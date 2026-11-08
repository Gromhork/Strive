import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sport.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/notification_service.dart';

/// Re-schedules local notifications whenever settings or the plan change.
final reminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  final plans = ref.watch(planListProvider);
  final code = settings.locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  final ns = NotificationService.instance;
  Future(() async {
    await ns.scheduleHydration(
      enabled: settings.hydration,
      fromHour: 8,
      toHour: 20,
      intervalHours: settings.hydrationInterval,
      title: l.hydrationTitle,
      body: l.hydrationBody,
    );
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
