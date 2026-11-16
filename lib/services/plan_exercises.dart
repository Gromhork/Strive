import 'dart:math';

import '../core/sport.dart';
import '../data/builtin_upgrade.dart' show builtinKeysNamed;
import '../data/default_programs.dart';
import '../data/models.dart';
import 'exercise_class.dart';
import 'supersets.dart';

/// [PlannedWorkout.gymMods]: beginner regressions of the technically demanding lifts
/// (lat pulldown for pull-ups, a dumbbell RDL for the barbell deadlift, reverse crunches for
/// hanging leg raises) â€“ the plan's first weeks for beginners.
const gymModRegress = 'regress';

/// [PlannedWorkout.gymMods]: the program without its leg exercises (an endurance race in the
/// next days â€“ upper body and core only).
const gymModNoLegs = 'noLegs';

/// [PlannedWorkout.gymMods]: a key endurance session follows â€“ the leg exercises keep all their
/// sets but go ~12 % lighter, no AMRAP, no step up ([gymLoadPhase] 'legsEasy', LoadPrescriber).
const gymModLegsEasy = 'legsEasy';

/// [PlannedWorkout.gymMods]: an endurance race in the next days â€“ the whole workout is
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

/// Exercise id â†’ (id, name) of its beginner regression (assets/data/exercises.json).
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
/// program's â€“ the plan periodises through load and reps in reserve only.
List<GymExercise> plannedGymExercises(PlannedWorkout p, WorkoutTemplate? t, {String gymGoal = 'general'}) {
  if (p.exercises.isNotEmpty) return p.exercises;
  return applyGymMods(t?.exercises ?? const [], p.gymMods, gymGoal: gymGoal);
}

/// The program of planned workout [p] among the athlete's [templates]: its program
/// ([PlannedWorkout.templateId]). When that one no longer exists â€“ deleted by an app version that
/// did not keep the plan's exercises ([programDeletion]), or deleted and then restored as a new
/// document â€“ a gym workout falls back to the athlete's gym program carrying the workout's title,
/// but only when that is unambiguous: the only program of that name, or the only one of them that
/// is the built-in program of that name. A name several built-ins share ("Beine": PPL and bro
/// split) is never guessed. Null for a workout without a program and when nothing matches
/// ([plannedProgramMissing]).
WorkoutTemplate? plannedProgramOf(PlannedWorkout p, List<WorkoutTemplate> templates) {
  final id = p.templateId;
  if (id == null) return null;
  final own = templates.where((t) => t.id == id).firstOrNull;
  if (own != null || p.sport != Sport.gym) return own;
  return _namedProgram(p.title, templates);
}

/// The gym program among [templates] that the title of a workout whose program is gone stands for
/// ([plannedProgramOf]).
WorkoutTemplate? _namedProgram(String title, List<WorkoutTemplate> templates) {
  final name = title.trim().toLowerCase();
  if (name.isEmpty) return null;
  final keys = builtinKeysNamed(name);
  if (keys.length > 1) return null;
  final named = [
    for (final t in templates)
      if (t.sport == Sport.gym && t.name.trim().toLowerCase() == name) t,
  ];
  if (named.length == 1) return named.single;
  final builtin = named.where((t) => keys.contains(t.key)).toList();
  return builtin.length == 1 ? builtin.single : null;
}

/// A planned gym workout whose program was deleted and that has no exercises of its own: it would
/// show no exercises and start an empty session â€“ the screens say so and offer to choose a program.
bool plannedProgramMissing(PlannedWorkout p, List<WorkoutTemplate> templates) =>
    p.sport == Sport.gym && p.exercises.isEmpty && p.templateId != null && plannedProgramOf(p, templates) == null;

/// Planned gym workouts whose program no longer exists but is found again among the athlete's
/// [templates] ([plannedProgramOf]) or is one of the originals just [restored] (by its shipped name in
/// any language â€“ also a name several built-ins share, as only one of them came back): plan id â†’
/// the fields that link them to it.
Map<String, Map<String, dynamic>> relinkedPlans(
  List<PlannedWorkout> plans,
  List<WorkoutTemplate> templates, {
  List<WorkoutTemplate> restored = const [],
}) {
  final ids = {for (final t in templates) t.id};
  WorkoutTemplate? restoredFor(PlannedWorkout p) {
    final keys = builtinKeysNamed(p.title);
    final hits = [
      for (final t in restored)
        if (t.sport == Sport.gym && (keys.contains(t.key) || t.name.trim().toLowerCase() == p.title.trim().toLowerCase())) t,
    ];
    return hits.length == 1 ? hits.single : null;
  }

  return {
    for (final p in plans)
      if (p.sport == Sport.gym && p.templateId != null && !ids.contains(p.templateId) && p.exercises.isEmpty)
        if (plannedProgramOf(p, templates) ?? restoredFor(p) case final t?) p.id: {'templateId': t.id},
  };
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
  // A superset that lost a member (or all but one) is no superset any more, and the remaining
  // groups are lettered A, B, … again – the same in the plan, the preview and the tracker.
  normalizeSupersets(out);
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
/// ([AthleteData.gymPlanA]): `key:<key>` for a built-in program (also the athlete's edited copy â€“
/// it keeps the key), else `id:<template id>`. Among the athlete's programs [among], a second
/// program with the same key (older data) is referenced by its id â€“ `key:` stands for the first
/// ([gymProgramOf]).
String gymProgramRef(WorkoutTemplate t, {List<WorkoutTemplate> among = const []}) {
  final key = t.key;
  if (key == null) return 'id:${t.id}';
  final first = among.where((x) => x.key == key).firstOrNull;
  return first == null || first.id == t.id ? 'key:$key' : 'id:${t.id}';
}

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

/// Work sets per muscle group ('push' / 'pull' / 'legs') of [exercises] â€“ core and other
/// exercises count for none.
Map<String, int> gymGroupSets(List<GymExercise> exercises) {
  final n = {'push': 0, 'pull': 0, 'legs': 0};
  for (final e in exercises) {
    final g = _groupOf(classifyLift(e.exId, e.name));
    if (g != null) n[g] = n[g]! + e.sets.where((s) => !s.warmup).length;
  }
  return n;
}

/// A program of mostly leg work: a built-in leg day ([legHeavyKeys]) or â‰¥ half of its push /
/// pull / leg sets (â‰¥ 3) for the legs â€“ not the day before a long or key endurance session.
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
