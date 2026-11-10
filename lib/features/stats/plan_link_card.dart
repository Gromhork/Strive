import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
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
                      ref.read(repoProvider)?.updatePlan(candidate.id, {'status': 'done', 'sessionId': s.id});
                      toast(context, l.replacementDone(candidate.title));
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
    return ratio < 0.8 ? l.coachShorter : l.coachLonger;
  }
}
