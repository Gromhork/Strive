import 'dart:math';
import 'dart:ui';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'cardio_progression.dart';
import 'compliance.dart';
import 'insights.dart';
import 'plan_adjuster.dart';
import 'plan_gaps.dart';
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
///    growth rule) – not when a threshold (VDOT / FTP / CSS) rises in the same run (R3:
///    never volume and intensity together) and not on workouts the AutoAdjuster reduced in
///    the last 7 days.
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
/// 10. Return after a break (R4): a planned sport without a session for ≥ 10 days (or
///    < 15 % of its due training) restarts at 60 % (≥ 21 days off: 50 %) in days 1–7 and
///    70 % in days 8–14, without quality in days 1–7.
/// 11. R1 cap on every long session of the horizon: ≤ 1.1 × the longest of that sport in the
///    30 days before it (× 1.1 per earlier long session), else ≤ 0.6 × the longest before.
/// 12. Gaps ([PlanGaps], §11.1): sessions the rebuilt plan expects but the calendar lacks
///    (deleted, empty week, plan ended) are proposed as [RecalKind.added], adapted by the
///    rules above; a hard refill next to a hard day becomes easy (next to a race: left out),
///    and a refilled week never exceeds the planned week.
///
/// Reductions count from the original volume (kept in an [AutoAdjustment] record, reason
/// 'recal'), so repeated runs never compound.
class Recalibrator {
  Recalibrator(
    this.l,
    this.profile, {
    required this.plans,
    required this.sessions,
    required this.now,
    this.templates = const [],
    this.newId,
    this.fillGaps = true,
  });

  final AppLocalizations l;
  final UserProfile profile;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;
  final DateTime now;

  /// Programs for refilled strength sessions; ids for refilled workouts.
  final List<WorkoutTemplate> templates;
  final String Function()? newId;

  /// Propose sessions for gaps in the plan ([PlanGaps], rule 12).
  final bool fillGaps;

  static const lookbackDays = 14;
  static const horizonDays = 14;
  static const trendDays = 42;

  /// Time share of a quality session that its easy replacement keeps ([_toEasy]).
  static const swapFactor = 0.8;

  AthleteData get a => profile.athlete;
  DateTime get today => dayOnly(now);

  /// HRmax for the HR signals: measured, else raised from hard sessions, else predicted.
  late final HrMax hrMax = HrMax.of(profile, sessions: sessions, now: now);

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
      // Imported workouts carry an RPE estimated from their average HR (rpeFromHr, against a
      // predicted HRmax): judged like a session without RPE, so it doesn't count at full weight.
      final hrRpe = s.source != null && s.avgHr != null;
      if (s.rpe == null || hrRpe) {
        // No RPE: heart rate, pace / power and pace fade still tell how hard it was.
        final f = evaluateSession(p, s, profile, hrMax: hrMax);
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
    // ── Return after a break (R4): a sport without any session for >= 10 days (or ~0 % of
    // its due training in the look-back) although it was planned and trained before.
    final breaks = _breaks(window, linked);
    if (breaks.isNotEmpty) {
      reasons.add(RecalReason.returnAfterBreak);
      progress = false;
    }

    // ── Thresholds
    final oldVdot = Vdot.of(a) ?? Vdot.defaultFor(profile.level);
    var newVdot = _newVdot(oldVdot);
    if (newVdot != null) reasons.add(newVdot > oldVdot ? RecalReason.fasterRuns : RecalReason.slowerRuns);
    // Only sessions whose targets were set for the current thresholds: a session run against
    // the old (pre-update) paces / power would count again after every update – the VDOT rose
    // 40 → 45 for a 42.5 runner (one point a week on the same old sessions) and then fell back.
    final oldFtp = a.ftp;
    final cssNow = SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(profile.level);
    final byId = {for (final p in plans) p.id: p};
    final linkedNow = {
      for (final e in linked.entries)
        if (_targetsCurrent(byId[e.key], oldVdot, oldFtp, cssNow)) e.key: e.value,
    };
    final trends = CardioTrend.of(plans, linkedNow, profile, now: now, days: trendDays, hrMax: hrMax);
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
    // R3: never raise volume and intensity together – a higher VDOT / FTP / CSS is this
    // recalibration's step up, the volume stays.
    final thresholdUp =
        (newVdot != null && newVdot > oldVdot) || (newFtp != null && newFtp > (a.ftp ?? newFtp)) || (newCss != null && newCss < oldCss);
    if (progress && thresholdUp) {
      progress = false;
      reasons[reasons.indexOf(RecalReason.rpeLow)] = RecalReason.rpeLowHold;
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
    final reentry = (completion != null && completion < 0.5) || breaks.isNotEmpty;
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

    // ── Gaps (rule 12): sessions the plan expects but the calendar lacks – proposed, with
    // the same adaptations as the planned workouts below.
    final current = [
      for (final p in plans)
        if (moved.contains(p.id))
          adjust.where((c) => c.plan.id == p.id).map((c) => c.isMove ? _copy(p, date: c.to) : _copy(p, status: 'skipped')).firstOrNull ??
              _copy(p, status: 'skipped')
        else
          p,
    ];
    final gapFinder = fillGaps ? PlanGaps(l, profile, plans: current, now: now, templates: templates, newId: newId) : null;
    final fills = {for (final f in gapFinder?.find() ?? const <GapFill>[]) f.plan.id: f};
    final budgets = gapFinder?.budgets ?? const <String, int>{};
    // Workouts that count as hard neighbours of a refilled session (endurance, not skipped).
    final hardDays = <DateTime, bool>{}; // day → race on that day
    for (final p in current) {
      if (p.sport == Sport.gym || p.status == 'skipped' || !isHardPlan(p)) continue;
      final d = dayOnly(p.date);
      hardDays[d] = (hardDays[d] ?? false) || p.intensity == 'race';
    }

    // ── Upcoming endurance workouts
    final end = today.add(const Duration(days: horizonDays));
    final upcoming = [
      ...plans.where(
        (p) =>
            p.status == 'planned' &&
            !moved.contains(p.id) &&
            p.sport != Sport.gym &&
            p.intensity != 'race' &&
            !dayOnly(p.date).isBefore(today) &&
            dayOnly(p.date).isBefore(end),
      ),
      for (final f in fills.values) f.plan,
    ]..sort((x, y) => x.date.compareTo(y.date));
    final swappedSports = <Sport>{};
    final pz = newVdot == null ? null : PaceZones(newVdot);
    final longIndex = <Sport, int>{};
    var capped = false;
    var gapCount = 0, gapOmitted = 0;
    final fillLongs = <Sport, int>{};
    for (final p0 in upcoming) {
      final fill = fills[p0.id];
      var p = p0;
      final days = dayOnly(p.date).difference(today).inDays;
      var downgraded = false, eased = false, shortened = false;
      if (fill != null) {
        // Strength and race sessions come back as planned.
        if (p.sport == Sport.gym || p.intensity == 'race') {
          gapCount++;
          changes.add(RecalChange(p0, p, RecalKind.added, gap: GapNote(fill.why)));
          continue;
        }
        // Spacing: a refilled hard session never sits next to a hard day – it becomes easy
        // (next to a race it is left out).
        if (isHardPlan(p)) {
          final d = dayOnly(p.date);
          final near = [hardDays[Recalibrator._add(d, -1)], hardDays[Recalibrator._add(d, 1)]];
          if (near.contains(true)) {
            gapOmitted++;
            continue;
          }
          if (near.contains(false)) {
            p = _toEasy(p, pz);
            downgraded = true;
          }
        }
      }
      // Load factors: days 0–6, 7–13; refills after the 14-day horizon keep the plan's volume.
      final fd = days < 7 ? f1 : (days < horizonDays ? f2 : 1.0);
      final quality = p.intensity == 'tempo' || p.intensity == 'intervals';
      final rest = p.phase == 'recovery' || p.phase == 'taper';
      // R4: restart at 50–70 % of the pre-break volume (50 % after >= 3 weeks off), 70 % in
      // the second week; no intensity in the first week back.
      final gap = breaks[p.sport];
      final bf = gap == null ? 1.0 : (days < 7 ? (gap >= 21 ? 0.5 : 0.6) : (days < horizonDays ? 0.7 : 1.0));
      var w = p;
      RecalKind? kind;
      // Fatigue / re-entry: quality → easy (never in the taper – it keeps its intensity).
      if (quality &&
          p.phase != 'taper' &&
          ((gap != null && days < 7) || (swapAll && days < 7) || (swapFirst && days < horizonDays && !swappedSports.contains(p.sport)))) {
        swappedSports.add(p.sport);
        w = _toEasy(p, pz);
        // The swap already takes ~20 % off; a stronger reduction of the day (e.g. R4 60 %)
        // comes on top. The easy replacement is the reference of later steps and of undo
        // ('recalEasy': later reductions know the 0.8 is already in it).
        final easy = w;
        final fe = min(1.0, min(fd, bf) / swapFactor);
        if (fe < 0.97) w = _scaledTo(w, _amount(w) * fe);
        if (fill == null) w = _copy(w, auto: _record(easy, fresh: true, reason: 'recalEasy'));
        kind = RecalKind.toEasy;
        if (fill != null) eased = true;
      } else if (!quality) {
        final f = min(min(fd, bf), shortenLong && p.intensity == 'long' ? 0.9 : 1.0);
        final cur = _amount(p);
        var g = 1.0;
        if (fill != null) {
          g = f;
        } else if (f < 1) {
          // Reductions count from the original volume: they replace an earlier automatic or
          // recalibration step instead of stacking on it (running the assistant twice, or a
          // week later on an overlapping look-back, never compounds).
          final swapped = p.auto?.reason == 'recalEasy' ? swapFactor : 1.0;
          g = min(1.0, min(1.0, f / swapped) * _origAmount(p) / cur);
        } else if (progress && days < 7 && !rest && !_autoReducedRecently(p)) {
          // A workout the AutoAdjuster just reduced (e.g. easy run too fast) is not raised.
          g = 1.05;
        }
        // R1 (Frandsen 2025): every long session <= 1.1 × the longest of the 30 days before it
        // (each earlier long session of the horizon counts as done: × 1.1 per step); none in
        // those 30 days → 0.6 × the longest before (return after a break).
        if (p.intensity == 'long') {
          var k = longIndex[p.sport] ?? 0;
          if (days < horizonDays) longIndex[p.sport] = k + 1;
          // A refill after the horizon: every planned long session before it counts.
          if (fill != null && days >= horizonDays) k = _longsBefore(p, current) + (fillLongs[p.sport] ?? 0);
          final cap = _longCap(p, k);
          if (cap != null && cur * g > cap * 1.02) {
            g = cap / cur;
            capped = true;
            if (fill != null) shortened = true;
          }
        }
        // 3 %: below the rounding of the steps (100 m / 1 min), so a second run is a no-op.
        if ((g - 1).abs() >= 0.03) {
          final scaled = _scaledTo(p, cur * g);
          if (_amount(scaled) != cur) {
            w = fill != null ? scaled : _copy(scaled, auto: _record(p));
            kind = _amount(scaled) < cur ? RecalKind.easier : RecalKind.harder;
          }
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
      if (fill != null) {
        // The refilled week never exceeds the planned week (its sport's minutes).
        final left = budgets[fill.budgetKey];
        if (left != null && w.durationMin > left + 2) {
          if (left < 20) {
            gapOmitted++;
            continue;
          }
          w = _scaledTo(w, _amount(w) * left / w.durationMin);
          shortened = true;
        }
        if (left != null) budgets[fill.budgetKey] = max(0, left - w.durationMin);
        if (w.intensity == 'long') fillLongs[w.sport] = (fillLongs[w.sport] ?? 0) + 1;
        if (isHardPlan(w)) {
          final d = dayOnly(w.date);
          hardDays[d] = hardDays[d] ?? false;
        }
        gapCount++;
        changes.add(
          RecalChange(p0, w, RecalKind.added, gap: GapNote(fill.why, downgraded: downgraded, eased: eased, shortened: shortened)),
        );
        continue;
      }
      if (kind != null) changes.add(RecalChange(p, kind == RecalKind.paces ? w : _noted(w), kind));
    }

    if (capped) reasons.add(RecalReason.longCap);
    if (gapCount > 0) reasons.add(RecalReason.planGaps);
    if (gapOmitted > 0) reasons.add(RecalReason.gapsOmitted);

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
        breakDays: breaks.values.fold<int?>(null, (x, v) => max(x ?? 0, v)),
        gaps: gapCount,
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

  /// Whether [p]'s work targets were set for the current VDOT / FTP / CSS (true when it has
  /// none to compare: easy / long runs, technique swims, plans without paces or power).
  static bool _targetsCurrent(PlannedWorkout? p, double vdot, int? ftp, int css) {
    if (p == null) return true;
    for (final s in p.steps) {
      if (!s.isWork) continue;
      switch (p.sport) {
        case Sport.run:
          final f = switch (s.zone) {
            'T' => 0.88,
            'I' => 0.975,
            _ => null,
          };
          if (f == null || s.paceMin == null || s.paceMax == null) continue;
          return (Vdot.vo2(60000 / ((s.paceMin! + s.paceMax!) / 2)) / f - vdot).abs() < 0.75;
        case Sport.ride:
          if (ftp == null || s.powerMin == null) continue;
          return (PowerZones(ftp).range(s.zone).$1 - s.powerMin!).abs() <= 3;
        case Sport.swim:
          if (s.paceMin == null) continue;
          return (SwimZones(css).range(s.zone).$1 - s.paceMin!).abs() <= 1;
        case Sport.gym:
          return true;
      }
    }
    return true;
  }

  /// A race / time trial, or a run that was rated (RPE ≥ 8) or measured (average HR
  /// ≥ 88 % HRmax, zone 4+) as hard.
  bool _maximalEffort(Session s) {
    if ((s.rpe ?? 0) >= 8) return true;
    if (s.avgHr != null && s.avgHr! >= 0.88 * hrMax.bpm) return true;
    final p = plans.where((p) => p.id == s.planId || (p.sessionId != null && p.sessionId == s.id)).firstOrNull;
    return p?.intensity == 'race';
  }

  /// Sports with a training break: sport → days without a session (>= 10, or the look-back
  /// when ~0 % of the due training was done). Only sports that were planned (>= 2 due
  /// workouts in the look-back) and trained before – a sport the plan just started is no return.
  Map<Sport, int> _breaks(List<PlannedWorkout> window, Map<String, Session> linked) {
    final out = <Sport, int>{};
    final from = today.subtract(const Duration(days: lookbackDays));
    for (final sport in {for (final p in plans) p.sport}) {
      if (sport == Sport.gym) continue;
      final due = window.where((p) => p.sport == sport && p.durationMin > 0 && p.intensity != 'race').toList();
      if (due.length < 2) continue;
      final mine = sessions.where((x) => x.sport == sport && !x.start.isAfter(now)).toList();
      if (mine.isEmpty) continue;
      final last = mine.map((x) => x.start).reduce((x, y) => x.isAfter(y) ? x : y);
      final gap = today.difference(dayOnly(last)).inDays;
      if (gap >= 10) {
        out[sport] = gap;
      } else if (due.length >= 3 && mine.any((x) => x.start.isBefore(from)) && (weeklyCompletion(due, linked, now: now) ?? 1) < 0.15) {
        out[sport] = lookbackDays;
      }
    }
    return out;
  }

  /// Runs and swims are measured in distance, rides (and plans without a distance) in time –
  /// as in [AutoAdjuster].
  static bool _byKm(PlannedWorkout p) => p.sport != Sport.ride && (p.distanceKm ?? 0) > 0;
  static double _amount(PlannedWorkout p) => _byKm(p) ? p.distanceKm! : p.durationMin.toDouble();

  /// Volume before any automatic / recalibration step (the generator's), same unit.
  static double _origAmount(PlannedWorkout p) {
    final o = p.auto;
    if (o == null) return _amount(p);
    return _byKm(p) && (o.distanceKm ?? 0) > 0 ? o.distanceKm! : o.durationMin.toDouble();
  }

  /// Reduced by the AutoAdjuster in the last 7 days.
  bool _autoReducedRecently(PlannedWorkout p) {
    final o = p.auto;
    return o != null && !o.reason.startsWith('recal') && now.difference(o.at).inDays < 7 && _amount(p) < _origAmount(p) - 0.01;
  }

  /// Record of a recalibration volume change: keeps the generator's original (undo, and
  /// the reference of later steps).
  AutoAdjustment _record(PlannedWorkout p, {bool fresh = false, String reason = 'recal'}) {
    final o = fresh ? null : p.auto;
    return AutoAdjustment(
      sessionId: '',
      reason: o?.reason == 'recalEasy' ? 'recalEasy' : reason,
      at: now,
      durationMin: o?.durationMin ?? p.durationMin,
      distanceKm: o == null ? p.distanceKm : o.distanceKm,
      steps: o?.steps ?? p.steps,
    );
  }

  /// R1 cap of the [k]-th long session (0-based) of its sport in the horizon, in the unit of
  /// [_amount], or null without any history of that sport.
  double? _longCap(PlannedWorkout p, int k) {
    double? longest(int fromDays, int toDays) {
      final day = dayOnly(p.date);
      var best = 0.0;
      for (final s in sessions) {
        if (s.sport != p.sport || s.start.isAfter(now)) continue;
        final ago = day.difference(dayOnly(s.start)).inDays;
        if (ago < fromDays || ago > toDays) continue;
        // Sessions without a distance (treadmill without a foot pod) count by time, in
        // the plan's unit (its own km per minute).
        final byTime = s.durationSec / 60 * (_amount(p) / max(1, p.durationMin));
        best = max(best, _byKm(p) && s.distanceM > 0 ? s.distanceM / 1000 : byTime);
      }
      return best > 0 ? best : null;
    }

    final recent = longest(1, 30);
    if (recent != null) return recent * pow(1.1, k + 1);
    final before = longest(31, 120);
    return before == null ? null : before * 0.6 * pow(1.1, k);
  }

  // ───────────────────────────── Workout edits ─────────────────────────────

  /// [p] scaled so that its volume ([_amount]) is about [target]. Parts that keep their
  /// length (strides, short repeats) make a plain × f overshoot, so the factor is corrected;
  /// sets of short repeats only (e.g. a technique swim) change by whole repeats instead
  /// ([AutoAdjuster.scaleWorkout]).
  PlannedWorkout _scaledTo(PlannedWorkout p, double target) {
    final cur = _amount(p);
    PlannedWorkout fit(PlannedWorkout Function(double g) scale) {
      var g = target / cur, w = scale(g);
      for (var i = 0; i < 3; i++) {
        final got = _amount(w);
        if (got <= 0 || (got / target - 1).abs() < 0.02) break;
        g = (g * target / got).clamp(0.75 * target / cur, 1.25 * target / cur);
        w = scale(g);
      }
      return w;
    }

    var w = fit((g) => _scaled(p, g));
    if ((_amount(w) / target - 1).abs() > 0.08) {
      final alt = fit((g) => _copy(AutoAdjuster.scaleWorkout(p, g, profile), description: p.description));
      if ((_amount(alt) - target).abs() < (_amount(w) - target).abs()) w = alt;
    }
    return w;
  }

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
    final minutes = max(20, (p.durationMin * swapFactor / 5).round() * 5);
    final hz = HrZones(hrMax.bpm, a.restHr);
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

  static DateTime _add(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// Planned long sessions of [p]'s sport from today until the day before [p].
  int _longsBefore(PlannedWorkout p, List<PlannedWorkout> all) =>
      all
          .where(
            (x) =>
                x.sport == p.sport &&
                x.intensity == 'long' &&
                x.status == 'planned' &&
                !dayOnly(x.date).isBefore(today) &&
                dayOnly(x.date).isBefore(dayOnly(p.date)),
          )
          .length;

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
    AutoAdjustment? auto,
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
    auto: auto ?? p.auto,
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
  returnAfterBreak,
  longCap,

  /// Quality felt easy, but a threshold went up: no extra volume this time (R3).
  rpeLowHold,

  /// Sessions the plan expects are missing (deleted, empty week, plan ended) – refills proposed.
  planGaps,

  /// Missing sessions that are not refilled (next to a race, week volume already reached).
  gapsOmitted,
}

/// What happens to one workout.
enum RecalKind { easier, harder, toEasy, moved, dropped, paces, added }

/// Why and how a refilled session ([RecalKind.added]) was adapted.
class GapNote {
  const GapNote(this.why, {this.downgraded = false, this.eased = false, this.shortened = false});
  final GapWhy why;

  /// Hard session next to a hard day → easy.
  final bool downgraded;

  /// Quality → easy because of fatigue / re-entry (rules 1, 2, 10).
  final bool eased;

  /// Shorter than generated: week volume or R1 long-run cap.
  final bool shortened;
}

class RecalChange {
  const RecalChange(this.before, this.after, this.kind, {this.gap});
  final PlannedWorkout before;
  final PlannedWorkout after;
  final RecalKind kind;

  /// Set for a refilled session ([RecalKind.added]).
  final GapNote? gap;

  /// Firestore update of this workout (only the fields that change). A volume change
  /// carries an [AutoAdjustment] record (reason 'recal') with the generator's original;
  /// a quality → easy swap records the easy replacement instead (undo restores volume only –
  /// the quality session's steps under an easy title would be stale).
  Map<String, dynamic> get update {
    final b = before.toMap(), a = after.toMap();
    return {
      for (final k in a.keys)
        if (!_eq(a[k], b[k])) k: a[k],
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
    this.breakDays,
    this.gaps = 0,
  });

  /// Refilled sessions proposed (gaps in the plan).
  final int gaps;

  /// Longest training break of a planned sport (days without a session), or null.
  final int? breakDays;

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
      if (c.kind != RecalKind.added && c.update.isNotEmpty) c.before.id: c.update,
  };

  /// New workouts that fill gaps of the plan, for [Repository.savePlans].
  List<PlannedWorkout> get additions => [
    for (final c in changes)
      if (c.kind == RecalKind.added) c.after,
  ];

  /// This proposal without the changes in [skip] (refills the athlete unticked).
  Recalibration without(Set<RecalChange> skip) => Recalibration(
    reasons: reasons,
    stats: stats,
    changes: [...changes.where((c) => !skip.contains(c))],
    raceTimes: raceTimes,
    athlete: athlete,
  );
}
