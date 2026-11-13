import 'package:flutter/gestures.dart';
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
import 'package:strive/features/train/program_order.dart';
import 'package:strive/features/train/train_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  var _n = 0;
  final saved = <List<WorkoutTemplate>>[];
  final folderOrders = <List<String>>[];
  @override
  String newId() => 'new${_n++}';
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async => saved.add(list);
  @override
  void saveTemplate(WorkoutTemplate t) => saved.add([t]);
  @override
  void saveFolderOrder(List<String> folders) => folderOrders.add(folders);
}

List<WorkoutTemplate> _defaults({bool de = true}) {
  var i = 0;
  return defaultTemplates(() => 'b${i++}', de: de);
}

WorkoutTemplate _t(String id, String folder, int order, {Sport sport = Sport.gym}) =>
    WorkoutTemplate(id: id, name: id, sport: sport, folder: folder, order: order);

/// The user changed a built-in gym program: one more set on the first exercise.
WorkoutTemplate _edited(WorkoutTemplate t) {
  final ex = [for (final e in t.exercises) e.copy()];
  ex.first.sets.add(ex.first.sets.first.copy());
  return t.copyWith(exercises: ex);
}

void main() {
  group('order helpers', () {
    test('folders reorder among the visible ones; hidden folders keep their slots', () {
      const full = ['A', 'B', 'C', 'D'];
      expect(reorderFolders(full, full, 0, 2), ['B', 'C', 'A', 'D']);
      expect(reorderFolders(full, full, 3, 0), ['D', 'A', 'B', 'C']);
      // Sport filter shows A, C, D only: moving D up to the top keeps B in its slot.
      expect(reorderFolders(full, const ['A', 'C', 'D'], 2, 0), ['D', 'B', 'A', 'C']);
      // A folder only known from its programs joins the order.
      expect(reorderFolders(const ['A'], const ['A', 'X'], 1, 0), ['X', 'A']);
    });

    test('a program moves inside its folder; only changed documents are written', () {
      final all = [_t('a', 'F', 0), _t('b', 'F', 1), _t('c', 'F', 2), _t('x', 'G', 0)];
      final out = placeProgram(all, all[0], 'F', 2);
      expect({for (final t in out) t.id: t.order}, {'b': 0, 'c': 1, 'a': 2});
      expect(out.every((t) => t.folder == 'F'), isTrue);
      // Moving c up by one: b and c swap, a stays untouched.
      expect({for (final t in placeProgram(all, all[2], 'F', 1)) t.id: t.order}, {'c': 1, 'b': 2});
    });

    test('a program moves into another folder at the given position', () {
      final all = [_t('a', 'F', 0), _t('b', 'F', 1), _t('x', 'G', 0), _t('y', 'G', 1)];
      final out = {for (final t in placeProgram(all, all[1], 'G', 1)) t.id: t};
      expect(out['b']!.folder, 'G');
      expect(out['b']!.order, 1);
      expect(out['y']!.order, 2);
      expect(out.containsKey('x'), isFalse);
      // Into an empty folder / "no folder".
      final loose = placeProgram(all, all[0], '', 0).single;
      expect((loose.folder, loose.order), ('', 0));
    });

    test('with a sport filter the index counts only the shown programs', () {
      final all = [_t('r1', 'F', 0, sport: Sport.run), _t('g1', 'F', 1), _t('r2', 'F', 2, sport: Sport.run), _t('g2', 'F', 3)];
      // Gym filter: shown g1, g2. Moving g2 above g1 puts it before g1, the runs keep their places.
      final out = {for (final t in placeProgram(all, all[3], 'F', 0, isVisible: (t) => t.sport == Sport.gym)) t.id: t.order};
      expect(out, {'g2': 1, 'g1': 2, 'r2': 3});
    });
  });

  group('built-in programs: untouched vs changed', () {
    test('every shipped program in both languages and every gym goal is untouched', () {
      for (final de in [false, true]) {
        for (final g in gymGoals) {
          for (final t in defaultTemplates(() => 'x', de: de, goal: g)) {
            expect(isUntouchedBuiltin(t), isTrue, reason: '${t.key} $de $g');
          }
        }
      }
    });

    test('edited sets, a new name, own weights or edited steps make it the user\'s version', () {
      final d = {for (final t in _defaults()) t.key!: t};
      expect(isUntouchedBuiltin(_edited(d['ppl_pull']!)), isFalse);
      expect(isUntouchedBuiltin(d['ppl_pull']!.copyWith(name: 'Mein Pull')), isFalse);
      final weighted = [for (final e in d['ppl_pull']!.exercises) e.copy()];
      weighted.first.sets.first.weight = 60;
      expect(isUntouchedBuiltin(d['ppl_pull']!.copyWith(exercises: weighted)), isFalse);
      final run = d.values.firstWhere((t) => t.sport == Sport.run && t.steps.length > 1);
      final steps = [...run.steps]..removeLast();
      expect(isUntouchedBuiltin(run.copyWith(steps: steps)), isFalse);
      // A custom program never counts as a built-in.
      expect(isUntouchedBuiltin(WorkoutTemplate.fromMap('c', {...d['ppl_pull']!.toMap(), 'key': null})), isFalse);
    });

    test('a zone-code revision of an old, untouched endurance program still counts as the original', () {
      final run = _defaults().firstWhere((t) => t.sport == Sport.run);
      final old = run.copyWith(
        steps: [
          for (final s in run.steps) WorkoutStep.fromMap({...s.toMap(), 'zone': 'L'}),
        ],
      );
      expect(isUntouchedBuiltin(old), isTrue);
    });
  });

  group('restoring the originals', () {
    const suffix = 'eigene';

    test('nothing to restore when every built-in is untouched (no duplicates)', () {
      var n = 0;
      final plan = planBuiltinRestore(_defaults(), () => 'n${n++}', de: true, ownSuffix: suffix);
      expect(plan.isEmpty, isTrue);
      expect(plan.writes, isEmpty);
    });

    test('a deleted built-in comes back into its standard folder', () {
      final list = _defaults()..removeWhere((t) => t.key == 'ppl_pull');
      var n = 0;
      final plan = planBuiltinRestore(list, () => 'n${n++}', de: true, ownSuffix: suffix);
      expect(plan.add.map((t) => t.key), ['ppl_pull']);
      expect(plan.add.single.folder, 'Push Pull Beine');
      expect(plan.add.single.name, 'Pull');
      expect(plan.keep, isEmpty);
      expect(plan.changed, isEmpty);
    });

    test('a changed built-in: the original is added, the changed one stays as own program', () {
      final list = [for (final t in _defaults()) t.key == 'ppl_pull' ? _edited(t) : t];
      final mine = list.firstWhere((t) => t.key == 'ppl_pull');
      var n = 0;
      final plan = planBuiltinRestore(list, () => 'n${n++}', de: true, ownSuffix: suffix);
      expect(plan.add.single.key, 'ppl_pull');
      expect(isUntouchedBuiltin(plan.add.single), isTrue);
      expect(plan.add.single.name, 'Pull');
      final kept = plan.keep.single;
      expect(kept.id, mine.id);
      expect(kept.key, isNull);
      expect(kept.name, 'Pull (eigene)');
      expect(gymSignature(kept.exercises), gymSignature(mine.exercises));
      expect(plan.changedNames, ['Pull']);
      // Applied, a second restore finds nothing.
      final after = [for (final t in list) t.id == kept.id ? kept : t, ...plan.add];
      expect(planBuiltinRestore(after, () => 'm${n++}', de: true, ownSuffix: suffix).isEmpty, isTrue);
    });

    test('a renamed changed version keeps its name', () {
      final list = [for (final t in _defaults()) t.key == 'ppl_push' ? _edited(t).copyWith(name: 'Brust & Schulter') : t];
      final plan = planBuiltinRestore(list, () => 'n', de: true, ownSuffix: suffix);
      expect(plan.keep.single.name, 'Brust & Schulter');
      expect(plan.add.single.name, 'Push');
    });

    test('restricted to folders; a renamed standard folder receives its originals', () {
      final list = [
        for (final t in _defaults())
          if (t.key != 'ppl_legs' && t.key != 'fb_a') t.folder == 'Push Pull Beine' ? t.copyWith(folder: 'PPL') : t,
      ];
      final plan = planBuiltinRestore(list, () => 'n', de: true, ownSuffix: suffix, folderKeys: {'ppl'});
      expect(plan.add.map((t) => (t.key, t.folder)), [('ppl_legs', 'PPL')]);
      expect(builtinFolderKeysOf('PPL', list), {'ppl'});
      expect(builtinFolderKeysOf('Ganzkörper', list), {'fullbody'});
      expect(builtinFolderKeysOf('Mein Ordner', list), isEmpty);
    });

    test('the gym goal sets the rep ranges of a restored program', () {
      final list = _defaults()..removeWhere((t) => t.key == 'ppl_push');
      final plan = planBuiltinRestore(list, () => 'n', de: true, ownSuffix: suffix, goal: 'strength');
      final want = defaultTemplates(() => '', goal: 'strength').firstWhere((t) => t.key == 'ppl_push');
      expect(gymSignature(plan.add.single.exercises), gymSignature(want.exercises));
    });
  });

  group('Train tab', () {
    Future<_FakeRepo> pump(
      WidgetTester tester,
      List<WorkoutTemplate> templates, {
      List<String> folderOrder = const [],
      Size size = const Size(900, 2600),
    }) async {
      tester.view.physicalSize = size;
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
            locale: const Locale('de'),
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

    Future<void> longPressDrag(WidgetTester tester, Finder from, Offset Function() to) async {
      final start = tester.getCenter(from);
      final end = to();
      final g = await tester.startGesture(start, kind: PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(start, end, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await g.up();
      await tester.pumpAndSettle();
    }

    final folders = [
      'Bro-Split',
      'Eigengewicht',
      'Ganzkörper',
      'Laufen',
      'Oberkörper / Unterkörper',
      'Push Pull Beine',
      'Radfahren',
      'Schwimmen',
      'Zuhause (Kurzhanteln)',
    ];

    testWidgets('long-press on a folder header drags it to a new place (order saved)', (tester) async {
      final repo = await pump(tester, _defaults());
      expect(find.text('Ordner und Programme lang drücken, um sie zu verschieben.'), findsOneWidget);
      await longPressDrag(tester, find.text('Bro-Split'), () => tester.getCenter(find.text('Ganzkörper')) + const Offset(0, 10));
      expect(repo.folderOrders, isNotEmpty);
      final order = repo.folderOrders.last;
      expect(order.toSet(), folders.toSet());
      expect(order.indexOf('Bro-Split'), greaterThan(order.indexOf('Eigengewicht')));
      expect(order.first, 'Eigengewicht');
    });

    testWidgets('dragging a program to the bottom edge scrolls the list', (tester) async {
      await pump(tester, _defaults(), size: const Size(500, 900));
      await tester.tap(find.text('Ganzkörper'));
      await tester.pumpAndSettle();
      final controller = PrimaryScrollController.of(tester.element(find.byType(CustomScrollView)));
      expect(controller.offset, 0);
      final start = tester.getCenter(find.text('Ganzkörper A'));
      final g = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset(start.dx, start.dy + (890 - start.dy) * i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 30; i++) {
        await g.moveBy(const Offset(0, 0.5));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(controller.offset, greaterThan(50));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('folder menu "Nach unten" moves it one place down', (tester) async {
      final repo = await pump(tester, _defaults(), folderOrder: folders);
      await tester.tap(find.byKey(const ValueKey('folderMenu-Laufen')));
      await tester.pumpAndSettle();
      expect(find.text('Nach oben'), findsOneWidget);
      await tester.tap(find.text('Nach unten'));
      await tester.pumpAndSettle();
      final order = repo.folderOrders.last;
      expect(order.indexOf('Laufen'), folders.indexOf('Laufen') + 1);
    });

    testWidgets('a program dragged onto another folder header moves into that folder', (tester) async {
      final repo = await pump(tester, _defaults());
      await tester.tap(find.text('Push Pull Beine'));
      await tester.pumpAndSettle();
      await longPressDrag(tester, find.text('Pull'), () => tester.getCenter(find.text('Bro-Split')));
      final moved = repo.saved.expand((l) => l).where((t) => t.name == 'Pull').toList();
      expect(moved, isNotEmpty);
      expect(moved.last.folder, 'Bro-Split');
      // Appended after the folder's programs; the key (plan generator) is kept.
      expect(moved.last.order, _defaults().where((t) => t.folder == 'Bro-Split').length);
      expect(moved.last.key, 'ppl_pull');
      // The target folder opened, the program shows there right away (optimistic).
      expect(find.text('Pull'), findsOneWidget);
    });

    testWidgets('a program dropped onto another program lands next to it', (tester) async {
      final repo = await pump(tester, _defaults());
      await tester.tap(find.text('Push Pull Beine'));
      await tester.pumpAndSettle();
      final legs = find.text('Beine');
      await longPressDrag(tester, find.text('Push'), () => tester.getCenter(legs) + const Offset(0, 12));
      final orders = {for (final t in repo.saved.expand((l) => l)) t.name: t.order};
      expect(orders['Push'], 2);
      expect(orders['Pull'], 0);
      expect(orders['Beine'], 1);
    });

    testWidgets('program menu "Nach unten" swaps it with the next one', (tester) async {
      final list = _defaults();
      final repo = await pump(tester, list);
      await tester.tap(find.text('Push Pull Beine'));
      await tester.pumpAndSettle();
      final push = list.firstWhere((t) => t.key == 'ppl_push');
      await tester.tap(find.byKey(ValueKey('programMenu-${push.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Nach oben'), findsNothing);
      await tester.tap(find.text('Nach unten'));
      await tester.pumpAndSettle();
      expect({for (final t in repo.saved.last) t.name: t.order}, {'Pull': 0, 'Push': 1});
    });

    testWidgets('folder menu restores changed and deleted standard programs', (tester) async {
      final list = [
        for (final t in _defaults())
          if (t.key != 'ppl_pull') t.key == 'ppl_push' ? _edited(t) : t,
      ];
      final repo = await pump(tester, list);
      await tester.tap(find.byKey(const ValueKey('folderMenu-Push Pull Beine')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standardprogramme wiederherstellen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Im Originalzustand hinzugefügt werden: Push, Pull.'), findsOneWidget);
      expect(find.textContaining('„Push (eigene)“'), findsOneWidget);
      await tester.tap(find.text('Wiederherstellen'));
      await tester.pumpAndSettle();
      final written = repo.saved.last;
      expect(written.where((t) => t.key == 'ppl_push' && isUntouchedBuiltin(t)), hasLength(1));
      expect(written.where((t) => t.key == 'ppl_pull' && isUntouchedBuiltin(t)), hasLength(1));
      final kept = written.firstWhere((t) => t.name == 'Push (eigene)');
      expect(kept.key, isNull);
      expect(find.text('2 Programme wiederhergestellt'), findsOneWidget);
    });

    testWidgets('the restore entry is hidden in folders whose originals are all there', (tester) async {
      await pump(tester, _defaults());
      await tester.tap(find.byKey(const ValueKey('folderMenu-Push Pull Beine')));
      await tester.pumpAndSettle();
      expect(find.text('Standardprogramme wiederherstellen'), findsNothing);
      expect(find.text('Umbenennen'), findsOneWidget);
    });

    testWidgets('overflow: all originals present → notice; empty library offers the standard programs', (tester) async {
      await pump(tester, _defaults());
      await tester.tap(find.byKey(const ValueKey('programsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standardprogramme wiederherstellen'));
      await tester.pumpAndSettle();
      expect(find.text('Alle Standardprogramme sind im Originalzustand vorhanden.'), findsOneWidget);
    });

    testWidgets('empty library: the button adds the standard programs (sheet, all folders preselected)', (tester) async {
      final repo = await pump(tester, const []);
      await tester.tap(find.byKey(const ValueKey('emptyAddBuiltins')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('restore-ppl')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restoreConfirm')));
      await tester.pumpAndSettle();
      expect(repo.saved.last.length, _defaults().length);
      expect(repo.saved.last.every(isUntouchedBuiltin), isTrue);
    });
  });
}
