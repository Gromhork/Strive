import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../core/sport.dart';
import '../data/models.dart';
import 'active_workout.dart';
import 'tracker.dart';

// Crash-safe storage of the workout in progress.
//
// Active workouts live in memory (Riverpod notifiers). Android may kill the process at any
// time (OOM, vendor app killers, swipe from recents, crash), so the workout is mirrored to
// local files: the state as JSON (rewritten, small) and the GPS route as an append-only
// text file (one "lat,lng" line per point – never rewritten while recording). The summary
// draft (finished but not yet saved) is stored the same way. On the next start the shell
// offers to continue (see WorkoutRestoreGate).

const _version = 1;

// ───────────────────────────── Serialization ─────────────────────────────

Map<String, dynamic> activeGymToJson(ActiveGym g) => {
  'title': g.title,
  'templateId': g.templateId,
  'planId': g.planId,
  'programSets': g.programSets,
  'start': g.start.millisecondsSinceEpoch,
  'exercises': [for (final e in g.exercises) e.toMap()],
  'restEnd': g.restEnd?.millisecondsSinceEpoch,
  'restTotal': g.restTotal,
  'restTransition': g.restIsTransition,
  'focus': g.focus,
  // The effort prompt refers to one of the exercises: stored by index.
  'effortFor': g.effortFor == null ? null : g.exercises.indexOf(g.effortFor!),
};

ActiveGym activeGymFromJson(Map m) {
  final exercises = [for (final e in (m['exercises'] as List? ?? const [])) GymExercise.fromMap(e as Map)];
  final effortIdx = m['effortFor'] as int?;
  return ActiveGym(
    title: m['title'] as String? ?? '',
    templateId: m['templateId'] as String?,
    planId: m['planId'] as String?,
    start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
    exercises: exercises,
    programSets: (m['programSets'] as num?)?.toInt(),
    restEnd: _time(m['restEnd']),
    restTotal: m['restTotal'] as int? ?? 0,
    restIsTransition: m['restTransition'] == true,
    focus: (m['focus'] as int? ?? 0).clamp(0, exercises.isEmpty ? 0 : exercises.length - 1),
    effortFor: effortIdx != null && effortIdx >= 0 && effortIdx < exercises.length ? exercises[effortIdx] : null,
  );
}

DateTime? _time(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
List<int> _ints(Object? v) => [for (final x in (v as List? ?? const [])) (x as num).toInt()];
List<double> _doubles(Object? v) => [for (final x in (v as List? ?? const [])) (x as num).toDouble()];
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Cardio state without the route (the route is stored separately, append-only).
/// Transient values (live pace, GPS accuracy / error) are not stored.
Map<String, dynamic> cardioToJson(CardioState s) => {
  'sport': s.sport.name,
  'title': s.title,
  'planId': s.planId,
  'start': s.start.millisecondsSinceEpoch,
  'acc': s.accumulatedSec,
  'runningSince': s.runningSince?.millisecondsSinceEpoch,
  'dist': s.distanceM,
  'elev': s.elevationM,
  'splits': s.splits,
  'indoor': s.indoor,
  'laps': s.laps,
  'pool': s.poolLengthM,
  'steps': [for (final st in s.steps) st.toMap()],
  'stepIndex': s.stepIndex,
  'stepStartSec': s.stepStartSec,
  'stepStartDist': s.stepStartDist,
  'stepsDone': s.stepsDone,
  'paceHistory': s.paceHistory,
  'autoPaused': s.autoPaused,
  'voice': s.voice,
  'lengthSecs': s.lengthSecs,
  'lastLengthAt': s.lastLengthAt,
  'lengthMarks': [
    for (final m in s.lengthMarks) [m.stepIndex, m.stepStartSec, m.stepStartDist, m.stepsDone ? 1 : 0, m.lastLengthAt],
  ],
  'bestPace': s.bestPace,
  'lapSecs': s.lapSecs,
  'lapDists': s.lapDists,
  'lapStartSec': s.lapStartSec,
  'lapStartDist': s.lapStartDist,
  'stepResults': [
    for (final r in s.stepResults) [r.index, r.sec, r.distanceM, r.complete ? 1 : 0],
  ],
  'paceTime': {for (final e in s.paceTime.entries) '${e.key}': e.value},
  // When this state was written – a restore counts the time the app was dead as a pause.
  'savedAt': DateTime.now().millisecondsSinceEpoch,
};

CardioState cardioFromJson(Map m, {List<LatLng> points = const []}) => CardioState(
  sport: SportX.parse(m['sport']),
  title: m['title'] as String? ?? '',
  planId: m['planId'] as String?,
  start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
  accumulatedSec: m['acc'] as int? ?? 0,
  runningSince: _time(m['runningSince']),
  distanceM: _d(m['dist']),
  elevationM: _d(m['elev']),
  points: points,
  splits: _ints(m['splits']),
  indoor: m['indoor'] == true,
  laps: m['laps'] as int? ?? 0,
  poolLengthM: m['pool'] as int? ?? 25,
  steps: [for (final st in (m['steps'] as List? ?? const [])) WorkoutStep.fromMap(st as Map)],
  stepIndex: m['stepIndex'] as int? ?? 0,
  stepStartSec: m['stepStartSec'] as int? ?? 0,
  stepStartDist: _d(m['stepStartDist']),
  stepsDone: m['stepsDone'] == true,
  paceHistory: _ints(m['paceHistory']),
  autoPaused: m['autoPaused'] == true,
  voice: m['voice'] != false,
  lengthSecs: _ints(m['lengthSecs']),
  lastLengthAt: m['lastLengthAt'] as int? ?? 0,
  lengthMarks: [
    for (final x in (m['lengthMarks'] as List? ?? const []))
      StepMark((x as List)[0] as int, x[1] as int, (x[2] as num).toDouble(), x[3] == 1, x[4] as int),
  ],
  bestPace: m['bestPace'] as int?,
  lapSecs: _ints(m['lapSecs']),
  lapDists: _doubles(m['lapDists']),
  lapStartSec: m['lapStartSec'] as int? ?? 0,
  lapStartDist: _d(m['lapStartDist']),
  stepResults: [
    for (final x in (m['stepResults'] as List? ?? const []))
      StepResult((x as List)[0] as int, x[1] as int, (x[2] as num).toDouble(), complete: x[3] == 1),
  ],
  paceTime: {for (final e in ((m['paceTime'] as Map?) ?? const {}).entries) int.parse(e.key as String): (e.value as num).toInt()},
);

/// One route point per line ("lat,lng"); 6 decimals ≈ 0.1 m.
String encodeRoutePoints(Iterable<LatLng> pts) =>
    pts.map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}\n').join();

List<LatLng> decodeRoute(String text) {
  final out = <LatLng>[];
  for (final line in const LineSplitter().convert(text)) {
    final i = line.indexOf(',');
    if (i <= 0) continue;
    final a = double.tryParse(line.substring(0, i)), o = double.tryParse(line.substring(i + 1));
    // A line cut off by a crash mid-write is skipped.
    if (a != null && o != null) out.add(LatLng(a, o));
  }
  return out;
}

/// Finished-but-unsaved session (summary page) incl. the effort rating and notes typed so far.
Map<String, dynamic> sessionDraftToJson(Session s) => {
  'id': s.id,
  'sport': s.sport.name,
  'title': s.title,
  'start': s.start.millisecondsSinceEpoch,
  'durationSec': s.durationSec,
  'rpe': s.rpe,
  'notes': s.notes,
  'exercises': [for (final e in s.exercises) e.toMap()],
  'distanceM': s.distanceM,
  'elevationM': s.elevationM,
  'route': s.route,
  'splits': s.splits,
  'laps': s.laps,
  'poolLengthM': s.poolLengthM,
  'indoor': s.indoor,
  'templateId': s.templateId,
  'planId': s.planId,
  if (s.plannedSets != null) 'plannedSets': s.plannedSets,
  if (s.bodyWeightKg != null) 'bwKg': s.bodyWeightKg,
};

Session sessionDraftFromJson(Map m) => Session(
  id: m['id'] as String,
  sport: SportX.parse(m['sport']),
  title: m['title'] as String? ?? '',
  start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
  durationSec: m['durationSec'] as int? ?? 0,
  rpe: m['rpe'] as int?,
  notes: m['notes'] as String? ?? '',
  exercises: [for (final e in (m['exercises'] as List? ?? const [])) GymExercise.fromMap(e as Map)],
  distanceM: _d(m['distanceM']),
  elevationM: _d(m['elevationM']),
  route: [for (final p in (m['route'] as List? ?? const [])) _doubles(p)],
  splits: _ints(m['splits']),
  laps: m['laps'] as int? ?? 0,
  poolLengthM: m['poolLengthM'] as int? ?? 25,
  indoor: m['indoor'] == true,
  templateId: m['templateId'] as String?,
  planId: m['planId'] as String?,
  plannedSets: m['plannedSets'] as int?,
  bodyWeightKg: m['bwKg'] is num ? (m['bwKg'] as num).toDouble() : null,
);

// ───────────────────────────── Store ─────────────────────────────

/// A workout found in storage on app start.
class SavedWorkout {
  const SavedWorkout({this.gym, this.cardio, this.savedAt});
  final ActiveGym? gym;
  final CardioState? cardio;

  /// When the cardio state was last written (null for files of older versions).
  final DateTime? savedAt;

  DateTime get start => gym?.start ?? cardio!.start;
  String get title => gym?.title ?? cardio!.title;
  Sport get sport => gym != null ? Sport.gym : cardio!.sport;
}

abstract class WorkoutStore {
  Future<SavedWorkout?> loadActive();

  /// Stores the gym workout (replaces any stored cardio recording).
  Future<void> saveGym(ActiveGym g);

  /// Stores the cardio recording; route points are appended (only the new ones are written).
  Future<void> saveCardio(CardioState s);
  Future<void> clearActive();

  Future<Session?> loadSummary();
  Future<void> saveSummary(Session draft);
  Future<void> clearSummary();
}

/// File storage in the app's private support directory.
class FileWorkoutStore implements WorkoutStore {
  FileWorkoutStore([this._resolveDir = _defaultDir]);

  static Future<Directory> _defaultDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}active_workout').create(recursive: true);
  }

  final Future<Directory> Function() _resolveDir;

  // Resolved on first use (inside error handling), never eagerly.
  Future<Directory>? _dirFuture;
  Future<Directory> get _dir => _dirFuture ??= _resolveDir();
  Future<void> _queue = Future.value();

  // Route points already in the route file, and the workout they belong to.
  int _routeSaved = 0;
  DateTime? _routeOf;

  Future<File> _file(String name) async => File('${(await _dir).path}${Platform.pathSeparator}$name');

  /// Runs writes one after another (never two writers on one file); errors are swallowed –
  /// persistence is best effort and must never break the workout.
  Future<void> _run(Future<void> Function() f) =>
      _queue = _queue.then((_) => f()).catchError((Object e) {
        debugPrint('WorkoutStore: $e');
      });

  Future<void> _writeAtomic(String name, String text) async {
    final f = await _file(name);
    final tmp = await _file('$name.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> _delete(String name) async {
    final f = await _file(name);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<SavedWorkout?> loadActive() async {
    await _queue;
    try {
      final f = await _file('active.json');
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map;
      if (m['v'] != _version) return null;
      final data = m['data'] as Map;
      if (m['kind'] == 'gym') return SavedWorkout(gym: activeGymFromJson(data));
      final r = await _file('route.txt');
      final pts = await r.exists() ? decodeRoute(await r.readAsString()) : <LatLng>[];
      final s = cardioFromJson(data, points: pts);
      _routeSaved = pts.length;
      _routeOf = s.start;
      return SavedWorkout(cardio: s, savedAt: _time(data['savedAt']));
    } catch (e) {
      debugPrint('WorkoutStore: unreadable workout ($e)');
      return null;
    }
  }

  @override
  Future<void> saveGym(ActiveGym g) {
    final json = jsonEncode({'v': _version, 'kind': 'gym', 'data': activeGymToJson(g)});
    return _run(() async {
      await _writeAtomic('active.json', json);
      if (_routeOf != null) {
        await _delete('route.txt');
        _routeOf = null;
        _routeSaved = 0;
      }
    });
  }

  @override
  Future<void> saveCardio(CardioState s) {
    final json = jsonEncode({'v': _version, 'kind': 'cardio', 'data': cardioToJson(s)});
    // Snapshot of the new points now (the live list keeps growing).
    final pts = s.points;
    final fresh = _routeOf != s.start || pts.length < _routeSaved;
    final from = fresh ? 0 : _routeSaved;
    final add = encodeRoutePoints(pts.skip(from).take(pts.length - from));
    final count = pts.length;
    _routeOf = s.start;
    _routeSaved = count;
    return _run(() async {
      final r = await _file('route.txt');
      if (fresh) {
        await r.writeAsString(add, flush: true);
      } else if (add.isNotEmpty) {
        await r.writeAsString(add, mode: FileMode.append, flush: true);
      }
      await _writeAtomic('active.json', json);
    });
  }

  @override
  Future<void> clearActive() {
    _routeOf = null;
    _routeSaved = 0;
    return _run(() async {
      await _delete('active.json');
      await _delete('route.txt');
    });
  }

  @override
  Future<Session?> loadSummary() async {
    await _queue;
    try {
      final f = await _file('summary.json');
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map;
      return m['v'] == _version ? sessionDraftFromJson(m['data'] as Map) : null;
    } catch (e) {
      debugPrint('WorkoutStore: unreadable summary ($e)');
      return null;
    }
  }

  @override
  Future<void> saveSummary(Session draft) {
    final json = jsonEncode({'v': _version, 'data': sessionDraftToJson(draft)});
    return _run(() => _writeAtomic('summary.json', json));
  }

  @override
  Future<void> clearSummary() => _run(() => _delete('summary.json'));
}

/// In-memory store (tests); goes through the same JSON as the file store.
class MemoryWorkoutStore implements WorkoutStore {
  String? active, route, summary;
  int saves = 0;

  @override
  Future<SavedWorkout?> loadActive() async {
    if (active == null) return null;
    final m = jsonDecode(active!) as Map;
    if (m['kind'] == 'gym') return SavedWorkout(gym: activeGymFromJson(m['data'] as Map));
    final data = m['data'] as Map;
    return SavedWorkout(cardio: cardioFromJson(data, points: decodeRoute(route ?? '')), savedAt: _time(data['savedAt']));
  }

  @override
  Future<void> saveGym(ActiveGym g) async {
    saves++;
    active = jsonEncode({'v': _version, 'kind': 'gym', 'data': activeGymToJson(g)});
    route = null;
  }

  @override
  Future<void> saveCardio(CardioState s) async {
    saves++;
    active = jsonEncode({'v': _version, 'kind': 'cardio', 'data': cardioToJson(s)});
    route = encodeRoutePoints(s.points);
  }

  @override
  Future<void> clearActive() async => active = route = null;

  @override
  Future<Session?> loadSummary() async => summary == null ? null : sessionDraftFromJson((jsonDecode(summary!) as Map)['data'] as Map);

  @override
  Future<void> saveSummary(Session draft) async => summary = jsonEncode({'v': _version, 'data': sessionDraftToJson(draft)});

  @override
  Future<void> clearSummary() async => summary = null;
}

final workoutStoreProvider = Provider<WorkoutStore>((ref) => FileWorkoutStore());

// ───────────────────────────── Autosave ─────────────────────────────

/// Mirrors the active workout into [WorkoutStore]: at most every [throttle] for routine
/// changes (timer ticks, GPS fixes, edits), immediately for important events (set checked
/// off, lap / length, pause / resume, step change, start, finish / discard) and when the
/// app goes to the background.
class WorkoutAutosave {
  WorkoutAutosave(this._store, {this.throttle = const Duration(seconds: 2)}) {
    _lifecycle = AppLifecycleListener(onHide: flush, onPause: flush, onDetach: flush);
  }

  final WorkoutStore _store;
  final Duration throttle;
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  ActiveGym? _gym;
  CardioState? _cardio;
  bool _dirty = false;

  // Fingerprint of the last saved state's "important" parts.
  String? _gymKey, _cardioKey;

  /// While false (restore prompt still open), nothing is written: the stored workout must
  /// not be overwritten or cleared before the user decided.
  bool enabled = false;

  /// Starts mirroring (after the restore decision); saves the current workout, if any.
  void enable() {
    if (enabled) return;
    enabled = true;
    onGym(_gym);
    onCardio(_cardio);
  }

  void onGym(ActiveGym? g) {
    _gym = g;
    if (!enabled) return;
    if (g == null) {
      if (_gymKey != null) _clear();
      _gymKey = null;
      return;
    }
    final key = '${g.start.millisecondsSinceEpoch}|${g.doneSets}|${g.exercises.length}|${g.totalSets}|${g.restEnd}';
    _schedule(immediate: key != _gymKey);
    _gymKey = key;
  }

  void onCardio(CardioState? s) {
    _cardio = s;
    if (!enabled) return;
    if (s == null) {
      if (_cardioKey != null) _clear();
      _cardioKey = null;
      return;
    }
    final key = '${s.start.millisecondsSinceEpoch}|${s.paused}|${s.laps}|${s.stepIndex}|${s.stepsDone}|${s.splits.length}';
    _schedule(immediate: key != _cardioKey);
    _cardioKey = key;
  }

  void _schedule({required bool immediate}) {
    _dirty = true;
    if (immediate) return flush();
    _timer ??= Timer(throttle, flush);
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _dirty = false;
    if (_gym == null && _cardio == null) _store.clearActive();
  }

  /// Writes the pending state now.
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (!_dirty || !enabled) return;
    _dirty = false;
    final c = _cardio, g = _gym;
    if (c != null) {
      _store.saveCardio(c);
    } else if (g != null) {
      _store.saveGym(g);
    }
  }

  void dispose() {
    flush();
    _timer?.cancel();
    _lifecycle.dispose();
  }
}

final workoutAutosaveProvider = Provider<WorkoutAutosave>((ref) {
  final a = WorkoutAutosave(ref.watch(workoutStoreProvider));
  ref.listen(activeGymProvider, (_, g) => a.onGym(g), fireImmediately: true);
  ref.listen(trackerProvider, (_, c) => a.onCardio(c), fireImmediately: true);
  ref.onDispose(a.dispose);
  return a;
});
