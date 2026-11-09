import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/compliance.dart';

final _now = DateTime(2026, 11, 9, 12);

PlannedWorkout _plan({
  String id = 'p1',
  DateTime? date,
  int durationMin = 60,
  double? distanceKm,
  String status = 'planned',
  String? sessionId,
}) => PlannedWorkout(
  id: id,
  date: date ?? DateTime(2026, 11, 8),
  sport: Sport.run,
  title: 'Run',
  durationMin: durationMin,
  distanceKm: distanceKm,
  status: status,
  sessionId: sessionId,
);

Session _session({String id = 's1', int minutes = 60, double distanceM = 0, String? planId}) => Session(
  id: id,
  sport: Sport.run,
  title: 'Run',
  start: DateTime(2026, 11, 8, 7),
  durationSec: minutes * 60,
  distanceM: distanceM,
  planId: planId,
);

void main() {
  group('complianceLevelOf', () {
    test('band edges', () {
      expect(complianceLevelOf(1.0), ComplianceLevel.green);
      expect(complianceLevelOf(0.8), ComplianceLevel.green);
      expect(complianceLevelOf(1.2), ComplianceLevel.green);
      expect(complianceLevelOf(0.79), ComplianceLevel.yellow);
      expect(complianceLevelOf(0.5), ComplianceLevel.yellow);
      expect(complianceLevelOf(1.21), ComplianceLevel.yellow);
      expect(complianceLevelOf(1.5), ComplianceLevel.yellow);
      expect(complianceLevelOf(0.49), ComplianceLevel.orange);
      expect(complianceLevelOf(1.51), ComplianceLevel.orange);
    });
  });

  group('planCompliance', () {
    test('duration-based ratio', () {
      final c = planCompliance(_plan(status: 'done'), _session(minutes: 54), now: _now);
      expect(c.level, ComplianceLevel.green);
      expect(c.ratio, closeTo(0.9, 1e-9));
      expect(c.pct, 90);
      expect(planCompliance(_plan(), _session(minutes: 40), now: _now).level, ComplianceLevel.yellow);
      expect(planCompliance(_plan(), _session(minutes: 100), now: _now).level, ComplianceLevel.orange);
    });

    test('distance-based plan uses distance', () {
      final p = _plan(distanceKm: 10, durationMin: 60);
      // Slow but full distance → green although duration is 150 %.
      expect(planCompliance(p, _session(minutes: 90, distanceM: 10000), now: _now).level, ComplianceLevel.green);
      expect(planCompliance(p, _session(minutes: 60, distanceM: 6000), now: _now).level, ComplianceLevel.yellow);
      // Session without distance (e.g. treadmill w/o data) falls back to duration.
      expect(planCompliance(p, _session(minutes: 60), now: _now).ratio, closeTo(1, 1e-9));
    });

    test('missed, future, today and skipped', () {
      expect(planCompliance(_plan(date: DateTime(2026, 11, 8)), null, now: _now).level, ComplianceLevel.red);
      expect(planCompliance(_plan(date: DateTime(2026, 11, 9)), null, now: _now).level, ComplianceLevel.none);
      expect(planCompliance(_plan(date: DateTime(2026, 11, 12)), null, now: _now).level, ComplianceLevel.none);
      expect(planCompliance(_plan(status: 'skipped'), null, now: _now).level, ComplianceLevel.none);
      expect(planCompliance(_plan(status: 'skipped'), _session(), now: _now).level, ComplianceLevel.none);
    });

    test('done without linked session counts as completed', () {
      final c = planCompliance(_plan(status: 'done'), null, now: _now);
      expect(c.level, ComplianceLevel.green);
      expect(c.ratio, isNull);
    });
  });

  test('linkPlanSessions via sessionId or planId', () {
    final plans = [_plan(id: 'a', sessionId: 's1'), _plan(id: 'b'), _plan(id: 'c')];
    final sessions = [_session(id: 's1'), _session(id: 's2', planId: 'b')];
    final m = linkPlanSessions(plans, sessions);
    expect(m['a']?.id, 's1');
    expect(m['b']?.id, 's2');
    expect(m.containsKey('c'), isFalse);
  });

  group('weeklyCompletion', () {
    test('weighted by planned minutes, capped per workout', () {
      final plans = [
        _plan(id: 'a', durationMin: 60, status: 'done'), // 60 of 60 (120 min done, capped)
        _plan(id: 'b', durationMin: 30, status: 'done'), // 15 of 30
        _plan(id: 'c', durationMin: 30), // missed / future → 0
        _plan(id: 'd', durationMin: 0), // ignored
      ];
      final linked = {'a': _session(id: 's1', minutes: 120), 'b': _session(id: 's2', minutes: 15)};
      expect(weeklyCompletion(plans, linked), closeTo(75 / 120, 1e-9));
    });

    test('skipped counts as 0, done without session as full', () {
      final plans = [_plan(id: 'a', durationMin: 40, status: 'skipped'), _plan(id: 'b', durationMin: 40, status: 'done')];
      expect(weeklyCompletion(plans, const {}), closeTo(0.5, 1e-9));
    });

    test('null when nothing planned', () {
      expect(weeklyCompletion(const [], const {}), isNull);
    });
  });
}
