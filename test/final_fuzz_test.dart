// Regression tests for the final fuzz round (plan_fuzz_test.dart, FUZZ_N = 5000, two seeds).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';

final en = lookupAppLocalizations(const Locale('en'));
var _n = 0;
String _id() => 'x${_n++}';

UserProfile prof(TrainingFocus f, String level, List<int> days, {Map<String, dynamic> a = const {}, int? longDay}) => UserProfile(
  level: level,
  focus: f,
  birthYear: DateTime.now().year - 30,
  experience: {...f.sports},
  trainingDays: days,
  longDay: longDay,
).copyWith(athlete: const AthleteData().merge(a));

/// Endurance minutes of the plan's week [i] (from the Monday of [start]'s week), the race left out.
double weekMin(List<PlannedWorkout> plan, DateTime start, int i) => plan
    .where((w) => w.sport != Sport.gym && w.intensity != 'race' && daysBetween(startOfWeek(start), dayOnly(w.date)) ~/ 7 == i)
    .fold(0.0, (x, w) => x + w.durationMin);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  group('run/walk starter, marathon in 10 weeks (fuzz #264)', () {
    final start = DateTime(2028, 3, 30); // Thursday
    final race = DateTime(2028, 6, 4); // Sunday, 10 weeks
    final p = prof(
      TrainingFocus.run,
      'intermediate',
      [2, 3, 4, 5, 6, 7],
      longDay: 7,
      a: {
        'setupMode': 'advanced',
        'difficulty': 'easy',
        'sessionMinutes': 270,
        'dayPlan': {
          for (final d in [2, 3, 4, 5, 6, 7]) '$d': ['run'],
        },
        'raceTimes': {'5k': 3725, 'm': 38367},
        'runWeeklyKm': 70.0,
        'longestRunKm': 3.5,
        'eventDistance': 'm',
        'eventDate': race,
      },
    );

    test('feasibility blocks the goal and offers a shorter distance that is a goal for the athlete', () {
      final f = PlanGenerator.feasibility(p, start: start, l: en);
      expect(f.issues, contains('runWalkLong'));
      expect(f.shorterDistance, isNotNull);
      final q = PlanGenerator.feasibility(p.copyWith(athlete: p.athlete.merge({'eventDistance': f.shorterDistance})), start: start, l: en);
      expect(q.issues.any(PlanFeasibility.entry.contains), isFalse);
    });

    test('… also when no shorter distance is free of every issue: the longest one without an entry requirement', () {
      // Two run days (the 5 / 10 km need no more – the half marathon needs three).
      final two = p.copyWith(
        trainingDays: [3, 7],
        athlete: p.athlete.merge({
          'dayPlan': {
            '3': ['run'],
            '7': ['run'],
          },
        }),
      );
      final f = PlanGenerator.feasibility(two, start: start, l: en);
      expect(f.issues, contains('runWalkLong'));
      expect(f.shorterDistance, isNotNull, reason: 'an entry requirement always offers a shorter distance');
      final q = PlanGenerator.feasibility(
        two.copyWith(athlete: two.athlete.merge({'eventDistance': f.shorterDistance})),
        start: start,
        l: en,
      );
      expect(q.issues.any(PlanFeasibility.entry.contains), isFalse);
    });

    test('the taper cuts the time – the week before the race clearly below the peak week', () {
      final plan = PlanGenerator(en, p, const [], _id).generate(start: start);
      const rw = 9; // race week (10 weeks: W1 … W10)
      final peak = [for (var i = rw - 6; i <= rw - 2; i++) weekMin(plan, start, i)].reduce((x, y) => x > y ? x : y);
      expect(weekMin(plan, start, rw - 1), lessThan(peak * 0.8));
      expect(weekMin(plan, start, rw), lessThan(peak * 0.75));
    });
  });

  test('no workout after race day when the race week holds no race sport (fuzz #2320)', () {
    final race = DateTime(2027, 11, 2); // Tuesday
    final p = prof(
      TrainingFocus.duathlon,
      'advanced',
      [3],
      a: {
        'setupMode': 'advanced',
        'dayPlan': {
          '3': ['gym'],
        },
        'eventDistance': 'du_sprint',
        'eventDate': race,
      },
    );
    final plan = PlanGenerator(en, p, const [], _id).generate(start: DateTime(2027, 4, 19));
    expect(plan.where((w) => dayOnly(w.date).isAfter(race)), isEmpty);
  });

  test('a sprint beginner swimming once a week builds the 750 m in one go (fuzz #3948)', () {
    final p = prof(
      TrainingFocus.triathlon,
      'beginner',
      [3, 6, 7],
      longDay: 3,
      a: {'sessionMinutes': 240, 'runWeeklyKm': 24.0, 'eventDistance': 'sprint', 'eventDate': DateTime(2029, 3, 7)},
    );
    final start = DateTime(2028, 10, 29);
    final f = PlanGenerator.feasibility(p, start: start, l: en);
    expect(f.issues, isNot(contains('longSwim')));
    final plan = PlanGenerator(en, p, const [], _id).generate(start: start);
    final longest = plan
        .where((w) => w.sport == Sport.swim && w.intensity != 'race')
        .expand((w) => w.steps)
        .where((s) => s.isWork)
        .fold(0.0, (x, s) => s.distanceM != null && s.distanceM! > x ? s.distanceM! : x);
    expect(longest, greaterThanOrEqualTo(700));
  });

  test('feasibility texts never say the long run reaches 0 km', () {
    // One run a week that is the brick run only: no long run in the plan.
    const f = PlanFeasibility(issues: ['runFrequency'], runsPerWeek: 1, minRuns: 2, planLongKm: 0, planLongMin: 0, planLongTargetKm: 7);
    expect(FeasibilityCard.issueText(en, f, 'runFrequency'), isNot(contains('0 km')));
    const g = PlanFeasibility(issues: ['longRunRamp'], weeks: 2, planLongKm: 0, planLongTargetKm: 30);
    expect(FeasibilityCard.issueText(en, g, 'longRunRamp'), isNot(contains('0 km')));
  });
}
