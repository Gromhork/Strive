import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/sport.dart';
import '../data/models.dart';

enum HealthStatus { available, needsInstall, unavailable }

/// Daily vitals shown on the home screen (from Galaxy Watch via Samsung Health → Health Connect).
class DailyVitals {
  final int? steps;
  final int? restingHr;
  final int? sleepMin;
  final double? hrv;
  const DailyVitals({this.steps, this.restingHr, this.sleepMin, this.hrv});
  bool get isEmpty => steps == null && restingHr == null && sleepMin == null && hrv == null;
}

/// Health Connect bridge. Samsung Health (and therefore the Galaxy Watch) syncs
/// workouts, heart rate, sleep etc. into Health Connect; Strive reads them and
/// writes its own workouts back.
class HealthService {
  HealthService(this.prefs, {this.uid});
  final SharedPreferences prefs;

  /// Signed-in user: the connection and the last import are per account (another account on
  /// this phone must not inherit them).
  final String? uid;

  String get _connectedKey => uid == null ? 'hc_connected' : 'hc_connected.$uid';
  String get _lastSyncKey => uid == null ? 'hc_lastSync' : 'hc_lastSync.$uid';

  /// Adopts the device-wide keys of older versions for the first account that signs in.
  void migrateLegacyKeys() {
    if (uid == null) return;
    final c = prefs.getBool('hc_connected'), t = prefs.getInt('hc_lastSync');
    if (c == null && t == null) return;
    if (c != null && prefs.getBool(_connectedKey) == null) prefs.setBool(_connectedKey, c);
    if (t != null && prefs.getInt(_lastSyncKey) == null) prefs.setInt(_lastSyncKey, t);
    prefs.remove('hc_connected');
    prefs.remove('hc_lastSync');
  }

  /// Firestore id of an imported workout: deterministic, so importing the same workout twice
  /// (two syncs at once, a reinstall) writes the same document instead of a duplicate.
  static String importId(String uuid) => 'hc_${uuid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';

  final _h = Health();
  bool _configured = false;

  static const readTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ];
  static const writeTypes = [HealthDataType.WORKOUT, HealthDataType.WEIGHT];

  bool get connected => prefs.getBool(_connectedKey) ?? false;
  DateTime? get lastSync {
    final v = prefs.getInt(_lastSyncKey);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> _configure() async {
    if (_configured) return;
    await _h.configure();
    _configured = true;
  }

  Future<HealthStatus> status() async {
    if (!Platform.isAndroid) return HealthStatus.unavailable;
    await _configure();
    final s = await _h.getHealthConnectSdkStatus();
    return switch (s) {
      HealthConnectSdkStatus.sdkAvailable => HealthStatus.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => HealthStatus.needsInstall,
      _ => HealthStatus.unavailable,
    };
  }

  Future<void> install() => _h.installHealthConnect();

  Future<bool> connect() async {
    await _configure();
    final types = [...readTypes, ...writeTypes];
    final perms = [for (final _ in readTypes) HealthDataAccess.READ, for (final _ in writeTypes) HealthDataAccess.WRITE];
    final ok = await _h.requestAuthorization(types, permissions: perms);
    if (ok) {
      try {
        if (!await _h.isHealthDataHistoryAuthorized()) await _h.requestHealthDataHistoryAuthorization();
      } catch (_) {}
    }
    await prefs.setBool(_connectedKey, ok);
    return ok;
  }

  Future<void> disconnect() async {
    await prefs.setBool(_connectedKey, false);
    try {
      await _h.revokePermissions();
    } catch (_) {}
  }

  static Sport? _sportOf(HealthWorkoutActivityType t) {
    final n = t.name;
    if (n.contains('RUNNING')) return Sport.run;
    if (n.contains('BIKING') || n.contains('CYCLING')) return Sport.ride;
    if (n.contains('SWIMMING')) return Sport.swim;
    if (n.contains('STRENGTH') || n.contains('WEIGHTLIFTING') || n.contains('CROSS_TRAINING') || n == 'HIGH_INTENSITY_INTERVAL_TRAINING') {
      return Sport.gym;
    }
    return null;
  }

  static HealthWorkoutActivityType _typeOf(Session s) => switch (s.sport) {
    Sport.run => s.indoor ? HealthWorkoutActivityType.RUNNING_TREADMILL : HealthWorkoutActivityType.RUNNING,
    Sport.ride => s.indoor ? HealthWorkoutActivityType.BIKING_STATIONARY : HealthWorkoutActivityType.BIKING,
    Sport.swim => s.indoor ? HealthWorkoutActivityType.SWIMMING_POOL : HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
    Sport.gym => HealthWorkoutActivityType.STRENGTH_TRAINING,
  };

  /// Reads workouts since [since] and converts them to sessions. Workouts that
  // Strive wrote itself and ones already imported or deleted by the user ([knownIds]) are skipped.
  Future<List<Session>> importWorkouts({required DateTime since, required Set<String> knownIds, String Function(Sport)? titleFor}) async {
    await _configure();
    final now = DateTime.now();
    final points = await _h.getHealthDataFromTypes(types: [HealthDataType.WORKOUT], startTime: since, endTime: now);
    final hr = await _h
        .getHealthDataFromTypes(types: [HealthDataType.HEART_RATE], startTime: since, endTime: now)
        .catchError((_) => <HealthDataPoint>[]);
    final out = <Session>[];
    for (final p in points) {
      if (knownIds.contains(p.uuid)) continue;
      if (p.sourceId.contains('strive') || p.sourceName.toLowerCase().contains('strive')) continue;
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;
      final sport = _sportOf(v.workoutActivityType);
      if (sport == null) continue;
      final inRange =
          hr
              .where((h) => !h.dateFrom.isBefore(p.dateFrom) && !h.dateFrom.isAfter(p.dateTo))
              .map((h) => (h.value as NumericHealthValue).numericValue.toDouble())
              .toList();
      final avgHr = inRange.isEmpty ? null : (inRange.reduce((a, b) => a + b) / inRange.length).round();
      final maxHr = inRange.isEmpty ? null : inRange.reduce((a, b) => a > b ? a : b).round();
      final name = v.workoutActivityType.name;
      out.add(
        Session(
          id: importId(p.uuid),
          sport: sport,
          title: (titleFor ?? _titleFor)(sport),
          start: p.dateFrom,
          durationSec: p.dateTo.difference(p.dateFrom).inSeconds,
          distanceM: (v.totalDistance ?? 0).toDouble(),
          avgHr: avgHr,
          maxHr: maxHr,
          calories: v.totalEnergyBurned,
          indoor: name.contains('TREADMILL') || name.contains('STATIONARY') || name.contains('POOL'),
          source: p.sourceName.isEmpty ? 'Health Connect' : _prettySource(p.sourceName),
          externalId: p.uuid,
        ),
      );
    }
    await prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);
    return out;
  }

  static String _titleFor(Sport s) => switch (s) {
    Sport.run => 'Run',
    Sport.ride => 'Ride',
    Sport.swim => 'Swim',
    Sport.gym => 'Strength',
  };

  static String _prettySource(String pkg) {
    if (pkg.contains('shealth') || pkg.contains('samsung')) return 'Samsung Health';
    if (pkg.contains('garmin')) return 'Garmin';
    if (pkg.contains('fitbit')) return 'Fitbit';
    if (pkg.contains('strava')) return 'Strava';
    if (pkg.contains('google')) return 'Google Fit';
    return pkg;
  }

  Future<bool> writeSession(Session s) async {
    if (!connected) return false;
    try {
      await _configure();
      return await _h.writeWorkoutData(
        activityType: _typeOf(s),
        start: s.start,
        end: s.start.add(Duration(seconds: s.durationSec)),
        totalDistance: s.distanceM > 0 ? s.distanceM.round() : null,
        totalEnergyBurned: s.calories,
        title: s.title,
      );
    } catch (e) {
      debugPrint('Health write failed: $e');
      return false;
    }
  }

  Future<void> writeWeight(double kg, DateTime at) async {
    if (!connected) return;
    try {
      await _configure();
      await _h.writeHealthData(value: kg, type: HealthDataType.WEIGHT, startTime: at);
    } catch (_) {}
  }

  /// Steps today, latest resting HR / HRV and last night's sleep.
  Future<DailyVitals> vitals() async {
    if (!connected) return const DailyVitals();
    await _configure();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    int? steps;
    try {
      steps = await _h.getTotalStepsInInterval(midnight, now);
    } catch (_) {}
    Future<List<HealthDataPoint>> get(HealthDataType t, DateTime from) =>
        _h.getHealthDataFromTypes(types: [t], startTime: from, endTime: now).catchError((_) => <HealthDataPoint>[]);
    final rhr = await get(HealthDataType.RESTING_HEART_RATE, now.subtract(const Duration(days: 3))); // time span
    final hrv = await get(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, now.subtract(const Duration(days: 3))); // time span
    final sleep = await get(HealthDataType.SLEEP_SESSION, midnight.subtract(const Duration(hours: 8)));
    double? latest(List<HealthDataPoint> l) {
      if (l.isEmpty) return null;
      l.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final v = l.first.value;
      return v is NumericHealthValue ? v.numericValue.toDouble() : null;
    }

    final sleepMin = sleep.fold<int>(0, (a, p) => a + p.dateTo.difference(p.dateFrom).inMinutes);
    return DailyVitals(steps: steps, restingHr: latest(rhr)?.round(), hrv: latest(hrv), sleepMin: sleepMin == 0 ? null : sleepMin);
  }
}
