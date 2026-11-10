import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'gcal_api.dart';

/// Google sign-in via Firebase Auth. If the current user is a guest, the Google
/// account is linked so no data is lost.
///
/// Also provides OAuth access for the Google Calendar sync, independent of how the user
/// signed in to Firebase (guest, e-mail or Google).
class GoogleAuth {
  /// Lets Strive create secondary calendars and manage events only in those calendars.
  static const calendarScope = 'https://www.googleapis.com/auth/calendar.app.created';

  // The Android plugin only issues access tokens for the scopes passed at initialisation
  // (requestScopes() does not extend them), and initialisation is global. So we keep one
  // client per scope set and re-initialise (new instance) when switching between them.
  static GoogleSignIn? _client;
  static bool _clientHasCalendar = false;

  static GoogleSignIn _get({required bool calendar}) {
    if (_client == null || _clientHasCalendar != calendar) {
      _client = GoogleSignIn(
        scopes: [
          if (calendar) ...['email', calendarScope] else 'email',
        ],
      );
      _clientHasCalendar = calendar;
    }
    return _client!;
  }

  /// Returns false when the user cancelled.
  static Future<bool> signIn() async {
    final acc = await _get(calendar: false).signIn();
    if (acc == null) return false;
    final a = await acc.authentication;
    final cred = GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken);
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithCredential(cred);
        return true;
      } on FirebaseAuthException catch (e) {
        // Google account already has a Strive account → switch to it.
        if (e.code != 'credential-already-in-use') rethrow;
      }
    }
    await FirebaseAuth.instance.signInWithCredential(cred);
    return true;
  }

  /// Signs the current Firebase user in again with Google (sensitive operations such as
  /// deleting the account need a recent login). Returns false when the user cancelled.
  static Future<bool> reauthenticate(User user) async {
    final g = _get(calendar: false);
    final acc = await g.signIn();
    if (acc == null) return false;
    final a = await acc.authentication;
    await user.reauthenticateWithCredential(GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken));
    return true;
  }

  static Future<void> signOut() async {
    try {
      await _get(calendar: _clientHasCalendar).signOut();
    } catch (_) {}
  }

  // ───────────────────────────── Calendar ─────────────────────────────

  /// Interactive: reuses the signed-in Google account if it already granted the calendar
  /// scope, otherwise shows the account picker + consent. Never touches Firebase Auth.
  /// Returns null when the user cancelled or declined.
  static Future<GoogleSignInAccount?> connectCalendar() async {
    final g = _get(calendar: true);
    GoogleSignInAccount? acc;
    try {
      acc = await g.signInSilently(suppressErrors: false);
    } on PlatformException catch (e) {
      if (e.code == 'network_error') throw GcalException(GcalErrorKind.offline, e.message ?? e.code);
    }
    acc ??= await g.signIn();
    if (acc == null) return null;
    if (!await g.requestScopes(const [calendarScope])) return null;
    return acc;
  }

  /// Silent account for background sync (null when the user has to connect again).
  static Future<GoogleSignInAccount?> calendarAccount() async {
    final g = _get(calendar: true);
    if (g.currentUser != null) return g.currentUser;
    try {
      return await g.signInSilently(suppressErrors: false);
    } on PlatformException catch (e) {
      if (e.code == 'network_error') throw GcalException(GcalErrorKind.offline, e.message ?? e.code);
      return null;
    }
  }

  /// Authorization headers carrying the calendar scope; [refresh] drops the cached token.
  static Future<Map<String, String>> calendarHeaders({bool refresh = false}) async {
    final acc = await calendarAccount();
    if (acc == null) throw const GcalException(GcalErrorKind.auth, 'Google account not connected');
    if (refresh) await acc.clearAuthCache();
    try {
      return await acc.authHeaders;
    } on PlatformException catch (e) {
      if (e.code == 'network_error') throw GcalException(GcalErrorKind.offline, e.message ?? e.code);
      throw GcalException(GcalErrorKind.auth, e.message ?? e.code);
    }
  }
}
