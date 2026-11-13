import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/event_distances.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/event_spec.dart';
import 'package:strive/services/exercise_class.dart';
import 'package:strive/services/plan_exercises.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Sport-science review 2026-11 of main 717f7b2 (H2–H5, M1–M7, L1–L3, L6): open water for non-swimmers,
/// run / swim frequency, marathons far short of their long run, long-course swimming, the long-run step
/// rule, plan weeks of a late-week start, honest feasibility issues, the taper, cold starts, strength before
/// a race, masters, gym beginners, race zones and gentle first weeks for beginners.
final _start = DateTime(2026, 11, 9); // Monday
DateTime _race(int weeks) => DateTime(_start.year, _start.month, _start.day + 7 * (weeks - 1) + 6);

UserProfile _p(
  TrainingFocus f,
  String level,
  String? ev,
  int weeks,
  List<int> days,
  int minutes,
  Map<int, int> dayMin, {
  bool swim400 = true,
  Map<String, int>? rt,
  double? longest,
  double? wkKm,
  int age = 35,
  String gymGoal = 'general',
  int planWeeks = 12,
}) => UserProfile(
  level: level,
  focus: f,
  birthYear: DateTime.now().year - age,
  experience: {...f.sports},
  trainingDays: days,
  goals: ev == null ? const ['strength'] : const ['race'],
  athlete: AthleteData(
    setupMode: 'advanced',
    sessionMinutes: minutes,
    dayMinutes: dayMin,
    canSwim400: swim400,
    raceTimes: rt ?? (level == 'beginner' ? const {} : (level == 'advanced' ? const {'10k': 42 * 60} : const {'10k': 52 * 60})),
    longestRunKm: longest,
    runWeeklyKm: wkKm,
    ftp: level == 'beginner' ? null : 220,
    eventDistance: ev,
    eventDate: ev == null ? null : _race(weeks),
    planWeeks: planWeeks,
    gymGoal: gymGoal,
  ),
);

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'r${n++}';
  final templates = defaultTemplates(id, de: true);
  List<PlannedWorkout> gen(UserProfile p, {DateTime? start, int? weeks}) =>
      PlanGenerator(l, p, templates, id).generate(start: start ?? _start, weeks: weeks)..sort((a, b) => a.date.compareTo(b.date));
  PlanFeasibility feas(UserProfile p) => PlanGenerator.feasibility(p, start: _start, l: l);
  int weekOf(PlannedWorkout w) => daysBetween(startOfWeek(_start), startOfWeek(dayOnly(w.date))) ~/ 7;
  double longestSwim(Iterable<PlannedWorkout> plan) => plan
      .where((w) => w.sport == Sport.swim && w.intensity != 'race' && w.phase != 'taper')
      .expand((w) => w.steps)
      .where((s) => s.isWork && s.zone != 'DR' && s.zone != 'SP')
      .fold(0.0, (x, s) => max(x, s.distanceM ?? 0));

  group('H2 open water for non-swimmers', () {
    test('10 weeks to a 1.5 km open-water race from "cannot swim 400 m": blocking, later date, safety text', () {
      final p = _p(TrainingFocus.swim, 'beginner', 'swim1500', 10, const [1, 3, 5], 60, const {}, swim400: false);
      final f = feas(p);
      expect(f.issues, contains('longSwim'));
      expect(f.openWater, isTrue);
      expect(f.laterDate, isNotNull);
      final race = gen(p).firstWhere((w) => w.intensity == 'race');
      expect(race.description, contains(l.wOpenWaterSafety));
    });

    test('with enough weeks the novice swims ≥ 80 % of the race in one go, growing after the test', () {
      final p = _p(TrainingFocus.swim, 'beginner', 'swim1500', 20, const [1, 3, 5], 60, const {}, swim400: false);
      final plan = gen(p);
      expect(longestSwim(plan), greaterThanOrEqualTo(1200));
      expect(feas(p).issues, isNot(contains('longSwim')));
      // The long swim of the test week is no shorter than what the ladder ended with.
      final longs = plan.where((w) => w.sport == Sport.swim && w.intensity == 'long').toList();
      expect(longs, isNotEmpty);
      expect(longs.first.steps.where((s) => s.isWork && s.zone == 'EN').first.distanceM, greaterThanOrEqualTo(400));
    });
  });

  group('H3 frequency and long-run share', () {
    test('Ironman on 3 days: too few runs and swims; the single run stays ≤ 90 min', () {
      final p = _p(TrainingFocus.triathlon, 'intermediate', 'ironman', 26, const [3, 6, 7], 90, const {6: 420, 7: 240});
      final f = feas(p);
      expect(f.issues, containsAll(['runFrequency', 'swimFrequency']));
      expect(FeasibilityText.of(l, f, 'runFrequency'), contains('1'));
      final longs = gen(p).where((w) => w.sport == Sport.run && w.intensity == 'long');
      expect(longs.map((w) => w.durationMin).fold(0, max), lessThanOrEqualTo(PlanGenerator.singleRunMaxMin + 3));
    });

    test('marathon on 3 runs: frequency issue, the half marathon is offered, long run ≤ 55 % of the week', () {
      final p = _p(TrainingFocus.run, 'intermediate', 'm', 18, const [2, 4, 7], 60, const {7: 200});
      final f = feas(p);
      expect(f.issues, contains('runFrequency'));
      expect(f.shorterDistance, 'hm');
      final plan = gen(p);
      for (var w = 0; w < 18; w++) {
        final runs = plan.where((x) => x.sport == Sport.run && x.intensity != 'race' && weekOf(x) == w).toList();
        final long = runs.where((x) => x.intensity == 'long').fold(0.0, (a, x) => max(a, x.distanceKm ?? 0));
        final total = runs.fold(0.0, (a, x) => a + (x.distanceKm ?? 0));
        if (runs.length == 3 && long >= 15) expect(long, lessThanOrEqualTo(0.55 * total + 0.3), reason: 'week ${w + 1}: $long of $total');
      }
    });
  });

  group('H4 marathon far short of its long run', () {
    for (final (name, p) in [
      ('4 × 30 min', _p(TrainingFocus.run, 'intermediate', 'm', 18, const [1, 3, 5, 7], 30, const {})),
      ('90 min long day', _p(TrainingFocus.run, 'intermediate', 'm', 18, const [1, 2, 4, 6, 7], 45, const {7: 90})),
    ]) {
      test('$name: finish goal – blocking issue, no race-pace work, no race pace', () {
        final f = feas(p);
        expect(f.issues, contains('longRunFinish'));
        expect(f.shorterDistance, isNotNull);
        final plan = gen(p);
        final racePace = {l.stepMpNote, l.stepGoalPaceNote, l.stepHmpNote};
        final work = plan.where((w) => w.intensity != 'race').expand((w) => w.steps).where((s) => racePace.contains(s.note));
        expect(work, isEmpty);
        final race = plan.firstWhere((w) => w.intensity == 'race');
        expect(race.steps.single.paceMin, isNull);
        expect(race.description, contains(l.wRaceFinishDesc));
        expect(PlanGenerator.finishOnly(p, start: _start), isTrue);
      });
    }

    test('a marathon that reaches its long run keeps its race-pace work', () {
      final p = _p(TrainingFocus.run, 'intermediate', 'm', 18, const [2, 4, 6, 7], 60, const {7: 200});
      final plan = gen(p);
      expect(plan.expand((w) => w.steps).where((s) => s.note == l.stepMpNote), isNotEmpty);
      expect(feas(p).issues, isNot(contains('longRunFinish')));
    });
  });

  group('H5 long-course swimming', () {
    for (final (ev, weeks, need) in [('ironman', 26, 1800.0), ('70.3', 18, 1350.0)]) {
      test('$ev intermediate: continuous swim ≥ ${need.round()} m by the peak, sessions grow', () {
        final p = _p(TrainingFocus.triathlon, 'intermediate', ev, weeks, const [1, 2, 3, 4, 6, 7], 90, const {6: 420, 7: 240});
        final plan = gen(p);
        expect(longestSwim(plan), greaterThanOrEqualTo(need));
        expect(feas(p).issues, isNot(contains('longSwim')));
        final sessions = plan
            .where((w) => w.sport == Sport.swim && w.intensity != 'race')
            .map((w) => w.steps.fold(0.0, (x, s) => x + (s.distanceM ?? 0)));
        if (ev == 'ironman') expect(sessions.fold(0.0, max), greaterThanOrEqualTo(3000));
      });
    }
  });

  group('M1 long-run steps', () {
    test('every loading week: long run ≤ the longest so far + max(10 %, 1 km) (beginners) / max(10 %, min(12 %, 2 km))', () {
      final fails = <String>[];
      for (final d in eventDistances.where((d) => EventSpec.of(d.key)!.longRunKm != null)) {
        final spec = EventSpec.of(d.key)!;
        for (final level in const ['beginner', 'intermediate', 'advanced']) {
          if (level == 'beginner' && !spec.beginnerOk) continue;
          final focus = switch (spec.sport) {
            EventSport.triathlon => TrainingFocus.triathlon,
            EventSport.duathlon => TrainingFocus.duathlon,
            _ => TrainingFocus.run,
          };
          final p = _p(focus, level, d.key, spec.weeksFor(level).$2, const [1, 2, 4, 6, 7], 75, const {6: 420, 7: 240});
          var longest = 0.0;
          for (final w in gen(p).where((w) => w.sport == Sport.run && w.intensity == 'long' && w.phase != 'taper')) {
            final km = w.distanceKm ?? 0;
            final step = level == 'beginner' ? max(longest * 0.1, 1.0) : max(longest * 0.1, min(longest * 0.12, 2.0));
            if (longest > 0 && w.phase != 'recovery' && km > longest + step + 0.3) {
              fails.add('${d.key}/$level ${dayKey(w.date)}: $km after $longest');
            }
            longest = max(longest, km);
          }
        }
      }
      expect(fails, isEmpty, reason: fails.join('\n'));
    });

    test('HM beginner: no +19–30 % steps, and the recommended weeks reach the race long run', () {
      final weeks = EventSpec.of('hm')!.weeksFor('beginner').$1;
      final p = _p(TrainingFocus.run, 'beginner', 'hm', weeks, const [2, 4, 6], 60, const {6: 150});
      final longs = gen(p).where((w) => w.sport == Sport.run && w.intensity == 'long').map((w) => w.distanceKm ?? 0).toList();
      expect(longs.fold(0.0, max), greaterThanOrEqualTo(14.5));
      expect(feas(p).issues.where((i) => !PlanFeasibility.notes.contains(i) && !i.startsWith('target')), isEmpty);
    });
  });

  group('M2 plan weeks of a late-week start', () {
    test('a Sunday start without a Sunday session: N training weeks to the race', () {
      final p = _p(TrainingFocus.run, 'beginner', 'hm', 16, const [2, 4, 6], 60, const {6: 150});
      final sun = DateTime(2026, 11, 15);
      final race = PlanGenerator.raceDayForWeeks(p, sun, 16);
      expect(PlanGenerator.planWeeksUntil(p, race, sun), 16);
      final q = p.copyWith(athlete: p.athlete.merge({'eventDate': race}));
      final plan = gen(q, start: sun);
      final weeks = plan.where((w) => w.intensity != 'race').map((w) => dayKey(startOfWeek(dayOnly(w.date)))).toSet();
      expect(weeks.length, 16);
    });
  });

  group('M3 honest issues', () {
    test('hybrid HM beginner on 2 runs: the runs a week, not "12 weeks are not enough"', () {
      final p = _p(TrainingFocus.hybrid, 'beginner', 'hm', 16, const [2, 4, 6], 60, const {});
      final f = feas(p);
      expect(f.issues, contains('runFrequency'));
      expect(f.issues, isNot(contains('tooShort')));
    });

    test('at the recommended plan length "N weeks are not enough" is never the reason', () {
      final fails = <String>[];
      for (final d in eventDistances) {
        final spec = EventSpec.of(d.key)!;
        for (final level in const ['beginner', 'intermediate', 'advanced']) {
          if (level == 'beginner' && !spec.beginnerOk) continue;
          final focus = switch (spec.sport) {
            EventSport.triathlon => TrainingFocus.triathlon,
            EventSport.duathlon => TrainingFocus.duathlon,
            EventSport.ride => TrainingFocus.ride,
            EventSport.swim => TrainingFocus.swim,
            _ => TrainingFocus.run,
          };
          final p = _p(focus, level, d.key, spec.weeksFor(level).$1, const [1, 2, 4, 6, 7], 75, const {6: 420, 7: 240});
          if (feas(p).issues.contains('tooShort')) fails.add('${d.key}/$level');
        }
      }
      expect(fails, isEmpty, reason: fails.join('\n'));
    });
  });

  group('M5 taper', () {
    for (final (name, p) in [
      ('swim1500 novice', _p(TrainingFocus.swim, 'beginner', 'swim1500', 20, const [1, 3, 5], 60, const {}, swim400: false)),
      ('swim3800', _p(TrainingFocus.swim, 'intermediate', 'swim3800', 14, const [1, 3, 5, 6], 75, const {})),
      ('marathon', _p(TrainingFocus.run, 'intermediate', 'm', 18, const [2, 4, 6, 7], 60, const {7: 200})),
      ('Ironman', _p(TrainingFocus.triathlon, 'intermediate', 'ironman', 26, const [1, 2, 3, 4, 6, 7], 90, const {6: 420, 7: 240})),
    ]) {
      test('$name: the taper cuts the volume by ≥ 40 % on average (Bosquet 2007)', () {
        final plan = gen(p);
        final race = plan.firstWhere((w) => w.intensity == 'race').date;
        int minutes(int w) => plan
            .where((x) => weekOf(x) == w && x.intensity != 'race' && daysBetween(x.date, race) > 1)
            .fold(0, (a, x) => a + x.durationMin);
        final weeks = plan.map(weekOf).toSet().toList()..sort();
        final taper = weeks.where((w) => plan.any((x) => weekOf(x) == w && x.phase == 'taper' && x.intensity != 'race')).toList();
        final load = weeks.lastWhere((w) => w < taper.first && plan.any((x) => weekOf(x) == w && x.phase != 'recovery'));
        final mean = taper.map(minutes).fold(0, (a, b) => a + b) / taper.length / minutes(load);
        expect(mean, lessThanOrEqualTo(0.6), reason: '${taper.map(minutes)} vs ${minutes(load)}');
      });
    }
  });

  group('M6 cold start', () {
    test('advanced 6 days without weekly km: ≤ 40 km and a single quality run in the first two weeks', () {
      final p = _p(TrainingFocus.run, 'advanced', '10k', 12, const [1, 2, 3, 4, 6, 7], 75, const {7: 120});
      final plan = gen(p);
      for (final w in [0, 1]) {
        final runs = plan.where((x) => weekOf(x) == w && x.sport == Sport.run);
        // (≤ 40 km planned volume; quality runs are time-defined and add a little.)
        expect(runs.fold(0.0, (a, x) => a + runningKm(x)), lessThanOrEqualTo(45));
        expect(runs.where((x) => x.intensity == 'tempo' || x.intensity == 'intervals').length, lessThanOrEqualTo(1));
      }
    });

    test('a slow runner\'s first long run is ≤ ~85 min', () {
      final p = _p(TrainingFocus.run, 'intermediate', 'm', 18, const [1, 2, 4, 6, 7], 60, const {7: 200}, rt: const {'10k': 70 * 60});
      final first = gen(p).firstWhere((w) => w.sport == Sport.run && w.intensity == 'long');
      expect(first.durationMin, lessThanOrEqualTo(85));
    });
  });

  test('M7 hybrid marathon: no lower-body strength in the 10 days before the race', () {
    final p = _p(TrainingFocus.hybrid, 'intermediate', 'm', 18, const [1, 2, 3, 4, 6, 7], 60, const {7: 200});
    final plan = gen(p);
    final race = plan.firstWhere((w) => w.intensity == 'race').date;
    final late = plan.where((w) => w.sport == Sport.gym && daysBetween(w.date, race) <= 10).toList();
    expect(late, isNotEmpty);
    for (final g in late) {
      // By reference: the program without its leg exercises (gymModNoLegs) – no leg day at all.
      final t = templates.firstWhere((t) => t.id == g.templateId);
      expect(legHeavyProgram(t), isFalse, reason: '${g.date} ${g.title}');
      final ex = plannedGymExercises(g, t);
      expect(ex, isNotEmpty);
      expect(ex.where((e) => classifyLift(e.exId, e.name).lower), isEmpty, reason: '${g.date} ${g.title}');
      expect(g.description, contains(l.wGymRaceWeekNote));
    }
  });

  test('L1 masters ≥ 60: 2:1 loading / recovery', () {
    final p = _p(TrainingFocus.run, 'intermediate', 'm', 18, const [2, 4, 6, 7], 60, const {7: 200}, age: 60);
    final phases = PlanGenerator.phasesFor(p, start: _start);
    expect(phases.indexOf('recovery'), 2, reason: '$phases');
    final young = PlanGenerator.phasesFor(
      _p(TrainingFocus.run, 'intermediate', 'm', 18, const [2, 4, 6, 7], 60, const {7: 200}),
      start: _start,
    );
    expect(young.indexOf('recovery'), 3, reason: '$young');
  });

  test('L2 gym beginners never go down to RIR 1', () {
    final p = _p(TrainingFocus.gym, 'beginner', null, 8, const [1, 3, 5], 60, const {}, gymGoal: 'strength', planWeeks: 8);
    final plan = gen(p, weeks: 8);
    expect(plan.where((w) => w.description.contains(l.wGymLoadDesc(1)) || w.description.contains(l.wGymLoadDescNoDeload(1))), isEmpty);
  });

  test('L3 the race step is labelled by its actual intensity', () {
    final p = _p(TrainingFocus.run, 'intermediate', 'hm', 14, const [2, 4, 6, 7], 60, const {7: 150});
    final step = gen(p).firstWhere((w) => w.intensity == 'race').steps.single;
    final pz = PaceZones(Vdot.of(p.athlete)!);
    final pace = (step.paceMin! + step.paceMax!) ~/ 2;
    double off(String z) {
      final (fast, slow) = pz.range(z);
      return pace < fast ? (fast - pace).toDouble() : (pace > slow ? (pace - slow).toDouble() : 0.0);
    }

    for (final z in const ['M', 'T', 'I']) {
      expect(off(step.zone), lessThanOrEqualTo(off(z)), reason: '${step.zone} vs $z');
    }
  });

  group('L6 gentle first weeks for beginners', () {
    test('fartlek of a beginner without race times: threshold effort, RPE-capped, in the first weeks', () {
      final p = _p(TrainingFocus.run, 'beginner', '5k', 9, const [2, 4, 6], 45, const {});
      final first = gen(p).firstWhere((w) => w.title == l.wFartlek);
      final work = first.steps.where((s) => s.isWork);
      expect(work.every((s) => s.zone == 'T' && s.note == l.stepFartlekSoftNote), isTrue);
    });

    test('sprint beginner: brick runs at an easy effort', () {
      final p = _p(TrainingFocus.triathlon, 'beginner', 'sprint', 10, const [1, 3, 5, 6, 7], 60, const {}, swim400: false);
      final bricks = gen(p).where((w) => w.sport == Sport.run && w.intensity == 'moderate').toList();
      expect(bricks, isNotEmpty);
      for (final b in bricks) {
        expect(b.steps.where((s) => s.isWork).every((s) => s.zone == 'E' && s.paceMin == null), isTrue);
      }
    });
  });

  test('QA 2026-11: the long session (and a race by plan length) is on the weekend whenever the days allow it', () {
    // Quick setup, hybrid 10 km by plan length: the preselected Mon / Wed / Fri put long run and race on a Friday.
    expect(defaultTrainingDays.any((d) => d >= 6), isTrue);
    final fails = <String>[];
    for (final f in TrainingFocus.values.where((f) => f != TrainingFocus.gym)) {
      for (final level in const ['beginner', 'intermediate']) {
        for (final ev in const [null, '10k']) {
          final def = UserProfile(
            level: level,
            focus: f,
            experience: {...f.sports},
            goals: const ['race'],
            athlete: AthleteData(eventDistance: ev),
          );
          final race = PlanGenerator.raceDayForWeeks(def, DateTime(2026, 11, 11), 12);
          if (race.weekday < 6) fails.add('${f.name}/$level/$ev default days: race on ${race.weekday}');
          for (var mask = 1; mask < 128; mask++) {
            final days = [
              for (var i = 0; i < 7; i++)
                if (mask & (1 << i) != 0) i + 1,
            ];
            if (days.length < 2 || !days.any((d) => d >= 6)) continue;
            final p = UserProfile(
              level: level,
              focus: f,
              experience: {...f.sports},
              trainingDays: days,
              goals: const ['race', 'strength'],
              athlete: AthleteData(eventDistance: ev),
            );
            final ld = PlanGenerator.longDayOf(p);
            if (ld != null && ld < 6) fails.add('${f.name}/$level/$ev $days: long day $ld');
          }
        }
      }
    }
    expect(fails, isEmpty, reason: fails.take(20).join('\n'));
  });
}

/// Issue texts as the feasibility card shows the new ones.
class FeasibilityText {
  static String of(AppLocalizations l, PlanFeasibility f, String issue) => f.extraIssueText(l, issue, dayName: (d) => '$d') ?? '';
}
