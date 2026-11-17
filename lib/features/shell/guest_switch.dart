import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../../services/app_check.dart';
import '../../services/google_auth.dart';
import '../../services/guest_merge.dart';
import '../../services/workout_store.dart';
import '../../widgets/common.dart';
import '../auth/login_page.dart' show loginNotice;
import '../calendar/auto_adjust.dart' show rootMessengerKey;
import 'account.dart';

/// What happens with the guest data when the Google account already has Strive data.
enum GuestDataChoice { merge, discard }

/// Profile → "Secure account" → Google. Links the guest with the Google account. When that
/// account already has Strive data the link is impossible: the user decides between taking the
/// guest data along, discarding it, or cancelling – "Account saved!" only after a real link.
Future<void> linkGuestWithGoogle(BuildContext context) async {
  final l = context.l10n;
  final GuestLinkResult r;
  try {
    r = await GoogleAuth.linkGuest();
  } catch (e) {
    if (context.mounted) toast(context, '${l.authError}: $e');
    return;
  }
  if (!context.mounted) return;
  switch (r.outcome) {
    case GuestLinkOutcome.cancelled:
      return;
    case GuestLinkOutcome.linked:
      toast(context, l.accountLinked);
    case GuestLinkOutcome.accountExists:
      final choice = await showDialog<GuestDataChoice>(context: context, builder: (_) => const GuestExistsDialog());
      if (choice == null || !context.mounted) {
        // Next time the account picker shows again (not silently this account).
        await GoogleAuth.signOut();
        return;
      }
      await switchFromGuest(context, r.credential!, keepData: choice == GuestDataChoice.merge);
  }
}

/// "This Google account already has Strive data": take along / discard / cancel.
class GuestExistsDialog extends StatelessWidget {
  const GuestExistsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
      title: Text(l.guestExistsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(l.guestExistsBody), const SizedBox(height: 12), Text(l.guestExistsMergeInfo)],
      ),
      actions: [
        TextButton(key: const ValueKey('guestExistsCancel'), onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(
          key: const ValueKey('guestExistsDiscard'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, GuestDataChoice.discard),
          child: Text(l.guestExistsDiscard),
        ),
        FilledButton(
          key: const ValueKey('guestExistsMerge'),
          onPressed: () => Navigator.pop(context, GuestDataChoice.merge),
          child: Text(l.guestExistsMerge),
        ),
      ],
    );
  }
}

/// Switches from the signed-in guest to the account of [cred].
///
/// [keepData]: the guest data is first copied into that account – through a second Firebase app
/// signed in to it, while the guest stays signed in here. Only when every batch was accepted by
/// the server are the guest's documents and the anonymous account deleted (they could never be
/// reached again – an anonymous account cannot sign in twice) and the app switches. Any failure
/// before that changes nothing. Otherwise the guest data is deleted (as chosen) and the app
/// switches.
Future<void> switchFromGuest(BuildContext context, AuthCredential cred, {required bool keepData}) async {
  final l = context.l10n;
  final guest = FirebaseAuth.instance.currentUser;
  if (guest == null || !guest.isAnonymous) return;
  final guestUid = guest.uid;
  final container = ProviderScope.containerOf(context, listen: false);
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(l.guestSwitchRunning))],
            ),
          ),
        ),
  );

  // 1. Nothing has changed yet: a failure leaves the guest as it was.
  ({String uid, int sessions})? moved;
  try {
    if (keepData) {
      moved = await copyGuestData(guestUid, cred);
    } else {
      await Repository(guestUid).ensureServerReachable();
    }
  } catch (e) {
    debugPrint('guest switch failed: $e');
    if (nav.canPop()) nav.pop();
    await GoogleAuth.signOut();
    _notify(l.guestSwitchFailed);
    return;
  }

  // 2. The guest data is in the target account (or was to be discarded): delete the guest.
  final deleted = await deleteGuestAccount(guest);
  if (!deleted) debugPrint('guest $guestUid could not be deleted after the switch');
  await removeAccountPrefs(container.read(prefsProvider), guestUid);
  final store = container.read(workoutStoreProvider);
  if (moved != null) {
    // A workout in progress is the same person's: it continues in the target account.
    await store.reassign(guestUid, moved.uid);
  } else {
    await discardLocalWorkout(container);
  }

  // 3. Switch.
  try {
    await FirebaseAuth.instance.signInWithCredential(cred);
  } catch (e) {
    debugPrint('sign-in after the guest switch failed: $e');
    loginNotice.value = l.guestSwitchSignInAgain;
  }
  invalidateUserScoped(container);
  nav.popUntil((r) => r.isFirst);
  if (FirebaseAuth.instance.currentUser?.isAnonymous == false) {
    _notify(moved != null ? l.guestSwitchMerged(moved.sessions) : l.guestSwitchDiscarded);
  }
}

/// Copies the guest's data into the account of [cred] (see [guestTransfer]) and returns that
/// account's uid and the number of workouts taken along. Throws when anything fails.
Future<({String uid, int sessions})> copyGuestData(String guestUid, AuthCredential cred) async {
  final guestData = await Repository(guestUid).exportAll();
  final app = await _transferApp();
  try {
    await activateAppCheck(app);
    final auth = FirebaseAuth.instanceFor(app: app);
    final signedIn = await auth.signInWithCredential(cred);
    final uid = signedIn.user!.uid;
    final db = FirebaseFirestore.instanceFor(app: app);
    // Nothing of this transfer stays in a local cache.
    db.settings = const Settings(persistenceEnabled: false);
    final target = Repository(uid, db);
    final t = guestTransfer(guest: guestData, target: await target.exportAll(), newId: target.newId);
    await target.importAll(t.writes);
    return (uid: uid, sessions: t.sessions);
  } finally {
    try {
      await FirebaseAuth.instanceFor(app: app).signOut();
      await app.delete();
    } catch (e) {
      debugPrint('transfer app cleanup: $e');
    }
  }
}

/// A second Firebase app (same project): the target account is signed in there while the guest
/// stays signed in in the default app.
Future<FirebaseApp> _transferApp() async {
  const name = 'strive-guest-transfer';
  try {
    // Left over from an interrupted transfer.
    await Firebase.app(name).delete();
  } catch (_) {}
  return Firebase.initializeApp(name: name, options: Firebase.app().options);
}

void _notify(String text) =>
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
