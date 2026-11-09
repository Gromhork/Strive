import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'compliance.dart';
import 'insights.dart';
import 'plan_adjuster.dart';
import 'session_feedback.dart';
import 'zones.dart';

/// "Re-plan & recalibrate": adapts the upcoming weeks of the current plan to how the
/// athlete actually trained (docs/training-science.md §11). Pure – no Firestore, no UI.
///
/// Signals (last [Recalibrator.lookbackDays] days):
/// * **RPE vs. intended intensity** (session-RPE, Foster 2001; three-zone model §0: easy
///   1–4, threshold 5–6, high 7–10). Too hard: easy / long ≥ 7, tempo ≥ 9, intervals 10;
///   elevated (counts ½): easy / long 5–6. Too easy: tempo / intervals ≤ 4.
/// * **Compliance**: share of the due planned minutes that were done ([weeklyCompletion]),
///   sessions cut short (< 80 % of the plan), missed key sessions (last 3 days).
/// * **Thresholds**: VDOT from recent running best efforts ([runBestEfforts]).
///
/// Rules (all on planned, not-yet-done endurance workouts of the next 14 days; strength
/// sessions, done and race workouts are never touched):
/// 1. Fatigue (too-hard score ≥ 2): next 7 days −10 % (≥ 3: −20 %, days 8–14 −10 %),
///    the next quality session of each sport becomes easy (≥ 3: all in the next 7 days)
///    – "RPE ≥ target + 2 twice → repeat the week" (§7.9), keep intensity otherwise.
/// 2. Completion < 70 % of the due minutes: next 7 days −10 % (no progression after
///    missed training); < 50 %: −20 % / −10 % and the first quality session per sport
///    becomes easy (re-entry). Needs ≥ 3 due workouts.
/// 3. ≥ 2 sessions cut short: long sessions of the next 14 days −10 %.
/// 4. Too easy (≥ 2 quality sessions at RPE ≤ 4), no fatigue, completion ≥ 90 %: easy and
///    long sessions of loading weeks in the next 7 days +5 % (inside the 5–10 %/week
///    growth rule; long runs never above +10 % of the longest run of the last 30 days, R1).
/// 5. Missed key sessions of the last 3 days move inside their week ([proposeWeekAdjustment]);
///    on re-entry (completion < 50 %) they are dropped instead.
/// 6. Faster running best effort: pace targets of upcoming runs follow the new VDOT (with
///    race times only upwards and at most +2 points at once – Daniels; without race times
///    the plan's default VDOT is replaced in both directions – downwards only by a real effort:
///    race, RPE ≥ 8 or HR ≥ 88 % HRmax).
///
/// Session evaluation (§12, [evaluateSession]): sessions without an RPE still count as too
/// hard / too easy when heart rate, pace / power and pace fade say so; and the trend of the
/// last [trendDays] days per sport ([CardioTrend]) adjusts the thresholds:
/// 7. Run, no best-effort change: ≥ 3 key runs slower than the targets at a high effort →
///    VDOT −1; ≥ 3 quality runs on target that felt easy, none too hard, aerobic efficiency
///    not falling → VDOT +1 (Daniels: small steps after a few weeks).
/// 8. Bike with a known FTP: ≥ 2 quality rides above the power targets without extra effort
///    (none too hard) → FTP +3 %; ≥ 2 key rides below target at a high effort → FTP −3 %
///    (Coggan zones follow).
/// 9. Swim: ≥ 3 quality swims faster than the targets at a comfortable effort → CSS −2 s /
///    100 m; ≥ 2 key swims slower at a high effort → CSS +2 s.
class Recalibrator {
  Recalibrator(this.l, this.profile, {required this.plans, required this.sessions, required this.now});

  final AppLocalizations l;
  final UserProfile profile;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;
  final DateTime now;

  static const lookbackDays = 14;
  static const horizonDays = 14;
  static const trendDays = 42;

  AthleteData get a => profile.athlete;
  DateTime get today => dayOnly(now);

  Recalibration run() {
    final linked = linkPlanSessions(plans, sessions);
    final from = today.subtract(const Duration(days: lookbackDays));
    final window = plans.where((p) => !dayOnly(p.date).isBefore(from) && dayOnly(p.date).isBefore(today)).toList();

    // ── RPE signals
    var tooHard = 0.0, tooEasy = 0, rated = 0, cutShort = 0, estimated = 0;
    for (final p in window.where((p) => p.sport != Sport.gym && p.intensity != 'race')) {
      final s = linked[p.id];
      if (s == null) continue;
      final r = complianceRatio(p, s);
      if (r != null && r < 0.8) cutShort++;
      if (s.rpe == null) {
        // No RPE: heart rate, pace / power and pace fade still tell how hard it was.
        final f = evaluateSession(p, s, profile);
        if (!f.rated) continue;
        estimated++;
        if (f.clearlyHarder) tooHard += f.score >= 0.6 ? 1 : 0.5;
        if (f.isQuality && f.clearlyEasier) tooEasy++;
        continue;
      }
      rated++;
      tooHard += rpeLoad(p.intensity, s.rpe!);
      if (rpeTooEasy(p.intensity, s.rpe!)) tooEasy++;
    }
    // ── Compliance (only meaningful with a few due workouts)
    final due = window.where((p) => p.durationMin > 0).length;
    final completion = due >= 3 ? weeklyCompletion(window, linked, now: now) : null;

    // ── Decide the load factors
    var f1 = 1.0, f2 = 1.0; // days 0–6, 7–13
    var swapAll = false, swapFirst = false, shortenLong = false, progress = false;
    final reasons = <RecalReason>[];
    if (tooHard >= 2) {
      reasons.add(RecalReason.rpeHigh);
      if (tooHard >= 3) {
        f1 = min(f1, 0.8);
        f2 = min(f2, 0.9);
        swapAll = true;
      } else {
        f1 = min(f1, 0.9);
        swapFirst = true;
      }
    }
    if (completion != null && completion < 0.7) {
      reasons.add(RecalReason.lowCompletion);
      if (completion < 0.5) {
        f1 = min(f1, 0.8);
        f2 = min(f2, 0.9);
        swapFirst = true;
      } else {
        f1 = min(f1, 0.9);
      }
    }
    if (cutShort >= 2) {
      reasons.add(RecalReason.cutShort);
      shortenLong = true;
    }
    if (reasons.isEmpty && tooEasy >= 2 && (completion ?? 1) >= 0.9) {
      reasons.add(RecalReason.rpeLow);
      progress = true;
    }

    // ── Thresholds
    final oldVdot = Vdot.of(a) ?? Vdot.defaultFor(profile.level);
    var newVdot = _newVdot(oldVdot);
    if (newVdot != null) reasons.add(newVdot > oldVdot ? RecalReason.fasterRuns : RecalReason.slowerRuns);
    final trends = CardioTrend.of(plans, linked, profile, now: now, days: trendDays);
    final run = trends[Sport.run], ride = trends[Sport.ride], swim = trends[Sport.swim];
    if (newVdot == null && run != null) {
      if (run.slowAndHard >= 3) {
        newVdot = oldVdot - 1;
        reasons.add(RecalReason.runTrendSlower);
      } else if (run.easyAndOnTarget >= 3 && run.harder == 0 && (run.efficiencyChange ?? 0) >= 0) {
        newVdot = oldVdot + 1;
        reasons.add(RecalReason.runTrendFaster);
      }
      if (newVdot != null) newVdot = double.parse(newVdot.toStringAsFixed(1));
    }
    int? newFtp;
    if (a.ftp != null && ride != null) {
      if (ride.strongAndComfortable >= 2 && ride.harder == 0) {
        newFtp = (a.ftp! * 1.03).round();
        reasons.add(RecalReason.ftpUp);
      } else if (ride.slowAndHard >= 2) {
        newFtp = (a.ftp! * 0.97).round();
        reasons.add(RecalReason.ftpDown);
      }
    }
    final oldCss = SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(profile.level);
    int? newCss;
    if (swim != null) {
      if (swim.strongAndComfortable >= 3 && swim.harder == 0) {
        newCss = oldCss - 2;
        reasons.add(RecalReason.cssFaster);
      } else if (swim.slowAndHard >= 2) {
        newCss = oldCss + 2;
        reasons.add(RecalReason.cssSlower);
      }
    }
    // Aerobic efficiency (pace or power per heartbeat at easy effort) – informational.
    final efficiency = <Sport, double>{
      for (final t in [run, ride])
        if (t != null && t.efficiencyChange != null) t.sport: t.efficiencyChange!,
    };
    final ef = efficiency.values.fold<double>(0, (x, v) => v.abs() > x.abs() ? v : x);
    if (ef >= 0.03) reasons.add(RecalReason.aerobicUp);
    if (ef <= -0.03) reasons.add(RecalReason.aerobicDown);

    // ── Missed key sessions: move inside the week (same rules as "adjust my week").
    final changes = <RecalChange>[];
    final moved = <String>{};
    // Re-entry after mostly missed training (< 50 %, e.g. illness): missed key sessions
    // are not made up – stacking them onto the return week contradicts the re-entry.
    final reentry = completion != null && completion < 0.5;
    final adjust = [for (final c in proposeWeekAdjustment(plans, now)) reentry && c.isMove ? PlanChange.skip(c.plan) : c];
    for (final c in adjust) {
      moved.add(c.plan.id);
      if (c.isMove) {
        changes.add(RecalChange(c.plan, _copy(c.plan, date: c.to), RecalKind.moved));
      } else {
        changes.add(RecalChange(c.plan, _copy(c.plan, status: 'skipped'), RecalKind.dropped));
      }
      if (c.replaces != null) {
        moved.add(c.replaces!.id);
        changes.add(RecalChange(c.replaces!, _copy(c.replaces!, status: 'skipped'), RecalKind.dropped));
      }
    }
    if (adjust.any((c) => isHardPlan(c.plan))) reasons.add(RecalReason.missedKey);

    // ── Upcoming endurance workouts
    final end = today.add(const Duration(days: horizonDays));
    final upcoming =
        plans
            .where(
              (p) =>
                  p.status == 'planned' &&
                  !moved.contains(p.id) &&
                  p.sport != Sport.gym &&
                  p.intensity != 'race' &&
                  !dayOnly(p.date).isBefore(today) &&
                  dayOnly(p.date).isBefore(end),
            )
            .toList()
          ..sort((x, y) => x.date.compareTo(y.date));
    final longest30 = _longestRecentRunKm();
    final swappedSports = <Sport>{};
    final pz = newVdot == null ? null : PaceZones(newVdot);
    for (final p in upcoming) {
      final days = dayOnly(p.date).difference(today).inDays;
      final quality = p.intensity == 'tempo' || p.intensity == 'intervals';
      final rest = p.phase == 'recovery' || p.phase == 'taper';
      var w = p;
      RecalKind? kind;
      // Fatigue / re-entry: quality → easy (never in the taper – it keeps its intensity).
      if (quality && p.phase != 'taper' && ((swapAll && days < 7) || (swapFirst && !swappedSports.contains(p.sport)))) {
        swappedSports.add(p.sport);
        w = _toEasy(p, pz);
        kind = RecalKind.toEasy;
      } else if (!quality) {
        var f = days < 7 ? f1 : f2;
        if (shortenLong && p.intensity == 'long') f = min(f, 0.9);
        if (progress && days < 7 && !rest && f == 1.0) {
          f = 1.05;
          // R1: a long run stays within +10 % of the longest run of the last 30 days.
          final km = p.distanceKm ?? 0;
          if (p.sport == Sport.run && p.intensity == 'long' && longest30 != null && km > 0) f = min(f, longest30 * 1.1 / km);
        }
        if ((f - 1).abs() >= 0.02) {
          w = _scaled(p, f);
          kind = f < 1 ? RecalKind.easier : RecalKind.harder;
        }
      }
      if (pz != null && w.sport == Sport.run && kind != RecalKind.toEasy) {
        final paced = _withPaces(w, pz);
        if (paced != null) {
          w = paced;
          kind ??= RecalKind.paces;
        }
      }
      if (newFtp != null && w.sport == Sport.ride) {
        final powered = _withPower(w, PowerZones(newFtp));
        if (powered != null) {
          w = powered;
          kind ??= RecalKind.paces;
        }
      }
      if (newCss != null && w.sport == Sport.swim) {
        final paced = _withSwimPaces(w, SwimZones(newCss));
        if (paced != null) {
          w = paced;
          kind ??= RecalKind.paces;
        }
      }
      if (kind != null) changes.add(RecalChange(p, kind == RecalKind.paces ? w : _noted(w), kind));
    }

    // Race times for the profile, so newly generated plans use the new VDOT too.
    Map<String, int>? raceTimes;
    if (newVdot != null) {
      final key = a.eventDistance != null && Vdot.distances.containsKey(a.eventDistance) ? a.eventDistance! : '10k';
      raceTimes = {...a.raceTimes, key: Vdot.raceTime(newVdot, Vdot.distances[key]!)};
    }
    // Swim test times that give the new CSS ((t400 − t200) / 2), for the profile.
    final athlete = <String, dynamic>{
      if (newFtp != null) 'ftp': newFtp,
      if (newCss != null) ...{'swim200Sec': 2 * newCss - 4, 'swim400Sec': 4 * newCss - 4},
    };
    return Recalibration(
      reasons: reasons,
      athlete: athlete,
      stats: RecalStats(
        estimated: estimated,
        oldFtp: a.ftp,
        newFtp: newFtp,
        oldCss: oldCss,
        newCss: newCss,
        efficiency: efficiency,
        rated: rated,
        tooHard: tooHard,
        tooEasy: tooEasy,
        completion: completion,
        cutShort: cutShort,
        oldVdot: oldVdot,
        newVdot: newVdot,
      ),
      changes: changes,
      raceTimes: raceTimes,
    );
  }

  // ───────────────────────────── RPE rules ─────────────────────────────

  /// How much a session counts toward "too hard" (0, ½ or 1) given its planned intensity.
  static double rpeLoad(String intensity, int rpe) => switch (intensity) {
    'easy' || 'technique' || 'long' => rpe >= 7 ? 1 : (rpe >= 5 ? 0.5 : 0),
    'tempo' => rpe >= 9 ? 1 : 0,
    'intervals' => rpe >= 10 ? 1 : 0,
    _ => 0,
  };

  /// Quality session that felt easy (RPE ≤ 4 – zone 1 effort for a threshold / VO2 set).
  static bool rpeTooEasy(String intensity, int rpe) => (intensity == 'tempo' || intensity == 'intervals') && rpe <= 4;

  // ───────────────────────────── Thresholds ─────────────────────────────

  /// New VDOT from running best efforts of the last 90 days (5 km and longer), or null.
  double? _newVdot(double current) {
    final recent = sessions.where((s) => now.difference(s.start).inDays <= 90).toList();
    double? bestOf(List<Session> list) {
      double? best;
      for (final e in runBestEfforts(list).values) {
        if (!Vdot.distances.containsKey(e.key)) continue;
        final v = Vdot.fromRace(e.meters, e.seconds);
        if (best == null || v > best) best = v;
      }
      return best;
    }

    var best = bestOf(recent);
    if (best == null) return null;
    if (a.raceTimes.isEmpty) {
      // The plan uses a level default: any real effort is a better anchor. Lowering it
      // needs a real (near-)maximal effort, though – a "best 5 km" inside an easy run says
      // nothing about VDOT (easy pace is ~59–74 % VO2max) and would slow every pace.
      if (best < current) best = bestOf(recent.where(_maximalEffort).toList());
      if (best == null) return null;
      return (best - current).abs() >= 1 ? double.parse(best.toStringAsFixed(1)) : null;
    }
    if (best < current + 0.5) return null;
    return double.parse(min(best, current + 2).toStringAsFixed(1));
  }

  /// A race / time trial, or a run that was rated (RPE ≥ 8) or measured (average HR
  /// ≥ 88 % HRmax, zone 4+) as hard.
  bool _maximalEffort(Session s) {
    if ((s.rpe ?? 0) >= 8) return true;
    if (s.avgHr != null && s.avgHr! >= 0.88 * profile.estimatedMaxHr) return true;
    final p = plans.where((p) => p.id == s.planId || (p.sessionId != null && p.sessionId == s.id)).firstOrNull;
    return p?.intensity == 'race';
  }

  double? _longestRecentRunKm() {
    final runs = sessions.where((s) => s.sport == Sport.run && now.difference(s.start).inDays <= 30);
    final km = runs.fold<double>(0, (x, s) => max(x, s.distanceM / 1000));
    return km > 0 ? km : null;
  }

  // ───────────────────────────── Workout edits ─────────────────────────────

  /// [p] with volume × [f]: steady / work steps, duration and distance.
  PlannedWorkout _scaled(PlannedWorkout p, double f) {
    WorkoutStep s(WorkoutStep x) {
      if (x.kind != 'steady' && x.kind != 'work') return x;
      // Short repeats (strides, intervals) keep their length – only continuous parts scale.
      // A step usually has only a time or only a distance: the missing one must not make
      // it "long" (a 20 s stride was scaled to the 5 min floor before).
      if (x.kind == 'work' && (x.durationSec ?? 0) < 600 && (x.distanceM ?? 0) < 2000) return x;
      return _step(
        x,
        durationSec: x.durationSec == null ? null : max(300, (x.durationSec! * f / 60).round() * 60),
        distanceM: x.distanceM == null ? null : max(p.sport == Sport.swim ? 100.0 : 1000.0, (x.distanceM! * f / 100).round() * 100.0),
      );
    }

    final steps = [for (final x in p.steps) s(x)];
    // Duration and distance follow the steps (same estimate as the generator), so the
    // card, the steps and the calendar agree; plans without steps scale directly.
    final before = estimateStepsSec(p.steps, p.sport, profile), after = estimateStepsSec(steps, p.sport, profile);
    final g = p.steps.isEmpty || before <= 0 ? f : after / before;
    return _copy(
      p,
      steps: steps,
      durationMin: max(15, (p.durationMin * g / 5).round() * 5),
      distanceKm: p.distanceKm == null ? null : double.parse((p.distanceKm! * g).toStringAsFixed(1)),
    );
  }

  /// Quality session → easy session of the same sport, ~80 % of the time.
  PlannedWorkout _toEasy(PlannedWorkout p, PaceZones? newPz) {
    final minutes = max(20, (p.durationMin * 0.8 / 5).round() * 5);
    final hz = HrZones(profile.estimatedMaxHr, a.restHr);
    switch (p.sport) {
      case Sport.swim:
        final css = SwimZones.fromTests(a.swim400Sec, a.swim200Sec);
        final total = max(600.0, ((p.steps.fold<double>(0, (x, s) => x + (s.distanceM ?? 0)) * 0.8) / 100).round() * 100.0);
        final reps = max(2, ((total - 300) / 200).floor());
        (int?, int?) pace(String z) => css == null ? (null, null) : SwimZones(css).range(z);
        final steps = <WorkoutStep>[
          WorkoutStep(kind: 'warmup', distanceM: 200, zone: 'REC', paceMin: pace('REC').$1, paceMax: pace('REC').$2, note: l.stepSwimWu),
          for (var i = 0; i < reps; i++) ...[
            WorkoutStep(kind: 'work', distanceM: 200, zone: 'EN', paceMin: pace('EN').$1, paceMax: pace('EN').$2, note: l.stepSwimEnNote),
            if (i < reps - 1) const WorkoutStep(kind: 'recovery', durationSec: 20, zone: 'REC'),
          ],
          WorkoutStep(kind: 'cooldown', distanceM: 100, zone: 'REC', paceMin: pace('REC').$1, paceMax: pace('REC').$2),
        ];
        final m = steps.fold<double>(0, (x, s) => x + (s.distanceM ?? 0));
        return _copy(
          p,
          title: l.wSwimEndurance(reps, 200),
          description: l.wSwimEnduranceDesc,
          intensity: 'easy',
          isKey: false,
          steps: steps,
          durationMin: max(15, (estimateStepsSec(steps, Sport.swim, profile) / 60 / 5).round() * 5),
          distanceKm: double.parse((m / 1000).toStringAsFixed(1)),
        );
      case Sport.ride:
        final ftp = a.ftp ?? (a.hasPowerMeter ? PowerZones.estimate(profile.level, profile.weightKg) : null);
        final pw = ftp == null ? null : PowerZones(ftp).range('Z2');
        final hr = hz.zone(2);
        return _copy(
          p,
          title: l.planEasyRide,
          description: l.wEasyRideDesc,
          intensity: 'easy',
          isKey: false,
          steps: [
            WorkoutStep(
              kind: 'steady',
              durationSec: minutes * 60,
              zone: 'Z2',
              powerMin: pw?.$1,
              powerMax: pw?.$2,
              hrMin: hr.$1 - 5,
              hrMax: hr.$2 - 5,
              note: l.stepZ2RideNote,
            ),
          ],
          durationMin: minutes,
          distanceKm: double.parse((minutes / 60 * 27).toStringAsFixed(1)),
        );
      case Sport.run:
      case Sport.gym:
        final pz = newPz ?? PaceZones(Vdot.of(a) ?? Vdot.defaultFor(profile.level));
        final hadPace = p.steps.any((s) => s.paceMin != null);
        final (fast, slow) = pz.range('E');
        final km = double.parse((minutes * 60 / ((fast + slow) / 2)).toStringAsFixed(1));
        final hr = hz.zone(2);
        return _copy(
          p,
          title: l.planEasyRun,
          description: l.wEasyDesc,
          intensity: 'easy',
          isKey: false,
          steps: [
            WorkoutStep(
              kind: 'steady',
              durationSec: minutes * 60,
              zone: 'E',
              paceMin: hadPace ? fast : null,
              paceMax: hadPace ? slow : null,
              hrMin: hr.$1,
              hrMax: hr.$2,
              note: l.stepEasyNote,
            ),
          ],
          durationMin: minutes,
          distanceKm: km,
        );
    }
  }

  /// Run steps that already show a pace get the targets of the new VDOT (null = no change).
  PlannedWorkout? _withPaces(PlannedWorkout p, PaceZones pz) {
    var changed = false;
    final steps = [
      for (final s in p.steps)
        if (s.paceMin != null && s.zone != 'walk')
          () {
            final (fast, slow) = pz.range(s.zone);
            if (fast == s.paceMin && slow == s.paceMax) return s;
            changed = true;
            return _step(s, paceMin: fast, paceMax: slow);
          }()
        else
          s,
    ];
    return changed ? _copy(p, steps: steps) : null;
  }

  /// Bike steps that show power get the targets of the new FTP (null = no change).
  PlannedWorkout? _withPower(PlannedWorkout p, PowerZones z) {
    var changed = false;
    final steps = [
      for (final s in p.steps)
        if (s.powerMin != null)
          () {
            final (lo, hi) = z.range(s.zone);
            if (lo == s.powerMin && hi == s.powerMax) return s;
            changed = true;
            return _step(s, powerMin: lo, powerMax: hi);
          }()
        else
          s,
    ];
    return changed ? _copy(p, steps: steps) : null;
  }

  /// Swim steps that show a pace get the targets of the new CSS (null = no change).
  PlannedWorkout? _withSwimPaces(PlannedWorkout p, SwimZones z) {
    var changed = false;
    final steps = [
      for (final s in p.steps)
        if (s.paceMin != null)
          () {
            final (fast, slow) = z.range(s.zone);
            if (fast == s.paceMin && slow == s.paceMax) return s;
            changed = true;
            return _step(s, paceMin: fast, paceMax: slow);
          }()
        else
          s,
    ];
    return changed ? _copy(p, steps: steps) : null;
  }

  /// Adds the recalibration note (once) to the description.
  PlannedWorkout _noted(PlannedWorkout p) {
    final notes = {recalNote('en'), recalNote('de')};
    final lines = p.description.split('\n').where((x) => x.isNotEmpty && !notes.contains(x)).toList();
    return _copy(p, description: [...lines, l.recalNote].join('\n'));
  }

  static String recalNote(String lang) => lookupAppLocalizations(Locale(lang)).recalNote;

  static WorkoutStep _step(
    WorkoutStep s, {
    int? durationSec,
    double? distanceM,
    int? paceMin,
    int? paceMax,
    int? powerMin,
    int? powerMax,
  }) => WorkoutStep(
    kind: s.kind,
    durationSec: durationSec ?? s.durationSec,
    distanceM: distanceM ?? s.distanceM,
    zone: s.zone,
    paceMin: paceMin ?? s.paceMin,
    paceMax: paceMax ?? s.paceMax,
    powerMin: powerMin ?? s.powerMin,
    powerMax: powerMax ?? s.powerMax,
    hrMin: s.hrMin,
    hrMax: s.hrMax,
    note: s.note,
  );

  static PlannedWorkout _copy(
    PlannedWorkout p, {
    DateTime? date,
    String? title,
    String? description,
    int? durationMin,
    double? distanceKm,
    String? intensity,
    String? status,
    List<WorkoutStep>? steps,
    bool? isKey,
  }) => PlannedWorkout(
    id: p.id,
    date: date ?? p.date,
    sport: p.sport,
    title: title ?? p.title,
    description: description ?? p.description,
    durationMin: durationMin ?? p.durationMin,
    distanceKm: distanceKm ?? p.distanceKm,
    intensity: intensity ?? p.intensity,
    templateId: p.templateId,
    status: status ?? p.status,
    sessionId: p.sessionId,
    steps: steps ?? p.steps,
    phase: p.phase,
    isKey: isKey ?? p.isKey,
    exercises: p.exercises,
  );
}

/// Why the plan changes.
enum RecalReason {
  rpeHigh,
  rpeLow,
  lowCompletion,
  cutShort,
  missedKey,
  fasterRuns,
  slowerRuns,
  runTrendSlower,
  runTrendFaster,
  ftpUp,
  ftpDown,
  cssFaster,
  cssSlower,
  aerobicUp,
  aerobicDown,
}

/// What happens to one workout.
enum RecalKind { easier, harder, toEasy, moved, dropped, paces }

class RecalChange {
  const RecalChange(this.before, this.after, this.kind);
  final PlannedWorkout before;
  final PlannedWorkout after;
  final RecalKind kind;

  /// Firestore update of this workout (only the fields that change). A new volume
  /// replaces an automatic adjustment (its undo would bring back stale values).
  Map<String, dynamic> get update {
    final b = before.toMap(), a = after.toMap();
    final volume = kind == RecalKind.easier || kind == RecalKind.harder || kind == RecalKind.toEasy;
    return {
      for (final k in a.keys)
        if (!_eq(a[k], b[k])) k: a[k],
      if (volume && before.auto != null) 'auto': FieldValue.delete(),
    };
  }

  static bool _eq(Object? x, Object? y) => x.toString() == y.toString();
}

class RecalStats {
  const RecalStats({
    this.estimated = 0,
    this.oldFtp,
    this.newFtp,
    this.oldCss,
    this.newCss,
    this.efficiency = const {},
    required this.rated,
    required this.tooHard,
    required this.tooEasy,
    required this.completion,
    required this.cutShort,
    required this.oldVdot,
    required this.newVdot,
  });

  /// Completed endurance workouts with an RPE in the look-back window.
  final int rated;

  /// Too-hard score (1 per clearly too hard session, ½ per elevated easy session).
  final double tooHard;

  /// Quality sessions rated ≤ 4.
  final int tooEasy;

  /// Share of the due planned minutes done (null: too few due workouts).
  final double? completion;

  /// Sessions cut short (< 80 % of the plan).
  final int cutShort;
  final double oldVdot;
  final double? newVdot;

  /// Sessions without RPE judged from heart rate / pace / power instead.
  final int estimated;
  final int? oldFtp, newFtp;

  /// CSS in sec / 100 m (current, new).
  final int? oldCss, newCss;

  /// Change of the aerobic efficiency factor over [Recalibrator.trendDays] (0.04 = +4 %).
  final Map<Sport, double> efficiency;
}

class Recalibration {
  const Recalibration({required this.reasons, required this.stats, required this.changes, this.raceTimes, this.athlete = const {}});
  final List<RecalReason> reasons;
  final RecalStats stats;
  final List<RecalChange> changes;

  /// New race times for the profile (VDOT update), or null.
  final Map<String, int>? raceTimes;

  /// Other threshold updates for the profile ([AthleteData.merge] keys: ftp, swim times).
  final Map<String, dynamic> athlete;

  bool get isEmpty => changes.isEmpty && raceTimes == null && athlete.isEmpty;

  /// Plan id → changed fields, for [Repository.updateMany].
  Map<String, Map<String, dynamic>> get updates => {
    for (final c in changes)
      if (c.update.isNotEmpty) c.before.id: c.update,
  };
}
