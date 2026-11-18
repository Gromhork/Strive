import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/step_text.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/step_progress.dart';
import 'package:strive/services/tracker.dart';

/// CSS swim set like the plan generator builds it: warm-up, drills, 4 × 100 m with 15 s rest, cool-down.
const cssSet = [
  WorkoutStep(kind: 'warmup', distanceM: 200, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 200, zone: 'DR'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105),
  WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105),
  WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105),
  WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105),
  WorkoutStep(kind: 'cooldown', distanceM: 100, zone: 'REC'),
];

/// Paused state so `elapsed` is fully controlled by `accumulatedSec`.
CardioState pool(List<WorkoutStep> steps, {int poolLength = 25}) =>
    CardioState(sport: Sport.swim, title: 't', start: DateTime(2026), indoor: true, poolLengthM: poolLength, steps: steps);

CardioState at(CardioState s, int sec) => s.copyWith(accumulatedSec: sec);

/// Swims [n] lengths of [secEach] seconds each.
CardioState swim(CardioState s, int n, {int secEach = 25}) {
  for (var i = 0; i < n; i++) {
    s = at(s, s.elapsed + secEach).addLength();
  }
  return s;
}

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));
  const u = Units(false);

  group('repInfo', () {
    test('counts repeats inside a work/rest block', () {
      expect(repInfo(cssSet, 2), (rep: 1, reps: 4));
      expect(repInfo(cssSet, 6), (rep: 3, reps: 4));
      expect(repInfo(cssSet, 8), (rep: 4, reps: 4));
      // Rest belongs to the preceding repetition.
      expect(repInfo(cssSet, 5), (rep: 2, reps: 4));
      // Single steps are not repeats.
      expect(repInfo(cssSet, 0), isNull);
      expect(repInfo(cssSet, 1), isNull);
      expect(repInfo(cssSet, 9), isNull);
    });

    test('swim titles use the set counter, drills and rests get their own names', () {
      expect(stepTitle(de, cssSet, 1, sport: Sport.swim), 'Technik');
      expect(stepTitle(de, cssSet, 4, sport: Sport.swim), 'Intervall 2/4');
      expect(stepTitle(de, cssSet, 4, sport: Sport.swim, spoken: true), 'Intervall 2 von 4');
      expect(stepTitle(de, cssSet, 3, sport: Sport.swim), 'Pause');
      expect(stepSetLabel(en, cssSet, 4, u, Sport.swim), '4 × 100 m · CSS pace');
    });
  });

  group('pool lengths', () {
    test('lengths add distance and auto-advance distance steps', () {
      var s = pool(cssSet);
      s = swim(s, 7);
      expect(s.stepIndex, 0); // 175 of 200 m warm-up
      expect(s.lengthsLeft, 1);
      s = swim(s, 1);
      expect(s.stepIndex, 1); // drills
      expect(s.effectiveDistance, 200);
      s = swim(s, 8);
      expect(s.stepIndex, 2); // first 100 m CSS
      s = swim(s, 4);
      expect(s.stepIndex, 3); // rest
      expect(s.step!.durationSec, 15);
    });

    test('timed rest completes after its duration and restarts the length clock', () {
      var s = swim(pool(cssSet), 20); // through warm-up, drills and the first 100 m
      expect(s.stepIndex, 3);
      final restStart = s.elapsed;
      s = at(s, restStart + 14);
      expect(s.stepComplete, isFalse);
      expect(s.stepRemaining.$2, 1);
      s = at(s, restStart + 15);
      expect(s.stepComplete, isTrue);
      s = s.advanceStep();
      expect(s.stepIndex, 4);
      expect(s.lastLengthAt, restStart + 15);
      // The next length is timed from the end of the rest, not from the last wall touch.
      s = at(s, s.elapsed + 24).addLength();
      expect(s.lengthSecs.last, 24);
    });

    test('a length tapped during a rest ends the rest early and counts', () {
      var s = swim(pool(cssSet), 20);
      expect(s.stepIndex, 3);
      s = swim(s, 1, secEach: 30);
      expect(s.stepIndex, 4);
      expect(s.stepLengths, 1);
      expect(s.lengthSecs.last, 30);
    });

    test('33 m pool: 3 lengths make 100 m', () {
      const steps = [
        WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS'),
        WorkoutStep(kind: 'recovery', durationSec: 20, zone: 'REC'),
        WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS'),
      ];
      var s = swim(pool(steps, poolLength: 33), 2);
      expect(s.stepIndex, 0);
      expect(s.lengthsLeft, 1);
      s = swim(s, 1);
      expect(s.stepIndex, 1);
      expect(s.effectiveDistance, closeTo(100, 0.01));
    });

    test('50 m pool: odd distances round to the nearest wall', () {
      const steps = [WorkoutStep(kind: 'work', distanceM: 75, zone: 'EN'), WorkoutStep(kind: 'cooldown', distanceM: 100, zone: 'REC')];
      var s = swim(pool(steps, poolLength: 50), 1);
      expect(s.stepIndex, 0);
      s = swim(s, 1);
      expect(s.stepIndex, 1);
    });

    test('undo removes the length and reverts an auto-advance', () {
      var s = swim(pool(cssSet), 7);
      final before = s;
      s = swim(s, 1);
      expect(s.stepIndex, 1);
      s = s.undoLength();
      expect(s.laps, 7);
      expect(s.stepIndex, 0);
      expect(s.stepStartDist, before.stepStartDist);
      expect(s.lengthSecs.length, 7);
      expect(s.lastLengthAt, before.lastLengthAt);
      // Undo at zero does nothing.
      expect(pool(cssSet).undoLength().laps, 0);
    });

    test('last step completes the workout; undo brings it back', () {
      const steps = [WorkoutStep(kind: 'work', distanceM: 50, zone: 'EN')];
      var s = swim(pool(steps), 2);
      expect(s.stepsDone, isTrue);
      expect(s.step, isNull);
      s = s.undoLength();
      expect(s.stepsDone, isFalse);
      expect(s.stepIndex, 0);
    });

    test('swim pace per 100 m and pace status against the CSS target', () {
      var s = swim(pool(cssSet), 20, secEach: 25); // 25 s per 25 m = 1:40 /100 m
      expect(s.swimPace100, 100);
      expect(s.avgSwimPace100, 100);
      s = s.advanceStep(); // skip rest → 100 m CSS (target 1:40–1:45)
      s = swim(s, 2, secEach: 30); // 2:00 /100 m
      expect(s.targetPace, 120);
      expect(s.paceStatus, 1); // too slow
    });

    test('unstructured pool swim just counts lengths', () {
      var s = swim(pool(const []), 6);
      expect(s.laps, 6);
      expect(s.effectiveDistance, 150);
      expect(s.step, isNull);
    });
  });

  group('workout remaining', () {
    test('time and distance left', () {
      expect(workoutRemainingM(cssSet, 9, stepDistance: 50), 50);
      expect(workoutRemainingM(cssSet, 0), 900); // 200 + 200 + 4 × 100 + 100
      const ride = [WorkoutStep(kind: 'warmup', durationSec: 600, zone: 'Z2'), WorkoutStep(kind: 'work', durationSec: 300, zone: 'Z4')];
      expect(workoutRemainingSec(ride, 0, Sport.ride, stepElapsed: 100), 800);
      expect(workoutRemainingM(ride, 0), isNull);
    });
  });

  group('voice', () {
    const rideSteps = [
      WorkoutStep(kind: 'warmup', durationSec: 600, zone: 'Z2', hrMin: 120, hrMax: 135),
      WorkoutStep(kind: 'work', durationSec: 180, zone: 'Z5', powerMin: 250, powerMax: 280, hrMin: 160, hrMax: 172),
      WorkoutStep(kind: 'recovery', durationSec: 180, zone: 'Z1'),
      WorkoutStep(kind: 'work', durationSec: 180, zone: 'Z5', powerMin: 250, powerMax: 280, hrMin: 160, hrMax: 172),
      WorkoutStep(kind: 'steady', durationSec: 3600, zone: 'Z2'),
    ];
    final runWords = RegExp(r'lauf|Lauf|jog|Trab|run\b|running|pro Kilometer|per kilometer', caseSensitive: false);

    test('ride step speech names power and heart rate, no running words', () {
      final de1 = stepSpeech(de, rideSteps, 1, u, Sport.ride, 'de');
      expect(de1, 'Intervall 1 von 2. 3 Minuten VO2max, 250 bis 280 Watt, Puls 160 bis 172.');
      final en1 = stepSpeech(en, rideSteps, 1, u, Sport.ride, 'en');
      expect(en1, contains('250 to 280 watts'));
      for (var i = 0; i < rideSteps.length; i++) {
        for (final (l, lang) in [(de, 'de'), (en, 'en')]) {
          expect(stepSpeech(l, rideSteps, i, u, Sport.ride, lang), isNot(matches(runWords)));
        }
      }
      expect(stepTitle(de, rideSteps, 4, sport: Sport.ride), isNot('Dauerlauf'));
    });

    test('swim step speech talks about 100 m pace and rests', () {
      expect(stepSpeech(de, cssSet, 2, u, Sport.swim, 'de'), 'Intervall 1 von 4. 100 Meter CSS-Tempo, 1:40 bis 1:45 pro 100 Meter.');
      // Later repetitions skip the pace (short reps would be chatty).
      expect(stepSpeech(de, cssSet, 4, u, Sport.swim, 'de'), 'Intervall 2 von 4. 100 Meter CSS-Tempo.');
      expect(stepSpeech(de, cssSet, 3, u, Sport.swim, 'de'), 'Pause. 15 Sekunden.');
      for (var i = 0; i < cssSet.length; i++) {
        for (final (l, lang) in [(de, 'de'), (en, 'en')]) {
          expect(stepSpeech(l, cssSet, i, u, Sport.swim, lang), isNot(matches(runWords)));
        }
      }
    });

    test('run step speech is unchanged apart from the spoken counter', () {
      const run = [
        WorkoutStep(kind: 'work', distanceM: 800, zone: 'I', paceMin: 230, paceMax: 240),
        WorkoutStep(kind: 'recovery', durationSec: 120, zone: 'REC'),
        WorkoutStep(kind: 'work', distanceM: 800, zone: 'I', paceMin: 230, paceMax: 240),
      ];
      expect(stepSpeech(de, run, 0, u, Sport.run, 'de'), 'Intervall 1 von 2. 800 Meter Intervall, 3:50 bis 4:00 pro Kilometer.');
      expect(stepTitle(de, run, 2), 'Intervall 2/2');
    });

    test('split announcements per sport', () {
      // Ride: only every 5 km, with the speed of the last 5 km (5 × 2:00 = 30 km/h).
      expect(splitSpeech(de, Sport.ride, [120, 120, 120, 120], 480, 'de'), isNull);
      final ride = splitSpeech(de, Sport.ride, [120, 120, 120, 120, 120], 600, 'de')!;
      expect(ride, 'Kilometer 5. Zeit 10 Minuten. Letzte 5 Kilometer mit 30,0 Kilometer pro Stunde.');
      expect(splitSpeech(en, Sport.ride, List.filled(10, 120), 1200, 'en'), contains('30.0 kilometers per hour'));
      // Open-water swim: pace per 100 m.
      expect(splitSpeech(de, Sport.swim, [1250], 1250, 'de'), contains('2:05 pro 100 Meter'));
      // Run unchanged.
      expect(splitSpeech(de, Sport.run, [300], 300, 'de'), 'Kilometer 1. Zeit 5 Minuten. Letzter Kilometer 5:00 pro Kilometer.');
    });

    test('auto-pause rules', () {
      expect(autoPauseRule(Sport.ride), (720, 6));
      expect(autoPauseRule(Sport.run), (1200, 10));
    });
  });
}
