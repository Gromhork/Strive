import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Spoken cues during runs/rides (km splits, step changes, pace guidance).
/// Music is ducked while speaking (Android audio focus "may duck").
class VoiceCoach {
  VoiceCoach(this.lang);
  final String lang;
  final _tts = FlutterTts();
  bool enabled = true;
  bool _ready = false;
  DateTime _lastPaceCue = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage(lang == 'de' ? 'de-DE' : 'en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setQueueMode(1); // add to queue
      }
    } catch (e) {
      debugPrint('tts init failed: $e');
    }
    _ready = true;
  }

  Future<void> say(String text) async {
    if (!enabled || text.isEmpty) return;
    await _init();
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('tts failed: $e');
    }
  }

  /// Pace guidance is throttled to at most one cue per [every].
  Future<void> paceCue(String text, {Duration every = const Duration(seconds: 60)}) async {
    final now = DateTime.now();
    if (now.difference(_lastPaceCue) < every) return;
    _lastPaceCue = now;
    await say(text);
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// "5:30" → "5 Minuten 30" / "5 minutes 30" for speech.
String spokenDuration(int sec, String lang) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  if (lang == 'de') {
    return [if (h > 0) '$h Stunde${h > 1 ? 'n' : ''}', if (m > 0) '$m Minute${m == 1 ? '' : 'n'}', if (s > 0 && h == 0) '$s Sekunden'].join(' ');
  }
  return [if (h > 0) '$h hour${h > 1 ? 's' : ''}', if (m > 0) '$m minute${m == 1 ? '' : 's'}', if (s > 0 && h == 0) '$s seconds'].join(' ');
}

String spokenPace(int secPerKm, String lang) {
  final m = secPerKm ~/ 60, s = secPerKm % 60;
  return lang == 'de' ? '$m:${s.toString().padLeft(2, '0')} pro Kilometer' : '$m:${s.toString().padLeft(2, '0')} per kilometer';
}
