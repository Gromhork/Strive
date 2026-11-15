import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/builtin_upgrade.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/train/program_duplicate.dart';
import 'package:strive/features/train/train_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_exercises.dart';

/// Duplicating programs and whole folders in the Train tab.
class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  var _n = 0;
  final saved = <List<WorkoutTemplate>>[];
  final folderOrders = <List<String>>[];
  final deleted = <String>[];
  final profiles = <UserProfile>[];
  @override
  String newId() => 'new${_n++}';
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async => saved.add(list);
  @override
  void saveTemplate(WorkoutTemplate t) => saved.add([t]);
  @override
  void saveFolderOrder(List<String> folders) => folderOrders.add(folders);
  @override
  Future<void> deleteTemplates(Iterable<String> ids) async => deleted.addAll(ids);
  @override
  void deleteTemplate(String id) => deleted.add(id);
  @override
  void saveProfile(UserProfile p) => profiles.add(p);
}

List<WorkoutTemplate> _defaults({bool de = true}) {
  var i = 0;
  return defaultTemplates(() => 'b${i++}', de: de);
}

WorkoutTemplate _t(String id, String folder, int order, {Sport sport = Sport.gym, String? name}) =>
    WorkoutTemplate(id: id, name: name ?? id, sport: sport, folder: folder, order: order);

/// What a copy must share with its source: everything but id, name, place and the built-in keys.
Map<String, dynamic> _content(WorkoutTemplate t) =>
    t.toMap()..removeWhere((k, _) => const {'name', 'folder', 'order', 'key', 'origKey'}.contains(k));

void main() {
  const ppl = 'Push Pull Beine';

  group('copyName', () {
    test('"(Kopie)", then "(Kopie 2)", "(Kopie 3)" – ignoring case and spaces', () {
      expect(copyName('Push', ['Push'], 'Kopie'), 'Push (Kopie)');
      expect(copyName('Push', ['Push', 'push (kopie) '], 'Kopie'), 'Push (Kopie 2)');
      expect(copyName('Push', ['Push', 'Push (Kopie)', 'Push (Kopie 2)'], 'Kopie'), 'Push (Kopie 3)');
      // A freed number is used again.
      expect(copyName('Push', ['Push', 'Push (Kopie 2)'], 'Kopie'), 'Push (Kopie)');
      expect(copyName(' Push ', const [], 'copy'), 'Push (copy)');
    });

    test('a copy of a copy counts on instead of stacking the suffix', () {
      expect(copyName('Push (Kopie)', ['Push', 'Push (Kopie)'], 'Kopie'), 'Push (Kopie 2)');
      expect(copyName('Push (Kopie 2)', ['Push', 'Push (Kopie)', 'Push (Kopie 2)'], 'Kopie'), 'Push (Kopie 3)');
      // Only the app's own marker counts: other brackets stay part of the name.
      expect(copyName('Zuhause (Kurzhanteln)', ['Zuhause (Kurzhanteln)'], 'Kopie'), 'Zuhause (Kurzhanteln) (Kopie)');
      expect(copyName('Lauf (Kopie)', const [], 'copy'), 'Lauf (Kopie) (copy)');
    });
  });

  group('duplicateProgram', () {
    test('the copy sits directly below its source; the folder is renumbered, only changes are written', () {
      final all = [_t('a', 'F', 0), _t('b', 'F', 1), _t('c', 'F', 2), _t('x', 'G', 0)];
      final d = duplicateProgram(all, all[0], 'n', suffix: 'Kopie');
      expect(d.copy.name, 'a (Kopie)');
      expect({for (final t in d.writes) t.id: t.order}, {'n': 1, 'b': 2, 'c': 3});
      expect(d.copy.folder, 'F');
      // The last program: nothing else moves.
      final last = duplicateProgram(all, all[2], 'n', suffix: 'Kopie');
      expect({for (final t in last.writes) t.id: t.order}, {'n': 3});
      // Equal orders (older data, imports with 999): still directly below, the folder gets clean numbers.
      final flat = [_t('a', 'F', 0), _t('b', 'F', 0), _t('c', 'F', 999)];
      final f = duplicateProgram(flat, flat[1], 'n', suffix: 'Kopie');
      expect({for (final t in f.writes) t.id: t.order}, {'b': 1, 'n': 2, 'c': 3});
    });

    test('a built-in program: the copy is the athlete\'s own (no key), the content is the same', () {
      final all = _defaults();
      for (final t in all) {
        final d = duplicateProgram(all, t, 'n', suffix: 'Kopie');
        expect(d.copy.key, isNull, reason: t.name);
        expect(d.copy.origKey, isNull);
        expect(d.copy.toMap().containsKey('key'), isFalse);
        expect(d.copy.name, '${t.name} (Kopie)');
        expect(d.copy.sport, t.sport);
        expect(_content(d.copy), _content(t), reason: t.name);
        // The original keeps its key and content (only its place may change).
        expect(d.writes.where((x) => x.id != 'n').every((x) => x.key == all.firstWhere((o) => o.id == x.id).key), isTrue);
      }
      // A changed version kept by "restore" (origKey) is copied without that link, too.
      final kept = WorkoutTemplate.fromMap('k', {...all.first.toMap(), 'key': null, 'origKey': all.first.key});
      expect(duplicateProgram([...all, kept], kept, 'n', suffix: 'Kopie').copy.origKey, isNull);
    });

    test('exercises, sets, supersets, timed holds and notes are copied – as independent objects', () {
      final ex = [
        GymExercise(exId: '0025', name: 'Bankdrücken', sets: [GymSet(weight: 60, reps: 8), GymSet(weight: 62.5, reps: 6)], restSec: 150)
          ..group = 'A'
          ..note = 'Schulterblätter zusammen'
          ..repMin = 6
          ..repMax = 10,
        GymExercise(exId: '0464', name: 'Plank', sets: [GymSet(weight: 0, reps: 45)])
          ..group = 'A'
          ..timed = true
          ..holdMin = 30
          ..holdMax = 60
          ..bw = true,
      ];
      final t = WorkoutTemplate(id: 'a', name: 'Mein Tag', sport: Sport.gym, folder: 'F', exercises: ex, description: 'Notiz');
      final copy = duplicateProgram([t], t, 'n', suffix: 'Kopie').copy;
      expect(_content(copy), _content(t));
      expect(copy.exercises.map((e) => e.group), ['A', 'A']);
      expect(copy.exercises[0].note, 'Schulterblätter zusammen');
      expect(copy.exercises[0].sets.map((s) => s.weight), [60, 62.5]);
      expect((copy.exercises[1].timed, copy.exercises[1].holdMin, copy.exercises[1].holdMax), (true, 30, 60));
      expect(copy.description, 'Notiz');
      // Editing the copy never changes the original.
      copy.exercises[0].sets[0].weight = 100;
      copy.exercises[1].group = null;
      expect(t.exercises[0].sets[0].weight, 60);
      expect(t.exercises[1].group, 'A');
    });

    test('into another folder: at its end, the name stays unless it is taken there', () {
      final all = _defaults();
      final push = all.firstWhere((t) => t.key == 'ppl_push'), legs = all.firstWhere((t) => t.key == 'ppl_legs');
      final bro = all.where((t) => t.folder == 'Bro-Split').length;
      final d = duplicateProgram(all, push, 'n', suffix: 'Kopie', folder: 'Bro-Split');
      expect((d.copy.name, d.copy.folder, d.copy.order, d.copy.key), ('Push', 'Bro-Split', bro, null));
      expect(d.writes, hasLength(1));
      // The bro split has its own "Beine".
      expect(duplicateProgram(all, legs, 'n', suffix: 'Kopie', folder: 'Bro-Split').copy.name, 'Beine (Kopie)');
      // "No folder" and a new folder.
      expect(duplicateProgram(all, push, 'n', suffix: 'Kopie', folder: '').copy.folder, '');
      final fresh = duplicateProgram(all, push, 'n', suffix: 'Kopie', folder: 'Neu').copy;
      expect((fresh.name, fresh.folder, fresh.order), ('Push', 'Neu', 0));
    });
  });

  group('duplicateFolder', () {
    test('a new folder directly after its source with copies of all programs (all sports) in the same order', () {
      final all = [_t('g2', 'Mix', 2), _t('r1', 'Mix', 0, sport: Sport.run), _t('s1', 'Mix', 1, sport: Sport.swim), _t('x', 'Other', 0)]
        ..sort((a, b) => a.order.compareTo(b.order));
      var n = 0;
      final d = duplicateFolder(all, ['Other', 'Mix', 'Leer'], 'Mix', () => 'n${n++}', suffix: 'Kopie');
      expect(d.folder, 'Mix (Kopie)');
      expect(d.folderOrder, ['Other', 'Mix', 'Mix (Kopie)', 'Leer']);
      expect(d.copies.map((t) => (t.id, t.name, t.sport, t.folder, t.order)), [
        ('n0', 'r1', Sport.run, 'Mix (Kopie)', 0),
        ('n1', 's1', Sport.swim, 'Mix (Kopie)', 1),
        ('n2', 'g2', Sport.gym, 'Mix (Kopie)', 2),
      ]);
    });

    test('unique folder name: "(Kopie 2)" on a clash – also with a folder only known from its programs', () {
      final all = [_t('a', 'Mix', 0), _t('b', 'Mix (Kopie)', 0)];
      final d = duplicateFolder(all, ['Mix'], 'Mix', () => 'n', suffix: 'Kopie');
      expect(d.folder, 'Mix (Kopie 2)');
      expect(d.folderOrder, ['Mix', 'Mix (Kopie 2)']);
      // The copy of the copy counts on and follows its own source.
      final again = duplicateFolder(all, ['Mix', 'Mix (Kopie)'], 'Mix (Kopie)', () => 'n', suffix: 'Kopie');
      expect(again.folder, 'Mix (Kopie 2)');
      expect(again.folderOrder, ['Mix', 'Mix (Kopie)', 'Mix (Kopie 2)']);
      expect(duplicateFolder(all, ['Mix'], 'Mix', () => 'n', suffix: 'copy').folder, 'Mix (copy)');
    });

    test('an empty folder gives an empty folder', () {
      final d = duplicateFolder([_t('a', 'Mix', 0)], ['Mix', 'Leer'], 'Leer', () => 'n', suffix: 'Kopie');
      expect(d.copies, isEmpty);
      expect(d.folderOrder, ['Mix', 'Leer', 'Leer (Kopie)']);
    });

    for (final de in [true, false]) {
      test(
        'every standard folder (${de ? 'de' : 'en'}): the copies are own programs – restore, upgrade and the plan keep the originals',
        () {
          final all = _defaults(de: de);
          final named = all.map((t) => t.folder).toSet().toList();
          for (final folder in named) {
            var n = 0;
            final d = duplicateFolder(all, named, folder, () => 'n${n++}', suffix: de ? 'Kopie' : 'copy');
            final source = all.where((t) => t.folder == folder).toList();
            expect(d.copies, hasLength(source.length), reason: folder);
            expect(d.copies.map((t) => t.name), source.map((t) => t.name));
            expect(d.copies.map(_content), source.map(_content));
            expect(d.copies.every((t) => t.key == null && t.origKey == null), isTrue);
            final after = [...d.copies, ...all];
            // Not a standard folder: nothing to restore there, the copies are no originals.
            expect(builtinFolderKeysOf(d.folder, after), isEmpty, reason: folder);
            expect(d.copies.any(isUntouchedBuiltin), isFalse);
            expect(planBuiltinRestore(after, () => 'r', de: de, ownSuffix: 'eigene').isEmpty, isTrue);
            expect(builtinTargetFolder(after, builtinFolderOf[source.first.key]!, de: de), folder);
            for (final t in d.copies) {
              expect(upgradedBuiltinExercises(t, 'strength'), isNull);
            }
            // Plan settings: `key:` references still stand for the originals, the copies get their own id.
            for (final t in source.where((t) => t.sport == Sport.gym)) {
              expect(gymProgramOf('key:${t.key}', after)?.id, t.id);
              expect(gymProgramRef(d.copies[source.indexOf(t)], among: after), 'id:${d.copies[source.indexOf(t)].id}');
            }
            // Without the originals the copies are not mistaken for them.
            final plan = planBuiltinRestore(
              d.copies,
              () => 'r',
              de: de,
              ownSuffix: 'eigene',
              folderKeys: {builtinFolderOf[source.first.key]!},
            );
            expect(plan.add, hasLength(source.length));
            expect(plan.keep, isEmpty);
          }
        },
      );
    }
  });

  group('Train tab', () {
    Future<_FakeRepo> pump(
      WidgetTester tester,
      List<WorkoutTemplate> templates, {
      List<String> folderOrder = const [],
      String lang = 'de',
    }) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            repoProvider.overrideWithValue(repo),
            profileProvider.overrideWith((ref) => Stream.value(UserProfile(folderOrder: folderOrder))),
            templatesProvider.overrideWith((ref) => Stream.value(templates)),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
            plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          ],
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
            home: const TrainPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> folderMenu(WidgetTester tester, String folder, String entry) async {
      await tester.tap(find.byKey(ValueKey('folderMenu-$folder')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
    }

    Future<void> programMenu(WidgetTester tester, String id, String entry) async {
      await tester.tap(find.byKey(ValueKey('programMenu-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
    }

    /// Folder names top to bottom as shown.
    List<String> shownFolders(WidgetTester tester, Iterable<String> names) {
      final found = [
        for (final n in names)
          if (find.byKey(ValueKey('f-$n')).evaluate().isNotEmpty) n,
      ];
      return found
        ..sort((a, b) => tester.getTopLeft(find.byKey(ValueKey('f-$a'))).dy.compareTo(tester.getTopLeft(find.byKey(ValueKey('f-$b'))).dy));
    }

    final folders = [
      'Bro-Split',
      'Eigengewicht',
      'Ganzkörper',
      'Laufen',
      'Oberkörper / Unterkörper',
      ppl,
      'Radfahren',
      'Schwimmen',
      'Zuhause (Kurzhanteln)',
    ];

    testWidgets('folder menu "Ordner duplizieren": new folder below with all programs, "Rückgängig" removes it again', (tester) async {
      final list = _defaults();
      final repo = await pump(tester, list, folderOrder: folders);
      await folderMenu(tester, ppl, 'Ordner duplizieren');

      // One batch with the three copies – the athlete's own programs.
      final copies = repo.saved.single;
      expect(copies.map((t) => (t.name, t.folder, t.order, t.key)), [
        ('Push', '$ppl (Kopie)', 0, null),
        ('Pull', '$ppl (Kopie)', 1, null),
        ('Beine', '$ppl (Kopie)', 2, null),
      ]);
      expect(copies.map((t) => t.id).toSet().intersection({for (final t in list) t.id}), isEmpty);
      final source = list.where((t) => t.folder == ppl).toList();
      expect(copies.map(_content), source.map(_content));
      // Directly after its source, shown and open right away (before any snapshot).
      final order = [...folders]..insert(folders.indexOf(ppl) + 1, '$ppl (Kopie)');
      expect(repo.folderOrders.single, order);
      expect(shownFolders(tester, order), order);
      for (final n in ['Push', 'Pull', 'Beine']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Ordner „$ppl (Kopie)“ mit 3 Programmen erstellt.'), findsOneWidget);
      // The copy is no standard folder: nothing to restore, even with the copies changed.
      await tester.tap(find.byKey(const ValueKey('folderMenu-$ppl (Kopie)')));
      await tester.pumpAndSettle();
      expect(find.text('Ordner duplizieren'), findsOneWidget);
      expect(find.text('Standardprogramme wiederherstellen'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.deleted.toSet(), {for (final t in copies) t.id});
      expect(repo.folderOrders.last, folders);
      expect(find.text('$ppl (Kopie)'), findsNothing);
      expect(shownFolders(tester, folders), folders);
      expect(find.text('Push'), findsNothing);
      // The originals were never written or deleted.
      expect(repo.saved.expand((l) => l).map((t) => t.id).toSet().intersection({for (final t in list) t.id}), isEmpty);
      expect(repo.profiles, isEmpty);
    });

    testWidgets('duplicating again gives "(Kopie 2)", directly below the source', (tester) async {
      final repo = await pump(tester, _defaults(), folderOrder: folders);
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      final at = folders.indexOf(ppl);
      expect(repo.folderOrders.last.sublist(at, at + 3), [ppl, '$ppl (Kopie 2)', '$ppl (Kopie)']);
      expect(repo.saved.last.every((t) => t.folder == '$ppl (Kopie 2)'), isTrue);
      expect(find.text('$ppl (Kopie)'), findsOneWidget);
      expect(find.text('$ppl (Kopie 2)'), findsOneWidget);
      // The copy of the copy.
      await folderMenu(tester, '$ppl (Kopie)', 'Ordner duplizieren');
      expect(repo.saved.last.map((t) => (t.name, t.folder)).toSet(), {
        for (final n in ['Push', 'Pull', 'Beine']) (n, '$ppl (Kopie 3)'),
      });
      expect(repo.folderOrders.last.sublist(at, at + 4), [ppl, '$ppl (Kopie 2)', '$ppl (Kopie)', '$ppl (Kopie 3)']);
    });

    testWidgets('a folder without a stored order (only known from its programs) is duplicated below itself, too', (tester) async {
      final repo = await pump(tester, _defaults());
      await folderMenu(tester, 'Laufen', 'Ordner duplizieren');
      final order = repo.folderOrders.single;
      expect(order.toSet(), {...folders, 'Laufen (Kopie)'});
      expect(order.indexOf('Laufen (Kopie)'), order.indexOf('Laufen') + 1);
      final runs = _defaults().where((t) => t.folder == 'Laufen').toList();
      expect(repo.saved.single.map((t) => (t.name, t.sport, t.key)), runs.map((t) => (t.name, Sport.run, null)));
      expect(repo.saved.single.map((t) => t.steps.length), runs.map((t) => t.steps.length));
    });

    testWidgets('sport filter on: the whole folder is duplicated and the snack bar says what is hidden', (tester) async {
      final list = [_t('g1', 'Mix', 0), _t('r1', 'Mix', 1, sport: Sport.run), _t('g2', 'Mix', 2), _t('s1', 'Mix', 3, sport: Sport.swim)];
      final repo = await pump(tester, list, folderOrder: ['Mix']);
      ProviderScope.containerOf(tester.element(find.byType(TrainPage))).read(sportFilterProvider.notifier).set(Sport.gym);
      await tester.pumpAndSettle();
      await folderMenu(tester, 'Mix', 'Ordner duplizieren');
      expect(repo.saved.single.map((t) => (t.name, t.sport, t.order)), [
        ('g1', Sport.gym, 0),
        ('r1', Sport.run, 1),
        ('g2', Sport.gym, 2),
        ('s1', Sport.swim, 3),
      ]);
      expect(
        find.text(
          'Ordner „Mix (Kopie)“ mit 4 Programmen erstellt. 2 davon gehören zu anderen Sportarten und sind durch den Sportfilter ausgeblendet.',
        ),
        findsOneWidget,
      );
      expect(find.text('2 Programme'), findsNWidgets(2));
    });

    testWidgets('"no folder" has no folder menu; an empty folder is duplicated as an empty folder (en)', (tester) async {
      final repo = await pump(tester, [_t('a', '', 0)], folderOrder: ['Empty'], lang: 'en');
      expect(find.byKey(const ValueKey('folderMenu-')), findsNothing);
      await folderMenu(tester, 'Empty', 'Duplicate folder');
      expect(repo.saved, isEmpty);
      expect(repo.folderOrders.single, ['Empty', 'Empty (copy)']);
      expect(find.text('Created the empty folder “Empty (copy)”.'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.folderOrders.last, ['Empty']);
      expect(find.text('Empty (copy)'), findsNothing);
    });

    testWidgets('program menu "Duplizieren": "(Kopie)" directly below, own program, undo; again → "(Kopie 2)"', (tester) async {
      final list = _defaults();
      final repo = await pump(tester, list, folderOrder: folders);
      await tester.tap(find.text(ppl));
      await tester.pumpAndSettle();
      final push = list.firstWhere((t) => t.key == 'ppl_push');
      await programMenu(tester, push.id, 'Duplizieren');
      expect({for (final t in repo.saved.single) t.name: t.order}, {'Push (Kopie)': 1, 'Pull': 2, 'Beine': 3});
      final copy = repo.saved.single.firstWhere((t) => t.name == 'Push (Kopie)');
      expect((copy.key, copy.origKey, copy.folder), (null, null, ppl));
      expect(_content(copy), _content(push));
      expect(find.text('„Push (Kopie)“ erstellt.'), findsOneWidget);
      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(y('Push') < y('Push (Kopie)') && y('Push (Kopie)') < y('Pull'), isTrue);

      await programMenu(tester, push.id, 'Duplizieren');
      expect(repo.saved.last.firstWhere((t) => t.id != copy.id && t.key == null).name, 'Push (Kopie 2)');
      expect(y('Push') < y('Push (Kopie 2)') && y('Push (Kopie 2)') < y('Push (Kopie)'), isTrue);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.deleted, hasLength(1));
      expect(find.text('Push (Kopie 2)'), findsNothing);
      expect(find.text('Push (Kopie)'), findsOneWidget);
      expect(repo.folderOrders, isEmpty);
    });

    testWidgets('program menu "In Ordner duplizieren": the copy goes to the end of the chosen folder', (tester) async {
      final list = _defaults();
      final repo = await pump(tester, list, folderOrder: folders);
      await tester.tap(find.text(ppl));
      await tester.pumpAndSettle();
      final push = list.firstWhere((t) => t.key == 'ppl_push');
      await tester.tap(find.byKey(ValueKey('programMenu-${push.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Ordner duplizieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pickFolder-Bro-Split')));
      await tester.pumpAndSettle();
      final copy = repo.saved.single.single;
      expect(
        (copy.name, copy.folder, copy.order, copy.key),
        ('Push', 'Bro-Split', list.where((t) => t.folder == 'Bro-Split').length, null),
      );
      expect(find.text('„Push“ in Bro-Split erstellt.'), findsOneWidget);
      // The target folder opened: the copy and the original both show.
      expect(find.text('Push'), findsNWidgets(2));
      expect(repo.folderOrders, isEmpty);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.deleted, [copy.id]);
      expect(find.text('Push'), findsOneWidget);
    });
  });
}
