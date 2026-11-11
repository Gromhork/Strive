import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Goal-driven plans (docs/training-science.md §1.12): plan length to race day, target-time
/// realism, race-pace work, phase outlook and the goal forecast.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9); // Monday
  final templates = defaultTemplates(id, de: false);
  DateTime race(int weeks) => start.add(Duration(days: 7 * (weeks - 1) + 6));
  List<PlannedWorkout> gen(UserProfile p, {DateTime? from}) => PlanGenerator(l, p, templates, id).generate(start: from ?? start);

  UserProfile runner({String ev = '10k', int weeks = 12, int? target, String level = 'intermediate', Map<String, int>? times}) =>
      UserProfile(
        level: level,
        focus: TrainingFocus.run,
        experience: const {Sport.run},
        trainingDays: const [2, 4, 6, 7],
        athlete: AthleteData(
          raceTimes: times ?? const {'10k': 3000},
          runWeeklyKm: 30,
          longestRunKm: 12,
          sessionMinutes: 75,
          eventDistance: ev,
          eventDate: race(weeks),
          targetTimeSec: target,
        ),
      );

  group('GoalModel', () {
    test('gain: beginners improve faster than advanced runners, curve flattens', () {
      for (final lv in ['beginner', 'intermediate', 'advanced']) {
        final p = UserProfile(level: lv);
        expect(GoalModel.gain(p, 8), greaterThan(GoalModel.gain(p, 4)));
        expect(GoalModel.gain(p, 8) - GoalModel.gain(p, 4), lessThan(GoalModel.gain(p, 4)));
      }
      // Daniels: ~1 VDOT per 4–6 weeks for trained runners.
      final inter = GoalModel.gain(const UserProfile(level: 'intermediate'), 12);
      expect(inter, inInclusiveRange(1.8, 3.0));
      expect(GoalModel.gain(const UserProfile(level: 'beginner'), 12), greaterThan(inter));
      expect(GoalModel.gain(const UserProfile(level: 'advanced'), 12), lessThan(inter));
    });

    test('target check: ok / ambitious / unrealistic for a 50:00 10 km runner in 12 weeks', () {
      TargetStatus? s(int t) => GoalModel.check(runner(target: t), start: start)?.status;
      expect(s(2910), TargetStatus.ok); // 48:30
      expect(s(2850), TargetStatus.ambitious); // 47:30
      expect(s(2700), TargetStatus.unrealistic); // 45:00
      expect(GoalModel.check(runner(), start: start), isNull); // no target
    });

    test('unrealistic target: suggested time and later date both pass', () {
      final c = GoalModel.check(runner(target: 2760), start: start)!;
      expect(c.status, isNot(TargetStatus.ok));
      expect(c.suggestedSec, greaterThanOrEqualTo(c.realisticSec));
      expect(c.realisticSec, lessThan(c.currentSec));
      expect(GoalModel.check(runner(target: c.suggestedSec), start: start)!.status, TargetStatus.ok);
      expect(c.laterDate, isNotNull);
      final later = runner(target: 2760).copyWith(athlete: runner(target: 2760).athlete.merge({'eventDate': c.laterDate}));
      expect(GoalModel.check(later, start: start)!.status, TargetStatus.ok);
      expect(c.goalVdot, greaterThan(c.currentVdot));
    });

    test('triathlon: checked with FTP / swim data, finish-oriented without', () {
      final tri = UserProfile(
        level: 'intermediate',
        focus: TrainingFocus.triathlon,
        athlete: AthleteData(eventDistance: 'olympic', eventDate: race(16), targetTimeSec: 3 * 3600),
      );
      expect(GoalModel.check(tri, start: start), isNull);
      final withFtp = tri.copyWith(
        athlete: tri.athlete.merge({
          'ftp': 220,
          'raceTimes': const {'10k': 2700},
        }),
      );
      final c = GoalModel.check(withFtp, start: start)!;
      expect(c.status, TargetStatus.ok);
      expect(c.currentSec, inInclusiveRange(2 * 3600, 3 * 3600));
      // Bike: ~220 W FTP, 75 kg → 30–36 km/h on a flat course at 85 % FTP.
      expect(GoalModel.bikeKmh(220, 75, 'intermediate', 0.85), inInclusiveRange(28, 36));
    });
  });

  group('plan aligned to the event', () {
    test('event 40 weeks away: plan runs to race day, base pre-plan before the 30 specific weeks', () {
      final p = runner(ev: 'hm', weeks: 40);
      final plan = gen(p);
      final raceDay = plan.where((w) => w.intensity == 'race').single;
      expect(sameDay(raceDay.date, race(40)), isTrue);
      expect(plan.every((w) => !w.date.isAfter(race(40))), isTrue);
      // The first 10 weeks are base (or recovery weeks inside it).
      final early = plan.where((w) => w.date.isBefore(start.add(const Duration(days: 70))));
      expect(early.every((w) => w.phase == 'base' || w.phase == 'recovery'), isTrue);
      for (final ph in ['build', 'peak', 'taper']) {
        expect(plan.any((w) => w.phase == ph), isTrue, reason: ph);
      }
      final o = PlanGenerator.outlook(p, start: start);
      expect(o.fold<int>(0, (x, e) => x + e.weeks), 40);
      expect(o.map((e) => e.phase).toList(), ['base', 'build', 'peak', 'taper']);
    });

    test('event > 52 weeks away is not aligned (plan length from the settings)', () {
      final plan = gen(runner(weeks: 60));
      expect(plan.where((w) => w.intensity == 'race'), isEmpty);
    });

    test('outlook: expected fitness rises phase by phase to the realistic race-day time', () {
      final p = runner(target: 2760);
      final o = PlanGenerator.outlook(p, start: start);
      for (var i = 1; i < o.length; i++) {
        expect(o[i].expectedVdot, greaterThanOrEqualTo(o[i - 1].expectedVdot));
        expect(o[i].firstWeek, o[i - 1].firstWeek + o[i - 1].weeks);
      }
      expect(o.last.predictedSec, GoalModel.check(p, start: start)!.realisticSec);
    });
  });

  group('target-time driven paces', () {
    List<WorkoutStep> work(List<PlannedWorkout> plan, String zone) => [
      for (final w in plan.where((w) => w.sport == Sport.run && w.intensity != 'race'))
        for (final s in w.steps.where((s) => s.isWork && s.zone == zone)) s,
    ];
    List<WorkoutStep> racePace(List<PlannedWorkout> plan) => [
      for (final w in plan.where((w) => w.sport == Sport.run && w.phase == 'peak'))
        for (final s in w.steps.where((s) => s.isWork && s.zone == 'M')) s,
    ];

    test('training paces stay on the current fitness, whatever the target', () {
      final none = gen(runner(ev: 'm', weeks: 18, times: const {'hm': 6300}));
      final goal = gen(runner(ev: 'm', weeks: 18, times: const {'hm': 6300}, target: 4 * 3600 + 300));
      final pz = PaceZones(Vdot.fromRace(21097.5, 6300));
      for (final z in ['T', 'I', 'E']) {
        final a = {for (final s in work(none, z)) s.paceMin}, b = {for (final s in work(goal, z)) s.paceMin};
        expect(b, a, reason: z);
      }
      for (final s in work(goal, 'T')) {
        expect(s.paceMin, pz.range('T').$1);
      }
    });

    test('marathon: realistic target → race-pace work at goal pace; unrealistic → realistic pace', () {
      UserProfile p(int t) => runner(ev: 'm', weeks: 18, times: const {'hm': 6300}, target: t);
      // 1:45 HM ≈ 3:40 marathon now: 3:38 is realistic in 18 weeks, 3:05 is not.
      final ok = GoalModel.check(p(3 * 3600 + 38 * 60), start: start)!;
      expect(ok.status, TargetStatus.ok);
      // Goal pace = the more ambitious of target and realistic time (plan review IMPORTANT 2: race-pace
      // work is never slower than the realistic pace).
      final okPace = (ok.ambitionSec / 42.195).round();
      final steps = racePace(gen(p(ok.targetSec)));
      expect(steps, isNotEmpty);
      for (final s in steps) {
        expect(s.paceMin, okPace - 5);
        expect(s.paceMax, okPace + 5);
      }
      final bad = GoalModel.check(p(3 * 3600 + 5 * 60), start: start)!;
      expect(bad.status, TargetStatus.unrealistic);
      final realisticPace = (bad.realisticSec / 42.195).round();
      final badSteps = racePace(gen(p(bad.targetSec)));
      expect(badSteps, isNotEmpty);
      for (final s in badSteps) {
        // Never faster than what the athlete can realistically run by race day.
        expect(s.paceMin, greaterThanOrEqualTo(realisticPace - 5));
        expect((s.paceMin! + s.paceMax!) / 2, closeTo(realisticPace, 1));
      }
    });

    test('half marathon: peak long-run goal segment at target pace when realistic', () {
      final p = runner(ev: 'hm', weeks: 14, times: const {'10k': 2700}, target: 6000);
      final check = GoalModel.check(p, start: start)!;
      expect(check.status, TargetStatus.ok);
      final steps = racePace(gen(p));
      expect(steps, isNotEmpty);
      for (final s in steps) {
        // The more ambitious of target and realistic time (plan review IMPORTANT 2).
        expect((s.paceMin! + s.paceMax!) / 2, closeTo(check.ambitionSec / 21.0975, 1));
      }
    });
  });

  group('feasibility with a target time', () {
    test('unrealistic target is an issue with a suggested time; realistic is not', () {
      final f = PlanGenerator.feasibility(runner(target: 2700), start: start, l: l);
      expect(f.issues, ['targetUnrealistic']);
      expect(f.onlyTarget, isTrue);
      expect(f.target!.suggestedSec, greaterThan(2700));
      final ok = PlanGenerator.feasibility(runner(target: 2910), start: start, l: l);
      expect(ok.ok, isTrue);
      expect(ok.target!.status, TargetStatus.ok);
      expect(PlanGenerator.feasibility(runner(target: 2850), start: start, l: l).issues, ['targetAmbitious']);
    });

    test('other issues first, target last; no target check for goals that are not allowed', () {
      final beginnerM = runner(ev: 'm', weeks: 16, level: 'beginner', times: const {}, target: 4 * 3600);
      final f = PlanGenerator.feasibility(beginnerM, start: start, l: l);
      expect(f.reason, 'beginnerMarathon');
      expect(f.target, isNull);
    });
  });

  group('GoalForecast scenarios', () {
    // Plan started 4 weeks ago; 10 km race 12 weeks after the start (8 weeks left).
    final now = start.add(const Duration(days: 28, hours: 12));
    final easy = PaceZones(Vdot.fromRace(10000, 3000)).easySlow;

    (List<PlannedWorkout>, List<Session>) history(
      UserProfile p, {
      double speed = 1.0,
      int rpe = 6,
      bool Function(PlannedWorkout w)? skip,
      DateTime? until,
    }) {
      final plan = gen(p);
      final sessions = <Session>[];
      for (final w in plan.where((w) => w.date.isBefore(dayOnly(until ?? now)))) {
        if (skip?.call(w) ?? false) continue;
        final sec = w.steps.fold<int>(0, (x, s) => x + estimateStepSec(s, w.sport, easyPace: easy, css: 100));
        final quality = w.intensity == 'tempo' || w.intensity == 'intervals';
        sessions.add(
          Session(
            id: 's${w.id}',
            sport: w.sport,
            title: w.title,
            start: w.date.add(const Duration(hours: 7)),
            durationSec: (sec / (quality ? speed : 1.0)).round(),
            distanceM: (w.distanceKm ?? 0) * 1000,
            planId: w.id,
            rpe: quality ? rpe : 3,
          ),
        );
      }
      return (plan, sessions);
    }

    GoalForecast fc(UserProfile p, (List<PlannedWorkout>, List<Session>) h) => GoalForecast.of(p, plans: h.$1, sessions: h.$2, now: now)!;

    final p = runner(target: 2910); // 48:30, realistic at the start

    test('on track: everything done as planned', () {
      final f = fc(p, history(p));
      expect(f.early, isFalse);
      expect(f.status, ForecastStatus.onTrack);
      expect(f.adherence, greaterThan(0.9));
      expect(f.raceDaySec, lessThan(f.nowSec!));
      expect(f.fastSec, lessThan(f.raceDaySec!));
      expect(f.slowSec, greaterThan(f.raceDaySec!));
      expect(f.reasons, isEmpty);
      expect(f.weeksLeft, 7);
      expect(f.planned, isNotEmpty);
    });

    test('missed weeks: goal at risk, a slower target suggested', () {
      final f = fc(p, history(p, skip: (w) => w.date.isAfter(start.add(const Duration(days: 11)))));
      expect(f.status, ForecastStatus.atRisk);
      expect(f.alert, isTrue);
      expect(f.reasons, containsAll([ForecastReason.missedTraining, ForecastReason.trainingBreak]));
      expect(f.suggestedSec, greaterThan(2910));
    });

    test('slower than planned paces at a high effort: at risk', () {
      final f = fc(p, history(p, speed: 0.93, rpe: 8));
      expect(f.status, ForecastStatus.atRisk);
      expect(f.reasons, contains(ForecastReason.slowerThanPlanned));
      expect(f.confidence, ForecastConfidence.medium);
      expect(f.suggestedSec, greaterThan(2910));
    });

    test('faster than planned: ahead, a more ambitious target suggested', () {
      // Review C1: a quality run within ± 5 % of its step estimate – or that took the plan's displayed
      // (rounded) duration – is on plan, and a status change needs the evidence on two consecutive
      // Mondays: 8 % faster (6 % matched the rounded fartlek durations), read a week later.
      final later = now.add(const Duration(days: 7));
      final h = history(p, speed: 1.08, rpe: 6, until: later);
      final f = GoalForecast.of(p, plans: h.$1, sessions: h.$2, now: later)!;
      expect(f.status, ForecastStatus.ahead);
      expect(f.reasons, contains(ForecastReason.fasterThanPlanned));
      expect(f.suggestedSec, lessThan(2910));
      expect(f.trend, isNotEmpty);
    });

    test('a race effort is a measurement: high confidence', () {
      final h = history(p);
      final raceRun = Session(
        id: 'tt',
        sport: Sport.run,
        title: '10k',
        start: now.subtract(const Duration(days: 3)),
        durationSec: 2820,
        distanceM: 10000,
        rpe: 9,
      );
      final f = GoalForecast.of(p, plans: h.$1, sessions: [...h.$2, raceRun], now: now)!;
      expect(f.confidence, ForecastConfidence.high);
      expect(f.vdotNow, closeTo(Vdot.fromRace(10000, 2820), 0.1));
      expect(f.status, ForecastStatus.ahead);
    });

    test('no data yet: early, no alert', () {
      final f = GoalForecast.of(p, plans: gen(p), sessions: const [], now: start.add(const Duration(days: 1)))!;
      expect(f.early, isTrue);
      expect(f.alert, isFalse);
    });

    test('retarget: upcoming race-pace steps and the race follow the new target (the generator'
        's goal-pace rule)', () {
      final m = runner(ev: 'm', weeks: 18, times: const {'hm': 6300}, target: 3 * 3600 + 38 * 60);
      final plan = gen(m);
      final u = GoalForecast.retarget(m, plan, 3 * 3600 + 45 * 60, now: start, l: l);
      expect(u, isNotEmpty);
      // Review round 2, C3: within reach → race-pace work at the faster of target and realistic time
      // (3:45 is conservative for this runner: realistic ≈ 3:27), the race itself at the target.
      final t = GoalModel.check(m.copyWith(athlete: m.athlete.merge({'targetTimeSec': 3 * 3600 + 45 * 60})), start: start)!;
      expect(t.status, TargetStatus.ok);
      final pace = (t.ambitionSec / 42.195).round();
      final raceId = plan.firstWhere((w) => w.intensity == 'race').id;
      expect(u[raceId]!['description'], contains('3:45:00'));
      final targetPace = ((3 * 3600 + 45 * 60) / 42.195).round();
      final raceStep = (u[raceId]!['steps'] as List).map((x) => WorkoutStep.fromMap(x as Map)).firstWhere((s) => s.isWork);
      expect((raceStep.paceMin! + raceStep.paceMax!) / 2, closeTo(targetPace, 1));
      expect(u[raceId]!['description'], contains(clock(GoalModel.roundTarget(t.realisticSec))));
      for (final e in u.entries.where((e) => e.key != raceId && e.value.containsKey('steps'))) {
        for (final s in (e.value['steps'] as List).map((x) => WorkoutStep.fromMap(x as Map)).where((s) => s.isWork && s.zone == 'M')) {
          expect((s.paceMin! + s.paceMax!) / 2, closeTo(pace, 1));
        }
      }
    });
  });
}
