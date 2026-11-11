import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// One option of a [Segments] control.
class Seg<T> {
  const Seg(this.value, {this.label, this.icon, this.color, this.tooltip});
  final T value;
  final String? label;
  final IconData? icon;

  /// Accent of the thumb when this option is selected (defaults to the brand colour).
  final Color? color;
  final String? tooltip;
}

/// Strive's segmented control: a soft pill track with a sliding thumb.
///
/// Replaces Material's [SegmentedButton], whose outlined boxes and check marks
/// wrap awkwardly ("Allgeme-in") in narrow layouts. Every option gets the same width, and all
/// labels share one font size ([labelLayout]): when one doesn't fit, all get smaller together –
/// never "Ab heute" large next to a tiny "Ab nächstem Montag". Below a readable size the labels
/// wrap onto two lines (at word breaks) instead.
class Segments<T> extends StatelessWidget {
  const Segments({super.key, required this.segments, required this.value, required this.onChanged, this.dense = false, this.expand = true});

  final List<Seg<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  /// Smaller height (e.g. chart metric switches, app-bar toggles).
  final bool dense;

  /// Fill the available width (default). When false, the control is as wide as its content.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    final accent = index < 0 ? AppColors.brand : (segments[index].color ?? AppColors.brand);
    final height = dense ? 36.0 : 46.0;
    final iconOnly = segments.every((s) => s.label == null);

    final baseFont = dense ? 12.5 : 14.0;
    final iconSize = dense ? 17.0 : 19.0;
    final textStyle = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);

    Widget item(Seg<T> s, bool selected, SegLabelFit fit) {
      final fg = selected ? scheme.onSurface : scheme.onSurfaceVariant;
      final children = <Widget>[
        if (s.icon != null) Icon(s.icon, size: iconSize, color: selected ? (s.color ?? accent) : fg),
        if (s.icon != null && s.label != null) const SizedBox(width: 6),
        if (s.label != null)
          Flexible(
            // Last-resort guard (e.g. a single word too long even on two lines): scales only that one.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fit.lines > 1 ? fit.maxWidth : double.infinity),
                child: Text(
                  s.label!,
                  maxLines: fit.lines,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fit.fontSize,
                    height: fit.lines > 1 ? 1.1 : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
      ];
      final content = Padding(
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? (dense ? 10 : 14) : 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: children),
      );
      final tappable = Semantics(
        selected: selected,
        button: true,
        label: s.label ?? s.tooltip,
        child: InkWell(borderRadius: BorderRadius.circular(height), onTap: () => onChanged(s.value), child: Center(child: content)),
      );
      return s.tooltip != null ? Tooltip(message: s.tooltip!, child: tappable) : tappable;
    }

    final track = LayoutBuilder(
      builder: (context, c) {
        final bounded = c.maxWidth.isFinite && expand;
        // Expanded: equal share of the width. Compact: fixed width per option.
        final w = bounded ? c.maxWidth / n : (iconOnly ? (dense ? 40.0 : 48.0) : 88.0);
        final fit = labelLayout(
          [
            for (final s in segments)
              if (s.label != null) (s.label!, s.icon != null),
          ],
          segmentWidth: w,
          innerHeight: height - 8,
          baseFont: baseFont,
          iconSize: iconSize,
          style: textStyle,
          scaler: scaler,
        );
        return SizedBox(
          height: height - 8,
          width: w * n,
          child: Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: w * index,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(accent.withValues(alpha: 0.22), scheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(height),
                      border: Border.all(color: accent.withValues(alpha: 0.55)),
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                  ),
                ),
              Row(children: [for (var i = 0; i < n; i++) SizedBox(width: w, child: item(segments[i], i == index, fit))]),
            ],
          ),
        );
      },
    );

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: track,
    );
  }
}

/// How the labels of a [Segments] control are set: one [fontSize] for all, on one or two [lines];
/// [maxWidth] is the room for a label's text.
class SegLabelFit {
  const SegLabelFit(this.fontSize, this.lines, this.maxWidth);
  final double fontSize;
  final int lines;
  final double maxWidth;
}

/// One font size for all [labels] ((text, has an icon)) of segments [segmentWidth] wide: the base
/// size, or smaller for all when one label is too wide – down to a readable minimum; below that
/// the labels go on two lines (still one size for all), shrunk only as far as two lines need.
SegLabelFit labelLayout(
  List<(String, bool)> labels, {
  required double segmentWidth,
  required double innerHeight,
  required double baseFont,
  required double iconSize,
  required TextStyle style,
  required TextScaler scaler,
}) {
  const pad = 16.0; // the item's horizontal padding (8 + 8)
  final minFont = baseFont - 2.5;
  double room(bool icon) => segmentWidth - pad - (icon ? iconSize + 6 : 0);
  final maxRoom = room(false);
  if (labels.isEmpty || maxRoom <= 0) return SegLabelFit(baseFont, 1, maxRoom);
  ({double width, double height, bool exceeded}) measure(String text, double size, {double? width, int lines = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size, fontWeight: FontWeight.w700, height: lines > 1 ? 1.1 : null)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: lines,
    )..layout(maxWidth: width ?? double.infinity);
    final r = (width: tp.width, height: tp.height, exceeded: tp.didExceedMaxLines);
    tp.dispose();
    return r;
  }

  // One line: the largest common size at which every label fits (the selected, bold weight).
  var scale = 1.0;
  for (final (text, icon) in labels) {
    final natural = measure(text, baseFont).width;
    if (natural > 0) scale = min(scale, room(icon) / natural);
  }
  final single = (baseFont * scale * 2).floorToDouble() / 2;
  if (single >= minFont || labels.every((l) => !l.$1.contains(' '))) {
    return SegLabelFit(single.clamp(1.0, baseFont), 1, maxRoom);
  }
  // Two lines: the largest common size (from the base size down) at which every label fits –
  // broken between words only (no word wider than the room).
  for (var size = baseFont; size >= minFont - 1; size -= 0.5) {
    final ok = labels.every((l) {
      final r = room(l.$2);
      if (l.$1.split(' ').any((word) => measure(word, size).width > r)) return false;
      final m = measure(l.$1, size, width: r, lines: 2);
      return !m.exceeded && m.height <= innerHeight;
    });
    if (ok) return SegLabelFit(size, 2, maxRoom);
  }
  return SegLabelFit(single.clamp(1.0, baseFont), 1, maxRoom);
}
