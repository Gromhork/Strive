import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/target_suggestion.dart';

/// Target-time suggestion (docs/training-science.md §1.2, §1.12): finish goals, fitness basis,
/// and that every suggested time passes the target check and the feasibility card.
void main() {
  final now = DateTime(2026, 11, 9); // Monday
  DateTime race(int weeks) => now.add(Duration(days: 7 * (weeks - 1) + 6));
  const tenK = {'beginner': 3600, 'intermediate': 3000, 'advanced': 2400};

  TrainingFocus focusFor(String key) => switch (eventDistanceOf(key)!.sport) {
    EventSport.run => TrainingFocus.run,
    EventSport.triathlon => TrainingFocus.triathlon,
    EventSport.duathlon => TrainingFocus.duathlon,
    EventSport.ride => TrainingFocus.ride,
    EventSport.swim => TrainingFocus.swim,
  };

  UserProfile athlete(
    String key, {
    String level = 'intermediate',
    int age = 30,
    Map<String, int>? times,
    bool ftp = false,
    bool swim = false,
    int? target,
  }) => UserProfile(
    level: level,
    birthYear: DateTime.now().year - age,
    focus: focusFor(key),
    experience: const {Sport.run, Sport.ride, Sport.swim},
    trainingDays: const [1, 2, 4, 6, 7],
    athlete: AthleteData(
      raceTimes: times ?? const {},
      runWeeklyKm: 30,
      longestRunKm: 12,
      sessionMinutes: 90,
      dayMinutes: const {6: 180, 7: 180},
      ftp: ftp ? 220 : null,
      swim400Sec: swim ? 400 : null,
      swim200Sec: swim ? 190 : null,
      targetTimeSec: target,
    ),
  );

  UserProfile withTarget(UserProfile p, String key, int weeks, int sec) =>
      p.copyWith(athlete: p.athlete.merge({'eventDistance': key, 'eventDate': race(weeks), 'targetTimeSec': sec}));

  test('matrix: every suggested time passes the target check and the feasibility card', () {
    var suggested = 0, finish = 0;
    for (final d in eventDistances) {
      for (final level in ['beginner', 'intermediate', 'advanced']) {
        for (final times in [false, true]) {
          for (final data in [false, true]) {
            for (final weeks in [4, 8, 12, 16, 24]) {
              for (final age in [30, 55, 70]) {
                final p = athlete(d.key, level: level, age: age, times: times ? {'10k': tenK[level]!} : null, ftp: data, swim: data);
                final s = suggestTargetTime(p, d.key, race(weeks), now: now);
                final what = '${d.key} $level times=$times data=$data weeks=$weeks age=$age';
                expect(s.weeks, weeks, reason: what);
                if (s.finishOnly) {
                  finish++;
                  expect(s.sec, isNull, reason: what);
                  continue;
                }
                suggested++;
                expect(s.fastSec! <= s.sec! && s.sec! <= s.slowSec!, isTrue, reason: what);
                final q = withTarget(p, d.key, weeks, s.sec!);
                expect(GoalModel.check(q, start: now)?.status, TargetStatus.ok, reason: what);
                final issues = PlanGenerator.feasibility(q, start: now).issues;
                expect(issues.contains('targetAmbitious') || issues.contains('targetUnrealistic'), isFalse, reason: '$what $issues');
              }
            }
          }
        }
      }
    }
    expect(suggested, greaterThan(500));
    expect(finish, greaterThan(500));
  });

  test('finish goals: ultra, cycling, open water, run/walk, beginner marathon, multisport without data', () {
    for (final k in ['ultra50', 'ride100', 'ride160', 'swim1500', 'swim3800', 'swim5000']) {
      expect(
        suggestTargetTime(athlete(k, times: const {'10k': 3000}, ftp: true, swim: true), k, race(12), now: now).finishOnly,
        isTrue,
        reason: k,
      );
    }
    expect(suggestTargetTime(athlete('m', level: 'beginner', times: const {'10k': 3600}), 'm', race(16), now: now).finishOnly, isTrue);
    expect(
      suggestTargetTime(athlete('ironman', level: 'beginner', ftp: true, swim: true), 'ironman', race(24), now: now).finishOnly,
      isTrue,
    );
    expect(suggestTargetTime(athlete('olympic'), 'olympic', race(12), now: now).finishOnly, isTrue);
    expect(suggestTargetTime(athlete('olympic', ftp: true), 'olympic', race(12), now: now).finishOnly, isFalse);
    // Beginner who cannot run 30 min starts on run/walk.
    final rw = athlete('5k', level: 'beginner');
    final noRun = rw.copyWith(athlete: rw.athlete.merge({'canRun30': false}));
    expect(PlanGenerator.runWalkStartFor(noRun), isNotNull);
    expect(suggestTargetTime(noRun, '5k', race(12), now: now).finishOnly, isTrue);
  });

  test('basis and confidence', () {
    final r = suggestTargetTime(athlete('10k', times: const {'10k': 3000}), '10k', race(12), now: now);
    expect((r.basis, r.confidence), (TargetBasis.raceTimes, TargetConfidence.high));
    final far = suggestTargetTime(athlete('m', times: const {'5k': 1400}), 'm', race(16), now: now);
    expect((far.basis, far.confidence), (TargetBasis.raceTimes, TargetConfidence.medium));
    final lv = suggestTargetTime(athlete('10k'), '10k', race(12), now: now);
    expect((lv.basis, lv.confidence, lv.vdotNow), (TargetBasis.levelEstimate, TargetConfidence.low, 42));

    Session run(int daysAgo, int sec) => Session(
      id: 's$daysAgo',
      sport: Sport.run,
      title: 'Run',
      start: now.subtract(Duration(days: daysAgo)),
      durationSec: sec,
      distanceM: 5000,
    );
    final be = suggestTargetTime(athlete('10k'), '10k', race(12), now: now, sessions: [run(10, 1500)]);
    expect((be.basis, be.confidence), (TargetBasis.bestEfforts, TargetConfidence.medium));
    expect(be.vdotNow!, lessThan(42));
    expect(be.sec!, greaterThan(lv.sec!));
    // Faster training efforts never lift the estimate above the level default; old runs are ignored.
    expect(suggestTargetTime(athlete('10k'), '10k', race(12), now: now, sessions: [run(10, 1100)]).vdotNow, 42);
    expect(suggestTargetTime(athlete('10k'), '10k', race(12), now: now, sessions: [run(120, 1500)]).basis, TargetBasis.levelEstimate);
    // Consistent with the check also from best efforts.
    final q = withTarget(athlete('10k'), '10k', 12, be.sec!);
    expect(GoalModel.check(q, start: now)!.status, TargetStatus.ok);
  });

  test('10 km in 50:00, intermediate, 12 weeks: slightly faster than 50:00', () {
    final s = suggestTargetTime(athlete('10k', times: const {'10k': 3000}), '10k', race(12), now: now);
    expect(s.sec!, inInclusiveRange(2850, 2990));
    expect(s.vdotRaceDay!, greaterThan(s.vdotNow!));
    expect(s.fastSec!, lessThan(s.sec!));
    expect(s.slowSec!, greaterThan(s.sec!));
  });

  test('marathon from a 10 km race (below advanced): Riegel 1.08 when slower than VDOT', () {
    final p = athlete('m', times: const {'10k': 3000});
    final s = suggestTargetTime(p, 'm', race(16), now: now);
    final vdotOnly = GoalModel.roundTarget(GoalModel.timeAt(withTarget(p, 'm', 16, 1), s.vdotNow!, s.vdotRaceDay! - s.vdotNow!)!);
    expect(s.sec!, greaterThan(vdotOnly));
    // With a half-marathon time the VDOT prediction stands.
    final hm = athlete('m', times: const {'10k': 3000, 'hm': 6700});
    final h = suggestTargetTime(hm, 'm', race(16), now: now);
    expect(h.sec, GoalModel.roundTarget(GoalModel.timeAt(withTarget(hm, 'm', 16, 1), h.vdotNow!, h.vdotRaceDay! - h.vdotNow!)!));
  });

  test('more weeks never give a slower suggestion', () {
    for (final (key, p) in [
      ('5k', athlete('5k', level: 'beginner')),
      ('10k', athlete('10k', times: const {'10k': 3000})),
      ('m', athlete('m', times: const {'10k': 3000}, age: 55)),
      ('hm', athlete('hm', level: 'advanced', times: const {'hm': 5400}, age: 70)),
      ('olympic', athlete('olympic', ftp: true, swim: true)),
      ('du_sprint', athlete('du_sprint', level: 'beginner', times: const {'5k': 1800})),
    ]) {
      int? prev;
      for (var w = 2; w <= 40; w++) {
        final sec = suggestTargetTime(p, key, race(w), now: now).sec!;
        if (prev != null) expect(sec, lessThanOrEqualTo(prev), reason: '$key week $w');
        prev = sec;
      }
    }
  });
}
