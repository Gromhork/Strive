// Round 10 (owner): "On some pages, e.g. body composition, tapping the tile opens the same page again
// and I have to close it twice." The body page shows the body-composition card, whose tap opened the
// body page again; a fast double tap on any tile stacked its page twice as well. Every tile/row now
// opens its page through [openPage]: one tap → one route, back once → where you came from.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/home/home_page.dart';
import 'package:strive/features/home/week_page.dart';
import 'package:strive/features/profile/profile_page.dart';
import 'package:strive/features/stats/body_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/widgets/nav.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  @override
  void saveProfile(UserProfile p) {}
}

/// Counts the pages pushed on the app's navigator.
class _Pushes extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) names.add(route.settings.name); // not the home route
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => names.removeLast();
}

Widget _app(Widget home, _Pushes obs, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
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
    navigatorObservers: [obs],
    home: home,
  ),
);

Future<List<Override>> _overrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    prefsProvider.overrideWithValue(prefs),
    authProvider.overrideWith((ref) => Stream.value(null)),
    repoProvider.overrideWithValue(_FakeRepo()),
    profileProvider.overrideWith((ref) => Stream.value(const UserProfile(name: 'Alex', onboarded: true, weightKg: 80, heightCm: 180))),
    sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
    plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
    templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
    goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
    bodyProvider.overrideWith(
      (ref) => Stream.value([
        BodyEntry(id: 'a', date: DateTime.now().subtract(const Duration(days: 10)), weightKg: 81),
        BodyEntry(id: 'b', date: DateTime.now().subtract(const Duration(days: 1)), weightKg: 80),
      ]),
    ),
    weatherProvider.overrideWith((ref) => Completer<Weather>().future), // offline: no fetch, no timer
  ];
}

void _size(WidgetTester t) {
  t.view.physicalSize = const Size(400, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// A page with a tile that opens [page] via [openPage].
class _Tile extends StatelessWidget {
  const _Tile(this.page, {this.label = 'tile'});
  final Widget page;
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: InkWell(onTap: () => openPage(context, page), child: Padding(padding: const EdgeInsets.all(24), child: Text(label))),
    ),
  );
}

class _Target extends StatelessWidget {
  const _Target();
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: const _Tile(_Target(), label: 'self'));
}

void main() {
  group('openPage', () {
    testWidgets('one tap → one route; back once → the previous page', (t) async {
      final obs = _Pushes();
      await t.pumpWidget(_app(const _Tile(_Target()), obs));
      await t.tap(find.text('tile'));
      await t.pumpAndSettle();
      expect(obs.names, ['_Target']);
      await t.binding.handlePopRoute(); // the system back button
      await t.pumpAndSettle();
      expect(obs.names, isEmpty);
      expect(find.text('tile'), findsOneWidget);
    });

    testWidgets('a fast double tap opens the page once', (t) async {
      final obs = _Pushes();
      await t.pumpWidget(_app(const _Tile(_Target()), obs));
      await t.tap(find.text('tile'));
      await t.tap(find.text('tile')); // before the next frame: still hits the tile
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.text('tile'), warnIfMissed: false); // during the transition
      await t.pumpAndSettle();
      expect(obs.names, ['_Target']);
    });

    testWidgets('a tile on the page it opens does nothing', (t) async {
      final obs = _Pushes();
      await t.pumpWidget(_app(const _Tile(_Target()), obs));
      await t.tap(find.text('tile'));
      await t.pumpAndSettle();
      await t.tap(find.text('self'));
      await t.pumpAndSettle();
      expect(obs.names, ['_Target']);
    });

    test('route names tell records apart', () {
      expect(pageRouteName(const _Target()), '_Target');
      expect(pageRouteName(const _Target(), 's1'), '_Target/s1');
    });
  });

  group('body composition', () {
    testWidgets('the card on the body page is no link to itself', (t) async {
      _size(t);
      final obs = _Pushes();
      await t.pumpWidget(_app(const BodyPage(), obs, overrides: await _overrides()));
      await t.pumpAndSettle();
      final card = find.descendant(of: find.byType(BodyCompositionCard), matching: find.byType(InkWell)).first;
      expect(t.widget<InkWell>(card).onTap, isNull);
      final l = AppLocalizations.of(t.element(find.byType(BodyPage)));
      await t.tap(find.descendant(of: find.byType(BodyCompositionCard), matching: find.text(l.bodyComposition)));
      await t.pumpAndSettle();
      expect(obs.names, isEmpty);
    });

    testWidgets('profile → body composition → tap its card → back once is the profile again', (t) async {
      _size(t);
      final obs = _Pushes();
      await t.pumpWidget(_app(const ProfilePage(), obs, overrides: await _overrides()));
      await t.pumpAndSettle();
      final l = AppLocalizations.of(t.element(find.byType(ProfilePage)));
      await t.tap(find.text(l.bodyComposition));
      await t.pumpAndSettle();
      expect(obs.names, hasLength(1));
      await t.tap(find.descendant(of: find.byType(BodyCompositionCard), matching: find.text(l.bodyComposition))); // the card's title
      await t.pumpAndSettle();
      expect(obs.names, hasLength(1), reason: 'no second body page');
      await t.binding.handlePopRoute(); // the system back button
      await t.pumpAndSettle();
      expect(obs.names, isEmpty);
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });

  group('home tiles', () {
    Future<_Pushes> home(WidgetTester t) async {
      _size(t);
      final obs = _Pushes();
      await t.pumpWidget(_app(const Scaffold(body: HomePage()), obs, overrides: await _overrides()));
      await t.pump(const Duration(seconds: 1));
      return obs;
    }

    testWidgets('weight tile → one body page, its card does not stack it again', (t) async {
      final obs = await home(t);
      final weight = find.byKey(const ValueKey('weightCard'));
      await t.tap(weight, warnIfMissed: false);
      await t.tap(weight, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(obs.names, hasLength(1));
      final l = AppLocalizations.of(t.element(find.byType(BodyPage)));
      await t.tap(find.descendant(of: find.byType(BodyCompositionCard), matching: find.text(l.bodyComposition)));
      await t.pumpAndSettle();
      expect(obs.names, hasLength(1));
      await t.binding.handlePopRoute(); // the system back button
      await t.pump(const Duration(seconds: 1)); // Home keeps a spinner running (weather offline)
      expect(obs.names, isEmpty);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('a double tap on "this week" opens the week page once', (t) async {
      final obs = await home(t);
      final l = AppLocalizations.of(t.element(find.byType(HomePage)));
      final week = find.text(l.trainedThisWeek);
      await t.tap(week);
      await t.tap(week);
      await t.pumpAndSettle();
      expect(obs.names, hasLength(1));
      expect(find.byType(WeekPage), findsOneWidget);
    });
  });

  test('tiles open their pages through openPage, not a bare push', () {
    // Session starts/restores push right after the workout started – they stay plain pushes.
    const plain = {'lib/features/session/start_helpers.dart', 'lib/features/shell/workout_restore.dart'};
    final bare = RegExp(r'Navigator\.push\(\s*context,\s*MaterialPageRoute');
    final offenders = [
      for (final f in Directory('lib/features').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && !plain.contains(f.path.replaceAll(r'\', '/')) && bare.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });
}
