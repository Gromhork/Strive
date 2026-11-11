import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/plan_log.dart';
import '../../providers.dart';
import '../../services/compliance.dart';
import '../../services/plan_generator.dart';
import '../../widgets/common.dart';
import '../../widgets/plan_amount.dart';
import '../stats/session_detail_page.dart';
import 'feasibility_card.dart';
import 'plan_editor.dart';
import 'plan_history_page.dart';
import 'planned_workout_page.dart';
import 'recalibrate_sheet.dart';
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
  final _feasibility = FeasibilityCache();
  bool _hideFeasibility = false;

  /// Feasibility of the event goal for the generated plan leading to it: checked from the
  /// plan's first week (the plan's own start), not from today.
  PlanFeasibility _goalCheck() {
    final profile = ref.watch(profileOrDefaultProvider);
    final event = profile.athlete.eventDate;
    if (_hideFeasibility || event == null || profile.athlete.eventDistance == null) return const PlanFeasibility();
    final race = dayOnly(event);
    if (race.isBefore(dayOnly(DateTime.now()))) return const PlanFeasibility();
    final earliest = addDays(race, -(7 * 30));
    DateTime? start;
    for (final p in ref.watch(planListProvider)) {
      if (p.phase == null || p.date.isAfter(race) || p.date.isBefore(earliest)) continue;
      if (start == null || p.date.isBefore(start)) start = p.date;
    }
    return start == null ? const PlanFeasibility() : _feasibility.of(profile, start, context.l10n);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(todayProvider); // "today" / missed workouts change at midnight
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
                // Focus of the page: adapt the coming sessions to the training done so far.
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('recalibrate'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: () => showRecalibration(context, ref),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                    // Scales down instead of cutting the label off on narrow phones.
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.recalButton, maxLines: 1)),
                  ),
                ),
                // Secondary: a whole new plan, calendar export.
                PopupMenuButton<String>(
                  key: const ValueKey('calendarMore'),
                  tooltip: l.recalMore,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected:
                      (v) => switch (v) {
                        'new' => showPlanGenerator(context, ref),
                        'history' => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanHistoryPage())),
                        _ => _exportIcs(),
                      },
                  itemBuilder:
                      (_) => [
                        PopupMenuItem(
                          value: 'new',
                          child: ListTile(leading: const Icon(Icons.restart_alt_rounded), title: Text(l.recalNewPlan)),
                        ),
                        PopupMenuItem(
                          value: 'history',
                          child: ListTile(leading: const Icon(Icons.history_rounded), title: Text(l.planHistory)),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: ListTile(leading: const Icon(Icons.ios_share_rounded), title: Text(l.syncCalendar)),
                        ),
                      ],
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
          if (!_goalCheck().ok)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FeasibilityCard(_goalCheck(), onClose: () => setState(() => _hideFeasibility = true)),
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

  // ── Week list with drag & drop between days. The current week is the scroll anchor;
  // past weeks (with completed workouts) are above it and revealed by scrolling up.
  static const _pastWeeks = 12;
  final _nowKey = GlobalKey();
  final _lastWeekKey = GlobalKey();

  Widget _weekCard(int w, List<PlannedWorkout> plans, List<Session> sessions, {Key? key}) {
    final l = context.l10n;
    final df = DateFormat.MMMd(context.localeName);
    final week = addDays(startOfWeek(DateTime.now()), 7 * w);
    final end = addDays(week, 7);
    final label = switch (w) {
      0 => l.currentWeek,
      1 => l.nextWeek,
      -1 => l.lastWeek,
      _ => null,
    };
    Widget? trailing;
    if (w < 0) {
      // Past week: completed vs. planned at a glance.
      final weekPlans = plans.where((p) => !p.date.isBefore(week) && p.date.isBefore(end)).toList();
      final planned = weekPlans.length;
      final done =
          planned > 0
              ? weekPlans.where((p) => p.isDone).length
              : sessions.where((s) => !s.start.isBefore(week) && s.start.isBefore(end)).length;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) Text('$label · ', style: Theme.of(context).textTheme.labelMedium),
          const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
          const SizedBox(width: 3),
          Text(planned > 0 ? '$done/$planned' : '$done', style: Theme.of(context).textTheme.labelMedium),
        ],
      );
    } else if (label != null) {
      trailing = Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.brand));
    }
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: w < 0 ? 0.92 : 1,
        child: SectionCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          title: '${df.format(week)} – ${df.format(addDays(week, 6))}',
          trailing: trailing,
          child: Column(children: [for (var d = 0; d < 7; d++) _DayRow(day: addDays(week, d), plans: plans, sessions: sessions)]),
        ),
      ),
    );
  }

  Widget _weekList() {
    final l = context.l10n;
    final plans = _plans();
    final sessions = _sessions();
    // Down to the last week of the plan (at least 8 weeks ahead, at most ~1 year) and up
    // to the plan's first week (at least 12 weeks back).
    final all = ref.watch(planListProvider);
    final thisWeek = startOfWeek(DateTime.now());
    int weeksTo(DateTime d) => (daysBetween(thisWeek, startOfWeek(d)) / 7).round();
    final ahead = all.isEmpty ? 8 : (all.map((p) => weeksTo(p.date)).reduce(max) + 1).clamp(8, 60);
    final back = all.isEmpty ? _pastWeeks : (-all.map((p) => weeksTo(p.date)).reduce(min)).clamp(_pastWeeks, 60);
    return CustomScrollView(
      center: _nowKey,
      slivers: [
        // Grows upwards from the anchor: index 0 = last week.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _weekCard(-(i + 1), plans, sessions, key: i == 0 ? _lastWeekKey : null),
              childCount: back,
            ),
          ),
        ),
        SliverPadding(
          key: _nowKey,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              if (i == 0) {
                return Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    label: Text(l.showPastWeeks),
                    onPressed: () {
                      final c = _lastWeekKey.currentContext;
                      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
                    },
                  ),
                );
              }
              return _weekCard(i - 1, plans, sessions);
            }, childCount: ahead + 1), // hint + current week … last plan week
          ),
        ),
      ],
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
    final now = ref.watch(todayProvider);
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
        // Legend above the grid: below it the add button covered it.
        const _MonthLegend(),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: Center(child: Text(names.format(addDays(gridStart, i)), style: Theme.of(context).textTheme.labelSmall))),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < 6; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Builder(
                  builder: (_) {
                    final day = addDays(gridStart, w * 7 + d);
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
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  height: 1.2,
                                  fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                                  color: inMonth ? null : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Fixed height: the day numbers line up whether a day has dots or not.
                              SizedBox(
                                height: 9,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Done: sessions, plus workouts marked done without a recording.
                                    for (final x in {
                                      ...s.map((e) => e.sport),
                                      ...p.where((e) => e.isDone && e.sessionId == null).map((e) => e.sport),
                                    }.take(4))
                                      Container(
                                        width: 7,
                                        height: 7,
                                        margin: const EdgeInsets.all(1),
                                        decoration: BoxDecoration(color: x.color, shape: BoxShape.circle),
                                      ),
                                    // Open: hollow dot; a day passed without it: × (as in the legend).
                                    for (final x in p.where((e) => e.status == 'planned' && !e.isMissedOn(now)).map((e) => e.sport).toSet())
                                      Container(
                                        width: 7,
                                        height: 7,
                                        margin: const EdgeInsets.all(1),
                                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: x.color, width: 1.5)),
                                      ),
                                    if (p.any((e) => e.status == 'planned' && e.isMissedOn(now)))
                                      const Icon(Icons.close_rounded, key: ValueKey('monthMissed'), size: 9, color: AppColors.danger),
                                  ],
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
        const SizedBox(height: 12),
        Text(DateFormat.yMMMMEEEEd(context.localeName).format(_selected), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (dayPlans.isEmpty && daySessions.isEmpty) Text(l.nothingPlanned, style: Theme.of(context).textTheme.bodySmall),
        for (final s in daySessions) _SessionChip(session: s),
        for (final p in dayPlans.where((p) => !p.isDone || p.sessionId == null))
          Padding(padding: const EdgeInsets.only(bottom: 6), child: PlanCard(plan: p)),
        for (final p in dayPlans.where((p) => p.isDone && p.sessionId != null))
          if (ref.watch(planSessionsProvider)[p.id] case final s? when !sameDay(s.start, p.date)) DoneElsewhereLine(plan: p, session: s),
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
      final end = DateFormat('yyyyMMdd').format(addDays(p.date, 1));
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

/// First day of any plan (the earliest planned workout) – days before it are no rest days.
final planFirstDayProvider = Provider<DateTime?>((ref) {
  DateTime? first;
  for (final p in ref.watch(planListProvider)) {
    if (first == null || p.date.isBefore(first)) first = dayOnly(p.date);
  }
  return first;
});

/// A planned workout that was done on another day, on its own day: "Fahrtspiel · erledigt am
/// Mo" (tap: the session) – the calendar and Home's "Demnächst" show the day the same way.
class DoneElsewhereLine extends StatelessWidget {
  const DoneElsewhereLine({super.key, required this.plan, required this.session});
  final PlannedWorkout plan;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = planCompliance(plan, session);
    final t = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      key: ValueKey('doneElsewhere_${plan.id}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: session.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.check_rounded, size: 16, color: c.color(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${glueTitle(plan.title)} · ${l.doneOnDay(DateFormat.E(context.localeName).format(session.start))}',
                style: t?.copyWith(color: Theme.of(context).colorScheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
    final linked = ref.watch(planSessionsProvider);
    final byId = {for (final x in plans) x.id: x};
    // A workout done on another day (early / late, as a replacement) is shown once: as the
    // session on the day it was done ("ersetzt Sa-Einheit"), not again on its planned day.
    bool doneElsewhere(PlannedWorkout x) => x.isDone && linked[x.id] != null && !sameDay(linked[x.id]!.start, x.date);
    final p = plans.where((x) => sameDay(x.date, day) && !doneElsewhere(x)).toList();
    // … but its own day says where it went ("erledigt am Mo") instead of "Pause".
    final elsewhere = plans.where((x) => sameDay(x.date, day) && doneElsewhere(x)).toList();
    final first = ref.watch(planFirstDayProvider);
    final s = sessions.where((x) => sameDay(x.start, day) && !p.any((pl) => pl.sessionId == x.id || linked[pl.id]?.id == x.id)).toList();
    PlannedWorkout? replaced(Session x) {
      final id = linked.entries.where((e) => e.value.id == x.id).map((e) => e.key).firstOrNull;
      final pl = id == null ? null : byId[id];
      return pl != null && !sameDay(pl.date, x.start) ? pl : null;
    }

    final today = sameDay(day, DateTime.now());
    return DragTarget<PlannedWorkout>(
      onWillAcceptWithDetails: (d) => !sameDay(d.data.date, day) && !d.data.isDone,
      onAcceptWithDetails: (d) => movePlan(context, ref, d.data, day),
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
                      for (final x in s) _SessionChip(session: x, replaces: replaced(x)),
                      for (final x in p)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          // Done workouts stay where they were done (their session is on that day).
                          child:
                              x.isDone
                                  ? PlanCard(plan: x)
                                  : LongPressDraggable<PlannedWorkout>(
                                    data: x,
                                    feedback: Material(color: Colors.transparent, child: SizedBox(width: 260, child: PlanCard(plan: x))),
                                    childWhenDragging: Opacity(opacity: 0.3, child: PlanCard(plan: x)),
                                    child: PlanCard(plan: x),
                                  ),
                        ),
                      for (final x in elsewhere) DoneElsewhereLine(plan: x, session: linked[x.id]!),
                      if (p.isEmpty && s.isEmpty && elsewhere.isEmpty)
                        SizedBox(
                          height: 36,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            // No "Pause" before the plan existed – there was nothing to rest from.
                            child:
                                first == null || day.isBefore(first)
                                    ? const SizedBox.shrink()
                                    : Text(
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
    final profile = ref.watch(profileOrDefaultProvider);
    final c = planCompliance(p, ref.watch(planSessionsProvider)[p.id]);
    return Material(
      color: p.sport.color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: c.level == ComplianceLevel.none ? BorderSide.none : BorderSide(color: c.color(context).withValues(alpha: 0.55)),
      ),
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
                      glueTitle(p.title),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        planAmountText(p, profile, templates: ref.watch(templateListProvider)),
                        if (p.sport != Sport.gym) intensityLabel(l, p.intensity),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ComplianceRing(compliance: c, skipped: p.status == 'skipped'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Moves an open planned workout to [day] by drag & drop – logged in the plan history (with
/// undo there) and undoable right away from the snackbar. Done workouts are not moved.
void movePlan(BuildContext context, WidgetRef ref, PlannedWorkout p, DateTime day) {
  final repo = ref.read(repoProvider);
  if (repo == null || p.isDone || sameDay(p.date, day)) return;
  final l = context.l10n;
  final after = PlannedWorkout.fromMap(p.id, {...p.toMap(), 'date': dayKey(day), 'status': 'planned'});
  repo.updatePlan(p.id, {'date': dayKey(day), 'status': 'planned'});
  repo.logPlanChange(PlanLogEntry.of('move', [(p, after)]));
  undoToast(
    ScaffoldMessenger.of(context),
    text: l.planMoved(p.title, DateFormat.MMMEd(context.localeName).format(day)),
    undoLabel: l.undo,
    icon: Icons.open_with_rounded,
    duration: const Duration(seconds: 6),
    onUndo: () => repo.savePlan(p),
  );
}

class _SessionChip extends ConsumerWidget {
  const _SessionChip({required this.session, this.replaces});
  final Session session;

  /// The planned workout of another day this session fulfils.
  final PlannedWorkout? replaces;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        glueTitle(s.title),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (replaces != null)
                        Text(
                          context.l10n.replacesDayWorkout(DateFormat.E(context.localeName).format(replaces!.date)),
                          key: const ValueKey('replacesLabel'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
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

/// What the dots and check colours of the calendar mean.
class _MonthLegend extends StatelessWidget {
  const _MonthLegend();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme.bodySmall;
    final outline = Theme.of(context).colorScheme.outline;
    Widget dot({required bool filled, required Color color}) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
    Widget item(Widget mark, String text) =>
        Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: 4), Text(text, style: t)]);
    return Wrap(
      key: const ValueKey('monthLegend'),
      spacing: 12,
      runSpacing: 4,
      children: [
        item(dot(filled: true, color: outline), l.legendDone),
        item(dot(filled: false, color: outline), l.legendPlanned),
        item(const Icon(Icons.check_rounded, size: 14, color: AppColors.success), l.legendOnTarget),
        item(const Icon(Icons.check_rounded, size: 14, color: complianceYellow), l.legendPartly),
        item(const Icon(Icons.check_rounded, size: 14, color: complianceOrange), l.legendOff),
        item(const Icon(Icons.close_rounded, size: 14, color: AppColors.danger), l.legendMissed),
      ],
    );
  }
}
