import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'term_info.dart';
import '../l10n/gen/app_localizations.dart';

/// "Leicht / Passend / Schwer / Limit".
String effortLabel(AppLocalizations l, Effort e) => switch (e) {
  Effort.easy => l.effortEasy,
  Effort.right => l.effortRight,
  Effort.hard => l.effortHard,
  Effort.limit => l.effortLimit,
};

/// Reserve chips of a set (reps in the tank) → stored set RPE (RPE = 10 − RIR, "4+" = 6).
const reserveChips = [('4+', 6.0), ('3', 7.0), ('2', 8.0), ('1', 9.0), ('0', 10.0)];

/// "4+", "2", "1.5" … for a stored set RPE.
String reserveLabel(double rpe) => 10 - rpe >= 4 ? '4+' : Units.num(10 - rpe);

/// Optional per-set reserve ("Reserve 4+ 3 2 1 0" reps in the tank); tapping the selected
/// chip again clears it. Shown only with the "log reserve per set" setting.
class ReservePicker extends StatelessWidget {
  const ReservePicker({super.key, required this.rpe, required this.onChanged});
  final double? rpe;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(l.reserveLabel, style: t.labelLarge),
            const SizedBox(width: 6),
            Flexible(child: Text(l.reserveHint, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
            const TermInfoButton(Term.rir),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (label, r) in reserveChips)
              ChoiceChip(
                key: ValueKey('rir-$label'),
                label: Text(label),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                selected: rpe == r,
                onSelected: (on) => onChanged(on ? r : null),
              ),
          ],
        ),
      ],
    );
  }
}

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
        Row(
          mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Flexible(child: Text(title ?? l.effortQuestion, style: const TextStyle(fontWeight: FontWeight.w600))),
            const TermInfoButton(Term.rir),
          ],
        ),
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
