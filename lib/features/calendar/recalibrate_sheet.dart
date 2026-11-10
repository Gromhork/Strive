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
import '../../services/goal_forecast.dart';
import '../../services/plan_gaps.dart';
import '../../services/plan_recalibrate.dart';
import '../../services/zones.dart' show fmtPace;
import '../../widgets/common.dart';
import '../goals/goal_forecast_widgets.dart';

/// "Review plan" (adapt plan to your training): computes the proposal for the next two weeks and shows it as
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
        templates: ref.read(templateListProvider),
        newId: ref.read(repoProvider)?.newId,
      ).run();
  // Goal forecast (Zielprognose): where the athlete stands on the way to the event goal.
  final forecast = GoalForecast.of(
    profile,
    plans: ref.read(planListProvider),
    sessions: ref.read(sessionListProvider),
    now: DateTime.now(),
  );
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (sheet) => RecalibrationSheet(
          result: r,
          forecast: forecast == null || forecast.early ? null : forecast,
          onAdjustTarget: (sec) {
            applyTargetTime(context, ref, sec);
            Navigator.pop(sheet);
          },
          onApply: (r) {
            final repo = ref.read(repoProvider)!;
            // Only planned workouts of the coming days are in [updates] – done ones stay untouched.
            if (r.updates.isNotEmpty) repo.updateMany(plans: r.updates);
            // Refilled gaps the athlete kept ticked.
            if (r.additions.isNotEmpty) repo.savePlans(r.additions);
            // Plan history: what changed, with the findings as they were shown.
            repo.logPlanChange(
              PlanLogEntry.of('recal', [
                for (final c in r.changes)
                  if (c.kind == RecalKind.added || r.updates.containsKey(c.before.id))
                    (c.kind == RecalKind.added ? null : c.before, c.after),
              ], note: [for (final x in r.reasons) RecalibrationSheet._reason(context.l10n, x, r.stats)].join('\n')),
            );
            if (r.raceTimes != null || r.athlete.isNotEmpty) {
              repo.saveProfile(
                profile.copyWith(athlete: profile.athlete.merge({if (r.raceTimes != null) 'raceTimes': r.raceTimes, ...r.athlete})),
              );
            }
            Navigator.pop(sheet);
            toast(context, context.l10n.recalApplied);
          },
        ),
  );
}

/// Preview of a [Recalibration]: why, and what gets easier / harder / moved; refills of
/// gaps in the plan can be unticked.
class RecalibrationSheet extends StatefulWidget {
  const RecalibrationSheet({super.key, required this.result, required this.onApply, this.forecast, this.onAdjustTarget});
  final Recalibration result;

  /// Called with the proposal minus the unticked refills.
  final ValueChanged<Recalibration> onApply;

  /// Goal forecast shown above the findings (null: no event goal / too early).
  final GoalForecast? forecast;
  final ValueChanged<int>? onAdjustTarget;

  static String _reason(AppLocalizations l, RecalReason r, RecalStats s) => switch (r) {
    RecalReason.rpeHigh => l.recalWhyRpeHigh,
    RecalReason.rpeLow => l.recalWhyRpeLow,
    RecalReason.lowCompletion => l.recalWhyCompletion(((s.completion ?? 0) * 100).round()),
    RecalReason.cutShort => l.recalWhyCutShort(s.cutShort),
    RecalReason.missedKey => l.recalWhyMissed,
    RecalReason.fasterRuns => l.recalWhyFaster(s.oldVdot.toStringAsFixed(1), (s.newVdot ?? s.oldVdot).toStringAsFixed(1)),
    RecalReason.slowerRuns => l.recalWhySlower(s.oldVdot.toStringAsFixed(1), (s.newVdot ?? s.oldVdot).toStringAsFixed(1)),
    RecalReason.runTrendSlower => l.recalWhyRunTrendSlower(s.oldVdot.toStringAsFixed(1), (s.newVdot ?? s.oldVdot).toStringAsFixed(1)),
    RecalReason.runTrendFaster => l.recalWhyRunTrendFaster(s.oldVdot.toStringAsFixed(1), (s.newVdot ?? s.oldVdot).toStringAsFixed(1)),
    RecalReason.ftpUp => l.recalWhyFtpUp('${s.oldFtp ?? ''}', '${s.newFtp ?? ''}'),
    RecalReason.ftpDown => l.recalWhyFtpDown('${s.oldFtp ?? ''}', '${s.newFtp ?? ''}'),
    RecalReason.cssFaster => l.recalWhyCssFaster(fmtPace(s.oldCss ?? 0), fmtPace(s.newCss ?? s.oldCss ?? 0)),
    RecalReason.cssSlower => l.recalWhyCssSlower(fmtPace(s.oldCss ?? 0), fmtPace(s.newCss ?? s.oldCss ?? 0)),
    RecalReason.aerobicUp => l.recalWhyAerobicUp((_ef(s) * 100).round().abs()),
    RecalReason.aerobicDown => l.recalWhyAerobicDown((_ef(s) * 100).round().abs()),
    RecalReason.returnAfterBreak => l.recalWhyBreak(s.breakDays ?? Recalibrator.lookbackDays),
    RecalReason.longCap => l.recalWhyLongCap,
    RecalReason.rpeLowHold => l.recalWhyRpeLowHold,
    RecalReason.planGaps => l.recalWhyGaps(s.gaps),
    RecalReason.gapsOmitted => l.recalWhyGapsOmitted,
  };

  /// Largest change of the aerobic efficiency factor (any sport).
  static double _ef(RecalStats s) => s.efficiency.values.fold<double>(0, (x, v) => v.abs() > x.abs() ? v : x);

  static (IconData, Color, String) kindStyle(AppLocalizations l, RecalKind k) => switch (k) {
    RecalKind.easier => (Icons.trending_down_rounded, AppColors.success, l.recalEasier),
    RecalKind.harder => (Icons.trending_up_rounded, AppColors.warning, l.recalHarder),
    RecalKind.toEasy => (Icons.spa_outlined, AppColors.success, l.recalToEasy),
    RecalKind.moved => (Icons.event_repeat_rounded, AppColors.brand, l.recalMoved),
    RecalKind.dropped => (Icons.event_busy_rounded, AppColors.danger, l.recalDropped),
    RecalKind.paces => (Icons.speed_rounded, AppColors.run, l.recalPaces),
    RecalKind.added => (Icons.add_circle_outline_rounded, AppColors.brand, l.recalAdded),
  };

  @override
  State<RecalibrationSheet> createState() => _RecalibrationSheetState();
}

class _RecalibrationSheetState extends State<RecalibrationSheet> {
  /// Refills the athlete unticked.
  final _off = <RecalChange>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = widget.result;
    final all = [...r.changes]..sort((a, b) => a.after.date.compareTo(b.after.date));
    final changes = all.where((c) => c.kind != RecalKind.added).toList();
    final gaps = all.where((c) => c.kind == RecalKind.added).toList();
    final chosen = r.without(_off);
    final n = chosen.changes.length;
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
                  if (widget.forecast != null) ...[
                    const SizedBox(height: 12),
                    ForecastSummary(widget.forecast!, onAdjustTarget: widget.onAdjustTarget),
                  ],
                  const SizedBox(height: 16),
                  Text(l.recalFindings, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (r.reasons.isEmpty) _Bullet(icon: Icons.check_circle_rounded, color: AppColors.success, text: l.recalOnTrack),
                  for (final reason in r.reasons)
                    _Bullet(icon: Icons.insights_rounded, color: AppColors.brand, text: RecalibrationSheet._reason(l, reason, r.stats)),
                  if (r.stats.rated == 0 && r.stats.estimated == 0)
                    _Bullet(icon: Icons.lightbulb_outline_rounded, color: AppColors.warning, text: l.recalNoRpe),
                  if (changes.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(l.recalChanges, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final c in changes) _ChangeTile(change: c),
                  ],
                  if (gaps.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(l.recalGapsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final c in gaps)
                      _GapTile(change: c, on: !_off.contains(c), onChanged: (v) => setState(() => v ? _off.remove(c) : _off.add(c))),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  // Cancel takes its natural width, the main action the rest; labels scale
                  // down instead of wrapping ("Abbreche-n") or being cut off.
                  if (r.isEmpty)
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)))
                  else ...[
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('recalApply'),
                        onPressed: chosen.isEmpty ? null : () => widget.onApply(chosen),
                        icon: const Icon(Icons.check_rounded),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(n > 0 ? l.recalApply(n) : l.apply, maxLines: 1)),
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

/// One proposed refill: tick box, sport, title, day · amount and why.
class _GapTile extends StatelessWidget {
  const _GapTile({required this.change, required this.on, required this.onChanged});
  final RecalChange change;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = change.after;
    final g = change.gap;
    final df = DateFormat.MMMEd(context.localeName);
    final amount = ['${p.durationMin} min', if (p.distanceKm != null && p.sport != Sport.gym) '${Units.num(p.distanceKm!)} km'].join(' · ');
    final why = [
      switch (g?.why) {
        GapWhy.emptyWeek => l.recalGapEmptyWeek,
        GapWhy.planEnded => l.recalGapEnded,
        _ => l.recalGapMissing(DateFormat.E(context.localeName).format(p.date)),
      },
      if (g?.downgraded ?? false) l.recalGapDowngraded,
      if (g?.eased ?? false) l.recalGapEased,
      if (g?.shortened ?? false) l.recalGapShortened,
    ].join(' ');
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('recalGap_${dayKey(p.date)}_${p.sport.name}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!on),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: on, onChanged: (v) => onChanged(v ?? false)),
            Padding(padding: const EdgeInsets.only(top: 12), child: Icon(p.sport.icon, color: p.sport.color, size: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${df.format(p.date)} · $amount', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      why,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
