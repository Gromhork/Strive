import 'dart:math';
import 'dart:ui' show Locale;

import '../core/format.dart';
import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'exercise_class.dart';
import 'goal_model.dart';
import 'health_limits.dart';
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
/// * Concurrent: no heavy legs the day before a key endurance session (C3; full-body
///   programs keep half their leg sets), max one key session per day, no back-to-back key
///   days for beginners (H1), one hard budget across sports (H2), no two key runs / rides
///   within 48 h (H3).
/// * Triathlon: bricks (run off the bike) from the build phase (§6.3); 70.3 ≥ 2 swims.
/// * Goal feasibility (§1.8): [feasibility] says when the event goal is not realistic –
///   incl. the target time (§1.12, [GoalModel]): race-pace work in the peak phase uses the
///   target pace only when it is realistic, all other paces the current VDOT.
/// * With an event the plan runs to race day (≤ 52 weeks; more than 30 weeks away: a base
///   "pre-plan" block before the race-specific 30 weeks).
/// * Every session fits the time the athlete has on that day; recovery / taper weeks
///   also shrink that time, so time-limited sessions deload too.
/// * Race day is placed on the event date with a shake-out run the day before.
/// * Athlete traits: beginners keep ≥ 2 rest days (H7) and ≤ 4 runs; quick-setup
///   beginners without running experience start with run/walk (also returning runners
///   with BMI ≥ 30 or age ≥ 65, from 3 × 5 min); masters (≥ 50) get 3:1 cycles
///   (≥ 65: 2:1), slower growth and no consecutive key days.
/// * Health limitations ([HealthFlags], §9.1): knee / hip / ankle → less running impact
///   (slower growth, no strides / VO2max reps, one easy run → easy ride); shoulder → swim
///   technique instead of CSS sets, less swim volume; heart / blood pressure → intensity
///   capped at threshold; back / shoulder / heart → notes on the strength sessions.
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
  late final HealthFlags hf = HealthFlags.of(profile);

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
  double get _runGrowth => (beginner && _heavy) || _senior || hf.lowImpactRun ? min(_growth, 0.05) : _growth;

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
  double get _longCap => a.difficulty == 'easy' || hf.lowImpactRun ? 1.05 : 1.10;

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
    final w = GoalModel.weeksUntil(d, _start);
    return w >= 2 && w <= GoalModel.maxEventWeeks ? w : null;
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
    // Beginners with knee / hip / ankle problems: run/walk lets tendons and joints adapt.
    if (beginner && a.raceTimes.isEmpty && HealthFlags.of(p).lowImpactRun) return p.experience.contains(Sport.run) ? 4 : 0;
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

  /// Run/walk stage still planned in race week (null: continuous running by then).
  int? _rwAtRace;

  /// Target-time check of this plan ([GoalModel.check]); decides the race-pace work.
  TargetCheck? _target;

  /// Longest long run / long ride the time on its day allows (km / min), see [feasibility].
  double _longRunLimitKm = 0;
  int _longRideLimitMin = 0;

  bool get _tri => const {'sprint', 'olympic', '70.3'}.contains(a.eventDistance);

  /// Easy pace (s/km) long runs are planned with: the middle of the E range – the same
  /// pace the session duration is estimated with (beginners without paces: the slow end).
  int get _longPace => beginner && a.raceTimes.isEmpty ? pz.easySlow : (pz.easyFast + pz.easySlow) ~/ 2;

  List<PlannedWorkout> generate({required DateTime start, int? weeks}) {
    _start = start;
    _target = GoalModel.check(profile, start: start);
    _rwAtRace = null;
    _longRunLimitKm = 0;
    _longRideLimitMin = 0;
    final total = weeksToEvent ?? weeks ?? a.planWeeks;
    final schedule = _weekSchedule();
    // Couch-to-5K has no recovery weeks: while a pure runner is still on run/walk (one
    // stage per week, every session easy), recovery weeks are not planned.
    final rwStart = runWalkStartFor(profile);
    final endurance = schedule.values.expand((e) => e).where((s) => s != Sport.gym).toSet();
    final noRecovery = rwStart != null && endurance.length == 1 && endurance.first == Sport.run ? _runWalkTable.length - rwStart : 0;
    final phases = _phases(total, noRecoveryBefore: noRecovery);
    final out = <PlannedWorkout>[];
    final monday = startOfWeek(start);

    // Weekly volume curves.
    final all = schedule.values.expand((e) => e);
    final runPerWeek = all.where((s) => s == Sport.run).length;
    final ridePerWeek = all.where((s) => s == Sport.ride).length;
    final swimPerWeek = all.where((s) => s == Sport.swim).length;
    // Knee / hip / ankle: ~10 % less running (impact), the cross-training ride makes up for it.
    final runKm = [
      for (final v in _curve(total, phases, _runStartKm(runPerWeek), _runCeilingKm(runPerWeek), growth: _runGrowth))
        hf.lowImpactRun ? v * 0.9 : v,
    ];
    final rideH = _curve(total, phases, _rideStartH(ridePerWeek), _rideCeilingH(ridePerWeek));
    final swimKm = _curve(total, phases, _swimStartKm(swimPerWeek), _swimCeilingKm(swimPerWeek));
    // Long-run share: 1 run/week → the whole volume, 2 → ~55 %, otherwise 27–32 % (Daniels).
    double baseShare(double wk) => runPerWeek <= 1 ? 1.0 : (runPerWeek == 2 ? 0.55 : (wk < 40 ? 0.32 : 0.27));
    // Half / full marathon: the long run must approach race-specific length (HM ~16–21 km,
    // marathon ~30–35 km), which at amateur volumes needs 35–45 % of the weekly km
    // (Higdon / Pfitzinger / Hanson plans). R1 (+≤ 10 % per week) and the time cap of
    // [_run] still apply.
    // At low amateur volumes the race-specific long run (HM ~15 km, marathon ~28–32 km)
    // needs up to half of the weekly km (Higdon / Hanson novice plans: 45–60 %).
    double longShare(double wk) => switch (a.eventDistance) {
      'hm' when runPerWeek >= 3 => max(baseShare(wk), max(wk < 50 ? 0.40 : 0.32, min(0.5, 15 / wk))),
      'm' when runPerWeek >= 3 => max(baseShare(wk), max(wk < 70 ? 0.42 : 0.33, min(0.55, 30 / wk))),
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
    var bricks = 0; // brick sessions so far (run off the bike grows with each)
    final brickRun = _tri && runPerWeek > 0;

    for (var w = 0; w < total; w++) {
      final phase = phases[w];
      final roles = _roles(schedule, phase, week: w);
      // Quality rides that really got a slot this week (spacing may leave fewer than allowed).
      final qRides = roles.values.expand((x) => x).where((r) => r.sport == Sport.ride && r.role.startsWith('q')).length;
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
        if (w == total - 1) _rwAtRace = rwStage;
      }
      // Brick (§6.3): a run off the bike after the long ride – from the build phase every
      // second loading week, weekly in the peak phase; not while still on run/walk.
      final brick = brickRun && !runWalk && (phase == 'peak' || (phase == 'build' && loadWeeks.isEven));

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
      var skippedRuns = 0; // run slots before the start day (plan starts mid-week)
      (DateTime, int)? longCtx;
      final qualityCtx = <(int, DateTime, String, int)>[]; // index in week, day, role, cap
      for (final entry in roles.entries) {
        final day = weekStart.add(Duration(days: entry.key - 1));
        if (day.isBefore(dayOnly(start))) {
          skippedRuns += entry.value.where((r) => r.sport == Sport.run).length;
          continue;
        }
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
          if (r.sport == Sport.ride && r.role == 'long' && brick) {
            // Run off the bike: sprint 15 → 20 min, olympic 15 → 30, 70.3 15 → 45 (advanced
            // 60), at most ~60 % of this week's long run; the ride keeps the rest of the day.
            final (b0, bMax) = switch (a.eventDistance) {
              'sprint' => (15, 20),
              'olympic' => (15, 30),
              _ => (15, level == 'advanced' ? 60 : 45),
            };
            final byLong = max(15, (longKm * 0.6 * _longPace / 60 / 5).floor() * 5);
            final bMin = min(min(bMax, b0 + bricks * 5), byLong);
            week.add(_ride(day, r.role, phase, rideH[w], ridePerWeek, loadWeeks, max(45, cap - bMin), qRides, dayCap: cap));
            week.add(_brickRun(day, phase, bMin));
            bricks++;
            continue;
          }
          week.add(switch (r.sport) {
            Sport.run => _run(day, r.role, phase, wk, longKm, tempoMin, intervalReps, w, cap),
            Sport.ride => _ride(day, r.role, phase, rideH[w], ridePerWeek, loadWeeks, cap, qRides),
            Sport.swim => _swim(day, r.role, phase, swimKm[w], swimPerWeek, w, cap),
            // Beginners: no planned strength deload in the first ~10 weeks (§2.7) – the
            // session keeps the loading phase it follows.
            Sport.gym => _gym(
              day,
              gymQueue,
              schedule,
              phase == 'recovery' && beginner && w < 10 ? _lastLoadPhase(phases, w) : phase,
              block,
              r.role,
              cap,
            ),
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
        // A plan that starts mid-week only has part of the week left: the runs before the
        // start day keep their share, so the remaining easy runs are not stuffed with
        // the whole weekly volume (which made the first week the hardest).
        final each = ((wk - used) / (easyRuns.length + skippedRuns)).clamp(3.0, capKm);
        for (final (day, cap) in easyRuns) {
          week.add(_easyRun(day, phase, each, w, cap));
        }
      }
      // Knee / hip / ankle: with ≥ 3 runs one easy run becomes an easy ride of the same
      // time – the aerobic stimulus stays, the impact goes (cross-training, H8).
      if (hf.lowImpactRun && !runWalk) {
        final runs = week.where((p) => p.sport == Sport.run).length;
        final i = week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'easy');
        if (runs >= 3 && i >= 0) week[i] = _crossRide(week[i].date, phase, week[i].durationMin);
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
    return hf.any ? [for (final w in out) _withHealthNotes(w)] : out;
  }

  /// Easy ride replacing a run (knee / hip / ankle limitation).
  PlannedWorkout _crossRide(DateTime day, String phase, int minutes) => _plan(
    day,
    Sport.ride,
    l.wCrossRide,
    l.wCrossRideDesc,
    'easy',
    [_rideStep('steady', 'Z2', max(20, minutes) * 60, note: l.stepZ2RideNote)],
    phase,
    false,
  );

  /// Adds the notes of the athlete's health limitations to [w]'s description (one line
  /// each, so they translate with the rest of the plan).
  PlannedWorkout _withHealthNotes(PlannedWorkout w) {
    final hard = w.intensity == 'tempo' || w.intensity == 'intervals';
    final notes = <String>[
      if (w.sport == Sport.run && hf.lowImpactRun && w.intensity != 'race') l.healthRunNote,
      if ((w.sport == Sport.run || w.sport == Sport.ride) && hf.capIntensity && hard) l.healthHeartNote,
      if (w.sport == Sport.swim && hf.avoidOverhead && w.intensity != 'race') l.healthSwimShoulderNote,
      if (w.sport == Sport.gym && hf.avoidAxialLoading) l.healthGymBackNote,
      if (w.sport == Sport.gym && hf.avoidOverhead) l.healthGymShoulderNote,
      if (w.sport == Sport.gym && hf.kneeOrHip) l.healthGymJointNote,
      if (w.sport == Sport.gym && hf.noStraining) l.healthGymHeartNote,
    ];
    if (notes.isEmpty) return w;
    return PlannedWorkout(
      id: w.id,
      date: w.date,
      sport: w.sport,
      title: w.title,
      description: [if (w.description.isNotEmpty) w.description, ...notes].join('\n'),
      durationMin: w.durationMin,
      distanceKm: w.distanceKm,
      intensity: w.intensity,
      templateId: w.templateId,
      status: w.status,
      sessionId: w.sessionId,
      steps: w.steps,
      phase: w.phase,
      isKey: w.isKey,
      exercises: w.exercises,
    );
  }

  // ───────────────────────────── Time available ─────────────────────────────

  /// Minutes for one session: the day's limit split between the sessions of that day.
  int _capMinutes(int weekday, int sessionsThatDay) {
    final day = dayMinutesFor(profile, weekday);
    return max(20, sessionsThatDay <= 1 ? day : (day / sessionsThatDay).round());
  }

  /// Time available on [weekday]: explicit per-day value, else the global maximum –
  /// on the long-session day at least [longDayDefault] unless that day was set explicitly.
  static int dayMinutesFor(UserProfile p, int weekday) {
    final a = p.athlete;
    final explicit = a.dayMinutes[weekday];
    if (explicit != null) return explicit;
    final longDay = longDayOf(p);
    if (weekday == longDay) return max(a.sessionMinutes, longDayDefault(p));
    final second = _secondLongDefault(p);
    if (second != null && longSessionDays(p).values.contains(weekday)) return max(a.sessionMinutes, second);
    return a.sessionMinutes;
  }

  /// Day of each sport's long session (run / ride): the sport on the long day gets it,
  /// the other one its latest still free day (masters: not next to the first one).
  static Map<Sport, int> longSessionDays(UserProfile p) => _longSessionDays(scheduleOf(p), longDayOf(p), (p.age ?? 30) >= 50);

  static Map<Sport, int> _longSessionDays(Map<int, List<Sport>> schedule, int? longDay, bool masters) {
    final days = schedule.keys.toList()..sort();
    final out = <Sport, int>{};
    if (days.isEmpty) return out;
    final ld0 = longDay ?? days.last;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    bool onLongDay(Sport s) => schedule[ld0]?.contains(s) ?? false;
    for (final sport in [Sport.run, Sport.ride]..sort((x, y) => (onLongDay(y) ? 1 : 0).compareTo(onLongDay(x) ? 1 : 0))) {
      final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
      if (sDays.isEmpty) continue;
      final taken = out.values.toSet();
      int latestFree() => sDays.lastWhere((d) => !taken.contains(d), orElse: () => sDays.last);
      out[sport] =
          sDays.contains(ld0) && !taken.contains(ld0)
              ? ld0
              : (masters
                  ? sDays.lastWhere((d) => !taken.contains(d) && taken.every((t) => dist(t, d) > 1), orElse: latestFree)
                  : latestFree());
    }
    return out;
  }

  /// Default time on the day of the triathlon long run (the long ride has the long day):
  /// 70.3 2 h, olympic 90 min – a 60 min cap kept the long run at ~9 km.
  static int? _secondLongDefault(UserProfile p) => switch (p.athlete.eventDistance) {
    '70.3' when p.focus == TrainingFocus.triathlon => 120,
    'olympic' when p.focus == TrainingFocus.triathlon => 90,
    _ => null,
  };

  /// Default time on the long-session day by goal: the race-specific long session must
  /// fit – marathon long run up to 3 h (~28–32 km), HM 2.5 h, olympic long ride 2.5 h,
  /// 70.3 long ride ≥ 3 h plus the run off the bike; otherwise 2 h.
  static int longDayDefault(UserProfile p) => switch (p.athlete.eventDistance) {
    'm' => 180,
    'hm' || 'olympic' => 150,
    '70.3' => 240,
    _ => 120,
  };

  /// The day of the long endurance session (null for gym-only plans).
  static int? longDayOf(UserProfile p) {
    final plan = scheduleOf(p);
    final endurance = plan.entries.where((e) => e.value.any((s) => s != Sport.gym)).map((e) => e.key).toList()..sort();
    if (endurance.isEmpty) return null;
    if (p.longDay != null && endurance.contains(p.longDay)) return p.longDay;
    return endurance.last;
  }

  // ───────────────────────────── Structure ─────────────────────────────

  /// weekday → sports. Advanced setup provides it directly; otherwise derive it.
  Map<int, List<Sport>> _weekSchedule() => scheduleOf(profile);

  /// The week the plan for [p] uses (weekday → sports): the detailed setup's day plan,
  /// else derived from the training days and focus ([deriveSchedule]).
  ///
  /// A day plan left over from an earlier detailed setup is ignored in the quick setup –
  /// otherwise the plan would silently use other days than the ones just chosen.
  static Map<int, List<Sport>> scheduleOf(UserProfile p) {
    final a = p.athlete;
    if (a.advanced && a.dayPlan.values.any((v) => v.isNotEmpty)) {
      return {
        for (final e in a.dayPlan.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      };
    }
    return deriveSchedule(p);
  }

  /// Strength sessions the quick setup adds for an endurance focus when the athlete also
  /// chose a strength / muscle goal (concurrent training: 1–2 sessions a week improve
  /// economy and lower injury risk, Blagrove 2018; §2.9). Endurance keeps priority:
  /// single sport 3–4 days → 1, ≥ 5 days → 2; duathlon / triathlon ≥ 5 days → 1.
  static int extraGymDays(UserProfile p, int days) {
    final strength = p.goals.contains('strength') || p.goals.contains('muscle');
    final sports = p.focus.sports;
    if (!strength || sports.contains(Sport.gym)) return 0;
    if (sports.length == 1) return days >= 5 ? 2 : (days >= 3 ? 1 : 0);
    return days >= 5 ? 1 : 0;
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
  static Map<Sport, int> _multiCounts(UserProfile p, int days) {
    final gym = extraGymDays(p, days);
    final n = days - gym;
    final counts = p.focus.sports.length == 1 ? {p.focus.sports.first: n} : _enduranceCounts(p, n);
    // Beginners: at most 4 runs (3 on run/walk) also when strength takes the other days.
    if (counts.containsKey(Sport.run) && p.focus == TrainingFocus.run) counts[Sport.run] = min(counts[Sport.run]!, maxRuns(p));
    return {...counts, if (gym > 0) Sport.gym: gym};
  }

  static Map<Sport, int> _enduranceCounts(UserProfile p, int n) => switch (p.focus) {
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
    final res = <int, List<Sport>>{};
    days = _spreadDays(days, maxTrainingDays(profile), longDay);
    final gym = extraGymDays(profile, days.length);
    final base = [...profile.focus.sports, if (gym > 0) Sport.gym];
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
    final main =
        profile.focus.sports.length == 1
            ? profile.focus.sports.first
            : (profile.focus == TrainingFocus.hybrid || profile.focus == TrainingFocus.duathlon ? Sport.run : Sport.ride);
    final counts = _multiCounts(profile, days.length);
    // Fewer sessions than days (e.g. a beginner's run cap): keep the best-spread days.
    days = _spreadDays(days, counts.values.fold<int>(0, (x, y) => x + y), longDay);
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
    // 70.3 with ≤ 5 days has a single swim – too little to build towards 1.9 km
    // continuous (§4.4: 2–3 swims a week). The second swim goes on an easy-session day
    // far from the first one (not the long day, not the day before it) as a double day.
    if (profile.focus == TrainingFocus.triathlon && profile.athlete.eventDistance == '70.3') {
      final swimDays = [
        for (final e in res.entries)
          if (e.value.contains(Sport.swim)) e.key,
      ];
      if (swimDays.length == 1 && res.length >= 4) {
        int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
        final cand =
            res.keys
                .where((d) => d != longDay && d % 7 + 1 != longDay && !res[d]!.contains(Sport.swim) && !res[d]!.contains(Sport.gym))
                .toList()
              ..sort((x, y) => dist(y, swimDays.first).compareTo(dist(x, swimDays.first)));
        if (cand.isNotEmpty) res[cand.first] = [Sport.swim, ...res[cand.first]!];
      }
    }
    return res;
  }

  /// Phases of the plan; no recovery week in the first [noRecoveryBefore] weeks (run/walk).
  List<String> _phases(int total, {int noRecoveryBefore = 0}) {
    // An event more than [GoalModel.specificWeeks] away: the weeks before the race-specific
    // plan are a base "pre-plan" block (easy volume, strides, recovery weeks) – build and peak
    // keep their usual length instead of stretching over a whole year.
    final pre = weeksToEvent != null ? max(0, total - GoalModel.specificWeeks) : 0;
    final spec = total - pre;
    // Short plans keep most weeks for loading: the taper is at most a third of the plan
    // (a 5-week 70.3 plan gets 1 taper week, not 3 out of 5).
    final taper = weeksToEvent != null ? min(_taperWeeks, min(max(0, spec - 2), max(1, spec ~/ 3))) : 0;
    final body = spec - taper;
    final base = max(1, (body * (beginner ? 0.5 : 0.42)).round());
    final peak = weeksToEvent != null ? max(1, (body * 0.18).round()) : 0;
    final build = max(0, body - base - peak);
    final out = <String>[
      ...List.filled(pre + base, 'base'),
      ...List.filled(build, 'build'),
      ...List.filled(peak, 'peak'),
      ...List.filled(taper, 'taper'),
    ];
    // Recovery weeks: after every N loading weeks (never in taper or the final week).
    var run = 0;
    for (var i = 0; i < out.length; i++) {
      if (out[i] == 'taper') break;
      if (i < noRecoveryBefore) continue;
      run++;
      if (run > _loadWeeks && i < out.length - 1 - taper) {
        out[i] = 'recovery';
        run = 0;
      }
    }
    return out;
  }

  String _lastLoadPhase(List<String> phases, int w) => phases.take(w).lastWhere((p) => p != 'recovery', orElse: () => 'base');

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

  /// Run volume ceiling; with a stated current volume also ≤ 1.5 × that volume (at least
  /// +10 km) – a 55 km runner should not be pushed to 100 km/week within one plan.
  double _runCeilingKm(int perWeek) {
    final start = _runStartKm(perWeek);
    final c = _ceiling(
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
      start,
      1.35,
    );
    final stated = a.runWeeklyKm != null && a.runWeeklyKm! > 0;
    return stated ? max(start, min(c, max(start * 1.5, start + 10))) : c;
  }

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
    // Joint problems or a heart / blood-pressure condition: at most one quality run.
    if (hf.lowImpactRun || hf.capIntensity) q = min(q, 1);
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
    if (a.difficulty == 'easy' || beginner || hf.capIntensity) q = min(q, 1);
    return q;
  }

  /// Assigns roles (long / q1 / q2 / technique / easy / nolegs) and spaces the key sessions.
  ///
  /// * H1: never three key days in a row; beginners, intermediates and masters never two
  ///   (a CSS swim set – non-weight-bearing, half a hard session – may sit next to one
  ///   key day, except for masters).
  /// * H3: advanced athletes may go hard on consecutive days only across systems, never
  ///   two key runs (or two key rides) within 48 h.
  /// * H2 (≥ 2 endurance sports): one hard budget across sports – ≤ 4 sessions: 2 · 5–7: 3 ·
  ///   more: 4 points; a quality run / ride costs 1, a long session or a CSS set 0.5. The
  ///   base phase keeps 1 (beginners) or 2 quality sessions.
  Map<int, List<_Slot>> _roles(Map<int, List<Sport>> schedule, String phase, {int week = 0}) {
    final days = schedule.keys.toList()..sort();
    final roles = {for (final d in days) d: schedule[d]!.map((s) => _Slot(s, 'easy')).toList()};
    final key = <int, Sport>{}; // day → sport of its key session
    // Same long day as [deriveSchedule] / [dayMinutesFor] – a stale profile value (a day
    // that is no longer a training day) must not decide the roles.
    final longDay = longDayOf(profile) ?? days.last;

    // The week wraps around: Sunday's long run is followed by Monday.
    int prev(int d) => d == 1 ? 7 : d - 1;
    int next(int d) => d == 7 ? 1 : d + 1;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    final strict = beginner || level == 'intermediate' || _masters;
    final longDays = <int>{};

    bool spaced(int d, Sport sport, Map<int, Sport> k, {bool half = false}) {
      if (k.containsKey(d)) return false;
      final p1 = k.containsKey(prev(d)), n1 = k.containsKey(next(d));
      if ((p1 && n1) || (p1 && k.containsKey(prev(prev(d)))) || (n1 && k.containsKey(next(next(d))))) return false;
      // Masters: a CSS set only next to a long (Z2) session, never next to a quality one.
      if (half) return !_masters || (!(p1 && !longDays.contains(prev(d))) && !(n1 && !longDays.contains(next(d))));
      if (strict) return !(p1 || n1);
      return k[prev(d)] != sport && k[next(d)] != sport;
    }

    // Long sessions first (they matter most), the sport on the long day first; quality
    // sessions then have to keep their distance from all of them.
    // Preferred long day, else the latest free day. Two long sessions of different sports
    // may follow each other (long ride Saturday, long run Sunday – both easy); masters keep
    // them apart when the week allows it. Shared with [dayMinutesFor] ([longSessionDays]).
    final longs = _longSessionDays(schedule, longDay, _masters);
    longDays.addAll(longs.values);
    for (final e in longs.entries) {
      roles[e.value]!.firstWhere((x) => x.sport == e.key).role = 'long';
      key[e.value] = e.key;
    }

    final endurance = schedule.values.expand((v) => v).where((s) => s != Sport.gym).toList();
    final multi = endurance.toSet().length >= 2;
    final n = endurance.length;
    final budget = multi ? (n <= 4 ? 2.0 : (n <= 7 ? 3.0 : 4.0)) : double.infinity;

    // Quality days per sport when the sports are filled in [order].
    Map<Sport, List<int>> place(List<Sport> order) {
      final k = {...key};
      var used = multi ? longs.length * 0.5 : 0.0;
      var qualityLeft = multi && phase == 'base' ? (beginner ? 1 : 2) : 99;
      final out = <Sport, List<int>>{};
      for (final sport in order) {
        final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
        if (sDays.isEmpty) continue;
        final ld = longs[sport]; // no long swim
        final css = sport == Sport.swim;
        final cost = css ? 0.5 : 1.0;
        var nQ = switch (sport) {
          Sport.run => _maxQualityRuns(sDays.length, phase),
          Sport.ride => _maxQualityRides(sDays.length, phase),
          // Beginners: technique + easy endurance only (no CSS sets yet); shoulder: no CSS.
          Sport.swim => sDays.length >= 2 && !beginner && !hf.avoidOverhead ? 1 : 0,
          Sport.gym => 0,
        };
        if (multi) nQ = min(nQ, min(qualityLeft, ((budget - used) / cost + 1e-9).floor()));
        // Candidates: not the long day; never the day right before the long run (H5), nor
        // right after the long session (with > 2 sessions of that sport).
        final cand = [
          for (final d in sDays)
            if (d != ld && !(ld != null && d == prev(ld) && sport == Sport.run) && !(ld != null && d == next(ld) && sDays.length > 2)) d,
        ];
        // The largest set of days that keeps the spacing; ties: far from the long day and on
        // days without a second session (a double day halves the time of each).
        var best = <int>[];
        var bestScore = -1;
        int score(List<int> pick) => pick.fold(0, (x, d) => x + dist(d, ld ?? longDay) * 10 - (schedule[d]!.length > 1 ? 15 : 0));
        void search(int i, List<int> pick, Map<int, Sport> kk) {
          if (pick.length > best.length || (pick.length == best.length && score(pick) > bestScore)) {
            best = pick;
            bestScore = score(pick);
          }
          if (pick.length >= nQ) return;
          for (var j = i; j < cand.length; j++) {
            if (!spaced(cand[j], sport, kk, half: css)) continue;
            search(j + 1, [...pick, cand[j]], {...kk, cand[j]: sport});
          }
        }

        if (nQ > 0) search(0, const [], k);
        out[sport] = [...best]..sort((x, y) => dist(y, ld ?? longDay).compareTo(dist(x, ld ?? longDay)));
        for (final d in best) {
          k[d] = sport;
        }
        used += best.length * cost;
        qualityLeft -= best.length;
      }
      return out;
    }

    // Multi-sport priority: the bike (largest share, no impact) first; in the base phase the
    // CSS set before run quality, later run quality before the CSS set. Another order wins
    // only if it fits more quality sessions into the week.
    final preferred =
        !multi
            ? [Sport.run, Sport.ride, Sport.swim]
            : (phase == 'base' || phase == 'recovery' ? [Sport.ride, Sport.swim, Sport.run] : [Sport.ride, Sport.run, Sport.swim]);
    var picks = place(preferred);
    int count(Map<Sport, List<int>> m) => m.values.fold(0, (x, v) => x + v.length);
    if (multi) {
      for (final o in [
        for (final a in preferred)
          for (final b in preferred)
            for (final c in preferred)
              if (a != b && b != c && a != c) [a, b, c],
      ]) {
        final alt = place(o);
        if (count(alt) > count(picks)) picks = alt;
      }
    }
    for (final e in picks.entries) {
      for (final (i, d) in e.value.indexed) {
        roles[d]!.firstWhere((x) => x.sport == e.key).role = 'q${i + 1}';
        key[d] = e.key;
      }
    }
    // Swim: one technique session a week – the first swim without a quality role (with 1–2
    // swims only if there is no quality session at all). A single weekly swim alternates
    // technique and continuous endurance swimming.
    final swimDays = days.where((d) => schedule[d]!.contains(Sport.swim)).toList();
    if (swimDays.isNotEmpty) {
      final slots = [for (final d in swimDays) roles[d]!.firstWhere((x) => x.sport == Sport.swim)];
      final hasQ = slots.any((x) => x.role.startsWith('q'));
      final free = slots.where((x) => x.role == 'easy').firstOrNull;
      if (free != null && (!hasQ || swimDays.length >= 3) && (swimDays.length >= 2 || week.isEven)) free.role = 'technique';
    }
    // Gym: sessions the day before a key endurance session avoid heavy legs (C3).
    for (final d in days) {
      for (final s in roles[d]!) {
        if (s.sport == Sport.gym && key.containsKey(next(d))) s.role = 'nolegs';
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
      // Fit into the time available that day and ≤ 150 min (marathon: 180 – the 28–32 km
      // long runs of amateur marathon plans take ~3 h; Daniels §1.4 allows 180 for
      // advanced) – longer runs add injury risk faster than aerobic benefit. Planned at
      // the middle of the easy range (the slow end made the long run ~5 % too short).
      final maxMin = min(capMin, dist == 'm' && !beginner ? 180 : 150);
      if (phase != 'recovery' && phase != 'taper') _longRunLimitKm = max(_longRunLimitKm, maxMin * 60 / _longPace);
      final km = max(4.0, _r1(min(longKm, maxMin * 60 / _longPace)));
      isKey = true;
      intensity = 'long';
      // Marathon / HM peak: last 25 % at goal pace (M).
      if (phase == 'peak' && (dist == 'm' || dist == 'hm') && !beginner) {
        final mpKm = _r1(km * 0.25);
        // Half marathon: the goal-pace segment runs at HM pace (between M and T), not at
        // marathon pace.
        final hm = dist == 'hm';
        final work = hm ? _runStep('work', 'M', km: mpKm, note: l.stepHmpNote) : _mpStep(mpKm);
        final hmPace = hm ? _goalPace() : null;
        steps = [
          _runStep('steady', 'E', km: km - mpKm, note: l.stepEasyNote),
          hmPace == null
              ? work
              : WorkoutStep(
                kind: 'work',
                distanceM: work.distanceM,
                zone: 'M',
                paceMin: hmPace - 3,
                paceMax: hmPace + 3,
                hrMin: hz.zone(3).$1,
                hrMax: hz.zone(4).$2,
                note: work.note,
              ),
        ];
        title = l.wLongRunMp;
        desc = hm ? l.wLongRunHmpDesc : l.wLongRunMpDesc2;
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
    // VO2max reps load joints and heart the most: threshold work instead with limitations.
    final useIntervals = (phase == 'build' || phase == 'peak') && level != 'beginner' && !hf.noHardRunning;
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
          steps.add(_runStep('work', hf.noHardRunning ? 'T' : 'I', sec: beginner ? 45 : 60, note: l.stepFartlekNote));
          steps.add(_runStep('recovery', 'REC', sec: 90));
        }
        steps.add(cd);
        title = l.wFartlek;
        desc = l.wFartlekDesc;
        intensity = 'tempo';
      }
    } else if (phase == 'peak' && dist == 'm' && second) {
      final mp = _r1(min(weekKm * 0.2, 14));
      steps = [wu, _mpStep(mp), cd];
      title = l.wMpRun;
      desc = l.wMpRunDesc;
      intensity = 'tempo';
    } else if (useIntervals && (second ? !shortRace : shortRace)) {
      // VO2max intervals (I), volume ≤ min(8 % weekly km, 10 km).
      // Short sessions: when fewer than 3 long repeats fit the time, use shorter repeats
      // (600 / 400 m, more of them) instead of 2 × 800 m.
      List<WorkoutStep> build(double repM, int reps) {
        final maxReps = max(3, (min(weekKm * 0.08, 10) * 1000 / repM).floor());
        final n = min(reps, maxReps);
        final repSec = (repM / 1000 * pz.interval).round();
        return [
          wu,
          for (var i = 0; i < n; i++) ...[
            _runStep('work', 'I', km: repM / 1000, note: l.stepIntervalNote),
            if (i < n - 1) _runStep('recovery', 'REC', sec: max(60, (repSec * 0.8 / 15).round() * 15)),
          ],
          cd,
        ];
      }

      final repM = level == 'advanced' ? 1000.0 : 800.0;
      steps = build(repM, intervalReps);
      for (final shorter in [600.0, 400.0]) {
        if (_fitToTime(steps, capMin * 60, Sport.run).where((s) => s.isWork).length >= 3) break;
        steps = build(shorter, (intervalReps * repM / shorter).round());
      }
      title = l.wIntervals(steps.where((s) => s.isWork).length, (repM).round());
      desc = l.wIntervalsDesc;
      intensity = 'intervals';
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
    if ((phase == 'base' || phase == 'build') && !beginner && !hf.noHardRunning && day.weekday.isEven) {
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

  /// Race-day run/walk rhythm from the last stage: the stage's run blocks (1–10 min),
  /// with 1 min walk breaks.
  static int _raceRunMin(int stage) => (_runWalkTable[min(stage, _runWalkTable.length - 1)].$1 ~/ 60).clamp(1, 10);

  /// Run off the bike (brick, §6.3): the first 5 min easy to find the rhythm, then at
  /// steady race feel. Part of the long-ride day's key session, not an extra key session.
  PlannedWorkout _brickRun(DateTime day, String phase, int minutes) => _plan(
    day,
    Sport.run,
    l.wBrickRun(minutes),
    l.wBrickRunDesc,
    'moderate',
    [
      _runStep('steady', 'E', sec: min<int>(5, minutes ~/ 2) * 60, note: l.stepBrickStartNote),
      _runStep('work', 'M', sec: (minutes - min<int>(5, minutes ~/ 2)) * 60, note: l.stepBrickNote),
    ],
    phase,
    false,
  );

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

  /// Long ride: with 2 rides a week ~60 % of the bike hours, 3 rides 50 %, more 42 % (a
  /// triathlete's 2-ride week is one long ride + one quality ride); at least 60 min
  /// (45 min in recovery / taper weeks, so the deload still shows when the volume is small).
  int _longRideMin(double weekH, int perWeek, {bool rest = false}) {
    final share = perWeek <= 2 ? 0.6 : (perWeek == 3 ? 0.5 : 0.42);
    return max(rest ? 45 : 60, ((weekH * share) * 60 / 15).round() * 15);
  }

  /// [loadWeek] counts the loading weeks so far: quality rides progress only in those.
  /// [dayCap]: the time of the whole day when a brick run shares it (feasibility).
  PlannedWorkout _ride(
    DateTime day,
    String role,
    String phase,
    double weekH,
    int perWeek,
    int loadWeek,
    int capMin,
    int nQ, {
    int? dayCap,
  }) {
    final rest = phase == 'recovery' || phase == 'taper';
    final wu = _rideStep('warmup', 'Z2', 600);
    final cd = _rideStep('cooldown', 'Z1', 600);
    String title, desc, intensity = 'easy';
    List<WorkoutStep> steps;
    var isKey = false;
    if (role == 'long') {
      if (!rest) _longRideLimitMin = max(_longRideLimitMin, dayCap ?? capMin);
      steps = [_rideStep('steady', 'Z2', min(capMin, _longRideMin(weekH, perWeek, rest: rest)) * 60, note: l.stepZ2RideNote)];
      title = l.planLongRide;
      desc = l.wLongRideDesc;
      intensity = 'long';
      isKey = true;
    } else if (role.startsWith('q')) {
      isKey = true;
      // < 5 bike hours: pyramidal – one sweet-spot / threshold and one VO2 session, also
      // in the base phase (§3.3). Beginners: no VO2max reps (threshold work instead).
      final vo2 = !beginner && (role == 'q2' || (phase == 'peak' && perWeek < 3));
      if (vo2 && (phase != 'base' || weekH < 5) && !hf.capIntensity) {
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
      final longMin = _longRideMin(weekH, perWeek, rest: rest);
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
    // Technique sessions stay ≤ ~60 min: drill quality drops with fatigue, and long sessions
    // of 50 m repeats do not build the continuous swimming a race needs.
    if (role == 'technique' || ((beginner || hf.avoidOverhead) && role.startsWith('q'))) capMin = min(capMin, 60);
    // Session distance, limited by the time available (≈ CSS + 15 s per 100 m incl. rests).
    final maxM = capMin * 60 / ((sz.css + 15) / 100);
    // Shoulder: ~20 % less swim volume (fewer strokes), technique over hard sets.
    final share = hf.avoidOverhead ? 0.8 : 1.0;
    var total = max(beginner ? 600.0 : 1000.0, (min(weekKm * 1000 / max(1, perWeek), maxM) * share / 100).round() * 100.0);
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
    if (role == 'q1' && !beginner && !hf.avoidOverhead) {
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
    } else if (role == 'technique' || ((beginner || hf.avoidOverhead) && role.startsWith('q'))) {
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
      // Continuous swimming grows through the plan (towards the race distance in one go):
      // beginners 50 → 100 → 200 → 400 → 800 m every 3 weeks, others 200 → 400 → 800 m
      // every 4 weeks; 800 m repeats only for olympic / 70.3, and always ≥ 2 repeats.
      final ladder = beginner ? [if (!a.canSwim400) 50.0, 100.0, 200.0, 400.0, 800.0] : [200.0, 400.0, 800.0];
      var rep = min(
        ladder[min(week ~/ (beginner ? 3 : 4), ladder.length - 1)],
        a.eventDistance == 'olympic' || a.eventDistance == '70.3' ? 800.0 : 400.0,
      );
      while (rep > 50 && main < rep * 2) {
        rep = rep == 800 ? 400 : rep / 2;
      }
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
    return _rotationFor(a, scheduleOf(p));
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
    final legsInside = key.startsWith('fb_') || key.startsWith('home_') || key.startsWith('bw_') || legHeavyKeys.contains(key);
    // C3/C4: a full-body (home / bodyweight) program the day before a key endurance
    // session keeps half of its leg sets (the session start uses these exercises).
    final lighter = endurance && role == 'nolegs' && legsInside && t != null && !legHeavyKeys.contains(key);
    final exercises = lighter ? [for (final e in t.exercises) _halveLegSets(e)] : const <GymExercise>[];
    final est = lighter ? estimateGymMinutes(exercises) : (t?.estimatedMinutes ?? 60);
    final minutes = deload ? (est * 0.7).round() : est;
    // Sets, rep ranges and loads are per exercise (program + exercise_class.dart +
    // LoadPrescriber, which also applies the deload: −10 % load, about half the work sets) – the note
    // only states what is true for every exercise: the effort target and the progression.
    final notes = [
      if (phase == 'taper') l.wGymTaperNote else if (deload) l.wGymDeloadNote3 else ...[l.wGymLoadDesc(rir), l.wGymProgressNote],
      if (endurance && role == 'nolegs' && legsInside) l.wGymConcurrentNote,
      if (lighter) l.wGymLegsHalvedNote,
      if (minutes > capMin) l.wGymTimeCapNote2(capMin),
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
      exercises: exercises,
    );
  }

  /// [e] with half of its work sets (at least one) if it trains the legs.
  static GymExercise _halveLegSets(GymExercise e) {
    final c = e.copy();
    if (!classifyLift(e.exId, e.name).lower) return c;
    final work = c.sets.where((s) => !s.warmup).length;
    for (var drop = work - max(1, work ~/ 2); drop > 0; drop--) {
      c.sets.removeAt(c.sets.lastIndexWhere((s) => !s.warmup));
    }
    return c;
  }

  String _builtinName(String key) {
    final de = l.localeName.startsWith('de');
    return defaultTemplates(() => '', de: de).firstWhere((t) => t.key == key).name;
  }

  /// Goal race pace (s/km) of the running event for race-specific work (peak phase): the
  /// target time when it is realistic in the weeks available ([GoalModel.check] ok); an
  /// ambitious / unrealistic target gives way to the realistic race-day time – goal-pace work
  /// far beyond the athlete's fitness is a classic mistake (Daniels). Without a target: the
  /// time predicted from the current VDOT. All other paces stay on the current VDOT.
  int? _goalPace() {
    final meters = Vdot.distances[a.eventDistance];
    final vdot = Vdot.of(a);
    if (meters == null) return null;
    final t = _target;
    final goal =
        t != null ? (t.status == TargetStatus.ok ? t.targetSec : t.realisticSec) : (vdot == null ? null : Vdot.raceTime(vdot, meters));
    return goal == null ? null : (goal / (meters / 1000)).round();
  }

  /// Marathon-pace work step: at goal pace (±5 s/km) when a target time is set, else the
  /// Daniels M zone of the current VDOT.
  WorkoutStep _mpStep(double km) {
    final step = _runStep('work', 'M', km: km, note: l.stepMpNote);
    final pace = _target == null || a.eventDistance != 'm' ? null : _goalPace();
    if (pace == null || step.paceMin == null) return step;
    return WorkoutStep(
      kind: 'work',
      distanceM: step.distanceM,
      zone: 'M',
      paceMin: pace - 5,
      paceMax: pace + 5,
      hrMin: step.hrMin,
      hrMax: step.hrMax,
      note: step.note,
    );
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
    final tri = _tri;
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
            if (!hf.noHardRunning)
              for (var i = 0; i < 4; i++) ...[
                _runStep('work', 'R', sec: 20, note: l.stepStrideNote),
                _runStep('recovery', 'walk', sec: 60),
              ],
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
        description: [
          if (tri && legs != null) legs,
          goal == null ? l.wRaceDesc : l.wRaceGoalDesc(clock(goal)),
          // Still on run/walk in race week: race with the same rhythm (Galloway-style
          // walk breaks from the start), never "run until it breaks".
          if (_rwAtRace != null) l.wRaceRunWalk(_raceRunMin(_rwAtRace!)),
        ].join('\n'),
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
      // Interval / repetition reps stay on whole 200 m steps (400 / 600 / 800 m, not 700 m).
      distanceM:
          s.distanceM == null
              ? null
              : (s.isWork && (s.zone == 'I' || s.zone == 'R')
                  ? max(200.0, (s.distanceM! * f / 200).floor() * 200.0)
                  : max(100.0, (s.distanceM! * f / 100).round() * 100.0)),
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
      // Deload / taper weeks say why the session is shorter (not for the race and the
      // shake-out, which explain themselves).
      description: [
        desc,
        if (phase == 'recovery' && intensity != 'race') l.wRecoveryWeekNote2,
        if (phase == 'taper' && intensity != 'race' && title != l.wShakeout) l.wTaperWeekNote,
      ].where((x) => x.isNotEmpty).join('\n'),
      durationMin: max(15, (sec / 60 / 5).round() * 5),
      distanceKm: meters <= 0 ? null : double.parse((meters / 1000).toStringAsFixed(1)),
      intensity: intensity,
      steps: steps,
      phase: phase,
      isKey: isKey,
    );
  }

  // ───────────────────────────── Feasibility ─────────────────────────────

  /// Long run the race needs before the taper (~70–80 % of the distance; 10 km: 8 km).
  static const _longRunTargetKm = {'10k': 8.0, 'hm': 15.0, 'm': 28.0};

  /// Long ride the race needs (min): 70.3 ≥ 3 h, olympic ≥ 90 min (bike leg ~80 min).
  static const _longRideTargetMin = {'sprint': 60, 'olympic': 90, '70.3': 180};

  /// Long run (km) the event needs before the taper (null: no requirement).
  static double? longRunTargetFor(String? event) => _longRunTargetKm[event];

  /// The phases of a plan for [p] that starts at [start] and runs to race day, each with the
  /// fitness it is expected to reach by its end ([GoalModel.gain]; recovery weeks belong to the
  /// phase around them). Empty without an event in range. The expected values are a guide the
  /// goal forecast compares the athlete with – the plan's paces stay on the current fitness.
  static List<PhaseOutlook> outlook(UserProfile p, {required DateTime start}) {
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '').._start = start;
    final total = g.weeksToEvent;
    if (total == null || p.athlete.eventDistance == null) return const [];
    final raw = g._phases(total);
    final phases = [...raw];
    for (var i = 0; i < phases.length; i++) {
      if (phases[i] != 'recovery') continue;
      phases[i] = i > 0 ? phases[i - 1] : (raw.firstWhere((x) => x != 'recovery', orElse: () => 'base'));
    }
    final (vdot, _) = GoalModel.currentVdot(p);
    final model = GoalModel.hasModel(p);
    final out = <PhaseOutlook>[];
    for (var i = 0; i < phases.length;) {
      var j = i;
      while (j + 1 < phases.length && phases[j + 1] == phases[i]) {
        j++;
      }
      // Training weeks completed by the end of the phase (race week adds none).
      final gain = GoalModel.gain(p, min(j + 1, total - 1).toDouble());
      out.add(
        PhaseOutlook(
          phase: phases[i],
          firstWeek: i,
          weeks: j - i + 1,
          expectedVdot: vdot + gain,
          predictedSec: model ? GoalModel.timeAt(p, vdot, gain) : null,
        ),
      );
      i = j + 1;
    }
    return out;
  }

  static const _shorterGoals = {
    'm': ['hm', '10k', '5k'],
    'hm': ['10k', '5k'],
    '10k': ['5k'],
    '70.3': ['olympic', 'sprint'],
    'olympic': ['sprint'],
  };

  /// Is the event goal of [p] realistic in the time to race day (§1.8)? The plan is
  /// generated either way; this says why it falls short and what would work: a later race
  /// date (the first one that is long enough), a shorter distance, or finishing with
  /// run/walk. Checks: entry requirements (no marathon for beginners, no HM / marathon
  /// while on run/walk), run/walk finished before race week, the long run reaching
  /// [_longRunTargetKm] / the long ride [_longRideTargetMin] – and whether the time on the
  /// long day, not the weeks, is what limits them.
  static PlanFeasibility feasibility(UserProfile p, {DateTime? start, AppLocalizations? l}) {
    final loc = l ?? lookupAppLocalizations(const Locale('en'));
    final from = start ?? DateTime.now();
    final ev = p.athlete.eventDistance;
    final weeks = (PlanGenerator(loc, p, const [], () => '').._start = from).weeksToEvent;
    if (ev == null || weeks == null) return const PlanFeasibility();
    final c = _check(loc, p, from);
    // Target time (§1.12): required vs. achievable VDOT gain – not for goals that are out of
    // reach anyway (entry requirements).
    final notAllowed = c.issues.contains('beginnerMarathon') || c.issues.contains('runWalkLong');
    final t = notAllowed ? null : GoalModel.check(p, start: from);
    final targetIssue = switch (t?.status) {
      TargetStatus.ambitious => 'targetAmbitious',
      TargetStatus.unrealistic => 'targetUnrealistic',
      _ => null,
    };
    if (c.ok) return PlanFeasibility(issues: [if (targetIssue != null) targetIssue], weeks: weeks, target: t);
    bool timing(PlanFeasibility f) => f.issues.contains('tooShort') || f.issues.contains('runWalk');
    DateTime? later;
    if (timing(c) && !c.issues.contains('beginnerMarathon') && !c.issues.contains('runWalkLong')) {
      final race = dayOnly(p.athlete.eventDate!);
      for (var w = weeks + 1; w <= 30 && later == null; w++) {
        final d = DateTime(race.year, race.month, race.day + 7 * (w - weeks));
        if (!timing(_check(loc, p.copyWith(athlete: p.athlete.merge({'eventDate': d})), from))) later = d;
      }
    }
    String? shorter;
    for (final d in _shorterGoals[ev] ?? const <String>[]) {
      if (_check(loc, p.copyWith(athlete: p.athlete.merge({'eventDistance': d})), from).ok) {
        shorter = d;
        break;
      }
    }
    return PlanFeasibility(
      issues: [...c.issues, if (targetIssue != null) targetIssue],
      target: t,
      weeks: weeks,
      laterDate: later,
      shorterDistance: shorter,
      runWalkFinish: c.issues.contains('runWalk') && const {'5k', '10k', 'sprint', 'olympic'}.contains(ev),
      longRunKm: c.longRunKm,
      longRunTargetKm: c.longRunTargetKm,
      longRideMin: c.longRideMin,
      longRideTargetMin: c.longRideTargetMin,
    );
  }

  static PlanFeasibility _check(AppLocalizations l, UserProfile p, DateTime start) {
    final ev = p.athlete.eventDistance!;
    final g = PlanGenerator(l, p, const [], () => '');
    final issues = <String>[];
    final runs = p.focus.sports.contains(Sport.run);
    if (ev == 'm' && p.level == 'beginner') issues.add('beginnerMarathon');
    if (runs && runWalkStartFor(p) != null && (ev == 'hm' || ev == 'm')) issues.add('runWalkLong');
    // Not a goal for this athlete at all (§1.8): the other checks would only add noise.
    if (issues.isNotEmpty) return PlanFeasibility(issues: issues);
    final plan = g.generate(start: start);
    if (g._rwAtRace != null) issues.add('runWalk');
    final runTarget = _longRunTargetKm[ev];
    double? runLimit;
    if (runs && runTarget != null && g._rwAtRace == null) {
      final longRun = plan.where((w) => w.sport == Sport.run && w.intensity == 'long').fold(0.0, (x, w) => max(x, w.distanceKm ?? 0));
      if (longRun < runTarget - 0.5) {
        final byTime = g._longRunLimitKm < runTarget - 0.5;
        issues.add(byTime ? 'longRunTime' : 'tooShort');
        if (byTime) runLimit = g._longRunLimitKm;
      }
    }
    final rideTarget = _longRideTargetMin[ev];
    int? rideLimit;
    if (rideTarget != null && p.focus.sports.contains(Sport.ride)) {
      final longRide = plan.where((w) => w.sport == Sport.ride && w.intensity == 'long').fold(0, (x, w) => max(x, w.durationMin));
      if (longRide < rideTarget * 0.9) {
        final byTime = g._longRideLimitMin < rideTarget;
        if (byTime) rideLimit = g._longRideLimitMin;
        final issue = byTime ? 'longRideTime' : 'tooShort';
        if (!issues.contains(issue)) issues.add(issue);
      }
    }
    return PlanFeasibility(
      issues: issues,
      longRunKm: runLimit,
      longRunTargetKm: runLimit == null ? null : runTarget,
      longRideMin: rideLimit,
      longRideTargetMin: rideLimit == null ? null : rideTarget,
    );
  }
}

/// Result of [PlanGenerator.feasibility].
class PlanFeasibility {
  const PlanFeasibility({
    this.issues = const [],
    this.weeks,
    this.laterDate,
    this.shorterDistance,
    this.runWalkFinish = false,
    this.longRunKm,
    this.longRunTargetKm,
    this.longRideMin,
    this.longRideTargetMin,
    this.target,
  });

  /// Why the goal is not realistic, most important first: `beginnerMarathon`,
  /// `runWalkLong` (HM / marathon while still on run/walk), `runWalk` (still on run/walk
  /// in race week), `tooShort` (too few weeks to build the long session), `longRunTime` /
  /// `longRideTime` (the time on the long day caps the long session), `targetAmbitious` /
  /// `targetUnrealistic` (the target time needs more fitness than the weeks can give).
  final List<String> issues;

  /// Target-time check (null without a target time).
  final TargetCheck? target;

  /// Only the target time is the problem – the event itself is fine.
  bool get onlyTarget => issues.isNotEmpty && issues.every((i) => i.startsWith('target'));
  bool get ok => issues.isEmpty;
  String? get reason => issues.firstOrNull;

  /// Weeks to race day (incl. race week).
  final int? weeks;

  /// First race date (same weekday, later week) that is long enough – null if none ≤ 30 weeks.
  final DateTime? laterDate;

  /// Largest shorter distance that works by the race date.
  final String? shorterDistance;

  /// The race can be finished with run/walk (5 / 10 km, sprint / olympic).
  final bool runWalkFinish;

  /// Longest long run (km) / ride (min) the time on its day allows, and what is needed.
  final double? longRunKm;
  final double? longRunTargetKm;
  final int? longRideMin;
  final int? longRideTargetMin;
}

/// One phase of [PlanGenerator.outlook].
class PhaseOutlook {
  const PhaseOutlook({required this.phase, required this.firstWeek, required this.weeks, required this.expectedVdot, this.predictedSec});

  /// base | build | peak | taper.
  final String phase;

  /// Index of its first week in the plan (0 = the plan's first week) and its length.
  final int firstWeek, weeks;

  /// Running fitness expected by the end of the phase, and the race time it predicts.
  final double expectedVdot;
  final int? predictedSec;
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
