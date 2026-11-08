import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated demonstration (or static thumbnail) of an exercise from the bundled
/// library. The source animations have a white background, so they are shown on
/// a light card that reads well in both themes.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({super.key, required this.exId, this.animated = true, this.size, this.radius = 20, this.done = false});

  final String exId;
  final bool animated;
  final double? size;
  final double radius;
  final bool done;

  static bool hasMedia(String id) => RegExp(r'^\d{4}$').hasMatch(id);

  @override
  Widget build(BuildContext context) {
    final path = 'assets/exercises/${animated ? 'anim' : 'thumb'}/$exId.webp';
    Widget fallback() => Container(
      color: AppColors.gym.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Icon(Icons.fitness_center_rounded, color: AppColors.gym, size: (size ?? 80) * 0.4),
    );
    final img =
        hasMedia(exId)
            ? Image.asset(
              path,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              cacheWidth: animated ? null : 160,
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
            const ColoredBox(color: Color(0xFFF4F3F8)),
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
