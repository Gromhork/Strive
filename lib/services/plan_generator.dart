import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'zones.dart';

/// Evidence-based, rule-based plan generator (offline). Implements
/// docs/training-science.md:
///
/// * Periodisation base → build → peak → taper, taper 8–21 days with a 41–60 %
///   volume cut and intensity kept (Bosquet 2007, Wang 2023).
/// * Recovery weeks 2:1 / 3:1 / 4:1 by difficulty at 60–75 % volume.
/// * Running: ≥ 75–80 % easy sessions (Seiler; Silva Oliveira 2024), paces from
///   VDOT (Daniels), weekly growth 5/8/10 % (Buist 2008; Nielsen 2014), longest
///   run ≤ +10 % of the 30-day max (Frandsen 2025), long run ≤ 30 % of weekly km
///   and always the longest run of the week (easy runs ≤ 75 % of it, recovery weeks ≤ 60 %),
///   per-session caps for T/I/R volume.
/// * Cycling: Coggan zones from FTP, pyramidal/80-20 by weekly hours.
/// * Swimming: CSS zones, warm-up/drills/main/cool-down structure.
/// * Strength: chosen or recommended split (each muscle ≥ 2×/week, Schoenfeld 2016),
///   RIR wave 3→2→1 then deload (sets × 0.5), rep ranges by goal.
/// * Concurrent: no heavy legs the day before a key endurance session (C3),
///   max one key session per day, no back-to-back key days for beginners (H1).
/// * Every session fits the time the athlete has on that day.
/// * Race day is placed on the event date with a shake-out run the day before.
class PlanGenerator {
  PlanGenerator(this.l, this.profile, this.templates, String Function() newId) : _id = newId;
  final AppLocalizations l;
  final UserProfile profile;
  final List<WorkoutTemplate> templates;
  final String Function() _id;

  AthleteData get a => profile.athlete;
  String get level => profile.level;
  bool get beginner => level == 'beginner';

  // ── difficulty parameters (§8) ──
  double get _growth => switch (a.difficulty) {
    'easy' => 0.05,
    'challenging' => 0.10,
    _ => 0.08,
  };
  int get _loadWeeks => switch (a.difficulty) {
    'easy' => 2,
    'challenging' => level == 'advanced' ? 4 : 3,
    _ => 3,
  };
  double get _recoveryFactor => switch (a.difficulty) {
    'easy' => 0.60,
    'challenging' => 0.75,
    _ => 0.70,
  };
  double get _longCap => a.difficulty == 'easy' ? 1.05 : 1.10;

  late final PaceZones pz = PaceZones(Vdot.of(a) ?? Vdot.defaultFor(level));
  late final HrZones hz = HrZones(profile.estimatedMaxHr, a.restHr);
  late final int? ftp = a.ftp ?? (a.hasPowerMeter ? PowerZones.estimate(level, profile.weightKg) : null);
  late final SwimZones sz = SwimZones(SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(level));

  /// First day of the generated plan (weeks are counted from its Monday).
  DateTime _start = DateTime.now();

  /// Number of weeks until (and including) race week, if an event is set.
  int? get weeksToEvent {
    final d = a.eventDate;
    if (d == null) return null;
    final w = (startOfWeek(d).difference(startOfWeek(_start)).inDays / 7).floor() + 1;
    return w >= 2 && w <= 30 ? w : null;
  }

  int get _taperWeeks => switch (a.eventDistance) {
    'm' || '70.3' => beginner ? 2 : 3,
    'hm' || 'olympic' => 2,
    '5k' || '10k' || 'sprint' => 1,
    _ => 0,
  };

  List<PlannedWorkout> generate({required DateTime start, int? weeks}) {
    _start = start;
    final total = weeksToEvent ?? weeks ?? a.planWeeks;
    final schedule = _weekSchedule();
    final phases = _phases(total);
    final out = <PlannedWorkout>[];
    final monday = startOfWeek(start);

    // Weekly volume curves.
    final all = schedule.values.expand((e) => e);
    final runPerWeek = all.where((s) => s == Sport.run).length;
    final ridePerWeek = all.where((s) => s == Sport.ride).length;
    final swimPerWeek = all.where((s) => s == Sport.swim).length;
    final runKm = _curve(total, phases, _runStartKm(runPerWeek), _runCeilingKm(runPerWeek));
    final rideH = _curve(total, phases, _rideStartH(ridePerWeek), _rideStartH(ridePerWeek) * 1.5);
    final swimKm = _curve(total, phases, _swimStartKm(swimPerWeek), _swimStartKm(swimPerWeek) * 1.4);
    // Long-run share: 1 run/week → the whole volume, 2 → ~55 %, otherwise 27–32 % (Daniels).
    double longShare(double wk) => runPerWeek <= 1 ? 1.0 : (runPerWeek == 2 ? 0.55 : (wk < 40 ? 0.32 : 0.27));
    var longestRun = a.longestRunKm ?? max(3.0, runKm.first * longShare(runKm.first));
    var tempoMin = beginner ? 12 : (level == 'advanced' ? 20 : 15);
    var intervalReps = beginner ? 4 : (level == 'advanced' ? 6 : 5);
    final gymQueue = _GymQueue(_gymRotation(schedule));
    var runWalkWeek = 0;

    for (var w = 0; w < total; w++) {
      final phase = phases[w];
      final roles = _roles(schedule, phase);
      final weekStart = monday.add(Duration(days: w * 7));
      final rest = phase == 'recovery' || phase == 'taper';

      // Long run respects the 30-day max rule (R1) and 25–30 % of weekly km.
      final wk = runKm[w];
      final longKm = min(wk * longShare(wk), longestRun * (rest ? 0.75 : _longCap));
      if (!rest) longestRun = max(longestRun, longKm);

      // Pass 1: everything except easy runs. Pass 2: easy runs share the remaining
      // weekly volume but stay clearly shorter than the long run.
      final week = <PlannedWorkout>[];
      final easyRuns = <(DateTime, int)>[];
      for (final entry in roles.entries) {
        final day = weekStart.add(Duration(days: entry.key - 1));
        if (day.isBefore(dayOnly(start))) continue;
        final n = entry.value.length;
        for (final r in entry.value) {
          final cap = _capMinutes(entry.key, n);
          if (r.sport == Sport.run) {
            if (!a.canRun30 && (beginner || a.raceTimes.isEmpty) && runWalkWeek < 18) {
              week.add(_runWalk(day, runWalkWeek++ ~/ max(1, runPerWeek), phase));
              continue;
            }
            if (r.role == 'easy') {
              easyRuns.add((day, cap));
              continue;
            }
          }
          week.add(switch (r.sport) {
            Sport.run => _run(day, r.role, phase, wk, longKm, tempoMin, intervalReps, w, cap),
            Sport.ride => _ride(day, r.role, phase, rideH[w], ridePerWeek, w, cap),
            Sport.swim => _swim(day, r.role, phase, swimKm[w], swimPerWeek, w, cap),
            Sport.gym => _gym(day, gymQueue, schedule, phase, w, r.role, cap),
          });
        }
      }
      if (easyRuns.isNotEmpty) {
        final runs = week.where((p) => p.sport == Sport.run);
        final used = runs.fold<double>(0, (x, p) => x + (p.distanceKm ?? 0));
        final longest = runs.where((p) => p.intensity == 'long').fold<double>(0, (x, p) => max(x, p.distanceKm ?? 0));
        final ref = longest > 0 ? longest : longKm;
        final capKm = max(3.0, ref * (rest ? 0.6 : 0.75));
        final each = ((wk - used) / easyRuns.length).clamp(3.0, capKm);
        for (final (day, cap) in easyRuns) {
          week.add(_easyRun(day, phase, each, w, cap));
        }
      }
      out.addAll(week);
      if (!rest) {
        tempoMin = min(tempoMin + (a.difficulty == 'easy' ? 2 : 4), 30);
        if (w.isOdd) intervalReps = min(intervalReps + 1, level == 'advanced' ? 8 : 6);
      }
    }
    _addRace(out, start);
    out.sort((x, y) => x.date.compareTo(y.date));
    return out;
  }

  // ───────────────────────────── Time available ─────────────────────────────

  /// Minutes for one session: the day's limit split between the sessions of that day.
  int _capMinutes(int weekday, int sessionsThatDay) {
    final day = dayMinutesFor(profile, weekday);
    return max(20, sessionsThatDay <= 1 ? day : (day / sessionsThatDay).round());
  }

  /// Time available on [weekday]: explicit per-day value, else the global maximum –
  /// on the long-session day at least 2 h unless that day was set explicitly.
  static int dayMinutesFor(UserProfile p, int weekday) {
    final a = p.athlete;
    final explicit = a.dayMinutes[weekday];
    if (explicit != null) return explicit;
    return weekday == longDayOf(p) ? max(a.sessionMinutes, 120) : a.sessionMinutes;
  }

  /// The day of the long endurance session (null for gym-only plans).
  static int? longDayOf(UserProfile p) {
    final plan = p.athlete.dayPlan.values.any((v) => v.isNotEmpty) ? p.athlete.dayPlan : deriveSchedule(p);
    final endurance = plan.entries.where((e) => e.value.any((s) => s != Sport.gym)).map((e) => e.key).toList()..sort();
    if (endurance.isEmpty) return null;
    if (p.longDay != null && endurance.contains(p.longDay)) return p.longDay;
    return endurance.last;
  }

  // ───────────────────────────── Structure ─────────────────────────────

  /// weekday → sports. Advanced setup provides it directly; otherwise derive it.
  Map<int, List<Sport>> _weekSchedule() {
    if (a.dayPlan.values.any((v) => v.isNotEmpty)) {
      return {
        for (final e in a.dayPlan.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      };
    }
    return deriveSchedule(profile);
  }

  /// Default weekday → sport mapping from training days and focus.
  static Map<int, List<Sport>> deriveSchedule(UserProfile profile) {
    final days = (profile.trainingDays.isEmpty ? [1, 3, 5] : [...profile.trainingDays])..sort();
    final longDay = profile.longDay ?? days.last;
    final base = profile.focus.sports;
    final res = <int, List<Sport>>{};
    if (base.length == 1) {
      for (final d in days) {
        res[d] = [base.first];
      }
      return res;
    }
    // Multi-sport: distribute, main endurance sport on the long day.
    final seq = <Sport>[];
    for (var i = 0; i < days.length; i++) {
      seq.add(base[i % base.length]);
    }
    final main = profile.focus == TrainingFocus.hybrid || profile.focus == TrainingFocus.duathlon ? Sport.run : Sport.ride;
    final li = days.indexOf(longDay);
    final si = seq.indexOf(main);
    if (li >= 0 && si >= 0 && si != li) {
      final t = seq[li];
      seq[li] = main;
      seq[si] = t;
    }
    for (var i = 0; i < days.length; i++) {
      res[days[i]] = [seq[i]];
    }
    return res;
  }

  List<String> _phases(int total) {
    final taper = weeksToEvent != null ? min(_taperWeeks, max(0, total - 2)) : 0;
    final body = total - taper;
    final base = max(1, (body * (beginner ? 0.5 : 0.42)).round());
    final peak = weeksToEvent != null ? max(1, (body * 0.18).round()) : 0;
    final build = max(0, body - base - peak);
    final out = <String>[
      ...List.filled(base, 'base'),
      ...List.filled(build, 'build'),
      ...List.filled(peak, 'peak'),
      ...List.filled(taper, 'taper'),
    ];
    // Recovery weeks: after every N loading weeks (never in taper or the final week).
    var run = 0;
    for (var i = 0; i < out.length; i++) {
      if (out[i] == 'taper') break;
      run++;
      if (run > _loadWeeks && i < out.length - 1 - taper) {
        out[i] = 'recovery';
        run = 0;
      }
    }
    return out;
  }

  /// Weekly volume: grow by g toward the ceiling, recovery weeks at a fraction of the
  /// last loading week, taper with a progressive cut.
  List<double> _curve(int total, List<String> phases, double startV, double ceiling) {
    final out = <double>[];
    var last = startV;
    final taperIdx = phases.indexOf('taper');
    final nTaper = phases.where((x) => x == 'taper').length;
    for (var i = 0; i < total; i++) {
      final p = phases[i];
      if (p == 'recovery') {
        out.add(last * _recoveryFactor);
      } else if (p == 'taper') {
        final k = i - taperIdx;
        final f = nTaper >= 3 ? const [0.8, 0.65, 0.45][min(k, 2)] : (nTaper == 2 ? const [0.7, 0.5][k] : 0.55);
        out.add(last * f);
      } else {
        if (i > 0) last = min(ceiling, last * (1 + _growth));
        out.add(last);
      }
    }
    return out;
  }

  double _runStartKm(int perWeek) {
    if (perWeek == 0) return 0;
    if (a.runWeeklyKm != null && a.runWeeklyKm! > 0) return a.runWeeklyKm!;
    final per = switch (level) {
      'advanced' => 9.0,
      'intermediate' => 7.0,
      _ => 4.5,
    };
    return per * perWeek;
  }

  double _runCeilingKm(int perWeek) {
    final lv = switch (level) {
      'advanced' => 2,
      'intermediate' => 1,
      _ => 0,
    };
    final table = switch (a.eventDistance) {
      '5k' => const [15.0, 30.0, 50.0],
      '10k' => const [25.0, 40.0, 60.0],
      'hm' => const [30.0, 50.0, 70.0],
      'm' => const [45.0, 65.0, 90.0],
      _ => <double>[],
    };
    final start = _runStartKm(perWeek);
    var c = table.isEmpty ? start * 1.35 : max(table[lv], start);
    if (a.difficulty == 'challenging') c *= 1.15;
    if (a.difficulty == 'easy' && table.isNotEmpty) c = max(table[0], start);
    return max(c, start);
  }

  double _rideStartH(int perWeek) {
    if (perWeek == 0) return 0;
    if (a.bikeWeeklyHours != null && a.bikeWeeklyHours! > 0) return a.bikeWeeklyHours!;
    return perWeek *
        switch (level) {
          'advanced' => 1.5,
          'intermediate' => 1.1,
          _ => 0.8,
        };
  }

  double _swimStartKm(int perWeek) {
    if (perWeek == 0) return 0;
    if (a.swimWeeklyKm != null && a.swimWeeklyKm! > 0) return a.swimWeeklyKm!;
    return perWeek *
        switch (level) {
          'advanced' => 3.5,
          'intermediate' => 2.5,
          _ => (a.canSwim400 ? 1.5 : 1.0),
        };
  }

  int _maxQualityRuns(int nRuns, String phase) {
    if (phase == 'recovery' || phase == 'taper') return nRuns >= 3 ? 1 : 0;
    // Keep ≥ 75 % of runs easy: ≤ 4 runs → 1 quality session (2 when challenging).
    var q = nRuns <= 4 ? 1 : 2;
    if (nRuns >= 3 && nRuns <= 4 && a.difficulty == 'challenging' && level != 'beginner') q = 2;
    if (nRuns >= 6 && level == 'advanced' && phase == 'build') q = 3;
    if (a.difficulty == 'easy') q = min(q, 1);
    if (nRuns <= 1) q = 0;
    return q;
  }

  /// Assigns roles (long / q1 / q2 / easy / …) per sport, spacing key sessions.
  Map<int, List<_Slot>> _roles(Map<int, List<Sport>> schedule, String phase) {
    final days = schedule.keys.toList()..sort();
    final roles = {for (final d in days) d: schedule[d]!.map((s) => _Slot(s, 'easy')).toList()};
    final keyDays = <int>{};
    final longDay = profile.longDay ?? days.last;

    bool spaced(int d) {
      if (keyDays.contains(d)) return false;
      if (beginner || level == 'intermediate') {
        return !keyDays.contains(d - 1) && !keyDays.contains(d + 1);
      }
      return true;
    }

    for (final sport in [Sport.run, Sport.ride, Sport.swim]) {
      final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
      if (sDays.isEmpty) continue;
      // Long session: preferred long day, else the latest free day (no long swim).
      int? ld;
      if (sport != Sport.swim) {
        ld =
            sDays.contains(longDay) && !keyDays.contains(longDay)
                ? longDay
                : sDays.lastWhere((d) => !keyDays.contains(d), orElse: () => sDays.last);
        roles[ld]!.firstWhere((x) => x.sport == sport).role = 'long';
        keyDays.add(ld);
      }
      final nQ = switch (sport) {
        Sport.run => _maxQualityRuns(sDays.length, phase),
        Sport.ride =>
          phase == 'recovery' || phase == 'taper' ? (sDays.length >= 3 ? 1 : 0) : (sDays.length >= 3 ? 2 : (sDays.length == 2 ? 1 : 0)),
        Sport.swim => sDays.length >= 2 ? 1 : 0,
        Sport.gym => 0,
      };
      var q = 0;
      // Prefer days far from the long day.
      final cand = [...sDays.where((d) => d != ld)]..sort((x, y) => ((y - (ld ?? 7)).abs()).compareTo((x - (ld ?? 7)).abs()));
      for (final d in cand) {
        if (q >= nQ) break;
        if (!spaced(d)) continue;
        // Never the day right before the long run (H5).
        if (ld != null && d == ld - 1 && sport == Sport.run) continue;
        roles[d]!.firstWhere((x) => x.sport == sport).role = 'q${q + 1}';
        keyDays.add(d);
        q++;
      }
      // Swim: if no quality session, first swim is technique.
      if (sport == Sport.swim) {
        final first = roles[sDays.first]!.firstWhere((x) => x.sport == sport);
        if (first.role == 'easy') first.role = 'technique';
      }
    }
    // Gym: sessions the day before a key endurance session avoid heavy legs (C3).
    for (final d in days) {
      for (final s in roles[d]!) {
        if (s.sport == Sport.gym && keyDays.contains(d + 1)) s.role = 'nolegs';
      }
    }
    return roles;
  }

  // ───────────────────────────── Running ─────────────────────────────

  WorkoutStep _runStep(String kind, String zone, {double? km, int? sec, String note = ''}) {
    final (fast, slow) = pz.range(zone);
    final hr = switch (zone) {
      'E' || 'L' || 'REC' => hz.zone(2),
      'M' => hz.zone(3),
      'T' => hz.zone(4),
      'I' || 'R' => hz.zone(5),
      _ => hz.zone(2),
    };
    final noPace = zone == 'walk' || (beginner && a.raceTimes.isEmpty);
    return WorkoutStep(
      kind: kind,
      distanceM: km == null ? null : (km * 1000).roundToDouble(),
      durationSec: sec,
      zone: zone,
      paceMin: noPace ? null : fast,
      paceMax: noPace ? null : slow,
      hrMin: zone == 'walk' ? null : hr.$1,
      hrMax: zone == 'walk' ? null : hr.$2,
      note: note,
    );
  }

  double _r1(double v) => (v * 2).round() / 2; // 0.5 km steps

  /// Long and quality runs (easy runs: [_easyRun]).
  PlannedWorkout _run(
    DateTime day,
    String role,
    String phase,
    double weekKm,
    double longKm,
    int tempoMin,
    int intervalReps,
    int week,
    int capMin,
  ) {
    final dist = a.eventDistance;
    final wu = _runStep('warmup', 'E', km: beginner ? 1.5 : 2, note: l.stepWarmupNote);
    final cd = _runStep('cooldown', 'E', km: beginner ? 1 : 1.5);
    String title, desc, intensity = 'easy';
    var steps = <WorkoutStep>[];
    var isKey = false;

    if (role == 'long') {
      // Fit into the time available that day.
      final km = max(4.0, _r1(min(longKm, capMin * 60 / pz.easySlow)));
      isKey = true;
      intensity = 'long';
      // Marathon / HM peak: last 25 % at goal pace (M).
      if (phase == 'peak' && (dist == 'm' || dist == 'hm') && !beginner) {
        final mpKm = _r1(km * 0.25);
        steps = [_runStep('steady', 'E', km: km - mpKm), _runStep('work', 'M', km: mpKm, note: l.stepMpNote)];
        title = l.wLongRunMp;
        desc = l.wLongRunMpDesc;
      } else {
        steps = [_runStep('steady', 'E', km: km, note: l.stepEasyNote)];
        title = l.planLongRun;
        desc = l.wLongRunDesc;
      }
      return _plan(day, Sport.run, title, desc, intensity, steps, phase, isKey);
    }
    if (!role.startsWith('q')) return _easyRun(day, phase, 5, week, capMin);

    isKey = true;
    final second = role == 'q2';
    final useIntervals = (phase == 'build' || phase == 'peak') && level != 'beginner';
    final shortRace = dist == '5k' || dist == '10k' || dist == null;
    if (phase == 'base' || phase == 'recovery' || phase == 'taper' || beginner) {
      if (phase == 'base' && !second && level != 'beginner' && week.isOdd) {
        // Tempo appears in base for non-beginners (pyramidal distribution).
        final t = min(tempoMin, 20);
        steps = [wu, _runStep('work', 'T', sec: t * 60, note: l.stepTempoNote), cd];
        title = l.planRunTempo;
        desc = l.wTempoDesc;
        intensity = 'tempo';
      } else {
        // Fartlek / strides: easy run with short pick-ups.
        final reps = phase == 'taper' ? 4 : (beginner ? 5 : 6 + week % 3);
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_runStep('work', 'I', sec: beginner ? 45 : 60, note: l.stepFartlekNote));
          steps.add(_runStep('recovery', 'REC', sec: 90));
        }
        steps.add(cd);
        title = l.wFartlek;
        desc = l.wFartlekDesc;
        intensity = 'tempo';
      }
    } else if (useIntervals && (second ? !shortRace : shortRace)) {
      // VO2max intervals (I), volume ≤ min(8 % weekly km, 10 km).
      final repM = level == 'advanced' ? 1000.0 : 800.0;
      final maxReps = max(3, (min(weekKm * 0.08, 10) * 1000 / repM).floor());
      final reps = min(intervalReps, maxReps);
      final repSec = (repM / 1000 * pz.interval).round();
      steps = [wu];
      for (var i = 0; i < reps; i++) {
        steps.add(_runStep('work', 'I', km: repM / 1000, note: l.stepIntervalNote));
        if (i < reps - 1) steps.add(_runStep('recovery', 'REC', sec: (repSec * 0.8).round()));
      }
      steps.add(cd);
      title = l.wIntervals(reps, (repM).round());
      desc = l.wIntervalsDesc;
      intensity = 'intervals';
    } else if (phase == 'peak' && dist == 'm' && second) {
      final mp = _r1(min(weekKm * 0.2, 14));
      steps = [wu, _runStep('work', 'M', km: mp, note: l.stepMpNote), cd];
      title = l.wMpRun;
      desc = l.wMpRunDesc;
      intensity = 'tempo';
    } else {
      // Threshold: cruise intervals once tempo ≥ 20 min (T ≤ 10 % weekly km).
      final tKm = min(weekKm * 0.10, tempoMin * 60 / pz.threshold);
      if (tempoMin >= 20 && tKm >= 4.5) {
        final reps = max(3, (tKm / 1.6).floor());
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_runStep('work', 'T', km: 1.6, note: l.stepTempoNote));
          if (i < reps - 1) steps.add(_runStep('recovery', 'REC', sec: 60));
        }
        steps.add(cd);
        title = l.wCruise(reps);
        desc = l.wCruiseDesc;
      } else {
        steps = [wu, _runStep('work', 'T', sec: tempoMin * 60, note: l.stepTempoNote), cd];
        title = l.planRunTempo;
        desc = l.wTempoDesc;
      }
      intensity = 'tempo';
    }
    steps = _fitToTime(steps, capMin * 60, Sport.run);
    // Titles with a repeat count must match the (possibly shortened) workout.
    final reps = steps.where((s) => s.isWork).length;
    if (intensity == 'intervals') title = l.wIntervals(reps, (steps.firstWhere((s) => s.isWork).distanceM ?? 800).round());
    if (desc == l.wCruiseDesc) title = l.wCruise(reps);
    return _plan(day, Sport.run, title, desc, intensity, steps, phase, isKey);
  }

  /// Easy run of [km] (capped by the time available); some get strides (base/build).
  PlannedWorkout _easyRun(DateTime day, String phase, double km, int week, int capMin) {
    final k = max(3.0, _r1(min(km, capMin * 60 / pz.easySlow)));
    final steps = [_runStep('steady', 'E', km: k, note: l.stepEasyNote)];
    String title, desc;
    if ((phase == 'base' || phase == 'build') && !beginner && day.weekday.isEven) {
      for (var i = 0; i < 4 + min(4, week ~/ 2); i++) {
        steps.add(_runStep('work', 'R', sec: 20, note: l.stepStrideNote));
        steps.add(_runStep('recovery', 'walk', sec: 60));
      }
      title = l.wEasyStrides;
      desc = l.wEasyStridesDesc;
    } else {
      title = phase == 'recovery' ? l.wRecoveryRun : l.planEasyRun;
      desc = l.wEasyDesc;
    }
    return _plan(day, Sport.run, title, desc, 'easy', steps, phase, false);
  }

  /// Couch-to-5K style run/walk progression (beginners who cannot run 30 min).
  PlannedWorkout _runWalk(DateTime day, int week, String phase) {
    const table = [
      (60, 90, 8),
      (90, 120, 6),
      (120, 120, 5),
      (180, 90, 5),
      (300, 180, 3),
      (480, 300, 2),
      (600, 120, 2),
      (900, 120, 2),
      (1200, 0, 1),
      (1500, 0, 1),
      (1800, 0, 1),
    ];
    final t = table[min(week, table.length - 1)];
    final steps = <WorkoutStep>[_runStep('warmup', 'walk', sec: 300, note: l.stepBriskWalk)];
    for (var i = 0; i < t.$3; i++) {
      steps.add(_runStep('work', 'E', sec: t.$1, note: l.stepTalkPace));
      if (t.$2 > 0 && i < t.$3 - 1) steps.add(_runStep('recovery', 'walk', sec: t.$2));
    }
    steps.add(_runStep('cooldown', 'walk', sec: 300));
    return _plan(day, Sport.run, l.wRunWalk(t.$3, t.$1 ~/ 60 == 0 ? 1 : t.$1 ~/ 60), l.wRunWalkDesc, 'easy', steps, phase, false);
  }

  // ───────────────────────────── Cycling ─────────────────────────────

  WorkoutStep _rideStep(String kind, String zone, int sec, {String note = ''}) {
    final p = ftp == null ? null : PowerZones(ftp!).range(zone);
    final hzN = switch (zone) {
      'Z1' => 1,
      'Z2' => 2,
      'Z3' || 'SS' => 3,
      'Z4' => 4,
      _ => 5,
    };
    final hr = hz.zone(hzN);
    return WorkoutStep(
      kind: kind,
      durationSec: sec,
      zone: zone,
      powerMin: p?.$1,
      powerMax: p?.$2,
      hrMin: hr.$1 - 5,
      hrMax: hr.$2 - 5,
      note: note,
    );
  }

  int _longRideMin(double weekH) => max(60, ((weekH * 0.42) * 60 / 15).round() * 15);

  PlannedWorkout _ride(DateTime day, String role, String phase, double weekH, int perWeek, int week, int capMin) {
    final wu = _rideStep('warmup', 'Z2', 600);
    final cd = _rideStep('cooldown', 'Z1', 600);
    String title, desc, intensity = 'easy';
    List<WorkoutStep> steps;
    var isKey = false;
    if (role == 'long') {
      steps = [_rideStep('steady', 'Z2', min(capMin, _longRideMin(weekH)) * 60, note: l.stepZ2RideNote)];
      title = l.planLongRide;
      desc = l.wLongRideDesc;
      intensity = 'long';
      isKey = true;
    } else if (role.startsWith('q')) {
      isKey = true;
      final vo2 = role == 'q2' || (phase == 'peak' && perWeek < 3);
      if (vo2 && phase != 'base') {
        final reps = 4 + min(2, week ~/ 3);
        final dur = phase == 'peak' ? 240 : 180;
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_rideStep('work', 'Z5', dur, note: l.stepVo2Note));
          if (i < reps - 1) steps.add(_rideStep('recovery', 'Z1', dur));
        }
        steps.add(cd);
        steps = _fitToTime(steps, capMin * 60, Sport.ride);
        title = l.wRideVo2(steps.where((s) => s.isWork).length, dur ~/ 60);
        desc = l.wRideVo2Desc;
        intensity = 'intervals';
      } else {
        // Sweet spot in base, threshold later.
        final ss = phase == 'base' || phase == 'recovery';
        final total = min(60, 24 + week * 4);
        final reps = total <= 30 ? 3 : 2;
        final each = (total / reps / 5).round() * 5;
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_rideStep('work', ss ? 'SS' : 'Z4', each * 60, note: ss ? l.stepSsNote : l.stepThresholdNote));
          if (i < reps - 1) steps.add(_rideStep('recovery', 'Z1', 300));
        }
        steps.add(cd);
        steps = _fitToTime(steps, capMin * 60, Sport.ride);
        final n = steps.where((s) => s.isWork).length;
        final e = (steps.firstWhere((s) => s.isWork).durationSec! / 60).round();
        title = ss ? l.wSweetSpot(n, e) : l.wThreshold(n, e);
        desc = ss ? l.wSweetSpotDesc : l.wThresholdDesc;
        intensity = 'tempo';
      }
    } else {
      // Remaining time after the long ride and ~65 min per quality ride, never longer
      // than 75 % of the long ride.
      final longMin = _longRideMin(weekH);
      final nQ = perWeek >= 3 ? (phase == 'recovery' || phase == 'taper' ? 1 : 2) : (perWeek == 2 ? 1 : 0);
      final easyCount = max(1, perWeek - 1 - nQ);
      final left = weekH * 60 - longMin - nQ * 65;
      final easyMin = ((left / easyCount).clamp(40, max(40, longMin * 0.75)) / 5).round() * 5;
      steps = [_rideStep('steady', 'Z2', min(easyMin, capMin) * 60, note: l.stepZ2RideNote)];
      title = phase == 'recovery' ? l.wRecoveryRide : l.planEasyRide;
      desc = l.wEasyRideDesc;
    }
    return _plan(day, Sport.ride, title, desc, intensity, steps, phase, isKey);
  }

  // ───────────────────────────── Swimming ─────────────────────────────

  WorkoutStep _swimStep(String kind, String zone, double m, {String note = ''}) {
    final (fast, slow) = sz.range(zone);
    final noPace = beginner && a.swim400Sec == null;
    return WorkoutStep(kind: kind, distanceM: m, zone: zone, paceMin: noPace ? null : fast, paceMax: noPace ? null : slow, note: note);
  }

  /// Two concrete technique drills, rotating weekly (see zone_info.dart › swimDrills).
  String _drillNote(int week) {
    final names = [l.drillCatchupName, l.drillFingertipName, l.drillSideKickName, l.drillSingleArmName, l.drillFistName, l.drillScullName];
    final i = (week * 2) % names.length;
    return l.drillsNote(names[i], names[(i + 1) % names.length]);
  }

  PlannedWorkout _swim(DateTime day, String role, String phase, double weekKm, int perWeek, int week, int capMin) {
    // Session distance, limited by the time available (≈ CSS + 15 s per 100 m incl. rests).
    final maxM = capMin * 60 / ((sz.css + 15) / 100);
    final total = max(beginner ? 600.0 : 1000.0, (min(weekKm * 1000 / max(1, perWeek), maxM) / 100).round() * 100.0);
    final wu = _swimStep('warmup', 'REC', (total * 0.18 / 50).round() * 50.0, note: l.stepSwimWu);
    final cd = _swimStep('cooldown', 'REC', max(100.0, (total * 0.1 / 50).round() * 50.0));
    String title, desc, intensity;
    final steps = <WorkoutStep>[wu];
    var isKey = false;
    if (role == 'q1' && !beginner) {
      // CSS set: n × 100 m @ CSS, 15 s rest.
      final n = max(6, ((total * 0.55) / 100).round());
      steps.add(_swimStep('work', 'DR', 200, note: _drillNote(week)));
      steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      for (var i = 0; i < n; i++) {
        steps.add(_swimStep('work', 'CSS', 100, note: l.stepCssNote));
        if (i < n - 1) steps.add(const WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'));
      }
      title = l.wSwimCss(n);
      desc = l.wSwimCssDesc;
      intensity = 'intervals';
      isKey = true;
    } else if (role == 'technique' || beginner) {
      steps.add(_swimStep('work', 'DR', (total * (beginner ? 0.35 : 0.2) / 50).round() * 50.0, note: _drillNote(week)));
      steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      final main = (total * 0.45 / 50).round() * 50.0;
      final reps = max(2, (main / (beginner ? 50 : 100)).round());
      for (var i = 0; i < reps; i++) {
        steps.add(_swimStep('work', 'EN', beginner ? 50 : 100, note: l.stepSwimEasyNote));
        if (i < reps - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: beginner ? 30 : 20, zone: 'REC'));
      }
      title = l.planSwimTechnique;
      desc = l.wSwimTechDesc;
      intensity = 'technique';
    } else {
      final main = (total * 0.65 / 100).round() * 100.0;
      final rep = main >= 1200 ? 400.0 : 200.0;
      final reps = max(2, (main / rep).round());
      for (var i = 0; i < reps; i++) {
        steps.add(_swimStep('work', 'EN', rep, note: l.stepSwimEnNote));
        if (i < reps - 1) steps.add(const WorkoutStep(kind: 'recovery', durationSec: 20, zone: 'REC'));
      }
      title = l.wSwimEndurance(reps, rep.round());
      desc = l.wSwimEnduranceDesc;
      intensity = 'easy';
    }
    steps.add(cd);
    return _plan(day, Sport.swim, title, desc, intensity, steps, phase, isKey);
  }

  // ───────────────────────────── Strength ─────────────────────────────

  /// Built-in program keys the plan for [p] will use.
  static List<String> gymKeysFor(UserProfile p) {
    final a = p.athlete;
    final schedule = a.dayPlan.values.any((v) => v.isNotEmpty) ? a.dayPlan : deriveSchedule(p);
    return _rotationFor(a, schedule);
  }

  List<String> _gymRotation(Map<int, List<Sport>> schedule) => _rotationFor(a, schedule);

  /// Program rotation for the chosen (or recommended) split and equipment.
  static List<String> _rotationFor(AthleteData a, Map<int, List<Sport>> schedule) {
    if (a.equipment == 'home') return splitRotation['home']!;
    if (a.equipment == 'bodyweight') return splitRotation['bodyweight']!;
    final all = schedule.values.expand((e) => e);
    final gymDays = all.where((s) => s == Sport.gym).length;
    final endurance = all.where((s) => s != Sport.gym).length;
    final split = a.gymSplit == 'auto' ? recommendedSplit(gymDays, enduranceSessions: endurance) : a.gymSplit;
    final rot = splitRotation[split] ?? splitRotation['fullbody']!;
    // Two full-body days a week alternate A/B (C is the optional third day).
    return split == 'fullbody' && gymDays <= 2 ? rot.take(2).toList() : rot;
  }

  /// Old (pre-key) template names, so existing users keep their programs.
  static const _legacyNames = {
    'fb_a': 'Full Body A',
    'fb_b': 'Full Body B',
    'ul_upper_a': 'Upper',
    'ul_upper_b': 'Upper',
    'ul_lower_a': 'Lower',
    'ul_lower_b': 'Lower',
    'ppl_push': 'Push',
    'ppl_pull': 'Pull',
    'ppl_legs': 'Legs',
  };

  WorkoutTemplate? _template(String key) =>
      templates.where((t) => t.key == key).firstOrNull ?? templates.where((t) => t.name == _legacyNames[key]).firstOrNull;

  PlannedWorkout _gym(DateTime day, _GymQueue queue, Map<int, List<Sport>> schedule, String phase, int week, String role, int capMin) {
    final endurance = schedule.values.expand((e) => e).any((s) => s != Sport.gym);
    // C3: no heavy legs the day before a key endurance session.
    final key = queue.next(avoid: role == 'nolegs' ? legHeavyKeys : const {});
    final t = _template(key);
    final name = t?.name ?? _builtinName(key);
    final deload = phase == 'recovery' || phase == 'taper';
    final rir = deload ? 4 : [3, 2, 1][week % 3];
    final (lo, hi) = switch (a.gymGoal) {
      'strength' => (4, 6),
      'hypertrophy' => (8, 12),
      _ => endurance ? (5, 8) : (6, 10),
    };
    final sets = deload ? 2 : (a.difficulty == 'easy' ? 3 : (a.difficulty == 'challenging' && level != 'beginner' ? 4 : 3));
    final est = t?.estimatedMinutes ?? 60;
    final minutes = deload ? (est * 0.7).round() : est;
    final legsInside = key.startsWith('fb_') || key.startsWith('home_') || key.startsWith('bw_') || legHeavyKeys.contains(key);
    final notes = [
      deload ? l.wGymDeloadDesc(sets) : l.wGymDesc(sets, lo, hi, rir),
      if (endurance && role == 'nolegs' && legsInside) l.wGymConcurrentNote,
      if (minutes > capMin) l.wGymTimeCapNote(capMin),
    ];
    return PlannedWorkout(
      id: _id(),
      date: day,
      sport: Sport.gym,
      title: name,
      description: notes.join('\n'),
      durationMin: min(minutes, capMin),
      templateId: t?.id,
      intensity: deload ? 'easy' : 'moderate',
      phase: phase,
    );
  }

  String _builtinName(String key) {
    final de = l.localeName.startsWith('de');
    return defaultTemplates(() => '', de: de).firstWhere((t) => t.key == key).name;
  }

  // ───────────────────────────── Race ─────────────────────────────

  /// Puts the race on the event day; the day before becomes a shake-out run, no
  /// strength in the last 3 days and nothing after the race in that week.
  void _addRace(List<PlannedWorkout> out, DateTime start) {
    final d = a.eventDate;
    if (d == null || weeksToEvent == null || a.eventDistance == null) return;
    final race = dayOnly(d);
    if (race.isBefore(dayOnly(start))) return;
    final before = race.subtract(const Duration(days: 1));
    out.removeWhere((p) {
      final diff = dayOnly(p.date).difference(race).inDays;
      if (diff >= 0 && diff < 7) return true; // race day and the rest of race week
      if (diff == -1) return true; // replaced by the shake-out
      if (p.sport == Sport.gym && diff >= -3) return true;
      return false;
    });
    final tri = a.eventDistance == 'sprint' || a.eventDistance == 'olympic' || a.eventDistance == '70.3';
    if (!before.isBefore(dayOnly(start))) {
      out.add(
        _plan(
          before,
          Sport.run,
          l.wShakeout,
          l.wShakeoutDesc,
          'easy',
          [
            _runStep('steady', 'E', sec: 15 * 60, note: l.stepEasyNote),
            for (var i = 0; i < 4; i++) ...[_runStep('work', 'R', sec: 20, note: l.stepStrideNote), _runStep('recovery', 'walk', sec: 60)],
          ],
          'taper',
          false,
        ),
      );
    }
    final km = Vdot.distances[a.eventDistance];
    final vdot = Vdot.of(a);
    final goal = a.targetTimeSec ?? (!tri && km != null && vdot != null ? Vdot.raceTime(vdot, km) : null);
    final pace = goal != null && km != null && !tri ? (goal / km).round() : null;
    final steps =
        tri || km == null
            ? <WorkoutStep>[]
            : [
              _runStep('warmup', 'E', sec: 10 * 60, note: l.stepWarmupNote),
              WorkoutStep(
                kind: 'work',
                distanceM: km * 1000,
                zone: 'M',
                paceMin: pace == null ? null : pace - 3,
                paceMax: pace == null ? null : pace + 3,
                note: l.stepRaceNote,
              ),
            ];
    out.add(
      PlannedWorkout(
        id: _id(),
        date: race,
        sport: tri ? Sport.swim : Sport.run,
        title: l.wRace(_eventName()),
        description: goal == null ? l.wRaceDesc : l.wRaceGoalDesc(clock(goal)),
        durationMin: goal == null ? 60 : (goal / 60).round(),
        distanceKm: tri ? _triKm(a.eventDistance) : km,
        intensity: 'race',
        steps: steps,
        phase: 'taper',
        isKey: true,
      ),
    );
  }

  static double? _triKm(String? d) => switch (d) {
    'sprint' => 25.75,
    'olympic' => 51.5,
    '70.3' => 113,
    _ => null,
  };

  String _eventName() => switch (a.eventDistance) {
    '5k' => '5 km',
    '10k' => '10 km',
    'hm' => l.halfMarathon,
    'm' => l.marathon,
    'sprint' => 'Sprint-Triathlon',
    'olympic' => l.olympicTri,
    '70.3' => l.middleDistance,
    _ => l.eventTitle,
  };

  // ───────────────────────────── Helpers ─────────────────────────────

  int _stepSec(WorkoutStep s, Sport sport) {
    if (s.durationSec != null) return s.durationSec!;
    final d = s.distanceM ?? 0;
    if (sport == Sport.swim) return (d / 100 * (s.paceMax ?? sz.css + 12)).round() + 10;
    return (d / 1000 * ((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) / 2).round();
  }

  /// Shortens a structured workout to [capSec]: first warm-up/cool-down (to 60 %),
  /// then whole repeats from the end of the main set (≥ 2 left), then everything
  /// proportionally.
  List<WorkoutStep> _fitToTime(List<WorkoutStep> steps, int capSec, Sport sport) {
    int total(List<WorkoutStep> list) => list.fold(0, (x, s) => x + _stepSec(s, sport));
    WorkoutStep scaled(WorkoutStep s, double f) => WorkoutStep(
      kind: s.kind,
      durationSec: s.durationSec == null ? null : max(30, (s.durationSec! * f / 30).round() * 30),
      distanceM: s.distanceM == null ? null : max(100.0, (s.distanceM! * f / 100).round() * 100.0),
      zone: s.zone,
      paceMin: s.paceMin,
      paceMax: s.paceMax,
      powerMin: s.powerMin,
      powerMax: s.powerMax,
      hrMin: s.hrMin,
      hrMax: s.hrMax,
      note: s.note,
    );

    var list = [...steps];
    if (total(list) <= capSec) return list;
    list = [for (final s in list) s.kind == 'warmup' || s.kind == 'cooldown' ? scaled(s, 0.6) : s];
    while (total(list) > capSec && list.where((s) => s.isWork).length > 2) {
      final lastWork = list.lastIndexWhere((s) => s.isWork);
      list.removeAt(lastWork);
      if (lastWork - 1 >= 0 && list[lastWork - 1].kind == 'recovery') list.removeAt(lastWork - 1);
    }
    final t = total(list);
    if (t > capSec) list = [for (final s in list) scaled(s, capSec / t)];
    return list;
  }

  PlannedWorkout _plan(
    DateTime day,
    Sport sport,
    String title,
    String desc,
    String intensity,
    List<WorkoutStep> steps,
    String phase,
    bool isKey,
  ) {
    var sec = 0;
    var meters = 0.0;
    for (final s in steps) {
      sec += _stepSec(s, sport);
      if (s.distanceM != null) {
        meters += s.distanceM!;
      } else if (s.durationSec != null) {
        if (sport == Sport.run && s.zone != 'walk') {
          meters += s.durationSec! / ((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) * 2 * 1000;
        }
        if (sport == Sport.ride) meters += s.durationSec! / 3600 * (s.zone == 'Z1' ? 20 : 27) * 1000;
      }
    }
    return PlannedWorkout(
      id: _id(),
      date: day,
      sport: sport,
      title: title,
      description: desc,
      durationMin: max(15, (sec / 60 / 5).round() * 5),
      distanceKm: meters <= 0 ? null : double.parse((meters / 1000).toStringAsFixed(1)),
      intensity: intensity,
      steps: steps,
      phase: phase,
      isKey: isKey,
    );
  }
}

class _Slot {
  _Slot(this.sport, this.role);
  final Sport sport;
  String role;
}

/// Rotates through a split's programs; can postpone leg-heavy ones by a session.
class _GymQueue {
  _GymQueue(this.rotation);
  final List<String> rotation;
  final _pending = <String>[];
  var _i = 0;

  String next({Set<String> avoid = const {}}) {
    final p = _pending.where((k) => !avoid.contains(k)).firstOrNull;
    if (p != null) {
      _pending.remove(p);
      return p;
    }
    for (var tries = 0; tries < rotation.length; tries++) {
      final k = rotation[_i++ % rotation.length];
      if (!avoid.contains(k)) return k;
      _pending.add(k);
    }
    return _pending.isNotEmpty ? _pending.removeAt(0) : rotation[_i++ % rotation.length];
  }
}
