import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/gym_tools.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/smart_progression.dart';
import 'package:strive/widgets/prescription.dart';

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

GymExercise done(String id, String name, List<(double, int)> sets, {Effort? effort, bool? bw, double bodyKg = 0, double? rpe}) =>
    GymExercise(
      exId: id,
      name: name,
      effort: effort,
      bw: bw,
      bodyKg: bodyKg,
      sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: true, rpe: rpe)],
    );

GymExercise planned(String id, String name, {int sets = 3, int lo = 6, int hi = 10}) =>
    GymExercise(exId: id, name: name, repMin: lo, repMax: hi, sets: [for (var i = 0; i < sets; i++) GymSet(reps: lo)]);

const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);
final beginner = male80.copyWith(level: 'beginner');
final advanced = male80.copyWith(level: 'advanced');

LoadPrescriber lp(List<Session> h, [UserProfile p = male80, DateTime? at]) => LoadPrescriber(history: h, profile: p, now: at ?? now);

final bench = planned('0025', 'barbell bench press');
Session benchDay(int daysAgo, List<(double, int)> s, {Effort? effort, double? rpe}) =>
    gym(daysAgo, [done('0025', 'barbell bench press', s, effort: effort, rpe: rpe)]);

List<(double, int)> x3(double w, int r) => [(w, r), (w, r), (w, r)];

/// A simulated lifter: true 1RM [oneRm] (changes by [gain] per session); does the
/// prescribed sets but cannot exceed the reps the 1RM allows (Epley), losing about one
/// rep per set from fatigue when a set is taken close to failure. Rates the effort with
/// the chip when [rate] is set.
class Lifter {
  Lifter(this.oneRm, {this.gain = 0, this.rate = false});
  double oneRm;
  final double gain;
  final bool rate;

  (List<(double, int)>, Effort?) perform(double w, List<int> targets) {
    final out = <(double, int)>[];
    var lastRir = 9;
    for (var k = 0; k < targets.length; k++) {
      final maxReps = max(0, (30 * (oneRm / w - 1)).floor()) - k; // fatigue: −1 rep per set
      final r = min(targets[k], maxReps);
      out.add((w, max(1, r)));
      lastRir = maxReps - r;
    }
    oneRm *= 1 + gain;
    final effort =
        !rate
            ? null
            : lastRir >= 4
            ? Effort.easy
            : lastRir >= 2
            ? Effort.right
            : lastRir == 1
            ? Effort.hard
            : Effort.limit;
    return (out, effort);
  }
}

/// Runs [sessions] workouts every 3 days, following the prescriptions; returns them.
List<Prescription> simulate(
  Lifter lifter,
  GymExercise plan,
  double startW, {
  int sessions = 12,
  UserProfile profile = male80,
  bool bodyweight = false,
}) {
  final history = <Session>[];
  final log = <Prescription>[];
  var w = startW;
  var targets = [for (var k = 0; k < plan.workSets.length; k++) plan.repMin!];
  for (var i = 0; i < sessions; i++) {
    final day = (sessions - i) * 3;
    final (sets, effort) = lifter.perform(bodyweight ? w + 80 : w, targets);
    history.insert(
      0,
      gym(day, [
        done(
          plan.exId,
          plan.name,
          [for (final (lw, r) in sets) (bodyweight ? lw - 80 : lw, r)],
          effort: effort,
          bw: bodyweight ? true : null,
          bodyKg: bodyweight ? 80 : 0,
        ),
      ]),
    );
    final p = LoadPrescriber(history: history, profile: profile, now: now.subtract(Duration(days: day - 2))).forExercise(plan)!;
    log.add(p);
    w = p.weight;
    targets = [for (var k = 0; k < plan.workSets.length; k++) max(1, p.repsForSet(k))];
  }
  return log;
}

void main() {
  group('effort', () {
    test('chip, logged RPE and failure sets come first', () {
      final s = [
        for (final r in [10, 8, 6]) GymSet(weight: 60, reps: r, done: true),
      ];
      expect(estimateEffort(s, chip: Effort.easy, top: 10).rir, 4);
      expect(estimateEffort(s, chip: Effort.easy, top: 10).inferred, isFalse);
      final rpe = [GymSet(weight: 60, reps: 8, done: true, rpe: 8), GymSet(weight: 60, reps: 8, done: true, rpe: 9)];
      expect(estimateEffort(rpe, top: 10).rir, 1); // hardest set RPE 9 → RIR 1
      final fail = [GymSet(weight: 60, reps: 8, done: true), GymSet(weight: 60, reps: 7, done: true, type: SetType.failure)];
      expect(estimateEffort(fail, top: 10).limit, isTrue);
    });

    test('inferred from rep drop-off and reps vs. range when there is no rating', () {
      List<GymSet> s(List<int> reps, [double w = 60]) => [for (final r in reps) GymSet(weight: w, reps: r, done: true)];
      final limit = estimateEffort(s([10, 8, 6]), top: 10);
      expect(limit.limit, isTrue);
      expect(limit.inferred, isTrue);
      expect(estimateEffort(s([10, 9, 8]), top: 10).rir, 1); // 20 % drop → hard
      expect(estimateEffort(s([8, 8, 7]), top: 10).rir, isNull); // 1 rep is noise
      expect(estimateEffort(s([10, 10, 10]), top: 10).rir, isNull); // even sets at the top: unknown
      expect(estimateEffort(s([13, 13, 12]), top: 10).easy, isTrue); // well above the range
      // Back-off sets at a lighter load do not count as drop-off.
      expect(
        estimateEffort([
          ...s([8, 8]),
          GymSet(weight: 50, reps: 4, done: true),
        ], top: 10).rir,
        isNull,
      );
    });

    test('effort is stored on the exercise, but not copied into a new workout', () {
      final e = done('0025', 'x', x3(60, 8), effort: Effort.hard);
      expect(GymExercise.fromMap(e.toMap()).effort, Effort.hard);
      expect(GymExercise.fromMap(done('0025', 'x', x3(60, 8)).toMap()).effort, isNull);
      expect(e.copy().effort, Effort.hard);
      expect(e.copy(resetDone: true).effort, isNull);
    });
  });

  group('trend (Theil–Sen)', () {
    test('robust slope ignores a single bad day', () {
      final pts = [(0.0, 100.0), (3.0, 101.0), (6.0, 80.0), (9.0, 103.0), (12.0, 104.0)];
      expect(theilSenSlope(pts), closeTo(1 / 3, 0.05));
    });

    test('progressing, plateau and regressing', () {
      ProgressEntry e(int daysAgo, double w, int r) =>
          ProgressEntry(now.subtract(Duration(days: daysAgo)), [for (var i = 0; i < 3; i++) GymSet(weight: w, reps: r, done: true)]);
      expect(e1rmTrend([e(1, 65, 8), e(5, 62.5, 8), e(9, 60, 8), e(13, 60, 7)]), E1rmTrend.progressing);
      expect(e1rmTrend([e(1, 60, 8), e(5, 60, 8), e(9, 60, 8), e(13, 60, 8)]), E1rmTrend.plateau);
      expect(e1rmTrend([e(1, 55, 7), e(5, 57.5, 7), e(9, 60, 8), e(13, 60, 8)]), E1rmTrend.regressing);
      expect(e1rmTrend([e(1, 60, 8), e(5, 60, 8)]), E1rmTrend.unknown); // too few sessions
    });
  });

  group('steady progress', () {
    test('a lifter who gets stronger climbs steadily and is never pushed back', () {
      final log = simulate(Lifter(100, gain: 0.01), bench, 60, sessions: 16);
      final weights = log.map((p) => p.weight).toList();
      for (var i = 1; i < weights.length; i++) {
        expect(weights[i], greaterThanOrEqualTo(weights[i - 1]), reason: '$log');
      }
      expect(weights.last, greaterThan(60));
      expect(log.map((p) => p.reason), everyElement(isIn([ProgressReason.addReps, ProgressReason.topReached])));
      // Each increase is a single 2.5 kg step (intermediate, no rating).
      for (var i = 1; i < weights.length; i++) {
        expect(weights[i] - weights[i - 1], lessThanOrEqualTo(2.5));
      }
    });

    test('rated "easy" at the top → two load steps; "just right" → one', () {
      final easy = lp([benchDay(3, x3(60, 10), effort: Effort.easy)]).forExercise(bench)!;
      expect(easy.weight, 65);
      expect(easy.reps, 6);
      expect(easy.reason, ProgressReason.topWithReserve);
      final right = lp([benchDay(3, x3(60, 10), effort: Effort.right)]).forExercise(bench)!;
      expect(right.weight, 62.5);
      expect(right.reason, ProgressReason.topReached);
    });

    test('easy inside the range → two more reps per set (capped at the top)', () {
      final p =
          lp([
            benchDay(3, [(60, 7), (60, 7), (60, 9)], effort: Effort.easy),
          ]).forExercise(bench)!;
      expect(p.setReps, [9, 9, 10]);
      expect(p.reason, ProgressReason.addRepsFast);
      expect(p.weight, 60);
    });

    test('a jump never exceeds ~10 % of the load', () {
      // 25 kg row (2.5 kg steps): two steps would be 20 % → one step only.
      final p =
          lp([
            gym(3, [done('0861', 'cable seated row', x3(25, 12), effort: Effort.easy)]),
          ]).forExercise(planned('0861', 'cable seated row', lo: 8, hi: 12))!;
      expect(p.weight, 27.5);
    });
  });

  group('limit and hard', () {
    test('top reached at the limit → same load and reps once more', () {
      final p = lp([benchDay(3, x3(60, 10), effort: Effort.limit)]).forExercise(bench)!;
      expect(p.weight, 60);
      expect(p.progression, ProgressionKind.hold);
      expect(p.setReps, [10, 10, 10]);
      expect(p.reason, ProgressReason.topAtLimit);
    });

    test('inside the range at the limit → repeat the reps instead of adding', () {
      final p =
          lp([
            benchDay(3, [(60, 8), (60, 8), (60, 7)], effort: Effort.limit),
          ]).forExercise(bench)!;
      expect(p.weight, 60);
      expect(p.setReps, [8, 8, 7]);
      expect(p.reason, ProgressReason.holdLimit);
    });

    test('one rep below the range at the limit → lighter (instead of holding)', () {
      final plain =
          lp([
            benchDay(3, [(62.5, 5), (62.5, 5), (62.5, 6)]),
          ]).forExercise(bench)!;
      expect(plain.reason, ProgressReason.missedHold);
      expect(plain.weight, 62.5);
      final limit =
          lp([
            benchDay(3, [(62.5, 5), (62.5, 5), (62.5, 6)], effort: Effort.limit),
          ]).forExercise(bench)!;
      expect(limit.reason, ProgressReason.missedReduce);
      expect(limit.weight, 60);
    });

    test('two hard sessions in a row without progress → hold', () {
      final p =
          lp([
            benchDay(3, [(60, 8), (60, 8), (60, 7)], effort: Effort.hard),
            benchDay(7, [(60, 8), (60, 8), (60, 7)], effort: Effort.hard),
          ]).forExercise(bench)!;
      expect(p.reason, ProgressReason.holdHard);
      expect(p.setReps, [8, 8, 7]);
      // Hard, but progressing → keep adding reps.
      final q =
          lp([
            benchDay(3, [(60, 9), (60, 8), (60, 8)], effort: Effort.hard),
            benchDay(7, [(60, 8), (60, 8), (60, 7)], effort: Effort.hard),
          ]).forExercise(bench)!;
      expect(q.reason, ProgressReason.addReps);
      expect(q.setReps, [10, 9, 9]);
    });
  });

  group('missing rating (inferred effort)', () {
    test('large rep drop-off counts as the limit → repeat the reps', () {
      final p =
          lp([
            benchDay(3, [(60, 10), (60, 8), (60, 6)]),
          ]).forExercise(bench)!;
      expect(p.effort!.inferred, isTrue);
      expect(p.effort!.limit, isTrue);
      expect(p.reason, ProgressReason.holdLimit);
      expect(p.weight, 60);
    });

    test('moderate drop-off (hard) still adds a rep per set', () {
      final p =
          lp([
            benchDay(3, [(60, 9), (60, 8), (60, 7)]),
          ]).forExercise(bench)!;
      expect(p.reason, ProgressReason.addReps);
      expect(p.setReps, [10, 9, 8]);
    });

    test('reps far above the range → bigger jump (intermediate), one step (advanced)', () {
      final h = [benchDay(3, x3(60, 12))];
      expect(lp(h).forExercise(bench)!.weight, 65);
      expect(lp(h, advanced).forExercise(bench)!.weight, 62.5);
      // An explicit "easy" lets advanced lifters jump too.
      expect(lp([benchDay(3, x3(60, 12), effort: Effort.easy)], advanced).forExercise(bench)!.weight, 65);
    });
  });

  group('training level', () {
    test('beginners progress faster, advanced lifters one notch at a time', () {
      final top = [benchDay(3, x3(60, 10))];
      expect(lp(top, beginner).forExercise(bench)!.weight, 65);
      expect(lp(top, beginner).forExercise(bench)!.reason, ProgressReason.topWithReserve);
      expect(lp(top).forExercise(bench)!.weight, 62.5);
      expect(lp(top, advanced).forExercise(bench)!.weight, 62.5);
      final mid = [benchDay(3, x3(60, 7))];
      expect(lp(mid, beginner).forExercise(bench)!.setReps, [9, 9, 9]);
      expect(lp(mid).forExercise(bench)!.setReps, [8, 8, 8]);
      expect(lp(mid, advanced).forExercise(bench)!.setReps, [8, 8, 8]);
      // A beginner who found it hard gets the normal step.
      expect(lp([benchDay(3, x3(60, 10), effort: Effort.hard)], beginner).forExercise(bench)!.weight, 62.5);
    });

    test('simulated beginner reaches a higher load than an advanced lifter in the same time', () {
      final b = simulate(Lifter(100, gain: 0.015), bench, 60, profile: beginner);
      final a = simulate(Lifter(100, gain: 0.015), bench, 60, profile: advanced);
      expect(b.last.weight, greaterThanOrEqualTo(a.last.weight));
      expect(b.map((p) => p.weight).reduce(max), greaterThan(60));
    });
  });

  group('stall and regression', () {
    test('three sessions at the same weight without more reps → ~10 % reset', () {
      final p =
          lp([
            benchDay(2, [(80, 7), (80, 6), (80, 6)]),
            benchDay(9, [(80, 7), (80, 6), (80, 6)]),
            benchDay(16, [(80, 7), (80, 7), (80, 6)]),
          ]).forExercise(bench)!;
      expect(p.reason, ProgressReason.stall);
      expect(p.weight, 72.5);
    });

    test('two weaker sessions in a row: small dip → hold, clear drop → ~7.5 % lighter', () {
      final dip =
          lp([
            benchDay(4, x3(77.5, 7)),
            benchDay(8, [(77.5, 8), (77.5, 7), (77.5, 7)]),
            benchDay(12, x3(80, 8)),
          ]).forExercise(bench)!;
      expect(dip.reason, ProgressReason.performanceDip);
      expect(dip.weight, 77.5);
      expect(dip.setReps, [7, 7, 7]);
      final drop =
          lp([
            benchDay(4, [(77.5, 6), (77.5, 6), (77.5, 5)]),
            benchDay(8, [(77.5, 7), (77.5, 7), (77.5, 6)]),
            benchDay(12, x3(80, 8)),
          ]).forExercise(bench)!;
      expect(drop.reason, ProgressReason.performanceDrop);
      expect(drop.weight, inInclusiveRange(70, 72.5));
      expect(drop.reps, 6);
    });

    test('a heavier load with fewer reps is normal progress, not a drop', () {
      final p = lp([benchDay(4, x3(65, 6)), benchDay(8, x3(62.5, 7)), benchDay(12, x3(60, 10))]).forExercise(bench)!;
      expect(p.reason, ProgressReason.addReps);
      expect(p.weight, 65);
    });

    test('a lifter who is losing strength gets lighter loads, not more', () {
      final log = simulate(Lifter(100, gain: -0.03), bench, 70, sessions: 10);
      expect(log.last.weight, lessThan(70));
      expect(
        log.map((p) => p.reason),
        anyElement(isIn([ProgressReason.missedReduce, ProgressReason.performanceDrop, ProgressReason.stall, ProgressReason.holdLimit])),
      );
    });
  });

  group('bodyweight', () {
    final pu = planned('0652', 'pull-up', lo: 6, hi: 10);

    test('pull-ups with added load: +2.5 kg at the top, +5 kg when easy', () {
      Session day(int d, double add, List<int> reps, {Effort? effort}) => gym(d, [
        done('0652', 'pull-up', [for (final r in reps) (add, r)], bw: true, bodyKg: 80, effort: effort),
      ]);
      final p =
          lp([
            day(3, 5, [10, 10, 10]),
          ]).forExercise(pu)!;
      expect(p.bodyweight, isTrue);
      expect(p.weight, 7.5);
      expect(p.reps, 6);
      expect(
        lp([
          day(3, 5, [10, 10, 10], effort: Effort.easy),
        ]).forExercise(pu)!.weight,
        10,
      );
      // Inside the range: reps first, the added load stays.
      final mid =
          lp([
            day(3, 5, [8, 7, 7]),
          ]).forExercise(pu)!;
      expect(mid.weight, 5);
      expect(mid.setReps, [9, 8, 8]);
    });

    test('stall with added load sheds load but never turns into assistance', () {
      Session day(int d, double add) => gym(d, [
        done('0652', 'pull-up', [(add, 7), (add, 6), (add, 6)], bw: true, bodyKg: 80),
      ]);
      final p = lp([day(2, 5), day(9, 5), day(16, 5)]).forExercise(pu)!;
      expect(p.reason, ProgressReason.stall);
      expect(p.weight, 0); // 5 − 10 % of 85 → 0, not −3.5
    });

    test('old pull-up sessions logged with the body weight as weight count as +0 kg', () {
      final p =
          lp([
            gym(3, [done('0652', 'pull-up', x3(80, 8))]),
          ]).forExercise(pu)!;
      expect(p.weight, 0);
      expect(p.setReps, [9, 9, 9]);
      // Explicitly loaded sessions (bodyweight mode off) convert the same way.
      final q =
          lp([
            gym(3, [done('0652', 'pull-up', x3(85, 10), bw: false)]),
          ]).forExercise(pu)!;
      expect(q.weight, 7.5); // +5 kg → top reached → +2.5 kg
    });

    test('bodyweight sessions feed a loaded exercise as body load + added weight', () {
      final off = planned('0652', 'pull-up', lo: 6, hi: 10)..bw = false;
      final p =
          lp([
            gym(3, [
              done('0652', 'pull-up', [(0, 8), (0, 8), (0, 8)], bw: true, bodyKg: 80),
            ]),
          ]).forExercise(off)!;
      expect(p.weight, 80);
      expect(p.setReps, [9, 9, 9]);
    });

    test('push-ups have no load step: reps beyond the range', () {
      final p =
          lp([
            gym(3, [done('0662', 'push-up', x3(0, 15), bw: true, bodyKg: 52)]),
          ]).forExercise(planned('0662', 'push-up', lo: 8, hi: 15))!;
      expect(p.weight, 0);
      expect(p.reps, 16);
      expect(p.reason, ProgressReason.repsNoLoad);
    });

    test('simulated pull-ups: reps up, then added load in 2.5 kg steps', () {
      final log = simulate(Lifter(110, gain: 0.01), pu, 0, sessions: 14, bodyweight: true);
      final adds = log.map((p) => p.weight).toList();
      expect(adds.last, greaterThan(0));
      for (var i = 1; i < adds.length; i++) {
        expect(adds[i] - adds[i - 1], lessThanOrEqualTo(5));
      }
    });
  });

  group('microloading (light dumbbells)', () {
    final lateral = planned('0334', 'dumbbell lateral raise', lo: 12, hi: 20, sets: 3);

    test('at the top: reps beyond the range first, then +1 kg with matched reps', () {
      final first =
          lp([
            gym(3, [done('0334', 'dumbbell lateral raise', x3(8, 20))]),
          ]).forExercise(lateral)!;
      expect(first.weight, 8);
      expect(first.setReps, [21, 21, 21]);
      expect(first.reason, ProgressReason.microload);
      final capped =
          lp([
            gym(3, [done('0334', 'dumbbell lateral raise', x3(8, 25))]),
          ]).forExercise(lateral)!;
      expect(capped.weight, 9);
      // e1RM 8 × (1 + 25/30) ≈ 14.7 → 9 kg × ~18, minus a rep of safety.
      expect(capped.reps, inInclusiveRange(15, 18));
      expect(capped.reason, ProgressReason.topReached);
    });

    test('simulated lateral raises never jump more than one small step', () {
      final log = simulate(Lifter(14, gain: 0.01), lateral, 8, sessions: 16);
      for (final p in log) {
        expect(p.reps, lessThanOrEqualTo(25));
      }
      final ws = log.map((p) => p.weight).toList();
      for (var i = 1; i < ws.length; i++) {
        expect(ws[i] - ws[i - 1], lessThanOrEqualTo(1));
      }
      expect(ws.last, greaterThanOrEqualTo(8));
    });

    test('heavy dumbbells (2 kg = 7.7 %) progress normally', () {
      final p =
          lp([
            gym(3, [done('0289', 'dumbbell bench press', x3(26, 12))]),
          ]).forExercise(planned('0289', 'dumbbell bench press', lo: 8, hi: 12))!;
      expect(p.weight, 28);
      expect(p.reps, 8);
    });
  });

  group('breaks', () {
    test('3-week break → ~5 % lighter, no progression reason', () {
      final p = lp([benchDay(23, x3(80, 8))]).forExercise(bench)!;
      expect(p.breakDays, 23);
      expect(p.weight, 75);
      expect(p.reason, isNull);
    });

    test('> 6 weeks → from the e1RM × 0.9', () {
      final p = lp([benchDay(50, x3(80, 8))]).forExercise(bench)!;
      expect(p.weight, lessThan(80));
      expect(p.breakDays, 50);
    });
  });

  group('UI reason', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('every reason has a German and an English text', () {
      for (final r in ProgressReason.values) {
        final p = Prescription(weight: 60, reps: 8, source: LoadSource.history, fromHistory: true, reason: r);
        expect(prescriptionReason(de, p), isNotEmpty);
        expect(prescriptionReason(en, p), isNotEmpty);
        expect(prescriptionReason(de, p), isNot(prescriptionReason(en, p)));
      }
    });

    test('the suggestion explains itself', () {
      final p = lp([benchDay(3, x3(60, 10), effort: Effort.easy)]).forExercise(bench)!;
      expect(prescriptionReason(de, p), contains('Reserve'));
      final hold =
          lp([
            benchDay(3, [(60, 8), (60, 8), (60, 7)], effort: Effort.hard),
            benchDay(7, [(60, 8), (60, 8), (60, 7)], effort: Effort.hard),
          ]).forExercise(bench)!;
      expect(prescriptionReason(de, hold), contains('schwer'));
      // A deload week overrides an increase.
      final deload = lp([benchDay(3, x3(60, 10))]).forExercise(bench, phase: 'recovery')!;
      expect(prescriptionReason(de, deload), isNot(contains('mehr Gewicht')));
    });
  });

  group('prescribed targets (feedback loops)', () {
    final d0 = DateTime(2026, 11, 1);
    List<GymSet> sets(List<(double, int, int)> x) => [for (final (w, r, t) in x) GymSet(weight: w, reps: r, done: true, target: t)];
    ProgressEntry entry(int daysAgo, List<(double, int, int)> x, {Effort? effort, double? rx}) =>
        ProgressEntry(d0.subtract(Duration(days: daysAgo)), sets(x), effort: effort, rxKg: rx);

    test('a planned descending pattern that was met is not read as a hard drop-off', () {
      expect(estimateEffort(sets([(0, 10, 10), (0, 9, 9), (0, 8, 8)]), top: 10).hard, isFalse);
      expect(estimateEffort(sets([(0, 10, 10), (0, 9, 10), (0, 8, 10)]), top: 10).limit, isTrue);
      expect(estimateEffort(sets([(0, 10, 10), (0, 9, 9), (0, 7, 8)]), top: 10).hard, isTrue);
      // Without targets the old drop-off inference stays.
      expect(
        estimateEffort([
          for (final r in [10, 9, 8]) GymSet(reps: r, done: true),
        ], top: 10).hard,
        isTrue,
      );
    });

    test('AMRAP set: reps beyond the target are the reserve', () {
      final work = sets([(60, 5, 5), (60, 5, 5)])..add(GymSet(weight: 60, reps: 12, done: true, target: 5, amrap: true));
      expect(estimateEffort(work, top: 8).rir, 5);
      expect(estimateEffort(work, top: 8, chip: Effort.hard).rir, 5); // the chip rates the AMRAP set itself
      final tight = sets([(60, 5, 5), (60, 5, 5)])..add(GymSet(weight: 60, reps: 5, done: true, target: 5, amrap: true));
      expect(estimateEffort(tight, top: 8).hard, isTrue);
    });

    test("the app's own lighter prescription with the same reps is not a performance drop", () {
      final hist = [
        entry(0, [(55, 5, 5), (55, 5, 5), (55, 5, 5)], effort: Effort.limit, rx: 55),
        entry(2, [(55, 5, 5), (55, 5, 5), (55, 5, 5)], effort: Effort.limit, rx: 55),
        entry(4, [(60, 5, 5), (60, 5, 5), (60, 5, 5)], effort: Effort.limit, rx: 60),
      ];
      final p = smartProgression(hist, bottom: 5, top: 8, increment: 2.5)!;
      expect(p.reason, isNot(ProgressReason.performanceDrop));
      expect(p.weight, 55);
      // The same lighter load chosen by the user (prescribed 60) is one.
      final chosen = [
        ProgressEntry(d0, [for (var i = 0; i < 3; i++) GymSet(weight: 55, reps: 5, done: true)], effort: Effort.limit, rxKg: 60),
        ProgressEntry(
          d0.subtract(const Duration(days: 2)),
          [for (var i = 0; i < 3; i++) GymSet(weight: 55, reps: 5, done: true)],
          effort: Effort.limit,
          rxKg: 60,
        ),
        ProgressEntry(d0.subtract(const Duration(days: 4)), [
          for (var i = 0; i < 3; i++) GymSet(weight: 60, reps: 5, done: true),
        ], rxKg: 60),
      ];
      expect(smartProgression(chosen, bottom: 5, top: 8, increment: 2.5)!.reason, ProgressReason.performanceDrop);
    });

    test('held twice with every target met → one more rep on the weakest set, no stall reset', () {
      final hist = [
        for (final d in [0, 7, 14, 21]) entry(d, [(60, 7, 7), (60, 6, 6), (60, 6, 6)], effort: Effort.limit, rx: 60),
      ];
      final p = smartProgression(hist, bottom: 5, top: 8, increment: 2.5)!;
      expect(p.reason, ProgressReason.nudge);
      expect(p.weight, 60);
      expect(p.setReps, [7, 6, 7]);
    });

    test('beginner linear progression: one step per session while targets are hit, repeat once on a miss', () {
      final hit = [
        entry(0, [(50, 5, 5), (50, 5, 5), (50, 5, 5)]),
      ];
      final p = smartProgression(hit, bottom: 5, top: 8, increment: 2.5, level: 'beginner', linear: true)!;
      expect(p.reason, ProgressReason.linear);
      expect(p.weight, 52.5);
      expect(p.setReps, [5, 5, 5]);
      final miss = [
        entry(0, [(50, 5, 5), (50, 5, 5), (50, 4, 5)]),
      ];
      final q = smartProgression(miss, bottom: 5, top: 8, increment: 2.5, level: 'beginner', linear: true)!;
      expect(q.kind, ProgressionKind.hold);
      expect(q.setReps, [5, 5, 5]);
    });

    test('lower-body barbell step: 2.5 kg below 50 kg, 5 kg above', () {
      const squat = Exercise(
        id: '0043',
        name: 'barbell full squat',
        bodyPart: 'upper legs',
        equipment: 'barbell',
        target: 'quads',
        secondary: [],
        instructions: [],
      );
      expect(loadIncrement(squat, weight: 47.5), 2.5);
      expect(loadIncrement(squat, weight: 60), 5);
    });
  });
}
