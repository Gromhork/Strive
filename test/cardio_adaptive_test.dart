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
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/session_feedback.dart';
import 'package:strive/services/zones.dart';

/// Simulations of past-session histories → session evaluation, automatic small
/// adjustments and recalibration proposals (docs/training-science.md §12).
void main() {
  final l = lookupAppLocalizations(const Locale('de'));

  UserProfile profile({List<String> limitations = const [], String focus = 'run', int? ftp = 250}) => UserProfile(
    level: 'intermediate',
    birthYear: 1990,
    focus: focus == 'tri' ? TrainingFocus.triathlon : TrainingFocus.run,
    trainingDays: const [1, 2, 3, 4, 6, 7],
    longDay: 7,
    athlete: AthleteData(
      raceTimes: const {'10k': 50 * 60},
      runWeeklyKm: 30,
      longestRunKm: 12,
      sessionMinutes: 120,
      ftp: ftp,
      hasPowerMeter: ftp != null,
      swim400Sec: 400,
      swim200Sec: 190,
      limitations: limitations,
    ),
  );
  final p0 = profile();
  final pz = PaceZones(Vdot.of(p0.athlete)!);
  final hz = HrZones(p0.estimatedMaxHr);
  int mid(String zone) => (pz.range(zone).$1 + pz.range(zone).$2) ~/ 2;

  // ───────────────────────────── Builders ─────────────────────────────

  var n = 0;
  WorkoutStep run(String kind, String zone, {double? km, int? sec}) {
    final (f, s) = pz.range(zone);
    final hr = hz.zone(switch (zone) {
      'T' => 4,
      'I' || 'R' => 5,
      'M' => 3,
      _ => 2,
    });
    return WorkoutStep(
      kind: kind,
      zone: zone,
      distanceM: km == null ? null : km * 1000,
      durationSec: sec,
      paceMin: f,
      paceMax: s,
      hrMin: zone == 'REC' ? null : hr.$1,
      hrMax: zone == 'REC' ? null : hr.$2,
    );
  }

  PlannedWorkout plan(
    Sport sport,
    String intensity,
    DateTime date,
    List<WorkoutStep> steps, {
    String phase = 'build',
    String status = 'planned',
    UserProfile? prof,
  }) {
    final pr = prof ?? p0;
    final sec = estimateStepsSec(steps, sport, pr);
    var m = 0.0;
    for (final s in steps) {
      if (s.distanceM != null) {
        m += s.distanceM!;
      } else if (s.durationSec != null && sport == Sport.run) {
        m += s.durationSec! / ((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) * 2 * 1000;
      } else if (s.durationSec != null && sport == Sport.ride) {
        m += s.durationSec! / 3600 * 27 * 1000;
      }
    }
    return PlannedWorkout(
      id: 'p${n++}',
      date: date,
      sport: sport,
      title: '$sport $intensity',
      durationMin: max(15, (sec / 60).round()),
      distanceKm: m <= 0 ? null : double.parse((m / 1000).toStringAsFixed(1)),
      intensity: intensity,
      steps: steps,
      phase: phase,
      status: status,
      isKey: intensity != 'easy',
    );
  }

  PlannedWorkout easyRun(DateTime d, double km, {String phase = 'build', String status = 'planned'}) =>
      plan(Sport.run, 'easy', d, [run('steady', 'E', km: km)], phase: phase, status: status);
  PlannedWorkout longRun(DateTime d, double km, {String phase = 'build', String status = 'planned'}) =>
      plan(Sport.run, 'long', d, [run('steady', 'E', km: km)], phase: phase, status: status);
  PlannedWorkout intervalRun(DateTime d, int reps, {String phase = 'build', String status = 'planned'}) => plan(
    Sport.run,
    'intervals',
    d,
    [
      run('warmup', 'E', km: 2),
      for (var i = 0; i < reps; i++) ...[run('work', 'I', km: 1), if (i < reps - 1) run('recovery', 'REC', sec: 120)],
      run('cooldown', 'E', km: 1.5),
    ],
    phase: phase,
    status: status,
  );
  PlannedWorkout tempoRun(DateTime d, int min, {String phase = 'build'}) => plan(Sport.run, 'tempo', d, [
    run('warmup', 'E', km: 2),
    run('work', 'T', sec: min * 60),
    run('cooldown', 'E', km: 1.5),
  ], phase: phase);

  final sz = SwimZones(105);
  WorkoutStep swim(String kind, String zone, double m) =>
      WorkoutStep(kind: kind, zone: zone, distanceM: m, paceMin: sz.range(zone).$1, paceMax: sz.range(zone).$2);
  PlannedWorkout cssSwim(DateTime d, int reps, {String phase = 'build'}) => plan(Sport.swim, 'tempo', d, [
    swim('warmup', 'REC', 300),
    for (var i = 0; i < reps; i++) ...[
      swim('work', 'CSS', 100),
      if (i < reps - 1) const WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'),
    ],
    swim('cooldown', 'REC', 200),
  ], phase: phase);

  final pw = PowerZones(250);
  WorkoutStep ride(String kind, String zone, int sec) =>
      WorkoutStep(kind: kind, zone: zone, durationSec: sec, powerMin: pw.range(zone).$1, powerMax: pw.range(zone).$2);
  PlannedWorkout thresholdRide(DateTime d, int reps, {String phase = 'build'}) => plan(Sport.ride, 'intervals', d, [
    ride('warmup', 'Z2', 600),
    for (var i = 0; i < reps; i++) ...[ride('work', 'Z4', 600), if (i < reps - 1) ride('recovery', 'Z1', 300)],
    ride('cooldown', 'Z1', 600),
  ], phase: phase);

  /// Session for [p]: [ratio] of the planned volume at [pace] × the planned pace
  /// (1.1 = 10 % slower), optional RPE, HR, power, splits, elevation.
  Session done(
    PlannedWorkout p, {
    double ratio = 1,
    double pace = 1,
    int? rpe,
    int? hr,
    int? power,
    List<int> splits = const [],
    double elevation = 0,
    DateTime? at,
    String? source,
  }) {
    final sec = estimateStepsSec(p.steps.isEmpty ? [WorkoutStep(kind: 'steady', durationSec: p.durationMin * 60)] : p.steps, p.sport, p0);
    var meters = (p.distanceKm ?? 0) * 1000;
    if (p.sport == Sport.swim) meters = p.steps.fold(0.0, (x, s) => x + (s.distanceM ?? 0));
    return Session(
      id: 's${p.id}',
      sport: p.sport,
      title: p.title,
      start: at ?? p.date.add(const Duration(hours: 8)),
      durationSec: (sec * ratio * pace).round(),
      distanceM: meters * ratio,
      rpe: rpe,
      avgHr: hr,
      avgPower: power,
      splits: splits,
      elevationM: elevation * meters / 1000 * ratio,
      planId: p.id,
      source: source,
    );
  }

  PlannedWorkout asDone(PlannedWorkout p, Session s) => PlannedWorkout.fromMap(p.id, {...p.toMap(), 'status': 'done', 'sessionId': s.id});

  // A build week: Sunday long run done, the next two weeks planned.
  final sun = DateTime(2026, 11, 15);
  final now = DateTime(2026, 11, 15, 12);
  DateTime d(int days) => sun.add(Duration(days: days));

  // ───────────────────────────── 1. Session evaluation ─────────────────────────────

  group('session evaluation', () {
    test('long run cut short (5 of 7 km), slow and RPE 7 → harder + incomplete', () {
      final p = longRun(sun, 7);
      final f = evaluateSession(p, done(p, ratio: 5 / 7, pace: 1.08, rpe: 7), p0);
      expect(f.effort, Effort.harder, reason: '$f');
      expect(f.cutShort, isTrue);
      expect(f.reasons, containsAll([FeedbackReason.rpeHigh, FeedbackReason.cutShort]));
      expect(f.belowTarget, isTrue);
      // A slower long run is not "harder" by itself – easy is easy.
      expect(f.signals.firstWhere((s) => s.kind == SignalKind.pace).score, 0);
    });

    test('as planned → as intended, confidence grows with the number of signals', () {
      final p = easyRun(sun, 8);
      final rpeOnly = evaluateSession(p, done(p, rpe: 3), p0);
      final all = evaluateSession(p, done(p, rpe: 3, hr: (hz.zone(2).$1 + hz.zone(2).$2) ~/ 2), p0);
      expect(rpeOnly.effort, Effort.asIntended);
      expect(all.effort, Effort.asIntended);
      expect(all.confidence, greaterThan(rpeOnly.confidence));
    });

    test('missing RPE, heart rate in zone 3+ on an easy run → harder from HR alone', () {
      final p = easyRun(sun, 8);
      final f = evaluateSession(p, done(p, hr: hz.zone(4).$1), p0);
      expect(f.effort, Effort.harder, reason: '$f');
      expect(f.clearlyHarder, isTrue);
      expect(f.reasons, contains(FeedbackReason.hrHigh));
    });

    test('easy run 12 % faster than the easy pace → harder (too fast)', () {
      final p = easyRun(sun, 8);
      final f = evaluateSession(p, done(p, pace: 0.88, rpe: 5), p0);
      expect(f.effort, Effort.harder, reason: '$f');
      expect(f.reasons, contains(FeedbackReason.tooFast));
    });

    test('no HR, no RPE, no pace targets → unrated, only completion', () {
      final p = PlannedWorkout(id: 'x', date: sun, sport: Sport.run, title: 'Run', durationMin: 40, distanceKm: 7, intensity: 'easy');
      final f = evaluateSession(p, done(p, ratio: 0.6), p0);
      expect(f.rated, isFalse);
      expect(f.confidence, 0);
      expect(f.effort, Effort.asIntended);
      expect(f.cutShort, isTrue);
      expect(f.completion, closeTo(0.6, 0.01));
    });

    test('intervals at RPE 4 on target paces → easier', () {
      final p = intervalRun(sun, 5);
      final f = evaluateSession(p, done(p, pace: 0.99, rpe: 4), p0);
      expect(f.effort, Effort.easier, reason: '$f');
      expect(f.clearlyEasier, isTrue);
      expect(f.belowTarget, isFalse);
    });

    test('swim CSS set 10 % slower than the targets at RPE 8 → harder, below target', () {
      final p = cssSwim(sun, 10);
      final f = evaluateSession(p, done(p, pace: 1.10, rpe: 8), p0);
      expect(f.effort, Effort.harder, reason: '$f');
      expect(f.belowTarget, isTrue);
      expect(f.reasons, contains(FeedbackReason.tooSlow));
    });

    test('bike power 8 % above the targets at the intended RPE → above target, not harder', () {
      final p = thresholdRide(sun, 3);
      final target = _avgPower(p);
      final f = evaluateSession(p, done(p, rpe: 7, power: (target * 1.08).round()), p0);
      expect(f.aboveTarget, isTrue);
      expect(f.effort, isNot(Effort.harder));
      expect(f.reasons, contains(FeedbackReason.powerHigh));
    });

    test('pace fade > 5 % between the halves counts as decoupling; hills mute the pace signal', () {
      final p = longRun(sun, 12);
      final e = mid('E');
      final f = evaluateSession(p, done(p, rpe: 4, splits: [for (var i = 0; i < 12; i++) i < 6 ? e : (e * 1.09).round()]), p0);
      expect(f.reasons, contains(FeedbackReason.paceFade));
      final hilly = evaluateSession(p, done(p, pace: 0.85, elevation: 40), p0);
      expect(hilly.signals.where((s) => s.kind == SignalKind.pace), isEmpty);
    });

    test('imported workouts: RPE estimated from HR does not count twice', () {
      final p = easyRun(sun, 8);
      final f = evaluateSession(p, done(p, rpe: 7, hr: hz.zone(2).$1 + 5, source: 'Samsung Health'), p0);
      expect(f.signals.firstWhere((s) => s.kind == SignalKind.rpe).weight, lessThan(0.5));
      expect(f.effort, Effort.asIntended, reason: '$f');
    });
  });

  // ───────────────────────────── 2. Automatic small adjustments ─────────────────────────────

  group('auto adjuster', () {
    (List<PlannedWorkout>, Session) week(PlannedWorkout donePlan, Session s, List<PlannedWorkout> upcoming) => (
      [asDone(donePlan, s), ...upcoming],
      s,
    );

    List<AutoChange> adjust(
      PlannedWorkout donePlan,
      Session s,
      List<PlannedWorkout> upcoming, {
      List<Session> history = const [],
      UserProfile? prof,
    }) {
      final (plans, _) = week(donePlan, s, upcoming);
      return AutoAdjuster(prof ?? p0, plans: plans, sessions: [...history, s], now: now).afterSession(s, plans.first);
    }

    /// 12 runs of 50 min in the last 4 weeks: a solid base for the 10 % rule.
    final base = [
      for (var i = 0; i < 12; i++)
        Session(id: 'h$i', sport: Sport.run, title: 'Run', start: now.subtract(Duration(days: 2 + i * 2)), durationSec: 50 * 60),
    ];

    test('long run cut short 5 of 7 km at RPE 7 → next long runs held at achieved + 10 % / + 20 %, ≥ −15 %', () {
      final l1 = longRun(sun, 7);
      final l2 = longRun(d(7), 8), l3 = longRun(d(14 - 1), 9), easy = easyRun(d(2), 6);
      final c = adjust(l1, done(l1, ratio: 5 / 7, pace: 1.08, rpe: 7), [easy, l2, l3]);
      expect(c.map((x) => x.before.id), [l2.id, l3.id]);
      expect(c.every((x) => x.reason == 'longCutShort'), isTrue);
      expect(c[0].after.distanceKm, closeTo(6.8, 0.11)); // 5.5 wanted, −15 % max per step
      expect(c[1].after.distanceKm, closeTo(7.7, 0.11));
      expect(c[0].after.auto!.distanceKm, 8);
      expect(c[0].after.auto!.sessionId, 's${l1.id}');
    });

    test('cut short, but achieved + 10 % already covers the next (shorter) long run → unchanged, never above plan', () {
      final l1 = longRun(sun, 8);
      final l2 = longRun(d(7), 6.5);
      expect(adjust(l1, done(l1, ratio: 0.78, rpe: 7), [l2]), isEmpty);
    });

    test('long run cut short at the intended effort (lack of time) → no change', () {
      final l1 = longRun(sun, 10);
      final l2 = longRun(d(7), 11);
      expect(adjust(l1, done(l1, ratio: 0.6, rpe: 4), [l2]), isEmpty);
    });

    test('long run complete but too hard → the next one does not grow', () {
      final l1 = longRun(sun, 10);
      final l2 = longRun(d(7), 11);
      final c = adjust(l1, done(l1, rpe: 8), [l2]);
      expect(c.single.reason, 'longHard');
      expect(c.single.after.distanceKm, closeTo(10, 0.11));
    });

    test('easy run too hard by HR (no RPE) → next easy run −10 %; too fast → hint to slow down', () {
      final e1 = easyRun(sun, 8);
      final e2 = easyRun(d(2), 8);
      final byHr = adjust(e1, done(e1, hr: hz.zone(4).$1), [e2]);
      expect(byHr.single.reason, 'easyHard');
      expect(byHr.single.after.distanceKm, closeTo(7.2, 0.11));
      final fast = adjust(e1, done(e1, pace: 0.85, rpe: 6), [e2]);
      expect(fast.single.reason, 'easyTooFast');
    });

    test('intervals too hard (RPE 10) → next quality session held at this volume', () {
      final q1 = intervalRun(sun, 5);
      final q2 = intervalRun(d(4), 6);
      final c = adjust(q1, done(q1, rpe: 10, pace: 1.06), [q2]);
      expect(c.single.reason, 'qualityHard');
      expect(c.single.after.distanceKm! / q2.distanceKm!, greaterThanOrEqualTo(0.85));
      expect(c.single.after.distanceKm!, lessThan(q2.distanceKm!));
    });

    test('intervals too easy on target → +5 % only in loading weeks, with base and no limitation', () {
      final q1 = intervalRun(sun, 5);
      final q2 = intervalRun(d(4), 5);
      final s = done(q1, rpe: 4, pace: 0.98);
      final c = adjust(q1, s, [q2], history: base);
      expect(c.single.reason, 'qualityEasy');
      expect(c.single.after.durationMin, greaterThan(q2.durationMin));
      expect(c.single.after.durationMin / q2.durationMin, lessThanOrEqualTo(1.06));
      // No base (fewer than 3 runs in 4 weeks) → 10 % rule can't be checked → no bump.
      expect(adjust(q1, s, [q2]), isEmpty);
      // Taper / recovery week → no bump.
      final taper = intervalRun(d(4), 5, phase: 'taper');
      expect(adjust(q1, s, [taper], history: base), isEmpty);
      // Heart limitation or knee (run impact) → no bump.
      expect(adjust(q1, s, [q2], history: base, prof: profile(limitations: ['heart'])), isEmpty);
      expect(adjust(q1, s, [q2], history: base, prof: profile(limitations: ['knee'])), isEmpty);
      // Race within 10 days → freshness first.
      final race = PlannedWorkout(id: 'race', date: d(10), sport: Sport.run, title: 'Race', intensity: 'race', distanceKm: 10);
      expect(adjust(q1, s, [q2, race], history: base), isEmpty);
    });

    test('consecutive good sessions → nothing changes', () {
      final e1 = easyRun(sun, 8), q = intervalRun(d(2), 5), l2 = longRun(d(7), 12);
      expect(adjust(e1, done(e1, rpe: 3, hr: hz.zone(2).$1 + 5), [q, l2], history: base), isEmpty);
      final q1 = intervalRun(sun, 5);
      expect(adjust(q1, done(q1, rpe: 8), [intervalRun(d(4), 6)], history: base), isEmpty);
    });

    test('swim CSS set too hard → next CSS set held; bike power above target at low RPE → +5 %', () {
      final s1 = cssSwim(sun, 10), s2 = cssSwim(d(3), 12);
      final sw = adjust(s1, done(s1, pace: 1.10, rpe: 9), [s2]);
      expect(sw.single.reason, 'qualityHard');
      expect(sw.single.after.durationMin, lessThan(s2.durationMin));

      final r1 = thresholdRide(sun, 3), r2 = thresholdRide(d(3), 3);
      final rides = [
        for (var i = 0; i < 8; i++)
          Session(id: 'r$i', sport: Sport.ride, title: 'Ride', start: now.subtract(Duration(days: 2 + i * 3)), durationSec: 80 * 60),
      ];
      final c = adjust(r1, done(r1, rpe: 4, power: (_avgPower(r1) * 1.08).round()), [r2], history: rides);
      expect(c.single.reason, 'qualityEasy');
      expect(c.single.after.durationMin, greaterThan(r2.durationMin));
    });

    test('idempotent per session; undo restores the original; stacking stays within −15 %', () {
      final l1 = longRun(sun, 10);
      final l2 = longRun(d(7), 12);
      final s = done(l1, ratio: 0.5, rpe: 8);
      final (plans, _) = week(l1, s, [l2]);
      final c = AutoAdjuster(p0, plans: plans, sessions: [s], now: now).afterSession(s, plans.first);
      expect(c, hasLength(1));
      final applied = [
        for (final p in plans) p.id == l2.id ? PlannedWorkout.fromMap(p.id, {...p.toMap(), ...c.single.update}) : p,
      ];
      expect(applied.last.auto, isNotNull);
      // Same session again (e.g. the watch import after the phone recording) → nothing.
      expect(AutoAdjuster(p0, plans: applied, sessions: [s], now: now).afterSession(s, applied.first), isEmpty);
      // Undo brings back the generator's workout.
      final undone = AutoAdjuster.undone(applied.last);
      expect(undone.distanceKm, l2.distanceKm);
      expect(undone.durationMin, l2.durationMin);
      expect(undone.steps.map((x) => x.toMap().toString()), l2.steps.map((x) => x.toMap().toString()));
      expect(undone.auto, isNull);
      // A second cut-short long run: the total stays within −15 % of the original.
      final l1b = longRun(d(3), 10);
      final s2 = done(l1b, ratio: 0.4, rpe: 9);
      final again = AutoAdjuster(p0, plans: [...applied, asDone(l1b, s2)], sessions: [s, s2], now: d(3)).afterSession(s2, asDone(l1b, s2));
      for (final x in again) {
        expect(x.after.distanceKm! / l2.distanceKm!, greaterThanOrEqualTo(0.85 - 0.01));
        expect(x.after.auto!.distanceKm, l2.distanceKm, reason: 'keeps the first original for undo');
      }
    });

    test('sanity: hundreds of random sessions never touch race / done / strength and stay in bounds', () {
      final rnd = Random(7);
      final kinds = ['easy', 'long', 'intervals', 'tempo'];
      PlannedWorkout make(String k, DateTime at, {String phase = 'build', String status = 'planned'}) => switch (k) {
        'easy' => easyRun(at, 6 + rnd.nextInt(5).toDouble(), phase: phase, status: status),
        'long' => longRun(at, 10 + rnd.nextInt(8).toDouble(), phase: phase, status: status),
        'intervals' => intervalRun(at, 4 + rnd.nextInt(3), phase: phase, status: status),
        _ => tempoRun(at, 15 + rnd.nextInt(15), phase: phase),
      };
      var changed = 0;
      for (var i = 0; i < 400; i++) {
        final donePlan = make(kinds[rnd.nextInt(4)], sun);
        final phases = ['base', 'build', 'peak', 'taper', 'recovery'];
        final upcoming = [
          for (var j = 1; j <= 10; j++) make(kinds[rnd.nextInt(4)], d(j), phase: phases[rnd.nextInt(5)]),
          make('long', d(3), status: 'done'),
          PlannedWorkout(id: 'race$i', date: d(5), sport: Sport.run, title: 'Race', intensity: 'race', distanceKm: 10, durationMin: 50),
          PlannedWorkout(id: 'gym$i', date: d(2), sport: Sport.gym, title: 'Gym', intensity: 'easy', durationMin: 60),
        ];
        final s = done(
          donePlan,
          ratio: 0.4 + rnd.nextDouble() * 0.8,
          pace: 0.85 + rnd.nextDouble() * 0.3,
          rpe: rnd.nextBool() ? 1 + rnd.nextInt(10) : null,
          hr: rnd.nextBool() ? 110 + rnd.nextInt(70) : null,
          splits: rnd.nextBool() ? [for (var k = 0; k < 8; k++) 300 + rnd.nextInt(60)] : const [],
        );
        final c = adjust(donePlan, s, upcoming, history: base);
        changed += c.length;
        expect(c.length, lessThanOrEqualTo(2));
        for (final x in c) {
          expect(x.before.status, 'planned');
          expect(x.before.sport, Sport.run);
          expect(x.before.intensity, isNot('race'));
          expect(x.before.id, isNot(donePlan.id));
          final o = x.before.distanceKm ?? x.before.durationMin.toDouble();
          final a = x.after.distanceKm ?? x.after.durationMin.toDouble();
          expect(a / o, inInclusiveRange(0.85 - 0.02, 1.10), reason: '${x.reason} $o → $a');
          if (x.before.phase == 'taper' || x.before.phase == 'recovery') expect(a, lessThanOrEqualTo(o));
          // Only a quality session that felt easy may grow; every other rule holds or reduces.
          if (x.reason != 'qualityEasy') expect(a, lessThanOrEqualTo(o), reason: x.reason);
          expect(x.after.intensity, x.before.intensity);
          expect(x.after.steps.map((s) => s.zone).toSet(), x.before.steps.map((s) => s.zone).toSet());
        }
      }
      expect(changed, greaterThan(20), reason: 'the rules do fire in random histories');
    });
  });

  // ───────────────────────────── 3. Recalibrator with evaluations and trends ─────────────────────────────

  group('recalibrator signals', () {
    final templates = defaultTemplates(() => 't${n++}', de: true);
    final start = DateTime(2026, 10, 5); // Monday, 6 weeks before
    final at = DateTime(2026, 11, 16, 7);

    /// Generated plan; every past workout done as planned unless [tweak] changes the
    /// session ([skip] drops it).
    (List<PlannedWorkout>, List<Session>) history(
      UserProfile p, {
      Session Function(PlannedWorkout w, Session s)? tweak,
      bool Function(PlannedWorkout w)? skip,
    }) {
      final gen = PlanGenerator(l, p, templates, () => 'g${n++}').generate(start: start, weeks: 10);
      final plans = <PlannedWorkout>[];
      final sessions = <Session>[];
      for (final w in gen) {
        if (!dayOnly(w.date).isBefore(dayOnly(at)) || (skip?.call(w) ?? false) || w.intensity == 'race') {
          plans.add(w);
          continue;
        }
        var s = done(w, rpe: _defaultRpe(w));
        if (w.sport == Sport.gym) {
          s = Session(id: 's${w.id}', sport: Sport.gym, title: 'Gym', start: w.date, durationSec: 3600, planId: w.id);
        }
        s = tweak?.call(w, s) ?? s;
        sessions.add(s);
        plans.add(asDone(w, s));
      }
      return (plans, sessions);
    }

    Recalibration recal(UserProfile p, (List<PlannedWorkout>, List<Session>) h) =>
        Recalibrator(l, p, plans: h.$1, sessions: h.$2, now: at).run();

    Session copy(Session s, {int? rpe, bool noRpe = false, int? hr, double? pace, int? power}) => Session(
      id: s.id,
      sport: s.sport,
      title: s.title,
      start: s.start,
      durationSec: (s.durationSec * (pace ?? 1)).round(),
      distanceM: s.distanceM,
      rpe: noRpe ? null : (rpe ?? s.rpe),
      avgHr: hr ?? s.avgHr,
      avgPower: power ?? s.avgPower,
      planId: s.planId,
    );

    test('on track with HR in zone → no changes, no new reasons', () {
      final p = profile();
      final r = recal(p, history(p, tweak: (w, s) => w.sport == Sport.run ? copy(s, hr: _hrFor(w, hz)) : s));
      expect(r.reasons, isEmpty, reason: '${r.reasons}');
      expect(r.changes, isEmpty);
    });

    test('missing RPE but HR high on easy runs → counted as too hard (estimated)', () {
      final p = profile();
      final r = recal(
        p,
        history(p, tweak: (w, s) => w.intensity == 'easy' && w.sport == Sport.run ? copy(s, noRpe: true, hr: hz.zone(4).$1 + 2) : s),
      );
      expect(r.stats.estimated, greaterThan(0));
      expect(r.reasons, contains(RecalReason.rpeHigh));
      expect(r.changes.where((c) => c.kind == RecalKind.easier || c.kind == RecalKind.toEasy), isNotEmpty);
    });

    test('key runs slower than target at a high RPE for weeks → VDOT −1, paces eased', () {
      final p = profile();
      final r = recal(
        p,
        history(
          p,
          tweak:
              (w, s) =>
                  w.sport == Sport.run && (w.intensity == 'tempo' || w.intensity == 'intervals' || w.intensity == 'long')
                      ? copy(s, pace: 1.08, rpe: w.intensity == 'long' ? 6 : 9)
                      : s,
        ),
      );
      expect(r.reasons, contains(RecalReason.runTrendSlower));
      expect(r.stats.newVdot, closeTo(r.stats.oldVdot - 1, 0.05));
      final paced = r.changes.where((c) => c.before.sport == Sport.run && c.after.steps.any((s) => s.paceMin != null)).toList();
      expect(paced, isNotEmpty);
      final slower = PaceZones(r.stats.newVdot!);
      for (final c in paced.where((c) => c.kind == RecalKind.paces)) {
        for (final s in c.after.steps.where((s) => s.paceMin != null && s.zone != 'walk')) {
          expect(s.paceMin, slower.range(s.zone).$1);
        }
      }
    });

    test('bike: power above target without extra effort → FTP +3 %, power targets follow', () {
      final p = profile(focus: 'tri');
      final r = recal(
        p,
        history(
          p,
          tweak:
              (w, s) =>
                  w.sport == Sport.ride && (w.intensity == 'tempo' || w.intensity == 'intervals')
                      ? copy(s, power: (_avgPower(w) * 1.08).round(), rpe: 6)
                      : s,
        ),
      );
      expect(r.reasons, contains(RecalReason.ftpUp));
      expect(r.athlete['ftp'], (250 * 1.03).round());
      final rides = r.changes.where((c) => c.before.sport == Sport.ride && c.after.steps.any((s) => s.powerMin != null));
      expect(rides, isNotEmpty);
      final z = PowerZones(r.athlete['ftp'] as int);
      for (final c in rides) {
        for (final s in c.after.steps.where((s) => s.powerMin != null)) {
          expect(s.powerMin, z.range(s.zone).$1);
        }
      }
      // Without an FTP there is nothing to recalibrate.
      final noFtp = profile(focus: 'tri', ftp: null);
      expect(recal(noFtp, history(noFtp)).reasons, isNot(contains(RecalReason.ftpUp)));
    });

    test('swim: faster than the CSS targets at a comfortable effort → CSS −2 s, profile swim times', () {
      final p = profile(focus: 'tri');
      final r = recal(
        p,
        history(
          p,
          tweak: (w, s) => w.sport == Sport.swim && (w.intensity == 'tempo' || w.intensity == 'intervals') ? copy(s, pace: 0.9, rpe: 5) : s,
        ),
      );
      expect(r.reasons, contains(RecalReason.cssFaster), reason: '${r.reasons}');
      expect(SwimZones.fromTests(r.athlete['swim400Sec'], r.athlete['swim200Sec']), 103);
    });

    test('sick week with misses → low completion, no progression', () {
      final p = profile();
      final r = recal(p, history(p, skip: (w) => !dayOnly(w.date).isBefore(at.subtract(const Duration(days: 8)))));
      expect(r.reasons, contains(RecalReason.lowCompletion));
      expect(r.changes.where((c) => c.kind == RecalKind.harder), isEmpty);
      expect(r.reasons, isNot(contains(RecalReason.runTrendFaster)));
    });

    test('aerobic efficiency rising on easy runs (same pace, falling HR) → reported', () {
      final p = profile();
      final r = recal(
        p,
        history(
          p,
          tweak:
              (w, s) =>
                  w.sport == Sport.run && (w.intensity == 'easy' || w.intensity == 'long')
                      ? copy(s, hr: 150 - (w.date.difference(start).inDays ~/ 3))
                      : s,
        ),
      );
      expect(r.stats.efficiency[Sport.run], greaterThan(0.03));
      expect(r.reasons, contains(RecalReason.aerobicUp));
    });
  });
}

/// Time-weighted planned power of a ride (same as the evaluator).
double _avgPower(PlannedWorkout p) {
  var t = 0.0, w = 0.0;
  for (final s in p.steps.where((s) => s.powerMin != null && s.durationSec != null)) {
    t += s.durationSec!;
    w += s.durationSec! * (s.powerMin! + s.powerMax!) / 2;
  }
  return t == 0 ? 200 : w / t;
}

/// Average HR an athlete would show for [p] when it goes as planned.
int _hrFor(PlannedWorkout p, HrZones hz) {
  final z = switch (p.intensity) {
    'tempo' => 3,
    'intervals' => 3,
    _ => 2,
  };
  final (lo, hi) = hz.zone(z);
  return (lo + hi) ~/ 2;
}

int? _defaultRpe(PlannedWorkout w) => switch (w.intensity) {
  'easy' || 'technique' => 3,
  'long' => 4,
  'tempo' => 6,
  'intervals' => 8,
  _ => null,
};
