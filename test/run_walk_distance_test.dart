import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/progression_check.dart';
import 'package:strive/services/session_checks.dart';
import 'package:strive/services/zones.dart';
import 'package:strive/widgets/plan_amount.dart';

/// Run/walk sessions (beginners who cannot run 30 min, Couch-to-5K ladder): the distance is the
/// running at the easy pace plus the walking at the walking pace – QA 2026-11: "Laufen/Gehen 8 × 1 min"
/// read "29 min · 1.0 km" (29:00 /km: only the 8 running minutes were counted).
final _start = DateTime(2026, 11, 9); // Monday

UserProfile _beginner(String ev, int weeks) => UserProfile(
  level: 'beginner',
  focus: TrainingFocus.run,
  birthYear: 1990,
  experience: const {},
  trainingDays: const [2, 4, 6],
  goals: const ['race'],
  athlete: AthleteData(
    setupMode: 'advanced',
    canRun30: false,
    sessionMinutes: 60,
    eventDistance: ev,
    eventDate: DateTime(_start.year, _start.month, _start.day + 7 * (weeks - 1) + 6),
  ),
);

double _pace(int minutes, double km) => minutes / km; // min/km

void main() {
  final l = lookupAppLocalizations(const Locale('de'));

  for (final (ev, weeks) in const [('5k', 10), ('10k', 12), ('hm', 16)]) {
    test('$ev beginner run/walk: distance includes the walks, the same on every screen', () {
      final p = _beginner(ev, weeks);
      expect(PlanGenerator.runWalkStartFor(p), 0);
      final plan = PlanGenerator(l, p, const [], () => 'x').generate(start: _start);
      final rw = plan.where(isRunWalk).toList();
      expect(rw, isNotEmpty);
      for (final w in rw) {
        final km = w.distanceKm!;
        final what = '${w.date} ${w.title}: ${w.durationMin} min · $km km';
        // Run/walk with brisk walks: ~8–10.5 min/km overall (never the 15–29 min/km of the running alone).
        expect(_pace(w.durationMin, km), inInclusiveRange(7.5, 10.5), reason: what);
        // Session card / editor ([planAmount]), "mark as done" ([PlanFill]) and the compliance reference agree.
        final a = planAmount(w, p);
        expect(a.km, km, reason: what);
        expect(a.minutes, w.durationMin, reason: what);
        final fill = PlanFill.of(w, profile: p);
        expect(fill.km, km, reason: what);
        expect(plannedReference(w, profile: p), (km, w.durationMin), reason: what);
        // The filled-in session passes the edit page's pace check.
        expect(SessionCheck.paceIsPlausible(Sport.run, fill.minutes * 60, fill.km! * 1000), isTrue, reason: what);
        // The running alone stays the plan's running km (progression rules).
        expect(runningKm(w), lessThan(km), reason: what);
      }
    });
  }

  test('week 1 "8 × 1 min": 29 min ≈ 3.2 km (1 km running + 2.2 km walking), not 1.0 km', () {
    final p = _beginner('hm', 16);
    final plan = PlanGenerator(l, p, const [], () => 'x').generate(start: _start);
    final first = plan.firstWhere((w) => w.sport == Sport.run);
    expect(first.title, l.wRunWalk(8, 1));
    expect(first.durationMin, 29);
    // 8 min at the easy pace (~1 km) + 21 min of walking at 9:30 /km (2.2 km).
    expect(first.distanceKm, closeTo(3.2, 0.3));
    expect(runningKm(first), closeTo(1.0, 0.2));
  });

  test('walk steps count at the walking pace (steps distance and step duration)', () {
    const walk = WorkoutStep(kind: 'recovery', durationSec: 570, zone: 'walk');
    const run = WorkoutStep(kind: 'work', durationSec: 600, zone: 'E', paceMin: 360, paceMax: 360);
    expect(timedRunStepM(walk, 400), closeTo(1000, 0.1));
    expect(timedRunStepM(run, 400), closeTo(1666.7, 0.1));
    const p = UserProfile(level: 'beginner');
    expect(stepsKm(const [walk, run], Sport.run, p), 2.7);
    // A walk given by distance takes walking time.
    expect(estimateStepSec(const WorkoutStep(kind: 'recovery', distanceM: 1000, zone: 'walk'), Sport.run, easyPace: 400, css: 100), 570);
  });

  test('pace check: back to 20:00 /km as the slowest plausible run', () {
    expect(SessionCheck.paceIsPlausible(Sport.run, 29 * 60, 3200), isTrue); // run/walk 9:04 /km
    expect(SessionCheck.paceIsPlausible(Sport.run, 15 * 60, 1000), isTrue); // slow walk
    expect(SessionCheck.paceIsPlausible(Sport.run, 29 * 60, 1000), isFalse); // the old run/walk bug
    expect(SessionCheck.paceIsPlausible(Sport.run, 21 * 60, 1000), isFalse);
  });
}
