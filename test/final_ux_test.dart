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
import 'package:strive/features/calendar/planned_workout_page.dart';
import 'package:strive/features/profile/profile_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';

final l = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => MaterialApp(
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
);

void main() {
  testWidgets('secure guest account: save stays disabled until e-mail and password are entered', (tester) async {
    await tester.pumpWidget(
      _app(Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => linkGuestWithEmail(c), child: const Text('open'))))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    FilledButton save() => tester.widget<FilledButton>(find.byKey(const ValueKey('linkEmailSave')));
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'a@b.de');
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'password still empty');
    await tester.enterText(find.byType(TextField).last, 'secret1');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
  });

  testWidgets('planned gym workout: a start too short to count keeps the weights and "adjust exercises"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final today = dayOnly(DateTime.now());
    final tpl = WorkoutTemplate(
      id: 't',
      name: 'Upper',
      sport: Sport.gym,
      exercises: [
        GymExercise(
          exId: 'bench',
          name: 'Bench press',
          repMin: 5,
          repMax: 8,
          sets: [GymSet(weight: 60, reps: 5), GymSet(weight: 60, reps: 5)],
        ),
      ],
    );
    final plan = PlannedWorkout(id: 'p', date: today, sport: Sport.gym, title: 'Upper', durationMin: 60, templateId: 't', status: 'done');
    // 1 of 20 planned sets, 2 minutes: linked, but not counted.
    final short = Session(
      id: 's',
      sport: Sport.gym,
      title: 'Upper',
      start: today.add(const Duration(hours: 8)),
      durationSec: 120,
      planId: 'p',
      templateId: 't',
      plannedSets: 20,
      exercises: [
        GymExercise(exId: 'bench', name: 'Bench press', sets: [GymSet(weight: 60, reps: 5, done: true)]),
      ],
    );
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          profileProvider.overrideWith(
            (ref) => Stream.value(const UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996)),
          ),
          sessionsProvider.overrideWith((ref) => Stream.value([short])),
          templatesProvider.overrideWith((ref) => Stream.value([tpl])),
          plansProvider.overrideWith((ref) => Stream.value([plan])),
          bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
          exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
        ],
        child: _app(const PlannedWorkoutPage(planId: 'p')),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(l.adjustExercises), findsOneWidget);
    final subtitle = tester.widget<ListTile>(find.byKey(const ValueKey('plannedExercise-0'))).subtitle!;
    final texts = find.descendant(of: find.byWidget(subtitle), matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data);
    expect(texts.any((t) => t != null && t.contains('≈')), isTrue, reason: 'weight suggestion still shown: $texts');
  });
}
