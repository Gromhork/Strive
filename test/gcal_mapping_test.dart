import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/gcal_api.dart';
import 'package:strive/services/gcal_mapping.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  const u = Units(false);
  final now = DateTime(2026, 11, 8, 10);

  PlannedWorkout plan(String id, DateTime date, {String status = 'planned', String title = 'Easy run', Sport sport = Sport.run}) =>
      PlannedWorkout(id: id, date: date, sport: sport, title: title, durationMin: 50, distanceKm: 8, status: status);

  test('event ids are valid base32hex and deterministic', () {
    final id = gcalEventId('aBc_123-XyZ');
    expect(RegExp(r'^[0-9a-v]{5,1024}$').hasMatch(id), isTrue);
    expect(gcalEventId('aBc_123-XyZ'), id);
    expect(gcalEventId('other'), isNot(id));
  });

  test('rfc3339 carries the local offset', () {
    final s = rfc3339Local(DateTime(2026, 7, 1, 7, 5));
    expect(s, startsWith('2026-07-01T07:05:00'));
    expect(RegExp(r'[+-]\d\d:\d\d$').hasMatch(s), isTrue);
    expect(rfc3339Local(DateTime.utc(2026, 1, 2, 3)), '2026-01-02T03:00:00+00:00');
  });

  test('event body uses preferred time, duration, colour and private props', () {
    final b = gcalEventBody(plan('p1', DateTime(2026, 11, 10)), l, u, startHour: gcalStartHour('morning'));
    expect((b['start'] as Map)['dateTime'], startsWith('2026-11-10T07:00:00'));
    expect((b['end'] as Map)['dateTime'], startsWith('2026-11-10T07:50:00'));
    expect(b['summary'], '🏃 Easy run');
    expect(b['colorId'], '10');
    expect(b['description'], contains('50 min · 8 km'));
    final priv = (b['extendedProperties'] as Map)['private'] as Map;
    expect(priv['striveId'], 'p1');
    expect(priv['striveHash'], hasLength(8));
    expect(gcalStartHour('midday'), 12);
    expect(gcalStartHour('evening'), 18);
  });

  test('hash changes with content and is stable otherwise', () {
    final a = gcalEventBody(plan('p1', DateTime(2026, 11, 10)), l, u, startHour: 18);
    final b = gcalEventBody(plan('p1', DateTime(2026, 11, 10)), l, u, startHour: 18);
    final c = gcalEventBody(plan('p1', DateTime(2026, 11, 10), title: 'Tempo'), l, u, startHour: 18);
    final d = gcalEventBody(plan('p1', DateTime(2026, 11, 10), status: 'done'), l, u, startHour: 18);
    expect(gcalBodyHash(a), gcalBodyHash(b));
    expect(gcalBodyHash(a), isNot(gcalBodyHash(c)));
    expect(gcalBodyHash(a), isNot(gcalBodyHash(d)));
    expect(d['summary'], startsWith('✅'));
  });

  test('only planned/done plans inside the window are synced', () {
    final plans = [
      plan('in', DateTime(2026, 11, 9)),
      plan('done', DateTime(2026, 11, 3), status: 'done'),
      plan('skipped', DateTime(2026, 11, 9), status: 'skipped'),
      plan('old', DateTime(2026, 10, 31)),
      plan('far', DateTime(2027, 6, 1)),
    ];
    final ids = gcalDesiredEvents(
      plans,
      l,
      u,
      preferredTime: 'evening',
      now: now,
    ).map((e) => (e['extendedProperties'] as Map)['private']['striveId']);
    expect(ids, ['in', 'done']);
  });

  test('diff inserts new, updates changed, deletes removed, ignores foreign events', () {
    final keep = gcalEventBody(plan('keep', DateTime(2026, 11, 9)), l, u, startHour: 18);
    final changed = gcalEventBody(plan('chg', DateTime(2026, 11, 10)), l, u, startHour: 18);
    final added = gcalEventBody(plan('new', DateTime(2026, 11, 11)), l, u, startHour: 18);
    final remote = [
      RemoteEvent(id: keep['id'], striveId: 'keep', hash: gcalBodyHash(keep)),
      RemoteEvent(id: changed['id'], striveId: 'chg', hash: 'deadbeef'),
      RemoteEvent(id: gcalEventId('gone'), striveId: 'gone', hash: 'x'),
      const RemoteEvent(id: 'userevent1'),
    ];
    final diff = gcalDiff([keep, changed, added], remote);
    expect(diff.inserts.map((e) => e['id']), [added['id']]);
    expect(diff.updates.map((e) => e['id']), [changed['id']]);
    expect(diff.deletes, [gcalEventId('gone')]);
    expect(gcalDiff([keep], [RemoteEvent(id: keep['id'], striveId: 'keep', hash: gcalBodyHash(keep))]).isEmpty, isTrue);
  });

  test('RemoteEvent parses extended properties', () {
    final r = RemoteEvent.fromJson({
      'id': 'abc',
      'extendedProperties': {
        'private': {'striveId': 'p9', 'striveHash': '1234abcd'},
      },
    });
    expect(r.striveId, 'p9');
    expect(r.hash, '1234abcd');
    expect(RemoteEvent.fromJson({'id': 'x'}).striveId, isNull);
  });

  test('API errors are classified', () {
    const disabled =
        '{"error":{"code":403,"message":"Google Calendar API has not been used in project 123 before or it is disabled.",'
        '"errors":[{"reason":"accessNotConfigured"}],"status":"PERMISSION_DENIED"}}';
    expect(gcalErrorFromResponse(403, disabled).kind, GcalErrorKind.apiDisabled);
    expect(gcalErrorFromResponse(403, '{"error":{"errors":[{"reason":"rateLimitExceeded"}]}}').kind, GcalErrorKind.rateLimit);
    expect(gcalErrorFromResponse(403, '{"error":{"errors":[{"reason":"insufficientPermissions"}]}}').kind, GcalErrorKind.auth);
    expect(gcalErrorFromResponse(401, '').kind, GcalErrorKind.auth);
    expect(gcalErrorFromResponse(410, 'gone').kind, GcalErrorKind.notFound);
    expect(gcalErrorFromResponse(409, '{}').kind, GcalErrorKind.conflict);
    expect(gcalErrorFromResponse(500, '<html>').kind, GcalErrorKind.other);
  });

  test('runPooled limits concurrency and runs everything', () async {
    var active = 0, peak = 0, done = 0;
    await runPooled([
      for (var i = 0; i < 10; i++)
        () async {
          active++;
          peak = peak < active ? active : peak;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          active--;
          done++;
        },
    ], concurrency: 3);
    expect(done, 10);
    expect(peak, lessThanOrEqualTo(3));
  });
}
