import 'dart:math';

import '../data/exercise_db.dart';
import '../data/models.dart';

/// Load increment for an exercise (kg). Lower-body barbell lifts progress faster
/// than upper-body or isolation work (practice-based, cf. NSCA guidelines).
double loadIncrement(Exercise? e) {
  if (e == null) return 2.5;
  final lower = const {'upper legs', 'lower legs'}.contains(e.bodyPart) || e.target == 'glutes';
  switch (e.equipment) {
    case 'barbell':
    case 'trap bar':
    case 'smith machine':
      return lower ? 5 : 2.5;
    case 'dumbbell':
    case 'kettlebell':
      return 2;
    case 'body weight':
    case 'band':
    case 'resistance band':
      return 0;
    default:
      return 2.5;
  }
}

enum ProgressionKind { increase, addReps, hold, deload }

class Progression {
  final ProgressionKind kind;
  final double weight;
  final int reps;
  const Progression(this.kind, this.weight, this.reps);
}

/// Double progression (Helms et al. 2018, "The Muscle and Strength Pyramid"):
/// work within a rep range; once every work set reaches the top of the range at
/// RPE ≤ 9, add load and restart at the bottom of the range.
Progression? suggestProgression(GymExercise planned, List<GymSet>? last, Exercise? info) {
  final work = last?.where((s) => !s.warmup && s.done).toList() ?? const [];
  if (work.isEmpty) return null;
  final top = planned.repMax ?? planned.workSets.fold<int>(0, (a, s) => max(a, s.reps));
  final bottom = planned.repMin ?? max(1, top - 4);
  if (top <= 0) return null;
  final w = work.map((s) => s.weight).reduce(max);
  final atTop = work.every((s) => s.reps >= top);
  final hardRpe = work.any((s) => (s.rpe ?? 8) >= 9.5);
  final missed = work.where((s) => s.reps < bottom).length;
  final inc = loadIncrement(info);
  if (atTop && !hardRpe && inc > 0) return Progression(ProgressionKind.increase, w + inc, bottom);
  if (atTop && inc == 0) return Progression(ProgressionKind.addReps, w, top + 1);
  if (missed >= (work.length / 2).ceil() && w > 0) {
    return Progression(ProgressionKind.deload, roundToPlate(w * 0.9), bottom);
  }
  final minReps = work.map((s) => s.reps).reduce(min);
  if (minReps < top) return Progression(ProgressionKind.addReps, w, minReps + 1);
  return Progression(ProgressionKind.hold, w, top);
}

double roundToPlate(double kg, [double step = 2.5]) => (kg / step).round() * step;

/// Ramp-up warm-up sets for a working weight (practice-based: ~40/60/80 %).
List<GymSet> warmupSets(double workWeight, {double bar = 20}) {
  if (workWeight <= 0) return [GymSet(reps: 12, type: SetType.warmup)];
  if (workWeight <= bar * 1.5) return [GymSet(weight: roundToPlate(workWeight * 0.5), reps: 10, type: SetType.warmup)];
  final out = <GymSet>[GymSet(weight: bar, reps: 10, type: SetType.warmup)];
  for (final (pct, reps) in const [(0.4, 8), (0.6, 5), (0.8, 3)]) {
    final w = roundToPlate(workWeight * pct);
    if (w > out.last.weight && w < workWeight) out.add(GymSet(weight: w, reps: reps, type: SetType.warmup));
  }
  return out;
}

/// Plates per side for a target barbell weight. Returns the plates and the
/// remainder that cannot be loaded with the available plates.
(List<double>, double) platesPerSide(double total, {double bar = 20, List<double>? available}) {
  final plates = available ?? const [25, 20, 15, 10, 5, 2.5, 1.25];
  var side = (total - bar) / 2;
  final out = <double>[];
  if (side <= 0) return (out, 0);
  for (final p in plates) {
    while (side >= p - 1e-6) {
      out.add(p);
      side -= p;
    }
  }
  return (out, side * 2);
}
