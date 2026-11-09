import 'dart:math';

import '../core/format.dart';
import '../data/models.dart';
import 'gym_tools.dart';

/// Why the next session of an exercise looks like it does. Machine-readable so the UI
/// can explain the suggestion ("+2.5 kg: all sets at the top with reps in reserve").
enum ProgressReason {
  /// All work sets reached the top of the range → one load step, back to the bottom.
  topReached,

  /// Top reached with clear reserve (easy, or beginner) → two load steps.
  topWithReserve,

  /// Top reached, but at the limit (RIR 0) → same load and reps once more.
  topAtLimit,

  /// The next load step would be > ~10 % of the load → reps beyond the range first.
  microload,

  /// Inside the range → one more rep per set.
  addReps,

  /// Inside the range with reserve (easy, or a beginner with even sets) → two more reps.
  addRepsFast,

  /// Bodyweight exercise without a load step (push-ups, …) → more reps.
  repsNoLoad,

  /// Last session at the limit → repeat the same reps.
  holdLimit,

  /// Last two sessions hard without progress → repeat the same reps.
  holdHard,

  /// Most sets just below the range (≤ 1 rep) → same weight, reach the bottom.
  missedHold,

  /// Reps clearly missed → lighter.
  missedReduce,

  /// Last two sessions below the session before them → hold.
  performanceDip,

  /// Last two sessions clearly weaker → ~5–10 % lighter.
  performanceDrop,

  /// Three sessions at the same weight without progress → ~10 % reset.
  stall,
}

/// Direction of the recent e1RM trend of an exercise.
enum E1rmTrend { progressing, plateau, regressing, unknown }

/// One past session of an exercise: its done work sets (no warm-ups / drop sets).
class ProgressEntry {
  ProgressEntry(this.date, this.sets, {this.effort, this.bodyKg = 0});
  final DateTime date;
  final List<GymSet> sets;

  /// Effort rating given after the last work set (null = not given).
  final Effort? effort;

  /// Body load per rep added to the set weight (bodyweight exercises), else 0.
  final double bodyKg;

  double get topWeight => sets.map((s) => s.weight).reduce(max);

  /// Work sets at the top weight (back-off sets would distort rep comparisons).
  List<GymSet> get topSets => sets.where((s) => (s.weight - topWeight).abs() < 1e-6).toList();
}

/// Effort of a session as reps in reserve after the last work set.
class EffortEstimate {
  const EffortEstimate(this.rir, {this.inferred = false});

  /// Reps in reserve; null = unknown (treated like "about right", RIR ≈ 2).
  final double? rir;

  /// Derived from the data (rep drop-off, reps vs. range), not rated by the user.
  final bool inferred;

  bool get easy => rir != null && rir! >= 3;
  bool get hard => rir != null && rir! <= 1.5;
  bool get limit => rir != null && rir! <= 0.5;

  @override
  String toString() => 'Effort(rir: $rir${inferred ? ', inferred' : ''})';
}

/// Effort of the session with work sets [work] (rep range top [top]).
///
/// Order of evidence: the quick rating [chip] (Leicht / Passend / Schwer / Limit) →
/// logged set RPEs (RIR = 10 − RPE, hardest set; Zourdos et al. 2016) → a set marked as
/// failure → inference from the data:
/// * **Rep drop-off across sets at the same load.** A set that stops 3+ reps short of
///   failure can be repeated with the same reps after normal rests; sets taken close to
///   failure lose reps from set to set (Willardson & Burkett 2005: large rep losses over
///   consecutive sets to failure, more with short rests; Refalo et al. 2023: fatigue
///   rises steeply over the last 2–3 reps before failure). Drop ≥ 30 % (and ≥ 2 reps) →
///   limit (RIR 0); ≥ 15 % (and ≥ 2 reps) → hard (RIR 1).
/// * **Reps vs. range.** Every set ≥ 2 reps above the top of the range without a
///   drop-off → the load was clearly light (easy, RIR ≥ 3).
/// Otherwise the effort is unknown and treated as "about right". Self-rated RIR is
/// accurate to ~1 rep close to failure, less so far from it (Halperin et al. 2022),
/// which is why the rating only modulates the step size by one notch.
EffortEstimate estimateEffort(List<GymSet> work, {Effort? chip, required int top}) {
  if (chip != null) return EffortEstimate(chip.rir);
  final rpes = work.map((s) => s.rpe).whereType<double>().toList();
  if (rpes.isNotEmpty) return EffortEstimate((10 - rpes.reduce(max)).clamp(0, 5).toDouble());
  if (work.any((s) => s.type == SetType.failure)) return const EffortEstimate(0);
  if (work.isEmpty) return const EffortEstimate(null, inferred: true);
  final w = work.map((s) => s.weight).reduce(max);
  final reps = [
    for (final s in work)
      if ((s.weight - w).abs() < 1e-6) s.reps,
  ];
  if (reps.length >= 2) {
    final peak = reps.reduce(max), last = reps.last;
    final drop = (peak - last) / peak;
    if (drop >= 0.3 && peak - last >= 2) return const EffortEstimate(0, inferred: true);
    if (drop >= 0.15 && peak - last >= 2) return const EffortEstimate(1, inferred: true);
  }
  if (top > 0 && reps.every((r) => r >= top + 2)) return const EffortEstimate(4, inferred: true);
  return const EffortEstimate(null, inferred: true);
}

/// Theil–Sen slope: the median of all pairwise slopes (Sen 1968). Unlike least squares
/// it ignores one bad (or one great) day – ~29 % breakdown point.
double theilSenSlope(List<(double, double)> pts) {
  final slopes = <double>[];
  for (var i = 0; i < pts.length; i++) {
    for (var j = i + 1; j < pts.length; j++) {
      final dx = pts[j].$1 - pts[i].$1;
      if (dx.abs() > 1e-9) slopes.add((pts[j].$2 - pts[i].$2) / dx);
    }
  }
  return slopes.isEmpty ? 0 : _median(slopes);
}

/// Performance of one session: top-set e1RM of the total load (Epley; reps in reserve
/// from a logged RPE, else 1), or – when there is no load at all (push-ups) – the mean
/// reps per set.
double sessionPerformance(ProgressEntry e) {
  var best = 0.0;
  for (final s in e.sets) {
    final load = s.weight + e.bodyKg;
    if (load <= 0) continue;
    final rir = s.rpe != null ? (10 - s.rpe!).clamp(0, 5).round() : 1;
    best = max(best, e1rm(load, s.reps + rir));
  }
  if (best > 0) return best;
  return e.sets.fold<double>(0, (a, s) => a + s.reps) / e.sets.length;
}

/// e1RM trend over the last ≤ 6 sessions within 8 weeks (newest first in [hist]):
/// Theil–Sen slope × time span relative to the median. ≥ +2 % → progressing,
/// ≤ −3 % → regressing (day-to-day e1RM noise is ~2–4 %), else plateau. Needs ≥ 3
/// sessions over ≥ 10 days.
E1rmTrend e1rmTrend(List<ProgressEntry> hist) {
  if (hist.length < 3) return E1rmTrend.unknown;
  final newest = hist.first.date;
  final pts = [
    for (final h in hist.take(6))
      if (newest.difference(h.date).inDays <= 56) (h.date.difference(newest).inHours / 24, sessionPerformance(h)),
  ];
  if (pts.length < 3) return E1rmTrend.unknown;
  final span = pts.map((p) => p.$1).reduce(max) - pts.map((p) => p.$1).reduce(min);
  final med = _median(pts.map((p) => p.$2).toList());
  if (span < 10 || med <= 0) return E1rmTrend.unknown;
  final change = theilSenSlope(pts) * span / med;
  if (change >= 0.02) return E1rmTrend.progressing;
  if (change <= -0.03) return E1rmTrend.regressing;
  return E1rmTrend.plateau;
}

/// Outcome of [smartProgression] – a [Progression] with the reason, the effort the
/// decision was based on and the e1RM trend.
class SmartProgression extends Progression {
  const SmartProgression(
    super.kind,
    super.weight,
    super.reps,
    super.setReps, {
    required this.reason,
    required this.effort,
    this.trend = E1rmTrend.unknown,
  });
  final ProgressReason reason;
  final EffortEstimate effort;
  final E1rmTrend trend;

  @override
  String toString() => 'SmartProgression($kind, $weight × $reps $setReps, $reason, $effort, $trend)';
}

/// Autoregulated, multi-session double progression.
///
/// Base: double progression (Helms et al. 2018; Plotkin et al. 2022 – adding reps or
/// load progresses strength and size equally well): add reps inside the range
/// [bottom]–[top], then add [increment] and restart at the bottom. On top of that:
/// * **Effort** ([estimateEffort]) modulates the step: top reached with reserve → two
///   load steps, at the limit → hold once more; inside the range easy → +2 reps, at
///   the limit → repeat; below the range at the limit → lighter even when only 1 rep
///   short. RIR-based autoregulation is at least as effective as fixed loading (Helms
///   et al. 2018; Graham & Cleather 2021).
/// * **Several sessions:** three sessions at the same weight without more reps (and no
///   rising e1RM trend) → ~10 % reset; the last two sessions both worse than the one
///   before (same load and ≥ 1 rep fewer per set, or lighter without more reps) → hold,
///   or ~7.5 % lighter when ≥ 2 reps per set were lost – a reactive deload
///   (Bell et al. 2023 deload consensus). Two hard sessions in a row without progress →
///   hold instead of adding reps.
/// * **Training level** [level]: beginners progress faster (+2 reps with even sets,
///   two load steps when not hard – novices adapt fastest and underestimate their
///   reserve, Steele et al. 2017); advanced lifters only take bigger steps on an
///   explicit "easy" rating (trained lifters gain less per unit of stimulus,
///   Androulakis-Korakakis et al. 2020). See docs/training-science.md §2.4a.
/// * **Microloading:** when one [increment] is > 10 % of the total load (light
///   dumbbells, isolation work), reps go beyond the top first (up to +25 %; hypertrophy
///   is similar across ~6–30 reps near failure, Schoenfeld et al. 2017), then the load
///   goes up with the reps matched to the same e1RM.
/// [bodyKg] is the body load per rep of bodyweight exercises (set weights are added
/// load then); exercises without a load step ([increment] = 0) progress by reps.
SmartProgression? smartProgression(
  List<ProgressEntry> hist, {
  required int bottom,
  required int top,
  required double increment,
  String level = 'intermediate',
  double bodyKg = 0,
}) {
  if (hist.isEmpty || top <= 0) return null;
  final last = hist.first;
  final work = last.sets.where((s) => !s.warmup && s.type != SetType.drop && s.reps > 0).toList();
  if (work.isEmpty) return null;
  if (bottom > top) bottom = top;
  final beginner = level == 'beginner', advanced = level == 'advanced';
  final w = work.map((s) => s.weight).reduce(max);
  final reps = work.map((s) => s.reps).toList();
  final total = w + bodyKg; // load per rep
  final eff = estimateEffort(work, chip: last.effort, top: top);
  final trend = e1rmTrend(hist);
  final explicitEasy = eff.easy && !eff.inferred;
  final loaded = increment > 0 && total > 0;

  SmartProgression out(ProgressionKind k, double weight, int r, List<int> setReps, ProgressReason why) =>
      SmartProgression(k, weight, r, setReps, reason: why, effort: eff, trend: trend);
  SmartProgression hold(ProgressReason why, {int? floor}) {
    final t = [for (final r in reps) min(top, max(r, floor ?? bottom))];
    return out(ProgressionKind.hold, w, t.reduce(min), t, why);
  }

  // 1. Stall: same weight 3× without more reps and no rising trend → ~10 % reset.
  if (loaded && (bodyKg <= 0 || w > 0) && trend != E1rmTrend.progressing && _stalled(hist, top)) {
    // Bodyweight exercises shed added load only (never into assistance on a stall).
    return out(ProgressionKind.reset, bodyKg > 0 ? max(0.0, w - 0.1 * total) : w * 0.9, bottom, const [], ProgressReason.stall);
  }

  // 2. Performance dropped in the last two sessions.
  if (hist.length >= 3 && hist[0].date.difference(hist[2].date).inDays <= 42) {
    final ref = hist[2];
    final d0 = _shortfall(hist[0], ref), d1 = _shortfall(hist[1], ref);
    if (d0 != null && d1 != null) {
      if (loaded && (d0 >= 2 || eff.limit)) {
        return out(ProgressionKind.deload, w - 0.075 * total, bottom, const [], ProgressReason.performanceDrop);
      }
      return hold(ProgressReason.performanceDip);
    }
  }

  final atTop = reps.every((r) => r >= top);
  if (atTop) {
    if (increment <= 0) {
      // No load step (push-ups, bodyweight leg work): keep adding reps beyond the range.
      final step = eff.easy ? 2 : 1;
      final r = reps.reduce(min) + step;
      return out(ProgressionKind.addReps, w, r, [for (final x in reps) max(x, r - step) + step], ProgressReason.repsNoLoad);
    }
    if (eff.limit) return hold(ProgressReason.topAtLimit, floor: top);
    if (total > 0 && increment / total > 0.10) {
      // Microloading: one step is a big jump – reps beyond the top first.
      final int cap = top + max(2, (top * 0.25).round());
      final minR = reps.reduce(min);
      if (minR < cap) {
        final step = explicitEasy ? 2 : 1; // reps above the top are planned here, not a sign of ease
        final t = <int>[for (final r in reps) min(cap, max(r, minR) + step)];
        return out(ProgressionKind.addReps, w, t.reduce(min), t, ProgressReason.microload);
      }
      // Cap reached: next load with the reps that match the same e1RM (minus 1 for safety).
      final e = e1rm(total, minR);
      final matched = (30 * (e / (total + increment) - 1)).floor() - 1;
      return out(ProgressionKind.increase, w + increment, matched.clamp(bottom, top), const [], ProgressReason.topReached);
    }
    var k = 1;
    if (explicitEasy || (eff.easy && !advanced) || (beginner && !eff.hard)) k = 2;
    if (trend == E1rmTrend.regressing) k = 1;
    // Never more than ~10 % at once (NSCA: ~2–10 % steps).
    if (total > 0) k = min(k, max(1, (0.10 * total / increment + 1e-9).floor()));
    return out(
      ProgressionKind.increase,
      w + k * increment,
      bottom,
      const [],
      k > 1 ? ProgressReason.topWithReserve : ProgressReason.topReached,
    );
  }

  // Reps clearly missed (most sets below the bottom).
  final missed = reps.where((r) => r < bottom).length;
  if (missed >= (work.length / 2).ceil()) {
    final median = _median(reps.map((r) => r.toDouble()).toList());
    final short = bottom - median;
    if (!loaded) {
      return out(ProgressionKind.addReps, w, reps.reduce(min) + 1, [for (final r in reps) r + 1], ProgressReason.repsNoLoad);
    }
    if (short > 1 || (short >= 1 && eff.limit)) {
      final target = short <= 3 ? w - increment : min(w - increment, w - 0.1 * total);
      return out(ProgressionKind.deload, target, bottom, const [], ProgressReason.missedReduce);
    }
    return out(ProgressionKind.hold, w, bottom, [for (final _ in work) bottom], ProgressReason.missedHold);
  }

  // Inside the range.
  if (eff.limit) return hold(ProgressReason.holdLimit);
  if (eff.hard && hist.length >= 2) {
    final prev = hist[1];
    final prevEff = estimateEffort(prev.sets, chip: prev.effort, top: top);
    final sameLoad = (prev.topWeight - w).abs() < 1e-6;
    int sum(List<GymSet> s) => s.fold(0, (a, x) => a + x.reps);
    if (prevEff.hard && sameLoad && sum(work) <= sum(prev.sets)) return hold(ProgressReason.holdHard);
  }
  var step = 1;
  final even = reps.toSet().length == 1;
  if (explicitEasy || (eff.easy && !advanced) || (beginner && !eff.hard && even)) step = 2;
  if (trend == E1rmTrend.regressing) step = 1;
  if (increment <= 0 && reps.every((r) => r >= top)) step = 1;
  final t = [for (final r in reps) r < top ? min(top, max(r + step, bottom)) : top];
  return out(ProgressionKind.addReps, w, t.reduce(min), t, step > 1 ? ProgressReason.addRepsFast : ProgressReason.addReps);
}

/// Stall: the last three sessions (within ~6 weeks) used the same top weight, never
/// reached the top of the range on all sets, and the latest did not beat the oldest of
/// them in total reps.
bool _stalled(List<ProgressEntry> hist, int top) {
  if (hist.length < 3) return false;
  final h = hist.take(3).toList();
  if (h.first.date.difference(h.last.date).inDays > 42) return false;
  final ws = h.map((e) => e.topWeight).toList();
  if (ws.any((w) => (w - ws.first).abs() > 0.01)) return false;
  if (h.any((e) => e.sets.every((s) => s.reps >= top))) return false;
  int total(ProgressEntry e) => e.sets.fold(0, (a, s) => a + s.reps);
  return total(h.first) <= total(h.last);
}

/// Reps per set lost by session [a] compared with the earlier session [b], or null when
/// [a] was not worse: same load (±1 %) and ≥ 1 rep fewer per set on average, or a
/// lighter load without more reps (then 0). A heavier load with fewer reps is expected
/// and not counted.
double? _shortfall(ProgressEntry a, ProgressEntry b) {
  final la = a.topWeight + a.bodyKg, lb = b.topWeight + b.bodyKg;
  final sa = a.topSets, sb = b.topSets;
  final n = min(sa.length, sb.length);
  if (n == 0) return null;
  double mean(List<GymSet> s) => s.take(n).fold<double>(0, (x, y) => x + y.reps) / n;
  final ra = mean(sa), rb = mean(sb);
  if ((la - lb).abs() <= max(0.01 * lb.abs(), 0.25)) return ra <= rb - 1 ? rb - ra : null;
  if (la < lb && ra <= rb) return rb - ra;
  return null;
}

double _median(List<double> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}
