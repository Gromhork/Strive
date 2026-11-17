// Audit UX-16 (follow-up): the calendar's week list goes back to the current week after a new plan and when the
// calendar tab is opened again – it kept a scroll position weeks into the old plan.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/calendar_page.dart';
import 'package:strive/features/shell/home_shell.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_service.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/services/workout_store.dart';

MaterialApp _material(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('de'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  final today = dayOnly(DateTime.now());
  // Three runs a week from 2 weeks back to 20 weeks ahead.
  final plans = [
    for (var w = -2; w <= 20; w++)
      for (final d in const [0, 2, 4])
        PlannedWorkout(
          id: 'p${w}_$d',
          date: addDays(today, 7 * w + d - (today.weekday - 1)),
          sport: Sport.run,
          title: 'Lauf',
          intensity: 'easy',
          durationMin: 40,
        ),
  ];

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('a replaced plan brings the week list back to the current week', (t) async {
    await phone(t);
    final primary = ScrollController();
    addTearDown(primary.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => Stream.value(const UserProfile(level: 'intermediate', focus: TrainingFocus.run))),
          plansProvider.overrideWith((ref) => Stream.value(plans)),
          sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
          templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
        ],
        child: _material(PrimaryScrollController(controller: primary, child: const Scaffold(body: CalendarPage()))),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await t.pumpAndSettle();
    expect(primary.offset, greaterThan(1000));
    PlanService.replaced.value++;
    await t.pumpAndSettle();
    expect(primary.offset, 0, reason: 'the list is anchored at the current week');
  });

  testWidgets('opening the calendar tab again shows the current week', (t) async {
    t.view.physicalSize = const Size(420, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          authProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith(
            (ref) =>
                Stream.value(const UserProfile(name: 'Alex', onboarded: true, weightKg: 75, birthYear: 1990, focus: TrainingFocus.run)),
          ),
          sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
          plansProvider.overrideWith((ref) => Stream.value(plans)),
          templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
          goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
          exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
          weatherProvider.overrideWith((ref) => Completer<Weather>().future),
          workoutStoreProvider.overrideWithValue(MemoryWorkoutStore()),
        ],
        child: _material(const HomeShell()),
      ),
    );
    await t.pump();
    await t.pump();
    final l = lookupAppLocalizations(const Locale('de'));
    Future<void> tab(String label) async {
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
    }

    await tab(l.navCalendar);
    final list = find.descendant(of: find.byType(CalendarPage), matching: find.byType(CustomScrollView));
    await t.drag(list, const Offset(0, -3000));
    await t.pump(const Duration(seconds: 1));
    ScrollPosition pos() => t.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position;
    expect(pos().pixels, greaterThan(1000));
    await tab(l.navHome);
    await tab(l.navCalendar);
    expect(pos().pixels, 0, reason: 'back at the current week');
    expect(t.takeException(), isNull);
  });
}
