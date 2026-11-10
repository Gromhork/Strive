import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/models.dart';

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
Future<DateTime?> confirmReplacePlan(BuildContext context, List<PlannedWorkout> plans, {DateTime? now}) async {
  final today = dayOnly(now ?? DateTime.now());
  if (plannedFrom(plans, today) == 0) return today;
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.replacePlanBody(date, plannedFrom(plans, start))),
                const SizedBox(height: 4),
                Text(l.replacePlanKeeps, style: Theme.of(c).textTheme.bodySmall),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(l.replaceFromToday)),
                    ButtonSegment(value: true, label: Text(l.replaceFromMonday)),
                  ],
                  selected: {start == monday},
                  onSelectionChanged: (s) => setState(() => start = s.first ? monday : today),
                ),
              ],
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
