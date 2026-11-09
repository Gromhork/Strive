import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Thin Firestore layer. All user data lives below `users/{uid}`.
///
/// Writes are intentionally *not awaited*: with offline persistence the local
/// cache is updated immediately and streams fire, while the server sync
/// happens whenever a connection is available (offline mode).
class Repository {
  Repository(this.uid);
  final String uid;

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _sessions => _user.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _templates => _user.collection('templates');
  CollectionReference<Map<String, dynamic>> get _plans => _user.collection('plans');
  CollectionReference<Map<String, dynamic>> get _body => _user.collection('body');
  CollectionReference<Map<String, dynamic>> get _goals => _user.collection('goals');

  String newId() => _sessions.doc().id;

  void _fire(Future<void> f) => unawaited(f.catchError((e) => debugPrint('Firestore write failed: $e')));

  // ── Profile
  Stream<UserProfile?> profile() => _user.snapshots().map((d) => d.exists ? UserProfile.fromMap(d.data()!) : null);
  void saveProfile(UserProfile p) => _fire(_user.set(p.toMap(), SetOptions(merge: true)));

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

  // ── Sessions
  Stream<List<Session>> sessions() =>
      _sessions.orderBy('start', descending: true).snapshots().map((q) => q.docs.map(Session.fromDoc).toList());
  void saveSession(Session s) => _fire(_sessions.doc(s.id).set(s.toMap()));
  void deleteSession(String id) => _fire(_sessions.doc(id).delete());

  // ── Templates
  Stream<List<WorkoutTemplate>> templates() => _templates.snapshots().map(
    (q) =>
        q.docs.map((d) => WorkoutTemplate.fromMap(d.id, d.data())).toList()..sort((a, b) {
          final o = a.order.compareTo(b.order);
          return o != 0 ? o : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }),
  );
  void saveTemplate(WorkoutTemplate t) => _fire(_templates.doc(t.id).set(t.toMap()));
  void deleteTemplate(String id) => _fire(_templates.doc(id).delete());

  /// Partial updates of several plans / programs in batches (e.g. after a language change).
  void updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) {
    final ops = [
      for (final e in sessions.entries) (_sessions.doc(e.key), e.value),
      for (final e in plans.entries) (_plans.doc(e.key), e.value),
      for (final e in templates.entries) (_templates.doc(e.key), e.value),
    ];
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final (doc, data) in ops.skip(i).take(400)) {
        batch.update(doc, data);
      }
      _fire(batch.commit());
    }
  }

  // ── Plans
  Stream<List<PlannedWorkout>> plans() => _plans.snapshots().map(
    (q) => q.docs.map((d) => PlannedWorkout.fromMap(d.id, d.data())).toList()..sort((a, b) => a.date.compareTo(b.date)),
  );

  /// Current plans straight from the server (not a possibly incomplete local cache) – used
  /// by the calendar sync, which deletes events of plans that no longer exist.
  Future<List<PlannedWorkout>> plansFromServer() async {
    final q = await _plans.get(const GetOptions(source: Source.server));
    return q.docs.map((d) => PlannedWorkout.fromMap(d.id, d.data())).toList();
  }

  void savePlan(PlannedWorkout p) => _fire(_plans.doc(p.id).set(p.toMap()));
  void updatePlan(String id, Map<String, dynamic> data) => _fire(_plans.doc(id).update(data));
  void deletePlan(String id) => _fire(_plans.doc(id).delete());
  void savePlans(List<PlannedWorkout> list) {
    for (var i = 0; i < list.length; i += 400) {
      final batch = _db.batch();
      for (final p in list.skip(i).take(400)) {
        batch.set(_plans.doc(p.id), p.toMap());
      }
      _fire(batch.commit());
    }
  }

  void deletePlansFrom(List<PlannedWorkout> all, DateTime from) {
    final batch = _db.batch();
    for (final p in all.where((p) => !p.date.isBefore(from) && p.status == 'planned')) {
      batch.delete(_plans.doc(p.id));
    }
    _fire(batch.commit());
  }

  // ── Body
  Stream<List<BodyEntry>> body() =>
      _body.orderBy('date').snapshots().map((q) => q.docs.map((d) => BodyEntry.fromMap(d.id, d.data())).toList());
  void saveBody(BodyEntry e) => _fire(_body.doc(e.id).set(e.toMap()));
  void deleteBody(String id) => _fire(_body.doc(id).delete());

  // ── Goals
  Stream<List<Goal>> goals() => _goals.snapshots().map((q) => q.docs.map((d) => Goal.fromMap(d.id, d.data())).toList());
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

  /// Saves several templates in one batch (e.g. new order after drag & drop).
  void saveTemplates(List<WorkoutTemplate> list) {
    final batch = _db.batch();
    for (final t in list) {
      batch.set(_templates.doc(t.id), t.toMap());
    }
    _fire(batch.commit());
  }

  void deleteTemplates(Iterable<String> ids) {
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_templates.doc(id));
    }
    _fire(batch.commit());
  }

  void saveFolderOrder(List<String> folders) => _fire(_user.set({'folderOrder': folders}, SetOptions(merge: true)));
}
