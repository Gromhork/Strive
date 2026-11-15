import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/supersets.dart';
import 'package:strive/widgets/superset_group.dart';
import 'package:strive/widgets/term_info.dart';

GymExercise _e(String name, [String? group]) => GymExercise(exId: 'x-$name', name: name, sets: [GymSet(reps: 8)])..group = group;

String _sig(List<GymExercise> ex) => ex.map((e) => '${e.name}${e.group ?? '-'}').join(' ');

Widget _app(Widget home, {String lang = 'de', bool dark = false, double scale = 1}) => MaterialApp(
  locale: Locale(lang),
  theme: dark ? ThemeData.dark() : ThemeData.light(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
  home: home,
);

Widget _list(List<GymExercise> ex) => Scaffold(
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: groupedExerciseWidgets(
      ex,
      (i) => ListTile(
        key: ValueKey('tile-$i'),
        leading: const SizedBox(width: 48, height: 48),
        title: Text(ex[i].name),
        subtitle: const Text('3 × 12–20 · ≈ 37,5 kg × 8 pro Hand'),
      ),
    ),
  ),
);

void main() {
  group('exerciseBlocks', () {
    test('adjacent namesakes form one block, everything else stays single', () {
      final ex = [_e('a'), _e('b', 'A'), _e('c', 'A'), _e('d'), _e('e', 'B'), _e('f', 'B'), _e('g', 'B')];
      final b = exerciseBlocks(ex);
      expect(b.map((x) => '${x.start}-${x.end}${x.letter ?? ''}').toList(), ['0-0', '1-2A', '3-3', '4-6B']);
      expect(b[1].indices.toList(), [1, 2]);
      expect(b[1].grouped, isTrue);
      expect(b[0].grouped, isFalse);
    });

    test('a superset whose members are separated by another exercise falls apart instead of framing the stranger', () {
      // "A · x · A": never normalised data (an old session).
      final ex = [_e('a', 'A'), _e('x'), _e('b', 'A')];
      expect(exerciseBlocks(ex).every((b) => !b.grouped), isTrue);
      // "A A x A A": two separate groups – lettered A and B, never two "A".
      final two = [_e('a', 'A'), _e('b', 'A'), _e('x'), _e('c', 'A'), _e('d', 'A')];
      expect(exerciseBlocks(two).where((b) => b.grouped).map((b) => b.letter).toList(), ['A', 'B']);
      // The stored data is not touched by the view.
      expect(_sig(two), 'aA bA x- cA dA');
    });

    test('display letters follow the order of appearance, a lone letter is no group', () {
      final ex = [_e('a', 'C'), _e('b', 'C'), _e('c', 'Q'), _e('d', 'B'), _e('e', 'B')];
      final b = exerciseBlocks(ex);
      expect(b.map((x) => x.letter).toList(), ['A', null, 'B']);
    });

    test('a long chain stays one block (shown as a circuit)', () {
      final ex = [for (var i = 0; i < 5; i++) _e('e$i', 'A')];
      final b = exerciseBlocks(ex);
      expect(b, hasLength(1));
      expect(b.single.length, 5);
    });
  });

  group('moveExercise (drag & drop)', () {
    test('an exercise dropped between two members joins the superset', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('x')];
      expect(moveExercise(ex, 2, 1), SupersetMove.joined);
      expect(_sig(ex), 'aA xA bA');
    });

    test('a full superset is never torn apart: the exercise lands right after it', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A'), _e('y'), _e('x')];
      expect(moveExercise(ex, 4, 1), SupersetMove.full);
      expect(_sig(ex), 'aA bA cA x- y-');
    });

    test('members can be reordered inside their superset', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A'), _e('x')];
      expect(moveExercise(ex, 0, 1), SupersetMove.moved);
      expect(_sig(ex), 'bA aA cA x-');
      moveExercise(ex, 0, 2);
      expect(_sig(ex), 'aA cA bA x-');
    });

    test('a member dragged away leaves its superset; a remaining pair stays linked', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A'), _e('x')];
      moveExercise(ex, 0, 3);
      expect(_sig(ex), 'bA cA x- a-');
      // The last pair dissolves when one of the two leaves.
      moveExercise(ex, 0, 3);
      expect(_sig(ex), 'c- x- a- b-');
    });

    test('a member dropped into another superset changes groups', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A'), _e('d', 'B'), _e('e', 'B')];
      expect(moveExercise(ex, 0, 3), SupersetMove.joined);
      expect(_sig(ex), 'bA cA dB aB eB');
    });

    test('dropping next to (not into) a superset does not join it', () {
      final ex = [_e('x'), _e('a', 'A'), _e('b', 'A'), _e('y')];
      moveExercise(ex, 3, 1);
      expect(_sig(ex), 'x- y- aA bA');
      moveExercise(ex, 0, 3);
      expect(_sig(ex), 'y- aA bA x-');
    });

    test('non-contiguous old data is repaired on the first move', () {
      final ex = [_e('a', 'A'), _e('x'), _e('b', 'A'), _e('c', 'A')];
      moveExercise(ex, 1, 0);
      expect(_sig(ex), 'x- a- bA cA');
    });
  });

  group('stepExercise (move up / down)', () {
    test('an exercise jumps over a whole superset instead of entering it', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('x')];
      expect(stepExercise(ex, 2, -1), 0);
      expect(_sig(ex), 'x- aA bA');
      expect(stepExercise(ex, 0, 1), 2);
      expect(_sig(ex), 'aA bA x-');
    });

    test('members swap inside their superset and leave it at the edge', () {
      final ex = [_e('x'), _e('a', 'A'), _e('b', 'A'), _e('c', 'A')];
      expect(stepExercise(ex, 3, -1), 2);
      expect(_sig(ex), 'x- aA cA bA');
      expect(stepExercise(ex, 1, -1), 0);
      expect(_sig(ex), 'a- x- cA bA');
    });

    test('the ends of the list are a no-op', () {
      final ex = [_e('a'), _e('b')];
      expect(stepExercise(ex, 0, -1), 0);
      expect(stepExercise(ex, 1, 1), 1);
      expect(_sig(ex), 'a- b-');
    });
  });

  test('dissolveSuperset frees every member, other supersets keep their order', () {
    final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A'), _e('d', 'B'), _e('e', 'B')];
    dissolveSuperset(ex, 1);
    expect(_sig(ex), 'a- b- c- dA eA');
  });

  group('SupersetGroup', () {
    final de = lookupAppLocalizations(const Locale('de'));

    testWidgets('frames the members, names the group and numbers every member', (t) async {
      final semantics = t.ensureSemantics();
      final ex = [_e('Klimmzug'), _e('Reverse Flys', 'A'), _e('Bizepscurl', 'A'), _e('Hammercurl')];
      await t.pumpWidget(_app(_list(ex)));
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(find.text(de.supersetGroupHint), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      expect(find.byType(TermInfoButton), findsOneWidget);
      // Exactly the two members sit inside the frame; the neighbours stay outside.
      final group = find.byKey(const ValueKey('supersetGroup-A'));
      expect(find.descendant(of: group, matching: find.text('Reverse Flys')), findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Bizepscurl')), findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Klimmzug')), findsNothing);
      expect(find.descendant(of: group, matching: find.text('Hammercurl')), findsNothing);
      // The members are attached (no gap), the frame is set off from its neighbours.
      final box = t.getRect(group);
      expect(t.getRect(find.byKey(const ValueKey('tile-0'))).bottom, lessThan(box.top + 6.5));
      expect(t.getRect(find.byKey(const ValueKey('tile-3'))).top, greaterThanOrEqualTo(box.bottom - 0.01));
      expect(t.getRect(find.byKey(const ValueKey('tile-2'))).top, t.getRect(find.byKey(const ValueKey('tile-1'))).bottom);
      // Members are indented behind the rail.
      expect(
        t.getRect(find.byKey(const ValueKey('tile-1'))).left,
        t.getRect(find.byKey(const ValueKey('tile-0'))).left + supersetRailWidth,
      );
      // Not colour only: screen readers get "Supersatz A, Übung 1 von 2".
      expect(find.bySemanticsLabel(RegExp('Supersatz A, Übung 1 von 2')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Supersatz A, Übung 2 von 2')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('every group has its own letter and colour; separated members are no group', (t) async {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('x'), _e('c', 'A'), _e('d', 'A'), _e('e', 'A'), _e('y', 'D'), _e('z')];
      await t.pumpWidget(_app(_list(ex), lang: 'en'));
      expect(find.text('Superset A · 2 exercises'), findsOneWidget);
      expect(find.text('Superset B · 3 exercises'), findsOneWidget);
      expect(find.text('B3'), findsOneWidget);
      expect(find.textContaining('Superset C'), findsNothing);
      expect(supersetColor('A'), isNot(supersetColor('B')));
      expect(supersetColor('A'), AppColors.brand);
      // The palette repeats after five groups but stays defined for every letter.
      expect(supersetColor('F'), supersetColor('A'));
      expect(supersetColor(null), supersetColor('A'));
    });

    testWidgets('four and more linked exercises are called a circuit', (t) async {
      await t.pumpWidget(_app(_list([for (var i = 0; i < 4; i++) _e('e$i', 'A')])));
      expect(find.text('Zirkel A · 4 Übungen'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
    });

    testWidgets('no overflow at 320 dp, text scale 1.3, light and dark, de and en', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final ex = [
        _e('Rudern vorgebeugt (Langhantel)'),
        _e('Reverse Flys (Kurzhantel) am Schrägbank-Kabelzug', 'A'),
        _e('Bizepscurl (Langhantel)', 'A'),
        _e('Hammercurl (Kurzhantel)', 'A'),
      ];
      for (final dark in [false, true]) {
        for (final lang in ['de', 'en']) {
          await t.pumpWidget(_app(KeyedSubtree(key: ValueKey('$dark$lang'), child: _list(ex)), lang: lang, dark: dark, scale: 1.3));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$lang dark=$dark');
          expect(find.text('A3'), findsOneWidget);
          // The badge keeps its size, so the rail does not grow with the font.
          expect(t.getSize(find.byType(SupersetBadge).first), const Size(26, 20));
        }
      }
    });

    testWidgets('next-in-superset line: the partner for every member but the last, then the rest', (t) async {
      final ex = [_e('Klimmzug'), _e('Reverse Flys', 'A'), _e('Bizepscurl', 'A')];
      await t.pumpWidget(
        _app(
          Scaffold(body: Column(children: [for (var i = 0; i < 3; i++) SupersetNextLine(key: ValueKey('n$i'), exercises: ex, index: i)])),
        ),
      );
      expect(find.descendant(of: find.byKey(const ValueKey('n0')), matching: find.byType(Text)), findsNothing);
      expect(find.text(de.supersetThen('Bizepscurl')), findsOneWidget);
      expect(find.text(de.supersetThenRest), findsOneWidget);
    });

    testWidgets('chip shows the position in the group', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: Center(child: SupersetChip(letter: 'B', position: 1, count: 3)))));
      expect(find.text('Supersatz B · 2/3'), findsOneWidget);
    });
  });
}
