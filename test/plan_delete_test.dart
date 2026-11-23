// Owner round 10: "When creating a new training plan, the old one should be deleted" and "a button to delete the
// current training plan". Decision: completed workouts (recordings, stats, records, their links) stay; every open
// workout of the old plan goes – also missed past ones, skipped ones, refills and leftovers of older plans.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/plan_log.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/calendar_page.dart';
import 'package:strive/features/calendar/plan_history_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/fitness_state.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_service.dart';

import 'adaptation_sim_test.dart' as a;

final de = lookupAppLocalizations(const Locale('de'));

/// In-memory plans: deletes / writes show up in [plans] (and the stream the calendar watches).
class _Repo extends Repository {
  _Repo(List<PlannedWorkout> initial) : docs = {for (final p in initial) p.id: p}, super('test');
  final Map<String, PlannedWorkout> docs;
  final _ctrl = StreamController<List<PlannedWorkout>>.broadcast();
  final removed = <String>[];
  final logs = <PlanLogEntry>[];
  UserProfile? savedProfile;
  var _id = 0;

  List<PlannedWorkout> get all => docs.values.toList()..sort(PlannedWorkout.compareByDay);
  Stream<List<PlannedWorkout>> watch() async* {
    yield all;
    yield* _ctrl.stream;
  }

  void _emit() => _ctrl.add(all);

  @override
  String newId() => 'n${_id++}';
  @override
  void saveProfile(UserProfile p) => savedProfile = p;
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async {}
  @override
  void logPlanChange(PlanLogEntry e) => logs.add(e);
  @override
  Future<void> deletePlans(Iterable<String> ids) async {
    removed.addAll(ids);
    ids.forEach(docs.remove);
    _emit();
  }

  @override
  Future<void> savePlans(List<PlannedWorkout> list) async {
    for (final p in list) {
      docs[p.id] = p;
    }
    _emit();
  }

  @override
  Future<void> replacePlans(Iterable<String> remove, List<PlannedWorkout> plan) async {
    removed.addAll(remove);
    remove.forEach(docs.remove);
    await savePlans(plan);
  }
}

void main() {
  final today = dayOnly(DateTime.now());
  final gen0 = newPlanGen(today.subtract(const Duration(days: 40)), 'old');
  final gen1 = newPlanGen(today.subtract(const Duration(days: 20)), 'cur');
  PlannedWorkout w(String id, int day, {String status = 'planned', String? gen, String? sessionId, String? phase = 'base'}) =>
      PlannedWorkout(
        id: id,
        date: addDays(today, day),
        sport: Sport.run,
        title: 'Lauf $id',
        durationMin: 40,
        distanceKm: 6,
        status: status,
        sessionId: sessionId,
        planGen: gen,
        phase: phase,
      );
  Session run(String id, int day, {String? planId, double km = 6, int min = 40}) => Session(
    id: id,
    sport: Sport.run,
    title: 'Lauf',
    start: addDays(today, day).add(const Duration(hours: 18)),
    durationSec: min * 60,
    distanceM: km * 1000,
    planId: planId,
  );

  // The calendar of an athlete 3 weeks into a plan, with an older plan's leftovers.
  final calendar = [
    w('done', -6, status: 'done', gen: gen1, sessionId: 's-done'), // completed: history
    w('linked', -4, gen: gen1), // a session was started from it and counts: history
    w('short', -2, status: 'done', gen: gen1, sessionId: 's-short'), // 2 of 40 min: "not counted" – open
    w('missed', -3, gen: gen1), // missed past workout
    w('skipped', 1, status: 'skipped', gen: gen1),
    w('future', 2, gen: gen1),
    w('refill', 3), // a refill of an older version (no generation)
    w('own', 4, phase: null), // added by the athlete
    w('old-leftover', 5, gen: gen0), // an older plan generation (stale cache on another device)
  ];
  final sessions = [
    run('s-done', -6, planId: 'done'),
    run('s-linked', -4, planId: 'linked'),
    run('s-short', -2, planId: 'short', km: 0.2, min: 2),
  ];
  final profile = withPlanMeta(a.marathoner(), addDays(today, -21), 12, gen: gen1);

  setUp(PlanService.reset);

  group('the old plan goes entirely', () {
    test('openWorkouts: every open workout of every date and origin; done and counted ones stay', () {
      final open = PlanService.openWorkouts(calendar, sessions, profile: profile).map((p) => p.id).toSet();
      expect(open, {'short', 'missed', 'skipped', 'future', 'refill', 'own', 'old-leftover'});
    });

    test('a new plan from today removes all open workouts – not only the planned ones from its start', () async {
      final repo = _Repo(calendar);
      final n = await PlanService.replacePlan(
        repo: repo,
        l: de,
        profile: profile,
        templates: const [],
        existing: calendar,
        sessions: sessions,
        start: today,
        weeks: 8,
        now: today,
      );
      expect(n, greaterThan(0));
      expect(repo.removed.toSet(), {'short', 'missed', 'skipped', 'future', 'refill', 'own', 'old-leftover'});
      expect(repo.docs.keys, containsAll(['done', 'linked']), reason: 'completed workouts stay as history');
      // Nothing of the old plan is left open: no overlapping duplicate plan.
      final gen = repo.savedProfile!.athlete.planGen!;
      expect(gen.compareTo(gen1), greaterThan(0));
      expect(repo.all.where((p) => !p.isDone && p.planGen != gen && !['linked'].contains(p.id)), isEmpty);
      expect(stalePlanWorkouts(repo.savedProfile!, repo.all, sessions), isEmpty);
    });

    test('review r10-N3: a plan starting later keeps the open workouts until then (the athlete finishes the week)', () async {
      final repo = _Repo(calendar);
      final start = addDays(today, 6);
      final n = await PlanService.replacePlan(
        repo: repo,
        l: de,
        profile: profile,
        templates: const [],
        existing: calendar,
        sessions: sessions,
        start: start,
        weeks: 8,
        now: today,
      );
      expect(n, greaterThan(0));
      // Missed past ones go (the old plan is deleted); today .. start-1 stay.
      expect(repo.removed.toSet(), {'short', 'missed'});
      expect(repo.docs.keys, containsAll(['done', 'linked', 'skipped', 'future', 'refill', 'own', 'old-leftover']));
      expect(repo.docs['skipped']!.status, 'skipped');
      expect(repo.all.where((p) => p.planGen != null && dayOnly(p.date).isBefore(start) && !p.isDone && p.id != 'linked').length, 3);
      // They move to the new generation: no device removes them as left over.
      final gen = repo.savedProfile!.athlete.planGen!;
      for (final id in ['skipped', 'future', 'old-leftover']) {
        expect(repo.docs[id]!.planGen, gen, reason: id);
      }
      expect(repo.docs['own']!.planGen, isNull, reason: "the athlete's own workout keeps no generation");
      expect(stalePlanWorkouts(repo.savedProfile!, repo.all, sessions), isEmpty);
      // The new plan starts on [start]: nothing of it before.
      expect(repo.all.where((p) => p.planGen == gen && dayOnly(p.date).isBefore(start)).map((p) => p.id).toSet(), {
        'skipped',
        'future',
        'old-leftover',
      });
      expect(PlanService.replacedWorkouts(calendar, sessions, profile: profile, start: start, now: today).map((p) => p.id).toSet(), {
        'short',
        'missed',
      });
      expect(PlanService.bridgeWorkouts(calendar, sessions, profile: profile, start: today, now: today), isEmpty);
    });

    test('review r10-N3: a done workout with a newer generation (clock ahead) never marks the new plan as left over', () async {
      // The old plan was made on a device whose clock ran 10 minutes ahead; one of its workouts is done.
      final ahead = newPlanGen(DateTime.now().add(const Duration(minutes: 10)), 'ahead');
      final cal = [
        w('done-ahead', -2, status: 'done', gen: ahead, sessionId: 's-a'),
        w('started-ahead', -1, gen: ahead),
        w('open-ahead', 1, gen: ahead),
      ];
      final ss = [run('s-a', -2, planId: 'done-ahead'), run('s-b', -1, planId: 'started-ahead')];
      final repo = _Repo(cal);
      await PlanService.replacePlan(
        repo: repo,
        l: de,
        profile: withPlanMeta(profile, addDays(today, -10), 8, gen: ahead),
        templates: const [],
        existing: cal,
        sessions: ss,
        start: today,
        weeks: 8,
        now: today,
      );
      final stale = stalePlanWorkouts(repo.savedProfile!, repo.all, ss);
      expect(stale, isEmpty, reason: 'done / started workouts must not decide the newest generation');
      // An open workout of a newer generation still wins (two devices: the later plan).
      final newer = newPlanGen(DateTime.now().add(const Duration(hours: 1)), 'newer');
      final withNewer = [...repo.all, w('newer', 3, gen: newer)];
      expect(
        stalePlanWorkouts(repo.savedProfile!, withNewer, ss).length,
        repo.all.where((p) => !p.isDone && p.id != 'started-ahead').length,
      );
    });
  });

  group('Plan löschen', () {
    test('deletes the open workouts, marks the plan deleted, logs it – goals and done workouts stay', () {
      final repo = _Repo(calendar);
      final d = PlanService.deletePlan(repo: repo, profile: profile, existing: calendar, sessions: sessions);
      expect(d, isNotNull);
      expect(d!.removed.map((p) => p.id).toSet(), {'short', 'missed', 'skipped', 'future', 'refill', 'own', 'old-leftover'});
      expect(repo.docs.keys.toSet(), {'done', 'linked'});
      final a1 = repo.savedProfile!.athlete;
      expect(a1.planDeleted, isTrue);
      expect(a1.planStart, isNull);
      expect(a1.planLength, 0);
      expect(a1.planGen!.compareTo(gen1), greaterThan(0));
      expect(a1.eventDate, profile.athlete.eventDate, reason: 'the race goal stays');
      expect(repo.logs.single.source, PlanLogEntry.planDelete);
      expect(repo.logs.single.reason, '7');
      // A second tap right after it does nothing (no double deletion / log).
      expect(PlanService.deletePlan(repo: repo, profile: repo.savedProfile!, existing: repo.all, sessions: sessions), isNull);
    });

    test("another device's copy of the deleted plan is removed as left over (multi-device / offline)", () {
      final repo = _Repo(calendar);
      PlanService.deletePlan(repo: repo, profile: profile, existing: calendar, sessions: sessions);
      // The other device still had the old plan (its cache) and syncs it back – or never saw the delete batch.
      final stale = stalePlanWorkouts(repo.savedProfile!, calendar, sessions).map((p) => p.id).toSet();
      expect(stale, {'missed', 'skipped', 'future', 'old-leftover'}, reason: 'open workouts of every older generation');
      expect(stale, isNot(contains('done')));
      expect(stale, isNot(contains('linked')), reason: 'a session was started from it');
    });

    test('undo writes the workouts back under a new generation – the deletion marker never removes them again', () {
      final repo = _Repo(calendar);
      final d = PlanService.deletePlan(repo: repo, profile: profile, existing: calendar, sessions: sessions)!;
      final tombstone = repo.savedProfile!;
      PlanService.undoDelete(repo, d, tombstone);
      expect(repo.docs.keys.toSet(), calendar.map((p) => p.id).toSet());
      final restored = repo.savedProfile!.athlete;
      expect(restored.planDeleted, isFalse);
      expect(restored.planStart, profile.athlete.planStart);
      expect(restored.planLength, 12);
      // Whichever arrives first – the restored workouts or the restored profile – nothing is cleaned up.
      expect(stalePlanWorkouts(tombstone, repo.all, sessions), isEmpty);
      expect(stalePlanWorkouts(repo.savedProfile!, repo.all, sessions), isEmpty);
      expect(repo.docs['own']!.planGen, isNull, reason: "the athlete's own workout stays without a generation");
      expect(repo.logs.last.source, PlanLogEntry.planRestore);
    });

    test('no gap refills and no plan start for a deleted plan (its done workouts stay in the calendar)', () {
      final repo = _Repo(calendar);
      PlanService.deletePlan(repo: repo, profile: profile, existing: calendar, sessions: sessions);
      final p = repo.savedProfile!;
      expect(PlanGaps(de, p, plans: repo.all, now: today, sessions: sessions).find(), isEmpty);
      final phased = repo.all.where((x) => x.phase != null).toList();
      expect(phased, isNotEmpty);
      expect(FitnessState.currentPlanStart(p, phased), isNull);
      expect(FitnessState.currentPlanStart(profile, phased), isNotNull, reason: 'with the plan running: its start');
    });

    test('refills of the plan review carry the plan generation (a new plan elsewhere removes them)', () {
      final p = withPlanMeta(a.marathoner(), addDays(today, -7), 12, gen: gen1);
      final gaps = PlanGaps(de, p, plans: [w('x', -7, gen: gen1)], now: today).find();
      expect(gaps, isNotEmpty);
      for (final g in gaps) {
        expect(g.plan.planGen, gen1);
      }
    });
  });

  group('UI', () {
    MaterialApp material(Widget home) => MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

    Future<_Repo> pumpCalendar(WidgetTester t, List<PlannedWorkout> plans) async {
      t.view.physicalSize = const Size(360, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = _Repo(plans);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            repoProvider.overrideWithValue(repo),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            plansProvider.overrideWith((ref) => repo.watch()),
            sessionsProvider.overrideWith((ref) => Stream.value(sessions)),
            templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          ],
          child: material(const Scaffold(body: CalendarPage())),
        ),
      );
      await t.pumpAndSettle();
      return repo;
    }

    testWidgets('calendar ⋮ → "Plan löschen": count, what stays, undo in the snackbar, then "Noch kein Plan"', (t) async {
      final repo = await pumpCalendar(t, calendar);
      expect(find.byKey(const ValueKey('calendarNoPlan')), findsNothing);
      await t.tap(find.byKey(const ValueKey('calendarMore')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('deletePlanItem')));
      await t.pumpAndSettle();
      expect(find.text(de.deletePlanBody(7)), findsOneWidget);
      expect(find.text(de.deletePlanKeeps), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('deletePlanOk')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.docs.keys.toSet(), {'done', 'linked'});
      expect(find.text(de.planDeletedToast(7)), findsOneWidget);
      expect(find.byKey(const ValueKey('calendarNoPlan')), findsOneWidget, reason: 'the way to a new plan');
      // Undo brings the plan back.
      await t.tap(find.text(de.undo));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.docs.length, calendar.length);
      expect(find.byKey(const ValueKey('calendarNoPlan')), findsNothing);
      await t.pumpAndSettle(const Duration(seconds: 11));
    });

    testWidgets('no "Plan löschen" without an open workout', (t) async {
      await pumpCalendar(t, [w('done', -6, status: 'done', gen: gen1, sessionId: 's-done')]);
      await t.tap(find.byKey(const ValueKey('calendarMore')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('deletePlanItem')), findsNothing);
      expect(find.byKey(const ValueKey('calendarNoPlan')), findsOneWidget);
    });

    testWidgets('review r10-N3: no "Noch kein Plan" flash while the plans are still loading', (t) async {
      t.view.physicalSize = const Size(360, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final plans = StreamController<List<PlannedWorkout>>();
      addTearDown(plans.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            repoProvider.overrideWithValue(_Repo(const [])),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            plansProvider.overrideWith((ref) => plans.stream),
            sessionsProvider.overrideWith((ref) => Stream.value(sessions)),
            templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          ],
          child: material(const Scaffold(body: CalendarPage())),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('calendarNoPlan')), findsNothing, reason: 'plans not loaded yet');
      plans.add(const []);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('calendarNoPlan')), findsOneWidget);
    });

    testWidgets('the plan history shows the deletion as one line', (t) async {
      final entry = PlanLogEntry.summary(PlanLogEntry.planDelete, 12, at: today);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
          ],
          child: material(Scaffold(body: PlanLogCard(entry: entry, current: const {}, onUndo: () {}))),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(de.planLogDeleted), findsOneWidget);
      expect(find.text(de.planLogDeletedReason(12)), findsOneWidget);
      expect(find.text(de.undo), findsNothing);
      // Not hidden as an entry of a replaced plan (it has no workouts).
      expect(visiblePlanLog([entry], const {}), [entry]);
    });
  });
}
