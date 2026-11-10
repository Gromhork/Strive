import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/goals/goals_page.dart' show eventKeyForKm;
import 'package:strive/features/goals/race_search_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/race_search.dart';
import 'package:strive/widgets/event_distance_picker.dart';

final _today = DateTime(2026, 11, 10);

String _fixture(String name) => File('test/fixtures/race_search/$name').readAsStringSync();
List<int> _fixtureBytes(String name) => File('test/fixtures/race_search/$name').readAsBytesSync();

/// Calendar that returns fixed races (widget tests).
class _FakeSource extends RaceSource {
  const _FakeSource(this.races, {this.fail = false, this.label = 'Fake-Kalender'});
  final List<RaceResult> races;
  final bool fail;
  final String label;
  @override
  String get name => label;
  @override
  bool supports(RaceQuery q, RaceRegion r) => true;
  @override
  Future<List<RaceResult>> fetch(RaceQuery q, RaceRegion r, DateTime today, RaceHttp http) async {
    if (fail) throw const RaceSourceException('offline');
    return races;
  }
}

/// Offline client: geocoder answers "Berlin", everything else 404.
final _offline = MockClient((req) async {
  if (req.url.host == 'geocoding-api.open-meteo.com') return http.Response(_fixture('geocode_berlin.json'), 200);
  return http.Response('', 404);
});

void main() {
  group('laufen.de parser', () {
    final json = jsonDecode(_fixture('laufen_search.json')) as Map;

    test('reads name, date, place, link and distance range', () {
      final r = parseLaufenDe(json);
      expect(r, hasLength(7));
      final silvester = r.firstWhere((e) => e.name == 'Berliner Silvesterlauf');
      expect(silvester.date, DateTime(2026, 12, 31));
      expect(silvester.city, 'Berlin-Charlottenburg');
      expect(silvester.countryCode, 'DE');
      expect(silvester.url.toString(), 'https://www.laufen.de/laufkalender/details/berlinersilvesterlauf');
      expect(silvester.source, 'laufen.de');
      expect(silvester.distances.single, contains('–'));
      expect(silvester.distanceKeys, isEmpty);
    });

    test('a searched distance inside the range is assumed', () {
      final r = parseLaufenDe(json, distance: 'hm');
      final hm = r.where((e) => e.distanceKeys.contains('hm')).map((e) => e.name).toList();
      expect(hm, ['20. WSD Teltowkanal Halbmarathon 2026', '47. Berliner Mannschaftslauf - einzeln oder als Team']);
    });

    test('certified distance codes and single distances map to the catalogue', () {
      final r = parseLaufenDe({
        'events':
            '<a href="laufkalender/details/x" class="teaser event"><div class="date">7.3.2027</div>'
            '<div class="headline noline">Stadtlauf</div><div class="location">80331 München</div>'
            '<div class="info wettbewerbe">Strecken: 5 bis 42,195 Kilometer</div>'
            '<div class="codes"><div class="code">10 km</div><div class="code">HM</div><div class="code">M</div></div></a>'
            '<a href="laufkalender/details/y" class="teaser event"><div class="date">8.3.2027</div>'
            '<div class="headline noline">Winterlauf</div><div class="location">Köln</div>'
            '<div class="info wettbewerbe">Strecke: 5 Kilometer</div></a>'
            '<a href="laufkalender/details/z" class="teaser event"><div class="date">kein Datum</div>'
            '<div class="headline noline">Ohne Datum</div></a>',
      });
      expect(r, hasLength(2));
      expect(r.first.distanceKeys, ['10k', 'hm', 'm']);
      expect(r.first.city, 'München');
      expect(r.last.distanceKeys, ['5k']);
      expect(r.last.city, 'Köln');
    });
  });

  group('DTU parser', () {
    final body = decodeBody(_fixtureBytes('dtu_list.html'));

    test('reads the result table (Latin-1 page)', () {
      final r = parseDtuList(body, sport: EventSport.triathlon);
      expect(r, hasLength(6));
      final kraichgau = r.firstWhere((e) => e.name == 'IRONMAN 70.3 Kraichgau');
      expect(kraichgau.city, 'Bad Schönborn');
      expect(kraichgau.region, 'Baden-Württemberg');
      expect(kraichgau.date, DateTime(2027, 5, 22));
      expect(kraichgau.endDate, DateTime(2027, 5, 23));
      expect(kraichgau.distanceKeys, ['70.3']);
      expect(kraichgau.url.host, 'www.dtu-kalender.de');
      expect(r.firstWhere((e) => e.name == '5150 Kraichgau').distanceKeys, ['olympic']);
    });

    test('the filtered distance is assumed for every race', () {
      final r = parseDtuList(body, sport: EventSport.triathlon, distance: 'sprint');
      expect(r.every((e) => e.distanceKeys.contains('sprint')), isTrue);
    });

    test('state ids and cookies', () {
      expect(DtuSource.stateId('Land Berlin'), '3');
      expect(DtuSource.stateId('Sachsen-Anhalt'), '14');
      expect(DtuSource.stateId('Sachsen'), '13');
      expect(DtuSource.stateId(null), '');
      final jar = <String, String>{};
      readCookies(
        'XSRF-TOKEN=abc%3D; expires=Tue, 10-Nov-2026 13:00:00 GMT; Max-Age=7200; path=/, dtu_kalender_session=xyz; path=/; httponly',
        jar,
      );
      expect(jar, {'XSRF-TOKEN': 'abc%3D', 'dtu_kalender_session': 'xyz'});
    });
  });

  group('RunSignup parser', () {
    test('reads races with US dates and mile distances', () {
      final r = parseRunSignup(jsonDecode(_fixture('runsignup_races.json')) as Map, sport: EventSport.run);
      expect(r, hasLength(4));
      expect(r.first.date, DateTime(2026, 11, 14));
      expect(r.first.city, 'New York City');
      expect(r.first.place, 'New York City, NY, US');
      expect(r.first.distanceKeys, ['5k', '10k', 'hm']);
      expect(r.first.distances, ['1 Miles']);
      expect(r.first.source, 'RunSignup');
    });

    test('skips drafts, private races and races without a date', () {
      final r = parseRunSignup({
        'races': [
          {
            'race': {'name': 'Draft', 'next_date': '05/01/2027', 'url': 'https://runsignup.com/a', 'is_draft_race': 'T'},
          },
          {
            'race': {'name': 'Private', 'next_date': '05/01/2027', 'url': 'https://runsignup.com/b', 'is_private_race': 'T'},
          },
          {
            'race': {'name': 'No date', 'next_date': null, 'url': 'https://runsignup.com/c'},
          },
          {
            'race': {'name': 'Bad date', 'next_date': '02/30/2027', 'url': 'https://runsignup.com/d'},
          },
          {
            'race': {'name': 'Ok', 'next_date': '05/01/2027', 'url': 'https://runsignup.com/e'},
          },
        ],
      }, sport: EventSport.run);
      expect(r.map((e) => e.name), ['Ok']);
    });
  });

  group('distances', () {
    test('recognises catalogue distances', () {
      expect(matchEventDistances(['Marathon', 'Halbmarathon', '10 km', '5km'], EventSport.run), ['5k', '10k', 'hm', 'm']);
      expect(matchEventDistances(['42,195 km'], EventSport.run), ['m']);
      expect(matchEventDistances(['26.2 Miles', '6.2 Miles', '50K'], EventSport.run), ['10k', 'm', 'ultra50']);
      expect(matchEventDistances(['Ultramarathon 56 km', '15 km'], EventSport.run), isEmpty);
      expect(matchEventDistances(['Olympische Distanz', 'Sprintdistanz'], EventSport.triathlon), ['sprint', 'olympic']);
      expect(matchEventDistances(['IRONMAN 70.3'], EventSport.triathlon), ['70.3']);
      expect(matchEventDistances(['IRONMAN Frankfurt'], EventSport.triathlon), ['ironman']);
      expect(matchEventDistances(['O-See-Triathlon (MD, OD, SD, Aquabike)'], EventSport.triathlon), ['sprint', 'olympic', '70.3']);
      expect(matchEventDistances(['Duathlon Sprint'], EventSport.duathlon), ['du_sprint']);
      expect(matchEventDistances(['100 km', '160 km'], EventSport.ride), ['ride100', 'ride160']);
      expect(matchEventDistances(['1500 m', '3.8 km'], EventSport.swim), ['swim1500', 'swim3800']);
    });

    test('event distance for a selected race', () {
      RaceResult race(List<String> keys) =>
          RaceResult(name: 'x', date: _today, url: Uri.parse('https://x.de'), source: 's', distanceKeys: keys);
      expect(eventDistanceFor(race(['10k', 'hm']), EventSport.run, 'hm'), 'hm');
      expect(eventDistanceFor(race(['10k', 'hm']), EventSport.run, null), '10k');
      expect(eventDistanceFor(race(['10k']), EventSport.run, 'm'), '10k');
      expect(eventDistanceFor(race([]), EventSport.run, 'm'), 'm');
      expect(eventDistanceFor(race([]), EventSport.ride, null), isNull);
      // A distance of another sport is not taken over.
      expect(eventDistanceFor(race([]), EventSport.run, 'olympic'), isNull);
    });

    test('event key for km uses the catalogue, sport and preference', () {
      expect(eventKeyForKm(226), 'ironman');
      expect(eventKeyForKm(21.1), 'hm');
      expect(eventKeyForKm(5), '5k');
      expect(eventKeyForKm(5, sport: EventSport.swim), 'swim5000');
      expect(eventKeyForKm(5, prefer: 'swim5000'), 'swim5000');
      expect(eventKeyForKm(100), 'ride100');
      expect(eventKeyForKm(37), isNull);
      expect(eventKeyForKm(0), isNull);
    });

    test('German dates', () {
      expect(parseGermanDate('1.1.2027'), DateTime(2027, 1, 1));
      expect(parseGermanDate('31.12.2026'), DateTime(2026, 12, 31));
      expect(parseGermanDate('30.2.2027'), isNull);
      expect(parseGermanDate('bald'), isNull);
    });
  });

  group('merge', () {
    RaceResult r(String name, DateTime d, {List<String> keys = const [], List<String> raw = const []}) =>
        RaceResult(name: name, date: d, url: Uri.parse('https://x.de'), source: 's', distanceKeys: keys, distances: raw);

    test('window, duplicates, sort and distance filter', () {
      final out = mergeRaces(
        [
          r('Spät', DateTime(2027, 3, 1)),
          r('Früh', DateTime(2026, 11, 20)),
          r('Vorbei', DateTime(2026, 11, 9)),
          r('Zu spät', DateTime(2027, 6, 1)),
          r('56. Stadtlauf', DateTime(2027, 1, 10)),
          r('Stadtlauf', DateTime(2027, 1, 10)),
          r('Nur 10 km', DateTime(2027, 1, 11), keys: ['10k']),
          r('HM', DateTime(2027, 1, 12), keys: ['hm']),
        ],
        today: _today,
        until: DateTime(2027, 5, 10),
        distance: 'hm',
      );
      expect(out.map((e) => e.name), ['Früh', '56. Stadtlauf', 'HM', 'Spät']);
    });
  });

  group('service', () {
    test('Berlin running search: geocoder, laufen.de request, cache', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        expect(req.headers['User-Agent'], 'Strive app');
        return switch (req.url.host) {
          'geocoding-api.open-meteo.com' => http.Response(_fixture('geocode_berlin.json'), 200),
          'www.laufen.de' => http.Response(_fixture('laufen_search.json'), 200),
          _ => http.Response('nope', 500),
        };
      });
      final s = RaceSearchService(client: client, clock: () => _today, minInterval: Duration.zero);
      const q = RaceQuery(sport: EventSport.run, distance: 'hm', region: 'Berlin', radiusKm: 25, months: 6, lang: 'de');
      final a = await s.search(q);
      expect(a.sources, ['laufen.de (DLV-Laufkalender)']);
      expect(a.failed, isEmpty);
      expect(a.races, isNotEmpty);
      expect(a.races.first.date.isBefore(a.races.last.date) || a.races.first.date == a.races.last.date, isTrue);
      final post = requests.firstWhere((r) => r.url.host == 'www.laufen.de');
      expect(post.method, 'POST');
      expect(post.headers['X-Requested-With'], 'XMLHttpRequest');
      // The geocoded postcode, not the city name (laufen.de resolves names slowly).
      expect(post.bodyFields, containsPair('search', '10967'));
      expect(post.bodyFields, containsPair('radius', '25'));
      expect(post.bodyFields, containsPair('start', '2026-11-10'));
      expect(post.bodyFields, containsPair('end', '2027-05-10'));
      expect(post.bodyFields, containsPair('distance_start', '20'));
      expect(post.bodyFields, containsPair('distance_end', '23'));
      final n = requests.length;
      expect(identical(await s.search(q), a), isTrue);
      expect(requests.length, n);
      expect(s.cached(q), same(a));
    });

    test('triathlon search: DTU form token, session cookie and list', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        if (req.url.host != DtuSource.host) return http.Response('', 404);
        if (req.url.path == '/event/sport/search' && req.method == 'GET') {
          return http.Response(_fixture('dtu_search.html'), 200, headers: {'set-cookie': 'dtu_kalender_session=s1; path=/'});
        }
        if (req.method == 'POST') {
          expect(req.headers['Cookie'], 'dtu_kalender_session=s1');
          return http.Response('', 302, headers: {'set-cookie': 'dtu_kalender_session=s2; path=/', 'location': '/event/sport/list'});
        }
        expect(req.headers['Cookie'], 'dtu_kalender_session=s2');
        return http.Response.bytes(_fixtureBytes('dtu_list.html'), 200, headers: {'content-type': 'text/html; charset=UTF-8'});
      });
      final s = RaceSearchService(client: client, clock: () => _today, minInterval: Duration.zero, sources: const [DtuSource(maxPages: 2)]);
      final r = await s.search(const RaceQuery(sport: EventSport.triathlon, distance: '70.3', region: 'Deutschland', months: 12));
      final post = requests.firstWhere((r) => r.method == 'POST');
      expect(post.bodyFields['_token'], isNotEmpty);
      expect(post.bodyFields['sport_id'], '1');
      expect(post.bodyFields['distance_id'], '5');
      expect(post.bodyFields['target_id'], '3');
      expect(post.bodyFields['start_date'], '10.11.2026');
      expect(post.bodyFields['end_date'], '10.11.2027');
      // Page 2 is linked in the fixture, page 3 is beyond maxPages.
      expect(requests.where((r) => r.url.path == '/event/sport/list').map((r) => r.url.queryParameters['page']), [null, '2']);
      expect(r.races.map((e) => e.name), contains('IRONMAN 70.3 Kraichgau'));
      expect(r.sources, ['DTU-Kalender (Triathlon Deutschland)']);
    });

    test('USA uses RunSignup with zip code and radius', () async {
      Uri? url;
      final client = MockClient((req) async {
        if (req.url.host == 'geocoding-api.open-meteo.com') {
          return http.Response('{"results":[{"name":"New York","country_code":"US","postcodes":["10001"],"admin1":"New York"}]}', 200);
        }
        url = req.url;
        return http.Response.bytes(_fixtureBytes('runsignup_races.json'), 200);
      });
      final s = RaceSearchService(client: client, clock: () => _today, minInterval: Duration.zero);
      final r = await s.search(const RaceQuery(sport: EventSport.run, distance: 'hm', region: 'New York', radiusKm: 50));
      expect(r.sources, ['RunSignup']);
      expect(url!.host, 'runsignup.com');
      expect(url!.queryParameters, containsPair('zipcode', '10001'));
      expect(url!.queryParameters, containsPair('radius', '31'));
      expect(url!.queryParameters, containsPair('event_type', 'running_race'));
      expect(url!.queryParameters['min_distance'], '20.46');
      expect(r.races, hasLength(4));
    });

    test('no calendar for the region, partial and total failures', () async {
      final none = RaceSearchService(client: _offline, clock: () => _today, minInterval: Duration.zero);
      final r = await none.search(const RaceQuery(sport: EventSport.run, region: 'Österreich'));
      expect(r.noSource, isTrue);
      expect(r.races, isEmpty);

      final race = RaceResult(name: 'Lauf', date: DateTime(2027, 1, 1), url: Uri.parse('https://a.de'), source: 'A');
      final partial = RaceSearchService(
        client: _offline,
        clock: () => _today,
        minInterval: Duration.zero,
        sources: [
          _FakeSource([race], label: 'A'),
          const _FakeSource([], fail: true, label: 'B'),
        ],
      );
      const q = RaceQuery(sport: EventSport.run);
      final p = await partial.search(q);
      expect(p.races, hasLength(1));
      expect(p.sources, ['A']);
      expect(p.failed, ['B']);
      // Partial results are not cached.
      expect(partial.cached(q), isNull);

      final all = RaceSearchService(client: _offline, clock: () => _today, minInterval: Duration.zero);
      await expectLater(
        all.search(const RaceQuery(sport: EventSport.run, region: 'Berlin')),
        throwsA(isA<RaceSearchException>().having((e) => e.failure, 'failure', RaceSearchFailure.failed)),
      );
    });

    test('regions', () async {
      final h = RaceHttp(_offline, minInterval: Duration.zero);
      expect((await resolveRegion('', 'de', h)).anywhere, isTrue);
      expect((await resolveRegion(' Deutschland ', 'de', h)).countryCode, 'DE');
      expect((await resolveRegion('usa', 'en', h)).countryCode, 'US');
      final berlin = await resolveRegion('Berlin', 'de', h);
      expect(berlin.countryCode, 'DE');
      expect(berlin.place, 'Berlin');
      expect(berlin.postcode, '10967');
      expect(berlin.admin1, 'Land Berlin');
      final failing = RaceHttp(MockClient((_) async => http.Response('', 500)), minInterval: Duration.zero);
      final plz = await resolveRegion('80331', 'de', failing);
      expect(plz.countryCode, isNull);
      expect(plz.postcode, '80331');
      expect(plz.germanyOrUnknown, isTrue);
    });
  });

  group('racePortals', () {
    test('German running calendars with prefilled laufen.de search for a city', () {
      const q = RaceQuery(sport: EventSport.run, distance: 'hm', region: 'München', months: 6, lang: 'de');
      final links = racePortals(q, today: _today);
      final laufen = links.firstWhere((l) => l.url.host == 'www.laufen.de');
      expect(laufen.url.queryParameters, {
        'search': 'München',
        'radius': '50',
        'distance_start': '20',
        'distance_end': '23',
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
      const q = RaceQuery(sport: EventSport.triathlon, distance: 'olympic', region: 'Austria', months: 12, lang: 'en');
      final links = racePortals(q, today: _today);
      expect(links.firstWhere((l) => l.url.host == 'www.ahotu.com').url.path, '/calendar/triathlon/olympic/austria');
      expect(links.any((l) => l.url.host.contains('dtu-kalender') || l.url.host.contains('laufen.de')), isFalse);
      expect(links.any((l) => l.url.host == 'www.ironman.com'), isFalse);
    });

    test('Germany: triathlon calendars and IRONMAN for long distances', () {
      const q = RaceQuery(sport: EventSport.triathlon, distance: 'ironman', region: 'Deutschland', lang: 'de');
      final hosts = racePortals(q, today: _today).map((l) => l.url.host).toList();
      expect(hosts, containsAll(['www.dtu-kalender.de', 'www.tri-mag.de', 'www.ironman.com', 'www.challengefamily.com']));
      expect(racePortals(q, today: _today).last.url.queryParameters['q'], contains('Langdistanz'));
    });

    test('every sport has at least ahotu and Google', () {
      for (final s in EventSport.values) {
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
      expect(countryCodeOf('Schweiz'), 'CH');
    });
  });

  group('page', () {
    Widget app(RaceSearchService service, String lang, double scale, Widget home) => ProviderScope(
      overrides: [raceSearchServiceProvider.overrideWithValue(service), profileOrDefaultProvider.overrideWithValue(const UserProfile())],
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
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: home,
      ),
    );

    Future<void> pump(WidgetTester tester, RaceSearchService service, String lang, double scale, {Widget? home}) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(service, lang, scale, home ?? const RaceSearchPage(saveToProfile: false)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> scrollThrough(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pump();
      }
    }

    RaceSearchService service(List<RaceSource> sources) =>
        RaceSearchService(client: _offline, sources: sources, minInterval: Duration.zero);

    final longRace = RaceResult(
      name: 'Internationaler Frühjahrs-Halbmarathon mit sehr langem Namen Bad Mergentheim',
      date: DateTime.now().add(const Duration(days: 40)),
      endDate: DateTime.now().add(const Duration(days: 41)),
      url: Uri.parse('https://www.laufen.de/laufkalender/details/sehr-langer-name'),
      source: 'laufen.de',
      city: 'Bad Mergentheim-Wachbach',
      region: 'Baden-Württemberg',
      countryCode: 'DE',
      distanceKeys: const ['5k', '10k', 'hm'],
      distances: const ['0,4–21,098 km'],
    );

    for (final lang in ['de', 'en']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('results without overflow at 360x640 ($lang, x$scale)', (tester) async {
          final errors = <String>[];
          final old = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.toString());
          try {
            await pump(
              tester,
              service([
                _FakeSource([longRace], label: 'laufen.de (DLV-Laufkalender)'),
              ]),
              lang,
              scale,
            );
            final l = lookupAppLocalizations(Locale(lang));
            expect(find.text(l.raceIntro), findsOneWidget);
            await tester.ensureVisible(find.text(l.raceSearchButton));
            await tester.tap(find.text(l.raceSearchButton));
            await tester.pump();
            await tester.pump();
            expect(find.textContaining('Bad Mergentheim'), findsWidgets);
            expect(find.text(l.raceResultsCount(1)), findsOneWidget);
            expect(find.text(l.raceSourceOf('laufen.de')), findsOneWidget);
            expect(find.text(l.raceDisclaimer), findsOneWidget);
            await scrollThrough(tester);
            expect(find.text(l.raceDataFrom('laufen.de (DLV-Laufkalender)')), findsOneWidget);
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
      'failed': (service([const _FakeSource([], fail: true)]), l.raceError),
      'empty': (service([const _FakeSource([])]), l.raceEmpty),
      'no source': (service(const []), l.raceNoSource),
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

    testWidgets('partial failure names the unreachable calendar', (tester) async {
      await pump(
        tester,
        service([
          _FakeSource([longRace], label: 'A'),
          const _FakeSource([], fail: true, label: 'DTU-Kalender'),
        ]),
        'de',
        1,
      );
      await tester.ensureVisible(find.text(l.raceSearchButton));
      await tester.tap(find.text(l.raceSearchButton));
      await tester.pump();
      await tester.pump();
      expect(find.text(l.raceSourcesFailed('DTU-Kalender')), findsOneWidget);
      expect(find.textContaining('Bad Mergentheim'), findsWidgets);
    });

    testWidgets('prefilled with the goal: sport and a non-primary distance', (tester) async {
      await pump(tester, service(const []), 'de', 1, home: const RaceSearchPage(saveToProfile: false, distance: 'ironman'));
      final chip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('distance-ironman')));
      expect(chip.selected, isTrue);
      final tri = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, l.focusTriathlon));
      expect(tri.selected, isTrue);
    });

    testWidgets('set as goal pops with the race', (tester) async {
      RaceSelection? picked;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final race = RaceResult(
        name: 'Stadtmarathon',
        date: DateTime.now().add(const Duration(days: 60)),
        url: Uri.parse('https://stadtmarathon.de'),
        source: 'Fake',
        city: 'Mainz',
        distanceKeys: const ['m'],
      );
      await tester.pumpWidget(
        app(
          service([
            _FakeSource([race]),
          ]),
          'en',
          1,
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async => picked = await openRaceSearch(context, saveToProfile: false, sport: EventSport.run),
                    child: const Text('open'),
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
      expect(picked?.sport, EventSport.run);
    });
  });

  group('distance chips', () {
    for (final lang in ['de', 'en']) {
      testWidgets('primary chips, "more" sheet grouped by sport, non-primary pick shown ($lang)', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.toString());
        String? value;
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark(),
              locale: Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: StatefulBuilder(
                  builder:
                      (context, setState) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: EventDistanceChips(
                          sports: const [EventSport.run],
                          selected: value,
                          onChanged: (k) => setState(() => value = k),
                        ),
                      ),
                ),
              ),
            ),
          );
          final l = lookupAppLocalizations(Locale(lang));
          for (final k in ['5k', '10k', 'hm', 'm']) {
            expect(find.byKey(ValueKey('distance-$k')), findsOneWidget);
          }
          expect(find.byKey(const ValueKey('distance-ultra50')), findsNothing);
          expect(find.byKey(const ValueKey('distance-sprint')), findsNothing);
          await tester.tap(find.text(l.moreDistances));
          await tester.pumpAndSettle();
          final sheet = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
          // Every distance of every sport is in the sheet (lazily built: scroll through it).
          for (final d in eventDistances) {
            await tester.scrollUntilVisible(find.byKey(ValueKey('sheet-${d.key}')), 120, scrollable: sheet);
          }
          expect(find.text(l.openWater), findsOneWidget);
          await tester.scrollUntilVisible(find.text(l.focusDuathlon), -120, scrollable: sheet);
          await tester.scrollUntilVisible(find.byKey(const ValueKey('sheet-ironman')), -120, scrollable: sheet);
          // Units.decimalComma is set by the app shell; off in this test.
          expect(find.text('3.8 / 180 / 42.2 km'), findsOneWidget);
          await tester.ensureVisible(find.byKey(const ValueKey('sheet-ironman')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('sheet-ironman')));
          await tester.pumpAndSettle();
          expect(value, 'ironman');
          final chip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('distance-ironman')));
          expect(chip.selected, isTrue);
          // Tapping the selected chip clears it.
          await tester.tap(find.byKey(const ValueKey('distance-ironman')));
          await tester.pump();
          expect(value, isNull);
        } finally {
          FlutterError.onError = old;
        }
        expect(errors, isEmpty);
      });
    }
  });
}
