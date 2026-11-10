import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/features/goals/race_search_page.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/race_search.dart';

final _today = DateTime(2026, 11, 10);
final _until = DateTime(2027, 5, 10);

List<RaceResult> _parse(String s) => parseRaces(s, today: _today, until: _until);

const _valid = '''
[
  {"name": "Frühjahrslauf", "date": "2027-03-14", "city": "München", "country": "Deutschland", "sport": "run",
   "distances": ["10 km", "Halbmarathon"], "url": "https://www.example-lauf.de/anmeldung"},
  {"name": "Herbstlauf", "date": "2026-12-05", "city": "Köln", "country": "Deutschland", "sport": "run",
   "distances": "5 km", "url": "https://herbstlauf.de"}
]''';

void main() {
  group('parseRaces', () {
    test('reads a valid array, sorted by date', () {
      final r = _parse(_valid);
      expect(r.map((e) => e.name), ['Herbstlauf', 'Frühjahrslauf']);
      expect(r.first.distances, ['5 km']);
      expect(r.last.place, 'München, Deutschland');
      expect(r.last.url.host, 'www.example-lauf.de');
      expect(r.last.date, DateTime(2027, 3, 14));
    });

    test('accepts markdown-wrapped JSON and text around it', () {
      expect(_parse('```json\n$_valid\n```'), hasLength(2));
      expect(_parse('Here are the races I found:\n$_valid\nGood luck!'), hasLength(2));
      expect(_parse('{"events": $_valid}'), hasLength(2));
    });

    test('malformed answers throw FormatException', () {
      expect(() => _parse('I could not find any races.'), throwsFormatException);
      expect(() => _parse('[{"name": "x", '), throwsFormatException);
      expect(() => _parse('{"foo": 1}'), throwsFormatException);
    });

    test('empty array is a valid empty result', () {
      expect(_parse('[]'), isEmpty);
    });

    test('drops past dates, dates after the window and invalid dates', () {
      final r = _parse('''[
        {"name": "Past", "date": "2026-10-01", "url": "https://a.de"},
        {"name": "Yesterday", "date": "2026-11-09", "url": "https://a.de"},
        {"name": "Today", "date": "2026-11-10", "url": "https://a.de"},
        {"name": "Too late", "date": "2027-08-01", "url": "https://a.de"},
        {"name": "Impossible", "date": "2027-02-30", "url": "https://a.de"},
        {"name": "No date", "url": "https://a.de"},
        {"name": "Vague", "date": "Spring 2027", "url": "https://a.de"}
      ]''');
      expect(r.map((e) => e.name), ['Today']);
    });

    test('drops items without a usable URL or name', () {
      final r = _parse('''[
        {"name": "No url", "date": "2027-01-10"},
        {"name": "Empty url", "date": "2027-01-10", "url": ""},
        {"name": "Not http", "date": "2027-01-10", "url": "ftp://race.de"},
        {"name": "Relative", "date": "2027-01-10", "url": "/race"},
        {"name": "Placeholder", "date": "2027-01-10", "url": "https://example.com/race"},
        {"name": "Google search", "date": "2027-01-10", "url": "https://www.google.com/search?q=race"},
        {"name": "Grounding redirect", "date": "2027-01-10", "url": "https://vertexaisearch.cloud.google.com/grounding-api-redirect/abc"},
        {"name": "", "date": "2027-01-10", "url": "https://ok.de"},
        "garbage",
        {"name": "Good", "date": "2027-01-10", "url": "https://race.de/2027"}
      ]''');
      expect(r.map((e) => e.name), ['Good']);
    });

    test('removes duplicates', () {
      final r = _parse('''[
        {"name": "Stadtlauf", "date": "2027-01-10", "url": "https://a.de"},
        {"name": "stadtlauf", "date": "2027-01-10", "url": "https://b.de"}
      ]''');
      expect(r, hasLength(1));
    });
  });

  group('service', () {
    test('caches per query and maps errors', () async {
      var calls = 0;
      final s = RaceSearchService((prompt) async {
        calls++;
        expect(prompt, contains('Only list events that you actually found'));
        return GroundedReply(_valid, queries: const ['laufen münchen 2027']);
      }, clock: () => _today);
      const q = RaceQuery(sport: RaceSport.run, distance: '10k', region: 'München', months: 6, lang: 'de');
      final a = await s.search(q);
      final b = await s.search(q);
      expect(calls, 1);
      expect(identical(a, b), isTrue);
      expect(s.cached(q), same(a));
      expect(s.cached(const RaceQuery(sport: RaceSport.swim)), isNull);

      final quota = RaceSearchService((_) async => throw Exception('429 RESOURCE_EXHAUSTED: quota'), clock: () => _today);
      await expectLater(
        quota.search(q),
        throwsA(isA<RaceSearchException>().having((e) => e.failure, 'failure', RaceSearchFailure.unavailable)),
      );
      final bad = RaceSearchService((_) async => const GroundedReply('Sorry, no idea.'), clock: () => _today);
      await expectLater(
        bad.search(q),
        throwsA(isA<RaceSearchException>().having((e) => e.failure, 'failure', RaceSearchFailure.badResponse)),
      );
      final net = RaceSearchService((_) async => throw Exception('SocketException'), clock: () => _today);
      await expectLater(net.search(q), throwsA(isA<RaceSearchException>().having((e) => e.failure, 'failure', RaceSearchFailure.failed)));
    });
  });

  group('distances', () {
    test('recognises app event distances', () {
      expect(matchEventDistances(['Marathon', 'Halbmarathon', '10 km', '5km'], RaceSport.run), ['5k', '10k', 'hm', 'm']);
      expect(matchEventDistances(['42,195 km'], RaceSport.run), ['m']);
      expect(matchEventDistances(['Ultramarathon 56 km', '15 km'], RaceSport.run), isEmpty);
      expect(matchEventDistances(['Olympische Distanz', 'Sprintdistanz'], RaceSport.triathlon), ['sprint', 'olympic']);
      expect(matchEventDistances(['IRONMAN 70.3'], RaceSport.triathlon), ['70.3']);
    });

    test('event distance for a selected race', () {
      RaceResult race(List<String> d) => RaceResult(name: 'x', date: _today, url: Uri.parse('https://x.de'), distances: d);
      expect(eventDistanceFor(race(['10 km', 'Halbmarathon']), RaceSport.run, 'hm'), 'hm');
      expect(eventDistanceFor(race(['10 km', 'Halbmarathon']), RaceSport.run, null), '10k');
      expect(eventDistanceFor(race(['10 km']), RaceSport.run, 'm'), '10k');
      expect(eventDistanceFor(race([]), RaceSport.run, 'm'), 'm');
      expect(eventDistanceFor(race(['Gran Fondo 120 km']), RaceSport.cycling, null), isNull);
    });
  });

  group('racePortals', () {
    test('German running calendars with prefilled laufen.de search for a city', () {
      const q = RaceQuery(sport: RaceSport.run, distance: 'hm', region: 'München', months: 6, lang: 'de');
      final links = racePortals(q, today: _today);
      final laufen = links.firstWhere((l) => l.url.host == 'www.laufen.de');
      expect(laufen.url.queryParameters, {
        'search': 'München',
        'radius': '50',
        'distance_start': '20',
        'distance_end': '22',
        'start': '2026-11-10',
        'end': '2027-05-10',
      });
      expect(links.map((l) => l.url.host), containsAll(['www.marathon.de', 'www.ahotu.com', 'worldsmarathons.com', 'www.google.com']));
      expect(links.firstWhere((l) => l.url.host == 'www.ahotu.com').url.path, '/calendar/running/half-marathon');
      final google = links.last.url.queryParameters['q']!;
      expect(google, contains('Halbmarathon'));
      expect(google, contains('München'));
    });

    test('country filter for ahotu, no German calendars abroad', () {
      const q = RaceQuery(sport: RaceSport.triathlon, distance: 'olympic', region: 'Austria', months: 12, lang: 'en');
      final links = racePortals(q, today: _today);
      expect(links.firstWhere((l) => l.url.host == 'www.ahotu.com').url.path, '/calendar/triathlon/olympic/austria');
      expect(links.any((l) => l.url.host.contains('dtu-kalender') || l.url.host.contains('laufen.de')), isFalse);
      // IRONMAN / Challenge only for middle distance or any distance.
      expect(links.any((l) => l.url.host == 'www.ironman.com'), isFalse);
    });

    test('Germany: triathlon calendars and IRONMAN for 70.3', () {
      const q = RaceQuery(sport: RaceSport.triathlon, distance: '70.3', region: 'Deutschland', lang: 'de');
      final hosts = racePortals(q, today: _today).map((l) => l.url.host).toList();
      expect(hosts, containsAll(['www.dtu-kalender.de', 'www.tri-mag.de', 'www.ironman.com', 'www.challengefamily.com']));
      expect(
        racePortals(q, today: _today).firstWhere((l) => l.url.host == 'www.ahotu.com').url.path,
        '/calendar/triathlon/middle-distance-70-3/germany',
      );
    });

    test('every sport has at least ahotu and Google', () {
      for (final s in RaceSport.values) {
        final hosts = racePortals(RaceQuery(sport: s, lang: 'en'), today: _today).map((l) => l.url.host);
        expect(hosts, containsAll(['www.ahotu.com', 'www.google.com']), reason: s.name);
      }
    });

    test('default region from locale', () {
      expect(defaultRegion('de', 'DE'), 'Deutschland');
      expect(defaultRegion('de', null), 'Deutschland');
      expect(defaultRegion('de', 'AT'), 'Österreich');
      expect(defaultRegion('en', 'US'), 'USA');
      expect(defaultRegion('en', null), '');
      expect(countrySlug(' deutschland '), 'germany');
      expect(countrySlug('Berlin'), isNull);
    });
  });

  group('page', () {
    Future<void> pump(WidgetTester tester, RaceSearchService service, String lang, double scale) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            raceSearchServiceProvider.overrideWithValue(service),
            profileOrDefaultProvider.overrideWithValue(const UserProfile()),
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
            builder:
                (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
            home: const RaceSearchPage(saveToProfile: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> scrollThrough(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
      }
    }

    String future(int days) {
      final d = DateTime.now().add(Duration(days: days));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    for (final lang in ['de', 'en']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('results without overflow at 360x640 ($lang, x$scale)', (tester) async {
          final errors = <String>[];
          final old = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.toString());
          try {
            final service = RaceSearchService(
              (_) async => GroundedReply(
                '[{"name": "Internationaler Frühjahrs-Halbmarathon mit sehr langem Namen Bad Mergentheim", "date": "${future(40)}", '
                '"city": "Bad Mergentheim-Wachbach", "country": "Deutschland", "distances": ["5 km", "10 km", "Halbmarathon", "Staffel"], '
                '"url": "https://www.sehr-lange-veranstalter-domain-fuer-tests.de/anmeldung/2027"}]',
                queries: const ['halbmarathon frühjahr 2027 deutschland termine'],
                sources: const [WebSource('sehr-lange-veranstalter-domain-fuer-tests.de', 'https://x.de')],
              ),
            );
            await pump(tester, service, lang, scale);
            final l = lang == 'de' ? lookupAppLocalizations(const Locale('de')) : lookupAppLocalizations(const Locale('en'));
            await tester.ensureVisible(find.text(l.raceSearchButton));
            expect(find.text(l.raceIntro), findsOneWidget);
            await tester.ensureVisible(find.text(l.raceSearchButton));
            await tester.tap(find.text(l.raceSearchButton));
            await tester.pump();
            await tester.pump();
            expect(find.textContaining('Bad Mergentheim'), findsWidgets);
            expect(find.text(l.raceDisclaimer), findsOneWidget);
            await scrollThrough(tester);
            expect(find.text(l.racePortals), findsOneWidget);
          } finally {
            FlutterError.onError = old;
          }
          expect(errors, isEmpty);
        });
      }
    }

    final l = lookupAppLocalizations(const Locale('de'));
    final states = {
      'unavailable': (RaceSearchService((_) async => throw Exception('429 quota exceeded')), l.raceUnavailable),
      'failed': (RaceSearchService((_) async => throw Exception('SocketException')), l.raceError),
      'empty': (RaceSearchService((_) async => const GroundedReply('[]')), l.raceEmpty),
    };
    for (final s in states.entries) {
      testWidgets('${s.key} state shows the message and the race calendars', (tester) async {
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.toString());
        try {
          await pump(tester, s.value.$1, 'de', 1.3);
          await tester.ensureVisible(find.text(l.raceSearchButton));
          await tester.tap(find.text(l.raceSearchButton));
          await tester.pump();
          await tester.pump();
          expect(find.text(s.value.$2), findsOneWidget);
          await scrollThrough(tester);
          expect(find.text('Google'), findsOneWidget);
        } finally {
          FlutterError.onError = old;
        }
        expect(errors, isEmpty);
      });
    }

    testWidgets('set as goal pops with the race', (tester) async {
      RaceSelection? picked;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = RaceSearchService(
        (_) async => GroundedReply(
          '[{"name": "Stadtmarathon", "date": "${future(60)}", "city": "Mainz", "distances": ["Marathon"], "url": "https://stadtmarathon.de"}]',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            raceSearchServiceProvider.overrideWithValue(service),
            profileOrDefaultProvider.overrideWithValue(const UserProfile()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async => picked = await openRaceSearch(context, saveToProfile: false),
                      child: const Text('open'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.ensureVisible(find.text(l.raceSearchButton));
      await tester.tap(find.text(l.raceSearchButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.raceSetAsGoal));
      await tester.tap(find.text(l.raceSetAsGoal));
      await tester.pumpAndSettle();
      expect(picked?.name, 'Stadtmarathon');
      expect(picked?.distance, 'm');
      expect(picked?.sport, RaceSport.run);
    });
  });
}
