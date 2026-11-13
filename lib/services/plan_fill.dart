import 'dart:math';

import '../core/sport.dart';
import '../data/models.dart';
import '../widgets/plan_amount.dart';
import 'load_prescription.dart';
import 'plan_exercises.dart';

/// A planned workout logged as done without recording it ("Als erledigt eintragen"): the
/// session gets the plan's content instead of only a duration, so history, volume and set
/// statistics, muscle groups, the load progression and the plan compliance work as for a
/// recorded workout. The session is marked [Session.fromPlan] ("aus Plan übernommen"), gym
/// exercises also one by one ([GymExercise.fromPlan]): no records / best efforts and no pace or
/// power signal come from it, the load progression only holds on it, and the plan compliance
/// is 100 % by definition. The athlete can correct it afterwards on the edit page – that clears
/// the mark of what was corrected (the edited exercises; for endurance the session).
///
/// * Gym: the workout's exercises (its own, else its program's) with the weights the app
///   prescribes for this day ([LoadPrescriber.apply] – last used weights with the progression
///   step, setup 1RMs or the body-weight estimate, deload / taper adjusted), every set done at
///   its target reps.
/// * Run / ride / swim: the planned duration and distance as every screen shows them
///   ([planAmount], from the steps for structured workouts); swims also get their laps in the
///   athlete's pool. The average pace / speed follows from these. No splits, heart rate or
///   power – those would be invented measurements.
class PlanFill {
  const PlanFill({required this.minutes, this.km, this.exercises = const [], this.plannedSets, this.poolLengthM = 25});

  final int minutes;

  /// Planned distance (endurance), null when the plan has none.
  final double? km;
  final List<GymExercise> exercises;
  final int? plannedSets;
  final int poolLengthM;

  int get sets => exercises.fold(0, (a, e) => a + e.doneSets);

  /// Volume incl. the body load of bodyweight exercises (stored when the prescriber filled them).
  double get volume => exercises.fold(0.0, (a, e) => a + e.volume);

  /// Laps of a swim of [distanceM] in the athlete's pool.
  int lapsFor(double distanceM) => poolLengthM <= 0 ? 0 : (distanceM / poolLengthM).round();

  static PlanFill of(
    PlannedWorkout p, {
    required UserProfile profile,
    List<WorkoutTemplate> templates = const [],
    LoadPrescriber? prescriber,
  }) {
    final amount = planAmount(p, profile, templates: templates);
    if (p.sport != Sport.gym) {
      final pool = profile.athlete.poolLength > 0 ? profile.athlete.poolLength : 25;
      return PlanFill(minutes: amount.minutes, km: amount.km, poolLengthM: pool);
    }
    final source = plannedGymExercises(p, plannedProgramOf(p, templates), gymGoal: profile.athlete.gymGoal);
    final list = prescriber == null ? [for (final e in source) e.copy(resetDone: true)] : prescriber.apply(source, phase: gymLoadPhase(p));
    for (final e in list) {
      e
        ..effort = null
        ..fromPlan = true;
      final timed = e.isTimed;
      for (final s in e.sets) {
        if (timed) {
          // Timed holds: the planned hold time was held.
          if (s.sec <= 0) s.sec = s.targetSec ?? e.holdRange.$1;
          s.reps = 0;
        } else if (s.reps <= 0) {
          s.reps = s.target ?? e.repMin ?? 10;
        }
        s
          ..done = true
          ..amrap = false
          ..rpe = null;
        // The plan's reps / hold times and weight are what was asked for (also for a program's own
        // weights the prescriber kept): a later correction on the edit page is judged against them.
        if (!s.warmup && s.type != SetType.drop) {
          if (timed) {
            s.targetSec ??= s.sec;
          } else {
            s.target ??= s.reps;
          }
        }
      }
      final work = e.workSets.where((s) => s.type != SetType.drop).map((s) => s.weight);
      if (e.rxKg == null && work.isNotEmpty) e.rxKg = work.reduce(max);
    }
    final ex = list.where((e) => e.sets.isNotEmpty).toList();
    return PlanFill(minutes: amount.minutes, exercises: ex, plannedSets: ex.fold<int>(0, (a, e) => a + e.workSets.length));
  }
}

/// The session for [p] logged as done with [fill] (see [PlanFill]). [distanceM] / [minutes]
/// are the values the athlete confirmed; when they differ from the plan they are the
/// athlete's own numbers and the session is no longer "taken over from the plan" – except gym,
/// whose sets always come from the plan.
Session sessionFromPlan(
  PlannedWorkout p,
  PlanFill fill, {
  required String id,
  required DateTime start,
  required String title,
  int? minutes,
  double? distanceM,
  int? rpe,
  String notes = '',
  double? bodyWeightKg,
}) {
  // A plan without a duration (0 min) never stores a 0-s session: the caller's value, else 1 min.
  final min = max(1, minutes ?? fill.minutes);
  final planM = (fill.km ?? 0) * 1000;
  final m = p.sport == Sport.gym ? 0.0 : (distanceM ?? planM);
  // Without a planned duration the entered one is no deviation from the plan.
  final sameTime = fill.minutes <= 0 || min == fill.minutes;
  final asPlanned = p.sport == Sport.gym ? fill.exercises.isNotEmpty : (sameTime && (m - planM).abs() < 1);
  return Session(
    id: id,
    sport: p.sport,
    title: title,
    start: start,
    durationSec: min * 60,
    rpe: rpe,
    notes: notes,
    exercises: p.sport == Sport.gym ? fill.exercises : const [],
    distanceM: m,
    laps: p.sport == Sport.swim ? fill.lapsFor(m) : 0,
    poolLengthM: p.sport == Sport.swim ? fill.poolLengthM : 25,
    indoor: true,
    templateId: p.templateId,
    planId: p.id,
    fromPlan: asPlanned,
    plannedSets: p.sport == Sport.gym ? fill.plannedSets : null,
    bodyWeightKg: p.sport == Sport.gym && bodyWeightKg != null && bodyWeightKg > 0 ? bodyWeightKg : null,
  );
}
