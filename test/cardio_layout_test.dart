import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/features/session/step_text.dart' show fmtPaceSec;
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/cardio_extra_pages.dart';
import 'package:strive/features/session/cardio_session_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/tracker.dart';
import 'package:strive/services/zones.dart';

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
    'run structured with results': _state(Sport.run, steps: _runSet, stepIndex: 3).copyWith(
      stepResults: const [
        StepResult(0, 600, 1750, complete: true),
        StepResult(1, 199, 800, complete: true),
        StepResult(2, 60, 150, complete: false),
      ],
      paceTime: const {300: 400, 245: 200, 420: 700, 900: 30},
      currentPace: 245,
    ),
    'pool structured with results': _state(Sport.swim, indoor: true, steps: _swimSet, stepIndex: 3).copyWith(
      stepResults: const [
        StepResult(0, 220, 200, complete: true),
        StepResult(1, 98, 100, complete: true),
        StepResult(2, 15, 0, complete: true),
      ],
    ),
    'ride structured done': _state(Sport.ride, steps: _rideSet, stepIndex: 4).copyWith(
      stepsDone: true,
      stepResults: [for (var i = 0; i < 5; i++) StepResult(i, _rideSet[i].durationSec!, 3000.0 * (i + 1), complete: i != 3)],
    ),
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

  testWidgets('tabs: only pages with data for the session; map last', (tester) async {
    const d = CardioTab.data, z = CardioTab.zones, p = CardioTab.plan, sp = CardioTab.splits, m = CardioTab.map;
    expect(cardioTabs(_state(Sport.run)), [d, z, sp, m]);
    expect(cardioTabs(_state(Sport.run, steps: _runSet)), [d, z, p, sp, m]);
    // Rides: no live power / HR → no zones page; plan page only when structured.
    expect(cardioTabs(_state(Sport.ride)), [d, sp, m]);
    expect(cardioTabs(_state(Sport.ride, steps: _rideSet)), [d, p, sp, m]);
    expect(cardioTabs(_state(Sport.ride, indoor: true, steps: _rideSet)), [d, p, sp]);
    expect(cardioTabs(_state(Sport.ride, indoor: true)), [d]);
    expect(cardioTabs(_state(Sport.swim, indoor: true)), [d, z, sp]);
    expect(cardioTabs(_state(Sport.swim, indoor: true, steps: _swimSet)), [d, z, p, sp]);
    expect(cardioTabs(_state(Sport.run, indoor: true)), [d]);
    expect(cardioTabs(_state(Sport.run, indoor: true, steps: _runSet)), [d, p, sp]);
    await _pump(tester, _state(Sport.run, indoor: true), 'en');
    expect(find.text('Map'), findsNothing);
    expect(find.text('Data'), findsNothing);
  });

  testWidgets('five tabs stay readable on 360 dp (icon above label, no overflow)', (tester) async {
    await _pump(tester, _state(Sport.run, steps: _runSet, stepIndex: 1), 'de');
    for (final t in ['Daten', 'Zonen', 'Soll/Ist', 'Ablauf', 'Karte']) {
      expect(find.text(t), findsOneWidget);
      // Rendered at ≥ 11 logical px (the FittedBox may shrink it slightly).
      final box = tester.getSize(find.text(t));
      expect(box.height, greaterThanOrEqualTo(11), reason: t);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('zones page: live pace in its zone, target zone flagged, time in zone from the pace histogram', (tester) async {
    // Default profile → default VDOT; a pace in the middle of its easy zone.
    final z = LiveZones.run(PaceZones(Vdot.defaultFor(const UserProfile().level)));
    final easy = ((z.cuts[0] + z.cuts[1]) / 2 / 5).round() * 5;
    final s = _state(Sport.run, steps: _runSet, stepIndex: 1).copyWith(currentPace: easy, paceTime: {easy: 600, 200: 60});
    await _pump(tester, s, 'en', tab: CardioTab.zones);
    expect(find.text(fmtPaceSec(easy, const Units(false))), findsOneWidget);
    expect(find.textContaining('Easy  ·'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsWidgets); // target: interval zone
    // Open ends: the fastest zone is "faster than", the slowest "slower than".
    expect(find.text('< ${fmtPaceSec(z.cuts.last, const Units(false))}'), findsOneWidget);
    expect(find.text('> ${fmtPaceSec(z.cuts.first, const Units(false))}'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget); // 600 s in the easy zone
    expect(find.text('11:00'), findsOneWidget); // total
    expect(tester.takeException(), isNull);
  });

  test('live zones: contiguous, slow → fast, pool time from lengths', () {
    final z = LiveZones.run(PaceZones(Vdot.defaultFor('beginner')));
    for (var i = 1; i < z.cuts.length; i++) {
      expect(z.cuts[i], lessThan(z.cuts[i - 1]));
    }
    expect(z.codes[z.indexOf(900)], 'REC');
    expect(z.codes[z.indexOf(200)], 'R');
    final sw = LiveZones.swim(110);
    expect(sw.codes[sw.indexOf(110)], 'CSS');
    expect(sw.codes[sw.indexOf(140)], 'REC');
    final pool = _state(Sport.swim, indoor: true); // 9 lengths of 27 s at 25 m = 1:48 /100 m
    expect(sw.timeIn(pool).fold<int>(0, (a, b) => a + b), 9 * 27);
  });

  test('step results: recorded on advance, statuses, undo in the pool reopens the step', () {
    var s = CardioState(sport: Sport.run, title: 't', start: DateTime(2026), steps: _runSet, accumulatedSec: 0);
    s = s.copyWith(stepIndex: 1, stepStartSec: 0, stepStartDist: 0, accumulatedSec: 196, distanceM: 800);
    s = s.advanceStep();
    expect(s.stepResults.single.index, 1);
    final r = s.stepResults.single;
    expect(resultPace(r, Sport.run), 245);
    expect(stepResultStatus(_runSet[1], r, Sport.run, measurable: true), 0);
    expect(stepResultStatus(_runSet[1], StepResult(1, 180, 800, complete: true), Sport.run, measurable: true), -1);
    expect(stepResultStatus(_runSet[1], StepResult(1, 180, 800, complete: true), Sport.run, measurable: false), 0);
    expect(stepResultStatus(_runSet[1], StepResult(1, 100, 300, complete: false), Sport.run, measurable: true), 2);

    var p = CardioState(sport: Sport.swim, title: 't', start: DateTime(2026), indoor: true, steps: _swimSet, accumulatedSec: 0);
    for (var i = 0; i < 8; i++) {
      p = p.copyWith(accumulatedSec: p.accumulatedSec + 30).addLength();
    }
    expect(p.stepIndex, 1);
    expect(p.stepResults.map((e) => e.index), [0]);
    p = p.undoLength();
    expect(p.stepIndex, 0);
    expect(p.stepResults, isEmpty);
  });

  testWidgets('plan page: projected finish vs plan and finished sections with status', (tester) async {
    final s = _state(
      Sport.run,
      steps: _runSet,
      stepIndex: 2,
    ).copyWith(stepResults: const [StepResult(0, 600, 1800, complete: true), StepResult(1, 180, 800, complete: true)]);
    await _pump(tester, s, 'en', tab: CardioTab.plan);
    expect(find.text('Projected finish'), findsOneWidget);
    expect(find.text('Intervals on target'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('Too fast'), findsOneWidget);
    expect(find.text('now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back button minimises the session (keeps recording), blocked while locked', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = _state(Sport.run);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trackerProvider.overrideWith(() => _FixedTracker(s)), profileOrDefaultProvider.overrideWithValue(const UserProfile())],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder:
                    (ctx) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CardioSessionPage())),
                        child: const Text('open'),
                      ),
                    ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Locked: back does nothing.
    await tester.tap(find.byTooltip('Lock screen'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CardioSessionPage), findsOneWidget);
    // Unlocked: back minimises, the session keeps running.
    await tester.longPress(find.text('Hold to unlock'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CardioSessionPage), findsNothing);
    expect(container.read(trackerProvider), isNotNull);
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
