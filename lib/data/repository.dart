import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/sport.dart';
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
  Future<String?> gcalCalendarId(String account) async {
    try {
      final d = await _user.get();
      final m = d.data()?['gcalCalendars'];
      return m is Map ? m[account] as String? : null;
    } catch (e) {
      debugPrint('gcal id lookup failed: $e');
      return null;
    }
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
        q.docs.map((d) => WorkoutTemplate.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
  void saveTemplate(WorkoutTemplate t) => _fire(_templates.doc(t.id).set(t.toMap()));
  void deleteTemplate(String id) => _fire(_templates.doc(id).delete());

  // ── Plans
  Stream<List<PlannedWorkout>> plans() => _plans.snapshots().map(
    (q) => q.docs.map((d) => PlannedWorkout.fromMap(d.id, d.data())).toList()..sort((a, b) => a.date.compareTo(b.date)),
  );
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

  /// Default programs created for new users.
  void seedTemplates(TrainingFocus focus) {
    for (final t in defaultTemplates(newId)) {
      saveTemplate(t);
    }
  }
}

GymExercise _ex(String id, String name, int sets, int reps, {double w = 0, int rest = 90}) =>
    GymExercise(exId: id, name: name, restSec: rest, sets: List.generate(sets, (_) => GymSet(weight: w, reps: reps)));

List<WorkoutTemplate> defaultTemplates(String Function() id) => [
  WorkoutTemplate(
    id: id(),
    name: 'Push',
    sport: Sport.gym,
    folder: 'Push Pull Legs',
    exercises: [
      _ex('0025', 'barbell bench press', 4, 8, rest: 150),
      _ex('0314', 'dumbbell incline bench press', 3, 10),
      _ex('0405', 'dumbbell seated shoulder press', 3, 10),
      _ex('0334', 'dumbbell lateral raise', 3, 15, rest: 60),
      _ex('0241', 'cable triceps pushdown (v-bar)', 3, 12, rest: 60),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Pull',
    sport: Sport.gym,
    folder: 'Push Pull Legs',
    exercises: [
      _ex('0652', 'pull-up', 4, 8, rest: 150),
      _ex('0027', 'barbell bent over row', 4, 8, rest: 120),
      _ex('2330', 'cable lat pulldown full range of motion', 3, 12),
      _ex('0203', 'cable rear delt row (with rope)', 3, 15, rest: 60),
      _ex('0031', 'barbell curl', 3, 10, rest: 60),
      _ex('0313', 'dumbbell hammer curl', 3, 12, rest: 60),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Legs',
    sport: Sport.gym,
    folder: 'Push Pull Legs',
    exercises: [
      _ex('0043', 'barbell full squat', 4, 6, rest: 180),
      _ex('0085', 'barbell romanian deadlift', 3, 10, rest: 120),
      _ex('0739', 'sled 45° leg press', 3, 12),
      _ex('0586', 'lever lying leg curl', 3, 12, rest: 60),
      _ex('0594', 'lever seated calf raise', 4, 15, rest: 60),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Upper',
    sport: Sport.gym,
    folder: 'Upper / Lower',
    exercises: [
      _ex('0025', 'barbell bench press', 4, 6, rest: 150),
      _ex('0027', 'barbell bent over row', 4, 8, rest: 120),
      _ex('0426', 'dumbbell standing overhead press', 3, 10),
      _ex('2330', 'cable lat pulldown full range of motion', 3, 10),
      _ex('0031', 'barbell curl', 2, 12, rest: 60),
      _ex('0241', 'cable triceps pushdown (v-bar)', 2, 12, rest: 60),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Lower',
    sport: Sport.gym,
    folder: 'Upper / Lower',
    exercises: [
      _ex('0032', 'barbell deadlift', 3, 5, rest: 180),
      _ex('1760', 'dumbbell goblet squat', 3, 10),
      _ex('0336', 'dumbbell lunge', 3, 10),
      _ex('0585', 'lever leg extension', 3, 12, rest: 60),
      _ex('0472', 'hanging leg raise', 3, 12, rest: 60),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Full Body A',
    sport: Sport.gym,
    folder: 'Full Body',
    exercises: [
      _ex('0043', 'barbell full squat', 3, 8, rest: 150),
      _ex('0025', 'barbell bench press', 3, 8, rest: 120),
      _ex('0861', 'cable seated row', 3, 10),
      _ex('0274', 'crunch floor', 3, 15, rest: 45),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Full Body B',
    sport: Sport.gym,
    folder: 'Full Body',
    exercises: [
      _ex('0032', 'barbell deadlift', 3, 5, rest: 180),
      _ex('0426', 'dumbbell standing overhead press', 3, 10),
      _ex('0652', 'pull-up', 3, 8, rest: 120),
      _ex('0662', 'push-up', 3, 15, rest: 60),
    ],
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Easy Run',
    sport: Sport.run,
    folder: 'Running',
    targetMin: 40,
    intensity: 'easy',
    description: 'Zone 2 – conversational pace.',
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Intervals 6×800 m',
    sport: Sport.run,
    folder: 'Running',
    targetMin: 50,
    intensity: 'intervals',
    description: '15 min warm-up · 6×800 m @ 5k pace, 2 min jog · 10 min cool-down',
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Long Run',
    sport: Sport.run,
    folder: 'Running',
    targetMin: 80,
    intensity: 'long',
    description: 'Steady, easy effort. Fuel every 40 min.',
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Endurance Ride',
    sport: Sport.ride,
    folder: 'Cycling',
    targetMin: 90,
    intensity: 'easy',
    description: 'Zone 2, high cadence (85–95 rpm).',
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Sweet Spot 3×12',
    sport: Sport.ride,
    folder: 'Cycling',
    targetMin: 60,
    intensity: 'tempo',
    description: '3×12 min @ 88–94 % FTP, 4 min easy between.',
  ),
  WorkoutTemplate(
    id: id(),
    name: 'Technique Swim',
    sport: Sport.swim,
    folder: 'Swimming',
    targetMin: 40,
    targetKm: 1.5,
    intensity: 'technique',
    description: '300 warm-up · 8×50 drills · 6×100 steady · 200 cool-down',
  ),
  WorkoutTemplate(
    id: id(),
    name: 'CSS Intervals',
    sport: Sport.swim,
    folder: 'Swimming',
    targetMin: 50,
    targetKm: 2.2,
    intensity: 'intervals',
    description: '400 warm-up · 10×100 @ CSS, 15 s rest · 300 pull · 200 cool-down',
  ),
];
