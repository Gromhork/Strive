import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/l10n/relocalize.dart';
import 'package:strive/services/plan_generator.dart';

void main() {
  UserProfile profile() => UserProfile(
    level: 'intermediate',
    focus: TrainingFocus.triathlon,
    trainingDays: const [1, 2, 3, 4, 5, 6, 7],
    longDay: 7,
    athlete: AthleteData(setupMode: 'advanced', raceTimes: const {'10k': 50 * 60}, runWeeklyKm: 25, longestRunKm: 12),
  );

  List<PlannedWorkout> gen(String lang) {
    var n = 0;
    final de = lang == 'de';
    final templates = defaultTemplates(() => 't${n++}', de: de);
    final hybrid = UserProfile(level: 'intermediate', focus: TrainingFocus.hybrid, trainingDays: const [1, 2, 3, 5, 6, 7], longDay: 6);
    return [
      for (final p in [profile(), hybrid])
        ...PlanGenerator(
          lookupAppLocalizations(Locale(lang)),
          p,
          templates,
          () => 'p${n++}',
        ).generate(start: DateTime(2026, 11, 9), weeks: 6),
    ];
  }

  PlannedWorkout apply(PlannedWorkout p, Map<String, dynamic> m) => PlannedWorkout.fromMap(p.id, {...p.toMap(), ...m});

  for (final (from, to) in [('de', 'en'), ('en', 'de')]) {
    test('generated plan texts translate $from → $to', () {
      final src = gen(from), want = gen(to);
      expect(src.length, want.length);
      final r = Relocalizer.to(to);
      var missed = <String>[];
      for (var i = 0; i < src.length; i++) {
        final got = apply(src[i], r.plan(src[i]));
        if (got.title != want[i].title) missed.add('title: ${src[i].title} → ${got.title} (want ${want[i].title})');
        if (got.description != want[i].description) missed.add('desc: ${got.description} (want ${want[i].description})');
        for (var j = 0; j < got.steps.length; j++) {
          if (got.steps[j].note != want[i].steps[j].note) missed.add('step: ${got.steps[j].note} (want ${want[i].steps[j].note})');
        }
      }
      missed = missed.toSet().toList();
      expect(missed, isEmpty, reason: missed.take(15).join('\n'));
    });
  }

  test('built-in programs and folders translate, user text stays', () {
    var n = 0;
    final de = defaultTemplates(() => 't${n++}', de: true), en = defaultTemplates(() => 't${n++}', de: false);
    final r = Relocalizer.to('en', programs: true);
    for (var i = 0; i < de.length; i++) {
      final m = r.template(de[i]);
      expect(m['name'] ?? de[i].name, en[i].name);
      expect(m['folder'] ?? de[i].folder, en[i].folder);
      expect(m['description'] ?? de[i].description, en[i].description);
    }
    expect(r.text('Mein Lieblingslauf am See'), 'Mein Lieblingslauf am See');
    expect(Relocalizer.to('de').text('Push'), 'Push');
  });
}
