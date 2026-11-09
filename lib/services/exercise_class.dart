import '../data/exercise_db.dart';
import '../data/models.dart';

/// Training role of an exercise – drives rep ranges, superset pairing and load steps.
///
/// * [main] – heavy barbell competition-style lifts (squat, bench press, deadlift,
///   overhead press): trained heavy, with long rests, never inside a superset.
/// * [heavy] – other free-weight compound lifts (barbell rows, RDLs, front squats, …).
/// * [compound] – dumbbell / machine / cable multi-joint exercises.
/// * [isolation] – single-joint exercises for mid-sized muscles (curls, triceps
///   extensions, leg extensions/curls, flys).
/// * [small] – single-joint exercises for small muscles that respond to higher reps
///   (lateral raises, rear delts, calves, shrugs, forearms).
/// * [bodyweight] – bodyweight strength exercises (pull-ups, dips, push-ups, rows, …).
/// * [core] – trunk exercises (crunches, leg raises, dead bugs, planks, …).
enum LiftClass { main, heavy, compound, isolation, small, bodyweight, core }

/// Movement pattern (used to build antagonist supersets and avoid competing pairs).
enum Movement {
  squat,
  hinge,
  lunge,
  hipExtension,
  horizontalPush,
  verticalPush,
  horizontalPull,
  verticalPull,
  elbowFlexion,
  elbowExtension,
  kneeExtension,
  kneeFlexion,
  lateralRaise,
  rearDelt,
  chestFly,
  calf,
  core,
  other,
}

/// Classification of one exercise.
class LiftProfile {
  const LiftProfile(this.cls, this.move, {this.lower = false, this.bodyFraction = 0, this.bodyweight = false});
  final LiftClass cls;
  final Movement move;
  final bool lower;

  /// Bodyweight exercise (load = body weight [+ added weight]).
  final bool bodyweight;

  /// Share of the body weight that is actually lifted (for volume / e1RM of bodyweight
  /// exercises). 0 = not counted (core, jumps, bodyweight leg work – progressed by reps).
  /// Pull-ups / chin-ups / dips ≈ 100 %; push-ups ≈ 64 % (Ebben et al. 2011);
  /// inverted rows ≈ 55–60 %; bench dips ≈ 50 %.
  final double bodyFraction;

  /// Bodyweight exercise that is commonly progressed with added load (belt / vest)
  /// once the top of the rep range is reached.
  bool get loadableBodyweight => bodyweight && bodyFraction >= 0.9;

  bool get isCompound => cls == LiftClass.main || cls == LiftClass.heavy || cls == LiftClass.compound;

  @override
  String toString() => 'LiftProfile($cls, $move${bodyweight ? ', bw ${bodyFraction.toStringAsFixed(2)}' : ''})';
}

/// Evidence-based rep range (double-progression window).
///
/// Hypertrophy is similar across a wide range of loads when sets are taken close to
/// failure (Schoenfeld et al. 2017/2021), but heavy loads (≈ ≥ 80 % 1RM, ≲ 6–8 reps)
/// build more maximal strength. Practical ranges therefore are: heavy main lifts low
/// (strength 3–6, hypertrophy 6–10), other compounds moderate (6–12), single-joint and
/// small-muscle work higher (10–20) where very heavy loads mostly stress joints.
/// [goal]: strength | hypertrophy | general.
(int, int) repRangeFor(LiftProfile p, String goal) {
  final strength = goal == 'strength', hyp = goal == 'hypertrophy';
  switch (p.cls) {
    case LiftClass.main:
      // Deadlifts: one step lower (high systemic fatigue, technique breaks down late in a set).
      if (p.move == Movement.hinge) return strength ? (3, 5) : (hyp ? (5, 8) : (4, 6));
      return strength ? (3, 6) : (hyp ? (6, 10) : (5, 8));
    case LiftClass.heavy:
      return strength ? (5, 8) : (6, 10);
    case LiftClass.compound:
      if (p.lower && p.move == Movement.squat) return strength ? (6, 10) : (10, 15); // leg press, hack squat
      return strength ? (6, 10) : (8, 12);
    case LiftClass.isolation:
      return strength ? (8, 12) : (10, 15);
    case LiftClass.small:
      return strength ? (10, 15) : (12, 20);
    case LiftClass.bodyweight:
      if (p.loadableBodyweight) return strength ? (4, 8) : (hyp ? (6, 12) : (6, 10));
      if (p.bodyFraction > 0) return strength ? (6, 12) : (8, 15);
      if (p.move == Movement.calf) return (15, 25);
      if (p.move == Movement.core) return (8, 15);
      return (10, 20);
    case LiftClass.core:
      return (8, 15);
  }
}

/// Rep range of a planned exercise: the explicit range if set, otherwise derived from
/// the classification and the gym goal.
(int, int) repRangeOf(GymExercise e, String goal, {Exercise? info}) {
  final lo = e.repMin, hi = e.repMax;
  if (lo != null && lo > 0 && hi != null && hi >= lo) return (lo, hi);
  final r = repRangeFor(classifyLift(e.exId, e.name, info: info), goal);
  if (lo != null && lo > 0) return (lo, lo > r.$2 ? lo + 4 : r.$2);
  return r;
}

const _loadedEquipment = {
  'barbell',
  'ez barbell',
  'olympic barbell',
  'trap bar',
  'dumbbell',
  'kettlebell',
  'cable',
  'leverage machine',
  'sled machine',
  'smith machine',
  'weighted',
};

bool _any(String n, List<String> words) => words.any(n.contains);

/// Classifies an exercise by its library metadata ([info]) and/or name.
LiftProfile classifyLift(String exId, String name, {Exercise? info}) {
  final n = (info?.name ?? name).toLowerCase();
  final eq = info?.equipment ?? _equipmentOfName(n);
  final lowerPart = info != null ? (const {'upper legs', 'lower legs'}.contains(info.bodyPart) || info.target == 'glutes') : null;
  final loaded = _loadedEquipment.contains(eq);
  final barbell = const {'barbell', 'olympic barbell', 'trap bar'}.contains(eq);

  // ── Bodyweight strength exercises (unless done on a machine / with a cable).
  final bwEquip = !loaded || eq == 'weighted';
  if (_any(n, ['pull-up', 'pull up', 'pullup', 'chin-up', 'chin up', 'chinup', 'muscle up', 'muscle-up']) && eq != 'cable') {
    return const LiftProfile(LiftClass.bodyweight, Movement.verticalPull, bodyFraction: 1, bodyweight: true);
  }
  if (n.contains('dip') && !n.contains('hip') && bwEquip) {
    final bench = n.contains('bench') || n.contains('chair');
    return LiftProfile(
      LiftClass.bodyweight,
      bench ? Movement.elbowExtension : Movement.verticalPush,
      bodyFraction: bench ? 0.5 : 1,
      bodyweight: true,
    );
  }
  if (_any(n, ['push-up', 'push up', 'pushup', 'press-up']) && bwEquip) {
    final easy = _any(n, ['knee', 'incline', 'wall']);
    final hard = n.contains('decline');
    return LiftProfile(LiftClass.bodyweight, Movement.horizontalPush, bodyFraction: easy ? 0.5 : (hard ? 0.75 : 0.65), bodyweight: true);
  }
  if (n.contains('inverted row') || (n.contains('australian') && n.contains('pull'))) {
    return const LiftProfile(LiftClass.bodyweight, Movement.horizontalPull, bodyFraction: 0.6, bodyweight: true);
  }

  // ── Core.
  if (_any(n, [
    'crunch',
    'plank',
    'sit-up',
    'sit up',
    'leg raise',
    'knee raise',
    'dead bug',
    'mountain climber',
    'hollow',
    'bird dog',
    'russian twist',
    'v-up',
    'ab wheel',
    'rollout',
    'flutter kick',
    'pallof',
    'side bridge',
    'jackknife',
  ])) {
    return LiftProfile(loaded && !n.contains('hanging') ? LiftClass.isolation : LiftClass.core, Movement.core, bodyweight: !loaded);
  }

  // ── Single-joint lower body.
  if (n.contains('calf')) return LiftProfile(LiftClass.small, Movement.calf, lower: true, bodyweight: !loaded);
  if (n.contains('leg extension')) return const LiftProfile(LiftClass.isolation, Movement.kneeExtension, lower: true);
  if (n.contains('leg curl') || n.contains('nordic') || n.contains('hamstring curl')) {
    return LiftProfile(LiftClass.isolation, Movement.kneeFlexion, lower: true, bodyweight: !loaded);
  }

  // ── Shoulders / arms / chest isolation.
  if (_any(n, ['face pull', 'rear delt', 'rear fly', 'reverse fly', 'rear lateral', 'reverse pec deck'])) {
    return const LiftProfile(LiftClass.small, Movement.rearDelt);
  }
  if (_any(n, ['lateral raise', 'side raise', 'front raise', 'y-raise', 'y raise'])) {
    return const LiftProfile(LiftClass.small, Movement.lateralRaise);
  }
  if (_any(n, ['shrug', 'wrist', 'forearm'])) return const LiftProfile(LiftClass.small, Movement.other);
  if (_any(n, [' fly', 'fly ', 'flye', 'crossover', 'pec deck'])) return const LiftProfile(LiftClass.isolation, Movement.chestFly);
  if (n.contains('curl') && !n.contains('leg')) return const LiftProfile(LiftClass.isolation, Movement.elbowFlexion);
  if (_any(n, ['pushdown', 'push-down', 'skull', 'kickback', 'triceps', 'tricep', 'french press']) ||
      (n.contains('extension') && !_any(n, ['back extension', 'hip extension', 'leg extension']))) {
    return const LiftProfile(LiftClass.isolation, Movement.elbowExtension);
  }

  // ── Compound lifts.
  Movement? move;
  if (_any(n, ['deadlift', 'romanian', 'stiff leg', 'stiff-leg', 'good morning', 'rack pull'])) {
    move = Movement.hinge;
  } else if (_any(n, ['hip thrust', 'glute bridge', 'back extension', 'hip extension', 'pull through', 'kettlebell swing'])) {
    move = Movement.hipExtension;
  } else if (_any(n, ['lunge', 'split squat', 'step-up', 'step up', 'pistol'])) {
    move = Movement.lunge;
  } else if (_any(n, ['squat', 'leg press', 'hack'])) {
    move = Movement.squat;
  } else if (_any(n, ['shoulder press', 'overhead press', 'military', 'push press', 'arnold', 'landmine press'])) {
    move = Movement.verticalPush;
  } else if (_any(n, ['bench press', 'chest press', 'floor press', 'incline press', 'decline press', 'svend'])) {
    move = Movement.horizontalPush;
  } else if (_any(n, ['pulldown', 'pull-down', 'pull down', 'pullover'])) {
    move = Movement.verticalPull;
  } else if (n.contains('upright row')) {
    return const LiftProfile(LiftClass.small, Movement.lateralRaise);
  } else if (n.contains('row')) {
    move = Movement.horizontalPull;
  }
  final lower =
      lowerPart ?? const {Movement.squat, Movement.hinge, Movement.lunge, Movement.hipExtension}.contains(move) || n.contains('leg');
  if (move == null) {
    return LiftProfile(loaded ? LiftClass.compound : LiftClass.bodyweight, Movement.other, lower: lower, bodyweight: !loaded);
  }
  if (!loaded) {
    // Jump squats, walking lunges, glute bridges, … – progressed by reps.
    return LiftProfile(LiftClass.bodyweight, move, lower: lower, bodyweight: true);
  }
  if (barbell) {
    final isMain = switch (move) {
      Movement.squat => !_any(n, ['front', 'box', 'jump', 'zercher', 'overhead', 'split', 'hack', 'pause']),
      Movement.hinge => !_any(n, ['romanian', 'stiff', 'good morning', 'deficit', 'single', 'rack', 'sumo high']),
      Movement.horizontalPush => n.contains('bench press') && !_any(n, ['close', 'incline', 'decline', 'reverse', 'guillotine', 'board']),
      Movement.verticalPush => _any(n, ['overhead press', 'military', 'standing shoulder press', 'push press']) && !n.contains('behind'),
      _ => false,
    };
    return LiftProfile(isMain ? LiftClass.main : LiftClass.heavy, move, lower: lower);
  }
  return LiftProfile(LiftClass.compound, move, lower: lower);
}

String _equipmentOfName(String n) {
  if (n.contains('trap bar')) return 'trap bar';
  if (n.contains('ez bar') || n.contains('ez-bar')) return 'ez barbell';
  if (n.contains('smith')) return 'smith machine';
  if (n.contains('barbell')) return 'barbell';
  if (n.contains('dumbbell')) return 'dumbbell';
  if (n.contains('kettlebell')) return 'kettlebell';
  if (n.contains('cable')) return 'cable';
  if (n.contains('sled') || n.contains('leg press')) return 'sled machine';
  if (n.contains('lever') || n.contains('machine') || n.contains('pec deck')) return 'leverage machine';
  if (n.contains('band')) return 'band';
  if (n.contains('weighted')) return 'weighted';
  if (n.contains('assisted')) return 'assisted';
  return 'body weight';
}

// ───────────────────────────── Superset pairing ─────────────────────────────

/// Agonist ↔ antagonist movement pairs (opposing muscle groups). Paired-set training
/// with antagonists keeps the volume load of traditional sets in ~half the time
/// (Robbins et al. 2010; Paz et al. 2017; Weakley et al. 2017), unlike pairing two
/// exercises for the same muscle, which lowers the reps of the second one.
const _antagonists = {
  (Movement.horizontalPush, Movement.horizontalPull),
  (Movement.verticalPush, Movement.verticalPull),
  (Movement.horizontalPush, Movement.verticalPull),
  (Movement.verticalPush, Movement.horizontalPull),
  (Movement.elbowFlexion, Movement.elbowExtension),
  (Movement.kneeExtension, Movement.kneeFlexion),
  (Movement.chestFly, Movement.rearDelt),
  (Movement.squat, Movement.kneeFlexion),
  (Movement.lunge, Movement.kneeFlexion),
};

bool areAntagonists(LiftProfile a, LiftProfile b) => _antagonists.contains((a.move, b.move)) || _antagonists.contains((b.move, a.move));

/// Muscles mainly loaded by a movement (coarse; for "do these two compete?").
Set<String> _muscles(Movement m) => switch (m) {
  Movement.squat || Movement.lunge => {'quads', 'glutes'},
  Movement.hinge || Movement.hipExtension => {'glutes', 'hamstrings', 'lowback'},
  Movement.horizontalPush => {'chest', 'frontdelt', 'triceps'},
  Movement.verticalPush => {'frontdelt', 'triceps', 'sidedelt'},
  Movement.horizontalPull => {'upperback', 'lats', 'biceps', 'reardelt'},
  Movement.verticalPull => {'lats', 'biceps'},
  Movement.elbowFlexion => {'biceps'},
  Movement.elbowExtension => {'triceps'},
  Movement.kneeExtension => {'quads'},
  Movement.kneeFlexion => {'hamstrings'},
  Movement.lateralRaise => {'sidedelt'},
  Movement.rearDelt => {'reardelt'},
  Movement.chestFly => {'chest'},
  Movement.calf => {'calves'},
  Movement.core => {'abs'},
  Movement.other => {},
};

/// True when two exercises make a sensible superset: antagonists, or non-competing
/// muscle groups (e.g. calves + abs). Never two exercises that load the same muscles
/// (e.g. two biceps curls, bench press + dips), never two heavy lifts of the same
/// pattern; a heavy main lift (squat, bench, deadlift, overhead press) only with its
/// antagonist (e.g. bench press + row).
bool goodSupersetPair(LiftProfile a, LiftProfile b) {
  final mains = (a.cls == LiftClass.main ? 1 : 0) + (b.cls == LiftClass.main ? 1 : 0);
  if (mains == 2) return false;
  if (mains == 1) return areAntagonists(a, b);
  if (areAntagonists(a, b)) return true;
  if (a.move == b.move) return false;
  if (a.isCompound && b.isCompound && a.lower == b.lower) return false;
  return _muscles(a.move).intersection(_muscles(b.move)).isEmpty;
}
