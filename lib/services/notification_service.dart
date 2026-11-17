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

/// Local reminders for upcoming training.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _legacyHydrationBase = 100;
  static const _trainingBase = 1000;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      useTimeZone(await deviceTimeZone());
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

  /// Removes the hydration reminders older versions scheduled (daily repeating, ids
  /// 100–123, channel "hydration") – the feature is gone, the alarms would stay forever.
  Future<void> cancelLegacyHydration() async {
    await init();
    for (var i = 0; i < 24; i++) {
      await _plugin.cancel(_legacyHydrationBase + i);
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.deleteNotificationChannel('hydration');
  }

  /// The device's current time zone (IANA id, e.g. "Europe/Berlin"); null when unknown.
  static Future<String?> deviceTimeZone() async {
    if (kIsWeb) return null;
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (e) {
      debugPrint('time zone lookup failed: $e');
      return null;
    }
  }

  // Scheduling runs one call at a time: two overlapping runs (cancel, cancel, schedule, schedule)
  // could leave reminders of the older plan behind.
  Future<void> _queue = Future.value();

  /// One reminder at [hour]:[minute] local time on the day of each upcoming planned workout
  /// (next 14 days). [timeZone]: the device's zone now – reminders are absolute instants, so
  /// after travelling they must be scheduled again in the new zone (reminderSyncProvider does
  /// that on every zone change and every new day, which also refills the 14-day window).
  Future<void> scheduleTraining({
    required bool enabled,
    required int hour,
    int minute = 0,
    String? timeZone,
    required List<PlannedWorkout> plans,
    required String Function(PlannedWorkout) title,
    required String Function(PlannedWorkout) body,
  }) {
    final Future<void> run = _queue.then((_) async {
      await init();
      useTimeZone(timeZone ?? await deviceTimeZone());
      for (var i = 0; i < trainingReminderMax; i++) {
        await _plugin.cancel(_trainingBase + i);
      }
      if (!enabled) return;
      final times = trainingReminderTimes(plans, hour: hour, minute: minute, now: tz.TZDateTime.now(tz.local));
      var idx = 0;
      for (final (p, t) in times) {
        await _plugin.zonedSchedule(
          _trainingBase + idx++,
          title(p),
          body(p),
          t,
          _details('training', 'Training'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    });
    _queue = run.catchError((Object e) {
      debugPrint('reminder scheduling failed: $e');
    });
    return run;
  }
}

/// At most this many training reminders are scheduled (notification ids 1000–1059).
const trainingReminderMax = 60;

/// Makes [zoneId] the local zone of the reminder times; true when it changed. Unknown ids are
/// ignored (the previous zone stays).
bool useTimeZone(String? zoneId) {
  if (zoneId == null || zoneId == tz.local.name) return false;
  try {
    tz.setLocalLocation(tz.getLocation(zoneId));
    return true;
  } catch (e) {
    debugPrint('unknown time zone $zoneId: $e');
    return false;
  }
}

/// The reminders for [plans]: [hour]:[minute] in [now]'s zone on the day of each planned workout
/// from today on, at most 14 days ahead and [trainingReminderMax] in all; times already past are
/// left out. A plan's day is its local calendar day (dayKey), wherever the phone is now.
List<(PlannedWorkout, tz.TZDateTime)> trainingReminderTimes(
  List<PlannedWorkout> plans, {
  required int hour,
  required int minute,
  required tz.TZDateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <(PlannedWorkout, tz.TZDateTime)>[];
  for (final p in plans) {
    if (p.status != 'planned') continue;
    final day = dayOnly(p.date);
    if (day.isBefore(today) || daysBetween(today, day) > 14) continue;
    final t = tz.TZDateTime(now.location, day.year, day.month, day.day, hour, minute);
    if (t.isBefore(now)) continue;
    out.add((p, t));
    if (out.length == trainingReminderMax) break;
  }
  return out;
}
