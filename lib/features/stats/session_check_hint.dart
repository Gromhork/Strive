import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../services/session_checks.dart';

/// What [SessionCheck] found, under the duration / distance of a session entered or corrected by
/// hand: "ends in the future" (saving is blocked) and "pace implausible" (a hint only).
class SessionCheckHint extends StatelessWidget {
  const SessionCheckHint({
    super.key,
    required this.check,
    required this.sport,
    required this.start,
    required this.durationSec,
    required this.distanceM,
    required this.units,
  });
  final SessionCheck check;
  final Sport sport;
  final DateTime start;
  final int durationSec;
  final double distanceM;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lines = <(String, Color, Key)>[
      if (check.endsInFuture)
        (
          l.sessionEndsInFuture(DateFormat.Hm(context.localeName).format(start.add(Duration(seconds: durationSec)))), // time span
          Theme.of(context).colorScheme.error,
          const ValueKey('checkFuture'),
        ),
      if (check.implausiblePace) (l.sessionPaceImplausible(_pace()), AppColors.warning, const ValueKey('checkPace')),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (text, color, key) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                key: key,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _pace() => units.paceOrSpeed(sport, distanceM, durationSec);
}
