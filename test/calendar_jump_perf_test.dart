import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/calendar_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';

Widget _app(Widget home, {List<Override> overrides = const [], ScrollController? primary}) => ProviderScope(
  overrides: overrides,
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
    home: primary == null ? home : PrimaryScrollController(controller: primary, child: home),
  ),
);

void main() {
  final today = dayOnly(DateTime.now());
  final l = lookupAppLocalizations(const Locale('de'));

  PlannedWorkout run(String id, int day, {String status = 'planned', String? sessionId}) => PlannedWorkout(
    id: id,
    date: addDays(today, day),
    sport: Sport.run,
    title: 'Lauf $id',
    intensity: 'easy',
    durationMin: 40,
    distanceKm: 7,
    status: status,
    sessionId: sessionId,
  );

  // A plan from 6 weeks back to 20 weeks ahead: three runs a week.
  final plans = [
    for (var w = -6; w <= 20; w++)
      for (final d in const [0, 2, 4]) run('p${w}_$d', 7 * w + d - (today.weekday - 1)),
  ];

  List<Override> data({List<PlannedWorkout>? p, List<Session> s = const []}) => [
    profileProvider.overrideWith((ref) => Stream.value(const UserProfile(level: 'intermediate', focus: TrainingFocus.run))),
    plansProvider.overrideWith((ref) => Stream.value(p ?? plans)),
    sessionsProvider.overrideWith((ref) => Stream.value(s)),
    templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
  ];

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder jump() => find.byKey(const ValueKey('jumpToToday'));
  bool jumpShown(WidgetTester tester) => tester.widget<JumpToTodayButton>(find.byType(JumpToTodayButton)).visible;
  IconData jumpIcon(WidgetTester tester) => tester.widget<JumpToTodayButton>(find.byType(JumpToTodayButton)).icon;

  testWidgets('week view: the Today button appears when the current week is scrolled away (arrow towards it) and brings it back', (
    tester,
  ) async {
    await phone(tester);
    final primary = ScrollController();
    addTearDown(primary.dispose);
    await tester.pumpWidget(_app(const Scaffold(body: CalendarPage()), overrides: data(), primary: primary));
    await tester.pumpAndSettle();
    expect(jumpShown(tester), isFalse, reason: 'the current week is in view');
    expect(find.text(l.currentWeek), findsOneWidget);

    // Scroll down into the future: the button points up.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(jumpShown(tester), isTrue);
    expect(jumpIcon(tester), Icons.arrow_upward_rounded);
    expect(find.text(l.currentWeek), findsNothing);

    await tester.tap(jump());
    await tester.pumpAndSettle();
    expect(primary.offset, 0, reason: 'back at the anchor: the current week on top');
    expect(find.text(l.currentWeek), findsOneWidget);
    expect(jumpShown(tester), isFalse);

    // Up into the past weeks: the button points down.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2500));
    await tester.pumpAndSettle();
    expect(jumpShown(tester), isTrue);
    expect(jumpIcon(tester), Icons.arrow_downward_rounded);
    await tester.tap(jump());
    await tester.pumpAndSettle();
    expect(primary.offset, 0);
    expect(jumpShown(tester), isFalse);
  });

  testWidgets('week view: far away (20 weeks) the jump does not animate through every week', (tester) async {
    await phone(tester);
    final primary = ScrollController();
    addTearDown(primary.dispose);
    await tester.pumpWidget(_app(const Scaffold(body: CalendarPage()), overrides: data(), primary: primary));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
    }
    expect(primary.offset, greaterThan(5000));
    await tester.tap(jump());
    await tester.pump(); // the jump close by happens at once …
    expect(primary.offset, lessThanOrEqualTo(740 * 1.5 + 1));
    await tester.pumpAndSettle(); // … then the short animation
    expect(primary.offset, 0);
    expect(jumpShown(tester), isFalse);
  });

  testWidgets('the Today button sits bottom centre, level with the add button and clear of it', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(const Scaffold(body: CalendarPage()), overrides: data()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();
    final b = tester.getRect(jump());
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(b.overlaps(fab), isFalse);
    expect((b.center.dy - fab.center.dy).abs(), lessThan(1), reason: 'same height as the add button');
    expect((b.center.dx - 180).abs(), lessThan(1), reason: 'centred');
  });

  testWidgets('month view: another month shows the button (arrow back to today), tapping returns to today and selects it', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(const Scaffold(body: CalendarPage()), overrides: data()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_view_month));
    await tester.pumpAndSettle();
    expect(jumpShown(tester), isFalse, reason: "today's month is shown");

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(jumpShown(tester), isTrue);
    expect(jumpIcon(tester), Icons.arrow_back_rounded);

    await tester.tap(jump());
    await tester.pumpAndSettle();
    expect(find.text(DateFormat.yMMMM('de').format(today)), findsOneWidget);
    expect(jumpShown(tester), isFalse);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(jumpShown(tester), isTrue);
    expect(jumpIcon(tester), Icons.arrow_forward_rounded);
  });

  test('CalendarIndex: plans and sessions by day, the plan a session fulfils', () {
    final s = Session(
      id: 's1',
      sport: Sport.run,
      title: 'Lauf',
      start: addDays(today, -1).add(const Duration(hours: 7)),
      durationSec: 2400,
    );
    final p1 = run('a', -2, status: 'done', sessionId: 's1');
    final p2 = run('b', -1);
    final p3 = run('c', -1);
    final idx = CalendarIndex(plans: [p1, p2, p3], sessions: [s], linked: {'a': s}, sessionPlan: {'s1': p1}, firstDay: p1.date);
    expect(idx.plansOn(addDays(today, -1)).map((p) => p.id), ['b', 'c'], reason: 'in list order');
    expect(idx.plansOn(addDays(today, -2)).single.id, 'a');
    expect(idx.plansOn(today), isEmpty);
    expect(idx.sessionsOn(addDays(today, -1)).single.id, 's1');
    expect(idx.sessionsOn(addDays(today, -1).add(const Duration(hours: 23))).single.id, 's1', reason: 'any time of the day');
    expect(idx.byId.keys, ['a', 'b', 'c']);
  });

  testWidgets('a session done instead of an earlier planned workout still shows "replaces" in the week list', (tester) async {
    await phone(tester);
    // Planned Monday … done the day after (today = the session's day).
    final planned = run('m', -1, status: 'done', sessionId: 'sx');
    final s = Session(
      id: 'sx',
      sport: Sport.run,
      title: 'Lauf m',
      start: today.add(const Duration(hours: 9)),
      durationSec: 2400,
      planId: 'm',
    );
    await tester.pumpWidget(_app(const Scaffold(body: CalendarPage()), overrides: data(p: [planned], s: [s])));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('replacesLabel')), findsOneWidget);
    expect(find.byKey(const ValueKey('doneElsewhere_m')), findsOneWidget);
    // On a Monday "the day before" lies in last week, which the week list does not show.
  }, skip: today.weekday == DateTime.monday);

  testWidgets("each day's add button keeps a 40 px target and its label", (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(const Scaffold(body: CalendarPage()), overrides: data()));
    await tester.pumpAndSettle();
    final add = find.byKey(ValueKey('addOn_${dayKey(today)}'));
    expect(add, findsOneWidget);
    expect(tester.getSize(add), const Size(40, 40));
    expect(find.bySemanticsLabel(l.planWorkout), findsWidgets);
  });

  test('dayKey stays yyyy-MM-dd', () {
    expect(dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    expect(dayKey(DateTime(2026, 11, 13)), '2026-11-13');
    expect(dayKey(DateTime(987, 1, 1)), '0987-01-01');
    expect(parseDayKey('2026-03-05'), DateTime(2026, 3, 5));
  });
}
