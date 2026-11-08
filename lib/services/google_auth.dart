import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in via Firebase Auth. If the current user is a guest, the Google
/// account is linked so no data is lost.
class GoogleAuth {
  static final _g = GoogleSignIn(scopes: const ['email']);

  /// Returns false when the user cancelled.
  static Future<bool> signIn() async {
    final acc = await _g.signIn();
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

  static Future<void> signOut() async {
    try {
      await _g.signOut();
    } catch (_) {}
  }
}
