import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/builtin_upgrade.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/shell/builtin_dup_cleanup_sync.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/guest_merge.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_service.dart';

/// Owner report r10: "When I overwrite a standard gym program, it sometimes just gets restored
/// under the same name without me importing it – I then have 2× Push, the changed one and the
/// standard program." Built-ins were added automatically whenever no program carried their key –
/// but "restore the originals" and the guest transfer take the key off the athlete's version, an
/// athlete may rebuild a standard program as their own, and an unloaded / empty program list has
/// no keys at all.

class _Repo extends Repository {
  _Repo({this.server}) : super('test');
  final List<WorkoutTemplate>? server;
  var _n = 0;
  var serverReads = 0;
  final saved = <WorkoutTemplate>[];
  @override
  String newId() => 'new${_n++}';
  @override
  Future<List<WorkoutTemplate>?> templatesFromServer() async {
    serverReads++;
    return server;
  }

  List<PlannedWorkout> serverPlans = const [];
  List<Session> serverSessions = const [];
  final deleted = <String>{};
  final updated = <String, Map<String, dynamic>>{};
  @override
  Future<List<PlannedWorkout>> plansFromServer() async => serverPlans;
  @override
  Future<List<Session>> sessionsFromServer() async => serverSessions;
  @override
  Future<void> deleteTemplates(Iterable<String> ids) async => deleted.addAll(ids);
  @override
  Future<void> updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) async =>
      updated
        ..addAll(templates)
        ..addAll(plans);
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async => saved.addAll(list);
  @override
  Future<void> replacePlans(Iterable<String> remove, List<PlannedWorkout> plan) async {}
  @override
  void saveProfile(UserProfile p) {}
}

final _l = lookupAppLocalizations(const Locale('de'));
final _start = DateTime(2026, 11, 9); // Monday

List<WorkoutTemplate> _builtins({bool de = true, String prefix = 'b'}) {
  var i = 0;
  return defaultTemplates(() => '$prefix${i++}', de: de);
}

WorkoutTemplate _byKey(List<WorkoutTemplate> all, String k) => all.firstWhere((t) => t.key == k);

/// One more set on the first exercise – the athlete's change.
WorkoutTemplate _edited(WorkoutTemplate t) {
  final ex = [for (final e in t.exercises) e.copy()];
  ex.first.sets.add(ex.first.sets.first.copy());
  return t.copyWith(exercises: ex);
}

WorkoutTemplate _with(WorkoutTemplate t, Map<String, dynamic> m, {String? id}) => WorkoutTemplate.fromMap(id ?? t.id, {...t.toMap(), ...m});

/// The athlete's edits that leave the plan-relevant fields (work sets, rep ranges, rest) as shipped.
WorkoutTemplate _warmUp(WorkoutTemplate t, {String? id}) {
  final ex = [for (final e in t.exercises) e.copy()];
  ex.first.sets.insert(0, GymSet(reps: 10, type: SetType.warmup));
  return WorkoutTemplate.fromMap(id ?? t.id, t.copyWith(exercises: ex).toMap());
}

WorkoutTemplate _noted(WorkoutTemplate t, {String? id}) {
  final ex = [for (final e in t.exercises) e.copy()];
  ex.first.note = 'Griff schulterbreit';
  return WorkoutTemplate.fromMap(id ?? t.id, t.copyWith(exercises: ex).toMap());
}

WorkoutTemplate _described(WorkoutTemplate t, {String? id}) => _with(t, {'description': 'Mein Drücktag'}, id: id);

UserProfile _ppl({Map<String, dynamic> extra = const {}}) => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.gym,
  birthYear: 1990,
  trainingDays: const [1, 3, 5],
  goals: const ['strength'],
  athlete: const AthleteData(gymSplit: 'ppl').merge(extra),
);

Set<String> _keys(List<WorkoutTemplate> l) => {for (final t in l) t.key!};

PlannedWorkout _plan(String id, String templateId, {String status = 'planned'}) =>
    PlannedWorkout(id: id, date: _start, sport: Sport.gym, title: 'Push', templateId: templateId, status: status);

Session _session(String templateId) =>
    Session(id: 's1', sport: Sport.gym, title: 'Push', start: _start, durationSec: 3600, templateId: templateId);

void main() {
  final pplKeys = PlanGenerator.gymKeysFor(_ppl()).toSet();

  test('the PPL profile needs the three PPL programs', () {
    expect(pplKeys, containsAll(['ppl_push', 'ppl_pull', 'ppl_legs']));
  });

  group('no automatic second copy next to the athlete\'s version', () {
    test('an edited built-in keeps its key: nothing is added', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final mine = [for (final t in all) t.id == push.id ? _edited(t) : t];
      expect(missingBuiltins(mine, () => 'x', de: true, only: pplKeys), isEmpty);
      // Also renamed.
      final renamed = [for (final t in mine) t.id == push.id ? t.copyWith(name: 'Mein Push') : t];
      expect(missingBuiltins(renamed, () => 'x', de: true, only: pplKeys), isEmpty);
    });

    test('after a restore the athlete deleted the original and named their version "Push" again', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final mine = [for (final t in all) t.id == push.id ? _edited(t) : t];
      final restore = planBuiltinRestore(mine, () => 'r', de: true, ownSuffix: 'eigene', folderKeys: {'ppl'});
      expect(restore.add.map((t) => t.key), ['ppl_push']);
      final own = restore.keep.single;
      expect(own.key, isNull);
      expect(own.origKey, 'ppl_push');
      expect(own.name, 'Push (eigene)');
      // The athlete deletes the restored original and renames their version back.
      final after = [
        for (final t in mine)
          if (t.id != push.id) t,
        _with(own, {'name': 'Push'}),
      ];
      expect(missingBuiltins(after, () => 'x', de: true, only: pplKeys), isEmpty, reason: 'no second "Push"');
      // The plan uses the athlete's version for the Push days.
      final plan = PlanGenerator(_l, _ppl(), after, () => 'p').generate(start: _start, weeks: 2);
      final pushDays = plan.where((p) => p.sport == Sport.gym && p.templateId == own.id);
      expect(pushDays, isNotEmpty);
      expect(plan.where((p) => p.sport == Sport.gym && p.templateId == null), isEmpty);
    });

    test('a changed built-in from the guest transfer ("Push (custom)", origKey) stands for the built-in', () {
      final all = [
        for (final t in _builtins())
          if (t.key != 'ppl_push') t,
        _with(_edited(_byKey(_builtins(), 'ppl_push')), {'key': null, 'origKey': 'ppl_push', 'name': 'Push (custom)'}, id: 'g'),
      ];
      expect(programForBuiltin(all, 'ppl_push')?.id, 'g');
      expect(missingBuiltins(all, () => 'x', de: true, only: pplKeys), isEmpty);
    });

    test('a standard program rebuilt as an own program (duplicated, edited, original deleted)', () {
      for (final de in [false, true]) {
        final all = _builtins(de: de);
        final push = _byKey(all, 'ppl_push');
        // A copy carries neither the key nor origKey.
        final copy = _with(_edited(push), {'key': null, 'origKey': null}, id: 'c');
        final mine = [
          for (final t in all)
            if (t.id != push.id) t,
          copy,
        ];
        expect(missingBuiltins(mine, () => 'x', de: de, only: pplKeys), isEmpty);
        expect(programForBuiltin(mine, 'ppl_push')?.id, 'c');
        // Name ignoring case and blanks.
        final lower = [for (final t in mine) t.id == 'c' ? t.copyWith(name: ' push ') : t];
        expect(programForBuiltin(lower, 'ppl_push')?.id, 'c');
      }
    });

    test('a shared name ("Beine": PPL and bro split) counts only in that built-in\'s standard folder', () {
      final all = _builtins();
      final legs = _byKey(all, 'ppl_legs');
      final ownLegs = _with(_edited(legs), {'key': null}, id: 'own');
      final base = [
        for (final t in all)
          if (t.key != 'ppl_legs' && t.key != 'bro_legs') t,
      ];
      // In the PPL folder: stands for the PPL legs day, not for the bro split's.
      final inPpl = [...base, ownLegs];
      expect(programForBuiltin(inPpl, 'ppl_legs')?.id, 'own');
      expect(programForBuiltin(inPpl, 'bro_legs'), isNull);
      // In an own folder: neither (German name; the English pre-key "Legs" still maps to PPL).
      final elsewhere = [
        ...base,
        _with(ownLegs, {'folder': 'Mein Plan'}),
      ];
      expect(programForBuiltin(elsewhere, 'ppl_legs'), isNull);
      expect(programForBuiltin(elsewhere, 'bro_legs'), isNull);
    });

    test('another built-in\'s program never stands in (the bro split\'s "Legs" is not the PPL legs day)', () {
      final all = _builtins(de: false);
      final noPplLegs = [
        for (final t in all)
          if (t.key != 'ppl_legs') t,
      ];
      expect(programForBuiltin(noPplLegs, 'ppl_legs'), isNull);
      expect(_keys(missingBuiltins(noPplLegs, () => 'x', only: pplKeys)), {'ppl_legs'});
      // Nor an own program of another sport.
      final run = WorkoutTemplate(id: 'r', name: 'Push', sport: Sport.run);
      expect(programForBuiltin([run], 'ppl_push'), isNull);
    });

    test('pre-key programs ("Push" stored without key) still count – also for adding', () {
      final legacy = [
        WorkoutTemplate(id: 'a', name: 'Push', sport: Sport.gym, exercises: _byKey(_builtins(), 'ppl_push').exercises),
        WorkoutTemplate(id: 'b', name: 'Pull', sport: Sport.gym, exercises: _byKey(_builtins(), 'ppl_pull').exercises),
        WorkoutTemplate(id: 'c', name: 'Legs', sport: Sport.gym, exercises: _byKey(_builtins(), 'ppl_legs').exercises),
      ];
      expect(missingBuiltins(legacy, () => 'x', only: pplKeys), isEmpty);
    });

    test('the plan replacement reads the server when the program list is empty (not loaded / empty cache)', () async {
      PlanService.reset();
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final server = [for (final t in all) t.id == push.id ? _edited(t) : t];
      final repo = _Repo(server: server);
      await PlanService.replacePlan(repo: repo, l: _l, profile: _ppl(), templates: const [], existing: const [], start: _start, weeks: 2);
      expect(repo.serverReads, 1);
      expect(repo.saved, isEmpty, reason: 'the athlete has every PPL program – none is added again');
    });

    test('offline with an empty list the built-ins are still added (a new athlete needs them)', () async {
      PlanService.reset();
      final repo = _Repo();
      await PlanService.replacePlan(repo: repo, l: _l, profile: _ppl(), templates: const [], existing: const [], start: _start, weeks: 2);
      expect(_keys(repo.saved), pplKeys);
    });

    test('a runner without programs does not wait for the server', () async {
      PlanService.reset();
      final repo = _Repo();
      await PlanService.replacePlan(
        repo: repo,
        l: _l,
        profile: const UserProfile(level: 'intermediate', focus: TrainingFocus.run, trainingDays: [1, 3, 5], onboarded: true),
        templates: const [],
        existing: const [],
        start: _start,
        weeks: 2,
      );
      expect(repo.serverReads, 0);
    });

    test('the program upgrade never touches an edited built-in', () {
      final push = _edited(_byKey(_builtins(), 'ppl_push'));
      for (final g in gymGoals) {
        expect(upgradedBuiltinExercises(push, g), isNull);
      }
    });
  });

  group('restore with the athlete\'s version standing for the built-in', () {
    test('an own version without key is kept as "Push (eigene)", the plan settings keep it', () {
      final all = _builtins();
      final mine = [
        for (final t in all)
          if (t.key != 'ppl_push') t,
        _with(_edited(_byKey(all, 'ppl_push')), {'key': null, 'origKey': 'ppl_push'}, id: 'own'),
      ];
      final r = planBuiltinRestore(mine, () => 'r', de: true, ownSuffix: 'eigene', folderKeys: {'ppl'});
      expect(r.add.map((t) => t.key), ['ppl_push']);
      expect(r.keep.single.id, 'own');
      expect(r.keep.single.name, 'Push (eigene)');
      expect(r.changed, {'ppl_push'});
      final a = const AthleteData(gymAssign: true, gymPlanA: {1: 'key:ppl_push'});
      expect(restoreAssignmentPatch(a, r, mine), {
        'gymPlanA': {1: 'id:own'},
      });
    });
  });

  test('the plan settings key reference finds the own version of the athlete (as the plan does)', () {
    final all = _builtins();
    final own = _with(_edited(_byKey(all, 'ppl_push')), {'key': null, 'origKey': 'ppl_push'}, id: 'own');
    final mine = [
      for (final t in all)
        if (t.key != 'ppl_push') t,
      own,
    ];
    expect(gymProgramOf('key:ppl_push', mine, builtins: all)?.id, 'own');
    expect(gymProgramOf('key:ppl_push', all)?.key, 'ppl_push');
  });

  group('guest transfer', () {
    test('the guest\'s unchanged copy maps to the target\'s own version (not left for the plan to re-add)', () {
      final guestT = _builtins(prefix: 'G');
      final targetT = [
        for (final t in _builtins(prefix: 'T'))
          if (t.key != 'ppl_push') t,
        _with(_edited(_byKey(_builtins(), 'ppl_push')), {'key': null, 'origKey': 'ppl_push'}, id: 'own'),
      ];
      var i = 0;
      final t = guestTransfer(
        guest: AccountData(
          user: const {'onboarded': true},
          collections: {
            'templates': [for (final x in guestT) (x.id, x.toMap())],
          },
        ),
        target: AccountData(
          user: const {'onboarded': true},
          collections: {
            'templates': [for (final x in targetT) (x.id, x.toMap())],
          },
        ),
        newId: () => 'n${i++}',
        today: _start,
        de: true,
      );
      expect(t.writes.where((w) => w.$1 == 'templates'), isEmpty);
      expect(t.ids[_byKey(guestT, 'ppl_push').id], 'own');
    });
  });

  group('one-off cleanup of existing duplicates', () {
    BuiltinDuplicateCleanup clean(
      List<WorkoutTemplate> t, {
      List<PlannedWorkout> plans = const [],
      List<Session> sessions = const [],
      AthleteData athlete = const AthleteData(),
    }) => builtinDuplicateCleanup(t, plans: plans, sessions: sessions, athlete: athlete, suffix: 'Standard');

    List<WorkoutTemplate> apply(List<WorkoutTemplate> t, BuiltinDuplicateCleanup c) => [
      for (final x in t)
        if (!c.delete.contains(x.id)) c.templates[x.id] == null ? x : _with(x, c.templates[x.id]!),
    ];

    test('a fresh library and the restore\'s result are left alone', () {
      final all = _builtins();
      expect(clean(all).isEmpty, isTrue);
      final mine = [for (final t in all) t.key == 'ppl_push' ? _edited(t) : t];
      final r = planBuiltinRestore(mine, () => 'r', de: true, ownSuffix: 'eigene', folderKeys: {'ppl'});
      final restored = [for (final t in mine) r.keep.where((k) => k.id == t.id).firstOrNull ?? t, ...r.add];
      expect(clean(restored).isEmpty, isTrue, reason: '"Push (eigene)" + "Push": restored on purpose');
    });

    test('an untouched copy with the key next to the changed one: removed, its open workouts move', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final dup = WorkoutTemplate.fromMap('dup', push.toMap());
      final mine = [for (final t in all) t.id == push.id ? _edited(t) : t, dup];
      final c = clean(mine, plans: [_plan('p1', 'dup'), _plan('p2', push.id)]);
      expect(c.delete, {'dup'});
      expect(c.templates, isEmpty);
      expect(c.plans, {
        'p1': {'templateId': push.id},
      });
      expect(clean(apply(mine, c)).isEmpty, isTrue, reason: 'idempotent');
    });

    test('next to the athlete\'s own "Push" without key: removed – kept as "Push (Standard)" when a workout used it', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final own = _with(_edited(push), {'key': null, 'origKey': 'ppl_push'}, id: 'own');
      final mine = [
        for (final t in all)
          if (t.id != push.id) t,
        own,
        WorkoutTemplate.fromMap('auto', push.toMap()),
      ];
      expect(clean(mine).delete, {'auto'});

      for (final (plans, sessions, athlete) in [
        (const <PlannedWorkout>[], [_session('auto')], const AthleteData()),
        ([_plan('d', 'auto', status: 'done')], const <Session>[], const AthleteData()),
        (const <PlannedWorkout>[], const <Session>[], const AthleteData(gymAssign: true, gymPlanA: {1: 'id:auto'})),
      ]) {
        final c = clean(mine, plans: [...plans, _plan('open', 'auto')], sessions: sessions, athlete: athlete);
        expect(c.delete, isEmpty);
        expect(c.templates, {
          'auto': {'key': null, 'name': 'Push (Standard)'},
        });
        expect(c.plans, {
          'open': {'templateId': 'own'},
        });
        final after = apply(mine, c);
        expect(programForBuiltin(after, 'ppl_push')?.id, 'own');
        expect(missingBuiltins(after, () => 'x', de: true, only: pplKeys), isEmpty);
        expect(clean(after, plans: plans, sessions: sessions, athlete: athlete).isEmpty, isTrue);
      }
    });

    test('a duplicated standard folder next to the originals stays; a rebuilt "Push" in the same folder wins', () {
      final all = _builtins();
      final ppl = all.where((t) => t.key?.startsWith('ppl_') ?? false).toList();
      final copies = [
        for (final t in ppl) _with(t, {'key': null, 'origKey': null, 'folder': 'Push Pull Beine 2'}, id: '${t.id}c'),
      ];
      expect(clean([...all, ...copies]).isEmpty, isTrue);

      final push = _byKey(all, 'ppl_push');
      final rebuilt = _with(_edited(push), {'key': null}, id: 'mine');
      final c = clean([...all, rebuilt]);
      expect(c.delete, {push.id});
    });

    test('an own version under another name is not a duplicate of the original', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final mine = [
        for (final t in all)
          if (t.id != push.id) t,
        _with(_edited(push), {'key': null, 'origKey': 'ppl_push', 'name': 'Push schwer'}, id: 'own'),
        WorkoutTemplate.fromMap('auto', push.toMap()),
      ];
      expect(clean(mine).isEmpty, isTrue);
    });

    test('identical twins (added twice from an empty list): the first stays', () {
      final all = _builtins();
      final twins = [...all, for (final t in all.where((t) => pplKeys.contains(t.key))) WorkoutTemplate.fromMap('${t.id}x', t.toMap())];
      final c = clean(twins);
      expect(c.delete, {for (final t in all.where((t) => pplKeys.contains(t.key))) '${t.id}x'});
      final after = apply(twins, c);
      expect(after.length, all.length);
    });

    group('the athlete\'s warm-ups, notes and description are never deleted (review r10 N2)', () {
      final edits = <String, WorkoutTemplate Function(WorkoutTemplate, {String? id})>{
        'warm-up': _warmUp,
        'note': _noted,
        'description': _described,
      };

      test('isUntouchedBuiltin ignores them, isPristineBuiltin does not', () {
        final push = _byKey(_builtins(), 'ppl_push');
        expect(isPristineBuiltin(push), isTrue);
        expect(isPristineBuiltin(_byKey(_builtins(de: false), 'ppl_push')), isTrue);
        for (final e in edits.entries) {
          final t = e.value(push);
          expect(isUntouchedBuiltin(t), isTrue, reason: e.key);
          expect(isPristineBuiltin(t), isFalse, reason: e.key);
        }
        final weighted = [for (final e in push.exercises) e.copy()];
        weighted.first.sets.first.weight = 60;
        expect(isPristineBuiltin(push.copyWith(exercises: weighted)), isFalse);
      });

      test('twin branch: an edited keyed Push next to an automatic copy – in either list order only the copy goes', () {
        for (final e in edits.entries) {
          final all = _builtins();
          final push = _byKey(all, 'ppl_push');
          final mine = e.value(push, id: 'mine');
          final auto = WorkoutTemplate.fromMap('auto', push.toMap());
          final rest = [
            for (final t in all)
              if (t.id != push.id) t,
          ];
          for (final order in [
            [auto, mine],
            [mine, auto],
          ]) {
            final c = clean([...rest, ...order], plans: [_plan('open', 'auto')]);
            expect(c.delete, {'auto'}, reason: e.key);
            expect(c.plans, {
              'open': {'templateId': 'mine'},
            }, reason: e.key);
          }
        }
      });

      test('two edited keyed copies (each with own warm-ups / notes) both stay', () {
        final all = _builtins();
        final push = _byKey(all, 'ppl_push');
        final mine = [
          for (final t in all)
            if (t.id != push.id) t,
          _warmUp(push, id: 'a'),
          _noted(push, id: 'b'),
        ];
        expect(clean(mine).isEmpty, isTrue);
      });

      test('changed branch: a keyed copy with only notes / warm-ups is not deleted next to an edited one', () {
        for (final e in edits.entries) {
          final all = _builtins();
          final push = _byKey(all, 'ppl_push');
          final mine = [
            for (final t in all)
              if (t.id != push.id) t,
            _edited(push),
            e.value(push, id: 'noted'),
          ];
          expect(clean(mine).isEmpty, isTrue, reason: e.key);
        }
      });

      test('same-folder rebuild: the keyed original carrying the athlete\'s notes / description stays', () {
        for (final e in edits.entries) {
          final all = _builtins();
          final push = _byKey(all, 'ppl_push');
          final mine = [
            for (final t in all)
              if (t.id != push.id) t,
            e.value(push),
            _with(_edited(push), {'key': null}, id: 'rebuilt'),
          ];
          expect(clean(mine).isEmpty, isTrue, reason: e.key);
        }
      });
    });

    test('twins: the one a workout refers to stays; copies differing in language both stay', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final mine = [...all, WorkoutTemplate.fromMap('x', push.toMap())];
      expect(clean(mine, sessions: [_session(push.id)]).delete, {'x'});
      final c = clean(mine, sessions: [_session('x')]);
      expect(c.delete, {push.id});
      expect(c.templates, isEmpty);

      final en = _byKey(_builtins(de: false, prefix: 'e'), 'ppl_push');
      expect(clean([...all, en]).isEmpty, isTrue, reason: '"Push" (en) and "Push" (de) differ in the description');
    });

    test('a kept "Push (Standard)" next to the keyed version still counts as Push for the gym rotation (origKey)', () {
      final all = _builtins();
      final push = _byKey(all, 'ppl_push');
      final mine = [for (final t in all) t.id == push.id ? _edited(t) : t, WorkoutTemplate.fromMap('auto', push.toMap())];
      final c = clean(mine, sessions: [_session('auto')]);
      expect(c.templates, {
        'auto': {'key': null, 'name': 'Push (Standard)', 'origKey': 'ppl_push'},
      });
      final after = apply(mine, c);
      expect(programForBuiltin(after, 'ppl_push')?.id, push.id, reason: 'the athlete\'s keyed version stays the plan\'s Push');
      expect(clean(after, sessions: [_session('auto')]).isEmpty, isTrue);
    });

    group('runs against the server\'s data (review r10 N2)', () {
      List<WorkoutTemplate> withDup() {
        final all = _builtins();
        final push = _byKey(all, 'ppl_push');
        return [for (final t in all) t.id == push.id ? _edited(t) : t, WorkoutTemplate.fromMap('auto', push.toMap())];
      }

      test('a copy only a workout on the server refers to (not in the local cache) is renamed, not deleted', () async {
        final repo = _Repo(server: withDup())..serverSessions = [_session('auto')];
        final c = await confirmedDuplicateCleanup(repo, athlete: const AthleteData(), suffix: 'Standard');
        expect(c!.delete, isEmpty);
        expect(repo.deleted, isEmpty);
        expect(repo.updated['auto']?['name'], 'Push (Standard)');
      });

      test('server unreachable or empty: nothing is changed', () async {
        for (final server in [null, <WorkoutTemplate>[]]) {
          final repo = _Repo(server: server);
          expect(await confirmedDuplicateCleanup(repo, athlete: const AthleteData(), suffix: 'Standard'), isNull);
          expect(repo.deleted, isEmpty);
          expect(repo.updated, isEmpty);
        }
      });

      test('a duplicate added later (after an earlier repair) is removed too', () async {
        final repo = _Repo(server: withDup());
        final c = await confirmedDuplicateCleanup(repo, athlete: const AthleteData(), suffix: 'Standard');
        expect(c!.delete, {'auto'});
        expect(repo.deleted, {'auto'});
      });
    });
  });
}
