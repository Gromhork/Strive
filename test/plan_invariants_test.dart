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
        for (final event in [null, '5k', '10k', 'hm', 'm']) {
          if (event != null && !focus.sports.contains(Sport.run)) continue;
          final days = [
            [2, 4, 6],
            [1, 3, 5, 6],
            [1, 2, 4, 6, 7],
            [1, 2, 3, 4, 6, 7],
          ][rnd.nextInt(4)];
          final minutes = [45, 60, 90][rnd.nextInt(3)];
          profiles['$level/$diff/${focus.name}/$event/${days.length}d/${minutes}m'] = UserProfile(
            level: level,
            focus: focus,
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
          expect(runKm(p), lessThanOrEqualTo(long / 1.1 + 0.05), reason: '${e.key}: ${p.title} ${runKm(p)} km > long $long km on ${p.date}');
        }
        for (final p in w.where((p) => p.intensity == 'easy' && p.steps.length == 1)) {
          expect(runKm(p), lessThanOrEqualTo(max(3.0, long * 0.75) + 0.5), reason: '${e.key}: easy ${runKm(p)} vs long $long');
        }
      }
    }
  });

  test('sessions fit the time available', () {
    for (final e in profiles.entries) {
      final p = e.value;
      final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: 12);
      final perDay = <DateTime, int>{};
      for (final w in plan) {
        perDay[dayOnly(w.date)] = (perDay[dayOnly(w.date)] ?? 0) + 1;
      }
      for (final w in plan.where((w) => w.intensity != 'race')) {
        final cap = PlanGenerator.dayMinutesFor(p, w.date.weekday) ~/ perDay[dayOnly(w.date)]!;
        // Minimum session floors (3 km easy, 4 km long, 600 m swim) may exceed tiny caps.
        if (cap < 40) continue;
        expect(w.durationMin, lessThanOrEqualTo(cap + 10), reason: '${e.key}: ${w.title} ${w.durationMin} min > cap $cap');
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
}
