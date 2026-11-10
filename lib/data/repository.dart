import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  Repository(this.uid);
  final String uid;

  /// Called when a write fails (set by the app: shows a snackbar).
  static void Function(Object error)? onWriteError;

  /// Firestore allows 500 operations per batch; keep a margin.
  static const batchLimit = 450;

  // Lazy, so a test double (subclass) can be created without Firebase.
  late final _db = FirebaseFirestore.instance;

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
  Stream<List<Session>> sessions() =>
      _sessions.orderBy('start', descending: true).snapshots().map((q) => parseDocs(q.docs, (id, m) => Session.tryFromMap(id, m)));
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
  Stream<List<WorkoutTemplate>> templates() => _templates.snapshots().map(
    (q) => parseDocs(q.docs, WorkoutTemplate.tryFromMap)..sort((a, b) {
      final o = a.order.compareTo(b.order);
      return o != 0 ? o : a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
      _plans.snapshots().map((q) => parseDocs(q.docs, PlannedWorkout.tryFromMap)..sort((a, b) => a.date.compareTo(b.date)));

  /// Current plans straight from the server (not a possibly incomplete local cache) – used
  /// by the calendar sync, which deletes events of plans that no longer exist.
  Future<List<PlannedWorkout>> plansFromServer() async {
    final q = await _plans.get(const GetOptions(source: Source.server));
    return parseDocs(q.docs, PlannedWorkout.tryFromMap);
  }

  void savePlan(PlannedWorkout p) => _fire(_plans.doc(p.id).set(p.toMap()));
  void updatePlan(String id, Map<String, dynamic> data) => _fire(_plans.doc(id).update(data));
  void deletePlan(String id) => _fire(_plans.doc(id).delete());
  Future<void> savePlans(List<PlannedWorkout> list) => _batched([for (final p in list) (b) => b.set(_plans.doc(p.id), p.toMap())]);

  Future<void> deletePlansFrom(List<PlannedWorkout> all, DateTime from) =>
      _batched([for (final p in all.where((p) => !p.date.isBefore(from) && p.status == 'planned')) (b) => b.delete(_plans.doc(p.id))]);

  /// Replaces the planned (not done / skipped) workouts from [from] on with [plan] in as few
  /// batches as possible – the deletes and the new plan go together, so the calendar never
  /// shows both or neither for long.
  Future<void> replacePlans(List<PlannedWorkout> all, DateTime from, List<PlannedWorkout> plan) {
    final keep = {for (final p in plan) p.id};
    return _batched([
      for (final p in all.where((p) => !p.date.isBefore(from) && p.status == 'planned' && !keep.contains(p.id)))
        (b) => b.delete(_plans.doc(p.id)),
      for (final p in plan) (b) => b.set(_plans.doc(p.id), p.toMap()),
    ]);
  }

  // ── Plan history ("Planverlauf"): every applied plan change, newest first.
  static const planLogMax = 300;
  static const planLogDays = 180;

  Stream<List<PlanLogEntry>> planLog() =>
      _planLog.orderBy('at', descending: true).limit(200).snapshots().map((q) => parseDocs(q.docs, (id, m) => PlanLogEntry.fromMap(id, m)));

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
  Stream<List<BodyEntry>> body() => _body.orderBy('date').snapshots().map((q) => parseDocs(q.docs, BodyEntry.fromMap));
  void saveBody(BodyEntry e) => _fire(_body.doc(e.id).set(e.toMap()));
  void deleteBody(String id) => _fire(_body.doc(id).delete());

  // ── Goals
  Stream<List<Goal>> goals() => _goals.snapshots().map((q) => parseDocs(q.docs, Goal.fromMap));
  void saveGoal(Goal g) => _fire(_goals.doc(g.id).set(g.toMap()));
  void deleteGoal(String id) => _fire(_goals.doc(id).delete());

  // ── Sharing: a template is copied into `shared/{code}`; importing creates a new copy.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<String> shareTemplate(WorkoutTemplate t, String ownerName) async {
    final r = Random.secure();
    final code = List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    await _db.collection('shared').doc(code).set({
      ...t.toMap(),
      'owner': uid,
      'ownerName': ownerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<WorkoutTemplate?> importTemplate(String code) async {
    final d = await _db.collection('shared').doc(code.trim().toUpperCase()).get();
    if (!d.exists) return null;
    final t = WorkoutTemplate.fromMap(newId(), d.data()!);
    saveTemplate(t);
    return t;
  }

  /// Saves several templates in batches (e.g. new order after drag & drop).
  Future<void> saveTemplates(List<WorkoutTemplate> list) => _batched([for (final t in list) (b) => b.set(_templates.doc(t.id), t.toMap())]);

  Future<void> deleteTemplates(Iterable<String> ids) => _batched([for (final id in ids) (b) => b.delete(_templates.doc(id))]);

  void saveFolderOrder(List<String> folders) => _fire(_user.set({'folderOrder': folders}, SetOptions(merge: true)));

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
