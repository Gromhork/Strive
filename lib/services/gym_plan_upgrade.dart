import 'dart:math';
import 'dart:ui';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'exercise_class.dart';
import 'plan_exercises.dart';

/// One-off upgrade of the gym workouts of stored plans to the current format (review r7 R4).
///
/// Plans generated before the plan referenced its programs stored frozen copies of the program's
/// exercises ([PlannedWorkout.exercises]) with the generator's adaptations baked in: one extra work
/// set per exercise when time was left, half the leg sets the day before a key endurance session,
/// the beginner regressions, and no leg exercises in race week. Those workouts kept showing and
/// starting the old set counts, ignored later program edits and opened as "adjusted for this day"
/// in the plan editor – although the plan now always uses the program's sets.
///
/// A future, not done generated workout whose copies are the program's exercises in the program's
/// order – possibly regressed ([gymRegressions]) or without the lower-body exercises – is turned
/// into a reference again: `exercises` cleared, the adaptations stored as [PlannedWorkout.gymMods].
/// Each copy must be the program's exercise as the old generator left it ([_sameContent]): the
/// same rep range, rest, note and set values, only work sets dropped from the end (halved leg
/// sets) or copies of the last one added (time fill), a regression with its own rep range. Anything
/// else (other exercises, another order, other reps / weights / rest / notes: the athlete's own
/// edits of the day – or of the program since) stays as it is: nothing the athlete typed is lost.
///
/// The load adaptations its notes promise are added as mods too – also to workouts already in the
/// new format (plans generated before the load followed them): "legs lighter / half the leg sets
/// before a key session" → [gymModLegsEasy] (the halved-sets note becomes the lighter-legs note),
/// the race-week note → [gymModRaceWeek] (and [gymModNoLegs] when the program has legs to drop).
///
/// Idempotent: an upgraded workout produces no further update.
class GymPlanUpgrade {
  GymPlanUpgrade._();

  /// Plan id → fields to update (`exercises`, `gymMods`, `description`, `durationMin`); empty when
  /// nothing needs an upgrade. Only workouts dated [today] or later.
  static Map<String, Map<String, dynamic>> updates(List<PlannedWorkout> plans, List<WorkoutTemplate> templates, {required DateTime today}) {
    final out = <String, Map<String, dynamic>>{};
    final day = dayOnly(today);
    for (final p in plans) {
      if (p.sport != Sport.gym || p.phase == null || p.status != 'planned' || dayOnly(p.date).isBefore(day)) continue;
      final t = templates.where((t) => t.id == p.templateId && t.sport == Sport.gym).firstOrNull;
      if (t == null) continue;
      final u = upgrade(p, t);
      if (u.isNotEmpty) out[p.id] = u;
    }
    return out;
  }

  /// The update of workout [p] of program [t] (empty: nothing to change).
  static Map<String, dynamic> upgrade(PlannedWorkout p, WorkoutTemplate t) {
    final mods = [...p.gymMods];
    final m = <String, dynamic>{};
    var lines = p.description.isEmpty ? <String>[] : p.description.split('\n');
    if (p.exercises.isNotEmpty) {
      final derived = _modsOf(p.exercises, t.exercises);
      if (derived == null) return const {}; // the athlete's own exercises for this day
      for (final x in derived) {
        if (!mods.contains(x)) mods.add(x);
      }
      m['exercises'] = const <Map<String, dynamic>>[];
    }
    // The notes' load promises.
    final halved = _halvedNotes, easy = _easyNotes;
    if (lines.any(halved.contains)) {
      lines = [for (final x in lines) halved.contains(x) ? easy[halved.indexOf(x)] : x];
      m['description'] = lines.join('\n');
    }
    if (lines.any(easy.contains) && !mods.contains(gymModLegsEasy)) mods.add(gymModLegsEasy);
    if (lines.any(_raceNotes.contains)) {
      if (!mods.contains(gymModRaceWeek)) mods.add(gymModRaceWeek);
      if (!mods.contains(gymModNoLegs) && gymModApplies(gymModNoLegs, t.exercises)) mods.add(gymModNoLegs);
    }
    if (mods.length != p.gymMods.length) m['gymMods'] = mods;
    if (m.isEmpty) return const {};
    if (m.containsKey('exercises') || mods.contains(gymModNoLegs) != p.gymMods.contains(gymModNoLegs)) {
      final ex = applyGymMods(t.exercises, mods);
      if (ex.isNotEmpty) m['durationMin'] = estimateGymMinutes(ex);
    }
    return m;
  }

  /// The day adaptations that turn the program's [program] exercises into the stored copies
  /// [stored] (exercise ids in program order, set counts ignored), or null when they are no such
  /// copies.
  static List<String>? _modsOf(List<GymExercise> stored, List<GymExercise> program) {
    var j = 0, regressed = false, unregressed = false, dropped = false;
    for (final s in stored) {
      // Lower-body exercises of the program the copy left out (race week).
      while (j < program.length && !_same(s, program[j]) && classifyLift(program[j].exId, program[j].name).lower) {
        dropped = true;
        j++;
      }
      if (j >= program.length || !_same(s, program[j])) return null;
      final r = gymRegressions[program[j].exId];
      final isRegression = r != null && s.exId == r.$1;
      if (r != null) {
        if (isRegression) {
          regressed = true;
        } else {
          unregressed = true;
        }
      }
      if (!_sameContent(s, program[j], regressed: isRegression)) return null;
      j++;
    }
    for (; j < program.length; j++) {
      if (!classifyLift(program[j].exId, program[j].name).lower) return null;
      dropped = true;
    }
    // Regressions were all or none; without legs means without any leg exercise.
    if (regressed && unregressed) return null;
    if (dropped && stored.any((e) => classifyLift(e.exId, e.name).lower)) return null;
    if (dropped && stored.isEmpty) return null;
    return [if (regressed) gymModRegress, if (dropped) gymModNoLegs];
  }

  /// [s] is [p] or its beginner regression.
  static bool _same(GymExercise s, GymExercise p) => s.exId == p.exId || gymRegressions[p.exId]?.$1 == s.exId;

  /// Stored copy [s] is program exercise [p] with only the old generator's changes (review r7 R4:
  /// a day whose rep range and note the athlete had changed was reset to the program): the same
  /// note, superset group, mode and hold range; the same rep range and rest – for a regression
  /// ([regressed], [regressedExercise]) the rest capped at 120 s and every work set at the bottom
  /// of its own range; the same warm-ups; the work sets a prefix of the program's (half the leg
  /// sets) or the program's plus copies of its last one (time fill), with the same values.
  static bool _sameContent(GymExercise s, GymExercise p, {required bool regressed}) {
    if (s.note != p.note || s.group != p.group || s.timed != p.timed || s.holdMin != p.holdMin || s.holdMax != p.holdMax) return false;
    if (regressed) {
      if (s.restSec != min(p.restSec, 120) || s.bw != null) return false;
    } else if (s.repMin != p.repMin || s.repMax != p.repMax || s.restSec != p.restSec || s.bw != p.bw) {
      return false;
    }
    final sw = s.workSets, pw = p.workSets, su = s.sets.where((x) => x.warmup).toList(), pu = p.sets.where((x) => x.warmup).toList();
    if (!_setsEqual(su, pu) || sw.isEmpty != pw.isEmpty) return false;
    for (var i = 0; i < sw.length; i++) {
      final q = pw[min(i, pw.length - 1)];
      if (!_setEqual(sw[i], q, reps: !regressed)) return false;
      if (regressed && sw[i].reps != (s.repMin ?? sw[i].reps)) return false;
    }
    return true;
  }

  static bool _setsEqual(List<GymSet> a, List<GymSet> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_setEqual(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _setEqual(GymSet a, GymSet b, {bool reps = true}) =>
      (a.weight - b.weight).abs() < 1e-6 &&
      (!reps || a.reps == b.reps) &&
      a.sec == b.sec &&
      a.type == b.type &&
      a.rpe == b.rpe &&
      a.target == b.target &&
      a.targetSec == b.targetSec;

  static final _halvedNotes = _texts((l) => l.wGymLegsHalvedNote);
  static final _easyNotes = _texts((l) => l.wGymLegsEasyNote);
  static final _raceNotes = _texts((l) => l.wGymRaceWeekNote);

  /// A plan text in both app languages (stored plans keep the language they were made in).
  static List<String> _texts(String Function(AppLocalizations) key) => [
    for (final lang in const ['en', 'de']) key(lookupAppLocalizations(Locale(lang))),
  ];
}
