import 'package:flutter_test/flutter_test.dart';
import 'package:strive/data/exercise_names_de.dart';

void main() {
  group('I1 German exercise names', () {
    test('curated names are fully German (no "Cable Fly")', () {
      for (final n in exerciseNamesDe.values) {
        expect(n, isNot(contains('Cable')), reason: n);
      }
      expect(exerciseName('0227', 'cable standing fly', 'de'), 'Fliegende stehend (Kabelzug)');
    });

    test('long tail: rule-based German name instead of the English database name', () {
      expect(germanExerciseName('dumbbell seated shoulder press'), 'Schulterdrücken sitzend (Kurzhantel)');
      expect(germanExerciseName('cable seated row'), 'Rudern sitzend (Kabelzug)');
      expect(germanExerciseName('barbell incline bench press'), 'Schrägbankdrücken (Langhantel)');
      expect(germanExerciseName('lever leg extension'), 'Beinstrecker (Maschine)');
      expect(germanExerciseName('dumbbell one arm triceps extension (on bench)'), 'Trizepsstrecken einarmig (Kurzhantel)');
      expect(germanExerciseName('ez barbell curl'), 'Curl (SZ-Stange)');
      // Unknown proper names stay in front of the German movement.
      expect(germanExerciseName('dumbbell zottman curl'), 'Zottman Curl (Kurzhantel)');
      // Through the resolver (stored sessions carry the English database name).
      expect(exerciseName('9999', 'cable lateral raise', 'de'), 'Seitheben (Kabelzug)');
      expect(exerciseName('9999', 'cable lateral raise', 'en'), 'Cable lateral raise');
      // A name the user typed in German stays.
      expect(exerciseName('custom', 'Kniebeuge mit Pause', 'de'), 'Kniebeuge mit Pause');
    });
  });
}
