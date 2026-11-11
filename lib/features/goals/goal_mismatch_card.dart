import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/goal_alignment.dart';
import '../onboarding/onboarding_page.dart';

/// How the next race goal fits the focus and the plan (null without a race goal).
final goalAlignmentProvider = Provider<GoalAlignment?>(
  (ref) => GoalAlignment.of(
    ref.watch(profileOrDefaultProvider),
    ref.watch(goalsProvider).value ?? const [],
    ref.watch(planListProvider),
    ref.watch(todayProvider),
  ),
);

/// Opens the plan settings prefilled with the race goal (focus of the race, its date and
/// distance); finishing them replaces the upcoming plan after the usual confirmation.
void openAlignPlan(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan)));

/// "Dein Ziel Hamburg Triathlon passt nicht zu deinem Fokus Hybrid – Fokus auf Triathlon
/// ändern und Plan anpassen?" [Anpassen] [Später] – on Home, in Ziele and in "Plan neu
/// aufsetzen". [snoozable]: "Später" hides it (Home) until the mismatch changes.
class GoalMismatchCard extends ConsumerStatefulWidget {
  const GoalMismatchCard({super.key, this.snoozable = false, this.padding = const EdgeInsets.only(bottom: 12), this.onAdjust});
  final bool snoozable;
  final EdgeInsets padding;

  /// Replaces the default (open the plan settings), e.g. to close a sheet first.
  final VoidCallback? onAdjust;

  static const prefsKey = 'goalMismatchLater';

  @override
  ConsumerState<GoalMismatchCard> createState() => _GoalMismatchCardState();
}

class _GoalMismatchCardState extends ConsumerState<GoalMismatchCard> {
  String? _snoozed;

  @override
  void initState() {
    super.initState();
    if (widget.snoozable) {
      try {
        _snoozed = ref.read(prefsProvider).getString(GoalMismatchCard.prefsKey);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(goalAlignmentProvider);
    if (m == null || !m.mismatch || (widget.snoozable && _snoozed == m.signature)) return const SizedBox.shrink();
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final body = [
      m.focusWrong ? l.mismatchFocusBody(m.goal.title, m.focus.label(l), m.neededFocus.label(l)) : l.mismatchPlanBody(m.goal.title),
      if (m.missingSports.isNotEmpty && (m.planAligned || m.focusWrong)) l.mismatchMissing(m.missingSports.map((s) => s.label(l)).join(', ')),
    ].join(' ');
    return Padding(
      padding: widget.padding,
      child: Container(
        key: const ValueKey('goalMismatch'),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_problem_rounded, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(l.mismatchTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 6),
            Text(body, key: const ValueKey('goalMismatchBody'), style: t.bodyMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.snoozable)
                  TextButton(
                    key: const ValueKey('goalMismatchLater'),
                    onPressed: () {
                      setState(() => _snoozed = m.signature);
                      try {
                        ref.read(prefsProvider).setString(GoalMismatchCard.prefsKey, m.signature);
                      } catch (_) {}
                    },
                    child: Text(l.later),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  key: const ValueKey('goalMismatchAdjust'),
                  onPressed: widget.onAdjust ?? () => openAlignPlan(context),
                  child: Text(l.mismatchAdjust),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
