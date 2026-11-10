import 'package:flutter/material.dart';

import '../core/format.dart';
import 'common.dart';

/// "Discard changes?" – true when the user chose to discard.
Future<bool> confirmDiscard(BuildContext context) {
  final l = context.l10n;
  return confirm(context, l.discardChanges, ok: l.discard, danger: true);
}

/// Unsaved-change protection for editors (pages and bottom sheets): Android back (and the
/// sheet's barrier / app-bar back) closes right away while nothing changed, otherwise only
/// after [confirmDiscard].
///
/// [isDirty] is evaluated on the back press, so editors can compare their current values
/// with the initial ones (text fields need no setState to count as changed).
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({super.key, required this.isDirty, required this.child});
  final bool Function() isDirty;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (isDirty() && !await confirmDiscard(context)) return;
      if (context.mounted) Navigator.of(context).pop(result);
    },
    child: child,
  );
}
