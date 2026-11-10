import '../core/sport.dart';
import '../data/models.dart';
import '../services/zones.dart';

/// Duration and distance of a planned workout as every screen shows them (Today card,
/// calendar, planned-workout page, editor, week strip): one computation, so a workout never
/// reads "40 min · 5,8 km" on Home and "≈ 36 min · 5,5 km" in the editor.
///
/// * Structured endurance workouts: from the steps ([estimateStepsSec] – the formula the
///   generator, editors and program list use), marked as an estimate ("≈ 38 min").
/// * Gym: the workout's own exercises, else its program's estimate.
/// * Everything else: the stored minutes / km.
class PlanAmount {
  const PlanAmount(this.minutes, this.km, {this.estimated = false});
  final int minutes;
  final double? km;
  final bool estimated;
}

PlanAmount planAmount(PlannedWorkout p, UserProfile profile, {List<WorkoutTemplate> templates = const []}) {
  if (p.sport == Sport.gym) {
    if (p.exercises.isNotEmpty) return PlanAmount(estimateGymMinutes(p.exercises), null, estimated: true);
    final t = templates.where((t) => t.id == p.templateId).firstOrNull;
    if (t != null && t.exercises.isNotEmpty) return PlanAmount(t.estimatedMinutes, null, estimated: true);
    return PlanAmount(p.durationMin, null);
  }
  if (p.steps.isEmpty) return PlanAmount(p.durationMin, (p.distanceKm ?? 0) > 0 ? p.distanceKm : null);
  final sec = estimateStepsSec(p.steps, p.sport, profile);
  final km = stepsKm(p.steps, p.sport, profile);
  return PlanAmount(
    sec <= 0 ? p.durationMin : (sec / 60).round().clamp(1, 600),
    km ?? ((p.distanceKm ?? 0) > 0 ? p.distanceKm : null),
    estimated: sec > 0,
  );
}

/// Distance of structured steps in km (null without any): distance steps as given, timed run
/// steps at their pace target (else the easy pace), timed rides at ~20 km/h (Z1) / 27 km/h.
double? stepsKm(List<WorkoutStep> steps, Sport sport, UserProfile p) {
  final easy = PaceZones(Vdot.of(p.athlete) ?? Vdot.defaultFor(p.level)).easySlow;
  var m = 0.0;
  for (final s in steps) {
    if (s.distanceM != null) {
      m += s.distanceM!;
    } else if (s.durationSec != null) {
      if (sport == Sport.run && s.zone != 'walk') m += s.durationSec! / ((s.paceMin ?? easy) + (s.paceMax ?? easy)) * 2000;
      if (sport == Sport.ride) m += s.durationSec! / 3600 * (s.zone == 'Z1' ? 20000 : 27000);
    }
  }
  return m <= 0 ? null : double.parse((m / 1000).toStringAsFixed(1));
}

/// "≈ 38 min · 5,5 km" (swims: "≈ 45 min · 1500 m").
String planAmountText(PlannedWorkout p, UserProfile profile, {List<WorkoutTemplate> templates = const []}) {
  final a = planAmount(p, profile, templates: templates);
  final u = profile.units;
  return [
    '${a.estimated ? '≈ ' : ''}${a.minutes} min',
    if (a.km != null) p.sport == Sport.swim ? u.swimDist(a.km! * 1000) : u.dist(a.km! * 1000, digits: 1),
  ].join(' · ');
}
