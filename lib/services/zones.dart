import 'dart:math';

import '../core/sport.dart';
import '../data/models.dart';

/// Training zones derived from field tests / race times.
/// Formulas: Daniels & Gilbert VDOT, Riegel, Tanaka HRmax, Karvonen,
/// Coggan power zones, CSS (Wakayoshi). See docs/training-science.md.
class Vdot {
  static const distances = {'5k': 5000.0, '10k': 10000.0, 'hm': 21097.5, 'm': 42195.0};

  /// VO2 cost (ml/kg/min) of running at [v] m/min.
  static double vo2(double v) => -4.60 + 0.182258 * v + 0.000104 * v * v;

  /// Fraction of VO2max sustainable for [tMin] minutes.
  static double pctMax(double tMin) => 0.8 + 0.1894393 * exp(-0.012778 * tMin) + 0.2989558 * exp(-0.1932605 * tMin);

  static double fromRace(double meters, int seconds) {
    final t = seconds / 60;
    return vo2(meters / t) / pctMax(t);
  }

  /// Speed (m/min) that needs [o] ml/kg/min.
  static double speedForVo2(double o) => (-0.182258 + sqrt(0.182258 * 0.182258 + 4 * 0.000104 * (4.60 + o))) / (2 * 0.000104);

  /// Predicted race time (s) for [meters] at a given VDOT (bisection).
  static int raceTime(double vdot, double meters) {
    var lo = 1.0, hi = 600.0;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (fromRace(meters, (mid * 60).round()) > vdot) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return ((lo + hi) / 2 * 60).round();
  }

  /// Best VDOT from the athlete's race times (most recent data is not tracked → best).
  static double? of(AthleteData a) {
    double? best;
    for (final e in a.raceTimes.entries) {
      final d = distances[e.key];
      if (d == null || e.value <= 0) continue;
      final v = fromRace(d, e.value);
      if (best == null || v > best) best = v;
    }
    return best;
  }

  /// Rough VDOT default by level when no race time is known.
  static double defaultFor(String level) => switch (level) {
    'advanced' => 50,
    'intermediate' => 42,
    _ => 33,
  };
}

int _secPerKm(double mPerMin) => (60000 / mPerMin).round();

/// Daniels pace zones in sec/km (faster bound first).
class PaceZones {
  final double vdot;
  final int easyFast, easySlow, marathon, threshold, interval, repetition;

  PaceZones._(this.vdot, this.easyFast, this.easySlow, this.marathon, this.threshold, this.interval, this.repetition);

  factory PaceZones(double vdot) => PaceZones._(
    vdot,
    _secPerKm(Vdot.speedForVo2(0.74 * vdot)),
    _secPerKm(Vdot.speedForVo2(0.62 * vdot)),
    (Vdot.raceTime(vdot, 42195) / 42.195).round(),
    _secPerKm(Vdot.speedForVo2(0.88 * vdot)),
    _secPerKm(Vdot.speedForVo2(0.975 * vdot)),
    (Vdot.raceTime(vdot, 1609.34) / 1.60934).round(),
  );

  /// (fast, slow) bounds for a zone code.
  (int, int) range(String zone) => switch (zone) {
    'E' => (easyFast, easySlow),
    'L' => (easyFast + 5, easySlow),
    'M' => (marathon - 5, marathon + 5),
    'T' => (threshold - 4, threshold + 4),
    'I' => (interval - 4, interval + 4),
    'R' => (repetition - 3, repetition + 3),
    'REC' => (easySlow, easySlow + 40),
    _ => (easyFast, easySlow),
  };
}

/// The HRmax that heart-rate signals are judged against, and how much it can be trusted
/// (docs/training-science.md §5, §12.1).
///
/// * **measured** – the athlete entered a max HR in the profile;
/// * else **observed** – the highest max HR of a hard session (RPE ≥ 7 or average HR
///   ≥ 85 % of the prediction) in the last year, when it is above the prediction (only
///   ever raises it; spikes > prediction + 25 bpm are treated as sensor artefacts);
/// * else **predicted** (Tanaka / Gulati, SEE ≈ ±10 bpm – [predictionSd]).
///
/// Only a measured value counts as [measured]: an observed peak is a lower bound of the
/// true HRmax, so HR keeps its reduced weight.
class HrMax {
  const HrMax(this.bpm, {required this.measured, this.observed = false});

  final int bpm;
  final bool measured;

  /// Raised from the athlete's own hard sessions.
  final bool observed;

  /// Standard error of the HRmax prediction equations (Tanaka 2001: ≈ ±10 bpm).
  static const predictionSd = 10;

  static HrMax of(UserProfile p, {Iterable<Session> sessions = const [], DateTime? now}) {
    if (p.maxHr != null) return HrMax(p.maxHr!, measured: true);
    final predicted = p.estimatedMaxHr;
    now ??= DateTime.now();
    var best = 0;
    for (final s in sessions) {
      final m = s.maxHr;
      if (m == null || !s.sport.isCardio || now.difference(s.start).inDays > 365) continue; // time span
      if (m > predicted + 25 || (s.avgHr != null && m < s.avgHr!)) continue;
      final hard = (s.rpe ?? 0) >= 7 || (s.avgHr ?? 0) >= 0.85 * predicted;
      if (hard && m > best) best = m;
    }
    return best > predicted ? HrMax(best, measured: false, observed: true) : HrMax(predicted, measured: false);
  }
}

/// Heart-rate zones (5-zone %HRmax model, Seiler/Olympiatoppen). Karvonen when resting HR is known.
class HrZones {
  final int max;
  final int? rest;
  HrZones(this.max, [this.rest]);

  static int tanaka(int age) => (208 - 0.7 * age).round();

  /// HRmax prediction for women (Gulati 2010, St. James Women Take Heart Project).
  static int gulati(int age) => (206 - 0.88 * age).round();

  static const _pct = [0.55, 0.72, 0.82, 0.87, 0.92, 1.0];
  static const _hrr = [0.40, 0.60, 0.72, 0.80, 0.88, 1.0];

  /// Zone 1..5 → (low, high) bpm.
  (int, int) zone(int z) {
    final i = z.clamp(1, 5);
    if (rest != null) {
      final r = rest!, span = max - r;
      return ((r + _hrr[i - 1] * span).round(), (r + _hrr[i] * span).round());
    }
    return ((max * _pct[i - 1]).round(), (max * _pct[i]).round());
  }

  int zoneOf(int bpm) {
    for (var z = 5; z >= 1; z--) {
      if (bpm >= zone(z).$1) return z;
    }
    return 1;
  }
}

/// Coggan power zones (% FTP).
class PowerZones {
  final int ftp;
  PowerZones(this.ftp);
  static const _z = {
    'Z1': (0.0, 0.55),
    'Z2': (0.56, 0.75),
    'Z3': (0.76, 0.90),
    'SS': (0.88, 0.94),
    'Z4': (0.91, 1.05),
    'Z5': (1.06, 1.20),
    'Z6': (1.21, 1.50),
    'Z7': (1.51, 2.5),
  };
  (int, int) range(String zone) {
    final r = _z[zone] ?? _z['Z2']!;
    return ((ftp * r.$1).round(), (ftp * r.$2).round());
  }

  /// FTP estimate without a test: W/kg by level (rough population values).
  static int estimate(String level, double weightKg) =>
      (weightKg *
              switch (level) {
                'advanced' => 3.6,
                'intermediate' => 2.8,
                _ => 2.0,
              })
          .round();
}

/// Critical swim speed zones (sec / 100 m).
/// Duration estimate of one structured step – the single formula used by the plan
/// generator, the editors, the program list and the calendar, so a workout shows the
/// same duration everywhere. Distance steps use the step's own pace target, else the
/// athlete's easy pace (run), ~27 km/h (ride) or CSS + 12 s (swim, plus ~10 s per
/// repeat for the wall).
int estimateStepSec(WorkoutStep s, Sport sport, {required int easyPace, required int css}) {
  if (s.durationSec != null) return s.durationSec!;
  final d = s.distanceM ?? 0;
  if (d <= 0) return 0;
  return switch (sport) {
    Sport.swim => (d / 100 * (s.paceMax ?? css + 12)).round() + 10,
    Sport.ride => (d / 1000 * 133).round(),
    _ => (d / 1000 * ((s.paceMin ?? easyPace) + (s.paceMax ?? easyPace)) / 2).round(),
  };
}

/// Total duration of [steps] for [p] (see [estimateStepSec]).
int estimateStepsSec(List<WorkoutStep> steps, Sport sport, UserProfile p) {
  final easy = PaceZones(Vdot.of(p.athlete) ?? Vdot.defaultFor(p.level)).easySlow;
  final css = SwimZones.fromTests(p.athlete.swim400Sec, p.athlete.swim200Sec) ?? SwimZones.defaultFor(p.level);
  return steps.fold(0, (x, s) => x + estimateStepSec(s, sport, easyPace: easy, css: css));
}

/// Minutes of a program for [p]: structured endurance programs from their steps,
/// everything else from [WorkoutTemplate.estimatedMinutes].
int templateMinutes(WorkoutTemplate t, UserProfile p) {
  if (t.targetMin != null || t.sport == Sport.gym || t.steps.isEmpty) return t.estimatedMinutes;
  return (estimateStepsSec(t.steps, t.sport, p) / 60).round().clamp(5, 400);
}

class SwimZones {
  final int css; // sec per 100 m
  SwimZones(this.css);

  static int? fromTests(int? t400, int? t200) {
    if (t400 == null || t200 == null || t400 <= t200 * 2) return null;
    return ((t400 - t200) / 2).round();
  }

  static int defaultFor(String level) => switch (level) {
    'advanced' => 90,
    'intermediate' => 110,
    _ => 140,
  };

  (int, int) range(String zone) => switch (zone) {
    'REC' => (css + 15, css + 20),
    'EN' => (css + 8, css + 12),
    'TE' => (css + 3, css + 6),
    'CSS' => (css - 2, css + 2),
    'SP' => (css - 10, css - 3),
    _ => (css + 8, css + 12),
  };
}

/// Riegel race prediction (exponent 1.06; 1.08 for marathon from short races for novices).
int riegel(int t1, double d1, double d2, {bool novice = false}) {
  final e = (novice && d2 >= 42000 && d1 <= 10000) ? 1.08 : 1.06;
  return (t1 * pow(d2 / d1, e)).round();
}

String fmtPace(int secPerKm) => '${secPerKm ~/ 60}:${(secPerKm % 60).toString().padLeft(2, '0')}';
