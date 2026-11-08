import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../stats/session_detail_page.dart';
import 'plan_editor.dart';
import 'planned_workout_page.dart';
import '../../widgets/segments.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  bool _month = false;
  DateTime _focused = dayOnly(DateTime.now());
  DateTime _selected = dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'addPlan',
        onPressed: () => showPlanEditor(context, ref, date: _month ? _selected : DateTime.now()),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: _exportIcs,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(l.syncCalendar, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: l.generatePlan,
                  onPressed: () => showPlanGenerator(context, ref),
                  icon: const Icon(Icons.auto_fix_high_rounded),
                ),
                const SizedBox(width: 4),
                Segments<bool>(
                  dense: true,
                  segments: [Seg(false, icon: Icons.view_agenda_outlined), Seg(true, icon: Icons.calendar_view_month)],
                  value: _month,
                  onChanged: (v) => setState(() => _month = v),
                ),
              ],
            ),
          ),
          Expanded(child: _month ? _monthView() : _weekList()),
        ],
      ),
    );
  }

  List<PlannedWorkout> _plans() {
    final f = ref.watch(sportFilterProvider);
    return ref.watch(planListProvider).where((p) => f == null || p.sport == f).toList();
  }

  List<Session> _sessions() {
    final f = ref.watch(sportFilterProvider);
    return ref.watch(sessionListProvider).where((s) => f == null || s.sport == f).toList();
  }

  // ── Week list with drag & drop between days
  Widget _weekList() {
    final l = context.l10n;
    final plans = _plans();
    final sessions = _sessions();
    final thisWeek = startOfWeek(DateTime.now());
    final df = DateFormat.MMMd(context.localeName);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: 8, // current week … 7 weeks ahead
      itemBuilder: (_, w) {
        final week = thisWeek.add(Duration(days: 7 * w));
        final label = w == 0 ? l.currentWeek : (w == 1 ? l.nextWeek : null);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            title: '${df.format(week)} – ${df.format(week.add(const Duration(days: 6)))}',
            trailing: label == null ? null : Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.brand)),
            child: Column(
              children: [for (var d = 0; d < 7; d++) _DayRow(day: week.add(Duration(days: d)), plans: plans, sessions: sessions)],
            ),
          ),
        );
      },
    );
  }

  // ── Month grid
  Widget _monthView() {
    final l = context.l10n;
    final plans = _plans();
    final sessions = _sessions();
    final first = DateTime(_focused.year, _focused.month, 1);
    final gridStart = startOfWeek(first);
    final names = DateFormat.E(context.localeName);
    final dayPlans = plans.where((p) => sameDay(p.date, _selected)).toList();
    final daySessions = sessions.where((s) => sameDay(s.start, _selected)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _focused = DateTime(_focused.year, _focused.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM(context.localeName).format(_focused),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _focused = DateTime(_focused.year, _focused.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(child: Text(names.format(gridStart.add(Duration(days: i))), style: Theme.of(context).textTheme.labelSmall)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < 6; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Builder(
                  builder: (_) {
                    final day = gridStart.add(Duration(days: w * 7 + d));
                    final inMonth = day.month == _focused.month;
                    final p = plans.where((x) => sameDay(x.date, day)).toList();
                    final s = sessions.where((x) => sameDay(x.start, day)).toList();
                    final sel = sameDay(day, _selected);
                    final today = sameDay(day, DateTime.now());
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = day),
                        child: Container(
                          height: 54,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.brand.withValues(alpha: 0.22) : null,
                            borderRadius: BorderRadius.circular(12),
                            border: today ? Border.all(color: AppColors.brand) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                                  color: inMonth ? null : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final x in {...s.map((e) => e.sport)})
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(color: x.color, shape: BoxShape.circle),
                                    ),
                                  for (final x in p.where((e) => !e.isDone).map((e) => e.sport).toSet())
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: x.color, width: 1.5)),
                                    ),
                                ],
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
        const SizedBox(height: 12),
        Text(DateFormat.yMMMMEEEEd(context.localeName).format(_selected), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (dayPlans.isEmpty && daySessions.isEmpty) Text(l.nothingPlanned, style: Theme.of(context).textTheme.bodySmall),
        for (final s in daySessions) _SessionChip(session: s),
        for (final p in dayPlans.where((p) => !p.isDone)) Padding(padding: const EdgeInsets.only(bottom: 6), child: PlanCard(plan: p)),
      ],
    );
  }

  Future<void> _exportIcs() async {
    final l = context.l10n;
    final plans = ref.read(planListProvider).where((p) => !p.date.isBefore(dayOnly(DateTime.now()))).toList();
    if (plans.isEmpty) {
      toast(context, l.nothingToExport);
      return;
    }
    final stamp = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());
    String esc(String s) => s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', '\\n');
    final b = StringBuffer('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Strive//Training//EN\r\nCALSCALE:GREGORIAN\r\n');
    for (final p in plans) {
      final d = DateFormat('yyyyMMdd').format(p.date);
      final end = DateFormat('yyyyMMdd').format(p.date.add(const Duration(days: 1)));
      b.write(
        'BEGIN:VEVENT\r\nUID:${p.id}@strive\r\nDTSTAMP:$stamp\r\nDTSTART;VALUE=DATE:$d\r\nDTEND;VALUE=DATE:$end\r\n'
        'SUMMARY:${esc('${p.sport.label(l)}: ${p.title}')}\r\nDESCRIPTION:${esc('${p.durationMin} min. ${p.description}')}\r\nEND:VEVENT\r\n',
      );
    }
    b.write('END:VCALENDAR\r\n');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(b.toString()), mimeType: 'text/calendar', name: 'strive_plan.ics')],
        fileNameOverrides: ['strive_plan.ics'],
        text: l.icsShareText,
      ),
    );
  }
}

class _DayRow extends ConsumerWidget {
  const _DayRow({required this.day, required this.plans, required this.sessions});
  final DateTime day;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plans.where((x) => sameDay(x.date, day)).toList();
    final s = sessions.where((x) => sameDay(x.start, day) && !p.any((pl) => pl.sessionId == x.id)).toList();
    final today = sameDay(day, DateTime.now());
    return DragTarget<PlannedWorkout>(
      onWillAcceptWithDetails: (d) => !sameDay(d.data.date, day),
      onAcceptWithDetails: (d) => ref.read(repoProvider)!.updatePlan(d.data.id, {'date': dayKey(day), 'status': 'planned'}),
      builder:
          (context, candidates, _) => Container(
            decoration: BoxDecoration(
              color: candidates.isNotEmpty ? AppColors.brand.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    children: [
                      Text(
                        DateFormat.E(context.localeName).format(day),
                        style: TextStyle(fontSize: 11, color: today ? AppColors.brand : Theme.of(context).colorScheme.outline),
                      ),
                      Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w700, color: today ? AppColors.brand : null)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      for (final x in s) _SessionChip(session: x),
                      for (final x in p)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: LongPressDraggable<PlannedWorkout>(
                            data: x,
                            feedback: Material(color: Colors.transparent, child: SizedBox(width: 260, child: PlanCard(plan: x))),
                            childWhenDragging: Opacity(opacity: 0.3, child: PlanCard(plan: x)),
                            child: PlanCard(plan: x),
                          ),
                        ),
                      if (p.isEmpty && s.isEmpty)
                        SizedBox(
                          height: 36,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.l10n.rest,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => showPlanEditor(context, ref, date: day),
                ),
              ],
            ),
          ),
    );
  }
}

class PlanCard extends ConsumerWidget {
  const PlanCard({super.key, required this.plan});
  final PlannedWorkout plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = plan;
    final (icon, color) =
        p.isDone
            ? (Icons.check_circle_rounded, AppColors.success)
            : p.isMissed
            ? (Icons.cancel_outlined, AppColors.danger)
            : (Icons.radio_button_unchecked, Theme.of(context).colorScheme.outline);
    return Material(
      color: p.sport.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: p.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(p.sport.icon, color: p.sport.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: TextStyle(fontWeight: FontWeight.w600, decoration: p.isDone ? TextDecoration.lineThrough : null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        '${p.durationMin} min',
                        if (p.distanceKm != null) '${Units.num(p.distanceKm!)} km',
                        if (p.sport != Sport.gym) intensityLabel(l, p.intensity),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends ConsumerWidget {
  const _SessionChip({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final u = ref.watch(profileOrDefaultProvider).units;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: s.sport.color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(s.sport.icon, color: s.sport.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  s.sport == Sport.gym
                      ? humanDuration(s.durationSec)
                      : (s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM, digits: 1)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
