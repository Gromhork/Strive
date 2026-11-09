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
/// * Every session fits the time the athlete has on that day; recovery / taper weeks
///   also shrink that time, so time-limited sessions deload too.
/// * Race day is placed on the event date with a shake-out run the day before.
/// * Athlete traits: beginners keep ≥ 2 rest days (H7) and ≤ 4 runs; quick-setup
///   beginners without running experience start with run/walk (also returning runners
///   with BMI ≥ 30 or age ≥ 65, from 3 × 5 min); masters (≥ 50) get 3:1 cycles
///   (≥ 65: 2:1), slower growth and no consecutive key days.
class PlanGenerator {
  PlanGenerator(this.l, this.profile, this.templates, String Function() newId) : _id = newId;
  final AppLocalizations l;
  final UserProfile profile;
  final List<WorkoutTemplate> templates;
  final String Function() _id;

  AthleteData get a => profile.athlete;
  String get level => profile.level;
  bool get beginner => level == 'beginner';

  // ── athlete traits ──
  // Masters athletes recover more slowly from hard sessions and loading blocks
  // (spec §1.9: age ≥ 50 → 3:1, 2:1 when EASY; masters coaching commonly uses 2:1 or
  // 3:1 blocks and ≥ 48–72 h between hard days). Novice runners with BMI > 30 have a
  // higher injury risk (Nielsen 2013, n = 930) and more injuries when they start with
  // > 3 km in week 1 (Nielsen 2014) → run/walk start and slower run progression.
  int get _age => profile.age ?? 30;
  bool get _masters => _age >= 50;
  bool get _senior => _age >= 65;
  bool get _heavy => profile.bmi >= 30;

  // ── difficulty parameters (§8) ──
  double get _growth {
    final g = switch (a.difficulty) {
      'easy' => 0.05,
      'challenging' => 0.10,
      _ => 0.08,
    };
    return _senior ? min(g, 0.05) : (_masters ? min(g, 0.08) : g);
  }

  /// Weekly growth of the run volume: impact load is what injures, so heavy novices
  /// and seniors grow at the EASY rate (H8: add volume via bike/swim first).
  double get _runGrowth => (beginner && _heavy) || _senior ? min(_growth, 0.05) : _growth;

  int get _loadWeeks {
    final n = switch (a.difficulty) {
      'easy' => 2,
      'challenging' => level == 'advanced' ? 4 : 3,
      _ => 3,
    };
    return _senior ? 2 : (_masters ? min(n, 3) : n);
  }

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

  /// Couch-to-5K style run/walk progression (index into the run/walk table of
  /// [_runWalk]) the plan starts with, or null for continuous running.
  ///
  /// * The athlete said they cannot run 30 min (advanced setup).
  /// * Quick setup does not ask: beginners without running experience start at
  ///   week 1; returning runners with BMI ≥ 30 or age ≥ 65 start at 3 × 5 min, since
  ///   impact tolerance (bone, tendon) adapts slower than the cardiovascular system.
  static int? runWalkStartFor(UserProfile p) {
    final a = p.athlete;
    final beginner = p.level == 'beginner';
    if (!a.canRun30 && (beginner || a.raceTimes.isEmpty)) return 0;
    if (!beginner || a.advanced || a.raceTimes.isNotEmpty) return null;
    if (!p.experience.contains(Sport.run)) return 0;
    if (p.bmi >= 30 || (p.age ?? 30) >= 65) return 4;
    return null;
  }

  // Taper length (incl. race week): marathon 2–3 weeks, 70.3 ~2 weeks (10–14 days),
  // shorter races 1–2 (Bosquet 2007: 8–14 days; Mujika & Padilla 2003).
  int get _taperWeeks => switch (a.eventDistance) {
    'm' => beginner ? 2 : 3,
    '70.3' => 2,
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
    final runKm = _curve(total, phases, _runStartKm(runPerWeek), _runCeilingKm(runPerWeek), growth: _runGrowth);
    final rideH = _curve(total, phases, _rideStartH(ridePerWeek), _rideCeilingH(ridePerWeek));
    final swimKm = _curve(total, phases, _swimStartKm(swimPerWeek), _swimCeilingKm(swimPerWeek));
    // Long-run share: 1 run/week → the whole volume, 2 → ~55 %, otherwise 27–32 % (Daniels).
    double baseShare(double wk) => runPerWeek <= 1 ? 1.0 : (runPerWeek == 2 ? 0.55 : (wk < 40 ? 0.32 : 0.27));
    // Half / full marathon: the long run must approach race-specific length (HM ~16–21 km,
    // marathon ~30–35 km), which at amateur volumes needs 35–45 % of the weekly km
    // (Higdon / Pfitzinger / Hanson plans). R1 (+≤ 10 % per week) and the time cap of
    // [_run] still apply.
    double longShare(double wk) => switch (a.eventDistance) {
      'hm' when runPerWeek >= 3 => max(baseShare(wk), wk < 50 ? 0.40 : 0.32),
      'm' when runPerWeek >= 3 => max(baseShare(wk), wk < 70 ? 0.42 : 0.33),
      _ => baseShare(wk),
    };
    final longMaxKm = switch (a.eventDistance) {
      'hm' => 21.0,
      'm' => 35.0,
      _ => double.infinity,
    };
    var longestRun = a.longestRunKm ?? max(3.0, runKm.first * baseShare(runKm.first));
    var tempoMin = beginner ? 12 : (level == 'advanced' ? 20 : 15);
    var intervalReps = beginner ? 4 : (level == 'advanced' ? 6 : 5);
    final gymQueue = _GymQueue(_gymRotation(schedule));
    // Run/walk: one stage per loading week (recovery weeks repeat the last stage), until
    // 30 min continuous running is reached; then continuous runs take over.
    var runWalkStage = runWalkStartFor(profile);
    var lastLongKm = 0.0; // actual long run of the last loading week
    var loadWeeks = 0; // loading weeks so far (progression of quality sessions)
    var block = 0; // loading weeks since the last recovery week (strength RIR wave)

    for (var w = 0; w < total; w++) {
      final phase = phases[w];
      final roles = _roles(schedule, phase);
      final weekStart = monday.add(Duration(days: w * 7));
      final rest = phase == 'recovery' || phase == 'taper';
      // Recovery / taper weeks shrink the time available as well: sessions that are
      // limited by the athlete's time (not by the volume curve) would otherwise stay
      // as long as in a loading week, and the deload or taper would not happen.
      final restF = rest ? _restFactor(phases, w) : 1.0;
      final runWalk = runWalkStage != null && runWalkStage < _runWalkTable.length;
      final rwStage = runWalk ? (rest ? max(0, runWalkStage - 1) : runWalkStage) : 0;
      if (runWalk) {
        // R1 after run/walk: the first long runs build on the longest continuous block.
        longestRun = max(3.0, _r1(_runWalkTable[rwStage].$1 / pz.easySlow));
        lastLongKm = longestRun;
      }

      // Long run respects the 30-day max rule (R1) and 25–30 % of weekly km.
      final wk = runKm[w];
      final r1Cap = longestRun * (rest ? 0.75 : _longCap);
      var longKm = min(min(wk * longShare(wk), longMaxKm), r1Cap);
      if (rest && lastLongKm > 0) longKm = min(longKm, lastLongKm * 0.8);
      if (!rest && !runWalk) longestRun = max(longestRun, longKm);

      // Pass 1: everything except easy runs. Pass 2: easy runs share the remaining
      // weekly volume but stay clearly shorter than the long run.
      final week = <PlannedWorkout>[];
      final easyRuns = <(DateTime, int)>[];
      (DateTime, int)? longCtx;
      final qualityCtx = <(int, DateTime, String, int)>[]; // index in week, day, role, cap
      for (final entry in roles.entries) {
        final day = weekStart.add(Duration(days: entry.key - 1));
        if (day.isBefore(dayOnly(start))) continue;
        final n = entry.value.length;
        for (final r in entry.value) {
          final full = _capMinutes(entry.key, n);
          final cap = r.sport == Sport.gym ? full : max(20, (full * restF).round());
          if (r.sport == Sport.run) {
            if (runWalk) {
              week.add(_runWalk(day, rwStage, phase));
              continue;
            }
            if (r.role == 'easy') {
              easyRuns.add((day, cap));
              continue;
            }
            if (r.role == 'long') longCtx = (day, cap);
            if (r.role.startsWith('q')) qualityCtx.add((week.length, day, r.role, cap));
          }
          week.add(switch (r.sport) {
            Sport.run => _run(day, r.role, phase, wk, longKm, tempoMin, intervalReps, w, cap),
            Sport.ride => _ride(day, r.role, phase, rideH[w], ridePerWeek, loadWeeks, cap),
            Sport.swim => _swim(day, r.role, phase, swimKm[w], swimPerWeek, w, cap),
            Sport.gym => _gym(day, gymQueue, schedule, phase, block, r.role, cap),
          });
        }
      }
      // The long run must stay the longest run of the week: a tempo / interval
      // session with warm-up and cool-down can otherwise match a short long run.
      if (longCtx != null) {
        final li = week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'long');
        final others = week
            .where((p) => p.sport == Sport.run && p.intensity != 'long')
            .fold<double>(0, (x, p) => max(x, p.distanceKm ?? 0));
        if (li >= 0 && others > 0 && (week[li].distanceKm ?? 0) < others * 1.15) {
          // Never beyond R1 – if that is not enough, the quality run is shortened below.
          final target = min(_r1(others * 1.2), max(longKm, r1Cap));
          final longer = _run(longCtx.$1, 'long', phase, wk, max(longKm, target), tempoMin, intervalReps, w, longCtx.$2);
          if ((longer.distanceKm ?? 0) > (week[li].distanceKm ?? 0)) week[li] = longer;
        }
        // A long run limited by R1 or by the time that day cannot grow: shorten the quality run
        // (fewer repeats, shorter warm-up) instead.
        final longDist = li >= 0 ? (week[li].distanceKm ?? 0) : 0.0;
        for (final (i, day, role, cap) in qualityCtx) {
          for (var t = 0; t < 3 && (week[i].distanceKm ?? 0) * 1.15 > longDist && longDist > 0; t++) {
            final d = week[i].distanceKm ?? 0;
            final shorter = _run(day, role, phase, wk, longKm, tempoMin, intervalReps, w, max(20, (cap * longDist / (d * 1.2)).floor()));
            if ((shorter.distanceKm ?? 0) >= d) break;
            week[i] = shorter;
          }
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
      final longRun = week.where((p) => p.sport == Sport.run && p.intensity == 'long').firstOrNull;
      if (!rest && longRun != null) lastLongKm = longRun.distanceKm ?? lastLongKm;
      if (phase == 'recovery') block = 0;
      if (!rest) {
        loadWeeks++;
        block++;
        if (runWalk) runWalkStage = runWalkStage + 1;
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

  /// Most training days a week for [p] (quick setup; an explicit day plan is kept as is).
  ///
  /// Beginners keep ≥ 2 rest days (H7, see [ScheduleAdvisor.maxDays]); pure strength
  /// beginners train ≤ 4×/week (full body 2–3× is the evidence-based dose, §2.2);
  /// athletes ≥ 60 keep one rest day (masters need longer recovery between loads).
  static int maxTrainingDays(UserProfile p) => p.maxPlanDays;

  /// Most runs a week: beginners 4 (3 while still on run/walk – Couch-to-5K is 3×/week
  /// with a rest day in between, §1.10).
  static int maxRuns(UserProfile p) => p.level != 'beginner' ? 7 : (runWalkStartFor(p) != null ? 3 : 4);

  /// Picks [n] of [days]: the long day first, then always the day farthest (cyclic)
  /// from the days already kept, so rest days are spread over the week.
  static List<int> _spreadDays(List<int> days, int n, int longDay) {
    if (days.length <= n) return days;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    final kept = <int>[days.contains(longDay) ? longDay : days.last];
    while (kept.length < n) {
      int? best;
      var bestScore = -1;
      for (final d in days.where((d) => !kept.contains(d))) {
        final score = kept.map((k) => dist(k, d)).reduce(min) * 10 + kept.fold<int>(0, (x, k) => x + dist(k, d));
        if (score > bestScore) {
          bestScore = score;
          best = d;
        }
      }
      kept.add(best!);
    }
    return kept..sort();
  }

  /// Sessions per sport for a multi-sport week of [n] days (one session a day).
  ///
  /// Triathlon follows §6.2 (time split swim ~20 %, bike ~45–50 %, run ~30–35 %):
  /// 3 days one of each, 4 days + a second ride, 5 days + a second run, 6 days 2/2/2,
  /// 7 days + a third ride. With only 2 days the swim is dropped for bike + run unless
  /// the athlete cannot swim 400 m yet. Duathlon / hybrid: the main sport (run) gets the
  /// extra session; hybrid keeps strength at ≤ 3×/week.
  static Map<Sport, int> _multiCounts(UserProfile p, int n) => switch (p.focus) {
    TrainingFocus.triathlon => switch (n) {
      <= 1 => {Sport.ride: 1},
      2 => p.athlete.canSwim400 ? {Sport.ride: 1, Sport.run: 1} : {Sport.swim: 1, Sport.ride: 1},
      3 => {Sport.swim: 1, Sport.ride: 1, Sport.run: 1},
      4 => {Sport.swim: 1, Sport.ride: 2, Sport.run: 1},
      5 => {Sport.swim: 1, Sport.ride: 2, Sport.run: 2},
      6 => {Sport.swim: 2, Sport.ride: 2, Sport.run: 2},
      _ => {Sport.swim: 2, Sport.ride: 3, Sport.run: 2},
    },
    TrainingFocus.hybrid => {Sport.run: n - min(3, n ~/ 2), if (n >= 2) Sport.gym: min(3, n ~/ 2)},
    _ => {Sport.run: (n + 1) ~/ 2, if (n >= 2) Sport.ride: n ~/ 2},
  };

  /// Default weekday → sport mapping from training days and focus.
  static Map<int, List<Sport>> deriveSchedule(UserProfile profile) {
    var days = (profile.trainingDays.isEmpty ? [1, 3, 5] : [...profile.trainingDays])..sort();
    final longDay = profile.longDay != null && days.contains(profile.longDay) ? profile.longDay! : days.last;
    final base = profile.focus.sports;
    final res = <int, List<Sport>>{};
    days = _spreadDays(days, maxTrainingDays(profile), longDay);
    if (base.length == 1) {
      if (base.first == Sport.run) days = _spreadDays(days, maxRuns(profile), longDay);
      for (final d in days) {
        res[d] = [base.first];
      }
      return res;
    }
    // Multi-sport: sessions per sport from [_multiCounts], then the arrangement with the
    // fewest conflicts: the main endurance sport on the long day, the same sport not on
    // consecutive days (the week wraps Sunday → Monday) and no strength session the day
    // before the long session (C3). All distinct orders are tried (≤ 210 for 7 days).
    final main = profile.focus == TrainingFocus.hybrid || profile.focus == TrainingFocus.duathlon ? Sport.run : Sport.ride;
    final counts = _multiCounts(profile, days.length);
    final pool = [for (final s in base) ...List.filled(counts[s] ?? 0, s)];
    bool adjacent(int x, int y) => (x - y).abs() == 1 || (x - y).abs() == 6;
    int score(List<Sport> seq) {
      var s = 0;
      for (var i = 0; i < seq.length; i++) {
        if (days[i] == longDay && seq[i] != main && pool.contains(main)) s += 100;
        for (var j = i + 1; j < seq.length; j++) {
          if (seq[i] == seq[j] && adjacent(days[i], days[j])) s += seq[i] == Sport.gym ? 4 : 10;
        }
        if (seq[i] == Sport.gym && days[i] % 7 + 1 == longDay) s += 8;
      }
      return s;
    }

    List<Sport>? best;
    var bestScore = 1 << 30;
    void permute(List<Sport> seq, Map<Sport, int> left) {
      if (seq.length == pool.length) {
        final sc = score(seq);
        if (sc < bestScore) {
          bestScore = sc;
          best = [...seq];
        }
        return;
      }
      for (final s in base) {
        if ((left[s] ?? 0) == 0) continue;
        left[s] = left[s]! - 1;
        seq.add(s);
        permute(seq, left);
        seq.removeLast();
        left[s] = left[s]! + 1;
      }
    }

    permute([], {...counts});
    for (var i = 0; i < days.length && i < best!.length; i++) {
      res[days[i]] = [best![i]];
    }
    return res;
  }

  List<String> _phases(int total) {
    // Short plans keep most weeks for loading: the taper is at most a third of the plan
    // (a 5-week 70.3 plan gets 1 taper week, not 3 out of 5).
    final taper = weeksToEvent != null ? min(_taperWeeks, min(max(0, total - 2), max(1, total ~/ 3))) : 0;
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
  List<double> _curve(int total, List<String> phases, double startV, double ceiling, {double? growth}) {
    final out = <double>[];
    var last = startV;
    for (var i = 0; i < total; i++) {
      final p = phases[i];
      if (p == 'recovery' || p == 'taper') {
        out.add(last * _restFactor(phases, i));
      } else {
        if (i > 0) last = min(ceiling, last * (1 + (growth ?? _growth)));
        out.add(last);
      }
    }
    return out;
  }

  /// Volume of a recovery / taper week relative to the last loading week: recovery
  /// 60–75 % by difficulty, taper progressive (3 weeks 80/65/45 %, 2 weeks 70/50 %,
  /// 1 week 55 %; Bosquet 2007: −41–60 % works best).
  double _restFactor(List<String> phases, int i) {
    if (phases[i] == 'recovery') return _recoveryFactor;
    if (phases[i] != 'taper') return 1;
    final k = i - phases.indexOf('taper');
    final nTaper = phases.where((x) => x == 'taper').length;
    return nTaper >= 3 ? const [0.8, 0.65, 0.45][min(k, 2)] : (nTaper == 2 ? const [0.7, 0.5][min(k, 1)] : 0.55);
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

  int get _lv => switch (level) {
    'advanced' => 2,
    'intermediate' => 1,
    _ => 0,
  };

  /// Volume ceiling (R5, table 1.8) from a (novice, intermediate, advanced) [table] for
  /// the goal; without a goal [start] × [noGoal]. CHALLENGING +15 %, EASY uses the
  /// novice column; never below the athlete's current volume.
  double _ceiling(List<double> table, double start, double noGoal) {
    var c = table.isEmpty ? start * noGoal : max(table[_lv], start);
    if (a.difficulty == 'challenging') c *= 1.15;
    if (a.difficulty == 'easy' && table.isNotEmpty) c = max(table[0], start);
    return max(c, start);
  }

  // Triathlon volume ceilings per discipline (weekly run km / bike hours / swim km).
  // Typical age-group plans: sprint ~4–7 h, olympic ~6–10 h, 70.3 ~8–13 h a week, split
  // swim ~20 % · bike ~45–50 % · run ~30–35 % (§6.2). Without them the bike and swim
  // volume stayed at the start value × 1.5 – e.g. a 60-min long ride for an olympic
  // distance whose bike leg alone takes ~80 min.

  double _runCeilingKm(int perWeek) => _ceiling(
    switch (a.eventDistance) {
      '5k' => const [15.0, 30.0, 50.0],
      '10k' => const [25.0, 40.0, 60.0],
      'hm' => const [30.0, 50.0, 70.0],
      'm' => const [45.0, 65.0, 90.0],
      'sprint' => const [12.0, 20.0, 30.0],
      'olympic' => const [18.0, 28.0, 40.0],
      '70.3' => const [25.0, 35.0, 50.0],
      _ => const <double>[],
    },
    _runStartKm(perWeek),
    1.35,
  );

  double _rideCeilingH(int perWeek) => _ceiling(
    switch (a.eventDistance) {
      'sprint' => const [2.5, 3.5, 4.5],
      'olympic' => const [3.5, 4.5, 6.0],
      '70.3' => const [5.0, 6.5, 8.0],
      _ => const <double>[],
    },
    _rideStartH(perWeek),
    1.5,
  );

  double _swimCeilingKm(int perWeek) => _ceiling(
    switch (a.eventDistance) {
      'sprint' => const [3.0, 5.0, 7.0],
      'olympic' => const [4.0, 6.0, 8.0],
      '70.3' => const [5.0, 7.0, 9.0],
      _ => const <double>[],
    },
    _swimStartKm(perWeek),
    1.4,
  );

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
    // Recovery / taper: one shortened quality session with ≥ 3 runs – beginners only
    // run easy in recovery weeks.
    if (phase == 'recovery' && beginner) return 0;
    if (phase == 'recovery' || phase == 'taper') return nRuns >= 3 ? 1 : 0;
    // Keep ≥ 75 % of runs easy: ≤ 4 runs → 1 quality session (2 when challenging).
    var q = nRuns <= 4 ? 1 : 2;
    if (nRuns >= 3 && nRuns <= 4 && a.difficulty == 'challenging' && level != 'beginner') q = 2;
    if (nRuns >= 6 && level == 'advanced' && phase == 'build') q = 3;
    if (a.difficulty == 'easy') q = min(q, 1);
    if (nRuns <= 1) q = 0;
    return q;
  }

  /// Quality rides besides the long ride: like running (≥ 75–80 % of sessions easy):
  /// 2–3 rides → 1, ≥ 4 → 2 (3 rides → 2 only for non-beginners on CHALLENGING);
  /// recovery / taper weeks keep one with ≥ 3 rides.
  int _maxQualityRides(int nRides, String phase) {
    if (phase == 'recovery' || phase == 'taper') return nRides >= 3 ? 1 : 0;
    var q = nRides >= 4 ? 2 : (nRides >= 2 ? 1 : 0);
    if (nRides == 3 && a.difficulty == 'challenging' && !beginner) q = 2;
    if (a.difficulty == 'easy' || beginner) q = min(q, 1);
    return q;
  }

  /// Assigns roles (long / q1 / q2 / easy / …) per sport, spacing key sessions.
  Map<int, List<_Slot>> _roles(Map<int, List<Sport>> schedule, String phase) {
    final days = schedule.keys.toList()..sort();
    final roles = {for (final d in days) d: schedule[d]!.map((s) => _Slot(s, 'easy')).toList()};
    final keyDays = <int>{};
    final longDay = profile.longDay ?? days.last;

    // The week wraps around: Sunday's long run is followed by Monday.
    int prev(int d) => d == 1 ? 7 : d - 1;
    int next(int d) => d == 7 ? 1 : d + 1;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());

    bool spaced(int d) {
      if (keyDays.contains(d)) return false;
      // Beginners, intermediates and masters (≥ 50: ≥ 48 h between hard days): never
      // two key days in a row.
      if (beginner || level == 'intermediate' || _masters) {
        return !keyDays.contains(prev(d)) && !keyDays.contains(next(d));
      }
      // Advanced athletes may train hard on two consecutive days, never three (H1).
      final p1 = keyDays.contains(prev(d)), n1 = keyDays.contains(next(d));
      return !(p1 && n1) && !(p1 && keyDays.contains(prev(prev(d)))) && !(n1 && keyDays.contains(next(next(d))));
    }

    // Long sessions first (they matter most), the sport on the long day first; quality
    // sessions then have to keep their distance from all of them.
    final longs = <Sport, int>{};
    bool onLongDay(Sport s) => schedule[longDay]?.contains(s) ?? false;
    for (final sport in [Sport.run, Sport.ride]..sort((x, y) => (onLongDay(y) ? 1 : 0).compareTo(onLongDay(x) ? 1 : 0))) {
      final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
      if (sDays.isEmpty) continue;
      // Preferred long day, else the latest free day. Two long sessions of different
      // sports may follow each other (long ride Saturday, long run Sunday – both easy);
      // beginners and masters keep them apart when the week allows it.
      int latestFree() => sDays.lastWhere((d) => !keyDays.contains(d), orElse: () => sDays.last);
      final ld =
          sDays.contains(longDay) && !keyDays.contains(longDay)
              ? longDay
              : (beginner || _masters ? sDays.lastWhere(spaced, orElse: latestFree) : latestFree());
      roles[ld]!.firstWhere((x) => x.sport == sport).role = 'long';
      keyDays.add(ld);
      longs[sport] = ld;
    }
    for (final sport in [Sport.run, Sport.ride, Sport.swim]) {
      final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
      if (sDays.isEmpty) continue;
      final ld = longs[sport]; // no long swim
      final nQ = switch (sport) {
        Sport.run => _maxQualityRuns(sDays.length, phase),
        Sport.ride => _maxQualityRides(sDays.length, phase),
        // Beginners: technique + easy endurance only (no CSS sets yet).
        Sport.swim => sDays.length >= 2 && !beginner ? 1 : 0,
        Sport.gym => 0,
      };
      var q = 0;
      // Prefer days far from the long day (cyclic: Monday is next to Sunday).
      final cand = [...sDays.where((d) => d != ld)]..sort((x, y) => dist(y, ld ?? 7).compareTo(dist(x, ld ?? 7)));
      for (final d in cand) {
        if (q >= nQ) break;
        // Swimming is non-weight-bearing: a CSS set may follow or precede a hard run /
        // ride day (only never two key sessions on the same day).
        if (sport == Sport.swim ? keyDays.contains(d) : !spaced(d)) continue;
        // Never the day right before the long run (H5), nor right after the long session.
        if (ld != null && d == prev(ld) && sport == Sport.run) continue;
        if (ld != null && d == next(ld) && sDays.length > 2) continue;
        roles[d]!.firstWhere((x) => x.sport == sport).role = 'q${q + 1}';
        keyDays.add(d);
        q++;
      }
      // Swim: one technique session a week – the first swim without a quality role
      // (with 1–2 swims only if there is no quality session at all).
      if (sport == Sport.swim) {
        final slots = [for (final d in sDays) roles[d]!.firstWhere((x) => x.sport == sport)];
        final hasQ = slots.any((x) => x.role.startsWith('q'));
        final free = slots.where((x) => x.role == 'easy').firstOrNull;
        if (free != null && (!hasQ || sDays.length >= 3)) free.role = 'technique';
      }
    }
    // Gym: sessions the day before a key endurance session avoid heavy legs (C3).
    for (final d in days) {
      for (final s in roles[d]!) {
        if (s.sport == Sport.gym && keyDays.contains(next(d))) s.role = 'nolegs';
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
      // No HR target for walks and short recovery jogs: heart rate lags far behind there.
      hrMin: zone == 'walk' || zone == 'REC' ? null : hr.$1,
      hrMax: zone == 'walk' || zone == 'REC' ? null : hr.$2,
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
      // Fit into the time available that day and ≤ 150 min (marathon, advanced: 180;
      // Daniels §1.4) – longer runs add injury risk faster than aerobic benefit.
      final maxMin = min(capMin, dist == 'm' && level == 'advanced' ? 180 : 150);
      final km = max(4.0, _r1(min(longKm, maxMin * 60 / pz.easySlow)));
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
        final reps = phase == 'taper' || phase == 'recovery' ? 4 : (beginner ? 5 + min(3, week ~/ 3) : 6 + week % 3);
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
        if (i < reps - 1) steps.add(_runStep('recovery', 'REC', sec: max(60, (repSec * 0.8 / 15).round() * 15)));
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
  /// Couch-to-5K style run/walk stages: (run s, walk s, repeats), one stage per week
  /// (§1.10), ending with 30 min continuous running. Whole minutes only, so the title
  /// ("8 × 1 min") always matches the steps.
  static const _runWalkTable = [
    (60, 90, 8),
    (60, 60, 10),
    (120, 120, 5),
    (180, 90, 5),
    (300, 180, 3),
    (480, 300, 2),
    (600, 120, 2),
    (720, 120, 2),
    (1200, 0, 1),
    (1500, 0, 1),
    (1800, 0, 1),
  ];

  /// Run/walk session of [stage] (beginners who cannot run 30 min yet).
  PlannedWorkout _runWalk(DateTime day, int stage, String phase) {
    final t = _runWalkTable[min(stage, _runWalkTable.length - 1)];
    final steps = <WorkoutStep>[_runStep('warmup', 'walk', sec: 300, note: l.stepBriskWalk)];
    for (var i = 0; i < t.$3; i++) {
      steps.add(_runStep('work', 'E', sec: t.$1, note: l.stepTalkPace));
      if (t.$2 > 0 && i < t.$3 - 1) steps.add(_runStep('recovery', 'walk', sec: t.$2));
    }
    steps.add(_runStep('cooldown', 'walk', sec: 300));
    return _plan(day, Sport.run, l.wRunWalk(t.$3, t.$1 ~/ 60), l.wRunWalkDesc, 'easy', steps, phase, false);
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

  /// Long ride ≈ 42 % of the weekly hours, at least 60 min (45 min in recovery / taper
  /// weeks, so the deload still shows when the volume is small).
  int _longRideMin(double weekH, {bool rest = false}) => max(rest ? 45 : 60, ((weekH * 0.42) * 60 / 15).round() * 15);

  /// [loadWeek] counts the loading weeks so far: quality rides progress only in those.
  PlannedWorkout _ride(DateTime day, String role, String phase, double weekH, int perWeek, int loadWeek, int capMin) {
    final rest = phase == 'recovery' || phase == 'taper';
    final wu = _rideStep('warmup', 'Z2', 600);
    final cd = _rideStep('cooldown', 'Z1', 600);
    String title, desc, intensity = 'easy';
    List<WorkoutStep> steps;
    var isKey = false;
    if (role == 'long') {
      steps = [_rideStep('steady', 'Z2', min(capMin, _longRideMin(weekH, rest: rest)) * 60, note: l.stepZ2RideNote)];
      title = l.planLongRide;
      desc = l.wLongRideDesc;
      intensity = 'long';
      isKey = true;
    } else if (role.startsWith('q')) {
      isKey = true;
      final vo2 = role == 'q2' || (phase == 'peak' && perWeek < 3);
      if (vo2 && phase != 'base') {
        final reps = rest ? 3 : 4 + min(2, loadWeek ~/ 3);
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
        // 24 → 60 min of work over the loading weeks (beginners 15 → 40, keeping the
        // hard share of their 2–3 rides near 20 %); recovery / taper weeks ~70 %.
        final total = (min(beginner ? 40 : 60, (beginner ? 15 : 24) + loadWeek * 4) * (rest ? 0.7 : 1.0)).round();
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
      final longMin = _longRideMin(weekH, rest: rest);
      final nQ = _maxQualityRides(perWeek, phase);
      final easyCount = max(1, perWeek - 1 - nQ);
      final left = weekH * 60 - longMin - nQ * 65;
      final floor = rest ? 30 : 40;
      final easyMin = ((left / easyCount).clamp(floor, max(floor, longMin * 0.75)) / 5).round() * 5;
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
    var total = max(beginner ? 600.0 : 1000.0, (min(weekKm * 1000 / max(1, perWeek), maxM) / 100).round() * 100.0);
    // Short repeats with long rests (beginners: 50 m + 30 s) take longer than the rough
    // estimate above: shrink until the session really fits the time available.
    var w = _swimSession(day, role, phase, total, week);
    for (var i = 0; i < 4 && w.durationMin > capMin + 5 && total > (beginner ? 600 : 1000); i++) {
      total = max(beginner ? 600.0 : 1000.0, (total * capMin / w.durationMin / 100).floor() * 100.0);
      w = _swimSession(day, role, phase, total, week);
    }
    return w;
  }

  PlannedWorkout _swimSession(DateTime day, String role, String phase, double total, int week) {
    final wu = _swimStep('warmup', 'REC', (total * 0.18 / 50).round() * 50.0, note: l.stepSwimWu);
    final cd = _swimStep('cooldown', 'REC', max(100.0, (total * 0.1 / 50).round() * 50.0));
    String title, desc, intensity;
    final steps = <WorkoutStep>[wu];
    var isKey = false;
    if (role == 'q1' && !beginner) {
      // CSS set (~50 % of the session). Repeats get longer through the season:
      // base 100 m (15 s rest) → build 200 m (20 s) → peak 300 m (30 s);
      // recovery / taper weeks go back to short 100s.
      final (rep, rest) = switch (phase) {
        'build' => (200.0, 20),
        'peak' => (300.0, 30),
        _ => (100.0, 15),
      };
      final n = max(rep >= 300 ? 3 : (rep >= 200 ? 4 : 6), ((total * 0.5) / rep).round());
      steps.add(_swimStep('work', 'DR', 200, note: _drillNote(week)));
      steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      for (var i = 0; i < n; i++) {
        steps.add(_swimStep('work', 'CSS', rep, note: l.stepCssNote));
        if (i < n - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: rest, zone: 'REC'));
      }
      title = l.wSwimCssSet(n, rep.round());
      desc = l.wSwimCssDesc;
      intensity = 'intervals';
      isKey = true;
    } else if (role == 'technique' || (beginner && role.startsWith('q'))) {
      steps.add(_swimStep('work', 'DR', (total * (beginner ? 0.3 : 0.2) / 50).round() * 50.0, note: _drillNote(week)));
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
      // Beginners build continuous swimming: 50s → 100s → 200s over the first weeks.
      final rep = beginner ? (week < 3 ? 50.0 : (week < 6 ? 100.0 : 200.0)) : (main >= 1200 ? 400.0 : 200.0);
      final reps = max(2, (main / rep).round());
      for (var i = 0; i < reps; i++) {
        steps.add(_swimStep('work', 'EN', rep, note: l.stepSwimEnNote));
        if (i < reps - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: beginner ? 30 : 20, zone: 'REC'));
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

  /// [block] counts the loading weeks since the last deload: the RIR wave 3 → 2 → 1
  /// restarts after every deload instead of drifting against it.
  PlannedWorkout _gym(DateTime day, _GymQueue queue, Map<int, List<Sport>> schedule, String phase, int block, String role, int capMin) {
    final endurance = schedule.values.expand((e) => e).any((s) => s != Sport.gym);
    // C3: no heavy legs the day before a key endurance session.
    final key = queue.next(avoid: role == 'nolegs' ? legHeavyKeys : const {});
    final t = _template(key);
    final name = t?.name ?? _builtinName(key);
    final deload = phase == 'recovery' || phase == 'taper';
    final rir = deload ? 4 : const [3, 2, 1][min(block, 2)];
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
    final meters = Vdot.distances[a.eventDistance];
    final km = meters == null ? null : meters / 1000;
    final vdot = Vdot.of(a);
    final goal = a.targetTimeSec ?? (!tri && meters != null && vdot != null ? Vdot.raceTime(vdot, meters) : null);
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
    final legs = switch (a.eventDistance) {
      'sprint' => l.wTriLegs('0.75', '20', '5'),
      'olympic' => l.wTriLegs('1.5', '40', '10'),
      '70.3' => l.wTriLegs('1.9', '90', '21.1'),
      _ => null,
    };
    out.add(
      PlannedWorkout(
        id: _id(),
        date: race,
        sport: tri ? Sport.swim : Sport.run,
        title: l.wRace(_eventName()),
        description: [if (tri && legs != null) legs, goal == null ? l.wRaceDesc : l.wRaceGoalDesc(clock(goal))].join('\n'),
        durationMin: ((goal ?? _expectedRaceSec(meters, tri)) / 60).round(),
        // A triathlon is stored as a swim (it starts with one), so it carries no single
        // distance – "Swim 51.5 km" would be wrong; the legs are in the description.
        distanceKm: tri ? null : km,
        intensity: 'race',
        steps: steps,
        phase: 'taper',
        isKey: true,
      ),
    );
  }

  /// Expected finishing time (s) when no goal is set, so the race shows a realistic
  /// duration (a marathon is not "60 min"): running from VDOT (or the level default);
  /// triathlon from CSS + 10 s/100 m (open water), a level-typical bike speed, the run
  /// 8 % slower off the bike, plus transitions.
  int _expectedRaceSec(double? meters, bool tri) {
    final vdot = Vdot.of(a) ?? Vdot.defaultFor(level);
    if (!tri) return meters == null ? 3600 : Vdot.raceTime(vdot, meters);
    final (swimM, bikeKm, runM, transition) = switch (a.eventDistance) {
      'sprint' => (750.0, 20.0, 5000.0, 300),
      'olympic' => (1500.0, 40.0, 10000.0, 360),
      _ => (1900.0, 90.0, 21097.5, 480),
    };
    final kmh = switch (level) {
      'advanced' => 33.0,
      'intermediate' => 29.0,
      _ => 25.0,
    };
    return (swimM / 100 * (sz.css + 10) + bikeKm / kmh * 3600 + Vdot.raceTime(vdot, runM) * 1.08 + transition).round();
  }

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

  int _stepSec(WorkoutStep s, Sport sport) => estimateStepSec(s, sport, easyPace: pz.easySlow, css: sz.css);

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
