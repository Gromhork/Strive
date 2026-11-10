import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sport.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/notification_service.dart';

/// Re-schedules local notifications whenever settings or the plan change.
final reminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  final plans = ref.watch(planListProvider);
  final prefs = ref.read(prefsProvider);
  final code = settings.locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  final ns = NotificationService.instance;
  Future(() async {
    await clearLegacyHydration(prefs, ns.cancelLegacyHydration);
    await ns.scheduleTraining(
      enabled: settings.trainingReminder,
      hour: settings.reminderHour,
      plans: plans,
      title: (p) => l.trainingReminderTitle(p.sport.label(l)),
      body: (p) => '${p.title} · ${p.durationMin} min',
    );
  }).catchError((Object e) {
    debugPrint('reminder sync failed: $e');
  });
});

/// Prefs keys of the removed hydration reminder.
const legacyHydrationKeys = ['hydration', 'hydrationInterval'];

/// Once after the upgrade that removed the hydration reminder: cancels the reminders an
/// older version may have scheduled and drops its settings (their absence marks it done).
Future<bool> clearLegacyHydration(SharedPreferences prefs, Future<void> Function() cancel) async {
  if (!legacyHydrationKeys.any(prefs.containsKey)) return false;
  await cancel();
  for (final k in legacyHydrationKeys) {
    await prefs.remove(k);
  }
  return true;
}
