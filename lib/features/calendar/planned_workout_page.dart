import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_media.dart';
import '../session/start_helpers.dart';
import '../session/step_list.dart';
import '../session/zone_info.dart' show ZoneInfoButton;
import '../stats/session_detail_page.dart';
import 'plan_editor.dart';

String phaseLabel(AppLocalizations l, String? phase) => switch (phase) {
  'base' => l.phaseBase,
  'build' => l.phaseBuild,
  'peak' => l.phasePeak,
  'taper' => l.phaseTaper,
  'recovery' => l.phaseRecovery,
  _ => '',
};

/// Detail view of a planned workout: structure, targets, explanation, start.
class PlannedWorkoutPage extends ConsumerWidget {
  const PlannedWorkoutPage({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(planListProvider).where((x) => x.id == planId).firstOrNull;
    if (p == null) return Scaffold(appBar: AppBar());
    final u = ref.watch(profileOrDefaultProvider).units;
    final template = ref.watch(templateListProvider).where((t) => t.id == p.templateId).firstOrNull;
    final t = Theme.of(context).textTheme;
    final phase = phaseLabel(l, p.phase);
    final exercises = p.exercises.isNotEmpty ? p.exercises : (template?.exercises ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.MMMEd(context.localeName).format(p.date)),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showPlanEditor(context, ref, existing: p)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: [p.sport.color.withValues(alpha: 0.3), p.sport.color.withValues(alpha: 0.06)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SportBadge(p.sport, size: 52, filled: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              '${p.durationMin} min',
                              if (p.distanceKm != null && p.distanceKm! > 0) u.dist(p.distanceKm! * 1000, digits: 1),
                              intensityLabel(l, p.intensity),
                            ].join(' · '),
                            style: t.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (phase.isNotEmpty || p.isKey) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (phase.isNotEmpty) Chip(label: Text(phase), visualDensity: VisualDensity.compact, avatar: const Icon(Icons.timeline, size: 16)),
                      if (p.isKey)
                        Chip(
                          label: Text(l.keySession),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                        ),
                    ],
                  ),
                ],
                if (p.steps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  WorkoutProfileBar(steps: p.steps, sport: p.sport, height: 50),
                ],
              ],
            ),
          ),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 20, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(p.description, style: const TextStyle(height: 1.4))),
              ],
            ),
          ],
          if (p.steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(l.workoutStructure, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ZoneInfoButton(sport: p.sport, profile: ref.watch(profileOrDefaultProvider)),
              ],
            ),
            const SizedBox(height: 8),
            StepList(steps: p.steps, sport: p.sport, units: u),
          ],
          if (p.sport == Sport.gym) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(l.exercises, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                if (!p.isDone)
                  TextButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(l.adjustExercises),
                    onPressed: () => showPlanEditor(context, ref, existing: p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in exercises)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ExerciseMedia(exId: e.exId, animated: false, size: 48, radius: 12),
                title: Text(e.name.isEmpty ? '' : e.name[0].toUpperCase() + e.name.substring(1)),
                subtitle: Text('${e.workSets.length} × ${e.workSets.isEmpty ? '' : e.workSets.first.reps}'),
              ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        height: 56,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: p.isDone ? AppColors.success : p.sport.color, foregroundColor: Colors.black87),
          onPressed:
              p.isDone
                  ? (p.sessionId == null
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: p.sessionId!))))
                  : () => startPlanned(context, ref, p),
          icon: Icon(p.isDone ? Icons.check_rounded : Icons.play_arrow_rounded),
          label: Text(p.isDone ? l.viewSession : l.startWorkout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
