import '../data/models.dart';

/// What the athlete's health limitations (setup: knee, back, shoulder, hip, ankle,
/// heart) mean for the plan – one place the plan generator, the recalibration and the
/// strength side read (docs/training-science.md §9.1).
///
/// * knee / hip / ankle (incl. Achilles): less running impact – run volume grows at the
///   EASY rate (5 %/week), the long run by ≤ 5 %, no strides or VO2max intervals (high
///   ground-reaction forces), ≤ 1 quality run a week, one easy run a week (with ≥ 3) is
///   replaced by an easy ride, beginners start with run/walk.
/// * back: no heavy axial loading in strength sessions ([avoidAxialLoading] – the strength
///   programs read this flag; the generator only adds a note).
/// * shoulder: swimming as technique / easy endurance (no CSS sets, no paddles), ~20 %
///   less swim volume; no heavy overhead pressing ([avoidOverhead]).
/// * heart (heart / blood pressure): intensity capped at threshold – no VO2max intervals,
///   no strides / sprints, ≤ 1 quality session per sport and week; strength with reps in
///   reserve and no breath holding ([noStraining]).
class HealthFlags {
  const HealthFlags({
    this.lowImpactRun = false,
    this.kneeOrHip = false,
    this.avoidAxialLoading = false,
    this.avoidOverhead = false,
    this.capIntensity = false,
  });

  /// Knee, hip or ankle / Achilles: reduce running impact.
  final bool lowImpactRun;

  /// Knee or hip: pain-free range of motion in strength exercises.
  final bool kneeOrHip;

  /// Back: no heavy axially loaded lifts (back squat, deadlift, overhead press standing).
  final bool avoidAxialLoading;

  /// Shoulder: no heavy overhead work, no swim paddles / hard swim sets.
  final bool avoidOverhead;

  /// Heart / blood pressure: nothing above threshold intensity, no straining.
  final bool capIntensity;

  /// Same as [capIntensity] for strength: reps in reserve, no Valsalva.
  bool get noStraining => capIntensity;

  /// No VO2max intervals, strides or sprints in running (impact or intensity limit).
  bool get noHardRunning => lowImpactRun || capIntensity;

  bool get any => lowImpactRun || avoidAxialLoading || avoidOverhead || capIntensity;

  static HealthFlags of(UserProfile p) => fromList(p.athlete.limitations);

  static HealthFlags fromList(List<String> limitations) {
    final l = limitations.toSet();
    return HealthFlags(
      lowImpactRun: l.contains('knee') || l.contains('hip') || l.contains('ankle') || l.contains('achilles'),
      kneeOrHip: l.contains('knee') || l.contains('hip'),
      avoidAxialLoading: l.contains('back'),
      avoidOverhead: l.contains('shoulder'),
      capIntensity: l.contains('heart') || l.contains('bloodpressure'),
    );
  }
}
