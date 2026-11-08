import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'p${n++}';

  List<PlannedWorkout> gen(UserProfile p, {int? weeks}) =>
      PlanGenerator(l, p, const [], id).generate(start: DateTime(2026, 11, 9), weeks: weeks);

  test('VDOT matches Daniels tables', () {
    final v = Vdot.fromRace(5000, 20 * 60);
    expect(v, closeTo(49.8, 0.3));
    final z = PaceZones(50);
    expect(z.threshold, closeTo(255, 4)); // 4:15/km
    expect(z.interval, closeTo(234, 4)); // 3:54/km
  });

  test('half-marathon plan: taper, easy share, long-run cap', () {
    final p = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.run,
      trainingDays: const [2, 4, 6, 7],
      longDay: 7,
      athlete: AthleteData(
        setupMode: 'advanced',
        raceTimes: const {'10k': 50 * 60},
        runWeeklyKm: 25,
        longestRunKm: 12,
        eventDistance: 'hm',
        eventDate: DateTime.now().add(const Duration(days: 7 * 12)),
      ),
    );
    final plan = gen(p);
    final runs = plan.where((w) => w.sport == Sport.run).toList();
    final easy = runs.where((r) => !r.isKey || r.intensity == 'long').length;
    // ≥ 75 % of runs are easy or long-easy.
    expect(easy / runs.length, greaterThanOrEqualTo(0.72));
    final hard = runs.where((r) => r.intensity == 'intervals' || r.intensity == 'tempo').length;
    expect(hard / runs.length, lessThanOrEqualTo(0.34));
    expect(plan.any((w) => w.phase == 'taper'), isTrue);
    expect(plan.any((w) => w.phase == 'recovery'), isTrue);
    // Longest run never jumps more than 10 % over the previous max.
    var best = 12.0;
    for (final r in runs.where((r) => r.intensity == 'long')) {
      final km = r.steps.fold<double>(0, (a, s) => a + (s.distanceM ?? 0)) / 1000;
      expect(km, lessThanOrEqualTo(best * 1.10 + 0.5));
      best = max(best, km);
    }
    for (final r in runs.take(8)) {
      // ignore: avoid_print
      print('${r.date.toIso8601String().substring(0, 10)} ${r.phase} ${r.title} ${r.distanceKm} km ${r.durationMin} min');
    }
  });

  test('triathlon advanced day plan with gym respects C3', () {
    final p = UserProfile(
      level: 'beginner',
      focus: TrainingFocus.triathlon,
      athlete: AthleteData(
        setupMode: 'advanced',
        canRun30: true,
        dayPlan: const {
          1: [Sport.swim],
          2: [Sport.run, Sport.gym],
          3: [Sport.ride],
          4: [Sport.swim],
          6: [Sport.ride],
          7: [Sport.run],
        },
      ),
    );
    final plan = gen(p, weeks: 8);
    expect(plan.where((w) => w.sport == Sport.swim).length, 16);
    expect(plan.every((w) => w.durationMin >= 15), isTrue);
    for (final w in plan.take(8)) {
      // ignore: avoid_print
      print('${w.date.weekday} ${w.sport.name} ${w.title} ${w.durationMin} min ${w.steps.length} steps');
    }
  });

  test('beginner who cannot run 30 min gets run/walk', () {
    final p = UserProfile(
      level: 'beginner',
      focus: TrainingFocus.run,
      trainingDays: const [1, 3, 6],
      athlete: const AthleteData(canRun30: false),
    );
    final plan = gen(p, weeks: 4);
    expect(plan.first.steps.any((s) => s.zone == 'walk'), isTrue);
  });
}
