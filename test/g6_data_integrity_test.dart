import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/auth/login_page.dart' show authErrorMessage;
import 'package:strive/features/shell/account.dart';
import 'package:strive/features/shell/guest_switch.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/app_check.dart';
import 'package:strive/services/google_auth.dart';
import 'package:strive/services/guest_merge.dart';
import 'package:strive/services/notification_service.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/services/workout_store.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// G6 data integrity & security: account switch of a guest (data-1), sign-out with unsent writes
// (data-2), workout files bound to their account (data-3), App Check (data-5), incremental
// snapshot parsing (data-6), shared-program rules (data-7), reminders across time zones (data-8).

class _FakeUser implements User {
  _FakeUser({this.anonymous = false});
  final bool anonymous;

  @override
  bool get isAnonymous => anonymous;

  @override
  String get uid => anonymous ? 'guest' : 'user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LinkedGym extends ActiveGymNotifier {
  @override
  ActiveGym? build() =>
      ActiveGym(title: 'Push A', templateId: 'tpl', planId: 'open', start: DateTime(2026, 11, 17, 9), exercises: const []);
}

/// No recording (and no wakelock call when the container is disposed).
class _IdleTracker extends TrackerNotifier {
  @override
  CardioState? build() => null;
}

class _RunningGym extends ActiveGymNotifier {
  @override
  ActiveGym? build() => ActiveGym(title: 'Push A', start: DateTime(2026, 11, 17, 9), exercises: const []);
}

Map<String, dynamic> _session(String sport, {String? planId, String? templateId, String? externalId}) => {
  'sport': sport,
  'title': sport,
  'start': Timestamp.fromDate(DateTime(2026, 11, 1)),
  'durationSec': 1800,
  'planId': planId,
  'templateId': templateId,
  if (externalId != null) 'externalId': externalId,
};

Map<String, dynamic> _plan(String status, {String? sessionId, String? templateId, Map<String, dynamic>? auto}) => {
  'date': '2026-11-01',
  'sport': 'run',
  'title': 'Easy run',
  'status': status,
  'sessionId': sessionId,
  'templateId': templateId,
  if (auto != null) 'auto': auto,
};

Map<String, dynamic> _template(String? key, {int sets = 3}) => {
  'name': 'Upper A',
  'sport': 'gym',
  if (key != null) 'key': key,
  'exercises': [
    {
      'exId': 'bench',
      'name': 'Bench press',
      'sets': List.filled(sets, {'reps': 8}),
    },
  ],
};

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  group('data-1: a guest whose Google account already has Strive data', () {
    var n = 0;
    String newId() => 'n${n++}';
    setUp(() => n = 0);

    final guest = AccountData(
      user: {'name': 'Guest', 'onboarded': true},
      collections: {
        'sessions': [
          ('s1', _session('run', planId: 'p1')),
          ('s2', _session('gym', templateId: 't1')),
          ('s3', _session('gym', templateId: 't2')),
          ('s4', _session('run', externalId: 'hc-1')),
        ],
        'plans': [
          ('p1', _plan('done', sessionId: 's1', auto: {'sessionId': 's1', 'reason': 'longHard'})),
          ('p2', _plan('skipped')),
          ('p3', _plan('planned')),
        ],
        'templates': [('t1', _template('ul_upper_a')), ('t2', _template(null)), ('t3', _template('ul_lower_a', sets: 5))],
        'body': [
          ('b1', {'date': Timestamp.fromDate(DateTime(2026, 11, 1)), 'weightKg': 80}),
        ],
        'goals': [
          ('g1', {'type': 'event', 'title': 'Marathon'}),
          ('g2', {'type': 'frequency', 'title': '3x'}),
        ],
        'planLog': [('l1', <String, dynamic>{})],
      },
    );

    test('target with a profile: its profile and plan stay, the guest history comes along re-linked', () {
      final target = AccountData(
        user: {'name': 'Google', 'onboarded': true},
        collections: {
          'templates': [('T1', _template('ul_upper_a')), ('T3', _template('ul_lower_a'))],
          'sessions': [('X', _session('run', externalId: 'hc-1'))],
        },
      );
      final t = guestTransfer(guest: guest, target: target, newId: newId, today: DateTime(2026, 11, 17));
      Map<String, Map<String, dynamic>> of(String c) => {
        for (final (cc, id, d) in t.writes)
          if (cc == c) id: d,
      };

      // Never the user document (profile) and never the open plan or the plan history; of
      // the plan only the completed entry its workout links to (data-1b).
      expect(t.writes.where((w) => w.$1.isEmpty || w.$1 == 'planLog'), isEmpty);
      final plans = of('plans');
      expect(plans.values.map((p) => p['status']), ['done']);

      // The Health Connect workout the target already has is not copied twice.
      final sessions = of('sessions');
      expect(sessions.length, 3);
      expect(t.sessions, 3);
      expect(sessions.values.where((s) => s['externalId'] == 'hc-1'), isEmpty);

      // Fresh ids everywhere, links re-pointed both ways.
      final ids = [for (final w in t.writes) w.$2];
      expect(ids.toSet().length, ids.length);
      expect(ids.any((id) => ['s1', 's2', 's3', 'p1', 'p2', 't1', 't2', 't3', 'b1', 'g2'].contains(id)), isFalse);
      final run = sessions.entries.firstWhere((e) => e.value['sport'] == 'run');
      final done = plans.entries.firstWhere((e) => e.value['status'] == 'done');
      expect(run.value['planId'], done.key);
      expect(done.value['sessionId'], run.key);
      expect((done.value['auto'] as Map)['sessionId'], run.key);

      // Same built-in → the target's program; own program → copied; changed built-in → own
      // program that still counts as the built-in (and never a second program with that key).
      final templates = of('templates');
      final gyms = sessions.values.where((s) => s['sport'] == 'gym').toList();
      expect(gyms.map((s) => s['templateId']), containsAll(['T1', isIn(templates.keys)]));
      expect(templates.length, 2);
      expect(templates.values.where((t) => t['key'] != null), isEmpty);
      expect(templates.values.where((t) => t['origKey'] == 'ul_lower_a').length, 1);

      // Body values and goals except the race goal.
      expect(of('body').length, 1);
      expect(of('goals').values.map((g) => g['type']), ['frequency']);
    });

    test('target without a finished setup: everything moves unchanged', () {
      final t = guestTransfer(guest: guest, target: const AccountData(), newId: newId, today: DateTime(2026, 11, 17));
      expect(t.writes.length, 1 + guest.documentCount);
      expect(t.writes.first, ('', '', guest.user));
      expect(t.writes.where((w) => w.$1 == 'plans').length, 3);
      expect(t.sessions, 4);
    });

    testWidgets('the choice dialog: take along / discard / cancel', (t) async {
      GuestDataChoice? choice;
      var closed = false;
      await t.pumpWidget(
        _app(
          Builder(
            builder:
                (c) => TextButton(
                  onPressed: () async {
                    choice = await showDialog<GuestDataChoice>(context: c, builder: (_) => const GuestExistsDialog());
                    closed = true;
                  },
                  child: const Text('go'),
                ),
          ),
          const [],
        ),
      );
      for (final (key, expected) in [
        ('guestExistsMerge', GuestDataChoice.merge),
        ('guestExistsDiscard', GuestDataChoice.discard),
        ('guestExistsCancel', null),
      ]) {
        closed = false;
        await t.tap(find.text('go'));
        await t.pumpAndSettle();
        expect(find.text(l.guestExistsTitle), findsOneWidget);
        await t.tap(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
        expect(closed, isTrue);
        expect(choice, expected);
      }
    });

    test('"Account saved" only after a real link: no silent sign-in for a guest', () {
      final src = File('lib/services/google_auth.dart').readAsStringSync();
      final link = src.substring(src.indexOf('static Future<GuestLinkResult> linkGuest()'));
      expect(link.substring(0, link.indexOf('\n  }\n')).contains('signInWithCredential'), isFalse);
      final profile = File('lib/features/profile/profile_page.dart').readAsStringSync();
      expect(profile.contains('GoogleAuth.signIn()'), isFalse);
    });
  });

  group('data-1a…e: taking the guest data along, follow-up', () {
    var n = 0;
    String newId() => 'n${n++}';
    setUp(() => n = 0);
    final today = DateTime(2026, 11, 17); // Tuesday; the week starts on Monday 16th
    const onboarded = {'name': 'Google', 'onboarded': true};

    List<Doc> builtins(String goal, {bool de = false, String prefix = 'g', Set<String> skip = const {}}) {
      var i = 0;
      return [
        for (final t in defaultTemplates(() => '$prefix${i++}', de: de, goal: goal))
          if (!skip.contains(t.key)) (t.id, t.toMap()),
      ];
    }

    Map<String, Map<String, dynamic>> of(GuestTransfer t, String c) => {
      for (final (cc, id, d) in t.writes)
        if (cc == c) id: d,
    };

    test('1a: untouched built-ins of another goal map to the target\'s – no "Full Body A" twice', () {
      for (final (guestGoal, targetGoal) in [('hypertrophy', 'strength'), ('strength', 'general'), ('general', 'hypertrophy')]) {
        for (final de in [false, true]) {
          final guestT = builtins(guestGoal, de: de);
          // The target deleted one built-in: the guest's copy of it stays behind (the plan adds
          // missing built-ins itself), it does not come along as an own program.
          final targetT = builtins(targetGoal, prefix: 'T', skip: {'bro_arms'});
          final t = guestTransfer(
            guest: AccountData(user: const {'onboarded': true}, collections: {'templates': guestT}),
            target: AccountData(user: onboarded, collections: {'templates': targetT}),
            newId: newId,
            today: today,
          );
          expect(of(t, 'templates'), isEmpty, reason: '$guestGoal → $targetGoal (de: $de)');
          final targetIdByKey = {for (final (id, d) in targetT) d['key']: id};
          for (final (id, d) in guestT) {
            expect(t.relink(id), targetIdByKey[d['key']], reason: '${d['key']}');
          }
        }
      }
    });

    test('1a: a used built-in (own loads) maps too; an edited one comes along renamed "(custom)"', () {
      final guestT = builtins('hypertrophy');
      final fbIdx = guestT.indexWhere((d) => d.$2['key'] == 'fb_a');
      final fb = guestT[fbIdx].$2;
      final ex = [for (final e in fb['exercises'] as List) Map<String, dynamic>.from(e as Map)];
      // Loads entered → still the built-in.
      final loaded = {
        ...fb,
        'exercises': [
          for (final e in ex)
            {
              ...e,
              'sets': [for (final s in e['sets'] as List) Map<String, dynamic>.from(s as Map)..['w'] = 40.0],
            },
        ],
      };
      // An exercise removed → the user's own version.
      final edited = {...fb, 'exercises': ex.sublist(1)};
      final t = guestTransfer(
        guest: AccountData(
          user: const {'onboarded': true},
          collections: {
            'templates': [('loaded', loaded), ('edited', edited), ('own', _template(null)..['name'] = 'Upper A')],
          },
        ),
        target: AccountData(
          user: onboarded,
          collections: {
            'templates': [...builtins('strength', prefix: 'T'), ('Town', _template(null)..['name'] = 'Upper A')],
          },
        ),
        newId: newId,
        today: today,
        ownSuffix: 'custom',
      );
      final copies = of(t, 'templates');
      expect(t.relink('loaded'), isNot(isIn(copies.keys)));
      expect(t.relink('loaded'), isNotNull);
      expect(copies.length, 2);
      final e = copies[t.relink('edited')]!;
      expect(e['name'], 'Full Body A (custom)');
      expect(e['key'], isNull);
      expect(e['origKey'], 'fb_a');
      expect(e['folder'], fb['folder']);
      // An own program whose name the target already uses in that folder.
      expect(copies[t.relink('own')]!['name'], 'Upper A 2');
    });

    test('1a: a German guest\'s edited built-in goes to the English target\'s standard folder', () {
      final guestT = builtins('general', de: true);
      final fb = guestT.firstWhere((d) => d.$2['key'] == 'fb_a').$2;
      final edited = {...fb, 'exercises': (fb['exercises'] as List).sublist(1)};
      final targetT = builtins('general', prefix: 'T');
      final t = guestTransfer(
        guest: AccountData(
          user: const {'onboarded': true},
          collections: {
            'templates': [('edited', edited)],
          },
        ),
        target: AccountData(user: onboarded, collections: {'templates': targetT}),
        newId: newId,
        today: today,
      );
      final copy = of(t, 'templates').values.single;
      expect(copy['folder'], targetT.firstWhere((d) => d.$2['key'] == 'fb_a').$2['folder']);
      expect(copy['name'], '${fb['name']} (custom)');
    });

    Map<String, dynamic> plan(String status, String date, {String? sessionId}) => {..._plan(status, sessionId: sessionId), 'date': date};

    test('1b: only completed history before this week, in weeks without a target plan', () {
      final t = guestTransfer(
        guest: AccountData(
          user: const {'onboarded': true},
          collections: {
            'sessions': [
              ('s1', _session('run', planId: 'old')),
              ('s2', _session('run', planId: 'thisWeek')),
              ('s3', _session('run', planId: 'clash')),
            ],
            'plans': [
              ('old', plan('done', '2026-11-03', sessionId: 's1')),
              ('thisWeek', plan('done', '2026-11-16', sessionId: 's2')),
              ('clash', plan('done', '2026-11-10', sessionId: 's3')),
              ('noSession', plan('done', '2026-11-02')),
              ('skippedPast', plan('skipped', '2026-11-04')),
              ('skippedFuture', plan('skipped', '2026-11-25')),
              ('planned', plan('planned', '2026-11-20')),
            ],
          },
        ),
        target: AccountData(
          user: onboarded,
          collections: {
            'plans': [('tp', plan('planned', '2026-11-12'))],
          },
        ),
        newId: newId,
        today: today,
      );
      final plans = of(t, 'plans');
      expect(plans.values.map((p) => p['date']), ['2026-11-03']);
      expect(t.relink('old'), plans.keys.single);
      final sessions = of(t, 'sessions');
      expect(sessions.length, 3);
      // Workouts without a copied entry come along unlinked (extra training in the target).
      expect(sessions.values.map((s) => s['planId']).toList()..sort((a, b) => '$a'.compareTo('$b')), [plans.keys.single, null, null]);
      expect(t.relink('thisWeek'), isNull);
    });

    test('1c: the workout in progress is re-pointed to the copied program; the open plan stayed behind', () async {
      final t = GuestTransfer(const [], sessions: 0, ids: const {'tpl': 'T9'});
      final c = ProviderContainer(
        overrides: [activeGymProvider.overrideWith(_LinkedGym.new), trackerProvider.overrideWith(_IdleTracker.new)],
      );
      addTearDown(c.dispose);
      relinkActiveWorkout(c, t.relink);
      expect(c.read(activeGymProvider)!.templateId, 'T9');
      expect(c.read(activeGymProvider)!.planId, isNull);
      expect(c.read(activeGymProvider)!.title, 'Push A');

      // The stored copy (and an unsaved summary) as well.
      final store = MemoryWorkoutStore(() => 'guest');
      await store.saveGym(
        ActiveGym(title: 'Push A', templateId: 'tpl', planId: 'p', start: DateTime(2026, 11, 17, 9), exercises: const []),
      );
      await store.saveSummary(
        Session(id: 'd', sport: Sport.gym, title: 'Push A', start: DateTime(2026, 11, 17), durationSec: 60, templateId: 'tpl', planId: 'p'),
      );
      await store.reassign('guest', 'google', relink: t.relink);
      store.owner = () => 'google';
      final g = (await store.loadActive())!.gym!;
      expect((g.templateId, g.planId), ('T9', null));
      final s = (await store.loadSummary())!;
      expect((s.templateId, s.planId), ('T9', null));

      // Cardio recordings carry the planned workout only.
      final cardio = CardioState(sport: Sport.run, title: 'Run', planId: 'p', start: DateTime(2026, 11, 17));
      expect(cardio.copyWith(relink: t.relink).planId, isNull);
      expect(cardio.copyWith().planId, 'p');
    });

    test('1d: a Health Connect duplicate links to the target\'s workout; deleted ones stay deleted', () {
      final t = guestTransfer(
        guest: AccountData(
          user: const {
            'onboarded': true,
            'hcDeleted': ['hc-gone', 'hc-shared'],
          },
          collections: {
            'sessions': [
              ('s1', _session('run', planId: 'p1', externalId: 'hc-1')),
              ('s2', _session('run', externalId: 'hc-del')),
              ('s3', _session('run', planId: 'p3', externalId: 'hc-claimed')),
            ],
            'plans': [('p1', plan('done', '2026-11-03', sessionId: 's1')), ('p3', plan('done', '2026-10-27', sessionId: 's3'))],
          },
        ),
        target: AccountData(
          user: const {
            ...onboarded,
            'hcDeleted': ['hc-del', 'hc-shared'],
          },
          collections: {
            'sessions': [('X1', _session('run', externalId: 'hc-1')), ('X3', _session('run', planId: 'TP', externalId: 'hc-claimed'))],
          },
        ),
        newId: newId,
        today: today,
      );
      // Nothing copied twice, nothing the target deleted comes back.
      expect(of(t, 'sessions'), isEmpty);
      // The completed entry points to the target's copy of the workout; one the target's own
      // plan already claims is not taken along.
      final plans = of(t, 'plans');
      expect(plans.values.map((p) => p['sessionId']), ['X1']);
      // The guest's deleted imports are added to the target's list.
      final user = t.writes.where((w) => w.$1.isEmpty).single.$3;
      expect((user['hcDeleted'] as List).toSet(), {'hc-del', 'hc-shared', 'hc-gone'});
      expect(user.keys, ['hcDeleted']);
    });

    test('1d: the guest\'s cached documents are cleared before the account signs in', () {
      final src = File('lib/features/shell/guest_switch.dart').readAsStringSync();
      final sw = src.substring(src.indexOf('Future<void> switchFromGuest('));
      expect(sw.indexOf('await clearLocalCache()'), greaterThan(sw.indexOf('deleteGuestAccount(guest)')));
      expect(sw.indexOf('await clearLocalCache()'), lessThan(sw.indexOf('FirebaseAuth.instance.signInWithCredential(cred)')));
      // Discarding: the sign-in (e-mail: the password) is checked before the guest data is deleted.
      expect(sw.indexOf('_inTransferApp(cred'), lessThan(sw.indexOf('deleteGuestAccount(guest)')));
    });

    test('1e: an e-mail address that already has an account offers the same choice', () {
      final src = File('lib/features/shell/guest_switch.dart').readAsStringSync();
      final email = src.substring(src.indexOf('Future<void> linkGuestWithEmailCredential('));
      expect(email.indexOf('resolveGuestAccountExists(context, cred)'), greaterThan(email.indexOf('isAccountTakenCode(e.code)')));
      expect(File('lib/features/profile/profile_page.dart').readAsStringSync(), contains('linkGuestWithEmailCredential(context'));
      expect(GoogleAuth.isAccountTakenCode('email-already-in-use'), isTrue);
      // Other errors read as text, not as a bare code.
      expect(authErrorMessage(l, 'wrong-password'), l.authWrongCredentials);
      expect(authErrorMessage(l, 'weak-password'), l.authWeakPassword);
      expect(wrongCredentialCodes, containsAll(['wrong-password', 'invalid-credential']));
      // The dialog no longer speaks of a Google account only.
      expect(l.guestExistsTitle.contains('Google'), isFalse);
    });
  });

  group('data-2 / data-3: signing out', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    tearDown(() {
      pendingWritesFlush = () async {};
      pendingWritesTimeout = const Duration(seconds: 10);
      signedInUser = () => null;
    });

    Future<bool?> run(WidgetTester t, {List<Override> extra = const []}) async {
      bool? result;
      await t.pumpWidget(
        _app(Builder(builder: (c) => TextButton(onPressed: () async => result = await readyToSignOut(c), child: const Text('out'))), [
          prefsProvider.overrideWithValue(prefs),
          workoutStoreProvider.overrideWithValue(MemoryWorkoutStore(() => 'user')),
          ...extra,
        ]),
      );
      await t.tap(find.text('out'));
      await t.pump();
      return result;
    }

    testWidgets('changes reach the server: no question', (t) async {
      signedInUser = () => _FakeUser();
      var flushed = false;
      pendingWritesFlush = () async => flushed = true;
      await run(t);
      await t.pumpAndSettle();
      expect(flushed, isTrue);
      expect(find.text(l.signOutUnsyncedTitle), findsNothing);
    });

    testWidgets('offline (queue not sent): the user is told the changes are lost and may cancel', (t) async {
      signedInUser = () => _FakeUser();
      pendingWritesFlush = () => Completer<void>().future; // never completes
      pendingWritesTimeout = const Duration(seconds: 2);
      bool? result;
      await t.pumpWidget(
        _app(Builder(builder: (c) => TextButton(onPressed: () async => result = await readyToSignOut(c), child: const Text('out'))), [
          prefsProvider.overrideWithValue(prefs),
        ]),
      );
      await t.tap(find.text('out'));
      await t.pump();
      expect(find.text(l.signOutSyncing), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text(l.signOutUnsyncedTitle), findsOneWidget);
      await t.tap(find.text(l.cancel));
      await t.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('guest: the guest dialog said everything is deleted – no sync wait', (t) async {
      signedInUser = () => _FakeUser(anonymous: true);
      var flushed = false;
      pendingWritesFlush = () async => flushed = true;
      await run(t);
      await t.pumpAndSettle();
      expect(flushed, isFalse);
    });

    testWidgets('a running workout: signing out ends it – asked first', (t) async {
      signedInUser = () => null;
      bool? result;
      await t.pumpWidget(
        _app(Builder(builder: (c) => TextButton(onPressed: () async => result = await readyToSignOut(c), child: const Text('out'))), [
          prefsProvider.overrideWithValue(prefs),
          activeGymProvider.overrideWith(_RunningGym.new),
        ]),
      );
      await t.tap(find.text('out'));
      await t.pumpAndSettle();
      expect(find.text(l.signOutWorkoutTitle), findsOneWidget);
      await t.tap(find.text(l.cancel));
      await t.pumpAndSettle();
      expect(result, isFalse);
    });

    test('the stored workout and summary are deleted and the workout ends', () async {
      final store = MemoryWorkoutStore(() => 'user');
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          workoutStoreProvider.overrideWithValue(store),
          activeGymProvider.overrideWith(_RunningGym.new),
        ],
      );
      addTearDown(c.dispose);
      await store.saveGym(c.read(activeGymProvider)!);
      await store.saveSummary(Session(id: 'x', sport: Sport.run, title: 'Run', start: DateTime(2026, 11, 17), durationSec: 60));
      expect(workoutInProgress(c), isTrue);
      await discardLocalWorkout(c);
      expect(store.active, isNull);
      expect(store.summary, isNull);
    });

    test('per-account prefs of the signed-out account are removed, others stay', () async {
      await prefs.setString('gcal_abc123_account', 'a@b.c');
      await prefs.setString('gcal_zzz_account', 'x@y.z');
      await prefs.setBool('theme', true);
      await removeAccountPrefs(prefs, 'abc123');
      expect(prefs.getKeys(), {'gcal_zzz_account', 'theme'});
      await removeAccountPrefs(prefs, '');
      expect(prefs.getKeys().length, 2);
    });
  });

  group('data-3: the workout files belong to one account', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('strive_owner'));
    tearDown(() => dir.deleteSync(recursive: true));

    final gym = ActiveGym(title: 'Push A', start: DateTime(2026, 11, 17, 9), exercises: const []);
    final draft = Session(
      id: 'd',
      sport: Sport.run,
      title: 'Run',
      start: DateTime(2026, 11, 17),
      durationSec: 60,
      route: const [
        [52.0, 13.0],
      ],
    );

    test('another account on this phone is never offered the workout or the summary', () async {
      var who = 'A';
      final store = FileWorkoutStore(() async => dir, () => who);
      await store.saveGym(gym);
      await store.saveSummary(draft);
      expect((await store.loadActive())?.gym?.title, 'Push A');
      expect((await store.loadSummary())?.id, 'd');
      who = 'B';
      expect(await store.loadActive(), isNull);
      expect(await store.loadSummary(), isNull);
      // Signed out: nobody's.
      expect(await FileWorkoutStore(() async => dir, () => null).loadActive(), isNull);
    });

    test('files of older versions (no uid) stay valid', () async {
      File('${dir.path}/summary.json').writeAsStringSync('{"v":1,"data":{"id":"old","sport":"run","start":0}}');
      expect((await FileWorkoutStore(() async => dir, () => 'A').loadSummary())?.id, 'old');
    });

    test('guest data taken along: the stored workout moves to the new account', () async {
      final store = FileWorkoutStore(() async => dir, () => 'guest');
      await store.saveGym(gym);
      await store.saveSummary(draft);
      await store.reassign('guest', 'google');
      final after = FileWorkoutStore(() async => dir, () => 'google');
      expect((await after.loadActive())?.gym?.title, 'Push A');
      expect((await after.loadSummary())?.id, 'd');
      expect(await FileWorkoutStore(() async => dir, () => 'guest').loadActive(), isNull);
    });

    test('memory store: same rules', () async {
      var who = 'A';
      final store = MemoryWorkoutStore(() => who);
      await store.saveGym(gym);
      who = 'B';
      expect(await store.loadActive(), isNull);
      await store.reassign('A', 'B');
      expect(await store.loadActive(), isNotNull);
    });
  });

  group('data-5: App Check', () {
    test('Play Integrity in release builds, the debug provider otherwise', () {
      expect(appCheckAndroidProvider(release: true), AndroidProvider.playIntegrity);
      expect(appCheckAndroidProvider(release: false), AndroidProvider.debug);
      expect(appCheckAppleProvider(release: false), AppleProvider.debug);
    });

    test('a token that cannot be obtained never fails the request on the client', () async {
      expect(await FailSoftAppCheck(fetch: (_) async => throw Exception('App attestation failed')).getToken(), isNull);
      expect(await FailSoftAppCheck(fetch: (_) async => 'tok').getToken(), 'tok');
    });

    test('every Gemini call goes through striveAI (App Check attached); activated before runApp', () {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.path.replaceAll('\\', '/').endsWith('services/app_check.dart')) continue;
        expect(f.readAsStringSync().contains('FirebaseAI.googleAI('), isFalse, reason: f.path);
      }
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.indexOf('await activateAppCheck()'), greaterThan(main.indexOf('Firebase.initializeApp')));
      expect(main.indexOf('await activateAppCheck()'), lessThan(main.indexOf('runApp(')));
      expect(File('docs/app-check.md').existsSync(), isTrue);
    });
  });

  group('data-6: snapshots parse only what changed', () {
    test('an edit of one session parses one document, unchanged ones keep their object', () {
      var parses = 0;
      final docs = IncrementalDocs<Session>((id, m) {
        parses++;
        return Session.tryFromMap(id, m);
      });
      Map<String, dynamic> s(int i) => {'sport': 'run', 'title': 'r$i', 'start': Timestamp.fromDate(DateTime(2026, 1, 1 + i))};
      final ids = [for (var i = 0; i < 200; i++) 'id$i'];
      final first = docs.apply([for (var i = 0; i < 200; i++) (ids[i], s(i))], ids, (_) => null);
      expect(parses, 200);
      expect(first.length, 200);
      final second = docs.apply(
        [
          ('id5', {...s(5), 'notes': 'x'}),
        ],
        ids,
        (_) => null,
      );
      expect(parses, 201);
      expect(second[5].notes, 'x');
      expect(identical(second[6], first[6]), isTrue);
      final third = docs.apply([('id7', null)], [...ids]..remove('id7'), (_) => null);
      expect(third.length, 199);
      expect(parses, 201);
      // A stray / corrupt document is skipped, not the stream.
      final fourth = docs.apply(
        [
          ('bad', {'title': 'stray'}),
        ],
        ['bad', ...ids]..remove('id7'),
        (_) => null,
      );
      expect(fourth.length, 199);
    });
  });

  group('data-7: shared programs', () {
    test('rules: get by code, list only the own programs', () {
      final rules = File('firestore.rules').readAsStringSync();
      final shared = rules.substring(rules.indexOf('match /shared/{code}'));
      expect(shared.contains('allow read'), isFalse);
      expect(shared.contains('allow get: if request.auth != null;'), isTrue);
      expect(shared.contains('allow list: if request.auth != null && resource.data.owner == request.auth.uid;'), isTrue);
    });

    test('the shared document carries no name of the owner', () {
      final t = WorkoutTemplate(id: 't', name: 'Upper', sport: Sport.gym, exercises: const []);
      final d = Repository.sharedTemplateDoc(t, 'uid1');
      expect(d.containsKey('ownerName'), isFalse);
      expect(d['owner'], 'uid1');
      expect(d['name'], 'Upper');
    });
  });

  group('data-8: training reminders follow the time zone', () {
    setUpAll(tzdata.initializeTimeZones);

    PlannedWorkout plan(DateTime d, {String status = 'planned'}) =>
        PlannedWorkout(id: '$d', date: d, sport: Sport.run, title: 'Run', durationMin: 40, status: status);

    test('08:00 is 08:00 local wherever the phone is', () {
      final plans = [plan(DateTime(2026, 11, 18)), plan(DateTime(2026, 11, 19)), plan(DateTime(2026, 11, 18), status: 'done')];
      for (final zone in ['Europe/Berlin', 'America/New_York', 'Asia/Tokyo']) {
        final loc = tz.getLocation(zone);
        final now = tz.TZDateTime(loc, 2026, 11, 17, 20);
        final times = trainingReminderTimes(plans, hour: 8, minute: 0, now: now);
        expect(times.length, 2, reason: zone);
        for (final (_, t) in times) {
          expect((t.location.name, t.hour, t.minute), (zone, 8, 0));
        }
      }
      // The same instant scheduled in Berlin rings at 02:00 in New York – why a zone change reschedules.
      final berlin = tz.TZDateTime(tz.getLocation('Europe/Berlin'), 2026, 11, 18, 8);
      expect(tz.TZDateTime.from(berlin, tz.getLocation('America/New_York')).hour, 2);
    });

    test('window: from today (not past times) up to 14 days ahead', () {
      final loc = tz.getLocation('Europe/Berlin');
      final now = tz.TZDateTime(loc, 2026, 11, 17, 9);
      final plans = [plan(DateTime(2026, 11, 16)), plan(DateTime(2026, 11, 17)), plan(DateTime(2026, 12, 1)), plan(DateTime(2026, 12, 2))];
      final days = [for (final (p, _) in trainingReminderTimes(plans, hour: 8, minute: 0, now: now)) p.date.day];
      expect(days, [1]); // 17th 08:00 already past, 2 Dec is 15 days ahead
    });

    test('useTimeZone switches the local zone, unknown ids keep it', () {
      expect(useTimeZone('Asia/Tokyo'), isTrue);
      expect(tz.local.name, 'Asia/Tokyo');
      expect(useTimeZone('Asia/Tokyo'), isFalse);
      expect(useTimeZone('Not/AZone'), isFalse);
      expect(tz.local.name, 'Asia/Tokyo');
    });

    test('the reminder sync follows the day and the device zone', () {
      final src = File('lib/features/shell/reminder_sync.dart').readAsStringSync();
      expect(src.contains('ref.watch(todayProvider)'), isTrue);
      expect(src.contains('ref.watch(deviceTimeZoneProvider)'), isTrue);
      expect(src.contains('timeZone: zone'), isTrue);
    });
  });
}
