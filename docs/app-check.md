# Firebase App Check & Firestore rules – steps for the owner

**Status:** the app *sends* App Check tokens (package `firebase_app_check` 0.3.2+10, activated in
`lib/main.dart` before the first request; Gemini calls go through `striveAI()` in
`lib/services/app_check.dart`). **Nothing is enforced yet.** Until you switch enforcement on in the
Firebase console (step 5), anybody who copies the API key out of the APK can still call Gemini on
your bill. The steps below have to be done by you in the consoles – the code cannot do them.

Project: `strive-fitness-app` · Android app: `com.gromhork.strive`

Providers used by the app:

| Build | Provider | What you must register |
|---|---|---|
| release (`flutter build apk --release`) | Play Integrity | SHA-256 of the signing certificate (step 2) |
| debug / profile (`flutter run`) | Debug provider | the debug token printed in logcat (step 3) |

If a token cannot be obtained (not registered, no Play services, offline) the app still sends the
request, just without a token: before enforcement it works as before, after enforcement the server
rejects it. So do steps 1–4 and check the metrics **before** step 5.

## 1. Play Integrity API (once)

1. Google Play Console → your app → **Test and release → App integrity** → *Play Integrity API* →
   **Link a Cloud project** → choose the Google Cloud project `strive-fitness-app`.
   (If the app is not in the Play Console yet: create it there first; an *Internal testing* track is
   enough.)
2. Google Cloud console → project `strive-fitness-app` → **APIs & Services → Library** → enable
   **Play Integrity API** (usually enabled by the link above).

Note: Play Integrity only vouches for builds Google Play knows. An APK you build yourself and
install with adb / file transfer is usually **not** recognised – for those builds register a debug
token (step 3) or install through an internal-testing track.

## 2. Register the Android app for App Check

1. Firebase console → **Build → App Check → Apps** tab → Android app `com.gromhork.strive` →
   **Play Integrity** → enter the **SHA-256 certificate fingerprint** → Save.
2. Which fingerprint:
   - Release builds are currently signed with the debug keystore
     (`android/app/build.gradle.kts`, `signingConfig = signingConfigs.getByName("debug")`). Get its
     SHA-256 with
     `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
     (or `cd android && gradlew signingReport`).
   - Once the app is distributed through Google Play with *Play App Signing*, add the **App signing
     key certificate** SHA-256 from Play Console → **Test and release → App integrity → App signing**
     as well (keep the old one until no old build is in use).
3. Leave the token time-to-live at the default (1 hour).

## 3. Debug token (development builds, emulator)

1. Run a debug build (`flutter run`) and open logcat; filter for `DebugAppCheckProvider`. The line
   reads *"Enter this debug secret into the allow list in the Firebase Console for your project:
   xxxxxxxx-xxxx-…"*.
2. Firebase console → **App Check → Apps** → Android app → menu **⋮ → Manage debug tokens → Add
   debug token** → paste the secret, give it a name (e.g. "Emulator", "Pixel debug") → Save.
3. The token is per installation: after clearing app data / reinstalling a new one is printed. Keep
   debug tokens secret (anyone holding one passes App Check) and delete unused ones.

## 4. Watch the metrics (a few days)

Firebase console → **App Check → APIs** → **Firebase AI Logic** (and **Cloud Firestore**): the
chart shows *verified / unverified / outdated client* requests. Before enforcing, unverified
requests from real users should be close to zero. Users on an app version without App Check show up
as *outdated client* – they lose the coach (and with Firestore enforcement: all data access) once
you enforce.

## 5. Switch enforcement on

1. Firebase console → **App Check → APIs → Firebase AI Logic → Enforce** → confirm. Takes up to
   ~15 minutes. From now on Gemini calls without a valid token fail (the coach shows its error).
2. Later, when the Firestore metrics are clean: **App Check → APIs → Cloud Firestore → Enforce**.
   This also stops scripts that create anonymous accounts and write data without the app.
3. Optional: **Authentication** can be enforced the same way (App Check → APIs → Authentication),
   which blocks scripted anonymous sign-ups.

To undo: the same page → **Unenforce**.

## 6. Cost protection (recommended, independent of App Check)

- Google Cloud console → **APIs & Services → Firebase AI Logic API** (`firebasevertexai.googleapis.com`)
  → **Quotas & system limits** → lower *Generate content requests per minute per user* and the
  per-project limit to what the app needs.
- Google Cloud console → **Billing → Budgets & alerts** → create a budget with e-mail alerts for the
  project.

## 7. Deploy the Firestore rules

`firestore.rules` changed: shared programs (`shared/{code}`) can be fetched by code (`get`) but only
the owner can list them (`list` with `owner == uid`) – before, any signed-in user could list every
shared program with its owner's uid and profile name. The repository has no `firebase.json`, so
deploy by hand:

Firebase console → **Firestore Database → Rules** → replace the text with the content of
`firestore.rules` → **Publish**. (Use *Rules playground* to check: `get` on
`/shared/ABC234` as any signed-in user → allowed; `list` on `/shared` without a filter → denied.)

Programs shared by older app versions still carry an `ownerName` field (the profile name); new
shares no longer store it. Old shared documents are readable only by people who have the code.
