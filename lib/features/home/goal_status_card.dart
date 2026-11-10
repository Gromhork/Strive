import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/goal_forecast.dart';
import '../calendar/recalibrate_sheet.dart';
import '../goals/goal_forecast_widgets.dart';
import '../goals/goal_status_page.dart';

/// When the "goal at risk" notice was last dismissed – it comes back at most once a week.
class GoalAlertSnooze extends Notifier<DateTime?> {
  static const key = 'goalRiskSnoozed';
  static const every = Duration(days: 7);

  @override
  DateTime? build() {
    try {
      final ms = ref.watch(prefsProvider).getInt(key);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null; // no preferences (tests)
    }
  }

  void snooze(DateTime now) {
    state = now;
    try {
      ref.read(prefsProvider).setInt(key, now.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// The notice is shown for an at-risk forecast unless it was dismissed in the last 7 days.
  static bool visible(GoalForecast f, DateTime? snoozed, DateTime now) => f.alert && (snoozed == null || now.difference(snoozed) >= every);
}

final goalAlertSnoozeProvider = NotifierProvider<GoalAlertSnooze, DateTime?>(GoalAlertSnooze.new);

/// "Where I stand" on the home screen – only for athletes with an upcoming event.
class GoalStatusCard extends ConsumerWidget {
  const GoalStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(goalForecastProvider);
    if (f == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final plans = ref.watch(planListProvider);
    final alert = GoalAlertSnooze.visible(f, ref.watch(goalAlertSnoozeProvider), now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GoalStatusCardView(
        forecast: f,
        segments: f.planStart == null ? const [] : phaseSegments(plans, f.planStart!, f.raceDate),
        now: now,
        showAlert: alert,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalStatusPage())),
        onAdjustTarget: (sec) {
          applyTargetTime(context, ref, sec);
          ref.read(goalAlertSnoozeProvider.notifier).snooze(now);
        },
        onRecalibrate: () {
          ref.read(goalAlertSnoozeProvider.notifier).snooze(now);
          showRecalibration(context, ref);
        },
        onDismiss: () => ref.read(goalAlertSnoozeProvider.notifier).snooze(now),
      ),
    );
  }
}

/// The card itself (pure – also used by the layout tests).
class GoalStatusCardView extends StatelessWidget {
  const GoalStatusCardView({
    super.key,
    required this.forecast,
    required this.segments,
    required this.now,
    this.showAlert = false,
    this.onTap,
    this.onAdjustTarget,
    this.onRecalibrate,
    this.onDismiss,
  });

  final GoalForecast forecast;
  final List<(String, int)> segments;
  final DateTime now;
  final bool showAlert;
  final VoidCallback? onTap;
  final ValueChanged<int>? onAdjustTarget;
  final VoidCallback? onRecalibrate;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final f = forecast;
    final start = f.planStart == null ? null : startOfWeek(f.planStart!);
    final span = start == null ? 0 : f.raceDate.difference(start).inDays + 1;
    final position = span <= 0 ? 0.0 : dayOnly(now).difference(start!).inDays / span;
    return Card(
      key: const ValueKey('goalStatusCard'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.goalStatusTitle, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        Text(
                          '${eventLabel(l, f.event)} · ${DateFormat.MMMd(context.localeName).format(f.raceDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(countdownText(l, f.daysLeft), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(l.goalToRace, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (segments.isNotEmpty) ...[const SizedBox(height: 14), PhaseTimeline(segments: segments, position: position)],
              const SizedBox(height: 12),
              ForecastTimes(f),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: ForecastChip(f)),
              if (f.early) ...[const SizedBox(height: 6), Text(l.fcEarlySub, style: theme.textTheme.bodySmall)],
              if (showAlert) ...[
                const SizedBox(height: 12),
                _RiskNotice(f: f, onAdjustTarget: onAdjustTarget, onRecalibrate: onRecalibrate, onDismiss: onDismiss),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your goal is at risk" with the options: adjust the target time, re-plan.
class _RiskNotice extends StatelessWidget {
  const _RiskNotice({required this.f, this.onAdjustTarget, this.onRecalibrate, this.onDismiss});
  final GoalForecast f;
  final ValueChanged<int>? onAdjustTarget;
  final VoidCallback? onRecalibrate;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final target = f.targetSec;
    return Container(
      key: const ValueKey('goalRiskNotice'),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.fcRiskTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  target != null && f.raceDaySec != null ? l.fcRiskBody(clock(f.raceDaySec!), clock(target)) : l.fcRiskBodyFinish,
                  style: const TextStyle(fontSize: 13),
                ),
                for (final r in f.reasons) Text('• ${forecastReasonText(l, f, r)}', style: const TextStyle(fontSize: 12)),
                for (final line in progressionLines(l, f))
                  Text(line.startsWith('→') ? line : '• $line', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (f.suggestedSec != null && onAdjustTarget != null)
                      FilledButton.tonal(
                        key: const ValueKey('riskAdjust'),
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => onAdjustTarget!(f.suggestedSec!),
                        child: Text(l.adjustTargetTo(clock(f.suggestedSec!))),
                      ),
                    if (onRecalibrate != null)
                      OutlinedButton(
                        key: const ValueKey('riskRecal'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: onRecalibrate,
                        child: Text(l.recalTitle),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
