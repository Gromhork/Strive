import '../core/format.dart';
import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../l10n/gen/app_localizations.dart';
import 'plan_gaps.dart';
import 'plan_generator.dart';

/// The one way to (re)generate the training plan – used by the setup, "align plan with
/// goal" and "start the plan over". Replaces the upcoming planned workouts from [start]
/// with a new plan in chunked batches, adds missing built-in programs and stores the plan
/// metadata (start / length) on the profile.
///
/// Guarded against double taps: while a replacement runs – and for [cooldown] after it, until
/// the plan stream shows the new plan (a second call would still see the old workouts and add
/// a second plan) – another call returns null.
class PlanService {
  PlanService._();

  static bool _busy = false;
  static DateTime? _last;

  /// Time after a replacement in which another one is refused.
  static const cooldown = Duration(seconds: 3);

  /// For tests.
  static void reset() {
    _busy = false;
    _last = null;
  }

  /// True while a plan is being replaced.
  static bool get busy => _busy || (_last != null && DateTime.now().difference(_last!) < cooldown);

  /// Returns the number of generated workouts, or null when another replacement is still
  /// running. [saveMeta] false: the profile is not written (no profile document yet).
  /// [sessions]: the athlete's sessions – a plan re-created mid-plan starts from the volume reached
  /// ([withReachedVolume]); that volume is stored on the profile with the plan metadata.
  static Future<int?> replacePlan({
    required Repository repo,
    required AppLocalizations l,
    required UserProfile profile,
    required List<WorkoutTemplate> templates,
    required List<PlannedWorkout> existing,
    required DateTime start,
    required int weeks,
    bool saveMeta = true,
    List<Session> sessions = const [],
  }) async {
    if (busy) return null;
    _busy = true;
    try {
      final day = dayOnly(start);
      final p = withReachedVolume(profile, plans: existing, sessions: sessions, start: day);
      // The programs of the chosen split must exist (built-ins added on demand).
      // (Also the built-in programs the athlete assigned to gym days.)
      final added = missingBuiltins(templates, repo.newId, de: l.localeName.startsWith('de'), only: PlanGenerator.gymKeysFor(p).toSet());
      if (added.isNotEmpty) repo.saveTemplates(added);
      // The gym rotation continues from the last gym workouts (no Push right after Push).
      final generated = PlanGenerator(l, p, [
        ...templates,
        ...added,
      ], repo.newId).generate(start: day, weeks: weeks, gymHistory: gymHistory(existing, sessions, day));
      // Done / linked workouts from [day] on stay – and their day is not planned again (a replan
      // "from today" after today's run must not add a second run for today).
      final kept = keptWorkouts(existing, day, sessions);
      final plan = withoutCoveredDays(generated, kept);
      // Written locally at once (offline persistence); the future is the server commit.
      final write = repo.replacePlans(existing, day, plan, keep: {for (final k in kept) k.id});
      // Plan start / length: lets the plan review rebuild the plan to find gaps.
      if (saveMeta) repo.saveProfile(withPlanMeta(p, day, weeks));
      write.ignore();
      return plan.length;
    } finally {
      _busy = false;
      _last = DateTime.now();
    }
  }

  /// The athlete's gym workouts of the [days] before [day] (day, program id), oldest first: recorded
  /// sessions of a program and planned workouts marked as done – the new plan's gym rotation (and an
  /// A/B week alternation) continues from them ([PlanGenerator.generate]).
  static List<(DateTime, String)> gymHistory(List<PlannedWorkout> existing, List<Session> sessions, DateTime day, {int days = 21}) {
    final from = addDays(dayOnly(day), -days);
    bool inWindow(DateTime d) => !dayOnly(d).isBefore(from) && dayOnly(d).isBefore(dayOnly(day));
    final out = <(DateTime, String)>[
      for (final s in sessions)
        if (s.sport == Sport.gym && s.templateId != null && inWindow(s.start)) (dayOnly(s.start), s.templateId!),
    ];
    final seen = {for (final (d, id) in out) '${dayKey(d)}|$id'};
    for (final p in existing) {
      if (p.sport != Sport.gym || !p.isDone || p.templateId == null || !inWindow(p.date)) continue;
      if (seen.add('${dayKey(p.date)}|${p.templateId}')) out.add((dayOnly(p.date), p.templateId!));
    }
    return out..sort((x, y) => x.$1.compareTo(y.$1));
  }

  /// Workouts on or after [day] a new plan keeps: done ones, and planned ones a session is
  /// linked to (started from them – also a start too short to count, its data stays attached).
  static List<PlannedWorkout> keptWorkouts(List<PlannedWorkout> existing, DateTime day, List<Session> sessions) {
    final linked = {
      for (final s in sessions)
        if (s.planId != null) s.planId!,
    };
    return [
      for (final p in existing)
        if (!p.date.isBefore(day) && (p.isDone || p.sessionId != null || (p.status == 'planned' && linked.contains(p.id)))) p,
    ];
  }

  /// [generated] without the workouts on days that already have a kept workout ([keptWorkouts]):
  /// a day that was trained is not planned a second time.
  static List<PlannedWorkout> withoutCoveredDays(List<PlannedWorkout> generated, List<PlannedWorkout> kept) {
    final covered = {
      for (final k in kept)
        if (k.status != 'skipped') dayKey(k.date),
    };
    return [
      for (final g in generated)
        if (!covered.contains(dayKey(g.date))) g,
    ];
  }
}
