import '../core/sport.dart';
import 'models.dart';

/// Built-in, evidence-based programs (see docs/training-science.md §5 "Strength").
///
/// Design rules used for every gym program:
/// * Each muscle is trained ≥ 2×/week in every split except the bro split
///   (Schoenfeld 2016 meta-analysis; Pelland 2024: frequency mainly matters through
///   weekly volume, but splitting volume over ≥ 2 sessions keeps sessions productive).
/// * Weekly hard sets per muscle: ~9–12 (full body / home) up to ~12–18 (UL, PPL) –
///   inside the 10–20 sets/week range of the dose–response data (Schoenfeld 2017,
///   Baz-Valle 2022, Pelland 2024). Beginners progress well with the lower end.
/// * Compound lifts first, heavier rep ranges (4–8) with 2–3 min rest; accessories
///   8–15/12–20 reps with 60–90 s rest (Schoenfeld 2016 rest-interval study, Grgic 2017).
/// * Rep ranges are double-progression targets: start at the low end, add reps each
///   session until the top of the range is reached on all sets, then add load.
/// * Effort: 1–3 reps in reserve (Robinson 2024: hypertrophy is similar near but not at
///   failure; strength benefits less from failure).
///
/// Endurance templates are generic structured workouts (zones, no personal paces).
class BuiltinProgram {
  const BuiltinProgram(this.key, this.folderKey, this.en, this.de);
  final String key;
  final String folderKey;
  final String en;
  final String de;
}

/// Folder display names.
const _folders = {
  'fullbody': ('Full Body', 'Ganzkörper'),
  'upperlower': ('Upper / Lower', 'Oberkörper / Unterkörper'),
  'ppl': ('Push Pull Legs', 'Push Pull Beine'),
  'bro': ('Bro Split', 'Bro-Split'),
  'home': ('Home (dumbbells)', 'Zuhause (Kurzhanteln)'),
  'bodyweight': ('Bodyweight', 'Eigengewicht'),
  'run': ('Running', 'Laufen'),
  'ride': ('Cycling', 'Radfahren'),
  'swim': ('Swimming', 'Schwimmen'),
};

String folderName(String folderKey, bool de) {
  final f = _folders[folderKey]!;
  return de ? f.$2 : f.$1;
}

/// Gym split → rotation of program keys used by the plan generator.
const splitRotation = {
  'fullbody': ['fb_a', 'fb_b', 'fb_c'],
  'upperlower': ['ul_upper_a', 'ul_lower_a', 'ul_upper_b', 'ul_lower_b'],
  'ppl': ['ppl_push', 'ppl_pull', 'ppl_legs'],
  'ulppl': ['ul_upper_a', 'ul_lower_a', 'ppl_push', 'ppl_pull', 'ppl_legs'],
  'bro': ['bro_chest', 'bro_back', 'bro_shoulders', 'bro_legs', 'bro_arms'],
  'home': ['home_a', 'home_b'],
  'bodyweight': ['bw_a', 'bw_b'],
};

/// Programs that load the legs heavily (avoided the day before a key endurance session).
const legHeavyKeys = {'ul_lower_a', 'ul_lower_b', 'ppl_legs', 'bro_legs'};

/// Recommended split for a number of gym days per week (and concurrent endurance load).
///
/// 1–3 days: full body (each muscle 2–3×/week). 4: upper/lower. 5: upper/lower + PPL
/// hybrid. 6: PPL twice. With a large endurance load (≥ 4 endurance sessions) the split
/// stays at upper/lower for 4+ gym days so leg sessions stay rare and recoverable.
String recommendedSplit(int gymDays, {int enduranceSessions = 0}) {
  if (gymDays <= 3) return 'fullbody';
  if (gymDays == 4 || enduranceSessions >= 4) return 'upperlower';
  if (gymDays == 5) return 'ulppl';
  return 'ppl';
}

/// Muscle frequency (times per week each muscle is trained) for a split and gym days.
double splitFrequency(String split, int gymDays) => switch (split) {
  'fullbody' => gymDays.toDouble(),
  'upperlower' => gymDays / 2,
  'ppl' => gymDays / 3,
  'ulppl' => gymDays >= 5 ? 2 : gymDays / 2.5,
  'bro' => 1,
  _ => gymDays / 2,
};

GymExercise _e(String id, String name, int sets, int lo, int hi, {int rest = 90, String? group}) => GymExercise(
  exId: id,
  name: name,
  restSec: rest,
  repMin: lo,
  repMax: hi,
  group: group,
  sets: List.generate(sets, (_) => GymSet(reps: lo)),
);

// Exercise shortcuts (ids from assets/data/exercises.json).
GymExercise _squat(int s, int lo, int hi) => _e('0043', 'barbell full squat', s, lo, hi, rest: 180);
GymExercise _bench(int s, int lo, int hi) => _e('0025', 'barbell bench press', s, lo, hi, rest: 150);
GymExercise _deadlift(int s, int lo, int hi) => _e('0032', 'barbell deadlift', s, lo, hi, rest: 180);
GymExercise _rdl(int s, int lo, int hi) => _e('0085', 'barbell romanian deadlift', s, lo, hi, rest: 120);
GymExercise _bbRow(int s, int lo, int hi) => _e('0027', 'barbell bent over row', s, lo, hi, rest: 120);
GymExercise _pullup(int s, int lo, int hi) => _e('0652', 'pull-up', s, lo, hi, rest: 150);
GymExercise _pulldown(int s, int lo, int hi) => _e('2330', 'cable lat pulldown full range of motion', s, lo, hi, rest: 120);
GymExercise _cableRow(int s, int lo, int hi) => _e('0861', 'cable seated row', s, lo, hi, rest: 120);
GymExercise _inclineDb(int s, int lo, int hi) => _e('0314', 'dumbbell incline bench press', s, lo, hi, rest: 120);
GymExercise _dbBench(int s, int lo, int hi) => _e('0289', 'dumbbell bench press', s, lo, hi, rest: 120);
GymExercise _dbShoulder(int s, int lo, int hi) => _e('0405', 'dumbbell seated shoulder press', s, lo, hi, rest: 120);
GymExercise _dbOhp(int s, int lo, int hi) => _e('0426', 'dumbbell standing overhead press', s, lo, hi, rest: 120);
GymExercise _lateral(int s, {String? g}) => _e('0334', 'dumbbell lateral raise', s, 12, 20, rest: 60, group: g);
GymExercise _rearFly(int s, {String? g}) => _e('0378', 'dumbbell rear fly', s, 12, 20, rest: 60, group: g);
GymExercise _fly(int s) => _e('0227', 'cable standing fly', s, 12, 15, rest: 60);
GymExercise _pushdown(int s, {String? g}) => _e('0241', 'cable triceps pushdown (v-bar)', s, 10, 15, rest: 60, group: g);
GymExercise _ohExt(int s, {String? g}) => _e('0194', 'cable overhead triceps extension (rope attachment)', s, 10, 15, rest: 60, group: g);
GymExercise _bbCurl(int s, {String? g}) => _e('0031', 'barbell curl', s, 8, 12, rest: 60, group: g);
GymExercise _inclineCurl(int s, {String? g}) => _e('0318', 'dumbbell incline curl', s, 10, 15, rest: 60, group: g);
GymExercise _hammer(int s, {String? g}) => _e('0313', 'dumbbell hammer curl', s, 10, 15, rest: 60, group: g);
GymExercise _legPress(int s) => _e('0739', 'sled 45° leg press', s, 10, 15, rest: 120);
GymExercise _legExt(int s) => _e('0585', 'lever leg extension', s, 10, 15, rest: 75);
GymExercise _lyingCurl(int s) => _e('0586', 'lever lying leg curl', s, 10, 15, rest: 75);
GymExercise _seatedCurl(int s) => _e('0599', 'lever seated leg curl', s, 10, 15, rest: 75);
GymExercise _lunge(int s) => _e('0336', 'dumbbell lunge', s, 8, 12, rest: 90);
GymExercise _calf(int s) => _e('0605', 'lever standing calf raise', s, 10, 15, rest: 60);
GymExercise _seatedCalf(int s) => _e('0594', 'lever seated calf raise', s, 12, 20, rest: 60);
GymExercise _legRaise(int s) => _e('0472', 'hanging leg raise', s, 8, 15, rest: 60);
GymExercise _deadBug(int s) => _e('0276', 'dead bug', s, 8, 12, rest: 45);

WorkoutTemplate _gym(
  String id,
  String key,
  String folderKey,
  String en,
  String de,
  bool isDe,
  List<GymExercise> ex, {
  required int order,
  String descEn = '',
  String descDe = '',
}) => WorkoutTemplate(
  id: id,
  key: key,
  name: isDe ? de : en,
  sport: Sport.gym,
  folder: folderName(folderKey, isDe),
  exercises: ex,
  order: order,
  description: isDe ? descDe : descEn,
);

WorkoutStep _st(String kind, String zone, {int? sec, double? m, String note = ''}) =>
    WorkoutStep(kind: kind, zone: zone, durationSec: sec, distanceM: m, note: note);

List<WorkoutStep> _repeat(int n, List<WorkoutStep> work, List<WorkoutStep> rest) => [
  for (var i = 0; i < n; i++) ...[...work, if (i < n - 1) ...rest],
];

WorkoutTemplate _cardio(
  String id,
  String key,
  Sport sport,
  String folderKey,
  String en,
  String de,
  bool isDe,
  String intensity,
  List<WorkoutStep> steps, {
  required int order,
  String descEn = '',
  String descDe = '',
}) => WorkoutTemplate(
  id: id,
  key: key,
  name: isDe ? de : en,
  sport: sport,
  folder: folderName(folderKey, isDe),
  intensity: intensity,
  steps: steps,
  order: order,
  description: isDe ? descDe : descEn,
);

/// All built-in programs. [de] selects German names.
List<WorkoutTemplate> defaultTemplates(String Function() id, {bool de = false}) => [
  // ── Full body (2–3×/week): ~9–12 sets per muscle per week at 3 sessions.
  _gym(
    id(),
    'fb_a',
    'fullbody',
    'Full Body A',
    'Ganzkörper A',
    de,
    order: 0,
    [_squat(3, 5, 8), _bench(3, 6, 10), _cableRow(3, 8, 12), _rdl(2, 8, 12), _lateral(2), _deadBug(2)],
    descEn: 'Squat focus. 1–3 reps in reserve.',
    descDe: 'Schwerpunkt Kniebeuge. 1–3 Wiederholungen in Reserve.',
  ),
  _gym(
    id(),
    'fb_b',
    'fullbody',
    'Full Body B',
    'Ganzkörper B',
    de,
    order: 1,
    [_deadlift(3, 4, 6), _dbOhp(3, 8, 12), _pulldown(3, 8, 12), _lunge(2), _inclineDb(2, 8, 12), _legRaise(2)],
    descEn: 'Hinge focus. 1–3 reps in reserve.',
    descDe: 'Schwerpunkt Hüftstreckung. 1–3 Wiederholungen in Reserve.',
  ),
  _gym(
    id(),
    'fb_c',
    'fullbody',
    'Full Body C',
    'Ganzkörper C',
    de,
    order: 2,
    [_legPress(3), _pullup(3, 6, 10), _dbBench(3, 8, 12), _lyingCurl(2), _hammer(2, g: 'A'), _pushdown(2, g: 'A')],
    descEn: 'Volume day, arms as a superset.',
    descDe: 'Volumentag, Arme als Supersatz.',
  ),

  // ── Upper / lower (4×/week): each muscle 2×/week, ~12–16 sets.
  _gym(
    id(),
    'ul_upper_a',
    'upperlower',
    'Upper A',
    'Oberkörper A',
    de,
    order: 0,
    [_bench(4, 5, 8), _bbRow(4, 6, 10), _dbShoulder(3, 8, 12), _pulldown(3, 8, 12), _bbCurl(2, g: 'A'), _pushdown(2, g: 'A')],
    descEn: 'Heavy pressing and rowing.',
    descDe: 'Schweres Drücken und Rudern.',
  ),
  _gym(
    id(),
    'ul_lower_a',
    'upperlower',
    'Lower A',
    'Unterkörper A',
    de,
    order: 1,
    [_squat(4, 5, 8), _rdl(3, 8, 10), _legExt(3), _lyingCurl(3), _calf(3), _deadBug(2)],
    descEn: 'Squat day.',
    descDe: 'Kniebeugen-Tag.',
  ),
  _gym(
    id(),
    'ul_upper_b',
    'upperlower',
    'Upper B',
    'Oberkörper B',
    de,
    order: 2,
    [
      _inclineDb(3, 8, 12),
      _pullup(3, 6, 10),
      _cableRow(3, 10, 12),
      _lateral(3, g: 'A'),
      _rearFly(3, g: 'A'),
      _fly(2),
      _inclineCurl(2, g: 'B'),
      _ohExt(2, g: 'B'),
    ],
    descEn: 'Hypertrophy day with supersets.',
    descDe: 'Muskelaufbau-Tag mit Supersätzen.',
  ),
  _gym(
    id(),
    'ul_lower_b',
    'upperlower',
    'Lower B',
    'Unterkörper B',
    de,
    order: 3,
    [_deadlift(3, 4, 6), _legPress(3), _lunge(3), _seatedCurl(3), _seatedCalf(3), _legRaise(3)],
    descEn: 'Deadlift day.',
    descDe: 'Kreuzheben-Tag.',
  ),

  // ── Push / pull / legs (3× or 6×/week).
  _gym(
    id(),
    'ppl_push',
    'ppl',
    'Push',
    'Push',
    de,
    order: 0,
    [_bench(4, 6, 10), _inclineDb(3, 8, 12), _dbShoulder(3, 8, 12), _lateral(3), _pushdown(3, g: 'A'), _ohExt(2, g: 'A')],
    descEn: 'Chest, shoulders, triceps.',
    descDe: 'Brust, Schultern, Trizeps.',
  ),
  _gym(
    id(),
    'ppl_pull',
    'ppl',
    'Pull',
    'Pull',
    de,
    order: 1,
    [_pullup(3, 6, 10), _bbRow(3, 6, 10), _pulldown(3, 10, 12), _rearFly(3), _bbCurl(3, g: 'A'), _hammer(2, g: 'A')],
    descEn: 'Back, rear delts, biceps.',
    descDe: 'Rücken, hintere Schulter, Bizeps.',
  ),
  _gym(
    id(),
    'ppl_legs',
    'ppl',
    'Legs',
    'Beine',
    de,
    order: 2,
    [_squat(4, 5, 8), _rdl(3, 8, 10), _legPress(3), _lyingCurl(3), _calf(4), _legRaise(3)],
    descEn: 'Quads, hamstrings, glutes, calves.',
    descDe: 'Oberschenkel, Gesäß, Waden.',
  ),

  // ── Bro split (5×/week, each muscle 1×/week – supported, but less efficient).
  _gym(
    id(),
    'bro_chest',
    'bro',
    'Chest',
    'Brust',
    de,
    order: 0,
    [_bench(4, 6, 10), _inclineDb(4, 8, 12), _dbBench(3, 8, 12), _fly(3)],
    descEn: 'Each muscle once a week – 2×/week usually builds more muscle.',
    descDe: 'Jeder Muskel 1×/Woche – 2×/Woche bringt meist mehr.',
  ),
  _gym(id(), 'bro_back', 'bro', 'Back', 'Rücken', de, order: 1, [
    _deadlift(3, 4, 6),
    _pullup(4, 6, 10),
    _bbRow(3, 8, 10),
    _cableRow(3, 10, 12),
  ]),
  _gym(id(), 'bro_shoulders', 'bro', 'Shoulders', 'Schultern', de, order: 2, [
    _dbShoulder(4, 8, 12),
    _lateral(4),
    _rearFly(4),
    _e('0178', 'cable lateral raise', 3, 12, 20, rest: 60),
  ]),
  _gym(id(), 'bro_legs', 'bro', 'Legs', 'Beine', de, order: 3, [
    _squat(4, 5, 8),
    _legPress(3),
    _rdl(3, 8, 10),
    _legExt(3),
    _lyingCurl(3),
    _calf(4),
  ]),
  _gym(id(), 'bro_arms', 'bro', 'Arms', 'Arme', de, order: 4, [
    _bbCurl(3, g: 'A'),
    _pushdown(3, g: 'A'),
    _inclineCurl(3, g: 'B'),
    _ohExt(3, g: 'B'),
    _hammer(3, g: 'C'),
    _e('0814', 'triceps dip', 3, 8, 12, rest: 60, group: 'C'),
  ]),

  // ── Home (dumbbells + bench): full body A/B.
  _gym(id(), 'home_a', 'home', 'Home A', 'Zuhause A', de, order: 0, [
    _e('1760', 'dumbbell goblet squat', 3, 8, 15),
    _dbBench(3, 8, 12),
    _e('0293', 'dumbbell bent over row', 3, 8, 12),
    _e('1459', 'dumbbell romanian deadlift', 3, 8, 12),
    _lateral(2, g: 'A'),
    _hammer(2, g: 'A'),
    _deadBug(2),
  ]),
  _gym(id(), 'home_b', 'home', 'Home B', 'Zuhause B', de, order: 1, [
    _e('0381', 'dumbbell rear lunge', 3, 8, 12),
    _dbOhp(3, 8, 12),
    _e('0499', 'inverted row', 3, 6, 12),
    _e('1757', 'dumbbell single leg deadlift', 2, 8, 12),
    _e('0662', 'push-up', 3, 8, 20, rest: 60),
    _e('0409', 'dumbbell single leg calf raise', 2, 10, 15, rest: 45),
  ]),

  // ── Bodyweight: full body A/B (progress via reps, tempo and harder variations).
  _gym(id(), 'bw_a', 'bodyweight', 'Bodyweight A', 'Eigengewicht A', de, order: 0, [
    _e('1460', 'walking lunge', 3, 10, 20, rest: 60),
    _e('0662', 'push-up', 3, 8, 20, rest: 60),
    _e('0499', 'inverted row', 3, 6, 15, rest: 75),
    _e('3561', 'glute bridge march', 3, 10, 20, rest: 45),
    _e('1373', 'bodyweight standing calf raise', 2, 15, 25, rest: 45),
    _deadBug(3),
  ]),
  _gym(id(), 'bw_b', 'bodyweight', 'Bodyweight B', 'Eigengewicht B', de, order: 1, [
    _e('0514', 'jump squat', 3, 8, 15, rest: 75),
    _e('1326', 'chin-up', 3, 3, 10, rest: 120),
    _e('0129', 'bench dip (knees bent)', 3, 8, 15, rest: 60),
    _e('0410', 'dumbbell single leg split squat', 3, 8, 12, rest: 60),
    _e('0630', 'mountain climber', 3, 20, 40, rest: 45),
    _legRaise(2),
  ]),

  // ── Running (structured, zones only).
  _cardio(
    id(),
    'run_easy',
    Sport.run,
    'run',
    'Easy Run',
    'Lockerer Lauf',
    de,
    'easy',
    order: 0,
    [_st('steady', 'E', sec: 40 * 60)],
    descEn: 'Zone 2 – you can talk in full sentences.',
    descDe: 'Zone 2 – du kannst in ganzen Sätzen reden.',
  ),
  _cardio(
    id(),
    'run_long',
    Sport.run,
    'run',
    'Long Run',
    'Langer Lauf',
    de,
    'long',
    order: 1,
    [_st('steady', 'L', sec: 80 * 60)],
    descEn: 'Easy and steady. From 75 min take carbs every 30–40 min.',
    descDe: 'Locker und gleichmäßig. Ab 75 min alle 30–40 min Kohlenhydrate.',
  ),
  _cardio(id(), 'run_strides', Sport.run, 'run', 'Easy + Strides', 'Locker + Steigerungen', de, 'easy', order: 2, [
    _st('steady', 'E', sec: 30 * 60),
    ..._repeat(6, [_st('work', 'R', sec: 20)], [_st('recovery', 'walk', sec: 60)]),
  ]),
  _cardio(
    id(),
    'run_tempo',
    Sport.run,
    'run',
    'Tempo Run 20 min',
    'Tempodauerlauf 20 min',
    de,
    'tempo',
    order: 3,
    [_st('warmup', 'E', sec: 12 * 60), _st('work', 'T', sec: 20 * 60), _st('cooldown', 'E', sec: 10 * 60)],
    descEn: 'Comfortably hard – about your 1-hour race pace.',
    descDe: 'Angenehm hart – etwa dein 1-Stunden-Wettkampftempo.',
  ),
  _cardio(
    id(),
    'run_intervals',
    Sport.run,
    'run',
    'Intervals 5×1000 m',
    'Intervalle 5×1000 m',
    de,
    'intervals',
    order: 4,
    [
      _st('warmup', 'E', sec: 15 * 60),
      ..._repeat(5, [_st('work', 'I', m: 1000)], [_st('recovery', 'REC', sec: 180)]),
      _st('cooldown', 'E', sec: 10 * 60),
    ],
    descEn: 'About 3–5 km race pace. Total hard volume ≤ 8 % of weekly km.',
    descDe: 'Etwa 3–5-km-Wettkampftempo. Harter Umfang ≤ 8 % der Wochen-km.',
  ),
  _cardio(id(), 'run_fartlek', Sport.run, 'run', 'Fartlek', 'Fahrtspiel', de, 'tempo', order: 5, [
    _st('warmup', 'E', sec: 10 * 60),
    ..._repeat(8, [_st('work', 'I', sec: 60)], [_st('recovery', 'REC', sec: 90)]),
    _st('cooldown', 'E', sec: 10 * 60),
  ]),

  // ── Cycling.
  _cardio(
    id(),
    'ride_z2',
    Sport.ride,
    'ride',
    'Endurance Ride',
    'Grundlagenfahrt',
    de,
    'easy',
    order: 0,
    [_st('steady', 'Z2', sec: 75 * 60)],
    descEn: 'Zone 2, cadence 85–95 rpm.',
    descDe: 'Zone 2, Trittfrequenz 85–95 U/min.',
  ),
  _cardio(
    id(),
    'ride_ss',
    Sport.ride,
    'ride',
    'Sweet Spot 3×12',
    'Sweet Spot 3×12',
    de,
    'tempo',
    order: 1,
    [
      _st('warmup', 'Z2', sec: 10 * 60),
      ..._repeat(3, [_st('work', 'SS', sec: 12 * 60)], [_st('recovery', 'Z1', sec: 4 * 60)]),
      _st('cooldown', 'Z1', sec: 10 * 60),
    ],
    descEn: '88–94 % FTP.',
    descDe: '88–94 % FTP.',
  ),
  _cardio(
    id(),
    'ride_vo2',
    Sport.ride,
    'ride',
    'VO2max 5×4 min',
    'VO2max 5×4 min',
    de,
    'intervals',
    order: 2,
    [
      _st('warmup', 'Z2', sec: 15 * 60),
      ..._repeat(5, [_st('work', 'Z5', sec: 4 * 60)], [_st('recovery', 'Z1', sec: 4 * 60)]),
      _st('cooldown', 'Z1', sec: 10 * 60),
    ],
    descEn: '106–120 % FTP (Rønnestad-style intervals).',
    descDe: '106–120 % FTP (Intervalle nach Rønnestad).',
  ),
  _cardio(
    id(),
    'ride_long',
    Sport.ride,
    'ride',
    'Long Ride',
    'Lange Ausfahrt',
    de,
    'long',
    order: 3,
    [_st('steady', 'Z2', sec: 150 * 60)],
    descEn: 'Eat 40–60 g carbs per hour.',
    descDe: '40–60 g Kohlenhydrate pro Stunde.',
  ),

  // ── Swimming.
  _cardio(id(), 'swim_tech', Sport.swim, 'swim', 'Technique Swim', 'Technikschwimmen', de, 'technique', order: 0, [
    _st('warmup', 'REC', m: 300),
    ..._repeat(8, [_st('work', 'DR', m: 50)], [_st('recovery', 'REC', sec: 20)]),
    _st('recovery', 'REC', sec: 60),
    ..._repeat(6, [_st('work', 'EN', m: 100)], [_st('recovery', 'REC', sec: 20)]),
    _st('cooldown', 'REC', m: 200),
  ]),
  _cardio(
    id(),
    'swim_css',
    Sport.swim,
    'swim',
    'CSS 10×100',
    'CSS 10×100',
    de,
    'intervals',
    order: 1,
    [
      _st('warmup', 'REC', m: 400),
      ..._repeat(10, [_st('work', 'CSS', m: 100)], [_st('recovery', 'REC', sec: 15)]),
      _st('cooldown', 'REC', m: 200),
    ],
    descEn: 'At your critical swim speed.',
    descDe: 'In deiner kritischen Schwimmgeschwindigkeit (CSS).',
  ),
  _cardio(id(), 'swim_endurance', Sport.swim, 'swim', 'Endurance 4×400', 'Ausdauer 4×400', de, 'moderate', order: 2, [
    _st('warmup', 'REC', m: 300),
    ..._repeat(4, [_st('work', 'EN', m: 400)], [_st('recovery', 'REC', sec: 30)]),
    _st('cooldown', 'REC', m: 200),
  ]),
];

/// Built-in programs whose key is not yet present in [existing] (for adding missing ones).
List<WorkoutTemplate> missingBuiltins(List<WorkoutTemplate> existing, String Function() id, {bool de = false, Set<String>? only}) {
  final have = existing.map((t) => t.key).whereType<String>().toSet();
  return defaultTemplates(id, de: de).where((t) => !have.contains(t.key) && (only == null || only.contains(t.key))).toList();
}
