import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/plan_log.dart';

PlannedWorkout _p(String id, int min) =>
    PlannedWorkout(id: id, date: DateTime(2026, 11, 12), sport: Sport.run, title: 'Lauf', durationMin: min, intensity: 'easy');

void main() {
  test('changes of a replaced plan are hidden, duplicates shown once', () {
    final now = DateTime(2026, 11, 10, 11);
    final old = PlanLogEntry.of(
      'readiness',
      [(_p('old1', 45), _p('old1', 35))],
      reason: 'tired',
      at: now.subtract(const Duration(days: 1)),
    );
    final a = PlanLogEntry.of('readiness', [(_p('new1', 45), _p('new1', 30))], reason: 'sick', at: now);
    final dup = PlanLogEntry.of(
      'readiness',
      [(_p('new1', 45), _p('new1', 30))],
      reason: 'sick',
      at: now.subtract(const Duration(minutes: 1)),
    );
    final current = {'new1': _p('new1', 30)};
    final shown = visiblePlanLog([a, dup, old], current);
    expect(shown, [a]);
  });
}
