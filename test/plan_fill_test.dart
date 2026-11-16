import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/session/manual_entry_page.dart';
import 'package:strive/features/session/session_summary_page.dart';
import 'package:strive/features/shell/health_sync.dart';
import 'package:strive/features/stats/edit_session_page.dart';
import 'package:strive/features/stats/plan_link_card.dart';
import 'package:strive/features/train/exercise_picker.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/l10n/gen/app_localizations_de.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/health_service.dart';
import 'package:strive/services/insights.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/session_feedback.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/widgets/duration_picker.dart';

final de = AppLocalizationsDe();
final _now = DateTime(2026, 11, 11, 12);
const _profile = UserProfile(name: 'Alex', onboarded: true, weightKg: 80, birthYear: 1990, level: 'intermediate');

GymExercise _ex(String id, String name, {int sets = 3, int reps = 8, double kg = 60}) => GymExercise(
  exId: id,
  name: name,
  repMin: reps,
  repMax: reps + 4,
  sets: [for (var i = 0; i < sets; i++) GymSet(weight: kg, reps: reps)],
);

final _push = WorkoutTemplate(
  id: 't1',
  name: 'Push',
  sport: Sport.gym,
  exercises: [_ex('0025', 'barbell bench press'), _ex('0405', 'dumbbell shoulder press', kg: 20), _ex('0241', 'triceps pushdown', kg: 25)],
);

PlannedWorkout _gymPlan({String status = 'planned', String? sessionId}) => PlannedWorkout(
  id: 'p1',
  date: DateTime(2026, 11, 10),
  sport: Sport.gym,
  title: 'Push',
  durationMin: 56,
  templateId: 't1',
  status: status,
  sessionId: sessionId,
);

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final saved = <Session>[];
  final planUpdates = <String, Map<String, dynamic>>{};
  final sessionUpdates = <String, Map<String, dynamic>>{};
  var _id = 0;
  @override
  String newId() => 'new${_id++}';
  @override
  void saveSession(Session s) => saved.add(s);
  @override
  void updatePlan(String id, Map<String, dynamic> data) => planUpdates[id] = data;
  @override
  void updateSession(String id, Map<String, dynamic> data) => sessionUpdates[id] = data;
  @override
  Future<void> updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) async {
    planUpdates.addAll(plans);
    sessionUpdates.addAll(sessions);
  }
}

Future<List<Override>> _overrides(
  _FakeRepo repo, {
  List<PlannedWorkout> plans = const [],
  List<Session> sessions = const [],
  List<WorkoutTemplate> templates = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    prefsProvider.overrideWithValue(prefs),
    repoProvider.overrideWithValue(repo),
    healthServiceProvider.overrideWith((ref) => HealthService(prefs)),
    profileProvider.overrideWith((ref) => Stream.value(_profile)),
    sessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    templatesProvider.overrideWith((ref) => Stream.value(templates)),
    plansProvider.overrideWith((ref) => Stream.value(plans)),
    goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
    bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
    exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
    weatherProvider.overrideWith((ref) => Completer<Weather>().future),
  ];
}

Widget _app(Widget home, List<Override> o) => ProviderScope(
  overrides: o,
  child: MaterialApp(
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
  ),
);

/// A button that opens [page] (so the page can pop); keeps the data streams loaded like the app.
Widget _launcher(Widget Function() page) => Consumer(
  builder: (c, ref, _) {
    ref.watch(templateListProvider);
    ref.watch(planListProvider);
    ref.watch(sessionListProvider);
    ref.watch(profileOrDefaultProvider);
    return Scaffold(
      body: Center(
        child: TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page())), child: const Text('open')),
      ),
    );
  },
);

Future<void> _open(WidgetTester t, Widget Function() page, List<Override> o) async {
  t.view.physicalSize = const Size(420, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(_launcher(page), o));
  await t.pump();
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  group('one compliance scale', () {
    test('bands incl. "not counted" below 10 %', () {
      expect(complianceLevelOf(0.01), ComplianceLevel.red);
      expect(complianceLevelOf(0.099), ComplianceLevel.red);
      expect(complianceLevelOf(0.1), ComplianceLevel.orange);
      expect(complianceLevelOf(0.49), ComplianceLevel.orange);
      expect(complianceLevelOf(0.5), ComplianceLevel.yellow);
      expect(complianceLevelOf(0.8), ComplianceLevel.green);
      expect(complianceLevelOf(1.2), ComplianceLevel.green);
      expect(complianceLevelOf(1.5), ComplianceLevel.yellow);
      expect(complianceLevelOf(1.51), ComplianceLevel.orange);
    });

    test('0:29 of a 56 min Push is not counted, the workout stays open', () {
      final p = _gymPlan(status: 'done', sessionId: 's');
      final s = Session(id: 's', sport: Sport.gym, title: 'Push', start: DateTime(2026, 11, 10, 18), durationSec: 29, planId: 'p1');
      final c = planCompliance(p, s, now: _now);
      expect(c.level, ComplianceLevel.red);
      expect(c.notCounted, isTrue);
      expect(c.pct, 1);
      expect(c.label(de), de.complianceNotCounted(1));
      expect(planCompleted(p, {'p1': s}), isFalse);
      expect(planCounts([p], {'p1': s}), (done: 0, planned: 1));
      expect(weeklyCompletion([p], {'p1': s}, now: _now), closeTo(0, 1e-9));
      expect(PlanLinkCard.coachLine(de, p, s, c), de.coachNotCounted(Units.pct(29 / 3360 * 100)));
    });

    test('gym compares done work sets with the sets of the workout, not the time', () {
      final p = _gymPlan(status: 'done', sessionId: 's');
      final ex = _ex('0025', 'bench', sets: 4);
      for (final x in ex.sets.take(3)) {
        x.done = true;
      }
      // 3 of 12 sets in 50 min: time says "as planned", sets say "far off" (25 %).
      final s = Session(
        id: 's',
        sport: Sport.gym,
        title: 'Push',
        start: DateTime(2026, 11, 10, 18),
        durationSec: 50 * 60,
        exercises: [ex],
        plannedSets: 12,
        planId: 'p1',
      );
      expect(complianceRatio(p, s), closeTo(0.25, 1e-9));
      final c = planCompliance(p, s, now: _now);
      expect(c.level, ComplianceLevel.orange);
      expect(planCompleted(p, {'p1': s}), isTrue);
      expect(PlanLinkCard.coachLine(de, p, s, c), de.coachMuchFewerSets(Units.pct(25)));
      // 10 of 12 sets → as planned, even in 30 min.
      final ex2 = _ex('0025', 'bench', sets: 12);
      for (final x in ex2.sets.take(10)) {
        x.done = true;
      }
      final s2 = Session(
        id: 's',
        sport: Sport.gym,
        title: 'Push',
        start: DateTime(2026, 11, 10, 18),
        durationSec: 30 * 60,
        exercises: [ex2],
        plannedSets: 12,
      );
      expect(planCompliance(p, s2, now: _now).level, ComplianceLevel.green);
      // Imported gym session without sets → duration.
      final imported = Session(id: 'i', sport: Sport.gym, title: 'Kraft', start: DateTime(2026, 11, 10, 18), durationSec: 56 * 60);
      expect(complianceRatio(p, imported), closeTo(1, 1e-9));
    });

    test('of two sessions from the same workout the one that counts is linked', () {
      final p = _gymPlan(status: 'done', sessionId: 'aborted');
      final aborted = Session(id: 'aborted', sport: Sport.run, title: 'x', start: DateTime(2026, 11, 10, 7), durationSec: 30, planId: 'p1');
      final real = Session(id: 'real', sport: Sport.run, title: 'x', start: DateTime(2026, 11, 10, 18), durationSec: 55 * 60, planId: 'p1');
      final run = PlannedWorkout(
        id: 'p1',
        date: DateTime(2026, 11, 10),
        sport: Sport.run,
        title: 'Lauf',
        durationMin: 56,
        status: 'done',
        sessionId: 'aborted',
      );
      expect(linkPlanSessions([run], [real, aborted])['p1']?.id, 'real');
      expect(linkPlanSessions([run], [aborted, real])['p1']?.id, 'real');
      expect(p.sessionId, 'aborted');
    });

    test('summary headline uses the same bands', () {
      final plan = PlannedWorkout(id: 'p', date: _now, sport: Sport.run, title: 'Lauf', durationMin: 40, distanceKm: 8);
      Session run(double m) => Session(id: 'x', sport: Sport.run, title: 'Lauf', start: _now, durationSec: 600, distanceM: m, planId: 'p');
      expect(summaryOutcome(run(6400), plan: plan), SummaryOutcome.planDone); // 80 %
      expect(summaryOutcome(run(4000), plan: plan), SummaryOutcome.partial);
      expect(summaryOutcome(run(500), plan: plan), SummaryOutcome.tooLittle); // 6 %
    });

    test('the glossary explains the bands with the scale\'s numbers', () {
      final body = de.termComplianceBody('80 %', '120 %', '50 %', '150 %', '10 %');
      expect(body, contains('80 %–120 %'));
      expect(body, contains('unter 10 %'));
    });
  });

  group('sport-specific "too short" texts', () {
    Session s(Sport sport, {int sec = 30, double m = 0, bool indoor = false}) =>
        Session(id: 'x', sport: sport, title: 't', start: _now, durationSec: sec, distanceM: m, indoor: indoor);

    test('gym never mentions a distance', () {
      final (title, body) = tooShortTexts(de, s(Sport.gym));
      expect(title, de.summaryTooShortTitle);
      expect(body, de.summaryTooShortGym);
      expect(body.contains('Strecke'), isFalse);
    });

    test('cardio names what is missing', () {
      expect(tooShortTexts(de, s(Sport.run)).$2, de.summaryTooShortTime);
      expect(tooShortTexts(de, s(Sport.run, sec: 1800)), (de.summaryNoDistanceTitle, de.summaryNoDistanceBody));
      expect(tooShortTexts(de, s(Sport.ride, sec: 1800)), (de.summaryNoDistanceTitle, de.summaryNoDistanceBody));
      expect(tooShortTexts(de, s(Sport.swim, sec: 1800, indoor: true)), (de.summaryNoLapsTitle, de.summaryNoLapsBody));
    });
  });

  group('logging a planned workout as done takes over the plan', () {
    test('gym: exercises, every set at the prescribed weight, totals', () {
      final prescriber = LoadPrescriber(history: const [], profile: _profile, now: _now);
      final fill = PlanFill.of(_gymPlan(), profile: _profile, templates: [_push], prescriber: prescriber);
      expect(fill.exercises.length, 3);
      expect(fill.plannedSets, 9);
      expect(fill.sets, 9);
      expect(fill.exercises.every((e) => e.sets.every((s) => s.done && s.reps > 0 && !s.amrap)), isTrue);
      expect(fill.volume, greaterThan(0));
      final s = sessionFromPlan(_gymPlan(), fill, id: 's1', start: _now, title: 'Push');
      expect(s.fromPlan, isTrue);
      expect(s.setsDone, 9);
      expect(s.exercises.length, 3);
      expect(s.volume, closeTo(fill.volume, 1e-9));
      expect(s.plannedSets, 9);
      expect(s.planId, 'p1');
      expect(s.templateId, 't1');
      // As planned in the calendar …
      expect(planCompliance(_gymPlan(status: 'done', sessionId: 's1'), s, now: _now).level, ComplianceLevel.green);
      // … but no records from the plan's weights.
      expect(newPrs(s, const []), isEmpty);
      expect(exerciseRecords([s]), isEmpty);
      expect(e1rmHistory([s], '0025'), isEmpty);
      // Stored and read back.
      final back = Session.fromMap('s1', s.toMap());
      expect(back.fromPlan, isTrue);
      expect(back.plannedSets, 9);
      expect(back.setsDone, 9);
    });

    test('gym: the weights follow the last session (progression)', () {
      final last = Session(
        id: 'h',
        sport: Sport.gym,
        title: 'Push',
        start: DateTime(2026, 11, 3, 18),
        durationSec: 3600,
        exercises: [
          GymExercise(
            exId: '0025',
            name: 'barbell bench press',
            repMin: 8,
            repMax: 12,
            sets: [for (var i = 0; i < 3; i++) GymSet(weight: 70, reps: 9, done: true)],
          ),
        ],
      );
      final prescriber = LoadPrescriber(history: [last], profile: _profile, now: _now);
      final fill = PlanFill.of(_gymPlan(), profile: _profile, templates: [_push], prescriber: prescriber);
      final bench = fill.exercises.firstWhere((e) => e.exId == '0025');
      expect(bench.workSets.first.weight, greaterThanOrEqualTo(70));
    });

    test('run: planned distance and duration, user changes make it their own numbers', () {
      final p = PlannedWorkout(id: 'r', date: _now, sport: Sport.run, title: 'Lauf', durationMin: 60, distanceKm: 10);
      final fill = PlanFill.of(p, profile: _profile);
      final s = sessionFromPlan(p, fill, id: 's', start: _now, title: 'Lauf');
      expect(s.distanceM, 10000);
      expect(s.durationSec, 3600);
      expect(s.fromPlan, isTrue);
      expect(runBestEfforts([s]), isEmpty);
      final own = sessionFromPlan(p, fill, id: 's', start: _now, title: 'Lauf', distanceM: 9500);
      expect(own.fromPlan, isFalse);
    });

    test('swim: laps in the athlete\'s pool', () {
      const profile = UserProfile(athlete: AthleteData(poolLength: 50));
      final p = PlannedWorkout(id: 'w', date: _now, sport: Sport.swim, title: 'Schwimmen', durationMin: 45, distanceKm: 1.5);
      final s = sessionFromPlan(p, PlanFill.of(p, profile: profile), id: 's', start: _now, title: 'Schwimmen');
      expect(s.distanceM, 1500);
      expect(s.laps, 30);
      expect(s.poolLengthM, 50);
    });

    test('no pace / power signal from the plan\'s own numbers', () {
      final p = PlannedWorkout(
        id: 'r',
        date: _now,
        sport: Sport.run,
        title: 'Tempo',
        durationMin: 50,
        distanceKm: 10,
        intensity: 'tempo',
        steps: [WorkoutStep(kind: 'work', distanceM: 10000, zone: 'T', paceMin: 240, paceMax: 250)],
      );
      final s = sessionFromPlan(p, PlanFill.of(p, profile: _profile), id: 's', start: _now, title: 'Tempo', rpe: 6);
      final f = evaluateSession(p, s, _profile);
      expect(f.signals.map((x) => x.kind), [SignalKind.rpe]);
    });

    testWidgets('gym: supersets of the plan are framed in "Als erledigt eintragen" (320 dp, text scale 1.3)', (t) async {
      final tpl = WorkoutTemplate(
        id: 't1',
        name: 'Pull',
        sport: Sport.gym,
        exercises: [
          _ex('q1', 'Klimmzüge mit Zusatzgewicht'),
          _ex('q2', 'Seitheben vorgebeugt am Kabelzug', kg: 12.5)..group = 'A',
          _ex('q3', 'Bizepsbeuge mit der SZ-Stange', kg: 27.5)..group = 'A',
          _ex('q4', 'Langhantelrudern vorgebeugt'),
        ],
      );
      final repo = _FakeRepo();
      final plan = _gymPlan();
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(t, () => ManualEntryPage(plan: plan), await _overrides(repo, plans: [plan], templates: [tpl]));
      t.view.physicalSize = const Size(320, 3200);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final card = find.byKey(const ValueKey('gymFromPlan'));
      final group = find.descendant(of: card, matching: find.byKey(const ValueKey('supersetGroup-A')));
      expect(group, findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Supersatz A · 2 Übungen')), findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Seitheben vorgebeugt am Kabelzug')), findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Bizepsbeuge mit der SZ-Stange')), findsOneWidget);
      expect(find.descendant(of: group, matching: find.text('Langhantelrudern vorgebeugt')), findsNothing);
      expect(find.descendant(of: card, matching: find.text('Langhantelrudern vorgebeugt')), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      // Stored with the superset.
      await t.tap(find.byKey(const ValueKey('manualSave')));
      await t.pumpAndSettle();
      expect(repo.saved.single.exercises.map((e) => e.group).toList(), [null, 'A', 'A', null]);
      expect(t.takeException(), isNull);
    });

    testWidgets('gym: "Als erledigt eintragen" stores the workout with sets and weights', (t) async {
      final repo = _FakeRepo();
      final plan = _gymPlan();
      final o = await _overrides(repo, plans: [plan], templates: [_push]);
      await _open(t, () => ManualEntryPage(plan: plan), o);
      expect(find.byKey(const ValueKey('gymFromPlan')), findsOneWidget);
      expect(find.textContaining('3 Übungen · 9 Sätze'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('manualSave')));
      await t.pumpAndSettle();
      final s = repo.saved.single;
      expect(s.fromPlan, isTrue);
      expect(s.exercises.length, 3);
      expect(s.setsDone, 9);
      expect(s.volume, greaterThan(0));
      expect(repo.planUpdates['p1'], {'status': 'done', 'sessionId': s.id});
    });

    testWidgets('run: pace follows from the plan\'s distance and duration', (t) async {
      final repo = _FakeRepo();
      final plan = PlannedWorkout(id: 'r', date: DateTime(2026, 11, 10), sport: Sport.run, title: 'Lauf', durationMin: 60, distanceKm: 10);
      final o = await _overrides(repo, plans: [plan]);
      await _open(t, () => ManualEntryPage(plan: plan), o);
      expect(find.byKey(const ValueKey('manualDerived')), findsOneWidget);
      expect(find.textContaining('6:00'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('manualSave')));
      await t.pumpAndSettle();
      final s = repo.saved.single;
      expect(s.distanceM, 10000);
      expect(s.durationSec, 3600);
      expect(s.fromPlan, isTrue);
    });
  });

  group('editing a finished gym workout', () {
    Session gym() => Session(
      id: 'g',
      sport: Sport.gym,
      title: 'Push',
      start: DateTime(2026, 11, 10, 18),
      durationSec: 3600,
      exercises: [
        GymExercise(exId: '0025', name: 'barbell bench press', sets: [GymSet(weight: 60, reps: 8, done: true)]),
        GymExercise(exId: '0405', name: 'dumbbell shoulder press', sets: [GymSet(weight: 20, reps: 10, done: true)]),
      ],
      fromPlan: true,
    );

    testWidgets('bodyweight switch: open sets get the plan\'s load phase like in the tracker (deload week)', (t) async {
      Session pullUps(String id, int daysAgo) => Session(
        id: id,
        sport: Sport.gym,
        title: 'Pull',
        start: _now.subtract(Duration(days: daysAgo)),
        durationSec: 3600,
        exercises: [
          GymExercise(
            exId: '0652',
            name: 'pull-up',
            bw: true,
            bodyKg: 80,
            sets: [for (var i = 0; i < 3; i++) GymSet(weight: 10, reps: 6, done: true, target: 6)],
          ),
        ],
      );
      final s = Session(
        id: 'g',
        sport: Sport.gym,
        title: 'Pull',
        start: DateTime(2026, 11, 10, 18),
        durationSec: 3600,
        planId: 'p1',
        exercises: [
          // Logged without its sets yet: the open set is re-prescribed by the switch.
          GymExercise(exId: '0652', name: 'pull-up', bw: false, sets: [GymSet(reps: 6)]),
        ],
      );
      final plan = PlannedWorkout(
        id: 'p1',
        date: DateTime(2026, 11, 10),
        sport: Sport.gym,
        title: 'Pull',
        durationMin: 50,
        phase: 'recovery',
        status: 'done',
        sessionId: 'g',
      );
      final history = [pullUps('h1', 5), pullUps('h2', 9)];
      final rx = LoadPrescriber(history: history, profile: _profile, now: _now);
      final probe = GymExercise(exId: '0652', name: 'pull-up', bw: true, sets: [GymSet(reps: 6)])
        ..bodyKg = rx.bodyLoad(GymExercise(exId: '0652', name: 'pull-up'));
      final deload = rx.forExercise(probe, phase: 'recovery')!.weight, loading = rx.forExercise(probe)!.weight;
      expect(deload, lessThan(loading));
      final repo = _FakeRepo();
      final o = await _overrides(repo, sessions: [s, ...history], plans: [plan]);
      await _open(t, () => EditSessionPage(session: s), o);
      await t.tap(find.byKey(const ValueKey('edit-bw')));
      await t.pumpAndSettle();
      await t.tap(find.text(de.save).last);
      await t.pumpAndSettle();
      final ex = GymExercise.fromMap((repo.sessionUpdates['g']!['exercises'] as List).single as Map);
      expect(ex.bw, isTrue);
      expect(ex.sets.last.done, isFalse);
      expect(ex.sets.last.weight, deload);
    });

    testWidgets('exercises can be removed (with undo), moved and added', (t) async {
      final repo = _FakeRepo();
      final s = gym();
      final o = await _overrides(repo, sessions: [s]);
      await _open(t, () => EditSessionPage(session: s), o);
      expect(find.text(de.editSessionHintGym), findsOneWidget);

      // Remove the bench press – undo brings it back.
      await t.tap(find.byKey(const ValueKey('editExerciseMenu-0025')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('editRemoveExercise')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('editExerciseMenu-0025')), findsNothing);
      await t.tap(find.text(de.undo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('editExerciseMenu-0025')), findsOneWidget);

      // Move the shoulder press up.
      await t.tap(find.byKey(const ValueKey('editExerciseMenu-0405')));
      await t.pumpAndSettle();
      await t.tap(find.text(de.moveUp));
      await t.pumpAndSettle();

      // Add an exercise from the library.
      await t.tap(find.byKey(const ValueKey('editAddExercise')));
      // The library keeps loading (no exercise DB in tests) – pick by closing it with a result.
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      Navigator.of(t.element(find.byType(ExerciseLibraryPage))).pop(const [
        Exercise(
          id: '0241',
          name: 'cable pushdown',
          bodyPart: 'upper arms',
          equipment: 'cable',
          target: 'triceps',
          secondary: [],
          instructions: [],
        ),
      ]);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('editExerciseMenu-0241')), findsOneWidget);

      // Remove the bench press for good and save.
      await t.tap(find.byKey(const ValueKey('editExerciseMenu-0025')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('editRemoveExercise')));
      await t.pumpAndSettle();
      await t.tap(find.text(de.save).last);
      await t.pumpAndSettle();

      final u = repo.sessionUpdates['g']!;
      final ex = [for (final m in u['exercises'] as List) GymExercise.fromMap(m as Map)];
      expect(ex.map((e) => e.exId), ['0405', '0241']);
      expect(ex.last.sets.every((x) => x.done), isTrue);
      expect(u['volume'], closeTo(ex.fold<double>(0, (a, e) => a + e.volume), 1e-9));
      // Corrected data are the athlete's own numbers now.
      expect(u['fromPlan'], isFalse);
    });

    testWidgets('swim: laps × pool length give the distance', (t) async {
      final repo = _FakeRepo();
      final s = Session(
        id: 'w',
        sport: Sport.swim,
        title: 'Schwimmen',
        start: DateTime(2026, 11, 10, 18),
        durationSec: 1800,
        distanceM: 1000,
        laps: 40,
        poolLengthM: 25,
        indoor: true,
      );
      final o = await _overrides(repo, sessions: [s]);
      await _open(t, () => EditSessionPage(session: s), o);
      await t.enterText(find.byKey(const ValueKey('editLaps')), '48');
      await t.pump();
      await t.tap(find.text(de.save).last);
      await t.pumpAndSettle();
      final u = repo.sessionUpdates['w']!;
      expect(u['laps'], 48);
      expect(u['distanceM'], 1200);
    });
  });

  group('review: "from the plan" per exercise on the edit page', () {
    /// A Push workout logged as done ("mark as done") – every exercise taken over from the plan.
    Session filled() {
      final prescriber = LoadPrescriber(history: const [], profile: _profile, now: _now);
      final fill = PlanFill.of(_gymPlan(), profile: _profile, templates: [_push], prescriber: prescriber);
      return sessionFromPlan(_gymPlan(), fill, id: 'g', start: DateTime(2026, 11, 10, 18), title: 'Push');
    }

    Session applied(Session s, Map<String, dynamic> u) => Session.fromMap(s.id, {...s.toMap(), ...u});

    testWidgets('M1: only the duration changed → still from the plan, no records', (t) async {
      final repo = _FakeRepo();
      final s = filled();
      expect(s.exercises.every((e) => e.fromPlan), isTrue);
      final o = await _overrides(repo, sessions: [s], plans: [_gymPlan(status: 'done', sessionId: 'g')], templates: [_push]);
      await _open(t, () => EditSessionPage(session: s), o);
      t.widget<DurationField>(find.byKey(const ValueKey('editDuration'))).onChanged(70 * 60);
      await t.pump();
      await t.tap(find.text(de.save).last);
      await t.pumpAndSettle();
      final u = repo.sessionUpdates['g']!;
      expect(u['durationSec'], 70 * 60);
      expect(u.containsKey('fromPlan'), isFalse);
      final after = applied(s, u);
      expect(after.fromPlan, isTrue);
      expect(after.exercises.every((e) => e.fromPlan), isTrue);
      expect(exerciseRecords([after]), isEmpty);
      expect(e1rmHistory([after], '0025'), isEmpty);
      expect(planCompliance(_gymPlan(status: 'done', sessionId: 'g'), after, now: _now).pct, 100);
    });

    testWidgets('reps of one exercise corrected → that exercise is measured, the others stay from the plan', (t) async {
      final repo = _FakeRepo();
      final s = filled();
      final o = await _overrides(repo, sessions: [s], templates: [_push]);
      await _open(t, () => EditSessionPage(session: s), o);
      // The first rep field belongs to the bench press (the first exercise).
      final reps = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == de.reps);
      await t.enterText(reps.first, '3');
      await t.pump();
      await t.tap(find.text(de.save).last);
      await t.pumpAndSettle();
      final u = repo.sessionUpdates['g']!;
      expect(u['fromPlan'], isFalse);
      final after = applied(s, u);
      final bench = after.exercises.firstWhere((e) => e.exId == '0025');
      expect(bench.fromPlan, isFalse);
      expect(after.exercises.where((e) => e.exId != '0025').every((e) => e.fromPlan), isTrue);
      // Records: the corrected bench press only – not the prescribed shoulder press / pushdown weights.
      expect(exerciseRecords([after]).keys, ['0025']);
      // Fewer reps than prescribed on one set → no longer the full plan.
      expect(complianceRatio(_gymPlan(), after)!, lessThan(1));
    });

    testWidgets('an added exercise raises the planned sets (no "> 150 %" for a full workout plus one)', (t) async {
      final repo = _FakeRepo();
      final s = filled();
      expect(s.plannedSets, 9);
      final o = await _overrides(repo, sessions: [s], templates: [_push]);
      await _open(t, () => EditSessionPage(session: s), o);
      await t.tap(find.byKey(const ValueKey('editAddExercise')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      Navigator.of(t.element(find.byType(ExerciseLibraryPage))).pop(const [
        Exercise(
          id: '0027',
          name: 'barbell bent over row',
          bodyPart: 'back',
          equipment: 'barbell',
          target: 'lats',
          secondary: [],
          instructions: [],
        ),
      ]);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      await t.tap(find.text(de.save).last);
      await t.pumpAndSettle();
      final u = repo.sessionUpdates['g']!;
      final after = applied(s, u);
      final row = after.exercises.firstWhere((e) => e.exId == '0027');
      expect(row.fromPlan, isFalse);
      expect(u['plannedSets'], 9 + row.workSets.length);
      expect(after.fromPlan, isFalse);
      expect(complianceLevelOf(complianceRatio(_gymPlan(), after)!), ComplianceLevel.green);
    });

    testWidgets('a plan without a duration is never stored as a 0-s session', (t) async {
      final repo = _FakeRepo();
      final plan = PlannedWorkout(id: 'r', date: DateTime(2026, 11, 10), sport: Sport.run, title: 'Lauf', durationMin: 0, distanceKm: 5);
      final o = await _overrides(repo, plans: [plan]);
      await _open(t, () => ManualEntryPage(plan: plan), o);
      await t.tap(find.byKey(const ValueKey('manualSave')));
      await t.pumpAndSettle();
      final s = repo.saved.single;
      expect(s.durationSec, 45 * 60);
      expect(s.distanceM, 5000);
      expect(s.fromPlan, isTrue);
    });
  });
}
