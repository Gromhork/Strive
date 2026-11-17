import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/event_spec.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/schedule_advisor.dart';

/// Property-style checks of the plan generator over many athlete profiles.
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9);
  final templates = defaultTemplates(id, de: true);

  double runKm(PlannedWorkout p) =>
      p.steps.where((s) => s.zone != 'walk').fold<double>(0, (a, s) => a + (s.distanceM ?? 0)) / 1000 + (p.distanceKm ?? 0) * 0;

  // Profile matrix.
  final profiles = <String, UserProfile>{};
  final rnd = Random(7);
  for (final level in ['beginner', 'intermediate', 'advanced']) {
    for (final diff in ['easy', 'balanced', 'challenging']) {
      for (final focus in TrainingFocus.values) {
        for (final event in [null, '5k', '10k', 'hm', 'm', 'sprint', 'olympic', '70.3']) {
          if (event != null && !focus.sports.contains(Sport.run)) continue;
          if (const {'sprint', 'olympic', '70.3'}.contains(event) != (focus == TrainingFocus.triathlon && event != null)) continue;
          final days =
              [
                [2, 4, 6],
                [1, 3, 5, 6],
                [1, 2, 4, 6, 7],
                [1, 2, 3, 4, 6, 7],
                [1, 2, 3, 4, 5, 6, 7],
              ][rnd.nextInt(5)];
          final minutes = [45, 60, 90][rnd.nextInt(3)];
          final age = [25, 55, 70][rnd.nextInt(3)];
          final bmi = [22.0, 33.0][rnd.nextInt(2)];
          profiles['$level/$diff/${focus.name}/$event/${days.length}d/${minutes}m/${age}y/bmi${bmi.round()}'] = UserProfile(
            level: level,
            focus: focus,
            birthYear: DateTime.now().year - age,
            weightKg: bmi * 1.75 * 1.75,
            experience: rnd.nextBool() ? {...focus.sports} : const {},
            goals: rnd.nextBool() ? const ['strength'] : const ['endurance'],
            trainingDays: days,
            athlete: AthleteData(
              difficulty: diff,
              sessionMinutes: minutes,
              runWeeklyKm: level == 'advanced' ? 45 : null,
              eventDistance: event,
              eventDate: event == null ? null : start.add(Duration(days: 7 * (8 + rnd.nextInt(12)) + 6)),
              raceTimes: level == 'beginner' ? const {} : const {'10k': 48 * 60},
            ),
          );
        }
      }
    }
  }

  test('long run is the longest run of every week', () {
    for (final e in profiles.entries) {
      final plan = PlanGenerator(l, e.value, templates, id).generate(start: start, weeks: 12);
      final byWeek = <DateTime, List<PlannedWorkout>>{};
      for (final p in plan.where((p) => p.sport == Sport.run && p.intensity != 'race')) {
        byWeek.putIfAbsent(startOfWeek(p.date), () => []).add(p);
      }
      for (final w in byWeek.values) {
        final long = w.where((p) => p.intensity == 'long').map(runKm).fold<double>(0, max);
        if (long == 0) continue;
        for (final p in w.where((p) => p.intensity != 'long')) {
          expect(
            runKm(p),
            lessThanOrEqualTo(long / 1.1 + 0.05),
            reason: '${e.key}: ${p.title} ${runKm(p)} km > long $long km on ${p.date}',
          );
        }
        for (final p in w.where((p) => p.intensity == 'easy' && p.steps.length == 1)) {
          expect(runKm(p), lessThanOrEqualTo(max(3.0, long * 0.75) + 0.5), reason: '${e.key}: easy ${runKm(p)} vs long $long');
        }
      }
    }
  });

  // The sessions of a day share its time: scheduled double days split it evenly, a brick
  // run takes its minutes from the long ride – so the check is on the whole day.
  test('sessions fit the time available', () {
    for (final e in profiles.entries) {
      final p = e.value;
      final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 12);
      final perDay = <DateTime, List<PlannedWorkout>>{};
      for (final w in plan.where((w) => w.intensity != 'race')) {
        perDay.putIfAbsent(dayOnly(w.date), () => []).add(w);
      }
      for (final d in perDay.entries) {
        final cap = PlanGenerator.dayMinutesFor(p, d.key.weekday);
        final sum = d.value.fold<int>(0, (x, w) => x + w.durationMin);
        // Minimum session floors (3 km easy, 4 km long, 600 m swim) may exceed tiny caps.
        if (cap ~/ d.value.length < 40) continue;
        expect(sum, lessThanOrEqualTo(cap + 10), reason: '${e.key}: ${d.value.map((w) => w.title)} $sum min > cap $cap');
      }
    }
  });

  test('race day, shake-out and no strength in the last 3 days', () {
    for (final e in profiles.entries.where((e) => e.value.athlete.eventDistance != null)) {
      final plan = PlanGenerator(l, e.value, templates, id).generate(start: start);
      final race = dayOnly(e.value.athlete.eventDate!);
      final onRace = plan.where((p) => sameDay(p.date, race)).toList();
      expect(onRace.length, 1, reason: e.key);
      expect(onRace.single.intensity, 'race');
      expect(plan.where((p) => p.sport == Sport.gym && !p.date.isBefore(race.subtract(const Duration(days: 3)))), isEmpty, reason: e.key);
      expect(plan.where((p) => p.date.isAfter(race)), isEmpty, reason: e.key);
      // Race distance in km (not metres) and a sensible goal pace.
      final r = onRace.single;
      if (r.sport == Sport.run) {
        expect(r.distanceKm, lessThan(43), reason: e.key);
        final work = r.steps.where((s) => s.isWork).single;
        expect(work.distanceM, closeTo(r.distanceKm! * 1000, 1), reason: e.key);
        if (work.paceMin != null) expect(work.paceMin, inInclusiveRange(150, 600), reason: e.key);
      }
    }
  });

  test('no quality run the day after the long run (week wraps Sunday → Monday)', () {
    for (final e in profiles.entries.where((e) => e.value.level != 'advanced')) {
      final plan = PlanGenerator(l, e.value, templates, id).generate(start: start, weeks: 10);
      final longDays = {for (final p in plan.where((p) => p.sport == Sport.run && p.intensity == 'long')) dayOnly(p.date)};
      for (final p in plan.where((p) => p.sport == Sport.run && (p.intensity == 'tempo' || p.intensity == 'intervals'))) {
        expect(longDays.contains(dayOnly(p.date).subtract(const Duration(days: 1))), isFalse, reason: '${e.key}: ${p.title} on ${p.date}');
      }
    }
  });

  test('swim weeks mix technique, endurance and (non-beginners) CSS work', () {
    for (final e in profiles.entries) {
      final swims = PlanGenerator.deriveSchedule(e.value).values.expand((v) => v).where((s) => s == Sport.swim).length;
      if (swims < 2) continue;
      final plan = PlanGenerator(l, e.value, templates, id).generate(start: start, weeks: 6);
      final week = plan.where((p) => p.sport == Sport.swim && startOfWeek(p.date) == start).toList();
      final kinds = week.map((p) => p.intensity).toSet();
      expect(kinds.length, greaterThanOrEqualTo(2), reason: '${e.key}: ${week.map((p) => p.title)}');
      // CSS sets now count as (half) key sessions: masters (≥ 48 h between hard days) only
      // get one where it fits next to a long Z2 session.
      if (e.value.level != 'beginner' && (e.value.age ?? 30) < 50) expect(kinds, contains('intervals'), reason: e.key);
    }
  });

  test('at most one key session per day and no leg day before a key session', () {
    final legNames = templates.where((t) => legHeavyKeys.contains(t.key)).map((t) => t.name).toSet();
    for (final e in profiles.entries) {
      final plan = PlanGenerator(l, e.value, templates, id).generate(start: start, weeks: 10);
      final keyDays = <DateTime, int>{};
      for (final p in plan.where((p) => p.isKey && p.intensity != 'race')) {
        keyDays[dayOnly(p.date)] = (keyDays[dayOnly(p.date)] ?? 0) + 1;
      }
      expect(keyDays.values.every((v) => v <= 1), isTrue, reason: e.key);
      final gymPerWeek = PlanGenerator.deriveSchedule(e.value).values.expand((v) => v).where((s) => s == Sport.gym).length;
      if (gymPerWeek >= 4) {
        for (final g in plan.where((p) => p.sport == Sport.gym && legNames.contains(p.title))) {
          final next = dayOnly(g.date).add(const Duration(days: 1));
          expect(keyDays.containsKey(next), isFalse, reason: '${e.key}: ${g.title} on ${g.date} before key session');
        }
      }
    }
  });

  test('gym split follows the selected split', () {
    final p = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.gym,
      trainingDays: const [1, 2, 4, 5],
      athlete: const AthleteData(gymSplit: 'ppl'),
    );
    final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 2);
    expect(plan.take(4).map((w) => w.title).toList(), ['Push', 'Pull', 'Beine', 'Push']);
    final auto = PlanGenerator(l, p.copyWith(athlete: const AthleteData()), templates, id).generate(start: start, weeks: 1);
    expect(auto.map((w) => w.title).toList(), ['Oberkörper A', 'Unterkörper A', 'Oberkörper B', 'Unterkörper B']);
  });

  test('schedule advisor builds a sensible week', () {
    final p = UserProfile(level: 'intermediate', focus: TrainingFocus.triathlon, goals: const ['strength']);
    final adv = ScheduleAdvisor(p, {Sport.swim, Sport.ride, Sport.run, Sport.gym});
    final freq = adv.recommended();
    final plan = adv.autoSchedule(freq);
    expect(plan.length, lessThanOrEqualTo(6));
    for (final s in freq.keys) {
      expect(plan.values.where((v) => v.contains(s)).length, freq[s], reason: '$s');
    }
    expect(plan[6]!.first, Sport.ride); // long ride on Saturday
    expect(plan[5]?.contains(Sport.gym) ?? false, isFalse); // no gym the day before
  });

  test('built-in programs reference existing exercises with animations', () {
    final db = (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List).map((e) => e['id'] as String).toSet();
    for (final t in templates.where((t) => t.sport == Sport.gym)) {
      for (final e in t.exercises) {
        expect(db.contains(e.exId), isTrue, reason: '${t.name}: ${e.exId} ${e.name}');
        expect(File('assets/exercises/anim/${e.exId}.webp').existsSync(), isTrue, reason: 'anim ${e.exId}');
        expect(e.repMin! <= e.repMax!, isTrue);
      }
    }
    expect(templates.map((t) => t.key).toSet().length, templates.length);
  });

  // ───────────── Plan-wide training-science invariants (matrix audit) ─────────────

  // Plans of the whole matrix, generated once for the checks below.
  final plans = {for (final e in profiles.entries) e.key: PlanGenerator(l, e.value, templates, id).generate(start: start, weeks: 12)};
  bool hard(PlannedWorkout p) => p.intensity == 'tempo' || p.intensity == 'intervals';
  bool runWalk(PlannedWorkout p) => p.steps.any((s) => s.note == l.stepTalkPace);
  Map<DateTime, List<PlannedWorkout>> byWeek(List<PlannedWorkout> plan) {
    final m = <DateTime, List<PlannedWorkout>>{};
    for (final p in plan.where((p) => p.intensity != 'race')) {
      m.putIfAbsent(startOfWeek(p.date), () => []).add(p);
    }
    return m;
  }

  test('sane values, titles, descriptions and workout structure', () {
    for (final e in plans.entries) {
      final a = profiles[e.key]!.athlete;
      for (final w in e.value) {
        final tag = '${e.key}: ${w.title} ${w.date}';
        expect(w.title.trim(), isNotEmpty, reason: tag);
        expect(w.description.trim(), isNotEmpty, reason: tag);
        // (A brick run shows its own minutes – 10 min off the bike, audit FUZZ-5.)
        expect(w.durationMin, inInclusiveRange(w.intensity == 'moderate' ? 5 : 15, w.intensity == 'race' ? 720 : 240), reason: tag);
        if (w.distanceKm != null) expect(w.distanceKm!.isFinite && w.distanceKm! >= 0, isTrue, reason: tag);
        if (w.sport != Sport.gym && w.intensity != 'race') expect(w.steps, isNotEmpty, reason: tag);
        for (final s in w.steps) {
          expect((s.durationSec ?? 1) > 0 && (s.distanceM ?? 1) > 0, isTrue, reason: tag);
          if (s.paceMin != null) expect(s.paceMin! <= s.paceMax!, isTrue, reason: tag);
          if (s.hrMin != null) expect(s.hrMin! < s.hrMax! && s.hrMin! > 50 && s.hrMax! < 225, isTrue, reason: tag);
        }
        if (w.sport == Sport.run && hard(w)) {
          expect(w.steps.first.kind, 'warmup', reason: tag);
          expect(w.steps.last.kind, 'cooldown', reason: tag);
        }
        if (w.sport == Sport.run && a.raceTimes.isNotEmpty && w.intensity != 'race' && !runWalk(w)) {
          expect(w.steps.where((s) => s.zone != 'walk').every((s) => s.paceMin != null), isTrue, reason: tag);
        }
      }
    }
  });

  test('no back-to-back quality days (non-advanced, masters), never 3 key days in a row, H2 budget', () {
    for (final e in plans.entries) {
      final p = profiles[e.key]!;
      final masters = (p.age ?? 30) >= 50;
      bool endurance(PlannedWorkout w) => w.sport == Sport.run || w.sport == Sport.ride;
      final quality = {for (final w in e.value.where((w) => endurance(w) && hard(w))) dayOnly(w.date)};
      final keys = {for (final w in e.value.where((w) => endurance(w) && (hard(w) || w.intensity == 'long'))) dayOnly(w.date)};
      for (final d in quality) {
        final next = d.add(const Duration(days: 1)), prev = d.subtract(const Duration(days: 1));
        if (p.level != 'advanced' || masters) {
          expect(keys.contains(next) || keys.contains(prev), isFalse, reason: '${e.key}: quality on $d next to another key day');
        }
      }
      for (final d in keys) {
        final three = keys.contains(d.add(const Duration(days: 1))) && keys.contains(d.add(const Duration(days: 2)));
        expect(three, isFalse, reason: '${e.key}: three key days from $d');
      }
      for (final wk in byWeek(e.value).entries) {
        final n = wk.value.where((w) => w.sport != Sport.gym).length;
        final budget = n <= 4 ? 2 : (n <= 7 ? 3 : 4);
        final h = wk.value.where(hard).fold<double>(0, (x, w) => x + (w.sport == Sport.swim ? 0.5 : (w.sport == Sport.gym ? 0 : 1)));
        expect(h, lessThanOrEqualTo(budget), reason: '${e.key}: ${wk.key} $h hard sessions > $budget');
      }
    }
  });

  test('H2 across sports (long 0.5, quality 1, CSS 0.5) and H3: no key runs / rides on consecutive days', () {
    for (final e in plans.entries) {
      final p = profiles[e.key]!;
      final multi = p.focus.sports.where((s) => s != Sport.gym).length >= 2;
      for (final wk in byWeek(e.value).entries) {
        final w = wk.value;
        if (multi) {
          final n = w.where((x) => x.sport != Sport.gym && x.intensity != 'moderate').length;
          final budget = n <= 4 ? 2.0 : (n <= 7 ? 3.0 : 4.0);
          final points = w.fold<double>(
            0,
            (x, s) => x + (s.intensity == 'long' || (s.sport == Sport.swim && hard(s)) ? 0.5 : (hard(s) ? 1 : 0)),
          );
          expect(points, lessThanOrEqualTo(budget), reason: '${e.key}: ${wk.key} $points > $budget');
        }
        for (final sport in [Sport.run, Sport.ride]) {
          final keys = {for (final s in w.where((s) => s.sport == sport && s.isKey)) dayOnly(s.date)};
          for (final d in keys) {
            expect(keys.contains(d.add(const Duration(days: 1))), isFalse, reason: '${e.key}: ${sport.name} key days $d and the next');
          }
        }
      }
    }
  });

  test('taper is 1–3 weeks and at most a third of short plans – a plan within its taper (+1 week) of race day is taper only', () {
    for (final weeks in [3, 5, 6, 9, 14]) {
      for (final ev in ['5k', 'hm', 'm', 'olympic', '70.3']) {
        final p = UserProfile(
          level: 'intermediate',
          focus: ev.contains('.') || ev == 'olympic' ? TrainingFocus.triathlon : TrainingFocus.run,
          trainingDays: const [1, 2, 4, 6, 7],
          longDay: 7,
          athlete: AthleteData(eventDistance: ev, eventDate: start.add(Duration(days: 7 * weeks - 1))),
        );
        final plan = PlanGenerator(l, p, templates, id).generate(start: start);
        final taperWeeks = byWeek(plan.where((w) => w.phase == 'taper').toList()).length;
        expect(taperWeeks, inInclusiveRange(1, 3), reason: '$ev $weeks weeks');
        // (Anchored to race day, audit adapt-1: weeks ≤ the event's taper + 1 → that taper, else ≤ a third.)
        final full = EventSpec.of(ev)!.taperFor('intermediate');
        expect(
          taperWeeks,
          lessThanOrEqualTo(weeks <= full + 1 ? min(weeks, full) : max(1, weeks ~/ 3)),
          reason: '$ev $weeks weeks: $taperWeeks taper weeks',
        );
      }
    }
  });

  test('rest days: beginners ≥ 2 a week, athletes ≥ 60 at least 1', () {
    for (final e in plans.entries) {
      final p = profiles[e.key]!;
      final need = p.level == 'beginner' ? 2 : ((p.age ?? 30) >= 60 ? 1 : 0);
      for (final wk in byWeek(e.value).entries) {
        final days = wk.value.map((w) => dayOnly(w.date)).toSet().length;
        expect(7 - days, greaterThanOrEqualTo(need), reason: '${e.key}: ${wk.key}');
      }
    }
  });

  test('recovery weeks: masters ≤ 3 loading weeks (≥ 65: 2), and the volume really drops', () {
    for (final e in plans.entries) {
      final age = profiles[e.key]!.age ?? 30;
      final weeks = byWeek(e.value);
      final keys = weeks.keys.toList()..sort();
      var loading = 0;
      double? lastLoad;
      for (final k in keys) {
        final ws = weeks[k]!;
        final phases = ws.map((w) => w.phase).toSet();
        final minutes = ws.where((w) => w.sport != Sport.gym).fold<double>(0, (x, w) => x + w.durationMin);
        // Run/walk weeks (Couch-to-5K) have no recovery weeks – the 2:1 / 3:1 cycle starts
        // with continuous running.
        if (ws.any(runWalk)) {
          loading = 0;
          continue;
        }
        if (!phases.contains('recovery') && !phases.contains('taper')) {
          loading++;
          lastLoad = minutes;
          continue;
        }
        // Loading blocks before a recovery week (the block right before the taper or at the
        // end of the plan may be one week longer – no deload right before a taper).
        if (phases.contains('recovery') && age >= 50) expect(loading, lessThanOrEqualTo(age >= 65 ? 2 : 3), reason: '${e.key}: $k');
        // Above the minimum session lengths (3 km run, 40 min ride, 1 km swim) the deload
        // must show in the time spent – also when the athlete's time is the limit.
        if (phases.contains('recovery') && lastLoad != null && lastLoad >= 180 && !ws.any(runWalk)) {
          expect(minutes, lessThanOrEqualTo(lastLoad * 0.9), reason: '${e.key}: recovery $k $minutes vs $lastLoad');
        }
        loading = 0;
      }
    }
  });

  test('triathlon: every discipline with ≥ 3 days, 5 days → 2 runs, 6 days → 2/2/2', () {
    for (final days in [3, 4, 5, 6, 7]) {
      final p = UserProfile(level: 'intermediate', focus: TrainingFocus.triathlon, trainingDays: [1, 2, 3, 4, 5, 6, 7].take(days).toList());
      final s = PlanGenerator.deriveSchedule(p).values.expand((v) => v).toList();
      int n(Sport x) => s.where((y) => y == x).length;
      expect([n(Sport.swim), n(Sport.ride), n(Sport.run)].every((c) => c >= 1), isTrue, reason: '$days d: $s');
      if (days == 5) expect(n(Sport.run), 2);
      if (days == 6) expect([n(Sport.swim), n(Sport.ride), n(Sport.run)], [2, 2, 2]);
    }
  });

  test('run/walk: quick-setup beginners without running experience, one stage a week, no jump afterwards', () {
    final novice = UserProfile(level: 'beginner', focus: TrainingFocus.run, trainingDays: const [2, 4, 6]);
    final plan = PlanGenerator(l, novice, templates, id).generate(start: start, weeks: 16);
    final weeks = byWeek(plan);
    final keys = weeks.keys.toList()..sort();
    // Run/walk until 30 min continuous (11 stages plus repeated stages in recovery weeks).
    final rw = keys.takeWhile((k) => weeks[k]!.every(runWalk)).length;
    expect(rw, inInclusiveRange(11, 15));
    // R1: the first long run is at most ~10 % longer than the 30 min run before.
    final firstLong = plan.firstWhere((p) => p.intensity == 'long');
    expect(firstLong.distanceKm, lessThanOrEqualTo(30 * 60 / PlanGenerator(l, novice, templates, id).pz.easySlow * 1.1 + 0.5));
    // A returning runner gets continuous runs; with BMI ≥ 30 a shortened run/walk start.
    final returning = UserProfile(
      level: 'beginner',
      focus: TrainingFocus.run,
      trainingDays: const [2, 4, 6],
      experience: const {Sport.run},
    );
    expect(PlanGenerator(l, returning, templates, id).generate(start: start, weeks: 2).any(runWalk), isFalse);
    final heavy = returning.copyWith(weightKg: 105);
    expect(PlanGenerator.runWalkStartFor(heavy), 4);
    expect(PlanGenerator(l, heavy, templates, id).generate(start: start, weeks: 2).first.title, l.wRunWalk(3, 5));
  });

  test('quick setup: only the chosen training days, long session on the chosen long day', () {
    for (final e in profiles.entries) {
      for (final longDay in [null, ...e.value.trainingDays]) {
        final p = UserProfile.fromMap({...e.value.toMap(), 'longDay': longDay});
        final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 3);
        expect(plan, isNotEmpty, reason: e.key);
        // Race day and the shake-out the day before are fixed by the event date.
        final regular = plan.where((w) => w.intensity != 'race' && w.title != l.wShakeout);
        expect(regular.map((w) => w.date.weekday).toSet().difference(p.trainingDays.toSet()), isEmpty, reason: '${e.key} long $longDay');
        final want = PlanGenerator.longDayOf(p);
        if (longDay != null && p.focus != TrainingFocus.gym) expect(want, longDay, reason: e.key);
        for (final w in plan.where((w) => w.intensity == 'long')) {
          // One long session per sport: with run + ride the second one may sit on another day.
          if (p.focus.sports.where((s) => s != Sport.gym).length == 1) expect(w.date.weekday, want, reason: '${e.key} long $longDay');
        }
      }
    }
  });

  test('a day plan left over from the detailed setup is ignored in the quick setup', () {
    final p = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.run,
      trainingDays: const [1, 3, 5],
      athlete: const AthleteData(
        dayPlan: {
          2: [Sport.run],
          4: [Sport.run],
        },
      ),
    );
    final quick = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 2);
    expect(quick.map((w) => w.date.weekday).toSet(), {1, 3, 5});
    final detailed = p.copyWith(athlete: p.athlete.merge({'setupMode': 'advanced'}));
    expect(PlanGenerator(l, detailed, templates, id).generate(start: start, weeks: 2).map((w) => w.date.weekday).toSet(), {2, 4});
  });

  test('a stale long day (no longer a training day) behaves like "automatic"', () {
    for (final f in [TrainingFocus.run, TrainingFocus.hybrid, TrainingFocus.triathlon, TrainingFocus.duathlon]) {
      final auto = UserProfile(level: 'intermediate', focus: f, trainingDays: const [1, 3, 5, 6]);
      final stale = UserProfile.fromMap({...auto.toMap(), 'longDay': 7});
      String sig(List<PlannedWorkout> plan) => plan.map((w) => '${w.date.weekday}${w.sport.name}${w.intensity}').join(',');
      expect(
        sig(PlanGenerator(l, stale, templates, id).generate(start: start, weeks: 3)),
        sig(PlanGenerator(l, auto, templates, id).generate(start: start, weeks: 3)),
        reason: f.name,
      );
    }
  });

  test('strength goal with an endurance focus adds strength days (quick setup)', () {
    for (final (focus, days, gym) in [
      (TrainingFocus.run, [1, 3, 5], 1),
      (TrainingFocus.run, [1, 2, 3, 5, 6], 2),
      (TrainingFocus.ride, [2, 4], 0),
      (TrainingFocus.swim, [1, 2, 4, 6], 1),
      (TrainingFocus.triathlon, [1, 2, 3, 4, 6, 7], 1),
      (TrainingFocus.triathlon, [1, 3, 5, 6], 0),
    ]) {
      final p = UserProfile(level: 'intermediate', focus: focus, goals: const ['strength'], trainingDays: days);
      final week = PlanGenerator.deriveSchedule(p);
      expect(week.values.where((v) => v.contains(Sport.gym)).length, gym, reason: '$focus $days');
      expect(week.keys.toSet().difference(days.toSet()), isEmpty);
      // The main sport keeps the long day.
      expect(week[days.last]!.contains(Sport.gym), isFalse, reason: '$focus $days');
      if (gym > 0) expect(PlanGenerator.gymKeysFor(p), isNotEmpty);
    }
    // Beginner runner on run/walk: still ≤ 3 runs, strength on top.
    final novice = UserProfile(focus: TrainingFocus.run, goals: const ['muscle'], trainingDays: const [1, 2, 3, 4, 5]);
    final week = PlanGenerator.deriveSchedule(novice).values.expand((v) => v);
    expect(week.where((s) => s == Sport.run).length, lessThanOrEqualTo(3));
    expect(week.where((s) => s == Sport.gym).length, 2);
  });

  test('a plan that starts mid-week does not stuff the whole weekly volume into the rest of the week', () {
    for (final level in ['intermediate', 'advanced']) {
      final p = UserProfile(
        level: level,
        focus: TrainingFocus.run,
        trainingDays: const [1, 2, 3, 4, 5, 6, 7],
        athlete: const AthleteData(runWeeklyKm: 40, sessionMinutes: 120),
      );
      final plan = PlanGenerator(l, p, templates, id).generate(start: start.add(const Duration(days: 3)), weeks: 3);
      double km(Iterable<PlannedWorkout> w) => w.fold(0, (x, p) => x + runKm(p));
      final first = plan.where((w) => startOfWeek(w.date) == start);
      final second = plan.where((w) => startOfWeek(w.date) == start.add(const Duration(days: 7)));
      expect(km(first), lessThan(km(second)), reason: level);
      final easyFirst = first.where((w) => w.intensity == 'easy').map(runKm).fold<double>(0, max);
      final easySecond = second.where((w) => w.intensity == 'easy').map(runKm).fold<double>(0, max);
      expect(easyFirst, lessThanOrEqualTo(easySecond * 1.15 + 0.5), reason: '$level: easy run $easyFirst vs $easySecond km');
    }
  });

  group('health limitations', () {
    UserProfile withLimits(UserProfile p, List<String> lim) => p.copyWith(athlete: p.athlete.merge({'limitations': lim}));
    double km(List<PlannedWorkout> plan) =>
        plan.where((w) => w.sport == Sport.run && w.intensity != 'race').fold(0, (x, w) => x + runKm(w));
    bool zone(PlannedWorkout w, Set<String> z) => w.steps.any((s) => z.contains(s.zone));

    test('knee / hip / ankle: less running impact, no strides or VO2max reps, ≤ 1 quality run, one run → ride', () {
      for (final lim in ['knee', 'hip', 'ankle']) {
        for (final e in profiles.entries.where((e) => e.value.focus.sports.contains(Sport.run))) {
          final p = withLimits(e.value, [lim]);
          final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 12);
          final base = plans[e.key]!;
          final tag = '$lim ${e.key}';
          for (final w in plan.where((w) => w.sport == Sport.run && w.intensity != 'race')) {
            expect(zone(w, {'I', 'R'}), isFalse, reason: '$tag: ${w.title}');
            expect(w.description.split('\n'), contains(l.healthRunNote), reason: tag);
          }
          for (final wk in byWeek(plan).values) {
            expect(wk.where((w) => w.sport == Sport.run && hard(w)).length, lessThanOrEqualTo(1), reason: tag);
          }
          // Total run km: ~10 % less where the weekly volume decides; long runs limited by R1
          // and threshold work instead of VO2max reps may keep it about level.
          expect(km(plan), lessThanOrEqualTo(km(base) * 1.03 + 0.5), reason: '$tag: run km ${km(plan)} > ${km(base)}');
          // ≥ 3 continuous runs a week → one of them is an easy ride.
          final runsPerWeek = PlanGenerator.scheduleOf(p).values.expand((v) => v).where((s) => s == Sport.run).length;
          if (runsPerWeek >= 3 && PlanGenerator.runWalkStartFor(p) == null) {
            expect(plan.where((w) => w.title == l.wCrossRide), isNotEmpty, reason: tag);
          }
        }
      }
    });

    test('shoulder: swim technique instead of CSS sets, less swim volume, note on every swim', () {
      for (final e in profiles.entries.where((e) => e.value.focus.sports.contains(Sport.swim))) {
        final plan = PlanGenerator(l, withLimits(e.value, ['shoulder']), templates, id).generate(start: start, weeks: 12);
        final swims = plan.where((w) => w.sport == Sport.swim && w.intensity != 'race').toList();
        expect(swims, isNotEmpty);
        for (final w in swims) {
          expect(zone(w, {'CSS', 'SP'}), isFalse, reason: '${e.key}: ${w.title}');
          expect(w.description.split('\n'), contains(l.healthSwimShoulderNote));
        }
        double m(Iterable<PlannedWorkout> x) => x.fold(0, (a, w) => a + w.steps.fold<double>(0, (b, s) => b + (s.distanceM ?? 0)));
        final before = m(plans[e.key]!.where((w) => w.sport == Sport.swim && w.intensity != 'race'));
        expect(m(swims), lessThanOrEqualTo(before + 1), reason: e.key);
      }
    });

    test('heart / blood pressure: nothing above threshold (no I/R runs, no VO2 rides)', () {
      for (final e in profiles.entries.where((e) => e.value.focus != TrainingFocus.gym)) {
        final plan = PlanGenerator(l, withLimits(e.value, ['heart']), templates, id).generate(start: start, weeks: 12);
        for (final w in plan.where((w) => w.intensity != 'race')) {
          expect(zone(w, {'I', 'R', 'Z5', 'Z6', 'Z7', 'SP'}), isFalse, reason: '${e.key}: ${w.title}');
          if ((w.sport == Sport.run || w.sport == Sport.ride) && hard(w)) expect(w.description.split('\n'), contains(l.healthHeartNote));
        }
      }
    });

    test('back / shoulder / heart: strength sessions keep their programs and get a note', () {
      for (final e in profiles.entries.where((e) => e.value.focus.sports.contains(Sport.gym))) {
        final limited = withLimits(e.value, ['back', 'shoulder', 'heart', 'knee']);
        final plan = PlanGenerator(l, limited, templates, id).generate(start: start, weeks: 4);
        final base = PlanGenerator(l, e.value, templates, id).generate(start: start, weeks: 4);
        final gym = plan.where((w) => w.sport == Sport.gym).toList();
        expect(gym.map((w) => w.title).toList(), base.where((w) => w.sport == Sport.gym).map((w) => w.title).toList(), reason: e.key);
        for (final w in gym) {
          final lines = w.description.split('\n');
          expect(lines, containsAll([l.healthGymBackNote, l.healthGymShoulderNote, l.healthGymHeartNote, l.healthGymJointNote]));
        }
      }
    });

    test('limitations keep the general invariants: time caps, rest days, sane values', () {
      for (final e in profiles.entries) {
        final p = withLimits(e.value, const ['knee', 'shoulder', 'heart']);
        final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 8);
        final perDay = <DateTime, List<PlannedWorkout>>{};
        for (final w in plan.where((w) => w.intensity != 'race')) {
          expect(w.durationMin, inInclusiveRange(w.intensity == 'moderate' ? 5 : 15, 240), reason: '${e.key}: ${w.title}');
          perDay.putIfAbsent(dayOnly(w.date), () => []).add(w);
        }
        for (final d in perDay.entries) {
          final cap = PlanGenerator.dayMinutesFor(p, d.key.weekday);
          final sum = d.value.fold<int>(0, (x, w) => x + w.durationMin);
          if (cap ~/ d.value.length >= 40) expect(sum, lessThanOrEqualTo(cap + 10), reason: '${e.key}: ${d.value.map((w) => w.title)}');
        }
        final need = p.level == 'beginner' ? 2 : ((p.age ?? 30) >= 60 ? 1 : 0);
        for (final wk in byWeek(plan).entries) {
          expect(7 - wk.value.map((w) => dayOnly(w.date)).toSet().length, greaterThanOrEqualTo(need), reason: '${e.key}: ${wk.key}');
        }
      }
    });

    test('beginners with joint problems start with run/walk', () {
      final p = UserProfile(focus: TrainingFocus.run, experience: const {Sport.run}, athlete: const AthleteData(limitations: ['knee']));
      expect(PlanGenerator.runWalkStartFor(p), 4);
      expect(PlanGenerator.runWalkStartFor(p.copyWith(athlete: const AthleteData())), isNull);
    });
  });

  test('sex: predicted HRmax uses Gulati for women, Tanaka otherwise; measured HRmax wins', () {
    final year = DateTime.now().year;
    expect(UserProfile(gender: 'f', birthYear: year - 50).estimatedMaxHr, 162);
    expect(UserProfile(gender: 'm', birthYear: year - 50).estimatedMaxHr, 173);
    expect(UserProfile(gender: 'd', birthYear: year - 50).estimatedMaxHr, 173);
    expect(UserProfile.fromMap({'gender': 'f', 'birthYear': year - 50, 'maxHr': 181}).estimatedMaxHr, 181);
    // The plan's heart-rate targets follow.
    final f = PlanGenerator(l, UserProfile(gender: 'f', birthYear: year - 50, focus: TrainingFocus.run), templates, id);
    final m = PlanGenerator(l, UserProfile(gender: 'm', birthYear: year - 50, focus: TrainingFocus.run), templates, id);
    expect(f.hz.zone(2).$2, lessThan(m.hz.zone(2).$2));
  });

  test('goal-specific volume: HM long run ≥ 14 km, olympic long ride ≥ 90 min, realistic race durations', () {
    UserProfile goal(TrainingFocus f, String event, List<int> days, int weeks) => UserProfile(
      level: 'intermediate',
      focus: f,
      trainingDays: days,
      longDay: days.last,
      athlete: AthleteData(sessionMinutes: 90, eventDistance: event, eventDate: start.add(Duration(days: 7 * (weeks - 1) + 6))),
    );
    final hm = PlanGenerator(l, goal(TrainingFocus.run, 'hm', const [2, 4, 6, 7], 14), templates, id).generate(start: start);
    expect(hm.where((p) => p.intensity == 'long').map((p) => p.distanceKm!).reduce(max), greaterThanOrEqualTo(14));
    final tri = PlanGenerator(
      l,
      goal(TrainingFocus.triathlon, 'olympic', const [1, 2, 3, 4, 6, 7], 16),
      templates,
      id,
    ).generate(start: start);
    final longRide = tri.where((p) => p.sport == Sport.ride && p.intensity == 'long').map((p) => p.durationMin).reduce(max);
    expect(longRide, greaterThanOrEqualTo(90));
    expect(tri.firstWhere((p) => p.intensity == 'race').durationMin, inInclusiveRange(120, 240));
    final m = PlanGenerator(l, goal(TrainingFocus.run, 'm', const [2, 4, 6, 7], 18), templates, id).generate(start: start);
    expect(m.firstWhere((p) => p.intensity == 'race').durationMin, greaterThan(180));
  });
}
