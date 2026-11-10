import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../core/event_distances.dart';
import '../core/format.dart';

/// Race / competition search without AI.
///
/// There is no free, global race API, so the search asks public race calendars directly –
/// the same requests their own websites make – and combines the results:
/// * [LaufenDeSource] – DLV-Laufkalender on laufen.de (running, Germany, city + radius),
/// * [DtuSource] – DTU-Kalender of Triathlon Deutschland (triathlon / duathlon, Germany,
///   postcode + radius or federal state),
/// * [RunSignupSource] – the public RunSignup REST API (all sports, USA).
///
/// Only pages that robots.txt allows and that need no login are used; every request carries
/// the "Strive app" user agent, requests to one host are spaced ([RaceHttp]) and results are
/// cached per query. Free-text regions are resolved with the Open-Meteo geocoding API
/// ([resolveRegion]). For other countries and sports the curated calendar links
/// ([racePortals]) remain the fallback.

const raceUserAgent = 'Strive app';

/// Filters of a race search.
class RaceQuery {
  const RaceQuery({required this.sport, this.distance, this.region = '', this.radiusKm = 50, this.months = 6, this.lang = 'en'});
  final EventSport sport;

  /// Event distance key ([eventDistances]) or null = any.
  final String? distance;

  /// Country, city or postcode, free text ('' = anywhere).
  final String region;

  /// Search radius around a city / postcode.
  final int radiusKm;

  /// Time window from today in months.
  final int months;
  final String lang;

  String key(DateTime today) => '${sport.name}|$distance|${region.trim().toLowerCase()}|$radiusKm|$months|$lang|${dayKey(today)}';

  /// Last day of the time window.
  DateTime until(DateTime today) => DateTime(today.year, today.month + months, today.day);
}

/// A region typed by the user, resolved to a country and (for a city / postcode) a place.
class RaceRegion {
  const RaceRegion({this.countryCode, this.place, this.postcode, this.admin1});

  /// ISO country code (upper case); null = anywhere or unknown.
  final String? countryCode;

  /// City or postcode as typed; null = the whole country / anywhere.
  final String? place;
  final String? postcode;

  /// First-level region of the place (German federal state, US state).
  final String? admin1;

  bool get anywhere => countryCode == null && place == null;

  /// Germany, or a place whose country could not be determined (German calendars are tried).
  bool get germanyOrUnknown => countryCode == 'DE' || (countryCode == null && place != null) || anywhere;
}

/// One race found in a calendar.
class RaceResult {
  const RaceResult({
    required this.name,
    required this.date,
    required this.url,
    required this.source,
    this.endDate,
    this.city = '',
    this.region = '',
    this.countryCode = '',
    this.distanceKeys = const [],
    this.distances = const [],
  });
  final String name;
  final DateTime date;
  final DateTime? endDate;
  final String city;
  final String region;
  final String countryCode;

  /// App event distances ([eventDistances] keys) the race offers.
  final List<String> distanceKeys;

  /// Other distance texts of the source (e.g. "1,2–21,1 km").
  final List<String> distances;

  /// Detail page of the race at the source.
  final Uri url;

  /// Name of the calendar it came from (attribution).
  final String source;

  String get place => [city, region, countryCode].where((s) => s.isNotEmpty).join(', ');
}

/// Combined result of all calendars that cover the query.
class RaceSearchResult {
  const RaceSearchResult(this.races, {this.sources = const [], this.failed = const []});
  final List<RaceResult> races;

  /// Calendars that were searched (attribution).
  final List<String> sources;

  /// Calendars that could not be reached.
  final List<String> failed;

  /// No calendar covers this sport / region – only the calendar links help.
  bool get noSource => sources.isEmpty && failed.isEmpty;
}

enum RaceSearchFailure {
  /// Every calendar failed (network / site changed).
  failed,
}

class RaceSearchException implements Exception {
  const RaceSearchException(this.failure, [this.detail]);
  final RaceSearchFailure failure;
  final Object? detail;
  @override
  String toString() => 'RaceSearchException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// HTTP error or unreadable answer of one calendar.
class RaceSourceException implements Exception {
  const RaceSourceException(this.message);
  final String message;
  @override
  String toString() => 'RaceSourceException($message)';
}

// ───────────────────────────── HTTP ─────────────────────────────

/// HTTP for the calendars: user agent, timeout and a minimum interval between two
/// requests to the same host (polite rate limit).
class RaceHttp {
  RaceHttp(this.client, {this.minInterval = const Duration(seconds: 1), this.timeout = const Duration(seconds: 20)});
  final http.Client client;
  final Duration minInterval;
  final Duration timeout;
  final _next = <String, DateTime>{};

  Future<void> _throttle(String host) async {
    if (minInterval == Duration.zero) return;
    final now = DateTime.now();
    final at = _next[host];
    final start = at == null || at.isBefore(now) ? now : at;
    _next[host] = start.add(minInterval);
    final wait = start.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  Future<http.Response> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Map<String, String>? fields,
    bool followRedirects = true,
  }) async {
    await _throttle(url.host);
    final req =
        http.Request(method, url)
          ..followRedirects = followRedirects
          ..headers['User-Agent'] = raceUserAgent
          ..headers.addAll(headers);
    if (fields != null) req.bodyFields = fields;
    final res = await http.Response.fromStream(await client.send(req).timeout(timeout)).timeout(timeout);
    if (res.statusCode >= 400) throw RaceSourceException('${url.host}: HTTP ${res.statusCode}');
    return res;
  }

  Future<http.Response> get(Uri url, {Map<String, String> headers = const {}}) => send('GET', url, headers: headers);
}

/// Body as text: UTF-8, or Latin-1 when the bytes are not valid UTF-8 (some calendars
/// declare UTF-8 but send Latin-1).
String decodeBody(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

// ───────────────────────────── Sources ─────────────────────────────

/// One race calendar.
abstract class RaceSource {
  const RaceSource();

  /// Shown as attribution ("Quelle: …").
  String get name;

  bool supports(RaceQuery q, RaceRegion r);

  Future<List<RaceResult>> fetch(RaceQuery q, RaceRegion r, DateTime today, RaceHttp http);
}

/// DLV-Laufkalender on laufen.de – the JSON endpoint its search page uses
/// (POST /laufkalender/ajax/search, allowed by robots.txt). Geo search by city or postcode.
class LaufenDeSource extends RaceSource {
  const LaufenDeSource({this.maxPages = 3});
  final int maxPages;

  static final endpoint = Uri.https('www.laufen.de', '/laufkalender/ajax/search');

  @override
  String get name => 'laufen.de (DLV-Laufkalender)';

  @override
  bool supports(RaceQuery q, RaceRegion r) => q.sport == EventSport.run && r.germanyOrUnknown;

  @override
  Future<List<RaceResult>> fetch(RaceQuery q, RaceRegion r, DateTime today, RaceHttp http) async {
    final d = eventDistanceOf(q.distance);
    final out = <RaceResult>[];
    for (var page = 1; page <= maxPages; page++) {
      final res = await http.send(
        'POST',
        endpoint,
        headers: const {'X-Requested-With': 'XMLHttpRequest', 'Accept': 'application/json'},
        fields: {
          // A postcode: laufen.de resolves city names slowly (~20 s) and imprecisely.
          'search': r.place == null ? '' : (r.postcode ?? r.place!),
          'radius': '${r.place == null ? 25 : q.radiusKm.clamp(5, 250)}',
          'start': dayKey(today),
          'end': dayKey(q.until(today)),
          'distance_start': d == null ? '0' : '${(d.km * 0.95).floor()}',
          'distance_end': d == null ? '150' : '${(d.km * 1.05).ceil().clamp(1, 150)}',
          'distances': '[]',
          'page': '$page',
        },
      );
      final Object? json;
      try {
        json = jsonDecode(decodeBody(res.bodyBytes));
      } on FormatException {
        throw const RaceSourceException('laufen.de: no JSON');
      }
      if (json is! Map) throw const RaceSourceException('laufen.de: unexpected answer');
      out.addAll(parseLaufenDe(json, distance: q.distance));
      final pages = json['pages'] is num ? (json['pages'] as num).toInt() : 1;
      if (page >= pages) break;
    }
    return out;
  }
}

/// Races of one laufen.de search answer ({"events": html, "topevents": html, …}).
/// [distance] is the distance the search was filtered by: a race whose distance range
/// covers it is assumed to offer it.
List<RaceResult> parseLaufenDe(Map json, {String? distance}) {
  final frag = html.parseFragment('${json['topevents'] ?? ''}${json['events'] ?? ''}');
  final want = eventDistanceOf(distance);
  final out = <RaceResult>[];
  for (final a in frag.querySelectorAll('a.teaser.event')) {
    final name = _text(a.querySelector('.headline'));
    final date = parseGermanDate(_text(a.querySelector('.date')));
    final href = a.attributes['href'];
    if (name.isEmpty || date == null || href == null) continue;
    final loc = _text(a.querySelector('.location'));
    final m = RegExp(r'^(\d{5})\s+(.+)$').firstMatch(loc);
    final range = _text(a.querySelector('.wettbewerbe'));
    final kms = [for (final n in RegExp(r'\d+(?:,\d+)?').allMatches(range)) double.parse(n.group(0)!.replaceAll(',', '.'))];
    final codes = [for (final c in a.querySelectorAll('.code')) _text(c)];
    final keys = <String>{
      ...matchEventDistances(codes, EventSport.run),
      if (kms.length == 1) ...matchEventDistances(['${kms.first} km'], EventSport.run),
      if (want != null && kms.isNotEmpty && kms.first <= want.km * 1.01 && kms.last >= want.km * 0.97) want.key,
    };
    final rangeText = switch (kms.length) {
      0 => '',
      1 => '${Units.num(kms.first, 3)} km',
      _ => '${Units.num(kms.first, 3)}–${Units.num(kms.last, 3)} km',
    };
    out.add(
      RaceResult(
        name: name,
        date: date,
        url: Uri.https('www.laufen.de', '/').resolve(href),
        source: 'laufen.de',
        city: m?.group(2) ?? loc,
        countryCode: 'DE',
        distanceKeys: _ordered(keys),
        distances: [if (rangeText.isNotEmpty) rangeText],
      ),
    );
  }
  return out;
}

/// DTU-Kalender (Triathlon Deutschland) – its search form (session + CSRF token, then the
/// result list). Filters: sport, distance, postcode + radius or federal state; only
/// individual races for age-groupers (no youth / relay events).
class DtuSource extends RaceSource {
  const DtuSource({this.maxPages = 4});
  final int maxPages;

  static const host = 'www.dtu-kalender.de';

  @override
  String get name => 'DTU-Kalender (Triathlon Deutschland)';

  @override
  bool supports(RaceQuery q, RaceRegion r) => (q.sport == EventSport.triathlon || q.sport == EventSport.duathlon) && r.germanyOrUnknown;

  /// DTU distance ids of the app's event distances.
  static const distanceIds = {'sprint': '3', 'olympic': '4', '70.3': '5', 'ironman': '6', 'du_sprint': '9', 'du_standard': '10'};

  /// DTU state ids by federal state name.
  static const stateIds = {
    'baden-württemberg': '1',
    'bayern': '2',
    'berlin': '3',
    'brandenburg': '4',
    'bremen': '5',
    'hamburg': '6',
    'hessen': '7',
    'mecklenburg-vorpommern': '8',
    'niedersachsen': '9',
    'nordrhein-westfalen': '10',
    'rheinland-pfalz': '11',
    'saarland': '12',
    'sachsen-anhalt': '14',
    'sachsen': '13',
    'schleswig-holstein': '15',
    'thüringen': '16',
  };

  static String stateId(String? admin1) {
    final a = (admin1 ?? '').toLowerCase();
    if (a.isEmpty) return '';
    for (final e in stateIds.entries) {
      if (a.contains(e.key)) return e.value;
    }
    return '';
  }

  @override
  Future<List<RaceResult>> fetch(RaceQuery q, RaceRegion r, DateTime today, RaceHttp http) async {
    final cookies = <String, String>{};
    Map<String, String> headers() => {if (cookies.isNotEmpty) 'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; ')};

    final search = Uri.https(host, '/event/sport/search');
    final form = await http.get(search);
    readCookies(form.headers['set-cookie'], cookies);
    final token = html.parse(decodeBody(form.bodyBytes)).querySelector('input[name="_token"]')?.attributes['value'];
    if (token == null || token.isEmpty) throw const RaceSourceException('DTU: no form token');

    final usePostcode = r.place != null && (r.postcode?.isNotEmpty ?? false);
    final posted = await http.send(
      'POST',
      search,
      headers: headers(),
      followRedirects: false,
      fields: {
        '_token': token,
        'event_name': '',
        'sport_id': q.sport == EventSport.duathlon ? '2' : '1',
        'distance_id': distanceIds[q.distance] ?? '',
        'postal_code': usePostcode ? r.postcode! : '',
        'radius': usePostcode ? '${const [10, 25, 50, 100, 150, 200].firstWhere((v) => v >= q.radiusKm, orElse: () => 200)}' : '',
        'state_id': r.place != null && !usePostcode ? stateId(r.admin1) : '',
        'start_date': _deDay(today),
        'end_date': _deDay(q.until(today)),
        'format_id': '1',
        'target_id': '3',
      },
    );
    readCookies(posted.headers['set-cookie'], cookies);

    final out = <RaceResult>[];
    for (var page = 1; page <= maxPages; page++) {
      final res = await http.get(Uri.https(host, '/event/sport/list', {if (page > 1) 'page': '$page'}), headers: headers());
      readCookies(res.headers['set-cookie'], cookies);
      final body = decodeBody(res.bodyBytes);
      out.addAll(parseDtuList(body, sport: q.sport, distance: q.distance));
      if (!body.contains('page=${page + 1}')) break;
    }
    return out;
  }
}

/// Reads `name=value` pairs of a (comma-joined) Set-Cookie header into [jar].
void readCookies(String? header, Map<String, String> jar) {
  if (header == null) return;
  for (final m in RegExp(r'(?:^|,\s*)([A-Za-z0-9_\-]+)=([^;,]*)').allMatches(header)) {
    jar[m.group(1)!] = m.group(2)!;
  }
}

/// Races of a DTU-Kalender result list page.
List<RaceResult> parseDtuList(String body, {required EventSport sport, String? distance}) {
  final doc = html.parse(body);
  final out = <RaceResult>[];
  for (final tr in doc.querySelectorAll('table tbody tr')) {
    final td = tr.querySelectorAll('td');
    if (td.length < 4) continue;
    final a = td[0].querySelector('a');
    final href = a?.attributes['href'];
    final name = _text(a);
    final dates = RegExp(r'\d{1,2}\.\d{1,2}\.\d{4}').allMatches(_text(td[3])).map((m) => parseGermanDate(m.group(0)!)).toList();
    if (href == null || name.isEmpty || dates.isEmpty || dates.first == null) continue;
    final end = dates.length > 1 ? dates.last : null;
    out.add(
      RaceResult(
        name: name,
        date: dates.first!,
        // Multi-year series entries ("2026 – 2065") are not a race end.
        endDate: end != null && end.isAfter(dates.first!) && end.difference(dates.first!).inDays < 14 ? end : null,
        url: Uri.parse(href),
        source: 'DTU-Kalender',
        city: _text(td[2]),
        region: _text(td[1]),
        countryCode: 'DE',
        distanceKeys: _ordered({
          if (eventDistanceOf(distance)?.sport == sport) distance!,
          ...matchEventDistances([name], sport),
        }),
      ),
    );
  }
  return out;
}

/// RunSignup public REST API (GET /Rest/races, JSON) – races in the USA.
class RunSignupSource extends RaceSource {
  const RunSignupSource();

  @override
  String get name => 'RunSignup';

  @override
  bool supports(RaceQuery q, RaceRegion r) => r.countryCode == 'US' || r.anywhere;

  static String eventType(EventSport s) => switch (s) {
    EventSport.run => 'running_race',
    EventSport.triathlon => 'triathlon',
    EventSport.duathlon => 'duathlon',
    EventSport.ride => 'bike_ride',
    EventSport.swim => 'swim',
  };

  @override
  Future<List<RaceResult>> fetch(RaceQuery q, RaceRegion r, DateTime today, RaceHttp http) async {
    final d = eventDistanceOf(q.distance);
    // Single-sport distance: let the API filter (± 3 %); multisport totals are not comparable.
    final band = d != null && d.legs.isEmpty ? (d.km * 0.97, d.km * 1.03) : null;
    final zip = r.place != null && RegExp(r'^\d{5}$').hasMatch(r.postcode ?? '') ? r.postcode : null;
    final url = Uri.https('runsignup.com', '/Rest/races', {
      'format': 'json',
      'results_per_page': '50',
      'page': '1',
      'start_date': dayKey(today),
      'end_date': dayKey(q.until(today)),
      'country': 'US',
      'event_type': eventType(q.sport),
      'events': 'T',
      'sort': 'date ASC',
      'search_start_date_only': 'T',
      if (zip != null) 'zipcode': zip,
      if (zip != null) 'radius': '${(q.radiusKm / 1.609).round()}',
      if (zip == null && r.place != null) 'city': r.place!,
      if (band != null) 'min_distance': band.$1.toStringAsFixed(2),
      if (band != null) 'max_distance': band.$2.toStringAsFixed(2),
      if (band != null) 'distance_units': 'K',
    });
    final res = await http.get(url, headers: const {'Accept': 'application/json'});
    final Object? json;
    try {
      json = jsonDecode(decodeBody(res.bodyBytes));
    } on FormatException {
      throw const RaceSourceException('RunSignup: no JSON');
    }
    if (json is! Map) throw const RaceSourceException('RunSignup: unexpected answer');
    if (json['error'] != null) throw RaceSourceException('RunSignup: ${json['error']}');
    return parseRunSignup(json, sport: q.sport);
  }
}

/// Races of a RunSignup /Rest/races JSON answer.
List<RaceResult> parseRunSignup(Map json, {required EventSport sport}) {
  final out = <RaceResult>[];
  final races = json['races'];
  if (races is! List) return out;
  for (final item in races) {
    final r = item is Map ? item['race'] : null;
    if (r is! Map) continue;
    if (r['is_draft_race'] == 'T' || r['is_private_race'] == 'T') continue;
    final name = _str(r['name']);
    final date = _usDate(r['next_date']);
    final url = Uri.tryParse(_str(r['url']));
    if (name.isEmpty || date == null || url == null || !url.hasScheme) continue;
    final end = _usDate(r['next_end_date']);
    final addr = r['address'] is Map ? r['address'] as Map : const {};
    final texts = <String>{
      for (final e in r['events'] is List ? r['events'] as List : const [])
        if (e is Map && _str(e['distance']).isNotEmpty) _str(e['distance']),
    };
    out.add(
      RaceResult(
        name: name,
        date: date,
        endDate: end != null && end.isAfter(date) ? end : null,
        url: url,
        source: 'RunSignup',
        city: _str(addr['city']),
        region: _str(addr['state']),
        countryCode: _str(addr['country_code']).toUpperCase(),
        distanceKeys: matchEventDistances(texts, sport),
        distances:
            [
              for (final t in texts)
                if (matchEventDistances([t], sport).isEmpty) t,
            ].take(4).toList(),
      ),
    );
  }
  return out;
}

// ───────────────────────────── Region ─────────────────────────────

/// Resolves a free-text region: '' = anywhere, a known country name, otherwise a city or
/// postcode geocoded with Open-Meteo (free, no key). A failed lookup keeps the text as a
/// place of unknown country.
Future<RaceRegion> resolveRegion(String text, String lang, RaceHttp http) async {
  final t = text.trim();
  if (t.isEmpty) return const RaceRegion();
  final cc = countryCodeOf(t);
  if (cc != null) return RaceRegion(countryCode: cc);
  final plz = RegExp(r'^\d{4,5}$').hasMatch(t) ? t : null;
  try {
    final res = await http.get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': t, 'count': '1', 'language': lang, 'format': 'json'}),
    );
    final json = jsonDecode(decodeBody(res.bodyBytes));
    final hit = json is Map && json['results'] is List && (json['results'] as List).isNotEmpty ? (json['results'] as List).first : null;
    if (hit is Map) {
      final codes = hit['postcodes'];
      return RaceRegion(
        countryCode: _str(hit['country_code']).toUpperCase().nullIfEmpty,
        place: t,
        postcode: plz ?? (codes is List && codes.isNotEmpty ? _str(codes.first) : null),
        admin1: _str(hit['admin1']).nullIfEmpty,
      );
    }
  } catch (_) {
    // Offline geocoder: search with the text alone.
  }
  return RaceRegion(place: t, postcode: plz);
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

// ───────────────────────────── Service ─────────────────────────────

/// Race search over all [sources] with a cache (per query, [ttl]).
class RaceSearchService {
  RaceSearchService({
    http.Client? client,
    List<RaceSource>? sources,
    DateTime Function()? clock,
    Duration minInterval = const Duration(seconds: 1),
    this.ttl = const Duration(hours: 6),
    this.maxResults = 120,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       sources = sources ?? const [LaufenDeSource(), DtuSource(), RunSignupSource()],
       _clock = clock ?? DateTime.now {
    _http = RaceHttp(_client, minInterval: minInterval);
  }

  final http.Client _client;
  final bool _ownsClient;
  late final RaceHttp _http;
  final List<RaceSource> sources;
  final DateTime Function() _clock;
  final Duration ttl;
  final int maxResults;
  final _cache = <String, (DateTime, RaceSearchResult)>{};
  final _regions = <String, RaceRegion>{};

  /// Cached result of [q], if searched recently.
  RaceSearchResult? cached(RaceQuery q) {
    final hit = _cache[q.key(dayOnly(_clock()))];
    if (hit == null || _clock().difference(hit.$1) > ttl) return null;
    return hit.$2;
  }

  Future<RaceSearchResult> search(RaceQuery q) async {
    final hit = cached(q);
    if (hit != null) return hit;
    final today = dayOnly(_clock());
    final regionKey = q.region.trim().toLowerCase();
    // German place names: the DTU state filter matches the German federal state names.
    final region = _regions[regionKey] ??= await resolveRegion(q.region, 'de', _http);
    final active = sources.where((s) => s.supports(q, region)).toList();
    final failed = <String>[];
    final lists = await Future.wait([
      for (final s in active)
        s.fetch(q, region, today, _http).catchError((Object _) {
          failed.add(s.name);
          return <RaceResult>[];
        }),
    ]);
    if (active.isNotEmpty && failed.length == active.length) {
      throw RaceSearchException(RaceSearchFailure.failed, failed.join(', '));
    }
    final result = RaceSearchResult(
      mergeRaces(lists.expand((l) => l), today: today, until: q.until(today), distance: q.distance).take(maxResults).toList(),
      sources: [
        for (final s in active)
          if (!failed.contains(s.name)) s.name,
      ],
      failed: failed,
    );
    // Partial results are not cached: the next search retries the failed calendar.
    if (failed.isEmpty) _cache[q.key(today)] = (_clock(), result);
    return result;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Races in [today, until], without duplicates (same name and day from two calendars),
/// sorted by date. With a [distance] filter, races that clearly offer other distances only
/// are dropped (races without distance information stay).
List<RaceResult> mergeRaces(Iterable<RaceResult> races, {required DateTime today, required DateTime until, String? distance}) {
  final from = dayOnly(today), to = dayOnly(until);
  final seen = <String>{};
  final out = <RaceResult>[];
  for (final r in races) {
    if (r.date.isBefore(from) || r.date.isAfter(to)) continue;
    if (distance != null && r.distanceKeys.isNotEmpty && !r.distanceKeys.contains(distance) && r.distances.isEmpty) continue;
    if (!seen.add('${_norm(r.name)}|${dayKey(r.date)}')) continue;
    out.add(r);
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'^\d+\.\s*'), '').replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');

// ───────────────────────────── Distances ─────────────────────────────

/// App event distances ([eventDistances] keys of [sport]) named in distance texts such as
/// "Halbmarathon", "HM", "10 km", "13.1 Miles", "Olympische Distanz" or "IRONMAN 70.3".
List<String> matchEventDistances(Iterable<String> texts, EventSport sport) {
  final found = <String>{};
  final options = eventDistancesFor(sport);
  for (final raw in texts) {
    final s = raw.toLowerCase().replaceAll(',', '.').trim();
    if (s.isEmpty) continue;
    switch (sport) {
      case EventSport.run:
        final ultra = s.contains('ultra');
        if (s == 'hm' || RegExp(r'halb|half|semi|\bhm\b').hasMatch(s)) {
          found.add('hm');
          continue;
        }
        if (!ultra && (s == 'm' || RegExp(r'marathon').hasMatch(s))) {
          found.add('m');
          continue;
        }
      case EventSport.triathlon:
        // Names often list several: "O-See-Triathlon (MD, OD, SD)".
        final middle = RegExp(r'70[.]3|mittel|middle|half|\bmd\b').hasMatch(s);
        if (middle) found.add('70.3');
        if (RegExp(r'langdistanz|long distance|full distance|140[.]6|\bld\b').hasMatch(s) || (s.contains('ironman') && !middle)) {
          found.add('ironman');
        }
        if (RegExp(r'olymp|kurzdistanz|standard|5150|51[.]5|\bod\b|\bkd\b').hasMatch(s)) found.add('olympic');
        if (RegExp(r'sprint|\bsd\b').hasMatch(s)) found.add('sprint');
        continue;
      case EventSport.duathlon:
        if (RegExp(r'sprint').hasMatch(s)) found.add('du_sprint');
        if (RegExp(r'standard|kurz|olymp').hasMatch(s)) found.add('du_standard');
        continue;
      case EventSport.ride:
      case EventSport.swim:
        break;
    }
    for (final km in _kms(s)) {
      for (final d in options) {
        if ((km - d.km).abs() <= d.km * 0.03) found.add(d.key);
      }
    }
  }
  return _ordered(found);
}

/// Distances in km named in a text ("10 km", "5K", "13.1 miles", "1500 m").
Iterable<double> _kms(String s) sync* {
  for (final m in RegExp(r'(\d+(?:[.]\d+)?)\s*(km|k|kilometer|mi|miles?|m)\b').allMatches(s)) {
    final v = double.parse(m.group(1)!);
    yield switch (m.group(2)) {
      'mi' || 'mile' || 'miles' => v * 1.609344,
      'm' => v / 1000,
      _ => v,
    };
  }
}

/// [keys] in catalogue order.
List<String> _ordered(Set<String> keys) => [
  for (final d in eventDistances)
    if (keys.contains(d.key)) d.key,
];

/// Event distance to store when a race is taken over as goal: the filtered distance when
/// the race offers it (or lists none), otherwise the first recognised one; null = unknown.
String? eventDistanceFor(RaceResult r, EventSport sport, String? selected) {
  final sel = eventDistanceOf(selected)?.sport == sport ? selected : null;
  if (sel != null && (r.distanceKeys.contains(sel) || r.distanceKeys.isEmpty)) return sel;
  return r.distanceKeys.where((k) => eventDistanceOf(k)?.sport == sport).firstOrNull ?? sel;
}

// ───────────────────────────── Helpers ─────────────────────────────

String _text(dom.Element? e) => e == null ? '' : e.text.replaceAll(RegExp(r'\s+'), ' ').trim();

String _str(Object? v) => v is String ? v.trim() : (v is num ? '$v' : '');

String _deDay(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// "31.12.2026" / "1.1.2027" → date; null for anything else or impossible dates.
DateTime? parseGermanDate(String s) {
  final m = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(s);
  if (m == null) return null;
  return _date(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
}

DateTime? _usDate(Object? v) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(_str(v));
  if (m == null) return null;
  return _date(int.parse(m.group(3)!), int.parse(m.group(1)!), int.parse(m.group(2)!));
}

DateTime? _date(int y, int mo, int d) {
  final dt = DateTime(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d ? dt : null;
}

// ───────────────────────────── Race calendars ─────────────────────────────

/// A curated link to a race calendar.
class RaceLink {
  const RaceLink(this.label, this.url);
  final String label;
  final Uri url;
}

/// Country names (German and English) → (ISO code, ahotu slug).
const _countries = {
  'deutschland': ('DE', 'germany'),
  'germany': ('DE', 'germany'),
  'österreich': ('AT', 'austria'),
  'oesterreich': ('AT', 'austria'),
  'austria': ('AT', 'austria'),
  'schweiz': ('CH', 'switzerland'),
  'switzerland': ('CH', 'switzerland'),
  'niederlande': ('NL', 'netherlands'),
  'netherlands': ('NL', 'netherlands'),
  'holland': ('NL', 'netherlands'),
  'belgien': ('BE', 'belgium'),
  'belgium': ('BE', 'belgium'),
  'frankreich': ('FR', 'france'),
  'france': ('FR', 'france'),
  'italien': ('IT', 'italy'),
  'italy': ('IT', 'italy'),
  'spanien': ('ES', 'spain'),
  'spain': ('ES', 'spain'),
  'portugal': ('PT', 'portugal'),
  'dänemark': ('DK', 'denmark'),
  'denmark': ('DK', 'denmark'),
  'schweden': ('SE', 'sweden'),
  'sweden': ('SE', 'sweden'),
  'norwegen': ('NO', 'norway'),
  'norway': ('NO', 'norway'),
  'polen': ('PL', 'poland'),
  'poland': ('PL', 'poland'),
  'tschechien': ('CZ', 'czech-republic'),
  'czech republic': ('CZ', 'czech-republic'),
  'großbritannien': ('GB', 'united-kingdom'),
  'grossbritannien': ('GB', 'united-kingdom'),
  'vereinigtes königreich': ('GB', 'united-kingdom'),
  'england': ('GB', 'united-kingdom'),
  'uk': ('GB', 'united-kingdom'),
  'united kingdom': ('GB', 'united-kingdom'),
  'irland': ('IE', 'ireland'),
  'ireland': ('IE', 'ireland'),
  'usa': ('US', 'usa'),
  'us': ('US', 'usa'),
  'united states': ('US', 'usa'),
  'vereinigte staaten': ('US', 'usa'),
  'kanada': ('CA', 'canada'),
  'canada': ('CA', 'canada'),
  'australien': ('AU', 'australia'),
  'australia': ('AU', 'australia'),
};

/// ahotu slug of a country name, or null when [region] is not a known country (e.g. a city).
String? countrySlug(String region) => _countries[region.trim().toLowerCase()]?.$2;

/// ISO code of a country name, or null when [region] is not a known country.
String? countryCodeOf(String region) => _countries[region.trim().toLowerCase()]?.$1;

/// Default region for a locale: the country of the locale, in the UI language.
String defaultRegion(String languageCode, String? countryCode) {
  final de = languageCode == 'de';
  return switch (countryCode?.toUpperCase()) {
    'AT' => de ? 'Österreich' : 'Austria',
    'CH' => de ? 'Schweiz' : 'Switzerland',
    'DE' => de ? 'Deutschland' : 'Germany',
    'GB' => 'United Kingdom',
    'US' => 'USA',
    _ => de ? 'Deutschland' : '',
  };
}

const _ahotuSport = {
  EventSport.run: 'running',
  EventSport.triathlon: 'triathlon',
  EventSport.duathlon: 'duathlon',
  EventSport.ride: 'cycling',
  EventSport.swim: 'swimming',
};

const _ahotuDistance = {
  '5k': '5-km',
  '10k': '10-km',
  'hm': 'half-marathon',
  'm': 'marathon',
  'sprint': 'sprint',
  'olympic': 'olympic',
  '70.3': 'middle-distance-70-3',
};

/// Curated race calendars for the filters, with the search prefilled where the site
/// supports it. German calendars are included for Germany (or a city with a German UI).
List<RaceLink> racePortals(RaceQuery q, {required DateTime today}) {
  final region = q.region.trim();
  final country = countrySlug(region);
  final isCity = region.isNotEmpty && country == null;
  final germany = country == 'germany' || (country == null && q.lang.startsWith('de'));
  final until = q.until(today);
  final d = q.distance;
  final dist = eventDistanceOf(d);
  final ahotu = Uri.https(
    'www.ahotu.com',
    [
      '/calendar/${_ahotuSport[q.sport]}',
      if (d != null && _ahotuDistance[d] != null) '/${_ahotuDistance[d]}',
      if (country != null) '/$country',
    ].join(),
  );
  final tri = q.sport == EventSport.triathlon;
  final links = <RaceLink>[
    if (q.sport == EventSport.run && germany)
      RaceLink(
        'laufen.de (DLV-Laufkalender)',
        Uri.https('www.laufen.de', '/laufkalender', {
          if (isCity) 'search': region,
          if (isCity) 'radius': '${q.radiusKm}',
          if (dist != null) 'distance_start': '${(dist.km * 0.95).floor()}',
          if (dist != null) 'distance_end': '${(dist.km * 1.05).ceil()}',
          'start': dayKey(today),
          'end': dayKey(until),
        }),
      ),
    if (q.sport == EventSport.run && germany) RaceLink('marathon.de', Uri.https('www.marathon.de', '/laufevents')),
    if ((tri || q.sport == EventSport.duathlon) && germany)
      RaceLink('DTU-Kalender (Triathlon Deutschland)', Uri.https('www.dtu-kalender.de', '/')),
    if (tri && germany) RaceLink('tri-mag.de', Uri.https('www.tri-mag.de', '/termine')),
    if (q.sport == EventSport.ride && germany)
      RaceLink('rad-net Breitensportkalender (BDR)', Uri.https('breitensport.rad-net.de', '/breitensportkalender/')),
    RaceLink('ahotu', ahotu),
    if (q.sport == EventSport.run && (d == null || d == 'm' || d == 'hm'))
      RaceLink('World\'s Marathons', Uri.https('worldsmarathons.com', d == 'm' ? '/s/running/full_marathon' : '/')),
    if (tri && (d == null || d == '70.3' || d == 'ironman')) ...[
      RaceLink('IRONMAN / IRONMAN 70.3', Uri.https('www.ironman.com', '/races')),
      RaceLink('Challenge Family', Uri.https('www.challengefamily.com', '/races/')),
    ],
  ];
  final de = q.lang.startsWith('de');
  final words = [
    switch (q.sport) {
      EventSport.run => de ? 'Lauf' : 'running race',
      EventSport.triathlon => 'Triathlon',
      EventSport.duathlon => 'Duathlon',
      EventSport.ride => de ? 'Radmarathon' : 'cycling event',
      EventSport.swim => de ? 'Freiwasserschwimmen' : 'open water swim',
    },
    if (d != null) _googleDistance(d, de),
    if (region.isNotEmpty) region,
    '${today.year}${until.year != today.year ? ' ${until.year}' : ''}',
    de ? 'Termine' : 'dates',
  ];
  links.add(RaceLink('Google', Uri.https('www.google.com', '/search', {'q': words.join(' ')})));
  return links;
}

String _googleDistance(String d, bool de) => switch (d) {
  'hm' => de ? 'Halbmarathon' : 'half marathon',
  'm' => 'Marathon',
  'ultra50' => de ? 'Ultralauf 50 km' : '50k ultra',
  'sprint' => 'Sprint',
  'olympic' => de ? 'Olympische Distanz' : 'olympic distance',
  '70.3' => de ? 'Mitteldistanz' : 'middle distance 70.3',
  'ironman' => de ? 'Langdistanz' : 'full distance',
  'du_sprint' => 'Sprint',
  'du_standard' => de ? 'Standarddistanz' : 'standard distance',
  _ => eventDistanceOf(d) == null ? d : '${Units.num(eventDistanceOf(d)!.km, 1)} km',
};
