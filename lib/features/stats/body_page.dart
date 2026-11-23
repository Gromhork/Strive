import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/segments.dart';
import '../../widgets/nav.dart';

/// Body composition: weight, BMI, body fat, muscle.
class BodyPage extends ConsumerWidget {
  const BodyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final body = ref.watch(bodyProvider).value ?? const [];
    final u = ref.watch(profileOrDefaultProvider).units;
    final df = DateFormat.yMMMd(context.localeName);
    return Scaffold(
      appBar: AppBar(title: Text(l.bodyComposition)),
      floatingActionButton: FloatingActionButton(onPressed: () => showBodyEntrySheet(context, ref), child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Already on the body page: the card is no link to itself (it stacked the page again).
          const BodyCompositionCard(opensPage: false),
          const SizedBox(height: 16),
          Text(l.entries, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final b in body.reversed)
            Dismissible(
              key: ValueKey(b.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) => ref.read(repoProvider)!.deleteBody(b.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(u.weight(b.weightKg)),
                subtitle: Text(
                  [
                    df.format(b.date),
                    if (b.fatPct != null) '${l.bodyFat} ${Units.num(b.fatPct!)}${Units.pctSign}',
                    if (b.musclePct != null) '${l.muscleMass} ${Units.num(b.musclePct!)}${Units.pctSign}',
                  ].join(' · '),
                ),
                onTap: () => showBodyEntrySheet(context, ref, existing: b),
              ),
            ),
        ],
      ),
    );
  }
}

class BodyCompositionCard extends ConsumerStatefulWidget {
  const BodyCompositionCard({super.key, this.opensPage = true});

  /// Tapping opens the [BodyPage] – off on that page itself.
  final bool opensPage;
  @override
  ConsumerState<BodyCompositionCard> createState() => _BodyCompositionCardState();
}

class _BodyCompositionCardState extends ConsumerState<BodyCompositionCard> {
  int _metric = 0; // weight, bmi, fat, muscle

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = ref.watch(bodyProvider).value ?? const [];
    final p = ref.watch(profileOrDefaultProvider);
    final u = p.units;
    final h = p.heightCm / 100;
    double? value(BodyEntry b) => switch (_metric) {
      0 => u.weightOut(b.weightKg),
      1 => h > 0 ? b.weightKg / (h * h) : null,
      2 => b.fatPct,
      _ => b.musclePct,
    };
    final pts = [
      for (final b in body)
        if (value(b) != null) (b.date, value(b)!),
    ];
    final last = body.isEmpty ? null : body.last;
    final colors = [AppColors.brand, AppColors.swim, AppColors.gym, AppColors.run];
    return SectionCard(
      title: l.bodyComposition,
      onTap: widget.opensPage ? () => openPage(context, const BodyPage()) : null,
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add),
        onPressed: () => showBodyEntrySheet(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: l.weight, value: last == null ? u.weight(p.weightKg) : u.weight(last.weightKg))),
              Expanded(child: StatTile(label: 'BMI', value: Units.fixed(last == null ? p.bmi : last.weightKg / (h * h)))),
              Expanded(
                child: StatTile(label: l.bodyFat, value: last?.fatPct == null ? '–' : '${Units.num(last!.fatPct!)}${Units.pctSign}'),
              ),
              Expanded(
                child: StatTile(label: l.muscle, value: last?.musclePct == null ? '–' : '${Units.num(last!.musclePct!)}${Units.pctSign}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Segments<int>(
            dense: true,
            segments: [Seg(0, label: l.weight), Seg(1, label: 'BMI'), Seg(2, label: l.bodyFat), Seg(3, label: l.muscle)],
            value: _metric,
            onChanged: (v) => setState(() => _metric = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child:
                pts.length < 2
                    ? Center(child: Text(l.notEnoughData, style: Theme.of(context).textTheme.bodySmall))
                    : LineChart(
                      LineChartData(
                        minY: paddedRange([for (final x in pts) x.$2], minSpan: 3).$1,
                        maxY: paddedRange([for (final x in pts) x.$2], minSpan: 3).$2,
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval:
                                  ((pts.last.$1.millisecondsSinceEpoch - pts.first.$1.millisecondsSinceEpoch) / 3)
                                      .clamp(1, double.infinity)
                                      .toDouble(),
                              getTitlesWidget:
                                  (v, _) => Text(
                                    DateFormat.Md(context.localeName).format(DateTime.fromMillisecondsSinceEpoch(v.toInt())),
                                    style: const TextStyle(fontSize: 9),
                                  ),
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (final x in pts) FlSpot(x.$1.millisecondsSinceEpoch.toDouble(), double.parse(x.$2.toStringAsFixed(1))),
                            ],
                            isCurved: pts.length > 2,
                            preventCurveOverShooting: true,
                            curveSmoothness: 0.2,
                            color: colors[_metric],
                            barWidth: 3,
                            belowBarData: BarAreaData(show: true, color: colors[_metric].withValues(alpha: 0.12)),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

Future<void> showBodyEntrySheet(BuildContext context, WidgetRef ref, {BodyEntry? existing}) {
  final l = context.l10n;
  final p = ref.read(profileOrDefaultProvider);
  final u = p.units;
  final w = TextEditingController(text: Units.num(u.weightOut(existing?.weightKg ?? p.weightKg), 2));
  final f = TextEditingController(text: existing?.fatPct == null ? '' : Units.num(existing!.fatPct!));
  final m = TextEditingController(text: existing?.musclePct == null ? '' : Units.num(existing!.musclePct!));
  var date = existing?.date ?? DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder:
        (c) => StatefulBuilder(
          builder:
              (c, setS) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.logBody, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event),
                          title: Text(DateFormat.yMMMd(c.localeName).format(date)),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: c,
                              initialDate: date,
                              firstDate: DateTime(2010),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setS(() => date = d);
                          },
                        ),
                        TextField(
                          controller: w,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: l.weight, suffixText: u.weightUnit),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: f,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: l.bodyFat, suffixText: '%'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: m,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: l.muscleMass, suffixText: '%'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () {
                            final kg = parseNum(w.text);
                            if (kg == null) return;
                            final repo = ref.read(repoProvider)!;
                            final entry = BodyEntry(
                              id: existing?.id ?? repo.newId(),
                              date: date,
                              weightKg: u.weightIn(kg),
                              fatPct: parseNum(f.text),
                              musclePct: parseNum(m.text),
                            );
                            repo.saveBody(entry);
                            final body = ref.read(bodyProvider).value ?? const [];
                            if (body.isEmpty || !date.isBefore(body.last.date)) {
                              repo.saveProfile(p.copyWith(weightKg: entry.weightKg, fatPct: entry.fatPct, musclePct: entry.musclePct));
                            }
                            Navigator.pop(c);
                          },
                          child: Text(l.save),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
  );
}
