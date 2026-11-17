import 'dart:math';
import 'dart:ui';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'cardio_progression.dart';
import 'compliance.dart';
import 'fitness_state.dart';
import 'goal_forecast.dart';
import 'insights.dart';
import 'plan_adjuster.dart';
import 'plan_gaps.dart';
import 'plan_generator.dart';
import 'progression_check.dart';
import 'session_feedback.dart';
import 'zones.dart';

/// "Review plan" (adapt plan to your training): adapts the upcoming weeks of the current plan to how the
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
///    becomes easy (re-entry) – only when the key sessions were missed; with them done the easy
///    volume comes down first. Needs ≥ 3 due workouts over ≥ 7 days of plan history.
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

  /// Plan history (days since the first due workout in the look-back) completion needs.
  static const minHistoryDays = 7;

  /// Time share of a quality session that its easy replacement keeps ([_toEasy]).
  static const swapFactor = 0.8;

  AthleteData get a => profile.athlete;
  DateTime get today => dayOnly(now);

  /// HRmax for the HR signals: measured, else raised from hard sessions, else predicted.
  late final HrMax hrMax = HrMax.of(profile, sessions: sessions, now: now);

  Recalibration run() {
    final linked = linkPlanSessions(plans, sessions, profile: profile);
    final from = addDays(today, -lookbackDays);
    final window = plans.where((p) => !dayOnly(p.date).isBefore(from) && dayOnly(p.date).isBefore(today)).toList();

    // ── RPE signals
    var tooHard = 0.0, tooEasy = 0, rated = 0, cutShort = 0, estimated = 0;
    // Too-hard score of the last 7 days alone (the fatigue must still be there).
    var tooHardLastWeek = 0.0;
    for (final p in window.where((p) => p.sport != Sport.gym && p.intensity != 'race')) {
      final s = linked[p.id];
      if (s == null) continue;
      final r = complianceRatio(p, s, profile: profile);
      if (r != null && r < ComplianceScale.greenMin) cutShort++;
      // Clearly more than planned (> 150 %): a load spike – counts like a too-hard session (a long
      // run, tempo or interval session ×1, an easy one ×½), whatever the RPE says.
      if (overPlan(p, s, profile: profile)) {
        final h = isHardPlan(p) ? 1.0 : 0.5;
        tooHard += h;
        if (!dayOnly(p.date).isBefore(_add(today, -7))) tooHardLastWeek += h;
      }
      // Imported workouts carry an RPE estimated from their average HR (rpeFromHr, against a
      // predicted HRmax): judged like a session without RPE, so it doesn't count at full weight.
      final hrRpe = s.source != null && s.avgHr != null;
      if (s.rpe == null || hrRpe) {
        // No RPE: heart rate, pace / power and pace fade still tell how hard it was.
        final f = evaluateSession(p, s, profile, hrMax: hrMax);
        if (!f.rated) continue;
        estimated++;
        final h = f.clearlyHarder ? (f.score >= 0.6 ? 1.0 : 0.5) : 0.0;
        tooHard += h;
        if (!dayOnly(p.date).isBefore(_add(today, -7))) tooHardLastWeek += h;
        if (f.isQuality && f.clearlyEasier) tooEasy++;
        continue;
      }
      rated++;
      final h = rpeLoad(p.intensity, s.rpe!);
      tooHard += h;
      if (!dayOnly(p.date).isBefore(_add(today, -7))) tooHardLastWeek += h;
      if (rpeTooEasy(p.intensity, s.rpe!)) tooEasy++;
    }
    // The look-back a week ago ([today − 21, today − 7)): was the RPE already high last Monday?
    var tooHardBefore = 0.0;
    final prevFrom = _add(today, -lookbackDays - 7), prevTo = _add(today, -7);
    for (final p in plans) {
      final d = dayOnly(p.date);
      if (d.isBefore(prevFrom) || !d.isBefore(prevTo) || p.sport == Sport.gym || p.intensity == 'race') continue;
      final s = linked[p.id];
      if (s == null) continue;
      if (s.rpe == null || (s.source != null && s.avgHr != null)) {
        final f = evaluateSession(p, s, profile, hrMax: hrMax);
        if (f.rated && f.clearlyHarder) tooHardBefore += f.score >= 0.6 ? 1 : 0.5;
        continue;
      }
      tooHardBefore += rpeLoad(p.intensity, s.rpe!);
    }
    // ── Compliance – only meaningful with a real sample: ≥ 3 due workouts spread over ≥ 7 days.
    // A plan that started yesterday with one missed workout is no "0 % done" (the missed key
    // session is moved inside its week instead, rule 5).
    final dueList = window.where((p) => p.durationMin > 0 && p.intensity != 'race').toList();
    final history = dueList.isEmpty ? 0 : daysBetween(dueList.map((p) => dayOnly(p.date)).reduce((x, y) => x.isBefore(y) ? x : y), today);
    final completion =
        dueList.length >= 3 && history >= minHistoryDays ? weeklyCompletion(dueList, linked, now: now, profile: profile) : null;
    // Key sessions (quality / long) of the look-back that were done: chronic partial adherence
    // (easy runs skipped, key sessions done) cuts easy volume, not the key sessions (B9). A key
    // session counts from half of it ([adaptationCompleted]): 4 of 30 km is no long run done.
    final keyDue = dueList.where((p) => p.sport != Sport.gym && isHardPlan(p)).toList();
    final keysDone = keyDue.where((p) => adaptationCompleted(p, linked, profile: profile)).length;
    final keysMissed = keyDue.isEmpty || keysDone < 0.75 * keyDue.length;
    // Slots (sport + weekday) the athlete skipped ≥ 2× in the look-back: with the key sessions done,
    // only these come down – the easy runs the athlete still does keep their volume (partial adherence).
    final misses = <String, int>{};
    for (final p in dueList) {
      if (p.sport == Sport.gym || adaptationCompleted(p, linked, profile: profile)) continue;
      misses.update(_slot(p), (n) => n + 1, ifAbsent: () => 1);
    }
    final skippedSlots = {
      for (final e in misses.entries)
        if (e.value >= 2) e.key,
    };

    // ── Decide the load factors: fatigue (RPE) and compliance separately – a long session
    // whose key sessions were all done only follows the fatigue factors.
    var f1 = 1.0, f2 = 1.0; // days 0–6, 7–13
    var r1 = 1.0, r2 = 1.0; // fatigue only
    var swapAll = false, swapFirst = false, shortenLong = false, progress = false;
    // Quality sessions kept but with fewer repeats (days 0–6, 7–13) – the way back after fatigue.
    var q1 = 1.0, q2 = 1.0;
    final reasons = <RecalReason>[];
    // Fatigue (C4): rule 1 swapped every quality session for easy running week after week while
    // the RPE stayed high (7–11 weeks). Now: the first week as before; two weeks in a row → one
    // recovery week (≈ 70 %, no intensity), then quality returns at ~75 % of its repeats; still too
    // hard after the recovery week → keep the reduced quality and ask about sleep, illness and
    // stress (overreaching, Meeusen 2013) instead of another month of easy running.
    final recoveryRecently = plans.any(
      (p) => _recoveryMark(p) && !dayOnly(p.date).isBefore(_add(today, -21)) && dayOnly(p.date).isBefore(today),
    );
    final recoveryPlanned = plans.any((p) => _recoveryMark(p) && !dayOnly(p.date).isBefore(today));
    if (tooHard >= 2) {
      reasons.add(RecalReason.rpeHigh);
      if (recoveryRecently && !recoveryPlanned) {
        reasons.add(RecalReason.fatigueCheck);
        r1 = 0.9;
        q1 = q2 = 0.75;
      } else if ((tooHardBefore >= 2 && tooHardLastWeek >= 1) || recoveryPlanned) {
        // (A recovery week already proposed: the same proposal again – no compounding.)
        reasons.add(RecalReason.fatigueRecovery);
        r1 = 0.7;
        r2 = 0.9;
        swapAll = true;
        q2 = 0.75;
      } else if (tooHard >= 3) {
        r1 = 0.8;
        r2 = 0.9;
        swapAll = true;
      } else {
        r1 = 0.9;
        swapFirst = true;
      }
      f1 = r1;
      f2 = r2;
    }
    var recoveryWeek = reasons.contains(RecalReason.fatigueRecovery);
    var easyFirst = false;
    // Long runs missed while the rest was done (I14): the easy runs are not the problem – they keep
    // their volume; the next long run moves to a day with more time instead.
    final restDue = dueList.where((p) => p.intensity != 'long').toList();
    final restCompletion = restDue.length >= 3 ? weeklyCompletion(restDue, linked, now: now, profile: profile) : null;
    final longMissed =
        dueList.where((p) => p.intensity == 'long' && p.sport != Sport.gym && !adaptationCompleted(p, linked, profile: profile)).length;
    final onlyLongMissed = longMissed >= 1 && (restCompletion ?? 0) >= 0.9;
    if (completion != null && completion < 0.7) {
      reasons.add(RecalReason.lowCompletion);
      easyFirst = !keysMissed;
      if (onlyLongMissed) {
        // Nothing to cut: the long run itself follows R1 below.
      } else if (completion < 0.5) {
        f1 = min(f1, 0.8);
        f2 = min(f2, 0.9);
        // Quality → easy only when the key sessions themselves were missed (re-entry); with the
        // key sessions done the easy volume comes down first.
        if (keysMissed) swapFirst = true;
      } else {
        f1 = min(f1, 0.9);
      }
    }
    if (cutShort >= 2) {
      reasons.add(RecalReason.cutShort);
      shortenLong = true;
    }
    if (reasons.isEmpty && tooEasy >= 2 && (completion ?? 1) >= 0.9) {
      // "A little more volume" at most every other week and [maxVolumeRaises] times per plan – the
      // +5 % came every Monday for weeks (review: W2–W7); quality that keeps feeling easy is a
      // threshold question (rules 7–9), not a volume one.
      final raised = _volumeRaiseWeeks();
      final raisable = plans.any(
        (p) =>
            p.status == 'planned' &&
            (p.intensity == 'easy' || p.intensity == 'long') &&
            p.sport != Sport.gym &&
            p.phase != 'recovery' &&
            p.phase != 'taper' &&
            !dayOnly(p.date).isBefore(today) &&
            dayOnly(p.date).isBefore(_add(today, 7)),
      );
      if (!raisable) {
        // A recovery / taper week ahead: nothing to raise – no "a little more volume" message.
      } else if (raised.contains(startOfWeek(_add(today, -7))) || raised.contains(startOfWeek(today)) || raised.length >= maxVolumeRaises) {
        reasons.add(RecalReason.rpeLowSpaced);
      } else {
        reasons.add(RecalReason.rpeLow);
        progress = true;
      }
    }
    // ── Return after a break (R4): a sport without any session for >= 10 days (or ~0 % of
    // its due training in the look-back) although it was planned and trained before.
    final breaks = _breaks(window, linked);
    if (breaks.isNotEmpty) {
      reasons.add(RecalReason.returnAfterBreak);
      progress = false;
    }
    // ── Taper / race week (§11.6): the plan's reduced volume is the point – no fatigue or completion
    // cuts on top, no recovery week, never more volume; one taper message instead of the generic
    // ones, and a warning when the athlete trained clearly more than the taper planned (> 110 %).
    final taperDone = _taperDone(linked);
    if (_inTaper()) {
      const volume = {
        RecalReason.rpeHigh,
        RecalReason.rpeLow,
        RecalReason.rpeLowSpaced,
        RecalReason.lowCompletion,
        RecalReason.cutShort,
        RecalReason.fatigueRecovery,
        RecalReason.fatigueCheck,
      };
      final generic = reasons.any(volume.contains);
      reasons.removeWhere(volume.contains);
      f1 = f2 = r1 = r2 = q1 = q2 = 1;
      swapAll = swapFirst = shortenLong = progress = easyFirst = recoveryWeek = false;
      if ((taperDone ?? 0) > taperOverdoShare) {
        reasons.add(RecalReason.taperOverdo);
      } else if (generic) {
        reasons.add(RecalReason.taper);
      }
    }

    // ── Thresholds
    final oldVdot = Vdot.of(a) ?? Vdot.defaultFor(profile.level);
    // The one fitness model (baseline, break penalty, cap) – shared with the goal forecast.
    final fitness = FitnessState.of(profile, plans: plans, sessions: sessions, now: now);
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
    // C5: training-derived VDOT steps (rule 7) only every ≥ 3 weeks (Daniels: ~1 point per 4–6
    // weeks), and the total rise since the plan start ≤ [GoalModel.optimistic] × the model's gain
    // for the weeks trained – the VDOT ran 40.4 → 48.4 in 8 weeks, one point every Monday.
    final lastStep = a.vdotEstimateAt;
    final stepDue = lastStep == null || daysBetween(lastStep, today) >= minVdotStepDays;
    if (newVdot == null && run != null && stepDue) {
      if (run.slowAndHard >= 3) {
        newVdot = oldVdot - 1;
        reasons.add(RecalReason.runTrendSlower);
      } else if (run.easyAndOnTarget >= 3 && run.harder == 0 && (run.efficiencyChange ?? 0) >= 0) {
        newVdot = oldVdot + 1;
        reasons.add(RecalReason.runTrendFaster);
      } else if (_fasterAtEffort(run) >= 3 && run.harder == 0 && (run.efficiencyChange ?? 0) >= 0) {
        // ≥ 3 quality runs ≥ 3 % faster than their targets at the intended effort (not harder) –
        // the forecast already calls that "ahead"; the paces follow (B10). Only sessions run
        // against the current VDOT's T / I targets count, so the same sessions never lift it twice.
        newVdot = oldVdot + 1;
        reasons.add(RecalReason.runTrendFaster);
      }
      if (newVdot != null && newVdot > oldVdot) {
        final cap = fitness.planStart == null ? null : fitness.cap;
        if (cap != null && newVdot > cap) {
          if (cap >= oldVdot + 0.3) {
            newVdot = cap;
          } else {
            newVdot = null;
            reasons.remove(RecalReason.runTrendFaster);
          }
        }
      }
      if (newVdot != null) newVdot = double.parse(newVdot.toStringAsFixed(1));
    }
    // IMPORTANT 1: no fitness increase while a break / return is active, after less than half of the
    // training, or while the forecast's model still takes VDOT off for a break – the paces must not
    // speed up on the way back (sim: VDOT 42.0 → 42.8 in the week back from two sick weeks).
    if (newVdot != null &&
        newVdot > oldVdot &&
        (breaks.isNotEmpty || (completion != null && completion < 0.5) || fitness.breakPenalty > 0)) {
      newVdot = null;
      reasons.removeWhere((r) => r == RecalReason.fasterRuns || r == RecalReason.runTrendFaster);
    }
    // FTP / CSS steps like the VDOT's (C5): at most every [minVdotStepDays] days, and the rise since
    // the plan start capped ([maxFtpRise], [maxCssGain]) – the FTP ran 220 → 287 W (+30 %) in 12 weeks.
    // (The training block's start: a plan re-created mid-plan keeps the caps of the block it continues.)
    final planStart = fitness.planStart ?? _planStart();
    bool since(DateTime? at) => at != null && (planStart == null || !dayOnly(at).isBefore(planStart));
    bool due(DateTime? at) => at == null || daysBetween(at, today) >= minVdotStepDays;
    final ftpBase = since(a.ftpStepAt) && a.ftpBase != null ? a.ftpBase! : a.ftp;
    // No fitness rise while a return after a break is active or less than half was trained.
    final noRise = breaks.isNotEmpty || (completion != null && completion < 0.5);
    int? newFtp;
    if (a.ftp != null && ride != null && due(a.ftpStepAt)) {
      if (ride.strongAndComfortable >= 2 && ride.harder == 0 && !noRise) {
        final up = min((a.ftp! * 1.03).round(), (ftpBase! * (1 + maxFtpRise(profile))).floor());
        if (up > a.ftp!) {
          newFtp = up;
          reasons.add(RecalReason.ftpUp);
        }
      } else if (ride.slowAndHard >= 2) {
        newFtp = (a.ftp! * 0.97).round();
        reasons.add(RecalReason.ftpDown);
      }
    }
    final oldCss = SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(profile.level);
    final cssBase = since(a.cssStepAt) && a.cssBase != null ? a.cssBase! : oldCss;
    int? newCss;
    if (swim != null && due(a.cssStepAt)) {
      if (swim.strongAndComfortable >= 3 && swim.harder == 0 && !noRise) {
        final faster = max(oldCss - 2, (cssBase * (1 - maxCssGain)).ceil());
        if (faster < oldCss) {
          newCss = faster;
          reasons.add(RecalReason.cssFaster);
        }
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
    final reentry = (completion != null && completion < 0.5 && keysMissed) || breaks.isNotEmpty;
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
    final end = addDays(today, horizonDays);
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
    // Run/walk stage held (I13): the coming run/walk sessions repeat the stage of a week earlier.
    final held = _repeatStage(upcoming.where((p) => fills[p.id] == null).toList());
    if (held.isNotEmpty) reasons.add(RecalReason.repeatStage);
    // Long runs missed on their day (I14): the next long run moves to a day with more time.
    final newDates = onlyLongMissed ? _moveLong(upcoming.where((p) => fills[p.id] == null).toList(), linked) : const <String, DateTime>{};
    if (newDates.isNotEmpty) reasons.add(RecalReason.moveLong);
    for (final p0 in upcoming) {
      final fill = fills[p0.id];
      var p = held[p0.id] ?? p0;
      final days = daysBetween(today, dayOnly(p.date));
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
      // Partial adherence: long sessions and the slots the athlete still trains keep their volume.
      final keepLong = easyFirst && (p.intensity == 'long' || !skippedSlots.contains(_slot(p)));
      final fd = days < 7 ? (keepLong ? r1 : f1) : (days < horizonDays ? (keepLong ? r2 : f2) : 1.0);
      final quality = p.intensity == 'tempo' || p.intensity == 'intervals';
      final rest = p.phase == 'recovery' || p.phase == 'taper';
      // R4: restart at 50–70 % of the pre-break volume (50 % after >= 3 weeks off), 70 % in
      // the second week; no intensity in the first week back.
      final gap = breaks[p.sport];
      final bf = gap == null ? 1.0 : (days < 7 ? (gap >= 21 ? 0.5 : 0.6) : (days < horizonDays ? 0.7 : 1.0));
      var w = p;
      RecalKind? kind = held.containsKey(p0.id) ? RecalKind.easier : null;
      // Quality kept with fewer repeats after a recovery week (C4).
      final qf = p.phase == 'taper' ? 1.0 : (days < 7 ? q1 : (days < horizonDays ? q2 : 1.0));
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
        if (fe < 0.97) w = _scaledTo(w, max(_amount(w) * fe, min(_amount(w), runFloor(w, profile))));
        if (fill == null) w = _copy(w, auto: _record(easy, fresh: true, reason: 'recalEasy'));
        kind = RecalKind.toEasy;
        if (fill != null) eased = true;
      } else if (quality && qf < 1) {
        // Quality kept at ~75 % of its work (C4, review 2026-11 adapt-4): whole repeats dropped – their length and
        // pace stay, the stimulus with them – always from the original, so a second run proposes nothing new.
        final fewer = _fewerRepeats(p, qf);
        if (fewer != null) {
          w = fill != null ? fewer : _copy(fewer, auto: _record(p));
          kind = RecalKind.easier;
        }
      } else if (!quality) {
        final f = quality ? qf : min(min(fd, bf), shortenLong && p.intensity == 'long' ? 0.9 : 1.0);
        final cur = _amount(p);
        var g = 1.0;
        if (fill != null) {
          g = f;
        } else if (f < 1) {
          // Reductions count from the original volume: they replace an earlier automatic or
          // recalibration step instead of stacking on it (running the assistant twice, or a
          // week later on an overlapping look-back, never compounds).
          final swapped = (p.auto?.reason ?? '').startsWith('recalEasy') ? swapFactor : 1.0;
          g = min(1.0, min(1.0, f / swapped) * _origAmount(p) / cur);
        } else if (progress && days < 7 && !rest && !_autoReducedRecently(p)) {
          // A workout the AutoAdjuster just reduced (e.g. easy run too fast) is not raised.
          g = 1.05;
          // A long session never grows beyond its time cap ([PlanGenerator.longSessionCapMin]: marathon long run
          // 3 h …) – and a long run already beyond it (the opt-in extension, agreed up to 3:30 h / 4 h) is not
          // raised at all (review 2026-11: only R1 limited the +5 %).
          final capMin = p.intensity == 'long' ? (_longCapMin[p.sport] ??= PlanGenerator.longSessionCapMin(profile, p.sport) ?? 0) : 0;
          if (capMin > 0) g = p.durationMin >= capMin ? 1.0 : min(g, capMin / p.durationMin);
        }
        // Floors (C4 / I15): a reduction never takes a run below 25 min and 4 km (beginners
        // 20 min) – 15-minute returns and 2.7 km "easy runs" are no training.
        if (g < 1 && !quality) g = max(g, min(cur, runFloor(p, profile)) / cur);
        var capHit = false;
        // R1 (Frandsen 2025): every long session <= 1.1 × the longest of the 30 days before it
        // (each earlier long session of the horizon counts as done: × 1.1 per step); none in
        // those 30 days → 0.6 × the longest before (return after a break).
        if (p.intensity == 'long') {
          var k = longIndex[p.sport] ?? 0;
          if (days < horizonDays) longIndex[p.sport] = k + 1;
          // A refill after the horizon: every planned long session before it counts.
          if (fill != null && days >= horizonDays) k = _longsBefore(p, current) + (fillLongs[p.sport] ?? 0);
          final cap = _longCapped(p) ? null : _longCap(p, k, linked);
          if (cap != null && cur * g > cap * 1.02) {
            // Never below the run floor (20 min run/walk and beginners, else 25 min and 4 km).
            g = max(cap / cur, min(1.0, runFloor(p, profile) / cur));
            capHit = true;
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
        // The long-run cap only counts as a reason when it actually shortened the session.
        if (capHit && kind == RecalKind.easier) capped = true;
      }
      // Changes of a proposed recovery week carry the marker the next run recognises it by.
      if (recoveryWeek && days < 7 && fill == null && kind != null && w.auto != null && !w.auto!.reason.endsWith('Recovery')) {
        final o = w.auto!;
        w = _copy(
          w,
          auto: AutoAdjustment(
            sessionId: o.sessionId,
            reason: '${o.reason}Recovery',
            at: o.at,
            durationMin: o.durationMin,
            distanceKm: o.distanceKm,
            steps: o.steps,
          ),
        );
      }
      final moveTo = newDates[p0.id];
      if (moveTo != null && fill == null) {
        w = _copy(w, date: DateTime(moveTo.year, moveTo.month, moveTo.day, w.date.hour, w.date.minute));
        kind ??= RecalKind.moved;
      }
      if (pz != null && w.sport == Sport.run && kind != RecalKind.toEasy) {
        final paced = _withPaces(w, pz, PaceZones(oldVdot));
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
      if (kind != null) changes.add(RecalChange(p0, kind == RecalKind.paces ? w : _noted(w), kind));
    }

    if (capped) reasons.add(RecalReason.longCap);
    if (gapCount > 0) reasons.add(RecalReason.planGaps);
    if (gapOmitted > 0) reasons.add(RecalReason.gapsOmitted);

    // ── Is the race goal still reachable (C3)? One verdict (IMPORTANT 2): the goal forecast's "at
    // risk" – judged against the ORIGINAL plan's long runs, adherence and the one fitness model, not a
    // fresh re-plan from today (that flagged "too short" for an athlete back on plan after a sick
    // fortnight). The setup's feasibility from today adds the options (later race, shorter distance).
    PlanFeasibility? feasibility;
    final forecast =
        a.eventDate != null && a.eventDistance != null ? GoalForecast.of(profile, plans: plans, sessions: sessions, now: now) : null;
    int? goalTargetSec, goalForecastSec;
    if (forecast != null && forecast.atRisk) {
      reasons.add(RecalReason.goalAtRisk);
      feasibility = _feasibilityNow();
      const behind = {
        ForecastReason.longRunBehind,
        ForecastReason.missedTraining,
        ForecastReason.trainingBreak,
        ForecastReason.sessionsSkipped,
      };
      if (forecast.targetSec != null &&
          forecast.raceDaySec != null &&
          !forecast.reasons.any(behind.contains) &&
          forecast.progression?.behind != true) {
        goalTargetSec = forecast.targetSec;
        goalForecastSec = forecast.raceDaySec;
      }
    }
    // ── Chronic skipping over the last 4 weeks (IMPORTANT 4) – the same counts as the forecast.
    final plannedWeeks = fitness.planStart == null ? 0.0 : fitness.elapsedWeeks;
    if (plannedWeeks >= 3 && fitness.recentDue >= 6 && fitness.recentDone < 0.7 * fitness.recentDue) {
      reasons.add(RecalReason.sessionsSkipped);
    }
    if (plannedWeeks >= 3 && fitness.keyDue >= 3 && fitness.keyDone < 0.75 * fitness.keyDue) reasons.add(RecalReason.keySessionsMissed);
    // The new VDOT for the profile (newly generated plans use it too) – in its own field, never as
    // a synthetic race time (C5). Race times an older version wrote are moved there (migration).
    Map<String, int>? raceTimes;
    final races = Vdot.ofRaces(a);
    final synthetic = a.vdotEstimate == null ? _syntheticRaceTime() : null;
    if (synthetic != null) {
      raceTimes = {...a.raceTimes}..remove(synthetic.$1);
    }
    final estimate = newVdot ?? synthetic?.$2;
    final athlete = <String, dynamic>{
      if (estimate != null) ...{
        'vdotEstimate': estimate,
        'vdotEstimateAt': newVdot != null ? now : _add(today, -minVdotStepDays),
        'vdotEstimateBase': raceTimes != null ? (Vdot.ofRaces(a.merge({'raceTimes': raceTimes})) ?? 0) : (races ?? 0),
      },
      if (newFtp != null) 'ftp': newFtp,
      // Swim test times that give the new CSS ((t400 − t200) / 2), for the profile.
      if (newCss != null) ...{'swim200Sec': 2 * newCss - 4, 'swim400Sec': 4 * newCss - 4},
    };
    // When the FTP / CSS stepped, and from which value (the cap's base for this plan).
    if (newFtp != null) athlete.addAll({'ftpStepAt': now, 'ftpBase': ftpBase});
    if (newCss != null) athlete.addAll({'cssStepAt': now, 'cssBase': cssBase});
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
        goalTargetSec: goalTargetSec,
        goalForecastSec: goalForecastSec,
        sessionsDue: fitness.recentDue,
        sessionsDone: fitness.recentDone,
        keysDue: fitness.keyDue,
        keysDone: fitness.keyDone,
        taperDone: taperDone,
      ),
      changes: changes,
      raceTimes: raceTimes,
      feasibility: feasibility,
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

  /// [PlanGenerator.feasibility] from today with the actual longest run (30 days) and weekly run
  /// volume (21 days), when it finds a timing issue (too short, long day too short, run/walk by race
  /// day, swim) the plan start's check did not – null otherwise.
  PlanFeasibility? _feasibilityNow() {
    if (!dayOnly(a.eventDate!).isAfter(today)) return null;
    final runs = sessions.where((s) => s.sport == Sport.run && !s.start.isAfter(now));
    // (The longest run stated at the plan start counts while it lies within the 30 days – as in R1, [_startReference].)
    final ps = _planStart();
    final stated = ps != null && !ps.isAfter(today) && daysBetween(ps, today) <= 30 ? (a.longestRunKm ?? 0) : 0.0;
    final longest = runs.where((s) => daysBetween(s.start, today) <= 30).fold(stated, (x, s) => max(x, s.distanceM / 1000));
    // Weekly volume: the last 3 weeks' average, not below 80 % of the stated one (a single short
    // week is no new baseline).
    final weekly = max(
      runs.where((s) => daysBetween(s.start, today) <= 21).fold(0.0, (x, s) => x + s.distanceM / 1000) / 3,
      0.8 * (a.runWeeklyKm ?? 0),
    );
    if (longest <= 0) return null;
    final actual = profile.copyWith(athlete: a.merge({'longestRunKm': double.parse(longest.toStringAsFixed(1)), 'runWeeklyKm': weekly}));
    final f = PlanGenerator.feasibility(actual, start: today, l: l);
    const timing = {'tooShort', 'longRunTime', 'runWalk'};
    final fresh = f.issues.where(timing.contains).toList();
    if (fresh.isEmpty) return null;
    DateTime? start = a.planStart;
    if (start == null) {
      final phased = plans.where((p) => p.phase != null).map((p) => dayOnly(p.date));
      if (phased.isNotEmpty) start = phased.reduce((x, y) => x.isBefore(y) ? x : y);
    }
    final before = start == null ? const <String>[] : PlanGenerator.feasibility(profile, start: start, l: l).issues;
    return fresh.any((i) => !before.contains(i)) ? f : null;
  }

  /// Highest training-derived FTP rise over a plan (share of the FTP before its first step): Allen &
  /// Coggan (Training and Racing with a Power Meter) – trained cyclists gain ~5–10 % FTP over a
  /// season's build, newcomers more. +3 % steps every ≥ 3 weeks reach it in ~2 months.
  static double maxFtpRise(UserProfile p) => p.level == 'beginner' ? 0.10 : 0.08;

  /// Highest training-derived CSS gain over a plan (share of the CSS before its first step, ~4 s / 100 m
  /// at 1:45): trained swimmers improve their CSS by a few per cent over a season.
  static const maxCssGain = 0.04;

  /// "A little more volume" (rule 4) at most this often per plan, never in consecutive weeks.
  static const maxVolumeRaises = 3;

  /// Done / planned volume of the taper above which it is "overdone" ([RecalReason.taperOverdo]).
  static const taperOverdoShare = 1.10;

  /// Plan start: stored on the profile, else the first workout with a phase.
  DateTime? _planStart() {
    if (a.planStart != null) return dayOnly(a.planStart!);
    final phased = plans.where((p) => p.phase != null).map((p) => dayOnly(p.date));
    return phased.isEmpty ? null : phased.reduce((x, y) => x.isBefore(y) ? x : y);
  }

  /// Weeks (Mondays) of this plan in which rule 4 raised the volume (a 'recal' record above the original).
  Set<DateTime> _volumeRaiseWeeks() {
    final start = _planStart();
    return {
      for (final p in plans)
        if (p.auto?.reason == 'recal' && _amount(p) > _origAmount(p) * 1.02 && (start == null || !dayOnly(p.date).isBefore(start)))
          startOfWeek(p.date),
    };
  }

  /// "sport|weekday" of a workout – its slot in the training week.
  static String _slot(PlannedWorkout p) => '${p.sport.name}|${p.date.weekday}';

  /// The next 7 days are (mostly) taper / race week: ≥ half of the planned endurance workouts are in
  /// the taper phase or the race.
  bool _inTaper() {
    final next = plans.where(
      (p) => p.sport != Sport.gym && p.status != 'skipped' && !dayOnly(p.date).isBefore(today) && dayOnly(p.date).isBefore(_add(today, 7)),
    );
    if (next.isEmpty) return false;
    return next.where((p) => p.phase == 'taper' || p.intensity == 'race').length * 2 >= next.length;
  }

  /// Done / planned volume of the taper workouts due in the last 7 days (distance, else time; missed
  /// and skipped = 0), or null without any.
  double? _taperDone(Map<String, Session> linked) {
    var planned = 0.0, done = 0.0;
    for (final p in plans) {
      final d = dayOnly(p.date);
      if (p.phase != 'taper' || p.sport == Sport.gym || p.intensity == 'race' || p.durationMin <= 0) continue;
      if (d.isBefore(_add(today, -7)) || !d.isBefore(today)) continue;
      planned += p.durationMin;
      if (p.status == 'skipped') continue;
      final s = linked[p.id];
      done += s != null ? p.durationMin * (complianceRatio(p, s, profile: profile) ?? 1) : (p.isDone ? p.durationMin.toDouble() : 0);
    }
    return planned > 0 ? done / planned : null;
  }

  /// Days between two training-derived VDOT steps (rule 7, C5).
  static const minVdotStepDays = 21;

  /// A race time an older version of the recalibration wrote for a VDOT step (key = the event
  /// distance or 10 km, the exact time of a one-decimal VDOT) next to the athlete's own race
  /// times – (key, VDOT), or null. A time the athlete entered matches by chance only rarely.
  (String, double)? _syntheticRaceTime() {
    final key = a.eventDistance != null && Vdot.distances.containsKey(a.eventDistance) ? a.eventDistance! : '10k';
    final t = a.raceTimes[key];
    if (t == null || a.raceTimes.length < 2) return null;
    final v = double.parse(Vdot.fromRace(Vdot.distances[key]!, t).toStringAsFixed(1));
    return Vdot.raceTime(v, Vdot.distances[key]!) == t ? (key, v) : null;
  }

  /// New VDOT from running best efforts of the last 90 days (5 km and longer), or null.
  double? _newVdot(double current) {
    final recent = sessions.where((s) => now.difference(s.start).inDays <= 90).toList(); // time span
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

  /// Quality runs with T / I targets (set for the current VDOT – [CardioTrend] gets only those)
  /// that were ≥ 3 % faster than planned without feeling harder than intended.
  static int _fasterAtEffort(CardioTrend run) =>
      run.feedback
          .where(
            (f) =>
                f.isQuality &&
                f.aboveTarget &&
                (f.internalScore ?? 0) < SessionFeedback.threshold &&
                f.plan.steps.any((s) => s.isWork && (s.zone == 'T' || s.zone == 'I') && s.paceMin != null),
          )
          .length;

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
    final from = addDays(today, -lookbackDays);
    for (final sport in {for (final p in plans) p.sport}) {
      if (sport == Sport.gym) continue;
      final due = window.where((p) => p.sport == sport && p.durationMin > 0 && p.intensity != 'race').toList();
      if (due.length < 2) continue;
      // A plan that just started is no return from a break: its first due workout must lie
      // ≥ [minHistoryDays] back (the generator already starts from the stated volume).
      final first = due.map((p) => dayOnly(p.date)).reduce((x, y) => x.isBefore(y) ? x : y);
      if (daysBetween(first, today) < minHistoryDays) continue;
      final mine = sessions.where((x) => x.sport == sport && !x.start.isAfter(now)).toList();
      if (mine.isEmpty) continue;
      final last = mine.map((x) => x.start).reduce((x, y) => x.isAfter(y) ? x : y);
      final gap = daysBetween(dayOnly(last), today);
      if (gap >= 10) {
        out[sport] = gap;
      } else if (due.length >= 3 &&
          mine.any((x) => x.start.isBefore(from)) &&
          (weeklyCompletion(due, linked, now: now, profile: profile) ?? 1) < 0.15) {
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

  /// Part of a recovery week the recalibration proposed (reason 'recal…Recovery', C4).
  static bool _recoveryMark(PlannedWorkout p) {
    final r = p.auto?.reason ?? '';
    return r.startsWith('recal') && r.endsWith('Recovery');
  }

  /// Reduced by the AutoAdjuster in the last 7 days.
  bool _autoReducedRecently(PlannedWorkout p) {
    final o = p.auto;
    return o != null && !o.reason.startsWith('recal') && now.difference(o.at).inDays < 7 && _amount(p) < _origAmount(p) - 0.01; // time span
  }

  /// Record of a recalibration volume change: keeps the generator's original (undo, and
  /// the reference of later steps).
  AutoAdjustment _record(PlannedWorkout p, {bool fresh = false, String reason = 'recal'}) {
    final o = fresh ? null : p.auto;
    return AutoAdjustment(
      sessionId: '',
      reason: (o?.reason ?? '').startsWith('recalEasy') ? 'recalEasy' : reason,
      at: now,
      durationMin: o?.durationMin ?? p.durationMin,
      distanceKm: o == null ? p.distanceKm : o.distanceKm,
      steps: o?.steps ?? p.steps,
    );
  }

  /// R1 cap of the [k]-th long session (0-based) of its sport in the horizon, in the unit of
  /// [_amount], or null without any history of that sport.
  ///
  /// Run/walk sessions compare by time (their km include the walking). When the previous planned
  /// long session (≤ 14 days ago) was done at ≥ 90 %, the generator's own progression is the
  /// reference (C2): the achieved long session × the plan's step to [p] (its goal-directed build
  /// grows the long run/walk +10 min a week, the long run up to +25 %) – the 30-day rule cut a
  /// beginner's planned 12 km to 7.3 km every Monday although every session was done.
  double? _longCap(PlannedWorkout p, int k, Map<String, Session> linked) {
    final rw = isRunWalk(p);
    double unitOf(Session s) {
      // Sessions without a distance (treadmill without a foot pod) count by time, in
      // the plan's unit (its own km per minute).
      final byTime = s.durationSec / 60 * (_amount(p) / max(1, p.durationMin));
      return !rw && _byKm(p) && s.distanceM > 0 ? s.distanceM / 1000 : byTime;
    }

    double? longest(int fromDays, int toDays) {
      final day = dayOnly(p.date);
      var best = 0.0;
      for (final s in sessions) {
        if (s.sport != p.sport || s.start.isAfter(now)) continue;
        final ago = daysBetween(dayOnly(s.start), day);
        if (ago < fromDays || ago > toDays) continue;
        best = max(best, unitOf(s));
      }
      return best > 0 ? best : null;
    }

    // What the athlete brought into the plan counts as done on its first day (review 2026-11 adapt-3 / UX-2: the
    // first logged 5 km run cut a marathoner's 14 km long run to 5.5 km): the plan's first long session of the
    // sport – built from the stated history under R1 – and, for runs, the stated longest run, while the plan
    // start lies within the 30 days.
    final recent = _max(longest(1, 30), _startReference(p, rw));
    double? cap;
    if (recent != null) {
      cap = recent * pow(1.1, k + 1);
    } else {
      final before = longest(31, 120);
      cap = before == null ? null : before * 0.6 * pow(1.1, k);
    }
    // The generator's reference: every long session of the last 30 days was done as planned
    // (≥ 90 %, none skipped) – then the plan's own growth from the longest of them to [p] holds.
    final recentLongs =
        plans
            .where(
              (x) =>
                  x.sport == p.sport &&
                  x.intensity == 'long' &&
                  x.id != p.id &&
                  dayOnly(x.date).isBefore(today) &&
                  daysBetween(x.date, p.date) <= 30,
            )
            .toList();
    if (cap != null && recentLongs.isNotEmpty) {
      final byTime = rw || recentLongs.any((x) => isRunWalk(x) || !_byKm(x));
      double orig(PlannedWorkout x) => byTime ? (x.auto?.durationMin ?? x.durationMin).toDouble() : _origAmount(x);
      var allDone = true;
      var doneMax = 0.0, origMax = 0.0;
      for (final x in recentLongs) {
        final s = linked[x.id];
        final planned = byTime ? x.durationMin.toDouble() : (x.distanceKm ?? 0);
        final done = s == null ? 0.0 : (byTime || s.distanceM <= 0 ? s.durationSec / 60 : s.distanceM / 1000);
        if (s == null || planned <= 0 || done < 0.9 * planned) {
          allDone = false;
          break;
        }
        doneMax = max(doneMax, done);
        origMax = max(origMax, orig(x));
      }
      if (allDone && origMax > 0) {
        final mine = doneMax * orig(p) / origMax; // minutes (by time) or km
        cap = max(cap, byTime ? mine / max(1, p.durationMin) * _amount(p) : mine);
      }
    }
    return cap;
  }

  /// R1 reference the plan start stands for ([_longCap]), in [p]'s unit (by time for run/walk [rw]): the original
  /// amount of the plan's first long session of [p]'s sport (in its first week) and, for runs by distance, the stated longest run
  /// ([AthleteData.longestRunKm]) – null when the plan started more than 30 days before [p].
  double? _startReference(PlannedWorkout p, bool rw) {
    final start = _planStart();
    if (start == null || daysBetween(start, p.date) > 30 || dayOnly(p.date).isBefore(start)) return null;
    // Only until the plan's first long session of the sport was due: from then on its outcome is the evidence (done
    // as planned: the plan's own progression, C2; cut short or missed: the runs actually done).
    if (plans.any(
      (x) =>
          x.sport == p.sport &&
          x.intensity == 'long' &&
          x.id != p.id &&
          !dayOnly(x.date).isBefore(start) &&
          dayOnly(x.date).isBefore(today),
    )) {
      return null;
    }
    final first =
        (plans.where((x) => x.sport == p.sport && x.intensity == 'long' && x.phase != null && !dayOnly(x.date).isBefore(start)).toList()
              ..sort((x, y) => x.date.compareTo(y.date)))
            .firstOrNull;
    double? ref;
    // (Only the plan's first week's long session is the one built from the athlete's history; later ones are the
    // plan's progression.)
    if (first != null && daysBetween(start, first.date) < 7) {
      final byTime = rw || isRunWalk(first) || !_byKm(p);
      // In [p]'s unit: by time through [p]'s own km per minute (run/walk), else the first session's amount.
      final minutes = (first.auto?.durationMin ?? first.durationMin).toDouble();
      ref = byTime ? (_byKm(p) ? minutes * _amount(p) / max(1, p.durationMin) : minutes) : _origAmount(first);
    }
    final stated = a.longestRunKm;
    if (p.sport == Sport.run && !rw && _byKm(p) && stated != null && stated > 0) ref = max(ref ?? 0, stated);
    return ref != null && ref > 0 ? ref : null;
  }

  static double? _max(double? x, double? y) => x == null ? y : (y == null ? x : max(x, y));

  /// A long session the AutoAdjuster capped in the last 14 days after a long run was cut short at a
  /// high effort ("longCutShort": achieved + 10 %): that is the evidence-based cap – the
  /// recalibration does not lower it again (C3: the cap kept ratcheting below the last cut).
  /// Time caps of the long sessions by sport ([PlanGenerator.longSessionCapMin]; 0: none), looked up once.
  final _longCapMin = <Sport, int>{};

  bool _longCapped(PlannedWorkout p) {
    final o = p.auto;
    return o != null && o.reason == 'longCutShort' && daysBetween(o.at, now) <= 14;
  }

  /// Smallest run a reduction leaves, in [p]'s [_amount] unit: 25 min and 4 km for runners above
  /// beginner level, 20 min for beginners (run/walk by its time); 0 for other sports. A planned
  /// session already below it is never raised by it.
  static double runFloor(PlannedWorkout p, UserProfile profile) {
    if (p.sport != Sport.run || p.durationMin <= 0) return 0;
    final beginner = profile.level == 'beginner' || isRunWalk(p);
    final minutes = beginner ? 20.0 : 25.0;
    if (!_byKm(p)) return minutes;
    final kmPerMin = p.distanceKm! / p.durationMin;
    return max(minutes * kmPerMin, beginner ? 0.0 : 4.0);
  }

  /// Run/walk stage held (I13, §1.10 Couch-to-5K: move up only at RPE ≤ 5 without pain): with
  /// ≥ 2 run/walk sessions of the last 3 weeks too hard or cut short ([progressionCheck]), every
  /// upcoming run/walk session of the horizon gets the content of the run/walk session of the same
  /// kind a week before it (the struggled-with stage is repeated, the ladder shifts by a week).
  Map<String, PlannedWorkout> _repeatStage(List<PlannedWorkout> upcoming) {
    final check = progressionCheck(profile, plans: plans, sessions: sessions, now: now);
    if (check == null || !check.issues.contains(ProgressionIssue.runWalkNotAchieved)) return const {};
    int runSec(PlannedWorkout x) => x.steps.where((s) => s.isWork && s.zone != 'walk').fold(0, (t, s) => t + (s.durationSec ?? 0));
    int repSec(PlannedWorkout x) => x.steps.where((s) => s.isWork && s.zone != 'walk').fold(0, (t, s) => max(t, s.durationSec ?? 0));
    final out = <String, PlannedWorkout>{};
    for (final p in upcoming.where(isRunWalk)) {
      final d = dayOnly(p.date);
      final before =
          plans
              .where((x) => x.id != p.id && isRunWalk(x) && x.intensity == p.intensity && x.status != 'skipped')
              .where((x) => daysBetween(x.date, d) >= 5 && daysBetween(x.date, d) <= 9)
              .toList()
            ..sort((x, y) => (daysBetween(x.date, d) - 7).abs().compareTo((daysBetween(y.date, d) - 7).abs()));
      if (before.isEmpty) continue;
      final prev = before.first;
      // Only a step up is held back (the taper's shorter sessions stay).
      if (repSec(prev) >= repSec(p) && runSec(prev) >= runSec(p)) continue;
      if (p.phase == 'taper') continue;
      out[p.id] = _copy(
        p,
        title: prev.title,
        description: prev.description,
        steps: prev.steps,
        durationMin: prev.durationMin,
        distanceKm: prev.distanceKm,
        auto: _record(p, reason: 'recalStage'),
      );
    }
    return out;
  }

  /// I14: the next long run (of the next 7 days) moves to another planned day of its week that has
  /// an easy run of the same sport and more time on it ([PlanGenerator.dayMinutesFor]) – the two
  /// swap days. Only when ≥ 2 of the last 3 weeks' long runs were missed while the rest was done.
  /// Long-run id / easy-run id → new day.
  Map<String, DateTime> _moveLong(List<PlannedWorkout> upcoming, Map<String, Session> linked) {
    final from = _add(today, -21);
    final missed =
        plans
            .where(
              (x) => x.intensity == 'long' && x.sport == Sport.run && !dayOnly(x.date).isBefore(from) && dayOnly(x.date).isBefore(today),
            )
            .where((x) => !adaptationCompleted(x, linked, profile: profile))
            .length;
    if (missed < 2) return const {};
    final long = upcoming.where((p) => p.intensity == 'long' && p.sport == Sport.run && daysBetween(today, p.date) < 7).firstOrNull;
    if (long == null) return const {};
    final week = startOfWeek(long.date);
    bool hardNear(DateTime d) =>
        plans.any((x) => x.id != long.id && x.status != 'skipped' && isHardPlan(x) && daysBetween(d, x.date).abs() == 1);
    PlannedWorkout? best;
    var bestMin = PlanGenerator.dayMinutesFor(profile, long.date.weekday);
    for (final e in upcoming) {
      if (e.sport != Sport.run || e.intensity != 'easy' || startOfWeek(e.date) != week || sameDay(e.date, long.date)) continue;
      if (dayOnly(e.date).isBefore(today) || hardNear(dayOnly(e.date))) continue;
      final m = PlanGenerator.dayMinutesFor(profile, e.date.weekday);
      if (m >= min(long.durationMin, bestMin) && (best == null || m > bestMin)) {
        best = e;
        bestMin = m;
      }
    }
    if (best == null) return const {};
    return {long.id: dayOnly(best.date), best.id: dayOnly(long.date)};
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
    return retitledRepeats(w, decimal: l.localeName.startsWith('de') ? ',' : '.');
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

  /// Quality session [p] with ~[qf] of its ORIGINAL work ([AutoAdjustment] record, else [p] itself): with ≥ 3 repeats
  /// whole repeats (and their recoveries) are dropped, rep length and pace kept; fewer repeats (2 × 2.4 km, one
  /// continuous tempo) get shorter work steps (100 m / whole minutes). Warm-up and cool-down stay. Duration and
  /// distance follow the steps; the title's "N × length" follows them too ([retitledRepeats]). Null when nothing
  /// changes against [p] (already reduced so) or [p] has no work steps.
  PlannedWorkout? _fewerRepeats(PlannedWorkout p, double qf) {
    final o = p.auto;
    final orig = o != null && o.steps.isNotEmpty ? o.steps : p.steps;
    final dur0 = o != null && o.steps.isNotEmpty ? o.durationMin : p.durationMin;
    final km0 = o != null && o.steps.isNotEmpty ? o.distanceKm : p.distanceKm;
    // (The main set only: a swim's drill block before its CSS repeats stays.)
    final work = mainSetIndices(orig);
    if (work.isEmpty) return null;
    final keep = (work.length * qf).round();
    final List<WorkoutStep> steps;
    if (work.length >= 3 && keep >= 1 && keep < work.length) {
      steps = [...orig.sublist(0, work[keep - 1] + 1), ...orig.sublist(work.last + 1)];
    } else {
      final set = work.toSet();
      WorkoutStep shorter(int i) {
        final x = orig[i];
        if (!set.contains(i)) return x;
        final d = x.durationSec, m = x.distanceM;
        return _step(
          x,
          durationSec: d == null ? null : (d >= 120 ? max(60, (d * qf / 60).round() * 60) : max(10, (d * qf / 10).round() * 10)),
          distanceM: m == null ? null : max(100.0, (m * qf / 100).round() * 100.0),
        );
      }

      steps = [for (var i = 0; i < orig.length; i++) shorter(i)];
    }
    // The targets stay the current ones (a VDOT / FTP / CSS step since the original updated [p]'s paces / power):
    // aligned from the start (warm-up, kept repeats) and from the end (cool-down).
    final cur = p.steps;
    for (var i = 0; i < steps.length; i++) {
      final j = i < cur.length && cur[i].kind == steps[i].kind && cur[i].zone == steps[i].zone ? i : cur.length - (steps.length - i);
      if (j < 0 || j >= cur.length || cur[j].kind != steps[i].kind || cur[j].zone != steps[i].zone) continue;
      steps[i] = _step(steps[i], paceMin: cur[j].paceMin, paceMax: cur[j].paceMax, powerMin: cur[j].powerMin, powerMax: cur[j].powerMax);
    }
    final before = estimateStepsSec(orig, p.sport, profile), after = estimateStepsSec(steps, p.sport, profile);
    final g = before <= 0 ? qf : after / before;
    final out = retitledRepeats(
      _copy(
        p,
        steps: steps,
        durationMin: max(15, (dur0 * g / 5).round() * 5),
        distanceKm: km0 == null ? null : double.parse((km0 * g).toStringAsFixed(1)),
      ),
      decimal: l.localeName.startsWith('de') ? ',' : '.',
    );
    final same =
        out.durationMin == p.durationMin &&
        out.distanceKm == p.distanceKm &&
        out.steps.length == p.steps.length &&
        [
          for (var i = 0; i < out.steps.length; i++)
            out.steps[i].durationSec == p.steps[i].durationSec && out.steps[i].distanceM == p.steps[i].distanceM,
        ].every((x) => x);
    return same ? null : out;
  }

  /// [_toEasy] with the current thresholds – also used by "Not feeling 100 %?" (readiness.dart).
  /// Endurance sports only.
  PlannedWorkout toEasy(PlannedWorkout p) => _toEasy(p, null);

  /// Quality session → easy session of the same sport, ~80 % of the time.
  PlannedWorkout _toEasy(PlannedWorkout p, PaceZones? newPz) {
    var minutes = max(20, (p.durationMin * swapFactor / 5).round() * 5);
    // Runs keep the run floor ([runFloor]: non-beginners 25 min / 4 km) – a 30 min interval session became a
    // 3.8 km easy run.
    if (p.sport == Sport.run && profile.level != 'beginner' && !isRunWalk(p)) minutes = max(minutes, min(25, p.durationMin));
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
        final km0 = double.parse((minutes * 60 / ((fast + slow) / 2)).toStringAsFixed(1));
        final km = profile.level == 'beginner' || isRunWalk(p) ? km0 : max(km0, min(4.0, p.distanceKm ?? 4.0));
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
  /// Race-pace steps (zone M at a goal pace other than the old VDOT's marathon pace – HM / 10 km /
  /// 5 km goal-pace sets, marathon target pace) keep the goal: a VDOT step doesn't move the race goal.
  PlannedWorkout? _withPaces(PlannedWorkout p, PaceZones pz, PaceZones old) {
    var changed = false;
    final (oldFast, oldSlow) = old.range('M');
    bool racePace(WorkoutStep s) => s.zone == 'M' && ((s.paceMin! + s.paceMax!) / 2 - (oldFast + oldSlow) / 2).abs() > 2;
    final steps = [
      for (final s in p.steps)
        if (s.paceMin != null && s.paceMax != null && s.zone != 'walk' && !racePace(s))
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
  }) => p.copyWith(
    date: date,
    title: title,
    description: description,
    durationMin: durationMin,
    distanceKm: distanceKm,
    intensity: intensity,
    status: status,
    steps: steps,
    isKey: isKey,
    auto: auto,
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

  /// Two weeks harder than intended in a row: one recovery week (C4, §11.4).
  fatigueRecovery,

  /// Still too hard after the recovery week: check sleep / illness / stress, consider a slower
  /// target; quality stays at reduced repeats.
  fatigueCheck,

  /// The goal forecast says "at risk" ([GoalForecast.atRisk] – the one verdict, IMPORTANT 2); the
  /// options come from [PlanGenerator.feasibility] re-run on the actual long run / weekly volume.
  goalAtRisk,

  /// Run/walk stage held: the coming week repeats the current stage (C25K: progress only at
  /// RPE ≤ 5).
  repeatStage,

  /// Long runs missed on their day while the other runs were done: the next one moves to a day
  /// with more time instead of cutting easy runs.
  moveLong,

  /// < 70 % of the sessions of the last 4 weeks done (chronic skipping, IMPORTANT 4).
  sessionsSkipped,

  /// < 75 % of the key sessions of the last 4 weeks done.
  keySessionsMissed,

  /// Quality felt easy again, but the volume was raised last week (or [Recalibrator.maxVolumeRaises]
  /// times this plan): it stays this week.
  rpeLowSpaced,

  /// Taper / race week: the reduced volume is deliberate – no extra cuts or additions.
  taper,

  /// Taper overdone: clearly more than the taper planned was trained ([RecalStats.taperDone]).
  taperOverdo,
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
  ///
  /// Fields [PlannedWorkout.toMap] leaves out when they are at their default (isKey false, no
  /// steps / phase / auto record) are written explicitly when [after] dropped them – a key session
  /// turned easy would otherwise keep `isKey: true` in Firestore and still count as key.
  Map<String, dynamic> get update {
    final b = before.toMap(), a = after.toMap();
    return {
      for (final k in a.keys)
        if (!_eq(a[k], b[k])) k: a[k],
      for (final k in b.keys)
        if (!a.containsKey(k) && _defaults.containsKey(k)) k: _defaults[k],
    };
  }

  static const _defaults = <String, Object?>{'isKey': false, 'steps': <Object>[], 'phase': null, 'auto': null};

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
    this.goalTargetSec,
    this.goalForecastSec,
    this.sessionsDue = 0,
    this.sessionsDone = 0,
    this.keysDue = 0,
    this.keysDone = 0,
    this.taperDone,
  });

  /// Done / planned volume of the taper workouts of the last 7 days (null without any).
  final double? taperDone;

  /// Refilled sessions proposed (gaps in the plan).
  final int gaps;

  /// Goal at risk from the target time alone: the target and the forecast's race-day time.
  final int? goalTargetSec, goalForecastSec;

  /// Due / done sessions and key sessions of the last 4 weeks.
  final int sessionsDue, sessionsDone, keysDue, keysDone;

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
  const Recalibration({
    required this.reasons,
    required this.stats,
    required this.changes,
    this.raceTimes,
    this.athlete = const {},
    this.feasibility,
  });
  final List<RecalReason> reasons;
  final RecalStats stats;
  final List<RecalChange> changes;

  /// New race times for the profile, or null: only when a race time an older version synthesized
  /// for a VDOT step is removed (the VDOT goes to [AthleteData.vdotEstimate] via [athlete]).
  final Map<String, int>? raceTimes;

  /// Threshold updates for the profile ([AthleteData.merge] keys: vdotEstimate*, ftp, swim times).
  final Map<String, dynamic> athlete;

  /// The race goal's feasibility re-checked on the actual training ([RecalReason.goalAtRisk]): later
  /// date / shorter distance options for the sheet. Null when nothing new.
  final PlanFeasibility? feasibility;

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
    feasibility: feasibility,
  );
}
