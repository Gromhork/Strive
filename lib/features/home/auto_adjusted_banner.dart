import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/cardio_progression.dart';
import '../calendar/auto_adjust.dart';
import '../calendar/plan_history_page.dart';
import 'adjust_week.dart';
import '../../widgets/nav.dart';

/// Prefs key of the automatic adjustments the athlete has already reviewed.
const autoAdjSeenKey = 'autoAdjSeen';

/// Id of one automatic adjustment (a later re-adjustment of the same workout is new).
String autoAdjSeenId(PlannedWorkout p) => '${p.id}@${p.auto!.at.millisecondsSinceEpoch}';

/// Automatic adjustments ([AutoAdjuster]) of the last 72 h on coming, not yet done workouts
/// that the athlete has not reviewed. Changes applied by "Plan überprüfen" (reason recal…)
/// were confirmed by the athlete and don't count.
List<PlannedWorkout> unseenAutoAdjustments(List<PlannedWorkout> plans, Set<String> seen, DateTime now) => [
  for (final p in plans)
    if (p.auto != null &&
        p.status == 'planned' &&
        !p.auto!.reason.startsWith('recal') &&
        now.difference(p.auto!.at) <= const Duration(hours: 72) &&
        !dayOnly(p.date).isBefore(dayOnly(now)) &&
        !seen.contains(autoAdjSeenId(p)))
      p,
];

/// Reviewed adjustment ids (device-local, SharedPreferences).
class AutoAdjSeen extends Notifier<Set<String>> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Set<String> build() => {...?ref.watch(prefsProvider).getStringList(autoAdjSeenKey)};

  void markSeen(Iterable<PlannedWorkout> plans) {
    final all = [
      ...state,
      for (final p in plans)
        if (p.auto != null) autoAdjSeenId(p),
    ];
    // Bounded: the newest 200 are plenty for a 72 h window.
    final keep = all.toSet().toList();
    state = keep.skip(keep.length > 200 ? keep.length - 200 : 0).toSet();
    _p.setStringList(autoAdjSeenKey, state.toList());
  }
}

final autoAdjSeenProvider = NotifierProvider<AutoAdjSeen, Set<String>>(AutoAdjSeen.new);

/// Compact Home banner "{n} workouts adapted automatically – review". Hidden while the
/// "adjust your week" banner shows (at most one plan banner at a time).
class AutoAdjustedBanner extends ConsumerWidget {
  const AutoAdjustedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(planListProvider);
    final now = DateTime.now();
    if (adjustWeekBannerVisible(ref.read(prefsProvider), plans, now)) return const SizedBox.shrink();
    final unseen = unseenAutoAdjustments(plans, ref.watch(autoAdjSeenProvider), now);
    if (unseen.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('autoAdjBanner'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => showAutoAdjustReview(context, [for (final p in unseen) p.id]),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: cs.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.autoAdjBanner(unseen.length), style: const TextStyle(fontWeight: FontWeight.w600))),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet: every adjusted workout before → after with its reason and undo; "OK" marks them reviewed.
Future<void> showAutoAdjustReview(BuildContext context, List<String> ids) =>
    showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => AutoAdjustReviewSheet(ids: ids));

class AutoAdjustReviewSheet extends ConsumerStatefulWidget {
  const AutoAdjustReviewSheet({super.key, required this.ids});
  final List<String> ids;

  @override
  ConsumerState<AutoAdjustReviewSheet> createState() => _AutoAdjustReviewSheetState();
}

class _AutoAdjustReviewSheetState extends ConsumerState<AutoAdjustReviewSheet> {
  /// Undone here (the stream may lag behind the local write).
  final _undone = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(profileOrDefaultProvider);
    final df = DateFormat.MMMEd(context.localeName);
    final plans = [
      for (final p in ref.watch(planListProvider))
        if (widget.ids.contains(p.id) && p.auto != null && !_undone.contains(p.id)) p,
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(l.autoAdjTitle, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.autoAdjSheetIntro, style: t.bodySmall),
            const SizedBox(height: 12),
            for (final p in plans)
              Container(
                key: ValueKey('autoAdjItem_${p.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(p.sport.icon, color: p.sport.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${p.title} · ${df.format(p.date)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${amountLabel(AutoAdjuster.undone(p), profile)} → ${amountLabel(p, profile)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(autoAdjustReason(l, p.auto!.reason), style: t.bodySmall?.copyWith(height: 1.3)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: ValueKey('autoAdjUndo_${p.id}'),
                        onPressed: () {
                          final repo = ref.read(repoProvider);
                          if (repo != null) undoAutoAdjust(repo, [p]);
                          setState(() => _undone.add(p.id));
                        },
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: Text(l.undo),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final nav = Navigator.of(context)..pop();
                      nav.push(pageRoute(const PlanHistoryPage()));
                    },
                    child: Text(l.planHistory, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('autoAdjOk'),
                    onPressed: () {
                      final all = ref.read(planListProvider).where((p) => widget.ids.contains(p.id) && p.auto != null);
                      ref.read(autoAdjSeenProvider.notifier).markSeen(all);
                      Navigator.pop(context);
                    },
                    child: Text(l.ok),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
