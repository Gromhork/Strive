import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/onboarding/gym_assign_section.dart';
import 'package:strive/features/onboarding/onboarding_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_service.dart';
import 'package:strive/widgets/segments.dart';

final l = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

/// Holds the profile like the setup page does ([AthleteData.merge] on every change).
class _Host extends StatefulWidget {
  const _Host(this.initial, this.templates);
  final UserProfile initial;
  final List<WorkoutTemplate> templates;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late UserProfile p = widget.initial;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GymAssignSection(
        profile: p,
        templates: widget.templates,
        onChanged: (c) => setState(() => p = p.copyWith(athlete: p.athlete.merge(c))),
      ),
    ),
  );
}

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  var _n = 0;
  UserProfile? savedProfile;
  final savedPlans = <PlannedWorkout>[];
  final savedTemplates = <WorkoutTemplate>[];
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
  Future<void> deletePlansFrom(List<PlannedWorkout> all, DateTime from) async {}
  @override
  Future<void> replacePlans(List<PlannedWorkout> all, DateTime from, List<PlannedWorkout> plan, {Set<String> keep = const {}}) async =>
      savePlans(plan);
  @override
  Future<List<WorkoutTemplate>?> templatesFromServer() async => null;
}

void main() {
  var n = 0;
  final templates = defaultTemplates(() => 't${n++}', de: false);
  final mine = WorkoutTemplate(
    id: 'mine',
    name: 'My Arms',
    sport: Sport.gym,
    folder: 'Own',
    exercises: [for (final e in templates.firstWhere((t) => t.key == 'bro_arms').exercises) e.copy()],
  );
  final ppl = UserProfile(
    level: 'intermediate',
    focus: TrainingFocus.gym,
    birthYear: DateTime.now().year - 30,
    trainingDays: const [1, 3, 5],
    athlete: const AthleteData(gymSplit: 'ppl'),
  );

  Future<void> pumpHost(WidgetTester tester, UserProfile p, {List<WorkoutTemplate>? list}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_Host(p, list ?? [...templates, mine])));
    await tester.pumpAndSettle();
  }

  UserProfile hostProfile(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).p;

  testWidgets('switching on prefills the suggestion per gym day', (tester) async {
    await pumpHost(tester, ppl);
    expect(find.text(l.gymAssignTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('gymDay1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gymAssign')));
    await tester.pumpAndSettle();
    final a = hostProfile(tester).athlete;
    expect(a.gymAssign, isTrue);
    expect(a.gymPlanA, {1: 'key:ppl_push', 3: 'key:ppl_pull', 5: 'key:ppl_legs'});
    expect(find.descendant(of: find.byKey(const ValueKey('gymDay1')), matching: find.text('Push')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gymDay3')), matching: find.text('Pull')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('gymDay5')), matching: find.text('Legs')), findsOneWidget);
    // No week B without the A/B switch.
    expect(find.byType(Segments<String>), findsNothing);
  });

  testWidgets('week A / week B: own programs from the searchable picker, stored per week', (tester) async {
    await pumpHost(tester, ppl);
    await tester.tap(find.byKey(const ValueKey('gymAssign')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gymAB')));
    await tester.pumpAndSettle();
    expect(find.byType(Segments<String>), findsOneWidget);
    await tester.tap(find.text(l.gymWeekB));
    await tester.pumpAndSettle();
    // Week B, Monday: search and pick the athlete's own program.
    await tester.tap(find.byKey(const ValueKey('gymDay1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gymProgramSearch')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('gymProgramSearch')), 'arms');
    await tester.pumpAndSettle();
    expect(find.text('My Arms'), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Push')), findsNothing);
    await tester.tap(find.text('My Arms'));
    await tester.pumpAndSettle();
    var a = hostProfile(tester).athlete;
    expect(a.gymAB, isTrue);
    expect(a.gymPlanB[1], 'id:mine');
    expect(a.gymPlanA[1], 'key:ppl_push'); // week A unchanged
    expect(find.descendant(of: find.byKey(const ValueKey('gymDay1')), matching: find.text('My Arms')), findsOneWidget);
    // Week A shows its own programs again; a built-in the athlete doesn't have yet can be picked too.
    await tester.tap(find.text(l.gymWeekA));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('gymDay1')), matching: find.text('Push')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gymDay5')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gymProgramSearch')), 'lower b');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lower B'));
    await tester.pumpAndSettle();
    a = hostProfile(tester).athlete;
    expect(a.gymPlanA[5], 'key:ul_lower_b');
  });

  testWidgets('warns about the same program on consecutive days and legs before the long run', (tester) async {
    final hybrid = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.hybrid,
      birthYear: DateTime.now().year - 30,
      trainingDays: const [1, 2, 4, 5, 6],
      longDay: 6,
      athlete: const AthleteData(
        gymSplit: 'ppl',
        setupMode: 'advanced',
        dayPlan: {
          1: [Sport.gym],
          2: [Sport.gym],
          4: [Sport.run],
          5: [Sport.gym],
          6: [Sport.run],
        },
      ),
    );
    await pumpHost(tester, hybrid);
    await tester.tap(find.byKey(const ValueKey('gymAssign')));
    await tester.pumpAndSettle();
    const days = [1, 2, 5];
    expect(hostProfile(tester).athlete.gymPlanA.keys.toList()..sort(), days);
    expect(find.textContaining('48 h'), findsNothing);
    // Every gym day: the same leg day.
    for (final d in days) {
      await tester.tap(find.byKey(ValueKey('gymDay$d')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('gymProgramSearch')), 'legs');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick_ppl_legs')));
      await tester.pumpAndSettle();
    }
    expect(find.text(l.gymAssignWarnRepeat('Legs', 'Mon–Tue')), findsOneWidget);
    expect(find.text(l.gymAssignWarnLegs('Legs', 'Fri')), findsOneWidget);
  });

  testWidgets('plan settings: the assignment is saved and the new plan uses exactly these programs', (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    PlanService.reset();
    final repo = _FakeRepo();
    final profile = ppl.copyWith(onboarded: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(repo),
          profileProvider.overrideWith((ref) => Stream.value(profile)),
          templatesProvider.overrideWith((ref) => Stream.value(templates)),
          plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
          goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
        ],
        child: _app(const OnboardingPage(mode: SetupMode.plan)),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> next() async {
      final f = find.widgetWithText(FilledButton, l.next);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 6 && find.byKey(const ValueKey('gymAssign')).evaluate().isEmpty; i++) {
      await next();
    }
    final sw = find.byKey(const ValueKey('gymAssign'));
    await tester.ensureVisible(sw);
    await tester.pumpAndSettle();
    await tester.tap(sw);
    await tester.pumpAndSettle();
    // The first gym day: Legs instead of the suggestion.
    final dayButtons = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('gymDay'));
    expect(dayButtons, findsWidgets);
    final first = int.parse('${(tester.widget(dayButtons.first).key as ValueKey).value}'.substring(6));
    await tester.ensureVisible(dayButtons.first);
    await tester.tap(dayButtons.first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gymProgramSearch')), 'legs');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick_ppl_legs')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && find.widgetWithText(FilledButton, l.next).evaluate().isNotEmpty; i++) {
      await next();
    }
    final done = [l.letsGo, l.recreatePlan, l.save].firstWhere((t) => find.widgetWithText(FilledButton, t).evaluate().isNotEmpty);
    final finish = find.widgetWithText(FilledButton, done);
    await tester.ensureVisible(finish);
    await tester.pumpAndSettle();
    await tester.tap(finish);
    await tester.pumpAndSettle();
    if (find.text(l.replacePlanOk).evaluate().isNotEmpty) {
      await tester.tap(find.text(l.replacePlanOk));
      await tester.pumpAndSettle();
    }
    final saved = repo.savedProfile!.athlete;
    expect(saved.gymAssign, isTrue);
    expect(saved.gymPlanA[first], 'key:ppl_legs');
    final gym = repo.savedPlans.where((p) => p.sport == Sport.gym).toList();
    expect(gym, isNotEmpty);
    final byId = {
      for (final t in [...templates, ...repo.savedTemplates]) t.id: t,
    };
    for (final g in gym) {
      expect('key:${byId[g.templateId]?.key}', saved.gymPlanA[g.date.weekday], reason: '${g.date}');
    }
  });
}
