import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        hasMedia(exId) && animated
            ? SlowAnimatedAsset(path: path, colorFilter: dark ? darkMediaFilter : null, fallback: fallback)
            : hasMedia(exId)
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

/// Plays an animated image asset (the exercise demos are 12-frame animated WebPs) at
/// [speed] × its encoded frame rate. The source animations run at a hurried pace; at
/// ~0.55× each repetition is easy to follow.
///
/// Frames are decoded one at a time from a single codec (like [Image] does), so memory
/// stays at one frame; playback pauses while the widget is in a disabled [TickerMode]
/// (e.g. an off-screen route or page).
class SlowAnimatedAsset extends StatefulWidget {
  const SlowAnimatedAsset({super.key, required this.path, this.speed = defaultSpeed, this.colorFilter, required this.fallback});

  /// Playback speed of the exercise demos.
  static const defaultSpeed = 0.55;

  final String path;
  final double speed;
  final ColorFilter? colorFilter;
  final Widget Function() fallback;

  @override
  State<SlowAnimatedAsset> createState() => _SlowAnimatedAssetState();
}

class _SlowAnimatedAssetState extends State<SlowAnimatedAsset> {
  /// Recently used animation files (~70 kB each), so the same exercise shown again
  /// (hero flight, overview → focus view) starts without re-reading the asset.
  static final _cache = <String, Uint8List>{};

  static Future<Uint8List> _bytes(String path) async {
    final hit = _cache.remove(path);
    if (hit != null) return _cache[path] = hit;
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    _cache[path] = bytes;
    if (_cache.length > 12) _cache.remove(_cache.keys.first);
    return bytes;
  }

  ui.Codec? _codec;
  ui.Image? _frame;
  Timer? _timer;
  bool _failed = false;
  bool _active = true;
  bool _decoding = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SlowAnimatedAsset old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _reset();
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (active == _active) return;
    _active = active;
    if (active) {
      _scheduleNext(Duration.zero);
    } else {
      _timer?.cancel();
    }
  }

  void _reset() {
    _generation++;
    _timer?.cancel();
    _codec?.dispose();
    _codec = null;
    _frame?.dispose();
    _frame = null;
    _failed = false;
  }

  Future<void> _load() async {
    final gen = _generation;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(await _bytes(widget.path));
      final codec = await ui.instantiateImageCodecFromBuffer(buffer);
      if (!mounted || gen != _generation) {
        codec.dispose();
        return;
      }
      _codec = codec;
      await _nextFrame(gen);
    } catch (_) {
      if (mounted && gen == _generation) setState(() => _failed = true);
    }
  }

  void _scheduleNext(Duration after) {
    _timer?.cancel();
    if (_codec == null || !_active) return;
    final gen = _generation;
    _timer = Timer(after, () => _nextFrame(gen));
  }

  Future<void> _nextFrame(int gen) async {
    final codec = _codec;
    if (codec == null || _decoding) return;
    _decoding = true;
    try {
      final info = await codec.getNextFrame();
      if (!mounted || gen != _generation) {
        info.image.dispose();
        return;
      }
      final old = _frame;
      setState(() => _frame = info.image);
      old?.dispose();
      if (codec.frameCount > 1) {
        final d = info.duration == Duration.zero ? const Duration(milliseconds: 100) : info.duration;
        _scheduleNext(d * (1 / widget.speed));
      }
    } catch (_) {
      if (mounted && gen == _generation && _frame == null) setState(() => _failed = true);
    } finally {
      _decoding = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _codec?.dispose();
    _frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback();
    final frame = _frame;
    if (frame == null) return const SizedBox.expand();
    final img = RawImage(image: frame, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    return widget.colorFilter == null ? img : ColorFiltered(colorFilter: widget.colorFilter!, child: img);
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
