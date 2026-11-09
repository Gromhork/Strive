import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';

/// Plan adherence of one planned workout (TrainingPeaks-style traffic light).
enum ComplianceLevel {
  /// Future, today-but-not-yet-done, or skipped on purpose.
  none,

  /// 80–120 % of the planned duration/distance.
  green,

  /// 50–80 % or 120–150 %.
  yellow,

  /// Below 50 % or above 150 %.
  orange,

  /// Day passed without the workout.
  red,
}

class Compliance {
  final ComplianceLevel level;

  /// actual / planned (duration, or distance for distance-based plans); null when unknown.
  final double? ratio;
  const Compliance(this.level, [this.ratio]);

  static const none = Compliance(ComplianceLevel.none);
  static const missed = Compliance(ComplianceLevel.red);

  int? get pct => ratio == null ? null : (ratio! * 100).round();

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
      ComplianceLevel.red => l.complianceMissed,
      ComplianceLevel.none => skipped ? l.complianceSkipped : l.compliancePlanned,
    };
  }
}

const complianceYellow = Color(0xFFFFD43B);
const complianceOrange = Color(0xFFFF8C1A);

ComplianceLevel complianceLevelOf(double ratio) {
  if (ratio >= 0.8 && ratio <= 1.2) return ComplianceLevel.green;
  if (ratio >= 0.5 && ratio <= 1.5) return ComplianceLevel.yellow;
  return ComplianceLevel.orange;
}

/// actual / planned: distance when the plan is distance-based (and the session has a
/// distance), otherwise duration. Null when the plan has no target.
double? complianceRatio(PlannedWorkout p, Session s) {
  final km = p.distanceKm ?? 0;
  if (km > 0 && s.distanceM > 0) return s.distanceM / (km * 1000);
  if (p.durationMin > 0) return s.durationSec / (p.durationMin * 60);
  return null;
}

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

/// Plan id → linked session (via [PlannedWorkout.sessionId] or [Session.planId]).
Map<String, Session> linkPlanSessions(List<PlannedWorkout> plans, List<Session> sessions) {
  final byId = {for (final s in sessions) s.id: s};
  final out = <String, Session>{};
  for (final s in sessions) {
    if (s.planId != null) out[s.planId!] = s;
  }
  for (final p in plans) {
    final s = p.sessionId == null ? null : byId[p.sessionId];
    if (s != null) out[p.id] = s;
  }
  return out;
}

/// Share (0…1) of the planned minutes that were completed, weighted by planned minutes.
/// Each workout contributes at most its planned minutes (over-delivery doesn't hide a miss).
/// Only workouts that are already due count – past days, plus anything done early – so
/// Monday morning doesn't read "0 %". Skipped and missed workouts count as 0.
/// Null when nothing with a duration is due yet.
double? weeklyCompletion(List<PlannedWorkout> plans, Map<String, Session> linked, {DateTime? now}) {
  final today = dayOnly(now ?? DateTime.now());
  var planned = 0.0, done = 0.0;
  for (final p in plans) {
    final min = p.durationMin.toDouble();
    if (min <= 0) continue;
    final s = linked[p.id];
    final completed = p.status != 'skipped' && (s != null || p.isDone);
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

/// Colour of a weekly completion share.
Color completionColor(double share) =>
    share >= 0.8
        ? AppColors.success
        : share >= 0.5
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
