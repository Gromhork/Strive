import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
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
///   run ≤ +10 % of the 30-day max (Frandsen 2025), long run ≤ 30 % of weekly km,
///   per-session caps for T/I/R volume.
/// * Cycling: Coggan zones from FTP, pyramidal/80-20 by weekly hours.
/// * Swimming: CSS zones, warm-up/drills/main/cool-down structure.
/// * Strength: split by frequency (each muscle ≥ 2×/week, Schoenfeld 2016),
///   RIR wave 3→2→1 then deload (sets × 0.5), rep ranges by goal.
/// * Concurrent: no heavy legs the day before a key endurance session (C3),
///   max one key session per day, no back-to-back key days for beginners (H1).
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

  /// Number of weeks until (and including) race week, if an event is set.
  int? get weeksToEvent {
    final d = a.eventDate;
    if (d == null) return null;
    final w = (startOfWeek(d).difference(startOfWeek(DateTime.now())).inDays / 7).floor() + 1;
    return w >= 2 && w <= 30 ? w : null;
  }

  int get _taperWeeks => switch (a.eventDistance) {
    'm' || '70.3' => beginner ? 2 : 3,
    'hm' || 'olympic' => 2,
    '5k' || '10k' || 'sprint' => 1,
    _ => 0,
  };

  List<PlannedWorkout> generate({required DateTime start, int? weeks}) {
    final total = weeksToEvent ?? weeks ?? a.planWeeks;
    final schedule = _weekSchedule();
    final phases = _phases(total);
    final out = <PlannedWorkout>[];
    final monday = startOfWeek(start);

    // Weekly volume curves.
    final runPerWeek = schedule.values.expand((e) => e).where((s) => s == Sport.run).length;
    final ridePerWeek = schedule.values.expand((e) => e).where((s) => s == Sport.ride).length;
    final swimPerWeek = schedule.values.expand((e) => e).where((s) => s == Sport.swim).length;
    final runKm = _curve(total, phases, _runStartKm(runPerWeek), _runCeilingKm(runPerWeek));
    final rideH = _curve(total, phases, _rideStartH(ridePerWeek), _rideStartH(ridePerWeek) * 1.5);
    final swimKm = _curve(total, phases, _swimStartKm(swimPerWeek), _swimStartKm(swimPerWeek) * 1.4);
    // Long-run share: 1 run/week → the whole volume, 2 → ~55 %, otherwise 27–32 % (Daniels).
    double longShare(double wk) => runPerWeek <= 1 ? 1.0 : (runPerWeek == 2 ? 0.55 : (wk < 40 ? 0.32 : 0.27));
    var longestRun = a.longestRunKm ?? max(3.0, runKm.first * longShare(runKm.first));
    var tempoMin = beginner ? 12 : (level == 'advanced' ? 20 : 15);
    var intervalReps = beginner ? 4 : (level == 'advanced' ? 6 : 5);
    var gymIndex = 0;
    var runWalkWeek = 0;

    for (var w = 0; w < total; w++) {
      final phase = phases[w];
      final roles = _roles(schedule, phase);
      final weekStart = monday.add(Duration(days: w * 7));
      final rest = phase == 'recovery' || phase == 'taper';

      // Long run respects the 30-day max rule (R1) and 25–30 % of weekly km.
      final wk = runKm[w];
      var longKm = min(wk * longShare(wk), longestRun * (rest ? 0.75 : _longCap));
      if (!rest) longestRun = max(longestRun, longKm);
      final ql = roles.values.expand((e) => e).where((r) => r.sport == Sport.run && r.role.startsWith('q')).length;
      final easyCount = max(1, runPerWeek - ql - (roles.values.expand((e) => e).any((r) => r.role == 'long' && r.sport == Sport.run) ? 1 : 0));

      for (final entry in roles.entries) {
        final day = weekStart.add(Duration(days: entry.key - 1));
        if (day.isBefore(dayOnly(start))) continue;
        for (final r in entry.value) {
          final p = switch (r.sport) {
            Sport.run =>
              !a.canRun30 && (beginner || a.raceTimes.isEmpty) && runWalkWeek < 18
                  ? _runWalk(day, runWalkWeek++ ~/ max(1, runPerWeek), phase)
                  : _run(day, r.role, phase, wk, longKm, easyCount, tempoMin, intervalReps, w),
            Sport.ride => _ride(day, r.role, phase, rideH[w], ridePerWeek, w),
            Sport.swim => _swim(day, r.role, phase, swimKm[w], swimPerWeek, w),
            Sport.gym => _gym(day, gymIndex++, schedule, phase, w, r.role),
          };
          out.add(p);
        }
      }
      if (!rest) {
        tempoMin = min(tempoMin + (a.difficulty == 'easy' ? 2 : 4), 30);
        if (w.isOdd) intervalReps = min(intervalReps + 1, level == 'advanced' ? 8 : 6);
      }
    }
    return out;
  }

  // ───────────────────────────── Structure ─────────────────────────────

  /// weekday → sports. Advanced setup provides it directly; otherwise derive it.
  Map<int, List<Sport>> _weekSchedule() {
    if (a.dayPlan.values.any((v) => v.isNotEmpty)) {
      return {for (final e in a.dayPlan.entries) if (e.value.isNotEmpty) e.key: e.value};
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
    for (var i = 0; i < total; i++) {
      final p = phases[i];
      if (p == 'recovery') {
        out.add(last * _recoveryFactor);
      } else if (p == 'taper') {
        final k = i - taperIdx;
        final n = phases.where((x) => x == 'taper').length;
        final f = n >= 3 ? const [0.8, 0.65, 0.45][k] : (n == 2 ? const [0.7, 0.5][k] : 0.55);
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
      // Long session: preferred long day, else the latest day.
      final hasLong = sDays.length >= 2 || sport != Sport.gym;
      int? ld;
      if (hasLong && sport != Sport.swim) {
        ld = sDays.contains(longDay) && !keyDays.contains(longDay) ? longDay : sDays.lastWhere((d) => !keyDays.contains(d), orElse: () => sDays.last);
        roles[ld]!.firstWhere((x) => x.sport == sport).role = 'long';
        keyDays.add(ld);
      }
      final nQ = switch (sport) {
        Sport.run => _maxQualityRuns(sDays.length, phase),
        Sport.ride => phase == 'recovery' || phase == 'taper' ? (sDays.length >= 3 ? 1 : 0) : (sDays.length >= 3 ? 2 : (sDays.length == 2 ? 1 : 0)),
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
    // Gym: mark sessions the day before a key endurance session as "upper" (C3).
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

  PlannedWorkout _run(DateTime day, String role, String phase, double weekKm, double longKm, int easyCount, int tempoMin,
      int intervalReps, int week) {
    final dist = a.eventDistance;
    final wu = _runStep('warmup', 'E', km: beginner ? 1.5 : 2, note: l.stepWarmupNote);
    final cd = _runStep('cooldown', 'E', km: beginner ? 1 : 1.5);
    String title, desc, intensity = 'easy';
    var steps = <WorkoutStep>[];
    var isKey = false;

    if (role == 'long') {
      final km = max(4.0, _r1(longKm));
      isKey = true;
      intensity = 'long';
      // Marathon / HM peak: last 25 % at goal pace (M).
      if (phase == 'peak' && (dist == 'm' || dist == 'hm') && !beginner) {
        final mpKm = _r1(km * 0.25);
        steps = [_runStep('steady', 'L', km: km - mpKm), _runStep('work', 'M', km: mpKm, note: l.stepMpNote)];
        title = l.wLongRunMp;
        desc = l.wLongRunMpDesc;
      } else {
        steps = [_runStep('steady', 'L', km: km, note: l.stepEasyNote)];
        title = l.planLongRun;
        desc = l.wLongRunDesc;
      }
    } else if (role.startsWith('q')) {
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
    } else {
      // Easy run fills the remaining volume; some get strides (base/build).
      final km = max(3.0, _r1((weekKm - longKm) / max(1, easyCount + 0.6)));
      steps = [_runStep('steady', 'E', km: km, note: l.stepEasyNote)];
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
    }
    return _plan(day, Sport.run, title, desc, intensity, steps, phase, isKey);
  }

  /// Couch-to-5K style run/walk progression (beginners who cannot run 30 min).
  PlannedWorkout _runWalk(DateTime day, int week, String phase) {
    const table = [(60, 90, 8), (90, 120, 6), (120, 120, 5), (180, 90, 5), (300, 180, 3), (480, 300, 2), (600, 120, 2), (900, 120, 2), (1200, 0, 1), (1500, 0, 1), (1800, 0, 1)];
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

  PlannedWorkout _ride(DateTime day, String role, String phase, double weekH, int perWeek, int week) {
    final wu = _rideStep('warmup', 'Z2', 600);
    final cd = _rideStep('cooldown', 'Z1', 600);
    String title, desc, intensity = 'easy';
    List<WorkoutStep> steps;
    var isKey = false;
    if (role == 'long') {
      final min_ = max(60, ((weekH * 0.42) * 60 / 15).round() * 15);
      steps = [_rideStep('steady', 'Z2', min_ * 60, note: l.stepZ2RideNote)];
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
        title = l.wRideVo2(reps.toInt(), dur ~/ 60);
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
        title = ss ? l.wSweetSpot(reps, each) : l.wThreshold(reps, each);
        desc = ss ? l.wSweetSpotDesc : l.wThresholdDesc;
        intensity = 'tempo';
      }
    } else {
      final easyMin = max(40, (weekH * 60 * 0.58 / max(1, perWeek - 1) / 5).round() * 5);
      steps = [_rideStep('steady', 'Z2', min(easyMin, a.sessionMinutes + 15) * 60, note: l.stepZ2RideNote)];
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

  PlannedWorkout _swim(DateTime day, String role, String phase, double weekKm, int perWeek, int week) {
    final total = max(beginner ? 600.0 : 1000.0, (weekKm * 1000 / max(1, perWeek) / 100).round() * 100.0);
    final wu = _swimStep('warmup', 'REC', (total * 0.18 / 50).round() * 50.0, note: l.stepSwimWu);
    final cd = _swimStep('cooldown', 'REC', max(100.0, (total * 0.1 / 50).round() * 50.0));
    String title, desc, intensity;
    final steps = <WorkoutStep>[wu];
    var isKey = false;
    if (role == 'q1' && !beginner) {
      // CSS set: n × 100 m @ CSS, 15 s rest.
      final n = max(6, ((total * 0.55) / 100).round());
      steps.add(_swimStep('work', 'DR', 200, note: l.stepDrills));
      for (var i = 0; i < n; i++) {
        steps.add(_swimStep('work', 'CSS', 100, note: l.stepCssNote));
        if (i < n - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'));
      }
      title = l.wSwimCss(n);
      desc = l.wSwimCssDesc;
      intensity = 'intervals';
      isKey = true;
    } else if (role == 'technique' || beginner) {
      steps.add(_swimStep('work', 'DR', (total * (beginner ? 0.35 : 0.2) / 50).round() * 50.0, note: l.stepDrills));
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
        steps.add(_swimStep('work', role == 'long' ? 'EN' : 'TE', rep, note: l.stepSwimEnNote));
        if (i < reps - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: 20, zone: 'REC'));
      }
      title = l.wSwimEndurance(reps, rep.round());
      desc = l.wSwimEnduranceDesc;
      intensity = role == 'long' ? 'long' : 'moderate';
    }
    steps.add(cd);
    return _plan(day, Sport.swim, title, desc, intensity, steps, phase, isKey);
  }

  // ───────────────────────────── Strength ─────────────────────────────

  PlannedWorkout _gym(DateTime day, int index, Map<int, List<Sport>> schedule, String phase, int week, String role) {
    final perWeek = schedule.values.expand((e) => e).where((s) => s == Sport.gym).length;
    final endurance = schedule.values.expand((e) => e).any((s) => s != Sport.gym);
    var names =
        perWeek <= 3
            ? ['Full Body A', 'Full Body B']
            : perWeek == 4
            ? ['Upper', 'Lower']
            : perWeek == 5
            ? ['Upper', 'Lower', 'Push', 'Pull', 'Legs']
            : ['Push', 'Pull', 'Legs'];
    var name = names[index % names.length];
    // C3: no heavy legs the day before a key endurance session.
    if (role == 'nolegs' && (name == 'Lower' || name == 'Legs')) name = perWeek >= 4 ? 'Upper' : name;
    final t = templates.where((t) => t.name == name).firstOrNull;
    final deload = phase == 'recovery' || phase == 'taper';
    final rir = deload ? 4 : [3, 2, 1][week % 3];
    final (lo, hi) = switch (a.gymGoal) {
      'strength' => (4, 6),
      'hypertrophy' => (8, 12),
      _ => endurance ? (5, 8) : (6, 10),
    };
    final sets = deload ? 2 : (a.difficulty == 'easy' ? 3 : (a.difficulty == 'challenging' && level != 'beginner' ? 4 : 3));
    final desc = deload ? l.wGymDeloadDesc(sets) : l.wGymDesc(sets, lo, hi, rir);
    return PlannedWorkout(
      id: _id(),
      date: day,
      sport: Sport.gym,
      title: name,
      description: desc + (endurance && role == 'nolegs' ? '\n${l.wGymConcurrentNote}' : ''),
      durationMin: t?.estimatedMinutes ?? min(75, a.sessionMinutes),
      templateId: t?.id,
      intensity: deload ? 'easy' : 'moderate',
      phase: phase,
    );
  }

  // ───────────────────────────── Helpers ─────────────────────────────

  PlannedWorkout _plan(DateTime day, Sport sport, String title, String desc, String intensity, List<WorkoutStep> steps,
      String phase, bool isKey) {
    var sec = 0;
    var meters = 0.0;
    for (final s in steps) {
      if (s.durationSec != null) {
        sec += s.durationSec!;
        if (sport == Sport.run && s.zone != 'walk') meters += s.durationSec! / ((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) * 2 * 1000;
        if (sport == Sport.ride) meters += s.durationSec! / 3600 * (s.zone == 'Z1' ? 20 : 27) * 1000;
      } else if (s.distanceM != null) {
        meters += s.distanceM!;
        final pace = sport == Sport.swim
            ? ((s.paceMax ?? sz.css + 12) / 100)
            : (((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) / 2000);
        sec += (s.distanceM! * pace).round();
        if (sport == Sport.swim) sec += 10; // wall time
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
