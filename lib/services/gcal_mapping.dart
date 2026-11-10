import 'dart:convert';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../features/calendar/planned_workout_page.dart' show phaseLabel;
import '../features/session/step_text.dart';
import '../l10n/gen/app_localizations.dart';

/// Pure mapping between Strive plans and Google Calendar events (no I/O, unit tested).
///
/// Every synced event gets a deterministic id derived from the plan id, so inserts are
/// idempotent, and carries `extendedProperties.private.{striveId, striveHash}`; the hash lets
/// the sync skip unchanged events.

/// Bump when the event layout changes so all events are rewritten once.
const gcalFormatVersion = 1;

/// Days in the past / future that are kept in sync.
const gcalPastDays = 7;
const gcalFutureDays = 183;

/// Local sync window [start, end) relative to [now].
(DateTime, DateTime) gcalWindow(DateTime now) {
  final today = dayOnly(now);
  return (addDays(today, -gcalPastDays), addDays(today, gcalFutureDays));
}

/// Start hour for the athlete's preferred training time.
int gcalStartHour(String preferredTime) => switch (preferredTime) {
  'morning' => 7,
  'midday' => 12,
  _ => 18,
};

/// Event ids may only contain base32hex characters (0-9, a-v), 5–1024 chars.
/// "strive" itself is valid base32hex; the plan id is appended hex-encoded.
String gcalEventId(String planId) => 'strive${utf8.encode(planId).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

/// RFC 3339 timestamp with the local UTC offset of [t] (DST-correct per date).
String rfc3339Local(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final o = t.isUtc ? Duration.zero : t.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final m = o.inMinutes.abs();
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
      '$sign${two(m ~/ 60)}:${two(m % 60)}';
}

String sportEmoji(Sport s) => switch (s) {
  Sport.gym => '🏋️',
  Sport.run => '🏃',
  Sport.ride => '🚴',
  Sport.swim => '🏊',
};

/// Google Calendar event colour ids closest to the app's sport colours.
String gcalColorId(Sport s) => switch (s) {
  Sport.gym => '6', // Tangerine
  Sport.run => '10', // Basil
  Sport.ride => '5', // Banana
  Sport.swim => '7', // Peacock
};

/// Which plans belong in the calendar: planned or done, inside the window.
bool gcalShouldSync(PlannedWorkout p, DateTime now) {
  if (p.status != 'planned' && p.status != 'done') return false;
  final (from, to) = gcalWindow(now);
  final d = dayOnly(p.date);
  return !d.isBefore(from) && d.isBefore(to);
}

/// 32-bit FNV-1a over the UTF-8 bytes, as 8 hex chars.
String fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

String gcalDescription(PlannedWorkout p, AppLocalizations l, Units u) {
  final b = StringBuffer();
  final head = [
    p.sport.label(l),
    if (p.sport.isCardio) intensityLabel(l, p.intensity),
    '${p.durationMin} min',
    if (p.distanceKm != null && p.distanceKm! > 0)
      p.sport == Sport.swim ? u.swimDist(p.distanceKm! * 1000) : u.dist(p.distanceKm! * 1000, digits: 1),
  ];
  b.writeln(head.join(' · '));
  final tags = [if (p.phase != null && phaseLabel(l, p.phase).isNotEmpty) phaseLabel(l, p.phase), if (p.isKey) '⭐ ${l.keySession}'];
  if (tags.isNotEmpty) b.writeln(tags.join(' · '));
  if (p.description.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln(p.description.trim());
  }
  if (p.steps.isNotEmpty) {
    b
      ..writeln()
      ..writeln('${l.gcalStructure}:');
    const maxSteps = 40;
    for (var i = 0; i < p.steps.length && i < maxSteps; i++) {
      final target = stepTarget(l, p.steps[i], u, p.sport);
      b.writeln('• ${stepSentence(l, p.steps, i, u, p.sport)}${target.isEmpty ? '' : ' ($target)'}');
    }
    if (p.steps.length > maxSteps) b.writeln('…');
  }
  b
    ..writeln()
    ..write(l.gcalEventFooter);
  return b.toString();
}

/// Full event resource for [p] (used for insert and update).
Map<String, dynamic> gcalEventBody(PlannedWorkout p, AppLocalizations l, Units u, {required int startHour}) {
  final start = DateTime(p.date.year, p.date.month, p.date.day, startHour);
  final end = start.add(Duration(minutes: p.durationMin <= 0 ? 30 : p.durationMin));
  final body = <String, dynamic>{
    'id': gcalEventId(p.id),
    'status': 'confirmed',
    'summary': '${p.isDone ? '✅ ' : ''}${sportEmoji(p.sport)} ${p.title}',
    'description': gcalDescription(p, l, u),
    'start': {'dateTime': rfc3339Local(start)},
    'end': {'dateTime': rfc3339Local(end)},
    'colorId': gcalColorId(p.sport),
    'transparency': 'opaque',
    // Strive has its own training reminders; avoid duplicate notifications.
    'reminders': {'useDefault': false},
  };
  final hash = fnv1a('$gcalFormatVersion|${jsonEncode(body)}');
  body['extendedProperties'] = {
    'private': {'striveId': p.id, 'striveHash': hash},
  };
  return body;
}

String? gcalBodyHash(Map<String, dynamic> body) => (body['extendedProperties']?['private'] as Map?)?['striveHash'] as String?;

/// Minimal view of an event already in the Strive calendar.
class RemoteEvent {
  final String id;
  final String? striveId;
  final String? hash;
  const RemoteEvent({required this.id, this.striveId, this.hash});

  factory RemoteEvent.fromJson(Map<String, dynamic> j) {
    final priv = (j['extendedProperties'] as Map?)?['private'] as Map?;
    return RemoteEvent(id: j['id'] as String, striveId: priv?['striveId'] as String?, hash: priv?['striveHash'] as String?);
  }
}

class GcalDiff {
  final List<Map<String, dynamic>> inserts;
  final List<Map<String, dynamic>> updates;
  final List<String> deletes; // event ids
  const GcalDiff({this.inserts = const [], this.updates = const [], this.deletes = const []});
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;
  int get length => inserts.length + updates.length + deletes.length;
}

/// True for events Strive created (marked via extended property or our id prefix).
bool gcalIsStriveEvent(RemoteEvent r) => r.striveId != null || r.id.startsWith('strive');

/// Event ids of all plans that may stay in the calendar regardless of the sync window
/// (planned or done). Events of deleted / skipped / replaced plans are removed even when
/// they lie outside the window.
Set<String> gcalKeepIds(List<PlannedWorkout> plans) => {
  for (final p in plans)
    if (p.status == 'planned' || p.status == 'done') gcalEventId(p.id),
};

/// Compares desired event bodies (inside the window) with all events in the Strive calendar.
/// Strive events that are neither desired nor in [keep] are deleted; events added by the
/// user are never touched.
GcalDiff gcalDiff(List<Map<String, dynamic>> desired, List<RemoteEvent> remote, {Set<String> keep = const {}}) {
  final byId = {for (final r in remote) r.id: r};
  final wanted = {for (final d in desired) d['id'] as String: d};
  final inserts = <Map<String, dynamic>>[], updates = <Map<String, dynamic>>[];
  for (final d in wanted.values) {
    final r = byId[d['id']];
    if (r == null) {
      inserts.add(d);
    } else if (r.hash != gcalBodyHash(d)) {
      updates.add(d);
    }
  }
  final deletes = [
    for (final r in remote)
      if (gcalIsStriveEvent(r) && !wanted.containsKey(r.id) && !keep.contains(r.id)) r.id,
  ];
  return GcalDiff(inserts: inserts, updates: updates, deletes: deletes);
}

/// Desired events for the current plan.
List<Map<String, dynamic>> gcalDesiredEvents(
  List<PlannedWorkout> plans,
  AppLocalizations l,
  Units u, {
  required String preferredTime,
  required DateTime now,
}) {
  final hour = gcalStartHour(preferredTime);
  return [
    for (final p in plans)
      if (gcalShouldSync(p, now)) gcalEventBody(p, l, u, startHour: hour),
  ];
}
