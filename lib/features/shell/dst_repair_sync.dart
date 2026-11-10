import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/dst_repair.dart';

/// One-off data migration: moves planned workouts that the pre-fix generator stored one day
/// early after the autumn clock change back to their day ([DstRepair]). Runs once per
/// account and device; the done-flag is set only after the server accepted the change (a
/// rerun is harmless – [DstRepair] finds nothing to move once the plan is repaired).
final dstRepairSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final profile = ref.watch(profileProvider);
  final plans = ref.watch(plansProvider);
  if (!profile.hasValue || profile.value == null || !plans.hasValue) return;
  final prefs = ref.read(prefsProvider);
  final key = 'dstRepair.v1.$uid';
  if (prefs.getBool(key) == true || _running.contains(key)) return;
  // An empty plan list may be an incomplete local cache – wait for workouts.
  if (plans.value!.isEmpty) return;
  final updates = DstRepair.updates(plans.value!, profile.value!);
  debugPrint('DST repair: ${updates.length} workouts');
  if (updates.isEmpty) {
    prefs.setBool(key, true);
    return;
  }
  _running.add(key);
  repo
      .updateMany(plans: updates)
      .then((_) => prefs.setBool(key, true))
      .catchError((Object e) {
        debugPrint('DST repair failed: $e');
        return false;
      })
      .whenComplete(() => _running.remove(key));
});

final _running = <String>{};
