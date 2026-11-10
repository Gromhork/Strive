import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/event_distances.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/plan_generator.dart';

/// Feasibility of the event goal ([PlanGenerator.feasibility]), cached per profile and
/// plan start – the check generates a few plans, so it must not run on every rebuild.
class FeasibilityCache {
  String? _key;
  PlanFeasibility _value = const PlanFeasibility();

  PlanFeasibility of(UserProfile p, DateTime start, AppLocalizations l) {
    final key = '${p.toMap()}|${dayOnly(start)}|${l.localeName}';
    if (key != _key) {
      _key = key;
      _value = PlanGenerator.feasibility(p, start: start, l: l);
    }
    return _value;
  }
}

/// Name of an event distance key (the shared catalogue, [eventDistanceLabel]).
String eventDistanceName(AppLocalizations l, String d) => eventDistanceLabel(l, d);

/// "3 h 45" / "90 min" for a minute value.
String _hm(int m) => m < 60 || (m % 60 != 0 && m < 90) ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60}');

/// Short warning when the event goal is not realistic in the time left, with what would
/// make it work (later date, shorter distance, run/walk). Nothing when the goal is fine.
class FeasibilityCard extends StatelessWidget {
  const FeasibilityCard(this.f, {super.key, this.planAnyway = false, this.onClose, this.onAdjustTarget, this.showTargetOk = false});
  final PlanFeasibility f;

  /// One tap "set target to the realistic time" (shown with a target-time issue).
  final ValueChanged<int>? onAdjustTarget;

  /// Also confirm a realistic target time (a small line instead of nothing).
  final bool showTargetOk;

  /// Adds "the plan is created anyway" (where a plan is about to be generated).
  final bool planAnyway;
  final VoidCallback? onClose;

  static String issueText(AppLocalizations l, PlanFeasibility f, String issue) => switch (issue) {
    'beginnerMarathon' => l.feasBeginnerMarathon,
    'beginnerDistance' => l.feasBeginnerDistance,
    'longSwim' => l.feasLongSwim((f.longSwimM ?? 0).round(), (f.longSwimTargetM ?? 0).round()),
    'runWalkLong' => l.feasRunWalkLong,
    'runWalk' => l.feasRunWalk,
    'longRunTime' => l.feasLongRunTime((f.longRunKm ?? 0).floor(), (f.longRunTargetKm ?? 0).round()),
    'longRideTime' => l.feasLongRideTime(f.longRideMin ?? 0, f.longRideTargetMin ?? 0),
    'targetAmbitious' => l.feasTargetAmbitious(clock(f.target!.targetSec), clock(f.target!.currentSec), clock(f.target!.realisticSec)),
    'targetUnrealistic' => l.feasTargetUnrealistic(clock(f.target!.targetSec), clock(f.target!.currentSec), clock(f.target!.realisticSec)),
    _ => l.feasTooShort(f.weeks ?? 0),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = f.target;
    if (f.ok) {
      if (!showTargetOk || t == null) return const SizedBox.shrink();
      return Row(
        key: const ValueKey('targetOk'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.feasTargetOkLine(clock(t.targetSec), clock(t.currentSec), clock(t.realisticSec)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      );
    }
    final small = Theme.of(context).textTheme.bodySmall;
    final df = DateFormat.yMMMd(context.localeName);
    final targetIssue = f.issues.any((i) => i.startsWith('target')) && t != null;
    String day(int d) => DateFormat.EEEE(context.localeName).format(DateTime(2024, 1, d)); // 1 Jan 2024 = Monday
    final options = [
      // The time on the long day is the limit: the concrete fix first.
      if (f.raiseDay != null && f.raiseDayMin != null) l.feasRaiseDay(day(f.raiseDay!), _hm(f.raiseDayMin!)),
      if (f.moveDay != null && f.moveDayMin != null) l.feasMoveLongDay(day(f.moveDay!), _hm(f.moveDayMin!)),
      if (f.laterDate != null) l.feasLaterDate(df.format(f.laterDate!)),
      if (f.shorterDistance != null) l.feasShorter(eventDistanceName(l, f.shorterDistance!)),
      if (f.runWalkFinish) l.feasRunWalkFinish,
      if (targetIssue && onAdjustTarget == null) l.feasTargetSuggest(clock(t.suggestedSec)),
      if (targetIssue && t.laterDate != null) l.feasTargetLater(clock(t.targetSec), df.format(t.laterDate!)),
    ];
    return Container(
      key: const ValueKey('feasibility'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.onlyTarget ? l.feasTitleTarget : l.feasTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                for (final i in f.issues) Text(issueText(l, f, i), style: const TextStyle(fontSize: 13)),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.feasOptions, style: small?.copyWith(fontWeight: FontWeight.w600)),
                  for (final o in options) Text('• $o', style: const TextStyle(fontSize: 13)),
                ],
                if (targetIssue && t.guessed) ...[const SizedBox(height: 4), Text(l.feasEstimated, style: small)],
                if (targetIssue && onAdjustTarget != null) ...[
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    key: const ValueKey('adjustTarget'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => onAdjustTarget!(t.suggestedSec),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text(l.adjustTargetTo(clock(t.suggestedSec))),
                  ),
                ],
                if (planAnyway) ...[const SizedBox(height: 6), Text(l.feasPlanAnyway, style: small)],
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
