import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/builtin_upgrade.dart';
import '../../providers.dart';

/// Keeps unchanged built-in gym programs up to date: when the shipped programs improve
/// (e.g. antagonist supersets) or the gym goal changes (rep ranges), programs the user has
/// not edited are replaced in Firestore once. Edited programs are left alone.
final programUpgradeSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final profile = ref.watch(profileProvider);
  final templates = ref.watch(templatesProvider);
  if (!profile.hasValue || profile.value == null || !templates.hasValue) return;
  final goal = profile.value!.athlete.gymGoal;
  final prefs = ref.read(prefsProvider);
  // Bump the version when the built-in programs change.
  final key = 'gymPrograms.v3.$uid';
  if (prefs.getString(key) == goal) return;
  final updates = <String, Map<String, dynamic>>{
    for (final t in templates.value!)
      if (upgradedBuiltinExercises(t, goal) case final ex?) t.id: {'exercises': ex.map((e) => e.toMap()).toList()},
  };
  debugPrint('program upgrade ($goal): ${updates.length} programs');
  if (updates.isEmpty) {
    prefs.setString(key, goal);
    return;
  }
  // Done only once the server accepted the change (idempotent: upgraded programs produce no
  // updates on the next run).
  final run = '$key/$goal';
  if (!_running.add(run)) return;
  repo
      .updateMany(templates: updates)
      .then((_) => prefs.setString(key, goal))
      .catchError((Object e) {
        debugPrint('program upgrade failed: $e');
        return false;
      })
      .whenComplete(() => _running.remove(run));
});

final _running = <String>{};
