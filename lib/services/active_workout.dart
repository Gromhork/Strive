import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/sport.dart';
import '../data/models.dart';
import '../providers.dart';
import 'supersets.dart';

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

  const ActiveGym({
    required this.title,
    this.templateId,
    this.planId,
    required this.start,
    required this.exercises,
    this.restEnd,
    this.restTotal = 0,
    this.restIsTransition = false,
    this.focus = 0,
    this.effortFor,
  });

  double get volume => exercises.fold(0, (a, e) => a + e.volume);
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneSets);
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

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
  }) => ActiveGym(
    title: title ?? this.title,
    templateId: templateId,
    planId: planId,
    start: start,
    exercises: exercises,
    restEnd: clearRest ? null : (restEnd ?? this.restEnd),
    restTotal: restTotal ?? this.restTotal,
    restIsTransition: clearRest ? false : (restIsTransition ?? this.restIsTransition),
    focus: (focus ?? this.focus).clamp(0, exercises.isEmpty ? 0 : exercises.length - 1),
    effortFor: clearRest ? null : (effortFor ?? this.effortFor),
  );
}

class ActiveGymNotifier extends Notifier<ActiveGym?> {
  Timer? _restTimer;

  @override
  ActiveGym? build() {
    ref.onDispose(() => _restTimer?.cancel());
    return null;
  }

  void start({required String title, String? templateId, String? planId, List<GymExercise> exercises = const []}) {
    final list = exercises.map((e) => e.copy(resetDone: true)).toList();
    // Repairs superset data of older programs (non-adjacent letters, long chains).
    normalizeSupersets(list);
    state = ActiveGym(title: title, templateId: templateId, planId: planId, start: DateTime.now(), exercises: list);
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
    list.removeAt(i);
    normalizeSupersets(list);
    _touch();
  }

  /// Moves an exercise; a superset member that is moved away leaves its superset.
  void moveExercise(int from, int to) {
    final list = state?.exercises;
    if (list == null) return;
    final e = list.removeAt(from);
    list.insert(to > from ? to - 1 : to, e);
    normalizeSupersets(list);
    _touch();
  }

  void addSet(int ex) {
    final e = state?.exercises[ex];
    if (e == null) return;
    final last = e.sets.isNotEmpty ? e.sets.last : GymSet();
    e.sets.add(GymSet(weight: last.weight, reps: last.reps));
    _touch();
  }

  void removeSet(int ex, int set) {
    state?.exercises[ex].sets.removeAt(set);
    _touch();
  }

  /// Updates a set. A new weight on an open work set is carried over to the following
  /// open work sets that had the same weight (so changing the load once is enough).
  void updateSet(int ex, int set, {double? weight, int? reps, bool? warmup, SetType? type, double? rpe, bool clearRpe = false}) {
    final e = state?.exercises[ex];
    final s = e?.sets[set];
    if (e == null || s == null) return;
    if (weight != null && !s.done && !s.warmup && s.type != SetType.drop) {
      for (final o in e.sets.skip(set + 1)) {
        if (!o.done && !o.warmup && o.type != SetType.drop && (o.weight - s.weight).abs() < 1e-6) o.weight = weight;
      }
    }
    if (weight != null) s.weight = weight;
    if (reps != null) s.reps = reps;
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
    final w = state;
    final e = w?.exercises[ex];
    if (w == null || e == null) return;
    final s = e.sets[set];
    s.done = !s.done;
    HapticFeedback.lightImpact();
    if (!s.done) return _touch();

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
  void setBodyweight(int ex, bool on) {
    final e = state?.exercises[ex];
    if (e == null) return;
    ref.read(loadPrescriberProvider).switchBodyweight(e, on);
    _touch();
  }

  /// Swaps the exercise of slot [i]: rep range, bodyweight mode and the open sets'
  /// loads are re-derived for the new exercise.
  void replaceExercise(int i, String exId, String name) {
    final e = state?.exercises[i];
    if (e == null) return;
    e.exId = exId;
    e.name = name;
    e.repMin = null;
    e.repMax = null;
    e.bw = null;
    e.bodyKg = 0;
    final rx = ref.read(loadPrescriberProvider);
    if (rx.isBodyweight(e)) {
      e.bw = true;
      e.bodyKg = rx.bodyLoad(e);
    }
    final p = rx.forExercise(e);
    e.rxKg = p?.weight;
    var k = 0;
    for (final s in e.sets) {
      if (s.done || s.warmup || s.type == SetType.drop) continue;
      s.weight = p?.weight ?? 0;
      s.reps = p?.repsForSet(k++) ?? s.reps;
      s.target = p == null ? null : s.reps;
      s.amrap = false;
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
    e.sets.add(GymSet(weight: (w / 2.5).round() * 2.5, reps: last.reps, type: SetType.drop));
    _touch();
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

  Future<void> _restDone() async {
    state = state?.copyWith(clearRest: true);
    if (ref.read(settingsProvider).vibrate) {
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  /// Builds the session (without saving) and clears the active workout.
  Session finish(String id) {
    final s = state!;
    final session = Session(
      id: id,
      sport: Sport.gym,
      title: s.title,
      start: s.start,
      durationSec: DateTime.now().difference(s.start).inSeconds,
      exercises: s.exercises.where((e) => e.sets.any((x) => x.done)).toList(),
      templateId: s.templateId,
      planId: s.planId,
      // All work sets incl. exercises without a done set (not stored) – plan compliance.
      plannedSets: s.exercises.fold<int>(0, (a, e) => a + e.workSets.length),
    );
    discard();
    return session;
  }

  void discard() {
    _restTimer?.cancel();
    state = null;
    WakelockPlus.disable();
  }
}

final activeGymProvider = NotifierProvider<ActiveGymNotifier, ActiveGym?>(ActiveGymNotifier.new);
