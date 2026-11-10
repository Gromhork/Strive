import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/format.dart';
import 'models.dart';

/// One entry of the plan history ("Planverlauf"): a set of plan changes applied together –
/// automatic adjustments after a session, a "Plan überprüfen" application, "Woche anpassen"
/// or a "Nicht 100 % fit?" change. Stored below `users/{uid}/planLog`.
class PlanLogEntry {
  const PlanLogEntry({this.id = '', required this.at, required this.source, this.reason = '', this.note = '', required this.items});

  final String id;
  final DateTime at;

  /// auto | recal | week | readiness
  final String source;

  /// Source-specific code: the AutoAdjuster reason, the readiness kind (sick, pain, tired, time).
  final String reason;

  /// Text rendered when the change was made (e.g. the findings of "Plan überprüfen").
  final String note;
  final List<PlanLogItem> items;

  /// Entry for the changed workouts ([before] null = newly added).
  factory PlanLogEntry.of(
    String source,
    List<(PlannedWorkout?, PlannedWorkout)> changes, {
    String reason = '',
    String note = '',
    DateTime? at,
  }) => PlanLogEntry(
    at: at ?? DateTime.now(),
    source: source,
    reason: reason,
    note: note,
    items: [for (final (b, a) in changes) PlanLogItem(planId: a.id, before: b?.toMap(), after: a.toMap())],
  );

  factory PlanLogEntry.fromMap(String id, Map<String, dynamic> m) => PlanLogEntry(
    id: id,
    at: m['at'] is Timestamp ? (m['at'] as Timestamp).toDate() : DateTime.tryParse('${m['at']}') ?? DateTime.now(),
    source: m['source'] ?? '',
    reason: m['reason'] ?? '',
    note: m['note'] ?? '',
    items: [
      for (final e in (m['items'] as List?) ?? const [])
        if (e is Map) PlanLogItem.fromMap(e),
    ],
  );

  Map<String, dynamic> toMap() => {
    'at': Timestamp.fromDate(at),
    'source': source,
    if (reason.isNotEmpty) 'reason': reason,
    if (note.isNotEmpty) 'note': note,
    'items': [for (final i in items) i.toMap()],
  };
}

/// One workout of a [PlanLogEntry]: the full plan before (null = added) and after the change.
class PlanLogItem {
  const PlanLogItem({required this.planId, required this.before, required this.after, this.reason = ''});
  final String planId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic> after;

  /// Per-workout reason (automatic adjustments of several workouts can differ).
  final String reason;

  PlannedWorkout? get beforePlan => before == null ? null : PlannedWorkout.fromMap(planId, before!);
  PlannedWorkout get afterPlan => PlannedWorkout.fromMap(planId, after);

  factory PlanLogItem.fromMap(Map m) => PlanLogItem(
    planId: m['planId'] ?? '',
    before: m['before'] is Map ? Map<String, dynamic>.from(m['before'] as Map) : null,
    after: Map<String, dynamic>.from((m['after'] as Map?) ?? const {}),
    reason: m['reason'] ?? '',
  );

  Map<String, dynamic> toMap() => {'planId': planId, 'before': before, 'after': after, if (reason.isNotEmpty) 'reason': reason};
}

/// State of a logged change compared with the current plan.
enum PlanLogState {
  /// The workout still looks as the change left it – it can be undone.
  undoable,

  /// The workout is back to its state before the change.
  undone,

  /// Changed again since (edited, done, deleted) – no undo.
  changed,
}

/// Fields that tell whether a workout is still as a change left it.
bool samePlanState(PlannedWorkout a, PlannedWorkout b) =>
    sameDay(a.date, b.date) &&
    a.status == b.status &&
    a.sport == b.sport &&
    a.title == b.title &&
    a.intensity == b.intensity &&
    a.durationMin == b.durationMin &&
    (a.distanceKm ?? 0) == (b.distanceKm ?? 0) &&
    a.exercises.length == b.exercises.length &&
    a.exercises.fold(0, (x, e) => x + e.sets.length) == b.exercises.fold(0, (x, e) => x + e.sets.length);

PlanLogState planLogItemState(PlanLogItem i, Map<String, PlannedWorkout> current) {
  final cur = current[i.planId];
  final before = i.beforePlan;
  if (cur == null) return before == null ? PlanLogState.undone : PlanLogState.changed;
  if (cur.isDone) return PlanLogState.changed;
  if (samePlanState(cur, i.afterPlan)) return PlanLogState.undoable;
  if (before != null && samePlanState(cur, before)) return PlanLogState.undone;
  return PlanLogState.changed;
}

/// State of a whole entry: undoable when any of its workouts can still be undone.
PlanLogState planLogState(PlanLogEntry e, Map<String, PlannedWorkout> current) {
  final states = [for (final i in e.items) planLogItemState(i, current)];
  if (states.contains(PlanLogState.undoable)) return PlanLogState.undoable;
  if (states.isNotEmpty && states.every((s) => s == PlanLogState.undone)) return PlanLogState.undone;
  return PlanLogState.changed;
}

/// What undoing [e] does: workouts to restore (full documents) and added ones to delete.
/// Only workouts that still look as the change left them are touched.
({List<PlannedWorkout> restore, List<String> delete}) planLogUndo(PlanLogEntry e, Map<String, PlannedWorkout> current) {
  final restore = <PlannedWorkout>[], delete = <String>[];
  for (final i in e.items) {
    if (planLogItemState(i, current) != PlanLogState.undoable) continue;
    final b = i.beforePlan;
    b == null ? delete.add(i.planId) : restore.add(b);
  }
  return (restore: restore, delete: delete);
}
