import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/exercise_db.dart';
import '../../providers.dart';
import '../../services/insights.dart';
import '../../services/translate_service.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_media.dart';

class ExerciseDetailPage extends ConsumerWidget {
  const ExerciseDetailPage({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final sessions = ref.watch(sessionListProvider);
    final u = ref.watch(profileOrDefaultProvider).units;
    final hist = e1rmHistory(sessions, exercise.id);
    final rec = exerciseRecords(sessions)[exercise.id];
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(exercise.displayName, maxLines: 2)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(aspectRatio: 1.3, child: ExerciseMedia(exId: exercise.id, radius: 24)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(avatar: const Icon(Icons.accessibility_new, size: 16), label: Text(term(exercise.bodyPart, lang))),
              Chip(avatar: const Icon(Icons.adjust, size: 16, color: AppColors.gym), label: Text(term(exercise.target, lang))),
              Chip(avatar: const Icon(Icons.fitness_center, size: 16), label: Text(term(exercise.equipment, lang))),
            ],
          ),
          if (exercise.secondary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${l.secondaryMuscles}: ${exercise.secondary.map((s) => term(s, lang)).join(', ')}', style: t.bodySmall),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.play_circle_outline),
            label: Text(l.watchVideo),
            onPressed:
                () => launchUrl(
                  Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent('${exercise.name} proper form')}'),
                  mode: LaunchMode.externalApplication,
                ),
          ),
          const SizedBox(height: 16),
          if (rec != null)
            SectionCard(
              title: l.yourRecords,
              child: Row(
                children: [
                  if (rec.maxWeight > 0) ...[
                    Expanded(child: StatTile(label: 'e1RM', value: u.weight(rec.bestE1rm), color: AppColors.gym)),
                    Expanded(child: StatTile(label: l.maxWeight, value: u.weight(rec.maxWeight))),
                  ] else
                    Expanded(child: StatTile(label: l.maxReps, value: '${rec.maxReps}', color: AppColors.gym)),
                  Expanded(child: StatTile(label: l.sessions, value: '${rec.sessions}')),
                ],
              ),
            ),
          if (hist.length >= 2) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: l.strengthProgress,
              child: SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: (hist.length / 4).ceilToDouble().clamp(1, 1000),
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= hist.length) return const SizedBox.shrink();
                            return Text(DateFormat.Md(context.localeName).format(hist[i].$1), style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < hist.length; i++) FlSpot(i.toDouble(), u.weightOut(hist[i].$2).roundToDouble())],
                        isCurved: true,
                        color: AppColors.gym,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: AppColors.gym.withValues(alpha: 0.12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(l.instructions, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _Instructions(exercise: exercise, lang: lang),
        ],
      ),
    );
  }
}

class _Instructions extends ConsumerStatefulWidget {
  const _Instructions({required this.exercise, required this.lang});
  final Exercise exercise;
  final String lang;
  @override
  ConsumerState<_Instructions> createState() => _InstructionsState();
}

class _InstructionsState extends ConsumerState<_Instructions> {
  Future<List<String>>? _future;
  bool _original = false;

  @override
  void initState() {
    super.initState();
    if (widget.lang != 'en') {
      final tr = TranslateService(ref.read(prefsProvider));
      final e = widget.exercise;
      final c = tr.cached(e.id, widget.lang);
      _future = c != null ? Future.value(c) : tr.instructions(e.id, e.name, e.instructions, widget.lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget list(List<String> steps) => Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.gym.withValues(alpha: 0.2),
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
      ],
    );
    if (_future == null || _original) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          list(widget.exercise.instructions),
          if (_original) TextButton(onPressed: () => setState(() => _original = false), child: Text(l.showTranslation)),
        ],
      );
    }
    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(l.translating),
              ],
            ),
          );
        }
        final steps = snap.data ?? widget.exercise.instructions;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            list(steps),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(child: Text(snap.hasError ? l.translationFailed : l.translatedByAi, style: Theme.of(context).textTheme.bodySmall)),
                if (!snap.hasError) TextButton(onPressed: () => setState(() => _original = true), child: Text(l.showOriginal)),
              ],
            ),
          ],
        );
      },
    );
  }
}
