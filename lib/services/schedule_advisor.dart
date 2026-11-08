import 'dart:math';

import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';

/// Recommends how often to train each sport per week and builds an optimal weekday
/// layout ("Auto" button in the setup). Rules (docs/training-science.md):
///
/// * Endurance frequency by level: beginners 3 runs/rides, intermediate 4, advanced 5
///   (+1 run for half/full marathon); swimming 2/3/4 – technique needs frequency.
/// * Multi-sport: triathlon ~2–3 per discipline; hybrid (run + gym) 3 + 2–3.
/// * Strength for endurance athletes: 2×/week improves economy and lowers injury
///   risk (Blagrove 2018, Lauersen 2014); strength focus: 3–5×/week.
/// * Rest: beginners ≥ 2 rest days, others ≥ 1 (recovery, H1).
class ScheduleAdvisor {
  ScheduleAdvisor(this.profile, this.sports);
  final UserProfile profile;
  final Set<Sport> sports;

  AthleteData get a => profile.athlete;
  int get _lv => switch (profile.level) {
    'advanced' => 2,
    'intermediate' => 1,
    _ => 0,
  };

  bool get _strengthGoal => profile.goals.contains('strength') || profile.goals.contains('muscle');

  /// Maximum number of training days per week (keeps rest days).
  int get maxDays => _lv == 0 ? 5 : 6;

  /// Recommended sessions per week for each selected sport.
  Map<Sport, int> recommended() {
    final lv = _lv;
    final multi = sports.where((s) => s != Sport.gym).length;
    final res = <Sport, int>{};
    for (final s in sports) {
      res[s] = switch (s) {
        Sport.gym when multi == 0 => _strengthGoal ? const [3, 4, 4][lv] : const [2, 3, 3][lv],
        Sport.gym when profile.focus == TrainingFocus.hybrid => const [2, 3, 3][lv],
        Sport.gym => _strengthGoal ? 2 : (lv == 0 ? 1 : 2),
        Sport.run when multi >= 3 => const [2, 3, 3][lv],
        Sport.run when multi == 2 => const [2, 3, 3][lv],
        Sport.run when profile.focus == TrainingFocus.hybrid => const [3, 3, 4][lv],
        Sport.run => const [3, 4, 5][lv] + ((a.eventDistance == 'hm' || a.eventDistance == 'm') && lv > 0 ? 1 : 0),
        Sport.ride when multi >= 2 => const [2, 3, 3][lv],
        Sport.ride => const [3, 4, 5][lv],
        Sport.swim when multi >= 2 => const [2, 2, 3][lv],
        Sport.swim => const [2, 3, 4][lv],
      };
    }
    // Fit into the available sessions (days × sessions/day, keep rest days).
    final cap = maxDays * a.sessionsPerDay;
    var total = res.values.fold<int>(0, (x, y) => x + y);
    while (total > cap) {
      // Trim the sport with the most sessions (gym last for endurance focus).
      final s = res.entries.reduce((x, y) => x.value > y.value || (x.value == y.value && y.key == Sport.gym) ? x : y).key;
      res[s] = res[s]! - 1;
      total--;
    }
    res.removeWhere((_, v) => v <= 0);
    return res;
  }

  /// Builds a weekday → sports layout for [freq].
  ///
  /// Long endurance session on the preferred long day (default Saturday), key
  /// endurance days spread out, gym away from the day before the long session, and
  /// same-sport sessions on non-consecutive days where possible.
  Map<int, List<Sport>> autoSchedule(Map<Sport, int> freq) {
    final perDay = a.sessionsPerDay;
    final total = freq.values.fold<int>(0, (x, y) => x + y);
    final nDays = min(maxDays, max((total / perDay).ceil(), min(total, maxDays)));
    final days = _spreadDays(nDays);
    final plan = {for (final d in days) d: <Sport>[]};

    final endurance =
        [Sport.run, Sport.ride, Sport.swim].where((s) => (freq[s] ?? 0) > 0).toList()..sort((x, y) => freq[y]!.compareTo(freq[x]!));
    final main = endurance.isEmpty ? null : _mainSport(endurance);
    final longDay = profile.longDay != null && days.contains(profile.longDay) ? profile.longDay! : (days.contains(6) ? 6 : days.last);

    bool canAdd(int d, Sport s) => plan[d]!.length < perDay && !plan[d]!.contains(s);
    int load(int d) => plan[d]!.length;

    void place(Sport s, int n, {int? first}) {
      final placed = <int>[];
      if (first != null && canAdd(first, s)) {
        plan[first]!.add(s);
        placed.add(first);
      }
      while (placed.length < n) {
        // Best day: free capacity, far from other sessions of the same sport, low load.
        int? best;
        double bestScore = -1e9;
        for (final d in days) {
          if (!canAdd(d, s)) continue;
          final gap = placed.isEmpty ? 3 : placed.map((p) => _circDist(p, d)).reduce(min);
          var score = gap * 10.0 - load(d) * 6;
          if (s == Sport.gym && d == longDay - 1) score -= 25; // C3: no legs before the long session
          if (s == Sport.gym && d == longDay) score -= 8;
          if (s != Sport.gym && s != main && d == longDay) score -= 12;
          if (score > bestScore) {
            bestScore = score;
            best = d;
          }
        }
        if (best == null) break;
        plan[best]!.add(s);
        placed.add(best);
      }
    }

    if (main != null) place(main, freq[main]!, first: longDay);
    for (final s in endurance.where((s) => s != main)) {
      place(s, freq[s]!);
    }
    if ((freq[Sport.gym] ?? 0) > 0) place(Sport.gym, freq[Sport.gym]!);
    plan.removeWhere((_, v) => v.isEmpty);
    // Keep a stable order inside a day: endurance first, gym last.
    for (final v in plan.values) {
      v.sort((x, y) => (x == Sport.gym ? 1 : 0).compareTo(y == Sport.gym ? 1 : 0));
    }
    return plan;
  }

  Sport _mainSport(List<Sport> endurance) => switch (profile.focus) {
    TrainingFocus.triathlon ||
    TrainingFocus.duathlon ||
    TrainingFocus.ride => endurance.contains(Sport.ride) ? Sport.ride : endurance.first,
    TrainingFocus.swim => endurance.contains(Sport.swim) ? Sport.swim : endurance.first,
    _ => endurance.contains(Sport.run) ? Sport.run : endurance.first,
  };

  static int _circDist(int a, int b) {
    final d = (a - b).abs();
    return min(d, 7 - d);
  }

  /// Picks [n] weekdays spread over the week (rest days distributed, weekend kept).
  static List<int> _spreadDays(int n) => switch (n) {
    <= 1 => [6],
    2 => [3, 6],
    3 => [2, 4, 6],
    4 => [2, 4, 6, 7],
    5 => [1, 2, 4, 6, 7],
    6 => [1, 2, 3, 5, 6, 7],
    _ => [1, 2, 3, 4, 5, 6, 7],
  };

  /// Recommended split for the gym days in [plan].
  String splitFor(Map<int, List<Sport>> plan) {
    final gym = plan.values.where((v) => v.contains(Sport.gym)).length;
    final endurance = plan.values.expand((v) => v).where((s) => s != Sport.gym).length;
    return recommendedSplit(gym, enduranceSessions: endurance);
  }
}
