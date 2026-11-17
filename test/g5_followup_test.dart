// Regression tests for the verifier's follow-up of the audit package G5: no race for a sport the week does not
// hold, one cause per long-session limit, race minimums in the quick week, true texts for time-limited long
// rides, the calendar back at the current week after a new plan.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/schedule_advisor.dart';

final en = lookupAppLocalizations(const Locale('en'));
final de = lookupAppLocalizations(const Locale('de'));
var _n = 0;
String _id() => 'x${_n++}';

UserProfile prof(
  TrainingFocus f,
  String level,
  List<int> days, {
  Map<String, dynamic> a = const {},
  int age = 35,
  int? longDay,
  List<String> goals = const [],
}) => UserProfile(
  level: level,
  focus: f,
  birthYear: DateTime.now().year - age,
  experience: {...f.sports},
  trainingDays: days,
  longDay: longDay,
  goals: goals,
).copyWith(athlete: const AthleteData().merge(a));

/// A detailed setup with this day plan.
Map<String, dynamic> detailed(Map<int, List<Sport>> plan, {int perDay = 1}) => {
  'setupMode': 'advanced',
  'sessionsPerDay': perDay,
  'dayPlan': plan,
};

const timeIssues = {'longRunTime', 'longRideTime'};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });
  final start = DateTime(2026, 11, 30); // Monday

  group('UX-1 no race for a sport the week does not hold', () {
    test('hybrid with a gym-only day plan and a 10 km: no run, no shake-out, no race', () {
      final race = DateTime(2027, 3, 14);
      final p = prof(
        TrainingFocus.hybrid,
        'intermediate',
        [2, 4, 6],
        a: {
          ...detailed({
            2: [Sport.gym],
            4: [Sport.gym],
            6: [Sport.gym],
          }),
          'eventDistance': '10k',
          'eventDate': race,
        },
      );
      final plan = PlanGenerator(de, p, const [], _id).generate(start: start);
      expect(plan, isNotEmpty);
      expect(plan.where((w) => w.sport != Sport.gym).map((w) => '${dayKey(w.date)} ${w.title}'), isEmpty);
      expect(plan.where((w) => w.intensity == 'race'), isEmpty);
      // The plan check still says why: the week has no run day.
      expect(PlanGenerator.feasibility(p, start: start, l: de).issues, contains('runFrequency'));
    });

    test('ride focus with a gym-only day plan and a 100 km ride: no ride, no shake-out, no race', () {
      final race = DateTime(2027, 5, 16);
      final p = prof(
        TrainingFocus.ride,
        'intermediate',
        [1, 3, 5],
        a: {
          ...detailed({
            1: [Sport.gym],
            3: [Sport.gym],
            5: [Sport.gym],
          }),
          'eventDistance': 'ride100',
          'eventDate': race,
        },
      );
      final plan = PlanGenerator(en, p, const [], _id).generate(start: start);
      expect(plan.where((w) => w.sport == Sport.ride), isEmpty);
      expect(plan.where((w) => w.intensity == 'race'), isEmpty);
    });

    test('a triathlon week without a run day: the race stays, its shake-out is a ride, never a run', () {
      final race = DateTime(2027, 6, 27); // Sunday
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        [2, 4, 6, 7],
        a: {
          ...detailed({
            2: [Sport.swim],
            4: [Sport.ride],
            6: [Sport.swim],
            7: [Sport.ride],
          }),
          'eventDistance': 'sprint',
          'eventDate': race,
        },
      );
      final plan = PlanGenerator(en, p, const [], _id).generate(start: DateTime(2027, 3, 1));
      expect(plan.where((w) => w.intensity == 'race').single.date, race);
      final dayBefore = plan.where((w) => sameDay(w.date, addDays(race, -1))).toList();
      expect(dayBefore.map((w) => w.sport), [Sport.ride], reason: 'the shake-out in a sport the week trains');
      expect(plan.where((w) => w.sport == Sport.run), isEmpty);
    });

    test('a run week keeps its race and shake-out run', () {
      final race = DateTime(2027, 3, 14);
      final p = prof(TrainingFocus.hybrid, 'intermediate', [2, 4, 6, 7], a: {'eventDistance': '10k', 'eventDate': race});
      final plan = PlanGenerator(en, p, const [], _id).generate(start: start);
      expect(plan.where((w) => w.intensity == 'race').single.date, race);
      expect(plan.where((w) => sameDay(w.date, addDays(race, -1)) && w.sport == Sport.run), hasLength(1));
    });
  });

  group('T6 one cause per long-session limit', () {
    test('70.3 beginner Mo/We/Fr 12 weeks: the frequency issues name the limit, no ramp texts on top', () {
      final from = DateTime(2027, 3, 1);
      final p = prof(TrainingFocus.triathlon, 'beginner', [1, 3, 5], a: {'eventDistance': '70.3', 'eventDate': addDays(from, 7 * 11 + 6)});
      for (final l in [de, en]) {
        final f = PlanGenerator.feasibility(p, start: from, l: l);
        if (f.issues.contains('runFrequency')) expect(f.issues, isNot(contains('longRunRamp')), reason: '${f.issues}');
        if (f.issues.contains('rideFrequency')) expect(f.issues, isNot(contains('longRideRamp')), reason: '${f.issues}');
        expect(f.issues.where((i) => i.endsWith('Frequency')), isNotEmpty, reason: '${f.issues}');
        expect(f.issues, isNot(contains('tooShort')), reason: 'no later date helps – the frequency is the limit');
      }
    });

    test('over races, levels and weeks: never a frequency issue next to the ramp of the same sport', () {
      final from = DateTime(2027, 3, 1);
      for (final ev in ['70.3', 'olympic', 'ironman', 'du_standard', 'm']) {
        final focus = ev == 'm' ? TrainingFocus.hybrid : (ev.startsWith('du') ? TrainingFocus.duathlon : TrainingFocus.triathlon);
        for (final lv in ['beginner', 'intermediate']) {
          for (final days in const [
            [1, 3, 5],
            [2, 4, 6, 7],
          ]) {
            for (final weeks in const [8, 12, 20]) {
              final p = prof(focus, lv, days, a: {'eventDistance': ev, 'eventDate': addDays(from, 7 * (weeks - 1) + 6)});
              final f = PlanGenerator.feasibility(p, start: from, l: en);
              final why = '$ev $lv $days $weeks: ${f.issues}';
              expect(f.issues.contains('runFrequency') && f.issues.contains('longRunRamp'), isFalse, reason: why);
              expect(f.issues.contains('rideFrequency') && f.issues.contains('longRideRamp'), isFalse, reason: why);
            }
          }
        }
      }
    });
  });

  group('UX-4 the quick week follows the race minimums', () {
    // The quick setup's recommendation: the advisor's days, the generator's week on them (onboarding _schedule).
    UserProfile recommended(UserProfile p) {
      final quick = p.copyWith(athlete: p.athlete.merge({'setupMode': 'simple', 'sessionsPerDay': 1}));
      final sports = {...p.focus.sports, if (p.goals.contains('strength')) Sport.gym};
      final adv = ScheduleAdvisor(quick, sports);
      final days = adv.autoSchedule(adv.recommended()).keys.toList()..sort();
      return UserProfile.fromMap({...quick.toMap(), 'trainingDays': days, 'longDay': days.contains(6) ? 6 : null});
    }

    test('following the recommendation gives no frequency issue (multisport focuses, single-sport races)', () {
      for (final (focus, ev, levels) in [
        (TrainingFocus.duathlon, 'm', ['intermediate', 'advanced']),
        (TrainingFocus.duathlon, 'ultra50', ['intermediate', 'advanced']),
        (TrainingFocus.duathlon, 'hm', ['beginner']),
        (TrainingFocus.duathlon, 'ride160', ['beginner', 'intermediate', 'advanced']),
        (TrainingFocus.triathlon, 'hm', ['beginner', 'intermediate', 'advanced']),
        (TrainingFocus.triathlon, 'm', ['intermediate', 'advanced']),
        (TrainingFocus.triathlon, 'ride160', ['beginner', 'intermediate', 'advanced']),
        (TrainingFocus.triathlon, 'swim1500', ['intermediate']),
        (TrainingFocus.triathlon, 'swim3800', ['beginner', 'intermediate', 'advanced']),
        (TrainingFocus.triathlon, 'swim5000', ['intermediate', 'advanced']),
        (TrainingFocus.hybrid, 'hm', ['beginner', 'intermediate']),
        (TrainingFocus.hybrid, 'm', ['intermediate']),
      ]) {
        for (final lv in levels) {
          for (final goals in const [
            <String>[],
            ['strength'],
          ]) {
            final p = recommended(prof(focus, lv, const [], goals: goals, a: {'eventDistance': ev, 'eventDate': DateTime(2027, 9, 26)}));
            final f = PlanGenerator.feasibility(p, start: DateTime(2027, 3, 1), l: en);
            expect(
              f.issues.where((i) => i.endsWith('Frequency')),
              isEmpty,
              reason: '$focus $ev $lv $goals ${PlanGenerator.scheduleOf(p)} ${f.issues}',
            );
          }
        }
      }
    });

    test('the quick week of a duathlon marathon on 6 days: 4 runs, the rides keep one day', () {
      final p = prof(
        TrainingFocus.duathlon,
        'intermediate',
        [1, 2, 3, 4, 5, 6],
        a: {'eventDistance': 'm', 'eventDate': DateTime(2027, 9, 26)},
      );
      final week = PlanGenerator.scheduleOf(p).values.expand((v) => v).toList();
      expect(week.where((s) => s == Sport.run), hasLength(4));
      expect(week.where((s) => s == Sport.ride), hasLength(2));
    });

    test('without a race (or one the counts already meet) the quick week is unchanged', () {
      final p = prof(TrainingFocus.triathlon, 'intermediate', [1, 2, 3, 4, 5, 6]);
      final week = PlanGenerator.scheduleOf(p).values.expand((v) => v).toList();
      for (final s in [Sport.swim, Sport.ride, Sport.run]) {
        expect(week.where((x) => x == s), hasLength(2), reason: '$s');
      }
    });

    test('a beginner 70.3 at one session a day: the setup says the minimum needs two a day', () {
      final p = prof(
        TrainingFocus.triathlon,
        'beginner',
        const [],
        a: {'setupMode': 'advanced', 'sessionsPerDay': 1, 'eventDistance': '70.3', 'eventDate': DateTime(2027, 9, 26)},
      );
      final adv = ScheduleAdvisor(p, {Sport.swim, Sport.ride, Sport.run});
      expect(adv.raceMinSessions, 6);
      expect(adv.raceMinSessions, greaterThan(adv.maxDays));
      expect(de.recMinNoFit(6, 5), contains('Bis zu 2× pro Tag'));
      // Two a day fits the minimum.
      final adv2 = ScheduleAdvisor(p.copyWith(athlete: p.athlete.merge({'sessionsPerDay': 2})), {Sport.swim, Sport.ride, Sport.run});
      final rec = adv2.recommended();
      expect(rec[Sport.swim], greaterThanOrEqualTo(2), reason: '$rec');
    });
  });

  group('FUZZ-4 a long ride the day time limits: an option that works, never a false time text', () {
    // Fuzz #0: duathlon, Sunday run + ride, Friday ride + run – raising Friday alone made it the long day and
    // moved the long ride to Sunday's short slot.
    test('fuzz #0: the raise keeps the long day, and it resolves the long ride', () {
      final p = prof(
        TrainingFocus.duathlon,
        'advanced',
        [3, 4, 5, 7],
        age: 65,
        a: {
          ...detailed({
            7: [Sport.run, Sport.ride],
            3: [Sport.ride],
            5: [Sport.ride, Sport.run],
            4: [Sport.gym, Sport.ride],
          }, perDay: 2),
          'sessionMinutes': 60,
          'dayMinutes': {6: 20},
          'longestRunKm': 24.0,
          'eventDistance': 'du_sprint',
          'eventDate': DateTime(2027, 9, 5),
        },
      );
      final from = DateTime(2027, 1, 1);
      final f = PlanGenerator.feasibility(p, start: from, l: en);
      if (!f.issues.contains('longRideTime')) return; // (not time-limited in this setup any more)
      expect(f.raiseDay ?? f.moveDay, isNotNull, reason: 'an option for the time-limited long ride: ${f.issues}');
      if (f.raiseDay != null) {
        final dm = {...p.athlete.dayMinutes, f.raiseDay!: f.raiseDayMin!, if (f.raiseDay2 != null) f.raiseDay2!: f.raiseDay2Min!};
        final f2 = PlanGenerator.feasibility(p.copyWith(athlete: p.athlete.merge({'dayMinutes': dm})), start: from, l: en);
        expect(
          f2.issues.where(timeIssues.contains),
          isEmpty,
          reason: '${f.raiseDay}/${f.raiseDayMin} ${f.raiseDay2}/${f.raiseDay2Min}: ${f2.issues}',
        );
      }
    });

    // Fuzz #1478: Ironman, Thursday ride + swim (105 min) – raising Thursday made it the long day and the long
    // run lost Sunday's time.
    test('fuzz #1478: raising the long-ride day keeps Sunday as the long day', () {
      final p = prof(
        TrainingFocus.triathlon,
        'advanced',
        [2, 4, 7],
        age: 41,
        a: {
          ...detailed({
            2: [Sport.run],
            4: [Sport.ride, Sport.swim],
            7: [Sport.run, Sport.ride],
          }, perDay: 2),
          'sessionMinutes': 105,
          'dayMinutes': {4: 105},
          'runWeeklyKm': 8.0,
          'ftp': 179,
          'eventDistance': 'ironman',
          'eventDate': DateTime(2027, 7, 25),
          'limitations': ['hip'],
        },
      );
      final from = DateTime(2027, 3, 29);
      final f = PlanGenerator.feasibility(p, start: from, l: de);
      // (Since G2's day selection by dayMinutes the long ride goes on Sunday – the day with the most time – and
      // Thursday's 105 min no longer limit it: no time issue at all is the better outcome. Otherwise the option
      // must work.)
      if (!f.issues.any(timeIssues.contains)) {
        expect(PlanGenerator.longSessionDays(p)[Sport.ride], 7, reason: '${f.issues}');
        return;
      }
      expect(f.raiseDay, isNotNull, reason: '${f.issues}');
      final dm = {...p.athlete.dayMinutes, f.raiseDay!: f.raiseDayMin!, if (f.raiseDay2 != null) f.raiseDay2!: f.raiseDay2Min!};
      final f2 = PlanGenerator.feasibility(p.copyWith(athlete: p.athlete.merge({'dayMinutes': dm})), start: from, l: de);
      expect(f2.issues.where(timeIssues.contains), isEmpty, reason: '${f2.issues}');
    });

    // Fuzz #1957: Ironman in 6 weeks, one ride a week – the long ride (≤ 80 min) is far below the day's 195 min:
    // the time is not the limit, "the day allows only 195 min" was false.
    test('fuzz #1957: a long ride the volume keeps short is no time issue', () {
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        [1, 2, 3, 4, 5, 6, 7],
        age: 56,
        goals: const ['strength'],
        a: {
          ...detailed({
            1: [Sport.run, Sport.gym],
            3: [Sport.run, Sport.ride],
            7: [Sport.run],
            6: [Sport.gym, Sport.run],
            5: [Sport.gym],
            2: [Sport.gym, Sport.swim],
            4: [Sport.run],
          }, perDay: 2),
          'sessionMinutes': 270,
          'dayMinutes': {1: 135, 2: 360},
          'raceTimes': {'10k': 2181, 'm': 10074},
          'runWeeklyKm': 116.0,
          'longestRunKm': 11.0,
          'eventDistance': 'ironman',
          'eventDate': DateTime(2027, 3, 23),
          'limitations': ['knee'],
        },
      );
      final from = DateTime(2027, 2, 19);
      final f = PlanGenerator.feasibility(p, start: from, l: en);
      expect(f.issues, isNot(contains('longRideTime')), reason: '${f.issues}');
      expect(f.issues, contains('rideFrequency'), reason: 'one ride a week is the limit');
      final plan = PlanGenerator(en, p, const [], _id).generate(start: from);
      final longest = plan
          .where((w) => w.sport == Sport.ride && w.intensity == 'long')
          .fold(0, (x, w) => w.durationMin > x ? w.durationMin : x);
      for (final t in [for (final i in FeasibilityCard.shownIssues(f)) FeasibilityCard.issueText(en, f, i)]) {
        expect(t, isNot(contains('allows only')), reason: 'longest long ride $longest\': $t');
      }
    });
  });
}
