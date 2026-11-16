import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:strive/features/calendar/plan_editor.dart';
import 'package:strive/features/train/program_duplicate.dart';
import 'package:strive/features/train/train_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_generator.dart';

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

/// A repository that answers like Firestore: every write changes the library / folder order and
/// is emitted as a new snapshot ([live], [liveProfile]).
class _LiveRepo extends _FakeRepo {
  _LiveRepo(Iterable<WorkoutTemplate> list, this.order) : list = [...list];
  List<WorkoutTemplate> list;
  List<String> order;
  final _lists = StreamController<List<WorkoutTemplate>>.broadcast();
  final _profiles = StreamController<UserProfile?>.broadcast();

  List<WorkoutTemplate> get _sorted => [...list]..sort((a, b) {
    final o = a.order.compareTo(b.order);
    return o != 0 ? o : a.name.compareTo(b.name);
  });

  Stream<List<WorkoutTemplate>> live() => Stream.multi((c) {
    c.add(_sorted);
    final sub = _lists.stream.listen(c.add);
    c.onCancel = sub.cancel;
  });

  Stream<UserProfile?> liveProfile() => Stream.multi((c) {
    c.add(UserProfile(folderOrder: order));
    final sub = _profiles.stream.listen(c.add);
    c.onCancel = sub.cancel;
  });

  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async {
    await super.saveTemplates(list);
    final ids = {for (final t in list) t.id};
    this.list = [...this.list.where((t) => !ids.contains(t.id)), ...list];
    _lists.add(_sorted);
  }

  @override
  void saveTemplate(WorkoutTemplate t) => saveTemplates([t]);

  @override
  Future<void> deleteTemplates(Iterable<String> ids) async {
    await super.deleteTemplates(ids);
    list = [...list.where((t) => !ids.contains(t.id))];
    _lists.add(_sorted);
  }

  @override
  void saveFolderOrder(List<String> folders) {
    super.saveFolderOrder(folders);
    order = folders;
    _profiles.add(UserProfile(folderOrder: folders));
  }
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
      // A freed number is used again for a copy of the original.
      expect(copyName('Push', ['Push', 'Push (Kopie 2)'], 'Kopie'), 'Push (Kopie)');
      expect(copyName(' Push ', const [], 'copy'), 'Push (copy)');
    });

    test('a copy of a copy counts on instead of stacking the suffix', () {
      expect(copyName('Push (Kopie)', ['Push', 'Push (Kopie)'], 'Kopie'), 'Push (Kopie 2)');
      expect(copyName('Push (Kopie 2)', ['Push', 'Push (Kopie)', 'Push (Kopie 2)'], 'Kopie'), 'Push (Kopie 3)');
      // Only the app's own marker counts: other brackets stay part of the name.
      expect(copyName('Zuhause (Kurzhanteln)', ['Zuhause (Kurzhanteln)'], 'Kopie'), 'Zuhause (Kurzhanteln) (Kopie)');
    });

    test('a copy of a numbered copy counts on from its own number – never back to a freed lower one', () {
      // "Push (Kopie)" was deleted: the copy of "Push (Kopie 2)" is not "Push (Kopie)" (the list would read 2, 1).
      expect(copyName('Push (Kopie 2)', ['Push', 'Push (Kopie 2)'], 'Kopie'), 'Push (Kopie 3)');
      expect(copyName('Push (Kopie 2)', ['Push', 'Push (Kopie 2)', 'Push (Kopie 3)'], 'Kopie'), 'Push (Kopie 4)');
      expect(copyName('Push (Kopie)', ['Push (Kopie)'], 'Kopie'), 'Push (Kopie 2)');
      expect(copyName('Push (Kopie 9)', ['Push (Kopie 9)'], 'Kopie'), 'Push (Kopie 10)');
      expect(copyName('push (KOPIE 2)', const [], 'Kopie'), 'push (Kopie 3)');
    });

    test('the marker of the other app language is recognised; the current one is written', () {
      expect(copyMarkers, containsAll([lookupAppLocalizations(const Locale('de')).copy, lookupAppLocalizations(const Locale('en')).copy]));
      expect(copyName('Lauf (Kopie)', ['Lauf', 'Lauf (Kopie)'], 'copy'), 'Lauf (copy 2)');
      expect(copyName('Run (copy 2)', ['Run (copy 2)'], 'Kopie'), 'Run (Kopie 3)');
      expect(copyName('Run (copy)', ['Run (copy)', 'Run (Kopie 2)'], 'Kopie'), 'Run (Kopie 3)');
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

  group('foldersOfUndoneDuplicate', () {
    final copies = [_t('n0', 'Mix (Kopie)', 0), _t('n1', 'Mix (Kopie)', 1)];
    final ids = {'n0', 'n1'};
    test('the new folder goes with its copies; no folder was created: none goes', () {
      final all = [_t('a', 'Mix', 0), ...copies];
      expect(foldersOfUndoneDuplicate(all, ['Mix', 'Mix (Kopie)'], ids, 'Mix (Kopie)'), {'Mix (Kopie)'});
      expect(foldersOfUndoneDuplicate(all, ['Mix', 'Mix (Kopie)'], ids, null), isEmpty);
      // An empty duplicate.
      expect(foldersOfUndoneDuplicate([_t('a', 'Mix', 0)], ['Mix', 'Leer', 'Leer (Kopie)'], const {}, 'Leer (Kopie)'), {'Leer (Kopie)'});
    });

    test('renamed meanwhile: found through its copies', () {
      final all = [_t('a', 'Mix', 0), for (final t in copies) t.copyWith(folder: 'Mein Mix')];
      expect(foldersOfUndoneDuplicate(all, ['Mix', 'Mein Mix'], ids, 'Mix (Kopie)'), {'Mein Mix'});
    });

    test('a folder that holds other programs by now stays', () {
      final all = [_t('a', 'Mix', 0), ...copies, _t('own', 'Mix (Kopie)', 2)];
      expect(foldersOfUndoneDuplicate(all, ['Mix', 'Mix (Kopie)'], ids, 'Mix (Kopie)'), isEmpty);
      // A copy moved into another folder never takes that folder with it …
      final moved = [_t('a', 'Mix', 0), copies[0], copies[1].copyWith(folder: 'Mix')];
      expect(foldersOfUndoneDuplicate(moved, ['Mix', 'Mix (Kopie)'], ids, 'Mix (Kopie)'), {'Mix (Kopie)'});
      // … nor "no folder".
      final loose = [for (final t in copies) t.copyWith(folder: '')];
      expect(foldersOfUndoneDuplicate(loose, const [], ids, 'Mix (Kopie)'), isEmpty);
    });
  });

  group('programLabels', () {
    test('same-named programs show their folder, the others just their name', () {
      final list = [
        _t('a', 'PPL', 0, name: 'Push'),
        _t('b', 'PPL (Kopie)', 0, name: 'push '),
        _t('c', '', 1, name: 'Push'),
        _t('d', 'PPL', 2, name: 'Pull'),
      ];
      expect(programLabels(list, 'Ohne Ordner'), {'a': 'Push · PPL', 'b': 'push  · PPL (Kopie)', 'c': 'Push · Ohne Ordner', 'd': 'Pull'});
      expect(programLabels(const [], 'x'), isEmpty);
    });
  });

  group('plan generator, accounts from before the built-in keys', () {
    test('a duplicated folder never takes the plan away from the original programs – whatever the document order', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final builtin = _defaults(de: false);
      // Stored without a key (found by their old names "Push" / "Pull" / "Legs").
      final legacy = [
        for (final (i, k) in ['ppl_push', 'ppl_pull', 'ppl_legs'].indexed)
          WorkoutTemplate.fromMap('o$i', {...builtin.firstWhere((t) => t.key == k).toMap(), 'key': null}),
      ];
      expect(legacy.map((t) => t.name), ['Push', 'Pull', 'Legs']);
      var n = 0;
      // The copies' ids sort before the originals'.
      final copies = duplicateFolder(legacy, [legacy.first.folder], legacy.first.folder, () => 'a${n++}', suffix: 'copy').copies;
      expect(copies.map((t) => (t.name, t.order)), legacy.map((t) => (t.name, t.order)));
      const profile = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.gym,
        weightKg: 80,
        gender: 'm',
        trainingDays: [1, 3, 5],
        goals: ['strength'],
        athlete: AthleteData(gymSplit: 'ppl'),
      );
      for (final templates in [
        [...copies, ...legacy],
        [...legacy, ...copies],
        [copies[0], legacy[0], legacy[1], copies[1], copies[2], legacy[2]],
      ]) {
        var p = 0;
        final plan = PlanGenerator(en, profile, templates, () => 'p${p++}').generate(start: DateTime(2026, 11, 9), weeks: 3);
        final used = {
          for (final w in plan)
            if (w.sport == Sport.gym) w.templateId,
        };
        expect(used, {'o0', 'o1', 'o2'});
      }
    });
  });

  Future<_FakeRepo> pump(
    WidgetTester tester,
    List<WorkoutTemplate> templates, {
    List<String> folderOrder = const [],
    String lang = 'de',
    Size size = const Size(900, 2600),
    double textScale = 1,
    _FakeRepo? fake,
    Widget home = const TrainPage(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The system font size – as on a phone, it also reaches the snack bar's messenger.
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = fake ?? _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          repoProvider.overrideWithValue(repo),
          profileProvider.overrideWith(
            (ref) => repo is _LiveRepo ? repo.liveProfile() : Stream.value(UserProfile(folderOrder: folderOrder)),
          ),
          templatesProvider.overrideWith((ref) => repo is _LiveRepo ? repo.live() : Stream.value(templates)),
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> folderMenu(WidgetTester tester, String folder, String entry) async {
    await tester.ensureVisible(find.byKey(ValueKey('folderMenu-$folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('folderMenu-$folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  Future<void> programMenu(WidgetTester tester, String id, String entry) async {
    await tester.ensureVisible(find.byKey(ValueKey('programMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('programMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  /// Renames [folder] through its menu.
  Future<void> rename(WidgetTester tester, String folder, String name) async {
    await folderMenu(tester, folder, 'Umbenennen');
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Speichern'));
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

  group('Train tab', () {
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
      expect(find.text('Ordner dupliziert (3 Programme).'), findsOneWidget);
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
      expect(find.text('Ordner dupliziert (4 Programme). 2 davon blendet der Sportfilter aus.'), findsOneWidget);
      expect(find.text('2 Programme'), findsNWidgets(2));
    });

    testWidgets('"no folder" has no folder menu; an empty folder is duplicated as an empty folder (en)', (tester) async {
      final repo = await pump(tester, [_t('a', '', 0)], folderOrder: ['Empty'], lang: 'en');
      expect(find.byKey(const ValueKey('folderMenu-')), findsNothing);
      await folderMenu(tester, 'Empty', 'Duplicate folder');
      expect(repo.saved, isEmpty);
      expect(repo.folderOrders.single, ['Empty', 'Empty (copy)']);
      expect(find.text('Empty folder duplicated.'), findsOneWidget);
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

    testWidgets('duplicate → rename the copy → "Rückgängig": no empty folder is left', (tester) async {
      final list = _defaults();
      final repo = _LiveRepo(list, folders);
      await pump(tester, list, fake: repo);
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      await rename(tester, '$ppl (Kopie)', 'Mein PPL');
      expect(find.text('Mein PPL'), findsOneWidget);
      expect(repo.list.where((t) => t.folder == 'Mein PPL'), hasLength(3));
      expect(repo.order, contains('Mein PPL'));
      // The bar is still there: the copy as a whole can be taken back.
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.order, folders);
      expect(repo.list.map((t) => t.id).toSet(), {for (final t in list) t.id});
      expect(find.text('Mein PPL'), findsNothing);
      expect(find.text('$ppl (Kopie)'), findsNothing);
      expect(shownFolders(tester, [...folders, 'Mein PPL', '$ppl (Kopie)']), folders);
    });

    testWidgets('renamed before the snapshot of the rename arrives (optimistic state): "Rückgängig" still removes the folder', (
      tester,
    ) async {
      final list = _defaults();
      // No snapshots: the page only has its optimistic copies.
      final repo = await pump(tester, list, folderOrder: folders);
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      await rename(tester, '$ppl (Kopie)', 'Mein PPL');
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.folderOrders.last, folders);
      expect(repo.deleted, hasLength(3));
    });

    testWidgets('an empty duplicated folder that is renamed or deleted: the bar closes (nothing left to take back)', (tester) async {
      final repo = _LiveRepo([_t('a', 'Mix', 0)], ['Mix', 'Leer']);
      await pump(tester, const [], fake: repo);
      await folderMenu(tester, 'Leer', 'Ordner duplizieren');
      expect(find.text('Rückgängig'), findsOneWidget);
      await rename(tester, 'Leer (Kopie)', 'Neu');
      expect(find.text('Rückgängig'), findsNothing);
      expect(repo.order, ['Mix', 'Leer', 'Neu']);

      await folderMenu(tester, 'Leer', 'Ordner duplizieren');
      expect(find.text('Rückgängig'), findsOneWidget);
      await folderMenu(tester, 'Leer (Kopie)', 'Löschen');
      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Rückgängig'), findsNothing);
      expect(repo.order, ['Mix', 'Leer', 'Neu']);
    });

    testWidgets('opening or editing a copy closes the bar – "Rückgängig" never deletes what is in use', (tester) async {
      final list = _defaults();
      final repo = _LiveRepo(list, folders);
      await pump(tester, list, fake: repo);
      await tester.tap(find.text(ppl));
      await tester.pumpAndSettle();
      final push = list.firstWhere((t) => t.key == 'ppl_push');
      await programMenu(tester, push.id, 'Duplizieren');
      expect(find.text('Rückgängig'), findsOneWidget);
      // Editing the original leaves the bar alone.
      await programMenu(tester, push.id, 'Bearbeiten');
      expect(find.text('Rückgängig'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      final copy = repo.list.firstWhere((t) => t.name == 'Push (Kopie)');
      await programMenu(tester, copy.id, 'Bearbeiten');
      expect(find.text('Rückgängig'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      expect(find.text('Push (Kopie)'), findsOneWidget);

      // A duplicated folder: opening one of its programs.
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      expect(find.text('Rückgängig'), findsOneWidget);
      final inCopy = repo.list.firstWhere((t) => t.folder == '$ppl (Kopie)' && t.name == 'Pull');
      await tester.ensureVisible(find.byKey(ValueKey('programMenu-${inCopy.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pull').last);
      await tester.pumpAndSettle();
      expect(find.text('Rückgängig'), findsNothing);
      expect(repo.deleted, isEmpty);
    });

    testWidgets('snapshots (live repository): duplicate folder → snapshot → undo gives the library and order back', (tester) async {
      final list = _defaults();
      final repo = _LiveRepo(list, folders);
      await pump(tester, list, fake: repo);
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      final order = [...folders]..insert(folders.indexOf(ppl) + 1, '$ppl (Kopie)');
      expect(repo.order, order);
      expect(repo.list, hasLength(list.length + 3));
      // The snapshot replaced the optimistic state: still one folder with three programs, open.
      expect(shownFolders(tester, order), order);
      for (final n in ['Push', 'Pull', 'Beine']) {
        expect(find.text(n), findsOneWidget);
      }
      // A second duplicate replaces the first bar; its undo only takes the second copy back.
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      expect(find.text('Rückgängig'), findsOneWidget);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.order, order);
      expect(repo.list, hasLength(list.length + 3));
      expect(shownFolders(tester, [...order, '$ppl (Kopie 2)']), order);
      expect(repo.list.where((t) => t.key != null).map((t) => t.id).toSet(), {for (final t in list) t.id});
    });

    testWidgets('snapshots (live repository): duplicate program → snapshot → undo', (tester) async {
      final list = _defaults();
      final repo = _LiveRepo(list, folders);
      await pump(tester, list, fake: repo);
      await tester.tap(find.text(ppl));
      await tester.pumpAndSettle();
      final push = list.firstWhere((t) => t.key == 'ppl_push');
      await programMenu(tester, push.id, 'Duplizieren');
      expect(
        {for (final t in repo.list.where((t) => t.folder == ppl)) t.name: t.order},
        {'Push': 0, 'Push (Kopie)': 1, 'Pull': 2, 'Beine': 3},
      );
      expect(find.text('Push (Kopie)'), findsOneWidget);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(find.text('Push (Kopie)'), findsNothing);
      expect(repo.list.map((t) => t.id).toSet(), {for (final t in list) t.id});
      expect(repo.order, folders);
      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(y('Push') < y('Pull') && y('Pull') < y('Beine'), isTrue);
    });

    testWidgets('"Rückgängig" after the Train tab is gone works on the folder order of that moment', (tester) async {
      final list = _defaults();
      final repo = _LiveRepo(list, folders);
      final train = ValueNotifier(true);
      addTearDown(train.dispose);
      await pump(
        tester,
        list,
        fake: repo,
        home: ValueListenableBuilder(
          valueListenable: train,
          builder: (_, on, _) => on ? const TrainPage() : const Scaffold(body: Center(child: Text('Kalender'))),
        ),
      );
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      train.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(TrainPage), findsNothing);
      // The folders were reordered meanwhile (another device): undo must not write the old order back.
      final reordered = [...repo.order.reversed];
      repo.saveFolderOrder(reordered);
      await tester.pump();
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.order, reordered.where((f) => f != '$ppl (Kopie)'));
      expect(repo.list.map((t) => t.id).toSet(), {for (final t in list) t.id});
      // Renamed meanwhile, page gone: found through the copies.
      train.value = true;
      await tester.pumpAndSettle();
      await folderMenu(tester, ppl, 'Ordner duplizieren');
      train.value = false;
      await tester.pumpAndSettle();
      await repo.saveTemplates([for (final t in repo.list.where((t) => t.folder == '$ppl (Kopie)')) t.copyWith(folder: 'Mein PPL')]);
      repo.saveFolderOrder([for (final f in repo.order) f == '$ppl (Kopie)' ? 'Mein PPL' : f]);
      await tester.pump();
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.order, reordered.where((f) => f != '$ppl (Kopie)'));
      expect(repo.list.map((t) => t.id).toSet(), {for (final t in list) t.id});
    });
  });

  group('plan editor', () {
    testWidgets('the program dropdown tells same-named programs apart by their folder', (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final list = _defaults();
      var n = 0;
      final copies = duplicateFolder(list, [ppl], ppl, () => 'c${n++}', suffix: 'Kopie').copies;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            repoProvider.overrideWithValue(_FakeRepo()),
            profileProvider.overrideWith((ref) => Stream.value(const UserProfile())),
            templatesProvider.overrideWith((ref) => Stream.value([...list, ...copies])),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
            plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
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
            home: Consumer(
              builder:
                  (context, ref, _) =>
                      Scaffold(body: Center(child: FilledButton(onPressed: () => showPlanEditor(context, ref), child: const Text('open')))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      for (final name in ['Push', 'Pull']) {
        expect(find.text(name), findsNothing);
        expect(find.text('$name · $ppl'), findsWidgets);
        expect(find.text('$name · $ppl (Kopie)'), findsWidgets);
      }
      // "Beine" also belongs to the bro split.
      expect(find.text('Beine · $ppl'), findsWidgets);
      expect(find.text('Beine · Bro-Split'), findsWidgets);
      // A name of its own stays as it is.
      final single = list.firstWhere(
        (t) => t.sport == Sport.gym && list.where((x) => x.sport == Sport.gym && x.name == t.name).length == 1,
      );
      expect(find.text(single.name), findsWidgets);
      await tester.tap(find.text('Push · $ppl (Kopie)').last);
      await tester.pumpAndSettle();
      expect(find.text('Push · $ppl (Kopie)'), findsOneWidget);
    });
  });

  // Last: loads the app font for this file.
  group('undo bar on a small phone with large text (320 × 640, text × 1.3)', () {
    Future<void> loadFont() async {
      final loader = FontLoader('Poppins');
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(File('fonts/Poppins-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await loader.load();
    }

    /// The visible bar: below a third of the screen, on screen, the action below the text (at most
    /// four lines; shown in full when [whole]).
    void expectBar(WidgetTester tester, String text, {bool whole = true}) {
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
      expect(bar.height, lessThan(640 / 3), reason: text);
      expect(bar.top, greaterThan(0));
      expect(bar.bottom, lessThanOrEqualTo(640));
      expect(bar.left >= 0 && bar.right <= 320, isTrue);
      final p = tester.renderObject<RenderParagraph>(find.descendant(of: find.text(text), matching: find.byType(RichText)));
      if (whole) expect(p.didExceedMaxLines, isFalse, reason: text);
      expect(p.maxLines, 4);
    }

    for (final de in [true, false]) {
      testWidgets('folder and program duplicates stay small and "Undo" can be tapped (${de ? 'de' : 'en'})', (tester) async {
        await tester.runAsync(loadFont);
        final ul = _defaults(de: de).where((t) => t.key != null && t.key!.startsWith('ul_')).toList();
        final folder = ul.first.folder;
        expect(folder, de ? 'Oberkörper / Unterkörper' : 'Upper / Lower');
        const other = 'Zuhause (Kurzhanteln) (Kopie 2)';
        final list = [
          ...ul,
          for (var i = ul.length; i < 11; i++) _t('r$i', folder, i, sport: Sport.run, name: 'Lauf $i'),
          _t('long', folder, 11, name: 'Oberkörper Hypertrophie Variante B'),
        ];
        final repo = _LiveRepo(list, [folder, other]);
        await pump(tester, list, fake: repo, lang: de ? 'de' : 'en', size: const Size(320, 640), textScale: 1.3);
        ProviderScope.containerOf(tester.element(find.byType(TrainPage))).read(sportFilterProvider.notifier).set(Sport.gym);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final hidden = list.where((t) => t.sport != Sport.gym).length;

        await folderMenu(tester, folder, de ? 'Ordner duplizieren' : 'Duplicate folder');
        expectBar(
          tester,
          de
              ? 'Ordner dupliziert (12 Programme). $hidden davon blendet der Sportfilter aus.'
              : 'Folder duplicated (12 programs). $hidden hidden by the sport filter.',
        );
        expect(repo.list, hasLength(24));
        await tester.tap(find.text(de ? 'Rückgängig' : 'Undo'));
        await tester.pumpAndSettle();
        expect(repo.list, hasLength(12));
        expect(repo.order, [folder, other]);

        // A long program name into a long folder name: cut after four lines instead of growing.
        if (find.byKey(const ValueKey('programMenu-long')).evaluate().isEmpty) {
          await tester.ensureVisible(find.text(folder));
          await tester.pumpAndSettle();
          await tester.tap(find.text(folder));
          await tester.pumpAndSettle();
        }
        await programMenu(tester, 'long', de ? 'In Ordner duplizieren' : 'Duplicate to folder');
        await tester.ensureVisible(find.byKey(const ValueKey('pickFolder-$other')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('pickFolder-$other')));
        await tester.pumpAndSettle();
        expectBar(
          tester,
          de ? '„Oberkörper Hypertrophie Variante B“ in $other erstellt.' : 'Created “Oberkörper Hypertrophie Variante B” in $other.',
          whole: false,
        );
        expect(repo.list.where((t) => t.folder == other), hasLength(1));
        await tester.tap(find.text(de ? 'Rückgängig' : 'Undo'));
        await tester.pumpAndSettle();
        expect(repo.list.where((t) => t.folder == other), isEmpty);
        expect(repo.order, [folder, other]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a short message keeps "Rückgängig" on its line (360 × 780)', (tester) async {
      await tester.runAsync(loadFont);
      final repo = _LiveRepo([_t('a', 'Mix', 0), _t('b', 'Mix', 1)], ['Mix']);
      await pump(tester, const [], fake: repo, size: const Size(360, 780));
      await folderMenu(tester, 'Mix', 'Ordner duplizieren');
      final text = tester.getRect(find.text('Ordner dupliziert (2 Programme).'));
      final undo = tester.getRect(find.text('Rückgängig'));
      expect(undo.left, greaterThan(text.right - 1));
      expect(undo.center.dy, closeTo(text.center.dy, 12));
      expect(tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first).height, lessThan(90));
    });
  });
}
