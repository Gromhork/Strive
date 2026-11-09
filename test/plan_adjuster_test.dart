import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/plan_adjuster.dart';

void main() {
  // Wednesday 11 Nov 2026.
  final now = DateTime(2026, 11, 11, 9);
  PlannedWorkout p(
    String id,
    int day, {
    Sport sport = Sport.run,
    String intensity = 'easy',
    bool key = false,
    String? phase,
    String status = 'planned',
  }) => PlannedWorkout(
    id: id,
    date: DateTime(2026, 11, day),
    sport: sport,
    title: id,
    intensity: intensity,
    isKey: key,
    phase: phase,
    status: status,
  );

  test('missed key session moves to a free day without hard neighbours', () {
    final plans = [
      p('int', 10, intensity: 'intervals', key: true), // missed Tue
      p('easyWed', 11),
      p('tempoThu', 12, intensity: 'tempo', key: true),
      p('fri', 13, sport: Sport.ride),
      p('longSun', 15, intensity: 'long', key: true),
    ];
    final ch = proposeWeekAdjustment(plans, now);
    expect(ch, hasLength(1));
    final c = ch.single;
    expect(c.plan.id, 'int');
    // Wed is next to Thu tempo, Fri next to Thu, Sat next to Sun long → nowhere in this week.
    expect(c.isMove, isFalse);
  });

  test('a key session missed last week is not moved into the new week', () {
    // Monday 16 Nov: Sunday's long run was missed; the new week has its own long run.
    final monday = DateTime(2026, 11, 16, 8);
    final plans = [
      p('longSun', 15, intensity: 'long', key: true),
      p('easyTue', 17),
      p('easyThu', 19),
      p('longSun2', 22, intensity: 'long', key: true),
    ];
    final c = proposeWeekAdjustment(plans, monday).single;
    expect(c.plan.id, 'longSun');
    expect(c.isMove, isFalse);
  });

  test('replaces an easy session of the same sport', () {
    final plans = [
      p('int', 9, intensity: 'intervals', key: true), // missed Mon
      p('easyWed', 11),
      p('longSun', 15, intensity: 'long', key: true),
    ];
    final c = proposeWeekAdjustment(plans, now).single;
    expect(c.isMove, isTrue);
    expect(c.to, DateTime(2026, 11, 11));
    expect(c.replaces?.id, 'easyWed');
    final u = planChangeUpdates([c]);
    expect(u['int'], {'date': '2026-11-11'});
    expect(u['easyWed'], {'status': 'skipped'});
  });

  test('easy and recovery-week sessions are dropped, done ones ignored', () {
    final plans = [
      p('easyMon', 9),
      p('doneTue', 10, intensity: 'intervals', key: true, status: 'done'),
      p('recInt', 10, intensity: 'intervals', key: true, phase: 'recovery'),
      p('old', 2, intensity: 'intervals', key: true),
    ];
    final ch = proposeWeekAdjustment(plans, now);
    expect(ch.map((c) => c.plan.id), ['easyMon', 'recInt']);
    expect(ch.every((c) => !c.isMove), isTrue);
  });

  test('two missed key sessions are not stacked on adjacent days', () {
    final plans = [p('a', 9, intensity: 'intervals', key: true), p('b', 10, intensity: 'tempo', key: true)];
    final ch = proposeWeekAdjustment(plans, now);
    final days = ch.where((c) => c.isMove).map((c) => c.to!.day).toList();
    expect(days, [11, 13]);
  });
}
