import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/cardio_progression.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_match.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/session_feedback.dart';
import 'package:strive/services/zones.dart';

/// Scenarios of the endurance adaptation review (docs/training-science.md §11, §12):
/// return after a break (R4 / R1), HR signals with a predicted HRmax, contradicting
/// adjustments (R3), aerobic-efficiency noise, and a day-by-day simulation of a sick
/// fortnight followed by normal training (no compounding, the plan comes back).
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'w${n++}';
  final templates = defaultTemplates(id, de: true);

  UserProfile profile({String focus = 'run', int? maxHr}) => UserProfile(
    level: 'intermediate',
    birthYear: 1990,
    maxHr: maxHr,
    focus: focus == 'tri' ? TrainingFocus.triathlon : TrainingFocus.run,
    trainingDays: const [1, 2, 4, 6, 7],
    longDay: 6,
    athlete: AthleteData(
      raceTimes: const {'10k': 50 * 60},
      runWeeklyKm: 30,
      longestRunKm: 12,
      sessionMinutes: 120,
      ftp: focus == 'tri' ? 250 : null,
      hasPowerMeter: focus == 'tri',
      swim400Sec: 400,
      swim200Sec: 190,
    ),
  );

  int rpeOf(PlannedWorkout w) => switch (w.intensity) {
    'easy' || 'technique' => 3,
    'long' => 4,
    'tempo' => 6,
    'intervals' => 8,
    _ => 5,
  };

  Session sessionFor(PlannedWorkout w, {double ratio = 1, double pace = 1, int? rpe, int? hr, String? source}) => Session(
    id: 's${w.id}',
    sport: w.sport,
    title: w.title,
    start: DateTime(w.date.year, w.date.month, w.date.day, 18),
    durationSec: (w.durationMin * 60 * ratio * pace).round(),
    distanceM: (w.distanceKm ?? 0) * 1000 * ratio,
    rpe: rpe ?? (w.sport == Sport.gym ? null : rpeOf(w)),
    avgHr: hr,
    source: source,
    planId: w.id,
  );

  PlannedWorkout asDone(PlannedWorkout p, Session s) => PlannedWorkout.fromMap(p.id, {...p.toMap(), 'status': 'done', 'sessionId': s.id});

  /// Generated plan from [start]; every workout before [until] done as planned, except on
  /// the days [off] says.
  (List<PlannedWorkout>, List<Session>) history(
    UserProfile p,
    DateTime start,
    DateTime until, {
    bool Function(DateTime day)? off,
    int weeks = 10,
  }) {
    final gen = PlanGenerator(l, p, templates, id).generate(start: start, weeks: weeks);
    final plans = <PlannedWorkout>[], sessions = <Session>[];
    for (final w in gen) {
      if (!dayOnly(w.date).isBefore(dayOnly(until)) || (off?.call(dayOnly(w.date)) ?? false) || w.intensity == 'race') {
        plans.add(w);
        continue;
      }
      final s = sessionFor(w);
      sessions.add(s);
      plans.add(asDone(w, s));
    }
    return (plans, sessions);
  }

  bool quality(PlannedWorkout w) => w.intensity == 'tempo' || w.intensity == 'intervals';
  double amount(PlannedWorkout p) => p.sport != Sport.ride && (p.distanceKm ?? 0) > 0 ? p.distanceKm! : p.durationMin.toDouble();

  // ───────────────────────────── I5: return after a break ─────────────────────────────

  group('I5 return after ≥ 2 weeks off', () {
    final start = DateTime(2026, 10, 5); // Monday
    final at = DateTime(2026, 11, 16, 7); // Monday, after two sick weeks (Nov 2–15)
    final today = dayOnly(at);
    bool sick(DateTime d) => !d.isBefore(DateTime(2026, 11, 2));

    test('two sick weeks: week 1 at 60 %, week 2 at 70 %, no intensity, long runs within R1', () {
      final p = profile();
      final (plans, sessions) = history(p, start, at, off: sick);
      final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: at).run();
      expect(r.reasons, contains(RecalReason.returnAfterBreak), reason: '${r.reasons}');
      expect(r.stats.breakDays, greaterThanOrEqualTo(14));
      final byId = {for (final c in r.changes) c.before.id: c};
      final upcoming = plans.where(
        (w) =>
            w.status == 'planned' &&
            w.sport == Sport.run &&
            w.intensity != 'race' &&
            !dayOnly(w.date).isBefore(today) &&
            dayOnly(w.date).difference(today).inDays < 14,
      );
      for (final w in upcoming) {
        final days = dayOnly(w.date).difference(today).inDays;
        final c = byId[w.id];
        if (quality(w)) {
          // Week 1: no intensity at all; the easy replacement is at most 60 % of the time.
          if (days < 7) {
            expect(c?.kind, RecalKind.toEasy, reason: w.title);
            expect(c!.after.durationMin, lessThanOrEqualTo(w.durationMin * 0.6 + 5));
          }
          continue;
        }
        final ratio = c == null ? 1.0 : amount(c.after) / amount(w);
        // Before: −20 % (days 1–7) / −10 % (days 8–14); now R4 50–70 %.
        expect(ratio, closeTo(days < 7 ? 0.6 : 0.7, 0.04), reason: '${w.title} day $days');
        expect(ratio, greaterThanOrEqualTo(0.45), reason: '${w.title} day $days');
      }
      // R1: every long run ≤ 1.1 × the longest of its 30 days before (× 1.1 per earlier one).
      final longest = sessions.where((s) => s.sport == Sport.run).fold<double>(0, (x, s) => max(x, s.distanceM / 1000));
      final longs = r.changes.where((c) => c.before.intensity == 'long' && c.kind == RecalKind.easier).toList();
      expect(longs, isNotEmpty);
      for (final c in longs) {
        expect(c.after.distanceKm!, lessThanOrEqualTo(longest * 1.21 + 0.1));
        expect(c.after.auto?.reason, 'recal');
        expect(c.after.auto!.distanceKm, c.before.distanceKm, reason: 'keeps the original for undo');
      }
    });

    test('five weeks off (no run in the last 30 days): 50 % restart, long run ≤ 0.6 × the pre-break long run', () {
      final p = profile();
      final at5 = DateTime(2026, 12, 7, 7);
      final (plans, sessions) = history(p, start, at5, off: (d) => !d.isBefore(DateTime(2026, 11, 2)), weeks: 12);
      final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: at5).run();
      expect(r.reasons, contains(RecalReason.returnAfterBreak));
      expect(r.stats.breakDays, greaterThanOrEqualTo(35));
      final preBreakLong = sessions.where((s) => s.sport == Sport.run).fold<double>(0, (x, s) => max(x, s.distanceM / 1000));
      final longs = r.changes.where((c) => c.before.intensity == 'long' && c.kind == RecalKind.easier).toList();
      expect(longs, isNotEmpty);
      // The first long run back ≤ 0.6 × the longest before the break, the next ≤ +10 % on it.
      longs.sort((a, b) => a.before.date.compareTo(b.before.date));
      expect(longs.first.after.distanceKm!, lessThanOrEqualTo(preBreakLong * 0.6 + 0.1));
      if (longs.length > 1) expect(longs[1].after.distanceKm!, lessThanOrEqualTo(preBreakLong * 0.66 + 0.1));
      expect(r.reasons, contains(RecalReason.longCap));
      for (final c in r.changes.where((c) => c.kind == RecalKind.easier && c.before.sport == Sport.run)) {
        final days = dayOnly(c.before.date).difference(dayOnly(at5)).inDays;
        if (days < 7 && c.before.intensity != 'long') expect(amount(c.after) / amount(c.before), closeTo(0.5, 0.06));
      }
    });

    test('triathlete off for two weeks: rides and swims restart proportionally, long ride capped by minutes', () {
      final p = profile(focus: 'tri');
      final (plans, sessions) = history(p, start, at, off: sick);
      final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: at).run();
      for (final sport in [Sport.ride, Sport.swim]) {
        final first = r.changes.where(
          (c) => c.before.sport == sport && c.kind == RecalKind.easier && dayOnly(c.before.date).difference(today).inDays < 7,
        );
        expect(first, isNotEmpty, reason: '$sport');
        for (final c in first) {
          // Swim warm-up / cool-down keep their length, the main set changes by whole repeats.
          expect(
            amount(c.after) / amount(c.before),
            lessThanOrEqualTo(sport == Sport.swim ? 0.72 : 0.65),
            reason: '$sport ${c.before.title}',
          );
        }
      }
      final longestRide = sessions.where((s) => s.sport == Sport.ride).fold<double>(0, (x, s) => max(x, s.durationSec / 60));
      for (final c in r.changes.where((c) => c.before.sport == Sport.ride && c.before.intensity == 'long')) {
        expect(c.after.durationMin, lessThanOrEqualTo(longestRide * 1.21 + 5));
      }
    });

    test('a single missed week is no break: −20 % / −10 % as before, no R4', () {
      final p = profile();
      final (plans, sessions) = history(p, start, at, off: (d) => !d.isBefore(DateTime(2026, 11, 9)));
      final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: at).run();
      expect(r.reasons, isNot(contains(RecalReason.returnAfterBreak)));
    });
  });

  // ───────────────────────────── I6: HR with a predicted HRmax ─────────────────────────────

  group('I6 heart rate against a predicted HRmax', () {
    final sun = DateTime(2026, 11, 15);
    final now = DateTime(2026, 11, 15, 12);
    final p0 = profile();
    final hz = HrZones(p0.estimatedMaxHr);
    final pz = PaceZones(Vdot.of(p0.athlete)!);
    final z2 = hz.zone(2);
    final expected = (z2.$1 + z2.$2) ~/ 2;

    PlannedWorkout easyRun(DateTime d, double km) => PlannedWorkout(
      id: id(),
      date: d,
      sport: Sport.run,
      title: 'Easy run',
      intensity: 'easy',
      durationMin: (km * pz.easySlow / 60).round(),
      distanceKm: km,
      phase: 'build',
      steps: [
        WorkoutStep(
          kind: 'steady',
          zone: 'E',
          distanceM: km * 1000,
          paceMin: pz.easyFast,
          paceMax: pz.easySlow,
          hrMin: z2.$1,
          hrMax: z2.$2,
        ),
      ],
    );

    /// Treadmill run without a foot pod: time and HR only.
    Session treadmill(PlannedWorkout p, {int? rpe, int? hr, String? source}) => Session(
      id: 's${p.id}',
      sport: Sport.run,
      title: 'Treadmill',
      start: p.date.add(const Duration(hours: 8)),
      durationSec: p.durationMin * 60,
      rpe: rpe,
      avgHr: hr,
      indoor: true,
      source: source,
      planId: p.id,
    );

    List<AutoChange> adjust(UserProfile prof, PlannedWorkout e1, Session s, PlannedWorkout e2, {List<Session> history = const []}) =>
        AutoAdjuster(prof, plans: [asDone(e1, s), e2], sessions: [...history, s], now: now).afterSession(s, asDone(e1, s));

    test('easy treadmill run at +9 bpm (inside the ±10 bpm error): no auto −10 % without a second signal', () {
      final e1 = easyRun(sun, 8), e2 = easyRun(sun.add(const Duration(days: 2)), 8);
      final s = treadmill(e1, hr: expected + 9);
      final f = evaluateSession(e1, s, p0);
      // Before: HR alone (weight 1) → harder, confidence 0.5 → next easy run −10 %.
      expect(f.clearlyHarder, isFalse, reason: '$f');
      expect(f.signals.single.weight, 0.5);
      expect(adjust(p0, e1, s, e2), isEmpty);
      // With a second signal (RPE 6 on an easy day) the reduction stays.
      expect(adjust(p0, e1, treadmill(e1, hr: expected + 9, rpe: 6), e2).single.reason, 'easyHard');
      // A measured HRmax makes HR a full signal again.
      final measured = profile(maxHr: p0.estimatedMaxHr);
      expect(adjust(measured, e1, s, e2).single.reason, 'easyHard');
      // Far beyond the prediction error (zone 4 on an easy run), HR alone still counts.
      expect(adjust(p0, e1, treadmill(e1, hr: hz.zone(4).$1 + 2), e2).single.reason, 'easyHard');
    });

    test('imported treadmill runs (HR-estimated RPE) at +9 bpm: the Recalibrator sees no fatigue', () {
      final start = DateTime(2026, 11, 2);
      final at = DateTime(2026, 11, 16, 7);
      final (plans0, _) = history(p0, start, start, weeks: 6);
      final plans = <PlannedWorkout>[], sessions = <Session>[];
      for (final w in plans0) {
        if (!dayOnly(w.date).isBefore(dayOnly(at)) || w.intensity == 'race') {
          plans.add(w);
          continue;
        }
        Session s;
        if (w.sport == Sport.run && (w.intensity == 'easy' || w.intensity == 'long')) {
          // Watch import: HR a little above the zone-2 target, RPE estimated from it.
          final hr = expected + 9;
          s = Session(
            id: 's${w.id}',
            sport: Sport.run,
            title: 'Treadmill',
            start: DateTime(w.date.year, w.date.month, w.date.day, 18),
            durationSec: w.durationMin * 60,
            avgHr: hr,
            rpe: rpeFromHr(hr, p0),
            source: 'Health Connect',
            indoor: true,
            planId: w.id,
          );
        } else {
          s = sessionFor(w);
        }
        sessions.add(s);
        plans.add(asDone(w, s));
      }
      final r = Recalibrator(l, p0, plans: plans, sessions: sessions, now: at).run();
      // Before: estimated RPE 5 counted ½ each → "too hard" 3 → −20 % and all quality easy.
      expect(r.stats.tooHard, lessThan(2), reason: '${r.reasons}');
      expect(r.reasons, isNot(contains(RecalReason.rpeHigh)));
      expect(r.changes.where((c) => c.kind == RecalKind.toEasy), isEmpty);
    });

    test('HRmax is raised (only up) from hard sessions; spikes and easy sessions are ignored', () {
      final predicted = p0.estimatedMaxHr;
      Session hard(int max, {int avg = 170, int? rpe = 9, int daysAgo = 10}) => Session(
        id: 'h$max$avg',
        sport: Sport.run,
        title: 'Intervals',
        start: now.subtract(Duration(days: daysAgo)),
        durationSec: 3000,
        avgHr: avg,
        maxHr: max,
        rpe: rpe,
      );
      expect(HrMax.of(p0, now: now).bpm, predicted);
      expect(HrMax.of(p0, now: now).measured, isFalse);
      final up = HrMax.of(p0, sessions: [hard(predicted + 8)], now: now);
      expect(up.bpm, predicted + 8);
      expect(up.observed, isTrue);
      expect(up.measured, isFalse);
      // Lower peaks never lower it; optical spikes and easy sessions don't raise it.
      expect(HrMax.of(p0, sessions: [hard(predicted - 10)], now: now).bpm, predicted);
      expect(HrMax.of(p0, sessions: [hard(predicted + 40)], now: now).bpm, predicted);
      expect(HrMax.of(p0, sessions: [hard(predicted + 8, avg: 130, rpe: 3)], now: now).bpm, predicted);
      expect(HrMax.of(p0, sessions: [hard(predicted + 8, daysAgo: 400)], now: now).bpm, predicted);
      // A measured value always wins.
      expect(HrMax.of(profile(maxHr: 200), sessions: [hard(predicted + 8)], now: now).bpm, 200);
      // With the observed HRmax the +9 bpm easy run is inside the (higher) zone 2.
      final e1 = easyRun(sun, 8), e2 = easyRun(sun.add(const Duration(days: 2)), 8);
      final s = treadmill(e1, hr: expected + 9, rpe: 3);
      expect(adjust(p0, e1, s, e2, history: [hard(predicted + 12)]), isEmpty);
    });
  });

  // ───────────────────────────── I7: contradicting adjustments ─────────────────────────────

  group('I7 no contradicting adjustments', () {
    final start = DateTime(2026, 10, 5);
    final at = DateTime(2026, 11, 16, 7);

    /// Quality runs at RPE 3 (felt easy) without pace data → "rpeLow", no VDOT change.
    (List<PlannedWorkout>, List<Session>) easyQuality(UserProfile p) {
      final (plans, sessions) = history(p, start, at, weeks: 12); // covers the recalibration horizon (no "plan ended" refill)
      final out = <Session>[];
      final rated = <PlannedWorkout>[];
      for (final w in plans) {
        final s = sessions.where((s) => s.planId == w.id).firstOrNull;
        if (s == null) {
          rated.add(w);
          continue;
        }
        final q = quality(w);
        final x = Session(
          id: s.id,
          sport: s.sport,
          title: s.title,
          start: s.start,
          durationSec: s.durationSec,
          distanceM: q ? 0 : s.distanceM,
          rpe: q ? 3 : s.rpe,
          planId: s.planId,
        );
        out.add(x);
        rated.add(w);
      }
      return (rated, out);
    }

    test('an easy run the AutoAdjuster cut −10 % (too fast) is not raised +5 % by the next recalibration', () {
      final p = profile();
      final (plans, sessions) = easyQuality(p);
      final r0 = Recalibrator(l, p, plans: plans, sessions: sessions, now: at).run();
      expect(r0.reasons, [RecalReason.rpeLow]);
      final raised = r0.changes.firstWhere((c) => c.kind == RecalKind.harder && c.before.intensity == 'easy');
      // The same easy run, reduced yesterday after a too-fast easy run.
      final cut = AutoAdjuster.scaleWorkout(raised.before, 0.9, p);
      final reduced = PlannedWorkout.fromMap(cut.id, {
        ...cut.toMap(),
        'auto':
            AutoAdjustment(
              sessionId: 'x',
              reason: 'easyTooFast',
              at: at.subtract(const Duration(days: 1)),
              durationMin: raised.before.durationMin,
              distanceKm: raised.before.distanceKm,
              steps: raised.before.steps,
            ).toMap(),
      });
      final plans2 = [for (final w in plans) w.id == reduced.id ? reduced : w];
      final r = Recalibrator(l, p, plans: plans2, sessions: sessions, now: at).run();
      expect(r.changes.where((c) => c.before.id == reduced.id && c.kind == RecalKind.harder), isEmpty);
      // Other easy runs still get their +5 %.
      expect(r.changes.where((c) => c.kind == RecalKind.harder), isNotEmpty);
    });

    test('a good race: VDOT +2 and the volume stays (R3)', () {
      final p = profile();
      final (plans, sessions) = easyQuality(p);
      final race = Session(
        id: 'race',
        sport: Sport.run,
        title: '10 km race',
        start: at.subtract(const Duration(days: 1)),
        durationSec: 46 * 60,
        distanceM: 10000,
        rpe: 9,
      );
      final r = Recalibrator(l, p, plans: plans, sessions: [...sessions, race], now: at).run();
      expect(r.stats.newVdot! - r.stats.oldVdot, closeTo(2, 0.11));
      expect(r.reasons, contains(RecalReason.rpeLowHold));
      expect(r.changes.where((c) => c.kind == RecalKind.harder), isEmpty, reason: 'before: VDOT +2 and +5 % volume together');
      expect(r.changes.where((c) => c.kind == RecalKind.paces), isNotEmpty);
    });
  });

  // ───────────────────────────── Aerobic efficiency noise ─────────────────────────────

  group('aerobic efficiency trend', () {
    final p0 = profile();
    final day0 = DateTime(2026, 10, 1);
    CardioTrend trend(List<double> ef, {int every = 4}) {
      final fb = <SessionFeedback>[];
      for (var i = 0; i < ef.length; i++) {
        final w = PlannedWorkout(id: 'e$i', date: day0.add(Duration(days: i * every)), sport: Sport.run, title: 'Easy', distanceKm: 8);
        // EF = m/min per beat: 8000 m in 48 min at an HR that gives the wanted EF.
        final s = Session(
          id: 's$i',
          sport: Sport.run,
          title: 'Easy',
          start: w.date,
          durationSec: 48 * 60,
          distanceM: 8000,
          avgHr: (8000 / 48 / ef[i]).round(),
        );
        fb.add(evaluateSession(w, s, p0));
      }
      return CardioTrend(Sport.run, fb);
    }

    test('±3 % day-to-day noise is no trend; ≥ 6 points needed; a steady fall is', () {
      // 5 noisy points: the old least-squares rule read −3 % here.
      expect(trend([1.24, 1.21, 1.18, 1.21, 1.17]).efficiencyChange, isNull);
      // 8 points of ±3 % noise around a flat line → 0.
      expect(trend([1.20, 1.24, 1.16, 1.21, 1.17, 1.23, 1.16, 1.20]).efficiencyChange, 0);
      // A single bad (hot) day at the end does not make a trend either.
      expect(trend([1.20, 1.21, 1.19, 1.20, 1.21, 1.19, 1.20, 1.10]).efficiencyChange, 0);
      // A real, consistent fall of ~6 %.
      final fall = trend([1.24, 1.23, 1.22, 1.21, 1.20, 1.19, 1.18, 1.17]).efficiencyChange!;
      expect(fall, lessThan(-0.03));
    });
  });

  // ───────────────────────────── Day-by-day simulation ─────────────────────────────

  group('simulation: sick fortnight → normal training', () {
    test('no compounding, bounds hold, R1 holds, the plan returns to its volume', () {
      final p = profile();
      final start = DateTime(2026, 10, 5); // Monday
      final gen = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 11);
      final orig = {for (final w in gen) w.id: w};
      final plans = {for (final w in gen) w.id: w};
      final sessions = <Session>[];
      const sickFrom = 21, sickTo = 34, back = 35; // two sick weeks, back on a Monday
      DateTime day(int i) => DateTime(start.year, start.month, start.day + i);
      var recals = 0;

      void checkBounds(String when) {
        for (final w in plans.values.where((w) => w.status == 'planned' && w.sport != Sport.gym && w.intensity != 'race')) {
          final o = orig[w.id]!;
          final r = w.durationMin / o.durationMin;
          expect(r, inInclusiveRange(0.45, 1.12), reason: '$when: ${w.title} ${w.date} ${o.durationMin} → ${w.durationMin}');
        }
      }

      for (var i = 0; i < 77; i++) {
        final today = day(i);
        if (today.weekday == DateTime.monday && i >= 7) {
          final now = today.add(const Duration(hours: 7));
          final r = Recalibrator(l, p, plans: plans.values.toList(), sessions: sessions, now: now).run();
          recals++;
          if (i == back) expect(r.reasons, contains(RecalReason.returnAfterBreak));
          for (final c in r.changes) {
            // Refills after the plan's end are new workouts (not part of the volume check).
            if (c.kind == RecalKind.added) continue;
            plans[c.after.id] = c.after;
          }
          checkBounds('recal day $i');
          // Running the assistant again right away changes no volume (no compounding).
          final again = Recalibrator(l, p, plans: plans.values.toList(), sessions: sessions, now: now).run();
          expect(again.changes.where((c) => c.kind == RecalKind.easier || c.kind == RecalKind.harder), isEmpty, reason: 'day $i');
        }
        if (i >= sickFrom && i <= sickTo) continue;
        for (final w in plans.values.where((w) => dayOnly(w.date) == today && w.status == 'planned').toList()) {
          if (w.intensity == 'race') continue;
          // R1 holds for every long run actually done after the break.
          if (w.sport == Sport.run && w.intensity == 'long' && i >= back) {
            final from = today.subtract(const Duration(days: 30));
            final longest = sessions
                .where((s) => s.sport == Sport.run && s.start.isAfter(from))
                .fold<double>(0, (x, s) => max(x, s.distanceM / 1000));
            // The recalibration leaves deviations ≤ 2 % alone (rounding of the steps).
            if (longest > 0) expect(w.distanceKm!, lessThanOrEqualTo(longest * 1.1 * 1.02 + 0.15), reason: 'long run day $i');
          }
          // First week back: easy runs a bit too fast (fires the AutoAdjuster on top of the
          // recalibration).
          final fast = i >= back && i < back + 7 && w.intensity == 'easy' && w.sport == Sport.run;
          final s = sessionFor(w, pace: fast ? 0.88 : 1, rpe: fast ? 5 : null);
          sessions.add(s);
          plans[w.id] = asDone(w, s);
          final changes = AutoAdjuster(
            p,
            plans: plans.values.toList(),
            sessions: sessions,
            now: today.add(const Duration(hours: 19)),
          ).afterSession(s, plans[w.id]!);
          for (final c in changes) {
            plans[c.after.id] = c.after;
          }
          checkBounds('auto day $i');
        }
      }
      expect(recals, greaterThan(8));
      // Three weeks after the return everything except the long run is back at the plan;
      // the long run climbs back by ≤ 10 % a week (R1) and is close to it.
      double week(int from, bool long) => plans.values
          .where((w) => w.sport == Sport.run && (w.intensity == 'long') == long)
          .where((w) => !dayOnly(w.date).isBefore(day(from)) && dayOnly(w.date).isBefore(day(from + 7)))
          .fold(0.0, (x, w) => x + (w.distanceKm ?? 0));
      double origWeek(int from, bool long) => orig.values
          .where((w) => w.sport == Sport.run && (w.intensity == 'long') == long)
          .where((w) => !dayOnly(w.date).isBefore(day(from)) && dayOnly(w.date).isBefore(day(from + 7)))
          .fold(0.0, (x, w) => x + (w.distanceKm ?? 0));
      for (final from in [back + 21, back + 28, back + 35]) {
        expect(week(from, false), closeTo(origWeek(from, false), 0.15), reason: 'week from day $from');
        expect(week(from, true), greaterThanOrEqualTo(origWeek(from, true) * 0.8), reason: 'long run week from day $from');
      }
      // The first week back really was a restart.
      expect(week(back, false) + week(back, true), lessThan((origWeek(back, false) + origWeek(back, true)) * 0.75));
    });
  });
}
