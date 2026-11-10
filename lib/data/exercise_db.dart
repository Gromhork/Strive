import 'dart:convert';

import 'package:flutter/services.dart';

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

/// Offline exercise database (1300+ exercises, bundled as an asset).
class ExerciseDb {
  ExerciseDb(this.all) : _byId = {for (final e in all) e.id: e};
  final List<Exercise> all;
  final Map<String, Exercise> _byId;

  static Future<ExerciseDb> load() async {
    final raw = await rootBundle.loadString('assets/data/exercises.json');
    final list = (jsonDecode(raw) as List).map((e) => Exercise.fromJson(e)).toList()..sort((a, b) => a.name.compareTo(b.name));
    return ExerciseDb(list);
  }

  Exercise? byId(String id) => _byId[id];

  List<String> get bodyParts => all.map((e) => e.bodyPart).toSet().toList()..sort();
  List<String> get equipment => all.map((e) => e.equipment).toSet().toList()..sort();

  /// Search by German and English name, muscles and equipment. Ranking: exact name,
  /// name prefix, word prefix, then common exercises (curated / built-in programs)
  /// before the rest, shorter names first.
  List<Exercise> search(String q, {String? bodyPart, String? equipment, String lang = 'en'}) {
    final q0 = q.toLowerCase().trim();
    final terms = q0.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final res =
        all.where((e) {
          if (bodyPart != null && e.bodyPart != bodyPart) return false;
          if (equipment != null && e.equipment != equipment) return false;
          if (terms.isEmpty) return true;
          final hay =
              '${e.name} ${exerciseNamesDe[e.id] ?? ''} ${e.target} ${e.bodyPart} ${e.equipment} '
                      '${term(e.target, 'de')} ${term(e.bodyPart, 'de')} ${term(e.equipment, 'de')} ${germanAlias(e)}'
                  .toLowerCase();
          return terms.every(hay.contains);
        }).toList();
    String shown(Exercise e) => exerciseName(e.id, e.name, lang);
    if (terms.isNotEmpty) {
      final ranks = {for (final e in res) e.id: searchRank(e, q0)};
      int common(Exercise e) => commonExerciseIds.contains(e.id) ? 0 : 1;
      res.sort((a, b) {
        final c = ranks[a.id]!.compareTo(ranks[b.id]!);
        if (c != 0) return c;
        final k = common(a).compareTo(common(b));
        return k != 0 ? k : shown(a).length.compareTo(shown(b).length);
      });
    } else if (lang != 'en') {
      res.sort((a, b) => shown(a).toLowerCase().compareTo(shown(b).toLowerCase()));
    }
    return res;
  }
}

/// Rank of [e] for the lower-case query [q] (lower = better): 0 exact name, 1/2 name
/// prefix, 3/4 word prefix, 5/6 anything else – common exercises first in each group.
int searchRank(Exercise e, String q) {
  final names = [e.name, if (exerciseNamesDe[e.id] case final de?) de.toLowerCase()];
  final popular = exerciseNamesDe.containsKey(e.id);
  final bare = RegExp(r'\s*\(.*\)$');
  if (names.any((n) => n == q || n.replaceAll(bare, '') == q)) return 0;
  if (names.any((n) => n.startsWith(q))) return popular ? 1 : 2;
  if (names.any((n) => n.split(RegExp(r'[\s\-/(]+')).any((w) => w.startsWith(q)))) return popular ? 3 : 4;
  return popular ? 5 : 6;
}

/// German search aliases so "bankdrücken" or "kniebeuge" find the right lifts.
String germanAlias(Exercise e) {
  final n = e.name;
  final out = <String>[];
  if (n.contains('bench press')) out.add('bankdrücken');
  if (n.contains('squat')) out.add('kniebeuge');
  if (n.contains('deadlift')) out.add('kreuzheben');
  if (n.contains('row')) out.add('rudern');
  if (n.contains('pull-up') || n.contains('chin-up')) out.add('klimmzug');
  if (n.contains('push-up')) out.add('liegestütz');
  if (n.contains('curl')) out.add('bizeps');
  if (n.contains('pushdown') || n.contains('triceps')) out.add('trizeps');
  if (n.contains('shoulder press') || n.contains('military') || n.contains('overhead press')) out.add('schulterdrücken');
  if (n.contains('lateral raise')) out.add('seitheben');
  if (n.contains('lunge')) out.add('ausfallschritt');
  if (n.contains('calf')) out.add('waden');
  if (n.contains('leg press')) out.add('beinpresse');
  if (n.contains('pulldown')) out.add('latzug');
  if (n.contains('fly')) out.add('fliegende butterfly');
  if (n.contains('crunch') || n.contains('sit-up')) out.add('bauch');
  if (n.contains('plank')) out.add('unterarmstütz');
  if (n.contains('dip')) out.add('dips');
  return out.join(' ');
}

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
  'leverage machine': 'Hebelmaschine',
  'kettlebell': 'Kettlebell',
  'band': 'Band',
  'resistance band': 'Widerstandsband',
  'smith machine': 'Multipresse',
  'ez barbell': 'SZ-Stange',
  'olympic barbell': 'Olympiastange',
  'medicine ball': 'Medizinball',
  'stability ball': 'Gymnastikball',
  'trap bar': 'Trap Bar',
  'weighted': 'Mit Gewicht',
  'assisted': 'Unterstützt',
  'sled machine': 'Schlittenmaschine',
  'roller': 'Rolle',
  'wheel roller': 'Bauchroller',
  'rope': 'Seil',
};

/// Translates body parts / muscles / equipment for the German UI.
String term(String en, String lang) {
  if (en.isEmpty) return en;
  if (lang != 'de') return en[0].toUpperCase() + en.substring(1);
  return _deTerms[en] ?? muscleNamesDe[en] ?? (en[0].toUpperCase() + en.substring(1));
}
