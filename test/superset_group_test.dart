import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_exercises.dart';
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

  group('display letter and round flow', () {
    test('supersetLetterAt is the letter of the frame, not the stored one', () {
      // Stored "B" only (the program's superset A was filtered out / never normalised).
      final ex = [_e('a'), _e('b', 'B'), _e('c', 'B'), _e('d'), _e('e', 'Q'), _e('f', 'Q'), _e('g', 'B')];
      expect([for (var i = 0; i < ex.length; i++) supersetLetterAt(ex, i)], [null, 'A', 'A', null, 'B', 'B', null]);
      expect(supersetLetterAt(ex, -1), isNull);
      expect(supersetLetterAt(ex, 99), isNull);
    });

    test('nextInSupersetRound: the first later member with open sets, else the rest follows', () {
      GymExercise m(String n, int sets, int done) =>
          GymExercise(exId: n, name: n, group: 'A', sets: [for (var i = 0; i < sets; i++) GymSet(reps: 8, done: i < done)]);
      // A1 3 sets, A2 2 sets, A3 3 sets – two rounds done.
      final ex = [m('a', 3, 2), m('b', 2, 2), m('c', 3, 2), _e('x')];
      expect(nextInSupersetRound(ex, 0), 2, reason: 'skips the finished A2');
      expect(nextInSupersetRound(ex, 1), 2);
      expect(nextInSupersetRound(ex, 2), isNull, reason: 'last member of the round');
      expect(nextInSupersetRound(ex, 3), isNull, reason: 'no superset');
      for (final s in ex[2].sets) {
        s.done = true;
      }
      expect(nextInSupersetRound(ex, 0), isNull, reason: 'all partners finished: full rest');
    });

    test('applyGymMods: a program without its legs is lettered A, B … again', () {
      GymExercise g(String name, String? group) => GymExercise(exId: 'x-$name', name: name, sets: [GymSet(reps: 10)])..group = group;
      final program = [
        g('barbell bench press', null),
        g('leg extension', 'A'),
        g('lying leg curl', 'A'),
        g('dumbbell biceps curl', 'B'),
        g('cable pushdown', 'B'),
        g('barbell squat', 'C'),
        g('dumbbell lateral raise', 'C'),
      ];
      final out = applyGymMods(program, [gymModNoLegs]);
      expect(out.map((e) => '${e.name}:${e.group ?? '-'}').toList(), [
        'barbell bench press:-',
        'dumbbell biceps curl:A',
        'cable pushdown:A',
        // Its partner (squat) is gone: a straight set, not a lone "C".
        'dumbbell lateral raise:-',
      ]);
      expect(program[3].group, 'B', reason: 'the program itself is untouched');
      // Without modifications the letters are repaired as well (what the tracker starts with).
      expect(applyGymMods(program, const []).map((e) => e.group).toList(), [null, 'A', 'A', 'B', 'B', 'C', 'C']);
    });
  });

  group('editing a stored session (split: false)', () {
    test('a longer chain stays linked; only its letters are tidied', () {
      final ex = [_e('x'), _e('a', 'C'), _e('b', 'C'), _e('c', 'C'), _e('d', 'C'), _e('y', 'C')..group = null, _e('z', 'K')];
      expect(normalizeSupersets(ex, split: false), isTrue);
      expect(_sig(ex), 'x- aA bA cA dA y- z-');
      // The default still splits (programs and running workouts: max. 3 per superset).
      final split = [_e('a', 'C'), _e('b', 'C'), _e('c', 'C'), _e('d', 'C')];
      normalizeSupersets(split);
      expect(split.where((e) => e.group != null).length, lessThan(4));
      expect(exerciseBlocks(split).every((b) => b.length <= maxSupersetSize), isTrue);
    });

    test('moving an exercise past a circuit does not split the circuit', () {
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A'), _e('d', 'A'), _e('x')];
      expect(stepExercise(ex, 4, -1, split: false), 0);
      expect(_sig(ex), 'x- aA bA cA dA');
      // A member at the edge leaves; the other three stay together.
      expect(stepExercise(ex, 4, 1, split: false), 4);
      expect(stepExercise(ex, 1, -1, split: false), 0);
      expect(_sig(ex), 'a- x- bA cA dA');
    });

    test('removing the exercise between two namesakes links nothing once the letters are tidied', () {
      // Old data: "A x A" – two straight sets that happen to share a letter.
      final ex = [_e('a', 'A'), _e('x'), _e('b', 'A')];
      normalizeSupersets(ex, split: false);
      ex.removeAt(1);
      normalizeSupersets(ex, split: false);
      expect(_sig(ex), 'a- b-');
    });

    test('restoreExercise puts a removed member back into its superset', () {
      final ex = [_e('x'), _e('a', 'A'), _e('b', 'A'), _e('y')];
      final partners = supersetPartners(ex, 2);
      expect(partners.map((e) => e.name), ['a']);
      final removed = ex.removeAt(2);
      normalizeSupersets(ex, split: false);
      expect(_sig(ex), 'x- a- y-', reason: 'a lone member is a straight set');
      expect(restoreExercise(ex, 2, removed, partners, split: false), 2);
      expect(_sig(ex), 'x- aA bA y-');

      // Middle of three: the outer two stay linked, the undo makes it three again.
      final three = [_e('a', 'A'), _e('b', 'A'), _e('c', 'A')];
      final p3 = supersetPartners(three, 1);
      final mid = three.removeAt(1);
      normalizeSupersets(three, split: false);
      expect(_sig(three), 'aA cA');
      restoreExercise(three, 1, mid, p3, split: false);
      expect(_sig(three), 'aA bA cA');
    });

    test('restoreExercise never joins or tears another superset with a stale letter', () {
      // "b" (A2) is removed, then its partner moves away and group B becomes the new "A".
      final ex = [_e('a', 'A'), _e('b', 'A'), _e('c', 'B'), _e('d', 'B'), _e('e', 'B')];
      final partners = supersetPartners(ex, 1);
      final removed = ex.removeAt(1);
      normalizeSupersets(ex, split: false);
      expect(_sig(ex), 'a- cA dA eA');
      expect(removed.group, 'A', reason: 'stale letter that now names the other superset');
      // Old index 1 = right before the other superset: a straight set, not its fourth member.
      final at = restoreExercise([...ex], 1, removed, const [], split: false);
      expect(at, 1);
      final list = [...ex];
      removed.group = 'A';
      restoreExercise(list, 1, removed, partners, split: false);
      expect(_sig(list), 'aA bA cB dB eB', reason: 'next to its former partner: linked with it only');
      // The partner is gone and the old index lies inside the other superset: behind it, unlinked.
      final moved = [ex[1], ex[2], ex[3], ex[0]]; // c d e a
      normalizeSupersets(moved, split: false);
      removed.group = 'A';
      expect(restoreExercise(moved, 1, removed, partners, split: false), 3);
      expect(_sig(moved), 'cA dA eA bB aB');
    });
  });

  group('colours', () {
    test('every group colour carries its badge text at 4.5:1 or better', () {
      for (var i = 0; i < supersetColorCount; i++) {
        final c = supersetColor(supersetLetter(i));
        expect(contrastRatio(c, supersetOnColor(c)), greaterThanOrEqualTo(4.5), reason: 'group ${supersetLetter(i)}');
      }
      // The palette repeats after its last entry and has no duplicates before.
      expect({for (var i = 0; i < supersetColorCount; i++) supersetColor(supersetLetter(i))}.length, supersetColorCount);
      expect(supersetColor(supersetLetter(supersetColorCount)), supersetColor('A'));
      // Pink (D): white text had under 3:1.
      expect(supersetOnColor(supersetColor('D')), Colors.black);
    });

    test('the frame outline is darker than the accent on light backgrounds', () {
      for (var i = 0; i < supersetColorCount; i++) {
        final l = supersetLetter(i);
        final accent = supersetColor(l);
        final light = supersetFrameColor(l, dark: false).withValues(alpha: 1);
        expect(contrastRatio(light, Colors.white), greaterThan(contrastRatio(accent, Colors.white)), reason: 'group $l');
        expect(supersetFrameColor(l, dark: true).withValues(alpha: 1), accent);
      }
    });
  });

  group('SupersetGroup', () {
    final de = lookupAppLocalizations(const Locale('de'));

    testWidgets('next-in-superset line follows the real state: finished partners are skipped', (t) async {
      GymExercise m(String n, int sets, int done, {bool warmup = false}) => GymExercise(
        exId: 'x-$n',
        name: n,
        group: 'A',
        sets: [for (var i = 0; i < sets; i++) GymSet(reps: 8, done: i < done, type: warmup && i == 0 ? SetType.warmup : SetType.normal)],
      );
      Future<void> show(List<GymExercise> ex) => t.pumpWidget(
        _app(
          Scaffold(
            body: Column(children: [for (var i = 0; i < ex.length; i++) SupersetNextLine(key: ValueKey('n$i'), exercises: ex, index: i)]),
          ),
        ),
      );
      Finder line(int i) => find.descendant(of: find.byKey(ValueKey('n$i')), matching: find.byType(Text));
      String text(int i) => t.widget<Text>(line(i)).data!;

      // A1 with 3 sets, A2 with 2 – two rounds done: after A1's last set the rest follows.
      await show([m('Reverse Flys', 3, 2), m('Bizepscurl', 2, 2)]);
      expect(text(0), de.supersetThenRest);
      expect(find.text(de.supersetThen('Bizepscurl')), findsNothing);
      expect(line(1), findsNothing, reason: 'a finished exercise has no "next"');
      expect(find.descendant(of: find.byKey(const ValueKey('n0')), matching: find.byIcon(Icons.timer_outlined)), findsOneWidget);

      // Three members, the middle one finished: A1 goes straight on to A3.
      await show([m('Uno', 3, 1), m('Dos', 1, 1), m('Tres', 3, 1)]);
      expect(text(0), de.supersetThen('Tres'));
      expect(text(2), de.supersetThenRest);
      expect(
        find.descendant(of: find.byKey(const ValueKey('n0')), matching: find.byIcon(Icons.subdirectory_arrow_right_rounded)),
        findsOneWidget,
      );

      // Before a warm-up set the tracker stays on the exercise: no promise of a switch.
      await show([m('Uno', 3, 0, warmup: true), m('Dos', 2, 0)]);
      expect(line(0), findsNothing);
      expect(text(1), de.supersetThenRest);
      // The warm-up done: the round starts.
      await show([m('Uno', 3, 1, warmup: true), m('Dos', 2, 0)]);
      expect(text(0), de.supersetThen('Dos'));
    });

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
