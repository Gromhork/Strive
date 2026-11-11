import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/compliance.dart' show planCompliance;
import '../../services/gym_tools.dart' show ProgressionKind;
import '../../services/plan_text.dart';
import '../../widgets/common.dart';
import '../../data/models.dart';
import '../../data/exercise_names_de.dart';
import '../../widgets/exercise_media.dart';
import '../../widgets/plan_amount.dart';
import '../../widgets/prescription.dart';
import '../session/manual_entry_page.dart';
import '../session/start_helpers.dart';
import '../session/step_list.dart';
import '../session/zone_info.dart' show ZoneInfoButton;
import '../stats/session_detail_page.dart';
import 'auto_adjust.dart';
import '../../widgets/term_info.dart';
import 'not_fit_sheet.dart';
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

  /// Opens the editor; deleting the workout there also closes this page (no blank page).
  static Future<void> _edit(BuildContext context, WidgetRef ref, PlannedWorkout p) async {
    final r = await showPlanEditor(context, ref, existing: p);
    if (r == planDeleted && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(planListProvider).where((x) => x.id == planId).firstOrNull;
    // Deleted (e.g. from its editor) or replaced: say so instead of a blank page.
    if (p == null) return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.event_busy_rounded, text: l.planGone));
    final u = ref.watch(profileOrDefaultProvider).units;
    final template = ref.watch(templateListProvider).where((t) => t.id == p.templateId).firstOrNull;
    final t = Theme.of(context).textTheme;
    final phase = phaseLabel(l, p.phase);
    final exercises = p.exercises.isNotEmpty ? p.exercises : (template?.exercises ?? const []);
    // Watched unconditionally at the top: a first subscription inside `isDone && …` happened in
    // the build right after "mark as done" and flushed pending provider updates during that build
    // ("setState() or markNeedsBuild() called during build").
    final profile = ref.watch(profileOrDefaultProvider);
    final linked = ref.watch(planSessionsProvider)[p.id];
    final prescriber = ref.watch(loadPrescriberProvider);
    final compliance = planCompliance(p, linked, profile: profile);
    // A start too short to count (< 10 % of the plan) leaves the workout open.
    final done = p.isDone && !compliance.notCounted;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.MMMEd(context.localeName).format(p.date)),
        actions: [IconButton(tooltip: l.edit, icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, p))],
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
                          Text(glueTitle(p.title), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              planAmountText(p, ref.watch(profileOrDefaultProvider), templates: ref.watch(templateListProvider)),
                              if (p.sport != Sport.gym) intensityLabel(l, p.intensity),
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
                      if (phase.isNotEmpty)
                        ActionChip(
                          label: Text(phase),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.timeline, size: 16),
                          onPressed: () => showTermInfo(context, p.phase == 'recovery' ? Term.deloadWeek : Term.phases),
                        ),
                      if (p.isKey)
                        ActionChip(
                          label: Text(l.keySession),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                          onPressed: () => showTermInfo(context, Term.keySession),
                        ),
                    ],
                  ),
                ],
                if (p.steps.isNotEmpty) ...[const SizedBox(height: 14), WorkoutProfileBar(steps: p.steps, sport: p.sport, height: 50)],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              // Labelled – an unlabelled icon in the app bar was not understood.
              if (!done)
                OutlinedButton.icon(
                  key: const ValueKey('logManuallyButton'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManualEntryPage(plan: p))),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(l.logAsDone),
                ),
              if (offersNotFit(p, DateTime.now()))
                OutlinedButton.icon(
                  key: const ValueKey('notFitButton'),
                  onPressed: () => showNotFitSheet(context, ref, p, exercises: exercises),
                  icon: const Icon(Icons.healing_rounded, size: 18),
                  label: Text(l.notFitButton),
                ),
              OutlinedButton.icon(
                key: const ValueKey('askCoachButton'),
                onPressed: () {
                  ref
                      .read(coachDraftProvider.notifier)
                      .set(l.coachExplainWorkout(p.title, DateFormat.MMMMEEEEd(context.localeName).format(p.date)));
                  ref.read(navIndexProvider.notifier).set(4);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l.askCoachAbout),
              ),
            ],
          ),
          // A session started from this workout but too short to count: say so and link it – the
          // workout stays open, but the attempt is not invisible.
          if (linked != null && compliance.notCounted) ...[
            const SizedBox(height: 12),
            Material(
              key: const ValueKey('notCountedSession'),
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: linked.id))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.close_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.complianceNotCounted(compliance.pct ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              l.plannedNotCountedSub(
                                DateFormat.MMMEd(context.localeName).format(linked.start),
                                humanDuration(linked.durationSec),
                              ),
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(l.viewSession, style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.brand),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (p.auto != null && !p.isDone) ...[
            const SizedBox(height: 16),
            AutoAdjustCard(
              plan: p,
              profile: ref.watch(profileOrDefaultProvider),
              onUndo: () {
                undoAutoAdjust(ref.read(repoProvider)!, [p]);
                toast(context, l.autoAdjUndone);
              },
            ),
          ],
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 20, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(planDescription(p.description, l), style: const TextStyle(height: 1.4))),
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
                    onPressed: () => _edit(context, ref, p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in exercises)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ExerciseMedia(exId: e.exId, animated: false, size: 48, radius: 12),
                title: Text(exName(context, e.exId, e.name)),
                subtitle: Builder(
                  builder: (_) {
                    final rx = p.isDone ? null : prescriber.forExercise(e, phase: p.phase);
                    final reps =
                        e.repMin != null && e.repMax != null
                            ? '${e.repMin}–${e.repMax}'
                            : '${e.workSets.isEmpty ? '' : e.workSets.first.reps}';
                    final line = Text(
                      ['${e.workSets.length} × $reps', if (rx != null && rx.weight > 0) prescriptionLabel(l, rx, u)].join(' · '),
                    );
                    // What changes since last time (from the user's own history only).
                    final why = rx != null && rx.fromHistory ? prescriptionReason(l, rx) : null;
                    if (why == null) return line;
                    final (icon, color) = switch (rx!.progression) {
                      ProgressionKind.increase => (Icons.trending_up_rounded, AppColors.success),
                      ProgressionKind.addReps => (Icons.add_circle_outline_rounded, AppColors.success),
                      ProgressionKind.deload || ProgressionKind.reset => (Icons.trending_down_rounded, AppColors.warning),
                      _ => (Icons.pause_circle_outline_rounded, AppColors.brand),
                    };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line,
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 14, color: color)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(why, style: TextStyle(fontSize: 12, color: color))),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        height: 56,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: done ? AppColors.success : p.sport.color, foregroundColor: Colors.black87),
          onPressed:
              done
                  ? (p.sessionId == null
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: p.sessionId!))))
                  : () => startPlanned(context, ref, p),
          icon: Icon(done ? Icons.check_rounded : Icons.play_arrow_rounded),
          label: Text(done ? l.viewSession : l.startWorkout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
