import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../calendar/auto_adjust.dart';
import '../shell/health_sync.dart';
import '../../services/plan_match.dart';
import '../../services/gym_tools.dart' show sessionRpeFromEfforts;
import '../../services/insights.dart';
import '../../services/workout_store.dart';
import 'gym_session_page.dart' show capitalize;
import '../../widgets/common.dart';
import '../../widgets/rpe_picker.dart';
import 'route_map.dart';

/// Shown after finishing a session: rate effort first (it adapts the plan), see XP / PRs, then save.
///
/// The draft (incl. rating and notes) is kept in [WorkoutStore] until it is saved or
/// discarded, so a finished workout survives the app being killed on this page.
class SessionSummaryPage extends ConsumerStatefulWidget {
  const SessionSummaryPage({super.key, required this.draft, this.restored = false});
  final Session draft;

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
  );

  void _save() {
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirm(context, l.discardWorkout, body: l.discardSummaryBody, ok: l.discard, danger: true);
        if (!discard || !context.mounted) return;
        _discarded = true;
        _notesDebounce?.cancel();
        _store.clearSummary();
        Navigator.pop(context);
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
                  Text(l.greatJob, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Wrap(
                runSpacing: 16,
                children: [
                  _cell(StatTile(label: l.duration, value: clock(s.durationSec), icon: Icons.timer_outlined)),
                  if (s.sport == Sport.gym) ...[
                    _cell(
                      StatTile(label: l.volume, value: u.weight(s.volume, digits: 0), icon: Icons.fitness_center, color: AppColors.gym),
                    ),
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
                      Text('+$xp XP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brand)),
                      const Spacer(),
                      if (levelUp)
                        Chip(
                          avatar: const Icon(Icons.arrow_upward_rounded, size: 16),
                          label: Text(l.levelN(after.level.level)),
                          backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                        ),
                    ],
                  ),
                  if (prs.isNotEmpty) ...[
                    const Divider(height: 24),
                    for (final p in prs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.trending_up_rounded, color: AppColors.success),
                        title: Text(l.newPr),
                        subtitle: Text(capitalize(p)),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _cell(Widget c) => SizedBox(width: (MediaQuery.sizeOf(context).width - 64) / 2, child: c);
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
