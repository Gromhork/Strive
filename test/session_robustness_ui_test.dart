import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/plan_editor.dart';
import 'package:strive/features/goals/goals_page.dart';
import 'package:strive/features/session/cardio_session_page.dart';
import 'package:strive/features/session/gym_session_page.dart';
import 'package:strive/features/session/manual_entry_page.dart';
import 'package:strive/features/session/session_summary_page.dart';
import 'package:strive/features/session/step_editor.dart';
import 'package:strive/features/calendar/calendar_page.dart' show CalendarPage;
import 'package:strive/features/home/home_page.dart' show HomePage;
import 'package:strive/features/stats/stats_page.dart' show StatsPage;
import 'package:strive/features/shell/home_shell.dart';
import 'package:strive/features/shell/workout_restore.dart';
import 'package:strive/features/stats/edit_session_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/services/workout_store.dart';

const _profile = UserProfile(name: 'Alex', onboarded: true, weightKg: 75, birthYear: 1990);

List<Override> _overrides(SharedPreferences prefs, WorkoutStore store, {List<Override> extra = const []}) => [
  prefsProvider.overrideWithValue(prefs),
  authProvider.overrideWith((ref) => Stream.value(null)),
  profileProvider.overrideWith((ref) => Stream.value(_profile)),
  sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
  plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
  templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
  goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
  bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
  exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
  weatherProvider.overrideWith((ref) => Completer<Weather>().future),
  workoutStoreProvider.overrideWithValue(store),
  ...extra,
];

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
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
    home: home,
  ),
);

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<ProviderContainer> _pump(WidgetTester t, Widget home, List<Override> overrides) async {
  t.view.physicalSize = const Size(420, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(home, overrides));
  await t.pump();
  await t.pump();
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

/// Android back button.
Future<void> _back(WidgetTester t, {bool settle = true}) async {
  await t.binding.handlePopRoute();
  settle ? await t.pumpAndSettle() : await t.pump(const Duration(milliseconds: 500));
}

/// Records platform calls the app makes on back (exit / move to background).
List<String> _platformCalls(WidgetTester t) {
  final calls = <String>[];
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    calls.add(c.method);
    return null;
  });
  m.setMockMethodCallHandler(const MethodChannel('com.gromhork.strive/app'), (c) async {
    calls.add(c.method);
    return true;
  });
  // Wakelock (gym / cardio sessions) – a no-op here.
  m.setMockMessageHandler('dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle', (_) async {
    return const StandardMessageCodec().encodeMessage(<Object?>[null]);
  });
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(const MethodChannel('com.gromhork.strive/app'), null);
    m.setMockMessageHandler('dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle', null);
  });
  return calls;
}

ActiveGym _gym() => ActiveGym(
  title: 'Push A',
  start: DateTime.now().subtract(const Duration(minutes: 20)),
  exercises: [
    GymExercise(exId: 'bench', name: 'bench press', sets: [GymSet(weight: 80, reps: 8, done: true), GymSet(weight: 80, reps: 8)]),
  ],
);

/// A page with a button that pushes [page] (so back has somewhere to go).
Widget _launcher(Widget Function() page) => Builder(
  builder:
      (c) => Scaffold(
        body: Center(
          child: FilledButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page())), child: const Text('open')),
        ),
      ),
);

void main() {
  // ───────────────────────────── Restore prompt ─────────────────────────────

  group('restore after the app was killed', () {
    testWidgets('gym: prompt shows the start time; continue restores the workout', (t) async {
      _platformCalls(t);
      final store = MemoryWorkoutStore();
      final g = _gym();
      await store.saveGym(g);
      final c = await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), store));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('restoreDialog')), findsOneWidget);
      expect(find.text('Continue workout?'), findsOneWidget);
      final hm = '${g.start.hour.toString().padLeft(2, '0')}:${g.start.minute.toString().padLeft(2, '0')}';
      expect(find.textContaining(hm), findsOneWidget);
      expect(find.textContaining('Push A'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('restoreResume')));
      await t.pumpAndSettle();
      final w = c.read(activeGymProvider);
      expect(w, isNotNull);
      expect(w!.title, 'Push A');
      expect(w.doneSets, 1);
      expect(w.start, DateTime.fromMillisecondsSinceEpoch(g.start.millisecondsSinceEpoch));
      expect(find.byType(GymSessionPage), findsOneWidget);
      // Autosave is on again after the decision: checking a set off is written at once.
      final before = store.saves;
      c.read(activeGymProvider.notifier).toggleDone(0, 1);
      await t.pump();
      expect(store.saves, greaterThan(before));
      expect((await store.loadActive())?.gym?.doneSets, 2);
      c.read(activeGymProvider.notifier).discard();
      await t.pump();
      expect(store.active, isNull);
    });

    testWidgets('gym: discard clears the stored workout', (t) async {
      _platformCalls(t);
      final store = MemoryWorkoutStore();
      await store.saveGym(_gym());
      final c = await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), store));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('restoreDiscard')));
      await t.pumpAndSettle();
      expect(store.active, isNull);
      expect(c.read(activeGymProvider), isNull);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('back on the prompt does not dismiss it (no workout in limbo), the workout is kept', (t) async {
      _platformCalls(t);
      final store = MemoryWorkoutStore();
      await store.saveGym(_gym());
      await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), store));
      await t.pumpAndSettle();
      await _back(t);
      expect(find.byKey(const ValueKey('restoreDialog')), findsOneWidget);
      expect(store.active, isNotNull);
    });

    testWidgets('cardio (indoor): time continues from the timestamps, route and laps are kept', (t) async {
      _platformCalls(t);
      final store = MemoryWorkoutStore();
      final start = DateTime.now().subtract(const Duration(minutes: 30));
      await store.saveCardio(
        CardioState(
          sport: Sport.run,
          title: 'Treadmill',
          start: start,
          accumulatedSec: 600,
          runningSince: DateTime.now().subtract(const Duration(minutes: 10)),
          indoor: true,
          laps: 2,
          lapSecs: const [300, 300],
          lapDists: const [0, 0],
          lapStartSec: 600,
          points: const [LatLng(52.5, 13.4), LatLng(52.51, 13.41)],
          steps: const [WorkoutStep(kind: 'steady', durationSec: 3600)],
        ),
      );
      final c = await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), store));
      await t.pumpAndSettle();
      expect(find.text('Continue workout?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('restoreResume')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      final s = c.read(trackerProvider)!;
      expect(s.title, 'Treadmill');
      expect(s.paused, isFalse);
      // 10 min before + 10 min since the last resume (the app was gone in between).
      expect(s.elapsed, inInclusiveRange(1199, 1202));
      expect(s.laps, 2);
      expect(s.points.length, 2);
      expect(s.structured, isTrue);
      expect(find.byType(CardioSessionPage), findsOneWidget);
      c.read(trackerProvider.notifier).discard();
      await t.pump(const Duration(seconds: 1));
      expect(store.active, isNull);
    });

    testWidgets('unsaved summary: reopened with rating and notes', (t) async {
      _platformCalls(t);
      final store = MemoryWorkoutStore();
      await store.saveSummary(
        Session(id: 's1', sport: Sport.gym, title: 'Legs', start: DateTime.now(), durationSec: 3000, rpe: 7, notes: 'heavy day'),
      );
      await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), store));
      await t.pumpAndSettle();
      expect(find.text('Save your workout?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('restoreResume')));
      await t.pumpAndSettle();
      expect(find.byType(SessionSummaryPage), findsOneWidget);
      expect(find.text('heavy day'), findsOneWidget);
      // Back on the summary still asks before throwing the workout away.
      await _back(t);
      expect(find.byType(SessionSummaryPage), findsOneWidget);
      await t.tap(find.text('Discard').last);
      await t.pumpAndSettle();
      expect(find.byType(SessionSummaryPage), findsNothing);
      expect(store.summary, isNull);
    });

    testWidgets('nothing stored: no prompt', (t) async {
      _platformCalls(t);
      await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), MemoryWorkoutStore()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('restoreDialog')), findsNothing);
    });
  });

  // ───────────────────────────── Autosave ─────────────────────────────

  testWidgets('autosave: set toggles immediately, other edits throttled to 2 s', (t) async {
    _platformCalls(t);
    final store = MemoryWorkoutStore();
    final c = await _pump(t, const WorkoutRestoreGate(child: Scaffold(body: Text('home'))), _overrides(await _prefs(), store));
    await t.pumpAndSettle();
    final n = c.read(activeGymProvider.notifier);
    n.start(
      title: 'Free',
      exercises: [
        GymExercise(exId: 'row', name: 'row', sets: [GymSet(weight: 50, reps: 10)]),
      ],
    );
    await t.pump();
    expect(store.saves, 1); // start
    n.updateSet(0, 0, reps: 12);
    await t.pump();
    expect(store.saves, 1); // throttled
    await t.pump(const Duration(seconds: 2));
    expect(store.saves, 2);
    expect(jsonDecode(store.active!)['data']['exercises'][0]['sets'][0]['r'], 12);
    n.toggleDone(0, 0);
    await t.pump();
    expect(store.saves, 3); // immediately
    n.skipRest();
    await t.pump(const Duration(seconds: 3));
    n.discard();
    await t.pump();
    expect(store.active, isNull);
  });

  // ───────────────────────────── Android back ─────────────────────────────

  group('Android back', () {
    testWidgets('shell: other tab → Home → hint → exit; with a running workout only to the background', (t) async {
      final calls = _platformCalls(t);
      final c = await _pump(t, const HomeShell(), _overrides(await _prefs(), MemoryWorkoutStore()));
      await t.pump(const Duration(milliseconds: 500));
      c.read(navIndexProvider.notifier).set(2);
      await t.pump();
      await _back(t, settle: false);
      expect(c.read(navIndexProvider), 0);
      expect(calls, isNot(contains('SystemNavigator.pop')));
      await _back(t, settle: false);
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(calls, isNot(contains('SystemNavigator.pop')));
      await _back(t, settle: false);
      expect(calls, contains('SystemNavigator.pop'));

      // Workout running: never finish the activity.
      calls.clear();
      await t.pump(const Duration(seconds: 3));
      c.read(activeGymProvider.notifier).start(title: 'Gym', exercises: [GymExercise(exId: 'x', name: 'x')]);
      await t.pump();
      await _back(t, settle: false);
      await t.pump(const Duration(milliseconds: 500)); // the previous hint is still fading out
      expect(find.text('Your workout keeps running in the background.'), findsOneWidget);
      await _back(t, settle: false);
      expect(calls, contains('moveTaskToBack'));
      expect(calls, isNot(contains('SystemNavigator.pop')));
      expect(c.read(activeGymProvider), isNotNull);
      c.read(activeGymProvider.notifier).discard();
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('shell: hidden tabs sleep (tickers off – their provider watches pause), the shown one is awake', (t) async {
      final c = await _pump(t, const HomeShell(), _overrides(await _prefs(), MemoryWorkoutStore()));
      bool awake(Type page) => TickerMode.of(t.element(find.byType(page, skipOffstage: false)));
      expect(awake(HomePage), isTrue);
      expect(awake(CalendarPage), isFalse);
      expect(awake(StatsPage), isFalse);
      c.read(navIndexProvider.notifier).set(2);
      await t.pump();
      expect(awake(CalendarPage), isTrue);
      expect(awake(HomePage), isFalse);
      expect(identical(AppTheme.dark(), AppTheme.dark()), isTrue, reason: 'one theme instance: no app-wide rebuild per root rebuild');
    });

    testWidgets('gym session: back minimizes, the workout keeps running', (t) async {
      _platformCalls(t);
      final c = await _pump(t, _launcher(() => const GymSessionPage()), _overrides(await _prefs(), MemoryWorkoutStore()));
      c.read(activeGymProvider.notifier).start(title: 'Gym', exercises: [GymExercise(exId: 'x', name: 'x')]);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(GymSessionPage), findsOneWidget);
      await _back(t);
      expect(find.byType(GymSessionPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(c.read(activeGymProvider), isNotNull);
      c.read(activeGymProvider.notifier).discard();
      await t.pump();
    });

    testWidgets('manual entry: back leaves at once without changes, asks with changes', (t) async {
      _platformCalls(t);
      await _pump(t, _launcher(() => const ManualEntryPage()), _overrides(await _prefs(), MemoryWorkoutStore()));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await _back(t);
      expect(find.byType(ManualEntryPage), findsNothing);

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Evening run');
      await _back(t);
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.byType(ManualEntryPage), findsOneWidget);
      expect(find.text('Evening run'), findsOneWidget);
      await _back(t);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.byType(ManualEntryPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('edit session: unsaved changes are protected', (t) async {
      _platformCalls(t);
      final s = Session(id: 'e1', sport: Sport.run, title: 'Run', start: DateTime(2026, 11, 9, 18), durationSec: 1800, distanceM: 5000);
      await _pump(t, _launcher(() => EditSessionPage(session: s)), _overrides(await _prefs(), MemoryWorkoutStore()));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await _back(t);
      expect(find.byType(EditSessionPage), findsNothing);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Tempo run');
      await _back(t);
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.byType(EditSessionPage), findsNothing);
    });

    testWidgets('plan editor: unsaved changes are protected', (t) async {
      _platformCalls(t);
      await _pump(
        t,
        Consumer(
          builder:
              (context, ref, _) =>
                  Scaffold(body: Center(child: FilledButton(onPressed: () => showPlanEditor(context, ref), child: const Text('open')))),
        ),
        _overrides(await _prefs(), MemoryWorkoutStore()),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('Plan workout'), findsWidgets);
      await _back(t);
      expect(find.text('open'), findsOneWidget);

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Long run');
      await _back(t);
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Long run'), findsOneWidget);
      await _back(t);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('goal editor sheet: unsaved changes are protected', (t) async {
      _platformCalls(t);
      await _pump(
        t,
        Consumer(
          builder:
              (context, ref, _) =>
                  Scaffold(body: Center(child: FilledButton(onPressed: () => showGoalEditor(context, ref), child: const Text('open')))),
        ),
        _overrides(await _prefs(), MemoryWorkoutStore()),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('New goal'), findsOneWidget);
      await _back(t);
      expect(find.text('New goal'), findsNothing);

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Run more');
      await _back(t);
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('New goal'), findsOneWidget);
      await _back(t);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.text('New goal'), findsNothing);
    });

    testWidgets('step sheet: unsaved changes are protected', (t) async {
      _platformCalls(t);
      var steps = const [WorkoutStep(kind: 'steady', durationSec: 1800, zone: 'E')];
      await _pump(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (_, set) => StepEditor(steps: steps, sport: Sport.run, profile: _profile, onChanged: (s) => set(() => steps = s)),
            ),
          ),
        ),
        _overrides(await _prefs(), MemoryWorkoutStore()),
      );
      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await t.pumpAndSettle();
      expect(find.text('Edit section'), findsOneWidget);
      await _back(t);
      expect(find.text('Edit section'), findsNothing);

      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.add_rounded).last);
      await t.pump();
      await _back(t);
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.text('Edit section'), findsNothing);
      expect(steps.single.durationSec, 1800);
    });

    testWidgets('cardio session: back minimizes; locked screen ignores back', (t) async {
      _platformCalls(t);
      final c = await _pump(t, _launcher(() => const CardioSessionPage()), _overrides(await _prefs(), MemoryWorkoutStore()));
      await c.read(trackerProvider.notifier).start(sport: Sport.run, title: 'Treadmill', indoor: true);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(CardioSessionPage), findsOneWidget);
      await t.tap(find.byIcon(Icons.lock_outline_rounded));
      await t.pump();
      await _back(t);
      expect(find.byType(CardioSessionPage), findsOneWidget);
      c.read(trackerProvider.notifier).discard();
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('cardio session unlocked: back returns to the previous screen', (t) async {
      _platformCalls(t);
      final c = await _pump(t, _launcher(() => const CardioSessionPage()), _overrides(await _prefs(), MemoryWorkoutStore()));
      await c.read(trackerProvider.notifier).start(sport: Sport.ride, title: 'Trainer', indoor: true);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await _back(t);
      expect(find.byType(CardioSessionPage), findsNothing);
      expect(c.read(trackerProvider), isNotNull);
      c.read(trackerProvider.notifier).discard();
      await t.pump(const Duration(seconds: 1));
    });
  });
}
