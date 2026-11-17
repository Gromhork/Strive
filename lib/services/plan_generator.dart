import 'dart:math';
import 'dart:ui' show Locale;

import '../core/event_distances.dart';
import '../core/format.dart';
import '../core/sport.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'event_spec.dart';
import 'exercise_class.dart';
import 'fitness_state.dart';
import 'goal_model.dart';
import 'health_limits.dart';
import 'plan_exercises.dart';
import 'plan_text.dart';
import 'schedule_advisor.dart';
import 'target_suggestion.dart';
import 'zones.dart';

/// Evidence-based, rule-based plan generator (offline). Implements
/// docs/training-science.md:
///
/// * Periodisation base → build → peak → taper, taper 8–21 days with a 41–60 %
///   volume cut and intensity kept (Bosquet 2007, Wang 2023).
/// * Recovery weeks 2:1 / 3:1 / 4:1 by difficulty at 60–75 % volume.
/// * Running: ≥ 75–80 % easy sessions (Seiler; Silva Oliveira 2024), paces from
///   VDOT (Daniels), weekly growth 5/8/10 % (Buist 2008; Nielsen 2014), longest
///   run ≤ +10 % of the 30-day max (Frandsen 2025), long run ≤ 30 % of weekly km
///   and always the longest run of the week (easy runs ≤ 75 % of it, recovery weeks ≤ 60 %),
///   per-session caps for T/I/R volume.
/// * Cycling: Coggan zones from FTP, pyramidal/80-20 by weekly hours.
/// * Swimming: CSS zones, warm-up/drills/main/cool-down structure.
/// * Strength: chosen or recommended split (each muscle ≥ 2×/week, Schoenfeld 2016),
///   RIR wave 3→2→1 then deload (sets × 0.5), rep ranges by goal.
/// * Concurrent: no heavy legs the day before a key endurance session (C3; full-body
///   programs keep half their leg sets), max one key session per day, no back-to-back key
///   days for beginners (H1), one hard budget across sports (H2), no two key runs / rides
///   within 48 h (H3).
/// * Triathlon: bricks (run off the bike) from the build phase (§6.3); 70.3 ≥ 2 swims.
/// * Goal feasibility (§1.8): [feasibility] says when the event goal is not realistic –
///   incl. the target time (§1.12, [GoalModel]): race-pace work in the peak phase uses the
///   target pace only when it is realistic, all other paces the current VDOT.
/// * With an event the plan runs to race day (≤ 52 weeks; more than 20 weeks away: a base
///   "pre-plan" block before the race-specific 20 weeks). Coach review 3: long run ≤ 40 % of the
///   week before the last 12 weeks and varied on its plateau, quality sessions progress per
///   stage, pyramidal base, race-pace taper and race-day pacing, triathlon intensity rotation.
/// * Every session fits the time the athlete has on that day; recovery / taper weeks
///   also shrink that time, so time-limited sessions deload too.
/// * Race day is placed on the event date with a shake-out run the day before.
/// * Athlete traits: beginners keep ≥ 2 rest days (H7) and ≤ 4 runs; quick-setup
///   beginners without running experience start with run/walk (also returning runners
///   with BMI ≥ 30 or age ≥ 65, from 3 × 5 min); masters (≥ 50) get 3:1 cycles with deeper recovery weeks
///   (≥ 60: 2:1), slower growth and no consecutive key days.
/// * Health limitations ([HealthFlags], §9.1): knee / hip / ankle → less running impact
///   (slower growth, no strides / VO2max reps, one easy run → easy ride); shoulder → swim
///   technique instead of CSS sets, less swim volume; heart / blood pressure → intensity
///   capped at threshold; back / shoulder / heart → notes on the strength sessions.
class PlanGenerator {
  PlanGenerator(this.l, this.profile, this.templates, String Function() newId) : _id = newId;
  final AppLocalizations l;
  final UserProfile profile;
  final List<WorkoutTemplate> templates;
  final String Function() _id;

  AthleteData get a => profile.athlete;
  String get level => profile.level;
  bool get beginner => level == 'beginner';

  // ── athlete traits ──
  // Masters athletes recover more slowly from hard sessions and loading blocks
  // (spec §1.9: age ≥ 50 → 3:1, 2:1 when EASY; masters coaching commonly uses 2:1 or
  // 3:1 blocks and ≥ 48–72 h between hard days). Novice runners with BMI > 30 have a
  // higher injury risk (Nielsen 2013, n = 930) and more injuries when they start with
  // > 3 km in week 1 (Nielsen 2014) → run/walk start and slower run progression.
  int get _age => profile.age ?? 30;
  bool get _masters => _age >= 50;
  bool get _senior => _age >= 65;
  bool get _heavy => profile.bmi >= 30;
  late final HealthFlags hf = HealthFlags.of(profile);

  // ── difficulty parameters (§8) ──
  double get _growth {
    final g = switch (a.difficulty) {
      'easy' => 0.05,
      'challenging' => 0.10,
      _ => 0.08,
    };
    return _senior ? min(g, 0.05) : (_masters ? min(g, 0.08) : g);
  }

  /// Weekly growth of the run volume: impact load is what injures, so heavy novices
  /// and seniors grow at the EASY rate (H8: add volume via bike/swim first).
  double get _runGrowth => (beginner && _heavy) || _senior || hf.lowImpactRun ? min(_growth, 0.05) : _growth;

  int get _loadWeeks {
    final n = switch (a.difficulty) {
      'easy' => 2,
      'challenging' => level == 'advanced' ? 4 : 3,
      _ => 3,
    };
    // Masters (review 2026-11 L1): ≥ 60 2:1 cycles (Friel, "Fast After 50": 2:1 or 3:1 with more recovery),
    // 50–59 3:1 with deeper recovery weeks ([_recoveryFactor]); ≥ 65 always 2:1.
    return _age >= 60 ? 2 : (_masters ? min(n, 3) : n);
  }

  double get _recoveryFactor {
    final f = switch (a.difficulty) {
      'easy' => 0.60,
      'challenging' => 0.75,
      _ => 0.70,
    };
    return _masters ? min(f, 0.65) : f;
  }

  double get _longCap => a.difficulty == 'easy' || hf.lowImpactRun ? 1.05 : 1.10;

  late final PaceZones pz = PaceZones(Vdot.of(a) ?? Vdot.defaultFor(level));
  late final HrZones hz = HrZones(profile.estimatedMaxHr, a.restHr);
  late final int? ftp = a.ftp ?? (a.hasPowerMeter ? PowerZones.estimate(level, profile.weightKg) : null);
  // Without a test: the level default – a swim novice (cannot swim 400 m) ~2:30 / 100 m whatever
  // the level in other sports, so the session times fit.
  late final SwimZones sz = SwimZones(
    SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? (_swimNovice ? max(150, SwimZones.defaultFor(level)) : SwimZones.defaultFor(level)),
  );

  /// First day of the generated plan (weeks are counted from its Monday) – [planStartFor]: a start
  /// whose week has no training day left begins with the next week.
  DateTime _start0 = DateTime.now();
  DateTime get _start => _start0;
  set _start(DateTime d) => _start0 = planStartFor(profile, d);

  /// The plan's effective first day for a plan created on [start]: [start] itself, or the next Monday when
  /// none of the week's training days is still ahead (a Sunday start with Tue / Thu / Sat runs) – the
  /// leftover days of that week hold no session, so they are no plan week (review 2026-11 M2: a 12-week
  /// plan created on a Sunday had 11 training weeks).
  static DateTime planStartFor(UserProfile p, DateTime start) {
    final d = dayOnly(start);
    final days = scheduleOf(p).keys;
    if (days.isEmpty || days.any((x) => x >= d.weekday)) return d;
    return addDays(startOfWeek(d), 7);
  }

  /// Plan weeks from [start] to the race on [event] (incl. race week) – [GoalModel.weeksUntil] from the
  /// plan's effective start ([planStartFor]).
  static int planWeeksUntil(UserProfile p, DateTime event, DateTime start) => GoalModel.weeksUntil(event, planStartFor(p, start));

  /// Weeks of the race-specific block (longer plans start with a base pre-plan): 20, Ironman 30,
  /// ultra 24 ([EventSpec.weeks]).
  int get _specificWeeks => specificWeeksFor(profile);

  /// [_specificWeeks] of a plan for [p] – the setup's "first N weeks of base, then the X-week race plan"
  /// uses the generator's own numbers (audit T5: it said 20 for an Ironman, whose specific block is 30).
  static int specificWeeksFor(UserProfile p) => max(GoalModel.specificWeeks, _specOf(p)?.weeks.$2 ?? 0);

  /// Number of weeks until (and including) race week, if an event is set.
  int? get weeksToEvent {
    final d = a.eventDate;
    if (d == null) return null;
    final w = GoalModel.weeksUntil(d, _start);
    return w >= 2 && w <= GoalModel.maxEventWeeks ? w : null;
  }

  /// Couch-to-5K style run/walk progression (index into the run/walk table of
  /// [_runWalk]) the plan starts with, or null for continuous running.
  ///
  /// * The athlete said they cannot run 30 min (advanced setup).
  /// * Quick setup does not ask: beginners without running experience start at
  ///   week 1; returning runners with BMI ≥ 30 or age ≥ 65 start at 3 × 5 min, since
  ///   impact tolerance (bone, tendon) adapts slower than the cardiovascular system.
  static int? runWalkStartFor(UserProfile p) {
    final a = p.athlete;
    final beginner = p.level == 'beginner';
    if (!a.canRun30 && (beginner || a.raceTimes.isEmpty)) return 0;
    // Beginners with knee / hip / ankle problems: run/walk lets tendons and joints adapt.
    if (beginner && a.raceTimes.isEmpty && HealthFlags.of(p).lowImpactRun) return p.experience.contains(Sport.run) ? 4 : 0;
    if (!beginner || a.advanced || a.raceTimes.isNotEmpty) return null;
    if (!p.experience.contains(Sport.run)) return 0;
    if (p.bmi >= 30 || (p.age ?? 30) >= 65) return 4;
    return null;
  }

  /// Plan lengths (weeks) the setup / "new plan" sheet can offer for a plan without an event (general
  /// fitness, strength, hybrid): any of them works – loading blocks of 2–4 weeks with a recovery week
  /// (§1.9, repeating mesocycles), no taper. With an event the plan always runs to race day.
  static const supportedWeeks = [4, 6, 8, 10, 12, 16, 20, 24];

  /// Recommended length of a plan without an event for [p] (min, max, default weeks):
  /// beginners 8–12 (default 8: linear progression works for the first 8–12 weeks, §2.4; then
  /// re-assess), others 8–16 (default 12: three 3:1 mesocycles, Kenneally 2018). With an event:
  /// [EventSpec.weeksFor] (default its lower end).
  static ({int min, int max, int def}) recommendedWeeks(UserProfile p) {
    final s = _specOf(p);
    if (s != null) {
      final (lo, hi) = s.weeksFor(p.level);
      return (min: lo, max: hi, def: lo);
    }
    return p.level == 'beginner' ? (min: 8, max: 12, def: 8) : (min: 8, max: 16, def: 12);
  }

  /// Phases week by week (base / build / peak / recovery / taper) of a plan for [p] starting at
  /// [start] – [weeks] long without an event, to race day with one. For a preview in the UI.
  static List<String> phasesFor(UserProfile p, {required DateTime start, int? weeks}) {
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '').._start = start;
    return g._phases(g.weeksToEvent ?? weeks ?? p.athlete.planWeeks);
  }

  /// Requirements of the race distance ([EventSpec]); null without an event or when the plan's
  /// sports do not train for it (e.g. a cycling event on a running plan).
  late final EventSpec? spec = _specOf(profile);

  /// Sports of a race of [spec] (a triathlon's swim, ride and run …); empty without one.
  static List<Sport> raceSportsOf(EventSpec? spec) => switch (spec?.sport) {
    EventSport.run => const [Sport.run],
    EventSport.triathlon => const [Sport.swim, Sport.ride, Sport.run],
    EventSport.duathlon => const [Sport.run, Sport.ride],
    EventSport.ride => const [Sport.ride],
    EventSport.swim => const [Sport.swim],
    null => const <Sport>[],
  };

  /// Sports the plan's week holds (after a run/walk ladder – its fourth run day is back by race day).
  late final Set<Sport> _weekSports = {for (final v in scheduleOf(profile, afterRunWalk: true).values) ...v};

  /// The week holds at least one sport of the race: else no race, no shake-out and no race window are placed
  /// (audit UX-1: a hybrid week of gym days only got a shake-out run and a 10 km race after 0 runs).
  bool get _raceInWeek => raceSportsOf(spec).any(_weekSports.contains);

  static EventSpec? _specOf(UserProfile p) {
    final s = EventSpec.of(p.athlete.eventDistance);
    return s != null && s.fits(p.focus) ? s : null;
  }

  // Taper length (incl. race week) from the event table: marathon / ultra / Ironman 3 weeks,
  // HM / olympic / 70.3 / standard duathlon / 160 km / long swims 2, short races 1
  // (Bosquet 2007: 8–14 days best; Wang 2023: up to 21 days for long endurance events).
  int get _taperWeeks => spec?.taperFor(level) ?? 0;

  /// Run/walk stage still planned in race week (null: continuous running by then).
  int? _rwAtRace;

  /// A former run/walker with a distance goal: the long runs keep a 1 min walk break every 10 min
  /// (Galloway; Hottenrott 2016) and race day shows the run/walk rhythm.
  bool _walkBreaks = false;

  /// Long run a goal-directed build aims at ([EventSpec.goalLongKm], or [EventSpec.longRunMin] at
  /// the long-run pace when that is shorter – slow runners: time on feet). Null without one.
  double? get _goalLongKm {
    final km = spec?.goalLongKm;
    if (km == null) return null;
    final m = spec!.longRunMin;
    return m == null ? km : min(km, _r1(m * 60 / _longPace));
  }

  /// Smallest weekly step of a short long run ([_longStepCap]): 1 km (EASY / joint problems – [_longCap] 5 % –
  /// 0.5 km) – below 10 km that is more than +10 %, the step novice plans take (Higdon / Galloway).
  double get _goalStepKm => _longCap < 1.1 ? 0.5 : 1.0;

  /// Longest long run a loading week may plan after [longest] (km), in 0.5 km steps, at least +0.5 km:
  /// * beginners, EASY, joint problems, seniors / heavy novices ([_gentleGoal]): + max(10 % – 5 %, [_goalStepKm])
  ///   (Frandsen 2025: spikes > 10 % over the 30-day longest raise the injury risk – review 2026-11 M1);
  /// * intermediate / advanced runners build from an established base: + max(10 %, min(12 %, 2 km)) – Pfitzinger /
  ///   Higdon intermediate marathon plans add 1.5–3 km a step towards 30–34 km (PR #51 peaks).
  double _longStepCap(double longest) {
    final gentle = beginner || _gentleGoal || _longCap < 1.1;
    final step = gentle ? max(longest * (_longCap - 1), _goalStepKm) : max(longest * 0.10, min(longest * 0.12, 2.0));
    // (Experienced runners: to the nearest 0.5 km – rounding every step down lost ~0.3 km a week.)
    return max(longest + 0.5, gentle ? _floorHalf(longest + step) : _r1(longest + step));
  }

  /// EASY, joint problems, seniors (≥ 65) and heavy novices (BMI ≥ 30): the smaller goal step.
  bool get _gentleGoal => a.difficulty == 'easy' || hf.lowImpactRun || _senior || (beginner && _heavy);

  /// Run/walk stages a goal-directed build skips (10 × 1 min, 3 × 5 min): the NHS Couch-to-5K pace.
  static const _rwFastSkip = {1, 4};

  /// Target-time check of this plan ([GoalModel.check]); decides the race-pace work.
  TargetCheck? _target;

  // Context of the week being generated (set in [generate] before its sessions are built).
  /// Long run of this week: 0 long easy, 1 progression run, 2 shorter week.
  int _longVariant = 0;

  /// Progression stage 0 → 2 of the quality sessions over the loading weeks of the phase.
  int _stage = 0;

  /// HM / marathon peak: this week's long run carries the race-pace finish (marathon: every other
  /// peak week – the weeks between have an MP run and a shorter plain long run).
  bool _mpLongWeek = true;

  /// Quality runs this week, loading weeks so far, race week of the taper.
  int _qRuns = 0, _loadWeek = 0;

  /// Sports whose taper-week touch of intensity (strides / pick-ups) is planned already this week – a discipline that
  /// gets no quality session in a taper week (spacing, the week's hard budget) keeps some intensity (§1.7; review
  /// 2026-11 G2-V6): its first easy session carries strides or pick-ups.
  final _taperTouch = <Sport>{};

  /// A taper week before race week without a quality session of [sport] ([nQ]: this week's) whose touch of intensity
  /// is still to plan – true once (marks it planned).
  bool _taperTouchDue(Sport sport, String phase, int nQ) =>
      phase == 'taper' && !_taperLast && nQ == 0 && !hf.capIntensity && _taperTouch.add(sport);

  /// Loading weeks of continuous running since the run/walk ladder ended (null: no run/walk start).
  int? _postRunWalk;
  bool _taperLast = false;

  /// Week index → disciplines with a quality session (triathlon rotation, [_roles]).
  final _lastQuality = <Sport, int>{};

  /// Threshold rides planned so far in loading weeks (their structure progresses one step each, [_ride]).
  int _thrRides = 0;

  /// Longest long run / long ride the time on its day allows (km / min), see [feasibility].
  double _longRunLimitKm = 0;
  int _longRideLimitMin = 0;

  bool get _tri => spec?.sport == EventSport.triathlon;
  bool get _du => spec?.sport == EventSport.duathlon;

  /// Time a plan with bricks keeps free on the long-ride day (longest brick, duathlon + the run
  /// before the ride), so the long ride does not shrink when the bricks grow.
  int get _brickReserve {
    final b = spec?.brick;
    if (b == null) return 0;
    final most = level == 'advanced' ? b.$3 : b.$2;
    return most + (_du ? min(20, most) : 0);
  }

  /// The long run's day is next to the long ride's ([longSessionDays], the week wraps).
  bool get _imAdjacent {
    final d = longSessionDays(profile);
    final r = d[Sport.run], b = d[Sport.ride];
    if (r == null || b == null || r == b) return false;
    return min((r - b).abs(), 7 - (r - b).abs()) == 1;
  }

  /// Long-course triathlon (70.3 / Ironman): race-specific bike tempo, second swim, long bricks.
  bool get _longCourse => a.eventDistance == '70.3' || a.eventDistance == 'ironman';

  /// Longest run assumed without a stated longest run or weekly km (cold start): a runner of the
  /// intermediate level runs 10 km comfortably, an advanced one ~13 km – whatever the number of runs the
  /// plan has. Assuming a third of 3 × 7 km (7 km) made a hybrid intermediate's marathon build start at
  /// 7.5 km and peak at 21.5 km (user report 2026-11). 0 for beginners / non-runners, seniors and joint
  /// problems (their gentle build stays), and for goals
  /// without a long run of ≥ 15 km (HM, marathon, ultra, 70.3, Ironman need it; shorter plans keep
  /// their gentle start).
  double get _coldLongestKm {
    if ((spec?.longRunKm ?? 0) < 15 || _senior || hf.lowImpactRun) return 0;
    if (a.runWeeklyKm != null && a.runWeeklyKm! > 0) return 0;
    if (!profile.experience.contains(Sport.run) && a.raceTimes.isEmpty) return 0;
    // … and never more than ~75 / 85 min at the long-run pace (review 2026-11 M6: a slow runner's first long
    // run took 107 min) – time on the feet is what a slower runner's longest run was.
    return switch (level) {
      'advanced' => min(13.0, _floorHalf(85 * 60 / _longPace)),
      'intermediate' => min(10.0, _floorHalf(75 * 60 / _longPace)),
      _ => 0.0,
    };
  }

  /// Peak long run (km) a marathon / Ironman build aims at once the race's minimum ([EventSpec.longRunKm])
  /// is reached – established practice: marathon intermediate 30–32, advanced 32–35 km (2–3 runs ≥ 28 km in
  /// the last weeks before the taper; Pfitzinger, Higdon), Ironman 28–32 km (Friel) – never beyond the
  /// run's time cap ([_longRunMaxMin]) at the long-run pace (slower runners: time on feet). Null otherwise.
  double? get _peakLongKm {
    final want = switch (a.eventDistance) {
      'm' => level == 'advanced' ? 34.0 : (level == 'intermediate' ? 32.0 : 28.0),
      'ironman' => level == 'advanced' ? 30.0 : (level == 'intermediate' ? 28.0 : 26.0),
      _ => null,
    };
    if (want == null) return null;
    final byTime = _floorHalf(_longRunMaxMin * 60 / _longPace);
    return max(spec!.longRunKm ?? 0, min(min(want, spec!.longRunCapKm), byTime));
  }

  /// Longest a single long run may take (min), whatever the time on its day: the event's cap
  /// ([EventSpec.longRunCapMin]: marathon / Ironman ~3 h, ultra 3.5 h; else 150), beginners ≤ 150.
  int get _longRunMaxMin => beginner ? min(150, spec?.longRunCapMin ?? 150) : (spec?.longRunCapMin ?? 150);

  /// Minutes the long run gets on its day – the day's time next to its other sessions ([splitDayMinutes]) –
  /// for a day of [dayMin] minutes (default: [dayMinutesFor]). Null without a long-run day.
  int? _longRunDayMin({int? dayMin}) {
    final d = longSessionDays(profile)[Sport.run];
    if (d == null) return null;
    final n = max(1, scheduleOf(profile, afterRunWalk: true)[d]?.length ?? 1);
    return splitDayMinutes(dayMin ?? dayMinutesFor(profile, d), n, 1, true);
  }

  /// Minutes by which this athlete's long runs may go beyond the event's cap ([_longRunMaxMin]) when they
  /// opt in ([AthleteData.longRunExtend], [EventSpec.longRunExtraMin]) – 0 when there is nothing to offer:
  /// * the cap already covers the race's long run at the athlete's long-run pace (3 h ≥ ~90 % of 28 km: no need);
  /// * beginners (≤ 150 min), run/walk starters, seniors (≥ 65) and joint problems keep the cap – the extra
  ///   time on the feet is impact load they should not add;
  /// * the long-run day has no time for it: a day the athlete set themselves must hold at least 20 min more
  ///   than the cap (the extension then ends at that time); a day left to the app's default
  ///   ([longDayDefault]) grows with the option.
  int get longRunExtraEligible {
    final s = spec;
    if (s == null || s.longRunExtraMin <= 0 || s.longRunKm == null || s.sport != EventSport.run) return 0;
    if (beginner || _senior || hf.lowImpactRun || runWalkStartFor(profile) != null) return 0;
    final cap = _longRunMaxMin;
    if (_floorHalf(cap * 60 / _longPace) >= s.longRunKm! * 0.9) return 0;
    final d = longSessionDays(profile)[Sport.run];
    if (d == null) return 0;
    final set = a.dayMinutes[d];
    final avail = _longRunDayMin(dayMin: set ?? max(dayMinutesFor(profile, d), cap + s.longRunExtraMin)) ?? 0;
    final extra = min(s.longRunExtraMin, (avail - cap) ~/ 5 * 5);
    return extra >= longRunExtraFloor ? extra : 0;
  }

  /// Smallest extension worth offering (min): the walk breaks take 1 min in 11, so only from ~20 min on does
  /// an extended run hold more running than the plain run at the cap (review 2026-11: a 10 min extension gave
  /// two run/walk sessions with fewer running km than the capped run, while the note said the plan could not
  /// use it).
  static const longRunExtraFloor = 20;

  /// Smallest first step (min) towards the full extension ([_longExtraWeeks]: half of it) – below it the
  /// plan goes to the full extension in one run.
  static const longRunExtraStepFloor = 15;

  /// Distance (km) an extended long run must cover beyond the plain run at the cap to be planned at all
  /// ([_extensionWorth]) – the one criterion of generator and note ([LongRunCapNote.gains]).
  static const longRunExtraGainKm = 1.0;

  /// The long run of [longKm] on a day of [capMin] minutes, extended by this week's [_longExtraNow], covers
  /// at least [longRunExtraGainKm] more (walk breaks included) than the plain run at the cap would.
  bool _extensionWorth(double longKm, int capMin) {
    final fit = min(capMin, _longRunMaxMin + _longExtraNow) * 60 / _longPace * 10 / 11;
    final km = min(_r1(longKm), (fit * 10 + 1e-9).floor() / 10);
    final block = (600 / _longPace * 10).round() * 100.0;
    final breaks = max(0, (km * 1000 / block).ceil() - 1);
    final walkKm = breaks * timedRunStepM(_runStep('recovery', 'walk', sec: 60), pz.easySlow) / 1000;
    final plain = min(_r1(longKm), _floorHalf(min(capMin, _longRunMaxMin) * 60 / _longPace));
    return km + walkKm >= plain + longRunExtraGainKm;
  }

  /// [longRunExtraEligible] of an athlete who opted in, else 0.
  int get _longExtraMax => a.longRunExtend ? longRunExtraEligible : 0;

  /// Extra minutes of this week's long run beyond the cap (0: none), set per week in [generate].
  int _longExtraNow = 0;

  /// This week's long run is the shorter one after a run beyond the cap ([_longExtraWeeks]): plain easy.
  bool _longCutNow = false;

  /// Days of the long runs that went beyond the cap ([generate]): the runs after them stay easy.
  final _extendedRuns = <DateTime>[];

  /// Race day of the plan being generated ([generate]); an extended run is never closer than
  /// [longRunExtraLeadDays] to it.
  DateTime? _raceDayNow;

  /// The plan had weeks for an extended long run ([_longExtraWeeks] not empty) – when it still planned none,
  /// the week's volume, not the weeks left, was the limit ([LongRunCapNote.noGainByVolume]).
  bool _extraWeeksFound = false;

  /// An extended long run lies at least this many days before race day (Pfitzinger: the last long run
  /// ≥ 3 weeks out) – counted from the run's own day, not by week index: a Sunday long run before a Saturday
  /// race in "week −3" is only 20 days out (review 2026-11).
  static const longRunExtraLeadDays = 21;

  /// This week's long run of [longKm] does not fit the cap and may use the extension ([_longExtraNow]).
  /// ([capMin]: the minutes the run has on its day.)
  bool _extendsNow(double longKm, {int? capMin}) =>
      _longExtraNow > 0 &&
      _r1(longKm) * _longPace / 60 > _longRunMaxMin &&
      _extensionWorth(longKm, capMin ?? _longRunMaxMin + _longExtraNow);

  /// Weeks whose long run may go beyond the cap (week → extra minutes) and the lighter weeks around them (−1)
  /// for an athlete who opted in ([_longExtraMax]): only the last loading weeks of the build / peak whose
  /// long-run day lies at least [longRunExtraLeadDays] before race day – the last one gets the full extension,
  /// an earlier one half of it (when that half is worth a run of its own, [longRunExtraStepFloor]); two extended
  /// runs never follow each other directly (a recovery week or a shorter long run lies between), and a loading
  /// week right after the last one gets the shorter long run too (short plans: no full marathon-pace long run
  /// a week after the longest run). So at most two runs go beyond the cap (Galloway: the longest runs every
  /// 2–3 weeks; Pfitzinger: the last long run ≥ 3 weeks out).
  Map<int, int> _longExtraWeeks(List<String> phases, int total, int preWeeks, DateTime monday, DateTime? raceDay) {
    final extra = _longExtraMax;
    final d = longSessionDays(profile)[Sport.run];
    if (extra <= 0 || weeksToEvent == null || raceDay == null || d == null) return const {};
    bool loading(int w) => w < total && (phases[w] == 'build' || phases[w] == 'peak');
    final cand = [
      for (var w = preWeeks; w < total; w++)
        if (loading(w) && daysBetween(addDays(monday, w * 7 + d - 1), raceDay) >= longRunExtraLeadDays) w,
    ];
    if (cand.isEmpty) return const {};
    final out = <int, int>{cand.last: extra};
    final half = (extra / 2 / 5).round() * 5;
    if (cand.length >= 2 && half >= longRunExtraStepFloor) {
      final prev = cand[cand.length - 2];
      if (prev != cand.last - 1) {
        out[prev] = half;
      } else if (cand.length >= 3) {
        final before = cand[cand.length - 3];
        out[before] = half;
        if (before == prev - 1) out[prev] = -1;
      }
    }
    if (loading(cand.last + 1)) out[cand.last + 1] = -1;
    return out;
  }

  /// Long sessions whose own cap is the limit although the athlete set more time for their day (the plan
  /// settings say so next to the day times – a day's time is an upper limit, not a target): sport, the cap
  /// (min; the long run's with the extension the athlete switched on) and the weekday. Long rides only with an
  /// event ([EventSpec.longRideCapMin]).
  static List<({Sport sport, int capMin, int weekday})> longCapsBelowDayTime(UserProfile p) {
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '');
    final days = longSessionDays(p);
    final a = p.athlete;
    final out = <({Sport sport, int capMin, int weekday})>[];
    final rd = days[Sport.run];
    if (rd != null && runWalkStartFor(p) == null) {
      final cap = g._longRunMaxMin + g._longExtraMax;
      final forRun = g._longRunDayMin(dayMin: a.dayMinutes[rd] ?? a.sessionMinutes) ?? 0;
      if (forRun > cap) out.add((sport: Sport.run, capMin: cap, weekday: rd));
    }
    final bd = days[Sport.ride];
    final s = g.spec;
    if (bd != null && s?.longRideMin != null) {
      final n = max(1, scheduleOf(p)[bd]?.length ?? 1);
      final forRide = splitDayMinutes(a.dayMinutes[bd] ?? a.sessionMinutes, n, 1, true, brickDay: s!.brick != null) - g._brickReserve;
      if (forRide > s.longRideCapMin) out.add((sport: Sport.ride, capMin: s.longRideCapMin, weekday: bd));
    }
    return out;
  }

  /// Default time cap (min) of [p]'s long session of [sport] – what the plan never exceeds on its own: the long
  /// run's [_longRunMaxMin] (without the opt-in extension), the long ride's [EventSpec.longRideCapMin] of an
  /// event plan. Null without one. The recalibration's "a little more volume" stops there.
  static int? longSessionCapMin(UserProfile p, Sport sport) {
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '');
    return switch (sport) {
      Sport.run => g._longRunMaxMin,
      Sport.ride => g.spec?.longRideMin == null ? null : g.spec!.longRideCapMin,
      _ => null,
    };
  }

  /// The long-run cap extension [p] could switch on ([longRunExtraEligible]): the cap and the cap with the
  /// extension (min). Null when there is nothing to offer.
  static ({int capMin, int maxMin})? longRunExtension(UserProfile p) {
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '');
    final extra = g.longRunExtraEligible;
    return extra <= 0 ? null : (capMin: g._longRunMaxMin, maxMin: g._longRunMaxMin + extra);
  }

  /// Easy pace (s/km) long runs are planned with: the middle of the E range – the same
  /// pace the session duration is estimated with (beginners without paces: the slow end).
  int get _longPace => beginner && a.raceTimes.isEmpty ? pz.easySlow : (pz.easyFast + pz.easySlow) ~/ 2;

  /// [gymHistory]: the athlete's last gym workouts before [start] (day, program id – done sessions
  /// or the previous plan's workouts): the split's rotation continues from them instead of starting
  /// over (a plan set up again after Push starts with Pull, not with Push again), and so does an
  /// A/B alternation of assigned programs.
  List<PlannedWorkout> generate({required DateTime start, int? weeks, List<(DateTime, String)> gymHistory = const []}) {
    _gymPicks.clear();
    _start = start;
    start = _start;
    _target = GoalModel.check(profile, start: start);
    _rwAtRace = null;
    _longRunLimitKm = 0;
    _longRideLimitMin = 0;
    _lastQuality.clear();
    _thrRides = 0;
    _ftpTestLoad = a.ftp != null ? 0 : null;
    _extendedRuns.clear();
    _longExtraNow = 0;
    _longCutNow = false;
    final total = weeksToEvent ?? weeks ?? a.planWeeks;
    final schedule = _weekSchedule();
    // Couch-to-5K has no recovery weeks: while a pure runner is still on run/walk (one
    // stage per week, every session easy), recovery weeks are not planned.
    // A plan re-created mid-plan ([PlanCarry], review 2026-11 adapt-2): the run/walk ladder continues at the stage
    // the athlete reached instead of starting over at 8 × 1 min (past its end: continuous running).
    final carry = _carry;
    final rwStart = switch (runWalkStartFor(profile)) {
      final s? when carry?.runWalkStage != null => max(s, carry!.runWalkStage!),
      final s => s,
    };
    final scheduleAfterRw = rwStart != null ? scheduleOf(profile, afterRunWalk: true) : schedule;
    final endurance = schedule.values.expand((e) => e).where((s) => s != Sport.gym).toSet();
    final pureRun = endurance.length == 1 && endurance.first == Sport.run;
    final all = schedule.values.expand((e) => e);
    final runPerWeek = all.where((s) => s == Sport.run).length;
    final ridePerWeek = all.where((s) => s == Sport.ride).length;
    final swimPerWeek = all.where((s) => s == Sport.swim).length;
    // Goal-directed build (fix/plan-goal-progression): an event with a long-run target and an athlete
    // who starts far below it (run/walk, beginner, low km) – the long session grows towards the
    // target ([_goalLongKm]) as fast as is still safe, not only by +10 % of a tiny base.
    // Marathon / Ironman (not run/walk starters, not the gentle builds): the build aims at the level's peak
    // long run ([_peakLongKm], e.g. 32 km), so 2–3 runs ≥ 28 km fit before the taper – not one at 27.5.
    final goalKm =
        runPerWeek > 0
            ? (_goalLongKm == null || runWalkStartFor(profile) != null || _gentleGoal ? _goalLongKm : max(_goalLongKm!, _peakLongKm ?? 0))
            : null;
    final rwGoal = goalKm != null && rwStart != null;
    var ladder = [for (var s = rwStart ?? 0; s < _runWalkTable.length; s++) s];
    // Couch-to-5K advances a stage a week with 3 run/walks a week; a triathlete / duathlete with only 1–2 runs a week
    // (review 2026-11 tri-2: 12 → 20 → 30 min of running in weeks 1–3 with one run a week) takes two loading weeks a
    // stage, and the long run/walk grows ≤ +10 % / +5 min of running a week, ≤ 1.5 × the stage's running.
    final rwFew = runPerWeek <= 2 && spec?.multisport == true;
    final rwPerStage = rwFew ? 2 : 1;
    var phases = _phases(total, noRecoveryBefore: rwStart != null && pureRun ? ladder.length * rwPerStage : 0);
    final loadBeforeTaper = phases.takeWhile((p) => p != 'taper').where((p) => p != 'recovery').length;
    final longest0 =
        a.longestRunKm ?? max(3.0, _runStartKm(runPerWeek) * min(0.5, runPerWeek <= 1 ? 1.0 : (runPerWeek == 2 ? 0.55 : 0.32)));
    // Loading weeks the long run needs at +10 % a week (R1) – more than the plan has: behind. (From the
    // volume-based start, not [_coldLongestKm]: the weekly volume, not only R1, must grow towards the goal.)
    final goalBehind =
        goalKm != null && (rwStart != null || (longest0 < goalKm && log(goalKm / longest0) / log(_longCap) > loadBeforeTaper - 1));
    // Run/walk with a distance goal and too few weeks: the NHS Couch-to-5K pace (9 stages) instead of
    // the gentler 11-stage ladder – stages 10 × 1 min and 3 × 5 min repeat the run time of the stage
    // before them. Each stage still needs RPE ≤ 5 without pain (the progression check watches it).
    if (rwGoal && ladder.length * rwPerStage + ((goalKm - 4) / _goalStepKm).ceil() > loadBeforeTaper) {
      ladder = [
        for (final s in ladder)
          if (s == rwStart || !_rwFastSkip.contains(s)) s,
      ];
      phases = _phases(total, noRecoveryBefore: pureRun ? ladder.length * rwPerStage : 0);
    }
    final out = <PlannedWorkout>[];
    final monday = startOfWeek(start);
    // (Only a race the plan's sports train for – [spec]: a 10 km on a pure gym plan is no race day, audit UX-1 –
    // and the week holds: a hybrid week of gym days only has no run to race, [_raceInWeek].)
    final raceDay = weeksToEvent != null && spec != null && _raceInWeek ? dayOnly(a.eventDate!) : null;
    // Base pre-plan of a far-away event (> [GoalModel.specificWeeks]): general endurance – the
    // race-specific long runs belong to the specific block; before it the long run stays at
    // ~70 % of their cap (marathon ~24.5 km, HM ~15 km) and the volume at ≤ 85 % of the ceiling.
    final prePlanWeeks = weeksToEvent != null ? max(0, total - _specificWeeks) : 0;
    // Knee / hip / ankle: ~10 % less running (impact), the cross-training ride makes up for it.
    // Goal-directed: the week grows at the CHALLENGING rate (10 %, R2) and up to what a long run of
    // the goal needs at ≤ 50 % of the week – heavy novices, seniors and joint problems keep their
    // slower rate (impact, H8) and get the feasibility warning instead.
    final slowRun = _runGrowth < _growth;
    final runGrowth = goalBehind && !slowRun ? max(_runGrowth, 0.10) : _runGrowth;
    final runCeiling = goalBehind && !slowRun ? max(_runCeilingKm(runPerWeek), goalKm / 0.5) : _runCeilingKm(runPerWeek);
    // The volume reaches its ceiling by the peak, not in week 6 (review IMPORTANT 3: 70 → 102 km in
    // five weeks, then flat for ten): the weekly growth is at most what reaches the ceiling in the
    // loading weeks before the peak (≥ 2 %); goal-directed builds keep their rate.
    var runGrowthEff = runGrowth;
    final start0 = _runStartKm(runPerWeek);
    if (weeksToEvent != null && spec?.multisport != true && !goalBehind && prePlanWeeks == 0 && start0 > 0 && runCeiling > start0) {
      final until = phases.contains('peak') ? phases.indexOf('peak') : (phases.contains('taper') ? phases.indexOf('taper') : total);
      final nLoad = [for (var i = 1; i < until; i++) phases[i]].where((p) => p != 'recovery' && p != 'taper').length;
      if (nLoad > 0) runGrowthEff = min(runGrowth, max(0.02, pow(runCeiling / start0, 1 / nLoad) - 1.0));
    }
    // 70.3 / Ironman (intermediate / advanced, coordinator 2026-11): the run volume reaches its ceiling a few
    // build's last ~10 weeks – at 8 % a week a cold start (2 runs, ~14 km) sat far below it, the long
    // run (≤ 60 % of the week) reached 28 km only once. Up to the CHALLENGING rate (10 %, R2).
    if (weeksToEvent != null && _longCourse && !beginner && !slowRun && start0 > 0 && runCeiling > start0) {
      final until = max(1, (phases.contains('taper') ? phases.indexOf('taper') : total) - 10);
      final nLoad = [for (var i = 1; i < until; i++) phases[i]].where((p) => p != 'recovery').length;
      if (nLoad > 0) runGrowthEff = max(runGrowthEff, min(0.10, pow(runCeiling / start0, 1 / nLoad) - 1.0));
    }
    final runKm = [
      for (final v in _curve(total, phases, _runStartKm(runPerWeek), runCeiling, growth: runGrowthEff, preWeeks: prePlanWeeks))
        hf.lowImpactRun ? v * 0.9 : v,
    ];
    final rideH = _curve(total, phases, _rideStartH(ridePerWeek), _rideCeilingH(ridePerWeek), preWeeks: prePlanWeeks);
    final swimKm = _curve(total, phases, _swimStartKm(swimPerWeek), _swimCeilingKm(swimPerWeek), preWeeks: prePlanWeeks);
    // Long-run share: 1 run/week → the whole volume, 2 → ~55 %, otherwise 27–32 % (Daniels).
    double baseShare(double wk) => runPerWeek <= 1 ? 1.0 : (runPerWeek == 2 ? 0.55 : (wk < 40 ? 0.32 : 0.27));
    // Half / full marathon: the long run must approach race-specific length (HM ~16–21 km,
    // marathon ~30–35 km), which at amateur volumes needs 35–45 % of the weekly km
    // (Higdon / Pfitzinger / Hanson plans). R1 (+≤ 10 % per week) and the time cap of
    // [_run] still apply.
    // At low amateur volumes the race-specific long run (HM ~15 km, marathon ~28–32 km)
    // needs up to half of the weekly km (Higdon / Hanson novice plans: 45–60 %).
    // Continuous in the weekly km: above 50 (HM) / 70 km (marathon) the share falls from 40 / 42 %
    // towards 32 / 33 % only as fast as the long run stays at 20 / 29.4 km – a step in the share
    // made the long run drop by 3–6 km when the week grew past the threshold.
    // 70.3: the long run should reach ~16 km / 100 min (feasibility) with only 2–3 runs a week.
    // Outside the last 12 weeks the share stays ≤ 40 % (coach review 3): a 55 % long run in a flat
    // 53 km week for 30 weeks is monotonous and concentrates the load in one session.
    // Ultra: like the marathon, but the back-to-back run carries part of the weekend's time on feet.
    // Multisport / Ironman: one long run among 2–3 runs a week – up to 45 % (≥ 3 runs) or 65 %
    // (2 runs: long + a short quality run) when the race-specific long run needs it.
    final runTarget = spec?.longRunKm;
    // Peak long run the build aims at ([_peakLongKm]: marathon 32 / 34 km, Ironman 28 / 30 km by level,
    // never beyond the run's time cap at the long-run pace).
    final peakKm = _peakLongKm;
    // Runs actually planned: knee / hip / ankle swap one easy run for a ride when there are ≥ 3.
    final runsActual = hf.lowImpactRun && runPerWeek >= 3 ? runPerWeek - 1 : runPerWeek;
    double longShare(double wk, int w) {
      final s = switch (a.eventDistance) {
        // (Three runs: up to 60 % (marathon / ultra 55 %) – Galloway / Higdon novice plans, [threeRunLongShare].)
        'hm' when runPerWeek >= 3 => max(
          baseShare(wk),
          max(max(0.32, min(0.40, 20 / wk)), min(runsActual == 3 ? threeRunShareFor(a.eventDistance) : 0.5, 15 / wk)),
        ),
        'm' when runPerWeek >= 3 => max(baseShare(wk), max(max(0.33, min(0.42, peakKm! * 0.98 / wk)), min(0.55, peakKm / wk))),
        'ultra50' when runPerWeek >= 3 => max(baseShare(wk), max(max(0.33, min(0.42, 32 / wk)), min(0.5, 32 / wk))),
        // (Three runs of a long-course week – the third an easy double-day run, tri-8 – split the second run's volume:
        // the long run keeps about the two-run share, 50–60 %, else a 70.3 / Ironman build lost its long run.)
        _ when runTarget != null && runPerWeek >= 3 && spec!.sport != EventSport.run => max(
          runPerWeek == 3 && _longCourse ? 0.5 : baseShare(wk),
          min(runPerWeek == 3 && _longCourse ? 0.6 : 0.45, max(runTarget, peakKm ?? 0) / wk),
        ),
        // (Two runs: ≤ 60 % of the week's run km, bricks included – was 65 %, review 2026-11 H3.)
        _ when runTarget != null && runPerWeek == 2 && spec!.sport != EventSport.run => max(
          baseShare(wk),
          min(0.6, max(runTarget, peakKm ?? 0) / wk),
        ),
        _ => baseShare(wk),
      };
      // Goal-directed build: the goal's long run may take up to half of a low-volume week (3+ runs;
      // 2 runs 55 %) – Higdon / Galloway novice plans (§1.10a).
      // (Three runs 60 % – marathon / ultra 55 % – [threeRunShareFor]; two runs 55 %, review 2026-11 H3.)
      final g =
          goalBehind && wk > 0
              ? max(s, min(runsActual >= 4 ? 0.5 : (runsActual == 3 ? threeRunShareFor(a.eventDistance) : 0.55), goalKm / wk))
              : s;
      return runPerWeek >= 3 && w < total - 12 && !(_longCourse && runPerWeek == 3) ? min(g, max(baseShare(wk), 0.40)) : g;
    }

    final longMaxKm = spec?.longRunCapKm ?? double.infinity;
    // Cold start (R1): the longest recent run is assumed ≤ half the stated weekly km – a 25 km week with one
    // run in the plan is not a 25 km run.
    var longestRun = a.longestRunKm ?? max(_coldLongestKm, max(3.0, runKm.first * min(0.5, baseShare(runKm.first))));
    var tempoMin = beginner ? 12 : (level == 'advanced' ? 20 : 15);
    var intervalReps = beginner ? 4 : (level == 'advanced' ? 6 : 5);
    // Gym programs rotate continuously over the whole plan (week boundaries, recovery weeks): never the
    // same program twice in a row, no overlapping muscle groups on consecutive days, leg-heavy programs
    // not the day before a key endurance session where avoidable ([_GymQueue]). The rotation continues
    // from the athlete's last gym workouts ([gymHistory]).
    final gymQueue = _GymQueue(_rotationFor(a, schedule), _gymInfo);
    final history = [
      for (final (day, id) in [...gymHistory]..sort((x, y) => x.$1.compareTo(y.$1)))
        if (dayOnly(day).isBefore(dayOnly(start)))
          if (templates.any((t) => t.id == id && t.sport == Sport.gym)) (dayOnly(day), _historyRef(id)),
    ];
    gymQueue.seed(history);
    final abOffset = _abOffset(history, startOfWeek(start));
    final gymPerWeek = all.where((s) => s == Sport.gym).length;
    final strengthHint = (_masters || (profile.gender == 'f' && _age >= 45)) && gymPerWeek == 0 && endurance.isNotEmpty;
    // Run/walk: one stage per loading week (recovery weeks repeat the last stage), until
    // 30 min continuous running is reached; then continuous runs take over.
    // [rwPos] indexes the stage [ladder]; with a goal the long day carries a long run/walk that grows
    // ~10 min per loading week (Galloway: time on feet with walk breaks), its running ≤ 2 × the
    // regular session's ([rwLongSec] main set s, [rwRunMax] longest regular running s so far).
    int? rwPos = rwStart == null ? null : 0;
    var rwLongSec = carry?.runWalkLongSec ?? 0,
        rwRunMax = 0,
        rwLongRun = 0; // (rwLongRun: running s of the last loading week's long run/walk)
    var rwHeld = 0; // loading weeks on the current run/walk stage
    var rwWeekRun = 0, rwWeekN = 0; // running s / sessions of the last loading week's run/walks (multisport: ≤ +30 %)
    var rwLongKm = carry?.runWalkLongKm ?? 0.0; // running km of the longest long run/walk (R1 reference afterwards)
    var easyKm = 0.0; // easy-run cap of a former run/walker: the last 30 min run, +10 % a week
    _walkBreaks = rwGoal;
    var lastLongKm = 0.0; // actual long run of the last loading week
    var lastLoadRunKm = 0.0; // run km of the last loading week (recovery weeks stay ≤ 75 % of it)
    var prevLoadRunKm = 0.0; // … and of the loading week before it (brick weeks, tri-9)
    var lastEasyRunKm = 0.0; // longest easy run of the last loading week (multisport recovery weeks)
    var postRw = 0; // loading weeks of continuous running after the run/walk ladder
    var actualLongMax = 0.0; // longest long run actually planned in a loading week
    var rampKm = -1.0; // longest run R1 alone allows by this week ([_rampMaxKm])
    _rampMaxKm = 0;
    var plateauKm = 0.0; // longest planned long run so far (variation once it stops growing)
    var plateau = 0; // loading weeks on the plateau
    var loadWeeks = 0; // loading weeks so far (progression of quality sessions)
    // (A re-created plan continues the replaced plan's block – [_phases].)
    var block =
        carry == null || carry.recovery
            ? 0
            : min(carry.loadWeeks, _loadWeeks - 1); // loading weeks since the last recovery week (strength RIR wave)
    var bricks = 0; // brick sessions so far (run off the bike grows with each)
    final brickRun = (_tri || _du) && runPerWeek > 0 && spec?.brick != null;
    var lastLongRide = 0; // long ride (min) of the last loading week
    var longSwimLoad = 0.0; // long swim (m) of the last loading week (swimming plans)
    var swimPlateau = 0; // loading weeks with the long swim at its cap
    _longSwimVariant = 0;
    final swimOnly = swimPerWeek > 0 && runPerWeek == 0 && ridePerWeek == 0;
    _swimStage = 0;
    _swimsPerWeek = swimPerWeek;
    _swimTested = false;
    _longSwimM = 0;
    _contSwimM = 0;
    _swimLimitDay = null;
    _swimLimitMin = 0;
    _ladderNow = _swimLadder;
    // Swim novice with a race: the continuous swim keeps growing after the ladder (and the ladder
    // runs at 6 stages when 8 + test + the growth to the race's continuous swim do not fit).
    // Triathlon beginners who can swim 400 m (review r2 IMPORTANT 8): the same continuous-swim growth from
    // 300 m in week 1 (below what they can swim; +100–200 m a loading week).
    final swimBeginner = !swimOnly && !_swimNovice && beginner && _tri && swimPerWeek >= 2;
    // 70.3 / Ironman athletes who swim ≥ 2× a week (review 2026-11 H5: an Ironman's "2 × 800 m" unchanged for 15
    // weeks, longest swim 2.35 km): one swim a week is a continuous swim growing from 800 m (advanced 1 km) to
    // 1.5 km (70.3) / 2 km (Ironman) by the peak ([_swimTargetM]) – Friel: 1–2 km continuous for long course.
    final swimLong = !swimOnly && !_swimNovice && !beginner && _longCourse && swimPerWeek >= 2;
    final swimGoal = !swimOnly && (_swimNovice || swimBeginner || swimLong) && swimPerWeek > 0 ? _swimTargetM : null;
    if (swimBeginner && swimGoal != null) _contSwimM = min(swimGoal, 300.0);
    if (swimLong && swimGoal != null) _contSwimM = min(swimGoal, level == 'advanced' ? 1000.0 : 800.0);
    // Swimming plans for an open-water race: a swim novice's long swim after the test grows towards the race's
    // continuous swim ([EventSpec.longSwimM]) – the ladder is shortened like a triathlon novice's when it would
    // not leave the weeks for that (review 2026-11 H2: swim1500 novice never swam more than 300 m in one go).
    // (Beginners who can swim 400 m too – review 2026-11 RS3: their long swim started at 1.4 km.)
    final openGoal = swimOnly && (_swimNovice || beginner) ? spec?.longSwimM : null;
    // Loading weeks the continuous swim needs after the test: 500 m, then ≤ +200 m a week ([_contStep]).
    int contWeeks(double goal) => 1 + ((goal - 500) / 200).ceil();
    final ladderGoal = swimGoal ?? openGoal;
    if (_swimNovice && ladderGoal != null && _swimLadder.length + 1 + contWeeks(ladderGoal) > loadBeforeTaper) {
      _ladderNow = [
        for (var i = 0; i < _swimLadder.length; i++)
          if (i != 1 && i != 5) _swimLadder[i],
      ];
      // Still too long: 5 stages (also without 7 × 100 m).
      if (_ladderNow.length + 1 + contWeeks(ladderGoal) > loadBeforeTaper) {
        _ladderNow = [
          for (var i = 0; i < _swimLadder.length; i++)
            if (i != 1 && i != 3 && i != 5) _swimLadder[i],
        ];
      }
    }

    // Opt-in extension of the long run's time cap ([_longExtraWeeks]).
    _raceDayNow = raceDay;
    final extraAt = _longExtraWeeks(phases, total, prePlanWeeks, monday, raceDay);
    _extraWeeksFound = extraAt.values.any((v) => v > 0);
    var extendedPrev = false; // last week's long run went beyond the cap
    for (var w = 0; w < total; w++) {
      final phase = phases[w];
      // After the run/walk ladder a quick-setup beginner's 4th chosen day is planned again.
      final onLadder = rwPos != null && rwPos < ladder.length;
      _weekIdx = w;
      _longExtraNow = max(0, extraAt[w] ?? 0);
      final roles = _roles(onLadder ? schedule : scheduleAfterRw, phase, week: w);
      final weekStart0 = addDays(monday, w * 7);
      // An endurance race in ≤ 10 days (review 2026-11 M7): no heavy leg work any more.
      bool raceSoonOn(DateTime day) => raceDay != null && !day.isAfter(raceDay) && daysBetween(day, raceDay) <= 10;
      final gymRefs = _planGymWeek(
        gymQueue,
        [
          for (final e in (roles.entries.toList()..sort((x, y) => x.key.compareTo(y.key))))
            if (!addDays(weekStart0, e.key - 1).isBefore(dayOnly(start)))
              for (final r in e.value)
                if (r.sport == Sport.gym) (addDays(weekStart0, e.key - 1), r.role),
        ],
        w + abOffset,
        raceSoonOn,
      );
      // Marathon peak (review IMPORTANT 1): one marathon-pace element a week – the long run with an MP
      // finish, alternating with an MP run plus a shorter plain long run (Pfitzinger / Hansons) – so
      // the week has ≤ 2 quality sessions besides the long run and 29 km never three weeks in a row.
      final peakIdx = phases.take(w).where((p) => p == 'peak').length;
      final hasQ2 = roles.values.expand((x) => x).any((s) => s.sport == Sport.run && s.role == 'q2');
      // (Only once the long run is near its peak: while it still grows by ≤ 10 % a step (R1) a shorter week
      // costs a whole step – the last peak week then stayed ~2.5 km short.)
      final grown = lastLongKm >= min(goalKm ?? 0, longMaxKm) - 0.75;
      // (A week whose long run may go beyond the cap keeps its long run – plain, with walk breaks – and has
      // no second quality run.)
      _mpLongWeek = _finishMode || !grown || _longExtraNow > 0 || !(phase == 'peak' && a.eventDistance == 'm' && peakIdx.isOdd && hasQ2);
      if (phase == 'peak' && a.eventDistance == 'm' && _mpLongWeek) {
        for (final s in roles.values.expand((x) => x)) {
          if (s.sport == Sport.run && s.role == 'q2') s.role = 'easy';
        }
      }
      // Quality rides that really got a slot this week (spacing may leave fewer than allowed).
      final qRides = roles.values.expand((x) => x).where((r) => r.sport == Sport.ride && r.role.startsWith('q')).length;
      final weekStart = addDays(monday, w * 7);
      final rest = phase == 'recovery' || phase == 'taper';
      // Recovery / taper weeks shrink the time available as well: sessions that are
      // limited by the athlete's time (not by the volume curve) would otherwise stay
      // as long as in a loading week, and the deload or taper would not happen.
      final restF = rest ? _restFactor(phases, w) : 1.0;
      final runWalk = rwPos != null && rwPos < ladder.length;
      final rwStage = runWalk ? ladder[rest ? max(0, rwPos - 1) : rwPos] : 0;
      // Long run/walk of this week (main set s): +10 min per loading week, recovery / taper weeks
      // like the long run (80 % / taper factors).
      var rwLongTarget = 0;
      if (runWalk) {
        // R1 after run/walk: the first long runs build on the longest continuous block – with a
        // goal on the running km of the long run/walk (walk breaks stay in the long run).
        longestRun = max(max(3.0, _r1(_runWalkTable[rwStage].$1 / pz.easySlow)), rwLongKm);
        lastLongKm = longestRun;
        if (w == total - 1 && runPerWeek > 0) _rwAtRace = rwStage;
        if (rwGoal) {
          final (run, walk, reps) = _runWalkTable[rwStage];
          rwRunMax = max(rwRunMax, run * reps);
          final regular = reps * (run + walk) - walk;
          // +10 min a week ([_gentleGoal]: +5).
          final step = _gentleGoal ? 300 : 600;
          rwLongTarget = rest ? (rwLongSec * _longRestFactor(phases, w)).round() : (rwLongSec == 0 ? regular + step : rwLongSec + step);
        }
      } else if (rwStart != null && easyKm == 0) {
        easyKm = max(3.0, _r1(_runWalkTable.last.$1 / pz.easySlow));
        // The last long run/walk is the longest run so far (its running km, walk breaks kept).
        longestRun = max(longestRun, rwLongKm);
        lastLongKm = max(lastLongKm, rwLongKm);
      }
      // Brick (§6.3): a run off the bike after the long ride – from the build phase every
      // second loading week, weekly in the peak phase; not while still on run/walk.
      // Weekly from the build phase (§6.3: every 1–2 weeks, weekly in the peak): alternating weeks
      // made the run volume jump ±10–50 % from week to week.
      final brick = brickRun && !runWalk && (phase == 'peak' || phase == 'build');

      // Long run respects the 30-day max rule (R1) and 25–30 % of weekly km.
      final wk = runKm[w];
      // R1 (Frandsen 2025: single-run spikes > 10 % over the longest run of the last 30 days raise the
      // injury risk): a loading week's long run ≤ the longest so far + max(10 %, 1 km) – EASY / joint
      // problems max(5 %, 0.5 km) – in 0.5 km steps. [longestRun] is the longest before a recovery week, so
      // the long run after a cutback is ≤ 1.1 × the one before it too. Goal-directed builds no longer take
      // +1.5–2.5 km (+12–30 %) steps (review 2026-11 M1: HM beginner +30 / +23 / +19 %): a goal the weeks
      // cannot reach at this rate is a feasibility issue instead ([longRunRamp] / [tooShort]).
      var r1Cap = rest ? longestRun * 0.75 : _longStepCap(longestRun);
      // A single run a week (review 2026-11 H3: an Ironman's 27.5 km long run as the week's only run): the
      // run is ≤ [singleRunMaxMin] – impact tolerance needs frequency, not one ever longer run; the
      // feasibility check asks for more run days ([runFrequency]).
      if (runPerWeek <= 1) r1Cap = min(r1Cap, max(4.0, _floorHalf(singleRunMaxMin * 60 / _longPace)));
      // The long run R1 alone would allow by now ([_rampMaxKm]: the feasibility check tells a ramp-limited
      // long run from one the week's volume / other runs keep short).
      if (!rest && !runWalk && runPerWeek > 0) {
        rampKm = min(w < prePlanWeeks ? longMaxKm * 0.7 : longMaxKm, rampKm < 0 ? r1Cap : _longStepCap(rampKm));
        _rampMaxKm = max(_rampMaxKm, rampKm);
      }
      var longKm = min(min(wk * longShare(wk, w), w < prePlanWeeks ? longMaxKm * 0.7 : longMaxKm), r1Cap);
      // Within a loading block the long run never shrinks (the "longer than the other runs" bump of
      // one week made it jump 12.5 → 11 → 12 km); the plateau's shorter week is applied below.
      final prevLoading = w > 0 && phases[w - 1] != 'recovery' && phases[w - 1] != 'taper';
      if (!rest && !runWalk && prevLoading && lastLongKm > 0) longKm = max(longKm, min(lastLongKm, longMaxKm));
      // Recovery week ~80 % of the last long run; taper: the last real long run is the peak week
      // (2–3 weeks out), then ~75 / 60 % (3-week taper) or ~65 % (2 weeks) and a short one in race
      // week (Pfitzinger; Mujika & Padilla 2003: volume down, intensity kept).
      final longF = _longRestFactor(phases, w);
      if (rest && lastLongKm > 0) longKm = min(longKm, lastLongKm * longF);
      // R1 reference: running plans update it from the long run actually planned, after the whole-week
      // checks; multisport plans (no whole-week checks) keep the planned value.
      // Long ride (min): its share of the bike hours ([_longRideMin]); recovery / taper weeks stay
      // below the last loading week by the same factors as the long run.
      var longRide = _longRideMin(rideH[w], ridePerWeek, rest: rest);
      if (rest && lastLongRide > 0) longRide = min(longRide, max(45, (lastLongRide * longF / 15).round() * 15));
      // Goal-directed long ride: when the bike hours grow too slowly for the race's long ride, at
      // least +10 min per loading week towards it (Friel: +10–15 min a week; cycling carries little
      // impact load, H8). The day's time still caps it.
      // Never beyond what the long-ride day holds with the brick run (a raised ride would drop again
      // in the brick weeks).
      final rideDay = longSessionDays(profile)[Sport.ride];
      // Cycling events: up to ~20 % beyond the race's long ride (≤ its cap) – a 160 km plan sat at 240 min
      // for 4 weeks once the target was reached (review 2026-11, IMPORTANT 4).
      final rideEv = spec?.sport == EventSport.ride;
      final rideGoal =
          spec?.longRideMin == null || rideDay == null
              ? null
              : min(
                rideEv ? min(spec!.longRideCapMin, (spec!.longRideMin! * 1.2 / 5).round() * 5) : spec!.longRideMin!,
                dayMinutesFor(profile, rideDay) - (brickRun ? _brickReserve : 0),
              );
      // The step is what the weeks left need, 10–20 min (review 2026-11 tri-10: an Ironman's long ride grew +10 min a
      // week from 80 min and peaked at 3:55 h with a 6 h Saturday – cycling is where long-course volume goes first, H8).
      var goalStep = 0;
      if (!rest && rideGoal != null && lastLongRide > 0 && lastLongRide < rideGoal) {
        final left = phases.sublist(w).takeWhile((p) => p != 'taper').where((p) => p != 'recovery').length;
        final need = (rideGoal - lastLongRide) / max(1, left);
        if (need > longRide - lastLongRide) {
          goalStep = ((need / 5).ceil() * 5).clamp(10, 20);
          longRide = min(rideGoal, max(longRide, lastLongRide + goalStep));
        }
      }
      // The first long ride (review 2026-11 FUZZ-2: the longest recent ride was asked and never used – a 40 km rider's
      // first long ride was 81 km): ≤ 110 % of the longest recent ride at an easy pace; a race's build starts from it.
      // Without it a long-ride race (≥ 3 h) starts at 90 min (advanced 2 h, beginners 1 h).
      if (!rest && lastLongRide == 0 && ridePerWeek > 0) {
        final km = a.longestRideKm;
        if (km != null && km > 0) {
          final longestMin = km / _rideKmh('Z2') * 60;
          longRide = min(longRide, max(45, (longestMin * 1.1 / 5).floor() * 5));
          if (rideGoal != null) longRide = max(longRide, min(rideGoal, (longestMin / 5).floor() * 5));
        } else if (rideGoal != null && (spec!.longRideMin ?? 0) >= 180) {
          longRide = max(longRide, min(rideGoal, beginner ? 60 : (level == 'advanced' ? 120 : 90)));
        }
      }
      // Never more than +10 % (≥ 15 min, a goal's step) on last loading week's (FUZZ-2: 480 min from week 1 with
      // 17.5 bike hours stated).
      if (!rest && lastLongRide > 0) longRide = min(longRide, lastLongRide + max(max(15, goalStep), (lastLongRide * 0.1 / 5).round() * 5));
      // Once raised, the long ride does not fall back below last loading week's.
      if (!rest && rideGoal != null && lastLongRide > 0) longRide = max(longRide, min(lastLongRide, rideGoal));
      // Ironman "big weekends" (review r2 IMPORTANT 9: a 300'+ ride with brick, then a 30 km long run the
      // next day): with the long run next to the long-ride day, brick weeks alternate – a ride weekend
      // (full long ride + brick, long run ≤ 75 % / 2 h) and a run weekend (long ride ≤ 3 h with a short
      // brick, the full long run). Friel / Fitzgerald: the longest run and the longest ride are not
      // stacked on consecutive days.
      final imAdj = a.eventDistance == 'ironman' && brick && !rest && !runWalk && longRide >= 240 && _imAdjacent;
      // Counted back from the taper, so the last loading week before it is a run weekend (the longest run
      // comes 2–3 weeks before the race, §1.7).
      final imLeft = phases.sublist(w).takeWhile((p) => p != 'taper').where((p) => p == 'build' || p == 'peak').length;
      final imRideWeek = imAdj && imLeft.isEven, imRunWeek = imAdj && imLeft.isOdd;
      if (imRideWeek) longKm = min(longKm, max(8.0, _r1(min(longKm * 0.75, 120 * 60 / _longPace))));
      if (!rest && !runWalk && spec?.multisport == true) longestRun = max(longestRun, longKm);
      // Ironman run weekend: the long ride ≤ 3 h ([imRunWeek]).
      if (imRunWeek) longRide = min(longRide, 180);
      // Swim progression: novices climb the continuous-swim ladder one stage per loading week.
      // Long swim of a swimming plan: +10 % (≥ 100 m) per loading week towards the race's
      // continuous distance ([EventSpec.longSwimM]; without an event 1.5 / 2.5 / 3 km by level).
      if (swimOnly && (!_swimNovice || _swimTested)) {
        final capM = spec?.longSwimM ?? (beginner ? 1500.0 : (level == 'advanced' ? 3000.0 : 2500.0));
        // Plateau rotation of the long swim ([_longSwim]): race-pace finish → over-distance → plain.
        if (!rest && longSwimLoad >= capM) swimPlateau++;
        _longSwimVariant = !rest && longSwimLoad >= capM ? swimPlateau % 3 : 0;
        if (longSwimLoad == 0) {
          // At least ~90 % of an average session: the long swim is the longest of the week.
          final level0 = _swimNovice ? 400.0 : (level == 'advanced' ? 1200.0 : (level == 'intermediate' ? 800.0 : 500.0));
          // (Former swim novices start at 400 m – what they just learned to swim in one go; beginners at what they can
          // swim: 400 m, ~500 m with a test – §4.5, review 2026-11 RS3: 1.4 km in week 1, 3.5 × their longest swim.)
          final tested = SwimZones.fromTests(a.swim400Sec, a.swim200Sec) != null;
          longSwimLoad =
              _swimNovice
                  ? level0
                  : (beginner
                      ? min(capM, tested ? 500.0 : 400.0)
                      : min(capM, max(level0, (swimKm[w] * 1000 / swimPerWeek * 0.9 / 100).round() * 100.0)));
        } else if (!rest) {
          // +10–15 % a week (≥ 100 m): swimming carries little impact load (H8). A former swim novice with a
          // race (review 2026-11 H2): up to +200 m when +100 m cannot reach the race's continuous swim in the
          // loading weeks left – like the triathlon novice's continuous swim.
          final left = phases.sublist(w).takeWhile((p) => p != 'taper').where((p) => p != 'recovery').length;
          // (Past 1.5 km the step may be ~12 % – +200 m a week took a beginner 14 loading weeks to 3 km, G2-V7.)
          final stepMax = max(200.0, (longSwimLoad * 0.12 / 100).round() * 100.0);
          final need = openGoal != null && left > 0 ? (((capM - longSwimLoad) / left / 100).ceil() * 100.0).clamp(100.0, stepMax) : 100.0;
          longSwimLoad = min(capM, max(longSwimLoad + need, (longSwimLoad * 1.12 / 100).round() * 100.0));
        }
        _longSwimM = rest ? max(300.0, (longSwimLoad * longF / 100).round() * 100.0) : longSwimLoad;
      }
      // Long-run variation (coach review 3): once the long run stops growing (≥ 12 km, base /
      // build), the weeks rotate long easy → progression run (build; last part at M effort) →
      // a shorter week (~80 %) instead of repeating the same distance (Pfitzinger / Hansons
      // alternate long, medium-long and marathon-pace long runs). Peak: race-pace long runs.
      _longVariant = 0;
      // Multisport races (no race-pace long runs) rotate in the peak too: a 30 km long run every
      // week for 12 weeks next to 5 h rides is not how long-course athletes train (Friel).
      final rotatePeak = phase == 'peak' && spec != null && spec!.sport != EventSport.run;
      // The shorter week never right before a recovery / taper week (two light weeks in a row).
      final nextRest = w + 1 < total && (phases[w + 1] == 'recovery' || phases[w + 1] == 'taper');
      if (!rest && !runWalk && !imAdj && (phase != 'peak' || rotatePeak) && longKm >= 12 && plateauKm > 0 && longKm <= plateauKm + 0.25) {
        plateau++;
        if (plateau % 3 == 2 && !nextRest) {
          _longVariant = 2;
          longKm = _r1(longKm * 0.8);
        } else if (plateau % 3 == 1 && phase == 'build' && !beginner && !hf.noHardRunning) {
          _longVariant = 1;
        }
      }
      // Marathon peak, MP-run week: a shorter plain long run (~80 %).
      if (!_mpLongWeek && !rest && !runWalk) {
        _longVariant = 2;
        longKm = _r1(longKm * 0.8);
      }
      // After a long run beyond the cap ([_longExtraWeeks]): a shorter long run (~80 % of the cap) before the
      // next one – the recovery the extra time on the feet costs.
      _longCutNow = extraAt[w] == -1 && extendedPrev && !rest && !runWalk;
      if (_longCutNow) {
        _longVariant = 2;
        longKm = _r1(min(longKm, _longRunMaxMin * 60 / _longPace) * 0.8);
      }
      // Ironman ride weekend: its long run is the shorter one ([imRideWeek]).
      if (imRideWeek) _longVariant = 2;
      if (!rest && !runWalk && _longVariant != 2) plateauKm = max(plateauKm, longKm);
      // Quality progression (B3): stage 0 → 1 → 2 over the loading weeks of the current phase.
      final phaseWeeks = phases.where((p) => p == phase).length;
      final phaseIdx = phases.take(w).where((p) => p == phase).length;
      _stage = phaseWeeks <= 1 ? 1 : min(2, phaseIdx * 3 ~/ phaseWeeks);
      _taperLast = phase == 'taper' && w == total - 1;
      _contSwimDone = false;
      _taperTouch.clear();
      _qRuns = roles.values.expand((x) => x).where((r) => r.sport == Sport.run && r.role.startsWith('q')).length;
      _loadWeek = loadWeeks;
      _postRunWalk = rwStart == null ? null : postRw;

      // Pass 1: everything except easy runs. Pass 2: easy runs share the remaining
      // weekly volume but stay clearly shorter than the long run.
      final week = <PlannedWorkout>[];
      final easyRuns = <(DateTime, int)>[];
      var skippedRuns = 0; // run slots before the start day (plan starts mid-week)
      (DateTime, int)? longCtx;
      final qualityCtx = <(int, DateTime, String, int)>[]; // index in week, day, role, cap
      for (final entry in roles.entries) {
        final day = addDays(weekStart, entry.key - 1);
        if (day.isBefore(dayOnly(start))) {
          skippedRuns += entry.value.where((r) => r.sport == Sport.run).length;
          continue;
        }
        for (final r in entry.value) {
          final full = _capMinutes(entry.key, entry.value, r);
          final cap = r.sport == Sport.gym ? full : max(20, (full * restF).round());
          // A run on the brick day (a day plan "Sat: ride + run"): the brick is that day's run – not a brick plus a
          // separate run (review 2026-11 FUZZ-8: run before the bike + long ride + brick + an easy run on one day).
          final brickDay = brick && entry.value.any((x) => x.sport == Sport.ride && x.role == 'long');
          if (r.sport == Sport.run && r.role != 'long' && brickDay) continue;
          if (r.sport == Sport.run) {
            if (runWalk) {
              if (rwGoal && r.role == 'long') {
                final lrw = _longRunWalk(
                  day,
                  rwStage,
                  phase,
                  rwLongTarget,
                  cap,
                  (rwRunMax * (rwFew ? (_gentleGoal ? 1.25 : 1.5) : (_gentleGoal ? 1.5 : 2))).round(),
                  rest ? 0 : rwLongSec,
                  single: rwFew,
                  onlyRun: runPerWeek == 1,
                  prevRunSec: !rwFew || rwLongRun == 0 || rest ? null : rwLongRun,
                );
                if (!rest) {
                  rwLongSec = lrw.$2;
                  rwLongRun = lrw.$1.steps.where((x) => x.isWork).fold(0, (t, x) => t + (x.durationSec ?? 0));
                  rwLongKm = max(rwLongKm, runningKm(lrw.$1));
                }
                week.add(lrw.$1);
              } else {
                week.add(_runWalk(day, rwStage, phase));
              }
              continue;
            }
            if (r.role == 'easy') {
              easyRuns.add((day, cap));
              continue;
            }
            if (r.role == 'long') longCtx = (day, cap);
            if (r.role.startsWith('q')) qualityCtx.add((week.length, day, r.role, cap));
          }
          if (r.sport == Sport.ride && r.role == 'long' && brick) {
            // Run off the bike ([EventSpec.brick]): sprint 15 → 20 min, olympic 15 → 30, 70.3 /
            // Ironman 15 → 45 (advanced 60), duathlon 10 → 20 / 15 → 30; at most ~60 % of this
            // week's long run; the ride keeps the rest of the day.
            final (b0, bMax, bAdv) = spec!.brick!;
            // ≤ 60 % of the long run and ≤ ~25 % of the week's run time (it counts as run volume).
            final byLong = max(10, (min(longKm * 0.6, wk * 0.25) * _longPace / 60 / 5).floor() * 5);
            // The runs share the reserved part of the day (≤ a third): the long ride keeps the same
            // time in every week ([_brickReserve]) and stays the main part of a short day.
            final reserve = max(10, min(_brickReserve, cap ~/ 3));
            // Duathlon peak: run – bike – run, the race's order (a short run before the ride too,
            // 10 → 20 min over the peak).
            // (Whole 5 min: a "13 min" run was planned as 15.)
            final pre = _du && phase == 'peak' ? max(5, min(10 + 5 * _stage, reserve ~/ 3 ~/ 5 * 5)) : 0;
            var bMin = min(min(min(level == 'advanced' ? bAdv : bMax, b0 + bricks * 5), byLong), max(10, reserve - pre));
            // Long run the day before / after (review 2026-11 C8: 300 min ride + 55 min brick, then a 30 km
            // long run): the brick stays ≤ 30 min – longer only in the week with the shorter long run.
            final runLongDay = longSessionDays(profile)[Sport.run];
            final nextToLong =
                runLongDay != null &&
                runLongDay != entry.key &&
                min((runLongDay - entry.key).abs(), 7 - (runLongDay - entry.key).abs()) == 1;
            if (nextToLong && _longVariant != 2) bMin = min(bMin, 30);
            // Ironman run weekend: a short transition run only.
            if (imRunWeek) bMin = min(bMin, 20);
            final int rideCap = max(45, cap - max<int>(bMin + pre, reserve));
            if (pre > 0) week.add(_brickRun(day, phase, pre, first: true));
            week.add(_ride(day, r.role, phase, rideH[w], ridePerWeek, loadWeeks, rideCap, qRides, longMin: longRide));
            week.add(_brickRun(day, phase, bMin));
            if (!rest) _longRideLimitMin = max(_longRideLimitMin, rideCap);
            bricks++;
            continue;
          }
          if (r.sport == Sport.run && r.role == 'b2b') {
            // Ultra back-to-back (Koop 2016): the day after the long run a medium-long easy run
            // (~55 % of it, 60 % in the peak) – time on tired legs without one 50 km training run.
            // (After a long run beyond the cap: a short easy run only – ≤ 60 min, ~35 % of it.)
            final ext = _extendsNow(longKm, capMin: _longRunDayMin());
            week.add(_backToBack(day, phase, longKm * (ext ? 0.35 : (phase == 'peak' ? 0.6 : 0.55)), ext ? min(cap, 60) : cap));
            continue;
          }
          // A plan with bricks keeps the brick's time free on the long-ride day in every week, so
          // the long ride does not shrink when the bricks start (last long ride = the longest).
          final keep = brickRun && r.sport == Sport.ride && r.role == 'long' ? min(_brickReserve, cap ~/ 3) : 0;
          // R3 (§1.5): intensity in, volume held. Multisport with ≤ 3 runs has no easy runs to
          // absorb a quality run – it gets the week's run km left after the long run and the brick,
          // so swapping an easy run for a tempo run does not add 30 % run volume.
          var runCap = cap;
          if (r.sport == Sport.run && r.role.startsWith('q') && spec?.multisport == true && runPerWeek <= 3) {
            final b = spec!.brick;
            // (The duathlon peak's run before the ride counts too – review 2026-11 tri-9: +36 % run km in the peak.)
            final preMin = _du && phase == 'peak' && brick ? 10 + 5 * _stage : 0;
            final brickMin = (brick && b != null ? min(level == 'advanced' ? b.$3 : b.$2, b.$1 + bricks * 5) : 0) + preMin;
            // … and no more than the easy run it alternates with (~half the long run, see pass 2).
            final brickKm = brickMin * 60 / _longPace;
            final leftKm = min(wk - longKm - brickKm - (runPerWeek - 2) * 3, longKm * 0.5 + 1 - brickKm);
            runCap = min(cap, max(30, (leftKm * pz.easySlow / 60).round()));
          }
          final raceSoon = raceSoonOn(day);
          week.add(switch (r.sport) {
            Sport.run => _run(day, r.role, phase, wk, longKm, tempoMin, intervalReps, w, runCap),
            Sport.ride => _ride(
              day,
              r.role,
              phase,
              rideH[w],
              ridePerWeek,
              loadWeeks,
              keep > 0 ? max(45, cap - keep) : cap,
              qRides,
              longMin: longRide,
            ),
            Sport.swim => _swim(day, r.role, phase, swimKm[w], swimPerWeek, w, cap),
            // Beginners: no planned strength deload in the first ~10 weeks (§2.7) – the
            // session keeps the loading phase it follows.
            Sport.gym => _gym(
              day,
              gymRefs[day]!,
              schedule,
              phase == 'recovery' && beginner && w < 10 ? _lastLoadPhase(phases, w) : phase,
              block,
              r.role,
              cap,
              week: w,
              raceSoon: raceSoon,
              deloadAhead:
                  [
                    for (var j = w + 1; j < total; j++)
                      if (phases[j] == 'taper' || (phases[j] == 'recovery' && !(beginner && j < 10))) j,
                  ].isNotEmpty,
            ),
          });
        }
      }
      // The long run must stay the longest run of the week: a tempo / interval
      // session with warm-up and cool-down can otherwise match a short long run.
      if (longCtx != null) {
        final li = week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'long');
        final others = week.where((p) => p.sport == Sport.run && p.intensity != 'long').fold<double>(0, (x, p) => max(x, runningKm(p)));
        if (li >= 0 && others > 0 && runningKm(week[li]) < others * 1.15) {
          // Never beyond R1 – if that is not enough, the quality run is shortened below.
          final target = min(_r1(others * 1.2), max(longKm, r1Cap));
          final longer = _run(longCtx.$1, 'long', phase, wk, max(longKm, target), tempoMin, intervalReps, w, longCtx.$2);
          if (runningKm(longer) > runningKm(week[li])) week[li] = longer;
        }
        // A long run limited by R1 or by the time that day cannot grow: shorten the quality run
        // (fewer repeats, shorter warm-up) instead.
        final longDist = li >= 0 ? runningKm(week[li]) : 0.0;
        for (final (i, day, role, cap) in qualityCtx) {
          for (var t = 0; t < 6 && runningKm(week[i]) * 1.15 > longDist && longDist > 0; t++) {
            final d = runningKm(week[i]);
            // Scale the session's own time (not the day's, which may be far longer than the run).
            final own = min(cap, week[i].durationMin);
            final shorter = _run(day, role, phase, wk, longKm, tempoMin, intervalReps, w, max(15, (own * longDist / (d * 1.2)).floor()));
            if (runningKm(shorter) >= d) break;
            week[i] = shorter;
          }
        }
      }
      // Marathon build / peak: easy runs ≥ 6 km (a 3 km jog next to a 29 km long run is no training
      // week – Pfitzinger / Higdon general-aerobic runs 8–13 km); otherwise ≥ 3 km.
      // (Never more than ~60 % of a short, time-capped long run.)
      // Other marathon weeks (base, recovery, taper – review r2 MINOR: 3–3.5 km jogs in the taper):
      // ≥ 5 km (~30 min), taper ≥ 4.5 km, race week ≥ 4 km (~25 min) – short enough to keep the taper's volume
      // cut (Bosquet 2007), long enough to count.
      final mara = a.eventDistance == 'm' && !beginner;
      final easyFloor =
          mara && (phase == 'build' || phase == 'peak')
              ? max(3.0, min(6.0, (_longKmOf(week) ?? longKm) * 0.6))
              // (≤ 75 % of the week's long run – race week: of the last loading week's – so a short,
              // time-capped long run stays the longest.)
              : (mara
                  ? max(
                    3.0,
                    min(
                      _taperLast ? 4.0 : (phase == 'taper' ? 4.5 : 5.0),
                      (_longKmOf(week) ?? (_taperLast && lastLongKm > 0 ? lastLongKm : longKm)) * 0.75,
                    ),
                  )
                  : 3.0);
      if (easyRuns.isNotEmpty) {
        final runs = week.where((p) => p.sport == Sport.run);
        final used = runs.fold<double>(0, (x, p) => x + runningKm(p));
        final longest = runs.where((p) => p.intensity == 'long').fold<double>(0, (x, p) => max(x, runningKm(p)));
        final ref = longest > 0 ? longest : longKm;
        // Multisport with ≤ 3 runs: the run day rotates between quality and easy week by week
        // (B7) – an easy run of ~half the long run keeps the run volume from jumping ±25 %.
        final multiRun = spec?.multisport == true && runPerWeek <= 3;
        final brickKm = week.where((p) => p.sport == Sport.run && p.intensity == 'moderate').fold<double>(0, (x, p) => x + runningKm(p));
        var capKm = max(3.0, rest ? ref * 0.6 : (multiRun ? ref * 0.5 - brickKm : ref * 0.75));
        // Just off run/walk: easy runs start at the 30 min run and grow ≤ 10 % a week (R1) – the long
        // run's walk breaks do not make a 45 min continuous easy run safe.
        if (easyKm > 0) capKm = max(3.0, min(capKm, rest ? easyKm * 0.8 : easyKm));
        // Multisport recovery weeks: no easy run longer than the last loading week's (a 47 min "recovery run" after 30 min
        // easy runs – the share of the long run alone set it).
        if (rest && multiRun && lastEasyRunKm > 0) capKm = max(3.0, min(capKm, lastEasyRunKm));
        // A plan that starts mid-week only has part of the week left: the runs before the
        // start day keep their share, so the remaining easy runs are not stuffed with
        // the whole weekly volume (which made the first week the hardest).
        // Multisport loading weeks: an easy run of ≥ 25 min (advanced 30) – the share of a short long run minus a long
        // brick left 15–20 min jogs (review 2026-11 tri-8).
        final floorKm =
            // (Rounded up to 0.5 km: rounded down, "25 min" came out at 23 – G2-V10.)
            spec?.multisport == true && !rest
                ? max(easyFloor, ((level == 'advanced' ? 30 : 25) * 60 / _longPace * 2 - 1e-9).ceil() / 2)
                : easyFloor;
        final each = ((wk - used) / (easyRuns.length + skippedRuns)).clamp(floorKm, max(floorKm, capKm)).toDouble();
        for (final (day, cap) in easyRuns) {
          week.add(_easyRun(day, phase, each, w, cap));
        }
      }
      // Knee / hip / ankle: with ≥ 3 runs one easy run becomes an easy ride of the same
      // time – the aerobic stimulus stays, the impact goes (cross-training, H8).
      if (hf.lowImpactRun && !runWalk) {
        // Planned runs only – a brick run off the bike must not make the swap come and go.
        final runs = week.where((p) => p.sport == Sport.run && p.intensity != 'moderate').length;
        // Not on a day that already has a ride (FUZZ-8: "long ride" + "easy ride instead of a run" on one Saturday): an
        // easy run on a day without a ride, else the run's time goes to that day's ride.
        bool rideDay(DateTime d, {bool easy = false}) =>
            week.any((p) => p.sport == Sport.ride && p.date == d && (!easy || p.intensity == 'easy' || p.intensity == 'long'));
        int easyRun(bool Function(PlannedWorkout) ok) => week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'easy' && ok(p));
        final free = easyRun((p) => !rideDay(p.date));
        if (runs >= 3 && free >= 0) {
          week[free] = _crossRide(week[free].date, phase, week[free].durationMin);
        } else if (runs >= 3) {
          // (Only into an easy or long ride – a quality ride keeps its structure: "Threshold 2 × 8 min" with a 25 min Z2
          // block in a 55 min ride, review 2026-11 G2-V10; no such ride – the run stays.)
          final i = easyRun((p) => rideDay(p.date, easy: true));
          if (i >= 0) {
            final run = week.removeAt(i);
            final j = week.indexWhere((p) => p.sport == Sport.ride && p.date == run.date);
            if (j >= 0) week[j] = _longerRide(week[j], run.durationMin);
          }
        }
      }
      // Multisport run/walk (review 2026-11 G2-V9: 26 → 36 min of running from one week to the next when the easy
      // run/walk moved on a stage): the week's running grows ≤ 30 % over the last loading week's – the easy run/walk
      // gives up blocks, the long run/walk keeps its own ≤ +10 % / +5 min step.
      if (runWalk && spec?.multisport == true) {
        int rwSec(PlannedWorkout p) =>
            p.steps.any((x) => x.zone == 'walk') ? p.steps.where((x) => x.isWork).fold(0, (t, x) => t + (x.durationSec ?? 0)) : 0;
        int blocks(PlannedWorkout p) => p.steps.where((x) => x.isWork).length;
        int rwTotal() => week.where((p) => p.sport == Sport.run).fold(0, (t, p) => t + rwSec(p));
        final n = week.where((p) => p.sport == Sport.run && rwSec(p) > 0).length;
        // (Against a full week with as many run/walks – a plan starting mid-week has a short first week – and never
        // below half the stage's blocks.)
        if (!rest && rwWeekRun > 0 && n <= rwWeekN) {
          final minBlocks = (_runWalkTable[min(rwStage, _runWalkTable.length - 1)].$3 / 2).ceil();
          for (var t = 0; t < 10 && rwTotal() > rwWeekRun * 1.3; t++) {
            final i = week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'easy' && rwSec(p) > 0 && blocks(p) > minBlocks);
            if (i < 0) break;
            week[i] = _runWalk(week[i].date, rwStage, phase, maxReps: blocks(week[i]) - 1);
          }
        }
        if (!rest) {
          rwWeekRun = rwTotal();
          rwWeekN = n;
        }
      }
      // Whole-week checks on the sessions actually planned (after the time caps) – single-sport runs.
      _clampedThisWeek = false;
      if (longCtx != null && !runWalk && spec?.multisport != true) {
        final lc = longCtx;
        _shapeRunWeek(
          week,
          rebuildLong: (km) => _run(lc.$1, 'long', phase, wk, km, tempoMin, intervalReps, w, lc.$2),
          rebuildEasy: (day, km) => _easyRun(day, phase, km, w, easyRuns.firstWhere((e) => e.$1 == day, orElse: () => (day, 60)).$2),
          rebuildQuality: (i, capMin) {
            final q = qualityCtx.where((c) => c.$1 == i).firstOrNull;
            return q == null ? null : _run(q.$2, q.$3, phase, wk, longKm, tempoMin, intervalReps, w, capMin);
          },
          // The share clamp never takes a loading week's long run below the last loading week's (coach
          // review 2: no drop within a block; the longest run stays close to the race).
          minLongKm: !rest && _longVariant != 2 ? lastLongKm : 0,
          ceilingKm: hf.lowImpactRun ? runCeiling * 0.9 : runCeiling,
          easyFloor: easyFloor,
          loading: !rest,
          lastLoadKm: phase == 'recovery' ? lastLoadRunKm : null,
        );
      }
      // Brick runs count as run volume: when they push the week past its run km, the long run
      // gives up to 8 % (the easy runs already shrank in pass 2).
      if (brick && longCtx != null) {
        final li = week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'long');
        final total = week.where((p) => p.sport == Sport.run).fold<double>(0, (x, p) => x + runningKm(p));
        if (li >= 0 && total > wk * 1.1) {
          final cur = runningKm(week[li]);
          final trimmed = max(cur * 0.92, cur - (total - wk * 1.1));
          if (trimmed < cur - 0.25) week[li] = _run(longCtx.$1, 'long', phase, wk, trimmed, tempoMin, intervalReps, w, longCtx.$2);
        }
        // Still above – also above +12 % on the last two loading weeks' run km (R2; the volume curve's +10 % tolerance on
        // top of its own growth let a duathlon's peak week jump +16–36 %, review 2026-11 tri-9): the runs off / before the
        // bike give the rest (≥ 10 / 5 min) – the long run keeps its progression and stays the week's longest, the brick
        // does not stack on top of a full run week (§6.3: the brick counts as run volume).
        final ref = max(lastLoadRunKm, prevLoadRunKm);
        final lim = min(wk * 1.1, !rest && ref > 0 ? ref * 1.12 : double.infinity);
        for (var t = 0; t < 8; t++) {
          final now = week.where((p) => p.sport == Sport.run).fold<double>(0, (x, p) => x + runningKm(p));
          if (now <= lim + 0.25) break;
          bool isFirst(PlannedWorkout p) => p.description.startsWith(l.wDuRunFirstDesc);
          final bi = week.lastIndexWhere((p) => p.sport == Sport.run && p.intensity == 'moderate' && p.durationMin > (isFirst(p) ? 5 : 10));
          if (bi < 0) break;
          final b = week[bi];
          final first = isFirst(b);
          final m = max(first ? 5 : 10, b.durationMin - 5);
          if (m >= b.durationMin) break;
          week[bi] = _brickRun(b.date, phase, m, first: first);
        }
      }
      // Masters (≥ 50) and women ≥ 45 without strength sessions: one easy session a loading week carries
      // a short strength routine as a suggestion (muscle, bone and tendon loss with age; §2.9 / §9.2 –
      // review 2026-11 MINOR). Not a separate day: the athlete chose the days.
      if (strengthHint && !rest) {
        final i = week.indexWhere((p) => p.intensity == 'easy' && !p.isKey && p.sport != Sport.gym);
        if (i >= 0) week[i] = _withNote(week[i], l.wMastersStrengthNote);
      }
      out.addAll(week);
      final longRun = week.where((p) => p.sport == Sport.run && p.intensity == 'long').firstOrNull;
      if (!rest && longRun != null && _longVariant != 2) lastLongKm = runningKm(longRun);
      extendedPrev = _longExtraNow > 0 && longRun != null && longRun.durationMin > _longRunMaxMin + 2;
      if (extendedPrev) _extendedRuns.add(dayOnly(longRun.date));
      if (!rest && !runWalk && longRun != null && spec?.multisport != true) {
        final km = runningKm(longRun);
        // A long run the whole-week checks cut below what R1 allowed: the plan's own long runs are the
        // reference from now on (the cold-start guess would let the next one jump > 10 %).
        longestRun = _clampedThisWeek ? max(actualLongMax, km) : max(longestRun, km);
        actualLongMax = max(actualLongMax, km);
      }
      // (A plan starting mid-week: the days before the start had their share of the week – a recovery week right
      // after it would otherwise be cut to 75 % of a partial week.)
      if (!rest) {
        lastEasyRunKm = week.where((p) => p.sport == Sport.run && p.intensity == 'easy').fold(0.0, (x, p) => max(x, runningKm(p)));
        prevLoadRunKm = lastLoadRunKm;
        final km = week.where((p) => p.sport == Sport.run).fold(0.0, (x, p) => x + runningKm(p));
        lastLoadRunKm = max(km, skippedRuns > 0 ? wk : 0.0);
      }
      final longRideW = week.where((p) => p.sport == Sport.ride && p.intensity == 'long').firstOrNull;
      if (!rest && longRideW != null && !imRunWeek) lastLongRide = longRideW.durationMin;
      if (phase == 'recovery') block = 0;
      if (!rest) {
        loadWeeks++;
        block++;
        if (week.any((p) => p.sport == Sport.swim)) {
          _swimStage++;
          // After the CSS test: 500 m in one go, then +100 m a loading week (≈ +15–20 %; swimming
          // carries little impact load, H8) up to the race's continuous swim.
          // Goal-directed: up to +200 m when +100 m a week cannot reach the race's continuous swim in the
          // loading weeks left (≤ ~+25–40 % at 500–800 m – swimming carries little impact load, H8).
          if (swimGoal != null && (_swimTested || swimBeginner || swimLong)) {
            final left = phases.sublist(w + 1).takeWhile((p) => p != 'taper').where((p) => p != 'recovery').length;
            final step = left <= 0 ? 100.0 : (((swimGoal - _contSwimM) / left / 100).ceil() * 100.0).clamp(100.0, 200.0);
            _contSwimM = _contSwimM == 0 ? min(swimGoal, 500.0) : min(swimGoal, _contSwimM + step);
          }
        }
        if (runWalk && ++rwHeld >= rwPerStage) {
          rwPos = rwPos + 1;
          rwHeld = 0;
        }
        if (!runWalk && rwStart != null) postRw++;
        if (!runWalk && easyKm > 0) easyKm = _r1(easyKm * _longCap + 0.25);
        // Up to 40 min of T in cruise intervals (Daniels); continuous tempo stays ≤ 30 min.
        tempoMin = min(tempoMin + (a.difficulty == 'easy' ? 2 : 4), 40);
        if (w.isOdd) intervalReps = min(intervalReps + 1, level == 'advanced' ? 8 : 6);
      }
    }
    // A running event whose long run never reaches the race's (time-capped other runs, too few weeks):
    // a finish goal – no race time ([finishOnly], review r2 C6). Only with ≥ 6 loading weeks before the
    // taper: a plan re-generated close to the race has no long runs left to build.
    final runEvent = spec?.sport == EventSport.run && weeksToEvent != null && runPerWeek > 0 && _rwAtRace == null && !_finishBase(profile);
    // Far short (review 2026-11 H4: marathons raced "normally" after 13.5–17.5 km long runs): the longest run
    // – planned, or already done ([AthleteData.longestRunKm]) – stays below ~65 % of what the race needs.
    // Then the race is a finish goal whatever the athlete's race times or target: no race-pace work, no
    // race time (Pfitzinger / Higdon: a marathon without ~28–32 km long runs is survived, not raced).
    // (≥ 3 loading weeks before the taper: a plan re-generated in the taper has no long runs left to show.)
    if (!_finishMode) {
      _longShort =
          runEvent &&
          ((loadBeforeTaper >= 6 &&
                  // (Only a guessed race time: with race times or a target the athlete's own time stays – the
                  // feasibility issues say the long run falls short; the goal forecast follows the same rule.)
                  a.raceTimes.isEmpty &&
                  a.targetTimeSec == null &&
                  !_reachesLongRun(out)) ||
              (loadBeforeTaper >= 3 && _farShort(out)));
    }
    if (!_probing && weeksToEvent != null) _shortCache['${profile.toMap()}|${dayKey(startOfWeek(start))}'] = _longShort;
    // A finish goal plans no race-pace work: the plan is generated once more in finish mode (only then – the
    // long sessions do not depend on it). The probe of [longRunShortFor] only needs [_longShort].
    if (_longShort && !_finishMode && !_probing) {
      _finishMode = true;
      try {
        // (With the gym history – the rotation and the A/B week continue from it; review 2026-11 eng-2.)
        return generate(start: start, weeks: weeks, gymHistory: gymHistory);
      } finally {
        _finishMode = false;
      }
    }
    // Extra recovery after a long run beyond the cap (the legs need 48–72 h after > 3 h on the feet): the run
    // of the next day is a short recovery run (≤ ~40 min; the ultra's back-to-back run is already shortened),
    // a quality run in the two days after it becomes one too.
    for (final d in _extendedRuns) {
      for (var i = 0; i < out.length; i++) {
        final x = out[i];
        final gap = daysBetween(d, dayOnly(x.date));
        if (x.sport != Sport.run || gap < 1 || gap > 2 || x.title == l.wBackToBack) continue;
        final quality = x.intensity == 'tempo' || x.intensity == 'intervals';
        final shortKm = max(3.0, _floorHalf(40 * 60 / pz.easySlow));
        if (!quality && !(gap == 1 && x.intensity == 'easy' && runningKm(x) > shortKm)) continue;
        final km = gap == 1 ? min(shortKm, max(3.0, _floorHalf(runningKm(x)))) : max(4.0, min(8.0, _floorHalf(runningKm(x) * 0.7)));
        out[i] = _plan(
          x.date,
          Sport.run,
          l.wRecoveryRun,
          [l.wEasyDesc, l.wAfterExtendedNote].join('\n'),
          'easy',
          [_runStep('steady', 'E', km: km, note: l.stepEasyNote)],
          x.phase ?? 'build',
          false,
        );
      }
    }
    _addRace(out, start);
    // Estimated FTP (power meter, no FTP stated – review 2026-11 RS4): every ride with watt targets says so.
    final estimated = a.ftp == null && ftp != null;
    final res = [
      for (final w in out)
        (hf.any ? _withHealthNotes(estimated ? _withFtpNote(w) : w) : (estimated ? _withFtpNote(w) : w)).copyWith(slot: _slotOf(w)),
    ];
    return res..sort(PlannedWorkout.compareByDay);
  }

  /// The long run of this week was cut by its share of the week (or by the next-longest run): the R1
  /// reference then follows the plan's own long runs ([generate]). (Whether the other runs keep the long run
  /// short, [feasibility] tells from [_rampMaxKm].)
  bool _clampedThisWeek = false;

  /// Longest long run the weekly step of R1 ([_longStepCap]) alone allows by the last loading week (km).
  double _rampMaxKm = 0;

  /// Long run's share of the week / ratio to the next-longest run in weeks with three runs
  /// (Galloway / Higdon novice plans, [_shapeRunWeek]): ≤ 60 % – marathon / ultra ≤ 55 %
  /// ([threeRunShareFor]; review 2026-11 H3: a 27 km long run was 62 % of a 43.8 km week).
  static const threeRunLongShare = 0.60, threeRunLongRatio = 3.5;

  /// [threeRunLongShare] for the event [ev]: marathon / ultra 55 % (their long runs of 25–32 km need
  /// midweek runs that carry the week).
  static double threeRunShareFor(String? ev) => ev == 'm' || ev == 'ultra50' ? 0.55 : threeRunLongShare;

  /// Longest run (min) of a week with a single run ([generate]).
  static const singleRunMaxMin = 90;

  /// Whole-week rules on the run sessions actually planned (single-sport running, after the time
  /// caps – the volume curve alone did not see them; review C9, IMPORTANT 3 / 12):
  ///
  /// * The long run ≤ 50 % of the week's run km (marathon 55 %, §1.10; 3-run weeks 65 % / ≤ 3.5 × the next run,
  ///   [threeRunLongShare]; not in 2-run weeks) and, in weeks with
  ///   ≤ 4 runs, ≤ 2 × the next-longest run (not marathon / ultra: their race-specific long run is ~3 ×
  ///   the midweek runs at amateur volumes, Pfitzinger / Higdon). Loading weeks first let the easy runs
  ///   grow (their time, ≤ 75 % of the long run, the ceiling; at the ceiling the shortest easy run
  ///   gives volume to the longest), then the long run is shortened – never below the last loading
  ///   week's ([minLongKm]) – a 120' long run next to 30' runs was 66 % of the week.
  /// * Loading weeks stay ≤ [ceilingKm] including the long run (R5: 1.5 × the stated volume, the level
  ///   ceiling): easy runs (≥ [easyFloor], marathon −1 km) shrink first, then the quality runs, then the
  ///   long run.
  /// * A recovery week stays ≤ 75 % (recovery factor + 5 %) of the last loading week's run km
  ///   ([lastLoadKm]) – 3 km easy-run floors left beginner recovery weeks at 83–87 %.
  void _shapeRunWeek(
    List<PlannedWorkout> week, {
    required PlannedWorkout Function(double km) rebuildLong,
    required PlannedWorkout Function(DateTime day, double km) rebuildEasy,
    required PlannedWorkout? Function(int index, int capMin) rebuildQuality,
    required double minLongKm,
    required double ceilingKm,
    required double easyFloor,
    required bool loading,
    double? lastLoadKm,
  }) {
    final li = week.indexWhere((p) => p.sport == Sport.run && p.intensity == 'long');
    if (li < 0) return;
    double km(PlannedWorkout p) => runningKm(p);
    bool isRun(int i) => week[i].sport == Sport.run;
    final runIdx = [
      for (var i = 0; i < week.length; i++)
        if (isRun(i)) i,
    ];
    if (runIdx.length < 2) return;
    double total() => runIdx.fold(0.0, (x, i) => x + km(week[i]));
    double next() => runIdx.where((i) => i != li).fold(0.0, (x, i) => max(x, km(week[i])));
    final easyIdx = [
      for (final i in runIdx)
        if (week[i].intensity == 'easy' && week[i].title != l.wBackToBack) i,
    ];
    final qIdx = [
      for (final i in runIdx)
        if (week[i].intensity == 'tempo' || week[i].intensity == 'intervals') i,
    ];
    final dist = a.eventDistance;
    // (Runs actually planned this week: a knee runner's swapped easy run is a ride.) Two-run weeks
    // (hybrid, a swapped easy run) are one long + one shorter run by design – the volume curve's share
    // (55 %) decides there; tying the long run to the quality run left it flat for weeks.
    final twoRuns = runIdx.length < 3;
    // Three-run weeks (C6, round 2): Galloway / Higdon novice HM plans put ~60–65 % of the week into
    // the long run (2 × 5 km midweek + 16 km) – at ≤ 50 % / ≤ 2 × the next run a 3 × 30 min athlete's
    // long run stayed at 7 km for seven weeks. R1 and the long run's time cap still bound it.
    final threeRuns = runIdx.length == 3;
    final share = twoRuns ? 1.0 : (threeRuns ? threeRunShareFor(dist) : (dist == 'm' ? 0.55 : 0.5));
    // Marathon / ultra: the share alone – their race-specific long run is ~3–3.5 × the midweek runs at
    // amateur volumes (Pfitzinger / Higdon: 29–32 km next to 8–10 km), a 2 × rule would cap it at ~20 km.
    // With ≥ 5 runs the volume is spread anyway (a 55 km HM runner's 20 km long run next to a 9 km
    // midweek run is normal) – the 2 × rule is for 4-run weeks; 3-run weeks allow 3.5 × (novice plans:
    // 16 km next to 5 km runs).
    final ratio =
        twoRuns || dist == 'm' || dist == 'ultra50' || runIdx.length >= 5 ? double.infinity : (threeRuns ? threeRunLongRatio : 2.0);
    bool longOk() => km(week[li]) <= share * total() + 0.25 && km(week[li]) <= ratio * next() + 0.25;

    // Trims the week to [limit] km: easy runs (longest first, ≥ [floor]), the quality runs (~10 %
    // shorter), then the long run (≥ [longMin]).
    void trimTo(double limit, double floor, {double longMin = 4}) {
      for (var t = 0; t < 40 && total() > limit + 0.05; t++) {
        // Longest first – with the 2 × rule the shortest first, so the next-longest run keeps carrying
        // the long run.
        final e =
            easyIdx.where((i) => (week[i].steps.firstOrNull?.distanceM ?? 0) / 1000 > floor + 0.25).toList()
              ..sort((x, y) => ratio.isFinite ? km(week[x]).compareTo(km(week[y])) : km(week[y]).compareTo(km(week[x])));
        if (e.isNotEmpty) {
          // The easy part (strides add a little distance on top).
          final easyKm = (week[e.first].steps.firstOrNull?.distanceM ?? km(week[e.first]) * 1000) / 1000;
          final r = rebuildEasy(week[e.first].date, max(floor, easyKm - 0.5));
          if (km(r) < km(week[e.first]) - 0.05) {
            week[e.first] = r;
            continue;
          }
        }
        var done = false;
        for (final i in qIdx) {
          final r = rebuildQuality(i, max(20, (week[i].durationMin * 0.9).floor()));
          if (r != null && km(r) < km(week[i]) - 0.1) {
            week[i] = r;
            done = true;
            break;
          }
        }
        if (done) continue;
        final cut = max(longMin, _floorHalf(km(week[li]) - (total() - limit)));
        if (cut < km(week[li]) - 0.25) {
          week[li] = rebuildLong(cut);
          continue;
        }
        break;
      }
    }

    // 1. Loading weeks: the easy runs grow towards the long run's share.
    if (loading) {
      for (var t = 0; t < 40 && !longOk() && total() < ceilingKm - 0.25; t++) {
        var grew = false;
        // ≤ 2 × the next-longest run: the longest easy run grows; the share: the shortest one.
        final byRatio = km(week[li]) > ratio * next() + 0.25;
        final order = [...easyIdx]..sort((x, y) => byRatio ? km(week[y]).compareTo(km(week[x])) : km(week[x]).compareTo(km(week[y])));
        for (final i in order) {
          final cur = km(week[i]);
          final want = min(cur + 0.5, km(week[li]) * 0.75);
          if (want <= cur + 0.05) continue;
          // (The E part grows; strides add a little on top.)
          final easyKm = (week[i].steps.firstOrNull?.distanceM ?? cur * 1000) / 1000;
          final r = rebuildEasy(week[i].date, easyKm + (want - cur));
          if (km(r) > cur + 0.05) {
            week[i] = r;
            grew = true;
            break; // one run per step, then re-check
          }
        }
        if (!grew) break;
      }
    }
    if (loading && ratio.isFinite && easyIdx.length >= 2) {
      // Still above 2 × the next-longest run (the ceiling stopped the growth): volume shifts: the shortest easy run gives 0.5 km to the longest.
      for (var t = 0; t < 20 && km(week[li]) > ratio * next() + 0.25; t++) {
        final s = [...easyIdx]..sort((x, y) => km(week[x]).compareTo(km(week[y])));
        final lo = s.first, hi = s.last;
        double easyOf(int i) => (week[i].steps.firstOrNull?.distanceM ?? km(week[i]) * 1000) / 1000;
        if (easyOf(lo) < 3.5 || km(week[hi]) >= km(week[li]) * 0.75) break;
        final up = rebuildEasy(week[hi].date, easyOf(hi) + 0.5);
        if (km(up) <= km(week[hi]) + 0.05) break;
        week[hi] = up;
        week[lo] = rebuildEasy(week[lo].date, easyOf(lo) - 0.5);
      }
    }
    // 2. The long run: ≤ share of the week and ≤ ratio × the next-longest run.
    void clampLong() {
      if (longOk()) return;
      final others = total() - km(week[li]);
      final lim = max(max(4.0, min(km(week[li]), minLongKm)), _floorHalf(min(share / (1 - share) * others, ratio * next() + 0.25)));
      if (lim < km(week[li]) - 0.25) {
        week[li] = rebuildLong(lim);
        _clampedThisWeek = true;
      }
    }

    clampLong();
    // 3. The weekly ceiling, long run included – marathon easy runs may give up to 1 km of their 6 km
    //    floor before the race-specific long run shrinks.
    if (loading) {
      trimTo(ceilingKm, easyFloor > 3 ? easyFloor - 1 : easyFloor);
      clampLong();
    }
    // 4. Recovery week: ≤ 75 % of the last loading week (the long run keeps its share after the cut).
    if (lastLoadKm != null && lastLoadKm > 0) {
      // (Marathon easy runs keep ≥ 4 km – [easyFloor] − 1.)
      trimTo(lastLoadKm * min(0.75, _recoveryFactor + 0.05), easyFloor > 3 ? easyFloor - 1 : 3.0);
      clampLong();
    }
  }

  /// [w] (a ride) [extraMin] minutes longer in Zone 2 – before its cool-down (the time of a run it absorbs).
  PlannedWorkout _longerRide(PlannedWorkout w, int extraMin) {
    final steps = [...w.steps];
    final at = steps.isNotEmpty && steps.last.kind == 'cooldown' ? steps.length - 1 : steps.length;
    steps.insert(at, _rideStep('steady', 'Z2', extraMin * 60, note: l.stepZ2RideNote));
    final p = _plan(w.date, Sport.ride, w.title, w.description, w.intensity, steps, w.phase ?? 'base', w.isKey);
    return w.copyWith(steps: steps, durationMin: p.durationMin, distanceKm: p.distanceKm);
  }

  /// Easy ride replacing a run (knee / hip / ankle limitation).
  PlannedWorkout _crossRide(DateTime day, String phase, int minutes) => _plan(
    day,
    Sport.ride,
    l.wCrossRide,
    l.wCrossRideDesc,
    'easy',
    [_rideStep('steady', 'Z2', max(20, minutes) * 60, note: l.stepZ2RideNote)],
    phase,
    false,
  );

  /// [w] with [note] as an extra line of its description.
  /// (A copy that keeps every other field – also the gym day adaptations [PlannedWorkout.gymMods].)
  PlannedWorkout _withNote(PlannedWorkout w, String note) =>
      w.copyWith(description: [if (w.description.isNotEmpty) w.description, note].join('\n'));

  /// Adds the notes of the athlete's health limitations to [w]'s description (one line
  /// each, so they translate with the rest of the plan).
  PlannedWorkout _withHealthNotes(PlannedWorkout w) {
    final hard = w.intensity == 'tempo' || w.intensity == 'intervals';
    final notes = <String>[
      if (w.sport == Sport.run && hf.lowImpactRun && w.intensity != 'race') l.healthRunNote,
      // Knee / hip on the bike (review 2026-11 RS5, §9.1): high cadence, light gears on climbs, saddle height.
      if (w.sport == Sport.ride && hf.kneeOrHip && w.intensity != 'race') l.healthRideKneeNote,
      if ((w.sport == Sport.run || w.sport == Sport.ride) && hf.capIntensity && hard) l.healthHeartNote,
      if (w.sport == Sport.swim && hf.avoidOverhead && w.intensity != 'race') l.healthSwimShoulderNote,
      // (A workout whose lifts were swapped already says so – [_gym]; the general note for the others.)
      // (Not for a bodyweight workout without a lift to swap – review G3V-5: "swap squats for leg press" did not fit.)
      if (w.sport == Sport.gym && hf.avoidAxialLoading && !w.gymMods.contains(gymModNoAxial) && !_bodyweightProgram(_exercisesOfWorkout(w)))
        l.healthGymBackNote,
      if (w.sport == Sport.gym && hf.avoidOverhead && !w.gymMods.contains(gymModNoOverhead)) l.healthGymShoulderNote,
      if (w.sport == Sport.gym && hf.kneeOrHip) l.healthGymJointNote,
      if (w.sport == Sport.gym && hf.noStraining) l.healthGymHeartNote,
    ];
    if (notes.isEmpty) return w;
    // (copyWith keeps the gym day adaptations – review r7 R1: a back-pain beginner got the barbell
    // deadlift and a knee athlete race-week squats while the notes promised otherwise.)
    return w.copyWith(description: [if (w.description.isNotEmpty) w.description, ...notes].join('\n'));
  }

  // ───────────────────────────── Time available ─────────────────────────────

  /// Minutes for one session ([slot]) of the day [weekday] with [slots]: the day's limit split
  /// between its sessions – evenly, except that a long session sharing its day with a shorter one
  /// (a swim, an easy run, strength) leaves that one only what it needs (a third of the day,
  /// 30–60 min) and keeps the rest. The even split capped the long ride of a 4 h day with a swim
  /// at 2 h, and the feasibility check then said the day was too short (user report 2026-11).
  int _capMinutes(int weekday, List<_Slot> slots, _Slot slot) => splitDayMinutes(
    dayMinutesFor(profile, weekday),
    slots.length,
    slots.where((s) => s.role == 'long').length,
    slot.role == 'long',
    // The long-ride day of a plan with bricks also carries the run off the bike.
    brickDay: spec?.brick != null && slots.any((s) => s.sport == Sport.ride && s.role == 'long'),
  );

  /// Minutes of one of [sessions] sessions on a day with [day] minutes, [longs] of them long. On a
  /// [brickDay] the short session (a swim) gets 30 min – long ride and brick run come first.
  static int splitDayMinutes(int day, int sessions, int longs, bool isLong, {bool brickDay = false}) {
    if (sessions <= 1) return max(20, day);
    if (longs == 0 || longs == sessions) return max(20, (day / sessions).round());
    final short = min(day / sessions, brickDay ? 30.0 : (day / 3).clamp(30.0, 60.0));
    if (!isLong) return max(20, short.round());
    return max(20, ((day - short * (sessions - longs)) / longs).round());
  }

  /// Time available on [weekday]: explicit per-day value, else the global maximum –
  /// on the long-session day at least [longDayDefault] unless that day was set explicitly.
  static int dayMinutesFor(UserProfile p, int weekday) {
    final a = p.athlete;
    final explicit = a.dayMinutes[weekday];
    if (explicit != null) return explicit;
    final longDay = longDayOf(p);
    if (weekday == longDay) return max(a.sessionMinutes, longDayDefault(p));
    final second = _secondLongDefault(p);
    if (second != null && (longSessionDays(p).values.contains(weekday) || backToBackDay(p) == weekday)) {
      return max(a.sessionMinutes, second);
    }
    return a.sessionMinutes;
  }

  /// Day of each sport's long session (run / ride): the sport on the long day gets it,
  /// the other one its latest still free day (masters: not next to the first one).
  static Map<Sport, int> longSessionDays(UserProfile p) =>
      _longSessionDays(scheduleOf(p), longDayOf(p), (p.age ?? 30) >= 50, minutes: _explicitMinutes(p), rideFirst: _rideFirst(p));

  /// Triathlon / duathlon: the long ride takes the long day when the long day holds a ride and a run (a day plan
  /// "Sat: ride + run" – review 2026-11 FUZZ-8: the long run took Saturday's 3 h, the long ride a 60 min Thursday).
  static bool _rideFirst(UserProfile p) => p.focus == TrainingFocus.triathlon || p.focus == TrainingFocus.duathlon;

  /// Time the athlete set for [weekday] (else the global session time) – no long-day defaults,
  /// so it can decide which day is the long day ([dayMinutesFor] depends on that).
  static int Function(int) _explicitMinutes(UserProfile p) => (d) => p.athlete.dayMinutes[d] ?? p.athlete.sessionMinutes;

  /// The long-session day among [days]: the athlete's choice, else the day with the most time set
  /// (70.3 with Sat 240 / Sun 120 min: the long ride goes on Saturday – coach review 3), else the
  /// last day.
  static int _longDayFrom(UserProfile p, List<int> days) {
    if (p.longDay != null && days.contains(p.longDay)) return p.longDay!;
    final m = _explicitMinutes(p);
    var best = days.last;
    for (final d in days.reversed) {
      if (m(d) > m(best)) best = d;
    }
    return best;
  }

  /// The second long session (other sport) goes on the free day with the most time (ties: the
  /// latest; masters: not next to the first one when possible).
  static Map<Sport, int> _longSessionDays(
    Map<int, List<Sport>> schedule,
    int? longDay,
    bool masters, {
    int Function(int)? minutes,
    bool rideFirst = false,
  }) {
    final days = schedule.keys.toList()..sort();
    final out = <Sport, int>{};
    if (days.isEmpty) return out;
    final ld0 = longDay ?? days.last;
    final mins = minutes ?? (int _) => 0;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    bool onLongDay(Sport s) => schedule[ld0]?.contains(s) ?? false;
    int most(List<int> c) => c.reduce((x, y) => mins(y) >= mins(x) ? y : x);
    // Swimming plans (no run / ride): a long continuous swim on the long day.
    final swimOnly = !schedule.values.any((v) => v.contains(Sport.run) || v.contains(Sport.ride));
    for (final sport in [if (rideFirst) Sport.ride, Sport.run, if (!rideFirst) Sport.ride, if (swimOnly) Sport.swim]
      ..sort((x, y) => (onLongDay(y) ? 1 : 0).compareTo(onLongDay(x) ? 1 : 0))) {
      final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
      if (sDays.isEmpty) continue;
      final taken = out.values.toSet();
      final free = sDays.where((d) => !taken.contains(d)).toList();
      // Apart (masters) only where the sport keeps a day for its quality session that is not next
      // to a long session – else the long sessions follow each other (B7).
      final apart =
          free
              .where(
                (d) =>
                    taken.every((t) => dist(t, d) > 1) &&
                    (sDays.length < 2 || sDays.any((e) => e != d && !taken.contains(e) && [...taken, d].every((t) => dist(t, e) > 1))),
              )
              .toList();
      out[sport] =
          sDays.contains(ld0) && !taken.contains(ld0)
              ? ld0
              : (free.isEmpty ? sDays.last : (masters && apart.isNotEmpty ? most(apart) : most(free)));
    }
    return out;
  }

  /// Default time on the day of the triathlon long run (the long ride has the long day):
  /// 70.3 2 h, olympic 90 min – a 60 min cap kept the long run at ~9 km.
  /// Day of the ultra's back-to-back run (§14): the run day right after the long run, else right
  /// before it – only with ≥ 4 runs a week and not for beginners. Null otherwise.
  static int? backToBackDay(UserProfile p) {
    final s = _specOf(p);
    if (s == null || !s.backToBack || p.level == 'beginner') return null;
    final sched = scheduleOf(p);
    final runDays = sched.entries.where((e) => e.value.contains(Sport.run)).map((e) => e.key).toList();
    final ld = longSessionDays(p)[Sport.run];
    if (runDays.length < 4 || ld == null) return null;
    final next = ld == 7 ? 1 : ld + 1, prev = ld == 1 ? 7 : ld - 1;
    return runDays.contains(next) ? next : (runDays.contains(prev) ? prev : null);
  }

  /// Ironman 3 h, ultra 2 h (back-to-back run), duathlon 90 min ([EventSpec.secondLongMin]).
  static int? _secondLongDefault(UserProfile p) {
    final s = _specOf(p);
    if (s == null || (!s.multisport && !s.backToBack)) return null;
    return s.secondLongMin;
  }

  /// Default time on the long-session day by goal ([EventSpec.longDayMin]): the race-specific
  /// long session must fit – marathon long run up to 3 h (~28–32 km), HM 2.5 h, olympic long ride
  /// 2.5 h, 70.3 long ride ≥ 3 h plus the run off the bike, Ironman 6 h, ultra 4 h, 160 km ride
  /// 5 h; otherwise 2 h.
  /// With the long-run extension switched on ([AthleteData.longRunExtend]) the default holds the extended run.
  static int longDayDefault(UserProfile p) {
    final s = _specOf(p);
    if (s == null) return 120;
    final ext = p.athlete.longRunExtend && s.longRunExtraMin > 0 && s.sport == EventSport.run && p.level != 'beginner';
    return ext ? max(s.longDayMin, s.longRunCapMin + s.longRunExtraMin) : s.longDayMin;
  }

  /// The day of the long endurance session (null for gym-only plans).
  static int? longDayOf(UserProfile p) {
    final plan = scheduleOf(p);
    final endurance = plan.entries.where((e) => e.value.any((s) => s != Sport.gym)).map((e) => e.key).toList()..sort();
    if (endurance.isEmpty) return null;
    return _longDayFrom(p, endurance);
  }

  /// Race day of a race goal given as a plan length instead of a date: the long-session day
  /// ([longDayOf] – the day the plan puts its longest session, e.g. the triathlon's long ride) of
  /// the plan's last week. Weeks count like [planWeeksUntil] (the week of [start] is week 1 unless no
  /// training day of it is left – then the next week, [planStartFor]), so a plan from [start] to this day
  /// has exactly [weeks] training weeks and builds up to it (periodisation, taper) like for a dated race.
  /// Without an endurance day: the last training day, else Saturday.
  static DateTime raceDayForWeeks(UserProfile p, DateTime start, int weeks) {
    final days = scheduleOf(p).keys.toList()..sort();
    final day = longDayOf(p) ?? days.lastOrNull ?? DateTime.saturday;
    return addDays(startOfWeek(planStartFor(p, start)), 7 * (max(weeks, 1) - 1) + day - 1);
  }

  // ───────────────────────────── Structure ─────────────────────────────

  /// weekday → sports. Advanced setup provides it directly; otherwise derive it.
  Map<int, List<Sport>> _weekSchedule() => scheduleOf(profile);

  /// The week the plan for [p] uses (weekday → sports): the detailed setup's day plan,
  /// else derived from the training days and focus ([deriveSchedule]).
  ///
  /// A day plan left over from an earlier detailed setup is ignored in the quick setup –
  /// otherwise the plan would silently use other days than the ones just chosen.
  static Map<int, List<Sport>> scheduleOf(UserProfile p, {bool afterRunWalk = false}) {
    final a = p.athlete;
    if (a.advanced && a.dayPlan.values.any((v) => v.isNotEmpty)) {
      // Pure strength: at most [UserProfile.maxPlanDays] gym days in the day plan too (review 2026-11 G3V-3: a
      // beginner's 7-day plan was PPL Monday to Sunday) – the others are rest days, spread over the week.
      final gymDays = [
        for (final e in a.dayPlan.entries)
          if (e.value.contains(Sport.gym)) e.key,
      ]..sort();
      final keep = p.focus == TrainingFocus.gym ? _spreadDays(gymDays, p.maxPlanDays, gymDays.lastOrNull ?? 7).toSet() : gymDays.toSet();
      return {
        for (final e in a.dayPlan.entries)
          if (e.value.isNotEmpty)
            if (keep.contains(e.key) || !e.value.contains(Sport.gym))
              e.key: e.value
            else if (e.value.any((s) => s != Sport.gym))
              e.key: [...e.value.where((s) => s != Sport.gym)],
      };
    }
    return deriveSchedule(p, afterRunWalk: afterRunWalk);
  }

  /// Strength sessions the quick setup adds for an endurance focus when the athlete also
  /// chose a strength / muscle goal (concurrent training: 1–2 sessions a week improve
  /// economy and lower injury risk, Blagrove 2018; §2.9). Endurance keeps priority:
  /// single sport 3–4 days → 1, ≥ 5 days → 2; duathlon / triathlon ≥ 5 days → 1.
  static int extraGymDays(UserProfile p, int days) {
    final strength = p.goals.contains('strength') || p.goals.contains('muscle');
    final sports = p.focus.sports;
    if (!strength || sports.contains(Sport.gym)) return 0;
    if (sports.length == 1) return days >= 5 ? 2 : (days >= 3 ? 1 : 0);
    return days >= 5 ? 1 : 0;
  }

  /// Most training days a week for [p] (quick setup; an explicit day plan is kept as is).
  ///
  /// Beginners keep ≥ 2 rest days (H7, see [ScheduleAdvisor.maxDays]); pure strength
  /// beginners train ≤ 4×/week (full body 2–3× is the evidence-based dose, §2.2);
  /// athletes ≥ 60 keep one rest day (masters need longer recovery between loads).
  static int maxTrainingDays(UserProfile p) => p.maxPlanDays;

  /// Most runs a week: beginners 4 (3 while still on run/walk – Couch-to-5K is 3×/week
  /// with a rest day in between, §1.10).
  /// [afterRunWalk]: the weeks after the run/walk ladder – the athlete's 4th day comes back.
  static int maxRuns(UserProfile p, {bool afterRunWalk = false}) =>
      p.level != 'beginner' ? 7 : (runWalkStartFor(p) != null && !afterRunWalk ? 3 : 4);

  /// Picks [n] of [days]: the long day first, then the days the athlete gave more time than the usual
  /// session ([extra]: minutes beyond it – the most first; review 2026-11 tri-3: a 70.3 beginner's 150 min
  /// Sunday was dropped and the long run went on a 60 min Friday), then always the day farthest (cyclic)
  /// from the days already kept, so rest days are spread over the week.
  static List<int> _spreadDays(List<int> days, int n, int longDay, {Map<int, int> extra = const {}}) {
    if (days.length <= n) return days;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    final kept = <int>[days.contains(longDay) ? longDay : days.last];
    final more = days.where((d) => !kept.contains(d) && (extra[d] ?? 0) > 0).toList()..sort((x, y) => extra[y]!.compareTo(extra[x]!));
    for (final d in more) {
      if (kept.length < n) kept.add(d);
    }
    while (kept.length < n) {
      int? best;
      var bestScore = -1;
      for (final d in days.where((d) => !kept.contains(d))) {
        final score = kept.map((k) => dist(k, d)).reduce(min) * 10 + kept.fold<int>(0, (x, k) => x + dist(k, d));
        if (score > bestScore) {
          bestScore = score;
          best = d;
        }
      }
      kept.add(best!);
    }
    return kept..sort();
  }

  /// Sessions per sport for a multi-sport week of [n] days (one session a day).
  ///
  /// Triathlon follows §6.2 (time split swim ~20 %, bike ~45–50 %, run ~30–35 %):
  /// 3 days one of each, 4 days + a second ride, 5 days + a second run, 6 days 2/2/2,
  /// 7 days + a third ride. With only 2 days the swim is dropped for bike + run unless
  /// the athlete cannot swim 400 m yet. Duathlon / hybrid: the main sport (run) gets the
  /// extra session; hybrid keeps strength at ≤ 3×/week.
  static Map<Sport, int> _multiCounts(UserProfile p, int days, {bool afterRunWalk = false}) {
    var gym = extraGymDays(p, days);
    var counts = <Sport, int>{};
    while (true) {
      final n = days - gym;
      counts = p.focus.sports.length == 1 ? {p.focus.sports.first: n} : _enduranceCounts(p, n);
      // The strength goal's extra day gives way to the race's minimum sessions when the week cannot get another
      // day that keeps its rest days ([ScheduleAdvisor.maxDays]: beginners 5, others 6) – endurance keeps priority
      // ([extraGymDays]; audit UX-4: a triathlon beginner's 5 days with a half marathon had 2 runs). (A second swim
      // that [deriveSchedule] adds as a double day – 70.3 / Ironman, swim novices, beginners – needs no day of its own.)
      final short = _raceMinimumsFirst(p, counts);
      final cap = min(maxTrainingDays(p), ScheduleAdvisor(p, const {}).maxDays);
      final ev = p.athlete.eventDistance;
      final swimDouble =
          short == Sport.swim &&
          p.focus == TrainingFocus.triathlon &&
          counts[Sport.swim] == 1 &&
          (_specOf(p)?.minSwims ?? 0) <= 2 &&
          (ev == '70.3' || ev == 'ironman' || swimNoviceOf(p) || p.level == 'beginner');
      if (short == null || swimDouble || gym == 0 || days < cap) break;
      gym--;
    }
    // Beginners: at most 4 runs (3 on run/walk) also when strength takes the other days.
    if (counts.containsKey(Sport.run) && p.focus == TrainingFocus.run) {
      counts[Sport.run] = min(counts[Sport.run]!, maxRuns(p, afterRunWalk: afterRunWalk));
    }
    return {...counts, if (gym > 0) Sport.gym: gym};
  }

  /// The race's minimum sessions of each discipline ([EventSpec.minRuns] …) come first while the week has days for
  /// them: a session moves from the sport with the most to spare (each sport of the focus keeps at least one). A
  /// duathlon week of 6 days with a marathon had 3 runs and the plan check's "needs at least 4 runs" right after
  /// following the setup's recommendation (audit UX-4). Returns a sport still below its minimum (null: all met).
  static Sport? _raceMinimumsFirst(UserProfile p, Map<Sport, int> counts) {
    final spec = _specOf(p);
    if (spec == null) return null;
    int minOf(Sport s) => switch (s) {
      Sport.run => spec.minRuns,
      Sport.ride => spec.minRides,
      Sport.swim => spec.minSwims,
      _ => 0,
    };
    // Ties: strength gives first, then the swim, the ride, the run.
    const order = [Sport.gym, Sport.swim, Sport.ride, Sport.run];
    for (var guard = 0; guard < 7; guard++) {
      final short = counts.keys.where((s) => counts[s]! < minOf(s)).firstOrNull;
      if (short == null) return null;
      int spare(Sport s) => counts[s]! - max(minOf(s), 1);
      final donors = counts.keys.where((s) => s != short && spare(s) > 0).toList();
      if (donors.isEmpty) return short;
      donors.sort((x, y) => spare(x) != spare(y) ? spare(y).compareTo(spare(x)) : order.indexOf(x).compareTo(order.indexOf(y)));
      counts[donors.first] = counts[donors.first]! - 1;
      counts[short] = counts[short]! + 1;
    }
    return counts.keys.where((s) => counts[s]! < minOf(s)).firstOrNull;
  }

  static Map<Sport, int> _enduranceCounts(UserProfile p, int n) => switch (p.focus) {
    TrainingFocus.triathlon => switch (n) {
      <= 1 => {Sport.ride: 1},
      2 => p.athlete.canSwim400 ? {Sport.ride: 1, Sport.run: 1} : {Sport.swim: 1, Sport.ride: 1},
      3 => {Sport.swim: 1, Sport.ride: 1, Sport.run: 1},
      4 => {Sport.swim: 1, Sport.ride: 2, Sport.run: 1},
      5 => {Sport.swim: 1, Sport.ride: 2, Sport.run: 2},
      6 => {Sport.swim: 2, Sport.ride: 2, Sport.run: 2},
      _ => {Sport.swim: 2, Sport.ride: 3, Sport.run: 2},
    },
    TrainingFocus.hybrid => {Sport.run: n - _hybridGym(p, n), if (n >= 2) Sport.gym: _hybridGym(p, n)},
    _ => {Sport.run: (n + 1) ~/ 2, if (n >= 2) Sport.ride: n ~/ 2},
  };

  /// Strength days of a hybrid week of [n] days: half of them, ≤ 3. With a half marathon, marathon or
  /// ultra the running comes first (2 strength sessions keep the concurrent-training benefit, Blagrove
  /// 2018): 6–7 days → 2 (4–5 runs); marathon / ultra 4–5 days → 1 – three runs a week could not carry a
  /// 28–32 km long run (user report 2026-11: hybrid marathon, 6 days, longest run 21.5 km).
  static int _hybridGym(UserProfile p, int n) {
    final ev = _specOf(p)?.key;
    if ((ev == 'm' || ev == 'ultra50') && n >= 4) return n >= 6 ? 2 : 1;
    if (ev == 'hm' && n >= 6) return 2;
    return min(3, n ~/ 2);
  }

  /// Default weekday → sport mapping from training days and focus.
  /// [afterRunWalk]: the schedule of the weeks after the run/walk ladder (a beginner's 4th run day
  /// is used again – review: the chosen Monday was never planned).
  static Map<int, List<Sport>> deriveSchedule(UserProfile profile, {bool afterRunWalk = false}) {
    var days = (profile.trainingDays.isEmpty ? [...defaultTrainingDays] : [...profile.trainingDays])..sort();
    final longDay = _longDayFrom(profile, days);
    final res = <int, List<Sport>>{};
    // Days with more time than the usual session (detailed setup) are kept first.
    final extra = {
      for (final e in profile.athlete.dayMinutes.entries)
        if (e.value > profile.athlete.sessionMinutes) e.key: e.value - profile.athlete.sessionMinutes,
    };
    days = _spreadDays(days, maxTrainingDays(profile), longDay, extra: extra);
    final gym = extraGymDays(profile, days.length);
    final base = [...profile.focus.sports, if (gym > 0) Sport.gym];
    if (base.length == 1) {
      if (base.first == Sport.run) days = _spreadDays(days, maxRuns(profile, afterRunWalk: afterRunWalk), longDay, extra: extra);
      for (final d in days) {
        res[d] = [base.first];
      }
      return res;
    }
    // Multi-sport: sessions per sport from [_multiCounts], then the arrangement with the
    // fewest conflicts: the main endurance sport on the long day, the same sport not on
    // consecutive days (the week wraps Sunday → Monday) and no strength session the day
    // before the long session (C3). All distinct orders are tried (≤ 210 for 7 days).
    final main =
        profile.focus.sports.length == 1
            ? profile.focus.sports.first
            // Duathlon: the long ride takes the long day (its race leg is the longest), like triathlon.
            : (profile.focus == TrainingFocus.hybrid ? Sport.run : Sport.ride);
    final counts = _multiCounts(profile, days.length, afterRunWalk: afterRunWalk);
    // Fewer sessions than days (e.g. a beginner's run cap): keep the best-spread days.
    days = _spreadDays(days, counts.values.fold<int>(0, (x, y) => x + y), longDay, extra: extra);
    final pool = [for (final s in base) ...List.filled(counts[s] ?? 0, s)];
    bool adjacent(int x, int y) => (x - y).abs() == 1 || (x - y).abs() == 6;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    final masters = (profile.age ?? 30) >= 50;
    // Multisport (review 2026-11, duathlon with zero bike quality in 12 weeks): a run / ride with
    // ≥ 2 sessions needs a day its quality session can go on – not a long day, not next to a long
    // session (beginners / intermediates / masters, H1; advanced: not next to its own sport's), and
    // a run not the day before the long run (H5). An arrangement without one costs more than two
    // sessions of the same sport on consecutive days.
    final multisport = profile.focus == TrainingFocus.duathlon || profile.focus == TrainingFocus.triathlon;
    final strictQ = profile.level != 'advanced' || masters;
    int noQualityDay(List<Sport> seq, Map<Sport, int> longs) {
      var n = 0;
      for (final s in const [Sport.run, Sport.ride]) {
        final sd = [
          for (var i = 0; i < seq.length; i++)
            if (seq[i] == s) days[i],
        ];
        if (sd.length < 2) continue;
        bool ok(int d) =>
            !longs.values.contains(d) &&
            longs.entries.every((e) => dist(e.value, d) > 1 || (!strictQ && e.key != s)) &&
            !(s == Sport.run && d % 7 + 1 == longs[Sport.run]);
        if (!sd.any(ok)) n++;
      }
      return n;
    }

    // The second long session (the long run of a triathlon / duathlon – the long ride has the long day) goes on
    // the day the athlete gave the most time besides the long day (review 2026-11 tri-3: Sat 300 / Sun 150 min
    // set – the long run went on a 60 min Friday at up to 165 min, Sunday held an easy swim and ride). The
    // athlete's time outweighs a missing quality day or two sessions of a sport on consecutive days.
    final setMin = _explicitMinutes(profile);
    final otherBest = profile.athlete.dayMinutes.isEmpty ? 0 : days.where((d) => d != longDay).map(setMin).fold(0, max);
    int longOffTime(List<Sport> seq) {
      if (otherBest <= profile.athlete.sessionMinutes) return 0;
      final m = {
        for (var i = 0; i < seq.length; i++) days[i]: [seq[i]],
      };
      final longs = _longSessionDays(m, longDay, masters, minutes: setMin, rideFirst: _rideFirst(profile));
      return longs.values.where((d) => d != longDay && setMin(d) < otherBest - 15).length;
    }

    int score(List<Sport> seq) {
      var s = 0;
      for (var i = 0; i < seq.length; i++) {
        if (days[i] == longDay && seq[i] != main && pool.contains(main)) s += 100;
        for (var j = i + 1; j < seq.length; j++) {
          if (seq[i] == seq[j] && adjacent(days[i], days[j])) s += seq[i] == Sport.gym ? 4 : 10;
        }
        if (seq[i] == Sport.gym && days[i] % 7 + 1 == longDay) s += 8;
      }
      return s;
    }

    List<Sport>? best;
    var bestScore = 1 << 30;
    void permute(List<Sport> seq, Map<Sport, int> left) {
      if (seq.length == pool.length) {
        var sc = score(seq);
        // The quality-day check only for arrangements that can still win (it is the costly part).
        if (sc >= bestScore) return;
        if (multisport) {
          final longs = _longSessionDays(
            {
              for (var i = 0; i < seq.length; i++) days[i]: [seq[i]],
            },
            longDay,
            masters,
            minutes: _explicitMinutes(profile),
            rideFirst: _rideFirst(profile),
          );
          sc += 12 * noQualityDay(seq, longs) + 30 * longOffTime(seq);
          // No strength session the day before the long run either (C3; [score] covers the long day) – review
          // 2026-11 GYM-9: a 70.3 athlete's only strength day sat before the long run every week.
          for (var i = 0; i < seq.length; i++) {
            final eve = days[i] % 7 + 1;
            if (seq[i] == Sport.gym && eve != longDay && longs.values.contains(eve)) sc += 8;
          }
        }
        if (sc < bestScore) {
          bestScore = sc;
          best = [...seq];
        }
        return;
      }
      for (final s in base) {
        if ((left[s] ?? 0) == 0) continue;
        left[s] = left[s]! - 1;
        seq.add(s);
        permute(seq, left);
        seq.removeLast();
        left[s] = left[s]! + 1;
      }
    }

    permute([], {...counts});
    for (var i = 0; i < days.length && i < best!.length; i++) {
      res[days[i]] = [best![i]];
    }
    // 70.3 with ≤ 5 days has a single swim – too little to build towards 1.9 km
    // continuous (§4.4: 2–3 swims a week). The second swim goes on an easy-session day
    // far from the first one (not the long day, not the day before it) as a double day.
    // Swim novices (cannot swim 400 m yet) get the same: one swim a week built only 0.8–1.3 km a week
    // and an 800 m continuous swim for a 1.5 km open-water leg (review 2026-11 C7; §4.4: 2–3 sessions,
    // 2–4 km a week).
    final ev = profile.athlete.eventDistance;
    final tri = profile.focus == TrainingFocus.triathlon;
    final longCourse = ev == '70.3' || ev == 'ironman';
    List<int> daysWith(Sport s) => [
      for (final e in res.entries)
        if (e.value.contains(s)) e.key,
    ];
    // Triathlon on 2 days (review 2026-11 tri-4: a sprint plan without a single swim – or without a run, while
    // race day ends with 5 km – and no warning): the long ride on the long day (the brick adds the run off the
    // bike), swim + run as a double day on the other – every discipline once a week.
    if (tri && res.length == 2 && res.containsKey(longDay)) {
      final other = res.keys.firstWhere((d) => d != longDay);
      res[longDay] = [Sport.ride];
      res[other] = [Sport.swim, Sport.run];
      return res;
    }
    // Triathlon beginners too (review r2 IMPORTANT 8: a sprint beginner with one swim a week reached 200 m
    // in one go – the 750 m leg needs a continuous-swim progression, §4.4: 2–3 swims a week).
    if (tri && (longCourse || swimNoviceOf(profile) || profile.level == 'beginner')) {
      final swimDays = daysWith(Sport.swim);
      if (swimDays.length == 1 && res.length >= 4) {
        // Not on the day of the run's / ride's only possible quality session nor on a long session's day: the double day
        // halves the time of both sessions (review 2026-11 G2-V4: the second swim halved the only quality ride's 60 min
        // Wednesday – "Sweet Spot 2 × 8 min" for 24 weeks – while Friday's easy run, next to the long ride, had room). The
        // day before the long day only when every other day is one of those.
        final longs = _longSessionDays(res, longDay, masters, minutes: _explicitMinutes(profile), rideFirst: _rideFirst(profile));
        int cost(int d) {
          final s = res[d]!.first;
          final sDays = daysWith(s);
          final qualityDay =
              (s == Sport.run || s == Sport.ride) &&
              !longs.values.contains(d) &&
              longs.values.every((x) => dist(x, d) > 1) &&
              sDays.where((x) => !longs.values.contains(x) && longs.values.every((y) => dist(y, x) > 1)).length == 1;
          return (longs.values.contains(d) ? 3 : 0) + (qualityDay ? 2 : 0) + (d % 7 + 1 == longDay ? 1 : 0);
        }

        final cand =
            res.keys.where((d) => d != longDay && !res[d]!.contains(Sport.swim) && !res[d]!.contains(Sport.gym)).toList()..sort((x, y) {
              final c = cost(x).compareTo(cost(y));
              return c != 0 ? c : dist(y, swimDays.first).compareTo(dist(x, swimDays.first));
            });
        if (cand.isNotEmpty) res[cand.first] = [Sport.swim, ...res[cand.first]!];
      }
    }
    // Triathlon with a single run (4 days: swim, 2 rides, the long run): a short easy run as a double
    // day – preferably after the swim (§6.2 "swim | PM easy run"), far from the long run. One run a week
    // is too little for the impact tolerance a race needs (review 2026-11, sprint beginner).
    final runDays = daysWith(Sport.run);
    if (tri && runDays.length == 1 && res.length >= 4) {
      int pref(int d) => dist(d, runDays.first) * 10 + (res[d]!.contains(Sport.swim) ? 5 : 0);
      final cand =
          res.keys
              .where((d) => d != longDay && res[d]!.length == 1 && !res[d]!.contains(Sport.run) && !res[d]!.contains(Sport.gym))
              .toList()
            ..sort((x, y) => pref(y).compareTo(pref(x)));
      if (cand.isNotEmpty) res[cand.first] = [...res[cand.first]!, Sport.run];
    }
    // 70.3 / Ironman (intermediate / advanced): ≥ 3 rides and ≥ 3 swims a week when a day has the time
    // for a second session (≥ 60 min besides what its own session needs – the long run its cap; never
    // the long-ride day, which carries the brick). A 4 h Saturday with only a 90 min long run left
    // 2.5 h unused (review 2026-11, IMPORTANT 7).
    if (tri && longCourse && profile.level != 'beginner') {
      final spec = _specOf(profile);
      final a = profile.athlete;
      final longs = _longSessionDays(res, longDay, masters, minutes: _explicitMinutes(profile), rideFirst: _rideFirst(profile));
      int mins(int d) =>
          a.dayMinutes[d] ??
          (d == longDay
              ? max(a.sessionMinutes, longDayDefault(profile))
              : (longs.values.contains(d) ? max(a.sessionMinutes, spec?.secondLongMin ?? 0) : a.sessionMinutes));
      // Ironman (review r2 IMPORTANT 9): a 90 min day holds two 45 min sessions – Ironman age-groupers train
      // 2-a-days (Friel); 70.3 keeps 60 min on top of the day's own session.
      // (A third run – an easy 30–45 min run – needs 30 min besides the day's own session.)
      int need(int d, Sport sport) =>
          d == longs[Sport.run] ? (spec?.longRunCapMin ?? 150) : (ev == 'ironman' || sport == Sport.run ? 30 : 60);
      // Third run (review 2026-11 tri-8: an advanced 70.3 athlete on 7 days with 2 sessions a day had two runs and
      // the brick – 31.6 km at the peak; Friel / Fitzgerald: each discipline ≥ 3 × a week for long-course age-groupers):
      // with ≥ 6 days or two sessions a day, as a double day – preferably with a swim (§6.2 "swim | PM easy run"),
      // not next to another run day.
      final runDays0 = daysWith(Sport.run);
      for (final sport in const [Sport.ride, Sport.swim, Sport.run]) {
        if (daysWith(sport).length >= 3) continue;
        if (sport == Sport.run && res.length < 6 && a.sessionsPerDay < 2) continue;
        // The third run never takes the last swim day of its own: the continuous swim needs a whole day (review 2026-11
        // G2-V5: the run halved the only solo swim day – the continuous swim fell from 2000 to 1700 m).
        final soloSwims = res.keys.where((d) => res[d]!.length == 1 && res[d]!.first == Sport.swim).length;
        final cand =
            res.keys
                .where(
                  (d) =>
                      d != longs[Sport.ride] &&
                      res[d]!.length == 1 &&
                      !res[d]!.contains(sport) &&
                      !res[d]!.contains(Sport.gym) &&
                      !(sport == Sport.run && res[d]!.first == Sport.swim && soloSwims <= 1) &&
                      mins(d) - 60 >= need(d, sport),
                )
                .toList()
              // Ties: a ride goes with a swim, a swim with a run, a run with a swim – the quality ride keeps its whole day.
              ..sort((x, y) {
                final m = mins(y).compareTo(mins(x));
                if (m != 0) return m;
                int pref(int d) =>
                    (res[d]!.contains(switch (sport) {
                          Sport.ride => Sport.swim,
                          Sport.swim => Sport.run,
                          _ => Sport.swim,
                        })
                        ? 2
                        : 0) +
                    (sport == Sport.run && runDays0.every((r) => dist(r, d) > 1) ? 1 : 0);
                return pref(y).compareTo(pref(x));
              });
        if (cand.isNotEmpty) res[cand.first] = [...res[cand.first]!, sport];
      }
    }
    return res;
  }

  /// Phases of the plan; no recovery week in the first [noRecoveryBefore] weeks (run/walk).
  ///
  /// A plan re-created mid-plan ([PlanCarry], review 2026-11 adapt-7) continues the replaced plan: never a phase
  /// before the one reached (build / peak: no base weeks again), and the loading / recovery rhythm goes on – the
  /// loading weeks right before it count, and a start in a planned recovery week keeps that week as recovery.
  List<String> _phases(int total, {int noRecoveryBefore = 0}) {
    final carry = _carry;
    // Same race: the replaced plan's own weeks (its taper, recovery weeks and phases) go on unchanged.
    final layout = carry?.phases;
    if (layout != null) {
      final off = daysBetween(startOfWeek(carry!.start), startOfWeek(_start)) ~/ 7;
      if (off >= 0 && layout.length - off == total) return layout.sublist(off);
    }
    // An event more than [GoalModel.specificWeeks] away: the weeks before the race-specific
    // plan are a base "pre-plan" block (easy volume, strides, recovery weeks) – build and peak
    // keep their usual length instead of stretching over a whole year.
    final pre = weeksToEvent != null ? max(0, total - _specificWeeks) : 0;
    final spec = total - pre;
    // Short plans keep most weeks for loading: the taper is at most a third of the plan
    // (a 5-week 70.3 plan gets 1 taper week, not 3 out of 5).
    final taper = weeksToEvent != null ? min(_taperWeeks, min(max(0, spec - 2), max(1, spec ~/ 3))) : 0;
    final body = spec - taper;
    // Phase reached by the replaced plan (1 build, 2 peak / taper); not before a base pre-plan of a moved race.
    final reached = pre == 0 ? (const {'build': 1, 'peak': 2, 'taper': 2}[carry?.phase] ?? 0) : 0;
    final base = reached > 0 ? 0 : max(1, (body * (beginner ? 0.5 : 0.42)).round());
    // (From the build on: build and peak share the weeks left as they do in a whole plan, ~0.4 : 0.18.)
    final peak = weeksToEvent != null ? (reached >= 2 ? body : min(body, max(1, (body * (reached == 1 ? 0.31 : 0.18)).round()))) : 0;
    final build = max(0, body - base - peak);
    final out = <String>[
      ...List.filled(pre + base, 'base'),
      ...List.filled(build, 'build'),
      ...List.filled(peak, 'peak'),
      ...List.filled(taper, 'taper'),
    ];
    // Recovery weeks: after every N loading weeks (never in taper or the final week).
    // (A re-created plan: the replaced plan's loading weeks before it count – a loading first week stays one.)
    final carried = carry == null || carry.recovery ? 0 : carry.loadWeeks;
    var run = noRecoveryBefore == 0 ? min(carried, _loadWeeks - 1) : 0;
    for (var i = 0; i < out.length; i++) {
      if (out[i] == 'taper') break;
      if (i == 0 && carry != null && carry.recovery && out.length - 1 - taper > 0) {
        out[0] = 'recovery';
        run = 0;
        continue;
      }
      if (i < noRecoveryBefore) continue;
      // Right after a run/walk ladder of ≥ N weeks: the ladder (with its growing long run/walk) was a
      // loading block, so a recovery week comes first – not 12 loading weeks in a row (IMPORTANT 12).
      if (i == noRecoveryBefore && noRecoveryBefore > 0 && noRecoveryBefore + carried >= _loadWeeks) run = _loadWeeks;
      run++;
      if (run > _loadWeeks && i < out.length - 1 - taper) {
        out[i] = 'recovery';
        run = 0;
      }
    }
    return out;
  }

  String _lastLoadPhase(List<String> phases, int w) => phases.take(w).lastWhere((p) => p != 'recovery', orElse: () => 'base');

  /// Weekly volume: grow by g toward the ceiling, recovery weeks at a fraction of the
  /// last loading week, taper with a progressive cut.
  ///
  /// The base pre-plan of a far-away event ([preWeeks]) stays at ≤ 85 % of the ceiling, so the
  /// volume still rises in the race-specific block instead of sitting flat for 30 weeks.
  List<double> _curve(int total, List<String> phases, double startV, double ceiling, {double? growth, int preWeeks = 0}) {
    final out = <double>[];
    var last = startV;
    for (var i = 0; i < total; i++) {
      final p = phases[i];
      if (p == 'recovery' || p == 'taper') {
        out.add(last * _restFactor(phases, i));
      } else {
        final c = i < preWeeks ? max(startV, ceiling * 0.85) : ceiling;
        if (i > 0) last = min(c, last * (1 + (growth ?? _growth)));
        out.add(last);
      }
    }
    return out;
  }

  /// Volume of a recovery / taper week relative to the last loading week: recovery
  /// 60–75 % by difficulty, taper progressive (3 weeks 80/65/45 %, 2 weeks 65/45 %,
  /// 1 week 50 %; Bosquet 2007: −41–60 % works best).
  double _restFactor(List<String> phases, int i) {
    if (phases[i] == 'recovery') return _recoveryFactor;
    if (phases[i] != 'taper') return 1;
    final k = i - phases.indexOf('taper');
    final nTaper = phases.where((x) => x == 'taper').length;
    return nTaper >= 3 ? const [0.8, 0.65, 0.45][min(k, 2)] : (nTaper == 2 ? const [0.65, 0.45][min(k, 1)] : 0.5);
  }

  /// Long session of a recovery / taper week relative to the last loading week's: recovery ~80 %;
  /// taper – the longest session comes in the last loading week (marathon / ultra / Ironman ~3
  /// weeks out, HM / 70.3 ~2), then 3-week taper 75 / 60 %, 2-week taper 65 %, race week 45 %
  /// (Pfitzinger; Bosquet 2007: volume −41–60 %, intensity kept).
  double _longRestFactor(List<String> phases, int i) {
    if (phases[i] == 'recovery') return 0.8;
    if (phases[i] != 'taper') return 1;
    final k = i - phases.indexOf('taper');
    final n = phases.where((x) => x == 'taper').length;
    if (k == n - 1) return 0.45;
    return n >= 3 ? const [0.75, 0.6][min(k, 1)] : 0.65;
  }

  double _runStartKm(int perWeek) {
    if (perWeek == 0) return 0;
    if (a.runWeeklyKm != null && a.runWeeklyKm! > 0) return a.runWeeklyKm!;
    // Cold start (weekly km unknown – review 2026-11 M6: an advanced 6-day plan began at 54–55 km with two
    // quality sessions, a slow runner's at 35 km with a 107' long run): a conservative guess – per run the
    // level's usual distance but ≤ 45 min (advanced 50 min) at the easy pace, the week ≤ 30 / 40 km – the
    // plan grows from there (≤ 10 % a week), the first two weeks with a single quality run ([_coldStart]).
    final (per, minutes, most) = switch (level) {
      'advanced' => (9.0, 50, 40.0),
      'intermediate' => (7.0, 45, 30.0),
      _ => (4.5, 45, 20.0),
    };
    final byTime = minutes * 60 / ((pz.easyFast + pz.easySlow) / 2);
    return min(most, min(per, byTime) * perWeek);
  }

  /// No weekly run volume stated: the first weeks start conservatively ([_runStartKm], [_maxQualityRuns]).
  bool get _coldStart => a.runWeeklyKm == null || a.runWeeklyKm! <= 0;

  /// Index of the plan week being generated (0 = the first).
  int _weekIdx = 0;

  int get _lv => switch (level) {
    'advanced' => 2,
    'intermediate' => 1,
    _ => 0,
  };

  /// Volume ceiling (R5, table 1.8) from a (novice, intermediate, advanced) [table] for
  /// the goal; without a goal [start] × [noGoal]. CHALLENGING +15 %, EASY uses the
  /// novice column; never below the athlete's current volume.
  /// ([base]: the volume the training block started with, [PlanCarry] – a re-created plan's ceiling does not grow.)
  double _ceiling(List<double> table, double start, double noGoal, {double? base}) {
    var c = table.isEmpty ? (base ?? start) * noGoal : max(table[_lv], start);
    if (a.difficulty == 'challenging') c *= 1.15;
    if (a.difficulty == 'easy' && table.isNotEmpty) c = max(table[0], start);
    return max(c, start);
  }

  // Triathlon volume ceilings per discipline (weekly run km / bike hours / swim km).
  // Typical age-group plans: sprint ~4–7 h, olympic ~6–10 h, 70.3 ~8–13 h a week, split
  // swim ~20 % · bike ~45–50 % · run ~30–35 % (§6.2). Without them the bike and swim
  // volume stayed at the start value × 1.5 – e.g. a 60-min long ride for an olympic
  // distance whose bike leg alone takes ~80 min.

  /// Run volume ceiling; with a stated current volume also ≤ 1.5 × that volume (at least
  /// +10 km) – a 55 km runner should not be pushed to 100 km/week within one plan.
  double _runCeilingKm(int perWeek) {
    final start = _runStartKm(perWeek);
    final c = _ceiling(spec?.runKm ?? const [], start, 1.35);
    final stated = a.runWeeklyKm != null && a.runWeeklyKm! > 0;
    // (A plan re-created mid-plan: from the volume the training block started with – review 2026-11 adapt-7.)
    final base = _carry?.baseRunKm ?? start;
    return stated ? max(start, min(c, max(base * 1.5, base + 10))) : c;
  }

  // Bike hours / swim km ceilings of the event ([EventSpec.rideH] / [EventSpec.swimKm]).
  double _rideCeilingH(int perWeek) => _ceiling(spec?.rideH ?? const [], _rideStartH(perWeek), 1.5, base: _carry?.baseRideH);

  double _swimCeilingKm(int perWeek) {
    final c = _ceiling(spec?.swimKm ?? const [], _swimStartKm(perWeek), 1.4, base: _carry?.baseSwimKm);
    // Cannot swim 400 m yet: technique and short repeats – about 1–1.5 km a session (§4.4).
    return _swimNovice ? min(c, max(_swimStartKm(perWeek), 1.4 * perWeek)) : c;
  }

  double _rideStartH(int perWeek) {
    if (perWeek == 0) return 0;
    if (a.bikeWeeklyHours != null && a.bikeWeeklyHours! > 0) return a.bikeWeeklyHours!;
    return perWeek *
        switch (level) {
          'advanced' => 1.5,
          'intermediate' => 1.1,
          _ => 0.8,
        };
  }

  double _swimStartKm(int perWeek) {
    if (perWeek == 0) return 0;
    // Cannot swim 400 m continuously: ~800 m sessions (§4.4 beginner 800–1500 m with breaks),
    // whatever the level in the other sports – a fit runner is still a swim beginner.
    if (_swimNovice) return perWeek * 0.8;
    if (a.swimWeeklyKm != null && a.swimWeeklyKm! > 0) return a.swimWeeklyKm!;
    // No swim experience and no test: the level (from the other sports) says little about the
    // swimming – start at the beginner volume.
    final swimmer = profile.experience.contains(Sport.swim) || SwimZones.fromTests(a.swim400Sec, a.swim200Sec) != null;
    if (!swimmer) return perWeek * 1.5;
    return perWeek *
        switch (level) {
          'advanced' => 3.5,
          'intermediate' => 2.5,
          _ => 1.5,
        };
  }

  /// Swim novice (§4.4/§4.5): cannot swim 400 m freestyle without stopping – the athlete's own answer to the setup
  /// question. Gets technique, short repeats with rests, a continuous-swim progression 50 → 400 m and a CSS test
  /// before any CSS set. (A beginner who says they can swim 400 m is no novice even without swim experience or a
  /// test – review 2026-11 RS2: the switch said "yes" and the plan started with 8 × 50 m anyway; they start their
  /// continuous swim at ~400 m instead, [generate].)
  bool get _swimNovice => swimNoviceOf(profile);

  /// [_swimNovice] for a profile (also used to give swim novices a second weekly swim).
  static bool swimNoviceOf(UserProfile p) => !p.athlete.canSwim400;

  /// CSS sets: not for beginners, not with a shoulder problem, swim novices only after the test.
  bool get _swimCssOk => !beginner && !hf.avoidOverhead && (!_swimNovice || _swimTested);

  /// Continuous-swim progression of swim novices ([_swimLadder] stage = loading weeks with swims
  /// so far), whether the CSS test is done, the week is a recovery / taper week, and the long
  /// swim (m) of swimming plans.
  int _swimStage = 0, _swimsPerWeek = 0;
  bool _swimTested = false;
  double _longSwimM = 0;

  /// Long swim of this week on its plateau: 0 plain, 1 race-pace finish, 2 over-distance ([_longSwim]).
  int _longSwimVariant = 0;

  /// Novice ladder (§4.5, practice): (repeat m, repeats) – 50 m → 400 m without stopping over ~8
  /// loading weeks, rest at the wall as needed; then a CSS test (400 m + 200 m time trial).
  static const _swimLadder = [(50, 8), (50, 10), (100, 6), (100, 7), (200, 4), (200, 4), (300, 3), (400, 2)];

  /// The ladder of this plan: a triathlon whose continuous swim cannot be reached in the weeks left
  /// skips the repeated stages (50 m × 10, the second 200 m × 4) – 6 stages instead of 8.
  List<(int, int)> _ladderNow = _swimLadder;

  /// Former swim novice after the CSS test: one easy swim a week is a continuous swim of this many m,
  /// +100 m per loading week towards [_swimTargetM] (§4.5, goal-directed; 0 = not yet / not needed).
  double _contSwimM = 0;

  /// This week's continuous swim is planned already ([_swimSession]).
  bool _contSwimDone = false;

  /// Longest continuous swim the race needs (open water [EventSpec.longSwimM]; triathlon the
  /// longest endurance repeat of the distance: sprint 400 m, olympic / 70.3 800 m, Ironman 1000 m).
  /// Swim novices (review 2026-11 C7): what they will swim in one go on race day, not the longest
  /// repeat – the race's swim leg (sprint 750 m, 70.3 1.9 km), olympic / Ironman ~80 % of it
  /// (1.2 / 3 km); an 800 m continuous swim left a novice 700 m short of a 1.5 km open-water leg.
  double? get _swimTargetM {
    final open = spec?.longSwimM;
    if (open != null || spec?.sport != EventSport.triathlon) return open;
    final leg = (eventDistanceOf(spec!.key)?.legs.firstOrNull ?? 1) * 1000;
    // Long course (review 2026-11 H5): 1.5 km (70.3) / 2 km (Ironman) in one go by the peak – Friel: 1–2 km
    // continuous; the endurance repeats of 800 / 1000 m alone left an Ironman at 800 m.
    if (!_swimNovice && !beginner && _longCourse) return a.eventDistance == 'ironman' ? 2000.0 : 1500.0;
    // Beginners (review r2 IMPORTANT 8) also swim the race's leg in one go before the taper (sprint 750 m).
    if (!_swimNovice && !beginner) return min(spec!.swimRepMax, leg);
    final f = leg <= 750 || (leg - 1900).abs() < 1 ? 1.0 : 0.8;
    // (Never beyond the leg: 750 m rounded up to 800 m.)
    return min(leg, max(min(spec!.swimRepMax, leg), (leg * f / 100).round() * 100.0));
  }

  int _maxQualityRuns(int nRuns, String phase) {
    // Recovery / taper: one shortened quality session with ≥ 3 runs – beginners only
    // run easy in recovery weeks.
    if (phase == 'recovery' && beginner) return 0;
    if (phase == 'recovery') return nRuns >= 3 ? 1 : 0;
    // Taper (§1.7: intensity kept, Bosquet 2007 / Mujika & Padilla 2003): one shortened quality run also with 2
    // runs a week – a triathlete's usual 2 runs left the whole taper easy (review 2026-11 tri-1).
    if (phase == 'taper') return nRuns >= 2 ? 1 : 0;
    // Keep ≥ 75 % of runs easy: ≤ 4 runs → 1 quality session (2 when challenging).
    var q = nRuns <= 4 ? 1 : 2;
    if (nRuns >= 3 && nRuns <= 4 && a.difficulty == 'challenging' && level != 'beginner') q = 2;
    if (nRuns >= 6 && level == 'advanced' && phase == 'build') q = 3;
    if (a.difficulty == 'easy') q = min(q, 1);
    // Joint problems or a heart / blood-pressure condition: at most one quality run.
    if (hf.lowImpactRun || hf.capIntensity) q = min(q, 1);
    // HM / marathon peak: the long run carries race pace – with ≤ 4 runs it is the second quality
    // session (3 runs with MP long run + 2 quality runs left no easy run at all).
    final d = a.eventDistance;
    if (phase == 'peak' && (d == 'm' || d == 'hm') && !beginner && nRuns <= 4) q = min(q, 1);
    // Ultra build / peak with the back-to-back run: long run + back-to-back + one quality run are the
    // ≤ 3 key sessions (review 2026-11, IMPORTANT 8: VO2 + cruise + back-to-back long = 4 in 5 runs).
    if (spec?.backToBack == true && (phase == 'build' || phase == 'peak') && backToBackDay(profile) != null) q = min(q, 1);
    // Cold start (no weekly km stated, M6): one quality run in the first two weeks – the body's tolerance is a guess.
    if (_coldStart && _weekIdx < 2) q = min(q, 1);
    if (nRuns <= 1) q = 0;
    return q;
  }

  /// Quality rides besides the long ride: like running (≥ 75–80 % of sessions easy):
  /// 2–3 rides → 1, ≥ 4 → 2 (3 rides → 2 only for non-beginners on CHALLENGING);
  /// recovery / taper weeks keep one with ≥ 3 rides.
  int _maxQualityRides(int nRides, String phase) {
    if (phase == 'recovery') return nRides >= 3 ? 1 : 0;
    // Taper: one shortened quality ride also with 2 rides a week (race week: openers, [_ride]) – tri-1.
    if (phase == 'taper') return nRides >= 2 ? 1 : 0;
    var q = nRides >= 4 ? 2 : (nRides >= 2 ? 1 : 0);
    if (nRides == 3 && a.difficulty == 'challenging' && !beginner) q = 2;
    if (a.difficulty == 'easy' || beginner || hf.capIntensity) q = min(q, 1);
    return q;
  }

  /// Assigns roles (long / q1 / q2 / technique / easy / nolegs) and spaces the key sessions.
  ///
  /// * H1: never three key days in a row; beginners, intermediates and masters never two
  ///   (a CSS swim set – non-weight-bearing, half a hard session – may sit next to one
  ///   key day, except for masters).
  /// * H3: advanced athletes may go hard on consecutive days only across systems, never
  ///   two key runs (or two key rides) within 48 h.
  /// * H2 (≥ 2 endurance sports): one hard budget across sports – ≤ 4 sessions: 2 · 5–7: 3 ·
  ///   more: 4 points; a quality run / ride costs 1, a long session or a CSS set 0.5. The
  ///   base phase keeps 1 (beginners) or 2 quality sessions.
  Map<int, List<_Slot>> _roles(Map<int, List<Sport>> schedule, String phase, {int week = 0}) {
    final days = schedule.keys.toList()..sort();
    final roles = {for (final d in days) d: schedule[d]!.map((s) => _Slot(s, 'easy')).toList()};
    final key = <int, Sport>{}; // day → sport of its key session
    // Same long day as [deriveSchedule] / [dayMinutesFor] – a stale profile value (a day
    // that is no longer a training day) must not decide the roles.
    final longDay = longDayOf(profile) ?? days.last;

    // The week wraps around: Sunday's long run is followed by Monday.
    int prev(int d) => d == 1 ? 7 : d - 1;
    int next(int d) => d == 7 ? 1 : d + 1;
    int dist(int x, int y) => min((x - y).abs(), 7 - (x - y).abs());
    final strict = beginner || level == 'intermediate' || _masters;
    final longDays = <int>{};

    bool spaced(int d, Sport sport, Map<int, Sport> k, {bool half = false}) {
      if (k.containsKey(d)) return false;
      final p1 = k.containsKey(prev(d)), n1 = k.containsKey(next(d));
      bool qd(int x) => k.containsKey(x) && !longDays.contains(x);
      // A CSS set (non-weight-bearing, half a key session) may sit next to long Z2 sessions – also
      // right before a Saturday + Sunday long block – but never in a chain with a quality session
      // (B7). Masters: only next to one long session (below).
      if (half && !_masters) {
        if (qd(prev(d)) && (n1 || k.containsKey(prev(prev(d))))) return false;
        if (qd(next(d)) && (p1 || k.containsKey(next(next(d))))) return false;
        return true;
      }
      if ((p1 && n1) || (p1 && k.containsKey(prev(prev(d)))) || (n1 && k.containsKey(next(next(d))))) return false;
      // Masters: a CSS set only next to a long (Z2) session, never next to a quality one.
      if (half) return !_masters || (!(p1 && !longDays.contains(prev(d))) && !(n1 && !longDays.contains(next(d))));
      if (strict) return !(p1 || n1);
      return k[prev(d)] != sport && k[next(d)] != sport;
    }

    // Long sessions first (they matter most), the sport on the long day first; quality
    // sessions then have to keep their distance from all of them.
    // Preferred long day, else the latest free day. Two long sessions of different sports
    // may follow each other (long ride Saturday, long run Sunday – both easy); masters keep
    // them apart when the week allows it. Shared with [dayMinutesFor] ([longSessionDays]).
    var longs = <Sport, int>{};
    void setLongs(Map<Sport, int> m) {
      longs = m;
      longDays
        ..clear()
        ..addAll(m.values);
      key.clear();
      for (final d in days) {
        for (final s in roles[d]!) {
          s.role = 'easy';
        }
      }
      for (final e in m.entries) {
        roles[e.value]!.firstWhere((x) => x.sport == e.key).role = 'long';
        key[e.value] = e.key;
      }
    }

    setLongs(_longSessionDays(schedule, longDay, _masters, minutes: _explicitMinutes(profile), rideFirst: _rideFirst(profile)));

    final endurance = schedule.values.expand((v) => v).where((s) => s != Sport.gym).toList();
    final multi = endurance.toSet().length >= 2;
    final n = endurance.length;
    final budget = multi ? (n <= 4 ? 2.0 : (n <= 7 ? 3.0 : 4.0)) : double.infinity;

    // Weeks since the discipline last had a quality session (triathlon rotation, B7).
    final multiBuild = multi && (phase == 'build' || phase == 'peak');
    int waited(Sport s) => min(4, week - (_lastQuality[s] ?? week - 4));

    // Quality days per sport when the sports are filled in [order].
    Map<Sport, List<int>> place(List<Sport> order) {
      final k = {...key};
      var used = multi ? longs.length * 0.5 : 0.0;
      var qualityLeft = multi && phase == 'base' ? (beginner ? 1 : 2) : 99;
      final out = <Sport, List<int>>{};
      for (final sport in order) {
        final sDays = days.where((d) => schedule[d]!.contains(sport)).toList();
        if (sDays.isEmpty) continue;
        final ld = longs[sport]; // no long swim
        final css = sport == Sport.swim;
        // Taper: the quality sessions are short (intensity kept, volume cut – §1.7) and cost half – each discipline with
        // ≥ 2 sessions keeps one (review 2026-11 G2-V6: the ride took the budget, the taper's runs were all easy).
        final cost = css || phase == 'taper' ? 0.5 : 1.0;
        var nQ = switch (sport) {
          Sport.run => _maxQualityRuns(sDays.length, phase),
          Sport.ride => _maxQualityRides(sDays.length, phase),
          // Beginners: technique + easy endurance only (no CSS sets yet); shoulder: no CSS; swim
          // novices only after their CSS test. Swimmers with ≥ 4 swims a week: 2 (§4.4).
          Sport.swim =>
            sDays.length >= 2 && _swimCssOk ? (sDays.length >= 4 && !multi && phase != 'recovery' && phase != 'taper' ? 2 : 1) : 0,
          Sport.gym => 0,
        };
        if (multi) nQ = min(nQ, min(qualityLeft, ((budget - used) / cost + 1e-9).floor()));
        // Candidates: not the long day; never the day right before the long run (H5), nor
        // right after the long session (with > 2 sessions of that sport).
        // (Taper, multisport: no quality ride in a slot too short for one once the taper cuts it – it would be an easy
        // ride with pick-ups and leave the day's run without its quality session, review 2026-11 G2-V6.)
        bool shortRide(int d) =>
            sport == Sport.ride &&
            multi &&
            phase == 'taper' &&
            dayMinutesFor(profile, d) ~/ schedule[d]!.length < 45 &&
            schedule[d]!.length > 1;
        final cand = [
          for (final d in sDays)
            if (d != ld &&
                !(ld != null && d == prev(ld) && sport == Sport.run) &&
                !(ld != null && d == next(ld) && sDays.length > 2) &&
                !shortRide(d))
              d,
        ];
        // The largest set of days that keeps the spacing; ties: far from the long day and on
        // days without a second session (a double day halves the time of each).
        var best = <int>[];
        var bestScore = -1;
        int score(List<int> pick) => pick.fold(0, (x, d) => x + dist(d, ld ?? longDay) * 10 - (schedule[d]!.length > 1 ? 15 : 0));
        void search(int i, List<int> pick, Map<int, Sport> kk) {
          if (pick.length > best.length || (pick.length == best.length && score(pick) > bestScore)) {
            best = pick;
            bestScore = score(pick);
          }
          if (pick.length >= nQ) return;
          for (var j = i; j < cand.length; j++) {
            if (!spaced(cand[j], sport, kk, half: css)) continue;
            // Two quality swims ≥ 48 h apart (review 2026-11 UX-3: tempo set Monday, CSS set Tuesday – the CSS set's
            // "half a key session" may sit next to other sports' key days, not next to another quality swim).
            if (css && kk.entries.any((e) => e.value == Sport.swim && !longDays.contains(e.key) && dist(e.key, cand[j]) <= 1)) continue;
            search(j + 1, [...pick, cand[j]], {...kk, cand[j]: sport});
          }
        }

        if (nQ > 0) search(0, const [], k);
        out[sport] = [...best]..sort((x, y) => dist(y, ld ?? longDay).compareTo(dist(x, ld ?? longDay)));
        for (final d in best) {
          k[d] = sport;
        }
        used += best.length * cost;
        qualityLeft -= best.length;
      }
      return out;
    }

    // Multi-sport priority: the bike (largest share, no impact) first; in the base phase the
    // CSS set before run quality, later run quality before the CSS set. Another order wins
    // only if it fits more quality sessions into the week.
    final preferred =
        !multi
            ? [Sport.run, Sport.ride, Sport.swim]
            : (phase == 'base' || phase == 'recovery'
                ? [Sport.ride, Sport.swim, Sport.run]
                // (Duathlon taper: the run first – two of the race's three legs.)
                : (phase == 'taper' && profile.focus == TrainingFocus.duathlon
                    ? [Sport.run, Sport.ride, Sport.swim]
                    : [Sport.ride, Sport.run, Sport.swim]));
    int count(Map<Sport, List<int>> m) => m.values.fold(0, (x, v) => x + v.length);
    // Build / peak (B7): among the orders that fit the most quality sessions, the one that gives
    // intensity to the disciplines that waited longest – a week with long sessions on Saturday
    // and Sunday leaves room for one full quality session, which then rotates bike → run week by
    // week (each discipline ≥ 1 quality session per 2 weeks) instead of always going to the bike.
    // A discipline that went without intensity last week outweighs an extra session of another.
    final rotate = multiBuild;
    int stale(Map<Sport, List<int>> m) => m.entries.where((e) => e.value.isNotEmpty).fold(0, (x, e) => x + waited(e.key));
    int value(Map<Sport, List<int>> m) =>
        count(m) * 2 + (rotate ? 3 * m.entries.where((e) => e.value.isNotEmpty && waited(e.key) >= 2).length : 0);
    Map<Sport, List<int>> choose() {
      var picks = place(preferred);
      if (multi) {
        for (final o in [
          for (final a in preferred)
            for (final b in preferred)
              for (final c in preferred)
                if (a != b && b != c && a != c) [a, b, c],
        ]) {
          final alt = place(o);
          if (value(alt) > value(picks) || (rotate && value(alt) == value(picks) && stale(alt) > stale(picks))) picks = alt;
        }
      }
      return picks;
    }

    var picks = choose();
    // Masters keep the two long sessions apart – unless that leaves no room for any quality
    // session in a build / peak week (e.g. a 5-day sprint week): then they may follow each other.
    if (_masters && rotate && count(picks) == 0) {
      final together = _longSessionDays(schedule, longDay, false, minutes: _explicitMinutes(profile), rideFirst: _rideFirst(profile));
      if (together.toString() != longs.toString()) {
        setLongs(together);
        picks = choose();
      }
    }
    for (final e in picks.entries) {
      if (e.value.isNotEmpty) _lastQuality[e.key] = week;
    }
    for (final e in picks.entries) {
      for (final (i, d) in e.value.indexed) {
        roles[d]!.firstWhere((x) => x.sport == e.key).role = 'q${i + 1}';
        key[d] = e.key;
      }
    }
    // Ultra (build / peak): the easy run right after (else right before) the long run becomes the
    // back-to-back run – same day as [backToBackDay], which gets the second long day's time.
    final b2b = spec?.backToBack == true && (phase == 'build' || phase == 'peak') ? backToBackDay(profile) : null;
    if (b2b != null) {
      final s = roles[b2b]?.where((x) => x.sport == Sport.run && x.role == 'easy').firstOrNull;
      if (s != null) s.role = 'b2b';
    }
    // Swim: one technique session a week – the first swim without a quality role (with 1–2
    // swims only if there is no quality session at all). A single weekly swim alternates
    // technique and continuous endurance swimming.
    final swimDays = days.where((d) => schedule[d]!.contains(Sport.swim)).toList();
    // The continuous swim (an easy swim, [_swimSession]) needs the swim day with the most time per session, the CSS
    // set (≤ ~35 min) does with half a day (review 2026-11 G2-V4: CSS on a solo 60 min Monday, the continuous swim in
    // half of Wednesday – 900 m for 24 weeks instead of 2000 m). Swapped when the CSS set keeps its spacing there.
    if (_contSwimM > 0 && swimDays.length >= 2) {
      int per(int d) => dayMinutesFor(profile, d) ~/ schedule[d]!.length;
      final q = swimDays.where((d) => roles[d]!.any((x) => x.sport == Sport.swim && x.role.startsWith('q'))).toList();
      final easy = swimDays.where((d) => roles[d]!.any((x) => x.sport == Sport.swim && x.role == 'easy')).toList();
      if (q.length == 1 && easy.isNotEmpty) {
        final qd = q.first;
        final cont = easy.first; // the first easy swim of the week is the continuous one
        final k = {...key}..remove(qd);
        final target = easy.where((d) => per(d) < per(qd)).toList()..sort((x, y) => per(x).compareTo(per(y)));
        if (per(qd) > per(cont)) {
          for (final d in target) {
            if (!spaced(d, Sport.swim, k, half: true)) continue;
            if (k.entries.any((e) => e.value == Sport.swim && !longDays.contains(e.key) && dist(e.key, d) <= 1)) continue;
            final from = roles[qd]!.firstWhere((x) => x.sport == Sport.swim), to = roles[d]!.firstWhere((x) => x.sport == Sport.swim);
            to.role = from.role;
            from.role = 'easy';
            key.remove(qd);
            key[d] = Sport.swim;
            break;
          }
        }
      }
    }
    if (swimDays.isNotEmpty) {
      final slots = [for (final d in swimDays) roles[d]!.firstWhere((x) => x.sport == Sport.swim)];
      final hasQ = slots.any((x) => x.role.startsWith('q'));
      // The technique swim (≤ 60 min anyway) preferably on a double day: the endurance / continuous swim
      // keeps a day of its own (a 1.2 km continuous swim does not fit half of a 60 min day).
      final free =
          [
            for (final d in swimDays)
              if (schedule[d]!.length > 1) roles[d]!.firstWhere((x) => x.sport == Sport.swim),
          ].where((x) => x.role == 'easy').firstOrNull ??
          slots.where((x) => x.role == 'easy').firstOrNull;
      // A single weekly swim is one endurance swim with a drill block ([_swimSession]) – alternating
      // technique / endurance weeks made the swim volume jump ±40 % from week to week.
      if (free != null && (!hasQ || swimDays.length >= 3) && swimDays.length >= 2) free.role = 'technique';
    }
    // Gym: sessions the day before a key endurance session avoid heavy legs (C3).
    for (final d in days) {
      for (final s in roles[d]!) {
        // (Before a run or ride only – a swim's kick barely loads the legs; review 2026-11 GYM-9: a swimmer's
        // only full-body day went "legs easy" every week before the long swim.)
        if (s.sport == Sport.gym && (key[next(d)] == Sport.run || key[next(d)] == Sport.ride)) s.role = 'nolegs';
      }
    }
    return roles;
  }

  // ───────────────────────────── Running ─────────────────────────────

  WorkoutStep _runStep(String kind, String zone, {double? km, int? sec, String note = ''}) {
    final (fast, slow) = pz.range(zone);
    final hr = switch (zone) {
      'E' || 'L' || 'REC' => hz.zone(2),
      'M' => hz.zone(3),
      'T' => hz.zone(4),
      'I' || 'R' => hz.zone(5),
      _ => hz.zone(2),
    };
    final noPace = zone == 'walk' || (beginner && a.raceTimes.isEmpty);
    return WorkoutStep(
      kind: kind,
      distanceM: km == null ? null : (km * 1000).roundToDouble(),
      durationSec: sec,
      zone: zone,
      paceMin: noPace ? null : fast,
      paceMax: noPace ? null : slow,
      // No HR target for walks and short recovery jogs: heart rate lags far behind there.
      hrMin: zone == 'walk' || zone == 'REC' ? null : hr.$1,
      hrMax: zone == 'walk' || zone == 'REC' ? null : hr.$2,
      note: note,
    );
  }

  /// Running km of the week's long run (null without one) – see [runningKm].
  static double? _longKmOf(List<PlannedWorkout> week) {
    final p = week.where((p) => p.sport == Sport.run && p.intensity == 'long').firstOrNull;
    return p == null ? null : runningKm(p);
  }

  double _r1(double v) => (v * 2).round() / 2; // 0.5 km steps
  double _floorHalf(double v) => (v * 2 + 1e-9).floor() / 2; // 0.5 km steps, never above [v]

  /// Long and quality runs (easy runs: [_easyRun]).
  PlannedWorkout _run(
    DateTime day,
    String role,
    String phase,
    double weekKm,
    double longKm,
    int tempoMin,
    int intervalReps,
    int week,
    int capMin,
  ) {
    final dist = a.eventDistance;
    final wu = _runStep('warmup', 'E', km: beginner ? 1.5 : 2, note: l.stepWarmupNote);
    final cd = _runStep('cooldown', 'E', km: beginner ? 1 : 1.5);
    String title, desc, intensity = 'easy';
    var steps = <WorkoutStep>[];
    var isKey = false;

    if (role == 'long') {
      // Fit into the time available that day and ≤ 150 min (marathon: 180 – the 28–32 km
      // long runs of amateur marathon plans take ~3 h; Daniels §1.4 allows 180 for
      // advanced) – longer runs add injury risk faster than aerobic benefit. Planned at
      // the middle of the easy range (the slow end made the long run ~5 % too short).
      // Event cap ([EventSpec.longRunCapMin]): marathon / Ironman 3 h, ultra 4 h (time on feet);
      // beginners ≤ 150 min.
      // Opt-in ([AthleteData.longRunExtend], [_longExtraWeeks]): a long run that does not fit the cap may take
      // this week's extra minutes – run with a walk break every 10 min from the start (Galloway), plain easy.
      final extended =
          phase != 'recovery' &&
          phase != 'taper' &&
          _extendsNow(longKm, capMin: capMin) &&
          (_raceDayNow == null || daysBetween(dayOnly(day), _raceDayNow!) >= longRunExtraLeadDays);
      final maxMin = min(capMin, _longRunMaxMin + (extended ? _longExtraNow : 0));
      if (phase != 'recovery' && phase != 'taper') _longRunLimitKm = max(_longRunLimitKm, maxMin * 60 / _longPace);
      final walk = _walkBreaks || extended;
      // Walk breaks (1 min per 10 min) take their time out of the day too.
      // (An extended run in 0.1 km steps: half-km steps would give away up to 4 of its extra minutes.)
      final fitKm = maxMin * 60 / _longPace * (walk ? 10 / 11 : 1);
      final km = max(4.0, min(_r1(longKm), extended ? (fitKm * 10 + 1e-9).floor() / 10 : _floorHalf(fitKm)));
      isKey = true;
      intensity = 'long';
      // Marathon / HM peak: the goal-pace segment at the end grows per stage (B3) – HM
      // 3 → 5 → 8 km at HM pace (between M and T), marathon 6 → 10 → 13 km at marathon pace;
      // at most 40 / 45 % of the run.
      if (phase == 'peak' && (dist == 'm' || dist == 'hm') && !beginner && _mpLongWeek && !_finishMode && !extended && !_longCutNow) {
        final hm = dist == 'hm';
        final seg = hm ? const [3.0, 5.0, 8.0][_stage] : const [6.0, 10.0, 13.0][_stage];
        // ≤ 25 % of the week at goal pace in the long run (15 % when an MP run follows the same week):
        // pyramidal, not a second threshold week (time in zone, Seiler 2010).
        final mpKm = max(1.0, _r1(min(min(seg, km * (hm ? 0.4 : 0.45)), weekKm * (_qRuns >= 2 ? 0.15 : 0.25))));
        steps = [_runStep('steady', 'E', km: km - mpKm, note: l.stepEasyNote), _racePaceStep(mpKm)];
        title = l.wLongRunMp;
        desc = hm ? l.wLongRunHmpDesc : l.wLongRunMpDesc2;
      } else if (_longVariant == 1 && km >= 12 && !extended) {
        // Progression long run: the last ~25 % (≤ 8 km) at a steady marathon-pace effort.
        final pKm = _r1(min(km * 0.25, 8));
        steps = [_runStep('steady', 'E', km: km - pKm, note: l.stepEasyNote), _runStep('work', 'M', km: pKm, note: l.stepProgressionNote)];
        title = l.wLongRunProgression;
        desc = l.wLongRunProgressionDesc;
      } else {
        steps = [_runStep('steady', 'E', km: km, note: l.stepEasyNote)];
        title = l.planLongRun;
        desc = _longVariant == 2 ? l.wLongRunShortDesc : l.wLongRunDesc;
      }
      if (walk) steps = _withWalkBreaks(steps);
      // Long races (≥ 2.5 h): practise the race fuelling on runs ≥ 90 min (Jeukendrup 2014);
      // ultra build / peak: hilly terrain and power hiking (trail ultras climb).
      final minutes = km * _longPace / 60;
      desc = [
        desc,
        if (extended) l.wLongRunExtendedNote(PlanFeasibility._dur(_longRunMaxMin)) else if (_walkBreaks) l.wWalkBreaksNote,
        if (minutes >= 90 && _expectedRaceSec() >= 150 * 60) l.wFuelPracticeNote,
        if (dist == 'ultra50' && (phase == 'build' || phase == 'peak')) l.wTrailNote,
      ].join('\n');
      return _plan(day, Sport.run, title, desc, intensity, steps, phase, isKey);
    }
    if (!role.startsWith('q')) return _easyRun(day, phase, 5, week, capMin);

    isKey = true;
    final second = role == 'q2';
    // VO2max reps load joints and heart the most: threshold work instead with limitations.
    // Ultra peak: threshold and long runs are specific, VO2max reps are not (Koop 2016).
    final useIntervals =
        (phase == 'build' || phase == 'peak') && level != 'beginner' && !hf.noHardRunning && !(phase == 'peak' && dist == 'ultra50');
    // Duathlon: 5–10 km run legs – peak intervals like a 10 km plan, the build's tempo run grows per stage
    // (review 2026-11, IMPORTANT 4: the same 30 min tempo run for 6 weeks).
    final shortRace = dist == '5k' || dist == '10k' || dist == null || (_du && phase == 'peak');
    final runningRace = dist == '5k' || dist == '10k' || dist == 'hm' || dist == 'm';
    var goalSet = false; // repeats at goal race pace (title follows the shortened workout)
    if (phase == 'taper' && runningRace && !beginner && !_finishMode) {
      // Taper (B5): the race-specific session stays with ~60 % of its peak volume – intensity is
      // what keeps the adaptations while the volume drops (Bosquet 2007; Mujika & Padilla 2003).
      // 5 km 4 × 800 m · 10 km 3 × 1 km · HM 3 × 2 km · marathon 2 × 3 km at goal pace; race
      // week one repeat less (two repeats: shorter ones).
      var (n, rep, rec) = switch (dist) {
        '5k' => (4, 0.8, 120),
        '10k' => (3, 1.0, 120),
        'hm' => (3, 2.0, 90),
        _ => (2, 3.0, 120),
      };
      if (_taperLast) {
        if (n > 2) {
          n--;
        } else {
          rep = max(1.0, _r1(rep * 2 / 3));
        }
      }
      // Small taper weeks: ≤ 20 % of the week's km at goal pace (the long run stays the longest).
      final cap = max(2.0, min(weekKm * 0.2, longKm * 0.5));
      while (n * rep > cap + 1e-9 && rep > 1.0) {
        rep = max(1.0, rep - 1);
      }
      while (n * rep > cap + 1e-9 && n > 2) {
        n--;
      }
      steps = _goalPaceSet(wu, cd, n, rep, rec);
      goalSet = true;
      title = '';
      desc = l.wGoalPaceSetDesc;
      intensity = shortRace ? 'intervals' : 'tempo';
    } else if (phase == 'base' && second && !beginner) {
      // Base, second quality run (B4): a progression run – aerobic strength at M effort, not a
      // second VO2max stimulus (pyramidal base: Z1 > Z2 > Z3).
      // About the size of an easy run (≤ 20 % of the week, ≤ 70 % of the long run); the M part
      // 15–25 min, ≤ 40 % of the run.
      final total = max(6.0, min(longKm * 0.7, weekKm * 0.2));
      final mKm = max(1.0, _r1(min(tempoMin.clamp(15, 25) * 60 / pz.marathon, total * 0.4)));
      steps = [
        _runStep('warmup', 'E', km: max(2.0, _r1(total - mKm - 1)), note: l.stepEasyNote),
        _runStep('work', 'M', km: mKm, note: l.stepProgressionNote),
        _runStep('cooldown', 'E', km: 1),
      ];
      title = l.wProgressionRun;
      desc = l.wProgressionRunDesc;
      intensity = 'tempo';
    } else if (phase == 'base' || phase == 'recovery' || phase == 'taper' || beginner) {
      if (phase == 'base' && !second && level != 'beginner' && week.isOdd) {
        // Tempo appears in base for non-beginners (pyramidal distribution); the I-pace fartlek
        // only every other week.
        final t = min<int>((tempoMin / 5).round() * 5, 20);
        steps = [wu, _runStep('work', 'T', sec: t * 60, note: l.stepTempoNote), cd];
        title = l.planRunTempo;
        desc = l.wTempoDesc;
        intensity = 'tempo';
      } else {
        // Fartlek / strides: easy run with short pick-ups.
        // Beginners progress over their loading weeks of continuous running (review IMPORTANT 4: the
        // same 8 × 45 s for 9 weeks): 5 → 8 pick-ups, then 45 → 90 s each. The first two weeks after
        // run/walk stay at threshold effort – no VO2max pick-ups straight off the walk breaks (IMPORTANT 18).
        final lw = _postRunWalk ?? _loadWeek;
        final rest = phase == 'taper' || phase == 'recovery';
        final reps = rest ? 4 : (beginner ? 5 + min(3, lw ~/ 2) : 6 + week % 3);
        final int sec = beginner ? (rest ? 45 : 45 + 15 * min(3, max(0, (lw - 6) ~/ 2))) : 60;
        // Beginners without race times (review 2026-11 L6): the first four loading weeks at a controlled
        // threshold effort (RPE 6–7, HR zone 4) – no VO2max pick-ups from week 1 without any pace or HR data.
        final novice = beginner && a.raceTimes.isEmpty && lw < 4;
        final soft = hf.noHardRunning || (_postRunWalk != null && _postRunWalk! < 2) || novice;
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_runStep('work', soft ? 'T' : 'I', sec: sec, note: novice ? l.stepFartlekSoftNote : l.stepFartlekNote));
          steps.add(_runStep('recovery', 'REC', sec: 90));
        }
        steps.add(cd);
        title = l.wFartlek;
        desc = l.wFartlekDesc;
        intensity = 'tempo';
      }
    } else if (phase == 'peak' && (dist == '5k' || dist == '10k') && !second && !hf.capIntensity && !_finishMode) {
      // 5 / 10 km peak (B6): one goal-pace set a week, longer repeats per stage – 10 km
      // 5 × 1 km → 4 × 1.5 km → 3 × 2 km, 5 km 6 × 800 m → 5 × 1 km → 3 × 1.6 km; ≤ 15 % of the
      // weekly km (≤ 8 km), at least 2 repeats.
      final sets = dist == '5k' ? const [(6, 0.8, 120), (5, 1.0, 120), (3, 1.6, 150)] : const [(5, 1.0, 90), (4, 1.5, 120), (3, 2.0, 150)];
      final (n0, rep, rec) = sets[_stage];
      final cap = max(3.0, min(weekKm * 0.15, 8.0));
      steps = _goalPaceSet(wu, cd, max(2, min(n0, (cap / rep + 1e-9).floor())), rep, rec);
      goalSet = true;
      title = '';
      desc = l.wGoalPaceSetDesc;
      intensity = 'intervals';
    } else if (phase == 'peak' && dist == 'm' && second && !_finishMode) {
      // Marathon-pace run, growing over the peak (B3): 70 → 85 → 100 % of min(20 % weekly km, 14 km).
      final mp = max(4.0, _r1(min(weekKm * 0.2, 14) * const [0.7, 0.85, 1.0][_stage]));
      steps = [wu, _mpStep(mp), cd];
      title = l.wMpRun;
      desc = l.wMpRunDesc;
      intensity = 'tempo';
    } else if (dist == 'ultra50' && (phase == 'build' || phase == 'peak') && !hf.noHardRunning && _loadWeek.isEven) {
      // Ultra build / peak (review 2026-11, IMPORTANT 8): every other week hill repeats instead of the
      // threshold run – the climbing strength trail ultras need (Koop 2016): 6 × 60 s → 8 × 60 s →
      // 8 × 90 s uphill at a hard effort, jog / walk down. No pace target (the gradient sets it).
      final (n, sec) = const [(6, 60), (8, 60), (8, 90)][_stage];
      WorkoutStep hill() {
        final s = _runStep('work', 'I', sec: sec, note: l.stepHillNote);
        return WorkoutStep(kind: 'work', durationSec: sec, zone: 'I', hrMin: s.hrMin, hrMax: s.hrMax, note: s.note);
      }

      steps = [
        wu,
        for (var i = 0; i < n; i++) ...[hill(), if (i < n - 1) _runStep('recovery', 'REC', sec: sec * 2, note: l.stepHillDownNote)],
        cd,
      ];
      title = l.wHillReps(n, sec);
      desc = l.wHillRepsDesc;
      intensity = 'intervals';
    } else if (useIntervals &&
        (second ? (!shortRace || phase == 'peak') : shortRace && !(phase == 'build' && _qRuns == 1 && _loadWeek.isOdd))) {
      // VO2max intervals (I), volume ≤ min(8 % weekly km, 10 km). A 5 / 10 km plan with one
      // quality run a week alternates intervals and threshold in the build phase.
      // Once the cap binds, the repeats get longer per stage (800 → 1000 → 1200 m) instead of
      // staying at the same session for weeks (B3).
      // Short sessions: when fewer than 3 long repeats fit the time, use shorter repeats
      // (600 / 400 m, more of them) instead of 2 × 800 m.
      List<WorkoutStep> build(double repM, int reps) {
        final maxReps = max(3, (min(weekKm * 0.08, 10) * 1000 / repM).floor());
        final n = min(reps, maxReps);
        final repSec = (repM / 1000 * pz.interval).round();
        return [
          wu,
          for (var i = 0; i < n; i++) ...[
            _runStep('work', 'I', km: repM / 1000, note: l.stepIntervalNote),
            if (i < n - 1) _runStep('recovery', 'REC', sec: max(60, (repSec * 0.8 / 15).round() * 15)),
          ],
          cd,
        ];
      }

      final baseRep = level == 'advanced' ? 1000.0 : 800.0;
      // The repeats get longer once the volume cap binds – or once the repeat count reached its level
      // maximum (advanced 8 × 1000 m stayed for 5 weeks: the cap of 10 km never bound; IMPORTANT 4).
      final binds = intervalReps > (min(weekKm * 0.08, 10) * 1000 / baseRep).floor() || intervalReps >= (level == 'advanced' ? 8 : 6);
      final repM = binds ? min(1200.0, baseRep + 200.0 * _stage) : baseRep;
      steps = build(repM, max(3, (intervalReps * baseRep / repM).round()));
      for (final shorter in [600.0, 400.0]) {
        if (shorter >= repM || _fitToTime(steps, capMin * 60, Sport.run).where((s) => s.isWork).length >= 3) break;
        steps = build(shorter, (intervalReps * baseRep / shorter).round());
      }
      title = '';
      desc = l.wIntervalsDesc;
      intensity = 'intervals';
    } else {
      // Threshold: cruise intervals once tempo ≥ 20 min (T ≤ 10 % weekly km). When the 10 % cap
      // binds, the structure progresses per stage instead of the volume (B3): 1.6 km repeats →
      // 2.4 km → 3.2 km (or one continuous tempo when fewer than 2 fit).
      final byTime = tempoMin * 60 / pz.threshold;
      final tKm = min(weekKm * 0.10, byTime);
      // … also once the T time reached its 40 min (6 × 1.6 km stayed for 8 weeks when the time, not the
      // 10 %, was the limit).
      final repKm = weekKm * 0.10 <= byTime || tempoMin >= 40 ? const [1.6, 2.4, 3.2][_stage] : 1.6;
      final cruise = tempoMin >= 20 && tKm >= 4.5 && (tKm / repKm + 1e-9).floor() >= 2;
      if (_du && phase == 'build' && _stage > 0 && !hf.capIntensity) {
        // Duathlon build, later stages: repeats at the 10 km race pace (the first run leg) – 4 × 1 km →
        // 3 × 1.5 km, the run's time unchanged (review 2026-11, IMPORTANT 4: the same 30 min tempo run
        // for 6 weeks; a 30 min multisport run cannot hold more threshold time).
        final (reps, km, rec) = _stage == 1 ? (4, 1.0, 90) : (3, 1.5, 120);
        final pace = beginner && a.raceTimes.isEmpty ? null : (Vdot.raceTime(pz.vdot, 10000) / 10).round();
        steps = [
          wu,
          for (var i = 0; i < reps; i++) ...[
            WorkoutStep(
              kind: 'work',
              distanceM: km * 1000,
              zone: 'M',
              paceMin: pace == null ? null : pace - 3,
              paceMax: pace == null ? null : pace + 3,
              hrMin: hz.zone(4).$1,
              hrMax: hz.zone(5).$2,
              note: l.stepGoalPaceNote,
            ),
            if (i < reps - 1) _runStep('recovery', 'REC', sec: rec),
          ],
          cd,
        ];
        // A repeat that does not fit is dropped – the time it leaves goes to the warm-up, so the run keeps
        // the volume of the tempo run it replaces (no dip in the week's run km).
        steps = _fitToTime(steps, capMin * 60, Sport.run);
        final spare = capMin * 60 - steps.fold(0, (x, s) => x + _stepSec(s, Sport.run));
        if (spare >= 120 && steps.first.kind == 'warmup' && steps.first.distanceM != null) {
          final km = steps.first.distanceM! / 1000 + spare / _longPace;
          steps = [_runStep('warmup', 'E', km: (km * 10).floor() / 10, note: l.stepWarmupNote), ...steps.skip(1)];
        }
        goalSet = true;
        title = '';
        desc = l.wGoalPaceSetDesc;
      } else if (cruise) {
        final reps = repKm == 1.6 ? max(3, (tKm / 1.6).floor()) : (tKm / repKm + 1e-9).floor();
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_runStep('work', 'T', km: repKm, note: l.stepTempoNote));
          if (i < reps - 1) steps.add(_runStep('recovery', 'REC', sec: repKm <= 1.6 ? 60 : (repKm <= 2.4 ? 90 : 120)));
        }
        steps.add(cd);
        title = '';
        desc = l.wCruiseDesc;
      } else {
        // Continuous tempo: also ≤ 10 % of the weekly km (Daniels §1.4), at least the classic
        // 20 min, at most 30 min – 30 min at T was 13–23 % of a 28–40 km week.
        // In 5-min steps, rounded down (a "27 min" tempo reads like a typo; ≤ 10 % stays ≤ 10 %).
        final raw = min(min(tempoMin, 30) * 60, max(20 * 60, (tKm * pz.threshold / 60).round() * 60));
        final sec = max(min(raw, 20 * 60), raw ~/ 300 * 300);
        steps = [wu, _runStep('work', 'T', sec: sec, note: l.stepTempoNote), cd];
        title = l.planRunTempo;
        desc = l.wTempoDesc;
      }
      intensity = 'tempo';
    }
    steps = _fitToTime(steps, capMin * 60, Sport.run);
    // Titles with a repeat count must match the (possibly shortened) workout.
    final reps = steps.where((s) => s.isWork).length;
    final firstWork = steps.where((s) => s.isWork).firstOrNull;
    if (goalSet) {
      title = l.wGoalPaceSet(reps, _km((firstWork?.distanceM ?? 1000) / 1000));
    } else if (desc == l.wHillRepsDesc) {
      title = l.wHillReps(reps, firstWork?.durationSec ?? 60);
    } else if (intensity == 'intervals') {
      title = l.wIntervals(reps, (firstWork?.distanceM ?? 800).round());
    }
    if (desc == l.wCruiseDesc) {
      final km = (firstWork?.distanceM ?? 1600) / 1000;
      title = (km - 1.6).abs() < 0.05 ? l.wCruise(reps) : l.wCruiseKm(reps, _km(km));
    }
    return _plan(day, Sport.run, title, desc, intensity, steps, phase, isKey);
  }

  /// Splits the easy part of a long run into 10-min blocks with a 1 min walk between them
  /// (Galloway run/walk for a former run/walker): the running km stay the same.
  List<WorkoutStep> _withWalkBreaks(List<WorkoutStep> steps) {
    final first = steps.firstOrNull;
    if (first == null || first.zone != 'E' || first.distanceM == null) return steps;
    final block = (600 / _longPace * 10).round() * 100.0; // m in 10 min, 100 m steps
    var left = first.distanceM!;
    final out = <WorkoutStep>[];
    while (left > 0) {
      final m = left - block < block * 0.3 ? left : block;
      out.add(_runStep('steady', 'E', km: m / 1000, note: first.note));
      left -= m;
      if (left > 0) out.add(_runStep('recovery', 'walk', sec: 60));
    }
    return [...out, ...steps.skip(1)];
  }

  /// [v] km for a title: whole numbers without decimals, else one decimal (German comma).
  String _km(double v) {
    final s = (v - v.roundToDouble()).abs() < 0.05 ? '${v.round()}' : v.toStringAsFixed(1);
    return l.localeName.startsWith('de') ? s.replaceAll('.', ',') : s;
  }

  /// Warm-up, [n] × [repKm] at goal race pace with [recSec] jog breaks, cool-down.
  List<WorkoutStep> _goalPaceSet(WorkoutStep wu, WorkoutStep cd, int n, double repKm, int recSec) => [
    wu,
    for (var i = 0; i < n; i++) ...[_racePaceStep(repKm), if (i < n - 1) _runStep('recovery', 'REC', sec: recSec)],
    cd,
  ];

  /// Work step at the goal race pace of the running event ([_goalPace], zone 'M' – the race-pace
  /// convention [GoalForecast.retarget] follows): marathon ±5 s/km ([_mpStep]), others ±3 s/km
  /// with the HR range of the race (HM zone 3–4, 5 / 10 km zone 4–5).
  WorkoutStep _racePaceStep(double km) {
    final dist = a.eventDistance;
    if (dist == 'm') return _mpStep(km);
    final hm = dist == 'hm';
    final pace = beginner && a.raceTimes.isEmpty ? null : _goalPace();
    // HR of the race's own zone: HM zone 3–4, 10 km zone 4, 5 km zone 5 (87–100 % HRmax for every
    // 5 / 10 km rep was too wide to guide anything).
    final (hrLo, hrHi) = switch (dist) {
      'hm' => (hz.zone(3).$1, hz.zone(4).$2),
      '10k' => hz.zone(4),
      _ => hz.zone(5),
    };
    return WorkoutStep(
      kind: 'work',
      distanceM: (km * 1000).roundToDouble(),
      zone: 'M',
      paceMin: pace == null ? null : pace - 3,
      paceMax: pace == null ? null : pace + 3,
      hrMin: hrLo,
      hrMax: hrHi,
      note: hm ? l.stepHmpNote : l.stepGoalPaceNote,
    );
  }

  /// Easy run of [km] (capped by the time available); some get strides (base / build / peak –
  /// neuromuscular speed is kept up to the taper, B6).
  PlannedWorkout _easyRun(DateTime day, String phase, double km, int week, int capMin) {
    // Strides (20 s + 60 s walk each) come out of the day's time too – easy run + strides made 65' on a
    // 60' day.
    var strides =
        (phase == 'base' || phase == 'build' || phase == 'peak') && !beginner && !hf.noHardRunning && day.weekday.isEven
            ? 4 + min(4, week ~/ 2)
            // (A taper week without a quality run: strides on its first easy run – [_taperTouchDue].)
            : (!beginner && !hf.noHardRunning && _taperTouchDue(Sport.run, phase, _qRuns) ? 4 : 0);
    while (strides > 0 && capMin * 60 - strides * 80 < 3 * pz.easySlow) {
      strides = strides > 4 ? strides - 1 : 0;
    }
    final k = max(3.0, min(_r1(km), _floorHalf((capMin * 60 - strides * 80) / pz.easySlow)));
    final steps = [_runStep('steady', 'E', km: k, note: l.stepEasyNote)];
    String title, desc;
    if (strides > 0) {
      for (var i = 0; i < strides; i++) {
        steps.add(_runStep('work', 'R', sec: 20, note: l.stepStrideNote));
        steps.add(_runStep('recovery', 'walk', sec: 60));
      }
      title = l.wEasyStrides;
      desc = l.wEasyStridesDesc;
    } else {
      title = phase == 'recovery' ? l.wRecoveryRun : l.planEasyRun;
      desc = l.wEasyDesc;
    }
    return _plan(day, Sport.run, title, desc, 'easy', steps, phase, false);
  }

  /// The continuation of a replaced plan ([PlanCarry]) – only for the plan that starts on its day (the plan
  /// review's rebuild from [AthleteData.planStart] too; a preview from another day starts fresh).
  PlanCarry? get _carry {
    final c = a.planCarry;
    return c != null && planStartFor(profile, c.start) == _start ? c : null;
  }

  /// Stage ([_runWalkTable] index) of a regular run/walk session [p] – its run blocks, walk breaks and repeats –
  /// or null (no run/walk session, a long run/walk, a shortened taper session).
  static int? runWalkStageOf(PlannedWorkout p) {
    if (p.sport != Sport.run || p.intensity != 'easy' || p.steps.isEmpty || p.steps.first.zone != 'walk') return null;
    final work = p.steps.where((s) => s.kind == 'work' && s.zone != 'walk').toList();
    final walks = p.steps.where((s) => s.kind == 'recovery' && s.zone == 'walk').toList();
    if (work.isEmpty) return null;
    final run = work.first.durationSec ?? 0;
    if (work.any((s) => s.durationSec != run)) return null;
    final walk = walks.firstOrNull?.durationSec ?? 0;
    for (var i = 0; i < _runWalkTable.length; i++) {
      final (r, w, n) = _runWalkTable[i];
      if (r == run && n == work.length && (n == 1 || w == walk)) return i;
    }
    return null;
  }

  /// Run/walk stages before continuous running takes over ([runWalkStageOf] past the last: the ladder is done).
  static int get runWalkStages => _runWalkTable.length;

  /// Main set (s, run blocks and walk breaks) of a long run/walk [p] ([_longRunWalk]), or 0.
  static int runWalkMainSec(PlannedWorkout p) {
    if (p.sport != Sport.run || p.intensity != 'long' || p.steps.isEmpty || p.steps.first.zone != 'walk') return 0;
    return p.steps.where((s) => s.kind == 'work' || s.kind == 'recovery').fold(0, (t, s) => t + (s.durationSec ?? 0));
  }

  /// Couch-to-5K style run/walk progression (beginners who cannot run 30 min).
  /// Couch-to-5K style run/walk stages: (run s, walk s, repeats), one stage per week
  /// (§1.10), ending with 30 min continuous running. Whole minutes only, so the title
  /// ("8 × 1 min") always matches the steps.
  static const _runWalkTable = [
    (60, 90, 8),
    (60, 60, 10),
    (120, 120, 5),
    (180, 90, 5),
    (300, 180, 3),
    (480, 300, 2),
    (600, 120, 2),
    (720, 120, 2),
    (1200, 0, 1),
    (1500, 0, 1),
    (1800, 0, 1),
  ];

  /// Race-day run/walk rhythm from the last stage: the stage's run blocks (1–10 min),
  /// with 1 min walk breaks.
  static int _raceRunMin(int stage) => (_runWalkTable[min(stage, _runWalkTable.length - 1)].$1 ~/ 60).clamp(1, 10);

  /// Run off the bike (brick, §6.3): the first 5 min easy to find the rhythm, then at
  /// steady race feel. Part of the long-ride day's key session, not an extra key session.
  /// [first]: the duathlon's first run before the ride (run – bike – run).
  ///
  /// The steady part runs at the race's run pace off the bike, not the stand-alone marathon pace
  /// (review 2026-11 C8: 50 min at 4:18–4:28 /km for a 3:05 marathoner in an Ironman plan): the
  /// stand-alone pace of the run leg × [GoalModel.runOffBikeFactor] (Ironman marathon × 1.25, 70.3
  /// HM × 1.12, olympic 10 km × 1.08; duathlon's first run: its 10 km × 1.02), ±5 s/km.
  PlannedWorkout _brickRun(DateTime day, String phase, int minutes, {bool first = false}) => _brickRun0(
    day,
    phase,
    minutes,
    first: first,
  ).copyWith(durationMin: minutes); // the time its title names (a 10 min run is no "15 min" session)

  PlannedWorkout _brickRun0(DateTime day, String phase, int minutes, {bool first = false}) {
    // Beginners (review 2026-11 L6: sprint beginners at marathon-pace effort off the bike): easy, RPE 4–5 – the
    // brick teaches the legs the change, the race pace comes with experience.
    final work =
        beginner
            ? _runStep('work', 'E', sec: (minutes - min<int>(5, minutes ~/ 2)) * 60, note: l.stepBrickEasyNote)
            : _runStep('work', 'M', sec: (minutes - min<int>(5, minutes ~/ 2)) * 60, note: l.stepBrickNote);
    final pace = beginner || work.paceMin == null ? null : _brickPace(first: first);
    return _plan(
      day,
      Sport.run,
      first ? l.wDuRunFirst(minutes) : l.wBrickRun(minutes),
      first ? l.wDuRunFirstDesc : l.wBrickRunDesc,
      'moderate',
      [
        _runStep('steady', 'E', sec: min<int>(5, minutes ~/ 2) * 60, note: l.stepBrickStartNote),
        pace == null
            ? work
            : WorkoutStep(
              kind: 'work',
              durationSec: work.durationSec,
              zone: 'M',
              paceMin: pace - 5,
              paceMax: pace + 5,
              hrMin: work.hrMin,
              hrMax: work.hrMax,
              note: work.note,
            ),
      ],
      phase,
      false,
    );
  }

  /// Race run pace (s/km) off the bike for [_brickRun]; null without a multisport race model.
  int? _brickPace({bool first = false}) {
    final legs = eventDistanceOf(a.eventDistance)?.legs ?? const <double>[];
    if (!(_tri || _du) || legs.length != 3) return null;
    final km = first ? legs[0] : legs[2];
    final f = first ? 1.02 : GoalModel.runOffBikeFactor(a.eventDistance);
    return (Vdot.raceTime(pz.vdot, km * 1000) / km * f).round();
  }

  /// Ultra back-to-back run: an easy medium-long run of [km] on the day after the long run.
  PlannedWorkout _backToBack(DateTime day, String phase, double km, int capMin) {
    final k = max(5.0, min(_r1(km), _floorHalf(capMin * 60 / _longPace)));
    return _plan(
      day,
      Sport.run,
      l.wBackToBack,
      // Trail ultras climb: the back-to-back run on hilly terrain too (review 2026-11, IMPORTANT 8).
      [l.wBackToBackDesc, if (a.eventDistance == 'ultra50') l.wTrailNote].join('\n'),
      'easy',
      [_runStep('steady', 'E', km: k, note: l.stepEasyNote)],
      phase,
      false,
    );
  }

  /// Run/walk session of [stage] (beginners who cannot run 30 min yet).
  /// [maxReps]: fewer blocks than the stage's (the week's running grows ≤ 30 %, [generate]).
  PlannedWorkout _runWalk(DateTime day, int stage, String phase, {int? maxReps}) {
    var (run, walk, reps) = _runWalkTable[min(stage, _runWalkTable.length - 1)];
    if (maxReps != null) reps = max(1, min(reps, maxReps));
    // Taper: the same rhythm, less of it (race week ~55 %, earlier taper weeks ~75 %) – the stage
    // stays, the volume drops like everyone else's (Bosquet 2007).
    if (phase == 'taper') {
      final f = _taperLast ? 0.45 : 0.7;
      if (reps > 1) {
        reps = max(1, (reps * f).round());
      } else {
        run = max(60, (run * f / 60).round() * 60);
      }
    }
    final steps = <WorkoutStep>[_runStep('warmup', 'walk', sec: phase == 'taper' ? 180 : 300, note: l.stepBriskWalk)];
    for (var i = 0; i < reps; i++) {
      steps.add(_runStep('work', 'E', sec: run, note: l.stepTalkPace));
      if (walk > 0 && i < reps - 1) steps.add(_runStep('recovery', 'walk', sec: walk));
    }
    steps.add(_runStep('cooldown', 'walk', sec: phase == 'taper' ? 180 : 300));
    // One block without walk breaks is a continuous run ("Laufen/Gehen 1 × 30 min" read oddly).
    final title = reps == 1 && walk == 0 ? l.wRunContinuous(run ~/ 60) : l.wRunWalk(reps, run ~/ 60);
    return _plan(day, Sport.run, title, l.wRunWalkDesc, 'easy', steps, phase, false);
  }

  /// Long run/walk on the long day of a run/walker with a distance goal (Galloway): the stage's
  /// rhythm (continuous stages: 10 min run / 1 min walk), repeated to about [targetSec] of main set,
  /// with the running ≤ [maxRunSec] (2 × the longest regular session's), never shorter than the
  /// regular session nor (loading weeks) than last week's [prevSec] main set; fits [capMin].
  /// Returns the workout and its main set (s).
  /// [single]: the week's only run (the description does not refer to other runs). [onlyRun]: really the only one –
  /// its running grows in whole blocks rounded down, a stage that cannot waits ([prevRunSec]).
  (PlannedWorkout, int) _longRunWalk(
    DateTime day,
    int stage,
    String phase,
    int targetSec,
    int capMin,
    int maxRunSec,
    int prevSec, {
    bool single = false,
    int? prevRunSec,
    bool onlyRun = false,
  }) {
    var (run, walk, reps0) = _runWalkTable[min(stage, _runWalkTable.length - 1)];
    if (walk == 0) {
      // (Whole 10 min blocks covering the stage's continuous run – 2 × 10 min was shorter than the regular 25 min run.)
      reps0 = max(1, (run / 600).ceil());
      run = min(run, 600);
      walk = 60;
    }
    // The week's only run: a stage whose whole blocks cannot hold last week's running within its growth (+10 % / +5 min)
    // – 6 × 3 min, then 2 × 8 min = less, 3 × 8 min = +6 min (review 2026-11 G2-V9) – waits: the stage before it this
    // week. (Next to other runs the long run/walk keeps their stage – it stays the longest of them.)
    if (prevRunSec != null && onlyRun && stage > 0) {
      final growth = max((prevRunSec * 1.1).round(), prevRunSec + 300);
      if (max(reps0, (prevRunSec / run).ceil()) * run > growth) {
        return _longRunWalk(
          day,
          stage - 1,
          phase,
          targetSec,
          capMin,
          maxRunSec,
          prevSec,
          single: single,
          prevRunSec: prevRunSec,
          onlyRun: true,
        );
      }
    }
    int main(int n) => n * (run + walk) - walk;
    final byTarget = ((targetSec + walk) / (run + walk)).round();
    final keep = ((prevSec - 0.03 * prevSec + walk) / (run + walk)).ceil();
    var reps = max(reps0, min(byTarget, max(maxRunSec ~/ run, keep)));
    // [prevRunSec]: last loading week's running – this week's ≤ +10 % / +5 min (in whole blocks), also when
    // the stage's shorter walk breaks would keep last week's main set (tri-2), and never less (a longer block of the
    // next stage must not shorten it).
    if (prevRunSec != null) {
      // (Whole blocks within the growth – rounding to the nearest made 18 → 24 min, review 2026-11 G2-V9.)
      final growth = max((prevRunSec * 1.1).round(), prevRunSec + 300);
      final upper = onlyRun ? growth ~/ run : ((growth + run / 2) / run).floor();
      reps = max(reps0, min(max(reps, min((prevRunSec / run).ceil(), upper)), upper));
    }
    final wu = phase == 'taper' ? 180 : 300;
    while (reps > reps0 && main(reps) + 2 * wu > capMin * 60) {
      reps--;
    }
    final steps = <WorkoutStep>[_runStep('warmup', 'walk', sec: wu, note: l.stepBriskWalk)];
    for (var i = 0; i < reps; i++) {
      steps.add(_runStep('work', 'E', sec: run, note: l.stepTalkPace));
      if (i < reps - 1) steps.add(_runStep('recovery', 'walk', sec: walk));
    }
    steps.add(_runStep('cooldown', 'walk', sec: wu));
    final w = _plan(
      day,
      Sport.run,
      l.wRunWalk(reps, run ~/ 60),
      single ? l.wLongRunWalkDescSingle : l.wLongRunWalkDesc,
      'long',
      steps,
      phase,
      true,
    );
    return (w, main(reps));
  }

  // ───────────────────────────── Cycling ─────────────────────────────

  WorkoutStep _rideStep(String kind, String zone, int sec, {String note = ''}) {
    final p = ftp == null ? null : PowerZones(ftp!).range(zone);
    final hzN = switch (zone) {
      'Z1' => 1,
      'Z2' => 2,
      'Z3' || 'SS' => 3,
      'Z4' => 4,
      _ => 5,
    };
    final hr = hz.zone(hzN);
    return WorkoutStep(
      kind: kind,
      durationSec: sec,
      zone: zone,
      powerMin: p?.$1,
      powerMax: p?.$2,
      hrMin: hr.$1 - 5,
      hrMax: hr.$2 - 5,
      note: note,
    );
  }

  /// Riding speed (km/h) in power zone [zone]: from the FTP ([GoalModel.bikeKmh], flat course incl. turns and
  /// wind), else from the level's long-race speed of [GoalModel.predict] (25 / 29 / 33 km/h × 0.93 at ~72 % FTP),
  /// scaled by the cube root of the power share – the same speeds the race forecast uses.
  double _rideKmh(String zone) {
    final frac = switch (zone) {
      'Z1' => 0.50,
      'Z3' => 0.83,
      'SS' => 0.91,
      'Z4' => 0.98,
      'Z5' || 'Z6' || 'Z7' => 1.13,
      _ => 0.65,
    };
    if (ftp != null) return GoalModel.bikeKmh(ftp!, profile.weightKg, level, frac);
    final race = switch (level) {
      'advanced' => 33.0,
      'intermediate' => 29.0,
      _ => 25.0,
    };
    return race * 0.93 * pow(frac / 0.72, 1 / 3);
  }

  /// Long ride: with 2 rides a week ~60 % of the bike hours, 3 rides 50 %, more 42 % (a
  /// triathlete's 2-ride week is one long ride + one quality ride); at least 60 min
  /// (45 min in recovery / taper weeks, so the deload still shows when the volume is small).
  ///
  /// The race's long ride ([EventSpec.longRideMin]: 70.3 3 h, Ironman 5 h, 100 / 160 km 3 / 4 h)
  /// may take up to 60 % of the bike hours (Friel; long-course plans), never more than the
  /// event's cap ([EventSpec.longRideCapMin]).
  int _longRideMin(double weekH, int perWeek, {bool rest = false}) {
    var share = perWeek <= 2 ? 0.6 : (perWeek == 3 ? 0.5 : 0.42);
    final target = spec?.longRideMin;
    if (target != null && weekH > 0) share = max(share, min(0.6, target / (weekH * 60)));
    // 5-min steps: 15-min steps kept a slowly growing long ride flat for 4 weeks.
    final m = max(rest ? 45 : 60, ((weekH * share) * 60 / 5).round() * 5);
    if (spec != null) return min(m, spec!.longRideCapMin);
    // Without an event the long ride is capped by level – beginners 3 h, intermediate 4 h, advanced 5 h (review 2026-11
    // G2-V10: 17.5 bike hours stated by a beginner grew a 7:50 h long ride); a longer recent ride raises the cap to it.
    final longest = a.longestRideKm == null ? 0 : (a.longestRideKm! / _rideKmh('Z2') * 60 / 5).floor() * 5;
    return min(m, max(longest, beginner ? 180 : (level == 'advanced' ? 300 : 240)));
  }

  /// [loadWeek] counts the loading weeks so far: quality rides progress only in those.
  /// [longMin]: the long ride's planned minutes this week (else from the bike hours).
  PlannedWorkout _ride(
    DateTime day,
    String role,
    String phase,
    double weekH,
    int perWeek,
    int loadWeek,
    int capMin,
    int nQ, {
    int? longMin,
  }) {
    final rest = phase == 'recovery' || phase == 'taper';
    final wu = _rideStep('warmup', 'Z2', 600);
    final cd = _rideStep('cooldown', 'Z1', 600);
    String title, desc, intensity = 'easy';
    List<WorkoutStep> steps;
    var isKey = false;
    final longRide = longMin ?? _longRideMin(weekH, perWeek, rest: rest);
    final rideEvent = spec?.sport == EventSport.ride;
    if (role == 'long') {
      if (!rest) _longRideLimitMin = max(_longRideLimitMin, capMin);
      final m = min(capMin, longRide);
      steps = [_rideStep('steady', 'Z2', m * 60, note: l.stepZ2RideNote)];
      title = l.planLongRide;
      // Long races: practise the race fuelling on rides ≥ 2 h (60–90 g carbs / h, Jeukendrup 2014).
      desc = [l.wLongRideDesc, if (m >= 120 && _expectedRaceSec() >= 150 * 60) l.wFuelPracticeNote].join('\n');
      // 70.3 / Ironman / duathlon / Gran Fondo build + peak: blocks at race power inside the long ride
      // (review 2026-11, IMPORTANT 6/7 – the long ride was pure Z2 all season): 70.3 2 × 15 → 3 × 20 →
      // 3 × 30 min, Ironman 2 × 20 → 3 × 30 → 3 × 40, at most ~45 % of the ride, Z2 in between.
      // (Duathlon peak: the run – bike – run brick is the race simulation – no blocks on top, ≤ 40 % of the
      // week at tempo or harder.)
      final racePower =
          (_longCourse || (_du && phase == 'build') || rideEvent) && (phase == 'build' || phase == 'peak') && !hf.capIntensity;
      if (racePower && m >= 75) {
        final im = a.eventDistance == 'ironman';
        // Duathlon (race power ~82 % FTP, a weekly threshold ride and tempo run besides): shorter blocks.
        final table =
            phase == 'build'
                ? (im ? const [(2, 20), (2, 30), (3, 30)] : (_du ? const [(2, 10), (2, 12), (2, 15)] : const [(2, 15), (2, 20), (3, 20)]))
                : (im ? const [(3, 30), (3, 40), (3, 40)] : const [(3, 20), (3, 25), (3, 30)]);
        var (n, each) = table[_stage];
        while (n * each > m * 0.45 && each > 10) {
          each -= 5;
        }
        final rec = max(5, min(15, (m - n * each - 20) ~/ max(1, n + 1)));
        final frac = GoalModel.raceFtpShare(a.eventDistance);
        final zone = frac >= 0.76 ? 'Z3' : 'Z2';
        final pw = ftp == null ? null : ((ftp! * (frac - 0.03)).round(), (ftp! * (frac + 0.03)).round());
        WorkoutStep block() {
          final s = _rideStep('work', zone, each * 60, note: l.stepRacePowerNote);
          return pw == null
              ? s
              : WorkoutStep(
                kind: s.kind,
                durationSec: s.durationSec,
                zone: s.zone,
                powerMin: pw.$1,
                powerMax: pw.$2,
                hrMin: s.hrMin,
                hrMax: s.hrMax,
                note: s.note,
              );
        }

        final easy = m - n * each - (n - 1) * rec;
        final first = max(10, easy ~/ 2);
        steps = [
          _rideStep('steady', 'Z2', first * 60, note: l.stepZ2RideNote),
          for (var i = 0; i < n; i++) ...[block(), if (i < n - 1) _rideStep('steady', 'Z2', rec * 60, note: l.stepZ2RideNote)],
          _rideStep('steady', 'Z2', max(10, easy - first) * 60, note: l.stepZ2RideNote),
        ];
        title = l.wLongRideRacePace(n, each);
        desc = [l.wLongRideRacePaceDesc, if (m >= 120 && _expectedRaceSec() >= 150 * 60) l.wFuelPracticeNote].join('\n');
      }
      intensity = 'long';
      isKey = true;
    } else if (role.startsWith('q')) {
      isKey = true;
      // FTP test (review 2026-11 RS4): a power meter without a stated FTP plans its watts from a W/kg guess – the
      // first quality ride is a 20 min test; every power-meter plan retests every 6 loading weeks in base / build
      // (§3.1; like the swim novices' CSS test, the athlete enters the result in the plan settings).
      final test = _ftpTestDue(day, role, phase, loadWeek, capMin);
      if (test != null) return test;
      // Race week: openers – a few short pick-ups in an easy ride keep the legs sharp (tri-1).
      if (_taperLast) return _ridePickups(day, phase, capMin, opener: true);
      // < 5 bike hours: pyramidal – one sweet-spot / threshold and one VO2 session, also
      // in the base phase (§3.3). Beginners: no VO2max reps (threshold work instead).
      final vo2 = !beginner && (role == 'q2' || (phase == 'peak' && perWeek < 3));
      // Every quality ride keeps a real stimulus (review 2026-11 RS1 / RS9: "Sweet Spot 3 × 5 min", 2 × 3 min
      // with a 4 min warm-up): blocks ≥ 8 min (VO2max ≥ 3 × 3 min) after a warm-up of ≥ 8 min – when the day's
      // time holds less, an easy ride with a few pick-ups instead ([_ridePickups]).
      List<WorkoutStep>? fitted;
      if (phase == 'peak' && role == 'q1' && (_longCourse || rideEvent) && !rest && !hf.capIntensity) {
        // 70.3 / Ironman / Gran Fondo peak: race-specific tempo at 75–85 % FTP (the race's long
        // steady effort) instead of VO2max reps – 2 × 25 → 2 × 30 → 3 × 25 min over the peak
        // (coach review 3); Ironman 2 × 30 → 2 × 40 → 3 × 30. The watts are that range, not the whole Z3 band
        // (review 2026-11 T2 / tri-6: 76–90 % on the watch, "75–85 %" in the text).
        final (reps, each) = (a.eventDistance == 'ironman' ? const [(2, 30), (2, 40), (3, 30)] : const [(2, 25), (2, 30), (3, 25)])[_stage];
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_raceTempoStep(each * 60));
          if (i < reps - 1) steps.add(_rideStep('recovery', 'Z1', 300));
        }
        steps.add(cd);
        fitted = _fitRide(steps, capMin * 60, minWorkSec: 480);
        if (fitted == null) return _ridePickups(day, phase, capMin);
        steps = fitted;
        final first = steps.firstWhere((s) => s.isWork);
        title = l.wRideTempo(steps.where((s) => s.isWork).length, (first.durationSec! / 60).round());
        // The description names the race (the Ironman / Gran Fondo said "a 70.3 bike leg"); the Ironman's is above
        // its race power (~65–75 % FTP, the long ride's race-pace blocks).
        desc = rideEvent ? l.wRideTempoDescFondo : (a.eventDistance == 'ironman' ? l.wRideTempoDescIm2 : l.wRideTempoDesc);
        intensity = 'tempo';
      } else if (vo2 && phase == 'base' && weekH >= 5 && !hf.capIntensity && !rest) {
        // Base with ≥ 5 bike hours: the second quality ride is tempo (Z3, 2 × 15 → 3 × 20 min) – it was a
        // second identical sweet-spot ride in the same week (review 2026-11, IMPORTANT 5).
        final (reps, each) = const [(2, 15), (2, 20), (3, 15), (2, 25), (3, 20)][min(4, loadWeek)];
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          // (The note names the zone's own range, 76–90 % – review 2026-11 RS8.)
          steps.add(_rideStep('work', 'Z3', each * 60, note: l.stepRideTempoNote2));
          if (i < reps - 1) steps.add(_rideStep('recovery', 'Z1', 300));
        }
        steps.add(cd);
        fitted = _fitRide(steps, capMin * 60, minWorkSec: 480);
        if (fitted == null) return _ridePickups(day, phase, capMin);
        steps = fitted;
        final first = steps.firstWhere((s) => s.isWork);
        title = l.wRideTempo(steps.where((s) => s.isWork).length, (first.durationSec! / 60).round());
        desc = l.wRideTempoBaseDesc;
        intensity = 'tempo';
      } else if (vo2 && (phase != 'base' || weekH < 5) && !hf.capIntensity) {
        final reps = rest ? 3 : 4 + min(2, loadWeek ~/ 3);
        final dur = phase == 'peak' ? 240 : 180;
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          steps.add(_rideStep('work', 'Z5', dur, note: l.stepVo2Note));
          if (i < reps - 1) steps.add(_rideStep('recovery', 'Z1', dur));
        }
        steps.add(cd);
        fitted = _fitRide(steps, capMin * 60, minWorkSec: 180, minReps: 3, recRatio: 1.0);
        if (fitted == null) return _ridePickups(day, phase, capMin);
        steps = fitted;
        // The title follows the (possibly shortened) repeats.
        title = l.wRideVo2(steps.where((s) => s.isWork).length, (steps.firstWhere((s) => s.isWork).durationSec! / 60).round());
        desc = l.wRideVo2Desc;
        intensity = 'intervals';
      } else {
        // Sweet spot in base, threshold later.
        final ss = phase == 'base' || phase == 'recovery';
        // 24 → 60 min of work over the loading weeks (beginners 15 → 40, keeping the
        // hard share of their 2–3 rides near 20 %); recovery / taper weeks ~70 %.
        // Beginners: threshold (Z4) ≤ 30 min of work – 2 × 20 min next to a swim test pushed a 3.5 h
        // week to 28 % hard time (fix/plan-goal-progression matrix); sweet spot up to 40.
        final total = (min(beginner ? (ss ? 40 : 30) : 60, (beginner ? 15 : 24) + loadWeek * 4) * (rest ? 0.7 : 1.0)).round();
        // Gran Fondo build: every other week the sweet-spot work as climbing repeats (seated, low
        // cadence 60–70 rpm) – the specific strength of long climbs (§3.5, practice). Not with a knee / hip
        // problem (review 2026-11 RS5): high torque at low cadence loads the patellofemoral joint – their
        // sweet spot stays at a normal cadence.
        final climb = rideEvent && phase == 'build' && loadWeek.isEven && !hf.kneeOrHip;
        // Blocks of ≥ 10 min (review 2026-11 RS1: 24 min of sweet spot as 3 × 5 min – §3.5 starts at 3 × 10, coaching
        // practice ≥ 8–10 min at 88–94 %): the last step of the ladder 2 × 10 → … → 2 × 30 within the work time
        // (+3 min) – a recovery week's ~70 % lands a step lower.
        final ladder = _ssLadder.lastWhere((x) => x.$1 * x.$2 <= total + 3, orElse: () => _ssLadder.first);
        var reps = climb ? max(3, total ~/ 10) : ladder.$1;
        var each = climb ? 10 : ladder.$2;
        // Threshold (non-beginners): one step per threshold ride – 3 × 10 → 3 × 12 → 3 × 15 → 2 × 20 →
        // 2 × 25 min at 91–100 % FTP (§3.5: 20 → 60 min in Z4; Coggan). "2 × 30 min at 95–105 %" every
        // week for 7 weeks was an FTP test each time (review 2026-11, IMPORTANT 4).
        final thr = !ss && !climb && !beginner;
        if (thr) {
          final lv = rest ? 0 : min(_thrRides, 4);
          (reps, each) = const [(3, 10), (3, 12), (3, 15), (2, 20), (2, 25)][lv];
          if (!rest) _thrRides++;
        }
        // Threshold work – beginners' too – at 91–100 % FTP (review 2026-11 RS8: the beginners' note said 95–105 %
        // on a 91–105 % watt range).
        final z4 = !ss && !climb;
        steps = [wu];
        for (var i = 0; i < reps; i++) {
          final s = _rideStep(
            'work',
            z4 ? 'Z4' : 'SS',
            each * 60,
            note: climb ? l.stepClimbNote : (ss ? l.stepSsNote : l.stepThresholdNote2),
          );
          steps.add(z4 && ftp != null ? _stepWith(s, powerMax: ftp) : s);
          if (i < reps - 1) steps.add(_rideStep('recovery', 'Z1', thr ? max(3, each ~/ 2) * 60 : 300));
        }
        steps.add(cd);
        fitted = _fitRide(steps, capMin * 60, minWorkSec: 480);
        if (fitted == null) return _ridePickups(day, phase, capMin);
        steps = fitted;
        final n = steps.where((s) => s.isWork).length;
        final e = (steps.firstWhere((s) => s.isWork).durationSec! / 60).round();
        title = climb ? l.wClimb(n, e) : (ss ? l.wSweetSpot(n, e) : l.wThreshold(n, e));
        desc = climb ? l.wClimbDesc : (ss ? l.wSweetSpotDesc : l.wThresholdDesc);
        intensity = 'tempo';
      }
    } else {
      // A taper week without a quality ride: its first easy ride carries a few pick-ups ([_taperTouchDue]).
      if (perWeek >= 2 && _taperTouchDue(Sport.ride, phase, nQ)) return _ridePickups(day, phase, min(capMin, 45), taper: true);
      // Remaining time after the long ride and ~65 min per quality ride, never longer
      // than 75 % of the long ride.
      final longMin = longRide;
      final easyCount = max(1, perWeek - 1 - nQ);
      final left = weekH * 60 - longMin - nQ * 65;
      final floor = rest ? 25 : 40;
      // Recovery / taper: easy rides ≤ 60 % of the (shortened) long ride, so the deload shows also when
      // the day's time, not the bike hours, sets the ride length.
      // (A recovery ride stays ≤ 90 min – FUZZ-2: a 235 min "recovery ride".)
      final easyMin =
          ((left / easyCount).clamp(floor, max(floor, min(rest ? 90.0 : double.infinity, longMin * (rest ? 0.6 : 0.75)))) / 5).round() * 5;
      steps = [_rideStep('steady', 'Z2', min(easyMin, capMin) * 60, note: l.stepZ2RideNote)];
      title = phase == 'recovery' ? l.wRecoveryRide : l.planEasyRide;
      desc = l.wEasyRideDesc;
    }
    return _plan(day, Sport.ride, title, desc, intensity, steps, phase, isKey);
  }

  /// Work blocks of ≥ 10 min shortened to whole 5 min ("2 × 29 min" / "2 × 37 min" after [_fitToTime]
  /// read like a typo – review 2026-11 MINOR).
  List<WorkoutStep> _tidyRideWork(List<WorkoutStep> steps) => [
    for (final s in steps)
      s.isWork && (s.durationSec ?? 0) >= 600 && s.durationSec! % 300 != 0
          ? WorkoutStep(
            kind: s.kind,
            durationSec: s.durationSec! ~/ 300 * 300,
            zone: s.zone,
            powerMin: s.powerMin,
            powerMax: s.powerMax,
            hrMin: s.hrMin,
            hrMax: s.hrMax,
            note: s.note,
          )
          : s,
  ];

  /// Sweet-spot / threshold blocks (reps, min) by the work time of the session (§3.5: 3 × 10 → 2 × 30 min).
  static const _ssLadder = [(2, 10), (3, 10), (2, 15), (2, 20), (3, 15), (2, 25), (2, 30)];

  /// [s] with another duration / power range.
  static WorkoutStep _stepWith(WorkoutStep s, {int? sec, int? powerMin, int? powerMax}) => WorkoutStep(
    kind: s.kind,
    durationSec: sec ?? s.durationSec,
    distanceM: s.distanceM,
    zone: s.zone,
    paceMin: s.paceMin,
    paceMax: s.paceMax,
    powerMin: powerMin ?? s.powerMin,
    powerMax: powerMax ?? s.powerMax,
    hrMin: s.hrMin,
    hrMax: s.hrMax,
    note: s.note,
  );

  /// Race-specific tempo block of 70.3 / Ironman / Gran Fondo plans: 75–85 % FTP – the range its text names
  /// ([stepRideTempoNote]), not the whole Z3 band of 76–90 % (review 2026-11 T2 / tri-6).
  WorkoutStep _raceTempoStep(int sec) {
    final s = _rideStep('work', 'Z3', sec, note: l.stepRideTempoNote);
    return ftp == null ? s : _stepWith(s, powerMin: (ftp! * 0.75).round(), powerMax: (ftp! * 0.85).round());
  }

  /// Fits a quality ride of warm-up, work blocks with recoveries and cool-down into [capSec] without making it a
  /// token session (review 2026-11 RS1 / RS9: "Sweet Spot 2 × 3 min" after a 4 min warm-up): fewer blocks first
  /// (≥ [minReps]), then a shorter cool-down (≥ 3 min) and warm-up (≥ 8 min – threshold and VO2max work need a
  /// progressive warm-up), then shorter blocks in whole minutes (≥ 10 min in 5 min steps), never below
  /// [minWorkSec], their recoveries scaled along ([recRatio] × the block at most, ≥ 2 min). Null when even that
  /// does not fit – an easy ride with pick-ups is then the honest session ([_ridePickups]).
  List<WorkoutStep>? _fitRide(List<WorkoutStep> steps, int capSec, {required int minWorkSec, int minReps = 2, double recRatio = 0.3}) {
    int total(List<WorkoutStep> l) => l.fold(0, (x, s) => x + (s.durationSec ?? 0));
    var list = [...steps];
    if (total(list) <= capSec) return _tidyRideWork(list);
    while (total(list) > capSec && list.where((s) => s.isWork).length > minReps) {
      final i = list.lastIndexWhere((s) => s.isWork);
      list.removeAt(i);
      if (i - 1 >= 0 && list[i - 1].kind == 'recovery') list.removeAt(i - 1);
    }
    if (total(list) <= capSec) return _tidyRideWork(list);
    final wu = list.firstWhere((s) => s.kind == 'warmup'), cd = list.lastWhere((s) => s.kind == 'cooldown');
    final work = list.firstWhere((s) => s.isWork);
    final rec0 = list.where((s) => s.kind == 'recovery').firstOrNull;
    final n = list.where((s) => s.isWork).length;
    final block0 = work.durationSec!;
    final wuSec = min(wu.durationSec!, 480);
    for (var block = block0; block >= minWorkSec; block -= 60) {
      if (block >= 600 && block % 300 != 0) continue;
      final int rec = rec0 == null ? 0 : max(120, min(rec0.durationSec!, (block * recRatio / 60).floor() * 60));
      final left = capSec - wuSec - n * block - (n - 1) * rec;
      if (left < 180) continue;
      // (The full warm-up when the time allows it.)
      final int wuFit = min(wu.durationSec!, wuSec + max(0, left - cd.durationSec!));
      final int cdFit = min(cd.durationSec!, capSec - wuFit - n * block - (n - 1) * rec);
      return [
        _stepWith(wu, sec: wuFit),
        for (var i = 0; i < n; i++) ...[_stepWith(work, sec: block), if (i < n - 1 && rec0 != null) _stepWith(rec0, sec: rec)],
        _stepWith(cd, sec: cdFit),
      ];
    }
    return null;
  }

  /// Easy ride with a few 1 min pick-ups – the quality ride of a day too short for ≥ 2 blocks of 8 min (VO2max:
  /// 3 × 3 min) after a proper warm-up ([_fitRide]). Not a key session.
  /// [opener]: race week's openers (the reason in the description).
  /// [taper]: a taper week's touch of intensity ([_taperTouchDue]).
  PlannedWorkout _ridePickups(DateTime day, String phase, int capMin, {bool opener = false, bool taper = false}) {
    // Openers are a short session (≤ 40 min – the day's whole time made a 190–240 min "opener" 2–3 days before the
    // race, review 2026-11 G2-V1); the fallback of a short day fills that day (its time is short by definition).
    final m = max(20, opener ? min(capMin, 40) : capMin);
    final n = m >= 30 ? 4 : 3;
    final first = min(10, m - n * 3 - 3), last = m - first - n * 3;
    return _plan(
      day,
      Sport.ride,
      l.wRidePickups(n),
      opener ? l.wRideOpenersDesc : (taper ? l.wRideTaperPickupsDesc : l.wRidePickupsDesc),
      'easy',
      [
        _rideStep('warmup', 'Z2', first * 60, note: l.stepZ2RideNote),
        for (var i = 0; i < n; i++) ...[_rideStep('work', 'Z4', 60, note: l.stepRidePickupNote), _rideStep('recovery', 'Z2', 120)],
        _rideStep('cooldown', 'Z2', last * 60, note: l.stepZ2RideNote),
      ],
      phase,
      false,
    );
  }

  /// Loading week of the last FTP test (null: none yet) – [_ftpTestDue].
  int? _ftpTestLoad;

  /// The FTP test (20 min, review 2026-11 RS4) when the quality ride [role] of this week is due for one: the
  /// first quality ride of a plan whose FTP is estimated (power meter, no FTP stated), then every 6 loading
  /// weeks in base / build for every power-meter plan (§3.1: retest every 6–8 weeks). Not with a heart / blood-
  /// pressure condition (no maximal efforts), not on a day under 40 min. Null otherwise.
  PlannedWorkout? _ftpTestDue(DateTime day, String role, String phase, int loadWeek, int capMin) {
    if (!a.hasPowerMeter || ftp == null || role != 'q1' || hf.capIntensity || capMin < 40) return null;
    if (phase != 'base' && phase != 'build') return null;
    final last = _ftpTestLoad;
    if (last == null ? a.ftp != null : loadWeek - last < 6) return null;
    _ftpTestLoad = loadWeek;
    final openers = capMin >= 55;
    final hr = hz.zone(4);
    return _plan(
      day,
      Sport.ride,
      l.wFtpTest,
      l.wFtpTestDesc,
      'intervals',
      [
        _rideStep('warmup', 'Z2', (openers ? 12 : 10) * 60, note: l.stepZ2RideNote),
        if (openers)
          for (var i = 0; i < 3; i++) ...[_rideStep('warmup', 'Z4', 60, note: l.stepRidePickupNote), _rideStep('warmup', 'Z1', 60)],
        _rideStep('recovery', 'Z1', 300),
        WorkoutStep(kind: 'work', durationSec: 1200, zone: 'Z4', hrMin: hr.$1 - 5, hrMax: hr.$2 - 5, note: l.stepFtpTestNote),
        _rideStep('cooldown', 'Z1', (openers ? 10 : 5) * 60),
      ],
      phase,
      true,
    );
  }

  /// Order of [w] among the day's workouts ([PlannedWorkout.slot], review 2026-11 tri-12: a brick run listed before its
  /// ride): the duathlon's run before the bike, swim, ride, the run off the bike, other runs, strength.
  int _slotOf(PlannedWorkout w) => switch (w.sport) {
    Sport.run when w.description.startsWith(l.wDuRunFirstDesc) => 1,
    Sport.swim => 2,
    Sport.ride => 3,
    Sport.run when w.intensity == 'moderate' => 4,
    Sport.run => 5,
    Sport.gym => 6,
  };

  /// [w] (a ride with watt targets from an estimated FTP) with the note that says so ([generate]).
  PlannedWorkout _withFtpNote(PlannedWorkout w) =>
      w.sport != Sport.ride ||
              w.intensity == 'race' ||
              w.title == l.wFtpTest ||
              !w.steps.any((s) => s.powerMin != null || s.powerMax != null)
          ? w
          : _withNote(w, l.wFtpEstimateNote('${ftp!}'));

  // ───────────────────────────── Swimming ─────────────────────────────

  WorkoutStep _swimStep(String kind, String zone, double m, {String note = ''}) {
    final (fast, slow) = sz.range(zone);
    // Drills are about technique, not speed: no pace target (coach review 3). Beginners swim by feel and breathing
    // for the first 5 weeks also with a test (§4.5; review 2026-11 RS3).
    final noPace = (beginner && (a.swim400Sec == null || _weekIdx < 5)) || zone == 'DR';
    return WorkoutStep(kind: kind, distanceM: m, zone: zone, paceMin: noPace ? null : fast, paceMax: noPace ? null : slow, note: note);
  }

  /// Two concrete technique drills, rotating weekly (see zone_info.dart › swimDrills) – for a block of 100 m
  /// multiples ("alternate 50 m drill, 50 m freestyle"); [fifty]: a single 50 m drill step, which cannot alternate
  /// 50 m drill and 50 m freestyle (review 2026-11 RS10).
  String _drillNote(int week, {bool fifty = false}) {
    final names = [l.drillCatchupName, l.drillFingertipName, l.drillSideKickName, l.drillSingleArmName, l.drillFistName, l.drillScullName];
    final i = (week * 2) % names.length;
    return fifty ? l.drillsNote50(names[i], names[(i + 1) % names.length]) : l.drillsNote(names[i], names[(i + 1) % names.length]);
  }

  /// Drill block of about [m] metres – whole 100 m (≥ 100), so "50 m drill, 50 m freestyle" alternates evenly.
  WorkoutStep _drillStep(double m, int week) => _swimStep('work', 'DR', max(100.0, (m / 100).round() * 100.0), note: _drillNote(week));

  PlannedWorkout _swim(DateTime day, String role, String phase, double weekKm, int perWeek, int week, int capMin) {
    // Swim novice before the CSS test: technique and the continuous-swim ladder (§4.5).
    if (_swimNovice && !_swimTested) return _noviceSwim(day, role, phase, week, capMin);
    // A beginner who can swim 400 m but has no swim test: the CSS test after ~3 loading weeks (§4.5; review 2026-11
    // RS2) – rested, in the recovery week after them (no hard session on top of the week's quality ones, H2), else
    // after 6 loading weeks; not on the long swim, not with a heart / shoulder limitation (no time trials).
    if (beginner &&
        !_swimTested &&
        SwimZones.fromTests(a.swim400Sec, a.swim200Sec) == null &&
        ((phase == 'recovery' && _loadWeek >= 3) || (phase != 'recovery' && phase != 'taper' && _loadWeek >= 6)) &&
        role != 'long' &&
        !hf.capIntensity &&
        !hf.avoidOverhead &&
        capMin >= 40) {
      _swimTested = true;
      return _swimCssTest(day, phase, week);
    }
    if (role == 'long') return _longSwim(day, phase, capMin);
    // No CSS set in the 2 days before the race (a 155 min "CSS 20 × 100 m" two days out – review 2026-11 G2-V1 fuzz):
    // an easy swim there; the race-week CSS set earlier in the week stays short ([_swimSession]).
    final raceDay = a.eventDate == null || spec == null ? null : dayOnly(a.eventDate!);
    if (_taperLast && role.startsWith('q') && raceDay != null && daysBetween(day, raceDay) <= 2) role = 'easy';
    // Technique sessions stay ≤ ~60 min: drill quality drops with fatigue, and long sessions
    // of 50 m repeats do not build the continuous swimming a race needs.
    if (role == 'technique' || ((beginner || hf.avoidOverhead) && role.startsWith('q'))) capMin = min(capMin, 60);
    // Session distance, limited by the time available (≈ CSS + 15 s per 100 m incl. rests).
    final maxM = capMin * 60 / ((sz.css + 15) / 100);
    // Shoulder: ~20 % less swim volume (fewer strokes), technique over hard sets.
    final share = hf.avoidOverhead ? 0.8 : 1.0;
    // Swimming plans: the long swim takes its part of the week first.
    final weekM = weekKm * 1000;
    final per = _longSwimM > 0 && perWeek >= 2 ? max(600.0, (weekM - _longSwimM) / (perWeek - 1)) : weekM / max(1, perWeek);
    // Recovery / taper weeks may go below the loading-week floor, so the swim volume deloads too.
    final restWeek = phase == 'recovery' || phase == 'taper';
    // Former swim novices (after their CSS test) keep the beginner floor – no jump in volume.
    final small = beginner || _swimNovice;
    final floor = small ? (restWeek ? 400.0 : 600.0) : (restWeek ? 600.0 : 1000.0);
    var total = max(floor, (min(per, maxM) * share / 100).round() * 100.0);
    // Beginners: ≤ ~1.5 km a session (§4.4: 800–1500 m – review 2026-11 RS3: 2.1–2.2 km sessions). A triathlete's swims
    // are the whole week's swimming (often a single one) and must reach the race's leg: their cap starts at 1.5 km and
    // grows ≤ 10 % a loading week (§4.4) – a fixed 1.5 km held a 70.3 beginner's only swim at 2 × 400 m for 20 weeks,
    // recovery and taper weeks included (review 2026-11 G2-V3). Recovery / taper weeks stay ~25 % below the cap, so the
    // deload still shows.
    var capM = double.infinity;
    if (small) {
      capM = 1500.0 * (_tri ? pow(1.1, _loadWeek) : 1.0);
      if (restWeek) capM *= 0.75;
      // (The shoulder's ~20 % less applies below the cap too.)
      capM = max(floor, (capM * share / 100).floor() * 100.0);
      total = min(total, capM);
    }
    // Short repeats with long rests (beginners: 50 m + 30 s) take longer than the rough
    // estimate above: shrink until the session really fits the time available – and the beginners' cap (drills and
    // repeats round up: a 1.5 km technique session came out at 1.6 km, G2-V10).
    final contDone = _contSwimDone;
    var w = _swimSession(day, role, phase, total, week, capMin: capMin);
    for (var i = 0; i < 4 && (w.durationMin > capMin + 5 || (w.distanceKm ?? 0) * 1000 > capM + 50) && total > floor; i++) {
      final byTime = w.durationMin > capMin + 5 ? total * capMin / w.durationMin : total;
      final byCap = (w.distanceKm ?? 0) * 1000 > capM + 50 ? total - ((w.distanceKm ?? 0) * 1000 - capM) : total;
      total = max(floor, (min(byTime, byCap) / 100).floor() * 100.0);
      _contSwimDone = contDone;
      w = _swimSession(day, role, phase, total, week, capMin: capMin);
    }
    return w;
  }

  /// CSS test (§4.1): 400 m and 200 m time trials – the swim zones then come from the athlete. Two short time
  /// trials: hard, but not a key session for the spacing rules (H1).
  PlannedWorkout _swimCssTest(DateTime day, String phase, int week) {
    WorkoutStep step(String kind, String zone, double m, {String note = ''}) =>
        WorkoutStep(kind: kind, distanceM: m, zone: zone, note: note);
    final steps = [
      step('warmup', 'REC', 300, note: l.stepSwimWu),
      step('work', 'DR', 100, note: _drillNote(week)),
      const WorkoutStep(kind: 'recovery', durationSec: 60, zone: 'REC'),
      step('work', 'SP', 400, note: l.stepSwimTestNote),
      const WorkoutStep(kind: 'recovery', durationSec: 360, zone: 'REC'),
      step('work', 'SP', 200, note: l.stepSwimTestNote),
      step('cooldown', 'REC', 200),
    ];
    return _plan(day, Sport.swim, l.wSwimCssTest, l.wSwimCssTestDesc, 'intervals', steps, phase, false);
  }

  /// Swim novice (cannot swim 400 m continuously, §4.4/§4.5): ~600–1200 m with technique drills
  /// (25 m kick / side-kick / catch-up with breaks), then the stage's repeats of the
  /// continuous-swim ladder ([_swimLadder]: 8 × 50 m → 2 × 400 m, one stage per loading week,
  /// rest at the wall ~30–45 s). After the last stage: a CSS test, then the normal sessions.
  /// No pace targets – breathing, body position and relaxed rhythm first.
  PlannedWorkout _noviceSwim(DateTime day, String role, String phase, int week, int capMin) {
    final rest = phase == 'recovery' || phase == 'taper';
    final stage = rest ? max(0, _swimStage - 1) : _swimStage;
    WorkoutStep step(String kind, String zone, double m, {String note = ''}) =>
        WorkoutStep(kind: kind, distanceM: m, zone: zone, note: note);
    // Heart / blood pressure or shoulder: no all-out time trial – the swimmer just continues with
    // the normal (technique / endurance) sessions once 400 m in one go is reached.
    if (stage >= _ladderNow.length && (hf.capIntensity || hf.avoidOverhead)) _swimTested = true;
    if (stage >= _ladderNow.length && !rest && !_swimTested) {
      _swimTested = true;
      return _swimCssTest(day, phase, week);
    }
    final (rep, n0) = _ladderNow[min(stage, _ladderNow.length - 1)];
    final technique = role == 'technique' || role.startsWith('q');
    // Technique days: half the stage's repeats after more drills.
    // Recovery ~70 %, taper 65 % / race week 45 % of the stage's repeats and drills.
    final f = phase == 'taper' ? (_taperLast ? 0.45 : 0.65) : (rest ? 0.7 : 1.0);
    var n = max(2, ((technique ? n0 ~/ 2 : n0) * f).round());
    var drills = max(2, ((technique ? 6 : 3) * f).round()); // 50 m drill lengths
    List<WorkoutStep> build() => [
      step('warmup', 'REC', 150, note: l.stepSwimNoviceWu),
      for (var i = 0; i < drills; i++) ...[
        step('work', 'DR', 50, note: i.isEven ? l.stepSwimKickNote : _drillNote(week, fifty: true)),
        const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'),
      ],
      for (var i = 0; i < n; i++) ...[
        step('work', 'EN', rep.toDouble(), note: l.stepSwimNoviceNote),
        if (i < n - 1) WorkoutStep(kind: 'recovery', durationSec: rep >= 200 ? 45 : 30, zone: 'REC'),
      ],
      step('cooldown', 'REC', 100),
    ];
    // Fit the time (≤ 60 min): fewer repeats (≥ 2), then fewer drills (≥ 2).
    final capSec = min(capMin, 60) * 60;
    int sec(List<WorkoutStep> s) => s.fold(0, (x, st) => x + _stepSec(st, Sport.swim));
    var fitted = build();
    while (sec(fitted) > capSec && (n > 2 || drills > 2)) {
      if (n > 2) {
        n--;
      } else {
        drills--;
      }
      fitted = build();
    }
    final reps = n;
    return _plan(
      day,
      Sport.swim,
      technique ? l.planSwimTechnique : l.wSwimBuild(reps, rep),
      technique ? l.wSwimNoviceTechDesc : l.wSwimBuildDesc,
      technique ? 'technique' : 'easy',
      fitted,
      phase,
      false,
    );
  }

  /// The continuous swim of a loading week was cut by the time on its day ([weekday]) even with the shortest frame
  /// ([frameM] of warm-up, drills and cool-down): the day the feasibility check asks to raise and the minutes a
  /// session with [targetM] in one go needs (review 2026-11 tri-7: the warning blamed the athlete, the day's time was
  /// the limit).
  void _noteSwimLimit(int weekday, double targetM, double frameM) {
    final need = ((120 + (targetM + frameM) * (sz.css + 12) / 100) / 60).ceil();
    if (_swimLimitDay == null || need > _swimLimitMin) {
      _swimLimitDay = weekday;
      _swimLimitMin = need;
    }
  }

  /// [_noteSwimLimit]: the swim day whose time cut the continuous swim, and the minutes it needs (null / 0: none).
  int? _swimLimitDay;
  int _swimLimitMin = 0;

  /// Long continuous swim of a swimming plan: [_longSwimM] in one go (grows ~10 % per loading
  /// week towards the race distance), with warm-up, a few drills and – for open-water races in
  /// build / peak – sighting practice.
  PlannedWorkout _longSwim(DateTime day, String phase, int capMin) {
    final ow = spec?.sport == EventSport.swim || _tri;
    final sight = ow && (phase == 'build' || phase == 'peak');
    // Fit the time: warm-up 300 + drills 200 + cool-down 200 around the continuous part – when the day's time binds,
    // the frame shrinks first (warm-up 200, drills 100, cool-down 100) before the swim itself (review 2026-11 tri-7).
    double fit(double frame) => ((capMin * 60 - 120) / ((sz.css + 12) / 100) - frame).clamp(300.0, 10000.0);
    // On its plateau (review 2026-11: swim3800 W5–W12 identical) the long swim rotates: the last third
    // at race pace, then ~15 % over the usual distance (≤ the race's), then the plain long swim.
    final race = (eventDistanceOf(a.eventDistance)?.km ?? 0) * 1000;
    // (The week of a novice's CSS test has no long swim planned yet: 400 m – what the ladder ended with, not 300.)
    final base = _longSwimM > 0 ? _longSwimM : 400.0;
    final over = _longSwimVariant == 2 ? min(base * 1.15, race > 0 ? race : double.infinity) : base;
    // Taper (review 2026-11 M5, Bosquet 2007: −40–60 % volume): the frame around a short taper swim shrinks
    // too – 700 m of warm-up, drills and cool-down around a 300 m swim kept a novice's race week at ~95 %.
    final taper = phase == 'taper';
    final tight = taper || fit(700) < over;
    final m = max(300.0, (min(over, fit(tight ? 400 : 700)) / 100).floor() * 100.0);
    if (tight && !taper && phase != 'recovery' && m < over) _noteSwimLimit(day.weekday, max(over, spec?.longSwimM ?? 0), 400);
    final finish = _longSwimVariant == 1 ? max(100.0, (m / 3 / 100).round() * 100.0) : 0.0;
    final steps = [
      _swimStep('warmup', 'REC', tight ? 200 : 300, note: l.stepSwimWu),
      _drillStep(tight ? 100 : 200, _swimStage),
      const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'),
      _swimStep('work', 'EN', m - finish, note: sight ? l.stepSightingNote : l.stepSwimEnNote),
      if (finish > 0) _swimStep('work', 'TE', finish, note: l.stepSwimRaceFinishNote),
      _swimStep('cooldown', 'REC', tight ? 100 : 200),
    ];
    return _plan(
      day,
      Sport.swim,
      // (The title names the continuous part – review 2026-11 T13: "Lange Schwimmeinheit 300 m" on a 1.0 km card.)
      l.wLongSwim2(m.round()),
      [
        l.wLongSwimDesc,
        if (finish > 0) l.wLongSwimRaceDesc,
        if (ow && spec != null) l.wOpenWaterNote,
        // Former swim novices / beginners heading for open water: the safety rules spelled out (review 2026-11 H2).
        if (ow && spec != null && (_swimNovice || beginner) && (phase == 'build' || phase == 'peak')) l.wOpenWaterSafety,
      ].join('\n'),
      'long',
      steps,
      phase,
      true,
    );
  }

  PlannedWorkout _swimSession(DateTime day, String role, String phase, double total, int week, {int? capMin}) {
    var wu = _swimStep('warmup', 'REC', (total * 0.18 / 50).round() * 50.0, note: l.stepSwimWu);
    var cd = _swimStep('cooldown', 'REC', max(100.0, (total * 0.1 / 50).round() * 50.0));
    String title, desc, intensity;
    final steps = <WorkoutStep>[wu];
    var isKey = false;
    // Triathlon build / peak: the endurance swims practise sighting, the description the open water
    // (review 2026-11 C7 – only the swim-only long swim had these cues).
    final ow = _tri && (phase == 'build' || phase == 'peak');
    // Quality swims progress over the loading weeks of a phase (review 2026-11: identical weeks W5–W12
    // of a swim3800 plan): a little more of the session at pace per stage ([_stage]).
    final load = phase == 'recovery' || phase == 'taper' ? 0 : _stage;
    if (role == 'q2' && _swimCssOk) {
      // Second quality swim (swimmers with ≥ 4 swims): tempo repeats at CSS + 3–6 s, 300 → 400 m
      // (peak, last stage: 500 m).
      final rep = phase == 'base' ? 300.0 : (phase == 'peak' && load == 2 ? 500.0 : 400.0);
      final n = max(3, ((total * (0.5 + 0.05 * load)) / rep).round());
      for (var i = 0; i < n; i++) {
        steps.add(_swimStep('work', 'TE', rep, note: l.stepSwimTempoNote));
        if (i < n - 1) steps.add(const WorkoutStep(kind: 'recovery', durationSec: 20, zone: 'REC'));
      }
      title = l.wSwimTempoSet(n, rep.round());
      desc = l.wSwimTempoDesc;
      intensity = 'tempo';
      isKey = true;
    } else if (role == 'q1' && _swimCssOk) {
      // CSS set (~50 % of the session). Repeats get longer through the season:
      // base 100 m (15 s rest) → build 200 m (20 s) → peak 300 m (30 s);
      // recovery / taper weeks go back to short 100s.
      final (rep, rest) = switch (phase) {
        'build' => (200.0, 20),
        'peak' => (300.0, 30),
        _ => (100.0, 15),
      };
      // ~35 % of the session at CSS (the rest easy): a 3-swim week stays ~80/20 by time.
      // (Taper: the set shortened like every quality session – ≤ 8 × 100 m, race week ≤ 6.)
      final n0 = max(rep >= 300 ? 3 : (rep >= 200 ? 4 : 6), ((total * (0.35 + 0.05 * load)) / rep).round());
      final n = phase == 'taper' ? min(n0, _taperLast ? 6 : 8) : n0;
      steps.add(_drillStep(200, week));
      steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      for (var i = 0; i < n; i++) {
        steps.add(_swimStep('work', 'CSS', rep, note: l.stepCssNote));
        if (i < n - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: rest, zone: 'REC'));
      }
      title = l.wSwimCssSet(n, rep.round());
      desc = l.wSwimCssDesc;
      intensity = 'intervals';
      isKey = true;
    } else if (role == 'technique' || ((beginner || hf.avoidOverhead) && role.startsWith('q'))) {
      steps.add(_drillStep(total * (beginner ? 0.3 : 0.2), week));
      steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      final main = (total * 0.45 / 50).round() * 50.0;
      final reps = max(2, (main / (beginner ? 50 : 100)).round());
      for (var i = 0; i < reps; i++) {
        steps.add(_swimStep('work', 'EN', beginner ? 50 : 100, note: l.stepSwimEasyNote));
        if (i < reps - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: beginner ? 30 : 20, zone: 'REC'));
      }
      title = l.planSwimTechnique;
      desc = l.wSwimTechDesc;
      intensity = 'technique';
    } else if (_contSwimM > 0 && (!_contSwimDone || _swimsPerWeek <= 2)) {
      // Former swim novice with a race: the main set in one go, growing towards the race's
      // continuous swim (recovery / taper weeks ~70 %, race week ~50 %). One such swim a week (three or more
      // swims: the other endurance swim keeps its repeats).
      _contSwimDone = true;
      final rest = phase == 'recovery' || phase == 'taper';
      final want = rest ? max(300.0, (_contSwimM * (_taperLast ? 0.5 : 0.7) / 100).round() * 100.0) : _contSwimM;
      var m = want;
      // Never longer than the time that day allows (warm-up, drills and cool-down around it) – when the time binds,
      // the warm-up (≥ 200 m) and cool-down (≥ 100 m) give way first (review 2026-11 tri-7: "1500 m" for six weeks
      // inside 400 m of warm-up and 250 m of cool-down).
      int around() => _stepSec(wu, Sport.swim) + _stepSec(cd, Sport.swim) + _stepSec(_swimStep('work', 'DR', 100), Sport.swim) + 40;
      double fit() => capMin == null ? double.infinity : ((capMin * 60 - around()) / (sz.css + 12) * 100 / 100).floor() * 100.0;
      if (fit() < m) {
        final wu0 = wu.distanceM!;
        wu = _swimStep('warmup', 'REC', min(wu0, 200), note: l.stepSwimWu);
        cd = _swimStep('cooldown', 'REC', min(cd.distanceM!, 100));
        // (Back to a longer warm-up with the time the swim does not need.)
        final spare = fit() - m;
        if (spare > 0) wu = _swimStep('warmup', 'REC', min(wu0, 200.0 + (spare / 50).floor() * 50.0), note: l.stepSwimWu);
        steps[0] = wu;
      }
      if (fit() < m) {
        m = max(300.0, fit());
        if (!rest && m < want) _noteSwimLimit(day.weekday, _swimTargetM ?? want, 400);
      }
      steps.add(_drillStep(100, week));
      steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      steps.add(_swimStep('work', 'EN', m, note: ow ? l.stepSightingNote : l.stepSwimEnNote));
      // Long course (review 2026-11 H5): the rest of the session's volume as easy 200s after the continuous
      // swim, so the session keeps the week's volume (Ironman ~3–3.5 km) – within the day's time.
      if (_longCourse && !beginner && !_swimNovice) {
        final left = total - wu.distanceM! - cd.distanceM! - 100 - m;
        var reps = (left / 200).floor();
        if (capMin != null) {
          final spare = capMin * 60 - around() - m / 100 * (sz.css + 12);
          reps = min(reps, (spare / (2 * (sz.css + 15) + 20)).floor());
        }
        for (var i = 0; i < reps; i++) {
          steps.add(WorkoutStep(kind: 'recovery', durationSec: i == 0 ? 60 : 20, zone: 'REC'));
          steps.add(_swimStep('work', 'EN', 200, note: l.stepSwimEnNote));
        }
      }
      title = l.wSwimContinuous(m.round());
      // "It grows ~100 m a week" only while it does (tri-7).
      final growing = !rest && m >= want && want < (_swimTargetM ?? 0);
      desc = [growing ? l.wSwimContinuousDesc : l.wSwimContinuousDesc2, if (ow) l.wTriOpenWaterNote].join('\n');
      intensity = 'easy';
    } else {
      // The only swim of the week: the technique drills come first (§4.3: 10–20 % drills).
      final single = _swimsPerWeek == 1;
      var drillM = max(100.0, (total * 0.15 / 100).round() * 100.0);
      // Build / peak: a bigger main set, so the race-length repeats (800 m+) fit a 60 min session.
      final late = phase == 'build' || phase == 'peak';
      final main = (total * (single ? 0.55 : (late ? 0.7 : 0.65)) / 100).round() * 100.0;
      // Continuous swimming grows through the plan (towards the race distance in one go):
      // beginners 50 → 100 → 200 → 400 → 800 m every 3 weeks, others 200 → 400 → 800 m
      // every 4 weeks; 800 m repeats only for olympic / 70.3, and always ≥ 2 repeats.
      // The longest repeat follows the race ([EventSpec.swimRepMax]: sprint 400 m, olympic / 70.3
      // 800 m, Ironman 1000 m); swim novices start here only after their CSS test.
      final ladder = beginner ? [100.0, 200.0, 400.0, 800.0, 1000.0] : [200.0, 400.0, 800.0, 1000.0];
      final repMax = spec?.swimRepMax ?? 400.0;
      (double, int) repeats(double main) {
        var i = min(week ~/ (beginner ? 3 : 4), ladder.length - 1);
        while (i > 0 && (ladder[i] > repMax || main < ladder[i] * 2)) {
          i--;
        }
        var rep = ladder[i];
        while (rep > 50 && main < rep * 2) {
          rep = rep / 2;
        }
        // Whole repeats (rounded down) that fill ≥ 75 % of the main set – rounding 2.5 × 800 m up to 3 made
        // the swim volume jump +30 % from one week to the next.
        while (rep > 100 && main - max(2, (main / rep).floor()) * rep > main * 0.25) {
          rep = ladder.lastWhere((x) => x < rep, orElse: () => rep / 2);
        }
        return (rep, max(2, rep >= 400 ? (main / rep).floor() : (main / rep).round()));
      }

      var (rep, reps) = repeats(main);
      // The only swim of a non-beginner's week ends with a CSS block in build / peak (review 2026-11 tri-11: one swim a
      // week never had a CSS or threshold swim – the race is swum near CSS): 4 → 6 → 8 × 100 m. Its metres come from
      // the main set's remainder, a shorter warm-up (≥ 300 m) and drill block (≥ 200 m) – the race-length repeats keep
      // their progression (review 2026-11 G2-V2: taken off the main set, it halved 2 × 800 m to 2 × 400 m). When not
      // even 4 × 100 m fit that way, every other loading week is a CSS week (the repeats from the rest of the main set)
      // and the weeks between keep the full endurance set.
      var cssReps = 0;
      if (single && late && _swimCssOk) {
        final want = 4 + 2 * _stage;
        var wuM = wu.distanceM!;
        final spare = max(0.0, main - reps * rep) + max(0.0, wuM - 300) + max(0.0, drillM - 200);
        if (spare >= 400) {
          cssReps = min(want, (spare / 100).floor());
          var need = cssReps * 100 - max(0.0, main - reps * rep);
          final fromWu = min(max(0.0, wuM - 300), max(0.0, need));
          wuM -= fromWu;
          need -= fromWu;
          if (need > 0) drillM -= need;
          wu = _swimStep('warmup', 'REC', wuM, note: l.stepSwimWu);
          steps[0] = wu;
        } else if (_loadWeek.isEven) {
          cssReps = want;
          (rep, reps) = repeats(main - want * 100);
        }
      }
      if (single) {
        steps.add(_drillStep(drillM, week));
        steps.add(const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'));
      }
      for (var i = 0; i < reps; i++) {
        steps.add(_swimStep('work', 'EN', rep, note: ow ? l.stepSightingNote : l.stepSwimEnNote));
        if (i < reps - 1) steps.add(WorkoutStep(kind: 'recovery', durationSec: beginner ? 30 : 20, zone: 'REC'));
      }
      for (var i = 0; i < cssReps; i++) {
        steps.add(WorkoutStep(kind: 'recovery', durationSec: i == 0 ? 60 : 15, zone: 'REC'));
        steps.add(_swimStep('work', 'CSS', 100, note: l.stepCssNote));
      }
      title = cssReps > 0 ? l.wSwimEnduranceCss(reps, rep.round(), cssReps) : l.wSwimEndurance(reps, rep.round());
      desc = [l.wSwimEnduranceDesc, if (cssReps > 0) l.wSwimCssDesc, if (ow) l.wTriOpenWaterNote].join('\n');
      intensity = 'easy';
    }
    steps.add(cd);
    return _plan(day, Sport.swim, title, desc, intensity, steps, phase, isKey);
  }

  // ───────────────────────────── Strength ─────────────────────────────

  /// Built-in program keys the plan for [p] will use: its split's rotation and the built-in
  /// programs the athlete assigned to gym days ([AthleteData.gymPlanA] / [AthleteData.gymPlanB]).
  static List<String> gymKeysFor(UserProfile p) {
    final a = p.athlete;
    final rotation = _rotationFor(a, scheduleOf(p));
    return {
      ...rotation,
      // (A race window's second consecutive day – [_planGymWeek].)
      if (a.eventDate != null && a.eventDistance != null) ..._raceAlternates(rotation),
      if (a.gymAssign)
        for (final r in [...a.gymPlanA.values, if (a.gymAB) ...a.gymPlanB.values])
          if (gymRefKey(r) case final k?) k,
    }.toList();
  }

  /// The programs the plan suggests for the gym days of its first two weeks (weekday → program
  /// reference, [gymProgramRef]) – the defaults of "Programme selbst zuweisen" (week A / week B).
  static ({Map<int, String> a, Map<int, String> b}) suggestedGymWeeks(UserProfile p, List<WorkoutTemplate> templates) {
    final plain = p.copyWith(athlete: p.athlete.merge({'gymAssign': false}));
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), plain, templates, () => '');
    final start = addDays(startOfWeek(DateTime.now()), 7);
    g.generate(start: start, weeks: 2);
    final picks = [
      for (final (day, ref) in g._gymPicks)
        if (daysBetween(start, day) ~/ 7 <= 1) (day, ref),
    ];
    // Weeks A and B repeat as a pair: week B's last program must not be week A's first again (review 2026-11
    // UX-10: 5 PPL days – B ended with Push, A starts with Push, and the setup warned about its own suggestion).
    // The program that takes its place: one neither neighbour has, no leg day before the long day, then (review
    // 2026-11 G3V-4: ulppl Mon/Wed/Fri put Lower A right after Legs) no leg day next to a leg day, the fewest muscle
    // groups shared with a neighbour on the day before / after, the least used, the rotation's order.
    final rotation = _rotationFor(plain.athlete, scheduleOf(plain));
    final long = longDayOf(p);
    final n = picks.length;
    for (var i = 0; n > 2 && rotation.length > 2 && i < n; i++) {
      final k = (i + 1) % n;
      if (picks[i].$2 != picks[k].$2) continue;
      final at = k == 0 ? i : k; // change week B, not the first day of week A
      final prev = picks[(at - 1 + n) % n].$2, next = picks[(at + 1) % n].$2;
      final day = picks[at].$1;
      // Days between two picks of the repeating two-week cycle.
      int gap(DateTime x, DateTime y) => (daysBetween(x, y) % 14 + 14) % 14;
      final prevInfo = g._gymInfo(prev), nextInfo = g._gymInfo(next);
      final prevNear = gap(picks[(at - 1 + n) % n].$1, day) == 1, nextNear = gap(day, picks[(at + 1) % n].$1) == 1;
      int used(String r) => picks.where((x) => x.$2 == r).length;
      int legs(String r) => g._gymInfo(r).legHeavy && (prevInfo.legHeavy || nextInfo.legHeavy) ? 1 : 0;
      int shared(String r) => (prevNear ? g._gymInfo(r).overlaps(prevInfo) : 0) + (nextNear ? g._gymInfo(r).overlaps(nextInfo) : 0);
      int rank(String x, String y) => [
        legs(x).compareTo(legs(y)),
        shared(x).compareTo(shared(y)),
        used(x).compareTo(used(y)),
        rotation.indexOf(x).compareTo(rotation.indexOf(y)),
      ].firstWhere((c) => c != 0, orElse: () => 0);
      final cands = [
        for (final r in rotation)
          if (r != prev && r != next && !(day.weekday % 7 + 1 == long && g._gymInfo(r).legHeavy)) r,
      ]..sort(rank);
      if (cands.isNotEmpty) picks[at] = (day, cands.first);
    }
    final out = (a: <int, String>{}, b: <int, String>{});
    for (final (day, ref) in picks) {
      final w = daysBetween(start, day) ~/ 7;
      final t = g._templateOfRef(ref);
      (w == 0 ? out.a : out.b)[day.weekday] = t != null ? gymProgramRef(t) : 'key:$ref';
    }
    return out;
  }

  /// Program rotation for the chosen (or recommended) split and equipment.
  static List<String> _rotationFor(AthleteData a, Map<int, List<Sport>> schedule) {
    final all = schedule.values.expand((e) => e);
    final gymDays = all.where((s) => s == Sport.gym).length;
    // Home / bodyweight: full body A/B up to 3 days; from 4 days upper / lower (review 2026-11 GYM-4: full body
    // on consecutive days loaded every muscle two days in a row).
    if (a.equipment == 'home' || a.equipment == 'bodyweight') {
      final key = a.equipment == 'home' ? 'home' : 'bodyweight';
      return splitRotation[gymDays >= 4 ? '${key}_ul' : key]!;
    }
    final endurance = all.where((s) => s != Sport.gym).length;
    final split = a.gymSplit == 'auto' ? recommendedSplit(gymDays, enduranceSessions: endurance) : a.gymSplit;
    final rot = splitRotation[split] ?? splitRotation['fullbody']!;
    // Two full-body days a week alternate A/B (C is the optional third day).
    return split == 'fullbody' && gymDays <= 2 ? rot.take(2).toList() : rot;
  }

  /// The programs a race window's second consecutive gym day takes when [rotation] has a single program
  /// without heavy leg work (the home / bodyweight upper / lower split): the full-body pair of the same
  /// equipment, trained without its leg exercises.
  static List<String> _raceAlternates(List<String> rotation) {
    for (final key in const ['home', 'bodyweight']) {
      if (rotation.join(',') == splitRotation['${key}_ul']!.join(',')) return [...splitRotation[key]!];
    }
    return const [];
  }

  /// Old (pre-key) template names, so existing users keep their programs.
  static const _legacyNames = {
    'fb_a': 'Full Body A',
    'fb_b': 'Full Body B',
    'ul_upper_a': 'Upper',
    'ul_upper_b': 'Upper',
    'ul_lower_a': 'Lower',
    'ul_lower_b': 'Lower',
    'ppl_push': 'Push',
    'ppl_pull': 'Pull',
    'ppl_legs': 'Legs',
  };

  WorkoutTemplate? _template(String key) => templates.where((t) => t.key == key).firstOrNull ?? _legacyTemplate(_legacyNames[key]);

  /// The pre-key program called [name]. Several can share the name – a duplicated folder holds
  /// "Push" / "Pull" / "Legs" again: the one in the folder with the shortest name wins ("Push Pull
  /// Legs" before "Push Pull Legs (copy)"), then folder name and id – never the document order.
  WorkoutTemplate? _legacyTemplate(String? name) {
    WorkoutTemplate? best;
    for (final t in templates) {
      if (t.name != name) continue;
      if (best == null || _legacyRank(t, best) < 0) best = t;
    }
    return best;
  }

  static int _legacyRank(WorkoutTemplate a, WorkoutTemplate b) {
    final length = a.folder.length.compareTo(b.folder.length);
    if (length != 0) return length;
    final folder = a.folder.compareTo(b.folder);
    return folder != 0 ? folder : a.id.compareTo(b.id);
  }

  /// Built-in programs in the plan's language (names and muscle groups of programs the athlete
  /// does not have).
  late final List<WorkoutTemplate> _builtins = defaultTemplates(() => '', de: l.localeName.startsWith('de'));

  /// Gym programs of the generated plan in date order (day, program reference) – [suggestedGymWeeks].
  final _gymPicks = <(DateTime, String)>[];

  /// A program reference ([gymProgramRef], or `id:<template id>` of a workout) as the queue uses it:
  /// the built-in key (also for an older copy of a built-in stored without its key, found by its
  /// legacy name), else `id:<template id>` for the athlete's own programs.
  String _normRef(String ref) {
    final key = gymRefKey(ref);
    if (key != null) return key;
    final t = _templateOfRef(ref);
    if (t == null) return ref;
    if (t.key != null) return t.key!;
    for (final k in _legacyNames.keys) {
      if (_template(k)?.id == t.id) return k;
    }
    return ref;
  }

  /// The rotation reference of a gym workout done with program [id] ([gymHistory]): [_normRef], but
  /// the athlete's changed version of a built-in that "restore the originals" turned into an own
  /// program ([WorkoutTemplate.origKey]) still counts as that built-in – the rotation continues
  /// after a restore (no Pull right after Pull) – unless the plan settings assign it by itself.
  String _historyRef(String id) {
    final norm = _normRef('id:$id');
    final base = _templateOfRef('id:$id')?.origKey;
    if (base == null || norm != 'id:$id') return norm;
    final assigned = a.gymAssign && [...a.gymPlanA.values, if (a.gymAB) ...a.gymPlanB.values].any((r) => _normRef(r) == norm);
    return assigned ? norm : base;
  }

  /// The athlete's program behind [ref] (built-in key or `id:<template id>`).
  WorkoutTemplate? _templateOfRef(String ref) {
    if (ref.startsWith('id:')) return templates.where((t) => t.id == ref.substring(3) && t.sport == Sport.gym).firstOrNull;
    return _template(ref);
  }

  /// Exercises of gym workout [w] (its own, else its program's).
  List<GymExercise> _exercisesOfWorkout(PlannedWorkout w) =>
      w.exercises.isNotEmpty ? w.exercises : (templates.where((t) => t.id == w.templateId).firstOrNull?.exercises ?? const []);

  /// Exercises of [ref]: the athlete's program, else the built-in one.
  List<GymExercise> _exercisesOfRef(String ref) =>
      _templateOfRef(ref)?.exercises ?? _builtins.where((t) => t.key == ref).firstOrNull?.exercises ?? const [];

  final _gymInfoCache = <String, _GymInfo>{};

  /// Muscle groups and leg load of [ref] ([_GymInfo]).
  _GymInfo _gymInfo(String ref) => _gymInfoCache.putIfAbsent(
    ref,
    () => _GymInfo.of(_exercisesOfRef(ref), legHeavy: legHeavyKeys.contains(_templateOfRef(ref)?.key ?? ref)),
  );

  /// The program the athlete assigned to [weekday] in plan week [weekNo] (A in even, B in odd
  /// weeks), or null (not assigned, or the program no longer exists).
  String? _assignedGym(int weekday, int weekNo) {
    if (!a.gymAssign) return null;
    final ref = (a.gymAB && weekNo.isOdd ? a.gymPlanB[weekday] : null) ?? a.gymPlanA[weekday];
    if (ref == null) return null;
    final norm = _normRef(ref);
    return _templateOfRef(norm) != null || _builtins.any((t) => t.key == norm) ? norm : null;
  }

  /// Week of the A/B alternation the plan starts with (0 = A, 1 = B): continues the weeks
  /// before [monday] (a plan set up again mid-plan keeps alternating) – by the programs of
  /// [history] in this week and the last one that match week A or B.
  int _abOffset(List<(DateTime, String)> history, DateTime monday) {
    if (!a.gymAssign || !a.gymAB) return 0;
    var votes = 0;
    for (final (day, ref) in history) {
      final d = daysBetween(monday, dayOnly(day));
      if (d < -7 || d >= 7) continue;
      final inA = a.gymPlanA[day.weekday] != null && _normRef(a.gymPlanA[day.weekday]!) == ref;
      final inB = a.gymPlanB[day.weekday] != null && _normRef(a.gymPlanB[day.weekday]!) == ref;
      if (inA == inB) continue;
      // Week A this week → the plan starts with A; week A last week → with B.
      final startsWithB = inB == (d >= 0);
      votes += startsWithB ? 1 : -1;
    }
    return votes > 0 ? 1 : 0;
  }

  /// The programs of the week's gym sessions on [days] (day, role; date order) in plan week [weekNo]
  /// (0-based incl. the A/B offset): the athlete's assignment, else the split's rotation ([_GymQueue]).
  /// Role 'nolegs': a key endurance session follows – leg-heavy programs wait if possible;
  /// [raceSoon]: no leg-heavy program at all (an assigned one gives way to the rotation).
  Map<DateTime, String> _planGymWeek(_GymQueue queue, List<(DateTime, String)> days, int weekNo, bool Function(DateTime) raceSoon) {
    _GymSlot slot(DateTime day, String role, int week) {
      final assigned = _assignedGym(day.weekday, week);
      final race = raceSoon(day);
      return _GymSlot(
        day,
        noLegs: role == 'nolegs',
        race: race,
        fixed: assigned != null && !(race && _gymInfo(assigned).legHeavy) ? assigned : null,
      );
    }

    final slots = [for (final (day, role) in days) slot(day, role, weekNo)];
    // The lookahead's next week: the same days and roles, with its own race window (none once the race is over –
    // review 2026-11 GYM-6: a copied race window made a passed-over leg day look blocked after the race too) and
    // its own assignment (week B).
    final next = [for (final (day, role) in days) slot(addDays(day, 7), role, weekNo + 1)];
    var prev =
        _gymPicks.isNotEmpty ? _gymPicks.last : (queue._lastDay != null && queue.last != null ? (queue._lastDay!, queue.last!) : null);
    final refs = queue.planWeek(slots, next);
    // Before a race an upper / lower rotation has one program left (review 2026-11 G3V-1: "Home Upper" on
    // Thursday and Friday): the second of two consecutive days takes the full-body program of the same
    // equipment instead – without its leg work ([_gym]: gymModNoLegs), the one used longest ago.
    final alternates = [
      for (final r in _raceAlternates(queue.rotation))
        if (_templateOfRef(r) != null) r,
    ];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (alternates.isNotEmpty && s.fixed == null && s.race && prev != null && prev.$2 == refs[i] && daysBetween(prev.$1, s.day) == 1) {
        final before = [for (final (_, r) in _gymPicks) r, ...refs.take(i)];
        refs[i] = (alternates..sort((x, y) => before.lastIndexOf(x).compareTo(before.lastIndexOf(y)))).first;
      }
      prev = (s.day, refs[i]);
    }
    for (var i = 0; i < slots.length; i++) {
      _gymPicks.add((slots[i].day, refs[i]));
    }
    return {for (var i = 0; i < slots.length; i++) slots[i].day: refs[i]};
  }

  /// [block] counts the loading weeks since the last deload: the RIR wave 3 → 2 → 1
  /// restarts after every deload instead of drifting against it.
  ///
  /// The workout references its program ([PlannedWorkout.templateId]) instead of copying its
  /// exercises: sets, rep ranges and exercises are always the program's (also after it was
  /// edited) – the plan periodises through load and reps in reserve only ([LoadPrescriber]: deload /
  /// taper ~10 % lighter, RIR 4). Day adaptations are [PlannedWorkout.gymMods].
  ///
  /// [week]: index of the plan week (beginner regressions in the first weeks); [deloadAhead]: a
  /// deload / taper week still follows (else the effort note does not promise one).
  PlannedWorkout _gym(
    DateTime day,
    String ref,
    Map<int, List<Sport>> schedule,
    String phase,
    int block,
    String role,
    int capMin, {
    int week = 99,
    bool deloadAhead = true,
    bool raceSoon = false,
  }) {
    final endurance = schedule.values.expand((e) => e).any((s) => s != Sport.gym);
    // C3: no heavy legs the day before a key endurance session – nor in the last 10 days before an endurance
    // race (review 2026-11 M7: deadlifts and lunges on the Wednesday before a Sunday marathon; the last heavy
    // lower-body session ≥ 7–10 days out – Rønnestad & Mujika 2014: strength is kept with ~1 session a week).
    final noLegs = raceSoon && endurance;
    final t = _templateOfRef(ref);
    final name = t?.name ?? _builtinName(ref);
    final program = t?.exercises ?? const <GymExercise>[];
    final info = _gymInfo(ref);
    // … and race week's strength is maintenance: the deload's effort (RIR 4).
    final deload = phase == 'recovery' || phase == 'taper' || noLegs;
    // Beginners stay at RIR 3 → 3 → 2 (review 2026-11 L2: technique before effort; RIR 1 is for experienced
    // lifters, Helms 2016).
    // Heart / blood pressure (review 2026-11 GYM-2): never closer than 2 reps to failure – the RIR-1 week
    // contradicted the health note's "2–3 reps in reserve" (and LoadPrescriber prescribes no AMRAP sets).
    final rir = max(hf.noStraining ? 2 : 0, deload ? 4 : (beginner ? const [3, 3, 2] : const [3, 2, 1])[min(block, 2)]);
    // Beginners (§2.3/2.4, review 2026-11 IMPORTANT 19): the first [_regressionWeeks] weeks use the
    // regression of the technically demanding lifts ([gymRegressions]); the full lifts follow afterwards.
    // Before the race: the program without its leg exercises (upper body, core).
    // C3/C4: a program with leg work the day before a key endurance session keeps all its sets –
    // the legs go lighter (load / reps in reserve), the session start uses these muscles.
    final legsBeforeKey = endurance && role == 'nolegs' && info.hasLegs && !noLegs;
    // The load adaptations the notes promise are stored too (review r7 R3/S2/S3: "legs 10–15 % lighter"
    // and the race window's "about 10 % lighter" were text only – the prescriber gave full loads and
    // AMRAP sets): [gymLoadPhase] passes them to LoadPrescriber everywhere the workout is used.
    // Health limitations (review 2026-11 GYM-2): the lifts the health note warns about are swapped in the
    // workout itself ([gymHealthMods]) – back: no axial loading, shoulder: no overhead pressing, knee / hip /
    // ankle: no jumps. Applied before the beginner regressions.
    final health = [if (hf.avoidAxialLoading) gymModNoAxial, if (hf.avoidOverhead) gymModNoOverhead, if (hf.lowImpactRun) gymModNoJump];
    final mods = [
      if (noLegs && gymModApplies(gymModNoLegs, program)) gymModNoLegs,
      for (final m in health)
        if (gymModApplies(m, program)) m,
    ];
    // (Regressions only for what the health swaps left.)
    final unregressed = applyGymMods(program, mods, gymGoal: a.gymGoal);
    if (beginner && week < _regressionWeeks && gymModApplies(gymModRegress, unregressed)) mods.add(gymModRegress);
    mods.addAll([if (noLegs) gymModRaceWeek, if (legsBeforeKey) gymModLegsEasy]);
    var exercises = applyGymMods(program, mods, gymGoal: a.gymGoal);
    // Longer than the day allows (review 2026-11 G3V-6): the last accessory exercises are left out – compound lifts
    // and every set of what stays remain the program's ([gymModShortPrefix]).
    var dropped = 0;
    if (exercises.isNotEmpty && estimateGymMinutes(exercises) > capMin) {
      dropped = exercises.length - shortenedGymExercises(exercises, capMin).length;
      if (dropped > 0) {
        mods.add(gymModShort(capMin));
        exercises = applyGymMods(program, mods, gymGoal: a.gymGoal);
      }
    }
    final minutes = exercises.isNotEmpty ? estimateGymMinutes(exercises) : (t?.estimatedMinutes ?? 60);
    // The regression note names lat pulldowns, dumbbell RDLs and reverse crunches; other regressions (bodyweight
    // programs, the assisted pull-up of a Pull day that has pulldowns already) get the general note.
    const named = {('0652', '2330'), ('0032', '1459'), ('0085', '1459'), ('0472', '0872')};
    final namedOnly = [
      for (var i = 0; i < unregressed.length && i < exercises.length; i++)
        if (unregressed[i].exId != exercises[i].exId) (unregressed[i].exId, exercises[i].exId),
    ].every(named.contains);
    // Sets, rep ranges and loads are per exercise (program + exercise_class.dart + LoadPrescriber,
    // which also applies the deload: ~10 % lighter, same sets) – the note only states what is true
    // for every exercise: the effort target and the progression.
    final notes = [
      if (phase == 'taper' || noLegs)
        l.wGymTaperNote
      else if (deload)
        l.wGymDeloadNote5
      else ...[
        gymLoadNote(l, rir, deloadAhead: deloadAhead),
        // How LoadPrescriber progresses (review 2026-11 GYM-14): bodyweight programs by reps and harder
        // variations, beginners linearly on the compound lifts, everyone else by double progression.
        // (Review G3V-5: bodyweight programs have no pull-ups / dips any more; the linear steps only where a barbell or
        // machine compound has them – dumbbell steps over 10 % progress by reps first, [smartProgression].)
        if (_bodyweightProgram(exercises))
          l.wGymProgressNoteBw2
        else if (beginner && exercises.any(_fixedStepCompound))
          l.wGymProgressNoteLinear
        else
          l.wGymProgressNote,
      ],
      if (mods.contains(gymModRegress)) namedOnly ? l.wGymRegressionNote : l.wGymRegressionNote2,
      // (Home / bodyweight programs have no leg press – their hinges, rows and jumps are swapped, review G3V-5.)
      if (mods.contains(gymModNoAxial))
        program.any((e) => _gymAxialSwapped.contains(e.exId)) ? l.healthGymBackSwapNote : l.healthGymBackSwapNoteHome,
      if (mods.contains(gymModNoOverhead)) l.healthGymShoulderSwapNote,
      if (mods.contains(gymModNoJump)) l.healthGymNoJumpNote,
      if (legsBeforeKey && !info.legHeavy) l.wGymConcurrentNote,
      if (legsBeforeKey) l.wGymLegsEasyNote,
      if (noLegs) l.wGymRaceWeekNote,
      if (dropped > 0) l.wGymShortNote(capMin),
      if (minutes > capMin) l.wGymOverTimeNote(minutes, capMin),
    ];
    return PlannedWorkout(
      id: _id(),
      date: day,
      sport: Sport.gym,
      title: name,
      description: notes.join('\n'),
      // The workout's real length (review 2026-11 GYM-12: a 46 min program was stored – and shown in reminders
      // and the calendar export – as the day's 30 min); the note above says it is longer than the day allows.
      durationMin: minutes,
      templateId: t?.id,
      intensity: deload ? 'easy' : 'moderate',
      phase: phase,
      gymMods: mods,
    );
  }

  /// Weeks a beginner's strength plan uses the regressions of [gymRegressions] (about one 4–6 week
  /// block of technique and base strength before the full lifts, §2.4).
  static const _regressionWeeks = 6;

  /// A program of bodyweight exercises only (the built-in bodyweight programs): no load to add – it
  /// progresses by reps and harder variations.
  static bool _bodyweightProgram(List<GymExercise> exercises) =>
      exercises.isNotEmpty && exercises.every((e) => e.bw ?? classifyLift(e.exId, e.name).bodyweight);

  /// Barbell / machine lifts of [gymNoAxialSwaps] (swapped for leg press, glute bridges, cable rows, seated presses –
  /// healthGymBackSwapNote); the others are the dumbbell / bodyweight hinges, rows, presses and jumps.
  static const _gymAxialSwapped = {'0043', '0032', '0085', '0027', '0605'};

  /// A compound lift loaded in fixed steps (barbell, machine, cable): a beginner's weight goes up linearly
  /// ([smartProgression] – steps ≤ 10 % of the load); dumbbells and body weight progress by reps first.
  static bool _fixedStepCompound(GymExercise e) {
    final lift = classifyLift(e.exId, e.name);
    final n = e.name.toLowerCase();
    return lift.isCompound && !lift.bodyweight && !(e.bw ?? false) && !n.contains('dumbbell') && !n.contains('kettlebell');
  }

  String _builtinName(String key) => _builtins.where((t) => t.key == key).firstOrNull?.name ?? '';

  /// Goal race pace (s/km) of the running event for race-specific work (peak phase): the
  /// target time when it is realistic in the weeks available ([GoalModel.check] ok); an
  /// ambitious / unrealistic target gives way to the realistic race-day time – goal-pace work
  /// far beyond the athlete's fitness is a classic mistake (Daniels). Without a target: the
  /// time predicted from the current VDOT. All other paces stay on the current VDOT.
  int? _goalPace() {
    final meters = Vdot.distances[a.eventDistance];
    final vdot = Vdot.of(a);
    if (meters == null) return null;
    final t = _target;
    // A conservative target never slows the race-pace work below the realistic pace (review
    // IMPORTANT 2: goal-pace 5:34 /km was slower than the base phase's M work at 5:24): the more
    // ambitious of target and realistic time. Without a target: the race-day prediction the race
    // session shows ([_racePredSec]).
    final goal =
        t != null
            ? (t.status == TargetStatus.ok ? t.ambitionSec : t.realisticSec)
            : (_racePredSec ?? (vdot == null ? null : Vdot.raceTime(vdot, meters)));
    return goal == null ? null : (goal / (meters / 1000)).round();
  }

  /// Marathon-pace work step: at goal pace (±5 s/km) when a target time is set, else the
  /// Daniels M zone of the current VDOT.
  WorkoutStep _mpStep(double km) {
    final step = _runStep('work', 'M', km: km, note: l.stepMpNote);
    final pace = _target == null || a.eventDistance != 'm' ? null : _goalPace();
    if (pace == null || step.paceMin == null) return step;
    return WorkoutStep(
      kind: 'work',
      distanceM: step.distanceM,
      zone: 'M',
      paceMin: pace - 5,
      paceMax: pace + 5,
      hrMin: step.hrMin,
      hrMax: step.hrMax,
      note: step.note,
    );
  }

  // ───────────────────────────── Race ─────────────────────────────

  /// Puts the race on the event day; the day before becomes a shake-out run, no
  /// strength in the last 3 days and nothing after the race in that week.
  void _addRace(List<PlannedWorkout> out, DateTime start) {
    final d = a.eventDate;
    // A race of a sport the plan does not train (a 10 km on a pure gym plan, [spec] null) is never placed –
    // no race, no shake-out run in a plan without a single run (audit UX-1).
    // Nor a race whose sport the week does not hold (a hybrid week of gym days only and a 10 km – audit UX-1).
    if (d == null || weeksToEvent == null || a.eventDistance == null || spec == null || !_raceInWeek) return;
    final race = dayOnly(d);
    if (race.isBefore(dayOnly(start))) return;
    final before = addDays(race, -1);
    out.removeWhere((p) {
      final diff = daysBetween(race, p.date);
      if (diff >= 0 && diff < 7) return true; // race day and the rest of race week
      if (diff == -1) return true; // replaced by the shake-out
      if (p.sport == Sport.gym && diff >= -3) return true;
      return false;
    });
    // Multisport races carry no single distance; cycling / open water are a ride / swim.
    final tri = _tri || _du;
    final raceSport = switch (spec?.sport) {
      EventSport.triathlon => Sport.swim,
      EventSport.ride => Sport.ride,
      EventSport.swim => Sport.swim,
      _ => Sport.run,
    };
    // The shake-out only in a sport the week trains: a multisport race's run, else its ride, else its swim.
    final week = _weekSports;
    final shakeSport = tri ? const [Sport.run, Sport.ride, Sport.swim].where(week.contains).firstOrNull : raceSport;
    if (shakeSport == null || before.isBefore(dayOnly(start))) {
      // No shake-out (no discipline of the race in the week, or the plan starts on race day).
    } else if (shakeSport != Sport.run) {
      // Cycling / open water: a short spin / swim with a few pick-ups the day before.
      out.add(
        shakeSport == Sport.ride
            ? _plan(
              before,
              Sport.ride,
              l.wShakeoutRide,
              l.wShakeoutRideDesc,
              'easy',
              [
                _rideStep('steady', 'Z2', 20 * 60, note: l.stepZ2RideNote),
                // Short pick-ups, as the description says – not "threshold 95–105 %" on a 91–105 % watt range (RS8).
                for (var i = 0; i < 3; i++) ...[_rideStep('work', 'Z4', 60, note: l.stepRidePickupNote), _rideStep('recovery', 'Z1', 120)],
              ],
              'taper',
              false,
            )
            : _plan(
              before,
              Sport.swim,
              l.wShakeoutSwim,
              l.wShakeoutSwimDesc,
              'easy',
              [
                _swimStep('warmup', 'REC', 300, note: l.stepSwimWu),
                for (var i = 0; i < 4; i++) ...[
                  _swimStep('work', 'TE', 50, note: l.stepSightingNote),
                  const WorkoutStep(kind: 'recovery', durationSec: 30, zone: 'REC'),
                ],
                _swimStep('cooldown', 'REC', 200),
              ],
              'taper',
              false,
            ),
      );
    } else {
      out.add(_shakeoutRun(before));
    }
    final meters = Vdot.distances[a.eventDistance];
    final cat = eventDistanceOf(a.eventDistance);
    // Distance of a single-sport race (running incl. ultra, cycling, open water).
    final km = meters != null ? meters / 1000 : (cat != null && !tri && spec != null ? cat.km : null);
    // Finish-only (run/walk starters, events without a time model): no time, no pace – a run/walker
    // planned at "26:32" for a 5 km was absurd (review C6).
    final finish = _finishBase(profile) || _longShort;
    // One source of truth for the time (review IMPORTANT 16): the target, else the realistic race-day
    // prediction the goal editor suggests ([suggestTargetTime]) and the forecast uses.
    final goal = finish ? null : (a.targetTimeSec ?? _racePredSec);
    // Race pace (A4): an ambitious / unrealistic target gives way to the realistic race-day time – it
    // would send the athlete out 2–3 % too fast, the classic way to lose a race.
    final behind = !finish && _target != null && _target!.status != TargetStatus.ok;
    final raceSec = finish ? _finishEstimateSec() : (behind ? _target!.realisticSec : (goal ?? _expectedRaceSec()));
    final pace = finish || tri || meters == null ? null : (raceSec / (meters / 1000)).round();
    final steps =
        tri || meters == null
            ? <WorkoutStep>[]
            : [
              WorkoutStep(
                kind: 'work',
                distanceM: meters,
                durationSec: finish ? raceSec : null,
                // The race's own intensity: 5 km ~I, 10 km / HM ~T, marathon M (finish-only: easy).
                // (By the race pace's actual intensity when there is one – review 2026-11 L3: an amateur's HM pace
                // is closer to M than to T.)
                zone: finish ? 'E' : (pace != null && a.eventDistance == 'hm' ? _zoneForPace(pace) : _raceZone),
                paceMin: pace == null ? null : pace - 3,
                paceMax: pace == null ? null : pace + 3,
                note: l.stepRaceNote,
              ),
            ];
    // (Localised like the legs' step notes – review 2026-11 T4: "Schwimmen 0.75 km" in German.)
    String leg(double v) => _legKm(v);
    final lg = cat?.legs ?? const <double>[];
    final legs =
        lg.length != 3 ? null : (_du ? l.wDuLegs(leg(lg[0]), leg(lg[1]), leg(lg[2])) : l.wTriLegs(leg(lg[0]), leg(lg[1]), leg(lg[2])));
    final description = [
      if (tri && legs != null) legs,
      // Open water (review 2026-11 H2): the safety rules on race day too – open-water swims, and triathlon
      // beginners / former swim novices.
      if (spec?.sport == EventSport.swim || (_tri && (_swimNovice || beginner))) l.wOpenWaterSafety,
      // Long races: the fuelling practised in training (Jeukendrup 2014).
      if (_expectedRaceSec() >= 150 * 60) l.wRaceFuelNote,
      if (behind && pace != null) ...[
        l.wRaceGoalStart(clock(a.targetTimeSec ?? raceSec), '${clock(pace)}/km'),
        l.wRaceDesc,
      ] else if (finish && (runWalkStartFor(profile) != null || _longShort))
        l.wRaceFinishDesc
      else if (goal == null)
        l.wRaceDesc
      // Multisport (review 2026-11 T8): no single goal pace – swim, bike and run each paced; a time the athlete did
      // not set is a forecast.
      else if (tri)
        _du
            ? (a.targetTimeSec == null ? l.wRaceDuForecastDesc(clock(goal)) : l.wRaceDuGoalDesc(clock(goal)))
            : (a.targetTimeSec == null ? l.wRaceTriForecastDesc(clock(goal)) : l.wRaceTriGoalDesc(clock(goal)))
      else
        a.targetTimeSec == null ? l.wRaceForecastDesc(clock(goal)) : l.wRaceGoalDesc(clock(goal)),
      // A conservative target: the realistic race-day pacing too (review round 2, IMPORTANT 5).
      if (!behind && !finish && meters != null && (_target?.conservative ?? false))
        l.wRaceRealistic(
          clock(GoalModel.roundTarget(_target!.realisticSec)),
          '${clock((_target!.realisticSec / (meters / 1000)).round())}/km',
        ),
      // Still on run/walk in race week: race with the same rhythm (Galloway-style
      // walk breaks from the start), never "run until it breaks".
      if (_rwAtRace != null)
        l.wRaceRunWalk(_raceRunMin(_rwAtRace!))
      // Long runs with walk breaks: the race keeps them (10 min run / 1 min walk).
      else if (_walkBreaks)
        l.wRaceRunWalk(10),
    ].join('\n');
    out.add(
      PlannedWorkout(
        id: _id(),
        date: race,
        // Multisport: stored as a ride – the bike is the longest leg of every triathlon / duathlon (a
        // triathlon used to be a "swim"); the legs are its steps, so the calendar, the editor and a watch
        // show swim – bike – run with distance and time each (review IMPORTANT 16).
        sport: tri ? Sport.ride : raceSport,
        title: l.wRace(_eventName()),
        description: description,
        // The race's own time (the warm-up before the start is not part of it).
        durationMin: (raceSec / 60).round(),
        // A multisport race carries no single distance ("Rad 51,5 km" would be wrong).
        distanceKm: tri ? null : km,
        intensity: 'race',
        steps: tri && lg.length == 3 ? _raceLegSteps(lg, raceSec) : steps,
        phase: 'taper',
        isKey: true,
      ),
    );
  }

  /// Race zone of a running event (the race step's label): 5 km ~VO2max (I), 10 km and HM ~threshold
  /// (T), marathon M.
  String get _raceZone => switch (a.eventDistance) {
    '5k' => 'I',
    '10k' || 'hm' => 'T',
    _ => 'M',
  };

  /// Run zone (M / T / I – with [easy] also E) whose pace range is nearest to [pace] (s/km) at the athlete's current VDOT.
  String _zoneForPace(int pace, {bool easy = false}) {
    double off(String z) {
      final (fast, slow) = pz.range(z);
      return pace < fast ? (fast - pace).toDouble() : (pace > slow ? (pace - slow).toDouble() : 0.0);
    }

    return (easy ? const ['E', 'M', 'T', 'I'] : const ['M', 'T', 'I']).reduce((x, y) => off(y) < off(x) ? y : x);
  }

  /// Legs of a multisport race as steps (triathlon swim – bike – run, duathlon run – bike – run), each
  /// with its distance and its share of [totalSec] by [GoalModel.legTimes] (transitions go to the legs
  /// before them), so the steps add up to the race time.
  List<WorkoutStep> _raceLegSteps(List<double> lg, int totalSec) {
    final sports = _du ? const [Sport.run, Sport.ride, Sport.run] : const [Sport.swim, Sport.ride, Sport.run];
    final parts = GoalModel.legTimes(profile, Vdot.of(a) ?? Vdot.defaultFor(level));
    final legSec = parts == null ? [for (final _ in lg) totalSec / lg.length] : [for (final x in parts.$1) x.toDouble()];
    final trans = parts?.$2 ?? 0;
    final sum = legSec.fold(0.0, (x, y) => x + y) + trans;
    final f = sum > 0 ? totalSec / sum : 1.0;
    final secs = [for (var i = 0; i < 3; i++) ((legSec[i] + (i < 2 ? trans / 2 : 0)) * f).round()];
    // Each leg at its race intensity (review 2026-11 tri-5: an Ironman's bike leg labelled Z3 = 76–90 % FTP, a run/walk
    // finisher's first duathlon run "T"): the bike at the event's race power ([GoalModel.raceFtpShare]: Ironman ~70 %
    // → Z2, 70.3 / olympic / sprint → Z3) with its watts when the FTP is known, the runs by the predicted leg pace;
    // finish-only athletes (run/walk, no time model) ride Z2 and run easy.
    final finish = _finishBase(profile);
    final frac = GoalModel.raceFtpShare(a.eventDistance);
    final power = finish || ftp == null ? null : ((ftp! * (frac - 0.03)).round(), (ftp! * (frac + 0.03)).round());
    String runZone(int i) {
      if (finish) return 'E';
      final pace = (secs[i] / lg[i]).round();
      // A race leg is never run at interval pace (G2-V8): at most threshold.
      final z = _zoneForPace(pace, easy: true);
      return z == 'I' ? 'T' : z;
    }

    final zones = [
      for (var i = 0; i < 3; i++)
        switch (sports[i]) {
          Sport.swim => 'EN',
          Sport.ride => finish ? 'Z2' : (frac >= 0.91 ? 'Z4' : (frac >= 0.76 ? 'Z3' : 'Z2')),
          _ => runZone(i),
        },
    ];
    // The rounding remainder goes to the last leg: the steps add up to the race time exactly.
    secs[2] += totalSec - secs.fold(0, (x, y) => x + y);
    return [
      for (var i = 0; i < 3; i++)
        WorkoutStep(
          kind: 'work',
          distanceM: lg[i] * 1000,
          durationSec: secs[i],
          zone: zones[i],
          powerMin: sports[i] == Sport.ride ? power?.$1 : null,
          powerMax: sports[i] == Sport.ride ? power?.$2 : null,
          note: l.wRaceLeg(sports[i].label(l), _legKm(lg[i])),
        ),
    ];
  }

  /// [v] km of a race leg: "0,75" / "1,9" in German, whole numbers without decimals.
  String _legKm(double v) {
    final s = v == v.roundToDouble() ? '${v.round()}' : '$v';
    return l.localeName.startsWith('de') ? s.replaceAll('.', ',') : s;
  }

  /// Shake-out the day before the race: 15 min easy plus a few strides – for a run/walker (still on
  /// run/walk, or long runs with walk breaks) the run/walk rhythm without strides: they have never
  /// run more than 10–20 min in one go (review IMPORTANT 17).
  PlannedWorkout _shakeoutRun(DateTime day) {
    if (_rwAtRace != null) {
      final run = min(300, _runWalkTable[min(_rwAtRace!, _runWalkTable.length - 1)].$1);
      final reps = max(2, (720 / (run + 60)).round());
      return _plan(
        day,
        Sport.run,
        l.wShakeout,
        l.wShakeoutRunWalkDesc,
        'easy',
        [
          _runStep('warmup', 'walk', sec: 240, note: l.stepBriskWalk),
          for (var i = 0; i < reps; i++) ...[
            _runStep('work', 'E', sec: run, note: l.stepTalkPace),
            if (i < reps - 1) _runStep('recovery', 'walk', sec: 60),
          ],
        ],
        'taper',
        false,
      );
    }
    return _plan(
      day,
      Sport.run,
      l.wShakeout,
      hf.noHardRunning || _walkBreaks ? l.wShakeoutEasyDesc : l.wShakeoutDesc,
      'easy',
      [
        _runStep('steady', 'E', sec: 15 * 60, note: l.stepEasyNote),
        // A former run/walker (long runs with walk breaks) has never done strides in the plan.
        if (!hf.noHardRunning && !_walkBreaks)
          for (var i = 0; i < 4; i++) ...[_runStep('work', 'R', sec: 20, note: l.stepStrideNote), _runStep('recovery', 'walk', sec: 60)],
      ],
      'taper',
      false,
    );
  }

  /// Finish-only goal for [p] – no race-day time anywhere (race session, [outlook], target suggestion,
  /// goal forecast): athletes who start on run/walk ([runWalkStartFor]; their level-default VDOT
  /// predicted a 1:54 HM for someone who cannot run 30 min, review C6), events without a time model
  /// ([GoalModel.hasModel]: ultra, cycling, open water, multisport without data) and beginners at a
  /// distance that is no beginner goal. The same rule as [suggestTargetTime].
  ///
  /// Also a running event whose plan never reaches the race's long run ([longRunShortFor], review r2 C6:
  /// a 3 × 30 min athlete's HM plan peaks at a 13 km long run – a 1:58 race time was promised all the
  /// same). [start] is the plan start (default today).
  static bool finishOnly(UserProfile p, {DateTime? start}) => _finishBase(p) || longRunShortFor(p, start: start ?? DateTime.now());

  static bool _finishBase(UserProfile p) =>
      runWalkStartFor(p) != null ||
      !GoalModel.hasModel(p) ||
      (p.level == 'beginner' && EventSpec.of(p.athlete.eventDistance)?.beginnerOk == false);

  /// The plan generated for [p] from [start] stays short of the running event's long run
  /// ([EventSpec.longRunKm], or [EventSpec.longRunMin] on the feet) – the race is then a finish goal.
  /// Only for plans with ≥ 6 loading weeks before the taper (a plan re-generated a few weeks before
  /// the race has no long runs left to build). Cached per profile and start week.
  static bool longRunShortFor(UserProfile p, {required DateTime start}) {
    if (_probing || _finishBase(p)) return false;
    final s = _specOf(p);
    final a = p.athlete;
    if (s == null || s.sport != EventSport.run || s.longRunKm == null || a.eventDate == null) return false;
    // (With race times or a target only a long run far short of the race's makes it a finish goal – see
    // [generate] / [_farShort].)
    final key = '${p.toMap()}|${dayKey(startOfWeek(start))}';
    final hit = _shortCache[key];
    if (hit != null) return hit;
    _probing = true;
    var short = false;
    try {
      final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '');
      g._start = start;
      if (g.weeksToEvent != null) {
        g.generate(start: start);
        short = g._longShort;
      }
    } finally {
      _probing = false;
    }
    if (_shortCache.length > 64) _shortCache.clear();
    return _shortCache[key] = short;
  }

  static final _shortCache = <String, bool>{};
  static bool _probing = false;

  /// This plan stays short of the race's long run ([longRunShortFor]); set by [generate].
  bool _longShort = false;

  /// Generating the plan of a finish goal ([_longShort]): no race-pace work (marathon-pace long runs and MP
  /// runs, goal-pace sets in the peak and the taper) – easy long runs, threshold / fartlek instead.
  bool _finishMode = false;

  /// Share of the race's long run ([_runTargetKm]) below which the plan is a finish goal whatever the
  /// athlete's race times ([_farShort]).
  static const farShortShare = 0.65;

  /// The longest run – planned in [plan] or already done ([AthleteData.longestRunKm]) – stays below
  /// [farShortShare] of the race's long run (km, or its time on the feet).
  bool _farShort(List<PlannedWorkout> plan) {
    final target = _runTargetKm;
    if (target == null) return false;
    final longs = plan.where((w) => w.sport == Sport.run && w.intensity == 'long');
    final km = max(a.longestRunKm ?? 0, longs.fold(0.0, (x, w) => max(x, runningKm(w))));
    final mins = longs.fold(0, (x, w) => max(x, w.durationMin));
    final timeOk = spec!.longRunMin != null && mins >= spec!.longRunMin! * farShortShare;
    return km < target * farShortShare && !timeOk;
  }

  /// Long run the running event needs (km): [EventSpec.longRunKm], or [EventSpec.longRunMin] at the
  /// long-run pace when that is shorter. Null without one.
  double? get _runTargetKm {
    final km = spec?.longRunKm;
    if (km == null) return null;
    return spec!.longRunMin == null ? km : min(km, _r1(spec!.longRunMin! * 60 / _longPace));
  }

  /// [plan]'s longest long run reaches [_runTargetKm] (or its time on the feet).
  bool _reachesLongRun(List<PlannedWorkout> plan) {
    final target = _runTargetKm;
    if (target == null) return true;
    final longs = plan.where((w) => w.sport == Sport.run && w.intensity == 'long');
    final km = longs.fold(0.0, (x, w) => max(x, runningKm(w)));
    final mins = longs.fold(0, (x, w) => max(x, w.durationMin));
    return km >= target - 0.5 || (spec!.longRunMin != null && mins >= spec!.longRunMin! - 5);
  }

  /// VDOT of a finish-only run/walk race estimate (C25K finishers run a 5 km in ~40–45 min).
  static const runWalkVdot = 28.0;

  /// Race duration (s) of a finish-only running race of a run/walker: the middle of the easy range at
  /// [runWalkVdot] (or the athlete's, when lower) plus ~3 % for the walk breaks – HM ~3:00, 5 km ~43
  /// min. Other finish-only events: [_expectedRaceSec].
  int _finishEstimateSec() {
    final meters = Vdot.distances[a.eventDistance];
    if (meters == null || runWalkStartFor(profile) == null) return _expectedRaceSec();
    final z = PaceZones(min(pz.vdot, runWalkVdot));
    return (meters / 1000 * (z.easyFast + z.easySlow) / 2 * 1.03).round();
  }

  /// Realistic race-day time without a target ([suggestTargetTime], the value the goal editor
  /// pre-fills); null for finish-only goals.
  late final int? _racePredSec =
      a.eventDistance == null || a.eventDate == null || _finishBase(profile)
          ? null
          : suggestTargetTime(profile, a.eventDistance!, a.eventDate!, now: _start).sec;

  /// Expected finishing time (s) when no goal is set, so the race shows a realistic
  /// duration (a marathon is not "60 min"): [GoalModel.predict] at the current VDOT (or the level
  /// default) – running from VDOT, multisport from the legs, cycling / open water from FTP / CSS.
  int _expectedRaceSec() => _raceEstSec;
  late final int _raceEstSec = GoalModel.predict(profile, Vdot.of(a) ?? Vdot.defaultFor(level)) ?? 3600;

  String _eventName() =>
      a.eventDistance == null || eventDistanceOf(a.eventDistance) == null ? l.eventTitle : eventDistanceLabel(l, a.eventDistance!);

  // ───────────────────────────── Helpers ─────────────────────────────

  int _stepSec(WorkoutStep s, Sport sport) => estimateStepSec(s, sport, easyPace: pz.easySlow, css: sz.css);

  /// Shortens a structured workout to [capSec]: first warm-up/cool-down (to 60 %),
  /// then whole repeats from the end of the main set (≥ 2 left), then everything
  /// proportionally.
  List<WorkoutStep> _fitToTime(List<WorkoutStep> steps, int capSec, Sport sport) {
    int total(List<WorkoutStep> list) => list.fold(0, (x, s) => x + _stepSec(s, sport));
    WorkoutStep scaled(WorkoutStep s, double f) => WorkoutStep(
      kind: s.kind,
      // Whole minutes for steps ≥ 2 min, so "2 × 15 min" titles match the steps (14.5 min read as 15);
      // work blocks ≥ 10 min in 5-min steps ("2 × 25 min", not "2 × 29 min").
      durationSec:
          s.durationSec == null
              ? null
              : (s.isWork && s.durationSec! * f >= 600
                  ? (sport == Sport.run ? (s.durationSec! * f / 300).round() : (s.durationSec! * f / 300).floor()) * 300
                  : (s.durationSec! * f >= 120 ? (s.durationSec! * f / 60).floor() * 60 : max(30, (s.durationSec! * f / 30).round() * 30))),
      // Interval / repetition reps stay on whole 200 m steps (400 / 600 / 800 m, not 700 m).
      distanceM:
          s.distanceM == null
              ? null
              : (s.isWork && (s.zone == 'I' || s.zone == 'R')
                  ? max(200.0, (s.distanceM! * f / 200).floor() * 200.0)
                  : max(100.0, (s.distanceM! * f / 100).round() * 100.0)),
      zone: s.zone,
      paceMin: s.paceMin,
      paceMax: s.paceMax,
      powerMin: s.powerMin,
      powerMax: s.powerMax,
      hrMin: s.hrMin,
      hrMax: s.hrMax,
      note: s.note,
    );

    var list = [...steps];
    if (total(list) <= capSec) return list;
    list = [for (final s in list) s.kind == 'warmup' || s.kind == 'cooldown' ? scaled(s, 0.6) : s];
    while (total(list) > capSec && list.where((s) => s.isWork).length > 2) {
      final lastWork = list.lastIndexWhere((s) => s.isWork);
      list.removeAt(lastWork);
      if (lastWork - 1 >= 0 && list[lastWork - 1].kind == 'recovery') list.removeAt(lastWork - 1);
    }
    // Proportionally – rounding the steps up (100 m) may still overshoot: shrink a little more then.
    final base = list;
    final t = total(base);
    var f = capSec / t;
    if (t > capSec) list = [for (final s in base) scaled(s, f)];
    // (Runs only – the ride / swim builders keep their single proportional step.)
    while (sport == Sport.run && total(list) > capSec && f > 0.05) {
      f *= 0.97;
      list = [for (final s in base) scaled(s, f)];
    }
    return list;
  }

  PlannedWorkout _plan(
    DateTime day,
    Sport sport,
    String title,
    String desc,
    String intensity,
    List<WorkoutStep> steps,
    String phase,
    bool isKey,
  ) {
    var sec = 0;
    var meters = 0.0;
    for (final s in steps) {
      sec += _stepSec(s, sport);
      if (s.distanceM != null) {
        meters += s.distanceM!;
      } else if (s.durationSec != null) {
        // Walks at the walking pace: a run/walk of 8 × 1 min covers its 21 min of walking too
        // (counting the running only gave "29 min · 1.0 km").
        if (sport == Sport.run) meters += timedRunStepM(s, pz.easySlow);
        // At the athlete's speed for the zone (review 2026-11 RS7: a fixed 27 km/h made a beginner's long ride 88 km
        // where their own race forecast said 23 km/h).
        if (sport == Sport.ride) meters += s.durationSec! / 3600 * _rideKmh(s.zone) * 1000;
      }
    }
    final km = meters <= 0 ? null : double.parse((meters / 1000).toStringAsFixed(1));
    return PlannedWorkout(
      id: _id(),
      date: day,
      sport: sport,
      title: title,
      // Deload / taper weeks say why the session is shorter (not for the race and the
      // shake-out, which explain themselves).
      description: [
        desc,
        if (phase == 'recovery' && intensity != 'race') l.wRecoveryWeekNote2,
        if (phase == 'taper' && intensity != 'race' && title != l.wShakeout) l.wTaperWeekNote,
      ].where((x) => x.isNotEmpty).join('\n'),
      durationMin: sport == Sport.run ? _runMinutes(steps, sec, km) : max(15, (sec / 60 / 5).round() * 5),
      distanceKm: km,
      intensity: intensity,
      steps: steps,
      phase: phase,
      isKey: isKey,
    );
  }

  /// Minutes of a run of [steps] ([sec] by [estimateStepSec], [km] in total): whole minutes, so the
  /// session time equals its step estimate (± 0.5 min) – the 5-min rounding made "20' / 3.5 km" imply
  /// 5:43 /km against an easy range of 5:48–6:41 and the goal forecast read a planned 38' Fahrtspiel
  /// as 40'. An easy run (E steps only, walk breaks aside) is kept inside the E range, so time and
  /// distance together never ask for a pace outside the zone (beginners without paces: estimated at
  /// the slow end).
  int _runMinutes(List<WorkoutStep> steps, int sec, double? km) {
    var m = max(15, (sec / 60).round());
    final moving = steps.where((s) => s.zone != 'walk');
    // Distance-defined easy runs only (a run/walk of timed blocks has no distance of its own to fit).
    if (km != null && km > 0 && moving.isNotEmpty && moving.every((s) => (s.zone == 'E' || s.zone == 'L') && s.distanceM != null)) {
      // ([km] counts the walk breaks' distance too: the E range applies to the running part.)
      final walk = steps.where((s) => s.zone == 'walk').fold(0, (x, s) => x + _stepSec(s, Sport.run));
      final run = double.parse((moving.fold<double>(0, (x, s) => x + s.distanceM!) / 1000).toStringAsFixed(1));
      final lo = ((run * pz.easyFast + walk) / 60).ceil(), hi = ((run * pz.easySlow + walk) / 60).floor();
      if (lo <= hi) m = m.clamp(lo, hi);
    }
    return m;
  }

  // ───────────────────────────── Feasibility ─────────────────────────────

  /// Long run (km) the event needs before the taper (null: no requirement) – [EventSpec.longRunKm]:
  /// ~70–80 % of the distance for 10 km – marathon, 70.3 16 km, Ironman 26 km, ultra 30 km (each
  /// or its time at the long-run pace, whichever is shorter).
  static double? longRunTargetFor(String? event) => EventSpec.of(event)?.longRunKm;

  /// The phases of a plan for [p] that starts at [start] and runs to race day, each with the
  /// fitness it is expected to reach by its end ([GoalModel.gain]; recovery weeks belong to the
  /// phase around them). Empty without an event in range. The expected values are a guide the
  /// goal forecast compares the athlete with – the plan's paces stay on the current fitness.
  ///
  /// [baseline]: the VDOT the plan was built with ([GoalForecast.baselineVdot]); default: the one fitness
  /// model's baseline at [start] ([FitnessState.fromProfile]) – the last phase ends at the check's
  /// realistic race-day value.
  static List<PhaseOutlook> outlook(UserProfile p, {required DateTime start, double? baseline}) {
    final g = PlanGenerator(lookupAppLocalizations(const Locale('en')), p, const [], () => '').._start = start;
    final total = g.weeksToEvent;
    if (total == null || p.athlete.eventDistance == null) return const [];
    final raw = g._phases(total);
    final phases = [...raw];
    for (var i = 0; i < phases.length; i++) {
      if (phases[i] != 'recovery') continue;
      phases[i] = i > 0 ? phases[i - 1] : (raw.firstWhere((x) => x != 'recovery', orElse: () => 'base'));
    }
    final fit = FitnessState.fromProfile(p, now: start);
    final vdot = baseline ?? fit.baseline;
    final training = max(0, daysBetween(start, startOfWeek(dayOnly(p.athlete.eventDate!))) / 7).toDouble();
    // Finish-only goals ([finishOnly], e.g. run/walk starters) get no predicted times.
    final model = !finishOnly(p, start: start);
    final out = <PhaseOutlook>[];
    for (var i = 0; i < phases.length;) {
      var j = i;
      while (j + 1 < phases.length && phases[j + 1] == phases[i]) {
        j++;
      }
      // Training weeks completed by the end of the phase (race week adds none).
      final gain = GoalModel.gain(p, min((j + 1).toDouble(), training));
      out.add(
        PhaseOutlook(
          phase: phases[i],
          firstWeek: i,
          weeks: j - i + 1,
          expectedVdot: vdot + gain,
          predictedSec: model ? GoalModel.timeAt(p, vdot, gain) : null,
        ),
      );
      i = j + 1;
    }
    return out;
  }

  /// Is the event goal of [p] realistic in the time to race day (§1.8)? The plan is
  /// generated either way; this says why it falls short and what would work: a later race
  /// date (the first one that is long enough), a shorter distance, or finishing with
  /// run/walk. Checks: entry requirements (no marathon for beginners, no HM / marathon
  /// while on run/walk), run/walk finished before race week, the long run reaching
  /// [_longRunTargetKm] / the long ride [_longRideTargetMin] – and whether the time on the
  /// long day, not the weeks, is what limits them.
  ///
  /// [fitness]: the one fitness model of the running plan ([FitnessState.of]) for the target check –
  /// mid-plan the realistic time is the forecast's race-day value.
  static PlanFeasibility feasibility(UserProfile p, {DateTime? start, AppLocalizations? l, FitnessState? fitness}) {
    final loc = l ?? lookupAppLocalizations(const Locale('en'));
    final from = start ?? DateTime.now();
    final ev = p.athlete.eventDistance;
    final weeks = (PlanGenerator(loc, p, const [], () => '').._start = from).weeksToEvent;
    // (A race the focus does not train for is no goal of this plan – the generator places no race for it, and
    // the goal card says the focus does not fit, [GoalAlignment].)
    if (ev == null || weeks == null || _specOf(p) == null) return const PlanFeasibility();
    final c = _check(loc, p, from);
    // Target time (§1.12): required vs. achievable VDOT gain – not for goals that are out of
    // reach anyway (entry requirements).
    final notAllowed = c.issues.contains('beginnerMarathon') || c.issues.contains('runWalkLong') || c.issues.contains('beginnerDistance');
    final t = notAllowed ? null : GoalModel.check(p, start: from, fitness: fitness);
    final targetIssue = switch (t?.status) {
      TargetStatus.ambitious => 'targetAmbitious',
      TargetStatus.unrealistic => 'targetUnrealistic',
      // Clearly slower than realistic (> 5 %): the race-pace work runs at the realistic pace.
      _ when t?.conservative ?? false => 'targetConservative',
      _ => null,
    };
    // The long-day note alone does not make the goal unreachable (no later date / shorter distance).
    final blocking = c.issues.where((i) => !PlanFeasibility.notes.contains(i)).toList();
    if (blocking.isEmpty) {
      return PlanFeasibility(
        issues: [...c.issues, if (targetIssue != null) targetIssue],
        weeks: weeks,
        target: t,
        longDayWeekday: c.longDayWeekday,
        longDayNeedMin: c.longDayNeedMin,
        longDay2Weekday: c.longDay2Weekday,
        longDay2NeedMin: c.longDay2NeedMin,
        timeCapMin: c.timeCapMin,
        timeCapKm: c.timeCapKm,
        timeCapRaceKm: c.timeCapRaceKm,
        capNote: c.capNote,
      );
    }
    // (Also the finish-goal fallback and the continuous swim: more weeks may build them – review r2.)
    bool timing(PlanFeasibility f) =>
        f.issues.any(const {'tooShort', 'longRunRamp', 'longRideRamp', 'runWalk', 'longRunFinish', 'longSwim'}.contains);
    DateTime? later;
    if (timing(c) && !notAllowed) {
      final race = dayOnly(p.athlete.eventDate!);
      DateTime dateAt(int w) => addDays(race, 7 * (w - weeks));
      bool fits(int w) => !timing(_check(loc, p.copyWith(athlete: p.athlete.merge({'eventDate': dateAt(w)})), from, probe: true));
      // The first later race week that is long enough – more weeks only help (in practice monotone), so a
      // binary search over weeks + 1 … 30 instead of up to 30 plans one by one (audit eng-4: 1.4 s per check,
      // rerun on every tap in the plan setup). Nothing if even 30 weeks are not enough.
      if (weeks < 30 && fits(30)) {
        var lo = weeks + 1, hi = 30;
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (fits(mid)) {
            hi = mid;
          } else {
            lo = mid + 1;
          }
        }
        later = dateAt(hi);
      }
    }
    String? shorter;
    for (final d in EventSpec.of(ev)?.shorter ?? const <String>[]) {
      if (_check(
        loc,
        p.copyWith(athlete: p.athlete.merge({'eventDistance': d})),
        from,
        probe: true,
      ).issues.every(PlanFeasibility.notes.contains)) {
        shorter = d;
        break;
      }
    }
    // "N weeks are not enough" with no later date that is long enough (audit T6): the weeks are not the limit –
    // the safe build-up from today's level is (or the finish goal already says how far the long run gets); say
    // that instead.
    // Too few runs / rides a week already name the limit of that long session – no second cause for the same
    // number (audit T6-ramp-dup; [_check] leaves the ramp out there too).
    final finishNote = c.issues.contains('longRunFinish');
    final runFreq = c.issues.contains('runFrequency'), rideFreq = c.issues.contains('rideFrequency');
    final issues = [
      for (final i in c.issues)
        if (i == 'tooShort' && later == null) ...[
          if (c.planLongKm != null && c.planLongTargetKm != null && !finishNote && !runFreq) 'longRunRamp',
          if (c.planLongRideMin != null && c.planLongRideTargetMin != null && !rideFreq) 'longRideRamp',
          if (c.planLongKm == null && c.planLongRideMin == null && !finishNote && !runFreq && !rideFreq) i,
        ] else
          i,
    ];
    return PlanFeasibility(
      issues: [...issues.toSet(), if (targetIssue != null) targetIssue],
      target: t,
      weeks: weeks,
      laterDate: later,
      shorterDistance: shorter,
      runWalkFinish: (c.issues.contains('runWalk') || c.runWalkFinish) && (EventSpec.of(ev)?.runWalkFinish ?? false),
      longRunKm: c.longRunKm,
      longRunTargetKm: c.longRunTargetKm,
      longRideMin: c.longRideMin,
      longRideTargetMin: c.longRideTargetMin,
      longSwimM: c.longSwimM,
      longSwimTargetM: c.longSwimTargetM,
      longSwimDay: c.longSwimDay,
      longSwimDayMin: c.longSwimDayMin,
      longSwimLegM: c.longSwimLegM,
      openWater: c.openWater,
      longestRunKnown: c.longestRunKnown,
      raiseDay: c.raiseDay,
      raiseDayMin: c.raiseDayMin,
      raiseDay2: c.raiseDay2,
      raiseDay2Min: c.raiseDay2Min,
      moveDay: c.moveDay,
      moveDayMin: c.moveDayMin,
      longDayWeekday: c.longDayWeekday,
      longDayNeedMin: c.longDayNeedMin,
      longDay2Weekday: c.longDay2Weekday,
      longDay2NeedMin: c.longDay2NeedMin,
      otherRunNeedMin: c.otherRunNeedMin,
      otherRunSharePct: c.otherRunSharePct,
      runsPerWeek: c.runsPerWeek,
      ridesPerWeek: c.ridesPerWeek,
      swimsPerWeek: c.swimsPerWeek,
      minRuns: c.minRuns,
      minRides: c.minRides,
      minSwims: c.minSwims,
      planLongKm: c.planLongKm,
      planLongMin: c.planLongMin,
      planLongTargetKm: c.planLongTargetKm,
      planLongRideMin: c.planLongRideMin,
      planLongRideTargetMin: c.planLongRideTargetMin,
      timeUnresolved: c.timeUnresolved,
      timeCapMin: c.timeCapMin,
      timeCapKm: c.timeCapKm,
      timeCapRaceKm: c.timeCapRaceKm,
      capNote: c.capNote,
    );
  }

  /// The long-run cap note of the event goal of [p] alone ([PlanFeasibility.capNote]) – the time step asks it on
  /// every minute tap, so without the later-date / shorter-distance search and the options (audit eng-4).
  static LongRunCapNote? longRunCapNote(UserProfile p, {DateTime? start, AppLocalizations? l}) {
    final loc = l ?? lookupAppLocalizations(const Locale('en'));
    final from = start ?? DateTime.now();
    final weeks = (PlanGenerator(loc, p, const [], () => '').._start = from).weeksToEvent;
    if (p.athlete.eventDistance == null || weeks == null || _specOf(p) == null) return null;
    return _check(loc, p, from, options: false).capNote;
  }

  /// Longest continuous swim (m) of [plan] before the taper (a work step at endurance or faster pace).
  static double _longestSwim(List<PlannedWorkout> plan) => plan
      .where((w) => w.sport == Sport.swim && w.phase != 'taper' && w.intensity != 'race')
      .expand((w) => w.steps)
      .where((s) => s.isWork && s.zone != 'DR' && s.zone != 'SP')
      .fold(0.0, (x, s) => max(x, s.distanceM ?? 0));

  /// Time (min, 15-min steps) day [weekday] needs so its long session gets [need] minutes – plus
  /// [reserve] for the run off the bike – next to the day's other sessions ([splitDayMinutes]). Never
  /// more than the long session, its reserve and the short sessions' own time: the suggestion stays a
  /// session length, not an inflated day.
  static int _dayTimeFor(UserProfile p, int weekday, int need, {int reserve = 0, bool brickDay = false}) {
    final n = max(1, scheduleOf(p)[weekday]?.length ?? 1);
    var day = ((need + reserve) / 15).ceil() * 15;
    while (splitDayMinutes(day, n, 1, true, brickDay: brickDay) - reserve < need && day < need + reserve + 60 * (n - 1) + 15) {
      day += 15;
    }
    return day;
  }

  /// Day time (min, 15 min steps) [weekday] needs so its swim gets [need] minutes next to the day's other sessions
  /// ([splitDayMinutes], the way [_capMinutes] shares the day); null when no day time gives it that much (a short
  /// session next to a long one keeps ≤ 60 min).
  static int? _swimDayTimeFor(UserProfile p, int weekday, int need) {
    final sched = scheduleOf(p);
    final n = max(1, sched[weekday]?.length ?? 1);
    final longs = longSessionDays(p);
    final swimOnly = !sched.values.any((v) => v.contains(Sport.run) || v.contains(Sport.ride));
    final isLong = swimOnly && longs[Sport.swim] == weekday;
    final nLong = longs.values.where((d) => d == weekday).length;
    final brick = _specOf(p)?.brick != null && longs[Sport.ride] == weekday;
    for (var day = (need / 15).ceil() * 15; day <= need * n + 240; day += 15) {
      if (splitDayMinutes(day, n, nLong, isLong || nLong == 0, brickDay: brick) >= need) return day;
    }
    return null;
  }

  /// [probe]: a check of a variant (later date, shorter distance, a suggested option) – only its issues
  /// count, so the cap note's second plan and the options' own verification are skipped (audit eng-4 / FUZZ-4).
  /// [options]: verify the raise / move options (off for the cap note alone, [longRunCapNote]).
  static PlanFeasibility _check(AppLocalizations l, UserProfile p, DateTime start, {bool probe = false, bool options = true}) {
    final ev = p.athlete.eventDistance!;
    final g = PlanGenerator(l, p, const [], () => '');
    final spec = g.spec;
    final issues = <String>[];
    final runs = p.focus.sports.contains(Sport.run);
    // Entry requirements (§1.8 / §14): marathon, ultra, Ironman and 5 km open water are no
    // beginner goals; no HM / marathon / ultra while still on run/walk.
    if (ev == 'm' && p.level == 'beginner') issues.add('beginnerMarathon');
    if (ev != 'm' && spec != null && !spec.beginnerOk && p.level == 'beginner') issues.add('beginnerDistance');
    // HM on run/walk (fix/plan-goal-progression): no longer ruled out – the plan builds run/walk →
    // long run/walk → long runs with walk breaks, and the checks below say whether the weeks suffice.
    if (runs && runWalkStartFor(p) != null && (ev == 'm' || ev == 'ultra50' || ev == 'ironman')) issues.add('runWalkLong');
    // Not a goal for this athlete at all (§1.8): the other checks would only add noise.
    if (issues.isNotEmpty) return PlanFeasibility(issues: issues);
    final plan = g.generate(start: start);
    if (g._rwAtRace != null) issues.add('runWalk');
    // Sessions a week (review 2026-11 H3: an Ironman on 3 days – one run, one swim a week – and a marathon on 3
    // runs had no issue at all): fewer runs / rides / swims than the race needs ([EventSpec.minRuns] …) – runs
    // unless the peak week still reaches [EventSpec.minRunKm]. More weeks do not fix it, more days do (or a
    // shorter distance).
    final sched = scheduleOf(p, afterRunWalk: true);
    int perWeek(Sport s) => sched.values.fold(0, (x, v) => x + v.where((e) => e == s).length);
    final nRuns = perWeek(Sport.run), nRides = perWeek(Sport.ride), nSwims = perWeek(Sport.swim);
    final weekRunKm = <DateTime, double>{};
    for (final w in plan.where((w) => w.sport == Sport.run && w.intensity != 'race')) {
      final k = startOfWeek(dayOnly(w.date));
      weekRunKm[k] = (weekRunKm[k] ?? 0) + runningKm(w);
    }
    final peakRunKm = weekRunKm.values.fold(0.0, max);
    // A discipline of the race without a single session in the week (a sprint triathlon week without a run
    // day) – always an issue, also where the race names no minimum (audit UX-1 / FUZZ-10).
    final raceSports = raceSportsOf(spec);
    bool none(Sport s) => raceSports.contains(s) && p.focus.sports.contains(s) && perWeek(s) == 0;
    final runFreq =
        spec != null &&
        runs &&
        (none(Sport.run) || (spec.minRuns > 0 && nRuns < spec.minRuns && (spec.minRunKm == null || peakRunKm < spec.minRunKm! - 0.5)));
    if (runFreq) issues.add('runFrequency');
    if (spec != null && p.focus.sports.contains(Sport.ride) && (nRides < spec.minRides || none(Sport.ride))) issues.add('rideFrequency');
    if (spec != null && p.focus.sports.contains(Sport.swim) && (nSwims < spec.minSwims || none(Sport.swim))) issues.add('swimFrequency');
    // The weeks are at least the recommended plan length ([recommendedWeeks]): a long run the plan cannot
    // build is then the athlete's start level and the safe weekly step (R1), not "too few weeks" (M3).
    // (Run/walk starters: the recommended lengths assume 30 min of running – their weeks are the limit.)
    final weeksOk = (g.weeksToEvent ?? 0) >= recommendedWeeks(p).min && runWalkStartFor(p) == null;
    double? shortLongKm;
    int? shortLongMin;
    // Long-run target: km, or its time at the long-run pace when that is shorter.
    final runKm = spec?.longRunKm;
    final runTarget = runKm == null ? null : (spec!.longRunMin == null ? runKm : min(runKm, g._r1(spec.longRunMin! * 60 / g._longPace)));
    double? runLimit;
    // The day whose time is too short, and the minutes it would need (feasibility options).
    int? raiseDay, raiseMin, moveNeed, shareNeedMin, raiseDay2, raiseMin2, sharePct;
    final longDays = longSessionDays(p);
    // (A week without a single run / ride / swim: its frequency issue says so – no "the long run reaches 0 km"
    // on top, audit FUZZ-10.)
    if (runs && nRuns > 0 && runTarget != null) {
      final longs = plan.where((w) => w.sport == Sport.run && w.intensity == 'long');
      final longRun = longs.fold(0.0, (x, w) => max(x, runningKm(w)));
      // Time on feet counts for slow runners ([EventSpec.longRunMin], e.g. a 2 h HM run/walk).
      final longMin = longs.fold(0, (x, w) => max(x, w.durationMin));
      final timeOk = spec!.longRunMin != null && longMin >= spec.longRunMin! - 5;
      if (longRun < runTarget - 0.5 && !timeOk) {
        // Still on run/walk by race day: the weeks are the limit, not the time on the long day.
        // (No continuous long run in a loading week at all: the weeks again.)
        // (Only when the day's time binds, not the run's own time cap [_longRunMaxMin] – more time on the
        // day changes nothing then.)
        // (… and only when the long run reaches that limit: one the volume / ramp keeps clearly below it gains
        // nothing from more time – like the long ride, audit FUZZ-4.)
        final byTime =
            g._rwAtRace == null &&
            g._longRunLimitKm > 0 &&
            g._longRunLimitKm < runTarget - 0.5 &&
            g._longRunLimitKm * g._longPace / 60 < g._longRunMaxMin - 1 &&
            longRun >= g._longRunLimitKm - 1;
        // The other runs are too short to carry the long run (≤ 50 % of the week, ≤ 2 × the next-longest
        // run): more weeks do not help, longer runs on the other days do.
        // … also when R1's weekly step alone would have gone further ([_rampMaxKm]): the week's volume and its
        // other runs keep the long run short, not the safe ramp. (Within two weekly steps of R1 – capped at the
        // race's need – counts as ramp-limited: a first long run the volume kept a step lower is still a ramp.)
        final rampLimited = g._longStepCap(g._longStepCap(longRun)) >= min(g._rampMaxKm, runTarget) - 0.25;
        final byShare = !byTime && !runFreq && g._rwAtRace == null && !rampLimited;
        // Otherwise the weeks – "N weeks are not enough" only below the recommended plan length; from it on the
        // start level and the safe weekly step are the limit ([longRunRamp], review 2026-11 M3). Too few runs
        // a week ([runFrequency]) or a finish goal ([longRunFinish]) already say why.
        final cause =
            byTime
                ? 'longRunTime'
                : (byShare ? 'longRunShare' : (!weeksOk ? 'tooShort' : (runFreq || g._longShort ? null : 'longRunRamp')));
        if (cause != null) issues.add(cause);
        shortLongKm = longRun;
        shortLongMin = longMin;
        if (byShare) {
          final m = ev == 'm' || ev == 'ultra50';
          // The other runs of the week with the longest long run: the quality runs stay as they are, the
          // easy runs carry the rest – the same share / ratio rules as [_shapeRunWeek] (3 runs: 60 % – marathon /
          // ultra 55 % – and ≤ 3.5 × the next run; 4 runs: 50 % and ≤ 2 ×; marathon 55 %, no ratio).
          final top = longs.reduce((x, y) => runningKm(y) > runningKm(x) ? y : x);
          final wk = plan.where((w) => w.sport == Sport.run && startOfWeek(w.date) == startOfWeek(top.date) && w != top).toList();
          final three = wk.length == 2;
          final share = wk.length <= 1 ? 0.55 : (three ? threeRunShareFor(ev) : (ev == 'm' ? 0.55 : 0.5));
          sharePct = (share * 100).round();
          final ratio = m || wk.length >= 4 ? 0.0 : (three ? threeRunLongRatio : 2.0);
          final q = wk.where((w) => w.intensity == 'tempo' || w.intensity == 'intervals').fold(0.0, (x, w) => x + runningKm(w));
          final nEasy = max(1, wk.where((w) => w.intensity == 'easy').length);
          final needKm = max(ratio > 0 ? runTarget / ratio : 0.0, (runTarget * (1 - share) / share - q) / nEasy);
          shareNeedMin = (needKm * g.pz.easySlow / 60 / 5).ceil() * 5;
          // Never more than the long run itself needs (review r2 C6: "other runs 90 min" next to a 60 min
          // long day): the other runs are always clearly shorter than the long run.
          final longNeed = (runTarget * g._longPace / 60).ceil();
          if (shareNeedMin >= longNeed * 0.75) shareNeedMin = max(5, (longNeed * 0.75 / 5).floor() * 5);
        }
        if (byTime) {
          runLimit = g._longRunLimitKm;
          final d = longDays[Sport.run];
          if (d != null) {
            // What the long run itself needs (never beyond its time cap, [_longRunMaxMin]; walk breaks take
            // their minute too) – and the day time that gives it that much next to the day's other
            // sessions ([splitDayMinutes]). The old "day time + the missing minutes" asked for 8 h 45 when
            // the 3 h cap, not the 8 h day, was the limit (user report 2026-11).
            final need = min(g._longRunMaxMin, (runTarget * g._longPace / 60 * (g._walkBreaks ? 11 / 10 : 1)).ceil());
            // (The day's time is the limit, so the day needs more than it has – also where the estimate says it
            // would fit: the options are verified on the plan below.)
            final day = max(_dayTimeFor(p, d, need), dayMinutesFor(p, d) + 15);
            if (day > dayMinutesFor(p, d)) {
              raiseDay = d;
              raiseMin = day;
              moveNeed = need;
            }
          }
        }
      }
    }
    // Time-capped long run (a note, not a blocker): the plan's longest long run stops at the generator's own
    // cap ([_longRunMaxMin]: marathon 3 h, ultra 3:30 h, else 2:30 h) and covers clearly less than the race's
    // usual long run – the plan stops there on purpose (time on feet) instead of asking for 4 h runs, and says
    // so honestly: a finish goal with walk breaks from the start (Galloway).
    // (Cap and distance are the plan's own – review 2026-11: [EventSpec.longRunMin], the HM's 2 h time-on-feet
    // target, was shown as "your long runs stop at 2 h / 12.5 km" while the plan ran 2:30 h / 15.5 km; and a
    // long run the week's volume kept well below the cap got "stops at 3 h" with a switch that changed nothing
    // – there [runFrequency] / [longRunShare] / [longRunRamp] name the real limit.)
    int? capMin;
    double? capKm;
    if (runs &&
        spec?.sport == EventSport.run &&
        runKm != null &&
        !issues.any(const {'longRunTime', 'longRunShare', 'tooShort', 'longRunRamp', 'runWalk'}.contains)) {
      final cap = g._longRunMaxMin;
      // (Runs beyond the cap are the opt-in extension's – the note's cap is the default one.)
      // At the cap: within one 0.5 km step of what the cap covers at the long-run pace (by distance – a
      // race-pace long run covers the cap's km in less time).
      final capped = plan.where((w) => w.sport == Sport.run && w.intensity == 'long' && w.durationMin <= cap + 2);
      final topKm = capped.fold(0.0, (x, w) => max(x, runningKm(w)));
      if (topKm >= g._floorHalf(cap * 60 / g._longPace) - 0.75 && topKm < runKm * 0.9) {
        issues.add('longRunTimeCap');
        capMin = cap;
        capKm = topKm;
      }
    }
    // The same note for the long run of a triathlon / duathlon plan (70.3, Ironman …): its cap
    // ([_longRunMaxMin]) is what the plan's longest run stops at, clearly short of the usual distance. A hard
    // cap there – no extension is offered ([EventSpec.longRunExtraMin]).
    var capHard = false;
    if (runs && spec != null && spec.multisport && runKm != null && capMin == null && g._rwAtRace == null) {
      final longs = plan.where((w) => w.sport == Sport.run && w.intensity == 'long' && w.phase != 'taper' && w.phase != 'recovery');
      final top = longs.fold<PlannedWorkout?>(null, (x, w) => x == null || w.durationMin > x.durationMin ? w : x);
      if (top != null &&
          top.durationMin >= g._longRunMaxMin - 5 &&
          runningKm(top) < runKm * 0.9 &&
          !issues.any(const {'longRunTime', 'longRunShare', 'tooShort', 'longRunRamp'}.contains)) {
        issues.add('longRunTimeCap');
        capMin = g._longRunMaxMin;
        capKm = runningKm(top);
        capHard = true;
      }
    }
    // What the note says besides the cap ([LongRunCapNote]): the time the athlete set for that day when it is
    // more than the cap (their time is not the limit – user report 2026-11: "I set 5 h, why do my long runs
    // stop at 3 h?"), and the opt-in extension ([AthleteData.longRunExtend]) with what it adds in this plan.
    LongRunCapNote? capNote;
    if (!probe && capMin != null && capKm != null && runKm != null) {
      final d = longDays[Sport.run];
      final set = d == null ? null : (p.athlete.dayMinutes[d] ?? p.athlete.sessionMinutes);
      final setForRun = set == null ? 0 : (g._longRunDayMin(dayMin: set) ?? 0);
      final extra = capHard ? 0 : g.longRunExtraEligible;
      final on = extra > 0 && p.athlete.longRunExtend;
      int? extMin;
      double? extKm;
      var extRuns = 0;
      var byVolume = false;
      if (extra > 0) {
        // The plan with the option on: how far its long runs really go (R1, the week's volume and the
        // weeks left decide – not just the cap).
        final gOn = on ? g : PlanGenerator(l, p.copyWith(athlete: p.athlete.merge({'longRunExtend': true})), const [], () => '');
        final planOn = on ? plan : gOn.generate(start: start);
        final beyond = planOn.where((w) => w.sport == Sport.run && w.intensity == 'long' && w.durationMin > capMin! + 2).toList();
        extRuns = beyond.length;
        if (beyond.isNotEmpty) {
          extMin = (beyond.fold(0, (x, w) => max(x, w.durationMin)) / 5).round() * 5;
          extKm = beyond.fold<double>(0, (x, w) => max(x, w.distanceKm ?? 0));
        }
        byVolume = beyond.isEmpty && gOn._extraWeeksFound;
      }
      capNote = LongRunCapNote(
        capMin: capMin,
        capKm: capKm,
        raceKm: runKm,
        hard: capHard,
        setDay: setForRun > capMin ? d : null,
        setDayMin: setForRun > capMin ? set : null,
        extendMaxMin: extra > 0 ? capMin + extra : null,
        extendMin: extMin,
        extendKm: extKm,
        extendRuns: extRuns,
        extendOn: on,
        noGainByVolume: byVolume,
      );
    }
    // The plan never reaches the race's long run: it plans the race as a finish goal without a time
    // ([finishOnly]) – say so (review r2 C6).
    if (g._longShort && nRuns > 0) issues.add('longRunFinish');
    final rideTarget = spec?.longRideMin;
    int? rideLimit, rideShortMin;
    if (rideTarget != null && p.focus.sports.contains(Sport.ride) && nRides > 0) {
      final longRide = plan.where((w) => w.sport == Sport.ride && w.intensity == 'long').fold(0, (x, w) => max(x, w.durationMin));
      if (longRide < rideTarget * 0.9) {
        // (Only when the day's time binds: a long ride the bike volume / few rides keep far below the day's cap
        // gains nothing from more time – audit FUZZ-4: "the day allows only 195 min" next to 80 min long rides.)
        final byTime = g._longRideLimitMin < rideTarget * 0.9 && longRide >= g._longRideLimitMin - 5;
        // Like the long run: "N weeks are not enough" only below the recommended plan length – from it on the
        // start level and the safe weekly step are the limit ([longRideRamp]), and too few rides a week
        // ([rideFrequency]) already say why (audit T6: "30 Wochen reichen nicht" for an Ironman at its
        // maximum plan length with one ride a week – no later date could help).
        final rideWeeksOk = (g.weeksToEvent ?? 0) >= recommendedWeeks(p).min;
        final issue = byTime ? 'longRideTime' : (!rideWeeksOk ? 'tooShort' : (issues.contains('rideFrequency') ? null : 'longRideRamp'));
        if (!byTime) rideShortMin = longRide;
        if (byTime) {
          rideLimit = g._longRideLimitMin;
          final d = longDays[Sport.ride];
          if (d != null) {
            // The long ride's target (≤ its cap) plus the brick run's time on that day, next to the day's
            // other sessions – not "day time + the missing minutes".
            final reserve = g._brickReserve;
            final day = max(_dayTimeFor(p, d, rideTarget, reserve: reserve, brickDay: spec!.brick != null), dayMinutesFor(p, d) + 15);
            if (day > dayMinutesFor(p, d)) {
              if (raiseDay == null) {
                raiseDay = d;
                raiseMin = day;
                // On a day of its own the long ride needs its target plus the brick run's time.
                moveNeed = rideTarget + reserve;
              } else if (raiseDay != d) {
                // Long run and long ride both short of time (triathlon): both days.
                raiseDay2 = d;
                raiseMin2 = day;
              } else {
                // … on the same day (one training day, or long run and brick on Sunday): the day needs time for
                // both – "raise Tue to 75'" fixed the run and left the ride short (audit FUZZ-9).
                raiseMin = max(raiseMin!, _dayTimeFor(p, d, (moveNeed ?? 0) + rideTarget, reserve: reserve, brickDay: spec.brick != null));
                moveNeed = (moveNeed ?? 0) + rideTarget + reserve;
              }
            }
          }
        }
        if (issue != null && !issues.contains(issue)) issues.add(issue);
      }
    }
    // Continuous swim: open-water races their [EventSpec.longSwimM]; triathlon the longest
    // endurance repeat of the distance (sprint 400 m, olympic / 70.3 800 m, Ironman 1000 m).
    // Open-water races (review 2026-11 H2): at least ~80 % of the race distance in one go before the taper –
    // open water has no wall to hold on to (blocking: a later date / a shorter distance, and the safety rules).
    var swimTarget = g._swimTargetM;
    final openWater = spec?.sport == EventSport.swim;
    double? swimHave;
    int? swimDay, swimDayMin;
    if (swimTarget != null && p.focus.sports.contains(Sport.swim) && nSwims > 0) {
      final race = openWater ? (eventDistanceOf(ev)?.km ?? 0) * 1000 : 0.0;
      final need = max(swimTarget * 0.9, race * 0.8);
      final longest = _longestSwim(plan);
      if (longest < need - 1e-9) {
        swimHave = longest;
        swimTarget = max(swimTarget, (race * 0.8 / 100).ceil() * 100.0);
        issues.add('longSwim');
        // The day's time cut the continuous swim (review 2026-11 tri-7): that day is the fix – raise its time to what a
        // session with the target in one go needs next to the day's other sessions.
        var d = g._swimLimitDay;
        var day = d == null ? null : _swimDayTimeFor(p, d, g._swimLimitMin);
        // Only a day time that really resolves it (review 2026-11 G2-V5: the raised day reshuffled the week and the swim
        // stayed at 1700 m): the plan with that day time is checked – else the note names no day.
        if (d != null && day != null && day > dayMinutesFor(p, d)) {
          final q = p.copyWith(
            athlete: p.athlete.merge({
              'dayMinutes': {...p.athlete.dayMinutes, d: day},
            }),
          );
          if (_longestSwim(PlanGenerator(l, q, const [], () => '').generate(start: start)) < need - 1e-9) d = day = null;
        }
        if (d != null) {
          swimDay = d;
          swimDayMin = day;
          if (day != null && day > dayMinutesFor(p, d)) {
            if (raiseDay == null) {
              raiseDay = d;
              raiseMin = day;
            } else if (raiseDay != d && raiseDay2 == null) {
              raiseDay2 = d;
              raiseMin2 = day;
            }
          }
        }
      }
    }
    // Time-limited long session: raise that day's time to what it needs (in 15 min steps), or move
    // the long session to a training day that already has that much time.
    int? moveDay, moveMin;
    // Every option is checked on the plan it gives: the time-limited long sessions must no longer be
    // time-limited (audit FUZZ-4 / FUZZ-9: "move the long session to Monday" left the multisport long run on
    // Friday, "raise Tue to 75'" left the long ride on the same day short). Not in a probe (no options there).
    const timeIssues = {'longRunTime', 'longRideTime'};
    bool fixes(UserProfile q) => !_check(l, q, start, probe: true).issues.any(timeIssues.contains);
    if (!probe && !options) raiseDay = raiseMin = raiseDay2 = raiseMin2 = null;
    // (The move is looked for also when no raise works – the day to move from and the time the long session needs. Only
    // for a long run / ride: a swim held by its day's time has no "long day" to move to, and its raise was checked above.)
    final moveFrom = raiseDay, moveNeedMin = moveNeed, oneShort = raiseDay2 == null;
    if (!probe && raiseDay != null && raiseMin != null && moveNeed != null) {
      // The day time that really fixes it: the suggestion, else a few 15-min steps more (the day's other
      // sessions take their share too); none found – no raise option rather than one that changes nothing.
      UserProfile raised(int m1, int? m2) => p.copyWith(
        athlete: p.athlete.merge({
          'dayMinutes': {...p.athlete.dayMinutes, raiseDay!: m1, if (raiseDay2 != null && m2 != null) raiseDay2: m2},
        }),
      );
      int? ok1, ok2;
      for (var i = 0; i < 6 && ok1 == null; i++) {
        final m1 = raiseMin + 15 * i, m2 = raiseMin2 == null ? null : raiseMin2 + 15 * i;
        if (fixes(raised(m1, m2))) (ok1, ok2) = (m1, m2);
      }
      // More time on a day that is not the long day makes it the long day ([_longDayFrom]: most time) – the long
      // sessions swap days and the other one is short then (audit FUZZ-4: raising Friday's long ride moved it to
      // Sunday). The long day keeps at least as much time as the raised day, so it stays the long day.
      final ld = longDayOf(p);
      if (ok1 == null && raiseDay2 == null && p.longDay == null && ld != null && ld != raiseDay) {
        for (var i = 0; i < 6 && ok1 == null; i++) {
          final m1 = raiseMin + 15 * i;
          // (Ties: the later day is the long day.)
          final m2 = max(dayMinutesFor(p, ld), ld > raiseDay ? m1 : m1 + 15);
          final q = raised(m1, null);
          if (fixes(
            q.copyWith(
              athlete: q.athlete.merge({
                'dayMinutes': {...q.athlete.dayMinutes, ld: m2},
              }),
            ),
          )) {
            (ok1, ok2) = (m1, m2);
            raiseDay2 = ld;
          }
        }
      }
      if (ok1 == null) {
        raiseDay = raiseMin = raiseDay2 = raiseMin2 = null;
      } else {
        raiseMin = ok1;
        raiseMin2 = ok2;
      }
    }
    if (!probe && moveFrom != null && moveNeedMin != null && oneShort) {
      // Days with time enough for the long session alone (other sessions move with the long day), most time
      // first – the first one whose plan really puts the long session there and gives it its time.
      final days =
          scheduleOf(p).keys.where((d) => d != moveFrom && dayMinutesFor(p, d) >= moveNeedMin).toList()
            ..sort((x, y) => dayMinutesFor(p, y).compareTo(dayMinutesFor(p, x)));
      for (final d in days.take(3)) {
        if (fixes(p.copyWith(longDay: d))) {
          moveDay = d;
          moveMin = dayMinutesFor(p, d);
          break;
        }
      }
    }
    // A time-limited long session no raise and no move resolves (the week's layout puts it on another day than the
    // one raised): the day's time is not the whole story – the text must not blame it alone (audit FUZZ-4).
    final timeUnresolved = !probe && options && issues.any(timeIssues.contains) && raiseDay == null && moveDay == null;
    // The long-day default ([dayMinutesFor] / [longDayDefault]) gives the long session more time than
    // the athlete set for that day – say so instead of silently overriding it (review C9: a 3 × 30 min
    // athlete got 120' long runs).
    // Every day of a long session – the long day, the second sport's long session (the triathlon's long run),
    // the ultra's back-to-back run – gets the second-long default too (review 2026-11 tri-3: a 165 min long run
    // on a Friday left at the 60 min session time, without a word).
    final defaulted = <(int, int)>[];
    final ld = longDayOf(p);
    // (Detailed setup only: there the athlete typed the times; the quick setup's session time is a default.)
    final b2bDay = backToBackDay(p);
    for (final d in {if (ld != null) ld, ...longDays.values, if (b2bDay != null) b2bDay}) {
      if (!p.athlete.advanced || p.athlete.dayMinutes[d] != null) continue;
      final perDay = <DateTime, int>{};
      for (final w in plan.where((w) => w.date.weekday == d && w.intensity != 'race')) {
        perDay[dayOnly(w.date)] = (perDay[dayOnly(w.date)] ?? 0) + w.durationMin;
      }
      final need = perDay.values.fold(0, max);
      final set = p.athlete.sessionMinutes;
      // A long run somewhat longer than the other days is expected; ≥ 1.5 × the set time is not.
      if (need >= set * 1.5 && need > set + 10) defaulted.add((d, (need / 15).ceil() * 15));
    }
    defaulted.sort((x, y) => x.$1.compareTo(y.$1));
    if (defaulted.isNotEmpty) issues.add('longDayDefault');
    final longDay = defaulted.firstOrNull?.$1, longDayNeed = defaulted.firstOrNull?.$2;
    final longDay2 = defaulted.length > 1 ? defaulted[1].$1 : null, longDayNeed2 = defaulted.length > 1 ? defaulted[1].$2 : null;
    return PlanFeasibility(
      issues: issues,
      longDayWeekday: longDay,
      longDayNeedMin: longDayNeed,
      longDay2Weekday: longDay2,
      longDay2NeedMin: longDayNeed2,
      otherRunNeedMin: shareNeedMin,
      otherRunSharePct: sharePct,
      planLongKm:
          g._longShort
              ? plan.where((w) => w.sport == Sport.run && w.intensity == 'long').fold<double>(0, (x, w) => max(x, runningKm(w)))
              : shortLongKm,
      planLongMin: shortLongMin,
      planLongTargetKm: g._longShort || shortLongKm != null ? g._runTargetKm : null,
      runsPerWeek: nRuns,
      ridesPerWeek: nRides,
      swimsPerWeek: nSwims,
      minRuns: spec?.minRuns,
      minRides: spec?.minRides,
      minSwims: spec?.minSwims,
      // A former run/walker whose long runs keep walk breaks can race the same way.
      runWalkFinish: g._walkBreaks && (issues.contains('tooShort') || issues.contains('longRunRamp')),
      longRunKm: runLimit,
      longRunTargetKm: runLimit == null ? null : runTarget,
      longRideMin: rideLimit,
      longRideTargetMin: rideLimit == null ? null : rideTarget,
      longSwimM: swimHave,
      longSwimTargetM: swimHave == null ? null : swimTarget,
      longSwimDay: swimHave == null ? null : swimDay,
      longSwimDayMin: swimHave == null || swimDay == null ? null : swimDayMin,
      // A triathlon's target is the plan's training goal, not what the race needs – the text names the leg (T11).
      longSwimLegM:
          swimHave == null || openWater || spec?.sport != EventSport.triathlon ? null : (eventDistanceOf(ev)?.legs.firstOrNull ?? 0) * 1000,
      openWater: openWater,
      longestRunKnown: p.athlete.longestRunKm != null,
      raiseDay: raiseDay,
      raiseDayMin: raiseMin,
      moveDay: moveDay,
      moveDayMin: moveMin,
      timeCapMin: capMin,
      timeCapKm: capKm,
      timeCapRaceKm: capKm == null ? null : runKm,
      capNote: capNote,
      raiseDay2: raiseDay2,
      raiseDay2Min: raiseMin2,
      planLongRideMin: rideShortMin,
      planLongRideTargetMin: rideShortMin == null ? null : rideTarget,
      timeUnresolved: timeUnresolved,
    );
  }
}

/// The `longRunTimeCap` note of [PlanFeasibility]: the plan's long runs stop at a time cap that covers clearly
/// less than the race's usual long run. The cap is a decision of the plan, not a lack of the athlete's time –
/// the note says so, names the time the athlete set, and offers the opt-in extension where there is one.
class LongRunCapNote {
  const LongRunCapNote({
    required this.capMin,
    required this.capKm,
    required this.raceKm,
    this.hard = false,
    this.setDay,
    this.setDayMin,
    this.extendMaxMin,
    this.extendMin,
    this.extendKm,
    this.extendRuns = 0,
    this.extendOn = false,
    this.noGainByVolume = false,
  });

  /// The cap (min), the distance it covers at the athlete's long-run pace, and the race's usual long run (km).
  final int capMin;
  final double capKm, raceKm;

  /// A cap without an extension by design (long run of a triathlon / duathlon plan).
  final bool hard;

  /// The athlete set more time than the cap for the long run's day: weekday (1 = Monday) and that time (min).
  final int? setDay, setDayMin;

  /// The extension this athlete can switch on ([PlanGenerator.longRunExtraEligible]): the cap with it (min) –
  /// null: nothing to offer (the switch is not shown).
  final int? extendMaxMin;

  /// What the extension reaches in this plan: longest long run (min, km covered incl. walk breaks) and the
  /// number of runs beyond the cap – null / 0 when the plan cannot use it (e.g. too few weeks left).
  final int? extendMin;
  final double? extendKm;
  final int extendRuns;

  /// The athlete switched the extension on ([AthleteData.longRunExtend]).
  final bool extendOn;

  /// The extension is on and reaches the race's usual long run (≥ 90 %): no finish-goal advice any more.
  bool get reachesRace => extendOn && extendKm != null && extendKm! >= raceKm * 0.9;

  /// The extension is on but the plan has no run beyond the cap ([gains] false) although it had the weeks for
  /// one: the week's running volume keeps the long run at the cap (else: too few weeks before the race).
  final bool noGainByVolume;

  /// The plan with the extension has runs beyond the cap. The generator only plans one that covers at least
  /// [PlanGenerator.longRunExtraGainKm] more than the plain run at the cap ([PlanGenerator._extensionWorth]) –
  /// one criterion for plan and note.
  bool get gains => extendRuns > 0 && extendMin != null && extendKm != null;

  /// The switch belongs next to the note: there is something to switch on, or it is on (and can be taken back).
  bool get showSwitch => extendMaxMin != null && (gains || extendOn);

  /// The note: cap → why ("not your time" with the time set) → honest finish-goal advice unless the extension
  /// reaches the race's long run → the extension last (offer, or what is planned / why nothing is).
  String text(AppLocalizations l, {required String Function(int weekday) dayName, bool canSwitch = false}) {
    final cap = PlanFeasibility._dur(capMin);
    String km(double v) => PlanFeasibility._kmText(l, v);
    final ext = extendMin == null ? '' : PlanFeasibility._dur(extendMin!);
    final set = setDay != null && setDayMin != null;
    return [
      extendOn && gains ? l.feasCapLineUsual(cap, km(capKm), km(raceKm)) : l.feasCapLine(cap, km(capKm), km(raceKm)),
      if (hard) ...[
        if (set) l.feasCapNotYourTime(PlanFeasibility._dur(setDayMin!), dayName(setDay!)),
        l.feasCapWhyTri,
      ] else
        set ? l.feasCapWhySet(dayName(setDay!), PlanFeasibility._dur(setDayMin!)) : l.feasCapWhy,
      if (!reachesRace) hard ? l.feasCapFinishTri : l.feasCapFinish,
      if (gains && extendOn) l.feasCapExtended(ext, km(extendKm!)),
      if (gains && !extendOn) canSwitch ? l.feasCapOffer(ext, km(extendKm!)) : l.feasCapOfferSettings(ext, km(extendKm!)),
      if (extendOn && !gains) noGainByVolume ? l.feasCapExtendedNoGainVolume : l.feasCapExtendedNoGain,
    ].join(' ');
  }
}

/// Result of [PlanGenerator.feasibility].
class PlanFeasibility {
  const PlanFeasibility({
    this.issues = const [],
    this.weeks,
    this.laterDate,
    this.shorterDistance,
    this.runWalkFinish = false,
    this.longRunKm,
    this.longRunTargetKm,
    this.longRideMin,
    this.longRideTargetMin,
    this.longSwimM,
    this.longSwimTargetM,
    this.longSwimDay,
    this.longSwimDayMin,
    this.longSwimLegM,
    this.raiseDay,
    this.raiseDayMin,
    this.raiseDay2,
    this.raiseDay2Min,
    this.moveDay,
    this.moveDayMin,
    this.target,
    this.longDayWeekday,
    this.longDayNeedMin,
    this.longDay2Weekday,
    this.longDay2NeedMin,
    this.otherRunNeedMin,
    this.planLongKm,
    this.planLongMin,
    this.planLongTargetKm,
    this.timeCapMin,
    this.timeCapKm,
    this.timeCapRaceKm,
    this.capNote,
    this.otherRunSharePct,
    this.runsPerWeek,
    this.ridesPerWeek,
    this.swimsPerWeek,
    this.minRuns,
    this.minRides,
    this.minSwims,
    this.openWater = false,
    this.longestRunKnown = true,
    this.planLongRideMin,
    this.planLongRideTargetMin,
    this.timeUnresolved = false,
  });

  /// `longRunTime` / `longRideTime` that no raise of a day and no move of the long day resolves: the text names
  /// the week's layout, not the day's time alone (audit FUZZ-4).
  final bool timeUnresolved;

  /// `longRideRamp`: the longest long ride (min) the plan builds by race day, and what the race needs.
  final int? planLongRideMin, planLongRideTargetMin;

  /// `longRunRamp`: the athlete stated their longest recent run (else the plan started from a guess).
  final bool longestRunKnown;

  /// `longSwim` of an open-water swimming race (the text adds the open-water safety rules).
  final bool openWater;

  /// Issues that are notes about the plan, not reasons the goal is out of reach (no later date / shorter
  /// distance is searched for them).
  static const notes = {'longDayDefault', 'longRunTimeCap'};

  /// `runFrequency` / `rideFrequency` / `swimFrequency`: sessions a week the plan has and the race needs
  /// ([EventSpec.minRuns] …).
  final int? runsPerWeek, ridesPerWeek, swimsPerWeek, minRuns, minRides, minSwims;

  /// `longRunShare`: the long run's share of the week (%) the plan keeps.
  final int? otherRunSharePct;

  /// Only notes ([notes]) – the goal itself is fine.
  bool get onlyNotes => issues.isNotEmpty && issues.every(notes.contains);

  /// `longRunTimeCap`: the long run stops at its time cap [timeCapMin] (min), about [timeCapKm] km at the
  /// athlete's easy pace, while the race's long run is usually [timeCapRaceKm] km.
  final int? timeCapMin;
  final double? timeCapKm, timeCapRaceKm;

  /// `longRunTimeCap`: what the note says besides the cap – the time the athlete set for that day and the
  /// opt-in extension ([LongRunCapNote]).
  final LongRunCapNote? capNote;

  /// Minutes as "75 min" / "2 h" / "2:15 h" with non-breaking spaces (the app-wide duration style – "2 h 00"
  /// wrapped as "2" / "h 00" on narrow phones).
  static String _dur(int m) {
    if (m < 90) return '$m min';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '$h h' : '$h:${r.toString().padLeft(2, '0')} h';
  }

  static String _kmText(AppLocalizations l, double v) {
    final s = (v - v.roundToDouble()).abs() < 0.05 ? '${v.round()}' : v.toStringAsFixed(1);
    return l.localeName.startsWith('de') ? s.replaceAll('.', ',') : s;
  }

  /// `longRunFinish`: the longest long run the plan reaches (km) and the race's long run (km).
  final double? planLongKm, planLongTargetKm;

  /// Time (min) of the plan's longest long run when it stays short of the race's ([planLongKm]) – `runFrequency`
  /// names it: the runs a week, not the long run's time cap, keep it there.
  final int? planLongMin;

  /// `longDayDefault`: the long session on [longDayWeekday] (1 = Monday) needs up to [longDayNeedMin]
  /// minutes (15-min steps) – ≥ 1.5 × the time the athlete set; the plan uses the event's long-day
  /// default ([PlanGenerator.longDayDefault]) there.
  final int? longDayWeekday, longDayNeedMin;

  /// `longDayDefault` on a second day (the other sport's long session, e.g. the triathlon's long run next to
  /// the long ride): weekday and minutes as [longDayWeekday] / [longDayNeedMin].
  final int? longDay2Weekday, longDay2NeedMin;

  /// `longRunShare`: each of the other runs needs about this many minutes so the race's long run fits the
  /// week's share (3 runs ≤ 65 % / ≤ 3.5 × the next run, 4 runs ≤ 50 % / ≤ 2 ×) – never ≥ ¾ of the long run.
  final int? otherRunNeedMin;

  /// Text of the issues this class added in review C9 / IMPORTANT 2 (`longDayDefault`,
  /// `longRunShare`, `targetConservative`); null for the others (the feasibility card has them).
  /// [dayName] names a weekday (1 = Monday).
  /// [canSwitch]: the long-run extension can be switched right there (else the note says where).
  String? extraIssueText(AppLocalizations l, String issue, {required String Function(int weekday) dayName, bool canSwitch = false}) =>
      switch (issue) {
        'longDayDefault' when longDayWeekday != null && longDayNeedMin != null && longDay2Weekday != null && longDay2NeedMin != null => l
            .feasLongDayDefault2(dayName(longDayWeekday!), _dur(longDayNeedMin!), dayName(longDay2Weekday!), _dur(longDay2NeedMin!)),
        'longDayDefault' when longDayWeekday != null && longDayNeedMin != null => l.feasLongDayDefault(
          dayName(longDayWeekday!),
          _dur(longDayNeedMin!),
        ),
        'longRunShare' => l.feasLongRunShare3(otherRunSharePct ?? 50, otherRunNeedMin ?? 0),
        // No session of the sport at all (a triathlon week without a run day): "0 runs … your longest long run
        // reaches about 0 km (0 min)" said nothing (audit FUZZ-10) – the week needs such days first.
        'runFrequency' when (runsPerWeek ?? 0) == 0 => l.feasNoRuns(max(1, minRuns ?? 1)),
        'rideFrequency' when (ridesPerWeek ?? 0) == 0 => l.feasNoRides(max(1, minRides ?? 1)),
        'swimFrequency' when (swimsPerWeek ?? 0) == 0 => l.feasNoSwims(max(1, minSwims ?? 1)),
        'longRideRamp' when planLongRideMin != null && planLongRideTargetMin != null => l.feasLongRideRamp(
          _dur(planLongRideMin!),
          weeks ?? 0,
          _dur(planLongRideTargetMin!),
        ),
        'runFrequency' => [
          l.feasRunFrequency('${runsPerWeek ?? 0}', '${minRuns ?? 0}'),
          // What that means for the long run – its real limit and real numbers (review 2026-11: the time-cap
          // note said "stops at 3 h / 21.5 km" for a plan whose long runs peaked at 19.5 km / 2:42 h).
          // (Not next to the finish-goal note, which says the same distances – one statement, not two.)
          if (planLongKm != null &&
              planLongMin != null &&
              planLongTargetKm != null &&
              planLongKm! < planLongTargetKm! - 0.5 &&
              !issues.contains('longRunFinish'))
            l.feasRunFrequencyLong(_kmText(l, planLongKm!), _dur(planLongMin!), _kmText(l, planLongTargetKm!)),
        ].join(' '),
        'rideFrequency' => l.feasRideFrequency('${ridesPerWeek ?? 0}', '${minRides ?? 0}'),
        'swimFrequency' => l.feasSwimFrequency('${swimsPerWeek ?? 0}', '${minSwims ?? 0}'),
        'longRunRamp' when planLongKm != null && planLongTargetKm != null => [
          l.feasLongRunRamp(_kmText(l, planLongKm!), weeks ?? 0, _kmText(l, planLongTargetKm!)),
          // The start was a guess: the athlete's real longest run may let the plan build from further up.
          if (!longestRunKnown) l.feasLongRunRampHint,
        ].join(' '),
        'longRunTimeCap' when capNote != null => capNote!.text(l, dayName: dayName, canSwitch: canSwitch),
        'longRunTimeCap' when timeCapMin != null && timeCapKm != null && timeCapRaceKm != null => l.feasLongRunTimeCap(
          _dur(timeCapMin!),
          _kmText(l, timeCapKm!),
          _kmText(l, timeCapRaceKm!),
        ),
        'longRunFinish' when planLongKm != null && planLongTargetKm != null => l.feasLongRunFinish(
          _kmText(l, planLongKm!),
          _kmText(l, planLongTargetKm!),
        ),
        'targetConservative' when target != null => l.feasTargetConservative(
          clock(target!.targetSec),
          clock(target!.currentSec),
          clock(target!.realisticSec),
        ),
        _ => null,
      };

  /// Longest continuous swim (m) the plan reaches before the taper and what the race needs.
  final double? longSwimM;
  final double? longSwimTargetM;

  /// `longSwim`: the day whose time cut the continuous swim (1 = Monday; null: the weeks, not the time, were the
  /// limit) and – triathlon – the race's swim leg (m), so the text calls [longSwimTargetM] the plan's goal.
  final int? longSwimDay;
  final double? longSwimLegM;

  /// `longSwim` held by [longSwimDay]'s time: the day time (min) a session with the target in one go needs there
  /// (null: no day time holds it next to the day's other sessions).
  final int? longSwimDayMin;

  /// The long session is limited by the time on its day: raise [raiseDay] (1 = Monday) to
  /// [raiseDayMin] minutes – or move the long session to [moveDay], which already has [moveDayMin].
  final int? raiseDay, raiseDayMin, moveDay, moveDayMin;

  /// Long run and long ride both limited by their days' time (triathlon / duathlon): the long ride's
  /// day [raiseDay2] needs [raiseDay2Min] minutes as well ([raiseDay] is the long run's).
  final int? raiseDay2, raiseDay2Min;

  /// Why the goal is not realistic, most important first: `beginnerMarathon`,
  /// `runWalkLong` (HM / marathon while still on run/walk), `runWalk` (still on run/walk
  /// in race week), `tooShort` (too few weeks to build the long session), `longRunTime` /
  /// `longRideTime` (the time on the long day caps the long session), `longSwim` (the continuous
  /// swim stays short of the race's), `beginnerDistance` (ultra / Ironman / 5 km open water as a
  /// beginner), `longRunShare` (the other runs are too short for the race's long run, [otherRunNeedMin]),
  /// `longRunFinish` (the plan never reaches the race's long run, so the race is a finish goal without a time,
  /// [planLongKm] / [planLongTargetKm]), `longDayDefault` (a note, not a blocker: the long day uses more time than the athlete set,
  /// [longDayNeedMin]), `targetAmbitious` / `targetUnrealistic` (the target time needs more fitness
  /// than the weeks can give), `targetConservative` (> 5 % slower than realistic).
  final List<String> issues;

  /// Target-time check (null without a target time).
  final TargetCheck? target;

  /// Only the target time is the problem – the event itself is fine.
  bool get onlyTarget => issues.isNotEmpty && issues.every((i) => i.startsWith('target'));
  bool get ok => issues.isEmpty;
  String? get reason => issues.firstOrNull;

  /// Weeks to race day (incl. race week).
  final int? weeks;

  /// First race date (same weekday, later week) that is long enough – null if none ≤ 30 weeks.
  final DateTime? laterDate;

  /// Largest shorter distance that works by the race date.
  final String? shorterDistance;

  /// The race can be finished with run/walk (5 / 10 km, sprint / olympic).
  final bool runWalkFinish;

  /// Longest long run (km) / ride (min) the time on its day allows, and what is needed.
  final double? longRunKm;
  final double? longRunTargetKm;
  final int? longRideMin;
  final int? longRideTargetMin;
}

/// One phase of [PlanGenerator.outlook].
class PhaseOutlook {
  const PhaseOutlook({required this.phase, required this.firstWeek, required this.weeks, required this.expectedVdot, this.predictedSec});

  /// base | build | peak | taper.
  final String phase;

  /// Index of its first week in the plan (0 = the plan's first week) and its length.
  final int firstWeek, weeks;

  /// Running fitness expected by the end of the phase, and the race time it predicts.
  final double expectedVdot;
  final int? predictedSec;
}

class _Slot {
  _Slot(this.sport, this.role);
  final Sport sport;
  String role;
}

/// Muscle groups a gym program trains (push / pull / legs with ≥ 3 work sets) and its leg load.
class _GymInfo {
  const _GymInfo(this.groups, {required this.legHeavy, required this.hasLegs});

  final Set<String> groups;

  /// Mostly leg work (≥ half of the push / pull / leg sets, or a built-in leg day) – waits for a
  /// day that is not before a key endurance session.
  final bool legHeavy;

  /// Has leg exercises at all.
  final bool hasLegs;

  /// Muscle groups both programs train ([gymMuscleSets] ≥ 3 work sets each).
  int overlaps(_GymInfo o) => groups.where(o.groups.contains).length;

  factory _GymInfo.of(List<GymExercise> exercises, {bool legHeavy = false}) {
    final n = gymGroupSets(exercises);
    return _GymInfo(
      {
        for (final e in gymMuscleSets(exercises).entries)
          if (e.value >= 3) e.key,
      },
      legHeavy: legHeavy || legHeavyExercises(exercises),
      hasLegs: n['legs']! > 0,
    );
  }
}

/// One gym session of a week for [_GymQueue.planWeek]: its day, whether a key endurance session
/// follows ([noLegs]) or a race is near ([race]), and the program the athlete assigned ([fixed]).
class _GymSlot {
  const _GymSlot(this.day, {this.noLegs = false, this.race = false, this.fixed});
  final DateTime day;
  final bool noLegs, race;
  final String? fixed;
}

/// Picks a split's programs, continuously over the whole plan: the program due longest comes
/// first (Push → Pull → Legs → Push …, across week boundaries and recovery weeks). A week's
/// sessions are chosen together (lookahead of two sessions) by cost:
/// * never the same program twice in a row (and preferably not again before the others had their turn);
/// * no program that trains the same muscle groups as yesterday's ([_GymInfo.overlaps]) – unless
///   every program does (full body);
/// * a leg-heavy program waits when a key endurance session follows ([_GymSlot.noLegs]) – one
///   session at most (strength for endurance athletes is mainly leg strength – Rønnestad & Mujika
///   2014, Blagrove 2018: the legs move to a later day, they are not trained less often); before a
///   race ([_GymSlot.race]) it always waits;
/// * no program is starved: one that already waited a whole rotation plus one session ([_wait] ≥
///   rotation length) is next – the most overdue first – before any of the preferences above but
///   the race rule (review r7 S1: a 5-day bro split dropped Back for ten weeks while Legs ran twice a
///   week). So every program comes back within rotation length + 1 sessions.
///
/// The last session of a week looks ahead into the next week (the same weekly pattern), so a
/// leg day passed over on Friday is not simply forced onto Tuesday's key-run eve.
class _GymQueue {
  _GymQueue(this.rotation, this.info) : _due = [...rotation] {
    // Before any history: the first due program is on time (waited rotation − 1 sessions), the
    // others less.
    for (var k = 0; k < rotation.length; k++) {
      _wait[rotation[k]] = rotation.length - 1 - k;
    }
  }

  _GymQueue._copy(_GymQueue o) : rotation = o.rotation, info = o.info, _due = [...o._due], _recent = [...o._recent] {
    last = o.last;
    _lastDay = o._lastDay;
    _wait.addAll(o._wait);
  }

  /// A race window's repeat of the only program without heavy leg work is replaced ([PlanGenerator._raceAlternates]).
  late final bool _raceAlternates = PlanGenerator._raceAlternates(rotation).isNotEmpty;

  /// Sessions since each rotation program was last trained (rotation − 1 = on time).
  final _wait = <String, int>{};

  final List<String> rotation;
  final _GymInfo Function(String ref) info;

  /// The rotation's programs, the one due longest first.
  final List<String> _due;

  /// The last programs (newest last, at most one rotation).
  var _recent = <String>[];

  /// Last program and its day.
  String? last;
  DateTime? _lastDay;

  /// [ref] was trained on [day] (a pick, an assigned program, the history before the plan).
  void record(String ref, DateTime day) {
    for (final k in _wait.keys.toList()) {
      _wait[k] = k == ref ? 0 : _wait[k]! + 1;
    }
    if (_due.remove(ref)) _due.add(ref);
    _recent = [..._recent, ref];
    if (_recent.length > rotation.length) _recent = _recent.sublist(_recent.length - rotation.length);
    last = ref;
    _lastDay = dayOnly(day);
  }

  /// The athlete's gym workouts before the plan (oldest first): the rotation continues after them –
  /// in the split's order from the first one of the rotation (after Pull comes Legs, not the
  /// never-recorded Push), then by what was trained since.
  void seed(List<(DateTime, String)> history) {
    final first = history.where((h) => rotation.contains(h.$2)).firstOrNull;
    if (first != null) {
      final i = rotation.indexOf(first.$2);
      _due
        ..clear()
        ..addAll([for (var k = 1; k <= rotation.length; k++) rotation[(i + k) % rotation.length]]);
      // (Recording [first] below makes the program after it on time: rotation − 1.)
      for (var k = 0; k < _due.length; k++) {
        _wait[_due[k]] = max(0, _due.length - 2 - k);
      }
    }
    for (final (day, ref) in history) {
      record(ref, day);
    }
  }

  /// Cost of each due program (index in [_due]) for [slot].
  List<int> _costs(_GymSlot slot) {
    final prev = last;
    final yesterday = prev != null && _lastDay != null && daysBetween(_lastDay!, dayOnly(slot.day)) == 1 ? info(prev) : null;
    // Done in the last (rotation − 1) sessions: the others did not all have their turn yet.
    final recent = _recent.length < rotation.length ? _recent : _recent.sublist(_recent.length - rotation.length + 1);
    // The most overdue program (waited a whole rotation and more) is next.
    var overdue = rotation.length - 1;
    for (final ref in _due) {
      overdue = max(overdue, _wait[ref] ?? 0);
    }
    final out = <int>[];
    for (var i = 0; i < _due.length; i++) {
      final ref = _due[i];
      final g = info(ref);
      final wait = _wait[ref] ?? 0;
      var cost = i * 10;
      // (Not in a race window of the home / bodyweight upper / lower split: a repeat there becomes the full-body
      // alternate – [PlanGenerator._planGymWeek]; the lookahead put Lower twice in a row before it, review G3V-1.)
      if (ref == prev && _due.length > 1 && !(slot.race && _raceAlternates && !g.legHeavy)) cost += 1000;
      // Again before the others had their turn: weighs more than a muscle-group overlap with yesterday or a
      // leg day on a key session's eve (review r7 S1 / S4: Legs twice a week in a bro split, Upper twice as
      // often as Lower for hybrid athletes) – every program about equally often.
      if (recent.contains(ref) && _due.length > 2) cost += 100;
      // (Each further shared muscle group adds a little: chest day → shoulder day shares delts and triceps, back
      // day → shoulder day only the rear delts – review 2026-11 GYM-10.)
      final shared = yesterday == null ? 0 : yesterday.overlaps(g);
      // (≤ 80: still below a program again before the others had their turn.)
      if (shared > 0) cost += 60 + 10 * min(shared - 1, 2);
      // Before a race a leg-heavy program never goes – absolute while another program exists (review 2026-11
      // GYM-6 / UX-8: overdue penalties outweighed it, and "Legs" without its leg work was a core-only session).
      if (g.legHeavy && slot.race) cost += 100000;
      // (Also when it is overdue – then the others cost more anyway, but the lookahead must see that passing it
      // over only moves it onto the next key session's eve.)
      if (g.legHeavy && slot.noLegs && !slot.race) cost += 40;
      if (overdue >= rotation.length && wait < overdue) cost += 400;
      out.add(cost);
    }
    return out;
  }

  /// Lowest summed cost of [slots] from [i] on, looking [depth] sessions ahead; [budget] or more when
  /// nothing stays below [budget] (branch and bound – the cheapest programs are tried first).
  int _future(List<_GymSlot> slots, int i, int depth, [int budget = 1 << 30]) {
    if (depth == 0 || i >= slots.length) return 0;
    final slot = slots[i];
    if (slot.fixed != null) {
      // An assigned program cannot move – the free session before it must not be the same program.
      final repeat = slot.fixed == last ? 1000 : 0;
      return repeat + (_GymQueue._copy(this)..record(slot.fixed!, slot.day))._future(slots, i + 1, depth - 1, budget - repeat);
    }
    final costs = _costs(slot);
    final order = [for (var k = 0; k < costs.length; k++) k]..sort((x, y) => costs[x].compareTo(costs[y]));
    var best = budget;
    for (final k in order) {
      if (costs[k] >= best) break;
      final q = _GymQueue._copy(this)..record(_due[k], slot.day);
      best = min(best, costs[k] + q._future(slots, i + 1, depth - 1, best - costs[k]));
    }
    return best;
  }

  /// The programs of a week's gym [slots] (in date order).
  /// [next]: the next week's slots (lookahead).
  List<String> planWeek(List<_GymSlot> slots, List<_GymSlot> next) {
    final ahead = [...slots, ...next];
    final out = <String>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot.fixed != null) {
        record(slot.fixed!, slot.day);
        out.add(slot.fixed!);
        continue;
      }
      final costs = _costs(slot);
      var pick = 0, best = 1 << 30;
      // The rest of the week (two to four sessions ahead) – review 2026-11 GYM-10: two sessions ahead, Monday's Back
      // looked as good as Chest, and Chest → Shoulders on consecutive days followed every bro-split week.
      final depth = max(2, min(4, slots.length - 1 - i));
      for (var k = 0; k < costs.length; k++) {
        if (costs[k] >= best) continue;
        final q = _GymQueue._copy(this)..record(_due[k], slot.day);
        final total = costs[k] + q._future(ahead, i + 1, depth, best - costs[k]);
        if (total < best) {
          best = total;
          pick = k;
        }
      }
      final ref = _due[pick];
      record(ref, slot.day);
      out.add(ref);
    }
    return out;
  }
}
