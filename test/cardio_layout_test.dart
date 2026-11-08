import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

CardioState _state(Sport sport, {bool indoor = false, List<WorkoutStep> steps = const [], int stepIndex = 0, bool paused = false}) {
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
  );
  if (!s.poolMode) return s;
  return s.copyWith(laps: 9, stepStartDist: 200, lengthSecs: List.filled(9, 27), lastLengthAt: 1200);
}

Future<void> _pump(WidgetTester tester, CardioState s, String lang) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [trackerProvider.overrideWith(() => _FixedTracker(s)), profileOrDefaultProvider.overrideWithValue(const UserProfile())],
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
        home: const CardioSessionPage(),
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
  for (final lang in ['de', 'en']) {
    for (final e in cases.entries) {
      testWidgets('no overflow at 360×640: ${e.key} ($lang)', (tester) async {
        await _pump(tester, e.value, lang);
        expect(tester.takeException(), isNull);
        expect(find.byType(CardioSessionPage), findsOneWidget);
      });
    }
  }

  testWidgets('pool shows LENGTH button, next-section button and no map page', (tester) async {
    await _pump(tester, _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 1), 'en');
    expect(find.text('LENGTH'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('INTERVAL 1/3'), findsOneWidget);
    expect(find.text('3 × 100 m · CSS'), findsOneWidget);
  });
}
