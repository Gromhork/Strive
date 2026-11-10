import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/plan_log.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/not_fit_sheet.dart';
import 'package:strive/features/calendar/plan_history_page.dart';
import 'package:strive/features/calendar/planned_workout_page.dart';
import 'package:strive/features/home/auto_adjusted_banner.dart';
import 'package:strive/features/session/session_summary_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/readiness.dart';
import 'package:strive/widgets/effort_chips.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final updates = <String, Map<String, dynamic>>{};
  final saved = <PlannedWorkout>[];
  final deleted = <String>[];
  final savedSessions = <Session>[];
  final log = <PlanLogEntry>[];
  @override
  void updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) => updates.addAll(plans);
  @override
  void savePlans(List<PlannedWorkout> list) => saved.addAll(list);
  @override
  void deletePlan(String id) => deleted.add(id);
  @override
  void saveSession(Session s) => savedSessions.add(s);
  @override
  void updatePlan(String id, Map<String, dynamic> data) {}
  @override
  void logPlanChange(PlanLogEntry e) => log.add(e);
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
    home: home,
  ),
);

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

const _profile = UserProfile(level: 'intermediate', birthYear: 1990, focus: TrainingFocus.run);

void main() {
  final now = DateTime.now();
  final today = dayOnly(now);

  PlannedWorkout run(String id, int day, {String intensity = 'easy', int min = 50}) => PlannedWorkout(
    id: id,
    date: today.add(Duration(days: day)),
    sport: Sport.run,
    title: 'Lockerer Dauerlauf',
    intensity: intensity,
    durationMin: min,
    distanceKm: min / 6,
    steps: [WorkoutStep(kind: 'steady', zone: 'E', durationSec: min * 60)],
  );
  PlannedWorkout adjusted(String id, int day) => PlannedWorkout.fromMap(id, {
    ...run(id, day, min: 45).toMap(),
    'auto': AutoAdjustment(sessionId: 's', reason: 'easyHard', at: now.subtract(const Duration(hours: 3)), durationMin: 50).toMap(),
  });

  Future<List<Override>> overrides(_FakeRepo repo, List<PlannedWorkout> plans, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    return [
      prefsProvider.overrideWithValue(p),
      repoProvider.overrideWithValue(repo),
      profileProvider.overrideWith((ref) => Stream.value(_profile)),
      sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
      templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
      plansProvider.overrideWith((ref) => Stream.value(plans)),
      exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
    ];
  }

  for (final lang in ['de', 'en']) {
    final l = lookupAppLocalizations(Locale(lang));

    testWidgets('summary: effort question first, gym prefill from effort chips, no coach battle ($lang)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final draft = Session(
        id: 'new',
        sport: Sport.gym,
        title: 'Ganzkörper',
        start: now.subtract(const Duration(hours: 1)),
        durationSec: 3000,
        exercises: [
          GymExercise(exId: 'a', name: 'bench press', effort: Effort.right, sets: [GymSet(weight: 60, reps: 8, done: true)]),
          GymExercise(exId: 'b', name: 'row', effort: Effort.hard, sets: [GymSet(weight: 50, reps: 8, done: true)]),
        ],
      );
      final o = await overrides(repo, const []);
      await t.pumpWidget(_app(const Scaffold(body: SizedBox()), lang, o));
      await t.pump();
      await t.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: draft))),
                    child: const Text('open'),
                  ),
                ),
          ),
          lang,
          o,
        ),
      );
      await t.pump();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text(l.summaryEffortTitle), findsOneWidget);
      expect(find.text(l.summaryEffortPrefilled), findsOneWidget);
      expect(find.textContaining('RPE 7'), findsOneWidget);
      expect(find.textContaining('Coach'), findsNothing);
      // Effort block sits above the XP card.
      final effortY = t.getTopLeft(find.byKey(const ValueKey('summaryEffort'))).dy;
      await t.scrollUntilVisible(find.textContaining('XP'), 100, scrollable: find.byType(Scrollable).first);
      expect(t.getTopLeft(find.textContaining('XP')).dy, greaterThan(effortY - 1000));
      // Editable: choose 9, then save.
      await t.scrollUntilVisible(find.byKey(const ValueKey('rpe-9')), -100, scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const ValueKey('rpe-9')));
      await t.pump();
      expect(find.text(l.summaryEffortPrefilled), findsNothing);
      await t.scrollUntilVisible(find.text(l.saveWorkout), 100, scrollable: find.byType(Scrollable).first);
      // scrollUntilVisible stops as soon as the button's top edge enters the view.
      await t.ensureVisible(find.text(l.saveWorkout));
      await t.pumpAndSettle();
      await t.tap(find.text(l.saveWorkout));
      await t.pumpAndSettle();
      expect(repo.savedSessions.single.rpe, 9);
    });

    testWidgets('home banner and review sheet: undo per item, OK marks seen ($lang)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final a = adjusted('a', 1), b = adjusted('b', 2);
      final o = await overrides(repo, [a, b]);
      await t.pumpWidget(_app(const Scaffold(body: Column(children: [AutoAdjustedBanner()])), lang, o));
      await t.pumpAndSettle();
      expect(find.text(l.autoAdjBanner(2)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('autoAdjBanner')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text(l.autoAdjSheetIntro), findsOneWidget);
      expect(find.textContaining('→'), findsNWidgets(2));
      await t.tap(find.byKey(const ValueKey('autoAdjUndo_a')));
      await t.pumpAndSettle();
      expect(repo.updates['a']!['durationMin'], 50);
      expect(find.byKey(const ValueKey('autoAdjItem_a')), findsNothing);
      await t.tap(find.byKey(const ValueKey('autoAdjOk')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('autoAdjBanner')), findsNothing);
      final container = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
      expect(container.read(prefsProvider).getStringList(autoAdjSeenKey), containsAll([autoAdjSeenId(b)]));
    });

    testWidgets('home banner hides while the adjust-week banner shows ($lang)', (t) async {
      _phone(t);
      final missed = run('m', -1, intensity: 'tempo').toMap();
      final o = await overrides(_FakeRepo(), [
        adjusted('a', 1),
        PlannedWorkout.fromMap('m', {...missed, 'isKey': true}),
      ]);
      await t.pumpWidget(_app(const Scaffold(body: Column(children: [AutoAdjustedBanner()])), lang, o));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('autoAdjBanner')), findsNothing);
    });

    testWidgets('not feeling 100 %: choose, preview with hints, apply ($lang)', (t) async {
      _phone(t);
      final p = run('t', 0, intensity: 'tempo', min: 60);
      final advisor = ReadinessAdvisor(l, _profile, plans: [p], sessions: const [], now: now);
      ReadinessPlan? result;
      await t.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<ReadinessPlan>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => NotFitSheet(plan: p, propose: (k, m) => advisor.propose(p, k, minutes: m)),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
          lang,
          await overrides(_FakeRepo(), [p]),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('notFitApply'))).onPressed, isNull);
      for (final k in Readiness.values) {
        await t.tap(find.byKey(ValueKey('notFit_${k.name}')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: k.name);
      }
      expect(find.byKey(const ValueKey('notFitMin_30')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('notFitMin_30')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text(l.notFitHintTime), 80, scrollable: find.byType(Scrollable).last);
      expect(find.text(l.notFitHintTime), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('notFit_tired')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text(l.notFitHintKeyEasy), 80, scrollable: find.byType(Scrollable).last);
      expect(find.text(l.notFitHintKeyEasy), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('notFitApply')));
      await t.pumpAndSettle();
      expect(result!.kind, Readiness.tired);
      expect(result!.changes.single.$2.intensity, 'easy');
    });

    testWidgets('planned workout: not-fit and ask-coach actions ($lang)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final p = run('e', 0);
      final o = await overrides(repo, [p]);
      await t.pumpWidget(_app(const PlannedWorkoutPage(planId: 'e'), lang, o));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('notFitButton')), findsOneWidget);
      // Apply "tired" through the real sheet: saved, logged as a readiness change.
      await t.tap(find.byKey(const ValueKey('notFitButton')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('notFit_tired')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('notFitApply')));
      await t.pumpAndSettle();
      expect(repo.saved.single.durationMin, lessThan(50));
      expect(repo.log.single.source, 'readiness');
      expect(repo.log.single.reason, 'tired');
      await t.tap(find.byKey(const ValueKey('askCoachButton')));
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(t.element(find.byType(Navigator).first));
      expect(c.read(navIndexProvider), 4);
      expect(c.read(coachDraftProvider), contains(p.title));
    });

    testWidgets('plan history lists changes with undo ($lang)', (t) async {
      _phone(t);
      final repo = _FakeRepo();
      final before = run('x', 2);
      final after = PlannedWorkout.fromMap('x', {...before.toMap(), 'durationMin': 40, 'distanceKm': 6.7});
      final added = run('n', 3);
      final entries = [
        PlanLogEntry.of('recal', [(before, after), (null, added)], note: 'Deine letzten Einheiten waren zu hart.').withId('r'),
        PlanLogEntry.of('readiness', [
          (run('y', 0), PlannedWorkout.fromMap('y', {...run('y', 0).toMap(), 'status': 'skipped'})),
        ], reason: 'sick').withId('s'),
      ];
      final o = await overrides(repo, [after, added]);
      await t.pumpWidget(_app(const PlanHistoryPage(), lang, [...o, planLogProvider.overrideWith((ref) => Stream.value(entries))]));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text(l.planLogRecal), findsOneWidget);
      expect(find.text(l.planLogReadiness(l.notFitSick)), findsOneWidget);
      expect(find.text(l.planLogChanged), findsOneWidget); // 'y' no longer exists as skipped
      await t.tap(find.byKey(const ValueKey('planLogUndo_r')));
      await t.pump();
      expect(repo.saved.single.durationMin, 50);
      expect(repo.deleted, ['n']);
    });

    testWidgets('reserve chips: 4+ 3 2 1 0 stored as RPE ($lang)', (t) async {
      _phone(t);
      double? rpe;
      await t.pumpWidget(
        _app(
          Scaffold(body: StatefulBuilder(builder: (c, set) => ReservePicker(rpe: rpe, onChanged: (v) => set(() => rpe = v)))),
          lang,
          const [],
        ),
      );
      expect(find.text(l.reserveLabel), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('rir-4+')));
      await t.pump();
      expect(rpe, 6);
      await t.tap(find.byKey(const ValueKey('rir-0')));
      await t.pump();
      expect(rpe, 10);
      await t.tap(find.byKey(const ValueKey('rir-0')));
      await t.pump();
      expect(rpe, isNull);
      expect(t.takeException(), isNull);
    });
  }
}

extension on PlanLogEntry {
  PlanLogEntry withId(String id) => PlanLogEntry.fromMap(id, toMap());
}
