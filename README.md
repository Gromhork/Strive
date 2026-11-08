# Strive

All-in-one fitness app for **gym, running, cycling and swimming** – Flutter + Firebase (Android first, iOS-ready).

## Features

| Area | What's in it |
|---|---|
| Onboarding | **Quick** (general questions) or **Detailed**: per-weekday sport plan (1–2×/day), session length, race times → VDOT pace zones, weekly km / longest run, FTP & power meter, CSS swim test, pool length, equipment, strength goal & 1RMs, resting/max HR, limitations, event distance + target time + prediction, difficulty (easy/balanced/challenging), plan length (4–20 weeks, recommendation per goal) |
| Home | Today's workout with intensity profile (tap → plan detail), next 6 days, weather card with athlete hint (tap → detail: best training window score, 24 h / 7 days, wind, UV, air quality, what to wear), watch vitals (steps, resting HR, sleep, HRV), weekly rings, recovery, weight, goals, level |
| Training | Quick start per sport, programs in folders, program editor, share programs via 6-character code & import, 1,300+ exercise library (search incl. German aliases, filters, instructions, video link, personal e1RM chart) |
| Gym session | Pulse-style **focus view** per exercise (animated demo, swipe between exercises), big weight/reps steppers, RPE, set types (warm-up / drop / failure), **supersets** (A1→A2→rest), full-screen rest timer with "up next", double-progression hint, warm-up calculator, plate calculator, replace exercise, notes; compact table view as alternative |
| Cardio session | **Guided workouts**: step card ("3.9 km left · conversational pace · 5:34–6:19 /km · Z2"), on-pace chip, live pace (big), pace chart vs. target band, voice cues (steps, km splits, pace), auto-pause, swipe pages metrics / map / splits, lock screen, hold-to-finish, Spotify button (tempo-matched or own playlist); cycling shows speed as primary metric; indoor & pool modes |
| Summary | XP, new PRs, new badges, level-up, "coach battle" vs. prediction, RPE, notes; marks the planned workout as done |
| Calendar | Week list with drag & drop, month view, plan detail page (phase, key session, structure), plan editor, **evidence-based generator** (see docs/training-science.md) or Gemini, .ics export |
| Stats | Ranges 4W/3M/1Y/all, totals, avg gym days/month, heatmap, minutes per week by sport, e1RM progress, distance per week, body composition (weight/BMI/fat/muscle); records & badges; history with "compare to last time" |
| Stats extras | Fitness / fatigue / form (Banister CTL/ATL/TSB), running best efforts (1k–marathon) and race predictions (VDOT) |
| Integrations | Google sign-in, Health Connect (Galaxy Watch via Samsung Health: import workouts with HR, vitals; write Strive workouts back) |
| AI coach | Gemini (Firebase AI Logic) chat with the athlete's profile, last 28 days, ACWR, PRs and plan as context |
| Gamification | XP per session, overall + per-sport levels, week streak, 16 badges |
| Settings | German/English, dark/light/system, metric/imperial, vibration, drink & training reminders |
| Offline | Firestore offline persistence – everything works without internet and syncs later |

The top bar sport switcher filters Home, Training, Calendar and Stats.

## Structure

```
lib/
  core/       theme, sports, formatting/units
  data/       models, Firestore repository, exercise DB
  services/   insights (XP, badges, ACWR, records), plan generator, coach (Gemini),
              weather (Open-Meteo), notifications, GPS tracker, active gym workout
  features/   auth, onboarding, shell, home, train, session, calendar, stats, coach, goals, profile
  l10n/       app_en.arb / app_de.arb (generated code in l10n/gen)
assets/data/exercises.json   exercise database (from Pulse)
assets/exercises/anim|thumb  exercise animations (Pulse GIFs → animated WebP, 360 px) and thumbnails
docs/training-science.md     evidence spec for the plan generator (papers in docs/papers, not in git)
docs/competitor-features.md  feature research (Strava, Runna, Komoot, Zwift, MySwimPro, Hevy …)
firestore.rules              users/{uid}/** owner-only, shared/{code} for program sharing
```

## Setup notes

- Firebase project: `strive-fitness-app` (Auth: email + anonymous, Firestore `eur3`, AI Logic with Gemini Developer API).
- Deploy rules: `firebase deploy --only firestore:rules --project strive-fitness-app`
- Google sign-in needs the debug/release SHA-1 registered in Firebase (debug key is registered).
- Health Connect requires minSdk 26 and `FlutterFragmentActivity`.
- Toolchain: Flutter 3.29.3. Package versions are pinned to that SDK (firebase_core 3.x, firebase_ai 2.x, fl_chart 0.70).
  Newer majors need a newer Flutter SDK.
- `android/gradle.properties` uses JDK 21 and the Windows trust store, and disables incremental Kotlin builds
  (project and pub cache live on different drives).

### Norton Antivirus (this dev machine)

Norton's "Web/Mail Shield" re-signs HTTPS traffic. For the emulator to reach Firebase, **debug builds only** trust that CA:
- `android/app/src/debug/res/xml/network_security_config.xml` + `res/raw/local_tls_proxy_ca.pem` (native/Firebase SDKs)
- `_DevTlsInspectionOverrides` in `lib/main.dart` (Dart HTTP: Gemini, weather), active only when `kDebugMode`

Release builds are not affected. On another machine, replace or remove the PEM file.

## Roadmap

Strava/Garmin APIs, Wear OS companion (live HR), BLE heart-rate straps, route planner/GPX, segments,
home-screen widgets, friends & challenges, adaptive plan updates from logged RPE.
