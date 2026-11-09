import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/insights.dart';
import '../../services/zones.dart';
import '../../widgets/common.dart';

/// Fitness (CTL), fatigue (ATL) and form (TSB) – Banister impulse-response model.
class FitnessFormCard extends ConsumerWidget {
  const FitnessFormCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final series = fitnessSeries(ref.watch(sessionListProvider));
    if (series.length < 7) return const SizedBox.shrink();
    final now = series.last;
    final form = now.form;
    final (label, color) =
        form > 15
            ? (l.formFresh, AppColors.swim)
            : form > -10
            ? (l.formNeutral, AppColors.success)
            : form > -30
            ? (l.formProductive, AppColors.ride)
            : (l.formOverload, AppColors.danger);
    final maxY = series.map((p) => p.fitness > p.fatigue ? p.fitness : p.fatigue).reduce((a, b) => a > b ? a : b) * 1.15 + 5;
    final minY = series.map((p) => p.form).reduce((a, b) => a < b ? a : b).clamp(-200.0, 0.0) * 1.15 - 5;
    return SectionCard(
      title: l.fitnessForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: l.fitness, value: now.fitness.round().toString(), color: AppColors.brand)),
              Expanded(child: StatTile(label: l.fatigue, value: now.fatigue.round().toString(), color: AppColors.gym)),
              Expanded(child: StatTile(label: l.form, value: form.round().toString(), color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (series.length / 4).ceilToDouble(),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= series.length) return const SizedBox.shrink();
                        return Text(DateFormat.Md(context.localeName).format(series[i].day), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _line(series.map((p) => p.fitness).toList(), AppColors.brand, fill: true),
                  _line(series.map((p) => p.fatigue).toList(), AppColors.gym.withValues(alpha: 0.8)),
                  _line(series.map((p) => p.form).toList(), color, dashed: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(l.fitnessFormHint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  LineChartBarData _line(List<double> v, Color c, {bool fill = false, bool dashed = false}) => LineChartBarData(
    spots: [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])],
    isCurved: true,
    barWidth: dashed ? 2 : 3,
    color: c,
    dashArray: dashed ? [5, 4] : null,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: fill, color: c.withValues(alpha: 0.12)),
  );
}

/// Fastest running efforts + race predictions from the best one (VDOT).
class RunBestEffortsCard extends ConsumerWidget {
  const RunBestEffortsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final efforts = runBestEfforts(ref.watch(sessionListProvider));
    final athlete = ref.watch(profileOrDefaultProvider).athlete;
    if (efforts.isEmpty && athlete.raceTimes.isEmpty) return const SizedBox.shrink();
    // VDOT: best of recorded efforts (≥ 5 km) and entered race times.
    double? vdot = Vdot.of(athlete);
    for (final e in efforts.values.where((e) => e.meters >= 5000)) {
      final v = Vdot.fromRace(e.meters, e.seconds);
      if (vdot == null || v > vdot) vdot = v;
    }
    final names = {'1k': '1 km', '5k': '5 km', '10k': '10 km', 'hm': l.halfMarathon, 'm': l.marathon};
    return SectionCard(
      title: l.bestEfforts,
      trailing: const Icon(Icons.timer_rounded, color: AppColors.run),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final k in bestEffortDistances.keys)
            if (efforts[k] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 110, child: Text(names[k]!, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMd(context.localeName).format(efforts[k]!.session.start),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      clock(efforts[k]!.seconds),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
          if (vdot != null) ...[
            const Divider(height: 24),
            Text('${l.racePredictions} · VDOT ${vdot.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in Vdot.distances.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.run.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Text(names[e.key]!, style: Theme.of(context).textTheme.labelSmall),
                        Text(clock(Vdot.raceTime(vdot, e.value)), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
