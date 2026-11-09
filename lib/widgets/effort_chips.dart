import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';

/// "Leicht / Passend / Schwer / Limit".
String effortLabel(AppLocalizations l, Effort e) => switch (e) {
  Effort.easy => l.effortEasy,
  Effort.right => l.effortRight,
  Effort.hard => l.effortHard,
  Effort.limit => l.effortLimit,
};

/// Optional quick effort rating of an exercise after its last work set. Tapping the
/// selected chip again clears it; nothing has to be chosen.
class EffortChips extends StatelessWidget {
  const EffortChips({super.key, required this.value, required this.onChanged, this.title, this.center = false});
  final Effort? value;
  final ValueChanged<Effort?> onChanged;
  final String? title;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title ?? l.effortQuestion, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(l.effortOptional, style: t.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          children: [
            for (final e in Effort.values)
              ChoiceChip(
                key: ValueKey('effort-${e.name}'),
                label: Text(effortLabel(l, e)),
                selected: value == e,
                onSelected: (on) => onChanged(on ? e : null),
              ),
          ],
        ),
      ],
    );
  }
}
