import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/plan_log.dart';
import 'package:strive/features/home/auto_adjusted_banner.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/gym_tools.dart';
import 'package:strive/services/readiness.dart';
import 'package:strive/services/zones.dart';
import 'package:strive/widgets/effort_chips.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  final now = DateTime(2026, 11, 10, 8);
  final today = dayOnly(now);
  const runner = UserProfile(level: 'intermediate', birthYear: 1990, focus: TrainingFocus.run);
  const duathlete = UserProfile(level: 'intermediate', birthYear: 1990, focus: TrainingFocus.duathlon);

  PlannedWorkout run(String id, int day, {String intensity = 'easy', int min = 50, bool key = false, List<WorkoutStep>? steps}) =>
      PlannedWorkout(
        id: id,
        date: today.add(Duration(days: day)),
        sport: Sport.run,
        title: 'Lauf $id',
        intensity: intensity,
        durationMin: min,
        distanceKm: min / 6,
        isKey: key,
        steps: steps ?? [WorkoutStep(kind: 'steady', zone: 'E', durationSec: min * 60)],
      );

  final intervals = run(
    'iv',
    0,
    intensity: 'intervals',
    min: 60,
    key: true,
    steps: [
      const WorkoutStep(kind: 'warmup', durationSec: 900, zone: 'E'),
      for (var i = 0; i < 6; i++) ...[
        const WorkoutStep(kind: 'work', durationSec: 180, zone: 'I'),
        if (i < 5) const WorkoutStep(kind: 'recovery', durationSec: 120, zone: 'E'),
      ],
      const WorkoutStep(kind: 'cooldown', durationSec: 600, zone: 'E'),
    ],
  );

  GymExercise ex(String id, int sets, {Effort? effort}) =>
      GymExercise(exId: id, name: id, effort: effort, sets: [for (var i = 0; i < sets; i++) GymSet(weight: 50, reps: 8)]);
  final gymPlan = PlannedWorkout(id: 'g', date: today, sport: Sport.gym, title: 'Ganzkörper', durationMin: 60, exercises: [ex('a', 4), ex('b', 3), ex('c', 3)]);

  ReadinessAdvisor advisor(UserProfile p, List<PlannedWorkout> plans) => ReadinessAdvisor(l, p, plans: plans, sessions: const [], now: now);

  group('not feeling 100 %', () {
    test('tired: key workout becomes easy, ~20 % shorter', () {
      final r = advisor(runner, [intervals]).propose(intervals, Readiness.tired);
      final after = r.changes.single.$2;
      expect(after.intensity, 'easy');
      expect(after.isKey, isFalse);
      expect(after.durationMin, 50); // 60 × 0.8, rounded to 5 min
      expect(after.auto, isNull);
      expect(r.hints, [ReadinessHint.keyToEasy]);
    });

    test('tired: easy session gets shorter, stays easy', () {
      final easy = run('e', 0);
      final after = advisor(runner, [easy]).propose(easy, Readiness.tired).changes.single.$2;
      expect(after.intensity, 'easy');
      expect(after.durationMin, inInclusiveRange(35, 40));
    });

    test('little time: shortened to the minutes, warm-up and cool-down kept', () {
      final a = advisor(runner, [intervals]);
      final after = a.propose(intervals, Readiness.time, minutes: 40).changes.single.$2;
      expect(after.durationMin, lessThanOrEqualTo(40));
      expect(after.steps.first.kind, 'warmup');
      expect(after.steps.last.kind, 'cooldown');
      expect(after.steps.where((s) => s.kind == 'work').length, lessThan(6));
      expect(after.steps.where((s) => s.kind == 'work').every((s) => s.durationSec == 180), isTrue, reason: 'repeats keep their length');
      expect(estimateStepsSec(after.steps, Sport.run, runner), lessThanOrEqualTo(44 * 60));
      // Enough time: nothing to change.
      expect(a.propose(intervals, Readiness.time, minutes: 90).isEmpty, isTrue);
    });

    test('pain: run swapped for an easy ride when the athlete rides', () {
      final r = advisor(duathlete, [intervals]).propose(intervals, Readiness.pain);
      final after = r.changes.single.$2;
      expect(after.sport, Sport.ride);
      expect(after.intensity, 'easy');
      expect(r.hints, containsAll([ReadinessHint.swapped, ReadinessHint.seeDoctor]));
    });

    test('pain: runner only → easy and at most 30 min', () {
      final r = advisor(runner, [intervals]).propose(intervals, Readiness.pain);
      final after = r.changes.single.$2;
      expect(after.sport, Sport.run);
      expect(after.intensity, 'easy');
      expect(after.durationMin, lessThanOrEqualTo(30));
      expect(r.hints, contains(ReadinessHint.seeDoctor));
    });

    test('sick: skip today, hard sessions of the next two days become easy', () {
      final easy = run('e', 0), tempo = run('t', 1, intensity: 'tempo', key: true), later = run('l', 3, intensity: 'long');
      final r = advisor(runner, [easy, tempo, later]).propose(easy, Readiness.sick);
      expect(r.changes.first.$2.status, 'skipped');
      expect(r.changes.map((c) => c.$1.id), ['e', 't']);
      expect(r.changes[1].$2.intensity, 'easy');
      expect(r.hints, [ReadinessHint.aboveNeck, ReadinessHint.returnRule]);
    });

    test('gym: tired → a third fewer sets; little time → fits the minutes', () {
      final a = advisor(runner, [gymPlan]);
      final tired = a.propose(gymPlan, Readiness.tired).changes.single.$2;
      expect([for (final e in tired.exercises) e.workSets.length], [3, 2, 2]);
      final short = a.propose(gymPlan, Readiness.time, minutes: 30).changes.single.$2;
      expect(estimateGymMinutes(short.exercises), lessThanOrEqualTo(30));
      expect(short.exercises.first.exId, 'a', reason: 'main lift first');
      expect(short.durationMin, lessThanOrEqualTo(30));
    });
  });

  group('summary RPE prefill from the effort chips', () {
    test('mean of easy 4 / right 6 / hard 8 / limit 10', () {
      expect(sessionRpeFromEfforts([ex('a', 3)]), isNull);
      expect(sessionRpeFromEfforts([ex('a', 3, effort: Effort.right)]), 6);
      expect(sessionRpeFromEfforts([ex('a', 3, effort: Effort.right), ex('b', 3, effort: Effort.hard)]), 7);
      expect(sessionRpeFromEfforts([ex('a', 3, effort: Effort.limit), ex('b', 3)]), 10);
      expect(sessionRpeFromEfforts([ex('a', 3, effort: Effort.easy), ex('b', 3, effort: Effort.easy), ex('c', 3, effort: Effort.hard)]), 5);
    });

    test('reserve chips: RPE = 10 − reps in the tank, 4+ = 6', () {
      expect({for (final (label, r) in reserveChips) label: r}, {'4+': 6.0, '3': 7.0, '2': 8.0, '1': 9.0, '0': 10.0});
      expect(reserveLabel(6), '4+');
      expect(reserveLabel(5), '4+');
      expect(reserveLabel(8), '2');
      expect(reserveLabel(8.5), '1.5');
    });
  });

  group('automatic adjustments: seen tracking', () {
    PlannedWorkout adjusted(String id, Duration ago, {int day = 1, String reason = 'easyHard', String status = 'planned'}) =>
        PlannedWorkout.fromMap(id, {
          ...run(id, day).toMap(),
          'status': status,
          'auto': AutoAdjustment(sessionId: 's', reason: reason, at: now.subtract(ago), durationMin: 55).toMap(),
        });

    test('only recent, unseen, coming automatic changes count', () {
      final fresh = adjusted('a', const Duration(hours: 5));
      final old = adjusted('b', const Duration(hours: 80));
      final recal = adjusted('c', const Duration(hours: 5), reason: 'recal');
      final past = adjusted('d', const Duration(hours: 5), day: -1);
      final done = adjusted('e', const Duration(hours: 5), status: 'done');
      final plain = run('f', 1);
      final plans = [fresh, old, recal, past, done, plain];
      expect(unseenAutoAdjustments(plans, {}, now).map((p) => p.id), ['a']);
      expect(unseenAutoAdjustments(plans, {autoAdjSeenId(fresh)}, now), isEmpty);
      // A new adjustment of the same workout is new again.
      final again = adjusted('a', const Duration(hours: 1));
      expect(unseenAutoAdjustments([again], {autoAdjSeenId(fresh)}, now).map((p) => p.id), ['a']);
    });
  });

  group('plan history', () {
    final before = run('x', 2, min: 50);
    final after = PlannedWorkout.fromMap('x', {...before.toMap(), 'durationMin': 40});
    final added = run('n', 3);
    final entry = PlanLogEntry.fromMap('id', PlanLogEntry.of('recal', [(before, after), (null, added)], at: now).toMap());

    test('round trip keeps before / after', () {
      expect(entry.source, 'recal');
      expect(entry.items.first.beforePlan!.durationMin, 50);
      expect(entry.items.first.afterPlan.durationMin, 40);
      expect(entry.items.last.before, isNull);
    });

    test('undo restores changed workouts and deletes added ones – only while unchanged', () {
      expect(planLogState(entry, {'x': after, 'n': added}), PlanLogState.undoable);
      final u = planLogUndo(entry, {'x': after, 'n': added});
      expect(u.restore.single.durationMin, 50);
      expect(u.delete, ['n']);
      expect(planLogState(entry, {'x': before}), PlanLogState.undone);
      final edited = PlannedWorkout.fromMap('x', {...before.toMap(), 'durationMin': 70});
      expect(planLogItemState(entry.items.first, {'x': edited}), PlanLogState.changed);
      final done = PlannedWorkout.fromMap('x', {...after.toMap(), 'status': 'done'});
      expect(planLogUndo(entry, {'x': done}).restore, isEmpty);
    });
  });
}
