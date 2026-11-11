import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/event_spec.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Peak long sessions per race distance and level (user report 2026-11: "longest marathon run 22.5 km",
/// "raise Saturday to 8 h 45"): with time enough the peak long session reaches what the race needs
/// (established amateur practice), never beyond a sensible duration, and a suggested day time is a
/// session length – never an inflated day.
final _start = DateTime(2026, 11, 9); // Monday
DateTime _race(int weeks) => DateTime(_start.year, _start.month, _start.day + 7 * (weeks - 1) + 6);

TrainingFocus _focus(EventSport s) => switch (s) {
  EventSport.run => TrainingFocus.run,
  EventSport.triathlon => TrainingFocus.triathlon,
  EventSport.duathlon => TrainingFocus.duathlon,
  EventSport.ride => TrainingFocus.ride,
  EventSport.swim => TrainingFocus.swim,
};

/// Peak long run (km) intermediate / advanced athletes with plenty of time reach – established practice:
/// 5 km 10–14, 10 km 13–18, HM 18–22, marathon ~28–35 (or ~3 h), ultra 30+ (or 3.5 h), 70.3 16–21,
/// Ironman 26–30 (or 2.5 h), duathlon ~1.2–1.5 × the run legs.
const _minRunKm = {
  '5k': 10.0,
  '10k': 13.0,
  'hm': 18.0,
  'm': 29.5,
  'ultra50': 30.0,
  'olympic': 10.0,
  '70.3': 16.0,
  'ironman': 27.5,
  'du_sprint': 7.0,
  'du_standard': 12.0,
};

UserProfile _p(String ev, String level, {required bool plenty, bool slow = false, TrainingFocus? focus, List<int>? days, int? weeks}) {
  final spec = EventSpec.of(ev)!;
  final f = focus ?? _focus(spec.sport);
  return UserProfile(
    level: level,
    focus: f,
    birthYear: DateTime.now().year - 35,
    experience: {...f.sports},
    trainingDays: days ?? const [1, 2, 4, 6, 7],
    goals: const ['race'],
    athlete: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: plenty ? 75 : 50,
      dayMinutes: plenty ? const {6: 420, 7: 240} : const {6: 120, 7: 90},
      raceTimes:
          slow
              ? const {'10k': 68 * 60}
              : switch (level) {
                'intermediate' => const {'10k': 52 * 60},
                'advanced' => const {'10k': 42 * 60},
                _ => const <String, int>{},
              },
      ftp: level == 'beginner' ? null : 220,
      eventDistance: ev,
      eventDate: _race(weeks ?? spec.weeksFor(level).$2),
    ),
  );
}

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  String id() => 'x';

  ({double runKm, int runMin, int rideMin, double swimM}) peaks(List<PlannedWorkout> plan) {
    var runKm = 0.0, swimM = 0.0;
    var runMin = 0, rideMin = 0;
    for (final w in plan.where((w) => w.intensity != 'race')) {
      if (w.sport == Sport.run && w.intensity == 'long') {
        runKm = max(runKm, w.distanceKm ?? 0);
        runMin = max(runMin, w.durationMin);
      }
      if (w.sport == Sport.ride && w.intensity == 'long') rideMin = max(rideMin, w.durationMin);
      if (w.sport == Sport.swim) {
        for (final s in w.steps.where((s) => s.isWork)) {
          swimM = max(swimM, s.distanceM ?? 0);
        }
      }
    }
    return (runKm: runKm, runMin: runMin, rideMin: rideMin, swimM: swimM);
  }

  test('with time enough the peak long session reaches the race need, never beyond a sensible duration', () {
    final fails = <String>[];
    for (final d in eventDistances) {
      final spec = EventSpec.of(d.key)!;
      for (final level in const ['beginner', 'intermediate', 'advanced']) {
        if (level == 'beginner' && !spec.beginnerOk) continue;
        for (final slow in const [false, true]) {
          final p = _p(d.key, level, plenty: true, slow: slow);
          final plan = PlanGenerator(l, p, const [], id).generate(start: _start);
          final pk = peaks(plan);
          final f = PlanGenerator.feasibility(p, start: _start, l: l);
          final tag = '${d.key}/$level${slow ? '/slow' : ''}: run ${pk.runKm} km/${pk.runMin}′ ride ${pk.rideMin}′ swim ${pk.swimM} m';
          // Never beyond a sensible duration: long run ≤ its cap (marathon / Ironman ~3 h, ultra 3.5 h, never
          // more than 3.5 h), long ride ≤ its cap (70.3 4 h, Ironman 6 h).
          if (pk.runMin > min(210, spec.longRunCapMin) + 5) fails.add('$tag – long run longer than its cap');
          if (pk.rideMin > spec.longRideCapMin) fails.add('$tag – long ride longer than its cap');
          // No blocking issue with plenty of time and the recommended weeks (notes and target checks aside).
          final blocking = f.issues.where((i) => !PlanFeasibility.notes.contains(i) && !i.startsWith('target')).toList();
          if (blocking.isNotEmpty) fails.add('$tag – warns $blocking');
          // The race's need.
          if (p.focus.sports.contains(Sport.run) && level != 'beginner' && !slow) {
            final need = _minRunKm[d.key];
            if (need != null && pk.runKm < need - 0.5 && !(spec.longRunMin != null && pk.runMin >= spec.longRunMin! - 10)) {
              fails.add('$tag – long run below $need km');
            }
          }
          if (spec.longRideMin != null && pk.rideMin < spec.longRideMin! * 0.9) fails.add('$tag – long ride below ${spec.longRideMin}′');
          if (spec.longSwimM != null && pk.swimM < spec.longSwimM! * 0.9) fails.add('$tag – long swim below ${spec.longSwimM} m');
        }
      }
    }
    expect(fails, isEmpty, reason: fails.join('\n'));
  });

  test('a suggested day time is the long session plus a small buffer – never an inflated day', () {
    final fails = <String>[];
    for (final d in eventDistances) {
      final spec = EventSpec.of(d.key)!;
      for (final level in const ['beginner', 'intermediate', 'advanced']) {
        if (level == 'beginner' && !spec.beginnerOk) continue;
        for (final plenty in const [false, true]) {
          for (final slow in const [false, true]) {
            final p = _p(d.key, level, plenty: plenty, slow: slow);
            final f = PlanGenerator.feasibility(p, start: _start, l: l);
            final tag = '${d.key}/$level/${plenty ? 'plenty' : 'tight'}${slow ? '/slow' : ''}: ${f.issues}';
            // Long session + brick run + the day's short sessions (≤ 60 min) – run ≤ 3.5 h + 1 h, ride ≤ cap + 2 h.
            final most = max(min(210, spec.longRunCapMin) + 60, spec.longRideCapMin + 120);
            for (final (day, m) in [(f.raiseDay, f.raiseDayMin), (f.raiseDay2, f.raiseDay2Min)]) {
              if (day == null || m == null) continue;
              if (m > most) fails.add('$tag – raise day $day to $m min');
              if (m <= PlanGenerator.dayMinutesFor(p, day)) fails.add('$tag – raise day $day to $m min, it already has that');
            }
            if (f.issues.contains('longRunTime') && f.raiseDay == null && f.moveDay == null) {
              // A day-time issue always says which day needs how much (unless the long day was not found).
              if (PlanGenerator.longSessionDays(p)[Sport.run] != null) fails.add('$tag – longRunTime without a day option');
            }
          }
        }
      }
    }
    expect(fails, isEmpty, reason: fails.join('\n'));
  });

  test('marathon / Ironman: peak 30–34 km (or 3 h on the feet) with 2–3 runs ≥ 28 km before the taper', () {
    // Long-run pace (s/km) as the generator plans it: the middle of the easy range.
    int pace(UserProfile p) {
      final pz = PaceZones(Vdot.of(p.athlete) ?? Vdot.defaultFor(p.level));
      return (pz.easyFast + pz.easySlow) ~/ 2;
    }

    final fails = <String>[];
    for (final ev in const ['m', 'ironman']) {
      for (final level in const ['intermediate', 'advanced']) {
        for (final tenK in const [0, 52, 48, 44, 40]) {
          for (final focus in ev == 'm' ? const [TrainingFocus.run, TrainingFocus.hybrid] : const [TrainingFocus.triathlon]) {
            for (final longest in const <double?>[null, 18]) {
              final spec = EventSpec.of(ev)!;
              // Recommended weeks; with a stated 18 km longest run also the user's 15 weeks (marathon).
              final weeks = longest != null && ev == 'm' ? 15 : spec.weeksFor(level).$2;
              final p = UserProfile(
                level: level,
                focus: focus,
                birthYear: DateTime.now().year - 35,
                experience: {...focus.sports},
                trainingDays: const [1, 2, 3, 4, 6, 7],
                goals: const ['race'],
                athlete: AthleteData(
                  setupMode: 'advanced',
                  sessionMinutes: 75,
                  dayMinutes: const {6: 420, 7: 240},
                  raceTimes: tenK == 0 ? const {} : {'10k': tenK * 60},
                  longestRunKm: longest,
                  runWeeklyKm: longest == null ? null : 40,
                  ftp: 220,
                  eventDistance: ev,
                  eventDate: _race(weeks),
                ),
              );
              final plan = PlanGenerator(l, p, const [], id).generate(start: _start);
              final longs = plan.where((w) => w.sport == Sport.run && w.intensity == 'long').map((w) => w.distanceKm ?? 0).toList();
              final peak = longs.fold(0.0, max);
              // What 3 h at the long-run pace covers (slower runners: time on feet decides).
              final byTime = 180 * 60 / pace(p);
              final want = ev == 'm' ? (level == 'advanced' ? 32.0 : 30.0) : (level == 'advanced' ? 30.0 : 28.0);
              final need = min(want, byTime) - 1.0;
              final big = min(28.0, byTime - 1.0);
              final nBig = longs.where((k) => k >= big).length;
              final tag =
                  '$ev/$level/${focus.name}/10k$tenK/${longest ?? '-'}km/${weeks}w: peak $peak (3 h ≈ ${byTime.toStringAsFixed(1)}), $nBig ≥ ${big.toStringAsFixed(1)}';
              if (peak < need) fails.add('$tag – peak below ${need.toStringAsFixed(1)}');
              if (nBig < 2) fails.add('$tag – fewer than 2 long runs ≥ ${big.toStringAsFixed(1)} km');
              if (peak > spec.longRunCapKm) fails.add('$tag – beyond the cap');
            }
          }
        }
      }
    }
    expect(fails, isEmpty, reason: fails.join('\n'));
  });

  test('user report: hybrid marathon, 6 days, 15 weeks', () {
    UserProfile hybrid(Map<String, int> times, Map<int, int> dayMin) => UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.hybrid,
      experience: const {Sport.run, Sport.gym},
      trainingDays: const [1, 2, 3, 4, 6, 7],
      goals: const ['race'],
      athlete: AthleteData(
        sessionMinutes: 60,
        setupMode: dayMin.isEmpty ? 'simple' : 'advanced',
        dayMinutes: dayMin,
        raceTimes: times,
        eventDistance: 'm',
        eventDate: _race(15),
      ),
    );
    // Slow runner (65 min 10 km) with an 8 h Saturday: the 3 h cap, not the day, limits the long run – no
    // "raise Saturday to 8 h 45", but the honest note (time on feet, walk breaks).
    final slow = hybrid(const {'10k': 65 * 60}, const {6: 480, 1: 240});
    final f = PlanGenerator.feasibility(slow, start: _start, l: l);
    expect(f.raiseDay, isNull);
    expect(f.issues, ['longRunTimeCap']);
    expect(f.timeCapMin, 180);
    expect(FeasibilityText.of(l, f), contains('3 h'));
    final slowPlan = PlanGenerator(l, slow, const [], id).generate(start: _start);
    expect(peaks(slowPlan).runMin, inInclusiveRange(170, 185));
    // Intermediate (52 min 10 km): 4 runs + 2 strength sessions, the long run builds to ~28 km.
    final mid = hybrid(const {'10k': 52 * 60}, const {});
    final sched = PlanGenerator.scheduleOf(mid).values.expand((e) => e);
    expect(sched.where((s) => s == Sport.run).length, 4);
    final pk = peaks(PlanGenerator(l, mid, const [], id).generate(start: _start));
    expect(pk.runKm, greaterThanOrEqualTo(27.0));
    expect(pk.runMin, lessThanOrEqualTo(185));
    // A 150 min Saturday: the day limits – raise it to the 3 h the long run needs, not more.
    final tight = hybrid(const {'10k': 52 * 60}, const {6: 150});
    final ft = PlanGenerator.feasibility(tight, start: _start, l: l);
    expect(ft.issues, contains('longRunTime'));
    expect(ft.raiseDay, 6);
    expect(ft.raiseDayMin, 180);
  });
}

/// The feasibility card's text of an issue list (as the card shows it).
class FeasibilityText {
  static String of(AppLocalizations l, PlanFeasibility f) =>
      f.issues.map((i) => f.extraIssueText(l, i, dayName: (d) => '$d') ?? i).join('\n');
}
