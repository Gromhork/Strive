import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/gcal_api.dart';
import '../../services/gcal_mapping.dart';
import '../../services/google_auth.dart';

/// Status of the Google Calendar sync (device-local, per Firebase user).
@immutable
class GcalState {
  final bool enabled;
  final String? account;
  final DateTime? lastSync;
  final int eventCount;
  final bool syncing;
  final GcalErrorKind? error;
  final String? errorDetail;

  const GcalState({
    this.enabled = false,
    this.account,
    this.lastSync,
    this.eventCount = 0,
    this.syncing = false,
    this.error,
    this.errorDetail,
  });

  GcalState copyWith({
    bool? enabled,
    String? account,
    DateTime? lastSync,
    int? eventCount,
    bool? syncing,
    GcalErrorKind? error,
    String? errorDetail,
    bool clearError = false,
  }) => GcalState(
    enabled: enabled ?? this.enabled,
    account: account ?? this.account,
    lastSync: lastSync ?? this.lastSync,
    eventCount: eventCount ?? this.eventCount,
    syncing: syncing ?? this.syncing,
    error: clearError ? null : (error ?? this.error),
    errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
  );
}

/// Connect / disconnect / sync the separate "Strive" Google calendar (write-only: other
/// calendars are never read – the OAuth scope `calendar.app.created` does not even allow it).
class GcalController extends Notifier<GcalState> {
  String? _uid;
  Future<int?>? _running;
  bool _again = false;

  String _k(String uid, String key) => 'gcal.$uid.$key';

  @override
  GcalState build() {
    _uid = ref.watch(authProvider.select((a) => a.value?.uid));
    final uid = _uid;
    if (uid == null) return const GcalState();
    final p = ref.watch(prefsProvider);
    final ms = p.getInt(_k(uid, 'lastSync'));
    final err = p.getString(_k(uid, 'error'));
    return GcalState(
      enabled: p.getBool(_k(uid, 'enabled')) ?? false,
      account: p.getString(_k(uid, 'account')),
      lastSync: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
      eventCount: p.getInt(_k(uid, 'count')) ?? 0,
      error: err == null ? null : GcalErrorKind.values.asNameMap()[err],
      errorDetail: p.getString(_k(uid, 'errorDetail')),
    );
  }

  void _set(GcalState s) {
    if (ref.mounted) state = s;
  }

  AppLocalizations _l10n() {
    final code = ref.read(settingsProvider).locale ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  }

  /// Interactive connect. Returns false if the user cancelled. Runs a first sync.
  Future<bool> connect() async {
    final uid = _uid;
    if (uid == null) return false;
    final acc = await GoogleAuth.connectCalendar();
    if (acc == null) return false;
    final p = ref.read(prefsProvider);
    if (acc.email != p.getString(_k(uid, 'account'))) await p.remove(_k(uid, 'calendarId'));
    await p.setBool(_k(uid, 'enabled'), true);
    await p.setString(_k(uid, 'account'), acc.email);
    _set(state.copyWith(enabled: true, account: acc.email, clearError: true));
    await sync();
    return true;
  }

  /// Stops syncing; optionally deletes the "Strive" calendar from the Google account.
  /// Throws [GcalException] if deleting fails (the connection is then kept).
  Future<void> disconnect({required bool deleteCalendar}) async {
    final uid = _uid;
    if (uid == null) return;
    final p = ref.read(prefsProvider);
    try {
      await _running;
    } catch (_) {}
    final calId = p.getString(_k(uid, 'calendarId'));
    final account = p.getString(_k(uid, 'account'));
    if (deleteCalendar && calId != null) {
      final api = GcalApi(GoogleAuth.calendarHeaders);
      try {
        await api.deleteCalendar(calId);
      } on GcalException catch (e) {
        if (e.kind != GcalErrorKind.notFound) rethrow;
      } finally {
        api.close();
      }
      if (account != null) ref.read(repoProvider)?.saveGcalCalendarId(account, null);
    }
    for (final k in ['enabled', 'account', 'calendarId', 'lastSync', 'count', 'error', 'errorDetail']) {
      await p.remove(_k(uid, k));
    }
    _set(const GcalState());
  }

  /// Syncs now (serialised; a request during a running sync triggers one follow-up run).
  /// Never throws: returns the number of synced events, or null on error (see [GcalState.error]).
  Future<int?> sync() async {
    if (_uid == null || !state.enabled) return null;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _running = _doSync(_uid!);
    try {
      return await run;
    } finally {
      _running = null;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(sync());
      }
    }
  }

  Future<int?> _doSync(String uid) async {
    final p = ref.read(prefsProvider);
    final repo = ref.read(repoProvider);
    _set(state.copyWith(syncing: true));
    final api = GcalApi(GoogleAuth.calendarHeaders);
    try {
      final acc = await GoogleAuth.calendarAccount();
      if (acc == null) throw const GcalException(GcalErrorKind.auth, 'Google account not connected');
      if (acc.email != p.getString(_k(uid, 'account'))) {
        // The device's Google account changed – the stored calendar belongs to the old one.
        await p.remove(_k(uid, 'calendarId'));
        await p.setString(_k(uid, 'account'), acc.email);
      }
      final account = acc.email;
      final l = _l10n();

      final plans = await ref.read(plansProvider.future);
      final profile = ref.read(profileOrDefaultProvider);
      final now = DateTime.now();
      final desired = gcalDesiredEvents(plans, l, profile.units, preferredTime: profile.athlete.preferredTime, now: now);
      final (from, to) = gcalWindow(now);

      Future<String> calendarId({bool recreate = false}) async {
        var id = recreate ? null : p.getString(_k(uid, 'calendarId'));
        if (id == null && !recreate) id = await repo?.gcalCalendarId(account);
        if (id == null) {
          String? tz;
          try {
            tz = (await FlutterTimezone.getLocalTimezone()).identifier;
          } catch (_) {}
          id = await api.createCalendar(summary: 'Strive', description: l.gcalCalendarDescription, timeZone: tz);
          repo?.saveGcalCalendarId(account, id);
        }
        await p.setString(_k(uid, 'calendarId'), id);
        return id;
      }

      var calId = await calendarId();
      List<RemoteEvent> remote;
      try {
        remote = await api.listEvents(calId, from, to);
      } on GcalException catch (e) {
        if (e.kind != GcalErrorKind.notFound) rethrow;
        // Calendar was deleted in Google Calendar → create a new one.
        calId = await calendarId(recreate: true);
        remote = const [];
      }

      final diff = gcalDiff(desired, remote);
      await runPooled([
        for (final b in diff.inserts) () => api.upsertEvent(calId, b),
        for (final b in diff.updates) () => api.upsertEvent(calId, b, exists: true),
        for (final id in diff.deletes) () => api.deleteEvent(calId, id),
      ]);
      debugPrint('gcal sync: ${desired.length} events (+${diff.inserts.length} ~${diff.updates.length} -${diff.deletes.length})');

      final at = DateTime.now();
      await p.setInt(_k(uid, 'lastSync'), at.millisecondsSinceEpoch);
      await p.setInt(_k(uid, 'count'), desired.length);
      await p.remove(_k(uid, 'error'));
      await p.remove(_k(uid, 'errorDetail'));
      if (_uid == uid) _set(state.copyWith(syncing: false, account: account, lastSync: at, eventCount: desired.length, clearError: true));
      return desired.length;
    } catch (e) {
      final ge = e is GcalException ? e : GcalException(GcalErrorKind.other, '$e');
      debugPrint('gcal sync failed: $ge');
      await p.setString(_k(uid, 'error'), ge.kind.name);
      await p.setString(_k(uid, 'errorDetail'), ge.message);
      if (_uid == uid) _set(state.copyWith(syncing: false, error: ge.kind, errorDetail: ge.message));
      return null;
    } finally {
      api.close();
    }
  }
}

final gcalProvider = NotifierProvider<GcalController, GcalState>(GcalController.new);

/// Automatic sync: debounced (5 s) after every plan / profile / language change and on app
/// start; plus a periodic check that retries after errors and keeps the moving window fresh.
final gcalAutoSyncProvider = Provider<void>((ref) {
  final enabled = ref.watch(gcalProvider.select((s) => s.enabled));
  if (!enabled) return;
  // Never sync before the plans are loaded – an empty list would delete all events.
  final plans = ref.watch(plansProvider);
  if (!plans.hasValue) return;
  ref.watch(profileProvider.select((p) => (p.value?.athlete.preferredTime, p.value?.imperial)));
  ref.watch(settingsProvider.select((s) => s.locale));

  final ctrl = ref.read(gcalProvider.notifier);
  final debounce = Timer(const Duration(seconds: 5), ctrl.sync);
  final periodic = Timer.periodic(const Duration(minutes: 30), (_) {
    final s = ref.read(gcalProvider);
    final stale = s.lastSync == null || DateTime.now().difference(s.lastSync!) > const Duration(hours: 12);
    final retry = s.error != null && s.error != GcalErrorKind.auth && s.error != GcalErrorKind.apiDisabled;
    if (stale || retry) ctrl.sync();
  });
  ref.onDispose(() {
    debounce.cancel();
    periodic.cancel();
  });
});
