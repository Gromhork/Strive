import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/collation.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/exercise_measure.dart';
import 'package:strive/data/exercise_names_de.dart';
import 'package:strive/features/train/exercise_picker.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/exercise_class.dart';

/// Review round 7, exercise library (F3): duplicates, wrong / inconsistent German names, word
/// based search aliases, the plain plank, German alphabetical order and the scroll position of
/// a new search.
void main() {
  final raw = jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List;
  final db = ExerciseDb(raw.map((e) => Exercise.fromJson(e)).toList());
  String de(String id) => exerciseNamesDe[id]!;
  List<String> ids(String q, {String lang = 'de'}) => db.search(q, lang: lang).map((e) => e.id).toList();

  group('DE-1 duplicates', () {
    test('no visible entry is a bare "Variante N" / "variation N"', () {
      for (final e in db.visible) {
        expect(de(e.id), isNot(contains('Variante')), reason: '${e.id} ${de(e.id)}');
        expect(e.name, isNot(contains('variation')), reason: '${e.id} ${e.name}');
        expect(exerciseName(e.id, e.name, 'en'), isNot(contains('variation')), reason: e.id);
      }
    });

    test('the reported duplicates are hidden (but resolvable) and not shipped as popular', () {
      const dups = {
        '0198': '2330', '0674': '1326', '1257': '0048', '1629': '0113', '1661': '0350', '1289': '1281', //
        '1623': '0321', '0324': '0321', '2292': '0380', '3546': '0388', '0340': '0352', '0164': '0162', //
        '0161': '0162', '0315': '0318', '0416': '0294', '1654': '0382', '0055': '0030',
      };
      for (final MapEntry(key: dup, value: kept) in dups.entries) {
        expect(hiddenExerciseIds, contains(dup), reason: dup);
        expect(hiddenExerciseIds, isNot(contains(kept)), reason: kept);
        expect(db.byId(dup), isNotNull, reason: dup);
        expect(popularExerciseIds, isNot(contains(dup)), reason: dup);
      }
      // "Latziehen" / "Klimmzug im Untergriff" show each exercise once.
      final lat = db.search('Latziehen', lang: 'de').map((e) => de(e.id)).toList();
      expect(lat.where((n) => n.startsWith('Latziehen (Kabelzug')), ['Latziehen (Kabelzug)']);
      final chin = db.search('Klimmzug im Untergriff', lang: 'de').map((e) => de(e.id)).toList();
      expect(chin.where((n) => n == 'Klimmzug im Untergriff' || n.startsWith('Klimmzug im Untergriff (')), [
        'Klimmzug im Untergriff (Chin-up)',
      ]);
    });

    test('variants with their own machine / focus are named by what differs', () {
      expect(de('0869'), 'Schulterdrücken nach schräg oben (Maschine)');
      expect(de('2318'), 'Schulterdrücken konvergierend (Maschine)');
      expect(db.byId('0869')!.name, 'lever incline shoulder press');
      expect(db.byId('2318')!.name, 'lever converging shoulder press');
      expect(de('2736'), 'Latziehen im Untergriff mit Hebelarmen (Maschine)');
      expect(de('0140'), 'Klimmzug im Untergriff, Bizeps-Fokus');
      expect(de('0318'), 'Bizepscurl auf der Schrägbank (Kurzhantel)');
      // 0139 is an underhand inverted row in its animation, not a pull-up.
      expect(de('0139'), 'Rudern am Körpergewicht eng im Untergriff');
      expect(db.byId('0139')!.name, 'inverted row (narrow underhand grip)');
      // Stored sessions with the old database name show the repaired one.
      expect(exerciseName('0869', 'lever shoulder press (variation 2)', 'en'), 'Lever incline shoulder press');
    });
  });

  group('DE-2 wrong German names', () {
    test('movement, support and direction match the exercise', () {
      const expected = {
        '3239': 'Schultertippen im Stütz kniend',
        '3663': 'Umgekehrter Stütz mit Beinheben',
        '0230': 'Holzhacker von unten nach oben (Kabelzug)',
        '0862': 'Rumpfdrehung stehend (Kabelzug)',
        '0229': 'Bizepscurl stehend (Kabelzug)',
        '0322': 'Bizepscurl auf der Schrägbank, Fokus innerer Kopf (Kurzhantel)',
        '0393': 'Bizepscurl sitzend, Fokus innerer Kopf (Kurzhantel)',
        '2321': 'Bizepscurl stehend, Fokus innerer Kopf (Kurzhantel)',
        '0977': 'Front-Seitheben (Band)',
        '1468': 'Zehentippen diagonal im Krebsstand',
        '1349': 'T-Bar-Rudern mit Brustauflage (Maschine)',
        '0445': 'Schulterdrücken bauchliegend auf der Schrägbank (SZ-Stange)',
        '0010': 'Knieheben hängend mit Wegstoßen durch Partner',
        '0012': 'Beinheben liegend mit seitlichem Wegstoßen durch Partner',
        '0013': 'Beinheben liegend mit Wegstoßen durch Partner',
        '0258': 'Uhr-Liegestütz im Kreis',
        '0786': 'Squat Jerk / Stoßen mit Hocke (Langhantel)',
      };
      for (final MapEntry(key: id, value: n) in expected.entries) {
        expect(de(id), n, reason: id);
      }
      for (final n in exerciseNamesDe.values) {
        for (final bad in ['Partnerwurf', 'Uhrzeigerkreis', 'Ausstoßen', 'Krebsgang mit', 'Bizepscurl nach außen', 'eng am Boden']) {
          expect(n, isNot(contains(bad)), reason: n);
        }
      }
      // The woodchop can be found.
      expect(ids('Holzhacker').first, '0230');
      expect(ids('woodchop', lang: 'en'), contains('0230'));
    });
  });

  group('DE-3 search aliases match whole words', () {
    test('"Bizeps" finds biceps exercises only, not leg / wrist curls or curl-ups', () {
      final hits = db.search('bizeps', lang: 'de');
      expect(hits.map((e) => e.id), containsAll(['0294', '0031', '0313']));
      for (final e in hits) {
        expect(const {'hamstrings', 'abs', 'spine', 'forearms', 'glutes'}, isNot(contains(e.target)), reason: '${e.id} ${e.name}');
      }
      for (final id in ['0586', '0599', '0697', '0126', '3016', '1352']) {
        expect(hits.map((e) => e.id), isNot(contains(id)), reason: id);
      }
    });

    test('"Rudern" finds rows, not "throw" / "narrow"', () {
      final hits = ids('rudern');
      expect(hits, containsAll(['0027', '0499', '0139']));
      for (final id in ['0010', '0012', '0013', '0063', '2328', '0253', '1353', '1750']) {
        expect(hits, isNot(contains(id)), reason: '$id ${db.byId(id)?.name}');
      }
    });

    test('leg and wrist curls carry their own German keyword', () {
      expect(ids('beinbeuger'), containsAll(['0586', '0599', '0697']));
      expect(ids('handgelenk'), containsAll(['0126', '0082']));
      expect(germanAlias(db.byId('0586')!), isNot(contains('bizeps')));
      expect(germanAlias(db.byId('3167')!), isNot(contains('kniebeuge'))); // "squatting row"
      expect(germanAlias(db.byId('1494')!), isNot(contains('fliegende'))); // "butterfly yoga pose"
    });
  });

  group('DE-4 / R7-9 cardio machines, plank', () {
    test('ski and arm ergometer are hidden like the cross trainer, also from the equipment filter', () {
      expect(hiddenExerciseIds, containsAll(['2142', '2139']));
      expect(db.equipment, isNot(contains('skierg machine')));
      expect(db.equipment, isNot(contains('upper body ergometer')));
    });

    test('a plain bodyweight plank exists, is a timed hold and ranks first', () {
      final p = db.byId('9001')!;
      expect(db.visible, contains(p));
      expect(p.equipment, 'body weight');
      expect(de('9001'), 'Unterarmstütz / Plank');
      expect(isTimedExercise('9001', p.name), isTrue);
      expect(classifyLift('9001', p.name, info: p).cls, LiftClass.core);
      expect(popularExerciseIds, contains('9001'));
      expect(ids('plank', lang: 'en').first, '9001');
      expect(ids('Plank').first, '9001');
      expect(ids('Unterarmstütz').first, '9001');
      // The side plank is found as "plank" / "side plank" too.
      expect(ids('plank'), contains('0705'));
      expect(ids('side plank').first, '0705');
      expect(ids('side bridge', lang: 'en'), contains('0705'));
      expect(exerciseName('0705', 'side bridge v. 2', 'en'), 'Side plank');
    });

    test('the self-assisted Nordic curl is visible under its own name', () {
      expect(hiddenExerciseIds, isNot(contains('1766')));
      expect(de('1766'), 'Nordic Curl mit Handunterstützung');
    });

    test('alternative names separated by " / " each count as the exact name', () {
      expect(searchRank(db.byId('3013')!, foldSearch('Hüftheben')), 0);
      expect(searchRank(db.byId('0060')!, foldSearch('skull crusher')), 0);
      expect(searchRank(db.byId('9001')!, foldSearch('plank')), 0);
    });
  });

  group('DE-5 one term per movement', () {
    test('no mixed terms among the visible names', () {
      for (final e in db.visible) {
        final n = de(e.id);
        expect(n, isNot(contains('Trizepsdrücken über Kopf')), reason: '${e.id} $n');
        expect(n, isNot(startsWith('Hohes Rudern')), reason: '${e.id} $n');
        expect(n, isNot(contains('Zehenheben')), reason: '${e.id} $n');
        if (n.contains('Hammergriff')) expect(n, startsWith('Wadenheben'), reason: '${e.id} $n');
        // Straight-leg = "durchgestreckt", stiff-leg = "gestreckt" for every equipment.
        if (n.startsWith('Kreuzheben mit gestreckten Beinen')) expect(e.name, contains('stiff'), reason: e.id);
        if (n.startsWith('Kreuzheben mit durchgestreckten Beinen')) expect(e.name, contains('straight leg'), reason: e.id);
      }
      expect(ids('Trizepsstrecken über Kopf'), contains('0194'));
      expect(de('0061'), 'French Press liegend (Langhantel)');
      expect(de('0763'), 'Tibialis-Heben (Multipresse)');
      expect(de('1000'), 'Tibialis-Heben einbeinig (Band)');
      expect(de('1396'), 'Wadenheben sitzend (Multipresse)');
    });
  });

  group('DE-6 naming convention', () {
    test('bodyweight names carry no muscle notes in brackets', () {
      final note = RegExp(r'\((Brust|Trizeps|Bizeps|Bauch|Yoga)\b');
      for (final e in db.visible.where((e) => e.equipment == 'body weight')) {
        expect(de(e.id), isNot(matches(note)), reason: '${e.id} ${de(e.id)}');
      }
      expect(de('0251'), 'Brust-Dips');
      expect(de('0814'), 'Trizeps-Dips');
      expect(de('0020'), 'Stand auf dem Balance Board');
      expect(de('3201'), 'Viertel-Sit-up');
      expect(de('3202'), 'Halber Sit-up');
      expect(de('3235'), 'Nordic Curl mit Unterstützung (Kabelzug)');
      expect(de('2202'), 'Hüftdehnung (Faszienrolle)');
    });

    test('the "assisted" equipment is labelled as the partner it is', () {
      expect(term('assisted', 'de'), 'Partner');
      expect(exerciseSubtitle(db.byId('1708')!, 'de'), endsWith('· Partner'));
    });
  });

  group('R7-8 German alphabetical order', () {
    test('umlauts sort as their base vowel', () {
      final names = ['Zug', 'Überzüge', 'Uhr', 'Abduktion', 'Äpfel', 'Öl', 'Ober'];
      expect([...names]..sort(compareNames), ['Abduktion', 'Äpfel', 'Ober', 'Öl', 'Überzüge', 'Uhr', 'Zug']);
      expect(collationKey('Fußkreisen'), 'fusskreisen');
    });

    test('the library lists "Überzüge" under U, not after Z', () {
      final list = db.search('', lang: 'de').map((e) => de(e.id)).toList();
      final keys = list.map(collationKey).toList();
      expect(keys, [...keys]..sort());
      final firstU = list.indexWhere((n) => n.startsWith('Ü'));
      expect(firstU, greaterThan(0));
      expect(list.indexWhere((n) => n.startsWith('V')), greaterThan(firstU));
      expect(list.last, isNot(startsWith('Ü')));
    });
  });

  testWidgets('R7-4 a new search or filter starts at the top of the list', (t) async {
    await t.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
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
    final list = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.vertical);
    ScrollController controller() => t.widget<ListView>(list).controller!;
    await t.drag(list, const Offset(0, -3000));
    await t.pumpAndSettle();
    expect(controller().offset, greaterThan(1000));
    await t.enterText(find.byType(TextField), 'latziehen');
    await t.pumpAndSettle();
    expect(controller().offset, 0);
    final first = db.search('latziehen', lang: 'de').first;
    expect(find.text(exerciseName(first.id, first.name, 'de')), findsOneWidget);
    // The same after scrolling the hits and changing the query again.
    await t.drag(list, const Offset(0, -600));
    await t.pumpAndSettle();
    expect(controller().offset, greaterThan(0));
    await t.enterText(find.byType(TextField), 'kniebeuge');
    await t.pumpAndSettle();
    expect(controller().offset, 0);
    expect(find.text('Kniebeuge (Langhantel)'), findsOneWidget);
  });
}
