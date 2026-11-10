import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/insights.dart';
import '../../widgets/common.dart';
import 'fitness_cards.dart';
import '../session/session_summary_page.dart' show badgeTitle;
import '../train/exercise_detail_page.dart';
import 'body_page.dart';
import 'session_detail_page.dart';
import '../../widgets/term_info.dart';
import '../../widgets/segments.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(dividerColor: Colors.transparent, tabs: [Tab(text: l.performance), Tab(text: l.records), Tab(text: l.history)]),
          const Expanded(child: TabBarView(children: [_Performance(), _Records(), _History()])),
        ],
      ),
    );
  }
}

// ───────────────────────────── Performance ─────────────────────────────

class _Performance extends ConsumerStatefulWidget {
  const _Performance();
  @override
  ConsumerState<_Performance> createState() => _PerformanceState();
}

class _PerformanceState extends ConsumerState<_Performance> {
  int _range = 1; // 0=4W 1=3M 2=1Y 3=all
  String? _exId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final all = ref.watch(sessionListProvider).where((s) => filter == null || s.sport == filter).toList();
    final u = ref.watch(profileOrDefaultProvider).units;
    final now = DateTime.now();
    final from = switch (_range) {
      0 => now.subtract(const Duration(days: 28)), // time span
      1 => now.subtract(const Duration(days: 91)), // time span
      2 => now.subtract(const Duration(days: 365)), // time span
      _ => DateTime(2000),
    };
    final s = all.where((x) => x.start.isAfter(from)).toList();
    final totalSec = s.fold<int>(0, (a, x) => a + x.durationSec);
    final dist = s.fold<double>(0, (a, x) => a + x.distanceM);
    final vol = s.fold<double>(0, (a, x) => a + x.volume);
    final minutesByDay = <DateTime, int>{};
    for (final x in all) {
      minutesByDay[dayOnly(x.start)] = (minutesByDay[dayOnly(x.start)] ?? 0) + x.minutes;
    }
    final records = ref.watch(exerciseRecordsProvider).values.toList()..sort((a, b) => b.sessions.compareTo(a.sessions));
    final shownRecords = records.take(25).toList();
    // The selection may drop out of the top 25 (or vanish) when sessions change → fall back to the first.
    final exId = shownRecords.any((r) => r.exId == _exId) ? _exId : shownRecords.firstOrNull?.exId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Segments<int>(
          segments: [Seg(0, label: l.range4w), Seg(1, label: l.range3m), Seg(2, label: l.range1y), Seg(3, label: l.rangeAll)],
          value: _range,
          onChanged: (v) => setState(() => _range = v),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatTile(label: l.sessions, value: '${s.length}', icon: Icons.event_available)),
                  Expanded(child: StatTile(label: l.time, value: humanDuration(totalSec), icon: Icons.timer_outlined)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: StatTile(label: l.distance, value: u.dist(dist, digits: 1), icon: Icons.straighten, color: AppColors.run),
                  ),
                  Expanded(
                    child: StatTile(
                      label: l.volume,
                      value: '${compactNumber(u.weightOut(vol))} ${u.weightUnit}',
                      icon: Icons.fitness_center,
                      color: AppColors.gym,
                    ),
                  ),
                ],
              ),
              if (filter == null || filter == Sport.gym) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(label: l.avgGymDays, value: avgGymDaysPerMonth(all).toStringAsFixed(1), icon: Icons.calendar_month),
                    ),
                    Expanded(
                      child: StatTile(
                        label: l.avgDuration,
                        value: s.isEmpty ? '–' : humanDuration(totalSec ~/ s.length),
                        icon: Icons.av_timer,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(title: l.heatmap, child: TrainingHeatmap(minutesByDay: minutesByDay, color: filter?.color ?? AppColors.brand)),
        const SizedBox(height: 12),
        SectionCard(title: l.weeklyMinutes, child: SizedBox(height: 180, child: _WeeklyBars(sessions: all, filter: filter))),
        const SizedBox(height: 12),
        const FitnessFormCard(),
        if (records.isNotEmpty && (filter == null || filter == Sport.gym)) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: l.strengthProgress,
            trailing: DropdownButton<String>(
              value: exId,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final r in shownRecords)
                  DropdownMenuItem(
                    value: r.exId,
                    child: SizedBox(
                      width: 150,
                      child: Text(capFirst(r.name), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _exId = v),
            ),
            child: SizedBox(height: 170, child: _E1rmChart(points: e1rmHistory(all, exId ?? ''), units: u)),
          ),
        ],
        if (filter != null && filter != Sport.gym) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: l.weeklyDistance,
            child: SizedBox(height: 170, child: _WeeklyDistance(sessions: all, sport: filter, units: u)),
          ),
        ],
        const SizedBox(height: 12),
        const BodyCompositionCard(),
      ],
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.sessions, required this.filter});
  final List<Session> sessions;
  final Sport? filter;

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    final start = addDays(startOfWeek(DateTime.now()), -(7 * (weeks - 1)));
    final data = List.generate(weeks, (_) => {for (final s in Sport.values) s: 0.0});
    for (final s in sessions) {
      final i = daysBetween(start, startOfWeek(s.start)) ~/ 7;
      if (i >= 0 && i < weeks) data[i][s.sport] = data[i][s.sport]! + s.minutes;
    }
    final maxY = data.map((m) => m.values.fold(0.0, (a, b) => a + b)).fold(0.0, max);
    return BarChart(
      BarChartData(
        maxY: max(60, maxY * 1.15),
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
              getTitlesWidget:
                  (v, _) =>
                      v.toInt() % 3 != 2
                          ? const SizedBox.shrink()
                          : Text(
                            DateFormat.Md(context.localeName).format(addDays(start, 7 * v.toInt())),
                            style: const TextStyle(fontSize: 9),
                          ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weeks; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].values.fold(0.0, (a, b) => a + b),
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                  rodStackItems: () {
                    var acc = 0.0;
                    return [
                      for (final s in Sport.values)
                        if (data[i][s]! > 0) BarChartRodStackItem(acc, acc += data[i][s]!, s.color),
                    ];
                  }(),
                  color: Colors.transparent,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeeklyDistance extends StatelessWidget {
  const _WeeklyDistance({required this.sessions, required this.sport, required this.units});
  final List<Session> sessions;
  final Sport sport;
  final Units units;

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    final start = addDays(startOfWeek(DateTime.now()), -(7 * (weeks - 1)));
    final data = List.filled(weeks, 0.0);
    for (final s in sessions.where((s) => s.sport == sport)) {
      final i = daysBetween(start, startOfWeek(s.start)) ~/ 7;
      if (i >= 0 && i < weeks) data[i] += units.distOut(s.distanceM);
    }
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
          bottomTitles: AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
        ),
        barGroups: [
          for (var i = 0; i < weeks; i++)
            BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: data[i], color: sport.color, width: 12, borderRadius: BorderRadius.circular(4))],
            ),
        ],
      ),
    );
  }
}

class _E1rmChart extends StatelessWidget {
  const _E1rmChart({required this.points, required this.units});
  final List<(DateTime, double)> points;
  final Units units;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return Center(child: Text(context.l10n.notEnoughData, style: Theme.of(context).textTheme.bodySmall));
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
          bottomTitles: AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), units.weightOut(points[i].$2).roundToDouble())],
            isCurved: true,
            color: AppColors.gym,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: AppColors.gym.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Records ─────────────────────────────

class _Records extends ConsumerWidget {
  const _Records();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final all = ref.watch(sessionListProvider);
    final u = ref.watch(profileOrDefaultProvider).units;
    final g = ref.watch(gameStatsProvider);
    final db = ref.watch(exerciseDbProvider).value;
    final recs =
        ref.watch(exerciseRecordsProvider).values.where((r) => r.exId != 'manual').toList()
          ..sort((a, b) => b.bestE1rm.compareTo(a.bestE1rm));

    Session? best(Sport s, double Function(Session) f) {
      final list = all.where((x) => x.sport == s && x.distanceM > 0).toList();
      if (list.isEmpty) return null;
      list.sort((a, b) => f(b).compareTo(f(a)));
      return list.first;
    }

    Widget sportRecords(Sport s) {
      final longest = best(s, (x) => x.distanceM);
      final longestTime = best(s, (x) => x.durationSec.toDouble());
      final fastest = best(s, (x) => x.distanceM >= (s == Sport.swim ? 400 : 5000) ? x.distanceM / x.durationSec : 0);
      final total = all.where((x) => x.sport == s).fold<double>(0, (a, x) => a + x.distanceM);
      if (longest == null) return const SizedBox.shrink();
      String d(double m) => s == Sport.swim ? u.swimDist(m) : u.dist(m, digits: 1);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SectionCard(
          title: s.label(l),
          trailing: Icon(s.icon, color: s.color),
          child: Wrap(
            runSpacing: 14,
            children: [
              _half(context, StatTile(label: l.longestDistance, value: d(longest.distanceM), color: s.color)),
              _half(context, StatTile(label: l.longestDuration, value: humanDuration(longestTime!.durationSec))),
              if (fastest != null && fastest.distanceM >= (s == Sport.swim ? 400 : 5000))
                _half(
                  context,
                  StatTile(label: s.usesPace ? l.bestPace : l.bestSpeed, value: u.paceOrSpeed(s, fastest.distanceM, fastest.durationSec)),
                ),
              _half(context, StatTile(label: l.totalDistance, value: d(total))),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (filter == null || filter == Sport.gym)
          SectionCard(
            title: l.strengthRecords,
            trailing: const TermInfoButton(Term.e1rm),
            child:
                recs.isEmpty
                    ? Text(l.noRecordsYet, style: Theme.of(context).textTheme.bodySmall)
                    : Column(
                      children: [
                        for (final r in recs.take(15))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.emoji_events_outlined, color: AppColors.gym),
                            title: Text(capFirst(r.name), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${l.maxWeight} ${u.weight(r.maxWeight)} · ${DateFormat.yMMMd(context.localeName).format(r.date)}',
                            ),
                            trailing: Text('e1RM ${u.weight(r.bestE1rm, digits: 0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () {
                              final e = db?.byId(r.exId);
                              if (e != null) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: e)));
                              }
                            },
                          ),
                      ],
                    ),
          ),
        const SizedBox(height: 12),
        if (filter == null || filter == Sport.run) ...[const RunBestEffortsCard(), const SizedBox(height: 12)],
        for (final s in [Sport.run, Sport.ride, Sport.swim].where((s) => filter == null || filter == s)) sportRecords(s),
        SectionCard(
          title: l.badges,
          trailing: Text('${g.badges.where((b) => b.earned).length}/${g.badges.length}'),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.78,
            children: [for (final b in g.badges) BadgeView(badge: b)],
          ),
        ),
      ],
    );
  }

  Widget _half(BuildContext c, Widget w) => SizedBox(width: (MediaQuery.sizeOf(c).width - 64) / 2, child: w);
}

class BadgeView extends StatelessWidget {
  const BadgeView({super.key, required this.badge});
  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '${badgeTitle(context.l10n, b.def.id)} · ${(b.progress * 100).round()}%',
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: b.progress,
                  strokeWidth: 3,
                  color: b.def.color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: b.earned ? b.def.color.withValues(alpha: 0.25) : scheme.surfaceContainerHigh,
                child: Icon(b.def.icon, color: b.earned ? b.def.color : scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            badgeTitle(context.l10n, b.def.id),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── History ─────────────────────────────

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final list = ref.watch(sessionListProvider).where((s) => filter == null || s.sport == filter).toList();
    final u = ref.watch(profileOrDefaultProvider).units;
    final xp = ref.watch(gameStatsProvider).xpBySession;
    if (list.isEmpty) return EmptyState(icon: Icons.history, text: l.noSessionsYet);
    final df = DateFormat.yMMMEd(context.localeName);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final s = list[i];
        final showMonth = i == 0 || list[i - 1].start.month != s.start.month || list[i - 1].start.year != s.start.year;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showMonth)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(DateFormat.yMMMM(context.localeName).format(s.start), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: SportBadge(s.sport),
                  title: Text(glueTitle(s.title), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      df.format(s.start),
                      humanDuration(s.durationSec),
                      if (s.sport == Sport.gym && s.volume > 0) u.weight(s.volume, digits: 0),
                      if (s.distanceM > 0) s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM, digits: 1),
                    ].join(' · '),
                  ),
                  trailing: Text('+${xp[s.id] ?? 0}', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id))),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
