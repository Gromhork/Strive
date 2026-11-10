import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/cardio_progression.dart';
import 'package:strive/services/goal_forecast.dart';
import 'package:strive/services/goal_model.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/progression_check.dart';
import 'package:strive/services/zones.dart';

/// Day-by-day adaptation simulation (sports-science review 2026-11, docs/training-science.md §11.4):
/// a generated plan is "trained" one day at a time by a scripted athlete; every Monday the athlete
/// opens "Plan überprüfen" and accepts the whole proposal, the goal forecast is read, and the
/// AutoAdjuster runs after every session. The scenarios are the review's; the expectations are the
/// coherence invariants of the adaptation layer (an athlete who trains exactly to plan hears nothing
/// negative, fatigue gets a recovery week instead of months of easy running, the forecast never
/// contradicts the recalibration, the VDOT moves in Daniels-sized steps …).
///
/// Set STRIVE_SIM_OUT to a folder to write a readable log per scenario (`sim_<name>.txt`) and a
/// summary (`sim_summary.txt`).

/// Behaviour of the simulated athlete for a workout in plan week [week] (0-based): null = skipped,
/// else (share of the planned volume done, speed factor > 1 faster, RPE).
typedef Behaviour = (double, double, int)? Function(PlannedWorkout w, int week);

int nominalRpe(PlannedWorkout w) => switch (w.intensity) {
  'easy' || 'technique' => 3,
  'long' => 4,
  'tempo' => 6,
  'intervals' => 8,
  _ => 5,
};

bool isQuality(PlannedWorkout w) => w.intensity == 'tempo' || w.intensity == 'intervals';

/// One Monday of the simulation.
class SimWeek {
  SimWeek(this.week, this.day, this.recal, this.forecast, this.profile);
  final int week; // 1-based plan week that starts on this Monday
  final DateTime day;
  final Recalibration recal;
  final GoalForecast? forecast;

  /// Profile after the athlete accepted the proposal.
  final UserProfile profile;
}

class SimRun {
  SimRun(this.name, this.original, this.start);
  final String name;
  final List<PlannedWorkout> original;
  final DateTime start;
  final weeks = <SimWeek>[];
  final autos = <(DateTime, AutoChange)>[];
  var plans = <PlannedWorkout>[];
  final sessions = <Session>[];
  late UserProfile profile;
  final log = StringBuffer();

  Map<String, PlannedWorkout> get originalById => {for (final w in original) w.id: w};
}

final simStart = DateTime(2026, 11, 16); // Monday
DateTime raceIn(int weeks) => DateTime(simStart.year, simStart.month, simStart.day + 7 * (weeks - 1) + 6);
String hms(int? s) =>
    s == null ? '-' : '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

UserProfile marathoner() => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.run,
  birthYear: 1990,
  gender: 'm',
  trainingDays: const [1, 2, 4, 6, 7],
  experience: const {Sport.run},
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 75,
    dayMinutes: const {7: 180},
    raceTimes: const {'hm': 6600},
    runWeeklyKm: 35,
    longestRunKm: 16,
    eventDistance: 'm',
    eventDate: raceIn(18),
    targetTimeSec: 3 * 3600 + 40 * 60,
  ),
);

UserProfile tenK() => UserProfile(
  level: 'intermediate',
  focus: TrainingFocus.run,
  birthYear: 1990,
  trainingDays: const [2, 4, 6, 7],
  experience: const {Sport.run},
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: 60,
    raceTimes: const {'10k': 52 * 60 + 30},
    runWeeklyKm: 25,
    longestRunKm: 10,
    eventDistance: '10k',
    eventDate: raceIn(10),
    targetTimeSec: 50 * 60 + 30,
  ),
);

UserProfile beginnerHm() => UserProfile(
  level: 'beginner',
  focus: TrainingFocus.run,
  birthYear: 1990,
  trainingDays: const [2, 4, 6],
  athlete: AthleteData(
    setupMode: 'advanced',
    canRun30: false,
    sessionMinutes: 60,
    dayMinutes: const {6: 150},
    eventDistance: 'hm',
    eventDate: raceIn(20),
  ),
);

/// The review's scenarios: profile, behaviour, weeks simulated.
final scenarios = <String, (UserProfile Function(), Behaviour, int)>{
  'M_good': (marathoner, (w, k) => (1, 1, nominalRpe(w)), 14),
  'M_missLong': (marathoner, (w, k) => w.intensity == 'long' && k >= 3 ? null : (1, 1, nominalRpe(w)), 12),
  'M_slower': (marathoner, (w, k) => (1, isQuality(w) ? 0.93 : 0.97, w.intensity == 'easy' ? 5 : 8), 12),
  'M_highRpe': (marathoner, (w, k) => (1, 1, (nominalRpe(w) + 3).clamp(1, 10)), 8),
  'M_sickW6': (marathoner, (w, k) => k == 5 || k == 6 ? null : (1, 1, nominalRpe(w)), 10),
  'M_faster': (marathoner, (w, k) => (1, isQuality(w) ? 1.05 : 1.0, isQuality(w) ? 4 : 3), 12),
  'M_longCut': (marathoner, (w, k) => w.intensity == 'long' ? (0.7, 0.97, 8) : (1, 1, nominalRpe(w)), 10),
  '10k_good': (tenK, (w, k) => (1, 1, nominalRpe(w)), 9),
  '10k_easyOnlySkipQuality': (tenK, (w, k) => isQuality(w) ? null : (1, 1, nominalRpe(w)), 8),
  'BHM_good': (beginnerHm, (w, k) => (1, 1, 4), 18),
  'BHM_struggle': (beginnerHm, (w, k) => (w.intensity == 'long' ? 0.75 : 0.85, 1, 7), 10),
  'BHM_hard8': (beginnerHm, (w, k) => (1, 1, 8), 8),
};

SimRun simulate(String name, AppLocalizations l, List<WorkoutTemplate> templates, String Function() id) {
  final (make, beh, weeksToSim) = scenarios[name]!;
  var p = make();
  final gen = PlanGenerator(l, p, templates, id).generate(start: simStart);
  final run = SimRun(name, gen, simStart)..plans = [...gen];
  run.profile = p;
  final b = run.log..writeln('#### $name');
  PlannedWorkout apply(PlannedWorkout x, Map<String, dynamic> m) => PlannedWorkout.fromMap(x.id, {...x.toMap(), ...m});
  for (var day = 0; day < weeksToSim * 7; day++) {
    final d = DateTime(simStart.year, simStart.month, simStart.day + day);
    final week = day ~/ 7;
    if (d.weekday == DateTime.monday && day > 0) {
      final now = DateTime(d.year, d.month, d.day, 7);
      final r = Recalibrator(l, p, plans: run.plans, sessions: run.sessions, now: now, templates: templates, newId: id).run();
      final f = GoalForecast.of(p, plans: run.plans, sessions: run.sessions, now: now);
      b.writeln(
        '\n[W${week + 1} Mon] RECAL reasons=${r.reasons.map((x) => x.name).toList()} completion=${r.stats.completion?.toStringAsFixed(2)} '
        'tooHard=${r.stats.tooHard} vdot ${r.stats.oldVdot.toStringAsFixed(1)}→${r.stats.newVdot?.toStringAsFixed(1)} '
        'raceTimes=${r.raceTimes} athlete=${r.athlete}',
      );
      for (final c in r.changes) {
        b.writeln(
          '   ${c.kind.name}: ${dayKey(c.before.date)} "${c.before.title}" ${c.before.durationMin}\'/${c.before.distanceKm} → '
          '"${c.after.title}" ${c.after.durationMin}\'/${c.after.distanceKm}',
        );
      }
      if (f != null) {
        b.writeln(
          '   FORECAST status=${f.status.name}${f.early ? '(early)' : ''} conf=${f.confidence.name} now=${hms(f.nowSec)} '
          'race=${hms(f.raceDaySec)} target=${hms(f.targetSec)} suggest=${hms(f.suggestedSec)} reasons=${f.reasons.map((x) => x.name).toList()} '
          'adh=${f.adherence?.toStringAsFixed(2)} vdot ${f.vdotNow}/${f.expectedVdotNow?.toStringAsFixed(1)} alert=${f.alert}'
          '${f.progression == null ? '' : ' PROG issues=${f.progression!.issues.map((x) => x.name).toList()}'}',
        );
      }
      // The athlete accepts the whole proposal.
      final upd = r.updates;
      run.plans = [for (final x in run.plans) upd.containsKey(x.id) ? apply(x, upd[x.id]!) : x, ...r.additions];
      if (r.raceTimes != null || r.athlete.isNotEmpty) {
        p = p.copyWith(athlete: p.athlete.merge({if (r.raceTimes != null) 'raceTimes': r.raceTimes, ...r.athlete}));
      }
      run.weeks.add(SimWeek(week + 1, d, r, f, p));
    }
    for (final w in run.plans.where((x) => dayOnly(x.date) == d && x.status == 'planned' && x.intensity != 'race').toList()) {
      final res = beh(w, week);
      if (res == null) {
        run.plans = [
          for (final x in run.plans) x.id == w.id ? apply(x, {'status': 'skipped'}) : x,
        ];
        b.writeln('  ${dayKey(d)} SKIP "${w.title}"');
        continue;
      }
      final (ratio, speed, rpe) = res;
      final s = Session(
        id: 's${w.id}',
        sport: w.sport,
        title: w.title,
        start: DateTime(d.year, d.month, d.day, 18),
        durationSec: (w.durationMin * 60 * ratio / speed).round(),
        distanceM: (w.distanceKm ?? 0) * 1000 * ratio,
        rpe: w.sport == Sport.gym ? null : rpe,
        planId: w.id,
      );
      run.sessions.add(s);
      run.plans = [
        for (final x in run.plans) x.id == w.id ? apply(x, {'status': 'done', 'sessionId': s.id}) : x,
      ];
      final done = run.plans.firstWhere((x) => x.id == w.id);
      final ch = AutoAdjuster(p, plans: run.plans, sessions: run.sessions, now: DateTime(d.year, d.month, d.day, 19)).afterSession(s, done);
      b.writeln(
        '  ${dayKey(d)} DONE "${w.title}" ${w.durationMin}\'/${w.distanceKm} ×$ratio speed $speed rpe $rpe'
        '${ch.isEmpty ? '' : '  AUTO: ${ch.map((c) => '${c.reason} "${c.before.title}" ${c.before.durationMin}\'/${c.before.distanceKm}→${c.after.durationMin}\'/${c.after.distanceKm}').join('; ')}'}',
      );
      for (final c in ch) {
        run.autos.add((d, c));
        run.plans = [for (final x in run.plans) x.id == c.before.id ? c.after : x];
      }
    }
  }
  run.profile = p;
  return run;
}

/// Reasons that tell the athlete something is wrong.
const negativeRecal = {
  RecalReason.rpeHigh,
  RecalReason.lowCompletion,
  RecalReason.cutShort,
  RecalReason.missedKey,
  RecalReason.slowerRuns,
  RecalReason.runTrendSlower,
  RecalReason.returnAfterBreak,
  RecalReason.longCap,
  RecalReason.fatigueRecovery,
  RecalReason.fatigueCheck,
  RecalReason.goalAtRisk,
  RecalReason.repeatStage,
  RecalReason.moveLong,
};

const negativeForecast = {
  ForecastReason.missedTraining,
  ForecastReason.slowerThanPlanned,
  ForecastReason.longRunBehind,
  ForecastReason.trainingBreak,
  ForecastReason.fatigue,
};

const reductions = {'easyTooFast', 'easyHard', 'longCutShort', 'longHard', 'qualityHard'};

/// Short machine-readable summary of a run (the numbers of the review report).
String summary(SimRun r) {
  final b = StringBuffer('== ${r.name}\n');
  final fs = r.weeks.where((w) => w.forecast != null && !w.forecast!.early).toList();
  b.writeln(
    '  forecast: ${fs.map((w) => 'W${w.week}:${w.forecast!.status.name}${w.forecast!.reasons.isEmpty ? '' : w.forecast!.reasons.map((x) => x.name).toList()}').join(' ')}',
  );
  b.writeln('  race-day: ${fs.map((w) => hms(w.forecast!.raceDaySec)).join(' ')}');
  b.writeln('  recal: ${r.weeks.map((w) => 'W${w.week}:${w.recal.reasons.map((x) => x.name).join('+')}').join(' ')}');
  final longCaps = r.weeks.where((w) => w.recal.reasons.contains(RecalReason.longCap)).length;
  final toEasyWeeks = r.weeks.where((w) => w.recal.changes.any((c) => c.kind == RecalKind.toEasy)).length;
  final negAuto = r.autos.where((a) => reductions.contains(a.$2.reason)).length;
  b.writeln('  longCap weeks: $longCaps · toEasy weeks: $toEasyWeeks · auto reductions: $negAuto');
  final vdots = r.weeks.map((w) => Vdot.of(w.profile.athlete)?.toStringAsFixed(1) ?? '-').toList();
  b.writeln('  profile VDOT by week: ${vdots.join(' ')} · raceTimes at end: ${r.profile.athlete.raceTimes}');
  final longs =
      r.plans.where((w) => w.sport == Sport.run && w.intensity == 'long' && w.status == 'done').toList()
        ..sort((x, y) => x.date.compareTo(y.date));
  final orig = r.originalById;
  b.writeln('  long runs done (planned now / generated): ${longs.map((w) => '${w.distanceKm}/${orig[w.id]?.distanceKm}').join(' ')}');
  final easy = r.plans.where((w) => w.sport == Sport.run && w.intensity == 'easy' && w.status != 'skipped').toList();
  final minEasy = easy.isEmpty ? null : easy.map((w) => w.durationMin).reduce(min);
  final minKm = easy.isEmpty ? null : easy.map((w) => w.distanceKm ?? 99).reduce(min);
  b.writeln('  shortest easy run: $minEasy min / $minKm km');
  return b.toString();
}

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'w${n++}';
  final templates = defaultTemplates(id, de: true);
  final runs = <String, SimRun>{};
  SimRun sim(String name) => runs.putIfAbsent(name, () => simulate(name, l, templates, id));
  final out = Platform.environment['STRIVE_SIM_OUT'];

  tearDownAll(() {
    if (out == null) return;
    final dir = Directory(out)..createSync(recursive: true);
    final all = StringBuffer();
    for (final r in runs.values) {
      File('${dir.path}${Platform.pathSeparator}sim_${r.name}.txt').writeAsStringSync(r.log.toString());
      all.write(summary(r));
    }
    File('${dir.path}${Platform.pathSeparator}sim_summary.txt').writeAsStringSync(all.toString());
  });

  /// Weeks left to race day on that Monday.
  int weeksLeft(SimWeek w) => daysBetween(w.day, w.profile.athlete.eventDate!) ~/ 7;

  group('perfect athlete: no negative messages, no cuts, on track', () {
    for (final name in ['M_good', '10k_good', 'BHM_good']) {
      test(name, () {
        final r = sim(name);
        for (final w in r.weeks) {
          expect(w.recal.reasons.toSet().intersection(negativeRecal), isEmpty, reason: 'W${w.week} recal ${w.recal.reasons}');
          final cuts = w.recal.changes.where(
            (c) => c.kind == RecalKind.easier || c.kind == RecalKind.toEasy || c.kind == RecalKind.dropped,
          );
          expect(cuts.map((c) => '${c.kind.name} ${c.before.title}'), isEmpty, reason: 'W${w.week}');
          final f = w.forecast;
          if (f == null || f.early) continue;
          expect(f.status, ForecastStatus.onTrack, reason: 'W${w.week} forecast ${f.status} ${f.reasons}');
          expect(f.reasons.toSet().intersection(negativeForecast), isEmpty, reason: 'W${w.week} ${f.reasons}');
          expect(f.alert, isFalse);
        }
        expect(r.autos.where((a) => reductions.contains(a.$2.reason)).map((a) => '${dayKey(a.$1)} ${a.$2.reason}'), isEmpty);
        // The generator's long runs stay as generated (C2: no R1 cap on a goal-directed build).
        final orig = r.originalById;
        for (final w in r.plans.where((w) => w.intensity == 'long' && w.status == 'done')) {
          expect(w.durationMin, greaterThanOrEqualTo(orig[w.id]!.durationMin), reason: '${dayKey(w.date)} ${w.title}');
        }
      });
    }

    test('run/walk beginner: finish-only forecast, no time prediction (C6)', () {
      final r = sim('BHM_good');
      for (final w in r.weeks.where((w) => w.forecast != null)) {
        expect(w.forecast!.raceDaySec, isNull, reason: 'W${w.week}');
        expect(w.forecast!.nowSec, isNull);
        expect(w.forecast!.targetSec, isNull);
      }
      // The long runs reach the generator's goal-directed length (≥ 12 km by week 14).
      final longest = r.sessions.where((s) => s.sport == Sport.run).fold(0.0, (x, s) => max(x, s.distanceM / 1000));
      expect(longest, greaterThanOrEqualTo(12));
    });
  });

  group('long runs fall short or are missed (C3, I14)', () {
    test('M_longCut: no "ahead" with long runs behind, status follows, no downward ratchet', () {
      final r = sim('M_longCut');
      var sawBehind = false;
      for (final w in r.weeks) {
        final f = w.forecast;
        if (f == null || f.early) continue;
        if (f.reasons.contains(ForecastReason.longRunBehind)) {
          sawBehind = true;
          expect(f.status, isNot(ForecastStatus.ahead), reason: 'W${w.week}');
          expect(f.status.index, greaterThanOrEqualTo(ForecastStatus.slightlyBehind.index), reason: 'W${w.week}');
          if (weeksLeft(w) <= 10) expect(f.status, ForecastStatus.atRisk, reason: 'W${w.week}');
        }
      }
      expect(sawBehind, isTrue);
      // The recalibration never lowers a long run the AutoAdjuster just capped after a cut-short
      // long run ("below the last cut"), and never below the longest long run of the last 30 days – a proposed
      // recovery week is the one deliberate dip.
      for (final w in r.weeks.where((w) => !w.recal.reasons.contains(RecalReason.fatigueRecovery))) {
        for (final c in w.recal.changes.where((c) => c.before.intensity == 'long' && c.kind == RecalKind.easier)) {
          expect(c.before.auto?.reason, isNot('longCutShort'), reason: 'W${w.week} ${dayKey(c.before.date)}');
          final from = DateTime(c.before.date.year, c.before.date.month, c.before.date.day - 30);
          final achieved = r.sessions
              .where((s) => s.sport == Sport.run && s.start.isAfter(from) && s.start.isBefore(w.day))
              .fold(0.0, (x, s) => max(x, s.distanceM / 1000));
          expect(c.after.distanceKm!, greaterThanOrEqualTo(achieved - 0.05), reason: 'W${w.week} ${dayKey(c.before.date)}');
        }
      }
    });

    test('M_missLong: skipped long runs are noticed, never "ahead", easy runs not cut, move offered', () {
      final r = sim('M_missLong');
      // Long runs are skipped from week 4 on.
      for (final w in r.weeks.where((w) => w.week >= 6)) {
        final f = w.forecast!;
        expect(f.status, isNot(ForecastStatus.ahead), reason: 'W${w.week}');
        expect(f.reasons, contains(ForecastReason.longRunBehind), reason: 'W${w.week}');
        expect(f.status.index, greaterThanOrEqualTo(ForecastStatus.slightlyBehind.index), reason: 'W${w.week}');
        // All easy runs were done: no cuts on them.
        final easyCuts = w.recal.changes.where((c) => c.kind == RecalKind.easier && c.before.intensity == 'easy');
        expect(easyCuts.map((c) => c.before.title), isEmpty, reason: 'W${w.week} ${w.recal.reasons}');
      }
      expect(r.weeks.any((w) => w.recal.reasons.contains(RecalReason.moveLong)), isTrue);
      expect(r.weeks.any((w) => w.recal.changes.any((c) => c.before.intensity == 'long' && !sameDay(c.before.date, c.after.date))), isTrue);
      // Eight weeks without a long run before a marathon: the goal is flagged.
      expect(r.weeks.last.recal.reasons, contains(RecalReason.goalAtRisk));
      expect(r.weeks.last.forecast!.status, ForecastStatus.atRisk);
    });
  });

  group('fatigue (C4)', () {
    for (final name in ['M_highRpe', 'M_slower']) {
      test('$name: one recovery week, then quality back at reduced reps; floors; forecast follows', () {
        final r = sim(name);
        // Consecutive weeks in which quality was turned into easy running: ≤ 2 (before: 7–11).
        var run = 0, longest = 0;
        for (final w in r.weeks) {
          run = w.recal.changes.any((c) => c.kind == RecalKind.toEasy) ? run + 1 : 0;
          longest = max(longest, run);
        }
        expect(longest, lessThanOrEqualTo(2), reason: r.weeks.map((w) => w.recal.reasons.map((x) => x.name).join('+')).join(' | '));
        expect(r.weeks.any((w) => w.recal.reasons.contains(RecalReason.fatigueRecovery)), isTrue);
        expect(r.weeks.any((w) => w.recal.reasons.contains(RecalReason.fatigueCheck)), isTrue);
        // After the recovery week, quality sessions are planned again.
        final rec = r.weeks.firstWhere((w) => w.recal.reasons.contains(RecalReason.fatigueRecovery));
        final after = r.plans.where(
          (p) => isQuality(p) && p.sport == Sport.run && daysBetween(rec.day, p.date) >= 7 && p.date.isBefore(r.weeks.last.day),
        );
        expect(after, isNotEmpty);
        // Floors: a non-beginner's easy run is never cut below 20 min / 4 km.
        for (final w in r.weeks) {
          for (final c in w.recal.changes.where((c) => c.after.sport == Sport.run && c.after.intensity == 'easy')) {
            final o = r.originalById[c.before.id];
            if (o == null || c.kind == RecalKind.harder) continue;
            expect(c.after.durationMin, greaterThanOrEqualTo(min(20, o.durationMin)), reason: 'W${w.week} ${c.before.title}');
            expect(
              c.after.distanceKm ?? 99,
              greaterThanOrEqualTo(min(4.0, o.distanceKm ?? 99) - 0.05),
              reason: 'W${w.week} ${c.before.title}',
            );
          }
        }
        // The forecast hears about it: never on track / ahead while the RPE stays high.
        for (final w in r.weeks.where((w) => w.recal.reasons.contains(RecalReason.rpeHigh))) {
          final f = w.forecast!;
          if (f.early) continue;
          expect(f.reasons, contains(ForecastReason.fatigue), reason: 'W${w.week}');
          expect(f.status.index, greaterThanOrEqualTo(ForecastStatus.slightlyBehind.index), reason: 'W${w.week}');
        }
      });
    }
  });

  test('M_faster: VDOT steps ≥ 3 weeks apart, total ≤ 1.6 × the model gain, no synthetic race times (C5)', () {
    final r = sim('M_faster');
    final base = Vdot.of(marathoner().athlete)!;
    DateTime? last;
    for (final w in r.weeks) {
      expect(w.recal.raceTimes, isNull, reason: 'W${w.week}: no race time is written for a training-derived VDOT');
      final v = w.recal.stats.newVdot;
      if (v == null) continue;
      if (last != null) expect(daysBetween(last, w.day), greaterThanOrEqualTo(21), reason: 'W${w.week}');
      last = w.day;
      final elapsed = daysBetween(simStart, w.day) / 7;
      expect(v - base, lessThanOrEqualTo(GoalModel.optimistic * GoalModel.gain(w.profile, elapsed) + 0.05), reason: 'W${w.week} $v');
    }
    expect(last, isNotNull, reason: 'faster quality runs do lift the VDOT');
    expect(r.profile.athlete.raceTimes, marathoner().athlete.raceTimes);
    expect(Vdot.of(r.profile.athlete), greaterThan(base));
  });

  test('M_sickW6: never "ahead" after a sick fortnight; return sessions ≥ the floor (I15)', () {
    final r = sim('M_sickW6');
    for (final w in r.weeks.where((w) => w.week >= 7)) {
      expect(w.forecast!.status, isNot(ForecastStatus.ahead), reason: 'W${w.week}');
    }
    for (final w in r.weeks) {
      for (final c in w.recal.changes.where((c) => c.after.sport == Sport.run && c.kind == RecalKind.easier)) {
        final o = r.originalById[c.before.id]!;
        expect(c.after.durationMin, greaterThanOrEqualTo(min(20, o.durationMin)), reason: 'W${w.week} ${c.before.title}');
      }
    }
  });

  test('10k_easyOnlySkipQuality: never "ahead" without quality evidence', () {
    final r = sim('10k_easyOnlySkipQuality');
    for (final w in r.weeks.where((w) => w.forecast != null)) {
      expect(w.forecast!.status, isNot(ForecastStatus.ahead), reason: 'W${w.week}');
    }
  });

  group('run/walk beginner who struggles (I13)', () {
    test('BHM_hard8: the stage is held (repeat week) and the forecast says behind', () {
      final r = sim('BHM_hard8');
      expect(r.weeks.any((w) => w.recal.reasons.contains(RecalReason.repeatStage)), isTrue);
      // Done run/walk sessions never advance by more than one stage a week while every one is RPE 8.
      int runMin(PlannedWorkout w) => w.steps.where((s) => s.isWork).map((s) => s.durationSec ?? 0).fold(0, max);
      final rw =
          r.plans.where((w) => isRunWalk(w) && w.status == 'done' && w.intensity == 'easy').toList()
            ..sort((x, y) => x.date.compareTo(y.date));
      final firstMin = runMin(rw.first), lastMin = runMin(rw.last);
      final plannedLast = r.original.where((w) => isRunWalk(w) && w.intensity == 'easy' && !w.date.isAfter(rw.last.date)).last;
      expect(lastMin, lessThan(runMin(plannedLast)), reason: 'held below the plan ($firstMin → $lastMin s)');
      for (final w in r.weeks.where((w) => w.forecast?.progression?.behind ?? false)) {
        expect(w.forecast!.status.index, greaterThanOrEqualTo(ForecastStatus.slightlyBehind.index));
      }
    });

    test('BHM_struggle: titles of trimmed run/walk sessions match their content', () {
      final r = sim('BHM_struggle');
      final pattern = RegExp(r'(\d+) × (\d+) min');
      for (final w in r.plans.where(isRunWalk)) {
        final m = pattern.firstMatch(w.title);
        if (m == null) continue;
        final work = w.steps.where((s) => s.isWork && s.zone != 'walk').toList();
        expect(int.parse(m.group(1)!), work.length, reason: '${dayKey(w.date)} ${w.title}');
        expect(int.parse(m.group(2)!), (work.first.durationSec ?? 0) ~/ 60, reason: '${dayKey(w.date)} ${w.title}');
      }
    });
  });
}
