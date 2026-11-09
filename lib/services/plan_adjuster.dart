import '../core/format.dart';
import '../data/models.dart';

/// One proposed change of the "adjust my week" assistant.
class PlanChange {
  const PlanChange.move(this.plan, DateTime this.to) : replaces = null;
  const PlanChange.skip(this.plan) : to = null, replaces = null;
  const PlanChange.replace(this.plan, DateTime this.to, PlannedWorkout this.replaces);

  final PlannedWorkout plan;

  /// New date (null = the workout is dropped).
  final DateTime? to;

  /// Easy workout of the same sport on the target day that the moved key workout replaces.
  final PlannedWorkout? replaces;

  bool get isMove => to != null;
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Hard sessions: the ones that need recovery around them.
bool isHardPlan(PlannedWorkout p) => p.isKey || const {'tempo', 'intervals', 'long'}.contains(p.intensity);

/// Workouts of the last [lookbackDays] days that were neither done nor skipped.
List<PlannedWorkout> missedPlans(List<PlannedWorkout> plans, DateTime now, {int lookbackDays = 3}) {
  final today = _d(now), from = today.subtract(Duration(days: lookbackDays));
  return plans.where((p) => p.status == 'planned' && !_d(p.date).isBefore(from) && _d(p.date).isBefore(today)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

/// Proposes how to absorb missed workouts (TriDot/Humango style), following the same
/// rules as the plan generator:
/// * Key/hard sessions move to the nearest remaining day of the *same* week (Mon–Sun)
///   that has no hard session the day before, the same day or the day after – so two
///   hard days are never back to back. On that day an easy session of the same sport is
///   replaced; otherwise the day must be free of that sport.
/// * Nothing is moved into or within recovery/taper weeks (those weeks protect
///   freshness) – missed sessions there are simply dropped, as are easy sessions
///   (one missed easy run doesn't need to be made up, stacking volume does harm).
List<PlanChange> proposeWeekAdjustment(List<PlannedWorkout> plans, DateTime now) {
  final today = _d(now);
  final weekEnd = today.add(Duration(days: 7 - today.weekday));
  final changes = <PlanChange>[];
  // Working copy of the schedule after the changes made so far: id → date.
  final dateOf = {for (final p in plans) p.id: _d(p.date)};
  final dropped = <String>{};
  final upcoming = plans.where((p) => p.status == 'planned' && !_d(p.date).isBefore(today)).toList();

  // Hard sessions that happen: done ones (also yesterday's) and planned ones from today on.
  // Missed ones on past days did not happen and don't block their neighbours.
  bool hardOn(DateTime day, {String? except}) => plans.any(
    (p) =>
        p.id != except &&
        !dropped.contains(p.id) &&
        p.status != 'skipped' &&
        !(p.status == 'planned' && dateOf[p.id]!.isBefore(today)) &&
        dateOf[p.id] == day &&
        isHardPlan(p),
  );

  for (final m in missedPlans(plans, now)) {
    final protectedWeek = m.phase == 'recovery' || m.phase == 'taper';
    if (!isHardPlan(m) || protectedWeek) {
      changes.add(PlanChange.skip(m));
      dropped.add(m.id);
      continue;
    }
    PlanChange? best;
    // Only inside the missed workout's own week: a Sunday long run missed and looked at on
    // Monday must not land in the next week, which already has its own long run.
    final md = _d(m.date);
    final ownWeekEnd = md.add(Duration(days: 7 - md.weekday));
    final last = ownWeekEnd.isBefore(weekEnd) ? ownWeekEnd : weekEnd;
    for (var day = today; !day.isAfter(last); day = day.add(const Duration(days: 1))) {
      if (hardOn(day, except: m.id) ||
          hardOn(day.subtract(const Duration(days: 1)), except: m.id) ||
          hardOn(day.add(const Duration(days: 1)), except: m.id)) {
        continue;
      }
      final sameSport = upcoming.where((p) => p.sport == m.sport && dateOf[p.id] == day && !dropped.contains(p.id)).toList();
      if (sameSport.isEmpty) {
        best = PlanChange.move(m, day);
      } else if (sameSport.length == 1 && !isHardPlan(sameSport.first)) {
        best = PlanChange.replace(m, day, sameSport.first);
      } else {
        continue;
      }
      break;
    }
    if (best == null) {
      changes.add(PlanChange.skip(m));
      dropped.add(m.id);
      continue;
    }
    changes.add(best);
    dateOf[m.id] = best.to!;
    if (best.replaces != null) dropped.add(best.replaces!.id);
  }
  return changes;
}

/// Firestore updates (plan id → fields) that apply [changes].
Map<String, Map<String, dynamic>> planChangeUpdates(List<PlanChange> changes) => {
  for (final c in changes) ...{
    c.plan.id: c.isMove ? {'date': dayKey(c.to!)} : {'status': 'skipped'},
    if (c.replaces != null) c.replaces!.id: {'status': 'skipped'},
  },
};
