import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/insights.dart';

/// Explains the week streak: current streak, this week's progress, the last weeks.
Future<void> showStreakSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => const _StreakSheet());
}

class _StreakSheet extends ConsumerWidget {
  const _StreakSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stats = ref.watch(gameStatsProvider);
    final target = ref.watch(profileOrDefaultProvider).weeklyTarget;
    final hist = GameStats.weekHistory(ref.watch(sessionListProvider), target, plans: ref.watch(planListProvider), weeks: 8);
    final now = hist.last;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat.Md(context.localeName);
    final left = (now.goal - now.done).clamp(0, 99);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 38,
                    color: stats.weekStreak > 0 ? AppColors.danger : scheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.streakWeeks(stats.weekStreak), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(l.weekStreakTooltip, style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l.streakThisWeek, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < now.goal; i++)
                  Expanded(
                    child: Container(
                      height: 10,
                      margin: EdgeInsets.only(right: i == now.goal - 1 ? 0 : 4),
                      decoration: BoxDecoration(
                        color: i < now.done ? AppColors.danger : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(now.met ? l.streakWeekDone(now.done, now.goal) : l.streakWeekLeft(now.done, now.goal, left), style: t.bodySmall),
            const SizedBox(height: 20),
            Text(l.streakLastWeeks, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final w in hist)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: w.met ? AppColors.danger : (identical(w, now) ? null : scheme.surfaceContainerHighest),
                            border: identical(w, now) && !w.met ? Border.all(color: AppColors.danger, width: 1.5) : null,
                          ),
                          child:
                              w.met
                                  ? const Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white)
                                  : Center(
                                    child: Text('${w.done}/${w.goal}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(df.format(w.week), style: t.labelSmall?.copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: scheme.outline),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.streakHow, style: t.bodySmall?.copyWith(height: 1.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
