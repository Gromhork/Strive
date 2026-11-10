import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/features/goals/goal_forecast_widgets.dart';
import 'package:strive/features/goals/goal_status_page.dart';
import 'package:strive/features/home/goal_status_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// "Where I stand" card and page: no overflow at 360 dp in dark / light, DE / EN, larger text.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  var n = 0;
  String id() => 'p${n++}';
  final start = DateTime(2026, 11, 9);
  final now = start.add(const Duration(days: 28, hours: 12));
  final profile = UserProfile(
    level: 'intermediate',
    focus: TrainingFocus.run,
    experience: const {Sport.run},
    trainingDays: const [2, 4, 6, 7],
    athlete: AthleteData(
      raceTimes: const {'hm': 6300},
      runWeeklyKm: 30,
      longestRunKm: 14,
      sessionMinutes: 75,
      eventDistance: 'm',
      eventDate: start.add(const Duration(days: 7 * 17 + 6)),
      targetTimeSec: 3 * 3600 + 38 * 60,
    ),
  );
  final plans = PlanGenerator(l, profile, defaultTemplates(id, de: false), id).generate(start: start);
  final easy = PaceZones(Vdot.fromRace(21097.5, 6300)).easySlow;

  /// Sessions until [now]: quality runs at [speed] × the planned speed, after day [stopAfter] nothing.
  List<Session> sessions(double speed, int rpe, {int stopAfter = 99}) => [
    for (final w in plans.where((w) => w.date.isBefore(now) && w.date.difference(start).inDays <= stopAfter))
      Session(
        id: 's${w.id}',
        sport: w.sport,
        title: w.title,
        start: w.date.add(const Duration(hours: 7)),
        durationSec:
            (w.steps.fold<int>(0, (x, s) => x + estimateStepSec(s, w.sport, easyPace: easy, css: 100)) /
                    (w.intensity == 'tempo' || w.intensity == 'intervals' ? speed : 1))
                .round(),
        distanceM: (w.distanceKm ?? 0) * 1000,
        planId: w.id,
        rpe: rpe,
      ),
  ];

  final atRisk = GoalForecast.of(profile, plans: plans, sessions: sessions(0.92, 8, stopAfter: 10), now: now)!;
  final ahead = GoalForecast.of(profile, plans: plans, sessions: sessions(1.06, 6), now: now)!;
  final early = GoalForecast.of(profile, plans: plans, sessions: const [], now: start.add(const Duration(days: 1)))!;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required String lang,
    required ThemeData theme,
    double scale = 1,
    double height = 640,
  }) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: c!),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Future<List<String>> errorsOf(Future<void> Function() body) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.toString());
    try {
      await body();
    } finally {
      FlutterError.onError = old;
    }
    return errors;
  }

  test('scenarios used below', () {
    expect(atRisk.alert, isTrue);
    expect(ahead.status, ForecastStatus.ahead);
    expect(early.early, isTrue);
    expect(phaseSegments(plans, atRisk.planStart!, atRisk.raceDate).map((s) => s.$1), ['base', 'build', 'peak', 'taper']);
  });

  for (final lang in ['de', 'en']) {
    for (final (name, theme) in [('dark', AppTheme.dark()), ('light', AppTheme.light())]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('home card fits 360×640 ($lang, $name, x$scale)', (tester) async {
          final errors = await errorsOf(() async {
            for (final f in [atRisk, ahead, early]) {
              var adjusted = 0;
              await pump(
                tester,
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GoalStatusCardView(
                      forecast: f,
                      segments: f.planStart == null ? const [] : phaseSegments(plans, f.planStart!, f.raceDate),
                      now: now,
                      showAlert: f.alert,
                      onAdjustTarget: (s) => adjusted = s,
                      onRecalibrate: () {},
                      onDismiss: () {},
                    ),
                  ],
                ),
                lang: lang,
                theme: theme,
                scale: scale,
              );
              expect(find.byKey(const ValueKey('goalRiskNotice')), f.alert ? findsOneWidget : findsNothing);
              if (f.alert) {
                await tester.ensureVisible(find.byKey(const ValueKey('riskAdjust')));
                await tester.pump();
                await tester.tap(find.byKey(const ValueKey('riskAdjust')));
                expect(adjusted, f.suggestedSec);
              }
            }
          });
          expect(errors, isEmpty);
        });

        testWidgets('status page has no overflow ($lang, $name, x$scale)', (tester) async {
          final errors = await errorsOf(() async {
            for (final f in [atRisk, ahead]) {
              await pump(
                tester,
                GoalStatusView(
                  forecast: f,
                  segments: phaseSegments(plans, f.planStart!, f.raceDate),
                  outlook: PlanGenerator.outlook(profile, start: f.planStart!),
                  now: now,
                  onAdjustTarget: (_) {},
                  onRecalibrate: () {},
                  onSettings: () {},
                ),
                lang: lang,
                theme: theme,
                scale: scale,
                height: 2600,
              );
              expect(find.byType(PhaseTimeline), findsOneWidget);
            }
          });
          expect(errors, isEmpty);
        });
      }
    }
  }

  testWidgets('feasibility card: unrealistic target with one-tap adjust', (tester) async {
    final p = profile.copyWith(athlete: profile.athlete.merge({'targetTimeSec': 3 * 3600}));
    final f = PlanGenerator.feasibility(p, start: start, l: l);
    expect(f.issues, contains('targetUnrealistic'));
    int? set;
    final errors = await errorsOf(() async {
      await pump(tester, FeasibilityCard(f, planAnyway: true, onAdjustTarget: (s) => set = s), lang: 'de', theme: AppTheme.light());
      await tester.tap(find.byKey(const ValueKey('adjustTarget')));
    });
    expect(errors, isEmpty);
    expect(set, f.target!.suggestedSec);
  });

  test('risk notice comes back at most once a week', () {
    expect(GoalAlertSnooze.visible(atRisk, null, now), isTrue);
    expect(GoalAlertSnooze.visible(atRisk, now.subtract(const Duration(days: 3)), now), isFalse);
    expect(GoalAlertSnooze.visible(atRisk, now.subtract(const Duration(days: 7)), now), isTrue);
    expect(GoalAlertSnooze.visible(ahead, null, now), isFalse);
  });
}
