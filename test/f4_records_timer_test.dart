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
import 'package:strive/data/exercise_measure.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/planned_workout_page.dart';
import 'package:strive/features/session/gym_session_page.dart' show exerciseSummary;
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/l10n/gen/app_localizations_de.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/insights.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/workout_alerts.dart';
import 'package:strive/services/workout_store.dart';
import 'package:strive/widgets/prescription.dart';

final now = DateTime(2026, 11, 9, 18);
const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);
const kg = Units(false);
final de = AppLocalizationsDe();

Session gym(String id, int daysAgo, List<GymExercise> ex, {double? bodyWeight}) => Session(
  id: id,
  sport: Sport.gym,
  title: 'Gym',
  start: now.subtract(Duration(days: daysAgo)),
  durationSec: 3600,
  exercises: ex,
  bodyWeightKg: bodyWeight,
);

GymExercise reps(String id, String name, List<(double, int)> sets, {bool? bw, double bodyKg = 0}) =>
    GymExercise(exId: id, name: name, bw: bw, bodyKg: bodyKg, sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: true)]);

GymExercise hold(String id, String name, List<(double, int)> sets) =>
    GymExercise(exId: id, name: name, bw: true, sets: [for (final (w, s) in sets) GymSet(weight: w, sec: s, done: true)]);

GymExercise pushUps(List<int> r) => reps('0662', 'push-up', [for (final x in r) (0, x)], bw: true, bodyKg: 51.2);
GymExercise plank(List<(double, int)> s) => hold('2135', 'weighted front plank', s);

/// Records the timer signals instead of calling the platform.
class _FakeAlerts extends WorkoutAlerts {
  final played = <(AlertSignal, bool, bool)>[];
  @override
  Future<void> play(AlertSignal signal, {required bool sound, required bool vibrate}) async => played.add((signal, sound, vibrate));
  List<AlertSignal> get signals => [for (final p in played) p.$1];
}

class _PresetGym extends ActiveGymNotifier {
  _PresetGym(this.init);
  final ActiveGym init;
  @override
  ActiveGym? build() => init;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // start() / finish() toggle the wake lock – no platform in unit tests.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  // ───────────────────────────── S6: compliance against the program's sets ─────────────────────────────
  group('S6 gym compliance against the program', () {
    List<GymExercise> program() => [
      for (var i = 0; i < 6; i++)
        GymExercise(exId: 'x$i', name: 'exercise $i', sets: [for (var k = 0; k < 3; k++) GymSet(weight: 20, reps: 10)]),
    ];

    ProviderContainer container() {
      final c = ProviderContainer(overrides: [profileProvider.overrideWith((ref) => Stream.value(male80))]);
      addTearDown(c.dispose);
      return c;
    }

    test('removing exercises in the tracker does not make a half workout "as planned"', () async {
      final c = container();
      c.listen(profileOrDefaultProvider, (_, __) {});
      await c.read(profileProvider.future);
      final n = c.read(activeGymProvider.notifier);
      n.start(title: 'Push', planId: 'p', exercises: program());
      expect(c.read(activeGymProvider)!.programSets, 18);
      // Three exercises (9 sets) deleted, the other 9 sets done.
      n.removeExercise(5);
      n.removeExercise(4);
      n.removeExercise(3);
      for (var e = 0; e < 3; e++) {
        for (var k = 0; k < 3; k++) {
          c.read(activeGymProvider)!.exercises[e].sets[k].done = true;
        }
      }
      expect(c.read(activeGymProvider)!.plannedWorkSets, 18);
      final s = n.finish('s');
      expect(s.plannedSets, 18);
      final p = PlannedWorkout(id: 'p', date: now, sport: Sport.gym, title: 'Push', durationMin: 60, templateId: 't');
      final r = complianceRatio(p, s)!;
      expect(r, closeTo(0.5, 1e-9));
      expect(complianceLevelOf(r), isNot(ComplianceLevel.green));
    });

    test('sets added in the tracker raise the reference; a free workout compares with its own sets', () async {
      final c = container();
      c.listen(profileOrDefaultProvider, (_, __) {});
      await c.read(profileProvider.future);
      final n = c.read(activeGymProvider.notifier);
      n.start(title: 'Push', planId: 'p', exercises: program());
      n.addSet(0);
      n.addSet(0);
      expect(c.read(activeGymProvider)!.plannedWorkSets, 20);
      n.discard();
      n.start(title: 'Free', exercises: program());
      expect(c.read(activeGymProvider)!.programSets, isNull);
      n.removeExercise(0);
      expect(c.read(activeGymProvider)!.plannedWorkSets, 15);
      n.discard();
    });

    test('a program started from the Train tab keeps its sets as the reference', () async {
      final c = container();
      c.listen(profileOrDefaultProvider, (_, __) {});
      await c.read(profileProvider.future);
      final n = c.read(activeGymProvider.notifier);
      n.start(title: 'Push', templateId: 't', exercises: program());
      expect(c.read(activeGymProvider)!.programSets, 18);
      n.removeExercise(5);
      n.removeExercise(4);
      n.removeExercise(3);
      for (var e = 0; e < 3; e++) {
        for (var k = 0; k < 3; k++) {
          c.read(activeGymProvider)!.exercises[e].sets[k].done = true;
        }
      }
      final s = n.finish('s');
      expect(s.plannedSets, 18);
      // Auto-linked to the day's planned workout of the same program on saving (matchPlan).
      final p = PlannedWorkout(id: 'p', date: now, sport: Sport.gym, title: 'Push', durationMin: 60, templateId: 't');
      final t = WorkoutTemplate(id: 't', name: 'Push', sport: Sport.gym, exercises: program());
      final linked = Session.fromMap(s.id, {...s.toMap(), 'plannedSets': linkedPlannedSets(s, p, t)});
      expect(linked.plannedSets, 18);
      expect(complianceRatio(p, linked), closeTo(0.5, 1e-9));
      expect(complianceLevelOf(complianceRatio(p, linked)!), isNot(ComplianceLevel.green));
    });

    test('linked on saving: the planned workout sets are the reference', () {
      final p = PlannedWorkout(id: 'p', date: now, sport: Sport.gym, title: 'Push', durationMin: 60, templateId: 't');
      final t = WorkoutTemplate(id: 't', name: 'Push', sport: Sport.gym, exercises: program());
      Session done(int exercises, {int? plannedSets, String? planId, String? templateId, bool fromPlan = false}) => Session(
        id: 's',
        sport: Sport.gym,
        title: 'Gym',
        start: now,
        durationSec: 3600,
        exercises: [
          for (var i = 0; i < exercises; i++)
            GymExercise(exId: 'x$i', name: 'exercise $i', sets: [for (var k = 0; k < 3; k++) GymSet(weight: 20, reps: 10, done: true)]),
        ],
        plannedSets: plannedSets,
        planId: planId,
        templateId: templateId,
        fromPlan: fromPlan,
      );
      // A free workout of 9 sets on the plan's day: 9 of the plan's 18 sets.
      expect(linkedPlannedSets(done(3, plannedSets: 9), p, t), 18);
      // More sets than planned: the session's own sets.
      expect(linkedPlannedSets(done(7, plannedSets: 21), p, t), 21);
      // Started from this planned workout: its stored reference already is the plan's.
      expect(linkedPlannedSets(done(3, plannedSets: 20, planId: 'p'), p, t), 20);
      // Taken over from the plan / program unknown: unchanged.
      expect(linkedPlannedSets(done(3, plannedSets: 9, fromPlan: true), p, t), 9);
      expect(linkedPlannedSets(done(3, plannedSets: 9), p, null), 9);
      // The planned workout's own (day-adjusted) exercises beat the program.
      final own = PlannedWorkout(
        id: 'q',
        date: now,
        sport: Sport.gym,
        title: 'Push',
        durationMin: 45,
        templateId: 't',
        exercises: program().take(4).toList(),
      );
      expect(linkedPlannedSets(done(4, plannedSets: 18, templateId: 't'), own, t), 12);
    });

    test('"no legs" day: the full program started from the Train tab is not judged against the full program', () {
      GymExercise ex(String id, String name) =>
          GymExercise(exId: id, name: name, sets: [for (var k = 0; k < 3; k++) GymSet(weight: 40, reps: 8)]);
      final full = [
        ex('a', 'barbell bench press'),
        ex('b', 'barbell bent over row'),
        ex('c', 'barbell full squat'),
        ex('d', 'lever leg extension'),
      ];
      final t = WorkoutTemplate(id: 't', name: 'Full', sport: Sport.gym, exercises: full);
      final p = PlannedWorkout(
        id: 'p',
        date: now,
        sport: Sport.gym,
        title: 'Full',
        durationMin: 60,
        templateId: 't',
        gymMods: const [gymModNoLegs],
      );
      expect(gymModApplies(gymModNoLegs, full), isTrue);
      // Leg exercises deleted, upper body done: as planned (6 of the day's 6 sets).
      final upper = [
        for (final e in full.take(2))
          GymExercise(exId: e.exId, name: e.name, sets: [for (final x in e.sets) GymSet(weight: x.weight, reps: x.reps, done: true)]),
      ];
      final s = Session(
        id: 's',
        sport: Sport.gym,
        title: 'Full',
        start: now,
        durationSec: 3600,
        exercises: upper,
        templateId: 't',
        plannedSets: 12,
      );
      final sets = linkedPlannedSets(s, p, t);
      expect(sets, 6);
      expect(complianceRatio(p, Session.fromMap('s', {...s.toMap(), 'plannedSets': sets})), closeTo(1, 1e-9));
    });

    test('no stored reference: the session own sets, not the duration (mostly rest)', () {
      final p = PlannedWorkout(id: 'p', date: now, sport: Sport.gym, title: 'Push', durationMin: 60, templateId: 't');
      final s = Session(
        id: 's',
        sport: Sport.gym,
        title: 'Gym',
        start: now,
        durationSec: 3600,
        exercises: [
          GymExercise(exId: 'x0', name: 'exercise 0', sets: [for (var k = 0; k < 6; k++) GymSet(weight: 20, reps: 10, done: k < 2)]),
        ],
      );
      expect(plannedGymSets(p, s), 6);
      expect(complianceRatio(p, s), closeTo(2 / 6, 1e-9));
      // Without set data (imported / summary-only): the duration.
      final imported = Session(id: 'i', sport: Sport.gym, title: 'Gym', start: now, durationSec: 3600);
      expect(plannedGymSets(p, imported), 0);
      expect(complianceRatio(p, imported), closeTo(1, 1e-9));
    });

    test('the program set count survives the app being killed (restore)', () {
      final g = ActiveGym(title: 'Push', planId: 'p', start: now, exercises: program().take(2).toList(), programSets: 18);
      final back = activeGymFromJson(activeGymToJson(g));
      expect(back.programSets, 18);
      expect(back.plannedWorkSets, 18);
      expect(activeGymFromJson({...activeGymToJson(g)}..remove('programSets')).programSets, isNull, reason: 'older drafts');
    });
  });

  // ───────────────────────────── R6 / S7 / R7-13b: one record rule ─────────────────────────────
  group('R6/S7 records: most reps, weighted holds, one rule for summary and records', () {
    test('push-ups: more reps is a PR in the summary (no e1RM for partial bodyweight)', () {
      final h1 = gym('a', 7, [
        pushUps([10, 10, 10]),
      ], bodyWeight: 80);
      final cur = gym('b', 0, [
        pushUps([15, 15, 12]),
      ], bodyWeight: 80);
      expect(recordE1rm(cur.exercises.single), 0);
      expect(newPrs(cur, [h1]), ['push-up']);
      final rec = exerciseRecords([cur, h1])['0662']!;
      expect(rec.bodyReps, 15);
      expect(rec.date, cur.start, reason: 'the records list dates the same session');
      // Fewer reps than the best: no PR, the record date stays.
      final worse = gym('c', -1, [
        pushUps([12, 12]),
      ], bodyWeight: 80);
      expect(newPrs(worse, [cur, h1]), isEmpty);
      expect(exerciseRecords([worse, cur, h1])['0662']!.date, cur.start);
    });

    test('squats / sit-ups logged without bodyweight mode: reps record too', () {
      final h = gym('a', 7, [
        reps('sq', 'bodyweight squat', [(0, 20)]),
      ]);
      final cur = gym('b', 0, [
        reps('sq', 'bodyweight squat', [(0, 25)]),
      ]);
      expect(newPrs(cur, [h]), ['bodyweight squat']);
    });

    test('a loaded lift still needs a higher e1RM', () {
      final h = gym('a', 7, [
        reps('b', 'barbell bench press', [(100, 5)]),
      ]);
      expect(
        newPrs(
          gym('b', 0, [
            reps('b', 'barbell bench press', [(80, 8)]),
          ]),
          [h],
        ),
        isEmpty,
      );
      expect(
        newPrs(
          gym('c', 0, [
            reps('b', 'barbell bench press', [(100, 7)]),
          ]),
          [h],
        ),
        ['barbell bench press'],
      );
    });

    test('holds: a heavier load held is progress even when shorter', () {
      final h = gym('a', 7, [
        plank([(0, 60)]),
      ]);
      final loaded = gym('b', 3, [
        plank([(2.5, 30)]),
      ]);
      expect(newPrs(loaded, [h]), ['weighted front plank']);
      final rec = exerciseRecords([loaded, h])['2135']!;
      expect((rec.holdKg, rec.holdAtKg, rec.longestHold), (2.5, 30, 60));
      expect(rec.date, loaded.start);
      // Same load, shorter: none. Same load, longer: PR. Lighter and not the longest: none.
      expect(
        newPrs(
          gym('c', 0, [
            plank([(2.5, 25)]),
          ]),
          [loaded, h],
        ),
        isEmpty,
      );
      expect(
        newPrs(
          gym('d', 0, [
            plank([(2.5, 35)]),
          ]),
          [loaded, h],
        ),
        ['weighted front plank'],
      );
      expect(
        newPrs(
          gym('e', 0, [
            plank([(0, 50)]),
          ]),
          [loaded, h],
        ),
        isEmpty,
      );
      expect(
        newPrs(
          gym('f', 0, [
            plank([(0, 70)]),
          ]),
          [loaded, h],
        ),
        ['weighted front plank'],
        reason: 'the longest hold ever',
      );
    });

    test('summary PRs and the records list agree on every session of a history', () {
      final hist = <Session>[
        gym('1', 20, [
          pushUps([8, 8]),
          plank([(0, 40)]),
          reps('b', 'barbell bench press', [(60, 8)]),
        ]),
        gym('2', 15, [
          pushUps([10, 9]),
          plank([(0, 35)]),
          reps('b', 'barbell bench press', [(62.5, 8)]),
        ]),
        gym('3', 10, [
          pushUps([9, 9]),
          plank([(2.5, 20)]),
          reps('b', 'barbell bench press', [(60, 6)]),
        ]),
        gym('4', 5, [
          pushUps([12]),
          plank([(2.5, 25)]),
          reps('b', 'barbell bench press', [(65, 8)]),
        ]),
      ];
      for (var i = 0; i < hist.length; i++) {
        final cur = hist[i];
        final before = hist.take(i).toList().reversed.toList();
        final prs = newPrs(cur, before);
        final recs = exerciseRecords([cur, ...before]);
        for (final e in cur.exercises) {
          expect(prs.contains(e.name), recs[e.exId]!.date == cur.start, reason: 'session ${cur.id}: ${e.name}');
        }
      }
    });
  });

  // ───────────────────────────── R7: XP / badges stable ─────────────────────────────
  group('R7 XP and badges from the stored volume', () {
    Session stored(double? volume) => Session.fromMap('x', {
      'sport': 'gym',
      'title': 'Calisthenics',
      'start': now.subtract(const Duration(days: 300)),
      'durationSec': 3600,
      'exercises': [
        reps('0662', 'push-up', [(0, 20), (0, 20), (0, 20)]).toMap(),
      ],
      if (volume != null) 'volume': volume,
    });

    test('a body weight filled in later does not move XP or the volume badge', () {
      final s = stored(0);
      expect(s.storedVolume, 0);
      final at70 = s.withBodyWeight(70), at95 = s.withBodyWeight(95);
      expect(at70.volume, greaterThan(0), reason: 'the display counts the body load');
      expect(at95.volume, greaterThan(at70.volume));
      expect(at70.storedVolume, 0, reason: 'withBodyWeight keeps the stored volume');
      expect(xpForSession(at70), xpForSession(s));
      expect(xpForSession(at95), xpForSession(s));
      final badges = GameStats.compute([at95], 3).badges;
      expect(badges.firstWhere((b) => b.def.id == 'ton').progress, 0);
    });

    test('a session not saved yet (summary) uses its volume', () {
      final s = gym('n', 0, [
        pushUps([20, 20]),
      ], bodyWeight: 80);
      expect(s.storedVolume, isNull);
      expect(s.xpVolume, s.volume);
      expect(Session.fromMap('n', s.toMap()).storedVolume, closeTo(s.volume, 1e-9));
    });
  });

  // ───────────────────────────── S8: volume consistent with loaded variants ─────────────────────────────
  group('S8 body load in the volume only where the loaded variant has none', () {
    test('squats / lunges / calf raises / bridges / sit-ups: only the added load', () {
      for (final name in ['bodyweight squat', 'walking lunge', 'calf raise', 'glute bridge', 'sit-up', 'pistol squat', 'step-up']) {
        expect(volumeBodyShareOf('t', name), 0, reason: name);
        final e = reps('t', name, [(0, 20), (0, 20), (0, 20)], bw: true, bodyKg: 56);
        expect(gym('s', 0, [e], bodyWeight: 80).volume, 0, reason: name);
        expect(e.countsBodyAt(80), isFalse);
      }
      final vest = reps('t', 'bodyweight squat', [(10, 12)], bw: true, bodyKg: 56);
      expect(vest.volumeAt(80), 120, reason: 'the vest counts, like the goblet squat its dumbbell');
      expect(
        gym('g', 0, [
          reps('g', 'dumbbell goblet squat', [(20, 12)]),
        ]).volume,
        240,
      );
    });

    test('push-ups, pull-ups, dips, inverted rows and Nordic curls keep their body load', () {
      expect(volumeBodyShareOf('0662', 'push-up'), closeTo(0.64, 1e-9));
      expect(volumeBodyShareOf('p', 'pull-up'), 1);
      expect(volumeBodyShareOf('d', 'chest dip'), 1);
      expect(volumeBodyShareOf('r', 'inverted row'), closeTo(0.6, 1e-9));
      expect(volumeBodyShareOf('n', 'nordic hamstring curl'), closeTo(0.6, 1e-9));
      expect(
        gym('s', 0, [
          reps('p', 'pull-up', [(0, 10)]),
        ], bodyWeight: 80).volume,
        800,
      );
      // The load prescription keeps the squat's body share (e1RM, progression).
      expect(bodyShareOf('t', 'bodyweight squat'), closeTo(0.7, 1e-9));
    });
  });

  // ───────────────────────────── R7-6: hold timer end signal ─────────────────────────────
  group('R7-6 hold timer: lead-in, countdown pips and an end signal', () {
    GymExercise plankOpen(int sec) =>
        GymExercise(exId: '2135', name: 'weighted front plank', restSec: 60, sets: [GymSet(sec: sec, targetSec: sec), GymSet(sec: sec)]);

    Future<(ProviderContainer, _FakeAlerts)> setup(ActiveGym g, {Map<String, Object> prefs = const {}}) async {
      SharedPreferences.setMockInitialValues(prefs);
      final p = await SharedPreferences.getInstance();
      final alerts = _FakeAlerts();
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(p),
          workoutAlertsProvider.overrideWithValue(alerts),
          activeGymProvider.overrideWith(() => _PresetGym(g)),
        ],
      );
      addTearDown(c.dispose);
      return (c, alerts);
    }

    testWidgets('3-2-1 lead-in, go, pips in the last 3 s, end beep + vibration; the set is checked off', (t) async {
      final e = plankOpen(5);
      final (c, alerts) = await setup(ActiveGym(title: 't', start: now, exercises: [e]));
      final n = c.read(activeGymProvider.notifier);
      n.startHold(0, 0);
      expect(c.read(activeGymProvider)!.holdLeadInLeft(), 3);
      expect(c.read(activeGymProvider)!.holdElapsed(), 0);
      await t.pump(const Duration(seconds: 3, milliseconds: 500));
      expect(alerts.signals, [AlertSignal.tick, AlertSignal.tick, AlertSignal.tick, AlertSignal.go]);
      expect(e.sets.first.done, isFalse);
      await t.pump(const Duration(seconds: 5));
      expect(alerts.signals, [
        AlertSignal.tick, AlertSignal.tick, AlertSignal.tick, AlertSignal.go, //
        AlertSignal.tick, AlertSignal.tick, AlertSignal.tick, AlertSignal.end,
      ]);
      expect(alerts.played.last, (AlertSignal.end, true, true), reason: 'sound and vibration by default');
      expect(e.sets.first.done, isTrue);
      expect(e.sets.first.sec, 5);
      n.skipRest();
    });

    testWidgets('without lead-in the hold runs at once; vibration off → the end still beeps', (t) async {
      final e = plankOpen(4);
      final (c, alerts) = await setup(
        ActiveGym(title: 't', start: now, exercises: [e]),
        prefs: {ActiveGymNotifier.holdLeadInKey: false, 'vibrate': false},
      );
      c.read(activeGymProvider.notifier).startHold(0, 0);
      expect(c.read(activeGymProvider)!.holdLeadInLeft(), 0);
      await t.pump(const Duration(seconds: 5));
      expect(alerts.signals, [AlertSignal.tick, AlertSignal.tick, AlertSignal.tick, AlertSignal.end]);
      expect(alerts.played.last, (AlertSignal.end, true, false));
      c.read(activeGymProvider.notifier).skipRest();
    });

    testWidgets('stop during the lead-in cancels; checking off during it logs the planned time', (t) async {
      final e = plankOpen(30);
      final (c, alerts) = await setup(ActiveGym(title: 't', start: now, exercises: [e]));
      final n = c.read(activeGymProvider.notifier);
      n.startHold(0, 0);
      await t.pump(const Duration(seconds: 1));
      n.stopHold();
      expect(c.read(activeGymProvider)!.holdStart, isNull);
      expect(e.sets.first.done, isFalse);
      n.startHold(0, 0);
      await t.pump(const Duration(seconds: 1));
      n.toggleDone(0, 0);
      expect(e.sets.first.done, isTrue);
      expect(e.sets.first.sec, 30);
      n.skipRest();
      final before = alerts.signals.length;
      await t.pump(const Duration(seconds: 40));
      expect(alerts.signals.length, before, reason: 'no pips or end signal after the hold was cancelled');
    });

    testWidgets('the end of a rest plays the same end signal', (t) async {
      final (c, alerts) = await setup(ActiveGym(title: 't', start: now, exercises: [plankOpen(30)]));
      c.read(activeGymProvider.notifier).startRest(10);
      await t.pump(const Duration(seconds: 11));
      expect(alerts.signals, [AlertSignal.end]);
    });

    test('platform call: an alarm-usage vibration pattern and a tone (MainActivity "alert")', () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('com.gromhork.strive/app');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
        calls.add(c);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      const a = WorkoutAlerts();
      await a.play(AlertSignal.end, sound: true, vibrate: true);
      await a.play(AlertSignal.tick, sound: true, vibrate: false);
      await a.play(AlertSignal.pulse, sound: true, vibrate: true);
      await a.play(AlertSignal.end, sound: false, vibrate: false);
      expect(calls.map((c) => c.method), ['alert', 'alert', 'alert']);
      expect(calls[0].arguments, {'tone': 'end', 'vibrate': WorkoutAlerts.patternOf(AlertSignal.end)});
      expect(calls[1].arguments, {'tone': 'tick', 'vibrate': null});
      expect(calls[2].arguments, {'tone': null, 'vibrate': WorkoutAlerts.patternOf(AlertSignal.pulse)}, reason: 'km pulses: no beep');
    });
  });

  // ───────────────────────────── R7-13: display consistency ─────────────────────────────
  group('R7-13 timed / superset display', () {
    test('unilateral holds are "per side"', () {
      for (final n in [
        'side plank',
        'bodyweight incline side plank',
        'side bridge v. 2',
        'Seitstütz',
        'copenhagen plank',
        'single arm dead hang',
      ]) {
        expect(holdPerSide(n), isTrue, reason: n);
      }
      for (final n in ['front plank', 'weighted front plank', 'wall sit', 'dead hang', 'hollow hold']) {
        expect(holdPerSide(n), isFalse, reason: n);
      }
      final side = GymExercise(exId: '0705', name: 'side bridge v. 2', sets: [GymSet(sec: 20), GymSet(sec: 20), GymSet(sec: 20)]);
      expect(exerciseSummary(de, side, kg, range: side.holdRange), '3 × 20 s ${de.perSide}');
      final front = GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet(sec: 30)]);
      expect(exerciseSummary(de, front, kg, range: front.holdRange), '1 × 30 s');
      const rx = Prescription(weight: 0, reps: 20, source: LoadSource.bodyweight, timed: true);
      expect(prescriptionToday(de, rx, kg, sets: 3, perSide: true), contains('3 × 20 s ${de.perSide}'));
    });

    testWidgets('planned workout page shows the superset like the program and the workout', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final template = WorkoutTemplate(
        id: 't',
        name: 'Push',
        sport: Sport.gym,
        exercises: [
          GymExercise(exId: '0025', name: 'barbell bench press', sets: [GymSet(reps: 8)]),
          GymExercise(exId: '0662', name: 'push-up', group: 'A', sets: [GymSet(reps: 10)]),
          GymExercise(exId: '0405', name: 'dumbbell lateral raise', group: 'A', sets: [GymSet(reps: 12)]),
        ],
      );
      final p = PlannedWorkout(
        id: 'p',
        date: now.add(const Duration(days: 1)),
        sport: Sport.gym,
        title: 'Push',
        durationMin: 45,
        templateId: 't',
      );
      final o = <Override>[
        prefsProvider.overrideWithValue(prefs),
        profileProvider.overrideWith((ref) => Stream.value(male80)),
        sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
        templatesProvider.overrideWith((ref) => Stream.value([template])),
        plansProvider.overrideWith((ref) => Stream.value([p])),
        bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
      ];
      t.view.physicalSize = const Size(420, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: o,
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
            home: const PlannedWorkoutPage(planId: 'p'),
          ),
        ),
      );
      await t.pumpAndSettle();
      // One frame with header and rail around exactly the two members (not just a letter prefix).
      final group = find.byKey(const ValueKey('supersetGroup-A'));
      expect(group, findsOneWidget);
      expect(find.text('${de.superset} A · 2 ${de.exercises}'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      expect(find.descendant(of: group, matching: find.byType(ListTile)), findsNWidgets(2));
      expect(find.descendant(of: group, matching: find.byKey(const ValueKey('plannedExercise-0'))), findsNothing);
      expect(find.textContaining('A · push'), findsNothing);
      expect(find.textContaining('A · Liege'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
