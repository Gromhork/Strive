import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/services/workout_store.dart';

/// Through real JSON text (what is written to disk).
Map<String, dynamic> viaJson(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

ActiveGym sampleGym() {
  final bench = GymExercise(
    exId: 'bench',
    name: 'Bench press',
    restSec: 120,
    group: 'A',
    repMin: 6,
    repMax: 10,
    rxKg: 80,
    effort: Effort.values.first,
    sets: [
      GymSet(weight: 40, reps: 8, done: true, type: SetType.warmup),
      GymSet(weight: 80, reps: 8, done: true, rpe: 8.5, target: 8),
      GymSet(weight: 80, reps: 7, amrap: true),
    ],
  );
  final pull = GymExercise(exId: 'pullup', name: 'Pull-up', group: 'A', bw: true, bodyKg: 78, sets: [GymSet(weight: -10, reps: 6)]);
  return ActiveGym(
    title: 'Push A',
    templateId: 't1',
    planId: 'p1',
    start: DateTime(2026, 11, 10, 10, 42),
    exercises: [bench, pull],
    restEnd: DateTime(2026, 11, 10, 11, 5, 30),
    restTotal: 120,
    restIsTransition: true,
    focus: 1,
    effortFor: bench,
  );
}

CardioState sampleCardio({List<LatLng>? points}) => CardioState(
  sport: Sport.run,
  title: 'Intervals',
  planId: 'plan7',
  start: DateTime(2026, 11, 10, 7, 30),
  accumulatedSec: 754,
  runningSince: DateTime(2026, 11, 10, 7, 43, 10),
  distanceM: 2512.5,
  elevationM: 31,
  points: points ?? [const LatLng(52.520008, 13.404954), const LatLng(52.5201, 13.4051), const LatLng(52.5203, 13.4054)],
  splits: [301, 295],
  laps: 3,
  steps: const [
    WorkoutStep(kind: 'warmup', durationSec: 600, zone: 'E', paceMin: 330, paceMax: 360),
    WorkoutStep(kind: 'work', distanceM: 400, zone: 'I', paceMin: 240, paceMax: 250, note: 'hard'),
    WorkoutStep(kind: 'recovery', durationSec: 90, zone: 'REC'),
  ],
  stepIndex: 1,
  stepStartSec: 600,
  stepStartDist: 1800,
  paceHistory: [330, 320, 250],
  autoPaused: false,
  voice: false,
  lengthSecs: [30, 31],
  lastLengthAt: 61,
  lengthMarks: const [StepMark(0, 0, 0, false, 0), StepMark(0, 0, 25, false, 30)],
  bestPace: 238,
  lapSecs: [300, 280],
  lapDists: [1000, 1012.5],
  lapStartSec: 580,
  lapStartDist: 2012.5,
  stepResults: const [StepResult(0, 600, 1800, complete: true)],
  paceTime: {330: 400, 250: 60},
);

void main() {
  group('serialization round trip', () {
    test('ActiveGym keeps exercises, sets, rest, focus and the effort prompt', () {
      final g = sampleGym();
      final r = activeGymFromJson(viaJson(activeGymToJson(g)));
      expect(r.title, 'Push A');
      expect(r.templateId, 't1');
      expect(r.planId, 'p1');
      expect(r.start, g.start);
      expect(r.restEnd, g.restEnd);
      expect(r.restTotal, 120);
      expect(r.restIsTransition, isTrue);
      expect(r.focus, 1);
      expect(r.doneSets, g.doneSets);
      expect(r.totalSets, 4);
      expect([for (final e in r.exercises) e.toMap()], [for (final e in g.exercises) e.toMap()]);
      // The effort prompt points at the restored exercise object (by index).
      expect(identical(r.effortFor, r.exercises[0]), isTrue);
      expect(r.exercises[0].sets[1].rpe, 8.5);
      expect(r.exercises[0].sets[2].amrap, isTrue);
      expect(r.exercises[1].bw, isTrue);
    });

    test('CardioState keeps timing, route, laps, splits, steps and their results', () {
      final s = sampleCardio();
      final route = decodeRoute(encodeRoutePoints(s.points));
      final r = cardioFromJson(viaJson(cardioToJson(s)), points: route);
      expect(r.sport, Sport.run);
      expect(r.title, 'Intervals');
      expect(r.planId, 'plan7');
      expect(r.start, s.start);
      expect(r.accumulatedSec, 754);
      expect(r.runningSince, s.runningSince);
      // Elapsed time continues from the timestamps (incl. the time the app was gone).
      expect(r.elapsed, s.elapsed);
      expect(r.distanceM, 2512.5);
      expect(r.elevationM, 31);
      expect(r.points.length, 3);
      expect(r.points.first.latitude, closeTo(52.520008, 1e-6));
      expect(r.points.last.longitude, closeTo(13.4054, 1e-6));
      expect(r.splits, [301, 295]);
      expect(r.laps, 3);
      expect([for (final x in r.steps) x.toMap()], [for (final x in s.steps) x.toMap()]);
      expect(r.stepIndex, 1);
      expect(r.stepStartSec, 600);
      expect(r.stepStartDist, 1800);
      expect(r.step?.kind, 'work');
      expect(r.paceHistory, [330, 320, 250]);
      expect(r.voice, isFalse);
      expect(r.lengthSecs, [30, 31]);
      expect(r.lastLengthAt, 61);
      expect(r.lengthMarks.length, 2);
      expect(r.lengthMarks[1].stepStartDist, 25);
      expect(r.bestPace, 238);
      expect(r.lapSecs, [300, 280]);
      expect(r.lapDists, [1000, 1012.5]);
      expect(r.lapStartSec, 580);
      expect(r.lapStartDist, 2012.5);
      expect(r.stepResults.single.sec, 600);
      expect(r.stepResults.single.complete, isTrue);
      expect(r.paceTime, {330: 400, 250: 60});
    });

    test('a paused recording stays paused', () {
      final s = sampleCardio().copyWith(accumulatedSec: 900, pause: true);
      final r = cardioFromJson(viaJson(cardioToJson(s)));
      expect(r.paused, isTrue);
      expect(r.elapsed, 900);
    });

    test('summary draft keeps the session, rating and notes', () {
      final s = Session(
        id: 's1',
        sport: Sport.ride,
        title: 'Ride',
        start: DateTime(2026, 11, 9, 17),
        durationSec: 3600,
        rpe: 6,
        notes: 'windy',
        distanceM: 30000,
        elevationM: 210,
        route: const [
          [52.5, 13.4],
          [52.6, 13.5],
        ],
        splits: const [120, 118],
        planId: 'p9',
      );
      final r = sessionDraftFromJson(viaJson(sessionDraftToJson(s)));
      expect(r.id, 's1');
      expect(r.sport, Sport.ride);
      expect(r.start, s.start);
      expect(r.rpe, 6);
      expect(r.notes, 'windy');
      expect(r.distanceM, 30000);
      expect(r.route, s.route);
      expect(r.splits, s.splits);
      expect(r.planId, 'p9');
    });

    test('a route line cut off by a crash is skipped', () {
      expect(decodeRoute('52.5,13.4\n52.6,13.5\n52.7,1').length, 3);
      expect(decodeRoute('52.5,13.4\n52.6,13.5\n52.7,').length, 2);
    });
  });

  group('FileWorkoutStore', () {
    late Directory dir;
    late FileWorkoutStore store;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('strive_store');
      store = FileWorkoutStore(() async => dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('cardio: the route file is appended, not rewritten', () async {
      final live = <LatLng>[for (var i = 0; i < 100; i++) LatLng(52 + i / 1e4, 13)];
      await store.saveCardio(sampleCardio(points: live));
      final route = File('${dir.path}/route.txt');
      expect(route.readAsLinesSync().length, 100);
      final before = route.readAsStringSync();
      live.addAll([for (var i = 100; i < 150; i++) LatLng(52 + i / 1e4, 13)]);
      await store.saveCardio(sampleCardio(points: live));
      final after = route.readAsStringSync();
      expect(after.startsWith(before), isTrue);
      expect(route.readAsLinesSync().length, 150);

      final loaded = await FileWorkoutStore(() async => dir).loadActive();
      expect(loaded?.cardio?.points.length, 150);
      expect(loaded?.cardio?.laps, 3);
      expect(loaded?.sport, Sport.run);
    });

    test('a new recording starts a new route file', () async {
      await store.saveCardio(sampleCardio());
      final other = CardioState(sport: Sport.ride, title: 'Ride', start: DateTime(2026, 11, 11), points: const [LatLng(1, 2)]);
      await store.saveCardio(other);
      final loaded = await store.loadActive();
      expect(loaded?.cardio?.points.length, 1);
    });

    test('gym round trip and clear', () async {
      await store.saveGym(sampleGym());
      final loaded = await FileWorkoutStore(() async => dir).loadActive();
      expect(loaded?.gym?.title, 'Push A');
      expect(loaded?.gym?.doneSets, 1);
      await store.clearActive();
      expect(await store.loadActive(), isNull);
    });

    test('summary save / clear', () async {
      final s = Session(id: 'x', sport: Sport.gym, title: 'Gym', start: DateTime(2026, 11, 10), durationSec: 60, notes: 'n');
      await store.saveSummary(s);
      expect((await FileWorkoutStore(() async => dir).loadSummary())?.notes, 'n');
      await store.clearSummary();
      expect(await store.loadSummary(), isNull);
    });

    test('unreadable files are ignored', () async {
      File('${dir.path}/active.json').writeAsStringSync('{broken');
      expect(await store.loadActive(), isNull);
    });
  });

  group('route performance', () {
    test('copyWith shares the route instead of copying it', () {
      final live = <LatLng>[for (var i = 0; i < 5000; i++) LatLng(52, 13 + i / 1e5)];
      final s = sampleCardio(points: live);
      final next = s.copyWith(distanceM: 1, elevationM: 2, accuracy: 3);
      expect(identical(next.points, s.points), isTrue);
      // Appending to the live list is visible without a copy; pointCount tells states apart.
      live.add(const LatLng(53, 14));
      final after = next.copyWith(distanceM: 2);
      expect(identical(after.points, live), isTrue);
      expect(next.pointCount, 5000);
      expect(after.pointCount, 5001);
    });

    test('10 000 fixes stay linear (no full copy per fix)', () {
      final live = <LatLng>[];
      var s = sampleCardio(points: live);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        live.add(LatLng(52 + i / 1e6, 13));
        s = s.copyWith(distanceM: i.toDouble());
      }
      sw.stop();
      expect(s.pointCount, 10000);
      expect(identical(s.points, live), isTrue);
      // A copy per fix would move 50 M elements; sharing is ~instant.
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
