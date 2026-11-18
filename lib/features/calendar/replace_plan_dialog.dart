import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/segments.dart';

/// Number of planned (not done / skipped) workouts on or after [from] that a new plan replaces.
int plannedFrom(List<PlannedWorkout> plans, DateTime from) {
  final d = dayOnly(from);
  return plans.where((p) => p.status == 'planned' && !p.date.isBefore(d)).length;
}

/// The Monday after [now] (a week later when [now] is a Monday).
DateTime nextMonday(DateTime now) {
  return DateTime(now.year, now.month, now.day + 8 - now.weekday);
}

/// Asks before a new plan replaces the upcoming planned workouts (calendar "Start plan
/// over", plan settings, aligning the plan to a goal). Returns the day the new plan starts
/// – today or next Monday – or null when cancelled. Without planned workouts from today
/// nothing is lost: no dialog, the plan starts today.
///
/// [change]: what is changed with the new plan (a feasibility option applied from the calendar, "Übernehmen: …") –
/// shown first, and the dialog is shown even when no planned workout would be lost (the change is confirmed).
Future<DateTime?> confirmReplacePlan(BuildContext context, List<PlannedWorkout> plans, {DateTime? now, String? change}) async {
  final today = dayOnly(now ?? DateTime.now());
  if (plannedFrom(plans, today) == 0 && change == null) return today;
  final monday = nextMonday(today);
  return showDialog<DateTime>(
    context: context,
    builder: (c) {
      var start = today;
      return StatefulBuilder(
        builder: (c, setState) {
          final l = c.l10n;
          final date = DateFormat.MMMEd(c.localeName).format(start);
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
                  Text(l.replacePlanBody(date, plannedFrom(plans, start))),
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
