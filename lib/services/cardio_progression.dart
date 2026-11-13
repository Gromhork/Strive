import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'health_limits.dart';
import 'plan_recalibrate.dart' show Recalibrator;
import 'progression_check.dart';
import 'session_feedback.dart';
import 'zones.dart';

/// Small automatic plan adjustments right after a completed (linked) endurance session
/// ("auto small" – larger changes stay a proposal of the Recalibrator, which the athlete
/// previews). docs/training-science.md §12. Pure – no Firestore writes, no UI.
///
/// Rules (only the next 1–2 planned workouts of the same sport; never races, strength,
/// done / skipped or past workouts):
/// * **Long session cut short** (< 80 %) and not easier than intended → the next long
///   session is capped at what was achieved + 10 % (the one after at + 20 %, i.e. +10 %
///   a week back to the plan) – never above the plan.
/// * **Long session harder than intended** (complete) → the next long one does not grow:
///   held at this session's volume.
/// * **Easy session harder than intended** (HR / RPE / pace too fast) → the next easy
///   session of that sport −10 %, with the hint to slow down (Seiler 80/20).
/// * **Quality session harder than intended or cut short** → the next quality session of
///   that sport is not increased (held at this one's volume).
/// * **Quality session easier than intended**, complete, targets hit → +5 % on the next
///   quality session – only in loading weeks (base / build / peak), not with a heart /
///   impact limitation, and only while the sport's week stays ≤ 110 % of its 4-week average
///   (10 % rule, acute:chronic caution).
///
/// Bounds: one step −15 … +5 %; all automatic steps together stay within −15 … +10 % of
/// the workout's original volume (also when the Recalibrator changed it before – its record
/// keeps the generator's original; a workout it already cut by more than 15 % is not cut
/// again). Heart rate is judged against [HrMax.of] (measured, else the highest HR of hard
/// sessions, else predicted – then with half weight and, on easy days, only with a second
/// signal). Taper / recovery weeks never get more volume. Each
/// changed workout keeps an [AutoAdjustment] with its original values (undo).
class AutoAdjuster {
  AutoAdjuster(this.profile, {required this.plans, required this.sessions, required this.now});

  final UserProfile profile;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;
  final DateTime now;

  static const maxCut = 0.85, maxGain = 1.10, bump = 1.05;

  /// Changes after [s] completed [done]. Empty when nothing needs to change, or when [s]
  /// already triggered adjustments (idempotent).
  List<AutoChange> afterSession(Session s, PlannedWorkout done) {
    if (done.sport == Sport.gym || !done.sport.isCardio || done.intensity == 'race') return const [];
    if (plans.any((p) => p.auto?.sessionId == s.id)) return const [];
    final f = evaluateSession(done, s, profile, hrMax: HrMax.of(profile, sessions: sessions, now: now));
    final hf = HealthFlags.of(profile);
    final day = dayOnly(s.start).isAfter(dayOnly(now)) ? dayOnly(s.start) : dayOnly(now);
    final next =
        plans
            .where(
              (p) =>
                  p.id != done.id &&
                  p.status == 'planned' &&
                  p.sport == done.sport &&
                  p.intensity != 'race' &&
                  dayOnly(p.date).isAfter(dayOnly(s.start)) &&
                  !dayOnly(p.date).isBefore(day) &&
                  daysBetween(day, dayOnly(p.date)) < 14,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    bool isQuality(PlannedWorkout p) => p.intensity == 'tempo' || p.intensity == 'intervals';
    bool isEasy(PlannedWorkout p) => p.intensity == 'easy' || p.intensity == 'technique';
    final out = <AutoChange>[];
    void add(PlannedWorkout p, double factor, String reason) {
      final c = _change(p, factor, reason, s.id);
      if (c != null) out.add(c);
    }

    // Cut short at a high (or unknown) effort: the planned volume was not sustainable.
    // Cut short at the intended effort or easier is more likely lack of time – no change.
    final hardStop = f.cutShort && (f.effort == SessionEffort.harder || !f.rated);
    if (done.intensity == 'long') {
      final longs = next.where((p) => p.intensity == 'long').take(2).toList();
      if (hardStop) {
        // Hold at what was achieved + 10 % (+ 20 % for the one after), never above the plan.
        for (var i = 0; i < longs.length; i++) {
          final p = longs[i];
          final achieved = _achieved(p, s);
          if (achieved == null) continue;
          final k = achieved * (1.1 + 0.1 * i) / _amount(p);
          if (k < 1) add(p, k, 'longCutShort');
        }
      } else if (f.clearlyHarder && longs.isNotEmpty) {
        final p = longs.first;
        final mine = _comparable(done, p);
        if (mine != null && _amount(p) > mine) add(p, max(0.9, mine / _amount(p)), 'longHard');
      }
    } else if (isEasy(done)) {
      if (f.clearlyHarder || (f.cutShort && f.effort == SessionEffort.harder)) {
        final p = next.where(isEasy).where((p) => daysBetween(day, dayOnly(p.date)) < 7).firstOrNull;
        final fast = f.signals.any((x) => x.kind == SignalKind.pace && x.score >= 0.3);
        if (p != null) add(p, 0.9, fast ? 'easyTooFast' : 'easyHard');
      }
    } else if (isQuality(done)) {
      final p = next.where(isQuality).firstOrNull;
      if (p != null) {
        if (f.clearlyHarder || hardStop) {
          final mine = _comparable(done, p);
          if (mine != null && _amount(p) > mine) add(p, max(0.9, mine / _amount(p)), 'qualityHard');
        } else if (f.clearlyEasier && (f.completion ?? 1) >= 0.95 && !f.belowTarget && _mayGrow(p, done, hf)) {
          add(p, bump, 'qualityEasy');
        }
      }
    }
    return out.take(2).toList();
  }

  /// Runs and swims are measured in distance; rides in time (their planned km are only an
  /// estimate at ~27 km/h).
  static bool _byKm(PlannedWorkout p) => p.sport != Sport.ride && (p.distanceKm ?? 0) > 0;

  /// Volume measure of a plan: km for distance-based plans, else minutes.
  static double _amount(PlannedWorkout p) => _byKm(p) ? p.distanceKm! : p.durationMin.toDouble();

  /// What [s] achieved in the unit of [target]'s volume, or null.
  static double? _achieved(PlannedWorkout target, Session s) {
    if (_byKm(target)) return s.distanceM > 0 ? s.distanceM / 1000 : null;
    return s.durationSec > 0 ? s.durationSec / 60 : null;
  }

  /// [done]'s planned volume in [target]'s unit.
  static double? _comparable(PlannedWorkout done, PlannedWorkout target) {
    if (_byKm(target)) return (done.distanceKm ?? 0) > 0 ? done.distanceKm : null;
    return done.durationMin > 0 ? done.durationMin.toDouble() : null;
  }

  bool _mayGrow(PlannedWorkout p, PlannedWorkout done, HealthFlags hf) {
    const loading = {'base', 'build', 'peak'};
    if (!loading.contains(p.phase ?? 'base') || !loading.contains(done.phase ?? 'base')) return false;
    if (hf.capIntensity || (p.sport == Sport.run && hf.lowImpactRun)) return false;
    // A race within the next 10 days: freshness first.
    if (plans.any((r) => r.intensity == 'race' && !r.date.isBefore(p.date) && daysBetween(p.date, r.date) <= 10)) return false;
    // 10 % rule: the sport's planned minutes in the target's week (with the bump) ≤ 110 %
    // of the weekly average of the last 4 weeks (needs ≥ 3 sessions as a base).
    final from = now.subtract(const Duration(days: 28)); // time span
    final recent = sessions.where((x) => x.sport == p.sport && x.start.isAfter(from) && !x.start.isAfter(now)).toList();
    if (recent.length < 3) return false;
    final chronic = recent.fold(0, (x, v) => x + v.minutes) / 4;
    final monday = addDays(dayOnly(p.date), -(p.date.weekday - 1));
    final week =
        plans
            .where((x) => x.sport == p.sport && x.status != 'skipped' && !dayOnly(x.date).isBefore(monday))
            .where((x) => dayOnly(x.date).isBefore(addDays(monday, 7)))
            .fold(0, (x, v) => x + v.durationMin) +
        p.durationMin * (bump - 1);
    return week <= chronic * 1.1;
  }

  /// [p] scaled by [factor] within the bounds, or null when the change is negligible.
  AutoChange? _change(PlannedWorkout p, double factor, String reason, String sessionId) {
    final orig = p.auto;
    final origAmount =
        orig == null ? _amount(p) : (_byKm(p) && (orig.distanceKm ?? 0) > 0 ? orig.distanceKm! : orig.durationMin.toDouble());
    final rest = p.phase == 'taper' || p.phase == 'recovery';
    // A session of a recovery week the recalibration proposed (C4) is cut already: not again.
    if (factor < 1 && orig != null && orig.reason.startsWith('recal') && orig.reason.endsWith('Recovery')) return null;
    var f = factor.clamp(maxCut, bump);
    if (rest) f = min(f, 1.0);
    // All automatic steps together: −15 … +10 % of the original. A step never turns into
    // its opposite: a workout the Recalibrator already cut below −15 % is not cut further
    // (and not raised by the bound either).
    final cur = _amount(p);
    final lo = maxCut * origAmount / cur, hi = maxGain * origAmount / cur;
    f = f < 1 ? (lo >= 1 ? 1.0 : max(f, lo)) : (hi <= 1 ? 1.0 : min(f, hi));
    // Never below the run floor (25 min / 4 km, beginners 20 min – [Recalibrator.runFloor]).
    if (f < 1) f = max(f, min(cur, Recalibrator.runFloor(p, profile)) / cur);
    if ((f - 1).abs() < 0.02) return null;
    final after = scaleWorkout(p, f, profile);
    if (after.durationMin == p.durationMin && after.distanceKm == p.distanceKm) return null;
    final record = AutoAdjustment(
      sessionId: sessionId,
      reason: reason,
      at: now,
      durationMin: orig?.durationMin ?? p.durationMin,
      distanceKm: orig == null ? p.distanceKm : orig.distanceKm,
      steps: orig?.steps ?? p.steps,
    );
    return AutoChange(p, _copy(after, auto: record), reason);
  }

  /// [p] with its continuous / work parts × [f]; duration and distance follow the steps.
  static PlannedWorkout scaleWorkout(PlannedWorkout p, double f, UserProfile profile) {
    final runWalk = isRunWalk(p);
    WorkoutStep s(WorkoutStep x) {
      if (x.kind != 'steady' && x.kind != 'work') return x;
      int? sec;
      if (x.durationSec != null) {
        // Run/walk: whole minutes, so the "N × M min" title still fits.
        final unit = x.durationSec! >= 600 || runWalk ? 60 : 15;
        sec = max(unit, (x.durationSec! * f / unit).round() * unit);
      }
      double? m;
      if (x.distanceM != null) {
        final unit = p.sport == Sport.swim ? 25.0 : (x.distanceM! >= 2000 ? 100.0 : 50.0);
        m = max(unit, (x.distanceM! * f / unit).round() * unit);
      }
      return WorkoutStep(
        kind: x.kind,
        durationSec: sec,
        distanceM: m,
        zone: x.zone,
        paceMin: x.paceMin,
        paceMax: x.paceMax,
        powerMin: x.powerMin,
        powerMax: x.powerMax,
        hrMin: x.hrMin,
        hrMax: x.hrMax,
        note: x.note,
      );
    }

    final steps = _repeatsScaled(p.steps, f, p.sport, profile) ?? [for (final x in p.steps) s(x)];
    final before = estimateStepsSec(p.steps, p.sport, profile), after = estimateStepsSec(steps, p.sport, profile);
    final g = p.steps.isEmpty || before <= 0 ? f : after / before;
    double? km;
    if (p.distanceKm != null) {
      final d0 = p.steps.fold(0.0, (x, v) => x + (v.distanceM ?? 0)), d1 = steps.fold(0.0, (x, v) => x + (v.distanceM ?? 0));
      final allDistance = p.steps.isNotEmpty && p.steps.every((v) => v.distanceM != null);
      km = double.parse((p.distanceKm! * (allDistance && d0 > 0 ? d1 / d0 : g)).toStringAsFixed(1));
    }
    return retitledRunWalk(_copy(p, steps: steps, durationMin: max(10, (p.durationMin * g).round()), distanceKm: km));
  }

  /// Interval sets (≥ 3 identical work steps in one block) change by whole repeats – a
  /// 100 m swim repeat or a 1 km interval keeps its length and intensity (Bosquet 2007:
  /// adjust volume, keep intensity). Null when the set can't get closer to [f] that way.
  static List<WorkoutStep>? _repeatsScaled(List<WorkoutStep> steps, double f, Sport sport, UserProfile profile) {
    final work = [
      for (var i = 0; i < steps.length; i++)
        if (steps[i].kind == 'work') i,
    ];
    if (work.length < 3) return null;
    final w0 = steps[work.first];
    if (work.any((i) => steps[i].zone != w0.zone || steps[i].durationSec != w0.durationSec || steps[i].distanceM != w0.distanceM)) {
      return null;
    }
    for (var i = work.first; i <= work.last; i++) {
      if (steps[i].kind != 'work' && steps[i].kind != 'recovery') return null;
    }
    final reps = work.length, target = max(2, (reps * f).round());
    if (target == reps) return null;
    final rec = steps[work.first + 1].kind == 'recovery' ? steps[work.first + 1] : null;
    final out = [
      ...steps.take(work.first),
      for (var i = 0; i < target; i++) ...[w0, if (rec != null && i < target - 1) rec],
      ...steps.skip(work.last + 1),
    ];
    final g = estimateStepsSec(out, sport, profile) / max(1, estimateStepsSec(steps, sport, profile));
    // Run/walk (walk warm-up): always whole repeats – a 45 s "minute" under a "12 × 1 min" title
    // matches neither the C25K stage nor the title (I13).
    final runWalk = sport == Sport.run && steps.first.zone == 'walk';
    if (!runWalk && ((g - f).abs() > 0.06 || (f < 1) != (g < 1))) return null;
    return out;
  }

  static PlannedWorkout _copy(PlannedWorkout p, {List<WorkoutStep>? steps, int? durationMin, double? distanceKm, AutoAdjustment? auto}) =>
      PlannedWorkout(
        id: p.id,
        date: p.date,
        sport: p.sport,
        title: p.title,
        description: p.description,
        durationMin: durationMin ?? p.durationMin,
        distanceKm: distanceKm ?? p.distanceKm,
        intensity: p.intensity,
        templateId: p.templateId,
        status: p.status,
        sessionId: p.sessionId,
        steps: steps ?? p.steps,
        phase: p.phase,
        isKey: p.isKey,
        exercises: p.exercises,
        gymMods: p.gymMods,
        auto: auto ?? p.auto,
      );

  /// Firestore update that restores the original values of an adjusted workout.
  static Map<String, dynamic> undoUpdate(PlannedWorkout p) {
    final a = p.auto;
    if (a == null) return const {};
    return {
      'durationMin': a.durationMin,
      'distanceKm': a.distanceKm,
      'steps': a.steps.map((e) => e.toMap()).toList(),
      'auto': FieldValue.delete(),
    };
  }

  /// [p] as it was before the automatic adjustment (for previews and tests).
  static PlannedWorkout undone(PlannedWorkout p) {
    final a = p.auto;
    if (a == null) return p;
    return PlannedWorkout.fromMap(p.id, {...p.toMap(), ...undoUpdate(p)..remove('auto')}..remove('auto'));
  }
}

class AutoChange {
  const AutoChange(this.before, this.after, this.reason);
  final PlannedWorkout before;
  final PlannedWorkout after;

  /// See [AutoAdjustment.reason].
  final String reason;

  /// Firestore update: the changed volume fields plus the [AutoAdjustment] record.
  Map<String, dynamic> get update => {
    'durationMin': after.durationMin,
    'distanceKm': after.distanceKm,
    'steps': after.steps.map((e) => e.toMap()).toList(),
    'auto': after.auto!.toMap(),
  };
}
