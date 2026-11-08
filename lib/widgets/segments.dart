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
/// wrap awkwardly ("Allgeme-in") in narrow layouts. Labels here never wrap:
/// they scale down to fit, and every option gets the same width.
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

    Widget item(Seg<T> s, bool selected) {
      final fg = selected ? scheme.onSurface : scheme.onSurfaceVariant;
      final children = <Widget>[
        if (s.icon != null) Icon(s.icon, size: dense ? 17 : 19, color: selected ? (s.color ?? accent) : fg),
        if (s.icon != null && s.label != null) const SizedBox(width: 6),
        if (s.label != null)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                s.label!,
                maxLines: 1,
                style: TextStyle(fontSize: dense ? 12.5 : 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: fg),
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
              Row(children: [for (var i = 0; i < n; i++) SizedBox(width: w, child: item(segments[i], i == index))]),
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
