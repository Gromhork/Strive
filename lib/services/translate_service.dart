import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_check.dart';
import 'coach_service.dart';

/// Translates exercise instructions with Gemini and caches the result locally,
/// so each exercise is translated only once per device.
class TranslateService {
  TranslateService(this.prefs);
  final SharedPreferences prefs;

  String _key(String id, String lang) => 'tr_${lang}_$id';

  List<String>? cached(String id, String lang) {
    final raw = prefs.getString(_key(id, lang));
    if (raw == null) return null;
    try {
      return List<String>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> instructions(String id, String name, List<String> steps, String lang) async {
    final c = cached(id, lang);
    if (c != null) return c;
    final model = striveAI().generativeModel(
      model: CoachService.model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(properties: {'name': Schema.string(), 'steps': Schema.array(items: Schema.string())}),
      ),
    );
    final target = lang == 'de' ? 'German (du-form, concise, gym terminology)' : lang;
    final res = await model.generateContent([
      Content.text(
        'Translate this exercise name and its numbered instructions to $target. '
        'Keep the number and order of steps. Return JSON {name, steps}.\n'
        'Name: $name\nSteps:\n${steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}',
      ),
    ]);
    final m = jsonDecode(res.text ?? '{}') as Map<String, dynamic>;
    final out = List<String>.from(m['steps'] ?? const []);
    if (out.isEmpty) return steps;
    prefs.setString(_key(id, lang), jsonEncode(out));
    if (m['name'] is String) prefs.setString('trn_${lang}_$id', m['name']);
    return out;
  }

  String? translatedName(String id, String lang) => prefs.getString('trn_${lang}_$id');
}
