import 'package:flutter_test/flutter_test.dart';
import 'package:strive/services/exercise_class.dart';

void main() {
  test('bodyweight switch only where it makes sense', () {
    // Loaded equipment: no switch.
    expect(offersBodyweightMode('0043', 'barbell full squat'), isFalse);
    expect(offersBodyweightMode('0025', 'barbell bench press'), isFalse);
    expect(offersBodyweightMode('0334', 'dumbbell lateral raise'), isFalse);
    expect(offersBodyweightMode('2330', 'cable lat pulldown'), isFalse);
    expect(offersBodyweightMode('0739', 'sled 45° leg press'), isFalse);
    // Bodyweight exercises and unknown / custom ones: switch offered.
    expect(offersBodyweightMode('0652', 'pull-up'), isTrue);
    expect(offersBodyweightMode('0814', 'triceps dip'), isTrue);
    expect(offersBodyweightMode('0662', 'push-up'), isTrue);
    expect(offersBodyweightMode('0276', 'dead bug'), isTrue);
    expect(offersBodyweightMode('manual', 'Meine Übung'), isTrue);
    // Already in bodyweight mode: keep it so it can be switched off.
    expect(offersBodyweightMode('0043', 'barbell full squat', current: true), isTrue);
  });
}
