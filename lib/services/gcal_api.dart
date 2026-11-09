import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'gcal_mapping.dart';

enum GcalErrorKind { apiDisabled, auth, offline, rateLimit, notFound, conflict, other }

class GcalException implements Exception {
  final GcalErrorKind kind;
  final int? status;
  final String message;
  const GcalException(this.kind, this.message, {this.status});
  @override
  String toString() => 'GcalException($kind, $status): $message';
}

/// Classifies a Calendar API error response.
GcalException gcalErrorFromResponse(int status, String body) {
  var message = 'HTTP $status';
  final reasons = <String>{};
  try {
    final err = (jsonDecode(body) as Map)['error'] as Map;
    message = (err['message'] as String?) ?? message;
    if (err['status'] is String) reasons.add(err['status'] as String);
    for (final e in (err['errors'] as List?) ?? const []) {
      if (e is Map && e['reason'] is String) reasons.add(e['reason'] as String);
    }
    for (final d in (err['details'] as List?) ?? const []) {
      if (d is Map && d['reason'] is String) reasons.add(d['reason'] as String);
    }
  } catch (_) {}
  final kind = switch (status) {
    401 => GcalErrorKind.auth,
    404 || 410 => GcalErrorKind.notFound,
    409 => GcalErrorKind.conflict,
    429 => GcalErrorKind.rateLimit,
    403
        when reasons.any((r) => r == 'accessNotConfigured' || r == 'SERVICE_DISABLED') ||
            message.contains('has not been used in project') =>
      GcalErrorKind.apiDisabled,
    403 when reasons.any((r) => r == 'rateLimitExceeded' || r == 'userRateLimitExceeded' || r == 'quotaExceeded') =>
      GcalErrorKind.rateLimit,
    403 when reasons.any((r) => r == 'insufficientPermissions' || r == 'ACCESS_TOKEN_SCOPE_INSUFFICIENT') => GcalErrorKind.auth,
    _ => GcalErrorKind.other,
  };
  return GcalException(kind, message, status: status);
}

/// Supplies OAuth headers; `refresh` asks for a fresh token (after a 401).
typedef GcalHeaders = Future<Map<String, String>> Function({bool refresh});

/// Thin Google Calendar REST v3 client (only the endpoints Strive needs).
class GcalApi {
  GcalApi(this._headers, {http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://www.googleapis.com/calendar/v3';
  final GcalHeaders _headers;
  final http.Client _client;
  Map<String, String>? _cached;

  void close() => _client.close();

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    var refreshed = false;
    for (var attempt = 0; ; attempt++) {
      _cached ??= await _headers();
      final req =
          http.Request(method, uri)
            ..headers.addAll(_cached!)
            ..headers['Accept'] = 'application/json';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json; charset=utf-8';
        req.body = jsonEncode(body);
      }
      final http.Response res;
      try {
        res = await http.Response.fromStream(await _client.send(req)).timeout(const Duration(seconds: 30));
      } on SocketException catch (e) {
        throw GcalException(GcalErrorKind.offline, e.message);
      } on http.ClientException catch (e) {
        throw GcalException(GcalErrorKind.offline, e.message);
      } on TimeoutException {
        throw const GcalException(GcalErrorKind.offline, 'timeout');
      } on HandshakeException catch (e) {
        throw GcalException(GcalErrorKind.offline, e.message);
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
      }
      final err = gcalErrorFromResponse(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true));
      if (err.kind == GcalErrorKind.auth && !refreshed) {
        refreshed = true;
        _cached = await _headers(refresh: true);
        continue;
      }
      // Bulk changes (a regenerated plan) easily hit Calendar's per-user write limits:
      // back off exponentially (1 s … 32 s) before giving up.
      if ((err.kind == GcalErrorKind.rateLimit || res.statusCode >= 500) && attempt < 6) {
        await Future<void>.delayed(Duration(milliseconds: 1000 * (1 << attempt)));
        continue;
      }
      throw err;
    }
  }

  Future<String> createCalendar({required String summary, required String description, String? timeZone}) async {
    final r = await _send(
      'POST',
      '/calendars',
      body: {'summary': summary, 'description': description, if (timeZone != null) 'timeZone': timeZone},
    );
    return (r as Map)['id'] as String;
  }

  Future<void> deleteCalendar(String calendarId) => _send('DELETE', '/calendars/${Uri.encodeComponent(calendarId)}');

  /// All non-deleted events (optionally only those overlapping [from, to)).
  Future<List<RemoteEvent>> listEvents(String calendarId, {DateTime? from, DateTime? to}) async {
    final out = <RemoteEvent>[];
    String? page;
    do {
      final r =
          await _send(
                'GET',
                '/calendars/${Uri.encodeComponent(calendarId)}/events',
                query: {
                  if (from != null) 'timeMin': rfc3339Local(from),
                  if (to != null) 'timeMax': rfc3339Local(to),
                  'singleEvents': 'true',
                  'showDeleted': 'false',
                  'maxResults': '2500',
                  'fields': 'items(id,extendedProperties),nextPageToken',
                  if (page != null) 'pageToken': page,
                },
              )
              as Map;
      for (final e in (r['items'] as List?) ?? const []) {
        out.add(RemoteEvent.fromJson((e as Map).cast<String, dynamic>()));
      }
      page = r['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  String _events(String calendarId) => '/calendars/${Uri.encodeComponent(calendarId)}/events';

  /// Insert with our deterministic id; if it already exists (e.g. outside the fetched window
  /// or previously deleted) the event is overwritten instead.
  Future<void> upsertEvent(String calendarId, Map<String, dynamic> body, {bool exists = false}) async {
    final id = body['id'] as String;
    if (exists) {
      try {
        await _send('PUT', '${_events(calendarId)}/$id', body: body);
        return;
      } on GcalException catch (e) {
        if (e.kind != GcalErrorKind.notFound) rethrow;
      }
    }
    try {
      await _send('POST', _events(calendarId), body: body);
    } on GcalException catch (e) {
      if (e.kind != GcalErrorKind.conflict) rethrow;
      await _send('PUT', '${_events(calendarId)}/$id', body: body);
    }
  }

  Future<void> deleteEvent(String calendarId, String eventId) async {
    try {
      await _send('DELETE', '${_events(calendarId)}/$eventId');
    } on GcalException catch (e) {
      if (e.kind != GcalErrorKind.notFound) rethrow;
    }
  }
}

/// Runs [tasks] with at most [concurrency] in flight. All tasks are attempted (one failing
/// event must not block the others); the first error is rethrown at the end. Auth / offline
/// errors stop early since every further request would fail the same way.
Future<void> runPooled(List<Future<void> Function()> tasks, {int concurrency = 3}) async {
  var next = 0;
  Object? error;
  StackTrace? stack;
  var fatal = false;
  Future<void> worker() async {
    while (!fatal && next < tasks.length) {
      final t = tasks[next++];
      try {
        await t();
      } catch (e, s) {
        error ??= e;
        stack ??= s;
        if (e is GcalException &&
            (e.kind == GcalErrorKind.auth || e.kind == GcalErrorKind.offline || e.kind == GcalErrorKind.apiDisabled)) {
          fatal = true;
        }
      }
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  if (error != null) Error.throwWithStackTrace(error!, stack!);
}
