import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../services/active_workout.dart';
import '../../services/google_auth.dart';
import '../../services/tracker.dart';
import '../../services/workout_store.dart';
import '../../widgets/common.dart';
import '../calendar/auto_adjust.dart' show rootMessengerKey;
import '../auth/login_page.dart' show loginNotice;
import 'health_sync.dart';

/// Firestore settings of the app (offline mode: everything cached locally).
const firestoreSettings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

/// Waits until the server has every local change (writes are queued locally first – offline
/// mode). Replaceable in tests.
@visibleForTesting
Future<void> Function() pendingWritesFlush = () => FirebaseFirestore.instance.waitForPendingWrites();

/// How long sign-out waits for the local changes to reach the server.
@visibleForTesting
Duration pendingWritesTimeout = const Duration(seconds: 10);

/// The signed-in Firebase user. Replaceable in tests.
@visibleForTesting
User? Function() signedInUser = () => FirebaseAuth.instance.currentUser;

/// The questions before signing out; true = go ahead.
///
/// - A workout is running: signing out ends it without saving it.
/// - Registered account: local changes not on the server yet (workouts recorded offline, plan
///   entries ticked off) are sent first. Signing out clears the local Firestore cache – and with
///   it the queue of unsent writes – so when they cannot be sent (offline) the user decides.
///   A guest was already told that signing out deletes everything ([confirmGuestLogout]).
Future<bool> readyToSignOut(BuildContext context) async {
  final l = context.l10n;
  final container = ProviderScope.containerOf(context, listen: false);
  if (workoutInProgress(container) &&
      !await confirm(context, l.signOutWorkoutTitle, body: l.signOutWorkoutBody, ok: l.logout, danger: true)) {
    return false;
  }
  final user = signedInUser();
  if (user == null || user.isAnonymous) return true;
  if (!context.mounted) return false;
  if (await syncPendingWrites(context)) return true;
  if (!context.mounted) return false;
  return confirm(context, l.signOutUnsyncedTitle, body: l.signOutUnsyncedBody, ok: l.signOutAnyway, danger: true);
}

/// Sends the queued local writes to the server (with a progress dialog); false when that did not
/// finish within [pendingWritesTimeout] (offline).
Future<bool> syncPendingWrites(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: _ProgressDialog(text: context.l10n.signOutSyncing)),
  ).whenComplete(() => open = false);
  try {
    await pendingWritesFlush().timeout(pendingWritesTimeout);
    return true;
  } catch (e) {
    debugPrint('pending writes not sent: $e');
    return false;
  } finally {
    if (open && nav.mounted) nav.pop();
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) =>
      AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(text))]));
}

/// Whether a gym workout or a cardio recording is running.
bool workoutInProgress(ProviderContainer c) => c.read(activeGymProvider) != null || c.read(trackerProvider) != null;

/// Ends the workout in progress without saving it (GPS recording stops) and deletes the stored
/// copy of it and of an unsaved summary – they belong to the account that is signed out.
Future<void> discardLocalWorkout(ProviderContainer c) async {
  c.invalidate(activeGymProvider);
  c.invalidate(trackerProvider);
  final store = c.read(workoutStoreProvider);
  await store.clearActive();
  await store.clearSummary();
}

/// Signs out and removes the account's data from this device: the Firestore cache (the next
/// account on this phone must not see it, even offline), the workout in progress and the
/// user-scoped providers. [checked]: [readyToSignOut] was already asked. A guest's server data
/// is deleted as well: nobody can ever sign in to an anonymous account again, so it would stay
/// in Firestore forever. Returns false when the user cancelled.
Future<bool> signOutAndClear(BuildContext context, {bool checked = false}) async {
  // The container, not the widget's ref: the calling page is gone once signed out.
  final container = ProviderScope.containerOf(context, listen: false);
  if (!checked && !await readyToSignOut(context)) return false;
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && user.isAnonymous) {
    final uid = user.uid;
    await deleteGuestAccount(user);
    await removeAccountPrefs(container.read(prefsProvider), uid);
  }
  await GoogleAuth.signOut();
  await FirebaseAuth.instance.signOut();
  await discardLocalWorkout(container);
  invalidateUserScoped(container);
  await clearLocalCache();
  return true;
}

/// Deletes a guest's server data and the anonymous account. Best effort: offline, the data
/// stays (the guest was told signing out deletes it; there is nothing else to do with it).
Future<bool> deleteGuestAccount(User guest, {Duration timeout = const Duration(seconds: 10)}) async {
  try {
    await Repository(guest.uid).deleteAllData().timeout(timeout);
    await guest.delete().timeout(timeout);
    return true;
  } catch (e) {
    debugPrint('guest data not deleted: $e');
    return false;
  }
}

/// Removes the settings stored per account (keys carry the uid, e.g. the calendar sync's).
Future<void> removeAccountPrefs(SharedPreferences prefs, String uid) async {
  if (uid.isEmpty) return;
  for (final k in prefs.getKeys().where((k) => k.contains(uid)).toList()) {
    await prefs.remove(k);
  }
}

/// Forgets every provider that holds data of the signed-in account.
void invalidateUserScoped(ProviderContainer ref) {
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
    await removeAccountPrefs(prefs, user.uid);
    await GoogleAuth.signOut();
    await discardLocalWorkout(container);
    invalidateUserScoped(container);
    nav.popUntil((r) => r.isFirst);
    await clearLocalCache();
    // On the login page the app shows next (a snackbar of the page that started this got lost).
    loginNotice.value = l.deleteAccountDone;
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
Future<bool> _typedConfirm(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (_) => const TypedDeleteConfirmDialog()) == true;

/// Whether [input] is the confirmation [word] – case and surrounding blanks aside, and with an
/// umlaut typed out ("LOESCHEN" for "LÖSCHEN": not every keyboard offers "Ö").
bool matchesConfirmWord(String input, String word) {
  String norm(String s) => s.trim().toUpperCase().replaceAll('Ä', 'AE').replaceAll('Ö', 'OE').replaceAll('Ü', 'UE').replaceAll('ß', 'SS');
  return input.trim().isNotEmpty && norm(input) == norm(word);
}

/// The typed confirmation of the account deletion. Pops true when confirmed.
///
/// The text controller lives in this widget's state: it is disposed only when the dialog has
/// left the tree. Disposing it right after `showDialog` returned (the route is popped, but still
/// animating out – the keyboard closing rebuilds the field) made the field use a disposed
/// controller, and the broken element tree then failed with "_elements.contains(element)".
class TypedDeleteConfirmDialog extends StatefulWidget {
  const TypedDeleteConfirmDialog({super.key});

  @override
  State<TypedDeleteConfirmDialog> createState() => _TypedDeleteConfirmDialogState();
}

class _TypedDeleteConfirmDialogState extends State<TypedDeleteConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final match = matchesConfirmWord(_ctrl.text, l.deleteAccountWord);
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
            controller: _ctrl,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: l.deleteAccountWord),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (match) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('deleteAccountGo'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: match ? () => Navigator.pop(context, true) : null,
          child: Text(l.delete),
        ),
      ],
    );
  }
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
  final usePassword = providers.contains('password') && user.email != null;
  // The password (null = cancelled); the field's controller lives in the dialog (see [TypedDeleteConfirmDialog]).
  final password = await showDialog<String>(context: context, builder: (_) => _ReauthDialog(usePassword: usePassword));
  if (password == null) return false;
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

/// "Sign in again" before deleting the account: the password (e-mail accounts) or a hint that
/// Google asks next. Pops the password ('' for Google), null when cancelled.
class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog({required this.usePassword});
  final bool usePassword;

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _pw = TextEditingController();

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.reauthTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.reauthBody),
          if (widget.usePassword) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l.password),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, widget.usePassword ? _pw.text : ''),
          child: Text(widget.usePassword ? l.reauthConfirm : l.reauthGoogle),
        ),
      ],
    );
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
