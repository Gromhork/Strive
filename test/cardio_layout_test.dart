import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/cardio_session_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/tracker.dart';

class _FixedTracker extends TrackerNotifier {
  _FixedTracker(this.fixed);
  final CardioState fixed;
  @override
  CardioState? build() => fixed;
}

const _swimSet = [
  WorkoutStep(kind: 'warmup', distanceM: 200, zone: 'REC', note: 'Locker, Lagen gemischt'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105, note: 'Im CSS-Tempo – gleichmäßig'),
  WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105, note: 'Im CSS-Tempo – gleichmäßig'),
  WorkoutStep(kind: 'recovery', durationSec: 15, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 100, zone: 'CSS', paceMin: 100, paceMax: 105),
  WorkoutStep(kind: 'cooldown', distanceM: 100, zone: 'REC'),
];

const _rideSet = [
  WorkoutStep(kind: 'warmup', durationSec: 600, zone: 'Z2', hrMin: 120, hrMax: 135),
  WorkoutStep(
    kind: 'work',
    durationSec: 180,
    zone: 'Z5',
    powerMin: 250,
    powerMax: 280,
    hrMin: 160,
    hrMax: 172,
    note: 'Hart, aber kontrolliert',
  ),
  WorkoutStep(kind: 'recovery', durationSec: 180, zone: 'Z1', hrMin: 100, hrMax: 120),
  WorkoutStep(kind: 'work', durationSec: 180, zone: 'Z5', powerMin: 250, powerMax: 280, hrMin: 160, hrMax: 172),
  WorkoutStep(kind: 'cooldown', durationSec: 600, zone: 'Z1'),
];

const _runSet = [
  WorkoutStep(kind: 'warmup', durationSec: 600, zone: 'E'),
  WorkoutStep(
    kind: 'work',
    distanceM: 800,
    zone: 'I',
    paceMin: 240,
    paceMax: 250,
    note: 'Locker aus der Hüfte, Arme aktiv – nicht überpacen',
  ),
  WorkoutStep(kind: 'recovery', durationSec: 90, zone: 'REC'),
  WorkoutStep(kind: 'work', distanceM: 800, zone: 'I', paceMin: 240, paceMax: 250),
  WorkoutStep(kind: 'cooldown', durationSec: 600, zone: 'E'),
];

final _route = [for (var i = 0; i < 40; i++) LatLng(52.5 + 0.0004 * i, 13.4 + 0.0006 * (i % 13))];

CardioState _state(
  Sport sport, {
  bool indoor = false,
  List<WorkoutStep> steps = const [],
  int stepIndex = 0,
  bool paused = false,
  bool autoPaused = false,
}) {
  final s = CardioState(
    sport: sport,
    title: 'Ein ziemlich langer Trainingstitel für kleine Bildschirme',
    start: DateTime(2026),
    accumulatedSec: 1234,
    runningSince: paused ? null : DateTime.now(),
    indoor: indoor,
    steps: steps,
    stepIndex: stepIndex,
    stepStartSec: 1200,
    distanceM: indoor ? 0 : 12345,
    currentPace: indoor ? null : 120,
    bestPace: indoor ? null : 90,
    paceHistory: indoor ? const [] : const [130, 125, 120, 118, 122],
    splits: indoor ? const [] : const [125, 118, 130],
    points: indoor ? const [] : _route,
    autoPaused: autoPaused,
    lapSecs: const [300, 290],
    lapDists: const [1000, 1010],
    laps: 2,
    lapStartSec: 590,
    lapStartDist: 2010,
  );
  if (!s.poolMode) return s;
  return s.copyWith(laps: 9, stepStartDist: 200, lengthSecs: List.filled(9, 27), lastLengthAt: 1200);
}

Future<void> _pump(
  WidgetTester tester,
  CardioState s,
  String lang, {
  Size size = const Size(360, 640),
  CardioTab tab = CardioTab.data,
  bool light = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [trackerProvider.overrideWith(() => _FixedTracker(s)), profileOrDefaultProvider.overrideWithValue(const UserProfile())],
      child: MaterialApp(
        theme: light ? AppTheme.light() : AppTheme.dark(),
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CardioSessionPage(initialTab: tab),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final cases = <String, CardioState>{
    'pool structured (work)': _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 1),
    'pool structured (rest)': _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 2),
    'pool structured (done)': _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 6).copyWith(stepsDone: true),
    'pool free': _state(Sport.swim, indoor: true),
    'pool paused': _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 1, paused: true),
    'ride outdoor structured': _state(Sport.ride, steps: _rideSet, stepIndex: 1),
    'ride outdoor free': _state(Sport.ride),
    'ride indoor structured': _state(Sport.ride, indoor: true, steps: _rideSet, stepIndex: 1),
    'ride indoor free': _state(Sport.ride, indoor: true),
    'run free': _state(Sport.run),
    'run paused': _state(Sport.run, paused: true),
    'ride paused': _state(Sport.ride, steps: _rideSet, stepIndex: 2, paused: true),
    'open water structured': _state(Sport.swim, steps: _swimSet, stepIndex: 1),
  };
  cases.addAll({
    'run structured (interval)': _state(Sport.run, steps: _runSet, stepIndex: 1),
    'run structured (warm-up)': _state(Sport.run, steps: _runSet),
    'run auto-paused': _state(Sport.run, steps: _runSet, stepIndex: 1, paused: true, autoPaused: true),
    'treadmill structured': _state(Sport.run, indoor: true, steps: _runSet, stepIndex: 1),
    'treadmill free': _state(Sport.run, indoor: true),
    'open water free': _state(Sport.swim),
  });
  for (final lang in ['de', 'en']) {
    for (final e in cases.entries) {
      testWidgets('no overflow at 360×640: ${e.key} ($lang)', (tester) async {
        await _pump(tester, e.value, lang);
        expect(tester.takeException(), isNull);
        expect(find.byType(CardioSessionPage), findsOneWidget);
      });
    }
  }

  // Every page of every sport, small and large phone, dark and light.
  for (final size in const [Size(360, 640), Size(411, 891)]) {
    for (final light in [false, true]) {
      for (final e in cases.entries) {
        for (final tab in cardioTabs(e.value)) {
          // The map page loads network tiles – covered separately below.
          if (tab == CardioTab.map) continue;
          testWidgets('no overflow ${size.width.toInt()}×${size.height.toInt()} ${light ? 'light' : 'dark'}: ${e.key} / ${tab.name}', (
            tester,
          ) async {
            await _pump(tester, e.value, 'de', size: size, tab: tab, light: light);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('tabs: data · map · splits outdoors, data · workout indoors, single page for a free treadmill run', (tester) async {
    expect(cardioTabs(_state(Sport.run)), [CardioTab.data, CardioTab.map, CardioTab.splits]);
    expect(cardioTabs(_state(Sport.ride, indoor: true, steps: _rideSet)), [CardioTab.data, CardioTab.splits]);
    expect(cardioTabs(_state(Sport.swim, indoor: true)), [CardioTab.data, CardioTab.splits]);
    expect(cardioTabs(_state(Sport.run, indoor: true)), [CardioTab.data]);
    await _pump(tester, _state(Sport.run, indoor: true), 'en');
    expect(find.text('Map'), findsNothing);
    expect(find.text('Data'), findsNothing);
  });

  testWidgets('map page: swiping does not change the page, the tab bar does', (tester) async {
    await _pump(tester, _state(Sport.run), 'en', tab: CardioTab.map);
    final pv = tester.widget<PageView>(find.byType(PageView));
    expect(pv.physics, isA<NeverScrollableScrollPhysics>());
    await tester.tap(find.text('Splits'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Current km 4'), findsOneWidget);
    final pv2 = tester.widget<PageView>(find.byType(PageView));
    expect(pv2.physics, isA<PageScrollPhysics>());
    tester.takeException(); // tile loading errors (no network in tests)
  });

  testWidgets('structured run: live pace is the big number, gauge and next step are shown', (tester) async {
    await _pump(tester, _state(Sport.run, steps: _runSet, stepIndex: 1), 'en');
    expect(find.text('Target'), findsOneWidget);
    expect(find.textContaining('Up next:'), findsOneWidget);
    expect(find.text('Current pace (/km)'), findsOneWidget);
  });

  testWidgets('lock button shows the hold-to-unlock overlay without layout errors', (tester) async {
    await _pump(tester, _state(Sport.ride), 'de');
    await tester.tap(find.byTooltip('Bildschirm sperren'));
    await tester.pump();
    expect(find.text('Gedrückt halten zum Entsperren'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-pause banner explains how it resumes', (tester) async {
    await _pump(tester, _state(Sport.run, paused: true, autoPaused: true), 'en');
    expect(find.textContaining('Resumes as soon as you move'), findsOneWidget);
  });

  testWidgets('pool shows LENGTH button, next-section button and no map page', (tester) async {
    await _pump(tester, _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 1), 'en');
    expect(find.text('LENGTH'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('INTERVAL 1/3'), findsOneWidget);
    expect(find.text('3 × 100 m · CSS pace'), findsOneWidget);
  });
}
