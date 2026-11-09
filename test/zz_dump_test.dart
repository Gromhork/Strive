import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  final profiles = {
    'tri': UserProfile(level: 'intermediate', focus: TrainingFocus.triathlon, athlete: AthleteData(setupMode: 'advanced', canRun30: true, eventDistance: 'olympic', eventDate: DateTime(2027, 3, 1), dayPlan: const {1: [Sport.swim], 2: [Sport.run, Sport.gym], 3: [Sport.ride], 4: [Sport.swim], 6: [Sport.ride], 7: [Sport.run]})),
    'hm': UserProfile(level: 'intermediate', focus: TrainingFocus.run, trainingDays: const [2, 4, 6, 7], longDay: 7, athlete: AthleteData(setupMode: 'advanced', raceTimes: const {'10k': 3000}, runWeeklyKm: 25, longestRunKm: 12, eventDistance: 'hm', eventDate: DateTime(2027, 2, 1))),
    'gym': UserProfile(level: 'advanced', focus: TrainingFocus.gym, trainingDays: const [1, 2, 4, 5], athlete: AthleteData(difficulty: 'challenging')),
    'hybrid': UserProfile(level: 'beginner', focus: TrainingFocus.hybrid, trainingDays: const [1, 3, 5, 6]),
  };
  for (final e in profiles.entries) {
    test(e.key, () {
      final plan = PlanGenerator(l, e.value, const [], () => 'p${n++}').generate(start: DateTime(2026, 11, 9), weeks: 8);
      final seen = <String>{};
      for (final w in plan) {
        final k = '${w.sport.name}|${w.title}|${w.phase}';
        if (!seen.add(k)) continue;
        // ignore: avoid_print
        print('=== ${e.key} ${w.date.toIso8601String().substring(0, 10)} ${w.sport.name} ${w.intensity} ${w.phase} "${w.title}" ${w.durationMin}min ${w.distanceKm}km\n${w.description}\n  steps: ${w.steps.map((s) => '${s.kind}/${s.zone}/${s.durationSec ?? ''}s${s.distanceM ?? ''}m ${s.note}').join(' | ')}');
      }
    });
  }
}
