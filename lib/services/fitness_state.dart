import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'compliance.dart';
import 'goal_model.dart';
import 'insights.dart';
import 'plan_adjuster.dart' show isHardPlan;
import 'plan_recalibrate.dart' show Recalibrator;
import 'zones.dart';

/// Where today's fitness estimate of a [FitnessState] comes from.
enum FitnessBasis {
  /// The plan's expected line (baseline + the gain of the weeks trained, scaled by adherence).
  planLine,

  /// The VDOT the recalibration set after the plan start ([AthleteData.vdotEstimate]) + the gain since.
  recalibrated,

  /// ≥ 3 quality runs clearly faster / slower than their targets.
  quality,

  /// A recent (near-)maximal effort – a measurement.
  effort,
}

/// The ONE running-fitness model (docs/training-science.md §1.12a): every place that predicts a race
/// time – goal forecast, target suggestion, target check / feasibility, the race session and its
/// pacing after a target change, the recalibration's goal-at-risk and VDOT cap – reads it, so they
/// can't disagree on the same day (review round 2: forecast 3:36 vs suggestion 3:47 vs paces 6 VDOT
/// apart).
///
/// * **Baseline** – the VDOT the plan was built with: the paces of its first tempo / interval run (T /
///   I targets; never the race session – review C5), else the profile's VDOT at the plan start (a
///   training-derived estimate only when it was set before the plan start).
/// * **Today** ([current]) – evidence first: a near-maximal effort (race, RPE ≥ 8, HR ≥ 88 %) > the
///   recalibrated VDOT (set after the plan start) + the model gain since > the plan line `baseline +
///   gain(weeks trained) × min(1, adherence / 0.9)`. ≥ 3 quality runs ≥ 3 % off their targets (the
///   recalibration's threshold) pull it down / lift it; the quality estimate is kept for 3 weeks after
///   its last run (fewer than 3 runs in 42 days → the runs of the last 63 days count). Detraining
///   after > 10 days without running (Mujika & Padilla 2000). Weeks of chronic overreaching (too-hard
///   score ≥ 2 in two consecutive 14-day windows) earn no adaptation (Meeusen 2013).
/// * **Race day** ([raceDayVdot]) – today + `gainBetween(weeks trained, + training weeks left)` ×
///   the recent adherence factor; the training weeks run to the Monday of race week.
/// * **Times** ([timeAt]) – always measured from the baseline: `GoalModel.timeAt(p, baseline, v −
///   baseline)`. For a triathlon the run leg's relative improvement is applied to the whole race, so
///   anchoring at today's VDOT counted the gain twice for the run and once for the rest (C1: 70.3 5:29
///   → 5:37 while the run fitness rose).
class FitnessState {
  FitnessState._({
    required this.profile,
    required this.today,
    required this.planStart,
    required this.baseline,
    required this.guessed,
    required this.elapsedWeeks,
    required this.creditedWeeks,
    required this.current,
    required this.basis,
    this.futureFactor = 1,
    this.breakPenalty = 0,
    this.effort,
    this.qualityRuns = 0,
    this.fasterEvidence = false,
    this.adherence,
    this.recentAdherence,
    this.trend = const [],
    this.linked = const {},
    this.chronicFatigue = false,
    this.recentDue = 0,
    this.recentDone = 0,
    this.keyDue = 0,
    this.keyDone = 0,
  });

  final UserProfile profile;
  final DateTime today;

  /// First day of the plan leading to the event (null: no plan running – the model starts today).
  final DateTime? planStart;

  /// VDOT the plan was built with (today's VDOT without a plan).
  final double baseline;

  /// No race time and no estimate: the baseline is a level default.
  final bool guessed;

  /// Weeks since the plan start, and the weeks that earned adaptation (minus chronic overreaching).
  final double elapsedWeeks, creditedWeeks;

  /// VDOT today (after detraining).
  final double current;
  final FitnessBasis basis;

  /// Share of the future gain the recent adherence promises (0.3 … 1).
  final double futureFactor;

  /// VDOT taken off for a training break (0: none).
  final double breakPenalty;

  /// VDOT of a recent near-maximal effort.
  final double? effort;

  /// Quality runs the estimate stands on (≥ 3 counts).
  final int qualityRuns;

  /// "Faster than planned" is backed by a maximal effort or ≥ 3 quality runs over ≥ 14 days.
  final bool fasterEvidence;

  /// Completion (minutes) of the due endurance training since the plan start / of the last 28 days.
  final double? adherence, recentAdherence;

  /// VDOT data points (efforts and quality runs).
  final List<(DateTime, double)> trend;

  /// Planned workout id → its session.
  final Map<String, Session> linked;

  /// Too hard in two consecutive 14-day windows right now.
  final bool chronicFatigue;

  /// Due / done endurance sessions and key sessions (tempo, intervals, long) of the last 28 days.
  final int recentDue, recentDone, keyDue, keyDone;

  /// Days a quality-based or recalibrated estimate is kept (the recalibration's VDOT step spacing).
  static const holdDays = 21;

  /// Quality runs this much faster / slower than their targets move the estimate (the recalibration's
  /// "≥ 3 % faster" rule).
  static const qualityThreshold = 0.03;

  /// The plan's expected VDOT today.
  double get planLine => baseline + GoalModel.gain(profile, elapsedWeeks);

  /// Highest training-derived VDOT today: baseline + [GoalModel.optimistic] × the gain of the weeks
  /// trained (the recalibration's cap, C5).
  double get cap => baseline + GoalModel.optimistic * GoalModel.gain(profile, elapsedWeeks);

  /// Training weeks left before race week (fractional, from today or the plan start if later).
  double trainingWeeksTo(DateTime race) {
    final from = planStart != null && planStart!.isAfter(today) ? planStart! : today;
    return max(0, daysBetween(from, startOfWeek(dayOnly(race))) / 7);
  }

  /// VDOT gain the weeks to [race] are expected to add (diminishing returns after the weeks trained).
  double gainTo(DateTime race, {double factor = 1}) =>
      GoalModel.gainBetween(profile, creditedWeeks, creditedWeeks + trainingWeeksTo(race)) * futureFactor * factor;

  /// Expected VDOT on [race] day.
  double raceDayVdot(DateTime race) => current + gainTo(race);

  /// Finishing time (s) of [p]'s event (default: this profile's) at running fitness [vdot], measured from
  /// the baseline (C1); null without a model.
  int? timeAt(double vdot, {UserProfile? p}) => GoalModel.timeAt(p ?? profile, baseline, vdot - baseline);

  /// Uncertainty (± VDOT) of the race-day value [weeksLeft] weeks out.
  double uncertainty(double weeksLeft) => (effort != null ? 1.0 : (qualityRuns >= 3 ? 1.5 : (guessed ? 3.5 : 2.0))) + 0.04 * weeksLeft;

  // ───────────────────────────── Construction ─────────────────────────────

  /// The recalibration's estimate is in effect (the race times it was derived from are unchanged).
  static bool estimateActive(AthleteData a) {
    final e = a.vdotEstimate;
    return e != null && e > 0 && ((Vdot.ofRaces(a) ?? 0) - (a.vdotEstimateBase ?? 0)).abs() < 0.05;
  }

  /// The profile's VDOT at [planStart]: a training-derived estimate only when it was set before.
  static double vdotAt(UserProfile p, DateTime? planStart) {
    final a = p.athlete;
    final at = a.vdotEstimateAt;
    if (estimateActive(a) && (planStart == null || at == null || dayOnly(at).isBefore(dayOnly(planStart)))) return a.vdotEstimate!;
    return Vdot.ofRaces(a) ?? Vdot.defaultFor(p.level);
  }

  /// The model from the profile alone (no plans / sessions): the plan stored on the profile
  /// ([AthleteData.planStart] / [AthleteData.planLength]) is assumed trained as planned; a
  /// recalibrated VDOT set after its start is the evidence. Without a running plan: today's VDOT.
  factory FitnessState.fromProfile(UserProfile p, {required DateTime now}) {
    final a = p.athlete;
    final today = dayOnly(now);
    var ps = a.planStart == null ? null : dayOnly(a.planStart!);
    if (ps != null && (ps.isAfter(today) || ((a.planLength ?? 0) > 0 && daysBetween(ps, today) > 7 * a.planLength!))) ps = null;
    final baseline = ps == null ? (Vdot.of(a) ?? Vdot.defaultFor(p.level)) : vdotAt(p, ps);
    final elapsed = ps == null ? 0.0 : daysBetween(ps, today) / 7;
    var current = baseline + GoalModel.gain(p, elapsed);
    var basis = FitnessBasis.planLine;
    final at = a.vdotEstimateAt;
    if (ps != null && estimateActive(a) && at != null && !dayOnly(at).isBefore(ps)) {
      current = a.vdotEstimate! + GoalModel.gainBetween(p, min(elapsed, daysBetween(ps, at) / 7), elapsed);
      basis = FitnessBasis.recalibrated;
    }
    return FitnessState._(
      profile: p,
      today: today,
      planStart: ps,
      baseline: baseline,
      guessed: Vdot.of(a) == null,
      elapsedWeeks: elapsed,
      creditedWeeks: elapsed,
      current: current,
      basis: basis,
    );
  }

  /// The full model from the plan and the logged sessions (see the class doc). [race] defaults to the
  /// profile's event date; the plan start is the first phased workout of the 52 weeks before it.
  factory FitnessState.of(
    UserProfile p, {
    required List<PlannedWorkout> plans,
    required List<Session> sessions,
    required DateTime now,
    DateTime? race,
  }) {
    final a = p.athlete;
    final today = dayOnly(now);
    final event = race ?? a.eventDate;
    final horizon = event == null ? null : addDays(dayOnly(event), -(7 * GoalModel.maxEventWeeks));
    final phased =
        plans
            .where((x) => x.phase != null && (horizon == null || (!x.date.isBefore(horizon) && !dayOnly(x.date).isAfter(dayOnly(event!)))))
            .map((x) => dayOnly(x.date))
            .toList();
    final planStart = phased.isEmpty ? null : phased.reduce((x, y) => x.isBefore(y) ? x : y);
    if (planStart == null) return FitnessState.fromProfile(p, now: now);
    final from = planStart.isAfter(today) ? today : planStart;
    final elapsed = max(0.0, daysBetween(planStart, today) / 7);

    final linked = linkPlanSessions(plans, sessions, profile: p);
    final hrMax = HrMax.of(p, sessions: sessions, now: now);
    final atStart = vdotAt(p, planStart);
    // Baseline: the paces of the plan's first tempo / interval run (the race session's step is no
    // training target – C5), unless they match the profile's VDOT at the plan start anyway.
    final firstQuality =
        (plans.where((x) => _quality(x) && !x.date.isBefore(planStart) && vdotOfSteps(x.steps) != null).toList()
              ..sort((x, y) => x.date.compareTo(y.date)))
            .firstOrNull;
    final stepVdot = firstQuality == null ? null : vdotOfSteps(firstQuality.steps);
    final baseline = stepVdot != null && (stepVdot - atStart).abs() >= 0.75 ? stepVdot : atStart;
    final guessed = Vdot.of(a) == null;
    final runs = sessions.where((s) => s.sport == Sport.run && !s.start.isAfter(now)).toList();
    final planOf = {for (final x in plans) x.id: x};
    PlannedWorkout? planFor(Session s) => s.planId != null ? planOf[s.planId] : plans.where((x) => x.sessionId == s.id).firstOrNull;

    // ── Efforts (5 km and longer, last 60 days)
    final trend = <(DateTime, double)>[];
    double? effort, floor;
    for (final s in runs.where((s) => daysBetween(dayOnly(s.start), today) <= 60)) {
      double? best;
      for (final e in runBestEfforts([s]).values) {
        if (!Vdot.distances.containsKey(e.key)) continue;
        final v = Vdot.fromRace(e.meters, e.seconds);
        if (best == null || v > best) best = v;
      }
      if (best == null) continue;
      // A run linked to a planned training session is structured training, not a time trial.
      final plan = planFor(s);
      final maximal =
          plan?.intensity == 'race' || (plan == null && ((s.rpe ?? 0) >= 8 || (s.avgHr != null && s.avgHr! >= 0.88 * hrMax.bpm)));
      if (maximal) {
        effort = max(effort ?? 0, best);
        trend.add((dayOnly(s.start), best));
      } else {
        floor = max(floor ?? 0, best);
      }
    }

    // ── Quality runs: implied VDOT from actual vs planned average speed (last 42 days; kept for
    // [holdDays] more when fewer than 3 are that recent).
    final quality = <(DateTime, double, double)>[]; // day, ratio, plan VDOT
    final easyPace = PaceZones(baseline).easySlow;
    for (final x in plans) {
      if (x.sport != Sport.run || !_quality(x)) continue;
      final s = linked[x.id];
      // Taken over from the plan: no measurement – no quality run (neither ratio, trend, count nor
      // the evidence for a faster VDOT).
      if (s == null || s.fromPlan || s.distanceM <= 0 || s.durationSec <= 0) continue;
      if (daysBetween(dayOnly(s.start), today) > 42 + holdDays) continue;
      final km = x.distanceKm ?? 0;
      final plannedSec = x.steps.fold<int>(0, (t, st) => t + estimateStepSec(st, Sport.run, easyPace: easyPace, css: 100));
      final planVdot = vdotOfSteps(x.steps);
      if (km <= 0 || plannedSec <= 0 || planVdot == null) continue;
      final ratio = qualityRatio(s, km: km, stepSec: plannedSec, planSec: x.durationMin * 60);
      // Faster only counts when it did not take an all-out effort; slower only when it was a
      // real effort (an easy jog of a quality day says nothing about fitness).
      if (ratio > 1 && (s.rpe ?? 0) >= 9) continue;
      if (ratio < 1 && s.rpe != null && s.rpe! <= 5) continue;
      quality.add((dayOnly(s.start), ratio, planVdot));
    }
    quality.sort((x, y) => x.$1.compareTo(y.$1));
    final recentQ = quality.where((q) => daysBetween(q.$1, today) <= 42).toList();
    final usedQ = recentQ.length >= 3 ? recentQ : quality;
    for (final q in recentQ) {
      trend.add((q.$1, (q.$3 * pow(q.$2, 1.2)).clamp(q.$3 - 3, q.$3 + 3).toDouble()));
    }
    trend.sort((x, y) => x.$1.compareTo(y.$1));

    // ── Adherence (training that was due since the plan start)
    bool endurance(PlannedWorkout x) => x.sport != Sport.gym && x.intensity != 'race';
    final due = plans.where((x) => endurance(x) && !x.date.isBefore(from) && !dayOnly(x.date).isAfter(today)).toList();
    final adherence = due.length >= 3 ? weeklyCompletion(due, linked, now: now, profile: p) : null;
    final recentFrom = addDays(today, -28);
    final recentList = due.where((x) => !x.date.isBefore(recentFrom)).toList();
    final recent = recentList.length >= 3 ? weeklyCompletion(recentList, linked, now: now, profile: p) : adherence;
    // Session counts of the last 28 days (before today) – chronic skipping shows in the count of
    // sessions and of key sessions even when the minutes look fine (IMPORTANT 4).
    bool done(PlannedWorkout x) => planCompleted(x, linked, profile: p);
    // A key session counts for the adaptation from half of it (4 of 30 km is no long run).
    bool keyDone(PlannedWorkout x) => adaptationCompleted(x, linked, profile: p);
    final countList = recentList.where((x) => x.durationMin > 0 && dayOnly(x.date).isBefore(today)).toList();
    final keys = countList.where(isHardPlan).toList();

    // ── Chronic overreaching: 7-day too-hard scores (the recalibration's rule 1), two consecutive
    // 14-day windows ≥ 2 → that week earns no adaptation (IMPORTANT 10).
    final blocks = <double>[];
    for (var end = today; !end.isBefore(addDays(from, 7)); end = addDays(end, -7)) {
      final start = addDays(end, -7);
      var score = 0.0;
      for (final s in sessions) {
        final d = dayOnly(s.start);
        if (s.sport == Sport.gym || s.rpe == null || d.isBefore(start) || !d.isBefore(end) || s.start.isAfter(now)) continue;
        if (s.source != null && s.avgHr != null) continue; // HR-estimated RPE
        final x = planFor(s);
        if (x == null || x.intensity == 'race') continue;
        score += Recalibrator.rpeLoad(x.intensity, s.rpe!);
      }
      blocks.add(score); // newest first
    }
    var chronicWeeks = 0;
    // As the recalibration's recovery week: too hard over 14 days on two consecutive Mondays, and
    // still ≥ 1 in the last of the weeks.
    bool chronicAt(int i) => blocks[i] >= 1 && _sum(blocks, i, 2) >= 2 && _sum(blocks, i + 1, 2) >= 2;
    for (var i = 0; i < blocks.length; i++) {
      if (chronicAt(i)) chronicWeeks++;
    }
    final chronicNow = blocks.isNotEmpty && chronicAt(0);
    final credited = max(0.0, elapsed - chronicWeeks);

    // ── Fitness now
    final adhF = ((adherence ?? 1) / 0.9).clamp(0.0, 1.0);
    var vdot = baseline + GoalModel.gain(p, credited) * adhF;
    var basis = FitnessBasis.planLine;
    final at = a.vdotEstimateAt;
    if (estimateActive(a) && at != null && !dayOnly(at).isBefore(planStart)) {
      // The recalibration's VDOT (set after the plan start) is evidence – the paces run on it (C2).
      final atW = min(credited, daysBetween(planStart, at) / 7);
      vdot = a.vdotEstimate! + GoalModel.gainBetween(p, atW, credited) * adhF;
      basis = FitnessBasis.recalibrated;
    }
    if (effort != null) {
      vdot = effort;
      basis = FitnessBasis.effort;
    }
    // After a recalibration only runs against the current targets count (as in the recalibration): the
    // runs against the old paces are what the new VDOT was derived from – counting them again pulled
    // the forecast 1.4 VDOT below the paces and back the next week (sim M_slower W10 → W11).
    final current = basis == FitnessBasis.recalibrated ? usedQ.where((q) => (q.$3 - a.vdotEstimate!).abs() < 0.75).toList() : usedQ;
    final last = current.skip(max(0, current.length - 5)).toList();
    final qDays = usedQ.map((x) => x.$1).toList();
    final fasterEvidence = effort != null || (qDays.length >= 3 && daysBetween(qDays.first, qDays.last) >= 14);
    if (last.length >= 3) {
      final rm = _median([for (final q in last) q.$2]);
      final q = _median([for (final x in last) x.$3]) * pow(rm, 1.2);
      if (rm < 1 - qualityThreshold) {
        vdot = min(vdot, (vdot + 2 * q) / 3);
        if (basis != FitnessBasis.effort) basis = FitnessBasis.quality;
      }
      // No added fitness while chronically overreached (IMPORTANT 10).
      if (rm > 1 + qualityThreshold && fasterEvidence && !chronicNow && q > vdot) {
        vdot = q.toDouble();
        basis = FitnessBasis.quality;
      }
      // On-target quality runs confirm the line (medium confidence).
      if (basis == FitnessBasis.planLine) basis = FitnessBasis.quality;
    }
    if (floor != null && floor > vdot) vdot = floor;

    // ── Detraining after a break: the longest gap of the last 28 days counts (B11); a finished gap
    // fades linearly over twice its length after the return; gaps before the plan start are the
    // plan's baseline.
    var penalty = 0.0;
    final runPlansDue = plans.where((x) => x.sport == Sport.run && !x.date.isBefore(from) && dayOnly(x.date).isBefore(today)).length;
    if (runs.isNotEmpty && runPlansDue >= 2) {
      final days = {for (final s in runs) dayOnly(s.start)}.toList()..sort();
      final points = [...days, today];
      for (var i = 1; i < points.length; i++) {
        final gap = daysBetween(points[i - 1], points[i]);
        if (gap <= 10) continue;
        final open = i == points.length - 1;
        final since = daysBetween(points[i], today);
        if (!open && (since > 28 || points[i - 1].isBefore(from))) continue;
        final full = min(4.0, (gap - 10) / 7 * 0.7 + 0.3);
        penalty = max(penalty, full * max(0.0, 1 - since / (2 * gap)));
      }
    }
    if (penalty > 0.05) vdot -= penalty;

    return FitnessState._(
      profile: p,
      today: today,
      planStart: planStart,
      baseline: baseline,
      guessed: guessed,
      elapsedWeeks: elapsed,
      creditedWeeks: credited,
      current: vdot,
      basis: basis,
      futureFactor: recent == null ? 1.0 : (0.3 + 0.7 * recent / 0.9).clamp(0.3, 1.0),
      breakPenalty: penalty > 0.05 ? penalty : 0,
      effort: effort,
      qualityRuns: last.length,
      fasterEvidence: fasterEvidence,
      adherence: adherence,
      recentAdherence: recent,
      trend: trend,
      linked: linked,
      chronicFatigue: chronicNow,
      recentDue: countList.length,
      recentDone: countList.where(done).length,
      keyDue: keys.length,
      keyDone: keys.where(keyDone).length,
    );
  }

  static bool _quality(PlannedWorkout x) => x.sport == Sport.run && (x.intensity == 'tempo' || x.intensity == 'intervals');

  static double _sum(List<double> v, int from, int n) {
    var s = 0.0;
    for (var i = from; i < from + n && i < v.length; i++) {
      s += v[i];
    }
    return s;
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    return s.length.isOdd ? s[s.length ~/ 2] : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
  }

  /// Dead band of [qualityRatio]: ± 5 % of the planned time is "as planned" (C1).
  static const deadBand = 0.05;

  /// Actual / planned average speed of a quality run [s] over the plan's [km], 0.85 … 1.15, against
  /// the step estimate ([stepSec]: work at the target paces, warm-up / cool-down / recoveries at
  /// easy pace). The whole-session average blurs the work paces, so ± [deadBand] counts as exactly
  /// on plan (1.0); a session that took the plan's displayed duration ([planSec], rounded to 5 min
  /// – up to ~9 % off the step estimate in older plans) ± 2 % is on plan as well.
  static double qualityRatio(Session s, {required double km, required int stepSec, required int planSec}) {
    // Taken over from the plan (no measurement): as planned.
    if (s.fromPlan || s.distanceM <= 0 || s.durationSec <= 0 || km <= 0) return 1;
    if (planSec > 0 && (s.durationSec / planSec - 1).abs() <= 0.02 && (s.distanceM / (km * 1000) - 1).abs() <= 0.02) return 1;
    final ref = stepSec > 0 ? stepSec : planSec;
    if (ref <= 0) return 1;
    final r = (s.distanceM / s.durationSec) / (km * 1000 / ref);
    return (r - 1).abs() <= deadBand ? 1 : r.clamp(0.85, 1.15).toDouble();
  }

  /// VDOT the work-step paces of a quality run were set for (T at 88 %, I at 97.5 % VO2max).
  static double? vdotOfSteps(List<WorkoutStep> steps) {
    for (final s in steps) {
      if (!s.isWork || s.paceMin == null || s.paceMax == null) continue;
      final frac = switch (s.zone) {
        'T' => 0.88,
        'I' => 0.975,
        _ => null,
      };
      if (frac == null) continue;
      final v = 60000 / ((s.paceMin! + s.paceMax!) / 2); // m/min
      return Vdot.vo2(v) / frac;
    }
    return null;
  }
}
