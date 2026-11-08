import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/sport.dart';
import '../data/models.dart';
import '../providers.dart';

/// State of the gym workout currently in progress (survives tab switches).
class ActiveGym {
  final String title;
  final String? templateId;
  final String? planId;
  final DateTime start;
  final List<GymExercise> exercises;
  final DateTime? restEnd;
  final int restTotal;

  /// Exercise shown in the focus view (follows supersets automatically).
  final int focus;

  const ActiveGym({
    required this.title,
    this.templateId,
    this.planId,
    required this.start,
    required this.exercises,
    this.restEnd,
    this.restTotal = 0,
    this.focus = 0,
  });

  double get volume => exercises.fold(0, (a, e) => a + e.volume);
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneSets);
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

  /// Members of the superset that exercise [i] belongs to (in order).
  List<int> groupOf(int i) {
    final g = exercises[i].group;
    if (g == null) return [i];
    return [
      for (var k = 0; k < exercises.length; k++)
        if (exercises[k].group == g) k,
    ];
  }

  /// Index of the next exercise that still has open sets (from [from] on, wrapping).
  int? nextOpen([int from = 0]) {
    for (var k = 0; k < exercises.length; k++) {
      final i = (from + k) % exercises.length;
      if (!exercises[i].allDone) return i;
    }
    return null;
  }

  ActiveGym copyWith({String? title, DateTime? restEnd, bool clearRest = false, int? restTotal, int? focus}) => ActiveGym(
    title: title ?? this.title,
    templateId: templateId,
    planId: planId,
    start: start,
    exercises: exercises,
    restEnd: clearRest ? null : (restEnd ?? this.restEnd),
    restTotal: restTotal ?? this.restTotal,
    focus: (focus ?? this.focus).clamp(0, exercises.isEmpty ? 0 : exercises.length - 1),
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
    state = ActiveGym(
      title: title,
      templateId: templateId,
      planId: planId,
      start: DateTime.now(),
      exercises: exercises.map((e) => e.copy(resetDone: true)).toList(),
    );
    WakelockPlus.enable();
  }

  void _touch() => state = state?.copyWith();

  void rename(String t) => state = state?.copyWith(title: t);

  void addExercise(GymExercise e) {
    state?.exercises.add(e);
    _touch();
  }

  void removeExercise(int i) {
    state?.exercises.removeAt(i);
    _touch();
  }

  void moveExercise(int from, int to) {
    final list = state?.exercises;
    if (list == null) return;
    final e = list.removeAt(from);
    list.insert(to > from ? to - 1 : to, e);
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

  void updateSet(int ex, int set, {double? weight, int? reps, bool? warmup, SetType? type, double? rpe, bool clearRpe = false}) {
    final s = state?.exercises[ex].sets[set];
    if (s == null) return;
    if (weight != null) s.weight = weight;
    if (reps != null) s.reps = reps;
    if (warmup != null) s.warmup = warmup;
    if (type != null) s.type = type;
    if (rpe != null || clearRpe) s.rpe = rpe;
    _touch();
  }

  void setFocus(int i) => state = state?.copyWith(focus: i);

  /// Checks a set off (or un-checks it). Handles rest timers and superset flow:
  /// A1 → A2 → rest → A1 → A2 … (no rest between members of a superset).
  void toggleDone(int ex, int set) {
    final w = state;
    final e = w?.exercises[ex];
    if (w == null || e == null) return;
    final s = e.sets[set];
    s.done = !s.done;
    HapticFeedback.lightImpact();
    if (!s.done) return _touch();

    final group = w.groupOf(ex);
    final pos = group.indexOf(ex);
    // Next member of the superset in this round that still has open sets.
    final laterInRound = group.skip(pos + 1).where((i) => !w.exercises[i].allDone);
    if (group.length > 1 && laterInRound.isNotEmpty) {
      state = w.copyWith(focus: laterInRound.first, clearRest: true);
      return;
    }
    final groupOpen = group.where((i) => !w.exercises[i].allDone);
    final nextFocus = groupOpen.isNotEmpty ? groupOpen.first : (w.nextOpen(group.last + 1) ?? ex);
    final rest = group.map((i) => w.exercises[i].restSec).reduce((a, b) => a > b ? a : b);
    final finishedAll = w.nextOpen() == null;
    if (rest > 0 && !finishedAll && s.type != SetType.drop) {
      state = w.copyWith(focus: nextFocus);
      startRest(rest);
    } else {
      state = w.copyWith(focus: nextFocus);
    }
  }

  /// Links exercise [i] with the next one into a superset, or removes it from its group.
  void toggleSuperset(int i) {
    final list = state?.exercises;
    if (list == null) return;
    final e = list[i];
    if (e.group != null) {
      final g = e.group;
      e.group = null;
      final rest = list.where((x) => x.group == g).toList();
      if (rest.length == 1) rest.first.group = null;
    } else if (i + 1 < list.length) {
      final used = list.map((x) => x.group).whereType<String>().toSet();
      final g = list[i + 1].group ?? 'ABCDEFGHIJ'.split('').firstWhere((c) => !used.contains(c), orElse: () => 'Z');
      e.group = g;
      list[i + 1].group = g;
    }
    _touch();
  }

  void replaceExercise(int i, String exId, String name) {
    final e = state?.exercises[i];
    if (e == null) return;
    e.exId = exId;
    e.name = name;
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
    e.sets.add(GymSet(weight: (last.weight * 0.8 / 2.5).round() * 2.5, reps: last.reps, type: SetType.drop));
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

  void startRest(int seconds) {
    _restTimer?.cancel();
    final end = DateTime.now().add(Duration(seconds: seconds));
    state = state?.copyWith(restEnd: end, restTotal: seconds);
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
