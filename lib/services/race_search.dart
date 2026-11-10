import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../core/format.dart';
import '../core/sport.dart';
import 'coach_service.dart';

/// Race / competition search.
///
/// There is no free, global race API. Two sources are combined:
/// 1. A web search through Gemini with Grounding with Google Search: the model may only
///    list events it found in the search results, with the organiser's URL. The answer is
///    parsed and validated here ([parseRaces]) – anything without a valid future date in
///    the time window or without a web link is dropped, so nothing invented reaches the UI.
///    Grounding needs a Gemini plan that includes it; without it the call fails with a
///    quota error ([RaceSearchFailure.unavailable]).
/// 2. Curated deep links to well-known race calendars ([racePortals]) – always available,
///    and the fallback for empty results and errors.

/// Sports the race search knows (not the same as [Sport]: multisport events are separate).
enum RaceSport { run, triathlon, duathlon, cycling, swim }

extension RaceSportX on RaceSport {
  /// Event distances of the app ([AthleteData.eventDistance] keys) for this sport.
  List<String> get distances => switch (this) {
    RaceSport.run => const ['5k', '10k', 'hm', 'm'],
    RaceSport.triathlon => const ['sprint', 'olympic', '70.3'],
    _ => const [],
  };

  /// Default sport for a training focus.
  static RaceSport fromFocus(TrainingFocus f) => switch (f) {
    TrainingFocus.triathlon => RaceSport.triathlon,
    TrainingFocus.duathlon => RaceSport.duathlon,
    TrainingFocus.ride => RaceSport.cycling,
    TrainingFocus.swim => RaceSport.swim,
    _ => RaceSport.run,
  };

  /// Main training sport of a race (for an event goal).
  Sport get sport => switch (this) {
    RaceSport.cycling => Sport.ride,
    RaceSport.swim => Sport.swim,
    _ => Sport.run,
  };
}

/// Filters of a race search.
class RaceQuery {
  const RaceQuery({required this.sport, this.distance, this.region = '', this.months = 6, this.lang = 'en'});
  final RaceSport sport;

  /// Event distance key ('5k', 'hm', 'olympic', …) or null = any.
  final String? distance;

  /// Country or city, free text ('' = anywhere).
  final String region;

  /// Time window from today in months.
  final int months;
  final String lang;

  String key(DateTime today) => '${sport.name}|$distance|${region.trim().toLowerCase()}|$months|$lang|${dayKey(today)}';

  /// Last day of the time window.
  DateTime until(DateTime today) => DateTime(today.year, today.month + months, today.day);
}

/// One race found on the web.
class RaceResult {
  const RaceResult({
    required this.name,
    required this.date,
    required this.url,
    this.city = '',
    this.country = '',
    this.sport = '',
    this.distances = const [],
  });
  final String name;
  final DateTime date;
  final String city;
  final String country;
  final String sport;
  final List<String> distances;
  final Uri url;

  String get place => [city, country].where((s) => s.isNotEmpty).join(', ');
}

/// A web page the search used (shown as source).
class WebSource {
  const WebSource(this.title, this.uri);
  final String title;
  final String uri;
}

/// Raw grounded answer of the model.
class GroundedReply {
  const GroundedReply(this.text, {this.sources = const [], this.queries = const []});
  final String text;
  final List<WebSource> sources;

  /// Google searches the model ran (shown as search suggestions).
  final List<String> queries;
}

/// Validated search result.
class RaceSearchResult {
  const RaceSearchResult(this.races, {this.sources = const [], this.queries = const []});
  final List<RaceResult> races;
  final List<WebSource> sources;
  final List<String> queries;
}

enum RaceSearchFailure {
  /// The AI web search is not available (quota / plan without grounding / service off).
  unavailable,

  /// Network or other error.
  failed,

  /// The answer could not be read.
  badResponse,
}

class RaceSearchException implements Exception {
  const RaceSearchException(this.failure, [this.detail]);
  final RaceSearchFailure failure;
  final Object? detail;
  @override
  String toString() => 'RaceSearchException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Runs the grounded web search for a prompt (injectable; the app uses [geminiGroundedSearch]).
typedef GroundedSearch = Future<GroundedReply> Function(String prompt);

/// Race search with a per-session cache.
class RaceSearchService {
  RaceSearchService(this._search, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final GroundedSearch _search;
  final DateTime Function() _clock;
  final _cache = <String, RaceSearchResult>{};

  /// Cached result of [q] for today, if searched before in this session.
  RaceSearchResult? cached(RaceQuery q) => _cache[q.key(dayOnly(_clock()))];

  Future<RaceSearchResult> search(RaceQuery q) async {
    final today = dayOnly(_clock());
    final key = q.key(today);
    final hit = _cache[key];
    if (hit != null) return hit;
    GroundedReply reply;
    try {
      reply = await _search(racePrompt(q, today));
    } on RaceSearchException {
      rethrow;
    } catch (e) {
      throw RaceSearchException(isQuotaError(e) ? RaceSearchFailure.unavailable : RaceSearchFailure.failed, e);
    }
    final List<RaceResult> races;
    try {
      races = parseRaces(reply.text, today: today, until: q.until(today));
    } on FormatException catch (e) {
      throw RaceSearchException(RaceSearchFailure.badResponse, e);
    }
    final result = RaceSearchResult(races, sources: reply.sources, queries: reply.queries);
    _cache[key] = result;
    return result;
  }
}

/// Whether an error of the AI service means "not available on this plan / quota used up".
bool isQuotaError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('quota') ||
      s.contains('resource_exhausted') ||
      s.contains('429') ||
      s.contains('billing') ||
      s.contains('api has not been used') ||
      s.contains('not enabled');
}

String _sportText(RaceSport s) => switch (s) {
  RaceSport.run => 'running races (road races, city runs, marathons)',
  RaceSport.triathlon => 'triathlon races',
  RaceSport.duathlon => 'duathlon races (run-bike-run)',
  RaceSport.cycling => 'cycling events (road races, gran fondos, cyclosportives, RTF)',
  RaceSport.swim => 'swimming competitions and open-water swims',
};

String _distanceText(String d) => switch (d) {
  '5k' => '5 km',
  '10k' => '10 km',
  'hm' => 'half marathon (21.1 km)',
  'm' => 'marathon (42.2 km)',
  'sprint' => 'sprint distance (750 m swim / 20 km bike / 5 km run)',
  'olympic' => 'olympic distance (1.5 km swim / 40 km bike / 10 km run)',
  '70.3' => 'middle distance / 70.3 (1.9 km swim / 90 km bike / 21.1 km run)',
  _ => d,
};

/// Prompt for the grounded search. The model must only return events it found.
String racePrompt(RaceQuery q, DateTime today) {
  final region = q.region.trim().isEmpty ? 'worldwide' : 'in or near "${q.region.trim()}"';
  final dist = q.distance == null ? '' : ' offering the ${_distanceText(q.distance!)}';
  final lang = q.lang.startsWith('de') ? 'German' : 'English';
  return '''
Today is ${dayKey(today)}. Use Google Search to find real, upcoming ${_sportText(q.sport)}$dist $region that take place between ${dayKey(today)} and ${dayKey(q.until(today))}.

Rules:
- Only list events that you actually found in the search results. Never invent or guess events, dates or links.
- Every event needs its exact date for this edition and the URL of the organiser's official event page (or, if there is none, the page where you found it). Skip events whose date is not published yet.
- Respond with ONLY a JSON array, no other text and no markdown. Each item:
  {"name": "official event name", "date": "YYYY-MM-DD", "city": "city", "country": "country", "sport": "${q.sport.name}", "distances": ["e.g. 10 km", "Half marathon"], "url": "https://..."}
- At most 15 events, sorted by date. If you found none, respond with [].
- City and country in $lang; keep event names as published.''';
}

/// Parses and validates the model's answer. Accepts a JSON array (optionally wrapped in a
/// markdown code block or surrounded by text) or an object with an "events"/"races" list.
/// Drops items without a name, without a date in [today, until] or without an http(s)
/// URL. Throws [FormatException] when no JSON can be read at all.
List<RaceResult> parseRaces(String text, {required DateTime today, required DateTime until}) {
  final decoded = _decodeJson(text);
  final list = switch (decoded) {
    List l => l,
    Map m when m['events'] is List => m['events'] as List,
    Map m when m['races'] is List => m['races'] as List,
    _ => throw const FormatException('no JSON array in the answer'),
  };
  final from = dayOnly(today);
  final to = dayOnly(until);
  final seen = <String>{};
  final out = <RaceResult>[];
  for (final item in list) {
    if (item is! Map) continue;
    final name = _str(item['name']);
    final date = _date(item['date']);
    final url = validRaceUrl(_str(item['url']));
    if (name.isEmpty || date == null || url == null) continue;
    if (date.isBefore(from) || date.isAfter(to)) continue;
    if (!seen.add('${name.toLowerCase()}|${dayKey(date)}')) continue;
    final d = item['distances'];
    out.add(
      RaceResult(
        name: name,
        date: date,
        url: url,
        city: _str(item['city']),
        country: _str(item['country']),
        sport: _str(item['sport']),
        distances: [if (d is List) ...d.map(_str).where((s) => s.isNotEmpty), if (d is String && d.trim().isNotEmpty) d.trim()],
      ),
    );
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

Object? _decodeJson(String text) {
  var t = text.trim();
  // ```json … ``` wrapper.
  final fence = RegExp(r'```(?:json|JSON)?\s*([\s\S]*?)```').firstMatch(t);
  if (fence != null) t = fence.group(1)!.trim();
  try {
    return jsonDecode(t);
  } on FormatException {
    // Text around the JSON: take the outermost array.
    final a = t.indexOf('[');
    final b = t.lastIndexOf(']');
    if (a >= 0 && b > a) {
      try {
        return jsonDecode(t.substring(a, b + 1));
      } on FormatException {
        // fall through
      }
    }
    throw const FormatException('answer is not JSON');
  }
}

String _str(Object? v) => v is String ? v.trim() : (v is num ? '$v' : '');

DateTime? _date(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  // Reject overflowing dates like 2027-02-30.
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// An http(s) link to a real web page, or null (search pages, placeholders and the
/// short-lived grounding redirect links are not organiser pages).
Uri? validRaceUrl(String s) {
  if (s.isEmpty) return null;
  final u = Uri.tryParse(s);
  if (u == null || (u.scheme != 'https' && u.scheme != 'http') || !u.host.contains('.')) return null;
  final h = u.host.toLowerCase();
  const bad = ['example.com', 'example.org', 'example.net', 'vertexaisearch.cloud.google.com'];
  if (bad.any((b) => h == b || h.endsWith('.$b'))) return null;
  if (RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(h) && u.path.startsWith('/search')) return null;
  return u;
}

/// App event distance keys ('5k', 'hm', 'olympic', …) named in a race's distance texts.
List<String> matchEventDistances(List<String> distances, RaceSport sport) {
  final found = <String>{};
  for (final raw in distances) {
    final s = raw.toLowerCase().replaceAll(',', '.');
    final half = RegExp(r'halb|half|semi|\bhm\b|21[.]1|21[.]09').hasMatch(s);
    if (sport == RaceSport.triathlon) {
      if (RegExp(r'70[.]3|mittel|middle|half|113\s*km|1[.]9\s*km').hasMatch(s)) {
        found.add('70.3');
      } else if (RegExp(r'olymp|kurz|standard|51[.]5|1[.]5\s*km').hasMatch(s)) {
        found.add('olympic');
      } else if (RegExp(r'sprint|25[.]75|750\s*m').hasMatch(s)) {
        found.add('sprint');
      }
      continue;
    }
    if (sport != RaceSport.run) continue;
    if (half) {
      found.add('hm');
    } else if (RegExp(r'marathon|42[.]2|42[.]195').hasMatch(s) && !s.contains('ultra')) {
      found.add('m');
    } else if (RegExp(r'(^|[^\d.])10(?:[.]0)?\s*(k|km)\b').hasMatch(s)) {
      found.add('10k');
    } else if (RegExp(r'(^|[^\d.])5(?:[.]0)?\s*(k|km)\b').hasMatch(s)) {
      found.add('5k');
    }
  }
  return [
    for (final d in sport.distances)
      if (found.contains(d)) d,
  ];
}

/// Event distance to store when a race is taken over as goal: the filtered distance when
/// the race offers it (or lists none), otherwise the first recognised one; null = unknown.
String? eventDistanceFor(RaceResult r, RaceSport sport, String? selected) {
  final found = matchEventDistances(r.distances, sport);
  if (selected != null && (found.contains(selected) || r.distances.isEmpty)) return selected;
  return found.firstOrNull ?? (sport.distances.contains(selected) ? selected : null);
}

/// Distance in km of an app event distance key.
double? eventKm(String? d) => switch (d) {
  '5k' => 5,
  '10k' => 10,
  'hm' => 21.1,
  'm' => 42.2,
  'sprint' => 25.75,
  'olympic' => 51.5,
  '70.3' => 113,
  _ => null,
};

// ───────────────────────────── Race calendars ─────────────────────────────

/// A curated link to a race calendar.
class RaceLink {
  const RaceLink(this.label, this.url);
  final String label;
  final Uri url;
}

/// Country names (German and English) → ahotu country slug.
const _countries = {
  'deutschland': 'germany',
  'germany': 'germany',
  'österreich': 'austria',
  'oesterreich': 'austria',
  'austria': 'austria',
  'schweiz': 'switzerland',
  'switzerland': 'switzerland',
  'niederlande': 'netherlands',
  'netherlands': 'netherlands',
  'holland': 'netherlands',
  'belgien': 'belgium',
  'belgium': 'belgium',
  'frankreich': 'france',
  'france': 'france',
  'italien': 'italy',
  'italy': 'italy',
  'spanien': 'spain',
  'spain': 'spain',
  'portugal': 'portugal',
  'dänemark': 'denmark',
  'denmark': 'denmark',
  'schweden': 'sweden',
  'sweden': 'sweden',
  'norwegen': 'norway',
  'norway': 'norway',
  'polen': 'poland',
  'poland': 'poland',
  'tschechien': 'czech-republic',
  'czech republic': 'czech-republic',
  'großbritannien': 'united-kingdom',
  'grossbritannien': 'united-kingdom',
  'vereinigtes königreich': 'united-kingdom',
  'england': 'united-kingdom',
  'uk': 'united-kingdom',
  'united kingdom': 'united-kingdom',
  'irland': 'ireland',
  'ireland': 'ireland',
  'usa': 'usa',
  'united states': 'usa',
  'vereinigte staaten': 'usa',
  'kanada': 'canada',
  'canada': 'canada',
  'australien': 'australia',
  'australia': 'australia',
};

/// ahotu slug of a country name, or null when [region] is not a known country (e.g. a city).
String? countrySlug(String region) => _countries[region.trim().toLowerCase()];

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
  RaceSport.run: 'running',
  RaceSport.triathlon: 'triathlon',
  RaceSport.duathlon: 'duathlon',
  RaceSport.cycling: 'cycling',
  RaceSport.swim: 'swimming',
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

/// laufen.de distance filter (km range) per event distance.
const _laufenKm = {'5k': (4, 6), '10k': (9, 11), 'hm': (20, 22), 'm': (42, 43)};

/// Curated race calendars for the filters, with the search prefilled where the site
/// supports it. German calendars are included for Germany (or a city with a German UI).
List<RaceLink> racePortals(RaceQuery q, {required DateTime today}) {
  final region = q.region.trim();
  final country = countrySlug(region);
  final isCity = region.isNotEmpty && country == null;
  final germany = country == 'germany' || (country == null && q.lang.startsWith('de'));
  final until = q.until(today);
  final d = q.distance;
  final ahotu = Uri.https(
    'www.ahotu.com',
    [
      '/calendar/${_ahotuSport[q.sport]}',
      if (d != null && _ahotuDistance[d] != null) '/${_ahotuDistance[d]}',
      if (country != null) '/$country',
    ].join(),
  );
  final links = <RaceLink>[
    if (q.sport == RaceSport.run && germany)
      RaceLink(
        'laufen.de (DLV-Laufkalender)',
        Uri.https('www.laufen.de', '/laufkalender', {
          if (isCity) 'search': region,
          if (isCity) 'radius': '50',
          if (d != null && _laufenKm[d] != null) 'distance_start': '${_laufenKm[d]!.$1}',
          if (d != null && _laufenKm[d] != null) 'distance_end': '${_laufenKm[d]!.$2}',
          'start': dayKey(today),
          'end': dayKey(until),
        }),
      ),
    if (q.sport == RaceSport.run && germany) RaceLink('marathon.de', Uri.https('www.marathon.de', '/laufevents')),
    if ((q.sport == RaceSport.triathlon || q.sport == RaceSport.duathlon) && germany)
      RaceLink('DTU-Kalender (Triathlon Deutschland)', Uri.https('www.dtu-kalender.de', '/')),
    if (q.sport == RaceSport.triathlon && germany) RaceLink('tri-mag.de', Uri.https('www.tri-mag.de', '/termine')),
    if (q.sport == RaceSport.cycling && germany) RaceLink('rad-net.de (BDR)', Uri.https('www.rad-net.de', '/')),
    RaceLink('ahotu', ahotu),
    if (q.sport == RaceSport.run && (d == null || d == 'm' || d == 'hm'))
      RaceLink('World\'s Marathons', Uri.https('worldsmarathons.com', d == 'm' ? '/s/running/full_marathon' : '/')),
    if (q.sport == RaceSport.triathlon && (d == null || d == '70.3')) ...[
      RaceLink('IRONMAN / IRONMAN 70.3', Uri.https('www.ironman.com', '/races')),
      RaceLink('Challenge Family', Uri.https('www.challengefamily.com', '/races/')),
    ],
  ];
  final words = [
    switch (q.sport) {
      RaceSport.run => q.lang.startsWith('de') ? 'Lauf' : 'running race',
      RaceSport.triathlon => 'Triathlon',
      RaceSport.duathlon => 'Duathlon',
      RaceSport.cycling => q.lang.startsWith('de') ? 'Radrennen' : 'cycling event',
      RaceSport.swim => q.lang.startsWith('de') ? 'Schwimmwettkampf' : 'swim race',
    },
    if (d != null) _googleDistance(d, q.lang),
    if (region.isNotEmpty) region,
    '${today.year}${until.year != today.year ? ' ${until.year}' : ''}',
    q.lang.startsWith('de') ? 'Termine' : 'dates',
  ];
  links.add(RaceLink('Google', Uri.https('www.google.com', '/search', {'q': words.join(' ')})));
  return links;
}

String _googleDistance(String d, String lang) => switch (d) {
  '5k' => '5 km',
  '10k' => '10 km',
  'hm' => lang.startsWith('de') ? 'Halbmarathon' : 'half marathon',
  'm' => 'Marathon',
  'sprint' => 'Sprint',
  'olympic' => lang.startsWith('de') ? 'Olympische Distanz' : 'olympic distance',
  '70.3' => lang.startsWith('de') ? 'Mitteldistanz' : 'middle distance 70.3',
  _ => d,
};

// ───────────────────────────── Gemini backend ─────────────────────────────

/// Grounded web search through Gemini (Firebase AI Logic, Grounding with Google Search).
/// No JSON response mode: tools and JSON mode are not combinable on every model, so the
/// prompt asks for JSON and [parseRaces] reads it defensively.
Future<GroundedReply> geminiGroundedSearch(String prompt) async {
  final model = FirebaseAI.googleAI().generativeModel(model: CoachService.model, tools: [Tool.googleSearch()]);
  final res = await model.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 90));
  final meta = res.candidates.firstOrNull?.groundingMetadata;
  return GroundedReply(
    res.text ?? '',
    sources: [
      for (final c in meta?.groundingChunks ?? const [])
        if (c.web?.uri != null) WebSource(c.web!.title ?? c.web!.domain ?? c.web!.uri!, c.web!.uri!),
    ],
    queries: meta?.webSearchQueries ?? const [],
  );
}
