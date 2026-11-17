import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_sport_x.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/onboarding/onboarding_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_service.dart';

/// Records what the setup saves instead of writing to Firestore.
class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  var _n = 0;
  UserProfile? savedProfile;
  final savedPlans = <PlannedWorkout>[];
  final savedTemplates = <WorkoutTemplate>[];
  final deleted = <String>[];

  @override
  String newId() => 'id${_n++}';
  @override
  void saveProfile(UserProfile p) => savedProfile = p;
  @override
  void saveBody(BodyEntry e) {}
  @override
  void saveGoal(Goal g) {}
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async => savedTemplates.addAll(list);
  @override
  Future<void> savePlans(List<PlannedWorkout> list) async => savedPlans.addAll(list);
  @override
  Future<void> deletePlansFrom(List<PlannedWorkout> all, DateTime from) async =>
      deleted.addAll(all.where((p) => !p.date.isBefore(from) && p.status == 'planned').map((p) => p.id));
  @override
  Future<void> replacePlans(List<PlannedWorkout> all, DateTime from, List<PlannedWorkout> plan, {Set<String> keep = const {}}) async {
    await deletePlansFrom(all, from);
    await savePlans(plan);
  }

  @override
  Future<List<WorkoutTemplate>?> templatesFromServer() async => null;
}

final l = lookupAppLocalizations(const Locale('en'));

Future<_FakeRepo> _pump(
  WidgetTester tester, {
  UserProfile? profile,
  SetupMode mode = SetupMode.setup,
  List<PlannedWorkout> existing = const [],
  bool loaded = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo();
  final page = OnboardingPage(mode: mode);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repoProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) => Stream.value(profile)),
        templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
        plansProvider.overrideWith((ref) => Stream.value(existing)),
        goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home:
            mode == SetupMode.setup
                ? page
                : Scaffold(
                  body: Consumer(
                    builder:
                        // [loaded]: the profile stream is listened to before the page opens (as in the app,
                        // where the calendar already shows the profile) – the page then starts from it.
                        (c, ref, _) => TextButton(
                          key: ValueKey(loaded ? ref.watch(profileProvider).value?.name : null),
                          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
                          child: const Text('open'),
                        ),
                  ),
                ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (mode != SetupMode.setup) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
  return repo;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) => _tap(tester, find.widgetWithText(FilledButton, l.next));

/// Welcome (name, quick start) → body → fitness ([level]) → focus ([focus], [goal]).
Future<void> _toSchedule(WidgetTester tester, {String level = 'beginner', String focus = 'Running', String? goal}) async {
  await tester.enterText(find.byType(TextField).first, 'Anna');
  await tester.pumpAndSettle();
  await _tap(tester, find.text(l.setupQuick));
  await _next(tester); // → body
  await _next(tester); // → fitness
  await _tap(
    tester,
    find.text(switch (level) {
      'advanced' => l.advanced,
      'intermediate' => l.intermediate,
      _ => l.beginner,
    }),
  );
  await _next(tester); // → focus
  await _tap(tester, find.text(focus));
  if (goal != null) await _tap(tester, find.text(goal));
  await _next(tester); // → schedule
  expect(find.text(l.scheduleTitle), findsOneWidget);
}

/// Taps "Next" until the last page, then finishes the setup.
Future<void> _finish(WidgetTester tester) async {
  for (var i = 0; i < 10 && find.widgetWithText(FilledButton, l.next).evaluate().isNotEmpty; i++) {
    await _next(tester);
  }
  final done = [l.letsGo, l.recreatePlan, l.save].firstWhere((t) => find.widgetWithText(FilledButton, t).evaluate().isNotEmpty);
  await _tap(tester, find.widgetWithText(FilledButton, done));
}

Future<void> _toggleDays(WidgetTester tester, List<int> days) async {
  for (final d in days) {
    await _tap(tester, find.byKey(ValueKey('day$d')));
  }
}

void main() {
  // Each test is its own setup run (the double-tap cooldown is global).
  setUp(PlanService.reset);
  testWidgets('quick start: chosen days and long day are saved and used by the generated plan', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester, level: 'intermediate');
    // Tue/Thu/Sat (the default, [defaultTrainingDays]) → Tue/Wed/Sat/Sun.
    await _toggleDays(tester, [4, 3, 7]);
    // Long session on Saturday.
    await _tap(tester, find.byKey(const ValueKey('longDay')));
    final sat = find.descendant(of: find.byType(DropdownMenuItem<int?>), matching: find.textContaining('Sat'));
    await tester.tap(sat.last);
    await tester.pumpAndSettle();
    await _finish(tester);

    final p = repo.savedProfile!;
    expect(p.onboarded, isTrue);
    expect(p.trainingDays, [2, 3, 6, 7]);
    expect(p.longDay, 6);
    expect(p.athlete.dayPlan, isEmpty);
    expect(repo.savedTemplates, isNotEmpty, reason: 'built-in programs for a new user');
    expect(repo.savedPlans, isNotEmpty, reason: 'the plan is generated and saved');
    expect(repo.savedPlans.map((w) => w.date.weekday).toSet().difference({2, 3, 6, 7}), isEmpty);
    final longs = repo.savedPlans.where((w) => w.intensity == 'long');
    expect(longs, isNotEmpty);
    expect(longs.every((w) => w.date.weekday == 6), isTrue);
    expect(repo.savedPlans.every((w) => !dayOnly(w.date).isBefore(dayOnly(DateTime.now()))), isTrue);
    // Every week of the plan has workouts (no empty weeks).
    final weeks = {for (final w in repo.savedPlans) startOfWeek(w.date)};
    expect(weeks.length, greaterThanOrEqualTo(p.athlete.planWeeks - 1));
  });

  testWidgets('quick start: the last training day cannot be removed', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester);
    await _toggleDays(tester, [2, 4, 6]);
    expect(find.text(l.quickMinOneDay), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(OnboardingPage))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _finish(tester);
    expect(repo.savedProfile!.trainingDays, [6]);
    expect(repo.savedPlans.map((w) => w.date.weekday).toSet(), {6});
  });

  testWidgets('quick start: removing the long day resets it to automatic', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester, level: 'intermediate');
    await _tap(tester, find.byKey(const ValueKey('longDay')));
    await tester.tap(find.descendant(of: find.byType(DropdownMenuItem<int?>), matching: find.textContaining('Thu')).last);
    await tester.pumpAndSettle();
    await _toggleDays(tester, [4, 7]); // drop Thursday, add Sunday
    await _finish(tester);
    expect(repo.savedProfile!.trainingDays, [2, 6, 7]);
    expect(repo.savedProfile!.longDay, isNull);
    expect(repo.savedPlans.where((w) => w.intensity == 'long').every((w) => w.date.weekday == 7), isTrue);
  });

  testWidgets('quick start: a beginner sees which of the chosen days the plan keeps free', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester); // beginner, no running experience → run/walk, ≤ 3 runs
    await _toggleDays(tester, [1, 3, 5, 6]); // Mon–Fri
    expect(find.text(l.quickDaysCapped(3, 5)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('use2')), matching: find.byIcon(Icons.bedtime_outlined)), findsOneWidget);
    await _finish(tester);
    expect(repo.savedProfile!.trainingDays, [1, 2, 3, 4, 5]);
    final used = repo.savedPlans.map((w) => w.date.weekday).toSet();
    expect(used.length, 3);
    expect(used.difference({1, 2, 3, 4, 5}), isEmpty);
  });

  testWidgets('quick start: a strength goal adds strength days and the gym step', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester, level: 'intermediate', goal: l.goalStrength);
    await _toggleDays(tester, [1, 3, 4, 5]); // Mon–Sat minus Thu
    final gymDays = [
      for (var d = 1; d <= 7; d++)
        if (find.descendant(of: find.byKey(ValueKey('use$d')), matching: find.byIcon(Sport.gym.icon)).evaluate().isNotEmpty) d,
    ];
    expect(gymDays.length, 2, reason: 'preview shows the strength days');
    await _next(tester); // → gym
    expect(find.text(l.gymSetupTitle), findsOneWidget);
    await _finish(tester);
    expect(repo.savedPlans.where((w) => w.sport == Sport.gym), isNotEmpty);
    expect(repo.savedPlans.where((w) => w.sport == Sport.run), isNotEmpty);
  });

  testWidgets('plan settings in quick mode ignore a day plan left over from the detailed setup', (tester) async {
    final old = PlannedWorkout(id: 'old', date: DateTime.now().add(const Duration(days: 1)), sport: Sport.run, title: 'Old');
    final repo = await _pump(
      tester,
      mode: SetupMode.plan,
      existing: [old],
      profile: UserProfile(
        name: 'Ben',
        birthYear: 1990,
        level: 'intermediate',
        focus: TrainingFocus.run,
        trainingDays: defaultTrainingDays, // (the page starts from the default profile before the stream emits)
        onboarded: true,
        athlete: const AthleteData(
          setupMode: 'simple',
          sessionsPerDay: 2,
          dayPlan: {
            1: [Sport.run],
            3: [Sport.run],
            5: [Sport.run, Sport.gym],
          },
        ),
      ),
    );
    await _finish(tester);
    // Replacing planned workouts is confirmed first (shared dialog), then they are replaced.
    expect(find.text(l.replacePlanKeeps), findsOneWidget);
    expect(repo.deleted, isEmpty, reason: 'nothing is replaced before the confirmation');
    await _tap(tester, find.text(l.replacePlanOk));
    expect(repo.deleted, ['old'], reason: 'old planned workouts are replaced');
    expect(repo.savedProfile!.athlete.dayPlan, isEmpty);
    expect(repo.savedPlans, isNotEmpty);
    expect(repo.savedPlans.map((w) => w.date.weekday).toSet().difference(defaultTrainingDays.toSet()), isEmpty);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('health limitations are asked in the quick setup too', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester, level: 'intermediate');
    await _next(tester); // → health
    expect(find.text(l.healthTitle), findsOneWidget);
    await _tap(tester, find.text(l.limitKnee));
    await _finish(tester);
    expect(repo.savedProfile!.athlete.limitations, ['knee']);
  });

  testWidgets('Android back goes one setup step back instead of closing the plan settings', (tester) async {
    final profile = UserProfile(
      name: 'Anna',
      onboarded: true,
      level: 'intermediate',
      focus: TrainingFocus.run,
      trainingDays: const [1, 3, 5],
    );
    await _pump(tester, profile: profile, mode: SetupMode.plan);
    final first = find.byType(PageView);
    expect(first, findsOneWidget);
    await _next(tester);
    final page1 = tester.widget<PageView>(find.byType(PageView)).controller!.page;
    expect(page1, 1);
    // System back: one step back, the page stays open.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    // On the first step back leaves the plan settings.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets('a race of another sport is cleared when the focus changes', (tester) async {
    expect(eventFitsFocus('70.3', TrainingFocus.run), isFalse);
    expect(eventFitsFocus('hm', TrainingFocus.run), isTrue);
    expect(eventFitsFocus('70.3', TrainingFocus.triathlon), isTrue);
    expect(eventFitsFocus('ride100', TrainingFocus.triathlon), isFalse);
    expect(eventFitsFocus(null, TrainingFocus.ride), isTrue);
  });

  // User report 2026-11 ("5 h set for long runs, yet the note says they stop at 3 h"): the plan settings say
  // that the day's time is an upper limit, and offer the opt-in extension – next to the day times and in the
  // note of the plan step. The switch is saved with the profile and the new plan uses it.
  testWidgets('plan settings: long-run cap hint and the switch for longer long runs (slow marathoner)', (tester) async {
    final now = DateTime.now();
    final profile = UserProfile(
      name: 'Mia',
      birthYear: now.year - 35,
      level: 'intermediate',
      focus: TrainingFocus.run,
      experience: const {Sport.run},
      trainingDays: const [1, 2, 4, 6, 7],
      longDay: 6,
      onboarded: true,
      athlete: AthleteData(
        setupMode: 'advanced',
        sessionMinutes: 75,
        dayMinutes: const {6: 300},
        dayPlan: const {
          1: [Sport.run],
          2: [Sport.run],
          4: [Sport.run],
          6: [Sport.run],
          7: [Sport.run],
        },
        raceTimes: const {'10k': 68 * 60},
        runWeeklyKm: 35,
        longestRunKm: 16,
        eventDistance: 'm',
        eventDate: addDays(startOfWeek(dayOnly(now)), 7 * 17 + 6),
      ),
    );
    final repo = await _pump(tester, profile: profile, mode: SetupMode.plan, loaded: true);
    final setting = find.byKey(const ValueKey('extendLongRunSetting'));
    for (var i = 0; i < 4 && setting.evaluate().isEmpty; i++) {
      await _next(tester);
    }
    expect(setting, findsOneWidget, reason: 'next to the day times');
    expect(find.byKey(const ValueKey('longCapHint-run')), findsOneWidget);
    expect(find.text(l.timeLongCapRun(formatMinutes(180))), findsOneWidget);
    expect(find.text(l.longRunExtendSwitch(formatMinutes(210))), findsOneWidget);
    expect(tester.widget<SwitchListTile>(setting).value, isFalse);
    await _tap(tester, setting);
    expect(tester.widget<SwitchListTile>(setting).value, isTrue);
    expect(find.text(l.timeLongCapRun(formatMinutes(210))), findsOneWidget, reason: 'the hint follows the switch');
    // Plan step: the note is an info card with the same switch.
    final inNote = find.byKey(const ValueKey('extendLongRun'));
    for (var i = 0; i < 6 && inNote.evaluate().isEmpty; i++) {
      await _next(tester);
    }
    expect(inNote, findsOneWidget);
    expect(find.byKey(const ValueKey('feasNoteIcon')), findsOneWidget);
    expect(find.text(l.feasTitleNote), findsOneWidget);
    expect(tester.widget<SwitchListTile>(inNote).value, isTrue);
    await _tap(tester, inNote);
    expect(tester.widget<SwitchListTile>(inNote).value, isFalse);
    await _tap(tester, inNote);
    expect(tester.widget<SwitchListTile>(inNote).value, isTrue);
    await _finish(tester);
    if (find.text(l.replacePlanOk).evaluate().isNotEmpty) await _tap(tester, find.text(l.replacePlanOk));
    expect(repo.savedProfile!.athlete.longRunExtend, isTrue);
    final longRuns = repo.savedPlans.where((w) => w.sport == Sport.run && w.intensity == 'long');
    expect(longRuns.where((w) => w.durationMin > 182).length, inInclusiveRange(1, 2));
    expect(longRuns.every((w) => w.durationMin <= 210), isTrue);
  });

  // Audit UX-1: a pure gym plan offered running races and planned "race + shake-out" after 17 weeks without a
  // run. The event step offers a plan length only, a stale race is dropped, and the plan holds no run.
  testWidgets('gym focus: no race in the event step, a stale race is dropped', (tester) async {
    final now = DateTime.now();
    final profile = UserProfile(
      name: 'Ben',
      birthYear: now.year - 30,
      level: 'intermediate',
      focus: TrainingFocus.gym,
      experience: const {Sport.gym},
      trainingDays: const [1, 2, 3, 5, 6],
      onboarded: true,
      athlete: AthleteData(eventDistance: '10k', eventDate: addDays(startOfWeek(dayOnly(now)), 7 * 16 + 6)),
    );
    final repo = await _pump(tester, profile: profile, mode: SetupMode.plan, loaded: true);
    for (var i = 0; i < 8 && find.text(l.eventGymNoRace).evaluate().isEmpty; i++) {
      await _next(tester);
    }
    expect(find.text(l.eventGymNoRace), findsOneWidget);
    expect(find.byKey(const ValueKey('goalKind')), findsNothing, reason: 'no race to choose');
    await _finish(tester);
    if (find.text(l.replacePlanOk).evaluate().isNotEmpty) await _tap(tester, find.text(l.replacePlanOk));
    expect(repo.savedProfile!.athlete.eventDate, isNull);
    expect(repo.savedProfile!.athlete.eventDistance, isNull);
    expect(repo.savedPlans, isNotEmpty);
    expect(repo.savedPlans.where((w) => w.sport != Sport.gym), isEmpty);
  });

  // Audit UX-9 / UX-4: the plan step's options are tappable – "Add run days" goes back to the week, where the
  // recommendation now meets the marathon's 4 runs.
  testWidgets('plan step: "add run days" opens the week with the race-aware recommendation', (tester) async {
    final now = DateTime.now();
    final profile = UserProfile(
      name: 'Lea',
      birthYear: now.year - 30,
      level: 'intermediate',
      focus: TrainingFocus.hybrid,
      experience: const {Sport.gym, Sport.run},
      goals: const ['strength'],
      trainingDays: const [1, 2, 3, 4, 5, 6],
      longDay: 6,
      onboarded: true,
      athlete: AthleteData(
        setupMode: 'advanced',
        sessionMinutes: 60,
        dayPlan: const {
          1: [Sport.gym],
          2: [Sport.run],
          3: [Sport.gym],
          4: [Sport.run],
          5: [Sport.gym],
          6: [Sport.run],
        },
        raceTimes: const {'hm': 110 * 60},
        eventDistance: 'm',
        eventDate: addDays(startOfWeek(dayOnly(now)), 7 * 16 + 6),
      ),
    );
    await _pump(tester, profile: profile, mode: SetupMode.plan, loaded: true);
    final add = find.text(l.feasAddRunDays);
    for (var i = 0; i < 10 && add.evaluate().isEmpty; i++) {
      await _next(tester);
    }
    expect(add, findsOneWidget);
    await _tap(tester, add);
    expect(find.text(l.weekPlanTitle), findsOneWidget);
    expect(find.textContaining(l.recPerWeek(4)), findsWidgets, reason: 'the recommendation names 4 runs for the marathon');
  });
}
