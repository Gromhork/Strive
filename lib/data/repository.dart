import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/collation.dart';
import '../services/guest_merge.dart';
import 'models.dart';
import 'plan_log.dart';

/// Thin Firestore layer. All user data lives below `users/{uid}`.
///
/// Writes are intentionally *not awaited* by the UI: with offline persistence the local
/// cache is updated immediately and streams fire, while the server sync happens whenever a
/// connection is available (offline mode). A write the server rejects (permission, invalid
/// data) is reported through [onWriteError] – the app shows a notice instead of silently
/// losing the change.
class Repository {
  /// [db]: another Firebase app's Firestore (the guest data transfer writes into the target
  /// account through a second app while the guest stays signed in here).
  Repository(this.uid, [FirebaseFirestore? db]) : _dbOverride = db;
  final String uid;
  final FirebaseFirestore? _dbOverride;

  /// Called when a write fails (set by the app: shows a snackbar).
  static void Function(Object error)? onWriteError;

  /// Firestore allows 500 operations per batch; keep a margin.
  static const batchLimit = 450;

  // Lazy, so a test double (subclass) can be created without Firebase.
  late final _db = _dbOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _sessions => _user.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _templates => _user.collection('templates');
  CollectionReference<Map<String, dynamic>> get _plans => _user.collection('plans');
  CollectionReference<Map<String, dynamic>> get _body => _user.collection('body');
  CollectionReference<Map<String, dynamic>> get _goals => _user.collection('goals');
  CollectionReference<Map<String, dynamic>> get _planLog => _user.collection('planLog');

  /// Every subcollection of the user document (account deletion).
  static const subcollections = ['sessions', 'templates', 'plans', 'body', 'goals', 'planLog'];

  String newId() => _sessions.doc().id;

  /// Runs a write in the background; failures go to [onWriteError]. Returns the future so
  /// callers that must know (migrations) can wait for the commit.
  Future<void> _fire(Future<void> f) {
    final done = f.catchError((Object e) {
      debugPrint('Firestore write failed: $e');
      onWriteError?.call(e);
      throw e;
    });
    unawaited(done.catchError((_) {}));
    return done;
  }

  /// Applies [ops] in batches of at most [batchLimit] operations.
  Future<void> _batched(List<void Function(WriteBatch)> ops) {
    if (ops.isEmpty) return Future.value();
    final commits = <Future<void>>[];
    for (var i = 0; i < ops.length; i += batchLimit) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(batchLimit)) {
        op(batch);
      }
      commits.add(batch.commit());
    }
    return _fire(Future.wait(commits));
  }

  /// Parses every document, skipping (and logging) corrupt ones instead of failing the stream.
  static List<T> parseDocs<T>(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    T? Function(String id, Map<String, dynamic> m) f,
  ) {
    final out = <T>[];
    for (final d in docs) {
      try {
        final v = f(d.id, d.data());
        if (v != null) out.add(v);
      } catch (e) {
        debugPrint('Skipping corrupt document ${d.reference.path}: $e');
      }
    }
    return out;
  }

  /// The query's documents, parsed – each document only when it is new or changed. Firestore sends
  /// the whole result set again on every change; parsing all of it (a year of sessions with GPS
  /// routes: ~0.5 s) after each single edit made the UI hang. One cache per listener.
  static Stream<List<T>> parsedSnapshots<T>(Query<Map<String, dynamic>> q, T? Function(String id, Map<String, dynamic> m) parse) =>
      Stream.multi((out) {
        final cache = IncrementalDocs<T>(parse);
        final sub = q.snapshots().listen(
          (snap) => out.add(
            cache.apply(
              [
                for (final c in snap.docChanges)
                  if (c.type == DocumentChangeType.removed) (c.doc.id, null) else (c.doc.id, c.doc.data() ?? const <String, dynamic>{}),
              ],
              [for (final d in snap.docs) d.id],
              (id) => snap.docs.firstWhere((d) => d.id == id).data(),
            ),
          ),
          onError: out.addError,
          onDone: out.close,
        );
        out.onCancel = sub.cancel;
      });

  // ── Profile
  /// The profile; `null` only when the server confirmed there is none. A missing document in
  /// the local cache (first start offline, cleared cache) is not "a new user": the stream waits
  /// for the server instead of sending an existing user into the setup.
  Stream<UserProfile?> profile() {
    Map<String, dynamic>? last;
    var emitted = false;
    return _user
        .snapshots(includeMetadataChanges: true)
        .where((d) => d.exists || !d.metadata.isFromCache)
        .where((d) {
          // Metadata-only changes (pending write acknowledged) carry the same data.
          final data = d.data();
          final same = emitted && deepEquals(data, last);
          last = data;
          emitted = true;
          return !same;
        })
        .map((d) => d.exists ? UserProfile.fromMap(d.data()!) : null);
  }

  /// The profile write: all of the profile's top-level fields are replaced (nested maps such
  /// as `athlete.dayPlan` / `raceTimes` lose removed keys, cleared fields become null / are
  /// deleted), fields written separately (gcalCalendars, hcDeleted, …) stay untouched.
  static (Map<String, dynamic>, SetOptions) profileWrite(UserProfile p) {
    final m = p.toMap();
    return (m, SetOptions(mergeFields: m.keys.toList()));
  }

  void saveProfile(UserProfile p) {
    final (m, opts) = profileWrite(p);
    _fire(_user.set(m, opts));
  }

  // ── Google Calendar: id of the "Strive" calendar per Google account (survives reinstalls,
  // shared by all devices so no duplicate calendars are created).
  /// Throws when the lookup fails, so the caller never creates a duplicate calendar (whose
  /// events would then never be cleaned up) just because Firestore was unreachable.
  Future<String?> gcalCalendarId(String account) async {
    final d = await _user.get();
    final m = d.data()?['gcalCalendars'];
    return m is Map ? m[account] as String? : null;
  }

  void saveGcalCalendarId(String account, String? id) => _fire(
    _user.set({
      'gcalCalendars': {account: id ?? FieldValue.delete()},
    }, SetOptions(merge: true)),
  );

  // ── Health Connect: ids of imported workouts the user deleted (never imported again).
  Future<Set<String>> deletedImports() async {
    final d = await _user.get();
    final l = d.data()?['hcDeleted'];
    return l is List ? {for (final x in l) '$x'} : const {};
  }

  // ── Sessions
  Stream<List<Session>> sessions() => parsedSnapshots(_sessions.orderBy('start', descending: true), Session.tryFromMap);

  /// Recorded workouts straight from the server (not a possibly incomplete local cache) – the
  /// duplicate cleanup only deletes a program no workout on the server refers to.
  Future<List<Session>> sessionsFromServer() async {
    final q = await _sessions.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15));
    return parseDocs(q.docs, Session.tryFromMap);
  }

  void saveSession(Session s) => _fire(_sessions.doc(s.id).set(s.toMap()));
  void updateSession(String id, Map<String, dynamic> data) => _fire(_sessions.doc(id).update(data));

  /// Deletes a session; an imported one (Health Connect) is remembered so the next import
  /// does not bring it back.
  void deleteSession(Session s) {
    final batch = _db.batch()..delete(_sessions.doc(s.id));
    if (s.externalId != null) {
      batch.set(_user, {
        'hcDeleted': FieldValue.arrayUnion([s.externalId]),
      }, SetOptions(merge: true));
    }
    _fire(batch.commit());
  }

  /// Undo of [deleteSession].
  void restoreSession(Session s) {
    final batch = _db.batch()..set(_sessions.doc(s.id), s.toMap());
    if (s.externalId != null) {
      batch.set(_user, {
        'hcDeleted': FieldValue.arrayRemove([s.externalId]),
      }, SetOptions(merge: true));
    }
    _fire(batch.commit());
  }

  // ── Templates
  Stream<List<WorkoutTemplate>> templates() => parsedSnapshots(_templates, WorkoutTemplate.tryFromMap).map(
    (list) =>
        list..sort((a, b) {
          final o = a.order.compareTo(b.order);
          return o != 0 ? o : compareNames(a.name, b.name);
        }),
  );

  /// The programs on the server (null when it cannot be reached) – the setup only adds the
  /// built-in programs when the server confirms there are none (no duplicates from an
  /// incomplete local cache).
  Future<List<WorkoutTemplate>?> templatesFromServer() async {
    try {
      final q = await _templates.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 8));
      return parseDocs(q.docs, WorkoutTemplate.tryFromMap);
    } catch (e) {
      debugPrint('templates from server failed: $e');
      return null;
    }
  }

  void saveTemplate(WorkoutTemplate t) => _fire(_templates.doc(t.id).set(t.toMap()));
  void deleteTemplate(String id) => _fire(_templates.doc(id).delete());

  /// Partial updates of several plans / programs / sessions in batches (e.g. after a language
  /// change). Each listed field is replaced as with `update`, but a document that was deleted
  /// meanwhile does not fail the whole batch (the stray partial document is skipped when read).
  /// The future completes when the server accepted every batch (migrations wait for it).
  Future<void> updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) {
    final ops = [
      for (final e in sessions.entries) (_sessions.doc(e.key), e.value),
      for (final e in plans.entries) (_plans.doc(e.key), e.value),
      for (final e in templates.entries) (_templates.doc(e.key), e.value),
    ];
    return _batched([
      for (final (doc, data) in ops)
        if (data.isNotEmpty) (b) => b.set(doc, data, SetOptions(mergeFields: data.keys.toList())),
    ]);
  }

  // ── Plans
  Stream<List<PlannedWorkout>> plans() =>
      parsedSnapshots(_plans, PlannedWorkout.tryFromMap).map((list) => list..sort(PlannedWorkout.compareByDay));

  /// Current plans straight from the server (not a possibly incomplete local cache) – used
  /// by the calendar sync, which deletes events of plans that no longer exist.
  Future<List<PlannedWorkout>> plansFromServer() async {
    final q = await _plans.get(const GetOptions(source: Source.server));
    return parseDocs(q.docs, PlannedWorkout.tryFromMap);
  }

  void savePlan(PlannedWorkout p) => _fire(_plans.doc(p.id).set(p.toMap()));
  void updatePlan(String id, Map<String, dynamic> data) => _fire(_plans.doc(id).update(data));
  void deletePlan(String id) => _fire(_plans.doc(id).delete());

  /// Deletes the planned workouts [ids] (batched).
  Future<void> deletePlans(Iterable<String> ids) => _batched([for (final id in ids) (b) => b.delete(_plans.doc(id))]);
  Future<void> savePlans(List<PlannedWorkout> list) => _batched([for (final p in list) (b) => b.set(_plans.doc(p.id), p.toMap())]);

  Future<void> deletePlansFrom(List<PlannedWorkout> all, DateTime from) =>
      _batched([for (final p in all.where((p) => !p.date.isBefore(from) && p.status == 'planned')) (b) => b.delete(_plans.doc(p.id))]);

  /// Replaces the planned (not done / skipped) workouts from [from] on with [plan] in as few
  /// batches as possible – the deletes and the new plan go together, so the calendar never
  /// shows both or neither for long.
  /// Replaces the planned workouts from [from] with [plan]; done / skipped ones and those in
  /// [keep] (linked to a session) stay. [drop]: done-marked workouts that are open all the same (their
  /// linked session too short to count) – replaced like the planned ones.
  Future<void> replacePlans(
    List<PlannedWorkout> all,
    DateTime from,
    List<PlannedWorkout> plan, {
    Set<String> keep = const {},
    Set<String> drop = const {},
  }) {
    final ids = {...keep, for (final p in plan) p.id};
    return _batched([
      for (final p in all.where((p) => !p.date.isBefore(from) && (p.status == 'planned' || drop.contains(p.id)) && !ids.contains(p.id)))
        (b) => b.delete(_plans.doc(p.id)),
      for (final p in plan) (b) => b.set(_plans.doc(p.id), p.toMap()),
    ]);
  }

  // ── Plan history ("Planverlauf"): every applied plan change, newest first.
  static const planLogMax = 300;
  static const planLogDays = 180;

  Stream<List<PlanLogEntry>> planLog() => parsedSnapshots(_planLog.orderBy('at', descending: true).limit(200), PlanLogEntry.fromMap);

  bool _logPruned = false;

  /// Records an applied plan change. Never throws: the history must not break the change itself.
  void logPlanChange(PlanLogEntry e) {
    if (e.items.isEmpty) return;
    try {
      _fire(_planLog.doc().set(e.toMap()));
      if (!_logPruned) {
        _logPruned = true;
        unawaited(prunePlanLog().catchError((Object err) => debugPrint('Plan log prune failed: $err')));
      }
    } catch (err) {
      debugPrint('Plan log write failed: $err');
    }
  }

  /// Keeps the history bounded: at most [planLogMax] entries, none older than [planLogDays].
  Future<void> prunePlanLog({DateTime? now}) async {
    final q = await _planLog.orderBy('at', descending: true).get();
    final ids = planLogPruneIds([for (final d in q.docs) (d.id, d.data()['at'])], now ?? DateTime.now());
    if (ids.isNotEmpty) await _batched([for (final id in ids) (b) => b.delete(_planLog.doc(id))]);
  }

  /// Ids to delete from a newest-first list of (id, at) – see [prunePlanLog].
  static List<String> planLogPruneIds(List<(String, Object?)> newestFirst, DateTime now) {
    final cutoff = now.subtract(const Duration(days: planLogDays)); // time span
    return [
      for (var i = 0; i < newestFirst.length; i++)
        if (i >= planLogMax ||
            switch (newestFirst[i].$2) {
              Timestamp t => t.toDate().isBefore(cutoff),
              _ => false,
            })
          newestFirst[i].$1,
    ];
  }

  // ── Body
  Stream<List<BodyEntry>> body() => parsedSnapshots(_body.orderBy('date'), BodyEntry.fromMap);
  void saveBody(BodyEntry e) => _fire(_body.doc(e.id).set(e.toMap()));
  void deleteBody(String id) => _fire(_body.doc(id).delete());

  // ── Goals
  Stream<List<Goal>> goals() => parsedSnapshots(_goals, Goal.fromMap);
  void saveGoal(Goal g) => _fire(_goals.doc(g.id).set(g.toMap()));
  void deleteGoal(String id) => _fire(_goals.doc(id).delete());

  // ── Sharing: a template is copied into `shared/{code}`; importing creates a new copy.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<String> shareTemplate(WorkoutTemplate t) async {
    final r = Random.secure();
    final code = List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    // Offline the write would wait in the local queue (no code for the user, a share nobody knows
    // about later): fail instead – the caller says "needs a connection".
    await ensureServerReachable();
    await _db.collection('shared').doc(code).set(sharedTemplateDoc(t, uid)).timeout(const Duration(seconds: 15));
    return code;
  }

  /// The document of a shared program: the program and its owner's uid (the owner deletes it with
  /// the account; firestore.rules lets only the owner list them). No name of the owner: anyone
  /// with the code reads the document, and the app never showed it (an older version stored the
  /// profile name as 'ownerName').
  static Map<String, dynamic> sharedTemplateDoc(WorkoutTemplate t, String owner) => {
    ...t.toMap(),
    'owner': owner,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Future<WorkoutTemplate?> importTemplate(String code) async {
    final d = await _db.collection('shared').doc(code.trim().toUpperCase()).get();
    if (!d.exists) return null;
    // An imported copy is the user's own program: a shared built-in's key would make the plan
    // generator pick it instead of the user's original (first program with that key).
    final t = WorkoutTemplate.fromMap(newId(), {...d.data()!, 'key': null, 'origKey': null, 'order': 999});
    saveTemplate(t);
    return t;
  }

  /// Saves several templates in batches (e.g. new order after drag & drop).
  Future<void> saveTemplates(List<WorkoutTemplate> list) => _batched([for (final t in list) (b) => b.set(_templates.doc(t.id), t.toMap())]);

  Future<void> deleteTemplates(Iterable<String> ids) => _batched([for (final id in ids) (b) => b.delete(_templates.doc(id))]);

  void saveFolderOrder(List<String> folders) => _fire(_user.set({'folderOrder': folders}, SetOptions(merge: true)));

  // ── Guest data transfer (a guest whose Google account already has Strive data)
  /// Throws unless the server answers (a step that must not start offline and stop halfway).
  Future<void> ensureServerReachable({Duration timeout = const Duration(seconds: 10)}) =>
      _user.get(const GetOptions(source: Source.server)).timeout(timeout);

  /// Every stored document of the user, straight from the server after the local queue was
  /// sent (nothing recorded offline is missed). Throws when the server cannot be reached.
  Future<AccountData> exportAll({Duration timeout = const Duration(seconds: 20)}) async {
    await _db.waitForPendingWrites().timeout(timeout);
    const server = GetOptions(source: Source.server);
    final user = await _user.get(server).timeout(timeout);
    final collections = <String, List<Doc>>{};
    for (final c in subcollections) {
      final q = await _user.collection(c).get(server).timeout(timeout);
      collections[c] = [for (final d in q.docs) (d.id, d.data())];
    }
    return AccountData(user: user.data(), collections: collections);
  }

  /// Writes [writes] (see guestTransfer) and waits until the server accepted every batch. The
  /// user document ('' collection) is merged, so fields written separately stay.
  Future<void> importAll(List<DocWrite> writes, {Duration timeout = const Duration(seconds: 30)}) async {
    for (var i = 0; i < writes.length; i += batchLimit) {
      final batch = _db.batch();
      for (final (c, id, data) in writes.skip(i).take(batchLimit)) {
        if (c.isEmpty) {
          batch.set(_user, data, SetOptions(merge: true));
        } else {
          batch.set(_user.collection(c).doc(id), data);
        }
      }
      await batch.commit().timeout(timeout);
    }
  }

  // ── Account deletion (GDPR / Play policy)
  /// Deletes everything the user stored: every subcollection below `users/{uid}` (in
  /// batches, straight on the server), the programs they shared and the user document.
  /// Throws when the server cannot be reached – nothing is reported as deleted that is not.
  Future<void> deleteAllData({void Function(int deleted)? onProgress}) async {
    var deleted = 0;
    Future<void> deleteQuery(Query<Map<String, dynamic>> q) async {
      while (true) {
        final page = await q.limit(batchLimit).get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) return;
        final batch = _db.batch();
        for (final d in page.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        deleted += page.docs.length;
        onProgress?.call(deleted);
        if (page.docs.length < batchLimit) return;
      }
    }

    for (final c in subcollections) {
      await deleteQuery(_user.collection(c));
    }
    await deleteQuery(_db.collection('shared').where('owner', isEqualTo: uid));
    await _user.delete();
  }
}

/// Parsed documents of one query listener, updated from each snapshot's changes (see
/// [Repository.parsedSnapshots]): only added / modified documents are parsed, unchanged ones keep
/// their parsed object. A corrupt document is skipped (logged), as with [Repository.parseDocs].
class IncrementalDocs<T> {
  IncrementalDocs(this._parse);
  final T? Function(String id, Map<String, dynamic> m) _parse;
  final _byId = <String, T?>{};

  /// Number of documents parsed so far (tests).
  int parsed = 0;

  T? _tryParse(String id, Map<String, dynamic> m) {
    parsed++;
    try {
      return _parse(id, m);
    } catch (e) {
      debugPrint('Skipping corrupt document $id: $e');
      return null;
    }
  }

  /// [changes]: (id, data) per changed document, data null = removed. [order]: the ids of the
  /// snapshot in query order. [dataOf] reads a document the cache does not know (never expected).
  List<T> apply(List<(String, Map<String, dynamic>?)> changes, List<String> order, Map<String, dynamic>? Function(String id) dataOf) {
    for (final (id, data) in changes) {
      if (data == null) {
        _byId.remove(id);
      } else {
        _byId[id] = _tryParse(id, data);
      }
    }
    final out = <T>[];
    for (final id in order) {
      final v = _byId.containsKey(id) ? _byId[id] : (_byId[id] = _tryParse(id, dataOf(id) ?? const {}));
      if (v != null) out.add(v);
    }
    return out;
  }
}

/// Structural equality of Firestore data (maps, lists, scalars).
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
