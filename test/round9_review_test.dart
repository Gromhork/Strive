// Round 9 review: the "today" card is compact in every state (rest day, filtered out), the top bar and the
// navigation labels fit at 320 dp with text ×1.3, and the early forecast names the sport of a single-sport race.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/features/home/home_page.dart';
import 'package:strive/features/shell/home_shell.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/services/workout_store.dart';

Future<void> _loadFont() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(File('fonts/Poppins-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

Widget _app(Widget home, {required List<Override> overrides, String lang = 'de', double scale = 1.0}) => ProviderScope(
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
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: home,
  ),
);

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(_loadFont);
  final today = dayOnly(DateTime.now());
  PlannedWorkout w(String id, int dayOffset, Sport sport, String title) =>
      PlannedWorkout(id: id, date: addDays(today, dayOffset), sport: sport, title: title, intensity: 'easy', durationMin: 40);

  group('today card: compact in every state', () {
    Future<void> pumpCard(WidgetTester t, List<PlannedWorkout> plans, {Sport? filter, required String lang, required double scale}) async {
      _size(t, 360, 800);
      final c = ProviderContainer(
        overrides: [
          planListProvider.overrideWithValue(plans),
          sessionListProvider.overrideWithValue(const []),
          templateListProvider.overrideWithValue(const []),
          profileOrDefaultProvider.overrideWithValue(const UserProfile()),
        ],
      );
      addTearDown(c.dispose);
      if (filter != null) c.read(sportFilterProvider.notifier).set(filter);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _app(
            const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.topCenter, child: TodayCard()))),
            overrides: const [],
            lang: lang,
            scale: scale,
          ),
        ),
      );
      await t.pump();
    }

    for (final lang in ['de', 'en']) {
      final l = lookupAppLocalizations(Locale(lang));
      for (final scale in [1.0, 1.3]) {
        testWidgets('rest day: one line with the next workout, no explanation ($lang, ×$scale)', (t) async {
          await pumpCard(t, [w('n', 2, Sport.run, 'Lockerer Lauf')], lang: lang, scale: scale);
          expect(find.text(l.restDay), findsOneWidget);
          expect(find.byKey(const ValueKey('todayNext')), findsOneWidget);
          expect(find.text(l.restDaySub), findsNothing);
          expect(find.byKey(const ValueKey('todayTrain')), findsOneWidget);
          expect(t.getSize(find.byKey(const ValueKey('todayCard'))).height, lessThan(scale > 1 ? 130 : 110));
          expect(t.takeException(), isNull); // an overflow fails the test by itself as well
        });

        testWidgets('filtered out: short title and a small "show all", no explanation ($lang, ×$scale)', (t) async {
          await pumpCard(t, [w('r', 0, Sport.run, 'Easy run'), w('n', 3, Sport.gym, 'Push')], filter: Sport.gym, lang: lang, scale: scale);
          expect(find.text(l.todayHiddenByFilter(1)), findsOneWidget);
          expect(find.text(l.todayHiddenByFilterSub), findsNothing);
          expect(t.getSize(find.byKey(const ValueKey('todayCard'))).height, lessThan(scale > 1 ? 130 : 110));
          await t.tap(find.byKey(const ValueKey('todayShowAll')));
          await t.pump();
          expect(find.text('Easy run'), findsOneWidget);
          expect(t.takeException(), isNull); // an overflow fails the test by itself as well
        });
      }
    }
  });

  group('top bar and navigation at 320 dp, text ×1.3', () {
    for (final lang in ['de', 'en']) {
      testWidgets('no overflow, the navigation labels on one line ($lang)', (t) async {
        _size(t, 320, 700);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await t.pumpWidget(
          _app(
            const HomeShell(),
            lang: lang,
            scale: 1.3,
            overrides: [
              prefsProvider.overrideWithValue(prefs),
              authProvider.overrideWith((ref) => Stream.value(null)),
              profileProvider.overrideWith((ref) => Stream.value(const UserProfile(name: 'Alex', onboarded: true))),
              sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
              plansProvider.overrideWith((ref) => Stream.value([w('a', 1, Sport.run, 'Lauf')])),
              templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
              goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
              bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
              exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
              weatherProvider.overrideWith((ref) => Completer<Weather>().future),
              workoutStoreProvider.overrideWithValue(MemoryWorkoutStore()),
            ],
          ),
        );
        await t.pump();
        await t.pump();
        final l = lookupAppLocalizations(Locale(lang));
        // The avatar stays inside the screen.
        expect(t.getRect(find.byKey(const ValueKey('profileAvatar'))).right, lessThanOrEqualTo(320));
        // Every label as high as the one-word "Home" label: none broke into two lines.
        double h(String s) => t.getSize(find.descendant(of: find.byType(NavigationBar), matching: find.text(s)).first).height;
        final one = h(l.navHome);
        for (final s in [l.navTrain, l.navCalendar, l.navStats, l.navCoach]) {
          expect(h(s), one, reason: s);
        }
      });
    }
  });

  group('early forecast names the race sport', () {
    GoalForecast f(String event, int done) => GoalForecast(
      event: event,
      raceDate: addDays(today, 100),
      daysLeft: 100,
      status: ForecastStatus.onTrack,
      confidence: ForecastConfidence.low,
      early: true,
      planStart: today,
      doneSessions: done,
    );

    test('running race: "am besten Laufen"; triathlon: all three sports', () {
      final de = lookupAppLocalizations(const Locale('de'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(forecastEarlyText(de, f('m', 0)), de.fcEarlyEnduranceSport(de.sportRun, 2));
      expect(forecastEarlyText(de, f('m', 0)), contains('Laufen'));
      expect(forecastEarlyText(de, f('m', 0)), isNot(contains('Rad oder')));
      expect(forecastEarlyText(de, f('10k', 1)), de.fcEarlyEnduranceSport(de.sportRun, 1));
      expect(forecastEarlyText(en, f('m', 0)), contains('ideally running'));
      expect(forecastEarlyText(de, f('olympic', 1)), de.fcEarlyEndurance(1));
    });
  });
}
