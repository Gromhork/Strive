import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/auto_adjust.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/zones.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  final updates = <Map<String, Map<String, dynamic>>>[];
  @override
  void updateMany({
    Map<String, Map<String, dynamic>> plans = const {},
    Map<String, Map<String, dynamic>> templates = const {},
    Map<String, Map<String, dynamic>> sessions = const {},
  }) => updates.add(plans);
}

Widget _app(Widget home, String lang) => MaterialApp(
  theme: AppTheme.dark(),
  locale: Locale(lang),
  scaffoldMessengerKey: rootMessengerKey,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  final profile = UserProfile(level: 'intermediate', birthYear: 1990, athlete: const AthleteData(raceTimes: {'10k': 3000}));
  final pz = PaceZones(Vdot.of(profile.athlete)!);
  final today = dayOnly(DateTime.now());
  PlannedWorkout long(String id, DateTime d, double km) => PlannedWorkout(
    id: id,
    date: d,
    sport: Sport.run,
    title: 'Langer Lauf',
    intensity: 'long',
    durationMin: (km * pz.easySlow / 60).round(),
    distanceKm: km,
    phase: 'build',
    steps: [WorkoutStep(kind: 'steady', zone: 'E', distanceM: km * 1000, paceMin: pz.easyFast, paceMax: pz.easySlow)],
  );

  testWidgets('cut-short long run: next long run adjusted, notice with undo restores the original', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const Scaffold(body: SizedBox()), 'de'));
    final repo = _FakeRepo();
    final l = lookupAppLocalizations(const Locale('de'));
    final l1 = long('l1', today, 7), l2 = long('l2', today.add(const Duration(days: 7)), 9);
    final s = Session(
      id: 's1',
      sport: Sport.run,
      title: 'Lauf',
      start: today.add(const Duration(hours: 7)),
      durationSec: 5 * pz.easySlow,
      distanceM: 5000,
      rpe: 8,
      planId: 'l1',
    );
    final c = autoAdjustAfterSessions(repo: repo, l: l, profile: profile, plans: [l1, l2], sessions: const [], done: [(s, l1)]);
    expect(c, hasLength(1));
    expect(repo.updates.single.keys, ['l2']);
    expect(repo.updates.single['l2']!['auto'], isA<Map>());
    await tester.pumpAndSettle();
    expect(find.textContaining('Plan angepasst: Langer Lauf'), findsOneWidget);
    expect(find.textContaining('statt 9'), findsOneWidget);
    await tester.tap(find.text(l.undo));
    await tester.pump();
    final undo = repo.updates.last['l2']!;
    expect(undo['distanceKm'], 9);
    expect(undo['auto'], isA<FieldValue>());
    // Same session again (watch import after the phone recording): nothing new.
    final adjusted = PlannedWorkout.fromMap('l2', {...l2.toMap(), ...repo.updates.first['l2']!});
    expect(autoAdjustAfterSessions(repo: repo, l: l, profile: profile, plans: [l1, adjusted], sessions: [s], done: [(s, l1)]), isEmpty);
  });

  for (final lang in ['de', 'en']) {
    testWidgets('marker on the planned workout: reason, original, undo – no overflow at 360 px ($lang)', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = PlannedWorkout.fromMap('l2', {
        ...long('l2', today, 7.7).toMap(),
        'auto': AutoAdjustment(sessionId: 's1', reason: 'longCutShort', at: today, durationMin: 60, distanceKm: 9).toMap(),
      });
      var undone = false;
      await tester.pumpWidget(
        _app(Scaffold(body: ListView(children: [AutoAdjustCard(plan: p, profile: profile, onUndo: () => undone = true)])), lang),
      );
      final l = lookupAppLocalizations(Locale(lang));
      expect(find.text(l.autoAdjTitle), findsOneWidget);
      expect(find.text(l.autoAdjLongCutShort), findsOneWidget);
      expect(find.textContaining('9'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('autoAdjUndo')));
      expect(undone, isTrue);
    });
  }
}
