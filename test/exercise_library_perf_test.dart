import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/exercise_names_de.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/train/exercise_picker.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';

/// Counts the searches the page runs.
class _CountingDb extends ExerciseDb {
  _CountingDb(super.all);
  int searches = 0;

  @override
  List<Exercise> search(String q, {String? bodyPart, String? equipment, String lang = 'en'}) {
    searches++;
    return super.search(q, bodyPart: bodyPart, equipment: equipment, lang: lang);
  }
}

Exercise _ex(String id, String name, {String body = 'chest'}) =>
    Exercise(id: id, name: name, bodyPart: body, equipment: 'barbell', target: 'pectorals', secondary: const [], instructions: const []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = ExerciseDb(parseExercises(File('assets/data/exercises.json').readAsStringSync()));

  test('the bundled library loads (parsed off the UI thread outside tests)', () async {
    final loaded = await ExerciseDb.load();
    expect(loaded.all.length, db.all.length);
    expect(loaded.all.length, greaterThan(1000));
  });

  test('German library order: by the shown name – and quick (it stalled the library for seconds)', () {
    final sw = Stopwatch()..start();
    final list = db.search('', lang: 'de');
    sw.stop();
    expect(list.length, db.visible.length);
    final names = [for (final e in list) exerciseName(e.id, e.name, 'de').toLowerCase()];
    expect(names, [...names]..sort());
    // Was ~1.5 s on a desktop VM (the rule-based German names were recomputed inside the sort).
    expect(sw.elapsedMilliseconds, lessThan(400));
  });

  test('rule-based German names are memoised (same result, computed once)', () {
    const en = 'dumbbell seated alternate shoulder press';
    final a = germanExerciseName(en);
    expect(a, contains('Schulterdrücken'));
    expect(identical(germanExerciseName(en), a), isTrue);
  });

  test('search ranks and filters as before', () {
    final r = db.search('bankdrücken', lang: 'de');
    expect(r, isNotEmpty);
    expect(exerciseName(r.first.id, r.first.name, 'de').toLowerCase(), contains('bankdrücken'));
    final chest = db.search('', bodyPart: 'chest', lang: 'de');
    expect(chest.every((e) => e.bodyPart == 'chest'), isTrue);
    expect(db.bodyParts, contains('chest'));
    expect(identical(db.bodyParts, db.bodyParts), isTrue, reason: 'computed once');
  });

  test('libraryList: exercises done before come first – unless searching', () {
    final small = ExerciseDb([_ex('0001', 'a press'), _ex('0002', 'b press'), _ex('0003', 'c press')]);
    expect(libraryList(small, '', lang: 'en', done: {'0003'}).map((e) => e.id), ['0003', '0001', '0002']);
    expect(libraryList(small, 'press', lang: 'en', done: {'0003'}).first.id, isNot('0003'));
  });

  testWidgets('selecting exercises does not search the library again', (tester) async {
    final small = _CountingDb([for (var i = 1; i <= 30; i++) _ex(i.toString().padLeft(4, '0'), 'exercise $i')]);
    final done = Session(
      id: 's',
      sport: Sport.gym,
      title: 'Gym',
      start: DateTime(2026, 11, 1),
      durationSec: 3600,
      exercises: [
        GymExercise(exId: '0005', name: 'exercise 5', sets: [GymSet(weight: 50, reps: 8, done: true)]),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseDbProvider.overrideWith((ref) async => small),
          sessionsProvider.overrideWith((ref) => Stream.value([done])),
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
          home: const ExerciseLibraryPage(selectMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((first.title as Text).data, 'Exercise 5', reason: 'done before: first');
    final before = small.searches;
    await tester.tap(find.text('Exercise 1'));
    await tester.pump();
    await tester.tap(find.text('Exercise 2'));
    await tester.pump();
    expect(small.searches, before, reason: 'the list is memoised – a selection tap only rebuilds');
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.addN(2)), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(small.searches, before + 1);
    expect(find.text('Exercise 12'), findsOneWidget);
  });
}
