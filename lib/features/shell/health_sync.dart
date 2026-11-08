import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/health_service.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService(ref.watch(prefsProvider)));

/// Bumped after connect/disconnect so dependent providers refresh.
class HealthTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final healthTickProvider = NotifierProvider<HealthTick, int>(HealthTick.new);

final vitalsProvider = FutureProvider<DailyVitals>((ref) async {
  ref.watch(healthTickProvider);
  final hs = ref.watch(healthServiceProvider);
  if (!hs.connected) return const DailyVitals();
  try {
    return await hs.vitals();
  } catch (e) {
    debugPrint('vitals failed: $e');
    return const DailyVitals();
  }
});

/// Imports new workouts from Health Connect (Galaxy Watch via Samsung Health)
/// once per app start / user and after connecting.
final healthSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(healthTickProvider);
  final repo = ref.watch(repoProvider);
  final hs = ref.watch(healthServiceProvider);
  if (repo == null || !hs.connected) return 0;
  // Wait for the first sessions snapshot to dedupe.
  final sessions = await ref.watch(sessionsProvider.future);
  final known = sessions.map((s) => s.externalId).whereType<String>().toSet();
  final since = hs.lastSync?.subtract(const Duration(days: 2)) ?? DateTime.now().subtract(const Duration(days: 30));
  try {
    final list = await hs.importWorkouts(since: since, knownIds: known, newId: repo.newId);
    // Skip workouts that overlap a session recorded in Strive (same sport, ±10 min).
    final fresh = list.where(
      (n) => !sessions.any((s) => s.sport == n.sport && (s.start.difference(n.start).inMinutes).abs() <= 10),
    );
    for (final s in fresh) {
      repo.saveSession(s);
    }
    return fresh.length;
  } catch (e) {
    debugPrint('health sync failed: $e');
    return 0;
  }
});
