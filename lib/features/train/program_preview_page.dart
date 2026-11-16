import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/exercise_names_de.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/zones.dart' show estimateStepsSec;
import '../../widgets/common.dart';
import '../../widgets/exercise_media.dart';
import '../../widgets/prescription.dart' show bodyweightLoad;
import '../../widgets/superset_group.dart';
import '../session/gym_session_page.dart' show exerciseSummary;
import '../session/start_helpers.dart';
import '../session/step_list.dart';
import 'template_editor_page.dart';

/// "Today: 3 × 6 @ 72.5 kg" for an exercise whose sets were filled by the load
/// prescriber – the same line the workout shows, so preview and workout agree.
String plannedSetsLine(AppLocalizations l, GymExercise e, Units u) {
  final work = e.sets.where((s) => !s.warmup && s.type != SetType.drop).toList();
  if (work.isEmpty) return l.programPreviewSets(e.sets.length);
  // Timed holds: "3 × 45 s · +10 kg".
  if (e.isTimed) return exerciseSummary(l, e, u, range: e.holdRange);
  final top = work.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  final load = e.bw == true ? bodyweightLoad(l.bodyweight, top, u) : (top > 0 ? u.weight(top) : l.bodyweight);
  // The same "4 × 5–8" as the planned workout and the editor (the rep range of the program),
  // with today's load – not "4 × 5 @ 57,5 kg" here and "4 × 5–8" there.
  if (e.repMin != null && e.repMax != null) return '${work.length} × ${e.repMin}–${e.repMax} · $load';
  final reps = work.map((s) => s.reps).toList();
  return reps.toSet().length == 1 ? l.rxToday(reps.length, reps.first, load) : l.rxTodayList(reps.join(' · '), load);
}

/// Duration of a program as every list shows it: endurance programs with steps from the
/// steps ([estimateStepsSec], like the planned workouts' "≈ 38 min"), gym from the program.
int programMinutes(WorkoutTemplate t, UserProfile p) =>
    t.sport != Sport.gym && t.steps.isNotEmpty ? (estimateStepsSec(t.steps, t.sport, p) / 60).round().clamp(5, 400) : t.estimatedMinutes;

/// Read-only view of a program with a big "Start" button; editing sits behind the pencil.
class ProgramPreviewPage extends ConsumerWidget {
  const ProgramPreviewPage({super.key, required this.template});
  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    // Follow edits made in the editor (and close when the program was deleted there).
    final list = ref.watch(templateListProvider);
    final p = list.where((x) => x.id == template.id).firstOrNull ?? template;
    final profile = ref.watch(profileOrDefaultProvider);
    final u = profile.units;
    // The same prescription the workout will start with.
    final exercises = p.sport == Sport.gym ? ref.watch(loadPrescriberProvider).apply(p.exercises) : const <GymExercise>[];
    final sets = exercises.fold<int>(0, (a, e) => a + e.sets.length);
    final minutes = programMinutes(p, profile);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, height: 1.15)),
        actions: [
          IconButton(
            key: const ValueKey('editProgram'),
            tooltip: l.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditorPage(template: p))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              SportBadge(p.sport),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  [
                    if (p.sport == Sport.gym) '${p.exercises.length} ${l.exercises}',
                    if (p.sport == Sport.gym) l.programPreviewSets(sets),
                    '≈ $minutes min',
                  ].join(' · '),
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
          if (p.description.isNotEmpty) ...[const SizedBox(height: 12), Text(p.description, style: t.bodyMedium?.copyWith(height: 1.4))],
          const SizedBox(height: 16),
          if (p.sport == Sport.gym)
            ...groupedExerciseWidgets(exercises, bottomInset: 8, (i) {
              final e = exercises[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ExerciseMedia(exId: e.exId, animated: false, size: 48, radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exName(context, e.exId, e.name),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(plannedSetsLine(l, e, u), style: t.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
          else if (p.steps.isNotEmpty)
            StepList(steps: p.steps, sport: p.sport, units: u)
          else
            Text(
              [if (p.targetKm != null) u.dist(p.targetKm! * 1000), '≈ $minutes min', intensityLabel(l, p.intensity)].join(' · '),
              style: t.bodyMedium,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('startProgram'),
              style: FilledButton.styleFrom(
                backgroundColor: p.sport.color,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.start),
              onPressed: () async {
                // Start on top of the preview, then drop the preview so "back" from the
                // workout returns to the program list.
                final route = ModalRoute.of(context);
                if (p.sport == Sport.gym) {
                  await startGym(context, ref, title: p.name, template: p);
                } else {
                  await showCardioStart(context, ref, p.sport, title: p.name, steps: p.steps);
                }
                if (route != null && route.isActive && !route.isCurrent && context.mounted) Navigator.removeRoute(context, route);
              },
            ),
          ),
        ),
      ),
    );
  }
}
