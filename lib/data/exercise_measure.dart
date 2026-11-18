/// How the sets of an exercise are measured – reps or hold time – and how much of the body
/// weight a bodyweight exercise moves. Pure Dart (no Flutter), shared by the models (derived
/// volume of stored sessions), the load prescription and the UI.
library;

// ───────────────────────────── Timed (isometric) exercises ─────────────────────────────

/// Library exercises held for time although their name doesn't say "hold" (or says it in a
/// way the keywords below can't tell): planks, side bridges, L-/V-sits, levers, handstands,
/// isometric squeezes and loaded carries.
const _timedIds = {
  '2135', // weighted front plank
  '3544', // bodyweight incline side plank
  '0705', // side bridge v. 2 (side plank)
  '3665', // power point plank
  '3419', // l-sit on floor
  '3420', // v-sit on floor
  '3296', // front lever
  '3297', // back lever
  '3302', // handstand
  '1297', // isometric chest squeeze
  '2133', // farmers walk
  '3548', // dumbbell single arm overhead carry
};

/// Library exercises whose name sounds like a hold but that are done for reps (dynamic plank
/// variations, flowing stretches).
const _repIds = {
  '0464', // front plank with twist
  '3239', // kneeling plank tap shoulder
  '3663', // reverse plank with leg lift
  '0664', // push-up to side plank
  '1774', // side bridge hip abduction
  '1775', // side plank hip adduction
  '3664', // dumbbell side plank with rear fly
  '3295', // front lever reps
  '0500', // isometric wipers (a push-up variation)
  '1167', // dynamic chest stretch
  '3642', // weighted stretch lunge
  '1604', // world greatest stretch (flow)
  '0257', // circles knee stretch
  '2571', // rocking frog stretch
};

/// Words of a held position (English library names, German custom names).
const _holdWords = [
  'plank',
  'side bridge',
  'bridge hold',
  'wall sit',
  'wall squat hold',
  'hollow',
  'dead hang',
  'bar hang',
  'active hang',
  'passive hang',
  'l-sit',
  'l sit',
  'v-sit',
  'front lever',
  'back lever',
  'handstand',
  'isometric',
  'static',
  ' hold',
  'hold ',
  'stretch',
  ' pose',
  'unterarmstütz',
  'seitstütz',
  'wandsitz',
  'halten',
  'dehnung',
  'totes hängen',
];

/// Movement words: a "plank with twist" or a "handstand push-up" is done for reps.
const _movingWords = [
  'twist',
  'tap',
  'reps',
  'leg lift',
  'to side plank',
  'jack',
  'up-down',
  'up down',
  'push-up',
  'push up',
  'pushup',
  'press-up',
  'dynamic',
  'circles',
  'rock',
  'march',
  'lunge',
  'abduction',
  'adduction',
  'fly',
  'walk',
  'row',
  'raise',
  'crunch',
  'curl',
  'swing',
  'clean',
  'climber',
  'sequence',
  'drehung',
];

bool _any(String n, List<String> words) => words.any(n.contains);

/// Whether exercise [exId] / [name] is held for time (plank, side plank, wall sit, hollow hold,
/// dead hang, L-sit, levers, handstand, loaded carries, static stretches, …) instead of counted
/// in reps. The per-exercise override is [GymExercise.timed].
bool isTimedExercise(String exId, String name) => _timedCache.putIfAbsent('$exId|$name', () => _isTimed(exId, name));

// Memoised: volumes of the whole history ask this for every exercise on every rebuild.
final _timedCache = <String, bool>{};
final _shareCache = <String, double>{};

bool _isTimed(String exId, String name) {
  if (exId == 'manual') return false;
  if (_repIds.contains(exId)) return false;
  if (_timedIds.contains(exId)) return true;
  final n = name.toLowerCase();
  if (_any(n, const ['farmer', 'carry', 'suitcase hold'])) return true;
  if (_any(n, _movingWords)) return false;
  return _any(n, _holdWords);
}

/// Whether a timed exercise is a stretch / mobility hold: no load progression, its hold time
/// only goes up to the top of its range.
bool isStretch(String name) {
  final n = name.toLowerCase();
  return _any(n, const ['stretch', ' pose', 'dehnung', 'yoga']);
}

/// Whether a timed hold is progressed with added load once its time reaches the top of the range:
/// planks and wall sits (plate on the back / lap), side planks (dumbbell), hangs (belt) and
/// carries – not stretches and skill holds (hollow body, L-/V-sit, levers, handstand), which
/// get harder by variation, not by load.
bool holdTakesLoad(String name) {
  final n = name.toLowerCase();
  if (isStretch(n)) return false;
  return !_any(n, const ['hollow', 'l-sit', 'l sit', 'v-sit', 'lever', 'handstand', 'squeeze', 'isometric']);
}

/// Hold-time range (seconds) of a timed exercise without its own range – the double-progression
/// window of the hold time: start at the bottom, add 5–10 s per session up to the top, then load.
/// Practice values (ACSM 2021 guidelines; McGill 2015 for trunk endurance holds: several
/// shorter holds of ~10–60 s rather than one long one).
(int, int) defaultHoldRange(String name) {
  final n = name.toLowerCase();
  if (isStretch(n)) return (30, 60); // static stretching: 30–60 s per stretch (ACSM)
  if (_any(n, const ['farmer', 'carry'])) return (30, 60);
  if (_any(n, const ['side plank', 'side bridge', 'seitstütz'])) return (20, 45);
  if (_any(n, const ['wall sit', 'wall squat', 'wandsitz'])) return (30, 90);
  if (_any(n, const ['l-sit', 'l sit', 'v-sit', 'lever', 'handstand'])) return (10, 30);
  if (_any(n, const ['hollow', 'isometric', 'squeeze'])) return (20, 40);
  if (n.contains('hang') || n.contains('hängen')) return (20, 60);
  return (30, 60); // planks and other holds
}

/// Whether a timed hold is done once per side – the prescribed time is "per side" (side plank,
/// Copenhagen plank, single-arm hang or carry, single-leg holds), like dumbbell lifts "per hand".
bool holdPerSide(String name) {
  final n = name.toLowerCase();
  return _any(n, const [
    'side plank',
    'side bridge',
    'seitstütz',
    'copenhagen',
    'single arm',
    'single-arm',
    'one arm',
    'one-arm',
    'single leg',
    'single-leg',
    'one leg',
    'one-leg',
    'einarmig',
    'einbeinig',
    'suitcase',
  ]);
}

/// "45 s", "1:30 min", "2 min" – one set's hold time.
String formatHold(int sec) {
  if (sec < 60) return '$sec${_nbsp}s';
  final m = sec ~/ 60, s = sec % 60;
  return s == 0 ? '$m${_nbsp}min' : '$m:${s.toString().padLeft(2, '0')} min';
}

// ───────────────────────────── Body load of bodyweight exercises ─────────────────────────────

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
};

/// Equipment of an exercise from its (library) name – library names name the equipment
/// ("barbell full squat", "lever seated row"); no equipment word = body weight.
String equipmentOfName(String name) {
  final n = name.toLowerCase();
  if (n.contains('trap bar')) return 'trap bar';
  if (n.contains('ez bar') || n.contains('ez-bar')) return 'ez barbell';
  if (n.contains('smith')) return 'smith machine';
  if (n.contains('barbell')) return 'barbell';
  if (n.contains('dumbbell')) return 'dumbbell';
  if (n.contains('kettlebell')) return 'kettlebell';
  if (n.contains('cable')) return 'cable';
  if (n.contains('sled') || n.contains('leg press')) return 'sled machine';
  if (n.contains('lever') && !n.contains('front lever') && !n.contains('back lever') || n.contains('machine') || n.contains('pec deck')) {
    return 'leverage machine';
  }
  if (n.contains('band')) return 'band';
  if (n.contains('weighted')) return 'weighted';
  if (n.contains('assisted')) return 'assisted';
  return 'body weight';
}

/// Share of the body weight a bodyweight exercise moves per rep – its "load" for volume, e1RM
/// and the load progression (set weights are added load on top). 0 for loaded exercises
/// (barbell, dumbbell, machine, cable), timed holds (their measure is the hold time, not
/// kg × reps) and unknown exercises.
///
/// Approximations from force-plate and segment-mass data:
/// * Push-up ≈ 64 % of body weight, from the knees ≈ 49 %, hands raised (incline) ≈ 41–55 %,
///   feet raised (decline) ≈ 70–74 % (Ebben et al. 2011, J Strength Cond Res 25:2891;
///   Suprak et al. 2011). Wall push-up ≈ 25 % (estimate, arms almost vertical). Pike push-up
///   ≈ 70 %, handstand push-up ≈ 95 % (body minus forearms/hands).
/// * Pull-up, chin-up, muscle-up, parallel-bar dip: 100 % (the whole body is lifted; the
///   hands' ~1 % is ignored). Bench / chair dips ≈ 50 % (feet carry the rest).
/// * Inverted row ≈ 60 % (feet on the floor; ~50–70 % depending on the body angle).
/// * Bodyweight squat, lunge, split squat, step-up ≈ 70 % (the body above the knees is ~88 %
///   of the mass – Winter 2009 segment table: foot 1.45 %, shank 4.65 % per leg – but the hips
///   travel a shorter path than a loaded bar; common practice value). Pistol / single-leg
///   squat ≈ 90 % (nearly the whole body on one leg).
/// * Hip thrust, glute bridge ≈ 50 % (pelvis and trunk rotate about the shoulders, the legs
///   stay put).
/// * Calf raise ≈ 95 % (everything above the feet).
/// * Back extension ≈ 50 % (upper body ≈ 60 % of the mass rotating about the hips).
/// * Nordic curl ≈ 60 % (body above the knees lowered about the knees; rough estimate).
/// * Burpee ≈ 50 % (squat thrust + push-up phases move roughly half the body).
/// * Sit-up, crunch, leg / knee raise, V-up and similar trunk work ≈ 30 % (trunk or both legs –
///   each leg is ~16 % of the body mass, Winter 2009). Dead bug / bird dog ≈ 15 % (limbs only).
///   Ab wheel rollout ≈ 50 %.
double bodyShareOf(String exId, String name, {String? equipment}) =>
    _shareCache.putIfAbsent('$exId|$name|${equipment ?? ''}', () => _bodyShare(exId, name, equipment));

/// Share of the body weight a bodyweight exercise counts in the volume load (kg × reps): its
/// [bodyShareOf] where the loaded counterpart's volume has no body weight in it either – the
/// body takes the place of the external load: push-ups (≈ bench press), pull-ups / chin-ups /
/// muscle-ups (≈ pulldown), dips, inverted rows (≈ rows) and the Nordic curl (≈ leg curl).
/// 0 for squats, lunges, step-ups, calf raises, bridges / hip thrusts, back extensions and trunk
/// work: their loaded variants move the body too but count only the bar or dumbbells, so
/// counting it in the bodyweight variant would make the volume collapse when the athlete
/// progresses from bodyweight to loaded squats (80 kg: 3 × 20 bodyweight squats ≈ 3 360 kg,
/// 3 × 8 back squats at 60 kg = 1 440 kg). Their added load still counts.
double volumeBodyShareOf(String exId, String name) => _volumeShareCache.putIfAbsent('$exId|$name', () {
  final share = bodyShareOf(exId, name);
  if (share <= 0) return 0;
  final n = name.toLowerCase();
  final replacesLoad =
      _any(n, const ['pull-up', 'pull up', 'pullup', 'chin-up', 'chin up', 'chinup', 'muscle up', 'muscle-up']) ||
      (n.contains('dip') && !n.contains('hip')) ||
      _any(n, const ['push-up', 'push up', 'pushup', 'press-up']) ||
      n.contains('inverted row') ||
      (n.contains('australian') && n.contains('pull')) ||
      n.contains('nordic');
  return replacesLoad ? share : 0.0;
});

final _volumeShareCache = <String, double>{};

double _bodyShare(String exId, String name, String? equipment) {
  if (exId == 'manual' || isTimedExercise(exId, name)) return 0;
  final n = name.toLowerCase();
  final eq = equipment ?? equipmentOfName(n);
  final loaded = _loadedEquipment.contains(eq);
  if (_any(n, const ['pull-up', 'pull up', 'pullup', 'chin-up', 'chin up', 'chinup', 'muscle up', 'muscle-up']) && eq != 'cable') {
    return 1;
  }
  if (loaded) return 0;
  if (n.contains('dip') && !n.contains('hip')) return n.contains('bench') || n.contains('chair') ? 0.5 : 1;
  if (_any(n, const ['push-up', 'push up', 'pushup', 'press-up'])) {
    if (n.contains('handstand')) return 0.95;
    if (n.contains('pike')) return 0.7;
    if (n.contains('knee')) return 0.49;
    if (n.contains('wall')) return 0.25;
    if (n.contains('incline')) return 0.41;
    if (n.contains('decline') || n.contains('feet elevated')) return 0.7;
    return 0.64;
  }
  if (n.contains('inverted row') || (n.contains('australian') && n.contains('pull'))) return 0.6;
  if (_any(n, const ['pistol', 'single leg squat', 'one leg squat', 'shrimp squat'])) return 0.9;
  if (_any(n, const ['lunge', 'split squat', 'step-up', 'step up'])) return 0.7;
  if (n.contains('squat')) return 0.7;
  if (_any(n, const ['hip thrust', 'glute bridge', 'bridge'])) return 0.5;
  if (n.contains('calf')) return 0.95;
  if (n.contains('nordic')) return 0.6;
  if (_any(n, const ['back extension', 'hyperextension', 'hip extension'])) return 0.5;
  if (n.contains('burpee')) return 0.5;
  if (_any(n, const ['ab wheel', 'rollout', 'roll out'])) return 0.5;
  if (_any(n, const ['dead bug', 'bird dog'])) return 0.15;
  if (_any(n, const [
    'sit-up',
    'sit up',
    'situp',
    'crunch',
    'leg raise',
    'knee raise',
    'hip raise',
    'v-up',
    'v up',
    'jackknife',
    'toes to bar',
    'russian twist',
    'flutter kick',
    'scissor',
    'mountain climber',
  ])) {
    return 0.3;
  }
  return 0;
}

/// Non-breaking space (number and unit never wrap apart; pure Dart – not core/format.dart's).
const _nbsp = ' ';
