import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/features/shell/account.dart';
import 'package:strive/l10n/gen/app_localizations.dart';

/// Account deletion, typed confirmation: the red screen "_elements.contains(element)" came from the
/// text controller being disposed while the dialog was still animating out.
void main() {
  test('the confirmation word: case, blanks and a typed-out umlaut', () {
    expect(matchesConfirmWord(' löschen ', 'LÖSCHEN'), isTrue);
    expect(matchesConfirmWord('LOESCHEN', 'LÖSCHEN'), isTrue);
    expect(matchesConfirmWord('delete', 'DELETE'), isTrue);
    expect(matchesConfirmWord('LOSCHEN', 'LÖSCHEN'), isFalse);
    expect(matchesConfirmWord('', ''), isFalse);
  });

  for (final confirmFirst in [true, false]) {
    testWidgets('typed confirmation ${confirmFirst ? 'confirmed' : 'cancelled'}: no use of a disposed controller', (t) async {
      final l = lookupAppLocalizations(const Locale('de'));
      bool? result;
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder:
                (c) => TextButton(
                  onPressed: () async => result = await showDialog<bool>(context: c, builder: (_) => const TypedDeleteConfirmDialog()),
                  child: const Text('go'),
                ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('deleteAccountGo'))).onPressed, isNull);
      await t.enterText(find.byKey(const ValueKey('deleteAccountWord')), 'loeschen');
      t.view.viewInsets = const FakeViewPadding(bottom: 300); // keyboard open
      addTearDown(t.view.reset);
      await t.pump();
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('deleteAccountGo'))).onPressed, isNotNull);
      await t.tap(confirmFirst ? find.byKey(const ValueKey('deleteAccountGo')) : find.text(l.cancel));
      // The keyboard closes while the dialog fades out: the field rebuilds during the exit animation.
      await t.pump();
      t.view.viewInsets = FakeViewPadding.zero;
      await t.pump(const Duration(milliseconds: 50));
      await t.pumpAndSettle();
      expect(result, confirmFirst);
      expect(find.byType(TypedDeleteConfirmDialog), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
