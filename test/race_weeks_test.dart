import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';

/// Race goal with a plan length instead of a date: the race goes on the long-session day of the
/// plan's last week, and the plan builds up to it like for a dated race.
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'w${n++}';

  UserProfile profile(
    TrainingFocus focus,
    String event, {
    List<int> days = const [1, 3, 5, 6],
    int? longDay,
    Map<int, int> dayMinutes = const {},
    Map<int, List<Sport>>? dayPlan,
    Set<Sport> experience = const {Sport.run, Sport.ride, Sport.swim},
  }) => UserProfile(
    level: 'intermediate',
    focus: focus,
    birthYear: 1990,
    experience: experience,
    trainingDays: days,
    longDay: longDay,
    athlete: AthleteData(
      setupMode: dayPlan == null ? 'simple' : 'advanced',
      sessionsPerDay: dayPlan != null && dayPlan.values.any((v) => v.length > 1) ? 2 : 1,
      dayPlan: dayPlan ?? const {},
      sessionMinutes: 75,
      dayMinutes: dayMinutes,
      raceTimes: const {'10k': 2880},
      ftp: 220,
      swim400Sec: 420,
      swim200Sec: 200,
      eventDistance: event,
    ),
  );

  final cases = <String, UserProfile>{
    'run, half marathon (quick setup, last day = long day)': profile(TrainingFocus.run, 'hm', days: const [2, 4, 6]),
    'run, marathon, Sunday chosen as long day': profile(TrainingFocus.run, 'm', days: const [1, 3, 5, 7], longDay: 7),
    'run, 10 km, the day with the most time is the long day': profile(
      TrainingFocus.run,
      '10k',
      days: const [2, 4, 6, 7],
      dayMinutes: const {6: 150},
    ),
    'ride, 100 km': profile(TrainingFocus.ride, 'ride100', days: const [2, 4, 6, 7]),
    'swim, 1500 m open water': profile(TrainingFocus.swim, 'swim1500', days: const [1, 3, 5]),
    'triathlon, olympic (long ride on the long day)': profile(TrainingFocus.triathlon, 'olympic', days: const [1, 2, 3, 4, 6, 7]),
    'triathlon, 70.3, detailed week with two sessions a day': profile(
      TrainingFocus.triathlon,
      '70.3',
      days: const [2, 4, 6, 7],
      longDay: 6,
      dayPlan: const {
        2: [Sport.swim, Sport.run],
        4: [Sport.ride],
        6: [Sport.swim, Sport.ride],
        7: [Sport.run],
      },
    ),
    'duathlon, standard': profile(TrainingFocus.duathlon, 'du_standard', days: const [1, 3, 5, 6]),
    'hybrid, half marathon (gym days do not count)': profile(TrainingFocus.hybrid, 'hm', days: const [1, 2, 4, 6]),
  };

  // Wednesday, Saturday and Sunday starts: the start's week is week 1 whatever the weekday.
  final starts = [DateTime(2026, 11, 11), DateTime(2026, 11, 14), DateTime(2026, 11, 15)];

  for (final e in cases.entries) {
    test('${e.key}: race on the long day of the last week, plan builds up to it', () {
      final p = e.value;
      final longDay = PlanGenerator.longDayOf(p);
      expect(longDay, isNotNull);
      for (final start in starts) {
        for (final weeks in [4, 8, 12, 16]) {
          final race = PlanGenerator.raceDayForWeeks(p, start, weeks);
          expect(race.weekday, longDay, reason: '$start, $weeks weeks');
          expect(GoalModel.weeksUntil(race, start), weeks, reason: 'exactly $weeks plan weeks ($start)');
          expect(race.isAfter(start), isTrue);
          expect(race, dayOnly(race));
        }
      }

      // Generated like a dated race: race day on that date, the plan's long session on that weekday,
      // a taper before it, nothing after it.
      final start = starts.first;
      final race = PlanGenerator.raceDayForWeeks(p, start, 12);
      final q = p.copyWith(athlete: p.athlete.merge({'eventDate': race}));
      final plan = PlanGenerator(l, q, const [], id).generate(start: start);
      final raceDay = plan.where((w) => w.intensity == 'race').toList();
      expect(raceDay, isNotEmpty);
      expect(raceDay.every((w) => sameDay(w.date, race)), isTrue);
      expect(plan.where((w) => w.date.isAfter(race)), isEmpty);
      expect(plan.any((w) => w.phase == 'taper'), isTrue);
      // A build week well before race day: the plan's long session (the triathlon's long ride, the
      // 1500 m continuous swim) is on the race weekday – the race takes its place in the last week.
      final week = addDays(startOfWeek(start), 7 * 5);
      final inWeek = plan.where((w) => w.sport != Sport.gym && !w.date.isBefore(week) && w.date.isBefore(addDays(week, 7))).toList();
      final longs = inWeek.where((w) => w.intensity == 'long').toList();
      expect(longs.map((w) => w.date.weekday), contains(longDay));
      final longest = longs.fold<int>(0, (x, w) => max(x, w.durationMin));
      expect(longs.firstWhere((w) => w.date.weekday == longDay).durationMin, longest, reason: 'the longest of the long sessions');
    });
  }

  test('without an endurance day the last training day, else Saturday', () {
    final gym = UserProfile(level: 'beginner', focus: TrainingFocus.gym, birthYear: 1990, trainingDays: const [1, 3]);
    final r = PlanGenerator.raceDayForWeeks(gym, DateTime(2026, 11, 11), 4);
    expect(r.weekday, PlanGenerator.scheduleOf(gym).keys.reduce(max));
  });
}
