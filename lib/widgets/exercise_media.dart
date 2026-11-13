import 'dart:ui' as ui;

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

  static bool hasMedia(String id) => _mediaId.hasMatch(id);
  static final _mediaId = RegExp(r'^\d{4}$');

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
    // The demos are animated WebPs whose frame timing is already slowed to ~0.55× in the
    // files themselves (tool/slow_anim.py), so the standard Image widget plays them – it
    // also pauses them while tickers are disabled (off-screen routes).
    final img =
        !hasMedia(exId)
            ? fallback()
            : dark
            // Dark mode: the colour filter is applied while painting the image, not with a
            // ColorFiltered layer – a filter layer over an animated image renders blank /
            // stale frames on some GPUs (Impeller on OpenGL ES).
            ? FilteredAssetImage(path: path, colorFilter: darkMediaFilter, cacheWidth: animated ? null : 160, fallback: fallback)
            : Image.asset(
              path,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              cacheWidth: animated ? null : 160,
              errorBuilder: (_, __, ___) => fallback(),
            );
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

/// Shows an (animated) image asset painted through [colorFilter]. Like [Image] it keeps
/// listening to the image stream only while tickers are enabled, so animations pause on
/// off-screen routes, and it disposes every replaced frame.
class FilteredAssetImage extends StatefulWidget {
  const FilteredAssetImage({super.key, required this.path, required this.colorFilter, required this.fallback, this.cacheWidth});

  final String path;
  final ColorFilter colorFilter;
  final Widget Function() fallback;
  final int? cacheWidth;

  @override
  State<FilteredAssetImage> createState() => _FilteredAssetImageState();
}

class _FilteredAssetImageState extends State<FilteredAssetImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  bool _failed = false;
  bool _listening = false;
  late final _listener = ImageStreamListener(_onFrame, onError: (_, __) => mounted ? setState(() => _failed = true) : null);

  ImageProvider get _provider => ResizeImage.resizeIfNeeded(widget.cacheWidth, null, AssetImage(widget.path));

  void _onFrame(ImageInfo info, bool _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  void _resolve() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stopListening();
    _stream = stream;
  }

  void _updateListening() {
    final active = TickerMode.of(context);
    if (active && !_listening) {
      _stream?.addListener(_listener);
      _listening = true;
    } else if (!active) {
      _stopListening();
    }
  }

  void _stopListening() {
    if (_listening) _stream?.removeListener(_listener);
    _listening = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
    _updateListening();
  }

  @override
  void didUpdateWidget(FilteredAssetImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.cacheWidth != widget.cacheWidth) {
      _failed = false;
      _resolve();
      _updateListening();
    }
  }

  @override
  void dispose() {
    _stopListening();
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback();
    final img = _info?.image;
    if (img == null) return const SizedBox.expand();
    return CustomPaint(size: Size.infinite, painter: _FilteredImagePainter(img, widget.colorFilter));
  }
}

class _FilteredImagePainter extends CustomPainter {
  _FilteredImagePainter(this.image, this.filter);
  final ui.Image image;
  final ColorFilter filter;

  @override
  void paint(Canvas canvas, Size size) => paintImage(
    canvas: canvas,
    rect: Offset.zero & size,
    image: image,
    fit: BoxFit.contain,
    colorFilter: filter,
    filterQuality: FilterQuality.medium,
  );

  @override
  bool shouldRepaint(_FilteredImagePainter old) => old.image != image || old.filter != filter;
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
