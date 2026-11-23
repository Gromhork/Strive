import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/scheduler.dart';
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
import '../../services/plan_service.dart';
import '../../widgets/common.dart';
import '../../widgets/plan_amount.dart';
import '../stats/session_detail_page.dart';
import '../../services/fitness_state.dart';
import '../onboarding/onboarding_page.dart';
import 'feasibility_apply.dart';
import 'feasibility_card.dart';
import 'plan_hint_memory.dart';
import 'plan_editor.dart';
import 'plan_history_page.dart';
import 'planned_workout_page.dart';
import 'recalibrate_sheet.dart';
import '../../widgets/segments.dart';
import '../../widgets/term_info.dart';
import '../../widgets/nav.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  bool _month = false;
  DateTime _focused = dayOnly(DateTime.now());
  DateTime _selected = dayOnly(DateTime.now());

  /// (Checked in the background – the page rebuilds when a check is done.)
  late final _feasibility = FeasibilityCache(
    onUpdate: () {
      if (mounted) setState(() {});
    },
  );

  /// Scroll controller of the week list and the month view: the tab's primary one (tapping the
  /// tab again scrolls back), an own one where there is none.
  final _ownScroll = ScrollController();
  ScrollController get _scroll => PrimaryScrollController.maybeOf(context) ?? _ownScroll;

  /// Where the current week (month view: today's cell) is, relative to the viewport: 0 in view,
  /// 1 above (scrolled into the future – the "Today" button points up), -1 below; month view
  /// showing a later month 2 (the button points back, left), an earlier one -2. A notifier, so
  /// showing the button rebuilds only the button, not the weeks being scrolled.
  final _jumpDir = ValueNotifier(0);

  /// Arrow of the button while it fades out (the last direction it showed).
  int _shownJumpDir = 1;
  final _currentWeekKey = GlobalKey();
  final _todayCellKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    PlanService.replaced.addListener(_onPlanReplaced);
  }

  /// A new plan (audit UX-16): back to the current week – the old scroll position pointed into the old plan.
  void _onPlanReplaced() {
    if (!mounted) return;
    final today = dayOnly(DateTime.now());
    setState(() {
      _selected = today;
      _focused = today;
    });
    final c = _scroll;
    if (c.hasClients && c.positions.length == 1) c.jumpTo(0);
  }

  @override
  void dispose() {
    PlanService.replaced.removeListener(_onPlanReplaced);
    _ownScroll.dispose();
    _jumpDir.dispose();
    super.dispose();
  }

  /// Feasibility of the event goal for the generated plan leading to it: checked from the
  /// plan's first week (the plan's own start), not from today.
  (PlanFeasibility, DateTime?) _goalCheck() {
    final profile = ref.watch(profileOrDefaultProvider);
    final event = profile.athlete.eventDate;
    if (event == null || profile.athlete.eventDistance == null) return (const PlanFeasibility(), null);
    final race = dayOnly(event);
    if (race.isBefore(dayOnly(DateTime.now()))) return (const PlanFeasibility(), null);
    final earliest = addDays(race, -(7 * 30));
    // The CURRENT plan's start – not the first workout of an older plan still in the history (QA 2026-11:
    // its weeks counted as trained and the plan was checked from the wrong start).
    final phased = [
      for (final p in ref.watch(planListProvider))
        if (p.phase != null && !p.date.isAfter(race) && !p.date.isBefore(earliest)) p,
    ]..sort((x, y) => x.date.compareTo(y.date));
    final start = FitnessState.currentPlanStart(profile, phased);
    if (start == null) return (const PlanFeasibility(), null);
    // The target check on the one fitness model of the running plan (= the goal forecast's race day),
    // computed once per data change – not on every rebuild of the page.
    return (_feasibility.of(profile, start, context.l10n, fitness: ref.watch(currentFitnessProvider)), start);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(todayProvider); // "today" / missed workouts change at midnight
    final l = context.l10n;
    final (goal, planStart) = _goalCheck();
    // Calm notes (owner round 9: the hint came back on every start): closed, a set of notes stays closed until it
    // changes; information only is a card once, then the small entry in the ⋮ menu (a dot on it).
    final hintSig = planStart == null ? '' : planHintSignature(goal, planStart);
    final hint = planStart == null ? PlanHintMode.none : PlanHintMemory.mode(goal, hintSig, ref.watch(planHintMemoryProvider));
    if (hint == PlanHintMode.card && goal.onlyNotes && !PlanHintMemory.shownThisRun.contains(hintSig)) {
      ref.read(planHintMemoryProvider.notifier).markSeen(hintSig);
    }
    void openSettings() => openPage(context, const OnboardingPage(mode: SetupMode.plan), id: SetupMode.plan.name);
    void option(FeasibilityAction x, String text) => applyFeasibilityOption(context, ref, x, text);
    // Content, view or month changed: is the current week still in view?
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateJump());
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
                // Race day ahead: one tap there (audit UX-16: 17 weeks of scrolling by hand).
                if (_raceDay() case final race?)
                  IconButton(
                    key: const ValueKey('jumpToRace'),
                    tooltip: l.calJumpRace,
                    icon: const Icon(Icons.flag_rounded),
                    onPressed: () => _showDay(race),
                  ),
                // Secondary: a whole new plan, calendar export.
                PopupMenuButton<String>(
                  key: const ValueKey('calendarMore'),
                  tooltip: l.recalMore,
                  // Closed / already seen plan notes: one tap away, unobtrusive – a dot on ⋮ (warning colour for a
                  // problem) and the first item in its menu. Next to the button they shrank its label.
                  icon:
                      hint == PlanHintMode.entry
                          ? Badge(
                            key: const ValueKey('planHintsBadge'),
                            backgroundColor: goal.onlyNotes ? AppColors.brand : AppColors.warning,
                            child: const Icon(Icons.more_vert_rounded),
                          )
                          : const Icon(Icons.more_vert_rounded),
                  onSelected:
                      (v) => switch (v) {
                        'hints' => FeasibilityCard.showDetails(context, goal, onOption: option, onOpenSettings: openSettings),
                        'new' => showPlanGenerator(context, ref),
                        'history' => openPage(context, const PlanHistoryPage()),
                        _ => _exportIcs(),
                      },
                  itemBuilder:
                      (_) => [
                        if (hint == PlanHintMode.entry)
                          PopupMenuItem(
                            key: const ValueKey('planHints'),
                            value: 'hints',
                            child: ListTile(
                              leading: Icon(
                                goal.onlyNotes ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                                color: goal.onlyNotes ? null : AppColors.warning,
                              ),
                              title: Text(l.planHints),
                            ),
                          ),
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
                  onChanged: (v) {
                    setState(() => _month = v);
                    // The list opens at the day picked in the month (audit UX-16: it jumped back to this week).
                    if (!v) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToWeek(_selected));
                  },
                ),
              ],
            ),
          ),
          if (hint == PlanHintMode.card)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              // Compact (audit UX-9: the full card took half the calendar); details and options in a sheet.
              child: FeasibilityCard(
                goal,
                compact: true,
                onClose: () => ref.read(planHintMemoryProvider.notifier).dismiss(hintSig),
                // The options as buttons, as in the setup: applied with the usual "Plan neu aufsetzen?" confirmation.
                onOption: option,
                onOpenSettings: openSettings,
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.depth == 0) _updateJump(n.metrics);
                    return false;
                  },
                  child: _month ? _monthView() : _weekList(),
                ),
                // Bottom centre, level with the add button (16 px margin, 56 px high) – never on it.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _jumpDir,
                      builder:
                          (_, dir, __) => JumpToTodayButton(
                            visible: dir != 0,
                            icon: switch (_shownJumpDir) {
                              2 => Icons.arrow_back_rounded,
                              -2 => Icons.arrow_forward_rounded,
                              -1 => Icons.arrow_downward_rounded,
                              _ => Icons.arrow_upward_rounded,
                            },
                            tooltip: _month ? l.calJumpTodayMonth : l.calJumpCurrentWeek,
                            onPressed: _jumpBack,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Jumps to a day: the race, the day picked in the month.

  /// The next race day: the plan's race workout, else the race date of the plan settings (not past).
  DateTime? _raceDay() {
    final today = ref.watch(todayProvider);
    final races = ref.watch(planListProvider).where((p) => p.intensity == 'race' && !p.date.isBefore(today)).map((p) => dayOnly(p.date));
    final race = races.isEmpty ? null : races.reduce((a, b) => a.isBefore(b) ? a : b);
    final ev = ref.watch(profileOrDefaultProvider).athlete.eventDate;
    return race ?? (ev != null && !dayOnly(ev).isBefore(today) ? dayOnly(ev) : null);
  }

  /// Shows [day]: the month view selects it, the list scrolls to its week.
  void _showDay(DateTime day) {
    setState(() {
      _selected = day;
      _focused = day;
    });
    if (!_month) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToWeek(day));
  }

  /// Week (from this week) the list builds with [_targetWeekKey] – the one [_scrollToWeek] is heading for.
  int? _targetWeek;
  final _targetWeekKey = GlobalKey();

  /// Scrolls the week list to the week of [day]: the weeks are built lazily, so first close to it (by the
  /// current week's height), then exactly onto its card.
  Future<void> _scrollToWeek(DateTime day) async {
    if (!mounted || _month) return;
    final w = (daysBetween(startOfWeek(dayOnly(DateTime.now())), startOfWeek(day)) / 7).round();
    final c = _scroll;
    if (!c.hasClients || c.positions.length != 1) return;
    if (w == 0) {
      await c.position.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      return;
    }
    setState(() => _targetWeek = w);
    await WidgetsBinding.instance.endOfFrame;
    final est = _currentWeekKey.currentContext?.size?.height ?? 400;
    for (var i = 0; i < 8 && mounted && c.hasClients; i++) {
      final ctx = (w == -1 ? _lastWeekKey : _targetWeekKey).currentContext;
      if (ctx != null) {
        if (!ctx.mounted) return;
        await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
        return;
      }
      // Not built yet: an estimate, then a week further on either side.
      final p = c.position;
      final off = (i.isEven ? 1 : -1) * ((i + 1) ~/ 2) * est;
      p.jumpTo((w * est + off).clamp(p.minScrollExtent, p.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  // ── "Today" button: shown while the current week is scrolled out of view.

  void _updateJump([ScrollMetrics? metrics]) {
    if (!mounted) return;
    final c = _scroll;
    final m = metrics ?? (c.hasClients && c.positions.length == 1 && c.position.hasContentDimensions ? c.position : null);
    final dir = m == null ? 0 : _jumpDirection(m);
    if (dir == _jumpDir.value) return;
    void apply() {
      if (!mounted) return;
      if (dir != 0) _shownJumpDir = dir;
      _jumpDir.value = dir;
    }

    // Notifications can arrive during layout: no setState there.
    SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks
        ? WidgetsBinding.instance.addPostFrameCallback((_) => apply())
        : apply();
  }

  int _jumpDirection(ScrollMetrics m) {
    if (_month) {
      final cell = _todayCellKey.currentContext;
      if (cell != null) return scrolledAwayDirection(cell, m);
      // Today is not in the grid: another month is shown.
      final now = ref.read(todayProvider);
      return DateTime(_focused.year, _focused.month).isAfter(DateTime(now.year, now.month)) ? 2 : -2;
    }
    final card = _currentWeekKey.currentContext;
    // Not built: far away – the current week is at scroll offset 0 (the list's anchor).
    if (card == null) return m.pixels > 0 ? 1 : (m.pixels < 0 ? -1 : 0);
    return scrolledAwayDirection(card, m);
  }

  Future<void> _jumpBack() async {
    if (_month) {
      final now = ref.read(todayProvider);
      setState(() {
        _focused = now;
        _selected = now;
      });
    }
    final c = _scroll;
    if (!c.hasClients || c.positions.length != 1) return;
    final p = c.position;
    // Far away: jump close first – animating across dozens of weeks would build every week on the way.
    final near = p.viewportDimension * 1.5;
    if (p.pixels.abs() > near) p.jumpTo(p.pixels.sign * near);
    await p.animateTo(0, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  List<PlannedWorkout> _plans() {
    final f = ref.watch(sportFilterProvider);
    return ref.watch(planListProvider).where((p) => f == null || p.sport == f).toList();
  }

  List<Session> _sessions() {
    final f = ref.watch(sportFilterProvider);
    return ref.watch(sessionListProvider).where((s) => f == null || s.sport == f).toList();
  }

  /// The shown plans and sessions indexed by day – rebuilt only when the data or the filter change.
  CalendarIndex _index() {
    final key = (
      ref.watch(planListProvider),
      ref.watch(sessionListProvider),
      ref.watch(sportFilterProvider),
      ref.watch(planSessionsProvider),
      ref.watch(sessionPlanProvider),
      ref.watch(planFirstDayProvider),
    );
    if (key != _indexKey) {
      _indexKey = key;
      _indexCache = CalendarIndex(plans: _plans(), sessions: _sessions(), linked: key.$4, sessionPlan: key.$5, firstDay: key.$6);
    }
    return _indexCache!;
  }

  Object? _indexKey;
  CalendarIndex? _indexCache;

  // ── Week list with drag & drop between days. The current week is the scroll anchor;
  // past weeks (with completed workouts) are above it and revealed by scrolling up.
  static const _pastWeeks = 12;
  final _nowKey = GlobalKey();
  final _lastWeekKey = GlobalKey();

  Widget _weekCard(int w, CalendarIndex idx, {Key? key}) {
    final l = context.l10n;
    final df = DateFormat.MMMd(context.localeName);
    final week = addDays(startOfWeek(DateTime.now()), 7 * w);
    final days = [for (var d = 0; d < 7; d++) addDays(week, d)];
    final label = switch (w) {
      0 => l.currentWeek,
      1 => l.nextWeek,
      -1 => l.lastWeek,
      _ => null,
    };
    Widget? trailing;
    if (w < 0) {
      // Past week: completed vs. planned at a glance.
      final weekPlans = [for (final d in days) ...idx.plansOn(d)];
      // The one count of the app ([planCounts]): a session too short to count is no "done".
      final counts = planCounts(weekPlans, idx.linked, profile: ref.watch(profileOrDefaultProvider));
      final planned = counts.planned;
      final done = planned > 0 ? counts.done : days.fold<int>(0, (n, d) => n + idx.sessionsOn(d).length);
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
    // No Opacity layer for past weeks: an offscreen layer per card made fast scrolling stutter.
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        title: '${df.format(week)} – ${df.format(days.last)}',
        trailing: trailing,
        child: Column(children: [for (final d in days) _DayRow(day: d, index: idx)]),
      ),
    );
  }

  Widget _weekList() {
    final l = context.l10n;
    final idx = _index();
    // Down to the last week of the plan (at least 8 weeks ahead, at most ~1 year) and up
    // to the plan's first week (at least 12 weeks back).
    final all = ref.watch(planListProvider);
    final thisWeek = startOfWeek(DateTime.now());
    int weeksTo(DateTime d) => (daysBetween(thisWeek, startOfWeek(d)) / 7).round();
    final ahead = all.isEmpty ? 8 : (all.map((p) => weeksTo(p.date)).reduce(max) + 1).clamp(8, 60);
    final back = all.isEmpty ? _pastWeeks : (-all.map((p) => weeksTo(p.date)).reduce(min)).clamp(_pastWeeks, 60);
    return CustomScrollView(
      controller: _scroll,
      center: _nowKey,
      slivers: [
        // Grows upwards from the anchor: index 0 = last week.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _weekCard(-(i + 1), idx, key: i == 0 ? _lastWeekKey : (-(i + 1) == _targetWeek ? _targetWeekKey : null)),
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
              return _weekCard(i - 1, idx, key: i == 1 ? _currentWeekKey : (i - 1 == _targetWeek ? _targetWeekKey : null));
            }, childCount: ahead + 1), // hint + current week … last plan week
          ),
        ),
      ],
    );
  }

  /// Month grid marks – recomputed only when their inputs change (not on every day tap).
  Map<String, List<DayMark>> _marks(List<PlannedWorkout> plans, List<Session> sessions) {
    final key = (
      ref.watch(planListProvider),
      ref.watch(sessionListProvider),
      ref.watch(sportFilterProvider),
      ref.watch(planSessionsProvider),
      ref.watch(todayProvider),
      ref.watch(profileOrDefaultProvider),
    );
    if (key != _marksKey) {
      _marksKey = key;
      _marksCache = monthMarks(key.$1, plans, sessions, key.$4, now: key.$5, profile: key.$6);
    }
    return _marksCache!;
  }

  Object? _marksKey;
  Map<String, List<DayMark>>? _marksCache;

  // ── Month grid
  Widget _monthView() {
    final l = context.l10n;
    final idx = _index();
    final first = DateTime(_focused.year, _focused.month, 1);
    final gridStart = startOfWeek(first);
    final names = DateFormat.E(context.localeName);
    final dayPlans = idx.plansOn(_selected);
    final daySessions = idx.sessionsOn(_selected);
    final linked = idx.linked;
    final profile = ref.watch(profileOrDefaultProvider);
    final marks = _marks(idx.plans, idx.sessions);
    return ListView(
      controller: _scroll,
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
                    final dayMarks = marks[dayKey(day)] ?? const <DayMark>[];
                    final sel = sameDay(day, _selected);
                    final today = sameDay(day, DateTime.now());
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = day),
                        child: Container(
                          key: today ? _todayCellKey : null,
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
                                    // The legend's marks: ✓ in the compliance colour of a planned workout done
                                    // (on the day it was done), ✕ missed / not counted, a hollow dot open, a
                                    // filled dot a session outside the plan.
                                    for (final m in dayMarks.take(4)) DayMarkIcon(m),
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
        for (final p in dayPlans.where((p) => !p.isDone || p.sessionId == null || _startedElsewhereNotCounted(p, linked, profile)))
          Padding(padding: const EdgeInsets.only(bottom: 6), child: PlanCard(plan: p)),
        for (final p in dayPlans.where((p) => _doneElsewhere(p, linked, profile))) DoneElsewhereLine(plan: p, session: linked[p.id]!),
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

/// Session id → the planned workout it fulfils (the first one linked to it) – a lookup instead of
/// a scan of all links for every session shown.
final sessionPlanProvider = Provider<Map<String, PlannedWorkout>>((ref) {
  final byId = {for (final p in ref.watch(planListProvider)) p.id: p};
  final out = <String, PlannedWorkout>{};
  for (final e in ref.watch(planSessionsProvider).entries) {
    final p = byId[e.key];
    if (p != null) out.putIfAbsent(e.value.id, () => p);
  }
  return out;
});

/// The running plan's fitness model (the goal forecast's), computed once per change of the
/// profile, plans, sessions or day – the calendar rebuilt it twice on every rebuild.
final currentFitnessProvider = Provider<FitnessState>((ref) {
  ref.watch(todayProvider);
  return FitnessState.of(
    ref.watch(profileOrDefaultProvider),
    plans: ref.watch(planListProvider),
    sessions: ref.watch(sessionListProvider),
    now: DateTime.now(),
  );
});

/// The shown plans and sessions of the calendar indexed by day (each day row used to scan all
/// of them – seven times for every week scrolled into view).
class CalendarIndex {
  CalendarIndex({required this.plans, required this.sessions, required this.linked, required this.sessionPlan, required this.firstDay})
    : byId = {for (final p in plans) p.id: p} {
    for (final p in plans) {
      _plansByDay.putIfAbsent(dayKey(p.date), () => []).add(p);
    }
    for (final s in sessions) {
      _sessionsByDay.putIfAbsent(dayKey(s.start), () => []).add(s);
    }
  }

  final List<PlannedWorkout> plans;
  final List<Session> sessions;

  /// Plan id → linked session ([planSessionsProvider]).
  final Map<String, Session> linked;

  /// Session id → the planned workout (of any sport) it fulfils ([sessionPlanProvider]).
  final Map<String, PlannedWorkout> sessionPlan;

  /// First day of any plan ([planFirstDayProvider]).
  final DateTime? firstDay;

  /// The shown plans by id.
  final Map<String, PlannedWorkout> byId;
  final _plansByDay = <String, List<PlannedWorkout>>{};
  final _sessionsByDay = <String, List<Session>>{};

  List<PlannedWorkout> plansOn(DateTime day) => _plansByDay[dayKey(day)] ?? const [];
  List<Session> sessionsOn(DateTime day) => _sessionsByDay[dayKey(day)] ?? const [];
}

/// Where [target] (inside the scroll view of [m]) is: 0 in view (a third of it – at most of the
/// viewport – on screen), 1 above the viewport, -1 below.
int scrolledAwayDirection(BuildContext target, ScrollMetrics m) {
  final box = target.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return 0;
  final viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport == null) return 0;
  final top = viewport.getOffsetToReveal(box, 0).offset;
  final h = box.size.height;
  final shown = min(top + h, m.pixels + m.viewportDimension) - max(top, m.pixels);
  if (shown >= min(h, m.viewportDimension) / 3) return 0;
  return top + h / 2 < m.pixels + m.viewportDimension / 2 ? 1 : -1;
}

/// Floating "Today" pill of the calendar: back to the current week (month view: today's month),
/// with an arrow towards it. Fades and slides in and out.
class JumpToTodayButton extends StatelessWidget {
  const JumpToTodayButton({super.key, required this.visible, required this.icon, required this.tooltip, required this.onPressed});
  final bool visible;

  /// Arrow towards today (up / down in the week list, back / forward to today's month).
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.6),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Tooltip(
            message: tooltip,
            child: Material(
              key: const ValueKey('jumpToToday'),
              color: cs.secondaryContainer,
              elevation: 3,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onPressed,
                child: SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: cs.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Text(context.l10n.today, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [p] was done on another day (its session counts): its own day shows a "done on Mo" line instead
/// of the card. A start too short to count leaves the workout open on its day.
bool _doneElsewhere(PlannedWorkout p, Map<String, Session> linked, UserProfile profile) {
  final s = linked[p.id];
  return p.isDone && s != null && !sameDay(s.start, p.date) && sessionCounts(p, s, profile: profile);
}

/// [p] is marked done by a session on another day that is too short to count: still open on its day.
bool _startedElsewhereNotCounted(PlannedWorkout p, Map<String, Session> linked, UserProfile profile) {
  final s = linked[p.id];
  return p.isDone && s != null && !sameDay(s.start, p.date) && !sessionCounts(p, s, profile: profile);
}

/// Short weekday names ("Mo") per locale – one DateFormat, not a new one for every day row.
final _weekdayFormats = <String, DateFormat>{};
DateFormat _weekdayFormat(String locale) => _weekdayFormats[locale] ??= DateFormat.E(locale);

/// A planned workout that was done on another day, on its own day: "Fahrtspiel · erledigt am
/// Mo" (tap: the session) – the calendar and Home's "Demnächst" show the day the same way.
class DoneElsewhereLine extends ConsumerWidget {
  const DoneElsewhereLine({super.key, required this.plan, required this.session});
  final PlannedWorkout plan;
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = planCompliance(plan, session, profile: ref.watch(profileOrDefaultProvider));
    final t = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      key: ValueKey('doneElsewhere_${plan.id}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => openPage(context, SessionDetailPage(sessionId: session.id), id: session.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            // A start too short to count is no "done" (the workout page says it stays open).
            Icon(c.notCounted ? Icons.close_rounded : Icons.check_rounded, size: 16, color: c.color(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${glueTitle(plan.title)} · ${(c.notCounted ? l.startedOnDayNotCounted : l.doneOnDay)(_weekdayFormat(context.localeName).format(session.start))}',
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
  const _DayRow({required this.day, required this.index});
  final DateTime day;
  final CalendarIndex index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = index.linked;
    // A workout done on another day (early / late, as a replacement) is shown once: as the
    // session on the day it was done ("ersetzt Sa-Einheit"), not again on its planned day.
    // (A start too short to count is no replacement: the workout stays open on its own day.)
    final profile = ref.watch(profileOrDefaultProvider);
    bool doneElsewhere(PlannedWorkout x) => _doneElsewhere(x, linked, profile);
    final dayPlans = index.plansOn(day);
    final p = dayPlans.where((x) => !doneElsewhere(x)).toList();
    // … but its own day says where it went ("erledigt am Mo") instead of "Pause".
    final elsewhere = dayPlans.where(doneElsewhere).toList();
    final first = index.firstDay;
    final s = index.sessionsOn(day).where((x) => !p.any((pl) => pl.sessionId == x.id || linked[pl.id]?.id == x.id)).toList();
    PlannedWorkout? replaced(Session x) {
      final pl = index.byId[index.sessionPlan[x.id]?.id];
      return pl != null && !sameDay(pl.date, x.start) && sessionCounts(pl, x, profile: profile) ? pl : null;
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
                        _weekdayFormat(context.localeName).format(day),
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
                // A plain ink button, not an IconButton: seven per week, and the M3 IconButton was
                // the largest part of building a week while scrolling (same 40 px target).
                Semantics(
                  button: true,
                  label: context.l10n.planWorkout,
                  child: InkResponse(
                    key: ValueKey('addOn_${dayKey(day)}'),
                    radius: 20,
                    onTap: () => showPlanEditor(context, ref, date: day),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.add, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
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
    final c0 = planCompliance(p, ref.watch(planSessionsProvider)[p.id], profile: profile);
    // A start too short to count leaves the workout open – until its day has passed it is shown as open.
    final c = c0.notCounted && !dayOnly(p.date).isBefore(dayOnly(DateTime.now())) ? Compliance.none : c0;
    return Material(
      // Missed or not counted (red ✕): neutral, not the sport's tint of an open / done workout.
      color: c.level == ComplianceLevel.red ? Theme.of(context).colorScheme.surfaceContainerHighest : p.sport.color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: c.level == ComplianceLevel.none ? BorderSide.none : BorderSide(color: c.color(context).withValues(alpha: 0.55)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openPage(context, PlannedWorkoutPage(planId: p.id), id: p.id),
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
    final profile = ref.watch(profileOrDefaultProvider);
    final u = profile.units;
    // The planned workout this session fulfils (same day or replaced) – its compliance, the same
    // ring as the planned-workout cards; a session outside the plan gets a neutral done mark.
    final plan = ref.watch(sessionPlanProvider)[s.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: s.sport.color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openPage(context, SessionDetailPage(sessionId: s.id), id: s.id),
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
                          context.l10n.replacesDayWorkout(_weekdayFormat(context.localeName).format(replaces!.date)),
                          key: const ValueKey('replacesLabel'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Text(
                  // Gym (and cardio without a distance, e.g. indoors): the time, never "0,0 km".
                  s.sport == Sport.gym || s.distanceM <= 0
                      ? humanDuration(s.durationSec)
                      : (s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM, digits: 1)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                plan != null
                    ? ComplianceRing(compliance: planCompliance(plan, s, profile: profile))
                    : Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('extraSessionDone'),
                      color: Theme.of(context).colorScheme.outline,
                      size: 20,
                    ),
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
        // What "teilweise" / "stark abweichend" mean in numbers (the one compliance scale).
        const TermInfoButton(Term.compliance, key: ValueKey('legendInfo')),
      ],
    );
  }
}

/// One mark of a day in the month grid (see [monthMarks]).
class DayMark {
  const DayMark(this.sport, {this.compliance, this.extra = false});
  final Sport sport;

  /// The planned workout's compliance; null for [extra].
  final Compliance? compliance;

  /// A session outside the plan (filled dot).
  final bool extra;
}

/// Day key → the marks of the month grid, as in its legend: a planned workout with a linked
/// session on the day it was done (✓ in its compliance colour, ✕ when too short to count), one
/// without on its own day (✓ marked done, hollow dot open, ✕ missed; skipped: none), sessions
/// fulfilling no planned workout as filled dots. [allPlans]: every planned workout (a session
/// linked to a filtered-out one is no extra); [plans] / [sessions]: the ones shown.
Map<String, List<DayMark>> monthMarks(
  List<PlannedWorkout> allPlans,
  List<PlannedWorkout> plans,
  List<Session> sessions,
  Map<String, Session> linked, {
  required DateTime now,
  UserProfile? profile,
}) {
  final out = <String, List<DayMark>>{};
  void add(DateTime d, DayMark m) => out.putIfAbsent(dayKey(d), () => []).add(m);
  final shown = {for (final x in sessions) x.id};
  for (final p in plans) {
    final s = linked[p.id];
    if (p.status == 'skipped' && s == null) continue;
    final c = planCompliance(p, s, now: now, profile: profile);
    // Started on another day but too short to count: the workout is still open on its own day.
    if (s != null && c.notCounted && !sameDay(s.start, p.date) && !dayOnly(p.date).isBefore(dayOnly(now))) {
      add(p.date, DayMark(p.sport, compliance: Compliance.none));
    }
    if (s != null && !shown.contains(s.id)) continue;
    add(s?.start ?? p.date, DayMark(p.sport, compliance: c));
  }
  final used = {
    for (final p in allPlans)
      if (linked[p.id] case final s?) s.id,
  };
  for (final s in sessions) {
    if (!used.contains(s.id)) add(s.start, DayMark(s.sport, extra: true));
  }
  return out;
}

/// A [DayMark] drawn in the month grid (9 px).
class DayMarkIcon extends StatelessWidget {
  const DayMarkIcon(this.mark, {super.key});
  final DayMark mark;

  @override
  Widget build(BuildContext context) {
    final m = mark;
    final c = m.compliance;
    if (m.extra || c == null) {
      return Container(
        key: const ValueKey('monthExtra'),
        width: 7,
        height: 7,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(color: m.sport.color, shape: BoxShape.circle),
      );
    }
    return switch (c.level) {
      ComplianceLevel.none => Container(
        key: const ValueKey('monthOpen'),
        width: 7,
        height: 7,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: m.sport.color, width: 1.5)),
      ),
      ComplianceLevel.red => Icon(Icons.close_rounded, key: const ValueKey('monthMissed'), size: 9, color: c.color(context)),
      _ => Icon(Icons.check_rounded, key: ValueKey('monthDone_${c.level.name}'), size: 9, color: c.color(context)),
    };
  }
}
