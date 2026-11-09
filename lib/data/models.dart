import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/format.dart';
import '../core/sport.dart';

DateTime _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.now();
}

double _d(dynamic v, [double def = 0]) => v is num ? v.toDouble() : def;
double? _dn(dynamic v) => v is num ? v.toDouble() : null;
int _i(dynamic v, [int def = 0]) => v is num ? v.toInt() : def;
int? _in(dynamic v) => v is num ? v.toInt() : null;

// ───────────────────────────── Profile ─────────────────────────────

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
    this.trainingDays = const [1, 3, 5],
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
  int get estimatedMaxHr => maxHr ?? (age == null ? 190 : (208 - 0.7 * age!).round());
  Units get units => Units(imperial);

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    name: m['name'] ?? '',
    birthYear: m['birthYear'],
    gender: m['gender'] ?? 'd',
    heightCm: _d(m['heightCm'], 175),
    weightKg: _d(m['weightKg'], 75),
    fatPct: _dn(m['fatPct']),
    musclePct: _dn(m['musclePct']),
    level: m['level'] ?? 'beginner',
    experience: ((m['experience'] as List?) ?? []).map((e) => SportX.parse(e)).toSet(),
    focus: TrainingFocusX.parse(m['focus']),
    goals: List<String>.from(m['goals'] ?? const []),
    trainingDays: List<int>.from(m['trainingDays'] ?? const [1, 3, 5]),
    longDay: m['longDay'],
    imperial: m['imperial'] ?? false,
    maxHr: m['maxHr'],
    onboarded: m['onboarded'] ?? false,
    athlete: AthleteData.fromMap((m['athlete'] as Map?)?.cast<String, dynamic>() ?? const {}),
    folderOrder: List<String>.from(m['folderOrder'] ?? const []),
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
  // Event
  final String? eventDistance; // 5k | 10k | hm | m | sprint | olympic | 70.3
  final DateTime? eventDate;
  final int? targetTimeSec;

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
    this.eventDistance,
    this.eventDate,
    this.targetTimeSec,
  });

  bool get advanced => setupMode == 'advanced';

  /// Minutes available on [weekday] (per-day override or the global maximum).
  int minutesOn(int weekday) => dayMinutes[weekday] ?? sessionMinutes;

  factory AthleteData.fromMap(Map<String, dynamic> m) => AthleteData(
    setupMode: m['setupMode'] ?? 'simple',
    difficulty: m['difficulty'] ?? 'balanced',
    planWeeks: _i(m['planWeeks'], 8),
    sessionMinutes: _i(m['sessionMinutes'], 60),
    dayMinutes: {for (final e in ((m['dayMinutes'] as Map?) ?? {}).entries) int.parse('${e.key}'): (e.value as num).toInt()},
    sessionsPerDay: _i(m['sessionsPerDay'], 1),
    dayPlan: {
      for (final e in ((m['dayPlan'] as Map?) ?? {}).entries)
        int.parse('${e.key}'): ((e.value as List?) ?? []).map((x) => SportX.parse(x)).toList(),
    },
    preferredTime: m['preferredTime'] ?? 'evening',
    restHr: m['restHr'],
    limitations: List<String>.from(m['limitations'] ?? const []),
    raceTimes: {for (final e in ((m['raceTimes'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toInt()},
    runWeeklyKm: _dn(m['runWeeklyKm']),
    longestRunKm: _dn(m['longestRunKm']),
    canRun30: m['canRun30'] ?? true,
    ftp: m['ftp'],
    bikeWeeklyHours: _dn(m['bikeWeeklyHours']),
    longestRideKm: _dn(m['longestRideKm']),
    hasPowerMeter: m['hasPowerMeter'] ?? false,
    indoorTrainer: m['indoorTrainer'] ?? false,
    swim400Sec: m['swim400Sec'],
    swim200Sec: m['swim200Sec'],
    swimWeeklyKm: _dn(m['swimWeeklyKm']),
    canSwim400: m['canSwim400'] ?? true,
    poolLength: _i(m['poolLength'], 25),
    equipment: m['equipment'] ?? 'gym',
    gymGoal: m['gymGoal'] ?? 'general',
    gymSplit: m['gymSplit'] ?? 'auto',
    oneRm: {for (final e in ((m['oneRm'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toDouble()},
    eventDistance: m['eventDistance'],
    eventDate: m['eventDate'] == null ? null : _date(m['eventDate']),
    targetTimeSec: m['targetTimeSec'],
  );

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
    'eventDistance': eventDistance,
    'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
    'targetTimeSec': targetTimeSec,
  };

  /// Copy with some fields replaced (keys as in [toMap]); `null` values clear a field.
  AthleteData merge(Map<String, dynamic> changes) {
    final m = toMap();
    // eventDate is stored as Timestamp; keep DateTime inputs working.
    final c = {...changes};
    if (c['eventDate'] is DateTime) c['eventDate'] = Timestamp.fromDate(c['eventDate']);
    if (c['dayPlan'] is Map<int, List<Sport>>) {
      c['dayPlan'] = {for (final e in (c['dayPlan'] as Map<int, List<Sport>>).entries) '${e.key}': e.value.map((s) => s.name).toList()};
    }
    if (c['dayMinutes'] is Map<int, int>) {
      c['dayMinutes'] = {for (final e in (c['dayMinutes'] as Map<int, int>).entries) '${e.key}': e.value};
    }
    return AthleteData.fromMap({...m, ...c});
  }
}

// ───────────────────────────── Gym ─────────────────────────────

/// Set type: normal, warm-up, drop set, to failure.
enum SetType { normal, warmup, drop, failure }

class GymSet {
  double weight;
  int reps;
  bool done;
  SetType type;
  double? rpe; // 6..10 (RIR = 10 - RPE)

  GymSet({this.weight = 0, this.reps = 0, this.done = false, this.type = SetType.normal, this.rpe});

  bool get warmup => type == SetType.warmup;
  set warmup(bool v) => type = v ? SetType.warmup : SetType.normal;
  double get volume => done && !warmup ? weight * reps : 0;

  factory GymSet.fromMap(Map m) => GymSet(
    weight: _d(m['w']),
    reps: _i(m['r']),
    done: m['d'] ?? false,
    type:
        m['t'] != null
            ? SetType.values.firstWhere((e) => e.name == m['t'], orElse: () => SetType.normal)
            : ((m['wu'] ?? false) ? SetType.warmup : SetType.normal),
    rpe: _dn(m['rpe']),
  );
  Map<String, dynamic> toMap() => {
    'w': weight,
    'r': reps,
    'd': done,
    if (type != SetType.normal) 't': type.name,
    if (rpe != null) 'rpe': rpe,
  };
  GymSet copy() => GymSet(weight: weight, reps: reps, done: done, type: type, rpe: rpe);
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
  }) : sets = sets ?? [GymSet(), GymSet(), GymSet()];

  List<GymSet> get workSets => sets.where((s) => !s.warmup).toList();

  /// Load per rep of a set: the weight, plus the body load in bodyweight mode.
  double loadOf(GymSet s) => bw == true ? s.weight + bodyKg : s.weight;

  double get volume => sets.fold(0, (a, s) => a + (s.done && !s.warmup ? (loadOf(s) > 0 ? loadOf(s) * s.reps : 0) : 0));
  int get doneSets => sets.where((s) => s.done && !s.warmup).length;
  bool get allDone => sets.isNotEmpty && sets.every((s) => s.done);
  double get bestE1rm => sets.where((s) => s.done && !s.warmup).fold(0.0, (a, s) {
    final v = e1rm(loadOf(s), s.reps);
    return a > v ? a : v;
  });
  double get maxWeight => sets.where((s) => s.done && !s.warmup).fold(0.0, (a, s) => a > s.weight ? a : s.weight);

  factory GymExercise.fromMap(Map m) => GymExercise(
    exId: m['exId'] ?? '',
    name: m['name'] ?? '',
    sets: ((m['sets'] as List?) ?? []).map((e) => GymSet.fromMap(e as Map)).toList(),
    restSec: _i(m['rest'], 90),
    note: m['note'] ?? '',
    group: m['group'],
    repMin: _in(m['repMin']),
    repMax: _in(m['repMax']),
    bw: m['bw'] is bool ? m['bw'] : null,
    bodyKg: _d(m['bodyKg']),
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
  });

  double get volume => exercises.fold(0, (a, e) => a + e.volume);
  int get setsDone => exercises.fold(0, (a, e) => a + e.doneSets);
  int get minutes => (durationSec / 60).round();

  /// Training load = minutes × RPE (session-RPE method, Foster 2001).
  double get load => minutes * (rpe ?? 6).toDouble();

  factory Session.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Session(
      id: d.id,
      sport: SportX.parse(m['sport']),
      title: m['title'] ?? '',
      start: _date(m['start']),
      durationSec: _i(m['durationSec']),
      rpe: m['rpe'],
      notes: m['notes'] ?? '',
      exercises: ((m['exercises'] as List?) ?? []).map((e) => GymExercise.fromMap(e as Map)).toList(),
      distanceM: _d(m['distanceM']),
      elevationM: _d(m['elevationM']),
      avgHr: m['avgHr'],
      route: ((m['route'] as List?) ?? []).map((p) => [(p as Map)['a'] as num, p['o'] as num].map((e) => e.toDouble()).toList()).toList(),
      splits: List<int>.from(m['splits'] ?? const []),
      laps: _i(m['laps']),
      poolLengthM: _i(m['poolLengthM'], 25),
      stroke: m['stroke'] ?? 'freestyle',
      indoor: m['indoor'] ?? false,
      templateId: m['templateId'],
      planId: m['planId'],
      source: m['source'],
      externalId: m['externalId'],
      calories: m['calories'],
      maxHr: m['maxHr'],
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

  factory WorkoutTemplate.fromMap(String id, Map<String, dynamic> m) => WorkoutTemplate(
    id: id,
    name: m['name'] ?? '',
    sport: SportX.parse(m['sport']),
    folder: m['folder'] ?? '',
    exercises: ((m['exercises'] as List?) ?? []).map((e) => GymExercise.fromMap(e as Map)).toList(),
    targetKm: _dn(m['targetKm']),
    targetMin: m['targetMin'],
    intensity: m['intensity'] ?? 'easy',
    description: m['description'] ?? '',
    steps: ((m['steps'] as List?) ?? []).map((e) => WorkoutStep.fromMap(e as Map)).toList(),
    key: m['key'],
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
    for (final st in e.sets) {
      sec += 40 + (inSupersetBeforeLast ? 20 : (st.warmup ? 60 : e.restSec));
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
  });

  bool get isDone => status == 'done';
  bool get isMissed => status == 'skipped' || (status == 'planned' && dayOnly(date).isBefore(dayOnly(DateTime.now())));

  factory PlannedWorkout.fromMap(String id, Map<String, dynamic> m) => PlannedWorkout(
    id: id,
    date: parseDayKey(m['date'] ?? dayKey(DateTime.now())),
    sport: SportX.parse(m['sport']),
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    durationMin: _i(m['durationMin'], 45),
    distanceKm: _dn(m['distanceKm']),
    intensity: m['intensity'] ?? 'easy',
    templateId: m['templateId'],
    status: m['status'] ?? 'planned',
    sessionId: m['sessionId'],
    steps: ((m['steps'] as List?) ?? []).map((e) => WorkoutStep.fromMap(e as Map)).toList(),
    phase: m['phase'],
    isKey: m['isKey'] ?? false,
    exercises: ((m['exercises'] as List?) ?? []).map((e) => GymExercise.fromMap(e as Map)).toList(),
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
    kind: m['k'] ?? 'steady',
    durationSec: m['t'],
    distanceM: _dn(m['d']),
    zone: m['z'] ?? 'E',
    paceMin: m['p0'],
    paceMax: m['p1'],
    powerMin: m['w0'],
    powerMax: m['w1'],
    hrMin: m['h0'],
    hrMax: m['h1'],
    note: m['n'] ?? '',
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
  });

  factory Goal.fromMap(String id, Map<String, dynamic> m) => Goal(
    id: id,
    type: GoalType.values.firstWhere((e) => e.name == m['type'], orElse: () => GoalType.frequency),
    title: m['title'] ?? '',
    sport: m['sport'] == null ? null : SportX.parse(m['sport']),
    target: _d(m['target']),
    startValue: _dn(m['startValue']),
    created: _date(m['created']),
    deadline: m['deadline'] == null ? null : _date(m['deadline']),
    exId: m['exId'],
    exName: m['exName'],
    eventKm: _dn(m['eventKm']),
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
  };
}
