import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/progression_check.dart';

/// Beginner progression check (run/walk, growing long session, swim novice ladder) and its
/// effect on the goal forecast.
void main() {
  final now = DateTime(2026, 11, 10, 9); // Tuesday
  final day0 = DateTime(2026, 10, 20); // 3 weeks back (Tuesday)
  var n = 0;

  UserProfile athlete({
    String level = 'beginner',
    String ev = '10k',
    int weeksLeft = 10,
    bool canSwim400 = true,
    Sport sport = Sport.run,
  }) => UserProfile(
    level: level,
    focus: sport == Sport.swim ? TrainingFocus.swim : TrainingFocus.run,
    experience: {sport},
    trainingDays: const [2, 4, 6],
    athlete: AthleteData(eventDistance: ev, eventDate: now.add(Duration(days: 7 * weeksLeft)), canSwim400: canSwim400),
  );

  const walk = WorkoutStep(kind: 'warmup', durationSec: 300, zone: 'walk');
  const run = WorkoutStep(kind: 'work', durationSec: 300, zone: 'E');

  PlannedWorkout runWalk(DateTime d, {int min = 40, String intensity = 'easy'}) => PlannedWorkout(
    id: 'p${n++}',
    date: d,
    sport: Sport.run,
    title: 'Run/walk 4 × 5 min',
    durationMin: min,
    intensity: intensity,
    phase: 'base',
    steps: const [walk, run, WorkoutStep(kind: 'recovery', durationSec: 120, zone: 'walk'), run, walk],
  );

  PlannedWorkout long(DateTime d, {double km = 8, int min = 60}) => PlannedWorkout(
    id: 'p${n++}',
    date: d,
    sport: Sport.run,
    title: 'Long run',
    durationMin: min,
    distanceKm: km,
    intensity: 'long',
    phase: 'base',
    steps: const [WorkoutStep(kind: 'steady', distanceM: 8000, zone: 'E')],
  );

  PlannedWorkout easy(DateTime d) =>
      PlannedWorkout(id: 'p${n++}', date: d, sport: Sport.run, title: 'Easy run', durationMin: 30, distanceKm: 4, phase: 'base');

  Session done(PlannedWorkout x, {double? km, int? min, int? rpe}) => Session(
    id: 's${n++}',
    sport: x.sport,
    title: x.title,
    start: x.date.add(const Duration(hours: 18)),
    durationSec: (min ?? x.durationMin) * 60,
    distanceM: (km ?? x.distanceKm ?? 0) * 1000,
    rpe: rpe,
    planId: x.id,
  );

  // 3 weeks of: run/walk Tue, easy Thu, long Sat.
  List<PlannedWorkout> weeks({double longKm = 8}) => [
    for (var w = 0; w < 3; w++) ...[
      runWalk(day0.add(Duration(days: 7 * w))),
      easy(day0.add(Duration(days: 7 * w + 2))),
      long(day0.add(Duration(days: 7 * w + 4)), km: longKm + w),
    ],
  ];

  ProgressionCheck? check(UserProfile p, List<PlannedWorkout> plans, List<Session> sessions) =>
      progressionCheck(p, plans: plans, sessions: sessions, now: now);

  group('progressionCheck', () {
    test('all done as planned: not behind, no options', () {
      final plans = weeks();
      final c = check(athlete(), plans, [for (final x in plans) done(x, rpe: 4)])!;
      expect(c.behind, isFalse);
      expect(c.issues, isEmpty);
      expect(c.options, isEmpty);
      expect(c.plannedLong, 3);
      expect(c.doneLong, 3);
      expect(c.longAchievedShare, closeTo(1, 1e-9));
    });

    test('over-delivery is capped per session (does not hide a short one)', () {
      final plans = weeks();
      final longs = plans.where((x) => x.intensity == 'long').toList();
      final s = [
        done(longs[0], km: 20, rpe: 4), // 250 %, counts 100 %
        done(longs[1], km: 4.5, rpe: 4), // 50 %
        done(longs[2], km: 5, rpe: 4), // 50 %
      ];
      final c = check(athlete(), plans, s)!;
      expect(c.longAchievedShare, closeTo(2 / 3, 1e-9));
      expect(c.behind, isTrue);
      expect(c.issues, [ProgressionIssue.longSessionsShort]);
    });

    test('long sessions short (< 80 %): behind with options', () {
      final plans = weeks();
      final s = [for (final x in plans) x.intensity == 'long' ? done(x, km: x.distanceKm! * 0.6, rpe: 5) : done(x, rpe: 4)];
      final c = check(athlete(), plans, s)!;
      expect(c.behind, isTrue);
      expect(c.issues, [ProgressionIssue.longSessionsShort]);
      expect(c.longAchievedShare, closeTo(0.6, 1e-9));
      // 10 km: repeat, later race, shorter (5 km), run/walk finish.
      expect(c.options, [
        ProgressionOption.repeatWeek,
        ProgressionOption.laterRace,
        ProgressionOption.shorterDistance,
        ProgressionOption.runWalkRace,
      ]);
    });

    test('two long sessions missed: behind (missed, not short)', () {
      final plans = weeks();
      final longs = plans.where((x) => x.intensity == 'long').toList();
      final s = [
        for (final x in plans)
          if (x != longs[0] && x != longs[1]) done(x, rpe: 4),
      ];
      final c = check(athlete(), plans, s)!;
      expect(c.behind, isTrue);
      expect(c.issues, [ProgressionIssue.longSessionsMissed]);
      expect(c.doneLong, 1);
    });

    test('one long session missed out of three, others full: share 0.67 → behind (missed)', () {
      final plans = weeks();
      final longs = plans.where((x) => x.intensity == 'long').toList();
      final c =
          check(athlete(), plans, [
            for (final x in plans)
              if (x != longs[0]) done(x, rpe: 4),
          ])!;
      expect(c.behind, isTrue);
      expect(c.issues, [ProgressionIssue.longSessionsMissed]);
    });

    test('long session marked done without data counts as achieved', () {
      final plans = [
        for (final x in weeks())
          x.intensity == 'long'
              ? PlannedWorkout(
                id: x.id,
                date: x.date,
                sport: x.sport,
                title: x.title,
                durationMin: x.durationMin,
                distanceKm: x.distanceKm,
                intensity: 'long',
                status: 'done',
              )
              : x,
      ];
      final c =
          check(athlete(), plans, [
            for (final x in plans)
              if (x.intensity != 'long') done(x, rpe: 4),
          ])!;
      expect(c.behind, isFalse);
      expect(c.longAchievedShare, closeTo(1, 1e-9));
    });

    test('run/walk long session is judged by duration, not distance', () {
      final plans = [for (var w = 0; w < 3; w++) runWalk(day0.add(Duration(days: 7 * w + 4)), min: 50, intensity: 'long')];
      // Walked a lot (short distance) but stayed out the planned time: on track.
      final c = check(athlete(), plans, [for (final x in plans) done(x, km: 3, rpe: 4)])!;
      expect(c.behind, isFalse);
      expect(c.longAchievedShare, closeTo(1, 1e-9));
      // 30 of 50 min: short.
      final c2 = check(athlete(), plans, [for (final x in plans) done(x, min: 30, rpe: 4)])!;
      expect(c2.issues, containsAll([ProgressionIssue.longSessionsShort, ProgressionIssue.runWalkNotAchieved]));
    });

    test('run/walk not achieved: ≥ 2 sessions cut short or at RPE ≥ 7 (C25K: progress only at RPE ≤ 5)', () {
      final plans = weeks();
      final rw = plans.where(isRunWalk).toList();
      List<Session> with2(Session Function(PlannedWorkout) bad) => [
        for (final x in plans) rw.indexOf(x) == 0 || rw.indexOf(x) == 1 ? bad(x) : done(x, rpe: 4),
      ];
      final c = check(athlete(), plans, with2((x) => done(x, min: 25, rpe: 5)))!;
      expect(c.issues, [ProgressionIssue.runWalkNotAchieved]);
      expect(c.behind, isTrue);
      expect(check(athlete(), plans, with2((x) => done(x, rpe: 7)))!.issues, [ProgressionIssue.runWalkNotAchieved]);
      // Only one such session: fine.
      final one = [for (final x in plans) x == rw[0] ? done(x, rpe: 7) : done(x, rpe: 4)];
      expect(check(athlete(), plans, one)!.behind, isFalse);
    });

    test('high effort: ≥ 2 long sessions at RPE ≥ 8', () {
      final plans = weeks();
      final longs = plans.where((x) => x.intensity == 'long').toList();
      final s = [for (final x in plans) done(x, rpe: longs.indexOf(x) >= 1 ? 8 : 4)];
      final c = check(athlete(), plans, s)!;
      expect(c.issues, [ProgressionIssue.highEffort]);
      expect(c.behind, isTrue);
    });

    test('null: no event, not a progression athlete, too few relevant sessions', () {
      final plans = weeks();
      final s = [for (final x in plans) done(x)];
      final noEvent = UserProfile(level: 'beginner', athlete: const AthleteData());
      expect(check(noEvent, plans, s), isNull);
      // Intermediate without run/walk sessions: not a progression athlete.
      final noRw = plans.where((x) => !isRunWalk(x)).toList();
      expect(check(athlete(level: 'intermediate'), noRw, s), isNull);
      // ... but with run/walk sessions in the plan it is.
      expect(check(athlete(level: 'intermediate'), plans, s), isNotNull);
      // One long session only.
      expect(check(athlete(), [long(day0.add(const Duration(days: 4)))], const []), isNull);
      // Sessions older than 3 weeks or from today on do not count.
      final old = [for (var w = 4; w < 7; w++) long(now.subtract(Duration(days: 7 * w)))];
      expect(check(athlete(), [...old, long(now), long(now.add(const Duration(days: 2)))], const []), isNull);
    });

    test('options: half marathon offers Galloway run/walk and shorter, 5 km no shorter distance', () {
      final plans = weeks();
      final s = [
        for (final x in plans)
          if (x.intensity != 'long') done(x, rpe: 4),
      ];
      expect(check(athlete(ev: 'hm'), plans, s)!.options, [
        ProgressionOption.repeatWeek,
        ProgressionOption.laterRace,
        ProgressionOption.shorterDistance,
        ProgressionOption.runWalkRace,
      ]);
      expect(check(athlete(ev: '5k'), plans, s)!.options, [
        ProgressionOption.repeatWeek,
        ProgressionOption.laterRace,
        ProgressionOption.runWalkRace,
      ]);
      // Marathon: shorter distances, but no run/walk race.
      expect(check(athlete(ev: 'm'), plans, s)!.options, [
        ProgressionOption.repeatWeek,
        ProgressionOption.laterRace,
        ProgressionOption.shorterDistance,
      ]);
    });

    test('swim novice: ladder swims judged by distance', () {
      PlannedWorkout swim(DateTime d) => PlannedWorkout(
        id: 'p${n++}',
        date: d,
        sport: Sport.swim,
        title: 'Swim',
        durationMin: 40,
        phase: 'base',
        steps: const [
          WorkoutStep(kind: 'warmup', distanceM: 150, zone: 'REC'),
          WorkoutStep(kind: 'work', distanceM: 100, zone: 'EN'),
          WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'),
          WorkoutStep(kind: 'work', distanceM: 100, zone: 'EN'),
          WorkoutStep(kind: 'cooldown', distanceM: 50, zone: 'REC'),
        ],
      );
      final plans = [for (var w = 0; w < 3; w++) swim(day0.add(Duration(days: 7 * w)))];
      final p = athlete(level: 'intermediate', ev: 'sprint', canSwim400: false, sport: Sport.swim);
      final ok = check(p, plans, [for (final x in plans) done(x, km: 0.4)])!;
      expect(ok.behind, isFalse);
      final short = check(p, plans, [for (final x in plans) done(x, km: 0.2)])!;
      expect(short.behind, isTrue);
      expect(short.longAchievedShare, closeTo(0.5, 1e-9));
      // A swimmer who can swim 400 m (intermediate) is not checked.
      expect(check(athlete(level: 'intermediate', ev: 'sprint', sport: Sport.swim), plans, const []), isNull);
    });
  });

  group('GoalForecast integration', () {
    GoalForecast fc(UserProfile p, List<PlannedWorkout> plans, List<Session> s) => GoalForecast.of(p, plans: plans, sessions: s, now: now)!;

    test('on track: no progression reason', () {
      final plans = weeks();
      final f = fc(athlete(), plans, [for (final x in plans) done(x, rpe: 4)]);
      expect(f.progression, isNotNull);
      expect(f.progression!.behind, isFalse);
      expect(f.reasons, isNot(contains(ForecastReason.longRunBehind)));
      expect(f.status, isNot(ForecastStatus.atRisk));
    });

    test('long sessions 70 % with 10 weeks left: slightly behind', () {
      final plans = weeks();
      final s = [for (final x in plans) x.intensity == 'long' ? done(x, km: x.distanceKm! * 0.7, rpe: 5) : done(x, rpe: 4)];
      final f = fc(athlete(weeksLeft: 10), plans, s);
      expect(f.reasons.where((r) => r == ForecastReason.longRunBehind).length, 1); // not twice
      expect(f.status, ForecastStatus.slightlyBehind);
      expect(f.alert, isFalse);
    });

    test('long sessions behind with ≤ 8 weeks left, or < 60 % achieved: at risk (alert)', () {
      final plans = weeks();
      final s70 = [for (final x in plans) x.intensity == 'long' ? done(x, km: x.distanceKm! * 0.7, rpe: 5) : done(x, rpe: 4)];
      final f = fc(athlete(weeksLeft: 8), plans, s70);
      expect(f.status, ForecastStatus.atRisk);
      expect(f.alert, isTrue);
      final s50 = [for (final x in plans) x.intensity == 'long' ? done(x, km: x.distanceKm! * 0.5, rpe: 5) : done(x, rpe: 4)];
      expect(fc(athlete(weeksLeft: 12), plans, s50).status, ForecastStatus.atRisk);
    });

    test('run/walk not achieved alone: slightly behind, not at risk', () {
      final plans = weeks();
      final s = [for (final x in plans) isRunWalk(x) ? done(x, rpe: 7) : done(x, rpe: 4)];
      final f = fc(athlete(weeksLeft: 6), plans, s);
      expect(f.progression!.issues, [ProgressionIssue.runWalkNotAchieved]);
      expect(f.status, ForecastStatus.slightlyBehind);
      expect(f.reasons, isNot(contains(ForecastReason.longRunBehind))); // the UI reads progression.issues
    });

    test('run/walk long sessions short (no distance): progression adds the long-run reason', () {
      final plans = [
        for (var w = 0; w < 3; w++) ...[
          runWalk(day0.add(Duration(days: 7 * w))),
          runWalk(day0.add(Duration(days: 7 * w + 4)), min: 50, intensity: 'long'),
        ],
      ];
      final s = [for (final x in plans) x.intensity == 'long' ? done(x, min: 35, rpe: 4) : done(x, rpe: 4)];
      final f = fc(athlete(weeksLeft: 12), plans, s);
      expect(f.progression!.issues, [ProgressionIssue.longSessionsShort, ProgressionIssue.runWalkNotAchieved]);
      expect(f.reasons, contains(ForecastReason.longRunBehind));
      expect(f.status, ForecastStatus.slightlyBehind);
    });

    test('not a progression athlete: progression null, forecast unchanged', () {
      final plans = weeks().where((x) => !isRunWalk(x)).toList();
      final s = [for (final x in plans) x.intensity == 'long' ? done(x, km: x.distanceKm! * 0.5) : done(x)];
      final f = fc(athlete(level: 'intermediate'), plans, s);
      expect(f.progression, isNull);
    });
  });
}
