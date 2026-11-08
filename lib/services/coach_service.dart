import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'insights.dart';

/// AI coach backed by Gemini through Firebase AI Logic.
class CoachService {
  static const model = 'gemini-3.5-flash-lite';

  CoachService({required this.profile, required this.sessions, required this.plans, required this.lang});
  final UserProfile profile;
  final List<Session> sessions;
  final List<PlannedWorkout> plans;
  final String lang;

  ChatSession? _chat;

  String _context() {
    final p = profile;
    final now = DateTime.now();
    final recent = sessions.where((s) => now.difference(s.start).inDays < 28).toList();
    final bySport = <Sport, List<Session>>{};
    for (final s in recent) {
      bySport.putIfAbsent(s.sport, () => []).add(s);
    }
    final summary = bySport.entries
        .map((e) {
          final min = e.value.fold<int>(0, (a, s) => a + s.minutes);
          final km = e.value.fold<double>(0, (a, s) => a + s.distanceM) / 1000;
          final vol = e.value.fold<double>(0, (a, s) => a + s.volume);
          return '- ${e.key.name}: ${e.value.length} sessions, $min min'
              '${km > 0 ? ', ${km.toStringAsFixed(1)} km' : ''}${vol > 0 ? ', ${vol.round()} kg volume' : ''}';
        })
        .join('\n');
    final rec = RecoveryInfo.compute(sessions);
    final prs = exerciseRecords(sessions).values.toList()..sort((a, b) => b.bestE1rm.compareTo(a.bestE1rm));
    final upcoming = plans
        .where((x) => x.status == 'planned' && !x.date.isBefore(dayOnly(now)))
        .take(7)
        .map((x) => '- ${dayKey(x.date)}: ${x.sport.name} "${x.title}" ${x.durationMin} min')
        .join('\n');
    return '''
Athlete profile:
- name: ${p.name}, age: ${p.age ?? 'unknown'}, gender: ${p.gender}, height ${p.heightCm} cm, weight ${p.weightKg} kg${p.fatPct != null ? ', body fat ${p.fatPct}%' : ''}
- level: ${p.level}, focus: ${p.focus.name}, goals: ${p.goals.join(', ')}
- training days per week: ${p.weeklyTarget}
Last 28 days:
${summary.isEmpty ? '- no sessions logged yet' : summary}
Acute:chronic workload ratio: ${rec.ratio.toStringAsFixed(2)} (${rec.readiness.name}), consecutive training days: ${rec.daysSinceRest}
Top strength estimates (e1RM): ${prs.take(5).map((r) => '${r.name} ${r.bestE1rm.round()} kg').join('; ')}
Upcoming plan:
${upcoming.isEmpty ? '- nothing planned' : upcoming}
Today: ${dayKey(now)}''';
  }

  String get _system => '''
You are "Strive Coach", an evidence-based personal coach for strength training, running, cycling and swimming inside the Strive app.
- Base advice on the current scientific consensus (e.g. ACSM guidelines, progressive overload, 80/20 polarized endurance training, sleep and protein recommendations). Mention the underlying principle briefly when helpful.
- Personalise using the athlete data below. Be concise, practical and motivating. Use short paragraphs or bullet points, no tables.
- You are not a doctor: for pain, injuries or medical conditions recommend seeing a professional.
- Answer in ${lang == 'de' ? 'German (du-form)' : 'English'}.

${_context()}''';

  GenerativeModel _model({GenerationConfig? config}) =>
      FirebaseAI.googleAI().generativeModel(model: model, systemInstruction: Content.system(_system), generationConfig: config);

  Stream<String> ask(String message) async* {
    _chat ??= _model().startChat();
    await for (final chunk in _chat!.sendMessageStream(Content.text(message))) {
      final t = chunk.text;
      if (t != null) yield t;
    }
  }

  /// Asks Gemini for a structured plan. Returns raw items; caller maps to [PlannedWorkout].
  Future<List<Map<String, dynamic>>> generatePlan({required int weeks, required DateTime start, String wish = ''}) async {
    final schema = Schema.array(
      items: Schema.object(
        properties: {
          'dayOffset': Schema.integer(description: 'days after start date (0 = start date)'),
          'sport': Schema.enumString(enumValues: ['gym', 'run', 'ride', 'swim']),
          'title': Schema.string(),
          'description': Schema.string(description: 'concrete session content, e.g. sets/intervals/paces'),
          'durationMin': Schema.integer(),
          'distanceKm': Schema.number(description: '0 for gym'),
          'intensity': Schema.enumString(enumValues: ['easy', 'moderate', 'tempo', 'intervals', 'long', 'technique']),
        },
      ),
    );
    final m = _model(config: GenerationConfig(responseMimeType: 'application/json', responseSchema: schema));
    final days = profile.trainingDays.map((d) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1]).join(', ');
    final prompt = '''
Create a periodised $weeks-week training plan starting ${dayKey(start)} (a ${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][start.weekday - 1]}).
Train only on: $days${profile.longDay != null ? '; long session on ${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][profile.longDay! - 1]}' : ''}.
Apply progressive overload and a deload in week 4 if the plan is long enough.
For gym sessions use one of these titles when fitting: Push, Pull, Legs, Upper, Lower, Full Body A, Full Body B.
${wish.isNotEmpty ? 'Athlete wish: $wish' : ''}
Titles and descriptions in ${lang == 'de' ? 'German' : 'English'}.''';
    final res = await m.generateContent([Content.text(prompt)]);
    final list = jsonDecode(res.text ?? '[]') as List;
    return list.cast<Map<String, dynamic>>();
  }
}
