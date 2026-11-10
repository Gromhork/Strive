import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/sport.dart';
import '../core/theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.trailing, this.onTap, this.padding});
  final Widget child;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class SportBadge extends StatelessWidget {
  const SportBadge(this.sport, {super.key, this.size = 40, this.filled = false});
  final Sport sport;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? sport.color : sport.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(sport.icon, size: size * 0.55, color: filled ? Colors.black87 : sport.color),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.color});
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color ?? t.bodySmall?.color), const SizedBox(width: 4)],
            Flexible(child: Text(label, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Concentric activity rings – one ring per sport (progress vs weekly target).
class SportRings extends StatelessWidget {
  const SportRings({super.key, required this.values, this.size = 120, this.stroke = 10});
  final Map<Sport, double> values; // 0..1+
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _RingsPainter(values, stroke, Theme.of(context).colorScheme.surfaceContainerHighest)),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.values, this.stroke, this.track);
  final Map<Sport, double> values;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    var r = size.width / 2 - stroke / 2;
    for (final e in values.entries) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(
        rect,
        0,
        2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track,
      );
      final v = e.value.clamp(0.0, 1.0);
      if (v > 0) {
        canvas.drawArc(
          rect,
          -pi / 2,
          2 * pi * max(v, 0.02),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = e.key.color,
        );
      }
      r -= stroke + 3;
      if (r <= stroke) break;
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.values != values;
}

/// GitHub-style training heatmap for the last [weeks] weeks.
class TrainingHeatmap extends StatelessWidget {
  const TrainingHeatmap({super.key, required this.minutesByDay, this.weeks = 26, this.color = AppColors.brand});
  final Map<DateTime, int> minutesByDay;
  final int weeks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dayOnly(DateTime.now());
    final firstMonday = addDays(startOfWeek(today), -(7 * (weeks - 1)));
    final lang = Localizations.localeOf(context).languageCode;
    final dayLabels = lang == 'de' ? ['Mo', '', 'Mi', '', 'Fr', '', 'So'] : ['Mo', '', 'We', '', 'Fr', '', 'Su'];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 3.0;
        final cell = ((c.maxWidth - 22) / weeks - gap).clamp(6.0, 16.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  for (final d in dayLabels)
                    SizedBox(height: cell + gap, width: 22, child: Text(d, style: TextStyle(fontSize: 9, color: scheme.outline))),
                ],
              ),
              for (var w = 0; w < weeks; w++)
                Column(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Builder(
                        builder: (_) {
                          final day = addDays(firstMonday, w * 7 + d);
                          final m = minutesByDay[day] ?? 0;
                          final future = day.isAfter(today);
                          final level = m == 0 ? 0.0 : (m < 30 ? 0.35 : (m < 60 ? 0.6 : (m < 90 ? 0.8 : 1.0)));
                          return Container(
                            width: cell,
                            height: cell,
                            margin: const EdgeInsets.only(right: gap, bottom: gap),
                            decoration: BoxDecoration(
                              color:
                                  future
                                      ? Colors.transparent
                                      : (level == 0 ? scheme.surfaceContainerHighest : color.withValues(alpha: level)),
                              borderRadius: BorderRadius.circular(3),
                              border: sameDay(day, today) ? Border.all(color: scheme.onSurface, width: 1) : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
  });
  final String label;
  final double value, min, max;
  final int? divisions;
  final String Function(double)? format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(format?.call(value) ?? value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String title, {String? body, String? ok, bool danger = false}) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(title),
          content: body == null ? null : Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(
              style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white) : null,
              onPressed: () => Navigator.pop(c, true),
              child: Text(ok ?? l.ok),
            ),
          ],
        ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// Snack bar with an icon and an "Undo" action on one line. Takes the messenger (captured
/// before an async gap / pop) so it also works after the calling page is gone.
void undoToast(
  ScaffoldMessengerState messenger, {
  required String text,
  required String undoLabel,
  required VoidCallback onUndo,
  IconData icon = Icons.delete_outline,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(children: [Icon(icon, size: 20, color: Colors.white70), const SizedBox(width: 12), Expanded(child: Text(text))]),
        action: SnackBarAction(label: undoLabel, onPressed: onUndo),
      ),
    );
}

/// Number input dialog (returns parsed value or null). [signed] allows negative values.
Future<double?> askNumber(BuildContext context, String title, {double? initial, String? suffix, bool signed = false}) async {
  final ctrl = TextEditingController(text: initial == null ? '' : Units.num(initial, 2));
  final l = context.l10n;
  return showDialog<double>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
            decoration: InputDecoration(suffixText: suffix),
            onSubmitted: (v) => Navigator.pop(c, parseNum(v)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, parseNum(ctrl.text)), child: Text(l.save)),
          ],
        ),
  );
}

Future<String?> askText(BuildContext context, String title, {String initial = '', String? hint}) {
  final ctrl = TextEditingController(text: initial);
  final l = context.l10n;
  return showDialog<String>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.pop(c, v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(l.save)),
          ],
        ),
  );
}
