import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/builtin_upgrade.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/planned_workout_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/gym_plan_upgrade.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/program_deletion.dart';
import 'package:strive/widgets/plan_amount.dart';

/// Review round 7 (R7-1 / R2, R5 / R7-7): deleting a program the plan uses, restoring the
/// originals, and what the planned workouts and the plan settings show afterwards.
void main() {
  var n = 0;
  String id() => 'p${n++}';
  final templates = defaultTemplates(id, de: true);
  WorkoutTemplate byKey(String k) => templates.firstWhere((t) => t.key == k);
  final today = DateTime(2026, 11, 16); // Monday
  final legs = byKey('ppl_legs'), push = byKey('ppl_push'), pull = byKey('ppl_pull');

  PlannedWorkout gym(String pid, WorkoutTemplate t, int day, {String status = 'planned', List<String> mods = const []}) =>
      PlannedWorkout(id: pid, date: addDays(today, day), sport: Sport.gym, title: t.name, templateId: t.id, status: status, gymMods: mods);

  /// The user changed a built-in gym program: one more set on the first exercise.
  WorkoutTemplate edited(WorkoutTemplate t) {
    final ex = [for (final e in t.exercises) e.copy()];
    ex.first.sets.add(ex.first.sets.first.copy());
    return t.copyWith(exercises: ex);
  }

  group('a planned workout finds its program', () {
    test('by id; a deleted program by the workout title when unambiguous', () {
      final p = gym('a', push, 1);
      expect(plannedProgramOf(p, templates), same(push));
      final without = [...templates.where((t) => t.id != push.id)];
      expect(plannedProgramOf(p, without), isNull);
      expect(plannedProgramMissing(p, without), isTrue);
      // Restored as a new document: found again by its name.
      final restored = WorkoutTemplate.fromMap('restored', push.toMap());
      expect(plannedProgramOf(p, [...without, restored])?.id, 'restored');
      expect(plannedProgramMissing(p, [...without, restored]), isFalse);
      // Two programs of that name, one of them the athlete's own: the built-in one.
      final own = WorkoutTemplate(id: 'own', name: 'Push', sport: Sport.gym);
      expect(plannedProgramOf(p, [...without, restored, own])?.id, 'restored');
      expect(plannedProgramOf(p, [...without, own])?.id, 'own');
      // The athlete's own program: a program of the same name.
      final mine = PlannedWorkout(id: 'm', date: today, sport: Sport.gym, title: 'Mein Oberkörper', templateId: 'gone');
      expect(plannedProgramOf(mine, [...templates, own.copyWith(name: 'Mein Oberkörper')])?.id, 'own');
    });

    test('a name several built-ins share is never guessed ("Beine": PPL and bro split)', () {
      final p = gym('a', legs, 1);
      final without = [...templates.where((t) => t.id != legs.id)];
      // The bro split's "Beine" is another program.
      expect(plannedProgramOf(p, without), isNull);
      expect(plannedProgramMissing(p, without), isTrue);
      expect(relinkedPlans([p], without), isEmpty);
      // … but restoring the PPL originals brings exactly one "Beine" back: relinked to it.
      final plan = planBuiltinRestore(without, () => 'new', de: true, ownSuffix: 'eigene');
      expect(plan.add.map((t) => t.key), ['ppl_legs']);
      expect(relinkedPlans([p], [...without, ...plan.add], restored: plan.add), {
        'a': {'templateId': 'new'},
      });
    });

    test('workouts with own exercises, without a program or of another sport never count as missing', () {
      final without = [...templates.where((t) => t.key != 'ppl_legs' && t.key != 'bro_legs')];
      final custom = PlannedWorkout.fromMap('c', {
        ...gym('c', legs, 1).toMap(),
        'exercises': [for (final e in legs.exercises) e.toMap()],
      });
      expect(plannedProgramMissing(custom, without), isFalse);
      expect(plannedProgramMissing(PlannedWorkout(id: 'f', date: today, sport: Sport.gym, title: 'Beine'), without), isFalse);
      final run = templates.firstWhere((t) => t.sport == Sport.run);
      final runPlan = PlannedWorkout(id: 'r', date: today, sport: Sport.run, title: run.name, templateId: 'gone');
      expect(plannedProgramOf(runPlan, templates), isNull);
      expect(plannedProgramMissing(runPlan, templates), isFalse);
    });
  });

  group('deleting a program the plan uses (R7-1 / R2)', () {
    test('its workouts keep the exercises they show now (day adaptations applied); upcoming ones are counted', () {
      final plans = [
        gym('past', legs, -2, status: 'done'),
        gym('missed', legs, -1),
        gym('today', legs, 0),
        gym('next', legs, 7, mods: [gymModNoLegs]),
        gym('regress', legs, 14, mods: [gymModRegress]),
        gym('other', push, 2),
      ];
      final before = {for (final p in plans) p.id: plannedGymExercises(p, plannedProgramOf(p, templates))};
      final d = programDeletion({legs.id}, templates: templates, plans: plans, athlete: const AthleteData(), today: today);
      expect(d.upcoming, 3);
      expect(d.plans.keys.toSet(), {'past', 'missed', 'today', 'next', 'regress'});
      expect(d.athlete, isNull);
      expect(d.assignedDays, isEmpty);
      // Applied: the workouts show the same exercises without the program.
      final after = [...templates.where((t) => t.id != legs.id)];
      for (final p in plans.where((p) => p.id != 'other')) {
        final kept = PlannedWorkout.fromMap(p.id, {...p.toMap(), ...d.plans[p.id]!});
        expect(plannedProgramMissing(kept, after), isFalse, reason: p.id);
        final shown = plannedGymExercises(kept, plannedProgramOf(kept, after));
        expect(shown.map((e) => '${e.exId}:${e.workSets.length}'), before[p.id]!.map((e) => '${e.exId}:${e.workSets.length}'));
        expect(kept.gymMods, isEmpty);
        // Duration, "log as done" and the session start use them too.
        final profile = const UserProfile();
        expect(planAmount(kept, profile, templates: after).minutes, estimateGymMinutes(shown));
        expect(PlanFill.of(kept, profile: profile, templates: after).exercises, isNotEmpty);
      }
    });

    test('the copied workouts keep the lighter load (legsEasy / raceWeek) and never apply noLegs twice', () {
      final mixed = templates.firstWhere((t) => t.sport == Sport.gym && gymModApplies(gymModNoLegs, t.exercises));
      final plans =
          [
            gym('easy', mixed, 1, mods: [gymModLegsEasy]),
            gym('noLegs', mixed, 2, mods: [gymModNoLegs]),
            gym('race', mixed, 3, mods: [gymModNoLegs, gymModRaceWeek]),
          ].map((p) => PlannedWorkout.fromMap(p.id, {...p.toMap(), 'phase': 'build'})).toList();
      final before = {for (final p in plans) p.id: plannedGymExercises(p, mixed)};
      final d = programDeletion({mixed.id}, templates: templates, plans: plans, athlete: const AthleteData(), today: today);
      final after = [...templates.where((t) => t.id != mixed.id)];
      final kept = {
        for (final p in plans) p.id: PlannedWorkout.fromMap(p.id, {...p.toMap(), ...d.plans[p.id]!}),
      };
      for (final p in plans) {
        final k = kept[p.id]!;
        // The same exercises as before the delete – the copy is shown as it is, no mod applied again.
        expect(plannedProgramMissing(k, after), isFalse, reason: p.id);
        expect(plannedGymExercises(k, plannedProgramOf(k, after)).map((e) => e.exId), before[p.id]!.map((e) => e.exId), reason: p.id);
        expect(
          PlanFill.of(k, profile: const UserProfile(), templates: after).exercises.map((e) => e.exId),
          before[p.id]!.map((e) => e.exId),
        );
        // The lighter load stays: the same load phase as before.
        expect(gymLoadPhase(k), gymLoadPhase(p), reason: p.id);
      }
      expect(kept['easy']!.gymMods, [gymModLegsEasy]);
      expect(gymLoadPhase(kept['easy']), 'legsEasy');
      expect(kept['noLegs']!.gymMods, isEmpty);
      expect(kept['noLegs']!.exercises.any((e) => classifyLift(e.exId, e.name).lower), isFalse);
      expect(kept['noLegs']!.exercises, isNotEmpty);
      expect(kept['race']!.gymMods, [gymModRaceWeek]);
      expect(gymLoadPhase(kept['race']), 'race');
      // The plan upgrade leaves the copies alone (their program is gone).
      expect(GymPlanUpgrade.updates(kept.values.toList(), after, today: today), isEmpty);
    });

    test('a folder: every program in it; the plan settings lose the deleted assignments', () {
      final copy = WorkoutTemplate.fromMap('copy', {...edited(pull).toMap()});
      final all = [...templates, copy];
      final a = const AthleteData().merge({
        'gymAssign': true,
        'gymAB': true,
        'gymPlanA': {1: 'id:${push.id}', 3: 'key:ppl_pull', 5: 'key:ppl_legs'},
        'gymPlanB': {1: 'id:${push.id}', 3: 'key:ppl_pull', 5: 'id:own'},
      });
      // The PPL folder (push, pull, legs) goes; the edited Pull copy elsewhere keeps the key.
      final d = programDeletion({push.id, pull.id, legs.id}, templates: all, plans: [gym('x', push, 1)], athlete: a, today: today);
      expect(d.upcoming, 1);
      expect(d.athlete, {
        'gymPlanA': {3: 'key:ppl_pull'},
        'gymPlanB': {3: 'key:ppl_pull', 5: 'id:own'},
      });
      expect(d.assignedDays, [1, 5]);
      // Assignment switched off: cleaned silently, not named.
      final off = programDeletion({push.id}, templates: all, plans: const [], athlete: a.merge({'gymAssign': false}), today: today);
      expect(off.assignedDays, isEmpty);
      expect(off.athlete, isNotNull);
      expect(off.usedByPlan, isFalse);
    });
  });

  group('restoring the originals (R7-1, R5 / R7-7)', () {
    test('planned workouts of a deleted built-in find the restored original', () {
      final list = [...templates.where((t) => t.key != 'ppl_legs' && t.key != 'bro_legs')];
      final plans = [gym('a', legs, 1), gym('b', legs, 8), gym('c', push, 2)];
      expect(plannedProgramMissing(plans.first, list), isTrue);
      final plan = planBuiltinRestore(list, () => 'new', de: true, ownSuffix: 'eigene', folderKeys: {'ppl'});
      final after = [...list, ...plan.add];
      final relink = relinkedPlans(plans, after, restored: plan.add);
      expect(relink, {
        'a': {'templateId': 'new'},
        'b': {'templateId': 'new'},
      });
      final linked = PlannedWorkout.fromMap('a', {...plans.first.toMap(), ...relink['a']!});
      expect(plannedGymExercises(linked, plannedProgramOf(linked, after)), isNotEmpty);
    });

    test('an assignment of the changed version stays on it; the kept version remembers its built-in', () {
      final mine = edited(push);
      final list = [for (final t in templates) t.key == 'ppl_push' ? mine : t];
      final a = const AthleteData().merge({
        'gymAssign': true,
        'gymAB': true,
        'gymPlanA': {1: 'key:ppl_push', 3: 'key:ppl_pull'},
        'gymPlanB': {1: 'key:ppl_legs', 3: 'key:ppl_push'},
      });
      final plan = planBuiltinRestore(list, () => 'orig', de: true, ownSuffix: 'eigene');
      expect(plan.changed, {'ppl_push'});
      final kept = plan.keep.single;
      expect((kept.key, kept.origKey, kept.name), (null, 'ppl_push', 'Push (eigene)'));
      final patch = restoreAssignmentPatch(a, plan, list)!;
      expect(patch, {
        'gymPlanA': {1: 'id:${mine.id}', 3: 'key:ppl_pull'},
        'gymPlanB': {1: 'key:ppl_legs', 3: 'id:${mine.id}'},
      });
      expect(restoreKeptDays(a, patch), [1, 3]);
      // The settings show (tick) the athlete's version, the plan uses it.
      final after = [for (final t in list) t.id == kept.id ? kept : t, ...plan.add];
      final b = a.merge(patch);
      expect(gymProgramOf(b.gymPlanA[1]!, after)!.id, mine.id);
      expect(gymProgramRef(kept, among: after), b.gymPlanA[1]);
      final l = lookupAppLocalizations(const Locale('de'));
      final p = UserProfile(trainingDays: const [1, 3, 5], focus: TrainingFocus.gym, athlete: b.merge({'gymSplit': 'ppl'}));
      final gymDays = PlanGenerator(l, p, after, id).generate(start: today, weeks: 2).where((w) => w.sport == Sport.gym);
      for (final w in gymDays.where((w) => w.date.weekday == 1 && daysBetween(today, w.date) < 7)) {
        expect(w.templateId, mine.id);
      }
      // Nothing assigned to the changed program: no patch.
      expect(
        restoreAssignmentPatch(
          a.merge({
            'gymPlanA': {1: 'key:ppl_pull'},
            'gymPlanB': <int, String>{},
          }),
          plan,
          list,
        ),
        isNull,
      );
      // The origin survives the round trip; a duplicate does not carry it.
      expect(WorkoutTemplate.fromMap(kept.id, kept.toMap()).origKey, 'ppl_push');
      expect(kept.copyWith(name: 'x').origKey, 'ppl_push');
    });

    test('the rotation continues from workouts done with the kept version (no Pull right after Pull)', () {
      final mine = edited(pull);
      final list = [for (final t in templates) t.key == 'ppl_pull' ? mine : t];
      final plan = planBuiltinRestore(list, () => 'orig', de: true, ownSuffix: 'eigene');
      final kept = plan.keep.single;
      final after = [for (final t in list) t.id == kept.id ? kept : t, ...plan.add];
      final l = lookupAppLocalizations(const Locale('de'));
      final p = UserProfile(trainingDays: const [1, 3, 5], focus: TrainingFocus.gym, athlete: const AthleteData(gymSplit: 'ppl'));
      final first = PlanGenerator(
        l,
        p,
        after,
        id,
      ).generate(start: today, weeks: 1, gymHistory: [(addDays(today, -3), kept.id)]).firstWhere((w) => w.sport == Sport.gym);
      expect(after.firstWhere((t) => t.id == first.templateId).key, 'ppl_legs');
    });

    test('a second program with the same key is referenced by its id (one tick, the right one)', () {
      final twin = WorkoutTemplate.fromMap('twin', push.toMap());
      final all = [...templates, twin];
      expect(gymProgramRef(push, among: all), 'key:ppl_push');
      expect(gymProgramRef(twin, among: all), 'id:twin');
      expect(gymProgramOf(gymProgramRef(twin, among: all), all), same(twin));
      expect(gymProgramRef(push), 'key:ppl_push');
    });
  });

  group('planned workout page (R7-1)', () {
    for (final lang in ['de', 'en']) {
      testWidgets('a workout whose program was deleted says so; start asks first ($lang)', (t) async {
        t.view.physicalSize = const Size(360, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final l = lookupAppLocalizations(Locale(lang));
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final plan = PlannedWorkout(id: 'p', date: dayOnly(DateTime.now()), sport: Sport.gym, title: 'Mein Programm', templateId: 'gone');
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              prefsProvider.overrideWithValue(prefs),
              repoProvider.overrideWithValue(Repository('test')),
              profileProvider.overrideWith((ref) => Stream.value(const UserProfile())),
              sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
              templatesProvider.overrideWith((ref) => Stream.value(templates)),
              plansProvider.overrideWith((ref) => Stream.value([plan])),
              goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              locale: Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const PlannedWorkoutPage(planId: 'p'),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('programMissing')), findsOneWidget);
        expect(find.text(l.planProgramMissing), findsOneWidget);
        await t.tap(find.text(l.startWorkout));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('chooseProgram')), findsOneWidget);
        expect(find.byKey(const ValueKey('startEmpty')), findsOneWidget);
        await t.tap(find.text(l.cancel));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('chooseProgram')), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  });
}
