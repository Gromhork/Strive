import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Firebase App Check: proves to Firebase that a request comes from this app on a real device
// (Play Integrity) and not from a script that copied the API key out of the APK. Without it the
// Gemini coach (Firebase AI Logic) could be called by anyone holding the key – on the owner's
// bill. The client only *sends* the tokens; the backend rejects requests without a valid one
// only after enforcement is switched on in the Firebase console (docs/app-check.md).

/// The App Check provider of this build: Play Integrity in release builds, the debug provider
/// otherwise (its debug token is printed to logcat and must be registered in the console).
AndroidProvider appCheckAndroidProvider({bool release = kReleaseMode}) => release ? AndroidProvider.playIntegrity : AndroidProvider.debug;

AppleProvider appCheckAppleProvider({bool release = kReleaseMode}) => release ? AppleProvider.deviceCheck : AppleProvider.debug;

/// Activates App Check for [app] (default: the default app). Never throws: a device without
/// Play services must still be able to start the app – its requests then simply carry no
/// token, and enforcement decides.
Future<void> activateAppCheck([FirebaseApp? app]) async {
  try {
    final ac = app == null ? FirebaseAppCheck.instance : FirebaseAppCheck.instanceFor(app: app);
    await ac.activate(androidProvider: appCheckAndroidProvider(), appleProvider: appCheckAppleProvider());
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

/// Firebase AI Logic (Gemini) with an App Check token attached to every request.
/// Every call site must use this: `FirebaseAI.googleAI` caches the first instance it creates,
/// so one call without App Check would send tokenless requests for the whole app run.
FirebaseAI striveAI() => FirebaseAI.googleAI(appCheck: FailSoftAppCheck());

/// App Check that never fails a request on the client: when no token can be obtained (debug
/// token not registered yet, sideloaded build that Play Integrity does not recognise, no Play
/// services, offline) the request goes out without one. Before enforcement it then works as
/// before; after enforcement the backend rejects it – the server, not a client error, decides.
/// (firebase_ai sends `getToken()` before each request and lets its exception fail the request.)
class FailSoftAppCheck implements FirebaseAppCheck {
  FailSoftAppCheck({FirebaseAppCheck? inner, Future<String?> Function(bool? forceRefresh)? fetch}) : _given = inner, _fetch = fetch;
  final FirebaseAppCheck? _given;
  FirebaseAppCheck get _inner => _given ?? FirebaseAppCheck.instance;
  final Future<String?> Function(bool? forceRefresh)? _fetch;

  @override
  Future<String?> getToken([bool? forceRefresh]) async {
    try {
      return await (_fetch ?? _inner.getToken)(forceRefresh);
    } catch (e) {
      debugPrint('App Check token unavailable: $e');
      return null;
    }
  }

  @override
  FirebaseApp get app => _inner.app;

  @override
  set app(FirebaseApp value) => _inner.app = value;

  @override
  // Android / iOS app: no web provider (its type is not exported by this plugin version).
  Future<void> activate({
    Object? webProvider,
    AndroidProvider androidProvider = AndroidProvider.playIntegrity,
    AppleProvider appleProvider = AppleProvider.deviceCheck,
  }) => _inner.activate(androidProvider: androidProvider, appleProvider: appleProvider);

  @override
  Future<String> getLimitedUseToken() => _inner.getLimitedUseToken();

  @override
  Stream<String?> get onTokenChange => _inner.onTokenChange;

  @override
  Future<void> setTokenAutoRefreshEnabled(bool isTokenAutoRefreshEnabled) => _inner.setTokenAutoRefreshEnabled(isTokenAutoRefreshEnabled);

  @override
  Map<dynamic, dynamic> get pluginConstants => _inner.pluginConstants;
}
