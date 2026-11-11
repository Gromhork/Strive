// ignore_for_file: avoid_print
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/cardio_progression.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/progression_check.dart';
import 'package:strive/services/zones.dart';

import 'adaptation_sim_test.dart' as h;

/// Fitness-model recalibration fixes (review round 2, docs/training-science.md §11.6): progression
/// against the plan's original ladder, R1 floor, reached volume for a re-created plan, taper week,
/// FTP / CSS step spacing and cap, spaced "a little more volume", partial adherence.
///
/// The day-by-day simulator below is the review's (round 2): a scripted athlete trains a generated
/// plan, "Plan überprüfen" runs every Monday (the whole proposal is accepted), the AutoAdjuster after
/// every session. "Before" numbers in the test names are from the review's runs of the old code.

typedef Beh = (double, double, int)? Function(PlannedWorkout w, int week);

class Sim {
  Sim(this.name);
  final String name;
  final weeks = <(int, DateTime, Recalibration, UserProfile)>[];
  late List<PlannedWorkout> original;
  late List<PlannedWorkout> plans;
  final sessions = <Session>[];
  late UserProfile profile;
}

double _avgPowerTarget(PlannedWorkout w) {
  var t = 0.0, p = 0.0;
  for (final s in w.steps) {
    final d = (s.durationSec ?? 0).toDouble();
    if (d <= 0 || s.powerMin == null) continue;
    t += d;
    p += d * (s.powerMin! + s.powerMax!) / 2;
  }
  return t > 0 ? p / t : 0;
}

Sim simulate(
  String name,
  UserProfile Function() make,
  Beh beh,
  int weeksToSim, {
  Map<int, void Function(Sim, UserProfile, DateTime)> hooks = const {},
  required AppLocalizations l,
  required List<WorkoutTemplate> templates,
  required String Function() id,
}) {
  final s0 = h.simStart;
  var p = make();
  final r = Sim(name);
  r.original = PlanGenerator(l, p, templates, id).generate(start: s0);
  r.plans = [...r.original];
  PlannedWorkout apply(PlannedWorkout x, Map<String, dynamic> m) => PlannedWorkout.fromMap(x.id, {...x.toMap(), ...m});
  for (var day = 0; day < weeksToSim * 7; day++) {
    final d = addDays(s0, day);
    final week = day ~/ 7;
    if (d.weekday == DateTime.monday && hooks[week] != null) hooks[week]!(r, p, d);
    if (d.weekday == DateTime.monday && day > 0) {
      final now = DateTime(d.year, d.month, d.day, 7);
      final rc = Recalibrator(l, p, plans: r.plans, sessions: r.sessions, now: now, templates: templates, newId: id).run();
      final upd = rc.updates;
      r.plans = [for (final x in r.plans) upd.containsKey(x.id) ? apply(x, upd[x.id]!) : x, ...rc.additions];
      if (rc.raceTimes != null || rc.athlete.isNotEmpty) {
        p = p.copyWith(athlete: p.athlete.merge({if (rc.raceTimes != null) 'raceTimes': rc.raceTimes, ...rc.athlete}));
      }
      r.weeks.add((week + 1, d, rc, p));
    }
    for (final w in r.plans.where((x) => dayOnly(x.date) == d && x.status == 'planned' && x.intensity != 'race').toList()) {
      final res = beh(w, week);
      if (res == null) {
        r.plans = [
          for (final x in r.plans) x.id == w.id ? apply(x, {'status': 'skipped'}) : x,
        ];
        continue;
      }
      final (ratio, speed, rpe) = res;
      final pw = w.sport == Sport.ride ? _avgPowerTarget(w) : 0.0;
      final s = Session(
        id: 's${w.id}',
        sport: w.sport,
        title: w.title,
        start: DateTime(d.year, d.month, d.day, 18),
        durationSec: w.sport == Sport.ride ? (w.durationMin * 60 * ratio).round() : (w.durationMin * 60 * ratio / speed).round(),
        distanceM: (w.distanceKm ?? 0) * 1000 * ratio * (w.sport == Sport.ride ? speed : 1),
        rpe: w.sport == Sport.gym ? null : rpe,
        planId: w.id,
        avgPower: pw > 0 ? (pw * speed).round() : null,
      );
      r.sessions.add(s);
      r.plans = [
        for (final x in r.plans) x.id == w.id ? apply(x, {'status': 'done', 'sessionId': s.id}) : x,
      ];
      final done = r.plans.firstWhere((x) => x.id == w.id);
      final ch = AutoAdjuster(p, plans: r.plans, sessions: r.sessions, now: DateTime(d.year, d.month, d.day, 19)).afterSession(s, done);
      for (final c in ch) {
        r.plans = [for (final x in r.plans) x.id == c.before.id ? c.after : x];
      }
    }
  }
  r.profile = p;
  return r;
}

UserProfile ride160() => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.ride,
  birthYear: 1990,
  trainingDays: const [2, 4, 6, 7],
  experience: const {Sport.ride},
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 75,
    dayMinutes: const {6: 300},
    ftp: 220,
    hasPowerMeter: true,
    eventDistance: 'ride160',
    eventDate: h.raceIn(14),
  ),
);

UserProfile swimmer() => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.swim,
  birthYear: 1990,
  trainingDays: const [1, 3, 5, 6],
  experience: const {Sport.swim},
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 75,
    swim400Sec: 400,
    swim200Sec: 190,
    eventDistance: 'swim3800',
    eventDate: h.raceIn(14),
  ),
);

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'f${n++}';
  final templates = defaultTemplates(id, de: true);
  (double, double, int) perfect(PlannedWorkout w) => (1, 1, h.nominalRpe(w));
  Sim sim(
    String name,
    UserProfile Function() make,
    Beh beh,
    int weeks, {
    Map<int, void Function(Sim, UserProfile, DateTime)> hooks = const {},
  }) => simulate(name, make, beh, weeks, hooks: hooks, l: l, templates: templates, id: id);

  // ───────────────────────── 1. Progression against the original ladder ─────────────────────────
  group('progression check (IMPORTANT 3)', () {
    final now = DateTime(2026, 11, 10, 9); // Tuesday
    final day0 = DateTime(2026, 10, 20);
    UserProfile beginner(int weeksLeft) => UserProfile(
      level: 'beginner',
      focus: TrainingFocus.run,
      experience: const {Sport.run},
      trainingDays: const [2, 4, 6],
      athlete: AthleteData(eventDistance: '10k', eventDate: addDays(dayOnly(now), 7 * weeksLeft)),
    );
    const walk = WorkoutStep(kind: 'warmup', durationSec: 300, zone: 'walk');
    const run = WorkoutStep(kind: 'work', durationSec: 300, zone: 'E');
    AutoAdjustment rec(String reason, int min, {double? km}) =>
        AutoAdjustment(sessionId: '', reason: reason, at: day0, durationMin: min, distanceKm: km);
    PlannedWorkout long(DateTime d, {required double km, required int min, AutoAdjustment? auto}) => PlannedWorkout(
      id: 'l${n++}',
      date: d,
      sport: Sport.run,
      title: 'Long run',
      durationMin: min,
      distanceKm: km,
      intensity: 'long',
      phase: 'base',
      steps: [WorkoutStep(kind: 'steady', distanceM: km * 1000, zone: 'E')],
      auto: auto,
    );
    PlannedWorkout runWalk(DateTime d, {AutoAdjustment? auto}) => PlannedWorkout(
      id: 'r${n++}',
      date: d,
      sport: Sport.run,
      title: 'Run/walk 2 × 5 min',
      durationMin: 30,
      phase: 'base',
      steps: const [walk, run, WorkoutStep(kind: 'recovery', durationSec: 120, zone: 'walk'), run, walk],
      auto: auto,
    );
    Session done(PlannedWorkout x) => Session(
      id: 's${x.id}',
      sport: Sport.run,
      title: x.title,
      start: x.date.add(const Duration(hours: 18)), // time span
      durationSec: x.durationMin * 60,
      distanceM: (x.distanceKm ?? 0) * 1000,
      rpe: 4,
      planId: x.id,
    );

    test('long sessions reduced 10 → 7 km and done as reduced: share 1.00 → 0.70, behind', () {
      // The plan's ladder: 10, 11, 12 km; each was cut to 70 % (AutoAdjuster / recalibration) and
      // done exactly as cut. Before: compared with the cut session → 100 %, "on track".
      final plans = [
        for (var w = 0; w < 3; w++)
          long(
            addDays(day0, 7 * w + 4),
            km: 0.7 * (10 + w),
            min: (0.7 * (60 + 6 * w)).round(),
            auto: rec('longHard', 60 + 6 * w, km: 10.0 + w),
          ),
      ];
      final c = progressionCheck(beginner(16), plans: plans, sessions: plans.map(done).toList(), now: now)!;
      print('progression share vs original: ${c.longAchievedShare?.toStringAsFixed(2)} issues ${c.issues}');
      expect(c.longAchievedShare, closeTo(0.70, 0.02));
      expect(c.behind, isTrue);
      expect(c.issues, contains(ProgressionIssue.longSessionsShort));
      expect(c.longBehind, isTrue);
    });

    test('a recovery week the recalibration proposed is no lag', () {
      final plans = [
        for (var w = 0; w < 3; w++)
          long(addDays(day0, 7 * w + 4), km: 0.7 * 10, min: 42, auto: w == 1 ? rec('recalRecovery', 60, km: 10) : null),
      ];
      final c = progressionCheck(beginner(16), plans: plans, sessions: plans.map(done).toList(), now: now)!;
      expect(c.longAchievedShare, closeTo(1, 1e-9));
      expect(c.behind, isFalse);
    });

    test('run/walk stage held 3 weeks: stageHeld; ≤ 12 weeks left → at risk (before: not flagged)', () {
      final plans = [
        for (var w = 0; w < 3; w++) ...[
          runWalk(addDays(day0, 7 * w), auto: rec('recalStage', 30)),
          runWalk(addDays(day0, 7 * w + 2)),
          long(addDays(day0, 7 * w + 4), km: 5, min: 40),
        ],
      ];
      final sessions = plans.map(done).toList();
      final near = progressionCheck(beginner(10), plans: plans, sessions: sessions, now: now)!;
      print('stage held: weeks ${near.heldWeeks} left ${near.weeksLeft} atRisk ${near.atRisk} issues ${near.issues}');
      expect(near.heldWeeks, 3);
      expect(near.issues, contains(ProgressionIssue.stageHeld));
      expect(near.behind, isTrue);
      expect(near.atRisk, isTrue);
      final far = progressionCheck(beginner(16), plans: plans, sessions: sessions, now: now)!;
      expect(far.issues, contains(ProgressionIssue.stageHeld));
      expect(far.atRisk, isFalse);
      // Two weeks held: no issue yet.
      final two =
          progressionCheck(
            beginner(10),
            plans: plans.where((x) => x.date.isAfter(addDays(day0, 3))).toList(),
            sessions: sessions,
            now: now,
          )!;
      expect(two.heldWeeks, 2);
      expect(two.issues, isNot(contains(ProgressionIssue.stageHeld)));
    });
  });

  // ───────────────────────── 1b. R1 long-run cap respects the run floor ─────────────────────────
  test('R1 cap never takes a long run below the floor: 7.0 km / 60 min → 2.2 km before, ≥ 2.3 km (20 min) now', () {
    final now = DateTime(2026, 11, 16, 7); // Monday
    final p = UserProfile(level: 'beginner', focus: TrainingFocus.run, trainingDays: const [1, 3, 5], athlete: const AthleteData());
    final plans = <PlannedWorkout>[];
    final sessions = <Session>[];
    // Two weeks of short easy runs (2 km / 15 min), all done.
    for (var i = 0; i < 6; i++) {
      final d = addDays(DateTime(2026, 11, 2), [0, 2, 4][i % 3] + 7 * (i ~/ 3));
      final w = PlannedWorkout(
        id: 'e$i',
        date: d,
        sport: Sport.run,
        title: 'Easy',
        durationMin: 15,
        distanceKm: 2,
        phase: 'base',
        status: 'done',
      );
      plans.add(w);
      sessions.add(
        Session(
          id: 's$i',
          sport: Sport.run,
          title: 'Easy',
          start: DateTime(d.year, d.month, d.day, 18),
          durationSec: 900,
          distanceM: 2000,
          rpe: 3,
          planId: w.id,
        ),
      );
    }
    final long = PlannedWorkout(
      id: 'long',
      date: DateTime(2026, 11, 20, 9),
      sport: Sport.run,
      title: 'Long run',
      durationMin: 60,
      distanceKm: 7,
      intensity: 'long',
      phase: 'base',
      steps: const [WorkoutStep(kind: 'steady', distanceM: 7000, zone: 'E')],
    );
    plans.add(long);
    final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, fillGaps: false).run();
    final c = r.changes.firstWhere((c) => c.before.id == 'long');
    final floor = Recalibrator.runFloor(long, p);
    print('R1 floor: 7.0 km → ${c.after.distanceKm} km / ${c.after.durationMin} min (cap 2.2 km, floor ${floor.toStringAsFixed(2)} km)');
    expect(r.reasons, contains(RecalReason.longCap));
    expect(c.after.distanceKm!, greaterThanOrEqualTo(2.3));
    expect(c.after.durationMin, greaterThanOrEqualTo(20));
  });

  // ───────────────────────── 2. Re-created plan starts from the reached volume ─────────────────────────
  test('plan re-created at W9 (M_recreateW9): starts from the reached volume, not the setup (35 km / 16 km)', () {
    UserProfile? reached;
    late List<PlannedWorkout> before, after;
    final day = addDays(h.simStart, 7 * 8);
    sim(
      'M_recreateW9',
      h.marathoner,
      (w, k) => perfect(w),
      9,
      hooks: {
        8: (s, p, d) {
          reached = withReachedVolume(p, plans: s.plans, sessions: s.sessions, start: d);
          final weeks = daysBetween(d, p.athlete.eventDate!) ~/ 7 + 1;
          before = PlanGenerator(l, p, templates, id).generate(start: d, weeks: weeks);
          after = PlanGenerator(l, reached!, templates, id).generate(start: d, weeks: weeks);
        },
      },
    );
    double wk(List<PlannedWorkout> ws) =>
        ws.where((x) => x.sport == Sport.run && startOfWeek(x.date) == day).fold(0.0, (a, x) => a + (x.distanceKm ?? 0));
    List<double?> longs(List<PlannedWorkout> ws) =>
        ws.where((x) => x.sport == Sport.run && x.intensity == 'long').take(3).map((x) => x.distanceKm).toList();
    final a = reached!.athlete;
    print(
      'recreate W9: profile ${h.marathoner().athlete.runWeeklyKm}/${h.marathoner().athlete.longestRunKm} → ${a.runWeeklyKm}/${a.longestRunKm}; '
      'first week ${wk(before).toStringAsFixed(1)} → ${wk(after).toStringAsFixed(1)} km; next longs ${longs(before)} → ${longs(after)}',
    );
    expect(a.runWeeklyKm!, greaterThan(35));
    expect(a.longestRunKm!, greaterThan(16));
    expect(wk(after), greaterThan(wk(before)));
    expect(longs(after).first!, greaterThan(longs(before).first!));
    // No jump: the first long run of the new plan stays within ~R1 of the longest reached (the
    // generator rounds to 0.5 km).
    expect(longs(after).first!, lessThanOrEqualTo(a.longestRunKm! * 1.1 + 0.25));
  });

  test('withReachedVolume: a fresh setup (no plan history) keeps the entered values', () {
    final p = h.marathoner();
    expect(identical(withReachedVolume(p, plans: const [], sessions: const [], start: h.simStart), p), isTrue);
  });

  // ───────────────────────── 3. Taper ─────────────────────────
  test('M_taperOverdo: taper message + warning instead of rpeHigh / recovery week (W17 before: rpeHigh, long 17.0 → 15.3 km)', () {
    final r = sim('M_taperOverdo', h.marathoner, (w, k) {
      if (w.phase == 'taper') return (1.3, h.isQuality(w) ? 1.03 : 1.0, h.isQuality(w) ? 8 : 6);
      return perfect(w);
    }, 18);
    for (final (wk, _, rc, _) in r.weeks.where((w) => w.$1 >= 16)) {
      print(
        'taper W$wk: ${rc.reasons.map((x) => x.name).toList()} done ${((rc.stats.taperDone ?? 0) * 100).round()} % changes ${rc.changes.map((c) => '${c.kind.name} ${c.before.distanceKm}→${c.after.distanceKm}').toList()}',
      );
      expect(rc.reasons, isNot(contains(RecalReason.rpeHigh)), reason: 'W$wk');
      expect(rc.reasons, isNot(contains(RecalReason.fatigueRecovery)), reason: 'W$wk');
      expect(
        rc.changes.where((c) => c.kind == RecalKind.harder || c.kind == RecalKind.easier || c.kind == RecalKind.toEasy),
        isEmpty,
        reason: 'W$wk',
      );
      if (wk >= 17) {
        expect(rc.reasons, contains(RecalReason.taperOverdo), reason: 'W$wk');
        expect(rc.stats.taperDone!, greaterThan(1.2));
      }
    }
  });

  test('taper: never more volume, never a recovery-week mark', () {
    final r = sim('M_taperEasy', h.marathoner, (w, k) => (1, h.isQuality(w) ? 1.05 : 1.0, h.isQuality(w) ? 4 : 3), 18);
    for (final (wk, _, rc, _) in r.weeks.where((w) => w.$1 >= 16)) {
      expect(rc.changes.where((c) => c.kind == RecalKind.harder), isEmpty, reason: 'W$wk');
      expect(rc.reasons, isNot(contains(RecalReason.rpeLow)), reason: 'W$wk');
    }
  });

  // ───────────────────────── 4. FTP / CSS spacing and cap ─────────────────────────
  test('ride_ftpStrong: FTP 220 → 287 W (+30 %) before; now steps ≥ 3 weeks apart and ≤ +8 % (≤ 237 W)', () {
    final r = sim('ride_ftpStrong', ride160, (w, k) => (1, (w.intensity == 'tempo' || w.intensity == 'intervals') ? 1.06 : 1.0, 4), 12);
    DateTime? last;
    final steps = <String>[];
    for (final (wk, d, rc, _) in r.weeks) {
      if (rc.stats.newFtp == null) continue;
      steps.add('W$wk ${rc.stats.oldFtp}→${rc.stats.newFtp}');
      if (last != null) expect(daysBetween(last, d), greaterThanOrEqualTo(Recalibrator.minVdotStepDays), reason: 'W$wk');
      last = d;
    }
    print('FTP steps: $steps → final ${r.profile.athlete.ftp} W');
    expect(r.profile.athlete.ftp, lessThanOrEqualTo((220 * 1.08).floor()));
    expect(r.profile.athlete.ftp, greaterThan(220));
    expect(r.profile.athlete.ftpBase, 220);
  });

  test('swim_cssFast: CSS steps ≥ 3 weeks apart and ≤ 4 % faster than the start', () {
    final r = sim('swim_cssFast', swimmer, (w, k) => (1, 1.04, 3), 12);
    DateTime? last;
    final steps = <String>[];
    for (final (wk, d, rc, _) in r.weeks) {
      if (rc.stats.newCss == null) continue;
      steps.add('W$wk ${rc.stats.oldCss}→${rc.stats.newCss}');
      if (last != null) expect(daysBetween(last, d), greaterThanOrEqualTo(Recalibrator.minVdotStepDays), reason: 'W$wk');
      last = d;
    }
    final css = SwimZones.fromTests(r.profile.athlete.swim400Sec, r.profile.athlete.swim200Sec)!;
    print('CSS steps: $steps → final $css s/100 m');
    expect(css, greaterThanOrEqualTo((105 * 0.96).ceil()));
  });

  test('FTP: no step up during a return after a break', () {
    // Ride well for 3 weeks, then 2 weeks off: the Monday after the break shows no FTP rise.
    final r = sim('ride_break', ride160, (w, k) => k == 3 || k == 4 ? null : (1, h.isQuality(w) ? 1.06 : 1.0, 4), 6);
    for (final (wk, _, rc, _) in r.weeks.where((w) => w.$3.reasons.contains(RecalReason.returnAfterBreak))) {
      expect(rc.reasons, isNot(contains(RecalReason.ftpUp)), reason: 'W$wk');
    }
  });

  // ───────────────────────── 5. "A little more volume" spaced ─────────────────────────
  List<int> raiseWeeks(Sim r) => [
    for (final (wk, _, rc, _) in r.weeks)
      if (rc.changes.any((c) => c.kind == RecalKind.harder)) wk,
  ];

  test('M_improveThenSick: "more volume" W2, W4, W5, W7 before → only weeks that really raise, never consecutive, ≤ 3×', () {
    final r = sim('M_improveThenSick', h.marathoner, (w, k) {
      if (k == 6 || k == 7) return null;
      if (k < 6) return (1, h.isQuality(w) ? 1.05 : 1.0, h.isQuality(w) ? 4 : 3);
      return perfect(w);
    }, 14);
    final said = [
      for (final (wk, _, rc, _) in r.weeks)
        if (rc.reasons.contains(RecalReason.rpeLow)) wk,
    ];
    final spaced = [
      for (final (wk, _, rc, _) in r.weeks)
        if (rc.reasons.contains(RecalReason.rpeLowSpaced)) wk,
    ];
    final raised = raiseWeeks(r);
    print('improveThenSick: rpeLow $said, raised $raised, spaced $spaced');
    // The message comes only with a raise (W4 is a recovery week – nothing to raise, no message).
    expect(said, raised);
    for (var i = 1; i < raised.length; i++) {
      expect(raised[i] - raised[i - 1], greaterThanOrEqualTo(2), reason: '$raised');
    }
    expect(raised.length, lessThanOrEqualTo(Recalibrator.maxVolumeRaises));
    expect(spaced, isNotEmpty);
  });

  test('quality easy for 16 weeks: at most 3 volume raises per plan, each a single +5 % on the generated session', () {
    final r = sim('M_easyQuality16', h.marathoner, (w, k) => (1, 1.0, h.isQuality(w) ? 4 : 3), 16);
    final raised = raiseWeeks(r);
    print('easyQuality16: raised $raised');
    expect(raised.length, lessThanOrEqualTo(Recalibrator.maxVolumeRaises));
    for (var i = 1; i < raised.length; i++) {
      expect(raised[i] - raised[i - 1], greaterThanOrEqualTo(2), reason: '$raised');
    }
    final orig = {for (final w in r.original) w.id: w};
    for (final w in r.plans.where((w) => w.auto?.reason == 'recal' && orig[w.id] != null)) {
      final o = orig[w.id]!;
      if ((w.distanceKm ?? 0) > 0 && (o.distanceKm ?? 0) > 0) expect(w.distanceKm!, lessThanOrEqualTo(o.distanceKm! * 1.1 + 0.05));
    }
  });

  // ───────────────────────── 6. Partial adherence ─────────────────────────
  test('partial adherence: Sat easy run (done) 50 → 45 min before, now kept; the skipped Mon / Wed / Fri slots come down', () {
    final now = DateTime(2026, 11, 16, 7); // Monday
    final p = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.run,
      trainingDays: const [1, 2, 3, 5, 6, 7],
      athlete: const AthleteData(raceTimes: {'10k': 50 * 60}, runWeeklyKm: 40, longestRunKm: 16),
    );
    final plans = <PlannedWorkout>[];
    final sessions = <Session>[];
    // Mon / Wed / Fri / Sat easy 50' (8 km), Tue intervals 50', Sun long 100' (16 km); 2 weeks back + this week.
    const kinds = {1: 'easy', 2: 'intervals', 3: 'easy', 5: 'easy', 6: 'easy', 7: 'long'};
    for (var wk = 0; wk < 3; wk++) {
      for (final e in kinds.entries) {
        final d = addDays(DateTime(2026, 11, 2), 7 * wk + e.key - 1);
        final long = e.value == 'long';
        final km = long ? 16.0 : 8.0;
        final w = PlannedWorkout(
          id: 'w$wk-${e.key}',
          date: DateTime(d.year, d.month, d.day, 9),
          sport: Sport.run,
          title: e.value,
          durationMin: long ? 100 : 50,
          distanceKm: km,
          intensity: e.value,
          phase: 'base',
          isKey: e.value != 'easy',
          steps: [WorkoutStep(kind: 'steady', distanceM: km * 1000, zone: 'E')],
        );
        if (wk == 2) {
          plans.add(w);
          continue;
        }
        final skipped = e.value == 'easy' && e.key != 6;
        if (skipped) {
          plans.add(PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'skipped'}));
          continue;
        }
        sessions.add(
          Session(
            id: 's${w.id}',
            sport: Sport.run,
            title: w.title,
            start: DateTime(d.year, d.month, d.day, 18),
            durationSec: w.durationMin * 60,
            distanceM: km * 1000,
            rpe: h.nominalRpe(w),
            planId: w.id,
          ),
        );
        plans.add(PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'done', 'sessionId': 's${w.id}'}));
      }
    }
    final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, fillGaps: false).run();
    final cuts = {
      for (final c in r.changes.where((c) => c.kind == RecalKind.easier))
        c.before.date.weekday: '${c.before.durationMin}→${c.after.durationMin}',
    };
    print(
      'partial adherence: completion ${r.stats.completion?.toStringAsFixed(2)} ${r.reasons.map((x) => x.name).toList()} cuts by weekday $cuts',
    );
    expect(r.reasons, contains(RecalReason.lowCompletion));
    expect(cuts.containsKey(6), isFalse, reason: 'the Saturday easy run was done every week');
    expect(cuts.containsKey(7), isFalse, reason: 'long runs were done');
    expect(cuts.containsKey(1) || cuts.containsKey(3) || cuts.containsKey(5), isTrue);
  });

  test('M_partial6 (review scenario): easy runs on days the athlete trains are never cut', () {
    final r = sim('M_partial6', h.marathoner, (w, k) {
      if (k >= 1 && k <= 6) {
        if (w.intensity == 'easy' && (w.date.weekday == 1 || w.date.weekday == 6)) return null;
        if (w.intensity == 'long') return (0.85, 1, 5);
      }
      return perfect(w);
    }, 10);
    for (final (wk, _, rc, _) in r.weeks.where((w) => w.$3.reasons.contains(RecalReason.lowCompletion))) {
      for (final c in rc.changes.where((c) => c.kind == RecalKind.easier && c.before.intensity == 'easy')) {
        expect(c.before.date.weekday, anyOf(1, 6), reason: 'W$wk ${c.before.title}');
      }
    }
    // Long runs still follow R1 (never above 1.1 × the longest of 30 days); none below the floor.
    for (final w in r.plans.where((w) => w.intensity == 'long' && w.sport == Sport.run)) {
      expect(w.durationMin, greaterThanOrEqualTo(min(25, r.original.firstWhere((o) => o.id == w.id, orElse: () => w).durationMin)));
    }
  });
}
