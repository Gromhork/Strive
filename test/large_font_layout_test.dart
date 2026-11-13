// R7-11: at text scale 1.3 key labels were cut off – the plan-settings subtitle lost its warning
// ("… danach neuer Plan"), the Google-Calendar subtitle, the sport-level rows ("Schwimm…"), the
// quick-start tiles ("Radfahr…", "Leere Einh…") – and "Manuell eintragen" was scaled down next to
// "Übungen". Text is never clipped or shrunk there now: rows grow, tiles go one per row.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/profile/profile_page.dart';
import 'package:strive/features/train/train_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  @override
  void saveProfile(UserProfile p) {}
}

Future<void> _pump(WidgetTester t, Widget home, {required String lang, required double scale, double width = 360}) async {
  t.view.physicalSize = Size(width, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith((ref) => Stream.value(null)),
        repoProvider.overrideWithValue(_FakeRepo()),
        profileProvider.overrideWith((ref) => Stream.value(const UserProfile(name: 'Alex', onboarded: true))),
        sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
        plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
        templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
        goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
      ],
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
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: home,
      ),
    ),
  );
  await t.pumpAndSettle();
}

AppLocalizations _l(WidgetTester t) => AppLocalizations.of(t.element(find.byType(Scaffold).first));

RenderParagraph _para(WidgetTester t, Finder f) => t.renderObject<RenderParagraph>(f);

/// Shown whole: not cut off by maxLines and not squeezed by a FittedBox.
void _expectWhole(WidgetTester t, Finder f, {bool oneLine = false}) {
  expect(f, findsOneWidget);
  final p = _para(t, f);
  expect(p.didExceedMaxLines, isFalse, reason: '${p.text.toPlainText()} is cut off');
  expect(find.ancestor(of: f, matching: find.byType(FittedBox)), findsNothing, reason: '${p.text.toPlainText()} is scaled');
  if (oneLine) {
    expect(p.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(p.size.width + 0.5), reason: '${p.text.toPlainText()} wraps');
  }
}

void main() {
  for (final lang in ['de', 'en']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('profile ($lang, text ×$scale): settings subtitles and sport levels are shown whole', (t) async {
        await _pump(t, const ProfilePage(), lang: lang, scale: scale);
        expect(t.takeException(), isNull);
        final l = _l(t);
        _expectWhole(t, find.text(l.editPlanSettingsSub));
        _expectWhole(t, find.text(l.googleCalendarSub));
        for (final s in Sport.values) {
          _expectWhole(t, find.textContaining(s.label(l)).last, oneLine: true);
        }
      });

      testWidgets('train ($lang, text ×$scale): quick-start and action tiles show whole labels in one size', (t) async {
        await _pump(t, const TrainPage(), lang: lang, scale: scale);
        expect(t.takeException(), isNull);
        final l = _l(t);
        // Whole and in the normal size; with the 1-em test glyphs a label may still need a second
        // line in a full-width tile at ×1.3 (Poppins fits on one) – wrapping is fine, cutting is not.
        for (final s in Sport.values) {
          _expectWhole(t, find.text(s.label(l)));
        }
        _expectWhole(t, find.text(l.emptyWorkout));
        for (final e in t.elementList(find.text(l.quickRecord))) {
          expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse);
        }
        _expectWhole(t, find.text(l.logManually));
        _expectWhole(t, find.text(l.exercises));
        // Both action labels in the same size (one was scaled down).
        final manual = _para(t, find.text(l.logManually)), exercises = _para(t, find.text(l.exercises));
        expect(manual.text.style?.fontSize, exercises.text.style?.fontSize);
        expect(manual.textScaler, exercises.textScaler);
        // Tiles of one row share a height; a tile is never lower than the 48 dp touch row.
        expect(t.getSize(find.byKey(const ValueKey('logManuallyTile'))).height, greaterThanOrEqualTo(48));
      });
    }
  }

  testWidgets('train: two tiles per row when the labels fit, one per row when they don\'t', (t) async {
    // Wide: Gym/Laufen side by side, the action tiles too.
    await _pump(t, const TrainPage(), lang: 'de', scale: 1.0, width: 900);
    final l = _l(t);
    double y(String s) => t.getTopLeft(find.text(s)).dy;
    expect(y(Sport.run.label(l)), y(Sport.gym.label(l)));
    expect(y(l.exercises), y(l.logManually));
    final wideTile = t.getSize(find.byKey(const ValueKey('logManuallyTile')));

    // Narrow at text ×1.3: stacked, each tile the full width.
    await _pump(t, const TrainPage(), lang: 'de', scale: 1.3, width: 360);
    expect(y(Sport.run.label(l)), greaterThan(y(Sport.gym.label(l))));
    expect(y(l.exercises), greaterThan(y(l.logManually)));
    expect(t.getSize(find.byKey(const ValueKey('logManuallyTile'))).width, greaterThan(t.view.physicalSize.width - 40));
    expect(wideTile.height, 48);
  });
}
