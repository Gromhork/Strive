import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/format.dart';
import 'core/sport.dart';
import 'data/exercise_db.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'services/compliance.dart';
import 'services/insights.dart';
import 'services/load_prescription.dart';
import 'services/weather_service.dart';

// ───────────────────────────── Auth & repository ─────────────────────────────

final authProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final repoProvider = Provider<Repository?>((ref) {
  final user = ref.watch(authProvider).value;
  return user == null ? null : Repository(user.uid);
});

Stream<T> _empty<T>(T v) => Stream.value(v);

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? _empty(null) : r.profile();
});

/// Non-null profile with defaults (convenience for widgets).
final profileOrDefaultProvider = Provider<UserProfile>((ref) => ref.watch(profileProvider).value ?? const UserProfile());

final sessionsProvider = StreamProvider<List<Session>>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? _empty(const []) : r.sessions();
});

final templatesProvider = StreamProvider<List<WorkoutTemplate>>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? _empty(const []) : r.templates();
});

final plansProvider = StreamProvider<List<PlannedWorkout>>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? _empty(const []) : r.plans();
});

final bodyProvider = StreamProvider<List<BodyEntry>>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? _empty(const []) : r.body();
});

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final r = ref.watch(repoProvider);
  return r == null ? _empty(const []) : r.goals();
});

/// Bundled exercise DB. No automatic retry: a failing load must surface as an error
/// (Riverpod 3 would otherwise retry forever and show an endless spinner).
final exerciseDbProvider = FutureProvider<ExerciseDb>((ref) => ExerciseDb.load(), retry: (_, __) => null);

// ───────────────────────────── Derived ─────────────────────────────

final sessionListProvider = Provider<List<Session>>((ref) => ref.watch(sessionsProvider).value ?? const []);
final planListProvider = Provider<List<PlannedWorkout>>((ref) => ref.watch(plansProvider).value ?? const []);
final templateListProvider = Provider<List<WorkoutTemplate>>((ref) => ref.watch(templatesProvider).value ?? const []);

final gameStatsProvider = Provider<GameStats>((ref) {
  final s = ref.watch(sessionListProvider);
  final target = ref.watch(profileOrDefaultProvider).weeklyTarget;
  return GameStats.compute(s, target, plans: ref.watch(planListProvider));
});

final recoveryProvider = Provider<RecoveryInfo>((ref) => RecoveryInfo.compute(ref.watch(sessionListProvider)));

/// Prescribed gym loads from history, setup 1RMs or body weight (see [LoadPrescriber]).
final loadPrescriberProvider = Provider<LoadPrescriber>(
  (ref) => LoadPrescriber(
    history: ref.watch(sessionListProvider),
    profile: ref.watch(profileOrDefaultProvider),
    db: ref.watch(exerciseDbProvider).value,
  ),
);

/// Plan phase ('base' | 'build' | 'peak' | 'taper' | 'recovery') of a planned workout id.
String? planPhaseOf(List<PlannedWorkout> plans, String? planId) =>
    planId == null ? null : plans.where((p) => p.id == planId).firstOrNull?.phase;

final weatherProvider = FutureProvider<Weather>((ref) async {
  final lang = ref.watch(settingsProvider).locale ?? 'de';
  // Refresh every 20 minutes.
  final t = Timer(const Duration(minutes: 20), ref.invalidateSelf);
  ref.onDispose(t.cancel);
  final prefs = ref.read(prefsProvider);
  final la = prefs.getDouble('wxLat'), lo = prefs.getDouble('wxLon');
  return WeatherService.fetch(
    lang,
    cached: la == null || lo == null ? null : (la, lo),
    onPosition: (a, o) {
      prefs.setDouble('wxLat', a);
      prefs.setDouble('wxLon', o);
    },
  ).timeout(const Duration(seconds: 50));
}, retry: (_, __) => null);

/// Global sport filter from the top switcher (null = all sports).
class SportFilter extends Notifier<Sport?> {
  @override
  Sport? build() => null;
  void set(Sport? s) => state = s;
}

final sportFilterProvider = NotifierProvider<SportFilter, Sport?>(SportFilter.new);

/// Bottom navigation index (lets pages switch tabs, e.g. "to calendar").
class NavIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

final navIndexProvider = NotifierProvider<NavIndex, int>(NavIndex.new);

/// Question another page hands to the coach tab ("Ask the coach" on a planned workout): the
/// coach page puts it into its input field and clears it.
class CoachDraft extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? q) => state = q;
}

final coachDraftProvider = NotifierProvider<CoachDraft, String?>(CoachDraft.new);

// ───────────────────────────── Settings (device-local) ─────────────────────────────

final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

class AppSettings {
  final String? locale; // null = system
  final ThemeMode themeMode;
  final bool trainingReminder;
  final int reminderHour;
  final bool vibrate;

  /// Gym: log the reserve (reps in the tank) of every set – off by default; the per-exercise
  /// effort chips stay.
  final bool logRir;

  const AppSettings({
    this.locale,
    this.themeMode = ThemeMode.dark,
    this.trainingReminder = false,
    this.reminderHour = 8,
    this.vibrate = true,
    this.logRir = false,
  });

  AppSettings copyWith({
    String? locale,
    bool clearLocale = false,
    ThemeMode? themeMode,
    bool? trainingReminder,
    int? reminderHour,
    bool? vibrate,
    bool? logRir,
  }) => AppSettings(
    locale: clearLocale ? null : (locale ?? this.locale),
    themeMode: themeMode ?? this.themeMode,
    trainingReminder: trainingReminder ?? this.trainingReminder,
    reminderHour: reminderHour ?? this.reminderHour,
    vibrate: vibrate ?? this.vibrate,
    logRir: logRir ?? this.logRir,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(prefsProvider);
    return AppSettings(
      locale: p.getString('locale'),
      themeMode: ThemeMode.values[p.getInt('themeMode') ?? ThemeMode.dark.index],
      trainingReminder: p.getBool('trainingReminder') ?? false,
      reminderHour: p.getInt('reminderHour') ?? 8,
      vibrate: p.getBool('vibrate') ?? true,
      logRir: p.getBool('logRir') ?? false,
    );
  }

  void update(AppSettings s) {
    state = s;
    s.locale == null ? _p.remove('locale') : _p.setString('locale', s.locale!);
    _p.setInt('themeMode', s.themeMode.index);
    _p.setBool('trainingReminder', s.trainingReminder);
    _p.setInt('reminderHour', s.reminderHour);
    _p.setBool('vibrate', s.vibrate);
    _p.setBool('logRir', s.logRir);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ───────────────────────────── Cached heavy computations ─────────────────────────────

/// Banister fitness/fatigue series of all sessions (recomputed only when sessions change).
final fitnessSeriesProvider = Provider<List<FitnessPoint>>((ref) => fitnessSeries(ref.watch(sessionListProvider)));

/// Best lifts per exercise id over all sessions.
final exerciseRecordsProvider = Provider<Map<String, ExerciseRecord>>((ref) => exerciseRecords(ref.watch(sessionListProvider)));

/// Plan id → linked session (for plan compliance).
final planSessionsProvider = Provider<Map<String, Session>>(
  (ref) => linkPlanSessions(ref.watch(planListProvider), ref.watch(sessionListProvider), profile: ref.watch(profileOrDefaultProvider)),
);

// ───────────────────────────── Today ─────────────────────────────

/// Today's date (midnight). Changes at midnight and when the app comes back to the
/// foreground on a new day, so "today", "missed" and the goal forecast never go stale while
/// the app stays open overnight. Watch it in widgets / providers that depend on the day.
class Today extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    AppLifecycleListener? listener;
    try {
      listener = AppLifecycleListener(onResume: refresh);
    } catch (_) {
      // No widgets binding (pure unit tests): midnight timer only.
    }
    ref.onDispose(() {
      _timer?.cancel();
      listener?.dispose();
    });
    _schedule();
    return dayOnly(DateTime.now());
  }

  void _schedule() {
    _timer?.cancel();
    // No midnight timer under `flutter test` (a pending timer fails widget tests; tests that
    // need another day override this provider).
    if (_underTest) return;
    final now = DateTime.now();
    _timer = Timer(addDays(now, 1).difference(now) + const Duration(seconds: 1), refresh);
  }

  /// Re-reads the clock (midnight timer, app resumed).
  void refresh() {
    final d = dayOnly(DateTime.now());
    if (d != state) state = d;
    _schedule();
  }
}

bool get _underTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

final todayProvider = NotifierProvider<Today, DateTime>(Today.new);

/// The current hour (0–23): changes on the hour and when the app comes back to the
/// foreground – the greeting ("Guten Morgen" / "Guten Abend") follows the local time even
/// when the app stays open.
class HourTick extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    AppLifecycleListener? listener;
    try {
      listener = AppLifecycleListener(onResume: refresh);
    } catch (_) {}
    ref.onDispose(() {
      _timer?.cancel();
      listener?.dispose();
    });
    _schedule();
    return DateTime.now().hour;
  }

  void _schedule() {
    _timer?.cancel();
    if (_underTest) return;
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), refresh);
  }

  void refresh() {
    final h = DateTime.now().hour;
    if (h != state) state = h;
    _schedule();
  }
}

final hourProvider = NotifierProvider<HourTick, int>(HourTick.new);

/// "Guten Morgen" until 11, "Guten Tag" until 18, then "Guten Abend" (by local [hour]).
String greetingFor(int hour, {required String morning, required String afternoon, required String evening}) =>
    hour >= 4 && hour < 11 ? morning : (hour >= 11 && hour < 18 ? afternoon : evening);
