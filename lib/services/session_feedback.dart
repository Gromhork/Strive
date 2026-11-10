import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'compliance.dart';
import 'zones.dart';

/// Evaluation of one completed endurance session against the workout it fulfilled, and
/// the multi-week trend per sport built from these evaluations
/// (docs/training-science.md §12). Pure – no Firestore, no UI.
///
/// Every signal is optional; each one that is available gives a score in −1…+1
/// (+ = harder than intended, − = easier) and a weight. The verdict is the weighted mean;
/// the more (and the more agreeing) signals, the higher the confidence.
///
/// | signal | source | weight |
/// |---|---|---|
/// | session RPE vs. the intended RPE band of the intensity (Foster 2001) | [Session.rpe] | 1 (0.3 when estimated from HR on import) |
/// | average HR vs. the time-weighted HR target of the steps (Seiler zones) | [Session.avgHr] | 1 · intervals 0.5 · swim 0.3; × ½ within the error of a predicted HRmax ([HrMax]) |
/// | average pace vs. the pace targets (run: Daniels VDOT, swim: CSS) | distance + duration | 1 · intervals 0.4 · hilly ½ |
/// | average power vs. the power targets (bike, Coggan % FTP) | [Session.avgPower] | 1 · intervals 0.7 |
/// | pace fade between halves (run splits, proxy of aerobic decoupling, Friel < 5 %) | [Session.splits] | 0.5 |
///
/// With a predicted HRmax, an HR deviation within its error (±10 bpm) on an easy / long day
/// only counts as "harder" together with a second independent signal (RPE, pace, fade).
///
/// Completion (distance / duration vs. plan) is reported separately: a session under 80 %
/// of the plan is *incomplete* ([cutShort]).
enum SessionEffort { easier, asIntended, harder }

enum SignalKind { rpe, hr, pace, power, fade }

class Signal {
  const Signal(this.kind, this.score, this.weight);
  final SignalKind kind;

  /// −1 (much easier than intended) … +1 (much harder).
  final double score;
  final double weight;

  @override
  String toString() => '${kind.name}:${score.toStringAsFixed(2)}×${weight.toStringAsFixed(1)}';
}

/// Why a session was judged harder / easier (for texts and tests).
enum FeedbackReason { rpeHigh, rpeLow, hrHigh, hrLow, tooFast, tooSlow, powerHigh, powerLow, paceFade, cutShort }

class SessionFeedback {
  const SessionFeedback({
    required this.plan,
    required this.session,
    required this.signals,
    required this.completion,
    this.paceDelta,
    this.efficiency,
  });

  final PlannedWorkout plan;
  final Session session;
  final List<Signal> signals;

  /// actual / planned (distance for distance-based plans, else duration); null = unknown.
  final double? completion;

  /// (target − actual pace) / target for run / swim, (actual − target power) / target for
  /// bike: positive = faster / stronger than the plan. Null without a target.
  final double? paceDelta;

  /// Aerobic efficiency factor (run: m/min per beat, bike with power: W per beat) of an
  /// easy / long session, or null.
  final double? efficiency;

  Sport get sport => plan.sport;
  bool get isQuality => plan.intensity == 'tempo' || plan.intensity == 'intervals';

  /// Less than 80 % of the planned volume (TrainingPeaks / §11 "cut short").
  bool get cutShort => completion != null && completion! < 0.8;

  double get _weight => signals.fold(0.0, (x, s) => x + s.weight);

  /// Weighted mean score (0 without signals).
  double get score => _weight == 0 ? 0 : signals.fold(0.0, (x, s) => x + s.score * s.weight) / _weight;

  /// Score of the internal-load signals only (RPE, HR, fade) – how hard it *felt / was*.
  double? get internalScore {
    final i = signals.where((s) => s.kind == SignalKind.rpe || s.kind == SignalKind.hr || s.kind == SignalKind.fade).toList();
    final w = i.fold(0.0, (x, s) => x + s.weight);
    return w == 0 ? null : i.fold(0.0, (x, s) => x + s.score * s.weight) / w;
  }

  static const threshold = 0.35;

  SessionEffort get effort =>
      score >= threshold
          ? SessionEffort.harder
          : score <= -threshold
          ? SessionEffort.easier
          : SessionEffort.asIntended;

  /// 0…1: grows with the total signal weight (1 → 0.5, 2 → 0.67, 3 → 0.75) and shrinks when
  /// the signals disagree with the verdict.
  double get confidence {
    final w = _weight;
    if (w == 0) return 0;
    final e = effort;
    final agree =
        signals
            .where((s) {
              return switch (e) {
                SessionEffort.harder => s.score > 0.1,
                SessionEffort.easier => s.score < -0.1,
                SessionEffort.asIntended => s.score.abs() < threshold,
              };
            })
            .fold(0.0, (x, s) => x + s.weight) /
        w;
    return w / (w + 1) * (0.5 + 0.5 * agree);
  }

  bool get rated => signals.isNotEmpty;

  /// Harder than intended with at least moderate confidence.
  bool get clearlyHarder => effort == SessionEffort.harder && confidence >= 0.4;
  bool get clearlyEasier => effort == SessionEffort.easier && confidence >= 0.4;

  /// Missed the pace / power targets on the slow side (beyond the tolerance).
  bool get belowTarget => (paceDelta ?? 0) < -_tolerance(sport);
  bool get aboveTarget => (paceDelta ?? 0) > _tolerance(sport);

  List<FeedbackReason> get reasons => [
    for (final s in signals)
      if (s.score >= 0.3)
        switch (s.kind) {
          SignalKind.rpe => FeedbackReason.rpeHigh,
          SignalKind.hr => FeedbackReason.hrHigh,
          SignalKind.pace => isQuality ? FeedbackReason.tooSlow : FeedbackReason.tooFast,
          SignalKind.power => isQuality ? FeedbackReason.powerLow : FeedbackReason.powerHigh,
          SignalKind.fade => FeedbackReason.paceFade,
        }
      else if (s.score <= -0.3)
        switch (s.kind) {
          SignalKind.rpe => FeedbackReason.rpeLow,
          SignalKind.hr => FeedbackReason.hrLow,
          SignalKind.pace => FeedbackReason.tooFast,
          SignalKind.power => FeedbackReason.powerHigh,
          SignalKind.fade => FeedbackReason.paceFade,
        },
    if (cutShort) FeedbackReason.cutShort,
  ];

  @override
  String toString() =>
      'Feedback(${plan.intensity} ${effort.name} score ${score.toStringAsFixed(2)} conf ${confidence.toStringAsFixed(2)} $signals'
      '${completion == null ? '' : ' completion ${(completion! * 100).round()} %'})';
}

double _tolerance(Sport s) => switch (s) {
  Sport.ride => 0.05,
  Sport.swim => 0.04,
  _ => 0.03,
};

/// Intended session-RPE band (CR10) per planned intensity (three-zone model, §0).
(int, int)? intendedRpe(String intensity) => switch (intensity) {
  'easy' || 'technique' || 'moderate' => (2, 4),
  'long' => (3, 4),
  'tempo' => (5, 7),
  'intervals' => (7, 8),
  _ => null,
};

/// Evaluates [s] against its planned workout [p] for [profile] (see [SessionFeedback]).
///
/// [hrMax] is the HRmax the HR signal is judged against ([HrMax.of] with the athlete's
/// sessions, so an observed peak above the prediction is used); default: the profile's.
SessionFeedback evaluateSession(PlannedWorkout p, Session s, UserProfile profile, {HrMax? hrMax}) {
  final signals = <Signal>[];
  final quality = p.intensity == 'tempo' || p.intensity == 'intervals';
  final steady = !quality || p.intensity == 'tempo';
  final intervals = p.intensity == 'intervals';

  // ── RPE
  final band = intendedRpe(p.intensity);
  if (band != null && s.rpe != null) {
    final r = s.rpe!;
    final sc = r > band.$2 ? (r - band.$2) * 0.4 : (r < band.$1 ? (r - band.$1) * 0.4 : 0.0);
    // Imported workouts get an RPE estimated from heart rate (rpeFromHr): not an
    // independent signal when the HR itself is used below.
    final estimated = s.source != null && s.avgHr != null;
    signals.add(Signal(SignalKind.rpe, sc.clamp(-1.0, 1.0), estimated ? 0.3 : 1));
  }

  // ── Heart rate vs. the time-weighted target of the steps (added after the other
  // signals: with a predicted HRmax it may need one of them as confirmation).
  final hm = hrMax ?? HrMax.of(profile);
  final maxHr = hm.bpm;
  final hz = HrZones(maxHr, profile.athlete.restHr);
  Signal? hrSignal;
  var hrUncertain = false;
  if (s.avgHr != null && s.avgHr! > 0 && p.steps.isNotEmpty) {
    final expected = _expectedHr(p, hz, profile);
    if (expected != null) {
      final diff = s.avgHr! - expected;
      final band = 0.03 * maxHr, scale = 0.05 * maxHr;
      var sc = diff.sign * ((diff.abs() - band) / scale).clamp(0.0, 1.0);
      // A low HR on an easy day is not "too easy" – easy should be easy.
      if (!quality) sc = max(sc, -0.3);
      var w = s.sport == Sport.swim ? 0.3 : (intervals ? 0.5 : 1.0);
      // Predicted HRmax (±10 bpm): a deviation the prediction error can explain counts half.
      if (!hm.measured && diff.abs() <= band + HrMax.predictionSd) {
        w *= 0.5;
        hrUncertain = true;
      }
      hrSignal = Signal(SignalKind.hr, sc, w);
    }
  }

  // ── Pace (run / swim) or power (bike) vs. the targets
  double? delta;
  final tol = _tolerance(p.sport);
  double paceScore(double d) {
    if (!quality) return d > tol ? ((d - tol) / 0.07).clamp(0.0, 1.0) : 0;
    if (d < -tol) return ((-d - tol) / 0.07).clamp(0.0, 1.0);
    if (d > tol) return -((d - tol) / 0.07).clamp(0.0, 1.0) * 0.7;
    return 0;
  }

  if ((p.sport == Sport.run || p.sport == Sport.swim) && s.distanceM > 0 && s.durationSec > 0) {
    final target = _expectedPace(p, profile);
    if (target != null) {
      final actual = s.sport == Sport.swim ? s.durationSec / (s.distanceM / 100) : s.durationSec / (s.distanceM / 1000);
      delta = (target - actual) / target;
      // Easy / long runs: running exactly the plan's own numbers (its duration over its distance)
      // is on plan, even where the rounded duration implies a pace a little off the steps'
      // mid-zone estimate (review I10: "easyTooFast" for an athlete who ran the plan, or 3 %
      // slower). Quality runs keep their step targets.
      final km = p.distanceKm ?? 0;
      if (p.sport == Sport.run && !quality && km > 0 && p.durationMin > 0) {
        final implied = p.durationMin * 60 / km;
        if (((actual - implied) / implied).abs() <= tol) delta = 0;
      }
      // Hills slow the pace at the same effort (no grade-adjusted pace without a profile).
      final gain = s.distanceM > 0 ? s.elevationM / (s.distanceM / 1000) : 0;
      var w = intervals ? 0.4 : 1.0;
      if (p.sport == Sport.run && gain > 30) w = 0;
      if (p.sport == Sport.run && gain > 15) w *= 0.5;
      if (w > 0) signals.add(Signal(SignalKind.pace, paceScore(delta), w));
    }
  } else if (p.sport == Sport.ride && s.avgPower != null && s.avgPower! > 0) {
    final target = _expectedPower(p);
    if (target != null) {
      delta = (s.avgPower! - target) / target;
      signals.add(Signal(SignalKind.power, paceScore(delta), intervals ? 0.7 : 1));
    }
  }

  // ── Pace fade between the halves (run, continuous sessions, ≥ 4 km splits)
  if (p.sport == Sport.run && steady && s.splits.length >= 4) {
    final h = s.splits.length ~/ 2;
    final first = s.splits.take(h).fold(0, (x, v) => x + v) / h;
    final second = s.splits.skip(s.splits.length - h).fold(0, (x, v) => x + v) / h;
    final fade = second / first - 1;
    if (fade > 0.05) signals.add(Signal(SignalKind.fade, (0.5 + (fade - 0.05) / 0.05).clamp(0.0, 1.0), 0.5));
  }

  if (hrSignal != null) {
    // Easy day, uncertain HR saying "harder": only with a second, independent signal
    // (RPE asked after the session, pace, pace fade) – an HR-estimated RPE is no second signal.
    final estimatedRpe = s.source != null && s.avgHr != null;
    final confirmed = signals.any((x) => x.score > 0 && !(x.kind == SignalKind.rpe && estimatedRpe));
    if (hrUncertain && !quality && hrSignal.score > 0 && !confirmed) hrSignal = Signal(SignalKind.hr, 0, hrSignal.weight);
    signals.add(hrSignal);
  }

  // ── Aerobic efficiency of easy / long sessions
  double? ef;
  if (!quality && !p.steps.any((x) => x.kind == 'work') && s.avgHr != null && s.avgHr! > 0 && s.durationSec > 0) {
    if (p.sport == Sport.run && s.distanceM > 0) ef = s.distanceM / (s.durationSec / 60) / s.avgHr!;
    if (p.sport == Sport.ride && s.avgPower != null) ef = s.avgPower! / s.avgHr!;
  }

  return SessionFeedback(plan: p, session: s, signals: signals, completion: complianceRatio(p, s), paceDelta: delta, efficiency: ef);
}

/// HR zone (1–5) a step aims at when it has no HR target of its own.
int _hrZoneOf(WorkoutStep x, Sport sport) => switch (x.zone) {
  'walk' || 'Z1' || 'REC' || 'DR' => 1,
  'E' || 'L' || 'Z2' || 'EN' => 2,
  'M' || 'Z3' || 'SS' || 'TE' => 3,
  'T' || 'Z4' || 'CSS' => 4,
  'I' || 'R' || 'Z5' || 'Z6' || 'Z7' || 'SP' => 5,
  _ => 2,
};

double? _expectedHr(PlannedWorkout p, HrZones hz, UserProfile profile) {
  var t = 0.0, sum = 0.0;
  final easy = PaceZones(Vdot.of(profile.athlete) ?? Vdot.defaultFor(profile.level)).easySlow;
  final css = SwimZones.fromTests(profile.athlete.swim400Sec, profile.athlete.swim200Sec) ?? SwimZones.defaultFor(profile.level);
  for (final x in p.steps) {
    final sec = estimateStepSec(x, p.sport, easyPace: easy, css: css).toDouble();
    if (sec <= 0) continue;
    double mid;
    if (x.hrMin != null && x.hrMax != null) {
      mid = (x.hrMin! + x.hrMax!) / 2;
    } else {
      final z = hz.zone(_hrZoneOf(x, p.sport));
      // Short recoveries: HR stays up from the work bout before.
      mid = x.kind == 'recovery' ? z.$2.toDouble() : (z.$1 + z.$2) / 2;
    }
    t += sec;
    sum += sec * mid;
  }
  return t <= 0 ? null : sum / t;
}

/// Planned average pace: run sec/km, swim sec/100 m (incl. the rests between repeats).
/// Null when the main steps have no pace target.
double? _expectedPace(PlannedWorkout p, UserProfile profile) {
  // Swim drills carry no pace target (technique, not speed): they don't void the main set's.
  final main = p.steps.where((x) => (x.kind == 'steady' || x.kind == 'work') && x.zone != 'DR');
  if (main.isEmpty || main.any((x) => x.paceMin == null || x.paceMax == null)) return null;
  if (p.sport == Sport.swim) {
    final m = p.steps.fold(0.0, (x, s) => x + (s.distanceM ?? 0));
    if (m <= 0) return null;
    return estimateStepsSec(p.steps, Sport.swim, profile) / (m / 100);
  }
  final pz = PaceZones(Vdot.of(profile.athlete) ?? Vdot.defaultFor(profile.level));
  var t = 0.0, d = 0.0;
  for (final x in p.steps) {
    final pace =
        x.paceMin != null && x.paceMax != null
            ? (x.paceMin! + x.paceMax!) / 2
            : x.zone == 'walk'
            ? 570.0
            : pz.easySlow.toDouble();
    if (x.distanceM != null) {
      d += x.distanceM!;
      t += x.distanceM! / 1000 * pace;
    } else if (x.durationSec != null) {
      t += x.durationSec!;
      d += x.durationSec! / pace * 1000;
    }
  }
  return d <= 0 ? null : t / (d / 1000);
}

/// Planned time-weighted average power (bike), null without power targets.
double? _expectedPower(PlannedWorkout p) {
  final main = p.steps.where((x) => x.kind == 'steady' || x.kind == 'work');
  if (main.isEmpty || main.any((x) => x.powerMin == null)) return null;
  var t = 0.0, sum = 0.0;
  for (final x in p.steps) {
    final sec = (x.durationSec ?? 0).toDouble();
    if (sec <= 0) continue;
    // Steps without a power target (rare) don't count.
    final w = x.powerMin != null && x.powerMax != null ? (x.powerMin! + x.powerMax!) / 2 : null;
    if (w == null) continue;
    t += sec;
    sum += sec * w;
  }
  return t <= 0 ? null : sum / t;
}

// ───────────────────────────── Multi-session trend ─────────────────────────────

/// Trend of one sport over the last weeks, from the evaluations of linked sessions.
class CardioTrend {
  CardioTrend(this.sport, this.feedback);

  final Sport sport;

  /// Oldest first.
  final List<SessionFeedback> feedback;

  int get n => feedback.length;
  int get rated => feedback.where((f) => f.rated).length;
  int get harder => feedback.where((f) => f.clearlyHarder).length;
  int get easier => feedback.where((f) => f.clearlyEasier).length;
  int get cutShort => feedback.where((f) => f.cutShort).length;

  double? get meanScore {
    final r = feedback.where((f) => f.rated).toList();
    return r.isEmpty ? null : r.fold(0.0, (x, f) => x + f.score) / r.length;
  }

  double? get completion {
    final c = feedback.map((f) => f.completion).whereType<double>().toList();
    return c.isEmpty ? null : c.fold(0.0, (x, v) => x + min(v, 1.2)) / c.length;
  }

  /// Key sessions (quality or long) that missed the targets on the slow side while
  /// feeling harder than intended: the targets are too ambitious for the current fitness.
  int get slowAndHard =>
      feedback.where((f) => (f.isQuality || f.plan.intensity == 'long') && f.belowTarget && (f.internalScore ?? 0) >= 0.3).length;

  /// Quality sessions that hit (or beat) the targets and felt easier than intended.
  int get easyAndOnTarget =>
      feedback.where((f) => f.isQuality && f.paceDelta != null && !f.belowTarget && (f.internalScore ?? f.score) <= -0.3).length;

  /// Quality sessions above the targets (power / pace) without feeling harder than intended.
  int get strongAndComfortable =>
      feedback.where((f) => f.isQuality && f.aboveTarget && (f.internalScore ?? 0) < SessionFeedback.threshold).length;

  /// Change of the aerobic efficiency factor over the window, e.g. 0.04 = +4 %: Theil–Sen
  /// slope (median of the pairwise slopes – robust to single outliers such as a hot day or a
  /// GPS glitch) × span, relative to the median EF. Needs ≥ 6 easy / long sessions with HR
  /// over ≥ 14 days; when the points don't move consistently in one direction (Kendall
  /// |τ| < 0.45 – day-to-day pace / HR noise of ~3 %) the change is 0. Rising EF at the
  /// same easy effort = better aerobic fitness (Friel / Coggan).
  double? get efficiencyChange {
    final pts = [
      for (final f in feedback)
        if (f.efficiency != null) (f.session.start, f.efficiency!),
    ];
    if (pts.length < 6) return null;
    final t0 = pts.first.$1;
    final xs = [for (final p in pts) p.$1.difference(t0).inHours / 24.0];
    final span = xs.reduce(max) - xs.reduce(min);
    if (span < 14) return null;
    final ys = [for (final p in pts) p.$2];
    final slopes = <double>[];
    var concordant = 0, discordant = 0;
    for (var i = 0; i < xs.length; i++) {
      for (var j = i + 1; j < xs.length; j++) {
        final dx = xs[j] - xs[i], dy = ys[j] - ys[i];
        if (dx == 0) continue;
        slopes.add(dy / dx);
        if (dy * dx > 0) concordant++;
        if (dy * dx < 0) discordant++;
      }
    }
    final my = _median(ys);
    if (slopes.isEmpty || my == 0) return null;
    final tau = (concordant - discordant) / slopes.length;
    if (tau.abs() < 0.45) return 0;
    return _median(slopes) * span / my;
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  /// Trends of all endurance sports from the linked sessions of the last [days] days.
  static Map<Sport, CardioTrend> of(
    List<PlannedWorkout> plans,
    Map<String, Session> linked,
    UserProfile profile, {
    required DateTime now,
    int days = 42,
    HrMax? hrMax,
  }) {
    final from = dayOnly(now).subtract(Duration(days: days));
    final out = <Sport, List<SessionFeedback>>{};
    for (final p in plans) {
      if (p.sport == Sport.gym || p.intensity == 'race') continue;
      final s = linked[p.id];
      if (s == null || s.start.isBefore(from) || s.start.isAfter(now)) continue;
      out.putIfAbsent(p.sport, () => []).add(evaluateSession(p, s, profile, hrMax: hrMax));
    }
    return {for (final e in out.entries) e.key: CardioTrend(e.key, e.value..sort((a, b) => a.session.start.compareTo(b.session.start)))};
  }
}
