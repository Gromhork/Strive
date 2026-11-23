import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/event_distances.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/plan_service.dart';
import '../../widgets/common.dart';
import '../onboarding/onboarding_page.dart';
import 'feasibility_card.dart';
import 'replace_plan_dialog.dart';

/// The athlete settings a feasibility option ([FeasibilityAction]) changes, as an [AthleteData.merge] map – the one
/// mapping of the setup, the goal page and the calendar. Null for the options that are no athlete setting (the long
/// day lives on the profile, more training days need the week step).
Map<String, dynamic>? feasibilityAthleteChanges(FeasibilityAction x, AthleteData a) => switch (x) {
  FeasLaterDate(:final date) => {'eventDate': date},
  FeasShorter(:final distance) => {'eventDistance': distance, 'targetTimeSec': null},
  FeasDayMinutes(:final minutes) => {
    'dayMinutes': {...a.dayMinutes, ...minutes},
  },
  FeasClearTarget() => {'targetTimeSec': null},
  FeasSetTarget(:final sec) => {'targetTimeSec': sec},
  FeasLongDay() || FeasAddDay() => null,
};

/// [p] with option [x] applied; null when the option needs the plan settings ([FeasAddDay]: which days?).
/// An automatic race name (the old distance's own name) follows a new distance, as in the setup.
UserProfile? profileWithFeasibility(UserProfile p, FeasibilityAction x, AppLocalizations l) {
  if (x is FeasLongDay) return UserProfile.fromMap({...p.toMap(), 'longDay': x.weekday});
  final m = feasibilityAthleteChanges(x, p.athlete);
  if (m == null) return null;
  final a = p.athlete;
  final old = a.eventDistance;
  final autoName = isAutoRaceName(l, old, a.eventName);
  return p.copyWith(athlete: a.merge({...m, if (x is FeasShorter && autoName) 'eventName': null}));
}

/// Applies a feasibility option outside the plan settings (the calendar's banner and its details sheet, audit: the
/// options there were plain text while the setup offers them as buttons): asks first – the option named in the
/// "Plan neu aufsetzen?" dialog –, then stores the changed goal / week with the new plan (the usual
/// [PlanService.replacePlan], which saves the profile) and moves the race goal along. [text]: the option as shown.
/// More training days open the plan settings at the week (the athlete picks the days).
Future<void> applyFeasibilityOption(BuildContext context, WidgetRef ref, FeasibilityAction x, String text) async {
  final l = context.l10n;
  final stored = ref.read(profileOrDefaultProvider);
  final next = profileWithFeasibility(stored, x, l);
  if (next == null) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan)));
    return;
  }
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  final start = await confirmReplacePlan(
    context,
    ref.read(planListProvider),
    sessions: ref.read(sessionListProvider),
    profile: ref.read(profileOrDefaultProvider),
    change: text,
  );
  if (start == null || !context.mounted) return;
  // The race goal follows a new date / distance (the goal page and Home show it).
  final a0 = stored.athlete, a1 = next.athlete;
  if (a0.eventDate != null && (!sameDay(a0.eventDate!, a1.eventDate!) || a0.eventDistance != a1.eventDistance)) {
    final goals = ref.read(goalsProvider).value ?? const <Goal>[];
    final g = goals.where((g) => g.type == GoalType.event && g.deadline != null && sameDay(g.deadline!, a0.eventDate!)).firstOrNull;
    if (g != null) {
      final renamed = a0.eventDistance != a1.eventDistance && isAutoRaceName(l, a0.eventDistance, g.title);
      repo.saveGoal(
        Goal.fromMap(g.id, {
          ...g.toMap(),
          'deadline': a1.eventDate,
          'eventKey': a1.eventDistance,
          'eventKm': eventDistanceOf(a1.eventDistance)?.km ?? g.eventKm,
          if (renamed) 'title': eventDistanceLabel(l, a1.eventDistance!),
        }),
      );
    }
  }
  final count = await PlanService.replacePlan(
    repo: repo,
    l: l,
    profile: next,
    templates: ref.read(templateListProvider),
    existing: ref.read(planListProvider),
    start: start,
    sessions: ref.read(sessionListProvider),
    weeks: next.athlete.planWeeks,
    saveMeta: ref.read(profileProvider).value != null,
  );
  if (count != null && context.mounted) toast(context, l.planCreated(count));
}
