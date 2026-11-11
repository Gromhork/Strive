import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/plan_log.dart';
import '../../data/repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/compliance.dart';
import '../../services/plan_match.dart';
import '../../widgets/common.dart';
import '../../widgets/plan_amount.dart';
import '../calendar/recalibrate_sheet.dart';

/// RPE a planned intensity is meant to feel like (session-RPE, training-science §3.4).
int expectedRpe(String intensity) => switch (intensity) {
  'tempo' => 7,
  'intervals' => 8,
  'race' => 9,
  'moderate' => 5,
  _ => 4, // easy, long, technique, recovery
};

/// "Ja" to "Als Ersatz für … werten?": ticks [plan] off with session [s], records it in the
/// plan history ("Planverlauf", undoable there) and offers undo in a snack bar.
void confirmReplacement(Repository repo, AppLocalizations l, Session s, PlannedWorkout plan, {ScaffoldMessengerState? messenger}) {
  final after = PlannedWorkout.fromMap(plan.id, {...plan.toMap(), 'status': 'done', 'sessionId': s.id});
  repo.updatePlan(plan.id, {'status': 'done', 'sessionId': s.id});
  repo.logPlanChange(PlanLogEntry.of('replace', [(plan, after)]));
  if (messenger != null) {
    undoToast(
      messenger,
      text: l.replacementDone(plan.title),
      undoLabel: l.undo,
      icon: Icons.swap_horiz_rounded,
      onUndo: () => undoReplacement(repo, plan.id),
    );
  }
}

/// Undoes [confirmReplacement]: the workout is open again; the session keeps its plan
/// reference, so the question comes back on its detail page.
void undoReplacement(Repository repo, String planId) => repo.updatePlan(planId, {'status': 'planned', 'sessionId': null});

/// "Als Ersatz für Langer Lauf (Sa) werten?" as a dialog – right after saving a session that
/// was started from a workout days away (the summary closes after saving). True = yes.
Future<void> askReplacement(BuildContext context, Repository repo, Session s, PlannedWorkout candidate) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final yes = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder:
        (c) => AlertDialog(
          key: const ValueKey('replacementDialog'),
          icon: Icon(Icons.swap_horiz_rounded, color: candidate.sport.color),
          title: Text(l.countAsReplacement(candidate.title, DateFormat.E(l.localeName).format(candidate.date))),
          content: Text(l.countAsReplacementSub),
          actions: [
            TextButton(key: const ValueKey('replacementNo'), onPressed: () => Navigator.pop(c, false), child: Text(l.no)),
            FilledButton(key: const ValueKey('replacementYes'), onPressed: () => Navigator.pop(c, true), child: Text(l.yes)),
          ],
        ),
  );
  if (yes == true) {
    confirmReplacement(repo, l, s, candidate, messenger: messenger);
  } else if (yes == false) {
    repo.updateSession(s.id, {'planId': null});
  }
}

/// What a session did to the plan, on the session detail page:
/// * fulfils a planned workout: "Geplant: Langer Lauf · 45 min · 7,5 km → 78 % erfüllt", a
///   coach sentence and – when it felt much harder than intended – "Plan überprüfen";
/// * was started from a workout more than a day away: "Als Ersatz für Langer Lauf (Sa)
///   werten?" [Ja] [Nein].
class PlanLinkCard extends ConsumerWidget {
  const PlanLinkCard({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = session;
    final plans = ref.watch(planListProvider);
    final linked = ref.watch(planSessionsProvider).entries.where((e) => e.value.id == s.id).map((e) => e.key).firstOrNull;
    final plan = plans.where((p) => p.id == linked).firstOrNull;
    final candidate = plan == null ? replacementCandidate(s, plans) : null;
    if (plan == null && candidate == null) return const SizedBox.shrink();
    final day = DateFormat.E(context.localeName);
    final theme = Theme.of(context);

    if (candidate != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SectionCard(
          key: const ValueKey('replacementCard'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: candidate.sport.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.countAsReplacement(candidate.title, day.format(candidate.date)),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l.countAsReplacementSub, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('replacementNo'),
                    onPressed: () => ref.read(repoProvider)?.updateSession(s.id, {'planId': null}),
                    child: Text(l.no),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('replacementYes'),
                    onPressed: () {
                      final repo = ref.read(repoProvider);
                      if (repo != null) confirmReplacement(repo, l, s, candidate, messenger: ScaffoldMessenger.of(context));
                    },
                    child: Text(l.yes),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final p = plan!;
    final profile = ref.watch(profileOrDefaultProvider);
    final ratio = complianceRatio(p, s);
    final c = planCompliance(p, s);
    final moved = !sameDay(p.date, s.start);
    final hard = s.rpe != null && s.rpe! >= expectedRpe(p.intensity) + 3;
    final coach = _coachLine(l, p, s, ratio, hard);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        key: const ValueKey('planLinkCard'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ComplianceRing(compliance: c),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          l.plannedLine(p.title, planAmountText(p, profile, templates: ref.watch(templateListProvider))),
                          if (ratio != null) l.fulfilledPct(Units.pct(ratio * 100)),
                        ].join(' → '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (moved)
                        Text(l.replacesDayWorkout(day.format(p.date)), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.brand)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(coach, key: const ValueKey('planLinkCoach'), style: theme.textTheme.bodyMedium),
            // A replacement (session days away from the workout) can be taken back here too.
            if (!withinLinkDays(p.date, s.start))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('replacementUndo'),
                  onPressed: () {
                    final repo = ref.read(repoProvider);
                    if (repo == null) return;
                    undoReplacement(repo, p.id);
                    toast(context, l.replacementUndone(p.title));
                  },
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(l.replacementUndo),
                ),
              ),
            if (hard) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('planLinkReview'),
                  onPressed: () => showRecalibration(context, ref),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text(l.recalButton),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _coachLine(AppLocalizations l, PlannedWorkout p, Session s, double? ratio, bool hard) {
    if (hard) return l.coachRpeHigh(p.title, s.rpe!);
    if (ratio == null || (ratio >= 0.8 && ratio <= 1.2)) return l.coachAsPlanned;
    // 100 m of a 1500 m swim is not "a bit shorter – no problem": say honestly how much it was.
    if (ratio < 0.5) return l.coachMuchShorter(Units.pct(ratio * 100));
    return ratio < 0.8 ? l.coachShorter : l.coachLonger;
  }
}
