import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/compliance.dart';
import '../../services/insights.dart';
import '../../widgets/common.dart';
import '../../widgets/plan_amount.dart';
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
    ref.watch(todayProvider); // "today" changes at midnight
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final end = addDays(_week, 7);
    bool inWeek(DateTime d) => !d.isBefore(_week) && d.isBefore(end);
    final sessions = ref.watch(sessionListProvider).where((s) => inWeek(s.start)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final plans = ref.watch(planListProvider).where((p) => inWeek(p.date)).toList();
    final sports = {...plans.map((p) => p.sport), ...sessions.map((s) => s.sport)}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final df = DateFormat.MMMd(context.localeName);
    final thisWeek = sameDay(_week, startOfWeek(DateTime.now()));
    final totalSec = sessions.fold<int>(0, (a, s) => a + s.durationSec);
    final totalKm = sessions.fold<double>(0, (a, s) => a + s.distanceM) / 1000;
    final linked = ref.watch(planSessionsProvider);
    // One definition everywhere: planned workouts (not dropped) completed by a session or
    // marked done – the total and the per-sport rows add up.
    final counts = planCounts(plans, linked, profile: ref.watch(profileOrDefaultProvider));
    final completion = weeklyCompletion(plans, linked, profile: ref.watch(profileOrDefaultProvider));

    return Scaffold(
      appBar: AppBar(title: Text(l.thisWeek)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _week = addDays(_week, -7))),
              Expanded(
                child: Text(
                  '${df.format(_week)} – ${df.format(addDays(end, -1))}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: thisWeek ? null : () => setState(() => _week = addDays(_week, 7)),
              ),
            ],
          ),
          if (completion != null) ...[_CompletionBar(share: completion), const SizedBox(height: 12)],
          Row(
            children: [
              Expanded(child: StatTile(label: l.duration, value: humanDuration(totalSec))),
              const SizedBox(width: 10),
              // A pure strength week shows its volume, not "0 km".
              Expanded(
                child:
                    sessions.any((s) => s.sport != Sport.gym) || plans.any((p) => p.sport != Sport.gym)
                        ? StatTile(label: l.distance, value: '${Units.num(u.distOut(totalKm * 1000), 1)} ${u.distUnit}')
                        : StatTile(
                          label: l.volume,
                          value: u.volume(sessions.fold<double>(0, (a, s) => a + s.volume)),
                          caption: sessions.any((s) => s.volumeCountsBody) ? l.volumeInclBody : null,
                        ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  key: const ValueKey('weekDoneCount'),
                  label: l.workoutsDone,
                  value: counts.planned == 0 ? '–' : '${counts.done}/${counts.planned}',
                ),
              ),
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
                        linked: linked,
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
                    day: addDays(_week, i),
                    plans: plans.where((p) => sameDay(p.date, addDays(_week, i))).toList(),
                    linked: linked,
                    // Sessions not fulfilling a plan of that day (incl. ones started from a workout days away).
                    sessions:
                        sessions
                            .where(
                              (s) =>
                                  sameDay(s.start, addDays(_week, i)) &&
                                  !plans.any((p) => sameDay(p.date, s.start) && linked[p.id]?.id == s.id),
                            )
                            .toList(),
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

class _SportRow extends ConsumerWidget {
  const _SportRow({required this.sport, required this.done, required this.planned, required this.linked, required this.units});
  final Sport sport;
  final List<Session> done;
  final List<PlannedWorkout> planned;
  final Map<String, Session> linked;
  final Units units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sec = done.fold<int>(0, (a, s) => a + s.durationSec);
    final km = done.fold<double>(0, (a, s) => a + s.distanceM);
    final profile = ref.watch(profileOrDefaultProvider);
    // The week's planned km as the session cards show them ([planAmount] – a run/walk with its walks).
    final planKm = planned.fold<double>(0, (a, p) => a + (planAmount(p, profile).km ?? 0));
    final c = planCounts(planned, linked, profile: profile);
    final extra = extraSessions(done, planned, linked);
    final target = c.planned;
    final progress = target == 0 ? (done.isEmpty ? 0.0 : 1.0) : (c.done / target).clamp(0.0, 1.0);
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
                  Text(
                    [
                      if (target > 0) '${c.done}/$target' else '${done.length}',
                      if (target > 0 && extra > 0) l.extraSessionsN(extra),
                    ].join(' '),
                    key: ValueKey('sportCount_${sport.name}'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    [
                      humanDuration(sec),
                      if (sport != Sport.gym && (km > 0 || planKm > 0))
                        planKm > 0
                            ? '${Units.num(units.distOut(km), 1)} / ${Units.num(units.distOut(planKm * 1000), 1)} ${units.distUnit}'
                            : '${Units.num(units.distOut(km), 1)} ${units.distUnit}',
                    ].join(' · '),
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

class _DayRow extends ConsumerWidget {
  const _DayRow({required this.day, required this.plans, required this.linked, required this.sessions, required this.units});
  final DateTime day;
  final List<PlannedWorkout> plans;
  final Map<String, Session> linked;
  final List<Session> sessions;
  final Units units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(profileOrDefaultProvider);
    final templates = ref.watch(templateListProvider);
    final today = sameDay(day, DateTime.now());
    final items = <Widget>[
      for (final p in plans)
        _Item(
          sport: p.sport,
          title: p.title,
          sub: planAmountText(p, profile, templates: templates),

          compliance: planCompliance(p, linked[p.id], profile: profile),
          skipped: p.status == 'skipped',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: p.id))),
        ),
      for (final s in sessions)
        _Item(
          sport: s.sport,
          title: s.title,
          sub: [
            humanDuration(s.durationSec),
            if (s.sport == Sport.gym && s.setsDone > 0) l.setsN(s.setsDone),
            if (s.distanceM > 0) s.sport == Sport.swim ? units.swimDist(s.distanceM) : units.dist(s.distanceM, digits: 1),
          ].join(' · '),
          compliance: const Compliance(ComplianceLevel.green),
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

class _Item extends StatelessWidget {
  const _Item({
    required this.sport,
    required this.title,
    required this.sub,
    required this.compliance,
    this.skipped = false,
    required this.onTap,
  });
  final Sport sport;
  final String title;
  final String sub;
  final Compliance compliance;
  final bool skipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: sport.color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            compliance.level == ComplianceLevel.none
                ? BorderSide.none
                : BorderSide(color: compliance.color(context).withValues(alpha: 0.55)),
      ),
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
              ComplianceRing(compliance: compliance, skipped: skipped),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Weekly plan completion (weighted by planned minutes).
class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.share});
  final double share;

  @override
  Widget build(BuildContext context) {
    // Says what it measures: the due planned minutes – not the number of workouts above.
    final text = context.l10n.planCompletionMinutes((share * 100).round());
    final color = completionColor(share);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
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
                  Text('ACWR ${Units.fixed(r.ratio, 2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
