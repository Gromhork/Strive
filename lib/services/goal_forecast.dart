import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'fitness_state.dart';
import 'goal_model.dart';
import 'plan_generator.dart';
import 'plan_recalibrate.dart';
import 'progression_check.dart';
import 'zones.dart';

/// Where the athlete stands on the way to the event goal.
enum ForecastStatus { ahead, onTrack, slightlyBehind, atRisk }

/// Why the forecast moved away from the plan.
enum ForecastReason {
  missedTraining,
  slowerThanPlanned,
  fasterThanPlanned,
  longRunBehind,
  trainingBreak,
  fatigue,

  /// < 70 % of the sessions of the last 4 weeks done (chronic skipping, IMPORTANT 4).
  sessionsSkipped,

  /// < 75 % of the key sessions (tempo, intervals, long) of the last 4 weeks done.
  keySessionsMissed,
}

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
    this.paceStatus,
    this.finishOnly = false,
    this.setAsideTargetSec,
    this.eventName,
    this.sessionsDue = 0,
    this.sessionsDone = 0,
    this.keysDue = 0,
    this.keysDone = 0,
    this.baselineVdot,
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

  /// Status from the target-time comparison alone (before the floors of long runs, adherence,
  /// fatigue and the beginner progression) – what has to persist for two weeks.
  final ForecastStatus? paceStatus;

  /// No time prediction: a run/walk beginner (finish goal) without a measured effort (C6) – the
  /// level-default VDOT predicts a half marathon in ~1:54 for someone whose easy pace is 7:40/km.
  final bool finishOnly;

  /// A finish goal ([finishOnly]) although the athlete set a target: that target (s) – stored, but not raced at
  /// ([PlanGenerator.targetSetAside]); the goal page says so next to "Ankommen" instead of dropping it silently.
  final int? setAsideTargetSec;

  /// The race's name as the athlete typed it ("Berlin"; [AthleteData.eventName]) – shown with the distance.
  final String? eventName;

  /// Due / done endurance sessions and key sessions of the last 4 weeks ([ForecastReason.sessionsSkipped],
  /// [ForecastReason.keySessionsMissed]).
  final int sessionsDue, sessionsDone, keysDue, keysDone;

  /// VDOT the plan was built with ([FitnessState.baseline]).
  final double? baselineVdot;

  /// Reasons that rule out "ahead": the athlete is behind on something the time model can't see.
  static const _noAhead = {
    ForecastReason.longRunBehind,
    ForecastReason.sessionsSkipped,
    ForecastReason.keySessionsMissed,
    ForecastReason.missedTraining,
    ForecastReason.trainingBreak,
    ForecastReason.fatigue,
  };

  /// Computes the forecast; null without an upcoming event.
  ///
  /// A status from the target-time comparison ([paceStatus]: ahead / slightly behind / at risk)
  /// only shows when it held a week ago too (C1: two consecutive weeks); with different sides the
  /// forecast stays on track, two "behind" weeks show the milder one. A measured maximal effort
  /// (race, time trial) counts at once.
  static GoalForecast? of(UserProfile p, {required List<PlannedWorkout> plans, required List<Session> sessions, required DateTime now}) =>
      _of(p, plans: plans, sessions: sessions, now: now, persist: true);

  static int _side(ForecastStatus s) => switch (s) {
    ForecastStatus.ahead => 1,
    ForecastStatus.onTrack => 0,
    _ => -1,
  };

  static GoalForecast? _of(
    UserProfile p, {
    required List<PlannedWorkout> plans,
    required List<Session> sessions,
    required DateTime now,
    required bool persist,
  }) {
    final a = p.athlete;
    final ev = a.eventDistance;
    if (a.eventDate == null || ev == null) return null;
    final today = dayOnly(now);
    final race = dayOnly(a.eventDate!);
    if (race.isBefore(today)) return null;
    final daysLeft = daysBetween(today, race);

    // ── Fitness: the one model ([FitnessState] – baseline, today's VDOT from the evidence, race day).
    final fit = FitnessState.of(p, plans: plans, sessions: sessions, now: now, race: race);
    final planStart = fit.planStart != null && !fit.planStart!.isAfter(race) ? fit.planStart : null;
    final from = planStart == null || planStart.isAfter(today) ? today : planStart;
    final elapsedWeeks = fit.elapsedWeeks;
    final linked = fit.linked;
    final baseline = fit.baseline;
    final runs = sessions.where((s) => s.sport == Sport.run && !s.start.isAfter(now)).toList();
    final planOf = {for (final x in plans) x.id: x};
    PlannedWorkout? planFor(Session s) => s.planId != null ? planOf[s.planId] : plans.where((x) => x.sessionId == s.id).firstOrNull;
    final effort = fit.effort;
    final trend = fit.trend;
    final adherence = fit.adherence;
    final recent = fit.recentAdherence;
    final fasterEvidence = fit.fasterEvidence;
    final qm = fit.qualityRuns >= 3;
    final vdot = fit.current;
    final reasons = <ForecastReason>[];
    if (fit.breakPenalty > 0) reasons.add(ForecastReason.trainingBreak);
    if (adherence != null && adherence < 0.7) reasons.add(ForecastReason.missedTraining);
    // Chronic skipping over the last 4 weeks (IMPORTANT 4): fewer than 70 % of the sessions or 75 % of
    // the key sessions done – even when the minutes look fine (long runs done, easy runs skipped).
    final sessionsSkipped = elapsedWeeks >= 3 && fit.recentDue >= 6 && fit.recentDone < 0.7 * fit.recentDue;
    final keysMissed = elapsedWeeks >= 3 && fit.keyDue >= 3 && fit.keyDone < 0.75 * fit.keyDue;
    if (sessionsSkipped && !reasons.contains(ForecastReason.missedTraining)) reasons.add(ForecastReason.sessionsSkipped);
    if (keysMissed) reasons.add(ForecastReason.keySessionsMissed);
    final doneSessions = sessions.where((s) => !dayOnly(s.start).isBefore(from) && !s.start.isAfter(now) && s.sport != Sport.gym).length;

    // ── Race day
    final weeksLeft = daysLeft / 7;
    final gainLeft = fit.gainTo(race);
    final vdotRace = vdot + gainLeft;
    final planLine = fit.planLine;
    final confidence = effort != null ? ForecastConfidence.high : (qm ? ForecastConfidence.medium : ForecastConfidence.low);
    if (confidence != ForecastConfidence.low && planStart != null) {
      if (vdot <= planLine - 1.5) reasons.add(ForecastReason.slowerThanPlanned);
      if (vdot >= planLine + 1.5) reasons.add(ForecastReason.fasterThanPlanned);
    }
    final u = fit.uncertainty(weeksLeft);

    // Run/walk beginners without a measured effort: finish goal, no time (C6). The level default
    // (VDOT 33) predicts a 1:54 half marathon for someone who cannot run 30 min yet.
    // Same rule as the generator's race session and outlook ([PlanGenerator.finishOnly]).
    // With race times only a plan whose long runs stay far short of the race's is a finish goal (review
    // 2026-11 H4, [PlanGenerator.longRunShortFor]).
    final finishOnly =
        effort == null && (a.raceTimes.isEmpty ? PlanGenerator.finishOnly(p, start: from) : PlanGenerator.longRunShortFor(p, start: from));
    final model = GoalModel.hasModel(p) && !finishOnly;
    // Times measured from the plan's baseline (C1: a triathlon applies the run's relative gain to the
    // whole race – anchoring at today's VDOT made a perfect athlete's 70.3 slower every week).
    int? at(double v) => model ? fit.timeAt(v) : null;
    final nowSec = at(vdot);
    final raceSec = at(vdotRace);
    final fast = at(vdotRace + u), slow = at(vdotRace - u);
    // ── Long run: the longest run of the last 6 weeks against the longest planned so far, and
    // the long runs due in the last 3 weeks – ≥ 2 of them missed or < 75 % done (C3: eight
    // skipped long runs stayed "on track" because one long run 6 weeks ago still counted).
    final need = PlanGenerator.longRunTargetFor(ev);
    final sixWeeks = addDays(today, -42);
    final longest = runs.where((s) => !s.start.isBefore(sixWeeks)).fold<double>(0, (x, s) => max(x, s.distanceM / 1000));
    final pastLongs =
        plans
            .where((x) => x.sport == Sport.run && x.intensity == 'long' && !x.date.isBefore(from) && dayOnly(x.date).isBefore(today))
            .toList();
    final plannedLong = pastLongs.fold<double>(0, (x, w) => max(x, w.distanceKm ?? 0));
    final threeWeeks = DateTime(today.year, today.month, today.day - 21);
    var longShortOrMissed = 0, longDue = 0;
    for (final x in pastLongs.where((x) => !x.date.isBefore(threeWeeks) && (x.distanceKm ?? 0) >= 6)) {
      longDue++;
      final s = linked[x.id];
      if (s == null) {
        if (!x.isDone) longShortOrMissed++;
      } else if (s.distanceM > 0 && s.distanceM < 0.75 * x.distanceKm! * 1000) {
        longShortOrMissed++;
      }
    }
    final longBehind = (plannedLong >= 6 && longest < 0.75 * plannedLong) || (longDue >= 2 && longShortOrMissed >= 2);
    if (longBehind) reasons.add(ForecastReason.longRunBehind);

    // ── Fatigue: sessions of the last 14 days rated harder than intended (the recalibration's
    // "too hard" score, rule 1) – the forecast must not stay "on track" while the plan keeps
    // cutting intensity (C4).
    var tooHard = 0.0;
    final twoWeeks = DateTime(today.year, today.month, today.day - 14);
    for (final s in sessions) {
      if (s.sport == Sport.gym || s.rpe == null || dayOnly(s.start).isBefore(twoWeeks) || s.start.isAfter(now)) continue;
      if (s.source != null && s.avgHr != null) continue; // HR-estimated RPE
      final x = planFor(s);
      if (x == null || x.intensity == 'race') continue;
      tooHard += Recalibrator.rpeLoad(x.intensity, s.rpe!);
    }
    final fatigue = tooHard >= 2 || fit.chronicFatigue;
    if (fatigue) reasons.add(ForecastReason.fatigue);

    // ── Status from the target time ([paceStatus], C1: persists two weeks)
    final target = a.targetTimeSec != null && a.targetTimeSec! > 0 && raceSec != null ? a.targetTimeSec : null;
    var pace = ForecastStatus.onTrack;
    int? suggested;
    var quietAhead = false;
    ForecastStatus? prevRaw;
    if (target != null) {
      final r = raceSec! / target;
      // Ahead: running needs the B10 evidence; a triathlon target slower than what the athlete's
      // data (FTP / CSS / race time) predicts already today is ahead as well – suggest a faster one.
      final triAhead = GoalModel.isTri(ev) && nowSec != null && nowSec <= 0.97 * target;
      pace =
          r <= 0.97 && ((confidence != ForecastConfidence.low && fasterEvidence) || triAhead)
              ? ForecastStatus.ahead
              : (r <= 1.01 ? ForecastStatus.onTrack : (r <= 1.03 ? ForecastStatus.slightlyBehind : ForecastStatus.atRisk));
      // Missed training and detraining are facts, not noise: they count at once.
      final facts = reasons.contains(ForecastReason.missedTraining) || reasons.contains(ForecastReason.trainingBreak);
      if (persist && pace != ForecastStatus.onTrack && effort == null && !facts) {
        final weekAgo = DateTime(now.year, now.month, now.day - 7, now.hour, now.minute);
        final prev = _of(
          p,
          plans: plans,
          sessions: [
            for (final s in sessions)
              if (!s.start.isAfter(weekAgo)) s,
          ],
          now: weekAgo,
          persist: false,
        );
        final before = prev == null || prev.early ? ForecastStatus.onTrack : (prev.paceStatus ?? ForecastStatus.onTrack);
        prevRaw = before;
        if (_side(before) != _side(pace)) {
          pace = ForecastStatus.onTrack;
        } else if (before.index < pace.index) {
          pace = before;
        }
      }
      if (pace != ForecastStatus.onTrack) suggested = GoalModel.roundTarget(raceSec);
      // A soft target the athlete keeps beating: the faster target is suggested for the first two
      // weeks "ahead" shows, then the forecast stays quiet about it (review round 2: "set 3:34" 13
      // weeks in a row).
      // "Ahead" showed the last two weeks already when the raw status was ahead one, two and three weeks ago.
      if (persist && pace == ForecastStatus.ahead && prevRaw == ForecastStatus.ahead && effort == null) {
        final twoWeeksAgo = DateTime(now.year, now.month, now.day - 14, now.hour, now.minute);
        final prev2 = _of(
          p,
          plans: plans,
          sessions: [
            for (final s in sessions)
              if (!s.start.isAfter(twoWeeksAgo)) s,
          ],
          now: twoWeeksAgo,
          persist: false,
        );
        final threeWeeksAgo = DateTime(now.year, now.month, now.day - 21, now.hour, now.minute);
        GoalForecast? prev3;
        if (prev2 != null && !prev2.early && prev2.paceStatus == ForecastStatus.ahead) {
          prev3 = _of(
            p,
            plans: plans,
            sessions: [
              for (final s in sessions)
                if (!s.start.isAfter(threeWeeksAgo)) s,
            ],
            now: threeWeeksAgo,
            persist: false,
          );
        }
        if (prev3 != null && !prev3.early && prev3.paceStatus == ForecastStatus.ahead) {
          suggested = null;
          quietAhead = true;
        }
      }
    }
    var status = pace;
    void atLeast(ForecastStatus s) {
      if (status.index < s.index) status = s;
    }

    // Adherence (with and without a target time – a target whose predicted time still fits does
    // not make 35 % of the training "on track"): < 50 % at risk, < 70 % slightly behind.
    final missed = adherence != null && elapsedWeeks >= 3 ? adherence : 1.0;
    if (missed < 0.5) atLeast(ForecastStatus.atRisk);
    if (missed < 0.7) atLeast(ForecastStatus.slightlyBehind);
    if (sessionsSkipped || keysMissed) atLeast(ForecastStatus.slightlyBehind);

    // ── Floors (C3): long runs behind → at least slightly behind; half marathon and longer at
    // risk with ≤ 10 weeks left (≤ 6 for shorter races). Fatigue → at least slightly behind.
    if (longBehind) {
      final longRace = (need ?? 0) >= 18;
      atLeast(daysLeft ~/ 7 <= (longRace ? 10 : 6) ? ForecastStatus.atRisk : ForecastStatus.slightlyBehind);
    }
    if (fatigue) atLeast(ForecastStatus.slightlyBehind);

    // ── Beginner progression (run/walk, long session, swim ladder)
    final progression = progressionCheck(p, plans: plans, sessions: sessions, now: now);
    if (progression != null && progression.behind) {
      if (progression.longBehind && !reasons.contains(ForecastReason.longRunBehind)) reasons.add(ForecastReason.longRunBehind);
      final share = progression.longAchievedShare ?? 1;
      atLeast(
        progression.atRisk || (progression.longBehind && (weeksLeft <= 8 || share < 0.6))
            ? ForecastStatus.atRisk
            : ForecastStatus.slightlyBehind,
      );
    }

    // Never "ahead" while something the time model can't see is behind (C3), or right after a
    // week of missed training (I15: the Monday after a sick week said "ahead – set 3:33").
    if (status == ForecastStatus.ahead && (reasons.any(_noAhead.contains) || (recent ?? 1) < 0.85)) {
      status = ForecastStatus.onTrack;
      suggested = null;
    }
    if (status == ForecastStatus.onTrack) suggested = null;
    if (quietAhead) suggested = null;
    // The suggested time points the way the status does (review 2026-11 adapt-5: "at risk" after two sick weeks
    // offered 3:42 for a 3:50 target): behind → only a slower target, ahead → only a faster one. A status that
    // the long runs, missed sessions or fatigue set (the time model alone would be ahead) gets its reasons, no time.
    if (suggested != null && target != null && (status == ForecastStatus.ahead ? suggested >= target : suggested <= target)) {
      suggested = null;
    }
    if (reasons.contains(ForecastReason.fasterThanPlanned) && status != ForecastStatus.ahead) {
      reasons.remove(ForecastReason.fasterThanPlanned);
    }

    // Expected line: from the plan start (baseline) to race day.
    final planned = <(DateTime, double)>[];
    if (planStart != null) {
      final totalWeeks = daysBetween(planStart, race) / 7;
      final training = daysBetween(planStart, startOfWeek(race)) / 7;
      for (var w = 0.0; w <= totalWeeks + 1e-9; w += max(1.0, totalWeeks / 12)) {
        planned.add((addDays(planStart, (w * 7).round()), baseline + GoalModel.gain(p, min(w, max(0, training)))));
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
      paceStatus: target == null ? null : pace,
      finishOnly: finishOnly,
      setAsideTargetSec: finishOnly && (a.targetTimeSec ?? 0) > 0 ? a.targetTimeSec : null,
      eventName: a.eventName,
      sessionsDue: fit.recentDue,
      sessionsDone: fit.recentDone,
      keysDue: fit.keyDue,
      keysDone: fit.keyDone,
      baselineVdot: planStart == null ? null : baseline,
    );
  }

  /// Dead band of [qualityRatio] ([FitnessState.deadBand]).
  static const deadBand = FitnessState.deadBand;

  /// [FitnessState.qualityRatio].
  static double qualityRatio(Session s, {required double km, required int stepSec, required int planSec}) =>
      FitnessState.qualityRatio(s, km: km, stepSec: stepSec, planSec: planSec);

  /// Planned workouts to update when the target changes to [newTarget]: race-pace steps of
  /// upcoming peak / taper workouts and the race itself follow the new goal – with the generator's
  /// rule (C3; [PlanGenerator] `_goalPace`): the target check from today on the one fitness model
  /// ([FitnessState] from [plans] and [sessions]) – within reach → race-pace work and the race at the faster of
  /// target and realistic time; out of reach → both at the realistic time and the race says the goal is out of
  /// reach for now (audit RUN-9 / T1: the race paces what the goal-pace work practised). A target slower than
  /// that pace adds the realistic pacing to the race (IMPORTANT 5). With [l] the race's description is rebuilt
  /// (else the old target's time is replaced in it).
  static Map<String, Map<String, dynamic>> retarget(
    UserProfile p,
    List<PlannedWorkout> plans,
    int newTarget, {
    required DateTime now,
    List<Session> sessions = const [],
    AppLocalizations? l,
  }) {
    final meters = Vdot.distances[p.athlete.eventDistance];
    if (meters == null) return const {};
    final old = p.athlete.targetTimeSec;
    final q = p.copyWith(athlete: p.athlete.merge({'targetTimeSec': newTarget}));
    final fit = FitnessState.of(q, plans: plans, sessions: sessions, now: now);
    final t = GoalModel.check(q, start: now, fitness: fit);
    final behind = t != null && t.status != TargetStatus.ok;
    // Race-pace work: the faster of target and realistic within reach, else the realistic time.
    final goal = t == null ? newTarget : (behind ? t.realisticSec : t.ambitionSec);
    final pace = (goal / (meters / 1000)).round();
    final raceSec = goal;
    final racePace = pace;
    final km = meters / 1000;
    final out = <String, Map<String, dynamic>>{};
    for (final x in plans) {
      if (x.status != 'planned' || dayOnly(x.date).isBefore(dayOnly(now)) || x.sport != Sport.run) continue;
      final race = x.intensity == 'race';
      // Peak and taper: the goal-pace sets of the taper follow the target too.
      if (!race && x.phase != 'peak' && x.phase != 'taper') continue;
      var changed = false;
      final steps = [
        for (final s in x.steps)
          // Race-pace sets are zone M; the race's own step is I / T / M by distance.
          if (s.isWork && (s.zone == 'M' || race) && s.paceMin != null)
            () {
              changed = true;
              final half = race ? 3 : ((s.paceMax! - s.paceMin!) ~/ 2).clamp(3, 5);
              final c = race ? racePace : pace;
              return WorkoutStep(
                kind: s.kind,
                durationSec: s.durationSec,
                distanceM: s.distanceM,
                zone: s.zone,
                paceMin: c - half,
                paceMax: c + half,
                hrMin: s.hrMin,
                hrMax: s.hrMax,
                note: s.note,
              );
            }()
          else
            s,
      ];
      if (!changed && !race) continue;
      String? description;
      if (race && l != null) {
        description = raceDescription(
          l,
          x.description,
          target: newTarget,
          realisticSec: t?.realisticSec,
          behind: behind,
          raceSec: raceSec,
          km: km,
        );
      } else if (race && old != null) {
        description = x.description.replaceAll(clock(old), clock(newTarget));
      }
      out[x.id] = {
        if (changed) 'steps': steps.map((s) => s.toMap()).toList(),
        if (description != null) 'description': description,
        if (race) 'durationMin': (raceSec / 60).round(),
      };
    }
    return out;
  }

  /// [description] of a running race session with its goal lines (the generator's: "Zielzeit X …",
  /// "Ziel X ist außer Reichweite …" / the older "Ziel X – starte mit Y" + the race text, or the plain race text)
  /// replaced for [target]; other lines (fuelling, run/walk) stay. [raceSec]: the time the race is paced at –
  /// faster than [target]: the realistic time and pace follow the goal line.
  static String raceDescription(
    AppLocalizations l,
    String description, {
    required int target,
    required int? realisticSec,
    required bool behind,
    required int raceSec,
    required double km,
  }) {
    // A line matches a template when it starts and ends like it around the placeholders.
    const mark = '\u0000';
    bool like(String line, String template) {
      final parts = template.split(mark);
      return line.startsWith(parts.first) && line.endsWith(parts.last) && line.length >= parts.first.length + parts.last.length;
    }

    final templates = [
      l.wRaceDesc,
      l.wRaceGoalDesc(mark),
      l.wRaceGoalStart(mark, mark),
      l.wRaceGoalBehind(mark, mark, mark),
      l.wRaceRealistic(mark, mark),
      l.wRaceRealisticPace(mark, mark),
    ];
    final lines = description.isEmpty ? <String>[] : description.split('\n');
    var at = lines.indexWhere((x) => templates.any((t) => like(x, t)));
    lines.removeWhere((x) => templates.any((t) => like(x, t)));
    if (at < 0 || at > lines.length) at = lines.length;
    String perKm(int sec) => '${clock((sec / km).round())}/km';
    final goal = [
      if (behind && realisticSec != null)
        l.wRaceGoalBehind(clock(target), perKm(realisticSec), clock(GoalModel.roundTarget(realisticSec)))
      else
        l.wRaceGoalDesc(clock(target)),
      // (The race is paced at [raceSec], the most the fitness gives – no "pick it up" beyond it: verifier G1-V5.)
      if (!behind && raceSec < target - 30) l.wRaceRealisticPace(clock(GoalModel.roundTarget(raceSec)), perKm(raceSec)),
    ];
    lines.insertAll(at, goal);
    return lines.join('\n');
  }
}
