import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:strive/data/exercise_names_de.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/coach/coach_page.dart';
import 'package:strive/features/session/cardio_extra_pages.dart';
import 'package:strive/features/session/exercise_focus_page.dart';
import 'package:strive/features/session/session_summary_page.dart';
import 'package:strive/features/session/start_helpers.dart';
import 'package:strive/features/train/program_preview_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/coach_service.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/widgets/prescription.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final savedSessions = <Session>[];
  @override
  void saveSession(Session s) => savedSessions.add(s);
  @override
  void updatePlan(String id, Map<String, dynamic> data) {}
}

Widget _app(Widget home, String lang, List<Override> overrides, {ThemeData? theme}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: theme ?? AppTheme.dark(),
    locale: Locale(lang),
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

Future<List<Override>> _overrides(
  _FakeRepo repo, {
  List<PlannedWorkout> plans = const [],
  List<WorkoutTemplate> templates = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  return [
    prefsProvider.overrideWithValue(p),
    repoProvider.overrideWithValue(repo),
    profileProvider.overrideWith((ref) => Stream.value(const UserProfile())),
    sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
    templatesProvider.overrideWith((ref) => Stream.value(templates)),
    plansProvider.overrideWith((ref) => Stream.value(plans)),
    goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
    exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
  ];
}

Session _gym({int done = 4, int total = 15, int sec = 1800, String? templateId = 't'}) => Session(
  id: 'new',
  sport: Sport.gym,
  title: 'Ganzkörper A',
  start: DateTime.now().subtract(Duration(seconds: sec)),
  durationSec: sec,
  templateId: templateId,
  exercises: [
    GymExercise(
      exId: '0043',
      name: 'barbell full squat',
      sets: [for (var i = 0; i < total; i++) GymSet(weight: 60, reps: 6, done: i < done)],
    ),
  ],
);

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final now = DateTime(2026, 11, 10, 18);

  group('C5 coach context', () {
    Session run(int daysAgo) =>
        Session(id: 'r$daysAgo', sport: Sport.run, title: 'Lauf', start: addDays(now, -daysAgo), durationSec: 3600, distanceM: 10000);

    test('baseline not ready: no load ratio / fitness numbers, says so', () {
      final c = CoachService(
        profile: const UserProfile(),
        sessions: [run(1), run(3), run(5)],
        plans: const [],
        lang: 'de',
      ).contextText(now: now);
      expect(c, contains('BASELINE NOT READY'));
      expect(c, isNot(contains('ratio ')));
      expect(c, isNot(contains('CTL')));
      expect(c, isNot(contains('ATL')));
    });

    test('baseline ready after 21 days: ratio is passed (without ATL/CTL jargon)', () {
      final c = CoachService(
        profile: const UserProfile(),
        sessions: [for (var d = 1; d < 30; d += 2) run(d)],
        plans: const [],
        lang: 'de',
      ).contextText(now: now);
      expect(c, isNot(contains('BASELINE NOT READY')));
      expect(c, contains('ratio'));
      expect(c, isNot(contains('CTL')));
    });

    test('the real goal (triathlon distance, date, target) is named; system prompt bans jargon', () {
      final p = UserProfile(
        focus: TrainingFocus.triathlon,
        goals: const ['strength'],
        athlete: AthleteData(eventDistance: 'olympic', eventDate: addDays(now, 120), targetTimeSec: 3 * 3600),
      );
      final s = CoachService(profile: p, sessions: const [], plans: const [], lang: 'de');
      final c = s.contextText(now: now);
      expect(c, contains('MAIN GOAL: triathlon race'));
      expect(c, contains('olympic'));
      expect(c, contains('3:00:00'));
      expect(c, contains('never call it a strength goal'));
      final sys = s.systemText(now: now);
      expect(sys, contains('ZNS'));
      expect(sys, contains('SHORT'));
      for (final t in CoachService.glossaryTerms) {
        expect(sys, contains(t));
      }
    });
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('C1 coach answer uses onSurface (${theme.brightness.name})', (t) async {
      final o = await _overrides(_FakeRepo());
      await t.pumpWidget(_app(const Scaffold(body: CoachText(text: 'Hallo **du**\n- Punkt')), 'de', o, theme: theme));
      await t.pump();
      final rich = t.widget<RichText>(find.byType(RichText).first);
      expect(rich.text.style?.color, theme.colorScheme.onSurface);
      expect(find.text('•  '), findsOneWidget); // bullet glyph intact (no mojibake)
    });
  }

  group('C6 summary outcome', () {
    test('partial, full, free and too short', () {
      expect(summaryOutcome(_gym(done: 4, total: 15)), SummaryOutcome.partial);
      expect(summaryOutcome(_gym(done: 14, total: 15)), SummaryOutcome.planDone);
      expect(summaryOutcome(_gym(done: 4, total: 4, templateId: null)), SummaryOutcome.free);
      expect(summaryOutcome(_gym(sec: 40)), SummaryOutcome.tooShort);
      // Exercises without any done set are not in the draft – plannedSets counts them.
      expect(summaryOutcome(_gym(done: 4, total: 4), plannedSets: 15), SummaryOutcome.partial);
      final outdoor0 = Session(id: 'x', sport: Sport.run, title: 'Lauf', start: now, durationSec: 600);
      expect(summaryOutcome(outdoor0), SummaryOutcome.tooShort);
      final indoor = Session(id: 'x', sport: Sport.run, title: 'Lauf', start: now, durationSec: 600, indoor: true);
      expect(summaryOutcome(indoor), SummaryOutcome.free);
      final plan = PlannedWorkout(id: 'p', date: now, sport: Sport.run, title: 'Lauf', durationMin: 40, distanceKm: 8);
      final run5 = Session(id: 'x', sport: Sport.run, title: 'Lauf', start: now, durationSec: 1800, distanceM: 5000, planId: 'p');
      expect(summaryOutcome(run5, plan: plan), SummaryOutcome.partial);
      final run8 = Session(id: 'x', sport: Sport.run, title: 'Lauf', start: now, durationSec: 2400, distanceM: 7900, planId: 'p');
      expect(summaryOutcome(run8, plan: plan), SummaryOutcome.planDone);
    });

    Future<void> open(WidgetTester t, Session draft, List<Override> o, {int? plannedSets}) async {
      t.view.physicalSize = const Size(360, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: draft, plannedSets: plannedSets)),
                        ),
                    child: const Text('open'),
                  ),
                ),
          ),
          'de',
          o,
        ),
      );
      await t.pump();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('4 of 15 sets: no "Starke Leistung", partial headline; discard button with confirm', (t) async {
      final repo = _FakeRepo();
      await open(t, _gym(), await _overrides(repo), plannedSets: 15);
      expect(find.text(de.greatJob), findsNothing);
      expect(find.text(de.summaryPartial), findsOneWidget);
      final discard = find.byKey(const ValueKey('summaryDiscard'));
      await t.scrollUntilVisible(discard, 100, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(discard);
      await t.pumpAndSettle();
      expect(find.text(de.discardWorkout), findsOneWidget);
      await t.tap(discard);
      await t.pumpAndSettle();
      expect(find.text(de.discardSummaryBody), findsOneWidget);
      await t.tap(find.text(de.discard));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(repo.savedSessions, isEmpty);
    });

    testWidgets('too short: [Verwerfen] [Trotzdem speichern]', (t) async {
      final repo = _FakeRepo();
      await open(t, _gym(sec: 30), await _overrides(repo));
      expect(find.text(de.summaryTooShortTitle), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tooShortSave')));
      await t.pumpAndSettle();
      expect(repo.savedSessions, hasLength(1));
    });
  });

  test('M1 completing a set selects the next open set (not the done one)', () {
    List<GymSet> sets(List<bool> done) => [for (final d in done) GymSet(reps: 5, done: d)];
    // Set 2 (index 1) just completed, set 1 still open → set 3 next, then wraps.
    expect(nextOpenSet(sets([false, true, false]), 1), 2);
    expect(nextOpenSet(sets([false, true, true]), 1), 0);
    expect(nextOpenSet(sets([true, true, true]), 2), isNull);
  });

  group('I5 plan vs actual', () {
    test('behind = orange "hinter Plan", ahead = green "vor Plan"', () {
      expect(planDeltaLabel(de, 16), (de.planBehind, AppColors.warning));
      expect(planDeltaLabel(de, -16), (de.planAhead, AppColors.success));
      expect(planDeltaLabel(de, -16, shortened: true).$2, AppColors.warning);
      expect(de.planBehind, 'hinter Plan');
      expect(de.planProjected, 'Voraussichtlich fertig nach');
      expect(de.planStepsLeft(8), 'danach noch 8 Abschnitte');
      expect(de.planStepsLeft(1), 'danach noch 1 Abschnitt');
    });

    test('indoor run starting with a distance step: "left in total" counts down with time', () {
      final steps = [
        WorkoutStep(kind: 'steady', zone: 'E', distanceM: 5000, paceMin: 330, paceMax: 360),
        WorkoutStep(kind: 'cooldown', zone: 'E', durationSec: 600),
      ];
      CardioState at(int sec) =>
          CardioState(sport: Sport.run, title: 't', start: now, steps: steps, indoor: true, accumulatedSec: sec, stepStartSec: 0);
      expect(at(600).workoutLeftSec, lessThan(at(0).workoutLeftSec));
      expect(at(0).workoutLeftSec - at(600).workoutLeftSec, 600);
    });
  });

  group('I1 German exercise names and search', () {
    final raw = jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List;
    final db = ExerciseDb(raw.map((e) => Exercise.fromJson(e)).toList());

    test('every built-in program exercise has a German name', () {
      for (final id in commonExerciseIds) {
        expect(exerciseNamesDe[id], isNotNull, reason: id);
        expect(db.byId(id), isNotNull, reason: id);
      }
      expect(exerciseName('0043', 'barbell full squat', 'de'), 'Kniebeuge (Langhantel)');
      expect(exerciseName('0043', 'barbell full squat', 'en'), 'Barbell full squat');
      expect(term('quadriceps', 'de'), 'Quadrizeps');
    });

    test('"Bankdr" finds the barbell bench press first, English still works', () {
      expect(db.search('Bankdr', lang: 'de').first.id, '0025');
      expect(db.search('bench press', lang: 'de').first.id, '0025');
      expect(db.search('kniebeuge', lang: 'de').first.id, '0043');
      expect(db.search('Quadrizeps', lang: 'de'), isNotEmpty);
    });
  });

  test('I10 one coaching line: "Heute: 3 × 6 @ 72,5 kg", no AMRAP text in the box', () {
    const u = Units(false);
    final p = Prescription(weight: 72.5, reps: 6, source: LoadSource.history, setReps: const [6, 6, 6], amrap: true);
    final line = prescriptionToday(de, p, u, sets: 3);
    expect(line, startsWith('Heute: 3 × 6 @ 72'));
    expect(line, isNot(contains(de.amrapHint)));
    final mixed = Prescription(weight: 60, reps: 9, source: LoadSource.history, setReps: const [9, 9, 8]);
    expect(prescriptionToday(de, mixed, u, sets: 3), contains('9 · 9 · 8'));
  });

  test('N9 today\'s planned workout of the sport is found', () {
    final p = PlannedWorkout(id: 'p', date: dayOnly(now), sport: Sport.run, title: 'Lockerer Lauf');
    expect(plannedToday([p], Sport.run, now)?.id, 'p');
    expect(plannedToday([p], Sport.ride, now), isNull);
    expect(plannedToday([p], Sport.run, addDays(now, 1)), isNull);
  });

  testWidgets('I11 tapping a program opens a read-only preview with Start and a pencil', (t) async {
    final tpl = WorkoutTemplate(
      id: 't1',
      name: 'Ganzkörper A – Kniebeuge-Schwerpunkt mit langem Namen',
      sport: Sport.gym,
      exercises: [
        GymExercise(exId: '0043', name: 'barbell full squat', sets: [for (var i = 0; i < 3; i++) GymSet(reps: 5)]),
      ],
    );
    final o = await _overrides(_FakeRepo(), templates: [tpl]);
    await t.pumpWidget(_app(ProgramPreviewPage(template: tpl), 'de', o));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('startProgram')), findsOneWidget);
    expect(find.byKey(const ValueKey('editProgram')), findsOneWidget);
    expect(find.text('Kniebeuge (Langhantel)'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(t.takeException(), isNull);
  });
}
