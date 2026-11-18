import 'dart:math';

import '../core/format.dart';
import '../data/models.dart';
import 'event_spec.dart';
import 'fitness_state.dart';
import 'goal_model.dart';
import 'insights.dart';
import 'plan_generator.dart';
import 'zones.dart';

/// Where the current fitness of a [TargetSuggestion] comes from.
enum TargetBasis { raceTimes, bestEfforts, levelEstimate, finishOnly }

/// How much the suggestion can be trusted (shown as a hint next to it).
enum TargetConfidence { low, medium, high }

/// A suggested target time for an event ([suggestTargetTime]).
class TargetSuggestion {
  const TargetSuggestion({
    required this.basis,
    required this.confidence,
    required this.weeks,
    this.sec,
    this.fastSec,
    this.slowSec,
    this.vdotNow,
    this.vdotRaceDay,
    this.targetRaced,
  });

  /// A finish goal ([finishOnly]) next to a target the athlete entered: true when the plan races at that target
  /// all the same (it survives the finish rule of capped / too few long runs – [PlanGenerator.generate]), false
  /// when the plan stays finish-only and the target is set aside ([PlanGenerator.targetSetAside]); null without
  /// a target or with a suggested time.
  final bool? targetRaced;

  /// Suggested target (s, rounded on the slow side); null for a finish goal.
  final int? sec;

  /// Plausible range on race day (high / low response, uncertainty of the fitness estimate).
  final int? fastSec, slowSec;
  final TargetBasis basis;
  final TargetConfidence confidence;

  /// Running VDOT today and expected on race day (triathlon: the run leg's fitness).
  final double? vdotNow, vdotRaceDay;

  /// Weeks from now's week to race week (incl. race week, [GoalModel.weeksUntil]).
  final int weeks;

  bool get finishOnly => basis == TargetBasis.finishOnly;
}

/// Suggests a realistic target time for [eventKey] on [eventDate] (docs/training-science.md
/// §1.2, §1.12) – the value the goal editor pre-fills.
///
/// * **Finish goal** (no time): ultra, cycling and open-water events (terrain, weather and
///   pacing dominate; the improvement model is a running model – [GoalModel.hasModel]),
///   triathlon / duathlon without any data (race time, FTP, swim test), athletes who start on
///   run/walk ([PlanGenerator.runWalkStartFor]) and beginners at distances that are no beginner
///   goal ([EventSpec.beginnerOk]: marathon, ultra, Ironman, 5 km open water).
/// * **One model** ([FitnessState], review round 2): with the plan ([plans]) the fitness of the plan
///   that runs – today's VDOT from the evidence (efforts, quality runs, the recalibrated VDOT) or the
///   plan's line, + the gain of the weeks to race day – exactly the goal forecast's race-day value and
///   the *realistic* value of [GoalModel.check] given the same [FitnessState] (C4: the suggestion got
///   slower week by week mid-plan because it restarted from the plan-start VDOT). Without plans: the
///   profile alone ([FitnessState.fromProfile]; a plan stored on the profile counts as trained as
///   planned).
/// * **Fitness now without a plan**: VDOT from the profile's race times (Daniels [7]; confidence high
///   when a race within × 2.5 of the event distance exists, else medium); else the best 5 km+ effort
///   of the runs of the last 90 days ([runBestEfforts], medium) – but never above the level
///   default: training runs are mostly submaximal; else the level default (low). Multisport: legs
///   from FTP / CSS as in [GoalModel.predict] (medium with FTP and swim test). Marathon from races ≤
///   10 km: Riegel 1.08 inside [GoalModel.predict] ([GoalModel.marathonScale]) – shared with the
///   check, no separate correction here any more.
/// * **Range**: VDOT gain ± u ([FitnessState.uncertainty]; best efforts 1.5).
TargetSuggestion suggestTargetTime(
  UserProfile p,
  String eventKey,
  DateTime eventDate, {
  List<Session> sessions = const [],
  List<PlannedWorkout>? plans,
  DateTime? now,
  int? target,
}) {
  final today = now ?? DateTime.now();
  final q = p.copyWith(athlete: p.athlete.merge({'eventDistance': eventKey, 'eventDate': eventDate, 'targetTimeSec': null}));
  final a = q.athlete;
  final weeks = GoalModel.weeksUntil(eventDate, today);

  // ── Fitness now
  final fit =
      plans == null
          ? FitnessState.fromProfile(q, now: today)
          : FitnessState.of(q, plans: plans, sessions: sessions, now: today, race: eventDate);
  // Same plan as the forecast's: from the running plan's start (C6 finish goals depend on its long runs).
  final from = fit.planStart ?? dayOnly(today);
  if (PlanGenerator.finishOnly(q, start: from)) {
    // With the athlete's own target the plan may race after all (the target survives some finish rules) – or not.
    final raced =
        (target ?? 0) > 0
            ? !PlanGenerator.targetSetAside(q.copyWith(athlete: q.athlete.merge({'targetTimeSec': target})), start: from)
            : null;
    return TargetSuggestion(basis: TargetBasis.finishOnly, confidence: TargetConfidence.low, weeks: weeks, targetRaced: raced);
  }
  final guessed = fit.guessed;
  var vdot = fit.current;
  var basis = guessed ? TargetBasis.levelEstimate : TargetBasis.raceTimes;
  if (guessed && fit.planStart == null) {
    final profileVdot = vdot;
    final recent = sessions.where((s) => !s.start.isAfter(today) && daysBetween(s.start, today) <= 90).toList();
    double? best;
    for (final e in runBestEfforts(recent).values) {
      if (!Vdot.distances.containsKey(e.key) || e.meters < 5000) continue;
      final v = Vdot.fromRace(e.meters, e.seconds);
      if (best == null || v > best) best = v;
    }
    if (best != null) {
      vdot = min(best, profileVdot);
      basis = TargetBasis.bestEfforts;
    }
  }
  final multi = GoalModel.isTri(eventKey);
  final meters = Vdot.distances[eventKey] ?? 0;
  final confidence = switch (basis) {
    TargetBasis.raceTimes when !multi && a.raceTimes.keys.any((k) => _ratio(Vdot.distances[k], meters) <= 2.5) => TargetConfidence.high,
    TargetBasis.raceTimes || TargetBasis.bestEfforts => TargetConfidence.medium,
    _ when multi && a.ftp != null && SwimZones.fromTests(a.swim400Sec, a.swim200Sec) != null => TargetConfidence.medium,
    _ => TargetConfidence.low,
  };

  // ── Race day: the one model's gain to race day, times measured from its baseline (C1).
  final g = fit.gainTo(eventDate);
  final u = (basis == TargetBasis.bestEfforts ? 1.5 : fit.uncertainty(0)) + 0.04 * weeks;
  int at(double v) => fit.timeAt(v, p: q)!;
  final sec = GoalModel.roundTarget(at(vdot + g));
  return TargetSuggestion(
    sec: sec,
    fastSec: min(sec, GoalModel.roundTarget(at(vdot + g + u))),
    slowSec: max(sec, GoalModel.roundTarget(at(max(vdot + g - u, 20)))),
    basis: basis,
    confidence: confidence,
    vdotNow: vdot,
    vdotRaceDay: vdot + g,
    weeks: weeks,
  );
}

/// Ratio of the longer to the shorter of two distances (infinite when one is unknown).
double _ratio(double? a, double b) => a == null || a <= 0 || b <= 0 ? double.infinity : max(a, b) / min(a, b);
