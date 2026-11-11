import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/exercise_names_de.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../calendar/auto_adjust.dart';
import '../shell/health_sync.dart';
import '../stats/plan_link_card.dart' show askReplacement;
import '../../services/plan_match.dart';
import '../../services/compliance.dart' show ComplianceScale, plannedKm;
import '../../services/gym_tools.dart' show sessionRpeFromEfforts;
import '../../services/insights.dart';
import '../../services/workout_store.dart';
import '../../widgets/common.dart';
import '../../widgets/rpe_picker.dart';
import 'route_map.dart';

/// Shown after finishing a session: rate effort first (it adapts the plan), see XP / PRs, then save.
///
/// The draft (incl. rating and notes) is kept in [WorkoutStore] until it is saved or
/// discarded, so a finished workout survives the app being killed on this page.
/// What the finished session achieved – picks the headline on the summary.
enum SummaryOutcome { planDone, partial, tooLittle, free, tooShort }

/// [SummaryOutcome] of [s]: under a minute, or no distance outdoors (or in the pool) →
/// too short. Against the program / plan the bands of the one compliance scale apply
/// ([ComplianceScale]): ≥ 80 % → plan done, below 10 % → too little to count, else partial.
/// Gym compares the done work sets with [plannedSets] (all work sets of the workout when it
/// was finished, incl. exercises without a done set; else [Session.plannedSets]); cardio the
/// planned distance (duration indoors / without a distance) of [plan]. Free sessions (no
/// program, no plan) get a neutral-positive message.
SummaryOutcome summaryOutcome(Session s, {PlannedWorkout? plan, int? plannedSets}) {
  final noDistance = s.sport != Sport.gym && s.distanceM <= 0 && (!s.indoor || s.sport == Sport.swim);
  if (s.durationSec < 60 || noDistance) return SummaryOutcome.tooShort;
  final double ratio;
  if (s.sport == Sport.gym) {
    final total = max(plannedSets ?? s.plannedSets ?? 0, s.exercises.fold<int>(0, (a, e) => a + e.workSets.length));
    if ((s.templateId == null && s.planId == null) || total == 0) return SummaryOutcome.free;
    ratio = s.setsDone / total;
  } else {
    if (plan == null) return SummaryOutcome.free;
    final km = plannedKm(plan);
    if (km > 0 && (!s.indoor || s.sport == Sport.swim)) {
      ratio = s.distanceM / 1000 / km;
    } else if (plan.durationMin > 0) {
      ratio = s.durationSec / 60 / plan.durationMin;
    } else {
      return SummaryOutcome.free;
    }
  }
  if (ratio >= ComplianceScale.greenMin) return SummaryOutcome.planDone;
  return ratio < ComplianceScale.countMin ? SummaryOutcome.tooLittle : SummaryOutcome.partial;
}

class SessionSummaryPage extends ConsumerStatefulWidget {
  const SessionSummaryPage({super.key, required this.draft, this.restored = false, this.plannedSets});
  final Session draft;

  /// Gym: all sets of the workout when it was finished (exercises without a done set are
  /// not part of the draft) – for the "plan done / partial" headline.
  final int? plannedSets;

  /// Reopened after a restart: rating and notes come from the stored draft.
  final bool restored;

  @override
  ConsumerState<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends ConsumerState<SessionSummaryPage> {
  int? _rpe; // optional – null = not rated

  /// Gym: preselected from the exercises' effort chips (visible and editable, not a silent default).
  late final int? _prefill = widget.draft.sport == Sport.gym ? sessionRpeFromEfforts(widget.draft.exercises) : null;

  late final WorkoutStore _store = ref.read(workoutStoreProvider);
  Timer? _notesDebounce;

  @override
  void initState() {
    super.initState();
    _rpe = widget.restored ? widget.draft.rpe : _prefill;
    if (widget.restored) _notes.text = widget.draft.notes;
    _persist();
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    if (!_saved && !_discarded) _persist();
    _notes.dispose();
    super.dispose();
  }

  void _persist() {
    _notesDebounce?.cancel();
    _store.saveSummary(_session);
  }

  final _notes = TextEditingController();
  bool _saved = false;
  bool _discarded = false;

  Session get _session => Session(
    id: widget.draft.id,
    sport: widget.draft.sport,
    title: widget.draft.title,
    start: widget.draft.start,
    durationSec: widget.draft.durationSec,
    rpe: _rpe,
    notes: _notes.text.trim(),
    exercises: widget.draft.exercises,
    distanceM: widget.draft.distanceM,
    elevationM: widget.draft.elevationM,
    route: widget.draft.route,
    splits: widget.draft.splits,
    laps: widget.draft.laps,
    poolLengthM: widget.draft.poolLengthM,
    indoor: widget.draft.indoor,
    templateId: widget.draft.templateId,
    planId: widget.draft.planId,
    plannedSets: widget.draft.plannedSets ?? widget.plannedSets,
  );

  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final repo = ref.read(repoProvider)!;
    final s = _session;
    repo.saveSession(s);
    // Firestore keeps the write offline – the local draft is no longer needed.
    _store.clearSummary();
    ref.read(healthServiceProvider).writeSession(s);
    // Mark the matching planned workout as done.
    final plans = ref.read(planListProvider);
    final plan = matchPlan(s, plans);
    if (plan != null) {
      repo.updatePlan(plan.id, {'status': 'done', 'sessionId': s.id});
      // Endurance: small automatic adjustments of the next sessions (with undo).
      autoAdjustAfterSessions(
        repo: repo,
        l: context.l10n,
        profile: ref.read(profileOrDefaultProvider),
        plans: plans,
        sessions: ref.read(sessionListProvider),
        done: [(s, plan)],
      );
    }
    // Started from a workout days away: ask right here – not only later on the session page.
    final candidate = plan == null ? replacementCandidate(s, plans) : null;
    if (candidate != null) await askReplacement(context, repo, s, candidate);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDiscard() async {
    final l = context.l10n;
    final discard = await confirm(context, l.discardWorkout, body: l.discardSummaryBody, ok: l.discard, danger: true);
    if (!discard || !mounted) return;
    _discard();
  }

  void _discard() {
    _discarded = true;
    _notesDebounce?.cancel();
    _store.clearSummary();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _session;
    final history = ref.watch(sessionListProvider);
    final u = ref.watch(profileOrDefaultProvider).units;
    final xp = xpForSession(s);
    final prs = s.sport == Sport.gym ? newPrs(s, history) : <String>[];
    final target = ref.watch(profileOrDefaultProvider).weeklyTarget;
    final plans = ref.watch(planListProvider);
    final before = GameStats.compute(history.where((h) => h.id != s.id).toList(), target, plans: plans);
    final after = GameStats.compute([s, ...history.where((h) => h.id != s.id)], target, plans: plans);
    final newBadges = after.badges.where((b) => b.earned && !before.badges.firstWhere((x) => x.def.id == b.def.id).earned).toList();
    final levelUp = after.level.level > before.level.level;
    final outcome = summaryOutcome(s, plan: plans.where((p) => p.id == s.planId).firstOrNull, plannedSets: widget.plannedSets);
    final headline = switch (outcome) {
      SummaryOutcome.planDone => l.summaryPlanDone,
      SummaryOutcome.partial => l.summaryPartial,
      SummaryOutcome.tooLittle => l.summaryTooLittle,
      SummaryOutcome.free || SummaryOutcome.tooShort => l.summaryFree,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.summary), automaticallyImplyLeading: false),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  SportBadge(s.sport, size: 64, filled: true),
                  const SizedBox(height: 10),
                  Text(glueTitle(s.title), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (outcome != SummaryOutcome.tooShort)
                    Text(headline, key: const ValueKey('summaryHeadline'), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (outcome == SummaryOutcome.tooShort) ...[
              const SizedBox(height: 12),
              _TooShortCard(session: s, onDiscard: _discard, onSave: _save),
            ],
            const SizedBox(height: 16),
            SectionCard(
              child: Wrap(
                runSpacing: 16,
                children: [
                  _cell(StatTile(label: l.duration, value: clock(s.durationSec), icon: Icons.timer_outlined)),
                  if (s.sport == Sport.gym) ...[
                    _cell(StatTile(label: l.volume, value: u.volume(s.volume), icon: Sport.gym.icon, color: AppColors.gym)),
                    _cell(StatTile(label: l.sets, value: '${s.setsDone}', icon: Icons.check_circle_outline)),
                    _cell(StatTile(label: l.exercises, value: '${s.exercises.length}', icon: Icons.list)),
                  ] else ...[
                    _cell(
                      StatTile(
                        label: l.distance,
                        value: s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM),
                        icon: Icons.straighten,
                        color: s.sport.color,
                      ),
                    ),
                    _cell(
                      StatTile(
                        label: s.sport.usesPace ? l.avgPace : l.avgSpeed,
                        value: u.paceOrSpeed(s.sport, s.distanceM, s.durationSec),
                        icon: Icons.speed,
                      ),
                    ),
                    if (s.elevationM > 0) _cell(StatTile(label: l.elevation, value: '${s.elevationM.round()} m', icon: Icons.terrain)),
                  ],
                ],
              ),
            ),
            // A session that is about to be discarded needs no effort rating.
            if (outcome != SummaryOutcome.tooShort || tooShortHasWork(s)) ...[
              const SizedBox(height: 12),
              SectionCard(
                key: const ValueKey('summaryEffort'),
                title: l.summaryEffortTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RpePicker(
                      value: _rpe,
                      hint: l.summaryEffortHint,
                      onChanged: (v) {
                        setState(() => _rpe = v);
                        _persist();
                      },
                    ),
                    if (_prefill != null && _rpe == _prefill)
                      Text(l.summaryEffortPrefilled, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
            if (s.route.length > 1) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 200, child: RouteMap(session: s))),
            ],
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.brand),
                      const SizedBox(width: 8),
                      if (xp > 0)
                        Text('+$xp XP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brand))
                      else
                        Flexible(child: Text(l.noXpTooShort, key: const ValueKey('noXp'), style: Theme.of(context).textTheme.bodyMedium)),
                      const Spacer(),
                      if (levelUp)
                        Flexible(
                          child: Chip(
                            avatar: const Icon(Icons.arrow_upward_rounded, size: 16),
                            label: Text(l.levelN(after.level.level), overflow: TextOverflow.ellipsis),
                            backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                          ),
                        ),
                    ],
                  ),
                  if (prs.isNotEmpty) ...[
                    const Divider(height: 24),
                    // German display names (also for exercises without a curated name).
                    for (final e in s.exercises.where((e) => prs.contains(e.name)))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.trending_up_rounded, color: AppColors.success),
                        title: Text(l.newPr),
                        subtitle: Text(exName(context, e.exId, e.name)),
                      ),
                  ],
                  if (newBadges.isNotEmpty) ...[
                    const Divider(height: 24),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final b in newBadges)
                          Chip(avatar: Icon(b.def.icon, color: b.def.color, size: 18), label: Text(badgeTitle(l, b.def.id))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(hintText: l.notesHint),
              onChanged: (_) {
                _notesDebounce?.cancel();
                _notesDebounce = Timer(const Duration(seconds: 2), _persist);
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_alt_rounded), label: Text(l.saveWorkout)),
            const SizedBox(height: 4),
            // Discarding is visible here, not only behind the system back gesture.
            TextButton(
              key: const ValueKey('summaryDiscard'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: _confirmDiscard,
              child: Text(l.discardWorkout),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _cell(Widget c) => SizedBox(width: (MediaQuery.sizeOf(context).width - 64) / 2, child: c);
}

/// Title and text of the "too short" card, naming what is missing for this sport: gym only
/// knows time (a workout without a done set is discarded before the summary), run / ride
/// outdoors the GPS distance, the pool the counted laps.
/// Whether a too-short session still holds real training: done gym sets, or cardio of at least
/// five minutes (only the distance is missing). Then saving is the expected answer, not discarding.
bool tooShortHasWork(Session s) => s.sport == Sport.gym ? s.setsDone > 0 : s.durationSec >= 5 * 60;

(String, String) tooShortTexts(AppLocalizations l, Session s) {
  if (s.durationSec < 60) return (l.summaryTooShortTitle, s.sport == Sport.gym ? l.summaryTooShortGym : l.summaryTooShortTime);
  if (s.sport == Sport.swim) return (l.summaryNoLapsTitle, l.summaryNoLapsBody);
  return (l.summaryNoDistanceTitle, l.summaryNoDistanceBody);
}

/// "Too short to save?" with [Verwerfen] [Trotzdem speichern].
class _TooShortCard extends StatelessWidget {
  const _TooShortCard({required this.session, required this.onDiscard, required this.onSave});
  final Session session;
  final VoidCallback onDiscard, onSave;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (title, body) = tooShortTexts(l, session);
    return Container(
      key: const ValueKey('summaryTooShort'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.durationSec < 60
                    ? Icons.timer_off_outlined
                    : (session.sport == Sport.swim ? Icons.pool_rounded : Icons.location_off_outlined),
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, key: const ValueKey('summaryTooShortBody'), style: Theme.of(context).textTheme.bodySmall),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              // Nothing real done: discarding is the expected answer (primary), saving the exception.
              // Real sets / minutes done: saving is primary – they should not be thrown away by habit.
              if (tooShortHasWork(session)) ...[
                TextButton(key: const ValueKey('tooShortDiscard'), onPressed: onDiscard, child: Text(l.discard)),
                FilledButton(key: const ValueKey('tooShortSave'), onPressed: onSave, child: Text(l.save)),
              ] else ...[
                TextButton(key: const ValueKey('tooShortSave'), onPressed: onSave, child: Text(l.saveAnyway)),
                FilledButton(key: const ValueKey('tooShortDiscard'), onPressed: onDiscard, child: Text(l.discard)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String badgeTitle(AppLocalizations l, String id) => switch (id) {
  'first' => l.badgeFirst,
  'ten' => l.badgeTen,
  'fifty' => l.badgeFifty,
  'hundred' => l.badgeHundred,
  'ton' => l.badgeTon,
  'k5' => l.badge5k,
  'k10' => l.badge10k,
  'half' => l.badgeHalf,
  'marathon' => l.badgeMarathon,
  'century' => l.badgeCentury,
  'swim1k' => l.badgeSwim1k,
  'swim3k' => l.badgeSwim3k,
  'streak4' => l.badgeStreak4,
  'streak12' => l.badgeStreak12,
  'early' => l.badgeEarly,
  'allround' => l.badgeAllround,
  _ => id,
};
