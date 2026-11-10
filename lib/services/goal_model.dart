import 'dart:math';

import '../core/format.dart';
import '../data/models.dart';
import 'zones.dart';

/// How a target time compares with what the weeks to race day can realistically give.
enum TargetStatus { ok, ambitious, unrealistic }

/// Target-time model (docs/training-science.md §1.12): how much fitness (VDOT) a plan of a
/// given length can add, and what race time that predicts.
///
/// * **Improvement rate** (Daniels [7]: with consistent training raise VDOT by ~1 point every
///   4–6 weeks; untrained people improve faster – VO2max +10–20 % within 8–12 weeks of
///   endurance training, Milanović 2015 [80]; gains level off with training age, Bacon 2013
///   [81]). Modelled as a saturating curve `gain(w) = cap · (1 − e^(−rate·w / cap))`: the slope
///   at the start is `rate` VDOT/week, the curve flattens towards `cap` within one training
///   cycle. beginner 0.45/wk (cap 10) · intermediate 0.22/wk (cap 5) · advanced 0.15/wk (cap 3).
///   EASY difficulty × 0.85, CHALLENGING × 1.1; age ≥ 50 × 0.85, ≥ 65 × 0.7 (slower adaptation).
/// * **Responders**: the individual response to the same training varies widely (HERITAGE,
///   Bouchard 1999 [82]); [optimistic] = 1.6 × the expected gain is what a high responder may
///   reach – a goal between the two is *ambitious*, beyond it *unrealistic*.
/// * **Weeks**: every week before race week counts; the taper only realises the gain.
/// * **Triathlon**: swim from CSS (+10 s / 100 m open water), bike from FTP with a flat-course
///   power model (or a level speed without FTP), the run from VDOT × 1.08 (70.3: × 1.12 – running
///   off the bike); the relative improvement of the run (VDOT) is applied to the whole race.
class GoalModel {
  /// Most weeks a plan aligns to an event (a longer lead time is not planned yet).
  static const maxEventWeeks = 52;

  /// The race-specific part of a long plan; earlier weeks are a base "pre-plan" block (general
  /// endurance, lower long-run cap and volume ceiling). 20 weeks: the length of amateur marathon
  /// plans (Pfitzinger / Higdon 16–20 weeks) – a 30-week block repeated the race-specific long
  /// run ~20 times (coach review 3).
  static const specificWeeks = 20;

  /// Factor of the expected gain a high responder may reach.
  static const optimistic = 1.6;

  /// Weeks from the plan start's week to race week (incl. race week).
  static int weeksUntil(DateTime event, DateTime start) =>
      // Whole days (a daylight-saving change makes one day 23 or 25 hours long).
      ((startOfWeek(event).difference(startOfWeek(start)).inHours / 24).round() / 7).floor() + 1;

  static (double, double) _params(UserProfile p) {
    var (rate, cap) = switch (p.level) {
      'advanced' => (0.15, 3.0),
      'intermediate' => (0.22, 5.0),
      _ => (0.45, 10.0),
    };
    final f =
        switch (p.athlete.difficulty) {
          'easy' => 0.85,
          'challenging' => 1.1,
          _ => 1.0,
        } *
        ((p.age ?? 30) >= 65 ? 0.7 : ((p.age ?? 30) >= 50 ? 0.85 : 1.0));
    return (rate * f, cap * f);
  }

  /// Expected VDOT gain after [weeks] of consistent training (see class doc).
  static double gain(UserProfile p, double weeks) {
    if (weeks <= 0) return 0;
    final (rate, cap) = _params(p);
    return cap * (1 - exp(-rate * weeks / cap));
  }

  /// Gain of the weeks [from] … [to] of a plan (diminishing returns).
  static double gainBetween(UserProfile p, double from, double to) => gain(p, to) - gain(p, max(0, from));

  /// Current running VDOT of [p] (race times, else the level default) and whether it is a guess.
  static (double, bool) currentVdot(UserProfile p) {
    final v = Vdot.of(p.athlete);
    return v == null ? (Vdot.defaultFor(p.level), true) : (v, false);
  }

  static const _triLegs = {
    'sprint': (750.0, 20.0, 5000.0, 300),
    'olympic': (1500.0, 40.0, 10000.0, 360),
    '70.3': (1900.0, 90.0, 21097.5, 480),
  };

  static bool isTri(String? event) => _triLegs.containsKey(event);

  /// Steady speed (km/h) on a flat course at [frac] × FTP: P·η = v·(Crr·m·g + ½·ρ·CdA·v²),
  /// η 0.975, Crr 0.005, ρ 1.2, CdA 0.32 / 0.30 / 0.27 by level, × 0.93 for turns, hills and wind.
  static double bikeKmh(int ftp, double weightKg, String level, double frac) {
    final cda = switch (level) {
      'advanced' => 0.27,
      'intermediate' => 0.30,
      _ => 0.32,
    };
    final p = ftp * frac * 0.975;
    final roll = 0.005 * (weightKg + 9) * 9.81;
    var lo = 1.0, hi = 25.0;
    for (var i = 0; i < 50; i++) {
      final v = (lo + hi) / 2;
      if (v * (roll + 0.6 * cda * v * v) > p) {
        hi = v;
      } else {
        lo = v;
      }
    }
    return lo * 3.6 * 0.93;
  }

  /// Predicted finishing time (s) of [p]'s event at running fitness [vdot]; null for events
  /// without a model. Triathlon uses the profile's CSS / FTP (or level values).
  static int? predict(UserProfile p, double vdot) {
    final ev = p.athlete.eventDistance;
    final meters = Vdot.distances[ev];
    if (meters != null) return Vdot.raceTime(vdot, meters);
    final legs = _triLegs[ev];
    if (legs == null) return null;
    final a = p.athlete;
    final (swimM, bikeKm, runM, transition) = legs;
    final css = SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(p.level);
    final kmh =
        a.ftp != null
            ? bikeKmh(a.ftp!, p.weightKg, p.level, switch (ev) {
              'sprint' => 0.88,
              'olympic' => 0.85,
              _ => 0.77,
            })
            : switch (p.level) {
              'advanced' => 33.0,
              'intermediate' => 29.0,
              _ => 25.0,
            };
    final runF = ev == '70.3' ? 1.12 : 1.08;
    return (swimM / 100 * (css + 10) + bikeKm / kmh * 3600 + Vdot.raceTime(vdot, runM) * runF + transition).round();
  }

  /// Predicted time after a VDOT [gain] from [vdot]: running directly, triathlon by the
  /// relative improvement of a 10 km run applied to the whole race.
  static int? timeAt(UserProfile p, double vdot, double gain) {
    if (Vdot.distances.containsKey(p.athlete.eventDistance)) return predict(p, vdot + gain);
    final base = predict(p, vdot);
    if (base == null) return null;
    return (base * Vdot.raceTime(vdot + gain, 10000) / Vdot.raceTime(vdot, 10000)).round();
  }

  /// Whether a target-time check makes sense: running events always; triathlon only with
  /// some real data (race time, FTP or swim test) – otherwise the goal is to finish.
  static bool hasModel(UserProfile p) {
    final a = p.athlete;
    if (Vdot.distances.containsKey(a.eventDistance)) return true;
    return isTri(a.eventDistance) && (a.raceTimes.isNotEmpty || a.ftp != null || SwimZones.fromTests(a.swim400Sec, a.swim200Sec) != null);
  }

  /// A target time rounded so it reads well and errs on the slow side: ≥ 1 h to the minute,
  /// else to 10 s.
  static int roundTarget(int sec) => sec >= 3600 ? (sec / 60).ceil() * 60 : (sec / 10).ceil() * 10;

  /// Target-time check for a plan starting at [start] (null without event date, distance,
  /// target time or model).
  static TargetCheck? check(UserProfile p, {required DateTime start}) {
    final a = p.athlete;
    final target = a.targetTimeSec;
    if (a.eventDate == null || a.eventDistance == null || target == null || target <= 0 || !hasModel(p)) return null;
    final weeks = weeksUntil(a.eventDate!, start);
    if (weeks < 1) return null;
    final (vdot, guessed) = currentVdot(p);
    TargetStatus statusFor(int w) {
      final g = gain(p, (w - 1).toDouble());
      final realistic = timeAt(p, vdot, g)!;
      final best = timeAt(p, vdot, g * optimistic)!;
      return target >= realistic * 0.995 ? TargetStatus.ok : (target >= best ? TargetStatus.ambitious : TargetStatus.unrealistic);
    }

    final g = gain(p, (weeks - 1).toDouble());
    final status = statusFor(weeks);
    DateTime? later;
    if (status != TargetStatus.ok) {
      final race = dayOnly(a.eventDate!);
      for (var w = weeks + 1; w <= maxEventWeeks && later == null; w++) {
        if (statusFor(w) == TargetStatus.ok) later = DateTime(race.year, race.month, race.day + 7 * (w - weeks));
      }
    }
    final meters = Vdot.distances[a.eventDistance];
    return TargetCheck(
      status: status,
      targetSec: target,
      currentSec: predict(p, vdot)!,
      realisticSec: timeAt(p, vdot, g)!,
      optimisticSec: timeAt(p, vdot, g * optimistic)!,
      currentVdot: vdot,
      gainVdot: g,
      goalVdot: meters == null ? null : Vdot.fromRace(meters, target),
      guessed: guessed,
      laterDate: later,
      weeks: weeks,
    );
  }
}

/// Result of [GoalModel.check].
class TargetCheck {
  const TargetCheck({
    required this.status,
    required this.targetSec,
    required this.currentSec,
    required this.realisticSec,
    required this.optimisticSec,
    required this.currentVdot,
    required this.gainVdot,
    required this.guessed,
    required this.weeks,
    this.goalVdot,
    this.laterDate,
  });

  final TargetStatus status;
  final int targetSec;

  /// Predicted time today, at race day with the expected gain, and with a high response.
  final int currentSec, realisticSec, optimisticSec;
  final double currentVdot;

  /// Expected VDOT gain until race day.
  final double gainVdot;

  /// VDOT the target time needs (running events).
  final double? goalVdot;

  /// The current fitness is a level default (no race time) – the check is a rough guide.
  final bool guessed;
  final int weeks;

  /// First race date (same weekday) by which the target becomes realistic (≤ 52 weeks).
  final DateTime? laterDate;

  /// Realistic target time to suggest (rounded, on the slow side).
  int get suggestedSec => GoalModel.roundTarget(realisticSec);
}
