import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/features/profile/profile_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';

final l = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('en'),
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
  testWidgets('secure guest account: save stays disabled until e-mail and password are entered', (tester) async {
    await tester.pumpWidget(
      _app(Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => linkGuestWithEmail(c), child: const Text('open'))))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    FilledButton save() => tester.widget<FilledButton>(find.byKey(const ValueKey('linkEmailSave')));
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'a@b.de');
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'password still empty');
    await tester.enterText(find.byType(TextField).last, 'secret1');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
  });
}
