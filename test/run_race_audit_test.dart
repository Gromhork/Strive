import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Regression tests of the run & race audit (package G1): taper anchored to race day, race-week sessions,
/// one race pace from the goal-pace work to race day, limits and texts.
final l = lookupAppLocalizations(const Locale('en'));
var _n = 0;
String _id() => 'r${_n++}';
final _templates = defaultTemplates(_id);

List<PlannedWorkout> gen(UserProfile p, DateTime start) => PlanGenerator(l, p, _templates, _id).generate(start: start);

UserProfile prof(TrainingFocus f, String level, List<int> days, {Map<String, dynamic> a = const {}, int age = 35, int? longDay}) =>
    UserProfile(
      level: level,
      focus: f,
      birthYear: DateTime.now().year - age,
      experience: {...f.sports},
      trainingDays: days,
      longDay: longDay,
    ).copyWith(athlete: const AthleteData().merge(a));

int out(PlannedWorkout w, DateTime race) => daysBetween(dayOnly(w.date), race);
bool hard(PlannedWorkout w) => w.intensity == 'tempo' || w.intensity == 'intervals';
double mid(WorkoutStep s) => (s.paceMin! + s.paceMax!) / 2;
String show(PlannedWorkout w) => '${dayKey(w.date)} ${w.sport.name} "${w.title}" ${w.intensity} ${w.durationMin}\' [${w.phase}]';

/// Weekly run km by Monday.
Map<DateTime, double> runWeeks(List<PlannedWorkout> plan) {
  final m = <DateTime, double>{};
  for (final w in plan.where((w) => w.sport == Sport.run && w.intensity != 'race')) {
    m[startOfWeek(w.date)] = (m[startOfWeek(w.date)] ?? 0) + runningKm(w);
  }
  return m;
}

/// The race window rules every event plan keeps ([PlanGenerator.raceWindowDays]).
void expectRaceWindow(List<PlannedWorkout> plan, DateTime race, String what) {
  expect(plan.where((w) => w.intensity == 'race').length, 1, reason: what);
  for (final w in plan.where((w) => w.intensity != 'race' && w.sport != Sport.gym)) {
    final d = out(w, race);
    if (d < 1 || d > PlanGenerator.raceWindowDays) continue;
    expect(w.intensity, isNot('long'), reason: '$what: long session $d days before the race: ${show(w)}');
    expect(w.phase, 'taper', reason: '$what: ${show(w)}');
    expect(w.sport == Sport.run && w.intensity == 'moderate', isFalse, reason: '$what: brick in race week ${show(w)}');
    if (d <= 2) {
      expect(hard(w), isFalse, reason: '$what: hard session $d days out ${show(w)}');
      expect(w.durationMin, lessThanOrEqualTo(60), reason: '$what: ${show(w)}');
    }
  }
}

void main() {
  final start = DateTime(2027, 3, 1); // Monday

  group('taper anchored to race day (adapt-1, FUZZ-1, FUZZ-11)', () {
    test('adapt-1: "Plan neu aufsetzen" in the last 24–10 days keeps the taper', () {
      final s0 = DateTime(2026, 11, 16);
      final race = DateTime(2027, 3, 21);
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [2, 4, 6, 7],
        a: {
          'eventDistance': 'm',
          'eventDate': race,
          'raceTimes': {'hm': 6600},
          'runWeeklyKm': 35.0,
          'longestRunKm': 16.0,
        },
      );
      final orig = gen(p, s0);
      final origWeeks = runWeeks(orig);
      final peakLong = orig.where((w) => w.intensity == 'long').fold(0.0, (m, w) => max(m, runningKm(w)));
      for (final d in [24, 20, 17, 13, 10]) {
        final day = addDays(race, -d);
        final sessions = [
          for (final w in orig.where((w) => w.date.isBefore(day) && w.intensity != 'race'))
            Session(
              id: 's${w.id}',
              sport: w.sport,
              title: w.title,
              start: DateTime(w.date.year, w.date.month, w.date.day, 18),
              durationSec: w.durationMin * 60,
              distanceM: (w.distanceKm ?? 0) * 1000,
              planId: w.id,
            ),
        ];
        final p2 = withReachedVolume(p, plans: orig, sessions: sessions, start: day);
        final re = gen(p2, day);
        final what = 're-created $d days before';
        expectRaceWindow(re, race, what);
        for (final w in re.where((w) => w.intensity != 'race' && out(w, race) <= 20)) {
          expect(w.phase, 'taper', reason: '$what: ${show(w)}');
        }
        for (final w in re.where((w) => w.intensity == 'long' && out(w, race) <= 13)) {
          expect(runningKm(w), lessThanOrEqualTo(peakLong * 0.65 + 0.5), reason: '$what: ${show(w)}');
        }
        // No taper week of the new plan is bigger than the original plan's.
        final weeks = runWeeks(re);
        for (final e in weeks.entries.where((e) => daysBetween(e.key, race) <= 20)) {
          expect(e.value, lessThanOrEqualTo((origWeeks[e.key] ?? 0) * 1.1 + 2), reason: '$what: week ${dayKey(e.key)}');
        }
      }
    });

    test('FUZZ-1: whatever the race weekday – no long, hard or loading session right before the race', () {
      for (var wd = 1; wd <= 7; wd++) {
        final race = addDays(DateTime(2027, 5, 3), wd - 1);
        for (final (ev, f, days, extra) in [
          (
            '10k',
            TrainingFocus.run,
            [2, 4, 6, 7],
            {
              'raceTimes': {'10k': 3000},
            },
          ),
          (
            'hm',
            TrainingFocus.run,
            [1, 3, 5, 7],
            {
              'raceTimes': {'10k': 3000},
            },
          ),
          (
            'm',
            TrainingFocus.run,
            [1, 2, 4, 6],
            {
              'raceTimes': {'hm': 6300},
              'dayMinutes': {6: 180},
            },
          ),
          (
            'ride100',
            TrainingFocus.ride,
            [3, 4, 7],
            {
              'sessionMinutes': 90,
              'dayMinutes': {7: 300},
              'ftp': 250,
            },
          ),
          (
            '70.3',
            TrainingFocus.triathlon,
            [1, 2, 3, 5, 6, 7],
            {
              'sessionMinutes': 90,
              'dayMinutes': {6: 240, 7: 150},
            },
          ),
        ]) {
          final p = prof(f, 'advanced', days, a: {'eventDistance': ev, 'eventDate': race, 'setupMode': 'advanced', ...extra});
          final plan = gen(p, DateTime(2027, 1, 4));
          expectRaceWindow(plan, race, '$ev race on weekday $wd');
        }
      }
    });

    test('FUZZ-1: a Tuesday 10 km – the week before is the race week (≤ ~55 % of the peak week)', () {
      final race = DateTime(2027, 5, 4);
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [2, 4, 6, 7],
        a: {
          'eventDistance': '10k',
          'eventDate': race,
          'raceTimes': {'10k': 3000},
        },
      );
      final weeks = runWeeks(gen(p, start));
      final before = weeks[startOfWeek(addDays(race, -7))]!;
      final peak = weeks.entries.where((e) => e.key.isBefore(startOfWeek(addDays(race, -7)))).fold(0.0, (m, e) => max(m, e.value));
      expect(before, lessThanOrEqualTo(peak * 0.55), reason: 'race-week volume $before vs peak $peak');
    });

    test('FUZZ-11: a race in the plan\'s first week – a race week, not a plan that ignores it', () {
      final race = DateTime(2027, 3, 6); // Saturday of the start week
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [1, 3, 5, 6],
        a: {
          'eventDistance': '10k',
          'eventDate': race,
          'raceTimes': {'10k': 3000},
        },
      );
      final plan = gen(p, start);
      expectRaceWindow(plan, race, 'race in week 1');
      expect(plan.any((w) => w.date.isAfter(race)), isFalse);
      expect(PlanGenerator.phasesFor(p, start: start), ['taper']);
    });
  });

  group('race week (RUN-2, UX-11, FUZZ-7)', () {
    test('RUN-2: long day Friday before a Sunday marathon – an easy run, no "long run" in race week', () {
      final race = DateTime(2027, 6, 27);
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [1, 3, 5],
        a: {
          'eventDistance': 'm',
          'eventDate': race,
          'raceTimes': {'10k': 3120},
          'runWeeklyKm': 35.0,
          'longestRunKm': 16.0,
          'dayMinutes': {5: 210},
        },
        longDay: 5,
      );
      final plan = gen(p, start);
      final fri = plan.firstWhere((w) => sameDay(w.date, addDays(race, -2)));
      expect(fri.intensity, 'easy');
      expect(fri.isKey, isFalse);
      expect(fri.durationMin, lessThanOrEqualTo(45));
    });

    test('FUZZ-7: the shake-out only on a training day (Mo / We / Fr runner, Sunday race: Saturday stays free)', () {
      final race = DateTime(2027, 5, 9);
      final p = prof(TrainingFocus.run, 'intermediate', [1, 3, 5], a: {'eventDistance': '10k', 'eventDate': race});
      final plan = gen(p, start);
      expect(plan.where((w) => sameDay(w.date, addDays(race, -1))), isEmpty);
      final p2 = prof(TrainingFocus.run, 'intermediate', [2, 4, 6], a: {'eventDistance': '10k', 'eventDate': race});
      expect(gen(p2, start).where((w) => sameDay(w.date, addDays(race, -1))).single.title, l.wShakeout);
    });
  });

  group('one race pace (RUN-1, RUN-9, T1, RUN-4)', () {
    UserProfile m13({int? target}) => prof(
      TrainingFocus.run,
      'intermediate',
      [1, 2, 4, 6, 7],
      a: {
        'eventDistance': 'm',
        'eventDate': DateTime(2027, 3, 21),
        'raceTimes': {'hm': 7500},
        'runWeeklyKm': 35.0,
        'longestRunKm': 16.0,
        'sessionMinutes': 75,
        'dayMinutes': {7: 210},
        'limitations': ['heart'],
        if (target != null) 'targetTimeSec': target,
      },
      age: 58,
    );

    void samePace(UserProfile p, String what) {
      final plan = gen(p, DateTime(2026, 11, 16));
      final race = plan.singleWhere((w) => w.intensity == 'race');
      final rp = mid(race.steps.single);
      final mp = [
        for (final w in plan.where((w) => w.intensity != 'race'))
          for (final s in w.steps.where((s) => s.isWork && s.note == l.stepMpNote && s.paceMin != null)) mid(s),
      ];
      expect(mp, isNotEmpty, reason: what);
      for (final x in mp) {
        expect((x - rp).abs(), lessThanOrEqualTo(5), reason: '$what: MP $x vs race $rp');
      }
      expect(race.durationMin, closeTo(rp * 42.195 / 60, 2), reason: what);
    }

    test('RUN-1: marathon without a target – every marathon-pace session at the race-day pace', () => samePace(m13(), 'no target'));
    test('RUN-1: … and with a target', () => samePace(m13(target: 4 * 3600 + 10 * 60), 'target 4:10'));

    test('RUN-9: a conservative target – race paced like the MP work, never slower than easy', () {
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [1, 2, 4, 6, 7],
        a: {
          'eventDistance': 'm',
          'eventDate': DateTime(2027, 3, 7),
          'raceTimes': {'10k': 3120},
          'runWeeklyKm': 40.0,
          'longestRunKm': 18.0,
          'sessionMinutes': 75,
          'dayMinutes': {7: 210},
          'targetTimeSec': 5 * 3600 + 30 * 60,
        },
      );
      samePace(p, 'target 5:30');
      final plan = gen(p, DateTime(2026, 11, 16));
      final race = plan.singleWhere((w) => w.intensity == 'race');
      final easy = PaceZones(Vdot.of(p.athlete)!).easySlow;
      expect(race.steps.single.paceMax!, lessThan(easy));
      expect(race.description, contains('5:30:00'));
    });

    test('T1: a target out of reach – the race says so and paces the realistic time', () {
      final race = DateTime(2027, 5, 24);
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [1, 3, 5, 6],
        a: {
          'eventDistance': 'hm',
          'eventDate': race,
          'raceTimes': {'10k': 3120},
          'targetTimeSec': 85 * 60,
        },
      );
      final plan = gen(p, start);
      final r = plan.singleWhere((w) => w.intensity == 'race');
      final pace = mid(r.steps.single);
      // "Your goal 1:25:00 is out of reach for now – race at the realistic <pace> (≈ <time>)": goal, pace and
      // duration describe one realistic race.
      expect(r.description, contains(l.wRaceGoalBehind('1:25:00', '${clock(pace.round())}/km', '#').split('#').first));
      expect(r.durationMin, closeTo(pace * 21.0975 / 60, 2));
    });

    test('RUN-4: a beginner without race times – no pace band, a finish goal on race day', () {
      final race = DateTime(2027, 6, 20);
      final p = prof(
        TrainingFocus.run,
        'beginner',
        [2, 4, 7],
        a: {
          'eventDistance': 'hm',
          'eventDate': race,
          'dayMinutes': {7: 150},
        },
      );
      final r = gen(p, start).singleWhere((w) => w.intensity == 'race');
      expect(r.steps.single.paceMin, isNull);
      expect(r.description, contains(l.wRaceFinishDesc));
    });

    test('RUN-7: long runs stopped by the time cap – race a finish goal with walk breaks, as the note says', () {
      final race = DateTime(2027, 3, 21);
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [1, 2, 4, 6, 7],
        a: {
          'eventDistance': 'm',
          'eventDate': race,
          'raceTimes': {'10k': 68 * 60},
          'runWeeklyKm': 30.0,
          'longestRunKm': 14.0,
          'sessionMinutes': 75,
          'dayMinutes': {7: 300},
          'setupMode': 'advanced',
        },
      );
      final s0 = DateTime(2026, 11, 16);
      final f = PlanGenerator.feasibility(p, start: s0, l: l);
      expect(f.issues, contains('longRunTimeCap'));
      final r = gen(p, s0).singleWhere((w) => w.intensity == 'race');
      expect(r.steps.single.paceMin, isNull);
      expect(r.description, contains(l.wRaceFinishDesc));
      expect(r.description, contains(l.wRaceRunWalk(10)));
      expect(PlanGenerator.finishOnly(p, start: s0), isTrue);
    });
  });

  group('limits (RUN-3, T7, FUZZ-6, eng-1)', () {
    test('RUN-3 / T7: heart or knee – no run step faster than threshold, goal-pace reps become cruise intervals', () {
      for (final (ev, lim, days) in [
        ('5k', 'heart', [1, 2, 4, 6, 7]),
        ('10k', 'heart', [1, 2, 4, 6, 7]),
        ('5k', 'knee', [2, 4, 6, 7]),
        ('10k', 'knee', [2, 4, 6, 7]),
        ('hm', 'heart', [1, 2, 4, 6, 7]),
        ('m', 'knee', [1, 2, 4, 6, 7]),
      ]) {
        final race = addDays(start, 7 * 13 + 6);
        final p = prof(
          TrainingFocus.run,
          'intermediate',
          days,
          a: {
            'eventDistance': ev,
            'eventDate': race,
            'raceTimes': {'5k': 26 * 60},
            'runWeeklyKm': 25.0,
            'limitations': [lim],
          },
          age: 55,
        );
        final tFast = PaceZones(Vdot.of(p.athlete)!).range('T').$1;
        for (final w in gen(p, start).where((w) => w.sport == Sport.run && w.intensity != 'race')) {
          expect(w.title.startsWith('Goal pace') && (ev == '5k' || ev == '10k'), isFalse, reason: '$ev $lim: ${show(w)}');
          for (final s in w.steps.where((s) => s.isWork && s.paceMin != null)) {
            expect(s.paceMin!, greaterThanOrEqualTo(tFast), reason: '$ev $lim: ${show(w)} ${s.zone} ${s.paceMin}');
          }
        }
      }
    });

    test('FUZZ-6: race times at walking pace – run/walk start, no pace slower than 11:00 /km', () {
      final p = prof(
        TrainingFocus.run,
        'beginner',
        [2, 4, 6],
        a: {
          'eventDistance': 'hm',
          'eventDate': DateTime(2027, 8, 29),
          'raceTimes': {'hm': 5 * 3600 + 32 * 60},
        },
      );
      expect(PlanGenerator.runWalkStartFor(p), isNotNull);
      for (final w in gen(p, start).where((w) => w.sport == Sport.run && w.intensity != 'race')) {
        for (final s in w.steps.where((s) => s.zone != 'walk' && s.paceMax != null)) {
          expect(s.paceMax!, lessThanOrEqualTo(PlanGenerator.slowestPaceSec), reason: show(w));
        }
      }
    });

    test('eng-1: 30 min days – runs fit the day', () {
      final p = prof(
        TrainingFocus.run,
        'beginner',
        [2, 4, 6],
        a: {
          'setupMode': 'advanced',
          'dayMinutes': {2: 30, 4: 30, 6: 30},
          'sessionMinutes': 30,
          'raceTimes': {'5k': 3300},
          'eventDistance': '5k',
          'eventDate': DateTime(2027, 5, 23),
        },
      );
      for (final w in gen(p, start).where((w) => w.sport == Sport.run && w.intensity != 'race')) {
        expect(w.durationMin, lessThanOrEqualTo(32), reason: show(w));
      }
    });
  });

  group('sessions (RUN-6, eng-3, FUZZ-5, FUZZ-3, T3)', () {
    test('RUN-6: with the long-run extension the peak keeps its marathon-pace work', () {
      final p = prof(
        TrainingFocus.run,
        'intermediate',
        [1, 2, 4, 6, 7],
        a: {
          'eventDistance': 'm',
          'eventDate': DateTime(2027, 3, 21),
          'raceTimes': {'10k': 60 * 60},
          'runWeeklyKm': 45.0,
          'longestRunKm': 20.0,
          'sessionMinutes': 75,
          'dayMinutes': {7: 300},
          'setupMode': 'advanced',
          'longRunExtend': true,
        },
      );
      final plan = gen(p, DateTime(2026, 11, 16));
      final extended = plan.where((w) => w.intensity == 'long' && w.durationMin > 182).toList();
      expect(extended, isNotEmpty);
      final peak = plan.where((w) => w.phase == 'peak').toList();
      final mpKm = peak
          .expand((w) => w.steps)
          .where((s) => s.isWork && s.note == l.stepMpNote)
          .fold(0.0, (m, s) => m + (s.distanceM ?? 0) / 1000);
      expect(mpKm, greaterThanOrEqualTo(15), reason: 'marathon-pace km in the peak');
      // An extended long run stays plain; its week has the marathon-pace run instead.
      for (final x in extended.where((x) => x.phase == 'peak')) {
        expect(x.steps.any((s) => s.note == l.stepMpNote), isFalse);
        final week = peak.where((w) => startOfWeek(w.date) == startOfWeek(x.date) && w != x);
        expect(week.any((w) => w.title == l.wMpRun), isTrue, reason: 'week of ${show(x)}');
      }
    });

    test('eng-3: strides 1–2× a loading week whatever the weekdays', () {
      for (final days in const [
        [1, 3, 5, 7],
        [2, 4, 6, 7],
        [1, 3, 5, 6],
        [1, 2, 4, 6, 7],
      ]) {
        final p = prof(
          TrainingFocus.run,
          'intermediate',
          days,
          a: {
            'raceTimes': {'10k': 2700},
            'sessionMinutes': 60,
            'planWeeks': 12,
          },
        );
        final plan = PlanGenerator(l, p, _templates, _id).generate(start: DateTime(2026, 11, 16), weeks: 12);
        final byWeek = <DateTime, List<PlannedWorkout>>{};
        for (final w in plan) {
          byWeek.putIfAbsent(startOfWeek(w.date), () => []).add(w);
        }
        for (final e in byWeek.entries.where((e) => e.value.every((w) => w.phase != 'recovery'))) {
          final n = e.value.where((w) => w.title == l.wEasyStrides).length;
          expect(n, inInclusiveRange(1, 2), reason: '$days week ${dayKey(e.key)}');
        }
      }
    });

    test('FUZZ-5 / T15: brick runs show their own minutes', () {
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        [1, 2, 3, 5, 6, 7],
        a: {
          'eventDistance': '70.3',
          'eventDate': DateTime(2027, 6, 20),
          'sessionMinutes': 90,
          'dayMinutes': {6: 240},
        },
      );
      final bricks = gen(p, start).where((w) => w.sport == Sport.run && w.intensity == 'moderate').toList();
      expect(bricks, isNotEmpty);
      for (final w in bricks) {
        final sec = w.steps.fold(0, (x, s) => x + (s.durationSec ?? 0));
        expect(w.durationMin, closeTo(sec / 60, 1), reason: show(w));
      }
    });

    test('FUZZ-3: no long-run jump where the base pre-plan ends (R1 from the own long runs of the plan)', () {
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        [1, 3, 5, 7],
        a: {'eventDistance': '70.3', 'eventDate': DateTime(2027, 10, 17), 'sessionMinutes': 420, 'runWeeklyKm': 48.0},
        longDay: 7,
      );
      final plan = gen(p, start);
      final long = <int, double>{};
      for (final w in plan.where((w) => w.sport == Sport.run && w.intensity == 'long')) {
        long[daysBetween(start, w.date) ~/ 7] = runningKm(w);
      }
      for (final e in long.entries.where((e) => e.key >= 4)) {
        final before = [for (var j = 0; j < e.key; j++) long[j] ?? 0.0].fold(0.0, max);
        expect(e.value, lessThanOrEqualTo(before * 1.12 + 0.5), reason: 'week ${e.key + 1}: ${e.value} after $before');
      }
    });

    test('T3 / RUN-8: continuous run/walk sessions say so', () {
      final p = prof(
        TrainingFocus.run,
        'beginner',
        [2, 4, 6],
        a: {
          'canRun30': false,
          'eventDistance': 'hm',
          'eventDate': DateTime(2027, 5, 23),
          'sessionMinutes': 60,
          'dayMinutes': {6: 150},
          'setupMode': 'advanced',
        },
      );
      final plan = gen(p, start);
      final cont =
          plan
              .where(
                (w) =>
                    w.steps.where((s) => s.isWork).length == 1 &&
                    w.steps.every((s) => s.zone != 'walk' || s.kind != 'recovery') &&
                    w.title != l.wShakeout &&
                    w.intensity == 'easy',
              )
              .toList();
      for (final w in cont.where((w) => w.steps.any((s) => s.kind == 'warmup' && s.zone == 'walk'))) {
        expect(w.description, startsWith(l.wRunContinuousDesc), reason: show(w));
      }
      expect(plan.any((w) => w.description.startsWith(l.wRunWalkDesc) && w.steps.where((s) => s.isWork).length == 1), isFalse);
    });

    test('T15: no over-time note for a gym estimate within its precision (46 min on a 45 min day)', () {
      for (final split in ['fullbody', 'upperlower', 'ppl']) {
        final p = prof(TrainingFocus.gym, 'beginner', [1, 3, 5], a: {'sessionMinutes': 45, 'gymSplit': split, 'planWeeks': 4});
        final plan = PlanGenerator(l, p, _templates, _id).generate(start: start, weeks: 4);
        for (final w in plan.where((w) => w.sport == Sport.gym)) {
          for (var m = 46; m <= 49; m++) {
            expect(w.description.contains(l.wGymOverTimeNote(m, 45)), isFalse, reason: show(w));
          }
        }
      }
    });

    test('RUN-5: a run/walk starter\'s recommended length never warns "too short" / "run/walk in race week"', () {
      for (final ev in ['5k', '10k', 'hm']) {
        final p = prof(
          TrainingFocus.run,
          'beginner',
          [2, 4, 6],
          a: {
            'canRun30': false,
            'eventDistance': ev,
            'dayMinutes': {6: 150},
          },
        );
        final rec = PlanGenerator.recommendedWeeks(p, start: start);
        final q = p.copyWith(athlete: p.athlete.merge({'eventDate': PlanGenerator.raceDayForWeeks(p, start, rec.def)}));
        final f = PlanGenerator.feasibility(q, start: start, l: l);
        expect(f.issues.where(const {'tooShort', 'runWalk'}.contains), isEmpty, reason: '$ev ${rec.def} weeks: ${f.issues}');
      }
    });
  });
}
