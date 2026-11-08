# Strive – Competitor Feature Research

Research date: 2026-11-08. Scope: running, cycling, swimming and gym apps that lead the market, and what Strive (Flutter, Android first, Galaxy Watch 6 Classic, Health Connect, no paid third-party APIs) should copy.

Legend: **[MUST]** = must-have for v1, **[NICE]** = nice-to-have / later. Every feature has a one-line note on how it should behave or look.
"Verified" means a source below confirmed it. "Common pattern" means it is widely known app behaviour that the sources did not explicitly document. Treat those as design suggestions.

---

## 1. Running

### 1.1 What the leaders do

**Runna (owned by Strava since April 2025)**
- **Plan setup questions (verified):** running history and current ability (recent race time or typical 5K pace), goal race and distance, target time, race date, how many runs per week and which days are available. Plans range from "New to Running" or "Return to Running" to a faster marathon.
- **Weekly plan structure (verified):** easy runs, speed sessions (intervals), tempo, a long run and recovery runs. Strength and mobility sessions sit alongside the running but don't sync to the watch. Common pattern in Runna plans: fartlek, hill reps, progression runs and race-pace long runs.
- **Pace guidance (verified):** each run has a pace window, for example 5:20–5:35 /km, rather than vague "easy" or "moderate" labels. This is the feature reviewers praise most. Paces come from the entered race time and are recalibrated as sessions are completed. There is a predicted race time that updates over time.
- **Adaptation (verified):** sessions can be moved between days. A "Not feeling 100%" option covers illness or injury, and "Adapt for Heat" adjusts pace using the weather forecast. The plan adjusts as you complete it.
- **Criticism (verified):** intensity is often too high, and a February 2026 report linked a wave of injuries to pace progression and intensity distribution. **Lesson for Strive:** keep about 80% of running easy, increase weekly volume by no more than about 10%, and schedule deload weeks.
- **Audio cues on the phone (verified):** a visual countdown at the start, then "start running", pace alerts (speed up / slow down), pause and resume, a halfway update, "Lap N completed in 5:50 min/km" and a workout-complete cue with the total time.
  - Pace alerts aim for the middle of the target range.
  - During intervals and tempo runs, cues fire only at lap or step boundaries, not continuously.
  - Feedback distance is configurable for free runs only.
  - Runna deliberately uses synthetic TTS voices because they speak without delay.
- **Watch sync (verified):** Garmin, Apple Watch, COROS, Suunto and Amazfit. Samsung Galaxy Watch and Wear OS are **not supported**. That is a gap Strive can fill for its own user.

**Strava**
- **Record screen (2025 redesign, Android first, verified):** map and stats on one screen, so there's no switching views. Also simpler sport selection, Live Splits, upcoming Custom Laps (manual lap button), a better map engine and subscriber map layers (heatmap, 3D, POIs).
- **Live segments (verified):** real-time effort against your PR or the KOM/QOM on popular segments, with a comparison screen.
- **Routes (verified):** AI or community-heatmap-based route suggestions from your current location, point-to-point routing, Route Builder with live distance, elevation and surface, Off-Route Alerts and offline routes.
- **Social (verified):** kudos (including a "kudos bomb" for a whole group activity), comments, clubs with club challenges, a global and personal heatmap, and segments with leaderboards. **Common pattern:** Best Efforts (fastest 1K, 5K, 10K inside any run), Flyby (who you crossed paths with), Year in Sport recap, monthly challenges and badges.

**Samsung Health (running)**
- **Running Coach (Watch8 and later, Samsung Health 6.30.2+, verified):** a running-level test gives you a level, then a personalised programme. Samsung's newsroom cites 160 programmes.
- **Targets on the watch (verified):** pace target (preset or custom), and Interval (run time, rest time, repeats). Users complain that the forced warm-up and cool-down distorts pace, and that intervals can only be built on the watch, not the phone. **Opportunity:** build structured workouts on the phone in Strive.

**Nike Run Club**
- **Free (verified):** it's loved for **Audio Guided Runs**, coach-narrated runs such as "Easy 30 min" or "Speed run", plus training plans from 5K to marathon, badges, Cheers from friends and splits.
- **Weaknesses (verified):** audio sometimes drifts out of sync with time or distance, there's no route suggestion, and there are occasional recording glitches.

**Garmin Connect / Garmin watches**
- **Workout screen (verified):** shows the current step name, step notes, the target (pace range or HR zone) and the step's data (step distance remaining, average step pace).
- **Alerts (verified):** an alert fires when you're outside the target range. It's vibration-only on some models and users ask for spoken alerts. Lap alert audio prompts are on by default.
- **Known complaint (verified):** Garmin Connect charts show the target as one average line instead of a band. **Lesson:** always draw the target as a **band** (upper and lower limits).

### 1.2 Prioritised running features for Strive

| Prio | Feature | Behaviour / look |
|---|---|---|
| MUST | GPS free run recording | Foreground service with a persistent notification. Use `geolocator` with a distance filter of about 3–5 m and Kalman/accuracy filtering (drop fixes with accuracy over 25 m). Keeps recording with the screen off. |
| MUST | Live run screen (see 1.3) | One big metric, a secondary grid, a step card, a map toggle and big controls. Stays readable in sunlight. |
| MUST | Auto-pause | Pause when speed stays under about 1 km/h for 5 s, resume when moving. Show a "Paused" banner and give an audio cue. |
| MUST | Audio cues (TTS) | Use `flutter_tts` with audio ducking (`audio_session`). Speak every 1 km (configurable) with distance, time, average pace and last split, plus step change and pace alerts. |
| MUST | Structured workouts | Steps: warm-up, run, recovery, cool-down and repeat blocks. Each step has a duration (distance or time) and a target (pace range, HR zone or "conversational"). Build them on the phone. |
| MUST | Pace-range alerts | Allow a 5–10 s tolerance. Say "Slightly fast, ease off to 5:30" at most every 30–45 s, and say nothing while in range. Add a haptic buzz. |
| MUST | Post-run summary | Map with a pace-coloured polyline, then key stats, km splits table, pace/HR/elevation charts, HR zone distribution bar, steps-vs-target compliance and best efforts. Share as an image. |
| MUST | Training plan generator (Runna-like, rule-based) | Setup: goal (5K/10K/HM/M/general fitness), race date, recent race time or 5K estimate, runs per week, available days, long-run day and experience. Output: periodised weeks (base, build, peak, taper) with easy, long, tempo, interval and recovery runs. Paces come from VDOT/Riegel. |
| MUST | Pace zones from a race time | Compute easy, marathon, threshold, interval and repetition paces with the Daniels VDOT formula, and show them as ranges. |
| MUST | Health Connect write/read | Write ExerciseSession, route, distance, HR samples and calories. Read watch runs recorded by Samsung Health so they appear in Strive. |
| MUST | Personal records / best efforts | Auto-detect the fastest 1K, 1 mi, 5K, 10K, HM and M inside every run. Show a trophy on the summary. |
| NICE | Plan adaptation | Move a run by dragging it. "Not feeling 100%" turns a hard session into easy or rest. Missed week means repeat the week. Recalibrate paces after a race or time trial. |
| NICE | Predicted race times | Riegel formula from recent best efforts, shown on the plan header and updated weekly. |
| NICE | Route planner | `flutter_map` with OSM tiles. Tap to add waypoints, snap with public OSRM/BRouter/GraphHopper (respect usage policies, or self-host), show distance and elevation, save, then follow with an off-route alert. |
| NICE | GPX import/export | Import routes to follow and export activities. |
| NICE | Local segments | User-defined start/end gates on their own routes. Match automatically after each run and show a PR history. With no server-side leaderboards, keep it personal or friends-only via Firestore. |
| NICE | Social (Firestore) | Friends feed, kudos, comments and a monthly challenge, for example "100 km in November". |
| NICE | Ghost / last-time comparison | On a repeated route, "12 s ahead of your last run". |
| NICE | Heat / weather adjustment | Widen pace ranges when it's above about 25 °C, using the free Open-Meteo API. |
| NICE | Spotify launcher | See section 5. |
| NICE | Wear OS companion | Later: mirror the step card on the Galaxy Watch. Runna doesn't support Galaxy Watch, so this is a differentiator. |

### 1.3 A great live run tracking screen (recommended layout)

Use a dark background, high-contrast white numbers and tabular figures. Everything must be readable at arm's length while running. Portrait only.

```
┌──────────────────────────────────────┐
│ GPS ●●●  ♥ HR source   🔒   12:41    │  1. Status bar: GPS quality, HR sensor, lock, time
├──────────────────────────────────────┤
│ ▶ INTERVAL 3 / 6 · RUN               │  2. STEP CARD (only in structured workouts)
│ 400 m left  ·  target 4:35–4:45 /km  │     - step name + repeat counter
│ ███████████░░░░░░  (step progress)   │     - remaining distance/time in the step
│ Next: 90 s recovery jog              │     - target band + progress bar + "Next"
│ [ON PACE ✓]  (green / amber / red)   │     - colour-coded compliance chip
├──────────────────────────────────────┤
│              4:41                     │  3. BIG METRIC (about 96–120 sp):
│        current pace /km              │     current pace in a step, else distance
├──────────────────────────────────────┤
│  5.23 km   │  26:14    │  4:59 avg   │  4. SECONDARY GRID 2×3 (customisable):
│  distance  │  time     │  avg pace   │     distance, moving time, avg pace,
│  152 bpm Z3│  +48 m    │  172 spm    │     HR + zone, elevation gain, cadence
├──────────────────────────────────────┤
│  pace graph / target band (mini)     │  5. Optional mini chart: last 2 min pace vs band
├──────────────────────────────────────┤
│   [ LAP ]     [ ❚❚ PAUSE ]   [ MAP ] │  6. CONTROLS: big pause in the centre (≥72 dp),
│                                       │     lap and map toggle. STOP = long-press 2 s
└──────────────────────────────────────┘     (or swipe-to-end) to avoid accidents
```

**Examples for the step card**
- An easy run in a plan reads: **"5.0 km left · conversational pace (Zone 2, 5:50–6:20 /km)"**, with a small hint: "You should be able to talk in full sentences."
- A long run reads: "Long run · 8.4 / 16 km · Easy 5:45–6:15".
- A free run has no card. The big metric shows distance and the secondary grid shows pace, time and HR.

**Behaviour**
- **Swipe pages:** page 1 shows metrics (above), page 2 is a full-screen map with a small metric overlay (Strava 2025 combines both), and page 3 is a splits list.
- **Step transitions:** a full-width flash card for 3 s ("RECOVERY · 90 s jog"), plus a TTS announcement, a double vibration and a countdown beep over the last 3 s of a time step.
- **Lock:** a lock icon disables touch input (protects against sweat and pockets). Unlock with a long-press or slide. Keep the screen on only if the user chooses (wakelock). The default is screen off with audio.
- **Lock screen / notification:** an ongoing foreground-service notification shows time, distance, pace and the current step, with Pause/Lap actions. Use a custom notification layout and update it once per second. A lock-screen widget like iOS Live Activities isn't available on Android, but a rich media-style notification on the lock screen gets close.
- **Pause state:** the whole screen tints amber, "PAUSED" pulses, and the big buttons become Resume and Finish.
- **Finish:** confirm, then save, then go to the summary with a confetti or PR badge if records were broken.
- **Accessibility:** support font scaling, use colour plus icons (never colour alone) for compliance, and fully support German and English TTS (`flutter_tts.setLanguage('de-DE')`).

### 1.4 Audio cue script (recommended)

Use the current locale. Keep cues short and say numbers naturally.
- Start: countdown "3, 2, 1, go".
- Every km: "Kilometre 3. Time 15 minutes 20. Average pace 5:07. Last kilometre 5:01."
- Step start: "Interval 3 of 6. 400 metres at 4:40 per kilometre."
- Step end and next: "Recovery. 90 seconds easy jog."
- Pace alerts, when out of band longer than the tolerance: "A bit fast, slow down to 4:45" or "Pick it up, target 4:40." Throttle to at most one every 30 s.
- Halfway: "Halfway done, great work."
- Finish: "Workout complete. 10.2 km in 52:10."
- Settings: interval (distance or time), which fields to speak, voice language, mute alerts and how much to duck other audio.

---

## 2. Cycling

### 2.1 Market leaders and most-loved features

| App | Known for | Most-loved features |
|---|---|---|
| **Strava** | Social and segments | Segments with KOM/QOM leaderboards, Live Segments, heatmaps, route builder, clubs, kudos, Best Efforts and power curves (subscribers). |
| **Komoot** | Route planning | Sport-specific routing (road, gravel, MTB, touring), way-type and surface breakdown, elevation profile, community Highlights (POIs) that routing passes through, turn-by-turn voice navigation, re-routing, offline maps (one region free) and multi-day tours. Community heatmap layer added Dec 2025. |
| **Zwift** | Social indoor game | Virtual worlds, group rides, races, ERG mode, structured workouts and plans. Can run TrainerRoad workouts. |
| **TrainerRoad** | Structured power training | Huge interval workout library, adaptive training (adjusts plans from performance), FTP detection, a plan builder working back from the target event, ERG control and no gamification. |
| **Wahoo SYSTM** | Multisport training | 4DP fitness profile (four metrics: NM, AC, MAP, FTP), a "Full Frontal" test, cinematic workouts, plus yoga, strength and run plans in one plan. |
| **Garmin Connect / Edge** | Head unit | ClimbPro (remaining climbs with gradient), training status and load, power/HR zones, course navigation and incident detection. |
| **Rouvy** | Real-world video routes | AR route videos (acquired BKOOL and FulGaz). |

### 2.2 Prioritised cycling features for Strive

| Prio | Feature | Behaviour / look |
|---|---|---|
| MUST | GPS ride recording | Same engine as running, but the big metric is **speed (km/h)**. Secondary: distance, time, average speed, elevation gain, HR and gradient. Auto-pause at under 3 km/h. |
| MUST | Bike-mount mode | Landscape or portrait large-font layout, screen-on by default and a dark map. |
| MUST | Ride summary | Speed-coloured map, elevation profile, speed and HR charts, climbs list (auto-detected: over 500 m long and over 3% average), plus calories. |
| MUST | Health Connect sync | Write a cycling ExerciseSession with route, distance, speed and HR. Import watch rides. |
| MUST | Indoor ride logging | Manual or Health Connect import of indoor and spin sessions with duration, HR, calories and optional power. |
| NICE | Route planner (Komoot-lite) | OSM map, tap-to-route with a bike profile (road or gravel), elevation profile, surface breakdown from OSM `surface` tags, GPX export and turn-by-turn TTS when following. |
| NICE | Climb detection and "ClimbPro-lite" | While following a route: "Climb 2/3 · 1.8 km left · 6% avg". |
| NICE | BLE sensors | Heart-rate strap, speed/cadence and power meter via `flutter_blue_plus` (standard GATT profiles: HR 0x180D, CSC 0x1816, Cycling Power 0x1818). |
| NICE | Structured indoor workouts | Interval timer with power or HR targets and the same step card as running. ERG control of smart trainers (FTMS 0x1826) much later. |
| NICE | FTP test and power zones | A 20-min test protocol with FTP = 0.95 × 20-min power. Coggan zones Z1–Z7. |
| NICE | Personal segments | Same mechanism as running. |
| NICE | Training load | TRIMP or HR-based load with acute vs chronic (ATL/CTL) chart across all sports. |

---

## 3. Swimming

### 3.1 Market leaders and most-loved features

| App | Known for | Most-loved features |
|---|---|---|
| **MySwimPro** | Structured swim training | Guided workouts with "Smart Intervals" on the watch, AI coach and personalised plans, custom workout builder, dryland library, analytics (lap splits, strokes per lap, SWOLF, HR). Syncs with Apple Watch, Garmin and **Wear OS**. Criticism: "designed for interval training, not lap swimming", and buggy at times. |
| **Swim.com** | Free logging and community | Free, workout creation, in-depth stats, community and challenges. |
| **FORM Swim** | Smart goggles | In-goggle live data, visual coaching, open-water heading guidance, plans and post-swim analysis. Needs goggles, so it isn't relevant for Strive except as inspiration for post-swim analysis. |
| **Garmin Swim / Garmin watches** | Watch-based gold standard | Pool length setting, auto rest (stopping over 15 s creates a rest interval), stroke detection per length, SWOLF, drill logging (kick or one-arm: time and distance logged manually), Critical Swim Speed (CSS) test, pace alerts and open-water GPS. |
| **Samsung Health (Galaxy Watch)** | Strive's data source | Pool swim with pool length, lengths, strokes, SWOLF and auto-detected stroke type, plus open-water swims, all written to Health Connect. |

### 3.2 Prioritised swimming features for Strive

Strive can't track swimming on the phone (the phone stays out of the water), so swimming is **watch-recorded, then imported**, plus planning and analysis.

| Prio | Feature | Behaviour / look |
|---|---|---|
| MUST | Import swims from Health Connect | Read ExerciseSession (pool or open water) with distance, duration, laps/segments, HR and calories. Show it in the activity feed. |
| MUST | Swim summary | Total distance, time, average pace /100 m, lengths, SWOLF (if available), HR chart and a laps table with a stroke icon per lap, if Health Connect gives segment data. |
| MUST | Manual swim log | Pool length (25/50 m or yd), sets as "4×100 free @ 2:00" with times, and RPE. |
| MUST | Swim workout builder | Warm-up, main and cool-down blocks. Each set has reps, distance, stroke, intensity and a send-off (interval) or rest. Show total distance and estimated duration. |
| MUST | Pace per 100 m and trends | Chart of average pace /100 m and weekly volume. |
| NICE | Pool-deck mode | A big-font, screen-on view of the workout: current set, "Rep 3/8 · leave on 1:45" and a big pace clock (send-off countdown). Useful with the phone on the pool deck. |
| NICE | CSS test and zones | 400 m + 200 m time trial. CSS = 200 / (T400 − T200) in m/s, giving per-100 m training paces (CSS, CSS+5 s and so on) shown in workouts. |
| NICE | Drill library | Catch-up, fingertip drag, kick with board, pull buoy: each with a text description and an icon. |
| NICE | Swim plans | 4–8 week plans (beginner freestyle, endurance to 1500 m, triathlon prep) using CSS paces. |
| NICE | Dryland routines | Reuse the gym module (shoulder mobility, core). |
| NICE | Open-water map | If Health Connect gives an exercise route, show the GPS track. |

---

## 4. Gym (Strong, Hevy, Fitbod)

### 4.1 What the leaders do

- **Hevy (verified from its help pages)**
  - Set types: normal, **warm-up (W)**, **drop set (D)** and **failure (F)**, picked from the set-number menu.
  - **Supersets and giant sets:** auto-scroll to the next exercise in the superset after a set is ticked.
  - **Warm-up calculator:** percentage-based warm-up sets with a configurable formula and rounding.
  - **Plate calculator:** barbell, EZ bar or short bar.
  - **RPE** is optional and off by default.
  - **Rest timer per exercise** with a global default, which can be disabled per exercise. The timer doesn't start before a drop set.
  - Estimated 1RM, routines and folders, a social feed and a large exercise library with animations.
  - Pricing: about $24–40 a year or $75 lifetime.
- **Strong**
  - Minimal, fast logger with a warm-up calculator and **plate calculator** (a standout per reviews).
  - Auto rest countdown, supersets and grouped exercises, notes and progress photos, and the previous set's values shown inline (common pattern: "previous" column).
  - Free tier is limited to 3 routines. The watch app is very polished.
- **Fitbod**
  - **Generates** workouts: recovery percentage per muscle group (0–100%), which also counts cardio imported from Health Connect.
  - Progression of weight and reps from logged performance, and estimated 1RM.
  - De-loads suggested weights after time off.
  - **Exercise swap / replace**, with "recommend more / less / exclude" preferences.
  - Pricing: about $96 a year.

### 4.2 Prioritised gym features for Strive

| Prio | Feature | Behaviour / look |
|---|---|---|
| MUST | Fast set logging | Exercise card with columns Set, Previous, kg, Reps, ✓. "Previous" shows the last session's values in grey. Tapping a weight or reps field copies previous. Ticking a set starts the rest timer. |
| MUST | Set types | Tap the set number to choose Normal, Warm-up (W, orange), Drop (D, purple) or Failure (F, red). Warm-ups are excluded from volume and PRs. |
| MUST | Rest timer per exercise | Default 90 s with a per-exercise override. Starts automatically on ✓ and shows a bottom bar with countdown, −15 s and +15 s. Vibrate and sound at 0, and keep running in a notification when the app is in the background. |
| MUST | Supersets | Long-press, then "Superset with…". A coloured left bar groups the exercises, and ticking a set jumps to the next exercise in the group. The rest timer starts only after the last exercise of the round. |
| MUST | Routines / templates | Create, reorder and duplicate, then "Start routine" pre-fills targets from last time. |
| MUST | Exercise library | About 200 built-in exercises with muscle groups, equipment and a text description (no paid API). Custom exercises are allowed. |
| MUST | Exercise notes | Sticky per-exercise note (seat height, grip) shown above the sets, plus a note per workout. |
| MUST | Replace exercise | ⋮ menu, then "Replace" suggests alternatives with the same primary muscle and similar equipment. Logged sets are kept if the user agrees. |
| MUST | Plate calculator | Tap the weight, then the plate icon. Bar weight is selectable (20/15/10 kg, EZ). Shows coloured plates per side graphically and lets the user set which plates are available. |
| MUST | Warm-up calculator | "Add warm-ups" generates, for example, bar × 10, 40% × 5, 60% × 3, 80% × 1, rounded to available plates. The formula can be changed. |
| MUST | PRs and e1RM | Epley/Brzycki estimated 1RM, plus PR badges (weight, reps, volume, e1RM) shown when a set is ticked and on the summary. |
| MUST | Workout summary | Duration, volume, sets, PRs and a muscle heatmap. Write to Health Connect as ExerciseSession STRENGTH_TRAINING. |
| NICE | RPE / RIR | Optional column (off by default) with a picker for RPE 6–10 in half steps, or RIR 0–4. |
| NICE | Progression suggestions | Rule-based double progression. If all sets hit the top of the rep range at RPE 8 or lower, suggest +2.5 kg (upper body) or +5 kg (lower body). If reps are missed twice, hold. If missed three times, deload 10%. Shown as a ↑ chip on the exercise. |
| NICE | Muscle recovery map | Fitbod-like percentage per muscle based on sets in the last 72 h, shown as a body heatmap that suggests "fresh" muscles. |
| NICE | Exercise history charts | e1RM, best set and volume over time for each exercise. |
| NICE | Programs | Pre-built plans (PPL, Upper/Lower, 5/3/1, GZCLP) with progression rules. |
| NICE | Wear OS logging | Tick sets and see the rest timer on the Galaxy Watch (later). |
| NICE | Bodyweight / measurements | Logs with charts, and read weight from Health Connect. |

---

## 5. Spotify integration (no paid API, no SDK required)

**How apps do it**
- Strava, Runna and Nike Run Club mostly let music play in the background and **duck** it for their own voice cues.
- Some apps add a "music" button that opens Spotify or a running playlist.
- Full control (play, skip, now-playing) needs the Spotify App Remote SDK, which is free but requires a developer app registration and client ID. That's optional for later.

**Recommended approach for Strive**
1. **Deep link button** on the pre-run screen and the live screen ("🎵 Music"):
   - Use `url_launcher` with `spotify:playlist:<id>` to open the Spotify app directly on the playlist.
   - If Spotify isn't installed or the link fails, open `https://open.spotify.com/playlist/<id>`.
   - Android 11+ needs a `<queries>` entry in `AndroidManifest.xml` (package `com.spotify.music`, or a `spotify` scheme intent) for `canLaunchUrl` to work.
   - Community reports say `android.intent.action.VIEW` with package `com.spotify.music` works. `MEDIA_PLAY_FROM_SEARCH` was unreliable.
2. **Preset playlists by workout type:** easy run means a chill or "Running 150 BPM" style playlist, intervals means "Beast Mode" or a high-BPM playlist.
   - Store the playlist IDs in Firestore or Remote Config, because Spotify's editorial playlist IDs can change.
   - Let users paste their own playlist link. Parse `open.spotify.com/playlist/<id>` into the `<id>`.
   - A search link (`spotify:search:running`) is a fallback that needs no IDs.
3. **Audio ducking:** configure `audio_session` (Android `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`) so Spotify lowers its volume while Strive's TTS speaks, then restores it.
4. **Media controls (NICE, later):** the Spotify App Remote SDK (free, needs client ID registration) or Android `MediaSessionManager` notification-listener access can show "now playing" and skip on the live screen.
5. **Opening Spotify without leaving the run:** recording keeps running in the foreground service, and the user returns via the notification.

---

## 6. Cross-sport / platform features (Health Connect and Galaxy Watch 6 Classic)

| Prio | Feature | Behaviour / look |
|---|---|---|
| MUST | Unified activity feed | All sports in one timeline, with Strive-recorded and Health Connect-imported sessions de-duplicated by time overlap. |
| MUST | Weekly overview | Total time and distance per sport, a training-days calendar dot view and streaks. |
| MUST | HR zones (shared) | Max HR (age-based or user-entered) or Karvonen with resting HR from Health Connect. Five zones, shared across sports. |
| MUST | Watch HR during phone runs | During a phone-recorded run, read live HR. Note: Health Connect isn't real-time. Live HR needs a BLE strap or a Wear OS companion. Otherwise, back-fill HR from Health Connect after the run. |
| NICE | Training load and recovery | Combined load across sports, rest-day suggestions and sleep/HRV from Health Connect where available. |
| NICE | Gemini coach integration | Feed plan, recent sessions and load to the AI coach for adjustments and Q&A (already planned in Strive). |
| NICE | Badges and challenges | First 10K, 100 km month, 10 gym sessions, swim 5 km. |

---

## 7. Implementation notes (free tools)

- **Maps:** `flutter_map` with OpenStreetMap tiles. Respect the OSM tile usage policy, or use a free-tier provider such as MapTiler or Stadia for production. `flutter_map_tile_caching` gives offline tiles.
- **Location:** `geolocator` with a foreground service (`flutter_foreground_task`). Request `ACCESS_BACKGROUND_LOCATION` and `FOREGROUND_SERVICE_LOCATION`.
- **TTS:** `flutter_tts` (German and English) with `audio_session` for ducking.
- **Health Connect:** the `health` package for ExerciseSession, ExerciseRoute, HeartRate, Distance, ActiveCaloriesBurned and Speed.
- **Routing:** public OSRM, BRouter or GraphHopper free tiers (rate-limited), or self-host BRouter. Get elevation from the Open-Meteo Elevation API (free).
- **Weather:** Open-Meteo (free, no key).
- **BLE sensors:** `flutter_blue_plus` with the standard GATT HR, CSC, Power and FTMS profiles.
- **Pace math:** Daniels VDOT, Riegel T2 = T1 × (D2/D1)^1.06, Epley 1RM = w × (1 + reps/30), CSS = 200 / (T400 − T200).

---

## Sources

Running / Runna
- [the5krunner – Runna: how Strava's running coach app works](https://the5krunner.com/runna/)
- [the5krunner – Runna vs Strava (Oct 2026)](https://the5krunner.com/2026/10/28/runna-vs-strava/)
- [Runna Support – Setting up and managing your audio cues](https://support.runna.com/en/articles/8159780-setting-up-and-managing-your-audio-cues)
- [Runna Support – Using your Apple Watch with Runna](https://support.runna.com/en/articles/6306200-using-your-apple-watch-with-runna-and-getting-the-most-out-of-it)
- [Runna Support – Using your Garmin watch with Runna](https://intercom.help/runna/en/articles/6169639-using-your-garmin-watch-with-runna-and-getting-the-most-out-of-it)
- [TechRadar – Runna review](https://www.techradar.com/health-fitness/fitness-apps/runna-review)
- [Tom's Guide – Runna for my sixth marathon](https://www.tomsguide.com/wellness/running/this-is-the-running-app-im-using-to-train-for-my-sixth-marathon-and-it-just-got-even-better-for-beginners-too)
- [Autonomous.ai – Runna app review](https://www.autonomous.ai/ourblog/runna-app-review-what-training-with-runna-is-really-like)
- [Google Play – Runna](https://play.google.com/store/apps/details?id=com.runbuddy.prod)

Strava
- [Brujula Bike – Strava updates its recording function](https://en.brujulabike.com/strava-updates-its-recording-function-more-accuracy-more-data-more-customization/)
- [Tour Magazin – Strava update: recording function revised](https://www.tour-magazin.de/en/electronics/bike-computers-sat-navs-trackers/strava-update-recording-function-revised/)
- [GB News – Strava major redesign (Android first)](https://www.gbnews.com/tech/strava-major-update-record-android-ios)
- [Endurance Sports Wire – Strava unveils suite of new subscriber features](https://www.endurancesportswire.com/strava-unveils-suite-of-new-subscriber-features/)
- [Gear and Grit – Strava AI route upgrades](https://gearandgrit.com/strava-ai-updates-route-planning-leaderboard-integrity)
- [Outdoor Magazin – Strava hiking features, navigation and route planning](https://www.outdoor-magazin.com/wandertipps/strava-erweitert-wander-features-navigation-routenplanung/)
- [road.cc – Strava Premium review](https://road.cc/review/strava-premium-287805)
- [Cycling Weekly – Strava surface types and personal heatmaps](https://cyclingweekly.com/news/strava-announces-surface-types-and-personal-heat-maps-have-now-been-added-to-mobile-app)

Samsung / Nike / Garmin
- [Samsung – Personalised Running Coach on Galaxy Watch8](https://www.samsung.com/ca/support/mobile-devices/how-to-use-the-personalized-running-coach-feature-on-your-galaxy-watch8-and-watch8-classic/)
- [Samsung Community – Custom pace target](https://us.community.samsung.com:443/t5/Galaxy-Watch/Samsung-Health-Set-a-Pace-Target-or-custom-Pace-Target-for/td-p/2954622)
- [Samsung Community – Customisable run interval training](https://eu.community.samsung.com/t5/wearables/customisable-run-interval-training/m-p/4782400/highlight/true)
- [Tom's Guide – Nike Run Club review](https://www.tomsguide.com/uk/reviews/nike-run-club-review)
- [T3 – Nike Run Club update](https://www.t3.com/active/latest-nike-run-club-app-update-adds-two-genius-features-runners-will-love-for-free)
- [Garmin fenix 5 manual – workout step display](https://www.manualslib.com/manual/1243940/Garmin-Fenix5.html?page=19)
- [Garmin Forum – audio prompt when above or below pace](https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-mobile-andriod/123583/feature-request-audio-prompt-when-above-or-below-pace-in-workout)
- [Garmin Forum – graphical representation of workout targets](https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-web/207592/request-graphical-representation-of-workout-targets-should-show-upper-lower-limits/1130354)
- [Garmin voice pace alerts guide](https://garmin.vaw.be/en/community/day-99-garmin-voice-pace-alerts)

Cycling
- [BikeRadar – Best indoor cycling apps 2026](https://www.bikeradar.com/advice/buyers-guides/best-indoor-cycling-apps)
- [Cyclingnews – Best indoor cycling apps 2026](https://www.cyclingnews.com/features/indoor-cycling-apps-the-best-to-help-you-stay-fit-during-the-coronavirus-lockdown/)
- [Cyclists Hub – TrainerRoad vs Wahoo SYSTM](https://www.cyclistshub.com/trainerroad-vs-wahoo-systm)
- [Join.cc – Best cycling training apps 2025](https://join.cc/cycling-tips/best-cycling-training-apps)
- [Komoot – Features](https://www.komoot.com/features)
- [Komoot – What's new](https://www.komoot.com/da-dk/whats-new)
- [Komoot – Route planner help](https://www.komoot.com/help/routeplanner)
- [BikeRadar – Guide to using Komoot](https://www.bikeradar.com/advice/buyers-guides/guide-to-using-komoot)

Swimming
- [GOWOD – Best swimming apps (Mar 2026)](https://www.gowod.app/blog/best-swimming-apps-for-performance-tracking-and-recovery)
- [App Store – MySwimPro](https://apps.apple.com/app/id994386450)
- [MySwimPro – Coach+ (AI workouts)](https://www.myswimpro.com/coach-plus)
- [MySwimPro blog – Swimming workout plan](https://blog.myswimpro.com/2024/08/16/swimming-workout-plan/)
- [YourSwimLog – Best swim apps](https://www.yourswimlog.com/?p=34919)
- [Garmin manual – pool swim features (auto rest, drills, SWOLF)](https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-AC68D94C-821E-4567-8705-F433CDEA5525.html)
- [Varuste – Garmin Swim 2 features](https://varuste.net/en/Garmin+Swim+2?_tu=99553)

Gym
- [Hevy – Workout settings (warm-up calculator, rest timer, RPE)](https://www.hevyapp.com/features/workout-settings/)
- [Hevy – What are supersets](https://www.hevyapp.com/features/what-are-supersets/)
- [Hevy – Track workouts](https://www.hevyapp.com/features/track-workouts/)
- [Hevy Help Center – Features](https://help.hevyapp.com/hc/en-us/sections/35650637568407-Features)
- [App Store – Strong Workout Tracker](https://apps.apple.com/gb/app/id464254577)
- [Fitbod Help – How Fitbod creates your workout](https://help.fitbod.me/hc/en-us/articles/360004429814-How-Fitbod-Creates-Your-Workout)
- [Fitbod blog – Muscle recovery](https://fitbod.me/blog/muscle-recovery/)
- [SensAI – Hevy vs Strong vs Fitbod (competitor-authored, biased)](https://www.sensai.fit/blog/hevy-vs-strong-vs-fitbod)
- [Jefit – Fitbod vs Strong vs Jefit vs Hevy (competitor-authored)](https://www.jefit.com/blog/fitbod-vs-strong-vs-jefit-vs-hevy)

Spotify
- [Spotify for Developers – Android content linking](https://developer.spotify.com/documentation/android/tutorials/content-linking)
- [Spotify Community – Starting a playlist via intent (Tasker)](https://community.spotify.com/t5/Android/Tasker-cannot-start-a-Playlist-anymore-Send-intent-does-not-wrok/td-p/4633926)
- [Spotify Community – Links open in browser instead of app](https://community.spotify.com/t5/Android/Spotify-links-won-t-open-in-app-opens-in-browser-android/m-p/5606902/highlight/true)

Note: several comparison pages are written by competing app makers (SensAI, Jefit and others) or are store listings. Feature claims were cross-checked against vendor help pages where possible. Items marked "common pattern" are well-known app behaviour that the sources above did not explicitly confirm.
