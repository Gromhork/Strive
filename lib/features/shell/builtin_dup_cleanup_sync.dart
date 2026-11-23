import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/builtin_upgrade.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// Data repair: built-in programs that were added automatically next to the athlete's own version
/// of them ("2× Push") are removed – or, when a recorded workout, a done plan entry or the plan
/// settings refer to them, kept as "Push (Standard)" without the built-in key
/// ([builtinDuplicateCleanup]).
///
/// It checks again whenever the programs, plans or workouts change (not once per account: a
/// duplicate added later – e.g. by a plan built offline from an empty list – is repaired too). The
/// local data only tells whether there is anything to do; the change itself is computed from the
/// server's programs, plans and workouts ([confirmedDuplicateCleanup]), so a copy a not yet loaded
/// workout refers to is never deleted. A repaired list has no duplicates – a rerun is harmless.
final builtinDupCleanupSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final profile = ref.watch(profileProvider);
  final templates = ref.watch(templatesProvider);
  final plans = ref.watch(plansProvider);
  final sessions = ref.watch(sessionsProvider);
  if (!profile.hasValue || profile.value == null || !templates.hasValue || !plans.hasValue || !sessions.hasValue) return;
  if (templates.value!.isEmpty || _running.contains(uid)) return;
  final code = ref.read(settingsProvider).locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final suffix = lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en')).standardCopySuffix;
  final athlete = profile.value!.athlete;
  final local = builtinDuplicateCleanup(templates.value!, plans: plans.value!, sessions: sessions.value!, athlete: athlete, suffix: suffix);
  if (local.isEmpty) return;
  // The same local finding again (e.g. the server disagreed, or could not be reached) is not
  // retried on every rebuild – only after a while.
  final sig = '$uid|${(local.delete.toList()..sort()).join(',')}|${(local.templates.keys.toList()..sort()).join(',')}';
  final last = _attempts[sig];
  if (last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) return;
  _attempts[sig] = DateTime.now();
  _running.add(uid);
  confirmedDuplicateCleanup(repo, athlete: athlete, suffix: suffix)
      .then((c) {
        // Counts only – nothing personal.
        if (c != null) {
          debugPrint('builtin duplicates: ${c.delete.length} removed, ${c.templates.length} renamed, ${c.plans.length} relinked');
        }
      })
      .catchError((Object e) {
        debugPrint('builtin duplicate cleanup failed: $e');
      })
      .whenComplete(() => _running.remove(uid));
});

final _running = <String>{};
final _attempts = <String, DateTime>{};

/// Computes [builtinDuplicateCleanup] from the programs, plans and recorded workouts on the server
/// and applies it. Null (nothing changed) when the server cannot be reached or the programs are
/// empty there; otherwise the applied change (possibly empty – the local cache was out of date).
Future<BuiltinDuplicateCleanup?> confirmedDuplicateCleanup(Repository repo, {required AthleteData athlete, required String suffix}) async {
  final templates = await repo.templatesFromServer();
  if (templates == null || templates.isEmpty) return null;
  final plans = await repo.plansFromServer();
  final sessions = await repo.sessionsFromServer();
  final c = builtinDuplicateCleanup(templates, plans: plans, sessions: sessions, athlete: athlete, suffix: suffix);
  if (c.isEmpty) return c;
  await Future.wait([
    if (c.templates.isNotEmpty || c.plans.isNotEmpty) repo.updateMany(templates: c.templates, plans: c.plans),
    if (c.delete.isNotEmpty) repo.deleteTemplates(c.delete),
  ]);
  return c;
}
