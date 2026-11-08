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
import '../calendar/planned_workout_page.dart';
import '../stats/fitness_cards.dart';
import '../stats/session_detail_page.dart';

/// Week overview (from the "This week" tile): plan vs. done per sport and per day.
class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({super.key});

  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  DateTime _week = startOfWeek(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final end = _week.add(const Duration(days: 7));
    bool inWeek(DateTime d) => !d.isBefore(_week) && d.isBefore(end);
    final sessions = ref.watch(sessionListProvider).where((s) => inWeek(s.start)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final plans = ref.watch(planListProvider).where((p) => inWeek(p.date)).toList();
    final sports = {...plans.map((p) => p.sport), ...sessions.map((s) => s.sport)}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final df = DateFormat.MMMd(context.localeName);
    final thisWeek = sameDay(_week, startOfWeek(DateTime.now()));
    final totalSec = sessions.fold<int>(0, (a, s) => a + s.durationSec);
    final totalKm = sessions.fold<double>(0, (a, s) => a + s.distanceM) / 1000;
    final doneCount = plans.where((p) => p.isDone).length;

    return Scaffold(
      appBar: AppBar(title: Text(l.thisWeek)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Text(
                  '${df.format(_week)} – ${df.format(end.subtract(const Duration(days: 1)))}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: thisWeek ? null : () => setState(() => _week = _week.add(const Duration(days: 7))),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: StatTile(label: l.duration, value: humanDuration(totalSec))),
              const SizedBox(width: 10),
              Expanded(child: StatTile(label: l.distance, value: '${Units.num(u.distOut(totalKm * 1000), 1)} ${u.distUnit}')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(label: l.planDone, value: plans.isEmpty ? '–' : '$doneCount/${plans.length}')),
            ],
          ),
          const SizedBox(height: 12),
          if (sports.isNotEmpty)
            SectionCard(
              title: l.perSport,
              child: Column(
                children: [
                  for (final s in sports)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _SportRow(
                        sport: s,
                        done: sessions.where((x) => x.sport == s).toList(),
                        planned: plans.where((p) => p.sport == s).toList(),
                        units: u,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.byDay,
            child: Column(
              children: [
                for (var i = 0; i < 7; i++)
                  _DayRow(
                    day: _week.add(Duration(days: i)),
                    plans: plans.where((p) => sameDay(p.date, _week.add(Duration(days: i)))).toList(),
                    sessions: sessions.where((s) => sameDay(s.start, _week.add(Duration(days: i))) && s.planId == null).toList(),
                    units: u,
                  ),
              ],
            ),
          ),
          if (thisWeek) ...[const SizedBox(height: 12), const FitnessFormCard()],
        ],
      ),
    );
  }
}

class _SportRow extends StatelessWidget {
  const _SportRow({required this.sport, required this.done, required this.planned, required this.units});
  final Sport sport;
  final List<Session> done;
  final List<PlannedWorkout> planned;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final sec = done.fold<int>(0, (a, s) => a + s.durationSec);
    final km = done.fold<double>(0, (a, s) => a + s.distanceM);
    final planKm = planned.fold<double>(0, (a, p) => a + (p.distanceKm ?? 0));
    final target = planned.length;
    final progress = target == 0 ? (done.isEmpty ? 0.0 : 1.0) : (done.length / target).clamp(0.0, 1.0);
    return Row(
      children: [
        SportBadge(sport, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${done.length}${target > 0 ? '/$target' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    [
                      humanDuration(sec),
                      if (sport != Sport.gym && km > 0) '${Units.num(units.distOut(km), 1)} ${units.distUnit}',
                      if (sport != Sport.gym && planKm > 0) '/ ${Units.num(units.distOut(planKm * 1000), 1)}',
                    ].join(' '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: sport.color,
                  backgroundColor: sport.color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.plans, required this.sessions, required this.units});
  final DateTime day;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = sameDay(day, DateTime.now());
    final items = <Widget>[
      for (final p in plans)
        _Item(
          sport: p.sport,
          title: p.title,
          sub: [if (p.durationMin > 0) '${p.durationMin} min', if (p.distanceKm != null) '${Units.num(p.distanceKm!)} km'].join(' · '),
          status: p.isDone ? _Status.done : (p.isMissed ? _Status.missed : _Status.planned),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: p.id))),
        ),
      for (final s in sessions)
        _Item(
          sport: s.sport,
          title: s.title,
          sub: [
            humanDuration(s.durationSec),
            if (s.distanceM > 0) '${Units.num(units.distOut(s.distanceM), 1)} ${units.distUnit}',
          ].join(' · '),
          status: _Status.done,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id))),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(DateFormat.E(context.localeName).format(day), style: Theme.of(context).textTheme.labelSmall),
                Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: today ? AppColors.brand : null)),
              ],
            ),
          ),
          Expanded(
            child:
                items.isEmpty
                    ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.rest, style: Theme.of(context).textTheme.bodySmall))
                    : Column(children: items),
          ),
        ],
      ),
    );
  }
}

enum _Status { planned, done, missed }

class _Item extends StatelessWidget {
  const _Item({required this.sport, required this.title, required this.sub, required this.status, required this.onTap});
  final Sport sport;
  final String title;
  final String sub;
  final _Status status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: sport.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(sport.icon, size: 18, color: sport.color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sub.isNotEmpty) Text(sub, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                switch (status) {
                  _Status.done => Icons.check_circle_rounded,
                  _Status.missed => Icons.cancel_outlined,
                  _Status.planned => Icons.radio_button_unchecked,
                },
                size: 20,
                color: switch (status) {
                  _Status.done => AppColors.success,
                  _Status.missed => AppColors.danger,
                  _Status.planned => Theme.of(context).colorScheme.outline,
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Readiness / training-load explanation (from the recovery tile).
class RecoveryPage extends ConsumerWidget {
  const RecoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = ref.watch(recoveryProvider);
    final (color, title, text) = switch (r.readiness) {
      Readiness.building => (AppColors.brand, l.readyBuilding, l.readyBuildingText),
      Readiness.fresh => (AppColors.swim, l.readyFresh, l.readyFreshText),
      Readiness.optimal => (AppColors.success, l.readyOptimal, l.readyOptimalText),
      Readiness.high => (AppColors.warning, l.readyHigh, l.readyHighText),
      Readiness.overreaching => (AppColors.danger, l.readyOver, l.readyOverText),
    };
    final ratio = r.ratio.clamp(0.0, 2.0);
    return Scaffold(
      appBar: AppBar(title: Text(l.recoveryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
                const SizedBox(height: 6),
                Text(text),
                if (r.readiness != Readiness.building) ...[
                  const SizedBox(height: 16),
                  Text('ACWR ${r.ratio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _AcwrBar(value: ratio),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile(label: l.load7d, value: r.acute.round().toString())),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(label: l.load28d, value: r.chronic.round().toString())),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(label: l.daysInARow, value: '${r.daysSinceRest}')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const FitnessFormCard(),
          const SizedBox(height: 12),
          SectionCard(title: l.recoveryHowTitle, child: Text(l.recoveryHowText, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 0 … 2 scale with the sweet spot 0.8–1.3 highlighted (Gabbett 2016).
class _AcwrBar extends StatelessWidget {
  const _AcwrBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        double x(double v) => w * v / 2;
        return SizedBox(
          height: 34,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                height: 10,
                child: Row(
                  children: [
                    Expanded(flex: 8, child: Container(color: AppColors.swim.withValues(alpha: 0.5))),
                    Expanded(flex: 5, child: Container(color: AppColors.success.withValues(alpha: 0.7))),
                    Expanded(flex: 2, child: Container(color: AppColors.warning.withValues(alpha: 0.7))),
                    Expanded(flex: 5, child: Container(color: AppColors.danger.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Positioned(
                left: (x(value) - 7).clamp(0, w - 14),
                top: 2,
                child: Container(
                  width: 14,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
              Positioned(left: x(0.8) - 10, top: 22, child: const Text('0.8', style: TextStyle(fontSize: 10))),
              Positioned(left: x(1.3) - 10, top: 22, child: const Text('1.3', style: TextStyle(fontSize: 10))),
            ],
          ),
        );
      },
    );
  }
}
