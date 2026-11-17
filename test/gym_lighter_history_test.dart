import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/load_prescription.dart';

/// Review r7 F1 re-check: a lighter session done as prescribed must not lower the next baseline.
/// An exercise done only on 'legsEasy' days (hybrid upper/lower with every lower day before a key
/// session) used to lose ~12 % every week: the lighter sessions became the history and were
/// lightened again (squat 65 → 22.5 kg in ten weeks).
void main() {
  const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);
  final day0 = DateTime(2026, 9, 7, 18); // Monday

  /// Runs [weeks] weekly sessions of [open] in load phase [phaseOf] (week → phase), each done
  /// exactly as prescribed (the tracker prefill, every set ticked). Returns the prescriptions.
  List<Prescription> run(GymExercise open, int weeks, String? Function(int week) phaseOf, {List<Session> seed = const []}) {
    final history = <Session>[...seed];
    final out = <Prescription>[];
    for (var w = 0; w < weeks; w++) {
      final now = addDays(day0, 7 * w);
      final rx = LoadPrescriber(history: [...history.reversed], profile: male80, now: now);
      final phase = phaseOf(w);
      final p = rx.forExercise(open, phase: phase)!;
      out.add(p);
      final done = rx.apply([open], phase: phase).single;
      for (final s in done.sets) {
        s.done = true;
        if (done.isTimed) {
          s.sec = s.targetSec ?? s.sec;
        } else {
          s.reps = s.target ?? s.reps;
        }
      }
      if (done.bw == true && done.bodyKg <= 0) done.bodyKg = 80;
      history.add(Session(id: 'w$w', sport: Sport.gym, title: 'Lower', start: now, durationSec: 3600, exercises: [done]));
    }
    return out;
  }

  double total(Prescription p) => p.weight * p.reps;

  test('squat on legs-easy days only: the load never goes down, it progresses', () {
    final squat = GymExercise(exId: '0043', name: 'barbell full squat', sets: [GymSet(reps: 6), GymSet(reps: 6), GymSet(reps: 6)]);
    final ps = run(squat, 10, (_) => 'legsEasy');
    final kg = [for (final p in ps) p.weight];
    for (var i = 1; i < kg.length; i++) {
      expect(kg[i], greaterThanOrEqualTo(kg[i - 1]), reason: '$kg');
    }
    expect(kg.last, greaterThan(kg.first), reason: '$kg');
    expect(ps.every((p) => p.phaseAdjusted && !p.amrap), isTrue);
  });

  test('legs-easy history, then a loading day: back at the loading level (~1 / 0.875)', () {
    final squat = GymExercise(exId: '0043', name: 'barbell full squat', sets: [GymSet(reps: 6), GymSet(reps: 6), GymSet(reps: 6)]);
    final ps = run(squat, 7, (w) => w < 6 ? 'legsEasy' : null);
    final easy = ps[5], load = ps[6];
    expect(load.phaseAdjusted, isFalse);
    expect(load.weight, greaterThanOrEqualTo(easy.weight / 0.875 - 2.5), reason: '${easy.weight} → ${load.weight}');
    expect(load.weight, lessThanOrEqualTo(easy.weight / 0.875 + 5), reason: '${easy.weight} → ${load.weight}');
  });

  test('deload sessions only: a second deload week does not cut again, the next loading week is ~1 / 0.9', () {
    final squat = GymExercise(exId: '0043', name: 'barbell full squat', sets: [GymSet(reps: 6), GymSet(reps: 6), GymSet(reps: 6)]);
    final ps = run(squat, 3, (w) => w < 2 ? 'recovery' : null);
    expect(ps[1].weight, greaterThanOrEqualTo(ps[0].weight));
    expect(ps[2].weight, greaterThanOrEqualTo(ps[1].weight / 0.9 - 2.5));
    // A deload week after legs-easy-only weeks: ~10 % below those weeks – they are the lift's loading level (review
    // 2026-11 GYM-5: 0.9 / 0.875 made the recovery week as heavy as, or heavier than, the week before).
    final mixed = run(squat, 5, (w) => w < 4 ? 'legsEasy' : 'recovery');
    expect(mixed[4].weight, lessThan(mixed[3].weight));
    expect(mixed[4].weight, greaterThanOrEqualTo(mixed[3].weight * 0.9 - 5));
  });

  test('bodyweight lower exercises on legs-easy days only: the reps never go down', () {
    for (final (exId, name) in [('3500', 'bodyweight squat'), ('1460', 'walking lunge')]) {
      final open = GymExercise(exId: exId, name: name, bw: true, sets: [GymSet(reps: 12), GymSet(reps: 12), GymSet(reps: 12)]);
      final ps = run(open, 8, (_) => 'legsEasy');
      final reps = [for (final p in ps) p.reps];
      for (var i = 1; i < ps.length; i++) {
        expect(total(ps[i]) + ps[i].reps, greaterThanOrEqualTo(total(ps[i - 1]) + ps[i - 1].reps), reason: '$name $reps');
        expect(ps[i].reps, greaterThanOrEqualTo(ps[i - 1].reps), reason: '$name $reps');
      }
    }
  });

  test('wall sit on legs-easy days only progresses its hold time', () {
    final wall = GymExercise(exId: 'ws', name: 'wall sit', sets: [GymSet(sec: 30), GymSet(sec: 30)]);
    expect(wall.isTimed, isTrue);
    final rx = LoadPrescriber(history: const [], profile: male80, now: day0);
    expect(rx.lighterFor(wall, 'legsEasy'), isTrue);
    final ps = run(wall, 6, (_) => 'legsEasy');
    final sec = [for (final p in ps) p.reps];
    for (var i = 1; i < sec.length; i++) {
      expect(sec[i], greaterThanOrEqualTo(sec[i - 1]), reason: '$sec');
    }
    expect(sec.last, greaterThan(sec.first), reason: '$sec');
    // A loading day afterwards holds longer than the legs-easy level (no second cut), a deload
    // week the same time.
    final then = run(wall, 5, (w) => w < 4 ? 'legsEasy' : null);
    expect(then[4].reps, greaterThanOrEqualTo(then[3].reps));
    final deload = run(wall, 5, (w) => w < 4 ? 'legsEasy' : 'recovery');
    expect(deload[4].reps, greaterThanOrEqualTo(deload[3].reps));
  });

  test('normal history still wins: lighter sessions are no anchor next to loading ones', () {
    final squat = GymExercise(exId: '0043', name: 'barbell full squat', sets: [GymSet(reps: 6), GymSet(reps: 6), GymSet(reps: 6)]);
    // Loading weeks then one legs-easy week: the next loading prescription follows the loading weeks.
    final ps = run(squat, 5, (w) => w == 3 ? 'legsEasy' : null);
    expect(ps[3].weight, lessThan(ps[2].weight));
    expect(ps[4].weight, greaterThanOrEqualTo(ps[2].weight));
  });
}
