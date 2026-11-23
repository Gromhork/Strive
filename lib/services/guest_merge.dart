// Moving a guest's data into an existing account.
//
// A guest (anonymous Firebase user) who links Google, but whose Google account already has a
// Strive account, cannot be linked: Firebase refuses it. The guest then chooses between
// discarding the guest data and taking it along. This file decides *what* is taken along – pure,
// so it is unit-tested without Firebase; lib/features/shell/guest_switch.dart does the I/O.

import '../core/format.dart';
import '../data/builtin_upgrade.dart';
import '../data/default_programs.dart';
import '../data/models.dart';

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
  const GuestTransfer(this.writes, {required this.sessions, this.ids = const {}});
  final List<DocWrite> writes;

  /// Number of workouts (sessions) taken along.
  final int sessions;

  /// The target's id for a guest program or plan entry (programs: the copy or the target's own
  /// built-in; plan entries: the copied history entry). A guest id without an entry has no
  /// counterpart in the target (the guest's open plan, a built-in the target adds itself).
  final Map<String, String> ids;

  /// [old] (a guest program / plan entry id) re-pointed into the target, null without a
  /// counterpart – for the workout in progress, which continues in the target account.
  String? relink(String? old) => old == null ? null : ids[old];
}

/// The writes that take a guest's data into the [target] account.
///
/// Target without a profile (the Google account never finished the setup): everything moves –
/// profile, plan, programs, goals, plan history. Ids are kept (the target has no documents).
///
/// Target with a profile: that account's profile, training plan and race goal stay as they are
/// – two plans on the same days, or the guest's race replacing the account's, would be wrong.
/// Taken along is the guest's history: every workout (session), body measurement, own program,
/// non-race goal, and the completed plan entries the sessions link to. Each document gets a
/// fresh id ([newId]) and every link is re-pointed (session ↔ plan entry, program,
/// automatic-adjustment source).
///
/// Programs: a guest built-in that is unchanged (loads aside – the rep ranges follow the
/// profile goal, so the target's copy rarely has the same ones) maps to the target's program
/// with that key, whatever its structure; the target lacking that key, it is left behind (the
/// plan adds missing built-ins itself). A changed built-in comes along as an own program that
/// still counts as that built-in ('origKey'), named "Name ([ownSuffix])" when its name is a
/// shipped one or clashes – never a second "Upper A" next to the target's. Own programs keep
/// their names ("Name 2" on a clash). Programs in a standard folder go to that folder as the
/// target has it ([de]: the language of a folder the target does not have yet).
///
/// Plan entries: only completed ones linked to a workout that is taken along, dated before the
/// current week ([today]) and in a week in which the target has no plan of its own – the guest's
/// plan must not mix into the target's weekly counts, compliance or adaptation, and a skipped or
/// future entry (never removed by a replan: only planned ones are) has no place in another plan.
/// Workouts without such an entry come along unlinked.
///
/// Health Connect workouts the target already has (same external id) are not copied twice; a
/// guest entry linked to one points to the target's copy (unless a target entry claims it).
/// Those the target deleted ('hcDeleted') stay deleted, and the guest's deleted ones are added
/// to the target's list.
GuestTransfer guestTransfer({
  required AccountData guest,
  required AccountData target,
  required String Function() newId,
  required DateTime today,
  String ownSuffix = 'custom',
  bool de = false,
}) {
  final targetHasProfile = target.user != null && target.user!['onboarded'] == true;
  if (!targetHasProfile) {
    return GuestTransfer(
      [
        if (guest.user != null) ('', '', guest.user!),
        for (final e in guest.collections.entries)
          for (final (id, data) in e.value) (e.key, id, data),
      ],
      sessions: guest['sessions'].length,
      ids: {
        for (final c in const ['templates', 'plans'])
          for (final (id, _) in guest[c]) id: id,
      },
    );
  }

  final writes = <DocWrite>[];

  // Programs.
  final templateIds = <String, String>{};
  final targetTemplates = [
    for (final (id, d) in target['templates'])
      if (WorkoutTemplate.tryFromMap(id, d) case final t?) t,
  ];
  final targetByKey = <String, Doc>{
    for (final d in target['templates'])
      if (d.$2['key'] is String) d.$2['key'] as String: d,
  };
  final taken = {for (final t in targetTemplates) _nameKey(t.folder, t.name)};
  String unique(String folder, String name) {
    var n = name;
    for (var i = 2; taken.contains(_nameKey(folder, n)); i++) {
      n = '$name $i';
    }
    taken.add(_nameKey(folder, n));
    return n;
  }

  final copies = <Doc>[];
  for (final (id, data) in guest['templates']) {
    final key = data['key'];
    // The target's program for that built-in: with the key, else the one standing for it (its own
    // version of it, [programForBuiltin]) – the guest's unchanged copy must not come along next to it.
    final same = key is String ? targetByKey[key] ?? _docOf(target['templates'], programForBuiltin(targetTemplates, key)?.id) : null;
    if (key is String && _unchangedBuiltin(id, data)) {
      // Without a counterpart it stays behind: the target's plan adds that built-in on demand.
      if (same != null) templateIds[id] = same.$1;
      continue;
    }
    if (same != null && _structure(same.$2) == _structure(data)) {
      templateIds[id] = same.$1;
      continue;
    }
    copies.add((id, data));
  }
  for (final (id, data) in copies) {
    final key = data['key'];
    final nid = newId();
    templateIds[id] = nid;
    final folder = _targetFolder('${data['folder'] ?? ''}', targetTemplates, de: de);
    final name = '${data['name'] ?? ''}'.trim();
    final origKey = data['origKey'] ?? key;
    // A changed built-in under a shipped name: the original carries that name (the target has
    // it or gets it), so this version is marked as the user's own.
    final own = origKey is String && (builtinKeysNamed(name).contains(origKey) || taken.contains(_nameKey(folder, name)));
    writes.add((
      'templates',
      nid,
      {
        ...data,
        'folder': folder,
        'name': unique(folder, own ? '$name ($ownSuffix)' : name),
        // Two programs with one key would make the plan generator pick one of them at random.
        if (key is String) ...{'key': null, 'origKey': origKey},
      },
    ));
  }

  // Workouts.
  final deleted = _strings(target.user?['hcDeleted']);
  final targetByExternal = <String, String>{
    for (final (id, d) in target['sessions'])
      if (d['externalId'] is String) d['externalId'] as String: id,
  };
  // Target workouts a target plan entry already claims (a second entry must not claim them).
  final targetLinked = {
    for (final (id, d) in target['sessions'])
      if (d['planId'] is String) id,
    for (final (_, d) in target['plans'])
      if (d['sessionId'] is String) d['sessionId'] as String,
  };
  final sessionIds = <String, String>{};
  final sessionDocs = <String, Map<String, dynamic>>{};
  for (final (id, data) in guest['sessions']) {
    final ext = data['externalId'];
    if (ext is String && deleted.contains(ext)) continue;
    final dup = ext is String ? targetByExternal[ext] : null;
    if (dup != null) {
      if (!targetLinked.contains(dup)) sessionIds[id] = dup;
      continue;
    }
    sessionIds[id] = newId();
    sessionDocs[id] = data;
  }

  // Completed plan entries (history) – see above.
  final thisWeek = startOfWeek(dayOnly(today));
  final targetWeeks = {
    for (final (id, d) in target['plans'])
      if (PlannedWorkout.tryFromMap(id, d) case final p?) startOfWeek(p.date),
  };
  final planIds = <String, String>{};
  final planDocs = <String, Map<String, dynamic>>{};
  for (final (id, data) in guest['plans']) {
    final p = PlannedWorkout.tryFromMap(id, data);
    final session = data['sessionId'];
    if (p == null || p.status != 'done' || session is! String || sessionIds[session] == null) continue;
    final week = startOfWeek(p.date);
    if (!week.isBefore(thisWeek) || targetWeeks.contains(week)) continue;
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

  // Health Connect workouts the guest deleted stay deleted in the target (never imported again).
  final guestDeleted = _strings(guest.user?['hcDeleted']);
  if (!deleted.containsAll(guestDeleted)) {
    writes.add((
      '',
      '',
      {
        'hcDeleted': [...deleted, ...guestDeleted.difference(deleted)],
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
  return GuestTransfer(writes, sessions: sessionDocs.length, ids: {...templateIds, ...planIds});
}

Set<String> _strings(Object? l) => l is List ? {for (final x in l) '$x'} : const {};

String _nameKey(String folder, String name) => '$folder\n${name.trim().toLowerCase()}';

/// A built-in program exactly as shipped apart from the loads the guest entered
/// ([isUntouchedBuiltin] on the program without its weights).
bool _unchangedBuiltin(String id, Map<String, dynamic> data) {
  final ex = data['exercises'];
  final t = WorkoutTemplate.tryFromMap(id, {
    ...data,
    if (ex is List)
      'exercises': [
        for (final e in ex.whereType<Map>())
          {
            ...e.cast<String, dynamic>(),
            if (e['sets'] is List)
              'sets': [
                for (final s in (e['sets'] as List).whereType<Map>()) {...s.cast<String, dynamic>(), 'w': 0},
              ],
          },
      ],
  });
  return t != null && isUntouchedBuiltin(t);
}

/// The target's folder for a copied program: a standard folder (either language, e.g. the
/// guest's "Ganzkörper") becomes that folder as the target has it; own folders stay.
String _targetFolder(String folder, List<WorkoutTemplate> target, {required bool de}) {
  for (final fk in builtinFolderKeys) {
    if (builtinFolderNames(fk).contains(folder)) return builtinTargetFolder(target, fk, de: de);
  }
  return folder;
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

/// The document [id] of [docs] (null for a null id).
Doc? _docOf(List<Doc> docs, String? id) => id == null ? null : docs.where((d) => d.$1 == id).firstOrNull;
