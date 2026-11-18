# Release signing – steps for the owner

Release builds are signed with `android/key.properties` if it exists, otherwise (fallback for local
testing) with the debug key. Both `android/key.properties` and `*.jks` are in `.gitignore` – never
commit them.

## 1. Create the upload key (once)

PowerShell (keytool ships with the JDK / Android Studio's `jbr\bin`):

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\strive-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Choose a strong password and answer the name questions. Back up the `.jks` file and the password
(password manager + an offline copy). With Play App Signing a lost upload key can be reset via
Google support, but it takes days.

## 2. Create `android/key.properties`

```properties
storePassword=<your password>
keyPassword=<your password>
keyAlias=upload
storeFile=C:/Users/<you>/strive-upload.jks
```

## 3. Build

```powershell
flutter build appbundle --release   # for Google Play (.aab)
flutter build apk --release         # for direct install
```

Check the signature: `cd android; .\gradlew signingReport` (variant `release` must show your
`upload` key, not `androiddebugkey`).

## 4. Register the new fingerprints in Firebase (important)

The SHA-1/SHA-256 of the new key must be added, otherwise **Google Sign-In** and **App Check** fail
in release builds:

1. Get them: `keytool -list -v -keystore $env:USERPROFILE\strive-upload.jks -alias upload`
2. Firebase console → Project settings → Your apps → Android `com.gromhork.strive` → **Add
   fingerprint** → add SHA-1 **and** SHA-256. Then download the new `google-services.json` and
   replace `android/app/google-services.json`.
3. Firebase console → App Check → Android app → Play Integrity → add the SHA-256 (see
   `docs/app-check.md` step 2).
4. After the first upload to Google Play with *Play App Signing*: Play Console → Test and release →
   App integrity → App signing → copy the **App signing key** SHA-1/SHA-256 and add them in Firebase
   (steps 2 and 3) as well – builds installed from Play are signed with Google's key, not yours.
