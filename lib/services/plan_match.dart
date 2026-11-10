import '../core/format.dart';
import '../data/models.dart';
import 'zones.dart';

/// The planned workout a recorded session fulfils: the explicitly linked plan, else an
/// open plan of the same sport on the same day (closest planned duration first).
/// Used when saving a live session, a manual entry and a watch import.
/// An explicitly linked plan only counts within ±1 day ([linkDays]) – a workout started
/// early from next Saturday's long run must not tick Saturday off by itself; the athlete is
/// asked instead ([replacementCandidate]).
PlannedWorkout? matchPlan(Session s, List<PlannedWorkout> plans) {
  if (s.planId != null) {
    final p = plans.where((p) => p.id == s.planId).firstOrNull;
    if (p != null && withinLinkDays(p.date, s.start)) return p;
  }
  final open = plans.where((p) => p.status == 'planned' && p.sport == s.sport && sameDay(p.date, s.start)).toList();
  if (open.isEmpty) return null;
  open.sort((a, b) => (a.durationMin - s.minutes).abs().compareTo((b.durationMin - s.minutes).abs()));
  return open.first;
}

/// How far (days) a session may be from its planned workout to fulfil it automatically.
const linkDays = 1;

bool withinLinkDays(DateTime plan, DateTime session) => daysBetween(plan, session).abs() <= linkDays;

/// The planned workout a session was started from but that lies more than [linkDays] away and
/// is still open – "count it as a replacement for the long run (Sat)?". Null otherwise.
PlannedWorkout? replacementCandidate(Session s, List<PlannedWorkout> plans) {
  if (s.planId == null) return null;
  final p = plans.where((p) => p.id == s.planId).firstOrNull;
  if (p == null || p.status != 'planned' || withinLinkDays(p.date, s.start)) return null;
  return p;
}

/// Whether two sessions of the same sport overlap in time (the watch and the phone
/// recorded the same workout). A few minutes of tolerance cover clocks / start delays.
bool sameWorkout(Session a, Session b) {
  if (a.sport != b.sport) return false;
  const slack = Duration(minutes: 5);
  final aEnd = a.start.add(Duration(seconds: a.durationSec)), bEnd = b.start.add(Duration(seconds: b.durationSec));
  return a.start.isBefore(bEnd.add(slack)) && b.start.isBefore(aEnd.add(slack));
}

/// Perceived exertion (1–10) estimated from the average heart rate of an imported
/// workout, so its training load (minutes × RPE) reflects how hard it really was instead
/// of a flat default. Uses the athlete's HR zones (Karvonen when resting HR is known).
int? rpeFromHr(int? avgHr, UserProfile p) {
  if (avgHr == null || avgHr <= 0) return null;
  final z = HrZones(p.estimatedMaxHr, p.athlete.restHr);
  final zone = z.zoneOf(avgHr);
  // Position inside the zone refines the value (e.g. high zone 2 → 4, low zone 2 → 3).
  final (lo, hi) = z.zone(zone);
  final frac = hi > lo ? ((avgHr - lo) / (hi - lo)).clamp(0.0, 1.0) : 0.0;
  const base = {1: 2, 2: 3, 3: 5, 4: 7, 5: 8};
  return (base[zone]! + (frac >= 0.5 ? 1 : 0)).clamp(1, 10);
}
