import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/home/home_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';

void main() {
  final today = dayOnly(DateTime.now());
  PlannedWorkout w(String id, int dayOffset, Sport sport, String title) =>
      PlannedWorkout(id: id, date: today.add(Duration(days: dayOffset)), sport: sport, title: title);

  Future<List<String>> pump(WidgetTester tester, String lang, List<PlannedWorkout> plans, {Sport? filter}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = old);
    final container = ProviderContainer(
      overrides: [planListProvider.overrideWithValue(plans), sessionListProvider.overrideWithValue(const [])],
    );
    addTearDown(container.dispose);
    if (filter != null) container.read(sportFilterProvider.notifier).set(filter);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: SingleChildScrollView(child: TodayCard()))),
        ),
      ),
    );
    await tester.pump();
    return errors;
  }

  for (final lang in ['de', 'en']) {
    final l = lookupAppLocalizations(Locale(lang));

    testWidgets('no plan yet: "create plan" ($lang, 360×640)', (tester) async {
      final errors = await pump(tester, lang, [w('old', -3, Sport.run, 'Old run')]);
      expect(find.text(l.noPlanYet), findsOneWidget);
      expect(find.byKey(const ValueKey('todayCreatePlan')), findsOneWidget);
      expect(find.text(l.restDay), findsNothing);
      expect(errors, isEmpty);
    });

    testWidgets('plan exists, nothing today: rest day with the next workout ($lang, 360×640)', (tester) async {
      final next = w('n', 2, Sport.run, 'Tempo run with a rather long title that must not overflow');
      final errors = await pump(tester, lang, [next]);
      expect(find.text(l.restDay), findsOneWidget);
      final day = DateFormat.EEEE(lang).format(next.date);
      expect(find.text(l.todayNext(next.title, day)), findsOneWidget);
      expect(find.byKey(const ValueKey('todayCreatePlan')), findsNothing);
      expect(errors, isEmpty);
    });

    testWidgets('today\'s workout hidden by the sport filter is announced ($lang, 360×640)', (tester) async {
      final errors = await pump(tester, lang, [w('r', 0, Sport.run, 'Easy run'), w('n', 3, Sport.gym, 'Push')], filter: Sport.gym);
      expect(find.text(l.todayHiddenByFilter(1)), findsOneWidget);
      expect(find.text(l.restDay), findsNothing);
      await tester.tap(find.text(l.showAllSports));
      await tester.pump();
      expect(find.text('Easy run'), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets('today\'s workout is shown ($lang, 360×640)', (tester) async {
      final errors = await pump(tester, lang, [w('r', 0, Sport.run, 'Easy run')]);
      expect(find.text('Easy run'), findsOneWidget);
      expect(find.text(l.todaysWorkout), findsOneWidget);
      expect(errors, isEmpty);
    });
  }
}
