import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/sport.dart';
import '../data/models.dart';
import '../providers.dart';
import 'supersets.dart';
import 'supersets.dart' as supersets;
import 'workout_alerts.dart';

/// Lead-in of the hold timer: "3, 2, 1" to get into position before the hold time runs.
const holdLeadInSec = 3;

/// Countdown pips before the end of a hold (the last seconds).
const holdCountdownSec = 3;

/// State of the gym workout currently in progress (survives tab switches).
class ActiveGym {
  final String title;
  final String? templateId;
  final String? planId;
  final DateTime start;
  final List<GymExercise> exercises;
  final DateTime? restEnd;
  final int restTotal;

  /// The running rest is the short switch between members of a superset.
  final bool restIsTransition;

  /// Exercise shown in the focus view (follows supersets automatically).
  final int focus;

  /// Exercise whose last work set was just checked off – the rest screen asks the
  /// optional effort rating for it.
  final GymExercise? effortFor;

  /// Running hold timer of a timed exercise (plank, wall sit, …): exercise / set index, when the
  /// hold time starts (after the lead-in – in the future while "3, 2, 1" runs, [holdLeadInLeft])
  /// and the target time it counts down from (then on as a stopwatch).
  final int? holdEx, holdSet;
  final DateTime? holdStart;
  final int holdTarget;

  /// Work sets of the planned workout when it was started from the plan (the program's sets for
  /// that day) or of the program started from the Train tab; null for free workouts. Exercises
  /// or sets removed in the tracker still count as planned – the compliance compares against
  /// the program, not against what is left ([plannedWorkSets]).
  final int? programSets;

  const ActiveGym({
    required this.title,
    this.templateId,
    this.planId,
    required this.start,
    required this.exercises,
    this.programSets,
    this.restEnd,
    this.restTotal = 0,
    this.restIsTransition = false,
    this.focus = 0,
    this.effortFor,
    this.holdEx,
    this.holdSet,
    this.holdStart,
    this.holdTarget = 0,
  });

  /// Whether the hold timer runs for set [set] of exercise [ex].
  bool holding(int ex, int set) => holdStart != null && holdEx == ex && holdSet == set;

  /// Seconds held so far (0 without a running hold and during the lead-in).
  int holdElapsed([DateTime? now]) => holdStart == null ? 0 : max(0, (now ?? DateTime.now()).difference(holdStart!).inMilliseconds ~/ 1000);

  /// Seconds left of the lead-in ("3, 2, 1") before the hold time runs; 0 once it runs.
  int holdLeadInLeft([DateTime? now]) {
    if (holdStart == null) return 0;
    final ms = holdStart!.difference(now ?? DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  double get volume => exercises.fold(0, (a, e) => a + e.volume);
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneSets);
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

  /// Work sets in the tracker now (incl. exercises without a done set).
  int get workSets => exercises.fold<int>(0, (a, e) => a + e.workSets.length);

  /// Work sets the done sets are compared with ([Session.plannedSets]): the program's sets of a
  /// planned workout or program ([programSets]) or, when more were added in the tracker, those.
  int get plannedWorkSets => max(programSets ?? 0, workSets);

  /// Members of the superset that exercise [i] belongs to (adjacent, in order).
  List<int> groupOf(int i) => supersetOf(exercises, i);

  /// Index of the next exercise that still has open sets (from [from] on, wrapping).
  int? nextOpen([int from = 0]) {
    for (var k = 0; k < exercises.length; k++) {
      final i = (from + k) % exercises.length;
      if (!exercises[i].allDone) return i;
    }
    return null;
  }

  ActiveGym copyWith({
    String? title,
    DateTime? restEnd,
    bool clearRest = false,
    int? restTotal,
    bool? restIsTransition,
    int? focus,
    GymExercise? effortFor,
    int? holdEx,
    int? holdSet,
    DateTime? holdStart,
    int? holdTarget,
    bool clearHold = false,
  }) => ActiveGym(
    title: title ?? this.title,
    templateId: templateId,
    planId: planId,
    start: start,
    exercises: exercises,
    programSets: programSets,
    restEnd: clearRest ? null : (restEnd ?? this.restEnd),
    restTotal: restTotal ?? this.restTotal,
    restIsTransition: clearRest ? false : (restIsTransition ?? this.restIsTransition),
    focus: (focus ?? this.focus).clamp(0, exercises.isEmpty ? 0 : exercises.length - 1),
    effortFor: clearRest ? null : (effortFor ?? this.effortFor),
    holdEx: clearHold ? null : (holdEx ?? this.holdEx),
    holdSet: clearHold ? null : (holdSet ?? this.holdSet),
    holdStart: clearHold ? null : (holdStart ?? this.holdStart),
    holdTarget: clearHold ? 0 : (holdTarget ?? this.holdTarget),
  );
}

class ActiveGymNotifier extends Notifier<ActiveGym?> {
  Timer? _restTimer;
  Timer? _holdTimer;
  Timer? _holdTicks;

  /// The running hold is still in its lead-in (nothing held yet) – set by the timers, not the
  /// wall clock, so "Stop" and the check-off agree with the pips.
  bool _inLeadIn = false;

  /// Preference key: a hold that reaches its target time is checked off by itself (and the
  /// rest starts); off = it counts on as a stopwatch until "Stop".
  static const holdAutoDoneKey = 'holdAutoDone';

  /// Preference key: the hold timer starts with a [holdLeadInSec] "3, 2, 1" to get into position.
  static const holdLeadInKey = 'holdLeadIn';

  @override
  ActiveGym? build() {
    ref.onDispose(() {
      _restTimer?.cancel();
      _holdTimer?.cancel();
      _holdTicks?.cancel();
    });
    return null;
  }

  bool get holdAutoDone {
    try {
      return ref.read(prefsProvider).getBool(holdAutoDoneKey) ?? true;
    } catch (_) {
      return true; // no preferences (tests)
    }
  }

  void setHoldAutoDone(bool on) {
    try {
      ref.read(prefsProvider).setBool(holdAutoDoneKey, on);
    } catch (_) {}
    _touch();
  }

  bool get holdLeadIn {
    try {
      return ref.read(prefsProvider).getBool(holdLeadInKey) ?? true;
    } catch (_) {
      return true; // no preferences (tests)
    }
  }

  void setHoldLeadIn(bool on) {
    try {
      ref.read(prefsProvider).setBool(holdLeadInKey, on);
    } catch (_) {}
    _touch();
  }

  /// Plays a timer signal with the user's sound / vibration settings (both on without settings).
  void _alert(AlertSignal signal) {
    var sound = true, vibrate = true;
    try {
      final st = ref.read(settingsProvider);
      sound = st.timerSound;
      vibrate = st.vibrate;
    } catch (_) {}
    try {
      ref.read(workoutAlertsProvider).play(signal, sound: sound, vibrate: vibrate);
    } catch (_) {}
  }

  void start({required String title, String? templateId, String? planId, List<GymExercise> exercises = const []}) {
    final list = exercises.map((e) => e.copy(resetDone: true)).toList();
    // Repairs superset data of older programs (non-adjacent letters, long chains).
    normalizeSupersets(list);
    state = ActiveGym(
      title: title,
      templateId: templateId,
      planId: planId,
      start: DateTime.now(),
      exercises: list,
      // Started from the plan or a program (Train tab – linked to the day's planned workout on
      // saving): its sets are the reference, whatever is removed in the tracker.
      programSets: planId == null && templateId == null ? null : list.fold<int>(0, (a, e) => a + e.workSets.length),
    );
    WakelockPlus.enable();
  }

  /// Continues a workout restored from storage after the app was killed. A rest that is
  /// still running keeps its end time; an expired one is cleared.
  void restore(ActiveGym g) {
    _restTimer?.cancel();
    final left = g.restEnd?.difference(DateTime.now());
    if (left == null || left.isNegative) {
      state = g.copyWith(clearRest: true);
    } else {
      state = g;
      _restTimer = Timer(left, _restDone);
    }
    WakelockPlus.enable();
  }

  void _touch() => state = state?.copyWith();

  void rename(String t) => state = state?.copyWith(title: t);

  void addExercise(GymExercise e) {
    state?.exercises.add(e);
    _touch();
  }

  void removeExercise(int i) {
    final list = state?.exercises;
    if (list == null) return;
    cancelHold();
    list.removeAt(i);
    normalizeSupersets(list);
    _touch();
  }

  /// Moves an exercise to index [to] (as in a reorderable list: the index *before* removal).
  /// Supersets stay contiguous, see [supersets.moveExercise].
  SupersetMove moveExercise(int from, int to) {
    final list = state?.exercises;
    if (list == null) return SupersetMove.moved;
    cancelHold();
    final focused = _focused(list);
    final r = supersets.moveExercise(list, from, to > from ? to - 1 : to);
    _refocus(list, focused);
    _touch();
    return r;
  }

  /// "Move up / down": one step, jumping over a whole superset instead of entering it
  /// ([supersets.stepExercise]).
  void stepExercise(int i, int dir) {
    final list = state?.exercises;
    if (list == null) return;
    cancelHold();
    final focused = _focused(list);
    supersets.stepExercise(list, i, dir);
    _refocus(list, focused);
    _touch();
  }

  GymExercise? _focused(List<GymExercise> list) {
    final f = state?.focus ?? -1;
    return f >= 0 && f < list.length ? list[f] : null;
  }

  /// The focus view keeps showing the same exercise after a reorder.
  void _refocus(List<GymExercise> list, GymExercise? focused) {
    final w = state;
    if (w == null || focused == null) return;
    final i = list.indexWhere((x) => identical(x, focused));
    if (i >= 0 && i != w.focus) state = w.copyWith(focus: i);
  }

  void addSet(int ex) {
    final e = state?.exercises[ex];
    if (e == null) return;
    final last = e.sets.isNotEmpty ? e.sets.last : GymSet();
    final sec = e.isTimed ? (last.sec > 0 ? last.sec : (last.targetSec ?? e.holdRange.$1)) : 0;
    e.sets.add(GymSet(weight: last.weight, reps: e.isTimed ? 0 : last.reps, sec: sec));
    _touch();
  }

  void removeSet(int ex, int set) {
    if (state?.holdEx == ex) cancelHold();
    state?.exercises[ex].sets.removeAt(set);
    _touch();
  }

  /// Updates a set. A new weight on an open work set is carried over to the following
  /// open work sets that had the same weight (so changing the load once is enough).
  void updateSet(int ex, int set, {double? weight, int? reps, int? sec, bool? warmup, SetType? type, double? rpe, bool clearRpe = false}) {
    final e = state?.exercises[ex];
    final s = e?.sets[set];
    if (e == null || s == null) return;
    if (weight != null && !s.done && !s.warmup && s.type != SetType.drop) {
      for (final o in e.sets.skip(set + 1)) {
        if (!o.done && !o.warmup && o.type != SetType.drop && (o.weight - s.weight).abs() < 1e-6) o.weight = weight;
      }
    }
    if (sec != null && !s.done && !s.warmup && s.type != SetType.drop) {
      // A new hold time on an open set carries over like a new weight.
      for (final o in e.sets.skip(set + 1)) {
        if (!o.done && !o.warmup && o.type != SetType.drop && o.sec == s.sec) o.sec = sec;
      }
    }
    if (weight != null) s.weight = weight;
    if (reps != null) s.reps = reps;
    if (sec != null) s.sec = max(0, sec);
    if (warmup != null) s.warmup = warmup;
    if (type != null) s.type = type;
    if (rpe != null || clearRpe) s.rpe = rpe;
    _touch();
  }

  void setFocus(int i) => state = state?.copyWith(focus: i);

  /// Checks a set off (or un-checks it). Handles rest timers and superset flow:
  /// A1 → short switch → A2 → full rest → A1 → A2 … Warm-up sets get a short rest and
  /// stay on the same exercise.
  void toggleDone(int ex, int set) {
    final cur = state;
    final e = cur?.exercises[ex];
    if (cur == null || e == null) return;
    var w = cur;
    final s = e.sets[set];
    if (w.holding(ex, set)) {
      // Checked off while its hold timer runs: the time held so far (during the lead-in nothing
      // was held yet – the planned time, like checking it off without the timer).
      final leadIn = _inLeadIn;
      _cancelHoldTimers();
      if (!s.done && !leadIn) s.sec = max(1, w.holdElapsed());
      state = w = w.copyWith(clearHold: true);
    }
    s.done = !s.done;
    HapticFeedback.lightImpact();
    if (!s.done) return _touch();
    // A timed set checked off without the timer: the planned time was held.
    if (e.isTimed && s.sec <= 0) s.sec = s.targetSec ?? e.holdRange.$1;

    final finished = w.nextOpen() == null;
    // Last work set of the exercise done → offer the optional effort rating.
    final work = e.sets.where((x) => !x.warmup && x.type != SetType.drop);
    final rate = !s.warmup && work.isNotEmpty && work.every((x) => x.done) ? e : null;
    if (s.warmup && !e.allDone) {
      state = w.copyWith(focus: ex);
      if (!finished) startRest(min(60, e.restSec));
      return;
    }
    final group = w.groupOf(ex);
    final pos = group.indexOf(ex);
    // Next member of the superset in this round that still has open sets.
    final laterInRound = group.skip(pos + 1).where((i) => !w.exercises[i].allDone);
    if (group.length > 1 && laterInRound.isNotEmpty) {
      state = w.copyWith(focus: laterInRound.first, clearRest: true);
      if (s.type != SetType.drop) startRest(supersetTransitionSec, transition: true, effortFor: rate);
      return;
    }
    final groupOpen = group.where((i) => !w.exercises[i].allDone);
    final nextFocus = groupOpen.isNotEmpty ? groupOpen.first : (w.nextOpen(group.last + 1) ?? ex);
    final rest = group.map((i) => w.exercises[i].restSec).reduce((a, b) => a > b ? a : b);
    if (rest > 0 && !finished && s.type != SetType.drop) {
      state = w.copyWith(focus: nextFocus);
      startRest(rest, effortFor: rate);
    } else {
      state = w.copyWith(focus: nextFocus);
    }
  }

  /// Links exercise [i] with the next one into a superset, or removes it from its
  /// superset. Returns false when linking would exceed [maxSupersetSize] exercises.
  bool toggleSuperset(int i) {
    final list = state?.exercises;
    if (list == null) return false;
    var ok = true;
    if (supersetOf(list, i).length > 1) {
      leaveSuperset(list, i);
    } else {
      ok = linkSuperset(list, i);
    }
    _touch();
    return ok;
  }

  /// Switches bodyweight mode of exercise [ex] (see [LoadPrescriber.switchBodyweight]).
  /// Load phase of the planned workout this one was started from ([planPhaseOf]).
  String? get _loadPhase => planPhaseOf(ref.read(planListProvider), state?.planId);

  void setBodyweight(int ex, bool on) {
    final e = state?.exercises[ex];
    if (e == null) return;
    ref.read(loadPrescriberProvider).switchBodyweight(e, on, phase: _loadPhase);
    _touch();
  }

  /// Swaps the exercise of slot [i]: rep range, bodyweight mode and the open sets'
  /// loads are re-derived for the new exercise.
  void replaceExercise(int i, String exId, String name) {
    final e = state?.exercises[i];
    if (e == null) return;
    if (state?.holdEx == i) cancelHold();
    e.exId = exId;
    e.name = name;
    e.repMin = null;
    e.repMax = null;
    e.holdMin = null;
    e.holdMax = null;
    e.timed = null;
    e.bw = null;
    e.bodyKg = 0;
    final rx = ref.read(loadPrescriberProvider);
    if (rx.isBodyweight(e)) {
      e.bw = true;
      e.bodyKg = rx.bodyLoad(e);
    }
    // (In a deload / taper week or on a lighter-legs day the new exercise is prescribed lighter too.)
    final phase = _loadPhase;
    e.phase = rx.lighterFor(e, phase) ? phase : null;
    final p = rx.forExercise(e, phase: phase);
    e.rxKg = p?.weight;
    final timed = e.isTimed;
    var k = 0;
    for (final s in e.sets) {
      if (s.done || s.warmup || s.type == SetType.drop) continue;
      s.weight = p?.weight ?? 0;
      s.amrap = false;
      if (timed) {
        // Reps → hold time (and back): the open sets switch their measure with the exercise.
        s.sec = p?.repsForSet(k++) ?? e.holdRange.$1;
        s.targetSec = p == null ? null : s.sec;
        s.reps = 0;
        s.target = null;
      } else {
        s.reps = p?.repsForSet(k++) ?? (s.reps > 0 ? s.reps : 10);
        s.target = p == null ? null : s.reps;
        s.sec = 0;
        s.targetSec = null;
      }
    }
    _touch();
  }

  /// Switches exercise [ex] between reps and hold time ([GymExercise.timed]): the open work sets
  /// get the prescription of the new measure (done sets keep what was logged).
  void setTimed(int ex, bool on) {
    final e = state?.exercises[ex];
    if (e == null) return;
    if (state?.holdEx == ex) cancelHold();
    e.timed = on;
    e.holdMin = null;
    e.holdMax = null;
    final rx = ref.read(loadPrescriberProvider);
    final p = rx.forExercise(e, phase: _loadPhase);
    var k = 0;
    for (final s in e.sets) {
      if (s.done || s.warmup) continue;
      if (on) {
        s.sec = p?.repsForSet(k++) ?? e.holdRange.$1;
        s.targetSec = p == null ? null : s.sec;
        s.reps = 0;
        s.target = null;
        s.amrap = false;
      } else {
        s.reps = p?.repsForSet(k++) ?? rx.range(e).$1;
        s.target = p == null ? null : s.reps;
        s.sec = 0;
        s.targetSec = null;
      }
      if (p != null) s.weight = p.weight;
    }
    _touch();
  }

  void insertWarmups(int ex, List<GymSet> warmups) {
    final e = state?.exercises[ex];
    if (e == null) return;
    e.sets.removeWhere((s) => s.warmup && !s.done);
    e.sets.insertAll(0, warmups);
    _touch();
  }

  void addDropSet(int ex) {
    final e = state?.exercises[ex];
    if (e == null) return;
    final last = e.sets.isNotEmpty ? e.sets.last : GymSet();
    // ~20 % less load; in bodyweight mode of the total load (more assistance).
    final w = e.bw == true ? last.weight - 0.2 * (last.weight + e.bodyKg) : last.weight * 0.8;
    e.sets.add(GymSet(weight: (w / 2.5).round() * 2.5, reps: last.reps, sec: last.sec, type: SetType.drop));
    _touch();
  }

  // ───────────────────────────── Hold timer (timed exercises) ─────────────────────────────

  /// Starts the hold timer for open set [set] of timed exercise [ex]: with [holdLeadIn] a
  /// "3, 2, 1" lead-in (pips) to get into position, then it counts down from the set's planned
  /// time with pips in the last [holdCountdownSec] seconds; at zero a beep and a vibration
  /// pattern signal the end ([WorkoutAlerts] – also with touch vibration off and the phone on
  /// the floor) and – with [holdAutoDone] – the set is checked off with that time and the rest
  /// starts, otherwise it counts on (overtime) until [stopHold]. A running rest ends; a hold
  /// running on another set is cancelled.
  void startHold(int ex, int set) {
    final w = state;
    final e = w?.exercises[ex];
    if (w == null || e == null || set >= e.sets.length || e.sets[set].done) return;
    _restTimer?.cancel();
    _cancelHoldTimers();
    final s = e.sets[set];
    final target = s.sec > 0 ? s.sec : (s.targetSec ?? e.holdRange.$1);
    final lead = holdLeadIn ? holdLeadInSec : 0;
    _inLeadIn = lead > 0;
    final start = DateTime.now().add(Duration(seconds: lead));
    state = w.copyWith(clearRest: true).copyWith(holdEx: ex, holdSet: set, holdStart: start, holdTarget: target, focus: ex);
    _holdTimer = Timer(Duration(seconds: lead + target), _holdReached);
    HapticFeedback.mediumImpact();
    // Second k after the tap: lead-in pips (3, 2, 1), "go", then the last seconds of the hold.
    var k = 0;
    void tick() {
      final held = k - lead;
      if (held < 0) {
        _alert(AlertSignal.tick);
      } else if (held == 0) {
        _inLeadIn = false;
        if (lead > 0) _alert(AlertSignal.go);
      } else if (held < target && target - held <= holdCountdownSec) {
        _alert(AlertSignal.tick);
      }
      k++;
      if (k - lead >= target) _holdTicks?.cancel();
    }

    tick();
    _holdTicks = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _cancelHoldTimers() {
    _holdTimer?.cancel();
    _holdTicks?.cancel();
    _inLeadIn = false;
  }

  void _holdReached() {
    final w = state;
    if (w?.holdStart == null) return;
    _holdTicks?.cancel();
    _alert(AlertSignal.end);
    if (holdAutoDone) stopHold(sec: w!.holdTarget);
  }

  /// Ends the running hold: the set gets the held time ([sec], else the time since the start,
  /// at least 1 s) and is checked off – the rest starts like after any set. Stopped during the
  /// lead-in (nothing held yet) the hold is just cancelled.
  void stopHold({int? sec}) {
    final w = state;
    final ex = w?.holdEx, set = w?.holdSet;
    if (w == null || ex == null || set == null || w.holdStart == null) return;
    if (sec == null && _inLeadIn) return cancelHold();
    _cancelHoldTimers();
    final held = max(1, sec ?? w.holdElapsed());
    state = w.copyWith(clearHold: true);
    final e = state!.exercises[ex];
    if (set >= e.sets.length || e.sets[set].done) return _touch();
    e.sets[set].sec = held;
    toggleDone(ex, set);
  }

  /// Stops the hold timer without logging anything.
  void cancelHold() {
    _cancelHoldTimers();
    if (state?.holdStart != null) state = state?.copyWith(clearHold: true);
  }

  /// Optional effort rating of exercise [ex] after its last work set (null clears it).
  void setEffort(int ex, Effort? effort) {
    final e = state?.exercises[ex];
    if (e == null) return;
    e.effort = effort;
    _touch();
  }

  void setNote(int ex, String note) {
    state?.exercises[ex].note = note;
    _touch();
  }

  void setRest(int ex, int sec) {
    state?.exercises[ex].restSec = sec;
    _touch();
  }

  void startRest(int seconds, {bool transition = false, GymExercise? effortFor}) {
    _restTimer?.cancel();
    final end = DateTime.now().add(Duration(seconds: seconds));
    state = state?.copyWith(clearRest: true).copyWith(restEnd: end, restTotal: seconds, restIsTransition: transition, effortFor: effortFor);
    _restTimer = Timer(Duration(seconds: seconds), _restDone);
  }

  void adjustRest(int delta) {
    final s = state;
    if (s?.restEnd == null) return;
    final end = s!.restEnd!.add(Duration(seconds: delta));
    final left = end.difference(DateTime.now());
    if (left.isNegative) return skipRest();
    _restTimer?.cancel();
    _restTimer = Timer(left, _restDone);
    state = s.copyWith(restEnd: end, restTotal: s.restTotal + delta);
  }

  void skipRest() {
    _restTimer?.cancel();
    state = state?.copyWith(clearRest: true);
  }

  void _restDone() {
    state = state?.copyWith(clearRest: true);
    _alert(AlertSignal.end);
  }

  /// Builds the session (without saving) and clears the active workout.
  Session finish(String id) {
    final s = state!;
    double? bodyWeight;
    try {
      bodyWeight = ref.read(profileOrDefaultProvider).weightKg;
    } catch (_) {}
    final session = Session(
      id: id,
      sport: Sport.gym,
      title: s.title,
      start: s.start,
      durationSec: DateTime.now().difference(s.start).inSeconds,
      exercises: s.exercises.where((e) => e.sets.any((x) => x.done)).toList(),
      templateId: s.templateId,
      planId: s.planId,
      // All work sets incl. exercises without a done set (not stored), at least the program's
      // sets of a planned workout (removed exercises count as not done) – plan compliance.
      plannedSets: s.plannedWorkSets,
      // Body weight of the day: the body load of bodyweight exercises in the volume stays as it
      // was, whatever the scale says later.
      bodyWeightKg: bodyWeight != null && bodyWeight > 0 ? bodyWeight : null,
    );
    discard();
    return session;
  }

  void discard() {
    _restTimer?.cancel();
    _cancelHoldTimers();
    state = null;
    WakelockPlus.disable();
  }
}

final activeGymProvider = NotifierProvider<ActiveGymNotifier, ActiveGym?>(ActiveGymNotifier.new);
