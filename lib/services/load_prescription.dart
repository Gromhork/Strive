import 'dart:math';

import '../core/format.dart';
import '../data/exercise_db.dart';
import '../data/models.dart';
import 'gym_tools.dart';

/// Where a prescribed load comes from.
enum LoadSource { history, oneRm, estimate, bodyweight }

/// The four anchor lifts the setup asks 1RMs for (keys of [AthleteData.oneRm]).
enum Anchor { squat, bench, deadlift, ohp }

/// A suggested working load for one exercise.
class Prescription {
  /// Work-set weight in kg (per dumbbell for dumbbell/kettlebell exercises; added
  /// load or 0 for bodyweight exercises).
  final double weight;

  /// Target reps per work set.
  final int reps;
  final LoadSource source;

  /// Estimated 1RM the weight was derived from (null for pure progression / bodyweight).
  final double? e1rm;

  /// Double-progression step taken from the last session (history only).
  final ProgressionKind? progression;

  /// Days since the last valid session when the load was reduced after a break.
  final int? breakDays;

  /// Load reduced because of the plan phase (deload / taper week).
  final bool phaseAdjusted;

  /// Plan phase that reduced the load ('recovery' | 'taper'), null otherwise.
  final String? phase;

  /// The weight is meant per hand (dumbbells/kettlebells, estimated loads only).
  final bool perHand;

  /// True when the numbers come from the user's own past sets.
  final bool fromHistory;

  /// Optional per-work-set rep targets (beat last time set by set); falls back to [reps].
  final List<int> setReps;

  const Prescription({
    required this.weight,
    required this.reps,
    required this.source,
    this.e1rm,
    this.progression,
    this.breakDays,
    this.phaseAdjusted = false,
    this.phase,
    this.perHand = false,
    this.fromHistory = false,
    this.setReps = const [],
  });

  int repsForSet(int workIndex) => workIndex < setReps.length ? setReps[workIndex] : reps;

  @override
  String toString() => 'Prescription($weight kg × $reps, $source, e1rm: ${e1rm?.toStringAsFixed(1)})';
}

/// Equipment family used for ratios, rounding and minimum loads.
enum _Kind { barbell, dumbbell, machine, bodyweight, unknown }

class _Info {
  const _Info(this.kind, this.lower, {this.anchor, this.ratio = 0, this.curl = false});
  final _Kind kind;
  final bool lower;
  final Anchor? anchor;

  /// Exercise 1RM ≈ anchor 1RM × ratio (per dumbbell for dumbbell exercises).
  final double ratio;
  final bool curl;
}

class _Entry {
  _Entry(this.date, this.sets, this.top);
  final DateTime date;
  final List<GymSet> sets;
  final double top; // top-set e1RM of the session
}

/// Prescribes working weights for gym exercises.
///
/// Order of evidence (most to least personal):
/// 1. **History** – the user's own done work sets of the last ~12 weeks, cleaned from
///    imported/empty sessions and outliers, progressed with double progression
///    (Helms et al. 2018) or re-derived from a recency-weighted e1RM.
/// 2. **Setup 1RMs** – the four anchor lifts from the setup, mapped to the exercise with
///    ratio tables (practice-based ratios in line with population strength-standard data
///    such as ExRx/StrengthLevel; deliberately on the low side).
/// 3. **Estimate** – strength standards as multiples of (allometrically scaled) body
///    weight per training level, adjusted for sex and age; prescribed at RIR 3 so the
///    first session feels easy and the history takes over from session two.
///
/// Loads from an e1RM use the inverse Epley formula with reps in reserve
/// (weight = e1RM / (1 + (reps + RIR) / 30)), which matches the RIR-based RPE chart of
/// Zourdos et al. 2016 / Helms et al. 2016 within ~2–3 % for 3–12 reps.
class LoadPrescriber {
  LoadPrescriber({required List<Session> history, required this.profile, this.db, DateTime? now})
    : now = now ?? DateTime.now(),
      _sessions =
          history
              .where((s) => s.exercises.isNotEmpty && !s.start.isAfter(now ?? DateTime.now()))
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));

  final UserProfile profile;
  final ExerciseDb? db;
  final DateTime now;
  final List<Session> _sessions;

  /// History window for "current" training data.
  static const recentWindow = Duration(days: 84);

  /// Older data (up to a year) is still better than a body-weight guess, but discounted.
  static const maxWindow = Duration(days: 365);

  /// Phases that reduce load (deload / taper weeks).
  static bool lighterPhase(String? phase) => phase == 'recovery' || phase == 'taper';

  /// Deload weeks also drop one work set (volume is the main fatigue driver;
  /// Bell et al. 2023 deload consensus: reduce volume and/or intensity ~10–50 %).
  static bool dropsSet(String? phase) => phase == 'recovery';

  // ───────────────────────────── Public API ─────────────────────────────

  Prescription? forExercise(GymExercise e, {String? phase}) {
    if (e.exId.isEmpty || e.exId == 'manual') return null;
    final info = _info(e);
    final hist = _history(e.exId, info);
    Prescription? p;
    if (info.kind == _Kind.bodyweight || (info.kind == _Kind.unknown && _looksBodyweight(e.exId))) {
      p = _bodyweight(e, hist);
    } else if (hist.isNotEmpty) {
      p = _fromHistory(e, info, hist);
    } else {
      p = _fromAnchor(e, info);
    }
    if (p == null || !lighterPhase(phase) || p.weight <= 0) return p;
    // Deload / taper: ~90 % load (Bosquet 2007 taper meta-analysis: keep intensity high,
    // cut volume; a ~10 % lighter load keeps the week clearly easier).
    return Prescription(
      weight: _floorStep(p.weight * 0.9, info),
      reps: p.reps,
      source: p.source,
      e1rm: p.e1rm,
      progression: p.progression == ProgressionKind.increase ? ProgressionKind.hold : p.progression,
      breakDays: p.breakDays,
      phaseAdjusted: true,
      phase: phase,
      perHand: p.perHand,
      fromHistory: p.fromHistory,
    );
  }

  /// Copies of [exercises] with weight (and target reps) filled into the work sets;
  /// warm-up sets derive their weights via [warmupSets] ratios. Explicit template weights
  /// (weight > 0) are kept when there is no history for that exercise.
  List<GymExercise> apply(List<GymExercise> exercises, {String? phase}) => [
    for (final e in exercises) _applyOne(e, phase),
  ];

  GymExercise _applyOne(GymExercise src, String? phase) {
    final e = src.copy(resetDone: true);
    final p = forExercise(e, phase: phase);
    final explicit = e.workSets.any((s) => s.weight > 0);
    if (p != null && !(explicit && !p.fromHistory)) {
      var k = 0;
      for (final s in e.sets) {
        if (s.warmup) continue;
        if (s.type == SetType.drop) {
          s.weight = _floorStep(p.weight * 0.75, _info(e));
          s.reps = p.reps;
        } else {
          s.weight = p.weight;
          s.reps = p.repsForSet(k++);
        }
      }
      final warm = e.sets.where((s) => s.warmup).toList();
      if (warm.isNotEmpty && p.weight > 0) {
        final info = _info(e);
        final gen = warmupSets(p.weight, bar: info.kind == _Kind.barbell ? 20 : p.weight * 0.3);
        // Align from the end: the last warm-up is the one closest to the work weight.
        for (var i = 0; i < warm.length; i++) {
          final g = gen[max(0, gen.length - warm.length + i)];
          warm[i].weight = _floorStep(g.weight, info);
          if (warm[i].reps <= 0) warm[i].reps = g.reps;
        }
      }
    }
    if (dropsSet(phase)) {
      final work = e.sets.where((s) => !s.warmup && s.type != SetType.drop).toList();
      if (work.length > 2) e.sets.remove(work.last);
    }
    return e;
  }

  // ───────────────────────────── History ─────────────────────────────

  /// Valid sessions (newest first) for [exId] after cleaning:
  /// * only done work sets (no warm-ups / drop sets), 1–30 reps, weight > 0 for loaded
  ///   exercises – this also removes imported sessions without real set data;
  /// * implausible sets inside a session (e1RM > 1.5× or < 0.5× the session median);
  /// * single-set sessions > 20 % off the multi-set sessions (quick tests, typos);
  /// * outlier sessions by top-set e1RM outside median ± max(3·1.4826·MAD, 15 %)
  ///   (robust z-score, Leys et al. 2013), or ± 30 % with few points / MAD = 0.
  List<_Entry> _history(String exId, _Info info) {
    final loaded = info.kind != _Kind.bodyweight;
    final recent = <_Entry>[], old = <_Entry>[];
    for (final s in _sessions) {
      final age = now.difference(s.start);
      if (age > maxWindow) break;
      var sets = <GymSet>[
        for (final ex in s.exercises.where((x) => x.exId == exId))
          for (final st in ex.sets)
            if (st.done && !st.warmup && st.type != SetType.drop && st.reps >= 1 && st.reps <= 30 && st.weight >= 0 && st.weight < 1000)
              st,
      ];
      if (loaded) sets = sets.where((st) => st.weight > 0).toList();
      // Imported sessions (Health Connect, …) rarely carry real sets; they only count when
      // they contain done sets with reps (and load) – otherwise they are skipped here.
      if (sets.isEmpty) continue;
      if (loaded && sets.length >= 3) {
        final med = _median(sets.map(_e1).toList());
        sets = sets.where((st) => _e1(st) <= med * 1.5 && _e1(st) >= med * 0.5).toList();
      }
      final entry = _Entry(s.start, sets, sets.map(_e1).reduce(max));
      (age <= recentWindow ? recent : old).add(entry);
    }
    final pool = recent.isNotEmpty ? recent : old;
    if (!loaded || pool.length < 2) return pool;
    return _dropOutliers(pool);
  }

  List<_Entry> _dropOutliers(List<_Entry> pool) {
    var list = pool;
    final multi = list.where((e) => e.sets.length > 1).toList();
    if (multi.isNotEmpty) {
      final ref = _median(multi.map((e) => e.top).toList());
      list = list.where((e) => e.sets.length > 1 || (e.top / ref - 1).abs() <= 0.2).toList();
    }
    if (list.length >= 2) {
      final tops = list.map((e) => e.top).toList();
      final med = _median(tops);
      final mad = _median(tops.map((t) => (t - med).abs()).toList());
      final band = list.length < 4 || mad == 0 ? med * 0.3 : max(3 * 1.4826 * mad, med * 0.15);
      list = list.where((e) => (e.top - med).abs() <= band).toList();
    }
    // Nothing survived (e.g. two wildly different points): trust the most recent one.
    return list.isEmpty ? [pool.first] : list;
  }

  /// Effective e1RM of a set: Epley on reps + reps in reserve (from RPE, else assume 1
  /// – logged work sets are usually close to, but not at, failure).
  static double _e1(GymSet s) => e1rm(s.weight, s.reps + (s.rpe != null ? (10 - s.rpe!).clamp(0, 5).round() : 1));

  /// Recency-weighted median of the last ≤ 6 sessions (half-life 14 days).
  double _robustE1rm(List<_Entry> hist) {
    final pts = [
      for (final h in hist.take(6)) (h.top, pow(0.5, now.difference(h.date).inHours / 24 / 14).toDouble()),
    ];
    return _weightedMedian(pts);
  }

  Prescription? _fromHistory(GymExercise e, _Info info, List<_Entry> hist) {
    final last = hist.first;
    final days = now.difference(last.date).inDays;
    final bottom = _bottom(e);
    final top = _top(e, bottom);
    final est = _robustE1rm(hist);
    final lastW = last.sets.map((s) => s.weight).reduce(max);
    final medReps = _median(last.sets.map((s) => s.reps.toDouble()).toList());
    final repsFit = medReps >= bottom - 2 && medReps <= top + 3;

    Prescription viaE1rm(double factor, {int? breakDays}) => Prescription(
      weight: _clampMin(_floorStep(_loadFor(est * factor, bottom, 2), info), info),
      reps: bottom,
      source: LoadSource.history,
      e1rm: est,
      breakDays: breakDays,
      fromHistory: true,
    );

    // > 6 weeks off (or older data only): detraining – re-derive from e1RM × 0.9
    // (strength is largely kept for ~3 weeks, then declines; Mujika & Padilla 2000,
    // McMaster 2013). Data older than the 12-week window: × 0.85.
    if (days > 42) return viaE1rm(days > recentWindow.inDays ? 0.85 : 0.9, breakDays: days);
    // Different rep range than last time (other program): use the e1RM, not the sets.
    if (!repsFit) return viaE1rm(days > 21 ? 0.95 : 1, breakDays: days > 21 ? days : null);
    // 3–6 weeks off: hold the last weight, 5–10 % lighter.
    if (days > 21) {
      return Prescription(
        weight: _floorStep(lastW * (days > 28 ? 0.9 : 0.95), info),
        reps: bottom,
        source: LoadSource.history,
        e1rm: est,
        breakDays: days,
        fromHistory: true,
      );
    }
    final prog = suggestProgression(e, last.sets, _asExercise(e, info));
    if (prog == null) return viaE1rm(1);
    final w = prog.kind == ProgressionKind.deload ? _floorStep(prog.weight, info) : _roundStep(prog.weight, info);
    return Prescription(
      weight: w,
      reps: prog.reps,
      source: LoadSource.history,
      e1rm: est,
      progression: prog.kind,
      fromHistory: true,
      setReps:
          prog.kind == ProgressionKind.addReps
              ? [for (final s in last.sets) s.reps < top ? max(s.reps + 1, bottom) : top]
              : const [],
    );
  }

  Prescription _bodyweight(GymExercise e, List<_Entry> hist) {
    final bottom = _bottom(e);
    if (hist.isNotEmpty && now.difference(hist.first.date).inDays <= 42) {
      final last = hist.first;
      final prog = suggestProgression(e, last.sets, _asExercise(e, const _Info(_Kind.bodyweight, false)));
      if (prog != null) {
        final top = _top(e, bottom);
        return Prescription(
          weight: prog.weight,
          reps: prog.reps,
          source: LoadSource.bodyweight,
          progression: prog.kind,
          fromHistory: true,
          setReps:
              prog.kind == ProgressionKind.addReps
                  ? [for (final s in last.sets) s.reps < top ? max(s.reps + 1, bottom) : s.reps + 1]
                  : const [],
        );
      }
    }
    return Prescription(weight: 0, reps: bottom, source: LoadSource.bodyweight);
  }

  // ───────────────────────────── 1RM & estimate ─────────────────────────────

  Prescription? _fromAnchor(GymExercise e, _Info info) {
    if (info.anchor == null || info.ratio <= 0) return null;
    final (anchor1Rm, src) = anchorOneRm(info.anchor!);
    final ex1Rm = anchor1Rm * info.ratio;
    final reps = _bottom(e);
    // RIR 2 for a known 1RM; RIR 3 for a body-weight guess (start easy, let history take over).
    final rir = src == LoadSource.oneRm ? 2 : 3;
    final w = _clampMin(_floorStep(_loadFor(ex1Rm, reps, rir), info), info);
    return Prescription(
      weight: w,
      reps: reps,
      source: src,
      e1rm: ex1Rm,
      perHand: info.kind == _Kind.dumbbell,
    );
  }

  /// 1RM of an anchor lift: from the setup, inferred from the other setup 1RMs via the
  /// standards' ratios, or estimated from body weight.
  (double, LoadSource) anchorOneRm(Anchor a) {
    final given = <Anchor, double>{};
    final bwLimit = max(profile.weightKg, 40) * 5;
    for (final x in Anchor.values) {
      final v = profile.athlete.oneRm[x.name];
      if (v != null && v > 0 && v < bwLimit) given[x] = v;
    }
    if (given[a] != null) return (given[a]!, LoadSource.oneRm);
    if (given.isNotEmpty) {
      final std = _standards(a);
      final avg = given.entries.map((g) => g.value * std / _standards(g.key)).reduce((x, y) => x + y) / given.length;
      return (avg, LoadSource.oneRm);
    }
    return (_standards(a), LoadSource.estimate);
  }

  /// Estimated 1RM (kg) from strength standards. Multiples of body weight for men by
  /// level, set slightly below common population tables (ExRx / StrengthLevel
  /// "novice / intermediate / advanced") because self-rated levels skew high.
  /// * Body weight is scaled allometrically (strength ∝ mass^0.67, Jaric 2002) around 75 kg.
  /// * Women: ~60 % (upper body) / ~72 % (lower body) of male standards (same sources;
  ///   Miller et al. 1993: larger sex difference in upper-body strength). Diverse: midpoint.
  /// * Age > 40: −1 %/year (max −30 %), sarcopenia-related decline (Keller & Engelhardt 2013).
  double _standards(Anchor a) {
    const table = {
      'beginner': [0.8, 0.6, 1.0, 0.4],
      'intermediate': [1.25, 1.0, 1.5, 0.65],
      'advanced': [1.75, 1.35, 2.1, 0.85],
    };
    final row = table[profile.level] ?? table['beginner']!;
    final mult = row[a.index];
    final bw = profile.weightKg.clamp(40, 200).toDouble();
    final scaled = 75 * pow(bw / 75, 0.67);
    final upper = a == Anchor.bench || a == Anchor.ohp;
    final sex = switch (profile.gender) {
      'f' => upper ? 0.6 : 0.72,
      'm' => 1.0,
      _ => upper ? 0.8 : 0.86,
    };
    final birth = profile.birthYear;
    final age = birth == null ? null : now.year - birth;
    final ageF = age == null || age <= 40 ? 1.0 : max(0.7, 1 - (age - 40) * 0.01);
    return mult * scaled * sex * ageF;
  }

  // ───────────────────────────── Exercise classification ─────────────────────────────

  /// Ratio table for every exercise of the built-in programs (exercise 1RM / anchor 1RM;
  /// dumbbells per dumbbell). Machine/cable values depend on the machine – kept low.
  static const Map<String, _Info> _byId = {
    // Barbell
    '0043': _Info(_Kind.barbell, true, anchor: Anchor.squat, ratio: 1.0), // full squat
    '0025': _Info(_Kind.barbell, false, anchor: Anchor.bench, ratio: 1.0), // bench press
    '0032': _Info(_Kind.barbell, true, anchor: Anchor.deadlift, ratio: 1.0), // deadlift
    '0085': _Info(_Kind.barbell, true, anchor: Anchor.deadlift, ratio: 0.7), // romanian deadlift
    '0027': _Info(_Kind.barbell, false, anchor: Anchor.bench, ratio: 0.7), // bent over row
    '0031': _Info(_Kind.barbell, false, anchor: Anchor.bench, ratio: 0.4, curl: true), // curl
    // Cable / machines
    '2330': _Info(_Kind.machine, false, anchor: Anchor.bench, ratio: 0.7), // lat pulldown
    '0861': _Info(_Kind.machine, false, anchor: Anchor.bench, ratio: 0.7), // seated cable row
    '0227': _Info(_Kind.machine, false, anchor: Anchor.bench, ratio: 0.25), // standing cable fly (per side)
    '0241': _Info(_Kind.machine, false, anchor: Anchor.bench, ratio: 0.4), // triceps pushdown
    '0194': _Info(_Kind.machine, false, anchor: Anchor.bench, ratio: 0.3), // overhead triceps ext.
    '0178': _Info(_Kind.machine, false, anchor: Anchor.ohp, ratio: 0.1), // cable lateral raise
    '0739': _Info(_Kind.machine, true, anchor: Anchor.squat, ratio: 1.6), // 45° leg press
    '0585': _Info(_Kind.machine, true, anchor: Anchor.squat, ratio: 0.45), // leg extension
    '0586': _Info(_Kind.machine, true, anchor: Anchor.squat, ratio: 0.35), // lying leg curl
    '0599': _Info(_Kind.machine, true, anchor: Anchor.squat, ratio: 0.4), // seated leg curl
    '0605': _Info(_Kind.machine, true, anchor: Anchor.squat, ratio: 0.8), // standing calf raise
    '0594': _Info(_Kind.machine, true, anchor: Anchor.squat, ratio: 0.5), // seated calf raise
    // Dumbbells (per dumbbell)
    '0289': _Info(_Kind.dumbbell, false, anchor: Anchor.bench, ratio: 0.37), // bench press
    '0314': _Info(_Kind.dumbbell, false, anchor: Anchor.bench, ratio: 0.32), // incline bench press
    '0405': _Info(_Kind.dumbbell, false, anchor: Anchor.ohp, ratio: 0.37), // seated shoulder press
    '0426': _Info(_Kind.dumbbell, false, anchor: Anchor.ohp, ratio: 0.35), // standing overhead press
    '0334': _Info(_Kind.dumbbell, false, anchor: Anchor.ohp, ratio: 0.12), // lateral raise
    '0378': _Info(_Kind.dumbbell, false, anchor: Anchor.ohp, ratio: 0.1), // rear fly
    '0293': _Info(_Kind.dumbbell, false, anchor: Anchor.bench, ratio: 0.32), // bent over row
    '0313': _Info(_Kind.dumbbell, false, anchor: Anchor.bench, ratio: 0.17, curl: true), // hammer curl
    '0318': _Info(_Kind.dumbbell, false, anchor: Anchor.bench, ratio: 0.13, curl: true), // incline curl
    '0336': _Info(_Kind.dumbbell, true, anchor: Anchor.squat, ratio: 0.2), // lunge
    '0381': _Info(_Kind.dumbbell, true, anchor: Anchor.squat, ratio: 0.2), // rear lunge
    '0410': _Info(_Kind.dumbbell, true, anchor: Anchor.squat, ratio: 0.18), // split squat
    '1760': _Info(_Kind.dumbbell, true, anchor: Anchor.squat, ratio: 0.3), // goblet squat (one dumbbell)
    '1459': _Info(_Kind.dumbbell, true, anchor: Anchor.deadlift, ratio: 0.25), // romanian deadlift
    '1757': _Info(_Kind.dumbbell, true, anchor: Anchor.deadlift, ratio: 0.15), // single-leg deadlift
    '0409': _Info(_Kind.dumbbell, true, anchor: Anchor.squat, ratio: 0.15), // single-leg calf raise
    // Bodyweight
    '0652': _Info(_Kind.bodyweight, false), // pull-up
    '1326': _Info(_Kind.bodyweight, false), // chin-up
    '0662': _Info(_Kind.bodyweight, false), // push-up
    '0814': _Info(_Kind.bodyweight, false), // triceps dip
    '0129': _Info(_Kind.bodyweight, false), // bench dip
    '0499': _Info(_Kind.bodyweight, false), // inverted row
    '0472': _Info(_Kind.bodyweight, false), // hanging leg raise
    '0276': _Info(_Kind.bodyweight, false), // dead bug
    '0514': _Info(_Kind.bodyweight, true), // jump squat
    '1460': _Info(_Kind.bodyweight, true), // walking lunge
    '1373': _Info(_Kind.bodyweight, true), // bodyweight calf raise
    '3561': _Info(_Kind.bodyweight, true), // glute bridge march
    '0630': _Info(_Kind.bodyweight, false), // mountain climber
  };

  /// Name patterns for all other exercises (first match wins). Ratios per equipment family:
  /// barbell / dumbbell (per dumbbell) / machine & cable.
  static const List<(List<String>, List<String>, Anchor, double?, double?, double?)> _patterns = [
    // (any of, none of, anchor, barbell, dumbbell, machine)
    (['leg press'], [], Anchor.squat, null, null, 1.6),
    (['hack squat'], [], Anchor.squat, 0.8, null, 1.0),
    (['goblet'], [], Anchor.squat, null, 0.3, null),
    (['front squat'], [], Anchor.squat, 0.8, 0.22, 0.8),
    (['split squat', 'lunge', 'step-up', 'step up'], [], Anchor.squat, 0.5, 0.2, 0.5),
    (['squat'], ['jump'], Anchor.squat, 1.0, 0.25, 0.9),
    (['romanian', 'stiff leg', 'stiff-leg'], [], Anchor.deadlift, 0.7, 0.25, 0.7),
    (['hip thrust', 'glute bridge'], ['march'], Anchor.squat, 1.0, 0.5, 1.0),
    (['good morning'], [], Anchor.squat, 0.4, null, 0.4),
    (['deadlift'], [], Anchor.deadlift, 1.0, 0.3, 0.9),
    (['leg extension'], [], Anchor.squat, null, null, 0.45),
    (['leg curl'], [], Anchor.squat, null, 0.1, 0.35),
    (['calf'], [], Anchor.squat, 0.6, 0.15, 0.8),
    (['shrug'], [], Anchor.deadlift, 0.6, 0.25, 0.6),
    (['rear delt', 'rear fly', 'reverse fly', 'rear lateral'], [], Anchor.ohp, null, 0.1, 0.15),
    (['lateral raise'], [], Anchor.ohp, null, 0.12, 0.1),
    (['front raise'], [], Anchor.ohp, 0.3, 0.13, 0.12),
    (['upright row'], [], Anchor.ohp, 0.5, 0.2, 0.5),
    (['fly', 'crossover', 'pec deck'], [], Anchor.bench, null, 0.15, 0.25),
    (['incline'], ['curl', 'row', 'fly', 'raise'], Anchor.bench, 0.8, 0.32, 0.8),
    (['decline'], ['curl', 'crunch', 'sit-up'], Anchor.bench, 0.95, 0.35, 0.9),
    (['close grip bench', 'close-grip bench'], [], Anchor.bench, 0.85, null, 0.85),
    (['bench press', 'chest press', 'floor press'], [], Anchor.bench, 1.0, 0.37, 0.9),
    (['shoulder press', 'overhead press', 'military', 'push press', 'arnold'], [], Anchor.ohp, 1.0, 0.37, 0.9),
    (['pulldown', 'pull-down', 'pull down'], [], Anchor.bench, null, null, 0.7),
    (['face pull'], [], Anchor.bench, null, null, 0.3),
    (['pullover'], [], Anchor.bench, 0.3, 0.25, 0.4),
    (['row'], ['upright'], Anchor.bench, 0.7, 0.3, 0.7),
    (['curl'], ['leg'], Anchor.bench, 0.4, 0.15, 0.35),
    (['pushdown', 'push-down', 'skull', 'kickback', 'triceps', 'tricep'], [], Anchor.bench, 0.35, 0.12, 0.4),
  ];

  static const _bwWords = [
    'push-up', 'push up', 'pushup', 'pull-up', 'pull up', 'pullup', 'chin-up', 'chin up', 'dip', 'plank', 'crunch',
    'sit-up', 'sit up', 'leg raise', 'burpee', 'mountain climber', 'bodyweight', 'body weight', 'jump', 'dead bug',
    'inverted row', 'air squat', 'bridge', 'hollow', 'bird dog', 'superman', 'flutter',
  ];

  _Info _info(GymExercise e) {
    final known = _byId[e.exId];
    final dbEx = db?.byId(e.exId);
    final name = (dbEx?.name ?? e.name).toLowerCase();
    if (known != null && (dbEx == null || _kindOfEquipment(dbEx.equipment) == known.kind)) return known;
    final kind = dbEx != null ? _kindOfEquipment(dbEx.equipment) : _kindOfName(name);
    final lower =
        dbEx != null
            ? (const {'upper legs', 'lower legs'}.contains(dbEx.bodyPart) || dbEx.target == 'glutes')
            : RegExp(r'squat|lunge|leg|calf|deadlift|hip|glute').hasMatch(name);
    if (kind == _Kind.bodyweight) return _Info(kind, lower);
    for (final (any, none, anchor, bb, dbR, mc) in _patterns) {
      if (!any.any(name.contains) || none.any(name.contains)) continue;
      final ratio = switch (kind) {
        _Kind.barbell => bb ?? mc,
        _Kind.dumbbell => dbR,
        _Kind.machine => mc ?? bb,
        _ => mc ?? bb,
      };
      if (ratio == null) break;
      return _Info(kind, anchor == Anchor.squat || anchor == Anchor.deadlift || lower, anchor: anchor, ratio: ratio, curl: name.contains('curl'));
    }
    return _Info(kind, lower);
  }

  static _Kind _kindOfEquipment(String eq) => switch (eq) {
    'barbell' || 'ez barbell' || 'olympic barbell' || 'trap bar' => _Kind.barbell,
    'dumbbell' || 'kettlebell' => _Kind.dumbbell,
    'cable' || 'leverage machine' || 'sled machine' || 'smith machine' || 'skierg machine' || 'upper body ergometer' => _Kind.machine,
    'body weight' || 'band' || 'resistance band' || 'assisted' || 'weighted' || 'stability ball' || 'roller' || 'wheel roller' ||
    'rope' || 'medicine ball' || 'bosu ball' => _Kind.bodyweight,
    _ => _Kind.unknown,
  };

  static _Kind _kindOfName(String n) {
    if (n.contains('dumbbell') || n.contains('kettlebell')) return _Kind.dumbbell;
    if (n.contains('barbell') || n.contains('ez bar') || n.contains('trap bar')) return _Kind.barbell;
    if (RegExp(r'smith|cable|lever|machine|sled|leg press|pulldown|pec deck').hasMatch(n)) return _Kind.machine;
    if (_bwWords.any(n.contains)) return _Kind.bodyweight;
    return _Kind.unknown;
  }

  /// Unknown equipment, but the user logs it (almost) without weight → treat as bodyweight.
  bool _looksBodyweight(String exId) {
    var zero = 0, all = 0;
    for (final s in _sessions.take(60)) {
      for (final ex in s.exercises.where((x) => x.exId == exId)) {
        for (final st in ex.sets.where((x) => x.done && !x.warmup)) {
          all++;
          if (st.weight <= 0) zero++;
        }
      }
    }
    return all > 0 && zero >= all * 0.8;
  }

  /// Minimal [Exercise] so [loadIncrement] / [suggestProgression] can be reused without the DB.
  Exercise _asExercise(GymExercise e, _Info info) {
    final dbEx = db?.byId(e.exId);
    if (dbEx != null) return dbEx;
    return Exercise(
      id: e.exId,
      name: e.name,
      bodyPart: info.lower ? 'upper legs' : 'chest',
      equipment: switch (info.kind) {
        _Kind.barbell => 'barbell',
        _Kind.dumbbell => 'dumbbell',
        _Kind.bodyweight => 'body weight',
        _ => 'cable',
      },
      target: '',
      secondary: const [],
      instructions: const [],
    );
  }

  // ───────────────────────────── Helpers ─────────────────────────────

  /// Bottom of the rep range = start target of double progression.
  int _bottom(GymExercise e) {
    if (e.repMin != null && e.repMin! > 0) return e.repMin!;
    final reps = e.workSets.map((s) => s.reps).where((r) => r > 0).toList();
    if (reps.isNotEmpty) return reps.reduce(min);
    return switch (profile.athlete.gymGoal) {
      'strength' => 5,
      'hypertrophy' => 10,
      _ => 8,
    };
  }

  int _top(GymExercise e, int bottom) => e.repMax ?? max(bottom, e.workSets.fold<int>(0, (a, s) => max(a, s.reps)));

  /// Load for [reps] at [rir] reps in reserve (inverse Epley).
  static double _loadFor(double oneRm, int reps, int rir) => oneRm / (1 + (reps + rir) / 30);

  /// Rounding grid: barbells 2.5 kg (1.25 kg plates – progression steps stay
  /// [loadIncrement]), dumbbells 2 kg, machines & cables 2.5 kg.
  static double _step(_Info info) => info.kind == _Kind.dumbbell ? 2 : 2.5;

  static double _floorStep(double kg, _Info info) {
    final st = _step(info);
    return (kg / st + 1e-6).floorToDouble() * st;
  }

  static double _roundStep(double kg, _Info info) {
    final st = _step(info);
    final r = (kg / st).round() * st;
    // Keep odd real-world weights (e.g. a 22.5 kg dumbbell) when they are close.
    return (r - kg).abs() <= 0.5 ? kg : r;
  }

  /// Minimum sensible load: empty barbell (20 kg; curls use fixed/EZ bars) or one step.
  static double _clampMin(double kg, _Info info) {
    if (info.kind == _Kind.barbell && !info.curl) return max(kg, 20);
    return max(kg, _step(info));
  }

  static double _median(List<double> v) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static double _weightedMedian(List<(double, double)> pts) {
    if (pts.isEmpty) return 0;
    final s = [...pts]..sort((a, b) => a.$1.compareTo(b.$1));
    final total = s.fold<double>(0, (a, p) => a + p.$2);
    var acc = 0.0;
    for (final p in s) {
      acc += p.$2;
      if (acc >= total / 2) return p.$1;
    }
    return s.last.$1;
  }
}
