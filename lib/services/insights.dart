import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';

// ───────────────────────────── XP & levels ─────────────────────────────

/// XP rewards effort (time × intensity) plus sport specific output.
int xpForSession(Session s) {
  final intensity = 0.6 + (s.rpe ?? 6) / 10; // 0.7 … 1.6
  var xp = s.minutes * intensity;
  switch (s.sport) {
    case Sport.gym:
      xp += s.volume / 400 + s.setsDone * 1.5;
    case Sport.run:
      xp += s.distanceM / 1000 * 8;
    case Sport.ride:
      xp += s.distanceM / 1000 * 2.5;
    case Sport.swim:
      xp += s.distanceM / 100 * 3;
  }
  return max(5, xp.round());
}

/// Cumulative XP needed to reach [level] (level 1 = 0 XP).
int xpForLevel(int level) => 60 * level * (level - 1);

class LevelInfo {
  final int level;
  final int xp;
  const LevelInfo(this.level, this.xp);

  factory LevelInfo.fromXp(int xp) {
    var l = 1;
    while (xpForLevel(l + 1) <= xp) {
      l++;
    }
    return LevelInfo(l, xp);
  }

  int get floor => xpForLevel(level);
  int get ceil => xpForLevel(level + 1);
  double get progress => (xp - floor) / (ceil - floor);
  int get remaining => ceil - xp;
}

// ───────────────────────────── Badges ─────────────────────────────

class BadgeDef {
  final String id;
  final IconData icon;
  final Color color;
  const BadgeDef(this.id, this.icon, this.color);
}

class Achievement {
  final BadgeDef def;
  final bool earned;
  final double progress; // 0..1
  const Achievement(this.def, this.earned, this.progress);
}

const badgeDefs = [
  BadgeDef('first', Icons.flag_rounded, Color(0xFF8B7CFF)),
  BadgeDef('ten', Icons.looks_one_rounded, Color(0xFF8B7CFF)),
  BadgeDef('fifty', Icons.military_tech_rounded, Color(0xFFB59CFF)),
  BadgeDef('hundred', Icons.workspace_premium_rounded, Color(0xFFFFD166)),
  BadgeDef('ton', Icons.fitness_center_rounded, Color(0xFFFF6B3D)),
  BadgeDef('k5', Icons.directions_run_rounded, Color(0xFF2FD38A)),
  BadgeDef('k10', Icons.directions_run_rounded, Color(0xFF2FD38A)),
  BadgeDef('half', Icons.emoji_events_rounded, Color(0xFF2FD38A)),
  BadgeDef('marathon', Icons.emoji_events_rounded, Color(0xFFFFD166)),
  BadgeDef('century', Icons.directions_bike_rounded, Color(0xFFFFB627)),
  BadgeDef('swim1k', Icons.pool_rounded, Color(0xFF3DB2FF)),
  BadgeDef('swim3k', Icons.waves_rounded, Color(0xFF3DB2FF)),
  BadgeDef('streak4', Icons.local_fire_department_rounded, Color(0xFFFF4D6D)),
  BadgeDef('streak12', Icons.whatshot_rounded, Color(0xFFFF4D6D)),
  BadgeDef('early', Icons.wb_twilight_rounded, Color(0xFFFFB627)),
  BadgeDef('allround', Icons.diversity_3_rounded, Color(0xFF8B7CFF)),
];

// ───────────────────────────── Aggregated stats ─────────────────────────────

/// Training days done vs. the goal of one week.
class WeekGoal {
  const WeekGoal(this.week, this.done, this.goal);
  final DateTime week;
  final int done;
  final int goal;
  bool get met => done >= goal;
}

class GameStats {
  final int totalXp;
  final LevelInfo level;
  final Map<Sport, LevelInfo> sportLevels;
  final int weekStreak;
  final List<Achievement> badges;
  final Map<String, int> xpBySession;

  const GameStats({
    required this.totalXp,
    required this.level,
    required this.sportLevels,
    required this.weekStreak,
    required this.badges,
    required this.xpBySession,
  });

  static GameStats compute(List<Session> sessions, int weeklyTarget, {List<PlannedWorkout> plans = const []}) {
    final xpBy = <String, int>{};
    final sportXp = {for (final s in Sport.values) s: 0};
    var total = 0;
    for (final s in sessions) {
      final x = xpForSession(s);
      xpBy[s.id] = x;
      sportXp[s.sport] = sportXp[s.sport]! + x;
      total += x;
    }
    final streak = computeWeekStreak(sessions, weeklyTarget, plans: plans);
    return GameStats(
      totalXp: total,
      level: LevelInfo.fromXp(total),
      sportLevels: sportXp.map((k, v) => MapEntry(k, LevelInfo.fromXp(v))),
      weekStreak: streak,
      badges: _badges(sessions, streak),
      xpBySession: xpBy,
    );
  }

  /// Training-day goal of the week starting [week]: the number of days with planned
  /// workouts when a plan exists for that week (so a plan with two sessions on one day
  /// or a lighter recovery week is judged fairly), else the profile's training days.
  static int weekGoal(DateTime week, int target, List<PlannedWorkout> plans) {
    final end = addDays(week, 7);
    final planned = {
      for (final p in plans)
        if (!p.date.isBefore(week) && p.date.isBefore(end)) dayOnly(p.date),
    };
    return max(1, planned.isNotEmpty ? min(planned.length, max(1, target)) : target);
  }

  /// Done training days vs. goal for the last [weeks] weeks (oldest first, current last).
  static List<WeekGoal> weekHistory(List<Session> sessions, int target, {List<PlannedWorkout> plans = const [], int weeks = 8}) {
    final days = <DateTime, Set<DateTime>>{};
    for (final s in sessions) {
      days.putIfAbsent(startOfWeek(s.start), () => {}).add(dayOnly(s.start));
    }
    final now = startOfWeek(DateTime.now());
    return [
      for (var i = weeks - 1; i >= 0; i--)
        () {
          final w = addDays(now, -7 * i);
          return WeekGoal(w, days[w]?.length ?? 0, weekGoal(w, target, plans));
        }(),
    ];
  }

  /// Consecutive weeks (ending this week) in which the weekly goal was met.
  /// The current week only counts once the goal is reached, but never breaks the streak.
  static int computeWeekStreak(List<Session> sessions, int target, {List<PlannedWorkout> plans = const []}) {
    final h = weekHistory(sessions, target, plans: plans, weeks: 160);
    var streak = h.last.met ? 1 : 0;
    for (var i = h.length - 2; i >= 0 && h[i].met; i--) {
      streak++;
    }
    return streak;
  }

  static List<Achievement> _badges(List<Session> s, int streak) {
    double best(Sport sp) => s.where((e) => e.sport == sp).fold(0.0, (a, e) => max(a, e.distanceM));
    final maxVol = s.fold(0.0, (a, e) => max(a, e.volume));
    final sports = s.map((e) => e.sport).toSet().length;
    final early = s.any((e) => e.start.hour < 7);
    Achievement b(String id, double value, double target) {
      final def = badgeDefs.firstWhere((d) => d.id == id);
      return Achievement(def, value >= target, (value / target).clamp(0, 1).toDouble());
    }

    return [
      b('first', s.length.toDouble(), 1),
      b('ten', s.length.toDouble(), 10),
      b('fifty', s.length.toDouble(), 50),
      b('hundred', s.length.toDouble(), 100),
      b('ton', maxVol, 10000),
      b('k5', best(Sport.run), 5000),
      b('k10', best(Sport.run), 10000),
      b('half', best(Sport.run), 21097),
      b('marathon', best(Sport.run), 42195),
      b('century', best(Sport.ride), 100000),
      b('swim1k', best(Sport.swim), 1000),
      b('swim3k', best(Sport.swim), 3000),
      b('streak4', streak.toDouble(), 4),
      b('streak12', streak.toDouble(), 12),
      b('early', early ? 1 : 0, 1),
      b('allround', sports.toDouble(), 4),
    ];
  }
}

// ───────────────────────────── Recovery / readiness ─────────────────────────────

enum Readiness { building, fresh, optimal, high, overreaching }

class RecoveryInfo {
  final double acute; // 7-day load
  final double chronic; // 28-day weekly average
  final Readiness readiness;
  final int daysSinceRest;
  const RecoveryInfo(this.acute, this.chronic, this.readiness, this.daysSinceRest);

  /// Acute:chronic workload ratio (Gabbett 2016). Sweet spot ≈ 0.8 – 1.3.
  double get ratio => chronic <= 0 ? (acute > 0 ? 1.5 : 0) : acute / chronic;

  static RecoveryInfo compute(List<Session> sessions) {
    final now = DateTime.now();
    double sum(int days) => sessions.where((s) => now.difference(s.start).inDays < days).fold(0.0, (a, s) => a + s.load); // time span
    final acute = sum(7);
    final chronic = sum(28) / 4;
    final ratio = chronic <= 0 ? (acute > 0 ? 1.0 : 0.0) : acute / chronic;
    var consecutive = 0;
    final days = sessions.map((s) => dayOnly(s.start)).toSet();
    var d = dayOnly(now);
    if (!days.contains(d)) d = addDays(d, -1);
    while (days.contains(d)) {
      consecutive++;
      d = addDays(d, -1);
    }
    // ACWR needs a baseline: with less than 3 weeks of history the ratio is meaningless.
    final oldest = sessions.isEmpty ? now : sessions.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    if (daysBetween(oldest, now) < 21) {
      return RecoveryInfo(acute, chronic, consecutive >= 6 ? Readiness.overreaching : Readiness.building, consecutive);
    }
    final r =
        ratio < 0.8
            ? Readiness.fresh
            : ratio <= 1.3
            ? Readiness.optimal
            : ratio <= 1.5
            ? Readiness.high
            : Readiness.overreaching;
    return RecoveryInfo(acute, chronic, consecutive >= 6 ? Readiness.overreaching : r, consecutive);
  }
}

// ───────────────────────────── Records ─────────────────────────────

class ExerciseRecord {
  final String exId;
  final String name;
  final double bestE1rm;
  final double maxWeight;
  final int maxReps;
  final DateTime date;
  final int sessions;
  const ExerciseRecord(this.exId, this.name, this.bestE1rm, this.maxWeight, this.maxReps, this.date, this.sessions);
}

Map<String, ExerciseRecord> exerciseRecords(List<Session> sessions) {
  final out = <String, ExerciseRecord>{};
  for (final s in sessions.reversed) {
    for (final e in s.exercises) {
      final prev = out[e.exId];
      final best = e.bestE1rm;
      final maxW = e.maxWeight;
      final maxR = e.sets.where((x) => x.done).fold(0, (a, x) => max(a, x.reps));
      if (best <= 0 && maxR <= 0) continue;
      if (prev == null) {
        out[e.exId] = ExerciseRecord(e.exId, e.name, best, maxW, maxR, s.start, 1);
      } else {
        out[e.exId] = ExerciseRecord(
          e.exId,
          e.name,
          max(prev.bestE1rm, best),
          max(prev.maxWeight, maxW),
          max(prev.maxReps, maxR),
          best > prev.bestE1rm ? s.start : prev.date,
          prev.sessions + 1,
        );
      }
    }
  }
  return out;
}

/// Per-session best e1RM history of one exercise (oldest first).
List<(DateTime, double)> e1rmHistory(List<Session> sessions, String exId) {
  final out = <(DateTime, double)>[];
  for (final s in sessions.reversed) {
    for (final e in s.exercises.where((e) => e.exId == exId)) {
      if (e.bestE1rm > 0) out.add((s.start, e.bestE1rm));
    }
  }
  return out;
}

/// Exercises in [current] that beat all previous sessions (new e1RM record).
List<String> newPrs(Session current, List<Session> history) {
  final prev = exerciseRecords(history.where((s) => s.id != current.id && s.start.isBefore(current.start)).toList());
  return current.exercises
      .where((e) => e.bestE1rm > 0 && (prev[e.exId] == null || e.bestE1rm > prev[e.exId]!.bestE1rm + 0.01))
      .map((e) => e.name)
      .toList();
}

/// Last set values of an exercise from history, used as "previous" hints.
List<GymSet>? lastSetsFor(List<Session> sessions, String exId) {
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (e.exId == exId && e.sets.any((x) => x.done)) return e.sets.where((x) => x.done).toList();
    }
  }
  return null;
}

/// Previous comparable session (same template or same title & sport).
Session? previousComparable(Session s, List<Session> all) {
  for (final o in all) {
    if (o.id == s.id || !o.start.isBefore(s.start) || o.sport != s.sport) continue;
    if ((s.templateId != null && o.templateId == s.templateId) || o.title == s.title) return o;
  }
  return null;
}

/// Average number of distinct gym days per month (over months with data, max 12).
double avgGymDaysPerMonth(List<Session> sessions) {
  final byMonth = <String, Set<int>>{};
  for (final s in sessions.where((s) => s.sport == Sport.gym)) {
    byMonth.putIfAbsent('${s.start.year}-${s.start.month}', () => {}).add(s.start.day);
  }
  if (byMonth.isEmpty) return 0;
  final months = byMonth.values.take(12).toList();
  return months.fold<int>(0, (a, m) => a + m.length) / months.length;
}

// ───────────────────────────── Running best efforts & predictions ─────────────────────────────

class BestEffort {
  final String key; // 1k | 5k | 10k | hm | m
  final double meters;
  final int seconds;
  final Session session;
  const BestEffort(this.key, this.meters, this.seconds, this.session);
}

const bestEffortDistances = {'1k': 1000.0, '5k': 5000.0, '10k': 10000.0, 'hm': 21097.5, 'm': 42195.0};

/// Fastest efforts from km splits (rolling windows) or, without splits, whole runs
/// scaled to the distance (Strava-style "best efforts").
Map<String, BestEffort> runBestEfforts(List<Session> sessions) {
  final out = <String, BestEffort>{};
  void consider(String k, int sec, Session s) {
    final cur = out[k];
    if (sec > 0 && (cur == null || sec < cur.seconds)) out[k] = BestEffort(k, bestEffortDistances[k]!, sec, s);
  }

  for (final s in sessions.where((s) => s.sport == Sport.run && !s.indoor)) {
    for (final e in bestEffortDistances.entries) {
      final km = (e.value / 1000).floor();
      if (s.splits.length >= km && km >= 1) {
        var best = 1 << 30;
        for (var i = 0; i + km <= s.splits.length; i++) {
          final sum = s.splits.sublist(i, i + km).fold<int>(0, (a, b) => a + b);
          best = min(best, sum);
        }
        consider(e.key, (best * e.value / (km * 1000)).round(), s);
      } else if (s.splits.isEmpty && s.distanceM >= e.value && s.distanceM < e.value * 1.25) {
        consider(e.key, (s.durationSec * e.value / s.distanceM).round(), s);
      }
    }
  }
  return out;
}

// ───────────────────────────── Fitness / fatigue / form (Banister) ─────────────────────────────

class FitnessPoint {
  final DateTime day;
  final double fitness; // CTL, τ = 42 d
  final double fatigue; // ATL, τ = 7 d
  double get form => fitness - fatigue; // TSB
  const FitnessPoint(this.day, this.fitness, this.fatigue);
}

/// Daily training stress ≈ session-RPE load / 6 (≈ TSS scale), see training-science §3.4.
List<FitnessPoint> fitnessSeries(List<Session> sessions, {int days = 90}) {
  if (sessions.isEmpty) return const [];
  final byDay = <DateTime, double>{};
  for (final s in sessions) {
    byDay.update(dayOnly(s.start), (v) => v + s.load / 6, ifAbsent: () => s.load / 6);
  }
  final first = byDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  final today = dayOnly(DateTime.now());
  final kC = 1 - exp(-1 / 42), kA = 1 - exp(-1 / 7);
  var ctl = 0.0, atl = 0.0;
  final out = <FitnessPoint>[];
  for (var d = first; !d.isAfter(today); d = addDays(d, 1)) {
    final tss = byDay[d] ?? 0;
    ctl += (tss - ctl) * kC;
    atl += (tss - atl) * kA;
    if (daysBetween(d, today) < days) out.add(FitnessPoint(d, ctl, atl));
  }
  return out;
}
