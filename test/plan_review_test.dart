import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/plan_generator.dart';

/// Findings of the sports-science review of generated plans (30 athlete profiles):
/// goal feasibility (C4), cross-sport hard budget (I1), long-session lengths (I2), bricks
/// (I3), 70.3 swimming (I4), legs before key sessions (I8), run spacing (I9), volume cap (I10).
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9);
  final templates = defaultTemplates(id, de: false);
  DateTime race(int weeks) => start.add(Duration(days: 7 * (weeks - 1) + 6)); // Sunday of week [weeks]
  List<PlannedWorkout> gen(UserProfile p, {int? weeks}) => PlanGenerator(l, p, templates, id).generate(start: start, weeks: weeks);
  Map<DateTime, List<PlannedWorkout>> byWeek(List<PlannedWorkout> plan) {
    final m = <DateTime, List<PlannedWorkout>>{};
    for (final p in plan.where((p) => p.intensity != 'race')) {
      m.putIfAbsent(startOfWeek(p.date), () => []).add(p);
    }
    return m;
  }

  bool runWalk(PlannedWorkout p) => p.steps.any((s) => s.note == l.stepTalkPace);
  bool hard(PlannedWorkout p) => p.intensity == 'tempo' || p.intensity == 'intervals';
  double longest(List<PlannedWorkout> plan, Sport s) => plan
      .where((p) => p.sport == s && p.intensity == 'long')
      .fold(0.0, (x, p) => max(x, s == Sport.run ? p.distanceKm ?? 0 : p.durationMin * 1.0));

  final beginner5k = UserProfile(
    level: 'beginner',
    focus: TrainingFocus.run,
    trainingDays: const [2, 4, 6],
    athlete: AthleteData(eventDistance: '5k', eventDate: race(9)),
  );
  final beginnerMarathon = UserProfile(
    level: 'beginner',
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: const [2, 4, 6, 7],
    athlete: AthleteData(eventDistance: 'm', eventDate: race(16)),
  );
  final senior10k = UserProfile(
    level: 'beginner',
    birthYear: DateTime.now().year - 68,
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: const [1, 3, 5],
    athlete: AthleteData(eventDistance: '10k', eventDate: race(12)),
  );
  final intermediateHm = UserProfile(
    level: 'intermediate',
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: const [2, 4, 6, 7],
    athlete: AthleteData(raceTimes: const {'10k': 3300}, eventDistance: 'hm', eventDate: race(12)),
  );
  final advancedMarathon = UserProfile(
    level: 'advanced',
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: const [1, 2, 3, 4, 6, 7],
    athlete: AthleteData(
      sessionMinutes: 90,
      runWeeklyKm: 55,
      longestRunKm: 22,
      raceTimes: const {'hm': 5400},
      eventDistance: 'm',
      eventDate: race(18),
    ),
  );
  final intermediateMarathon = UserProfile(
    level: 'intermediate',
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: const [2, 3, 5, 7],
    athlete: AthleteData(
      sessionMinutes: 75,
      runWeeklyKm: 35,
      longestRunKm: 16,
      raceTimes: const {'10k': 3000},
      eventDistance: 'm',
      eventDate: race(18),
    ),
  );
  UserProfile tri(String level, String event, List<int> days, int weeks) => UserProfile(
    level: level,
    focus: TrainingFocus.triathlon,
    experience: const {Sport.run, Sport.ride, Sport.swim},
    trainingDays: days,
    athlete: AthleteData(raceTimes: level == 'beginner' ? const {} : const {'10k': 3000}, eventDistance: event, eventDate: race(weeks)),
  );
  final olympic = tri('intermediate', 'olympic', const [1, 2, 3, 4, 6, 7], 16);
  final half = tri('intermediate', '70.3', const [1, 2, 3, 4, 6, 7], 20);
  final halfBeginner = tri('beginner', '70.3', const [1, 2, 4, 6, 7], 20);

  group('C4 goal feasibility', () {
    test('beginner marathon: not a beginner goal, half marathon suggested, plan generated anyway', () {
      final f = PlanGenerator.feasibility(beginnerMarathon, start: start, l: l);
      expect(f.ok, isFalse);
      expect(f.reason, 'beginnerMarathon');
      expect(f.shorterDistance, 'hm');
      expect(f.laterDate, isNull);
      expect(gen(beginnerMarathon).where((p) => p.intensity == 'race'), isNotEmpty);
    });

    test('run/walk 5 km in 9 weeks: later date, finish with run/walk, strategy on race day', () {
      final f = PlanGenerator.feasibility(beginner5k, start: start, l: l);
      expect(f.issues, ['runWalk']);
      expect(f.runWalkFinish, isTrue);
      // C25K needs 11 run/walk weeks + race week here: the suggested date is that late, and works.
      expect(f.laterDate, isNotNull);
      expect(startOfWeek(f.laterDate!).difference(start).inDays ~/ 7 + 1, inInclusiveRange(10, 13));
      final later = beginner5k.copyWith(athlete: beginner5k.athlete.merge({'eventDate': f.laterDate}));
      expect(PlanGenerator.feasibility(later, start: start, l: l).ok, isTrue);
      final raceDay = gen(beginner5k).firstWhere((p) => p.intensity == 'race');
      expect(raceDay.description.split('\n').any((x) => x.startsWith(l.wRaceRunWalk(1).split(' 1 ').first)), isTrue);
      expect(gen(later).firstWhere((p) => p.intensity == 'race').description, isNot(contains(l.wRaceRunWalk(1).substring(0, 12))));
    });

    test('run/walk: no recovery weeks until continuous running (Couch-to-5K has none)', () {
      for (final p in [beginner5k, senior10k]) {
        final weeks = byWeek(gen(p));
        for (final w in weeks.values.where((w) => w.any(runWalk))) {
          expect(w.any((x) => x.phase == 'recovery'), isFalse, reason: '${p.age}');
        }
      }
      // Run/walk progresses one stage per week: the senior (from 3 × 5 min) runs 30 min after 7 weeks.
      final rw = byWeek(gen(senior10k)).values.where((w) => w.any(runWalk)).length;
      expect(rw, 7);
    });

    test('senior 10 km in 12 weeks: too short, later date and 5 km offered', () {
      final f = PlanGenerator.feasibility(senior10k, start: start, l: l);
      expect(f.issues, ['tooShort']);
      expect(f.laterDate, isNotNull);
      expect(f.laterDate!.isAfter(senior10k.athlete.eventDate!), isTrue);
      expect(f.shorterDistance, '5k');
    });

    test('HM / marathon while on run/walk is not allowed', () {
      final p = beginner5k.copyWith(athlete: beginner5k.athlete.merge({'eventDistance': 'hm', 'eventDate': race(20)}));
      final f = PlanGenerator.feasibility(p, start: start, l: l);
      expect(f.reason, 'runWalkLong');
      expect(f.shorterDistance, isNotNull);
    });

    test('realistic goals pass', () {
      for (final p in [intermediateHm, advancedMarathon, intermediateMarathon, olympic, half]) {
        final f = PlanGenerator.feasibility(p, start: start, l: l);
        expect(f.issues, isEmpty, reason: '${p.level} ${p.athlete.eventDistance}');
      }
      expect(PlanGenerator.feasibility(const UserProfile(focus: TrainingFocus.run), start: start, l: l).ok, isTrue);
    });

    test('time on the long day caps the long session: warning with the numbers', () {
      final shortDay = intermediateMarathon.copyWith(
        athlete: intermediateMarathon.athlete.merge({
          'dayMinutes': {'7': 120},
        }),
      );
      final f = PlanGenerator.feasibility(shortDay, start: start, l: l);
      expect(f.issues, contains('longRunTime'));
      expect(f.longRunKm, lessThan(28));
      expect(f.longRunTargetKm, 28);
      final shortRide = half.copyWith(
        athlete: half.athlete.merge({
          'dayMinutes': {'7': 150},
        }),
      );
      final r = PlanGenerator.feasibility(shortRide, start: start, l: l);
      expect(r.issues, contains('longRideTime'));
      expect(r.longRideMin, 150);
      expect(r.longRideTargetMin, 180);
    });
  });

  group('I1 one hard budget across sports', () {
    for (final p in [
      olympic,
      half,
      halfBeginner,
      tri('advanced', 'olympic', const [1, 2, 3, 4, 5, 6, 7], 16),
    ]) {
      test('${p.level} ${p.athlete.eventDistance} ${p.trainingDays.length} days', () {
        final plan = gen(p);
        for (final wk in byWeek(plan).entries) {
          final w = wk.value;
          // Brick runs (intensity "moderate") belong to the long ride; they are no extra session.
          final endurance = w.where((x) => x.sport != Sport.gym && x.intensity != 'moderate').length;
          final budget = endurance <= 4 ? 2.0 : (endurance <= 7 ? 3.0 : 4.0);
          final points = w.fold<double>(0, (x, s) {
            if (s.intensity == 'long') return x + 0.5;
            if (s.sport == Sport.swim && hard(s)) return x + 0.5;
            return x + (hard(s) ? 1 : 0);
          });
          expect(points, lessThanOrEqualTo(budget), reason: '${wk.key}: $points > $budget');
          final keyDays = {for (final s in w.where((s) => s.isKey)) dayOnly(s.date)};
          for (final d in keyDays) {
            final three = keyDays.contains(d.add(const Duration(days: 1))) && keyDays.contains(d.add(const Duration(days: 2)));
            expect(three, isFalse, reason: '${wk.key}: three key days from $d');
          }
          // Base: ≤ 2 quality sessions (beginners 1), CSS included.
          if (w.every((s) => s.phase == 'base')) {
            expect(w.where(hard).length, lessThanOrEqualTo(p.level == 'beginner' ? 1 : 2), reason: '${wk.key}');
          }
          expect(w.where((s) => s.isKey).length, lessThanOrEqualTo(4), reason: '${wk.key}');
        }
      });
    }
  });

  group('I2 long sessions reach race-specific length', () {
    test('marathon long run ≥ 28 km (advanced ≥ 30), ≤ 180 min, at mid easy pace', () {
      final adv = gen(advancedMarathon);
      expect(longest(adv, Sport.run), greaterThanOrEqualTo(30));
      expect(longest(gen(intermediateMarathon), Sport.run), greaterThanOrEqualTo(28));
      for (final p in adv.where((p) => p.intensity == 'long')) {
        expect(p.durationMin, lessThanOrEqualTo(185));
      }
      // No 15-week plateau: the long run grows in the first weeks (R1 ≤ +10 %).
      final longs = adv.where((p) => p.intensity == 'long' && p.phase != 'recovery').map((p) => p.distanceKm!).toList();
      expect(longs[2], greaterThan(longs[0]));
      for (var i = 1; i < longs.length; i++) {
        expect(longs[i], lessThanOrEqualTo(max(longs.take(i).reduce(max), 22) * 1.1 + 0.5));
      }
    });

    test('event-based long-day time: marathon 180, 70.3 240, olympic 150 min', () {
      expect(PlanGenerator.dayMinutesFor(intermediateMarathon, 7), 180);
      expect(PlanGenerator.dayMinutesFor(half, 7), 240);
      expect(PlanGenerator.dayMinutesFor(olympic, 7), 150);
      // The triathlon long run day gets time too (70.3: 2 h).
      final runDay = PlanGenerator.longSessionDays(half)[Sport.run]!;
      expect(PlanGenerator.dayMinutesFor(half, runDay), 120);
    });

    test('70.3 long ride ≥ 3 h, olympic long ride grows from week 1 (not 60 min for weeks)', () {
      expect(longest(gen(half), Sport.ride), greaterThanOrEqualTo(180));
      final oly = gen(olympic).where((p) => p.sport == Sport.ride && p.intensity == 'long' && p.phase != 'recovery').toList();
      expect(oly.first.durationMin, greaterThan(60));
      expect(oly.map((p) => p.durationMin).reduce(max), greaterThanOrEqualTo(120));
    });
  });

  group('I3 bricks', () {
    for (final (p, maxMin) in [
      (olympic, 30),
      (half, 45),
      (tri('beginner', 'sprint', const [1, 3, 5, 6], 12), 20),
    ]) {
      test('${p.athlete.eventDistance}: run off the bike after the long ride from the build phase', () {
        final plan = gen(p);
        final bricks = plan.where((w) => w.sport == Sport.run && w.title.startsWith(l.wBrickRun(0).split(' ').first)).toList();
        expect(bricks.length, greaterThanOrEqualTo(2));
        for (final b in bricks) {
          expect(b.phase, isIn(['build', 'peak']));
          expect(plan.any((w) => w.sport == Sport.ride && w.intensity == 'long' && sameDay(w.date, b.date)), isTrue);
          expect(b.isKey, isFalse);
          expect(b.durationMin, inInclusiveRange(15, maxMin + 5));
        }
        // Every 1–2 weeks once it starts (weekly in the peak phase).
        final weeks = bricks.map((b) => startOfWeek(b.date)).toList();
        for (var i = 1; i < weeks.length; i++) {
          expect(weeks[i].difference(weeks[i - 1]).inDays, lessThanOrEqualTo(21));
        }
      });
    }
  });

  test('I4 70.3 beginner: 2 swims a week, technique ≤ ~1 h, growing continuous repeats, long run at the weekend', () {
    final plan = gen(halfBeginner);
    for (final w in byWeek(plan).values) {
      expect(w.where((p) => p.sport == Sport.swim).length, greaterThanOrEqualTo(2));
    }
    for (final p in plan.where((p) => p.intensity == 'technique')) {
      expect(p.durationMin, lessThanOrEqualTo(65), reason: p.title);
    }
    final reps = [
      for (final p in plan.where((p) => p.sport == Sport.swim && p.intensity == 'easy'))
        p.steps.where((s) => s.isWork).map((s) => s.distanceM ?? 0).fold(0.0, max),
    ];
    expect(reps.first, lessThanOrEqualTo(200));
    expect(reps.reduce(max), greaterThanOrEqualTo(400));
    for (final p in plan.where((p) => p.sport == Sport.run && p.intensity == 'long')) {
      expect(p.date.weekday, greaterThanOrEqualTo(6), reason: '${p.date}');
    }
  });

  test('I8 full body the day before a key session: half the leg sets', () {
    for (final p in [
      UserProfile(level: 'beginner', focus: TrainingFocus.hybrid, experience: const {Sport.run}, trainingDays: const [1, 2, 4, 6]),
      UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.hybrid,
        trainingDays: const [1, 2, 3, 5, 6],
        athlete: const AthleteData(raceTimes: {'10k': 3000}),
      ),
    ]) {
      final plan = gen(p, weeks: 6);
      final keyDays = {for (final w in plan.where((w) => w.isKey)) dayOnly(w.date)};
      final before = plan.where((w) => w.sport == Sport.gym && keyDays.contains(dayOnly(w.date).add(const Duration(days: 1)))).toList();
      expect(before, isNotEmpty);
      for (final g in before) {
        final t = templates.firstWhere((t) => t.id == g.templateId);
        expect(g.exercises, isNotEmpty, reason: g.title);
        expect(g.description.split('\n'), contains(l.wGymLegsHalvedNote));
        for (final (i, e) in g.exercises.indexed) {
          final full = t.exercises[i].workSets.length;
          final lower = classifyLift(e.exId, e.name).lower;
          expect(e.workSets.length, lower ? max(1, full ~/ 2) : full, reason: '${g.title} ${e.name}');
        }
      }
      // Other days keep the full program (no per-day copy).
      expect(plan.where((w) => w.sport == Sport.gym && !before.contains(w)).every((w) => w.exercises.isEmpty), isTrue);
    }
  });

  test('I9 / H3 advanced runners: never two key runs on consecutive days', () {
    for (final p in [
      advancedMarathon,
      UserProfile(
        level: 'advanced',
        focus: TrainingFocus.run,
        trainingDays: const [1, 2, 3, 4, 5, 6, 7],
        athlete: AthleteData(difficulty: 'challenging', runWeeklyKm: 60, eventDistance: '10k', eventDate: race(12)),
      ),
    ]) {
      final keys = {for (final w in gen(p).where((w) => w.sport == Sport.run && w.isKey && w.intensity != 'race')) dayOnly(w.date)};
      for (final d in keys) {
        expect(keys.contains(d.add(const Duration(days: 1))), isFalse, reason: '$d');
      }
    }
  });

  test('I10 peak run volume ≤ 1.5 × the stated weekly volume', () {
    for (final diff in ['balanced', 'challenging']) {
      final p = advancedMarathon.copyWith(athlete: advancedMarathon.athlete.merge({'difficulty': diff}));
      final peak = byWeek(
        gen(p),
      ).values.map((w) => w.where((x) => x.sport == Sport.run).fold(0.0, (a, x) => a + (x.distanceKm ?? 0))).reduce(max);
      expect(peak, lessThanOrEqualTo(55 * 1.5 + 3), reason: diff);
    }
  });

  group('smaller findings', () {
    test('beginners: no planned strength deload in the first 10 weeks', () {
      final p = UserProfile(
        level: 'beginner',
        focus: TrainingFocus.hybrid,
        experience: const {Sport.run},
        trainingDays: const [1, 2, 4, 6],
      );
      final plan = gen(p, weeks: 12);
      expect(plan.where((w) => w.phase == 'recovery' && w.sport == Sport.run), isNotEmpty);
      for (final g in plan.where((w) => w.sport == Sport.gym && w.date.isBefore(start.add(const Duration(days: 70))))) {
        expect(g.phase, isNot('recovery'), reason: '${g.date}');
        expect(g.description, isNot(contains(l.wGymDeloadNote)));
      }
    });

    test('interval repeats are whole 200 m steps; short sessions use shorter repeats', () {
      final p = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.run,
        trainingDays: const [2, 4, 6],
        athlete: AthleteData(sessionMinutes: 30, raceTimes: const {'10k': 3300}, eventDistance: '10k', eventDate: race(10)),
      );
      // VO2max (I) repeats – the goal-pace sets of the peak / taper are a different session.
      final iv = gen(p).where((w) => w.intensity == 'intervals' && w.steps.any((s) => s.isWork && s.zone == 'I')).toList();
      expect(iv, isNotEmpty);
      for (final w in iv) {
        final work = w.steps.where((s) => s.isWork).toList();
        expect(work.every((s) => s.distanceM! % 200 == 0), isTrue, reason: w.title);
        expect(work.length, greaterThanOrEqualTo(3), reason: w.title);
      }
    });

    test('cycling < 5 h: one sweet-spot and one VO2 session in the base phase', () {
      final p = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.ride,
        trainingDays: const [2, 4, 6, 7],
        athlete: const AthleteData(ftp: 220),
      );
      final week = gen(p, weeks: 8).where((w) => startOfWeek(w.date) == start).toList();
      expect(week.where((w) => w.intensity == 'intervals').length, 1);
      expect(week.where((w) => w.intensity == 'tempo').length, 1);
    });

    test('sprint beginner: no VO2max rides, long ride grows beyond 60 min', () {
      final plan = gen(tri('beginner', 'sprint', const [1, 3, 5, 6], 12));
      expect(plan.where((w) => w.steps.any((s) => s.zone == 'Z5')), isEmpty);
      expect(longest(plan, Sport.ride), greaterThan(60));
    });
  });
}
