import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/dst_repair.dart';
import 'package:strive/services/health_service.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_service.dart';

/// Records the plan replacement instead of writing to Firestore.
class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  var _n = 0;
  var replaced = 0;
  final saved = <PlannedWorkout>[];
  UserProfile? savedProfile;

  @override
  String newId() => 'id${_n++}';
  @override
  Future<void> replacePlans(List<PlannedWorkout> all, DateTime from, List<PlannedWorkout> plan, {Set<String> keep = const {}}) async {
    replaced++;
    saved.addAll(plan);
  }

  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async {}
  @override
  void saveProfile(UserProfile p) => savedProfile = p;
}

final l = lookupAppLocalizations(const Locale('de'));

/// Whether this machine's time zone has a clock change in the given span (the DST-specific
/// assertions are only meaningful there; the date checks run everywhere).
bool _hasDst(DateTime from, int days) => from.add(Duration(days: days)).hour != 0; // time span

UserProfile _runner({List<int> days = const [1, 3, 5, 7]}) => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.run,
  trainingDays: days,
  longDay: 7,
  onboarded: true,
  athlete: const AthleteData(runWeeklyKm: 30, longestRunKm: 14, planWeeks: 24),
);

void main() {
  group('C1 calendar arithmetic', () {
    test('addDays stays on midnight across both clock changes', () {
      expect(addDays(DateTime(2026, 10, 19), 7), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2027, 3, 22), 7), DateTime(2027, 3, 29));
      expect(addDays(DateTime(2026, 10, 26), -1), DateTime(2026, 10, 25));
      expect(addDays(DateTime(2026, 12, 28), 7), DateTime(2027, 1, 4));
      expect(startOfWeek(DateTime(2026, 10, 28, 15)), DateTime(2026, 10, 26));
      expect(startOfWeek(DateTime(2027, 3, 28, 23)), DateTime(2027, 3, 22));
    });

    test('daysBetween counts calendar days (a 23 h / 25 h day is one day)', () {
      expect(daysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 29)), 2);
      expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
      expect(daysBetween(DateTime(2027, 3, 22), DateTime(2027, 3, 29)) ~/ 7, 1);
      expect(daysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 19)), -7);
      expect(daysBetween(DateTime(2026, 10, 25, 23), DateTime(2026, 10, 26, 1)), 1);
    });

    for (final start in [DateTime(2026, 10, 5), DateTime(2027, 3, 8), DateTime(2026, 9, 2)]) {
      test('plans across 25 Oct 2026 / 28 Mar 2027 keep midnight and their weekdays (start ${dayKey(start)})', () {
        var n = 0;
        final p = _runner();
        final plan = PlanGenerator(l, p, const [], () => 'p${n++}').generate(start: start, weeks: 30);
        expect(plan, isNotEmpty);
        expect(plan.any((w) => w.date.isAfter(DateTime(2026, 10, 25)) || w.date.isAfter(DateTime(2027, 3, 28))), isTrue);
        for (final w in plan) {
          expect((w.date.hour, w.date.minute), (0, 0), reason: '${w.title} ${w.date}');
          expect(p.trainingDays, contains(w.date.weekday), reason: '${w.title} on ${w.date}');
        }
        // Round trip through the stored day key keeps the day.
        for (final w in plan) {
          expect(PlannedWorkout.fromMap(w.id, w.toMap()).date, dayOnly(w.date));
        }
      });
    }

    test('no Duration(days:) / .inDays on day values in lib/ (real time spans are marked)', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final path = f.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart') || path.contains('/l10n/gen/') || path.endsWith('core/format.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final s = lines[i];
          if ((s.contains('Duration(days') || s.contains('.inDays')) && !s.contains('// time span')) {
            offenders.add('$path:${i + 1}: ${s.trim()}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'use addDays / daysBetween for day values, or mark a real time span with "// time span"');
    });
  });

  group('C1 DST repair migration', () {
    final start = DateTime(2026, 10, 5);
    const weeks = 12;

    test('finds the shifted days of a plan over the autumn change (DST zones only)', () {
      final shift = DstRepair.shiftedKeys(start, weeks);
      if (!_hasDst(DateTime(2026, 10, 19), 7)) {
        expect(shift, isEmpty);
        return;
      }
      expect(shift['2026-10-25'], '2026-10-26');
      expect(shift['2026-11-01'], '2026-11-02');
      expect(shift.containsKey('2026-10-24'), isFalse);
      // Plans starting in winter time are not affected by the spring change.
      expect(DstRepair.shiftedKeys(DateTime(2027, 1, 4), 20), isEmpty);
    });

    test('moves shifted not-done workouts one day later, keeps done ones, is idempotent', () {
      if (!_hasDst(DateTime(2026, 10, 19), 7)) return; // nothing to repair without a clock change
      var n = 0;
      final p = _runner();
      final profile = p.copyWith(athlete: p.athlete.merge({'planStart': start, 'planLength': weeks}));
      final good = PlanGenerator(l, profile, const [], () => 'p${n++}').generate(start: start, weeks: weeks);
      // What the old generator stored: shifted day keys after the clock change.
      final back = {for (final e in DstRepair.shiftedKeys(start, weeks).entries) e.value: e.key};
      final doneId = good.firstWhere((w) => back.containsKey(dayKey(w.date))).id;
      final stored = [
        for (final w in good)
          PlannedWorkout.fromMap(w.id, {
            ...w.toMap(),
            'date': back[dayKey(w.date)] ?? dayKey(w.date),
            if (w.id == doneId) 'status': 'done',
          }),
      ];
      final shiftedCount = stored.where((w) => !sameDay(w.date, good.firstWhere((g) => g.id == w.id).date)).length;
      expect(shiftedCount, greaterThan(5));

      final u = DstRepair.updates(stored, profile);
      expect(u.containsKey(doneId), isFalse, reason: 'done workouts keep their date');
      final repaired = [
        for (final w in stored) PlannedWorkout.fromMap(w.id, {...w.toMap(), ...?u[w.id]}),
      ];
      for (final w in repaired) {
        final g = good.firstWhere((x) => x.id == w.id);
        if (w.id == doneId) continue;
        expect(dayKey(w.date), dayKey(g.date), reason: w.title);
      }
      // Second run: the plan matches its pattern again – nothing to do.
      expect(DstRepair.updates(repaired, profile), isEmpty);
      // A correct plan is never touched.
      expect(DstRepair.updates(good, profile), isEmpty);
    });

    test('no plan metadata → nothing to repair', () {
      expect(DstRepair.updates(const [], _runner()), isEmpty);
    });
  });

  group('C2 profile write', () {
    test('replaces every top-level field (nested maps lose removed keys, cleared fields are written)', () {
      final p = _runner().copyWith(
        athlete: const AthleteData(
          dayPlan: {
            1: [Sport.run],
          },
          raceTimes: {'5k': 1500},
        ),
      );
      final (m, opts) = Repository.profileWrite(p);
      expect(opts, isA<SetOptions>());
      final athlete = m['athlete'] as Map<String, dynamic>;
      expect(athlete['dayPlan'], {
        '1': ['run'],
      });
      // A cleared plan start is absent from the replaced athlete map (so it is deleted).
      expect(athlete.containsKey('planStart'), isFalse);
      expect(m.containsKey('gcalCalendars'), isFalse);
      expect(m.containsKey('hcDeleted'), isFalse);
      // mergeFields = exactly the profile's fields: the profile is replaced, separately
      // written fields (gcalCalendars, hcDeleted) stay.
      expect(opts.mergeFields?.map((f) => f.components.join('.')).toSet(), m.keys.toSet());
      expect(opts.merge, isNull);
    });

    test('a cleared day plan stays cleared after a round trip', () {
      final a = const AthleteData(
        dayPlan: {
          1: [Sport.run],
          3: [Sport.gym],
        },
      ).merge({'dayPlan': <int, List<Sport>>{}, 'planStart': null});
      expect(a.toMap()['dayPlan'], isEmpty);
      expect(AthleteData.fromMap(a.toMap()).dayPlan, isEmpty);
    });
  });

  group('robust parsing', () {
    test('corrupt profile values fall back instead of throwing', () {
      final p = UserProfile.fromMap({
        'birthYear': '1990',
        'trainingDays': ['1', 3, 'x', 9],
        'maxHr': 185.0,
        'imperial': 'yes',
        'athlete': {
          'dayPlan': {
            '1': ['run'],
            'x': ['gym'],
            '3': 'bad',
          },
          'dayMinutes': {'2': '45', 'mon': 60, '4': null},
          'raceTimes': {'5k': '1500', '10k': 'fast'},
          'oneRm': {'squat': '100,5'},
          'ftp': '250',
        },
      });
      expect(p.birthYear, 1990);
      expect(p.trainingDays, [1, 3]);
      expect(p.maxHr, 185);
      expect(p.imperial, isFalse);
      expect(p.athlete.dayPlan, {
        1: [Sport.run],
      });
      expect(p.athlete.dayMinutes, {2: 45});
      expect(p.athlete.raceTimes, {'5k': 1500});
      expect(p.athlete.oneRm, {'squat': 100.5});
      expect(p.athlete.ftp, 250);
    });

    test('documents without their key fields are skipped', () {
      expect(PlannedWorkout.tryFromMap('a', {'status': 'done'}), isNull);
      expect(PlannedWorkout.tryFromMap('a', {'date': 'garbage', 'sport': 'run'}), isNull);
      expect(PlannedWorkout.tryFromMap('a', {'date': '2026-11-10', 'sport': 'run'})?.date, DateTime(2026, 11, 10));
      expect(Session.tryFromMap('s', {'title': 'x'}), isNull);
      expect(WorkoutTemplate.tryFromMap('t', {'exercises': []}), isNull);
      final s = Session.tryFromMap('s', {
        'sport': 'run',
        'start': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'route': [
          {'a': 1, 'o': 2},
          {'a': 'x'},
          'bad',
        ],
        'splits': [300, '310', null],
        'rpe': 6.0,
      });
      expect(s!.route, [
        [1.0, 2.0],
      ]);
      expect(s.splits, [300, 310]);
      expect(s.rpe, 6);
    });
  });

  test('plan history pruning keeps ≤ 300 entries and none older than 180 days', () {
    final now = DateTime(2026, 11, 10);
    final entries = [
      for (var i = 0; i < 320; i++) ('e$i', Timestamp.fromDate(now.subtract(Duration(hours: i)))), // time span
    ];
    final ids = Repository.planLogPruneIds(entries, now);
    expect(ids.length, 20);
    expect(ids.first, 'e300');
    final old = [('new', Timestamp.fromDate(now)), ('old', Timestamp.fromDate(DateTime(2026, 4, 1))), ('bad', null)];
    expect(Repository.planLogPruneIds(old, now), ['old']);
  });

  test('I2 Health Connect imports get a deterministic id', () {
    expect(HealthService.importId('abc-123'), 'hc_abc-123');
    expect(HealthService.importId('a/b c'), 'hc_a_b_c');
    expect(HealthService.importId('x'), HealthService.importId('x'));
  });

  test('I8 PlanService refuses a second replacement while the first is fresh (double tap)', () async {
    PlanService.reset();
    final repo = _FakeRepo();
    Future<int?> run() => PlanService.replacePlan(
      repo: repo,
      l: l,
      profile: _runner(),
      templates: const [],
      existing: const [],
      start: DateTime(2026, 11, 9),
      weeks: 4,
    );
    final first = await run();
    final second = await run();
    expect(first, greaterThan(0));
    expect(second, isNull);
    expect(repo.replaced, 1);
    expect(repo.savedProfile?.athlete.planStart, DateTime(2026, 11, 9));
    expect(repo.savedProfile?.athlete.planLength, 4);
    PlanService.reset();
  });

  test('deepEquals compares Firestore data structurally', () {
    expect(
      deepEquals(
        {
          'a': [
            1,
            {'b': 2},
          ],
        },
        {
          'a': [
            1,
            {'b': 2},
          ],
        },
      ),
      isTrue,
    );
    expect(deepEquals({'a': 1}, {'a': 2}), isFalse);
    expect(deepEquals(null, {}), isFalse);
  });

  test('todayProvider starts at today midnight', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(todayProvider), dayOnly(DateTime.now()));
  });
}
