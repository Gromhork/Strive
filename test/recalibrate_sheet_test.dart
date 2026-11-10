import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/calendar_page.dart';
import 'package:strive/features/calendar/recalibrate_sheet.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_recalibrate.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final updated = <String, Map<String, dynamic>>{};
  UserProfile? savedProfile;
  @override
  void updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) => updated.addAll(plans);
  @override
  void saveProfile(UserProfile p) => savedProfile = p;
}

Widget _app(Widget home, String lang, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.dark(),
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

void main() {
  final today = dayOnly(DateTime.now());
  PlannedWorkout w(String id, int day, String title, {String intensity = 'easy', Sport sport = Sport.run, String status = 'planned'}) =>
      PlannedWorkout(
        id: id,
        date: today.add(Duration(days: day)),
        sport: sport,
        title: title,
        intensity: intensity,
        durationMin: 50,
        distanceKm: 8,
        status: status,
      );
  PlannedWorkout edit(PlannedWorkout p, Map<String, dynamic> m) => PlannedWorkout.fromMap(p.id, {...p.toMap(), ...m});

  final tempo = w('a', 1, 'Tempolauf mit einem ziemlich langen Titel', intensity: 'tempo');
  final easy = w('b', 2, 'Lockerer Lauf');
  final missed = w('c', -1, 'Intervalle', intensity: 'intervals');
  final result = Recalibration(
    reasons: const [RecalReason.rpeHigh, RecalReason.lowCompletion, RecalReason.fasterRuns],
    stats: const RecalStats(rated: 4, tooHard: 2, tooEasy: 0, completion: 0.62, cutShort: 0, oldVdot: 41.2, newVdot: 43.2),
    changes: [
      RecalChange(tempo, edit(tempo, {'title': 'Lockerer Lauf', 'intensity': 'easy', 'durationMin': 40}), RecalKind.toEasy),
      RecalChange(easy, edit(easy, {'durationMin': 45, 'distanceKm': 7.2}), RecalKind.easier),
      RecalChange(missed, edit(missed, {'date': dayKey(today.add(const Duration(days: 3)))}), RecalKind.moved),
    ],
  );

  for (final lang in ['de', 'en']) {
    testWidgets('preview shows reasons and every change, no overflow at 360 px ($lang)', (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var applied = 0;
      await tester.pumpWidget(_app(Scaffold(body: RecalibrationSheet(result: result, onApply: (_) => applied++)), lang));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(lang));
      expect(tester.takeException(), isNull);
      expect(find.text(l.recalWhyRpeHigh), findsOneWidget);
      expect(find.text(l.recalWhyCompletion(62)), findsOneWidget);
      expect(find.text(l.recalWhyFaster('41.2', '43.2')), findsOneWidget);
      for (final k in [RecalKind.toEasy, RecalKind.easier, RecalKind.moved]) {
        expect(find.text(RecalibrationSheet.kindStyle(l, k).$3), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('recalApply')));
      expect(applied, 1);
    });
  }

  for (final lang in ['de', 'en']) {
    testWidgets('gaps in the plan: own section with tick boxes, unticked refills are not applied, no overflow at 360 px ($lang)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l = lookupAppLocalizations(Locale(lang));
      final thu = w('g1', 1, 'Dauerlauf mit einem wirklich sehr langen Titel, der umbrechen muss');
      final sat = w('g2', 3, 'Langer Lauf', intensity: 'long');
      final easyNow = edit(sat, {'intensity': 'easy', 'title': 'Lockerer Lauf'});
      final gaps = Recalibration(
        reasons: const [RecalReason.planGaps],
        stats: const RecalStats(rated: 4, tooHard: 0, tooEasy: 0, completion: 1, cutShort: 0, oldVdot: 42, newVdot: null, gaps: 2),
        changes: [
          RecalChange(tempo, edit(tempo, {'durationMin': 45}), RecalKind.easier),
          RecalChange(thu, thu, RecalKind.added, gap: const GapNote(GapWhy.missing)),
          RecalChange(sat, easyNow, RecalKind.added, gap: const GapNote(GapWhy.emptyWeek, downgraded: true, shortened: true)),
        ],
      );
      Recalibration? applied;
      await tester.pumpWidget(_app(Scaffold(body: RecalibrationSheet(result: gaps, onApply: (r) => applied = r)), lang));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(l.recalGapsTitle), findsOneWidget);
      expect(find.text(l.recalWhyGaps(2)), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.textContaining(l.recalGapDowngraded), findsOneWidget);
      expect(find.text(l.recalApply(3)), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text(l.recalApply(2)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recalApply')));
      expect(applied!.additions.map((p) => p.id), ['g2']);
      expect(applied!.additions.single.intensity, 'easy');
      expect(applied!.updates.keys, ['a']);
    });
  }

  testWidgets('nothing to change: on-track message, no apply button', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecalibrationSheet(
            result: const Recalibration(
              reasons: [],
              stats: RecalStats(rated: 0, tooHard: 0, tooEasy: 0, completion: null, cutShort: 0, oldVdot: 42, newVdot: null),
              changes: [],
            ),
            onApply: (_) {},
          ),
        ),
        'en',
      ),
    );
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.recalOnTrack), findsOneWidget);
    expect(find.text(l.recalGapsTitle), findsNothing);
    expect(find.text(l.recalNoRpe), findsOneWidget);
    expect(find.byKey(const ValueKey('recalApply')), findsNothing);
  });

  testWidgets('calendar: recalibrate is the main action, export and new plan sit in the menu; apply writes only planned workouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final l = lookupAppLocalizations(const Locale('en'));
    final repo = _FakeRepo();
    // Two easy runs of the last days felt very hard; a done one stays untouched.
    final past = [
      for (var d = 1; d <= 3; d++) edit(w('d$d', -d, 'Easy run'), {'status': 'done', 'sessionId': 's$d'}),
    ];
    final sessions = [
      for (var d = 1; d <= 3; d++)
        Session(
          id: 's$d',
          sport: Sport.run,
          title: 'Easy run',
          start: today.subtract(Duration(days: d)),
          durationSec: 3000,
          rpe: 8,
          planId: 'd$d',
        ),
    ];
    final plans = [...past, tempo, easy, w('e', 4, 'Long run', intensity: 'long')];
    await tester.pumpWidget(
      _app(
        const Scaffold(body: CalendarPage()),
        'en',
        overrides: [
          repoProvider.overrideWithValue(repo),
          profileProvider.overrideWith((ref) => Stream.value(const UserProfile(level: 'intermediate', focus: TrainingFocus.run))),
          plansProvider.overrideWith((ref) => Stream.value(plans)),
          sessionsProvider.overrideWith((ref) => Stream.value(sessions)),
          templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.recalButton), findsOneWidget);
    expect(find.text(l.syncCalendar), findsNothing, reason: 'export is no longer a big button');
    await tester.tap(find.byKey(const ValueKey('calendarMore')));
    await tester.pumpAndSettle();
    expect(find.text(l.syncCalendar), findsOneWidget);
    expect(find.text(l.recalNewPlan), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recalibrate')));
    await tester.pumpAndSettle();
    expect(find.text(l.recalWhyRpeHigh), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recalApply')));
    await tester.pumpAndSettle();
    expect(repo.updated, isNotEmpty);
    expect(repo.updated.keys.toSet().intersection({'d1', 'd2', 'd3'}), isEmpty);
    expect(repo.updated['a']?['intensity'], 'easy');
    expect(find.text(l.recalApplied), findsOneWidget);
  });
}
