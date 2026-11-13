import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signals of the workout timers – hold and rest countdowns, km splits and step changes.
///
/// On Android they go through the app channel (MainActivity "alert"): the vibration is a real
/// vibrator pattern with alarm usage – not a haptic "click" (HapticFeedback), which Android
/// silences when "touch vibration" is off and which is barely noticeable with the phone on the
/// floor during a plank – and the beep is a tone on the media stream (heard in headphones, mixes
/// with music). Elsewhere (iOS, tests) they fall back to the haptic feedback.
enum AlertSignal {
  /// One second of a countdown ("3, 2, 1"): short pip, short buzz.
  tick,

  /// The hold starts after the lead-in: higher pip, one buzz.
  go,

  /// A timer reached its end (hold time reached, rest over): long beep, three strong pulses.
  end,

  /// Km split / step change of a recording: vibration only (the voice coach speaks).
  pulse,
}

class WorkoutAlerts {
  const WorkoutAlerts();

  static const _channel = MethodChannel('com.gromhork.strive/app');

  /// Vibration pattern (off / on ms, alternating, starting with a pause) of [s].
  static List<int> patternOf(AlertSignal s) => switch (s) {
    AlertSignal.tick => const [0, 60],
    AlertSignal.go => const [0, 180],
    AlertSignal.end => const [0, 450, 200, 450, 200, 450],
    AlertSignal.pulse => const [0, 250, 150, 250],
  };

  /// Plays [signal]: the beep when [sound], the vibration when [vibrate].
  Future<void> play(AlertSignal signal, {required bool sound, required bool vibrate}) async {
    final tone = sound && signal != AlertSignal.pulse ? signal.name : null;
    if (tone == null && !vibrate) return;
    try {
      await _channel.invokeMethod<void>('alert', {'tone': tone, 'vibrate': vibrate ? patternOf(signal) : null});
    } on MissingPluginException {
      if (vibrate) await _haptic(signal);
    } catch (e) {
      debugPrint('alert failed: $e');
      if (vibrate) await _haptic(signal);
    }
  }

  Future<void> _haptic(AlertSignal s) async {
    try {
      switch (s) {
        case AlertSignal.tick:
          await HapticFeedback.selectionClick();
        case AlertSignal.go:
          await HapticFeedback.heavyImpact();
        case AlertSignal.end || AlertSignal.pulse:
          for (var i = 0; i < (s == AlertSignal.end ? 3 : 2); i++) {
            await HapticFeedback.vibrate();
            await Future.delayed(const Duration(milliseconds: 300));
          }
      }
    } catch (_) {}
  }
}

/// Overridable in tests (records the signals instead of calling the platform).
final workoutAlertsProvider = Provider<WorkoutAlerts>((ref) => const WorkoutAlerts());
