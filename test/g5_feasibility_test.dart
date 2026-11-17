// Regression tests for the audit package G5 (feasibility texts and options): every option the feasibility
// card offers must really fix what it names, and no text may contradict the plan.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/event_sport_x.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';

final en = lookupAppLocalizations(const Locale('en'));
final de = lookupAppLocalizations(const Locale('de'));
var _n = 0;
String _id() => 'x${_n++}';

UserProfile prof(TrainingFocus f, String level, List<int> days, {Map<String, dynamic> a = const {}, int age = 35, int? longDay}) =>
    UserProfile(
      level: level,
      focus: f,
      birthYear: DateTime.now().year - age,
      experience: {...f.sports},
      trainingDays: days,
      longDay: longDay,
    ).copyWith(athlete: const AthleteData().merge(a));

List<String> texts(AppLocalizations l, PlanFeasibility f) => [
  for (final i in FeasibilityCard.shownIssues(f)) FeasibilityCard.issueText(l, f, i),
];

const timeIssues = {'longRunTime', 'longRideTime'};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });
  final start = DateTime(2027, 3, 1); // Monday

  group('UX-1 no race for a sport the plan does not train', () {
    test('a running race does not fit a pure gym focus – a gym athlete is offered hybrid', () {
      expect(eventFitsFocus('10k', TrainingFocus.gym), isFalse);
      expect(eventFitsFocus(null, TrainingFocus.gym), isTrue);
      expect(eventFitsFocus('10k', TrainingFocus.hybrid), isTrue);
      expect(focusForRace('10k', TrainingFocus.gym), TrainingFocus.hybrid);
      expect(focusForRace('m', TrainingFocus.hybrid), TrainingFocus.hybrid);
      expect(focusForRace('olympic', TrainingFocus.gym), TrainingFocus.triathlon);
      expect(focusForRace('ride100', TrainingFocus.run), TrainingFocus.ride);
    });

    test('a gym plan with a stale 10 km race has no race, no shake-out run and no taper leg swap', () {
      final race = DateTime(2027, 6, 27);
      final p = prof(TrainingFocus.gym, 'intermediate', [1, 2, 3, 5, 6], a: {'eventDistance': '10k', 'eventDate': race, 'gymSplit': 'ppl'});
      final plan = PlanGenerator(en, p, const [], _id).generate(start: start);
      expect(plan.where((w) => w.sport != Sport.gym), isEmpty, reason: 'a gym plan holds no run (race / shake-out)');
      expect(plan.where((w) => w.intensity == 'race'), isEmpty);
      expect(PlanGenerator.feasibility(p, start: start, l: en).ok, isTrue);
    });

    test('a ride race on a running plan is not placed either', () {
      final race = DateTime(2027, 6, 27);
      final p = prof(TrainingFocus.run, 'intermediate', [2, 4, 6, 7], a: {'eventDistance': 'ride100', 'eventDate': race});
      final plan = PlanGenerator(en, p, const [], _id).generate(start: start);
      expect(plan.where((w) => w.sport != Sport.run), isEmpty);
      expect(plan.where((w) => w.intensity == 'race'), isEmpty);
    });
  });

  group('FUZZ-10 a race discipline without a session', () {
    for (final ev in ['sprint', 'olympic', '70.3']) {
      test('$ev week without a run day: "no run day", never "0 runs … 0 km"', () {
        final race = DateTime(2027, 7, 4);
        final p = prof(
          TrainingFocus.triathlon,
          'intermediate',
          [2, 4, 6, 7],
          a: {
            'setupMode': 'advanced',
            'dayPlan': <int, List<Sport>>{
              2: [Sport.swim],
              4: [Sport.ride],
              6: [Sport.ride],
              7: [Sport.swim],
            },
            'eventDistance': ev,
            'eventDate': race,
            'sessionMinutes': 90,
          },
        );
        final f = PlanGenerator.feasibility(p, start: start, l: en);
        expect(f.issues, contains('runFrequency'));
        final all = [...texts(en, f), ...texts(de, f)].join('\n');
        expect(all, contains('no run day'));
        expect(all, contains('keinen Lauftag'));
        expect(all, isNot(contains(' 0 km')));
        expect(all, isNot(contains('0 runs')));
        expect(all, isNot(contains('weeks are not enough')));
      });
    }

    test('hybrid marathon without a run day', () {
      final p = prof(
        TrainingFocus.hybrid,
        'intermediate',
        [1, 3, 5],
        a: {
          'setupMode': 'advanced',
          'dayPlan': <int, List<Sport>>{
            1: [Sport.gym],
            3: [Sport.gym],
            5: [Sport.gym],
          },
          'eventDistance': 'm',
          'eventDate': DateTime(2027, 7, 4),
        },
      );
      final f = PlanGenerator.feasibility(p, start: start, l: en);
      expect(f.issues, contains('runFrequency'));
      expect(texts(en, f).join(), contains('at least 4 runs'));
      expect(texts(de, f).join(), contains('mindestens 4 Läufe'));
    });
  });

  group('T6 "N weeks are not enough" only with a later date', () {
    final cases = <(String, UserProfile, DateTime)>[
      (
        'Ironman 30 weeks, 3 days',
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          [2, 4, 6],
          a: {
            'eventDistance': 'ironman',
            'sessionMinutes': 75,
            'dayMinutes': {6: 240, 7: 180},
            'ftp': 210,
            'swim400Sec': 7 * 60 + 40,
            'swim200Sec': 3 * 60 + 35,
          },
        ),
        addDays(start, 7 * 29 + 6),
      ),
      (
        '70.3 beginner 12 weeks, 3 days',
        prof(TrainingFocus.triathlon, 'beginner', [2, 4, 6], a: {'eventDistance': '70.3', 'sessionMinutes': 60}),
        addDays(start, 7 * 11 + 6),
      ),
      (
        'ride160 beginner 16 weeks, 3 days',
        prof(TrainingFocus.ride, 'beginner', [2, 4, 6], a: {'eventDistance': 'ride160', 'sessionMinutes': 45}),
        addDays(start, 7 * 15 + 6),
      ),
      (
        'marathon 8 weeks',
        prof(TrainingFocus.run, 'intermediate', [2, 4, 6, 7], a: {'eventDistance': 'm', 'sessionMinutes': 45}),
        addDays(start, 7 * 7 + 6),
      ),
      (
        'HM beginner 6 weeks',
        prof(TrainingFocus.run, 'beginner', [2, 4, 7], a: {'eventDistance': 'hm', 'sessionMinutes': 30}),
        addDays(start, 7 * 5 + 6),
      ),
    ];
    for (final (name, p0, race) in cases) {
      test(name, () {
        final p = p0.copyWith(athlete: p0.athlete.merge({'eventDate': race}));
        final f = PlanGenerator.feasibility(p, start: start, l: en);
        if (f.issues.contains('tooShort')) expect(f.laterDate, isNotNull, reason: '${f.issues}');
        for (final l in [en, de]) {
          final all = texts(l, f).join('\n');
          if (f.laterDate == null) {
            expect(all, isNot(contains('weeks are not enough')));
            expect(all, isNot(contains('Wochen reichen nicht')));
          }
          expect(all, isNot(contains('about 0 ')));
        }
      });
    }

    test('the later date is the first race week that is long enough', () {
      final race = addDays(start, 7 * 9 + 6);
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [2, 4, 6, 7],
        a: {
          'eventDistance': 'm',
          'eventDate': race,
          'sessionMinutes': 60,
          'dayMinutes': {7: 180},
        },
      );
      final f = PlanGenerator.feasibility(p, start: start, l: en);
      expect(f.laterDate, isNotNull);
      final week = addDays(f.laterDate!, -7);
      final before = PlanGenerator.feasibility(p.copyWith(athlete: p.athlete.merge({'eventDate': week})), start: start, l: en);
      expect(before.issues.any(const {'tooShort', 'longRunRamp', 'runWalk', 'longRunFinish', 'longSwim'}.contains), isTrue);
    });
  });

  group('FUZZ-4 / FUZZ-9 every day option really fixes the time issue', () {
    void checkOptions(UserProfile p, DateTime race) {
      final q = p.copyWith(athlete: p.athlete.merge({'eventDate': race}));
      final f = PlanGenerator.feasibility(q, start: start, l: en);
      if (f.moveDay != null) {
        final moved = PlanGenerator.feasibility(q.copyWith(longDay: f.moveDay), start: start, l: en);
        expect(moved.issues.where(timeIssues.contains), isEmpty, reason: 'move to ${f.moveDay}: ${moved.issues}');
      }
      if (f.raiseDay != null) {
        final raised = PlanGenerator.feasibility(
          q.copyWith(
            athlete: q.athlete.merge({
              'dayMinutes': {...q.athlete.dayMinutes, f.raiseDay!: f.raiseDayMin!, if (f.raiseDay2 != null) f.raiseDay2!: f.raiseDay2Min!},
            }),
          ),
          start: start,
          l: en,
        );
        expect(raised.issues.where(timeIssues.contains), isEmpty, reason: 'raise ${f.raiseDay}: ${raised.issues}');
      }
    }

    test('Ironman Mo/Tu/Th/Fr with a 6 h Monday: moving the long session moves it', () {
      checkOptions(
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          [1, 2, 4, 5],
          a: {
            'eventDistance': 'ironman',
            'sessionMinutes': 90,
            'dayMinutes': {1: 360},
          },
        ),
        DateTime(2027, 9, 12),
      );
    });

    test('duathlon on a single training day: the raise covers run and ride', () {
      final p = prof(TrainingFocus.duathlon, 'beginner', [2], a: {'eventDistance': 'du_sprint', 'sessionMinutes': 45});
      final race = addDays(start, 7 * 11 + 1);
      checkOptions(p, race);
      final f = PlanGenerator.feasibility(p.copyWith(athlete: p.athlete.merge({'eventDate': race})), start: start, l: en);
      if (f.issues.any(timeIssues.contains)) expect(f.raiseDay, isNotNull, reason: '${f.issues}');
    });

    test('sprint triathlon with long run and brick on Sunday', () {
      checkOptions(
        prof(
          TrainingFocus.triathlon,
          'advanced',
          [2, 4, 7],
          a: {
            'setupMode': 'advanced',
            'sessionsPerDay': 2,
            'dayPlan': <int, List<Sport>>{
              2: [Sport.swim],
              4: [Sport.swim, Sport.run],
              7: [Sport.ride, Sport.run],
            },
            'eventDistance': 'sprint',
            'sessionMinutes': 45,
          },
          longDay: 7,
        ),
        addDays(start, 7 * 11 + 6),
      );
    });

    test('detailed duathlon {Sat: ride, Sun: run}: no move to a day without that sport', () {
      checkOptions(
        prof(
          TrainingFocus.duathlon,
          'intermediate',
          [2, 4, 6, 7],
          a: {
            'setupMode': 'advanced',
            'dayPlan': <int, List<Sport>>{
              2: [Sport.run],
              4: [Sport.ride],
              6: [Sport.ride],
              7: [Sport.run],
            },
            'eventDistance': 'du_standard',
            'sessionMinutes': 60,
            'dayMinutes': {7: 240},
          },
          longDay: 6,
        ),
        addDays(start, 7 * 13 + 6),
      );
    });
  });
}
