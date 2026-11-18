import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../services/compliance.dart';
import '../../services/insights.dart';
import '../../widgets/common.dart';
import '../../widgets/term_info.dart';
import '../../widgets/plan_amount.dart';
import '../profile/health_connect_page.dart';
import '../shell/health_sync.dart';
import 'adjust_week.dart';
import 'auto_adjusted_banner.dart';
import 'goal_status_card.dart';
import 'weather_page.dart';
import 'week_page.dart';
import '../profile/profile_page.dart';
import '../calendar/plan_editor.dart';
import '../calendar/planned_workout_page.dart';
import '../session/step_list.dart';
import '../goals/goal_forecast_widgets.dart';
import '../goals/goals_page.dart';
import '../goals/goal_mismatch_card.dart';
import '../onboarding/onboarding_page.dart';
import '../session/start_helpers.dart';
import '../stats/body_page.dart';
import '../../services/plan_service.dart';
import '../../widgets/whole_words_text.dart';
import '../stats/session_detail_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(weatherProvider);
        // Pull-to-refresh also fetches new watch workouts and vitals.
        ref.read(healthTickProvider.notifier).bump();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [
          _Greeting(),
          SizedBox(height: 12),
          _BannerSlot(),
          TodayCard(),
          SizedBox(height: 12),
          // Order (owner, round 9): what's next and this week first, then body values, then the goal.
          ComingUpCard(),
          SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: WeatherCard()), SizedBox(width: 12), Expanded(child: _WeekCard())],
            ),
          ),
          SizedBox(height: 12),
          _WeightCard(key: ValueKey('weightCard')),
          SizedBox(height: 12),
          _VitalsCard(key: ValueKey('vitalsCard')),
          _RecoveryCard(key: ValueKey('recoveryCard')),
          GoalStatusCard(),
          _EventLine(),
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
    // Both tick (midnight / every hour, and on resume): the header never shows yesterday's
    // date or an evening greeting in the morning while the app stayed open.
    final today = ref.watch(todayProvider);
    final hello = greetingFor(ref.watch(hourProvider), morning: l.goodMorning, afternoon: l.goodAfternoon, evening: l.goodEvening);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.MMMMEEEEd(context.localeName).format(today),
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

// ───────────────────────────── Guest account ─────────────────────────────

/// Whether the signed-in account is a guest (anonymous) – false without Firebase (tests).
final isGuestProvider = Provider<bool>((ref) {
  try {
    ref.watch(authProvider);
    return FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
  } catch (_) {
    return false;
  }
});

/// After 3 sessions a guest is asked to secure the data (link e-mail or Google); dismissed,
/// it comes back after a week.
/// At most one hint card above today's workout, the most important first: goal and plan
/// don't match → missed workouts to move → automatic adjustments to review → secure the
/// guest account. Several stacked cards pushed today's workout out of view.
class _BannerSlot extends ConsumerWidget {
  const _BannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(planListProvider);
    final now = DateTime.now();
    final prefs = ref.read(prefsProvider);
    final m = ref.watch(goalAlignmentProvider);
    String? snoozed;
    try {
      snoozed = prefs.getString(GoalMismatchCard.prefsKey);
    } catch (_) {}
    if (m != null && m.mismatch && snoozed != m.signature) return const GoalMismatchCard(snoozable: true);
    if (adjustWeekBannerVisible(prefs, plans, now)) return const AdjustWeekBanner();
    if (unseenAutoAdjustments(plans, ref.watch(autoAdjSeenProvider), now).isNotEmpty) return const AutoAdjustedBanner();
    return const GuestBanner();
  }
}

class GuestBanner extends ConsumerStatefulWidget {
  const GuestBanner({super.key});
  static const prefsKey = 'guestBannerSnoozed';
  static const minSessions = 3;
  @override
  ConsumerState<GuestBanner> createState() => _GuestBannerState();
}

class _GuestBannerState extends ConsumerState<GuestBanner> {
  bool _hidden = false;

  bool _snoozed() {
    try {
      final ms = ref.read(prefsProvider).getInt(GuestBanner.prefsKey);
      return ms != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms)).inDays < 7; // time span
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched unconditionally: a first subscription inside a short-circuited condition happens in
    // some later build and flushes pending provider updates during that build.
    final guest = ref.watch(isGuestProvider);
    final count = ref.watch(sessionListProvider).length;
    if (_hidden || !guest || count < GuestBanner.minSessions || _snoozed()) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SecureGuestCard(
        onDismiss: () {
          setState(() => _hidden = true);
          try {
            ref.read(prefsProvider).setInt(GuestBanner.prefsKey, DateTime.now().millisecondsSinceEpoch);
          } catch (_) {}
        },
      ),
    );
  }
}

// ───────────────────────────── Today ─────────────────────────────

class TodayCard extends ConsumerStatefulWidget {
  const TodayCard({super.key});
  @override
  ConsumerState<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<TodayCard> {
  int _i = 0;

  // While the first setup still creates the plan (the profile is saved first and opens this page),
  // the card says so instead of offering "Plan erstellen" for a plan that is on its way.
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<bool>(valueListenable: PlanService.creating, builder: (context, creating, _) => _build(context, creating));

  Widget _build(BuildContext context, bool creating) {
    ref.watch(todayProvider); // "today" changes at midnight
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final today = dayOnly(DateTime.now());
    final all = ref.watch(planListProvider);
    final allToday = all.where((p) => sameDay(p.date, today)).toList();
    // Open workouts first, then done ones; skipped ("Entfällt") last – never a skipped
    // workout with a play button in front.
    int rank(PlannedWorkout p) => p.status == 'skipped' ? 2 : (p.isDone ? 1 : 0);
    final plans = allToday.where((p) => filter == null || p.sport == filter).toList()..sort((a, b) => rank(a).compareTo(rank(b)));
    // Today's workouts of other sports are not hidden silently.
    final hidden = allToday.length - plans.length;
    final doneToday = ref.watch(sessionListProvider).where((s) => sameDay(s.start, today)).toList();
    if (_i >= plans.length) _i = 0;

    if (plans.isEmpty) {
      final noPlan = !all.any((p) => !p.date.isBefore(today));
      final upcoming = all.where((p) => p.status == 'planned' && p.date.isAfter(today)).toList()..sort((a, b) => a.date.compareTo(b.date));
      final next = upcoming.where((p) => filter == null || p.sport == filter).firstOrNull ?? upcoming.firstOrNull;
      final small = Theme.of(context).textTheme.bodySmall;
      final (IconData icon, Color color, String title, String sub) =
          hidden > 0
              ? (Icons.filter_alt_outlined, AppColors.brand, l.todayHiddenByFilter(hidden), l.todayHiddenByFilterSub)
              : doneToday.isNotEmpty
              ? (Icons.check_circle_rounded, AppColors.success, l.doneToday(doneToday.length), doneToday.map((s) => s.title).join(', '))
              : noPlan && creating
              ? (Icons.hourglass_top_rounded, AppColors.brand, l.planCreating, l.noPlanYetSub)
              : noPlan
              ? (Icons.event_note_rounded, AppColors.brand, l.noPlanYet, l.noPlanYetSub)
              : (Icons.self_improvement_rounded, AppColors.brand, l.restDay, l.restDaySub);
      return SectionCard(
        title: l.todaysWorkout,
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l.planWorkout,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => showPlanEditor(context, ref, date: today),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, key: const ValueKey('todayTitle'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(sub, style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (next != null && hidden == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l.todayNext(next.title, DateFormat.EEEE(context.localeName).format(next.date)),
                            key: const ValueKey('todayNext'),
                            style: small?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child:
                  hidden > 0
                      ? FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => ref.read(sportFilterProvider.notifier).set(null),
                        child: Text(l.showAllSports),
                      )
                      : noPlan && creating
                      ? const Padding(
                        key: ValueKey('todayPlanCreating'),
                        padding: EdgeInsets.all(8),
                        child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                      )
                      : noPlan
                      ? FilledButton.icon(
                        key: const ValueKey('todayCreatePlan'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed:
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan))),
                        icon: const Icon(Icons.auto_graph_rounded, size: 18),
                        label: Text(l.generatePlan),
                      )
                      : FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => showQuickStart(context, ref),
                        child: Text(l.train),
                      ),
            ),
          ],
        ),
      );
    }

    final p = plans[_i];
    final skipped = p.status == 'skipped';
    // The same state and colour as the calendar: 0,39 of 5,8 km is "partly" (orange), not a green tick.
    final c = planCompliance(p, ref.watch(planSessionsProvider)[p.id], profile: ref.watch(profileOrDefaultProvider));
    final partly = p.isDone && c.partly;
    // A start too short to count (< 10 % of the plan) leaves the workout open: start it again.
    final notCounted = p.isDone && c.notCounted;
    final done = p.isDone && !notCounted;
    final small = Theme.of(context).textTheme.bodySmall;
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => PlannedWorkoutPage(planId: p.id)));
    // Compact (owner, round 9: the card with its description paragraph filled the screen – the tiles below were out
    // of view): title, amount and intensity, the start button; edit / add and the switch between several workouts
    // of the day in the header line. The description stays on the workout page.
    return Card(
      key: const ValueKey('todayCard'),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [p.sport.color.withValues(alpha: 0.28), p.sport.color.withValues(alpha: 0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hidden > 0 ? '${l.todaysWorkout} · ${l.todayHiddenByFilter(hidden)}' : l.todaysWorkout,
                        style: Theme.of(context).textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (plans.length > 1) ...[
                      IconButton(
                        key: const ValueKey('todayPrev'),
                        visualDensity: VisualDensity.compact,
                        tooltip: l.previousWorkout,
                        onPressed: () => setState(() => _i = (_i - 1) % plans.length),
                        icon: const Icon(Icons.chevron_left, size: 20),
                      ),
                      Text('${_i + 1}/${plans.length}', style: Theme.of(context).textTheme.labelSmall),
                      IconButton(
                        key: const ValueKey('todayNextWorkout'),
                        visualDensity: VisualDensity.compact,
                        tooltip: l.nextWorkout,
                        onPressed: () => setState(() => _i = (_i + 1) % plans.length),
                        icon: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ],

                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l.edit,
                      onPressed: () => showPlanEditor(context, ref, existing: p),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l.add,
                      onPressed: () => showPlanEditor(context, ref, date: today),
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SportBadge(p.sport, size: 44, filled: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(glueTitle(p.title), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
                          Text(
                            [
                              if (skipped) l.recalDropped,
                              if (partly) c.shortLabel(l),
                              if (notCounted) l.notCountedShort(Units.pct(c.pct!.toDouble())),
                              planAmountText(p, ref.watch(profileOrDefaultProvider), templates: ref.watch(templateListProvider)),
                              intensityLabel(l, p.intensity),
                            ].join(' · '),
                            style: small,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const ValueKey('todayStart'),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        backgroundColor:
                            done ? c.color(context) : (skipped ? Theme.of(context).colorScheme.surfaceContainerHighest : p.sport.color),
                        foregroundColor: Colors.black87,
                      ),
                      tooltip: skipped ? l.recalDropped : l.start,
                      onPressed:
                          skipped
                              ? open
                              : done
                              ? (p.sessionId == null
                                  ? null
                                  : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: p.sessionId!)),
                                  ))
                              : () => startPlanned(context, ref, p),
                      icon: Icon(done ? Icons.check_rounded : (skipped ? Icons.block_rounded : Icons.play_arrow_rounded), size: 28),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                if (p.steps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(padding: const EdgeInsets.only(right: 6), child: WorkoutProfileBar(steps: p.steps, sport: p.sport, height: 22)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Coming up ─────────────────────────────

/// Long words of gym program names and their abbreviation for the week strip.
const _gymAbbrev = {
  'Ganzkörper': 'GK',
  'Full Body': 'FB',
  'Fullbody': 'FB',
  'Oberkörper': 'OK',
  'Unterkörper': 'UK',
  'Upper Body': 'Upper',
  'Lower Body': 'Lower',
};

/// Compact label for the week strip: the kind of endurance session ("Locker", "Lang"),
/// gym programs abbreviated ("Ganzkörper A" → "GK A").
String shortPlanLabel(AppLocalizations l, PlannedWorkout p) {
  if (p.sport != Sport.gym && p.intensity.isNotEmpty && p.intensity != 'moderate') return intensityLabel(l, p.intensity);
  var t = p.title;
  for (final e in _gymAbbrev.entries) {
    t = t.replaceAll(RegExp(e.key, caseSensitive: false), e.value);
  }
  return t;
}

/// "Demnächst": the next six days.
class ComingUpCard extends ConsumerWidget {
  const ComingUpCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plans = ref.watch(planListProvider);
    final linked = ref.watch(planSessionsProvider);
    final filter = ref.watch(sportFilterProvider);
    final today = ref.watch(todayProvider);
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
                final d = addDays(today, i);
                final allDay = plans.where((p) => sameDay(p.date, d)).toList();
                final dayPlans = allDay.where((p) => filter == null || p.sport == filter).toList();
                // Workouts of other sports are hidden by the filter – not a rest day.
                final hiddenDay = dayPlans.isEmpty && allDay.isNotEmpty;
                final dim = Theme.of(context).colorScheme.outline;
                // Done already (early / as a replacement): ticked like in the calendar, with the
                // day it was done ("erledigt am Mo") instead of looking still open.
                // (A start too short to count leaves it open: no tick, no "erledigt am".)
                final profile = ref.watch(profileOrDefaultProvider);
                final doneOne = dayPlans.length == 1 && dayPlans.first.isDone && planCompleted(dayPlans.first, linked, profile: profile);
                final doneSession = doneOne ? linked[dayPlans.first.id] : null;
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
                          SizedBox(
                            height: 40,
                            child: Center(
                              child:
                                  hiddenDay
                                      ? Text('–', style: TextStyle(fontSize: 18, color: dim, fontWeight: FontWeight.w700))
                                      : _DayBadges(
                                        plans: dayPlans,
                                        done: doneOne ? planCompliance(dayPlans.first, linked[dayPlans.first.id], profile: profile) : null,
                                      ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Long-press explains the short label ("GK A" → "Ganzkörper A").
                          Tooltip(
                            message: dayPlans.map((p) => glueTitle(p.title)).join('\n'),
                            triggerMode: TooltipTriggerMode.longPress,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: WholeWordsText(
                                textAlign: TextAlign.center,
                                // Six days share the row: a short label (the kind of session; gym:
                                // "GK A") – long titles were cut off. The full title is one tap away.
                                hiddenDay
                                    ? l.hiddenShort
                                    : dayPlans.isEmpty
                                    ? l.rest
                                    : doneSession != null && !sameDay(doneSession.start, d)
                                    ? l.doneOnDay(fmt.format(doneSession.start))
                                    : (dayPlans.length == 1 ? shortPlanLabel(l, dayPlans.first) : l.nWorkouts(dayPlans.length)),
                                textKey: ValueKey('stripLabel$i'),
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.15,
                                  color: hiddenDay || dayPlans.isEmpty ? dim : null,
                                  fontWeight: dayPlans.length > 1 ? FontWeight.w700 : FontWeight.w400,
                                ),
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
    final profile = ref.read(profileOrDefaultProvider);
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
                        title: Text(glueTitle(p.title), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            l.sessionN(i + 1),
                            planAmountText(p, profile, templates: ref.read(templateListProvider)),
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
  const _DayBadges({required this.plans, this.done});
  final List<PlannedWorkout> plans;

  /// The single workout of the day is done: a check in its compliance colour on the badge.
  final Compliance? done;

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
    if (plans.length == 1 && done != null) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, child: Opacity(opacity: 0.55, child: SportBadge(plans.first.sport, size: 34))),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                key: const ValueKey('stripDone'),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.surfaceContainerLow),
                padding: const EdgeInsets.all(1),
                child: ComplianceRing(compliance: done!, size: 18),
              ),
            ),
          ],
        ),
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
    final weekStart = startOfWeek(ref.watch(todayProvider));
    final weekEnd = addDays(weekStart, 7);
    bool inWeek(DateTime d) => !d.isBefore(weekStart) && d.isBefore(weekEnd);
    final done = sessions.where((s) => inWeek(s.start)).toList();
    final planned = plans.where((p) => inWeek(p.date)).toList();
    final sports = {...planned.map((p) => p.sport), ...done.map((s) => s.sport)}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final linked = ref.watch(planSessionsProvider);
    final profile = ref.watch(profileOrDefaultProvider);
    // The same count as the week page: completed planned workouts / planned (not dropped).
    final counts = {for (final s in sports) s: planCounts(planned.where((p) => p.sport == s), linked, profile: profile)};
    String countText(Sport s) {
      final c = counts[s]!;
      return c.planned == 0 ? '${done.where((x) => x.sport == s).length}' : '${c.done}/${c.planned}';
    }

    final values = <Sport, double>{
      for (final s in sports) s: counts[s]!.planned == 0 ? 1 : (counts[s]!.done / counts[s]!.planned).clamp(0.0, 1.0),
    };
    final totalSec = done.fold<int>(0, (a, s) => a + s.durationSec);
    final completion = weeklyCompletion(planned, linked, profile: profile);
    final focus = profile.focus.sports;
    final quickSports = [
      for (final s in Sport.values)
        if (sports.contains(s) || focus.contains(s)) s,
    ];
    if (quickSports.isEmpty) quickSports.addAll(Sport.values);
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
                            Text(countText(s), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
          Text(humanDuration(totalSec), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(l.trainedThisWeek, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              // Quick start for the sports of this week's plan / the focus – no bike without a ride.
              for (final s in quickSports)
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
  const _RecoveryCard({super.key});
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
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
                        Text('ACWR ${Units.fixed(r.ratio, 2)}', style: Theme.of(context).textTheme.labelSmall),
                      if (r.readiness != Readiness.building) const TermInfoButton(Term.acwr, size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(text, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Weight ─────────────────────────────

class _WeightCard extends ConsumerStatefulWidget {
  const _WeightCard({super.key});
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
    final recent = body.where((b) => DateTime.now().difference(b.date).inDays <= 90).toList(); // time span
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

/// The next race as one line under today's workout – when the big goal-status card (with the
/// forecast) isn't shown, e.g. for a triathlon or before the plan is aligned.
class _EventLine extends ConsumerWidget {
  const _EventLine();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(goalForecastProvider) != null) return const SizedBox.shrink();
    return EventGoalLine(onTap: (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())));
  }
}

class _GoalsPreview extends ConsumerWidget {
  const _GoalsPreview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // The next race is already shown at the top (status card / event line).
    final event = activeEventGoal(ref.watch(goalsProvider).value ?? const [], ref.watch(todayProvider));
    final goals = (ref.watch(goalsProvider).value ?? const <Goal>[]).where((g) => g.id != event?.id).toList();
    if (goals.isEmpty && event != null) return const SizedBox.shrink();
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
  const _VitalsCard({super.key});
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
