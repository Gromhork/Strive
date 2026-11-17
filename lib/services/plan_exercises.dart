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
/// (In order of preference: the next one when the session already has the first – review 2026-11
/// GYM-7: the PPL "Pull" day got two identical lat-pulldown blocks.)
const gymRegressions = <String, List<(String, String)>>{
  '0652': [('2330', 'cable lat pulldown full range of motion'), ('0970', 'band assisted pull-up')], // pull-up
  '0032': [('1459', 'dumbbell romanian deadlift'), ('2286', 'lever hip extension')], // barbell deadlift
  '0085': [('1459', 'dumbbell romanian deadlift'), ('2286', 'lever hip extension')], // barbell romanian deadlift
  '0472': [('0872', 'reverse crunch')], // hanging leg raise
  // Bodyweight programs (review 2026-11 GYM-3: jump squats and full push-ups from week 1).
  '0514': [('3533', 'bodyweight squat')], // jump squat
  '0662': [('0493', 'incline push-up')], // push-up
  '0499': [('2300', 'inverted row bent knees')], // inverted row
};

/// [PlannedWorkout.gymMods]: back limitation ([HealthFlags.avoidAxialLoading]) – the heavy axially
/// loaded and unsupported bent-over lifts are swapped for supported variants ([gymNoAxialSwaps]).
const gymModNoAxial = 'noAxial';

/// [PlannedWorkout.gymMods]: shoulder limitation ([HealthFlags.avoidOverhead]) – overhead pressing,
/// overhead triceps work and dips are swapped ([gymNoOverheadSwaps]).
const gymModNoOverhead = 'noOverhead';

/// [PlannedWorkout.gymMods]: knee / hip / ankle limitation ([HealthFlags.lowImpactRun]) – no
/// jumps (plyometric landings), [gymNoJumpSwaps].
const gymModNoJump = 'noJump';

/// Back ([gymModNoAxial], review 2026-11 GYM-2: back squats, deadlifts and bent-over rows stayed in
/// every program, only a note asked to replace them): no spinal compression or unsupported hinging
/// under load – leg press / split squat for the squat, glute bridge / hip extension for the hinges,
/// chest-supported or cable rows, seated presses and calf raises, no jump landings.
const gymNoAxialSwaps = <String, List<(String, String)>>{
  '0043': [('0739', 'sled 45° leg press'), ('0410', 'dumbbell single leg split squat')], // barbell squat
  '0032': [('1409', 'barbell glute bridge'), ('2286', 'lever hip extension')], // barbell deadlift
  '0085': [('1409', 'barbell glute bridge'), ('2286', 'lever hip extension'), ('0599', 'lever seated leg curl')], // barbell RDL
  '1459': [('3523', 'glute bridge (feet on bench)'), ('3561', 'glute bridge march')], // dumbbell RDL
  '1757': [('3561', 'glute bridge march'), ('3523', 'glute bridge (feet on bench)')], // dumbbell single-leg deadlift
  '0027': [('0861', 'cable seated row'), ('0327', 'dumbbell incline row')], // barbell bent-over row
  '0293': [('0327', 'dumbbell incline row'), ('0861', 'cable seated row')], // dumbbell bent-over row
  '0426': [('0405', 'dumbbell seated shoulder press'), ('0352', 'dumbbell neutral grip bench press')], // standing press
  '0605': [('0594', 'lever seated calf raise'), ('0409', 'dumbbell single leg calf raise')], // standing calf (load on the shoulders)
  '0514': [('3533', 'bodyweight squat')], // jump squat
  // Hanging leg raises pull on the lumbar spine through the hip flexors – the dead bug keeps it neutral.
  '0472': [('0276', 'dead bug'), ('0872', 'reverse crunch')],
};

/// Shoulder ([gymModNoOverhead]): no heavy overhead pressing (incline presses instead), no
/// overhead triceps extensions and no dips (end-range shoulder extension under body weight).
const gymNoOverheadSwaps = <String, List<(String, String)>>{
  '0405': [('0314', 'dumbbell incline bench press'), ('1299', 'lever incline chest press'), ('0352', 'dumbbell neutral grip bench press')],
  '0426': [('0314', 'dumbbell incline bench press'), ('0352', 'dumbbell neutral grip bench press'), ('1299', 'lever incline chest press')],
  '0194': [('0241', 'cable triceps pushdown (v-bar)'), ('0186', 'cable lying triceps extension')], // cable overhead extension
  '0430': [('0351', 'dumbbell lying triceps extension')], // dumbbell overhead extension
  '0814': [('0241', 'cable triceps pushdown (v-bar)'), ('0186', 'cable lying triceps extension'), ('0259', 'close-grip push-up')], // dip
  '0129': [('0259', 'close-grip push-up'), ('0493', 'incline push-up')], // bench dip
};

/// Knee / hip / ankle ([gymModNoJump]): no plyometric landings.
const gymNoJumpSwaps = <String, List<(String, String)>>{
  '0514': [('3533', 'bodyweight squat')], // jump squat
};

/// The exercise swaps of an exercise mod (null for the others).
Map<String, List<(String, String)>>? gymSwapsOf(String mod) => switch (mod) {
  gymModRegress => gymRegressions,
  gymModNoAxial => gymNoAxialSwaps,
  gymModNoOverhead => gymNoOverheadSwaps,
  gymModNoJump => gymNoJumpSwaps,
  _ => null,
};

/// The health mods in the order [applyGymMods] applies them – before the beginner regressions (a
/// back-pain beginner's deadlift becomes a glute bridge, not a dumbbell RDL).
const gymHealthMods = [gymModNoAxial, gymModNoOverhead, gymModNoJump];

/// Whether [mod] changes anything for the program [exercises].
bool gymModApplies(String mod, List<GymExercise> exercises) {
  if (mod == gymModNoLegs) {
    return exercises.any((e) => classifyLift(e.exId, e.name).lower) && exercises.any((e) => !classifyLift(e.exId, e.name).lower);
  }
  final swaps = gymSwapsOf(mod);
  return swaps != null && exercises.any((e) => swaps.containsKey(e.exId));
}

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
  // Health swaps first, then the beginner regressions of what is left.
  for (final mod in [...gymHealthMods, gymModRegress]) {
    if (!mods.contains(mod)) continue;
    final swaps = gymSwapsOf(mod)!;
    for (var i = 0; i < out.length; i++) {
      out[i] = swappedExercise(out[i], swaps, gymGoal, taken: {for (final x in out) x.exId});
    }
  }
  // A superset that lost a member (or all but one) is no superset any more, and the remaining
  // groups are lettered A, B, … again – the same in the plan, the preview and the tracker.
  normalizeSupersets(out);
  return out;
}

/// [e] replaced by its beginner regression ([gymRegressions]; rep range from its class and the
/// gym goal), same number of sets. Unchanged copy when it has none.
GymExercise regressedExercise(GymExercise e, String gymGoal) => swappedExercise(e, gymRegressions, gymGoal);

/// [e] replaced by its first option in [swaps] that is not [taken] (the session's exercise ids –
/// never the same exercise twice in one workout), else by its last option; rep range from its class
/// and the gym goal, same number of sets. Unchanged copy when [swaps] has none for it.
GymExercise swappedExercise(GymExercise e, Map<String, List<(String, String)>> swaps, String gymGoal, {Set<String> taken = const {}}) {
  final c = e.copy();
  final options = swaps[e.exId];
  if (options == null || options.isEmpty) return c;
  final r = options.firstWhere((o) => !taken.contains(o.$1), orElse: () => options.last);
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

/// Work sets per muscle group of [exercises] for "do two days in a row load the same muscles?":
/// chest, delts (front / side), triceps, back (lats, upper back, rear delts), biceps, legs – a press
/// also loads the delts and triceps, a row or pulldown the biceps ([liftMuscles]; review 2026-11
/// GYM-10: bench press on Tuesday, shoulder press on Wednesday in every bro-split week, as the coarse
/// push / pull groups made every order look equally overlapping). Core counts for none.
Map<String, int> gymMuscleSets(List<GymExercise> exercises) {
  final n = <String, int>{};
  for (final e in exercises) {
    final p = classifyLift(e.exId, e.name);
    final sets = e.sets.where((s) => !s.warmup).length;
    final groups =
        p.lower
            ? const {'legs'}
            : {
              for (final m in liftMuscles(p.move))
                switch (m) {
                  'frontdelt' || 'sidedelt' => 'delts',
                  'upperback' || 'lats' || 'reardelt' => 'back',
                  _ => m,
                },
            }.where(const {'chest', 'delts', 'triceps', 'back', 'biceps'}.contains);
    for (final g in groups) {
      n[g] = (n[g] ?? 0) + sets;
    }
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
