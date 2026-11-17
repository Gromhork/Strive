import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Review 2026-11 (23 generated plans), triathlon / cycling / swimming / duathlon / ultra / hybrid /
/// gym builders: C7, C8, IMPORTANT 4–9 and 19, and the MINOR sprint / masters findings.
void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'm${n++}';
  final start = DateTime(2026, 11, 16);
  final templates = defaultTemplates(id, de: true);
  DateTime race(int weeks) => DateTime(start.year, start.month, start.day + 7 * (weeks - 1) + 6);
  List<PlannedWorkout> gen(UserProfile p, {int? weeks}) => PlanGenerator(l, p, templates, id).generate(start: start, weeks: weeks);

  /// Plan weeks (Monday → sessions) without the race.
  List<List<PlannedWorkout>> weeksOf(List<PlannedWorkout> plan) {
    final m = <DateTime, List<PlannedWorkout>>{};
    for (final p in plan.where((p) => p.intensity != 'race')) {
      m.putIfAbsent(startOfWeek(p.date), () => []).add(p);
    }
    final keys = m.keys.toList()..sort();
    return [for (final k in keys) m[k]!..sort((x, y) => x.date.compareTo(y.date))];
  }

  bool loading(List<PlannedWorkout> wk) => wk.every((p) => p.phase != 'recovery' && p.phase != 'taper');
  String phaseOf(List<PlannedWorkout> wk) => wk.first.phase ?? '';
  bool quality(PlannedWorkout p) => p.intensity == 'tempo' || p.intensity == 'intervals';
  String sig(PlannedWorkout p) =>
      '${p.title}|${p.description}|${p.steps.map((s) => '${s.kind}${s.zone}${s.distanceM}${s.durationSec}').join(',')}';

  UserProfile prof({
    String level = 'intermediate',
    TrainingFocus focus = TrainingFocus.run,
    int birth = 1990,
    String gender = 'm',
    required List<int> days,
    Set<Sport>? exp,
    AthleteData a = const AthleteData(),
  }) => UserProfile(
    level: level,
    focus: focus,
    birthYear: birth,
    gender: gender,
    trainingDays: days,
    experience: exp ?? {...focus.sports},
    weightKg: 72,
    heightCm: 178,
    athlete: a,
  );

  final olympicSwimNovice = prof(
    level: 'beginner',
    focus: TrainingFocus.triathlon,
    days: const [1, 3, 5, 6, 7],
    exp: const {Sport.run, Sport.ride},
    a: AthleteData(sessionMinutes: 60, canSwim400: false, eventDistance: 'olympic', eventDate: race(16)),
  );
  final ironman = prof(
    level: 'advanced',
    focus: TrainingFocus.triathlon,
    days: const [1, 2, 3, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 90,
      dayMinutes: const {6: 360, 7: 180},
      raceTimes: const {'10k': 40 * 60, 'm': 3 * 3600 + 15 * 60},
      ftp: 280,
      hasPowerMeter: true,
      swim400Sec: 360,
      swim200Sec: 170,
      eventDistance: 'ironman',
      eventDate: race(28),
    ),
  );
  final half = prof(
    focus: TrainingFocus.triathlon,
    days: const [1, 2, 3, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      dayMinutes: const {6: 240, 7: 240},
      raceTimes: const {'10k': 48 * 60},
      ftp: 230,
      hasPowerMeter: true,
      swim400Sec: 440,
      swim200Sec: 210,
      eventDistance: '70.3',
      eventDate: race(16),
    ),
  );
  final ride160 = prof(
    focus: TrainingFocus.ride,
    days: const [2, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      dayMinutes: const {6: 300},
      ftp: 220,
      hasPowerMeter: true,
      eventDistance: 'ride160',
      eventDate: race(14),
    ),
  );
  final swim3800 = prof(
    focus: TrainingFocus.swim,
    days: const [1, 3, 5, 6],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      swim400Sec: 400,
      swim200Sec: 190,
      eventDistance: 'swim3800',
      eventDate: race(14),
    ),
  );
  final ultra = prof(
    days: const [1, 2, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      dayMinutes: const {6: 240, 7: 150},
      raceTimes: const {'m': 3 * 3600 + 50 * 60},
      runWeeklyKm: 50,
      longestRunKm: 25,
      eventDistance: 'ultra50',
      eventDate: race(20),
    ),
  );
  final duathlon = prof(
    focus: TrainingFocus.duathlon,
    days: const [1, 2, 4, 6, 7],
    a: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 60,
      dayMinutes: const {6: 150, 7: 120},
      raceTimes: const {'10k': 46 * 60},
      ftp: 240,
      hasPowerMeter: true,
      eventDistance: 'du_standard',
      eventDate: race(12),
    ),
  );

  test('C7 swim novice, olympic: ≥ 2 swims a week, 1.6+ km, continuous ≥ 1 km, open-water cues in build / peak', () {
    final weeks = weeksOf(gen(olympicSwimNovice));
    for (final wk in weeks.where(loading)) {
      final swims = wk.where((p) => p.sport == Sport.swim).toList();
      expect(swims.length, greaterThanOrEqualTo(2), reason: '${wk.first.date}');
      expect(swims.fold(0.0, (x, p) => x + (p.distanceKm ?? 0)), greaterThanOrEqualTo(1.5), reason: '${wk.first.date}');
    }
    final preTaper = weeks.where((wk) => phaseOf(wk) != 'taper').expand((wk) => wk).where((p) => p.sport == Sport.swim);
    final longest = preTaper.expand((p) => p.steps).where((s) => s.isWork && s.zone == 'EN').fold(0.0, (x, s) => max(x, s.distanceM ?? 0));
    expect(longest, greaterThanOrEqualTo(1000)); // before: 800 m once (W14)
    final late = weeks.where((wk) => phaseOf(wk) == 'build' || phaseOf(wk) == 'peak').expand((wk) => wk);
    final endurance = late.where((p) => p.sport == Sport.swim && p.intensity == 'easy').toList();
    expect(endurance, isNotEmpty);
    for (final p in endurance) {
      expect(p.description.split('\n'), contains(l.wTriOpenWaterNote), reason: p.title);
      expect(p.steps.where((s) => s.zone == 'EN').every((s) => s.note == l.stepSightingNote), isTrue, reason: p.title);
    }
    expect(PlanGenerator.feasibility(olympicSwimNovice, start: start, l: l).issues, isNot(contains('longSwim')));
  });

  test('C8 Ironman brick: race-specific pace, ≤ 30 min before a long run next day; tempo ride names the Ironman', () {
    final plan = gen(ironman);
    final m = PaceZones(Vdot.of(ironman.athlete)!).marathon;
    final bricks = plan.where((p) => p.sport == Sport.run && p.intensity == 'moderate').toList();
    expect(bricks, isNotEmpty);
    for (final b in bricks) {
      final work = b.steps.firstWhere((s) => s.isWork);
      // Stand-alone M was 4:18–4:28 /km; the race runs off the bike at ~M × 1.25.
      expect(work.paceMin!, greaterThan((m * GoalModel.runOffBikeFactor('ironman') - 15).round()), reason: '${b.date}');
      final next = plan.where(
        (p) => p.sport == Sport.run && p.intensity == 'long' && dayOnly(p.date) == DateTime(b.date.year, b.date.month, b.date.day + 1),
      );
      if (next.isNotEmpty && (next.first.distanceKm ?? 0) >= 25) expect(b.durationMin, lessThanOrEqualTo(30), reason: '${b.date}');
    }
    final tempo = plan.where((p) => p.sport == Sport.ride && p.phase == 'peak' && p.description.split('\n').contains(l.wRideTempoDescIm2));
    expect(tempo, isNotEmpty);
    expect(plan.where((p) => p.description.contains(l.wRideTempoDesc)), isEmpty);
  });

  test('IMPORTANT 4 progressions: Ironman threshold, swim3800, ride160 long ride, duathlon tempo run', () {
    // Ironman threshold rides: 3 × 10 → … → 2 × 25 min, never above 100 % FTP, never 2 × 30.
    final thr = gen(ironman).where((p) => p.sport == Sport.ride && p.description.startsWith(l.wThresholdDesc)).toList();
    expect(thr.length, greaterThanOrEqualTo(3));
    final work = [for (final p in thr) p.steps.where((s) => s.isWork).fold(0, (x, s) => x + s.durationSec!) ~/ 60];
    expect(work.first, lessThan(work.reduce(max)));
    for (final p in thr) {
      for (final s in p.steps.where((s) => s.isWork)) {
        expect(s.durationSec!, lessThanOrEqualTo(25 * 60), reason: p.title);
        expect(s.powerMax!, lessThanOrEqualTo(280), reason: p.title);
      }
    }
    // swim3800: the loading weeks of build / peak are not all the same week.
    final sw = weeksOf(gen(swim3800)).where((wk) => loading(wk) && phaseOf(wk) != 'base').toList();
    expect({for (final wk in sw) wk.map(sig).join('#')}.length, greaterThanOrEqualTo(3));
    // ride160: the long ride keeps changing after the 240 min target.
    final rides = [
      for (final wk in weeksOf(gen(ride160)).where((wk) => loading(wk) && phaseOf(wk) != 'base'))
        wk.firstWhere((p) => p.sport == Sport.ride && p.intensity == 'long'),
    ];
    expect(rides.map((p) => p.durationMin).reduce(max), greaterThan(240));
    for (var i = 3; i < rides.length; i++) {
      expect({for (final p in rides.sublist(i - 3, i + 1)) sig(p)}.length, greaterThan(1));
    }
    // Duathlon: the quality run is not the same tempo run for weeks.
    final runs = [
      for (final wk in weeksOf(gen(duathlon)).where((wk) => loading(wk) && phaseOf(wk) != 'base'))
        ...wk.where((p) => p.sport == Sport.run && quality(p)),
    ];
    expect({for (final p in runs) sig(p)}.length, greaterThanOrEqualTo(3));
  });

  test('IMPORTANT 5 no duplicate quality session of one sport in a week (ultra, cycling)', () {
    for (final p in [
      ultra,
      ride160,
      prof(
        focus: TrainingFocus.ride,
        days: const [2, 4, 6, 7],
        a: const AthleteData(planWeeks: 8, sessionMinutes: 60, ftp: 220, hasPowerMeter: true),
      ),
    ]) {
      final plan = p.athlete.eventDate == null ? gen(p, weeks: 8) : gen(p);
      for (final wk in weeksOf(plan)) {
        for (final s in [Sport.run, Sport.ride]) {
          final titles = wk.where((x) => x.sport == s && quality(x)).map((x) => x.title).toList();
          expect(titles.toSet().length, titles.length, reason: '${p.focus.name} ${wk.first.date}: $titles');
        }
      }
    }
  });

  test('IMPORTANT 6 duathlon: bike quality in the loading weeks, race-power blocks in the build long rides', () {
    final weeks = weeksOf(gen(duathlon)).where(loading).toList();
    final withRideQ = weeks.where((wk) => wk.any((p) => p.sport == Sport.ride && quality(p))).length;
    expect(withRideQ, greaterThanOrEqualTo((weeks.length * 0.75).floor())); // before: 0 of 12 weeks
    final build = weeks
        .where((wk) => phaseOf(wk) == 'build')
        .expand((wk) => wk)
        .where((p) => p.sport == Sport.ride && p.intensity == 'long');
    expect(build, isNotEmpty);
    expect(build.every((p) => p.steps.any((s) => s.note == l.stepRacePowerNote)), isTrue);
  });

  test('IMPORTANT 7 70.3 with a 4 h Saturday: ≥ 3 rides a week, race-power blocks at ~77 % FTP', () {
    final weeks = weeksOf(gen(half));
    for (final wk in weeks.where(loading)) {
      expect(wk.where((p) => p.sport == Sport.ride).length, greaterThanOrEqualTo(3), reason: '${wk.first.date}');
      // Saturday (240 min) carries the long run and a ride – before: only a 45–100 min long run.
      final sat = wk.where((p) => p.date.weekday == 6).toList();
      expect(sat.map((p) => p.sport).toSet(), {Sport.run, Sport.ride}, reason: '${wk.first.date}');
      if (phaseOf(wk) != 'base') expect(sat.fold(0, (x, p) => x + p.durationMin), greaterThanOrEqualTo(120), reason: '${wk.first.date}');
    }
    final blocks =
        weeks
            .where((wk) => phaseOf(wk) == 'build' || phaseOf(wk) == 'peak')
            .expand((wk) => wk)
            .where((p) => p.sport == Sport.ride && p.intensity == 'long')
            .expand((p) => p.steps.where((s) => s.note == l.stepRacePowerNote))
            .toList();
    expect(blocks, isNotEmpty);
    for (final s in blocks) {
      expect((s.powerMin! + s.powerMax!) / 2, closeTo(230 * GoalModel.raceFtpShare('70.3'), 2));
    }
  });

  test('IMPORTANT 8 ultra: ≤ 1 quality run besides the weekend block, hill repeats and terrain notes', () {
    final weeks = weeksOf(gen(ultra));
    for (final wk in weeks.where((wk) => loading(wk) && (phaseOf(wk) == 'build' || phaseOf(wk) == 'peak'))) {
      expect(wk.where((p) => p.sport == Sport.run && quality(p)).length, lessThanOrEqualTo(1), reason: '${wk.first.date}');
    }
    final all = weeks.expand((wk) => wk).toList();
    expect(all.where((p) => p.description.startsWith(l.wHillRepsDesc)), isNotEmpty);
    expect(all.where((p) => p.title == l.wBackToBack).every((p) => p.description.split('\n').contains(l.wTrailNote)), isTrue);
  });

  test('IMPORTANT 9 hybrid: the full-body session before the key day keeps all its sets, A/B alternate continuously', () {
    final plan = gen(
      prof(
        focus: TrainingFocus.hybrid,
        days: const [1, 3, 5, 6],
        a: const AthleteData(planWeeks: 12, sessionMinutes: 60, raceTimes: {'10k': 3000}),
      ),
      weeks: 12,
    );
    final gym = plan.where((p) => p.sport == Sport.gym).toList()..sort((x, y) => x.date.compareTo(y.date));
    // The user's decision: the plan never changes set counts – legs go lighter by load / RIR instead.
    expect(gym.where((p) => p.description.split('\n').contains(l.wGymLegsHalvedNote)), isEmpty);
    expect(gym.where((p) => p.description.split('\n').contains(l.wGymLegsEasyNote)), isNotEmpty);
    expect(gym.every((p) => p.exercises.isEmpty), isTrue);
    for (var i = 1; i < gym.length; i++) {
      expect(gym[i].templateId, isNot(gym[i - 1].templateId), reason: '${gym[i].date}');
    }
    // Each session as long as its program (no sets added or removed).
    for (final p in gym) {
      final t = templates.firstWhere((t) => t.id == p.templateId);
      expect(p.durationMin, min(60, t.estimatedMinutes), reason: '${p.date} ${p.title}');
    }
  });

  test('IMPORTANT 19 beginner gym: regressions first, the full lifts later, no deload promised without one', () {
    final plan = gen(
      prof(level: 'beginner', focus: TrainingFocus.gym, days: const [1, 3, 5], a: const AthleteData(planWeeks: 8, sessionMinutes: 60)),
      weeks: 8,
    );
    const full = {'0652', '0032', '0472'}; // pull-up, barbell deadlift, hanging leg raise
    List<GymExercise> ex(PlannedWorkout p) => plannedGymExercises(p, templates.firstWhere((t) => t.id == p.templateId));
    final firstWeeks = plan.where((p) => p.date.difference(start).inDays < 42);
    final later = plan.where((p) => p.date.difference(start).inDays >= 42);
    expect(firstWeeks.expand(ex).where((e) => full.contains(e.exId)), isEmpty);
    expect(later.expand(ex).where((e) => full.contains(e.exId)), isNotEmpty);
    expect(firstWeeks.where((p) => p.description.split('\n').contains(l.wGymRegressionNote)), isNotEmpty);
    for (final p in plan) {
      for (var rir = 1; rir <= 4; rir++) {
        expect(p.description.split('\n'), isNot(contains(l.wGymLoadDesc(rir))), reason: '${p.date} ${p.title}');
      }
    }
  });

  test('MINOR sprint beginner ≥ 2 runs a week; masters / women ≥ 45 get a strength tip', () {
    final sprint = prof(
      level: 'beginner',
      focus: TrainingFocus.triathlon,
      days: const [2, 4, 6, 7],
      a: AthleteData(sessionMinutes: 60, eventDistance: 'sprint', eventDate: race(10)),
    );
    for (final wk in weeksOf(gen(sprint)).where(loading)) {
      expect(wk.where((p) => p.sport == Sport.run).length, greaterThanOrEqualTo(2), reason: '${wk.first.date}');
    }
    UserProfile tenK(int birth, String g) => prof(
      birth: birth,
      gender: g,
      days: const [2, 4, 6, 7],
      a: AthleteData(
        setupMode: 'advanced',
        sessionMinutes: 60,
        raceTimes: const {'10k': 58 * 60},
        eventDistance: '10k',
        eventDate: race(12),
      ),
    );
    bool tip(UserProfile p) => gen(p).any((w) => w.description.split('\n').contains(l.wMastersStrengthNote));
    expect(tip(tenK(1964, 'f')), isTrue);
    expect(tip(tenK(1970, 'm')), isTrue);
    expect(tip(tenK(1979, 'f')), isTrue);
    expect(tip(tenK(1990, 'm')), isFalse);
    // Once a loading week, on an easy session.
    final w = weeksOf(gen(tenK(1964, 'f'))).where(loading).first;
    expect(w.where((p) => p.description.split('\n').contains(l.wMastersStrengthNote)).single.intensity, 'easy');
  });
}
