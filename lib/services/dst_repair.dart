import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';

/// One-off repair of plans generated before the DST fix (see [addDays]).
///
/// The generator used to compute every day as `monday + n × 24 h`. Planned workouts are
/// stored as day keys ("yyyy-MM-dd"), so the time never reached Firestore – but once a plan
/// crossed the autumn clock change (e.g. 25 Oct 2026 in Europe), `monday + n × 24 h` was
/// 23:00 of the day before, and every workout from then until the spring change was stored
/// **one day early** (the spring change only moves midnight to 01:00 – same day, harmless).
///
/// The repair replays that arithmetic for the stored plan ([AthleteData.planStart] /
/// [AthleteData.planLength]) in the device's time zone to find the stored days that are
/// shifted, and moves the not-done workouts there one day later – but only when the plan
/// itself confirms the shift: its workouts after the clock change sit on the day *before*
/// the weekday/sport pattern of its weeks before the change (or of the profile's week plan)
/// clearly more often than on it. That check also makes the repair idempotent: once moved,
/// the workouts match the pattern again and nothing is changed a second time.
///
/// Done workouts keep their date: the athlete trained on the day the calendar showed and the
/// session is linked to it. There is nothing to "normalise" in stored data – the day keys
/// carry no time of day; the wrong part is the key itself.
class DstRepair {
  DstRepair._();

  /// The old (buggy) day of plan offset [n] from [monday].
  static DateTime legacyDay(DateTime monday, int n) => monday.add(Duration(days: n)); // time span – replays the old bug

  /// Stored (shifted) day key → intended day key, for the plan from [planStart] over [weeks].
  static Map<String, String> shiftedKeys(DateTime planStart, int weeks) {
    final monday = startOfWeek(planStart);
    final out = <String, String>{};
    for (var n = 0; n < (weeks + 1) * 7; n++) {
      final old = dayKey(legacyDay(monday, n)), right = dayKey(addDays(monday, n));
      if (old != right) out[old] = right;
    }
    return out;
  }

  /// Plan id → `{'date': intended day}` for the workouts to move (empty: nothing to repair).
  static Map<String, Map<String, dynamic>> updates(List<PlannedWorkout> plans, UserProfile profile) {
    final a = profile.athlete;
    final start = a.planStart, weeks = a.planLength;
    if (start == null || weeks == null || weeks <= 0) return const {};
    final shift = shiftedKeys(start, weeks);
    if (shift.isEmpty) return const {};
    final monday = startOfWeek(start), end = addDays(monday, (weeks + 1) * 7);
    final generated = plans.where((p) => p.phase != null && !p.date.isBefore(monday) && p.date.isBefore(end)).toList();
    // First shifted stored day: it may also hold the genuine workouts of that day.
    final keys = shift.keys.toList()..sort();
    final boundary = keys.first;
    final firstShifted = parseDayKey(boundary);

    // Weekday → sports of the plan before the clock change (else the profile's week plan).
    final pattern = <int, Map<String, int>>{};
    void add(int wd, String sport) => pattern.putIfAbsent(wd, () => {}).update(sport, (v) => v + 1, ifAbsent: () => 1);
    for (final p in generated.where((p) => p.date.isBefore(firstShifted))) {
      add(p.date.weekday, p.sport.name);
    }
    if (pattern.values.fold<int>(0, (x, m) => x + m.values.fold(0, (y, v) => y + v)) < 3) {
      pattern.clear();
      if (a.dayPlan.values.any((v) => v.isNotEmpty)) {
        for (final e in a.dayPlan.entries) {
          for (final s in e.value) {
            add(e.key, s.name);
          }
        }
      } else {
        for (final d in profile.trainingDays) {
          for (final s in profile.focus.sports) {
            add(d, s.name);
          }
        }
      }
    }
    bool fits(int wd, String sport) => pattern[(wd - 1) % 7 + 1]?.containsKey(sport) ?? false;

    // Evidence from the unambiguous shifted days: on the pattern vs. one day before it.
    final after = generated.where((p) => shift.containsKey(dayKey(p.date)) && dayKey(p.date) != boundary).toList();
    if (after.isEmpty) return const {};
    var onPattern = 0, dayBefore = 0;
    for (final p in after) {
      if (fits(p.date.weekday, p.sport.name)) onPattern++;
      if (fits(p.date.weekday + 1, p.sport.name)) dayBefore++;
    }
    if (dayBefore <= onPattern || dayBefore < 0.6 * after.length) return const {};

    final out = <String, Map<String, dynamic>>{};
    for (final p in after) {
      if (!p.isDone) out[p.id] = {'date': shift[dayKey(p.date)]};
    }
    // The boundary day: move the workouts that belong to the next day's pattern only, or –
    // when both days fit – the ones beyond what that day normally holds.
    final onBoundary = generated.where((p) => dayKey(p.date) == boundary).toList();
    final wd = firstShifted.weekday;
    final perSport = <String, int>{};
    for (final p in onBoundary) {
      final s = p.sport.name;
      final cur = fits(wd, s), next = fits(wd + 1, s);
      perSport[s] = (perSport[s] ?? 0) + 1;
      final usual = cur ? 1 : 0;
      final move = next && (!cur || perSport[s]! > usual);
      if (move && !p.isDone) out[p.id] = {'date': shift[boundary]};
    }
    return out;
  }
}
