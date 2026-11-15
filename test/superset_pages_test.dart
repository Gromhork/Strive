import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/exercise_focus_page.dart';
import 'package:strive/features/session/gym_session_page.dart';
import 'package:strive/features/stats/edit_session_page.dart';
import 'package:strive/features/stats/session_detail_page.dart';
import 'package:strive/features/train/gym_exercise_editor.dart';
import 'package:strive/features/train/program_preview_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/supersets.dart' show SupersetMove;
import 'package:strive/widgets/superset_group.dart';

final now = DateTime(2026, 11, 9, 18);
const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);

class _PresetGym extends ActiveGymNotifier {
  _PresetGym(this.init);
  final ActiveGym init;
  @override
  ActiveGym? build() => init;
}

GymExercise _e(String id, String name, {String? group, bool done = false, int sets = 2}) => GymExercise(
  exId: id,
  name: name,
  group: group,
  repMin: 8,
  repMax: 12,
  sets: [for (var i = 0; i < sets; i++) GymSet(weight: 20, reps: 10, done: done)],
);

/// Pull day: a straight set, superset A (2), a straight set, superset B (3).
List<GymExercise> _pull({bool done = false}) => [
  _e('p1', 'Uno', done: done),
  _e('p2', 'Dos', group: 'A', done: done),
  _e('p3', 'Tres', group: 'A', done: done),
  _e('p4', 'Cuatro', done: done),
  _e('p5', 'Cinco', group: 'B', done: done),
  _e('p6', 'Seis', group: 'B', done: done),
  _e('p7', 'Siete', group: 'B', done: done),
];

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  Future<SharedPreferences> prefs({bool table = false}) async {
    SharedPreferences.setMockInitialValues({'gymTableView': table});
    return SharedPreferences.getInstance();
  }

  List<Override> overrides(
    SharedPreferences p, {
    ActiveGym? g,
    List<Session> history = const [],
    List<WorkoutTemplate> templates = const [],
  }) => [
    prefsProvider.overrideWithValue(p),
    profileProvider.overrideWith((ref) => Stream.value(male80)),
    sessionsProvider.overrideWith((ref) => Stream.value(history)),
    templatesProvider.overrideWith((ref) => Stream.value(templates)),
    plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
    bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
    exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
    if (g != null) activeGymProvider.overrideWith(() => _PresetGym(g)),
  ];

  Future<ProviderContainer> pump(
    WidgetTester t,
    Widget page,
    List<Override> o, {
    Size size = const Size(420, 2600),
    bool dark = true,
    double scale = 1,
    String lang = 'de',
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: o,
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: page,
        ),
      ),
    );
    await t.pump();
    await t.pump();
    return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  /// Names of the exercises inside the frame of superset [letter].
  void expectMembers(String letter, List<String> inside, List<String> outside) {
    final group = find.byKey(ValueKey('supersetGroup-$letter'));
    expect(group, findsOneWidget);
    for (final n in inside) {
      expect(find.descendant(of: group, matching: find.text(n)), findsOneWidget, reason: '$n in $letter');
    }
    for (final n in outside) {
      expect(find.descendant(of: group, matching: find.text(n)), findsNothing, reason: '$n not in $letter');
    }
  }

  group('program editor', () {
    Widget editor(List<GymExercise> list, VoidCallback onChanged) => StatefulBuilder(
      builder:
          (c, set) => Scaffold(
            body: SingleChildScrollView(
              child: GymExerciseEditor(
                exercises: list,
                onChanged: () {
                  onChanged();
                  set(() {});
                },
              ),
            ),
          ),
    );

    testWidgets('supersets sit in one frame; link, split and dissolve are one tap each', (t) async {
      final list = _pull().sublist(0, 4);
      var changes = 0;
      await pump(t, editor(list, () => changes++), overrides(await prefs()));
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      // No letter chip in the card title any more – the rail carries it.
      expect(find.text('A'), findsNothing);
      // Linked pair: one "split" link inside the frame; "link" between all other neighbours.
      expect(find.text(de.supersetLinked), findsOneWidget);
      expect(find.text(de.linkSuperset), findsNWidgets(2));
      // No "how to" hint once a superset exists.
      expect(find.byKey(const ValueKey('supersetEditHint')), findsNothing);

      // Dissolve from the header.
      await t.tap(find.byKey(const ValueKey('dissolveSuperset-A')));
      await t.pump();
      expect(list.every((e) => e.group == null), isTrue);
      expect(find.byType(SupersetSegment), findsNothing);
      expect(find.text(de.linkSuperset), findsNWidgets(3));
      expect(find.byKey(const ValueKey('supersetEditHint')), findsOneWidget);
      expect(changes, 1);

      // Link the last two, then the one before them: one superset of three.
      await t.tap(find.text(de.linkSuperset).last);
      await t.pump();
      await t.tap(find.text(de.linkSuperset).last);
      await t.pump();
      expect(list.map((e) => e.group).toList(), [null, 'A', 'A', 'A']);
      expect(find.text('Supersatz A · 3 Übungen'), findsOneWidget);
      expect(find.text('A3'), findsOneWidget);
      // A fourth would exceed the maximum: toast, nothing changes.
      await t.tap(find.text(de.linkSuperset));
      await t.pump();
      expect(find.text(de.supersetMax), findsOneWidget);
      expect(list.first.group, isNull);
      // Split between the 2nd and 3rd member: the pair stays, the third is free again.
      await t.tap(find.text(de.supersetLinked).last);
      await t.pump();
      expect(list.map((e) => e.group).toList(), [null, 'A', 'A', null]);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('old data with separated members shows no misleading frame', (t) async {
      final list = [_e('p2', 'Dos', group: 'A'), _e('p1', 'Uno'), _e('p3', 'Tres', group: 'A')];
      await pump(t, editor(list, () {}), overrides(await prefs()));
      expect(find.byType(SupersetSegment), findsNothing);
      expect(find.text(de.linkSuperset), findsNWidgets(2));
    });

    testWidgets('320 dp, text scale 1.3, light: no overflow', (t) async {
      final list = _pull();
      await pump(t, editor(list, () {}), overrides(await prefs()), size: const Size(320, 4200), dark: false, scale: 1.3);
      expect(find.text('Supersatz B · 3 Übungen'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('running workout', () {
    testWidgets('overview: frames per superset, up-next card names the superset and what follows', (t) async {
      final ex = _pull();
      for (final s in ex.first.sets) {
        s.done = true;
      }
      await pump(t, const GymSessionPage(), overrides(await prefs(), g: ActiveGym(title: 'Pull', start: now, exercises: ex)));
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(find.text('Supersatz B · 3 Übungen'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('supersetGroup-A')), matching: find.text('Dos')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('supersetGroup-A')), matching: find.text('Tres')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('supersetGroup-A')), matching: find.text('Cuatro')), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('supersetGroup-B')), matching: find.text('Siete')), findsOneWidget);
      // Up next = first member of A: chip "Supersatz A · 1/2" and "Danach direkt: Tres".
      expect(find.byKey(const ValueKey('upNextSuperset')), findsOneWidget);
      expect(find.text('Supersatz A · 1/2'), findsOneWidget);
      expect(find.text(de.supersetThen('Tres')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('overview at 320 dp, text scale 1.3, light and dark: no overflow', (t) async {
      for (final dark in [false, true]) {
        final p = await prefs();
        await pump(
          t,
          KeyedSubtree(key: ValueKey(dark), child: const GymSessionPage()),
          overrides(p, g: ActiveGym(title: 'Pull', start: now, exercises: _pull())),
          size: const Size(320, 2600),
          dark: dark,
          scale: 1.3,
        );
        expect(find.text('Supersatz B · 3 Übungen'), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'dark=$dark');
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('table view: the same frames, no letter prefix in the card titles', (t) async {
      await pump(
        t,
        const GymSessionPage(),
        overrides(await prefs(table: true), g: ActiveGym(title: 'Pull', start: now, exercises: _pull())),
        size: const Size(420, 5200),
      );
      expectMembers('A', ['Dos', 'Tres'], ['Uno', 'Cuatro']);
      expectMembers('B', ['Cinco', 'Seis', 'Siete'], ['Cuatro']);
      expect(find.textContaining('A · Dos'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('focus view: chip with the position, next member / rest line', (t) async {
      final ex = _pull().sublist(1, 3); // A1, A2
      final c = await pump(
        t,
        const ExerciseFocusPage(),
        overrides(await prefs(), g: ActiveGym(title: 'Pull', start: now, exercises: ex)),
        size: const Size(420, 1800),
      );
      expect(find.byKey(const ValueKey('focusSuperset')), findsOneWidget);
      expect(find.text('Supersatz A · 1/2'), findsOneWidget);
      expect(find.text(de.supersetThen('Tres')), findsOneWidget);
      // Dissolved → chip and line disappear.
      c.read(activeGymProvider.notifier).toggleSuperset(0);
      await t.pump();
      expect(find.byKey(const ValueKey('focusSuperset')), findsNothing);
      expect(find.text(de.supersetThen('Tres')), findsNothing);
    });

    testWidgets('switch pause between two members: the up-next card carries the "A2" badge', (t) async {
      final ex = _pull().sublist(1, 3); // A1, A2
      final c = await pump(
        t,
        const ExerciseFocusPage(),
        overrides(await prefs(), g: ActiveGym(title: 'Pull', start: now, exercises: ex)),
        size: const Size(420, 1800),
      );
      final n = c.read(activeGymProvider.notifier);
      n.toggleDone(0, 0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('restOverlay')), findsOneWidget);
      expect(find.text(de.supersetSwitch), findsOneWidget);
      final badge = find.byKey(const ValueKey('restNextSuperset'));
      expect(badge, findsOneWidget);
      expect(find.descendant(of: badge, matching: find.text('A2')), findsOneWidget);
      n.skipRest();
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });

    test('move up / down jumps over a superset and keeps the focused exercise', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final ex = _pull();
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(p),
          activeGymProvider.overrideWith(() => _PresetGym(ActiveGym(title: 'Pull', start: now, exercises: ex, focus: 3))),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(activeGymProvider.notifier);
      // "Cuatro" (index 3) up: over the whole superset A, not into it.
      n.stepExercise(3, -1);
      var w = c.read(activeGymProvider)!;
      expect(w.exercises.map((e) => '${e.name}${e.group ?? ''}').toList(), ['Uno', 'Cuatro', 'DosA', 'TresA', 'CincoB', 'SeisB', 'SieteB']);
      expect(w.exercises[w.focus].name, 'Cuatro', reason: 'the focus follows the exercise');
      // A member at the lower edge moving down leaves its superset and passes B as a whole.
      n.stepExercise(3, 1);
      w = c.read(activeGymProvider)!;
      expect(w.exercises.map((e) => '${e.name}${e.group ?? ''}').toList(), ['Uno', 'Cuatro', 'Dos', 'CincoA', 'SeisA', 'SieteA', 'Tres']);
      // Drag-style move into the middle of the full superset: it lands right behind it.
      expect(n.moveExercise(0, 5), SupersetMove.full);
      w = c.read(activeGymProvider)!;
      expect(w.exercises.map((e) => '${e.name}${e.group ?? ''}').toList(), ['Cuatro', 'Dos', 'CincoA', 'SeisA', 'SieteA', 'Uno', 'Tres']);
    });
  });

  group('history and program', () {
    Session session(List<GymExercise> ex) =>
        Session(id: 's1', sport: Sport.gym, title: 'Pull', start: now, durationSec: 3600, exercises: ex, bodyWeightKg: 80);

    testWidgets('session detail frames the supersets that were trained', (t) async {
      await pump(t, const SessionDetailPage(sessionId: 's1'), overrides(await prefs(), history: [session(_pull(done: true))]));
      expectMembers('A', ['Dos', 'Tres'], ['Uno', 'Cuatro']);
      expectMembers('B', ['Cinco', 'Seis', 'Siete'], ['Cuatro']);
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('session detail at 320 dp, text scale 1.3, light', (t) async {
      await pump(
        t,
        const SessionDetailPage(sessionId: 's1'),
        overrides(await prefs(), history: [session(_pull(done: true))]),
        size: const Size(320, 3600),
        dark: false,
        scale: 1.3,
      );
      expect(find.text('Supersatz B · 3 Übungen'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('edit session: the same frames; "move up" jumps over the superset', (t) async {
      final s = session(_pull(done: true));
      await pump(t, EditSessionPage(session: s), overrides(await prefs(), history: [s]), size: const Size(420, 5200));
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(find.text('Supersatz B · 3 Übungen'), findsOneWidget);
      expectMembers('A', ['Dos', 'Tres'], ['Uno', 'Cuatro']);
      // "Cuatro" (below A) one step up: above the whole superset, which stays intact.
      await t.tap(find.byKey(const ValueKey('editExerciseMenu-p4')));
      await t.pumpAndSettle();
      await t.tap(find.text(de.moveUp));
      await t.pumpAndSettle();
      expectMembers('A', ['Dos', 'Tres'], ['Uno', 'Cuatro']);
      final y = [
        for (final n in ['Uno', 'Cuatro', 'Dos', 'Tres', 'Cinco']) t.getTopLeft(find.text(n)).dy,
      ];
      expect(y, [...y]..sort(), reason: 'order Uno, Cuatro, [Dos, Tres], Cinco');
      expect(t.takeException(), isNull);
    });

    testWidgets('share text groups the supersets textually', (t) async {
      final ex = _pull(done: true);
      // One member of B was skipped, one set of "Tres" differs.
      for (final s in ex[6].sets) {
        s.done = false;
      }
      ex[2].sets.last.reps = 8;
      late List<String> lines;
      await pump(
        t,
        Builder(
          builder: (c) {
            lines = gymShareLines(c, session(ex), const Units(false));
            return const SizedBox();
          },
        ),
        overrides(await prefs()),
      );
      expect(lines, [
        'Uno: 2 × 20 kg × 10',
        'Supersatz A:',
        '  A1 Dos: 2 × 20 kg × 10',
        '  A2 Tres: 20 kg × 10, 20 kg × 8',
        'Cuatro: 2 × 20 kg × 10',
        'Supersatz B:',
        '  B1 Cinco: 2 × 20 kg × 10',
        '  B2 Seis: 2 × 20 kg × 10',
      ]);
      // Only one member done → listed like a straight set, without a group line.
      for (final s in ex[5].sets) {
        s.done = false;
      }
      late List<String> single;
      await pump(
        t,
        Builder(
          key: const ValueKey('second'),
          builder: (c) {
            single = gymShareLines(c, session(ex), const Units(false));
            return const SizedBox();
          },
        ),
        overrides(await prefs()),
      );
      expect(single.sublist(4), ['Cuatro: 2 × 20 kg × 10', 'Cinco: 2 × 20 kg × 10']);
    });

    testWidgets('program preview frames the supersets (and ignores a stale lone letter)', (t) async {
      final ex = [..._pull(), _e('p8', 'Ocho', group: 'Q')];
      final tpl = WorkoutTemplate(id: 't', name: 'Pull', sport: Sport.gym, exercises: ex);
      await pump(t, ProgramPreviewPage(template: tpl), overrides(await prefs(), templates: [tpl]));
      expectMembers('A', ['Dos', 'Tres'], ['Uno', 'Cuatro']);
      expectMembers('B', ['Cinco', 'Seis', 'Siete'], ['Ocho']);
      expect(find.text('Ocho'), findsOneWidget);
      expect(find.textContaining('Q · '), findsNothing);
      expect(find.byType(SupersetGroup), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });

    testWidgets('program preview at 320 dp, text scale 1.3, light', (t) async {
      final tpl = WorkoutTemplate(id: 't', name: 'Pull', sport: Sport.gym, exercises: _pull());
      await pump(
        t,
        ProgramPreviewPage(template: tpl),
        overrides(await prefs(), templates: [tpl]),
        size: const Size(320, 2600),
        dark: false,
        scale: 1.3,
      );
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
