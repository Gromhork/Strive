import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/l10n/relocalize.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/zones.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'p${n++}';
  final templates = defaultTemplates(id, de: true);
  final start = DateTime(2026, 11, 2); // Monday
  final now = DateTime(2026, 11, 16, 7); // Monday of week 3, before training

  UserProfile profile({List<int> days = const [1, 2, 4, 6, 7], String focus = 'run', Map<String, int>? race}) => UserProfile(
    level: 'intermediate',
    focus: focus == 'tri' ? TrainingFocus.triathlon : (focus == 'hybrid' ? TrainingFocus.hybrid : TrainingFocus.run),
    birthYear: 1990,
    trainingDays: days,
    longDay: 6,
    athlete: AthleteData(raceTimes: race ?? const {'10k': 50 * 60}, runWeeklyKm: 30, longestRunKm: 12, sessionMinutes: 90),
  );

  /// Plan + sessions: every past workout done as planned with [rpe] (by intensity), unless
  /// [skip] says otherwise.
  (List<PlannedWorkout>, List<Session>) history(
    UserProfile p, {
    int? Function(PlannedWorkout w)? rpe,
    bool Function(PlannedWorkout w)? skip,
    double Function(PlannedWorkout w)? ratio,
  }) {
    final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 6);
    final plans = <PlannedWorkout>[];
    final sessions = <Session>[];
    for (final w in plan) {
      if (!dayOnly(w.date).isBefore(dayOnly(now)) || (skip?.call(w) ?? false)) {
        plans.add(w);
        continue;
      }
      final r = ratio?.call(w) ?? 1.0;
      final s = Session(
        id: 's${w.id}',
        sport: w.sport,
        title: w.title,
        start: w.date.add(const Duration(hours: 18)),
        durationSec: (w.durationMin * 60 * r).round(),
        distanceM: (w.distanceKm ?? 0) * 1000 * r,
        rpe: rpe?.call(w) ?? defaultRpe(w),
        planId: w.id,
      );
      sessions.add(s);
      plans.add(PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'done', 'sessionId': s.id}));
    }
    return (plans, sessions);
  }

  Recalibration recal(UserProfile p, List<PlannedWorkout> plans, List<Session> sessions, {DateTime? at}) =>
      // Gap refills have their own tests (plan_gaps_test.dart); the 6-week plan ends inside the horizon.
      Recalibrator(l, p, plans: plans, sessions: sessions, now: at ?? now, fillGaps: false).run();

  bool quality(PlannedWorkout w) => w.intensity == 'tempo' || w.intensity == 'intervals';
  bool inDays(PlannedWorkout w, int from, int to) {
    final d = dayOnly(w.date).difference(dayOnly(now)).inDays;
    return d >= from && d < to;
  }

  void expectSafe(Recalibration r, List<PlannedWorkout> plans) {
    for (final c in r.changes) {
      // Done workouts, strength and races are never touched.
      expect(c.before.status, isNot('done'), reason: c.before.title);
      if (c.kind != RecalKind.moved && c.kind != RecalKind.dropped) {
        expect(c.before.sport, isNot(Sport.gym));
        expect(c.before.intensity, isNot('race'));
        expect(dayOnly(c.before.date).isBefore(dayOnly(now)), isFalse);
      }
      expect(
        c.update.keys.toSet().difference({
          'date',
          'status',
          'title',
          'description',
          'durationMin',
          'distanceKm',
          'intensity',
          'steps',
          'isKey',
          'auto',
        }),
        isEmpty,
      );
      // Volume changes keep the generator's original (undo, reference of later steps).
      if (c.kind == RecalKind.easier || c.kind == RecalKind.harder) {
        // 'recal', or 'recalRecovery' inside a proposed recovery week (C4: its marker).
        expect(c.after.auto?.reason, anyOf('recal', 'recalRecovery'));
        expect(c.after.auto!.durationMin, c.before.auto?.durationMin ?? c.before.durationMin);
      }
      for (final s in c.after.steps) {
        expect((s.durationSec ?? 1) > 0 && (s.distanceM ?? 1) > 0, isTrue);
        if (s.paceMin != null) expect(s.paceMin! <= s.paceMax!, isTrue);
      }
      expect(c.after.durationMin, greaterThanOrEqualTo(15));
      // A reduction never adds time, an increase stays small (≤ +10 %), and short repeats
      // (strides, VO2 reps) keep their length.
      if (c.kind == RecalKind.easier || c.kind == RecalKind.toEasy) {
        expect(c.after.durationMin, lessThanOrEqualTo(c.before.durationMin), reason: c.before.title);
      }
      if (c.kind == RecalKind.harder) {
        expect(c.after.durationMin, lessThanOrEqualTo(c.before.durationMin * 1.1 + 5), reason: c.before.title);
      }
      final shortBefore = c.before.steps.where((s) => s.isWork && (s.durationSec ?? 0) > 0 && s.durationSec! < 600).length;
      final shortAfter = c.after.steps.where((s) => s.isWork && (s.durationSec ?? 0) > 0 && s.durationSec! < 600).length;
      // (Quality kept at ~75 % after fatigue drops whole repeats – their length stays, review 2026-11 adapt-4.)
      final q = c.before.intensity == 'tempo' || c.before.intensity == 'intervals';
      if ((c.kind == RecalKind.easier || c.kind == RecalKind.harder) && !q) expect(shortAfter, shortBefore, reason: c.before.title);
      if (c.kind == RecalKind.easier && q) {
        expect(shortAfter, lessThanOrEqualTo(shortBefore), reason: c.before.title);
        final zones = {
          for (final s in [...c.before.steps, ...c.after.steps])
            if (s.isWork) s.zone,
        };
        for (final z in zones) {
          final b = c.before.steps.where((s) => s.isWork && s.zone == z).map((s) => '${s.durationSec}/${s.distanceM}').toSet();
          final a = c.after.steps.where((s) => s.isWork && s.zone == z).map((s) => '${s.durationSec}/${s.distanceM}').toSet();
          if (shortAfter < shortBefore) expect(b.containsAll(a), isTrue, reason: '${c.before.title}: repeats keep their length');
        }
      }
    }
    final ids = {for (final p in plans.where((p) => p.isDone)) p.id};
    expect(r.updates.keys.toSet().intersection(ids), isEmpty);
  }

  test('target RPE rules by intensity', () {
    expect(Recalibrator.rpeLoad('easy', 7), 1);
    expect(Recalibrator.rpeLoad('long', 5), 0.5);
    expect(Recalibrator.rpeLoad('easy', 4), 0);
    expect(Recalibrator.rpeLoad('tempo', 8), 0);
    expect(Recalibrator.rpeLoad('tempo', 9), 1);
    expect(Recalibrator.rpeLoad('intervals', 9), 0);
    expect(Recalibrator.rpeLoad('intervals', 10), 1);
    expect(Recalibrator.rpeTooEasy('tempo', 4), isTrue);
    expect(Recalibrator.rpeTooEasy('intervals', 5), isFalse);
    expect(Recalibrator.rpeTooEasy('easy', 2), isFalse);
  });

  test('on track: training as intended changes nothing', () {
    final p = profile();
    final (plans, sessions) = history(p);
    final r = recal(p, plans, sessions);
    expect(r.reasons, isEmpty);
    expect(r.isEmpty, isTrue, reason: r.changes.map((c) => '${c.kind} ${c.before.title}').join(', '));
    expect(r.stats.completion, closeTo(1, 0.01));
    expect(r.stats.rated, greaterThan(5));
  });

  test('easy runs that felt hard twice: next 7 days −10 %, first quality session becomes easy', () {
    final p = profile();
    var hardEasy = 0;
    final (plans, sessions) = history(p, rpe: (w) => w.intensity == 'easy' && hardEasy++ < 2 ? 7 : null);
    final r = recal(p, plans, sessions);
    expect(r.reasons, contains(RecalReason.rpeHigh));
    expect(r.stats.tooHard, 2);
    expectSafe(r, plans);
    final swapped = r.changes.where((c) => c.kind == RecalKind.toEasy).toList();
    expect(swapped.length, 1);
    expect(swapped.single.after.title, l.planEasyRun);
    expect(swapped.single.after.intensity, 'easy');
    expect(swapped.single.after.isKey, isFalse);
    expect(swapped.single.after.durationMin, lessThan(swapped.single.before.durationMin));
    final easier = r.changes.where((c) => c.kind == RecalKind.easier).toList();
    expect(easier, isNotEmpty);
    for (final c in easier) {
      expect(inDays(c.before, 0, 7), isTrue);
      expect(c.after.durationMin, lessThanOrEqualTo(c.before.durationMin));
      expect(c.after.description.split('\n'), contains(l.recalNote));
    }
    // Week 2 of the horizon is unchanged.
    expect(r.changes.where((c) => inDays(c.before, 7, 14)), isEmpty);
  });

  test('clearly overreached (≥ 3 too hard): all quality of the next 7 days easy, −20 % / −10 %', () {
    final p = profile();
    final (plans, sessions) = history(p, rpe: (w) => w.intensity == 'easy' || w.intensity == 'long' ? 8 : null);
    final r = recal(p, plans, sessions);
    expect(r.stats.tooHard, greaterThanOrEqualTo(3));
    expectSafe(r, plans);
    final upcomingQuality = plans.where((w) => w.status == 'planned' && quality(w) && inDays(w, 0, 7) && w.phase != 'taper');
    expect(
      r.changes.where((c) => c.kind == RecalKind.toEasy).map((c) => c.before.id).toSet(),
      containsAll(upcomingQuality.map((w) => w.id)),
    );
    for (final c in r.changes.where((c) => c.kind == RecalKind.easier)) {
      // Distance / steps scale exactly; minutes are rounded to 5 (short sessions may keep theirs).
      final f = (c.after.distanceKm ?? c.after.durationMin) / (c.before.distanceKm ?? c.before.durationMin);
      expect(f, lessThanOrEqualTo(inDays(c.before, 0, 7) ? 0.86 : 0.95), reason: '${c.before.title} $f');
      expect(c.after.durationMin, lessThanOrEqualTo(c.before.durationMin));
    }
  });

  test('low completion: volume down, no progression; missed key sessions are not made up on re-entry', () {
    final p = profile();
    // Everything of the last 8 days missed (incl. the key sessions of the last 3 days) – not
    // yet a training break (≥ 10 days, see the return-after-break scenarios).
    final (plans, sessions) = history(p, skip: (w) => dayOnly(now).difference(dayOnly(w.date)).inDays <= 8);
    final r = recal(p, plans, sessions);
    expect(r.reasons, contains(RecalReason.lowCompletion));
    expect(r.reasons, isNot(contains(RecalReason.returnAfterBreak)));
    expect(r.stats.completion, lessThan(0.5));
    expectSafe(r, plans);
    expect(r.changes.where((c) => c.kind == RecalKind.easier), isNotEmpty);
    expect(r.changes.where((c) => c.kind == RecalKind.harder), isEmpty);
    expect(r.changes.where((c) => c.kind == RecalKind.toEasy).length, 1, reason: 're-entry: first quality session easy');
    final missed = r.changes.where((c) => c.kind == RecalKind.moved || c.kind == RecalKind.dropped);
    expect(missed, isNotEmpty);
    // < 50 % done (e.g. ill): the missed key sessions are dropped, not stacked onto the return.
    expect(missed.where((c) => c.kind == RecalKind.moved), isEmpty);
    for (final c in missed) {
      expect(c.update, {'status': 'skipped'});
    }
  });

  test('sessions cut short twice: long sessions of the next 14 days −10 %', () {
    final p = profile();
    var cut = 0;
    final (plans, sessions) = history(p, ratio: (w) => w.intensity == 'long' && cut++ < 2 ? 0.6 : 1.0);
    final r = recal(p, plans, sessions);
    expect(r.reasons, contains(RecalReason.cutShort));
    expectSafe(r, plans);
    final longs = r.changes.where((c) => c.before.intensity == 'long');
    expect(longs, isNotEmpty);
    for (final c in longs) {
      expect(c.kind, RecalKind.easier);
      expect(c.after.distanceKm!, lessThan(c.before.distanceKm!));
    }
  });

  test('quality sessions that felt easy + VDOT up → paces only, no extra volume (R3)', () {
    final p = profile();
    final (plans, sessions) = history(p, rpe: (w) => quality(w) ? 3 : null);
    final r = recal(p, plans, sessions);
    // Quality runs on target paces that felt easy for weeks also lift the VDOT by one point
    // (session evaluation trend, §12) – that is this week's step up, volume and intensity
    // never rise together.
    expect(r.reasons, [RecalReason.rpeLowHold, RecalReason.runTrendFaster]);
    // Two weeks into the plan the step is capped at 1.6 × the model's gain of those weeks (C5:
    // +1 point every Monday ran a VDOT 40 → 48 in 8 weeks).
    final cap = Vdot.of(p.athlete)! + GoalModel.optimistic * GoalModel.gain(p, 2);
    expect(r.stats.newVdot, closeTo(min(r.stats.oldVdot + 1, cap), 0.06));
    expectSafe(r, plans);
    expect(r.changes.where((c) => c.kind == RecalKind.harder), isEmpty);
    expect(r.changes.where((c) => c.kind == RecalKind.paces), isNotEmpty);
  });

  test('quality sessions that felt easy: +5 % on easy / long of loading weeks, long run within R1', () {
    final p = profile();
    final h = history(p, rpe: (w) => quality(w) ? 3 : null);
    // Without pace data on the quality runs (e.g. treadmill without a foot pod) the VDOT
    // stays, so the volume may grow.
    final sessions = [
      for (final s in h.$2)
        if (h.$1.any((w) => w.id == s.planId && quality(w)))
          Session(id: s.id, sport: s.sport, title: s.title, start: s.start, durationSec: s.durationSec, rpe: s.rpe, planId: s.planId)
        else
          s,
    ];
    final plans = h.$1;
    final r = recal(p, plans, sessions);
    expect(r.reasons, [RecalReason.rpeLow]);
    expectSafe(r, plans);
    final harder = r.changes.where((c) => c.kind == RecalKind.harder).toList();
    expect(harder, isNotEmpty);
    final longest = sessions.where((s) => s.sport == Sport.run).fold<double>(0, (x, s) => x > s.distanceM / 1000 ? x : s.distanceM / 1000);
    for (final c in harder) {
      expect(inDays(c.before, 0, 7), isTrue);
      expect(c.before.phase, isNot(anyOf('recovery', 'taper')));
      expect(c.after.durationMin, greaterThanOrEqualTo(c.before.durationMin));
      expect(quality(c.before), isFalse);
      if (c.before.intensity == 'long') expect(c.after.distanceKm!, lessThanOrEqualTo(longest * 1.1 + 0.6));
    }
  });

  test('faster best effort: pace targets follow the new VDOT (max +2), saved as the VDOT estimate', () {
    final p = profile();
    final (plans, sessions) = history(p);
    // A 5 km in 21:00 (VDOT ~47 vs ~41 from the 50:00 10 km).
    final fast = Session(
      id: 'race5k',
      sport: Sport.run,
      title: 'Parkrun',
      start: now.subtract(const Duration(days: 2)),
      durationSec: 21 * 60,
      distanceM: 5000,
      splits: const [252, 252, 252, 252, 252],
    );
    final r = recal(p, plans, [...sessions, fast]);
    final old = Vdot.of(p.athlete)!;
    expect(r.reasons, contains(RecalReason.fasterRuns));
    expect(r.stats.newVdot, closeTo(old + 2, 0.11));
    // C5: the new VDOT goes to its own field – no synthetic race time in the profile.
    expect(r.raceTimes, isNull);
    expect(r.athlete['vdotEstimate'], closeTo(old + 2, 0.11));
    expect(Vdot.of(p.athlete.merge(r.athlete)), closeTo(old + 2, 0.11));
    expectSafe(r, plans);
    final paced = r.changes.where((c) => c.before.sport == Sport.run && c.after.steps.any((s) => s.paceMin != null)).toList();
    expect(paced, isNotEmpty);
    final pz = PaceZones(r.stats.newVdot!);
    for (final c in paced) {
      for (final s in c.after.steps.where((s) => s.paceMin != null)) {
        expect(s.paceMin, pz.range(s.zone).$1, reason: '${c.before.title} ${s.zone}');
      }
      expect(c.kind, RecalKind.paces);
      // A pure pace update keeps the athlete's text.
      expect(c.after.description, c.before.description);
    }
    // Slower runs never lower the paces of an athlete with race times.
    final slow = Session(
      id: 'slow',
      sport: Sport.run,
      title: 'Jog',
      start: now.subtract(const Duration(days: 1)),
      durationSec: 35 * 60,
      distanceM: 5000,
    );
    expect(recal(p, plans, [...sessions, slow]).stats.newVdot, isNull);
  });

  test('without race times the level default is replaced by a real effort, also downwards', () {
    final p = profile(race: const {});
    final (plans, sessions) = history(p);
    final slow = Session(
      id: 'slow',
      sport: Sport.run,
      title: 'Lauf',
      start: now.subtract(const Duration(days: 1)),
      durationSec: 33 * 60,
      distanceM: 5000,
      splits: const [396, 396, 396, 396, 396],
      rpe: 9, // an all-out 5 km
    );
    final r = recal(p, plans, [...sessions, slow]);
    expect(r.stats.newVdot, lessThan(Vdot.defaultFor('intermediate')));
    expect(r.reasons, contains(RecalReason.slowerRuns));
  });

  test('without race times an easy training run does not lower the level default', () {
    final p = profile(race: const {});
    final (plans, sessions) = history(p);
    // The same 5 km, but an unrated easy jog (no RPE, low HR): its "best 5 km" is no VDOT.
    final jog = Session(
      id: 'jog',
      sport: Sport.run,
      title: 'Lauf',
      start: now.subtract(const Duration(days: 1)),
      durationSec: 33 * 60,
      distanceM: 5000,
      avgHr: 130,
      splits: const [396, 396, 396, 396, 396],
    );
    final r = recal(p, plans, [...sessions, jog]);
    expect(r.reasons, isNot(contains(RecalReason.slowerRuns)));
    expect(r.raceTimes, isNull);
  });

  test('multi-sport: rides and swims are recalibrated, strength is never touched', () {
    final p = profile(focus: 'tri', days: const [1, 2, 3, 4, 6, 7]);
    final (plans, sessions) = history(
      p,
      rpe: (w) => w.intensity == 'easy' || w.intensity == 'technique' || w.intensity == 'long' ? 8 : null,
    );
    final r = recal(p, plans, sessions);
    expectSafe(r, plans);
    expect(r.changes.map((c) => c.before.sport).toSet(), containsAll([Sport.run, Sport.ride]));
    for (final c in r.changes.where((c) => c.kind == RecalKind.toEasy)) {
      expect(c.after.intensity, 'easy');
      expect(c.after.steps, isNotEmpty);
      if (c.before.sport == Sport.swim) expect(c.after.steps.any((s) => s.zone == 'CSS'), isFalse);
      if (c.before.sport == Sport.ride) expect(c.after.steps.single.zone, 'Z2');
    }
    final hybrid = profile(focus: 'hybrid', days: const [1, 2, 3, 5, 6, 7]);
    final (hp, hs) = history(hybrid, rpe: (w) => 9);
    expect(recal(hybrid, hp, hs).changes.where((c) => c.before.sport == Sport.gym), isEmpty);
  });

  test('recalibrating twice does not stack notes; texts relocalize', () {
    final p = profile();
    var hardEasy = 0;
    final (plans, sessions) = history(p, rpe: (w) => w.intensity == 'easy' && hardEasy++ < 2 ? 7 : null);
    final r1 = recal(p, plans, sessions);
    final applied = [
      for (final w in plans) r1.updates.containsKey(w.id) ? PlannedWorkout.fromMap(w.id, {...w.toMap(), ...r1.updates[w.id]!}) : w,
    ];
    final r2 = recal(p, applied, sessions);
    for (final c in r2.changes) {
      expect(c.after.description.split('\n').where((x) => x == l.recalNote).length, lessThanOrEqualTo(1));
    }
    expect(Relocalizer.to('en').text(l.recalNote), lookupAppLocalizations(const Locale('en')).recalNote);
    for (final c in r1.changes) {
      final en = Relocalizer.to('en').plan(c.after);
      expect((en['description'] as String? ?? c.after.description).contains(l.recalNote), isFalse, reason: c.after.title);
    }
  });
}

/// RPE an athlete would give when a workout went as intended.
int defaultRpe(PlannedWorkout w) => switch (w.intensity) {
  'easy' || 'technique' => 3,
  'long' => 4,
  'tempo' => 6,
  'intervals' => 8,
  _ => 6,
};
