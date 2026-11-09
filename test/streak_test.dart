import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/insights.dart';

Session _s(DateTime d) => Session(id: '${d.millisecondsSinceEpoch}', sport: Sport.run, title: 'Run', start: d, durationSec: 1800);
PlannedWorkout _p(DateTime d) => PlannedWorkout(id: 'p${d.millisecondsSinceEpoch}', date: d, sport: Sport.run, title: 'Run');

void main() {
  final thisWeek = startOfWeek(DateTime.now());
  final lastWeek = thisWeek.subtract(const Duration(days: 7));

  test('plan days define the weekly goal (two sessions on one day = one day)', () {
    final plans = [_p(lastWeek), _p(lastWeek), _p(lastWeek.add(const Duration(days: 2)))];
    expect(GameStats.weekGoal(lastWeek, 6, plans), 2);
    expect(GameStats.weekGoal(lastWeek, 6, const []), 6);
  });

  test('streak counts weeks that met their goal, current week never breaks it', () {
    final plans = [_p(lastWeek), _p(lastWeek.add(const Duration(days: 3)))];
    final sessions = [_s(lastWeek.add(const Duration(hours: 8))), _s(lastWeek.add(const Duration(days: 3, hours: 8)))];
    // Profile says 6 training days, but last week's plan only had 2 days → met.
    expect(GameStats.computeWeekStreak(sessions, 6, plans: plans), 1);
    // Without the plan the 6-day goal is missed.
    expect(GameStats.computeWeekStreak(sessions, 6), 0);
  });
}
