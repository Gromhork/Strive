import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/gym_plan_upgrade.dart';
import 'package:strive/services/gym_tools.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/widgets/prescription.dart';

/// Review r7, package F1 (gym plan generation and load prescription): health notes keep the day
/// adaptations (R1), no program starved or doubled by the rotation (S1 / S4), the load the notes
/// promise is the load prescribed (R3 / S2 / S3 / S5 / S9), old plans upgraded (R4).
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));
  var n = 0;
  String id() => 'p${n++}';
  final templates = defaultTemplates(id, de: true);
  final start = DateTime(2026, 11, 9); // Monday
  WorkoutTemplate byKey(String k) => templates.firstWhere((t) => t.key == k);
  WorkoutTemplate? byId(String? i) => templates.where((t) => t.id == i).firstOrNull;
  List<PlannedWorkout> gymOf(List<PlannedWorkout> plan) =>
      plan.where((p) => p.sport == Sport.gym).toList()..sort((x, y) => x.date.compareTo(y.date));
  bool hasLine(PlannedWorkout w, String line) => w.description.split('\n').contains(line);

  UserProfile profile({
    TrainingFocus focus = TrainingFocus.gym,
    List<int> days = const [1, 3, 5],
    String split = 'auto',
    String level = 'intermediate',
    String? event,
    List<String> limitations = const [],
    Map<int, List<Sport>> dayPlan = const {},
  }) => UserProfile(
    level: level,
    focus: focus,
    birthYear: DateTime.now().year - 30,
    weightKg: 80,
    gender: 'm',
    trainingDays: days,
    goals: const ['strength'],
    athlete: AthleteData(
      gymSplit: split,
      eventDistance: event,
      eventDate: event == null ? null : addDays(start, 7 * 9 + 6),
      raceTimes: level == 'beginner' ? const {} : const {'10k': 50 * 60},
      limitations: limitations,
      setupMode: dayPlan.isEmpty ? 'simple' : 'advanced',
      dayPlan: dayPlan,
    ),
  );

  group('R1: health notes keep the gym day adaptations', () {
    test('copyWith keeps every field (also gymMods and auto)', () {
      final w = PlannedWorkout(
        id: 'x',
        date: start,
        sport: Sport.gym,
        title: 'Pull',
        description: 'a',
        durationMin: 50,
        templateId: 't',
        status: 'planned',
        phase: 'build',
        isKey: true,
        exercises: [GymExercise(exId: '0652', name: 'pull-up')],
        gymMods: const [gymModRegress, gymModLegsEasy],
        auto: AutoAdjustment(sessionId: 's', reason: 'longHard', at: start, durationMin: 40),
      );
      final c = w.copyWith(description: 'b');
      expect({...c.toMap(), 'description': 'a'}, w.toMap());
      expect(c.description, 'b');
      expect(w.copyWith(clearAuto: true).auto, isNull);
    });

    test('limitations × beginner regressions and race week: the mods match the notes', () {
      for (final lim in [
        const <String>[],
        ['back'],
        ['knee'],
        ['back', 'knee'],
        ['heart', 'shoulder'],
      ]) {
        final beginner = gymOf(
          PlanGenerator(de, profile(days: [1, 3, 5], level: 'beginner', limitations: lim), templates, id).generate(start: start, weeks: 8),
        );
        final regressed = beginner.where((g) => g.gymMods.contains(gymModRegress)).toList();
        expect(regressed, isNotEmpty, reason: '$lim');
        final hybrid = gymOf(
          PlanGenerator(
            de,
            profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6, 7], split: 'ppl', event: '10k', limitations: lim),
            templates,
            id,
          ).generate(start: start, weeks: 10),
        );
        final raceWeek = hybrid.where((g) => hasLine(g, de.wGymRaceWeekNote)).toList();
        expect(raceWeek, isNotEmpty, reason: '$lim');
        for (final g in [...beginner, ...hybrid]) {
          final why = '$lim ${g.date} ${g.title} ${g.gymMods}';
          expect(hasLine(g, de.wGymRegressionNote), g.gymMods.contains(gymModRegress), reason: why);
          expect(hasLine(g, de.wGymRaceWeekNote), g.gymMods.contains(gymModRaceWeek), reason: why);
          expect(hasLine(g, de.wGymLegsEasyNote), g.gymMods.contains(gymModLegsEasy), reason: why);
          // Race week: no leg exercise is shown or started (the program has upper-body work).
          if (g.gymMods.contains(gymModRaceWeek)) {
            final ex = plannedGymExercises(g, byId(g.templateId));
            expect(ex.any((e) => classifyLift(e.exId, e.name).lower), isFalse, reason: why);
          }
          if (g.gymMods.contains(gymModRegress)) {
            expect(plannedGymExercises(g, byId(g.templateId)).map((e) => e.exId), isNot(contains('0032')), reason: why);
          }
        }
      }
    });
  });

  group('S1 / S4: every program about equally often, none starved', () {
    // Counts over the plan, the longest gap between two sessions of a program incl. the leading and
    // trailing one.
    void checkBalance(String name, UserProfile p, {int weeks = 12}) {
      final gym = gymOf(PlanGenerator(de, p, templates, id).generate(start: start, weeks: weeks));
      final rotation = PlanGenerator.gymKeysFor(p);
      final keys = [for (final g in gym) byId(g.templateId)!.key!];
      final counts = {for (final k in rotation) k: keys.where((x) => x == k).length};
      final why = '$name $counts $keys';
      expect(counts.values.reduce((a, b) => a < b ? a : b), greaterThan(0), reason: why);
      expect(
        counts.values.reduce((a, b) => a > b ? a : b) / counts.values.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1.5),
        reason: why,
      );
      for (final k in rotation) {
        var lastAt = -1;
        for (var i = 0; i <= keys.length; i++) {
          if (i == keys.length || keys[i] == k) {
            final gap = i - lastAt;
            expect(gap, lessThanOrEqualTo(rotation.length + 1), reason: '$why: $k gap $gap at $i');
            lastAt = i;
          }
        }
      }
    }

    test('bro and UL/PPL splits on 4–7 consecutive days (gym only)', () {
      for (final split in ['bro', 'ulppl', 'ppl', 'upperlower']) {
        for (final days in [
          [1, 2, 3, 4],
          [1, 2, 3, 4, 5],
          [1, 2, 3, 4, 5, 6],
          [1, 2, 3, 4, 5, 6, 7],
        ]) {
          checkBalance('$split $days', profile(days: days, split: split, level: 'advanced'));
        }
      }
    });

    test('user example: bro split Mon–Fri trains Back every week', () {
      final gym = gymOf(PlanGenerator(de, profile(days: [1, 2, 3, 4, 5], split: 'bro'), templates, id).generate(start: start, weeks: 12));
      for (var w = 0; w < 12; w++) {
        final week = gym.where((g) => daysBetween(start, g.date) ~/ 7 == w).map((g) => byId(g.templateId)!.key).toSet();
        expect(week, containsAll(splitRotation['bro']!), reason: 'week $w $week');
      }
    });

    test('hybrid UL / PPL: legs as often as the upper body; UL: no week without legs', () {
      for (final (name, p) in [
        (
          'UL Tue/Fri before key runs',
          profile(
            focus: TrainingFocus.hybrid,
            days: [1, 2, 3, 5, 6],
            split: 'upperlower',
            dayPlan: {
              1: [Sport.run],
              2: [Sport.gym],
              3: [Sport.run],
              5: [Sport.gym],
              6: [Sport.run],
            },
          ),
        ),
        ('UL 5 days', profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6], split: 'upperlower')),
        ('UL 6 days', profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 4, 5, 6], split: 'upperlower')),
        ('PPL 6 days', profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 4, 5, 6], split: 'ppl')),
        ('PPL 4 days', profile(focus: TrainingFocus.hybrid, days: [1, 3, 5, 6], split: 'ppl')),
      ]) {
        checkBalance(name, p);
        // Upper / lower: the leg day alternates with the upper-body day, so every week of two sessions has one.
        if (!name.startsWith('UL')) continue;
        final gym = gymOf(PlanGenerator(de, p, templates, id).generate(start: start, weeks: 12));
        final weeks = {for (final g in gym) daysBetween(start, g.date) ~/ 7};
        for (final w in weeks) {
          final week = gym.where((g) => daysBetween(start, g.date) ~/ 7 == w).toList();
          if (week.length < 2) continue;
          expect(week.any((g) => legHeavyProgram(byId(g.templateId)!)), isTrue, reason: '$name week $w ${week.map((g) => g.title)}');
        }
      }
    });
  });

  group('R3 / S2 / S3: the load the notes promise', () {
    final now = DateTime(2026, 11, 20, 18);
    final p80 = profile();
    GymExercise ex(String exId, String name, double kg, int reps, {int sets = 3, bool done = true}) => GymExercise(
      exId: exId,
      name: name,
      sets: [for (var i = 0; i < sets; i++) GymSet(weight: kg, reps: reps, done: done, target: reps)],
    );
    Session session(int daysAgo, List<GymExercise> list) => Session(
      id: 's$daysAgo',
      sport: Sport.gym,
      title: 'Gym',
      start: now.subtract(Duration(days: daysAgo)),
      durationSec: 3600,
      exercises: list,
    );
    final history = [
      session(3, [ex('0043', 'barbell full squat', 100, 8), ex('0025', 'barbell bench press', 80, 8)]),
      session(10, [ex('0043', 'barbell full squat', 97.5, 8), ex('0025', 'barbell bench press', 77.5, 8)]),
      session(17, [ex('0043', 'barbell full squat', 95, 8), ex('0025', 'barbell bench press', 75, 8)]),
    ];
    final rx = LoadPrescriber(history: history, profile: p80, now: now);
    final squat = GymExercise(exId: '0043', name: 'barbell full squat', sets: [GymSet(reps: 8), GymSet(reps: 8), GymSet(reps: 8)]);
    final bench = GymExercise(exId: '0025', name: 'barbell bench press', sets: [GymSet(reps: 8), GymSet(reps: 8), GymSet(reps: 8)]);

    test('legs before a key session: lower-body lifts ~12 % lighter, no AMRAP, no step up; upper body unchanged', () {
      final base = rx.forExercise(squat)!;
      final easy = rx.forExercise(squat, phase: 'legsEasy')!;
      expect(easy.weight, lessThanOrEqualTo(base.weight * 0.9));
      expect(easy.weight, greaterThanOrEqualTo(base.weight * 0.85 - 2.5));
      expect(easy.amrap, isFalse);
      expect(easy.progression, isNot(ProgressionKind.increase));
      expect(easy.phaseAdjusted, isTrue);
      expect(prescriptionReason(de, easy), contains(de.loadLegsEasyLighter));
      final b = rx.forExercise(bench)!, bEasy = rx.forExercise(bench, phase: 'legsEasy')!;
      expect(bEasy.weight, b.weight);
      expect(bEasy.amrap, b.amrap);
      // Tracker prefill tags only the lighter exercises (no progression anchor).
      final applied = rx.apply([squat, bench], phase: 'legsEasy');
      expect(applied[0].phase, 'legsEasy');
      expect(applied[1].phase, isNull);
      expect(applied[0].workSets.first.weight, easy.weight);
      expect(applied[0].workSets.any((s) => s.amrap), isFalse);
    });

    test('race window in a loading week: ~10 % lighter like the taper, no AMRAP', () {
      final base = rx.forExercise(bench)!;
      final race = rx.forExercise(bench, phase: 'race')!;
      expect(race.weight, lessThanOrEqualTo(base.weight * 0.9 + 1e-9));
      expect(race.amrap, isFalse);
      expect(prescriptionReason(en, race), contains(en.loadRaceLighter));
    });

    test('generated plans: the workout\'s load phase follows its notes – planned page, start, mark as done', () {
      // (A 10 km race: the 10-day race window starts in the peak week, before the short taper.)
      final p = profile(focus: TrainingFocus.hybrid, days: [1, 2, 3, 5, 6], event: '10k');
      final plan = gymOf(PlanGenerator(de, p, templates, id).generate(start: start, weeks: 10));
      final easyDays = plan.where((g) => hasLine(g, de.wGymLegsEasyNote) && g.phase != 'recovery' && g.phase != 'taper').toList();
      final raceDays = plan.where((g) => hasLine(g, de.wGymRaceWeekNote) && g.phase != 'taper').toList();
      expect(easyDays, isNotEmpty);
      expect(raceDays, isNotEmpty);
      for (final g in easyDays) {
        expect(gymLoadPhase(g), 'legsEasy', reason: '${g.date}');
      }
      for (final g in raceDays) {
        expect(gymLoadPhase(g), 'race', reason: '${g.date} ${g.phase}');
      }
      // Every workout whose note says "lighter" is lighter.
      for (final g in plan.where((g) => hasLine(g, de.wGymTaperNote) || hasLine(g, de.wGymDeloadNote5))) {
        expect(LoadPrescriber.lighterPhase(gymLoadPhase(g)), isTrue, reason: '${g.date} ${g.phase} ${g.gymMods}');
      }
      // The session's plan id resolves to the same load phase (tracker, exercise focus page).
      expect(planPhaseOf(plan, easyDays.first.id), 'legsEasy');
      // "Mark as done" prefills the lighter loads.
      final g = easyDays.firstWhere((g) => plannedGymExercises(g, byId(g.templateId)).any((e) => classifyLift(e.exId, e.name).lower));
      final fill = PlanFill.of(g, profile: p, templates: templates, prescriber: LoadPrescriber(history: const [], profile: p));
      final loaded = PlanFill.of(
        g.copyWith(gymMods: const []),
        profile: p,
        templates: templates,
        prescriber: LoadPrescriber(history: const [], profile: p),
      );
      for (var i = 0; i < fill.exercises.length; i++) {
        final e = fill.exercises[i];
        final lower = classifyLift(e.exId, e.name).lower;
        final w = e.workSets.first.weight, w0 = loaded.exercises[i].workSets.first.weight;
        if (lower && w0 > 0) expect(w, lessThan(w0), reason: e.name);
        if (!lower) expect(w, w0, reason: e.name);
      }
    });
  });

  group('same class: exercises swapped during a planned workout keep its load phase', () {
    test('replacing an exercise in a deload-week workout prescribes the deload load', () async {
      final now = DateTime.now();
      final hist = [
        for (final d in [3, 10, 17])
          Session(
            id: 'h$d',
            sport: Sport.gym,
            title: 'Gym',
            start: now.subtract(Duration(days: d)),
            durationSec: 3600,
            exercises: [
              GymExercise(
                exId: '0025',
                name: 'barbell bench press',
                sets: [for (var i = 0; i < 3; i++) GymSet(weight: 80, reps: 8, done: true, target: 8)],
              ),
            ],
          ),
      ];
      final plan = PlannedWorkout(id: 'w', date: now, sport: Sport.gym, title: 'Push', phase: 'recovery');
      final c = ProviderContainer(
        overrides: [
          profileProvider.overrideWith((ref) => Stream.value(profile())),
          sessionsProvider.overrideWith((ref) => Stream.value(hist)),
          plansProvider.overrideWith((ref) => Stream.value([plan])),
          exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
          activeGymProvider.overrideWith(
            () => _PresetGym(
              ActiveGym(
                title: 'Push',
                start: now,
                planId: 'w',
                exercises: [
                  GymExercise(exId: '0289', name: 'dumbbell bench press', sets: [GymSet(), GymSet()]),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      // (Riverpod pauses providers nobody listens to.)
      c.listen(loadPrescriberProvider, (_, _) {});
      c.listen(planListProvider, (_, _) {});
      await c.read(profileProvider.future);
      await c.read(sessionsProvider.future);
      await c.read(plansProvider.future);
      final rx = c.read(loadPrescriberProvider);
      final bench = GymExercise(exId: '0025', name: 'barbell bench press', sets: [GymSet(), GymSet()]);
      final loading = rx.forExercise(bench)!, deload = rx.forExercise(bench, phase: 'recovery')!;
      expect(deload.weight, lessThan(loading.weight));
      c.read(activeGymProvider.notifier).replaceExercise(0, '0025', 'barbell bench press');
      final e = c.read(activeGymProvider)!.exercises.single;
      expect(e.phase, 'recovery');
      expect(e.workSets.every((s) => s.weight == deload.weight && !s.amrap), isTrue);
    });
  });

  group('S5: deload / taper for bodyweight exercises', () {
    final now = DateTime(2026, 11, 20, 18);
    const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);
    GymExercise bwEx(String exId, String name, int reps, {double kg = 0, bool done = true, int sets = 3}) => GymExercise(
      exId: exId,
      name: name,
      bw: true,
      bodyKg: done ? 80 : 0,
      sets: [for (var i = 0; i < sets; i++) GymSet(weight: kg, reps: reps, done: done, target: done ? reps : null)],
    );
    Session session(int daysAgo, List<GymExercise> list) => Session(
      id: 's$daysAgo',
      sport: Sport.gym,
      title: 'Gym',
      start: now.subtract(Duration(days: daysAgo)),
      durationSec: 3600,
      exercises: list,
    );

    test('push-ups / pull-ups / squats: fewer reps than the loading level, never a step up', () {
      for (final (exId, name, reps) in [('0662', 'push-up', 12), ('0652', 'pull-up', 8), ('3500', 'bodyweight squat', 15)]) {
        final rx = LoadPrescriber(
          history: [
            session(3, [bwEx(exId, name, reps)]),
            session(7, [bwEx(exId, name, reps)]),
          ],
          profile: male80,
          now: now,
        );
        final open = bwEx(exId, name, reps, done: false);
        final load = rx.forExercise(open)!;
        for (final phase in ['recovery', 'taper', 'race']) {
          final p = rx.forExercise(open, phase: phase)!;
          final why = '$name $phase: ${p.reps} vs ${load.reps}';
          expect(p.reps, lessThan(reps), reason: why);
          expect(p.reps, greaterThanOrEqualTo((reps * 0.7).floor()), reason: why);
          expect(p.progression, isNot(ProgressionKind.addReps), reason: why);
          expect(p.progression, isNot(ProgressionKind.increase), reason: why);
          expect(p.phaseAdjusted, isTrue, reason: why);
          final applied = rx.apply([open], phase: phase).single;
          expect(applied.workSets.every((s) => s.reps == p.reps), isTrue, reason: why);
        }
      }
    });

    test('weighted pull-up: ~10 % off the total load (body + belt), no extra reps', () {
      final rx = LoadPrescriber(
        history: [
          session(3, [bwEx('0652', 'pull-up', 6, kg: 10)]),
          session(7, [bwEx('0652', 'pull-up', 6, kg: 10)]),
        ],
        profile: male80,
        now: now,
      );
      final open = bwEx('0652', 'pull-up', 6, done: false);
      final load = rx.forExercise(open)!;
      expect(load.weight, greaterThan(0));
      final p = rx.forExercise(open, phase: 'recovery')!;
      final body = rx.bodyLoad(open);
      expect(p.weight + body, lessThanOrEqualTo((load.weight + body) * 0.9 + 1e-9));
      expect(p.weight, greaterThanOrEqualTo(0));
      expect(p.reps, lessThanOrEqualTo(6));
    });
  });

  group('S9: carries and skill holds', () {
    const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);
    final rx = LoadPrescriber(history: const [], profile: male80, now: DateTime(2026, 11, 20));

    test('a loaded carry without history starts with a load per hand', () {
      for (final (exId, name) in [('2133', "farmer's walk"), ('3548', 'dumbbell single arm overhead carry')]) {
        final e = GymExercise(exId: exId, name: name, sets: [GymSet(), GymSet()]);
        expect(e.isTimed, isTrue);
        final p = rx.forExercise(e)!;
        expect(p.weight, greaterThan(0), reason: name);
        expect(p.perHand, isTrue);
        expect(p.timed, isTrue);
        final applied = rx.apply([e]).single;
        expect(applied.workSets.every((s) => s.weight == p.weight && s.sec > 0), isTrue, reason: name);
      }
      final farmer = rx.forExercise(GymExercise(exId: '2133', name: "farmer's walk", sets: [GymSet()]))!;
      final overhead = rx.forExercise(GymExercise(exId: '3548', name: 'dumbbell single arm overhead carry', sets: [GymSet()]))!;
      expect(overhead.weight, lessThan(farmer.weight));
      // A deload week: lighter.
      expect(
        rx.forExercise(GymExercise(exId: '2133', name: "farmer's walk", sets: [GymSet()]), phase: 'recovery')!.weight,
        lessThan(farmer.weight),
      );
    });

    test('skill holds are bodyweight work', () {
      for (final (exId, name) in [
        ('3302', 'handstand'),
        ('3419', 'l-sit on floor'),
        ('3296', 'front lever'),
        ('9999', 'hollow body hold'),
      ]) {
        final e = GymExercise(exId: exId, name: name, sets: [GymSet()]);
        expect(rx.isBodyweight(e), isTrue, reason: name);
      }
      // A plank stays bodyweight, a lever machine stays a machine.
      expect(rx.isBodyweight(GymExercise(exId: '9998', name: 'lever seated row', sets: [GymSet()])), isFalse);
    });
  });

  group('R4: plans generated before #59 are upgraded', () {
    final pull = byKey('ppl_pull'), legs = byKey('ppl_legs'), fb = byKey('fb_a');
    final today = DateTime(2026, 11, 13);
    PlannedWorkout old(
      WorkoutTemplate t,
      List<GymExercise> ex, {
      String desc = '',
      int days = 2,
      String status = 'planned',
      List<String> mods = const [],
    }) => PlannedWorkout(
      id: 'w${n++}',
      date: addDays(today, days),
      sport: Sport.gym,
      title: t.name,
      description: desc,
      durationMin: 70,
      templateId: t.id,
      phase: 'build',
      status: status,
      exercises: ex,
      gymMods: mods,
    );
    PlannedWorkout applyUpdate(PlannedWorkout p, Map<String, dynamic> u) => PlannedWorkout.fromMap(p.id, {...p.toMap(), ...u});
    GymExercise plusSet(GymExercise e) => e.copy()..sets.add(e.sets.lastWhere((s) => !s.warmup).copy());

    test('extra sets (time fill): back to the program, the set counts follow it again', () {
      final w = old(pull, [for (final e in pull.exercises) plusSet(e)]);
      final u = GymPlanUpgrade.upgrade(w, pull);
      expect(u['exercises'], isEmpty);
      final up = applyUpdate(w, u);
      expect(up.exercises, isEmpty);
      expect(up.gymMods, isEmpty);
      expect([for (final e in plannedGymExercises(up, pull)) e.workSets.length], [for (final e in pull.exercises) e.workSets.length]);
      expect(GymPlanUpgrade.upgrade(up, pull), isEmpty, reason: 'idempotent');
    });

    test('beginner regressions become the regress mod', () {
      final t = pull.exercises.any((e) => gymRegressions.containsKey(e.exId)) ? pull : fb;
      expect(t.exercises.any((e) => gymRegressions.containsKey(e.exId)), isTrue);
      final w = old(t, [for (final e in t.exercises) regressedExercise(e, 'strength')], desc: de.wGymRegressionNote);
      final up = applyUpdate(w, GymPlanUpgrade.upgrade(w, t));
      expect(up.exercises, isEmpty);
      expect(up.gymMods, [gymModRegress]);
      expect(plannedGymExercises(up, t).map((e) => e.exId), [for (final e in t.exercises) gymRegressions[e.exId]?.$1 ?? e.exId]);
    });

    test('halved leg sets before a key session: lighter legs instead, the note follows', () {
      final halved = [for (final e in fb.exercises) classifyLift(e.exId, e.name).lower ? (e.copy()..sets.removeLast()) : e.copy()];
      for (final l in [de, en]) {
        final w = old(fb, halved, desc: '${l.wGymLoadDesc(2)}\n${l.wGymConcurrentNote}\n${l.wGymLegsHalvedNote}');
        final up = applyUpdate(w, GymPlanUpgrade.upgrade(w, fb));
        expect(up.exercises, isEmpty);
        expect(up.gymMods, [gymModLegsEasy]);
        expect(up.description.split('\n'), [l.wGymLoadDesc(2), l.wGymConcurrentNote, l.wGymLegsEasyNote]);
        expect(gymLoadPhase(up), 'legsEasy');
      }
    });

    test('race week without the leg exercises: noLegs + the race-week load', () {
      final upper = [
        for (final e in fb.exercises)
          if (!classifyLift(e.exId, e.name).lower) e.copy(),
      ];
      final w = old(fb, upper, desc: '${de.wGymTaperNote}\n${de.wGymRaceWeekNote}');
      final up = applyUpdate(w, GymPlanUpgrade.upgrade(w, fb));
      expect(up.exercises, isEmpty);
      expect(up.gymMods, containsAll([gymModNoLegs, gymModRaceWeek]));
      expect(plannedGymExercises(up, fb).map((e) => e.exId), upper.map((e) => e.exId));
      expect(gymLoadPhase(up), 'race');
    });

    test('plans of the previous version (references already) get the load mods their notes promise', () {
      final easy = old(legs, const [], desc: '${de.wGymLoadDesc(2)}\n${de.wGymLegsEasyNote}');
      expect(GymPlanUpgrade.upgrade(easy, legs), {
        'gymMods': [gymModLegsEasy],
      });
      final race = old(fb, const [], desc: '${en.wGymTaperNote}\n${en.wGymRaceWeekNote}', mods: const [gymModNoLegs]);
      expect(applyUpdate(race, GymPlanUpgrade.upgrade(race, fb)).gymMods, [gymModNoLegs, gymModRaceWeek]);
      final plain = old(pull, const [], desc: de.wGymLoadDesc(2));
      expect(GymPlanUpgrade.upgrade(plain, pull), isEmpty);
    });

    test('the athlete\'s own exercises, done and past workouts stay as they are', () {
      final reordered = old(pull, [for (final e in pull.exercises.reversed) e.copy()]);
      final other = old(pull, [...pull.exercises.map((e) => e.copy()), GymExercise(exId: '0025', name: 'barbell bench press')]);
      final swapped = old(pull, [GymExercise(exId: '0025', name: 'barbell bench press'), ...pull.exercises.skip(1).map((e) => e.copy())]);
      final done = old(pull, [for (final e in pull.exercises) plusSet(e)], status: 'done');
      final past = old(pull, [for (final e in pull.exercises) plusSet(e)], days: -1);
      final updates = GymPlanUpgrade.updates([reordered, other, swapped, done, past], templates, today: today);
      expect(updates, isEmpty);
      // … while a future copy is upgraded.
      final future = old(pull, [for (final e in pull.exercises) plusSet(e)], days: 0);
      expect(GymPlanUpgrade.updates([future], templates, today: today).keys, [future.id]);
    });

    test('day edits of reps, weights, rest, notes or set values keep the copy (re-check of R4)', () {
      List<GymExercise> edited(void Function(GymExercise e) f) {
        final list = [for (final e in pull.exercises) e.copy()];
        f(list.first);
        return list;
      }

      final edits = {
        'rep range': edited(
          (e) =>
              e
                ..repMin = 3
                ..repMax = 4,
        ),
        'note': edited((e) => e.note = 'grip wide'),
        'rest': edited((e) => e.restSec = e.restSec + 30),
        'set reps': edited((e) => e.workSets.first.reps += 2),
        'set weight': edited((e) => e.workSets.first.weight += 5),
        'extra set with other reps': edited((e) => e.sets.add(GymSet(reps: e.workSets.last.reps + 3))),
        'warm-up added': edited((e) => e.sets.insert(0, GymSet(type: SetType.warmup, reps: 10))),
      };
      for (final MapEntry(key: what, value: ex) in edits.entries) {
        expect(GymPlanUpgrade.upgrade(old(pull, ex), pull), isEmpty, reason: what);
      }
      // A regressed copy whose reps the athlete changed stays too.
      final t = pull.exercises.any((e) => gymRegressions.containsKey(e.exId)) ? pull : fb;
      final reg = [for (final e in t.exercises) regressedExercise(e, 'strength')];
      final r = reg.firstWhere((e) => gymRegressions.values.any((v) => v.$1 == e.exId));
      r.workSets.first.reps += 3;
      expect(GymPlanUpgrade.upgrade(old(t, reg, desc: de.wGymRegressionNote), t).containsKey('exercises'), isFalse);
      // The unedited copies (exact, +1 set, halved) are still upgraded.
      expect(GymPlanUpgrade.upgrade(old(pull, [for (final e in pull.exercises) e.copy()]), pull)['exercises'], isEmpty);
    });
  });

  group('R7-5: the suggested assignment for 4 PPL days', () {
    test('weeks A and B differ (the rotation does not fit into one week)', () {
      final s = PlanGenerator.suggestedGymWeeks(profile(days: [1, 2, 4, 6], split: 'ppl'), templates);
      expect(s.a.keys.toSet(), {1, 2, 4, 6});
      expect(s.b.entries.any((e) => s.a[e.key] != e.value), isTrue);
      // Over both weeks every program at least twice.
      final all = [...s.a.values, ...s.b.values];
      for (final k in ['ppl_push', 'ppl_pull', 'ppl_legs']) {
        expect(all.where((r) => r == 'key:$k').length, greaterThanOrEqualTo(2), reason: '$all');
      }
    });
  });
}

class _PresetGym extends ActiveGymNotifier {
  _PresetGym(this.init);
  final ActiveGym init;
  @override
  ActiveGym? build() => init;
}
