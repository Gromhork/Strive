import 'dart:math';
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
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/zones.dart';

/// Coach review 3 (2026-11, PhD exercise physiology; 23 profiles, 15 adaptation scenarios):
/// long-run monotony, race-day pacing, quality progression, pyramidal base, race-specific taper,
/// 5/10 km peak, triathlon intensity rotation and long-session days, partial adherence,
/// forecast vs. recalibration, break penalty, isKey after a swap, completion sample size.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9); // Monday
  final templates = defaultTemplates(id, de: false);
  DateTime race(int weeks) => start.add(Duration(days: 7 * (weeks - 1) + 6));
  int week(PlannedWorkout w) => w.date.difference(start).inDays ~/ 7;
  bool quality(PlannedWorkout w) => w.intensity == 'tempo' || w.intensity == 'intervals';

  UserProfile runner({
    String ev = '10k',
    int weeks = 12,
    Map<String, int> times = const {'10k': 3000},
    double? km = 30,
    double? longest = 12,
    List<int> days = const [2, 4, 6, 7],
    int minutes = 75,
    Map<int, int> dayMin = const {},
    int? target,
    String level = 'intermediate',
  }) => UserProfile(
    level: level,
    focus: TrainingFocus.run,
    birthYear: 1990,
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

  UserProfile tri({
    String ev = 'olympic',
    int weeks = 16,
    String level = 'intermediate',
    List<int> days = const [1, 2, 3, 4, 6, 7],
    Map<int, int> dayMin = const {},
    int age = 30,
    int? target,
  }) => UserProfile(
    level: level,
    focus: TrainingFocus.triathlon,
    birthYear: DateTime.now().year - age,
    experience: const {Sport.swim, Sport.ride, Sport.run},
    trainingDays: days,
    athlete: AthleteData(
      raceTimes: level == 'beginner' ? const {} : const {'10k': 3000},
      sessionMinutes: 60,
      dayMinutes: dayMin,
      eventDistance: ev,
      eventDate: race(weeks),
      ftp: level == 'beginner' ? null : 220,
      hasPowerMeter: level != 'beginner',
      swim400Sec: level == 'beginner' ? null : 420,
      swim200Sec: level == 'beginner' ? null : 200,
      targetTimeSec: target,
    ),
  );

  List<PlannedWorkout> gen(UserProfile p, {DateTime? from}) => PlanGenerator(l, p, templates, id).generate(start: from ?? start);

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ A3 long-run monotony â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  test('A3: 40-week marathon â€“ race-specific block, long run â‰¤ 40 % before the last 12 weeks, varied', () {
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
    final runKm = <int, double>{};
    for (final w in plan.where((w) => w.sport == Sport.run && w.intensity != 'race')) {
      runKm[week(w)] = (runKm[week(w)] ?? 0) + (w.distanceKm ?? 0);
    }
    final longs = {for (final w in plan.where((w) => w.sport == Sport.run && w.intensity == 'long')) week(w): w};
    // Before: 29 km long runs ~20 times from week 14. After: only in the race-specific build / peak.
    final longest = longs.values.where((w) => w.distanceKm! >= 28).toList();
    expect(longest.length, inInclusiveRange(1, 6), reason: '${longest.map(week)}');
    expect(longest.every((w) => week(w) >= 40 - GoalModel.specificWeeks), isTrue);
    // â‰¤ 40 % of the week outside the last 12 weeks (before: 55 %).
    for (final e in longs.entries.where((e) => e.key < 40 - 12 && e.value.phase != 'recovery')) {
      expect(e.value.distanceKm! / runKm[e.key]!, lessThanOrEqualTo(0.42), reason: 'week ${e.key + 1}');
    }
    // Volume still rises in the race-specific block (pre-plan â‰¤ 85 % of the ceiling).
    final pre = [for (var w = 0; w < 20; w++) runKm[w] ?? 0].reduce(max);
    final spec = [for (var w = 20; w < 37; w++) runKm[w] ?? 0].reduce(max);
    expect(spec, greaterThan(pre * 1.1));
    // No more than 3 loading weeks in a row with the same long run (base / build).
    var same = 0;
    double? last;
    for (final w in (longs.keys.toList()..sort())) {
      final x = longs[w]!;
      if (x.phase == 'recovery' || x.phase == 'taper' || x.phase == 'peak') continue;
      final sig = '${x.distanceKm}${x.title}';
      same = last != null && sig == '$last' ? same + 1 : 0;
      last = double.tryParse('${x.distanceKm}');
      expect(same, lessThan(3), reason: 'week ${w + 1}');
    }
    expect(longs.values.any((w) => w.title == l.wLongRunProgression), isTrue);
    expect(longs.values.any((w) => w.description.contains(l.wLongRunShortDesc)), isTrue);
    expect(PlanGenerator.feasibility(p, start: start, l: l).issues, isEmpty);
  });

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ A4 race pacing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  test('A4: unrealistic target â€“ race step at the realistic pace, "Goal â€¦ â€“ start at â€¦"', () {
    final p = runner(target: 2700); // 45:00 from a 50:00 10 km in 12 weeks
    final check = GoalModel.check(p, start: start)!;
    expect(check.status, TargetStatus.unrealistic);
    final r = gen(p).singleWhere((w) => w.intensity == 'race');
    final work = r.steps.singleWhere((s) => s.isWork);
    final pace = (check.realisticSec / 10).round();
    expect(work.paceMin, pace - 3); // before: 270 - 3 (target pace, ~6 % too fast)
    expect(r.description, contains(l.wRaceGoalStart(clock(2700), '${clock(pace)}/km')));
    // Realistic targets keep the target pace and the usual text.
    final ok = runner(target: 3000);
    final r2 = gen(ok).singleWhere((w) => w.intensity == 'race');
    expect(r2.steps.singleWhere((s) => s.isWork).paceMin, 300 - 3);
    expect(r2.description, contains(l.wRaceGoalDesc(clock(3000))));
  });

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ B3 / B4 / B5 / B6 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<WorkoutStep> work(PlannedWorkout w) => w.steps.where((s) => s.isWork).toList();
  bool goalSet(PlannedWorkout w) => quality(w) && work(w).isNotEmpty && work(w).every((s) => s.zone == 'M');

  test('B3: quality sessions progress â€“ no identical session for > 3 loading weeks in build / peak', () {
    for (final p in [
      runner(),
      runner(ev: 'hm', weeks: 16, times: const {'hm': 6000}, km: 45, longest: 16, days: const [1, 2, 3, 5, 6, 7], minutes: 120),
      runner(ev: 'm', weeks: 18, times: const {'hm': 6000}, km: 40, longest: 20, dayMin: const {7: 180}),
      runner(
        ev: 'm',
        weeks: 18,
        times: const {'hm': 5520},
        km: 60,
        longest: 24,
        days: const [1, 2, 3, 5, 6, 7],
        minutes: 90,
        dayMin: const {7: 180},
      ),
    ]) {
      final plan = gen(p);
      final byWeek = <int, List<String>>{};
      for (final w in plan.where((w) => w.sport == Sport.run && quality(w) && (w.phase == 'build' || w.phase == 'peak'))) {
        byWeek.putIfAbsent(week(w), () => []).add(w.title);
      }
      final ks = byWeek.keys.toList()..sort();
      var run = 0;
      for (var i = 1; i < ks.length; i++) {
        run = (byWeek[ks[i]]!..sort()).join() == (byWeek[ks[i - 1]]!..sort()).join() ? run + 1 : 0;
        expect(run, lessThan(3), reason: '${p.athlete.eventDistance} week ${ks[i] + 1}: $byWeek');
      }
    }
  });

  test('B3: HM / marathon race-pace segment of the peak long run grows; 10 km goal-pace repeats get longer', () {
    final hm = gen(
      runner(ev: 'hm', weeks: 20, times: const {'hm': 6000}, km: 45, longest: 16, days: const [1, 2, 3, 5, 6, 7], minutes: 120),
    );
    final segs = [for (final w in hm.where((w) => w.intensity == 'long' && w.phase == 'peak')) work(w).single.distanceM!];
    expect(segs.length, greaterThanOrEqualTo(2));
    expect(segs.last, greaterThan(segs.first), reason: '$segs'); // before: 25 % every week (5 km)
    expect(segs.first, lessThanOrEqualTo(3000));
    final tenK = gen(runner(weeks: 20, km: 35));
    final reps = [for (final w in tenK.where((w) => w.phase == 'peak' && goalSet(w))) work(w).first.distanceM!];
    expect(reps.length, greaterThanOrEqualTo(2));
    expect(reps.last, greaterThan(reps.first), reason: '$reps');
  });

  test('B4: pyramidal base â€“ second quality run is a progression run, I-pace work at most every other week', () {
    final p = runner(ev: 'hm', weeks: 20, times: const {'hm': 6000}, km: 45, longest: 16, days: const [1, 2, 3, 5, 6, 7], minutes: 120);
    final plan = gen(p);
    final base = plan.where((w) => w.sport == Sport.run && w.phase == 'base').toList();
    final iWeeks = {for (final w in base.where((w) => work(w).any((s) => s.zone == 'I'))) week(w)};
    final weeks = {for (final w in base) week(w)};
    for (final w in iWeeks) {
      expect(iWeeks.contains(w + 1) && weeks.contains(w + 1), isFalse, reason: 'I work in base weeks ${w + 1} and ${w + 2}');
      expect(base.where((x) => week(x) == w && work(x).any((s) => s.zone == 'I')).length, 1);
    }
    expect(base.any((w) => w.title == l.wProgressionRun), isTrue);
  });

  test('B5: the taper keeps a goal-pace set (~60 %), race week a shorter one', () {
    for (final (ev, times, repKm) in [
      ('m', const {'hm': 5520}, 3.0),
      ('hm', const {'hm': 6000}, 2.0),
      ('10k', const {'10k': 3000}, 1.0),
    ]) {
      final p = runner(
        ev: ev,
        weeks: 18,
        times: times,
        km: 55,
        longest: 22,
        days: const [1, 2, 3, 5, 6, 7],
        minutes: 100,
        dayMin: const {7: 180},
      );
      final taper = gen(p).where((w) => w.phase == 'taper' && w.sport == Sport.run && quality(w)).toList();
      expect(taper, isNotEmpty, reason: ev);
      expect(taper.every(goalSet), isTrue, reason: '$ev: ${taper.map((w) => w.title)}'); // before: 4 Ã— 1 min fartlek
      expect(work(taper.first).first.distanceM, repKm * 1000, reason: ev);
      expect(work(taper.first).first.paceMin, isNotNull);
      double total(List<WorkoutStep> s) => s.fold<double>(0, (x, s) => x + s.distanceM!);
      if (taper.length > 1) expect(total(work(taper.last)), lessThan(total(work(taper.first))), reason: ev);
    }
  });

  test('B6: 5 / 10 km peak â€“ one goal-pace set a week, strides stay', () {
    for (final p in [
      runner(weeks: 14, km: 35),
      runner(ev: '5k', weeks: 12, times: const {'5k': 1500}, km: 30, days: const [1, 2, 4, 6, 7]),
    ]) {
      final plan = gen(p);
      final peakWeeks = {for (final w in plan.where((w) => w.phase == 'peak')) week(w)};
      expect(peakWeeks, isNotEmpty);
      for (final k in peakWeeks) {
        final ws = plan.where((w) => week(w) == k && w.sport == Sport.run).toList();
        expect(ws.where(goalSet).length, 1, reason: '${p.athlete.eventDistance} week ${k + 1}');
      }
      expect(plan.where((w) => w.phase == 'peak' && w.title == l.wEasyStrides), isNotEmpty);
    }
  });

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ B7 / B8 triathlon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  test('B7 invariant: every triathlon plan has â‰¥ 1 quality per discipline per 2 weeks in build / peak', () {
    var checked = 0;
    final fails = <String>{};
    for (final level in ['beginner', 'intermediate', 'advanced']) {
      for (final ev in ['sprint', 'olympic', '70.3']) {
        for (final days in const [
          [1, 2, 3, 4, 6, 7],
          [1, 2, 3, 5, 6, 7],
          [1, 3, 5, 6, 7],
          [2, 4, 6, 7],
          [1, 2, 3, 4, 5, 6, 7],
        ]) {
          for (final age in [30, 55]) {
            final p = tri(ev: ev, level: level, days: days, age: age);
            final schedule = PlanGenerator.scheduleOf(p);
            int count(Sport s) => schedule.values.expand((v) => v).where((x) => x == s).length;
            final plan = gen(p);
            final load = [
              for (var w = 0; w < 16; w++)
                if (plan.any((x) => week(x) == w && (x.phase == 'build' || x.phase == 'peak'))) w,
            ];
            // Beginners (no back-to-back key days, H1; no CSS sets yet): in 5â€“7-day weeks the two
            // long sessions often leave a single quality slot â€“ at least one quality session per
            // 2 weeks overall (documented exception, Â§6.1).
            for (final sport in level == 'beginner' ? const [null] : [Sport.ride, Sport.run, Sport.swim]) {
              // A discipline with one session a week has no room for quality.
              if (sport != null && count(sport) < 2) continue;
              // Documented exception (H1): every other day of the discipline sits right next to a
              // long session – intermediates / masters never put quality next to a key day, and next
              // to a Saturday + Sunday long block it would make three key days in a row. CSS sets may
              // sit next to long sessions, masters' only next to one.
              if (sport != null) {
                final longs = PlanGenerator.longSessionDays(p).values.toSet();
                final block = longs.length == 2 && longs.any((d) => longs.contains(d % 7 + 1));
                int prev(int d) => d == 1 ? 7 : d - 1;
                final flank = {
                  for (final d in longs) ...[prev(d), d % 7 + 1],
                }.difference(longs);
                final other = [
                  for (final e in schedule.entries)
                    if (e.value.contains(sport) && !longs.contains(e.key)) e.key,
                ];
                final strict = level == 'intermediate' || age >= 50;
                final applies = sport == Sport.swim ? age >= 50 && block : strict || block;
                if (applies && other.isNotEmpty && other.every(flank.contains)) continue;
              }
              bool q(int w) => plan.any((x) => week(x) == w && (sport == null ? x.sport != Sport.gym : x.sport == sport) && quality(x));
              for (var i = 1; i < load.length; i++) {
                if (load[i] != load[i - 1] + 1) continue;
                checked++;
                if (!q(load[i]) && !q(load[i - 1])) {
                  fails.add('$level $ev $days ${age}y: no ${sport?.name ?? 'any'} quality in weeks ${load[i - 1] + 1}â€“${load[i] + 1}');
                }
              }
            }
          }
        }
      }
    }
    expect(fails, isEmpty, reason: fails.join('\n'));
    expect(checked, greaterThan(100));
  });

  test('B8: 70.3 long ride on the day with the most time; 70.3 long-run requirement', () {
    final p = tri(ev: '70.3', dayMin: const {6: 240, 7: 120});
    expect(PlanGenerator.longSessionDays(p), {Sport.ride: 6, Sport.run: 7}); // before: ride on Sunday (120 min)
    final plan = gen(p);
    final rides = plan.where((w) => w.sport == Sport.ride && w.intensity == 'long');
    expect(rides.every((w) => w.date.weekday == 6), isTrue);
    expect(rides.fold<int>(0, (x, w) => max(x, w.durationMin)), greaterThanOrEqualTo(150));
    expect(PlanGenerator.feasibility(p, start: start, l: l).issues, isEmpty);
    // A 60-min long-run day cannot build the ~16 km / 100 min long run of a 70.3.
    final short = tri(ev: '70.3', dayMin: const {6: 240, 7: 60});
    final f = PlanGenerator.feasibility(short, start: start, l: l);
    expect(f.issues, contains('longRunTime'));
    expect(PlanGenerator.longRunTargetFor('70.3'), 16);
  });

  test('nice-to-have: swim drills without pace targets, 70.3 peak bike tempo instead of VO2max', () {
    final plan = gen(tri(ev: '70.3', dayMin: const {6: 240, 7: 120}));
    final drills = plan.expand((w) => w.steps).where((s) => s.zone == 'DR').toList();
    expect(drills, isNotEmpty);
    expect(drills.every((s) => s.paceMin == null && s.paceMax == null), isTrue);
    final peakRides = plan.where((w) => w.sport == Sport.ride && w.phase == 'peak' && quality(w)).toList();
    expect(peakRides, isNotEmpty);
    expect(peakRides.expand(work).any((s) => s.zone == 'Z5'), isFalse);
    expect(peakRides.expand(work).every((s) => s.zone == 'Z3'), isTrue);
  });

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Adaptation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Session done(PlannedWorkout w, {double speed = 1, int? rpe, DateTime? at}) {
    final sec = w.steps.fold<int>(0, (x, s) => x + estimateStepSec(s, w.sport, easyPace: 360, css: 100));
    return Session(
      id: 's${w.id}',
      sport: w.sport,
      title: w.title,
      start: (at ?? w.date).add(const Duration(hours: 7)),
      durationSec: ((sec > 0 ? sec : w.durationMin * 60) / speed).round(),
      distanceM: (w.distanceKm ?? 0) * 1000,
      planId: w.id,
      rpe: rpe ?? (w.intensity == 'intervals' ? 7 : (w.intensity == 'tempo' ? 6 : 3)),
    );
  }

  (List<PlannedWorkout>, List<Session>) history(
    List<PlannedWorkout> plan,
    DateTime now, {
    bool Function(PlannedWorkout)? skip,
    Session Function(PlannedWorkout)? make,
  }) {
    final plans = <PlannedWorkout>[], sessions = <Session>[];
    for (final w in plan) {
      if (!dayOnly(w.date).isBefore(dayOnly(now)) || w.intensity == 'race' || (skip?.call(w) ?? false)) {
        plans.add(w);
        continue;
      }
      final s = make?.call(w) ?? done(w);
      sessions.add(s);
      plans.add(PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'done', 'sessionId': s.id}));
    }
    return (plans, sessions);
  }

  test('B9: chronic partial adherence (easy runs skipped, key sessions done) cuts easy volume, keeps the key sessions', () {
    final p = runner(
      ev: 'hm',
      weeks: 16,
      times: const {'hm': 6000},
      km: 45,
      longest: 16,
      days: const [1, 2, 3, 4, 5, 6, 7],
      minutes: 60,
    ).copyWith(goals: const ['strength']);
    final now = start.add(const Duration(days: 21, hours: 6));
    // Easy runs and strength sessions skipped, the key sessions done (all but last week's long run).
    final (plans, sessions) = history(
      gen(p),
      now,
      skip: (w) => w.intensity == 'easy' || w.sport == Sport.gym || (w.intensity == 'long' && now.difference(w.date).inDays < 7),
    );
    final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, fillGaps: false).run();
    expect(r.stats.completion, lessThan(0.5), reason: 'precondition');
    expect(r.reasons, contains(RecalReason.lowCompletion));
    // Before: the first quality run of the horizon became easy (re-entry).
    expect(r.changes.where((c) => c.kind == RecalKind.toEasy), isEmpty);
    final easier = r.changes.where((c) => c.kind == RecalKind.easier).toList();
    expect(easier, isNotEmpty);
    expect(easier.every((c) => c.before.intensity == 'easy'), isTrue, reason: '${easier.map((c) => c.before.title)}');
  });

  test('completion needs a real sample: plan started yesterday, one missed workout â†’ no cuts, no swaps', () {
    // Emulator finding: "0 % done â€“ less volume" a day after the plan start (easy run 40 â†’ 35 min,
    // technique swim 38 â†’ 31, tempo â†’ easy). Leftovers of an earlier plan and an old session made
    // the guard (â‰¥ 3 due workouts) pass and the break detection fire.
    final tue = DateTime(2026, 11, 10);
    final now = DateTime(2026, 11, 11, 7);
    final p = runner(days: const [2, 4, 6, 7]);
    final plan = gen(p, from: tue);
    expect(plan.where((w) => dayOnly(w.date).isBefore(dayOnly(now))).length, 1, reason: 'precondition');
    final leftovers = [
      for (final d in [DateTime(2026, 11, 7), DateTime(2026, 11, 8)])
        PlannedWorkout(id: 'old${d.day}', date: d, sport: Sport.run, title: l.planEasyRun, durationMin: 40, distanceKm: 6, phase: 'base'),
    ];
    final old = Session(id: 'old', sport: Sport.run, title: 'Run', start: DateTime(2026, 10, 30, 8), durationSec: 3600, distanceM: 11000);
    final r = Recalibrator(l, p, plans: [...leftovers, ...plan], sessions: [old], now: now, fillGaps: false).run();
    expect(r.stats.completion, isNull);
    expect(r.reasons, isNot(contains(RecalReason.lowCompletion)));
    expect(r.reasons, isNot(contains(RecalReason.returnAfterBreak)));
    expect(r.changes.where((c) => c.kind == RecalKind.toEasy || c.kind == RecalKind.easier), isEmpty);
  });

  test('isKey: a key session turned easy is written as no longer key', () {
    final before = PlannedWorkout(id: 'k', date: start, sport: Sport.run, title: 'Tempo', intensity: 'tempo', isKey: true);
    final after = PlannedWorkout(id: 'k', date: start, sport: Sport.run, title: 'Easy', intensity: 'easy');
    expect(RecalChange(before, after, RecalKind.toEasy).update['isKey'], false); // before: missing
    expect(RecalChange(before, before, RecalKind.paces).update.containsKey('isKey'), isFalse);
  });

  // Quality runs 5 % faster than planned at the intended effort.
  Session faster(PlannedWorkout w) => quality(w) ? done(w, speed: 1.05) : done(w);

  test('B10: forecast "ahead" needs â‰¥ 3 quality runs over â‰¥ 14 days', () {
    final p0 = runner(weeks: 14);
    final p = p0.copyWith(athlete: p0.athlete.merge({'targetTimeSec': (Vdot.raceTime(Vdot.of(p0.athlete)!, 10000) * 1.06).round()}));
    final plan = gen(p);
    GoalForecast at(int days) {
      final now = start.add(Duration(days: days, hours: 12));
      final (plans, sessions) = history(plan, now, make: faster);
      return GoalForecast.of(p, plans: plans, sessions: sessions, now: now)!;
    }

    final early = at(11); // two quality runs (weeks 1 and 2)
    expect(early.status, isNot(ForecastStatus.ahead), reason: '${early.trend}');
    final later = at(25);
    expect(later.trend.length, greaterThanOrEqualTo(3));
    expect(later.status, ForecastStatus.ahead);
    expect(later.suggestedSec, lessThan(p.athlete.targetTimeSec!));
  });

  test('B10: â‰¥ 3 quality runs â‰¥ 3 % faster at the intended effort â†’ VDOT +1, not twice from the same sessions', () {
    var p = runner(weeks: 14);
    final plan = gen(p);
    final now = start.add(const Duration(days: 28, hours: 6));
    final (plans, sessions) = history(plan, now, make: faster);
    final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, fillGaps: false).run();
    expect(r.reasons, contains(RecalReason.runTrendFaster)); // before: no VDOT change
    expect(r.stats.newVdot, closeTo(r.stats.oldVdot + 1, 0.05));
    // C5: the new VDOT is the profile's vdotEstimate (no synthetic race time).
    expect(r.raceTimes, isNull);
    p = p.copyWith(athlete: p.athlete.merge(r.athlete));
    final again = Recalibrator(l, p, plans: plans, sessions: sessions, now: now, fillGaps: false).run();
    expect(again.stats.newVdot, isNull);
  });

  test('B11: the break penalty survives one easy run and fades over ~2Ã— the break', () {
    final p = runner(weeks: 16);
    final plan = gen(p);
    // Trained 3 weeks, then 21 days off, then one easy run.
    final back = start.add(const Duration(days: 42));
    final (plans0, sessions0) = history(plan, back, skip: (w) => !w.date.isBefore(start.add(const Duration(days: 21))));
    final easy = plan.firstWhere((w) => !w.date.isBefore(back) && w.intensity == 'easy');
    final s = done(easy);
    final plans = [
      for (final w in plans0) w.id == easy.id ? PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'done', 'sessionId': s.id}) : w,
    ];
    final sessions = [...sessions0, s];
    final next = dayOnly(easy.date).add(const Duration(days: 1, hours: 12));
    final f = GoalForecast.of(p, plans: plans, sessions: sessions, now: next)!;
    expect(f.reasons, contains(ForecastReason.trainingBreak)); // before: gone after the run
    final noBreak =
        GoalForecast.of(
          p,
          plans: plans,
          sessions: [
            ...sessions,
            for (final w in plan.where(
              (w) => !w.date.isBefore(start.add(const Duration(days: 21))) && w.date.isBefore(back) && w.intensity != 'race',
            ))
              done(w),
          ],
          now: next,
        )!;
    expect(f.vdotNow!, lessThan(noBreak.vdotNow! - 0.5));
    // ~2 Ã— 21 days after the return the penalty is gone.
    final much = dayOnly(easy.date).add(const Duration(days: 45, hours: 12));
    final runs = [
      ...sessions,
      for (final w in plan.where((w) => w.date.isAfter(easy.date) && w.date.isBefore(much) && w.intensity != 'race')) done(w),
    ];
    final g = GoalForecast.of(p, plans: plans, sessions: runs, now: much)!;
    expect(g.reasons, isNot(contains(ForecastReason.trainingBreak)));
  });

  test('nice-to-have: triathlon target slower than today\'s prediction â†’ ahead, faster target suggested', () {
    final p0 = tri(ev: 'olympic');
    final pred = GoalModel.predict(p0, Vdot.of(p0.athlete)!)!;
    final p = tri(ev: 'olympic', target: (pred * 1.1).round());
    final plan = gen(p);
    final now = start.add(const Duration(days: 10, hours: 12));
    final (plans, sessions) = history(plan, now);
    final f = GoalForecast.of(p, plans: plans, sessions: sessions, now: now)!;
    expect(f.status, ForecastStatus.ahead);
    expect(f.suggestedSec, lessThan(p.athlete.targetTimeSec!));
  });
}
