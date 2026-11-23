import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/plan_service.dart';
import '../../widgets/common.dart';

/// Whether there is a plan to delete: an open workout ([PlanService.openWorkouts]) in the calendar. ("Plan löschen"
/// is offered only then – after deleting, the calendar holds only completed workouts.)
bool hasPlanToDelete(WidgetRef ref) =>
    PlanService.openWorkouts(
      ref.read(planListProvider),
      ref.read(sessionListProvider),
      profile: ref.read(profileOrDefaultProvider),
    ).isNotEmpty;

/// "Plan löschen" (owner round 10; calendar ⋮ menu, plan settings): asks with the number of open workouts that go
/// and what stays (completed workouts, recordings, stats, goals), deletes them ([PlanService.deletePlan]) and offers
/// undo in the snackbar. Returns true when the plan was deleted. The race goal is kept: a goal without a plan is a
/// normal state (Home offers "Plan erstellen"), and deleting a goal belongs to the goal page.
Future<bool> confirmDeletePlan(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final repo = ref.read(repoProvider);
  if (repo == null) return false;
  final open = PlanService.openWorkouts(
    ref.read(planListProvider),
    ref.read(sessionListProvider),
    profile: ref.read(profileOrDefaultProvider),
  );
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (c) => AlertDialog(
          key: const ValueKey('deletePlanDialog'),
          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
          title: Text(l.deletePlanTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.deletePlanBody(open.length), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(l.deletePlanKeeps, style: Theme.of(c).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(
              key: const ValueKey('deletePlanOk'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.deletePlan),
            ),
          ],
        ),
  );
  if (ok != true || !context.mounted) return false;
  // Read after the dialog (the plan may have changed meanwhile), through the container: the undo may run after
  // the calling page is gone (plan settings close).
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final saveMeta = container.read(profileProvider).value != null;
  final d = PlanService.deletePlan(
    repo: repo,
    profile: container.read(profileOrDefaultProvider),
    existing: container.read(planListProvider),
    sessions: container.read(sessionListProvider),
    saveMeta: saveMeta,
  );
  if (d == null) return false;
  undoToast(
    messenger,
    text: l.planDeletedToast(d.removed.length),
    undoLabel: l.undo,
    icon: Icons.delete_sweep_outlined,
    onUndo: () => PlanService.undoDelete(repo, d, container.read(profileOrDefaultProvider), saveMeta: saveMeta),
  );
  return true;
}
