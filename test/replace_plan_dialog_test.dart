import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/replace_plan_dialog.dart';
import 'package:strive/l10n/gen/app_localizations.dart';

void main() {
  // Wednesday.
  final today = DateTime(2026, 11, 11);
  PlannedWorkout w(String id, int dayOffset, {String status = 'planned'}) =>
      PlannedWorkout(id: id, date: today.add(Duration(days: dayOffset)), sport: Sport.run, title: 'Run $id', status: status);

  test('next Monday and counting the planned workouts that would be replaced', () {
    expect(nextMonday(today), DateTime(2026, 11, 16));
    expect(nextMonday(DateTime(2026, 11, 16)), DateTime(2026, 11, 23), reason: 'on a Monday: the following one');
    final plans = [w('past', -2), w('done', 0, status: 'done'), w('a', 0), w('b', 2), w('c', 5), w('d', 9)];
    expect(plannedFrom(plans, today), 4);
    expect(plannedFrom(plans, nextMonday(today)), 2);
  });

  Future<DateTime?> open(WidgetTester tester, List<PlannedWorkout> plans, {Future<void> Function()? interact}) async {
    DateTime? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  result = await confirmReplacePlan(context, plans, now: today);
                  done = true;
                },
                child: const Text('go'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await interact?.call();
    expect(done, isTrue);
    return result;
  }

  testWidgets('nothing planned from today: no dialog, the plan starts today', (tester) async {
    final r = await open(tester, [w('past', -3), w('done', 1, status: 'done')]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(r, today);
  });

  testWidgets('asks with the count, "from next Monday" starts the plan on Monday', (tester) async {
    final de = lookupAppLocalizations(const Locale('de'));
    final plans = [w('a', 0), w('b', 2), w('c', 5), w('d', 9)];
    final r = await open(
      tester,
      plans,
      interact: () async {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('4 geplante Einheiten'), findsOneWidget);
        expect(find.text(de.replacePlanKeeps), findsOneWidget);
        await tester.tap(find.text(de.replaceFromMonday));
        await tester.pumpAndSettle();
        expect(find.textContaining('2 geplante Einheiten ab'), findsOneWidget);
        await tester.tap(find.text(de.replacePlanOk));
        await tester.pumpAndSettle();
      },
    );
    expect(r, DateTime(2026, 11, 16));
  });

  testWidgets('cancel returns null', (tester) async {
    final de = lookupAppLocalizations(const Locale('de'));
    final r = await open(
      tester,
      [w('a', 1)],
      interact: () async {
        await tester.tap(find.text(de.cancel));
        await tester.pumpAndSettle();
      },
    );
    expect(r, isNull);
  });
}
