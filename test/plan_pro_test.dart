import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/event_spec.dart';
import 'package:strive/services/plan_generator.dart';

/// fix/plan-pro: user reports (time on the long day, 70.3 long runs, swim beginners) and the new
/// race distances (Ironman, ultra, duathlon, cycling, open water).
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9);
  DateTime race(int weeks) => start.add(Duration(days: 7 * (weeks - 1) + 6));
  List<PlannedWorkout> gen(UserProfile p) => PlanGenerator(l, p, const [], id).generate(start: start);
  double longest(List<PlannedWorkout> plan, Sport s, {bool min = false}) => plan
      .where((w) => w.sport == s && w.intensity == 'long')
      .fold(0.0, (x, w) => max(x, min ? w.durationMin.toDouble() : (w.distanceKm ?? 0)));

  UserProfile tri(String event, {String level = 'intermediate', int minutes = 60, Map<int, int> days = const {}, int weeks = 16}) =>
      UserProfile(
        level: level,
        focus: TrainingFocus.triathlon,
        birthYear: 1990,
        experience: const {Sport.run, Sport.ride, Sport.swim},
        trainingDays: const [1, 2, 3, 4, 6, 7],
        athlete: AthleteData(
          sessionMinutes: minutes,
          dayMinutes: days,
          raceTimes: level == 'beginner' ? const {} : const {'10k': 2880},
          eventDistance: event,
          eventDate: race(weeks),
        ),
      );

  group('time on the long day (user report: "4 h a day and still only 120 min")', () {
    // Detailed setup, two sessions a day: Saturday swim + long ride with 4 h a day. The even split
    // gave the long ride 2 h and the feasibility card said the day was too short.
    final p = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.triathlon,
      birthYear: 1990,
      experience: const {Sport.run, Sport.ride, Sport.swim},
      trainingDays: const [2, 4, 6, 7],
      longDay: 6,
      athlete: AthleteData(
        setupMode: 'advanced',
        sessionsPerDay: 2,
        sessionMinutes: 240,
        dayPlan: const {
          2: [Sport.swim, Sport.run],
          4: [Sport.ride],
          6: [Sport.swim, Sport.ride],
          7: [Sport.run],
        },
        raceTimes: const {'10k': 2880},
        eventDistance: '70.3',
        eventDate: race(20),
      ),
    );

    test('a short session on the long day gets what it needs, the long ride the rest', () {
      expect(PlanGenerator.splitDayMinutes(240, 2, 1, true), 180);
      expect(PlanGenerator.splitDayMinutes(240, 2, 1, false), 60);
      expect(PlanGenerator.splitDayMinutes(120, 2, 1, true), 80);
      expect(PlanGenerator.splitDayMinutes(90, 2, 0, false), 45);
      final f = PlanGenerator.feasibility(p, start: start, l: l);
      expect(f.issues, isNot(contains('longRideTime')));
      expect(longest(gen(p), Sport.ride, min: true), greaterThanOrEqualTo(165));
    });

    test('a day that really is too short: raise it to … or move the long session there', () {
      final short = p.copyWith(
        athlete: p.athlete.merge({
          'dayMinutes': {6: 150},
        }),
      );
      final f = PlanGenerator.feasibility(short, start: start, l: l);
      expect(f.issues, contains('longRideTime'));
      expect(f.raiseDay, 6);
      expect(f.raiseDayMin! % 15, 0);
      expect(f.raiseDayMin, greaterThan(150));
      // Thursday (ride, 240 min) has the time: offered as the new long day.
      expect(f.moveDay, isNotNull);
      // … enough for the long ride (180 min) plus the brick run on a day of its own.
      expect(PlanGenerator.dayMinutesFor(short, f.moveDay!), greaterThanOrEqualTo(180 + 45));
    });
  });

  group('long sessions progress and peak 2–3 weeks out (user report: 70.3 long run 11 km)', () {
    test('70.3 intermediate, 16 weeks: long run ≥ 16 km, long ride ≥ 3 h, last long run 2 weeks out', () {
      final p = tri('70.3', minutes: 75);
      final plan = gen(p);
      expect(longest(plan, Sport.run), greaterThanOrEqualTo(15.5));
      expect(longest(plan, Sport.ride, min: true), greaterThanOrEqualTo(165));
      final raceDay = dayOnly(p.athlete.eventDate!);
      final longRuns = plan.where((w) => w.sport == Sport.run && w.intensity == 'long').toList();
      final peak = longRuns.reduce((x, y) => (y.distanceKm ?? 0) >= (x.distanceKm ?? 0) ? y : x);
      final weeksOut = (startOfWeek(raceDay).difference(startOfWeek(peak.date)).inDays / 7).round();
      expect(weeksOut, inInclusiveRange(2, 3));
      // The week before race week: clearly shorter (~65 %).
      final taper = longRuns.where((w) => w.phase == 'taper').map((w) => w.distanceKm ?? 0);
      expect(taper.every((k) => k <= (peak.distanceKm ?? 0) * 0.7 + 0.5), isTrue);
    });

    test('Ironman: 3-week taper, long ride ~5 h, long run ≤ 30 km / 165 min', () {
      final p = tri('ironman', level: 'advanced', minutes: 90, days: const {6: 360, 7: 180}, weeks: 28);
      final plan = gen(p);
      expect(plan.where((w) => w.phase == 'taper').map((w) => startOfWeek(w.date)).toSet().length, 3);
      expect(longest(plan, Sport.ride, min: true), greaterThanOrEqualTo(270));
      expect(longest(plan, Sport.run), lessThanOrEqualTo(30));
      expect(plan.where((w) => w.sport == Sport.run && w.intensity == 'long').every((w) => w.durationMin <= 170), isTrue);
      // Fuelling practice on the long sessions of a long race.
      expect(plan.where((w) => w.intensity == 'long' && w.description.contains(l.wFuelPracticeNote)), isNotEmpty);
    });
  });

  group('swim beginners (user report: "13 × 100 m CSS" for someone who cannot swim 400 m)', () {
    for (final level in ['intermediate', 'advanced']) {
      test('$level who cannot swim 400 m: short sessions, the ladder, then a CSS test, then CSS sets', () {
        final base = tri('olympic', level: level, weeks: 20);
        final p = base.copyWith(athlete: base.athlete.merge({'canSwim400': false}));
        final swims = gen(p).where((w) => w.sport == Sport.swim && w.intensity != 'race').toList();
        double m(PlannedWorkout w) => w.steps.fold(0.0, (x, s) => x + (s.distanceM ?? 0));
        expect(m(swims.first), lessThanOrEqualTo(1200));
        expect(swims.take(4).every((w) => m(w) >= 400 && m(w) <= 1500), isTrue);
        final test = swims.indexWhere((w) => w.title == l.wSwimCssTest);
        expect(test, greaterThan(0), reason: 'CSS test once 400 m in one go is reached');
        final css = swims.indexWhere((w) => w.steps.any((s) => s.zone == 'CSS'));
        expect(css, greaterThan(test), reason: 'no CSS set before the test');
        // The ladder grows: 50 m repeats first, 400 m at the end.
        expect(swims.first.steps.where((s) => s.zone == 'EN').every((s) => (s.distanceM ?? 0) <= 50), isTrue);
      });
    }

    test('no swim experience: the first swims start at the beginner volume', () {
      final p = tri('olympic').copyWith(experience: const {Sport.run, Sport.ride});
      final first = gen(p).firstWhere((w) => w.sport == Sport.swim);
      expect(first.steps.fold(0.0, (x, s) => x + (s.distanceM ?? 0)), lessThanOrEqualTo(1600));
    });
  });

  group('every catalogue distance', () {
    for (final d in eventDistances) {
      test('${d.key}: race on race day as the right sport, taper from the table', () {
        final spec = EventSpec.of(d.key)!;
        final focus = switch (d.sport) {
          EventSport.run => TrainingFocus.run,
          EventSport.triathlon => TrainingFocus.triathlon,
          EventSport.duathlon => TrainingFocus.duathlon,
          EventSport.ride => TrainingFocus.ride,
          EventSport.swim => TrainingFocus.swim,
        };
        final weeks = spec.weeks.$2;
        final p = UserProfile(
          level: 'advanced',
          focus: focus,
          birthYear: 1990,
          experience: {...focus.sports},
          trainingDays: const [1, 2, 4, 6, 7],
          athlete: AthleteData(sessionMinutes: 90, raceTimes: const {'10k': 2700}, ftp: 250, eventDistance: d.key, eventDate: race(weeks)),
        );
        final plan = gen(p);
        final races = plan.where((w) => w.intensity == 'race').toList();
        expect(races, hasLength(1));
        expect(dayOnly(races.single.date), dayOnly(p.athlete.eventDate!));
        expect(races.single.sport, switch (d.sport) {
          EventSport.triathlon || EventSport.swim => Sport.swim,
          EventSport.ride => Sport.ride,
          _ => Sport.run,
        });
        expect(races.single.durationMin, greaterThan(10));
        final taperWeeks = plan.where((w) => w.phase == 'taper').map((w) => startOfWeek(w.date)).toSet().length;
        expect(taperWeeks, spec.taperFor('advanced'));
        expect(plan.where((w) => w.date.isAfter(races.single.date)), isEmpty);
      });
    }

    test('ultra: back-to-back runs in build / peak, trail note', () {
      final p = UserProfile(
        level: 'advanced',
        focus: TrainingFocus.run,
        birthYear: 1990,
        experience: const {Sport.run},
        trainingDays: const [1, 2, 4, 6, 7],
        athlete: AthleteData(
          sessionMinutes: 90,
          runWeeklyKm: 60,
          raceTimes: const {'m': 12600},
          eventDistance: 'ultra50',
          eventDate: race(20),
        ),
      );
      final plan = gen(p);
      expect(plan.where((w) => w.title == l.wBackToBack), isNotEmpty);
      expect(PlanGenerator.dayMinutesFor(p, PlanGenerator.backToBackDay(p)!), greaterThanOrEqualTo(120));
      expect(plan.where((w) => w.description.contains(l.wTrailNote)), isNotEmpty);
    });

    test('open water: a growing long continuous swim with sighting', () {
      final p = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.swim,
        birthYear: 1990,
        experience: const {Sport.swim},
        trainingDays: const [2, 4, 6],
        athlete: AthleteData(sessionMinutes: 75, swim400Sec: 400, swim200Sec: 190, eventDistance: 'swim3800', eventDate: race(16)),
      );
      final longs = gen(p).where((w) => w.sport == Sport.swim && w.intensity == 'long').toList();
      final m = longs.map((w) => w.steps.where((s) => s.zone == 'EN').fold(0.0, (x, s) => max(x, s.distanceM ?? 0))).toList();
      expect(m.first, lessThan(m.reduce(max)));
      expect(m.reduce(max), greaterThanOrEqualTo(2000));
      expect(longs.any((w) => w.steps.any((s) => s.note == l.stepSightingNote)), isTrue);
    });

    test('duathlon peak: run – bike – run on the long-ride day', () {
      final p = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.duathlon,
        birthYear: 1990,
        experience: const {Sport.run, Sport.ride},
        trainingDays: const [1, 3, 5, 6, 7],
        athlete: AthleteData(sessionMinutes: 120, raceTimes: const {'10k': 2700}, eventDistance: 'du_standard', eventDate: race(14)),
      );
      final plan = gen(p);
      expect(plan.where((w) => w.phase == 'peak' && w.title == l.wDuRunFirst(10)), isNotEmpty);
    });
  });
}
