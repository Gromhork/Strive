import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sport.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/notification_service.dart';

/// The device's time zone (IANA id; null until read / unknown). Read at start and again whenever
/// the app comes back to the foreground – after a flight the phone switches zones while the app
/// sleeps.
class DeviceTimeZone extends Notifier<String?> {
  @override
  String? build() {
    AppLifecycleListener? listener;
    try {
      listener = AppLifecycleListener(onResume: refresh);
    } catch (_) {
      // No widgets binding (pure unit tests).
    }
    ref.onDispose(() => listener?.dispose());
    refresh();
    return null;
  }

  Future<void> refresh() async {
    final zone = await NotificationService.deviceTimeZone();
    if (zone != null && ref.mounted && zone != state) state = zone;
  }
}

final deviceTimeZoneProvider = NotifierProvider<DeviceTimeZone, String?>(DeviceTimeZone.new);

/// Re-schedules local notifications whenever settings or the plan change, on every new day (the
/// 14-day window moves on) and when the device's time zone changes (reminders are absolute
/// instants: 08:00 in Berlin would ring at 02:00 in New York).
final reminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  final plans = ref.watch(planListProvider);
  ref.watch(todayProvider);
  final zone = ref.watch(deviceTimeZoneProvider);
  final prefs = ref.read(prefsProvider);
  final code = settings.locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  final ns = NotificationService.instance;
  Future(() async {
    await clearLegacyHydration(prefs, ns.cancelLegacyHydration);
    await ns.scheduleTraining(
      enabled: settings.trainingReminder,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      timeZone: zone,
      plans: plans,
      title: (p) => l.trainingReminderTitle(p.sport.label(l)),
      body: (p) => '${p.title} · ${p.durationMin} min',
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
