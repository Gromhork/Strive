import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/zones.dart';

/// Coach review 2 (2026-11): long-run share continuity, continuous-tempo cap, base pre-plan
/// long runs, no re-use of stale sessions in the VDOT trend, forecast plan line anchored at
/// the plan start.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9); // Monday
  final templates = defaultTemplates(id, de: false);
  DateTime race(int weeks) => start.add(Duration(days: 7 * (weeks - 1) + 6));

  UserProfile runner({
    String ev = 'hm',
    int weeks = 14,
    Map<String, int> times = const {'hm': 6000},
    double km = 45,
    double longest = 16,
    List<int> days = const [1, 2, 3, 5, 6, 7],
    int minutes = 120,
    Map<int, int> dayMin = const {},
    int? target,
  }) => UserProfile(
    level: 'intermediate',
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: days,
    athlete: AthleteData(
      raceTimes: times,
      runWeeklyKm: km,
      longestRunKm: longest,
      sessionMinutes: minutes,
      dayMinutes: dayMin,
      eventDistance: ev,
      eventDate: race(weeks),
      targetTimeSec: target,
    ),
  );

  List<PlannedWorkout> gen(UserProfile p) => PlanGenerator(l, p, templates, id).generate(start: start);
  int week(PlannedWorkout w) => w.date.difference(start).inDays ~/ 7;

  test('HM / marathon long run does not drop when the week grows past 50 / 70 km', () {
    for (final p in [
      runner(),
      runner(ev: 'm', weeks: 18, times: const {'hm': 5520}, km: 60, longest: 24, minutes: 90, dayMin: const {7: 180}),
    ]) {
      final plan = gen(p);
      // Intended shorter weeks of the long-run variation (coach review 3) are not a drop.
      final longs = {
        for (final w in plan.where(
          (w) =>
              w.sport == Sport.run &&
              w.intensity == 'long' &&
              (w.phase == 'base' || w.phase == 'build') &&
              !w.description.contains(l.wLongRunShortDesc),
        ))
          week(w): w.distanceKm!,
      };
      final ks = longs.keys.toList()..sort();
      for (var i = 1; i < ks.length; i++) {
        expect(
          longs[ks[i]]!,
          greaterThanOrEqualTo(longs[ks[i - 1]]! - 0.5),
          reason: '${p.athlete.eventDistance} week ${ks[i] + 1}: $longs',
        );
      }
    }
  });

  test('continuous tempo: ≤ 10 % of the weekly km, at least 20 min', () {
    final p = runner(ev: 'hm', weeks: 16, times: const {'10k': 3600}, km: 25, longest: 10, days: const [2, 4, 6, 7], minutes: 75);
    final plan = gen(p);
    final weekKm = <int, double>{};
    for (final w in plan.where((w) => w.sport == Sport.run && w.intensity != 'race')) {
      weekKm[week(w)] = (weekKm[week(w)] ?? 0) + (w.distanceKm ?? 0);
    }
    final pz = PaceZones(Vdot.of(p.athlete)!);
    var checked = 0;
    for (final w in plan.where((w) => w.sport == Sport.run && w.steps.where((s) => s.isWork).length == 1)) {
      final t = w.steps.firstWhere((s) => s.isWork);
      if (t.zone != 'T' || t.durationSec == null) continue;
      checked++;
      final km = t.durationSec! / pz.threshold;
      expect(t.durationSec!, lessThanOrEqualTo(max(20 * 60, (weekKm[week(w)]! * 0.1 * pz.threshold / 60).round() * 60 + 60)));
      expect(km, lessThan(max(weekKm[week(w)]! * 0.12, 20 * 60 / pz.threshold + 0.1)), reason: '${w.date}');
    }
    expect(checked, greaterThan(2));
  });

  test('event 40 weeks away: no race-specific long runs in the base pre-plan', () {
    final p = runner(
      ev: 'm',
      weeks: 40,
      times: const {'hm': 6300},
      km: 35,
      longest: 15,
      days: const [2, 3, 5, 7],
      minutes: 90,
      dayMin: const {7: 180},
    );
    final plan = gen(p);
    final longs = plan.where((w) => w.sport == Sport.run && w.intensity == 'long');
    for (final w in longs.where((w) => week(w) < 10)) {
      expect(w.distanceKm!, lessThanOrEqualTo(24.5), reason: 'pre-plan week ${week(w) + 1}');
    }
    expect(longs.fold<double>(0, (x, w) => max(x, w.distanceKm!)), greaterThanOrEqualTo(28));
    expect(PlanGenerator.feasibility(p, start: start, l: l).issues, isEmpty);
  });

  // ── Adaptation: a runner whose true VDOT is 42.5 on a plan built for 40.
  double? planVdot(PlannedWorkout w) {
    for (final s in w.steps) {
      if (!s.isWork || s.paceMin == null) continue;
      final f = s.zone == 'T' ? 0.88 : (s.zone == 'I' ? 0.975 : null);
      if (f != null) return Vdot.vo2(60000 / ((s.paceMin! + s.paceMax!) / 2)) / f;
    }
    return null;
  }

  Session session(PlannedWorkout w, DateTime day, double vTrue) {
    final pv = planVdot(w);
    final r = pv == null ? 1.0 : pow(vTrue / pv, 1 / 1.2).toDouble();
    final sec = w.steps.fold<int>(0, (x, s) => x + estimateStepSec(s, w.sport, easyPace: 360, css: 100));
    final tempo = w.intensity == 'tempo';
    return Session(
      id: 's${w.id}',
      sport: w.sport,
      title: w.title,
      start: day.add(const Duration(hours: 7)),
      durationSec: (sec / r).round(),
      distanceM: (w.distanceKm ?? 0) * 1000,
      planId: w.id,
      rpe: pv == null ? 3 : (r >= 1.03 ? (tempo ? 4 : 5) : (r <= 0.97 ? (tempo ? 8 : 9) : (tempo ? 6 : 7))),
    );
  }

  test('VDOT trend: stale sessions do not push the VDOT past the true fitness (no overshoot / oscillation)', () {
    var p = runner(
      ev: '10k',
      weeks: 12,
      times: const {'10k': 3000},
      km: 30,
      longest: 12,
      days: const [2, 4, 6, 7],
      minutes: 75,
      target: 2910,
    );
    var plans = gen(p);
    final sessions = <Session>[];
    final vdots = <double>[];
    for (var day = start; day.isBefore(race(12)); day = day.add(const Duration(days: 1))) {
      if (day.weekday == 1 && day.isAfter(start)) {
        final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: day.add(const Duration(hours: 6))).run();
        final ups = {for (final c in r.changes.where((c) => c.kind != RecalKind.added)) c.before.id: c.after};
        plans = [for (final w in plans) ups[w.id] ?? w];
        // The VDOT now comes as [Recalibration.athlete] (vdotEstimate), not as a race time (C5).
        if (r.raceTimes != null || r.athlete.isNotEmpty) {
          p = p.copyWith(athlete: p.athlete.merge({if (r.raceTimes != null) 'raceTimes': r.raceTimes, ...r.athlete}));
        }
        vdots.add(Vdot.of(p.athlete)!);
      }
      for (final w in plans.where((w) => sameDay(w.date, day) && w.status == 'planned' && w.intensity != 'race').toList()) {
        final s = session(w, day, 42.5);
        sessions.add(s);
        plans = [
          for (final x in plans) x.id == w.id ? PlannedWorkout.fromMap(x.id, {...x.toMap(), 'status': 'done', 'sessionId': s.id}) : x,
        ];
      }
    }
    expect(vdots.last, greaterThanOrEqualTo(41), reason: '$vdots');
    expect(vdots.reduce(max), lessThanOrEqualTo(43.5), reason: '$vdots');
    for (var i = 1; i < vdots.length; i++) {
      expect(vdots[i], greaterThanOrEqualTo(vdots[i - 1]), reason: 'no step back after a step up: $vdots');
    }
  });

  test('forecast: a VDOT update of the profile does not move the plan line', () {
    final p = runner(
      ev: '10k',
      weeks: 12,
      times: const {'10k': 3000},
      km: 30,
      longest: 12,
      days: const [2, 4, 6, 7],
      minutes: 75,
      target: 2910,
    );
    final now = start.add(const Duration(days: 42, hours: 12));
    final plan = gen(p);
    final sessions = [
      for (final w in plan.where((w) => w.date.isBefore(dayOnly(now)) && w.intensity != 'race'))
        Session(
          id: 's${w.id}',
          sport: w.sport,
          title: w.title,
          start: w.date.add(const Duration(hours: 7)),
          durationSec: w.durationMin * 60,
          distanceM: (w.distanceKm ?? 0) * 1000,
          planId: w.id,
          rpe: 4,
        ),
    ];
    final before = GoalForecast.of(p, plans: plan, sessions: sessions, now: now)!;
    // The recalibration raised the VDOT by 2 and rewrote the race time.
    final up = p.copyWith(
      athlete: p.athlete.merge({
        'raceTimes': {'10k': Vdot.raceTime(42, 10000)},
      }),
    );
    final after = GoalForecast.of(up, plans: plan, sessions: sessions, now: now)!;
    expect(after.expectedVdotNow!, closeTo(before.expectedVdotNow!, 0.2));
  });
}
