import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'compliance.dart';
import 'goal_model.dart';
import 'insights.dart';
import 'plan_generator.dart';
import 'progression_check.dart';
import 'zones.dart';

/// Where the athlete stands on the way to the event goal.
enum ForecastStatus { ahead, onTrack, slightlyBehind, atRisk }

/// Why the forecast moved away from the plan.
enum ForecastReason { missedTraining, slowerThanPlanned, fasterThanPlanned, longRunBehind, trainingBreak }

/// How much data the forecast stands on.
enum ForecastConfidence { low, medium, high }

/// "Zielprognose" – predicted race time today and at race day from what was actually trained
/// (docs/training-science.md §1.12). Pure – no Firestore, no UI.
///
/// * **Fitness now** (running VDOT): a recent near-maximal effort (the planned race, or an
///   unplanned run at RPE ≥ 8 or HR ≥ 88 % HRmax; best 5 km+ of the last 60 days, [runBestEfforts]) is a measurement; otherwise the
///   plan's line – baseline + the gain of the weeks trained × completion / 0.9 (hitting the
///   targets says "at least as planned"). Done quality runs (tempo / intervals, last 42 days)
///   give the median actual / planned average speed of the last ≤ 5: < 0.98 at a real effort
///   pulls the estimate towards the VDOT their targets were set for × ratio^1.2 (VO2 rises
///   ~1.2 % per 1 % of speed in the Daniels equation), > 1.02 lifts it there. Faster
///   non-maximal efforts only raise it. Detraining after > 10 days without running: −0.7 VDOT
///   per further week, ≤ −4 (Mujika & Padilla 2000 [68]: VO2max −4–14 % within 2–4 weeks).
/// * **Race day**: fitness now + the gain the remaining weeks give ([GoalModel.gainBetween],
///   diminishing returns after the weeks already trained), scaled by the recent adherence
///   (0.3 + 0.7 × completion of the last 28 days / 0.9, ≤ 1).
/// * **Range**: ± 1 VDOT with a recent maximal effort, ± 1.5 from quality sessions, ± 2 from
///   race times, ± 3.5 from the level default, + 0.04 per week left.
/// * **Status** with a target time: race-day prediction ≤ 0.97 × target → ahead (suggest a
///   faster target), ≤ 1.01 → on track, ≤ 1.03 → slightly behind, else at risk (suggest the
///   predicted time). Without a target (finish goal): completion < 50 % or the long run far
///   behind with ≤ 6 weeks left → at risk; completion < 70 % or long run behind → slightly
///   behind. Before 2 done sessions of the plan the status is only [early].
/// * **Beginner progression** ([progressionCheck]: run/walk, growing long session, swim novice
///   ladder, last 3 weeks, carried in [progression]): behind → status at least slightly behind;
///   long sessions behind → reason [ForecastReason.longRunBehind], and with ≤ 8 weeks left or
///   < 60 % achieved → at risk. Run/walk and effort issues add no reason (the UI reads
///   [ProgressionCheck.issues]).
class GoalForecast {
  const GoalForecast({
    required this.event,
    required this.raceDate,
    required this.daysLeft,
    required this.status,
    required this.confidence,
    required this.early,
    this.targetSec,
    this.nowSec,
    this.raceDaySec,
    this.fastSec,
    this.slowSec,
    this.vdotNow,
    this.vdotRaceDay,
    this.expectedVdotNow,
    this.reasons = const [],
    this.adherence,
    this.longestRunKm,
    this.longRunNeededKm,
    this.longRunPlannedKm,
    this.trend = const [],
    this.planned = const [],
    this.planStart,
    this.suggestedSec,
    this.doneSessions = 0,
    this.progression,
  });

  final String event;
  final DateTime raceDate;
  final int daysLeft;
  final ForecastStatus status;
  final ForecastConfidence confidence;

  /// Too little done training to judge (status is a placeholder).
  final bool early;

  final int? targetSec;

  /// Predicted finishing time today / at race day, and the race-day range (fast … slow).
  final int? nowSec, raceDaySec, fastSec, slowSec;
  final double? vdotNow, vdotRaceDay;

  /// Fitness the plan expected by today.
  final double? expectedVdotNow;
  final List<ForecastReason> reasons;

  /// Completion of the due planned endurance training since the plan start.
  final double? adherence;

  /// Longest run of the last 6 weeks, what the race needs, and the longest planned so far.
  final double? longestRunKm, longRunNeededKm, longRunPlannedKm;

  /// VDOT data points (efforts and quality sessions) and the plan's expected line.
  final List<(DateTime, double)> trend;
  final List<(DateTime, double)> planned;
  final DateTime? planStart;

  /// Target time to suggest: the predicted one when behind, a faster one when ahead.
  final int? suggestedSec;
  final int doneSessions;

  /// Beginner progression check (null when it does not apply – see [progressionCheck]).
  final ProgressionCheck? progression;

  int get weeksLeft => daysLeft ~/ 7;
  bool get atRisk => !early && status == ForecastStatus.atRisk;

  /// The user should hear about it (in-app, at most weekly – see the home card).
  bool get alert => atRisk;

  /// Computes the forecast; null without an upcoming event.
  static GoalForecast? of(UserProfile p, {required List<PlannedWorkout> plans, required List<Session> sessions, required DateTime now}) {
    final a = p.athlete;
    final ev = a.eventDistance;
    if (a.eventDate == null || ev == null) return null;
    final today = dayOnly(now);
    final race = dayOnly(a.eventDate!);
    if (race.isBefore(today)) return null;
    final daysLeft = race.difference(today).inDays;

    // Plan start: the first phased workout of the plan leading to this race.
    final horizon = race.subtract(const Duration(days: 7 * GoalModel.maxEventWeeks));
    final phased = plans.where((x) => x.phase != null && !x.date.isBefore(horizon) && !dayOnly(x.date).isAfter(race)).toList();
    final planStart = phased.isEmpty ? null : phased.map((x) => dayOnly(x.date)).reduce((x, y) => x.isBefore(y) ? x : y);
    final from = planStart ?? today;
    final elapsedWeeks = max(0.0, today.difference(from).inDays / 7);

    final linked = linkPlanSessions(plans, sessions);
    final hrMax = HrMax.of(p, sessions: sessions, now: now);
    final (profileVdot, guessed) = GoalModel.currentVdot(p);
    // The plan line starts at the fitness the plan was built with. A recalibration that moved
    // the profile's VDOT since then (it rewrites the race time) must not move the start of the
    // line too – baseline + gain(weeks) would count the realised gain twice (or a cut twice).
    // The first quality run of the plan keeps the paces of the plan start.
    final firstQuality =
        (plans
                .where((x) => x.sport == Sport.run && planStart != null && !x.date.isBefore(planStart) && _vdotOfSteps(x.steps) != null)
                .toList()
              ..sort((x, y) => x.date.compareTo(y.date)))
            .firstOrNull;
    final startVdot = firstQuality == null ? null : _vdotOfSteps(firstQuality.steps);
    final baseline = startVdot != null && (startVdot - profileVdot).abs() >= 0.75 ? startVdot : profileVdot;
    final runs = sessions.where((s) => s.sport == Sport.run && !s.start.isAfter(now)).toList();
    final planOf = {for (final x in plans) x.id: x};
    PlannedWorkout? planFor(Session s) => s.planId != null ? planOf[s.planId] : plans.where((x) => x.sessionId == s.id).firstOrNull;

    // ── Efforts (5 km and longer, last 60 days)
    final trend = <(DateTime, double)>[];
    double? effort, floor;
    for (final s in runs.where((s) => today.difference(dayOnly(s.start)).inDays <= 60)) {
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

    // ── Quality runs: implied VDOT from actual vs planned average speed
    final implied = <(DateTime, double)>[];
    final ratios = <double>[], planVdots = <double>[];
    final easyPace = PaceZones(baseline).easySlow;
    for (final x in plans) {
      if (x.sport != Sport.run || (x.intensity != 'tempo' && x.intensity != 'intervals')) continue;
      final s = linked[x.id];
      if (s == null || s.distanceM <= 0 || s.durationSec <= 0 || today.difference(dayOnly(s.start)).inDays > 42) continue;
      final km = x.distanceKm ?? 0;
      final plannedSec = x.steps.fold<int>(0, (t, st) => t + estimateStepSec(st, Sport.run, easyPace: easyPace, css: 100));
      final planVdot = _vdotOfSteps(x.steps);
      if (km <= 0 || plannedSec <= 0 || planVdot == null) continue;
      final ratio = ((s.distanceM / s.durationSec) / (km * 1000 / plannedSec)).clamp(0.85, 1.15);
      // Faster only counts when it did not take an all-out effort; slower only when it was a
      // real effort (an easy jog of a quality day says nothing about fitness).
      if (ratio > 1 && (s.rpe ?? 0) >= 9) continue;
      if (ratio < 1 && s.rpe != null && s.rpe! <= 5) continue;
      final v = (planVdot * pow(ratio, 1.2)).clamp(planVdot - 3, planVdot + 3).toDouble();
      implied.add((dayOnly(s.start), v));
      ratios.add(ratio.toDouble());
      planVdots.add(planVdot);
    }
    trend.addAll(implied);
    trend.sort((x, y) => x.$1.compareTo(y.$1));

    // ── Adherence (training that was due since the plan start)
    bool endurance(PlannedWorkout x) => x.sport != Sport.gym && x.intensity != 'race';
    final due = plans.where((x) => endurance(x) && !x.date.isBefore(from) && !dayOnly(x.date).isAfter(today)).toList();
    final adherence = due.length >= 3 ? weeklyCompletion(due, linked, now: now) : null;
    final recentFrom = today.subtract(const Duration(days: 28));
    final recentDue = due.where((x) => !x.date.isBefore(recentFrom)).toList();
    final recent = recentDue.length >= 3 ? weeklyCompletion(recentDue, linked, now: now) : adherence;

    // ── Fitness now. Hitting the targets of a quality run only says "at least the VDOT the
    // plan expected" (targets are a prescription, not a maximum): without contrary evidence
    // the athlete is on the plan's line (the gain of the weeks trained, scaled by how much of
    // it was done). Clearly slower runs at a real effort pull it down, faster ones up; a
    // near-maximal effort is a direct measurement.
    final expectedNow = baseline + GoalModel.gain(p, elapsedWeeks) * ((adherence ?? 1) / 0.9).clamp(0.0, 1.0);
    var vdot = effort ?? expectedNow;
    final recentRatios = ratios.skip(max(0, ratios.length - 5)).toList();
    // "Faster than planned" needs more than two good days (B10): ≥ 3 quality runs over ≥ 14 days
    // (or a measured maximal effort) – the same evidence the recalibration needs for VDOT +1.
    final qDays = implied.map((x) => x.$1).toList()..sort();
    final fasterEvidence = effort != null || (qDays.length >= 3 && qDays.last.difference(qDays.first).inDays >= 14);
    if (recentRatios.length >= 2) {
      final rm = _median(recentRatios);
      final q = _median(planVdots.skip(max(0, planVdots.length - 5)).toList()) * pow(rm, 1.2);
      if (rm < 0.98) vdot = min(vdot, (vdot + 2 * q) / 3);
      if (rm > 1.02 && fasterEvidence) vdot = max(vdot, q.toDouble());
    }
    final qm = recentRatios.length >= 2;
    if (floor != null && floor > vdot) vdot = floor;
    final reasons = <ForecastReason>[];

    // ── Detraining after a break
    final runPlansDue = plans.where((x) => x.sport == Sport.run && !x.date.isBefore(from) && dayOnly(x.date).isBefore(today)).length;
    // The longest gap of the last 28 days counts (B11), not only the one up to today – one easy
    // run after three weeks off does not undo the detraining. A finished gap fades linearly over
    // twice its length after the return; gaps before the plan start are the plan's baseline.
    if (runs.isNotEmpty && runPlansDue >= 2) {
      final days = {for (final s in runs) dayOnly(s.start)}.toList()..sort();
      final points = [...days, today];
      var penalty = 0.0;
      for (var i = 1; i < points.length; i++) {
        final gap = points[i].difference(points[i - 1]).inDays;
        if (gap <= 10) continue;
        final open = i == points.length - 1;
        final since = today.difference(points[i]).inDays;
        if (!open && (since > 28 || points[i - 1].isBefore(from))) continue;
        final full = min(4.0, (gap - 10) / 7 * 0.7 + 0.3);
        penalty = max(penalty, full * max(0.0, 1 - since / (2 * gap)));
      }
      if (penalty > 0.05) {
        vdot -= penalty;
        reasons.add(ForecastReason.trainingBreak);
      }
    }

    if (adherence != null && adherence < 0.7) reasons.add(ForecastReason.missedTraining);
    final futureFactor = recent == null ? 1.0 : (0.3 + 0.7 * recent / 0.9).clamp(0.3, 1.0);
    final doneSessions = sessions.where((s) => !dayOnly(s.start).isBefore(from) && !s.start.isAfter(now) && s.sport != Sport.gym).length;

    // ── Race day
    final weeksLeft = daysLeft / 7;
    final trainingLeft = max(0.0, weeksLeft - 1);
    final gainLeft = GoalModel.gainBetween(p, elapsedWeeks, elapsedWeeks + trainingLeft) * futureFactor;
    final vdotRace = vdot + gainLeft;
    final planLine = baseline + GoalModel.gain(p, elapsedWeeks);
    final confidence = effort != null ? ForecastConfidence.high : (qm ? ForecastConfidence.medium : ForecastConfidence.low);
    if (confidence != ForecastConfidence.low && planStart != null) {
      if (vdot <= planLine - 1.5) reasons.add(ForecastReason.slowerThanPlanned);
      if (vdot >= planLine + 1.5) reasons.add(ForecastReason.fasterThanPlanned);
    }
    final u =
        switch (confidence) {
          ForecastConfidence.high => 1.0,
          ForecastConfidence.medium => 1.5,
          ForecastConfidence.low => guessed ? 3.5 : 2.0,
        } +
        0.04 * weeksLeft;

    final model = GoalModel.hasModel(p);
    int? at(double v, double g) => model ? GoalModel.timeAt(p, v, g) : null;
    final nowSec = at(vdot, 0);
    final raceSec = at(vdot, gainLeft);
    final fast = at(vdot, gainLeft + u), slow = at(vdot, gainLeft - u);

    // ── Long run
    final need = PlanGenerator.longRunTargetFor(ev);
    final sixWeeks = today.subtract(const Duration(days: 42));
    final longest = runs.where((s) => !s.start.isBefore(sixWeeks)).fold<double>(0, (x, s) => max(x, s.distanceM / 1000));
    final plannedLong = plans
        .where((x) => x.sport == Sport.run && x.intensity == 'long' && !x.date.isBefore(from) && dayOnly(x.date).isBefore(today))
        .fold<double>(0, (x, w) => max(x, w.distanceKm ?? 0));
    final longBehind = plannedLong >= 6 && longest < 0.75 * plannedLong;
    if (longBehind) reasons.add(ForecastReason.longRunBehind);

    // ── Status
    final target = a.targetTimeSec != null && a.targetTimeSec! > 0 && raceSec != null ? a.targetTimeSec : null;
    var status = ForecastStatus.onTrack;
    int? suggested;
    if (target != null) {
      final r = raceSec! / target;
      // Ahead: running needs the B10 evidence; a triathlon target slower than what the athlete's
      // data (FTP / CSS / race time) predicts already today is ahead as well – suggest a faster one.
      final triAhead = GoalModel.isTri(ev) && nowSec != null && nowSec <= 0.97 * target;
      status =
          r <= 0.97 && ((confidence != ForecastConfidence.low && fasterEvidence) || triAhead)
              ? ForecastStatus.ahead
              : (r <= 1.01 ? ForecastStatus.onTrack : (r <= 1.03 ? ForecastStatus.slightlyBehind : ForecastStatus.atRisk));
      if (status == ForecastStatus.ahead || status == ForecastStatus.slightlyBehind || status == ForecastStatus.atRisk) {
        suggested = GoalModel.roundTarget(raceSec);
      }
    } else {
      final missed = adherence != null && elapsedWeeks >= 3 ? adherence : 1.0;
      status =
          missed < 0.5 || (longBehind && weeksLeft <= 6)
              ? ForecastStatus.atRisk
              : (missed < 0.7 || longBehind ? ForecastStatus.slightlyBehind : ForecastStatus.onTrack);
    }
    if (longBehind && weeksLeft <= 6 && status.index < ForecastStatus.slightlyBehind.index) status = ForecastStatus.slightlyBehind;

    // ── Beginner progression (run/walk, long session, swim ladder)
    final progression = progressionCheck(p, plans: plans, sessions: sessions, now: now);
    if (progression != null && progression.behind) {
      if (progression.longBehind && !reasons.contains(ForecastReason.longRunBehind)) reasons.add(ForecastReason.longRunBehind);
      final share = progression.longAchievedShare ?? 1;
      final floor = progression.longBehind && (weeksLeft <= 8 || share < 0.6) ? ForecastStatus.atRisk : ForecastStatus.slightlyBehind;
      if (status.index < floor.index) status = floor;
    }

    // Expected line: from the plan start (baseline) to race day.
    final planned = <(DateTime, double)>[];
    if (planStart != null) {
      final totalWeeks = race.difference(planStart).inDays / 7;
      for (var w = 0.0; w <= totalWeeks + 1e-9; w += max(1.0, totalWeeks / 12)) {
        planned.add((planStart.add(Duration(days: (w * 7).round())), baseline + GoalModel.gain(p, min(w, max(0, totalWeeks - 1)))));
      }
    }

    return GoalForecast(
      event: ev,
      raceDate: race,
      daysLeft: daysLeft,
      status: status,
      confidence: confidence,
      early: doneSessions < 2 || planStart == null,
      targetSec: target,
      nowSec: nowSec,
      raceDaySec: raceSec,
      fastSec: fast,
      slowSec: slow,
      vdotNow: double.parse(vdot.toStringAsFixed(1)),
      vdotRaceDay: double.parse(vdotRace.toStringAsFixed(1)),
      expectedVdotNow: planStart == null ? null : planLine,
      reasons: reasons,
      adherence: adherence,
      longestRunKm: longest > 0 ? longest : null,
      longRunNeededKm: need,
      longRunPlannedKm: plannedLong > 0 ? plannedLong : null,
      trend: trend,
      planned: planned,
      planStart: planStart,
      suggestedSec: suggested,
      doneSessions: doneSessions,
      progression: progression,
    );
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    return s.length.isOdd ? s[s.length ~/ 2] : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
  }

  /// VDOT the work-step paces of a quality run were set for (T at 88 %, I at 97.5 % VO2max).
  static double? _vdotOfSteps(List<WorkoutStep> steps) {
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

  /// Planned workouts to update when the target changes to [newTarget]: race-pace steps of
  /// upcoming peak / taper workouts and the race itself follow the new goal pace.
  static Map<String, Map<String, dynamic>> retarget(UserProfile p, List<PlannedWorkout> plans, int newTarget, {required DateTime now}) {
    final meters = Vdot.distances[p.athlete.eventDistance];
    if (meters == null) return const {};
    final pace = (newTarget / (meters / 1000)).round();
    final old = p.athlete.targetTimeSec;
    final out = <String, Map<String, dynamic>>{};
    for (final x in plans) {
      if (x.status != 'planned' || dayOnly(x.date).isBefore(dayOnly(now)) || x.sport != Sport.run) continue;
      final race = x.intensity == 'race';
      // Peak and taper: the goal-pace sets of the taper follow the target too.
      if (!race && x.phase != 'peak' && x.phase != 'taper') continue;
      var changed = false;
      final steps = [
        for (final s in x.steps)
          if (s.isWork && s.zone == 'M' && s.paceMin != null)
            () {
              changed = true;
              final half = race ? 3 : ((s.paceMax! - s.paceMin!) ~/ 2).clamp(3, 5);
              return WorkoutStep(
                kind: s.kind,
                durationSec: s.durationSec,
                distanceM: s.distanceM,
                zone: s.zone,
                paceMin: pace - half,
                paceMax: pace + half,
                hrMin: s.hrMin,
                hrMax: s.hrMax,
                note: s.note,
              );
            }()
          else
            s,
      ];
      if (!changed && !race) continue;
      out[x.id] = {
        if (changed) 'steps': steps.map((s) => s.toMap()).toList(),
        if (race && old != null) 'description': x.description.replaceAll(clock(old), clock(newTarget)),
        if (race) 'durationMin': (newTarget / 60).round(),
      };
    }
    return out;
  }
}
