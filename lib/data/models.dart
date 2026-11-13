import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/event_distances.dart';
import '../core/format.dart';
import '../core/sport.dart';
import 'exercise_measure.dart';

DateTime _date(dynamic v) {
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.now();
}

// Tolerant parsing: Firestore data may come from older app versions, the console or a
// partial write – a wrong type falls back to the default instead of throwing.
double? _dn(dynamic v) => switch (v) {
  num n when n.isFinite => n.toDouble(),
  String s => double.tryParse(s.trim().replaceAll(',', '.')),
  _ => null,
};
double _d(dynamic v, [double def = 0]) => _dn(v) ?? def;
int? _in(dynamic v) => switch (v) {
  int n => n,
  num n when n.isFinite => n.round(),
  String s => int.tryParse(s.trim()) ?? double.tryParse(s.trim())?.round(),
  _ => null,
};
int _i(dynamic v, [int def = 0]) => _in(v) ?? def;
String _s(dynamic v, [String def = '']) => v is String ? v : (v == null ? def : '$v');
String? _sn(dynamic v) => v is String ? v : null;
bool _b(dynamic v, [bool def = false]) => v is bool ? v : def;
List<Map> _maps(dynamic v) => v is List ? v.whereType<Map>().toList() : const [];
List<String> _strings(dynamic v) =>
    v is List
        ? [
          for (final x in v)
            if (x != null) '$x',
        ]
        : const [];
List<int> _ints(dynamic v) =>
    v is List
        ? [
          for (final x in v)
            if (_in(x) != null) _in(x)!,
        ]
        : const [];

/// Map with int keys ("1".."7" in Firestore); keys or values that do not parse are skipped.
Map<int, T> _intKeyed<T>(dynamic v, T? Function(dynamic) value) => {
  if (v is Map)
    for (final e in v.entries)
      if (int.tryParse('${e.key}') case final k?)
        if (value(e.value) case final T x) k: x,
};

// ───────────────────────────── Profile ─────────────────────────────

/// Training days before the athlete chose any (1 = Monday): Tue / Thu / Sat – rest days spread and the long
/// session (and a race given as a plan length) on the weekend. Mon / Wed / Fri put a quick-setup hybrid 10 km
/// plan's long run and race on a Friday (QA 2026-11).
const defaultTrainingDays = [2, 4, 6];

class UserProfile {
  final String name;
  final int? birthYear;
  final String gender; // m | f | d
  final double heightCm;
  final double weightKg;
  final double? fatPct;
  final double? musclePct;
  final String level; // beginner | intermediate | advanced
  final Set<Sport> experience;
  final TrainingFocus focus;
  final List<String> goals; // strength, muscle, fatloss, endurance, health, race
  final List<int> trainingDays; // 1 = Monday … 7 = Sunday
  final int? longDay;
  final bool imperial;
  final int? maxHr;
  final bool onboarded;
  final AthleteData athlete;
  final List<String> folderOrder; // program folders on the Train page, in display order

  const UserProfile({
    this.name = '',
    this.birthYear,
    this.gender = 'd',
    this.heightCm = 175,
    this.weightKg = 75,
    this.fatPct,
    this.musclePct,
    this.level = 'beginner',
    this.experience = const {},
    this.focus = TrainingFocus.gym,
    this.goals = const [],
    this.trainingDays = defaultTrainingDays,
    this.longDay,
    this.imperial = false,
    this.maxHr,
    this.onboarded = false,
    this.athlete = const AthleteData(),
    this.folderOrder = const [],
  });

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  /// Training days the generated plan uses at most (quick setup): beginners keep ≥ 2
  /// rest days (pure strength ≤ 4 days), athletes ≥ 60 one – see PlanGenerator.
  int get maxPlanDays => level == 'beginner' ? (focus == TrainingFocus.gym ? 4 : 5) : ((age ?? 0) >= 60 ? 6 : 7);
  int get weeklyTarget => trainingDays.isEmpty ? 3 : (trainingDays.length < maxPlanDays ? trainingDays.length : maxPlanDays);
  double get bmi => heightCm <= 0 ? 0 : weightKg / ((heightCm / 100) * (heightCm / 100));

  /// Measured HRmax, else predicted: women Gulati 2010 (206 − 0.88·age, n = 5437 women –
  /// Tanaka overestimates female HRmax by ~5 bpm at 50), everyone else Tanaka 2001
  /// (208 − 0.7·age). See docs/training-science.md §5.
  int get estimatedMaxHr {
    if (maxHr != null) return maxHr!;
    if (age == null) return gender == 'f' ? 185 : 190;
    return gender == 'f' ? (206 - 0.88 * age!).round() : (208 - 0.7 * age!).round();
  }

  Units get units => Units(imperial);

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    name: _s(m['name']),
    birthYear: _in(m['birthYear']),
    gender: _s(m['gender'], 'd'),
    heightCm: _d(m['heightCm'], 175),
    weightKg: _d(m['weightKg'], 75),
    fatPct: _dn(m['fatPct']),
    musclePct: _dn(m['musclePct']),
    level: _s(m['level'], 'beginner'),
    experience: _strings(m['experience']).map(SportX.parse).toSet(),
    focus: TrainingFocusX.parse(_sn(m['focus'])),
    goals: _strings(m['goals']),
    trainingDays:
        m['trainingDays'] is List
            ? [
              for (final d in _ints(m['trainingDays']))
                if (d >= 1 && d <= 7) d,
            ]
            : defaultTrainingDays,
    longDay: _in(m['longDay']),
    imperial: _b(m['imperial']),
    maxHr: _in(m['maxHr']),
    onboarded: _b(m['onboarded']),
    athlete: AthleteData.fromMap(m['athlete'] is Map ? Map<String, dynamic>.from(m['athlete'] as Map) : const {}),
    folderOrder: _strings(m['folderOrder']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'birthYear': birthYear,
    'gender': gender,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'fatPct': fatPct,
    'musclePct': musclePct,
    'level': level,
    'experience': experience.map((e) => e.name).toList(),
    'focus': focus.name,
    'goals': goals,
    'trainingDays': trainingDays,
    'longDay': longDay,
    'imperial': imperial,
    'maxHr': maxHr,
    'onboarded': onboarded,
    'athlete': athlete.toMap(),
    'folderOrder': folderOrder,
  };

  UserProfile copyWith({
    String? name,
    int? birthYear,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? fatPct,
    double? musclePct,
    String? level,
    Set<Sport>? experience,
    TrainingFocus? focus,
    List<String>? goals,
    List<int>? trainingDays,
    int? longDay,
    bool? imperial,
    int? maxHr,
    bool? onboarded,
    AthleteData? athlete,
    List<String>? folderOrder,
  }) => UserProfile(
    name: name ?? this.name,
    birthYear: birthYear ?? this.birthYear,
    gender: gender ?? this.gender,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    fatPct: fatPct ?? this.fatPct,
    musclePct: musclePct ?? this.musclePct,
    level: level ?? this.level,
    experience: experience ?? this.experience,
    focus: focus ?? this.focus,
    goals: goals ?? this.goals,
    trainingDays: trainingDays ?? this.trainingDays,
    longDay: longDay ?? this.longDay,
    imperial: imperial ?? this.imperial,
    maxHr: maxHr ?? this.maxHr,
    onboarded: onboarded ?? this.onboarded,
    athlete: athlete ?? this.athlete,
    folderOrder: folderOrder ?? this.folderOrder,
  );
}

/// Detailed, sport-specific athlete data from the (advanced) setup.
/// Everything is optional – the plan generator falls back to level defaults.
class AthleteData {
  final String setupMode; // simple | advanced
  final String difficulty; // easy | balanced | challenging
  final int planWeeks;
  final int sessionMinutes; // max. training time per day (minutes) – default for every day
  final Map<int, int> dayMinutes; // optional per-weekday override (1..7 → minutes)
  final int sessionsPerDay; // 1 | 2
  final Map<int, List<Sport>> dayPlan; // weekday (1..7) → sports on that day
  final String preferredTime; // morning | midday | evening
  final int? restHr;
  final List<String> limitations; // knee, back, shoulder, …
  // Running
  final Map<String, int> raceTimes; // '5k' | '10k' | 'hm' | 'm' → seconds
  final double? runWeeklyKm;
  final double? longestRunKm; // last 4 weeks
  final bool canRun30;
  // Cycling
  final int? ftp;
  final double? bikeWeeklyHours;
  final double? longestRideKm;
  final bool hasPowerMeter;
  final bool indoorTrainer;
  // Swimming
  final int? swim400Sec;
  final int? swim200Sec;
  final double? swimWeeklyKm;
  final bool canSwim400;
  final int poolLength;
  // Gym
  final String equipment; // gym | home | bodyweight
  final String gymGoal; // strength | hypertrophy | general
  final String gymSplit; // auto | fullbody | upperlower | ppl | ulppl | bro
  final Map<String, double> oneRm; // squat | bench | deadlift | ohp → kg

  /// Programs the athlete assigned to gym days in the plan setup ("Programme selbst zuweisen"):
  /// weekday (1..7) → program reference ([gymProgramRef]: `key:<built-in key>` or `id:<template id>`).
  /// [gymPlanB] is week B of an A/B alternation ([gymAB]); the plan uses week A in its even weeks
  /// (0, 2, …) and week B in the odd ones. Days without an entry follow the split's rotation.
  final bool gymAssign;
  final bool gymAB;
  final Map<int, String> gymPlanA;
  final Map<int, String> gymPlanB;
  // Event
  final String? eventDistance; // 5k | 10k | hm | m | sprint | olympic | 70.3
  final DateTime? eventDate;
  final int? targetTimeSec;

  /// First day and length (weeks) of the current rule-based plan, written when a plan is
  /// generated (null for plans from before this was stored; [planLength] 0 = the current
  /// plan is not rule-based, e.g. an AI plan of an older version) – lets the recalibration rebuild it to find gaps.
  final DateTime? planStart;
  final int? planLength;

  /// Name of the target event (e.g. taken over from the race search); optional.
  final String? eventName;

  /// Running fitness (VDOT) derived from training by "Plan überprüfen" (Recalibrator), when it was
  /// set, and the race-time VDOT it was derived from ([vdotEstimateBase], 0 = none): it replaces the
  /// race times' VDOT until the athlete enters different race times. Never written into [raceTimes]
  /// (review C5: synthetic marathon times showed up as best times).
  final double? vdotEstimate;
  final DateTime? vdotEstimateAt;
  final double? vdotEstimateBase;

  /// Last training-derived FTP / CSS step of "Plan überprüfen" and the value before the plan's first
  /// step (the base of the per-plan cap): steps ≥ 3 weeks apart, total rise capped like the VDOT's.
  final DateTime? ftpStepAt;
  final int? ftpBase;
  final DateTime? cssStepAt;
  final int? cssBase;

  const AthleteData({
    this.setupMode = 'simple',
    this.difficulty = 'balanced',
    this.planWeeks = 8,
    this.sessionMinutes = 60,
    this.dayMinutes = const {},
    this.sessionsPerDay = 1,
    this.dayPlan = const {},
    this.preferredTime = 'evening',
    this.restHr,
    this.limitations = const [],
    this.raceTimes = const {},
    this.runWeeklyKm,
    this.longestRunKm,
    this.canRun30 = true,
    this.ftp,
    this.bikeWeeklyHours,
    this.longestRideKm,
    this.hasPowerMeter = false,
    this.indoorTrainer = false,
    this.swim400Sec,
    this.swim200Sec,
    this.swimWeeklyKm,
    this.canSwim400 = true,
    this.poolLength = 25,
    this.equipment = 'gym',
    this.gymGoal = 'general',
    this.gymSplit = 'auto',
    this.oneRm = const {},
    this.gymAssign = false,
    this.gymAB = false,
    this.gymPlanA = const {},
    this.gymPlanB = const {},
    this.eventDistance,
    this.eventDate,
    this.targetTimeSec,
    this.planStart,
    this.planLength,
    this.eventName,
    this.vdotEstimate,
    this.vdotEstimateAt,
    this.vdotEstimateBase,
    this.ftpStepAt,
    this.ftpBase,
    this.cssStepAt,
    this.cssBase,
  });

  bool get advanced => setupMode == 'advanced';

  /// Minutes available on [weekday] (per-day override or the global maximum).
  int minutesOn(int weekday) => dayMinutes[weekday] ?? sessionMinutes;

  factory AthleteData.fromMap(Map<String, dynamic> m) => AthleteData(
    setupMode: _s(m['setupMode'], 'simple'),
    difficulty: _s(m['difficulty'], 'balanced'),
    planWeeks: _i(m['planWeeks'], 8),
    sessionMinutes: _i(m['sessionMinutes'], 60),
    dayMinutes: _intKeyed(m['dayMinutes'], _in),
    sessionsPerDay: _i(m['sessionsPerDay'], 1),
    dayPlan: _intKeyed(m['dayPlan'], (v) => v is List ? _strings(v).map(SportX.parse).toList() : null),
    preferredTime: _s(m['preferredTime'], 'evening'),
    restHr: _in(m['restHr']),
    limitations: _strings(m['limitations']),
    // Implausible times (a typo such as 4 s for 10 km) are dropped: every pace model would derive
    // absurd paces from them ([plausibleEventTime]).
    raceTimes: {
      if (m['raceTimes'] is Map)
        for (final e in (m['raceTimes'] as Map).entries)
          if (_in(e.value) case final v? when plausibleEventTime('${e.key}', v)) '${e.key}': v,
    },
    runWeeklyKm: _dn(m['runWeeklyKm']),
    longestRunKm: _dn(m['longestRunKm']),
    canRun30: _b(m['canRun30'], true),
    ftp: _in(m['ftp']),
    bikeWeeklyHours: _dn(m['bikeWeeklyHours']),
    longestRideKm: _dn(m['longestRideKm']),
    hasPowerMeter: _b(m['hasPowerMeter']),
    indoorTrainer: _b(m['indoorTrainer']),
    swim400Sec: _swimTest(m['swim400Sec'], 400),
    swim200Sec: _swimTest(m['swim200Sec'], 200),
    swimWeeklyKm: _dn(m['swimWeeklyKm']),
    canSwim400: _b(m['canSwim400'], true),
    poolLength: _i(m['poolLength'], 25),
    equipment: _s(m['equipment'], 'gym'),
    gymGoal: _s(m['gymGoal'], 'general'),
    gymSplit: _s(m['gymSplit'], 'auto'),
    oneRm: {
      if (m['oneRm'] is Map)
        for (final e in (m['oneRm'] as Map).entries)
          if (_dn(e.value) case final v?) '${e.key}': v,
    },
    gymAssign: _b(m['gymAssign']),
    gymAB: _b(m['gymAB']),
    gymPlanA: _intKeyed(m['gymPlanA'], _sn),
    gymPlanB: _intKeyed(m['gymPlanB'], _sn),
    eventDistance: _sn(m['eventDistance']),
    eventDate: m['eventDate'] == null ? null : _date(m['eventDate']),
    targetTimeSec: switch (_in(m['targetTimeSec'])) {
      final t? when plausibleEventTime(_sn(m['eventDistance']), t) => t,
      _ => null,
    },
    planStart: m['planStart'] == null ? null : _date(m['planStart']),
    planLength: _in(m['planLength']),
    eventName: _sn(m['eventName']),
    vdotEstimate: _dn(m['vdotEstimate']),
    vdotEstimateAt: m['vdotEstimateAt'] == null ? null : _date(m['vdotEstimateAt']),
    vdotEstimateBase: _dn(m['vdotEstimateBase']),
    ftpStepAt: m['ftpStepAt'] == null ? null : _date(m['ftpStepAt']),
    ftpBase: _in(m['ftpBase']),
    cssStepAt: m['cssStepAt'] == null ? null : _date(m['cssStepAt']),
    cssBase: _in(m['cssBase']),
  );

  /// A swim test time within [swimTestBounds], else null.
  static int? _swimTest(dynamic v, int meters) {
    final t = _in(v);
    if (t == null) return null;
    final (lo, hi) = swimTestBounds(meters);
    return t >= lo && t <= hi ? t : null;
  }

  Map<String, dynamic> toMap() => {
    'setupMode': setupMode,
    'difficulty': difficulty,
    'planWeeks': planWeeks,
    'sessionMinutes': sessionMinutes,
    'dayMinutes': {for (final e in dayMinutes.entries) '${e.key}': e.value},
    'sessionsPerDay': sessionsPerDay,
    'dayPlan': {for (final e in dayPlan.entries) '${e.key}': e.value.map((s) => s.name).toList()},
    'preferredTime': preferredTime,
    'restHr': restHr,
    'limitations': limitations,
    'raceTimes': raceTimes,
    'runWeeklyKm': runWeeklyKm,
    'longestRunKm': longestRunKm,
    'canRun30': canRun30,
    'ftp': ftp,
    'bikeWeeklyHours': bikeWeeklyHours,
    'longestRideKm': longestRideKm,
    'hasPowerMeter': hasPowerMeter,
    'indoorTrainer': indoorTrainer,
    'swim400Sec': swim400Sec,
    'swim200Sec': swim200Sec,
    'swimWeeklyKm': swimWeeklyKm,
    'canSwim400': canSwim400,
    'poolLength': poolLength,
    'equipment': equipment,
    'gymGoal': gymGoal,
    'gymSplit': gymSplit,
    'oneRm': oneRm,
    'gymAssign': gymAssign,
    'gymAB': gymAB,
    'gymPlanA': {for (final e in gymPlanA.entries) '${e.key}': e.value},
    'gymPlanB': {for (final e in gymPlanB.entries) '${e.key}': e.value},
    'eventDistance': eventDistance,
    'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
    'targetTimeSec': targetTimeSec,
    if (planStart != null) 'planStart': Timestamp.fromDate(planStart!),
    if (planLength != null) 'planLength': planLength,
    'eventName': eventName,
    if (vdotEstimate != null) 'vdotEstimate': vdotEstimate,
    if (vdotEstimateAt != null) 'vdotEstimateAt': Timestamp.fromDate(vdotEstimateAt!),
    if (vdotEstimateBase != null) 'vdotEstimateBase': vdotEstimateBase,
    if (ftpStepAt != null) 'ftpStepAt': Timestamp.fromDate(ftpStepAt!),
    if (ftpBase != null) 'ftpBase': ftpBase,
    if (cssStepAt != null) 'cssStepAt': Timestamp.fromDate(cssStepAt!),
    if (cssBase != null) 'cssBase': cssBase,
  };

  /// Copy with some fields replaced (keys as in [toMap]); `null` values clear a field.
  AthleteData merge(Map<String, dynamic> changes) {
    final m = toMap();
    // eventDate is stored as Timestamp; keep DateTime inputs working.
    final c = {...changes};
    if (c['eventDate'] is DateTime) c['eventDate'] = Timestamp.fromDate(c['eventDate']);
    if (c['vdotEstimateAt'] is DateTime) c['vdotEstimateAt'] = Timestamp.fromDate(c['vdotEstimateAt']);
    for (final k in const ['ftpStepAt', 'cssStepAt']) {
      if (c[k] is DateTime) c[k] = Timestamp.fromDate(c[k]);
    }
    if (c['dayPlan'] is Map<int, List<Sport>>) {
      c['dayPlan'] = {for (final e in (c['dayPlan'] as Map<int, List<Sport>>).entries) '${e.key}': e.value.map((s) => s.name).toList()};
    }
    if (c['dayMinutes'] is Map<int, int>) {
      c['dayMinutes'] = {for (final e in (c['dayMinutes'] as Map<int, int>).entries) '${e.key}': e.value};
    }
    for (final k in const ['gymPlanA', 'gymPlanB']) {
      if (c[k] is Map<int, String>) c[k] = {for (final e in (c[k] as Map<int, String>).entries) '${e.key}': e.value};
    }
    return AthleteData.fromMap({...m, ...c});
  }
}

// ───────────────────────────── Gym ─────────────────────────────

/// Set type: normal, warm-up, drop set, to failure.
enum SetType { normal, warmup, drop, failure }

/// How hard an exercise felt after its last work set (optional quick rating), mapped to
/// reps in reserve (RIR) on the RIR-based RPE scale (Zourdos et al. 2016; Helms et al.
/// 2016): easy ≈ RIR 4+, right ≈ RIR 2–3, hard ≈ RIR 1, limit ≈ RIR 0.
enum Effort {
  easy(4),
  right(2.5),
  hard(1),
  limit(0);

  const Effort(this.rir);

  /// Reps in reserve this rating stands for.
  final double rir;

  static Effort? fromName(Object? v) => v is String ? Effort.values.where((e) => e.name == v).firstOrNull : null;
}

class GymSet {
  double weight;
  int reps;
  bool done;
  SetType type;
  double? rpe; // 6..10 (RIR = 10 - RPE)

  /// Rep target the app prescribed for this set (null = none / added by hand). Lets the
  /// progression tell "did what was asked" apart from "fell short" (planned descending
  /// targets are not a rep drop-off).
  int? target;

  /// "As many reps as possible – stop 1 rep before failure" set (calibration set the app
  /// asks for on the last work set; see LoadPrescriber).
  bool amrap;

  /// Timed exercises ([GymExercise.isTimed] – plank, wall sit, dead hang, …): the hold time in
  /// seconds – planned while the set is open, held once it is done. [reps] stays 0 then. Sets
  /// of a timed exercise logged before hold times existed carry reps only ([legacyReps]).
  int sec;

  /// Hold time (s) the app prescribed for this set (timed exercises; null = none).
  int? targetSec;

  GymSet({
    this.weight = 0,
    this.reps = 0,
    this.done = false,
    this.type = SetType.normal,
    this.rpe,
    this.target,
    this.amrap = false,
    this.sec = 0,
    this.targetSec,
  });

  bool get warmup => type == SetType.warmup;
  set warmup(bool v) => type = v ? SetType.warmup : SetType.normal;
  double get volume => done && !warmup ? weight * reps : 0;

  /// A set of a timed exercise stored as reps (before hold times existed): shown as reps.
  bool get legacyReps => sec <= 0 && reps > 0;

  factory GymSet.fromMap(Map m) => GymSet(
    weight: _d(m['w']),
    reps: _i(m['r']),
    done: _b(m['d']),
    type:
        m['t'] != null
            ? SetType.values.firstWhere((e) => e.name == m['t'], orElse: () => SetType.normal)
            : (_b(m['wu']) ? SetType.warmup : SetType.normal),
    rpe: _dn(m['rpe']),
    target: _in(m['tg']),
    amrap: m['am'] == true,
    sec: _i(m['s']),
    targetSec: _in(m['ts']),
  );
  Map<String, dynamic> toMap() => {
    'w': weight,
    'r': reps,
    'd': done,
    if (type != SetType.normal) 't': type.name,
    if (rpe != null) 'rpe': rpe,
    if (target != null) 'tg': target,
    if (amrap) 'am': true,
    if (sec > 0) 's': sec,
    if (targetSec != null) 'ts': targetSec,
  };
  GymSet copy() =>
      GymSet(weight: weight, reps: reps, done: done, type: type, rpe: rpe, target: target, amrap: amrap, sec: sec, targetSec: targetSec);
}

class GymExercise {
  String exId;
  String name;
  final List<GymSet> sets;
  int restSec;
  String note;

  /// Exercises sharing the same group letter form a superset / circuit.
  String? group;

  /// Target rep range used for double-progression suggestions.
  int? repMin;
  int? repMax;

  /// Bodyweight mode: the set weight is *added* load (negative = assistance) on top of
  /// the body weight. `null` = automatic (pull-ups, dips, push-ups, … are bodyweight).
  bool? bw;

  /// Body load per rep (kg) at the time of the session – body weight × the share of it
  /// that is lifted (e.g. ~100 % pull-ups, ~65 % push-ups). Used for volume and e1RM of
  /// bodyweight exercises; 0 = progressed by reps only.
  double bodyKg;

  /// Optional effort rating after the last work set (null = not given).
  Effort? effort;

  /// Work-set weight the app prescribed when the workout was started (null = none). A
  /// lighter load than last time only counts as a performance drop when the user chose
  /// it, not when the app prescribed it.
  double? rxKg;

  /// Plan phase that lightened this exercise ('recovery' = deload week, 'taper'), set by
  /// LoadPrescriber.apply. Such sessions are skipped by the progression (a deload is
  /// temporary; the next loading week resumes at the last loading level).
  String? phase;

  /// Taken over from the plan ("Als erledigt eintragen", lib/services/plan_fill.dart): the sets
  /// are the prescribed weights at the target reps, not a measured lift – no records / e1RM,
  /// and only a hold anchor for the load progression. Cleared per exercise when the athlete
  /// corrects its sets on the edit page. See [Session.exerciseFromPlan].
  bool fromPlan;

  /// Measured in hold time instead of reps (plank, wall sit, dead hang, …): the user's choice,
  /// `null` = automatic ([isTimedExercise] from the exercise id / name). See [isTimed].
  bool? timed;

  /// Hold-time range in seconds of a timed exercise (the progression window, like
  /// [repMin] / [repMax] for reps); null = the exercise's default ([defaultHoldRange]).
  int? holdMin;
  int? holdMax;

  GymExercise({
    required this.exId,
    required this.name,
    List<GymSet>? sets,
    this.restSec = 90,
    this.note = '',
    this.group,
    this.repMin,
    this.repMax,
    this.bw,
    this.bodyKg = 0,
    this.effort,
    this.rxKg,
    this.phase,
    this.fromPlan = false,
    this.timed,
    this.holdMin,
    this.holdMax,
  }) : sets = sets ?? [GymSet(), GymSet(), GymSet()];

  List<GymSet> get workSets => sets.where((s) => !s.warmup).toList();

  /// Held for time (seconds per set) instead of counted in reps – see [timed].
  bool get isTimed => timed ?? isTimedExercise(exId, name);

  /// Hold-time range (s) of a timed exercise: its own, else the exercise's default.
  (int, int) get holdRange {
    final lo = holdMin, hi = holdMax;
    if (lo != null && lo > 0 && hi != null && hi >= lo) return (lo, hi);
    return defaultHoldRange(name);
  }

  /// Share of the body weight the exercise moves per rep when done with body weight
  /// ([bodyShareOf]; 0 for loaded and timed exercises).
  double get bodyShare => bodyShareOf(exId, name);

  /// Body load per rep (kg) for volume: in bodyweight mode the body load stored when the
  /// workout started ([bodyKg]); a bodyweight exercise logged without it (older sessions, mode
  /// automatic) gets [bodyWeight] × [bodyShare] – derived, so older history counts the body
  /// like new workouts. 0 for loaded exercises, timed holds and when switched off.
  double bodyLoadAt(double? bodyWeight) {
    if (bw == false || isTimed) return 0;
    if (bw == true && bodyKg > 0) return bodyKg;
    final share = bodyShare;
    if (share <= 0 || bodyWeight == null || bodyWeight <= 0) return 0;
    return (bodyWeight * share * 10).roundToDouble() / 10;
  }

  /// Load per rep of set [s] for volume: added weight + body load ([bodyLoadAt]); assistance
  /// (negative weight) is subtracted. Sets from before bodyweight mode existed (mode automatic,
  /// no body load stored) that carry roughly the body weight were logged as the total load and
  /// count as such; a positive weight logged that way on an assisted machine is the assistance.
  double loadAt(GymSet s, double? bodyWeight) {
    final body = bodyLoadAt(bodyWeight);
    if (body <= 0) return s.weight;
    if (bw == null && bodyKg <= 0) {
      if (s.weight > 0 && name.toLowerCase().contains('assisted')) return body - s.weight;
      if (s.weight >= body * 0.5) return s.weight;
    }
    return s.weight + body;
  }

  /// Volume load (kg × reps of the done work sets) incl. the body load of bodyweight exercises
  /// ([loadAt] at the session's [bodyWeight]). Timed holds count 0 – kg × seconds is no volume;
  /// their measure is the hold time ([holdSec]).
  double volumeAt(double? bodyWeight) {
    if (isTimed) return 0;
    var v = 0.0;
    for (final s in sets) {
      if (!s.done || s.warmup) continue;
      final load = loadAt(s, bodyWeight);
      if (load > 0) v += load * s.reps;
    }
    return v;
  }

  /// Whether [volumeAt] contains body weight (a bodyweight exercise with done reps).
  bool countsBodyAt(double? bodyWeight) => !isTimed && bodyLoadAt(bodyWeight) > 0 && sets.any((s) => s.done && !s.warmup && s.reps > 0);

  /// Load per rep of a set: the weight, plus the body load in bodyweight mode.
  double loadOf(GymSet s) => bw == true ? s.weight + bodyKg : s.weight;

  /// Volume with the stored body load only (running workout, programs) – see [volumeAt].
  double get volume => volumeAt(null);
  int get doneSets => sets.where((s) => s.done && !s.warmup).length;
  bool get allDone => sets.isNotEmpty && sets.every((s) => s.done);

  /// Time under tension of a timed exercise: the held seconds of its done work sets.
  int get holdSec => isTimed ? sets.where((s) => s.done && !s.warmup).fold(0, (a, s) => a + s.sec) : 0;

  /// Longest single hold (s) of a timed exercise's done work sets – its record.
  int get longestHold => isTimed ? sets.where((s) => s.done && !s.warmup).fold(0, (a, s) => a > s.sec ? a : s.sec) : 0;

  /// Best estimated 1RM of the done work sets (none for timed holds).
  double get bestE1rm =>
      isTimed
          ? 0
          : sets.where((s) => s.done && !s.warmup).fold(0.0, (a, s) {
            final v = e1rm(loadOf(s), s.reps);
            return a > v ? a : v;
          });
  double get maxWeight => sets.where((s) => s.done && !s.warmup).fold(0.0, (a, s) => a > s.weight ? a : s.weight);

  factory GymExercise.fromMap(Map m) => GymExercise(
    exId: _s(m['exId']),
    name: _s(m['name']),
    sets: _maps(m['sets']).map(GymSet.fromMap).toList(),
    restSec: _i(m['rest'], 90),
    note: _s(m['note']),
    group: _sn(m['group']),
    repMin: _in(m['repMin']),
    repMax: _in(m['repMax']),
    bw: m['bw'] is bool ? m['bw'] : null,
    bodyKg: _d(m['bodyKg']),
    effort: Effort.fromName(m['effort']),
    rxKg: _dn(m['rx']),
    phase: m['ph'] is String ? m['ph'] : null,
    fromPlan: m['fp'] == true,
    timed: m['tm'] is bool ? m['tm'] : null,
    holdMin: _in(m['hMin']),
    holdMax: _in(m['hMax']),
  );
  Map<String, dynamic> toMap() => {
    'exId': exId,
    'name': name,
    'sets': sets.map((s) => s.toMap()).toList(),
    'rest': restSec,
    if (note.isNotEmpty) 'note': note,
    if (group != null) 'group': group,
    if (repMin != null) 'repMin': repMin,
    if (repMax != null) 'repMax': repMax,
    if (bw != null) 'bw': bw,
    if (bodyKg > 0) 'bodyKg': bodyKg,
    if (effort != null) 'effort': effort!.name,
    if (rxKg != null) 'rx': rxKg,
    if (phase != null) 'ph': phase,
    if (fromPlan) 'fp': true,
    if (timed != null) 'tm': timed,
    if (holdMin != null) 'hMin': holdMin,
    if (holdMax != null) 'hMax': holdMax,
  };
  GymExercise copy({bool resetDone = false}) => GymExercise(
    exId: exId,
    name: name,
    sets: sets.map((s) => s.copy()..done = resetDone ? false : s.done).toList(),
    restSec: restSec,
    note: note,
    group: group,
    repMin: repMin,
    repMax: repMax,
    bw: bw,
    bodyKg: bodyKg,
    effort: resetDone ? null : effort,
    rxKg: rxKg,
    phase: phase,
    fromPlan: resetDone ? false : fromPlan,
    timed: timed,
    holdMin: holdMin,
    holdMax: holdMax,
  );
}

// ───────────────────────────── Session (completed activity) ─────────────────────────────

class Session {
  final String id;
  final Sport sport;
  final String title;
  final DateTime start;
  final int durationSec;
  final int? rpe; // 1..10 perceived exertion
  final String notes;
  final List<GymExercise> exercises;
  final double distanceM;
  final double elevationM;
  final int? avgHr;
  final List<List<double>> route; // [[lat, lng], …] (downsampled)
  final List<int> splits; // seconds per km
  final int laps;
  final int poolLengthM;
  final String stroke;
  final bool indoor;
  final String? templateId;
  final String? planId;
  final String? source; // e.g. "Samsung Health" when imported
  final String? externalId; // Health Connect record id (dedupe)
  final int? calories;
  final int? maxHr;

  /// Average power in watts (bike with a power meter), if known.
  final int? avgPower;

  /// Logged as done without recording: exercises / sets / distance were taken over from the
  /// planned workout ("aus Plan übernommen", lib/services/plan_fill.dart). Counts for volume,
  /// set and muscle statistics and the plan, but is no measurement – no records (PRs, best
  /// efforts) and no pace / power signal for the plan adaptation. Cleared when the athlete
  /// corrects the performance data (edit page).
  final bool fromPlan;

  /// Gym: work sets the workout had when it was finished / taken over (incl. exercises
  /// without a done set, which are not stored) – the plan compliance compares the done sets
  /// against it. Null for older sessions and free workouts.
  final int? plannedSets;

  /// XP the session earned before it was first corrected ([xpForSession] caps at it): a correction
  /// can lower the XP (a forgotten stop), never raise it – XP can't be farmed by editing the
  /// duration or the effort afterwards. Null for sessions never edited.
  final int? xpCap;

  /// Body weight (kg) at the time of the workout – the body load of bodyweight exercises in
  /// the volume ([GymExercise.volumeAt]). Stored with new gym sessions; older ones get the body
  /// weight of that day filled in for display by the session list ([withBodyWeight]).
  final double? bodyWeightKg;

  Session({
    required this.id,
    required this.sport,
    required this.title,
    required this.start,
    required this.durationSec,
    this.rpe,
    this.notes = '',
    this.exercises = const [],
    this.distanceM = 0,
    this.elevationM = 0,
    this.avgHr,
    this.route = const [],
    this.splits = const [],
    this.laps = 0,
    this.poolLengthM = 25,
    this.stroke = 'freestyle',
    this.indoor = false,
    this.templateId,
    this.planId,
    this.source,
    this.externalId,
    this.calories,
    this.maxHr,
    this.avgPower,
    this.fromPlan = false,
    this.plannedSets,
    this.xpCap,
    this.bodyWeightKg,
  });

  /// Real measurement (recorded, imported or entered by hand) – not taken over from the plan.
  bool get measured => !fromPlan;

  /// Whether exercise [e] of this session carries the plan's prescribed sets rather than a
  /// measured lift: the whole session was taken over from the plan, or the exercise itself was
  /// (and the athlete has not corrected it). Records, e1RM, strength goals and the coach skip
  /// it; the load progression only holds on it.
  bool exerciseFromPlan(GymExercise e) => fromPlan || e.fromPlan;

  /// Volume load (kg) incl. the body load of bodyweight exercises at [bodyWeightKg]; timed holds
  /// are not part of it ([holdSec]).
  double get volume => exercises.fold(0, (a, e) => a + e.volumeAt(bodyWeightKg));

  /// Whether [volume] contains body weight (bodyweight exercises) – "incl. body weight".
  bool get volumeCountsBody => exercises.any((e) => e.countsBodyAt(bodyWeightKg));

  /// Time under tension of the timed holds (planks, wall sits, …), seconds.
  int get holdSec => exercises.fold(0, (a, e) => a + e.holdSec);

  /// This session with [kg] as its body weight when it has none stored (older gym sessions:
  /// derived for display, see sessionListProvider); otherwise itself.
  Session withBodyWeight(double? kg) {
    if (bodyWeightKg != null || kg == null || kg <= 0 || exercises.isEmpty) return this;
    return Session.fromMap(id, {...toMap(), 'bwKg': kg});
  }

  int get setsDone => exercises.fold(0, (a, e) => a + e.doneSets);
  int get minutes => (durationSec / 60).round();

  /// Training load = minutes × RPE (session-RPE method, Foster 2001).
  double get load => minutes * (rpe ?? 6).toDouble();

  factory Session.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) => Session.fromMap(d.id, d.data() ?? const {});

  /// Null for a document that is not a session (no start / sport, e.g. a stray partial write).
  static Session? tryFromMap(String id, Map<String, dynamic> m) => m['start'] == null || m['sport'] == null ? null : Session.fromMap(id, m);

  factory Session.fromMap(String id, Map<String, dynamic> m) {
    return Session(
      id: id,
      sport: SportX.parse(_sn(m['sport'])),
      title: _s(m['title']),
      start: _date(m['start']),
      durationSec: _i(m['durationSec']),
      rpe: _in(m['rpe']),
      notes: _s(m['notes']),
      exercises: _maps(m['exercises']).map(GymExercise.fromMap).toList(),
      distanceM: _d(m['distanceM']),
      elevationM: _d(m['elevationM']),
      avgHr: _in(m['avgHr']),
      route: [
        for (final p in _maps(m['route']))
          if ((_dn(p['a']), _dn(p['o'])) case (final a?, final o?)) [a, o],
      ],
      splits: _ints(m['splits']),
      laps: _i(m['laps']),
      poolLengthM: _i(m['poolLengthM'], 25),
      stroke: _s(m['stroke'], 'freestyle'),
      indoor: _b(m['indoor']),
      templateId: _sn(m['templateId']),
      planId: _sn(m['planId']),
      source: _sn(m['source']),
      externalId: _sn(m['externalId']),
      calories: _in(m['calories']),
      maxHr: _in(m['maxHr']),
      avgPower: _in(m['avgPower']),
      fromPlan: _b(m['fromPlan']),
      plannedSets: _in(m['plannedSets']),
      xpCap: _in(m['xpCap']),
      bodyWeightKg: _dn(m['bwKg']),
    );
  }

  Map<String, dynamic> toMap() => {
    'sport': sport.name,
    'title': title,
    'start': Timestamp.fromDate(start),
    'durationSec': durationSec,
    'rpe': rpe,
    'notes': notes,
    if (exercises.isNotEmpty) 'exercises': exercises.map((e) => e.toMap()).toList(),
    if (sport == Sport.gym) 'volume': volume,
    'distanceM': distanceM,
    'elevationM': elevationM,
    'avgHr': avgHr,
    // Firestore does not support nested arrays → store as maps.
    if (route.isNotEmpty) 'route': route.map((p) => {'a': p[0], 'o': p[1]}).toList(),
    if (splits.isNotEmpty) 'splits': splits,
    'laps': laps,
    'poolLengthM': poolLengthM,
    'stroke': stroke,
    'indoor': indoor,
    'templateId': templateId,
    'planId': planId,
    if (source != null) 'source': source,
    if (externalId != null) 'externalId': externalId,
    if (calories != null) 'calories': calories,
    if (maxHr != null) 'maxHr': maxHr,
    if (avgPower != null) 'avgPower': avgPower,
    if (fromPlan) 'fromPlan': true,
    if (plannedSets != null) 'plannedSets': plannedSets,
    if (xpCap != null) 'xpCap': xpCap,
    if (bodyWeightKg != null) 'bwKg': bodyWeightKg,
  };
}

// ───────────────────────────── Template (program) ─────────────────────────────

class WorkoutTemplate {
  final String id;
  final String name;
  final Sport sport;
  final String folder;
  final List<GymExercise> exercises;
  final double? targetKm;
  final int? targetMin;
  final String intensity; // easy | moderate | tempo | intervals | long | technique
  final String description;
  final List<WorkoutStep> steps; // structured endurance workout (phases)
  final String? key; // stable id of a built-in program (e.g. 'ul_upper_a'), used by the plan generator
  final int order; // position inside its folder

  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.sport,
    this.folder = '',
    this.exercises = const [],
    this.targetKm,
    this.targetMin,
    this.intensity = 'easy',
    this.description = '',
    this.steps = const [],
    this.key,
    this.order = 0,
  });

  /// Null for a document that is not a program (no sport / name, e.g. a stray partial write).
  static WorkoutTemplate? tryFromMap(String id, Map<String, dynamic> m) =>
      m['sport'] == null || m['name'] == null ? null : WorkoutTemplate.fromMap(id, m);

  factory WorkoutTemplate.fromMap(String id, Map<String, dynamic> m) => WorkoutTemplate(
    id: id,
    name: _s(m['name']),
    sport: SportX.parse(_sn(m['sport'])),
    folder: _s(m['folder']),
    exercises: _maps(m['exercises']).map(GymExercise.fromMap).toList(),
    targetKm: _dn(m['targetKm']),
    targetMin: _in(m['targetMin']),
    intensity: _s(m['intensity'], 'easy'),
    description: _s(m['description']),
    steps: _maps(m['steps']).map(WorkoutStep.fromMap).toList(),
    key: _sn(m['key']),
    order: _i(m['order']),
  );

  WorkoutTemplate copyWith({String? name, String? folder, int? order, List<GymExercise>? exercises, List<WorkoutStep>? steps}) =>
      WorkoutTemplate(
        id: id,
        name: name ?? this.name,
        sport: sport,
        folder: folder ?? this.folder,
        exercises: exercises ?? this.exercises,
        targetKm: targetKm,
        targetMin: targetMin,
        intensity: intensity,
        description: description,
        steps: steps ?? this.steps,
        key: key,
        order: order ?? this.order,
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'sport': sport.name,
    'folder': folder,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'targetKm': targetKm,
    'targetMin': targetMin,
    'intensity': intensity,
    'description': description,
    if (steps.isNotEmpty) 'steps': steps.map((e) => e.toMap()).toList(),
    if (key != null) 'key': key,
    'order': order,
  };

  int get estimatedMinutes {
    if (targetMin != null) return targetMin!;
    if (sport != Sport.gym) {
      if (steps.isEmpty) return 45;
      // Typical pace per km when a step is distance-based: swim ~2:00/100 m incl. walls,
      // ride ~30 km/h, run ~6:00/km.
      final perKm = switch (sport) {
        Sport.swim => 1250,
        Sport.ride => 120,
        _ => 360,
      };
      final sec = steps.fold<int>(0, (a, s) => a + (s.durationSec ?? ((s.distanceM ?? 0) / 1000 * perKm).round()));
      return (sec / 60).round().clamp(10, 400);
    }
    return estimateGymMinutes(exercises);
  }
}

/// Session length estimate: ~40 s per set plus its rest (supersets: a short transition
/// between members, the full rest once per round), plus ~6 min general warm-up.
int estimateGymMinutes(List<GymExercise> exercises) {
  var sec = 360.0;
  for (var i = 0; i < exercises.length; i++) {
    final e = exercises[i];
    final next = i + 1 < exercises.length ? exercises[i + 1] : null;
    final inSupersetBeforeLast = e.group != null && next?.group == e.group;
    final timed = e.isTimed;
    for (final st in e.sets) {
      // A hold takes its time plus ~15 s to get into position; a rep set ~40 s.
      sec += (timed && st.sec > 0 ? st.sec + 15 : 40) + (inSupersetBeforeLast ? 20 : (st.warmup ? 60 : e.restSec));
    }
  }
  return (sec / 60).round().clamp(10, 180);
}

// ───────────────────────────── Calendar plan ─────────────────────────────

class PlannedWorkout {
  final String id;
  final DateTime date;
  final Sport sport;
  final String title;
  final String description;
  final int durationMin;
  final double? distanceKm;
  final String intensity;
  final String? templateId;
  final String status; // planned | done | skipped
  final String? sessionId;
  final List<WorkoutStep> steps; // structured workout (endurance)
  final String? phase; // base | build | peak | taper | recovery
  final bool isKey;

  /// Gym: exercises adjusted for this one workout (empty = use the program's exercises).
  final List<GymExercise> exercises;

  /// Gym: how the plan adapts the program's exercises for this day without copying them
  /// ([gymModRegress], [gymModNoLegs] – lib/services/plan_exercises.dart), so the workout
  /// always shows the program as it is now (sets, reps, exercises) – also after the program
  /// was edited. Ignored when [exercises] is set.
  final List<String> gymMods;

  /// Small automatic adjustment after a completed session (original values for undo).
  final AutoAdjustment? auto;

  PlannedWorkout({
    required this.id,
    required this.date,
    required this.sport,
    required this.title,
    this.description = '',
    this.durationMin = 45,
    this.distanceKm,
    this.intensity = 'easy',
    this.templateId,
    this.status = 'planned',
    this.sessionId,
    this.steps = const [],
    this.phase,
    this.isKey = false,
    this.exercises = const [],
    this.gymMods = const [],
    this.auto,
  });

  bool get isDone => status == 'done';
  bool get isMissed => isMissedOn(DateTime.now());

  /// Skipped, or still planned on a day before [today] (pass the ticking `todayProvider` value
  /// in widgets, so the state changes at midnight without a rebuild from elsewhere).
  bool isMissedOn(DateTime today) => status == 'skipped' || (status == 'planned' && dayOnly(date).isBefore(dayOnly(today)));

  /// Null for a document without a valid date or sport (corrupt / stray partial write) – it is
  /// skipped instead of showing up "today".
  static PlannedWorkout? tryFromMap(String id, Map<String, dynamic> m) {
    final d = m['date'];
    if (d is! String || DateTime.tryParse(d) == null || m['sport'] == null) return null;
    return PlannedWorkout.fromMap(id, m);
  }

  factory PlannedWorkout.fromMap(String id, Map<String, dynamic> m) => PlannedWorkout(
    id: id,
    date: parseDayKey(m['date'] ?? dayKey(DateTime.now())),
    sport: SportX.parse(_sn(m['sport'])),
    title: _s(m['title']),
    description: _s(m['description']),
    durationMin: _i(m['durationMin'], 45),
    distanceKm: _dn(m['distanceKm']),
    intensity: _s(m['intensity'], 'easy'),
    templateId: _sn(m['templateId']),
    status: _s(m['status'], 'planned'),
    sessionId: _sn(m['sessionId']),
    steps: _maps(m['steps']).map(WorkoutStep.fromMap).toList(),
    phase: _sn(m['phase']),
    isKey: _b(m['isKey']),
    exercises: _maps(m['exercises']).map(GymExercise.fromMap).toList(),
    gymMods: _strings(m['gymMods']),
    auto: m['auto'] is Map ? AutoAdjustment.fromMap(m['auto'] as Map) : null,
  );

  Map<String, dynamic> toMap() => {
    'date': dayKey(date),
    'sport': sport.name,
    'title': title,
    'description': description,
    'durationMin': durationMin,
    'distanceKm': distanceKm,
    'intensity': intensity,
    'templateId': templateId,
    'status': status,
    'sessionId': sessionId,
    if (steps.isNotEmpty) 'steps': steps.map((e) => e.toMap()).toList(),
    if (phase != null) 'phase': phase,
    if (isKey) 'isKey': true,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    if (gymMods.isNotEmpty) 'gymMods': gymMods,
    if (auto != null) 'auto': auto!.toMap(),
  };
}

/// Record of a small automatic plan adjustment made after a completed session
/// (lib/services/cardio_progression.dart): why, triggered by which session, and the
/// workout's original volume so the athlete can undo it.
class AutoAdjustment {
  const AutoAdjustment({
    required this.sessionId,
    required this.reason,
    required this.at,
    required this.durationMin,
    this.distanceKm,
    this.steps = const [],
  });

  /// Session whose evaluation triggered the change (idempotency: once per session).
  final String sessionId;

  /// longCutShort | longHard | easyHard | easyTooFast | qualityHard | qualityEasy
  final String reason;
  final DateTime at;

  /// Original values (before any automatic adjustment).
  final int durationMin;
  final double? distanceKm;
  final List<WorkoutStep> steps;

  factory AutoAdjustment.fromMap(Map m) => AutoAdjustment(
    sessionId: _s(m['sessionId']),
    reason: _s(m['reason']),
    at: _date(m['at']),
    durationMin: _i(m['durationMin'], 45),
    distanceKm: _dn(m['distanceKm']),
    steps: _maps(m['steps']).map(WorkoutStep.fromMap).toList(),
  );

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'reason': reason,
    'at': Timestamp.fromDate(at),
    'durationMin': durationMin,
    'distanceKm': distanceKm,
    if (steps.isNotEmpty) 'steps': steps.map((e) => e.toMap()).toList(),
  };
}

/// One step of a structured endurance workout (repeats are expanded).
class WorkoutStep {
  final String kind; // warmup | work | recovery | cooldown | steady
  final int? durationSec;
  final double? distanceM;
  final String zone; // E, M, T, I, R, walk (run) · Z1..Z7, SS (bike) · CSS, EN, TE, SP, DR (swim)
  final int? paceMin; // faster bound: sec/km (run) or sec/100 m (swim)
  final int? paceMax; // slower bound
  final int? powerMin; // watts (bike)
  final int? powerMax;
  final int? hrMin;
  final int? hrMax;
  final String note;

  const WorkoutStep({
    required this.kind,
    this.durationSec,
    this.distanceM,
    this.zone = 'E',
    this.paceMin,
    this.paceMax,
    this.powerMin,
    this.powerMax,
    this.hrMin,
    this.hrMax,
    this.note = '',
  });

  bool get isWork => kind == 'work';

  factory WorkoutStep.fromMap(Map m) => WorkoutStep(
    kind: _s(m['k'], 'steady'),
    durationSec: _in(m['t']),
    distanceM: _dn(m['d']),
    zone: _s(m['z'], 'E'),
    paceMin: _in(m['p0']),
    paceMax: _in(m['p1']),
    powerMin: _in(m['w0']),
    powerMax: _in(m['w1']),
    hrMin: _in(m['h0']),
    hrMax: _in(m['h1']),
    note: _s(m['n']),
  );

  Map<String, dynamic> toMap() => {
    'k': kind,
    if (durationSec != null) 't': durationSec,
    if (distanceM != null) 'd': distanceM,
    'z': zone,
    if (paceMin != null) 'p0': paceMin,
    if (paceMax != null) 'p1': paceMax,
    if (powerMin != null) 'w0': powerMin,
    if (powerMax != null) 'w1': powerMax,
    if (hrMin != null) 'h0': hrMin,
    if (hrMax != null) 'h1': hrMax,
    if (note.isNotEmpty) 'n': note,
  };
}

// ───────────────────────────── Body & goals ─────────────────────────────

/// Body weight (kg) on [day]: the latest body entry on or before it, else the earliest one after
/// it, else [fallback] (the profile weight).
double bodyWeightOn(DateTime day, List<BodyEntry> entries, double fallback) {
  BodyEntry? before, after;
  for (final b in entries) {
    if (b.weightKg <= 0) continue;
    if (!b.date.isAfter(day)) {
      if (before == null || b.date.isAfter(before.date)) before = b;
    } else if (after == null || b.date.isBefore(after.date)) {
      after = b;
    }
  }
  return (before ?? after)?.weightKg ?? fallback;
}

class BodyEntry {
  final String id;
  final DateTime date;
  final double weightKg;
  final double? fatPct;
  final double? musclePct;

  BodyEntry({required this.id, required this.date, required this.weightKg, this.fatPct, this.musclePct});

  factory BodyEntry.fromMap(String id, Map<String, dynamic> m) =>
      BodyEntry(id: id, date: _date(m['date']), weightKg: _d(m['weightKg']), fatPct: _dn(m['fatPct']), musclePct: _dn(m['musclePct']));
  Map<String, dynamic> toMap() => {'date': Timestamp.fromDate(date), 'weightKg': weightKg, 'fatPct': fatPct, 'musclePct': musclePct};
}

enum GoalType { weight, distance, frequency, strength, event }

class Goal {
  final String id;
  final GoalType type;
  final String title;
  final Sport? sport;
  final double target;
  final double? startValue;
  final DateTime created;
  final DateTime? deadline;
  final String? exId; // strength goals
  final String? exName;
  final double? eventKm;

  /// Event goals: the race distance of the catalogue (eventDistances key) – set when the
  /// distance was picked from the presets, so a triathlon never turns into a 51,5 km run.
  final String? eventKey;

  Goal({
    required this.id,
    required this.type,
    required this.title,
    this.sport,
    required this.target,
    this.startValue,
    required this.created,
    this.deadline,
    this.exId,
    this.exName,
    this.eventKm,
    this.eventKey,
  });

  factory Goal.fromMap(String id, Map<String, dynamic> m) => Goal(
    id: id,
    type: GoalType.values.firstWhere((e) => e.name == m['type'], orElse: () => GoalType.frequency),
    title: _s(m['title']),
    sport: m['sport'] == null ? null : SportX.parse(_sn(m['sport'])),
    target: _d(m['target']),
    startValue: _dn(m['startValue']),
    created: _date(m['created']),
    deadline: m['deadline'] == null ? null : _date(m['deadline']),
    exId: _sn(m['exId']),
    exName: _sn(m['exName']),
    eventKm: _dn(m['eventKm']),
    eventKey: _sn(m['eventKey']),
  );

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'title': title,
    'sport': sport?.name,
    'target': target,
    'startValue': startValue,
    'created': Timestamp.fromDate(created),
    'deadline': deadline == null ? null : Timestamp.fromDate(deadline!),
    'exId': exId,
    'exName': exName,
    'eventKm': eventKm,
    'eventKey': eventKey,
  };
}
