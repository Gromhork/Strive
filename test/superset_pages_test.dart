import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/planned_workout_page.dart';
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

class _Repo extends Repository {
  _Repo() : super('test');
  final updated = <String, Map<String, dynamic>>{};
  @override
  Future<void> updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) async => updated.addAll(sessions);
}

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
  TestWidgetsFlutterBinding.ensureInitialized();
  // restore() / discard() toggle the wake lock – no platform in tests.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
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
    List<PlannedWorkout> plans = const [],
  }) => [
    prefsProvider.overrideWithValue(p),
    profileProvider.overrideWith((ref) => Stream.value(male80)),
    sessionsProvider.overrideWith((ref) => Stream.value(history)),
    templatesProvider.overrideWith((ref) => Stream.value(templates)),
    plansProvider.overrideWith((ref) => Stream.value(plans)),
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

    testWidgets('drag & drop into a superset: "added to superset" / "superset is full" toasts', (t) async {
      // Uno · [Dos, Tres] · Cuatro · [Cinco, Seis, Siete]
      final list = _pull();
      await pump(t, editor(list, () {}), overrides(await prefs()), size: const Size(420, 5200));
      void drop(int from, int to) => t.widget<ReorderableListView>(find.byType(ReorderableListView)).onReorder(from, to);
      // "Uno" between Dos and Tres (list index before removal: 2) → third member of A.
      drop(0, 2);
      await t.pump();
      expect(find.text(de.supersetJoined('A')), findsOneWidget);
      expect(list.map((e) => '${e.name}${e.group ?? ''}').toList(), ['DosA', 'UnoA', 'TresA', 'Cuatro', 'CincoB', 'SeisB', 'SieteB']);
      expect(find.text('Supersatz A · 3 Übungen'), findsOneWidget);
      expect(find.text('A3'), findsOneWidget);
      // "Cuatro" into the full superset B (between Cinco and Seis) → behind it, with the reason.
      drop(3, 5);
      await t.pump();
      expect(find.text(de.supersetFullMoved), findsOneWidget);
      expect(find.text(de.supersetJoined('A')), findsNothing);
      expect(list.map((e) => '${e.name}${e.group ?? ''}').toList(), ['DosA', 'UnoA', 'TresA', 'CincoB', 'SeisB', 'SieteB', 'Cuatro']);
      expect(find.text('Supersatz B · 3 Übungen'), findsOneWidget);
      // A plain move (Cuatro to the top) says nothing.
      drop(6, 0);
      await t.pump();
      expect(find.byType(SnackBar), findsOneWidget, reason: 'no new toast (the last one is still showing)');
      expect(find.text(de.supersetFullMoved), findsOneWidget);
      expect(list.first.name, 'Cuatro');
      expect(t.takeException(), isNull);
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

    testWidgets('unequal set counts: the partner is finished → "rest afterwards", not "straight on to"', (t) async {
      // A1 with 3 sets, A2 with 2 – two rounds done.
      final ex = [_e('p2', 'Dos', group: 'A', sets: 3), _e('p3', 'Tres', group: 'A', sets: 2)];
      for (final e in ex) {
        e.sets[0].done = e.sets[1].done = true;
      }
      final p = await prefs();
      final c = await pump(t, const GymSessionPage(), overrides(p, g: ActiveGym(title: 'Pull', start: now, exercises: ex)));
      final card = find.byKey(const ValueKey('upNextCard'));
      expect(find.descendant(of: card, matching: find.text('Supersatz A · 1/2')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(de.supersetThenRest)), findsOneWidget);
      expect(find.text(de.supersetThen('Tres')), findsNothing);
      // … and that is what happens: the full rest, no switch to "Tres".
      final n = c.read(activeGymProvider.notifier);
      ex[0].restSec = 90;
      ex[1].restSec = 90;
      // One more exercise so the workout is not finished with that set.
      n.addExercise(_e('p9', 'Nueve'));
      n.toggleDone(0, 2);
      final w = c.read(activeGymProvider)!;
      expect(w.restIsTransition, isFalse);
      expect(w.restEnd, isNotNull);
      expect(w.exercises[w.focus].name, 'Nueve');
      n.skipRest();
      await t.pump(const Duration(seconds: 2));
      await t.pumpWidget(const SizedBox());

      // The focus view says the same.
      final again = [_e('p2', 'Dos', group: 'A', sets: 3), _e('p3', 'Tres', group: 'A', sets: 2)];
      for (final e in again) {
        e.sets[0].done = e.sets[1].done = true;
      }
      await pump(
        t,
        const ExerciseFocusPage(key: ValueKey('focus')),
        overrides(p, g: ActiveGym(title: 'Pull', start: now, exercises: again)),
        size: const Size(420, 1800),
      );
      expect(find.text(de.supersetThenRest), findsOneWidget);
      expect(find.text(de.supersetThen('Tres')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('stored letters differ from the shown ones: chip, badge and frame agree', (t) async {
      // Only "B" stored (the program's superset A was filtered out; a restored / old workout).
      List<GymExercise> ex() => [_e('p1', 'Uno', done: true), _e('p2', 'Dos', group: 'B'), _e('p3', 'Tres', group: 'B')];
      final p = await prefs();
      await pump(t, const GymSessionPage(), overrides(p, g: ActiveGym(title: 'Arme', start: now, exercises: ex())));
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(find.text('Supersatz A · 1/2'), findsOneWidget);
      expect(find.textContaining('Supersatz B'), findsNothing);
      // Same colour as the frame's badges.
      final chip = t.widget<Container>(
        find.descendant(of: find.byKey(const ValueKey('upNextSuperset')), matching: find.byType(Container)).first,
      );
      expect((chip.decoration! as BoxDecoration).color, supersetColor('A'));
      await t.pumpWidget(const SizedBox());

      // Focus view + switch pause.
      final c = await pump(
        t,
        const ExerciseFocusPage(key: ValueKey('focus')),
        overrides(p, g: ActiveGym(title: 'Arme', start: now, exercises: ex(), focus: 1)),
        size: const Size(420, 1800),
      );
      expect(find.descendant(of: find.byKey(const ValueKey('focusSuperset')), matching: find.text('Supersatz A · 1/2')), findsOneWidget);
      final n = c.read(activeGymProvider.notifier);
      n.toggleDone(1, 0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      final badge = find.byKey(const ValueKey('restNextSuperset'));
      expect(find.descendant(of: badge, matching: find.text('A2')), findsOneWidget);
      expect(find.text('B2'), findsNothing);
      n.skipRest();
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });

    test('a restored workout is repaired like a started one', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(p)]);
      addTearDown(c.dispose);
      final n = c.read(activeGymProvider.notifier);
      n.restore(
        ActiveGym(
          title: 'Arme',
          start: now,
          exercises: [_e('p1', 'Uno', group: 'B'), _e('p2', 'Dos'), _e('p3', 'Tres', group: 'B'), _e('p4', 'Cuatro', group: 'B')],
        ),
      );
      expect(c.read(activeGymProvider)!.exercises.map((e) => e.group).toList(), [null, null, 'A', 'A']);
      n.discard();
    });

    testWidgets('focus view: the progress bar joins the members of a superset', (t) async {
      await pump(
        t,
        const ExerciseFocusPage(),
        overrides(await prefs(), g: ActiveGym(title: 'Pull', start: now, exercises: _pull())),
        size: const Size(420, 1800),
      );
      // The coloured bar itself (inside the dot's margin).
      Rect dot(int i) => t.getRect(find.descendant(of: find.byKey(ValueKey('focusDot-$i')), matching: find.byType(DecoratedBox)));
      double gap(int i) => dot(i + 1).left - dot(i).right;
      // Uno | Dos+Tres | Cuatro | Cinco+Seis+Siete
      expect(gap(1), moreOrLessEquals(0), reason: 'A1–A2 joined');
      expect(gap(4), moreOrLessEquals(0), reason: 'B1–B2 joined');
      expect(gap(5), moreOrLessEquals(0), reason: 'B2–B3 joined');
      for (final i in [0, 2, 3]) {
        expect(gap(i), moreOrLessEquals(4), reason: 'gap after exercise $i');
      }
    });

    testWidgets('focus view at 320 dp, text scale 1.3, light and dark: no overflow', (t) async {
      for (final dark in [false, true]) {
        final ex = [
          _e('p2', 'Kurzhantel-Seitheben vorgebeugt am Schrägbank-Kabelzug', group: 'A'),
          _e('p3', 'Trizepsdrücken am Kabelzug mit Seil über Kopf', group: 'A'),
        ];
        await pump(
          t,
          ExerciseFocusPage(key: ValueKey(dark)),
          overrides(await prefs(), g: ActiveGym(title: 'Pull', start: now, exercises: ex)),
          size: const Size(320, 2600),
          dark: dark,
          scale: 1.3,
        );
        expect(find.byKey(const ValueKey('focusSuperset')), findsOneWidget);
        expect(find.text(de.supersetThen('Trizepsdrücken am Kabelzug mit Seil über Kopf')), findsOneWidget);
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

  group('planned workout', () {
    // What the athlete reported: a pull day with two supersets and long German names.
    GymExercise x(String id, String name, {String? group}) => GymExercise(
      exId: id,
      name: name,
      group: group,
      repMin: 6,
      repMax: 10,
      sets: [for (var i = 0; i < 3; i++) GymSet(weight: 47.5, reps: 6)],
    );
    final tpl = WorkoutTemplate(
      id: 't',
      name: 'Pull',
      sport: Sport.gym,
      exercises: [
        x('q1', 'Klimmzüge mit Zusatzgewicht'),
        x('q2', 'Seitheben vorgebeugt am Kabelzug', group: 'A'),
        x('q3', 'Bizepsbeuge mit der SZ-Stange', group: 'A'),
        x('q4', 'Langhantelrudern vorgebeugt'),
        x('q5', 'Armbeuger-Hammercurl im Wechsel', group: 'B'),
        x('q6', 'Gesichtsziehen am Kabelzug mit Seil', group: 'B'),
        x('q7', 'Unterarmstütz'),
      ],
    );
    final plan = PlannedWorkout(
      id: 'p',
      date: now.add(const Duration(days: 1)),
      sport: Sport.gym,
      title: 'Pull',
      durationMin: 60,
      templateId: 't',
    );

    testWidgets('membership and the end of every superset are obvious', (t) async {
      await pump(
        t,
        const PlannedWorkoutPage(planId: 'p'),
        overrides(await prefs(), templates: [tpl], plans: [plan]),
        size: const Size(420, 3200),
      );
      expectMembers(
        'A',
        ['Seitheben vorgebeugt am Kabelzug', 'Bizepsbeuge mit der SZ-Stange'],
        ['Klimmzüge mit Zusatzgewicht', 'Langhantelrudern vorgebeugt'],
      );
      expectMembers(
        'B',
        ['Armbeuger-Hammercurl im Wechsel', 'Gesichtsziehen am Kabelzug mit Seil'],
        ['Langhantelrudern vorgebeugt', 'Unterarmstütz'],
      );
      expect(find.text('Supersatz A · 2 Übungen'), findsOneWidget);
      expect(find.text('Supersatz B · 2 Übungen'), findsOneWidget);
      expect(find.text(de.supersetGroupHint), findsNWidgets(2));
      for (final b in ['A1', 'A2', 'B1', 'B2']) {
        expect(find.text(b), findsOneWidget);
      }
      // The frame of A ends above the next straight set, with clear air in between.
      final a = t.getRect(find.byKey(const ValueKey('supersetGroup-A')));
      final next = t.getRect(find.text('Langhantelrudern vorgebeugt'));
      expect(next.top, greaterThan(a.bottom));
      expect(t.takeException(), isNull);
    });

    testWidgets('320 dp, text scale 1.3, light and dark: no overflow, the "adjust" button wraps', (t) async {
      for (final dark in [false, true]) {
        await pump(
          t,
          PlannedWorkoutPage(key: ValueKey(dark), planId: 'p'),
          overrides(await prefs(), templates: [tpl], plans: [plan]),
          size: const Size(320, 4200),
          dark: dark,
          scale: 1.3,
        );
        expect(t.takeException(), isNull, reason: 'dark=$dark');
        expect(find.text('Supersatz B · 2 Übungen'), findsOneWidget);
        expect(find.text(de.adjustExercises), findsOneWidget);
        expectMembers('A', ['Seitheben vorgebeugt am Kabelzug', 'Bizepsbeuge mit der SZ-Stange'], ['Langhantelrudern vorgebeugt']);
        // Every member's name keeps real room next to the rail and the thumbnail.
        expect(t.getSize(find.text('Bizepsbeuge mit der SZ-Stange')).width, greaterThan(90), reason: 'dark=$dark');
        await t.pumpWidget(const SizedBox());
      }
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
      // Wide enough: the full rows with set number, "Gewicht" label and the unit as suffix.
      expect(find.text(de.weight), findsNWidgets(14));
      expect(find.descendant(of: find.byType(Card), matching: find.text('1')), findsNWidgets(7));
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

    testWidgets('edit session at 320 dp (text scale 1.0 and 1.3, light and dark): names stay readable, no overflow', (t) async {
      const long = 'Kurzhantel-Seitheben vorgebeugt';
      for (final scale in [1.0, 1.3]) {
        for (final dark in [false, true]) {
          final ex = _pull(done: true);
          ex[1].name = long;
          final s = session(ex);
          await pump(
            t,
            EditSessionPage(key: ValueKey('$scale$dark'), session: s),
            overrides(await prefs(), history: [s]),
            size: const Size(320, 9000),
            dark: dark,
            scale: scale,
          );
          final why = 'scale=$scale dark=$dark';
          expect(t.takeException(), isNull, reason: why);
          expectMembers('A', [long, 'Tres'], ['Uno', 'Cuatro']);
          // The name of a member has real room (it had none next to the bodyweight switch).
          expect(t.getSize(find.text(long)).width, greaterThan(100), reason: why);
          // One bodyweight switch per exercise, below the title – never in its row.
          final chips = find.byKey(const ValueKey('edit-bw'));
          expect(chips, findsNWidgets(7), reason: why);
          final card = find.ancestor(of: find.text(long), matching: find.byType(Card));
          final chip = find.descendant(of: card, matching: chips);
          expect(t.getTopLeft(chip).dy, greaterThanOrEqualTo(t.getBottomLeft(find.text(long)).dy), reason: why);
          // Weight and reps of a member stay usable next to the rail.
          for (final f in t.widgetList<TextFormField>(find.descendant(of: card, matching: find.byType(TextFormField)))) {
            expect(t.getSize(find.byWidget(f)).width, greaterThanOrEqualTo(64), reason: why);
          }
          // Compact rows on this width: the unit is the label (no suffix eating the field), no set number.
          expect(find.descendant(of: card, matching: find.text('kg')), findsNWidgets(2), reason: why);
          expect(find.descendant(of: card, matching: find.text(de.weight)), findsNothing, reason: why);
          expect(find.descendant(of: card, matching: find.text('1')), findsNothing, reason: why);
          await t.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('edit session: removing an exercise links nothing by accident; undo restores the superset', (t) async {
      // Old, never normalised data: "Uno" and "Tres" share a letter but are separated by "Dos".
      final s = session([
        _e('p1', 'Uno', group: 'A', done: true),
        _e('p2', 'Dos', done: true),
        _e('p3', 'Tres', group: 'A', done: true),
        _e('p4', 'Cuatro', group: 'C', done: true),
        _e('p5', 'Cinco', group: 'C', done: true),
      ]);
      final repo = _Repo();
      await pump(t, EditSessionPage(session: s), [
        ...overrides(await prefs(), history: [s]),
        repoProvider.overrideWithValue(repo),
      ], size: const Size(420, 5200));
      expect(find.byType(SupersetGroup), findsOneWidget);
      expectMembers('A', ['Cuatro', 'Cinco'], ['Uno', 'Dos', 'Tres']);

      Future<void> remove(String id) async {
        await t.tap(find.byKey(ValueKey('editExerciseMenu-$id')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('editRemoveExercise')));
        await t.pumpAndSettle();
      }

      // "Dos" removed: Uno and Tres are neighbours now – still two straight sets.
      await remove('p2');
      expect(find.text('Dos'), findsNothing);
      expect(find.byType(SupersetGroup), findsOneWidget);
      expectMembers('A', ['Cuatro', 'Cinco'], ['Uno', 'Tres']);

      // A member removed: the other one is a straight set; undo → the superset is back.
      await remove('p5');
      expect(find.byType(SupersetGroup), findsNothing);
      await t.tap(find.text(de.undo));
      await t.pumpAndSettle();
      expectMembers('A', ['Cuatro', 'Cinco'], ['Uno', 'Tres']);

      await t.tap(find.byKey(const ValueKey('editSave')));
      await t.pumpAndSettle();
      final saved = (repo.updated['s1']!['exercises'] as List).cast<Map<String, dynamic>>();
      expect(saved.map((e) => '${e['name']}${e['group'] ?? ''}').toList(), ['Uno', 'Tres', 'CuatroA', 'CincoA']);
      expect(t.takeException(), isNull);
    });

    testWidgets('edit session: a circuit of an old session survives a reorder', (t) async {
      final s = session([
        _e('p1', 'Uno', done: true),
        for (final (i, n) in ['Dos', 'Tres', 'Cuatro', 'Cinco'].indexed) _e('c$i', n, group: 'K', done: true),
      ]);
      await pump(t, EditSessionPage(session: s), overrides(await prefs(), history: [s]), size: const Size(420, 5200));
      expect(find.text('Zirkel A · 4 Übungen'), findsOneWidget);
      // "Uno" one step down: below the whole circuit, which stays one group of four.
      await t.tap(find.byKey(const ValueKey('editExerciseMenu-p1')));
      await t.pumpAndSettle();
      await t.tap(find.text(de.moveDown));
      await t.pumpAndSettle();
      expect(find.text('Zirkel A · 4 Übungen'), findsOneWidget);
      expectMembers('A', ['Dos', 'Tres', 'Cuatro', 'Cinco'], ['Uno']);
      expect(t.getTopLeft(find.text('Uno')).dy, greaterThan(t.getTopLeft(find.text('Cinco')).dy));
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
        'Uno: 2 × 20 kg × 10',
        'Supersatz A:',
        '  A1 Dos: 2 × 20 kg × 10',
        '  A2 Tres: 20 kg × 10, 20 kg × 8',
        'Cuatro: 2 × 20 kg × 10',
        'Supersatz B:',
        '  B1 Cinco: 2 × 20 kg × 10',
        '  B2 Seis: 2 × 20 kg × 10',
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
      expect(single.sublist(4), ['Cuatro: 2 × 20 kg × 10', 'Cinco: 2 × 20 kg × 10']);
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
