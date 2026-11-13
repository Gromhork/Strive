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
/// into a reference again: `exercises` cleared, the adaptations stored as [PlannedWorkout.gymMods]
/// (set counts are ignored – they are what changed). Anything else (other exercises, another order:
/// the athlete's own edits) stays as it is.
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
      if (r != null) {
        if (s.exId == r.$1) {
          regressed = true;
        } else {
          unregressed = true;
        }
      }
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

  static final _halvedNotes = _texts((l) => l.wGymLegsHalvedNote);
  static final _easyNotes = _texts((l) => l.wGymLegsEasyNote);
  static final _raceNotes = _texts((l) => l.wGymRaceWeekNote);

  /// A plan text in both app languages (stored plans keep the language they were made in).
  static List<String> _texts(String Function(AppLocalizations) key) => [
    for (final lang in const ['en', 'de']) key(lookupAppLocalizations(Locale(lang))),
  ];
}
