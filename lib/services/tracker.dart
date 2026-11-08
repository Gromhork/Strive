import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../features/session/step_text.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers.dart';
import 'voice_coach.dart';

/// Live state of a run / ride / swim being recorded.
class CardioState {
  final Sport sport;
  final String title;
  final String? planId;
  final DateTime start;
  final int accumulatedSec; // time before the current running segment
  final DateTime? runningSince; // null = paused
  final double distanceM;
  final double elevationM;
  final List<LatLng> points;
  final List<int> splits; // seconds per km
  final bool indoor; // treadmill / trainer / pool (no GPS)
  final int laps;
  final int poolLengthM;
  final double? accuracy;
  final String? gpsError;
  // Structured workout
  final List<WorkoutStep> steps;
  final int stepIndex;
  final int stepStartSec;
  final double stepStartDist;
  final bool stepsDone;
  // Live pace (sec/km) over the last ~20–30 s, null when not moving.
  final int? currentPace;
  final List<int> paceHistory; // one value per ~5 s (for the mini chart)
  final bool autoPaused;
  final bool voice;

  const CardioState({
    required this.sport,
    required this.title,
    this.planId,
    required this.start,
    this.accumulatedSec = 0,
    this.runningSince,
    this.distanceM = 0,
    this.elevationM = 0,
    this.points = const [],
    this.splits = const [],
    this.indoor = false,
    this.laps = 0,
    this.poolLengthM = 25,
    this.accuracy,
    this.gpsError,
    this.steps = const [],
    this.stepIndex = 0,
    this.stepStartSec = 0,
    this.stepStartDist = 0,
    this.stepsDone = false,
    this.currentPace,
    this.paceHistory = const [],
    this.autoPaused = false,
    this.voice = true,
  });

  bool get paused => runningSince == null;
  int get elapsed => accumulatedSec + (runningSince == null ? 0 : DateTime.now().difference(runningSince!).inSeconds);
  double get effectiveDistance => sport == Sport.swim && indoor ? laps * poolLengthM.toDouble() : distanceM;

  bool get structured => steps.isNotEmpty;
  WorkoutStep? get step => structured && !stepsDone && stepIndex < steps.length ? steps[stepIndex] : null;
  WorkoutStep? get nextStep => structured && stepIndex + 1 < steps.length ? steps[stepIndex + 1] : null;
  int get stepElapsed => elapsed - stepStartSec;
  double get stepDistance => effectiveDistance - stepStartDist;

  /// 0..1 progress of the current step.
  double get stepProgress {
    final s = step;
    if (s == null) return 1;
    if (s.distanceM != null && s.distanceM! > 0) return (stepDistance / s.distanceM!).clamp(0, 1);
    if (s.durationSec != null && s.durationSec! > 0) return (stepElapsed / s.durationSec!).clamp(0, 1);
    return 0;
  }

  /// Remaining amount: meters (distance steps) or seconds (time steps).
  (double? meters, int? seconds) get stepRemaining {
    final s = step;
    if (s == null) return (null, null);
    if (s.distanceM != null) return (max(0, s.distanceM! - stepDistance), null);
    if (s.durationSec != null) return (null, max(0, s.durationSec! - stepElapsed));
    return (null, null);
  }

  /// -1 too fast, 0 on target, 1 too slow, null = no target / no pace.
  int? get paceStatus {
    final s = step;
    final p = currentPace;
    if (s == null || p == null || s.paceMin == null || s.paceMax == null) return null;
    if (p < s.paceMin! - 5) return -1;
    if (p > s.paceMax! + 5) return 1;
    return 0;
  }

  CardioState copyWith({
    int? accumulatedSec,
    DateTime? runningSince,
    bool pause = false,
    double? distanceM,
    double? elevationM,
    List<LatLng>? points,
    List<int>? splits,
    int? laps,
    int? poolLengthM,
    double? accuracy,
    String? gpsError,
    bool clearError = false,
    int? stepIndex,
    int? stepStartSec,
    double? stepStartDist,
    bool? stepsDone,
    int? currentPace,
    bool clearPace = false,
    List<int>? paceHistory,
    bool? autoPaused,
    bool? voice,
  }) => CardioState(
    sport: sport,
    title: title,
    planId: planId,
    start: start,
    accumulatedSec: accumulatedSec ?? this.accumulatedSec,
    runningSince: pause ? null : (runningSince ?? this.runningSince),
    distanceM: distanceM ?? this.distanceM,
    elevationM: elevationM ?? this.elevationM,
    points: points ?? this.points,
    splits: splits ?? this.splits,
    indoor: indoor,
    laps: laps ?? this.laps,
    poolLengthM: poolLengthM ?? this.poolLengthM,
    accuracy: accuracy ?? this.accuracy,
    gpsError: clearError ? null : (gpsError ?? this.gpsError),
    steps: steps,
    stepIndex: stepIndex ?? this.stepIndex,
    stepStartSec: stepStartSec ?? this.stepStartSec,
    stepStartDist: stepStartDist ?? this.stepStartDist,
    stepsDone: stepsDone ?? this.stepsDone,
    currentPace: clearPace ? null : (currentPace ?? this.currentPace),
    paceHistory: paceHistory ?? this.paceHistory,
    autoPaused: autoPaused ?? this.autoPaused,
    voice: voice ?? this.voice,
  );
}

class TrackerNotifier extends Notifier<CardioState?> {
  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  Position? _last;
  double? _lastAlt;
  int _splitStartSec = 0;
  final _samples = <(int, double)>[]; // (elapsed sec, distance m)
  int _stillSince = -1;
  VoiceCoach? _voice;
  AppLocalizations? _l;
  Units _u = const Units(false);
  String _lang = 'de';

  @override
  CardioState? build() {
    ref.onDispose(_stopAll);
    return null;
  }

  Future<String?> start({
    required Sport sport,
    required String title,
    String? planId,
    bool indoor = false,
    int poolLengthM = 25,
    List<WorkoutStep> steps = const [],
    AppLocalizations? l,
    String lang = 'de',
  }) async {
    if (!indoor) {
      final err = await _ensurePermission();
      if (err != null) return err;
    }
    _last = null;
    _lastAlt = null;
    _splitStartSec = 0;
    _samples.clear();
    _stillSince = -1;
    _l = l;
    _lang = lang;
    _u = ref.read(profileOrDefaultProvider).units;
    final voiceOn = ref.read(prefsProvider).getBool('voiceCues') ?? true;
    _voice = VoiceCoach(lang)..enabled = voiceOn && sport != Sport.swim;
    state = CardioState(
      sport: sport,
      title: title,
      planId: planId,
      start: DateTime.now(),
      runningSince: DateTime.now(),
      indoor: indoor,
      poolLengthM: poolLengthM,
      steps: sport == Sport.swim ? const [] : steps,
      voice: voiceOn,
    );
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (!indoor) _listen(title);
    if (l != null) {
      final s = state!;
      _voice?.say(s.structured ? '${l.vcGo} ${stepSpeech(l, s.steps, 0, _u, sport, lang)}' : l.vcGo);
    }
    return null;
  }

  Future<String?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return 'service';
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return 'permission';
    return null;
  }

  void _listen(String title) {
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 3,
              intervalDuration: const Duration(seconds: 1),
              foregroundNotificationConfig: ForegroundNotificationConfig(
                notificationTitle: 'Strive',
                notificationText: title,
                enableWakeLock: true,
              ),
            )
            : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (e) {
        state = state?.copyWith(gpsError: e.toString());
      },
    );
  }

  /// Once per second: step timing, live pace, auto-pause, pace cues.
  void _tick() {
    var s = state;
    if (s == null) return;
    if (!s.paused || s.autoPaused) {
      // Live pace from the samples of the last 25 s.
      final now = s.elapsed;
      _samples.removeWhere((e) => now - e.$1 > 25);
      int? pace;
      if (_samples.length >= 2) {
        final d = _samples.last.$2 - _samples.first.$2;
        final t = _samples.last.$1 - _samples.first.$1;
        if (d > 8 && t > 0) pace = (t / d * 1000).round();
      }
      var hist = s.paceHistory;
      if (now % 5 == 0 && pace != null) hist = [...hist.length > 120 ? hist.sublist(hist.length - 120) : hist, pace];
      s = s.copyWith(currentPace: pace, clearPace: pace == null, paceHistory: hist);
      state = s;
      _autoPause(s);
    } else {
      state = s.copyWith();
    }
    _checkStep();
    _paceCue();
  }

  void _autoPause(CardioState s) {
    if (s.indoor || s.sport == Sport.swim || !(ref.read(prefsProvider).getBool('autoPause') ?? true)) return;
    final moving = s.currentPace != null && s.currentPace! < (s.sport == Sport.ride ? 600 : 1200);
    if (!s.paused && !moving && s.elapsed > 30) {
      if (_stillSince < 0) _stillSince = s.elapsed;
      if (s.elapsed - _stillSince >= 10) {
        state = s.copyWith(accumulatedSec: s.elapsed, pause: true, autoPaused: true);
        if (_l != null) _voice?.say(_l!.vcAutoPaused);
      }
    } else if (moving) {
      _stillSince = -1;
    }
  }

  void _checkStep() {
    final s = state;
    final st = s?.step;
    if (s == null || st == null || s.paused) return;
    final done =
        (st.distanceM != null && s.stepDistance >= st.distanceM!) ||
        (st.distanceM == null && st.durationSec != null && s.stepElapsed >= st.durationSec!);
    // Countdown beeps for the last 3 seconds of timed steps.
    if (st.distanceM == null && st.durationSec != null) {
      final left = st.durationSec! - s.stepElapsed;
      if (left > 0 && left <= 3) HapticFeedback.selectionClick();
    }
    if (done) _advance();
  }

  void _advance() {
    final s = state;
    if (s == null) return;
    final next = s.stepIndex + 1;
    if (ref.read(settingsProvider).vibrate) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), HapticFeedback.heavyImpact);
    }
    if (next >= s.steps.length) {
      state = s.copyWith(stepsDone: true);
      if (_l != null) _voice?.say(_l!.vcAllDone);
      return;
    }
    state = s.copyWith(stepIndex: next, stepStartSec: s.elapsed, stepStartDist: s.effectiveDistance);
    if (_l != null) _voice?.say(stepSpeech(_l!, s.steps, next, _u, s.sport, _lang));
  }

  /// Manually skip to the next step.
  void skipStep() {
    if (state?.step != null) _advance();
  }

  void _paceCue() {
    final s = state;
    if (s == null || s.paused || _l == null) return;
    final st = s.paceStatus;
    if (st == null || st == 0 || s.stepElapsed < 20) return;
    _voice?.paceCue(st < 0 ? _l!.vcSlowDown : _l!.vcSpeedUp);
  }

  void _onPosition(Position p) {
    final s = state;
    if (s == null) return;
    if (s.paused && !s.autoPaused) {
      _last = p;
      return;
    }
    if (p.accuracy > 35) {
      state = s.copyWith(accuracy: p.accuracy);
      return;
    }
    var d = 0.0;
    if (_last != null) {
      d = Geolocator.distanceBetween(_last!.latitude, _last!.longitude, p.latitude, p.longitude);
      final dt = p.timestamp.difference(_last!.timestamp).inMilliseconds / 1000;
      if (dt > 0 && d / dt >= 50) d = 0; // GPS jump
    }
    // Auto-resume when moving again.
    if (s.autoPaused) {
      _last = p;
      if (d > 4) {
        _stillSince = -1;
        state = s.copyWith(runningSince: DateTime.now(), autoPaused: false);
        if (_l != null) _voice?.say(_l!.vcResumed);
      }
      return;
    }
    final dist = s.distanceM + d;
    var elev = s.elevationM;
    if (_lastAlt != null && p.altitude - _lastAlt! > 1) elev += p.altitude - _lastAlt!;
    if (_lastAlt == null || (p.altitude - _lastAlt!).abs() > 1) _lastAlt = p.altitude;
    _last = p;
    _samples.add((s.elapsed, dist));

    var splits = s.splits;
    if ((dist / 1000).floor() > splits.length) {
      final now = s.elapsed;
      final split = now - _splitStartSec;
      splits = [...splits, split];
      _splitStartSec = now;
      if (ref.read(settingsProvider).vibrate) HapticFeedback.heavyImpact();
      if (_l != null && !(s.step?.isWork ?? false)) {
        _voice?.say(_l!.vcKm(splits.length, spokenDuration(now, _lang), spokenPace(split, _lang)));
      }
    }
    state = s.copyWith(
      distanceM: dist,
      elevationM: elev,
      points: [...s.points, LatLng(p.latitude, p.longitude)],
      splits: splits,
      accuracy: p.accuracy,
      clearError: true,
    );
    _checkStep();
  }

  void pause() {
    final s = state;
    if (s == null || s.paused) return;
    state = s.copyWith(accumulatedSec: s.elapsed, pause: true, autoPaused: false);
  }

  void resume() {
    final s = state;
    if (s == null || (!s.paused && !s.autoPaused)) return;
    _last = null;
    _stillSince = -1;
    state = s.copyWith(runningSince: DateTime.now(), autoPaused: false);
  }

  void toggleVoice() {
    final s = state;
    if (s == null) return;
    final v = !s.voice;
    ref.read(prefsProvider).setBool('voiceCues', v);
    _voice?.enabled = v;
    if (!v) _voice?.stop();
    state = s.copyWith(voice: v);
  }

  void lap() {
    final s = state;
    if (s == null) return;
    HapticFeedback.mediumImpact();
    state = s.copyWith(laps: s.laps + 1);
    // Pool: a lap also advances distance-based steps.
    _checkStep();
  }

  void undoLap() {
    final s = state;
    if (s == null || s.laps == 0) return;
    state = s.copyWith(laps: s.laps - 1);
  }

  void setPoolLength(int m) => state = state?.copyWith(poolLengthM: m);

  /// Stops recording and returns a session draft (not yet saved).
  Session finish(String id, {double? manualDistanceM}) {
    final s = state!;
    final pts = s.points;
    // Downsample route to ≤ 500 points to keep documents small.
    final step = (pts.length / 500).ceil().clamp(1, 1 << 30);
    final route = [
      for (var i = 0; i < pts.length; i += step) [pts[i].latitude, pts[i].longitude],
    ];
    final session = Session(
      id: id,
      sport: s.sport,
      title: s.title,
      start: s.start,
      durationSec: s.elapsed,
      distanceM: manualDistanceM ?? s.effectiveDistance,
      elevationM: s.elevationM,
      route: route,
      splits: s.splits,
      laps: s.laps,
      poolLengthM: s.poolLengthM,
      indoor: s.indoor,
      planId: s.planId,
    );
    discard();
    return session;
  }

  void discard() {
    _stopAll();
    state = null;
  }

  void _stopAll() {
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    _voice?.stop();
    WakelockPlus.disable();
  }
}

final trackerProvider = NotifierProvider<TrackerNotifier, CardioState?>(TrackerNotifier.new);
