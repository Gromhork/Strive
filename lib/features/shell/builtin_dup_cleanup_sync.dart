import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/builtin_upgrade.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// One-off data repair: built-in programs an older version added automatically next to the
/// athlete's own version of them ("2× Push") are removed – or, when a recorded workout, a done
/// plan entry or the plan settings refer to them, kept as "Push (Standard)" without the built-in
/// key ([builtinDuplicateCleanup]). Runs once per account and device; the done-flag is set only
/// after the server accepted the change (a rerun is harmless – a repaired list has no duplicates).
final builtinDupCleanupSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final profile = ref.watch(profileProvider);
  final templates = ref.watch(templatesProvider);
  final plans = ref.watch(plansProvider);
  final sessions = ref.watch(sessionsProvider);
  if (!profile.hasValue || profile.value == null || !templates.hasValue || !plans.hasValue || !sessions.hasValue) return;
  final prefs = ref.read(prefsProvider);
  final key = 'builtinDupCleanup.v1.$uid';
  if (prefs.getBool(key) == true || _running.contains(key)) return;
  // An empty list may be an incomplete local cache – wait for the programs.
  if (templates.value!.isEmpty) return;
  final code = ref.read(settingsProvider).locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  final c = builtinDuplicateCleanup(
    templates.value!,
    plans: plans.value!,
    sessions: sessions.value!,
    athlete: profile.value!.athlete,
    suffix: l.standardCopySuffix,
  );
  // Counts only – nothing personal.
  debugPrint('builtin duplicates: ${c.delete.length} removed, ${c.templates.length} renamed, ${c.plans.length} workouts relinked');
  if (c.isEmpty) {
    prefs.setBool(key, true);
    return;
  }
  _running.add(key);
  Future.wait([
        if (c.templates.isNotEmpty || c.plans.isNotEmpty) repo.updateMany(templates: c.templates, plans: c.plans),
        if (c.delete.isNotEmpty) repo.deleteTemplates(c.delete),
      ])
      .then((_) => prefs.setBool(key, true))
      .catchError((Object e) {
        debugPrint('builtin duplicate cleanup failed: $e');
        return false;
      })
      .whenComplete(() => _running.remove(key));
});

final _running = <String>{};
