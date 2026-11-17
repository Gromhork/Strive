import 'package:flutter/material.dart';

/// Text that never breaks inside a word: when its longest word is wider than the space (a long
/// German compound like "Technikschwimmen" at large text sizes), the whole text shrinks just enough
/// – instead of "Technikschwimm-en" over two lines (audit UX-17: "Interval|le", "Techni|k" on Home at 1.3).
class WholeWordsText extends StatelessWidget {
  const WholeWordsText(this.text, {super.key, this.textKey, this.style, this.textAlign = TextAlign.start, this.maxLines = 2});
  final String text;
  final Key? textKey;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final scaler = MediaQuery.textScalerOf(context);
      final base = DefaultTextStyle.of(context).style.merge(style);
      var widest = 0.0;
      for (final w in text.split(RegExp(r'\s+'))) {
        final tp = TextPainter(
          text: TextSpan(text: w, style: base),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (tp.width > widest) widest = tp.width;
        tp.dispose();
      }
      final shrink = widest > c.maxWidth && widest > 0 ? c.maxWidth / widest : 1.0;
      return Text(
        text,
        key: textKey,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
        textScaler: shrink < 1 ? TextScaler.linear(scaler.scale(14) / 14 * shrink * 0.98) : null,
      );
    },
  );
}
