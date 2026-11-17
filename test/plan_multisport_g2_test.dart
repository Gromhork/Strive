import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Audit 2026-11, package G2 (triathlon / duathlon / cycling / swimming): one regression test per finding.
void main() {
  setUpAll(() async => initializeDateFormatting('de'));
  final de = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'g${n++}';
  final templates = defaultTemplates(id, de: true);
  final start = DateTime(2026, 11, 16); // Monday
  DateTime race(int weeks, [int weekday = 7]) => addDays(start, 7 * (weeks - 1) + weekday - 1);

  UserProfile prof(TrainingFocus f, String level, List<int> days, Map<String, dynamic> a, {Set<Sport>? exp, int age = 35}) => UserProfile(
    level: level,
    focus: f,
    birthYear: DateTime.now().year - age,
    experience: exp ?? {...f.sports},
    trainingDays: days,
    goals: const ['race'],
    weightKg: 75,
    heightCm: 178,
  ).copyWith(athlete: const AthleteData().merge({'setupMode': 'advanced', ...a}));

  List<PlannedWorkout> gen(UserProfile p, {AppLocalizations? l, int? weeks}) =>
      PlanGenerator(l ?? de, p, templates, id).generate(start: start, weeks: weeks);

  /// Plan weeks (Monday → sessions, date order) without the race.
  List<List<PlannedWorkout>> weeksOf(List<PlannedWorkout> plan) {
    final m = <DateTime, List<PlannedWorkout>>{};
    for (final p in plan.where((p) => p.intensity != 'race')) {
      m.putIfAbsent(startOfWeek(p.date), () => []).add(p);
    }
    final keys = m.keys.toList()..sort();
    return [for (final k in keys) m[k]!];
  }

  bool loading(List<PlannedWorkout> wk) => wk.every((p) => p.phase != 'recovery' && p.phase != 'taper');
  bool quality(PlannedWorkout p) => p.intensity == 'tempo' || p.intensity == 'intervals';
  double runKm(List<PlannedWorkout> wk) => wk.where((p) => p.sport == Sport.run).fold(0.0, (x, p) => x + runningKm(p));

  group('tri-3: the long run goes on the day the athlete gave time', () {
    test('Ironman, Sat 300 / Sun 150 set, 60 min otherwise: long run on Sunday, never beyond the day it is on', () {
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        const [1, 3, 5, 6, 7],
        {
          'eventDistance': 'ironman',
          'eventDate': race(24),
          'sessionMinutes': 60,
          'dayMinutes': {6: 300, 7: 150},
          'ftp': 220,
        },
      );
      expect(PlanGenerator.longSessionDays(p), {Sport.ride: 6, Sport.run: 7});
      for (final w in gen(p).where((w) => w.sport == Sport.run && w.intensity == 'long')) {
        expect(w.date.weekday, 7);
        expect(w.durationMin, lessThanOrEqualTo(150));
      }
    });

    test('70.3 beginner on 6 chosen days (max 5): the 150 min Sunday is kept, with the long run', () {
      final p = prof(
        TrainingFocus.triathlon,
        'beginner',
        const [1, 2, 3, 5, 6, 7],
        {
          'eventDistance': '70.3',
          'eventDate': race(24, 6),
          'sessionMinutes': 60,
          'dayMinutes': {6: 240, 7: 150},
        },
      );
      final sched = PlanGenerator.scheduleOf(p);
      expect(sched.keys, containsAll([6, 7]));
      expect(PlanGenerator.longSessionDays(p)[Sport.run], 7);
    });

    test('both long days left at their defaults: the note names both', () {
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        const [1, 3, 5, 6, 7],
        {'eventDistance': 'ironman', 'eventDate': race(26), 'sessionMinutes': 60, 'ftp': 220},
      );
      final f = PlanGenerator.feasibility(p, start: start, l: de);
      expect(f.issues, contains('longDayDefault'));
      final days = {f.longDayWeekday, f.longDay2Weekday};
      expect(days, containsAll(PlanGenerator.longSessionDays(p).values));
      final text = FeasibilityCard.issueText(de, f, 'longDayDefault');
      expect(text, contains('Samstag'));
      expect(text, contains('Sonntag'));
    });
  });

  group('cycling quality sessions (RS1, RS9, T2, RS8, tri-6, RS5)', () {
    final ride100 = prof(
      TrainingFocus.ride,
      'intermediate',
      const [2, 4, 6, 7],
      {
        'eventDistance': 'ride100',
        'eventDate': race(12),
        'sessionMinutes': 75,
        'dayMinutes': {6: 240},
        'ftp': 220,
      },
    );

    test('RS1: sweet-spot / threshold / tempo blocks ≥ 8 min, ≥ 20 min of work in loading weeks', () {
      for (final p in [
        ride100,
        prof(
          TrainingFocus.ride,
          'beginner',
          const [2, 4, 6, 7],
          {'eventDistance': 'ride100', 'eventDate': race(12), 'sessionMinutes': 60, 'ftp': 180},
        ),
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          const [1, 2, 4, 6, 7],
          {
            'eventDistance': 'olympic',
            'eventDate': race(12),
            'sessionMinutes': 60,
            'dayMinutes': {6: 150, 7: 90},
            'ftp': 220,
          },
        ),
      ]) {
        for (final wk in weeksOf(gen(p))) {
          for (final w in wk.where((w) => w.sport == Sport.ride && quality(w))) {
            final work = w.steps.where((s) => s.isWork && const {'SS', 'Z3', 'Z4'}.contains(s.zone)).toList();
            if (work.isEmpty) continue;
            expect(work.every((s) => s.durationSec! >= 480), isTrue, reason: '${w.date} ${w.title}');
            if (loading(wk) && w.phase != 'peak') {
              expect(work.fold(0, (x, s) => x + s.durationSec!), greaterThanOrEqualTo(1200), reason: '${w.date} ${w.title}');
            }
          }
        }
      }
    });

    test('RS9: 30 min days – warm-up ≥ 8 min and real blocks, else an easy ride with pick-ups', () {
      final p = prof(
        TrainingFocus.ride,
        'intermediate',
        const [1, 2, 4, 6, 7],
        {'eventDistance': 'ride100', 'eventDate': race(12), 'sessionMinutes': 30, 'ftp': 200},
      );
      for (final w in gen(p).where((w) => w.sport == Sport.ride && quality(w))) {
        final wu = w.steps.firstWhere((s) => s.kind == 'warmup');
        expect(wu.durationSec, greaterThanOrEqualTo(480), reason: '${w.date} ${w.title}');
        final work = w.steps.where((s) => s.isWork).toList();
        final minBlock = work.every((s) => s.zone == 'Z5') ? 180 : 480;
        expect(work.every((s) => s.durationSec! >= minBlock), isTrue, reason: '${w.date} ${w.title}');
      }
    });

    test('T2 / RS8 / tri-6: the watts match the text – race tempo 75–85 %, base tempo 76–90 %, threshold ≤ FTP', () {
      const ftp = 220;
      final plans = [
        gen(ride100),
        gen(
          prof(
            TrainingFocus.ride,
            'beginner',
            const [2, 4, 6, 7],
            {'eventDistance': 'ride100', 'eventDate': race(12), 'sessionMinutes': 75, 'ftp': ftp},
          ),
        ),
        gen(
          prof(
            TrainingFocus.triathlon,
            'intermediate',
            const [1, 2, 3, 4, 6, 7],
            {
              'eventDistance': 'ironman',
              'eventDate': race(28),
              'sessionMinutes': 90,
              'dayMinutes': {6: 360, 7: 180},
              'ftp': ftp,
            },
          ),
        ),
      ];
      var raceTempo = 0, baseTempo = 0;
      for (final plan in plans) {
        for (final s in plan.where((w) => w.sport == Sport.ride).expand((w) => w.steps)) {
          expect(s.note, isNot(de.stepThresholdNote), reason: 'no "95–105 %" note on a 91–105 % range');
          if (s.note == de.stepRideTempoNote) {
            raceTempo++;
            expect(s.powerMin, (ftp * 0.75).round());
            expect(s.powerMax, (ftp * 0.85).round());
          }
          if (s.note == de.stepRideTempoNote2) {
            baseTempo++;
            expect((s.powerMin, s.powerMax), PowerZones(ftp).range('Z3'));
          }
          if (s.note == de.stepThresholdNote2) expect(s.powerMax, ftp);
        }
      }
      expect(raceTempo, greaterThan(0));
      expect(baseTempo, greaterThan(0));
      final im = plans[2].where((w) => w.title.startsWith('Tempo ') && w.sport == Sport.ride);
      expect(im.every((w) => w.description.startsWith(de.wRideTempoDescIm2)), isTrue);
    });

    test('RS5: knee – no low-cadence climbing repeats, every ride carries the knee note', () {
      final p = prof(
        TrainingFocus.ride,
        'intermediate',
        const [2, 4, 6, 7],
        {
          'eventDistance': 'ride100',
          'eventDate': race(12),
          'sessionMinutes': 75,
          'dayMinutes': {6: 240},
          'ftp': 200,
          'limitations': ['knee'],
        },
      );
      final rides = gen(p).where((w) => w.sport == Sport.ride && w.intensity != 'race').toList();
      expect(rides.expand((w) => w.steps).any((s) => s.note == de.stepClimbNote), isFalse);
      expect(rides.every((w) => w.description.contains(de.healthRideKneeNote)), isTrue);
      // Control: without the limitation the Gran Fondo build has climbing repeats.
      expect(gen(ride100).expand((w) => w.steps).any((s) => s.note == de.stepClimbNote), isTrue);
    });
  });

  group('RS4: power meter without FTP', () {
    test('an FTP test first, the watts marked as estimates, retests every 6 loading weeks', () {
      final p = prof(
        TrainingFocus.ride,
        'intermediate',
        const [2, 4, 6, 7],
        {
          'eventDistance': 'ride160',
          'eventDate': race(14),
          'sessionMinutes': 75,
          'dayMinutes': {6: 300},
          'hasPowerMeter': true,
        },
      );
      final plan = gen(p);
      final rides = plan.where((w) => w.sport == Sport.ride && w.intensity != 'race').toList();
      final firstQuality = rides.firstWhere((w) => w.isKey && w.intensity != 'long');
      expect(firstQuality.title, de.wFtpTest);
      expect(daysBetween(start, firstQuality.date), lessThan(7));
      final tests = rides.where((w) => w.title == de.wFtpTest).toList();
      expect(tests.length, greaterThanOrEqualTo(2));
      expect(daysBetween(tests[0].date, tests[1].date), greaterThanOrEqualTo(42));
      final est = PowerZones.estimate('intermediate', 75);
      for (final w in rides.where((w) => w.title != de.wFtpTest && w.steps.any((s) => s.powerMin != null))) {
        expect(w.description, contains(de.wFtpEstimateNote('$est')));
      }
    });

    test('a stated FTP: no estimate note, the retest after 6 loading weeks; no power meter: no test', () {
      final base = {
        'eventDistance': 'ride160',
        'eventDate': race(14),
        'sessionMinutes': 75,
        'dayMinutes': {6: 300},
        'ftp': 230,
      };
      final withPm = gen(prof(TrainingFocus.ride, 'intermediate', const [2, 4, 6, 7], {...base, 'hasPowerMeter': true}));
      expect(withPm.any((w) => w.description.contains('geschätzt')), isFalse);
      final tests = withPm.where((w) => w.title == de.wFtpTest).toList();
      expect(tests, isNotEmpty);
      expect(daysBetween(start, tests.first.date), greaterThanOrEqualTo(42));
      expect(gen(prof(TrainingFocus.ride, 'intermediate', const [2, 4, 6, 7], base)).any((w) => w.title == de.wFtpTest), isFalse);
    });
  });

  group('race day (tri-5, T4, T8)', () {
    test('tri-5: the bike leg at the race power – Ironman Z2 ~70 % FTP, olympic Z3; run/walk finishers run easy', () {
      PlannedWorkout raceOf(UserProfile p) => gen(p).firstWhere((w) => w.intensity == 'race');
      final im = raceOf(
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          const [1, 2, 3, 4, 6, 7],
          {
            'eventDistance': 'ironman',
            'eventDate': race(30),
            'sessionMinutes': 90,
            'dayMinutes': {6: 360, 7: 180},
            'ftp': 240,
          },
        ),
      );
      final bike = im.steps[1];
      expect(bike.zone, 'Z2');
      expect(bike.powerMin, (240 * (GoalModel.raceFtpShare('ironman') - 0.03)).round());
      expect(bike.powerMax, (240 * (GoalModel.raceFtpShare('ironman') + 0.03)).round());
      expect(im.steps[2].zone, anyOf('E', 'M'));
      final oly = raceOf(
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          const [1, 2, 4, 6, 7],
          {'eventDistance': 'olympic', 'eventDate': race(12), 'sessionMinutes': 60, 'ftp': 220},
        ),
      );
      expect(oly.steps[1].zone, 'Z3');
      final du = raceOf(
        prof(
          TrainingFocus.duathlon,
          'beginner',
          const [2, 4, 6],
          {'eventDistance': 'du_sprint', 'eventDate': race(8, 6), 'sessionMinutes': 45, 'canRun30': false},
        ),
      );
      expect(du.steps[0].zone, 'E');
      expect(du.steps[1].zone, 'Z2');
      expect(du.steps[2].zone, 'E');
    });

    test('T4 / T8: German leg distances with a comma; a forecast is no "goal time", no km cue', () {
      final w = gen(
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          const [1, 2, 4, 6, 7],
          {'eventDistance': 'sprint', 'eventDate': race(10), 'sessionMinutes': 60, 'ftp': 220},
        ),
      ).firstWhere((w) => w.intensity == 'race');
      expect(w.description, contains('Schwimmen 0,75 km'));
      expect(w.description, isNot(contains('0.75')));
      expect(w.description, contains('Prognose'));
      expect(w.description, isNot(contains('erster km')));
      expect(w.description, isNot(contains('Zielzeit')));
      final withTarget = gen(
        prof(
          TrainingFocus.triathlon,
          'intermediate',
          const [1, 2, 4, 6, 7],
          {'eventDistance': 'sprint', 'eventDate': race(10), 'sessionMinutes': 60, 'ftp': 220, 'targetTimeSec': 80 * 60},
        ),
      ).firstWhere((w) => w.intensity == 'race');
      expect(withTarget.description, contains('Zielzeit'));
      expect(withTarget.description, isNot(contains('erster km')));
    });
  });

  test('tri-1: the taper keeps a quality ride and run (2 a week each); race week has openers', () {
    final plan = gen(
      prof(
        TrainingFocus.triathlon,
        'intermediate',
        const [1, 2, 4, 6, 7],
        {
          'eventDistance': 'olympic',
          'eventDate': race(12),
          'sessionMinutes': 60,
          'dayMinutes': {6: 150, 7: 90},
          'ftp': 220,
          'raceTimes': {'10k': 3000},
        },
      ),
    );
    final weeks = weeksOf(plan).where((wk) => wk.first.phase == 'taper').toList();
    expect(weeks.length, 2);
    final first = weeks.first;
    expect(first.any((w) => w.sport == Sport.ride && quality(w)), isTrue);
    expect(first.any((w) => w.sport == Sport.run && quality(w)), isTrue);
    expect(weeks.last.any((w) => w.sport == Sport.ride && w.title == de.wRidePickups(w.steps.where((s) => s.isWork).length)), isTrue);
  });

  test('tri-2: one run a week on run/walk – the running grows ≤ +10 % / +5 min a week, ≤ 1.5 × the stage', () {
    final p = prof(
      TrainingFocus.triathlon,
      'beginner',
      const [2, 4, 7],
      {'eventDistance': 'olympic', 'sessionMinutes': 60, 'canSwim400': false, 'canRun30': false},
    );
    final q = p.copyWith(athlete: p.athlete.merge({'eventDate': PlanGenerator.raceDayForWeeks(p, start, 12)}));
    final plan = gen(q);
    int running(List<PlannedWorkout> wk) => wk
        .where((w) => w.sport == Sport.run)
        .expand((w) => w.steps)
        .where((s) => s.isWork && s.zone == 'E')
        .fold(0, (x, s) => x + (s.durationSec ?? 0));
    final weeks = weeksOf(plan).where(loading).toList();
    for (var i = 1; i < weeks.length && i < 8; i++) {
      final a = running(weeks[i - 1]), b = running(weeks[i]);
      // (+10 % / +5 min to the nearest whole block – ≤ +6 min with 10 min blocks; never less than last week.)
      expect(b, inInclusiveRange(a, max(a * 1.1, a + 300) + 60), reason: 'week ${i + 1}: $a → $b s');
    }
    // No "the same rhythm as your other runs" – there are none.
    expect(plan.where((w) => w.description.contains(de.wLongRunWalkDesc)), isEmpty);
  });

  test('tri-4: a 2-day sprint week has every discipline', () {
    for (final swim400 in [true, false]) {
      final p = prof(
        TrainingFocus.triathlon,
        swim400 ? 'intermediate' : 'beginner',
        const [3, 6],
        {'eventDistance': 'sprint', 'eventDate': race(10, 6), 'sessionMinutes': 90, 'canSwim400': swim400},
      );
      for (final wk in weeksOf(gen(p)).take(8)) {
        for (final s in const [Sport.swim, Sport.ride, Sport.run]) {
          expect(wk.any((w) => w.sport == s), isTrue, reason: '${wk.first.date} $s');
        }
      }
    }
    // One day only: the frequency warnings say what is missing.
    final one = prof(
      TrainingFocus.triathlon,
      'intermediate',
      const [6],
      {'eventDistance': 'sprint', 'eventDate': race(10, 6), 'sessionMinutes': 90},
    );
    expect(PlanGenerator.feasibility(one, start: start, l: de).issues, containsAll(['swimFrequency', 'runFrequency']));
  });

  test('tri-7: a continuous swim held by the day\'s time – shorter warm-up first, then the day to raise', () {
    final p = prof(
      TrainingFocus.triathlon,
      'intermediate',
      const [2, 4, 6, 7],
      {
        'eventDistance': '70.3',
        'eventDate': race(20),
        'sessionMinutes': 60,
        'dayMinutes': {6: 180, 7: 90},
        'ftp': 220,
      },
    );
    final plan = gen(p);
    final cont = plan.where((w) => w.title.startsWith('Am Stück schwimmen')).toList();
    expect(cont, isNotEmpty);
    final f = PlanGenerator.feasibility(p, start: start, l: de);
    if (f.issues.contains('longSwim')) {
      expect(f.longSwimDay, isNotNull);
      expect(f.longSwimDayMin, greaterThan(PlanGenerator.dayMinutesFor(p, f.longSwimDay!)));
      // The text names the day and the time that would hold the swim (the raise options may already hold the long days).
      final text = FeasibilityCard.issueText(de, f, 'longSwim');
      expect(text, contains('Die Zeit am'));
      expect(text, contains('Mit etwa'));
      // The warm-up gave way before the swim did.
      final held = cont.where((w) => w.phase != 'taper' && w.phase != 'recovery').last;
      expect(held.steps.first.distanceM, lessThanOrEqualTo(200));
    }
    // "It grows ~100 m a week" only while it does: not in a loading week whose swim is no longer than the last one's.
    final loads = cont.where((w) => w.phase != 'taper' && w.phase != 'recovery').toList();
    double m(PlannedWorkout w) => w.steps.where((s) => s.zone == 'EN').first.distanceM!;
    var held = 0;
    for (var i = 1; i < loads.length; i++) {
      if (m(loads[i]) > m(loads[i - 1])) continue;
      held++;
      expect(loads[i].description, isNot(contains(de.wSwimContinuousDesc)), reason: '${loads[i].date} ${loads[i].title}');
    }
    expect(held, greaterThan(0));
  });

  test('tri-8: long-course advanced on 7 days – a third run, no 15 min jogs, the long run still reaches the race', () {
    final p = prof(
      TrainingFocus.triathlon,
      'advanced',
      const [1, 2, 3, 4, 5, 6, 7],
      {
        'eventDistance': '70.3',
        'eventDate': race(16),
        'sessionMinutes': 90,
        'dayMinutes': {6: 270, 7: 180},
        'sessionsPerDay': 2,
        'raceTimes': {'hm': 5100},
        'ftp': 280,
      },
    );
    expect(PlanGenerator.scheduleOf(p).values.expand((v) => v).where((s) => s == Sport.run).length, 3);
    final plan = gen(p);
    for (final wk in weeksOf(plan).where(loading)) {
      for (final w in wk.where((w) => w.sport == Sport.run && w.intensity == 'easy')) {
        expect(w.durationMin, greaterThanOrEqualTo(28), reason: '${w.date} ${w.title}');
      }
    }
    final longest = plan.where((w) => w.sport == Sport.run && w.intensity == 'long').map((w) => w.distanceKm ?? 0).fold(0.0, max);
    expect(longest, greaterThanOrEqualTo(16));
    // Ironman intermediate on 6 days: the 28 km long run stays (the third run splits the second run's volume).
    final im = prof(
      TrainingFocus.triathlon,
      'intermediate',
      const [1, 2, 3, 4, 6, 7],
      {
        'eventDistance': 'ironman',
        'eventDate': race(30),
        'sessionMinutes': 90,
        'dayMinutes': {6: 360, 7: 180},
        'ftp': 240,
      },
    );
    final imLong = gen(im).where((w) => w.sport == Sport.run && w.intensity == 'long').map((w) => w.distanceKm ?? 0).fold(0.0, max);
    expect(imLong, greaterThanOrEqualTo(26));
  });

  test('tri-9: the duathlon peak week does not jump in run km (pre-ride run counted)', () {
    final p = prof(
      TrainingFocus.duathlon,
      'advanced',
      const [2, 4, 6, 7],
      {
        'eventDistance': 'du_sprint',
        'eventDate': race(8),
        'sessionMinutes': 60,
        'ftp': 280,
        'raceTimes': {'5k': 1080},
      },
    );
    final weeks = weeksOf(gen(p)).where(loading).toList();
    bool brick(List<PlannedWorkout> wk) => wk.any((w) => w.sport == Sport.run && w.intensity == 'moderate');
    var checked = 0;
    for (var i = 1; i < weeks.length; i++) {
      // Week to week with bricks in both (the first brick week adds its 10 min run on top of the long run's R1 step).
      if (!brick(weeks[i - 1]) || !brick(weeks[i])) continue;
      checked++;
      expect(runKm(weeks[i]), lessThanOrEqualTo(runKm(weeks[i - 1]) * 1.12 + 0.3), reason: 'loading week ${i + 1}');
    }
    expect(checked, greaterThan(0));
    // The peak week with the run before the bike (was +36 %).
    final peak = weeks.lastWhere((wk) => wk.any((w) => w.description.startsWith(de.wDuRunFirstDesc)));
    expect(runKm(peak), lessThanOrEqualTo(runKm(weeks[weeks.indexOf(peak) - 1]) * 1.12 + 0.3));
    // The run before the bike: whole 5 min, its time as its title says.
    for (final w in gen(p).where((w) => w.description.startsWith(de.wDuRunFirstDesc))) {
      expect(w.title, de.wDuRunFirst(w.durationMin));
      expect(w.durationMin % 5, 0);
    }
  });

  test('tri-10: Ironman intermediate in the recommended 24 weeks reaches a ~5 h long ride, no "too short"', () {
    final p = prof(
      TrainingFocus.triathlon,
      'intermediate',
      const [1, 2, 3, 5, 6, 7],
      {
        'eventDistance': 'ironman',
        'eventDate': race(24),
        'sessionMinutes': 75,
        'dayMinutes': {6: 360, 7: 180},
        'ftp': 230,
        'raceTimes': {'hm': 6000},
      },
    );
    final plan = gen(p);
    final longRide = plan.where((w) => w.sport == Sport.ride && w.intensity == 'long').map((w) => w.durationMin).fold(0, max);
    expect(longRide, greaterThanOrEqualTo(270));
    expect(PlanGenerator.feasibility(p, start: start, l: de).issues, isNot(contains('tooShort')));
  });

  test('tri-11: one swim a week ends with a CSS block in build / peak', () {
    final plan = gen(
      prof(
        TrainingFocus.triathlon,
        'intermediate',
        const [1, 2, 4, 6, 7],
        {'eventDistance': 'sprint', 'eventDate': race(12), 'sessionMinutes': 60, 'swim400Sec': 420},
      ),
    );
    final late = plan.where((w) => w.sport == Sport.swim && (w.phase == 'build' || w.phase == 'peak'));
    expect(late, isNotEmpty);
    expect(late.every((w) => w.steps.any((s) => s.zone == 'CSS')), isTrue);
  });

  test('tri-12: same-day order – run before the bike, ride, brick run', () {
    final plan = gen(
      prof(
        TrainingFocus.duathlon,
        'advanced',
        const [2, 4, 6, 7],
        {
          'eventDistance': 'du_sprint',
          'eventDate': race(8),
          'sessionMinutes': 60,
          'ftp': 280,
          'raceTimes': {'5k': 1080},
        },
      ),
    );
    final byDay = <DateTime, List<PlannedWorkout>>{};
    for (final w in plan) {
      byDay.putIfAbsent(dayOnly(w.date), () => []).add(w);
    }
    var bricks = 0;
    for (final day in byDay.values.where((d) => d.any((w) => w.sport == Sport.ride && w.intensity == 'long'))) {
      final order =
          day.map((w) => w.description.startsWith(de.wDuRunFirstDesc) ? 'pre' : (w.sport == Sport.ride ? 'ride' : w.sport.name)).toList();
      final brick = day.indexWhere(
        (w) => w.sport == Sport.run && w.intensity == 'moderate' && !w.description.startsWith(de.wDuRunFirstDesc),
      );
      if (brick < 0) continue;
      bricks++;
      expect(order.indexOf('ride'), lessThan(brick), reason: '$order');
      if (order.contains('pre')) expect(order.indexOf('pre'), lessThan(order.indexOf('ride')));
    }
    expect(bricks, greaterThan(0));
    // Stored and read back in that order.
    final a = PlannedWorkout(id: 'b', date: start, sport: Sport.run, title: 'brick', slot: 4);
    final b = PlannedWorkout(id: 'a', date: start, sport: Sport.ride, title: 'ride', slot: 3);
    expect(PlannedWorkout.fromMap('b', a.toMap()).slot, 4);
    expect(([a, b]..sort(PlannedWorkout.compareByDay)).map((w) => w.title), ['ride', 'brick']);
    expect(PlannedWorkout.fromMap('x', {'date': '2026-11-16', 'sport': 'run'}).slot, 0);
  });

  group('swimming (RS2, RS3, RS10, T13, UX-3, T11)', () {
    test('RS3: a beginner with a slow test starts the long swim at what they swim, +≤ 200 m a week, ≤ 1.6 km sessions', () {
      final plan = gen(
        prof(
          TrainingFocus.swim,
          'beginner',
          const [2, 4, 6],
          {'eventDistance': 'swim1500', 'eventDate': race(12), 'sessionMinutes': 60, 'swim400Sec': 600, 'swim200Sec': 285},
        ),
      );
      final longs = plan.where((w) => w.sport == Sport.swim && w.intensity == 'long').toList();
      double cont(PlannedWorkout w) => w.steps.where((s) => s.isWork && s.zone != 'DR').fold(0.0, (x, s) => x + s.distanceM!);
      expect(cont(longs.first), lessThanOrEqualTo(500));
      var most = cont(longs.first);
      for (final w in longs.skip(1)) {
        expect(cont(w) - most, lessThanOrEqualTo(200), reason: '${w.date}');
        most = max(most, cont(w));
      }
      for (final w in plan.where((w) => w.sport == Sport.swim && w.intensity != 'race')) {
        // (The long swim: its continuous part plus warm-up, drills and cool-down.)
        if (w.intensity != 'long') expect(w.distanceKm, lessThanOrEqualTo(1.7), reason: '${w.date} ${w.title}');
        final early = daysBetween(start, w.date) < 35;
        if (early) expect(w.steps.every((s) => s.paceMin == null), isTrue, reason: 'no pace targets in the first 5 weeks');
      }
    });

    test('RS2: a beginner who can swim 400 m is no swim novice – no 50 m ladder, a CSS test after ~3 weeks', () {
      final p = prof(
        TrainingFocus.swim,
        'beginner',
        const [2, 4, 6],
        {'setupMode': 'simple', 'eventDistance': 'swim1500', 'eventDate': race(10), 'sessionMinutes': 60, 'canSwim400': true},
        exp: const {},
      );
      expect(PlanGenerator.swimNoviceOf(p), isFalse);
      final swims = gen(p).where((w) => w.sport == Sport.swim).toList();
      expect(swims.any((w) => w.title == de.wSwimBuild(8, 50)), isFalse);
      final test = swims.indexWhere((w) => w.title == de.wSwimCssTest);
      expect(test, greaterThanOrEqualTo(0));
      expect(daysBetween(start, swims[test].date), inInclusiveRange(21, 42));
      // Who cannot swim 400 m still starts with the ladder.
      final novice = gen(p.copyWith(athlete: p.athlete.merge({'canSwim400': false}))).where((w) => w.sport == Sport.swim);
      expect(novice.first.steps.where((s) => s.zone == 'EN').every((s) => s.distanceM! <= 50), isTrue);
    });

    test('RS10 / T13: drill notes fit the step; the long swim names its continuous part', () {
      final novice = gen(
        prof(
          TrainingFocus.swim,
          'beginner',
          const [1, 3, 5],
          {'eventDistance': 'swim1500', 'eventDate': race(10), 'sessionMinutes': 45, 'canSwim400': false},
        ),
      );
      final tested = gen(
        prof(
          TrainingFocus.swim,
          'intermediate',
          const [1, 3, 5, 6],
          {'eventDistance': 'swim3800', 'eventDate': race(14), 'sessionMinutes': 75, 'swim400Sec': 420, 'swim200Sec': 200},
        ),
      );
      for (final s in [...novice, ...tested].expand((w) => w.steps).where((s) => s.zone == 'DR')) {
        if (s.distanceM! < 100) {
          expect(s.note, isNot(contains('50 m Übung, 50 m Kraul')));
        } else {
          expect(s.distanceM! % 100, 0, reason: '${s.distanceM} m of drills alternating 50 / 50 m');
        }
      }
      for (final w in tested.where((w) => w.sport == Sport.swim && w.intensity == 'long')) {
        final m = w.steps.where((s) => s.isWork && s.zone != 'DR').fold(0.0, (x, s) => x + s.distanceM!);
        expect(w.title, de.wLongSwim2(m.round()));
      }
    });

    test('UX-3: two quality swims never on consecutive days', () {
      final p = prof(
        TrainingFocus.swim,
        'intermediate',
        const [1, 2, 3, 4, 6, 7],
        {
          'eventDistance': 'swim5000',
          'eventDate': race(16, 6),
          'sessionMinutes': 75,
          'swim400Sec': 455,
          'swim200Sec': 218,
          'swimWeeklyKm': 6.5,
          'dayPlan': <int, List<Sport>>{
            1: [Sport.swim],
            2: [Sport.swim],
            3: [Sport.gym],
            4: [Sport.swim],
            6: [Sport.swim],
            7: [Sport.gym],
          },
        },
      );
      final key = gen(p).where((w) => w.sport == Sport.swim && quality(w) && w.isKey).map((w) => dayOnly(w.date)).toList()..sort();
      expect(key, isNotEmpty);
      for (var i = 1; i < key.length; i++) {
        expect(daysBetween(key[i - 1], key[i]), greaterThanOrEqualTo(2), reason: '${key[i - 1]} / ${key[i]}');
      }
    });

    test('T11: a triathlon\'s continuous-swim target is the plan\'s goal, with the leg named', () {
      final p = prof(
        TrainingFocus.triathlon,
        'intermediate',
        const [3, 6],
        {'eventDistance': 'sprint', 'eventDate': race(8, 6), 'sessionMinutes': 90},
      );
      final f = PlanGenerator.feasibility(p, start: start, l: de);
      expect(f.issues, contains('longSwim'));
      expect(f.longSwimLegM, 750);
      final text = FeasibilityCard.issueText(de, f, 'longSwim');
      expect(text, contains('750 m'));
      expect(text, isNot(contains('dieses Rennen braucht')));
    });
  });

  group('rides from what the athlete has done (FUZZ-2, RS7)', () {
    test('FUZZ-2: the first long ride ≤ 110 % of the longest recent ride, then ≤ +10 % / 15 min a week', () {
      final p = prof(
        TrainingFocus.ride,
        'beginner',
        const [2, 4, 6],
        {'sessionMinutes': 480, 'bikeWeeklyHours': 6.0, 'longestRideKm': 40.0, 'planWeeks': 12},
        age: 64,
      );
      final plan = PlanGenerator(de, p.copyWith(goals: const []), templates, id).generate(start: start, weeks: 12);
      final longs = plan.where((w) => w.sport == Sport.ride && w.intensity == 'long').toList();
      expect(longs.first.distanceKm, lessThanOrEqualTo(44.5));
      var last = 0;
      for (final wk in weeksOf(plan)) {
        final l0 = wk.where((w) => w.sport == Sport.ride && w.intensity == 'long').firstOrNull;
        if (l0 == null) continue;
        if (loading(wk) && last > 0) expect(l0.durationMin, lessThanOrEqualTo(last + max(15, (last * 0.1 / 5).round() * 5) + 5));
        if (loading(wk)) last = l0.durationMin;
        if (!loading(wk)) {
          for (final w in wk.where((w) => w.sport == Sport.ride && w.intensity == 'easy')) {
            expect(w.durationMin, lessThanOrEqualTo(90));
          }
        }
      }
    });

    test('RS7: ride distances at the athlete\'s own speed – a beginner\'s long ride not faster than their race', () {
      final p = prof(
        TrainingFocus.ride,
        'beginner',
        const [2, 4, 6, 7],
        {
          'eventDistance': 'ride100',
          'eventDate': race(12),
          'sessionMinutes': 60,
          'dayMinutes': {6: 240},
        },
      );
      final plan = gen(p);
      final raceW = plan.firstWhere((w) => w.intensity == 'race');
      final raceKmh = 100 / (raceW.durationMin / 60);
      for (final w in plan.where((w) => w.sport == Sport.ride && w.intensity == 'long')) {
        expect(w.distanceKm! / (w.durationMin / 60), lessThan(raceKmh), reason: '${w.date} ${w.distanceKm} km in ${w.durationMin}′');
      }
    });
  });

  test('FUZZ-8: a day plan with ride + run on the long day – the brick is that run; the knee swap no second ride', () {
    final p = prof(
      TrainingFocus.duathlon,
      'intermediate',
      const [2, 4, 6, 7],
      {
        'eventDistance': 'du_standard',
        'eventDate': race(12),
        'sessionMinutes': 60,
        'dayMinutes': {6: 180},
        'sessionsPerDay': 2,
        'limitations': ['knee'],
        'dayPlan': <int, List<Sport>>{
          2: [Sport.run],
          4: [Sport.ride, Sport.run],
          6: [Sport.ride, Sport.run],
          7: [Sport.run],
        },
      },
    );
    expect(PlanGenerator.longSessionDays(p)[Sport.ride], 6);
    final byDay = <DateTime, List<PlannedWorkout>>{};
    for (final w in gen(p).where((w) => w.intensity != 'race')) {
      byDay.putIfAbsent(dayOnly(w.date), () => []).add(w);
    }
    for (final day in byDay.values) {
      expect(day.where((w) => w.sport == Sport.ride).length, lessThanOrEqualTo(1), reason: '${day.first.date}: ${day.map((w) => w.title)}');
      if (day.any((w) => w.sport == Sport.run && w.intensity == 'moderate')) {
        expect(
          day.where((w) => w.sport == Sport.run && w.intensity != 'moderate'),
          isEmpty,
          reason: '${day.first.date}: ${day.map((w) => w.title)}',
        );
      }
    }
  });
}
