import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/fitness_state.dart';
import 'package:strive/services/gym_tools.dart' show ProgressionKind;
import 'package:strive/services/health_service.dart';
import 'package:strive/services/insights.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/smart_progression.dart';
import 'package:strive/widgets/plan_amount.dart';

/// Review of "mark as done" (PR #50): the plan's assumed numbers never become a progression
/// step, a record, a quality run or a measured distance; one compliance source; adaptation bands.
const _male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);

GymExercise _squat() =>
    GymExercise(exId: '0043', name: 'barbell full squat', repMin: 5, repMax: 8, sets: [for (var i = 0; i < 3; i++) GymSet(reps: 5)]);

GymExercise _pushUp() =>
    GymExercise(exId: '0662', name: 'push-up', repMin: 8, repMax: 15, sets: [for (var i = 0; i < 3; i++) GymSet(reps: 8)]);

Session _gym(String id, DateTime at, List<GymExercise> ex, {bool fromPlan = false, int? plannedSets}) => Session(
  id: id,
  sport: Sport.gym,
  title: 'Gym',
  start: at,
  durationSec: 3600,
  exercises: ex,
  fromPlan: fromPlan,
  plannedSets: plannedSets,
);

GymExercise _done(String id, String name, List<(double, int)> sets, {bool fromPlan = false, double? rx, int? target, bool? bw}) =>
    GymExercise(
      exId: id,
      name: name,
      rxKg: rx,
      bw: bw,
      fromPlan: fromPlan,
      sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: true, target: target)],
    );

/// [n] taps on "mark as done" for a workout with [ex], two days apart from [from], on top of
/// [history]; the work-set weights and rep targets of every fill.
(List<double>, List<List<int>>, List<Session>) _taps(GymExercise Function() ex, List<Session> history, DateTime from, int n) {
  var h = [...history];
  final weights = <double>[], reps = <List<int>>[];
  for (var i = 0; i < n; i++) {
    final at = from.add(Duration(days: 2 * i));
    final lp = LoadPrescriber(history: h, profile: _male80, now: at);
    final plan = PlannedWorkout(id: 'p$i', date: at, sport: Sport.gym, title: 'Gym', durationMin: 60, exercises: [ex()]);
    final s = sessionFromPlan(plan, PlanFill.of(plan, profile: _male80, prescriber: lp), id: 'f$i', start: at, title: 'Gym');
    expect(s.fromPlan, isTrue);
    final e = s.exercises.single;
    expect(e.fromPlan, isTrue);
    weights.add(e.workSets.first.weight);
    reps.add([for (final x in e.workSets) x.reps]);
    h = [s, ...h];
  }
  return (weights, reps, h);
}

void main() {
  group('1 · load progression: "mark as done" is a hold anchor, never a step', () {
    final from = DateTime(2026, 10, 1, 18);
    final measured = _gym('m', DateTime(2026, 9, 28, 18), [
      _done('0043', 'barbell full squat', [(80, 5), (80, 5), (80, 5)], rx: 80, target: 5),
    ]);

    test('15 taps keep the squat flat (was 80 → 155 kg)', () {
      final (w, reps, _) = _taps(_squat, [measured], from, 15);
      // At most the one step the last measured session earned, then held.
      expect(w.first, inInclusiveRange(80, 85));
      expect(w.toSet(), {w.first}, reason: '$w');
      expect(reps.map((r) => r.join(',')).toSet().length, 1, reason: '$reps');
    });

    test('the hold says why; a measured session afterwards progresses again', () {
      final (w, _, h) = _taps(_squat, [measured], from, 3);
      final at = from.add(const Duration(days: 6));
      final p = LoadPrescriber(history: h, profile: _male80, now: at).forExercise(_squat())!;
      expect(p.progression, ProgressionKind.hold);
      expect(p.reason, ProgressReason.fromPlan);
      expect(p.weight, w.last);
      // The athlete records the workout: the targets met → the progression resumes from it.
      final real = _gym('r', at, [
        _done('0043', 'barbell full squat', [for (var i = 0; i < 3; i++) (w.last, 8)], rx: w.last, target: 5),
      ]);
      final next = LoadPrescriber(history: [real, ...h], profile: _male80, now: at.add(const Duration(days: 2))).forExercise(_squat())!;
      expect(next.weight, greaterThan(w.last));
    });

    test('AMRAP calibration is not ended by assumed reps', () {
      final (_, _, h) = _taps(_squat, const [], from, 5);
      final at = from.add(const Duration(days: 10));
      // No measured session yet: still calibrating (AMRAP on the last set) – the fills don't count.
      final p = LoadPrescriber(history: h, profile: _male80, now: at).forExercise(_squat())!;
      expect(p.amrap, isTrue);
    });

    test('push-ups: taps stay flat (was 8 → 26 reps)', () {
      final first = _gym('m', DateTime(2026, 9, 28, 18), [
        _done('0662', 'push-up', [(0, 12), (0, 12), (0, 12)], target: 12, bw: true),
      ]);
      final (_, reps, _) = _taps(_pushUp, [first], from, 15);
      expect(reps.map((r) => r.join(',')).toSet().length, 1, reason: '$reps');
      expect(reps.first.every((r) => r <= LoadPrescriber.repCap(15)), isTrue);
    });

    test('rep targets never exceed the top of the range + 25 % (measured push-ups)', () {
      expect(LoadPrescriber.repCap(15), 19);
      final h =
          [
            for (var i = 0; i < 3; i++)
              _gym('m$i', DateTime(2026, 9, 20 + 3 * i, 18), [
                _done('0662', 'push-up', [(0, 19), (0, 19), (0, 19)], target: 19, bw: true),
              ]),
          ].reversed.toList();
      final p = LoadPrescriber(history: h, profile: _male80, now: DateTime(2026, 9, 30)).forExercise(_pushUp())!;
      expect(p.reps, lessThanOrEqualTo(19));
      expect(p.setReps.every((r) => r <= 19), isTrue);
      expect(p.reason, ProgressReason.repCap);
    });
  });

  group('2 · records per exercise', () {
    test('only exercises the athlete measured are records', () {
      final s = _gym('s', DateTime(2026, 10, 1), [
        _done('0025', 'barbell bench press', [(100, 5), (100, 5)], fromPlan: true),
        _done('0027', 'barbell bent over row', [(60, 8), (60, 8)]),
      ]);
      expect(s.fromPlan, isFalse);
      expect(exerciseRecords([s]).keys, ['0027']);
      expect(e1rmHistory([s], '0025'), isEmpty);
      expect(e1rmHistory([s], '0027'), hasLength(1));
      expect(newPrs(s, const []), ['barbell bent over row']);
      // Legacy: the whole session from the plan (no per-exercise mark) → nothing.
      final legacy = _gym('l', DateTime(2026, 10, 1), [
        _done('0025', 'barbell bench press', [(100, 5)]),
      ], fromPlan: true);
      expect(exerciseRecords([legacy]), isEmpty);
    });

    test('the per-exercise mark survives storage', () {
      final e = _done('0025', 'barbell bench press', [(100, 5)], fromPlan: true);
      expect(GymExercise.fromMap(e.toMap()).fromPlan, isTrue);
      expect(GymExercise.fromMap(_done('0025', 'x', [(100, 5)]).toMap()).fromPlan, isFalse);
      expect(e.copy().fromPlan, isTrue);
      // A copy for a new workout starts measured.
      expect(e.copy(resetDone: true).fromPlan, isFalse);
    });
  });

  group('3 · no quality run from the plan\'s numbers', () {
    final profile = UserProfile(level: 'intermediate', birthYear: 1990, athlete: const AthleteData(raceTimes: {'10k': 50 * 60}));
    final now = DateTime(2026, 11, 11, 8);
    (List<PlannedWorkout>, List<Session>) tempos({required bool fromPlan}) {
      final plans = <PlannedWorkout>[], sessions = <Session>[];
      for (var i = 0; i < 4; i++) {
        final d = DateTime(2026, 10, 14 + 7 * i);
        final p = PlannedWorkout(
          id: 't$i',
          date: d,
          sport: Sport.run,
          title: 'Tempo',
          durationMin: 40,
          distanceKm: 8,
          intensity: 'tempo',
          phase: 'build',
          status: 'done',
          sessionId: 's$i',
          steps: const [WorkoutStep(kind: 'work', distanceM: 8000, zone: 'T', paceMin: 255, paceMax: 265)],
        );
        plans.add(p);
        // Clearly faster than the targets (≈ 4:00 /km instead of 4:20).
        sessions.add(
          Session(
            id: 's$i',
            sport: Sport.run,
            title: 'Tempo',
            start: d.add(const Duration(hours: 18)),
            durationSec: 8 * 240,
            distanceM: 8000,
            rpe: 7,
            planId: p.id,
            fromPlan: fromPlan,
          ),
        );
      }
      return (plans, sessions);
    }

    test('measured tempo runs count, taken over ones do not', () {
      final (plans, measured) = tempos(fromPlan: false);
      final real = FitnessState.of(profile, plans: plans, sessions: measured, now: now);
      expect(real.qualityRuns, greaterThanOrEqualTo(3));
      final (_, assumed) = tempos(fromPlan: true);
      final f = FitnessState.of(profile, plans: plans, sessions: assumed, now: now);
      expect(f.qualityRuns, 0);
      expect(f.fasterEvidence, isFalse);
      expect(f.trend, isEmpty);
      expect(f.basis, isNot(FitnessBasis.quality));
    });
  });

  group('4–9 · compliance, guards, health and best efforts', () {
    final now = DateTime(2026, 11, 11, 12);

    test('no 0-s session from a plan without a duration', () {
      final p = PlannedWorkout(id: 'r', date: now, sport: Sport.run, title: 'Lauf', durationMin: 0, distanceKm: 5);
      final fill = PlanFill.of(p, profile: _male80);
      expect(fill.minutes, 0);
      final s = sessionFromPlan(p, fill, id: 's', start: now, title: 'Lauf');
      expect(s.durationSec, greaterThan(0));
      final own = sessionFromPlan(p, fill, id: 's', start: now, title: 'Lauf', minutes: 45);
      expect(own.durationSec, 45 * 60);
      // The plan has no duration: the entered one is no deviation.
      expect(own.fromPlan, isTrue);
    });

    test('no division by a zero duration', () {
      final zero = Session(id: 'z', sport: Sport.run, title: 'x', start: now, durationSec: 0, distanceM: 5000);
      expect(runBestEfforts([zero]), isEmpty);
      final p = PlannedWorkout(id: 'r', date: now, sport: Sport.run, title: 'x', durationMin: 30, distanceKm: 5);
      expect(complianceRatio(p, zero)!.isFinite, isTrue);
      final noDistance = PlannedWorkout(id: 'r', date: now, sport: Sport.run, title: 'x', durationMin: 30);
      expect(complianceRatio(noDistance, zero), 0);
    });

    test('"as planned" is 100 %: one source with the display (planAmount)', () {
      final profile = _male80.copyWith(athlete: const AthleteData(raceTimes: {'10k': 50 * 60}));
      final p = PlannedWorkout(
        id: 'q',
        date: now,
        sport: Sport.run,
        title: 'Intervalle',
        durationMin: 45,
        distanceKm: 7,
        intensity: 'intervals',
        steps: const [
          WorkoutStep(kind: 'warmup', durationSec: 900),
          WorkoutStep(kind: 'work', distanceM: 5000, zone: 'T', paceMin: 280, paceMax: 290),
          WorkoutStep(kind: 'cooldown', durationSec: 600),
        ],
      );
      final a = planAmount(p, profile);
      expect(a.km, isNot(7)); // the stored distance differs from the display
      // Marked as done: the plan's own numbers.
      final fill = sessionFromPlan(p, PlanFill.of(p, profile: profile), id: 'f', start: now, title: 'x');
      expect(complianceRatio(p, fill, profile: profile), 1);
      expect(complianceRatio(p, fill), 1);
      expect(planCompliance(p, fill, profile: profile).pct, 100);
      // Recorded with exactly the displayed numbers: 100 %, not 91–94 %.
      final rec = Session(id: 'r', sport: Sport.run, title: 'x', start: now, durationSec: a.minutes * 60, distanceM: a.km! * 1000);
      expect(complianceRatio(p, rec, profile: profile), closeTo(1, 0.005));
      // Structured: the closer of distance and time – recoveries stood still cost distance only.
      final stood = Session(id: 'r', sport: Sport.run, title: 'x', start: now, durationSec: a.minutes * 60, distanceM: a.km! * 800);
      expect(complianceRatio(p, stood, profile: profile), closeTo(1, 0.005));
    });

    test('several sessions of one workout: the one closest to 100 % among those that count', () {
      final p = PlannedWorkout(id: 'p', date: now, sport: Sport.run, title: 'x', durationMin: 60, distanceKm: 10);
      Session run(String id, double km) =>
          Session(id: id, sport: Sport.run, title: 'x', start: now, durationSec: 3600, distanceM: km * 1000, planId: 'p');
      for (final order in [
        ['ok', 'long'],
        ['long', 'ok'],
      ]) {
        final byId = {'ok': run('ok', 10), 'long': run('long', 16), 'abort': run('abort', 0.3)};
        final linked = linkPlanSessions(
          [p],
          [
            for (final id in [...order, 'abort']) byId[id]!,
          ],
        );
        expect(linked['p']!.id, 'ok', reason: '$order');
      }
      // An aborted start never wins over one that counts.
      expect(linkPlanSessions([p], [run('abort', 0.3), run('short', 3)])['p']!.id, 'short');
    });

    test('gym: sets done far lighter / with far fewer reps are partial; taken over = 100 %', () {
      final p = PlannedWorkout(id: 'g', date: now, sport: Sport.gym, title: 'Push', durationMin: 60);
      GymExercise bench(double w, int reps) => _done('0025', 'barbell bench press', [(w, reps), (w, reps), (w, reps)], rx: 100, target: 8);
      expect(complianceRatio(p, _gym('a', now, [bench(100, 8)], plannedSets: 3)), closeTo(1, 1e-9));
      expect(complianceLevelOf(complianceRatio(p, _gym('b', now, [bench(50, 8)], plannedSets: 3))!), ComplianceLevel.yellow);
      expect(complianceRatio(p, _gym('c', now, [bench(100, 4)], plannedSets: 3)), closeTo(0.5, 1e-9));
      // More on one set doesn't make up for a missed one; free sets (no target) count as done.
      expect(complianceRatio(p, _gym('d', now, [bench(120, 10)], plannedSets: 3)), closeTo(1, 1e-9));
      expect(
        complianceRatio(
          p,
          _gym('e', now, [
            _done('x', 'curl', [(10, 5), (10, 5)]),
          ], plannedSets: 2),
        ),
        closeTo(1, 1e-9),
      );
      expect(complianceRatio(p, _gym('f', now, [bench(50, 4)], plannedSets: 3, fromPlan: true)), 1);
    });

    test('Health Connect: no distance for the plan\'s numbers, nothing without a duration', () {
      final fill = Session(id: 'f', sport: Sport.run, title: 'x', start: now, durationSec: 3600, distanceM: 10000, fromPlan: true);
      expect(HealthService.writable(fill), isTrue);
      expect(HealthService.distanceToWrite(fill), isNull);
      final real = Session(id: 'r', sport: Sport.run, title: 'x', start: now, durationSec: 3600, distanceM: 10000);
      expect(HealthService.distanceToWrite(real), 10000);
      expect(HealthService.writable(Session(id: 'z', sport: Sport.run, title: 'x', start: now, durationSec: 0)), isFalse);
    });

    test('best efforts outside the plausible time of the distance are dropped', () {
      Session run(double m, int sec) => Session(id: 'r$sec', sport: Sport.run, title: 'x', start: now, durationSec: sec, distanceM: m);
      // A "5 km" in 8 minutes (GPS jump / a ride logged as a run) and a 5 km in 3 hours.
      expect(runBestEfforts([run(5000, 8 * 60)]), isEmpty);
      expect(runBestEfforts([run(5000, 3 * 3600)]), isEmpty);
      expect(runBestEfforts([run(5000, 25 * 60)])['5k']!.seconds, 25 * 60);
      // Splits: a 1-km split of 1:30 is impossible.
      final splits = Session(
        id: 's',
        sport: Sport.run,
        title: 'x',
        start: now,
        durationSec: 1500,
        distanceM: 5000,
        splits: const [90, 300, 300, 300, 300],
      );
      expect(runBestEfforts([splits]).containsKey('1k'), isFalse);
      expect(plausibleRunEffort('1k', 4 * 60), isTrue);
      expect(plausibleRunEffort('m', 90 * 60), isFalse);
    });
  });

  group('10 · adaptation: key sessions below half are missed, above 150 % a spike', () {
    final now = DateTime(2026, 11, 11, 12);
    final long = PlannedWorkout(
      id: 'l',
      date: DateTime(2026, 11, 8),
      sport: Sport.run,
      title: 'Lang',
      durationMin: 180,
      distanceKm: 30,
      intensity: 'long',
      status: 'done',
      sessionId: 's',
    );
    Session run(double km) => Session(
      id: 's',
      sport: Sport.run,
      title: 'x',
      start: DateTime(2026, 11, 8, 9),
      durationSec: (km * 360).round(),
      distanceM: km * 1000,
      planId: 'l',
    );

    test('4 of 30 km: done in the calendar (orange), missed for the adaptation', () {
      final linked = {'l': run(4)};
      expect(planCompleted(long, linked), isTrue);
      expect(planCompliance(long, linked['l'], now: now).level, ComplianceLevel.orange);
      expect(adaptationCompleted(long, linked), isFalse);
      expect(adaptationCompleted(long, {'l': run(16)}), isTrue);
      // An easy run keeps the calendar rule.
      final easy = PlannedWorkout.fromMap('e', {...long.toMap(), 'intensity': 'easy'});
      expect(adaptationCompleted(easy, {'e': run(4)}), isTrue);
      expect(overPlan(long, run(46)), isTrue);
      expect(overPlan(long, run(44)), isFalse);
    });

    test('long runs far beyond the plan count like too-hard sessions', () {
      final l = lookupAppLocalizations(const Locale('de'));
      var n = 0;
      String id() => 'p${n++}';
      final templates = defaultTemplates(id, de: true);
      final profile = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.run,
        birthYear: 1990,
        trainingDays: const [1, 2, 4, 6, 7],
        longDay: 6,
        athlete: const AthleteData(raceTimes: {'10k': 50 * 60}, runWeeklyKm: 30, longestRunKm: 12, sessionMinutes: 90),
      );
      final start = DateTime(2026, 11, 2), at = DateTime(2026, 11, 16, 7);
      Recalibration recal(double longRatio) {
        final plans = <PlannedWorkout>[], sessions = <Session>[];
        for (final w in PlanGenerator(l, profile, templates, id).generate(start: start, weeks: 6)) {
          if (!dayOnly(w.date).isBefore(dayOnly(at))) {
            plans.add(w);
            continue;
          }
          final r = w.intensity == 'long' ? longRatio : 1.0;
          final s = Session(
            id: 's${w.id}',
            sport: w.sport,
            title: w.title,
            start: w.date.add(const Duration(hours: 18)),
            durationSec: (w.durationMin * 60 * r).round(),
            distanceM: (w.distanceKm ?? 0) * 1000 * r,
            rpe: switch (w.intensity) {
              'tempo' || 'intervals' => 7,
              _ => 4,
            },
            planId: w.id,
          );
          sessions.add(s);
          plans.add(PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'done', 'sessionId': s.id}));
        }
        return Recalibrator(l, profile, plans: plans, sessions: sessions, now: at, fillGaps: false).run();
      }

      expect(recal(1.0).reasons, isNot(contains(RecalReason.rpeHigh)));
      expect(recal(1.7).reasons, contains(RecalReason.rpeHigh));
    });
  });
}
