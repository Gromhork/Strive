import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/zone_info.dart';

void main() {
  test('retired zone codes map to the reduced set', () {
    expect(normalizeZone('L', Sport.run), 'E');
    expect(normalizeZone('walk', Sport.run), 'REC');
    expect(normalizeZone('Z3', Sport.ride), 'SS');
    expect(normalizeZone('TE', Sport.swim), 'EN');
    for (final s in [Sport.run, Sport.ride, Sport.swim]) {
      expect(zonesFor(s).length, lessThanOrEqualTo(6));
    }
  });

  test('intensity is derived from the workout structure', () {
    const easy = [WorkoutStep(kind: 'steady', zone: 'E', durationSec: 2400)];
    const long = [WorkoutStep(kind: 'steady', zone: 'E', durationSec: 5400)];
    const tempo = [
      WorkoutStep(kind: 'warmup', zone: 'E', durationSec: 600),
      WorkoutStep(kind: 'work', zone: 'T', durationSec: 1200),
    ];
    const vo2 = [WorkoutStep(kind: 'work', zone: 'I', distanceM: 800), WorkoutStep(kind: 'recovery', zone: 'REC', durationSec: 120)];
    const drills = [
      WorkoutStep(kind: 'work', zone: 'DR', distanceM: 50),
      WorkoutStep(kind: 'recovery', zone: 'REC', durationSec: 20),
      WorkoutStep(kind: 'work', zone: 'DR', distanceM: 50),
    ];
    expect(deriveIntensity(easy, Sport.run), 'easy');
    expect(deriveIntensity(long, Sport.run), 'long');
    expect(deriveIntensity(tempo, Sport.run), 'tempo');
    expect(deriveIntensity(vo2, Sport.run), 'intervals');
    expect(deriveIntensity(drills, Sport.swim), 'technique');
  });
}
