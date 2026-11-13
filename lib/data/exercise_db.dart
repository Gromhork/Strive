import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart';

import '../core/collation.dart';
import 'exercise_names_de.dart';

class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final List<String> secondary;
  final List<String> instructions;

  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.secondary,
    required this.instructions,
  });

  String get displayName => name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  factory Exercise.fromJson(Map<String, dynamic> m) => Exercise(
    id: m['id'],
    name: m['n'],
    bodyPart: m['b'],
    equipment: m['e'],
    target: m['t'],
    secondary: List<String>.from(m['s'] ?? const []),
    instructions: List<String>.from(m['i'] ?? const []),
  );
}

/// Library entries that are hidden from the library, the picker and the search but stay
/// loadable by id ([ExerciseDb.byId]), so stored sessions, programs, plans and goals that
/// reference them keep working (name, media, classification).
const hiddenExerciseIds = {
  // Endurance cardio – logged as run / ride workouts, not as gym sets.
  '0684', '0685', // run (jogging on the spot)
  '0798', '2138', // stationary bike
  '0858', '3656', // wind sprints, short stride run
  '2141', '2331', // elliptical / cycle cross trainer
  '2311', // stepmill
  '3666', // incline treadmill walk
  '2139', '2142', // arm ergometer, ski ergometer (steady-state machines, not sets of a muscle)
  // Not a meaningful exercise on its own.
  '2271', // "left hook. boxing"
  '3637', // "wheel run" (unclear; the ab wheel rollouts cover it)
  '3638', // "push to run" (push-up + sprint start)
  // Duplicates: a second animation ("v. 2/v. 3", camera angle, female/male model) or an
  // identical second entry of an exercise that stays in the library.
  '0077', '0079', '0097', '0119', '0121', '0125', '0287', '0304', '0309', '0312', '0317', '0342', '0360', '0376', '0395',
  '0497', '0513', '0576', '0656', '0658', '0735', '1371', '1394', '1439', '1461', '1462', '1463', '1464', '1479', '1614',
  '1628', '1657', '1680', '1731', '1765', '2136', '2189', '2371', '2800', '2801', '3698', '3760',
  // Same movement as the entry in brackets (same instructions, same or reworded name).
  '0055', // close-grip bench press (0030)
  '0161', '0164', // cable front raise (0162)
  '0198', // cable lat pulldown (2330)
  '0315', // dumbbell incline curl (0318)
  '0324', '1623', // dumbbell incline neutral-grip press (0321)
  '0340', // dumbbell neutral-grip bench press (0352)
  '0416', // dumbbell biceps curl (0294)
  '0674', // chin-up (1326)
  '1257', // barbell incline reverse-grip bench press (0048)
  '1289', // dumbbell one arm incline press (1281)
  '1629', // barbell standing wide-grip curl (0113)
  '1654', // dumbbell reverse curl (0382)
  '1661', // dumbbell lying supine curl (0350)
  '2292', // dumbbell rear lateral raise (0380)
  '3546', // dumbbell seated alternate shoulder press (0388)
};

/// Offline exercise database (~1250 visible exercises, bundled as an asset).
class ExerciseDb {
  ExerciseDb(this.all)
    : _byId = {for (final e in all) e.id: e},
      visible = [
        for (final e in all)
          if (!hiddenExerciseIds.contains(e.id)) e,
      ];

  /// Every entry, also the hidden ones (for lookups by id).
  final List<Exercise> all;

  /// The entries shown in the library, the picker and the search.
  final List<Exercise> visible;
  final Map<String, Exercise> _byId;
  final _hay = <String, String>{};

  static Future<ExerciseDb> load() async {
    final raw = await rootBundle.loadString('assets/data/exercises.json');
    // ~0.8 MB of JSON: decoded off the UI thread (it stalled the frame opening the library).
    // Not under `flutter test`: fake-async widget tests would never see the isolate finish.
    final list = _underTest ? parseExercises(raw) : await compute(parseExercises, raw);
    return ExerciseDb(list);
  }

  /// Any exercise by id – also one hidden from the library (stored sessions keep working).
  Exercise? byId(String id) => _byId[id];

  late final List<String> bodyParts = visible.map((e) => e.bodyPart).toSet().toList()..sort();
  late final List<String> equipment = visible.map((e) => e.equipment).toSet().toList()..sort();

  /// [bodyParts] / [equipment] in the alphabetical order of their labels in [lang] (filter
  /// menus).
  List<String> bodyPartsFor(String lang) => _byLabel(bodyParts, lang);
  List<String> equipmentFor(String lang) => _byLabel(equipment, lang);
  static List<String> _byLabel(List<String> keys, String lang) => [...keys]..sort((a, b) => compareNames(term(a, lang), term(b, lang)));

  /// Search text of [e]: English and German name, muscles, body part and equipment in both
  /// languages plus German keywords – folded ([foldSearch]) and built once per exercise. The
  /// names are added a second time without hyphens, so "pushup" finds "push-up" too.
  String _searchText(Exercise e) =>
      _hay[e.id] ??= () {
        final names = '${e.name} ${exerciseNamesDe[e.id] ?? ''}';
        return foldSearch(
          '$names ${e.target} ${e.bodyPart} ${e.equipment} ${term(e.target, 'de')} ${term(e.bodyPart, 'de')} '
          '${term(e.equipment, 'de')} ${germanAlias(e)} ${names.replaceAll('-', '')}',
        );
      }();

  /// Search by German and English name, muscles and equipment – case-, umlaut- and
  /// hyphen-insensitive ("bankdrucken", "Bankdrücken", "bankdruecken"; "pushup", "push-up").
  /// Ranking: exact name, name prefix, word prefix, then common exercises (built-in programs
  /// and classic lifts) before the rest, shorter names first. Hidden entries never show up.
  List<Exercise> search(String q, {String? bodyPart, String? equipment, String lang = 'en'}) {
    final q0 = foldSearch(q).trim();
    final terms = q0.split(' ').where((t) => t.isNotEmpty).toList();
    final res =
        visible.where((e) {
          if (bodyPart != null && e.bodyPart != bodyPart) return false;
          if (equipment != null && e.equipment != equipment) return false;
          if (terms.isEmpty) return true;
          final hay = _searchText(e);
          return terms.every(hay.contains);
        }).toList();
    // Each hit's shown name once – the comparators below asked for it O(n log n) times.
    final names = {for (final e in res) e.id: exerciseName(e.id, e.name, lang)};
    String shown(Exercise e) => names[e.id]!;
    if (terms.isNotEmpty) {
      final ranks = {for (final e in res) e.id: searchRank(e, q0)};
      int common(Exercise e) => commonExerciseIds.contains(e.id) ? 0 : 1;
      res.sort((a, b) {
        final c = ranks[a.id]!.compareTo(ranks[b.id]!);
        if (c != 0) return c;
        final k = common(a).compareTo(common(b));
        if (k != 0) return k;
        final l = shown(a).length.compareTo(shown(b).length);
        if (l != 0) return l;
        // Deterministic ties (List.sort is not stable): the classic free weights first.
        final q = _equipmentRank(a).compareTo(_equipmentRank(b));
        return q != 0 ? q : compareNames(shown(a), shown(b));
      });
    } else {
      // Alphabetical by the shown name – also in English, where display names
      // ([exerciseNamesEn], e.g. 9001 "Front plank") differ from the database names the JSON
      // is sorted by. German order: "Überzüge" under U, not after Z.
      final keys = {for (final e in res) e.id: collationKey(shown(e))};
      res.sort((a, b) {
        final c = keys[a.id]!.compareTo(keys[b.id]!);
        return c != 0 ? c : shown(a).compareTo(shown(b));
      });
    }
    return res;
  }
}

bool get _underTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// The exercises of the bundled JSON, sorted by database name (top-level for [compute]).
List<Exercise> parseExercises(String raw) =>
    (jsonDecode(raw) as List).map((e) => Exercise.fromJson(e)).toList()..sort((a, b) => a.name.compareTo(b.name));

int _equipmentRank(Exercise e) => switch (e.equipment) {
  'barbell' => 0,
  'dumbbell' => 1,
  'body weight' => 2,
  'cable' || 'leverage machine' || 'smith machine' || 'sled machine' => 3,
  _ => 4,
};

/// Folds [s] for searching: lower case, umlauts and their transcriptions to the base vowel
/// (ä/ae → a, ö/oe → o, ü/ue → u, ß/ss → s), hyphens as word breaks, whitespace collapsed.
String foldSearch(String s) =>
    s.toLowerCase().replaceAll(_ae, 'a').replaceAll(_oe, 'o').replaceAll(_ue, 'u').replaceAll(_sz, 's').replaceAll(_gaps, ' ');

/// Rank of [e] for the folded query [q] ([foldSearch]; lower = better): 0 exact name, 1/2
/// name prefix, 3/4 word prefix, 5/6 anything else – popular exercises first in each group.
int searchRank(Exercise e, String q) {
  final names = [foldSearch(e.name), if (exerciseNamesDe[e.id] case final de?) foldSearch(de)];
  final popular = popularExerciseIds.contains(e.id);
  // "Unterarmstütz / Plank": each of the alternative names counts as the name.
  final alternatives = [for (final n in names) ...n.replaceAll(_bracketSuffix, '').split(' / ')];
  if (names.contains(q) || alternatives.any((n) => n.trim() == q)) return 0;
  if (names.any((n) => n.startsWith(q))) return popular ? 1 : 2;
  if (names.any((n) => n.split(_wordBreaks).any((w) => w.startsWith(q)))) return popular ? 3 : 4;
  return popular ? 5 : 6;
}

final _bracketSuffix = RegExp(r'\s*\(.*\)$');
final _wordBreaks = RegExp(r'[\s/(),]+');
final _ae = RegExp('ä|ae'), _oe = RegExp('ö|oe'), _ue = RegExp('ü|ue'), _sz = RegExp('ß|ss'), _gaps = RegExp(r'[\s\-]+');

/// German search aliases so "bankdrücken" or "kniebeuge" find the right lifts. Matched on
/// whole words of the English database name – a substring would tag "th-row" and "nar-row" as
/// rows or a leg curl as a biceps exercise.
String germanAlias(Exercise e) {
  final n = e.name;
  final out = [
    for (final (re, alias) in _aliases)
      if (re.hasMatch(n)) alias,
  ];
  // "Curl" names the biceps curl, the leg curl and the wrist curl: tagged by the movement the
  // name spells out ("leg curl", "wrist curl"), otherwise by what it trains – a "bicep curl
  // with leg raised" or a "leg concentration curl" stays a biceps curl.
  if (_curl.hasMatch(n)) {
    if (_legCurl.hasMatch(n)) {
      out.add('beinbeuger');
    } else if (_wristCurl.hasMatch(n)) {
      out.add('unterarm handgelenk');
    } else {
      switch (e.target) {
        case 'biceps':
          out.add('bizeps');
        case 'hamstrings':
          out.add('beinbeuger');
        case 'forearms':
          out.add('unterarm handgelenk');
      }
    }
  }
  return out.join(' ');
}

final _aliases = <(RegExp, String)>[
  (RegExp(r'\bbench press'), 'bankdrücken'),
  (RegExp(r'\bsquats?\b'), 'kniebeuge'),
  (RegExp(r'\bdeadlifts?\b'), 'kreuzheben'),
  (RegExp(r'\brows?\b'), 'rudern'),
  (RegExp(r'\b(pull|chin)-?ups?\b'), 'klimmzug'),
  (RegExp(r'\bpush-?ups?\b'), 'liegestütz'),
  (RegExp(r'\bpushdown|\btriceps?\b'), 'trizeps'),
  (RegExp(r'\bshoulder press|\bmilitary press|\boverhead press'), 'schulterdrücken'),
  (RegExp(r'\blateral raises?\b'), 'seitheben'),
  (RegExp(r'\blunges?\b'), 'ausfallschritt'),
  (RegExp(r'\bcalf\b|\bcalves\b'), 'waden'),
  (RegExp(r'\bleg press'), 'beinpresse'),
  (RegExp(r'\bpulldowns?\b'), 'latzug'),
  (RegExp(r'\b(fly|flys|flyes|flies)\b'), 'fliegende butterfly'),
  (RegExp(r'\bcrunch(es)?\b|\bsit-?ups?\b'), 'bauch'),
  (RegExp(r'\bplank\b'), 'unterarmstütz'),
  (RegExp(r'\bside (plank|bridge)\b'), 'seitstütz side plank side bridge'),
  (RegExp(r'\bdips?\b'), 'dips'),
  (RegExp(r'\b(wood ?chop|chop)\b|\bcable standing lift\b'), 'holzhacker woodchop'),
];
final _curl = RegExp(r'\bcurls?\b');
final _legCurl = RegExp(r'\b(leg|hamstring) curls?\b|\bnordic\b');
final _wristCurl = RegExp(r'\b(wrist|finger) curls?\b');

const _deTerms = {
  'back': 'Rücken',
  'cardio': 'Cardio',
  'chest': 'Brust',
  'lower arms': 'Unterarme',
  'lower legs': 'Unterschenkel',
  'neck': 'Nacken',
  'shoulders': 'Schultern',
  'upper arms': 'Oberarme',
  'upper legs': 'Oberschenkel',
  'waist': 'Rumpf',
  'abductors': 'Abduktoren',
  'abs': 'Bauch',
  'adductors': 'Adduktoren',
  'biceps': 'Bizeps',
  'calves': 'Waden',
  'cardiovascular system': 'Herz-Kreislauf',
  'delts': 'Deltamuskel',
  'forearms': 'Unterarme',
  'glutes': 'Gesäß',
  'hamstrings': 'Beinbeuger',
  'lats': 'Latissimus',
  'levator scapulae': 'Schulterblattheber',
  'pectorals': 'Brustmuskel',
  'quads': 'Quadrizeps',
  'serratus anterior': 'Sägemuskel',
  'spine': 'Rückenstrecker',
  'traps': 'Trapez',
  'triceps': 'Trizeps',
  'upper back': 'Oberer Rücken',
  'body weight': 'Körpergewicht',
  'barbell': 'Langhantel',
  'dumbbell': 'Kurzhantel',
  'cable': 'Kabelzug',
  'leverage machine': 'Maschine',
  'kettlebell': 'Kettlebell',
  'band': 'Band',
  'resistance band': 'Band',
  'smith machine': 'Multipresse',
  'ez barbell': 'SZ-Stange',
  'olympic barbell': 'Langhantel',
  'medicine ball': 'Medizinball',
  'stability ball': 'Gymnastikball',
  'bosu ball': 'Bosu',
  'trap bar': 'Trap Bar',
  'weighted': 'Zusatzgewicht',
  'assisted': 'Partner',
  'sled machine': 'Beinpresse & Hackenschmidt',
  'roller': 'Faszienrolle',
  'wheel roller': 'Bauchroller',
  'rope': 'Seil',
  'hammer': 'Vorschlaghammer',
  'tire': 'Reifen',
  'upper body ergometer': 'Armergometer',
  'skierg machine': 'Ski-Ergometer',
  'stationary bike': 'Fahrradergometer',
  'elliptical machine': 'Crosstrainer',
  'stepmill machine': 'Stepper',
};

/// List subtitle of [e]: target muscle · equipment ("Brustmuskel · Multipresse").
String exerciseSubtitle(Exercise e, String lang) => '${term(e.target, lang)} · ${term(e.equipment, lang)}';

/// English labels where the database term is unclear.
const _enTerms = {
  'leverage machine': 'Machine',
  'sled machine': 'Leg press & hack sled',
  'weighted': 'Added weight',
  'skierg machine': 'Ski ergometer',
  'upper body ergometer': 'Arm ergometer',
  'cardiovascular system': 'Cardiovascular system',
  'delts': 'Shoulders',
  'pectorals': 'Chest',
  'spine': 'Lower back',
};

/// Translates body parts / muscles / equipment for the UI (German, else a cleaned-up
/// English label).
String term(String en, String lang) {
  if (en.isEmpty) return en;
  if (lang != 'de') return _enTerms[en] ?? en[0].toUpperCase() + en.substring(1);
  return _deTerms[en] ?? muscleNamesDe[en] ?? (en[0].toUpperCase() + en.substring(1));
}
