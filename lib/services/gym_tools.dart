import 'dart:math';

import '../data/exercise_db.dart';
import '../data/models.dart';
import 'exercise_class.dart';

/// Smallest sensible load step (kg) for progressing an exercise: +5 kg for lower-body
/// barbell / sled compounds, +2.5 kg for upper-body barbell and machine/cable work,
/// +2 kg for dumbbells (+1 kg for light dumbbells < 10 kg, where 2 kg would be a 20–30 %
/// jump), +2.5 kg added load for pull-ups / chin-ups / dips, 0 for exercises that are
/// progressed by reps (push-ups, bodyweight leg and core work). Practice-based, in line
/// with NSCA guidance of ~2–10 % steps (larger for lower body).
double loadIncrement(Exercise? e, {double weight = 0, bool? bodyweight}) {
  if (e == null) return bodyweight == true ? 0 : 2.5;
  final lift = classifyLift(e.id, e.name, info: e);
  if (bodyweight ?? lift.bodyweight) return lift.loadableBodyweight ? 2.5 : 0;
  final lowerCompound = lift.lower && lift.isCompound;
  switch (e.equipment) {
    case 'barbell':
    case 'olympic barbell':
    case 'trap bar':
    case 'smith machine':
    case 'ez barbell':
      return lowerCompound ? 5 : 2.5;
    case 'dumbbell':
    case 'kettlebell':
      return weight > 0 && weight < 10 ? 1 : 2;
    case 'sled machine':
    case 'leverage machine':
    case 'cable':
      return lowerCompound && lift.move == Movement.squat ? 5 : 2.5;
    case 'body weight':
    case 'band':
    case 'resistance band':
      return lift.loadableBodyweight ? 2.5 : 0;
    default:
      return 2.5;
  }
}

/// Outcome of the double-progression rule for the next session ([reset]: lighter after
/// a stall of several sessions).
enum ProgressionKind { increase, addReps, hold, deload, reset }

class Progression {
  final ProgressionKind kind;
  final double weight;

  /// Lowest per-set rep target (the start of the range after a load increase).
  final int reps;

  /// Per-work-set rep targets (same order as last time).
  final List<int> setReps;
  const Progression(this.kind, this.weight, this.reps, [this.setReps = const []]);

  @override
  String toString() => 'Progression($kind, $weight × $reps $setReps)';
}

/// Double progression (Helms et al. 2018, "The Muscle and Strength Pyramid"; Plotkin et
/// al. 2022: adding reps or load progresses equally well):
/// * keep the weight and add reps set by set inside the rep range [bottom]–[top];
/// * when **every** work set reached the top (and the last set was not a grinder at
///   RPE ≥ 9.5), add the smallest step [increment] and restart at [bottom];
/// * reps clearly missed (most sets below [bottom]): keep the weight when it was close
///   (≤ 1 rep short), else go back one step (≤ 3 reps short) or ~10 % (more);
/// * exercises without a load step ([increment] = 0, e.g. push-ups) keep adding reps.
Progression? suggestProgression(List<GymSet>? last, {required int bottom, required int top, required double increment}) {
  final work = last?.where((s) => !s.warmup && s.type != SetType.drop && s.done && s.reps > 0).toList() ?? const [];
  if (work.isEmpty || top <= 0) return null;
  if (bottom > top) bottom = top;
  final w = work.map((s) => s.weight).reduce(max);
  final reps = work.map((s) => s.reps).toList();
  final atTop = reps.every((r) => r >= top);
  final hardRpe = work.any((s) => (s.rpe ?? 8) >= 9.5);
  if (atTop) {
    if (increment > 0 && !hardRpe) return Progression(ProgressionKind.increase, w + increment, bottom);
    if (increment > 0) return Progression(ProgressionKind.hold, w, top, [for (final _ in work) top]);
    // No load step: keep adding reps beyond the range.
    final r = reps.reduce(min) + 1;
    return Progression(ProgressionKind.addReps, w, r, [for (final x in reps) max(x, r - 1) + 1]);
  }
  final missed = reps.where((r) => r < bottom).length;
  if (missed >= (work.length / 2).ceil()) {
    final sorted = [...reps]..sort();
    final median = sorted[sorted.length ~/ 2];
    final short = bottom - median;
    if (increment > 0 && w > 0 && short > 1) {
      final target = short <= 3 ? w - increment : min(w - increment, w * 0.9);
      return Progression(ProgressionKind.deload, max(0, target), bottom);
    }
    if (increment <= 0 || w <= 0) {
      // Bodyweight / no load: beat last time by one rep.
      return Progression(ProgressionKind.addReps, w, reps.reduce(min) + 1, [for (final r in reps) r + 1]);
    }
    return Progression(ProgressionKind.hold, w, bottom, [for (final _ in work) bottom]);
  }
  final targets = [for (final r in reps) r < top ? max(r + 1, bottom) : top];
  return Progression(ProgressionKind.addReps, w, targets.reduce(min), targets);
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
