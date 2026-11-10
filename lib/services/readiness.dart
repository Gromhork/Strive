import 'dart:math';

import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'cardio_progression.dart';
import 'plan_adjuster.dart';
import 'plan_recalibrate.dart';
import 'zones.dart';

/// "Nicht 100 % fit?" – how the athlete feels on the day of a planned workout.
enum Readiness { sick, pain, tired, time }

/// Hints shown with a [ReadinessPlan] (docs/training-science.md §13).
enum ReadinessHint {
  /// Above-the-neck rule: mild head-cold symptoms without fever → rest or very easy; fever,
  /// aching muscles, chest or stomach symptoms → no training.
  aboveNeck,

  /// Back after illness: the next hard sessions become easy; after ≥ 10 days off "Plan
  /// überprüfen" rebuilds at 50–70 % (§1.5 R4).
  returnRule,

  /// Pain-monitoring model: ≤ 3/10 that settles by the next morning is OK, otherwise stop.
  painRule,

  /// Persistent or worsening pain → see a doctor / physiotherapist.
  seeDoctor,

  /// Run swapped for low-impact cross-training.
  swapped,

  /// Key session → easy session (~80 % of the time).
  keyToEasy,

  /// Easy session shortened.
  shorter,

  /// Strength: about a third fewer sets, same loads, 2–3 reps in reserve.
  gymLighter,

  /// Strength: fewer sets / exercises to fit the time – main lifts first.
  gymShorter,

  /// Endurance: shortened, warm-up and cool-down kept.
  timeStructure,

  /// The workout already fits into the available time.
  fits,
}

class ReadinessPlan {
  const ReadinessPlan(this.kind, this.changes, this.hints);
  final Readiness kind;

  /// Workout before → after (status 'skipped' = dropped).
  final List<(PlannedWorkout, PlannedWorkout)> changes;
  final List<ReadinessHint> hints;

  bool get isEmpty => changes.isEmpty;
}

/// Maps "sick / pain / tired / little time" to the existing, science-based plan edits
/// ([Recalibrator.toEasy], [AutoAdjuster.scaleWorkout]); nothing is saved here.
class ReadinessAdvisor {
  ReadinessAdvisor(this.l, this.profile, {required this.plans, required this.sessions, required this.now});

  final AppLocalizations l;
  final UserProfile profile;
  final List<PlannedWorkout> plans;
  final List<Session> sessions;
  final DateTime now;

  /// Share of the sets a tired / sore lifter keeps (volume −⅓, load unchanged).
  static const gymKeep = 2 / 3;

  /// Share of an easy endurance session kept when tired.
  static const easyKeep = 0.75;

  /// Longest easy session when something hurts (minutes).
  static const painMaxMin = 30;

  /// Pain areas that running doesn't load much (no swap to cycling).
  static const upperBodyPain = {'shoulder', 'arm', 'neck'};

  late final _recal = Recalibrator(l, profile, plans: plans, sessions: sessions, now: now, fillGaps: false);

  /// Proposal for [p]. [minutes]: available time ([Readiness.time]). [exercises]: the gym
  /// workout's exercises (the plan's own or its program's).
  ///
  /// [painArea] (pain): where it hurts – upper-body pain (shoulder, arm, neck) doesn't turn
  /// a run into a ride; the run just gets easy and short.
  ReadinessPlan propose(PlannedWorkout p, Readiness kind, {int? minutes, List<GymExercise> exercises = const [], String? painArea}) {
    final gym = p.sport == Sport.gym;
    final ex = p.exercises.isNotEmpty ? p.exercises : exercises;
    switch (kind) {
      case Readiness.sick:
        final day = dayOnly(p.date);
        // Return after illness: hard sessions of the next two days become easy.
        final next = plans.where((x) {
          final d = daysBetween(day, dayOnly(x.date));
          return x.id != p.id && x.status == 'planned' && d >= 1 && d <= 2 && x.sport.isCardio && isHardPlan(x) && x.intensity != 'race';
        });
        return ReadinessPlan(
          kind,
          [
            (p, _edit(p, {'status': 'skipped'})),
            for (final x in next) (x, _plain(_recal.toEasy(x))),
          ],
          const [ReadinessHint.aboveNeck, ReadinessHint.returnRule],
        );
      case Readiness.tired:
        if (gym) return ReadinessPlan(kind, _gym(p, _lighter(ex)), const [ReadinessHint.gymLighter]);
        if (isHardPlan(p)) return ReadinessPlan(kind, [(p, _plain(_recal.toEasy(p)))], const [ReadinessHint.keyToEasy]);
        final shorter = _plain(AutoAdjuster.scaleWorkout(p, easyKeep, profile));
        return ReadinessPlan(kind, [(p, _withMin(shorter, max(15, shorter.durationMin)))], const [ReadinessHint.shorter]);
      case Readiness.pain:
        if (gym) return ReadinessPlan(kind, _gym(p, _lighter(ex)), const [ReadinessHint.painRule, ReadinessHint.seeDoctor]);
        final cross = p.sport == Sport.run && !upperBodyPain.contains(painArea) ? _crossSport() : null;
        if (cross != null) {
          final swapped = _plain(_recal.toEasy(_edit(p, {'sport': cross.name})));
          return ReadinessPlan(kind, [(p, swapped)], const [ReadinessHint.swapped, ReadinessHint.painRule, ReadinessHint.seeDoctor]);
        }
        final easy = isHardPlan(p) ? _plain(_recal.toEasy(p)) : p;
        final short = fitMinutes(easy, min(easy.durationMin, painMaxMin));
        return ReadinessPlan(kind, [if (!samePlan(p, short)) (p, short)], const [ReadinessHint.painRule, ReadinessHint.seeDoctor]);
      case Readiness.time:
        final m = minutes ?? p.durationMin;
        if (m >= p.durationMin) return ReadinessPlan(kind, const [], const [ReadinessHint.fits]);
        if (gym) return ReadinessPlan(kind, _gym(p, fitGymMinutes(ex, m)), const [ReadinessHint.gymShorter]);
        return ReadinessPlan(kind, [(p, fitMinutes(p, m))], const [ReadinessHint.timeStructure]);
    }
  }

  /// Low-impact sport the athlete does (bike before swim), or null.
  Sport? _crossSport() {
    bool does(Sport s) => profile.focus.sports.contains(s) || plans.any((x) => x.sport == s) || sessions.any((x) => x.sport == s);
    return does(Sport.ride) ? Sport.ride : (does(Sport.swim) ? Sport.swim : null);
  }

  List<(PlannedWorkout, PlannedWorkout)> _gym(PlannedWorkout p, List<GymExercise> ex) {
    if (ex.isEmpty) return const [];
    final after = _plain(_edit(p, {'exercises': ex.map((e) => e.toMap()).toList()}));
    final mins = estimateGymMinutes(ex);
    return [(p, _withMin(after, min(p.durationMin, mins)))];
  }

  /// About a third fewer work sets per exercise (at least one), warm-up sets kept.
  static List<GymExercise> _lighter(List<GymExercise> ex) => [
    for (final e in ex) _keepWorkSets(e, max(1, (e.workSets.length * gymKeep).round())),
  ];

  static GymExercise _keepWorkSets(GymExercise e, int n) {
    final c = e.copy(resetDone: true);
    var work = 0;
    c.sets.retainWhere((s) => s.warmup || ++work <= n);
    return c;
  }

  /// Strength session cut to [minutes] ([estimateGymMinutes]): one work set at a time from
  /// the exercise with the most sets left (later exercises – usually accessories – first),
  /// never below one; then accessories are dropped from the end, the first exercise stays.
  static List<GymExercise> fitGymMinutes(List<GymExercise> ex, int minutes) {
    final out = [for (final e in ex) e.copy(resetDone: true)];
    while (estimateGymMinutes(out) > minutes) {
      GymExercise? pick;
      for (final e in out.reversed) {
        if (e.workSets.length > 1 && (pick == null || e.workSets.length > pick.workSets.length)) pick = e;
      }
      if (pick != null) {
        pick.sets.removeAt(pick.sets.lastIndexWhere((s) => !s.warmup));
      } else if (out.length > 1) {
        out.removeLast();
      } else {
        break;
      }
    }
    return out;
  }

  /// Endurance workout shortened to about [minutes]: warm-up and cool-down stay (shortened
  /// in proportion, at least 5 min or their own length), the main part is scaled
  /// ([AutoAdjuster.scaleWorkout]: continuous parts in length, interval sets by whole repeats).
  PlannedWorkout fitMinutes(PlannedWorkout p, int minutes) {
    if (minutes >= p.durationMin) return p;
    final f0 = minutes / p.durationMin;
    if (p.steps.isEmpty) {
      return _plain(
        _edit(p, {
          'durationMin': minutes,
          'distanceKm': p.distanceKm == null ? null : double.parse((p.distanceKm! * f0).toStringAsFixed(1)),
        }),
      );
    }
    final est0 = max(1, estimateStepsSec(p.steps, p.sport, profile));
    final target = est0 * f0;
    // Frame: warm-up / cool-down shortened in proportion, but kept.
    final frameF = max(0.5, f0);
    WorkoutStep frame(WorkoutStep s) {
      if (s.kind != 'warmup' && s.kind != 'cooldown') return s;
      final sec = s.durationSec == null ? null : min(s.durationSec!, max(300, (s.durationSec! * frameF / 60).round() * 60));
      final m =
          s.distanceM == null
              ? null
              : min(s.distanceM!, max(p.sport == Sport.swim ? 100.0 : 1000.0, (s.distanceM! * frameF / 100).round() * 100.0));
      return WorkoutStep(
        kind: s.kind,
        durationSec: sec,
        distanceM: m,
        zone: s.zone,
        paceMin: s.paceMin,
        paceMax: s.paceMax,
        powerMin: s.powerMin,
        powerMax: s.powerMax,
        hrMin: s.hrMin,
        hrMax: s.hrMax,
        note: s.note,
      );
    }

    final framed = _edit(p, {
      'steps': [for (final s in p.steps) frame(s).toMap()],
    });
    // Interval set: drop whole repeats first (each keeps its length and intensity).
    final dropped = _dropRepeats(framed, target);
    var g = f0;
    var w = dropped ?? framed;
    for (var i = 0; i < 4 && (dropped == null || estimateStepsSec(w.steps, p.sport, profile) > target * 1.04); i++) {
      w = AutoAdjuster.scaleWorkout(dropped ?? framed, g, profile);
      final got = estimateStepsSec(w.steps, p.sport, profile);
      if (got <= 0 || (got / target - 1).abs() < 0.04) break;
      g = max(0.1, g * target / got);
    }
    final ratio = estimateStepsSec(w.steps, p.sport, profile) / est0;
    final allDistance = w.steps.every((s) => s.distanceM != null);
    final km =
        p.distanceKm == null
            ? null
            : double.parse(
              (allDistance ? w.steps.fold<double>(0, (x, s) => x + s.distanceM!) / 1000 : p.distanceKm! * ratio).toStringAsFixed(1),
            );
    return _plain(_edit(w, {'durationMin': max(10, min(minutes, (p.durationMin * ratio).round())), 'distanceKm': km}));
  }

  /// [p] with as many repeats of its interval set (≥ 3 identical work steps with recoveries)
  /// as fit into [targetSec], at least two; null without such a set or when nothing drops.
  PlannedWorkout? _dropRepeats(PlannedWorkout p, double targetSec) {
    final steps = p.steps;
    final work = [
      for (var i = 0; i < steps.length; i++)
        if (steps[i].kind == 'work') i,
    ];
    if (work.length < 3) return null;
    final w0 = steps[work.first];
    if (work.any((i) => steps[i].zone != w0.zone || steps[i].durationSec != w0.durationSec || steps[i].distanceM != w0.distanceM)) {
      return null;
    }
    for (var i = work.first; i <= work.last; i++) {
      if (steps[i].kind != 'work' && steps[i].kind != 'recovery') return null;
    }
    final rec = steps[work.first + 1].kind == 'recovery' ? steps[work.first + 1] : null;
    List<WorkoutStep> withReps(int n) => [
      ...steps.take(work.first),
      for (var i = 0; i < n; i++) ...[w0, if (rec != null && i < n - 1) rec],
      ...steps.skip(work.last + 1),
    ];
    var n = work.length;
    while (n > 2 && estimateStepsSec(withReps(n), p.sport, profile) > targetSec * 1.04) {
      n--;
    }
    if (n == work.length) return null;
    return _edit(p, {
      'steps': [for (final s in withReps(n)) s.toMap()],
    });
  }

  static PlannedWorkout _edit(PlannedWorkout p, Map<String, dynamic> m) => PlannedWorkout.fromMap(p.id, {...p.toMap(), ...m});

  static PlannedWorkout _withMin(PlannedWorkout p, int min) => _edit(p, {'durationMin': min});

  /// Without the automatic-adjustment record: this change is undone from the plan history.
  static PlannedWorkout _plain(PlannedWorkout p) => PlannedWorkout.fromMap(p.id, p.toMap()..remove('auto'));

  static bool samePlan(PlannedWorkout a, PlannedWorkout b) =>
      a.sport == b.sport && a.title == b.title && a.durationMin == b.durationMin && a.distanceKm == b.distanceKm && a.status == b.status;
}
