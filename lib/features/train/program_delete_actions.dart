import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../services/program_deletion.dart';
import '../../widgets/common.dart';

/// Deleting programs from the UI – shared by every delete path (Train tab program menu, folder
/// "delete all", program editor), so the plan always keeps the workouts' exercises, loses the
/// gym-day assignments and the confirmation says so (R7-1 / R2).

/// Asks to delete [t] (naming what it does to the plan) and deletes it on OK; true if deleted.
Future<bool> confirmDeleteProgram(BuildContext context, WidgetRef ref, WorkoutTemplate t) async {
  final l = context.l10n;
  final usage = await programDeletionOf(ref, {t.id});
  if (!context.mounted) return false;
  final profile = ref.read(profileOrDefaultProvider);
  final body = [t.name, ...programDeletionNotes(context, usage, folder: false)].join('\n\n');
  if (!await confirm(context, l.deleteProgram, body: body, ok: l.delete, danger: true)) return false;
  deletePrograms(ref.read(repoProvider)!, profile, {t.id}, usage);
  return true;
}

/// What deleting the programs [ids] does to the plan ([programDeletion]).
Future<ProgramDeletion> programDeletionOf(WidgetRef ref, Set<String> ids) async {
  final templates = ref.read(templateListProvider);
  final athlete = ref.read(profileOrDefaultProvider).athlete;
  return programDeletion(ids, templates: templates, plans: await loadedPlans(ref), athlete: athlete, today: DateTime.now());
}

/// The planned workouts – awaited while they are still loading, so a delete or restore never
/// misses the plan.
Future<List<PlannedWorkout>> loadedPlans(WidgetRef ref) async {
  final now = ref.read(plansProvider);
  if (now.hasValue) return now.requireValue;
  try {
    return await ref.read(plansProvider.future).timeout(const Duration(seconds: 5));
  } catch (_) {
    return ref.read(planListProvider);
  }
}

/// The delete confirmation's lines about the plan: upcoming workouts using the programs and gym
/// days assigned to them.
List<String> programDeletionNotes(BuildContext context, ProgramDeletion d, {required bool folder}) {
  final l = context.l10n;
  return [
    if (d.upcoming > 0) folder ? l.folderDeleteUsed(d.upcoming) : l.programDeleteUsed(d.upcoming),
    if (d.assignedDays.isNotEmpty) l.programDeleteAssigned(weekdayNames(context, d.assignedDays)),
  ];
}

/// Deletes the programs [ids]; the planned workouts using them keep their exercises and their
/// assignments in the plan settings go ([d]).
void deletePrograms(Repository repo, UserProfile profile, Set<String> ids, ProgramDeletion d) {
  if (d.plans.isNotEmpty) repo.updateMany(plans: d.plans).ignore();
  if (d.athlete case final patch?) repo.saveProfile(profile.copyWith(athlete: profile.athlete.merge(patch)));
  repo.deleteTemplates(ids).ignore();
}

/// Short weekday names of [days] (1 = Monday): "Mo, Mi".
String weekdayNames(BuildContext context, List<int> days) {
  final f = DateFormat.E(context.localeName);
  final monday = startOfWeek(DateTime.now());
  return days.map((d) => f.format(addDays(monday, d - 1))).join(', ');
}
