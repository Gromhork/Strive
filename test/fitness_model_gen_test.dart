import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/step_text.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';

// Review round 2 (fitness model, plan generator structure): C6 three-run HM plans, IMPORTANT 8 sprint
// beginner swims, IMPORTANT 9 Ironman weekends, MINOR marathon easy runs / knee later date / 10 km
// goal-pace label. Profiles as in the review dumps (start Monday 16 Nov 2026).
final start = DateTime(2026, 11, 16);
DateTime race(int weeks) => DateTime(start.year, start.month, start.day + 7 * (weeks - 1) + 6);

UserProfile prof({
  String level = 'intermediate',
  int birth = 1990,
  String gender = 'm',
  List<int> days = const [2, 4, 6, 7],
  Set<Sport>? exp,
  TrainingFocus focus = TrainingFocus.run,
  AthleteData a = const AthleteData(),
}) => UserProfile(
  level: level,
  focus: focus,
  birthYear: birth,
  gender: gender,
  trainingDays: days,
  experience: exp ?? {...focus.sports},
  weightKg: gender == 'f' ? 62 : 72,
  heightCm: gender == 'f' ? 165 : 178,
  athlete: a,
);

final l = lookupAppLocalizations(const Locale('de'));
var _n = 0;
String _id() => 'w${_n++}';
final templates = defaultTemplates(_id, de: true);

List<PlannedWorkout> gen(UserProfile p) =>
    PlanGenerator(l, p, templates, _id).generate(start: start)..sort((x, y) => x.date.compareTo(y.date));

/// Sessions grouped by week (Monday key), in order.
List<List<PlannedWorkout>> weeks(List<PlannedWorkout> plan) {
  final m = <DateTime, List<PlannedWorkout>>{};
  for (final w in plan) {
    m.putIfAbsent(startOfWeek(w.date), () => []).add(w);
  }
  return [for (final k in m.keys.toList()..sort()) m[k]!];
}

double longestLong(List<PlannedWorkout> plan) =>
    plan.where((w) => w.sport == Sport.run && w.intensity == 'long').fold<double>(0, (x, w) => max(x, w.distanceKm ?? 0));

bool loading(List<PlannedWorkout> wk) => wk.every((w) => w.phase != 'recovery' && w.phase != 'taper');

final r3x30 = prof(
  level: 'beginner',
  days: const [2, 4, 7],
  a: AthleteData(setupMode: 'advanced', sessionMinutes: 30, canRun30: true, eventDistance: 'hm', eventDate: race(14)),
);
final a2 = prof(
  level: 'beginner',
  days: const [2, 4, 6],
  a: AthleteData(
    setupMode: 'advanced',
    canRun30: false,
    sessionMinutes: 60,
    dayMinutes: const {6: 150},
    eventDistance: 'hm',
    eventDate: race(20),
  ),
);
UserProfile sprint(int w) => prof(
  level: 'beginner',
  focus: TrainingFocus.triathlon,
  days: const [2, 4, 6, 7],
  a: AthleteData(sessionMinutes: 60, eventDistance: 'sprint', eventDate: race(w)),
);
final ironman = prof(
  level: 'advanced',
  focus: TrainingFocus.triathlon,
  days: const [1, 2, 3, 4, 6, 7],
  a: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 90,
    dayMinutes: const {6: 360, 7: 180},
    raceTimes: const {'10k': 40 * 60, 'm': 3 * 3600 + 15 * 60},
    ftp: 280,
    hasPowerMeter: true,
    eventDistance: 'ironman',
    eventDate: race(28),
  ),
);
final marathon = prof(
  days: const [1, 2, 4, 6, 7],
  a: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 75,
    dayMinutes: const {7: 180},
    raceTimes: const {'hm': 6600},
    runWeeklyKm: 35,
    longestRunKm: 16,
    eventDistance: 'm',
    eventDate: race(18),
    targetTimeSec: 3 * 3600 + 55 * 60,
  ),
);
UserProfile knee(int w) => prof(
  a: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 60,
    dayMinutes: const {7: 120},
    limitations: const ['knee'],
    raceTimes: const {'10k': 55 * 60},
    runWeeklyKm: 20,
    longestRunKm: 10,
    eventDistance: 'hm',
    eventDate: race(w),
  ),
);
final tenK = prof(
  a: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 60,
    raceTimes: const {'10k': 52 * 60 + 30},
    runWeeklyKm: 25,
    longestRunKm: 10,
    eventDistance: '10k',
    eventDate: race(10),
    targetTimeSec: 49 * 60 + 59,
  ),
);

void main() {
  group('C6 three-run half-marathon plans', () {
    test('3 × 30 min: long run grows past 7 km (≤ 65 % of the week), finish goal without a race time', () {
      final plan = gen(r3x30);
      // Before: 7.0 km from W6 to W12 (≤ 50 % / ≤ 2 × the 3.5 km runs). After: 13 km by the peak; since review
      // 2026-11 H3 the long run is ≤ 60 % of a 3-run week (was 65 %): ~11 km next to 30 min runs.
      expect(longestLong(plan), greaterThanOrEqualTo(11));
      for (final wk in weeks(plan).where(loading)) {
        final runs = wk.where((w) => w.sport == Sport.run && w.intensity != 'race').toList();
        final total = runs.fold(0.0, (x, w) => x + (w.distanceKm ?? 0));
        final long = runs.where((w) => w.intensity == 'long').fold<double>(0, (x, w) => max(x, w.distanceKm ?? 0));
        expect(long, lessThanOrEqualTo(PlanGenerator.threeRunLongShare * total + 0.3), reason: '${wk.first.date}');
      }
      // 15 km (2 h on the feet) is still out of reach with 30 min midweek runs: a finish goal.
      expect(PlanGenerator.finishOnly(r3x30, start: start), isTrue);
      final raceW = plan.firstWhere((w) => w.intensity == 'race');
      expect(raceW.steps.single.paceMin, isNull);
      expect(raceW.description, contains(l.wRaceFinishDesc));
      expect(PlanGenerator.outlook(r3x30, start: start).every((o) => o.predictedSec == null), isTrue);
      final f = PlanGenerator.feasibility(r3x30, start: start, l: l);
      expect(f.issues, containsAll(['longRunShare', 'longRunFinish']));
      // Before: "other runs need 90 min" next to a 60 min long day. After: below the long run's time (≤ 60 % of
      // the week since review 2026-11 H3: ~50 min).
      expect(f.otherRunNeedMin, lessThan(60));
      expect(f.planLongKm, greaterThanOrEqualTo(11));
      expect(f.planLongTargetKm, 15);
      expect(f.extraIssueText(l, 'longRunFinish', dayName: (d) => '$d'), contains('Finish-Ziel'));
      expect(f.shorterDistance, '10k');
    });

    test('run/walk beginner, 20 weeks: the long run reaches the HM long run (was 12 km)', () {
      final plan = gen(a2);
      expect(longestLong(plan), greaterThanOrEqualTo(14.5));
      final f = PlanGenerator.feasibility(a2, start: start, l: l);
      expect(f.issues, isNot(contains('longRunShare')));
      expect(f.issues, isNot(contains('longRunFinish')));
    });

    test('a plan that reaches the long run keeps its race time', () {
      expect(PlanGenerator.finishOnly(knee(14), start: start), isFalse);
      expect(PlanGenerator.finishOnly(marathon, start: start), isFalse);
    });
  });

  group('IMPORTANT 8 sprint triathlon beginner', () {
    test('two swims a week and a continuous swim towards the 750 m leg', () {
      final plan = gen(sprint(10));
      final ws = weeks(plan);
      for (final wk in ws.where(loading)) {
        // Before: 1 swim a week.
        expect(wk.where((w) => w.sport == Sport.swim).length, greaterThanOrEqualTo(2), reason: '${wk.first.date}');
      }
      double cont(List<PlannedWorkout> wk) => wk
          .where((w) => w.sport == Sport.swim)
          .expand((w) => w.steps)
          .where((s) => s.isWork && s.zone == 'EN')
          .fold<double>(0, (x, s) => max(x, s.distanceM ?? 0));
      final ladder = [for (final wk in ws.where(loading)) cont(wk)];
      // 300 → 400 → … → 700 m, never shrinking in loading weeks. Before: 200 m at most.
      expect(ladder.first, 300);
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i], greaterThanOrEqualTo(ladder[i - 1]));
      }
      expect(ladder.last, greaterThanOrEqualTo(675));
      expect(PlanGenerator.feasibility(sprint(10), start: start, l: l).issues, isNot(contains('longSwim')));
    });

    test('too few weeks for the continuous swim: the issue offers a later date', () {
      final f = PlanGenerator.feasibility(sprint(3), start: start, l: l);
      // (3 weeks: 300 → 500 m; the first date that builds ≥ 675 m is offered.)
      expect(f.issues, contains('longSwim'));
      expect(f.laterDate, isNotNull);
    });
  });

  group('IMPORTANT 9 Ironman', () {
    test('≥ 3 rides and swims a week; no 30 km long run after a long ride with brick', () {
      final plan = gen(ironman);
      for (final wk in weeks(plan).where(loading)) {
        // Before: 2 rides, 2 swims.
        expect(wk.where((w) => w.sport == Sport.ride).length, greaterThanOrEqualTo(3), reason: '${wk.first.date}');
        expect(wk.where((w) => w.sport == Sport.swim).length, greaterThanOrEqualTo(3), reason: '${wk.first.date}');
      }
      for (final ride in plan.where((w) => w.sport == Sport.ride && w.intensity == 'long' && w.durationMin >= 240)) {
        final brick = plan.any((w) => w.intensity == 'moderate' && w.sport == Sport.run && dayOnly(w.date) == dayOnly(ride.date));
        if (!brick) continue;
        final next = plan.where((w) => w.sport == Sport.run && w.intensity == 'long' && dayOnly(w.date) == addDays(dayOnly(ride.date), 1));
        // Before: 300' + brick, then 30 km. After: ≤ 75 % of the long run (peak ≤ 32 km → 24 km) / ~2 h.
        for (final r in next) {
          expect(r.distanceKm!, lessThanOrEqualTo(24), reason: '${r.date}');
          expect(r.durationMin, lessThanOrEqualTo(120), reason: '${r.date}');
        }
      }
      // The race-specific long run (26 km) and long ride (270 min) are still reached – on alternate weekends.
      expect(longestLong(plan), greaterThanOrEqualTo(25.5));
      expect(
        plan.where((w) => w.sport == Sport.ride && w.intensity == 'long').fold(0, (x, w) => max(x, w.durationMin)),
        greaterThanOrEqualTo(270),
      );
      expect(PlanGenerator.feasibility(ironman, start: start, l: l).issues, isEmpty);
    });
  });

  test('MINOR marathon easy runs ≥ 4 km (taper before race week ≥ 4.5 km)', () {
    final plan = gen(marathon);
    final easy = plan.where((w) => w.sport == Sport.run && w.intensity == 'easy' && w.title != l.wShakeout).toList();
    // Before: 3.0 km in the taper, 3.5 km in base weeks.
    for (final w in easy) {
      expect(w.distanceKm!, greaterThanOrEqualTo(4.0), reason: '${w.date} ${w.phase}');
      if (w.phase == 'taper' && daysBetween(dayOnly(w.date), dayOnly(marathon.athlete.eventDate!)) > 7) {
        expect(w.distanceKm!, greaterThanOrEqualTo(4.5), reason: '${w.date}');
      }
    }
  });

  test('MINOR knee runner HM: 14 weeks reach the long run; a too short plan offers a later date', () {
    // Before: tooShort with laterDate null (one run swapped for a ride, the 4-run share capped the long run).
    expect(PlanGenerator.feasibility(knee(14), start: start, l: l).issues, isNot(contains('tooShort')));
    final f = PlanGenerator.feasibility(knee(7), start: start, l: l);
    expect(f.issues, contains('tooShort'));
    // The first date that works has no issue. (Joint problems: the long run grows ≤ +5 % / 0.5 km a step since
    // review 2026-11 M1 – 10 → 15 km takes longer than the 9 weeks of before.)
    expect(f.laterDate, isNotNull);
    final w = 1 + daysBetween(start, f.laterDate!) ~/ 7;
    const timing = {'tooShort', 'longRunRamp', 'runWalk', 'longRunFinish'};
    expect(PlanGenerator.feasibility(knee(w), start: start, l: l).issues.where(timing.contains), isEmpty);
  });

  test('MINOR 10 km goal pace: zone code M kept, label "race pace" for sets and race alike', () {
    final plan = gen(tenK);
    final sets = plan.where((w) => w.title.startsWith('Zieltempo')).expand((w) => w.steps).where((s) => s.isWork).toList();
    expect(sets, isNotEmpty);
    final raceStep = plan.firstWhere((w) => w.intensity == 'race').steps.single;
    // Before: sets "Zügig" (zone M), race "Schwelle" (zone T).
    for (final s in sets) {
      expect(s.zone, 'M'); // the race-pace convention of GoalForecast.retarget / plan_recalibrate
      expect(zoneLabel(l, s.zone, sport: Sport.run, note: s.note), l.zGoalPace);
    }
    expect(zoneLabel(l, raceStep.zone, sport: Sport.run, note: raceStep.note), l.zGoalPace);
    // Other M / T work keeps its zone name.
    expect(zoneLabel(l, 'M', sport: Sport.run, note: l.stepProgressionNote), l.zMarathon);
  });
}
