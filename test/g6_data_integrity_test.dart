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
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/shell/account.dart';
import 'package:strive/features/shell/guest_switch.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/app_check.dart';
import 'package:strive/services/guest_merge.dart';
import 'package:strive/services/notification_service.dart';
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
      final t = guestTransfer(guest: guest, target: target, newId: newId);
      Map<String, Map<String, dynamic>> of(String c) => {
        for (final (cc, id, d) in t.writes)
          if (cc == c) id: d,
      };

      // Never the user document (profile) and never the open plan or the plan history.
      expect(t.writes.where((w) => w.$1.isEmpty || w.$1 == 'planLog'), isEmpty);
      final plans = of('plans');
      expect(plans.values.map((p) => p['status']).toSet(), {'done', 'skipped'});

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
      final t = guestTransfer(guest: guest, target: const AccountData(), newId: newId);
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
