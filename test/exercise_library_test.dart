import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/exercise_names_de.dart';
import 'package:strive/features/train/exercise_picker.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/exercise_class.dart';

/// Exercise library content (package C): complete German names, cleaned-up English names,
/// hidden entries, umlaut-insensitive search, German filter labels and subtitles.
void main() {
  final raw = jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List;
  final db = ExerciseDb(raw.map((e) => Exercise.fromJson(e)).toList());

  group('German names', () {
    test('every exercise (also the hidden ones) has a curated German name', () {
      for (final e in db.all) {
        expect(exerciseNamesDe[e.id], isNotNull, reason: '${e.id} ${e.name}');
        expect(exerciseName(e.id, e.name, 'de'), exerciseNamesDe[e.id]);
      }
      expect(exerciseNamesDe.keys.toSet(), db.all.map((e) => e.id).toSet(), reason: 'no names of unknown ids');
    });

    test('no duplicates, no leading dash, no lower-case fragment, no empty brackets', () {
      final seen = <String, String>{};
      for (final MapEntry(key: id, value: n) in exerciseNamesDe.entries) {
        final k = n.toLowerCase();
        expect(seen[k], isNull, reason: '"$n" for $id and ${seen[k]}');
        seen[k] = id;
        expect(n, isNot(startsWith('-')), reason: id);
        expect(n, isNot(startsWith('(')), reason: id);
        expect(n[0], n[0].toUpperCase(), reason: '$id $n');
        expect(n, isNot(contains('()')), reason: id);
        expect(n.trim(), n, reason: id);
        expect(n, isNot(contains('  ')), reason: id);
      }
    });

    test('no English leftovers (except established loanwords)', () {
      const english = [
        'grip',
        'straight',
        'back',
        'above',
        'head',
        'against',
        'wall',
        'circles',
        'advanced',
        'standing',
        'seated',
        'lying',
        'incline',
        'decline',
        'reverse',
        'bench',
        'alternate',
        'alternating',
        'with',
        'one',
        'arm',
        'leg',
        'single',
        'raise',
        'row',
        'pulldown',
        'extension',
        'squat',
        'lunge',
        'stretch',
        'bent',
        'over',
        'close',
        'wide',
        'narrow',
        'side',
        'rear',
        'high',
        'low',
        'kneeling',
        'hanging',
        'twisting',
        'dumbbell',
        'barbell',
        'cable',
        'lever',
        'machine',
        'smith',
        'exercise',
        'stability',
        'male',
        'female',
        'squad',
        'run',
        'walk',
        'jump',
        'knee',
        'hip',
        'chest',
        'shoulder',
        'on',
      ];
      // Loanwords German gyms use as they are (whole phrases only).
      const loanwords = [
        'Back Lever',
        'Front-Lever',
        'Bent Press',
        'Glute-Ham Raise',
        'Hip Thrust',
        'Front Lever',
        'Goblet Squat',
        'Split Squat',
        'Sissy Squat',
        'Pistol Squat',
        'Cossack Squat',
        'Potty Squat',
        'Squat Jerk',
        'Curtsy Lunge',
        'Farmer\'s Walk',
        'Monster Walk',
        "World's Greatest Stretch",
        'Reverse Curl',
        'Reverse Flys',
        'Reverse Fly',
        'Reverse Crunch',
        'Reverse Butterfly',
        'Reverse Hyperextension',
        'Reverse Push-up',
        'Renegade Row',
        'High-Bar',
        'Low-Bar',
        'Drop Jump',
        'Box Jump',
        'Arm Blaster',
        "Captain's Chair",
        'Balance Board Stand',
        'Push and Pull',
      ];
      final bad = <String>[];
      for (final MapEntry(key: id, value: n) in exerciseNamesDe.entries) {
        var s = n;
        for (final w in loanwords) {
          s = s.replaceAll(w, '');
        }
        for (final w in english) {
          if (RegExp('\\b$w\\b', caseSensitive: false).hasMatch(s)) bad.add('$id "$n" ($w)');
        }
      }
      expect(bad, isEmpty);
    });

    test('the reported entries read as natural German', () {
      expect(exerciseNamesDe['0754'], 'Negativbankdrücken Untergriff (Multipresse)'); // was "-grip Drücken negativ umgekehrt"
      expect(exerciseNamesDe['1257'], startsWith('Schrägbankdrücken Untergriff (Langhantel')); // was "-grip Drücken schräg …"
      expect(exerciseNamesDe['0208'], 'Rudern hoch Untergriff sitzend (Kabelzug)'); // was "-grip Straight Back Rudern …"
      expect(exerciseNamesDe['0753'], 'Negativbankdrücken (Multipresse)'); // was "Smith-Maschine Negativbankdrücken"
      expect(exerciseNamesDe['0419'], 'Frontheben bis über Kopf stehend (Kurzhantel)'); // was "Above Head Frontheben …"
      expect(exerciseNamesDe['1355'], 'Latissimus-Dehnung einarmig an der Wand'); // was "Against Wall einarmig"
      expect(exerciseNamesDe['1512'], 'Quadrizeps-Dehnung im Vierfüßlerstand'); // was "All Fours Squad Dehnung"
      expect(exerciseNamesDe['1368'], 'Fußkreisen'); // was "Ankle circles"
      expect(exerciseNamesDe['0517'], 'Windmühle fortgeschritten (Kettlebell)'); // was "Advanced Windmill (Kettlebell)"
      // Variants are told apart by grip / angle, the base movement first.
      expect(exerciseNamesDe['0030'], 'Bankdrücken eng (Langhantel)');
      expect(exerciseNamesDe['1258'], 'Bankdrücken breit Untergriff (Langhantel)');
      expect(exerciseNamesDe['0122'], 'Bankdrücken breit (Langhantel)');
    });

    test('rule-based fallback (names without an id) keeps hyphenated grips together', () {
      final n = germanExerciseName('smith decline reverse-grip press');
      expect(n, isNot(contains('-grip')));
      expect(n, isNot(startsWith('-')));
      expect(n, contains('Untergriff'));
      expect(n, endsWith('(Multipresse)'));
      expect(germanExerciseName('barbell close-grip bench press'), 'Bankdrücken eng (Langhantel)');
      // Only equipment understood: the English name rather than "(Langhantel)" / "Langhantel".
      expect(germanExerciseName('barbell'), 'Barbell');
      expect(germanExerciseName('dumbbell standing'), 'Dumbbell standing');
    });
  });

  group('English names', () {
    test('broken database names are repaired, also for stored sessions', () {
      for (final e in db.all) {
        expect(e.name, isNot(startsWith('-')), reason: e.id);
        if (!hiddenExerciseIds.contains(e.id)) {
          expect(e.name, isNot(contains('v. ')), reason: '${e.id} ${e.name}');
          expect(e.name, isNot(contains('(male)')), reason: '${e.id} ${e.name}');
          expect(e.name, isNot(contains('pov')), reason: '${e.id} ${e.name}');
        }
      }
      for (final MapEntry(key: id, value: n) in exerciseNamesEn.entries) {
        expect(db.byId(id)!.name, n, reason: id);
      }
      expect(db.byId('1512')!.name, 'all fours quad stretch');
      // A session stored with the old name shows the repaired one.
      expect(exerciseName('1512', 'all fours squad stretch', 'en'), 'All fours quad stretch');
      expect(exerciseName('0043', 'barbell full squat', 'en'), 'Barbell full squat');
    });
  });

  group('hidden entries', () {
    test('cardio covered by run / ride workouts and duplicates are hidden but resolvable', () {
      for (final id in hiddenExerciseIds) {
        final e = db.byId(id);
        expect(e, isNotNull, reason: id);
        expect(db.visible.contains(e), isFalse, reason: id);
        expect(db.search(e!.name).map((x) => x.id), isNot(contains(id)), reason: id);
        expect(db.search(exerciseNamesDe[id]!, lang: 'de').map((x) => x.id), isNot(contains(id)), reason: id);
        // Stored sessions keep their German name and classification.
        expect(exerciseName(id, e.name, 'de'), exerciseNamesDe[id]);
        expect(() => classifyLift(id, e.name, info: e), returnsNormally);
      }
      for (final id in ['3666', '0798', '2138', '2141', '2311', '2331', '0684', '0685']) {
        expect(hiddenExerciseIds, contains(id));
      }
      expect(db.search('Laufband', lang: 'de'), isEmpty);
      expect(db.search('treadmill'), isEmpty);
      expect(db.visible.length, db.all.length - hiddenExerciseIds.length);
      // No visible endurance machine of the run / ride / swim workouts.
      for (final e in db.visible) {
        expect(const {'stationary bike', 'elliptical machine', 'stepmill machine'}.contains(e.equipment), isFalse, reason: e.id);
      }
    });

    test('nothing the app ships with references a hidden exercise', () {
      final shipped = {...commonExerciseIds, ...popularExerciseIds};
      // Every exercise id literal of the app code (built-in programs, plan generator, …).
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.contains('exercise_names_de') || f.path.contains('exercise_db')) continue;
        shipped.addAll(RegExp(r"'(\d{4})'").allMatches(f.readAsStringSync()).map((m) => m[1]!).where((id) => db.byId(id) != null));
      }
      expect(shipped.length, greaterThan(150));
      expect(shipped.intersection(hiddenExerciseIds), isEmpty);
      for (final id in shipped) {
        expect(db.byId(id), isNotNull, reason: id);
      }
    });
  });

  group('search', () {
    test('German and English, case-, umlaut- and hyphen-insensitive', () {
      for (final q in ['Bankdrücken', 'bankdrucken', 'BANKDRUECKEN', 'bench press']) {
        expect(db.search(q, lang: 'de').first.id, '0025', reason: q);
      }
      expect(db.search('kniebeuge', lang: 'de').first.id, '0043');
      expect(db.search('rumaenisches kreuzheben', lang: 'de').map((e) => e.id).take(2), containsAll(['0085', '1459']));
      expect(db.search('pushup').map((e) => e.id), contains('0662'));
      expect(db.search('push-up').map((e) => e.id), contains('0662'));
      expect(db.search('Liegestutz', lang: 'de').first.id, '0662');
      expect(db.search('negativbank multipresse', lang: 'de').map((e) => e.id), containsAll(['0753', '0754']));
      expect(db.search('reverse grip smith', lang: 'de').map((e) => e.id), contains('0754'));
      // Hyphenated German compounds: the second part is a word prefix too.
      expect(searchRank(db.byId('0045')!, foldSearch('bankdr')), lessThan(5));
    });

    test('foldSearch', () {
      expect(foldSearch('Rückenstrecken – Schulterdrücken'), 'ruckenstrecken – schulterdrucken');
      expect(foldSearch('Rueckenstrecken'), foldSearch('Rückenstrecken'));
      expect(foldSearch('Fußkreisen'), foldSearch('Fusskreisen'));
      expect(foldSearch('Sit-up  Crunch'), 'sit up crunch');
    });
  });

  group('filters and subtitles', () {
    test('German labels for every body part, muscle and equipment of the library', () {
      const sameInGerman = {'cardio', 'kettlebell', 'band', 'trap bar'};
      for (final k in {...db.bodyParts, ...db.equipment, for (final e in db.visible) e.target}) {
        final de = term(k, 'de');
        if (!sameInGerman.contains(k)) expect(de.toLowerCase(), isNot(k), reason: k);
      }
      expect(term('leverage machine', 'de'), 'Maschine');
      expect(term('smith machine', 'de'), 'Multipresse');
      expect(term('weighted', 'de'), 'Zusatzgewicht');
      expect(term('leverage machine', 'en'), 'Machine');
      // Merged / hidden-only equipment is gone from the filter.
      expect(db.equipment, isNot(contains('resistance band')));
      expect(db.equipment, isNot(contains('olympic barbell')));
      expect(db.equipment, isNot(contains('stationary bike')));
      // Menus are sorted by their label.
      final labels = db.equipmentFor('de').map((k) => foldSearch(term(k, 'de'))).toList();
      expect(labels, [...labels]..sort());
    });

    test('subtitle: target muscle · equipment, no English alias', () {
      final e = db.byId('0753')!;
      expect(exerciseSubtitle(e, 'de'), 'Brustmuskel · Multipresse');
      expect(exerciseSubtitle(e, 'en'), 'Chest · Smith machine');
    });

    testWidgets('library list: German name and subtitle, no truncated English alias', (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [exerciseDbProvider.overrideWith((ref) async => db), sessionListProvider.overrideWithValue(const [])],
          child: const MaterialApp(
            locale: Locale('de'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExerciseLibraryPage(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'negativbankdrücken multipresse');
      await t.pumpAndSettle();
      expect(find.text('Negativbankdrücken (Multipresse)'), findsOneWidget);
      expect(find.text('Negativbankdrücken Untergriff (Multipresse)'), findsOneWidget);
      expect(find.text('Brustmuskel · Multipresse'), findsWidgets);
      expect(find.textContaining('Smith'), findsNothing);
      expect(find.textContaining('decline'), findsNothing);
    });
  });
}
