import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/plan_log.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'auto_adjust.dart';

/// Plan history entries, newest first.
final planLogProvider = StreamProvider<List<PlanLogEntry>>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? Stream.value(const []) : r.planLog();
});

/// "Not feeling 100 %" reason label.
String readinessLabel(AppLocalizations l, String kind) => switch (kind) {
  'sick' => l.notFitSick,
  'pain' => l.notFitPain,
  'tired' => l.notFitTired,
  'time' => l.notFitTime,
  _ => kind,
};

/// Undoes what can still be undone of [e] (see [planLogUndo]).
void undoPlanLog(WidgetRef ref, PlanLogEntry e) {
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  final u = planLogUndo(e, {for (final p in ref.read(planListProvider)) p.id: p});
  if (u.restore.isNotEmpty) repo.savePlans(u.restore);
  for (final id in u.delete) {
    repo.deletePlan(id);
  }
}

/// "Planverlauf": every plan change (automatic adjustments, "Plan überprüfen",
/// "Woche anpassen", "Nicht 100 % fit?") with date, reason, before → after and undo.
class PlanHistoryPage extends ConsumerWidget {
  const PlanHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final log = ref.watch(planLogProvider);
    final current = {for (final p in ref.watch(planListProvider)) p.id: p};
    // Changes of a replaced plan and accidental duplicates are left out.
    final entries = visiblePlanLog(log.value ?? const <PlanLogEntry>[], current);
    return Scaffold(
      appBar: AppBar(title: Text(l.planHistory)),
      body:
          log.isLoading && entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
              ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l.planHistoryEmpty, textAlign: TextAlign.center)))
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => PlanLogCard(entry: entries[i], current: current, onUndo: () => _undo(context, ref, entries[i])),
              ),
    );
  }

  void _undo(BuildContext context, WidgetRef ref, PlanLogEntry e) {
    undoPlanLog(ref, e);
    toast(context, context.l10n.planLogUndoDone);
  }
}

/// One entry: source, time, reason, the changed workouts and undo.
class PlanLogCard extends ConsumerWidget {
  const PlanLogCard({super.key, required this.entry, required this.current, required this.onUndo});
  final PlanLogEntry entry;
  final Map<String, PlannedWorkout> current;
  final VoidCallback onUndo;

  (IconData, Color, String) _style(AppLocalizations l) => switch (entry.source) {
    'auto' => (Icons.auto_fix_high_rounded, AppColors.brand, l.autoAdjTitle),
    'recal' => (Icons.fact_check_outlined, AppColors.success, l.planLogRecal),
    'week' => (Icons.event_repeat_rounded, AppColors.warning, l.adjustDone),
    'readiness' => (Icons.healing_rounded, AppColors.danger, l.planLogReadiness(readinessLabel(l, entry.reason))),
    _ => (Icons.edit_calendar_outlined, AppColors.brand, entry.source),
  };

  String _reason(AppLocalizations l) => switch (entry.source) {
    'auto' => autoAdjustReason(l, entry.reason),
    'week' => l.planLogWeekReason,
    _ => entry.note,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final (icon, color, title) = _style(l);
    final state = planLogState(entry, current);
    final reason = _reason(l);
    final when = DateFormat.MMMEd(context.localeName).add_Hm().format(entry.at);
    final profile = ref.watch(profileOrDefaultProvider);
    return Card(
      key: ValueKey('planLog_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(when, style: t.bodySmall),
              ],
            ),
            if (reason.isNotEmpty) ...[const SizedBox(height: 4), Text(reason, style: t.bodySmall?.copyWith(height: 1.3))],
            const SizedBox(height: 6),
            for (final i in entry.items) _ItemLine(item: i, profile: profile),
            Align(
              alignment: Alignment.centerRight,
              child: switch (state) {
                PlanLogState.undoable => TextButton.icon(
                  key: ValueKey('planLogUndo_${entry.id}'),
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(l.undo),
                ),
                PlanLogState.undone => Padding(padding: const EdgeInsets.all(8), child: Text(l.planLogUndone, style: t.bodySmall)),
                PlanLogState.changed => Padding(padding: const EdgeInsets.all(8), child: Text(l.planLogChanged, style: t.bodySmall)),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Long run · Sat 14 Nov: 9 km → 7.7 km" – what changed on one workout.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, required this.profile});
  final PlanLogItem item;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final df = DateFormat.MMMEd(context.localeName);
    final a = item.afterPlan, b = item.beforePlan;
    final parts = <String>[];
    if (b == null) {
      parts.add('${l.planLogNew}: ${amountLabel(a, profile)}');
    } else {
      if (!sameDay(a.date, b.date)) parts.add('${df.format(b.date)} → ${df.format(a.date)}');
      if (a.status == 'skipped' && b.status != 'skipped') parts.add(l.planLogDropped);
      if (a.sport != b.sport) parts.add('${b.sport.label(l)} → ${a.sport.label(l)}');
      if (a.title != b.title && a.sport == b.sport) parts.add('${b.title} → ${a.title}');
      final ba = amountLabel(b, profile), aa = amountLabel(a, profile);
      if (ba != aa && a.status != 'skipped') parts.add('$ba → $aa');
      final bs = b.exercises.fold(0, (x, e) => x + e.workSets.length), as = a.exercises.fold(0, (x, e) => x + e.workSets.length);
      if (a.sport == Sport.gym && as != bs && as > 0) parts.add('${l.sets}: ${bs > 0 ? bs : '–'} → $as');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon((b ?? a).sport.icon, size: 16, color: (b ?? a).sport.color)),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${(b ?? a).title} · ${df.format((b ?? a).date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (parts.isNotEmpty) TextSpan(text: '\n${parts.join(' · ')}'),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
