import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/builtin_upgrade.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/gym_tools.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/smart_progression.dart';
import 'package:strive/services/supersets.dart';

final now = DateTime(2026, 11, 9, 18);
var _id = 0;

Session gym(int daysAgo, List<GymExercise> ex) => Session(
  id: 's${_id++}',
  sport: Sport.gym,
  title: 'Gym',
  start: now.subtract(Duration(days: daysAgo)),
  durationSec: 3600,
  exercises: ex,
);

GymExercise done(String id, String name, List<(double, int)> sets, {double? rpe}) =>
    GymExercise(exId: id, name: name, sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: true, rpe: rpe)]);

GymExercise planned(String id, String name, {int sets = 3, int? lo, int? hi}) =>
    GymExercise(exId: id, name: name, repMin: lo, repMax: hi, sets: [for (var i = 0; i < sets; i++) GymSet(reps: lo ?? 0)]);

const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);

LoadPrescriber lp(List<Session> h, [UserProfile p = male80]) => LoadPrescriber(history: h, profile: p, now: now);

List<GymSet> sets(List<(double, int)> s, {double? rpe}) => [for (final (w, r) in s) GymSet(weight: w, reps: r, done: true, rpe: rpe)];

Exercise ex(String id, String name, String equipment, String bodyPart, String target) =>
    Exercise(id: id, name: name, bodyPart: bodyPart, equipment: equipment, target: target, secondary: const [], instructions: const []);

LiftProfile c(String name, [String id = '9999']) => classifyLift(id, name);

void main() {
  group('exercise classification', () {
    test('main lifts, compounds, isolation, small muscles', () {
      expect(c('barbell full squat').cls, LiftClass.main);
      expect(c('barbell bench press').cls, LiftClass.main);
      expect(c('barbell deadlift').cls, LiftClass.main);
      expect(c('barbell standing military press').cls, LiftClass.main);
      expect(c('barbell romanian deadlift').cls, LiftClass.heavy);
      expect(c('barbell bent over row').cls, LiftClass.heavy);
      expect(c('barbell incline bench press').cls, LiftClass.heavy);
      expect(c('barbell front squat').cls, LiftClass.heavy);
      expect(c('dumbbell incline bench press').cls, LiftClass.compound);
      expect(c('cable lat pulldown full range of motion').move, Movement.verticalPull);
      expect(c('sled 45° leg press').move, Movement.squat);
      expect(c('barbell curl').cls, LiftClass.isolation);
      expect(c('cable triceps pushdown (v-bar)').move, Movement.elbowExtension);
      expect(c('lever leg extension').move, Movement.kneeExtension);
      expect(c('lever lying leg curl').move, Movement.kneeFlexion);
      expect(c('dumbbell lateral raise').cls, LiftClass.small);
      expect(c('dumbbell rear fly').move, Movement.rearDelt);
      expect(c('cable standing fly').move, Movement.chestFly);
      expect(c('lever standing calf raise').cls, LiftClass.small);
      expect(c('hanging leg raise').cls, LiftClass.core);
    });

    test('bodyweight exercises and lifted body share', () {
      final pu = c('pull-up');
      expect(pu.bodyweight, isTrue);
      expect(pu.loadableBodyweight, isTrue);
      expect(pu.bodyFraction, 1);
      expect(c('chin-up').loadableBodyweight, isTrue);
      expect(c('triceps dip').bodyFraction, 1);
      expect(c('bench dip (knees bent)').bodyFraction, 0.5);
      expect(c('push-up').bodyFraction, closeTo(0.65, 1e-9));
      expect(c('push-up').loadableBodyweight, isFalse);
      expect(c('inverted row').bodyFraction, 0.6);
      expect(c('walking lunge').bodyweight, isTrue);
      expect(c('walking lunge').bodyFraction, 0);
      expect(c('cable lat pulldown').bodyweight, isFalse);
      // Library metadata wins over the name.
      final assisted = classifyLift('x', 'x', info: ex('x', 'assisted pull-up', 'leverage machine', 'back', 'lats'));
      expect(assisted.move, Movement.verticalPull);
    });

    test('rep ranges by class and goal', () {
      expect(repRangeFor(c('barbell full squat'), 'strength'), (3, 6));
      expect(repRangeFor(c('barbell full squat'), 'general'), (5, 8));
      expect(repRangeFor(c('barbell full squat'), 'hypertrophy'), (6, 10));
      expect(repRangeFor(c('barbell deadlift'), 'general'), (4, 6));
      expect(repRangeFor(c('dumbbell bench press'), 'hypertrophy'), (8, 12));
      expect(repRangeFor(c('dumbbell bench press'), 'strength'), (6, 10));
      expect(repRangeFor(c('barbell curl'), 'general'), (10, 15));
      expect(repRangeFor(c('dumbbell lateral raise'), 'general'), (12, 20));
      expect(repRangeFor(c('dumbbell lateral raise'), 'strength'), (10, 15));
      expect(repRangeFor(c('pull-up'), 'strength'), (4, 8));
      expect(repRangeFor(c('push-up'), 'general'), (8, 15));
      // Explicit range wins; a lone repMin keeps a sensible top.
      expect(repRangeOf(planned('0025', 'barbell bench press', lo: 6, hi: 10), 'strength'), (6, 10));
      expect(repRangeOf(planned('0025', 'barbell bench press'), 'strength'), (3, 6));
      expect(repRangeOf(GymExercise(exId: '0334', name: 'dumbbell lateral raise', repMin: 25), 'general'), (25, 29));
    });

    test('superset pairing: antagonists yes, same muscle / main + non-antagonist no', () {
      expect(goodSupersetPair(c('dumbbell bench press'), c('cable seated row')), isTrue);
      expect(goodSupersetPair(c('barbell bench press'), c('barbell bent over row')), isTrue); // main + antagonist
      expect(goodSupersetPair(c('dumbbell seated shoulder press'), c('pull-up')), isTrue);
      expect(goodSupersetPair(c('barbell curl'), c('cable triceps pushdown (v-bar)')), isTrue);
      expect(goodSupersetPair(c('lever leg extension'), c('lever lying leg curl')), isTrue);
      expect(goodSupersetPair(c('lever standing calf raise'), c('hanging leg raise')), isTrue); // non-competing
      expect(goodSupersetPair(c('barbell curl'), c('dumbbell hammer curl')), isFalse);
      expect(goodSupersetPair(c('barbell bench press'), c('dumbbell incline bench press')), isFalse);
      expect(goodSupersetPair(c('barbell full squat'), c('barbell deadlift')), isFalse);
      expect(goodSupersetPair(c('barbell full squat'), c('cable seated row')), isFalse); // main lift, no antagonist
      expect(goodSupersetPair(c('pull-up'), c('barbell bent over row')), isFalse); // both back
      expect(goodSupersetPair(c('dumbbell bench press'), c('triceps dip')), isFalse); // same muscles
    });
  });

  group('load increments', () {
    Exercise e(String n, String eq, [String bp = 'chest']) => ex('x', n, eq, bp, '');
    test('smallest sensible step per exercise', () {
      expect(loadIncrement(e('barbell full squat', 'barbell', 'upper legs')), 5);
      expect(loadIncrement(e('barbell deadlift', 'barbell', 'upper legs')), 5);
      expect(loadIncrement(e('barbell bench press', 'barbell')), 2.5);
      expect(loadIncrement(e('barbell curl', 'barbell', 'upper arms')), 2.5);
      expect(loadIncrement(e('dumbbell lateral raise', 'dumbbell', 'shoulders'), weight: 8), 1);
      expect(loadIncrement(e('dumbbell bench press', 'dumbbell'), weight: 24), 2);
      expect(loadIncrement(e('sled 45° leg press', 'sled machine', 'upper legs')), 5);
      expect(loadIncrement(e('lever leg extension', 'leverage machine', 'upper legs')), 2.5);
      expect(loadIncrement(e('cable triceps pushdown', 'cable', 'upper arms')), 2.5);
      expect(loadIncrement(e('pull-up', 'body weight', 'back')), 2.5);
      expect(loadIncrement(e('push-up', 'body weight')), 0);
      expect(loadIncrement(e('walking lunge', 'body weight', 'upper legs')), 0);
    });
  });

  group('double progression rule', () {
    Progression? prog(List<(double, int)> s, {int lo = 8, int hi = 12, double inc = 2.5, double? rpe}) =>
        suggestProgression(sets(s, rpe: rpe), bottom: lo, top: hi, increment: inc);

    test('adds reps set by set inside the range', () {
      final p = prog([(60, 8), (60, 8), (60, 8)])!;
      expect(p.kind, ProgressionKind.addReps);
      expect(p.weight, 60);
      expect(p.setReps, [9, 9, 9]);
      final q = prog([(60, 12), (60, 11), (60, 9)])!;
      expect(q.setReps, [12, 12, 10]); // capped at the top
      expect(q.reps, 10);
    });

    test('top of the range on all sets → more weight, back to the bottom', () {
      final p = prog([(60, 12), (60, 12), (60, 12)])!;
      expect(p.kind, ProgressionKind.increase);
      expect(p.weight, 62.5);
      expect(p.reps, 8);
      // Only some sets at the top: keep going.
      expect(prog([(60, 12), (60, 12), (60, 11)])!.kind, ProgressionKind.addReps);
    });

    test('top reached but at failure (RPE 10) → hold the weight once more', () {
      final p = prog([(60, 12), (60, 12), (60, 12)], rpe: 10)!;
      expect(p.kind, ProgressionKind.hold);
      expect(p.weight, 60);
    });

    test('reps clearly missed: keep (1 short), one step back (2–3 short), ~10 % (more)', () {
      final close = prog([(62.5, 7), (62.5, 7), (62.5, 6)])!;
      expect(close.kind, ProgressionKind.hold);
      expect(close.weight, 62.5);
      expect(close.reps, 8);
      final mid = prog([(62.5, 6), (62.5, 5), (62.5, 5)])!;
      expect(mid.kind, ProgressionKind.deload);
      expect(mid.weight, 60); // back one step
      final far = prog([(62.5, 3), (62.5, 3), (62.5, 2)])!;
      expect(far.weight, closeTo(56.25, 1e-9));
      // One bad set out of three does not count as missed.
      expect(prog([(60, 9), (60, 8), (60, 5)])!.kind, ProgressionKind.addReps);
    });

    test('no load step (push-ups): reps keep growing beyond the range', () {
      final p = prog([(0, 15), (0, 15), (0, 16)], lo: 8, hi: 15, inc: 0)!;
      expect(p.kind, ProgressionKind.addReps);
      expect(p.reps, 16);
      expect(p.setReps, [16, 16, 17]);
    });

    test('warm-ups, drop sets and undone sets are ignored', () {
      final s = [
        GymSet(weight: 20, reps: 12, done: true, type: SetType.warmup),
        ...sets([(60, 12), (60, 12)]),
        GymSet(weight: 45, reps: 6, done: true, type: SetType.drop),
        GymSet(weight: 60, reps: 0),
      ];
      expect(suggestProgression(s, bottom: 8, top: 12, increment: 2.5)!.kind, ProgressionKind.increase);
      expect(suggestProgression(const [], bottom: 8, top: 12, increment: 2.5), isNull);
    });
  });

  group('prescriber: double progression over several sessions', () {
    test('8 → 12 reps, then +2.5 kg and back to 8 (cable row, 8–12)', () {
      final row = planned('0861', 'cable seated row', lo: 8, hi: 12);
      final history = <Session>[];
      var w = 50.0;
      var reps = [8, 8, 8];
      final log = <String>[];
      for (var day = 30; day >= 2; day -= 4) {
        history.insert(
          0,
          gym(day, [
            done('0861', 'cable seated row', [for (final r in reps) (w, r)]),
          ]),
        );
        final p = LoadPrescriber(history: history, profile: male80, now: now.subtract(Duration(days: day - 2))).forExercise(row)!;
        log.add('${p.weight}×${p.setReps.isEmpty ? p.reps : p.setReps.join('/')}');
        // The lifter does exactly what is prescribed.
        w = p.weight;
        reps = [for (var k = 0; k < 3; k++) p.repsForSet(k)];
      }
      expect(log, [
        '50.0×9/9/9',
        '50.0×10/10/10',
        '50.0×11/11/11',
        '50.0×12/12/12',
        '52.5×8',
        '52.5×9/9/9',
        '52.5×10/10/10',
        '52.5×11/11/11',
      ]);
    });

    test('lower-body barbell lift progresses by 5 kg, dumbbells by 2 kg (1 kg when light)', () {
      final squat =
          lp([
            gym(3, [
              done('0043', 'barbell full squat', [(100, 8), (100, 8), (100, 8)]),
            ]),
          ]).forExercise(planned('0043', 'barbell full squat', lo: 5, hi: 8))!;
      expect(squat.weight, 105);
      expect(squat.reps, 5);
      final lateral =
          lp([
            gym(3, [
              done('0334', 'dumbbell lateral raise', [(8, 20), (8, 20)]),
            ]),
          ]).forExercise(planned('0334', 'dumbbell lateral raise', lo: 12, hi: 20))!;
      // 8 → 9 kg would be a 12.5 % jump: microloading adds reps beyond the top first.
      expect(lateral.weight, 8);
      expect(lateral.reps, 21);
      expect(lateral.reason, ProgressReason.microload);
      final db =
          lp([
            gym(3, [
              done('0289', 'dumbbell bench press', [(26, 12), (26, 12), (26, 12)]),
            ]),
          ]).forExercise(planned('0289', 'dumbbell bench press', lo: 8, hi: 12))!;
      expect(db.weight, 28);
    });

    test('missed reps after an increase → back one step', () {
      final p =
          lp([
            gym(3, [
              done('0025', 'barbell bench press', [(82.5, 3), (82.5, 3), (82.5, 3)]),
            ]),
            gym(7, [
              done('0025', 'barbell bench press', [(80, 8), (80, 8), (80, 8)]),
            ]),
          ]).forExercise(planned('0025', 'barbell bench press', lo: 5, hi: 8))!;
      expect(p.progression, ProgressionKind.deload);
      expect(p.weight, 80); // back to the last weight that worked
    });

    test('stall: same weight 3× without more reps → ~10 % reset', () {
      final s = [(80.0, 6), (80.0, 6), (80.0, 5)];
      final p =
          lp([
            gym(2, [done('0025', 'x', s)]),
            gym(6, [done('0025', 'x', s)]),
            gym(10, [done('0025', 'x', s)]),
          ]).forExercise(planned('0025', 'barbell bench press', lo: 5, hi: 8))!;
      expect(p.progression, ProgressionKind.reset);
      expect(p.weight, 72.5);
      // Still improving → no reset.
      final q =
          lp([
            gym(2, [
              done('0025', 'x', [(80, 7), (80, 6), (80, 6)]),
            ]),
            gym(6, [done('0025', 'x', s)]),
            gym(10, [done('0025', 'x', s)]),
          ]).forExercise(planned('0025', 'barbell bench press', lo: 5, hi: 8))!;
      expect(q.progression, ProgressionKind.addReps);
      expect(q.weight, 80);
    });

    test('rep range from the goal when the program has none', () {
      final strength = male80.copyWith(athlete: const AthleteData(gymGoal: 'strength', oneRm: {'bench': 100}));
      final p = lp(const [], strength).forExercise(planned('0025', 'barbell bench press'))!;
      expect((p.repMin, p.repMax), (3, 6));
      expect(p.reps, 3);
      // 100 / (1 + (3 + 2) / 30) = 85.7 → 85
      expect(p.weight, 85);
      final hyp = male80.copyWith(athlete: const AthleteData(gymGoal: 'hypertrophy', oneRm: {'bench': 100}));
      final h = lp(const [], hyp).forExercise(planned('0025', 'barbell bench press'))!;
      expect((h.repMin, h.repMax), (6, 10));
      expect(h.weight, lessThan(p.weight));
    });

    test('first workout from setup 1RMs for accessory lifts', () {
      final prof = male80.copyWith(athlete: const AthleteData(oneRm: {'bench': 100, 'squat': 140, 'deadlift': 180, 'ohp': 60}));
      final x = lp(const [], prof);
      final pulldown = x.forExercise(planned('2330', 'cable lat pulldown full range of motion'))!;
      expect(pulldown.source, LoadSource.oneRm);
      expect(pulldown.weight, inInclusiveRange(45, 60));
      final curl = x.forExercise(planned('0031', 'barbell curl'))!;
      expect(curl.weight, inInclusiveRange(25, 35));
      final legCurl = x.forExercise(planned('0586', 'lever lying leg curl'))!;
      expect(legCurl.weight, inInclusiveRange(30, 45));
    });
  });

  group('bodyweight', () {
    test('pull-ups: reps first, then +2.5 kg added load', () {
      final pu = planned('0652', 'pull-up', lo: 6, hi: 10);
      final top =
          lp([
            gym(3, [
              done('0652', 'pull-up', [(0, 10), (0, 10), (0, 10)]),
            ]),
          ]).forExercise(pu)!;
      expect(top.progression, ProgressionKind.increase);
      expect(top.weight, 2.5);
      expect(top.reps, 6);
      expect(top.bodyweight, isTrue);
      // Assisted (negative weight): less assistance.
      final assisted =
          lp([
            gym(3, [
              done('0652', 'pull-up', [(-20, 10), (-20, 10), (-20, 10)]),
            ]),
          ]).forExercise(pu)!;
      expect(assisted.weight, -17.5);
    });

    test('push-ups: reps only', () {
      final p =
          lp([
            gym(3, [
              done('0662', 'push-up', [(0, 15), (0, 15), (0, 15)]),
            ]),
          ]).forExercise(planned('0662', 'push-up', lo: 8, hi: 15))!;
      expect(p.weight, 0);
      expect(p.reps, 16);
      expect(p.progression, ProgressionKind.addReps);
    });

    test('apply() switches bodyweight mode on with the body load per rep', () {
      final out = lp(const []).apply([
        planned('0652', 'pull-up', lo: 6, hi: 10),
        planned('0662', 'push-up', lo: 8, hi: 15),
        planned('0025', 'barbell bench press', lo: 5, hi: 8),
      ]);
      expect(out[0].bw, isTrue);
      expect(out[0].bodyKg, 80);
      expect(out[1].bw, isTrue);
      expect(out[1].bodyKg, 52);
      expect(out[2].bw, isNull);
      // A user can switch it off (e.g. pull-ups on a machine) – then it is a loaded lift.
      final off = planned('0652', 'pull-up', lo: 6, hi: 10)..bw = false;
      expect(lp(const []).isBodyweight(off), isFalse);
      final on = planned('0585', 'lever leg extension')..bw = true;
      expect(lp(const []).isBodyweight(on), isTrue);
    });

    test('volume and e1RM include the body load', () {
      final e = GymExercise(
        exId: '0652',
        name: 'pull-up',
        bw: true,
        bodyKg: 80,
        sets: [
          GymSet(weight: 10, reps: 5, done: true),
          GymSet(weight: 0, reps: 8, done: true),
          GymSet(weight: 20, reps: 12, type: SetType.warmup, done: true),
        ],
      );
      expect(e.volume, 90 * 5 + 80 * 8);
      expect(e.bestE1rm, closeTo(e1rm(90, 5) > e1rm(80, 8) ? e1rm(90, 5) : e1rm(80, 8), 1e-9));
      expect(e.maxWeight, 10);
      // Round-trip through Firestore maps.
      final m = GymExercise.fromMap(e.toMap());
      expect(m.bw, isTrue);
      expect(m.bodyKg, 80);
      expect(GymExercise.fromMap(GymExercise(exId: '1', name: 'x').toMap()).bw, isNull);
    });
  });

  group('supersets', () {
    GymExercise x(String id, String name, [String? g]) => GymExercise(exId: id, name: name, group: g);
    List<String?> groups(List<GymExercise> l) => l.map((e) => e.group).toList();

    test('the "Pull" bug: a chain of 4 linked exercises is split into sensible pairs', () {
      final pull = [
        x('0652', 'pull-up'),
        x('0027', 'barbell bent over row'),
        x('2330', 'cable lat pulldown', 'A'),
        x('0378', 'dumbbell rear fly', 'A'),
        x('0031', 'barbell curl', 'A'),
        x('0313', 'dumbbell hammer curl', 'A'),
      ];
      expect(normalizeSupersets(pull), isTrue);
      // pulldown + rear fly (non-competing) stay paired, two curls do not.
      expect(groups(pull), [null, null, 'A', 'A', null, null]);
      final w = ActiveGym(title: 'Pull', start: now, exercises: pull);
      expect(w.groupOf(2), [2, 3]);
      expect(w.groupOf(4), [4]);
    });

    test('a letter shared by non-adjacent exercises does not form a superset', () {
      final l = [x('0031', 'barbell curl', 'A'), x('0025', 'barbell bench press'), x('0241', 'cable triceps pushdown', 'A')];
      final w = ActiveGym(title: 't', start: now, exercises: l);
      expect(w.groupOf(0), [0]); // adjacency only, even before normalizing
      normalizeSupersets(l);
      expect(groups(l), [null, null, null]);
    });

    test('adjacent runs of 2–3 are kept and re-lettered; singles dissolved', () {
      final l = [
        x('1', 'barbell curl', 'C'),
        x('2', 'cable triceps pushdown', 'C'),
        x('3', 'lever leg extension', 'Q'),
        x('4', 'lever leg curl', 'B'),
        x('5', 'lever standing calf raise', 'B'),
        x('6', 'hanging leg raise', 'B'),
      ];
      normalizeSupersets(l);
      expect(groups(l), ['A', 'A', null, 'B', 'B', 'B']);
      expect(normalizeSupersets(l), isFalse);
    });

    test('link / unlink / leave keep supersets adjacent and ≤ 3', () {
      final l = [for (var i = 0; i < 5; i++) x('$i', 'exercise $i')];
      expect(linkSuperset(l, 0), isTrue);
      expect(groups(l), ['A', 'A', null, null, null]);
      expect(linkSuperset(l, 1), isTrue);
      expect(groups(l), ['A', 'A', 'A', null, null]);
      expect(canLinkSuperset(l, 2), isFalse);
      expect(linkSuperset(l, 2), isFalse); // would be 4
      expect(groups(l), ['A', 'A', 'A', null, null]);
      unlinkSuperset(l, 0);
      expect(groups(l), [null, 'A', 'A', null, null]);
      expect(linkSuperset(l, 3), isTrue);
      expect(groups(l), [null, 'A', 'A', 'B', 'B']);
      expect(linkSuperset(l, 2), isFalse); // 2 + 2 > 3
      leaveSuperset(l, 1);
      expect(groups(l), [null, null, null, 'A', 'A']);
      // Middle member leaves a superset of 3 → nothing sensible remains.
      final m = [x('a', 'a', 'A'), x('b', 'b', 'A'), x('c', 'c', 'A')];
      leaveSuperset(m, 1);
      expect(groups(m), [null, null, null]);
    });

    test('session time estimate counts a short switch inside supersets', () {
      final straight = [x('1', 'a'), x('2', 'b')];
      final paired = [x('1', 'a', 'A'), x('2', 'b', 'A')];
      expect(estimateGymMinutes(paired), lessThan(estimateGymMinutes(straight)));
    });
  });

  group('built-in programs', () {
    for (final goal in gymGoals) {
      test('supersets are sensible antagonist / non-competing pairs ($goal)', () {
        for (final t in defaultTemplates(() => '', goal: goal).where((t) => t.sport == Sport.gym)) {
          final ex = t.exercises;
          final copy = [for (final e in ex) e.copy()];
          expect(normalizeSupersets(copy), isFalse, reason: '${t.key}: superset data must already be normalized');
          if (classifyLift(ex.first.exId, ex.first.name).isCompound) {
            expect(ex.first.group, isNull, reason: '${t.key}: the first (main) lift stays a straight set');
          }
          for (var i = 0; i < ex.length; i++) {
            final g = supersetOf(ex, i);
            if (g.length < 2 || g.first != i) continue;
            expect(g.length, 2, reason: '${t.key}: pairs only');
            final a = classifyLift(ex[g[0]].exId, ex[g[0]].name), b = classifyLift(ex[g[1]].exId, ex[g[1]].name);
            expect(goodSupersetPair(a, b), isTrue, reason: '${t.key}: ${ex[g[0]].name} + ${ex[g[1]].name}');
          }
          for (final e in ex) {
            expect(e.repMin, isNotNull, reason: '${t.key} ${e.name}');
            expect(e.repMax! >= e.repMin!, isTrue);
            expect(e.sets.every((s) => s.reps == e.repMin && s.weight == 0), isTrue);
          }
        }
      });
    }

    test('at least one antagonist superset in most programs with both muscle sides', () {
      final ts = defaultTemplates(() => '').where((t) => t.sport == Sport.gym && t.exercises.any((e) => e.group != null)).toList();
      var antagonist = 0;
      for (final t in ts) {
        final ex = t.exercises;
        for (var i = 0; i + 1 < ex.length; i++) {
          if (ex[i].group != null && ex[i].group == ex[i + 1].group) {
            if (areAntagonists(classifyLift(ex[i].exId, ex[i].name), classifyLift(ex[i + 1].exId, ex[i + 1].name))) antagonist++;
          }
        }
      }
      expect(antagonist, greaterThanOrEqualTo(14));
    });

    test('rep ranges follow the goal', () {
      WorkoutTemplate pull(String goal) => defaultTemplates(() => '', goal: goal).firstWhere((t) => t.key == 'ul_upper_a');
      expect((pull('strength').exercises.first.repMin, pull('strength').exercises.first.repMax), (3, 6));
      expect((pull('general').exercises.first.repMin, pull('general').exercises.first.repMax), (5, 8));
      expect((pull('hypertrophy').exercises.first.repMin, pull('hypertrophy').exercises.first.repMax), (6, 10));
    });
  });

  group('built-in upgrade', () {
    WorkoutTemplate stored(String key, List<GymExercise> ex) =>
        WorkoutTemplate(id: 't', key: key, name: 'Pull', sport: Sport.gym, folder: '', exercises: ex);

    // The v1 "Pull" as it was seeded (two curls as a superset).
    List<GymExercise> v1Pull() => [
      GymExercise(exId: '0652', name: 'pull-up', restSec: 150, repMin: 6, repMax: 10, sets: [for (var i = 0; i < 3; i++) GymSet(reps: 6)]),
      GymExercise(
        exId: '0027',
        name: 'barbell bent over row',
        restSec: 120,
        repMin: 6,
        repMax: 10,
        sets: [for (var i = 0; i < 3; i++) GymSet(reps: 6)],
      ),
      GymExercise(
        exId: '2330',
        name: 'cable lat pulldown full range of motion',
        restSec: 120,
        repMin: 10,
        repMax: 12,
        sets: [for (var i = 0; i < 3; i++) GymSet(reps: 10)],
      ),
      GymExercise(
        exId: '0378',
        name: 'dumbbell rear fly',
        restSec: 60,
        repMin: 12,
        repMax: 20,
        sets: [for (var i = 0; i < 3; i++) GymSet(reps: 12)],
      ),
      GymExercise(
        exId: '0031',
        name: 'barbell curl',
        restSec: 60,
        repMin: 8,
        repMax: 12,
        group: 'A',
        sets: [for (var i = 0; i < 3; i++) GymSet(reps: 8)],
      ),
      GymExercise(
        exId: '0313',
        name: 'dumbbell hammer curl',
        restSec: 60,
        repMin: 10,
        repMax: 15,
        group: 'A',
        sets: [for (var i = 0; i < 2; i++) GymSet(reps: 10)],
      ),
    ];

    test('unchanged v1 program is replaced with the current version', () {
      final up = upgradedBuiltinExercises(stored('ppl_pull', v1Pull()), 'general')!;
      final cur = defaultTemplates(() => '').firstWhere((t) => t.key == 'ppl_pull').exercises;
      expect(gymSignature(up), gymSignature(cur));
      expect(up.where((e) => e.group != null).map((e) => e.name), ['dumbbell rear fly', 'barbell curl']);
    });

    test('edited programs, own weights and up-to-date programs stay untouched', () {
      final edited = v1Pull()..[2].sets.add(GymSet(reps: 10));
      expect(upgradedBuiltinExercises(stored('ppl_pull', edited), 'general'), isNull);
      final weighted = v1Pull()..[0].sets.first.weight = 10;
      expect(upgradedBuiltinExercises(stored('ppl_pull', weighted), 'general'), isNull);
      final cur = defaultTemplates(() => '').firstWhere((t) => t.key == 'ppl_pull');
      expect(upgradedBuiltinExercises(cur, 'general'), isNull);
      expect(upgradedBuiltinExercises(stored('custom', v1Pull()), 'general'), isNull);
    });

    test('goal change re-derives the rep ranges of unchanged programs', () {
      final general = defaultTemplates(() => '').firstWhere((t) => t.key == 'ppl_pull');
      final up = upgradedBuiltinExercises(general, 'strength')!;
      expect(up.first.repMin, 4); // pull-up, strength
      expect(up.first.sets.first.reps, 4);
    });
  });
}
