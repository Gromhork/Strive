import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/cardio_progression.dart';

/// App-wide messenger, so the "plan adjusted – undo" notice survives the page that saved
/// the session being popped.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Applies the small automatic plan adjustments ([AutoAdjuster]) after sessions were linked
/// to their planned workouts – the phone recording, a manual entry or a watch import – and
/// shows one notice with "Undo". Idempotent: a session that already adjusted the plan is
/// ignored. Returns the applied changes.
List<AutoChange> autoAdjustAfterSessions({
  required Repository repo,
  required AppLocalizations l,
  required UserProfile profile,
  required List<PlannedWorkout> plans,
  required List<Session> sessions,
  required List<(Session, PlannedWorkout)> done,
  bool notify = true,
}) {
  final now = DateTime.now();
  final local = {for (final p in plans) p.id: p};
  final allSessions = [...sessions.where((x) => !done.any((d) => d.$1.id == x.id)), for (final d in done) d.$1];
  final applied = <String, AutoChange>{};
  for (final (s, p) in done) {
    if (!s.sport.isCardio) continue;
    // The linked plan counts as done from now on.
    local[p.id] = PlannedWorkout.fromMap(p.id, {...p.toMap(), 'status': 'done', 'sessionId': s.id});
    final changes = AutoAdjuster(profile, plans: local.values.toList(), sessions: allSessions, now: now).afterSession(s, local[p.id]!);
    for (final c in changes) {
      local[c.after.id] = c.after;
      // Keep the first "before" (the notice shows the change from what the athlete saw).
      applied[c.after.id] = applied.containsKey(c.after.id) ? AutoChange(applied[c.after.id]!.before, c.after, c.reason) : c;
    }
  }
  if (applied.isEmpty) return const [];
  final list = applied.values.toList();
  repo.updateMany(plans: {for (final c in list) c.after.id: c.update});
  if (notify) {
    final c = list.first;
    final text =
        list.length == 1
            ? l.autoAdjSnack(
              c.after.title,
              DateFormat.MMMEd(l.localeName).format(c.after.date),
              amountLabel(c.after, profile),
              amountLabel(c.before, profile),
            )
            : l.autoAdjSnackMany(list.length);
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(label: l.undo, onPressed: () => undoAutoAdjust(repo, [for (final c in list) c.after])),
        ),
      );
  }
  return list;
}

/// Restores the original values of automatically adjusted workouts.
void undoAutoAdjust(Repository repo, List<PlannedWorkout> plans) {
  final updates = {
    for (final p in plans)
      if (p.auto != null) p.id: AutoAdjuster.undoUpdate(p),
  };
  if (updates.isNotEmpty) repo.updateMany(plans: updates);
}

/// "8 km" for runs, "1500 m" for swims, else "45 min" (as [AutoAdjuster] measures them).
String amountLabel(PlannedWorkout p, UserProfile profile) => switch (p.sport) {
  _ when (p.distanceKm ?? 0) <= 0 => '${p.durationMin} min',
  Sport.run => profile.units.dist(p.distanceKm! * 1000, digits: 1),
  Sport.swim => profile.units.swimDist(p.distanceKm! * 1000),
  _ => '${p.durationMin} min',
};

/// Reason text of an automatic adjustment.
String autoAdjustReason(AppLocalizations l, String reason) => switch (reason) {
  'longCutShort' => l.autoAdjLongCutShort,
  'longHard' => l.autoAdjLongHard,
  'easyTooFast' => l.autoAdjEasyTooFast,
  'easyHard' => l.autoAdjEasyHard,
  'qualityHard' => l.autoAdjQualityHard,
  'qualityEasy' => l.autoAdjQualityEasy,
  _ => l.autoAdjTitle,
};

/// Marker on the planned workout page: what was changed automatically and why, with undo.
class AutoAdjustCard extends StatelessWidget {
  const AutoAdjustCard({super.key, required this.plan, required this.profile, required this.onUndo});
  final PlannedWorkout plan;
  final UserProfile profile;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = plan.auto!;
    final original = PlannedWorkout(
      id: plan.id,
      date: plan.date,
      sport: plan.sport,
      title: plan.title,
      durationMin: a.durationMin,
      distanceKm: a.distanceKm,
    );
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, size: 20, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(l.autoAdjTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 6),
          Text(autoAdjustReason(l, a.reason), style: const TextStyle(height: 1.35)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.autoAdjOriginal(
                    [
                      amountLabel(original, profile),
                      if ((a.distanceKm ?? 0) > 0 && plan.sport != Sport.ride) '${a.durationMin} min',
                    ].join(' · '),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('autoAdjUndo'),
                onPressed: onUndo,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(l.undo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
