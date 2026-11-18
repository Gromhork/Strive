import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../l10n/gen/app_localizations.dart';
import 'compliance.dart';
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

  /// Counts the plans replaced ([replacePlan]): the calendar goes back to the current week when it changes
  /// (audit UX-16: after "Plan neu aufsetzen" the list stayed weeks into the old plan).
  static final replaced = ValueNotifier<int>(0);

  /// True while the first setup creates the plan: its profile is saved first (which already opens
  /// the app), the plan follows a moment later – Home shows "creating" instead of "no plan yet".
  static final creating = ValueNotifier<bool>(false);

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
      final kept = keptWorkouts(existing, day, sessions, profile: p);
      // A start too short to count leaves its workout open: it is replaced like any open one.
      final reopened = notCountedWorkouts(existing, day, sessions, profile: p);
      // The plan's generation (data-9): its workouts carry it, the profile names the current one.
      final gen = newPlanGen(DateTime.now(), repo.newId());
      final plan = [
        for (final g in relinkNotCounted(withoutCoveredDays(generated, kept), reopened, sessions))
          PlannedWorkout.fromMap(g.id, {...g.toMap(), 'planGen': gen}),
      ];
      // Written locally at once (offline persistence); the future is the server commit.
      final write = repo.replacePlans(existing, day, plan, keep: {for (final k in kept) k.id}, drop: {for (final r in reopened) r.id});
      // Plan start / length: lets the plan review rebuild the plan to find gaps.
      if (saveMeta) repo.saveProfile(withPlanMeta(p, day, weeks, gen: gen));
      write.ignore();
      replaced.value++;
      return plan.length;
    } finally {
      _busy = false;
      _last = DateTime.now();
    }
  }

  /// The athlete's gym workouts of the [days] before [day] (day, program id), oldest first: recorded
  /// sessions of a program and planned workouts marked as done – the new plan's gym rotation (and an
  /// A/B week alternation) continues from them ([PlanGenerator.generate]).
  static List<(DateTime, String)> gymHistory(List<PlannedWorkout> existing, List<Session> sessions, DateTime day, {int days = 21}) =>
      gymHistoryBefore(existing, sessions, day, days: days);

  /// Workouts on or after [day] a new plan keeps: done ones, and planned ones a session is
  /// linked to (started from them) – but not one whose linked session was too short to count
  /// ([sessionCounts], < 10 % of the plan): that workout is still open ([notCountedWorkouts]) and
  /// is replaced like every open one (audit: an aborted 3-min start "replaced" Wednesday's gym
  /// session, and after "Plan neu aufsetzen" Wednesday had no gym session any more).
  static List<PlannedWorkout> keptWorkouts(List<PlannedWorkout> existing, DateTime day, List<Session> sessions, {UserProfile? profile}) {
    final open = {for (final p in notCountedWorkouts(existing, day, sessions, profile: profile)) p.id};
    return [
      for (final p in _linkedFrom(existing, day, sessions))
        if (!open.contains(p.id)) p,
    ];
  }

  /// Workouts on or after [day] with a linked session (or marked done) – the candidates to keep.
  static Iterable<PlannedWorkout> _linkedFrom(List<PlannedWorkout> existing, DateTime day, List<Session> sessions) {
    final linked = {
      for (final s in sessions)
        if (s.planId != null) s.planId!,
    };
    return existing.where(
      (p) => !p.date.isBefore(day) && (p.isDone || p.sessionId != null || (p.status == 'planned' && linked.contains(p.id))),
    );
  }

  /// Workouts on or after [day] whose linked session does not count (< [ComplianceScale.countMin]
  /// of the plan): open for every purpose of the plan – a new plan replaces them and plans their day.
  static List<PlannedWorkout> notCountedWorkouts(
    List<PlannedWorkout> existing,
    DateTime day,
    List<Session> sessions, {
    UserProfile? profile,
  }) {
    final links = linkPlanSessions(existing, sessions, profile: profile);
    return [
      for (final p in _linkedFrom(existing, day, sessions))
        if (links[p.id] case final s? when p.status != 'skipped' && !sessionCounts(p, s, profile: profile)) p,
    ];
  }

  /// [plan] with the ids of [reopened] workouts reused where the attempt stays attached: the new
  /// plan's workout of the same sport on the day the too-short session was done on (an aborted start of
  /// today's run stays visible on today's new run as "nicht gewertet"). A session done on another day
  /// (started early from a later workout) is not attached to the new plan – it is just a short session.
  static List<PlannedWorkout> relinkNotCounted(List<PlannedWorkout> plan, List<PlannedWorkout> reopened, List<Session> sessions) {
    if (reopened.isEmpty) return plan;
    final out = [...plan];
    final used = <int>{};
    for (final r in reopened) {
      final s = sessions.where((s) => s.planId == r.id || s.id == r.sessionId).firstOrNull;
      if (s == null || !sameDay(s.start, r.date) || s.planId != r.id) continue;
      final i = out.indexWhere((g) => g.sport == r.sport && sameDay(g.date, r.date));
      if (i < 0 || !used.add(i)) continue;
      final g = out[i];
      out[i] = PlannedWorkout.fromMap(r.id, {...g.toMap(), 'status': 'planned', 'sessionId': null});
    }
    return out;
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
