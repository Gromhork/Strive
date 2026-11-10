import 'package:flutter/material.dart';

import '../core/event_distances.dart';
import '../core/event_sport_x.dart';
import '../core/format.dart';

/// Race distance choice: the primary distances of [sports] as chips plus "More distances…",
/// which opens [showEventDistanceSheet] with every distance of the catalogue. A selected
/// distance that is not among the chips is shown as an extra selected chip.
class EventDistanceChips extends StatelessWidget {
  const EventDistanceChips({
    super.key,
    required this.sports,
    required this.selected,
    required this.onChanged,
    this.anyLabel,
    this.scroll = false,
  });

  final List<EventSport> sports;
  final String? selected;
  final ValueChanged<String?> onChanged;

  /// Label of an "any distance" chip; null = no such chip (tapping the selected chip clears it).
  final String? anyLabel;

  /// One horizontally scrolling row instead of a wrapping block.
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final shown = [
      for (final d in eventDistances)
        if (d.primary && sports.contains(d.sport)) d,
    ];
    final sel = eventDistanceOf(selected);
    // A distance of another sport (e.g. left over from a previous focus) is not offered.
    if (sel != null && !shown.contains(sel) && sports.contains(sel.sport)) shown.add(sel);
    final chips = <Widget>[
      if (anyLabel != null) ChoiceChip(label: Text(anyLabel!), selected: selected == null, onSelected: (_) => onChanged(null)),
      for (final d in shown)
        ChoiceChip(
          key: ValueKey('distance-${d.key}'),
          label: Text(d.label(l)),
          selected: d.key == selected,
          onSelected: (v) => onChanged(v || anyLabel != null ? d.key : null),
        ),
      ActionChip(
        key: const ValueKey('moreDistances'),
        avatar: const Icon(Icons.more_horiz_rounded, size: 18),
        label: Text(l.moreDistances),
        onPressed: () async {
          final k = await showEventDistanceSheet(context, selected: selected, sports: sports);
          if (k != null) onChanged(k);
        },
      ),
    ];
    if (!scroll) return Wrap(spacing: 8, runSpacing: 8, children: chips);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [for (final (i, c) in chips.indexed) Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 8), child: c)]),
    );
  }
}

/// Bottom sheet with the race distances of [sports] (all sports when null), grouped by
/// sport, with the legs as subtitle. Returns the chosen key (null when dismissed).
Future<String?> showEventDistanceSheet(BuildContext context, {String? selected, List<EventSport>? sports}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final l = context.l10n;
      final theme = Theme.of(context);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(l.eventDistance, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final sport in EventSport.values.where((x) => sports == null || sports.contains(x))) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                  child: Row(
                    children: [
                      Icon(sport.icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sport.label(l),
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final d in eventDistancesFor(sport))
                  ListTile(
                    key: ValueKey('sheet-${d.key}'),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(d.label(l), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: eventDistanceDetail(d) == d.label(l) ? null : Text(eventDistanceDetail(d)),
                    trailing: d.key == selected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
                    selected: d.key == selected,
                    onTap: () => Navigator.pop(context, d.key),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
