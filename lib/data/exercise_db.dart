import 'dart:convert';

import 'package:flutter/services.dart';

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

  List<Exercise> search(String q, {String? bodyPart, String? equipment}) {
    final terms = q.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final res =
        all.where((e) {
          if (bodyPart != null && e.bodyPart != bodyPart) return false;
          if (equipment != null && e.equipment != equipment) return false;
          if (terms.isEmpty) return true;
          final hay = '${e.name} ${e.target} ${e.bodyPart} ${e.equipment} ${germanAlias(e)}';
          return terms.every(hay.contains);
        }).toList();
    if (terms.isNotEmpty) {
      // Rank: names starting with the query first, then shorter names.
      final q0 = q.toLowerCase();
      res.sort((a, b) {
        final sa = a.name.startsWith(q0) ? 0 : (a.name.contains(q0) ? 1 : 2);
        final sb = b.name.startsWith(q0) ? 0 : (b.name.contains(q0) ? 1 : 2);
        return sa != sb ? sa.compareTo(sb) : a.name.length.compareTo(b.name.length);
      });
    }
    return res;
  }
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
  if (lang != 'de') return en[0].toUpperCase() + en.substring(1);
  return _deTerms[en] ?? (en[0].toUpperCase() + en.substring(1));
}
