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
  Future<void> replacePlans(List<PlannedWorkout> all, DateTime from, List<PlannedWorkout> plan) async {
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
                  body: Builder(
                    builder:
                        (c) => TextButton(
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
  final done = find.widgetWithText(FilledButton, l.letsGo).evaluate().isNotEmpty ? l.letsGo : l.save;
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
    // Mon/Wed/Fri → Tue/Wed/Sat/Sun.
    await _toggleDays(tester, [1, 2, 7, 5, 6]);
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
    await _toggleDays(tester, [1, 3, 5]);
    expect(find.text(l.quickMinOneDay), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(OnboardingPage))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _finish(tester);
    expect(repo.savedProfile!.trainingDays, [5]);
    expect(repo.savedPlans.map((w) => w.date.weekday).toSet(), {5});
  });

  testWidgets('quick start: removing the long day resets it to automatic', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester, level: 'intermediate');
    await _tap(tester, find.byKey(const ValueKey('longDay')));
    await tester.tap(find.descendant(of: find.byType(DropdownMenuItem<int?>), matching: find.textContaining('Wed')).last);
    await tester.pumpAndSettle();
    await _toggleDays(tester, [3, 6]); // drop Wednesday, add Saturday
    await _finish(tester);
    expect(repo.savedProfile!.trainingDays, [1, 5, 6]);
    expect(repo.savedProfile!.longDay, isNull);
    expect(repo.savedPlans.where((w) => w.intensity == 'long').every((w) => w.date.weekday == 6), isTrue);
  });

  testWidgets('quick start: a beginner sees which of the chosen days the plan keeps free', (tester) async {
    final repo = await _pump(tester);
    await _toSchedule(tester); // beginner, no running experience → run/walk, ≤ 3 runs
    await _toggleDays(tester, [2, 4]); // Mon–Fri
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
    await _toggleDays(tester, [2, 6]); // Mon–Sat minus Thu
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
        trainingDays: const [1, 3, 5],
        onboarded: true,
        athlete: const AthleteData(
          setupMode: 'simple',
          sessionsPerDay: 2,
          dayPlan: {
            2: [Sport.run],
            4: [Sport.run],
            6: [Sport.run, Sport.gym],
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
    expect(repo.savedPlans.map((w) => w.date.weekday).toSet().difference({1, 3, 5}), isEmpty);
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
}
