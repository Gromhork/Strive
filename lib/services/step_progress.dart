import '../core/sport.dart';
import '../data/models.dart';

/// Pure helpers for structured workouts (no Flutter, unit-testable).

bool _same(WorkoutStep a, WorkoutStep b) =>
    a.kind == b.kind && a.zone == b.zone && a.distanceM == b.distanceM && a.durationSec == b.durationSec;

/// Position of work step [i] inside a block of identical repeats, e.g.
/// `8 × [100 m CSS + 15 s rest]` → (rep: 3, reps: 8) for the third 100 m.
/// Recovery steps between repeats belong to the preceding repetition.
/// Returns null when the step is not part of a repeat block.
({int rep, int reps})? repInfo(List<WorkoutStep> steps, int i) {
  if (i < 0 || i >= steps.length) return null;
  var w = i;
  if (steps[i].kind == 'recovery') {
    if (i == 0 || !steps[i - 1].isWork) return null;
    w = i - 1;
  }
  final st = steps[w];
  if (!st.isWork) return null;
  // Walk backwards over [same] or [same, recovery] pairs.
  var before = 0;
  var j = w;
  while (true) {
    if (j - 1 >= 0 && _same(steps[j - 1], st)) {
      j -= 1;
    } else if (j - 2 >= 0 && steps[j - 1].kind == 'recovery' && _same(steps[j - 2], st)) {
      j -= 2;
    } else {
      break;
    }
    before++;
  }
  var after = 0;
  j = w;
  while (true) {
    if (j + 1 < steps.length && _same(steps[j + 1], st)) {
      j += 1;
    } else if (j + 2 < steps.length && steps[j + 1].kind == 'recovery' && _same(steps[j + 2], st)) {
      j += 2;
    } else {
      break;
    }
    after++;
  }
  final reps = before + after + 1;
  return reps > 1 ? (rep: before + 1, reps: reps) : null;
}

/// Rough duration of a step in seconds (distance steps estimated from their pace target).
int approxStepSec(WorkoutStep s, Sport sport) {
  if (s.durationSec != null) return s.durationSec!;
  final d = s.distanceM ?? 0;
  if (sport == Sport.swim) return (d / 100 * (s.paceMax ?? 120)).round();
  if (sport == Sport.ride) return (d / 1000 * 120).round(); // ~30 km/h
  final pace = ((s.paceMin ?? 360) + (s.paceMax ?? 360)) / 2;
  return (d / 1000 * pace).round();
}

/// Estimated seconds left in the workout: rest of the current step + all following steps.
int workoutRemainingSec(List<WorkoutStep> steps, int index, Sport sport, {int stepElapsed = 0, double stepDistance = 0}) {
  if (index >= steps.length) return 0;
  final cur = steps[index];
  var total = 0;
  if (cur.distanceM != null && cur.distanceM! > 0) {
    final left = (1 - stepDistance / cur.distanceM!).clamp(0.0, 1.0);
    total += (approxStepSec(cur, sport) * left).round();
  } else {
    total += (approxStepSec(cur, sport) - stepElapsed).clamp(0, 1 << 30);
  }
  for (var k = index + 1; k < steps.length; k++) {
    total += approxStepSec(steps[k], sport);
  }
  return total;
}

/// Meters left in the workout (distance steps only), or null if it has none.
double? workoutRemainingM(List<WorkoutStep> steps, int index, {double stepDistance = 0}) {
  if (index >= steps.length) return 0;
  var any = false;
  var total = 0.0;
  for (var k = index; k < steps.length; k++) {
    final d = steps[k].distanceM;
    if (d == null) continue;
    any = true;
    total += k == index ? (d - stepDistance).clamp(0.0, d) : d;
  }
  return any ? total : null;
}
