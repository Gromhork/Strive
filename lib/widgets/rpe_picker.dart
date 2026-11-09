import 'package:flutter/material.dart';

import '../core/format.dart';
import '../l10n/gen/app_localizations.dart';

/// "very easy" … "maximal" for a session RPE 1–10.
String rpeLabel(AppLocalizations l, int r) =>
    r <= 2
        ? l.rpeVeryEasy
        : r <= 4
        ? l.rpeEasy
        : r <= 6
        ? l.rpeModerate
        : r <= 8
        ? l.rpeHard
        : l.rpeMax;

/// Optional session RPE (1–10) as an inline chip row – nothing is preselected, so a
/// workout saved without touching it stores no rating. "Skip" folds the row away;
/// a chosen value can be cleared again.
class RpePicker extends StatefulWidget {
  const RpePicker({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<RpePicker> createState() => _RpePickerState();
}

class _RpePickerState extends State<RpePicker> {
  bool _skipped = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final v = widget.value;
    if (_skipped && v == null) {
      return Row(
        children: [
          Expanded(child: Text(l.rpeNotSet, style: t.bodySmall)),
          TextButton(key: const ValueKey('rpe-rate'), onPressed: () => setState(() => _skipped = false), child: Text(l.rpeRate)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.rpeOptionalHint, style: t.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var r = 1; r <= 10; r++)
              ChoiceChip(
                key: ValueKey('rpe-$r'),
                label: Text('$r'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                selected: v == r,
                onSelected: (on) => widget.onChanged(on ? r : null),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text(v == null ? l.rpeNotSet : 'RPE $v – ${rpeLabel(l, v)}', style: t.bodySmall)),
            if (v != null)
              TextButton(key: const ValueKey('rpe-clear'), onPressed: () => widget.onChanged(null), child: Text(l.rpeClear))
            else
              TextButton(key: const ValueKey('rpe-skip'), onPressed: () => setState(() => _skipped = true), child: Text(l.skip)),
          ],
        ),
      ],
    );
  }
}
