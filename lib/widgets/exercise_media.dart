import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated demonstration (or static thumbnail) of an exercise from the bundled
/// library. The source animations have a white background: in light mode they are
/// shown as-is on a light card, in dark mode they are rendered "dark" with
/// [darkMediaFilter] so they don't glare as bright boxes.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({super.key, required this.exId, this.animated = true, this.size, this.radius = 20, this.done = false});

  final String exId;
  final bool animated;
  final double? size;
  final double radius;
  final bool done;

  static bool hasMedia(String id) => RegExp(r'^\d{4}$').hasMatch(id);

  /// Background of the media tile in dark mode – the colour the white image
  /// background is mapped to (a dark grey slightly above the card colour).
  static const darkBackground = Color(0xFF242C37);

  /// Colour black / dark lines of the source are mapped to in dark mode (soft white).
  static const darkForeground = Color(0xFFD5D9E1);

  static const _lightBackground = Color(0xFFF4F3F8);

  @override
  Widget build(BuildContext context) {
    final path = 'assets/exercises/${animated ? 'anim' : 'thumb'}/$exId.webp';
    Widget fallback() => Container(
      color: AppColors.gym.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Icon(Icons.fitness_center_rounded, color: AppColors.gym, size: (size ?? 80) * 0.4),
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final img =
        hasMedia(exId)
            ? Image.asset(
              path,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              cacheWidth: animated ? null : 160,
              // Only the decoded image is filtered, not the error fallback.
              frameBuilder: dark ? (_, child, __, ___) => ColorFiltered(colorFilter: darkMediaFilter, child: child) : null,
              errorBuilder: (_, __, ___) => fallback(),
            )
            : fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: dark ? darkBackground : _lightBackground),
            Padding(padding: EdgeInsets.all(animated ? 8 : 2), child: img),
            if (done)
              Container(
                color: AppColors.success.withValues(alpha: 0.82),
                alignment: Alignment.center,
                child: Icon(Icons.check_rounded, color: Colors.black, size: (size ?? 60) * 0.55),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dark-mode rendering of the white-background exercise illustrations: inverts the
/// luminance while keeping the hue (invert, then rotate the hue by 180°), and maps
/// the result linearly so white becomes [ExerciseMedia.darkBackground] and black
/// becomes [ExerciseMedia.darkForeground]. Highlighted muscles stay red.
final ColorFilter darkMediaFilter = _invertLuminanceFilter(ExerciseMedia.darkBackground, ExerciseMedia.darkForeground);

ColorFilter _invertLuminanceFilter(Color bg, Color fg) {
  // Luminance-preserving hue rotation by 180° (feColorMatrix hueRotate, cos = -1, sin = 0).
  const hue = [
    [-0.574, 1.430, 0.144],
    [0.426, 0.430, 0.144],
    [0.426, 1.430, -0.856],
  ];
  final b = [bg.r, bg.g, bg.b];
  final f = [fg.r, fg.g, fg.b];
  final m = <double>[];
  for (var c = 0; c < 3; c++) {
    // out = bg + (fg - bg) * hue(255 - in) / 255 ; rows of `hue` sum to 1.
    final s = f[c] - b[c];
    m.addAll([-s * hue[c][0], -s * hue[c][1], -s * hue[c][2], 0, (s + b[c]) * 255]);
  }
  m.addAll([0, 0, 0, 1, 0]);
  return ColorFilter.matrix(m);
}
