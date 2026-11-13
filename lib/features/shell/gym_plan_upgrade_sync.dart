import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/gym_plan_upgrade.dart';

/// One-off data migration: gym workouts of plans generated before the plan referenced its
/// programs become references again, with their day adaptations as mods ([GymPlanUpgrade]). Runs
/// once per account and device; the done-flag is set only after the server accepted the change
/// (a rerun is harmless – upgraded workouts produce no further updates).
final gymPlanUpgradeSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final plans = ref.watch(plansProvider);
  final templates = ref.watch(templatesProvider);
  if (!plans.hasValue || !templates.hasValue) return;
  final prefs = ref.read(prefsProvider);
  final key = 'gymPlanUpgrade.v1.$uid';
  if (prefs.getBool(key) == true || _running.contains(key)) return;
  // An empty list may be an incomplete local cache – wait for workouts and programs.
  if (plans.value!.isEmpty || templates.value!.isEmpty) return;
  final updates = GymPlanUpgrade.updates(plans.value!, templates.value!, today: DateTime.now());
  debugPrint('gym plan upgrade: ${updates.length} workouts');
  if (updates.isEmpty) {
    prefs.setBool(key, true);
    return;
  }
  _running.add(key);
  repo
      .updateMany(plans: updates)
      .then((_) => prefs.setBool(key, true))
      .catchError((Object e) {
        debugPrint('gym plan upgrade failed: $e');
        return false;
      })
      .whenComplete(() => _running.remove(key));
});

final _running = <String>{};
