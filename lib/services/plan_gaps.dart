import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'compliance.dart';
import 'fitness_state.dart';
import 'plan_generator.dart';
import 'zones.dart';

/// Why a session is proposed to fill a gap.
enum GapWhy {
  /// A single planned session of the week is missing (deleted).
  missing,

  /// The whole week has no workouts.
  emptyWeek,

  /// The plan ended before the event / the rolling horizon: continued.
  planEnded,
}

/// One session that the plan expects but the calendar does not have.
class GapFill {
  const GapFill(this.plan, this.why, {required this.budgetKey});

  /// The session as the generator plans it (already with a new id).
  final PlannedWorkout plan;
  final GapWhy why;

  /// Key into [PlanGaps.budgets]: sport and week of this session.
  final String budgetKey;
}

/// The profile with the metadata of a plan generated from [start] for [weeks] weeks
/// ([weeks] 0: the plan is not rule-based – no gap detection) and its generation id [gen] ([AthleteData.planGen]).
UserProfile withPlanMeta(UserProfile p, DateTime start, int weeks, {String? gen}) =>
    p.copyWith(athlete: p.athlete.merge({'planStart': dayOnly(start), 'planLength': weeks, 'planGen': gen}));

/// A new plan generation id ([AthleteData.planGen]): ordered by time, so the newer of two plans is known.
String newPlanGen(DateTime now, String id) => '${now.millisecondsSinceEpoch.toString().padLeft(15, '0')}-$id';

/// Planned workouts left over from a plan another device replaced with a stale cache (review 2026-11 data-9): of an
/// older generation ([newPlanGen]) than the newest one – the profile's ([AthleteData.planGen]) or a generated workout's
/// from its [AthleteData.planStart] on (two devices: the later plan wins, whichever profile write arrived last) –,
/// dated from that start on – and from the newest generation's own first workout on: only the days the newer plan
/// covers hold duplicates; before them the older plan's workouts are history (missed ones feed the compliance, the
/// forecast and the next re-creation; review 2026-11 G4V-3: the plans snapshot of another device's replan arriving
/// before its profile deleted the old plan's past missed workouts) –, still open and not started from (no session
/// points at them). Empty without a stored generation. (Workouts the athlete added or the plan review refilled carry
/// none and always stay.)
List<PlannedWorkout> stalePlanWorkouts(UserProfile p, List<PlannedWorkout> plans, List<Session> sessions) {
  final planStart = p.athlete.planStart;
  var gen = p.athlete.planGen;
  if (gen == null || planStart == null) return const [];
  for (final x in plans) {
    final g = x.planGen;
    if (g != null && !dayOnly(x.date).isBefore(dayOnly(planStart)) && g.compareTo(gen!) > 0) gen = g;
  }
  var start = dayOnly(planStart);
  DateTime? first;
  for (final x in plans) {
    if (x.planGen == gen && (first == null || dayOnly(x.date).isBefore(first))) first = dayOnly(x.date);
  }
  if (first != null && first.isAfter(start)) start = first;
  final started = {
    for (final s in sessions)
      if (s.planId != null) s.planId!,
  };
  return [
    for (final x in plans)
      if (x.planGen != null &&
          x.planGen!.compareTo(gen!) < 0 &&
          x.status == 'planned' &&
          x.sessionId == null &&
          !started.contains(x.id) &&
          !dayOnly(x.date).isBefore(start))
        x,
  ];
}

/// The profile for a plan re-created mid-plan ("Plan neu aufsetzen", "align plan with goal") from
/// [start]: the weekly volume and the longest run the athlete actually reached in the 4 weeks before
/// it replace the setup values (runWeeklyKm, longestRunKm, bikeWeeklyHours, swimWeeklyKm) – the new
/// plan continues from there instead of restarting at the setup's volume (like [PlanGaps]' continuation,
/// but from the done sessions). Weekly volume: the highest loading week (the plan's recovery / taper
/// weeks don't count); longest run: the longest run of the 4 weeks. Unchanged without ≥ 2 weeks of a
/// generated plan before [start] (a fresh setup keeps what the athlete entered).
///
/// The new plan also continues where the replaced one was ([PlanCarry], [planCarryOf]): its loading / recovery
/// rhythm and phase, the run/walk stage and the fitness model's training block.
UserProfile withReachedVolume(
  UserProfile p, {
  required List<PlannedWorkout> plans,
  required List<Session> sessions,
  required DateTime start,
}) {
  final day = dayOnly(start);
  final from = addDays(day, -28);
  final carry = planCarryOf(p, plans: plans, sessions: sessions, start: day);
  if (carry != null || p.athlete.planCarry != null) p = p.copyWith(athlete: p.athlete.merge({'planCarry': carry}));
  final history = plans.where((x) => x.phase != null && !dayOnly(x.date).isBefore(from) && dayOnly(x.date).isBefore(day)).toList();
  if (history.isEmpty) return p;
  final first = history.map((x) => dayOnly(x.date)).reduce((x, y) => x.isBefore(y) ? x : y);
  if (daysBetween(first, day) < 14) return p;
  final rest = {
    for (final x in history)
      if (x.phase == 'recovery' || x.phase == 'taper') startOfWeek(x.date),
  };
  final weeks = <DateTime, Map<Sport, double>>{};
  var longest = 0.0;
  for (final s in sessions) {
    final d = dayOnly(s.start);
    if (d.isBefore(from) || !d.isBefore(day) || s.sport == Sport.gym) continue;
    if (s.sport == Sport.run) longest = max(longest, s.distanceM / 1000);
    final wk = startOfWeek(d);
    if (rest.contains(wk)) continue;
    final w = weeks.putIfAbsent(wk, () => {});
    w[s.sport] = (w[s.sport] ?? 0) + (s.sport == Sport.ride ? s.durationSec / 3600 : s.distanceM / 1000);
  }
  double top(Sport s) => weeks.values.fold<double>(0, (x, w) => max(x, w[s] ?? 0));
  double r1(double v) => double.parse(v.toStringAsFixed(1));
  final run = top(Sport.run), ride = top(Sport.ride), swim = top(Sport.swim);
  return p.copyWith(
    athlete: p.athlete.merge({
      if (run > 0) 'runWeeklyKm': r1(run),
      if (longest > 0) 'longestRunKm': r1(longest),
      if (ride > 0) 'bikeWeeklyHours': r1(ride),
      if (swim > 0) 'swimWeeklyKm': r1(swim),
    }),
  );
}

/// Where a plan re-created on [start] continues the generated plan it replaces ([PlanCarry]; review 2026-11
/// adapt-2 / -6 / -7) – null without generated workouts in the 4 weeks before [start]:
/// * **Rhythm** – the loading weeks in a row right before [start]'s week, and whether that week was a planned
///   recovery week (it stays one): no 5–6 loading weeks in a row across the re-creation.
/// * **Phase** – the phase reached (build / peak) for the same goal (race day unchanged): no base weeks again.
/// * **Run/walk** – a run/walker's stage: the highest one done in the 4 weeks (the next one after ≥ 2 sessions of
///   it), past the ladder once a continuous run of ≥ 20 min was done; and the longest long run/walk's main set.
/// * **Fitness** – the training block the fitness model counts from stays the first plan's (the forecast and
///   the gain the weeks trained earned don't restart with the new plan, adapt-6).
/// After a break (< 50 % of the last 2 weeks' training, or ≥ 10 days without a session) the rhythm and phase
/// start over and the run/walk stage goes one back.
PlanCarry? planCarryOf(UserProfile p, {required List<PlannedWorkout> plans, required List<Session> sessions, required DateTime start}) {
  final day = dayOnly(start);
  final from = addDays(day, -28);
  final phased = plans.where((x) => x.phase != null && x.sport != Sport.gym).toList()..sort((x, y) => x.date.compareTo(y.date));
  final before = phased.where((x) => !dayOnly(x.date).isBefore(from) && dayOnly(x.date).isBefore(day)).toList();
  if (before.isEmpty) return null;
  final linked = linkPlanSessions(plans, sessions, profile: p);
  // A break: little of the last two weeks' training done, or a long gap without any session.
  final due = before.where((x) => x.intensity != 'race' && x.durationMin > 0 && !dayOnly(x.date).isBefore(addDays(day, -14))).toList();
  final done = due.length >= 3 ? weeklyCompletion(due, linked, now: day, profile: p) : null;
  final last = sessions
      .where((s) => s.sport != Sport.gym && dayOnly(s.start).isBefore(day))
      .map((s) => dayOnly(s.start))
      .fold<DateTime?>(null, (x, d) => x == null || d.isAfter(x) ? d : x);
  final brk = (done != null && done < 0.5) || last == null || daysBetween(last, day) >= 10;
  // Phase of a plan week: recovery when the plan or the review made it one (most of its workouts), else the
  // most frequent phase.
  bool rest(PlannedWorkout x) =>
      x.phase == 'recovery' || ((x.auto?.reason ?? '').startsWith('recal') && x.auto!.reason.endsWith('Recovery'));
  String? phaseOf(DateTime monday) {
    // (Race week: the race itself counts when the week has nothing else.)
    final all = phased.where((x) => !dayOnly(x.date).isBefore(monday) && dayOnly(x.date).isBefore(addDays(monday, 7)));
    final ws = all.any((x) => x.intensity != 'race') ? all.where((x) => x.intensity != 'race') : all;
    if (ws.isEmpty) return null;
    if (ws.where(rest).length * 2 >= ws.length) return 'recovery';
    final n = <String, int>{};
    for (final x in ws) {
      n.update(x.phase!, (v) => v + 1, ifAbsent: () => 1);
    }
    return (n.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).first.key;
  }

  final week0 = startOfWeek(day);
  // The new plan's first week ([PlanGenerator.planStartFor]: the next one when the start's week has no training day
  // left – then the old plan's week of [start] is one before it).
  final first = startOfWeek(PlanGenerator.planStartFor(p, day));
  final current = phaseOf(first);
  var loads = 0;
  for (var m = addDays(first, -7); loads < 8; m = addDays(m, -7)) {
    final ph = phaseOf(m);
    if (ph == null || ph == 'recovery' || ph == 'taper') break;
    loads++;
  }
  // Phase reached: this week's, else the last loading week's – only for the same goal (a new race starts its own
  // build-up).
  String? reached = current != null && current != 'recovery' ? current : null;
  for (var m = addDays(week0, -7); reached == null && !m.isBefore(from); m = addDays(m, -7)) {
    final ph = phaseOf(m);
    if (ph != null && ph != 'recovery') reached = ph;
  }
  final a = p.athlete;
  final races = phased.where((x) => x.intensity == 'race' && !dayOnly(x.date).isBefore(day)).toList();
  final sameGoal = a.eventDate == null ? races.isEmpty : races.any((x) => sameDay(x.date, a.eventDate!));
  // The same race: the replaced plan's week-by-week phases to race week (every week still has its workouts).
  List<String>? layout;
  if (sameGoal && a.eventDate != null && !brk) {
    final weeks = [for (var m = week0; !m.isAfter(startOfWeek(a.eventDate!)); m = addDays(m, 7)) phaseOf(m)];
    if (weeks.isNotEmpty && !weeks.contains(null)) layout = weeks.whereType<String>().toList();
  }
  // Run/walk stage reached.
  int? stage;
  var longSec = 0;
  var longKm = 0.0;
  if (PlanGenerator.runWalkStartFor(p) != null) {
    var k = -1, atK = 0;
    var continuous = false;
    for (final x in before.where((x) => x.sport == Sport.run && planCompleted(x, linked, profile: p))) {
      final s = PlanGenerator.runWalkStageOf(x);
      if (s != null) {
        if (s > k) {
          k = s;
          atK = 1;
        } else if (s == k) {
          atK++;
        }
        continue;
      }
      final main = PlanGenerator.runWalkMainSec(x);
      if (main > 0) {
        if (main > longSec) longSec = main;
        longKm = max(longKm, runningKm(x));
      } else if ((x.steps.isEmpty || x.steps.first.zone != 'walk') && x.durationMin >= 20 && x.intensity != 'race') {
        continuous = true; // a continuous run after the ladder
      }
    }
    if (continuous && !brk) {
      stage = PlanGenerator.runWalkStages;
    } else if (k >= 0) {
      // The next stage: the one the replaced plan scheduled after k (a goal-directed build skips stages – 5 × 3 min →
      // 2 × 8 min, review 2026-11 G4V-4), else the table's next.
      final next = phased
          .where((x) => x.sport == Sport.run && !dayOnly(x.date).isBefore(day))
          .map(PlanGenerator.runWalkStageOf)
          .whereType<int>()
          .where((s) => s > k)
          .fold<int?>(null, (m, s) => m == null || s < m ? s : m);
      stage = brk ? max(0, k - 1) : (atK >= 2 ? next ?? k + 1 : k);
    }
    if (brk) longSec = 0;
  }
  // The fitness model's training block: the replaced plan's (or the block it continued).
  final fitnessStart = FitnessState.currentPlanStart(p, phased);
  // The volume the block started with – only for the same race without a break (the same build-up continues): the
  // replaced plan's own carry (a plan re-created twice), else its stated start volume. A new goal, a plan without a
  // race or a break starts a new block: its ceilings count from the new start volume (review 2026-11 G4V-1: a new
  // marathon after a 10K stayed frozen at 1.5 × the 10K plan's volume).
  final block = sameGoal && a.eventDate != null && !brk;
  final prev = block && a.planCarry != null && a.planStart != null && sameDay(a.planCarry!.start, a.planStart!) ? a.planCarry : null;
  double? pos(double? v) => block && v != null && v > 0 ? v : null;
  return PlanCarry(
    start: day,
    loadWeeks: brk || current == 'recovery' ? 0 : loads,
    recovery: !brk && current == 'recovery' && loads > 0,
    phase: brk || !sameGoal ? null : reached,
    phases: layout,
    runWalkStage: stage,
    runWalkLongSec: longSec,
    runWalkLongKm: brk ? 0 : longKm,
    fitnessStart: fitnessStart != null && fitnessStart.isBefore(day) ? fitnessStart : null,
    baseRunKm: prev?.baseRunKm ?? pos(a.runWeeklyKm),
    baseRideH: prev?.baseRideH ?? pos(a.bikeWeeklyHours),
    baseSwimKm: prev?.baseSwimKm ?? pos(a.swimWeeklyKm),
  );
}

/// The athlete's gym workouts of the [days] before [day] (day, program id), oldest first: recorded
/// sessions of a program and planned workouts marked as done – a new plan's gym rotation (and an
/// A/B week alternation) continues from them ([PlanGenerator.generate]).
List<(DateTime, String)> gymHistoryBefore(List<PlannedWorkout> existing, List<Session> sessions, DateTime day, {int days = 21}) {
  final from = addDays(dayOnly(day), -days);
  bool inWindow(DateTime d) => !dayOnly(d).isBefore(from) && dayOnly(d).isBefore(dayOnly(day));
  // A start too short to count (< 10 % of its planned workout) is no workout of the rotation: the
  // next program would otherwise skip the one that was aborted.
  final linked = linkPlanSessions(existing.where((p) => p.sport == Sport.gym).toList(), sessions);
  final notCounted = <String>{
    for (final p in existing)
      if (linked[p.id] case final s? when !sessionCounts(p, s)) s.id,
  };
  final out = <(DateTime, String)>[
    for (final s in sessions)
      if (s.sport == Sport.gym && s.templateId != null && inWindow(s.start) && !notCounted.contains(s.id))
        (dayOnly(s.start), s.templateId!),
  ];
  final seen = {for (final (d, id) in out) '${dayKey(d)}|$id'};
  for (final p in existing) {
    if (p.sport != Sport.gym || !p.isDone || p.templateId == null || !inWindow(p.date)) continue;
    if (linked[p.id] case final s? when notCounted.contains(s.id)) continue;
    if (seen.add('${dayKey(p.date)}|${p.templateId}')) out.add((dayOnly(p.date), p.templateId!));
  }
  return out..sort((x, y) => x.$1.compareTo(y.$1));
}

/// Gaps in the current plan (docs/training-science.md §11, "gaps"). Pure – no Firestore.
///
/// The plan is rebuilt with [PlanGenerator] from its start (stored on the profile as
/// [AthleteData.planStart] / [AthleteData.planLength] when it was generated; older plans:
/// reconstructed from the workouts' dates and phases). A plan that ends before the event or
/// – without an event – before the horizon is continued with the generator from the Monday
/// after its last week, starting at the plan's last loading volume.
///
/// Per week and sport, the rebuilt plan's sessions are compared with the calendar's
/// workouts of every status (done, planned, skipped – a skipped session is no gap; moved
/// ones still count in their week): if the calendar has fewer, the missing ones are taken
/// from the rebuilt week – those on a day after today without a workout of that sport,
/// preferring the roles the week lacks (long, quality, easy). Days the generator leaves free
/// (rest days, recovery weeks with fewer sessions, race week) have no rebuilt session, so
/// they are never "missing". Weeks that only hold the athlete's own (non-generated) workouts
/// are left alone.
class PlanGaps {
  PlanGaps(
    this.l,
    this.profile, {
    required this.plans,
    required this.now,
    this.templates = const [],
    this.sessions = const [],
    String Function()? newId,
  }) : _newId = newId ?? (() => 'gap${_seq++}');

  final AppLocalizations l;
  final UserProfile profile;
  final List<PlannedWorkout> plans;

  /// The athlete's recorded sessions: with the plan's done gym workouts, the gym history the plan was
  /// generated with ([gymHistoryBefore]) – the rebuilt plan's rotation then matches the calendar's.
  final List<Session> sessions;
  final DateTime now;
  final List<WorkoutTemplate> templates;
  final String Function() _newId;
  static int _seq = 0;
  var _refSeq = 0;

  /// Horizon: the rest of the current week and this many weeks after it.
  static const weeksAhead = 4;

  /// A plan whose last generated workout is longer ago than this is over – nothing to fill.
  static const activeDays = 14;

  DateTime get today => dayOnly(now);

  /// First day that may be filled (today's session is the athlete's call, past days never).
  DateTime get from => _add(today, 1);

  /// End of the horizon (exclusive).
  DateTime get until {
    final end = _add(_monday(today), 7 * (weeksAhead + 1));
    final ev = profile.athlete.eventDate;
    return ev != null && !dayOnly(ev).isBefore(from) && dayOnly(ev).isBefore(end) ? _add(dayOnly(ev), 1) : end;
  }

  /// Minutes per sport and week the rebuilt plan has left above the calendar's (not
  /// skipped) workouts – a refilled week never exceeds the planned week ([budgetKey]).
  final budgets = <String, int>{};

  static DateTime _add(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);
  static DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
  static String budgetKey(Sport s, DateTime day) => '${s.name}|${dayKey(_monday(day))}';

  static String _role(PlannedWorkout p) => switch (p.intensity) {
    'race' => 'race',
    'long' => 'long',
    'tempo' || 'intervals' => 'q',
    _ => 'easy',
  };

  List<GapFill> find() {
    final ref = reference();
    if (ref == null) return const [];
    final (gen, ext) = ref;
    final out = <GapFill>[];
    final end = until;
    for (var wk = _monday(today); wk.isBefore(end); wk = _add(wk, 7)) {
      final wEnd = _add(wk, 7);
      bool inWeek(PlannedWorkout p) => !dayOnly(p.date).isBefore(wk) && dayOnly(p.date).isBefore(wEnd);
      final g = gen.where(inWeek).toList();
      if (g.isEmpty) continue;
      final have = plans.where(inWeek).toList();
      // Only the athlete's own workouts this week (AI plan, added by hand): not ours to fill.
      if (have.isNotEmpty && have.every((p) => p.phase == null)) continue;
      for (final sport in {for (final p in g) p.sport}) {
        final gs = g.where((p) => p.sport == sport).toList();
        final hs = have.where((p) => p.sport == sport).toList();
        final missing = gs.length - hs.length;
        if (missing <= 0) continue;
        // Roles of the rebuilt week the calendar lacks.
        final lack = [for (final p in gs) _role(p)];
        for (final p in hs) {
          lack.remove(_role(p));
        }
        final cands =
            gs
                .where((p) => !dayOnly(p.date).isBefore(from) && dayOnly(p.date).isBefore(end) && !hs.any((h) => sameDay(h.date, p.date)))
                .toList();
        final picked = <PlannedWorkout>[];
        for (var pass = 0; pass < 2 && picked.length < missing; pass++) {
          for (final p in cands) {
            if (picked.length >= missing || picked.contains(p)) continue;
            if (pass == 0 && !lack.contains(_role(p))) continue;
            if (pass == 0) lack.remove(_role(p));
            picked.add(p);
          }
        }
        if (picked.isEmpty) continue;
        final key = budgetKey(sport, wk);
        final planned = gs.fold<int>(0, (x, p) => x + p.durationMin);
        final used = hs.where((p) => p.status != 'skipped').fold<int>(0, (x, p) => x + p.durationMin);
        budgets[key] = max(0, planned - used);
        for (final p in picked..sort((x, y) => x.date.compareTo(y.date))) {
          // (Never a strength refill without a program to show.)
          if (p.sport == Sport.gym && p.exercises.isEmpty && ![...templates, ..._missing].any((t) => t.id == p.templateId)) continue;
          final why = ext.contains(p.id) ? GapWhy.planEnded : (have.isEmpty ? GapWhy.emptyWeek : GapWhy.missing);
          out.add(GapFill(PlannedWorkout.fromMap(_newId(), _withProgram(p).toMap()), why, budgetKey: key));
        }
      }
    }
    out.sort((x, y) => x.plan.date.compareTo(y.plan.date));
    return out;
  }

  /// The rebuilt plan (and its continuation) and the ids of the continuation's sessions,
  /// or null when there is no active rule-based plan.
  (List<PlannedWorkout>, Set<String>)? reference() {
    final a = profile.athlete;
    if (a.planLength == 0) return null;
    final phased = plans.where((p) => p.phase != null).toList()..sort((x, y) => x.date.compareTo(y.date));
    if (phased.isEmpty || dayOnly(phased.last.date).isBefore(_add(today, -activeDays))) return null;
    final base = _anchor(phased);
    if (base == null) return null;
    final out = [...base];
    final ext = <String>{};
    // Continuation: not after a race (the plan ran to its event), at most a few blocks.
    if (!out.any((p) => p.intensity == 'race')) {
      var start = _add(_monday(out.isEmpty ? today : out.last.date), 7);
      final ev = a.eventDate;
      final eventAhead = ev != null && !dayOnly(ev).isBefore(start);
      final weeks = max(1, a.planWeeks);
      for (var i = 0; i < 4 && start.isBefore(until); i++) {
        // The gym rotation continues from the block before.
        final next = _gen(
          _continuation(start, out),
          start,
          weeks,
          gymHistory: [
            for (final p in out)
              if (p.sport == Sport.gym && p.templateId != null) (p.date, p.templateId!),
          ],
        );
        if (next.isEmpty) break;
        out.addAll(next);
        ext.addAll(next.map((p) => p.id));
        if (next.any((p) => p.intensity == 'race') || (ev != null && !eventAhead)) break;
        start = _add(_monday(next.last.date), 7);
      }
    }
    return (out, ext);
  }

  List<PlannedWorkout> _gen(UserProfile p, DateTime start, int weeks, {List<(DateTime, String)> gymHistory = const []}) => PlanGenerator(
    l,
    p,
    [...templates, ..._missing],
    () => 'ref${_refSeq++}',
  ).generate(start: start, weeks: weeks, gymHistory: gymHistory);

  /// Built-in programs the rebuilt plan uses that the athlete's list lacks (programs added in a later version, e.g.
  /// the home / bodyweight upper / lower split – review 2026-11 G3V-2: the refill had no program, 0 exercises): the
  /// plan is rebuilt with them (placeholder ids), and a refill that uses one gets it with a new id ([addedTemplates],
  /// saved with the refill – Recalibration.newTemplates – as PlanService.replacePlan does).
  late final List<WorkoutTemplate> _missing =
      missingBuiltins(
        templates,
        () => '',
        de: l.localeName.startsWith('de'),
        only: PlanGenerator.gymKeysFor(profile).toSet(),
      ).map((t) => WorkoutTemplate.fromMap('$_builtinPrefix${t.key}', t.toMap())).toList();

  static const _builtinPrefix = 'builtin:';

  /// Placeholder id → the program with its new id, drawn when a refill first uses it.
  final _added = <String, WorkoutTemplate>{};

  /// The missing built-in programs the refills of [find] use (with their new ids).
  List<WorkoutTemplate> get addedTemplates => _added.values.toList();

  /// [p] with its program's new id when it is a missing built-in.
  PlannedWorkout _withProgram(PlannedWorkout p) {
    final id = p.templateId;
    if (id == null || !id.startsWith(_builtinPrefix)) return p;
    final t = _missing.where((t) => t.id == id).firstOrNull;
    if (t == null) return p;
    final added = _added.putIfAbsent(id, () => WorkoutTemplate.fromMap(_newId(), t.toMap()));
    return PlannedWorkout.fromMap(p.id, {...p.toMap(), 'templateId': added.id});
  }

  /// The plan from its stored start, else from the start that reproduces the phases of the
  /// generated workouts best (≥ 75 % agree).
  List<PlannedWorkout>? _anchor(List<PlannedWorkout> phased) {
    final a = profile.athlete;
    if (a.planStart != null && (a.planLength ?? 0) > 0 && phased.any((p) => !dayOnly(p.date).isBefore(dayOnly(a.planStart!)))) {
      // The gym history the plan was generated with (PlanService.replacePlan): without it the rebuilt rotation
      // was offset from the calendar's and a deleted Legs day was refilled with Pull (review 2026-11 eng-5).
      final start = dayOnly(a.planStart!);
      return _gen(profile, start, a.planLength!, gymHistory: gymHistoryBefore(plans, sessions, start));
    }
    // Latest block of generated workouts (no hole > 3 weeks).
    var i = phased.length - 1;
    while (i > 0 && daysBetween(phased[i - 1].date, phased[i].date) <= 21) {
      i--;
    }
    final block = phased.sublist(i);
    // Candidate starts: the block's first workout and every point where the phases start over.
    const rank = {'base': 0, 'build': 1, 'peak': 2, 'taper': 3};
    final cands = <DateTime>[dayOnly(block.first.date)];
    int? last;
    for (var j = 0; j < block.length; j++) {
      final r = rank[block[j].phase];
      if (r == null) continue; // recovery: keeps the phase it follows
      final prevRace = j > 0 && block[j - 1].intensity == 'race';
      if (last != null && (r < last || prevRace) && !sameDay(_monday(block[j].date), _monday(block[j - 1].date))) {
        cands.add(dayOnly(block[j].date));
      }
      last = r;
    }
    for (final start in cands.reversed.take(4)) {
      final mine = block.where((p) => !dayOnly(p.date).isBefore(start)).toList();
      final weeks = daysBetween(_monday(start), _monday(mine.last.date)) ~/ 7 + 1;
      final gen = _gen(profile, start, max(1, weeks.round()), gymHistory: gymHistoryBefore(plans, sessions, start));
      final phaseOf = <String, String>{
        for (final p in gen)
          if (p.intensity != 'race') dayKey(_monday(p.date)): p.phase ?? '',
      };
      final agree = mine.where((p) => p.intensity == 'race' || phaseOf[dayKey(_monday(p.date))] == p.phase).length;
      if (agree >= 0.75 * mine.length) return gen;
    }
    return null;
  }

  /// The profile for a continuation from [start]: the volume the plan reached in its last
  /// loading weeks ([before]: the rebuilt plan) is the new start volume (no jump back to the
  /// setup values, no jump up).
  UserProfile _continuation(DateTime start, List<PlannedWorkout> before) {
    final from = _add(start, -28);
    final recent = before.where((p) => !dayOnly(p.date).isBefore(from) && dayOnly(p.date).isBefore(start) && p.intensity != 'race');
    final loading = recent.where((p) => p.phase != 'recovery' && p.phase != 'taper').toList();
    final weeks = <String, Map<Sport, double>>{};
    for (final p in loading) {
      final w = weeks.putIfAbsent(dayKey(_monday(p.date)), () => {});
      final v = p.sport == Sport.ride ? p.durationMin / 60 : (p.distanceKm ?? 0);
      w[p.sport] = (w[p.sport] ?? 0) + v;
    }
    double top(Sport s) => weeks.values.fold<double>(0, (x, w) => max(x, w[s] ?? 0));
    final longest = recent.where((p) => p.sport == Sport.run).fold<double>(0, (x, p) => max(x, p.distanceKm ?? 0));
    final run = top(Sport.run), ride = top(Sport.ride), swim = top(Sport.swim);
    final a = profile.athlete;
    return profile.copyWith(
      athlete: a.merge({
        if (run > 0) 'runWeeklyKm': double.parse(run.toStringAsFixed(1)),
        if (longest > 0) 'longestRunKm': longest,
        if (ride > 0) 'bikeWeeklyHours': double.parse(ride.toStringAsFixed(1)),
        if (swim > 0) 'swimWeeklyKm': double.parse(swim.toStringAsFixed(1)),
      }),
    );
  }
}
