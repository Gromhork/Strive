import '../core/event_distances.dart';
import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import 'compliance.dart';
import 'event_spec.dart';

/// What holds a beginner's goal-directed build back.
enum ProgressionIssue {
  /// The long sessions were done, but clearly shorter than planned (< 80 % of the load).
  longSessionsShort,

  /// ≥ 2 long sessions of the last 3 weeks were not done.
  longSessionsMissed,

  /// ≥ 2 run/walk sessions were cut short (< 80 %) or felt hard (RPE ≥ 6) – Couch-to-5K only
  /// progresses at RPE ≤ 5 without pain (docs/training-science.md §1.10).
  runWalkNotAchieved,

  /// ≥ 2 long / run/walk sessions at RPE ≥ 8.
  highEffort,

  /// The run/walk stage or the long session has been held (repeated or reduced below the plan's
  /// ladder) for ≥ [stageHeldWeeks] weeks in a row.
  stageHeld,
}

/// Weeks in a row a held stage / reduced long session counts as an issue ([ProgressionIssue.stageHeld]).
const stageHeldWeeks = 3;

/// Weeks before race day within which a held stage ([ProgressionCheck.atRisk]) puts the goal at risk.
const stageHeldRiskWeeks = 12;

/// What the athlete can do about it (offered with the warning).
enum ProgressionOption {
  /// Repeat the current week's stage instead of moving up.
  repeatWeek,

  /// Pick a later race date (more weeks for the build-up).
  laterRace,

  /// Switch to a shorter distance ([EventSpec.shorter]).
  shorterDistance,

  /// Plan the race itself as run/walk ([EventSpec.runWalkFinish], or Galloway run/walk for a
  /// half marathon).
  runWalkRace,
}

/// Beginner-specific progression check (run/walk ladder, growing long session, swim novice
/// ladder): does the athlete keep up with the build-up the goal needs? Feeds [GoalForecast]
/// (reason `progressionBehind`, status ≥ slightly behind / at risk) and the home card's warning.
class ProgressionCheck {
  const ProgressionCheck({
    required this.behind,
    this.issues = const [],
    this.options = const [],
    this.longAchievedShare,
    this.plannedLong = 0,
    this.doneLong = 0,
    this.heldWeeks = 0,
    this.weeksLeft,
  });

  /// The athlete falls behind the build-up (any issue).
  final bool behind;
  final List<ProgressionIssue> issues;

  /// Empty when not [behind].
  final List<ProgressionOption> options;

  /// Achieved / planned long-session load of the last 3 weeks (each session ≤ 100 %, weighted by
  /// the planned minutes); null without planned long sessions in the window.
  final double? longAchievedShare;

  /// Planned long sessions in the window and how many of them were done.
  final int plannedLong, doneLong;

  /// Consecutive weeks (up to the current one) in which a run/walk stage or long session was held:
  /// repeated by the recalibration ('recalStage') or planned ≥ 5 % below the plan's original.
  final int heldWeeks;

  /// Whole weeks until race day.
  final int? weeksLeft;

  /// The build-up stalls with too little time left: a stage held for ≥ [stageHeldWeeks] weeks with
  /// ≤ [stageHeldRiskWeeks] weeks to go – the goal is at risk (the ladder can't catch up any more).
  bool get atRisk => heldWeeks >= stageHeldWeeks && (weeksLeft ?? 99) <= stageHeldRiskWeeks;

  /// Behind because of the long sessions (short or missed) – what moves the forecast to at risk.
  bool get longBehind => issues.contains(ProgressionIssue.longSessionsShort) || issues.contains(ProgressionIssue.longSessionsMissed);
}

/// Days the check looks back (3 weeks before today).
const progressionWindowDays = 21;

/// Run/walk session: a run whose first step is a walk (the generator's "Run/walk N × M min").
bool isRunWalk(PlannedWorkout x) => x.sport == Sport.run && x.steps.isNotEmpty && x.steps.first.zone == 'walk';

/// [w] with its run/walk title ("Run/walk 8 × 1 min") matching its steps after an adjustment changed
/// the repeats or their length (review I13: sessions trimmed to 25' still read "2 × 10 min").
PlannedWorkout retitledRunWalk(PlannedWorkout w) {
  if (!isRunWalk(w)) return w;
  final work = w.steps.where((s) => s.isWork && s.zone != 'walk').toList();
  final m = RegExp(r'(\d+) × (\d+) min').firstMatch(w.title);
  if (work.isEmpty || m == null) return w;
  final sec = work.first.durationSec ?? 0;
  if (sec <= 0 || sec % 60 != 0) return w;
  final title = w.title.replaceRange(m.start, m.end, '${work.length} × ${sec ~/ 60} min');
  return title == w.title ? w : PlannedWorkout.fromMap(w.id, {...w.toMap(), 'title': title});
}

/// [w] with the "N × length" of its title (intervals, cruise intervals, goal-pace sets, hill reps, ride and swim
/// sets – "Intervalle 4 × 800 m", "Schwelle 3 × 10 min") matching its work steps after an adjustment dropped repeats
/// or shortened them (review 2026-11 adapt-4: "4 × 800 m" with 450 m repeats); run/walk via [retitledRunWalk].
/// [decimal]: the decimal separator of a km length when the title has none yet (',' in German; default: from the
/// title – the German km titles are "Zieltempo …" and "Cruise-Intervalle …").
PlannedWorkout retitledRepeats(PlannedWorkout w, {String? decimal}) {
  if (isRunWalk(w)) return retitledRunWalk(w);
  final m = RegExp(r'(\d+) × (\d+(?:[.,]\d+)?) (m|km|min|s)\b').firstMatch(w.title);
  final work = [for (final i in mainSetIndices(w.steps)) w.steps[i]];
  if (m == null || work.isEmpty) return w;
  final f = work.first;
  final sep =
      m.group(2)!.contains(',')
          ? ','
          : (m.group(2)!.contains('.') ? '.' : (decimal ?? (w.title.contains('Intervalle') || w.title.contains('Zieltempo') ? ',' : '.')));
  final String len;
  switch (m.group(3)) {
    case 'm' when f.distanceM != null:
      len = '${f.distanceM!.round()}';
    case 'km' when f.distanceM != null:
      final km = f.distanceM! / 1000;
      len = (km - km.roundToDouble()).abs() < 0.05 ? '${km.round()}' : km.toStringAsFixed(1).replaceAll('.', sep);
    case 'min' when f.durationSec != null && f.durationSec! % 60 == 0:
      len = '${f.durationSec! ~/ 60}';
    case 's' when f.durationSec != null:
      len = '${f.durationSec}';
    default:
      return w;
  }
  final title = w.title.replaceRange(m.start, m.end, '${work.length} × $len ${m.group(3)}');
  return title == w.title ? w : PlannedWorkout.fromMap(w.id, {...w.toMap(), 'title': title});
}

/// Indices of the main set's work steps of [steps] – the repeats a "N × length" title counts: the work steps of
/// the zone with the most volume (a tie: the later one), so a swim's drills before its CSS set or its "2 × 400 m"
/// build-up are not part of it. (Volume: metres, a timed step at ~3 m/s.)
List<int> mainSetIndices(List<WorkoutStep> steps) {
  final v = <String?, double>{};
  for (final s in steps) {
    if (s.isWork) v[s.zone] = (v[s.zone] ?? 0) + (s.distanceM ?? 0) + 3 * (s.durationSec ?? 0);
  }
  String? zone;
  for (final s in steps) {
    if (s.isWork && (zone == null || v[s.zone]! >= v[zone]!)) zone = s.zone;
  }
  return [
    for (var i = 0; i < steps.length; i++)
      if (steps[i].isWork && steps[i].zone == zone) i,
  ];
}

/// Swim novice ladder session: a swim with continuous endurance (EN) work steps.
bool _isSwimLadder(PlannedWorkout x) => x.sport == Sport.swim && x.steps.any((s) => s.isWork && s.zone == 'EN');

/// The long session of the week (run long run / run/walk long session; also long rides of a
/// triathlon beginner).
bool _isLong(PlannedWorkout x) => x.intensity == 'long' && x.sport != Sport.gym && x.sport != Sport.swim;

/// A reduction that is deliberate rest (a recovery week the recalibration proposed), not a lag.
bool _restMark(AutoAdjustment o) => o.reason.startsWith('recal') && o.reason.endsWith('Recovery');

/// The session as the plan's ladder had it: an automatic / recalibration change keeps the original in
/// its [AutoAdjustment] record – a repeated reduction must not hide a lag (the share of a session
/// cut to 80 % and done at 80 % is 80 %, not 100 %). Recovery weeks count as planned.
PlannedWorkout _original(PlannedWorkout x) {
  final o = x.auto;
  if (o == null || _restMark(o)) return x;
  return PlannedWorkout.fromMap(x.id, {
    ...x.toMap(),
    'durationMin': o.durationMin,
    'distanceKm': o.distanceKm ?? x.distanceKm,
    if (o.steps.isNotEmpty) 'steps': [for (final st in o.steps) st.toMap()],
  });
}

/// Done / planned of one session: duration for run/walk sessions and plans without a distance,
/// otherwise distance (when the session recorded one). Swims: distance vs the planned metres.
/// [x] is compared as planned right now – pass [_original] for the ladder's amount.
double? _ratio(PlannedWorkout x, Session s) {
  if (x.sport == Sport.swim) {
    final m = (x.distanceKm ?? 0) > 0 ? x.distanceKm! * 1000 : x.steps.fold<double>(0, (t, st) => t + (st.distanceM ?? 0));
    if (m > 0 && s.distanceM > 0) return s.distanceM / m;
  } else if (!isRunWalk(x)) {
    final km = x.distanceKm ?? 0;
    if (km > 0 && s.distanceM > 0) return s.distanceM / (km * 1000);
  }
  if (x.durationMin > 0) return s.durationSec / (x.durationMin * 60);
  return null;
}

/// Planned amount of [x] in its ladder unit: distance for long runs / rides with one, else minutes.
double _amountOf(PlannedWorkout x) => !isRunWalk(x) && (x.distanceKm ?? 0) > 0 ? x.distanceKm! : x.durationMin.toDouble();

/// Held in its week: repeated by the recalibration (run/walk stage) or ≥ 5 % below the original.
bool _held(PlannedWorkout x) {
  final o = x.auto;
  if (o == null || _restMark(o) || x.status == 'skipped') return false;
  if (o.reason.startsWith('recalStage')) return true;
  if (x.phase == 'taper' || x.phase == 'recovery') return false;
  final orig = _amountOf(_original(x));
  return orig > 0 && _amountOf(x) < 0.95 * orig;
}

/// The beginner progression check of the last [progressionWindowDays] days (planned workouts
/// dated before today). Null without an upcoming event, when the athlete is no "progression
/// athlete" (level beginner, run/walk sessions in the plan, or a swim novice –
/// `canSwim400 == false`) or with fewer than 2 relevant planned sessions in the window.
///
/// Rules (docs/training-science.md §1.10, §1.12):
/// * long sessions: achieved share = Σ min(done, planned) / Σ planned, weighted by planned
///   minutes (done = linked session's distance, or its duration for run/walk / plans without
///   a distance; marked done without data = 100 %); missed = no linked session.
/// * behind when ≥ 2 planned long sessions and (share < 0.8 or ≥ 2 missed);
/// * run/walk not achieved: ≥ 2 done run/walk sessions at < 80 % of the planned duration or
///   RPE > 5 (Couch-to-5K: progress only at RPE ≤ 5 without pain; the recalibration then holds
///   the stage – `RecalReason.repeatStage`);
/// * high effort: ≥ 2 done long / run/walk sessions at RPE ≥ 8;
/// * stage held: a run/walk stage repeated or a long session planned ≥ 5 % below the plan's original
///   for ≥ [stageHeldWeeks] weeks in a row; with ≤ [stageHeldRiskWeeks] weeks left the goal is at risk
///   ([ProgressionCheck.atRisk]);
/// * long sessions are measured against the plan's original amount (the [AutoAdjustment] record), so
///   repeated reductions don't hide a lag;
/// * swim novices: the ladder swims (EN work steps) count like long sessions (distance done vs
///   planned).
/// Options when behind: repeat week, later race, a shorter distance (when the event has one),
/// a run/walk race (short distances, or Galloway run/walk for a half marathon).
ProgressionCheck? progressionCheck(
  UserProfile p, {
  required List<PlannedWorkout> plans,
  required List<Session> sessions,
  required DateTime now,
}) {
  final a = p.athlete;
  final ev = a.eventDistance;
  if (a.eventDate == null || ev == null) return null;
  final today = dayOnly(now);
  if (dayOnly(a.eventDate!).isBefore(today)) return null;
  // Calendar days (a Duration would shift by an hour across a DST change).
  final from = DateTime(today.year, today.month, today.day - progressionWindowDays);
  final window = plans.where((x) => !dayOnly(x.date).isBefore(from) && dayOnly(x.date).isBefore(today) && x.intensity != 'race').toList();

  final swimNovice = !a.canSwim400;
  final hasRunWalk = window.any(isRunWalk);
  if (p.level != 'beginner' && !hasRunWalk && !swimNovice) return null;

  final longs = window.where((x) => _isLong(x) || (swimNovice && _isSwimLadder(x))).toList();
  final runWalks = window.where(isRunWalk).toList();
  final relevant = {...longs, ...runWalks};
  if (relevant.length < 2) return null;

  final linked = linkPlanSessions(plans, sessions, profile: p);

  // ── Long sessions
  var planned = 0.0, achieved = 0.0, doneAchieved = 0.0, donePlanned = 0.0;
  var missed = 0, done = 0;
  for (final x0 in longs) {
    // Against the plan's ladder, not the already-reduced session.
    final x = _original(x0);
    final w = x.durationMin > 0 ? x.durationMin.toDouble() : 1.0;
    planned += w;
    final s = linked[x.id];
    // (A start too short to count, < 10 % of the plan, is a missed session too.)
    if (!planCompleted(x0, linked, profile: p)) {
      missed++;
      continue;
    }
    done++;
    final r = s == null ? 1.0 : (_ratio(x, s) ?? 1.0).clamp(0.0, 1.0);
    achieved += w * r;
    doneAchieved += w * r;
    donePlanned += w;
  }
  final share = longs.isEmpty ? null : achieved / planned;
  final longBehind = longs.length >= 2 && (share! < 0.8 || missed >= 2);

  // ── Run/walk sessions and effort
  var rwShort = 0, hard = 0;
  for (final x in relevant) {
    final s = linked[x.id];
    if (s == null) continue;
    final rpe = s.rpe ?? 0;
    if (rpe >= 8) hard++;
    if (isRunWalk(x)) {
      final r = _ratio(x, s);
      if ((r != null && r < 0.8) || rpe >= 6) rwShort++;
    }
  }
  final runWalkNotAchieved = rwShort >= 2;
  final highEffort = hard >= 2;

  // ── Stage held: consecutive weeks (ending this week or the last) with a run/walk stage repeated or
  // a long session planned below the ladder.
  final heldIn = <DateTime>{
    for (final x in plans)
      if ((isRunWalk(x) || _isLong(x)) && _held(x) && !dayOnly(x.date).isAfter(addDays(today, 6))) startOfWeek(x.date),
  };
  var held = 0;
  var wk = startOfWeek(today);
  if (!heldIn.contains(wk)) wk = addDays(wk, -7);
  while (heldIn.contains(wk)) {
    held++;
    wk = addDays(wk, -7);
  }
  final weeksLeft = daysBetween(today, dayOnly(a.eventDate!)) ~/ 7;

  final issues = <ProgressionIssue>[];
  if (longBehind) {
    final missedIssue = missed >= 2;
    final shortIssue = donePlanned > 0 && doneAchieved / donePlanned < 0.8;
    if (missedIssue) issues.add(ProgressionIssue.longSessionsMissed);
    if (shortIssue) issues.add(ProgressionIssue.longSessionsShort);
    // One miss plus slightly short sessions: name the bigger cause.
    if (!missedIssue && !shortIssue) issues.add(missed > 0 ? ProgressionIssue.longSessionsMissed : ProgressionIssue.longSessionsShort);
  }
  if (runWalkNotAchieved) issues.add(ProgressionIssue.runWalkNotAchieved);
  if (highEffort) issues.add(ProgressionIssue.highEffort);
  if (held >= stageHeldWeeks) issues.add(ProgressionIssue.stageHeld);
  final behind = issues.isNotEmpty;

  final spec = EventSpec.of(ev);
  final runs = spec == null || (spec.sport != EventSport.swim && spec.sport != EventSport.ride);
  final options = <ProgressionOption>[
    if (behind) ...[
      ProgressionOption.repeatWeek,
      ProgressionOption.laterRace,
      if (spec != null && spec.shorter.isNotEmpty) ProgressionOption.shorterDistance,
      if (runs && ((spec?.runWalkFinish ?? false) || ev == 'hm')) ProgressionOption.runWalkRace,
    ],
  ];

  return ProgressionCheck(
    behind: behind,
    issues: issues,
    options: options,
    longAchievedShare: share,
    plannedLong: longs.length,
    doneLong: done,
    heldWeeks: held,
    weeksLeft: weeksLeft,
  );
}
