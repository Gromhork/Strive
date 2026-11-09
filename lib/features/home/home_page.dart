import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../services/compliance.dart';
import '../../services/insights.dart';
import '../../widgets/common.dart';
import '../profile/health_connect_page.dart';
import '../shell/health_sync.dart';
import 'weather_page.dart';
import 'week_page.dart';
import '../profile/profile_page.dart';
import '../calendar/plan_editor.dart';
import '../calendar/planned_workout_page.dart';
import '../session/step_list.dart';
import '../goals/goals_page.dart';
import '../session/start_helpers.dart';
import '../stats/body_page.dart';
import '../stats/session_detail_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(weatherProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [
          _Greeting(),
          SizedBox(height: 12),
          _TodayCard(),
          SizedBox(height: 12),
          _ComingUp(),
          SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: WeatherCard()), SizedBox(width: 12), Expanded(child: _WeekCard())],
            ),
          ),
          SizedBox(height: 12),
          _VitalsCard(),
          _RecoveryCard(),
          SizedBox(height: 12),
          _WeightCard(),
          SizedBox(height: 12),
          _GoalsPreview(),
          SizedBox(height: 12),
          _LevelCard(),
        ],
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final h = DateTime.now().hour;
    final hello = h < 11 ? l.goodMorning : (h < 18 ? l.goodAfternoon : l.goodEvening);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.MMMMEEEEd(context.localeName).format(DateTime.now()),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        Text(
          '$hello${p.name.isEmpty ? '' : ', ${p.name.split(' ').first}'}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ───────────────────────────── Today ─────────────────────────────

class _TodayCard extends ConsumerStatefulWidget {
  const _TodayCard();
  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final today = dayOnly(DateTime.now());
    final plans = ref.watch(planListProvider).where((p) => sameDay(p.date, today) && (filter == null || p.sport == filter)).toList();
    final doneToday = ref.watch(sessionListProvider).where((s) => sameDay(s.start, today)).toList();
    if (_i >= plans.length) _i = 0;

    if (plans.isEmpty) {
      return SectionCard(
        title: l.todaysWorkout,
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => showPlanEditor(context, ref, date: today),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
              child: Icon(
                doneToday.isEmpty ? Icons.self_improvement_rounded : Icons.check_circle_rounded,
                color: doneToday.isEmpty ? AppColors.brand : AppColors.success,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doneToday.isEmpty ? l.restDay : l.doneToday(doneToday.length),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text(
                    doneToday.isEmpty ? l.restDaySub : doneToday.map((s) => s.title).join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => showQuickStart(context, ref),
              child: Text(l.train),
            ),
          ],
        ),
      );
    }

    final p = plans[_i];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [p.sport.color.withValues(alpha: 0.28), p.sport.color.withValues(alpha: 0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
        child: Row(
          children: [
            if (plans.length <= 1) const SizedBox(width: 8),
            if (plans.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l.previousWorkout,
                onPressed: () => setState(() => _i = (_i - 1) % plans.length),
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: p.id))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l.todaysWorkout, style: Theme.of(context).textTheme.labelMedium),
                        if (plans.length > 1) Text('  ${_i + 1}/${plans.length}', style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SportBadge(p.sport, size: 48, filled: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              Text(
                                [
                                  '${p.durationMin} min',
                                  if (p.distanceKm != null && p.distanceKm! > 0)
                                    ref.watch(profileOrDefaultProvider).units.dist(p.distanceKm! * 1000, digits: 1),
                                  intensityLabel(l, p.intensity),
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (p.steps.isNotEmpty) ...[const SizedBox(height: 10), WorkoutProfileBar(steps: p.steps, sport: p.sport, height: 26)],
                    if (p.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(p.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: p.isDone ? AppColors.success : p.sport.color,
                    foregroundColor: Colors.black87,
                  ),
                  tooltip: l.start,
                  onPressed:
                      p.isDone
                          ? (p.sessionId == null
                              ? null
                              : () =>
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: p.sessionId!))))
                          : () => startPlanned(context, ref, p),
                  icon: Icon(p.isDone ? Icons.check_rounded : Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: l.edit,
                  onPressed: () => showPlanEditor(context, ref, existing: p),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: l.add,
                  onPressed: () => showPlanEditor(context, ref, date: today),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
            if (plans.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l.nextWorkout,
                onPressed: () => setState(() => _i = (_i + 1) % plans.length),
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Coming up ─────────────────────────────

class _ComingUp extends ConsumerWidget {
  const _ComingUp();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plans = ref.watch(planListProvider);
    final filter = ref.watch(sportFilterProvider);
    final today = dayOnly(DateTime.now());
    final fmt = DateFormat.E(context.localeName);
    return SectionCard(
      title: l.comingUp,
      trailing: InkWell(
        onTap: () => ref.read(navIndexProvider.notifier).set(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(l.toCalendar, style: Theme.of(context).textTheme.labelMedium), const Icon(Icons.chevron_right, size: 18)],
        ),
      ),
      child: Row(
        children: [
          for (var i = 1; i <= 6; i++)
            Builder(
              builder: (_) {
                final d = today.add(Duration(days: i));
                final dayPlans = plans.where((p) => sameDay(p.date, d) && (filter == null || p.sport == filter)).toList();
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (dayPlans.isEmpty) {
                        showPlanEditor(context, ref, date: d);
                      } else if (dayPlans.length == 1) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: dayPlans.first.id)));
                      } else {
                        _showDay(context, ref, d, dayPlans);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(fmt.format(d), style: Theme.of(context).textTheme.labelSmall),
                          Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          SizedBox(height: 40, child: Center(child: _DayBadges(plans: dayPlans))),
                          const SizedBox(height: 4),
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Text(
                              dayPlans.isEmpty ? l.rest : (dayPlans.length == 1 ? dayPlans.first.title : l.nWorkouts(dayPlans.length)),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                height: 1.2,
                                fontWeight: dayPlans.length > 1 ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Bottom sheet listing all workouts of a day with several sessions.
  void _showDay(BuildContext context, WidgetRef ref, DateTime d, List<PlannedWorkout> list) {
    final l = context.l10n;
    final u = ref.read(profileOrDefaultProvider).units;
    showModalBottomSheet(
      context: context,
      builder:
          (c) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    DateFormat.MMMMEEEEd(context.localeName).format(d),
                    style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(l.nWorkouts(list.length), style: Theme.of(c).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  for (final (i, p) in list.indexed)
                    Card(
                      child: ListTile(
                        leading: SportBadge(p.sport),
                        title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            l.sessionN(i + 1),
                            '${p.durationMin} min',
                            if (p.distanceKm != null && p.distanceKm! > 0) u.dist(p.distanceKm! * 1000, digits: 1),
                            if (p.isKey) '★',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(c);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: p.id)));
                        },
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      showPlanEditor(context, ref, date: d);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l.planWorkout),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// One badge, or overlapping badges for days with several workouts.
class _DayBadges extends StatelessWidget {
  const _DayBadges({required this.plans});
  final List<PlannedWorkout> plans;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.outline),
      );
    }
    if (plans.length == 1) return SportBadge(plans.first.sport, size: 34);
    final shown = plans.take(2).toList();
    return SizedBox(
      width: 42,
      height: 40,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: SportBadge(shown[0].sport, size: 28)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerLow, width: 2),
              ),
              child: SportBadge(shown[1].sport, size: 28),
            ),
          ),
          if (plans.length > 2)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(8)),
                child: Text('+${plans.length - 2}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Week rings ─────────────────────────────

class _WeekCard extends ConsumerWidget {
  const _WeekCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sessions = ref.watch(sessionListProvider);
    final plans = ref.watch(planListProvider);
    final weekStart = startOfWeek(DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 7));
    bool inWeek(DateTime d) => !d.isBefore(weekStart) && d.isBefore(weekEnd);
    final done = sessions.where((s) => inWeek(s.start)).toList();
    final planned = plans.where((p) => inWeek(p.date)).toList();
    final sports = {...planned.map((p) => p.sport), ...done.map((s) => s.sport)}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final values = <Sport, double>{};
    for (final s in sports) {
      final target = planned.where((p) => p.sport == s).length;
      final d = done.where((x) => x.sport == s).length;
      values[s] = target == 0 ? 1 : d / target;
    }
    final totalSec = done.fold<int>(0, (a, s) => a + s.durationSec);
    final completion = weeklyCompletion(planned, ref.watch(planSessionsProvider));
    return SectionCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeekPage())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.thisWeek, style: Theme.of(context).textTheme.labelMedium)),
              if (completion != null)
                Semantics(
                  label: l.planCompletion((completion * 100).round()),
                  excludeSemantics: true,
                  child: Text(
                    NumberFormat.percentPattern(context.localeName).format(completion),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: completionColor(completion)),
                  ),
                ),
              Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.outline),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SportRings(values: values.isEmpty ? {Sport.gym: 0} : values, size: 74, stroke: 7),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in sports)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(s.icon, size: 13, color: s.color),
                            const SizedBox(width: 4),
                            Text(
                              '${done.where((x) => x.sport == s).length}/${planned.where((p) => p.sport == s).length}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    if (sports.isEmpty) Text('–', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(clock(totalSec), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(l.trainedThisWeek, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in Sport.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => quickStart(context, ref, s),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(color: s.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Icon(s.icon, size: 17, color: s.color),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Recovery ─────────────────────────────

class _RecoveryCard extends ConsumerWidget {
  const _RecoveryCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = ref.watch(recoveryProvider);
    if (ref.watch(sessionListProvider).isEmpty) return const SizedBox.shrink();
    final (color, icon, title, text) = switch (r.readiness) {
      Readiness.building => (AppColors.brand, Icons.insights_rounded, l.readyBuilding, l.readyBuildingText),
      Readiness.fresh => (AppColors.swim, Icons.battery_full_rounded, l.readyFresh, l.readyFreshText),
      Readiness.optimal => (AppColors.success, Icons.check_circle_outline, l.readyOptimal, l.readyOptimalText),
      Readiness.high => (AppColors.warning, Icons.warning_amber_rounded, l.readyHigh, l.readyHighText),
      Readiness.overreaching => (AppColors.danger, Icons.hotel_rounded, l.readyOver, l.readyOverText),
    };
    return SectionCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryPage())),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    const Spacer(),
                    if (r.readiness != Readiness.building)
                      Text('ACWR ${r.ratio.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Weight ─────────────────────────────

class _WeightCard extends ConsumerStatefulWidget {
  const _WeightCard();
  @override
  ConsumerState<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends ConsumerState<_WeightCard> {
  /// Value shown while +/- taps are being collected; written after [_debounce] of no taps.
  double? _pending;
  Timer? _timer;
  static const _debounce = Duration(milliseconds: 800);

  @override
  void dispose() {
    // Don't lose the last taps when the page goes away.
    _timer?.cancel();
    _flush();
    super.dispose();
  }

  /// Captured at tap time so the write needs no `ref` (also safe from [dispose]).
  void Function()? _write;

  void _flush() {
    _write?.call();
    _write = null;
  }

  static void _save(Repository repo, List<BodyEntry> body, UserProfile profile, double kg) {
    final today = body.where((b) => sameDay(b.date, DateTime.now())).firstOrNull;
    repo.saveBody(
      BodyEntry(
        id: today?.id ?? repo.newId(),
        date: DateTime.now(),
        weightKg: double.parse(kg.toStringAsFixed(2)),
        fatPct: today?.fatPct,
        musclePct: today?.musclePct,
      ),
    );
    repo.saveProfile(profile.copyWith(weightKg: kg));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = ref.watch(bodyProvider).value ?? const [];
    final profile = ref.watch(profileOrDefaultProvider);
    final u = profile.units;
    final current = _pending ?? (body.isNotEmpty ? body.last.weightKg : profile.weightKg);
    final recent = body.where((b) => DateTime.now().difference(b.date).inDays <= 90).toList();
    final yRange = paddedRange([for (final b in recent) u.weightOut(b.weightKg)], minSpan: u.weightOut(3));
    final delta = recent.length >= 2 ? recent.last.weightKg - recent.first.weightKg : null;

    void log(double kg) {
      final repo = ref.read(repoProvider);
      if (repo == null) return;
      _write = () => _save(repo, body, profile, kg);
      setState(() => _pending = kg);
      _timer?.cancel();
      _timer = Timer(_debounce, () {
        _flush();
        // Firestore reports local writes immediately, so the stream already shows the new value.
        if (mounted) setState(() => _pending = null);
      });
    }

    final step = u.imperial ? Units.kgPerLb * 0.2 : 0.1;
    return SectionCard(
      title: l.weight,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyPage())),
      trailing:
          delta == null
              ? null
              : Text(
                '${delta >= 0 ? '+' : ''}${Units.num(u.weightOut(delta))} ${u.weightUnit} · 90d',
                style: Theme.of(context).textTheme.labelSmall,
              ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 70,
              child:
                  recent.length < 2
                      ? Center(child: Text(l.weightLogHint, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center))
                      : LineChart(
                        LineChartData(
                          // Keep at least ±1.5 kg of headroom so 0.1 kg noise doesn't look like a swing.
                          minY: yRange.$1,
                          maxY: yRange.$2,
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [for (final b in recent) FlSpot(b.date.millisecondsSinceEpoch.toDouble(), u.weightOut(b.weightKg))],
                              isCurved: recent.length > 2,
                              preventCurveOverShooting: true,
                              curveSmoothness: 0.2,
                              color: AppColors.brand,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: true, color: AppColors.brand.withValues(alpha: 0.12)),
                            ),
                          ],
                        ),
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(u.weight(current), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Row(
                children: [
                  IconButton.filledTonal(tooltip: l.weightMinus, onPressed: () => log(current - step), icon: const Icon(Icons.remove)),
                  IconButton.filledTonal(tooltip: l.weightPlus, onPressed: () => log(current + step), icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Goals ─────────────────────────────

class _GoalsPreview extends ConsumerWidget {
  const _GoalsPreview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goals = ref.watch(goalsProvider).value ?? const [];
    return SectionCard(
      title: l.goals,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())),
      trailing: const Icon(Icons.chevron_right, size: 18),
      child:
          goals.isEmpty
              ? Text(l.noGoalsYet, style: Theme.of(context).textTheme.bodySmall)
              : Column(children: [for (final g in goals.take(3)) GoalTile(goal: g, compact: true)]),
    );
  }
}

// ───────────────────────────── Level ─────────────────────────────

class _LevelCard extends ConsumerWidget {
  const _LevelCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final g = ref.watch(gameStatsProvider);
    return SectionCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(l.levelN(g.level.level), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text('${g.totalXp} XP', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: g.level.progress, minHeight: 8, color: AppColors.brand),
          ),
          const SizedBox(height: 6),
          Text(l.xpToNext(g.level.remaining), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in Sport.values)
                Expanded(
                  child: Row(
                    children: [
                      Icon(s.icon, size: 16, color: s.color),
                      const SizedBox(width: 4),
                      Text('Lv ${g.sportLevels[s]!.level}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Watch vitals (Health Connect) ─────────────────────────────

class _VitalsCard extends ConsumerWidget {
  const _VitalsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(vitalsProvider).value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    Widget item(IconData i, Color c, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(i, color: c, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthConnectPage())),
        child: Row(
          children: [
            item(Icons.directions_walk_rounded, AppColors.run, v.steps == null ? '–' : compactNumber(v.steps!.toDouble()), l.steps),
            item(Icons.favorite_rounded, AppColors.danger, v.restingHr == null ? '–' : '${v.restingHr}', l.restingHr),
            item(Icons.bedtime_rounded, AppColors.brand, v.sleepMin == null ? '–' : humanDuration(v.sleepMin! * 60), l.sleep),
            item(Icons.monitor_heart_outlined, AppColors.swim, v.hrv == null ? '–' : '${v.hrv!.round()} ms', 'HRV'),
          ],
        ),
      ),
    );
  }
}
