import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_apply.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/features/session/manual_entry_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_service.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/target_suggestion.dart';
import 'package:strive/widgets/target_suggestion_line.dart';

final en = lookupAppLocalizations(const Locale('en'));
final de = lookupAppLocalizations(const Locale('de'));

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  // ── 1. A start too short to count leaves its workout open – also for "Plan neu aufsetzen".
  group('not counted = open in plan replacement', () {
    final tue = DateTime(2026, 11, 17), wed = DateTime(2026, 11, 18), thu = DateTime(2026, 11, 19);
    PlannedWorkout gym(String id, DateTime d, {String status = 'planned', String? sessionId}) => PlannedWorkout(
      id: id,
      date: d,
      sport: Sport.gym,
      title: 'Upper A',
      durationMin: 60,
      templateId: 'upperA',
      status: status,
      sessionId: sessionId,
    );
    Session started(String id, DateTime at, String planId, {int sec = 180}) =>
        Session(id: id, sport: Sport.gym, title: 'Upper A', start: at, durationSec: sec, planId: planId, templateId: 'upperA');

    test('a Wednesday gym workout "replaced" by a 3-min Tuesday start is not kept and its day is planned again', () {
      final plan = gym('w', wed, status: 'done', sessionId: 's1');
      final s = started('s1', DateTime(2026, 11, 17, 21, 50), 'w');
      final existing = [plan, gym('t', thu)];
      expect(planCompleted(plan, linkPlanSessions(existing, [s]), profile: null), isFalse, reason: 'premise: not counted');
      final kept = PlanService.keptWorkouts(existing, tue, [s]);
      expect(kept, isEmpty);
      expect(PlanService.notCountedWorkouts(existing, tue, [s]).map((p) => p.id), ['w']);
      final generated = [gym('g1', wed), gym('g2', thu)];
      final out = PlanService.withoutCoveredDays(generated, kept);
      expect(out.any((g) => sameDay(g.date, wed)), isTrue, reason: 'Wednesday gets its gym session again');
      // Started on another day: not attached to the new plan.
      final relinked = PlanService.relinkNotCounted(out, PlanService.notCountedWorkouts(existing, tue, [s]), [s]);
      expect(relinked.map((p) => p.id), ['g1', 'g2']);
    });

    test('a counting session keeps its workout and covers the day (unchanged)', () {
      final plan = gym('w', wed, status: 'done', sessionId: 's1');
      final s = started('s1', DateTime(2026, 11, 18, 18), 'w', sec: 3600);
      final kept = PlanService.keptWorkouts([plan], tue, [s]);
      expect(kept.map((p) => p.id), ['w']);
      expect(PlanService.withoutCoveredDays([gym('g1', wed)], kept), isEmpty);
    });

    test("today's aborted start stays attached to today's new workout of the same sport (open, \"not counted\")", () {
      final plan = gym('w', wed);
      final s = started('s1', DateTime(2026, 11, 18, 7), 'w');
      final reopened = PlanService.notCountedWorkouts([plan], wed, [s]);
      expect(reopened.map((p) => p.id), ['w']);
      final out = PlanService.relinkNotCounted([gym('g1', wed)], reopened, [s]);
      expect(out.single.id, 'w', reason: 'the session still points at it');
      expect(out.single.status, 'planned');
      expect(out.single.sessionId, isNull);
      final c = planCompliance(out.single, linkPlanSessions(out, [s])['w']);
      expect(c.notCounted, isTrue);
    });

    test('the gym rotation does not count an aborted start', () {
      final s = started('s1', DateTime(2026, 11, 17, 7), 'p');
      final hist = gymHistoryBefore([gym('p', tue)], [s], wed);
      expect(hist, isEmpty);
      final full = started('s2', DateTime(2026, 11, 17, 7), 'p', sec: 3600);
      expect(gymHistoryBefore([gym('p', tue)], [full], wed), isNotEmpty);
    });
  });

  // ── 2. An entered target next to a finish-only plan is said, not dropped.
  group('target set aside by a finish-only plan', () {
    final start = DateTime(2026, 11, 9);
    UserProfile beginnerMarathon({int? target}) => UserProfile(
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
        targetTimeSec: target,
      ),
    );

    test('generator, feasibility, race day and the suggestion line agree', () {
      final p = beginnerMarathon(target: 4 * 3600 + 30 * 60);
      expect(PlanGenerator.finishOnly(p, start: start), isTrue);
      expect(PlanGenerator.targetSetAside(p, start: start), isTrue);
      expect(PlanGenerator.targetSetAside(beginnerMarathon(), start: start), isFalse, reason: 'no target, nothing set aside');
      final f = PlanGenerator.feasibility(p, start: start, l: de);
      expect(f.issues, contains('targetSetAside'));
      expect(f.target, isNull, reason: 'no "ambitious" check of a pace the plan does not train');
      expect(f.extraIssueText(de, 'targetSetAside', dayName: (_) => ''), contains('4:30:00'));
      final race = PlanGenerator(de, p, const [], () => 'x').generate(start: start).firstWhere((w) => w.intensity == 'race');
      expect(race.description, contains('4:30:00'));
      expect(race.description, isNot(contains(de.wRaceFinishDesc)));
      final sug = suggestTargetTime(p, 'm', p.athlete.eventDate!, now: start, target: p.athlete.targetTimeSec);
      expect(sug.finishOnly, isTrue);
      expect(sug.targetRaced, isFalse);
      expect(suggestTargetTime(p, 'm', p.athlete.eventDate!, now: start).targetRaced, isNull);
    });

    testWidgets('the setup line says the target stays saved and offers to remove it', (tester) async {
      final p = beginnerMarathon();
      var cleared = false;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: TargetSuggestionLine(
              profile: p,
              eventKey: 'm',
              eventDate: p.athlete.eventDate!,
              sessions: const [],
              current: 4 * 3600 + 30 * 60,
              onApply: (_) {},
              onClear: () => cleared = true,
            ),
          ),
        ),
      );
      expect(find.textContaining('4:30:00'), findsOneWidget);
      expect(find.text(en.targetSuggestFinish), findsNothing);
      await tester.tap(find.byKey(const ValueKey('clearTarget')));
      expect(cleared, isTrue);
    });
  });

  // ── 3. Feasibility options are buttons outside the setup too.
  group('feasibility options are actionable in the calendar', () {
    test('one mapping of an option to the settings it changes', () {
      final p = UserProfile(
        athlete: AthleteData(eventDistance: 'm', eventName: 'Marathon', targetTimeSec: 3 * 3600, dayMinutes: const {6: 90}),
      );
      expect(profileWithFeasibility(p, const FeasSetTarget(4 * 3600), en)!.athlete.targetTimeSec, 4 * 3600);
      expect(profileWithFeasibility(p, const FeasClearTarget(), en)!.athlete.targetTimeSec, isNull);
      final later = profileWithFeasibility(p, FeasLaterDate(DateTime(2027, 5, 2)), en)!;
      expect(later.athlete.eventDate, DateTime(2027, 5, 2));
      final shorter = profileWithFeasibility(p, const FeasShorter('hm'), en)!;
      expect(shorter.athlete.eventDistance, 'hm');
      expect(shorter.athlete.eventName, isNull, reason: 'the automatic name follows the distance');
      expect(profileWithFeasibility(p, const FeasDayMinutes({7: 120}), en)!.athlete.dayMinutes, {6: 90, 7: 120});
      expect(profileWithFeasibility(p, const FeasLongDay(7), en)!.longDay, 7);
      expect(profileWithFeasibility(p, const FeasAddDay(Sport.run), en), isNull);
    });

    testWidgets('the target option is a button that hands over its text for the confirmation', (tester) async {
      const t = TargetCheck(
        status: TargetStatus.ambitious,
        targetSec: 12900,
        currentSec: 17897,
        realisticSec: 16567,
        optimisticSec: 16000,
        currentVdot: 35,
        gainVdot: 2,
        guessed: false,
        weeks: 20,
      );
      const f = PlanFeasibility(issues: ['targetAmbitious'], target: t, weeks: 20);
      (FeasibilityAction, String)? got;
      await tester.pumpWidget(
        _app(Scaffold(body: SingleChildScrollView(child: FeasibilityCard(f, onOption: (x, text) => got = (x, text))))),
      );
      await tester.tap(find.byKey(const ValueKey('feasOption-FeasSetTarget')));
      expect(got!.$1, isA<FeasSetTarget>());
      expect((got!.$1 as FeasSetTarget).sec, t.suggestedSec);
      expect(got!.$2, en.feasTargetSuggest(clock(t.suggestedSec)));
    });
  });

  // ── 4. The athlete's race name.
  test('race label: the name with its distance, the name alone when it says the distance, else the distance', () {
    expect(raceLabel(de, 'm', name: 'Berlin'), 'Berlin · Marathon');
    expect(raceLabel(de, 'm', name: 'Berlin-Marathon'), 'Berlin-Marathon');
    expect(raceLabel(de, 'm'), 'Marathon');
    expect(raceLabel(de, 'm', name: '  '), 'Marathon');
    final p = UserProfile(
      focus: TrainingFocus.run,
      trainingDays: const [2, 4, 6, 7],
      athlete: AthleteData(eventDistance: 'm', eventName: 'Berlin', eventDate: DateTime(2027, 3, 28), runWeeklyKm: 40, longestRunKm: 20),
    );
    final race = PlanGenerator(de, p, const [], () => 'x').generate(start: DateTime(2026, 11, 16)).firstWhere((w) => w.intensity == 'race');
    expect(race.title, de.wRace('Berlin · Marathon'));
  });

  // ── 5. Number and unit never wrap apart.
  test('distance labels and unit formatters use non-breaking spaces', () {
    expect(eventDistanceLabel(de, 'swim1500'), 'Freiwasser 1,5${nbsp}km');
    expect(eventDistanceLabel(en, '5k'), '5${nbsp}km');
    expect(const Units(false).dist(5600, digits: 1), contains(nbsp));
    expect(const Units(false).swimDist(400), '400${nbsp}m');
    expect(glueUnits('Lauf 8 km · 45 min'), 'Lauf 8${nbsp}km · 45${nbsp}min');
    expect(glueUnits('5 more'), '5 more', reason: 'only units');
    expect(glueTitle('Freiwasser 1,5 km'), 'Freiwasser 1,5${nbsp}km');
  });

  // ── 6. Every phase is named under the timeline.
  testWidgets('a short taper keeps its name: legend when the labels do not fit under their segments', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PhaseTimeline(segments: const [('base', 6), ('build', 6), ('peak', 4), ('taper', 1)], position: 0.1),
            ),
          ),
        ),
      ),
    );
    expect(find.text(en.goalPhaseTaperShort), findsOneWidget);
    expect(find.byKey(const ValueKey('phaseLegend')), findsOneWidget);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: PhaseTimeline(segments: const [('base', 4), ('build', 4), ('peak', 4), ('taper', 4)], position: 0.1),
            ),
          ),
        ),
      ),
    );
    expect(find.text(en.goalPhaseTaperShort), findsOneWidget);
    expect(find.byKey(const ValueKey('phaseLegend')), findsNothing);
  });

  // ── 7. Manual entry: the prefilled time is start and end, ending now – also on a DST night.
  group('manual entry time', () {
    test('today: ends at the current minute, starts the duration before', () {
      final now = DateTime(2026, 11, 17, 22, 12, 40);
      final s = manualEntryStart(now: now, minutes: 42);
      expect(s, DateTime(2026, 11, 17, 21, 30));
      expect(manualEntryTimeText('de', s, 42), endsWith('21:30–22:12'));
    });

    test('DST nights: the end is the current wall-clock minute (absolute arithmetic)', () {
      // Europe: 29 Mar 2026 02:00 → 03:00, 25 Oct 2026 03:00 → 02:00 (whatever the test machine's zone, the end must
      // be "now" and the span the duration).
      for (final now in [
        DateTime(2026, 3, 29, 3, 30),
        DateTime(2026, 3, 29, 4, 5),
        DateTime(2026, 10, 25, 2, 30),
        DateTime(2026, 10, 25, 3, 10),
      ]) {
        final s = manualEntryStart(now: now, minutes: 90);
        expect(s.add(const Duration(minutes: 90)), now, reason: '$now');
        final hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        expect(manualEntryTimeText('de', s, 90), endsWith('–$hm'), reason: '$now');
      }
    });

    test('a past plan day: 18:00 on that day; a later plan day: today', () {
      final now = DateTime(2026, 11, 17, 22, 12);
      expect(manualEntryStart(now: now, minutes: 60, planDate: DateTime(2026, 11, 15)), DateTime(2026, 11, 15, 18));
      expect(manualEntryStart(now: now, minutes: 60, planDate: DateTime(2026, 11, 19)), DateTime(2026, 11, 17, 21, 12));
    });
  });

  // ── 8. Race date suggestion per sport and season.
  group('default race date', () {
    final today = DateTime(2026, 11, 18);
    test('open water and triathlon: the next summer weekend, never before the recommended weeks', () {
      for (final (key, weeks) in [('swim1500', 8), ('olympic', 12), ('70.3', 16), ('ironman', 24)]) {
        final d = defaultRaceDateFor(key, today, weeks);
        expect(d.isAfter(DateTime(2027, 5, 31)) && d.isBefore(DateTime(2027, 9, 16)), isTrue, reason: '$key $d');
        expect(d.weekday, DateTime.sunday);
        expect(daysBetween(today, d), greaterThanOrEqualTo(7 * weeks));
      }
      expect(defaultRaceDateFor('70.3', today, 16, longDay: DateTime.saturday).weekday, DateTime.saturday);
      expect(defaultRaceDateFor('70.3', today, 16, longDay: DateTime.wednesday).weekday, DateTime.sunday);
    });

    test('late in the season: the plan does not fit before mid-September – next year', () {
      final d = defaultRaceDateFor('olympic', DateTime(2026, 7, 1), 12);
      expect(d.year, 2027);
      expect(d.month, 6);
      final early = defaultRaceDateFor('olympic', DateTime(2026, 4, 1), 12);
      expect(early, DateTime(2026, 6, 28), reason: '12 weeks from 1 Apr = 24 Jun, the Sunday after');
    });

    test('running races: as before (recommended weeks out, on the long day)', () {
      expect(defaultRaceDateFor('m', today, 16), defaultRaceDate(today, 16));
      expect(defaultRaceDateFor(null, today, 12, longDay: 6), defaultRaceDate(today, 12, longDay: 6));
    });
  });
}
