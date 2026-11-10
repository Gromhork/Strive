import 'dart:math';

import '../data/models.dart';
import 'event_spec.dart';
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
  });

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
/// * **Fitness now**: VDOT from the profile's race times (Daniels [7]; confidence high when a
///   race within × 2.5 of the event distance exists, else medium); else the best 5 km+ effort of
///   the runs of the last 90 days ([runBestEfforts], medium) – but never above the level
///   default: training runs are mostly submaximal, and the target check / plan paces keep the
///   profile's VDOT until the recalibration takes an effort over; else the level default (low).
///   Multisport: legs from FTP / CSS as in [GoalModel.predict] (medium with FTP and swim test).
/// * **Race day**: `GoalModel.timeAt(VDOT_now, gain(weeks − 1))` – exactly the *realistic* value
///   of [GoalModel.check], so the suggestion always passes the check and the feasibility card.
///   Marathon from a race ≤ 10 km below the advanced level: Riegel with exponent 1.08 ([riegel],
///   §1.2 – 1.06 / VDOT are too optimistic for recreational marathoners), scaled by the same
///   relative gain; the slower of the two counts.
/// * **Range**: VDOT gain ± u with u = 2 (race times) · 1.5 (best efforts) · 3.5 (level default)
///   + 0.04 / week, as in GoalForecast.
TargetSuggestion suggestTargetTime(UserProfile p, String eventKey, DateTime eventDate, {List<Session> sessions = const [], DateTime? now}) {
  final today = now ?? DateTime.now();
  final q = p.copyWith(athlete: p.athlete.merge({'eventDistance': eventKey, 'eventDate': eventDate, 'targetTimeSec': null}));
  final a = q.athlete;
  final weeks = GoalModel.weeksUntil(eventDate, today);
  final finish =
      !GoalModel.hasModel(q) ||
      PlanGenerator.runWalkStartFor(q) != null ||
      (q.level == 'beginner' && EventSpec.of(eventKey)?.beginnerOk == false);
  if (finish) return TargetSuggestion(basis: TargetBasis.finishOnly, confidence: TargetConfidence.low, weeks: weeks);

  // ── Fitness now
  final (profileVdot, guessed) = GoalModel.currentVdot(q);
  var vdot = profileVdot;
  var basis = guessed ? TargetBasis.levelEstimate : TargetBasis.raceTimes;
  if (guessed) {
    final recent = sessions.where((s) => !s.start.isAfter(today) && today.difference(s.start).inDays <= 90).toList();
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

  // ── Race day
  final g = GoalModel.gain(q, max(0, weeks - 1).toDouble());
  final u =
      switch (basis) {
        TargetBasis.raceTimes => 2.0,
        TargetBasis.bestEfforts => 1.5,
        _ => 3.5,
      } +
      0.04 * weeks;
  final time = GoalModel.timeAt(q, vdot, g)!;
  var scale = 1.0;
  if (eventKey == 'm' && basis == TargetBasis.raceTimes && q.level != 'advanced') {
    // Riegel 1.08 from the best race ≤ 10 km (no HM / marathon time known).
    (String, int)? from;
    for (final e in a.raceTimes.entries) {
      final d = Vdot.distances[e.key];
      if (d == null || e.value <= 0) continue;
      if (d > 10000) {
        from = null;
        break;
      }
      if (from == null || Vdot.fromRace(d, e.value) > Vdot.fromRace(Vdot.distances[from.$1]!, from.$2)) from = (e.key, e.value);
    }
    if (from != null) {
      final r = riegel(from.$2, Vdot.distances[from.$1]!, meters, novice: true) * time / GoalModel.predict(q, vdot)!;
      if (r > time) scale = r / time;
    }
  }
  int at(double gain) => (GoalModel.timeAt(q, vdot, gain)! * scale).round();
  final sec = GoalModel.roundTarget(at(g));
  return TargetSuggestion(
    sec: sec,
    fastSec: min(sec, GoalModel.roundTarget(at(g + u))),
    slowSec: max(sec, GoalModel.roundTarget(at(max(g - u, 20 - vdot)))),
    basis: basis,
    confidence: confidence,
    vdotNow: vdot,
    vdotRaceDay: vdot + g,
    weeks: weeks,
  );
}

/// Ratio of the longer to the shorter of two distances (infinite when one is unknown).
double _ratio(double? a, double b) => a == null || a <= 0 || b <= 0 ? double.infinity : max(a, b) / min(a, b);
