import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/features/home/weather_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/weather_service.dart';

Weather _weather() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, now.hour);
  return Weather(
    place: 'Garmisch-Partenkirchen Innenstadt Nord',
    temp: -12,
    feelsLike: -18,
    wind: 34,
    windDir: 225,
    humidity: 100,
    code: 2,
    isDay: true,
    uv: 7,
    aqi: 120,
    hours: [
      for (var i = 0; i < 48; i++)
        HourForecast(
          time: start.add(Duration(hours: i)),
          temp: -12.0 + i % 30,
          feelsLike: -18.0 + i % 30,
          code: [0, 2, 3, 61, 95][i % 5],
          rainChance: (i * 17) % 101,
          rainMm: (i % 4) * 0.5,
          wind: 10.0 + i,
          uv: (i % 9).toDouble(),
          humidity: 80,
          isDay: i % 24 < 14,
        ),
    ],
    days: [
      for (var i = 0; i < 7; i++)
        DayForecast(
          date: DateTime(now.year, now.month, now.day + i),
          code: [0, 61, 95, 3, 71, 2, 45][i],
          max: -5.0 + i * 6,
          min: -15.0 + i * 2,
          rainChance: i * 15,
          uvMax: 4,
          windMax: 30,
          sunrise: DateTime(now.year, now.month, now.day + i, 7, 12),
          sunset: DateTime(now.year, now.month, now.day + i, 16, 48),
        ),
    ],
    fetched: now,
  );
}

Future<void> _pump(WidgetTester tester, String lang, double scale, ThemeData theme) async {
  // Tall viewport so the whole (lazy) list is laid out at a narrow width.
  tester.view.physicalSize = const Size(360, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = _weather();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [weatherProvider.overrideWith((ref) async => w)],
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
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: const WeatherPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final lang in ['de', 'en']) {
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('weather page has no overflow ($lang, x$scale)', (tester) async {
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.toString());
        try {
          await _pump(tester, lang, scale, AppTheme.dark());
          expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
          // Legend opens the score explanation sheet.
          await tester.tap(find.byIcon(Icons.info_outline_rounded));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.thunderstorm_rounded), findsWidgets);
        } finally {
          FlutterError.onError = old;
        }
        expect(errors, isEmpty);
      });
    }
  }
}
