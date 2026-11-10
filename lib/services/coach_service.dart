import 'package:firebase_ai/firebase_ai.dart';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'insights.dart';
import 'zones.dart';

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
    // Thresholds, event, fitness/form and adherence – so answers account for race timing,
    // current fatigue and what was actually done.
    final a = p.athlete;
    final vdot = Vdot.of(a);
    final css = SwimZones.fromTests(a.swim400Sec, a.swim200Sec);
    final pz = vdot == null ? null : PaceZones(vdot);
    final thresholds = [
      if (vdot != null)
        'VDOT ${vdot.toStringAsFixed(1)} (easy ${fmtPace(pz!.easyFast)}–${fmtPace(pz.easySlow)}/km, threshold ${fmtPace(pz.threshold)}/km)',
      if (a.ftp != null) 'FTP ${a.ftp} W (${(a.ftp! / p.weightKg).toStringAsFixed(1)} W/kg)',
      if (css != null) 'CSS ${fmtPace(css)}/100 m',
      'HRmax ${p.estimatedMaxHr}${a.restHr != null ? ', resting HR ${a.restHr}' : ''}',
      if (a.oneRm.isNotEmpty) '1RM ${a.oneRm.entries.map((e) => '${e.key} ${e.value.round()} kg').join(', ')}',
      if (a.limitations.isNotEmpty) 'limitations: ${a.limitations.join(', ')}',
    ].join('; ');
    final event =
        a.eventDate == null
            ? 'none'
            : '${a.eventDistance ?? '?'} on ${dayKey(a.eventDate!)} (${a.eventDate!.difference(dayOnly(now)).inDays} days away)'
                '${a.targetTimeSec != null ? ', target ${clock(a.targetTimeSec!)}' : ''}';
    final fit = fitnessSeries(sessions);
    final form =
        fit.isEmpty
            ? 'no data'
            : 'fitness (CTL) ${fit.last.fitness.toStringAsFixed(0)}, fatigue (ATL) ${fit.last.fatigue.toStringAsFixed(0)}, form (TSB) ${fit.last.form.toStringAsFixed(0)}';
    final past = plans.where((x) => !x.date.isBefore(dayOnly(now).subtract(const Duration(days: 14))) && x.date.isBefore(dayOnly(now)));
    final missed = past.where((x) => x.status == 'planned').map((x) => '${dayKey(x.date)} ${x.sport.name} "${x.title}"').take(6).join('; ');
    final done = past.where((x) => x.status == 'done').length;
    final phase = plans.where((x) => !x.date.isBefore(dayOnly(now))).firstOrNull?.phase;
    return '''
Athlete profile:
- name: ${p.name}, age: ${p.age ?? 'unknown'}, gender: ${p.gender}, height ${p.heightCm} cm, weight ${p.weightKg} kg${p.fatPct != null ? ', body fat ${p.fatPct}%' : ''}
- level: ${p.level}, focus: ${p.focus.name}, goals: ${p.goals.join(', ')}
- training days per week: ${p.weeklyTarget}
Last 28 days:
${summary.isEmpty ? '- no sessions logged yet' : summary}
Acute:chronic workload ratio: ${rec.ratio.toStringAsFixed(2)} (${rec.readiness.name}), consecutive training days: ${rec.daysSinceRest}
Top strength estimates (e1RM): ${prs.take(5).map((r) => '${r.name} ${r.bestE1rm.round()} kg').join('; ')}
Thresholds: $thresholds
Target event: $event
Fitness/form (Banister): $form
Plan adherence last 14 days: $done of ${past.length} planned workouts done${missed.isEmpty ? '' : '; missed: $missed'}
Current plan phase: ${phase ?? 'none'}
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

  GenerativeModel _model() => FirebaseAI.googleAI().generativeModel(model: model, systemInstruction: Content.system(_system));

  Stream<String> ask(String message) async* {
    _chat ??= _model().startChat();
    await for (final chunk in _chat!.sendMessageStream(Content.text(message))) {
      final t = chunk.text;
      if (t != null) yield t;
    }
  }
}
