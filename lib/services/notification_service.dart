import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';

/// Android drawable used as small (status-bar) icon by every notification.
const notificationIcon = 'ic_notification';

/// Local reminders: hydration and upcoming training.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _hydrationBase = 100;
  static const _trainingBase = 1000;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('timezone init failed: $e');
    }
    await _plugin.initialize(
      const InitializationSettings(
        // Monochrome status-bar icon (tool/branding/make_icons.py).
        android: AndroidInitializationSettings(notificationIcon),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  NotificationDetails _details(String channel, String name) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel,
      name,
      importance: Importance.high,
      priority: Priority.high,
      icon: notificationIcon,
      color: AppColors.brand,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  /// Daily repeating reminders every [intervalHours] between [fromHour] and [toHour].
  Future<void> scheduleHydration({
    required bool enabled,
    required int fromHour,
    required int toHour,
    required int intervalHours,
    required String title,
    required String body,
  }) async {
    await init();
    for (var i = 0; i < 24; i++) {
      await _plugin.cancel(_hydrationBase + i);
    }
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    var idx = 0;
    for (var h = fromHour; h <= toHour; h += intervalHours) {
      var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h);
      if (t.isBefore(now)) t = t.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _hydrationBase + idx++,
        title,
        body,
        t,
        _details('hydration', 'Hydration'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// One reminder at [hour] on the day of each upcoming planned workout (next 14 days).
  Future<void> scheduleTraining({
    required bool enabled,
    required int hour,
    required List<PlannedWorkout> plans,
    required String Function(PlannedWorkout) title,
    required String Function(PlannedWorkout) body,
  }) async {
    await init();
    for (var i = 0; i < 60; i++) {
      await _plugin.cancel(_trainingBase + i);
    }
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    final upcoming =
        plans
            .where((p) => p.status == 'planned' && !dayOnly(p.date).isBefore(dayOnly(DateTime.now())))
            .where((p) => p.date.difference(DateTime.now()).inDays <= 14)
            .take(60)
            .toList();
    var idx = 0;
    for (final p in upcoming) {
      final t = tz.TZDateTime(tz.local, p.date.year, p.date.month, p.date.day, hour);
      if (t.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        _trainingBase + idx++,
        title(p),
        body(p),
        t,
        _details('training', 'Training'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showNow(String title, String body) async {
    await init();
    await _plugin.show(1, title, body, _details('general', 'General'));
  }
}
