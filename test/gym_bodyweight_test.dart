import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/session/gym_session_page.dart';
import 'package:strive/features/session/session_summary_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/widgets/rpe_picker.dart';

final now = DateTime(2026, 11, 9, 18);
const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);

LoadPrescriber lp(List<Session> h) => LoadPrescriber(history: h, profile: male80, now: now);

Session gym(int daysAgo, List<GymExercise> ex, {String id = 'h'}) =>
    Session(id: id, sport: Sport.gym, title: 'Gym', start: now.subtract(Duration(days: daysAgo)), durationSec: 3600, exercises: ex);

GymExercise ex(String id, String name, List<(double, int)> sets, {bool done = false, bool? bw, double bodyKg = 0}) =>
    GymExercise(exId: id, name: name, bw: bw, bodyKg: bodyKg, sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: done)]);

class _PresetGym extends ActiveGymNotifier {
  _PresetGym(this.init);
  final ActiveGym init;
  @override
  ActiveGym? build() => init;
}

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final saved = <Session>[];
  @override
  void saveSession(Session s) => saved.add(s);
  @override
  void updatePlan(String id, Map<String, dynamic> data) {}
}

Future<SharedPreferences> _prefs({bool table = true}) async {
  SharedPreferences.setMockInitialValues({'gymTableView': table});
  return SharedPreferences.getInstance();
}

List<Override> _overrides(SharedPreferences prefs, {ActiveGym? gym, List<Session> history = const [], Repository? repo}) => [
  prefsProvider.overrideWithValue(prefs),
  profileProvider.overrideWith((ref) => Stream.value(male80)),
  sessionsProvider.overrideWith((ref) => Stream.value(history)),
  plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
  exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
  if (gym != null) activeGymProvider.overrideWith(() => _PresetGym(gym)),
  if (repo != null) repoProvider.overrideWithValue(repo),
];

Widget _app(Widget home, List<Override> overrides, {String lang = 'de'}) => ProviderScope(
  overrides: overrides,
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
);

/// Loads the stream providers, then shows the page.
Future<ProviderContainer> _pump(WidgetTester t, Widget page, List<Override> overrides) async {
  t.view.physicalSize = const Size(420, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(page, overrides));
  await t.pump();
  await t.pump();
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

Iterable<String> _fieldTexts(WidgetTester t) => t.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller!.text);

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  group('switching bodyweight mode', () {
    test('done sets keep their total load, open sets get the new mode\'s load', () {
      final e = ex('0652', 'pull-up', [(80, 8), (80, 8), (80, 8)], bw: false)..sets.first.done = true;
      final volume = e.volume;
      lp(const []).switchBodyweight(e, true);
      expect(e.bw, isTrue);
      expect(e.bodyKg, 80);
      expect(e.sets.map((s) => s.weight), [0, 0, 0]); // done: 80 total → +0; open: prescribed +0
      expect(e.volume, volume);
      lp(const []).switchBodyweight(e, false);
      expect(e.bw, isFalse);
      expect(e.bodyKg, 0);
      expect(e.sets.map((s) => s.weight), [80, 80, 80]); // same total load again
      expect(e.volume, volume);
    });

    test('a small loaded weight stays added load (no −70 kg assistance)', () {
      final e = ex('0652', 'pull-up', [(10, 8)], bw: false)..sets.first.done = true;
      lp(const []).switchBodyweight(e, true);
      expect(e.sets.first.weight, 10);
    });

    test('open sets pick up the prescription from bodyweight history', () {
      final h = [
        gym(3, [
          ex('0652', 'pull-up', [(5, 10), (5, 10), (5, 10)], done: true, bw: true, bodyKg: 80),
        ]),
      ];
      final e = ex('0652', 'pull-up', [(60, 6), (60, 6)], bw: false);
      lp(h).switchBodyweight(e, true);
      expect(e.sets.map((s) => s.weight), [7.5, 7.5]);
      expect(e.sets.map((s) => s.reps), [6, 6]); // reps stay as the user had them
    });

    test('loaded exercises switched to bodyweight count the moving body share', () {
      final squat = ex('9997', 'dumbbell goblet squat', [(0, 10)])..bw = true;
      expect(lp(const []).bodyLoad(squat), 68); // 85 % of 80 kg
      final jump = ex('0514', 'jump squat', [(0, 10)])..bw = true;
      expect(lp(const []).bodyLoad(jump), 0); // bodyweight leg work: progressed by reps
      final legExt = ex('0585', 'lever leg extension', [(0, 10)])..bw = true;
      expect(lp(const []).bodyLoad(legExt), 0); // the body does not move
    });

    test('bodyweight warm-ups get no weight, drop sets more assistance', () {
      final h = [
        gym(3, [
          ex('0652', 'pull-up', [(10, 8), (10, 8)], done: true, bw: true, bodyKg: 80),
        ]),
      ];
      final plan = GymExercise(
        exId: '0652',
        name: 'pull-up',
        repMin: 6,
        repMax: 10,
        sets: [GymSet(type: SetType.warmup), GymSet(reps: 6), GymSet(reps: 6), GymSet(reps: 6, type: SetType.drop)],
      );
      final e = lp(h).apply([plan]).single;
      expect(e.sets.first.weight, 0);
      expect(e.workSets.first.weight, 10);
      expect(e.sets.last.weight, lessThan(10)); // 10 − 20 % of 90 → −10 (assisted)
      expect(e.sets.last.weight, -10);
    });
  });

  group('"last time" in the current mode', () {
    test('legacy pull-ups logged with the body weight show as +0 kg; bodyweight sets as total when loaded', () {
      final legacy = [
        gym(3, [
          ex('0652', 'pull-up', [(80, 8), (80, 7)], done: true),
        ]),
      ];
      final bw = ex('0652', 'pull-up', [(0, 0)], bw: true, bodyKg: 80);
      expect(lp(legacy).previousSets(bw)!.map((s) => s.weight), [0, 0]);
      final h = [
        gym(3, [
          ex('0652', 'pull-up', [(10, 8)], done: true, bw: true, bodyKg: 80),
        ]),
      ];
      expect(lp(h).previousSets(bw)!.single.weight, 10);
      final loaded = ex('0652', 'pull-up', [(0, 0)], bw: false);
      expect(lp(h).previousSets(loaded)!.single.weight, 90);
    });
  });

  group('active workout', () {
    test('finishing the last work set asks for the effort during the rest; drop set in bodyweight mode', () {
      final a = ex('0025', 'barbell bench press', [(60, 8), (60, 8)]);
      final b = ex('0652', 'pull-up', [(0, 8)], bw: true, bodyKg: 80);
      final c = ProviderContainer(
        overrides: [
          activeGymProvider.overrideWith(() => _PresetGym(ActiveGym(title: 't', start: now, exercises: [a, b]))),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(activeGymProvider.notifier);
      n.toggleDone(0, 0);
      expect(c.read(activeGymProvider)!.effortFor, isNull);
      n.toggleDone(0, 1);
      expect(identical(c.read(activeGymProvider)!.effortFor, a), isTrue);
      n.setEffort(0, Effort.hard);
      expect(a.effort, Effort.hard);
      n.skipRest();
      expect(c.read(activeGymProvider)!.effortFor, isNull);
      n.addDropSet(1);
      expect(b.sets.last.weight, -15); // 20 % of 80 kg as assistance (2.5 kg grid)
    });
  });

  group('table view', () {
    testWidgets('toggling bodyweight updates the weight fields and the header', (t) async {
      final prefs = await _prefs();
      final gymState = ActiveGym(
        title: 'Pull',
        start: now,
        exercises: [
          ex('9998', 'pull-up', [(80, 8), (80, 8), (80, 8)], bw: false),
        ],
      );
      final c = await _pump(t, const GymSessionPage(), _overrides(prefs, gym: gymState));
      expect(_fieldTexts(t).where((s) => s == '80'), hasLength(3));
      c.read(activeGymProvider.notifier).setBodyweight(0, true);
      await t.pump();
      expect(_fieldTexts(t).where((s) => s == '80'), isEmpty, reason: 'fields must not keep the old body weight');
      expect(find.text('${de.bodyweightShort} ± kg'), findsOneWidget);
      c.read(activeGymProvider.notifier).setBodyweight(0, false);
      await t.pump();
      expect(_fieldTexts(t).where((s) => s == '80'), hasLength(3));
    });

    testWidgets('a new weight carried over to the next sets shows up in their fields', (t) async {
      final prefs = await _prefs();
      final gymState = ActiveGym(
        title: 'Push',
        start: now,
        exercises: [
          ex('9999', 'barbell bench press', [(60, 8), (60, 8)]),
        ],
      );
      final c = await _pump(t, const GymSessionPage(), _overrides(prefs, gym: gymState));
      c.read(activeGymProvider.notifier).updateSet(0, 0, weight: 62.5);
      await t.pump();
      expect(_fieldTexts(t).where((s) => s == '62.5'), hasLength(2));
    });

    testWidgets('checking a bodyweight set keeps "no added load"; last time is converted', (t) async {
      final prefs = await _prefs();
      final history = [
        gym(3, [
          ex('9998', 'pull-up', [(80, 8), (80, 8)], done: true),
        ]), // logged before bodyweight mode
      ];
      final gymState = ActiveGym(
        title: 'Pull',
        start: now,
        exercises: [
          ex('9998', 'pull-up', [(0, 0), (0, 0)], bw: true, bodyKg: 80),
        ],
      );
      final c = await _pump(t, const GymSessionPage(), _overrides(prefs, gym: gymState, history: history));
      expect(find.text('${de.bodyweightShort} × 8'), findsNWidgets(2));
      await t.tap(find.byIcon(Icons.check_rounded).first);
      await t.pump();
      final s = c.read(activeGymProvider)!.exercises.first.sets.first;
      expect(s.done, isTrue);
      expect(s.reps, 8);
      expect(s.weight, 0, reason: 'the body weight of the old session must not become added load');
      c.read(activeGymProvider.notifier).skipRest();
      await t.pump();
    });

    testWidgets('effort chips appear after the last work set and store the rating', (t) async {
      final prefs = await _prefs();
      final gymState = ActiveGym(
        title: 'Push',
        start: now,
        exercises: [
          ex('9999', 'barbell bench press', [(60, 8), (60, 8)], done: true),
        ],
      );
      final c = await _pump(t, const GymSessionPage(), _overrides(prefs, gym: gymState));
      expect(find.text(de.effortQuestion), findsOneWidget);
      await t.tap(find.text(de.effortHard));
      await t.pump();
      expect(c.read(activeGymProvider)!.exercises.first.effort, Effort.hard);
      // Tapping it again clears the optional rating.
      await t.tap(find.text(de.effortHard));
      await t.pump();
      expect(c.read(activeGymProvider)!.exercises.first.effort, isNull);
    });
  });

  group('optional RPE', () {
    testWidgets('picker: nothing preselected, choose, clear, skip', (t) async {
      int? value;
      var calls = 0;
      await t.pumpWidget(
        _app(
          Scaffold(
            body: StatefulBuilder(
              builder:
                  (context, set) => RpePicker(
                    value: value,
                    onChanged: (v) {
                      calls++;
                      set(() => value = v);
                    },
                  ),
            ),
          ),
          const [],
        ),
      );
      expect(find.text(de.rpeNotSet), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('rpe-7')));
      await t.pump();
      expect(value, 7);
      expect(find.text('RPE 7 – ${de.rpeHard}'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('rpe-clear')));
      await t.pump();
      expect(value, isNull);
      await t.tap(find.text(de.skip));
      await t.pump();
      expect(find.byKey(const ValueKey('rpe-7')), findsNothing);
      await t.tap(find.text(de.rpeRate));
      await t.pump();
      expect(find.byKey(const ValueKey('rpe-7')), findsOneWidget);
      expect(calls, 2);
    });

    for (final sport in [Sport.gym, Sport.run]) {
      testWidgets('summary saves without a rating unless one is chosen (${sport.name})', (t) async {
        final prefs = await _prefs();
        final repo = _FakeRepo();
        final draft = Session(
          id: 'new',
          sport: sport,
          title: 'Workout',
          start: DateTime.now().subtract(const Duration(hours: 1)),
          durationSec: 3000,
          distanceM: sport == Sport.run ? 8000 : 0,
          exercises:
              sport == Sport.gym
                  ? [
                    ex('9999', 'barbell bench press', [(60, 8)], done: true),
                  ]
                  : const [],
        );
        final home = Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: draft))),
                  child: const Text('open'),
                ),
              ),
        );
        await _pump(t, home, _overrides(prefs, repo: repo));
        Future<void> openAndSave({int? rpe}) async {
          await t.tap(find.text('open'));
          await t.pumpAndSettle();
          expect(find.text(de.howHardOptional), findsOneWidget);
          if (rpe != null) {
            await t.ensureVisible(find.byKey(ValueKey('rpe-$rpe')));
            await t.tap(find.byKey(ValueKey('rpe-$rpe')));
            await t.pump();
          }
          await t.ensureVisible(find.text(de.saveWorkout));
          await t.tap(find.text(de.saveWorkout));
          await t.pumpAndSettle();
        }

        await openAndSave();
        expect(repo.saved.single.rpe, isNull);
        await openAndSave(rpe: 8);
        expect(repo.saved.last.rpe, 8);
      });
    }
  });
}
