import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/widgets/term_info.dart';

Widget _app(Widget home, String lang) => MaterialApp(
  locale: Locale(lang),
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
  testWidgets('info button opens the explanation', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const Scaffold(body: Center(child: TermInfoButton(Term.rpe))), 'de'));
    await t.tap(find.byType(TermInfoButton));
    await t.pumpAndSettle();
    final de = lookupAppLocalizations(const Locale('de'));
    expect(find.text(de.termRpeTitle), findsOneWidget);
    expect(find.text(de.termRpeTip), findsOneWidget);
  });

  testWidgets('glossary lists every term without overflow at 360 dp', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final lang in ['de', 'en']) {
      await t.pumpWidget(_app(GlossaryPage(key: ValueKey(lang)), lang));
      await t.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(lang));
      for (final term in Term.values) {
        await t.dragUntilVisible(find.text(term.title(l)), find.byType(ListView), const Offset(0, -150));
        expect(find.text(term.title(l)), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    }
  });
}
