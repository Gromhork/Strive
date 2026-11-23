import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../services/plan_service.dart';
import '../../widgets/segments.dart';

/// The Monday after [now] (a week later when [now] is a Monday).
DateTime nextMonday(DateTime now) {
  return DateTime(now.year, now.month, now.day + 8 - now.weekday);
}

/// Asks before a new plan replaces the old one (calendar "Start plan over", plan settings, aligning the plan to a
/// goal, a feasibility option): the old plan's open workouts – all of them, also missed past ones
/// ([PlanService.openWorkouts], owner round 10) – are deleted, completed ones stay. Returns the day the new plan
/// starts – today or next Monday (the old plan's open workouts until then stay, [PlanService.bridgeWorkouts]) – or null when cancelled. Without open workouts nothing is lost: no dialog, the
/// plan starts today. [sessions] / [profile]: a done-marked workout whose session was too short to count is open.
///
/// [change]: what is changed with the new plan (a feasibility option applied from the calendar, "Übernehmen: …") –
/// shown first, and the dialog is shown even when no planned workout would be lost (the change is confirmed).
Future<DateTime?> confirmReplacePlan(
  BuildContext context,
  List<PlannedWorkout> plans, {
  List<Session> sessions = const [],
  UserProfile? profile,
  DateTime? now,
  String? change,
}) async {
  final today = dayOnly(now ?? DateTime.now());
  final open = PlanService.openWorkouts(plans, sessions, profile: profile).length;
  if (open == 0 && change == null) return today;
  final monday = nextMonday(today);
  return showDialog<DateTime>(
    context: context,
    builder: (c) {
      var start = today;
      return StatefulBuilder(
        builder: (c, setState) {
          final l = c.l10n;
          final date = DateFormat.MMMEd(c.localeName).format(start);
          // Per choice (review r10-N3): from next Monday the old plan's open workouts until then stay.
          final removed = PlanService.replacedWorkouts(plans, sessions, profile: profile, start: start, now: today).length;
          final bridge = PlanService.bridgeWorkouts(plans, sessions, profile: profile, start: start, now: today).length;
          return AlertDialog(
            title: Text(l.replacePlanTitle),
            // The full dialog width: the dialog sizes its content by its intrinsic width, which the
            // segmented control (it lays out by the width it gets) cannot report.
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (change != null) ...[
                    Text(l.applyChange(change), key: const ValueKey('replaceChange'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                  ],
                  Text(l.replacePlanBodyAll(date, removed), key: const ValueKey('replaceBody')),
                  if (bridge > 0) ...[const SizedBox(height: 4), Text(l.replacePlanBridge(bridge), key: const ValueKey('replaceBridge'))],
                  const SizedBox(height: 4),
                  Text(l.replacePlanKeeps, style: Theme.of(c).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Segments<bool>(
                    key: const ValueKey('replaceStart'),
                    segments: [Seg(false, label: l.replaceFromToday), Seg(true, label: l.replaceFromMonday)],
                    value: start == monday,
                    onChanged: (v) => setState(() => start = v ? monday : today),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, start), child: Text(l.replacePlanOk)),
            ],
          );
        },
      );
    },
  );
}
