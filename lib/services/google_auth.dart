import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'gcal_api.dart';

enum GuestLinkOutcome { cancelled, linked, accountExists }

/// Result of [GoogleAuth.linkGuest]; [credential] is set for [GuestLinkOutcome.accountExists].
class GuestLinkResult {
  const GuestLinkResult(this.outcome, {this.credential});
  final GuestLinkOutcome outcome;
  final AuthCredential? credential;
}

/// Google sign-in via Firebase Auth. A guest is linked to the Google account ([linkGuest]) so no
/// data is lost.
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

  /// The Google account the user picks, as a Firebase credential (null = cancelled).
  static Future<AuthCredential?> _pick() async {
    final acc = await _get(calendar: false).signIn();
    if (acc == null) return null;
    final a = await acc.authentication;
    return GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken);
  }

  /// Signs in with Google (login page: nobody is signed in). Returns false when the user cancelled.
  /// A signed-in guest goes through [linkGuest] instead – signing in here would drop the guest.
  static Future<bool> signIn() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.isAnonymous) throw StateError('a guest links with GoogleAuth.linkGuest');
    final cred = await _pick();
    if (cred == null) return false;
    await FirebaseAuth.instance.signInWithCredential(cred);
    return true;
  }

  /// Links the signed-in guest with a Google account, so the guest's data stays where it is.
  ///
  /// When that Google account already has a Strive account, Firebase refuses the link
  /// (`credential-already-in-use`). Nothing is switched then: the result carries the credential and
  /// the caller asks the user what happens with the guest data (`linkGuestWithGoogle`). A silent
  /// switch used to orphan every guest document under the old uid and still said "Account saved".
  static Future<GuestLinkResult> linkGuest() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || !current.isAnonymous) throw StateError('linkGuest needs a signed-in guest');
    final cred = await _pick();
    if (cred == null) return const GuestLinkResult(GuestLinkOutcome.cancelled);
    try {
      await current.linkWithCredential(cred);
      return const GuestLinkResult(GuestLinkOutcome.linked);
    } on FirebaseAuthException catch (e) {
      if (!isAccountTakenCode(e.code)) rethrow;
      // The token credential (not e.credential): it is used again in a second Firebase app.
      return GuestLinkResult(GuestLinkOutcome.accountExists, credential: cred);
    }
  }

  /// Whether a link failure means "this sign-in already belongs to another Strive account".
  static bool isAccountTakenCode(String code) => code == 'credential-already-in-use' || code == 'email-already-in-use';

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
