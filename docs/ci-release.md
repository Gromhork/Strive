# CI & automatische APK-Builds (GitHub Actions)

Zwei Workflows liegen in `.github/workflows/`:

| Workflow | Wann | Was |
|---|---|---|
| **CI** (`ci.yml`) | jeder Pull Request, jeder Push auf `main` | `dart format`-Check (-l 140), l10n-Check, `flutter analyze`, alle Tests – **keine APK** |
| **Release** (`release.yml`) | Push eines Versions-Tags `v1.2.0` | CI-Checks → Release-APK + `.aab` → **GitHub Release** mit Changelog |
| **Release** (manuell) | Actions → *Release* → *Run workflow* | Test-APK als Download-Artefakt (kein Release) |

Die Tests dauern auf GitHub ca. 5–10 Minuten, ein kompletter Release-Lauf etwa 15–25 Minuten.
Ein neuer Push auf denselben PR bzw. auf `main` bricht den alten, noch laufenden Check ab.

## 1. Neue Version veröffentlichen

1. In `pubspec.yaml` die Version erhöhen, z. B. `version: 1.2.0+1`.
   - Der Teil **vor** dem `+` (`1.2.0`) muss genau zum Tag passen, sonst bricht der Lauf schon
     nach wenigen Sekunden (Job *Version*, noch vor den Tests) mit einer klaren Fehlermeldung ab.
   - Die Zahl **nach** dem `+` ignoriert die Pipeline: Der `versionCode` ist die Laufnummer des
     Release-Workflows (steigt automatisch bei jedem Lauf, damit Android Updates immer annimmt).
2. Committen und auf `main` pushen (bzw. per PR mergen).
3. Tag setzen und pushen:

   ```powershell
   git checkout main
   git pull
   git tag v1.2.0
   git push origin v1.2.0
   ```

4. Unter **Actions → Release** läuft der Build. Am Ende erscheint unter **Releases** der Eintrag
   *Strive v1.2.0* mit:
   - `strive-v1.2.0.apk` – direkt aufs Handy installieren
   - `strive-v1.2.0.aab` – für Google Play
   - `SHA256SUMS.txt` – Prüfsummen
   - Release Notes = alle Commits seit dem vorherigen `v*`-Tag

Nur Tags der Form `v` + Ziffer (`v1.2.0`) starten die Pipeline; andere Tags (z. B. `very-old`)
werden ignoriert.

Vorabversionen: Tags mit Bindestrich (z. B. `v1.3.0-beta.1`, dann `version: 1.3.0-beta.1+1`)
werden als *Pre-release* markiert.

**Tag falsch gesetzt (z. B. Version vergessen)?** Tag löschen, Fehler beheben, neu taggen:

```powershell
git push --delete origin v1.2.0
git tag -d v1.2.0
# pubspec.yaml korrigieren, committen, pushen, dann wieder Schritt 3
```

Wurde schon ein Release angelegt, unter *Releases* vorher löschen. Ein erneuter Lauf (*Re-run
jobs*) für denselben Tag ersetzt die Dateien eines bestehenden Releases.

## 2. Test-APK auf Knopfdruck

GitHub → **Actions** → links **Release** → **Run workflow** → Branch wählen → *Run workflow*.
Optional *Skip analyze + tests* anhaken (schneller, ~10 Minuten).

Download: den Lauf öffnen → ganz unten **Artifacts** → `strive-v1.2.0-test-<commit>.zip`
(ohne Signing-Secrets `…-unsigned-debug.zip`; enthält die APK). Artefakte werden 30 Tage aufbewahrt. Es wird **kein** Release erstellt.

## 3. Signing-Secrets einrichten (einmalig)

Ohne Secrets baut die Pipeline mit einem **Debug-Schlüssel**. Dann tragen alle Dateien und der
Release-Titel den Zusatz **`unsigned-debug`**. Solche APKs sind nur zum Testen geeignet:

- Jeder GitHub-Runner erzeugt einen *neuen* Debug-Schlüssel – eine neuere APK lässt sich **nicht**
  über eine ältere installieren, die alte App muss erst deinstalliert werden. **Vorher unbedingt
  [„Vor dem Deinstallieren“](#vor-dem-deinstallieren) beachten**, sonst können Daten verloren gehen.
- Google-Anmeldung und App Check funktionieren nicht (Fingerabdruck in Firebase unbekannt). Nach
  der Installation per **E-Mail** anmelden – oder eine signierte Version verwenden.

Für echte Releases den Upload-Schlüssel aus `docs/release-signing.md` (Schritt 1) hinterlegen.
Mit der [GitHub CLI](https://cli.github.com/) in PowerShell im Repo-Ordner:

```powershell
gh auth login   # einmalig

# Keystore als Base64 (Pfad ggf. anpassen)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\strive-upload.jks")) | gh secret set ANDROID_KEYSTORE_BASE64

# Passwörter: gh fragt verdeckt nach dem Wert (landet nicht in der PowerShell-History)
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_PASSWORD

# Alias des Schlüssels (in der Anleitung: upload)
gh secret set ANDROID_KEY_ALIAS --body upload

gh secret list   # Kontrolle: alle vier müssen erscheinen
```

Alternativ im Browser: Repo → *Settings* → *Secrets and variables* → *Actions* → *New repository
secret* (Base64-Text vorher mit dem `[Convert]`-Befehl ohne `| gh …` erzeugen und kopieren).

Hinweise:

- Entweder **alle vier** Secrets setzen oder **keins**. Fehlen nur einzelne oder stimmt Passwort
  bzw. Alias nicht, bricht der Build mit einer Fehlermeldung ab (statt still unsigniert zu bauen).
- Die Pipeline schreibt `android/key.properties` und den Keystore nur während des Builds auf den
  Runner und löscht sie danach. Beides ist in `.gitignore` – nie committen.
- Fingerabdrücke (SHA-1/SHA-256) des Upload-Schlüssels in Firebase eintragen – siehe
  `docs/release-signing.md` Schritt 4, sonst scheitern Google-Anmeldung/App Check.
- Wer bisher eine mit dem Debug-Schlüssel gebaute Version installiert hat (lokal oder
  `unsigned-debug` aus der Pipeline), muss sie einmal deinstallieren, bevor die signierte Version
  installiert werden kann – vorher [„Vor dem Deinstallieren“](#vor-dem-deinstallieren) beachten.
- Passwörter dürfen beliebige Zeichen enthalten (auch `\`, Leerzeichen, Umlaute). Ein falsches
  Keystore- oder Schlüssel-Passwort bzw. ein falscher Alias wird gleich zu Beginn des Builds mit
  einer klaren Meldung erkannt.

### Vor dem Deinstallieren

Beim Deinstallieren löscht Android alles, was die App auf dem Handy gespeichert hat. Darum vorher:

1. **Gastkonto?** Dann zuerst unter *Profil* → **„Gastkonto sichern“** mit E-Mail oder Google
   verknüpfen. Ein Gastkonto ist an diese Installation gebunden – ohne Verknüpfung sind nach dem
   Deinstallieren **alle** Einheiten, Körperwerte, Programme und der Plan verloren.
2. **Online sein** und die App einmal geöffnet lassen, bis alle Einträge in die Cloud übertragen
   sind. Offline erfasste, noch nicht synchronisierte Einträge gehen sonst verloren.
3. Geräte-Einstellungen wie **Erinnerungen** und andere lokale Einstellungen werden
   zurückgesetzt und müssen danach neu eingerichtet werden.

Danach die neue Version installieren und mit demselben Konto anmelden (bei `unsigned-debug`-Builds
per E-Mail, siehe oben) – Daten eines verknüpften Kontos kommen aus der Cloud zurück.

## 4. Firebase-Konfiguration

`android/app/google-services.json` und `lib/firebase_options.dart` sind im Repo eingecheckt und
werden direkt verwendet – dafür sind **keine** Secrets nötig. (Diese Dateien enthalten nur
öffentliche Client-Kennungen; geschützt wird das Backend über `firestore.rules` und App Check.)

## 5. Technische Details

- Runner `ubuntu-24.04`, Flutter **3.29.3** (fest), JDK **21** (Temurin). Pub-, Flutter- und
  Gradle-Caches werden zwischen Läufen wiederverwendet.
- `android/gradle.properties` enthält Windows-Einstellungen dieses PCs (`org.gradle.java.home`,
  `Windows-ROOT`-Truststore). Die Pipeline überschreibt sie auf dem Runner über
  `~/.gradle/gradle.properties` – lokal ändert sich nichts.
- Versionierung: `versionName` = Tag ohne `v`, `versionCode` = Laufnummer des Release-Workflows
  (+ `BUILD_NUMBER_OFFSET` in `release.yml`; den Wert erhöhen, falls der Workflow einmal neu
  angelegt/umbenannt wird, damit der `versionCode` nie kleiner wird). Die Zahl nach dem `+` in
  `pubspec.yaml` nutzt nur ein **lokaler** Build. Ist eine Pipeline-Version installiert (z. B.
  `versionCode` 12, steht in der Zusammenfassung des Laufs), lehnt Android eine lokal gebaute APK
  mit kleinerem `versionCode` als Downgrade ab. Lokal dann z. B.
  `flutter build apk --release --build-number=13` verwenden (größer als der letzte
  Pipeline-`versionCode`) oder die Zahl nach dem `+` in `pubspec.yaml` entsprechend erhöhen.
- Signing: `.github/scripts/CheckKey.java` prüft Keystore, Alias und Schlüssel-Passwort vor dem
  Build; `.github/scripts/write_key_properties.py` schreibt `android/key.properties` mit korrekt
  maskierten Werten (Java-Properties-Format).
- Berechtigungen: alle Jobs nur Lesezugriff; nur der Job *GitHub Release* darf Inhalte schreiben.
- Alle Actions sind auf feste Commit-SHAs gepinnt (Version steht als Kommentar daneben).
