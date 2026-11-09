import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/plan_adjuster.dart';
import '../../widgets/common.dart';

/// Home banner when planned workouts of the last days were missed: proposes how to fit
/// the key sessions into the rest of the week (see [proposeWeekAdjustment]).
/// "Not now" hides it until the next day.
class AdjustWeekBanner extends ConsumerStatefulWidget {
  const AdjustWeekBanner({super.key});
  @override
  ConsumerState<AdjustWeekBanner> createState() => _AdjustWeekBannerState();
}

class _AdjustWeekBannerState extends ConsumerState<AdjustWeekBanner> {
  static const _key = 'adjustWeekDismissed';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plans = ref.watch(planListProvider);
    final now = DateTime.now();
    final prefs = ref.read(prefsProvider);
    if (prefs.getString(_key) == dayKey(now)) return const SizedBox.shrink();
    final changes = proposeWeekAdjustment(plans, now);
    if (changes.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(changes),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.event_repeat_rounded, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(child: Text(l.adjustWeekBanner(changes.length), style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: l.notNow,
                  icon: Icon(Icons.close_rounded, color: c.onSurfaceVariant),
                  onPressed: () => setState(() => prefs.setString(_key, dayKey(now))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(List<PlanChange> changes) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AdjustSheet(changes: changes),
    );
    if (ok != true || !mounted) return;
    ref.read(repoProvider)?.updateMany(plans: planChangeUpdates(changes));
    toast(context, context.l10n.adjustDone);
  }
}

class _AdjustSheet extends StatelessWidget {
  const _AdjustSheet({required this.changes});
  final List<PlanChange> changes;

  String _why(AppLocalizations l, PlanChange ch) {
    if (ch.isMove) return ch.replaces == null ? '' : l.adjustReplaces(ch.replaces!.title);
    if (ch.plan.phase == 'recovery' || ch.plan.phase == 'taper') return l.adjustProtected;
    return isHardPlan(ch.plan) ? l.adjustNoRoom : l.adjustDropped;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final day = DateFormat.E(context.localeName);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.adjustWeekTitle, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l.adjustWeekIntro, style: t.bodySmall),
            const SizedBox(height: 12),
            for (final ch in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(ch.plan.sport.icon, color: ch.plan.sport.color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.isMove
                                ? '${ch.plan.title}: ${day.format(ch.plan.date)} → ${day.format(ch.to!)}'
                                : '${ch.plan.title} (${day.format(ch.plan.date)})',
                            style: TextStyle(fontWeight: FontWeight.w600, decoration: ch.isMove ? null : TextDecoration.lineThrough),
                          ),
                          if (_why(l, ch).isNotEmpty) Text(_why(l, ch), style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.apply))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
