// ignore_for_file: avoid_print
// Multi-session simulations of the gym load prescription: a simulated lifter with a
// true 1RM that changes over time performs whatever LoadPrescriber prescribes, the
// session is fed back as history, and the trajectory of the prescribed loads is checked.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/load_prescription.dart';

final start = DateTime(2026, 9, 1, 18);

/// One simulated session: the prescription and what the lifter did.
class SimStep {
  SimStep(this.day, this.phase, this.weight, this.targets, this.done, this.trueOneRm, this.reason, this.effort);
  final int day;
  final String? phase;
  final double weight;
  final List<int> targets;
  final List<int> done;
  final double trueOneRm;
  final String reason;
  final Effort? effort;

  @override
  String toString() {
    final ph = phase == null ? '' : ' [$phase]';
    return 'd$day$ph ${_kg(weight)}×${targets.join('/')} → ${done.join('/')}'
        '${effort == null ? '' : ' ${effort!.name}'} (1RM ${_kg(trueOneRm)}, $reason)';
  }
}

String _kg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Simulated lifter.
/// * [oneRm] – true 1RM (total load per rep incl. body load) on session index i.
/// * A set at load L can be done for `30·(1RM/L − 1)` reps to failure (Epley inverse);
///   each further set loses [fatigue] reps of capacity.
/// * Normal sets: the lifter does the target reps when able, else as many as possible.
///   AMRAP sets: capacity − 1 (stop one rep before failure), at least the target when able.
/// * [chip] picks the effort rating (null = none given).
class Lifter {
  Lifter({required this.oneRm, this.bodyKg = 0, this.fatigue = 1, this.chip});
  final double Function(int i) oneRm;
  final double bodyKg;
  final double fatigue;
  final Effort? Function(int rirLastSet)? chip;

  (List<int>, Effort?) perform(int i, List<GymSet> work) {
    final t = oneRm(i);
    final out = <int>[];
    var lastRir = 0;
    for (var k = 0; k < work.length; k++) {
      final load = work[k].weight + bodyKg;
      final cap = max(0, (30 * (t / load - 1) - fatigue * k).floor());
      final target = work[k].reps;
      final r = work[k].amrap ? max(min(target, max(1, cap)), cap - 1) : min(target, max(1, cap));
      out.add(r);
      lastRir = cap - r;
    }
    return (out, chip?.call(lastRir));
  }
}

/// Effort chip a lifter would pick from the real reserve of the last set.
Effort honestChip(int rir) => rir >= 4 ? Effort.easy : (rir >= 2 ? Effort.right : (rir >= 1 ? Effort.hard : Effort.limit));

/// Runs [sessions] sessions of one exercise; [dayOf] gives the day offset of session i,
/// [phaseOf] the plan phase.
List<SimStep> simulate({
  required GymExercise Function() planned,
  required Lifter lifter,
  required int sessions,
  required UserProfile profile,
  int Function(int i)? dayOf,
  String? Function(int i)? phaseOf,
}) {
  final hist = <Session>[];
  final steps = <SimStep>[];
  for (var i = 0; i < sessions; i++) {
    final day = dayOf?.call(i) ?? i * 3;
    final date = start.add(Duration(days: day));
    final phase = phaseOf?.call(i);
    final rx = LoadPrescriber(history: hist, profile: profile, now: date);
    final ex = rx.apply([planned()], phase: phase).single;
    final p = rx.forExercise(planned(), phase: phase);
    final work = ex.sets.where((s) => !s.warmup && s.type != SetType.drop).toList();
    final targets = [for (final s in work) s.reps];
    final (reps, effort) = lifter.perform(i, work);
    for (var k = 0; k < work.length; k++) {
      work[k]
        ..reps = reps[k]
        ..done = true;
    }
    for (final s in ex.sets) {
      s.done = true;
    }
    ex.effort = effort;
    hist.add(Session(id: 's$i', sport: Sport.gym, title: 'Gym', start: date, durationSec: 3600, exercises: [ex]));
    final why = p?.reason?.name ?? p?.source.name ?? '-';
    steps.add(SimStep(day, phase, work.first.weight, targets, reps, lifter.oneRm(i), why, effort));
  }
  return steps;
}

String summary(List<SimStep> s) => s.map((x) => '  $x').join('\n');

List<double> loads(List<SimStep> s) => [for (final x in s) x.weight];

GymExercise plannedEx(String id, String name, {int sets = 3, int? lo, int? hi}) =>
    GymExercise(exId: id, name: name, repMin: lo, repMax: hi, sets: [for (var i = 0; i < sets; i++) GymSet(reps: lo ?? 8)]);

const intermediate = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1990);
const beginner = UserProfile(weightKg: 80, gender: 'm', level: 'beginner', birthYear: 1990);

void main() {
  test('C5 deload weeks: temporary, next loading week resumes at the loading level', () {
    // 3:1 – sessions twice a week; week 4 (sessions 6, 7) is a recovery week.
    final steps = simulate(
      planned: () => plannedEx('0025', 'barbell bench press', lo: 5, hi: 8),
      lifter: Lifter(oneRm: (i) => 85 + 0.5 * i, chip: honestChip),
      sessions: 12,
      profile: intermediate,
      dayOf: (i) => (i ~/ 2) * 7 + (i.isOdd ? 3 : 0),
      phaseOf: (i) => i == 6 || i == 7 ? 'recovery' : null,
    );
    printOnFailure(summary(steps));
    print('C5 deload\n${summary(steps)}');
    final before = steps[5].weight;
    // Both deload sessions are ~90 % of the loading level – the second is not derived from the first.
    expect(steps[6].weight, closeTo(before * 0.9, 2.5));
    expect(steps[7].weight, closeTo(before * 0.9, 2.5));
    // The deload keeps the program's work sets (the plan never changes set counts) – it is lighter only.
    expect(steps[6].targets.length, steps[5].targets.length);
    // The next loading session resumes at (or above) the last loading level.
    expect(steps[8].weight, greaterThanOrEqualTo(before));
    expect(steps.last.weight, greaterThanOrEqualTo(before));
  });

  test('C6 limit chip every session while hitting all reps: no downward spiral', () {
    final steps = simulate(
      planned: () => plannedEx('0025', 'barbell bench press', lo: 5, hi: 8),
      lifter: Lifter(oneRm: (i) => 100 + 3 * i / 11, chip: (_) => Effort.limit),
      sessions: 12,
      profile: intermediate,
      dayOf: (i) => (i ~/ 3) * 7 + const [0, 2, 4][i % 3],
    );
    print('C6 limit chip\n${summary(steps)}');
    final first = steps[1].weight; // after the setup estimate
    for (final s in steps.skip(1)) {
      expect(s.weight, greaterThanOrEqualTo(first * 0.85), reason: summary(steps));
    }
    expect(steps.last.weight, greaterThanOrEqualTo(first - 2.5), reason: summary(steps));
  });

  test('C6 pull-ups with descending targets: effort read against targets, keeps progressing', () {
    final steps = simulate(
      planned: () => plannedEx('0652', 'pull-up', lo: 6, hi: 10),
      lifter: Lifter(oneRm: (i) => 104 + 1.0 * i, bodyKg: 80),
      sessions: 14,
      profile: intermediate,
    );
    print('C6 pull-ups\n${summary(steps)}');
    int total(SimStep s) => s.done.fold(0, (a, b) => a + b);
    // Progress (more total reps or more added load) within any 4 consecutive sessions.
    for (var i = 4; i < steps.length; i++) {
      final better = total(steps[i]) > total(steps[i - 4]) || steps[i].weight > steps[i - 4].weight;
      expect(better, isTrue, reason: 'no progress over sessions ${i - 4}..$i\n${summary(steps)}');
    }
  });

  test('I11 beginner squat: linear progression keeps up with fast novice gains', () {
    final steps = simulate(
      planned: () => plannedEx('0043', 'barbell full squat', lo: 5, hi: 8),
      lifter: Lifter(oneRm: (i) => 60 + 2.5 * i),
      sessions: 14,
      profile: beginner,
      dayOf: (i) => (i ~/ 3) * 7 + const [0, 2, 4][i % 3],
    );
    print('I11 beginner squat\n${summary(steps)}');
    // No microloading of the squat beyond the rep range.
    for (final s in steps) {
      expect(s.targets.every((r) => r <= 8), isTrue, reason: summary(steps));
    }
    // 1RM 92.5 at the end → RIR-2 load for 5 reps ≈ 75 kg; the prescription keeps pace.
    expect(steps.last.weight, greaterThanOrEqualTo(70), reason: summary(steps));
  });

  test('GYM-1 beginner dumbbell press: no 20 % linear jumps, no swinging back and forth', () {
    for (final (exId, name) in [('0314', 'dumbbell incline bench press'), ('0289', 'dumbbell bench press'), ('0336', 'dumbbell lunge')]) {
      for (final p in [beginner, const UserProfile(weightKg: 62, gender: 'f', level: 'beginner', birthYear: 1964)]) {
        GymExercise planned() => plannedEx(exId, name, lo: 8, hi: 12);
        final first = LoadPrescriber(history: const [], profile: p, now: start).forExercise(planned())!.weight;
        final steps = simulate(
          planned: planned,
          lifter: Lifter(oneRm: (i) => first * 1.33 * (1 + 0.004 * i)),
          sessions: 42,
          profile: p,
          dayOf: (i) => (i ~/ 3) * 7 + const [0, 2, 4][i % 3],
        );
        printOnFailure(summary(steps));
        // The load never comes back down below a load whose targets were all met …
        var completed = 0.0;
        var downs = 0;
        for (var i = 1; i < steps.length; i++) {
          final prev = steps[i - 1];
          final met = [for (var k = 0; k < prev.done.length; k++) prev.done[k] >= prev.targets[k]].every((x) => x);
          if (met) completed = max(completed, prev.weight);
          expect(steps[i].weight, greaterThanOrEqualTo(completed - 1e-6), reason: '$name ${p.gender} session $i\n${summary(steps)}');
          if (steps[i].weight < prev.weight - 1e-6) downs++;
        }
        // … and does not swing: at most one step back in 14 weeks (the lifter gets steadily stronger).
        expect(downs, lessThanOrEqualTo(1), reason: '$name ${p.gender}\n${summary(steps)}');
      }
    }
  });

  test('GYM-5 deload after weeks of legs-easy sessions only: lighter than the week before', () {
    // A squat done only the day before the key run (legs easy), then a recovery week.
    final steps = simulate(
      planned: () => plannedEx('0043', 'barbell full squat', lo: 5, hi: 8),
      lifter: Lifter(oneRm: (i) => 100 + 0.5 * i),
      sessions: 8,
      profile: intermediate,
      dayOf: (i) => i * 7,
      phaseOf: (i) => i == 3 || i == 7 ? 'recovery' : 'legsEasy',
    );
    printOnFailure(summary(steps));
    for (final i in [3, 7]) {
      final prev = steps[i - 1], deload = steps[i];
      int volume(SimStep s) => s.targets.fold(0, (a, b) => a + b);
      expect(deload.weight, lessThan(prev.weight), reason: summary(steps));
      expect(volume(deload), lessThanOrEqualTo(volume(prev)), reason: summary(steps));
    }
    // The deload is temporary: the next legs-easy week resumes at the legs-easy level, not below it.
    expect(steps[4].weight, greaterThanOrEqualTo(steps[2].weight), reason: summary(steps));
  });

  test('GYM-11 bodyweight deload after a load step: reps of the last loading week, not of the step', () {
    // Pull-ups at the top of the range (10/10/10) → next step +2.5 kg × 6; the recovery week instead.
    final steps = simulate(
      planned: () => plannedEx('0652', 'pull-up', lo: 6, hi: 10),
      lifter: Lifter(oneRm: (i) => i < 3 ? 108 : 125, bodyKg: 80),
      sessions: 6,
      profile: intermediate,
      dayOf: (i) => i * 3,
      phaseOf: (i) => i == 5 ? 'recovery' : null,
    );
    printOnFailure(summary(steps));
    final last = steps[4], deload = steps[5];
    expect(last.done, everyElement(10), reason: summary(steps)); // top of the range: the next step would add load
    // ~10 % lighter: at most ~20 % fewer reps of the last loading session, no added load.
    expect(deload.weight, lessThanOrEqualTo(last.weight));
    expect(deload.targets.first, greaterThanOrEqualTo((last.done.reduce(min) * 0.8).floor()), reason: summary(steps));
  });

  test('I12 under-estimated start load is corrected without an effort rating', () {
    final steps = simulate(
      planned: () => plannedEx('0025', 'barbell bench press', lo: 5, hi: 8),
      lifter: Lifter(oneRm: (_) => 100),
      sessions: 12,
      profile: intermediate,
    );
    print('I12 under-estimate\n${summary(steps)}');
    // True 1RM 100 → a 5–8 rep working load at RIR 1–3 is ≈ 75–82.5 kg.
    expect(steps.last.weight, greaterThanOrEqualTo(75), reason: summary(steps));
    expect(steps.sublist(0, 6).map((s) => s.weight).reduce(max), greaterThanOrEqualTo(72.5), reason: summary(steps));
  });
}
