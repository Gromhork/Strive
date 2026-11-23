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

  test('next Monday', () {
    expect(nextMonday(today), DateTime(2026, 11, 16));
    expect(nextMonday(DateTime(2026, 11, 16)), DateTime(2026, 11, 23), reason: 'on a Monday: the following one');
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

  testWidgets('nothing open: no dialog, the plan starts today', (tester) async {
    final r = await open(tester, [w('done', -3, status: 'done'), w('done2', 1, status: 'done')]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(r, today);
  });

  testWidgets('round 10: a missed past workout alone is part of the old plan – asked, counted', (tester) async {
    final de = lookupAppLocalizations(const Locale('de'));
    final r = await open(
      tester,
      [w('past', -3), w('done', 1, status: 'done')],
      interact: () async {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('Dein bisheriger Plan wird ersetzt – 1 offene Einheit (auch selbst hinzugefügte) wird gelöscht'),
          findsOneWidget,
        );
        await tester.tap(find.text(de.replacePlanOk));
        await tester.pumpAndSettle();
      },
    );
    expect(r, today);
  });

  testWidgets('asks with the count of every open workout, "from next Monday" starts the plan on Monday', (tester) async {
    final de = lookupAppLocalizations(const Locale('de'));
    // The old plan goes entirely (round 10): the missed and the skipped workout count, the done one stays.
    final plans = [
      w('a', 0),
      w('b', 2),
      w('c', 5),
      w('d', 9),
      w('missed', -2),
      w('skip', 3, status: 'skipped'),
      w('done', -1, status: 'done'),
    ];
    final r = await open(
      tester,
      plans,
      interact: () async {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('Dein bisheriger Plan wird ersetzt – 6 offene Einheiten (auch selbst hinzugefügte) werden gelöscht'),
          findsOneWidget,
        );
        expect(find.text(de.replacePlanKeeps), findsOneWidget);
        await tester.tap(find.text(de.replaceFromMonday));
        await tester.pumpAndSettle();
        // Review r10-N3: from next Monday the old plan runs until then – this week's open workouts (a, b, skip) stay,
        // only the rest goes (c on Monday, d, the missed one); the count is per choice.
        expect(
          find.textContaining('3 offene Einheiten (auch selbst hinzugefügte) werden gelöscht. Der neue Plan beginnt am Mo., 16. Nov.'),
          findsOneWidget,
        );
        expect(find.text(de.replacePlanBridge(3)), findsOneWidget);
        expect(find.textContaining('dieser Woche bleiben'), findsOneWidget);
        // Back to "from today": everything open goes, no bridge note.
        await tester.tap(find.text(de.replaceFromToday));
        await tester.pumpAndSettle();
        expect(find.textContaining('6 offene Einheiten (auch selbst hinzugefügte) werden gelöscht'), findsOneWidget);
        expect(find.byKey(const ValueKey('replaceBridge')), findsNothing);
        await tester.tap(find.text(de.replaceFromMonday));
        await tester.pumpAndSettle();
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
