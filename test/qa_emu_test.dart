import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/exercise_names_de.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/calendar_page.dart';
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/features/onboarding/onboarding_page.dart';
import 'package:strive/features/session/manual_entry_page.dart';
import 'package:strive/features/session/session_summary_page.dart';
import 'package:strive/features/shell/health_sync.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/l10n/gen/app_localizations_de.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/health_service.dart';
import 'package:strive/services/insights.dart';
import 'package:strive/services/plan_service.dart';
import 'package:strive/services/session_checks.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/services/weather_service.dart';
import 'package:strive/services/zones.dart';
import 'package:strive/widgets/common.dart';
import 'package:strive/widgets/duration_picker.dart';
import 'package:strive/widgets/segments.dart';

/// Emulator QA review (H1 … L14): replanning keeps a trained day, compliance marks and labels,
/// "mark as done" links the planned workout, consistent duration input / format, segments with
/// one font size, swim test feedback, plausibility checks, XP not farmable by edits.
final de = AppLocalizationsDe();
final _today = dayOnly(DateTime.now());
const _profile = UserProfile(name: 'Alex', onboarded: true, weightKg: 80, birthYear: 1990, level: 'intermediate');

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final saved = <Session>[];
  final planUpdates = <String, Map<String, dynamic>>{};
  Set<String> removed = {};
  List<PlannedWorkout> written = [];
  var _id = 0;
  @override
  String newId() => 'new${_id++}';
  @override
  void saveSession(Session s) => saved.add(s);
  @override
  void updatePlan(String id, Map<String, dynamic> data) => planUpdates[id] = data;
  @override
  Future<void> updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) async => planUpdates.addAll(plans);
  @override
  Future<void> replacePlans(Iterable<String> remove, List<PlannedWorkout> plan) async {
    removed = {...remove};
    written = plan;
  }

  final deletedGoals = <String>[];
  final savedGoals = <Goal>[];
  @override
  void deleteGoal(String id) => deletedGoals.add(id);
  @override
  void saveGoal(Goal g) => savedGoals.add(g);
  @override
  Future<List<WorkoutTemplate>?> templatesFromServer() async => const [];
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async {}
  @override
  void saveProfile(UserProfile p) {}
  @override
  void logPlanChange(dynamic e) {}
}

Future<List<Override>> _overrides(
  _FakeRepo repo, {
  List<PlannedWorkout> plans = const [],
  List<Session> sessions = const [],
  UserProfile profile = _profile,
  List<Goal> goals = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    prefsProvider.overrideWithValue(prefs),
    repoProvider.overrideWithValue(repo),
    healthServiceProvider.overrideWith((ref) => HealthService(prefs)),
    profileProvider.overrideWith((ref) => Stream.value(profile)),
    sessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
    plansProvider.overrideWith((ref) => Stream.value(plans)),
    goalsProvider.overrideWith((ref) => Stream.value(goals)),
    bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
    exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
    weatherProvider.overrideWith((ref) => Completer<Weather>().future),
  ];
}

Widget _app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.light(),
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

PlannedWorkout _run(String id, DateTime date, {String status = 'planned', String? sessionId, double km = 8}) => PlannedWorkout(
  id: id,
  date: date,
  sport: Sport.run,
  title: 'Fahrtspiel',
  durationMin: 48,
  distanceKm: km,
  status: status,
  sessionId: sessionId,
);

Session _session(String id, DateTime start, {double km = 8, int min = 48, String? planId, Sport sport = Sport.run}) =>
    Session(id: id, sport: sport, title: 'Lauf', start: start, durationSec: min * 60, distanceM: km * 1000, planId: planId);

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  group('H1 start the plan over from today', () {
    test('a done / linked workout of today stays and its day is not planned again', () async {
      PlanService.reset();
      final repo = _FakeRepo();
      final done = _run('done', _today, status: 'done', sessionId: 's1');
      final linked = _run('linked', addDays(_today, 2)); // started (too short), still planned
      final open = _run('open', addDays(_today, 3));
      final n = await PlanService.replacePlan(
        repo: repo,
        l: de,
        profile: _profile.copyWith(focus: TrainingFocus.run, trainingDays: const [1, 2, 3, 4, 5, 6, 7]),
        templates: const [],
        existing: [done, linked, open],
        sessions: [_session('s1', _today, planId: 'done'), _session('s2', addDays(_today, 2), km: 0.3, min: 2, planId: 'linked')],
        start: _today,
        weeks: 4,
      );
      expect(n, greaterThan(0));
      expect(repo.written.where((p) => sameDay(p.date, _today)), isEmpty, reason: 'today was trained: no second workout');
      // A start too short to count leaves its workout open (final QA): its day is planned again, and the new run of
      // that day takes over its id – the 2-min attempt stays attached ("nicht gewertet") instead of the day vanishing.
      final day2 = repo.written.where((p) => sameDay(p.date, addDays(_today, 2))).toList();
      expect(day2.map((p) => p.id), contains('linked'));
      expect(day2.firstWhere((p) => p.id == 'linked').status, 'planned');
      expect(repo.removed, isNot(contains('done')), reason: 'completed workouts stay');
      expect(repo.removed, isNot(contains('linked')), reason: 'its id is taken over by the new run of that day');
      expect(repo.removed, contains('open'), reason: 'open planned workouts are replaced');
      PlanService.reset();
    });
  });

  group('compliance everywhere (M1, M4)', () {
    test('month marks: ✓ in the compliance colour on the day done, ✕ missed / not counted, open hollow, extra filled', () {
      final now = DateTime(2026, 11, 11);
      final d = DateTime(2026, 11, 9);
      final plans = [
        _run('green', d),
        _run('over', addDays(d, 1)),
        _run('short', addDays(d, 1)),
        _run('missed', addDays(d, -1)),
        _run('open', addDays(d, 4)),
      ];
      final sessions = [
        _session('g', d, planId: 'green'),
        _session('o', addDays(d, 1), km: 10.5, planId: 'over'), // 131 %
        _session('x', addDays(d, 1), km: 0.4, min: 3, planId: 'short'), // 5 %: not counted
        _session('free', addDays(d, 2)),
      ];
      final linked = linkPlanSessions(plans, sessions);
      final m = monthMarks(plans, plans, sessions, linked, now: now);
      ComplianceLevel? lvl(DateTime day, int i) => m[dayKey(day)]![i].compliance?.level;
      expect(lvl(d, 0), ComplianceLevel.green);
      expect(m[dayKey(addDays(d, 1))]!.map((x) => x.compliance!.level), containsAll([ComplianceLevel.yellow, ComplianceLevel.red]));
      expect(lvl(addDays(d, -1), 0), ComplianceLevel.red);
      expect(m[dayKey(addDays(d, 2))]!.single.extra, isTrue);
      expect(lvl(addDays(d, 4), 0), ComplianceLevel.none);
    });

    test('bucket labels: above plan / far off / partly – not "teilweise erledigt (129 %)"', () {
      expect(const Compliance(ComplianceLevel.yellow, 1.29).shortLabel(de), startsWith('über Plan'));
      expect(const Compliance(ComplianceLevel.yellow, 0.7).shortLabel(de), startsWith('teilweise erledigt'));
      expect(const Compliance(ComplianceLevel.orange, 1.61).shortLabel(de), startsWith('stark abweichend'));
      expect(const Compliance(ComplianceLevel.green, 1).shortLabel(de), isNull);
    });

    test('legend info text from the scale constants', () {
      final body = de.termComplianceBody('80 %', '120 %', '50 %', '150 %', '10 %');
      expect(body, contains('50 % bis unter 80 % oder über 120 % bis 150 %'));
      expect(body, contains('10 % bis unter 50 % oder über 150 %'));
    });
  });

  group('H3 plan settings without the race', () {
    test('a plan without a race shows only the countdown (no phases of an unrelated plan)', () {
      final race = addDays(_today, 87);
      final plans = [
        for (var i = 0; i < 20; i++) PlannedWorkout(id: '$i', date: addDays(_today, i), sport: Sport.run, title: 'x', phase: 'base'),
      ];
      expect(EventProgress.of(race, plans, _today).phase, isNotNull);
      final e = EventProgress.of(race, plans, _today, planForRace: false);
      expect(e.phase, isNull);
      expect(e.weeks, isNull);
      final g = Goal(id: 'g', type: GoalType.event, title: 'HM', target: 21.1, created: _today, deadline: race);
      expect(planBuiltFor(_profile, g), isFalse);
      expect(planBuiltFor(_profile.copyWith(athlete: AthleteData(eventDate: race)), g), isTrue);
    });

    test('review lines: no "Halbmarathon · Halbmarathon", no quick/detailed line', () {
      final before = _profile.copyWith(athlete: AthleteData(eventDate: DateTime(2027, 2, 6), eventDistance: 'hm', setupMode: 'advanced'));
      final after = _profile.copyWith(athlete: const AthleteData(setupMode: 'simple'));
      final lines = planSettingChanges(de, 'de', before, after, nameBefore: 'Halbmarathon', nameAfter: '');
      expect(lines.where((x) => x.contains('Halbmarathon · Halbmarathon')), isEmpty);
      expect(lines.any((x) => x.startsWith('${de.summaryRace}: Halbmarathon · ')), isTrue);
      expect(lines.where((x) => x.startsWith(de.setupModeTitle)), isEmpty);
    });
  });

  group('formats and dates', () {
    test('durations never wrap and never read "2 h 00" (M12)', () {
      expect(formatMinutes(45), '45 min');
      expect(formatMinutes(75), '75 min');
      expect(formatMinutes(120), '2 h');
      expect(formatMinutes(135), '2:15 h');
      expect(formatMinutes(60), '1 h');
    });

    test('race date picker opens on the long day, else a Sunday (L8)', () {
      final tue = DateTime(2026, 11, 10);
      expect(defaultRaceDate(tue, 12).weekday, DateTime.sunday);
      expect(defaultRaceDate(tue, 12, longDay: 6).weekday, DateTime.saturday);
      expect(daysBetween(tue, defaultRaceDate(tue, 12)), inInclusiveRange(84, 90));
    });

    test('exercise names: no leading "- " (L9)', () {
      final n = germanExerciseName('dumbbell seated one leg calf raise - hammer grip');
      expect(n.startsWith('-'), isFalse);
      expect(n.contains(' - '), isFalse);
    });
  });

  group('M8 swim test', () {
    test('both plausible: classic CSS; 400 m alone: an estimate; implausible combo: flagged', () {
      expect(SwimZones.test(400, 190).css, 105);
      expect(SwimZones.test(400, 190).kind, SwimTestKind.both);
      final only = SwimZones.test(400, null);
      expect(only.kind, SwimTestKind.only400);
      expect(only.css, 105); // 400 m pace 100 + 5 s
      expect(SwimZones.test(400, 210).kind, SwimTestKind.implausible); // 400 m faster per 100 m
      expect(SwimZones.test(null, 190).css, isNull);
      expect(SwimZones.test(null, 190).kind, SwimTestKind.only200);
    });
  });

  group('L3 plausibility and XP', () {
    test('ends in the future / impossible pace', () {
      final now = DateTime(2026, 11, 11, 12);
      expect(SessionCheck.of(Sport.run, DateTime(2026, 11, 11, 11, 30), 3600, 10000, now: now).endsInFuture, isTrue);
      expect(SessionCheck.of(Sport.run, DateTime(2026, 11, 11, 10), 3600, 10000, now: now).endsInFuture, isFalse);
      expect(SessionCheck.paceIsPlausible(Sport.run, 600, 10000), isFalse); // 1:00 /km
      expect(SessionCheck.paceIsPlausible(Sport.run, 3000, 10000), isTrue);
      expect(SessionCheck.paceIsPlausible(Sport.ride, 3600, 120000), isFalse);
      expect(SessionCheck.paceIsPlausible(Sport.swim, 1800, 1500), isTrue);
    });

    test('a correction never raises the XP', () {
      final s = _session('a', DateTime(2026, 11, 10), min: 40);
      final recorded = xpForSession(s);
      final edited = Session.fromMap('a', {...s.toMap(), 'durationSec': 4 * 3600, 'rpe': 10, 'xpCap': recorded});
      expect(xpForSession(edited), recorded);
      final lowered = Session.fromMap('a', {...s.toMap(), 'durationSec': 10 * 60, 'xpCap': recorded});
      expect(xpForSession(lowered), lessThan(recorded));
    });
  });

  group('L12 indoor run with distance steps', () {
    test('a distance step without a distance source runs on its estimated time and ends', () {
      final start = DateTime(2026, 11, 11, 8);
      final step = WorkoutStep(kind: 'warmup', zone: 'E', distanceM: 2000, paceMin: 330, paceMax: 370);
      var s = CardioState(
        sport: Sport.run,
        title: 'Fahrtspiel',
        start: start,
        indoor: true,
        steps: [step, WorkoutStep(kind: 'work', zone: 'I', durationSec: 60)],
      );
      expect(s.blindDistanceStep, isTrue);
      final (m, sec) = s.stepRemaining;
      expect(m, isNull, reason: 'no "2 km übrig" that never moves');
      expect(sec, greaterThan(600));
      s = CardioState(
        sport: Sport.run,
        title: 'Fahrtspiel',
        start: start,
        indoor: true,
        accumulatedSec: 13 * 60,
        steps: [step, WorkoutStep(kind: 'work', zone: 'I', durationSec: 60)],
      );
      expect(s.stepComplete, isTrue);
    });
  });

  group('widgets', () {
    testWidgets('M13 segments: one font size for all labels (or two lines), never one tiny', (t) async {
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: Segments<bool>(
                  segments: [Seg(false, label: 'Ab heute'), Seg(true, label: 'Ab nächstem Montag')],
                  value: false,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final a = t.widget<Text>(find.text('Ab heute')).style!.fontSize;
      final b = t.widget<Text>(find.text('Ab nächstem Montag')).style!.fontSize;
      expect(a, b);
      // Nothing scaled down on top: the FittedBox leaves the text at its size.
      final rb = t.getSize(find.text('Ab nächstem Montag'));
      expect(rb.width, lessThanOrEqualTo(125));
      expect(t.takeException(), isNull);
    });

    testWidgets('L1 / L2 minutes + seconds wheels show "80:10", the range in the same format, no jump', (t) async {
      int? v = 80 * 60 + 10;
      await t.pumpWidget(
        _app(
          Scaffold(
            body: StatefulBuilder(
              builder:
                  (c, set) => DurationField(
                    key: const ValueKey('f'),
                    value: v,
                    min: 12 * 60,
                    max: 80 * 60,
                    units: DurationUnits.ms,
                    label: 'x',
                    onChanged: (x) => set(() => v = x),
                  ),
            ),
          ),
        ),
      );
      expect(find.text('80:10'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('f')));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const ValueKey('durationValue'))).data, '80:10');
      expect(find.textContaining('12:00 und 80:00'), findsOneWidget);
      final h1 = t.getSize(find.byType(BottomSheet)).height;
      await t.drag(find.byKey(const ValueKey('durationWheel-s')), const Offset(0, 44.0 * 10));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('durationRange')), findsNothing);
      expect(t.getSize(find.byType(BottomSheet)).height, h1, reason: 'the error line is reserved');
      // The minute wheel starts at the minimum: nothing below 12 min to scroll to.
      await t.drag(find.byKey(const ValueKey('durationWheel-min')), const Offset(0, 44.0 * 200));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const ValueKey('durationValue'))).data, startsWith('12:'));
    });

    testWidgets('M11 distance dialog: empty can\'t be saved, "Ohne Distanz" answers none', (t) async {
      NumberAnswer? answer;
      var closed = false;
      await t.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder:
                  (c) => TextButton(
                    onPressed: () async {
                      answer = await askOptionalNumber(c, 'Distanz', noneLabel: de.withoutDistance, suffix: 'km');
                      closed = true;
                    },
                    child: const Text('go'),
                  ),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('askNumberSave'))).onPressed, isNull);
      await t.enterText(find.byKey(const ValueKey('askNumberField')), 'abc');
      await t.pump();
      expect(find.text(de.invalidNumber), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('askNumberNone')));
      await t.pumpAndSettle();
      expect(closed, isTrue);
      expect(answer, isNotNull);
      expect(answer!.value, isNull);
    });

    testWidgets('H4 / M9 "Als erledigt eintragen" on a later day: saved today, linked to that workout, duration field', (t) async {
      final repo = _FakeRepo();
      final plan = _run('fri', addDays(_today, 2));
      final o = await _overrides(repo, plans: [plan]);
      await t.pumpWidget(_app(ManualEntryPage(plan: plan), overrides: o));
      await t.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(const ValueKey('manualDuration')), findsOneWidget);
      expect(find.byKey(const ValueKey('manualOtherDay')), findsOneWidget);
      await t.scrollUntilVisible(find.byKey(const ValueKey('manualSave')), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const ValueKey('manualSave')));
      await t.pumpAndSettle();
      final s = repo.saved.single;
      expect(sameDay(s.start, DateTime.now()) || s.start.isBefore(DateTime.now()), isTrue);
      expect(repo.planUpdates['fri'], {'status': 'done', 'sessionId': s.id});
    });

    testWidgets('L11 too short with real sets: "Speichern" is the primary action, RPE shown', (t) async {
      final repo = _FakeRepo();
      final o = await _overrides(repo);
      final s = Session(
        id: 'g',
        sport: Sport.gym,
        title: 'Freies Training',
        start: DateTime.now(),
        durationSec: 40,
        exercises: [
          GymExercise(exId: '0025', name: 'bench', sets: [GymSet(weight: 60, reps: 8, done: true)]),
        ],
      );
      expect(tooShortHasWork(s), isTrue);
      await t.pumpWidget(_app(SessionSummaryPage(draft: s), overrides: o));
      await t.pumpAndSettle();
      expect(find.ancestor(of: find.text(de.save), matching: find.byKey(const ValueKey('tooShortSave'))), findsOneWidget);
      expect(t.widget(find.byKey(const ValueKey('tooShortSave'))), isA<FilledButton>());
      final empty = Session(id: 'e', sport: Sport.run, title: 'Lauf', start: DateTime.now(), durationSec: 20);
      expect(tooShortHasWork(empty), isFalse);
    });
  });
  group('plan settings wizard (H3, M5, M6, M7)', () {
    final race = addDays(_today, 87);
    final runner = _profile.copyWith(
      focus: TrainingFocus.run,
      trainingDays: const [2, 4, 6, 7],
      athlete: AthleteData(eventDate: race, eventDistance: 'hm', eventName: 'Halbmarathon', planWeeks: 12),
    );
    final goal = Goal(id: 'hm', type: GoalType.event, title: 'Halbmarathon', target: 21.1, eventKey: 'hm', created: _today, deadline: race);

    void phone(WidgetTester t) {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Widget opener() => Consumer(
      builder: (c, ref, _) {
        ref.watch(profileProvider);
        ref.watch(plansProvider);
        ref.watch(goalsProvider);
        return Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan))),
            child: const Text('open'),
          ),
        );
      },
    );

    Future<_FakeRepo> open(WidgetTester t) async {
      phone(t);
      final repo = _FakeRepo();
      await t.pumpWidget(_app(opener(), overrides: await _overrides(repo, profile: runner, goals: [goal])));
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return repo;
    }

    Future<void> toStep(WidgetTester t, Key key) async {
      for (var i = 0; i < 12 && find.byKey(key).evaluate().isEmpty; i++) {
        await t.tap(find.widgetWithText(FilledButton, de.next));
        await t.pumpAndSettle();
      }
      expect(find.byKey(key), findsOneWidget);
    }

    final nameField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == de.eventName);

    testWidgets('"Nur Planlänge": the review says the race goal goes, finishing removes it', (t) async {
      final repo = await open(t);
      await toStep(t, const ValueKey('goalKind'));
      await t.tap(find.text(de.goalKindWeeks));
      await t.pumpAndSettle();
      await toStep(t, const ValueKey('summaryRaceGoal'));
      expect(find.textContaining('Halbmarathon'), findsWidgets);
      expect(find.text(de.summaryRemoveRaceGoalOn), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, de.recreatePlan));
      await t.pumpAndSettle();
      expect(repo.deletedGoals, ['hm']);
      PlanService.reset();
    });

    testWidgets('kept on the review step: the goal stays', (t) async {
      final repo = await open(t);
      await toStep(t, const ValueKey('goalKind'));
      await t.tap(find.text(de.goalKindWeeks));
      await t.pumpAndSettle();
      await toStep(t, const ValueKey('summaryRaceGoal'));
      await t.tap(find.byKey(const ValueKey('removeRaceGoal')));
      await t.pumpAndSettle();
      expect(find.text(de.summaryRemoveRaceGoalOff), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, de.recreatePlan));
      await t.pumpAndSettle();
      expect(repo.deletedGoals, isEmpty);
      PlanService.reset();
    });

    testWidgets('the automatic race name follows the distance; Datum → Planlänge → Datum keeps the date', (t) async {
      await open(t);
      await toStep(t, const ValueKey('goalKind'));
      expect(t.widget<TextField>(nameField).controller!.text, 'Halbmarathon');
      await t.ensureVisible(find.byKey(const ValueKey('distance-10k')));
      await t.tap(find.byKey(const ValueKey('distance-10k')));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(nameField).controller!.text, isEmpty, reason: 'no "Halbmarathon" for a 10 km race');
      final dateText = DateFormat.yMMMd('de').format(race);
      expect(find.text(dateText), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('raceWhen')));
      await t.tap(find.text(de.raceByWeeks));
      await t.pumpAndSettle();
      await t.tap(find.text(de.raceByDate));
      await t.pumpAndSettle();
      expect(find.text(dateText), findsOneWidget, reason: 'the picked date is back');
      expect(find.byKey(const ValueKey('eventNeedsDate')), findsNothing);
    });

    testWidgets('✕ on the first step asks before discarding changes', (t) async {
      await open(t);
      // Unchanged: closes right away.
      await t.tap(find.byType(CloseButton));
      await t.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text(TrainingFocus.hybrid.label(de)));
      await t.pumpAndSettle();
      await t.tap(find.byType(CloseButton));
      await t.pumpAndSettle();
      expect(find.text(de.discardChanges), findsOneWidget);
      await t.tap(find.text(de.cancel));
      await t.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
    });
  });
}
