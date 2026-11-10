import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'term_info.dart';
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
  const RpePicker({super.key, required this.value, required this.onChanged, this.hint});
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Line above the scale (default: why rating helps).
  final String? hint;

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
          const TermInfoButton(Term.rpe),
          TextButton(key: const ValueKey('rpe-rate'), onPressed: () => setState(() => _skipped = false), child: Text(l.rpeRate)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [Expanded(child: Text(widget.hint ?? l.rpeOptionalHint, style: t.bodySmall)), const TermInfoButton(Term.rpe)]),
        const SizedBox(height: 8),
        _Scale(value: v, onChanged: widget.onChanged),
        const SizedBox(height: 4),
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

/// 1–10 as one row of equal cells (no wrapping at 360 px), verbal anchors under 2, 4, 6, 8, 10.
class _Scale extends StatelessWidget {
  const _Scale({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  static Color _color(int r) => Color.lerp(AppColors.success, AppColors.danger, (r - 1) / 9)!;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, height: 1.15);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var r = 1; r <= 10; r++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Material(
                    color:
                        value == r
                            ? _color(r)
                            : (value != null && r < value! ? _color(r).withValues(alpha: 0.25) : cs.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: ValueKey('rpe-$r'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(value == r ? null : r),
                      child: SizedBox(
                        height: 40,
                        child: Center(
                          child: Text(
                            '$r',
                            style: TextStyle(fontWeight: FontWeight.w700, color: value == r ? Colors.black87 : cs.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in const [2, 4, 6, 8, 10])
              Expanded(child: Text(rpeLabel(l, r), textAlign: TextAlign.center, maxLines: 2, style: small)),
          ],
        ),
      ],
    );
  }
}
