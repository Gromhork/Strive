import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/health_service.dart';
import '../../services/plan_match.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService(ref.watch(prefsProvider)));

/// Bumped after connect/disconnect – and when the app comes back to the foreground
/// (at most every 15 min) – so vitals and watch workouts refresh while the app stays open.
class HealthTick extends Notifier<int> {
  DateTime _last = DateTime.now();

  @override
  int build() {
    final listener = AppLifecycleListener(
      onResume: () {
        if (DateTime.now().difference(_last) < const Duration(minutes: 15)) return;
        bump();
      },
    );
    ref.onDispose(listener.dispose);
    return 0;
  }

  void bump() {
    _last = DateTime.now();
    state++;
  }
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

/// Imports new workouts from Health Connect (Galaxy Watch via Samsung Health) at app
/// start, after connecting and on resume.
/// * A watch workout that overlaps a session recorded in Strive is the same workout:
///   its heart rate and calories are merged into that session instead of a duplicate.
/// * New workouts get an RPE estimated from heart rate (for a realistic training load)
///   and complete the matching planned workout of that day.
final healthSyncProvider = FutureProvider<int>((ref) async {
  ref.watch(healthTickProvider);
  final repo = ref.watch(repoProvider);
  final hs = ref.watch(healthServiceProvider);
  if (repo == null || !hs.connected) return 0;
  // read, not watch: saving the imported sessions must not trigger another import.
  final sessions = await ref.read(sessionsProvider.future);
  final plans = await ref.read(plansProvider.future);
  final profile = ref.read(profileOrDefaultProvider);
  final code = ref.read(settingsProvider).locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  final known = sessions.map((s) => s.externalId).whereType<String>().toSet();
  final since = hs.lastSync?.subtract(const Duration(days: 2)) ?? DateTime.now().subtract(const Duration(days: 30));
  try {
    final list = await hs.importWorkouts(since: since, knownIds: known, newId: repo.newId, titleFor: (s) => s.label(l));
    final merged = <String, Map<String, dynamic>>{};
    final planUpdates = <String, Map<String, dynamic>>{};
    var added = 0;
    final open = [...plans];
    // Watch workouts imported before plans were linked on import complete their plan now.
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    // Their load also uses the heart-rate RPE estimate instead of the flat default.
    for (final old in sessions.where((s) => s.externalId != null && s.source != null && s.start.isAfter(cutoff))) {
      final fix = <String, dynamic>{};
      final rpe = old.rpe == null ? rpeFromHr(old.avgHr, profile) : null;
      if (rpe != null) fix['rpe'] = rpe;
      final plan = old.planId == null ? matchPlan(old, open) : null;
      if (plan != null && plan.status == 'planned') {
        planUpdates[plan.id] = {'status': 'done', 'sessionId': old.id};
        fix['planId'] = plan.id;
        open.remove(plan);
      }
      if (fix.isNotEmpty) merged[old.id] = fix;
    }
    for (final n in list) {
      final twin = sessions.where((s) => s.externalId == null && sameWorkout(s, n)).firstOrNull;
      if (twin != null) {
        merged[twin.id] = {
          'externalId': n.externalId,
          if (twin.avgHr == null && n.avgHr != null) 'avgHr': n.avgHr,
          if (twin.maxHr == null && n.maxHr != null) 'maxHr': n.maxHr,
          if (twin.calories == null && n.calories != null) 'calories': n.calories,
        };
        continue;
      }
      final rpe = rpeFromHr(n.avgHr, profile);
      final plan = matchPlan(n, open);
      final s = Session(
        id: n.id,
        sport: n.sport,
        title: n.title,
        start: n.start,
        durationSec: n.durationSec,
        distanceM: n.distanceM,
        avgHr: n.avgHr,
        maxHr: n.maxHr,
        calories: n.calories,
        indoor: n.indoor,
        source: n.source,
        externalId: n.externalId,
        rpe: rpe,
        planId: plan?.id,
      );
      repo.saveSession(s);
      added++;
      if (plan != null && plan.status == 'planned') {
        planUpdates[plan.id] = {'status': 'done', 'sessionId': s.id};
        open.remove(plan);
      }
    }
    if (merged.isNotEmpty || planUpdates.isNotEmpty) repo.updateMany(sessions: merged, plans: planUpdates);
    return added;
  } catch (e) {
    debugPrint('health sync failed: $e');
    return 0;
  }
});
