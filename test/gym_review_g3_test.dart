import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/builtin_upgrade.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';

/// Strength review 2026-11 (package G3): health limitations change the lifts and the effort, no-equipment
/// programs need no equipment, home / bodyweight 4+ days split upper / lower, the race window never keeps a
/// leg day, rest days for pure strength, the bro split's order, the stored duration, the progression notes,
/// the gym history in finish-goal plans and gap fills, and the A/B suggestion.
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'g${n++}';
  final templates = defaultTemplates(id, de: true);
  final start = DateTime(2026, 11, 16); // Monday
  WorkoutTemplate byKey(String k) => templates.firstWhere((t) => t.key == k);
  WorkoutTemplate? byId(String? i) => templates.where((t) => t.id == i).firstOrNull;

  UserProfile prof(
    TrainingFocus focus,
    String level,
    List<int> days, {
    Map<String, dynamic> a = const {},
    List<String> goals = const ['strength'],
  }) => UserProfile(
    level: level,
    focus: focus,
    birthYear: 1990,
    weightKg: 80,
    gender: 'm',
    trainingDays: days,
    goals: goals,
    athlete: const AthleteData(raceTimes: {'10k': 50 * 60}).merge(a),
  );

  List<PlannedWorkout> gen(UserProfile p, {int? weeks, List<(DateTime, String)> hist = const []}) =>
      PlanGenerator(l, p, templates, id).generate(start: start, weeks: weeks, gymHistory: hist);
  List<PlannedWorkout> gymOf(List<PlannedWorkout> plan) =>
      plan.where((w) => w.sport == Sport.gym).toList()..sort((x, y) => x.date.compareTo(y.date));
  List<GymExercise> exOf(PlannedWorkout w, UserProfile p) => plannedGymExercises(w, byId(w.templateId), gymGoal: p.athlete.gymGoal);

  final db = {
    for (final e in (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List).cast<Map<String, dynamic>>())
      e['id'] as String: e,
  };

  group('GYM-2 health limitations change the workout, not only its note', () {
    const axial = {'0043', '0032', '0085', '0027', '0293', '0426', '0605', '0514', '0472', '1459', '1757'};
    const overhead = {'0405', '0426', '0194', '0430', '0814', '0129'};
    final cases = <String, UserProfile>{};
    for (final level in ['beginner', 'intermediate', 'advanced']) {
      for (final eq in ['gym', 'home', 'bodyweight']) {
        for (final split in eq == 'gym' ? ['fullbody', 'upperlower', 'ppl', 'ulppl', 'bro'] : ['auto']) {
          for (final days in [
            [1, 3, 5],
            [1, 2, 4, 5],
            [1, 2, 3, 4, 5, 6],
          ]) {
            cases['$level/$eq/$split/${days.length}'] = prof(
              TrainingFocus.gym,
              level,
              days,
              a: {
                'equipment': eq,
                'gymSplit': split,
                'limitations': ['back', 'shoulder', 'knee'],
              },
            );
          }
        }
      }
    }

    test('back / shoulder / knee: no axial, overhead or jump lifts in any workout; never an exercise twice', () {
      for (final MapEntry(key: name, value: p) in cases.entries) {
        for (final w in gymOf(gen(p, weeks: 8))) {
          final ids = [for (final e in exOf(w, p)) e.exId];
          expect(ids.where(axial.contains), isEmpty, reason: '$name ${w.date} ${w.title} $ids');
          expect(ids.where(overhead.contains), isEmpty, reason: '$name ${w.date} ${w.title} $ids');
          expect(ids.toSet().length, ids.length, reason: '$name ${w.date} ${w.title} $ids');
          // The workout says what was swapped; the general "replace …" note only where nothing was.
          // (G3V-5: home / bodyweight workouts have no leg press – their own swap note.)
          if (w.gymMods.contains(gymModNoAxial)) {
            expect(w.description, contains(p.athlete.equipment == 'gym' ? l.healthGymBackSwapNote : l.healthGymBackSwapNoteHome));
            expect(w.description, isNot(contains(l.healthGymBackNote)));
          }
        }
      }
    });

    test('heart: RIR ≥ 2 in every loading week and no AMRAP set', () {
      for (final level in ['intermediate', 'advanced']) {
        final p = prof(
          TrainingFocus.gym,
          level,
          [1, 3, 5],
          a: {
            'limitations': ['heart'],
          },
        );
        final gym = gymOf(gen(p, weeks: 12));
        expect(gym.any((w) => w.description.contains(l.wGymLoadDesc(1)) || w.description.contains(l.wGymLoadDescNoDeload(1))), isFalse);
        expect(gym.any((w) => w.description.contains(l.wGymLoadDesc(2))), isTrue);
        final rx = LoadPrescriber(history: const [], profile: p, now: start);
        for (final w in gym.take(6)) {
          final sets = [for (final e in rx.apply(exOf(w, p), phase: gymLoadPhase(w))) ...e.sets];
          expect(sets.where((s) => s.amrap), isEmpty, reason: w.title);
        }
      }
      // Without the limitation the calibration sets stay.
      final plain = prof(TrainingFocus.gym, 'intermediate', [1, 3, 5]);
      final w = gymOf(gen(plain, weeks: 2)).first;
      final rx = LoadPrescriber(history: const [], profile: plain, now: start);
      expect(rx.apply(exOf(w, plain)).expand((e) => e.sets).any((s) => s.amrap), isTrue);
    });

    test('every swap target exists in the exercise library under its name', () {
      for (final swaps in [gymRegressions, gymNoAxialSwaps, gymNoOverheadSwaps, gymNoJumpSwaps]) {
        for (final options in swaps.values) {
          for (final (exId, name) in options) {
            expect(db[exId]?['n'], name, reason: exId);
          }
        }
      }
    });
  });

  group('GYM-3 / GYM-7 programs and regressions', () {
    test('bodyweight programs need no equipment, home programs dumbbells and body weight only', () {
      for (final t in templates.where((t) => t.sport == Sport.gym)) {
        final folder = builtinFolderOf[t.key];
        if (folder != 'bodyweight' && folder != 'home') continue;
        final allowed = folder == 'bodyweight' ? {'body weight'} : {'body weight', 'dumbbell'};
        for (final e in t.exercises) {
          expect(allowed, contains(db[e.exId]?['e']), reason: '${t.key} ${e.exId} ${e.name}');
          expect(db[e.exId]?['n'], e.name, reason: '${t.key} ${e.exId}');
        }
      }
    });

    test('beginners: no exercise twice in a session, the hinge regressed on every day', () {
      for (final split in ['fullbody', 'ppl', 'ulppl', 'upperlower', 'bro']) {
        final p = prof(TrainingFocus.gym, 'beginner', [1, 3, 5], a: {'gymSplit': split});
        for (final w in gymOf(gen(p, weeks: 6))) {
          final ids = [for (final e in exOf(w, p)) e.exId];
          expect(ids.toSet().length, ids.length, reason: '$split ${w.title} $ids');
          expect(ids.where((x) => x == '0032' || x == '0085' || x == '0652'), isEmpty, reason: '$split ${w.title} $ids');
        }
      }
      // Bodyweight beginners: easier variations first, the full exercises later.
      final bw = prof(TrainingFocus.gym, 'beginner', [1, 3, 5], a: {'equipment': 'bodyweight'});
      final gym = gymOf(gen(bw, weeks: 10));
      final first = {for (final w in gym.take(2)) ...exOf(w, bw).map((e) => e.exId)};
      expect(first, containsAll(['3533', '0493', '2300']));
      expect(first, isNot(contains('0514')));
      expect(gym.first.description, contains(l.wGymRegressionNote2));
      final later = {for (final w in gym.skip(gym.length - 2)) ...exOf(w, bw).map((e) => e.exId)};
      expect(later, containsAll(['0514', '0662', '0499']));
    });

    test('an untouched copy of the earlier bodyweight B is upgraded', () {
      for (final goal in gymGoals) {
        final old = previousBuiltinVersions(goal)['bw_b']!.single;
        final t = WorkoutTemplate(id: 'x', key: 'bw_b', name: 'Eigengewicht B', sport: Sport.gym, exercises: old);
        final up = upgradedBuiltinExercises(t, goal);
        expect(up?.map((e) => e.exId), defaultTemplates(id, goal: goal).firstWhere((t) => t.key == 'bw_b').exercises.map((e) => e.exId));
        expect(isUntouchedBuiltin(t), isTrue);
      }
    });
  });

  test('GYM-4 home / bodyweight: full body up to 3 days, upper / lower from 4 days', () {
    for (final eq in ['home', 'bodyweight']) {
      for (final days in [
        [1, 3, 5],
        [1, 2, 4, 5],
        [1, 2, 3, 4, 5, 6],
      ]) {
        final p = prof(TrainingFocus.gym, 'advanced', days, a: {'equipment': eq});
        final gym = gymOf(gen(p, weeks: 8));
        final keys = {for (final w in gym) byId(w.templateId)!.key};
        expect(keys, days.length >= 4 ? splitRotation['${eq}_ul']!.toSet() : splitRotation[eq]!.toSet(), reason: '$eq $days');
        for (var i = 1; i < gym.length; i++) {
          if (daysBetween(gym[i - 1].date, gym[i].date) != 1) continue;
          final a = gymGroupSets(byId(gym[i - 1].templateId)!.exercises), b = gymGroupSets(byId(gym[i].templateId)!.exercises);
          final shared = a.keys.where((k) => a[k]! >= 3 && b[k]! >= 3);
          expect(shared, isEmpty, reason: '$eq $days ${gym[i - 1].title} → ${gym[i].title}');
        }
      }
    }
  });

  group('GYM-6 / UX-8 race window', () {
    test('a session in the last 10 days keeps ≥ half of its program when a non-leg program exists', () {
      final race = addDays(start, 7 * 11 + 6);
      for (final split in ['ppl', 'upperlower', 'ulppl', 'bro', 'fullbody']) {
        for (final days in [
          [1, 2, 3, 5, 6, 7],
          [1, 3, 5, 7],
        ]) {
          final p = prof(TrainingFocus.hybrid, 'intermediate', days, a: {'eventDistance': '10k', 'eventDate': race, 'gymSplit': split});
          for (final w in gymOf(gen(p))) {
            if (daysBetween(w.date, race) > 10) continue;
            final program = byId(w.templateId)!.exercises;
            int sets(List<GymExercise> ex) => ex.fold(0, (x, e) => x + e.workSets.length);
            expect(sets(exOf(w, p)) * 2, greaterThanOrEqualTo(sets(program)), reason: '$split $days ${w.date} ${w.title}');
            expect(legHeavyProgram(byId(w.templateId)!), isFalse, reason: '$split $days ${w.date} ${w.title}');
          }
        }
      }
    });

    test('an assigned leg day in the race window gives way to an upper-body program', () {
      final race = addDays(start, 7 * 16 + 6);
      final p = prof(
        TrainingFocus.ride,
        'intermediate',
        [1, 2, 3, 4, 6, 7],
        a: {
          'eventDistance': 'ride160',
          'eventDate': race,
          'gymSplit': 'ppl',
          'gymAssign': true,
          'gymAB': true,
          'gymPlanA': {1: 'key:ppl_push', 3: 'key:ppl_legs'},
          'gymPlanB': {1: 'key:ppl_pull', 3: 'key:ppl_legs'},
        },
      );
      final gym = gymOf(gen(p));
      final window = gym.where((w) => daysBetween(w.date, race) <= 10).toList();
      expect(window, isNotEmpty);
      for (final w in window) {
        expect(byId(w.templateId)!.key, isNot('ppl_legs'), reason: '${w.date}');
      }
      for (var i = 1; i < gym.length; i++) {
        expect(gym[i].templateId, isNot(gym[i - 1].templateId), reason: '${gym[i].date} ${gym[i].title}');
      }
    });
  });

  test('GYM-8 pure strength: beginners ≤ 4, intermediates ≤ 5, advanced ≤ 6 days – at least one rest day', () {
    for (final (level, max) in [('beginner', 4), ('intermediate', 5), ('advanced', 6)]) {
      final p = prof(TrainingFocus.gym, level, [1, 2, 3, 4, 5, 6, 7]);
      final plan = gen(p, weeks: 4);
      for (var w = 0; w < 4; w++) {
        final days = {
          for (final x in plan)
            if (daysBetween(start, x.date) ~/ 7 == w) x.date.weekday,
        };
        expect(days.length, lessThanOrEqualTo(max), reason: '$level week $w');
      }
    }
  });

  test('GYM-9 legs easy only before a run or ride; the single tri strength day not before the long run', () {
    final swim = prof(TrainingFocus.swim, 'intermediate', [1, 2, 4, 6, 7]);
    expect(gymOf(gen(swim, weeks: 6)).where((w) => w.gymMods.contains(gymModLegsEasy)), isEmpty);
    final tri = prof(
      TrainingFocus.triathlon,
      'intermediate',
      [1, 2, 3, 4, 5, 6, 7],
      a: {'eventDistance': '70.3', 'eventDate': addDays(start, 7 * 20 + 6)},
    );
    final plan = gen(tri, weeks: 8);
    final longRuns = {
      for (final w in plan)
        if (w.sport == Sport.run && w.intensity == 'long') dayKey(w.date),
    };
    for (final g in gymOf(plan)) {
      expect(longRuns, isNot(contains(dayKey(addDays(g.date, 1)))), reason: '${g.date}');
    }
  });

  test('GYM-10 bro split: chest and shoulders never on consecutive days when the week allows it', () {
    final p = prof(TrainingFocus.gym, 'intermediate', [1, 2, 3, 5, 6], a: {'gymSplit': 'bro'});
    final gym = gymOf(gen(p, weeks: 8));
    for (var i = 1; i < gym.length; i++) {
      if (daysBetween(gym[i - 1].date, gym[i].date) != 1) continue;
      final pair = {byId(gym[i - 1].templateId)!.key, byId(gym[i].templateId)!.key};
      expect(pair, isNot(equals({'bro_chest', 'bro_shoulders'})), reason: '${gym[i].date}');
    }
  });

  test('GYM-12 the stored duration is the workout\'s real length', () {
    final p = prof(TrainingFocus.gym, 'intermediate', [1, 2, 4, 5], a: {'sessionMinutes': 30});
    for (final w in gymOf(gen(p, weeks: 4))) {
      final est = estimateGymMinutes(exOf(w, p));
      expect(w.durationMin, est);
      if (est > 30) expect(w.description, contains(l.wGymOverTimeNote(est, 30)));
    }
  });

  test('GYM-14 progression note: beginners linear, bodyweight programs by reps and variations', () {
    final beg = gymOf(gen(prof(TrainingFocus.gym, 'beginner', [1, 3, 5]), weeks: 2));
    expect(beg.first.description, contains(l.wGymProgressNoteLinear));
    final bw = gymOf(gen(prof(TrainingFocus.gym, 'intermediate', [1, 3, 5], a: {'equipment': 'bodyweight'}), weeks: 2));
    expect(bw.first.description, contains(l.wGymProgressNoteBw2));
    final mid = gymOf(gen(prof(TrainingFocus.gym, 'intermediate', [1, 3, 5]), weeks: 2));
    expect(mid.first.description, contains(l.wGymProgressNote));
  });

  test('eng-2 a finish-goal plan keeps the gym history (no Push right after Push)', () {
    final p = prof(
      TrainingFocus.run,
      'intermediate',
      [1, 2, 3, 4, 5, 6, 7],
      goals: const ['strength', 'race'],
      a: {
        'gymSplit': 'ppl',
        'sessionMinutes': 30,
        'dayMinutes': {7: 60},
        'eventDistance': 'hm',
        'eventDate': addDays(start, 7 * 11 + 6),
        'raceTimes': <String, int>{},
      },
    );
    final push = byKey('ppl_push').id;
    final first = gymOf(gen(p, hist: [(addDays(start, -1), push)])).first;
    expect(first.templateId, isNot(push));
  });

  test('eng-5 a deleted gym day is refilled with the program the rotation needs', () {
    final base = prof(TrainingFocus.gym, 'intermediate', [1, 3, 5], a: {'gymSplit': 'ppl', 'planWeeks': 8});
    final p = withPlanMeta(base, start, 8);
    final push = byKey('ppl_push').id;
    final before = PlannedWorkout(
      id: 'h',
      date: addDays(start, -2),
      sport: Sport.gym,
      title: 'Push',
      templateId: push,
      status: 'done',
      phase: 'base',
    );
    final plan = gen(p, weeks: 8, hist: [(before.date, push)]);
    final wed = addDays(start, 9);
    final deleted = plan.firstWhere((w) => sameDay(w.date, wed));
    final plans = [
      before,
      for (final w in plan)
        if (w.id != deleted.id) w,
    ];
    final fills = PlanGaps(l, p, plans: plans, now: addDays(start, 7), templates: templates).find();
    final fill = fills.where((f) => f.plan.sport == Sport.gym && sameDay(f.plan.date, wed)).single;
    expect(fill.plan.templateId, deleted.templateId);
  });

  test('UX-10 the suggested weeks A / B never repeat a program across the A → B → A cycle', () {
    for (final days in [
      [1, 2, 3, 5, 6],
      [1, 2, 4, 6],
      [1, 2, 3, 4, 5],
    ]) {
      for (final split in ['ppl', 'ulppl', 'bro']) {
        final p = prof(TrainingFocus.gym, 'advanced', days, a: {'gymSplit': split});
        final s = PlanGenerator.suggestedGymWeeks(p, templates);
        final cycle = [for (final d in s.a.keys.toList()..sort()) s.a[d]!, for (final d in s.b.keys.toList()..sort()) s.b[d]!];
        for (var i = 0; i < cycle.length; i++) {
          expect(cycle[i], isNot(cycle[(i + 1) % cycle.length]), reason: '$split $days $cycle');
        }
      }
    }
  });

  group('verifier follow-up (G3V)', () {
    test('G3V-1 home / bodyweight upper / lower before a race: never the same program on consecutive days', () {
      final race = addDays(start, 7 * 11 + 6);
      for (final eq in ['home', 'bodyweight']) {
        for (final (focus, plan) in [
          (
            TrainingFocus.run,
            <int, List<Sport>>{
              1: [Sport.gym],
              2: [Sport.run, Sport.gym],
              3: [Sport.run],
              4: [Sport.gym],
              5: [Sport.gym],
              6: [Sport.run],
              7: [Sport.run],
            },
          ),
          (
            TrainingFocus.hybrid,
            <int, List<Sport>>{
              1: [Sport.gym],
              2: [Sport.gym, Sport.run],
              3: [Sport.gym],
              4: [Sport.run],
              5: [Sport.gym],
              6: [Sport.gym],
              7: [Sport.run],
            },
          ),
        ]) {
          final p = prof(
            focus,
            'intermediate',
            const [1, 2, 3, 4, 5, 6, 7],
            goals: const ['race', 'strength'],
            a: {'equipment': eq, 'eventDistance': '10k', 'eventDate': race, 'setupMode': 'advanced', 'sessionsPerDay': 2, 'dayPlan': plan},
          );
          final gym = gymOf(gen(p));
          var pairs = 0;
          for (var i = 1; i < gym.length; i++) {
            if (daysBetween(gym[i - 1].date, gym[i].date) != 1) continue;
            if (daysBetween(gym[i].date, race) <= 10) pairs++;
            expect(gym[i].templateId, isNot(gym[i - 1].templateId), reason: '$eq $focus ${gym[i].date} ${gym[i].title}');
          }
          expect(pairs, greaterThan(0), reason: '$eq $focus: the race window has consecutive gym days');
          for (final w in gym.where((w) => daysBetween(w.date, race) <= 10)) {
            final t = byId(w.templateId)!;
            // (A full-body alternate goes without its leg work.)
            expect(!legHeavyProgram(t) || w.gymMods.contains(gymModNoLegs), isTrue, reason: '$eq ${w.date} ${w.title}');
            expect(exOf(w, p).where((e) => classifyLift(e.exId, e.name).lower), isEmpty, reason: '$eq ${w.date} ${w.title}');
          }
        }
      }
    });

    test('G3V-2 a refill never lacks its program: missing built-ins are planned with and saved', () {
      for (final eq in ['home', 'bodyweight']) {
        final base = prof(TrainingFocus.gym, 'intermediate', [1, 2, 4, 5], a: {'equipment': eq, 'planWeeks': 8});
        final p = withPlanMeta(base, start, 8);
        final plan = gen(p, weeks: 8);
        final thu = addDays(start, 10); // Thursday of week 2
        final deleted = plan.firstWhere((w) => sameDay(w.date, thu) && w.sport == Sport.gym);
        final rest = [
          for (final w in plan)
            if (w.id != deleted.id) w,
        ];
        // An existing user's list: the programs of an older version (no upper / lower ones).
        final old = templates.where((t) => !const {'home_upper', 'home_lower', 'bw_upper', 'bw_lower'}.contains(t.key)).toList();
        final gaps = PlanGaps(l, p, plans: rest, now: addDays(start, 7), templates: old);
        final fill = gaps.find().where((f) => f.plan.sport == Sport.gym && sameDay(f.plan.date, thu)).single;
        final t = gaps.addedTemplates.where((t) => t.id == fill.plan.templateId).single;
        expect(t.key, byId(deleted.templateId)!.key);
        expect(plannedGymExercises(fill.plan, t), isNotEmpty);
        // The recalibration saves it with the refill.
        final r = Recalibrator(l, p, plans: rest, sessions: const [], now: addDays(start, 7), templates: old).run();
        final added = r.additions.where((a) => a.sport == Sport.gym).toList();
        expect(added, isNotEmpty, reason: eq);
        for (final a in added) {
          expect([...old, ...r.templatesToSave].any((t) => t.id == a.templateId), isTrue, reason: '$eq ${a.date} ${a.title}');
        }
        expect(r.without({...r.changes}).templatesToSave, isEmpty);
      }
    });

    test('G3V-3 pure strength day plan: at most maxPlanDays gym days, the rest days spread', () {
      for (final (level, max) in [('beginner', 4), ('intermediate', 5), ('advanced', 6)]) {
        final p = prof(
          TrainingFocus.gym,
          level,
          [1, 2, 3, 4, 5, 6, 7],
          a: {
            'setupMode': 'advanced',
            'dayPlan': {
              for (var d = 1; d <= 7; d++) d: [Sport.gym],
            },
          },
        );
        final days = PlanGenerator.scheduleOf(p).keys.toList()..sort();
        expect(days.length, max, reason: level);
        // Never three rest days in a row (spread).
        final rest = [
          for (var d = 1; d <= 7; d++)
            if (!days.contains(d)) d,
        ];
        for (final d in rest) {
          expect(rest.contains(d % 7 + 1) && rest.contains((d + 1) % 7 + 1), isFalse, reason: '$level $days');
        }
        final plan = gen(p, weeks: 3);
        for (var w = 0; w < 3; w++) {
          final week = {
            for (final x in plan)
              if (daysBetween(start, x.date) ~/ 7 == w) x.date.weekday,
          };
          expect(week.length, lessThanOrEqualTo(max), reason: '$level week $w');
        }
      }
      // Other focuses keep their day plan.
      final hybrid = prof(
        TrainingFocus.hybrid,
        'beginner',
        [1, 2, 3, 4, 5, 6, 7],
        a: {
          'setupMode': 'advanced',
          'dayPlan': {
            for (var d = 1; d <= 7; d++) d: d.isOdd ? [Sport.run, Sport.gym] : [Sport.gym],
          },
        },
      );
      expect(PlanGenerator.scheduleOf(hybrid).values.expand((x) => x).where((s) => s == Sport.gym).length, 7);
    });

    test('G3V-4 the A / B repair puts no leg day next to a leg day', () {
      for (final days in [
        [1, 3, 5],
        [1, 2, 3, 5, 6],
        [1, 2, 4, 6],
      ]) {
        final p = prof(TrainingFocus.gym, 'advanced', days, a: {'gymSplit': 'ulppl'});
        final s = PlanGenerator.suggestedGymWeeks(p, templates);
        final cycle = [for (final d in s.a.keys.toList()..sort()) s.a[d]!, for (final d in s.b.keys.toList()..sort()) s.b[d]!];
        bool legs(String ref) => legHeavyKeys.contains(gymRefKey(ref));
        for (var i = 0; i < cycle.length; i++) {
          final next = cycle[(i + 1) % cycle.length];
          expect(cycle[i], isNot(next), reason: '$days $cycle');
          expect(legs(cycle[i]) && legs(next), isFalse, reason: '$days $cycle');
        }
      }
    });

    test('G3V-5 notes match the workout: home swaps, bodyweight progression, linear only with fixed steps', () {
      for (final eq in ['home', 'bodyweight']) {
        for (final days in [
          [1, 3, 5],
          [1, 2, 4, 5],
        ]) {
          final p = prof(
            TrainingFocus.gym,
            'beginner',
            days,
            a: {
              'equipment': eq,
              'limitations': ['back'],
            },
          );
          for (final w in gymOf(gen(p, weeks: 3))) {
            final ex = exOf(w, p);
            expect(w.description, isNot(contains(l.healthGymBackSwapNote)), reason: '$eq ${w.title}');
            expect(w.description, isNot(contains(l.wGymProgressNoteBw)), reason: '$eq ${w.title}');
            expect(w.description, isNot(contains(l.wGymProgressNoteLinear)), reason: '$eq ${w.title}');
            final bwOnly = ex.every((e) => e.bw ?? classifyLift(e.exId, e.name).bodyweight);
            if (bwOnly && !w.gymMods.contains(gymModNoAxial)) expect(w.description, isNot(contains(l.healthGymBackNote)));
            if (w.gymMods.contains(gymModNoAxial)) expect(w.description, contains(l.healthGymBackSwapNoteHome));
          }
        }
      }
      // A barbell beginner keeps the linear note.
      expect(gymOf(gen(prof(TrainingFocus.gym, 'beginner', [1, 3, 5]), weeks: 2)).first.description, contains(l.wGymProgressNoteLinear));
    });

    test('G3V-6 a 30 min day leaves out the last accessories, never a compound lift or a set', () {
      for (final split in ['fullbody', 'upperlower', 'ppl']) {
        final p = prof(TrainingFocus.gym, 'intermediate', [1, 2, 4, 5, 6], a: {'sessionMinutes': 30, 'gymSplit': split});
        var shortened = 0;
        for (final w in gymOf(gen(p, weeks: 4))) {
          final program = byId(w.templateId)!.exercises;
          final ex = exOf(w, p);
          expect(w.durationMin, estimateGymMinutes(ex));
          if (!w.gymMods.any((m) => m.startsWith(gymModShortPrefix))) continue;
          shortened++;
          expect(w.description, contains(l.wGymShortNote(30)));
          final kept = {for (final e in ex) e.exId};
          for (final e in program) {
            if (classifyLift(e.exId, e.name).isCompound) expect(kept, contains(e.exId), reason: '$split ${w.title} ${e.name}');
          }
          for (final e in ex) {
            final o = program.where((x) => x.exId == e.exId).firstOrNull;
            if (o != null) expect(e.workSets.length, o.workSets.length, reason: '$split ${w.title} ${e.name}');
          }
          if (w.durationMin > 30) {
            expect(ex.where((e) => !classifyLift(e.exId, e.name).isCompound), isEmpty, reason: '$split ${w.title}');
          }
        }
        expect(shortened, greaterThan(0), reason: split);
      }
    });
  });
}
