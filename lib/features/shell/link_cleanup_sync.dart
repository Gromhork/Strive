import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/plan_log.dart';
import '../../providers.dart';
import '../../services/plan_match.dart';

/// Planned workouts ticked off by a session more than [linkDays] away – links the app made
/// automatically before the ±1-day rule (a Monday workout started from Saturday's long run
/// ticked Saturday off). Each one is reopened; the session keeps its plan reference, so its
/// detail page asks "Als Ersatz für … werten?" and the athlete re-assigns it (or not).
List<(PlannedWorkout before, PlannedWorkout after)> staleLinks(List<PlannedWorkout> plans, List<Session> sessions) {
  final byId = {for (final s in sessions) s.id: s};
  return [
    for (final p in plans)
      if ((p.isDone ? byId[p.sessionId] : null) case final s? when !withinLinkDays(p.date, s.start))
        (p, PlannedWorkout.fromMap(p.id, {...p.toMap(), 'status': 'planned', 'sessionId': null})),
  ];
}

/// One-off cleanup ([staleLinks]), once per account and device; logged in the plan history
/// ("Planverlauf") so it can be undone there. The done-flag is set after the server accepted it.
final linkCleanupSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final plans = ref.watch(plansProvider);
  final sessions = ref.watch(sessionsProvider);
  if (!plans.hasValue || !sessions.hasValue) return;
  final prefs = ref.read(prefsProvider);
  final key = 'linkCleanup.v1.$uid';
  if (prefs.getBool(key) == true || _running.contains(key)) return;
  // Empty lists may be an incomplete local cache – wait for data.
  if (plans.value!.isEmpty || sessions.value!.isEmpty) return;
  final changes = staleLinks(plans.value!, sessions.value!);
  debugPrint('Link cleanup: ${changes.length} workouts');
  if (changes.isEmpty) {
    prefs.setBool(key, true);
    return;
  }
  _running.add(key);
  repo.logPlanChange(PlanLogEntry.of('unlink', changes));
  repo
      .updateMany(plans: {for (final (_, a) in changes) a.id: {'status': 'planned', 'sessionId': null}})
      .then((_) => prefs.setBool(key, true))
      .catchError((Object e) {
        debugPrint('Link cleanup failed: $e');
        return false;
      })
      .whenComplete(() => _running.remove(key));
});

final _running = <String>{};
