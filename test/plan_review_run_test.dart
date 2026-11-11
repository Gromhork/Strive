import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/target_suggestion.dart';
import 'package:strive/services/zones.dart';

/// Running-plan findings of the independent plan review (23 generated plans, fix/adaptation-coherence):
/// time vs. distance vs. zone (C1 / IMPORTANT 10), day budgets (IMPORTANT 11), long-run share (C9),
/// run/walk race (C6), marathon peak (IMPORTANT 1), conservative targets (IMPORTANT 2), volume ceilings
/// (IMPORTANT 3), quality progression (IMPORTANT 4 / 18), recovery weeks (IMPORTANT 12), race day
/// (IMPORTANT 16 / 17) and the minor findings.
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'r${n++}';
  final start = DateTime(2026, 11, 16);
  final templates = defaultTemplates(id, de: true);
  DateTime race(int weeks) => DateTime(start.year, start.month, start.day + 7 * (weeks - 1) + 6);
  List<PlannedWorkout> gen(UserProfile p) =>
      PlanGenerator(l, p, templates, id).generate(start: start, weeks: p.athlete.eventDate == null ? p.athlete.planWeeks : null);

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

  // The review's running cases.
  final a1 = prof(
    level: 'beginner',
    days: const [2, 4, 6],
    a: AthleteData(
      setupMode: 'advanced',
      canRun30: false,
      sessionMinutes: 60,
      dayMinutes: const {6: 150},
      eventDistance: 'hm',
      eventDate: race(12),
    ),
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
  final a3 = prof(
    level: 'beginner',
    days: const [1, 3, 5, 7],
    exp: const {},
    a: AthleteData(canRun30: false, sessionMinutes: 60, eventDistance: 'hm', eventDate: race(12)),
  );
  final b = prof(
    level: 'beginner',
    days: const [1, 3, 6],
    exp: const {},
    a: AthleteData(sessionMinutes: 45, eventDistance: '5k', eventDate: race(8)),
  );
  final c = prof(
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
  final d = prof(
    days: const [1, 2, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      dayMinutes: const {7: 180},
      raceTimes: const {'hm': 1 * 3600 + 50 * 60},
      runWeeklyKm: 35,
      longestRunKm: 16,
      eventDistance: 'm',
      eventDate: race(18),
      targetTimeSec: 3 * 3600 + 55 * 60,
    ),
  );
  final e = prof(
    level: 'advanced',
    days: const [1, 2, 3, 4, 5, 7],
    a: AthleteData(
      setupMode: 'advanced',
      difficulty: 'challenging',
      sessionMinutes: 90,
      dayMinutes: const {7: 180},
      raceTimes: const {'hm': 1 * 3600 + 25 * 60},
      runWeeklyKm: 70,
      longestRunKm: 25,
      eventDistance: 'm',
      eventDate: race(18),
      targetTimeSec: 2 * 3600 + 59 * 60,
    ),
  );
  final f703 = prof(
    focus: TrainingFocus.triathlon,
    days: const [1, 2, 3, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      dayMinutes: const {6: 240, 7: 240},
      raceTimes: const {'10k': 48 * 60},
      ftp: 230,
      hasPowerMeter: true,
      swim400Sec: 440,
      swim200Sec: 210,
      eventDistance: '70.3',
      eventDate: race(16),
    ),
  );
  final p62 = prof(
    birth: 1964,
    gender: 'f',
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 60,
      raceTimes: const {'10k': 58 * 60},
      runWeeklyKm: 20,
      longestRunKm: 8,
      eventDistance: '10k',
      eventDate: race(12),
      targetTimeSec: 56 * 60,
    ),
  );
  final q = prof(
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 60,
      dayMinutes: const {7: 120},
      limitations: const ['knee'],
      raceTimes: const {'10k': 55 * 60},
      runWeeklyKm: 20,
      longestRunKm: 10,
      eventDistance: 'hm',
      eventDate: race(14),
    ),
  );
  final r = prof(
    level: 'beginner',
    days: const [2, 4, 7],
    a: AthleteData(setupMode: 'advanced', sessionMinutes: 30, canRun30: true, eventDistance: 'hm', eventDate: race(14)),
  );
  final s1 = prof(a: const AthleteData(planWeeks: 8, sessionMinutes: 60, raceTimes: {'10k': 50 * 60}));

  // A wider sweep for the invariants: levels × events × days × minutes.
  final sweep = <String, UserProfile>{
    'a1': a1,
    'a2': a2,
    'a3': a3,
    'b': b,
    'c': c,
    'd': d,
    'e': e,
    'p': p62,
    'q': q,
    'r': r,
    's1': s1,
    for (final lv in ['beginner', 'intermediate', 'advanced'])
      for (final ev in ['5k', '10k', 'hm', if (lv != 'beginner') 'm'])
        for (final mins in [30, 45, 75])
          '$lv-$ev-$mins': prof(
            level: lv,
            days: lv == 'advanced' ? const [1, 2, 4, 5, 7] : const [2, 4, 6, 7],
            a: AthleteData(
              sessionMinutes: mins,
              raceTimes: lv == 'beginner' ? const {} : {'10k': lv == 'advanced' ? 40 * 60 : 50 * 60},
              eventDistance: ev,
              eventDate: race(ev == 'm' ? 18 : 12),
            ),
          ),
  };
  final plans = {for (final x in sweep.entries) x.key: gen(x.value)};

  PaceZones zonesOf(UserProfile p) => PaceZones(Vdot.of(p.athlete) ?? Vdot.defaultFor(p.level));
  int stepSec(UserProfile p, PlannedWorkout w) =>
      w.steps.fold(0, (x, s) => x + estimateStepSec(s, Sport.run, easyPace: zonesOf(p).easySlow, css: 100));
  Map<DateTime, List<PlannedWorkout>> byWeek(List<PlannedWorkout> plan) {
    final m = <DateTime, List<PlannedWorkout>>{};
    for (final w in plan) {
      m.putIfAbsent(startOfWeek(w.date), () => []).add(w);
    }
    return m;
  }

  // Running km ([runningKm]: walk breaks / stride walks are part of the distance, not of the run volume).
  double runKm(List<PlannedWorkout> ws) => ws.where((w) => w.sport == Sport.run).fold(0.0, (x, w) => x + runningKm(w));
  bool raceWeek(List<PlannedWorkout> ws) => ws.any((w) => w.intensity == 'race');

  test('C1 / IMPORTANT 10: run durations equal their step estimate (±3 %) and easy runs imply an E pace', () {
    var checked = 0;
    for (final x in sweep.entries) {
      final z = zonesOf(x.value);
      for (final w in plans[x.key]!.where((w) => w.sport == Sport.run && w.intensity != 'race' && w.steps.isNotEmpty)) {
        final est = stepSec(x.value, w);
        expect(
          (w.durationMin * 60 - est).abs(),
          lessThanOrEqualTo(max(est * 0.03, 31)),
          reason: '${x.key} ${w.date} ${w.title} ${w.durationMin}\' vs ${est / 60}',
        );
        final moving = w.steps.where((s) => s.zone != 'walk');
        final easy = (w.intensity == 'easy' || w.intensity == 'long') && moving.every((s) => s.zone == 'E' && s.distanceM != null);
        if (!easy || (w.distanceKm ?? 0) <= 0) continue;
        final walk = w.steps.where((s) => s.zone == 'walk').fold(0, (t, s) => t + (s.durationSec ?? 0));
        final pace = (w.durationMin * 60 - walk) / w.distanceKm!;
        expect(
          pace,
          inInclusiveRange(z.easyFast - 1, z.easySlow + 1),
          reason: '${x.key} ${w.date} ${w.title} ${w.durationMin}\' ${w.distanceKm} km',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(200));
  });

  test('IMPORTANT 11: no training day exceeds the time set for it', () {
    for (final x in sweep.entries) {
      final perDay = <DateTime, int>{};
      for (final w in plans[x.key]!.where((w) => w.intensity != 'race')) {
        perDay[dayOnly(w.date)] = (perDay[dayOnly(w.date)] ?? 0) + w.durationMin;
      }
      for (final e in perDay.entries) {
        expect(e.value, lessThanOrEqualTo(PlanGenerator.dayMinutesFor(x.value, e.key.weekday)), reason: '${x.key} ${e.key}');
      }
    }
  });

  test('C9: the long run ≤ 50 % of the actual week and ≤ 2 × the next-longest run; long-day default is reported', () {
    for (final key in ['r', 'q', 'a2', 'c', 's1', 'p']) {
      // (Run/walk weeks: the long run/walk is time on feet, Galloway – not part of this rule.)
      for (final ws in byWeek(
        plans[key]!,
      ).values.where((ws) => !raceWeek(ws) && !ws.any((w) => w.steps.any((s) => s.note == l.stepTalkPace)))) {
        final runs = ws.where((w) => w.sport == Sport.run).toList();
        final long = runs.where((w) => w.intensity == 'long').firstOrNull;
        if (long == null || runs.length < 3) continue;
        final km = long.distanceKm!;
        final next = runs.where((w) => w != long).fold(0.0, (x, w) => max(x, w.distanceKm ?? 0));
        // Review r2 C6: weeks with three runs follow the Galloway / Higdon novice plans – ≤ 65 % and
        // ≤ 3.5 × the next run; four runs keep 50 % / 2 ×.
        final three = runs.length == 3;
        expect(km, lessThanOrEqualTo((three ? 0.65 : 0.5) * runKm(runs) + 0.3), reason: '$key ${long.date}');
        expect(km, lessThanOrEqualTo((three ? 3.5 : 2) * next + 0.3), reason: '$key ${long.date}');
      }
    }
    // Marathon: ≤ 55 % (spec §1.10).
    for (final ws in byWeek(plans['d']!).values.where((ws) => !raceWeek(ws))) {
      final long = ws.where((w) => w.intensity == 'long').firstOrNull;
      if (long != null) expect(long.distanceKm!, lessThanOrEqualTo(0.55 * runKm(ws) + 0.3));
    }
    final f = PlanGenerator.feasibility(r, start: start, l: l);
    expect(f.issues, contains('longDayDefault'));
    expect(f.longDayWeekday, 7);
    expect(f.longDayNeedMin, greaterThanOrEqualTo(45));
    expect(f.issues, contains('longRunShare'));
    expect(f.otherRunNeedMin, greaterThan(30));
    for (final i in f.issues) {
      if (i == 'longDayDefault' || i == 'longRunShare') expect(f.extraIssueText(l, i, dayName: (d) => 'So'), isNotEmpty);
    }
    // Explicit day time: no default note.
    expect(PlanGenerator.feasibility(d, start: start, l: l).issues, isNot(contains('longDayDefault')));
  });

  test('C6: run/walk starters race finish-only (no pace, a run/walk time, no outlook times)', () {
    for (final p in [a1, a2, b]) {
      expect(PlanGenerator.finishOnly(p), isTrue);
      expect(PlanGenerator.outlook(p, start: start).every((o) => o.predictedSec == null), isTrue);
      expect(suggestTargetTime(p, p.athlete.eventDistance!, p.athlete.eventDate!, now: start).finishOnly, isTrue);
      final race = gen(p).firstWhere((w) => w.intensity == 'race');
      expect(race.steps.every((s) => s.paceMin == null && s.paceMax == null), isTrue);
      final km = race.distanceKm!;
      // ≥ 7:30 /km – not the 5:18 /km ("26:32" 5 km, 131' HM) of the level-default VDOT.
      expect(race.durationMin * 60 / km, greaterThan(450), reason: '${p.athlete.eventDistance} ${race.durationMin}');
      expect(race.description, isNot(contains(RegExp(r'\d:\d\d'))), reason: race.description);
    }
    expect(PlanGenerator.finishOnly(c), isFalse);
    expect(PlanGenerator.outlook(c, start: start).every((o) => o.predictedSec != null), isTrue);
  });

  test('IMPORTANT 1: marathon peak – one MP element a week, ≤ 2 hard sessions, easy runs ≥ 5 km, no 3 × max long run', () {
    for (final key in ['d', 'e']) {
      final weeks = byWeek(plans[key]!).values.where((ws) => ws.first.phase == 'peak' || ws.any((w) => w.phase == 'peak')).toList();
      final longs = <double>[];
      for (final ws in weeks.where((ws) => !ws.any((w) => w.phase == 'recovery'))) {
        final mpRun = ws.where((w) => w.title == l.wMpRun).length;
        final mpLong = ws.where((w) => w.intensity == 'long' && w.steps.any((s) => s.isWork && s.zone == 'M')).length;
        expect(mpRun + mpLong, 1, reason: '$key ${ws.first.date}');
        final hard = ws.where((w) => w.intensity == 'tempo' || w.intensity == 'intervals').length + mpLong;
        expect(hard, lessThanOrEqualTo(2), reason: '$key ${ws.first.date}');
        for (final w in ws.where((w) => w.intensity == 'easy' && w.sport == Sport.run)) {
          expect(w.steps.first.distanceM! / 1000, greaterThanOrEqualTo(5), reason: '$key ${w.date}');
        }
        longs.add(ws.firstWhere((w) => w.intensity == 'long').distanceKm!);
      }
      final top = longs.fold(0.0, max);
      for (var i = 0; i + 2 < longs.length; i++) {
        expect([longs[i], longs[i + 1], longs[i + 2]].every((x) => x >= top - 0.5), isFalse, reason: '$key $longs');
      }
    }
  });

  test('IMPORTANT 2: a conservative target is flagged and race-pace work is not slower than realistic', () {
    final f = PlanGenerator.feasibility(d, start: start, l: l);
    expect(f.issues, contains('targetConservative'));
    expect(f.target!.conservative, isTrue);
    expect(f.extraIssueText(l, 'targetConservative', dayName: (_) => ''), contains(clock(f.target!.realisticSec)));
    final realisticPace = f.target!.realisticSec / 42.195;
    final z = zonesOf(d);
    for (final w in plans['d']!.where((w) => w.phase == 'peak' && w.intensity != 'race')) {
      for (final s in w.steps.where((s) => s.isWork && s.zone == 'M' && s.paceMax != null)) {
        expect(s.paceMax!, lessThanOrEqualTo(realisticPace + 6), reason: '${w.date} ${w.title}');
        expect(s.paceMax!, lessThanOrEqualTo(z.marathon + 5), reason: '${w.date} ${w.title}');
      }
    }
    // A realistic target (c is ambitious, p is ok) is not conservative.
    expect(PlanGenerator.feasibility(p62, start: start, l: l).issues, isNot(contains('targetConservative')));
  });

  test('IMPORTANT 3: weekly run km within the ceiling incl. the long run, no front-loaded flat volume', () {
    for (final ws in byWeek(plans['d']!).values) {
      expect(runKm(ws.where((w) => w.intensity != 'race').toList()), lessThanOrEqualTo(35 * 1.5 + 0.5), reason: '${ws.first.date}');
    }
    final eWeeks = byWeek(plans['e']!).values.where((ws) => !raceWeek(ws)).map(runKm).toList();
    final top = eWeeks.fold(0.0, max);
    expect(top, lessThanOrEqualTo(90 * 1.15 + 0.5)); // advanced ceiling, CHALLENGING +15 %
    expect(eWeeks[5], lessThan(top * 0.9), reason: '$eWeeks'); // week 6 is not yet the peak volume
  });

  test('IMPORTANT 4 / 18: quality sessions progress; no VO2max fartlek right after run/walk', () {
    final eTitles = plans['e']!.where((w) => w.phase == 'build').map((w) => w.title).toSet();
    expect(eTitles.where((t) => t.startsWith('Intervalle')).length, greaterThanOrEqualTo(2), reason: '$eTitles');
    expect(eTitles.where((t) => t.startsWith('Cruise')).length, greaterThanOrEqualTo(2), reason: '$eTitles');
    // Beginner fartlek: more or longer pick-ups over the plan.
    final shapes =
        plans['r']!
            .where((w) => w.title == l.wFartlek && w.phase != 'taper' && w.phase != 'recovery')
            .map((w) => '${w.steps.where((s) => s.isWork).length}x${w.steps.firstWhere((s) => s.isWork).durationSec}')
            .toSet();
    expect(shapes.length, greaterThanOrEqualTo(3), reason: '$shapes');
    final firstQ = plans['a2']!.firstWhere((w) => w.title == l.wFartlek);
    expect(firstQ.steps.where((s) => s.isWork).every((s) => s.zone != 'I'), isTrue);
  });

  test('IMPORTANT 12: recovery weeks 65–75 % of the loading week, also right after run/walk', () {
    final weeks = byWeek(plans['a2']!).values.toList();
    for (var i = 1; i < weeks.length; i++) {
      if (!weeks[i].any((w) => w.phase == 'recovery')) continue;
      final prev = weeks.sublist(0, i).lastWhere((ws) => ws.every((w) => w.phase != 'recovery'));
      expect(runKm(weeks[i]), lessThanOrEqualTo(runKm(prev) * 0.76), reason: '${weeks[i].first.date}');
    }
    final lastRw = weeks.lastIndexWhere(
      (ws) => ws.any((w) => w.steps.any((s) => s.note == l.stepTalkPace) && w.intensity == 'easy' && w.phase != 'taper'),
    );
    expect(weeks.skip(lastRw + 1).take(2).any((ws) => ws.any((w) => w.phase == 'recovery')), isTrue);
  });

  test('IMPORTANT 16: race day – multisport legs, one source of truth for the time', () {
    // 70.3: one race session (stored as a ride, not a swim) whose steps are the legs swim – bike – run,
    // adding up to the forecast's race-day time.
    final tri = gen(f703).where((w) => w.intensity == 'race').single;
    expect(tri.sport, Sport.ride);
    expect(tri.distanceKm, isNull);
    expect(tri.steps.map((s) => s.distanceM).toList(), [1900, 90000, 21100]);
    expect(tri.steps.map((s) => s.note.split(' ').first).toList(), [l.sportSwim, l.sportRide, l.sportRun]);
    final sug = suggestTargetTime(f703, '70.3', f703.athlete.eventDate!, now: start).sec!;
    expect((tri.durationMin * 60 - sug).abs(), lessThanOrEqualTo(60), reason: '${tri.durationMin} vs ${sug / 60}');
    expect((tri.steps.fold(0, (x, s) => x + s.durationSec!) - tri.durationMin * 60).abs(), lessThanOrEqualTo(30), reason: 'legs add up');
    // No target: the race shows the suggested time (the goal editor's / forecast's value).
    final qs = suggestTargetTime(q, 'hm', q.athlete.eventDate!, now: start).sec!;
    final qRace = plans['q']!.firstWhere((w) => w.intensity == 'race');
    expect(qRace.durationMin, (qs / 60).round());
    expect(qRace.description, contains(clock(qs)));
    // Duration matches the race pace.
    for (final key in ['c', 'd', 'e', 'p', 'q']) {
      final w = plans[key]!.firstWhere((w) => w.intensity == 'race');
      final s = w.steps.single;
      final paced = s.distanceM! / 1000 * (s.paceMin! + s.paceMax!) / 2;
      expect((w.durationMin * 60 - paced).abs(), lessThanOrEqualTo(60), reason: key);
    }
  });

  test('IMPORTANT 17: run/walk athletes shake out with walk breaks, former run/walkers without strides', () {
    for (final p in [a2, b]) {
      final plan = gen(p);
      final raceDay = plan.firstWhere((w) => w.intensity == 'race').date;
      final shake = plan.firstWhere((w) => dayOnly(w.date) == dayOnly(raceDay).subtract(const Duration(days: 1)));
      expect(shake.steps.any((s) => s.zone == 'R'), isFalse);
      expect(shake.durationMin, lessThanOrEqualTo(16));
      if (p == b) {
        // Still on run/walk in race week: the run/walk rhythm, ≤ 5 min blocks.
        expect(shake.steps.any((s) => s.zone == 'walk'), isTrue);
        expect(shake.steps.where((s) => s.zone == 'E').every((s) => (s.durationSec ?? 0) <= 300), isTrue);
      }
    }
    // Runners keep their strides.
    final c0 = plans['c']!;
    final cRace = c0.firstWhere((w) => w.intensity == 'race').date;
    expect(
      c0.firstWhere((w) => dayOnly(w.date) == dayOnly(cRace).subtract(const Duration(days: 1))).steps.any((s) => s.zone == 'R'),
      isTrue,
    );
  });

  test('MINOR: 5-min blocks, sane goal-pace HR, race zone per distance, run/walk titles, chosen days, masters strength', () {
    // Work blocks ≥ 10 min come in 5-min steps (also when shortened to the day's time).
    for (final plan in [...plans.values, gen(f703)]) {
      for (final w in plan.where((w) => w.intensity != 'race')) {
        for (final s in w.steps.where((s) => s.isWork && (s.durationSec ?? 0) >= 600 && s.zone != 'walk')) {
          if (w.sport == Sport.run && s.zone == 'E') continue; // run/walk blocks
          expect(s.durationSec! % 300, 0, reason: '${w.title} ${s.durationSec}');
        }
      }
    }
    // 10 km goal pace: HR zone 4, not 87–100 % HRmax.
    final hr = HrZones(c.estimatedMaxHr);
    for (final s in plans['c']!.expand((w) => w.steps).where((s) => s.note == l.stepGoalPaceNote)) {
      expect((s.hrMin!, s.hrMax!), hr.zone(4));
    }
    for (final (key, zone) in [('c', 'T'), ('d', 'M'), ('q', 'T'), ('lv5k', 'I')]) {
      final plan = key == 'lv5k' ? plans['intermediate-5k-45']! : plans[key]!;
      expect(plan.firstWhere((w) => w.intensity == 'race').steps.single.zone, zone, reason: key);
    }
    // A single run/walk block without walk breaks is a continuous run.
    expect(plans['a2']!.where((w) => w.title == l.wRunWalk(1, 30)), isEmpty);
    expect(plans['a2']!.where((w) => w.title == l.wRunContinuous(30)), isNotEmpty);
    // Quick-setup beginner: the chosen Monday is planned once run/walk is over.
    expect(plans['a3']!.any((w) => w.date.weekday == DateTime.monday && w.sport == Sport.run), isTrue);
    expect(
      plans['a3']!.where((w) => w.date.weekday == DateTime.monday).every((w) => !w.steps.any((s) => s.note == l.stepTalkPace)),
      isTrue,
    );
    // Masters runner without strength days: a strength tip.
    expect(plans['p']!.any((w) => w.description.contains(l.wMastersStrengthNote)), isTrue);
    expect(plans['c']!.any((w) => w.description.contains(l.wMastersStrengthNote)), isFalse);
    // Goal model legs add up to the prediction.
    final parts = GoalModel.legTimes(f703, 40)!;
    expect((parts.$1.fold(0, (x, y) => x + y) + parts.$2 - GoalModel.predict(f703, 40)!).abs(), lessThanOrEqualTo(3));
  });
}
