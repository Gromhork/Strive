import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../data/plan_log.dart';
import '../data/repository.dart';
import '../l10n/gen/app_localizations.dart';
import 'compliance.dart';
import 'plan_gaps.dart';
import 'plan_generator.dart';

/// The one way to (re)generate the training plan – used by the setup, "align plan with
/// goal" and "start the plan over" – and to delete it ([deletePlan]). A new plan from [start]
/// replaces the old one: every open workout of the calendar goes ([openWorkouts] – also missed
/// past ones; done ones stay as history), the new plan is written in the same chunked batches,
/// missing built-in programs are added and the plan metadata (start / length) is stored on the profile.
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
    DateTime? now,
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
      // A plan from next Monday: the old plan's open workouts until then (today to Sunday) stay – the athlete
      // finishes the week (review r10-N3). They move to the new generation, so no device removes them as left
      // over ([stalePlanWorkouts]); the athlete's own workouts (no generation) stay as they are.
      final bridge = [
        for (final x in bridgeWorkouts(existing, sessions, profile: p, start: day, now: now))
          if (x.planGen != null) PlannedWorkout.fromMap(x.id, {...x.toMap(), 'planGen': gen}),
      ];
      final plan = [
        for (final g in relinkNotCounted(withoutCoveredDays(generated, kept), reopened, sessions))
          PlannedWorkout.fromMap(g.id, {...g.toMap(), 'planGen': gen}),
        ...bridge,
      ];
      // The old plan goes entirely (owner round 10: "when a new plan is created, the old one is deleted"): every
      // open workout – also the missed ones before [day], skipped ones, refills and leftovers of older plans –, not
      // only the planned ones from [day] on (they stayed in the calendar and overlapped the new plan's weeks).
      // Written locally at once (offline persistence); the future is the server commit.
      // (A reopened workout whose id the new plan's run of that day took over is overwritten, not deleted.)
      final ids = {for (final g in plan) g.id};
      final remove = [
        for (final x in replacedWorkouts(existing, sessions, profile: p, start: day, now: now))
          if (!ids.contains(x.id)) x.id,
      ];
      final write = repo.replacePlans(remove, plan);
      // Plan start / length: lets the plan review rebuild the plan to find gaps.
      if (saveMeta) repo.saveProfile(withPlanMeta(p, day, weeks, gen: gen));
      write.ignore();
      replaced.value++;
      return plan.length - bridge.length;
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

  /// The workouts a new plan or "Plan löschen" removes – the old plan (owner round 10): every workout that is
  /// still open, of every date and origin – planned ones (also missed past ones, refills, the athlete's own and
  /// leftovers of older plans), skipped ones and done-marked ones whose linked session was too short to count
  /// ([notCountedWorkouts]). Done workouts and those a counting session is linked to stay ([keptWorkouts]): the
  /// recordings, stats and records keep their link to the workout as history.
  static List<PlannedWorkout> openWorkouts(List<PlannedWorkout> existing, List<Session> sessions, {UserProfile? profile}) {
    final kept = {for (final k in keptWorkouts(existing, _always, sessions, profile: profile)) k.id};
    return [
      for (final p in existing)
        if (!kept.contains(p.id)) p,
    ];
  }

  /// The open workouts ([openWorkouts]) a new plan from [start] removes: all of them, except those from today until
  /// the day before [start] ([bridgeWorkouts]).
  static List<PlannedWorkout> replacedWorkouts(
    List<PlannedWorkout> existing,
    List<Session> sessions, {
    UserProfile? profile,
    required DateTime start,
    DateTime? now,
  }) {
    final keep = {for (final x in bridgeWorkouts(existing, sessions, profile: profile, start: start, now: now)) x.id};
    return [
      for (final x in openWorkouts(existing, sessions, profile: profile))
        if (!keep.contains(x.id)) x,
    ];
  }

  /// The open workouts that stay when a new plan starts later than today ("ab nächstem Montag", review r10-N3): those
  /// from today until the day before [start] – the old plan runs until the new one begins and they never overlap it.
  /// (Missed past ones go: the old plan is deleted, owner round 10.) Empty for a plan from today.
  static List<PlannedWorkout> bridgeWorkouts(
    List<PlannedWorkout> existing,
    List<Session> sessions, {
    UserProfile? profile,
    required DateTime start,
    DateTime? now,
  }) {
    final today = dayOnly(now ?? DateTime.now());
    final day = dayOnly(start);
    if (!day.isAfter(today)) return const [];
    return [
      for (final x in openWorkouts(existing, sessions, profile: profile))
        if (!dayOnly(x.date).isBefore(today) && dayOnly(x.date).isBefore(day)) x,
    ];
  }

  /// A day before every workout: [keptWorkouts] / [notCountedWorkouts] over the whole calendar.
  static final _always = DateTime(1970);

  /// "Plan löschen" (owner round 10): removes the open workouts ([openWorkouts]; done ones stay), marks the plan as
  /// deleted on the profile ([AthleteData.planDeleted]: no start, length 0, a fresh generation – another device's
  /// copy of the old plan is removed as left over, [stalePlanWorkouts]) and logs it in the plan history. Goals stay.
  /// Returns what [undoDelete] needs, or null while another plan change is running. [saveMeta] false: no profile
  /// document yet.
  static PlanDeletion? deletePlan({
    required Repository repo,
    required UserProfile profile,
    required List<PlannedWorkout> existing,
    List<Session> sessions = const [],
    bool saveMeta = true,
    DateTime? now,
  }) {
    if (busy) return null;
    _busy = true;
    try {
      final open = openWorkouts(existing, sessions, profile: profile);
      final a = profile.athlete;
      final d = PlanDeletion(removed: open, planStart: a.planStart, planLength: a.planLength);
      repo.deletePlans([for (final p in open) p.id]).ignore();
      if (saveMeta) {
        final gen = newPlanGen(now ?? DateTime.now(), repo.newId());
        repo.saveProfile(profile.copyWith(athlete: a.merge({'planStart': null, 'planLength': 0, 'planGen': gen})));
      }
      repo.logPlanChange(PlanLogEntry.summary(PlanLogEntry.planDelete, open.length, at: now));
      replaced.value++;
      return d;
    } finally {
      _busy = false;
      _last = DateTime.now();
    }
  }

  /// Undo of [deletePlan] (the snackbar): the deleted workouts are written again and the plan's start / length come
  /// back on [current] (the profile as it is now). Under a new generation – the restored workouts and the profile
  /// carry it –, so the deletion marker never removes them again, whichever of the two writes another device (or the
  /// cleanup on this one, [stalePlanWorkouts]) sees first.
  static void undoDelete(Repository repo, PlanDeletion d, UserProfile current, {bool saveMeta = true, DateTime? now}) {
    final gen = newPlanGen(now ?? DateTime.now(), repo.newId());
    repo.savePlans([
      for (final p in d.removed) p.planGen == null ? p : PlannedWorkout.fromMap(p.id, {...p.toMap(), 'planGen': gen}),
    ]).ignore();
    if (saveMeta) {
      repo.saveProfile(
        current.copyWith(athlete: current.athlete.merge({'planStart': d.planStart, 'planLength': d.planLength, 'planGen': gen})),
      );
    }
    repo.logPlanChange(PlanLogEntry.summary(PlanLogEntry.planRestore, d.removed.length, at: now));
    replaced.value++;
  }

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

/// What [PlanService.deletePlan] removed – for its undo ([PlanService.undoDelete]).
class PlanDeletion {
  const PlanDeletion({required this.removed, this.planStart, this.planLength});

  /// The deleted workouts (full documents).
  final List<PlannedWorkout> removed;

  /// The plan's start / length before the deletion.
  final DateTime? planStart;
  final int? planLength;
}
