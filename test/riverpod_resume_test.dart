// R7-2: hidden tabs (and pages under a pushed route) run with TickerMode off, which pauses their
// Riverpod watches. Resuming them – on a tab switch or a route pop after a data change – threw
// "setState() or markNeedsBuild() called during build" whenever the provider graph had a diamond
// (A → B, A → C, B+C → D): flushing one branch invalidated the other, and the refresh request
// called setState on the ProviderScope in the middle of the build that flipped TickerMode.
// Fixed upstream in riverpod 3.4.0/3.4.2/3.5.0 (Dart 3.12); backported in third_party/riverpod.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/shell/home_shell.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/services/workout_store.dart';

class _Seed extends Notifier<int> {
  @override
  int build() => 0;
  void inc() => state++;
}

final _seed = NotifierProvider<_Seed, int>(_Seed.new);
final _shared = Provider<int>((ref) => ref.watch(_seed));
final _left = Provider<int>((ref) => ref.watch(_shared) + 1);
final _rightLeaf = Provider<int>((ref) => ref.watch(_shared) * 2);
final _right = Provider<int>((ref) => ref.watch(_rightLeaf));
final _topLeftFirst = Provider<int>((ref) => ref.watch(_left) + ref.watch(_right));
final _topRightFirst = Provider<int>((ref) {
  final r = ref.watch(_right);
  return ref.watch(_left) + r;
});

Session _session(String id) =>
    Session(id: id, sport: Sport.run, title: 'Run', start: DateTime.now().subtract(const Duration(hours: 2)), durationSec: 1800);

void main() {
  group('resuming a paused consumer (diamond provider graph)', () {
    for (final (name, top) in [('left first', _topLeftFirst), ('right first', _topRightFirst)]) {
      testWidgets('TickerMode off → data change → on: no build-phase setState, latest value shown ($name)', (t) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        Widget app({required bool enabled}) => UncontrolledProviderScope(
          container: container,
          child: TickerMode(
            enabled: enabled,
            child: Consumer(builder: (_, ref, _) => Text('${ref.watch(top)}', textDirection: TextDirection.ltr)),
          ),
        );
        await t.pumpWidget(app(enabled: true));
        expect(find.text('1'), findsOneWidget);
        await t.pumpWidget(app(enabled: false));
        container.read(_seed.notifier).inc();
        await t.pumpWidget(app(enabled: true));
        expect(t.takeException(), isNull);
        expect(find.text('4'), findsOneWidget);
        // Keeps updating normally afterwards.
        container.read(_seed.notifier).inc();
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.text('7'), findsOneWidget);
      });
    }

    testWidgets('a sibling branch with another active listener', (t) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Widget app({required bool enabled}) => UncontrolledProviderScope(
        container: container,
        child: Column(
          textDirection: TextDirection.ltr,
          children: [
            TickerMode(
              enabled: enabled,
              child: Consumer(builder: (_, ref, _) => Text('top ${ref.watch(_topLeftFirst)}', textDirection: TextDirection.ltr)),
            ),
            Consumer(builder: (_, ref, _) => Text('leaf ${ref.watch(_rightLeaf)}', textDirection: TextDirection.ltr)),
          ],
        ),
      );
      await t.pumpWidget(app(enabled: true));
      await t.pumpWidget(app(enabled: false));
      container.read(_seed.notifier).inc();
      await t.pump();
      expect(find.text('leaf 2'), findsOneWidget);
      await t.pumpWidget(app(enabled: true));
      expect(t.takeException(), isNull);
      expect(find.text('top 4'), findsOneWidget);
    });

    testWidgets('a page under a pushed route catches up on pop without a build-phase setState', (t) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: nav,
            home: Scaffold(body: Consumer(builder: (_, ref, _) => Text('home ${ref.watch(_topLeftFirst)}'))),
          ),
        ),
      );
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('page'))));
      await t.pumpAndSettle();
      container.read(_seed.notifier).inc();
      await t.pump();
      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('home 4'), findsOneWidget);
    });
  });

  testWidgets('HomeShell: data change, then visiting every tab throws nothing', (t) async {
    t.view.physicalSize = const Size(420, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sessions = StreamController<List<Session>>.broadcast();
    addTearDown(sessions.close);
    var list = <Session>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          authProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith(
            (ref) => Stream.value(const UserProfile(name: 'Alex', onboarded: true, weightKg: 75, birthYear: 1990)),
          ),
          sessionsProvider.overrideWith((ref) async* {
            yield list;
            yield* sessions.stream;
          }),
          plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
          templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
          goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
          exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
          weatherProvider.overrideWith((ref) => Completer<Weather>().future),
          workoutStoreProvider.overrideWithValue(MemoryWorkoutStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeShell(),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    final container = ProviderScope.containerOf(t.element(find.byType(HomeShell)));
    // Wake every tab once so each has subscribed to its providers, then go back to Home.
    for (final i in [1, 2, 3, 4, 0]) {
      container.read(navIndexProvider.notifier).set(i);
      await t.pump();
      await t.pump();
    }
    expect(t.takeException(), isNull);
    // While a tab sleeps the data changes; switching to it must not throw.
    for (final (n, i) in [1, 2, 3, 4, 0, 2].indexed) {
      list = [...list, _session('s$n')];
      sessions.add(list);
      await t.pump();
      container.read(navIndexProvider.notifier).set(i);
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull, reason: 'switch to tab $i after a data change');
    }
  });
}
