// Review 2026-11 package G4 (adaptation / replan / recalibrate): regression tests for adapt-2 … adapt-7, UX-2,
// data-4 and data-9 – the scenarios of the audit (au_adapt3), asserted.
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/cardio_progression.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_match.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/plan_service.dart';
import 'package:strive/services/progression_check.dart';

import 'adaptation_sim_test.dart' as a;

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'x${n++}';
  final templates = defaultTemplates(id, de: true);
  PlannedWorkout apply(PlannedWorkout x, Map<String, dynamic> m) => PlannedWorkout.fromMap(x.id, {...x.toMap(), ...m});

  /// Trains [plans] exactly as planned up to (excluding) [until].
  (List<PlannedWorkout>, List<Session>) trainUntil(List<PlannedWorkout> plans, DateTime until) {
    final sessions = <Session>[];
    final out = <PlannedWorkout>[];
    for (final w in plans) {
      if (dayOnly(w.date).isBefore(until) && w.status == 'planned' && w.intensity != 'race') {
        final s = Session(
          id: 's${w.id}',
          sport: w.sport,
          title: w.title,
          start: DateTime(w.date.year, w.date.month, w.date.day, 18),
          durationSec: w.durationMin * 60,
          distanceM: (w.distanceKm ?? 0) * 1000,
          rpe: w.sport == Sport.gym ? null : a.nominalRpe(w),
          planId: w.id,
        );
        sessions.add(s);
        out.add(apply(w, {'status': 'done', 'sessionId': s.id}));
      } else {
        out.add(w);
      }
    }
    return (out, sessions);
  }

  /// "Plan neu aufsetzen" as [PlanService.replacePlan] does it: the whole calendar afterwards and the profile.
  (List<PlannedWorkout>, UserProfile, List<PlannedWorkout>) recreate(
    UserProfile p,
    List<PlannedWorkout> existing,
    List<Session> sessions,
    DateTime day,
  ) {
    final rp = withReachedVolume(p, plans: existing, sessions: sessions, start: day);
    final gen = PlanGenerator(l, rp, templates, id).generate(start: day, weeks: 12);
    final kept = PlanService.keptWorkouts(existing, day, sessions);
    final plan = PlanService.withoutCoveredDays(gen, kept);
    final before = existing.where((w) => dayOnly(w.date).isBefore(day) || kept.contains(w)).toList();
    return ([...before, ...plan], withPlanMeta(rp, day, 12), plan);
  }

  /// Phase of every week (Monday) from [from] to [to]: recovery when any endurance workout says so.
  List<String?> phases(List<PlannedWorkout> plans, DateTime from, DateTime to) => [
    for (var m = startOfWeek(from); !m.isAfter(to); m = addDays(m, 7))
      () {
        final ws = plans.where((w) => w.sport != Sport.gym && w.phase != null && !w.date.isBefore(m) && w.date.isBefore(addDays(m, 7)));
        if (ws.isEmpty) return null;
        return ws.any((w) => w.phase == 'recovery') ? 'recovery' : ws.first.phase;
      }(),
  ];

  int maxLoadingRun(List<String?> ps) {
    var best = 0, run = 0;
    for (final p in ps) {
      run = p == 'base' || p == 'build' || p == 'peak' ? run + 1 : 0;
      best = max(best, run);
    }
    return best;
  }

  group('adapt-7 / adapt-1: a re-created plan keeps the rhythm and the phases of the same race', () {
    test('marathon re-created mid-build (Wed in a loading week, Mon of a recovery week)', () {
      final p0 = withPlanMeta(a.marathoner(), a.simStart, 18);
      final gen = PlanGenerator(l, p0, templates, id).generate(start: a.simStart);
      final race = p0.athlete.eventDate!;
      final orig = phases(gen, a.simStart, race);
      for (final day in [addDays(a.simStart, 44), addDays(a.simStart, 49)]) {
        final (trained, ss) = trainUntil(gen, day);
        final (np, _, _) = recreate(p0, trained, ss, day);
        final now = phases(np, a.simStart, race);
        expect(now, orig, reason: 're-created ${dayKey(day)}');
        expect(maxLoadingRun(now), lessThanOrEqualTo(3));
      }
    });

    test('marathon re-created in the last 3–4 weeks: the taper stays', () {
      final p0 = withPlanMeta(a.marathoner(), a.simStart, 18);
      final gen = PlanGenerator(l, p0, templates, id).generate(start: a.simStart);
      final race = p0.athlete.eventDate!;
      final orig = phases(gen, a.simStart, race);
      for (final back in [24, 20, 17, 13, 10]) {
        final day = addDays(dayOnly(race), -back);
        final (trained, ss) = trainUntil(gen, day);
        final (np, _, _) = recreate(p0, trained, ss, day);
        expect(phases(np, a.simStart, race), orig, reason: '$back days before the race');
      }
    });

    test('a re-created plan does not raise its volume ceiling (same block)', () {
      final p0 = withPlanMeta(a.marathoner(), a.simStart, 18);
      final gen = PlanGenerator(l, p0, templates, id).generate(start: a.simStart);
      double peakWeek(List<PlannedWorkout> ws) {
        final weeks = <DateTime, double>{};
        for (final w in ws.where((w) => w.sport == Sport.run && w.intensity != 'race')) {
          weeks.update(startOfWeek(w.date), (v) => v + (w.distanceKm ?? 0), ifAbsent: () => w.distanceKm ?? 0);
        }
        return weeks.values.fold(0.0, max);
      }

      final day = addDays(a.simStart, 44);
      final (trained, ss) = trainUntil(gen, day);
      final (np, p1, _) = recreate(p0, trained, ss, day);
      expect(p1.athlete.planCarry?.baseRunKm, p0.athlete.runWeeklyKm);
      // Stated 35 km/week: ≤ 1.5 × 35 (+ the rounding of the weeks), not 1.5 × the 44 km reached.
      expect(peakWeek(np), lessThanOrEqualTo(peakWeek(gen) * 1.08));
    });

    test('the carry survives Firestore and belongs to its plan only', () {
      final c = PlanCarry(
        start: DateTime(2027, 1, 4),
        loadWeeks: 2,
        recovery: true,
        phase: 'build',
        phases: const ['recovery', 'build', 'peak', 'taper'],
        runWalkStage: 11,
        runWalkLongSec: 3600,
        runWalkLongKm: 7.5,
        fitnessStart: DateTime(2026, 11, 16),
        baseRunKm: 35,
      );
      final back = PlanCarry.fromMap(c.toMap())!;
      expect(back.toMap().toString(), c.toMap().toString());
      final p = a.marathoner().copyWith(athlete: a.marathoner().athlete.merge({'planCarry': c}));
      expect(AthleteData.fromMap(p.athlete.toMap()).planCarry?.phases, c.phases);
      // A fresh plan (no history before its start) clears it.
      final fresh = withReachedVolume(p, plans: const [], sessions: const [], start: DateTime(2027, 2, 1));
      expect(fresh.athlete.planCarry, isNull);
    });
  });

  test('adapt-2: re-creating a run/walk beginner HM plan mid-plan continues the ladder', () {
    final p0 = withPlanMeta(a.beginnerHm(), a.simStart, 20);
    final gen = PlanGenerator(l, p0, templates, id).generate(start: a.simStart);
    final race = p0.athlete.eventDate!;
    final day = addDays(a.simStart, 7 * 8 + 2);
    final (trained, ss) = trainUntil(gen, day);
    final (np, p1, fresh) = recreate(p0, trained, ss, day);
    final done = trained.where((w) => w.isDone).map(PlanGenerator.runWalkStageOf).whereType<int>().fold(-1, max);
    expect(done, greaterThanOrEqualTo(9), reason: 'Dauerlauf 25 / 30 min done');
    final firstNew = fresh.map(PlanGenerator.runWalkStageOf).whereType<int>().fold(99, min);
    expect(firstNew, greaterThanOrEqualTo(done), reason: 'no restart at 8 × 1 min');
    expect(fresh.where((w) => w.title.contains('× 1 min')), isEmpty);
    expect(p1.athlete.planCarry?.runWalkStage, isNotNull);
    double longest(Iterable<PlannedWorkout> ws) => ws.where((w) => w.intensity == 'long').fold(0.0, (x, w) => max(x, w.distanceKm ?? 0));
    expect(longest(fresh), greaterThanOrEqualTo(longest(gen) - 0.5), reason: 'the HM long run still reaches its peak');
    expect(phases(np, a.simStart, race), phases(gen, a.simStart, race));
  });

  test('adapt-6: re-creating mid-plan keeps the same morning\'s forecast and the paces', () {
    final p0 = withPlanMeta(a.marathoner(), a.simStart, 18);
    final gen = PlanGenerator(l, p0, templates, id).generate(start: a.simStart);
    for (final day in [addDays(a.simStart, 44), addDays(a.simStart, 49)]) {
      final (trained, ss) = trainUntil(gen, day);
      final now = day.add(const Duration(hours: 7));
      final f0 = GoalForecast.of(p0, plans: trained, sessions: ss, now: now)!;
      final (np, p1, fresh) = recreate(p0, trained, ss, day);
      final f1 = GoalForecast.of(p1, plans: np, sessions: ss, now: now)!;
      expect((f1.vdotNow! - f0.vdotNow!).abs(), lessThanOrEqualTo(0.1), reason: dayKey(day));
      expect(f1.nowSec, f0.nowSec);
      expect(f1.raceDaySec, f0.raceDaySec);
      expect(f1.status, f0.status);
      // No VDOT without evidence: the new plan's paces are the old plan's (Daniels, recalibration rule C5).
      final t0 = gen.expand((w) => w.steps).where((s) => s.zone == 'T' && s.paceMin != null).first.paceMin;
      final t1 = fresh.expand((w) => w.steps).where((s) => s.zone == 'T' && s.paceMin != null).first.paceMin;
      expect(t1, t0);
    }
  });

  test('adapt-4: the fatigue check keeps whole repeats, the title follows and a second review changes nothing', () {
    final p0 = withPlanMeta(a.marathoner(), a.simStart, 18);
    var plans = PlanGenerator(l, p0, templates, id).generate(start: a.simStart);
    final orig = {for (final w in plans) w.id: w};
    final sessions = <Session>[];
    var p = p0;
    var reduced = 0;
    for (var day = 0; day < 10 * 7; day++) {
      final d = addDays(a.simStart, day);
      if (d.weekday == DateTime.monday && day > 0) {
        final now = d.add(const Duration(hours: 7));
        for (var k = 1; k <= 3; k++) {
          final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, templates: templates, newId: id).run();
          if (k > 1) {
            expect(
              r.changes.where((c) => c.kind != RecalKind.paces),
              isEmpty,
              reason: 'run #$k on ${dayKey(d)}: ${r.changes.map((c) => c.before.title)}',
            );
          }
          for (final c in r.changes) {
            expect(retitledRepeats(c.after).title, c.after.title, reason: 'title matches the steps');
            final q = c.before.intensity == 'tempo' || c.before.intensity == 'intervals';
            if (!q || c.kind != RecalKind.easier) continue;
            reduced++;
            // Repeats keep their length and pace (VO2max / threshold stimulus), only fewer of them.
            final o = orig[c.before.id]!;
            final ow = o.steps.where((s) => s.isWork).toList(), nw = c.after.steps.where((s) => s.isWork).toList();
            if (ow.length >= 3) {
              expect(nw.length, lessThan(ow.length));
              expect(nw.first.distanceM, ow.first.distanceM);
              expect(nw.first.durationSec, ow.first.durationSec);
              expect(nw.first.paceMin, ow.first.paceMin);
            }
          }
          final upd = r.updates;
          plans = [for (final x in plans) upd.containsKey(x.id) ? apply(x, upd[x.id]!) : x, ...r.additions];
          if (r.raceTimes != null || r.athlete.isNotEmpty) {
            p = p.copyWith(athlete: p.athlete.merge({if (r.raceTimes != null) 'raceTimes': r.raceTimes, ...r.athlete}));
          }
        }
      }
      for (final w in plans.where((x) => dayOnly(x.date) == d && x.status == 'planned' && x.intensity != 'race').toList()) {
        final s = Session(
          id: 's${w.id}',
          sport: w.sport,
          title: w.title,
          start: DateTime(d.year, d.month, d.day, 18),
          durationSec: w.durationMin * 60,
          distanceM: (w.distanceKm ?? 0) * 1000,
          rpe: (a.nominalRpe(w) + 3).clamp(1, 10),
          planId: w.id,
        );
        sessions.add(s);
        plans = [
          for (final x in plans) x.id == w.id ? apply(x, {'status': 'done', 'sessionId': s.id}) : x,
        ];
      }
    }
    expect(reduced, greaterThan(0));
    // "Intervalle 4 × 800 m" with 3 repeats of 800 m left reads "3 × 800 m" (and back on undo).
    final iv = plans.where((w) => w.auto != null && w.title.startsWith('Intervalle 3 × 800')).firstOrNull;
    expect(iv, isNotNull, reason: 'the W6 fatigue check left 3 of the 4 × 800 m');
    expect(PlannedWorkout.fromMap(iv!.id, {...iv.toMap(), ...AutoAdjuster.undoUpdate(iv)..remove('auto')}).title, 'Intervalle 4 × 800 m');
  });

  test('retitledRepeats: the main set only (a swim\'s drills are no repeats)', () {
    final swim = PlannedWorkout(
      id: 'w',
      date: a.simStart,
      sport: Sport.swim,
      title: 'CSS-Serie 4 × 200 m',
      steps: [
        const WorkoutStep(kind: 'warmup', distanceM: 300, zone: 'REC'),
        const WorkoutStep(kind: 'work', distanceM: 200, zone: 'DR'),
        for (var i = 0; i < 3; i++) const WorkoutStep(kind: 'work', distanceM: 200, zone: 'CSS'),
        const WorkoutStep(kind: 'cooldown', distanceM: 100, zone: 'REC'),
      ],
    );
    expect(retitledRepeats(swim).title, 'CSS-Serie 3 × 200 m');
    final cruise = PlannedWorkout(
      id: 'c',
      date: a.simStart,
      sport: Sport.run,
      title: 'Cruise-Intervalle 2 × 2,4 km',
      steps: [for (var i = 0; i < 2; i++) const WorkoutStep(kind: 'work', distanceM: 1800, zone: 'T')],
    );
    expect(retitledRepeats(cruise).title, 'Cruise-Intervalle 2 × 1,8 km');
  });

  test('adapt-5: behind / at risk never suggests a faster target', () {
    var p = withPlanMeta(
      a.marathoner().copyWith(athlete: a.marathoner().athlete.merge({'targetTimeSec': 3 * 3600 + 50 * 60})),
      a.simStart,
      18,
    );
    var plans = PlanGenerator(l, p, templates, id).generate(start: a.simStart);
    final sessions = <Session>[];
    var behind = 0;
    for (var day = 0; day < 14 * 7; day++) {
      final d = addDays(a.simStart, day);
      final wk = day ~/ 7;
      if (d.weekday == DateTime.monday && day > 0) {
        final now = d.add(const Duration(hours: 7));
        final f = GoalForecast.of(p, plans: plans, sessions: sessions, now: now)!;
        if (f.status == ForecastStatus.slightlyBehind || f.status == ForecastStatus.atRisk) {
          behind++;
          expect(
            f.suggestedSec == null || f.suggestedSec! > f.targetSec!,
            isTrue,
            reason: '${dayKey(d)} ${f.status.name} suggests ${f.suggestedSec}',
          );
        }
        if (f.status == ForecastStatus.ahead && f.suggestedSec != null) expect(f.suggestedSec!, lessThan(f.targetSec!));
        final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, templates: templates, newId: id).run();
        final upd = r.updates;
        plans = [for (final x in plans) upd.containsKey(x.id) ? apply(x, upd[x.id]!) : x, ...r.additions];
        if (r.raceTimes != null || r.athlete.isNotEmpty) {
          p = p.copyWith(athlete: p.athlete.merge({if (r.raceTimes != null) 'raceTimes': r.raceTimes, ...r.athlete}));
        }
      }
      for (final w in plans.where((x) => dayOnly(x.date) == d && x.status == 'planned' && x.intensity != 'race').toList()) {
        if (wk == 7 || wk == 8) {
          plans = [
            for (final x in plans) x.id == w.id ? apply(x, {'status': 'skipped'}) : x,
          ];
          continue;
        }
        final s = Session(
          id: 's${w.id}',
          sport: w.sport,
          title: w.title,
          start: DateTime(d.year, d.month, d.day, 18),
          durationSec: w.durationMin * 60,
          distanceM: (w.distanceKm ?? 0) * 1000,
          rpe: a.nominalRpe(w),
          planId: w.id,
        );
        sessions.add(s);
        plans = [
          for (final x in plans) x.id == w.id ? apply(x, {'status': 'done', 'sessionId': s.id}) : x,
        ];
      }
    }
    expect(behind, greaterThan(0), reason: 'the sick weeks put the goal behind');
  });

  group('adapt-3 / UX-2: the first review of a new plan keeps the long sessions', () {
    test('marathon and 10 km: the first session done, review the next morning', () {
      for (final make in [a.marathoner, a.tenK]) {
        final p = withPlanMeta(make(), a.simStart, 18);
        final gen = PlanGenerator(l, p, templates, id).generate(start: a.simStart);
        final first = (gen.where((w) => w.sport != Sport.gym).toList()..sort((x, y) => x.date.compareTo(y.date))).first;
        final (trained, ss) = trainUntil(gen, addDays(dayOnly(first.date), 1));
        final now = addDays(dayOnly(first.date), 1).add(const Duration(hours: 7));
        final r = Recalibrator(l, p, plans: trained, sessions: ss, now: now, templates: templates, newId: id).run();
        expect(r.reasons, isNot(contains(RecalReason.longCap)));
        expect(r.changes.where((c) => c.before.intensity == 'long'), isEmpty);
      }
    });

    test('run/walk beginner (10 km, Tue/Thu/Sat): the first run/walk done at 100 %', () {
      final race = addDays(a.simStart, 7 * 12 - 2);
      final p = withPlanMeta(
        UserProfile(
          level: 'beginner',
          focus: TrainingFocus.run,
          birthYear: 1998,
          gender: 'f',
          goals: const ['endurance', 'race'],
          trainingDays: const [2, 4, 6],
        ).copyWith(athlete: const AthleteData().merge({'eventDistance': '10k', 'eventDate': race, 'canRun30': false})),
        a.simStart,
        12,
      );
      final gen = PlanGenerator(l, p, templates, id).generate(start: a.simStart);
      final first = (gen.where((w) => w.sport == Sport.run).toList()..sort((x, y) => x.date.compareTo(y.date))).first;
      expect(isRunWalk(first), isTrue);
      final (trained, ss) = trainUntil(gen, addDays(dayOnly(first.date), 1));
      final now = addDays(dayOnly(first.date), 1).add(const Duration(hours: 7));
      final r = Recalibrator(l, p, plans: trained, sessions: ss, now: now, templates: templates, newId: id).run();
      expect(r.reasons, isNot(contains(RecalReason.longCap)));
      expect(r.changes.where((c) => c.before.intensity == 'long' && c.kind == RecalKind.easier), isEmpty);
    });
  });

  test('data-4: a corrected session date moves its plan link', () {
    final d = DateTime(2026, 11, 17);
    final p1 = PlannedWorkout(id: 'p1', date: d, sport: Sport.run, title: 'Lauf', durationMin: 40, status: 'done', sessionId: 's1');
    final p2 = PlannedWorkout(id: 'p2', date: addDays(d, 7), sport: Sport.run, title: 'Lauf', durationMin: 40);
    final s = Session(id: 's1', sport: Sport.run, title: 'Lauf', start: DateTime(2026, 11, 17, 18), durationSec: 2400, planId: 'p1');
    final r = relinkOnRedate(s, DateTime(2026, 11, 24, 18), [p1, p2]);
    expect(r.relink, isTrue);
    expect(r.planId, 'p2');
    final after = {for (final (_, x) in r.changes) x.id: x};
    expect(after['p1']!.status, 'planned');
    expect(after['p1']!.sessionId, isNull);
    expect(after['p2']!.status, 'done');
    expect(after['p2']!.sessionId, 's1');
    // ±1 day keeps the link; a confirmed replacement (days away already) keeps it too.
    expect(relinkOnRedate(s, DateTime(2026, 11, 18, 7), [p1, p2]).relink, isFalse);
    final far = Session(id: 's1', sport: Sport.run, title: 'Lauf', start: DateTime(2026, 11, 14, 18), durationSec: 2400, planId: 'p1');
    expect(relinkOnRedate(far, DateTime(2026, 11, 12, 18), [p1, p2]).relink, isFalse);
    // No workout on the new day: only the old one is open again.
    final r2 = relinkOnRedate(s, DateTime(2026, 11, 21, 18), [p1, p2]);
    expect(r2.relink, isTrue);
    expect(r2.planId, isNull);
    expect(r2.changes.single.$2.status, 'planned');
  });

  test('data-9: workouts of an older plan generation from the plan start on are left-overs', () {
    final start = DateTime(2027, 1, 4);
    final genA = newPlanGen(DateTime(2027, 1, 3, 9), 'a'), genB = newPlanGen(DateTime(2027, 1, 3, 10), 'b');
    expect(genB.compareTo(genA), greaterThan(0));
    PlannedWorkout w(String id, int day, String? gen, {String status = 'planned', String? sessionId}) => PlannedWorkout(
      id: id,
      date: addDays(start, day),
      sport: Sport.run,
      title: 'Lauf',
      status: status,
      sessionId: sessionId,
      planGen: gen,
    );
    final plans = [
      w('a1', 0, genA),
      w('a2', 2, genA, status: 'done', sessionId: 's'),
      w('a3', 4, genA),
      w('a0', -3, genA),
      w('b1', 0, genB),
      w('b2', 2, genB),
      w('own', 1, null),
    ];
    // Whichever profile write arrived last, the later plan stays.
    for (final gen in [genA, genB]) {
      final p = withPlanMeta(a.marathoner(), start, 12, gen: gen);
      expect(p.athlete.planGen, gen);
      final stale = stalePlanWorkouts(p, plans, const []).map((x) => x.id).toSet();
      expect(stale, {'a1', 'a3'});
    }
    // A workout a session was started from stays; a profile without a generation removes nothing.
    final started = Session(id: 'x', sport: Sport.run, title: 'Lauf', start: start, durationSec: 600, planId: 'a3');
    expect(stalePlanWorkouts(withPlanMeta(a.marathoner(), start, 12, gen: genB), plans, [started]).map((x) => x.id), ['a1']);
    expect(stalePlanWorkouts(withPlanMeta(a.marathoner(), start, 12), plans, const []), isEmpty);
    expect(PlannedWorkout.fromMap('b1', plans[4].toMap()).planGen, genB);
  });
}
