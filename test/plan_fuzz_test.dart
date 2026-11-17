// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/event_sport_x.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/event_spec.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Property-based fuzz test of [PlanGenerator.generate] and [PlanGenerator.feasibility].
///
/// Random but valid profiles over every input the setup wizard allows (focus, level, sports, age, body,
/// days + per-day minutes incl. extremes, detailed day plan with 1–2 sessions a day, race distance by
/// date or by weeks, absurd / consistent / inconsistent target and race times, weekly volumes, FTP, CSS,
/// limitations, gym split / A/B assignment, long-run extension, units, start dates around DST changes
/// and the year change, quick vs detailed setup) – each profile normalised the way the setup saves it
/// (`UserProfile.fromMap(toMap())` drops implausible times, the quick setup drops the day plan).
///
/// Each plan is checked against invariants (see `_check`); violations are grouped by invariant with
/// frequency and the first examples (a reproducible profile + the offending workout).
///
/// Env: FUZZ_N (profiles, default 80 – sized for CI, < 60 s; 5000+ for an audit), FUZZ_SEED (default 20261116),
/// FUZZ_FROM (first index), FUZZ_ONLY (comma-separated case indices – print the plan week by week), FUZZ_EX
/// (examples per invariant, default 4), FUZZ_STRICT=1 (fail on every violation, also the [_open] ones).
///
/// The test fails on any violation of an invariant that holds today; the invariants in [_open] (known issues
/// another fix package owns) are reported, not failed – remove them from the list once they hold.
///
/// Every case i uses its own Random(seed * 100003 + i), so `FUZZ_ONLY=i` reproduces it alone.

const _wd = ['', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _limits = ['knee', 'back', 'shoulder', 'hip', 'ankle', 'heart'];
const _goals = ['strength', 'muscle', 'fatloss', 'endurance', 'health', 'race'];
const _gymKeys = [
  'fb_a', 'fb_b', 'fb_c', 'ul_upper_a', 'ul_upper_b', 'ul_lower_a', 'ul_lower_b', 'ppl_push', 'ppl_pull', 'ppl_legs', //
  'bro_chest', 'bro_back', 'bro_legs', 'bro_shoulders', 'bro_arms', 'bw_a', 'bw_b', 'home_a', 'home_b',
];

/// Values of the wizard's minute stepper: 20, 30, 45 … 180, 210 … 480.
final _stepper = [20, for (var m = 30; m <= 180; m += 15) m, for (var m = 210; m <= 480; m += 30) m];

class _Case {
  _Case(this.i, this.p, this.start, this.weeks, this.de, this.desc);
  final int i;
  final UserProfile p;
  final DateTime start;
  final int weeks;
  final bool de;
  final String desc;
}

T _pick<T>(Random r, List<T> xs) => xs[r.nextInt(xs.length)];
bool _p(Random r, double prob) => r.nextDouble() < prob;

/// Start days: uniformly over 2026-11-16 … 2028-12-31, a third of them in a DST-change week
/// (last Sunday of March / October ± 3 days) or around the year change.
DateTime _randomStart(Random r) {
  final k = r.nextInt(6);
  final year = 2027 + r.nextInt(2);
  DateTime lastSunday(int y, int m) {
    var d = DateTime(y, m + 1, 0);
    while (d.weekday != DateTime.sunday) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }

  final DateTime base = switch (k) {
    0 => lastSunday(year, 3),
    1 => lastSunday(year, 10),
    2 => DateTime(year - 1, 12, 28),
    _ => DateTime(2026, 11, 16 + r.nextInt(760)),
  };
  return DateTime(base.year, base.month, base.day + (k <= 2 ? r.nextInt(9) - 4 : 0));
}

_Case _randomCase(int i, int seed) {
  final r = Random(seed * 100003 + i);
  final focus = _pick(r, TrainingFocus.values);
  final level = _pick(r, const ['beginner', 'intermediate', 'advanced']);
  final age = _p(r, 0.15) ? _pick(r, const [12, 14, 16, 17, 70, 75, 80, 85, 90]) : 18 + r.nextInt(55);
  final goals = [
    for (final g in _goals)
      if (_p(r, 0.25)) g,
  ];
  final sports = {...focus.sports, if (goals.contains('strength') || goals.contains('muscle')) Sport.gym};
  final nDays = 1 + r.nextInt(7);
  final days = ([1, 2, 3, 4, 5, 6, 7]..shuffle(r)).take(nDays).toList()..sort();
  final advanced = _p(r, 0.45);
  final sessionsPerDay = advanced && _p(r, 0.35) ? 2 : 1;
  Map<int, List<Sport>> dayPlan = {};
  if (advanced) {
    final pd = ([1, 2, 3, 4, 5, 6, 7]..shuffle(r)).take(1 + r.nextInt(7)).toList();
    final sl = sports.toList();
    for (final d in pd) {
      final n = sessionsPerDay == 2 && _p(r, 0.4) && sl.length > 1 ? 2 : 1;
      dayPlan[d] = (sl..shuffle(r)).take(n).toList();
    }
    // Usually every sport of the focus has a day (the wizard warns when one has none).
    if (_p(r, 0.9)) {
      for (final s in focus.sports) {
        if (!dayPlan.values.any((v) => v.contains(s))) {
          final d = 1 + r.nextInt(7);
          dayPlan[d] = [...(sessionsPerDay == 2 ? (dayPlan[d] ?? const <Sport>[]).take(1) : const <Sport>[]), s];
        }
      }
    }
  }
  final sessionMinutes = _p(r, 0.15) ? _pick(r, const [20, 30, 360, 420, 480]) : _pick(r, _stepper);
  final dayMinutes = <int, int>{
    for (var d = 1; d <= 7; d++)
      if (_p(r, 0.2)) d: _p(r, 0.2) ? _pick(r, const [20, 30, 480]) : _pick(r, _stepper),
  };
  final trainDays = advanced && dayPlan.values.any((v) => v.isNotEmpty) ? (dayPlan.keys.toList()..sort()) : days;
  final longDay = _p(r, 0.5) ? _pick(r, trainDays) : (_p(r, 0.1) ? 1 + r.nextInt(7) : null);

  // Race.
  final fits = eventDistances.where((d) => d.sport == EventSportX.fromFocus(focus)).toList();
  final withEvent = fits.isNotEmpty && _p(r, focus == TrainingFocus.gym ? 0.0 : 0.7);
  final ev = withEvent ? _pick(r, fits).key : null;
  final byWeeks = withEvent && _p(r, 0.5);
  final start = _randomStart(r);
  final today = dayOnly(start);
  int? target;
  if (ev != null && _p(r, 0.5)) {
    final b = eventTimeBounds(ev)!;
    final kind = r.nextInt(4);
    target =
        switch (kind) {
          0 => b.$1 + r.nextInt(max(1, (b.$2 - b.$1) ~/ 10)), // absurdly fast
          1 => b.$2 - r.nextInt(max(1, (b.$2 - b.$1) ~/ 10)), // absurdly slow
          _ => b.$1 + r.nextInt(b.$2 - b.$1),
        } ~/
        60 *
        60;
  }
  // Race times: consistent (one VDOT), inconsistent (independent) or none.
  final raceTimes = <String, int>{};
  final rtKind = r.nextInt(3);
  if (rtKind > 0) {
    final vdot = 28 + r.nextDouble() * 45;
    for (final k in const ['5k', '10k', 'hm', 'm']) {
      if (!_p(r, 0.45)) continue;
      final b = eventTimeBounds(k)!;
      raceTimes[k] = rtKind == 1 ? Vdot.raceTime(vdot, Vdot.distances[k]!).round() : b.$1 + r.nextInt(b.$2 - b.$1);
    }
  }
  int? swimTest(int m) {
    final (lo, hi) = swimTestBounds(m);
    return lo + r.nextInt(hi - lo);
  }

  final s400 = _p(r, 0.3) ? swimTest(400) : null;
  final s200 = _p(r, 0.25) ? swimTest(200) : null;
  final assign = sports.contains(Sport.gym) && _p(r, 0.3);
  final ab = assign && _p(r, 0.5);
  final gymDays = [
    for (final e in dayPlan.entries)
      if (e.value.contains(Sport.gym)) e.key,
  ];
  final assignDays = gymDays.isNotEmpty ? gymDays : trainDays;
  Map<int, String> plan() => {
    for (final d in assignDays)
      if (_p(r, 0.7)) d: _p(r, 0.1) ? 'id:custom1' : 'key:${_pick(r, _gymKeys)}',
  };

  final athlete = <String, dynamic>{
    'setupMode': advanced ? 'advanced' : 'simple',
    'difficulty': _pick(r, const ['easy', 'balanced', 'challenging']),
    'planWeeks': _pick(r, PlanGenerator.supportedWeeks),
    'sessionMinutes': sessionMinutes,
    'dayMinutes': {for (final e in dayMinutes.entries) '${e.key}': e.value},
    'sessionsPerDay': sessionsPerDay,
    'dayPlan': {for (final e in dayPlan.entries) '${e.key}': e.value.map((s) => s.name).toList()},
    'limitations': [
      for (final x in _limits)
        if (_p(r, 0.12)) x,
    ],
    'raceTimes': raceTimes,
    'runWeeklyKm': _p(r, 0.4) ? (r.nextInt(121)).toDouble() : null,
    'longestRunKm': _p(r, 0.35) ? r.nextInt(85) / 2 : null,
    'canRun30': _p(r, 0.8),
    'ftp': _p(r, 0.35) ? (_p(r, 0.1) ? _pick(r, const [1, 20, 60, 600, 900]) : 80 + r.nextInt(340)) : null,
    'bikeWeeklyHours': _p(r, 0.3) ? r.nextInt(41) / 2 : null,
    'longestRideKm': _p(r, 0.3) ? r.nextInt(251).toDouble() : null,
    'hasPowerMeter': _p(r, 0.4),
    'indoorTrainer': _p(r, 0.4),
    'swim400Sec': s400,
    'swim200Sec': s200,
    'swimWeeklyKm': _p(r, 0.3) ? r.nextInt(51) / 2 : null,
    'canSwim400': _p(r, 0.8),
    'poolLength': _pick(r, const [25, 50, 0]),
    'equipment': _pick(r, const ['gym', 'home', 'bodyweight']),
    'gymGoal': _pick(r, const ['strength', 'hypertrophy', 'general']),
    'gymSplit': _pick(r, const ['auto', 'fullbody', 'upperlower', 'ppl', 'ulppl', 'bro']),
    'oneRm': {
      for (final k in const ['squat', 'bench', 'deadlift', 'ohp'])
        if (_p(r, 0.2)) k: (20 + r.nextInt(200)).toDouble(),
    },
    'gymAssign': assign,
    'gymAB': ab,
    'gymPlanA': assign ? {for (final e in plan().entries) '${e.key}': e.value} : <String, String>{},
    'gymPlanB': ab ? {for (final e in plan().entries) '${e.key}': e.value} : <String, String>{},
    'eventDistance': ev,
    'targetTimeSec': target,
    'longRunExtend': _p(r, 0.2),
  };
  var p = UserProfile.fromMap({
    'birthYear': DateTime.now().year - age,
    'gender': _pick(r, const ['m', 'f', 'd']),
    'heightCm': (130 + r.nextInt(91)).toDouble(),
    'weightKg': (70 + r.nextInt(291)) / 2,
    'level': level,
    'experience': [
      for (final s in focus.sports)
        if (_p(r, 0.6)) s.name,
    ],
    'focus': focus.name,
    'goals': goals,
    'trainingDays': trainDays,
    'longDay': longDay,
    'imperial': _p(r, 0.25),
    'maxHr': _p(r, 0.2) ? 150 + r.nextInt(66) : null,
    'onboarded': true,
    'athlete': athlete,
  });
  // Quick setup: the day plan is dropped (onboarding_page._finish).
  if (!advanced) p = p.copyWith(athlete: p.athlete.merge({'dayPlan': <int, List<Sport>>{}, 'sessionsPerDay': 1}));
  var weeks = p.athlete.planWeeks;
  if (ev != null) {
    DateTime date;
    if (byWeeks) {
      weeks = 4 + r.nextInt(GoalModel.maxEventWeeks - 3);
      date = PlanGenerator.raceDayForWeeks(p, today, weeks);
    } else {
      date = addDays(today, r.nextInt(731));
    }
    p = p.copyWith(athlete: p.athlete.merge({'eventDate': date, 'planWeeks': weeks}));
  }
  final de = _p(r, 0.5);
  return _Case(i, p, today, weeks, de, _describe(p, today, byWeeks: byWeeks, de: de));
}

String _describe(UserProfile p, DateTime start, {bool byWeeks = false, required bool de}) {
  final a = p.athlete;
  return [
    'focus=${p.focus.name}',
    'level=${p.level}',
    'age=${p.age}',
    'sex=${p.gender}',
    'h=${p.heightCm.round()} w=${p.weightKg}',
    if (p.goals.isNotEmpty) 'goals=${p.goals}',
    if (p.experience.isNotEmpty) 'exp=${p.experience.map((e) => e.name).toList()}',
    'days=${p.trainingDays}',
    if (p.longDay != null) 'longDay=${p.longDay}',
    if (p.imperial) 'imperial',
    if (p.maxHr != null) 'maxHr=${p.maxHr}',
    'mode=${a.setupMode}',
    'diff=${a.difficulty}',
    'min=${a.sessionMinutes}',
    if (a.dayMinutes.isNotEmpty) 'dayMin=${a.dayMinutes}',
    if (a.sessionsPerDay != 1) 'spd=${a.sessionsPerDay}',
    if (a.dayPlan.isNotEmpty) 'dayPlan={${a.dayPlan.entries.map((e) => '${e.key}:${e.value.map((s) => s.name).join('+')}').join(', ')}}',
    if (a.limitations.isNotEmpty) 'limits=${a.limitations}',
    if (a.raceTimes.isNotEmpty) 'raceTimes=${a.raceTimes}',
    if (a.runWeeklyKm != null) 'runKm=${a.runWeeklyKm}',
    if (a.longestRunKm != null) 'longestRun=${a.longestRunKm}',
    if (!a.canRun30) 'canRun30=false',
    if (a.ftp != null) 'ftp=${a.ftp}',
    if (a.bikeWeeklyHours != null) 'bikeH=${a.bikeWeeklyHours}',
    if (a.longestRideKm != null) 'longestRide=${a.longestRideKm}',
    if (a.hasPowerMeter) 'power',
    if (a.indoorTrainer) 'indoor',
    if (a.swim400Sec != null) 'swim400=${a.swim400Sec}',
    if (a.swim200Sec != null) 'swim200=${a.swim200Sec}',
    if (a.swimWeeklyKm != null) 'swimKm=${a.swimWeeklyKm}',
    if (!a.canSwim400) 'canSwim400=false',
    'pool=${a.poolLength}',
    if (p.focus == TrainingFocus.gym || p.goals.contains('strength') || p.goals.contains('muscle'))
      'gym=${a.equipment}/${a.gymGoal}/${a.gymSplit}',
    if (a.oneRm.isNotEmpty) '1rm=${a.oneRm}',
    if (a.gymAssign) 'A=${a.gymPlanA}',
    if (a.gymAB) 'B=${a.gymPlanB}',
    if (a.eventDistance != null)
      'event=${a.eventDistance} on ${a.eventDate == null ? '-' : dayKey(a.eventDate!)}${byWeeks ? ' (by ${a.planWeeks} weeks)' : ''}',
    if (a.targetTimeSec != null) 'target=${clock(a.targetTimeSec!)}',
    if (a.longRunExtend) 'longRunExtend',
    if (a.eventDistance == null) 'planWeeks=${a.planWeeks}',
    'start=${dayKey(start)} (${_wd[start.weekday]})',
    de ? 'de' : 'en',
  ].join(' ');
}

// ───────────────────────────── Report ─────────────────────────────

class _Report {
  final v = <String, List<String>>{};
  final cases = <String, Set<int>>{};
  void add(String inv, _Case c, String detail) {
    v.putIfAbsent(inv, () => []).add('#${c.i} ${c.desc}\n      → $detail');
    cases.putIfAbsent(inv, () => {}).add(c.i);
  }

  String summary(int n, int examples) {
    final b = StringBuffer('\n══════ plan fuzz: $n profiles ══════\n');
    final keys = v.keys.toList()..sort();
    for (final k in keys) {
      b.writeln(
        '${k.padRight(64)} ${cases[k]!.length.toString().padLeft(5)} ${(cases[k]!.length / n * 100).toStringAsFixed(2).padLeft(6)} %',
      );
    }
    for (final k in keys) {
      b.writeln('── $k (${cases[k]!.length}) ──');
      final seen = <int>{};
      var shown = 0;
      for (final e in v[k]!) {
        final id = int.parse(e.substring(1, e.indexOf(' ')));
        if (!seen.add(id)) continue;
        b.writeln('  $e');
        if (++shown >= examples) break;
      }
    }
    return b.toString();
  }
}

// ───────────────────────────── Checks ─────────────────────────────

int _days(DateTime a, DateTime b) => (dayOnly(a).difference(dayOnly(b)).inHours / 24).round();
final _brickRe = RegExp(r'brick|koppel|before the bike|vor dem rad', caseSensitive: false);
final _shakeRe = RegExp(r'shake|vorschwimmen|vorbelastung|lockerer auftakt', caseSensitive: false);
bool _brick(PlannedWorkout w) => w.sport == Sport.run && _brickRe.hasMatch(w.title);
bool _hard(PlannedWorkout w) => w.intensity == 'tempo' || w.intensity == 'intervals';
bool _hardOrLong(PlannedWorkout w) => _hard(w) || w.intensity == 'long';
String _w(PlannedWorkout w) =>
    '${dayKey(w.date)} ${_wd[w.date.weekday]} ${w.sport.name} "${w.title}" ${w.intensity} ${w.durationMin}\'${w.distanceKm == null ? '' : ' ${w.distanceKm} km'}${w.phase == null ? '' : ' [${w.phase}]'}';

final _placeholder = RegExp(r'\{|\}|\bnull\b|\bNaN\b|Infinity|\$|\bundefined\b|  |\(\)|\.\.(?!\.)| ,| \.$');

void _check(_Case c, List<PlannedWorkout> plan, _Report r, AppLocalizations l, List<WorkoutTemplate> templates) {
  final p = c.p;
  final a = p.athlete;
  final start0 = PlanGenerator.planStartFor(p, c.start);
  final monday = startOfWeek(start0);
  final weeksToEvent =
      a.eventDate == null
          ? null
          : (() {
            final w = GoalModel.weeksUntil(a.eventDate!, start0);
            return w >= 1 && w <= GoalModel.maxEventWeeks ? w : null;
          })();
  final ev = weeksToEvent != null ? a.eventDistance : null;
  final spec = EventSpec.of(ev);
  final total = weeksToEvent ?? c.weeks;
  final sched = PlanGenerator.scheduleOf(p);
  final schedAfter = PlanGenerator.scheduleOf(p, afterRunWalk: true);
  final raceDay = ev != null ? dayOnly(a.eventDate!) : null;
  int wk(DateTime d) => _days(d, monday) ~/ 7;
  final hrMax = p.estimatedMaxHr;

  if (plan.isEmpty) {
    r.add('S00 empty plan', c, 'no workouts');
    return;
  }

  // ── Values ──
  for (final w in plan) {
    if (w.durationMin <= 0) r.add('V01 duration <= 0', c, _w(w));
    if (w.durationMin > 480 && w.intensity != 'race') r.add('V01 duration > 8 h', c, _w(w));
    if (w.distanceKm != null && (!w.distanceKm!.isFinite || w.distanceKm! <= 0)) r.add('V02 distance not positive/finite', c, _w(w));
    for (final s in w.steps) {
      if ((s.durationSec != null && s.durationSec! <= 0) || (s.distanceM != null && (!s.distanceM!.isFinite || s.distanceM! <= 0))) {
        r.add('V03 step with non-positive duration/distance', c, '${_w(w)} step ${s.kind} ${s.zone} ${s.durationSec}s ${s.distanceM}m');
      }
      if (s.durationSec == null && s.distanceM == null) {
        r.add('V03 step without duration and distance', c, '${_w(w)} step ${s.kind} ${s.zone}');
      }
      if (s.paceMin != null && s.paceMax != null && s.paceMin! > s.paceMax!) {
        r.add('V04 paceMin > paceMax', c, '${_w(w)} ${s.zone} ${s.paceMin}-${s.paceMax}');
      }
      if (w.sport == Sport.run && s.zone != 'walk' && w.intensity != 'race') {
        final pm = s.paceMin, px = s.paceMax;
        if ((pm != null && pm < 150) || (px != null && px > 960)) r.add('V04 run pace implausible', c, '${_w(w)} ${s.zone} $pm-$px s/km');
      }
      if (w.sport == Sport.swim && ((s.paceMin != null && s.paceMin! < 55) || (s.paceMax != null && s.paceMax! > 300))) {
        r.add('V04 swim pace implausible', c, '${_w(w)} ${s.zone} ${s.paceMin}-${s.paceMax} s/100m');
      }
      if ((s.powerMin != null && s.powerMin! <= 0 && s.zone != 'Z1') || (s.powerMax != null && s.powerMax! <= 0)) {
        r.add('V05 power <= 0', c, '${_w(w)} ${s.zone} ${s.powerMin}-${s.powerMax} W');
      }
      if (s.powerMin != null && s.powerMax != null && s.powerMin! > s.powerMax!) {
        r.add('V05 powerMin > powerMax', c, '${_w(w)} ${s.zone} ${s.powerMin}-${s.powerMax}');
      }
      if ((s.hrMin != null && s.hrMin! <= 40) || (s.hrMax != null && s.hrMax! > hrMax + 1)) {
        r.add('V06 HR outside 40..HRmax', c, '${_w(w)} ${s.zone} ${s.hrMin}-${s.hrMax} (HRmax $hrMax)');
      }
      if (s.hrMin != null && s.hrMax != null && s.hrMin! > s.hrMax!) {
        r.add('V06 hrMin > hrMax', c, '${_w(w)} ${s.zone} ${s.hrMin}-${s.hrMax}');
      }
    }
  }

  // ── Texts ──
  for (final w in plan) {
    if (w.title.trim().isEmpty) r.add('T01 empty title', c, _w(w));
    if (w.sport != Sport.gym && w.description.trim().isEmpty) r.add('T01 empty description (endurance)', c, _w(w));
    for (final (what, t) in [('title', w.title), ('description', w.description), for (final s in w.steps) ('step note', s.note)]) {
      final m = _placeholder.firstMatch(t);
      if (m != null) {
        final at = max(0, m.start - 40);
        r.add(
          'T02 suspicious text in $what ("${m.group(0)}")',
          c,
          '${_w(w)}: …${t.substring(at, min(t.length, m.end + 40)).replaceAll('\n', '⏎')}…',
        );
      }
    }
  }

  // ── Dates / schedule ──
  final first = plan.map((w) => dayOnly(w.date)).reduce((x, y) => x.isBefore(y) ? x : y);
  if (first.isBefore(dayOnly(start0))) r.add('S01 workout before plan start', c, '${dayKey(first)} < ${dayKey(start0)}');
  final lastWeek = plan.map((w) => wk(w.date)).reduce(max);
  if (lastWeek + 1 != total) {
    r.add('S02 plan length != requested weeks', c, '${lastWeek + 1} weeks, expected $total (start ${dayKey(start0)})');
  }
  for (var i = 1; i < plan.length; i++) {
    if (plan[i].date.isBefore(dayOnly(plan[i - 1].date))) {
      r.add('S03 workouts not in date order', c, '${_w(plan[i - 1])} then ${_w(plan[i])}');
      break;
    }
  }
  final byDay = <DateTime, List<PlannedWorkout>>{};
  for (final w in plan) {
    byDay.putIfAbsent(dayOnly(w.date), () => []).add(w);
  }
  for (final e in byDay.entries) {
    final d = e.key, ws = e.value;
    final isRace = raceDay != null && sameDay(d, raceDay);
    if (isRace) continue;
    final allowed = {...?sched[d.weekday], ...?schedAfter[d.weekday]};
    if (allowed.isEmpty) {
      final shake = raceDay != null && _days(raceDay, d) == 1 && ws.every((w) => _shakeRe.hasMatch(w.title));
      r.add(
        shake ? 'S04 pre-race shake-out on a day without training' : 'S04 workout on a day without training',
        c,
        ws.map(_w).join(' | '),
      );
      continue;
    }
    for (final w in ws.where((w) => !allowed.contains(w.sport))) {
      // Brick runs off the bike are documented (multisport).
      final brick =
          (w.sport == Sport.run && ws.any((x) => x.sport == Sport.ride) && (spec?.multisport ?? false)) ||
          RegExp(r'instead|statt|shake|Vorbelastung|Auflockerung', caseSensitive: false).hasMatch(w.title);
      if (!brick) r.add('S05 sport not planned for that day', c, '${_w(w)} (day plan: ${allowed.map((s) => s.name)})');
    }
    final slots = max(sched[d.weekday]?.length ?? 0, schedAfter[d.weekday]?.length ?? 0);
    final brickRun = ws.where(_brick).length;
    if (brickRun > 0 && ws.any((w) => w.sport == Sport.run && !_brick(w))) {
      r.add('S10 brick day also holds a separate run', c, ws.map(_w).join(' | '));
    }
    if (ws.length > slots + brickRun) r.add('S06 more sessions than day slots', c, '${ws.length} > $slots: ${ws.map(_w).join(' | ')}');
    if (ws.length > 3) r.add('S06 more than 3 sessions on a day', c, ws.map(_w).join(' | '));
    final keys = <String>{};
    for (final w in ws) {
      if (!keys.add('${w.sport.name}|${w.title}')) r.add('S07 duplicate workout on a day', c, ws.map(_w).join(' | '));
    }
    final sportCount = <Sport, int>{};
    for (final w in ws) {
      sportCount[w.sport] = (sportCount[w.sport] ?? 0) + 1;
    }
    final dupSport = sportCount.entries.where((x) => x.value > (sched[d.weekday] ?? const []).where((s) => s == x.key).length.clamp(1, 9));
    if (dupSport.isNotEmpty) r.add('S07 same sport twice on a day (not in day plan)', c, ws.map(_w).join(' | '));
    // Day budget.
    final budget = PlanGenerator.dayMinutesFor(p, d.weekday);
    final sum = ws.fold(0, (x, w) => x + w.durationMin);
    if (sum > budget + 10) {
      final setMin = a.minutesOn(d.weekday);
      final cls = budget > setMin ? 'long-day default above set time' : (setMin <= 30 ? 'budget <= 30' : 'over set time');
      r.add('S08 day over budget ($cls)', c, '$sum\' > $budget\' (set $setMin\'): ${ws.map(_w).join(' | ')}');
    }
  }
  // Rest day: every full week has at least one day off unless 7 days were chosen; then an easy day.
  final weeks = <int, List<PlannedWorkout>>{};
  for (final w in plan) {
    weeks.putIfAbsent(wk(w.date), () => []).add(w);
  }
  final daysChosen = {...sched.keys, ...schedAfter.keys}.length;
  for (final e in weeks.entries) {
    final days = {for (final w in e.value) dayOnly(w.date)};
    if (days.length == 7 && daysChosen < 7) r.add('S09 no rest day although < 7 days chosen', c, 'W${e.key + 1}');
    if (days.length == 7) {
      final easyDay = days.any((d) => byDay[d]!.every((w) => !_hardOrLong(w) && w.intensity != 'race'));
      if (!easyDay) r.add('S09 7 training days without an easy day', c, 'W${e.key + 1}: ${e.value.where(_hardOrLong).map(_w).join(' | ')}');
    }
    if (days.length == 7 && !a.advanced && (p.level == 'beginner' || (p.age ?? 30) >= 60)) {
      r.add('S09 beginner / 60+ without a rest day', c, 'W${e.key + 1}');
    }
  }

  // ── Race ──
  final races = plan.where((w) => w.intensity == 'race').toList();
  if (ev != null) {
    // (A week without any sport of the race – a hybrid week of gym days only – places no race: audit UX-1.)
    final weekSports = {for (final v in PlanGenerator.scheduleOf(p, afterRunWalk: true).values) ...v};
    final raceable = PlanGenerator.raceSportsOf(spec).any(weekSports.contains);
    if (races.length != (raceable ? 1 : 0)) r.add('R01 not exactly one race', c, '${races.length} race workouts');
    if (races.isNotEmpty && !sameDay(races.first.date, raceDay!)) {
      r.add('R01 race not on race date', c, '${_w(races.first)} vs ${dayKey(raceDay)}');
    }
    final after = plan.where((w) => dayOnly(w.date).isAfter(raceDay!)).toList();
    if (after.isNotEmpty) r.add('R02 workouts after race day', c, after.map(_w).take(3).join(' | '));
    for (final w in plan.where((w) => w.intensity != 'race')) {
      final dd = _days(raceDay!, w.date);
      if (dd >= 1 && dd <= 2 && w.intensity == 'long') {
        r.add('R03 long session in the 2 days before the race', c, '${_w(w)} (race ${dayKey(raceDay)})');
      }
      if (dd >= 1 && dd <= 2 && w.phase != 'taper' && w.intensity != 'race') {
        r.add('R03 non-taper (loading) session in the 2 days before the race', c, '${_w(w)} (race ${dayKey(raceDay)})');
      }
      if (dd >= 1 && dd <= 2 && _hard(w)) r.add('R03 hard session in the 2 days before the race', c, '${_w(w)} (race ${dayKey(raceDay)})');
      if (dd >= 1 && dd <= 2 && w.sport != Sport.gym && w.durationMin > 60) {
        r.add('R03 > 60 min in the 2 days before the race', c, '${_w(w)} (race ${dayKey(raceDay)})');
      }
      if (dd >= 1 && dd <= 3 && w.sport == Sport.gym && w.gymMods.isEmpty && w.phase != 'taper') {
        r.add('R03 full gym session (no race mods) ≤ 3 days before race', c, '${_w(w)} (race ${dayKey(raceDay)})');
      }
    }
    // Taper: race week (without the race) and the week before are lighter than the biggest of the 4 weeks before.
    if (total >= 6) {
      double em(int i) =>
          (weeks[i] ?? const []).where((w) => w.sport != Sport.gym && w.intensity != 'race').fold(0.0, (x, w) => x + w.durationMin);
      final rw = total - 1;
      final peak = [for (var i = max(0, rw - 6); i <= rw - 2; i++) em(i)].fold(0.0, max);
      if (peak >= 150) {
        if (em(rw) > peak * 0.75) {
          r.add('R04 no taper in race week (> 75 % of peak)', c, 'race week ${em(rw).round()}\' vs peak ${peak.round()}\'');
        }
        if (spec!.taperFor(p.level) >= 2 && em(rw - 1) > peak * 0.95) {
          r.add('R04 week before race not reduced (> 95 % of peak)', c, '${em(rw - 1).round()}\' vs peak ${peak.round()}\'');
        }
      }
    }
  } else if (races.isNotEmpty) {
    r.add('R05 race in a plan without (valid) event', c, races.map(_w).join(' | '));
  }

  // ── Load ──
  double vol(List<PlannedWorkout> ws, Sport s) => ws
      .where((w) => w.sport == s && w.intensity != 'race')
      .fold(0.0, (x, w) => x + (s == Sport.ride ? w.durationMin : (s == Sport.run ? runningKm(w) : (w.distanceKm ?? 0))));
  final rideCap = PlanGenerator.longSessionCapMin(p, Sport.ride);
  final runCap = PlanGenerator.longSessionCapMin(p, Sport.run);
  final ext = PlanGenerator.longRunExtension(p);
  final runCapAll = a.longRunExtend && ext != null ? ext.maxMin : runCap;
  for (final s in [Sport.run, Sport.ride, Sport.swim]) {
    if (!plan.any((w) => w.sport == s)) continue;
    final (rel, abs, unit) = switch (s) {
      Sport.run => (0.20, 3.0, 'km'),
      Sport.ride => (0.25, 45.0, 'min'),
      _ => (0.25, 1.0, 'km'),
    };
    for (var i = 2; i < total - 1; i++) {
      final now = vol(weeks[i] ?? const [], s);
      final before = max(vol(weeks[i - 1] ?? const [], s), vol(weeks[i - 2] ?? const [], s));
      if (before > 0 && now > before * (1 + rel) + abs) {
        r.add(
          'L01 ${s.name} weekly volume jump > ${(rel * 100).round()} % + ${abs.round()} $unit',
          c,
          'W${i + 1}: ${before.toStringAsFixed(1)} → ${now.toStringAsFixed(1)} $unit',
        );
      }
    }
  }
  for (final e in weeks.entries) {
    final runs = e.value.where((w) => w.sport == Sport.run && w.intensity != 'race' && !_brick(w) && !_shakeRe.hasMatch(w.title)).toList();
    final long = runs.where((w) => w.intensity == 'long').toList();
    if (runs.length >= 3 && long.isNotEmpty) {
      final tot = runs.fold(0.0, (x, w) => x + runningKm(w));
      final lk = long.map(runningKm).reduce(max);
      if (tot > 0 && lk / tot > 0.62 && lk > 8) {
        r.add(
          'L02 long run > 62 % of weekly run km (>= 3 runs)',
          c,
          'W${e.key + 1}: ${lk.toStringAsFixed(1)} of ${tot.toStringAsFixed(1)} km',
        );
      }
    }
    for (final w in long) {
      if (runCapAll != null && w.durationMin > runCapAll + 5) r.add('L03 long run over its time cap', c, '${_w(w)} > cap $runCapAll\'');
    }
    final schedRuns = sched.values.fold(0, (x, v) => x + v.where((s) => s == Sport.run).length);
    if (schedRuns == 1 &&
        runs.length == 1 &&
        runs.first.durationMin > PlanGenerator.singleRunMaxMin + 5 &&
        runs.first.intensity == 'long') {
      r.add('L03 single weekly run > ${PlanGenerator.singleRunMaxMin} min', c, _w(runs.first));
    }
    for (final w in e.value.where((w) => w.sport == Sport.ride && w.intensity == 'long')) {
      if (rideCap != null && w.durationMin > rideCap + 5) r.add('L04 long ride over its cap', c, '${_w(w)} > cap $rideCap\'');
    }
    // Hard sessions per week.
    final hard = e.value.where(_hard).length;
    if (hard > (p.level == 'beginner' ? 2 : 3)) {
      r.add('L05 too many hard sessions in a week', c, 'W${e.key + 1}: $hard: ${e.value.where(_hard).map(_w).join(' | ')}');
    }
  }
  // Hard days back to back.
  final hardDays = <DateTime, List<PlannedWorkout>>{};
  for (final w in plan.where((w) => _hard(w) && w.intensity != 'race')) {
    hardDays.putIfAbsent(dayOnly(w.date), () => []).add(w);
  }
  for (final e in hardDays.entries) {
    if (e.value.length >= 2) r.add('L06 two hard sessions on one day', c, e.value.map(_w).join(' | '));
    final next = hardDays[addDays(e.key, 1)];
    if (next == null) continue;
    final same = e.value.any((x) => next.any((y) => y.sport == x.sport));
    final masters = p.level == 'beginner' || (p.age ?? 30) >= 50;
    if (same && !e.value.every((w) => w.sport == Sport.swim)) {
      r.add('L06 hard same sport on consecutive days', c, '${e.value.map(_w).join(' | ')} → ${next.map(_w).join(' | ')}');
    } else if (masters) {
      r.add('L06 hard days back-to-back (beginner/50+, other sport)', c, '${e.value.map(_w).join(' | ')} → ${next.map(_w).join(' | ')}');
    }
  }
  final keyDays = {
    for (final w in plan.where((w) => (w.isKey || _hardOrLong(w)) && w.intensity != 'race' && w.sport != Sport.gym)) dayOnly(w.date),
  };
  for (final d in keyDays) {
    if (keyDays.contains(addDays(d, 1)) && keyDays.contains(addDays(d, 2))) {
      r.add(
        'L07 key/long sessions on 3 consecutive days',
        c,
        [for (var k = 0; k < 3; k++) ...byDay[addDays(d, k)]!.where((w) => w.sport != Sport.gym).map(_w)].join(' | '),
      );
    }
  }
  // Long run before hard run the next day.
  for (final w in plan.where((w) => w.sport == Sport.run && w.intensity == 'long')) {
    final next = byDay[addDays(dayOnly(w.date), 1)] ?? const [];
    final h = next.where((x) => x.sport == Sport.run && _hard(x));
    if (h.isNotEmpty) r.add('L08 hard run the day after the long run', c, '${_w(w)} → ${h.map(_w).join(' | ')}');
  }

  // ── Gym ──
  for (final w in plan.where((w) => w.sport == Sport.gym)) {
    final t = plannedProgramOf(w, templates);
    if (t == null && w.exercises.isEmpty) {
      r.add('G01 gym workout without program/exercises', c, '${_w(w)} templateId=${w.templateId}');
      continue;
    }
    final ex = plannedGymExercises(w, t, gymGoal: a.gymGoal);
    if (ex.isEmpty) r.add('G01 gym workout with no exercises', c, _w(w));
    if (t != null && w.exercises.isNotEmpty) {
      for (final e in w.exercises) {
        final o = t.exercises.where((x) => x.exId == e.exId).firstOrNull;
        if (o != null && o.sets.where((s) => !s.warmup).length != e.sets.where((s) => !s.warmup).length) {
          r.add('G02 gym sets differ from the program', c, '${_w(w)} ${e.name}: ${e.sets.length} vs ${o.sets.length}');
        }
      }
    }
    if (t != null && w.durationMin > t.estimatedMinutes + 30) {
      r.add('G03 gym duration far above program estimate', c, '${_w(w)} vs ${t.estimatedMinutes}\'');
    }
  }
  if (a.gymAssign && a.gymPlanA.isNotEmpty) {
    final firstWeek = plan.map((w) => wk(w.date)).reduce(min);
    for (final w in plan.where((w) => w.sport == Sport.gym)) {
      final odd = (wk(w.date) - firstWeek).isOdd;
      final ref = (a.gymAB && odd ? a.gymPlanB[w.date.weekday] : null) ?? (a.gymAB && odd ? null : a.gymPlanA[w.date.weekday]);
      if (ref == null) continue;
      final t = gymProgramOf(ref, templates);
      if (t != null && w.templateId != t.id) {
        r.add('G04 assigned gym program not used', c, '${_w(w)} assigned $ref (${t.name}) week ${odd ? 'B' : 'A'}');
      }
    }
  }

  // ── Consistency of distance / duration / pace / steps ──
  final easy = PaceZones(Vdot.of(a) ?? Vdot.defaultFor(p.level)).easySlow;
  for (final w in plan.where((w) => w.sport != Sport.gym && w.steps.isNotEmpty && w.intensity != 'race')) {
    final sec = estimateStepsSec(w.steps, w.sport, p);
    // (Swims: the generator's swim novices use a slower CSS than [estimateStepsSec] – not compared.)
    if (w.sport == Sport.swim) continue;
    if (_brick(w) && w.durationMin > sec / 60 + 2) {
      r.add('C05 short brick run shown longer (15-min floor)', c, '${_w(w)} steps ${(sec / 60).toStringAsFixed(1)} min');
      continue;
    }
    if ((sec / 60 - w.durationMin).abs() > max(4, w.durationMin * 0.10)) {
      r.add('C01 steps total != workout duration (${w.sport.name})', c, '${_w(w)} steps ${(sec / 60).toStringAsFixed(1)}\'');
    }
    if (w.sport == Sport.run && w.distanceKm != null) {
      final m = w.steps.fold(0.0, (x, s) => x + (s.distanceM ?? timedRunStepM(s, easy)));
      if ((m / 1000 - w.distanceKm!).abs() > 0.3 + w.distanceKm! * 0.06) {
        r.add('C02 run distance != steps distance', c, '${_w(w)} steps ${(m / 1000).toStringAsFixed(2)} km');
      }
      final fast = w.steps.map((s) => s.zone == 'walk' ? walkPaceSecPerKm : (s.paceMin ?? easy)).reduce(min);
      final slow = w.steps.map((s) => s.zone == 'walk' ? walkPaceSecPerKm : (s.paceMax ?? easy)).reduce(max);
      final avg = w.durationMin * 60 / w.distanceKm!;
      if (avg < fast * 0.93 || avg > slow * 1.07) {
        r.add('C03 run avg pace outside step paces', c, '${_w(w)} avg ${avg.round()} s/km, steps $fast–$slow');
      }
    }
    if (w.sport == Sport.swim && w.distanceKm != null) {
      final m = w.steps.fold(0.0, (x, s) => x + (s.distanceM ?? 0));
      if (m > 0 && (m / 1000 - w.distanceKm!).abs() > 0.05 + w.distanceKm! * 0.03) {
        r.add('C02 swim distance != steps distance', c, '${_w(w)} steps ${m.round()} m');
      }
    }
  }
  // Title "N × M" matches the work steps.
  final nxm = RegExp(r'(\d+)\s*[×x]\s*(\d+(?:[.,]\d+)?)\s*(km|m|min|s|sec)\b');
  for (final w in plan.where((w) => w.sport != Sport.gym && w.intensity != 'race')) {
    final m = nxm.firstMatch(w.title);
    if (m == null) continue;
    // ("Endurance 12 × 200 m + 4 × 100 m CSS": the repeats of every "N × M" together – as plan_matrix_test 11a.)
    final n = nxm.allMatches(w.title).fold(0, (x, e) => x + int.parse(e.group(1)!));
    final work = w.steps.where((s) => s.kind == 'work' && s.zone != 'DR' && s.zone != 'walk').toList();
    if (work.length != n && w.steps.where((s) => s.kind == 'work').length != n) {
      r.add('C04 title N × M != work steps', c, '${_w(w)} has ${work.length} work steps');
    }
  }

  // ── Long sessions vs. race needs, feasibility silent ──
  if (spec != null && weeksToEvent != null && weeksToEvent >= spec.weeksFor(p.level).$1) {
    final pre = plan.where((w) => w.intensity != 'race');
    final misses = <String>[];
    if (plan.any((w) => w.sport == Sport.run) && spec.longRunKm != null) {
      final km = pre.where((w) => w.sport == Sport.run).fold(0.0, (x, w) => max(x, runningKm(w)));
      final mins = pre.where((w) => w.sport == Sport.run).fold(0, (x, w) => max(x, w.durationMin));
      if (km < spec.longRunKm! * 0.75 && (spec.longRunMin == null || mins < spec.longRunMin! * 0.75)) {
        misses.add('long run ${km.toStringAsFixed(1)} km < 75 % of ${spec.longRunKm}');
      }
    }
    if (plan.any((w) => w.sport == Sport.ride) && spec.longRideMin != null) {
      final mins = pre.where((w) => w.sport == Sport.ride).fold(0, (x, w) => max(x, w.durationMin));
      if (mins < spec.longRideMin! * 0.75) misses.add('long ride $mins\' < 75 % of ${spec.longRideMin}\'');
    }
    if (misses.isNotEmpty) {
      final f = PlanGenerator.feasibility(p, start: c.start, l: l);
      if (f.issues.where((i) => !i.startsWith('target')).isEmpty) {
        r.add('F06 long session far below race needs, feasibility silent', c, misses.join('; '));
      }
    }
  }
}

/// Feasibility: no exception, texts free of placeholders, and every suggested option resolves its issue.
void _checkFeasibility(_Case c, _Report r, AppLocalizations l) {
  final p = c.p;
  final a = p.athlete;
  if (a.eventDistance == null || a.eventDate == null) return;
  PlanFeasibility f;
  try {
    f = PlanGenerator.feasibility(p, start: c.start, l: l);
  } catch (e, st) {
    r.add('E02 feasibility throws', c, '$e @ ${st.toString().split('\n').take(3).join(' | ')}');
    return;
  }
  for (final i in f.issues) {
    String t;
    try {
      t = FeasibilityCard.issueText(l, f, i, canSwitch: true);
    } catch (e) {
      r.add('E03 feasibility text throws', c, '$i: $e');
      continue;
    }
    final m = _placeholder.firstMatch(t);
    if (m != null || t.trim().isEmpty) r.add('T03 feasibility text suspicious ($i)', c, t);
    if (RegExp(r'\b0 (km|min|m)\b|\b0 h\b').hasMatch(t) && FeasibilityCard.shownIssues(f).contains(i)) {
      r.add('T03 feasibility text with 0 values ($i)', c, t);
    }
  }
  final blocking = f.issues.where((i) => !PlanFeasibility.notes.contains(i) && !i.startsWith('target')).toSet();
  PlanFeasibility re(UserProfile q) => PlanGenerator.feasibility(q, start: c.start, l: l);
  // Raise the long day(s).
  if (f.raiseDay != null && f.raiseDayMin != null) {
    final dm = {
      ...a.dayMinutes,
      f.raiseDay!: f.raiseDayMin!,
      if (f.raiseDay2 != null && f.raiseDay2Min != null) f.raiseDay2!: f.raiseDay2Min!,
    };
    final f2 = re(p.copyWith(athlete: a.merge({'dayMinutes': dm})));
    final still = f2.issues.where((i) => i == 'longRunTime' || i == 'longRideTime').toList();
    if (still.isNotEmpty) {
      r.add(
        'F01 raising the day as suggested does not resolve',
        c,
        'raise ${_wd[f.raiseDay!]} to ${f.raiseDayMin}\'${f.raiseDay2 != null ? ' + ${_wd[f.raiseDay2!]} ${f.raiseDay2Min}\'' : ''}: ${f.issues} → ${f2.issues}',
      );
    }
  }
  if (f.moveDay != null && f.moveDayMin != null) {
    final f2 = re(p.copyWith(longDay: f.moveDay));
    final still = f2.issues.where((i) => i == 'longRunTime' || i == 'longRideTime').toList();
    if (still.isNotEmpty) {
      r.add(
        'F02 moving the long day as suggested does not resolve',
        c,
        'move to ${_wd[f.moveDay!]} (${f.moveDayMin}\'): ${f.issues} → ${f2.issues}',
      );
    }
  }
  if (f.laterDate != null) {
    final f2 = re(p.copyWith(athlete: a.merge({'eventDate': f.laterDate})));
    final timing = const {'tooShort', 'longRunRamp', 'runWalk', 'longRunFinish', 'longSwim'};
    final still = f2.issues.where(timing.contains).toList();
    if (still.isNotEmpty) r.add('F03 later date does not resolve', c, '${dayKey(f.laterDate!)}: ${f.issues} → ${f2.issues}');
    if (f.laterDate!.weekday != a.eventDate!.weekday) {
      r.add('F03 later date on another weekday', c, '${dayKey(f.laterDate!)} vs ${dayKey(a.eventDate!)}');
    }
  }
  if (f.shorterDistance != null) {
    final f2 = re(p.copyWith(athlete: a.merge({'eventDistance': f.shorterDistance, 'targetTimeSec': null})));
    final still = f2.issues.where((i) => !PlanFeasibility.notes.contains(i) && !i.startsWith('target')).toList();
    if (still.isNotEmpty) r.add('F04 shorter distance does not resolve', c, '${f.shorterDistance}: ${f.issues} → ${f2.issues}');
  }
  final t = f.target;
  if (t != null && f.issues.any((i) => i == 'targetAmbitious' || i == 'targetUnrealistic' || i == 'targetConservative')) {
    final f2 = re(p.copyWith(athlete: a.merge({'targetTimeSec': t.suggestedSec})));
    final still = f2.issues.where((i) => i.startsWith('target')).toList();
    if (still.isNotEmpty) {
      r.add('F05 suggested target time still flagged', c, '${clock(t.targetSec)} → ${clock(t.suggestedSec)}: ${f2.issues}');
    }
    if (t.laterDate != null) {
      final f3 = re(p.copyWith(athlete: a.merge({'eventDate': t.laterDate})));
      final s3 = f3.issues.where((i) => i == 'targetAmbitious' || i == 'targetUnrealistic').toList();
      if (s3.isNotEmpty) r.add('F05 target "later date" still flagged', c, '${dayKey(t.laterDate!)}: ${f3.issues}');
    }
  }
  if (blocking.isNotEmpty &&
      f.raiseDay == null &&
      f.moveDay == null &&
      f.laterDate == null &&
      f.shorterDistance == null &&
      !f.runWalkFinish) {
    r.add('F07 blocking issue without any option', c, '${f.issues}');
  }
}

String _dump(List<PlannedWorkout> plan, DateTime start) {
  final monday = startOfWeek(start);
  final b = StringBuffer();
  int? lastW;
  for (final w in plan) {
    final k = _days(w.date, monday) ~/ 7;
    if (k != lastW) b.writeln('── W${k + 1} ──');
    lastW = k;
    b.writeln('  ${_w(w)} key=${w.isKey}');
    if (Platform.environment['FUZZ_DESC'] != null) {
      b.writeln('     ${w.description.replaceAll('\n', ' ⏎ ')}');
      for (final s in w.steps) {
        b.writeln(
          '       ${s.kind} ${s.zone} ${s.durationSec ?? ''}s ${s.distanceM ?? ''}m p${s.paceMin}-${s.paceMax} w${s.powerMin}-${s.powerMax} hr${s.hrMin}-${s.hrMax} ${s.note}',
        );
      }
    }
  }
  return b.toString();
}

void main() => fuzzMain();

/// Invariants with known open violations (reported, not failed – see the file comment): multisport day plans
/// and long rides / swims (S05–S10, L01 ride, F01 / F02 / F07, T03), gym assignment (G04), weekly structure
/// (L02, L06, L07), and inputs outside the plausible range (V04: elite race times next to slow ones; C03: a
/// walker's 0.5 km brick rounding; L01 run: run/walk → running transitions of walkers).
const _open = [
  'C03', 'F01', 'F02', 'F07', 'G04', 'L01', 'L02', 'L06', 'L07', //
  'S05', 'S06', 'S07', 'S08', 'S09', 'S10', 'T03', 'V04',
];

/// Runs the fuzz test over cases [from] … [from] + [n] − 1 (default: FUZZ_FROM / FUZZ_N); with
/// FUZZ_RAW set, every violation is also written as a tab-separated line to `\$FUZZ_RAW.<from>.tsv`.
void fuzzMain({int? from, int? n}) {
  final env = Platform.environment;
  n ??= int.tryParse(env['FUZZ_N'] ?? '') ?? 80;
  from ??= int.tryParse(env['FUZZ_FROM'] ?? '') ?? 0;
  final seed = int.tryParse(env['FUZZ_SEED'] ?? '') ?? 20261116;
  final examples = int.tryParse(env['FUZZ_EX'] ?? '') ?? 4;
  final only = env['FUZZ_ONLY']?.split(',').map(int.parse).toList();
  final lde = lookupAppLocalizations(const Locale('de'));
  final len = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  test('plan fuzz', () {
    final sw = Stopwatch()..start();
    final r = _Report();
    final idx = only ?? [for (var i = from!; i < from + n!; i++) i];
    for (final i in idx) {
      final c = _randomCase(i, seed);
      final l = c.de ? lde : len;
      var seq = 0;
      String id() => 'w${seq++}';
      final templates = [
        ...defaultTemplates(id, de: c.de, goal: c.p.athlete.gymGoal),
        WorkoutTemplate(id: 'custom1', name: 'Mein Programm', sport: Sport.gym, exercises: defaultTemplates(id).first.exercises),
      ];
      List<PlannedWorkout> gen() {
        seq = 1000;
        return PlanGenerator(l, c.p, templates, id).generate(start: c.start, weeks: c.weeks);
      }

      List<PlannedWorkout> plan;
      try {
        plan = gen();
      } catch (e, st) {
        r.add('E01 generate throws', c, '$e @ ${st.toString().split('\n').take(3).join(' | ')}');
        continue;
      }
      if (only != null) print('#$i ${c.desc}\n${_dump(plan, c.start)}');
      try {
        _check(c, plan, r, l, templates);
      } catch (e, st) {
        r.add('E04 checker crashed', c, '$e @ ${st.toString().split('\n').take(4).join(' | ')}');
      }
      // Determinism.
      final again = gen();
      final m1 = plan.map((w) => w.toMap().toString()).toList(), m2 = again.map((w) => w.toMap().toString()).toList();
      if (m1.length != m2.length || [for (var k = 0; k < m1.length; k++) m1[k] == m2[k]].contains(false)) {
        final k =
            [
              for (var k = 0; k < min(m1.length, m2.length); k++)
                if (m1[k] != m2[k]) k,
            ].firstOrNull ??
            min(m1.length, m2.length);
        r.add(
          'D01 non-deterministic generate',
          c,
          'first difference at #$k: ${k < plan.length ? _w(plan[k]) : '-'} vs ${k < again.length ? _w(again[k]) : '-'}',
        );
      }
      // Replan one week later (PlanService.replacePlan from a later day): the race stays where it is.
      final a = c.p.athlete;
      if (a.eventDistance != null && a.eventDate != null && i % 3 == 0) {
        final later = addDays(c.start, 7);
        final w = GoalModel.weeksUntil(a.eventDate!, PlanGenerator.planStartFor(c.p, later));
        if (w >= 1 && w <= GoalModel.maxEventWeeks && !dayOnly(a.eventDate!).isBefore(PlanGenerator.planStartFor(c.p, later))) {
          try {
            final p2 = PlanGenerator(l, c.p, templates, id).generate(start: later, weeks: c.weeks);
            final race = p2.where((x) => x.intensity == 'race').toList();
            if (race.length != 1 || !sameDay(race.first.date, a.eventDate!)) {
              r.add('D02 replan a week later moves/loses the race', c, race.map(_w).join(' | '));
            }
            if (p2.any((x) => x.date.isBefore(later))) r.add('D02 replan contains days before its start', c, '');
          } catch (e) {
            r.add('D02 replan a week later throws', c, '$e');
          }
        }
      }
      _checkFeasibility(c, r, l);
      if (i % 250 == 0) print('… $i (${sw.elapsed.inSeconds} s)');
    }
    print(r.summary(idx.length, examples));
    final raw = env['FUZZ_RAW'];
    if (raw != null) {
      final b = StringBuffer();
      for (final e in r.v.entries) {
        for (final x in e.value) {
          b.writeln('${e.key}\t${x.replaceAll('\n', '\t')}');
        }
      }
      File('$raw.$from.tsv').writeAsStringSync(b.toString());
    }
    print('${idx.length} profiles in ${sw.elapsed.inSeconds} s');
    final failing = r.v.keys.where((k) => env['FUZZ_STRICT'] == '1' || !_open.any(k.startsWith)).toList()..sort();
    expect(failing, isEmpty, reason: r.summary(idx.length, examples));
  }, timeout: const Timeout(Duration(hours: 3)));
}
