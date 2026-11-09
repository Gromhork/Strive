import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_generator.dart';

void main() {
  Widget app(Widget child, Locale locale) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 320, child: child)),
  );

  final start = DateTime(2026, 11, 9);
  final runWalk5k = UserProfile(
    level: 'beginner',
    focus: TrainingFocus.run,
    trainingDays: const [2, 4, 6],
    athlete: AthleteData(eventDistance: '5k', eventDate: start.add(const Duration(days: 8 * 7 + 6))),
  );

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('shows reason and options (${locale.languageCode}), nothing when the goal is fine', (tester) async {
      final l = lookupAppLocalizations(locale);
      final f = PlanGenerator.feasibility(runWalk5k, start: start, l: l);
      await tester.pumpWidget(app(FeasibilityCard(f, planAnyway: true), locale));
      expect(find.text(l.feasTitle), findsOneWidget);
      expect(find.text(l.feasRunWalk), findsOneWidget);
      expect(find.text('• ${l.feasRunWalkFinish}'), findsOneWidget);
      expect(find.textContaining(l.feasLaterDate('').trim().split(' ').first), findsWidgets);
      expect(find.text(l.feasPlanAnyway), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(const FeasibilityCard(PlanFeasibility()), locale));
      expect(find.text(l.feasTitle), findsNothing);
    });
  }

  test('cache: one check per profile and start', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final cache = FeasibilityCache();
    final a = cache.of(runWalk5k, start, l);
    expect(identical(cache.of(runWalk5k, start, l), a), isTrue);
    final later = runWalk5k.copyWith(athlete: runWalk5k.athlete.merge({'eventDate': start.add(const Duration(days: 16 * 7))}));
    expect(cache.of(later, start, l).ok, isTrue);
  });
}
