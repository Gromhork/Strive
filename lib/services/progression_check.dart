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
}

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
  final title = w.title.replaceRange(m.start, m.end, '${work.length} × ${sec ~/ 60} min');
  return title == w.title ? w : PlannedWorkout.fromMap(w.id, {...w.toMap(), 'title': title});
}

/// Swim novice ladder session: a swim with continuous endurance (EN) work steps.
bool _isSwimLadder(PlannedWorkout x) => x.sport == Sport.swim && x.steps.any((s) => s.isWork && s.zone == 'EN');

/// The long session of the week (run long run / run/walk long session; also long rides of a
/// triathlon beginner).
bool _isLong(PlannedWorkout x) => x.intensity == 'long' && x.sport != Sport.gym && x.sport != Sport.swim;

/// Done / planned of one session: duration for run/walk sessions and plans without a distance,
/// otherwise distance (when the session recorded one). Swims: distance vs the planned metres.
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

  final linked = linkPlanSessions(plans, sessions);

  // ── Long sessions
  var planned = 0.0, achieved = 0.0, doneAchieved = 0.0, donePlanned = 0.0;
  var missed = 0, done = 0;
  for (final x in longs) {
    final w = x.durationMin > 0 ? x.durationMin.toDouble() : 1.0;
    planned += w;
    final s = linked[x.id];
    if (s == null && !x.isDone) {
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
  );
}
