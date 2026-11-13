import 'dart:math';

import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import 'exercise_class.dart';

/// [PlannedWorkout.gymMods]: beginner regressions of the technically demanding lifts
/// (lat pulldown for pull-ups, a dumbbell RDL for the barbell deadlift, reverse crunches for
/// hanging leg raises) – the plan's first weeks for beginners.
const gymModRegress = 'regress';

/// [PlannedWorkout.gymMods]: the program without its leg exercises (an endurance race in the
/// next days – upper body and core only).
const gymModNoLegs = 'noLegs';

/// [PlannedWorkout.gymMods]: a key endurance session follows – the leg exercises keep all their
/// sets but go ~12 % lighter, no AMRAP, no step up ([gymLoadPhase] 'legsEasy', LoadPrescriber).
const gymModLegsEasy = 'legsEasy';

/// [PlannedWorkout.gymMods]: an endurance race in the next days – the whole workout is
/// maintenance at taper load (~10 % lighter, no AMRAP, no step up; [gymLoadPhase] 'race'), also
/// when the plan week itself is still a loading week.
const gymModRaceWeek = 'raceWeek';

/// Mods that change the load only (not the exercises): they stay when the athlete adjusts the
/// workout's exercises for the day.
const gymLoadMods = {gymModLegsEasy, gymModRaceWeek};

/// Load phase of planned workout [p] for LoadPrescriber (`phase:`): its plan phase ('recovery' /
/// 'taper' lighten the whole workout), else 'race' ([gymModRaceWeek]) or 'legsEasy'
/// ([gymModLegsEasy]), else the plan phase. Tracker prefill, "mark as done", the planned page
/// and the plan editor all read it, so the numbers match the workout's notes.
String? gymLoadPhase(PlannedWorkout? p) {
  if (p == null) return null;
  if (p.sport != Sport.gym || p.phase == 'recovery' || p.phase == 'taper') return p.phase;
  if (p.gymMods.contains(gymModRaceWeek)) return 'race';
  if (p.gymMods.contains(gymModLegsEasy)) return 'legsEasy';
  return p.phase;
}

/// Exercise id → (id, name) of its beginner regression (assets/data/exercises.json).
const gymRegressions = {
  '0652': ('2330', 'cable lat pulldown full range of motion'), // pull-up
  '0032': ('1459', 'dumbbell romanian deadlift'), // barbell deadlift
  '0472': ('0872', 'reverse crunch'), // hanging leg raise
};

/// Whether [mod] changes anything for the program [exercises].
bool gymModApplies(String mod, List<GymExercise> exercises) => switch (mod) {
  gymModRegress => exercises.any((e) => gymRegressions.containsKey(e.exId)),
  gymModNoLegs => exercises.any((e) => classifyLift(e.exId, e.name).lower) && exercises.any((e) => !classifyLift(e.exId, e.name).lower),
  _ => false,
};

/// The exercises of planned gym workout [p]: its own (adjusted for this day in the plan editor,
/// or stored by an older app version), else the current exercises of its program [t] with the
/// plan's day adaptations ([PlannedWorkout.gymMods]) applied. Set counts always stay the
/// program's – the plan periodises through load and reps in reserve only.
List<GymExercise> plannedGymExercises(PlannedWorkout p, WorkoutTemplate? t, {String gymGoal = 'general'}) {
  if (p.exercises.isNotEmpty) return p.exercises;
  return applyGymMods(t?.exercises ?? const [], p.gymMods, gymGoal: gymGoal);
}

/// Copies of [exercises] with [mods] applied (see [plannedGymExercises]).
List<GymExercise> applyGymMods(List<GymExercise> exercises, List<String> mods, {String gymGoal = 'general'}) {
  var out = [for (final e in exercises) e.copy()];
  if (mods.contains(gymModNoLegs)) {
    final upper = out.where((e) => !classifyLift(e.exId, e.name).lower).toList();
    // A program of leg exercises only stays as it is (better than an empty workout).
    if (upper.isNotEmpty) out = upper;
  }
  if (mods.contains(gymModRegress)) out = [for (final e in out) regressedExercise(e, gymGoal)];
  return out;
}

/// [e] replaced by its beginner regression ([gymRegressions]; rep range from its class and the
/// gym goal), same number of sets. Unchanged copy when it has none.
GymExercise regressedExercise(GymExercise e, String gymGoal) {
  final c = e.copy();
  final r = gymRegressions[e.exId];
  if (r == null) return c;
  c.exId = r.$1;
  c.name = r.$2;
  c.bw = null;
  final (lo, hi) = repRangeFor(classifyLift(r.$1, r.$2), gymGoal);
  c.repMin = lo;
  c.repMax = hi;
  c.restSec = min(c.restSec, 120);
  for (final s in c.sets) {
    if (!s.warmup) s.reps = lo;
  }
  return c;
}

/// Reference of program [t] for the gym days the athlete assigns in the plan setup
/// ([AthleteData.gymPlanA]): `key:<key>` for a built-in program (also the athlete's edited copy –
/// it keeps the key), else `id:<template id>`.
String gymProgramRef(WorkoutTemplate t) => t.key != null ? 'key:${t.key}' : 'id:${t.id}';

/// The built-in key of a program reference ([gymProgramRef]), null for the athlete's own programs.
String? gymRefKey(String ref) => ref.startsWith('key:') ? ref.substring(4) : null;

/// The program [ref] ([gymProgramRef]) stands for among [templates] (the athlete's programs),
/// else the built-in program from [builtins] (not yet added), else null.
WorkoutTemplate? gymProgramOf(String ref, List<WorkoutTemplate> templates, {List<WorkoutTemplate> builtins = const []}) {
  final key = gymRefKey(ref);
  if (key != null) return templates.where((t) => t.key == key).firstOrNull ?? builtins.where((t) => t.key == key).firstOrNull;
  if (ref.startsWith('id:')) return templates.where((t) => t.id == ref.substring(3)).firstOrNull;
  return null;
}

/// Work sets per muscle group ('push' / 'pull' / 'legs') of [exercises] – core and other
/// exercises count for none.
Map<String, int> gymGroupSets(List<GymExercise> exercises) {
  final n = {'push': 0, 'pull': 0, 'legs': 0};
  for (final e in exercises) {
    final g = _groupOf(classifyLift(e.exId, e.name));
    if (g != null) n[g] = n[g]! + e.sets.where((s) => !s.warmup).length;
  }
  return n;
}

/// A program of mostly leg work: a built-in leg day ([legHeavyKeys]) or ≥ half of its push /
/// pull / leg sets (≥ 3) for the legs – not the day before a long or key endurance session.
bool legHeavyProgram(WorkoutTemplate t) => legHeavyKeys.contains(t.key) || legHeavyExercises(t.exercises);

/// [legHeavyProgram] by the exercises alone.
bool legHeavyExercises(List<GymExercise> exercises) {
  final n = gymGroupSets(exercises);
  final legs = n['legs']!, total = n.values.fold<int>(0, (x, y) => x + y);
  return legs >= 3 && legs * 2 >= total;
}

String? _groupOf(LiftProfile p) {
  if (p.lower) return 'legs';
  return switch (p.move) {
    Movement.horizontalPush || Movement.verticalPush || Movement.elbowExtension || Movement.lateralRaise || Movement.chestFly => 'push',
    Movement.horizontalPull || Movement.verticalPull || Movement.elbowFlexion || Movement.rearDelt => 'pull',
    _ => null,
  };
}
