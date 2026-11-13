import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_service.dart';

/// Gym programs in generated plans: a continuous rotation (never the same program twice in a row,
/// over week boundaries, recovery weeks and re-created plans), recovery-aware placement, the
/// program's set counts everywhere, and programs the athlete assigns to weekdays (week A / B).
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'p${n++}';
  final templates = defaultTemplates(id, de: true);
  final start = DateTime(2026, 11, 9); // Monday
  WorkoutTemplate byKey(String k) => templates.firstWhere((t) => t.key == k);
  WorkoutTemplate? byId(String? i) => templates.where((t) => t.id == i).firstOrNull;

  List<PlannedWorkout> gymOf(List<PlannedWorkout> plan) =>
      plan.where((p) => p.sport == Sport.gym).toList()..sort((x, y) => x.date.compareTo(y.date));

  UserProfile profile({
    TrainingFocus focus = TrainingFocus.gym,
    List<int> days = const [1, 3, 5],
    String split = 'auto',
    String equipment = 'gym',
    String level = 'intermediate',
    List<String> goals = const ['strength'],
    String? event,
    Map<String, dynamic> extra = const {},
  }) => UserProfile(
    level: level,
    focus: focus,
    birthYear: DateTime.now().year - 30,
    trainingDays: days,
    goals: goals,
    athlete: AthleteData(
      gymSplit: split,
      equipment: equipment,
      eventDistance: event,
      eventDate: event == null ? null : start.add(const Duration(days: 7 * 14 + 6)),
      raceTimes: level == 'beginner' ? const {} : const {'10k': 50 * 60},
    ).merge(extra),
  );

  /// Muscle groups (≥ 3 work sets) of a program.
  Set<String> groups(WorkoutTemplate t) => {
    for (final e in gymGroupSets(t.exercises).entries)
      if (e.value >= 3) e.key,
  };

  group('continuous rotation', () {
    // Every split / equipment / focus / day count: no program twice in a row over the whole plan,
    // every program of the rotation is used, and the gaps between two sessions of a program stay
    // close to the rotation length (no program forgotten for weeks).
    final cases = <String, UserProfile>{};
    for (final focus in [TrainingFocus.gym, TrainingFocus.hybrid, TrainingFocus.run, TrainingFocus.triathlon]) {
      for (final days in [
        [2, 5],
        [1, 3, 5],
        [1, 3, 5, 6],
        [1, 2, 4, 5, 6],
        [1, 2, 3, 4, 5, 6],
        [1, 2, 3, 4, 5, 6, 7],
      ]) {
        for (final split in ['auto', 'fullbody', 'upperlower', 'ppl', 'ulppl', 'bro']) {
          cases['${focus.name}/${days.length}d/$split'] = profile(focus: focus, days: days, split: split, level: 'advanced');
        }
        for (final eq in ['home', 'bodyweight']) {
          cases['${focus.name}/${days.length}d/$eq'] = profile(focus: focus, days: days, equipment: eq, level: 'advanced');
        }
      }
    }
    cases['hybrid/race/ppl'] = profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6, 7], split: 'ppl', event: 'hm', level: 'advanced');
    cases['beginner/hybrid/ppl'] = profile(focus: TrainingFocus.hybrid, days: [1, 3, 5, 6], split: 'ppl', level: 'beginner');

    test('never the same program twice in a row, every program used, no program forgotten', () {
      var checked = 0;
      for (final e in cases.entries) {
        final p = e.value;
        final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 12);
        final gym = gymOf(plan);
        if (gym.isEmpty) continue;
        checked++;
        final rotation = PlanGenerator.gymKeysFor(p);
        final keys = [for (final g in gym) byId(g.templateId)?.key];
        expect(keys, everyElement(isNotNull), reason: e.key);
        for (var i = 1; i < keys.length; i++) {
          if (rotation.length > 1) expect(keys[i], isNot(keys[i - 1]), reason: '${e.key}: ${gym[i].date} $keys');
        }
        if (gym.length >= rotation.length * 2) expect(keys.toSet(), containsAll(rotation), reason: '${e.key} $keys');
        // The longest gap between two sessions of the same program: ≤ 2 rotations.
        final lastAt = <String, int>{};
        for (var i = 0; i < keys.length; i++) {
          final k = keys[i]!;
          if (lastAt[k] != null) expect(i - lastAt[k]!, lessThanOrEqualTo(rotation.length * 2), reason: '${e.key} $keys');
          lastAt[k] = i;
        }
      }
      expect(checked, greaterThan(100));
    });

    test('gym-only plans follow the split order strictly, across weeks and recovery weeks', () {
      for (final (split, days, rotation) in [
        ('ppl', [1, 3, 5], ['ppl_push', 'ppl_pull', 'ppl_legs']),
        ('ppl', [1, 4], ['ppl_push', 'ppl_pull', 'ppl_legs']),
        ('ppl', [1, 2, 4, 5], ['ppl_push', 'ppl_pull', 'ppl_legs']),
        ('upperlower', [1, 2, 4, 5], splitRotation['upperlower']!),
        ('upperlower', [1, 3, 5], splitRotation['upperlower']!),
        ('fullbody', [1, 3, 5], splitRotation['fullbody']!),
        ('fullbody', [2, 5], ['fb_a', 'fb_b']),
        ('bro', [1, 3, 5], splitRotation['bro']!), // (5 days in a row: arms / shoulders overlap chest and back – reordered)
      ]) {
        final p = profile(days: days, split: split);
        final gym = gymOf(PlanGenerator(l, p, templates, id).generate(start: start, weeks: 10));
        expect(gym.map((g) => g.phase), contains('recovery'), reason: '$split $days');
        final keys = [for (final g in gym) byId(g.templateId)!.key];
        expect(keys, [for (var i = 0; i < keys.length; i++) rotation[i % rotation.length]], reason: '$split $days');
      }
    });

    test('user example: hybrid PPL never repeats Push after Push and keeps the order Push → … → Push', () {
      // Fr Push → (Sa long run, Su rest) → Mo Push was planned before.
      for (final days in [
        [1, 3, 5, 6],
        [1, 2, 3, 5, 6, 7],
        [1, 3, 5, 6, 7],
        [1, 2, 3, 4, 5, 6],
      ]) {
        final p = profile(focus: TrainingFocus.hybrid, days: days, split: 'ppl');
        final gym = gymOf(PlanGenerator(l, p, templates, id).generate(start: start, weeks: 12));
        final keys = [for (final g in gym) byId(g.templateId)!.key];
        for (var i = 1; i < keys.length; i++) {
          expect(keys[i], isNot(keys[i - 1]), reason: '$days $keys');
        }
        // Three gym days a week: each program exactly once a week.
        if (gym.length == 12 * 3) {
          for (var w = 0; w < 12; w++) {
            expect(keys.sublist(w * 3, w * 3 + 3).toSet(), hasLength(3), reason: '$days week $w $keys');
          }
        }
      }
    });
  });

  group('recovery-aware placement', () {
    test('no overlapping muscle groups on consecutive days when the split allows it', () {
      for (final (split, days) in [
        ('ppl', [1, 2, 3, 4, 5, 6]),
        ('ppl', [1, 2, 3]),
        ('upperlower', [1, 2, 4, 5]),
        ('upperlower', [1, 2, 3, 4]),
        // (Bro split on consecutive days cannot avoid it: arms and shoulders share muscles with chest and back.)
        ('ulppl', [1, 2, 3, 4, 5]),
      ]) {
        for (final focus in [TrainingFocus.gym, TrainingFocus.hybrid]) {
          final p = profile(focus: focus, days: focus == TrainingFocus.gym ? days : [...days, 7], split: split, level: 'advanced');
          final gym = gymOf(PlanGenerator(l, p, templates, id).generate(start: start, weeks: 10));
          for (var i = 1; i < gym.length; i++) {
            if (daysBetween(gym[i - 1].date, gym[i].date) != 1) continue;
            final a = groups(byId(gym[i - 1].templateId)!), b = groups(byId(gym[i].templateId)!);
            expect(a.intersection(b), isEmpty, reason: '$split $focus ${gym[i - 1].title} ${gym[i].date} ${gym[i].title}');
          }
        }
      }
    });

    test('hybrid PPL with three gym days: legs never the day before a key run after the first week', () {
      final p = profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6, 7], split: 'ppl');
      final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 12);
      final hard = {
        for (final w in plan)
          if (w.sport == Sport.run && (w.isKey || w.intensity == 'long' || w.intensity == 'tempo' || w.intensity == 'intervals'))
            dayKey(w.date),
      };
      for (final g in gymOf(plan)) {
        if (byId(g.templateId)!.key != 'ppl_legs') continue;
        expect(hard.contains(dayKey(addDays(g.date, 1))), isFalse, reason: '${g.date}');
      }
    });

    test('race week: no leg-heavy program, leg exercises stripped by reference', () {
      final p = profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6, 7], split: 'ppl', event: 'hm');
      final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 15);
      final race = plan.firstWhere((w) => w.intensity == 'race').date;
      for (final g in gymOf(plan).where((g) => daysBetween(g.date, race) <= 10 && !g.date.isAfter(race))) {
        final t = byId(g.templateId)!;
        expect(legHeavyProgram(t), isFalse, reason: '${g.date} ${g.title}');
        final ex = plannedGymExercises(g, t);
        expect(ex.any((e) => classifyLift(e.exId, e.name).lower), isFalse, reason: '${g.date} ${g.title}');
      }
    });
  });

  group('set counts come from the program', () {
    test('plan workouts reference the program; sets never change (deload, taper, fill)', () {
      final prescriber = LoadPrescriber(history: const [], profile: profile());
      for (final p in [
        profile(days: [1, 3, 5], split: 'ppl'),
        profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6, 7], split: 'ppl', event: 'hm'),
        profile(focus: TrainingFocus.hybrid, days: [1, 3, 5, 6], level: 'beginner'),
        profile(days: [1, 2, 4, 5], split: 'upperlower', level: 'advanced', extra: {'sessionMinutes': 120}),
      ]) {
        final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 16);
        final gym = gymOf(plan);
        expect(gym.map((g) => g.phase).toSet(), contains('recovery'));
        for (final g in gym) {
          expect(g.exercises, isEmpty, reason: '${g.date} ${g.title}: no copied (and changed) exercises');
          final t = byId(g.templateId)!;
          final ex = plannedGymExercises(g, t);
          // Same sets per exercise as the program (regressions swap the exercise, not its sets).
          final program = applyGymMods(t.exercises, g.gymMods.where((m) => m == gymModNoLegs).toList());
          expect([for (final e in ex) e.workSets.length], [for (final e in program) e.workSets.length], reason: '${g.date} ${g.title}');
          // Tracker prefill / mark as done keep them, also in recovery and taper weeks.
          final applied = prescriber.apply(ex, phase: g.phase);
          expect([for (final e in applied) e.workSets.length], [for (final e in program) e.workSets.length], reason: '${g.phase}');
          final fill = PlanFill.of(g, profile: p, templates: templates, prescriber: prescriber);
          expect(fill.plannedSets, program.fold<int>(0, (a, e) => a + e.workSets.length), reason: '${g.date} ${g.phase}');
          expect(g.description, isNot(contains(l.wGymLegsHalvedNote)));
          expect(g.description, isNot(contains(l.wGymDeloadNote3)));
          if (g.phase == 'recovery' && !g.description.contains(l.wGymTaperNote)) expect(g.description, contains(l.wGymDeloadNote5));
        }
      }
    });

    test('an edited program shows up in the plan (sets and exercises)', () {
      final p = profile(days: [1, 3, 5], split: 'ppl');
      final own = defaultTemplates(id, de: true);
      final plan = PlanGenerator(l, p, own, id).generate(start: start, weeks: 4);
      final pull = gymOf(plan).firstWhere((g) => own.firstWhere((t) => t.id == g.templateId).key == 'ppl_pull');
      final t = own.firstWhere((t) => t.id == pull.templateId);
      // The athlete edits the program after the plan was made: 3 × hammer curls → 2.
      final edited = WorkoutTemplate.fromMap(t.id, {
        ...t.toMap(),
        'exercises': [
          for (final e in t.exercises) {...e.toMap(), 'sets': e.sets.take(2).map((s) => s.toMap()).toList()},
        ],
      });
      expect(plannedGymExercises(pull, edited).every((e) => e.workSets.length == 2), isTrue);
    });

    test('beginner regression is a reference too and keeps the set count', () {
      final p = profile(days: [1, 3, 5], split: 'ppl', level: 'beginner');
      final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 8);
      final pull = gymOf(plan).firstWhere((g) => byId(g.templateId)!.key == 'ppl_pull');
      expect(pull.gymMods, contains(gymModRegress));
      final t = byId(pull.templateId)!;
      final ex = plannedGymExercises(pull, t);
      expect(ex.map((e) => e.exId), isNot(contains('0652'))); // pull-up → lat pulldown
      expect([for (final e in ex) e.workSets.length], [for (final e in t.exercises) e.workSets.length]);
      final late = gymOf(plan).lastWhere((g) => byId(g.templateId)!.key == 'ppl_pull');
      expect(late.gymMods, isNot(contains(gymModRegress)));
    });

    test('stored gym mods round-trip and old documents without them still load', () {
      final w = PlannedWorkout(id: 'x', date: start, sport: Sport.gym, title: 'Pull', gymMods: const [gymModRegress]);
      expect(PlannedWorkout.fromMap('x', w.toMap()).gymMods, [gymModRegress]);
      final old = PlannedWorkout.fromMap('y', {'date': '2026-11-09', 'sport': 'gym', 'title': 'Pull', 'exercises': []});
      expect(old.gymMods, isEmpty);
    });
  });

  group('rotation continues across re-created plans', () {
    test('after Push the new plan starts with Pull, after Pull with Legs', () {
      final p = profile(days: [1, 3, 5], split: 'ppl');
      for (final (last, first) in [('ppl_push', 'ppl_pull'), ('ppl_pull', 'ppl_legs'), ('ppl_legs', 'ppl_push')]) {
        final plan = PlanGenerator(
          l,
          p,
          templates,
          id,
        ).generate(start: start, weeks: 2, gymHistory: [(addDays(start, -3), byKey(last).id)]);
        expect(byId(gymOf(plan).first.templateId)!.key, first, reason: last);
      }
    });

    test('history comes from done sessions and done plan workouts before the day', () {
      final push = byKey('ppl_push'), pull = byKey('ppl_pull');
      final sessions = [
        Session(id: 's', sport: Sport.gym, title: 'Push', start: addDays(start, -5), durationSec: 3600, templateId: push.id),
      ];
      final plans = [
        PlannedWorkout(id: 'a', date: addDays(start, -3), sport: Sport.gym, title: 'Pull', templateId: pull.id, status: 'done'),
        PlannedWorkout(id: 'b', date: addDays(start, -1), sport: Sport.gym, title: 'Beine', templateId: byKey('ppl_legs').id),
        PlannedWorkout(id: 'c', date: addDays(start, 1), sport: Sport.gym, title: 'Push', templateId: push.id, status: 'done'),
      ];
      final h = PlanService.gymHistory(plans, sessions, start);
      expect(h.map((e) => e.$2), [push.id, pull.id]); // the missed legs day and later days don't count
      final plan = PlanGenerator(l, profile(days: [1, 3, 5], split: 'ppl'), templates, id).generate(start: start, weeks: 1, gymHistory: h);
      expect(byId(gymOf(plan).first.templateId)!.key, 'ppl_legs');
    });
  });

  group('programs assigned to weekdays', () {
    final push = byKey('ppl_push'), pull = byKey('ppl_pull'), legs = byKey('ppl_legs');
    final own = WorkoutTemplate(
      id: 'mine',
      name: 'Mein Oberkörper',
      sport: Sport.gym,
      exercises: [for (final e in byKey('ul_upper_a').exercises) e.copy()],
    );
    final all = [...templates, own];

    test('the plan uses exactly the assigned programs, week A / week B alternating incl. recovery weeks', () {
      final p = profile(
        days: [1, 3, 5],
        split: 'fullbody',
        extra: {
          'gymAssign': true,
          'gymAB': true,
          'gymPlanA': {1: gymProgramRef(push), 3: gymProgramRef(pull), 5: gymProgramRef(legs)},
          'gymPlanB': {1: gymProgramRef(pull), 3: gymProgramRef(own), 5: gymProgramRef(push)},
        },
      );
      expect(PlanGenerator.gymKeysFor(p), containsAll(['ppl_push', 'ppl_pull', 'ppl_legs']));
      final plan = PlanGenerator(l, p, all, id).generate(start: start, weeks: 8);
      final gym = gymOf(plan);
      expect(gym.map((g) => g.phase), contains('recovery'));
      for (final g in gym) {
        final w = daysBetween(start, g.date) ~/ 7;
        final want = (w.isEven ? {1: push, 3: pull, 5: legs} : {1: pull, 3: own, 5: push})[g.date.weekday]!;
        expect(g.templateId, want.id, reason: '${g.date} week $w');
        expect(g.title, want.name);
      }
      // Load / RIR periodisation still applies.
      expect(gym.where((g) => g.phase == 'recovery').every((g) => g.description.contains(l.wGymDeloadNote5)), isTrue);
    });

    test('without A/B week A every week; unassigned or deleted programs fall back to the rotation', () {
      final p = profile(
        days: [1, 3, 5],
        split: 'ppl',
        extra: {
          'gymAssign': true,
          'gymPlanA': {1: gymProgramRef(legs), 3: 'id:deleted'},
          'gymPlanB': {1: gymProgramRef(push)},
        },
      );
      final gym = gymOf(PlanGenerator(l, p, templates, id).generate(start: start, weeks: 4));
      for (final g in gym.where((g) => g.date.weekday == 1)) {
        expect(g.templateId, legs.id);
      }
      final keys = [for (final g in gym) byId(g.templateId)!.key];
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i], isNot(keys[i - 1]), reason: '$keys');
      }
    });

    test('switched off: the rotation is used', () {
      final p = profile(
        days: [1, 3, 5],
        split: 'ppl',
        extra: {
          'gymAssign': false,
          'gymPlanA': {1: gymProgramRef(legs), 3: gymProgramRef(legs), 5: gymProgramRef(legs)},
        },
      );
      final keys = [for (final g in gymOf(PlanGenerator(l, p, templates, id).generate(start: start, weeks: 2))) byId(g.templateId)!.key];
      expect(keys.take(3), ['ppl_push', 'ppl_pull', 'ppl_legs']);
    });

    test('a re-created plan continues the A/B alternation', () {
      final p = profile(
        days: [1, 3, 5],
        split: 'ppl',
        extra: {
          'gymAssign': true,
          'gymAB': true,
          'gymPlanA': {1: gymProgramRef(push), 3: gymProgramRef(pull), 5: gymProgramRef(legs)},
          'gymPlanB': {1: gymProgramRef(legs), 3: gymProgramRef(push), 5: gymProgramRef(pull)},
        },
      );
      // Last week was week A → the new plan starts with week B.
      final hist = [(addDays(start, -7), push.id), (addDays(start, -5), pull.id), (addDays(start, -3), legs.id)];
      final gym = gymOf(PlanGenerator(l, p, templates, id).generate(start: start, weeks: 2, gymHistory: hist));
      expect(gym.first.templateId, legs.id);
      expect(gym[3].templateId, push.id);
    });

    test('assigned programs persist in the profile', () {
      final a = const AthleteData().merge({
        'gymAssign': true,
        'gymAB': true,
        'gymPlanA': {1: 'key:ppl_push'},
        'gymPlanB': <int, String>{3: 'id:abc'},
      });
      final back = AthleteData.fromMap(a.toMap());
      expect(back.gymAssign, isTrue);
      expect(back.gymAB, isTrue);
      expect(back.gymPlanA, {1: 'key:ppl_push'});
      expect(back.gymPlanB, {3: 'id:abc'});
      expect(AthleteData.fromMap(const {}).gymPlanA, isEmpty);
    });

    test('suggestion: the generator\'s programs of the first two weeks', () {
      final s = PlanGenerator.suggestedGymWeeks(profile(days: [1, 3, 5], split: 'ppl'), templates);
      expect(s.a, {1: 'key:ppl_push', 3: 'key:ppl_pull', 5: 'key:ppl_legs'});
      expect(s.b, {1: 'key:ppl_push', 3: 'key:ppl_pull', 5: 'key:ppl_legs'});
      final s2 = PlanGenerator.suggestedGymWeeks(profile(days: [1, 4], split: 'ppl'), templates);
      expect(s2.a, {1: 'key:ppl_push', 4: 'key:ppl_pull'});
      expect(s2.b, {1: 'key:ppl_legs', 4: 'key:ppl_push'});
    });
  });
}
