import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

/// Name of an event distance key.
String eventDistanceName(AppLocalizations l, String d) => switch (d) {
  '5k' => '5 km',
  '10k' => '10 km',
  'hm' => l.halfMarathon,
  'm' => l.marathon,
  'sprint' => 'Sprint-Triathlon',
  'olympic' => l.olympicTri,
  '70.3' => l.middleDistance,
  _ => d,
};

/// Short warning when the event goal is not realistic in the time left, with what would
/// make it work (later date, shorter distance, run/walk). Nothing when the goal is fine.
class FeasibilityCard extends StatelessWidget {
  const FeasibilityCard(this.f, {super.key, this.planAnyway = false, this.onClose});
  final PlanFeasibility f;

  /// Adds "the plan is created anyway" (where a plan is about to be generated).
  final bool planAnyway;
  final VoidCallback? onClose;

  static String issueText(AppLocalizations l, PlanFeasibility f, String issue) => switch (issue) {
    'beginnerMarathon' => l.feasBeginnerMarathon,
    'runWalkLong' => l.feasRunWalkLong,
    'runWalk' => l.feasRunWalk,
    'longRunTime' => l.feasLongRunTime((f.longRunKm ?? 0).floor(), (f.longRunTargetKm ?? 0).round()),
    'longRideTime' => l.feasLongRideTime(f.longRideMin ?? 0, f.longRideTargetMin ?? 0),
    _ => l.feasTooShort(f.weeks ?? 0),
  };

  @override
  Widget build(BuildContext context) {
    if (f.ok) return const SizedBox.shrink();
    final l = context.l10n;
    final small = Theme.of(context).textTheme.bodySmall;
    final options = [
      if (f.laterDate != null) l.feasLaterDate(DateFormat.yMMMd(context.localeName).format(f.laterDate!)),
      if (f.shorterDistance != null) l.feasShorter(eventDistanceName(l, f.shorterDistance!)),
      if (f.runWalkFinish) l.feasRunWalkFinish,
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
                Text(l.feasTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                for (final i in f.issues) Text(issueText(l, f, i), style: const TextStyle(fontSize: 13)),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.feasOptions, style: small?.copyWith(fontWeight: FontWeight.w600)),
                  for (final o in options) Text('• $o', style: const TextStyle(fontSize: 13)),
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
