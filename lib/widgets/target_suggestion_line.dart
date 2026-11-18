import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../services/target_suggestion.dart';

/// Directly under a target-time field: "Realistisch: 1:39:00 (1:35:00–1:44:00)" with where it
/// comes from ("aus deinen Bestzeiten") and one tap to take it over.
class TargetSuggestionLine extends StatelessWidget {
  const TargetSuggestionLine({
    super.key,
    required this.profile,
    required this.eventKey,
    required this.eventDate,
    required this.sessions,
    required this.current,
    required this.onApply,
    this.plans,
    this.onClear,
  });

  /// Removes the target (offered when the finish-only plan sets it aside).

  final UserProfile profile;
  final String eventKey;
  final DateTime eventDate;
  final List<Session> sessions;
  final int? current;
  final ValueChanged<int> onApply;
  final VoidCallback? onClear;

  /// The plan that runs (mid-plan the suggestion starts from its fitness – the goal forecast's model).
  final List<PlannedWorkout>? plans;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sug = suggestTargetTime(profile, eventKey, eventDate, sessions: sessions, plans: plans, target: current);
    final t = Theme.of(context).textTheme;
    // A finish goal next to an entered target says what the plan does with it – never "no target time" under the
    // time just entered (final QA: "Ziel: ankommen – noch keine Zielzeit" under 3:27).
    final setAside = sug.targetRaced == false;
    final basis = switch (sug.basis) {
      TargetBasis.raceTimes => l.targetSuggestBasisRace,
      TargetBasis.bestEfforts => l.targetSuggestBasisEfforts,
      TargetBasis.levelEstimate => l.targetSuggestBasisLevel,
      TargetBasis.finishOnly when sug.targetRaced == true => l.targetSuggestFinishKept(clock(current!)),
      TargetBasis.finishOnly when setAside => l.targetSuggestSetAside(clock(current!)),
      TargetBasis.finishOnly => l.targetSuggestFinish,
    };
    return Container(
      key: const ValueKey('targetSuggestion'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: AppColors.run.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.run),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (sug.sec != null)
                    TextSpan(
                      text: l.targetSuggestRange(clock(sug.sec!), clock(sug.fastSec ?? sug.sec!), clock(sug.slowSec ?? sug.sec!)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (sug.sec != null) const TextSpan(text: ' · '),
                  TextSpan(text: basis, style: t.bodySmall),
                ],
              ),
            ),
          ),
          if (sug.sec != null && current != sug.sec)
            TextButton(key: const ValueKey('takeSuggestion'), onPressed: () => onApply(sug.sec!), child: Text(l.apply)),
          if (setAside && onClear != null) TextButton(key: const ValueKey('clearTarget'), onPressed: onClear, child: Text(l.targetRemove)),
        ],
      ),
    );
  }
}
