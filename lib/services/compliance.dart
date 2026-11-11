import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/sport.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';

/// The one plan-compliance scale of the app (TrainingPeaks-style traffic light). Every place
/// that judges "how much of the plan was done" – calendar markers and legend, the session's
/// plan card, Home, the week page, the summary headline, the plan adaptation and the stats –
/// uses these bands via [complianceLevelOf] / [complianceRatio] / [planCompleted].
///
/// | share of the plan | level | counts as done |
/// |---|---|---|
/// | 80–120 % | green "wie geplant" | yes |
/// | 50–79 % or 121–150 % | yellow "teilweise" | yes |
/// | 10–49 % or > 150 % | orange "stark abweichend" | yes |
/// | < 10 % | red "nicht gewertet" | no – an aborted start (e.g. 0:29 of 56 min) gives no training stimulus |
///
/// The share is distance for distance-based endurance plans, done work sets for gym, else duration.
abstract final class ComplianceScale {
  static const greenMin = 0.8;
  static const greenMax = 1.2;
  static const yellowMin = 0.5;
  static const yellowMax = 1.5;

  /// Below this share a linked session does not count as done.
  static const countMin = 0.1;
}

/// Plan adherence of one planned workout.
enum ComplianceLevel {
  /// Future, today-but-not-yet-done, or skipped on purpose.
  none,

  /// 80–120 % of the plan.
  green,

  /// 50–80 % or 120–150 %.
  yellow,

  /// 10–50 % or above 150 %.
  orange,

  /// Day passed without the workout, or a session of less than 10 % of the plan (not counted).
  red,
}

class Compliance {
  final ComplianceLevel level;

  /// actual / planned ([complianceRatio]); null when unknown.
  final double? ratio;
  const Compliance(this.level, [this.ratio]);

  static const none = Compliance(ComplianceLevel.none);
  static const missed = Compliance(ComplianceLevel.red);

  int? get pct => ratio == null ? null : (ratio! * 100).round();

  /// A session is linked, but it was too little to count (< [ComplianceScale.countMin]).
  bool get notCounted => level == ComplianceLevel.red && ratio != null;

  /// Done, but not "as planned" (yellow / orange) – "teilweise erledigt (40 %)".
  bool get partly => (level == ComplianceLevel.yellow || level == ComplianceLevel.orange) && ratio != null;

  Color color(BuildContext context) => switch (level) {
    ComplianceLevel.green => AppColors.success,
    ComplianceLevel.yellow => complianceYellow,
    ComplianceLevel.orange => complianceOrange,
    ComplianceLevel.red => AppColors.danger,
    ComplianceLevel.none => Theme.of(context).colorScheme.outline,
  };

  IconData get icon => switch (level) {
    ComplianceLevel.green || ComplianceLevel.yellow || ComplianceLevel.orange => Icons.check_rounded,
    ComplianceLevel.red => Icons.close_rounded,
    ComplianceLevel.none => Icons.circle_outlined,
  };

  /// Screen-reader text.
  String label(AppLocalizations l, {bool skipped = false}) {
    final p = pct;
    return switch (level) {
      ComplianceLevel.green => p == null ? l.complianceDone : l.complianceGreen(p),
      ComplianceLevel.yellow => l.complianceYellow(p ?? 0),
      ComplianceLevel.orange => l.complianceOrange(p ?? 0),
      ComplianceLevel.red => p == null ? l.complianceMissed : l.complianceNotCounted(p),
      ComplianceLevel.none => skipped ? l.complianceSkipped : l.compliancePlanned,
    };
  }
}

const complianceYellow = Color(0xFFFFD43B);
const complianceOrange = Color(0xFFFF8C1A);

ComplianceLevel complianceLevelOf(double ratio) {
  if (ratio < ComplianceScale.countMin) return ComplianceLevel.red;
  if (ratio >= ComplianceScale.greenMin && ratio <= ComplianceScale.greenMax) return ComplianceLevel.green;
  if (ratio >= ComplianceScale.yellowMin && ratio <= ComplianceScale.yellowMax) return ComplianceLevel.yellow;
  return ComplianceLevel.orange;
}

/// Work sets a gym session is compared with: the sets the workout had when it was finished
/// ([Session.plannedSets]), else the work sets of the planned workout's own exercises. 0 when
/// unknown or when the session has no set data (imported / summary-only entry) – then the
/// duration is compared.
int plannedGymSets(PlannedWorkout p, Session s) {
  if (!s.exercises.any((e) => e.exId != 'manual')) return 0;
  final own = s.plannedSets ?? 0;
  if (own > 0) return own;
  return p.exercises.fold<int>(0, (a, e) => a + e.workSets.length);
}

/// Planned distance (km) of [p]: its distance, or for a swim the sum of its steps' metres.
double plannedKm(PlannedWorkout p) {
  final km = p.distanceKm ?? 0;
  if (km > 0) return km;
  if (p.sport == Sport.swim) return p.steps.fold<double>(0, (a, s) => a + (s.distanceM ?? 0)) / 1000;
  return 0;
}

/// actual / planned: done work sets for gym ([plannedGymSets]), distance when the plan is
/// distance-based (and the session has a distance), otherwise duration. Null when the plan
/// has no target.
double? complianceRatio(PlannedWorkout p, Session s) {
  if (p.sport == Sport.gym && s.sport == Sport.gym) {
    final sets = plannedGymSets(p, s);
    if (sets > 0) return s.setsDone / sets;
  }
  final km = plannedKm(p);
  if (km > 0 && s.distanceM > 0) return s.distanceM / (km * 1000);
  if (p.durationMin > 0) return s.durationSec / (p.durationMin * 60);
  return null;
}

/// Whether linked session [s] fulfils [p] at all (≥ [ComplianceScale.countMin] of the plan).
bool sessionCounts(PlannedWorkout p, Session s) => (complianceRatio(p, s) ?? 1) >= ComplianceScale.countMin;

/// Compliance of [p] given its linked session [s] (if any). [now] is injectable for tests.
Compliance planCompliance(PlannedWorkout p, Session? s, {DateTime? now}) {
  if (p.status == 'skipped') return Compliance.none;
  if (s != null) {
    final r = complianceRatio(p, s);
    return r == null ? const Compliance(ComplianceLevel.green) : Compliance(complianceLevelOf(r), r);
  }
  // Marked done without recorded data → counts as completed.
  if (p.isDone) return const Compliance(ComplianceLevel.green);
  final today = dayOnly(now ?? DateTime.now());
  return dayOnly(p.date).isBefore(today) ? Compliance.missed : Compliance.none;
}

/// Plan id → linked session (via [PlannedWorkout.sessionId] or [Session.planId]). Of several
/// sessions started from the same workout (an aborted start, then the real one), the one that
/// fulfils more of the plan wins.
Map<String, Session> linkPlanSessions(List<PlannedWorkout> plans, List<Session> sessions) {
  final byId = {for (final s in sessions) s.id: s};
  final planById = {for (final p in plans) p.id: p};
  final out = <String, Session>{};
  for (final s in sessions) {
    // A session started from a workout days away only fulfils it once confirmed (the plan
    // then points back at it via sessionId) – see plan_match.replacementCandidate.
    final p = s.planId == null ? null : planById[s.planId];
    if (p != null && (p.sessionId == s.id || daysBetween(p.date, s.start).abs() <= 1)) {
      final cur = out[p.id];
      if (cur == null || (complianceRatio(p, s) ?? 1) > (complianceRatio(p, cur) ?? 1)) out[p.id] = s;
    }
  }
  for (final p in plans) {
    final s = p.sessionId == null ? null : byId[p.sessionId];
    if (s == null) continue;
    final cur = out[p.id];
    // The explicit link wins – unless it is a start too short to count and another session
    // from the same workout does count.
    if (cur == null || cur.id == s.id || sessionCounts(p, s) || !sessionCounts(p, cur)) out[p.id] = s;
  }
  return out;
}

/// Share (0…1) of the planned minutes that were completed, weighted by planned minutes.
/// Each workout contributes at most its planned minutes (over-delivery doesn't hide a miss).
/// Only workouts that are already due count – past days, plus anything done early – so
/// Monday morning doesn't read "0 %". Skipped and missed workouts count as 0, and so does a
/// session too short to count ([sessionCounts]).
/// Null when nothing with a duration is due yet.
double? weeklyCompletion(List<PlannedWorkout> plans, Map<String, Session> linked, {DateTime? now}) {
  final today = dayOnly(now ?? DateTime.now());
  var planned = 0.0, done = 0.0;
  for (final p in plans) {
    final min = p.durationMin.toDouble();
    if (min <= 0) continue;
    final s = linked[p.id];
    final completed = planCompleted(p, linked);
    if (!completed && !dayOnly(p.date).isBefore(today)) continue; // not due yet
    planned += min;
    if (!completed) continue;
    if (s != null) {
      final r = complianceRatio(p, s) ?? 1;
      done += min * r.clamp(0.0, 1.0);
    } else {
      done += min;
    }
  }
  return planned == 0 ? null : done / planned;
}

/// Whether [p] counts as completed: not skipped, and a linked session that counts
/// ([sessionCounts]) or marked done without one.
bool planCompleted(PlannedWorkout p, Map<String, Session> linked) {
  if (p.status == 'skipped') return false;
  final s = linked[p.id];
  return s != null ? sessionCounts(p, s) : p.isDone;
}

/// One definition of "x of y workouts done" for every count of a week (total, per sport, Home
/// and week page): planned workouts that were not dropped, and how many are completed.
({int done, int planned}) planCounts(Iterable<PlannedWorkout> plans, Map<String, Session> linked) {
  final counted = plans.where((p) => p.status != 'skipped').toList();
  return (done: counted.where((p) => planCompleted(p, linked)).length, planned: counted.length);
}

/// Sessions that fulfil none of [plans] (extra training), shown as "+1 extra" next to the counts.
int extraSessions(Iterable<Session> sessions, Iterable<PlannedWorkout> plans, Map<String, Session> linked) {
  final used = {
    for (final p in plans)
      if (linked[p.id] case final s?) s.id,
  };
  return sessions.where((s) => !used.contains(s.id)).length;
}

/// Colour of a weekly completion share (same bands as one workout).
Color completionColor(double share) =>
    share >= ComplianceScale.greenMin
        ? AppColors.success
        : share >= ComplianceScale.yellowMin
        ? complianceYellow
        : complianceOrange;

/// Small coloured ring showing [compliance] (replaces the plain check mark).
class ComplianceRing extends StatelessWidget {
  const ComplianceRing({super.key, required this.compliance, this.skipped = false, this.size = 22});
  final Compliance compliance;
  final bool skipped;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = compliance;
    final color = c.color(context);
    final filled = c.level != ComplianceLevel.none;
    return Semantics(
      label: c.label(context.l10n, skipped: skipped),
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withValues(alpha: 0.18) : null,
          border: Border.all(color: color, width: filled ? 2.2 : 1.5),
        ),
        child:
            filled ? Icon(c.icon, size: size * 0.6, color: color) : (skipped ? Icon(Icons.remove, size: size * 0.6, color: color) : null),
      ),
    );
  }
}
