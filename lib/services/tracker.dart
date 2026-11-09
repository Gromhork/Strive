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
import '../core/theme.dart';
import '../data/models.dart';
import '../features/session/step_text.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers.dart';
import 'notification_service.dart' show notificationIcon;
import 'step_progress.dart';
import 'voice_coach.dart';

/// Step state before a pool length was counted – lets "undo" revert an auto-advance.
class StepMark {
  const StepMark(this.stepIndex, this.stepStartSec, this.stepStartDist, this.stepsDone, this.lastLengthAt);
  final int stepIndex;
  final int stepStartSec;
  final double stepStartDist;
  final bool stepsDone;
  final int lastLengthAt;
}

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
  // Live pace (sec/km) over the last ~10–25 s, null when not moving.
  final int? currentPace;
  final List<int> paceHistory; // one value per ~5 s (for the mini chart)
  final bool autoPaused;
  final bool voice;
  // Pool swimming: seconds per length, elapsed time of the last wall touch (or the
  // end of the last rest), and the step state before each length (for undo).
  final List<int> lengthSecs;
  final int lastLengthAt;
  final List<StepMark> lengthMarks;
  final int? bestPace; // fastest live pace (sec/km) – shown as max speed on rides

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
    this.lengthSecs = const [],
    this.lastLengthAt = 0,
    this.lengthMarks = const [],
    this.bestPace,
  });

  bool get paused => runningSince == null;
  int get elapsed => accumulatedSec + (runningSince == null ? 0 : DateTime.now().difference(runningSince!).inSeconds);

  bool get poolMode => sport == Sport.swim && indoor;

  /// "33 m" pools are 33⅓ m (3 lengths = 100 m).
  double get poolLen => poolLengthM == 33 ? 100 / 3 : poolLengthM.toDouble();
  double get effectiveDistance => poolMode ? laps * poolLen : distanceM;

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

  /// Whether the current step's target (distance or time) has been reached.
  /// In the pool a distance step is done at the wall closest to the target.
  bool get stepComplete {
    final s = step;
    if (s == null) return false;
    if (s.distanceM != null) return poolMode ? stepDistance + poolLen / 2 > s.distanceM! : stepDistance >= s.distanceM!;
    return s.durationSec != null && stepElapsed >= s.durationSec!;
  }

  /// Pool lengths still to swim in the current distance step.
  int? get lengthsLeft {
    final s = step;
    if (!poolMode || s?.distanceM == null) return null;
    return max(0, ((s!.distanceM! - stepDistance) / poolLen).round());
  }

  /// Lengths swum since the current step started.
  int get stepLengths => poolMode ? (stepDistance / poolLen).round() : 0;

  int? _pace100(int n) {
    if (n <= 0 || lengthSecs.length < n) return null;
    final t = lengthSecs.sublist(lengthSecs.length - n).fold<int>(0, (a, b) => a + b);
    return (t / (n * poolLen) * 100).round();
  }

  /// Rolling swim pace (sec/100 m) over the last ≤ 4 lengths, null before the first length.
  int? get swimPace100 => _pace100(min(4, lengthSecs.length));

  /// Average swim pace (sec/100 m) over swimming time only (timed rests excluded).
  int? get avgSwimPace100 => _pace100(lengthSecs.length);

  /// Live pace in the unit of the step targets: sec/km (run) or sec/100 m (swim).
  int? get targetPace {
    if (poolMode) return _pace100(min(4, stepLengths));
    if (currentPace == null) return null;
    return sport == Sport.swim ? (currentPace! / 10).round() : currentPace;
  }

  /// Estimated seconds left in the whole structured workout.
  int get workoutLeftSec =>
      structured && !stepsDone ? workoutRemainingSec(steps, stepIndex, sport, stepElapsed: stepElapsed, stepDistance: stepDistance) : 0;

  /// Moves to the next step (or marks the workout as done).
  CardioState advanceStep() {
    final s = step;
    if (s == null) return this;
    final next = stepIndex + 1;
    // Leaving a timed step in the pool (rest): the next length starts now, not at the last wall touch.
    final restEnded = poolMode && s.distanceM == null;
    if (next >= steps.length) return copyWith(stepsDone: true, lastLengthAt: restEnded ? elapsed : null);
    return copyWith(stepIndex: next, stepStartSec: elapsed, stepStartDist: effectiveDistance, lastLengthAt: restEnded ? elapsed : null);
  }

  /// Pool: one length swum. Ends a running rest early, adds the length and
  /// auto-advances a distance step once its distance is reached.
  CardioState addLength() {
    final mark = StepMark(stepIndex, stepStartSec, stepStartDist, stepsDone, lastLengthAt);
    var s = this;
    // Touching the wall during a rest means the swimmer left early: end the rest, but
    // time this length from the previous wall touch.
    if (s.step?.kind == 'recovery' && s.step?.distanceM == null) s = s.advanceStep().copyWith(lastLengthAt: lastLengthAt);
    final now = s.elapsed;
    s = s.copyWith(
      laps: s.laps + 1,
      lengthSecs: [...s.lengthSecs, max(1, now - s.lastLengthAt)],
      lastLengthAt: now,
      lengthMarks: [...s.lengthMarks, mark],
    );
    if (s.step?.distanceM != null && s.stepComplete) s = s.advanceStep();
    return s;
  }

  /// Pool: removes the last length and restores the step state from before it.
  CardioState undoLength() {
    if (laps == 0) return this;
    final m = lengthMarks.isNotEmpty ? lengthMarks.last : null;
    return copyWith(
      laps: laps - 1,
      lengthSecs: lengthSecs.isEmpty ? null : lengthSecs.sublist(0, lengthSecs.length - 1),
      lengthMarks: lengthMarks.isEmpty ? null : lengthMarks.sublist(0, lengthMarks.length - 1),
      stepIndex: m?.stepIndex,
      stepStartSec: m?.stepStartSec,
      stepStartDist: m?.stepStartDist,
      stepsDone: m?.stepsDone,
      lastLengthAt: m?.lastLengthAt,
    );
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
    final p = targetPace;
    if (s == null || p == null || s.paceMin == null || s.paceMax == null) return null;
    final tol = sport == Sport.swim ? 3 : 5;
    if (p < s.paceMin! - tol) return -1;
    if (p > s.paceMax! + tol) return 1;
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
    List<int>? lengthSecs,
    int? lastLengthAt,
    List<StepMark>? lengthMarks,
    int? bestPace,
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
    lengthSecs: lengthSecs ?? this.lengthSecs,
    lastLengthAt: lastLengthAt ?? this.lastLengthAt,
    lengthMarks: lengthMarks ?? this.lengthMarks,
    bestPace: bestPace ?? this.bestPace,
  );
}

/// Voice preference key per sport: swims default to silent (phone lies at the pool edge).
String voicePrefKey(Sport sport) => sport == Sport.swim ? 'voiceCuesSwim' : 'voiceCues';
bool voiceDefault(Sport sport) => sport != Sport.swim;

/// Auto-pause: (moving if live pace below this many sec/km, seconds standing still before pausing).
/// Rides: < 5 km/h for 6 s (short window, bikes stop and start quickly). Runs: < 3 km/h for 10 s.
(int, int) autoPauseRule(Sport sport) => sport == Sport.ride ? (720, 6) : (1200, 10);

/// Rides announce every 5 km (every km would be every ~2 min); runs/swims every km.
int splitAnnounceEvery(Sport sport) => sport == Sport.ride ? 5 : 1;

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
    final voiceOn = ref.read(prefsProvider).getBool(voicePrefKey(sport)) ?? voiceDefault(sport);
    _voice = VoiceCoach(lang)..enabled = voiceOn;
    state = CardioState(
      sport: sport,
      title: title,
      planId: planId,
      start: DateTime.now(),
      runningSince: DateTime.now(),
      indoor: indoor,
      poolLengthM: poolLengthM,
      steps: steps,
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
                notificationIcon: const AndroidResource(name: notificationIcon),
                color: AppColors.brand,
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
      // Live pace from the recent samples (rides: 10 s, runs/swims: 25 s).
      final now = s.elapsed;
      final window = s.sport == Sport.ride ? 10 : 25;
      _samples.removeWhere((e) => now - e.$1 > window);
      int? pace;
      if (_samples.length >= 2) {
        final d = _samples.last.$2 - _samples.first.$2;
        final t = _samples.last.$1 - _samples.first.$1;
        if (d > 8 && t > 0) pace = (t / d * 1000).round();
      }
      var hist = s.paceHistory;
      if (now % 5 == 0 && pace != null) hist = [...hist.length > 120 ? hist.sublist(hist.length - 120) : hist, pace];
      // Max speed (rides): ignore implausible spikes (> 100 km/h).
      final best = pace != null && !s.paused && pace >= 36 && (s.bestPace == null || pace < s.bestPace!) ? pace : null;
      s = s.copyWith(currentPace: pace, clearPace: pace == null, paceHistory: hist, bestPace: best);
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
    final (movingPace, stillSec) = autoPauseRule(s.sport);
    final moving = s.currentPace != null && s.currentPace! < movingPace;
    if (!s.paused && !moving && s.elapsed > 30) {
      if (_stillSince < 0) _stillSince = s.elapsed;
      if (s.elapsed - _stillSince >= stillSec) {
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
    // Countdown haptics for the last 3 seconds of timed steps.
    if (st.distanceM == null && st.durationSec != null) {
      final left = st.durationSec! - s.stepElapsed;
      if (left > 0 && left <= 3) HapticFeedback.selectionClick();
    }
    if (s.stepComplete) _advance();
  }

  void _advance() {
    final s = state;
    if (s == null) return;
    final next = s.advanceStep();
    state = next;
    _announceStep(s, next);
  }

  /// Haptics + voice when the step changed between [before] and [after].
  void _announceStep(CardioState before, CardioState after) {
    if (after.stepIndex == before.stepIndex && after.stepsDone == before.stepsDone) return;
    if (ref.read(settingsProvider).vibrate) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), HapticFeedback.heavyImpact);
    }
    final l = _l;
    if (l == null) return;
    if (after.stepsDone) {
      _voice?.say(switch (after.sport) {
        Sport.ride => l.vcAllDoneRide,
        Sport.swim => l.vcAllDoneSwim,
        _ => l.vcAllDone,
      });
    } else {
      _voice?.say(stepSpeech(l, after.steps, after.stepIndex, _u, after.sport, _lang));
    }
  }

  /// Manually skip to the next step.
  void skipStep() {
    if (state?.step != null) _advance();
  }

  void _paceCue() {
    final s = state;
    if (s == null || s.paused || _l == null || s.sport == Sport.swim) return;
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
        final speech = splitSpeech(_l!, s.sport, splits, now, _lang);
        if (speech != null) _voice?.say(speech);
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
    ref.read(prefsProvider).setBool(voicePrefKey(s.sport), v);
    _voice?.enabled = v;
    if (!v) _voice?.stop();
    state = s.copyWith(voice: v);
  }

  /// Lap button. In the pool this is one length (adds distance, advances steps).
  void lap() {
    final s = state;
    if (s == null) return;
    if (s.poolMode) {
      // No pool length takes under 5 s (25 m world record ≈ 10 s): a second tap that
      // fast is an accidental double tap and would ruin pace and step progress.
      if (s.elapsed - s.lastLengthAt < 5) return;
      HapticFeedback.mediumImpact();
      final next = s.addLength();
      state = next;
      _announceStep(s, next);
      return;
    }
    HapticFeedback.mediumImpact();
    state = s.copyWith(laps: s.laps + 1);
    _checkStep();
  }

  void undoLap() {
    final s = state;
    if (s == null || s.laps == 0) return;
    HapticFeedback.selectionClick();
    state = s.poolMode ? s.undoLength() : s.copyWith(laps: s.laps - 1);
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

/// Spoken split announcement, or null when this split is not announced.
/// * Run: "Kilometer 3. Time 15 minutes 30 seconds. Last kilometer 5:10 per kilometer."
/// * Ride (every 5 km): "Kilometer 10. Time 21 minutes. Last 5 kilometers at 28.6 kilometers per hour."
/// * Open-water swim: "Kilometer 1. Time 22 minutes. Pace 2:12 per 100 meters."
String? splitSpeech(AppLocalizations l, Sport sport, List<int> splits, int elapsed, String lang) {
  final n = splits.length;
  if (n == 0) return null;
  final time = spokenDuration(elapsed, lang);
  switch (sport) {
    case Sport.ride:
      final every = splitAnnounceEvery(sport);
      if (n % every != 0) return null;
      final sec = splits.sublist(n - every).fold<int>(0, (a, b) => a + b);
      if (sec <= 0) return null;
      final kmh = every * 3600 / sec;
      return l.vcSplitRide(n, time, every, l.vcKmh(spokenNum(kmh, lang)));
    case Sport.swim:
      return l.vcSplitSwim(n, time, l.vcPer100m(spokenClock((splits.last / 10).round())));
    default:
      return l.vcKm(n, time, spokenPace(splits.last, lang));
  }
}

final trackerProvider = NotifierProvider<TrackerNotifier, CardioState?>(TrackerNotifier.new);
