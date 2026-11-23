import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/plan_gaps.dart';

/// Removes planned workouts left over from a plan replaced or deleted on another device with a stale or offline cache
/// ([stalePlanWorkouts], review 2026-11 data-9): both replacements synced → two plans, every training day twice; a
/// plan deleted ("Plan löschen") on one device and still in another's cache → back in the calendar. Runs whenever the
/// plans, sessions or profile change; only open workouts of an older plan generation go (done, started and the
/// athlete's own workouts stay).
final planGenCleanupSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final profile = ref.watch(profileProvider);
  final plans = ref.watch(plansProvider);
  final sessions = ref.watch(sessionsProvider);
  if (!profile.hasValue || profile.value == null || !plans.hasValue || !sessions.hasValue) return;
  final stale = stalePlanWorkouts(profile.value!, plans.value!, sessions.value!).where((p) => !_deleting.contains(p.id)).toList();
  if (stale.isEmpty) return;
  debugPrint('Plan generation cleanup: ${stale.length} workouts');
  final ids = {for (final p in stale) p.id};
  _deleting.addAll(ids);
  repo
      .deletePlans(ids)
      .catchError((Object e) => debugPrint('Plan generation cleanup failed: $e'))
      .whenComplete(() => _deleting.removeAll(ids));
});

final _deleting = <String>{};
