import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/plan_recalibrate.dart';
import '../../widgets/common.dart';

/// "Re-plan & recalibrate": computes the proposal for the next two weeks and shows it as
/// a preview; nothing changes until the athlete confirms with "Apply".
Future<void> showRecalibration(BuildContext context, WidgetRef ref) {
  final profile = ref.read(profileOrDefaultProvider);
  final r =
      Recalibrator(
        context.l10n,
        profile,
        plans: ref.read(planListProvider),
        sessions: ref.read(sessionListProvider),
        now: DateTime.now(),
      ).run();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (sheet) => RecalibrationSheet(
          result: r,
          onApply: () {
            final repo = ref.read(repoProvider)!;
            // Only planned workouts of the coming days are in [updates] – done ones stay untouched.
            if (r.updates.isNotEmpty) repo.updateMany(plans: r.updates);
            if (r.raceTimes != null) repo.saveProfile(profile.copyWith(athlete: profile.athlete.merge({'raceTimes': r.raceTimes})));
            Navigator.pop(sheet);
            toast(context, context.l10n.recalApplied);
          },
        ),
  );
}

/// Preview of a [Recalibration]: why, and what gets easier / harder / moved.
class RecalibrationSheet extends StatelessWidget {
  const RecalibrationSheet({super.key, required this.result, required this.onApply});
  final Recalibration result;
  final VoidCallback onApply;

  static String _reason(AppLocalizations l, RecalReason r, RecalStats s) => switch (r) {
    RecalReason.rpeHigh => l.recalWhyRpeHigh,
    RecalReason.rpeLow => l.recalWhyRpeLow,
    RecalReason.lowCompletion => l.recalWhyCompletion(((s.completion ?? 0) * 100).round()),
    RecalReason.cutShort => l.recalWhyCutShort(s.cutShort),
    RecalReason.missedKey => l.recalWhyMissed,
    RecalReason.fasterRuns => l.recalWhyFaster(s.oldVdot.toStringAsFixed(1), (s.newVdot ?? s.oldVdot).toStringAsFixed(1)),
    RecalReason.slowerRuns => l.recalWhySlower(s.oldVdot.toStringAsFixed(1), (s.newVdot ?? s.oldVdot).toStringAsFixed(1)),
  };

  static (IconData, Color, String) kindStyle(AppLocalizations l, RecalKind k) => switch (k) {
    RecalKind.easier => (Icons.trending_down_rounded, AppColors.success, l.recalEasier),
    RecalKind.harder => (Icons.trending_up_rounded, AppColors.warning, l.recalHarder),
    RecalKind.toEasy => (Icons.spa_outlined, AppColors.success, l.recalToEasy),
    RecalKind.moved => (Icons.event_repeat_rounded, AppColors.brand, l.recalMoved),
    RecalKind.dropped => (Icons.event_busy_rounded, AppColors.danger, l.recalDropped),
    RecalKind.paces => (Icons.speed_rounded, AppColors.run, l.recalPaces),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = result;
    final changes = [...r.changes]..sort((a, b) => a.after.date.compareTo(b.after.date));
    final n = changes.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  Text(l.recalTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(l.recalIntro, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Text(l.recalFindings, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (r.reasons.isEmpty) _Bullet(icon: Icons.check_circle_rounded, color: AppColors.success, text: l.recalOnTrack),
                  for (final reason in r.reasons)
                    _Bullet(icon: Icons.insights_rounded, color: AppColors.brand, text: _reason(l, reason, r.stats)),
                  if (r.stats.rated == 0) _Bullet(icon: Icons.lightbulb_outline_rounded, color: AppColors.warning, text: l.recalNoRpe),
                  if (n > 0) ...[
                    const SizedBox(height: 14),
                    Text(l.recalChanges, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final c in changes) _ChangeTile(change: c),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
                  if (!r.isEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const ValueKey('recalApply'),
                        onPressed: onApply,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(n > 0 ? l.recalApply(n) : l.apply, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

/// One changed workout: kind, day, before → after.
class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});
  final RecalChange change;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = change;
    final df = DateFormat.MMMEd(context.localeName);
    final (icon, color, label) = RecalibrationSheet.kindStyle(l, c.kind);
    String amount(PlannedWorkout p) =>
        ['${p.durationMin} min', if (p.distanceKm != null && p.sport != Sport.gym) '${Units.num(p.distanceKm!)} km'].join(' · ');
    final detail = switch (c.kind) {
      RecalKind.moved => '${df.format(c.before.date)} → ${df.format(c.after.date)}',
      RecalKind.dropped || RecalKind.paces => amount(c.before),
      _ => '${amount(c.before)} → ${amount(c.after)}',
    };
    final title = c.after.title == c.before.title ? c.before.title : '${c.before.title} → ${c.after.title}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(c.before.sport.icon, color: c.before.sport.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${df.format(c.after.date)} · $detail', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
