import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/plan_log.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/readiness.dart';
import '../../widgets/common.dart';
import 'auto_adjust.dart' show amountLabel;

/// Whether "Not feeling 100 %?" is offered: a planned endurance or gym workout from today on (no race).
bool offersNotFit(PlannedWorkout p, DateTime now) =>
    p.status == 'planned' && !p.isDone && !dayOnly(p.date).isBefore(dayOnly(now)) && p.intensity != 'race';

String readinessHintText(AppLocalizations l, ReadinessHint h) => switch (h) {
  ReadinessHint.aboveNeck => l.notFitHintAboveNeck,
  ReadinessHint.returnRule => l.notFitHintReturn,
  ReadinessHint.painRule => l.notFitHintPainRule,
  ReadinessHint.seeDoctor => l.notFitHintDoctor,
  ReadinessHint.swapped => l.notFitHintSwapped,
  ReadinessHint.keyToEasy => l.notFitHintKeyEasy,
  ReadinessHint.shorter => l.notFitHintShorter,
  ReadinessHint.gymLighter => l.notFitHintGymLighter,
  ReadinessHint.gymShorter => l.notFitHintGymShorter,
  ReadinessHint.timeStructure => l.notFitHintTime,
  ReadinessHint.fits => l.notFitNoChange,
};

/// Opens the sheet for [p]; an applied proposal is saved, logged in the plan history
/// (source 'readiness') and can be undone from the snack bar or the history.
Future<void> showNotFitSheet(BuildContext context, WidgetRef ref, PlannedWorkout p, {List<GymExercise> exercises = const []}) async {
  final advisor = ReadinessAdvisor(
    context.l10n,
    ref.read(profileOrDefaultProvider),
    plans: ref.read(planListProvider),
    sessions: ref.read(sessionListProvider),
    now: DateTime.now(),
  );
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final plan = await showModalBottomSheet<ReadinessPlan>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => NotFitSheet(plan: p, propose: (k, m) => advisor.propose(p, k, minutes: m, exercises: exercises)),
  );
  final repo = ref.read(repoProvider);
  if (plan == null || plan.isEmpty || repo == null) return;
  repo.savePlans([for (final c in plan.changes) c.$2]);
  repo.logPlanChange(PlanLogEntry.of('readiness', plan.changes, reason: plan.kind.name));
  undoToast(
    messenger,
    text: l.notFitApplied,
    undoLabel: l.undo,
    icon: Icons.healing_rounded,
    onUndo: () => repo.savePlans([for (final c in plan.changes) c.$1]),
  );
}

class NotFitSheet extends StatefulWidget {
  const NotFitSheet({super.key, required this.plan, required this.propose});
  final PlannedWorkout plan;
  final ReadinessPlan Function(Readiness kind, int? minutes) propose;

  @override
  State<NotFitSheet> createState() => _NotFitSheetState();
}

class _NotFitSheetState extends State<NotFitSheet> {
  Readiness? _kind;
  int? _minutes;

  List<int> get _options => [
    for (final m in const [15, 20, 30, 45, 60, 75, 90])
      if (m < widget.plan.durationMin) m,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final k = _kind;
    final proposal = k == null ? null : widget.propose(k, k == Readiness.time ? _minutes : null);
    final labels = {
      Readiness.sick: (l.notFitSick, Icons.sick_outlined),
      Readiness.pain: (l.notFitPain, Icons.personal_injury_outlined),
      Readiness.tired: (l.notFitTired, Icons.battery_2_bar_rounded),
      Readiness.time: (l.notFitTime, Icons.timer_outlined),
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  Text(l.notFitButton, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(l.notFitIntro, style: t.bodySmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in labels.entries)
                        ChoiceChip(
                          key: ValueKey('notFit_${e.key.name}'),
                          avatar: Icon(e.value.$2, size: 18),
                          label: Text(e.value.$1),
                          selected: k == e.key,
                          showCheckmark: false,
                          onSelected:
                              (_) => setState(() {
                                _kind = e.key;
                                if (e.key == Readiness.time && _options.isNotEmpty) _minutes ??= _options.last;
                              }),
                        ),
                    ],
                  ),
                  if (k == Readiness.time && _options.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(l.notFitMinutes, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in _options)
                          ChoiceChip(
                            key: ValueKey('notFitMin_$m'),
                            label: Text('$m min'),
                            selected: _minutes == m,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _minutes = m),
                          ),
                      ],
                    ),
                  ],
                  if (proposal != null) ...[
                    const SizedBox(height: 16),
                    if (proposal.changes.isNotEmpty) ...[
                      Text(l.notFitPreview, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      for (final c in proposal.changes) _ChangeRow(before: c.$1, after: c.$2),
                    ],
                    const SizedBox(height: 6),
                    for (final h in proposal.hints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              h == ReadinessHint.seeDoctor || h == ReadinessHint.aboveNeck
                                  ? Icons.medical_services_outlined
                                  : Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: h == ReadinessHint.seeDoctor ? AppColors.danger : AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(readinessHintText(l, h), style: const TextStyle(fontSize: 13, height: 1.3))),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('notFitApply'),
                      onPressed: proposal == null || proposal.isEmpty ? null : () => Navigator.pop(context, proposal),
                      child: Text(l.apply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends ConsumerWidget {
  const _ChangeRow({required this.before, required this.after});
  final PlannedWorkout before, after;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(profileOrDefaultProvider);
    final df = DateFormat.MMMEd(context.localeName);
    final skipped = after.status == 'skipped';
    String amount(PlannedWorkout p) {
      final sets = p.exercises.fold(0, (x, e) => x + e.workSets.length);
      return [amountLabel(p, profile), if (p.sport == Sport.gym && sets > 0) '$sets ${l.sets}'].join(' · ');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(after.sport.icon, color: after.sport.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  after.title == before.title ? before.title : '${before.title} → ${after.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, decoration: skipped ? TextDecoration.lineThrough : null),
                ),
                Text(
                  '${df.format(after.date)} · ${skipped ? l.planLogDropped : '${amount(before)} → ${amount(after)}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
