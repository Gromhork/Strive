import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';

/// fix/plan-goal-progression – user report: "I can't run 30 min and prepare for a half marathon in
/// 12 weeks: the longest sessions are just over 30 min, long runs max ~5 km."
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'g${n++}';
  final start = DateTime(2026, 11, 9);
  DateTime race(int weeks) => DateTime(start.year, start.month, start.day + 7 * (weeks - 1) + 6);
  List<PlannedWorkout> gen(UserProfile p, {int? weeks}) => PlanGenerator(l, p, const [], id).generate(start: start, weeks: weeks);
  Iterable<PlannedWorkout> longRuns(List<PlannedWorkout> plan) => plan.where((w) => w.sport == Sport.run && w.intensity == 'long');
  double longestKm(List<PlannedWorkout> plan) => longRuns(plan).fold(0.0, (x, w) => max(x, w.distanceKm ?? 0));
  int longestMin(List<PlannedWorkout> plan) => longRuns(plan).fold(0, (x, w) => max(x, w.durationMin));

  UserProfile runner(String ev, int weeks, {bool can30 = false, String level = 'beginner'}) => UserProfile(
    level: level,
    focus: TrainingFocus.run,
    birthYear: 1990,
    trainingDays: const [2, 4, 6],
    athlete: AthleteData(sessionMinutes: 60, canRun30: can30, setupMode: 'advanced', eventDistance: ev, eventDate: race(weeks)),
  );

  group('HM in 12 weeks, cannot run 30 min (the user report)', () {
    final p = runner('hm', 12);
    final plan = gen(p);

    test('a long run/walk on the long day grows ~10 min a week, then long runs with walk breaks', () {
      final longs = longRuns(plan).where((w) => w.phase != 'taper').toList();
      expect(longs, isNotEmpty);
      // Before: every run was the same 30 min run/walk, the longest 3 km. After: ≥ 75 min, ≥ 7.5 km.
      expect(longestMin(plan), greaterThanOrEqualTo(75));
      expect(longestKm(plan), greaterThanOrEqualTo(7.5));
      for (var i = 1; i < longs.length; i++) {
        // (The first continuous long run builds on the run/walk's running km at ≤ +10 % / +1 km – review 2026-11 M1 –
        // so it may be a few minutes shorter than the last long run/walk.)
        expect(longs[i].durationMin, greaterThanOrEqualTo(longs[i - 1].durationMin - 5), reason: longs[i].title);
        expect(longs[i].durationMin, lessThanOrEqualTo(longs[i - 1].durationMin + 15), reason: longs[i].title);
      }
      // The first long session is a long run/walk (walk breaks from the start), not a continuous run.
      expect(longs.first.steps.first.zone, 'walk');
      // The continuous long run keeps Galloway walk breaks; race day shows the rhythm.
      final cont = longs.where((w) => w.title == l.planLongRun).toList();
      expect(cont, isNotEmpty);
      expect(cont.first.steps.where((s) => s.zone == 'walk'), isNotEmpty);
      expect(plan.firstWhere((w) => w.intensity == 'race').description, contains(l.wRaceRunWalk(10)));
    });

    test('Couch-to-5K pace (9 stages) instead of 11 when the goal needs it', () {
      final regular = plan.where((w) => w.sport == Sport.run && w.intensity == 'easy' && w.steps.first.zone == 'walk').toList();
      final titles = regular.map((w) => w.title).toSet();
      expect(titles, isNot(contains(l.wRunWalk(10, 1))));
      // The 30 min block without walk breaks is titled as a continuous run (plan review, MINOR).
      expect(titles, contains(l.wRunContinuous(30)));
    });

    test('feasibility warns at creation: too short, a later date that works, 10 km, run/walk finish', () {
      final f = PlanGenerator.feasibility(p, start: start, l: l);
      expect(f.issues, contains('tooShort'));
      expect(f.issues, isNot(contains('runWalkLong')));
      expect(f.laterDate, isNotNull);
      expect(f.shorterDistance, '10k');
      expect(f.runWalkFinish, isTrue);
      final later = p.copyWith(athlete: p.athlete.merge({'eventDate': f.laterDate}));
      final fl = PlanGenerator.feasibility(later, start: start, l: l);
      expect(fl.issues, isNot(contains('tooShort')));
      // Plan review C9 capped the long run at ≤ 50 % / ≤ 2 × the next run (~12 km with 3 × 60 min, then
      // "other runs need > 60 min"). Review r2 C6: three-run weeks follow the Galloway / Higdon novice plans
      // (≤ 65 %, ≤ 3.5 ×) – the later date now reaches the HM long run without a share warning.
      final lp = gen(later);
      // (13.5 km with walk breaks ≈ 2 h on the feet – the HM's time-on-feet long run.)
      expect(longestKm(lp), greaterThanOrEqualTo(13), reason: '${longestKm(lp)} km / ${longestMin(lp)} min');
      expect(fl.issues, isNot(contains('longRunShare')));
    });
  });

  test('beginner who can run 30 min, HM in 12 weeks: long run grows ~1–1.5 km a week to ≥ 12 km', () {
    final plan = gen(runner('hm', 12, can30: true));
    // Before: 5 → 9.5 km. After: 5 → 13 km, recovery weeks in between, ≤ +25 % per step.
    expect(longestKm(plan), greaterThanOrEqualTo(12));
    var best = 0.0;
    for (final w in longRuns(plan).where((w) => w.phase != 'recovery' && w.phase != 'taper')) {
      final km = w.distanceKm ?? 0;
      if (best > 0) expect(km, lessThanOrEqualTo(max(best * 1.1, min(best + 1.5, best * 1.25)) + 0.5));
      best = max(best, km);
    }
  });

  test('beginner 10 km in 8 weeks from run/walk: built as far as safe, warned with a later date', () {
    final p = runner('10k', 8);
    final f = PlanGenerator.feasibility(p, start: start, l: l);
    expect(f.issues, containsAll(['runWalk', 'tooShort']));
    expect(f.laterDate, isNotNull);
    expect(f.runWalkFinish, isTrue);
    expect(longestMin(gen(p)), greaterThanOrEqualTo(55));
  });

  test('marathon on run/walk is still not allowed', () {
    expect(PlanGenerator.feasibility(runner('m', 20), start: start, l: l).issues, contains('runWalkLong'));
  });

  test('swim beginner, olympic in 16 weeks: the continuous swim grows past 400 m to the race’s 800 m', () {
    final p = UserProfile(
      level: 'beginner',
      focus: TrainingFocus.triathlon,
      birthYear: 1990,
      experience: const {Sport.run, Sport.ride},
      trainingDays: const [1, 3, 5, 6, 7],
      athlete: AthleteData(sessionMinutes: 60, canSwim400: false, eventDistance: 'olympic', eventDate: race(16)),
    );
    final swims = gen(p).where((w) => w.sport == Sport.swim && w.phase != 'taper');
    final longest = swims.expand((w) => w.steps).where((s) => s.isWork && s.zone == 'EN').fold(0.0, (x, s) => max(x, s.distanceM ?? 0));
    // Before: 400 m (the end of the ladder) and a "longSwim" warning. After: 800 m, no warning.
    // Review 2026-11 C7: the target is what the race needs in one go (olympic ~1.2 km of the 1.5 km leg),
    // reached with up to +200 m a week – no longer the 800 m longest repeat.
    expect(longest, greaterThanOrEqualTo(1000));
    expect(swims.where((w) => w.title == l.wSwimContinuous(longest.round())), isNotEmpty);
    expect(PlanGenerator.feasibility(p, start: start, l: l).issues, isNot(contains('longSwim')));
  });

  group('plans without an event (general fitness / strength / hybrid)', () {
    for (final focus in [TrainingFocus.gym, TrainingFocus.hybrid, TrainingFocus.run]) {
      for (final weeks in PlanGenerator.supportedWeeks) {
        test('${focus.name} $weeks weeks: exactly that long, recovery weeks, no peak / taper / race', () {
          final p = UserProfile(
            level: 'intermediate',
            focus: focus,
            birthYear: 1990,
            experience: {...focus.sports},
            trainingDays: const [1, 3, 5, 6],
            athlete: AthleteData(planWeeks: weeks),
          );
          final phases = PlanGenerator.phasesFor(p, start: start, weeks: weeks);
          expect(phases, hasLength(weeks));
          expect(phases.where((x) => x == 'taper' || x == 'peak'), isEmpty);
          if (weeks >= 8) expect(phases, contains('recovery'));
          final plan = gen(p, weeks: weeks);
          expect(plan.where((w) => w.intensity == 'race'), isEmpty);
          final last = plan.map((w) => w.date).reduce((x, y) => x.isAfter(y) ? x : y);
          expect(last.difference(start).inDays ~/ 7, lessThan(weeks));
        });
      }
    }

    test('recommended length: beginners 8–12 (8), others 8–16 (12), events from the table', () {
      const beginner = UserProfile(level: 'beginner', focus: TrainingFocus.gym);
      expect(PlanGenerator.recommendedWeeks(beginner), (min: 8, max: 12, def: 8));
      expect(PlanGenerator.recommendedWeeks(beginner.copyWith(level: 'advanced')), (min: 8, max: 16, def: 12));
      // Beginner HM 16–18 weeks (review 2026-11 M1 / M3: the long run grows ≤ +10 % / +1 km a step).
      expect(PlanGenerator.recommendedWeeks(runner('hm', 12)).min, 16);
      for (final r in [PlanGenerator.recommendedWeeks(beginner), PlanGenerator.recommendedWeeks(beginner.copyWith(level: 'advanced'))]) {
        expect(PlanGenerator.supportedWeeks, contains(r.def));
      }
    });
  });
}
