import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Which wheels a [DurationField] / [showDurationPicker] offers.
enum DurationUnits {
  /// Hours, minutes and seconds (half marathon, marathon, a recorded workout).
  hms,

  /// Hours and minutes (seconds are always 0).
  hm,

  /// Minutes and seconds – the minutes run past 59 (400 m swim test, 5 km).
  ms;

  /// The wheels for durations up to [maxSec]: minutes + seconds below 100 min (5 km, 400 m swim
  /// test, 1500 m open water), else hours + minutes + seconds.
  static DurationUnits upTo(int? maxSec) => maxSec != null && maxSec < 100 * 60 ? ms : hms;

  /// [seconds] the way these wheels show it: "80:10" with minutes + seconds (the minute wheel runs
  /// past 59 – never "1:20:10" above wheels reading 80 min 10 s), else "1:20:10" / "7:35".
  /// Hours + minutes: "0:29 h" – "29:00" would read as 29 minutes and 0 seconds of the other modes.
  String format(int seconds) {
    String two(int v) => v.toString().padLeft(2, '0');
    return switch (this) {
      ms => '${seconds ~/ 60}:${two(seconds % 60)}',
      hm => '${seconds ~/ 3600}:${two((seconds % 3600) ~/ 60)}${nbsp}h',
      hms => clock(seconds),
    };
  }
}

/// Result of [showDurationPicker]; the sheet returns null when it was dismissed.
class DurationPick {
  const DurationPick(this.seconds);

  /// The chosen duration, null when the value was removed ("Entfernen").
  final int? seconds;
}

/// Tappable duration input: shows the value as "1:45:30" and opens [showDurationPicker] – no
/// free text to mistype ("4" for a 10 km time, "1:2:" while typing), only valid durations.
///
/// [label] floats above the value like a text field's label; [inlineLabel] sits inside the field
/// on the right (race time grid: "5 km", "400 m"). [initial] is where the wheels start without a
/// value (e.g. the suggested target time). [min] / [max] bound what can be taken over; without
/// [units] the wheels follow [max] ([DurationUnits.upTo]), as do the wheels' ranges.
class DurationField extends StatelessWidget {
  const DurationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.inlineLabel,
    this.title,
    this.helperText,
    this.emptyText,
    this.units,
    this.maxHours,
    this.maxMinutes,
    this.initial,
    this.min,
    this.max,
    this.clearable = true,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final String? label, inlineLabel;

  /// Title of the sheet (defaults to [label] / [inlineLabel]).
  final String? title;
  final String? helperText;

  /// Shown instead of a value while there is none (default: an empty clock "–:––:––").
  final String? emptyText;
  final DurationUnits? units;

  /// Largest value of the hour wheel ([DurationUnits.hms] / [DurationUnits.hm]); default from [max], else 23.
  final int? maxHours;

  /// Largest value of the minute wheel with [DurationUnits.ms]; default from [max], else 99.
  final int? maxMinutes;
  final int? initial, min, max;

  /// Offers "Entfernen" for a set value (optional fields).
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = value == null;
    final text = empty ? (emptyText ?? _placeholder) : (units ?? DurationUnits.upTo(max)).format(value!);
    return Semantics(
      button: true,
      label: [label ?? inlineLabel ?? title, if (!empty) text].whereType<String>().join(', '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            floatingLabelBehavior: empty ? FloatingLabelBehavior.auto : FloatingLabelBehavior.always,
            prefixIcon: const Icon(Icons.timer_outlined, size: 20),
            suffixIcon:
                inlineLabel != null
                    ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Align(widthFactor: 1, child: Text(inlineLabel!, style: const TextStyle(fontWeight: FontWeight.w600))),
                    )
                    : const Icon(Icons.unfold_more_rounded, size: 20),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: empty ? scheme.onSurfaceVariant.withValues(alpha: 0.6) : scheme.onSurface,
              fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    // A text field keeping the focus would pop the keyboard up again behind the sheet.
    FocusScope.of(context).unfocus();
    final pick = await showDurationPicker(
      context,
      title: title ?? label ?? inlineLabel ?? '',
      value: value,
      initial: initial,
      units: units,
      maxHours: maxHours,
      maxMinutes: maxMinutes,
      min: min,
      max: max,
      clearable: clearable,
    );
    if (pick != null && pick.seconds != value) onChanged(pick.seconds);
  }

  /// Empty value: a short dash clock – it has to fit the narrow race-time grid next to "21,1 km".
  static const _placeholder = '–:––';
}

/// Bottom sheet with scroll wheels for a duration. Returns the chosen [DurationPick] ("Übernehmen"),
/// `DurationPick(null)` for "Entfernen" (only with [clearable] and a [value]), null when dismissed.
///
/// The wheels start at [value], else [initial], else [min]; they are clamped to the wheels' range.
/// "Übernehmen" is disabled for 0 and outside [min] / [max] (the allowed range is shown).
Future<DurationPick?> showDurationPicker(
  BuildContext context, {
  required String title,
  int? value,
  int? initial,
  DurationUnits? units,
  int? maxHours,
  int? maxMinutes,
  int? min,
  int? max,
  bool clearable = true,
}) {
  return showModalBottomSheet<DurationPick>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => _DurationSheet(
          title: title,
          value: value,
          start: value ?? initial ?? min ?? 0,
          units: units ?? DurationUnits.upTo(max),
          maxHours: maxHours ?? (max == null ? 23 : (max / 3600).ceil()),
          maxMinutes: maxMinutes ?? (max == null ? 99 : (max / 60).ceil()),
          min: min,
          max: max,
          clearable: clearable && value != null,
        ),
  );
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({
    required this.title,
    required this.value,
    required this.start,
    required this.units,
    required this.maxHours,
    required this.maxMinutes,
    required this.min,
    required this.max,
    required this.clearable,
  });

  final String title;
  final int? value;
  final int start;
  final DurationUnits units;
  final int maxHours, maxMinutes;
  final int? min, max;
  final bool clearable;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  static const _itemExtent = 44.0;

  late int _h, _m, _s;
  late final FixedExtentScrollController _hc, _mc, _sc;

  bool get _hasHours => widget.units != DurationUnits.ms;
  bool get _hasSeconds => widget.units != DurationUnits.hm;

  /// First value of the leading wheel: the wheels start at [min] where they can (hours, or the
  /// minutes without an hour wheel) – no scrolling through values that can't be taken.
  late final int _hFirst = _hasHours ? ((widget.min ?? 0) ~/ 3600).clamp(0, widget.maxHours) : 0;
  late final int _mFirst = _hasHours ? 0 : ((widget.min ?? 0) ~/ 60).clamp(0, widget.maxMinutes);

  int get _seconds => _hasHours ? _h * 3600 + _m * 60 + (_hasSeconds ? _s : 0) : _m * 60 + _s;

  @override
  void initState() {
    super.initState();
    // Within what the wheels can show.
    final most = _hasHours ? widget.maxHours * 3600 + 59 * 60 + (_hasSeconds ? 59 : 0) : widget.maxMinutes * 60 + 59;
    final least = _hasHours ? _hFirst * 3600 : _mFirst * 60;
    final int total = widget.start.clamp(least, max(least, most));
    _h = _hasHours ? total ~/ 3600 : 0;
    _m = _hasHours ? (total % 3600) ~/ 60 : total ~/ 60;
    _s = _hasSeconds ? total % 60 : 0;
    _hc = FixedExtentScrollController(initialItem: _h - _hFirst);
    _mc = FixedExtentScrollController(initialItem: _m - _mFirst);
    _sc = FixedExtentScrollController(initialItem: _s);
  }

  @override
  void dispose() {
    _hc.dispose();
    _mc.dispose();
    _sc.dispose();
    super.dispose();
  }

  String? _rangeError(BuildContext context) {
    final v = _seconds;
    final lo = widget.min, hi = widget.max;
    if ((lo != null && v < lo) || (hi != null && v > hi)) {
      final f = widget.units.format;
      return context.l10n.durationRange(f(lo ?? 1), hi == null ? '–' : f(hi));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = _rangeError(context);
    final ok = _seconds > 0 && error == null;
    final wheels = <Widget>[
      if (_hasHours) _wheel('h', _hc, widget.maxHours + 1 - _hFirst, first: _hFirst, looping: false, onChanged: (i) => _h = i),
      _wheel('min', _mc, _hasHours ? 60 : widget.maxMinutes + 1 - _mFirst, first: _mFirst, looping: _hasHours, onChanged: (i) => _m = i),
      if (_hasSeconds) _wheel('s', _sc, 60, looping: true, onChanged: (i) => _s = i),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              widget.units.format(_seconds),
              key: const ValueKey('durationValue'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _itemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The selection band behind the wheels.
                  IgnorePointer(
                    child: Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(AppColors.brand.withValues(alpha: 0.16), scheme.surfaceContainerHighest),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.45)),
                      ),
                    ),
                  ),
                  Row(children: [for (final w in wheels) Expanded(child: w)]),
                ],
              ),
            ),
            // The line is reserved: the sheet does not jump when the range hint appears.
            SizedBox(
              height: 40,
              child: Center(
                child:
                    error == null
                        ? null
                        : Text(
                          error,
                          key: const ValueKey('durationRange'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
                        ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (widget.clearable)
                  TextButton.icon(
                    key: const ValueKey('durationClear'),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: () => Navigator.pop(context, const DurationPick(null)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: Text(l.remove),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('durationApply'),
                  onPressed: ok ? () => Navigator.pop(context, DurationPick(_seconds)) : null,
                  child: Text(l.apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One wheel ([count] values from [first]) with its unit next to the selected value.
  Widget _wheel(
    String unit,
    FixedExtentScrollController c,
    int count, {
    int first = 0,
    required bool looping,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The leading wheel (hours, or minutes without an hour wheel) without a leading zero: "7:35".
    final plain = unit == 'h' || (unit == 'min' && !_hasHours);
    Widget item(int i) => Center(
      child: Text(
        plain ? '${first + i}' : (first + i).toString().padLeft(2, '0'),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final children = [for (var i = 0; i < count; i++) item(i)];
    return Semantics(
      label: unit,
      child: Row(
        children: [
          Expanded(
            child: ListWheelScrollView.useDelegate(
              key: ValueKey('durationWheel-$unit'),
              controller: c,
              itemExtent: _itemExtent,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.6,
              perspective: 0.004,
              overAndUnderCenterOpacity: 0.4,
              onSelectedItemChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => onChanged(first + i % count));
              },
              childDelegate:
                  looping ? ListWheelChildLoopingListDelegate(children: children) : ListWheelChildListDelegate(children: children),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(unit, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
