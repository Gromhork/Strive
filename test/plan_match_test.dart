import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/plan_match.dart';

void main() {
  final day = DateTime(2026, 11, 9, 7);
  Session run({DateTime? at, int min = 40, Sport sport = Sport.run, String? planId}) =>
      Session(id: 's', sport: sport, title: 'Run', start: at ?? day, durationSec: min * 60, planId: planId);
  PlannedWorkout plan(String id, {int min = 45, Sport sport = Sport.run, String status = 'planned', DateTime? date}) =>
      PlannedWorkout(id: id, date: date ?? DateTime(2026, 11, 9), sport: sport, title: id, durationMin: min, status: status);

  test('matches open plan of same sport and day, closest duration', () {
    final plans = [plan('long', min: 90), plan('easy', min: 40), plan('ride', sport: Sport.ride), plan('done', status: 'done')];
    expect(matchPlan(run(min: 42), plans)?.id, 'easy');
    expect(matchPlan(run(min: 85), plans)?.id, 'long');
    expect(matchPlan(run(at: day.add(const Duration(days: 1))), plans), isNull);
    expect(matchPlan(run(sport: Sport.swim), plans), isNull);
    expect(matchPlan(run(planId: 'long'), plans)?.id, 'long');
  });

  test('watch and phone recordings of one workout overlap', () {
    final phone = run(min: 40);
    expect(sameWorkout(phone, run(at: day.add(const Duration(minutes: 2)), min: 38)), isTrue);
    expect(sameWorkout(phone, run(at: day.add(const Duration(minutes: 50)))), isFalse);
    expect(sameWorkout(phone, run(sport: Sport.ride)), isFalse);
  });

  test('RPE from heart rate rises with intensity', () {
    const p = UserProfile(birthYear: 1990, maxHr: 190);
    expect(rpeFromHr(null, p), isNull);
    final easy = rpeFromHr(125, p)!, tempo = rpeFromHr(160, p)!, hard = rpeFromHr(180, p)!;
    expect(easy, lessThanOrEqualTo(4));
    expect(tempo, greaterThan(easy));
    expect(hard, greaterThanOrEqualTo(8));
  });
}
