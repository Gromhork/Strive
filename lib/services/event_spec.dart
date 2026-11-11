import '../core/event_distances.dart';
import '../core/sport.dart';

/// Training requirements of one race distance (docs/training-science.md §1.8 / §14): plan
/// length, taper, the long sessions the race needs and their caps, the weekly volume ceilings
/// and the brick length. One table for the plan generator, the feasibility check and the
/// goal model – the distances themselves live in [eventDistances].
///
/// Sources (see §14 of the spec): taper Bosquet 2007 / Mujika & Padilla 2003 / Wang 2023;
/// long-run and long-ride targets from amateur race plans (Daniels, Pfitzinger, Higdon,
/// Friel's Triathlete's Training Bible, Fitzgerald 80/20 Triathlon, Koop's Training Essentials
/// for Ultrarunning); single-run spikes ≤ +10 % (Frandsen 2025).
class EventSpec {
  const EventSpec(
    this.key, {
    required this.weeks,
    this.weeksBeginner,
    required this.taper,
    this.taperBeginner,
    this.beginnerOk = true,
    this.longRunKm,
    this.longRunMin,
    this.longRunGoalKm,
    this.longRunCapKm = 21,
    this.longRunCapMin = 150,
    this.runKm = const [],
    this.longRideMin,
    this.longRideCapMin = 180,
    this.rideH = const [],
    this.longSwimM,
    this.swimKm = const [],
    this.swimRepMax = 400,
    this.longDayMin = 120,
    this.secondLongMin,
    this.brick,
    this.shorter = const [],
    this.runWalkFinish = false,
    this.backToBack = false,
    this.minRuns = 0,
    this.minRunKm,
    this.minRides = 0,
    this.minSwims = 0,
  });

  final String key;

  /// Recommended plan length (weeks) for intermediate / advanced athletes and for beginners.
  final (int, int) weeks;
  final (int, int)? weeksBeginner;

  /// Taper weeks incl. race week (beginners may differ).
  final int taper;
  final int? taperBeginner;

  /// A first goal a beginner can train for (marathon, ultra and Ironman are not).
  final bool beginnerOk;

  /// Long run the race needs before the taper: [longRunKm], or [longRunMin] at the long-run pace
  /// when that is shorter (slow runners are on their feet long enough sooner).
  final double? longRunKm;
  final int? longRunMin;

  /// Long run a goal-directed build aims at by the peak when the athlete starts far below it
  /// (beginners, run/walk, low weekly km): 10 km 9 km, HM 16 km (Higdon / Galloway novice plans:
  /// 8–10 / 16–18 km) – else [longRunKm]. Slow runners: [longRunMin] at the long-run pace when
  /// that is shorter (time on feet).
  final double? longRunGoalKm;
  double? get goalLongKm => longRunGoalKm ?? longRunKm;

  /// Longest long run the plan builds to (km) and the most time one run may take (min).
  final double longRunCapKm;
  final int longRunCapMin;

  /// Weekly volume ceilings novice / intermediate / advanced (R5): run km, bike hours, swim km.
  final List<double> runKm, rideH, swimKm;

  /// Long ride the race needs before the taper (min) and the most one long ride may take.
  final int? longRideMin;
  final int longRideCapMin;

  /// Longest continuous swim the race needs before the taper (m), and the longest repeat of the
  /// endurance swims.
  final double? longSwimM;
  final double swimRepMax;

  /// Default time (min) on the long-session day / the second long day when the athlete set none.
  final int longDayMin;
  final int? secondLongMin;

  /// Run off the bike: first brick, last brick, last brick for advanced athletes (min).
  final (int, int, int)? brick;

  /// Shorter distances to offer when this one does not fit (largest first).
  final List<String> shorter;

  /// Can be finished with run/walk (short distances).
  final bool runWalkFinish;

  /// Back-to-back long runs on the weekend (ultra).
  final bool backToBack;

  /// Sessions a week the race needs at least (review 2026-11 H3: an Ironman on 3 days had one run and one
  /// swim a week, a marathon on 3 runs a 62 % long run): runs – unless the peak week reaches [minRunKm] run
  /// km (marathon: 4 runs or ~40 km) – rides and swims. 0: no requirement. Coaching practice: Higdon /
  /// Pfitzinger (marathon 4–5 runs, HM 3–4), Friel (Ironman 2–3 runs, 2–3 swims, 2–3 rides).
  final int minRuns, minRides, minSwims;
  final double? minRunKm;

  EventSport get sport => eventDistanceOf(key)?.sport ?? EventSport.run;
  bool get multisport => sport == EventSport.triathlon || sport == EventSport.duathlon;

  /// Taper weeks for an athlete of [level].
  int taperFor(String level) => level == 'beginner' ? (taperBeginner ?? taper) : taper;

  /// Recommended plan length for [level].
  (int, int) weeksFor(String level) => level == 'beginner' ? (weeksBeginner ?? weeks) : weeks;

  /// Whether a plan of [focus] trains for this event's disciplines.
  bool fits(TrainingFocus focus) => switch (sport) {
    EventSport.run => focus.sports.contains(Sport.run),
    EventSport.triathlon => focus == TrainingFocus.triathlon,
    EventSport.duathlon => focus == TrainingFocus.duathlon || focus == TrainingFocus.triathlon,
    EventSport.ride => focus.sports.contains(Sport.ride),
    EventSport.swim => focus.sports.contains(Sport.swim),
  };

  static EventSpec? of(String? key) => _specs[key];

  static const _specs = <String, EventSpec>{
    // ── Running ──
    '5k': EventSpec(
      '5k',
      weeks: (8, 12),
      weeksBeginner: (9, 10),
      taper: 1,
      longRunCapKm: 16,
      runKm: [15, 30, 50],
      runWalkFinish: true,
      minRuns: 2,
    ),
    '10k': EventSpec(
      '10k',
      weeks: (8, 12),
      taper: 1,
      longRunKm: 8,
      longRunGoalKm: 9,
      longRunCapKm: 18,
      runKm: [25, 40, 60],
      shorter: ['5k'],
      runWalkFinish: true,
      minRuns: 2,
    ),
    'hm': EventSpec(
      'hm',
      weeks: (12, 16),
      // Beginners 16–18 (review 2026-11 M1 / M3): from a ~5 km first long run at ≤ +10 % / +1 km a step, 3:1 cycles
      // and the 2-week taper, 12 weeks reached ~12 km – Higdon's 12-week novice plan starts from a 5–6 km long run
      // and steps +1.6 km.
      weeksBeginner: (16, 18),
      taper: 2,
      longRunKm: 15,
      // Slow runners: ~2 h time on feet is the HM long run (Galloway) – 15 km at 8:00 /km.
      longRunMin: 120,
      longRunGoalKm: 16,
      longRunCapKm: 21,
      runKm: [30, 50, 70],
      longDayMin: 150,
      shorter: ['10k', '5k'],
      // Galloway run/walk finishes are common at the HM (Hottenrott 2016: similar times, less fatigue).
      runWalkFinish: true,
      minRuns: 3,
      minRunKm: 30,
    ),
    'm': EventSpec(
      'm',
      weeks: (16, 18),
      weeksBeginner: (18, 20),
      taper: 3,
      taperBeginner: 2,
      beginnerOk: false,
      longRunKm: 28,
      // Slow runners: ~3 h on the feet is the marathon long run (Hanson / Galloway / Higdon: time-capped,
      // never > 3–3.5 h – longer single runs add injury risk and recovery cost faster than aerobic benefit).
      // At a long-run pace slower than ~6:25 /km the 3 h run is shorter than 28 km, and that is the target.
      longRunMin: 180,
      longRunCapKm: 35,
      longRunCapMin: 180,
      runKm: [45, 65, 90],
      longDayMin: 180,
      shorter: ['hm', '10k', '5k'],
      minRuns: 4,
      minRunKm: 45,
    ),
    // 50 km ultra: time on feet – long runs up to 3.5 h plus the back-to-back run the next day carry
    // the weekend's load (Koop 2016; Roche) – no single run beyond 3.5 h.
    'ultra50': EventSpec(
      'ultra50',
      weeks: (16, 24),
      taper: 3,
      beginnerOk: false,
      longRunKm: 30,
      longRunMin: 210,
      longRunCapKm: 38,
      longRunCapMin: 210,
      runKm: [55, 75, 100],
      longDayMin: 240,
      secondLongMin: 120,
      shorter: ['m', 'hm'],
      backToBack: true,
      minRuns: 4,
      minRunKm: 50,
    ),
    // ── Triathlon ──
    'sprint': EventSpec(
      'sprint',
      weeks: (8, 12),
      taper: 1,
      longRunCapKm: 12,
      runKm: [12, 20, 30],
      longRideMin: 60,
      longRideCapMin: 120,
      rideH: [2.5, 3.5, 4.5],
      swimKm: [3, 5, 7],
      longDayMin: 120,
      brick: (10, 20, 20),
      runWalkFinish: true,
    ),
    'olympic': EventSpec(
      'olympic',
      weeks: (12, 16),
      taper: 2,
      longRunKm: 10,
      longRunMin: 75,
      longRunCapKm: 16,
      runKm: [18, 28, 40],
      longRideMin: 90,
      longRideCapMin: 150,
      rideH: [3.5, 4.5, 6],
      swimKm: [4, 6, 8],
      swimRepMax: 800,
      longDayMin: 150,
      secondLongMin: 90,
      brick: (10, 30, 30),
      shorter: ['sprint'],
      runWalkFinish: true,
      minRuns: 2,
      minRides: 2,
      minSwims: 2,
    ),
    '70.3': EventSpec(
      '70.3',
      weeks: (16, 20),
      weeksBeginner: (20, 24),
      taper: 2,
      longRunKm: 16,
      longRunMin: 110,
      longRunCapKm: 21,
      runKm: [25, 35, 50],
      longRideMin: 180,
      longRideCapMin: 240,
      rideH: [5, 6.5, 8],
      swimKm: [6, 8, 10],
      swimRepMax: 800,
      longDayMin: 240,
      secondLongMin: 120,
      brick: (10, 45, 60),
      shorter: ['olympic', 'sprint'],
      minRuns: 2,
      minRides: 2,
      minSwims: 2,
    ),
    // Ironman: long ride 5–6 h, long run 28–32 km / ≤ 3 h (Friel; Fitzgerald), 3-week taper.
    'ironman': EventSpec(
      'ironman',
      weeks: (24, 30),
      taper: 3,
      beginnerOk: false,
      longRunKm: 26,
      longRunMin: 150,
      longRunCapKm: 32,
      // ≤ 3 h like the marathon long run – 28–32 km for most age-groupers (Friel; Fitzgerald).
      longRunCapMin: 180,
      runKm: [35, 45, 60],
      longRideMin: 300,
      longRideCapMin: 360,
      rideH: [8, 10, 13],
      swimKm: [7, 10, 12],
      swimRepMax: 1000,
      longDayMin: 360,
      secondLongMin: 180,
      brick: (10, 45, 60),
      shorter: ['70.3', 'olympic'],
      minRuns: 2,
      minRides: 2,
      minSwims: 2,
    ),
    // ── Duathlon (run – bike – run) ──
    'du_sprint': EventSpec(
      'du_sprint',
      weeks: (8, 12),
      taper: 1,
      longRunKm: 7,
      longRunMin: 50,
      longRunCapKm: 14,
      runKm: [20, 30, 45],
      longRideMin: 60,
      longRideCapMin: 120,
      rideH: [2.5, 3.5, 4.5],
      longDayMin: 120,
      secondLongMin: 90,
      brick: (10, 20, 20),
      runWalkFinish: true,
      minRuns: 2,
    ),
    'du_standard': EventSpec(
      'du_standard',
      weeks: (10, 14),
      taper: 2,
      longRunKm: 12,
      longRunMin: 80,
      longRunCapKm: 18,
      runKm: [25, 40, 55],
      longRideMin: 90,
      longRideCapMin: 150,
      rideH: [3.5, 4.5, 6],
      longDayMin: 150,
      secondLongMin: 90,
      brick: (10, 30, 30),
      shorter: ['du_sprint'],
      minRuns: 2,
      minRides: 2,
    ),
    // ── Cycling (Gran Fondo / century) ──
    'ride100': EventSpec(
      'ride100',
      weeks: (8, 12),
      weeksBeginner: (10, 14),
      taper: 1,
      longRideMin: 180,
      longRideCapMin: 270,
      rideH: [5, 7, 9],
      longDayMin: 240,
      minRides: 2,
    ),
    'ride160': EventSpec(
      'ride160',
      weeks: (12, 16),
      taper: 2,
      longRideMin: 240,
      longRideCapMin: 330,
      rideH: [6, 8, 11],
      longDayMin: 300,
      shorter: ['ride100'],
      minRides: 3,
    ),
    // ── Open-water swimming ──
    'swim1500': EventSpec(
      'swim1500',
      weeks: (8, 12),
      taper: 1,
      longSwimM: 1500,
      swimKm: [5, 8, 12],
      swimRepMax: 1500,
      longDayMin: 90,
      minSwims: 2,
    ),
    'swim3800': EventSpec(
      'swim3800',
      weeks: (12, 16),
      taper: 2,
      longSwimM: 3200,
      swimKm: [8, 12, 18],
      swimRepMax: 3200,
      longDayMin: 120,
      shorter: ['swim1500'],
      minSwims: 3,
    ),
    'swim5000': EventSpec(
      'swim5000',
      weeks: (12, 20),
      taper: 2,
      beginnerOk: false,
      longSwimM: 4000,
      swimKm: [10, 15, 22],
      swimRepMax: 4000,
      longDayMin: 150,
      shorter: ['swim3800', 'swim1500'],
      minSwims: 3,
    ),
  };
}
