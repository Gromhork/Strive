import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/plan_log.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/features/coach/coach_page.dart';
import 'package:strive/features/goals/goal_mismatch_card.dart';
import 'package:strive/features/goals/goals_page.dart';
import 'package:strive/features/home/week_page.dart';
import 'package:strive/features/onboarding/onboarding_page.dart' show planSummaryLines;
import 'package:strive/features/session/cardio_extra_pages.dart';
import 'package:strive/features/shell/link_cleanup_sync.dart';
import 'package:strive/features/stats/plan_link_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/coach_service.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/goal_alignment.dart';
import 'package:strive/services/insights.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/services/zones.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final planUpdates = <String, Map<String, dynamic>>{};
  final sessionUpdates = <String, Map<String, dynamic>>{};
  final log = <PlanLogEntry>[];
  @override
  void updatePlan(String id, Map<String, dynamic> data) => planUpdates[id] = data;
  @override
  void updateSession(String id, Map<String, dynamic> data) => sessionUpdates[id] = data;
  @override
  void logPlanChange(PlanLogEntry e) => log.add(e);
  @override
  void saveGoal(Goal g) {}
  @override
  void saveProfile(UserProfile p) {}
}

Future<List<Override>> _overrides(
  _FakeRepo repo, {
  UserProfile profile = const UserProfile(),
  List<PlannedWorkout> plans = const [],
  List<Session> sessions = const [],
  List<Goal> goals = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  return [
    prefsProvider.overrideWithValue(p),
    repoProvider.overrideWithValue(repo),
    profileProvider.overrideWith((ref) => Stream.value(profile)),
    sessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
    plansProvider.overrideWith((ref) => Stream.value(plans)),
    goalsProvider.overrideWith((ref) => Stream.value(goals)),
  ];
}

Widget _app(Widget home, List<Override> o, {String lang = 'de'}) => ProviderScope(
  overrides: o,
  child: MaterialApp(
    theme: AppTheme.dark(),
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (c, child) {
      Units.decimalComma = lang == 'de';
      return child!;
    },
    home: home,
  ),
);

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final today = dayOnly(DateTime.now());
  final triGoal = Goal(
    id: 'g',
    type: GoalType.event,
    title: 'Hamburg Triathlon',
    target: 51.5,
    eventKm: 51.5,
    eventKey: 'olympic',
    created: today,
    deadline: addDays(today, 88),
  );
  const hybrid = UserProfile(level: 'intermediate', birthYear: 1990, focus: TrainingFocus.hybrid);
  PlannedWorkout plan(String id, int day, Sport sport, {String status = 'planned', String? sessionId, double? km, int min = 40}) =>
      PlannedWorkout(
        id: id,
        date: addDays(today, day),
        sport: sport,
        title: 'W$id',
        status: status,
        sessionId: sessionId,
        distanceKm: km,
        durationMin: min,
      );
  Session session(String id, int day, Sport sport, {String? planId, double m = 0, int sec = 1800}) => Session(
    id: id,
    sport: sport,
    title: 'S$id',
    start: addDays(today, day).add(const Duration(hours: 9)),
    durationSec: sec,
    distanceM: m,
    planId: planId,
  );
  final hybridPlan = [plan('a', 1, Sport.run), plan('b', 2, Sport.gym), plan('c', 3, Sport.swim)];

  group('C2/C5 goal ↔ focus ↔ plan mismatch', () {
    test('triathlon goal on a hybrid plan without cycling is detected', () {
      final m = GoalAlignment.of(hybrid, [triGoal], hybridPlan, today)!;
      expect(m.focusWrong, isTrue);
      expect(m.neededFocus, TrainingFocus.triathlon);
      expect(m.planAligned, isFalse);
      expect(m.missingSports, [Sport.ride]);
      expect(m.coachText(), contains('DATA MISMATCH'));
      expect(m.coachText(), contains('Never invent a reason'));
    });

    test('an aligned triathlon plan has no mismatch', () {
      final p = UserProfile(focus: TrainingFocus.triathlon, athlete: AthleteData(eventDate: triGoal.deadline, eventDistance: 'olympic'));
      final plans = [...hybridPlan, plan('d', 4, Sport.ride)];
      expect(GoalAlignment.of(p, [triGoal], plans, today)!.mismatch, isFalse);
    });

    test('coach: the race goal is the main goal, the mismatch is explicit, first person', () {
      final s = CoachService(profile: hybrid, sessions: const [], plans: hybridPlan, goals: [triGoal], lang: 'de');
      final c = s.contextText(now: today);
      expect(c, contains('MAIN GOAL: triathlon race "Hamburg Triathlon"'));
      expect(c, contains('DATA MISMATCH'));
      expect(c, isNot(contains('no race planned')));
      final sys = s.systemText(now: today);
      expect(sys, contains('first person'));
      expect(sys, contains('Deine App lernt'));
      expect(sys, contains('Never invent reasons'));
    });

    test('coach starter questions follow the goal (no "10 km faster" for a triathlete)', () {
      final q = coachSuggestions(de, TrainingFocus.hybrid, GoalAlignment.of(hybrid, [triGoal], hybridPlan, today));
      expect(q, isNot(contains(de.coachQ3)));
      expect(q, contains(de.coachQTri));
      expect(q, contains(de.coachQRace('Hamburg Triathlon')));
      expect(coachSuggestions(de, TrainingFocus.run, null), contains(de.coachQ3));
    });

    test('feasibility never shows "0 min / 0 m" limits', () {
      const f = PlanFeasibility(issues: ['longRideTime', 'longSwim'], longRideMin: 0, longRideTargetMin: 90, longSwimM: 0);
      expect(FeasibilityCard.shownIssues(f), isEmpty);
      const g = PlanFeasibility(issues: ['longRideTime'], longRideMin: 60, longRideTargetMin: 90);
      expect(FeasibilityCard.shownIssues(g), ['longRideTime']);
    });

    testWidgets('card on the goals page, "Anpassen" present (de, 360×640)', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final o = await _overrides(_FakeRepo(), profile: hybrid, goals: [triGoal], plans: hybridPlan);
      await t.pumpWidget(_app(const GoalsPage(), o));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('goalMismatch')), findsOneWidget);
      expect(find.text(de.mismatchFocusBody('Hamburg Triathlon', de.focusHybrid, de.focusTriathlon), findRichText: true), findsNothing);
      expect(find.textContaining('Fokus auf Triathlon ändern'), findsOneWidget);
      expect(find.byKey(const ValueKey('goalMismatchAdjust')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Home card: "Später" hides it', (t) async {
      final o = await _overrides(_FakeRepo(), profile: hybrid, goals: [triGoal], plans: hybridPlan);
      await t.pumpWidget(_app(const Scaffold(body: GoalMismatchCard(snoozable: true)), o));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('goalMismatchLater')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('goalMismatch')), findsNothing);
    });

    testWidgets('goal editor: the align switch shows reality, no feasibility with the wrong focus', (t) async {
      final o = await _overrides(_FakeRepo(), profile: hybrid, goals: [triGoal], plans: hybridPlan);
      await t.pumpWidget(
        _app(
          Consumer(
            builder:
                (c, ref, _) =>
                    Scaffold(body: TextButton(onPressed: () => showGoalEditor(c, ref, existing: triGoal), child: const Text('open'))),
          ),
          o,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('alignPlan')));
      await t.pumpAndSettle();
      final sw = t.widget<SwitchListTile>(find.byKey(const ValueKey('alignPlan')));
      expect(sw.value, isFalse);
      expect(find.text(de.alignStatusNotAligned), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('alignPlan')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('alignFocusHint')), findsOneWidget);
      expect(find.byKey(const ValueKey('feasibility')), findsNothing);
      expect(t.takeException(), isNull);
    });

    test('plan settings summary lists the week and the plan length', () {
      final p = UserProfile(
        focus: TrainingFocus.triathlon,
        trainingDays: const [1, 2, 3, 4, 5, 6],
        athlete: AthleteData(eventDate: addDays(today, 98), eventDistance: 'olympic'),
      );
      final lines = planSummaryLines(de, p, now: today);
      expect(lines.first, contains('Radfahren'));
      expect(lines.last, contains('Wochen bis zum Wettkampftag'));
    });
  });

  group('C4 replacement, partial completion, cleanup', () {
    test('old links > ±1 day are reopened (and logged)', () {
      final plans = [
        plan('sat', 5, Sport.run, status: 'done', sessionId: 's1'),
        plan('mon', 0, Sport.run, status: 'done', sessionId: 's2'),
      ];
      final sessions = [session('s1', 0, Sport.run, planId: 'sat'), session('s2', 0, Sport.run, planId: 'mon')];
      final c = staleLinks(plans, sessions);
      expect(c.map((x) => x.$1.id), ['sat']);
      expect(c.single.$2.status, 'planned');
      expect(c.single.$2.sessionId, isNull);
    });

    test('"Ja" is logged and undoable (plan history + undo)', () {
      final repo = _FakeRepo();
      final sat = plan('sat', 5, Sport.run);
      confirmReplacement(repo, de, session('s', 0, Sport.run, planId: 'sat'), sat);
      expect(repo.planUpdates['sat'], {'status': 'done', 'sessionId': 's'});
      final e = repo.log.single;
      expect(e.source, 'replace');
      final done = e.items.single.afterPlan;
      expect(planLogState(e, {'sat': done}), PlanLogState.undoable);
      expect(planLogUndo(e, {'sat': done}).restore.single.status, 'planned');
      undoReplacement(repo, 'sat');
      expect(repo.planUpdates['sat'], {'status': 'planned', 'sessionId': null});
    });

    testWidgets('a 400 m swim of a 1500 m workout is shown as far off, not "no problem"', (t) async {
      final p = plan('p', 0, Sport.swim, status: 'done', sessionId: 's', km: 1.5);
      final s = session('s', 0, Sport.swim, planId: 'p', m: 400, sec: 600);
      expect(planCompliance(p, s).level, ComplianceLevel.orange);
      final o = await _overrides(_FakeRepo(), plans: [p], sessions: [s]);
      await t.pumpWidget(_app(Scaffold(body: ListView(children: [PlanLinkCard(session: s)])), o));
      await t.pumpAndSettle();
      expect(find.text(de.coachMuchShorter(Units.pct(400 / 1500 * 100))), findsOneWidget);
      expect(find.text(de.coachShorter), findsNothing);
    });

    testWidgets('a 100 m swim of a 1500 m workout (< 10 %) does not count', (t) async {
      final p = plan('p', 0, Sport.swim, status: 'done', sessionId: 's', km: 1.5);
      final s = session('s', 0, Sport.swim, planId: 'p', m: 100, sec: 120);
      final c = planCompliance(p, s);
      expect(c.level, ComplianceLevel.red);
      expect(c.notCounted, isTrue);
      expect(planCompleted(p, {'p': s}), isFalse);
      final o = await _overrides(_FakeRepo(), plans: [p], sessions: [s]);
      await t.pumpWidget(_app(Scaffold(body: ListView(children: [PlanLinkCard(session: s)])), o));
      await t.pumpAndSettle();
      expect(find.text(de.coachNotCounted(Units.pct(100 / 1500 * 100))), findsOneWidget);
    });

    testWidgets('a confirmed replacement can be taken back on the session', (t) async {
      final repo = _FakeRepo();
      final p = plan('sat', 3, Sport.run, status: 'done', sessionId: 's', km: 5);
      final s = session('s', 0, Sport.run, planId: 'sat', m: 5000);
      final o = await _overrides(repo, plans: [p], sessions: [s]);
      await t.pumpWidget(_app(Scaffold(body: ListView(children: [PlanLinkCard(session: s)])), o));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('replacementUndo')));
      await t.pump();
      expect(repo.planUpdates['sat'], {'status': 'planned', 'sessionId': null});
    });
  });

  group('week counts, header, minors', () {
    test('one definition of "done" counts', () {
      final plans = [
        plan('a', 0, Sport.gym, status: 'done', sessionId: 'x'),
        plan('b', 0, Sport.gym),
        plan('c', 0, Sport.run, status: 'skipped'),
      ];
      final x = session('x', 0, Sport.gym), y = session('y', 0, Sport.gym);
      final linked = linkPlanSessions(plans, [x, y]);
      expect(planCounts(plans, linked), (done: 1, planned: 2));
      expect(extraSessions([x, y], plans, linked), 1);
    });

    testWidgets('week page total uses the same count', (t) async {
      final plans = [plan('a', 0, Sport.gym, status: 'done', sessionId: 'x'), plan('b', 0, Sport.gym)];
      final o = await _overrides(_FakeRepo(), plans: plans, sessions: [session('x', 0, Sport.gym), session('y', 0, Sport.gym)]);
      await t.pumpWidget(_app(const WeekPage(), o));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('weekDoneCount')), matching: find.text('1/2')), findsOneWidget);
      expect(find.text('1/2 ${de.extraSessionsN(1)}'), findsOneWidget);
    });

    test('greeting by local hour; durations rounded', () {
      String g(int h) => greetingFor(h, morning: 'M', afternoon: 'A', evening: 'E');
      expect([g(7), g(12), g(20), g(0)], ['M', 'A', 'E', 'E']);
      expect(humanDuration(229), '4 min');
      expect(humanDuration(20), '20 s');
      expect(humanDuration(3600 + 29 * 60 + 40), '1 h 30 min');
    });

    test('restored run: the time the app was dead is a pause', () {
      final start = DateTime(2026, 11, 10, 8);
      final s = CardioState(sport: Sport.run, title: 'Lauf', start: start, accumulatedSec: 60, runningSince: start);
      final now = start.add(const Duration(minutes: 30));
      final r = TrackerNotifier.withKilledGapPaused(s, start.add(const Duration(minutes: 10)), now);
      expect(r.accumulatedSec, 60 + 600);
      expect(r.runningSince, now);
    });

    test('no XP / badge for a 32 s swim; early bird is 4–8 am', () {
      final tiny = Session(id: 't', sport: Sport.swim, title: 'S', start: DateTime(2026, 11, 11, 0, 8), durationSec: 32);
      expect(xpForSession(tiny), 0);
      expect(isEarlySession(tiny), isFalse);
      expect(isEarlySession(Session(id: 'e', sport: Sport.run, title: 'R', start: DateTime(2026, 11, 11, 6), durationSec: 1800)), isTrue);
    });

    test('run zone display is contiguous', () {
      final z = PaceZones(45);
      final codes = ['E', 'M', 'T', 'I', 'R'];
      for (var i = 0; i < codes.length - 1; i++) {
        expect(contiguousRunRange(z, codes[i]).$1, contiguousRunRange(z, codes[i + 1]).$2, reason: codes[i]);
      }
    });
  });
}
