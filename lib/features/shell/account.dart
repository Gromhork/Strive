import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../services/google_auth.dart';
import '../../widgets/common.dart';
import '../calendar/auto_adjust.dart' show rootMessengerKey;
import 'health_sync.dart';

/// Firestore settings of the app (offline mode: everything cached locally).
const firestoreSettings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

/// Signs out and removes the account's data from this device: the Firestore cache (the next
/// account on this phone must not see it, even offline) and the user-scoped providers.
Future<void> signOutAndClear(BuildContext context) async {
  // The container, not the widget's ref: the calling page is gone once signed out.
  final container = ProviderScope.containerOf(context, listen: false);
  await GoogleAuth.signOut();
  await FirebaseAuth.instance.signOut();
  _invalidateUserScoped(container);
  await clearLocalCache();
}

void _invalidateUserScoped(ProviderContainer ref) {
  ref.invalidate(repoProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(sessionsProvider);
  ref.invalidate(plansProvider);
  ref.invalidate(templatesProvider);
  ref.invalidate(bodyProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(healthServiceProvider);
  ref.invalidate(coachDraftProvider);
  ref.invalidate(navIndexProvider);
  ref.invalidate(sportFilterProvider);
}

/// Clears the local Firestore cache (after sign-out / account deletion).
Future<void> clearLocalCache() async {
  try {
    // Let the providers drop their listeners first (they follow the auth state).
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final db = FirebaseFirestore.instance;
    await db.terminate();
    await db.clearPersistence();
  } catch (e) {
    debugPrint('clearing the Firestore cache failed: $e');
  }
  try {
    FirebaseFirestore.instance.settings = firestoreSettings;
  } catch (e) {
    debugPrint('Firestore settings: $e');
  }
}

/// Profile → "Delete account": two confirmations, a fresh login when needed, then every
/// stored document of the user (all subcollections, shared programs, the user document) and
/// finally the Firebase account itself (GDPR / Google Play account-deletion requirement).
Future<void> deleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final repo = ref.read(repoProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (repo == null || user == null) return;
  if (!await confirm(context, l.deleteAccount, body: l.deleteAccountConfirm1, ok: l.delete, danger: true)) return;
  if (!context.mounted || !await _typedConfirm(context)) return;
  if (!context.mounted || !await _ensureRecentLogin(context, user)) return;
  if (!context.mounted) return;
  final nav = Navigator.of(context, rootNavigator: true);
  final prefs = ref.read(prefsProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(l.deleteAccountRunning))],
            ),
          ),
        ),
  );
  try {
    await repo.deleteAllData();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login' || !context.mounted) rethrow;
      // The login got too old while deleting: ask once more, then delete the account.
      if (!await _reauthenticate(context, user)) rethrow;
      await user.delete();
    }
    for (final k in prefs.getKeys().where((k) => k.contains(user.uid)).toList()) {
      await prefs.remove(k);
    }
    await GoogleAuth.signOut();
    _invalidateUserScoped(container);
    nav.popUntil((r) => r.isFirst);
    await clearLocalCache();
    _notify(l.deleteAccountDone);
  } catch (e) {
    debugPrint('account deletion failed: $e');
    if (nav.canPop()) nav.pop();
    _notify(l.deleteAccountFailed);
  }
}

void _notify(String text) =>
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

/// Second confirmation: the user types the confirmation word.
Future<bool> _typedConfirm(BuildContext context) async {
  final l = context.l10n;
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (c) => StatefulBuilder(
          builder: (c, setState) {
            final match = ctrl.text.trim().toUpperCase() == l.deleteAccountWord.toUpperCase();
            return AlertDialog(
              title: Text(l.deleteAccountConfirm2Title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.deleteAccountConfirm2),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('deleteAccountWord'),
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(hintText: l.deleteAccountWord),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                FilledButton(
                  key: const ValueKey('deleteAccountGo'),
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
                  onPressed: match ? () => Navigator.pop(c, true) : null,
                  child: Text(l.delete),
                ),
              ],
            );
          },
        ),
  );
  ctrl.dispose();
  return ok == true;
}

/// Firebase only deletes an account whose last login is recent (~5 min): ask for a new
/// login first, so the data is not deleted while the account itself cannot be.
Future<bool> _ensureRecentLogin(BuildContext context, User user) async {
  if (user.isAnonymous) return true;
  final last = user.metadata.lastSignInTime;
  if (last != null && DateTime.now().difference(last) < const Duration(minutes: 4)) return true;
  return _reauthenticate(context, user);
}

Future<bool> _reauthenticate(BuildContext context, User user) async {
  final l = context.l10n;
  final providers = {for (final p in user.providerData) p.providerId};
  final pw = TextEditingController();
  final usePassword = providers.contains('password') && user.email != null;
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(l.reauthTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.reauthBody),
              if (usePassword) ...[
                const SizedBox(height: 12),
                TextField(controller: pw, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: l.password)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(usePassword ? l.reauthConfirm : l.reauthGoogle)),
          ],
        ),
  );
  final password = pw.text;
  pw.dispose();
  if (ok != true) return false;
  try {
    if (usePassword) {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
      return true;
    }
    if (providers.contains('google.com')) return await GoogleAuth.reauthenticate(user);
    return false;
  } catch (e) {
    debugPrint('re-authentication failed: $e');
    if (context.mounted) toast(context, l.authError);
    return false;
  }
}

/// Shows a write error (rejected by the server) at most every few seconds.
class WriteErrorNotifier {
  WriteErrorNotifier._();
  static DateTime? _last;
  static String text = 'A change could not be saved.';

  static void show(Object error) {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(seconds: 5)) return;
    _last = now;
    _notify(text);
  }

  /// Wires [Repository.onWriteError] to the snackbar.
  static void install() => Repository.onWriteError = show;
}
