// Regression tests for the audit package G5 (texts and UX): plurals, one term for the recovery week, texts
// relocalised in the plan history, the coach's week, the setup's recommendation, XP after a correction.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/l10n/relocalize.dart';
import 'package:strive/services/coach_service.dart';
import 'package:strive/services/insights.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_text.dart';
import 'package:strive/services/schedule_advisor.dart';

final en = lookupAppLocalizations(const Locale('en'));
final de = lookupAppLocalizations(const Locale('de'));

void main() {
  group('T10 counts are plurals', () {
    test('countdowns', () {
      expect(countdownText(de, 1), '1 Tag');
      expect(countdownText(en, 1), '1 day');
      expect(countdownText(de, 5), '5 Tage');
      expect(countdownText(de, 0), de.goalCountdownToday);
      expect(de.daysLeftInline(1), 'noch 1 Tag');
      expect(en.daysLeftInline(1), '1 day left');
      expect(de.daysLeft(1), 'Noch 1 Tag');
      expect(de.planAligned(1), 'Plan ausgerichtet: 1 Woche bis zum Wettkampf');
      expect(en.planAligned(3), 'Plan aligned: 3 weeks to race day');
    });

    test('other counts that can be 1', () {
      expect(de.planCreated(1), '1 Einheit geplant');
      expect(en.nWorkouts(1), '1 workout');
      expect(de.timeCustomDays(1), '1 Tag individuell festgelegt');
      expect(de.sessionsPerWeekN(1), '1 Einheit / Woche');
      expect(en.daysPerWeek(1), '1 day per week');
      expect(de.generatePlanSub('Laufen', 1), contains('1 Tag/Woche'));
    });

    test('T5 pre-plan sentence: plural and the generator\'s own block length', () {
      expect(de.planToEventPre(21, 1, 20), contains('zuerst 1 Woche Grundlagenaufbau'));
      expect(en.planToEventPre(21, 1, 20), contains('1 week of base building'));
      UserProfile p(TrainingFocus f, String ev) => UserProfile(focus: f, athlete: AthleteData(eventDistance: ev));
      expect(PlanGenerator.specificWeeksFor(p(TrainingFocus.triathlon, 'ironman')), 30);
      expect(PlanGenerator.specificWeeksFor(p(TrainingFocus.run, 'ultra50')), 24);
      expect(PlanGenerator.specificWeeksFor(p(TrainingFocus.run, 'm')), 20);
      // A race 26 weeks away is all race-specific for an Ironman – no "6 weeks of base first".
      final weeks = PlanGenerator.phasesFor(
        p(TrainingFocus.triathlon, 'ironman').copyWith(athlete: AthleteData(eventDistance: 'ironman', eventDate: DateTime(2027, 8, 29))),
        start: DateTime(2027, 3, 1),
      );
      expect(weeks.length, 26);
    });
  });

  group('T9 / T14 gym loading-week note', () {
    test('"1 rep", and the lighter week is the recovery week', () {
      expect(gymLoadNote(en, 1), contains('about 1 rep in the tank'));
      expect(gymLoadNote(en, 1), contains('until the next recovery week'));
      expect(gymLoadNote(en, 2), contains('about 2 reps in the tank'));
      expect(gymLoadNote(en, 2), isNot(contains('deload')));
      expect(gymLoadNote(en, 1, deloadAhead: false), contains('about 1 rep in reserve'));
      expect(gymLoadNote(de, 1), contains('1 Wdh. im Tank'));
      expect(en.termDeloadTitle, 'Recovery week');
      expect(de.recalWhyFatigueRecovery, contains('Entlastungswoche'));
      expect(de.recalWhyFatigueCheck, contains('Entlastungswoche'));
    });

    test('stored notes in the old wording are shown in today\'s', () {
      expect(planDescription(en.wGymLoadDesc(1), en), gymLoadNote(en, 1));
      expect(planDescription(en.wGymLoadDesc(3), en), gymLoadNote(en, 3));
      expect(planDescription(en.wGymLoadDescNoDeload(1), en), gymLoadNote(en, 1, deloadAhead: false));
      // Stored in German, shown in English.
      expect(planDescription(de.wGymLoadDesc(1), en), gymLoadNote(en, 1));
      // Today's wording stays as it is.
      expect(planDescription(gymLoadNote(de, 2), de), gymLoadNote(de, 2));
    });

    test('generated gym plans use the new note', () {
      final p = UserProfile(
        level: 'advanced',
        focus: TrainingFocus.gym,
        experience: const {Sport.gym},
        trainingDays: const [1, 3, 5],
        athlete: const AthleteData(planWeeks: 12),
      );
      final plan = PlanGenerator(en, p, const [], () => 'x').generate(start: DateTime(2027, 3, 1), weeks: 12);
      final text = plan.map((w) => w.description).join('\n');
      expect(text, isNot(contains('1 reps')));
      expect(text, isNot(contains('next deload')));
    });
  });

  group('T12 plan history texts in today\'s language', () {
    test('recalibration findings and titles', () {
      final rel = Relocalizer.to('en');
      expect(rel.text(de.recalWhyCutShort(2)), en.recalWhyCutShort(2));
      expect(rel.text(de.recalWhyFatigueRecovery), en.recalWhyFatigueRecovery);
      // Stored before the wording change ("Erholungswoche").
      expect(rel.text(de.legacyRecalWhyFatigueRecovery), en.recalWhyFatigueRecovery);
      expect(Relocalizer.to('de').text(en.recalWhyFatigueCheck), de.recalWhyFatigueCheck);
      expect(rel.text(de.planLongRun), en.planLongRun);
    });
  });

  group('UX-4 the setup recommends what the race needs', () {
    test('hybrid marathon: at least 4 runs', () {
      for (final level in ['intermediate', 'advanced']) {
        final p = UserProfile(
          level: level,
          focus: TrainingFocus.hybrid,
          goals: const ['strength'],
          athlete: AthleteData(eventDistance: 'm', eventDate: DateTime(2027, 6, 27)),
        );
        expect(ScheduleAdvisor(p, {Sport.gym, Sport.run}).recommended()[Sport.run], greaterThanOrEqualTo(4), reason: level);
      }
    });

    test('every race discipline at its minimum', () {
      for (final (focus, ev, sports) in [
        (TrainingFocus.swim, 'swim3800', {Sport.swim}),
        (TrainingFocus.ride, 'ride160', {Sport.ride}),
        (TrainingFocus.triathlon, 'ironman', {Sport.swim, Sport.ride, Sport.run}),
        (TrainingFocus.run, 'hm', {Sport.run}),
      ]) {
        final p = UserProfile(
          level: 'intermediate',
          focus: focus,
          athlete: AthleteData(eventDistance: ev, eventDate: DateTime(2027, 6, 27)),
        );
        final rec = ScheduleAdvisor(p, sports).recommended();
        final f = PlanGenerator.feasibility(
          p.copyWith(trainingDays: List.generate(rec.values.fold(0, (a, b) => a + b).clamp(1, 7), (i) => i + 1)),
          start: DateTime(2027, 3, 1),
          l: en,
        );
        expect(f.issues.where((i) => i.endsWith('Frequency')), isEmpty, reason: '$ev $rec ${f.issues}');
      }
    });
  });

  group('UX-6 the coach sees weekdays', () {
    test('weekday, kind and key flag of each workout; training days from the plan', () {
      final today = DateTime(2026, 11, 16); // Monday
      PlannedWorkout w(String id, int day, Sport s, String title, String intensity, {bool key = false}) =>
          PlannedWorkout(id: id, date: addDays(today, day), sport: s, title: title, durationMin: 45, intensity: intensity, isKey: key);
      final plans = [
        w('a', 0, Sport.run, 'Locker', 'easy'),
        w('b', 4, Sport.run, 'Fahrtspiel', 'tempo', key: true),
        w('c', 5, Sport.run, 'Langer Lauf', 'long', key: true),
        w('d', 2, Sport.gym, 'Push', 'moderate'),
        w('e', 9, Sport.run, 'Langer Lauf', 'long', key: true),
      ];
      final c = CoachService(
        profile: const UserProfile(trainingDays: [1, 2, 3, 4, 5, 6]),
        sessions: const [],
        plans: plans,
        lang: 'de',
      ).contextText(now: today);
      expect(c, contains('Sat 2026-11-21: run "Langer Lauf"'));
      expect(c, contains('(long, key)'));
      expect(c, contains('Fri 2026-11-20: run "Fahrtspiel" 45 min (tempo, key)'));
      expect(c, contains('training days this week (from the plan): 4 (Mon, Wed, Fri, Sat)'));
      expect(c, contains('Today: Mon 2026-11-16'));
      expect(c, contains('Wed 2026-11-25'), reason: 'next week too');
    });
  });

  group('UX-14 XP after a correction', () {
    Session s({int sec = 19, double m = 500, int? cap}) =>
        Session(id: 's', sport: Sport.run, title: 'Lauf', start: DateTime(2026, 11, 16, 8), durationSec: sec, distanceM: m, xpCap: cap);
    test('a recording that was no workout does not cap the corrected one at 0 XP', () {
      expect(xpForSession(s()), 0);
      expect(xpForSession(s(sec: 28 * 60 + 19, m: 3200, cap: 0)), greaterThan(0));
      // A real workout's cap still holds: a correction never raises its XP.
      final real = xpForSession(s(sec: 30 * 60, m: 5000));
      expect(xpForSession(s(sec: 60 * 60, m: 10000, cap: real)), real);
    });
  });
}
