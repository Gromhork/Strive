import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/profile/profile_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/widgets/settings.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  @override
  void saveProfile(UserProfile p) {}
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Widget _app(Widget home, {required SharedPreferences prefs, String lang = 'de', bool dark = true, double scale = 1}) => ProviderScope(
  overrides: [
    prefsProvider.overrideWithValue(prefs),
    authProvider.overrideWith((ref) => Stream.value(null)),
    repoProvider.overrideWithValue(_FakeRepo()),
    profileProvider.overrideWith((ref) => Stream.value(const UserProfile(name: 'Alexandra-Charlotte Mustermann'))),
    sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
    plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
    templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
    goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
  ],
  child: MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
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

void _narrow(WidgetTester tester, {double height = 3200, double width = 320}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('profile settings', () {
    for (final lang in ['de', 'en']) {
      for (final dark in [true, false]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('no overflow at 320 dp ($lang, ${dark ? 'dark' : 'light'}, text ×$scale)', (tester) async {
            _narrow(tester);
            final prefs = await _prefs({'trainingReminder': true, 'reminderHour': 7, 'reminderMinute': 30});
            await tester.pumpWidget(_app(const ProfilePage(), prefs: prefs, lang: lang, dark: dark, scale: scale));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byKey(const ValueKey('logRirSetting')), findsOneWidget);
            expect(find.byKey(const ValueKey('reminderTimeSetting')), findsOneWidget);
            // Lazily built list: the last row may sit below the fold at large text sizes.
            await tester.scrollUntilVisible(find.byKey(const ValueKey('deleteAccount')), 300, scrollable: find.byType(Scrollable).first);
            expect(tester.takeException(), isNull);
            expect(find.byKey(const ValueKey('deleteAccount')), findsOneWidget);
          });
        }
      }
    }

    testWidgets('rows share one height; the RIR row is no taller than the others; every row has an icon', (tester) async {
      // The test font draws every glyph 1 em wide (Poppins ≈ 0.55 em), so 800 dp here is about a phone's 400 dp;
      // the 320 dp case is covered by the overflow tests.
      _narrow(tester, width: 800);
      final prefs = await _prefs({'trainingReminder': true});
      await tester.pumpWidget(_app(const ProfilePage(), prefs: prefs));
      await tester.pumpAndSettle();
      final rir = tester.getSize(find.byKey(const ValueKey('logRirSetting'))).height;
      final vib = tester.getSize(find.byKey(const ValueKey('vibrationSetting'))).height;
      final time = tester.getSize(find.byKey(const ValueKey('reminderTimeSetting'))).height;
      // One-line subtitle → same height as the vibration row (was ~3× taller with the long text).
      expect(rir, vib);
      expect(rir, lessThanOrEqualTo(72));
      expect(time, greaterThanOrEqualTo(60));
      // The time row has its icon like every other row.
      expect(
        find.descendant(of: find.byKey(const ValueKey('reminderTimeSetting')), matching: find.byIcon(Icons.schedule_rounded)),
        findsOneWidget,
      );
      for (final tile in tester.widgetList<SettingsTile>(find.byType(SettingsTile))) {
        expect(tile.icon, isNotNull);
      }
    });

    testWidgets('the reminder time is shown in the title size and the local format (7:30 → 07:30)', (tester) async {
      _narrow(tester);
      final prefs = await _prefs({'trainingReminder': true, 'reminderHour': 7, 'reminderMinute': 30});
      await tester.pumpWidget(_app(const ProfilePage(), prefs: prefs));
      await tester.pumpAndSettle();
      final value = tester.widget<Text>(
        find.descendant(of: find.byKey(const ValueKey('reminderTimeSetting')), matching: find.text('07:30')),
      );
      final title = tester.widget<Text>(find.text('Uhrzeit'));
      expect(value.style!.fontSize, title.style!.fontSize);
      expect(value.style!.fontSize, 15);
      // The switch row does not repeat the time while the time row is shown.
      expect(find.text('An geplanten Trainingstagen'), findsOneWidget);
    });

    testWidgets('the ⓘ of the RIR row opens the long explanation', (tester) async {
      _narrow(tester);
      await tester.pumpWidget(_app(const ProfilePage(), prefs: await _prefs({})));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reps in Reserve'), findsNothing);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('logRirSetting')), matching: find.byIcon(Icons.info_outline_rounded)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reps in Reserve, RIR'), findsOneWidget);
      // Tapping the row itself still toggles the setting.
      Navigator.of(tester.element(find.textContaining('Reps in Reserve, RIR'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('logRirSetting')));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(ProfilePage));
      expect(ProviderScope.containerOf(ctx).read(settingsProvider).logRir, isTrue);
    });

    testWidgets('language and theme rows show the value and pick from a sheet', (tester) async {
      _narrow(tester);
      await tester.pumpWidget(_app(const ProfilePage(), prefs: await _prefs({})));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('themeSetting')), matching: find.text('Dunkel')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('themeSetting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hell'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(ProfilePage));
      expect(ProviderScope.containerOf(ctx).read(settingsProvider).themeMode, ThemeMode.light);
    });
  });

  group('settings rows', () {
    testWidgets('long titles, subtitles and values stay inside 320 dp at text ×1.3', (tester) async {
      _narrow(tester, height: 900);
      final prefs = await _prefs({});
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              SettingsSection(
                title: 'Ein sehr langer Abschnittstitel, der nicht in eine Zeile passt',
                children: [
                  const SettingsTile(
                    icon: Icons.schedule_rounded,
                    title: 'Eine ausgesprochen lange Einstellungsbezeichnung mit vielen Wörtern',
                    subtitle:
                        'Ein langer Untertitel, der mehrere Zeilen bräuchte, aber auf zwei Zeilen gekürzt wird, damit die Zeile nicht zu hoch wird.',
                    value: 'Ein sehr langer Wert',
                    info: 'Erklärung',
                  ),
                  SettingsSwitchTile(
                    icon: Icons.vibration_rounded,
                    title: 'Eine ausgesprochen lange Einstellungsbezeichnung mit vielen Wörtern',
                    subtitle: 'Ein langer Untertitel, der mehrere Zeilen bräuchte, aber auf zwei Zeilen gekürzt wird.',
                    info: 'Erklärung',
                    value: true,
                    onChanged: (_) {},
                  ),
                  SettingsTile(icon: Icons.logout_rounded, title: 'Abmelden', danger: true, onTap: () {}),
                ],
              ),
            ],
          ),
          prefs: prefs,
          scale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Subtitles are never cut off (R7-11: at text ×1.3 the plan-settings warning "… danach neuer
      // Plan" was lost to a two-line cap) – the row grows instead.
      final sub = find.textContaining('Ein langer Untertitel, der mehrere Zeilen bräuchte, aber auf zwei Zeilen gekürzt wird, damit');
      expect(tester.widget<Text>(sub).maxLines, isNull);
      expect(tester.renderObject<RenderParagraph>(sub).didExceedMaxLines, isFalse);
    });
  });
}
