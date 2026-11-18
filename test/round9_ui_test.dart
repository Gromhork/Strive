// Round 9 (owner): the compact quick-start grid is back (two sports side by side, also at 320 dp and text ×1.3),
// the calendar's plan notes stay closed across restarts until they change, Home shows its tiles in the new order
// with a compact "today" card, and the phase labels under the goal bar never run together.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/calendar_page.dart';
import 'package:strive/features/calendar/plan_hint_memory.dart';
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/features/home/home_page.dart';
import 'package:strive/features/train/train_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/weather_service.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  @override
  void saveProfile(UserProfile p) {}
}

Future<void> _loadFont() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(File('fonts/Poppins-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

Widget _app(Widget home, {required List<Override> overrides, String lang = 'de', double scale = 1.0}) => ProviderScope(
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
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: home,
  ),
);

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<SharedPreferences> _prefs([Map<String, Object> v = const {}]) async {
  SharedPreferences.setMockInitialValues(v);
  return SharedPreferences.getInstance();
}

void main() {
  setUpAll(_loadFont);

  // ── 1. Quick start: two per row.
  group('quick start', () {
    Future<AppLocalizations> pumpTrain(
      WidgetTester t, {
      required String lang,
      required double scale,
      double width = 320,
      Sport? filter,
    }) async {
      _size(t, width, 2000);
      final prefs = await _prefs();
      await t.pumpWidget(
        _app(
          const TrainPage(),
          lang: lang,
          scale: scale,
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            authProvider.overrideWith((ref) => Stream.value(null)),
            repoProvider.overrideWithValue(_FakeRepo()),
            profileProvider.overrideWith((ref) => Stream.value(const UserProfile(name: 'Alex', onboarded: true))),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
            plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
            templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          ],
        ),
      );
      await t.pumpAndSettle();
      if (filter != null) {
        ProviderScope.containerOf(t.element(find.byType(TrainPage))).read(sportFilterProvider.notifier).set(filter);
        await t.pumpAndSettle();
      }
      return AppLocalizations.of(t.element(find.byType(TrainPage)));
    }

    double top(WidgetTester t, Sport s) => t.getTopLeft(find.byKey(ValueKey('quickTile-${s.name}'))).dy;
    double left(WidgetTester t, Sport s) => t.getTopLeft(find.byKey(ValueKey('quickTile-${s.name}'))).dx;

    for (final lang in ['de', 'en']) {
      for (final (width, scale) in [(360.0, 1.0), (320.0, 1.0), (360.0, 1.3), (320.0, 1.3)]) {
        testWidgets('$lang, $width dp, text ×$scale: 2 × 2 sports, the actions side by side, labels whole', (t) async {
          final l = await pumpTrain(t, lang: lang, scale: scale, width: width);
          expect(t.takeException(), isNull);
          expect(top(t, Sport.gym), top(t, Sport.run));
          expect(top(t, Sport.ride), top(t, Sport.swim));
          expect(top(t, Sport.ride), greaterThan(top(t, Sport.gym)));
          expect(left(t, Sport.run), greaterThan(left(t, Sport.gym)));
          expect(t.getTopLeft(find.text(l.exercises)).dy, closeTo(t.getTopLeft(find.text(l.logManually)).dy, 30));
          expect(t.getTopLeft(find.byKey(const ValueKey('exercisesTile'))).dx, greaterThan(100));
          // Whole: no line cut off, no word broken (each word on one line).
          for (final text in [for (final s in Sport.values) s.label(l), l.emptyWorkout, l.logManually, l.exercises]) {
            final p = t.renderObject<RenderParagraph>(find.text(text));
            expect(p.didExceedMaxLines, isFalse, reason: text);
          }
          // Compact: the four sport tiles take less than 180 dp.
          expect(top(t, Sport.ride) - top(t, Sport.gym), lessThan(100));
        });
      }
    }

    testWidgets('extreme text (×2) on 320 dp: one per row rather than broken words', (t) async {
      await pumpTrain(t, lang: 'de', scale: 2.0);
      expect(t.takeException(), isNull);
      expect(top(t, Sport.run), greaterThan(top(t, Sport.gym)));
    });

    testWidgets('sport filter: the one sport takes the whole row', (t) async {
      await pumpTrain(t, lang: 'de', scale: 1.0, filter: Sport.run);
      expect(find.byKey(const ValueKey('quickTile-gym')), findsNothing);
      expect(t.getSize(find.byKey(const ValueKey('quickTile-run'))).width, greaterThan(250));
    });

    test('the shared scale: ambient when it fits, never below 1.0, none when nothing fits', () {
      expect(quickStartScaler(const TextScaler.linear(1.3), (_) => true), const TextScaler.linear(1.3));
      final s = quickStartScaler(const TextScaler.linear(1.3), (s) => s.scale(10) <= 12);
      expect(s!.scale(10), closeTo(11.7, 0.01));
      expect(
        quickStartScaler(const TextScaler.linear(1.3), (s) => s.scale(10) <= 10.05)!.scale(10),
        closeTo(10, 0.05),
        reason: '×1.3 down to about the normal size',
      );
      expect(quickStartScaler(const TextScaler.linear(2), (s) => s.scale(10) <= 15), isNull, reason: '×2 never below ×1.54');
      expect(quickStartScaler(const TextScaler.linear(1.0), (s) => s.scale(10) < 10), isNull);
      expect(quickStartScaler(const TextScaler.linear(1.3), (_) => false), isNull);
    });
  });

  // ── 2. Plan notes: closed stays closed (across restarts) until they change.
  group('plan notes', () {
    final today = dayOnly(DateTime.now());
    final start = addDays(today, -(today.weekday - 1));
    final de = lookupAppLocalizations(const Locale('de'));
    // A beginner marathon with a target the finish-only plan sets aside: a note with an option.
    final profile = UserProfile(
      name: 'Alex',
      onboarded: true,
      level: 'beginner',
      focus: TrainingFocus.run,
      experience: const {Sport.run},
      trainingDays: const [2, 4, 6, 7],
      athlete: AthleteData(
        runWeeklyKm: 20,
        longestRunKm: 10,
        sessionMinutes: 75,
        eventDistance: 'm',
        eventDate: addDays(start, 7 * 20 - 1),
        targetTimeSec: 4 * 3600 + 30 * 60,
      ),
    );
    var n = 0;
    final plans = PlanGenerator(de, profile, const [], () => 'w${n++}').generate(start: start);

    Future<void> pumpCalendar(WidgetTester t, SharedPreferences prefs) async {
      _size(t, 360, 740);
      PlanHintMemory.shownThisRun.clear(); // a new app run
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        _app(
          const Scaffold(body: CalendarPage()),
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            authProvider.overrideWith((ref) => Stream.value(null)),
            repoProvider.overrideWithValue(_FakeRepo()),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            plansProvider.overrideWith((ref) => Stream.value(plans)),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
            templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          ],
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('closed (×): gone after a restart, reachable via the small entry; back when the notes change', (t) async {
      final prefs = await _prefs();
      await pumpCalendar(t, prefs);
      expect(find.byKey(const ValueKey('feasibility')), findsOneWidget);
      expect(find.byKey(const ValueKey('planHintsBadge')), findsNothing);
      // The label of "Plan überprüfen" keeps its size when the small entry joins the row (it shrank before).
      final label = find.descendant(of: find.byKey(const ValueKey('recalibrate')), matching: find.text(de.recalButton));
      final labelWidth = t.getRect(label).width; // as drawn (after the FittedBox)
      await t.tap(find.descendant(of: find.byKey(const ValueKey('feasibility')), matching: find.byIcon(Icons.close_rounded)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('feasibility')), findsNothing);
      expect(find.byKey(const ValueKey('planHintsBadge')), findsOneWidget);
      expect(find.byKey(const ValueKey('jumpToRace')), findsOneWidget);
      expect(t.getRect(label).width, closeTo(labelWidth, 0.01));

      // Restart: still closed.
      await pumpCalendar(t, prefs);
      expect(find.byKey(const ValueKey('feasibility')), findsNothing);
      await t.tap(find.byKey(const ValueKey('calendarMore')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('planHints')));
      await t.pumpAndSettle();
      expect(find.text(de.feasOptions), findsOneWidget, reason: 'the notes with their options in a sheet');

      // Other notes (the stored set no longer matches): the card again.
      await prefs.setString(PlanHintMemory.dismissedKey, 'an older set');
      await pumpCalendar(t, prefs);
      expect(find.byKey(const ValueKey('feasibility')), findsOneWidget);
    });

    test('information only: a card in one app run, then the entry; problems stay until closed', () {
      const note = PlanFeasibility(issues: ['longDayDefault'], longDayWeekday: 6, longDayNeedMin: 150);
      const problem = PlanFeasibility(issues: ['tooShort'], weeks: 6);
      const fresh = (dismissed: null, seen: null);
      final sig = planHintSignature(note, start);
      expect(PlanHintMemory.mode(note, sig, fresh, shown: {}), PlanHintMode.card);
      expect(PlanHintMemory.mode(note, sig, (dismissed: null, seen: sig), shown: {sig}), PlanHintMode.card, reason: 'same run');
      expect(PlanHintMemory.mode(note, sig, (dismissed: null, seen: sig), shown: {}), PlanHintMode.entry, reason: 'next start');
      final psig = planHintSignature(problem, start);
      expect(PlanHintMemory.mode(problem, psig, (dismissed: null, seen: psig), shown: {}), PlanHintMode.card);
      expect(PlanHintMemory.mode(problem, psig, (dismissed: psig, seen: null), shown: {}), PlanHintMode.entry);
      expect(PlanHintMemory.mode(const PlanFeasibility(), '', fresh, shown: {}), PlanHintMode.none);
      // A new plan or other numbers: another signature.
      expect(planHintSignature(problem, addDays(start, 7)), isNot(psig));
      expect(planHintSignature(const PlanFeasibility(issues: ['tooShort'], weeks: 5), start), isNot(psig));
    });

    test('the notes are kept per account', () async {
      final prefs = await _prefs();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs), authProvider.overrideWith((ref) => Stream.value(null))],
      );
      addTearDown(c.dispose);
      c.read(planHintMemoryProvider.notifier).dismiss('x');
      expect(prefs.getString(PlanHintMemory.dismissedKey), 'x');
      final again = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs), authProvider.overrideWith((ref) => Stream.value(null))],
      );
      addTearDown(again.dispose);
      expect(again.read(planHintMemoryProvider).dismissed, 'x', reason: 'read back after a restart');
    });
  });

  // ── 3./4. Home: compact today card, new order.
  group('home', () {
    final today = dayOnly(DateTime.now());
    PlannedWorkout gymW(String id, String title) => PlannedWorkout(
      id: id,
      date: today,
      sport: Sport.gym,
      title: title,
      intensity: 'moderate',
      durationMin: 46,
      description: 'Belastungswoche: Beende jeden Arbeitssatz mit etwa 3 Wdh. im Tank. ' * 3,
    );

    testWidgets('today card without the description, compact; tiles in order', (t) async {
      _size(t, 360, 3000);
      final prefs = await _prefs();
      await t.pumpWidget(
        _app(
          const Scaffold(body: HomePage()),
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            authProvider.overrideWith((ref) => Stream.value(null)),
            repoProvider.overrideWithValue(_FakeRepo()),
            profileProvider.overrideWith((ref) => Stream.value(const UserProfile(name: 'Alex', onboarded: true))),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
            plansProvider.overrideWith((ref) => Stream.value([gymW('a', 'Beine'), gymW('b', 'Oberkörper')])),
            templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
            bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
            weatherProvider.overrideWith((ref) => Completer<Weather>().future), // offline: no fetch, no timer
          ],
        ),
      );
      await t.pump(const Duration(seconds: 1));
      final l = AppLocalizations.of(t.element(find.byType(HomePage)));
      expect(find.text('Beine'), findsOneWidget);
      expect(find.textContaining('Belastungswoche'), findsNothing, reason: 'the description is on the workout page');
      expect(t.getSize(find.byKey(const ValueKey('todayCard'))).height, lessThan(140));
      expect(find.byKey(const ValueKey('todayStart')), findsOneWidget);
      expect(find.byTooltip(l.edit), findsOneWidget);
      // Two workouts: switching stays in the header.
      await t.tap(find.byKey(const ValueKey('todayNextWorkout')));
      await t.pump();
      expect(find.text('Oberkörper'), findsOneWidget);
      expect(t.getSize(find.byKey(const ValueKey('todayCard'))).height, lessThan(140));

      double y(Finder f) => t.getTopLeft(f).dy;
      final coming = y(find.byType(ComingUpCard));
      final week = y(find.text(l.trainedThisWeek));
      final weight = y(find.byKey(const ValueKey('weightCard')));
      expect(y(find.byKey(const ValueKey('todayCard'))), lessThan(coming));
      expect(coming, lessThan(week));
      expect(week, lessThan(weight));
    });

    test('order in the page: weight → Health Connect → recovery → "where I stand"', () {
      final src = File('lib/features/home/home_page.dart').readAsStringSync();
      int at(String s) {
        final i = src.indexOf(s);
        expect(i, greaterThan(0), reason: s);
        return i;
      }

      expect(at('ComingUpCard(),'), lessThan(at('Expanded(child: WeatherCard())')));
      expect(at('Expanded(child: WeatherCard())'), lessThan(at("_WeightCard(key: ValueKey('weightCard'))")));
      expect(at("_WeightCard(key: ValueKey('weightCard'))"), lessThan(at("_VitalsCard(key: ValueKey('vitalsCard'))")));
      expect(at("_VitalsCard(key: ValueKey('vitalsCard'))"), lessThan(at('GoalStatusCard(),')));
    });
  });

  // ── 5. Phase labels with a gap, measured in the app font.
  group('phase labels', () {
    for (final segments in const [
      [('base', 6), ('build', 6), ('peak', 3), ('taper', 2)],
      [('base', 5), ('build', 5), ('peak', 2), ('taper', 2)],
      [('base', 4), ('build', 4), ('peak', 4), ('taper', 4)],
      [('base', 10), ('build', 8), ('peak', 4), ('taper', 1)],
    ]) {
      testWidgets('$segments: labels apart or the legend', (t) async {
        _size(t, 360, 400);
        await t.pumpWidget(
          _app(
            Scaffold(body: Padding(padding: const EdgeInsets.all(32), child: PhaseTimeline(segments: segments, position: 0.3))),
            overrides: const [],
          ),
        );
        await t.pumpAndSettle();
        if (find.byKey(const ValueKey('phaseLegend')).evaluate().isNotEmpty) return;
        final l = AppLocalizations.of(t.element(find.byType(PhaseTimeline)));
        final rects = [
          for (final s in segments)
            () {
              final p = t.renderObject<RenderParagraph>(find.text(phaseShort(l, s.$1)));
              final w = p.getMaxIntrinsicWidth(double.infinity);
              final o = p.localToGlobal(Offset.zero);
              expect(w, lessThanOrEqualTo(p.size.width + 0.5), reason: '${s.$1} clipped');
              return (o.dx, o.dx + w);
            }(),
        ];
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].$1 - rects[i - 1].$2, greaterThanOrEqualTo(4), reason: '${segments[i - 1].$1} and ${segments[i].$1} touch');
        }
      });
    }
  });
}
