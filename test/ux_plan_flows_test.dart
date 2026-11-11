import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/plan_log.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/planned_workout_page.dart';
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/features/goals/goals_page.dart';
import 'package:strive/features/home/home_page.dart';
import 'package:strive/features/onboarding/onboarding_page.dart';
import 'package:strive/features/profile/profile_page.dart' show SecureGuestCard, confirmGuestLogout;
import 'package:strive/features/stats/plan_link_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/plan_match.dart';
import 'package:strive/widgets/plan_amount.dart';
import 'package:strive/widgets/term_info.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final planUpdates = <String, Map<String, dynamic>>{};
  final sessionUpdates = <String, Map<String, dynamic>>{};
  final savedGoals = <Goal>[];
  final deletedGoals = <String>[];
  final log = <PlanLogEntry>[];
  var _n = 0;
  @override
  String newId() => 'id${_n++}';
  @override
  void updatePlan(String id, Map<String, dynamic> data) => planUpdates[id] = data;
  @override
  void updateSession(String id, Map<String, dynamic> data) => sessionUpdates[id] = data;
  @override
  void saveGoal(Goal g) => savedGoals.add(g);
  @override
  void deleteGoal(String id) => deletedGoals.add(id);
  @override
  void logPlanChange(PlanLogEntry e) => log.add(e);
  @override
  void saveProfile(UserProfile p) {}
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<List<Override>> _overrides(
  _FakeRepo repo, {
  UserProfile profile = const UserProfile(level: 'intermediate', birthYear: 1990, focus: TrainingFocus.run),
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

Widget _app(Widget home, String lang, List<Override> overrides) => ProviderScope(
  overrides: overrides,
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
    builder: (context, child) {
      Units.decimalComma = lang == 'de';
      return child!;
    },
    home: home,
  ),
);

/// A page pushed from a button (so streams have emitted when its state initialises).
/// The app keeps the profile loaded (Home watches it) – so does the opener; goals load late.
Widget _opener(Widget Function() page) => Consumer(
  builder: (c, ref, _) {
    ref.watch(profileProvider);
    ref.watch(plansProvider);
    return Scaffold(
      body: TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page())), child: const Text('open')),
    );
  },
);

void main() {
  final today = dayOnly(DateTime.now());
  PlannedWorkout plan(
    String id,
    int day, {
    Sport sport = Sport.run,
    String title = 'Langer Lauf',
    String status = 'planned',
    String intensity = 'long',
  }) => PlannedWorkout(
    id: id,
    date: addDays(today, day),
    sport: sport,
    title: title,
    status: status,
    intensity: intensity,
    durationMin: 45,
    distanceKm: 7.5,
  );
  Session session(String id, int day, {String? planId, int min = 35, double km = 5.9, int? rpe}) => Session(
    id: id,
    sport: Sport.run,
    title: 'Lauf',
    start: addDays(today, day).add(const Duration(hours: 8)),
    durationSec: min * 60,
    distanceM: km * 1000,
    planId: planId,
    rpe: rpe,
  );

  group('I2 number formatting', () {
    tearDown(() => Units.decimalComma = false);
    test('German', () {
      Units.decimalComma = true;
      expect(compactNumber(8432), '8.432');
      expect(const Units(false).volume(1593), '1.593 kg');
      expect(const Units(false).volume(12400), '12,4 t');
      expect(Units.fixed(2), '2,0');
      expect(Units.fixed(43.44), '43,4');
      expect(Units.pct(26.2), '26 %');
    });
    test('English', () {
      expect(compactNumber(8432), '8,432');
      expect(const Units(false).volume(1593), '1,593 kg');
      expect(Units.fixed(2), '2.0');
      expect(Units.pct(26.2), '26%');
    });
  });

  group('C2 race presets', () {
    test('51,5 km is the olympic triathlon, never "Ultra 50 km"', () {
      expect(eventKeyForKm(51.5), 'olympic');
      expect(eventKeyForKm(51), isNull);
      expect(eventKeyForKm(50.5), isNull);
      expect(eventKeyForKm(21.1), 'hm');
      expect(eventKeyForKm(5, sport: EventSport.swim), 'swim5000');
    });
  });

  group('C4 plan linking ±1 day', () {
    test('a session started from Saturday\'s workout on Monday does not fulfil it', () {
      final sat = plan('sat', 5);
      final s = session('s', 0, planId: 'sat');
      expect(matchPlan(s, [sat]), isNull);
      expect(replacementCandidate(s, [sat])?.id, 'sat');
      expect(linkPlanSessions([sat], [s]), isEmpty);
      // Confirmed ("Ja") – the plan points back at the session.
      final confirmed = PlannedWorkout.fromMap('sat', {...sat.toMap(), 'status': 'done', 'sessionId': 's'});
      expect(linkPlanSessions([confirmed], [s]).keys, ['sat']);
    });
    test('the day before / after still links', () {
      final tue = plan('tue', 1);
      final s = session('s', 0, planId: 'tue');
      expect(matchPlan(s, [tue])?.id, 'tue');
      expect(replacementCandidate(s, [tue]), isNull);
      expect(linkPlanSessions([tue], [s]).keys, ['tue']);
    });
  });

  group('I4 one duration', () {
    test('structured workouts show the step estimate everywhere', () {
      const profile = UserProfile(level: 'intermediate', birthYear: 1990);
      final p = PlannedWorkout(
        id: 'x',
        date: today,
        sport: Sport.run,
        title: 'Locker',
        durationMin: 40,
        distanceKm: 5.8,
        steps: [WorkoutStep(kind: 'steady', zone: 'E', durationSec: 36 * 60)],
      );
      final a = planAmount(p, profile);
      expect(a.minutes, 36);
      expect(a.estimated, isTrue);
      expect(planAmountText(p, profile), startsWith('≈ 36 min'));
    });
  });

  test('I6 short gym labels', () {
    final l = lookupAppLocalizations(const Locale('de'));
    expect(shortPlanLabel(l, plan('g', 1, sport: Sport.gym, title: 'Ganzkörper A', intensity: 'moderate')), 'GK A');
  });

  test('I9 event progress: phase and week instead of a percentage', () {
    final race = addDays(startOfWeek(today), 7 * 12 + 5);
    final plans = [
      for (var w = -1; w < 12; w++)
        PlannedWorkout(
          id: 'w$w',
          date: addDays(startOfWeek(today), 7 * w + 1),
          sport: Sport.run,
          title: 'x',
          phase: w < 6 ? 'base' : 'build',
        ),
    ];
    final e = EventProgress.of(race, plans, today);
    expect(e.week, 2);
    expect(e.weeks, 14); // plan from last week to race week
    expect(e.phase, 'base');
    final l = lookupAppLocalizations(const Locale('de'));
    expect(eventProgressText(l, e), contains('Grundlagenphase (Woche 2/14)'));
  });

  test('I13 glossary has the plan terms', () {
    final l = lookupAppLocalizations(const Locale('de'));
    final titles = Term.values.map((t) => t.title(l)).toList();
    for (final t in ['Schlüsseleinheit', 'Belastungswoche', 'Entlastungswoche', 'Steigerungen', 'Fahrtspiel']) {
      expect(titles, contains(t));
    }
    expect(l.termRirTip, contains('Bewertungs-Chips'));
  });

  for (final lang in ['de', 'en']) {
    final l = lookupAppLocalizations(Locale(lang));

    testWidgets('QA TodayCard: a skipped workout is not first and has no play button ($lang)', (t) async {
      _phone(t);
      final o = await _overrides(
        _FakeRepo(),
        plans: [plan('skip', 0, title: 'Entfallen', status: 'skipped'), plan('open', 0, title: 'Offen')],
      );
      await t.pumpWidget(_app(const Scaffold(body: SingleChildScrollView(child: TodayCard())), lang, o));
      await t.pumpAndSettle();
      expect(find.text('Offen'), findsOneWidget);
      expect(find.text('Entfallen'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('I6 week strip: filtered days are "hidden", not "rest" ($lang, 360×640)', (t) async {
      _phone(t);
      final o = await _overrides(
        _FakeRepo(),
        plans: [plan('r', 1), plan('g', 2, sport: Sport.gym, title: 'Ganzkörper A', intensity: 'moderate')],
      );
      await t.pumpWidget(
        _app(
          Consumer(
            builder: (c, ref, _) {
              return const Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: ComingUpCard()));
            },
          ),
          lang,
          [...o],
        ),
      );
      await t.pumpAndSettle();
      final container = ProviderScope.containerOf(t.element(find.byType(ComingUpCard)));
      container.read(sportFilterProvider.notifier).set(Sport.gym);
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const ValueKey('stripLabel1'))).data, l.hiddenShort);
      expect(t.widget<Text>(find.byKey(const ValueKey('stripLabel2'))).data, 'GK A');
      expect(t.widget<Text>(find.byKey(const ValueKey('stripLabel3'))).data, l.rest);
      expect(t.widget<Text>(find.byKey(const ValueKey('stripLabel1'))).style!.fontSize, greaterThanOrEqualTo(11));
      expect(t.takeException(), isNull);
    });

    testWidgets('I9 event line under today\'s workout ($lang, 360×640)', (t) async {
      _phone(t);
      final goal = Goal(
        id: 'g',
        type: GoalType.event,
        title: 'Hamburg Triathlon',
        target: 51.5,
        eventKm: 51.5,
        eventKey: 'olympic',
        created: today,
        deadline: addDays(today, 88),
      );
      final o = await _overrides(_FakeRepo(), goals: [goal]);
      await t.pumpWidget(_app(Scaffold(body: EventGoalLine(onTap: (_) {})), lang, o));
      await t.pumpAndSettle();
      expect(find.textContaining('Hamburg Triathlon', findRichText: true), findsOneWidget);
      expect(find.textContaining(l.daysLeftInline(88), findRichText: true), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('C2 goal editor: race type, exact presets, ambition run leg ($lang, 360×640)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final o = await _overrides(repo, profile: const UserProfile(level: 'intermediate', birthYear: 1990, focus: TrainingFocus.hybrid));
      await t.pumpWidget(
        _app(
          Consumer(builder: (c, ref, _) => Scaffold(body: TextButton(onPressed: () => showGoalEditor(c, ref), child: const Text('open')))),
          lang,
          o,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      // Empty goal can't be saved ("0 per week") – but no red error before the first try.
      expect(find.byKey(const ValueKey('goalInvalid')), findsNothing);
      await t.tap(find.byKey(const ValueKey('saveGoal')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('goalInvalid')), findsOneWidget);
      expect(repo.savedGoals, isEmpty);
      await t.tap(find.text(l.goalTypeEvent));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('raceType-triathlon')));
      await t.tap(find.byKey(const ValueKey('raceType-triathlon')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('distance-olympic')), findsOneWidget);
      expect(find.byKey(const ValueKey('distance-ultra50')), findsNothing);
      await t.tap(find.byKey(const ValueKey('distance-olympic')));
      await t.pumpAndSettle();
      expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('distance-olympic'))).selected, isTrue);
      // 51 km is no preset: nothing is auto-selected.
      await t.enterText(find.widgetWithText(TextField, l.eventDistance), '51');
      await t.pumpAndSettle();
      expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('distance-olympic'))).selected, isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets('QA goal delete asks first and can be undone ($lang)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final g = Goal(id: 'g1', type: GoalType.frequency, title: '3×', target: 3, created: today);
      final o = await _overrides(repo, goals: [g]);
      await t.pumpWidget(_app(const GoalsPage(), lang, o));
      await t.pumpAndSettle();
      await t.tap(find.text('3×'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip(l.delete));
      await t.pumpAndSettle();
      expect(repo.deletedGoals, isEmpty);
      expect(find.text(l.deleteGoalTitle), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, l.delete));
      await t.pumpAndSettle();
      expect(repo.deletedGoals, ['g1']);
      await t.tap(find.text(l.undo));
      await t.pumpAndSettle();
      expect(repo.savedGoals.single.id, 'g1');
    });

    testWidgets('C4 replacement question on the session ($lang, 360×640)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final sat = plan('sat', 5);
      final s = session('s', 0, planId: 'sat');
      final o = await _overrides(repo, plans: [sat], sessions: [s]);
      await t.pumpWidget(_app(Scaffold(body: ListView(children: [PlanLinkCard(session: s)])), lang, o));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('replacementCard')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('replacementYes')));
      await t.pumpAndSettle();
      expect(repo.planUpdates['sat'], {'status': 'done', 'sessionId': 's'});
      expect(t.takeException(), isNull);
    });

    testWidgets('I8 session ↔ plan card with RPE hint ($lang, 360×640)', (t) async {
      _phone(t);
      final p = plan('p', 0);
      final s = session('s', 0, planId: 'p', rpe: 8);
      final o = await _overrides(_FakeRepo(), plans: [p], sessions: [s]);
      await t.pumpWidget(_app(Scaffold(body: ListView(children: [PlanLinkCard(session: s)])), lang, o));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('planLinkCard')), findsOneWidget);
      expect(find.textContaining(l.fulfilledPct(Units.pct(5.9 / 7.5 * 100))), findsOneWidget);
      expect(find.text(l.coachRpeHigh('Langer Lauf', 8)), findsOneWidget);
      expect(find.byKey(const ValueKey('planLinkReview')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('QA planned workout: deleted → message, labelled "log as done" ($lang, 360×640)', (t) async {
      _phone(t);
      final o = await _overrides(_FakeRepo(), plans: [plan('p', 1)]);
      await t.pumpWidget(_app(const PlannedWorkoutPage(planId: 'gone'), lang, o));
      await t.pumpAndSettle();
      expect(find.text(l.planGone), findsOneWidget);
      await t.pumpWidget(_app(const PlannedWorkoutPage(planId: 'p'), lang, o));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('logManuallyButton')), findsOneWidget);
      expect(find.text(l.logAsDone), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('I14 guest logout dialog and secure card ($lang, 360×640)', (t) async {
      _phone(t);
      bool? result;
      final o = await _overrides(_FakeRepo());
      await t.pumpWidget(
        _app(
          Builder(
            builder:
                (c) => Scaffold(
                  body: Column(
                    children: [
                      const SecureGuestCard(),
                      TextButton(onPressed: () async => result = await confirmGuestLogout(c), child: const Text('logout')),
                    ],
                  ),
                ),
          ),
          lang,
          o,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l.secureGuestTitle), findsOneWidget);
      await t.tap(find.text('logout'));
      await t.pumpAndSettle();
      expect(find.text(l.guestLogoutBody), findsOneWidget);
      expect(find.text(l.guestSecureFirst), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('guestLogoutAnyway')));
      await t.pumpAndSettle();
      expect(result, isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('C3 plan settings: prefilled from the race goal, summary + "recreate" ($lang, 360×640)', (t) async {
      _phone(t);
      final goal = Goal(
        id: 'g',
        type: GoalType.event,
        title: 'Hamburg Triathlon',
        target: 51.5,
        eventKm: 51.5,
        eventKey: 'olympic',
        created: today,
        deadline: addDays(today, 88),
      );
      final o = await _overrides(
        _FakeRepo(),
        profile: const UserProfile(
          level: 'intermediate',
          birthYear: 1990,
          focus: TrainingFocus.hybrid,
          onboarded: true,
          trainingDays: [1, 3, 5],
        ),
        goals: [goal],
      );
      await t.pumpWidget(_app(_opener(() => const OnboardingPage(mode: SetupMode.plan)), lang, o));
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      // Step 1: the focus follows the triathlon goal.
      for (var i = 0; i < 12 && find.byKey(const ValueKey('goalKind')).evaluate().isEmpty; i++) {
        await t.tap(find.widgetWithText(FilledButton, l.next));
        await t.pumpAndSettle();
      }
      expect(find.widgetWithText(TextField, 'Hamburg Triathlon'), findsOneWidget);
      expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('distance-olympic'))).selected, isTrue);
      expect(find.byKey(const ValueKey('distance-hm')), findsNothing);
      await t.tap(find.widgetWithText(FilledButton, l.next));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, l.next));
      await t.pumpAndSettle();
      expect(find.text(l.summaryChanges), findsOneWidget);
      expect(find.widgetWithText(FilledButton, l.recreatePlan), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
