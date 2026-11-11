import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'plan_generator.dart';

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
/// ([weeks] 0: the plan is not rule-based – no gap detection).
UserProfile withPlanMeta(UserProfile p, DateTime start, int weeks) =>
    p.copyWith(athlete: p.athlete.merge({'planStart': dayOnly(start), 'planLength': weeks}));

/// The profile for a plan re-created mid-plan ("Plan neu aufsetzen", "align plan with goal") from
/// [start]: the weekly volume and the longest run the athlete actually reached in the 4 weeks before
/// it replace the setup values (runWeeklyKm, longestRunKm, bikeWeeklyHours, swimWeeklyKm) – the new
/// plan continues from there instead of restarting at the setup's volume (like [PlanGaps]' continuation,
/// but from the done sessions). Weekly volume: the highest loading week (the plan's recovery / taper
/// weeks don't count); longest run: the longest run of the 4 weeks. Unchanged without ≥ 2 weeks of a
/// generated plan before [start] (a fresh setup keeps what the athlete entered).
UserProfile withReachedVolume(
  UserProfile p, {
  required List<PlannedWorkout> plans,
  required List<Session> sessions,
  required DateTime start,
}) {
  final day = dayOnly(start);
  final from = addDays(day, -28);
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
  PlanGaps(this.l, this.profile, {required this.plans, required this.now, this.templates = const [], String Function()? newId})
    : _newId = newId ?? (() => 'gap${_seq++}');

  final AppLocalizations l;
  final UserProfile profile;
  final List<PlannedWorkout> plans;
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
          final why = ext.contains(p.id) ? GapWhy.planEnded : (have.isEmpty ? GapWhy.emptyWeek : GapWhy.missing);
          out.add(GapFill(PlannedWorkout.fromMap(_newId(), p.toMap()), why, budgetKey: key));
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
        final next = _gen(_continuation(start, out), start, weeks);
        if (next.isEmpty) break;
        out.addAll(next);
        ext.addAll(next.map((p) => p.id));
        if (next.any((p) => p.intensity == 'race') || (ev != null && !eventAhead)) break;
        start = _add(_monday(next.last.date), 7);
      }
    }
    return (out, ext);
  }

  List<PlannedWorkout> _gen(UserProfile p, DateTime start, int weeks) =>
      PlanGenerator(l, p, templates, () => 'ref${_refSeq++}').generate(start: start, weeks: weeks);

  /// The plan from its stored start, else from the start that reproduces the phases of the
  /// generated workouts best (≥ 75 % agree).
  List<PlannedWorkout>? _anchor(List<PlannedWorkout> phased) {
    final a = profile.athlete;
    if (a.planStart != null && (a.planLength ?? 0) > 0 && phased.any((p) => !dayOnly(p.date).isBefore(dayOnly(a.planStart!)))) {
      return _gen(profile, dayOnly(a.planStart!), a.planLength!);
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
      final gen = _gen(profile, start, max(1, weeks.round()));
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
