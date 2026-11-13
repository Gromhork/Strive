import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'plan_exercises.dart';

/// What deleting programs does to the plan. Planned gym workouts reference their program
/// ([PlannedWorkout.templateId]) instead of copying its exercises, so a deleted program would
/// leave them empty: they keep a copy of its exercises as they show them now (with the plan's
/// day adaptations, [PlannedWorkout.gymMods]); gym days assigned to it in the plan settings
/// ([AthleteData.gymPlanA] / [AthleteData.gymPlanB]) lose the assignment (the plan picks their
/// program again). The confirmation names both ([upcoming], [assignedDays]).
class ProgramDeletion {
  const ProgramDeletion({this.plans = const {}, this.upcoming = 0, this.assignedDays = const [], this.athlete});

  /// Planned workouts that keep the exercises: plan id → fields to update.
  final Map<String, Map<String, dynamic>> plans;

  /// Planned (not done) workouts from today on that use the programs.
  final int upcoming;

  /// Weekdays (1..7) assigned to the programs in the plan settings (with the assignment on).
  final List<int> assignedDays;

  /// Athlete-data changes ([AthleteData.merge]) removing the assignments; null when none.
  final Map<String, dynamic>? athlete;

  bool get usedByPlan => upcoming > 0 || assignedDays.isNotEmpty;
}

/// [ProgramDeletion] for deleting the programs [ids] among the athlete's [templates].
ProgramDeletion programDeletion(
  Set<String> ids, {
  required List<WorkoutTemplate> templates,
  required List<PlannedWorkout> plans,
  required AthleteData athlete,
  required DateTime today,
}) {
  final updates = <String, Map<String, dynamic>>{};
  var upcoming = 0;
  for (final p in plans) {
    if (p.sport != Sport.gym || p.exercises.isNotEmpty) continue;
    final t = plannedProgramOf(p, templates);
    if (t == null || !ids.contains(t.id)) continue;
    if (p.status == 'planned' && !dayOnly(p.date).isBefore(dayOnly(today))) upcoming++;
    final snapshot = applyGymMods(t.exercises, p.gymMods, gymGoal: athlete.gymGoal);
    if (snapshot.isEmpty) continue;
    updates[p.id] = {
      'exercises': [for (final e in snapshot) e.copy(resetDone: true).toMap()],
      'gymMods': const <String>[],
    };
  }
  final remaining = [
    for (final t in templates)
      if (!ids.contains(t.id)) t,
  ];
  // An assignment goes when its program is deleted and no other program stands for it (a
  // `key:` reference still finds another program with that key).
  bool goes(String ref) => ids.contains(gymProgramOf(ref, templates)?.id) && gymProgramOf(ref, remaining) == null;
  final a = {
    for (final e in athlete.gymPlanA.entries)
      if (!goes(e.value)) e.key: e.value,
  };
  final b = {
    for (final e in athlete.gymPlanB.entries)
      if (!goes(e.value)) e.key: e.value,
  };
  final changedA = a.length != athlete.gymPlanA.length, changedB = b.length != athlete.gymPlanB.length;
  final days = <int>{
    if (athlete.gymAssign) ...[
      for (final d in athlete.gymPlanA.keys)
        if (!a.containsKey(d)) d,
      if (athlete.gymAB)
        for (final d in athlete.gymPlanB.keys)
          if (!b.containsKey(d)) d,
    ],
  };
  return ProgramDeletion(
    plans: updates,
    upcoming: upcoming,
    assignedDays: days.toList()..sort(),
    athlete: changedA || changedB ? {if (changedA) 'gymPlanA': a, if (changedB) 'gymPlanB': b} : null,
  );
}
