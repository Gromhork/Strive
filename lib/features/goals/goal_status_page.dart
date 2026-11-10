import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/goal_forecast.dart';
import '../../services/plan_generator.dart';
import '../../widgets/common.dart';
import '../../widgets/term_info.dart';
import '../calendar/recalibrate_sheet.dart';
import '../onboarding/onboarding_page.dart';
import 'goal_forecast_widgets.dart';

/// "Where I stand": countdown, plan phases, forecast vs. target, completion, long run and the
/// fitness trend of the athlete's event goal.
class GoalStatusPage extends ConsumerWidget {
  const GoalStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = ref.watch(goalForecastProvider);
    final plans = ref.watch(planListProvider);
    final profile = ref.watch(profileOrDefaultProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.goalStatusTitle)),
      body:
          f == null
              ? EmptyState(icon: Icons.emoji_events_outlined, text: l.noGoalsYet)
              : GoalStatusView(
                forecast: f,
                segments: f.planStart == null ? const [] : phaseSegments(plans, f.planStart!, f.raceDate),
                outlook: f.planStart == null ? const [] : PlanGenerator.outlook(profile, start: f.planStart!),
                now: DateTime.now(),
                onAdjustTarget: (sec) => applyTargetTime(context, ref, sec),
                onRecalibrate: () => showRecalibration(context, ref),
                onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan))),
              ),
    );
  }
}

/// The page body (pure – also used by the layout tests).
class GoalStatusView extends StatelessWidget {
  const GoalStatusView({
    super.key,
    required this.forecast,
    required this.segments,
    required this.outlook,
    required this.now,
    this.onAdjustTarget,
    this.onRecalibrate,
    this.onSettings,
  });

  final GoalForecast forecast;
  final List<(String, int)> segments;
  final List<PhaseOutlook> outlook;
  final DateTime now;
  final ValueChanged<int>? onAdjustTarget;
  final VoidCallback? onRecalibrate;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final f = forecast;
    final (color, icon, label) = forecastStyle(l, f);
    final start = f.planStart == null ? null : startOfWeek(f.planStart!);
    final span = start == null ? 0 : daysBetween(start, f.raceDate) + 1;
    final elapsed = start == null ? 0 : daysBetween(start, dayOnly(now));
    final position = span <= 0 ? 0.0 : elapsed / span;
    final currentWeek = elapsed ~/ 7;
    final small = theme.textTheme.bodySmall;
    final conf = switch (f.confidence) {
      ForecastConfidence.high => l.fcConfHigh,
      ForecastConfidence.medium => l.fcConfMedium,
      ForecastConfidence.low => l.fcConfLow,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Countdown
        SectionCard(
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventLabel(l, f.event),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      DateFormat.yMMMMEEEEd(context.localeName).format(f.raceDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
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
                      Text(countdownText(l, f.daysLeft), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(l.goalToRace, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Forecast
        SectionCard(
          title: l.goalForecast,
          trailing: ForecastChip(f),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ForecastTimes(f, large: true),
              if (!f.early && f.fastSec != null && f.slowSec != null) ...[
                const SizedBox(height: 8),
                Text('${l.fcRange(clock(f.fastSec!), clock(f.slowSec!))} · $conf', style: small),
              ],
              if (f.early) ...[const SizedBox(height: 8), Text(l.fcEarlySub, style: small)],
              if (!f.early && f.status == ForecastStatus.atRisk && f.targetSec != null && f.raceDaySec != null) ...[
                const SizedBox(height: 8),
                Text(l.fcRiskBody(clock(f.raceDaySec!), clock(f.targetSec!)), style: TextStyle(color: color, fontSize: 13)),
              ],
              if (!f.early && f.status == ForecastStatus.ahead && f.suggestedSec != null) ...[
                const SizedBox(height: 8),
                Text(l.fcAheadBody(clock(f.suggestedSec!)), style: TextStyle(color: color, fontSize: 13)),
              ],
              for (final r in f.reasons) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(forecastReasonText(l, f, r), style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ],
              for (final line in progressionLines(l, f)) ...[
                const SizedBox(height: 4),
                Text(line.startsWith('→') ? line : '• $line', style: const TextStyle(fontSize: 13)),
              ],
              if (!f.early && f.suggestedSec != null && onAdjustTarget != null && f.status != ForecastStatus.onTrack) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('pageAdjust'),
                    onPressed: () => onAdjustTarget!(f.suggestedSec!),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text(l.adjustTargetTo(clock(f.suggestedSec!))),
                  ),
                ),
              ],
              Semantics(label: label, child: const SizedBox.shrink()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Phases
        if (segments.isNotEmpty)
          SectionCard(
            title: l.goalPhaseOutlook,
            trailing: const TermInfoButton(Term.phases),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PhaseTimeline(segments: segments, position: position, height: 12),
                const SizedBox(height: 12),
                for (final o in outlook) _PhaseRow(o: o, current: currentWeek >= o.firstWeek && currentWeek < o.firstWeek + o.weeks),
              ],
            ),
          ),
        if (segments.isNotEmpty) const SizedBox(height: 12),
        // ── Progress
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Meter(
                label: l.goalCompletion,
                value: f.adherence == null ? '–' : Units.pct(f.adherence! * 100),
                progress: f.adherence ?? 0,
                color:
                    f.adherence == null
                        ? theme.colorScheme.outline
                        : (f.adherence! >= 0.8 ? AppColors.success : (f.adherence! >= 0.6 ? AppColors.warning : AppColors.danger)),
              ),
              if (f.longRunNeededKm != null) ...[
                const SizedBox(height: 14),
                _Meter(
                  label: l.goalLongestRun,
                  value: f.longestRunKm == null ? '–' : '${Units.num(f.longestRunKm!, 1)} km',
                  progress: (f.longestRunKm ?? 0) / f.longRunNeededKm!,
                  color: AppColors.run,
                  sub: l.goalLongRunNeed(f.longRunNeededKm!.round()),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Trend
        SectionCard(title: l.goalFitnessTrend, trailing: const TermInfoButton(Term.vdot), child: _TrendChart(f: f, now: now)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onRecalibrate != null)
              OutlinedButton.icon(
                onPressed: onRecalibrate,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(l.recalTitle),
              ),
            if (onSettings != null)
              OutlinedButton.icon(onPressed: onSettings, icon: const Icon(Icons.tune_rounded, size: 18), label: Text(l.goalEditPlan)),
          ],
        ),
      ],
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.o, required this.current});
  final PhaseOutlook o;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: current ? phaseColor(o.phase).withValues(alpha: 0.14) : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: phaseColor(o.phase), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${phaseShort(l, o.phase)} · ${l.goalWeeksN(o.weeks)}${current ? ' · ${l.goalPhaseNow}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: current ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
                ),
                Text(
                  ['VDOT ${Units.fixed(o.expectedVdot)}', if (o.predictedSec != null) '~${clock(o.predictedSec!)}'].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.progress, required this.color, this.sub});
  final String label, value;
  final double progress;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        if (sub != null) ...[const SizedBox(height: 4), Text(sub!, style: theme.textTheme.bodySmall)],
      ],
    );
  }
}

/// Fitness (VDOT) of the athlete's efforts and quality runs vs. the plan's expected line.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.f, required this.now});
  final GoalForecast f;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final origin = f.planStart ?? (f.trend.isEmpty ? dayOnly(now) : f.trend.first.$1);
    double x(DateTime d) => daysBetween(origin, d).toDouble();
    final actual = [for (final p in f.trend) FlSpot(x(p.$1), p.$2)];
    final planned = [for (final p in f.planned) FlSpot(x(p.$1), p.$2)];
    if (actual.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l.goalTrendEmpty, style: theme.textTheme.bodySmall));
    }
    final ys = [...actual.map((s) => s.y), ...planned.map((s) => s.y), if (f.vdotNow != null) f.vdotNow!];
    final minY = (ys.reduce(min) - 1).floorToDouble(), maxY = (ys.reduce(max) + 1).ceilToDouble();
    final xs = [...actual.map((s) => s.x), ...planned.map((s) => s.x)];
    final grid = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    Widget legend(Color c, String t, {bool dashed = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: dashed ? c.withValues(alpha: 0.6) : c),
        const SizedBox(width: 4),
        Text(t, style: theme.textTheme.labelSmall),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              minX: xs.reduce(min),
              maxX: max(xs.reduce(max), xs.reduce(min) + 1),
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: max(1, ((maxY - minY) / 4).roundToDouble()),
                getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: max(1, ((maxY - minY) / 4).roundToDouble()),
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: theme.textTheme.labelSmall),
                  ),
                ),
              ),
              lineBarsData: [
                if (planned.length >= 2)
                  LineChartBarData(
                    spots: planned,
                    color: theme.colorScheme.outline,
                    barWidth: 2,
                    dashArray: const [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                LineChartBarData(
                  spots: actual,
                  color: AppColors.brand,
                  barWidth: 2.5,
                  isCurved: actual.length > 2,
                  preventCurveOverShooting: true,
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3.5, color: AppColors.brand, strokeWidth: 0),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [legend(AppColors.brand, l.goalTrendActual), legend(theme.colorScheme.outline, l.goalTrendPlanned, dashed: true)],
        ),
      ],
    );
  }
}
