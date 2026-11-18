import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/plan_log.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/plan_adjuster.dart';
import '../../widgets/common.dart';

const adjustWeekDismissedKey = 'adjustWeekDismissed';

/// Identity of a proposal: the missed workouts it is about. Closed ("Not now"), the banner stays away for these
/// workouts – also the next days and after a restart – and comes back when another one is missed (owner round 9:
/// it came back every day for the same workouts).
String adjustWeekSignature(List<PlanChange> changes) => ([for (final c in changes) c.plan.id]..sort()).join(',');

/// Whether [AdjustWeekBanner] shows: missed workouts to absorb and this set not dismissed.
bool adjustWeekBannerVisible(SharedPreferences prefs, List<PlannedWorkout> plans, DateTime now) {
  final changes = proposeWeekAdjustment(plans, now);
  return changes.isNotEmpty && prefs.getString(adjustWeekDismissedKey) != adjustWeekSignature(changes);
}

/// Before / after of every workout "adjust my week" changes (for the plan history).
List<(PlannedWorkout, PlannedWorkout)> weekChangeLog(List<PlanChange> changes) {
  PlannedWorkout edit(PlannedWorkout p, Map<String, dynamic> m) => PlannedWorkout.fromMap(p.id, {...p.toMap(), ...m});
  return [
    for (final c in changes) ...[
      (c.plan, edit(c.plan, c.isMove ? {'date': dayKey(c.to!)} : {'status': 'skipped'})),
      if (c.replaces != null) (c.replaces!, edit(c.replaces!, {'status': 'skipped'})),
    ],
  ];
}

/// Home banner when planned workouts of the last days were missed: proposes how to fit
/// the key sessions into the rest of the week (see [proposeWeekAdjustment]).
/// "Not now" hides it until the next day.
class AdjustWeekBanner extends ConsumerStatefulWidget {
  const AdjustWeekBanner({super.key});
  @override
  ConsumerState<AdjustWeekBanner> createState() => _AdjustWeekBannerState();
}

class _AdjustWeekBannerState extends ConsumerState<AdjustWeekBanner> {
  static const _key = adjustWeekDismissedKey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plans = ref.watch(planListProvider);
    final now = DateTime.now();
    final prefs = ref.read(prefsProvider);
    if (!adjustWeekBannerVisible(prefs, plans, now)) return const SizedBox.shrink();
    final changes = proposeWeekAdjustment(plans, now);
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
                  onPressed: () {
                    // (Not inside setState: its callback must not return the write's Future – in debug that threw and
                    // the banner stayed.)
                    prefs.setString(_key, adjustWeekSignature(changes));
                    setState(() {});
                  },
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
    final repo = ref.read(repoProvider);
    repo?.updateMany(plans: planChangeUpdates(changes));
    repo?.logPlanChange(PlanLogEntry.of('week', weekChangeLog(changes)));
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
