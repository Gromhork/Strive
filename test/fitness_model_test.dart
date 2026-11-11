import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/cardio_progression.dart';
import 'package:strive/services/fitness_state.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/target_suggestion.dart';
import 'package:strive/services/zones.dart';

import 'adaptation_sim_test.dart' as h;

/// The one fitness model (review round 2, docs/training-science.md §1.12a): forecast, target
/// suggestion, target check, race-day pacing and "Plan überprüfen" agree on every simulated day.
///
/// Set STRIVE_SIM_OUT to a folder to write `fm_<name>.txt` logs with the weekly numbers.

typedef Beh = (double, double, int)? Function(PlannedWorkout w, int week);

/// One Monday: what each place says.
class Day {
  Day(this.week, this.now, this.profile, this.plans, this.sessions, this.recal, this.forecast, this.fitness, this.suggestion, this.check);
  final int week;
  final DateTime now;
  final UserProfile profile;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;
  final Recalibration recal;
  final GoalForecast? forecast;
  final FitnessState fitness;
  final TargetSuggestion? suggestion;
  final TargetCheck? check;
}

class Sim {
  Sim(this.name);
  final String name;
  final days = <Day>[];
  final log = StringBuffer();
  late List<PlannedWorkout> plans;
  late UserProfile profile;
}

Sim simulate(
  String name,
  UserProfile Function() make,
  Beh beh,
  int weeks, {
  required AppLocalizations l,
  required List<WorkoutTemplate> templates,
  required String Function() id,
  Map<int, (UserProfile, List<PlannedWorkout>) Function(UserProfile, List<PlannedWorkout>, List<Session>, DateTime)> hooks = const {},
}) {
  final start = h.simStart;
  var p = make();
  final sim = Sim(name)..plans = PlanGenerator(l, p, templates, id).generate(start: start);
  final sessions = <Session>[];
  PlannedWorkout apply(PlannedWorkout x, Map<String, dynamic> m) => PlannedWorkout.fromMap(x.id, {...x.toMap(), ...m});
  for (var day = 0; day < weeks * 7; day++) {
    final d = DateTime(start.year, start.month, start.day + day);
    final week = day ~/ 7;
    if (d.weekday == DateTime.monday && day > 0) {
      final now = DateTime(d.year, d.month, d.day, 7);
      final hook = hooks[week];
      if (hook != null) {
        final r = hook(p, sim.plans, sessions, now);
        p = r.$1;
        sim.plans = r.$2;
      }
      final rc = Recalibrator(l, p, plans: sim.plans, sessions: sessions, now: now, templates: templates, newId: id).run();
      final f = GoalForecast.of(p, plans: sim.plans, sessions: sessions, now: now);
      final fit = FitnessState.of(p, plans: sim.plans, sessions: sessions, now: now);
      final a = p.athlete;
      final sug =
          a.eventDistance == null
              ? null
              : suggestTargetTime(p, a.eventDistance!, a.eventDate!, sessions: sessions, plans: sim.plans, now: now);
      final tc = a.targetTimeSec == null ? null : GoalModel.check(p, start: now, fitness: fit);
      sim.days.add(Day(week + 1, now, p, sim.plans, [...sessions], rc, f, fit, sug, tc));
      sim.log.writeln(
        'W${week + 1} recal=${rc.reasons.map((x) => x.name).join('+')} | fc=${f?.status.name} ${h.hms(f?.raceDaySec)} ${f?.reasons.map((x) => x.name).join(',')} '
        'vdot ${fit.current.toStringAsFixed(2)} (${fit.basis.name}) base ${fit.baseline.toStringAsFixed(2)} profile ${Vdot.of(a)?.toStringAsFixed(1)} '
        '| sug ${h.hms(sug?.sec)} | check ${tc?.status.name} ${h.hms(tc?.realisticSec)}',
      );
      final upd = rc.updates;
      sim.plans = [for (final x in sim.plans) upd.containsKey(x.id) ? apply(x, upd[x.id]!) : x, ...rc.additions];
      if (rc.raceTimes != null || rc.athlete.isNotEmpty) {
        p = p.copyWith(athlete: p.athlete.merge({if (rc.raceTimes != null) 'raceTimes': rc.raceTimes, ...rc.athlete}));
      }
    }
    for (final w in sim.plans.where((x) => dayOnly(x.date) == d && x.status == 'planned' && x.intensity != 'race').toList()) {
      final res = beh(w, week);
      if (res == null) {
        sim.plans = [
          for (final x in sim.plans) x.id == w.id ? apply(x, {'status': 'skipped'}) : x,
        ];
        continue;
      }
      final (ratio, speed, rpe) = res;
      final s = Session(
        id: 's${w.id}',
        sport: w.sport,
        title: w.title,
        start: DateTime(d.year, d.month, d.day, 18),
        durationSec: (w.durationMin * 60 * ratio / speed).round(),
        distanceM: (w.distanceKm ?? 0) * 1000 * ratio,
        rpe: w.sport == Sport.gym ? null : rpe,
        planId: w.id,
      );
      sessions.add(s);
      sim.plans = [
        for (final x in sim.plans) x.id == w.id ? apply(x, {'status': 'done', 'sessionId': s.id}) : x,
      ];
      final done = sim.plans.firstWhere((x) => x.id == w.id);
      for (final c in AutoAdjuster(
        p,
        plans: sim.plans,
        sessions: sessions,
        now: DateTime(d.year, d.month, d.day, 19),
      ).afterSession(s, done)) {
        sim.plans = [for (final x in sim.plans) x.id == c.before.id ? c.after : x];
      }
    }
  }
  sim.profile = p;
  return sim;
}

UserProfile tri703() => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.triathlon,
  birthYear: 1990,
  trainingDays: const [1, 2, 3, 4, 6, 7],
  experience: const {Sport.run, Sport.ride, Sport.swim},
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 75,
    dayMinutes: const {6: 240, 7: 240},
    raceTimes: const {'10k': 48 * 60},
    ftp: 230,
    hasPowerMeter: true,
    swim400Sec: 440,
    swim200Sec: 210,
    eventDistance: '70.3',
    eventDate: h.raceIn(16),
    targetTimeSec: 5 * 3600 + 30 * 60,
  ),
);

UserProfile duathlete() => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.duathlon,
  birthYear: 1990,
  trainingDays: const [1, 2, 4, 6, 7],
  experience: const {Sport.run, Sport.ride},
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 60,
    dayMinutes: const {6: 150, 7: 120},
    raceTimes: const {'10k': 46 * 60},
    ftp: 240,
    hasPowerMeter: true,
    eventDistance: 'du_standard',
    eventDate: h.raceIn(12),
  ),
);

/// A beginner without race times (level-default VDOT) aiming at a half marathon, 3 runs a week.
UserProfile beginnerHm3() => UserProfile(
  level: 'beginner',
  focus: TrainingFocus.run,
  birthYear: 1990,
  trainingDays: const [2, 4, 7],
  athlete: AthleteData(setupMode: 'advanced', sessionMinutes: 45, canRun30: true, eventDistance: 'hm', eventDate: h.raceIn(14)),
);

(double, double, int) perfect(PlannedWorkout w) => (1, 1, h.nominalRpe(w));

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'f${n++}';
  final templates = defaultTemplates(id, de: true);
  final runs = <String, Sim>{};
  final out = Platform.environment['STRIVE_SIM_OUT'];
  Sim sim(String name, UserProfile Function() make, Beh beh, int weeks, {Map<int, dynamic> hooks = const {}}) =>
      runs.putIfAbsent(name, () => simulate(name, make, beh, weeks, l: l, templates: templates, id: id, hooks: hooks.cast()));

  tearDownAll(() {
    if (out == null) return;
    final dir = Directory(out)..createSync(recursive: true);
    for (final r in runs.values) {
      File('${dir.path}${Platform.pathSeparator}fm_${r.name}.txt').writeAsStringSync(r.log.toString());
    }
  });

  /// A retarget hook (the goal editor's "apply"): profile + the plan's race-pace work follow.
  (UserProfile, List<PlannedWorkout>) Function(UserProfile, List<PlannedWorkout>, List<Session>, DateTime) retargetTo(int t) => (
    p,
    plans,
    sessions,
    now,
  ) {
    final u = GoalForecast.retarget(p, plans, t, now: now, sessions: sessions, l: l);
    return (
      p.copyWith(athlete: p.athlete.merge({'targetTimeSec': t})),
      [
        for (final x in plans) u.containsKey(x.id) ? PlannedWorkout.fromMap(x.id, {...x.toMap(), ...u[x.id]!}) : x,
      ],
    );
  };

  /// The invariant: on every Monday the suggestion, the check's realistic time and the forecast's
  /// race-day time are the same model value (suggestion and check rounded on the slow side).
  void invariant(Sim r) {
    for (final d in r.days) {
      final f = d.forecast;
      if (f == null || f.raceDaySec == null) continue;
      final what = '${r.name} W${d.week}';
      expect(d.suggestion!.sec, GoalModel.roundTarget(f.raceDaySec!), reason: '$what suggestion vs forecast ${h.hms(f.raceDaySec)}');
      if (d.check != null) {
        expect((d.check!.realisticSec - f.raceDaySec!).abs(), lessThanOrEqualTo(1), reason: '$what check ${h.hms(d.check!.realisticSec)}');
        expect((d.check!.currentSec - f.nowSec!).abs(), lessThanOrEqualTo(1), reason: '$what check now');
      }
    }
  }

  group('invariant: suggestion == check realistic == forecast race day', () {
    test('M_good: perfect marathoner – and the race-day time never drifts', () {
      final r = sim('M_good', h.marathoner, (w, k) => perfect(w), 17);
      invariant(r);
      final times = r.days.map((d) => d.forecast!.raceDaySec!).toList();
      // Review round 2 C4: suggestion / check W1 3:37 → W17 3:47 while the forecast said 3:36.
      expect(times.reduce(max) - times.reduce(min), lessThanOrEqualTo(5), reason: times.map(h.hms).join(' '));
      final sugs = r.days.map((d) => d.suggestion!.sec!).toSet();
      expect(sugs.length, 1, reason: '$sugs');
      // The race session of the generated plan shows the same race-day pacing: a 3:40 target is within
      // reach (realistic ≈ 3:36) → the race runs at the target.
      final race = r.plans.firstWhere((w) => w.intensity == 'race');
      expect(race.durationMin, 220);
      expect(r.days.every((d) => d.check!.status == TargetStatus.ok), isTrue);
    });

    test('tri703: perfect triathlete – the forecast no longer gets slower every week (C1)', () {
      final r = sim('tri703', tri703, (w, k) => perfect(w), 14);
      invariant(r);
      final times = r.days.map((d) => d.forecast!.raceDaySec!).toList();
      // Before: 5:29:13 (W2) → 5:37:40 (W14) while the run fitness rose 42.2 → 44.1.
      expect(times.reduce(max) - times.reduce(min), lessThanOrEqualTo(15), reason: times.map(h.hms).join(' '));
      expect(r.days.map((d) => d.forecast!.status), everyElement(ForecastStatus.onTrack));
      // The time today falls while the fitness rises.
      expect(r.days.last.forecast!.nowSec!, lessThan(r.days.first.forecast!.nowSec!));
    });

    test('duathlon: perfect athlete, no drift', () {
      final r = sim('du', duathlete, (w, k) => perfect(w), 11);
      invariant(r);
      final times = r.days.map((d) => d.forecast!.raceDaySec!).toList();
      expect(times.reduce(max) - times.reduce(min), lessThanOrEqualTo(15), reason: times.map(h.hms).join(' '));
    });

    test('M_slower: the forecast follows the recalibrated VDOT – no 20-minute jumps back to the plan line (C2)', () {
      final r = sim('M_slower', h.marathoner, (w, k) => (1, h.isQuality(w) ? 0.93 : 0.97, w.intensity == 'easy' ? 5 : 8), 12);
      invariant(r);
      for (var i = 1; i < r.days.length; i++) {
        final a = r.days[i - 1].forecast!.raceDaySec!, b = r.days[i].forecast!.raceDaySec!;
        // Before: 3:56:53 (W10) → 3:36:09 (W11).
        expect((b - a).abs(), lessThan(8 * 60), reason: 'W${r.days[i].week}: ${h.hms(a)} → ${h.hms(b)}');
      }
      // Forecast and paces on the same fitness: the forecast's VDOT within 1.5 of the profile's (before: ~6 apart).
      for (final d in r.days.where((d) => d.fitness.basis == FitnessBasis.recalibrated)) {
        expect((d.fitness.current - Vdot.of(d.profile.athlete)!).abs(), lessThan(1.5), reason: 'W${d.week}');
      }
      expect(r.days.any((d) => d.fitness.basis == FitnessBasis.recalibrated), isTrue);
    });

    test('M_faster: forecast never below the recalibrated VDOT; invariant holds', () {
      final r = sim('M_faster', h.marathoner, (w, k) => (1, h.isQuality(w) ? 1.05 : 1.0, h.isQuality(w) ? 4 : 3), 12);
      invariant(r);
      for (final d in r.days) {
        final e = d.profile.athlete.vdotEstimate;
        if (e != null && FitnessState.estimateActive(d.profile.athlete)) {
          expect(d.fitness.current, greaterThanOrEqualTo(e - 0.01), reason: 'W${d.week}');
        }
      }
    });

    test('target changed mid-plan (W6): race pacing follows the generator rule, suggestion / check / forecast agree (C3)', () {
      final fast = sim('M_target325', h.marathoner, (w, k) => perfect(w), 12, hooks: {5: retargetTo(3 * 3600 + 25 * 60)});
      final slow = sim('M_target400', h.marathoner, (w, k) => perfect(w), 12, hooks: {5: retargetTo(4 * 3600)});
      invariant(fast);
      invariant(slow);
      for (final (r, target) in [(fast, 3 * 3600 + 25 * 60), (slow, 4 * 3600)]) {
        final d = r.days.firstWhere((d) => d.week == 6);
        final tc = d.check!;
        final race = d.plans.firstWhere((w) => w.intensity == 'race');
        final step = race.steps.firstWhere((s) => s.isWork);
        final racePace = (step.paceMin! + step.paceMax!) / 2;
        final mp =
            d.plans
                .where((w) => w.phase == 'peak' && w.status == 'planned' && w.intensity != 'race')
                .expand((w) => w.steps)
                .where((s) => s.isWork && s.zone == 'M' && s.paceMin != null)
                .map((s) => (s.paceMin! + s.paceMax!) / 2)
                .toSet();
        if (tc.status == TargetStatus.ok) {
          // 4:00 is conservative: race at the target, race-pace work at the faster realistic pace, and the
          // race says what is realistic (IMPORTANT 5).
          expect(racePace, closeTo(target / 42.195, 1));
          for (final m in mp) {
            expect(m, closeTo(tc.ambitionSec / 42.195, 1));
          }
          expect(race.description, contains(clock(GoalModel.roundTarget(tc.realisticSec))));
          expect(race.durationMin, (target / 60).round());
        } else {
          // 3:25 is out of reach: race and race-pace work at the realistic time, "Ziel 3:25 – starte mit …".
          expect(racePace, closeTo(tc.realisticSec / 42.195, 1));
          for (final m in mp) {
            expect(m, closeTo(tc.realisticSec / 42.195, 1));
          }
          expect(race.description, contains(l.wRaceGoalStart(clock(target), '${clock((tc.realisticSec / 42.195).round())}/km')));
        }
      }
      expect(fast.days.firstWhere((d) => d.week == 6).check!.status, isNot(TargetStatus.ok));
      expect(slow.days.firstWhere((d) => d.week == 6).check!.conservative, isTrue);
      // "Plan überprüfen" says goal at risk exactly when the forecast does (IMPORTANT 2).
      for (final d in [...fast.days, ...slow.days]) {
        expect(d.recal.reasons.contains(RecalReason.goalAtRisk), d.forecast!.atRisk, reason: 'W${d.week}');
      }
    });

    test('soft target: the faster target is suggested for two weeks, then the forecast is quiet', () {
      final r = runs['M_target400'] ?? sim('M_target400', h.marathoner, (w, k) => perfect(w), 12, hooks: {5: retargetTo(4 * 3600)});
      final ahead = r.days.where((d) => d.forecast!.status == ForecastStatus.ahead).toList();
      expect(ahead.length, greaterThanOrEqualTo(3));
      // Before: "set 3:37" every week for 13 weeks.
      expect(ahead.where((d) => d.forecast!.suggestedSec != null).length, lessThanOrEqualTo(2));
    });
  });

  group('baseline and evidence', () {
    test('beginner without race times: the baseline is never read from the race session (C5)', () {
      final p = beginnerHm3();
      final plan = PlanGenerator(l, p, templates, id).generate(start: h.simStart);
      final fit = FitnessState.of(p, plans: plan, sessions: const [], now: DateTime(h.simStart.year, h.simStart.month, h.simStart.day, 8));
      final race = plan.firstWhere((w) => w.intensity == 'race');
      final raceStepVdot = FitnessState.vdotOfSteps(race.steps);
      // Before: the race's T-zone step (≈ VDOT of the level-default race time) became the baseline,
      // forecast 1:51:06 vs suggestion 1:58:00.
      if (raceStepVdot != null) expect((fit.baseline - raceStepVdot).abs() > 0.01 || fit.baseline == Vdot.defaultFor('beginner'), isTrue);
      final f = GoalForecast.of(p, plans: plan, sessions: const [], now: DateTime(h.simStart.year, h.simStart.month, h.simStart.day, 8));
      final s = suggestTargetTime(p, 'hm', p.athlete.eventDate!, plans: plan, now: h.simStart);
      if (f?.raceDaySec != null) expect(s.sec, GoalModel.roundTarget(f!.raceDaySec!));
    });

    test('M_improveThenSick: no VDOT rise in the week back from a break (IMPORTANT 1)', () {
      final r = sim('M_improveThenSick', h.marathoner, (w, k) {
        if (k == 6 || k == 7) return null;
        if (k < 6) return (1, h.isQuality(w) ? 1.05 : 1.0, h.isQuality(w) ? 4 : 3);
        return perfect(w);
      }, 12);
      invariant(r);
      for (final d in r.days) {
        final back = d.recal.reasons.contains(RecalReason.returnAfterBreak) || d.fitness.breakPenalty > 0;
        if (back) {
          expect(d.recal.reasons, isNot(contains(RecalReason.runTrendFaster)), reason: 'W${d.week}');
          expect(d.recal.reasons, isNot(contains(RecalReason.fasterRuns)), reason: 'W${d.week}');
        }
        // One verdict: goal at risk ⇔ forecast at risk (before: W9–W10 "goal at risk" from a fresh re-plan).
        expect(d.recal.reasons.contains(RecalReason.goalAtRisk), d.forecast!.atRisk, reason: 'W${d.week}');
      }
      expect(r.days.any((d) => d.fitness.breakPenalty > 0), isTrue);
    });

    test('chronic overreaching earns no forecast fitness (IMPORTANT 10)', () {
      final good = sim('M_good', h.marathoner, (w, k) => perfect(w), 17);
      final hard = sim('M_highRpe', h.marathoner, (w, k) => (1, 1, (h.nominalRpe(w) + 3).clamp(1, 10)), 8);
      final g = good.days.firstWhere((d) => d.week == 8), b = hard.days.firstWhere((d) => d.week == 8);
      expect(b.fitness.chronicFatigue, isTrue);
      expect(b.fitness.creditedWeeks, lessThan(g.fitness.creditedWeeks - 2));
      expect(b.forecast!.raceDaySec!, greaterThan(g.forecast!.raceDaySec!));
      expect(b.forecast!.reasons, contains(ForecastReason.fatigue));
    });

    test('chronic skipping: session and key-session counts are reasons in forecast and review (IMPORTANT 4)', () {
      // Two of five runs a week skipped (Mon + Sat easy) – the minutes look fine (long runs done).
      final r = sim('M_partial', h.marathoner, (w, k) {
        if (w.intensity == 'easy' && (w.date.weekday == 1 || w.date.weekday == 6)) return null;
        return perfect(w);
      }, 7);
      final d = r.days.last;
      expect(d.forecast!.reasons, contains(ForecastReason.sessionsSkipped));
      expect(d.recal.reasons, contains(RecalReason.sessionsSkipped));
      expect(d.forecast!.sessionsDone / d.forecast!.sessionsDue, lessThan(0.7));
      // Key sessions skipped.
      final k = sim('M_skipKeys', h.marathoner, (w, k) => h.isQuality(w) && k >= 2 ? null : perfect(w), 7);
      expect(k.days.last.forecast!.reasons, contains(ForecastReason.keySessionsMissed));
      expect(k.days.last.recal.reasons, contains(RecalReason.keySessionsMissed));
      expect(k.days.last.forecast!.status.index, greaterThanOrEqualTo(ForecastStatus.slightlyBehind.index));
    });
  });

  test('conservative target: the race card shows the realistic pacing too (IMPORTANT 5)', () {
    final m = h.marathoner();
    final p = m.copyWith(athlete: m.athlete.merge({'targetTimeSec': 3 * 3600 + 55 * 60}));
    final tc = GoalModel.check(p, start: h.simStart)!;
    expect(tc.conservative, isTrue);
    final race = PlanGenerator(l, p, templates, id).generate(start: h.simStart).firstWhere((w) => w.intensity == 'race');
    expect(race.durationMin, 235);
    expect(race.description, contains(l.wRaceRealistic(clock(tc.suggestedSec), '${clock((tc.realisticSec / 42.195).round())}/km')));
  });

  test('the profile-only model: a plan stored on the profile counts as trained (C4)', () {
    final m = h.marathoner();
    final p = m.copyWith(athlete: m.athlete.merge({'planStart': h.simStart, 'planLength': 18}));
    final at = <int>[];
    for (final w in [0, 5, 11, 16]) {
      final now = DateTime(h.simStart.year, h.simStart.month, h.simStart.day + 7 * w, 9);
      at.add(GoalModel.check(p, start: now)!.realisticSec);
      expect(suggestTargetTime(p, 'm', p.athlete.eventDate!, now: now).sec, GoalModel.roundTarget(at.last));
    }
    // Before: 3:36:13 (W1) → 3:47 (W17) – the check restarted from the plan-start VDOT every week.
    expect(at.reduce(max) - at.reduce(min), lessThanOrEqualTo(2), reason: at.map(h.hms).join(' '));
  });

  test('QA 2026-11: the wizard\'s suggested target never triggers our own warning – an older plan in the history aside', () {
    // HM on 6 Feb 2027, 5 km PB 22:12, wizard on Wed 11 Nov 2026: suggestion 1:39:00; after "Übernehmen" the
    // check said "very ambitious – realistic 1:41:59": workouts of an older plan (June) were taken as this
    // plan's start, its weeks counted as trained and the race-day gain shrank to ~0.
    final now = DateTime(2026, 11, 11, 10);
    final race = DateTime(2027, 2, 6);
    final base = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.run,
      birthYear: 1990,
      experience: const {Sport.run},
      trainingDays: const [2, 4, 6],
      goals: const ['race'],
      athlete: AthleteData(raceTimes: const {'5k': 22 * 60 + 12}, eventDistance: 'hm', eventDate: race),
    );
    final s = suggestTargetTime(base, 'hm', race, now: now);
    expect(s.sec, 99 * 60);
    final start = dayOnly(now);
    for (final stored in [true, false]) {
      final p = base.copyWith(
        athlete: base.athlete.merge({'targetTimeSec': s.sec, if (stored) 'planStart': start, if (stored) 'planLength': 13}),
      );
      final old = PlanGenerator(
        l,
        p.copyWith(athlete: p.athlete.merge({'eventDate': null, 'planStart': null})),
        templates,
        id,
      ).generate(start: DateTime(2026, 6, 1), weeks: 12);
      final plans = [...old, ...PlanGenerator(l, p, templates, id).generate(start: start)];
      final fit = FitnessState.of(p, plans: plans, sessions: const [], now: now);
      expect(daysBetween(start, fit.planStart!), inInclusiveRange(0, 6), reason: 'stored $stored: ${fit.planStart}');
      final tc = GoalModel.check(p, start: start, fitness: fit)!;
      expect(tc.status, TargetStatus.ok, reason: 'stored $stored: realistic ${h.hms(tc.realisticSec)}');
      expect(PlanGenerator.feasibility(p, start: start, l: l, fitness: fit).issues.where((i) => i.startsWith('target')), isEmpty);
      // Goal editor and forecast: the same race-day time.
      expect(suggestTargetTime(p, 'hm', race, plans: plans, now: now).sec, s.sec);
      final fc = GoalForecast.of(p, plans: plans, sessions: const [], now: now)!;
      expect(GoalModel.roundTarget(fc.raceDaySec!), s.sec);
    }
  });
}
