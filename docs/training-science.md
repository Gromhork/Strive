# Strive – Training Science Specification for the Rule-Based Plan Generator

Version 1.0 · 2026-11-08 · Scope: running, strength, cycling, swimming, hybrid/triathlon.

This file is an implementation spec: formulas, tables and decision rules that can be coded directly.
Every rule has an evidence tag:

| Tag | Meaning |
|---|---|
| **[S]** strong | Several RCTs and/or meta-analyses agree |
| **[M]** moderate | One meta-analysis, a few RCTs, or large prospective cohorts; some conflicting data |
| **[P]** practice | Coaching consensus, textbook methods (Daniels, Coggan, Friel, Swim Smooth), validated tools with limited outcome trials |

Paper numbers like [12] point to the References section (§10). Open-access PDFs are in `docs/papers/`.

---

## 0. Global conventions (apply to all sports)

```text
units: distance m, time s, speed m/s (or m/min for VDOT math), power W, HR bpm
week: Mon..Sun, index 0..6
session.intensityClass ∈ {RECOVERY, EASY, MODERATE, HARD, VERY_HARD}
session.isKey = intensityClass ∈ {HARD, VERY_HARD} || isLongSession
userLevel ∈ {BEGINNER, NOVICE, INTERMEDIATE, ADVANCED}
difficulty ∈ {EASY, BALANCED, CHALLENGING}          // §8
```

**Universal load metric (to compare sports, including strength).** Use session-RPE (Foster 2001) [43] **[M]**:

```text
sRPE_load = RPE_CR10 (0..10, asked ~30 min after the session) × duration_min
```

When power, pace or HR data exist, also compute TSS-type scores (§3.4). For planning, use the target RPE of each
workout template.

### Three-zone intensity model (shared by all endurance sports) [1,2] **[S]**

| Zone (3-zone) | Physiology | %HRmax | RPE (CR10) | Run (Daniels) | Bike (Coggan) | Swim (CSS) |
|---|---|---|---|---|---|---|
| Z1 low | < LT1/VT1 | < ~82% | 1–4 | E, M (part) | Z1–Z2 | CSS + ≥ 8 s/100 m |
| Z2 threshold | LT1–LT2 | ~82–87% | 5–6 | M, T | Z3–Z4 (sweet spot) | CSS + 2 to 6 s/100 m |
| Z3 high | > LT2/VT2 | > ~87% | 7–10 | I, R | Z5–Z7 | ≤ CSS |

---

## 1. Running

### 1.1 Intensity distribution

| Rule | Value | Evidence |
|---|---|---|
| Share of **sessions** that are easy (Z1) | ≈ 80% (≈ 4 of 5 sessions). Because hard sessions are short, this works out to ≈ 85–90% of **time** in Z1 | [S] descriptive data from elite athletes [1,2,4]; [M] interventions [3,5] |
| Polarized (≈ 75–80% Z1 / < 10% Z2 / 15–20% Z3) vs threshold, HIIT or high-volume training | Polarized was best for VO2peak (+11.7%), time to exhaustion (+17.4%) and peak speed/power (+5.1%) in a 9-week trial [3] | [M] |
| Meta-analysis (17 studies) | Polarized beat other distributions only for VO2peak (SMD 0.24), only in programs under 12 weeks and in highly trained athletes (SMD 0.46). Time trial and threshold outcomes were the same across distributions [5] | [S] |
| **Generator rule** | Default to a **pyramidal** distribution (Z1 > Z2 > Z3) in base/build and switch to **polarized** in peak. Always keep **≥ 75–80% of sessions easy**. Users with ≤ 3 runs per week: at most 1 quality session (2 when difficulty = CHALLENGING) | [P] synthesis of [4,5,17] |

```text
maxQualityRunsPerWeek(nRuns):          // = PlanGenerator._maxQualityRuns (decided 2026-11, coach review 3)
  nRuns <= 1 -> 0
  nRuns 2-4  -> 1     (3-4 runs: 2 if CHALLENGING and level >= INTERMEDIATE)
  nRuns >= 5 -> 2     (3 only for ADVANCED with >= 6 runs in the build phase)
  EASY difficulty, joint or heart limitations -> at most 1
// 4 runs = long run + 1 quality + 2 easy: the long run is already a key session, so 2 quality runs
// would leave only half of the runs easy (< 75-80 %). The earlier spec line "4-5 -> 2" is superseded.
the long run counts as a "key" session but not as a quality (Z2/Z3) session
unless it contains M-pace or T-pace segments
```

### 1.2 Fitness from a race time: Daniels VDOT [P, widely validated tables]

Equations (Daniels & Gilbert 1979; Daniels' Running Formula [7]). v in **m/min**, t in **min**:

```text
VO2(v)        = -4.60 + 0.182258·v + 0.000104·v²            // ml/kg/min needed to run at speed v
pctMax(t)     = 0.8 + 0.1894393·e^(-0.012778·t)
                    + 0.2989558·e^(-0.1932605·t)            // share of VO2max you can hold for t minutes
VDOT          = VO2(d / t) / pctMax(t)

// inverse: speed that needs a given VO2
speedForVO2(o) = (-0.182258 + sqrt(0.182258² + 4·0.000104·(4.60 + o))) / (2·0.000104)

// race time predicted from VDOT for distance d: solve VDOT(d,t) = VDOT for t by bisection, t in [1, 600] min
```

Checks (computed with the code above): 5 km in 20:00 → VDOT 49.8; 10 km in 41:21 → 50.0; 5 km in 30:00 → 30.8.

**Riegel race prediction** (fallback, or for a quick estimate) [8] **[M]**:

```text
T2 = T1 · (D2 / D1)^1.06
// 1.06 is too optimistic for the marathon in recreational runners (actual exponent often 1.08–1.15).
// Rule: when predicting the marathon from a race ≤ 10 km for BEGINNER/NOVICE, use exponent 1.08 (practice).
```

### 1.3 Pace zones (Daniels) [P]

| Zone | Target %VO2max (= fraction of VDOT) | Approx. speed relative to T-pace | Purpose / RPE |
|---|---|---|---|
| **E** easy / long | 59–74% | 0.73–0.87 × vT | Aerobic base, RPE 2–4, conversational |
| **M** marathon | race velocity for 42.195 km at this VDOT (≈ 75–84%) | ≈ 0.93–0.95 × vT | Specific endurance, RPE 5 |
| **T** threshold | 83–88% (use 86–88%) | 1.00 | "Comfortably hard", about 60-min race pace, RPE 6–7 |
| **I** interval | 95–100% (use 97.5%) | ≈ 1.09 × vT | VO2max work, about 3–5k race pace, RPE 8–9 |
| **R** repetition | race velocity for 1 mile (≈ 105–120%) | ≈ 1.12–1.18 × vT | Speed/economy, RPE 9 |

```text
paceE_slow = speedForVO2(0.59·VDOT);  paceE_fast = speedForVO2(0.74·VDOT)
paceM      = 42195 / raceTime(VDOT, 42195)
paceT      = speedForVO2(0.88·VDOT)
paceI      = speedForVO2(0.975·VDOT)
paceR      = 1609.34 / raceTime(VDOT, 1609.34)
// check for VDOT 50: E 5:51–4:53/km, M 4:31, T 4:15, I 3:54, R 3:37/km  (matches Daniels' tables)
```

Also show each runner an HR range (§5) as a cross-check. On hills, in heat, or when no race time exists, prescribe by RPE.

No race time? Estimate VDOT from a 12-min Cooper test (`distance/12` = v, t = 12) or a 3 km time trial. If neither is
done, set default pace targets from RPE only.

### 1.4 Per-session volume caps per zone (Daniels) [P]

| Workout type | Max per session |
|---|---|
| T (tempo or cruise intervals) | ≤ 10% of weekly km. Continuous tempo 20–30 min; cruise intervals up to 40 min of total T time |
| I | ≤ min(8% of weekly km, 10 km). Each rep 3–5 min; recovery jog equal to or slightly shorter than the rep |
| R | ≤ min(5% of weekly km, 8 km). Reps 200–400 m (up to 600 m); full recovery jog (2–3 × rep time) |
| Long run (L) | ≤ 25–30% of weekly km (30% allowed when weekly km < 40) **and** ≤ 150 min (marathon plans: ≤ 180 min for ADVANCED) |

Generator (review 2026-11): marathon plans allow 180 min for every non-beginner (the 28–32 km long runs of amateur
marathon plans take ~3 h); long-run km are planned at the **middle** of the E range (the pace the session duration is
estimated with), not at its slow end. Default time on the long day when the athlete set none: from the event table
(§14, `EventSpec.longDayMin`) – marathon 180 min, HM and olympic 150, 70.3 240 (long ride + brick run), Ironman 360,
ultra 240, 160 km ride 300, otherwise 120; the second long day (other sport / ultra back-to-back) 90–180 min.

**Long-run cap and its opt-in extension (user report 2026-11: "I set 5 h for the long day, why do my long runs stop at
3 h?").** The cap is a decision of the plan, not a lack of the athlete's time: a day's time is an upper limit, never a
target. The cap stays the default (marathon 3 h, 50 km ultra 3:30 h, everything else 150 min; Ironman long run 3 h).
For slower runners whose cap covers < 90 % of the race's usual long run (28 km marathon, 30 km ultra) the athlete may
switch on `AthleteData.longRunExtend` ("Lange Läufe bis 3:30 h erlauben", `EventSpec.longRunExtraMin`):

| Cap | Opt-in | Why |
|---|---|---|
| Marathon 3 h | up to 3:30 h | Galloway: run/walk long runs towards race distance; Higdon / Hanson cap at 3–3.5 h – beyond that recovery cost outgrows the gain at every pace |
| Ultra 50 km 3:30 h | up to 4 h | Koop 2016: single runs of 4–5 h are the upper end; the back-to-back run carries the rest |
| 70.3 / Ironman / duathlon long run | hard | the bike carries the endurance; a longer run costs the key rides of the following days (Friel) |
| 5 km – HM long run (150 min) | hard | the cap already covers the race's long run |
| Long rides (70.3 4 h, Ironman 6 h, 100 / 160 km 4:30 / 5:30 h), long swims | hard | no impact load – the caps already sit 20–50 % above the race's need; the day's time is their only real limit |

Rules of the extension (`PlanGenerator._longExtraWeeks`, `longRunExtraEligible`): only non-beginners without joint
problems, < 65, not on run/walk; the long-run day must hold ≥ 20 min more than the cap (`longRunExtraFloor` – the walk
breaks take 1 min in 11, a smaller extension holds less running than the plain run at the cap; a day left to the app's
default grows with the option); at most **two** runs go beyond the cap – half the extension (when ≥ 15 min), then all of
it – in the last build / peak weeks; each lies ≥ 21 days before race day **counted from the run's own day**
(`longRunExtraLeadDays` – a Sunday long run before a Saturday race is one week earlier than the week index suggests);
never in consecutive weeks (a recovery week or a long run of ~80 % of the cap lies between), and a loading week right
after the last one gets that shorter plain long run too (short plans: no race-pace long run a week after the longest
run); they are plain easy runs with a 1 min walk break every 10 min from the start (no race-pace finish), R1 (+≤ 10 %)
still applies to their running km; the run of the next day is ≤ ~40 min (ultra back-to-back ≤ 60 min), no quality run
for two days. A run is only extended when it covers ≥ 1 km more (walk breaks included) than the plain run at the cap
(`_extensionWorth`) – the note's `gains` is simply "the plan has such runs", one rule for both. The consent belongs to
one event: `AthleteData.merge` resets `longRunExtend` when `eventDistance` changes (marathon 3:30 h is not a yes to the
ultra's 4 h). "Plan neu aufsetzen" keeps the switch local and saves it with the rebuilt plan. The recalibration's
"a little more volume" (+5 %) never raises a long session beyond its default cap (`PlanGenerator.longSessionCapMin`)
and never raises an extended run.

The feasibility note (`LongRunCapNote`) is an info card. It is raised from the **plan's own** long runs: only when the
longest one sits at the generator's cap (`_longRunMaxMin`, within a 0.5 km step) and covers < 90 % of the usual
distance – so an HM plan that runs 2:30 h / 15 km gets no note (the 2 h of `EventSpec.longRunMin` is a time-on-feet
target, not the cap), and a long run the week's volume keeps below the cap (three runs a week) is explained by
`runFrequency` / `longRunShare` / `longRunRamp` with its real km and time instead. The note names the time the athlete
set ("that is not about your time"), gives the finish-goal advice while even the extended run stays < 90 % of the usual
distance, and ends with the extension: what it reaches in *this* plan (time and km), or – switched on without effect –
why (too few weeks / weekly volume). The switch is shown only where the plan with it has runs beyond the cap, or to
take it back.

**Day split (fix/plan-pro, user report "4 h a day and still only 120 min").** Two sessions on one day share its time
evenly – except when one of them is the long session: the short one (swim, easy run, strength) gets a third of the day,
30–60 min (30 min on the long-ride day of a plan with bricks), the long session the rest. The even split had capped
the 70.3 long ride of a 4 h Saturday with a swim at 2 h, and the feasibility card then said the day was too short.

### 1.5 Weekly volume progression and injury risk

| Evidence | Finding | Tag |
|---|---|---|
| Buist 2008 (GRONORUN RCT, n = 532 novices) [9] | A graded 13-week plan using the **10% rule** gave **no fewer injuries** than a standard 8-week plan (20.8% vs 20.3%) | [M] |
| Nielsen 2014 (cohort, n = 874 novices) [10] | Weekly increases **> 30%** were linked to more "distance-related" overuse injuries vs < 10% (HR 1.59, borderline). 10–30% was not clearly worse | [M] |
| **Frandsen 2025** (cohort, n = 5205, 588k sessions) [11] | A **single run that is > 10% longer than the longest run of the past 30 days** raised overuse-injury rate: +10–30% → HRR 1.64; +30–100% → 1.52; > 100% → 2.28. Week-to-week ratio: no association. ACWR: *negative* dose-response | [M] (large, recent) |
| Damsted 2018 review [12] | Evidence linking load change to injury is limited and low quality | [M] |

**Generator rules**

```text
R1 [M]  longestRun_next <= 1.10 × max(single-run distance, last 30 days)
        (cold start with no history: use the user's stated longest recent run, or 3 km for beginners)
R2 [M]  weeklyVolume_next <= weeklyVolume_lastNonDeload × (1 + g), where g comes from difficulty (§8):
        EASY 0.05 · BALANCED 0.08 · CHALLENGING 0.10 ; hard cap 0.30 over any 2-week window
R3 [P]  do not increase volume and intensity in the same week (when quality share rises, hold km)
R4 [P]  returning after a break of >= 2 weeks: restart at 50–70% of the pre-break volume
R5 [P]  the volume ceiling for a plan comes from the goal distance and level (table 1.8); stop progressing at the ceiling
```

**ACWR** (Gabbett 2016 [13]: "sweet spot" 0.8–1.3, danger > 1.5) **[M→weak]**. It is criticised for mathematical coupling,
arbitrary windows and spurious ratios (Impellizzeri 2020 [14], Lolli 2019 [15]), and in runners it was not predictive (or
was inversely related) [11]. **Implementation:** compute only as an *informational* EWMA-ACWR (Williams 2017 [16]); do not
use it as a hard constraint. Use R1/R2 instead.

```text
EWMA_today = load_today·λ + (1-λ)·EWMA_yesterday,  λ_acute = 2/(7+1), λ_chronic = 2/(28+1)
ACWR = EWMA_acute / EWMA_chronic        // show a warning if > 1.5 for 2 consecutive days
```

### 1.6 Periodization phases [P] (Daniels' 4-phase model [7]; Kenneally 2018 [17])

| Phase | Share of plan | Content |
|---|---|---|
| Base (foundation) | 35–50% | Mostly E running; strides 2×/week; volume rises toward the ceiling; hill sprints. No I work for beginners |
| Build (early + transition quality) | 25–35% | Add T and I (or M for marathon plans); volume near peak; long run grows |
| Peak (race-specific) | 10–20% | Race-pace work (5k/10k: I and R; HM: T and M; marathon: M and long runs with M-pace) |
| Taper | see 1.7 | Volume ↓, intensity kept |

Shorter plans shrink base first; build and taper are kept intact. Minimum base: 2 weeks.

### 1.7 Taper (Bosquet 2007 meta-analysis [18]; Wang 2023 [19]; Mujika & Padilla 2003 [20])

| Variable | Rule | Tag |
|---|---|---|
| Volume | Cut **41–60%** below pre-taper volume (Bosquet: largest performance effect in this range) | [S] |
| Shape | Progressive / exponential (e.g. week −2: −30%, race week: −50 to −60%) rather than a step cut | [M] |
| Intensity | **Keep it** (quality sessions stay, with fewer reps) | [S] |
| Frequency | Keep **≥ 80%** of normal session count | [M] |
| Duration | Bosquet: **8–14 days** best. Wang 2023 (endurance only): 21 days with −41–60% worked; an overload block before the taper boosted the effect | [S]/[M] |

```text
taperDays: 5k 7–10 · 10k 10 · HM 10–14 · Marathon 14–21 (BEGINNER marathon: 14) – all distances: §14
taperWeekFactor (3-wk taper: marathon, ultra, Ironman): [0.80, 0.65, 0.45 race week incl. race]
taperWeekFactor (2-wk taper): [0.65, 0.45]        (fix/plan-pro, was 0.70 / 0.50)
taperWeekFactor (1-wk taper): [0.50]               (was 0.55)
long session in the taper (vs. the last loading week): 3 weeks 0.75 / 0.60, 2 weeks 0.65, race week 0.45;
  recovery week 0.80 – the longest run / ride is the last loading week (marathon / ultra / Ironman ~3 weeks out,
  HM / 70.3 ~2), never repeated in the taper (Pfitzinger; Mujika & Padilla 2003 [20])
run/walk and swim-novice sessions taper too: fewer repeats (taper 70 %, race week 45 %), same stage
```

**Race-specific intensity in the taper** (coach review 3, Bosquet 2007 [18], Mujika & Padilla 2003 [20]): the taper's
quality run is the peak's race-pace session at ~60 % of its volume, not a generic fartlek – 5 km 4 × 800 m · 10 km 3 × 1 km ·
HM 3 × 2 km · marathon 2 × 3 km at goal pace (race week one repeat less, two repeats: shorter ones; ≤ 20 % of the week and ≤ 50 %
of that week's long run). Beginners, triathlon and plans without an event keep the short fartlek.

### 1.8 Plan length and prerequisites [P] (Daniels [7], Higdon/Pfitzinger plans, NHS Couch-to-5K [44])

| Goal | Beginner (cannot run 30 min) | Novice | Intermediate | Advanced | Entry requirement before the plan starts | Weekly volume ceiling (Nov / Int / Adv) |
|---|---|---|---|---|---|---|
| 5 km | 9–10 wk run/walk | 8 wk | 8–10 wk | 10–12 wk | none | 15 / 30 / 50 km |
| 10 km | 5k plan first, then 8 wk | 8–10 wk | 10 wk | 10–12 wk | can run 30 min continuously | 25 / 40 / 60 km |
| Half marathon | not allowed (do 5k/10k first) | 12 wk | 12–14 wk | 12–16 wk | about 15 km/week and a 6–8 km long run | 30 / 50 / 70 km |
| Marathon | not allowed | 18–20 wk | 16–18 wk | 16–18 wk (12 min.) | about 25–30 km/week and a 10–13 km long run | 45 / 65 / 90 km |

If the time to race day is shorter than the minimum: show a warning and offer a smaller goal (finishing rather than a time target).

**Feasibility check (generator, `PlanGenerator.feasibility`)** [P]. The plan is generated anyway; the onboarding summary,
the "new plan" sheet and the calendar header show a short warning with options when the goal is not realistic:

```text
not allowed  : BEGINNER + marathon; still on run/walk (cannot run 30 min) + marathon / ultra / Ironman
               (HM on run/walk: built goal-directed, §1.10b, and checked like every other goal)
runWalk      : run/walk stages still planned in race week (one stage per week, §1.10)
tooShort     : the plan's longest long run stays below 10k 8 km · HM 15 km (or 2 h on the feet, §1.10b) · marathon 28 km
               (~70–80 % of the distance) – also while still on run/walk by race day,
               or the long ride below 90 % of olympic 90 min · 70.3 180 min, because there are too few weeks;
               70.3 also needs a long run of ~16 km or 100 min (whichever is shorter at the long-run pace)
longRunTime / longRideTime : the time on the long day (not the weeks) caps the long session below those minimums
longSwim     : the longest continuous swim before the taper stays < 90 % of what the race needs (open water: §14
               longSwim; triathlon: sprint 400 m, olympic / 70.3 800 m, Ironman 1000 m)
beginnerDistance : ultra 50 km, Ironman, 5 km open water are no beginner goals (like the marathon)
options      : time-limited long session first: "raise <day> to <time>" (the day's minutes + what the long session
               lacks, in 15-min steps) and "move the long session to <day> (<time> available)" (a training day with
               enough time for the long session alone, incl. the brick run) · the first later race date (same
               weekday, ≤ 30 weeks) that passes · the largest shorter distance that passes by the date · finish with
               run/walk (5k / 10k / sprint / olympic / duathlon sprint) – race day then shows a run/walk rhythm
               (run 1–10 min as in the last stage, walk 1 min, from the start)
```

All distances, targets, caps, ceilings and the recommended plan length come from one table (§14, `EventSpec`). The
time stepper of the setup goes to 8 h (30-min steps above 3 h) – an Ironman long ride needs 5–6 h plus the brick.

### 1.12 Goal-driven plans: race date, target time, forecast [M/P]

**Plan length.** With an event date the plan always runs to race day (`PlanGenerator.weeksToEvent`, 2–52 weeks; every
creation path – setup, "new plan" sheet, goal editor "align plan to this event" – uses it). More than 20 weeks away
(`GoalModel.specificWeeks`, was 30 until coach review 3): the first `weeks − 20` weeks are a base **pre-plan** block (easy
volume, strides, recovery weeks; long run ≤ 70 % of the race-specific cap – marathon 24.5 km, HM ~15 km; volume ≤ 85 % of the
ceiling, so it still rises in the specific block), then the usual base → build → peak → taper of 20 weeks (amateur marathon
plans: 16–20 weeks).

**Long-run monotony** (coach review 3: a 40-week marathon plan repeated 29 km long runs ~20 times in a flat 53 km week, the long
run 55 % of the week). HM / marathon / 70.3 with ≥ 3 runs: the long run is ≤ 40 % of the weekly km outside the last 12 weeks
(the race-specific 45–55 % only close to the race). Once the long run stops growing (≥ 12 km, base / build), the loading weeks
rotate *long easy → progression long run* (build; last ~25 %, ≤ 8 km, at a steady M effort) *→ shorter week* (~80 %, text says
why) – Pfitzinger / Hansons alternate long, medium-long and marathon-pace long runs. Peak: race-pace long runs (below).

**Quality progression** (coach review 3, B3–B6). Each quality type progresses over the loading weeks of its phase in three
stages (0 → 1 → 2, proportional to the phase length):

```text
VO2max (I)     : volume ≤ min(8 % week, 10 km); once that cap binds, longer repeats 800 → 1000 → 1200 m (advanced 1000 → 1200)
threshold (T)  : ≤ 10 % week, ≤ 40 min in cruise intervals; once the cap binds 1.6 km → 2.4 km → 3.2 km repeats, then one
                 continuous tempo (≤ 30 min)
5 / 10 km peak : one goal-pace set a week (q1): 10 km 5 × 1 km → 4 × 1.5 km → 3 × 2 km, 5 km 6 × 800 m → 5 × 1 km → 3 × 1.6 km
                 (≤ 15 % week, ≤ 8 km, ≥ 2 repeats); a second quality run is VO2max; strides on easy runs stay in the peak
                 one quality run a week in the build: intervals and threshold alternate
HM peak        : long run with an HM-pace finish of 3 → 5 → 8 km (≤ 40 % of the run)
marathon peak  : long run with an MP finish of 6 → 10 → 13 km (≤ 45 %); MP run 70 → 85 → 100 % of min(20 % week, 14 km)
base           : q1 tempo (odd weeks) / I-pace fartlek (even weeks) – VO2 work only every other week; q2 = progression run
                 (easy, last 15–25 min at M effort, ≤ 20 % of the week, ≤ 70 % of the long run) – pyramidal base
```

Goal-pace steps use zone M with the goal pace (±3 s/km; marathon ±5) – the race-pace convention the target change
(`GoalForecast.retarget`, now also for the taper) follows; a VDOT step of the recalibration leaves them on the goal.

**Race day** (A4): the race step uses the *realistic* race-day pace (`_goalPace`: target when realistic, else the realistic
prediction) – an ambitious / unrealistic target would send the athlete out 2–3 % too fast. The description then reads
"Goal {target} – start at {pace}" ("Ziel … – starte mit …"); the race duration is the realistic time. Shorter than the recommended length: the plan is built anyway and the feasibility
card warns (§1.8). Rebuilding keeps done workouts (only upcoming *planned* workouts are replaced).

**Improvement model** (`GoalModel`, lib/services/goal_model.dart). Expected VDOT gain after `w` weeks of consistent training:

```text
gain(w) = cap · (1 − e^(−rate·w / cap))          // slope `rate` at the start, saturating towards `cap`
beginner      rate 0.45 / week   cap 10
intermediate  rate 0.22 / week   cap 5            // ≈ 1 VDOT per 4–5 weeks (Daniels [7]: +1 after 4–6 weeks)
advanced      rate 0.15 / week   cap 3
× 0.85 EASY · × 1.1 CHALLENGING · × 0.85 age ≥ 50 · × 0.7 age ≥ 65
weeks counted = weeks to race − 1 (race week; the taper realises, not adds, fitness)
high responder = 1.6 × gain                         // individual response varies widely (HERITAGE [82])
```

Evidence: Daniels raises VDOT about one point per 4–6 weeks of consistent training [7]; untrained people gain VO2max
~10–20 % in 8–12 weeks of endurance training [80], gains shrink with training status [81]; the training response is highly
individual [82]. **[P]** for the exact rates – they are deliberately conservative and the forecast corrects them with data.

**Target-time check** (part of `PlanGenerator.feasibility`): `realistic = time(VDOT_now + gain)`,
`optimistic = time(VDOT_now + 1.6·gain)`; target ≥ 0.995 × realistic → ok; ≥ optimistic → `targetAmbitious`; else
`targetUnrealistic`. Shown with today's and the race-day prediction, a suggested realistic target (rounded up: ≥ 1 h to the
minute, else 10 s; one tap applies it) and the first later race date at which the target is realistic. Without a race time
the check is marked as a rough estimate (level default VDOT). Triathlon: only with data (race time, FTP or swim test),
otherwise finish-oriented; time = swim (CSS + 10 s/100 m) + bike (flat-course power model at 88 / 85 / 77 % FTP for sprint /
olympic / 70.3, CdA 0.32–0.27, Crr 0.005, × 0.93 course factor; level speed without FTP) + run (VDOT × 1.08, 70.3 × 1.12) +
transitions; the run's relative improvement is applied to the whole race.

**Paces.** All training paces (E, T, I, R, and M without a target) stay on the **current** VDOT – training at goal pace too
early is a classic mistake (Daniels [7]); VDOT steps up only through the recalibration (§11, §12.3). Race-specific work in the
peak phase (HM long-run goal segment, marathon MP segments / MP run) uses the **target pace** when the target is realistic,
otherwise the realistic race-day pace. `PlanGenerator.outlook` gives each phase's expected VDOT and predicted time (stepwise,
per phase) – the line the forecast compares with.

**Goal forecast** ("Zielprognose", `GoalForecast`, lib/services/goal_forecast.dart):

```text
fitness now : planned race / unplanned max effort (RPE ≥ 8 or HR ≥ 88 % HRmax) of the last 60 days → measured VDOT;
              else the plan line  baseline + gain(weeks since plan start) × min(1, completion / 0.9);
              quality runs (last 42 days, ≥ 3 – review C1): actual / planned avg speed vs the step estimate, ± 5 %
              dead band (= 1.0; a session that took the plan's displayed, rounded duration ± 2 % is on plan as well);
              median r < 0.98 at a real effort pulls towards VDOT_targets · r^1.2, r > 1.02 lifts there only with ≥ 3
              quality runs over ≥ 14 days (or a max effort) – the same evidence the recalibration needs for VDOT +1;
              faster non-max efforts only raise
detraining  : the longest gap without running of the last 28 days (> 10 days; open gap up to today, or a finished one that
              started after the plan start) → −(0.3 + 0.7 / week beyond day 10), ≤ −4 VDOT (Mujika & Padilla [68]);
              a finished gap fades linearly over 2 × its length after the return (one easy run no longer erases it)
race day    : now + [gain(elapsed + left) − gain(elapsed)] × (0.3 + 0.7 · completion_28d / 0.9, ≤ 1)
plan line   : starts at the VDOT of the plan's first quality run (the plan-start paces) when a recalibration has moved
              the profile's VDOT since – baseline + gain would otherwise count the realised gain twice
range       : ± 1 (max effort) · 1.5 (quality runs) · 2 (race times) · 3.5 (level default) + 0.04 / week left
status      : forecast / target ≤ 0.97 ahead (suggest faster; running: needs the evidence above, triathlon: also when the
              target is ≥ 3 % slower than what FTP / CSS / race time predict today) · ≤ 1.01 on track · ≤ 1.03 slightly
              behind · else at risk. Persistence (C1): this pace status only shows when the forecast of a week ago
              (sessions until then) was on the same side – otherwise on track; two "behind" weeks show the milder one.
              Missed training / a break and a measured max effort count at once.
floors      : completion < 50 % (≥ 3 weeks in) → at risk, < 70 % → slightly behind (with or without a target);
              long runs behind (longest of 6 weeks < 75 % of the longest planned, or ≥ 2 of the last 3 weeks' long runs
              missed / < 75 %) → ≥ slightly behind, at risk with ≤ 10 weeks left for HM and longer (≤ 6 otherwise);
              fatigue (the recalibration's too-hard score ≥ 2 over 14 days, reason "fatigue") → ≥ slightly behind
no ahead    : never "ahead" with long runs behind, missed training, a break or fatigue, nor with < 85 % of the last 4
              weeks done (the Monday after a sick week said "ahead – set 3:33")
finish-only : run/walk beginners (PlanGenerator.runWalkStartFor ≠ null, no race times) without a measured max effort:
              no time today / on race day / target (the level default VDOT 33 predicted a 1:54 HM for someone whose
              easy pace is ~7:40/km) – status from adherence, long runs, fatigue and the progression check
early       : < 2 done endurance sessions since the plan start → no verdict
```

**Messages.** At creation: the feasibility card (setup plan step, "new plan" sheet, goal editor). Afterwards: the home card
"Wo stehe ich" (countdown, phase timeline with the current position, forecast vs. target with delta, status) shows a notice
when the forecast is *at risk* – with "set target to …" (also moves the upcoming race-pace steps and the race) and
"Re-plan & recalibrate"; dismissed, it returns at most once a week (no push). The recalibration preview shows the same
forecast. The detail page adds completion, longest run vs. what the race needs, the VDOT trend vs. the plan line and the
phase outlook.

**Beginner progression check** (fix/plan-goal-progression, `progressionCheck`, lib/services/progression_check.dart,
carried as `GoalForecast.progression`) [P]: for beginners, plans with run/walk and swim novices, over the last 21 days:

```text
long sessions  : achieved share = Σ min(done, planned) / Σ planned (distance; run/walk and plans without a distance by
                 duration), weighted by planned minutes; missed = no linked session
behind         : ≥ 2 planned long sessions and (share < 0.8 or ≥ 2 missed)
run/walk       : ≥ 2 run/walk sessions done < 80 % of the planned time or at RPE ≥ 7 (C25K: progress only at RPE ≤ 5)
high effort    : ≥ 2 long / run/walk sessions at RPE ≥ 8
forecast       : behind → status ≥ slightly behind; long sessions behind → reason longRunBehind, and at risk with ≤ 8 weeks
                 left or share < 0.6 (the existing weekly at-risk notice of the home card)
options        : repeat the week · a later race · a shorter distance · race with run/walk (short races, HM: Galloway)
```

**Target-time suggestion** (`suggestTargetTime`, lib/services/target_suggestion.dart): VDOT from race times (high /
medium confidence), else the best 5 km+ effort of the last 90 days (never above the level default the target check
uses), else the level default (low); race day = `GoalModel.timeAt(VDOT, gain(weeks − 1))` – exactly the check's
*realistic* time, rounded on the slow side, so a suggestion is never flagged; marathon from ≤ 10 km below advanced:
the slower of VDOT and Riegel 1.08; triathlon from the legs (FTP / CSS). Finish only (no time): ultra, cycling, open
water, run/walk starters, beginner marathon / Ironman, multisport without data. Range ± 2 / 1.5 / 3.5 VDOT + 0.04 /
week.

**Target-time suggestion, update (review round 2).** The suggestion no longer has its own model: it reads the one
fitness model of §1.12a (with the running plan: the forecast's race-day value), and the marathon Riegel 1.08 correction
now lives in `GoalModel.predict` (`GoalModel.marathonScale`), so suggestion, check, forecast and race session share it.

### 1.12a One fitness model (`FitnessState`, review round 2) [M/P]

Round 2 of the sports-science review found forecast, target suggestion, target check, race-day pacing and "Plan
überprüfen" disagreeing on the same day (marathoner W17: suggestion / check 3:47, forecast 3:36; a perfect 70.3 athlete
whose forecast got 8 min slower in 12 weeks; forecast and training paces ~6 VDOT apart after recalibrations). All of them
now read `FitnessState` (lib/services/fitness_state.dart):

```text
baseline     : VDOT the plan was built with – paces of its first tempo / interval run (T / I targets; never the race
               session's step, C5), else the profile's VDOT at the plan start (a recalibrated estimate only when set before)
today        : max effort (60 d) > recalibrated VDOT set after the plan start + the gain since (C2: the paces run on it)
               > plan line baseline + gain(credited weeks) × min(1, completion / 0.9)
quality runs : ≥ 3 runs ≥ 3 % off their targets (the recalibration's threshold; ± 5 % dead band) pull down / lift; after a
               recalibration only runs against the current targets count; < 3 runs in 42 d → those of the last 63 d (an
               estimate is kept 3 weeks)
detraining   : as §1.12 (gap > 10 d)
overreaching : a week whose 14-day too-hard score was ≥ 2 on two consecutive Mondays (and ≥ 1 in that week) earns no
               adaptation (credited weeks = elapsed − those weeks; non-functional overreaching, Meeusen 2013), and no
               upward quality lift while it lasts (IMPORTANT 10)
race day     : today + [gain(credited + left) − gain(credited)] × (0.3 + 0.7 · completion_28d / 0.9, ≤ 1);
               left = training weeks to the Monday of race week (fractional)
times        : GoalModel.timeAt(p, baseline, v − baseline) – always from the baseline (C1: the triathlon model applies the
               run's relative gain to the whole race; anchored at today's VDOT it counted the gain twice for the run)
profile only : FitnessState.fromProfile – a plan stored on the profile (planStart / planLength) is assumed trained as
               planned; the default of GoalModel.check and of suggestTargetTime without plans (C4: mid-plan the check
               restarted from the plan-start VDOT every week and drifted 3:37 → 3:47)
```

Consumers: `GoalForecast` (status, reasons, range), `suggestTargetTime(plans:)` (goal editor), `GoalModel.check(fitness:)`
(feasibility card, retarget), `GoalForecast.retarget` (C3: the generator's goal-pace rule – within reach the race-pace work
runs at the faster of target and realistic time and the race at the target; out of reach both at the realistic time with
"Ziel X – starte mit Y"; a conservative target adds "realistisch: …" to the race – IMPORTANT 5), and the `Recalibrator`
(VDOT cap = baseline + 1.6 × gain(weeks trained); no VDOT rise while a break / return is active, completion < 50 % or the
model still takes VDOT off for a break – IMPORTANT 1; goal at risk ⇔ the forecast's at risk, judged on the original plan –
the setup's feasibility from today only supplies the options, IMPORTANT 2). Invariant (`test/fitness_model_test.dart`,
day-by-day simulation): every Monday suggestion = round(forecast race day) and check realistic = forecast race day (± 1 s);
a perfect athlete's race-day time stays constant (marathon ± 5 s, 70.3 / duathlon ± 15 s).

**Chronic skipping** (IMPORTANT 4): over the last 28 days (≥ 3 weeks into the plan) < 70 % of the due endurance sessions
(≥ 6 due) or < 75 % of the key sessions (tempo, intervals, long; ≥ 3 due) done → forecast reasons `sessionsSkipped` /
`keySessionsMissed` (≥ slightly behind, never ahead) and the same findings in "Plan überprüfen" – the minutes alone looked
fine when the long runs were done and two easy runs a week were skipped.

**Soft target**: "ahead – set a faster target" is suggested for the first two weeks it shows, then the forecast stays
quiet about it (it said "set 3:37" for 13 weeks in a row).

**Plan length without an event** (`PlanGenerator.supportedWeeks` = 4, 6, 8, 10, 12, 16, 20, 24;
`recommendedWeeks(p)`: beginners 8–12 (8), others 8–16 (12), with an event the table §14; `phasesFor(p, start:,
weeks:)` for a preview): base ~42–50 % then build, a recovery week after every 2–4 loading weeks (§1.9), no peak, no
taper, no race – verified for every supported length in the plan matrix (invariant 13g).

### 1.9 Deload / recovery weeks [P] (no RCT on cycle length)

```text
cycleLength (weeks loading : 1 recovery):
  BEGINNER/NOVICE, age >= 50, or difficulty EASY : 2:1 or 3:1  -> use 3:1 (2:1 if age >= 50 & EASY)
  INTERMEDIATE / BALANCED                       : 3:1
  ADVANCED & CHALLENGING                        : 3:1 or 4:1
recoveryWeek: volume × 0.65–0.75, long run × 0.70, keep 1 quality session at reduced reps, no new progression
next loading week resumes at the volume of the last loading week (not at the deload volume)
```

### 1.10 Beginner run/walk [P] (Couch-to-5K style, 3 sessions/week, ≥ 1 rest day between)

| Week | Main set (after a 5-min brisk walk warm-up) | Total run time |
|---|---|---|
| 1 | 8 × (60 s run / 90 s walk) | 8 min |
| 2 | 6 × (90 s run / 2 min walk) | 9 min |
| 3 | 2 × (90 s run, 90 s walk, 3 min run, 3 min walk) | 9 min |
| 4 | 3 min / 5 min / 3 min / 5 min run with 90–150 s walks | 16 min |
| 5 | s1: 3 × 5 min run / 3 min walk · s2: 2 × 8 min / 5 min walk · s3: 20 min continuous | 15–20 min |
| 6 | 25 min continuous (or 2 × 10 min) | 20–25 min |
| 7–9 | 25 → 30 min continuous | 25–30 min |

Rules: progress only if the last session felt RPE ≤ 5 with no pain. Otherwise repeat the week [P]. All running is at
"talking pace". Show no pace targets. Couch-to-5K has no recovery weeks: while a pure runner (also hybrid run + strength)
is on run/walk, no recovery week is planned; the 2:1 / 3:1 cycle starts with continuous running.

### 1.10a Who starts with run/walk; masters and body weight [M/P] (generator audit 2026-11)

```text
runWalkStart:
  advanced setup, "cannot run 30 min"                          -> stage 1 (8 × 1 min)
  quick setup (question not asked), BEGINNER, no run experience -> stage 1
  quick setup, BEGINNER returning runner with BMI >= 30 or age >= 65 -> stage 5 (3 × 5 min)
  one stage per loading week, recovery/taper weeks repeat the last stage; ends with 30 min continuous,
  the first long run after it obeys R1 (<= +10 % of the 30 min run)
BMI >= 30 novices (Nielsen 2013, n = 930: higher injury risk; Nielsen 2014: > 3 km in week 1 -> more injuries)
  and age >= 65: run volume grows at the EASY rate (5 %/week), add volume via bike/swim first (H8)
masters: age >= 50 -> cycle <= 3:1, growth <= 8 %, no key sessions on consecutive days (>= 48 h between hard days);
  age >= 65 -> 2:1, growth <= 5 %; age >= 60 -> at least 1 rest day/week
beginners: >= 2 rest days/week (strength only: <= 4 days), <= 4 runs/week (<= 3 while on run/walk)
```

Long-run share for half/full marathon goals: Daniels' 25–30 % (1.4) keeps an amateur HM long run at ~11 km on 35 km/week.
Race-specific plans (Higdon, Pfitzinger, Hanson) use 35–45 % at amateur volumes, so with ≥ 3 runs/week the generator allows
HM 40 % (above 50 km/week falling towards 32 % only as fast as the long run stays at 20 km) and marathon 42 % (above
70 km/week falling towards 33 %, long run ≥ 29.4 km) – continuous, so a growing week never shortens the long run (review 2:
a step at 50 km cut it from 19 to 16 km) – capped at 21 / 35 km, still bounded by R1 and
the 150 min (marathon 180 min) limit. At low volumes the share may rise to what the race-specific long run needs:
HM up to min(50 %, 15 km / weekly km), marathon up to min(55 %, 30 km / weekly km) (Higdon / Hanson novice plans 45–60 %).
Peak run volume with a stated current volume: ≤ 1.5 × that volume (at least +10 km), whatever the table ceiling says
(review: 55 → 103 km/week in 9 weeks was +87 %).

Triathlon volume ceilings (R5) per discipline, novice / intermediate / advanced:
run km sprint 12/20/30 · olympic 18/28/40 · 70.3 25/35/50; bike hours 2.5/3.5/4.5 · 3.5/4.5/6 · 5/6.5/8;
swim km 3/5/7 · 4/6/8 · 5/7/9. Sessions per discipline with one session a day: 3 days 1/1/1, 4 days swim 1 · bike 2 · run 1,
5 days 1/2/2, 6 days 2/2/2, 7 days 2/3/2 (2 days: bike + run, or swim + bike if the athlete cannot swim 400 m).

### 1.10b Goal-directed build for limited current ability [M/P] (fix/plan-goal-progression)

User report: "cannot run 30 min, half marathon in 12 weeks → the longest sessions are just over 30 min, long runs
≤ 5 km". Root cause: (1) run/walk athletes got three identical run/walk sessions a week for 11 weeks – no long session
at all, the HM plan never left run/walk; the feasibility card only said "start with 5 km"; (2) athletes who can run
30 min started the long run at ~4–5 km and grew it by +10 % (R1) of that tiny base – 5 → 9.5 km in 12 weeks; (3) the
swim-novice ladder ended at 400 m and nothing grew afterwards. The principle now: *as far as is safely possible
towards the goal*, and a clear warning when that is not far enough.

```text
goal long run   : EventSpec.goalLongKm – 10k 9 km · HM 16 km (Higdon / Galloway novice plans 8–10 / 16–18 km) · else
                  longRunKm; slow runners: longRunMin at the long-run pace when shorter (HM 120 min ≈ 15 km at 8:00/km)
behind          : the long run cannot reach it at +10 %/week (R1) in the loading weeks before the taper, or run/walk start
run/walk + goal : NHS Couch-to-5K pace (9 stages: skip 10 × 1 min and 3 × 5 min, which repeat the run time before them)
                  when 11 stages + the long-run build do not fit; each stage still needs RPE ≤ 5 without pain [44]
long run/walk   : on the long day the stage's rhythm repeated (continuous stages: 10 min run / 1 min walk), main set
                  +10 min per loading week (gentle: +5), running ≤ 2 × the longest regular session's (gentle 1.5 ×),
                  never shorter than last loading week's; no recovery weeks while on run/walk (C25K), taper as usual
                  – Galloway run-walk-run [91]; walk breaks keep finish times with less fatigue (Hottenrott 2016 [92])
after run/walk  : R1 reference = the running km of the last long run/walk; long runs keep a 1 min walk break every
                  10 min (description says: drop them once easy); easy runs start at the 30 min run, +10 %/week;
                  race day shows "run 10 min / walk 1 min"
goal step       : behind → longest + min(1.5 km, 10 min at the long-run pace), ≤ +25 % (gentle: 1 km, ≤ +15 %), never in
                  the first plan week, never beyond the goal; recovery weeks (80 %) stay. Higdon novice HM adds ~1.5 km a
                  week [93]; Nielsen 2014 [10]: < 30 %/week not clearly riskier; Pfitzinger [94]: ≤ ~10 min more per
                  week on the long run; ACSM [95]: progress duration before intensity
volume          : behind (not gentle) → run km grow 10 %/week (R2 CHALLENGING rate) up to max(ceiling, goal / 0.5); the
                  goal's long run may take ≤ 50 % of a 3+-run week (2 runs 60 %)
gentle          : EASY, knee / hip / ankle, age ≥ 65, BMI ≥ 30 novices – they also keep the slower volume growth
monotonic       : within a loading block the long run never shrinks (plateau's planned shorter week excepted)
cold start (R1) : longest recent run ≤ 50 % of the stated weekly km (one run a week in the plan ≠ a 25 km run)
long ride       : too slow for the race's long ride → ≥ +10 min per loading week (Friel [86]), ≤ the long day minus the
                  brick, never below last loading week's
swim novice     : see §4.5
```

Before → after (Mon-start plan 2026-11-09, 3 run days, 60 min, Saturday 150 min):

| Case | Before | After |
|---|---|---|
| HM 12 wk, cannot run 30 min | 11 weeks of 3 × the same 30 min run/walk, longest 3.2 km / 35 min; "HM not allowed" | long run/walk 40 → 75 min (7.7 km running), long run 9 km with walk breaks; warns: too short, race on 2027-03-07 or 10 km, or finish with run/walk |
| HM 12 wk, can run 30 min | long run 5 → 9.5 km | 5 → 13 km (+1–1.5 km/week, recovery weeks); warns too short, later date one week later |
| 10 km 8 wk, cannot run 30 min | longest 2.6 km / 30 min | long run/walk 40 → 65 min (6.4 km); warns run/walk on race day + too short, later date, run/walk finish |
| olympic 16 wk, cannot swim 400 m | continuous swim stuck at 400 m, warning | ladder (6 stages) → CSS test → continuous swim 500 → 800 m, no warning |

The ongoing check is in §1.12 (progression check). The UI suggests a target time with `suggestTargetTime` (§1.12).

### 1.10c Three-run weeks, finish goals and easy-run floors [P] (review round 2, `test/fitness_model_gen_test.dart`)

* **Long-run share with three runs (C6).** Novice half-marathon plans with three runs a week put ~60–65 % of the
  week into the long run (Galloway run-walk-run [91]: two 30 min midweek runs + the long run; Higdon Novice 1 [93]:
  3 + 3 mi midweek next to a 10 mi long run, ~3.3 ×). The whole-week rule is therefore 65 % and ≤ 3.5 × the
  next-longest run for weeks with exactly three runs (four runs: 50 % / 2 ×, marathon 55 %), and the HM volume curve
  lets the long run take ≤ 65 % (≤ 15 km) of a three-run week. R1 (≤ 1.1 × the longest run of the last 30 days) and
  the long run's time cap (HM 150 min) still bound it. A knee / hip / ankle runner whose easy run is swapped for a
  ride counts the runs actually planned. 3 × 30 min HM (14 wk): long run 7 km W6–W12 → 13 km; run/walk beginner HM
  (20 wk): peak 12 → 15.5 km.
* **Finish goal when the long run is not reached.** A running event whose plan (≥ 6 loading weeks before the taper)
  never reaches the race's long run (`EventSpec.longRunKm` or `longRunMin` on the feet) is planned as a finish goal:
  `PlanGenerator.finishOnly` is true, the race session has no pace / target time, the outlook no predicted times;
  feasibility adds `longRunFinish` ("longest long run ~X km, the race needs ~Y km") with a later date when one helps,
  else the shorter distance. The "other runs need … min" option (`longRunShare`) uses the same 65 % / 3.5 × rules and
  stays below ¾ of the long run's own time (3 × 30 min case: 90 → 35 min).
* **Marathon easy runs.** Besides the build / peak floor (≥ 6 km), marathon easy runs stay ≥ 5 km (~30 min) in base and
  recovery weeks (≥ 4 km after the recovery-week trim), ≥ 4.5 km in the taper and ≥ 4 km (~25 min) in race week, never
  more than 75 % of the week's long run – 3 km jogs in a marathon taper are not training (Pfitzinger [94]:
  general-aerobic runs through the taper), while the lower taper floors keep its volume cut (§1.7). Marathon 18 wk:
  shortest easy run 3.0 → 4.0 km (taper 3.0 → 4.5 km).
* **Later date for too-short plans.** A knee runner's HM plan reported "14 weeks are not enough" without a later date –
  the long run was capped by the four-run share while one run had become a ride, so no later date helped. With the
  runs actually planned the 14-week plan reaches 15 km; a 9-week plan reports `tooShort` with a later date.
* **Goal-pace label.** Goal-pace sets keep the race-pace zone code `M` (forecast retarget / recalibration rely on it),
  but every goal-pace / race step of a running event is labelled "race pace" in the UI (`zoneLabel` with the step's
  note) – a 10 km goal pace lies between T and I, so "steady" (sets) next to "threshold" (race) was wrong.

### 1.11 Workout library and scaling [P]

All quality sessions: 10–15 min E warm-up with 4 × 20 s strides, and a 10 min E cool-down.

| Template | Structure | Base dose | Progression step | Max |
|---|---|---|---|---|
| Strides | 4–8 × 15–20 s quick (≈ R pace), 60 s easy walk/jog | 4 | +1–2 / week | 10 |
| Hill sprints | 6–10 × 8–10 s steep hill, full recovery | 4 | +2 | 10 |
| Fartlek | 6–10 × 1 min at I/T feel / 1–2 min E | 6 × 1 min | +1 rep or +30 s | 20 min "on" |
| Tempo (continuous T) | 15 → 30 min at T | 15 min (N), 20 (I) | +3–5 min | 30 min, and ≤ 10 % of the weekly km (at least 20 min) |
| Cruise intervals (T) | n × 1 mile/1.6 km (or 5–8 min) at T, 60 s jog | 3 × 1.6 km | +1 rep | T cap (1.4) |
| VO2 intervals (I) | n × 800–1200 m (3–5 min) at I, jog = 0.5–1 × rep time | 5 × 800 m / 4 × 1000 m | +1 rep or +200 m | min(8% wk, 10 km) |
| Repetitions (R) | n × 200–400 m at R, jog 2–3 × rep time | 8 × 200 m | +2 reps | min(5% wk, 8 km) |
| Progression run | E for 2/3, then build to M (or T in last 10–15 min) | 40 min | +5 min | 90 min |
| Long run | E; marathon build: last 20–40% at M | per 1.4 | ≤ R1 rule | per 1.4 |
| Marathon-pace run | 2 × 5 km → 16–22 km at M inside a long run | 8 km M | +2–3 km | 22 km M |
| Recovery run | 20–40 min at slow end of E | — | — | — |

Scaling by level: BEGINNER no I/R (strides and fartlek only) · NOVICE: T + fartlek, I from build phase (short reps) ·
INTERMEDIATE/ADVANCED: full library. Scale reps to time available, never pace.

---

## 2. Strength / hypertrophy

### 2.1 Volume (hard sets per muscle per week)

| Evidence | Finding | Tag |
|---|---|---|
| Schoenfeld 2017 meta-regression [21] | Graded dose-response: each extra weekly set ≈ +0.37% muscle growth (ES +0.023); 10+ sets/week > 5–9 > < 5 | [S] |
| Pelland 2026 (67 studies, n = 2058) [22] | Hypertrophy and strength both rise with volume, with **diminishing returns** (much sooner for strength). Count indirect sets as **0.5** ("fractional") | [S] |
| Iversen 2021 [23] | Minimum effective dose: **≥ 4 sets/muscle/week**, 6–15 reps, near failure | [M] |

```text
// fractional set counting
effectiveSets(muscle) = Σ direct sets + 0.5·Σ sets where muscle is a synergist
                        (e.g. bench press: chest 1.0, triceps 0.5, front delt 0.5)
weeklyTargetSets per muscle (per difficulty & level):
             BEGINNER   INTERMEDIATE   ADVANCED
  EASY        4–6         6–10          8–12
  BALANCED    6–10        10–14         12–16
  CHALLENGING 8–12        12–18         14–22
progress volume +1–2 sets/muscle/week per mesocycle week; reset at deload        [M/P]
perSessionCap: ≤ 8–10 effective sets per muscle per session (spread above this)  [P]
```

### 2.2 Frequency

- Hit each muscle **≥ 2× per week**: better hypertrophy than 1× per week (Schoenfeld 2016 [24]) **[S]**.
- With volume equated, frequency itself matters little for hypertrophy (Schoenfeld 2019 [25]; Pelland 2026 [22]). Use
  frequency mainly as a way to spread volume. Strength gains benefit somewhat more from frequent practice of the lift **[M]**.

### 2.3 Load, reps, proximity to failure

| Rule | Value | Tag |
|---|---|---|
| Hypertrophy | Similar across **~30–85% 1RM (≈ 6–30 reps)** when sets go near failure (Schoenfeld 2017 [26]) | [S] |
| Maximal strength | Heavier loads win: ≥ 80% 1RM (1–6 reps) needed for max strength [26] | [S] |
| Proximity to failure | **0–3 RIR** for hypertrophy. Closer to failure adds a little hypertrophy but much more fatigue (Robinson 2024 [27]; Refalo 2023: velocity loss −25% at failure vs −8% at 3 RIR, slower recovery [28]) | [M] |
| Autoregulation | RPE-based loading ≥ %1RM loading (Helms 2018: slightly better strength [29]) | [M] |

**RIR-based RPE scale** (Zourdos 2016 [30]; Helms 2016 [31]) **[M]**: RPE 10 = 0 RIR · 9.5 = maybe 1 · 9 = 1 RIR · 8 = 2 ·
7 = 3 · 5–6 = 4–6 RIR · 1–4 = very light. Novices misjudge RIR (they underestimate it) → beginners get target RIR 2–3 and no failure.

```text
RIR targets:
  compound (squat, deadlift, bench, row, press):  RIR 1–3   (never 0 for BEGINNER or on axial-loaded lifts)
  isolation / machine:                             RIR 0–2
  mesocycle wave: week1 RIR 3 -> week2 RIR 2 -> week3 RIR 1(–0 isolation) -> deload
rep ranges (default):
  goal STRENGTH:     compound 3–6, accessory 6–10
  goal HYPERTROPHY:  compound 6–10, isolation 10–15 (–20)
  goal GENERAL/HYBRID: compound 5–8, isolation 8–15
estimated 1RM (Epley):  1RM = w·(1 + reps/30)        // reps <= 10 for accuracy
load for target:       w = 1RM / (1 + (reps + RIR)/30)
```

Approximate %1RM ↔ reps to failure (NSCA): 1 = 100%, 2 = 95, 3 = 93, 4 = 90, 5 = 87, 6 = 85, 8 = 80, 10 = 75, 12 = 70,
15 = 65 **[P]**.

### 2.4 Progression models

| Model | Evidence | When to use (generator) |
|---|---|---|
| **Linear** (load ↑ each session/week) | Works well for novices [P] | BEGINNER/NOVICE compounds, first 8–12 weeks |
| **Double progression** (reps ↑ within a range, then load ↑) | Practice standard [P]. Pairs naturally with RIR | Default for all accessories, and compounds for INTERMEDIATE+ |
| **DUP** (daily undulating: heavy/moderate/light days in the same week) | Rhea 2002: DUP roughly doubled % strength gains vs linear in 12 wk (small n) [32]. Williams 2017 meta: periodized > non-periodized for 1RM (ES 0.43); undulating ≈ linear [33] | INTERMEDIATE/ADVANCED with ≥ 3 sessions/week per lift pattern |

```text
linear (novice): if all sets done at RIR >= target: +2.5 kg upper / +5 kg lower (per session, max 2×/wk);
                 after 2 failed sessions: −10% and resume
doubleProgression(range [lo,hi], sets n):
  if all n sets reach hi reps at <= target RPE: load += increment; reps reset to lo
     increment: upper compound 2.5 kg (or +2.5%), lower compound 5 kg (+5%), isolation smallest step (1–2.5 kg)
  elif reps < lo in 2 consecutive sessions: load −= 5–10%
  else: aim for +1 rep on at least one set
DUP weekly template (per main lift): Day H 4–6 reps @RIR2 · Day M 8–10 @RIR2 · Day L 12–15 @RIR1–2
```

### 2.4a Autoregulated multi-session progression (what the app does) [M/P]

Implemented in `lib/services/smart_progression.dart` (used by `LoadPrescriber`). Double progression stays the base –
adding reps or adding load progresses strength and hypertrophy equally well (Plotkin 2022 [69]) – but the step is
**autoregulated** by effort (RIR-based autoregulation ≥ fixed loading: Helms 2018 [29]; Graham & Cleather 2021 [70]) and
judged over the **last 3–6 sessions** instead of the last one only.

**Effort per exercise** (reps in reserve after the last work set), first source that exists:

| Source | RIR |
|---|---|
| AMRAP last set ("as many reps as possible – stop 1 rep before failure", see below) | reps − target + 1 (measured; a chip after it rates the AMRAP set itself, so it comes first) |
| Optional chip after the last work set: Leicht / Passend / Schwer / Limit | 4+ / 2–3 / 1 / 0 (RIR-based RPE scale [30,31]) |
| Logged set RPE (hardest set) | 10 − RPE |
| A work set marked "failure" | 0 |
| Reps vs. the per-set targets the app prescribed (stored on each set) | a set ≥ 2 short → 0; 1 short → 1; all ≥ 2 above → ≥ 3; all met → unknown. A planned descending pattern (10/9/8) is **not** a drop-off |
| Inferred (no targets – old data, hand-added sets): rep drop-off across sets at the same load ≥ 30 % (and ≥ 2 reps) | 0 (limit) |
| Inferred: drop-off ≥ 15 % (and ≥ 2 reps) | 1 (hard) – sets far from failure can be repeated with the same reps; losses across sets mean the sets were close to failure (Willardson & Burkett 2005 [73]; Refalo 2023 [28]) |
| Inferred: every set ≥ 2 reps above the top of the range | ≥ 3 (easy – load clearly too light) |
| Nothing of the above | unknown → treated as "about right" |

Self-rated RIR is accurate to about ±1 rep near failure and worse far from it, and novices tend to underestimate their
reserve (Halperin 2022 [71]; Steele 2017 [72]) – so the effort only moves the step **one notch**.

**Trend:** session performance = top-set e1RM of the total load (Epley, RIR from RPE else 1; mean reps for exercises
without load). Theil–Sen slope (median of pairwise slopes, Sen 1968 [75] – robust to one bad day) over the last ≤ 6
sessions within 8 weeks, × time span ÷ median: ≥ +2 % progressing, ≤ −3 % regressing (day-to-day e1RM noise ≈ 2–4 %),
else plateau. Needs ≥ 3 sessions over ≥ 10 days.

**What a session stores** (so the app can tell its own decisions from the lifter's): per work set the prescribed rep
`target`, per exercise the prescribed load `rxKg`, an `amrap` flag on the AMRAP set and the plan `phase` when the
exercise was lightened for a deload/taper week. Old sessions without these fields keep the previous behaviour.

```text
order of rules (first match wins); w = last top weight, total = w + body load (bodyweight exercises)
1. stall:  same weight ≥ 3 sessions (≤ 6 wk) spanning ≥ 14 days (3 full-body sessions in one week are no stall),
           never all sets at the top, no more total reps, trend not rising, and – when targets are stored – a target
           was missed (holds the app prescribed and the lifter completed are not a stall)
           → reset w × 0.9 (bodyweight: shed added load, never into assistance)
2. drop:   the last two sessions both worse than the one before them
           (same load ±1 % and ≥ 1 rep/set fewer; lighter load with fewer reps; lighter load without more reps only
           when the lifter chose it – not the app's own lighter prescription; a session with every target met is
           never "worse")
           → ≥ 2 reps/set lost or limit: −7.5 % of total (reactive deload, Bell 2023 [74]); else hold w, repeat reps
2b. linear (BEGINNER, compound lifts, targets stored, until the first stall = targets missed twice in a row):
           all targets hit and not hard → +1 increment, same reps (§2.4 linear model); hard → hold;
           narrowly missed once → same weight and targets again; then double progression
3. top:    all sets ≥ top of range
           limit → hold w, top reps once more
           one increment > 10 % of total (light dumbbells, isolation; never barbell compounds – a light squat uses a
               2.5 kg step below 50 kg instead of 5 kg) → MICROLOADING: reps beyond the top first
               (+1/session, +2 when rated easy) up to top + max(2, 25 %) – hypertrophy is similar across ~6–30 reps
               near failure (Schoenfeld 2017 [26]) – then +1 increment with reps matched to the same e1RM − 1
           else k increments, restart at the bottom: k = 2 when easy (intermediate: rated or inferred; advanced:
               rated only) or beginner and not hard; never > 10 % of total at once (NSCA 2–10 %); k = 1 when regressing
4. missed: ≥ half of the sets below the bottom: ≤ 1 rep short → hold (limit → one step back);
           2–3 short → one step back; more → −10 %
5. inside: limit → repeat the same reps; hard twice in a row at the same load without more reps → repeat;
           else +1 rep per set below the top (+2 when easy, or beginner with even sets and not hard)
hold guard: a hold (rules 2, 3-limit, 5) after two holds in which every target was met → +1 rep on the weakest set
           (all at the top: +1 increment) – a lifter who keeps rating "limit" but does every rep still progresses
AMRAP recalibration: AMRAP set ≥ 2 reps above its target → load = e1RM(AMRAP reps + 1) at RIR 2 for the bottom of the
           range, at most +30 % at once, when that is more than the normal step
e1RM floor: no reps missed in the last 4 weeks → never more than 15 % below the load the best e1RM of those 4 weeks
           supports (RIR 2) – limit ratings and holds alone cannot spiral the load down
breaks (unchanged): 3–6 wk → last weight × 0.95/0.9; > 6 wk → e1RM × 0.9 (× 0.85 beyond 12 wk) [68]
deload / taper week: load × 0.9 of the loading-week prescription, deload keeps about half the work sets
           (max(n/2, 2) of n ≥ 3, 1 of 2; no drop sets) – Bell 2023 [74]: ~50 % volume. Deload/taper sessions are
           tagged and skipped by progression, trend and e1RM, so the second deload session is again 90 % of the loading
           level and the next loading week resumes at the last loading level (§1.9) instead of "regressing" from it
```

**AMRAP calibration set** [P]: the last work set is "as many reps as possible – stop 1 rep before failure" in the first
3 sessions of an exercise (the start load is a guess from a 1RM or body-weight standards) and whenever the targets are
at the top of the range. Reps are otherwise capped at the target, so an under-estimated start (e.g. 60 kg for a true
100 kg 1RM) could never show itself without a rating; one near-failure set per exercise is cheap (Refalo 2023 [28]:
fatigue rises mainly over the last reps before failure) and is the least intrusive way to learn the real level – no
extra step, no rating needed. Rejected alternatives: assuming RIR 2–3 instead of 1 for unrated sessions only shifts the
e1RM a few % and cannot detect a 40 % under-estimate; a more prominent effort chip still depends on the user and the
"easy" rating (RIR 4+) is open-ended.

```text
simulation (test/gym_progression_sim_test.dart; lifter: reps to failure = 30·(1RM/load − 1), −1 rep per set)
deload 3:1, bench 1RM 85→90:    before 62.5 → deload 57.5, 50 → 50 "dip"    after 65 → deload 57.5, 57.5 → 65 → 67.5
"limit" chip every session:      before 60 → 55 → 50 → 45 → 40 → 35            after 60 → AMRAP → 77.5, held, +reps
pull-ups 10/9/8 pattern:         before 8× holdHard at 10/9/8 (1RM rising)      after 10/10/10 → +2.5 kg
beginner squat 1RM 60→92.5:      before 47.5 → 62.5 (microloaded to 10 reps)    after 47.5 → 70 (linear, then double)
bench start 60 vs 1RM 100:       before 65 after 12 sessions                    after 77.5 from session 2
```

**Training level:** beginners progress fastest and misjudge RIR conservatively → bigger steps unless a session was hard;
advanced lifters need more stimulus for smaller gains (Androulakis-Korakakis 2020 [77]) → one notch at a time unless they
explicitly rate a set easy.

**Bodyweight exercises** use the same rules on the total load (body share × body weight + added weight; pull-ups/dips
100 %, push-ups ~65 %, inverted rows 60 %; user-switched loaded exercises: squat/lunge 85 % – body minus shanks and
feet, Winter 2009 [76]). Exercises without a load step (push-ups, core) progress by reps beyond the range. Sessions
logged in the other mode are converted (old pull-ups logged with the body weight as weight → +0 kg added).

Every suggestion carries a machine-readable reason (`ProgressReason`) that the workout screens show, e.g.
"alle Sätze am oberen Ende mit Reserve – größerer Sprung" or "Gewicht halten: letzte 2 Einheiten schwer".
Not used (deliberately): daily readiness / HRV – no cheap, reliable per-exercise signal; the effort rating covers it.

### 2.5 Rest intervals

| Rule | Value | Tag |
|---|---|---|
| Multi-joint (compound) lifts | **2–3 min** (strength focus 3–5 min). Schoenfeld 2016: 3 min > 1 min for strength and hypertrophy in trained men [34] | [M] |
| Isolation / machines | **60–90 s** | [M] |
| Lower bound | > 60 s gives a small hypertrophy benefit over shorter rest; beyond ~90 s no extra benefit (Singer 2024 Bayesian meta [35]; Grgic 2017 [36]) | [M] |

### 2.6 Time-efficient techniques (Iversen 2021 [23]; Zhang 2025 [37]; Weakley 2017 [38]; Sødal 2023 [39])

| Technique | Evidence | Rule |
|---|---|---|
| Antagonist / non-competing supersets (e.g. bench + row) | Cut session time ~50% without losing volume or muscle activation; more perceived effort [37,38] | [M] Offer when sessionMinutes ≤ 45, or always for accessories |
| Agonist supersets / tri-sets | More fatigue, lactate and RPE [38] | [P] Avoid for BEGINNER |
| Drop sets | Same hypertrophy as traditional sets in ½–⅓ of the time [39] | [M] Last set of isolation exercises only, INTERMEDIATE+ |
| Rest-pause | Similar idea, little data | [P] optional, isolation only |

### 2.7 Deload [P]+[survey]

Rogerson 2024 survey (n = 246 strength/physique athletes) [40]: deload every **5.6 ± 2.3 weeks**, lasting **6.4 ± 1.7 days**.
Volume was cut (fewer reps and sets) while frequency was kept. No RCT shows the best timing.

```text
deloadEvery: BEGINNER none planned for the first 8–12 wk (only a reactive deload) · INTERMEDIATE every 4–6 wk · ADVANCED every 4–5 wk
deloadWeek: sets × 0.5, load × 0.9 (or RIR +2–3), frequency unchanged
reactiveDeload trigger: e1RM down ≥ 5% for 2 sessions, or RPE ≥ 2 above target on ≥ 2 lifts
hybrid athletes: put the strength deload in the same week as the endurance recovery week
```

Generator: beginners' strength sessions in endurance recovery weeks of the first 10 weeks keep the loading phase (no set
cut); from week 11 they deload with the endurance recovery week. The day before a key endurance session (C3/C4), a
full-body / home / bodyweight program keeps half of its leg work sets (at least 1); the planned workout carries that
adjusted exercise list, which the session start uses.

### 2.8 Split by days per week [P] (all keep ≥ 2×/week per muscle)

| Days | Split | Notes |
|---|---|---|
| 1 | Full body | Maintenance only (~4–6 sets/muscle) |
| 2 | Full body A / B | |
| 3 | Full body A/B/A or A/B/C | Best default for BEGINNER and for hybrid athletes |
| 4 | Upper / Lower × 2 | |
| 5 | Upper / Lower / Push / Pull / Legs, or U/L + 1 weak-point day | |
| 6 | Push / Pull / Legs × 2 | ADVANCED only |

Exercise order within a session: compound → accessory → isolation. Big lower-body lifts first. Core work last [P].

### 2.9 Concurrent training (strength + endurance)

| Evidence | Finding | Tag |
|---|---|---|
| Wilson 2012 meta [41] | Interference effect: hypertrophy ES 1.23 (strength only) vs 0.85 (concurrent); power 0.91 vs 0.55. **Running** interferes, cycling much less. Interference grows with endurance frequency and duration | [M] |
| Schumann 2022 meta (43 studies) [42] | **No** interference for hypertrophy (SMD −0.01) or max strength (−0.06). Explosive strength impaired (−0.28), mainly when **same session**; not when ≥ 3 h apart | [S] |
| Petré 2021 meta [45] | Lower-body 1RM impaired only in **trained** individuals (ES −0.35), and more when done in the same session | [M] |
| Murlasits 2018 meta [46]; Eddens 2018 [47] | Same session: strength **before** endurance → +3.96 kg lower-body 1RM. No effect on VO2max | [M] |

```text
scheduling rules (concurrent):
C1 [M] same day -> separate by >= 3 h (prefer >= 6 h); same-session only if time forces it
C2 [M] same session -> do the user's priority first; default strength first if goal includes strength,
       endurance first if a key endurance session (intervals/long) is planned
C3 [P] no heavy lower-body strength within 24 h BEFORE a key run/bike session; leave >= 48 h between heavy legs and a long run
C4 [P] "hard day hard, easy day easy": put leg strength on the SAME day as hard endurance (endurance AM, strength PM)
       rather than on an easy day, so recovery days stay easy
C5 [M] prefer cycling over running for extra cardio volume when hypertrophy is the main goal
C6 [P] endurance goal: 2 strength sessions/wk (full body, 2–3 sets, RIR 2–3, heavy-ish 4–8 reps) is enough; 1/wk in taper
```

---

## 3. Cycling

### 3.1 FTP estimation [P] (Allen & Coggan [48])

```text
FTP = 0.95 × avgPower(20-min all-out test)        // after a 5-min hard effort + recovery in the warm-up
FTP = 0.75 × best 1-min power in a ramp test       // ramp: +20–25 W/min (e.g. Zwift/TrainerRoad protocol)
FTP = 0.90 × avgPower(8-min test)                  // alternative (CTS)
no power meter: use LTHR (30-min solo TT, avg HR of the last 20 min) or HRmax zones (§5)
retest every 6–8 weeks or at the end of each build block
```

Generator (audit 2026-11, RS4): a power meter without a stated FTP plans its watts from a W/kg estimate (beginner 2.0,
intermediate 2.8, advanced 3.6 W/kg) – the first quality ride of the plan is a 20-min FTP test (warm-up with 3 × 1 min
pick-ups when the day has ≥ 55 min, 20 min as hard as can be held evenly; FTP = 95 % of its average, entered in the plan
settings), and every ride with watt targets says the watts are estimated. Every power-meter plan retests every 6 loading
weeks in base / build (not with a heart / blood-pressure limitation – no maximal efforts – and not on a day < 40 min).

### 3.2 Coggan power zones [P] and Friel/Coggan HR zones [P]

| Zone | Name | % FTP | % LTHR (Coggan) | Typical RPE |
|---|---|---|---|---|
| 1 | Active recovery | < 55 | < 68 | 1–2 |
| 2 | Endurance | 56–75 | 69–83 | 2–3 |
| 3 | Tempo | 76–90 | 84–94 | 4–5 |
| SS | Sweet spot | 88–94 | ~92–96 | 5–6 |
| 4 | Lactate threshold | 91–105 | 95–105 | 6–7 |
| 5 | VO2max | 106–120 | > 106 | 8–9 |
| 6 | Anaerobic capacity | 121–150 | n/a | 9–10 |
| 7 | Neuromuscular | > 150 (max sprints) | n/a | 10 |

Friel cycling HR zones (% LTHR): Z1 < 81 · Z2 81–89 · Z3 90–93 · Z4 94–99 · Z5a 100–102 · Z5b 103–106 · Z5c > 106.
Friel running (% LTHR): Z1 < 85 · Z2 85–89 · Z3 90–94 · Z4 95–99 · Z5a 100–102 · Z5b 103–106 · Z5c > 106 [49].

### 3.3 Polarized vs sweet spot

- Neal 2013 (trained cyclists, 6 wk): polarized > threshold-heavy for peak power and lactate-threshold power [50] **[M]**.
  Rosenblat 2019 meta: polarized ≥ threshold for time-trial performance, small effect [51] **[M]**. See also §1.1 [5].
- Sweet spot (88–94% FTP) is time-efficient but adds fatigue. Evidence is practice-based **[P]**.

```text
weeklyBikeHours < 5  -> pyramidal: 1 sweet-spot/threshold + 1 VO2 session, rest Z2 (also in base) [P]
weeklyBikeHours 5–10 -> 80/20: 2 quality sessions (1 threshold/SS, 1 VO2) + long Z2 ride   [M/P]
weeklyBikeHours > 10 -> polarized in peak phase (Z3 by VO2/anaerobic work, Z2 long rides)  [M]
```

### 3.4 Training load: TSS / CTL / ATL / TSB (Banister impulse-response) [P]

```text
IF  = NP / FTP                                 // NP = normalized power (30-s rolling avg ^4, mean, ^0.25)
TSS = (duration_s × NP × IF) / (FTP × 3600) × 100  ==  hours × IF² × 100
running (rTSS): IF = threshold pace (as speed) ratio = v_ngp / v_T   -> rTSS = hours × IF² × 100
swimming (sTSS): IF = v / v_CSS               -> sTSS = hours × IF³ × 100
HR only (hrTSS):  IF ≈ avgHR_above_rest / LTHR_above_rest (approx.)  or use TRIMP:
TRIMP_Banister = minutes × ΔHR × 0.64·e^(1.92·ΔHR) (men) | 0.86·e^(1.67·ΔHR) (women),
                 ΔHR = (HRavg − HRrest) / (HRmax − HRrest)
strength/no data: sRPE_load (§0); approx TSS ≈ sRPE_load / 6 for display        [P, heuristic]

CTL_t = CTL_{t-1} + (TSS_t − CTL_{t-1}) · (1 − e^(−1/42))   // "fitness", τ = 42 d
ATL_t = ATL_{t-1} + (TSS_t − ATL_{t-1}) · (1 − e^(−1/7))    // "fatigue", τ = 7 d
TSB_t = CTL_{t-1} − ATL_{t-1}                               // "form"
Banister: performance(t) = p0 + k1·Σ w(s)e^(−(t−s)/τ1) − k2·Σ w(s)e^(−(t−s)/τ2),  default τ1 42, τ2 7, k1 1, k2 2 [52]
guidance [P]: CTL ramp ≤ 5–7 TSS/day per week (≤ 3–5 for beginners); TSB −10…−30 during build is normal;
race-day TSB target +5…+25
```

### 3.5 Cycling workout library [P]

| Workout | Structure | Progression |
|---|---|---|
| Endurance (Z2) | 60–240 min at 56–75% FTP | +15–30 min/week on the long ride |
| Tempo | 2–3 × 15–30 min Z3 | +5 min per interval |
| Sweet spot | 3 × 10 → 2 × 30 min at 88–94%, 5 min rest | total SS time 30 → 60–90 min |
| Threshold | 4 × 8 → 2 × 20 min at 95–105%, rest ≈ 1/2 work | 20 → 60 min total in Z4 |
| VO2max | 5 × 3 → 5 × 5 min at 106–120%, rest = work. Or 30/15 s × 10–13 × 3 sets | 15 → 25 min total in Z5 |
| Anaerobic | 8 × 30–60 s at 130–150%, rest 2–4 min | +2 reps |
| Sprints | 6–10 × 10–15 s max, full rest | — |
| Recovery | 30–60 min Z1 | — |

Generator (audit 2026-11, RS1 / RS9 / RS8 / T2 / tri-6 / RS5):

```text
sweet spot / beginner threshold : the work time (24 → 60 min, beginners 15 → 40 / 30, recovery weeks 70 %) picks the last
                  step of the ladder 2 × 10 → 3 × 10 → 2 × 15 → 2 × 20 → 3 × 15 → 2 × 25 → 2 × 30 min that fits (+3 min) –
                  never "3 × 5 min" (blocks < 8–10 min at 88–94 % build fatigue without the time-at-SS stimulus)
threshold       : 3 × 10 → 3 × 12 → 3 × 15 → 2 × 20 → 2 × 25 min at 91–100 % FTP (the watt range and the note agree;
                  beginners' threshold blocks too – their note said 95–105 % on a 91–105 % range)
tempo (base)    : Z3 76–90 % FTP, the note says 76–90 %; race-specific tempo (70.3 / Ironman / Gran Fondo peak) has its own
                  watts 75–85 % FTP; the Ironman text calls it a notch above race power (~65–75 % FTP)
fit to the day  : fewer blocks first (≥ 2; VO2max ≥ 3), then the cool-down (≥ 3 min) and the warm-up (≥ 8 min), then
                  shorter blocks (≥ 8 min; VO2max ≥ 3 min) with recoveries ≤ 0.3 × the block (≥ 2 min); when even that does
                  not fit: an easy Z2 ride with 3–4 × 1 min pick-ups (not a key session) instead of a token interval session
race week       : the quality ride is openers – Z2 with 3–4 × 1 min pick-ups
knee / hip      : no seated low-cadence climbing repeats (patellofemoral load rises with torque); every ride notes high
                  cadence 85–95 rpm, easy gears on climbs, saddle height (§9.1)
long ride       : the first one ≤ 110 % of the athlete's longest recent ride (at their easy speed), else a long-ride race
                  (≥ 3 h) starts at 90 min (advanced 2 h, beginners 1 h); then ≤ +10 % (≥ 15 min) a loading week – a goal
                  that needs more gets 10–20 min steps (Ironman intermediate in 24 weeks: 90 → ~275–300 min);
                  recovery rides ≤ 90 min
ride distance   : at the athlete's speed for the zone – from the FTP (GoalModel.bikeKmh) or the level's long-race speed
                  (25 / 29 / 33 km/h × 0.93 at ~72 % FTP) × (power share / 0.72)^(1/3); a fixed 27 km/h overstated a
                  beginner's km by ~16 %
```

---

## 4. Swimming

### 4.1 Critical Swim Speed (CSS) [M] (Wakayoshi 1992 critical velocity [53]; Swim Smooth [54])

```text
test: warm-up 300–400 m, all-out 400 m (T400 s), 5–10 min easy, all-out 200 m (T200 s)
CSS_speed (m/s)        = (400 − 200) / (T400 − T200)
CSS_pace (s per 100 m) = (T400 − T200) / 2
validity check: require T400 > 2·T200 (otherwise pacing was off -> retest)
retest every 6–8 weeks
fallback without a test: CSS_pace ≈ T400/4 + 4 s/100 m (practice) or use RPE
```

### 4.2 CSS pace zones [P] (Swim Smooth / common coaching)

| Zone | Pace per 100 m | Use |
|---|---|---|
| 1 Recovery | CSS + 15–20 s | Warm-up, cool-down, drills |
| 2 Endurance | CSS + 8–12 s | Aerobic volume |
| 3 Tempo / Sweet spot | CSS + 3–6 s | Long reps (300–800 m), short rest |
| 4 Threshold (CSS) | CSS ± 2 s | e.g. 8–15 × 100 m on 10–15 s rest; 4 × 400 m |
| 5 VO2 / Speed | CSS − 3 to −10 s | 25–100 m reps, long rest |

### 4.3 Session structure [P]

| Block | Share | Content |
|---|---|---|
| Warm-up | 15–20% | Easy mixed strokes, build |
| Drills / technique | 10–20% (BEGINNER 30–40%) | Kicking with fins, catch-up, single-arm, fist, 6-kick switch, sculling |
| Main set | 50–60% | CSS/tempo/endurance reps |
| Cool-down | ~10% | Easy |

Generator: technique sessions ≤ ~60 min. Endurance swims grow continuous repeats: BEGINNER 100 → 200 → 400 → 800 m
(every 3 weeks), others 200 → 400 → 800 → 1000 m (every 4 weeks), the longest repeat by race (`swimRepMax`: sprint
400 m, olympic / 70.3 800 m, Ironman 1000 m), always ≥ 2 whole repeats that fill ≥ 75 % of the main set (rounding
2.5 × 800 m up made the volume jump +30 %). Build / peak: main set 70 % of the session. A single weekly swim is one
endurance swim with a drill block (the earlier technique / endurance alternation made the volume jump ±40 %). 70.3 and
Ironman with ≤ 5 days get a second swim as a double day (easy-session day far from the first swim, not the long day or
the day before it). Swimmers with ≥ 4 swims a week (swim focus): a second quality swim – tempo repeats 300 → 400 m at
CSS + 3–6 s. CSS sets are ~35 % of the session (3-swim weeks stay ~80/20 by time).

**Swim novices (fix/plan-pro, user report "13 × 100 m CSS for someone who cannot swim 400 m").** A swim novice is
anyone who said they cannot swim 400 m freestyle without stopping – *whatever the level in the other sports*. The answer
decides (audit 2026-11, RS2: a beginner without swim experience who answered "yes" got the 8 × 50 m ladder anyway); the
quick setup asks the question too ("Dein aktueller Stand": can run 30 min / can swim 400 m). Novices get:

```text
volume       : ~800 m per session at the start (§4.4 beginner 800–1500 m with breaks), ≤ 1.4 km per session
sessions     : warm-up 150 m easy with breaks · 2–6 × 50 m drills (kick with board, catch-up, side kick …, 30 s rest) ·
               the stage of the continuous-swim ladder · 100 m easy; ≤ 60 min, no pace targets (§4.5)
ladder       : 8 × 50 → 10 × 50 → 6 × 100 → 7 × 100 → 4 × 200 → 4 × 200 → 3 × 300 → 2 × 400 m, one stage per loading
               week, rest at the wall 30–45 s; technique days half the repeats; recovery 70 %, taper 65 / 45 %
CSS test     : after the last stage – 400 m and 200 m time trials (§4.1), the athlete enters the times in the plan
               settings; afterwards the normal sessions (CSS sets for non-beginners), long swims start at 400 m.
               Heart / blood pressure or shoulder: no all-out test, the normal sessions simply follow
no CSS set   : before the test (also for intermediate / advanced runners and cyclists)
swim zones   : CSS ~150 s / 100 m without a test (the level default 110 s of an intermediate was far too fast)
no swim experience, no test (can swim 400 m): starts at the beginner volume (1.5 km / session) whatever the level
beginner, can swim 400 m, no test: no ladder; a CSS test in the recovery week after ≥ 3 loading weeks (else after 6
               loading weeks), not with a heart / shoulder limitation
```

Drill blocks are whole 100 m ("alternate 50 m drill, 50 m freestyle"); a single 50 m drill step alternates the two drills
instead (RS10).

**Long swim** (swim-focus plans, with or without event): a weekly continuous swim on the long day, starting at ~90 %
of an average session (former novices 400 m; beginners 400 m, 500 m with a test – audit 2026-11 RS3: a beginner with a
10:00 400 m test started at 1.4 km – then +100–200 m per loading week as the race needs), +12 % (≥ 100 m) per loading week towards the race's continuous
distance (swim1500 1.5 km, swim3800 3 km, swim5000 4 km; without an event 1.5 / 2.5 / 3 km by level); recovery / taper
weeks by the long-session factors (§1.7). Open-water races and triathlon: sighting every 6–9 strokes in build / peak
and an open-water note (wetsuit, group / drafting, never alone).

Beginner sessions stay ≤ ~1.5 km (the long swim: its continuous part plus warm-up, drills and cool-down); the long swim's
title names the continuous part ("Lange Schwimmeinheit: 1000 m am Stück"). When the day's time cuts a continuous swim the
frame gives way first (warm-up ≥ 200 m, drills 100 m, cool-down ≥ 100 m – tri-7); a swim still cut is a `longSwim` issue
that names the day and the time that would hold it. "It grows ~100 m a week" is only said while it does. The only swim
of a non-beginner's week ends with 4 → 6 → 8 × 100 m at CSS in build / peak (tri-11). Two quality swims are ≥ 48 h apart
(UX-3).

### 4.4 Weekly volume by level [P]

| Level | Sessions/wk | Per session | Weekly |
|---|---|---|---|
| BEGINNER (cannot swim 400 m continuously freestyle) | 2–3 | 800–1500 m, rest breaks allowed | 2–4 km |
| NOVICE | 3 | 1500–2500 m | 4–7 km |
| INTERMEDIATE | 3–4 | 2500–3500 m | 8–14 km |
| ADVANCED / triathlon long course | 4–6 | 3500–5000 m | 15–25 km |

Progress swim volume by ≤ 10%/week [P]. Swimming has low impact, so injury risk sits in the shoulders. For a beginner, limit
paddle use, keep breathing bilateral, and progress main-set volume no faster than technique allows.

### 4.5 Technique emphasis for beginners [P]

Order: (1) breathing and exhaling underwater; (2) body position, horizontal with head neutral; (3) rotation and
bilateral breathing every 3; (4) catch and pull (high elbow); (5) kick from the hips with a small amplitude. Use fins and a pull buoy as
aids. For BEGINNER, don't use pace targets for the first 4–6 weeks: give reps by distance and rest by breaths/RPE.
(Generator: beginners without a test never get swim paces; with a test not in the first 5 plan weeks.)

**Goal-directed swim novices** (fix/plan-goal-progression) [P]: a triathlon whose continuous swim (sprint 400 m,
olympic / 70.3 800 m, Ironman 1000 m) cannot be reached in the weeks before the taper (8 ladder stages + CSS test +
100 m a week after it) runs the ladder at 6 stages (skips 50 m × 10 and the second 200 m × 4). After the CSS test one easy
swim a week is a *continuous swim*: 500 m, then +100 m per loading week (≈ +15–20 %, little impact load, H8) up to the
race's distance (recovery / taper ~70 %, race week ~50 %).

**Triathlon beginners who can swim 400 m** (review round 2, IMPORTANT 8) [P]: a sprint beginner with one swim a week
reached only 200 m in one go. Triathlon beginners now get ≥ 2 swims a week (§4.4: 2–3 sessions; the second as a double
day far from the first), one of them the continuous swim: 300 m in week 1 (below the 400 m they can swim), +100–200 m
per loading week towards the race's swim leg (sprint 750 m; the target never exceeds the leg) – sprint 10 weeks:
300 → 400 → 500 → 600 → 700 m before the taper instead of 200 m. When the weeks are too few, the `longSwim`
feasibility issue offers a later race date like the other timing issues.

---

## 5. Heart-rate zones

```text
HRmax (measured) > predicted. Predicted:
  Tanaka 2001:  HRmax = 208 − 0.7·age     (meta-analysis of 351 studies, n ≈ 18,700; SEE ≈ ±10 bpm) [55]   [S]
  Gellish 2007: HRmax = 207 − 0.7·age     (longitudinal) [57]                                                [M]
  Gulati 2010:  HRmax = 206 − 0.88·age   (women, n = 5437; Tanaka overestimates female HRmax, ~5 bpm at 50) [58] [M]
  220 − age:    underestimates HRmax in older adults, overestimates in young; do not use as default          [S]
  generator: measured HRmax > Gulati (gender f) > Tanaka (m / d)
  sport offsets [P]: cycling HRmax ≈ run − 5…10 bpm; swimming ≈ run − 10…15 bpm
Karvonen (heart-rate reserve) [56]:
  HR_target = HRrest + pct × (HRmax − HRrest)     // HRrest = morning resting HR
LTHR (Friel): avg HR of the final 20 min of a solo 30-min TT (run or bike)                             [P]
```

**5-zone %HRmax model** (Olympiatoppen / Seiler, maps onto the 3-zone model) [1] **[P]**:

| 5-zone | %HRmax | ≈ %HRR | 3-zone |
|---|---|---|---|
| Z1 | 55–72% | 40–60% | Z1 |
| Z2 | 72–82% | 60–72% | Z1 |
| Z3 | 82–87% | 72–80% | Z2 |
| Z4 | 87–92% | 80–88% | Z3 |
| Z5 | 92–100% | 88–100% | Z3 |

Priority of anchors: lab LT/VT > LTHR / FTP / CSS / VDOT field test > measured HRmax (with HRR) > Tanaka prediction > RPE only.
Always show RPE beside HR because of cardiac drift, heat and HR lag in short intervals [P].

---

## 6. Hybrid / triathlon weekly scheduling

### 6.1 Core rules

```text
H1 [P/M] max 1 key session per day; no key sessions on back-to-back days for BEGINNER/NOVICE
         (INTERMEDIATE+: max 2 consecutive key days, then an easy day)
H2 [P]   hardSessionBudget/week (all sports, including heavy lower-body strength counted as 0.5–1):
         totalSessions <= 4: 2 · 5–7: 3 · 8–10: 4 · >= 11: 4–5 (ADVANCED)
H3 [P]   >= 48 h between two HARD sessions that stress the same system (e.g. run intervals & run tempo)
H4 [M]   concurrent rules C1–C6 (§2.9)
H5 [P]   long sessions on the weekend (or the user's preferred long days); do not put the long run the day after a hard run
H6 [P]   recovery-week alignment: all sports deload in the same week
H7 [P]   at least 1 full rest day/week for BEGINNER/NOVICE; ADVANCED may use active recovery (Z1 swim/spin)
H8 [P]   cycling and swimming count only ~50–70% as much as running toward musculoskeletal (impact) load;
         when the user wants more volume, add it via bike/swim before adding run km
```

Generator implementation of H1–H3 (review 2026-11):

```text
key days     : never 3 in a row; BEGINNER / INTERMEDIATE / age >= 50 never 2 (long run + long ride of different sports may
               follow each other, except masters)
CSS swim set : a key session for spacing, weighted as half: may sit next to long Z2 sessions – also right before a Saturday +
               Sunday long block – but never in a chain with a quality session (masters: only next to one long Z2 session)
H3           : ADVANCED may go hard on consecutive days only across sports – never two key runs (or rides) within 48 h
H2 budget    : with >= 2 endurance sports one budget across sports: sessions <= 4: 2 · 5–7: 3 · more: 4 points;
               quality run / ride 1, long session 0.5, CSS set 0.5; base phase <= 2 quality sessions (BEGINNER 1).
               Priority: bike quality first; base CSS before run quality, build / peak run quality before CSS – another
               order only if it fits more quality sessions. Quality days avoid double days.
```

Triathlon intensity rotation (coach review 3, B7/B8; an olympic 6-day week with long sessions Saturday + Sunday had zero run
quality and zero CSS sets in 16 weeks):

```text
build / peak : the order of the sports is chosen by value = 2 · sessions + 3 · (disciplines without quality last week);
               ties: the discipline that waited longest – the single full quality slot such a week leaves rotates bike ↔ run,
               the CSS set goes next to the long block
invariant    : every discipline with >= 2 sessions a week gets >= 1 quality session per 2 loading weeks (build / peak).
               Exceptions (H1 wins): beginners (no back-to-back key days, no CSS yet: >= 1 quality of any discipline per
               2 weeks); a discipline whose other days all sit right next to a long session (intermediates / masters), or
               flank a Saturday + Sunday long block (three key days in a row)
masters      : the long sessions are kept apart only where the second sport keeps a day for its quality session that is
               not next to a long one; if a build / peak week still has no quality at all, they may follow each other
long day     : without a chosen long day the day with the most time set (70.3 with Sat 240 / Sun 120 min → long ride
               Saturday; before: Sunday, 120 min); the second long session goes on the free day with the most time
70.3 peak    : race-specific bike tempo 2 × 25 → 2 × 30 → 3 × 25 min at 75–85 % FTP (Z3) instead of VO2max 6 × 4 min
swim drills  : no pace target (technique, not speed); session feedback ignores them for the pace signal
```

### 6.2 Session allocation by days available (examples, all sports in hybrid order of priority) [P]

Triathlon time split by default: swim ~20%, bike ~45–50%, run ~30–35% of weekly endurance time [P].

| Days/wk | Triathlon (sprint/olympic) | Run + strength | Run + bike + strength (hybrid) |
|---|---|---|---|
| 3 | Swim · Bike (quality) · Run (long/brick) | Run Q + Full body · Run E · Run long + Full body | Run Q · Bike Z2 + Strength · Run long |
| 4 | Swim · Bike Q · Run Q · Brick (long bike + 15 min run) | Run Q · Full body A · Run long · Full body B + Run E | Run Q (AM) / Strength (PM) · Bike Q · Strength · Run long |
| 5 | Swim · Bike Q · Run Q + Swim · Bike long · Run long | 3 runs + 2–3 strength | 2 runs, 2 rides, 2–3 strength |
| 6 | 2 swim · 2 bike (1 Q, 1 long/brick) · 2 run (1 Q, 1 long) | 4 runs + 2–3 strength | 3 run · 2 bike · 2–3 strength |
| 7 | as 6 + 1 recovery swim | — | — |

Example week (6 days, triathlon, BALANCED):

```text
Mon  Rest (or 30 min easy swim technique)
Tue  Run intervals (Q)            | PM: swim CSS set
Wed  Bike Z2 60–90 min            | PM: strength full body (RIR 2–3)
Thu  Swim endurance               | PM: easy run 30–40 min
Fri  Bike sweet spot / threshold (Q)
Sat  Brick: long bike (Z2) + 15–30 min run off the bike at goal pace
Sun  Long run (E)                 | optional: strength (upper / core)
```

### 6.3 Brick sessions [P]

- Start in **build phase**; 1 brick every 1–2 weeks (weekly in the peak phase for triathlon).
- Run off the bike: 10–15 min to start → 20–30 min (olympic) → 45–60 min (70.3/ironman, ADVANCED). The first 5 min at
  E/race feel, then goal pace.
- A brick counts as a key session (H1/H2). Transition practice: ≤ 2 min.

Generator (fix/plan-pro): a run off the bike follows the long ride **every loading week from the build phase** (every
second week made the run volume jump ±10–50 % week to week), not while on run/walk: sprint 10 → 20 min, olympic 10 →
30, 70.3 / Ironman 10 → 45 (ADVANCED 60), duathlon 10 → 20 / 10 → 30, +5 min per brick, ≤ ~60 % of that week's long
run and ≤ ~25 % of the week's run km. The brick counts as run volume: the easy runs shrink first, then the long run by
≤ 8 %. The long-ride day keeps the longest brick's time free in *every* week (≤ a third of the day), so the long ride
does not shrink when the bricks start or grow. Duathlon peak: run – bike – run (a 10 → 20 min run before the ride as
well). Part of that day's key session (intensity "moderate"), first 5 min easy, then steady race feel. Long ride share
of the bike hours: 2 rides 60 %, 3 rides 50 %, more 42 % – up to 60 % when the race's long ride needs it (§14), never
beyond the event cap; 5-min steps (15-min steps kept a slowly growing long ride flat for 4 weeks).

Multisport with ≤ 3 runs a week: the run day rotates quality ↔ easy (B7). The easy run is ≤ ~half the long run (minus
the brick), and a quality run gets the run km left after the long run and the brick (R3: intensity in, volume held) –
before, the run volume jumped ±25–35 % from week to week. Long runs of multisport races rotate in the peak too (long →
long → shorter), never with the shorter week right before a recovery / taper week.

**Ironman weekends and session counts** (review round 2, IMPORTANT 9) [P]: Ironman age-group plans (Friel [86];
Fitzgerald & Warden 80/20 Triathlon [87]) train each discipline ≥ 3 × a week and do not stack the longest ride with
brick and the longest run on consecutive days. The generator therefore (1) adds a third ride and a third swim as
second sessions on days with ≥ 90 min (two ~45 min sessions; a ride goes with a swim, a swim with a run, so the
quality ride keeps its day; never on the long-ride day) – 70.3 keeps the rule "≥ 60 min on top of the day's session";
(2) alternates brick weeks whose long run is next to a long ride ≥ 4 h: a *ride weekend* (full long ride + brick, the
next day's long run ≤ 75 % / ≤ 2 h, planned as the shorter long-run week) and a *run weekend* (long ride ≤ 3 h with a ≤ 20
min transition run, the full long run). Counted back from the taper, the last loading week is a run weekend; the long
ride's progression ignores the capped weeks. Advanced Ironman 28 wk: 2 rides / 2 swims → 3 / 3 per week; peak weekend
"300' + brick, then 30 km" → "300' + brick, then 21–22.5 km" alternating with "180' + 20' brick, then 30 km".

**Audit 2026-11 (G2)** [P]:

```text
long run day    : the second long session goes on the free day the athlete gave the most time besides the long day (Sat 300
                  / Sun 150 min: long run Sunday – it went on a 60 min Friday at up to 165 min); days with more time than
                  the usual session are kept first when a beginner's week drops a day; the long ride takes the long day when
                  a day plan puts ride + run there; the long-day note names every long-session day left at its default
2 days          : triathlon on 2 days – long ride (+ brick) on the long day, swim + run as a double day on the other; sprint
                  needs ≥ 1 swim / ride / run a week (frequency warnings)
third run       : 70.3 / Ironman intermediate / advanced with ≥ 6 days or 2 sessions a day – an easy run as a second session
                  (preferably after a swim, not next to another run day); the long run keeps ~50–60 % of the week's run km,
                  the third run splits the second one's volume; easy runs in loading weeks ≥ 25 min (advanced 30)
taper           : one shortened quality run and ride also with 2 a week (intensity kept, §1.7); race week: ride openers
run/walk        : with 1–2 runs a week a stage takes 2 loading weeks, the long run/walk's running ≤ 1.5 × the stage's and
                  ≤ +10 % / +5 min a week
duathlon peak   : the run before the ride counts as run volume (quality run cap); brick weeks ≤ +12 % run km on the last
                  loading week – the long run gives ≤ 8 %, then the brick / pre-ride run (whole 5 min, titled as planned)
day plan bricks : the brick is the run slot of its day (no brick + separate run); a knee swap never puts a second ride on a
                  day – the run's time goes to that day's ride
race day        : bike leg at the event's race power (Ironman ~70 % → Z2, 70.3 / olympic / sprint Z3, watts with an FTP),
                  runs by the predicted leg pace (E included); finish-only: Z2 / E; leg km localised; a time the athlete
                  did not set is a "Prognose", no "first km" cue
same-day order  : PlannedWorkout.slot – run before the bike, swim, ride, brick, other runs, strength
```

---

## 7. Default progression summary (generator flow)

```text
1. inputs: sports, goal(s) & date, days/week, minutes/day, level, recent race/test results, age, difficulty
2. anchors: VDOT (1.2), FTP (3.1), CSS (4.1), HRmax/LTHR (5) -> zones
3. plan length & phases (1.6/1.8), with taper (1.7) scheduled backwards from race day
4. weekly volume curve: start = current volume (or the level default), grow by g (§8) toward the ceiling,
   deload every N weeks (1.9/2.7), taper at the end
5. sessions/week per sport (6.2) -> place long & key sessions (H1–H8, C1–C6)
6. fill sessions from workout libraries (1.11, 3.5, 4.2/4.3, 2.x) with phase-appropriate templates
7. strength: split (2.8), sets (2.1), reps/RIR (2.3), progression (2.4), rest (2.5)
8. validate: R1/R2 caps, zone caps (1.4), hard budget (H2), 80% easy (1.1); auto-fix by
   downgrading the lowest-priority key session to EASY or shortening it
9. adapt weekly from logged data: missed sessions -> no progression; RPE >= target+2 twice -> repeat the week;
   pain flag -> −30% run volume and no intensity for 1 week, recommend a professional if it persists
```

---

## 8. Difficulty settings ("easy / balanced / challenging") [P, bounded by the evidence above]

Difficulty changes **rate and density**, never the safety caps (R1, taper, C1).

| Parameter | EASY | BALANCED | CHALLENGING | Evidence anchor |
|---|---|---|---|---|
| Weekly endurance volume growth g | +5% | +8% | +10% (max +30% over 2 wk) | Buist 2008 [9], Nielsen 2014 [10] |
| Longest single run vs 30-day max | ≤ +5% | ≤ +10% | ≤ +10% (hard cap) | Frandsen 2025 [11] |
| Load : recovery weeks | 2:1 | 3:1 | 3:1 (4:1 ADVANCED) | practice |
| Recovery week volume | 60% | 70% | 75% | practice |
| Share of easy sessions | ≥ 85–90% | ≈ 80% | ≈ 75–80% | Seiler [1], [5] |
| Quality sessions/wk (endurance) | 0–1 | 1–2 | 2–3 | 1.1 |
| Volume ceiling (table 1.8) | Novice column | level column | level column +15% | practice |
| Strength sets/muscle/wk | low end (2.1) | middle | high end | [21,22] |
| Strength target RIR | 3 | 2 | 1 (isolation 0) | [27,28] |
| Strength progression | double progression, slow | linear/double | DUP for INT+ | [32,33] |
| CTL ramp (TSS/day per week) | ≤ 3 | ≤ 5 | ≤ 7 | practice |
| Plan length when flexible | upper end of range | middle | lower end | 1.8 |

Auto-downgrade [P]: if a user completes < 70% of planned sessions over 2 weeks, or logs RPE ≥ target + 2 on most sessions,
suggest moving one difficulty level down (or repeat the week).

---

## 9. Safety notes

- Screen: PAR-Q+ style questions before the first plan. For chest pain, syncope or known cardiac disease, require medical clearance [P].
- Pain rule: stop the session for sharp or localized pain, or pain that changes your gait. Pain ≤ 3/10 that settles within 24 h is
  acceptable for easy running [P].
- Heat/altitude: prescribe by HR/RPE, not pace [P].
- Ages < 16: no maximal tests, no RIR 0, endurance volume ≤ the NOVICE column [P].

### 9.1 Health limitations in the plan (setup: knee, back, shoulder, hip, ankle/Achilles, heart/blood pressure) [P]

The setup asks for limitations in both the quick and the detailed setup (`AthleteData.limitations`). The generator never
diagnoses or treats; it removes the loads that are most likely to aggravate the area and keeps the rest of the plan. All
rules live in `HealthFlags` (lib/services/health_limits.dart), which the strength side also reads.

```text
knee | hip | ankle (incl. Achilles)  -> lowImpactRun
  run volume curve × 0.9, growth at the EASY rate (5 %/week), long run ≤ +5 % (R1 EASY)
  no strides (R) and no VO2max reps (I): build/peak quality = threshold / cruise intervals,
    fartlek pick-ups at T instead of I (vertical ground-reaction force rises with speed [61])
  ≤ 1 quality run per week
  ≥ 3 runs/week -> one easy run becomes an easy ride of the same duration (cross-training keeps
    the aerobic stimulus without impact; H8)
  beginners without race times start with run/walk (no running experience: stage 1, else 3 × 5 min)
  note on every run: soft surfaces, stop if pain > 3/10 or it changes the stride (pain-monitoring model [62])
knee | hip -> strength note: pain-free range of motion, reduce depth or load
knee | hip -> cycling: no seated low-cadence (60–70 rpm) climbing repeats – the sweet spot stays at a normal cadence;
              every ride notes high cadence (85–95 rpm), easy gears on climbs, saddle height, stop with pain (high
              pedal torque raises patellofemoral / tibiofemoral load)
back       -> avoidAxialLoading: strength note (no heavy back squat / deadlift; leg press, split squat,
              hip thrust; lumbar compression in squats reaches several times body weight [64]);
              the strength programs may read the flag – the generator does not rewrite them
shoulder   -> avoidOverhead: swims ~20 % shorter, CSS sets become technique sessions, note "no paddles,
              bilateral breathing" (paddles and volume are the main loads in swimmer's shoulder [63]);
              strength note: no heavy overhead pressing
heart      -> capIntensity: nothing above threshold – no I/R runs, no Z5 rides (VO2 sets become threshold),
              no strides in the shake-out, ≤ 1 quality session per sport and week; note on quality sessions;
              strength note: 2–3 reps in reserve, exhale on effort, no breath holding (Valsalva drives
              systolic pressure far above 200 mmHg in heavy lifts [65]). Moderate continuous and threshold
              work stays – it is what exercise guidelines for hypertension recommend [60]; medical clearance first.
```

### 9.2 Sex [M/P]

Sex is used only where the evidence gives a different number, never to change the training content:

- **HRmax prediction:** women Gulati (206 − 0.88·age) [58], men and "diverse" Tanaka [55]; a measured HRmax always wins.
  All heart-rate targets follow (Karvonen when resting HR is known).
- **Not used:** menstrual-cycle based periodisation – the meta-analysis of McNulty 2020 [59] found only trivial, inconsistent
  performance differences across phases, so the plan does not shift sessions by cycle phase (users can move sessions themselves).
  Volume, progression, recovery weeks and strength dosing are the same for all athletes; individual responses are handled by the
  RPE/compliance recalibration (§11) instead of group stereotypes.

---

## 11. Adaptive recalibration from RPE, compliance and new best efforts [M/P]

"Re-plan & recalibrate" (calendar) adapts the next 14 days of the current plan to the last 14 days of training
(`Recalibrator`, lib/services/plan_recalibrate.dart). The athlete sees every change before it is applied; done workouts,
strength sessions (handled by the load prescription) and races are never changed.

**Signals.** Session RPE (CR10, asked after the session) is compared with the intended intensity using the three-zone
model of §0 (Z1 RPE 1–4, Z2 5–6, Z3 7–10) – session-RPE is a valid internal-load measure across sports [43, 66].

```text
too hard (score 1):    easy / technique / long RPE >= 7 · tempo RPE >= 9 · intervals RPE 10
elevated (score 1/2):  easy / technique / long RPE 5–6 (threshold-like effort on an easy day)
too easy:              tempo / intervals RPE <= 4 (a zone-1 effort for a quality set)
completion:            done share of the due planned minutes (each workout <= its plan), needs >= 3 due workouts (races
                       excluded) whose first lies >= 7 days back – a plan that started yesterday with one missed workout
                       (or leftovers of an older plan) is no "0 % done"; the break rule needs the same 7 days of history
cut short:             session < 80 % of the planned duration / distance
best effort:           fastest 5 km / 10 km / HM / M of the last 90 days (km splits or whole runs)
```

**Rules** (on planned endurance workouts of the next 14 days):

| Signal (last 14 days) | Change | Rationale |
|---|---|---|
| too-hard score ≥ 2 | days 1–7 −10 %; next quality session per sport → easy (~80 % of its time) | §7.9 "RPE ≥ target + 2 twice → repeat the week"; rising RPE at the same external load is an early marker of non-functional overreaching [67] |
| too-hard score ≥ 3 | days 1–7 −20 %, days 8–14 −10 %; all quality of days 1–7 → easy (taper keeps its intensity) | as above, stronger signal; reduce load before intensity is resumed [67] |
| completion < 70 % | days 1–7 −10 % (no progression after missed training) | §8 auto-downgrade (< 70 % over 2 weeks); ACWR spikes after gaps raise injury risk [13] |
| completion < 50 % | days 1–7 −20 %, days 8–14 −10 %, first quality per sport → easy (re-entry) – only when the key sessions (quality / long) themselves were missed (< 75 % of them done); with the key sessions done (easy runs skipped – chronic partial adherence) the easy volume comes down, the key sessions and the long run keep theirs and missed key sessions are still moved | detraining after ~2 weeks of reduced training [68]; gradual return; coach review 3 (B9): turning done key sessions easy week after week removed the intensity the athlete was actually doing |
| ≥ 2 sessions cut short | long sessions of the next 14 days −10 % | the planned duration was not sustainable |
| ≥ 2 quality sessions at RPE ≤ 4, no fatigue signal, completion ≥ 90 % | easy + long sessions of loading weeks, days 1–7, +5 % – not when a threshold (VDOT / FTP / CSS) rises in the same recalibration, and not on a workout the AutoAdjuster reduced in the last 7 days | within the 5–10 %/week growth rule (§1.5); R3: never raise volume and intensity together (the new paces are the step up) |
| return after a break: a planned sport with no session for ≥ 10 days (or < 15 % of its due training in the 14 days), trained before | days 1–7 at 60 % of the plan (50 % after ≥ 21 days off), days 8–14 at 70 %; all quality of days 1–7 → easy (the easy replacement scaled the same way); missed key sessions dropped | R4: restart at 50–70 % of the pre-break volume [68]; the plan is the pre-break reference |
| every long session of the 14 days (run, ride, swim) | ≤ 1.1 × the longest session of that sport in the 30 days before it (× 1.1 per earlier long session of the horizon, which counts as done); none in those 30 days → ≤ 0.6 × the longest in the 120 days before. When every long session of those 30 days was done at ≥ 90 %, the generator's own growth is the reference (longest done × the plan's step to this one – a goal-directed build grows +10 min / up to +25 %); a long session the AutoAdjuster capped after a hard cut-short long run is not lowered again; run/walk by time | R1, Frandsen 2025 [11] – applied as a cap, not only when increasing. Runs / swims by distance (sessions without one, e.g. a treadmill without a foot pod, by time), rides by time |
| missed key session in the last 3 days | moved to a free day of the same week (the missed workout's week – never into the next one), never next to another hard day; missed easy sessions dropped; with completion < 50 % (re-entry) key sessions are dropped, not made up | same rules as "adjust my week" (plan_adjuster) |
| faster best effort | run pace targets follow the new VDOT: with race times only upwards and ≤ +2 points at once; without race times the level default is replaced (downwards only by a real effort: race, RPE ≥ 8 or HR ≥ 88 % HRmax – not by the fastest 5 km of an easy run); the new VDOT is stored as the profile's `vdotEstimate` (never as a race time, §11.2) | Daniels [7]: update VDOT from races / time trials, small steps |

Reductions never stack beyond the strongest rule (the minimum factor wins); an increase only happens without any reduction
reason. Reductions are computed from the workout's **original** volume (the generator's, kept in the change record), so they
replace an earlier automatic or recalibration step instead of compounding on it: running the assistant twice, or a week later
on an overlapping look-back, changes nothing more (changes below 3 % – the rounding of the steps – are skipped). Each volume
change stores that original as an `AutoAdjustment` record (reason `recal`; a quality → easy swap stores the easy replacement,
`recalEasy`, whose 0.8 time share later reductions take into account) – the planned workout shows it with undo. Imported
sessions whose RPE was estimated from heart rate are judged like sessions without RPE (§12.1), not by the RPE table.
Simulated: two sick weeks → 60 % / 70 % → the volume is back at the plan three weeks after the return; the long run climbs
back by ≤ 10 % a week (R1). Volume changes scale continuous parts (steady runs / rides, swim sets); short repeats keep their length, so a reduced
interval session keeps its intensity (Bosquet 2007 [18]: cut volume, keep intensity). Every changed workout gets the note
"Adjusted to your recent training" (once, translatable).

A key session turned easy is written with `isKey: false` (the Firestore update sets fields the new workout drops – isKey,
steps, phase, auto – to their default instead of leaving the old value; before, a swapped session still counted as key).
Race-pace steps (zone M at a goal pace other than the old VDOT's marathon pace) keep their goal when the VDOT steps up.

### 11.1 Gaps in the plan (deleted sessions, empty weeks, plan ended) [P]

The same assistant also proposes sessions the plan expects but the calendar no longer has (`PlanGaps`,
lib/services/plan_gaps.dart). Refills are only a proposal: a section "Gaps in the plan" in the preview lists each one
(date, title, time / distance, why) with a tick box (default on); nothing is written until "Apply".

**Which week the plan expects.** The plan is rebuilt with the generator from its start: plan start and length are stored on
the profile (`athlete.planStart` / `planLength`) whenever a rule-based plan is generated (`planLength` 0 = AI plan → no
gap detection). For older plans the start is reconstructed from the generated workouts: the first workout of the latest
block (no hole > 3 weeks) or a point where the phases start over, accepted when the rebuilt plan reproduces ≥ 75 % of the
stored phases. The rebuild uses the current profile, so pace targets are current. A plan whose last generated workout is
> 14 days ago is over – nothing is filled.

**What is a gap.** Horizon: from tomorrow (today is the athlete's call, past days are never refilled) to the end of the 4th
week after the current one, never past the event day. Per week and sport the rebuilt sessions are counted against the
calendar's workouts of **every** status: a skipped session is a decision, not a gap; a session moved to another day of the
week still counts. If the calendar has fewer, the missing ones are the rebuilt sessions on a day without a workout of that
sport – preferring the roles the week lacks (long / quality / easy). Rest days, recovery weeks with fewer sessions, the race
week after the race and the days before a mid-week plan start have no rebuilt session, so they are never "missing". Weeks
that only hold the athlete's own (non-generated) workouts are left alone.

**Plan ended.** A plan without a race that ends before the horizon (no event) or before the event is continued with the
generator from the Monday after its last week (blocks of the athlete's plan length; with an event the generator builds the
phases and taper towards it). The continuation starts at the plan's last loading volume (largest loading week of its last 4
weeks, longest run) instead of the setup values – no drop back, no jump.

**Adapted like the rest of the plan.** Refills go through the same rules as the planned workouts of the same days: load
factors of days 1–7 / 8–14 (later refills keep the plan's volume), R4 return, quality → easy under fatigue / re-entry, the new
VDOT / FTP / CSS targets and the **R1 cap** for long sessions (every planned long session before it counts as done). Spacing:
a refilled hard session (key, tempo, intervals, long) next to a hard day becomes an easy session (~80 % of its time); next
to a race it is left out. **Volume:** a refilled week never exceeds the rebuilt week (minutes per sport, minus the
calendar's not-skipped workouts); a refill that does not fit is shortened, below 20 min left out ("not refilled" reason).
Applying writes the refills as new planned workouts with the rebuilt phase, so a second run proposes nothing (idempotent).

**Limits.** Matching is by count per sport and week: a session moved into another week leaves a "gap" in its own week (shown
as a proposal, can be unticked); a session deleted on a day that now holds a moved workout of that sport is not detected.
After a profile change (training days, focus) without a new plan, the rebuilt week follows the new profile.

### 11.2 Coherence of the adaptation layer (review 2026-11, `test/adaptation_sim_test.dart`) [P]

An independent review ran 12 day-by-day simulations (the athlete accepts every "Plan überprüfen" each Monday, the
AutoAdjuster runs after every session) and found that the adaptation layer contradicted the generator. The scenarios are now a
committed test (`test/adaptation_sim_test.dart`, `STRIVE_SIM_OUT=<dir>` writes a log per scenario) with these invariants:

| Invariant | Rule that guarantees it |
|---|---|
| An athlete who trains exactly to plan hears nothing negative: no rpeHigh / longCap / cuts / auto reductions, forecast on track every week (marathon, 10 km, run/walk HM beginner) | forecast dead band + ≥ 3 quality runs + 2-week persistence (§1.12); R1 cap with the generator's reference (§11); easy / long runs at the plan's own duration / distance are on pace (§12.1) |
| Long runs falling short or missed are noticed and never contradicted: no "ahead" with longRunBehind, ≥ slightly behind, HM / M at risk with ≤ 10 weeks left; no ratchet below the AutoAdjuster's cap | §1.12 floors; `_longCapped` |
| Missed long runs (rest done ≥ 90 %): the easy runs keep their volume; the next long run moves to a training day of its week with more time (swap with an easy run, not next to a hard day) – reason `moveLong` | I14 |
| The race goal is re-checked on the actual training: `PlanGenerator.feasibility` from today with the longest run of 30 days and the weekly volume of 3 weeks (≥ 80 % of the stated one); a new timing issue (too short / long day / run/walk) → reason `goalAtRisk` with the options (`Recalibration.feasibility`). Only after evidence: ≥ 2 long runs of 3 weeks missed / short, a break, < 50 % done, or a run/walk stage held twice | C3 |
| Fatigue doesn't remove quality for months: week 1 as rule 1; the too-hard score ≥ 2 on two consecutive Mondays (and still ≥ 1 in the last 7 days) → **one recovery week** (days 1–7 ≈ 70 %, no intensity; days 8–14 quality back at ~75 % of its repeats); still too hard after it → quality stays at ~75 % with "check sleep, illness, stress – consider a slower target" (`fatigueCheck`), another recovery week at the earliest 3 weeks later. Before: quality → easy for 7–11 weeks in a row | Meeusen 2013 [67] (overreaching: reduce load, then resume; persistent → look for causes) |
| Floors: no reduction takes a run below 25 min and 4 km (beginners / run/walk 20 min); a planned session already below stays as it is | C4 / I15 – 15-minute returns and 2.7 km "easy runs" are no training stimulus |
| VDOT moves in Daniels-sized steps: training-derived steps ≥ 21 days apart, total rise ≤ 1.6 × `GoalModel.gain` of the weeks since the plan start; stored as `athlete.vdotEstimate` (+ date, + the race-time VDOT it was derived from – new race times entered by the athlete win); race times written by older versions for a VDOT step (the exact time of a one-decimal VDOT at the event distance, next to another race time) are migrated | Daniels [7] ~1 point / 4–6 weeks; before: 40.4 → 48.4 in 8 weeks with a synthetic 3:15 marathon in the profile |
| Run/walk: ≥ 2 run/walk sessions of 3 weeks at RPE > 5 or < 80 % → the coming run/walk sessions repeat the stage of a week earlier (`repeatStage`); trimmed sessions change by whole repeats / minutes and their "N × M min" title follows | §1.10 Couch-to-5K: progress only at RPE ≤ 5 |
| Run/walk beginners get no finish-time prediction | §1.12 finish-only |

Measured (`STRIVE_SIM_OUT`), before → after: 10 km perfect athlete "at risk / slower than planned" W4–W9 → on track every
week; marathon perfect athlete ahead / at risk flips → on track; beginner HM perfect athlete longCap 16 of 17 Mondays (long run
15.5 → 10.0 km) → 0, long runs as generated (15.5 km); fatigue: quality → easy 7 (highRpe) / 11 (slower) consecutive weeks →
≤ 2; marathon VDOT 40.4 → 48.4 in 8 weeks → 40.4 → 43.5 in 11 weeks (steps W3, W6, W9, W12), race times unchanged; eight
skipped long runs "on track" until W12 → slightly behind from W6, at risk from W8, goalAtRisk.

### 11.3 Generator rules from the same review (`test/plan_review_run_test.dart`, `test/plan_review_multi_test.dart`) [P]

Running plans:
- **Duration = steps.** Run durations are whole minutes equal to the step estimate (± 0.5 min) and easy / long runs imply a
  pace inside E – the adaptation layer compares sessions against these numbers (§11.2), so a rounded "20' / 3.5 km" (5:43/km
  for an E zone of 5:48–6:41) made "too fast" fire on an athlete who ran the plan.
- **Day budget**: no day exceeds its minutes (strides and walk breaks included).
- **Long-run share** (weeks with ≥ 3 runs; 2-run weeks keep the volume curve's 55 %): ≤ 50 % of the actual week's run
  volume (marathon 55 %) and ≤ 2 × the next-longest run (weeks with ≤ 4 runs, not marathon / ultra); easy runs grow first. Feasibility issues `longRunShare` (the other runs
  need ≥ X min) and `longDayDefault` (the event's long-day default exceeds the time the athlete set: "long day needs ≥ X").
  Trade-off: a 3 × 60 min half-marathon beginner peaks at ~12 km instead of 15.5 km and sees the warning.
- **Weekly ceiling includes the long run** (1.5 × stated, level ceiling); event volume grows evenly to the peak instead of
  reaching the ceiling in week 6. With a 52.5 km ceiling and a 28 km long run, marathon easy runs may drop to 5 km.
- **Marathon peak**: one marathon-pace element a week (long run with MP finish, alternating with an MP run + ~80 % plain long
  run) – ≤ 2 quality sessions besides the long run, the longest long run not three weeks in a row.
- **Conservative target** (> 5 % slower than realistic): issue `targetConservative`; race-pace training uses the faster of
  target and realistic (race day keeps the athlete's target).
- **Quality progresses** (1000 → 1200 m reps, cruise 1.6 → 2.4 → 3.2 km, beginner fartlek grows); the first two weeks after
  run/walk use threshold pick-ups, not VO2max fartlek.
- **Recovery weeks** ≤ 75 % of the last loading week, the first right after the run/walk ladder.
- **Race day**: one source for the race time (target, else `suggestTargetTime`); race step zone I (5 km), T (10 km / HM), M
  (marathon); finish-only run/walk races (`PlanGenerator.finishOnly`, VDOT ≤ 28) carry no pace; triathlon / duathlon races
  are one session stored as a ride with swim / bike / run leg steps that add up to the predicted time. Run/walk athletes get
  a run/walk shake-out; former run/walkers 15' easy without strides.
- Minor: interval blocks ≥ 10 min in 5-min steps; goal-pace HR from the pace zone's HR zone; "continuous run 30 min" title;
  a quick-setup beginner's 4th day returns after run/walk.

Multisport, cycling, swimming, ultra, hybrid, strength:
- **Swim novices (triathlon)**: ≥ 2 swims a week (a double day if needed), continuous-swim target from the race's swim leg
  (sprint 750 m, olympic 1200, 70.3 1900, Ironman 3000, + ≤ 200 m a week); build / peak triathlon swims carry sighting cues
  and an open-water / wetsuit note (§4.4).
- **Bricks** at the run leg's race pace (stand-alone pace × `GoalModel.runOffBikeFactor`: Ironman × 1.25, 70.3 × 1.12) and
  ≤ 30' when a long run follows the next day.
- **Progressions**: threshold rides 3 × 10 → 2 × 25 min at 91–100 % FTP (not 2 × 30 at 95–105 % for weeks); long rides with
  race-power blocks (70.3 / Ironman / 160 km); swim3800 long swims rotate plain / race-pace finish / over-distance; duathlon
  run quality tempo → 1 km / 1.5 km reps → 800 / 600 m; duathlon bike quality every week; no duplicate quality session in a
  week (sweet spot + tempo ride).
- **70.3** with a 4 h Saturday: long run + easy ride there, ≥ 3 rides a week when days allow.
- **Ultra**: ≤ 3 key sessions (long + back-to-back + one quality run alternating hill repeats and cruise intervals).
- **Hybrid**: full-body A / B alternate as the session before the long run (legs halved), so neither is halved every week;
  time left in the gym slot fills with upper-body / core sets.
- **Beginner strength**: weeks 1–6 use regressions (lat pulldown, dumbbell RDL, reverse crunch), full lifts from week 7; no
  "next deload week" text without a deload.
- **Masters** (≥ 50) and women ≥ 45 without strength days: a strength tip on one easy session per loading week (§2.9, §9.2).

### 11.6 Fitness-model recalibration (review round 2, `test/fitness_model_recal_test.dart`) [P]

- **Progression against the plan's ladder** (`progressionCheck`): long sessions are measured against the original amount kept
  in the `AutoAdjustment` record, not the already-reduced session – a long run cut 10 → 7 km and done at 7 km is 70 % of the
  ladder, not 100 % (repeated reductions no longer hide a lag). A recovery week the recalibration proposed counts as planned.
  New issue `stageHeld`: a run/walk stage repeated ('recalStage') or a long session planned ≥ 5 % below its original for
  ≥ 3 weeks in a row; with ≤ 12 weeks to race day `ProgressionCheck.atRisk` is set (C25K / Galloway: a ladder that stalls for
  3 weeks cannot catch up in the time left).
- **R1 floor**: the R1 long-run cap (≤ 1.1 × the longest of 30 days) never takes a long session below the run floor (20 min for
  beginners / run/walk, else 25 min and 4 km) – a 7 km long run of a beginner whose longest was 2 km is capped at 2.3 km /
  20 min instead of 2.2 km / 19 min.
- **Re-created plan** ("Plan neu aufsetzen", "align plan with goal"): `withReachedVolume` replaces the setup's weekly volume and
  longest run by what the done sessions of the last 4 weeks reached (highest loading week, longest run; recovery / taper
  weeks don't count; unchanged without ≥ 2 weeks of plan history). Marathon re-created in week 9: 35 / 16 km →
  47.6 / 18.5 km, first week 36.9 → 48.4 km, next long runs 17.5 / 19.5 / 21.5 → 20.5 / 22.5 / 25 km (same as the old plan).
- **Taper** (Mujika & Padilla 2003, Bosquet 2007: volume −40–60 %, intensity kept): in a taper / race week the plan's reduced
  volume is not cut further for fatigue or missed sessions, never raised, and no recovery week is proposed; instead of
  rpeHigh / lowCompletion / rpeLow one message "Taper: weniger ist mehr" (`RecalReason.taper`), and a warning
  (`taperOverdo`) when the taper workouts of the last 7 days were done at > 110 % of the plan (scenario: 130 %).
- **FTP / CSS steps like the VDOT's**: training-derived FTP +3 % and CSS −2 s steps at most every 21 days (as
  `minVdotStepDays`), the rise since the plan's first step capped – FTP ≤ +8 % (beginners +10 %; Allen & Coggan: trained
  cyclists gain ~5–10 % FTP over a season's build), CSS ≤ 4 % faster. No step up during a return after a break or with < 50 %
  of the training done. Scenario: 220 → 287 W in 12 weeks before, now 220 → 227 → 234 → 237 W.
- **"A little more volume"** (rule 4, +5 %): never in consecutive weeks, at most 3 × per plan, and only said when a workout is
  actually raised (not ahead of a recovery week); otherwise `rpeLowSpaced` (quality that keeps feeling easy is a threshold
  question, rules 7–9).
- **Partial adherence** (key sessions done, completion < 70 %): only the slots (sport + weekday) the athlete skipped ≥ 2 × in
  the look-back come down; the easy runs the athlete still does keep their volume (scenario: Saturday easy run 50' stays,
  the skipped Monday / Wednesday / Friday runs 50 → 45').

---

## 12. Session feedback and progressive adaptation of endurance plans (run, bike, swim) [M/P]

Two speeds of adaptation ("auto small + preview large"):

* **Automatic, small** – right after a completed endurance session is linked to its planned workout (phone recording,
  manual entry, watch import), the next 1–2 planned sessions of the *same sport* may change by a few percent
  (`AutoAdjuster`, lib/services/cardio_progression.dart). The athlete sees a notice ("Plan adjusted: long run Sun 6.8 km
  instead of 8 km – Undo") and a marker with the reason and the original values on the planned workout; undo restores the
  generator's workout.
* **Proposal, large** – weekly volume, quality → easy swaps and threshold changes (VDOT, FTP, CSS) stay in "Re-plan &
  recalibrate" (§11), which now also reads the session evaluations and the multi-week trends below.

### 12.1 Evaluating one session (`evaluateSession`, lib/services/session_feedback.dart)

Every available signal gives a score from −1 (much easier than intended) to +1 (much harder) and a weight; the verdict is
the weighted mean (≥ +0.35 harder, ≤ −0.35 easier). Confidence = W / (W + 1) × (0.5 + 0.5 × share of the weight that agrees),
W = total weight – one signal ≈ 0.5, three agreeing signals ≈ 0.75. Signals that are missing are simply left out, so the
model works with RPE only, HR only, pace only or any mix.

| Signal | Rule | Weight | Basis |
|---|---|---|---|
| Session RPE (CR10) | intended band: easy/technique 2–4, long 3–4, tempo 5–7, intervals 7–8; ±0.4 per point outside | 1 (0.3 when imported with an HR-estimated RPE) | session-RPE, Foster 2001 [43, 66]; three-zone model §0 |
| Average HR | vs. the time-weighted HR target of the steps (step HR targets, else the zone's mid; recoveries at the zone top); dead band ±3 % HRmax, full score at +8 % HRmax; on easy days a low HR is not "too easy" (capped at −0.3). **Predicted HRmax** (no measured max HR in the profile): a deviation within the dead band + 10 bpm (the SEE of Tanaka / Gulati) counts with half weight, and on easy / long days it only says "harder" together with a second independent signal (RPE asked after the session, pace, pace fade – not an HR-estimated RPE) | 1 · intervals 0.5 (HR lag) · swim 0.3 (water, wrist HR); × ½ as described | Seiler zones [1], §5; Tanaka 2001 [55] |
| Average pace (run: VDOT paces, swim: CSS paces incl. rests) | tolerance run 3 %, swim 4 %; easy / long: only *faster* than the easy range counts (too hard), slower is fine; quality: slower = could not hold the targets (harder), faster = targets too soft (easier, ×0.7) | 1 · intervals 0.4 (recovery jogs dilute the average) · run with > 15 m/km climbing ½, > 30 m/km 0 | Daniels [7], Wakayoshi / Swim Smooth [53, 54] |
| Average power (bike) | vs. the time-weighted Coggan targets, tolerance 5 %; same easy / quality logic as pace | 1 · intervals 0.7 | Allen & Coggan [48] |
| Pace fade (run, continuous sessions, ≥ 4 km splits) | 2nd half vs. 1st half; > 5 % slower = decoupling (0.5 → 1 at 10 %) | 0.5 | aerobic decoupling Pa:HR < 5 % = aerobically fit (Friel [49]); cardiac drift [79]. Without an HR stream, the pace drift at a steady effort is the proxy |
| Completion | actual / planned (distance for runs / swims, else time); < 80 % = *incomplete* | – (separate) | §11 "cut short" |

HRmax used for the HR signals (`HrMax.of`): measured (profile) > observed – the highest max HR of a hard session (RPE ≥ 7 or
average HR ≥ 85 % of the prediction) of the last year when it is above the prediction, only ever upwards, spikes > prediction
+ 25 bpm ignored as sensor artefacts – > predicted. An observed peak is a lower bound of the true HRmax, so HR keeps the reduced
weight. Example: a treadmill easy run at +9 bpm with HR only was "harder" (next easy run −10 %); now it is as intended
unless the athlete also rates it hard.

Bike *speed* is ignored (terrain, wind, drafting); heat is not modelled (no temperature per session) – it shows up as a
higher HR / RPE and the athlete sees the reason. Aerobic efficiency (EF) of steady easy / long sessions: run speed (m/min)
per beat, bike power per beat (Coggan's EF = NP / HR, with average power).

### 12.2 Automatic small adjustments (`AutoAdjuster`)

| After … | Next session(s) of the same sport | Rationale |
|---|---|---|
| long session cut short (< 80 %) at a high or unknown effort | next long one ≤ achieved + 10 %, the one after ≤ + 20 % (never above the plan) | rebuild by ~10 %/week from what was sustainable (10 % rule [9, 10], R1 Frandsen [11]) |
| long session complete but harder than intended | next long one does not grow (held at this volume, ≥ −10 %) | "repeat the step" instead of progressing on fatigue (§7.9, [67]) |
| easy session harder than intended (HR / RPE / pace too fast) | next easy session within 7 days −10 %, with the hint to slow down | 80/20: easy days must stay easy (Seiler [1]); Maffetone [78] |
| quality session harder than intended, or cut short at a high effort | next quality session not increased (held at this volume) | keep intensity, don't add volume on top of a struggle (Bosquet [18]) |
| quality session easier than intended, complete, targets hit | next quality session +5 % | only in loading weeks (base / build / peak), no race within 10 days, no heart / joint-impact limitation (§9.1), and the sport's planned week ≤ 110 % of its 4-week average (≥ 3 sessions as a base) – acute:chronic caution [13, 14] |

Bounds: −15 … +5 % per step; all automatic steps together −15 … +10 % of the workout's original volume (also after a
recalibration – its record keeps the generator's original; a workout it already cut by more than 15 % is not cut further,
and a bound never turns a cut into an increase); taper / recovery weeks never get more volume. Interval sets (≥ 3 identical repeats) change by whole repeats (a 100 m swim repeat or a 1 km
interval keeps its length and pace); continuous parts scale in length. Never touched: races, strength sessions, done /
skipped / past workouts. Each session triggers adjustments at most once (the record on the changed workout names the
session); a manual edit or a recalibration with a new volume replaces the record.

### 12.3 Multi-session trend → recalibration proposals (`CardioTrend`, last 6 weeks)

* **Sessions without RPE** count toward the §11 "too hard" score when the evaluation is clearly harder (score ≥ 0.6 → 1,
  else ½) and toward "too easy" for quality sessions – so watch imports with HR also adapt the plan.
* **Only current targets count** for the VDOT / FTP / CSS trend: sessions whose work targets were set for another
  threshold (before the last update) are left out – otherwise the same old sessions raised the VDOT again every week
  (simulated: true VDOT 42.5 on a VDOT 40 plan → 41, 42, … 45, then back down; now 41 and holding).
* **Run VDOT** (only when no best effort changed it): ≥ 3 key runs (tempo / intervals / long) slower than the targets with an
  internal score ≥ 0.3 → VDOT −1; ≥ 3 quality runs on target that felt easier than intended, none too hard, EF not falling →
  VDOT +1; also ≥ 3 quality runs with T / I targets ≥ 3 % faster than planned at the intended effort (not harder), none too
  hard, EF not falling → VDOT +1 (coach review 3, B10 – the forecast already called that "ahead"; only sessions run against the
  current VDOT's targets count, so the same sessions never lift it twice). Daniels [7]: adjust VDOT in steps of about one
  point after a few weeks of training at it.
* **Bike FTP** (only with a known FTP): ≥ 2 quality rides above the power targets without feeling harder, none too hard →
  FTP +3 %; ≥ 2 key rides below target at a high effort → FTP −3 %. Power targets of the upcoming rides follow (Coggan
  zones [48]); the profile's FTP is updated on "Apply".
* **Swim CSS**: ≥ 3 quality swims faster than the targets at a comfortable effort, none too hard → CSS −2 s / 100 m; ≥ 2 key
  swims slower at a high effort → CSS +2 s. The profile's 400 / 200 m test times are set so that (t400 − t200) / 2 is the new
  CSS (t200 = 2·CSS − 4 s, t400 = 4·CSS − 4 s).
* **Aerobic efficiency**: robust change of EF over the window – Theil–Sen slope (median of pairwise slopes) × span relative
  to the median EF, ≥ 6 steady easy / long sessions over ≥ 14 days, and only when the points move consistently in one
  direction (Kendall |τ| ≥ 0.45; otherwise 0 – day-to-day pace / HR noise of ~3 % and single hot days are no trend);
  ±3 % or more is reported ("your base is growing" / "watch recovery, sleep and heat") – informational, no changes by itself.

## 13. Day-of readiness: "Not feeling 100 %?" (`ReadinessAdvisor`, lib/services/readiness.dart) [P]

On a planned endurance or strength workout from today on (not a race) the athlete can say how they feel. The app proposes
a change with a preview; nothing is saved until "Apply", and the change is logged in the plan history (source
`readiness`) with undo.

| Choice | Change | Rationale |
|---|---|---|
| **Sick** | the workout is skipped; hard endurance sessions of the next two days become easy (`Recalibrator.toEasy`, ~80 % of the time). Hints: above-the-neck rule, and after ≥ 10 days off "Plan überprüfen" applies the return rule (R4: 50–70 % of the previous volume) | "Neck check": symptoms only above the neck (runny nose, mild sore throat) and no fever → rest or at most short and easy; fever, aching muscles, chest or stomach symptoms → no training (Eichner 1993 [83]; Primos 1996 [84]). Detraining after short breaks is small (Mujika & Padilla [68]), so skipping costs little |
| **Pain** | run → easy ride (or swim) of ~80 % of the time when the athlete does that sport; otherwise easy and ≤ 30 min. Strength: about ⅓ fewer sets, same loads. Hints: pain-monitoring rule, see a doctor if it persists | low-impact cross-training keeps aerobic fitness without the impact load of running (Keller 1996 [61]); pain ≤ 3/10 that settles by the next morning is acceptable (Silbernagel 2007 [62], §9.1) |
| **Tired** | key / hard session (tempo, intervals, long) → easy session of the same sport, ~20 % shorter; an easy session −25 %. Strength: ⅓ fewer sets, loads unchanged, 2–3 RIR | quality on a fatigued body adds strain rather than adaptation – keep easy days easy (Seiler [1]; Meeusen [67]); in strength, cutting volume while keeping load maintains adaptations (minimum effective dose, Androulakis-Korakakis [77]; deload practice §2.7) |
| **Short on time** | endurance: shortened to the available minutes – warm-up and cool-down kept (shortened in proportion, ≥ 5 min), interval sets lose whole repeats first (each repeat keeps length and pace), continuous parts scale. Strength: one work set at a time from the exercise with the most sets (accessories first), then accessories dropped; the first (main) exercise always stays | keep intensity, cut volume (Bosquet [18]); a few hard sets keep most of the strength / hypertrophy stimulus (Iversen 2021 [23]) |

---

## 14. Race distances: requirements per event (fix/plan-pro, `EventSpec`, lib/services/event_spec.dart) [P/M]

One table drives plan length, phases, taper, long-session targets and caps, volume ceilings and the feasibility check.
The distances themselves are the shared catalogue (lib/core/event_distances.dart). Targets = what the long session must
reach before the taper (the feasibility check warns otherwise); km **or** the time at the long-run pace, whichever is
shorter (slow runners are on their feet long enough sooner).

| Event | Weeks (int/adv · beg) | Taper | Long run target · cap | Long ride target · cap | Long swim | Ceilings run km / bike h / swim km (N/I/A) | Brick | Notes |
|---|---|---|---|---|---|---|---|---|
| 5 km | 8–12 · 9–10 | 1 | – · 16 km | | | 15/30/50 | | run/walk finish |
| 10 km | 8–12 | 1 | 8 km · 18 | | | 25/40/60 | | |
| HM | 12–16 · 12–14 | 2 | 15 km · 21 km / 150 min | | | 30/50/70 | | |
| Marathon | 16–18 · 18–20 | 3 (beg 2) | 28 km · 35 km / 180 min | | | 45/65/90 | | not for beginners |
| Ultra 50 km | 16–24 | 3 | 30 km or 3 h 30 · 38 km / 4 h | | | 55/75/100 | | back-to-back, hills, fuelling; not for beginners |
| Sprint tri | 8–12 | 1 | – · 12 | 60 min · 2 h | (400 m) | 12/20/30 · 2.5/3.5/4.5 · 3/5/7 | 10→20 | |
| Olympic | 12–16 | 2 | 10 km or 75 min · 16 | 90 min · 2.5 h | (800 m) | 18/28/40 · 3.5/4.5/6 · 4/6/8 | 10→30 | |
| 70.3 | 16–20 · 20–24 | 2 | 16 km or 110 min · 21 | 3 h · 4 h | (800 m) | 25/35/50 · 5/6.5/8 · 5/7/9 | 10→45 (60) | race-pace bike tempo in the peak |
| Ironman | 24–30 | 3 | 26 km or 150 min · 30 km / 165 min | 5 h · 6 h | (1000 m) | 35/45/60 · 8/10/13 · 6/8/10 | 10→45 (60) | not for beginners; 30-week specific block |
| Duathlon sprint (5/20/2.5) | 8–12 | 1 | 7 km or 50 min · 14 | 60 min · 2 h | | 20/30/45 · 2.5/3.5/4.5 | 10→20 | run–bike–run in the peak |
| Duathlon standard (10/40/5) | 10–14 | 2 | 12 km or 80 min · 18 | 90 min · 2.5 h | | 25/40/55 · 3.5/4.5/6 | 10→30 | run–bike–run in the peak |
| 100 km ride | 8–12 · 10–14 | 1 | | 3 h · 4 h 30 | | – · 5/7/9 | | climbing repeats (build), race tempo (peak) |
| 160 km ride | 12–16 | 2 | | 4 h · 5 h 30 | | – · 6/8/11 | | as 100 km |
| Open water 1.5 km | 8–12 | 1 | | | 1.5 km | swim 5/8/12 | | sighting, open-water notes |
| Open water 3.8 km | 12–16 | 2 | | | 3 km | swim 8/12/18 | | |
| Open water 5 km | 12–20 | 2 | | | 4 km | swim 10/15/22 | | not for beginners |

Rules by discipline (sources in brackets):

```text
taper        : 3 weeks for marathon / ultra / Ironman (Wang 2023 [19]: ~21 days with −41–60 % for long endurance events;
               Bosquet 2007 [18]); 2 weeks HM / olympic / 70.3 / standard duathlon / 160 km / long swims; 1 week short races
specific     : plans longer than max(20, recommended max weeks) start with a base pre-plan (Ironman 30, ultra 24 weeks)
long run     : per loading week ≤ +10 % of the 30-day longest run (R1, Frandsen 2025 [11]); share of the week: ultra like the
               marathon (≤ 50 %, 32 km / week km), multisport ≤ 45 % (≥ 3 runs) / ≤ 65 % (2 runs: long + quality)
ultra        : back-to-back (build / peak, ≥ 4 runs, non-beginners): the day after the long run an easy medium-long run of
               55 % (peak 60 %) of it, with the second long day's time (≥ 2 h); long runs in build / peak carry a hills /
               power-hiking note; peak quality = threshold, no VO2max reps (Koop 2016 [85]; Roche)
Ironman      : long run ≤ 30 km / 2 h 45 (marathon off the bike: recovery cost of longer runs exceeds their benefit –
               Friel [86]; Fitzgerald 80/20 Triathlon [87]); long ride up to 6 h; bike peak tempo 2 × 30 → 2 × 40 → 3 × 30 min
               at 75–85 % FTP; one quality ride in the peak is race tempo, a second stays VO2max / threshold
cycling      : long ride share ≤ 60 % of the bike hours when the target needs it; build: every other week the sweet-spot
               ride as climbing repeats (seated, 60–70 rpm, 10-min blocks); peak: race-specific tempo (as 70.3)
open water   : weekly long continuous swim (§4.3), sighting in build / peak, shake-out swim the day before the race
fuelling     : races ≥ 2.5 h: long runs ≥ 90 min and long rides ≥ 2 h carry "practise race fuelling: 60–90 g
               carbohydrate / h, 400–800 ml / h" (Jeukendrup 2014 [88]; Thomas et al. ACSM 2016 [89]); race-day note
race day     : triathlon stored as a swim, duathlon as a run (legs in the description), cycling as a ride, open water as a
               swim, ultra as a 50 km run; shake-out the day before (ride: 20–30 min with 3 short pick-ups; swim: short
               with 50s and sighting); expected duration from GoalModel.predict
forecast     : target-time check / forecast for 5 km – marathon (VDOT) and multisport with data (race time, FTP or swim
               test; Ironman: bike 70 % FTP, run × 1.25 off the bike, 10 min transitions; duathlon: run 1 × 1.02, bike
               82–86 % FTP, run 2 × 1.08–1.10). Ultra, cycling and open water are finish-oriented (terrain, weather and
               pacing dominate; the improvement model is a VDOT model) – the race still gets a realistic duration
```

**Invariant matrix** (test/plan_matrix_test.dart, 207 plans: 16 distances × 3 levels × 3 time budgets, rotating days
3–6, health limits, near / far race date, target realistic / unrealistic, swim / run ability, FTP, difficulty, age;
plus 7 focuses without an event). Checked: race on race day as the right sport · loading weeks ≤ +12 % (+2 km run /
+30 min ride / +1 km swim / +30 min total) over the higher of the two previous loading weeks (plans ≥ 8 weeks) · ≤ 5
loading weeks in a row, no recovery week right before the taper · taper length and cut (week before race ≤ 80 %, race
week ≤ 60 % of the last loading week, weeks ≥ 150 min) · long session target reached or the feasibility card warns ·
long sessions not flat > 2 loading weeks unless at cap / target / volume ceiling, the last long session before the taper
≥ 90 % of the longest, the longest long run 2–4 weeks before race day · day time caps · time in zone per loading week:
high (> LT2) ≤ 25 %, high + threshold ≤ 40 %, whole plan high ≤ 20 % (Seiler 2010 [1]; Stöggl & Sperlich 2014 [90]) · no
3 key days in a row, beginners / masters no 2 hard days of one sport in a row · swim novices / run/walk / health limits ·
titles "N × M" match the steps · sane values. Before this branch: 740 violations; after: 0 (6 hand-reviewed edge cases
are listed in the test as accepted residuals).

## 10. References

Downloaded PDFs in `docs/papers/` are marked **(PDF)**.

1. Seiler S. What is best practice for training intensity and duration distribution in endurance athletes? *Int J Sports Physiol Perform.* 2010;5(3):276–291. doi:10.1123/ijspp.5.3.276
2. Seiler KS, Kjerland GØ. Quantifying training intensity distribution in elite endurance athletes: is there evidence for an "optimal" distribution? *Scand J Med Sci Sports.* 2006;16(1):49–56. doi:10.1111/j.1600-0838.2004.00418.x
3. Stöggl T, Sperlich B. Polarized training has greater impact on key endurance variables than threshold, high intensity, or high volume training. *Front Physiol.* 2014;5:33. doi:10.3389/fphys.2014.00033 **(PDF: Stoggl2014_polarized_training_key_endurance_variables.pdf)**
4. Stöggl TL, Sperlich B. The training intensity distribution among well-trained and elite endurance athletes. *Front Physiol.* 2015;6:295. doi:10.3389/fphys.2015.00295 **(PDF: Stoggl2015_training_intensity_distribution_elite.pdf)**
5. Silva Oliveira P, Boppre G, Fonseca H. Comparison of polarized versus other types of endurance training intensity distribution on athletes' endurance performance: a systematic review with meta-analysis. *Sports Med.* 2024;54(8):2071–2095. doi:10.1007/s40279-024-02034-z **(PDF: SilvaOliveira2024_polarized_vs_other_TID_meta.pdf)**
7. Daniels J. *Daniels' Running Formula.* 4th ed. Human Kinetics; 2022 (VDOT equations from Daniels J, Gilbert J. *Oxygen Power: Performance Tables for Distance Runners.* 1979).
8. Riegel PS. Athletic records and human endurance. *American Scientist.* 1981;69(3):285–290.
9. Buist I, Bredeweg SW, van Mechelen W, et al. No effect of a graded training program on the number of running-related injuries in novice runners: a randomized controlled trial. *Am J Sports Med.* 2008;36(1):33–39. doi:10.1177/0363546507307505
10. Nielsen RØ, Parner ET, Nohr EA, et al. Excessive progression in weekly running distance and risk of running-related injuries: an association which varies according to type of injury. *J Orthop Sports Phys Ther.* 2014;44(10):739–747. doi:10.2519/jospt.2014.5164
11. Frandsen JSB, Hulme A, Parner ET, et al. How much running is too much? Identifying high-risk running sessions in a 5200-person cohort study. *Br J Sports Med.* 2025. doi:10.1136/bjsports-2024-109380 (open access; PMC12421110. Automated download was blocked)
12. Damsted C, Glad S, Nielsen RO, et al. Is there evidence for an association between changes in training load and running-related injuries? A systematic review. *Int J Sports Phys Ther.* 2018;13(6):931–942. doi:10.26603/ijspt20180931
13. Gabbett TJ. The training–injury prevention paradox: should athletes be training smarter and harder? *Br J Sports Med.* 2016;50(5):273–280. doi:10.1136/bjsports-2015-095788 **(PDF: Gabbett2016_training_injury_prevention_paradox.pdf)**
14. Impellizzeri FM, Tenan MS, Kempton T, et al. Acute:chronic workload ratio: conceptual issues and fundamental pitfalls. *Int J Sports Physiol Perform.* 2020;15(6):907–913. doi:10.1123/ijspp.2019-0864
15. Lolli L, Batterham AM, Hawkins R, et al. Mathematical coupling causes spurious correlation within the conventional acute-to-chronic workload ratio calculations. *Br J Sports Med.* 2019;53(15):921–922. doi:10.1136/bjsports-2017-098110
16. Williams S, West S, Cross MJ, Stokes KA. Better way to determine the acute:chronic workload ratio? *Br J Sports Med.* 2017;51(3):209–210. doi:10.1136/bjsports-2016-096589
17. Kenneally M, Casado A, Santos-Concejero J. The effect of periodization and training intensity distribution on middle- and long-distance running performance: a systematic review. *Int J Sports Physiol Perform.* 2018;13(9):1114–1121. doi:10.1123/ijspp.2017-0327
18. Bosquet L, Montpetit J, Arvisais D, Mujika I. Effects of tapering on performance: a meta-analysis. *Med Sci Sports Exerc.* 2007;39(8):1358–1365. doi:10.1249/mss.0b013e31806010e0
19. Wang Z, Wang YT, Gao W, Zhong Y. Effects of tapering on performance in endurance athletes: a systematic review and meta-analysis. *PLoS One.* 2023;18(5):e0282838. doi:10.1371/journal.pone.0282838 **(PDF: Wang2023_tapering_endurance_meta.pdf)**
20. Mujika I, Padilla S. Scientific bases for precompetition tapering strategies. *Med Sci Sports Exerc.* 2003;35(7):1182–1187. doi:10.1249/01.MSS.0000074448.73931.11
21. Schoenfeld BJ, Ogborn D, Krieger JW. Dose-response relationship between weekly resistance training volume and increases in muscle mass: a systematic review and meta-analysis. *J Sports Sci.* 2017;35(11):1073–1082. doi:10.1080/02640414.2016.1210197
22. Pelland JC, Remmert JF, Robinson ZP, et al. The resistance training dose response: meta-regressions exploring the effects of weekly volume and frequency on muscle hypertrophy and strength gains. *Sports Med.* 2026. doi:10.1007/s40279-025-02344-w (preprint: SportRxiv 2024)
23. Iversen VM, Norum M, Schoenfeld BJ, Fimland MS. No time to lift? Designing time-efficient training programs for strength and hypertrophy: a narrative review. *Sports Med.* 2021;51(10):2079–2095. doi:10.1007/s40279-021-01490-1 **(PDF: Iversen2021_time_efficient_strength_training.pdf)**
24. Schoenfeld BJ, Ogborn D, Krieger JW. Effects of resistance training frequency on measures of muscle hypertrophy: a systematic review and meta-analysis. *Sports Med.* 2016;46(11):1689–1697. doi:10.1007/s40279-016-0543-8
25. Schoenfeld BJ, Grgic J, Krieger J. How many times per week should a muscle be trained to maximize muscle hypertrophy? A systematic review and meta-analysis of studies examining the effects of resistance training frequency. *J Sports Sci.* 2019;37(11):1286–1295. doi:10.1080/02640414.2018.1555906
26. Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW. Strength and hypertrophy adaptations between low- vs. high-load resistance training: a systematic review and meta-analysis. *J Strength Cond Res.* 2017;31(12):3508–3523. doi:10.1519/JSC.0000000000002200
27. Robinson ZP, Pelland JC, Remmert JF, et al. Exploring the dose–response relationship between estimated resistance training proximity to failure, strength gain, and muscle hypertrophy: a series of meta-regressions. *Sports Med.* 2024;54(9):2209–2231. doi:10.1007/s40279-024-02069-2
28. Refalo MC, Helms ER, Hamilton DL, Fyfe JJ. Influence of resistance training proximity-to-failure, determined by repetitions-in-reserve, on neuromuscular fatigue in resistance-trained males and females. *Sports Med Open.* 2023;9:10. doi:10.1186/s40798-023-00554-y **(PDF: Refalo2023_proximity_to_failure_RIR.pdf)**
29. Helms ER, Byrnes RK, Cooke DM, et al. RPE vs. percentage 1RM loading in periodized programs matched for sets and repetitions. *Front Physiol.* 2018;9:247. doi:10.3389/fphys.2018.00247 **(PDF: Helms2018_RPE_vs_percent1RM.pdf)**
30. Zourdos MC, Klemp A, Dolan C, et al. Novel resistance training–specific rating of perceived exertion scale measuring repetitions in reserve. *J Strength Cond Res.* 2016;30(1):267–275. doi:10.1519/JSC.0000000000001049
31. Helms ER, Cronin J, Storey A, Zourdos MC. Application of the repetitions in reserve-based rating of perceived exertion scale for resistance training. *Strength Cond J.* 2016;38(4):42–49. doi:10.1519/SSC.0000000000000218
32. Rhea MR, Ball SD, Phillips WT, Burkett LN. A comparison of linear and daily undulating periodized programs with equated volume and intensity for strength. *J Strength Cond Res.* 2002;16(2):250–255.
33. Williams TD, Tolusso DV, Fedewa MV, Esco MR. Comparison of periodized and non-periodized resistance training on maximal strength: a meta-analysis. *Sports Med.* 2017;47(10):2083–2100. doi:10.1007/s40279-017-0734-y
34. Schoenfeld BJ, Pope ZK, Benik FM, et al. Longer interset rest periods enhance muscle strength and hypertrophy in resistance-trained men. *J Strength Cond Res.* 2016;30(7):1805–1812. doi:10.1519/JSC.0000000000001272
35. Singer A, Wolf M, Generoso L, et al. Give it a rest: a systematic review with Bayesian meta-analysis on the effect of inter-set rest interval duration on muscle hypertrophy. *Front Sports Act Living.* 2024;6:1429789. doi:10.3389/fspor.2024.1429789 **(PDF: Singer2024_rest_interval_hypertrophy_meta.pdf)**
36. Grgic J, Lazinica B, Mikulic P, et al. The effects of short versus long inter-set rest intervals in resistance training on measures of muscle hypertrophy: a systematic review. *Eur J Sport Sci.* 2017;17(8):983–993. doi:10.1080/17461391.2017.1340524
37. Zhang X, Weakley J, Li H, et al. Superset versus traditional resistance training prescriptions: a systematic review and meta-analysis exploring acute and chronic effects on mechanical, metabolic, and perceptual variables. *Sports Med.* 2025. doi:10.1007/s40279-025-02176-8 **(PDF: Zhang2025_superset_meta.pdf)**
38. Weakley JJS, Till K, Read DB, et al. The effects of traditional, superset, and tri-set resistance training structures on perceived intensity and physiological responses. *Eur J Appl Physiol.* 2017;117(9):1877–1889. doi:10.1007/s00421-017-3680-3 **(PDF: Weakley2017_superset_trisets_physiology.pdf)**
39. Sødal LK, Kristiansen E, Larsen S, van den Tillaar R. Effects of drop sets on skeletal muscle hypertrophy: a systematic review and meta-analysis. *Sports Med Open.* 2023;9:66. doi:10.1186/s40798-023-00620-5 **(PDF: Sodal2023_drop_sets_meta.pdf)**
40. Rogerson D, Nolan D, Korakakis PA, et al. Deloading practices in strength and physique sports: a cross-sectional survey. *Sports Med Open.* 2024;10:26. doi:10.1186/s40798-024-00691-y **(PDF: Rogerson2024_deloading_practices_survey.pdf)**
41. Wilson JM, Marin PJ, Rhea MR, et al. Concurrent training: a meta-analysis examining interference of aerobic and resistance exercises. *J Strength Cond Res.* 2012;26(8):2293–2307. doi:10.1519/JSC.0b013e31823a3e2d
42. Schumann M, Feuerbacher JF, Sünkeler M, et al. Compatibility of concurrent aerobic and strength training for skeletal muscle size and function: an updated systematic review and meta-analysis. *Sports Med.* 2022;52(3):601–612. doi:10.1007/s40279-021-01587-7 **(PDF: Schumann2022_concurrent_training_compatibility_meta.pdf)**
43. Foster C, Florhaug JA, Franklin J, et al. A new approach to monitoring exercise training. *J Strength Cond Res.* 2001;15(1):109–115.
44. NHS. Couch to 5K running plan. https://www.nhs.uk/live-well/exercise/running-and-aerobic-exercises/get-running-with-couch-to-5k/
45. Petré H, Hemmingsson E, Rosdahl H, Psilander N. Development of maximal dynamic strength during concurrent resistance and endurance training in untrained, moderately trained, and trained individuals: a systematic review and meta-analysis. *Sports Med.* 2021;51(5):991–1010. doi:10.1007/s40279-021-01426-9 **(PDF: Petre2021_concurrent_training_strength_meta.pdf)**
46. Murlasits Z, Kneffel Z, Thalib L. The physiological effects of concurrent strength and endurance training sequence: a systematic review and meta-analysis. *J Sports Sci.* 2018;36(11):1212–1219. doi:10.1080/02640414.2017.1364405
47. Eddens L, van Someren K, Howatson G. The role of intra-session exercise sequence in the interference effect: a systematic review with meta-analysis. *Sports Med.* 2018;48(1):177–188. doi:10.1007/s40279-017-0784-1
48. Allen H, Coggan AR, McGregor S. *Training and Racing with a Power Meter.* 3rd ed. VeloPress; 2019.
49. Friel J. *The Triathlete's Training Bible.* 4th ed. VeloPress; 2016. Zones: https://joefrielsblog.com/quick-guide-to-setting-zones/
50. Neal CM, Hunter AM, Brennan L, et al. Six weeks of a polarized training-intensity distribution leads to greater physiological and performance adaptations than a threshold model in trained cyclists. *J Appl Physiol.* 2013;114(4):461–471. doi:10.1152/japplphysiol.00652.2012
51. Rosenblat MA, Perrotta AS, Vicenzino B. Polarized vs. threshold training intensity distribution on endurance sport performance: a systematic review and meta-analysis of randomized controlled trials. *J Strength Cond Res.* 2019;33(12):3491–3500. doi:10.1519/JSC.0000000000002618
52. Banister EW, Calvert TW, Savage MV, Bach T. A systems model of training for athletic performance. *Aust J Sports Med.* 1975;7:57–61.
53. Wakayoshi K, Yoshida T, Udo M, et al. A simple method for determining critical speed as swimming fatigue threshold in competitive swimming. *Int J Sports Med.* 1992;13(5):367–371. doi:10.1055/s-2007-1021282
54. Swim Smooth. CSS test & training zones. https://www.swimsmooth.com/training/critical-swim-speed
55. Tanaka H, Monahan KD, Seals DR. Age-predicted maximal heart rate revisited. *J Am Coll Cardiol.* 2001;37(1):153–156. doi:10.1016/S0735-1097(00)01054-8
56. Karvonen MJ, Kentala E, Mustala O. The effects of training on heart rate; a longitudinal study. *Ann Med Exp Biol Fenn.* 1957;35(3):307–315.
57. Gellish RL, Goslin BR, Olson RE, et al. Longitudinal modeling of the relationship between age and maximal heart rate. *Med Sci Sports Exerc.* 2007;39(5):822–829. doi:10.1097/mss.0b013e31803349c6
58. Gulati M, Shaw LJ, Thisted RA, et al. Heart rate response to exercise stress testing in asymptomatic women: the St. James Women Take Heart Project. *Circulation.* 2010;122(2):130–137. doi:10.1161/CIRCULATIONAHA.109.939249
59. McNulty KL, Elliott-Sale KJ, Dolan E, et al. The effects of menstrual cycle phase on exercise performance in eumenorrheic women: a systematic review and meta-analysis. *Sports Med.* 2020;50(10):1813–1827. doi:10.1007/s40279-020-01319-3
60. Pescatello LS, MacDonald HV, Lamberti L, Johnson BT. Exercise for hypertension: a prescription update integrating existing recommendations with emerging research. *Curr Hypertens Rep.* 2015;17(11):87. doi:10.1007/s11906-015-0600-y — see also Pelliccia A, Sharma S, Gati S, et al. 2020 ESC Guidelines on sports cardiology and exercise in patients with cardiovascular disease. *Eur Heart J.* 2021;42(1):17–96. doi:10.1093/eurheartj/ehaa605
61. Keller TS, Weisberger AM, Ray JL, et al. Relationship between vertical ground reaction force and speed during walking, slow jogging, and running. *Clin Biomech.* 1996;11(5):253–259. doi:10.1016/0268-0033(95)00068-2
62. Silbernagel KG, Thomeé R, Eriksson BI, Karlsson J. Continued sports activity, using a pain-monitoring model, during rehabilitation in patients with Achilles tendinopathy: a randomized controlled study. *Am J Sports Med.* 2007;35(6):897–906. doi:10.1177/0363546506298279
63. Wanivenhaus F, Fox AJS, Chaudhury S, Rodeo SA. Epidemiology of injuries and prevention strategies in competitive swimmers. *Sports Health.* 2012;4(3):246–251. doi:10.1177/1941738111434406
64. Cappozzo A, Felici F, Figura F, Gazzani F. Lumbar spine loading during half-squat exercises. *Med Sci Sports Exerc.* 1985;17(5):613–620.
65. MacDougall JD, Tuxen D, Sale DG, et al. Arterial blood pressure response to heavy resistance exercise. *J Appl Physiol.* 1985;58(3):785–790. doi:10.1152/jappl.1985.58.3.785
66. Haddad M, Stylianides G, Djaoui L, Dellal A, Chamari K. Session-RPE method for training load monitoring: validity, ecological usefulness, and influencing factors. *Front Neurosci.* 2017;11:612. doi:10.3389/fnins.2017.00612
67. Meeusen R, Duclos M, Foster C, et al. Prevention, diagnosis, and treatment of the overtraining syndrome: joint consensus statement of the European College of Sport Science and the American College of Sports Medicine. *Med Sci Sports Exerc.* 2013;45(1):186–205. doi:10.1249/MSS.0b013e318279a10a
68. Mujika I, Padilla S. Detraining: loss of training-induced physiological and performance adaptations. Part I: short term insufficient training stimulus. *Sports Med.* 2000;30(2):79–87. doi:10.2165/00007256-200030020-00002
69. Plotkin D, Coleman M, Van Every D, et al. Progressive overload without progressing load? The effects of load or repetition progression on muscular adaptations. *PeerJ.* 2022;10:e14142. doi:10.7717/peerj.14142
70. Graham T, Cleather DJ. Autoregulation by "repetitions in reserve" leads to greater improvements in strength over a 12-week training program than fixed loading. *J Strength Cond Res.* 2021;35(9):2451–2456. doi:10.1519/JSC.0000000000003164
71. Halperin I, Malleron T, Har-Nir I, et al. Accuracy in predicting repetitions to task failure in resistance exercise: a scoping review and exploratory meta-analysis. *Sports Med.* 2022;52(2):377–390. doi:10.1007/s40279-021-01559-x
72. Steele J, Endres A, Fisher J, Gentil P, Giessing J. Ability to predict repetitions to momentary failure is not perfectly accurate, though improves with resistance training experience. *PeerJ.* 2017;5:e4105. doi:10.7717/peerj.4105
73. Willardson JM, Burkett LN. A comparison of 3 different rest intervals on the exercise volume completed during a workout. *J Strength Cond Res.* 2005;19(1):23–26.
74. Bell L, Strafford BW, Coleman M, Androulakis Korakakis P, Nolan D. Integrating deloading into strength and physique sports training programmes: an international Delphi consensus approach. *Sports Med Open.* 2023;9:87. doi:10.1186/s40798-023-00633-0
75. Sen PK. Estimates of the regression coefficient based on Kendall's tau. *J Am Stat Assoc.* 1968;63(324):1379–1389.
76. Winter DA. *Biomechanics and Motor Control of Human Movement.* 4th ed. Wiley; 2009 (body segment parameters).
77. Androulakis-Korakakis P, Fisher JP, Steele J. The minimum effective training dose required to increase 1RM strength in resistance-trained men: a systematic review and meta-analysis. *Sports Med.* 2020;50(4):751–765. doi:10.1007/s40279-019-01236-0
78. Maffetone P. *The Big Book of Endurance Training and Racing.* Skyhorse; 2010 (aerobic base, MAF heart rate, easy days kept easy).
79. Coyle EF, González-Alonso J. Cardiovascular drift during prolonged exercise: new perspectives. *Exerc Sport Sci Rev.* 2001;29(2):88–92. doi:10.1097/00003677-200104000-00009
80. Milanović Z, Sporiš G, Weston M. Effectiveness of high-intensity interval training (HIT) and continuous endurance training for VO2max improvements: a systematic review and meta-analysis of controlled trials. *Sports Med.* 2015;45(10):1469–1481. doi:10.1007/s40279-015-0365-0
81. Bacon AP, Carter RE, Ogle EA, Joyner MJ. VO2max trainability and high intensity interval training in humans: a meta-analysis. *PLoS One.* 2013;8(9):e73182. doi:10.1371/journal.pone.0073182
82. Bouchard C, An P, Rice T, et al. Familial aggregation of VO2max response to exercise training: results from the HERITAGE Family Study. *J Appl Physiol.* 1999;87(3):1003–1008. doi:10.1152/jappl.1999.87.3.1003
83. Eichner ER. Infection, immunity, and exercise: what to tell patients? *Phys Sportsmed.* 1993;21(1):125–135. doi:10.1080/00913847.1993.11710319 (the "above-the-neck" rule)
84. Primos WA Jr. Sports and exercise during acute illness: recommending the right course for patients. *Phys Sportsmed.* 1996;24(1):44–53. doi:10.3810/psm.1996.01.1195

85. Koop J. *Training Essentials for Ultrarunning.* Boulder: Pursuit Press; 2016 (back-to-back long runs, time on feet, vert-specific training). [P]
86. Friel J. *The Triathlete's Training Bible.* 4th ed. Boulder: VeloPress; 2016 (long-course long sessions, bricks, taper). [P]
87. Fitzgerald M, Warden D. *80/20 Triathlon.* Boston: Da Capo; 2018 (intensity distribution and long-session caps for Ironman). [P]
88. Jeukendrup A. A step towards personalized sports nutrition: carbohydrate intake during exercise. *Sports Med.* 2014;44(Suppl 1):S25–S33. doi:10.1007/s40279-014-0148-z [M]
89. Thomas DT, Erdman KA, Burke LM. American College of Sports Medicine joint position statement: nutrition and athletic performance. *Med Sci Sports Exerc.* 2016;48(3):543–568. doi:10.1249/MSS.0000000000000852 [S]
90. Stöggl T, Sperlich B. Polarized training has greater impact on key endurance variables than threshold, high intensity, or high volume training. *Front Physiol.* 2014;5:33. doi:10.3389/fphys.2014.00033 [M]
91. Galloway J. *Galloway's Book on Running.* 2nd ed. Bolinas: Shelter Publications; 2002 – and *Half Marathon: You Can Do It* (run-walk-run method, walk breaks from the start, long run/walks as time on feet).
92. Hottenrott K, Ludyga S, Schulze S, Gronwald T, Jäger FS. Does a run/walk strategy decrease cardiovascular stress and fatigue in running? *J Sci Med Sport.* 2016;19(1):64–68 (similar marathon times, less muscle pain and fatigue with run/walk).
93. Higdon H. Half Marathon Novice 1 / 10K Novice training programs (12 / 8 weeks; long run +1 mile a week to 10 mi / 6 mi). halhigdon.com.
94. Pfitzinger P, Latter P. *Faster Road Racing: 5K to Half Marathon.* Champaign: Human Kinetics; 2015 (long-run progression, cut-back weeks, taper).
95. American College of Sports Medicine; Garber CE et al. Quantity and quality of exercise for developing and maintaining cardiorespiratory, musculoskeletal, and neuromotor fitness. *Med Sci Sports Exerc.* 2011;43(7):1334–1359 (progress duration before intensity, gradual progression for the untrained).
96. NHS. Couch to 5K: week by week (9-week run/walk programme, 3 sessions a week). nhs.uk (see also [44]).
