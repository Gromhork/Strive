import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../core/event_distances.dart';
import '../core/format.dart';
import '../core/sport.dart';
import '../data/exercise_names_de.dart';
import '../data/models.dart';
import 'app_check.dart';
import 'goal_alignment.dart';
import 'goal_forecast.dart';
import 'insights.dart';
import 'zones.dart';

/// AI coach backed by Gemini through Firebase AI Logic.
class CoachService {
  static const model = 'gemini-3.5-flash-lite';

  CoachService({required this.profile, required this.sessions, required this.plans, required this.lang, this.goals = const []});
  final UserProfile profile;
  final List<Session> sessions;
  final List<PlannedWorkout> plans;
  final String lang;

  /// The athlete's saved goals (Goals page) – the coach must name the real goal.
  final List<Goal> goals;

  /// Days of history the load ratio (ACWR) and fitness/fatigue (CTL/ATL) need before
  /// they mean anything – the same rule as [RecoveryInfo.compute] / the Home card.
  static const baselineDays = 21;

  ChatSession? _chat;

  /// The training history is long enough for ACWR / fitness / fatigue numbers.
  static bool baselineReady(List<Session> sessions, DateTime now) {
    if (sessions.isEmpty) return false;
    final oldest = sessions.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    return daysBetween(oldest, now) >= baselineDays;
  }

  /// The main goal in plain words: the event (sport, distance, date, target, forecast)
  /// first, then saved goals; profile interests only as a hint.
  String _goalText(DateTime now) {
    final p = profile;
    final a = p.athlete;
    final lines = <String>[];
    final ev = eventDistanceOf(a.eventDistance);
    if (a.eventDate != null && !a.eventDate!.isBefore(dayOnly(now))) {
      final sport = ev?.sport.name ?? p.focus.name;
      final dist =
          ev == null
              ? (a.eventDistance ?? 'unknown distance')
              : '${a.eventDistance} (${ev.legs.isNotEmpty ? '${ev.legs.join(' / ')} km' : '${ev.km} km'})';
      lines.add(
        '- MAIN GOAL: $sport race${a.eventName == null ? '' : ' "${a.eventName}"'}, distance $dist, on ${dayKey(a.eventDate!)} '
        '(${daysBetween(dayOnly(now), a.eventDate!)} days away)${a.targetTimeSec != null ? ', target time ${clock(a.targetTimeSec!)}' : ', no target time'}. '
        'This is an endurance goal - never call it a strength goal.',
      );
      GoalForecast? f;
      try {
        f = GoalForecast.of(p, plans: plans, sessions: sessions, now: now);
      } catch (_) {
        f = null;
      }
      if (f != null) {
        lines.add(
          f.early
              ? '- goal forecast: too early to judge (not enough completed training yet) - do not predict a race time.'
              : '- goal forecast: ${f.status.name}${f.raceDaySec != null ? ', predicted race time ~${clock(f.raceDaySec!)}' : ''}'
                  '${f.reasons.isEmpty ? '' : ' (reasons: ${f.reasons.map((r) => r.name).join(', ')})'}',
        );
      }
    } else {
      // No race in the plan settings – but a saved race goal is still THE goal (never a
      // "hybrid goal" just because the focus says hybrid).
      final race = GoalAlignment.of(p, goals, plans, dayOnly(now));
      if (race != null) {
        final g = race.goal;
        final ev = eventDistanceOf(race.raceKey);
        lines.add(
          '- MAIN GOAL: ${ev?.sport.name ?? g.sport?.name ?? 'endurance'} race "${g.title}"'
          '${race.raceKey == null ? '' : ', distance ${race.raceKey}'} on ${dayKey(g.deadline!)} '
          '(${daysBetween(dayOnly(now), g.deadline!)} days away). The training focus setting is "${p.focus.name}".',
        );
      } else {
        lines.add('- main training focus: ${p.focus.name} (no race planned)');
      }
    }
    final mismatch = GoalAlignment.of(p, goals, plans, dayOnly(now))?.coachText(lang: lang) ?? '';
    if (mismatch.isNotEmpty) lines.add('- $mismatch');
    for (final g in goals.take(5)) {
      lines.add(
        '- saved goal: ${g.type.name}${g.sport == null ? '' : ' (${g.sport!.name})'} "${g.title}", target ${g.target}'
        '${g.deadline == null ? '' : ' by ${dayKey(g.deadline!)}'}',
      );
    }
    if (p.focus.sports.contains(Sport.gym)) lines.add('- gym goal: ${a.gymGoal}');
    if (p.goals.isNotEmpty) lines.add('- general interests (secondary): ${p.goals.join(', ')}');
    // Plan week / phase from the stored plan frame.
    final phase = plans.where((x) => !x.date.isBefore(dayOnly(now))).firstOrNull?.phase;
    final start = a.planStart;
    final len = a.planLength ?? 0;
    final week = start == null || len <= 0 ? null : (daysBetween(start, dayOnly(now)) ~/ 7 + 1).clamp(1, len);
    lines.add('- plan: ${week == null ? 'no week info' : 'week $week of $len'}, current phase: ${phase ?? 'none'}');
    return lines.join('\n');
  }

  @visibleForTesting
  String contextText({DateTime? now}) => _context(now ?? DateTime.now());

  @visibleForTesting
  String systemText({DateTime? now}) => _systemFor(now ?? DateTime.now());

  String _context(DateTime now) {
    final p = profile;
    final recent = sessions.where((s) => now.difference(s.start).inDays < 28).toList(); // time span
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
    final ready = baselineReady(sessions, now);
    // Lifts with an e1RM only (holds and partial-bodyweight exercises have no strength estimate).
    final prs = exerciseRecords(sessions).values.where((r) => r.bestE1rm > 0).toList()..sort((a, b) => b.bestE1rm.compareTo(a.bestE1rm));
    // Every workout with its weekday, kind and key flag (audit UX-6: from bare ISO dates the model worked out
    // the weekdays itself and put Saturday's long run "on Friday"), the current week in full (done ones too),
    // then the planned ones up to the end of next week.
    final today = dayOnly(now);
    final monday = startOfWeek(today);
    final sorted = [...plans]..sort((x, y) => x.date.compareTo(y.date));
    final thisWeek = sorted.where((x) => !x.date.isBefore(monday) && x.date.isBefore(addDays(monday, 7)) && x.status != 'skipped').toList();
    final upcoming = sorted
        .where((x) => x.status == 'planned' && !x.date.isBefore(addDays(monday, 7)) && x.date.isBefore(addDays(monday, 14)))
        .map(_planLine)
        .join('\n');
    final weekDays = {for (final x in thisWeek) _weekday(x.date)};
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
            : '${a.eventDistance ?? '?'} on ${dayKey(a.eventDate!)} (${daysBetween(dayOnly(now), a.eventDate!)} days away)'
                '${a.targetTimeSec != null ? ', target ${clock(a.targetTimeSec!)}' : ''}';
    final fit = ready ? fitnessSeries(sessions) : null;
    final form =
        fit == null || fit.isEmpty
            ? 'no data'
            : 'fitness ${fit.last.fitness.toStringAsFixed(0)}, fatigue ${fit.last.fatigue.toStringAsFixed(0)}, form ${fit.last.form.toStringAsFixed(0)}';
    // Before 3 weeks of history the load numbers are meaningless - the app itself says
    // "building your baseline", so the coach must not quote a ratio or call the base long-standing.
    final load =
        ready
            ? 'Training load (7 days vs. 28-day average): ratio ${rec.ratio.toStringAsFixed(2)} (${rec.readiness.name}); fitness/form: $form'
            : 'BASELINE NOT READY: less than $baselineDays days of training history. Do NOT quote any load ratio, fitness, fatigue or form numbers '
                'and do not describe the training base as long-standing; say that you are still getting to know the athlete\'s baseline.';
    final past = plans.where((x) => !x.date.isBefore(addDays(dayOnly(now), -14)) && x.date.isBefore(dayOnly(now)));
    final missed = past.where((x) => x.status == 'planned').map((x) => '${dayKey(x.date)} ${x.sport.name} "${x.title}"').take(6).join('; ');
    final done = past.where((x) => x.status == 'done').length;
    return '''
Athlete profile:
- name: ${p.name}, age: ${p.age ?? 'unknown'}, gender: ${p.gender}, height ${p.heightCm} cm, weight ${p.weightKg} kg${p.fatPct != null ? ', body fat ${p.fatPct}%' : ''}
- level: ${p.level}, training focus: ${p.focus.name}
- training days this week (from the plan): ${weekDays.length}${weekDays.isEmpty ? '' : ' (${weekDays.join(', ')})'}
Goal:
${_goalText(now)}
Last 28 days:
${summary.isEmpty ? '- no sessions logged yet' : summary}
$load
Consecutive training days: ${rec.daysSinceRest}
${prs.isEmpty ? '' : 'Top strength estimates (e1RM): ${prs.take(5).map((r) => '${exerciseName(r.exId, r.name, lang)} ${r.bestE1rm.round()} kg').join('; ')}\n'}Thresholds: $thresholds
Target event: $event
Plan adherence last 14 days: $done of ${past.length} planned workouts done${missed.isEmpty ? '' : '; missed: $missed'}
This week (Mon-Sun, as planned now - use these weekdays, never work them out from the dates):
${thisWeek.isEmpty ? '- nothing planned' : thisWeek.map(_planLine).join('\n')}
Next week:
${upcoming.isEmpty ? '- nothing planned' : upcoming}
Today: ${_weekday(today)} ${dayKey(today)}''';
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String _weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// "- Sat 2026-11-21: run "Langer Lauf" 73 min, 12.0 km (long, key)" – plus "done" for a done one.
  static String _planLine(PlannedWorkout x) =>
      '- ${_weekday(x.date)} ${dayKey(x.date)}: ${x.sport.name} "${x.title}" ${x.durationMin} min'
      '${(x.distanceKm ?? 0) > 0 ? ', ${x.distanceKm!.toStringAsFixed(1)} km' : ''}'
      ' (${[x.intensity, if (x.isKey) 'key', if (x.isDone) 'done'].join(', ')})';

  /// Abbreviations the app explains in its glossary (lib/widgets/term_info.dart) - the
  /// only ones the coach may use, each explained on first use.
  static const glossaryTerms = ['RPE', 'RIR', 'e1RM', 'VDOT', 'FTP', 'CSS', 'AMRAP'];

  String _systemFor(DateTime now) => '''
You are "Strive Coach", an evidence-based personal coach for strength training, running, cycling and swimming inside the Strive app.
- Base advice on the current scientific consensus (progressive overload, mostly easy endurance training, sleep and protein recommendations).
- Personalise using the athlete data below. The athlete's MAIN GOAL is stated there - refer to it correctly (sport, distance, date) and never invent a different goal.
- Keep answers SHORT: at most about 120 words, 2-4 short bullet points or short paragraphs, no tables, no headings.
- Use plain, everyday ${lang == 'de' ? 'German (du-form) - write like a friendly trainer, no English sports jargon' : 'English'}. No scientific jargon or study names (e.g. no "CNS", "ZNS", "interference effect", "ATL", "CTL", "TSB", "ACWR", "supercompensation").
- The only abbreviations allowed are the ones the app explains in its glossary: ${glossaryTerms.join(', ')}. Explain each one in a few words the first time you use it (e.g. ${lang == 'de' ? '"RPE (wie anstrengend, 1-10)"' : '"RPE (how hard, 1-10)"'}).
- You ARE the coach of this app: always speak in the first person (${lang == 'de' ? '"ich", e.g. "Ich lerne deine Grundlage noch kennen"' : '"I", e.g. "I\'m still getting to know your baseline"'}) and address the athlete directly. Never talk about the app or the coach in the third person (${lang == 'de' ? 'never "Deine App lernt …", "Der Plan von Strive …"' : 'never "Your app is learning …"'}).
- Never invent reasons for how the plan looks (e.g. "before we add more cycling"). Explain the plan only with facts from the data below; if the data does not say why, say that plainly. If the data reports a DATA MISMATCH, name it honestly and point to the fix it names.
- Never contradict the data: if the baseline is not ready, say you are still getting to know the athlete's baseline. Use the app's words ${lang == 'de' ? '"Einheit", "Schlüsseleinheit", "Entlastungswoche", "Plan überprüfen"' : '"session", "key session", "recovery week", "Review plan"'}.
- You are not a doctor: for pain, injuries or medical conditions recommend seeing a professional.
- Answer in ${lang == 'de' ? 'German (du-form)' : 'English'}.

${_context(now)}''';

  GenerativeModel _model() => striveAI().generativeModel(model: model, systemInstruction: Content.system(_systemFor(DateTime.now())));

  Stream<String> ask(String message) async* {
    _chat ??= _model().startChat();
    await for (final chunk in _chat!.sendMessageStream(Content.text(message))) {
      final t = chunk.text;
      if (t != null) yield t;
    }
  }
}
