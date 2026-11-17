// Moving a guest's data into an existing account.
//
// A guest (anonymous Firebase user) who links Google, but whose Google account already has a
// Strive account, cannot be linked: Firebase refuses it. The guest then chooses between
// discarding the guest data and taking it along. This file decides *what* is taken along – pure,
// so it is unit-tested without Firebase; lib/features/shell/guest_switch.dart does the I/O.

/// One Firestore document: its id and data.
typedef Doc = (String id, Map<String, dynamic> data);

/// One document to write below `users/{target uid}`: subcollection ('' = the user document
/// itself), id, data.
typedef DocWrite = (String collection, String id, Map<String, dynamic> data);

/// A user's stored data: the user document and the subcollections (see Repository.subcollections).
class AccountData {
  const AccountData({this.user, this.collections = const {}});
  final Map<String, dynamic>? user;
  final Map<String, List<Doc>> collections;

  List<Doc> operator [](String collection) => collections[collection] ?? const [];

  int get documentCount => collections.values.fold(0, (a, l) => a + l.length);
}

/// What the transfer writes and what it amounts to (for the message after the switch).
class GuestTransfer {
  const GuestTransfer(this.writes, {required this.sessions});
  final List<DocWrite> writes;

  /// Number of workouts (sessions) taken along.
  final int sessions;
}

/// The writes that take a guest's data into the [target] account.
///
/// Target without a profile (the Google account never finished the setup): everything moves –
/// profile, plan, programs, goals, plan history. Ids are kept (the target has no documents).
///
/// Target with a profile: that account's profile, training plan and race goal stay as they are
/// – two plans on the same days, or the guest's race replacing the account's, would be wrong.
/// Taken along is the guest's history: every workout (session), body measurement, own program,
/// non-race goal, and the completed / skipped plan entries (the history the sessions link to).
/// Each document gets a fresh id ([newId]) and every link is re-pointed (session ↔ plan entry,
/// program, automatic-adjustment source). A guest's built-in program maps to the target's copy
/// of it when both have the same structure; a changed one comes along as an own program that
/// still counts as that built-in ('origKey'). Workouts imported from Health Connect that the
/// target already has (same external id) are not copied twice.
GuestTransfer guestTransfer({required AccountData guest, required AccountData target, required String Function() newId}) {
  final targetHasProfile = target.user != null && target.user!['onboarded'] == true;
  if (!targetHasProfile) {
    return GuestTransfer([
      if (guest.user != null) ('', '', guest.user!),
      for (final e in guest.collections.entries)
        for (final (id, data) in e.value) (e.key, id, data),
    ], sessions: guest['sessions'].length);
  }

  final writes = <DocWrite>[];

  // Programs: built-ins map to the target's, everything else is copied with a fresh id.
  final templateIds = <String, String>{};
  final targetByKey = <String, Doc>{
    for (final d in target['templates'])
      if (d.$2['key'] is String) d.$2['key'] as String: d,
  };
  for (final (id, data) in guest['templates']) {
    final key = data['key'];
    final same = key is String ? targetByKey[key] : null;
    if (same != null && _structure(same.$2) == _structure(data)) {
      templateIds[id] = same.$1;
      continue;
    }
    final nid = newId();
    templateIds[id] = nid;
    writes.add((
      'templates',
      nid,
      {
        ...data,
        // A built-in the target has differently (or not at all) becomes an own program: two
        // programs with one key would make the plan generator pick one of them at random.
        if (key is String) ...{'key': null, 'origKey': data['origKey'] ?? key},
      },
    ));
  }

  // Workouts.
  final targetExternal = {
    for (final (_, d) in target['sessions'])
      if (d['externalId'] is String) d['externalId'] as String,
  };
  final sessionIds = <String, String>{};
  final sessionDocs = <String, Map<String, dynamic>>{};
  for (final (id, data) in guest['sessions']) {
    final ext = data['externalId'];
    if (ext is String && targetExternal.contains(ext)) continue;
    sessionIds[id] = newId();
    sessionDocs[id] = data;
  }

  // Completed / skipped plan entries (history); the guest's open plan stays behind.
  final planIds = <String, String>{};
  final planDocs = <String, Map<String, dynamic>>{};
  for (final (id, data) in guest['plans']) {
    final status = data['status'];
    if (status != 'done' && status != 'skipped') continue;
    planIds[id] = newId();
    planDocs[id] = data;
  }

  String? remap(Map<String, String> ids, Object? old) => old is String ? ids[old] : null;

  for (final e in sessionDocs.entries) {
    final d = e.value;
    writes.add((
      'sessions',
      sessionIds[e.key]!,
      {...d, 'planId': remap(planIds, d['planId']), 'templateId': remap(templateIds, d['templateId'])},
    ));
  }
  for (final e in planDocs.entries) {
    final d = e.value;
    final auto = d['auto'];
    writes.add((
      'plans',
      planIds[e.key]!,
      {
        ...d,
        'sessionId': remap(sessionIds, d['sessionId']),
        'templateId': remap(templateIds, d['templateId']),
        // The automatic adjustment names the session that triggered it (once per session).
        if (auto is Map) 'auto': {...auto.cast<String, dynamic>(), 'sessionId': remap(sessionIds, auto['sessionId']) ?? ''},
      },
    ));
  }

  for (final (_, data) in guest['body']) {
    writes.add(('body', newId(), data));
  }
  for (final (_, data) in guest['goals']) {
    // The race goal mirrors the guest's plan goal; the target keeps its own.
    if (data['type'] == 'event') continue;
    writes.add(('goals', newId(), data));
  }
  return GuestTransfer(writes, sessions: sessionDocs.length);
}

/// What makes two programs "the same" across accounts: their exercises and steps, not the names
/// (which follow each account's language) or the stored loads.
String _structure(Map<String, dynamic> t) {
  final ex = t['exercises'];
  final steps = t['steps'];
  return [
    t['sport'],
    t['intensity'],
    t['targetKm'],
    t['targetMin'],
    if (ex is List)
      for (final e in ex.whereType<Map>())
        '${e['exId']}/${e['sets'] is List ? (e['sets'] as List).length : 0}/${e['group']}/${e['repMin']}/${e['repMax']}',
    steps is List ? steps.length : 0,
  ].join('|');
}
