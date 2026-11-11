import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/widgets/duration_picker.dart';

/// The scroll-wheel duration input that replaced the typed "h:mm:ss" fields (setup race times,
/// swim test, target time, goal editor, workout correction).
void main() {
  Widget app(Widget child, {String lang = 'de', bool dark = false}) => MaterialApp(
    locale: Locale(lang),
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );

  /// A field whose value lives in a StatefulBuilder; returns the value getter.
  Future<int? Function()> pumpField(
    WidgetTester t, {
    int? value,
    int? initial,
    int? min,
    int? max,
    DurationUnits? units,
    String lang = 'de',
    bool dark = false,
    String? emptyText,
  }) async {
    int? v = value;
    await t.pumpWidget(
      app(
        StatefulBuilder(
          builder:
              (c, set) => DurationField(
                key: const ValueKey('field'),
                value: v,
                onChanged: (x) => set(() => v = x),
                label: 'Zeit',
                initial: initial,
                min: min,
                max: max,
                units: units,
                emptyText: emptyText,
              ),
        ),
        lang: lang,
        dark: dark,
      ),
    );
    return () => v;
  }

  Future<void> open(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('field')));
    await t.pumpAndSettle();
  }

  /// Scrolls a wheel by [items] rows (positive = to larger values).
  Future<void> turn(WidgetTester t, String unit, int items) async {
    await t.drag(find.byKey(ValueKey('durationWheel-$unit')), Offset(0, -44.0 * items));
    await t.pumpAndSettle();
  }

  String shown(WidgetTester t) => t.widget<Text>(find.byKey(const ValueKey('durationValue'))).data!;

  testWidgets('shows the formatted value; the sheet starts at it and "Übernehmen" takes the wheels', (t) async {
    final get = await pumpField(t, value: 2 * 3600 + 30 * 60 + 30); // 2:30:30
    expect(find.text('2:30:30'), findsOneWidget);
    await open(t);
    expect(find.byKey(const ValueKey('durationWheel-h')), findsOneWidget);
    expect(find.byKey(const ValueKey('durationWheel-min')), findsOneWidget);
    expect(find.byKey(const ValueKey('durationWheel-s')), findsOneWidget);
    expect(shown(t), '2:30:30');
    await turn(t, 'min', 2);
    await turn(t, 'h', -1);
    expect(shown(t), '1:32:30');
    await t.tap(find.text('Übernehmen'));
    await t.pumpAndSettle();
    expect(get(), 3600 + 32 * 60 + 30);
    expect(find.text('1:32:30'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('minutes + seconds only for short durations; minutes go past 59, seconds loop', (t) async {
    final get = await pumpField(t, initial: 9 * 60, min: 220, max: 1200); // 400 m swim test
    expect(find.text('–:––'), findsOneWidget, reason: 'no value yet: an empty clock');
    await open(t);
    expect(find.byKey(const ValueKey('durationWheel-h')), findsNothing);
    expect(shown(t), '9:00', reason: 'starts at the plausible default');
    await turn(t, 's', -3); // 0 → 57: the seconds wheel loops
    await turn(t, 'min', 5);
    expect(shown(t), '14:57');
    await t.tap(find.text('Übernehmen'));
    await t.pumpAndSettle();
    expect(get(), 14 * 60 + 57);
  });

  testWidgets('outside the allowed range "Übernehmen" is disabled and the range is shown', (t) async {
    final b = eventTimeBounds('10k')!;
    final get = await pumpField(t, initial: 3000, min: b.$1, max: b.$2);
    await open(t);
    await turn(t, 'min', -40); // 0:10:00 – faster than any 10 km
    expect(find.byKey(const ValueKey('durationRange')), findsOneWidget);
    final apply = t.widget<FilledButton>(find.byKey(const ValueKey('durationApply')));
    expect(apply.onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('durationApply')));
    await t.pumpAndSettle();
    expect(get(), isNull);
  });

  testWidgets('"Entfernen" clears a set value; dismissing keeps it', (t) async {
    final get = await pumpField(t, value: 1500, emptyText: 'Keine Zielzeit');
    await open(t);
    // Dismissed (tap on the barrier): unchanged.
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(get(), 1500);
    await open(t);
    await t.tap(find.byKey(const ValueKey('durationClear')));
    await t.pumpAndSettle();
    expect(get(), isNull);
    expect(find.text('Keine Zielzeit'), findsOneWidget);
    // Without a value there is nothing to remove.
    await open(t);
    expect(find.byKey(const ValueKey('durationClear')), findsNothing);
  });

  testWidgets('English and dark theme render without errors', (t) async {
    await pumpField(t, value: 4000, lang: 'en', dark: true);
    await open(t);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('wheels follow the longest plausible time', () {
    expect(DurationUnits.upTo(eventTimeBounds('5k')!.$2), DurationUnits.ms);
    expect(DurationUnits.upTo(eventTimeBounds('swim1500')!.$2), DurationUnits.ms);
    expect(DurationUnits.upTo(eventTimeBounds('hm')!.$2), DurationUnits.hms);
    expect(DurationUnits.upTo(null), DurationUnits.hms);
  });

  test('plausible race times: typos are dropped from the profile', () {
    final (lo, hi) = eventTimeBounds('10k')!;
    expect(lo, lessThan(26 * 60), reason: 'faster than the world record is impossible, but close to it is not');
    expect(hi, greaterThanOrEqualTo(2 * 3600));
    final a = AthleteData.fromMap({
      'raceTimes': {'5k': 22 * 60 + 30, '10k': 4, 'm': 3 * 3600 + 59 * 60},
      'swim400Sec': 7,
      'swim200Sec': 200,
      'eventDistance': 'hm',
      'targetTimeSec': 90,
    });
    expect(a.raceTimes, {'5k': 1350, 'm': 14340}, reason: '"4" typed for the 10 km time is not a time');
    expect(a.swim400Sec, isNull);
    expect(a.swim200Sec, 200);
    expect(a.targetTimeSec, isNull);
    expect(a.merge({'targetTimeSec': 6300}).targetTimeSec, 6300);
  });
}
