import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_apply.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/progression_check.dart';

final en = lookupAppLocalizations(const Locale('en'));
final de = lookupAppLocalizations(const Locale('de'));

/// Review of the final-open fixes: race names with / without non-breaking spaces, run/walk retitling twice, the
/// set-aside target on the goal page with race times.
void main() {
  group('automatic race names ignore whitespace (nbsp label vs. names stored with a plain space)', () {
    test('raceLabel never repeats the distance', () {
      for (final key in ['swim1500', '5k', '10k', 'ride100', 'm']) {
        for (final l in [de, en]) {
          final label = eventDistanceLabel(l, key);
          expect(raceLabel(l, key, name: label), label, reason: '$key nbsp');
          expect(raceLabel(l, key, name: label.replaceAll(nbsp, ' ')), label, reason: '$key plain space');
          expect(raceLabel(l, key, name: ' ${label.replaceAll(nbsp, '  ')} '), label, reason: '$key padded');
        }
      }
      expect(raceLabel(de, 'swim1500', name: 'Alster'), 'Alster · ${eventDistanceLabel(de, 'swim1500')}');
    });

    test('isAutoRaceName / ownRaceName', () {
      expect(isAutoRaceName(de, '10k', '10 km'), isTrue);
      expect(isAutoRaceName(de, '10k', '10${nbsp}km'), isTrue);
      expect(isAutoRaceName(de, 'swim1500', 'Freiwasser 1,5 km'), isTrue);
      expect(isAutoRaceName(de, '10k', 'Stadtlauf'), isFalse);
      expect(isAutoRaceName(de, null, '10 km'), isFalse);
      expect(isAutoRaceName(de, '10k', null), isFalse);
      expect(ownRaceName(de, '10k', '10 km'), isNull);
      expect(ownRaceName(de, '10k', '  '), isNull);
      expect(ownRaceName(de, '10k', ' Stadtlauf '), 'Stadtlauf');
    });

    test('a shorter race clears an automatic name stored with a plain space or an nbsp', () {
      for (final name in ['10 km', '10${nbsp}km']) {
        final p = UserProfile(athlete: AthleteData(eventDistance: '10k', eventName: name));
        expect(profileWithFeasibility(p, const FeasShorter('5k'), de)!.athlete.eventName, isNull, reason: name);
      }
      final own = UserProfile(athlete: AthleteData(eventDistance: '10k', eventName: 'Stadtlauf'));
      expect(profileWithFeasibility(own, const FeasShorter('5k'), de)!.athlete.eventName, 'Stadtlauf');
    });
  });

  test('run/walk: retitled twice follows the steps both times (plain space in the stored title)', () {
    PlannedWorkout rw(String title, int reps, int runMin) => PlannedWorkout(
      id: 'w',
      date: DateTime(2026, 11, 18),
      sport: Sport.run,
      title: title,
      steps: [
        for (var i = 0; i < reps; i++) ...[
          const WorkoutStep(kind: 'work', durationSec: 60, zone: 'walk'),
          WorkoutStep(kind: 'work', durationSec: runMin * 60, zone: 'E'),
        ],
      ],
    );
    final first = retitledRunWalk(rw('Run/walk 8 × 1 min', 6, 2));
    expect(first.title, 'Run/walk 6 × 2 min');
    final second = retitledRunWalk(rw(first.title, 4, 1));
    expect(second.title, 'Run/walk 4 × 1 min');
    // A title stored with a non-breaking space (the previous build) still matches.
    expect(retitledRunWalk(rw('Run/walk 6 × 2${nbsp}min', 4, 1)).title, 'Run/walk 4 × 1 min');
  });

  test('goal page: a target the plan sets aside is set aside with race times too (no delta, no status)', () {
    final start = DateTime(2026, 11, 9);
    final p = UserProfile(
      level: 'beginner',
      focus: TrainingFocus.run,
      experience: const {Sport.run},
      trainingDays: const [2, 4, 6, 7],
      athlete: AthleteData(
        runWeeklyKm: 20,
        longestRunKm: 10,
        sessionMinutes: 75,
        eventDistance: 'm',
        eventDate: addDays(start, 7 * 20 - 1),
        targetTimeSec: 4 * 3600 + 30 * 60,
        raceTimes: const {'hm': 2 * 3600 + 15 * 60},
      ),
    );
    expect(PlanGenerator.targetSetAside(p, start: start), isTrue);
    expect(PlanGenerator.feasibility(p, start: start, l: de).issues, contains('targetSetAside'));
    final plans = PlanGenerator(de, p, const [], () => 'x').generate(start: start);
    final f = GoalForecast.of(p, plans: plans, sessions: const [], now: start)!;
    expect(f.setAsideTargetSec, 4 * 3600 + 30 * 60);
    expect(f.targetSec, isNull, reason: 'no delta against a target the plan does not race at');
    expect(f.paceStatus, isNull);
  });
}
