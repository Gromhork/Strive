// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tagline => 'Gym · Laufen · Rad · Schwimmen — alles an einem Ort.';

  @override
  String get sportGym => 'Gym';

  @override
  String get sportRun => 'Laufen';

  @override
  String get sportRide => 'Radfahren';

  @override
  String get sportSwim => 'Schwimmen';

  @override
  String get focusHybrid => 'Hybrid';

  @override
  String get focusDuathlon => 'Duathlon';

  @override
  String get focusTriathlon => 'Triathlon';

  @override
  String get intensityEasy => 'Locker';

  @override
  String get intensityModerate => 'Moderat';

  @override
  String get intensityTempo => 'Tempo';

  @override
  String get intensityIntervals => 'Intervalle';

  @override
  String get intensityLong => 'Lang';

  @override
  String get intensityTechnique => 'Technik';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get login => 'Anmelden';

  @override
  String get register => 'Konto erstellen';

  @override
  String get haveAccount => 'Schon ein Konto? Anmelden';

  @override
  String get noAccount => 'Noch kein Konto? Registrieren';

  @override
  String get or => 'oder';

  @override
  String get continueAsGuest => 'Als Gast fortfahren';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get authInvalidEmail => 'Ungültige E-Mail-Adresse.';

  @override
  String get authWrongCredentials => 'E-Mail oder Passwort ist falsch.';

  @override
  String get authEmailInUse => 'Diese E-Mail ist bereits registriert.';

  @override
  String get authWeakPassword => 'Das Passwort muss mindestens 6 Zeichen haben.';

  @override
  String get authNetwork => 'Keine Internetverbindung.';

  @override
  String get authNotEnabled => 'Diese Anmeldemethode ist in Firebase noch nicht aktiviert.';

  @override
  String get authError => 'Anmeldung fehlgeschlagen';

  @override
  String get authEnterEmail => 'Bitte zuerst die E-Mail eingeben.';

  @override
  String get authResetSent => 'Link zum Zurücksetzen gesendet – schau in dein Postfach.';

  @override
  String get onboardingTitle => 'Strive einrichten';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get next => 'Weiter';

  @override
  String get letsGo => 'Los geht\'s!';

  @override
  String get welcomeTitle => 'Willkommen bei Strive';

  @override
  String get welcomeSub => 'Ein paar Fragen, damit dein Coach den passenden Plan für dich erstellen kann.';

  @override
  String get yourName => 'Dein Name';

  @override
  String get aboutYou => 'Über dich';

  @override
  String get aboutYouSub => 'Wird für Trainingsbelastung, Pulszonen und Körperwerte genutzt.';

  @override
  String get gender => 'Geschlecht';

  @override
  String get male => 'Männlich';

  @override
  String get female => 'Weiblich';

  @override
  String get diverse => 'Divers';

  @override
  String get age => 'Alter';

  @override
  String get height => 'Größe';

  @override
  String get weight => 'Gewicht';

  @override
  String get bodyCompositionOptional => 'Körperzusammensetzung (optional)';

  @override
  String get bodyFat => 'Körperfett';

  @override
  String get muscleMass => 'Muskelmasse';

  @override
  String get muscle => 'Muskel';

  @override
  String get fitnessLevel => 'Erfahrung';

  @override
  String get fitnessLevelSub => 'Sei ehrlich – der Plan passt sich an, wenn du besser wirst.';

  @override
  String get beginner => 'Einsteiger';

  @override
  String get beginnerDesc => 'Neu dabei oder nach langer Pause';

  @override
  String get intermediate => 'Fortgeschritten';

  @override
  String get intermediateDesc => 'Trainiere seit über 6 Monaten regelmäßig';

  @override
  String get advanced => 'Profi';

  @override
  String get advancedDesc => 'Jahrelanges strukturiertes Training';

  @override
  String get experienceWith => 'Erfahrung mit';

  @override
  String get focusTitle => 'Dein Fokus';

  @override
  String get focusSub => 'Wofür trainierst du hauptsächlich?';

  @override
  String get yourGoals => 'Deine Ziele';

  @override
  String get goalStrength => 'Stärker werden';

  @override
  String get goalMuscle => 'Muskeln aufbauen';

  @override
  String get goalFatLoss => 'Fett verlieren';

  @override
  String get goalEndurance => 'Ausdauer';

  @override
  String get goalHealth => 'Gesundheit';

  @override
  String get goalRace => 'Wettkampf';

  @override
  String get scheduleTitle => 'Trainingstage';

  @override
  String get scheduleSub => 'An welchen Tagen möchtest du trainieren?';

  @override
  String daysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage pro Woche',
      one: '1 Tag pro Woche',
    );
    return '$_temp0';
  }

  @override
  String get longSessionDay => 'Tag für die lange Einheit';

  @override
  String get automatic => 'Automatisch';

  @override
  String get units => 'Einheiten';

  @override
  String get metric => 'Metrisch (kg, km)';

  @override
  String get imperial => 'Imperial (lb, mi)';

  @override
  String get eventTitle => 'Trainierst du für ein Event?';

  @override
  String get eventSub => 'Füge einen Wettkampf hinzu (Marathon, Triathlon …) und erhalte einen Countdown. Optional.';

  @override
  String get eventName => 'Name des Wettkampfs';

  @override
  String get eventDate => 'Datum des Wettkampfs';

  @override
  String get eventDistance => 'Distanz';

  @override
  String get halfMarathon => 'Halbmarathon';

  @override
  String get marathon => 'Marathon';

  @override
  String get generatePlanNow => 'Trainingsplan erstellen';

  @override
  String get generatePlanNowSub => 'Aus deinen Antworten erstellt – alles ist später änderbar.';

  @override
  String get navHome => 'Home';

  @override
  String get navTrain => 'Training';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navStats => 'Statistik';

  @override
  String get navCoach => 'Coach';

  @override
  String get allSports => 'Alle Sportarten';

  @override
  String get weekStreakTooltip => 'Wochen in Folge mit erreichtem Trainingsziel';

  @override
  String get goodMorning => 'Guten Morgen';

  @override
  String get goodAfternoon => 'Hallo';

  @override
  String get goodEvening => 'Guten Abend';

  @override
  String get todaysWorkout => 'Heutige Einheit';

  @override
  String get restDay => 'Ruhetag';

  @override
  String get restDaySub => 'Erholung ist auch Training. Trotzdem Lust auf Bewegung?';

  @override
  String doneToday(int count) {
    return 'Heute $count erledigt 💪';
  }

  @override
  String get train => 'Trainieren';

  @override
  String get start => 'Starten';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get comingUp => 'Demnächst';

  @override
  String get toCalendar => 'Kalender';

  @override
  String get rest => 'Pause';

  @override
  String get weather => 'Wetter';

  @override
  String get feelsLike => 'gefühlt';

  @override
  String get retry => 'Erneut';

  @override
  String get weatherNoLocation => 'Standort erlauben für lokales Wetter';

  @override
  String get weatherError => 'Wetter nicht verfügbar';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get trainedThisWeek => 'diese Woche trainiert';

  @override
  String get readyBuilding => 'Basis wird aufgebaut';

  @override
  String get readyBuildingText => 'Nach ca. 3 Wochen Training kann Strive deine Belastung und Erholung einschätzen.';

  @override
  String get readyFresh => 'Erholt';

  @override
  String get readyFreshText => 'Deine Belastung ist niedrig – ideal für eine Schlüsseleinheit oder mehr Umfang.';

  @override
  String get readyOptimal => 'Optimale Belastung';

  @override
  String get readyOptimalText => 'Deine Trainingsbelastung liegt im idealen Bereich. Weiter so!';

  @override
  String get readyHigh => 'Hohe Belastung';

  @override
  String get readyHighText => 'Die Belastung steigt schnell. Achte auf Schlaf und halte die nächste Einheit locker.';

  @override
  String get readyOver => 'Erholung empfohlen';

  @override
  String get readyOverText => 'Das Verletzungsrisiko ist erhöht. Gönn dir einen Ruhetag oder eine lockere Alternative (Spaziergang, Mobility).';

  @override
  String get weightLogHint => 'Trage dein Gewicht mit + / – ein, um den Verlauf zu sehen';

  @override
  String get goals => 'Ziele';

  @override
  String get noGoalsYet => 'Noch keine Ziele – setz dir eins, um motiviert zu bleiben.';

  @override
  String levelN(int level) {
    return 'XP-Stufe $level';
  }

  @override
  String xpToNext(int xp) {
    return 'Noch $xp XP bis zum nächsten Level';
  }

  @override
  String get freeWorkout => 'Frei';

  @override
  String get workoutRunning => 'Einheit läuft';

  @override
  String get workoutRunningBody => 'Es läuft noch eine andere Einheit. Verwerfen und neu starten?';

  @override
  String get discardAndStart => 'Verwerfen & starten';

  @override
  String get startTraining => 'Einheit starten';

  @override
  String get logManually => 'Manuell eintragen';

  @override
  String get openWater => 'Freiwasser';

  @override
  String get outdoor => 'Draußen (GPS)';

  @override
  String get pool => 'Becken';

  @override
  String get indoor => 'Indoor';

  @override
  String get poolLength => 'Beckenlänge';

  @override
  String get poolHint => 'Tippe nach jeder Bahn auf „Bahn“. Die Distanz wird automatisch berechnet.';

  @override
  String get indoorHint => 'Laufband / Rolle: Distanz am Ende eintragen.';

  @override
  String get gpsHint => 'GPS zeichnet Strecke, Distanz und Pace auf – auch bei ausgeschaltetem Bildschirm.';

  @override
  String get gpsServiceOff => 'Bitte Standortdienste aktivieren.';

  @override
  String get gpsPermissionDenied => 'Für GPS-Tracking wird die Standortberechtigung benötigt.';

  @override
  String get noActiveWorkout => 'Keine aktive Einheit.';

  @override
  String get noSetsDone => 'Keine Sätze abgehakt';

  @override
  String get noSetsDoneBody => 'Diese Einheit verwerfen?';

  @override
  String get discard => 'Verwerfen';

  @override
  String get finishWorkout => 'Einheit beenden?';

  @override
  String get finishWorkoutBody => 'Deine Einheit wird nach der Zusammenfassung gespeichert.';

  @override
  String get finish => 'Beenden';

  @override
  String get minimize => 'Minimieren';

  @override
  String get rename => 'Umbenennen';

  @override
  String get discardWorkout => 'Einheit verwerfen';

  @override
  String get addExercise => 'Übung hinzufügen';

  @override
  String get duration => 'Dauer';

  @override
  String get volume => 'Volumen';

  @override
  String get sets => 'Sätze';

  @override
  String get restTimeSeconds => 'Pausenzeit (Sekunden)';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get remove => 'Entfernen';

  @override
  String get setShort => 'Satz';

  @override
  String get previous => 'Vorher';

  @override
  String get reps => 'Wdh.';

  @override
  String get addSet => 'Satz hinzufügen';

  @override
  String get skip => 'Überspringen';

  @override
  String get enterDistance => 'Zurückgelegte Distanz';

  @override
  String get distance => 'Distanz';

  @override
  String get avgPace => 'Ø Pace';

  @override
  String get avgSpeed => 'Ø Tempo';

  @override
  String get laps => 'Bahnen';

  @override
  String get lap => 'Bahn';

  @override
  String get elevation => 'Höhenmeter';

  @override
  String get lastSplit => 'Letzter km';

  @override
  String get undoLap => 'Letzte Bahn rückgängig';

  @override
  String get pauseToFinish => 'Pausieren zum Beenden';

  @override
  String get gpsError => 'GPS-Fehler';

  @override
  String get gpsSearching => 'Suche GPS …';

  @override
  String get summary => 'Zusammenfassung';

  @override
  String get greatJob => 'Starke Leistung! 🎉';

  @override
  String get exercises => 'Übungen';

  @override
  String get coachBattleWon => 'Coach-Battle gewonnen! Du hast die Prognose aus deiner letzten Einheit geschlagen.';

  @override
  String get coachBattleLost => 'Coach-Battle: Die Prognose lag diesmal etwas höher – nächstes Mal!';

  @override
  String get newPr => 'Neue Bestleistung!';

  @override
  String get howHard => 'Wie anstrengend war\'s?';

  @override
  String get notesHint => 'Notizen (Wie hat es sich angefühlt? Schlaf, Ernährung …)';

  @override
  String get saveWorkout => 'Einheit speichern';

  @override
  String get discardSummaryBody => 'Diese Einheit wird nicht gespeichert.';

  @override
  String get rpeVeryEasy => 'sehr leicht';

  @override
  String get rpeEasy => 'leicht';

  @override
  String get rpeModerate => 'mittel';

  @override
  String get rpeHard => 'hart';

  @override
  String get rpeMax => 'maximal';

  @override
  String get badgeFirst => 'Erste Einheit';

  @override
  String get badgeTen => '10 Einheiten';

  @override
  String get badgeFifty => '50 Einheiten';

  @override
  String get badgeHundred => '100 Einheiten';

  @override
  String get badgeTon => '10 t in einer Einheit';

  @override
  String get badge5k => '5-km-Lauf';

  @override
  String get badge10k => '10-km-Lauf';

  @override
  String get badgeHalf => 'Halbmarathon';

  @override
  String get badgeMarathon => 'Marathon';

  @override
  String get badgeCentury => '100 km Rad';

  @override
  String get badgeSwim1k => '1 km Schwimmen';

  @override
  String get badgeSwim3k => '3 km Schwimmen';

  @override
  String get badgeStreak4 => '4 Wochen Streak';

  @override
  String get badgeStreak12 => '12 Wochen Streak';

  @override
  String get badgeEarly => 'Frühaufsteher';

  @override
  String get badgeAllround => 'Allrounder';

  @override
  String get title => 'Titel';

  @override
  String get totalVolume => 'Gesamtvolumen';

  @override
  String get saved => 'Gespeichert';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Löschen';

  @override
  String get share => 'Teilen';

  @override
  String get newProgram => 'Neues Programm';

  @override
  String get editProgram => 'Programm bearbeiten';

  @override
  String get quickStart => 'Schnellstart';

  @override
  String get programs => 'Programme';

  @override
  String get importCode => 'Code importieren';

  @override
  String get noPrograms => 'Noch keine Programme für diese Sportart.';

  @override
  String get noFolder => 'Sonstige';

  @override
  String get codeNotFound => 'Code nicht gefunden.';

  @override
  String imported(String name) {
    return '„$name“ importiert';
  }

  @override
  String get offlineAction => 'Dafür wird eine Internetverbindung benötigt.';

  @override
  String get emptyWorkout => 'Leere Einheit';

  @override
  String get recordGps => 'Aktivität aufzeichnen';

  @override
  String get exerciseLibrary => 'Übungsbibliothek';

  @override
  String addN(int count) {
    return '$count hinzufügen';
  }

  @override
  String get searchExercises => 'Übungen suchen (z. B. Bankdrücken, Squat)';

  @override
  String get bodyPart => 'Körperpartie';

  @override
  String get equipment => 'Ausrüstung';

  @override
  String nResults(int count) {
    return '$count Übungen';
  }

  @override
  String get all => 'Alle';

  @override
  String get secondaryMuscles => 'Sekundär';

  @override
  String get watchVideo => 'Video-Anleitung ansehen';

  @override
  String get yourRecords => 'Deine Rekorde';

  @override
  String get maxWeight => 'Max. Gewicht';

  @override
  String get sessions => 'Einheiten';

  @override
  String get strengthProgress => 'Kraftentwicklung (e1RM)';

  @override
  String get instructions => 'Anleitung';

  @override
  String get instructionsEnglishNote => 'Anleitungen sind aktuell auf Englisch verfügbar.';

  @override
  String codeCopied(String code) {
    return 'Code $code kopiert';
  }

  @override
  String shareText(String name, String code) {
    return 'Probier mein Strive-Programm „$name“! Import-Code: $code';
  }

  @override
  String get deleteProgram => 'Programm löschen?';

  @override
  String get name => 'Name';

  @override
  String get folder => 'Ordner';

  @override
  String get description => 'Beschreibung';

  @override
  String get startWorkout => 'Einheit starten';

  @override
  String get targetDistance => 'Zieldistanz';

  @override
  String get intensity => 'Intensität';

  @override
  String get planWorkout => 'Einheit planen';

  @override
  String get editWorkout => 'Einheit bearbeiten';

  @override
  String get program => 'Programm';

  @override
  String get none => 'Keins';

  @override
  String get markSkipped => 'Als ausgelassen markieren';

  @override
  String get generatePlan => 'Plan erstellen';

  @override
  String generatePlanSub(String focus, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage/Woche',
      one: '1 Tag/Woche',
    );
    return 'Fokus: $focus · $_temp0 (in den Planeinstellungen änderbar)';
  }

  @override
  String get planLocalDesc => 'Periodisierter Plan nach sportwissenschaftlichen Prinzipien (80/20, progressive Überlastung, Entlastungswoche alle 3–5 Wochen, je nach Schwierigkeit). Funktioniert offline.';

  @override
  String planCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einheiten geplant',
      one: '1 Einheit geplant',
    );
    return '$_temp0';
  }

  @override
  String get aiUnavailable => 'Der KI-Coach ist gerade nicht erreichbar. Prüfe deine Verbindung oder aktiviere Firebase AI Logic.';

  @override
  String get syncCalendar => 'Kalender exportieren';

  @override
  String get currentWeek => 'Aktuell';

  @override
  String get nextWeek => 'Nächste';

  @override
  String get lastWeek => 'Letzte Woche';

  @override
  String get nothingPlanned => 'Nichts geplant.';

  @override
  String get nothingToExport => 'Keine kommenden Einheiten zum Exportieren.';

  @override
  String get icsShareText => 'Mein Strive-Trainingsplan (.ics) – mit einer Kalender-App öffnen, um ihn zu importieren.';

  @override
  String get planGymDesc => 'Krafteinheit – progressive Überlastung: Gewicht oder Wdh. steigern, wenn alle Sätze gut laufen.';

  @override
  String get planEasyRun => 'Lockerer Lauf';

  @override
  String get planEasyRide => 'Grundlagenfahrt';

  @override
  String get planEasyDesc => 'Zone 2 – du solltest in ganzen Sätzen sprechen können.';

  @override
  String get planLongRun => 'Langer Lauf';

  @override
  String get planLongRunDesc => 'Locker und gleichmäßig. Ab 60 min Flüssigkeit/Kohlenhydrate.';

  @override
  String get planRunIntervals => 'Lauf-Intervalle';

  @override
  String get planRunIntervalsDesc => '15 min Einlaufen · 6×800 m im 5-km-Tempo, 2 min Trabpause · 10 min Auslaufen';

  @override
  String get planRunTempo => 'Tempolauf';

  @override
  String get planRunTempoDesc => '15 min locker · 20 min an der Schwelle (angenehm hart) · 10 min locker';

  @override
  String get planLongRide => 'Lange Ausfahrt';

  @override
  String get planLongRideDesc => 'Zone 2, Trittfrequenz 85–95. Alle 45 min essen.';

  @override
  String get planRideIntervals => 'VO2max-Intervalle';

  @override
  String get planRideIntervalsDesc => '15 min Einfahren · 5×4 min hart, 4 min locker · 10 min Ausfahren';

  @override
  String get planRideTempo => 'Sweet Spot';

  @override
  String get planRideTempoDesc => '3×12 min bei 88–94 % FTP, 4 min locker dazwischen.';

  @override
  String get planLongSwim => 'Ausdauerschwimmen';

  @override
  String get planLongSwimDesc => 'Durchgehend locker schwimmen, Fokus auf die Atmung.';

  @override
  String get planSwimIntervals => 'Schwimm-Intervalle';

  @override
  String get planSwimIntervalsDesc => '400 Einschwimmen · 10×100 im CSS-Tempo, 15 s Pause · 200 Ausschwimmen';

  @override
  String get planSwimTechnique => 'Technikschwimmen';

  @override
  String get planSwimTechniqueDesc => '300 Einschwimmen · 8×50 Technikübungen · 6×100 gleichmäßig · 200 Ausschwimmen';

  @override
  String get performance => 'Leistung';

  @override
  String get records => 'Rekorde';

  @override
  String get history => 'Verlauf';

  @override
  String get range4w => '4W';

  @override
  String get range3m => '3M';

  @override
  String get range1y => '1J';

  @override
  String get rangeAll => 'Alle';

  @override
  String get time => 'Zeit';

  @override
  String get avgGymDays => 'Ø Gym-Tage / Monat';

  @override
  String get avgDuration => 'Ø Dauer';

  @override
  String get heatmap => 'Trainings-Heatmap';

  @override
  String get weeklyMinutes => 'Minuten pro Woche';

  @override
  String get weeklyDistance => 'Distanz pro Woche';

  @override
  String get notEnoughData => 'Noch nicht genug Daten';

  @override
  String get strengthRecords => 'Kraft-Rekorde';

  @override
  String get noRecordsYet => 'Absolviere eine Gym-Einheit, um deine Rekorde zu sehen.';

  @override
  String get longestDistance => 'Längste Distanz';

  @override
  String get longestDuration => 'Längste Dauer';

  @override
  String get bestPace => 'Beste Pace';

  @override
  String get bestSpeed => 'Bestes Tempo';

  @override
  String get totalDistance => 'Gesamt';

  @override
  String get badges => 'Abzeichen';

  @override
  String get noSessionsYet => 'Noch keine Einheiten. Starte deine erste!';

  @override
  String get deleteSession => 'Einheit löschen?';

  @override
  String get splits => 'Zwischenzeiten';

  @override
  String get compareLast => 'Vergleich zum letzten Mal';

  @override
  String get notes => 'Notizen';

  @override
  String get sharedFromStrive => 'Getrackt mit Strive 💪';

  @override
  String get bodyComposition => 'Körperzusammensetzung';

  @override
  String get entries => 'Einträge';

  @override
  String get logBody => 'Körperwerte eintragen';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get coachTitle => 'Dein KI-Coach';

  @override
  String get coachSub => 'Frag alles zu Training, Erholung oder Ernährung. Die Antworten berücksichtigen dein Profil und deine Trainingsdaten.';

  @override
  String get coachQ1 => 'Wie läuft mein Training? Was sollte ich verbessern?';

  @override
  String get coachQ2 => 'Warum sieht meine Woche so aus?';

  @override
  String get coachQ3 => 'Wie werde ich auf 10 km schneller?';

  @override
  String get coachQ4 => 'Ich habe schlecht geschlafen – soll ich heute trotzdem trainieren?';

  @override
  String get coachQ5 => 'Ich bin krank/müde – was soll ich anpassen?';

  @override
  String get coachDisclaimer => 'KI-Antworten können fehlerhaft sein und ersetzen keine ärztliche Beratung.';

  @override
  String get askCoach => 'Frag deinen Coach …';

  @override
  String get newGoal => 'Neues Ziel';

  @override
  String get editGoal => 'Ziel bearbeiten';

  @override
  String perWeekProgress(int done, int target) {
    return '$done / $target pro Woche';
  }

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Noch $days Tage',
      one: 'Noch 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get eventPassed => 'Wettkampf vorbei';

  @override
  String get onTrack => 'Im Plan';

  @override
  String get behindSchedule => 'Im Rückstand';

  @override
  String get until => 'bis';

  @override
  String get goalTypeWeight => 'Körpergewicht';

  @override
  String get goalTypeDistance => 'Distanz';

  @override
  String get goalTypeFrequency => 'Häufigkeit';

  @override
  String get goalTypeStrength => 'Kraft';

  @override
  String get goalTypeEvent => 'Wettkampf';

  @override
  String get perWeek => 'pro Woche';

  @override
  String get chooseExercise => 'Übung wählen';

  @override
  String get target => 'Zielwert';

  @override
  String get deadlineOptional => 'Stichtag (optional)';

  @override
  String get profile => 'Profil';

  @override
  String get athlete => 'Athlet';

  @override
  String get guestAccount => 'Gastkonto';

  @override
  String get settings => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get system => 'System';

  @override
  String get theme => 'Design';

  @override
  String get dark => 'Dunkel';

  @override
  String get light => 'Hell';

  @override
  String get vibration => 'Vibration';

  @override
  String get vibrationSub => 'Nach Pausen- und Haltetimern und jedem km';

  @override
  String get reminders => 'Erinnerungen';

  @override
  String get trainingReminder => 'Trainings-Erinnerung';

  @override
  String trainingReminderSub(String time) {
    return 'An Trainingstagen um $time';
  }

  @override
  String get reminderTime => 'Uhrzeit';

  @override
  String get notificationsDenied => 'Benachrichtigungen sind in den Systemeinstellungen blockiert.';

  @override
  String trainingReminderTitle(String sport) {
    return 'Heute: $sport';
  }

  @override
  String get integrations => 'Integrationen';

  @override
  String get googleCalendar => 'Google Kalender';

  @override
  String get googleCalendarSub => 'Plan automatisch in einen eigenen „Strive“-Kalender übertragen';

  @override
  String get account => 'Konto';

  @override
  String get upgradeAccount => 'Gastkonto sichern';

  @override
  String get upgradeAccountSub => 'Verknüpfe eine E-Mail, damit deine Daten nicht verloren gehen';

  @override
  String get accountLinked => 'Konto gesichert!';

  @override
  String get logout => 'Abmelden';

  @override
  String get guestLogoutWarning => 'Als Gast gehen deine Daten beim Abmelden verloren.';

  @override
  String get offlineReady => 'funktioniert offline';

  @override
  String get viewFocus => 'Fokus-Ansicht';

  @override
  String get viewTable => 'Tabellen-Ansicht';

  @override
  String get upNext => 'Als Nächstes';

  @override
  String setXofY(int x, int y) {
    return 'Satz $x von $y';
  }

  @override
  String exerciseXofY(int x, int y) {
    return 'Übung $x/$y';
  }

  @override
  String completeSet(int n) {
    return 'Satz $n abschließen';
  }

  @override
  String get nextExercise => 'Nächste Übung';

  @override
  String get workoutComplete => 'Alle Sätze geschafft – stark!';

  @override
  String get superset => 'Supersatz';

  @override
  String get linkSuperset => 'Als Supersatz verbinden';

  @override
  String get unlinkSuperset => 'Aus Supersatz lösen';

  @override
  String get replaceExercise => 'Übung ersetzen';

  @override
  String get warmupSets => 'Aufwärmsätze';

  @override
  String warmupAdded(int n) {
    return '$n Aufwärmsätze hinzugefügt';
  }

  @override
  String get plateCalculator => 'Scheiben';

  @override
  String get plateCalcTitle => 'Scheibenrechner';

  @override
  String get perSide => 'pro Seite';

  @override
  String get barWeight => 'Stange';

  @override
  String notLoadable(String value) {
    return '$value nicht exakt ladbar';
  }

  @override
  String get dropSet => 'Drop-Satz';

  @override
  String get note => 'Notiz';

  @override
  String get setTypeNormal => 'Arbeitssatz';

  @override
  String get setTypeWarmup => 'Aufwärmen';

  @override
  String get setTypeDrop => 'Drop-Satz';

  @override
  String get setTypeFailure => 'Bis zum Versagen';

  @override
  String get rpeHint => 'Wie hart? RPE 10 = keine Wdh. mehr drin, 8 = noch zwei';

  @override
  String progIncrease(String value) {
    return 'Letztes Mal oberes Wdh.-Ende geschafft → heute $value probieren';
  }

  @override
  String get progAddReps => 'Gewicht halten – eine Wiederholung mehr als letztes Mal';

  @override
  String get progHold => 'Gewicht halten und jede Wdh. sauber';

  @override
  String get apply => 'Übernehmen';

  @override
  String get lastTime => 'Letztes Mal';

  @override
  String get undo => 'Rückgängig';

  @override
  String get restHint => 'Durchatmen, etwas trinken, bereit machen.';

  @override
  String get skipRest => 'Pause überspringen';

  @override
  String get translating => 'Wird übersetzt…';

  @override
  String get translatedByAi => 'Von KI übersetzt';

  @override
  String get translationFailed => 'Übersetzung nicht verfügbar – englisches Original';

  @override
  String get showOriginal => 'Original';

  @override
  String get showTranslation => 'Übersetzung zeigen';

  @override
  String get skyClear => 'Klar';

  @override
  String get skyPartly => 'Leicht bewölkt';

  @override
  String get skyCloudy => 'Bewölkt';

  @override
  String get skyFog => 'Nebel';

  @override
  String get skyDrizzle => 'Nieselregen';

  @override
  String get skyRain => 'Regen';

  @override
  String get skySnow => 'Schnee';

  @override
  String get skyStorm => 'Gewitter';

  @override
  String get clothShorts => 'Kurze Hose & T-Shirt';

  @override
  String get clothLongTee => 'Kurze Hose & Langarmshirt';

  @override
  String get clothTights => 'Lange Tight & Langarm, dünne Handschuhe';

  @override
  String get clothJacket => 'Tight, Thermo-Shirt & leichte Jacke, Mütze';

  @override
  String get clothWinter => 'Winter-Tight, Zwiebellook, Handschuhe & Mütze';

  @override
  String get hintStorm => 'Gewitter – heute lieber drinnen trainieren';

  @override
  String hintRainAt(String time) {
    return 'Regen ab $time – vorher los';
  }

  @override
  String get hintHot => 'Heiß – früh los & viel trinken';

  @override
  String get hintCold => 'Kalt – drinnen aufwärmen';

  @override
  String hintBest(String time) {
    return 'Beste Trainingszeit: $time';
  }

  @override
  String get hintIndoor => 'Mäßig draußen – guter Gym-Tag';

  @override
  String get bestTrainingWindow => 'Bestes Trainingsfenster';

  @override
  String rainChanceN(int pct) {
    return '$pct% Regen';
  }

  @override
  String get next24h => 'Nächste 24 Stunden';

  @override
  String get now => 'Jetzt';

  @override
  String get trainingScoreLegend => 'Balken = Bedingungen fürs Training draußen';

  @override
  String get wind => 'Wind';

  @override
  String get humidity => 'Luftfeuchte';

  @override
  String get uvIndex => 'UV-Index';

  @override
  String get uvHigh => 'Hoch – Sonnenschutz';

  @override
  String get uvModerate => 'Mittel';

  @override
  String get uvLow => 'Niedrig';

  @override
  String get airQuality => 'Luftqualität';

  @override
  String get aqiGood => 'Gut';

  @override
  String get aqiModerate => 'Mäßig';

  @override
  String get aqiPoor => 'Schlecht – locker bleiben';

  @override
  String get sunrise => 'Sonnenaufgang';

  @override
  String get sunset => 'Sonnenuntergang';

  @override
  String get whatToWear => 'Was anziehen zum Laufen';

  @override
  String get wearSunscreen => 'Sonnencreme & Kappe';

  @override
  String get wearRainJacket => 'Regenjacke einpacken';

  @override
  String get wearWindproof => 'Winddichte Schicht';

  @override
  String get drinkMore => 'Mehr trinken';

  @override
  String get wearReflective => 'Reflektoren / Stirnlampe';

  @override
  String get next7Days => '7-Tage-Vorhersage';

  @override
  String get today => 'Heute';

  @override
  String get weatherSource => 'Wetterdaten: Open-Meteo.com';

  @override
  String get stepWarmupNote => 'Locker einlaufen';

  @override
  String get stepEasyNote => 'Gesprächstempo – ganze Sätze sprechen möglich';

  @override
  String get stepMpNote => 'Marathon-Zieltempo – kontrolliert';

  @override
  String get stepTempoNote => 'Angenehm hart – nur noch kurze Sätze';

  @override
  String get stepFartlekNote => 'Tempo anziehen – kräftig, aber locker';

  @override
  String get stepIntervalNote => 'Hart – 3–5-km-Renntempo';

  @override
  String get stepStrideNote => 'Schnell und locker, kein Sprint';

  @override
  String get stepBriskWalk => 'Zügiges Gehen';

  @override
  String get stepTalkPace => 'Ganz locker joggen – Plaudern möglich';

  @override
  String get stepZ2RideNote => 'Zone 2 – gleichmäßig, Unterhaltung möglich';

  @override
  String get stepVo2Note => 'Sehr hart – 106–120 % FTP';

  @override
  String get stepSsNote => 'Sweet Spot – 88–94 % FTP';

  @override
  String get stepThresholdNote => 'Schwelle – 95–105 % FTP';

  @override
  String get stepSwimWu => 'Locker, Lagen gemischt';

  @override
  String get stepDrills => 'Technik: Abschlag, Faust, 6er-Beinschlag';

  @override
  String get stepCssNote => 'Im CSS-Tempo – gleichmäßig';

  @override
  String get stepSwimEasyNote => 'Locker, auf lange Züge achten';

  @override
  String get stepSwimEnNote => 'Gleichmäßiges Grundlagentempo';

  @override
  String get wLongRunDesc => 'Baut Grundlagenausdauer und Fettstoffwechsel auf. Locker bleiben – Zeit auf den Beinen zählt, nicht das Tempo.';

  @override
  String get wLongRunMp => 'Langer Lauf mit Renntempo';

  @override
  String get wLongRunMpDesc => 'Lockerer langer Lauf, das letzte Viertel im Zielrenntempo – die wichtigste wettkampfspezifische Einheit.';

  @override
  String get wTempoDesc => 'Schwellenlauf: verschiebt das Tempo, das du eine Stunde halten kannst.';

  @override
  String get wFartlek => 'Fahrtspiel';

  @override
  String get wFartlekDesc => 'Lockerer Lauf mit kurzen Tempoverschärfungen – Tempo ohne viel Ermüdung.';

  @override
  String wIntervals(int reps, int meters) {
    return 'Intervalle $reps × $meters m';
  }

  @override
  String get wIntervalsDesc => 'VO2max-Intervalle im 3–5-km-Renntempo. Trabpause zwischen den Wiederholungen.';

  @override
  String get wMpRun => 'Marathon-Tempolauf';

  @override
  String get wMpRunDesc => 'Durchgehender Block im Marathon-Zieltempo, um den Rhythmus zu verinnerlichen.';

  @override
  String wCruise(int reps) {
    return 'Cruise-Intervalle $reps × 1,6 km';
  }

  @override
  String get wCruiseDesc => 'Schwellentempo mit kurzen Trabpausen – mehr Zeit an der Schwelle bei weniger Belastung (Daniels).';

  @override
  String get wEasyStrides => 'Lockerer Lauf + Steigerungen';

  @override
  String get wEasyStridesDesc => 'Lockerer Lauf, danach kurze lockere Steigerungen für die Laufökonomie.';

  @override
  String get wRecoveryRun => 'Regenerationslauf';

  @override
  String get wEasyDesc => 'Der Großteil deiner Läufe sollte sich so anfühlen – lockerer Umfang baut den Motor.';

  @override
  String wRunWalk(int n, int min) {
    return 'Laufen/Gehen $n × $min min';
  }

  @override
  String get wRunWalkDesc => 'Locker joggen und gehen im Wechsel. Wiederhole die Woche, wenn es schwer war.';

  @override
  String get wLongRideDesc => 'Lange Zone-2-Ausfahrt – das Rückgrat der Radausdauer. Alle 20–30 min essen und trinken.';

  @override
  String wRideVo2(int reps, int min) {
    return 'VO2max $reps × $min min';
  }

  @override
  String get wRideVo2Desc => 'Harte Intervalle mit gleich langer Pause – hebt deine Leistungsdecke.';

  @override
  String wSweetSpot(int reps, int each) {
    return 'Sweet Spot $reps × $each min';
  }

  @override
  String get wSweetSpotDesc => 'Knapp unter der Schwelle – sehr zeiteffizient für die FTP.';

  @override
  String wThreshold(int reps, int each) {
    return 'Schwelle $reps × $each min';
  }

  @override
  String get wThresholdDesc => 'An der FTP – die Leistung, die du etwa eine Stunde halten kannst.';

  @override
  String get wRecoveryRide => 'Regenerationsfahrt';

  @override
  String get wEasyRideDesc => 'Lockere Grundlagenfahrt, gleichmäßige Trittfrequenz 85–95.';

  @override
  String wSwimCss(int n) {
    return 'CSS-Serie $n × 100 m';
  }

  @override
  String get wSwimCssDesc => 'Schwellentraining im CSS-Tempo mit kurzen Pausen.';

  @override
  String get wSwimTechDesc => 'Technik zuerst: Übungen, dann lockere Wiederholungen mit sauberer Technik.';

  @override
  String wSwimEndurance(int reps, int meters) {
    return 'Ausdauer $reps × $meters m';
  }

  @override
  String get wSwimEnduranceDesc => 'Aerobe Serie – gleichmäßiges Tempo, kurze Pausen.';

  @override
  String wGymDesc(int sets, int lo, int hi, int rir) {
    return '$sets Sätze × $lo–$hi Wdh., $rir Wdh. im Tank lassen. Gewicht erhöhen, sobald du in allen Sätzen $hi Wdh. schaffst.';
  }

  @override
  String wGymDeloadDesc(int sets) {
    return 'Deload: $sets Sätze pro Übung, etwa 10 % leichter, nichts bis zur Erschöpfung.';
  }

  @override
  String get wGymConcurrentNote => 'Morgen wichtige Ausdauereinheit – Fokus Oberkörper, Beine leicht halten.';

  @override
  String get setupModeTitle => 'Wie ausführlich soll es sein?';

  @override
  String get setupQuick => 'Schnellstart · ~2 Min.';

  @override
  String get setupQuickSub => 'Ein paar allgemeine Fragen. Dein Plan passt sich an, sobald du trainierst.';

  @override
  String get setupDetailed => 'Ausführlich · ~6 Min.';

  @override
  String get setupDetailedSub => 'Bestzeiten, Wochenumfang, FTP, Schwimmtest, Maximalkraft und Wochenplan – für einen präzisen Plan ab Tag 1.';

  @override
  String get recommended => 'Empfohlen';

  @override
  String get heartRateOptional => 'Herzfrequenz (optional)';

  @override
  String get heartRateHint => 'Ruhepuls: morgens im Bett gemessen. Max-Puls leer lassen zum Schätzen (208 − 0,7 × Alter).';

  @override
  String get restingHr => 'Ruhepuls';

  @override
  String get maxHr => 'Max-Puls';

  @override
  String get sessionLength => 'Zeit pro Einheit';

  @override
  String get weekPlanTitle => 'Deine Trainingswoche';

  @override
  String get weekPlanSub => 'Tippe an, welche Sportart du an welchem Tag machen willst. Dein Plan folgt dieser Struktur.';

  @override
  String get oncePerDay => '1× pro Tag';

  @override
  String get twicePerDay => 'Bis zu 2× pro Tag';

  @override
  String sessionsPerWeekN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Einheiten / Woche',
      one: '1 Einheit / Woche',
    );
    return '$_temp0';
  }

  @override
  String get longDayHint => '★ = Tag für die lange Einheit';

  @override
  String get noRestDayWarning => 'Kein Ruhetag – mindestens ein lockerer oder freier Tag pro Woche wird empfohlen.';

  @override
  String get preferredTime => 'Bevorzugte Trainingszeit';

  @override
  String get morning => 'Morgens';

  @override
  String get midday => 'Mittags';

  @override
  String get evening => 'Abends';

  @override
  String get runSetupTitle => 'Laufen';

  @override
  String get runSetupSub => 'Deine aktuelle Laufform – daraus berechnen wir Pace-Zonen und eine sichere Steigerung.';

  @override
  String get canRun30 => 'Ich kann 30 Min. am Stück laufen';

  @override
  String get canRun30Sub => 'Falls nicht, starten wir mit Laufen/Gehen im Wechsel.';

  @override
  String get raceTimesTitle => 'Aktuelle Bestzeiten (optional)';

  @override
  String get raceTimesHint => 'Aus den letzten ~6 Monaten. Eine reicht – wir berechnen deinen VDOT (Daniels).';

  @override
  String get currentVolume => 'Aktueller Trainingsumfang';

  @override
  String get weeklyKmNow => 'Lauf-km pro Woche';

  @override
  String get longestRun4w => 'Längster Lauf (letzte 4 Wochen)';

  @override
  String get notSure => 'Weiß nicht';

  @override
  String get rideSetupTitle => 'Radfahren';

  @override
  String get rideSetupSub => 'Leistung oder Puls – wir setzen deine Zonen entsprechend.';

  @override
  String get hasPowerMeter => 'Ich habe einen Powermeter / Smart-Trainer';

  @override
  String get hasIndoorTrainer => 'Ich kann drinnen fahren (Rolle)';

  @override
  String get ftpTitle => 'FTP (optional)';

  @override
  String get ftpHint => 'Functional Threshold Power: 95 % eines 20-Min.-Tests.';

  @override
  String get weeklyHoursNow => 'Radstunden pro Woche';

  @override
  String get longestRide4w => 'Längste Ausfahrt (letzte 4 Wochen)';

  @override
  String get swimSetupTitle => 'Schwimmen';

  @override
  String get swimSetupSub => 'Ein kurzer Test ergibt deine kritische Schwimmgeschwindigkeit (CSS) für Pace-Vorgaben.';

  @override
  String get canSwim400 => 'Ich kann 400 m Kraul am Stück';

  @override
  String get cssTitle => 'CSS-Test (optional)';

  @override
  String get cssHint => '400 m Vollgas, Pause, dann 200 m Vollgas.';

  @override
  String cssResult(String pace) {
    return 'Deine CSS: $pace /100 m';
  }

  @override
  String get weeklySwimKm => 'Schwimm-km pro Woche';

  @override
  String get gymSetupTitle => 'Krafttraining';

  @override
  String get gymSetupSub => 'Ausrüstung und Ziel bestimmen Übungen, Wiederholungsbereiche und Steigerung.';

  @override
  String get equipmentTitle => 'Wo trainierst du?';

  @override
  String get equipGym => 'Fitnessstudio';

  @override
  String get equipGymSub => 'Langhanteln, Maschinen, Kabelzug';

  @override
  String get equipHome => 'Zuhause';

  @override
  String get equipHomeSub => 'Kurzhanteln, Bank, evtl. Rack';

  @override
  String get equipBodyweight => 'Eigengewicht';

  @override
  String get equipBodyweightSub => 'Keine Geräte, evtl. Bänder';

  @override
  String get gymGoalTitle => 'Kraft-Ziel';

  @override
  String get general => 'Allgemein';

  @override
  String get oneRmTitle => 'Maximalkraft (optional)';

  @override
  String get oneRmHint => '1RM oder gute Schätzung – für die Startgewichte.';

  @override
  String get liftSquat => 'Kniebeuge';

  @override
  String get liftBench => 'Bankdrücken';

  @override
  String get liftDeadlift => 'Kreuzheben';

  @override
  String get liftOhp => 'Schulterdrücken';

  @override
  String get healthTitle => 'Etwas zu beachten?';

  @override
  String get healthSub => 'Für betroffene Bereiche vermeiden wir riskante Steigerungen.';

  @override
  String get limitKnee => 'Knie';

  @override
  String get limitBack => 'Rücken';

  @override
  String get limitShoulder => 'Schulter';

  @override
  String get limitHip => 'Hüfte';

  @override
  String get limitAnkle => 'Sprunggelenk / Achilles';

  @override
  String get limitHeart => 'Herz / Blutdruck';

  @override
  String get healthDisclaimer => 'Strive ersetzt keine ärztliche Beratung. Bei Schmerzen oder Vorerkrankungen bitte vorher ärztlich abklären.';

  @override
  String get olympicTri => 'Olympische Distanz';

  @override
  String get targetTime => 'Zielzeit';

  @override
  String get targetTimeHint => 'Optional – leer lassen, um einfach stark zu finishen.';

  @override
  String predictedTime(String time) {
    return 'Prognose nach aktueller Form: $time';
  }

  @override
  String get planSetupTitle => 'Dein Plan';

  @override
  String get planSetupSub => 'Wie hart und wie lange? Basierend auf sportwissenschaftlichen Empfehlungen.';

  @override
  String get difficultyTitle => 'Schwierigkeit';

  @override
  String get difficultyHint => 'Im Vergleich zu deinem aktuellen Training.';

  @override
  String get diffEasy => 'Einfach';

  @override
  String get diffEasySub => '+5 % Umfang/Woche, jede 3. Woche eine Entlastungswoche, fast nur lockere Einheiten.';

  @override
  String get diffBalanced => 'Ausgewogen';

  @override
  String get diffBalancedSub => '+8 % Umfang/Woche, jede 4. Woche eine Entlastungswoche, ~80/20 locker/hart.';

  @override
  String get diffChallenging => 'Herausfordernd';

  @override
  String get diffChallengingSub => '+10 % Umfang/Woche, mehr Schlüsseleinheiten – für Erfahrene.';

  @override
  String get planLength => 'Planlänge';

  @override
  String get plan4w => '4 Wochen · schneller Impuls';

  @override
  String get plan8w => '8 Wochen';

  @override
  String get plan12w => '12 Wochen';

  @override
  String get plan16w => '16 Wochen';

  @override
  String get plan20w => '20 Wochen · maximaler Aufbau';

  @override
  String planLengthHint(int lo, int hi) {
    return 'Empfohlen für dein Ziel: $lo–$hi Wochen.';
  }

  @override
  String planToEvent(int weeks) {
    return 'Dein Plan läuft $weeks Wochen bis zum Wettkampf, inklusive Tapering.';
  }

  @override
  String planToEventShort(int weeks, int lo) {
    return 'Nur $weeks Wochen bis zum Wettkampf – empfohlen sind $lo+. Fokus: fit ankommen statt Zeitziel.';
  }

  @override
  String get planScienceNote => 'Pläne folgen u. a. Seiler (80/20), Daniels (VDOT-Paces), Bosquet (Tapering), Schoenfeld (Kraftvolumen). Details in der Planansicht.';

  @override
  String get yourPaceZones => 'Deine Pace-Zonen';

  @override
  String get zoneEasy => 'Locker / lang';

  @override
  String get zoneMarathon => 'Marathon';

  @override
  String get zoneThreshold => 'Schwelle';

  @override
  String get zoneInterval => 'Intervall';

  @override
  String get zoneRepetition => 'Wiederholung';

  @override
  String get hcTileSub => 'Galaxy Watch, Samsung Health, Garmin & mehr';

  @override
  String get hcConnectedShort => 'Verbunden – synchronisiert automatisch';

  @override
  String get hcTitle => 'Galaxy Watch verbinden';

  @override
  String get hcSub => 'Deine Uhr synchronisiert mit Samsung Health, Samsung Health teilt mit Health Connect und Strive liest Einheiten, Puls, Schlaf und Schritte – und schreibt deine Strive-Einheiten zurück.';

  @override
  String get hcUnavailable => 'Health Connect ist auf diesem Gerät nicht verfügbar.';

  @override
  String get hcInstall => 'Health Connect muss zuerst installiert oder aktualisiert werden.';

  @override
  String get hcInstallButton => 'Health Connect installieren';

  @override
  String get hcConnect => 'Mit Health Connect verbinden';

  @override
  String get hcConnected => 'Verbunden!';

  @override
  String get hcDenied => 'Berechtigungen wurden nicht erteilt.';

  @override
  String hcImported(int n) {
    return '$n neue Einheiten importiert';
  }

  @override
  String get hcConnectedInfo => 'Verbunden. Neue Uhr-Einheiten erscheinen automatisch in deinem Verlauf.';

  @override
  String get hcImportedLabel => 'Importiert';

  @override
  String get hcLastSync => 'Letzter Sync';

  @override
  String get hcSyncNow => 'Jetzt synchronisieren';

  @override
  String get hcDisconnect => 'Trennen';

  @override
  String get hcSetupTitle => 'Galaxy Watch 6 einrichten';

  @override
  String get hcStep1 => 'Uhr mit der Galaxy Wearable App koppeln und in Samsung Health anmelden.';

  @override
  String get hcStep2 => 'In Samsung Health: ⋮ → Einstellungen → Health Connect → alle Datentypen freigeben.';

  @override
  String get hcStep3 => 'Oben auf „Verbinden“ tippen und Strive Lesen & Schreiben erlauben.';

  @override
  String get hcStep4 => 'Einheiten wie gewohnt auf der Uhr aufzeichnen – Strive importiert sie beim nächsten App-Start.';

  @override
  String get hcOpenSamsung => 'Samsung Health öffnen';

  @override
  String get hcWhatSynced => 'Was wird synchronisiert?';

  @override
  String get hcWhatSyncedBody => 'Lesen: Einheiten (Laufen, Rad, Schwimmen, Kraft) inkl. Ø/Max-Puls, Distanz und Kalorien, Ruhepuls, HRV, Schlaf, Schritte, Gewicht, Körperfett. Schreiben: Strive-Einheiten und Gewichtseinträge.';

  @override
  String get steps => 'Schritte';

  @override
  String get sleep => 'Schlaf';

  @override
  String get continueWithGoogle => 'Weiter mit Google';

  @override
  String get linkGoogle => 'Google-Konto verknüpfen';

  @override
  String get guidedWorkout => 'Geführte Einheit';

  @override
  String get guidedWorkoutSub => 'Abschnitte mit Zielvorgaben und Sprachansagen';

  @override
  String get music => 'Musik';

  @override
  String get voiceCues => 'Sprachansagen';

  @override
  String get lockScreen => 'Bildschirm sperren';

  @override
  String get skipStep => 'Nächster Abschnitt';

  @override
  String get autoPaused => 'AUTO-PAUSE';

  @override
  String get paused => 'PAUSIERT';

  @override
  String get currentPace => 'Aktuelle Pace';

  @override
  String get currentSpeed => 'Tempo';

  @override
  String get allStepsDone => 'Alle Abschnitte geschafft! Locker auslaufen und dann beenden.';

  @override
  String get onPace => 'Im Ziel';

  @override
  String get tooFast => 'Zu schnell';

  @override
  String get tooSlow => 'Zu langsam';

  @override
  String get left => 'übrig';

  @override
  String freeRunHint(int lo, int hi) {
    return 'Lockerer Lauf? Bleib bei $lo–$hi bpm (Zone 2) – ganze Sätze sprechen sollte gehen.';
  }

  @override
  String get workoutStructure => 'Trainingsaufbau';

  @override
  String get noSplitsYet => 'Zwischenzeiten erscheinen nach dem ersten Kilometer.';

  @override
  String get holdToFinish => 'Halten = Ende';

  @override
  String get holdToUnlock => 'Gedrückt halten zum Entsperren';

  @override
  String get musicSub => 'Öffnet Spotify mit Musik passend zum Trainingstempo.';

  @override
  String musicForNow(String label) {
    return 'Jetzt passend: $label';
  }

  @override
  String get musicEasy => 'Lockerer Lauf';

  @override
  String get musicTempo => 'Tempolauf';

  @override
  String get musicIntervals => 'Intervalle';

  @override
  String get musicPodcasts => 'Podcasts';

  @override
  String get musicPodcastsSub => 'Ideal für lange lockere Läufe';

  @override
  String get musicOwn => 'Meine Playlist';

  @override
  String get musicSetOwn => 'Eigenen Spotify-Playlist-Link festlegen';

  @override
  String get musicChangeOwn => 'Playlist ändern';

  @override
  String get vcGo => 'Los geht\'s!';

  @override
  String get vcAutoPaused => 'Automatische Pause.';

  @override
  String get vcResumed => 'Weiter geht es.';

  @override
  String get vcAllDone => 'Alle Abschnitte geschafft. Stark! Jetzt locker auslaufen.';

  @override
  String get vcSlowDown => 'Etwas langsamer – bleib in deiner Zone.';

  @override
  String get vcSpeedUp => 'Etwas schneller.';

  @override
  String vcKm(int n, String time, String pace) {
    return 'Kilometer $n. Zeit $time. Letzter Kilometer $pace.';
  }

  @override
  String get zConversational => 'Locker';

  @override
  String get zEasyLong => 'Locker';

  @override
  String get zMarathon => 'Zügig';

  @override
  String get zThreshold => 'Schwelle';

  @override
  String get zInterval => 'Intervall';

  @override
  String get zStride => 'Schnell';

  @override
  String get zJog => 'Erholung';

  @override
  String get zWalk => 'Gehen';

  @override
  String get zRecovery => 'Erholung';

  @override
  String get zSprint => 'Sprint';

  @override
  String get zSwimEndurance => 'Grundlage';

  @override
  String get zDrills => 'Technik';

  @override
  String get stepWarmup => 'Aufwärmen';

  @override
  String get stepCooldown => 'Ausklang';

  @override
  String get stepRecovery => 'Erholung';

  @override
  String stepWorkN(int x, int y) {
    return 'Intervall $x/$y';
  }

  @override
  String get stepWork => 'Hauptteil';

  @override
  String get stepSteady => 'Dauerlauf';

  @override
  String get phaseBase => 'Grundlagenphase';

  @override
  String get phaseBuild => 'Aufbauphase';

  @override
  String get phasePeak => 'Spitzenphase';

  @override
  String get phaseTaper => 'Tapering';

  @override
  String get phaseRecovery => 'Entlastungswoche';

  @override
  String get keySession => 'Schlüsseleinheit';

  @override
  String get viewSession => 'Einheit ansehen';

  @override
  String get fitnessForm => 'Fitness & Form';

  @override
  String get fitness => 'Fitness';

  @override
  String get fatigue => 'Ermüdung';

  @override
  String get form => 'Form';

  @override
  String get formFresh => 'Frisch – bereit für Wettkampf oder Schlüsseleinheit';

  @override
  String get formNeutral => 'Ausgeglichen – Fitness wird gehalten';

  @override
  String get formProductive => 'Produktives Training – Fitness wird aufgebaut';

  @override
  String get formOverload => 'Hohe Ermüdung – Erholung einplanen';

  @override
  String get fitnessFormHint => 'Fitness = Belastung der letzten 42 Tage, Ermüdung = 7 Tage, Form = Differenz (Banister-Modell).';

  @override
  String get bestEfforts => 'Lauf-Bestleistungen';

  @override
  String get racePredictions => 'Wettkampfprognose';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get middleDistance => 'Mitteldistanz (70.3)';

  @override
  String get maxReps => 'Max. Wdh.';

  @override
  String get roundLap => 'Runde';

  @override
  String get linkGoogleSub => 'Künftig mit Google anmelden – deine Daten bleiben erhalten';

  @override
  String wGymTimeCapNote(int min) {
    return 'Nur $min min Zeit: pro Übung einen Satz weniger oder die letzte Übung weglassen.';
  }

  @override
  String get wShakeout => 'Lockerer Auftakt';

  @override
  String get wShakeoutDesc => '15 min ganz locker plus ein paar Steigerungen – nur lockern, mehr nicht. Lege heute Abend deine Wettkampfsachen bereit.';

  @override
  String wRace(String name) {
    return 'Wettkampf: $name';
  }

  @override
  String get wRaceDesc => 'Kontrolliert starten, Rhythmus finden, stark finishen. Viel Erfolg!';

  @override
  String wRaceGoalDesc(String time) {
    return 'Zielzeit $time. Kontrolliert starten (erster km nicht schneller als Zieltempo), stark finishen. Viel Erfolg!';
  }

  @override
  String get stepRaceNote => 'Wettkampftempo – gleichmäßig einteilen';

  @override
  String get intensityRace => 'Wettkampf';

  @override
  String gcalConnectedSub(String account) {
    return 'Verbunden · $account';
  }

  @override
  String get gcalHeroTitle => 'Dein Plan im Google Kalender';

  @override
  String get gcalHeroSub => 'Strive legt einen eigenen Kalender „Strive“ an und hält ihn automatisch aktuell. Deine anderen Termine werden nie gelesen.';

  @override
  String get gcalConnect => 'Google Kalender verbinden';

  @override
  String get gcalDisconnect => 'Trennen';

  @override
  String get gcalSyncNow => 'Jetzt synchronisieren';

  @override
  String get gcalSyncing => 'Synchronisiere…';

  @override
  String get gcalAccount => 'Google-Konto';

  @override
  String get gcalLastSync => 'Letzter Abgleich';

  @override
  String get gcalEvents => 'Termine';

  @override
  String get gcalAutoInfo => 'Automatische Synchronisierung aktiv – Änderungen an deinem Plan erscheinen wenige Sekunden später im Google Kalender.';

  @override
  String gcalSynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einheiten synchronisiert',
      one: '1 Einheit synchronisiert',
    );
    return '$_temp0';
  }

  @override
  String get gcalConnectedToast => 'Google Kalender verbunden';

  @override
  String get gcalDisconnectTitle => 'Google Kalender trennen?';

  @override
  String get gcalDisconnectBody => 'Strive aktualisiert den Kalender dann nicht mehr. Soll der Kalender „Strive“ mit allen Terminen auch aus deinem Google-Konto gelöscht werden?';

  @override
  String get gcalDeleteCalendar => 'Kalender löschen';

  @override
  String get gcalKeepCalendar => 'Kalender behalten';

  @override
  String get gcalDisconnected => 'Google Kalender getrennt';

  @override
  String get gcalHowTitle => 'So funktioniert es';

  @override
  String get gcalHow1 => 'Strive erhält nur Zugriff auf Kalender, die es selbst angelegt hat – deine anderen Kalender und Termine bleiben unsichtbar.';

  @override
  String gcalHow2(String time) {
    return 'Einheiten der letzten 7 Tage bis 6 Monate im Voraus werden zu deiner bevorzugten Trainingszeit ($time) eingetragen.';
  }

  @override
  String get gcalHow3 => 'Zum Ausblenden einfach den Kalender „Strive“ im Google Kalender abwählen – die Synchronisierung läuft im Hintergrund weiter.';

  @override
  String get gcalHow4 => 'Änderungen im Google Kalender werden beim nächsten Abgleich überschrieben – bearbeite deine Einheiten in Strive.';

  @override
  String get gcalOpen => 'Google Kalender öffnen';

  @override
  String get gcalReconnect => 'Erneut verbinden';

  @override
  String get gcalErrApiDisabled => 'Die Google Calendar API ist für diese App noch nicht aktiviert. Der Entwickler muss sie in der Google Cloud Console aktivieren (Projekt strive-fitness-app).';

  @override
  String get gcalErrAuth => 'Der Google-Zugriff ist abgelaufen oder wurde widerrufen. Bitte erneut verbinden.';

  @override
  String get gcalErrOffline => 'Keine Verbindung zu Google. Strive versucht es automatisch erneut.';

  @override
  String get gcalErrRateLimit => 'Google begrenzt gerade die Anfragen. Bitte in ein paar Minuten erneut versuchen.';

  @override
  String gcalErrGeneric(String detail) {
    return 'Synchronisierung fehlgeschlagen: $detail';
  }

  @override
  String get gcalCalendarDescription => 'Trainingsplan aus der Strive-App. Wird automatisch verwaltet – Änderungen hier werden überschrieben.';

  @override
  String get gcalStructure => 'Ablauf';

  @override
  String get gcalEventFooter => 'Aus Strive synchronisiert – bearbeite diese Einheit in der App.';

  @override
  String get planSettings => 'Planeinstellungen';

  @override
  String get editPlanSettings => 'Planeinstellungen bearbeiten';

  @override
  String get editPlanSettingsSub => 'Sportarten, Woche, Zeiten, Sportdaten, Ziel – danach neuer Plan';

  @override
  String get editProfileSub => 'Name, Körperdaten, Erfahrung, Gesundheit';

  @override
  String get timeTitle => 'Zeit pro Trainingstag';

  @override
  String get timeHint => 'Die maximale Zeit, die du an einem Trainingstag hast – inklusive Ein- und Auslaufen. Jede Einheit wird so geplant, dass sie hineinpasst.';

  @override
  String get timeLongDayHint => 'An deinem Tag für lange Einheiten (★) plant Strive bis zu 2 h ein, außer du legst den Tag selbst fest.';

  @override
  String get timePerDay => 'Pro Tag festlegen (optional)';

  @override
  String timeCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage individuell festgelegt',
      one: '1 Tag individuell festgelegt',
    );
    return '$_temp0';
  }

  @override
  String get timeDefault => 'Zurück auf Standard';

  @override
  String get recTitle => 'Empfehlung für dich';

  @override
  String get recSub => 'Basierend auf Level, Ziel und Fokus. Ruhetage bleiben bewusst frei – dann passt sich dein Körper an.';

  @override
  String recPerWeek(int count) {
    return '$count× / Woche';
  }

  @override
  String get recAuto => 'Woche automatisch planen';

  @override
  String get recApplied => 'Woche geplant – passe sie gern an.';

  @override
  String get recActive => 'Empfehlung übernommen';

  @override
  String recDays(int count) {
    return 'Empfohlen: $count Trainingstage';
  }

  @override
  String get recAutoDays => 'Empfehlung übernehmen';

  @override
  String get splitTitle => 'Trainingssplit';

  @override
  String get splitHint => 'Wie deine Gym-Einheiten aufgeteilt werden. Ideal: jeder Muskel etwa 2× pro Woche.';

  @override
  String get splitAuto => 'Automatisch';

  @override
  String splitAutoSub(String name) {
    return 'Aktuell: $name – passt sich deinen Trainingstagen an';
  }

  @override
  String get splitFullbody => 'Ganzkörper';

  @override
  String get splitFullbodySub => 'Ganzer Körper in jeder Einheit · ideal für 2–3 Tage';

  @override
  String get splitUpperLower => 'Oberkörper / Unterkörper';

  @override
  String get splitUpperLowerSub => 'Abwechselnd Ober- und Unterkörper · ideal für 4 Tage';

  @override
  String get splitPpl => 'Push / Pull / Beine';

  @override
  String get splitPplSub => 'Drücken, Ziehen, Beine · ideal für 3 oder 6 Tage';

  @override
  String get splitUlppl => 'Ober/Unter + PPL';

  @override
  String get splitUlpplSub => 'Mischung aus beidem · ideal für 5 Tage';

  @override
  String get splitBro => 'Bro-Split';

  @override
  String get splitBroSub => 'Eine Muskelgruppe pro Tag · 5 Tage';

  @override
  String splitFreq(String value) {
    return 'Jeder Muskel ca. $value× pro Woche bei deinen Tagen';
  }

  @override
  String get splitBroWarning => 'Jeder Muskel nur 1× pro Woche. Bei gleichem Wochenvolumen bringt 2× pro Woche meist etwas mehr Muskelaufbau (Schoenfeld 2016) – okay, wenn es dir Spaß macht.';

  @override
  String splitForDays(int count) {
    return 'Optimal bei $count Tagen';
  }

  @override
  String get splitHomeNote => 'Bei Training zuhause oder mit Eigengewicht nutzt Strive Ganzkörper-Programme (2 im Wechsel).';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get folderNameHint => 'z. B. Sommerform';

  @override
  String get folderExists => 'Ein Ordner mit diesem Namen existiert bereits.';

  @override
  String get sortPrograms => 'Ordner & Programme sortieren';

  @override
  String get sortHint => 'Ziehe Ordner und Programme am Griff, um sie neu anzuordnen.';

  @override
  String get addBuiltinPrograms => 'Standardprogramme hinzufügen';

  @override
  String get addBuiltinProgramsSub => 'Wissenschaftlich fundierte Programme für jeden Split plus strukturierte Lauf-, Rad- und Schwimmeinheiten.';

  @override
  String get builtinsComplete => 'Du hast bereits alle Standardprogramme.';

  @override
  String programsAdded(int count) {
    return '$count Programme hinzugefügt';
  }

  @override
  String deleteFolderTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteFolderEmpty => 'Der Ordner ist leer.';

  @override
  String deleteFolderBody(int count) {
    return 'Der Ordner enthält $count Programme. Behalten (ohne Ordner) oder alles löschen?';
  }

  @override
  String get deleteFolderKeep => 'Programme behalten';

  @override
  String get deleteFolderAll => 'Alles löschen';

  @override
  String programsCount(int count) {
    return '$count Programme';
  }

  @override
  String get folderEmpty => 'Noch keine Programme – füge eins über das Menü hinzu.';

  @override
  String get duplicate => 'Duplizieren';

  @override
  String get copy => 'Kopie';

  @override
  String get moveToFolder => 'In Ordner verschieben';

  @override
  String stepsCount(int count) {
    return '$count Abschnitte';
  }

  @override
  String get addSection => 'Abschnitt';

  @override
  String get addRepeat => 'Wiederholungen';

  @override
  String get editSection => 'Abschnitt bearbeiten';

  @override
  String get byTime => 'Zeit';

  @override
  String get byDistance => 'Distanz';

  @override
  String get discardChanges => 'Änderungen verwerfen?';

  @override
  String setsN(int count) {
    return '$count Sätze';
  }

  @override
  String get structuredWorkout => 'Strukturiert';

  @override
  String get structuredWorkoutSub => 'Phasen mit Zielen – während des Trainings Schritt für Schritt geführt (Sprache, Pace/Watt/Puls).';

  @override
  String get freeWorkoutSub => 'Nur ein Zeit- oder Distanzziel, ohne Abschnitte.';

  @override
  String get supersetLinked => 'Verbunden – hier tippen zum Trennen';

  @override
  String get repRange => 'Wiederholungsbereich';

  @override
  String get repRangeHint => 'Doppelte Progression: Wiederholungen steigern, bis du bei allen Sätzen oben im Bereich bist – dann mehr Gewicht.';

  @override
  String get exerciseLoadError => 'Übungen konnten nicht geladen werden.';

  @override
  String vcStepN(int x, int y) {
    return 'Intervall $x von $y';
  }

  @override
  String vcSplitRide(int n, String time, int km, String speed) {
    return 'Kilometer $n. Zeit $time. Letzte $km Kilometer mit $speed.';
  }

  @override
  String vcSplitSwim(int n, String time, String pace) {
    return 'Kilometer $n. Zeit $time. Pace $pace.';
  }

  @override
  String vcKmh(String speed) {
    return '$speed Kilometer pro Stunde';
  }

  @override
  String vcPer100m(String pace) {
    return '$pace pro 100 Meter';
  }

  @override
  String vcPaceRange100(String a, String b) {
    return '$a bis $b pro 100 Meter';
  }

  @override
  String vcPowerRange(int lo, int hi) {
    return '$lo bis $hi Watt';
  }

  @override
  String vcHrRange(int lo, int hi) {
    return 'Puls $lo bis $hi';
  }

  @override
  String get vcAllDoneRide => 'Alle Abschnitte geschafft. Stark! Jetzt locker ausrollen.';

  @override
  String get vcAllDoneSwim => 'Alle Abschnitte geschafft. Stark! Jetzt locker ausschwimmen.';

  @override
  String get allStepsDoneRide => 'Alle Abschnitte geschafft! Locker ausrollen und dann beenden.';

  @override
  String get allStepsDoneSwim => 'Alle Abschnitte geschafft! Locker ausschwimmen und dann beenden.';

  @override
  String freeRideHint(int lo, int hi) {
    return 'Lockere Ausfahrt? Bleib bei $lo–$hi bpm (Zone 2) – du solltest dich gut unterhalten können.';
  }

  @override
  String get stepRest => 'Pause';

  @override
  String get stepSteadyRide => 'Grundlagenfahrt';

  @override
  String get stepSteadySwim => 'Gleichmäßig schwimmen';

  @override
  String get stepDrillsTitle => 'Technik';

  @override
  String get zThresholdRide => 'Schwelle';

  @override
  String get lengthBtn => 'Bahn';

  @override
  String get lengths => 'Bahnen';

  @override
  String nLengths(int lengths) {
    String _temp0 = intl.Intl.pluralLogic(
      lengths,
      locale: localeName,
      other: '$lengths Bahnen',
      one: '1 Bahn',
    );
    return '$_temp0';
  }

  @override
  String get undoLength => 'Rückgängig';

  @override
  String get lengthUndone => 'Letzte Bahn entfernt';

  @override
  String get lastLength => 'Letzte Bahn';

  @override
  String get pace100 => 'Pace /100 m';

  @override
  String get avgPace100 => 'Ø /100 m';

  @override
  String get maxSpeed => 'Max. Tempo';

  @override
  String get workoutLeft => 'Noch gesamt';

  @override
  String get section => 'Abschnitt';

  @override
  String get poolTapHint => 'Tippe bei jedem Anschlag auf BAHN.';

  @override
  String get noLengthsYet => 'Deine Bahnen erscheinen hier nach dem ersten Tippen.';

  @override
  String get keySessionSub => 'Wichtige Einheit der Woche – Strive hält harte Tage auseinander.';

  @override
  String get workoutPhases => 'Ablauf';

  @override
  String get planDone => 'Erledigt';

  @override
  String get perSport => 'Pro Sportart';

  @override
  String get recoveryTitle => 'Erholung & Belastung';

  @override
  String get load7d => 'Belastung 7 Tage';

  @override
  String get load28d => 'Ø Woche (28 T)';

  @override
  String get daysInARow => 'Tage am Stück';

  @override
  String get recoveryHowTitle => 'So funktioniert es';

  @override
  String get recoveryHowText => 'Jedes Training bekommt einen Belastungswert (Dauer × Intensität, aus RPE oder Puls). Strive vergleicht die letzten 7 Tage mit deiner Durchschnittswoche der letzten 28 Tage (Acute:Chronic Workload Ratio, Gabbett 2016). Zwischen 0,8 und 1,3 baust du Fitness bei geringem Verletzungsrisiko auf; über 1,5 steigt das Risiko deutlich – plane einen lockeren Tag. Fitness, Ermüdung und Form folgen dem Banister-Modell: Form = Fitness − Ermüdung.';

  @override
  String nWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einheiten',
      one: '1 Einheit',
    );
    return '$_temp0';
  }

  @override
  String sessionN(int n) {
    return 'Einheit $n';
  }

  @override
  String get byDay => 'Tag für Tag';

  @override
  String get planExercisesHint => 'Änderungen gelten nur für diese Einheit – das Programm bleibt unverändert.';

  @override
  String planExercisesCustom(String name) {
    return 'Für diese Einheit angepasst (Programm: $name).';
  }

  @override
  String get saveToProgram => 'Ins Programm übernehmen';

  @override
  String savedToProgram(String name) {
    return 'In „$name“ gespeichert';
  }

  @override
  String get resetToProgram => 'Zurücksetzen';

  @override
  String get adjustExercises => 'Übungen anpassen';

  @override
  String get zSwimEasy => 'Locker';

  @override
  String get zEndurance => 'Grundlage';

  @override
  String get zCss => 'CSS-Tempo';

  @override
  String get zTempo => 'Tempo';

  @override
  String get zoneInfoTitle => 'Intensitätszonen';

  @override
  String get zoneInfoRun => 'Die Tempi basieren auf deinen Wettkampfzeiten (VDOT nach Jack Daniels). Der Großteil deines Laufens – etwa 80 % – sollte locker sein; die schnellen Zonen setzt du kurz und gezielt ein.';

  @override
  String get zoneInfoRide => 'Die Wattbereiche sind Prozent deiner FTP (die Leistung, die du etwa eine Stunde halten kannst). Ohne Wattmesser fährst du nach Puls und Gefühl.';

  @override
  String get zoneInfoSwim => 'Die Zeiten pro 100 m basieren auf deiner kritischen Schwimmgeschwindigkeit (CSS, aus einem 400-m- und 200-m-Test).';

  @override
  String get zoneInfoEstimated => '≈-Werte sind aus deinem Level geschätzt – trage in den Planeinstellungen einen Testwert ein, dann werden sie genau.';

  @override
  String get zfVeryEasy => 'RPE 1–2 · sehr leicht';

  @override
  String get zfEasy => 'RPE 3–4 · ganze Sätze';

  @override
  String get zfDrills => 'Fokus auf Technik';

  @override
  String get zfModerate => 'RPE 5–6 · kurze Sätze';

  @override
  String get zfHard => 'RPE 7–8 · einzelne Worte';

  @override
  String get zfVeryHard => 'RPE 8–9 · kein Sprechen';

  @override
  String get zfMax => 'RPE 9–10 · schnell & locker';

  @override
  String get zdRunRec => 'Gehen oder ganz langsames Traben zwischen harten Abschnitten und zum Einlaufen. Der Puls darf sinken.';

  @override
  String get zdRunEasy => 'Dein Alltagstempo: entspannt, du kannst dich in ganzen Sätzen unterhalten. Baut die Grundlagenausdauer auf – für lockere und lange Läufe.';

  @override
  String get zdRunSteady => 'Kontrolliert, aber mit Zug – etwa dein Marathontempo. Für zügige Abschnitte am Ende langer Läufe.';

  @override
  String get zdRunThreshold => '„Angenehm hart“ – ein Tempo, das du etwa eine Stunde halten könntest. Tempodauerläufe und Schwellenintervalle heben deine Laktatschwelle.';

  @override
  String get zdRunInterval => 'Etwa dein 3–5-km-Wettkampftempo. Abschnitte von 2–5 Minuten mit Trabpausen verbessern deine VO2max.';

  @override
  String get zdRunSprint => 'Kurze, schnelle, aber lockere Abschnitte (Steigerungen, 10–30 s) mit voller Erholung. Verbessert Laufökonomie und Technik.';

  @override
  String get zdRideRec => 'Locker kurbeln – zum Ein- und Ausfahren und für Erholungsfahrten.';

  @override
  String get zdRideEndurance => 'Die Basis im Radtraining: lange, gleichmäßige Fahrten in einem Tempo, das du stundenlang halten kannst.';

  @override
  String get zdRideSweetSpot => 'Knapp unter der Schwelle: fordernd, aber 10–40 Minuten durchhaltbar. Sehr zeiteffizient, um die FTP zu steigern.';

  @override
  String get zdRideThreshold => 'Rund um deine FTP – die Belastung eines einstündigen Zeitfahrens. Blöcke von 8–20 Minuten.';

  @override
  String get zdRideVo2 => 'Sehr harte Abschnitte von 2–6 Minuten, die deine maximale Sauerstoffaufnahme fordern.';

  @override
  String get zdRideSprint => 'Kurze, maximale Antritte (bis 30 s) für Kraft und Spritzigkeit, mit langen Pausen.';

  @override
  String get zdSwimEasy => 'Locker und entspannt – zum Ein- und Ausschwimmen und in Pausen. Auf lange Züge und ruhige Atmung achten.';

  @override
  String get zdSwimDrills => 'Technikübungen: Übungen, die einen Teil der Bewegung isolieren (Armzug, Wasserlage, Rotation, Atmung). Das Tempo ist egal – schwimm langsam und sauber. Die Übungen findest du unten unter „Technikübungen“.';

  @override
  String get zdSwimEndurance => 'Gleichmäßiges Grundlagenschwimmen, einige Sekunden pro 100 m langsamer als CSS. Die Hauptzone für längere Serien.';

  @override
  String get zdSwimCss => 'Deine kritische Schwimmgeschwindigkeit – etwa dein 1500-m-Wettkampftempo. Hart, aber gleichmäßig, mit kurzen Pausen (10–20 s).';

  @override
  String get zdSwimSprint => 'Kurze, schnelle Bahnen (25–50 m) mit langen Pausen für Schnelligkeit und Kraft.';

  @override
  String get swimDrillsTitle => 'Technikübungen';

  @override
  String get swimDrillsIntro => 'In einem Technikblock schwimmst du statt normalem Kraul diese Übungen, z. B. 50 m Übung / 50 m Kraul im Wechsel. Schwimm langsam und konzentriere dich pro Bahn auf eine Sache.';

  @override
  String get drillCatchupName => 'Abschlagschwimmen';

  @override
  String get drillCatchupHow => 'Ein Arm bleibt vorne gestreckt, bis der andere ihn „abschlägt“ – erst dann beginnt er seinen Zug.';

  @override
  String get drillCatchupWhy => 'Längerer Zug, besseres Gleiten und Timing.';

  @override
  String get drillFingertipName => 'Fingerspitzen ziehen';

  @override
  String get drillFingertipHow => 'In der Rückholphase ziehst du die Fingerspitzen von der Hüfte bis zum Kopf über die Wasseroberfläche.';

  @override
  String get drillFingertipWhy => 'Hoher Ellbogen und lockere Armrückführung.';

  @override
  String get drillSideKickName => '6-1-6 Seitlage';

  @override
  String get drillSideKickHow => '6 Beinschläge in Seitlage (unterer Arm nach vorne gestreckt), ein Armzug, 6 Beinschläge auf der anderen Seite.';

  @override
  String get drillSideKickWhy => 'Wasserlage, Rotation und ruhige Atmung.';

  @override
  String get drillSingleArmName => 'Einarmig';

  @override
  String get drillSingleArmHow => 'Ein Arm bleibt vorne, der andere schwimmt allein; pro Bahn wechseln.';

  @override
  String get drillSingleArmWhy => 'Sauberer Unterwasserzug und Rotation zur Atemseite.';

  @override
  String get drillFistName => 'Faustschwimmen';

  @override
  String get drillFistHow => 'Kraul mit geschlossenen Fäusten; auf den letzten 10 m die Hände wieder öffnen.';

  @override
  String get drillFistWhy => 'Du lernst, mit dem ganzen Unterarm zu ziehen (früher, senkrechter Unterarm).';

  @override
  String get drillScullName => 'Wriggen (Sculling)';

  @override
  String get drillScullHow => 'In Bauchlage bewegst du die Hände in kleinen Achten vor dem Kopf und kommst so voran.';

  @override
  String get drillScullWhy => 'Wassergefühl und kräftiges Wasserfassen.';

  @override
  String drillsNote(String a, String b) {
    return '$a / $b – im Wechsel 50 m Übung, 50 m Kraul';
  }

  @override
  String intensityAuto(String name) {
    return '$name (aus dem Aufbau)';
  }

  @override
  String get showDrills => 'Übungen anzeigen';

  @override
  String streakWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen in Folge',
      one: '1 Woche in Folge',
    );
    return '$_temp0';
  }

  @override
  String get streakThisWeek => 'Diese Woche';

  @override
  String streakWeekDone(int done, int target) {
    return 'Ziel erreicht: $done von $target Trainingstagen – diese Woche zählt!';
  }

  @override
  String streakWeekLeft(int done, int target, int count) {
    return '$done von $target Trainingstagen – noch $count, dann zählt die Woche.';
  }

  @override
  String get streakLastWeeks => 'Letzte 8 Wochen';

  @override
  String get streakHow => 'Eine Woche zählt, wenn du an so vielen Tagen trainierst wie geplant. Mit Trainingsplan ist das Ziel die Anzahl der Tage mit geplanten Einheiten in dieser Woche (zwei Einheiten an einem Tag zählen als ein Tag), ohne Plan deine Anzahl Trainingstage. Die laufende Woche unterbricht deinen Streak nie – sie wird gezählt, sobald du das Ziel erreichst.';

  @override
  String get showPastWeeks => 'Vergangene Wochen';

  @override
  String loadSuggestion(String load) {
    return 'Vorschlag: $load';
  }

  @override
  String loadApprox(String weight, int reps) {
    return '≈ $weight × $reps';
  }

  @override
  String loadApproxPerHand(String weight, int reps) {
    return '≈ $weight × $reps pro Hand';
  }

  @override
  String loadBodyweight(int reps) {
    return 'Körpergewicht × $reps';
  }

  @override
  String loadBodyweightPlus(String weight, int reps) {
    return 'Körpergewicht +$weight × $reps';
  }

  @override
  String get loadSrcHistory => 'aus deiner letzten Einheit';

  @override
  String get loadSrcIncrease => 'letztes Mal alle Wiederholungen geschafft – mehr Gewicht';

  @override
  String get loadSrcAddReps => 'aus deiner letzten Einheit – schaff eine Wiederholung mehr';

  @override
  String get loadSrcDeload => 'letztes Mal war hart – etwas leichter';

  @override
  String get loadSrcBreak => 'nach deiner Pause etwas leichter';

  @override
  String get loadSrcOneRm => 'aus deinem 1RM im Setup';

  @override
  String get loadSrcEstimate => 'geschätzt aus Körpergewicht – passe es an';

  @override
  String get loadPhaseLighter => 'Entlastungswoche';

  @override
  String get loadTaperLighter => 'Taper-Woche';

  @override
  String get scoreLegendTitle => 'Bedingungen fürs Training draußen';

  @override
  String get scoreGood => 'Gut';

  @override
  String get scoreFair => 'Mäßig';

  @override
  String get scorePoor => 'Schlecht';

  @override
  String get scoreHowTitle => 'So entsteht der Wert';

  @override
  String get scoreHowIntro => 'Jede Stunde bekommt einen Wert von 0 bis 100 fürs Ausdauertraining draußen. Er startet bei 100 und verliert Punkte für:';

  @override
  String get scoreHowTemp => 'Gefühlte Temperatur außerhalb von 7–16 °C (ideal zum Laufen): −3,5 je °C kälter, −4,5 je °C wärmer';

  @override
  String get scoreHowRain => 'Regen: Regenwahrscheinlichkeit und erwartete Menge';

  @override
  String get scoreHowWind => 'Wind über 20 km/h';

  @override
  String get scoreHowUv => 'UV-Index über 6';

  @override
  String get scoreHowDark => 'Dunkelheit (−18)';

  @override
  String get scoreHowStorm => 'Gewitter (−40)';

  @override
  String get scoreHowLevels => 'Gut ab 70, mäßig ab 45, darunter lieber drinnen trainieren.';

  @override
  String get streakSub => 'mit erreichtem Wochenziel';

  @override
  String wSwimCssSet(int n, int meters) {
    return 'CSS-Serie $n × $meters m';
  }

  @override
  String complianceGreen(int pct) {
    return 'Wie geplant absolviert ($pct % vom Plan)';
  }

  @override
  String complianceYellow(int pct) {
    return 'Absolviert, teilweise abweichend ($pct % vom Plan)';
  }

  @override
  String complianceOrange(int pct) {
    return 'Absolviert, stark abweichend ($pct % vom Plan)';
  }

  @override
  String get complianceDone => 'Absolviert';

  @override
  String get complianceMissed => 'Verpasst';

  @override
  String get compliancePlanned => 'Geplant';

  @override
  String get complianceSkipped => 'Übersprungen';

  @override
  String planCompletion(int pct) {
    return 'Plan erfüllt zu $pct %';
  }

  @override
  String get weightMinus => 'Gewicht verringern';

  @override
  String get weightPlus => 'Gewicht erhöhen';

  @override
  String get previousWorkout => 'Vorherige Einheit';

  @override
  String get nextWorkout => 'Nächste Einheit';

  @override
  String get avgHrShort => 'Ø Puls';

  @override
  String get caloriesLabel => 'Kalorien';

  @override
  String recordedWith(String source) {
    return 'Aufgezeichnet mit $source';
  }

  @override
  String get sessionGone => 'Diese Einheit gibt es nicht mehr.';

  @override
  String adjustWeekBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n geplante Einheiten verpasst – Woche anpassen?',
      one: '1 geplante Einheit verpasst – Woche anpassen?',
    );
    return '$_temp0';
  }

  @override
  String get adjustWeekTitle => 'Woche anpassen';

  @override
  String get adjustWeekIntro => 'Schlüsseleinheiten wandern auf einen freien Tag dieser Woche – nie direkt neben eine andere Schlüsseleinheit. Lockere Einheiten musst du nicht nachholen: aufgestaute Umfänge schaden mehr, als sie bringen.';

  @override
  String adjustReplaces(String title) {
    return 'Ersetzt $title';
  }

  @override
  String get adjustDropped => 'Entfällt – muss nicht nachgeholt werden';

  @override
  String get adjustNoRoom => 'Entfällt – diese Woche kein freier Tag ohne Schlüsseleinheit daneben';

  @override
  String get adjustProtected => 'Entfällt – Entlastungs-/Taperwoche bleibt locker';

  @override
  String get adjustDone => 'Woche angepasst';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String wTriLegs(String swim, String bike, String run) {
    return 'Schwimmen $swim km · Rad $bike km · Laufen $run km';
  }

  @override
  String get editSession => 'Einheit bearbeiten';

  @override
  String get durationHms => 'Dauer (h:mm:ss oder mm:ss)';

  @override
  String get invalidDuration => 'Gib die Dauer als h:mm:ss oder in Minuten ein.';

  @override
  String get rpeNotSet => 'nicht angegeben';

  @override
  String get sessionCorrected => 'Einheit aktualisiert';

  @override
  String get editSessionHint => 'Korrigiere fehlerhafte Messungen oder Eingaben. Aufgezeichnete Strecke und Splits bleiben erhalten.';

  @override
  String get deleted => 'Gelöscht';

  @override
  String get supersetHint => 'Übungen abwechseln – kurzer Wechsel, volle Pause nach jeder Runde';

  @override
  String get supersetMax => 'Ein Supersatz hat höchstens 3 Übungen.';

  @override
  String get supersetSwitch => 'Übung wechseln';

  @override
  String get supersetSwitchHint => 'Kurze Pause – dann direkt weiter mit der nächsten Übung des Supersatzes.';

  @override
  String get bodyweight => 'Körpergewicht';

  @override
  String get bodyweightShort => 'Körpergew.';

  @override
  String get bodyweightHint => 'Gewicht = Zusatzlast zu deinem Körpergewicht (negativ = Unterstützung).';

  @override
  String get addedWeight => 'Zusatzgewicht';

  @override
  String targetLoad(String load, int lo, int hi) {
    return 'Ziel: $load · $lo–$hi Wdh.';
  }

  @override
  String targetToday(String list) {
    return 'Heute: $list Wdh.';
  }

  @override
  String loadWeightApprox(String weight) {
    return '≈ $weight';
  }

  @override
  String loadWeightPerHand(String weight) {
    return '≈ $weight pro Hand';
  }

  @override
  String get loadSrcHold => 'Gewicht halten und alle Ziel-Wiederholungen schaffen';

  @override
  String get loadSrcStall => '3 Einheiten ohne Fortschritt – etwas leichter, dann wieder steigern';

  @override
  String get loadSrcIncreaseBw => 'alle Wiederholungen geschafft – etwas Zusatzgewicht (Gürtel oder Weste)';

  @override
  String get loadSrcMoreReps => 'alle Wiederholungen geschafft – jetzt mehr Wiederholungen';

  @override
  String get loadTotal => 'gesamt';

  @override
  String get quickMinOneDay => 'Wähle mindestens einen Trainingstag';

  @override
  String quickDaysCapped(int n, int total) {
    return 'Dein Plan nutzt $n deiner $total Tage – die übrigen bleiben Ruhetage, damit du dich zwischen den Einheiten erholst.';
  }

  @override
  String get wCrossRide => 'Lockere Radeinheit statt Lauf';

  @override
  String get wCrossRideDesc => 'Gleicher Ausdauerreiz ohne Stoßbelastung – schont Knie, Hüfte und Achillessehne. Rad oder Rollentrainer im Plaudertempo.';

  @override
  String get healthRunNote => 'Gelenke: möglichst weicher Untergrund; abbrechen, wenn der Schmerz über 3/10 steigt oder den Laufstil verändert.';

  @override
  String get healthHeartNote => 'Herz / Blutdruck: Intensität bis zur Schwelle begrenzt – keine Maximalbelastungen.';

  @override
  String get healthSwimShoulderNote => 'Schulter: keine Paddles, beidseitig atmen, bei Schmerzen abbrechen.';

  @override
  String get healthGymBackNote => 'Rücken: keine schwere axiale Last – Kniebeugen und Kreuzheben durch Beinpresse, Split Squats oder Hip Thrusts ersetzen; neutrale Wirbelsäule.';

  @override
  String get healthGymShoulderNote => 'Schulter: kein schweres Drücken über Kopf – Landmine- oder Neutralgriff-Varianten, schmerzfrei bleiben.';

  @override
  String get healthGymJointNote => 'Gelenke: im schmerzfreien Bewegungsumfang trainieren – Tiefe oder Last reduzieren, wenn Knie oder Hüfte schmerzen.';

  @override
  String get healthGymHeartNote => 'Herz / Blutdruck: 2–3 Wiederholungen Reserve lassen und bei der Anstrengung ausatmen – kein Pressen, keine Pressatmung.';

  @override
  String get recalNote => 'An dein bisheriges Training angepasst (Anstrengung und erledigte Einheiten).';

  @override
  String get recalButton => 'Plan überprüfen';

  @override
  String get recalTitle => 'Plan überprüfen';

  @override
  String get recalIntro => 'Deine nächsten zwei Wochen, angepasst an die letzten zwei: Anstrengung (RPE), erledigte und verpasste Einheiten, neue Bestleistungen. Erledigte Einheiten bleiben unverändert.';

  @override
  String get recalFindings => 'Was wir sehen';

  @override
  String get recalChanges => 'Vorgeschlagene Änderungen';

  @override
  String get recalWhyRpeHigh => 'Mehrere Einheiten waren anstrengender als geplant – erst mehr Erholung.';

  @override
  String get recalWhyRpeLow => 'Deine Schlüsseleinheiten fielen dir leicht – etwas mehr Umfang.';

  @override
  String recalWhyCompletion(int pct) {
    return '$pct % des geplanten Trainings erledigt – vorerst keine Steigerung, etwas weniger Umfang.';
  }

  @override
  String recalWhyCutShort(int n) {
    return '$n Einheiten früher beendet – lange Einheiten werden kürzer.';
  }

  @override
  String get recalWhyMissed => 'Verpasste Schlüsseleinheiten wandern auf einen freien Tag dieser Woche.';

  @override
  String recalWhyFaster(String from, String to) {
    return 'Neue Bestleistung: Laufform (VDOT) $from → $to – Pace-Vorgaben angepasst.';
  }

  @override
  String recalWhySlower(String to, String from) {
    return 'Deine echte Laufform (VDOT $to) weicht von der Schätzung ($from) ab – Pace-Vorgaben angepasst.';
  }

  @override
  String get recalOnTrack => 'Du bist im Plan – er passt zu deinem Training. Nichts zu ändern.';

  @override
  String get recalNoRpe => 'Tipp: Bewerte nach dem Training deine Anstrengung (RPE) – dann passt sich der Plan an dein Empfinden an.';

  @override
  String get recalEasier => 'Leichter';

  @override
  String get recalHarder => 'Etwas mehr';

  @override
  String get recalToEasy => 'Locker statt hart';

  @override
  String get recalMoved => 'Verschoben';

  @override
  String get recalDropped => 'Entfällt';

  @override
  String get recalPaces => 'Neue Pace';

  @override
  String recalApply(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Änderungen übernehmen',
      one: '1 Änderung übernehmen',
    );
    return '$_temp0';
  }

  @override
  String get recalApplied => 'Plan angepasst';

  @override
  String get recalNewPlan => 'Plan neu aufsetzen…';

  @override
  String get recalMore => 'Mehr';

  @override
  String wGymDescRange(int sets, int rir) {
    return '$sets Sätze pro Übung im jeweiligen Wiederholungsbereich, $rir Wdh. im Tank lassen. Erst Wiederholungen steigern – schaffst du in allen Sätzen das obere Ende, Gewicht erhöhen und wieder unten beginnen.';
  }

  @override
  String wGymLoadDesc(int rir) {
    return 'Belastungswoche: Beende jeden Arbeitssatz mit etwa $rir Wdh. im Tank – die Reserve wird von Woche zu Woche kleiner, bis zur nächsten Entlastungswoche. Sätze, Wiederholungsbereich und Gewichtsvorschlag stehen bei jeder Übung.';
  }

  @override
  String get wGymProgressNote => 'Steigerung: Erst die Wiederholungen bis zum oberen Ende des Bereichs aufbauen, dann Gewicht erhöhen und wieder unten beginnen.';

  @override
  String get wGymDeloadNote => 'Entlastungswoche: Die Gewichte sind ca. 10 % leichter eingetragen, bei Übungen mit 3 oder mehr Sätzen fällt ein Satz weg. Sauber mit etwa 4 Wdh. im Tank trainieren – so baust du Ermüdung ab und kommst stärker zurück.';

  @override
  String get wGymTaperNote => 'Tapering vor dem Wettkampf: Gewichte ca. 10 % leichter, nichts bis zur Erschöpfung – Kraft erhalten, frisch bleiben.';

  @override
  String wGymTimeCapNote2(int min) {
    return 'Heute nur $min min Zeit: Hauptübungen wie geplant, bei den letzten Übungen je einen Satz weniger oder sie weglassen.';
  }

  @override
  String get wRecoveryWeekNote => 'Entlastungswoche: Der Umfang ist bewusst reduziert – locker bleiben, auch wenn du dich frisch fühlst. Jetzt verarbeitet der Körper die letzten Wochen.';

  @override
  String get wTaperWeekNote => 'Tapering: weniger Umfang, kurze Belastungen halten dich spritzig. Nichts nachholen – jetzt zählt die Frische für den Wettkampf.';

  @override
  String get wLongRunHmpDesc => 'Lockerer langer Lauf, das letzte Viertel im Halbmarathon-Zieltempo – die wettkampfspezifischste Einheit.';

  @override
  String get stepHmpNote => 'Halbmarathon-Zieltempo – kontrolliert';

  @override
  String get wLongRunMpDesc2 => 'Lockerer langer Lauf, das letzte Viertel im Marathon-Zieltempo – die wettkampfspezifischste Einheit.';

  @override
  String recalWhyRunTrendSlower(String from, String to) {
    return 'Deine Schlüsselläufe waren bei hoher Anstrengung langsamer als die Zielpaces – Paces entschärft (VDOT $from → $to).';
  }

  @override
  String recalWhyRunTrendFaster(String from, String to) {
    return 'Deine Schlüsselläufe trafen die Zielpaces und fühlten sich leicht an – Paces etwas schneller (VDOT $from → $to).';
  }

  @override
  String recalWhyFtpUp(String from, String to) {
    return 'Rad: Leistung über den Zielwerten ohne Mehranstrengung – FTP $from → $to W, Wattvorgaben angepasst.';
  }

  @override
  String recalWhyFtpDown(String from, String to) {
    return 'Rad: Die Wattvorgaben waren kaum zu halten – FTP $from → $to W, Wattvorgaben angepasst.';
  }

  @override
  String recalWhyCssFaster(String from, String to) {
    return 'Schwimmen: schneller als die Zielpaces bei angenehmer Anstrengung – CSS $from → $to pro 100 m.';
  }

  @override
  String recalWhyCssSlower(String from, String to) {
    return 'Schwimmen: Die Zielpaces waren kaum zu halten – CSS $from → $to pro 100 m.';
  }

  @override
  String recalWhyAerobicUp(int pct) {
    return 'Aerobe Effizienz (Tempo pro Herzschlag im lockeren Bereich) +$pct % in 6 Wochen – deine Grundlage wächst.';
  }

  @override
  String recalWhyAerobicDown(int pct) {
    return 'Aerobe Effizienz (Tempo pro Herzschlag im lockeren Bereich) −$pct % in 6 Wochen – achte auf Erholung, Schlaf und Hitze.';
  }

  @override
  String autoAdjSnack(String workout, String date, String after, String before) {
    return 'Plan angepasst: $workout $date jetzt $after statt $before';
  }

  @override
  String autoAdjSnackMany(int n) {
    return 'Plan angepasst: $n kommende Einheiten';
  }

  @override
  String get autoAdjTitle => 'Automatisch angepasst';

  @override
  String autoAdjOriginal(String value) {
    return 'Ursprünglich geplant: $value';
  }

  @override
  String get autoAdjUndone => 'Ursprünglicher Plan wiederhergestellt';

  @override
  String get autoAdjLongCutShort => 'Deine letzte lange Einheit endete vorzeitig bei hoher Anstrengung – diese bleibt bei deinem Erreichten plus etwa 10 %, statt weiter zu wachsen.';

  @override
  String get autoAdjLongHard => 'Deine letzte lange Einheit war härter als geplant – diese bleibt gleich lang, statt zu wachsen.';

  @override
  String get autoAdjEasyHard => 'Deine letzte lockere Einheit war härter als geplant (Puls / Anstrengung) – diese ist etwas kürzer. Bleib wirklich locker: Du solltest in ganzen Sätzen reden können.';

  @override
  String get autoAdjEasyTooFast => 'Deine letzte lockere Einheit war schneller als das lockere Tempo – diese ist etwas kürzer. Nimm Tempo raus: Lockere Tage bauen die Grundlage auf (80/20).';

  @override
  String get autoAdjQualityHard => 'Deine letzte Schlüsseleinheit war härter als geplant – diese wird nicht gesteigert.';

  @override
  String get autoAdjQualityEasy => 'Deine letzte Schlüsseleinheit traf die Vorgaben und fühlte sich leicht an – diese ist 5 % länger.';

  @override
  String get progTopReached => 'alle Sätze am oberen Ende – mehr Gewicht';

  @override
  String get progTopWithReserve => 'alle Sätze am oberen Ende mit Reserve – größerer Sprung';

  @override
  String get progTopAtLimit => 'oberes Ende erreicht, aber am Limit – Gewicht noch einmal halten';

  @override
  String get progMicroload => 'nächster Gewichtssprung wäre zu groß – erst mehr Wiederholungen';

  @override
  String get progAddRepsFast => 'gute Reserve – zwei Wiederholungen mehr je Satz';

  @override
  String get progRepsNoLoad => 'mehr Wiederholungen – so steigerst du hier';

  @override
  String get progHoldLimit => 'letztes Mal am Limit – gleiche Wiederholungen noch einmal';

  @override
  String get progHoldHard => 'Gewicht halten: letzte 2 Einheiten schwer';

  @override
  String get progMissedHold => 'knapp unter dem Bereich – Gewicht halten';

  @override
  String get progMissedReduce => 'Wiederholungen klar verfehlt – etwas leichter';

  @override
  String get progPerformanceDip => 'Gewicht halten: letzte 2 Einheiten unter deinem Niveau';

  @override
  String get progPerformanceDrop => 'letzte 2 Einheiten deutlich schwächer – 5–10 % leichter zum Erholen';

  @override
  String get effortQuestion => 'Wie war\'s?';

  @override
  String effortQuestionFor(String name) {
    return 'Wie war $name?';
  }

  @override
  String get effortOptional => 'Optional – hilft bei den nächsten Gewichten';

  @override
  String get effortEasy => 'Leicht';

  @override
  String get effortRight => 'Passend';

  @override
  String get effortHard => 'Schwer';

  @override
  String get effortLimit => 'Limit';

  @override
  String get howHardOptional => 'Wie anstrengend war\'s? (optional)';

  @override
  String get rpeOptionalHint => 'Hilft, deinen Plan anzupassen – kannst du auch weglassen.';

  @override
  String get rpeClear => 'Keine Angabe';

  @override
  String get rpeRate => 'Bewerten';

  @override
  String get progLinear => 'alle Ziel-Wiederholungen geschafft – etwas mehr Gewicht, gleiche Wiederholungen (Anfänger: lineare Steigerung)';

  @override
  String get progNudge => 'zweimal gehalten und jedes Ziel geschafft – eine Wiederholung mehr im schwächsten Satz';

  @override
  String get progRecalibrated => 'dein AMRAP-Satz zeigt mehr Kraft – Gewicht daran angepasst';

  @override
  String get progE1rmFloor => 'keine Wiederholungen verpasst – das Gewicht bleibt nahe an deinem Kraftniveau';

  @override
  String get amrapHint => 'Letzter Satz: so viele Wiederholungen wie möglich – 1 Wdh. vor dem Versagen aufhören (so lernt die App deine Kraft)';

  @override
  String get amrapShort => 'AMRAP';

  @override
  String recalWhyBreak(int days) {
    return '$days Tage ohne Training: Die erste Woche danach startet mit 50–70 % des geplanten Umfangs, ohne Intensität, und baut dann wieder auf.';
  }

  @override
  String get recalWhyLongCap => 'Lange Einheiten bleiben bei höchstens +10 % deiner längsten der letzten 30 Tage – darüber steigt das Verletzungsrisiko.';

  @override
  String get recalWhyRpeLowHold => 'Deine Schlüsseleinheiten fielen dir leicht – die neuen Zielwerte sind diese Woche die Steigerung, der Umfang bleibt (nie beides gleichzeitig).';

  @override
  String wBrickRun(int min) {
    return 'Koppellauf $min min';
  }

  @override
  String get wBrickRunDesc => 'Direkt vom Rad: Die ersten Minuten fühlen sich schwer an – das ist normal. Schnell wechseln (≤ 2 min) – Wechseltraining inklusive.';

  @override
  String get stepBrickStartNote => 'Laufrhythmus finden – kurze, schnelle Schritte';

  @override
  String get stepBrickNote => 'Gleichmäßiges Renngefühl – kontrolliert, nicht voll';

  @override
  String wRaceRunWalk(int min) {
    return 'Lauf-Geh-Strategie: $min min laufen, 1 min gehen – von Anfang an, auch wenn du dich frisch fühlst.';
  }

  @override
  String get wGymLegsHalvedNote => 'Beinübungen heute mit halben Sätzen – die Schlüsseleinheit morgen braucht frische Beine.';

  @override
  String get feasTitle => 'Sehr ambitioniertes Ziel';

  @override
  String get feasBeginnerMarathon => 'Ein Marathon ist kein Einsteigerziel: Baue erst über 5 km, 10 km und Halbmarathon auf.';

  @override
  String get feasRunWalkLong => 'Solange du nicht 30 min am Stück laufen kannst, ist ein Marathon zu weit – baue erst über 5 km, 10 km und einen Halbmarathon auf.';

  @override
  String get feasRunWalk => 'Am Wettkampftag bist du noch im Lauf-Geh-Programm – durchgehendes Laufen braucht länger.';

  @override
  String feasTooShort(int weeks) {
    return '$weeks Wochen reichen nicht, um die langen Einheiten für diese Distanz aufzubauen.';
  }

  @override
  String feasLongRunTime(int km, int x) {
    return 'Die Zeit an deinem Tag für den langen Lauf reicht nur für etwa $km km – dieses Rennen braucht lange Läufe über $x km. Plane an dem Tag mehr Zeit ein.';
  }

  @override
  String feasLongRideTime(int min, int target) {
    return 'Die Zeit an deinem Tag für die lange Ausfahrt reicht nur für $min min – dieses Rennen braucht lange Ausfahrten von mindestens $target min.';
  }

  @override
  String get feasOptions => 'Möglichkeiten';

  @override
  String feasLaterDate(String date) {
    return 'Ein Wettkampf am $date oder später';
  }

  @override
  String feasShorter(String dist) {
    return 'Eine kürzere Distanz: $dist';
  }

  @override
  String get feasRunWalkFinish => 'Mit Lauf-Geh-Strategie ins Ziel – der Wettkampftag im Plan zeigt den Rhythmus';

  @override
  String get feasPlanAnyway => 'Der Plan wird trotzdem erstellt und baut so weit auf, wie es sicher möglich ist.';

  @override
  String get wGymDeloadNote2 => 'Entlastungswoche: Die Gewichte sind ca. 10 % leichter eingetragen, jede Übung behält etwa die Hälfte ihrer Arbeitssätze. Sauber mit etwa 4 Wdh. im Tank trainieren – so baust du Ermüdung ab und kommst stärker zurück.';

  @override
  String get glossary => 'Glossar';

  @override
  String get glossaryHint => 'Kurze Erklärungen der Begriffe und Abkürzungen in der App.';

  @override
  String termWhatIs(String term) {
    return 'Was bedeutet $term?';
  }

  @override
  String get termRpeTitle => 'RPE – wahrgenommene Anstrengung';

  @override
  String get termRpeBody => 'Wie anstrengend sich eine Einheit oder ein Satz angefühlt hat, auf einer Skala von 1 (sehr leicht) bis 10 (maximal). 3–4 = locker, du kannst dich unterhalten; 6–7 = fordernd, aber kontrolliert; 9–10 = absolutes Maximum.';

  @override
  String get termRpeTip => 'Optional. Wenn du sie einträgst, passt sich der Plan genauer an – z. B. führen zu harte lockere Läufe zu einer leichteren nächsten Woche.';

  @override
  String get termRirTitle => 'RIR – Wiederholungen im Tank';

  @override
  String get termRirBody => 'Wie viele Wiederholungen du am Ende eines Satzes noch geschafft hättest. „2 im Tank“ heißt: zwei Wiederholungen vor dem Muskelversagen aufhören.';

  @override
  String get termRirTip => 'Die Bewertungs-Chips entsprechen dem: Leicht ≈ 4+, Passend ≈ 2–3, Schwer ≈ 1, Limit = 0. Die meisten Sätze sollten mit 1–3 im Tank enden.';

  @override
  String get termE1rmTitle => 'e1RM – geschätztes Maximalgewicht';

  @override
  String get termE1rmBody => 'Das Gewicht, das du vermutlich genau einmal schaffen würdest – berechnet aus einem Satz mit mehr Wiederholungen (z. B. 80 kg × 8 ≈ 101 kg). Ein echter Maximaltest ist nicht nötig.';

  @override
  String get termE1rmTip => 'Ideal, um Fortschritt über verschiedene Gewichte und Wiederholungszahlen zu vergleichen.';

  @override
  String get termVdotTitle => 'VDOT – Lauf-Fitnesswert';

  @override
  String get termVdotBody => 'Ein Wert nach Trainer Jack Daniels, berechnet aus deinen Wettkampfzeiten. Alle Lauftempos in deinem Plan (locker, Tempo, Intervall) werden daraus abgeleitet.';

  @override
  String get termVdotTip => '+1 VDOT entspricht etwa 1–2 % schneller über jede Distanz. Er steigt mit regelmäßigem Training und wird aktualisiert, wenn du schneller läufst.';

  @override
  String get termFtpTitle => 'FTP – funktionelle Schwellenleistung';

  @override
  String get termFtpBody => 'Die Leistung (Watt), die du auf dem Rad etwa eine Stunde halten kannst. Radzonen wie Grundlage, Sweet Spot und Schwelle sind Prozentwerte davon.';

  @override
  String get termFtpTip => 'Ohne Wattmesser nutzt der Plan stattdessen Puls und Gefühl.';

  @override
  String get termCssTitle => 'CSS – kritische Schwimmgeschwindigkeit';

  @override
  String get termCssBody => 'Dein Schwellentempo im Becken pro 100 m, berechnet aus einem 400-m- und einem 200-m-Test. Schwimm-Intervalle werden relativ dazu vorgegeben.';

  @override
  String get termCssTip => 'Beispiel: 400 m in 8:00 und 200 m in 3:40 → CSS ≈ 2:10 /100 m.';

  @override
  String get termSupersetTitle => 'Supersatz';

  @override
  String get termSupersetBody => 'Zwei (oder drei) Übungen direkt nacheinander mit nur kurzem Wechsel, danach die volle Pause. Die App kombiniert gegensätzliche Muskeln (z. B. Drücken + Rudern), so erholt sich der eine, während der andere arbeitet.';

  @override
  String get termSupersetTip => 'Spart Zeit, ohne Leistung zu kosten.';

  @override
  String get termAmrapTitle => 'AMRAP – so viele Wiederholungen wie möglich';

  @override
  String get termAmrapBody => 'Im letzten Satz so viele saubere Wiederholungen wie möglich – aber eine Wiederholung vor dem Versagen aufhören. Die App korrigiert damit deine Gewichte.';

  @override
  String get termAmrapTip => 'Erscheint nur, wenn es hilft: bei neuen Übungen und wenn du das obere Ende des Bereichs erreichst.';

  @override
  String get termVolumeTitle => 'Volumen';

  @override
  String get termVolumeBody => 'Gewicht × Wiederholungen aller Arbeitssätze zusammengezählt (Aufwärmsätze zählen nicht). Wo dein Körper ein Gewicht ersetzt – Liegestütz (≈ 64 % deines Körpergewichts, wie beim Bankdrücken), Klimmzüge und Dips (100 %), Rudern am Tisch – zählt dieser Anteil plus Zusatzgewicht. Kniebeugen, Ausfallschritte, Wadenheben, Brücken und Rumpfübungen zählen nur das Zusatzgewicht, so wie ihre Varianten mit Hantel nur die Hantel zählen – so bricht das Volumen nicht ein, wenn du von Kniebeugen ohne zu Kniebeugen mit Gewicht wechselst. Halteübungen wie Unterarmstütz zählen als Haltezeit, nicht als Volumen.';

  @override
  String get termVolumeTip => 'Mehr Volumen ist nicht automatisch besser – entscheidend ist der Fortschritt über Wochen.';

  @override
  String get termPhaseTitle => 'Planphasen';

  @override
  String get termPhaseBody => 'Grundlage: Ausdauer und Technik aufbauen, überwiegend locker. Aufbau: mehr Intensität. Spitze: wettkampfspezifische Einheiten. Tapering: weniger Umfang vor dem Wettkampf, damit du frisch startest. Entlastungswoche: alle 3–5 Wochen eine leichtere Woche, damit sich der Körper anpasst.';

  @override
  String get termPhaseTip => 'Entlastungs- und Taperwochen fühlen sich bewusst leicht an – nicht nachholen.';

  @override
  String get termZonesTitle => 'Intensitätszonen';

  @override
  String get termZonesBody => 'Belastungsbereiche von sehr locker bis maximal, über Tempo, Puls oder Leistung definiert. Etwa 80 % des Ausdauertrainings sollten locker sein – das baut deine Grundlage auf.';

  @override
  String get termZonesTip => 'Tippe in einer Einheit auf eine Zone, um ihren genauen Bereich zu sehen.';

  @override
  String get raceSearch => 'Wettkämpfe suchen';

  @override
  String get raceSport => 'Sportart';

  @override
  String get raceAnyDistance => 'Alle Distanzen';

  @override
  String get raceRegion => 'Region (Land oder Stadt)';

  @override
  String get raceRegionHint => 'z. B. Deutschland, München, 80331 – leer = überall';

  @override
  String get raceWindow => 'Zeitraum';

  @override
  String raceNextMonths(int n) {
    return '$n Monate';
  }

  @override
  String get raceSearchButton => 'Suchen';

  @override
  String get raceIntro => 'Durchsucht öffentliche Wettkampfkalender (DLV-Laufkalender, DTU-Kalender, RunSignup für die USA) – oder öffne direkt einen Wettkampfkalender.';

  @override
  String get raceSearching => 'Durchsuche Wettkampfkalender…';

  @override
  String get raceWebResults => 'Web-Ergebnisse (KI-Suche)';

  @override
  String get raceDisclaimer => 'Aus öffentlichen Wettkampfkalendern – ohne Gewähr. Prüfe Datum und Details beim Veranstalter, bevor du dich anmeldest.';

  @override
  String get raceOrganiserPage => 'Details';

  @override
  String get raceSetAsGoal => 'Als Ziel übernehmen';

  @override
  String get raceGoalSet => 'Wettkampf als Ziel übernommen';

  @override
  String get raceEmpty => 'Keine Wettkämpfe für diese Filter gefunden. Versuch einen längeren Zeitraum oder eine größere Region – oder stöbere in einem Wettkampfkalender.';

  @override
  String get raceUnavailable => 'Die KI-Websuche ist gerade nicht verfügbar (Kontingent bzw. Tarif des KI-Dienstes). Stöbere stattdessen in einem Wettkampfkalender.';

  @override
  String get raceError => 'Die Suche ist fehlgeschlagen. Prüfe die Verbindung und versuch es erneut – oder stöbere in einem Wettkampfkalender.';

  @override
  String get raceBadResponse => 'Die Suche hat kein verwertbares Ergebnis geliefert. Versuch es erneut – oder stöbere in einem Wettkampfkalender.';

  @override
  String get raceRetry => 'Erneut versuchen';

  @override
  String get racePortals => 'Wettkampfkalender';

  @override
  String get racePortalsHint => 'Öffnet im Browser, wo möglich schon gefiltert.';

  @override
  String get raceSources => 'Quellen';

  @override
  String get raceGoogleSuggestions => 'Google-Suchen';

  @override
  String get recalGapsTitle => 'Lücken im Plan';

  @override
  String recalWhyGaps(int n) {
    return 'Im Plan fehlen Einheiten ($n) – Vorschläge zum Auffüllen siehe unten.';
  }

  @override
  String get recalWhyGapsOmitted => 'Einige fehlende Einheiten werden nicht aufgefüllt: Sie lägen neben einem Wettkampf oder die Woche hat ihren geplanten Umfang schon.';

  @override
  String get recalAdded => 'Neu';

  @override
  String recalGapMissing(String day) {
    return 'Am $day fehlt die geplante Einheit – wieder eingefügt.';
  }

  @override
  String get recalGapEmptyWeek => 'Diese Woche ist leer – die geplante Einheit wird wieder eingefügt.';

  @override
  String get recalGapEnded => 'Der Plan endete vorher – hier fortgesetzt.';

  @override
  String get recalGapDowngraded => 'Locker statt hart: Der Nachbartag ist schon hart.';

  @override
  String get recalGapEased => 'Locker, weil der Plan gerade entlastet.';

  @override
  String get recalGapShortened => 'Kürzer, damit Woche und langer Lauf im sicheren Rahmen bleiben.';

  @override
  String get feasTitleTarget => 'Zielzeit-Check';

  @override
  String feasTargetAmbitious(String goal, String now, String pred) {
    return 'Ehrgeizig: $goal braucht mehr als den üblichen Fortschritt bis zum Wettkampf (heute ~$now, erwartet am Wettkampftag ~$pred). Mit sehr konsequentem Training möglich.';
  }

  @override
  String feasTargetUnrealistic(String goal, String now, String pred) {
    return '$goal ist bis zum Wettkampf kaum erreichbar: heute liegst du bei ~$now, realistisch sind am Wettkampftag ~$pred.';
  }

  @override
  String feasTargetOkLine(String goal, String now, String pred) {
    return 'Zielzeit $goal ist realistisch: heute ~$now, erwartet am Wettkampftag ~$pred.';
  }

  @override
  String feasTargetLater(String goal, String date) {
    return '$goal wird mit einem Wettkampf ab $date realistisch';
  }

  @override
  String feasTargetSuggest(String goal) {
    return 'eine Zielzeit von $goal';
  }

  @override
  String get feasEstimated => 'Grobe Schätzung – trag in den Planeinstellungen eine Wettkampfzeit ein, dann wird der Check genau.';

  @override
  String adjustTargetTo(String goal) {
    return 'Zielzeit auf $goal anpassen';
  }

  @override
  String targetAdjusted(String goal) {
    return 'Zielzeit auf $goal gesetzt';
  }

  @override
  String planToEventPre(int weeks, int n, int x) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wochen',
      one: '1 Woche',
    );
    return '$weeks Wochen bis zum Wettkampf: zuerst $_temp0 Grundlagenaufbau, dann der $x-wöchige Wettkampfplan.';
  }

  @override
  String get planKeepsDone => 'Erledigte Einheiten bleiben erhalten – nur kommende geplante Einheiten werden ersetzt.';

  @override
  String get planEventTooFar => 'Dein Wettkampf ist mehr als 52 Wochen entfernt – der Plan nutzt vorerst die Länge unten.';

  @override
  String planUntilRace(int weeks) {
    return 'Der Plan läuft bis zum Wettkampftag ($weeks Wochen).';
  }

  @override
  String get alignPlanToEvent => 'Trainingsplan auf diesen Wettkampf ausrichten';

  @override
  String get alignPlanToEventSub => 'Der Plan läuft bis zum Wettkampftag; erledigte Einheiten bleiben erhalten.';

  @override
  String get alignNeedsDistance => 'Wähle eine Wettkampfdistanz, um den Plan auszurichten.';

  @override
  String planAligned(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks Wochen',
      one: '1 Woche',
    );
    return 'Plan ausgerichtet: $_temp0 bis zum Wettkampf';
  }

  @override
  String get goalStatusTitle => 'Wo stehe ich';

  @override
  String goalCountdown(int weeks, int days) {
    return '$weeks Wo. $days T.';
  }

  @override
  String goalCountdownDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get goalToRace => 'bis zum Wettkampf';

  @override
  String get goalForecast => 'Prognose';

  @override
  String get goalTargetLabel => 'Ziel';

  @override
  String get goalToday => 'Heute';

  @override
  String get goalFinish => 'Ankommen';

  @override
  String get fcAhead => 'Vor dem Plan';

  @override
  String get fcOnTrack => 'Im Plan';

  @override
  String get fcSlightlyBehind => 'Leicht hinter dem Plan';

  @override
  String get fcAtRisk => 'Ziel gefährdet';

  @override
  String get fcEarly => 'Noch zu früh';

  @override
  String get fcEarlySub => 'Nach deinen ersten Einheiten nutzt die Prognose deine Trainingsdaten.';

  @override
  String get fcRiskTitle => 'Dein Ziel ist gefährdet';

  @override
  String fcRiskBody(String pred, String goal) {
    return 'Das Training lief zuletzt nicht wie geplant. Prognose für den Wettkampftag: ~$pred statt $goal.';
  }

  @override
  String get fcRiskBodyFinish => 'Das Training lief zuletzt nicht wie geplant – so ist das Finish gefährdet. Konsequentes Training ab jetzt (oder eine der Optionen) kann es noch drehen.';

  @override
  String fcAheadBody(String goal) {
    return 'Du bist schneller als geplant – $goal sieht realistisch aus.';
  }

  @override
  String fcReasonMissed(int pct) {
    return '$pct % des geplanten Trainings erledigt';
  }

  @override
  String get fcReasonSlower => 'Schlüsselläufe langsamer als geplant';

  @override
  String get fcReasonFaster => 'Schlüsselläufe schneller als geplant';

  @override
  String get fcReasonLongRun => 'Lange Läufe kürzer als geplant';

  @override
  String get fcReasonBreak => 'Trainingspause – nach ~10 Tagen ohne Laufen sinkt die Form';

  @override
  String fcRange(String fast, String slow) {
    return 'Spanne $fast – $slow';
  }

  @override
  String get fcConfLow => 'grobe Schätzung';

  @override
  String get fcConfMedium => 'aus deinen Einheiten';

  @override
  String get fcConfHigh => 'aus einem Wettkampfergebnis';

  @override
  String get fcInRecal => 'Zielprognose';

  @override
  String get goalPhaseBaseShort => 'Grundlage';

  @override
  String get goalPhaseBuildShort => 'Aufbau';

  @override
  String get goalPhasePeakShort => 'Spitze';

  @override
  String get goalPhaseTaperShort => 'Tapering';

  @override
  String get goalCompletion => 'Planerfüllung';

  @override
  String get goalLongestRun => 'Längster Lauf (6 Wochen)';

  @override
  String goalLongRunNeed(int km) {
    return 'nötig vor dem Tapering: $km km';
  }

  @override
  String get goalFitnessTrend => 'Formverlauf (VDOT)';

  @override
  String get goalTrendPlanned => 'Plan';

  @override
  String get goalTrendActual => 'Deine Einheiten';

  @override
  String get goalTrendEmpty => 'Der Verlauf erscheint nach ein paar Tempo- oder Intervallläufen.';

  @override
  String get goalPhaseOutlook => 'Phasen & erwartete Form';

  @override
  String get goalPhaseNow => 'jetzt';

  @override
  String goalWeeksN(int weeks) {
    return '$weeks Wo.';
  }

  @override
  String get goalEditPlan => 'Planeinstellungen';

  @override
  String get replacePlanTitle => 'Plan neu aufsetzen?';

  @override
  String replacePlanBody(String date, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n geplante Einheiten ab $date werden ersetzt.',
      one: '1 geplante Einheit ab $date wird ersetzt.',
    );
    return '$_temp0';
  }

  @override
  String get replacePlanKeeps => 'Erledigte Einheiten und Statistik bleiben.';

  @override
  String get replaceFromToday => 'Ab heute';

  @override
  String get replaceFromMonday => 'Ab nächstem Montag';

  @override
  String get replacePlanOk => 'Ersetzen';

  @override
  String get startOverTitle => 'Plan neu aufsetzen';

  @override
  String get startOverButton => 'Neu aufsetzen';

  @override
  String get wRecoveryWeekNote2 => 'Entlastungswoche: Der Umfang ist bewusst reduziert – bleib locker, auch wenn du dich frisch fühlst. Jetzt verarbeitet der Körper die letzten Wochen.';

  @override
  String get wGymDeloadNote3 => 'Entlastungswoche: Die Gewichte sind etwa 10 % leichter eingetragen, jede Übung behält etwa die Hälfte ihrer Arbeitssätze. Sauber mit etwa 4 Wdh. im Tank trainieren – so baust du Ermüdung ab und kommst stärker zurück.';

  @override
  String get eventQuestion => 'Trainierst du für einen Wettkampf?';

  @override
  String get noPlanYet => 'Noch kein Plan';

  @override
  String get noPlanYetSub => 'Strive erstellt ihn aus Ziel, Trainingstagen und Zeit.';

  @override
  String todayNext(String title, String day) {
    return 'Nächste: $title · $day';
  }

  @override
  String todayHiddenByFilter(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Einheiten durch Filter ausgeblendet',
      one: '1 Einheit durch Filter ausgeblendet',
    );
    return '$_temp0';
  }

  @override
  String get todayHiddenByFilterSub => 'Der Sportfilter ist aktiv – heute ist kein Ruhetag.';

  @override
  String get showAllSports => 'Alle zeigen';

  @override
  String hintPlannedDry(String sport, String time) {
    return 'Heute geplant: $sport – trocken bis $time';
  }

  @override
  String hintPlannedBest(String sport, String time) {
    return 'Heute geplant: $sport – am besten um $time';
  }

  @override
  String hintPlannedStorm(String sport) {
    return 'Gewitter – $sport lieber drinnen oder später';
  }

  @override
  String hintPlannedNeutral(String sport) {
    return 'Heute geplant: $sport – passend anziehen';
  }

  @override
  String get summaryEffortTitle => 'Wie anstrengend war\'s? Dein Plan passt sich daran an.';

  @override
  String get summaryEffortHint => 'Optional · 1 = ganz locker, 10 = alles gegeben';

  @override
  String get summaryEffortPrefilled => 'Vorausgewählt aus deinen Übungsbewertungen – tippe, um es zu ändern.';

  @override
  String autoAdjBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Einheiten automatisch angepasst – ansehen',
      one: '1 Einheit automatisch angepasst – ansehen',
    );
    return '$_temp0';
  }

  @override
  String get autoAdjSheetIntro => 'Nach deinen letzten Einheiten hat sich der Plan hier angepasst. Behalte die Änderungen oder mach einzelne rückgängig.';

  @override
  String get planHistory => 'Planverlauf';

  @override
  String get planHistoryEmpty => 'Noch keine Planänderungen. Automatische Anpassungen, „Plan überprüfen“, „Woche anpassen“ und „Nicht 100 % fit?“ erscheinen hier.';

  @override
  String get planLogRecal => 'Plan überprüft';

  @override
  String planLogReadiness(String why) {
    return 'Nicht 100 % fit: $why';
  }

  @override
  String get planLogWeekReason => 'Verpasste Einheiten innerhalb der Woche verschoben oder gestrichen.';

  @override
  String get planLogUndone => 'Rückgängig gemacht';

  @override
  String get planLogChanged => 'Inzwischen geändert – kein Rückgängig';

  @override
  String get planLogNew => 'neu';

  @override
  String get planLogDropped => 'Entfällt';

  @override
  String get planLogUndoDone => 'Änderung rückgängig gemacht';

  @override
  String get notFitButton => 'Nicht 100 % fit?';

  @override
  String get notFitIntro => 'Sag dem Plan, wie es dir geht – er schlägt eine sichere Änderung vor. Erst mit „Übernehmen“ ändert sich etwas.';

  @override
  String get notFitSick => 'Krank';

  @override
  String get notFitPain => 'Schmerzen';

  @override
  String get notFitTired => 'Müde';

  @override
  String get notFitTime => 'Wenig Zeit';

  @override
  String get notFitMinutes => 'Verfügbare Zeit';

  @override
  String get notFitNoChange => 'Keine Änderung nötig – die Einheit passt so.';

  @override
  String get notFitPreview => 'Vorgeschlagene Änderung';

  @override
  String get notFitApplied => 'Plan angepasst';

  @override
  String get notFitHintAboveNeck => 'Hals-Regel: Nur Schnupfen oder leichtes Halskratzen ohne Fieber – Pause oder höchstens eine kurze, lockere Einheit. Fieber, Gliederschmerzen, Brust- oder Magen-Darm-Beschwerden: kein Training, bis du gesund bist.';

  @override
  String get notFitHintReturn => 'Nach dem Kranksein: Harte Einheiten der nächsten zwei Tage werden locker. Nach 10 Tagen Pause oder mehr nutze „Plan überprüfen“ – er baut mit 50–70 % deines bisherigen Umfangs wieder auf.';

  @override
  String get notFitHintPainRule => 'Schmerz bis 3/10, der am nächsten Morgen abgeklungen ist, ist vertretbar. Brich ab, wenn er während der Einheit zunimmt.';

  @override
  String get notFitHintDoctor => 'Hält der Schmerz länger als ein paar Tage an oder kommt immer wieder, lass ihn ärztlich oder physiotherapeutisch abklären.';

  @override
  String get notFitHintSwapped => 'Gegen gelenkschonendes Alternativtraining getauscht: Es erhält deine Ausdauer ohne die Stoßbelastung beim Laufen.';

  @override
  String get notFitHintKeyEasy => 'Müde: Die Schlüsseleinheit wird zur lockeren Einheit (ca. 20 % kürzer). Qualität mit müden Beinen bringt Ermüdung statt Form.';

  @override
  String get notFitHintShorter => 'Müde: Die lockere Einheit ist ca. 25 % kürzer – bleib wirklich locker.';

  @override
  String get notFitHintGymLighter => 'Etwa ein Drittel weniger Sätze bei gleichen Gewichten; beende jeden Satz mit 2–3 Wdh. im Tank. Lass Übungen weg, die schmerzen.';

  @override
  String get notFitHintGymShorter => 'Weniger Sätze, damit es in deine Zeit passt – Hauptübungen zuerst. Wenige harte Sätze erhalten den Großteil der Wirkung.';

  @override
  String get notFitHintTime => 'Auf deine Zeit gekürzt: Aufwärmen und Ausklang bleiben, der Hauptteil wird kürzer.';

  @override
  String get askCoachAbout => 'Coach fragen';

  @override
  String coachExplainWorkout(String title, String date) {
    return 'Erklär mir die Einheit „$title“ am $date';
  }

  @override
  String get reserveLabel => 'Reserve';

  @override
  String reserveN(String value) {
    return 'Reserve $value';
  }

  @override
  String get reserveHint => 'Wdh. im Tank';

  @override
  String get logRirSetting => 'Reserve je Satz';

  @override
  String get logRirSettingSub => 'Wiederholungen im Tank nach jedem Satz (RIR). Die Bewertung pro Übung bleibt.';

  @override
  String wRaceGoalStart(String goal, String pace) {
    return 'Ziel $goal – starte mit $pace';
  }

  @override
  String get wProgressionRun => 'Steigerungslauf';

  @override
  String get wProgressionRunDesc => 'Locker beginnen, den letzten Teil gleichmäßig im Marathontempo laufen – aerobe Kraft ohne harten Intervalltag.';

  @override
  String get stepProgressionNote => 'Zügig – Marathontempo, noch kontrolliert';

  @override
  String get wLongRunProgression => 'Langer Lauf mit Steigerung';

  @override
  String get wLongRunProgressionDesc => 'Lockerer langer Lauf, der letzte Teil zügig im Marathontempo – Ermüdungsresistenz ohne Renntempo-Einheit.';

  @override
  String get wLongRunShortDesc => 'Kürzerer langer Lauf diese Woche: eine leichtere Woche zwischen den längsten Läufen – der Körper verarbeitet die Belastung vor dem nächsten Schritt.';

  @override
  String wGoalPaceSet(int reps, String dist) {
    return 'Zieltempo $reps × $dist km';
  }

  @override
  String get wGoalPaceSetDesc => 'Wiederholungen im Wettkampf-Zieltempo mit kurzen Trabpausen – die wettkampfspezifische Einheit: Rhythmus, Tempogefühl, Selbstvertrauen.';

  @override
  String get stepGoalPaceNote => 'Wettkampf-Zieltempo – gleichmäßig und kontrolliert';

  @override
  String wCruiseKm(int reps, String dist) {
    return 'Cruise-Intervalle $reps × $dist km';
  }

  @override
  String wRideTempo(int reps, int min) {
    return 'Tempo $reps × $min min';
  }

  @override
  String get wRideTempoDesc => 'Wettkampfspezifisches Tempo bei 75–85 % FTP – die Belastung einer 70.3-Radstrecke: gleichmäßig, aerodynamisch, mit Verpflegung.';

  @override
  String get stepRideTempoNote => 'Tempo – 75–85 % FTP, gleichmäßig';

  @override
  String get sprintTri => 'Sprint-Triathlon';

  @override
  String get distUltra50 => 'Ultra 50 km';

  @override
  String get distIronman => 'Langdistanz (Ironman)';

  @override
  String get distDuSprint => 'Duathlon Sprint (5/20/2,5)';

  @override
  String get distDuStandard => 'Duathlon Standard (10/40/5)';

  @override
  String get distRide100 => 'Radmarathon 100 km';

  @override
  String get distRide160 => 'Radmarathon 160 km';

  @override
  String get distSwim1500 => 'Freiwasser 1,5 km';

  @override
  String get distSwim3800 => 'Freiwasser 3,8 km';

  @override
  String get distSwim5000 => 'Freiwasser 5 km';

  @override
  String get moreDistances => 'Weitere Distanzen…';

  @override
  String get backAgainToExit => 'Nochmal zurück zum Beenden';

  @override
  String get musicRpm => 'U/min';

  @override
  String get musicIntroRun => 'Musik im Takt deiner Schrittfrequenz (≈ 150–185 Schritte/min) macht das Laufen ökonomischer und gefühlt leichter.';

  @override
  String get musicRunEasy => 'Lockerer Lauf';

  @override
  String get musicRunSteady => 'Langer / gleichmäßiger Lauf';

  @override
  String get musicRunTempo => 'Tempolauf';

  @override
  String get musicRunIntervals => 'Intervalle & Steigerungen';

  @override
  String get musicPodcastsRun => 'Ideal für lange lockere Läufe';

  @override
  String get musicIntroRide => 'Musik im Takt deiner Trittfrequenz (80–100 U/min): ein Schlag pro Kurbelumdrehung oder Double-Time.';

  @override
  String get musicRideSafety => 'Draußen: Lautstärke niedrig oder nur ein Ohrhörer – den Verkehr musst du weiter hören.';

  @override
  String get musicRideEasy => 'Lockere Fahrt';

  @override
  String get musicRideSteady => 'Grundlage & Sweet Spot';

  @override
  String get musicRideThreshold => 'Schwelle';

  @override
  String get musicRideIntervals => 'Intervalle & Sprints';

  @override
  String get musicPodcastsRide => 'Ideal für lange lockere Ausfahrten';

  @override
  String get musicPodcastsTrainer => 'Ideal für lange Einheiten auf der Rolle';

  @override
  String get musicIntroSwim => 'Unter Wasser hörst du Musik nur mit Spezial-Kopfhörern – starte sie vor dem Einstieg.';

  @override
  String get musicSwimPoolHint => 'Bluetooth funktioniert unter Wasser nicht: Du brauchst wasserdichte Knochenschall-Kopfhörer mit eigenem Speicher (MP3). Lade die Playlist vorher herunter.';

  @override
  String get musicSwimOpenHint => 'Freiwasser: nur mit Knochenschall-Kopfhörern und so leise, dass du Boote, deine Gruppe und die Wasseraufsicht hörst.';

  @override
  String get musicPreSwim => 'Vor dem Schwimmen: Aufwärmen & Fokus';

  @override
  String get musicSwimList => 'Schwimm-Playlist (zum Herunterladen)';

  @override
  String get musicSwimListSub => 'Gleichmäßiger Rhythmus für MP3-Kopfhörer';

  @override
  String get musicPodcastsSwim => 'Für lange, ruhige Strecken (Knochenschall)';

  @override
  String get musicIntroGym => 'Laute, motivierende Musik mit 120–140 BPM hilft beim Krafttraining; Zirkel schneller, Aufwärmen und Dehnen ruhiger.';

  @override
  String get musicGymHint => 'Tipp: Durchgehende Mixe halten die Energie in den Satzpausen – der Pausen-Timer vibriert trotzdem, wenn die Pause vorbei ist.';

  @override
  String get musicGymWarmup => 'Aufwärmen & Mobility';

  @override
  String get musicGymStrength => 'Krafttraining';

  @override
  String get musicGymHeavy => 'Schwere Sätze';

  @override
  String get musicGymCircuit => 'Supersätze, Zirkel & HIIT';

  @override
  String get musicGymCooldown => 'Cool-down & Dehnen';

  @override
  String get tabData => 'Daten';

  @override
  String get tabMap => 'Karte';

  @override
  String get tabSplits => 'Splits';

  @override
  String get tabWorkout => 'Ablauf';

  @override
  String get autoPausedHint => 'Läuft weiter, sobald du dich bewegst';

  @override
  String get pausedHint => 'Zum Beenden ■ gedrückt halten';

  @override
  String lapDone(int n, String time, String dist) {
    return 'Runde $n: $time · $dist';
  }

  @override
  String get currentLap => 'Aktuelle Runde';

  @override
  String get lapCount => 'Runden';

  @override
  String get currentSplit => 'Aktueller km';

  @override
  String get bestSplit => 'Schnellster km';

  @override
  String get avgSplit => 'Ø km';

  @override
  String get repeatCue => 'Ansage wiederholen';

  @override
  String get cadenceTarget => 'Ziel-Trittfrequenz';

  @override
  String vcStatus(String time, String dist) {
    return 'Zeit $time. Distanz $dist.';
  }

  @override
  String get targetBand => 'Ziel';

  @override
  String get routeTapHint => 'Karte';

  @override
  String get stepLeft => 'Rest Abschnitt';

  @override
  String get raceRadius => 'Umkreis';

  @override
  String raceResultsCount(int n) {
    return 'Gefundene Wettkämpfe: $n';
  }

  @override
  String raceSourceOf(String name) {
    return 'Quelle: $name';
  }

  @override
  String raceDataFrom(String names) {
    return 'Daten: $names';
  }

  @override
  String raceSourcesFailed(String names) {
    return 'Gerade nicht erreichbar: $names';
  }

  @override
  String get raceNoSource => 'Für diese Sportart und Region gibt es noch keine direkte Suche (angebunden: DLV-Laufkalender, DTU-Kalender, RunSignup für die USA). Stöbere unten in einem Wettkampfkalender.';

  @override
  String get wShakeoutRide => 'Lockere Vorbelastung (Rad)';

  @override
  String get wShakeoutRideDesc => '20–30 min ganz locker mit drei kurzen Antritten – Beine lockern, Rad checken. Verpflegung für morgen vorbereiten.';

  @override
  String get wShakeoutSwim => 'Lockeres Vorschwimmen';

  @override
  String get wShakeoutSwimDesc => 'Kurz und locker mit ein paar zügigen 50ern und Orientierung – am besten am Wettkampfort im Neoprenanzug.';

  @override
  String get stepSightingNote => 'Orientierung: alle 6–9 Züge kurz nach vorn schauen, Rhythmus halten';

  @override
  String wDuLegs(String run, String bike, String run2) {
    return 'Laufen $run km · Rad $bike km · Laufen $run2 km';
  }

  @override
  String get wRaceFuelNote => 'Verpflege dich wie geübt: früh beginnen, 60–90 g Kohlenhydrate pro Stunde, nach Durst trinken – nichts Neues am Wettkampftag.';

  @override
  String get wFuelPracticeNote => 'Wettkampfverpflegung üben: 60–90 g Kohlenhydrate und 400–800 ml Flüssigkeit pro Stunde – der Darm trainiert mit.';

  @override
  String get wTrailNote => 'Hat dein Rennen Höhenmeter: im hügeligen Gelände laufen und an steilen Stücken zügiges Gehen üben.';

  @override
  String get stepClimbNote => 'Im Sitzen, niedrige Trittfrequenz 60–70 U/min – am Anstieg oder mit hohem Widerstand';

  @override
  String wClimb(int reps, int each) {
    return 'Bergintervalle $reps × $each min';
  }

  @override
  String get wClimbDesc => 'Sweet-Spot-Belastung als Bergintervalle: baut die Kraftausdauer für lange Anstiege auf.';

  @override
  String wDuRunFirst(int min) {
    return 'Lauf vor dem Rad $min min';
  }

  @override
  String get wDuRunFirstDesc => 'Duathlon-Reihenfolge: zügig im Wettkampfgefühl laufen, schnell aufs Rad wechseln – nach der Ausfahrt folgt der Koppellauf.';

  @override
  String get wBackToBack => 'Back-to-Back-Lauf';

  @override
  String get wBackToBackDesc => 'Lockerer mittellanger Lauf auf müden Beinen, am Tag nach dem langen Lauf – Ultra-Ausdauer ohne einen riesigen Einzellauf. Gehpausen sind erlaubt.';

  @override
  String get stepSwimTestNote => 'Zeitschwimmen: das schnellste gleichmäßige Tempo – Zeit notieren';

  @override
  String get wSwimCssTest => 'CSS-Test (400 m + 200 m)';

  @override
  String get wSwimCssTestDesc => 'Du schwimmst jetzt 400 m am Stück: 400 m und nach 5–10 min locker 200 m auf Zeit schwimmen. Trage beide Zeiten in den Planeinstellungen (Schwimmen) ein – dann berechnet Strive deine Schwimmtempi und plant CSS-Serien.';

  @override
  String get stepSwimNoviceWu => 'Locker, Pausen nach Bedarf';

  @override
  String get stepSwimKickNote => 'Beinschlag mit Brett, locker aus der Hüfte – unter Wasser ausatmen';

  @override
  String get stepSwimNoviceNote => 'Locker und ohne anzuhalten – lange Züge, ruhig atmen';

  @override
  String wSwimBuild(int reps, int meters) {
    return 'Aufbau $reps × $meters m';
  }

  @override
  String get wSwimBuildDesc => 'Am-Stück-Schwimmen aufbauen: jede Wiederholung locker ohne Anhalten schwimmen, am Rand so lange pausieren wie nötig (~30–45 s). Die Strecken werden Woche für Woche länger – Ziel: 400 m am Stück.';

  @override
  String get wSwimNoviceTechDesc => 'Technik für Schwimmeinsteiger: unter Wasser ausatmen, flache Wasserlage, lockerer Beinschlag – kurze Strecken mit Pausen. Keine Tempovorgaben.';

  @override
  String wLongSwim(int meters) {
    return 'Lange Schwimmeinheit $meters m';
  }

  @override
  String get wLongSwimDesc => 'Das lange Am-Stück-Schwimmen der Woche – gleichmäßiger Rhythmus, beidseitig atmen, ohne Anhalten. Es wächst in Richtung deiner Wettkampfdistanz.';

  @override
  String get wOpenWaterNote => 'Wenn möglich im Freiwasser: Neoprenanzug, Orientierung, Schwimmen in der Gruppe (Wasserschatten) und nie allein.';

  @override
  String get stepSwimTempoNote => 'Tempo – etwas langsamer als CSS, kurze Pausen';

  @override
  String wSwimTempoSet(int n, int meters) {
    return 'Tempo-Serie $n × $meters m';
  }

  @override
  String get wSwimTempoDesc => 'Lange Wiederholungen knapp unter der Schwelle: ausdauerndes Renntempo für längere Strecken.';

  @override
  String get feasBeginnerDistance => 'Diese Distanz ist kein Einsteigerziel: Baue erst über eine Saison mit kürzeren Rennen auf.';

  @override
  String feasLongSwim(int meters, int target) {
    return 'Bis zum Wettkampf reicht dein Am-Stück-Schwimmen nur für etwa $meters m – dieses Rennen braucht etwa $target m am Stück.';
  }

  @override
  String feasRaiseDay(String day, String time) {
    return 'Erhöhe die Zeit am $day auf $time';
  }

  @override
  String feasMoveLongDay(String day, String time) {
    return 'Lege die lange Einheit auf $day ($time verfügbar)';
  }

  @override
  String timeLongDayHint2(String time) {
    return 'An deinem Tag für lange Einheiten (★) plant Strive für dieses Ziel $time ein, außer du legst den Tag selbst fest.';
  }

  @override
  String get abilityTitle => 'Dein aktueller Stand';

  @override
  String get canSwim400Sub => 'Falls nicht, beginnt der Plan mit Technik und baut bis 400 m am Stück auf – dann legt ein Schwimmtest deine Tempi fest.';

  @override
  String get goalKindRace => 'Wettkampf';

  @override
  String get goalKindWeeks => 'Nur Planlänge';

  @override
  String get goalKindWeeksHint => 'Kein Wettkampf – ein Plan, der deine Form über die gewählten Wochen aufbaut, mit Entlastungswochen und ohne Tapering.';

  @override
  String get tabZones => 'Zonen';

  @override
  String get tabPlan => 'Soll/Ist';

  @override
  String get planProjected => 'Voraussichtlich fertig nach';

  @override
  String get planPlanned => 'Geplant';

  @override
  String get planDelta => 'ggü. Plan';

  @override
  String get planOnTarget => 'Intervalle im Ziel';

  @override
  String get planNow => 'läuft';

  @override
  String get planShort => 'Verkürzt';

  @override
  String get planNoneDone => 'Abgeschlossene Abschnitte erscheinen hier mit ihren Ist-Werten.';

  @override
  String planStepsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'danach noch $n Abschnitte',
      one: 'danach noch 1 Abschnitt',
    );
    return '$_temp0';
  }

  @override
  String get zoneWaiting => 'Warte auf Tempo…';

  @override
  String get zoneTimeIn => 'Zeit in Zone';

  @override
  String get zoneCurrent => 'Aktuelle Zone';

  @override
  String get wLongRunWalkDesc => 'Langer Lauf/Geh-Wechsel: derselbe Rhythmus wie in deinen anderen Läufen, mehr Wiederholungen – Zeit auf den Beinen für den Wettkampf. Plaudertempo, zügig gehen. Wächst etwa 10 min pro Woche.';

  @override
  String get wWalkBreaksNote => 'Nach je 10 min Laufen 1 min gehen (Galloway) – die Pausen schonen Beine und Gelenke. Lass sie weg, sobald es sich leicht anfühlt.';

  @override
  String wSwimContinuous(int meters) {
    return 'Am Stück schwimmen $meters m';
  }

  @override
  String get wSwimContinuousDesc => 'Den Hauptteil am Stück in lockerem, gleichmäßigem Tempo schwimmen – er wächst etwa 100 m pro Woche bis zu der Strecke, die dein Wettkampf ohne Pause verlangt.';

  @override
  String get progTitle => 'Dein Aufbau hinkt hinterher';

  @override
  String progLongShort(int pct) {
    return 'Deine langen Einheiten der letzten 3 Wochen erreichten nur $pct % des Plans.';
  }

  @override
  String get progLongMissed => 'Mehrere lange Einheiten – die Schlüsseleinheiten deines Aufbaus – sind ausgefallen.';

  @override
  String get progRunWalkNotAchieved => 'Die Lauf/Geh-Stufen wurden gekürzt oder fühlten sich schwer an (RPE ≥ 7) – geh erst weiter, wenn eine Stufe leicht fällt.';

  @override
  String get progHighEffort => 'Deine langen Einheiten fühlten sich sehr schwer an (RPE ≥ 8) – sie sollten locker sein.';

  @override
  String get progOptRepeatWeek => 'Diese Woche wiederholen, bevor der nächste Schritt kommt';

  @override
  String get progOptLaterRace => 'Einen späteren Wettkampf wählen';

  @override
  String get progOptShorter => 'Auf eine kürzere Distanz wechseln';

  @override
  String get progOptRunWalkRace => 'Den Wettkampf mit Lauf/Geh-Wechsel planen';

  @override
  String get targetSuggestBasisRace => 'aus deinen Bestzeiten';

  @override
  String get targetSuggestBasisEfforts => 'aus deinen letzten Läufen';

  @override
  String get targetSuggestBasisLevel => 'Grobe Schätzung nach deinem Level – eine Wettkampfzeit macht sie genauer';

  @override
  String get targetSuggestFinish => 'Ziel: ankommen – für diesen Wettkampf noch keine Zielzeit';

  @override
  String targetSuggestRange(String time, String fast, String slow) {
    return 'Realistisch: $time ($fast–$slow)';
  }

  @override
  String get restoreWorkoutTitle => 'Einheit fortsetzen?';

  @override
  String restoreWorkoutBody(String title, String day, String time) {
    return '$title – gestartet $day um $time. Die App wurde während der Einheit beendet; mach dort weiter, wo du aufgehört hast, oder verwirf sie.';
  }

  @override
  String get restoreWorkoutResume => 'Fortsetzen';

  @override
  String get restoreSummaryTitle => 'Einheit speichern?';

  @override
  String restoreSummaryBody(String title, String day, String time) {
    return '$title ($day, $time) wurde beendet, aber noch nicht gespeichert.';
  }

  @override
  String get restoreSummaryOpen => 'Zusammenfassung öffnen';

  @override
  String get restoreToday => 'heute';

  @override
  String get restoreYesterday => 'gestern';

  @override
  String get workoutRunsInBackground => 'Deine Einheit läuft im Hintergrund weiter.';

  @override
  String deletedAutoReverted(int count) {
    return 'Gelöscht – $count automatische Plananpassungen zurückgenommen';
  }

  @override
  String get writeFailed => 'Eine Änderung konnte nicht gespeichert werden. Bitte prüfe die Verbindung und versuche es erneut.';

  @override
  String get loadFailedTitle => 'Deine Daten konnten nicht geladen werden';

  @override
  String get loadFailedBody => 'Bitte prüfe deine Internetverbindung und versuche es erneut. Wenn es weiter passiert, melde dich ab und wieder an.';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountSub => 'Löscht dein Konto und alle deine Daten endgültig';

  @override
  String get deleteAccountConfirm1 => 'Alle deine Einheiten, Pläne, Programme, Ziele und Körperdaten werden endgültig gelöscht – auf allen Geräten. Das kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountConfirm2Title => 'Wirklich löschen?';

  @override
  String get deleteAccountConfirm2 => 'Gib LÖSCHEN ein, um zu bestätigen.';

  @override
  String get deleteAccountWord => 'LÖSCHEN';

  @override
  String get deleteAccountRunning => 'Deine Daten werden gelöscht…';

  @override
  String get deleteAccountDone => 'Dein Konto und alle Daten wurden gelöscht.';

  @override
  String get deleteAccountFailed => 'Löschen fehlgeschlagen – bitte versuche es erneut, wenn du online bist.';

  @override
  String get reauthTitle => 'Bestätige, dass du es bist';

  @override
  String get reauthBody => 'Zu deiner Sicherheit melde dich bitte noch einmal an, bevor du dein Konto löschst.';

  @override
  String get reauthGoogle => 'Weiter mit Google';

  @override
  String get reauthConfirm => 'Bestätigen';

  @override
  String feasLongDayDefault(String day, String time) {
    return 'Die lange Einheit am $day braucht bis zu $time – deutlich mehr als deine übrigen Einheiten. Der Plan plant sie so ein; trag die Zeit für diesen Tag selbst ein, falls sie nicht passt.';
  }

  @override
  String feasLongRunShare(int min) {
    return 'Deine übrigen Läufe sind zu kurz für den langen Lauf, den dieses Rennen braucht: Er darf höchstens die Hälfte der Woche und doppelt so lang wie dein zweitlängster Lauf sein. Plane für die anderen Läufe etwa $min min ein.';
  }

  @override
  String feasTargetConservative(String goal, String now, String pred) {
    return '$goal ist ein vorsichtiges Ziel: heute ~$now, realistisch am Wettkampftag ~$pred. Deine Renntempo-Einheiten laufen im realistischen Tempo.';
  }

  @override
  String wRunContinuous(int min) {
    return 'Dauerlauf $min min';
  }

  @override
  String get wShakeoutRunWalkDesc => 'Lockeres Auslaufen im Lauf-Geh-Rhythmus – nur lockern, mehr nicht. Lege heute Abend deine Wettkampfsachen bereit.';

  @override
  String get wShakeoutEasyDesc => '15 min ganz locker – nur lockern, mehr nicht. Lege heute Abend deine Wettkampfsachen bereit.';

  @override
  String get wMastersStrengthNote => 'Kraft-Tipp: Hänge an diese Einheit 15–20 min Kraft an (Kniebeugen, Ausfallschritte, Wadenheben, Unterarmstütz) – zweimal pro Woche erhält das mit zunehmendem Alter Muskeln, Knochen und Sehnen.';

  @override
  String wRaceLeg(String leg, String dist) {
    return '$leg $dist km – dein Renntempo für diesen Teil';
  }

  @override
  String get wRaceFinishDesc => 'Ziel ist das Ankommen: noch keine Zielzeit – starte langsamer als es sich richtig anfühlt, halte deinen Rhythmus und genieß das Finish.';

  @override
  String get wTriOpenWaterNote => 'Wettkampfvorbereitung: Orientierung im Becken üben (alle 6–9 Züge kurz nach vorn schauen); sobald es das Wasser zulässt, einige Einheiten im Freiwasser mit Neoprenanzug – in der Gruppe, nie allein.';

  @override
  String get stepSwimRaceFinishNote => 'Letztes Drittel im Renntempo – gleichmäßig, Technik halten';

  @override
  String get wLongSwimRaceDesc => 'Diese Woche schwimmst du das letzte Drittel der langen Einheit im Renntempo: üben, das Tempo zu halten, wenn du schon müde bist.';

  @override
  String wLongRideRacePace(int reps, int each) {
    return 'Lange Ausfahrt mit $reps × $each min Renntempo';
  }

  @override
  String get wLongRideRacePaceDesc => 'Lange Zone-2-Ausfahrt mit Blöcken in der Leistung, die du im Wettkampf fahren willst: gleichmäßig, aerodynamisch, essen und trinken wie im Rennen (alle 20–30 min).';

  @override
  String get stepRacePowerNote => 'Renntempo – gleichmäßig, wie im Wettkampf';

  @override
  String get wRideTempoDescIm => 'Wettkampfspezifisches Tempo bei 75–85 % FTP – die Belastung einer Ironman-Radstrecke: gleichmäßig, aerodynamisch, mit Verpflegung.';

  @override
  String get wRideTempoDescFondo => 'Wettkampfspezifisches Tempo bei 75–85 % FTP – die Dauerbelastung langer Anstiege und einer schnellen Gruppe: gleichmäßig einteilen, mit Verpflegung.';

  @override
  String get wRideTempoBaseDesc => 'Tempo bei 76–90 % FTP: aerobe Kraft für lange Belastungen – kontrolliert, eine Stufe unter dem Sweet Spot.';

  @override
  String get stepThresholdNote2 => 'Schwelle – 91–100 % FTP, kontrolliert';

  @override
  String wHillReps(int reps, int sec) {
    return 'Bergläufe $reps × $sec s';
  }

  @override
  String get wHillRepsDesc => 'Bergaufläufe an einem gleichmäßigen Anstieg (5–8 %): kräftig, kurze Schritte, aufrecht; locker hinunter traben oder gehen. Baut die Kraft für die Anstiege deines Ultras auf.';

  @override
  String get stepHillNote => 'Bergauf – hart, aber kontrolliert, nach Gefühl (ohne Tempovorgabe)';

  @override
  String get stepHillDownNote => 'Locker hinunter traben oder gehen';

  @override
  String wGymLoadDescNoDeload(int rir) {
    return 'Beende jeden Arbeitssatz mit etwa $rir Wdh. im Tank. Sätze, Wiederholungsbereich und Gewichtsvorschlag stehen bei jeder Übung.';
  }

  @override
  String get wGymRegressionNote => 'Erste Wochen: leichtere Varianten der technisch anspruchsvollen Übungen (Latziehen statt Klimmzügen, Rumänisches Kreuzheben mit Kurzhanteln statt Kreuzheben mit der Langhantel, Reverse Crunches statt hängendem Beinheben) – die vollen Übungen folgen, sobald die Technik sitzt.';

  @override
  String get recalWhyFatigueRecovery => 'Seit zwei Wochen fühlen sich die Einheiten härter an als geplant: Die nächsten 7 Tage sind eine Entlastungswoche (weniger Umfang, keine Intensität). Danach kommen die Qualitätseinheiten mit weniger Wiederholungen zurück.';

  @override
  String get recalWhyFatigueCheck => 'Auch nach der Entlastungswoche noch härter als geplant: Prüfe Schlaf, Krankheit und Stress – und überlege eine langsamere Zielzeit. Die Qualitätseinheiten bleiben, mit weniger Wiederholungen.';

  @override
  String get recalWhyGoalAtRisk => 'Mit dem Training der letzten Wochen ist das Wettkampfziel schwer erreichbar (lange Läufe oder Wochenumfang weit von dem, was der Wettkampf braucht) – überlege einen späteren Wettkampf oder eine kürzere Distanz.';

  @override
  String get recalWhyRepeatStage => 'Die Laufen/Gehen-Einheiten waren anstrengend (RPE über 5) oder wurden abgebrochen: Die kommende Woche wiederholt deine aktuelle Stufe, statt aufzusteigen.';

  @override
  String get recalWhyMoveLong => 'Lange Läufe sind ausgefallen, die übrigen Läufe wurden gemacht: Der nächste lange Lauf rückt auf einen Trainingstag mit mehr Zeit – die lockeren Läufe bleiben, wie sie sind.';

  @override
  String get fcReasonFatigue => 'Einheiten zuletzt härter als geplant';

  @override
  String get summaryPlanDone => 'Plan erfüllt – stark!';

  @override
  String get summaryPartial => 'Kurz und knapp – jede Einheit zählt.';

  @override
  String get summaryFree => 'Gut gemacht – Einheit erledigt.';

  @override
  String get summaryTooShortTitle => 'Zu kurz zum Speichern?';

  @override
  String get summaryTooShortBody => 'Weniger als eine Minute oder keine Strecke aufgezeichnet.';

  @override
  String get saveAnyway => 'Trotzdem speichern';

  @override
  String finishOpenSets(int n, int total) {
    return '$n von $total Sätzen offen.';
  }

  @override
  String get keepTraining => 'Weiter trainieren';

  @override
  String get planBehind => 'hinter Plan';

  @override
  String get planAhead => 'vor Plan';

  @override
  String get planOnPlan => 'im Plan';

  @override
  String get todayPlannedTitle => 'Heute geplant';

  @override
  String todayPlannedBody(String title) {
    return '$title – geführt starten?';
  }

  @override
  String get startGuided => 'Geführt starten';

  @override
  String get startFree => 'Frei starten';

  @override
  String rxToday(int sets, int reps, String load) {
    return 'Heute: $sets × $reps @ $load';
  }

  @override
  String rxTodayList(String list, String load) {
    return 'Heute: $list Wdh. @ $load';
  }

  @override
  String get amrapLastSet => 'Letzter Satz: so viele Wdh. wie möglich – 1 vor dem Versagen aufhören.';

  @override
  String programPreviewSets(int sets) {
    return '$sets Sätze';
  }

  @override
  String get raceToday => 'heute ist Wettkampftag';

  @override
  String phaseWeekOf(String phase, int n, int total) {
    return '$phase (Woche $n/$total)';
  }

  @override
  String get raceType => 'Art des Wettkampfs';

  @override
  String alignChangesFocus(String focus) {
    return 'Dein Trainingsfokus wird auf $focus umgestellt, damit der Plan zu diesem Wettkampf passt.';
  }

  @override
  String get goalNeedsExercise => 'Wähle eine Übung.';

  @override
  String get goalNeedsDate => 'Wähle das Datum des Wettkampfs.';

  @override
  String get goalNeedsDistance => 'Wähle eine Distanz oder gib die km ein.';

  @override
  String get goalNeedsTarget => 'Gib ein Ziel größer als 0 ein.';

  @override
  String get deleteGoalTitle => 'Ziel löschen?';

  @override
  String goalDeleted(String title) {
    return '„$title“ gelöscht';
  }

  @override
  String eventSubFor(String examples) {
    return 'Füge einen Wettkampf hinzu (z. B. $examples) und erhalte einen Countdown. Optional.';
  }

  @override
  String get recreatePlan => 'Plan neu erstellen';

  @override
  String get summaryTitle => 'Prüfen & erstellen';

  @override
  String get summarySub => 'Dein Plan wird mit diesen Einstellungen neu erstellt.';

  @override
  String get summaryChanges => 'Das ändert sich:';

  @override
  String get summaryNoChanges => 'Nichts – der Plan wird mit denselben Einstellungen neu erstellt.';

  @override
  String get summaryWeek => 'Trainingswoche';

  @override
  String get summaryRace => 'Wettkampf';

  @override
  String get noRace => 'kein Wettkampf';

  @override
  String planWeeksN(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get hiddenShort => 'gefiltert';

  @override
  String get secureGuestTitle => 'Sichere deine Daten';

  @override
  String get secureGuestBody => 'Du trainierst als Gast – verknüpfe E-Mail oder Google, damit deine Einheiten und dein Plan nicht verloren gehen.';

  @override
  String get secureGuestButton => 'E-Mail oder Google verknüpfen';

  @override
  String get guestLogoutTitle => 'Als Gast abmelden?';

  @override
  String get guestLogoutBody => 'Als Gast abmelden löscht alle Daten auf diesem Gerät.';

  @override
  String get guestLogoutAnyway => 'Trotzdem abmelden';

  @override
  String get guestSecureFirst => 'Erst sichern';

  @override
  String experienceIs(String value) {
    return 'Erfahrung: $value';
  }

  @override
  String get planGone => 'Diese Einheit gibt es nicht mehr.';

  @override
  String get logAsDone => 'Als erledigt eintragen';

  @override
  String planMoved(String title, String date) {
    return '$title auf $date verschoben';
  }

  @override
  String get planLogMoved => 'Einheit verschoben';

  @override
  String planLogCreated(String date) {
    return 'Plan erstellt – Start am $date';
  }

  @override
  String get legendDone => 'erledigt';

  @override
  String get legendPlanned => 'geplant';

  @override
  String get legendOnTarget => 'wie geplant';

  @override
  String get legendPartly => 'teilweise';

  @override
  String get legendOff => 'stark abweichend';

  @override
  String get legendMissed => 'verpasst / zu wenig';

  @override
  String replacesDayWorkout(String day) {
    return 'ersetzt $day-Einheit';
  }

  @override
  String get painWhere => 'Wo tut es weh?';

  @override
  String get painFoot => 'Fuß / Sprunggelenk';

  @override
  String get painArm => 'Arm / Hand';

  @override
  String get painNeck => 'Nacken';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String countAsReplacement(String title, String day) {
    return 'Als Ersatz für $title ($day) werten?';
  }

  @override
  String get countAsReplacementSub => 'Du hast sie aus einer Einheit eines anderen Tags gestartet. Ja hakt diese Einheit ab, Nein lässt sie offen.';

  @override
  String replacementDone(String title) {
    return '$title zählt als erledigt';
  }

  @override
  String plannedLine(String title, String amount) {
    return 'Geplant: $title · $amount';
  }

  @override
  String fulfilledPct(String share) {
    return '$share erfüllt';
  }

  @override
  String coachRpeHigh(String title, int n) {
    return '$title mit RPE $n – nächste Woche etwas ruhiger?';
  }

  @override
  String get coachAsPlanned => 'Wie geplant erledigt – gut gemacht.';

  @override
  String get coachShorter => 'Kürzer als geplant – kein Problem, nicht nachholen.';

  @override
  String get coachLonger => 'Länger als geplant – halte die nächste lockere Einheit wirklich locker.';

  @override
  String maxRepsN(int reps) {
    String _temp0 = intl.Intl.pluralLogic(
      reps,
      locale: localeName,
      other: '$reps Wdh.',
      one: '1 Wdh.',
    );
    return '$_temp0';
  }

  @override
  String predictionBasis(String dist, String time, String source) {
    return 'Basierend auf $dist in $time ($source)';
  }

  @override
  String get predictionFromProfile => 'Profil';

  @override
  String predictionFromRun(String date) {
    return 'Lauf am $date';
  }

  @override
  String get recalSubtitle => 'Vorschläge für die nächsten 2 Wochen';

  @override
  String get termKeyTitle => 'Schlüsseleinheit';

  @override
  String get termKeyBody => 'Die ein bis zwei Einheiten einer Woche, die deine Form am meisten voranbringen – z. B. Intervalle, ein Tempolauf oder der lange Lauf. Die übrigen Einheiten sind locker und helfen dir, dich dafür zu erholen.';

  @override
  String get termKeyTip => 'Eine verpasst? „Woche anpassen“ legt sie auf einen freien Tag – nie direkt neben eine andere Schlüsseleinheit.';

  @override
  String get termLoadWeekTitle => 'Belastungswoche';

  @override
  String get termLoadWeekBody => 'Eine normale Trainingswoche, in der Umfang oder Intensität etwas steigen. Auf zwei bis vier Belastungswochen folgt eine Entlastungswoche.';

  @override
  String get termLoadWeekTip => 'Etwas Müdigkeit am Ende einer Belastungswoche ist normal – die Entlastungswoche macht daraus Form.';

  @override
  String get termDeloadTitle => 'Entlastungswoche';

  @override
  String get termDeloadBody => 'Alle 3–5 Wochen eine leichtere Woche (etwa 60–70 % des Umfangs, wenig Intensität). In dieser Zeit passt sich dein Körper an das Training an.';

  @override
  String get termDeloadTip => 'Den fehlenden Umfang nicht nachholen – die Woche soll sich leicht anfühlen.';

  @override
  String get termStridesTitle => 'Steigerungen';

  @override
  String get termStridesBody => 'Kurze Beschleunigungen über 15–30 s bis zu einem schnellen, aber lockeren Tempo, dazwischen volle Erholung. Sie verbessern Laufökonomie und Technik, ohne zu ermüden.';

  @override
  String get termStridesTip => 'Locker bleiben: Schultern entspannt, schnelle Schritte – es ist kein Sprint.';

  @override
  String get termFartlekTitle => 'Fahrtspiel';

  @override
  String get termFartlekBody => 'Schnellere und lockere Abschnitte wechseln nach Gefühl oder nach Zeit, ohne feste Strecken. Eine spielerische Art, Tempo in einen Lauf zu bringen.';

  @override
  String get termFartlekTip => 'Nutze Orientierungspunkte: schneller bis zur nächsten Laterne, locker bis zur nächsten Ecke.';

  @override
  String get termAcwrTitle => 'ACWR – Akut-chronische Belastung';

  @override
  String get termAcwrBody => 'Deine Belastung der letzten 7 Tage (akut, ATL) im Vergleich zu deiner Durchschnittswoche der letzten 28 Tage (chronisch, CTL). Zwischen 0,8 und 1,3 baust du Form bei geringem Verletzungsrisiko auf; über 1,5 steigt das Risiko deutlich.';

  @override
  String get termAcwrTip => 'Hoher Wert? Plane einen lockeren Tag ein, statt noch mehr draufzulegen.';

  @override
  String daysLeftInline(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'noch $days Tage',
      one: 'noch 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String fcReasonSessionsSkipped(int done, int total) {
    return '$done von $total geplanten Einheiten der letzten 4 Wochen erledigt – Regelmäßigkeit macht die Form, ausgelassene Einheiten summieren sich';
  }

  @override
  String fcReasonKeyMissed(int done, int total) {
    return '$done von $total Schlüsseleinheiten (Tempo, Intervalle, lange Läufe) der letzten 4 Wochen erledigt';
  }

  @override
  String recalWhySessionsSkipped(int done, int total) {
    return 'In den letzten 4 Wochen hast du $done von $total Einheiten gemacht. Wenn bestimmte Tage nie klappen, verschiebe oder streiche sie im Wochenplan, statt sie auszulassen.';
  }

  @override
  String recalWhyKeyMissed(int done, int total) {
    return 'In den letzten 4 Wochen hast du $done von $total Schlüsseleinheiten (Tempo, Intervalle, lange Läufe) gemacht – sie tragen die Wettkampfvorbereitung, gib ihnen Vorrang vor lockeren Läufen.';
  }

  @override
  String recalWhyGoalAtRiskTime(String forecast, String goal) {
    return 'Die Zielprognose liegt bei $forecast – die Zielzeit $goal ist mit der aktuellen Form schwer erreichbar. Überlege, die Zielzeit anzupassen.';
  }

  @override
  String wRaceRealistic(String time, String pace) {
    return 'Mit deiner Form realistisch: $time ($pace) – fühlst du dich nach der Hälfte gut, steigere.';
  }

  @override
  String get recalWhyRpeLowSpaced => 'Deine Schlüsseleinheiten fielen dir wieder leicht – der Umfang wurde aber gerade erst erhöht und bleibt diese Woche (höchstens jede zweite Woche, 3× pro Plan). Bleibt es leicht, ziehen die Zielwerte nach.';

  @override
  String get recalWhyTaper => 'Taper: weniger ist mehr – der Umfang ist bewusst reduziert und bleibt so. Die Form geht in zwei Wochen nicht verloren, die Frische für den Wettkampf kommt aus der Erholung.';

  @override
  String recalWhyTaperOverdo(int pct) {
    return 'Taper: Letzte Woche hast du $pct % des geplanten Umfangs trainiert. Jetzt ist weniger mehr – halte dich an den reduzierten Umfang, die Form für den Wettkampf kommt aus der Erholung.';
  }

  @override
  String progStageHeld(int weeks) {
    return 'Der Aufbau steht seit $weeks Wochen (Stufe wiederholt oder lange Einheit gekürzt).';
  }

  @override
  String progStageHeldRisk(int weeks) {
    return 'Der Aufbau steht seit $weeks Wochen und der Wettkampf ist nah – das Ziel ist gefährdet.';
  }

  @override
  String feasLongRunShare2(int min) {
    return 'Deine übrigen Läufe sind zu kurz für den langen Lauf, den dieses Rennen braucht: Bei drei Läufen pro Woche darf er etwa zwei Drittel der Woche ausmachen. Plane für die anderen Läufe etwa $min min ein.';
  }

  @override
  String feasLongRunFinish(String have, String need) {
    return 'Dein längster langer Lauf erreicht vor dem Rennen nur etwa $have km – dieses Rennen braucht etwa $need km. Der Plan behandelt das Rennen deshalb als Finish-Ziel, ohne Zielzeit.';
  }

  @override
  String get zGoalPace => 'Wettkampftempo';

  @override
  String get mismatchTitle => 'Ziel und Plan passen nicht zusammen';

  @override
  String mismatchFocusBody(String goal, String focus, String newFocus) {
    return 'Dein Ziel $goal passt nicht zu deinem Fokus $focus – Fokus auf $newFocus ändern und Plan anpassen?';
  }

  @override
  String mismatchPlanBody(String goal) {
    return 'Dein Plan ist noch nicht auf $goal ausgerichtet – Plan bis zum Wettkampftag anpassen?';
  }

  @override
  String mismatchMissing(String sports) {
    return 'Im Plan fehlt bisher: $sports.';
  }

  @override
  String get mismatchAdjust => 'Anpassen';

  @override
  String get later => 'Später';

  @override
  String get alignStatusAligned => 'Dein Plan ist auf diesen Wettkampf ausgerichtet';

  @override
  String get alignStatusAlignedSub => 'Ein neues Datum oder eine neue Distanz baut den Plan bis zum Wettkampftag neu (erledigte Einheiten bleiben).';

  @override
  String get alignStatusNotAligned => 'Dein Plan ist aktuell nicht auf diesen Wettkampf ausgerichtet.';

  @override
  String alignFocusWizard(String focus) {
    return 'Der Fokus wird auf $focus umgestellt. Beim Speichern öffnen sich die Planeinstellungen, damit du deine Woche (mit allen Disziplinen) festlegst – die Prüfung des Ziels folgt dort.';
  }

  @override
  String weekMissingSport(String sports, String focus) {
    return '$sports ist noch nicht in deiner Woche – ein $focus-Plan braucht mindestens eine Einheit davon.';
  }

  @override
  String get summaryNewPlan => 'Dein neuer Plan';

  @override
  String summaryWeekStructure(String structure) {
    return 'Woche: $structure';
  }

  @override
  String summaryPlanLengthEvent(int weeks) {
    return 'Länge: $weeks Wochen bis zum Wettkampftag';
  }

  @override
  String summaryPlanLength(int weeks) {
    return 'Länge: $weeks Wochen';
  }

  @override
  String planWeeksCurrent(int weeks) {
    return '$weeks Wochen · aktuell';
  }

  @override
  String get planLogReplace => 'Als Ersatz gewertet';

  @override
  String get planLogReplaceReason => 'Eine Einheit von einem anderen Tag hat diese Einheit abgehakt.';

  @override
  String get planLogUnlink => 'Verknüpfung gelöst';

  @override
  String get planLogUnlinkReason => 'Ältere Versionen haben Einheiten mit Trainings abgehakt, die mehr als einen Tag entfernt lagen. Sie sind wieder offen – bei der Einheit kannst du sie als Ersatz werten.';

  @override
  String get planLogTickedOff => 'abgehakt';

  @override
  String get planLogReopened => 'wieder offen';

  @override
  String get replacementUndo => 'Nicht mehr als Ersatz werten';

  @override
  String replacementUndone(String title) {
    return '$title ist wieder offen';
  }

  @override
  String coachMuchShorter(String share) {
    return 'Nur $share des Plans – stark abweichend, zählt aber als erledigt. Fühlst du dich gut, ergänze etwas an einem lockeren Tag; sonst einfach weitermachen.';
  }

  @override
  String partlyDone(String share) {
    return 'teilweise erledigt ($share)';
  }

  @override
  String doneOnDay(String day) {
    return 'erledigt am $day';
  }

  @override
  String get beforePlanStart => 'vor Planstart';

  @override
  String get workoutsDone => 'Einheiten erledigt';

  @override
  String extraSessionsN(int n) {
    return '+$n extra';
  }

  @override
  String planCompletionMinutes(int pct) {
    return 'Plan zu $pct % erfüllt (fällige geplante Minuten)';
  }

  @override
  String get quickRecord => 'Aufzeichnen';

  @override
  String get noXpTooShort => 'Keine XP – zu kurz für ein Training';

  @override
  String coachQRace(String race) {
    return 'Wie bereite ich mich am besten auf $race vor?';
  }

  @override
  String get coachQTri => 'Wie kombiniere ich Schwimmen, Radfahren und Laufen in einer Woche?';

  @override
  String get coachQGym => 'Wie werde ich stärker, ohne zu stagnieren?';

  @override
  String get coachQRide => 'Wie werde ich auf dem Rad schneller?';

  @override
  String get coachQSwim => 'Wie schwimme ich ökonomischer?';

  @override
  String get fromPlanTitle => 'Aus dem Plan übernommen';

  @override
  String fromPlanGymLine(int count, int sets, String volume) {
    return '$count Übungen · $sets Sätze · $volume';
  }

  @override
  String get fromPlanHintGym => 'Gespeichert mit den Übungen, Sätzen und Gewichten aus dem Plan. Weicht etwas ab? Danach in der Einheit unter „Bearbeiten“ korrigieren.';

  @override
  String get fromPlanHintCardio => 'Dauer und Strecke kommen aus dem Plan – trag ein, was du wirklich gemacht hast.';

  @override
  String get fromPlanBadge => 'Aus Plan übernommen';

  @override
  String get fromPlanNoteGym => 'nicht aufgezeichnet: zählt für Volumen, Sätze, Statistik und Plan, setzt aber keine Rekorde. Über „Bearbeiten“ trägst du ein, was du wirklich bewegt hast.';

  @override
  String get fromPlanNoteCardio => 'nicht aufgezeichnet: zählt für Strecke, Zeit und Plan, setzt aber keine Bestleistungen und passt keine Tempovorgaben an. Über „Bearbeiten“ trägst du deine echten Werte ein.';

  @override
  String get summaryTooShortGym => 'Weniger als eine Minute trainiert.';

  @override
  String get summaryTooShortTime => 'Weniger als eine Minute aufgezeichnet.';

  @override
  String get summaryNoDistanceTitle => 'Keine Strecke aufgezeichnet';

  @override
  String get summaryNoDistanceBody => 'Das GPS hat keine Strecke erfasst. Speichere trotzdem und trag die Distanz danach unter „Bearbeiten“ ein – oder verwirf die Einheit.';

  @override
  String get summaryNoLapsTitle => 'Keine Bahnen gezählt';

  @override
  String get summaryNoLapsBody => 'Es wurden keine Bahnen gezählt. Speichere trotzdem und trag Bahnen oder Strecke danach unter „Bearbeiten“ ein – oder verwirf die Einheit.';

  @override
  String get summaryTooLittle => 'Weniger als 10 % des Plans – das zählt noch nicht als erledigt.';

  @override
  String get editSessionHintGym => 'Korrigiere Gewichte, Wiederholungen und Sätze, füge Übungen hinzu oder entferne sie.';

  @override
  String get editSessionHintCardio => 'Korrigiere fehlerhafte Messungen oder Eingaben.';

  @override
  String get editSessionHintSwim => 'Korrigiere Bahnen, Beckenlänge oder Strecke – Bahnen × Beckenlänge ergeben die Distanz.';

  @override
  String get removeExercise => 'Übung entfernen';

  @override
  String exerciseRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get moreActions => 'Mehr';

  @override
  String complianceNotCounted(int pct) {
    return 'Nicht gewertet – nur $pct % vom Plan';
  }

  @override
  String notCountedShort(String share) {
    return 'nicht gewertet ($share)';
  }

  @override
  String setsOfPlanned(int done, int total) {
    return '$done von $total Sätzen';
  }

  @override
  String coachNotCounted(String share) {
    return 'Nur $share des Plans – zu wenig, um als erledigt zu zählen. Hast du mehr gemacht, korrigiere die Einheit; sonst ist die Einheit noch offen.';
  }

  @override
  String coachNotCountedSets(String share) {
    return 'Nur $share der geplanten Sätze – zu wenig, um als erledigt zu zählen. Hast du mehr Sätze gemacht, trag sie in der Einheit nach; sonst ist die Einheit noch offen.';
  }

  @override
  String coachMuchFewerSets(String share) {
    return 'Nur $share der geplanten Sätze – stark abweichend, zählt aber als erledigt. Nicht nachholen – die nächste Krafteinheit startet wieder normal.';
  }

  @override
  String get coachFewerSets => 'Weniger Sätze als geplant – kein Problem, nicht nachholen.';

  @override
  String get coachMoreSets => 'Mehr Sätze als geplant – gönn dir bis zur nächsten Krafteinheit genug Erholung.';

  @override
  String get termComplianceTitle => 'Plan-Erfüllung – so wird eine Einheit gewertet';

  @override
  String termComplianceBody(String greenMin, String greenMax, String yellowMin, String yellowMax, String countMin) {
    return 'Mit dem Plan verglichen wird die Strecke (Ausdauer mit Distanz; strukturierte Einheiten: Strecke oder Dauer, je nachdem, was näher am Plan liegt), die erledigten Arbeitssätze (Kraft – Sätze mit deutlich weniger Gewicht oder Wiederholungen zählen teilweise) oder sonst die Dauer. Eine mit den Planwerten als erledigt eingetragene Einheit zählt wie geplant.\n\n✓ grün, wie geplant: $greenMin–$greenMax\n✓ gelb, teilweise / über Plan: $yellowMin bis unter $greenMin oder über $greenMax bis $yellowMax\n✓ orange, stark abweichend: $countMin bis unter $yellowMin oder über $yellowMax\n✕ rot: verpasst, oder unter $countMin – ein abgebrochener Start zählt nicht als erledigt.';
  }

  @override
  String termComplianceTip(String half, String over) {
    return 'Teilweise oder stark abweichend zählt trotzdem als erledigt – der Plan passt sich erst an, wenn es sich wiederholt. Dafür braucht ein langer Lauf oder eine Schlüsseleinheit mindestens $half des Plans, und deutlich mehr als geplant (über $over) zählt wie eine zu harte Einheit.';
  }

  @override
  String get feasTitleNote => 'Hinweis zu deinem Plan';

  @override
  String feasLongRunTimeCap(String time, String have, String race) {
    return 'Deine langen Läufe enden bei $time – bei deinem lockeren Tempo sind das etwa $have km (viele Pläne gehen bis $race km). Länger am Stück bringt mehr Verletzungsrisiko und Erholungsbedarf als Fitness. Daher: Ankommen ist das Ziel – ruhig loslaufen und von Beginn an kurze Gehpausen einplanen (z. B. 1 min alle 10 min).';
  }

  @override
  String durationRange(String from, String to) {
    return 'Wähle eine Zeit zwischen $from und $to.';
  }

  @override
  String bestTimeFor(String distance) {
    return 'Bestzeit · $distance';
  }

  @override
  String swimTestFor(String distance) {
    return 'Schwimmtest · $distance';
  }

  @override
  String get noTargetTime => 'Keine Zielzeit – ankommen';

  @override
  String get raceWhen => 'Wann ist der Wettkampf?';

  @override
  String get raceByDate => 'Datum';

  @override
  String get raceByWeeks => 'Planlänge';

  @override
  String get raceByWeeksHint => 'Noch kein Termin? Wähle die Planlänge: Der Wettkampf liegt am Tag deiner langen Einheit in der letzten Woche, und der Plan baut darauf hin – inklusive Tapering.';

  @override
  String raceOnDate(String date) {
    return 'Wettkampf am $date';
  }

  @override
  String get progFromPlan => 'letzte Einheit aus dem Plan übernommen, nicht gemessen – Gewicht und Wiederholungen noch einmal';

  @override
  String get progRepCap => 'so viele Wiederholungen, wie dieser Bereich vorsieht – steigere mit Zusatzgewicht oder einer schwereren Variante';

  @override
  String feasRunFrequency(String have, String need) {
    return 'Läufe pro Woche in deinem Plan: $have. Diese Distanz braucht mindestens $need Läufe pro Woche (oder einen deutlich höheren Wochenumfang), damit dein Körper die Belastung des langen Laufs verträgt – plane mehr Lauftage ein.';
  }

  @override
  String feasRideFrequency(String have, String need) {
    return 'Radeinheiten pro Woche in deinem Plan: $have. Dieses Rennen braucht mindestens $need Radeinheiten pro Woche – plane mehr Radtage ein.';
  }

  @override
  String feasSwimFrequency(String have, String need) {
    return 'Schwimmeinheiten pro Woche in deinem Plan: $have. Dieses Rennen braucht mindestens $need Schwimmeinheiten pro Woche, damit Technik und Am-Stück-Schwimmen wachsen – plane mehr Schwimmeinheiten ein.';
  }

  @override
  String feasLongRunRamp(String have, int weeks, String need) {
    return 'Von deinem jetzigen Stand aus wächst dein langer Lauf bei sicherer Steigerung (höchstens +10 % bzw. +1 km pro Woche) in $weeks Wochen nur bis etwa $have km – dieses Rennen braucht etwa $need km.';
  }

  @override
  String feasLongRunShare3(int pct, int min) {
    return 'Deine übrigen Läufe sind zu kurz für den langen Lauf, den dieses Rennen braucht: Er sollte höchstens etwa $pct % deiner Wochenkilometer ausmachen. Plane für die anderen Läufe etwa $min min ein.';
  }

  @override
  String feasLongSwimOpen(int meters, int target) {
    return 'Bis zum Wettkampf reicht dein Am-Stück-Schwimmen nur für etwa $meters m – für dieses Freiwasser-Rennen solltest du mindestens etwa $target m ohne Pause schwimmen können. Im offenen Wasser gibt es keinen Beckenrand: nie allein schwimmen, mit Neoprenanzug und Schwimmboje.';
  }

  @override
  String get wOpenWaterSafety => 'Sicherheit im Freiwasser: nie allein schwimmen (Gruppe oder Begleitboot), Neoprenanzug, Schwimmboje und auffällige Badekappe; bei Kälte, Krampf oder Panik auf den Rücken drehen und eine Hand heben.';

  @override
  String get wGymRaceWeekNote => 'Wettkampf in Sicht: keine schweren Beinübungen mehr (die letzte schwere Beineinheit liegt 7–10 Tage vor dem Rennen) – nur Oberkörper, Rumpf und Mobilität, locker.';

  @override
  String get stepFartlekSoftNote => 'Zügig, aber kontrolliert – Anstrengung 6–7 von 10, kurze Sätze sprechen geht noch, kein Sprint';

  @override
  String get stepBrickEasyNote => 'Locker weiterlaufen (Anstrengung 4–5 von 10) – die Beine gewöhnen sich an den Wechsel, noch kein Renntempo';

  @override
  String get feasLongRunRampHint => 'Läufst du schon länger? Trag deinen längsten Lauf der letzten Wochen ein – der Plan baut dann darauf auf.';

  @override
  String summaryRemoveRaceGoal(String name, String date) {
    return 'Wettkampfziel „$name“ ($date) entfernen';
  }

  @override
  String get summaryRemoveRaceGoalOn => 'Dein neuer Plan hat keinen Wettkampf – das Ziel, auf das der bisherige Plan ausgerichtet war, wird entfernt.';

  @override
  String get summaryRemoveRaceGoalOff => 'Das Ziel bleibt: Countdown und der Hinweis „Ziel und Plan passen nicht zusammen“ bleiben, bis du einen Plan wieder darauf ausrichtest.';

  @override
  String fcEarlyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nach $count weiteren Einheiten des Plans nutzt die Prognose deine Trainingsdaten.',
      one: 'Nach einer weiteren Einheit des Plans nutzt die Prognose deine Trainingsdaten.',
    );
    return '$_temp0';
  }

  @override
  String plannedNotCountedSub(String date, String duration) {
    return 'Deine Einheit am $date ($duration) war zu kurz, um für diese Einheit zu zählen – sie bleibt offen.';
  }

  @override
  String overPlanShort(String share) {
    return 'über Plan ($share)';
  }

  @override
  String farOffShort(String share) {
    return 'stark abweichend ($share)';
  }

  @override
  String logCompletesPlanOf(String day) {
    return 'Zählt für die Einheit vom $day';
  }

  @override
  String get invalidNumber => 'Bitte eine Zahl eingeben';

  @override
  String get withoutDistance => 'Ohne Distanz';

  @override
  String get enterDistanceHint => 'z. B. vom Laufband';

  @override
  String streakThisWeekShort(int done, int target) {
    return 'Diese Woche: $done von $target Trainingstagen';
  }

  @override
  String get freeGymTitle => 'Freies Training';

  @override
  String sessionEndsInFuture(String time) {
    return 'Mit diesem Start und dieser Dauer würde die Einheit in der Zukunft enden ($time) – bitte prüfe beides.';
  }

  @override
  String sessionPaceImplausible(String pace) {
    return 'Durchschnitt $pace – kaum möglich. Stimmen Distanz und Dauer?';
  }

  @override
  String recNow(int count) {
    return 'jetzt $count×';
  }

  @override
  String get yourSwimZones => 'Deine Schwimmzonen';

  @override
  String get swimCssEstimated => 'Geschätzt aus deinen 400 m – mit der 200-m-Zeit wird die CSS genau.';

  @override
  String get swimTestOnly200 => 'Für den CSS-Test brauchst du auch die 400-m-Zeit – die 200 m allein reichen nicht.';

  @override
  String get swimTestImplausible => 'Die beiden Zeiten passen nicht zusammen: Normalerweise dauern die 400 m etwas mehr als doppelt so lange wie die 200 m (etwa das 2,0- bis 2,4-Fache). Bitte prüfe sie – bis dahin wird die CSS aus den 400 m geschätzt.';

  @override
  String get calJumpCurrentWeek => 'Zurück zur aktuellen Woche';

  @override
  String get calJumpTodayMonth => 'Zurück zum aktuellen Monat';

  @override
  String get progHoldLonger => 'alle Sätze gehalten – etwas länger';

  @override
  String get progHoldAddLoad => 'oberes Ende der Haltezeit – mit Zusatzgewicht, wieder kürzer';

  @override
  String get progHoldTop => 'oberes Ende der Haltezeit – halten (schwerer über eine Variante)';

  @override
  String get progHoldMissed => 'Haltezeit verfehlt – gleiche Zeit noch einmal';

  @override
  String get progHoldShorter => 'Haltezeit zweimal verfehlt – etwas kürzer';

  @override
  String rxTodayText(String text) {
    return 'Heute: $text';
  }

  @override
  String get holdTime => 'Haltezeit';

  @override
  String holdStartBtn(String time) {
    return 'Start $time';
  }

  @override
  String get holdStop => 'Stopp';

  @override
  String get holdRunning => 'Halten';

  @override
  String get holdOvertime => 'Ziel erreicht';

  @override
  String get holdAutoDone => 'Bei Zielzeit abhaken und Pause starten';

  @override
  String get holdLogWithout => 'Ohne Timer eintragen';

  @override
  String get timedMode => 'Auf Zeit (halten)';

  @override
  String get holdRange => 'Haltezeit-Bereich';

  @override
  String get holdRangeHint => 'Jeder Satz hat seine Zielzeit gehalten → nächstes Mal 5–10 s länger, bis zum oberen Ende; dann mit Zusatzgewicht und wieder kürzer.';

  @override
  String get volumeInclBody => 'inkl. Körpergewicht';

  @override
  String volumeInclBodyKg(String weight) {
    return 'inkl. Körpergewicht ($weight)';
  }

  @override
  String get longestHold => 'Längstes Halten';

  @override
  String longestHoldN(String time) {
    return 'längstes Halten $time';
  }

  @override
  String infoAbout(String title) {
    return 'Info zu $title';
  }

  @override
  String get logRirSettingShort => 'Wiederholungen im Tank (RIR) je Satz';

  @override
  String get logRirSettingInfo => 'Nach jedem Satz gibst du an, wie viele Wiederholungen du noch geschafft hättest (Reps in Reserve, RIR). Hat eine Übung keine Schnellbewertung, nutzt Strive diese Werte für die nächste Steigerung. Die Bewertung pro Übung bleibt in jedem Fall.';

  @override
  String get trainingReminderShort => 'An geplanten Trainingstagen';

  @override
  String get vibrationInfo => 'Vibriert, wenn ein Pausen- oder Haltetimer abläuft, bei jedem neuen Abschnitt eines strukturierten Trainings und bei jedem Kilometer einer aufgezeichneten Aktivität – auch wenn die Vibration bei Berührung in den Systemeinstellungen aus ist.';

  @override
  String get reorderHint => 'Ordner und Programme lang drücken, um sie zu verschieben.';

  @override
  String get restoreBuiltins => 'Standardprogramme wiederherstellen';

  @override
  String restoreBuiltinsAdd(String names) {
    return 'Im Originalzustand hinzugefügt werden: $names.';
  }

  @override
  String restoreBuiltinsKeep(String names) {
    return 'Deine geänderten Versionen bleiben als eigene Programme erhalten ($names). Neue Pläne verwenden wieder die Originale.';
  }

  @override
  String get restoreAction => 'Wiederherstellen';

  @override
  String programsRestored(int count) {
    return '$count Programme wiederhergestellt';
  }

  @override
  String get ownVersionSuffix => 'eigene';

  @override
  String builtinChangedLine(String names) {
    return 'Geändert: $names';
  }

  @override
  String get builtinsAllOriginal => 'Alle Standardprogramme sind im Originalzustand vorhanden.';

  @override
  String get restoreBuiltinsSub => 'Fügt fehlende oder geänderte Standardprogramme im Originalzustand hinzu. Deine geänderten Versionen bleiben erhalten.';

  @override
  String movedToFolder(String folder) {
    return 'Nach $folder verschoben';
  }

  @override
  String get wGymDeloadNote4 => 'Entlastungswoche: gleiche Sätze wie im Programm, die Gewichte sind etwa 10 % leichter eingetragen. Sauber mit etwa 4 Wdh. im Tank trainieren – so baust du Ermüdung ab und kommst stärker zurück.';

  @override
  String get wGymLegsEasyNote => 'Beinübungen heute mit allen Sätzen, aber etwa 10–15 % leichter (etwa 4 Wdh. im Tank) – die Schlüsseleinheit morgen braucht frische Beine.';

  @override
  String wGymOverTimeNote(int total, int min) {
    return 'Das Programm dauert etwa $total min, für diesen Tag sind $min min eingeplant – nimm dir mehr Zeit oder wähle für diesen Tag ein kürzeres Programm.';
  }

  @override
  String get gymAssignTitle => 'Programme selbst zuweisen';

  @override
  String get gymAssignSub => 'Lege fest, welches Programm du an welchem Gym-Tag trainierst – eigene oder vorgefertigte. Sätze und Übungen kommen aus dem Programm, der Plan steuert Gewicht und Wdh. im Tank.';

  @override
  String get gymAssignAB => 'Woche A / Woche B abwechseln';

  @override
  String get gymAssignABSub => 'Zwei Wochen im Wechsel, z. B. A: Push, Pull, Beine · B: Pull, Beine, Push.';

  @override
  String get gymWeekA => 'Woche A';

  @override
  String get gymWeekB => 'Woche B';

  @override
  String get gymAssignPick => 'Programm wählen';

  @override
  String get gymAssignSearch => 'Programme durchsuchen';

  @override
  String get gymAssignNone => 'Keine Programme gefunden';

  @override
  String get gymAssignNoDays => 'Deine Woche hat noch keinen Gym-Tag – füge im Wochen-Schritt einen hinzu.';

  @override
  String get gymAssignSuggest => 'Vorschlag übernehmen';

  @override
  String get gymAssignBuiltin => 'Vorlage';

  @override
  String gymAssignWarnRepeat(String program, String dayPair) {
    return '$program an zwei Tagen hintereinander ($dayPair) – dieselben Muskeln brauchen etwa 48 h Erholung.';
  }

  @override
  String gymAssignWarnLegs(String program, String day) {
    return '$program am $day, dem Tag vor deiner langen Einheit – schwere Beine erschweren sie.';
  }

  @override
  String get holdGetReady => 'In Position gehen';

  @override
  String get holdLeadInSetting => '3-s-Countdown vor dem Halten';

  @override
  String get timerSound => 'Timer-Töne';

  @override
  String get timerSoundSub => 'Countdown und Ende beim Halten, Ende der Pause';

  @override
  String get wGymDeloadNote5 => 'Entlastungswoche: gleiche Sätze wie im Programm, die Gewichte sind etwa 10 % leichter eingetragen (Übungen mit Körpergewicht: ein paar Wiederholungen weniger). Sauber mit etwa 4 Wdh. im Tank trainieren – so baust du Ermüdung ab und kommst stärker zurück.';

  @override
  String get loadRaceLighter => 'Wettkampf in Sicht';

  @override
  String get loadLegsEasyLighter => 'Beine leichter vor der Schlüsseleinheit';

  @override
  String get gymGroupPush => 'Push';

  @override
  String get gymGroupPull => 'Pull';

  @override
  String get gymGroupLegs => 'Beine';

  @override
  String gymAssignWarnBackToBack(String program, String dayPair) {
    return '$program in zwei Einheiten hintereinander ($dayPair) – die anderen Programme warten eine ganze Einheit länger.';
  }

  @override
  String gymAssignWarnFrequency(String group, String freq, String other, String otherFreq) {
    return '$group nur $freq× pro Woche, $other $otherFreq× – ideal ist jeder Muskel etwa 2× pro Woche. Ohne eigene Zuweisung wechselt der Plan die Programme über die Wochen gleichmäßig ab.';
  }

  @override
  String programDeleteUsed(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Dein Plan verwendet es in $n anstehenden Einheiten – sie behalten ihre Übungen.',
      one: 'Dein Plan verwendet es in 1 anstehenden Einheit – sie behält ihre Übungen.',
    );
    return '$_temp0';
  }

  @override
  String folderDeleteUsed(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Dein Plan verwendet Programme dieses Ordners in $n anstehenden Einheiten – sie behalten ihre Übungen.',
      one: 'Dein Plan verwendet Programme dieses Ordners in 1 anstehenden Einheit – sie behält ihre Übungen.',
    );
    return '$_temp0';
  }

  @override
  String programDeleteAssigned(String weekdays) {
    return 'In deinen Planeinstellungen $weekdays zugewiesen – der Plan wählt für diese Tage wieder selbst ein Programm.';
  }

  @override
  String restoreKeepsAssigned(String weekdays) {
    return 'In deinen Planeinstellungen bleibt $weekdays deine Version zugewiesen.';
  }

  @override
  String get planProgramMissing => 'Das Programm dieser Einheit wurde gelöscht';

  @override
  String get planProgramMissingSub => 'Wähle ein Programm oder Übungen dafür – oder starte eine leere Einheit.';

  @override
  String get planProgramChoose => 'Programm wählen';

  @override
  String get startEmptyWorkout => 'Leer starten';

  @override
  String feasCapLine(String time, String have, String race) {
    return 'Deine langen Läufe enden bei $time – bei deinem lockeren Tempo sind das etwa $have km (viele Pläne gehen bis $race km).';
  }

  @override
  String feasCapLineUsual(String time, String have, String race) {
    return 'Deine langen Läufe enden normalerweise bei $time – bei deinem lockeren Tempo sind das etwa $have km (viele Pläne gehen bis $race km).';
  }

  @override
  String feasCapNotYourTime(String set, String day) {
    return 'Das liegt nicht an deiner Zeit (für $day hast du $set eingeplant) – die Grenze ist bewusst gesetzt.';
  }

  @override
  String get feasCapWhy => 'Länger am Stück bringt mehr Verletzungsrisiko und Erholungsbedarf als Fitness.';

  @override
  String get feasCapWhyTri => 'Im Triathlon- und Duathlon-Training ist diese Grenze fest: Die Ausdauer kommt vom Rad, und ein noch längerer Lauf würde dich die wichtigen Einheiten der Folgetage kosten.';

  @override
  String feasCapOffer(String time, String dist) {
    return 'Auf Wunsch gehen die letzten langen Läufe vor dem Tapering schrittweise bis $time (etwa $dist km), mit Gehpausen.';
  }

  @override
  String feasCapExtended(String time, String dist) {
    return 'Du hast längere Läufe erlaubt: Die letzten langen Läufe vor dem Tapering gehen schrittweise bis $time (etwa $dist km), mit Gehpausen.';
  }

  @override
  String get feasCapExtendedNoGain => 'Du hast längere Läufe erlaubt, dieser Plan kann sie aber nicht nutzen: Es bleiben zu wenige Wochen, um sicher über die Grenze hinaus aufzubauen.';

  @override
  String get feasCapFinish => 'Ankommen ist deshalb das Ziel – ruhig loslaufen und von Beginn an kurze Gehpausen einplanen (z. B. 1 min alle 10 min).';

  @override
  String get feasCapFinishTri => 'Für den Lauf im Rennen heißt das: ruhig anlaufen und von Beginn an kurze Gehpausen einplanen, z. B. an jeder Verpflegungsstelle.';

  @override
  String longRunExtendSwitch(String time) {
    return 'Lange Läufe bis $time erlauben';
  }

  @override
  String longRunExtendSub(String time) {
    return 'Standard: höchstens $time am Stück. Mit dieser Option werden nur die letzten langen Läufe vor dem Tapering länger – schrittweise, mit Gehpausen und leichteren Tagen danach.';
  }

  @override
  String timeLongCapRun(String time) {
    return 'Deine Tageszeit ist eine Obergrenze, kein Soll: Lange Läufe plant Strive für dieses Ziel höchstens $time am Stück, auch wenn der Tag mehr Zeit hat.';
  }

  @override
  String timeLongCapRide(String time) {
    return 'Deine Tageszeit ist eine Obergrenze, kein Soll: Lange Ausfahrten plant Strive für dieses Ziel höchstens $time, auch wenn der Tag mehr Zeit hat.';
  }

  @override
  String wLongRunExtendedNote(String time) {
    return 'Verlängerter langer Lauf (über deine üblichen $time hinaus): von Beginn an nach je 10 min Laufen 1 min gehen, früh essen und trinken. Brich ab, wenn etwas schmerzt – gesund bleiben zählt mehr als die Minuten. Die nächsten zwei Tage locker oder frei halten.';
  }

  @override
  String get wAfterExtendedNote => 'Bewusst locker gehalten: Deine Beine erholen sich noch vom verlängerten langen Lauf.';

  @override
  String get longRunExtendTitle => 'Längere lange Läufe';

  @override
  String feasCapWhySet(String day, String set) {
    return 'Das liegt nicht an deiner Zeit ($day: $set) – länger am Stück bringt mehr Verletzungsrisiko und Erholungsbedarf als Fitness.';
  }

  @override
  String feasCapOfferSettings(String time, String dist) {
    return 'In den Planeinstellungen kannst du erlauben, dass die letzten langen Läufe vor dem Tapering schrittweise bis $time (etwa $dist km) gehen, mit Gehpausen.';
  }

  @override
  String get feasCapExtendedNoGainVolume => 'Du hast längere Läufe erlaubt, dieser Plan kann sie aber nicht nutzen: Dein Wochenumfang trägt keinen längeren langen Lauf – dafür braucht es mehr oder längere Läufe an den anderen Tagen, nicht mehr Wochen.';

  @override
  String feasRunFrequencyLong(String have, String time, String need) {
    return 'Mit diesen Läufen erreicht dein längster langer Lauf etwa $have km ($time); das Rennen braucht etwa $need km. Die Grenze setzen die Läufe pro Woche, nicht deine Zeit.';
  }

  @override
  String get planRebuildExtendHint => 'Gilt, sobald du den Plan unten neu aufsetzt – bis dahin bleibt dein aktueller Plan unverändert.';

  @override
  String get circuit => 'Zirkel';

  @override
  String supersetGroupTitle(String kind, String letter, int count) {
    return '$kind $letter · $count Übungen';
  }

  @override
  String get supersetGroupHint => 'Abwechselnd · Pause nach jeder Runde';

  @override
  String supersetMemberOf(String kind, String letter, int x, int y) {
    return '$kind $letter, Übung $x von $y';
  }

  @override
  String supersetPosition(String kind, String letter, int x, int y) {
    return '$kind $letter · $x/$y';
  }

  @override
  String supersetThen(String name) {
    return 'Danach direkt: $name';
  }

  @override
  String get supersetThenRest => 'Letzte Übung der Runde – danach Pause';

  @override
  String get supersetDissolve => 'Auflösen';

  @override
  String get supersetDissolveTip => 'Supersatz auflösen';

  @override
  String get supersetFullMoved => 'Dieser Supersatz ist voll (max. 3 Übungen) – die Übung steht jetzt dahinter.';

  @override
  String supersetJoined(String letter) {
    return 'Zu Supersatz $letter hinzugefügt.';
  }

  @override
  String get supersetEditHint => 'Tipp: Verbinde zwei Übungen über den Ketten-Button dazwischen, um sie abwechselnd als Supersatz zu trainieren.';

  @override
  String get duplicateFolder => 'Ordner duplizieren';

  @override
  String get duplicateToFolder => 'In Ordner duplizieren';

  @override
  String programDuplicated(String name) {
    return '„$name“ erstellt.';
  }

  @override
  String programDuplicatedTo(String name, String folder) {
    return '„$name“ in $folder erstellt.';
  }

  @override
  String folderDuplicated(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ordner dupliziert ($n Programme).',
      one: 'Ordner dupliziert (1 Programm).',
      zero: 'Leeren Ordner dupliziert.',
    );
    return '$_temp0';
  }

  @override
  String folderDuplicatedHidden(int n) {
    return '$n davon blendet der Sportfilter aus.';
  }

  @override
  String get eventGymNoRace => 'Ein reiner Kraftplan bereitet auf keinen Wettkampf vor. Für einen Lauf-Wettkampf wähle den Fokus Hybrid (Kraft + Laufen) oder Laufen – hier legst du fest, wie lange der Plan läuft.';

  @override
  String feasNoRuns(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'mindestens $n Läufe',
      one: 'mindestens 1 Lauf',
    );
    return 'Deine Woche hat noch keinen Lauftag – dieses Rennen braucht $_temp0 pro Woche. Plane Lauftage ein.';
  }

  @override
  String feasNoRides(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'mindestens $n Radeinheiten',
      one: 'mindestens 1 Radeinheit',
    );
    return 'Deine Woche hat noch keinen Radtag – dieses Rennen braucht $_temp0 pro Woche. Plane Radtage ein.';
  }

  @override
  String feasNoSwims(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'mindestens $n Schwimmeinheiten',
      one: 'mindestens 1 Schwimmeinheit',
    );
    return 'Deine Woche hat noch keine Schwimmeinheit – dieses Rennen braucht $_temp0 pro Woche. Plane Schwimmtage ein.';
  }

  @override
  String feasLongRideRamp(String have, int weeks, String need) {
    return 'Von deinem jetzigen Stand aus wächst deine lange Ausfahrt bei sicherer Steigerung in $weeks Wochen nur auf etwa $have – dieses Rennen braucht lange Ausfahrten von etwa $need.';
  }

  @override
  String get feasAddRunDays => 'Lauftage hinzufügen';

  @override
  String get feasAddRideDays => 'Radtage hinzufügen';

  @override
  String get feasAddSwimDays => 'Schwimmtage hinzufügen';

  @override
  String feasRaiseTwoDays(String day, String time, String day2, String time2) {
    return 'Erhöhe die Zeit am $day auf $time und am $day2 auf $time2';
  }

  @override
  String get feasShowDetails => 'Details und Möglichkeiten';

  @override
  String get goalCountdownToday => 'Heute Wettkampf';

  @override
  String wGymLoadDesc2(int rir) {
    return 'Belastungswoche: Beende jeden Arbeitssatz mit etwa $rir Wdh. im Tank – die Reserve wird von Woche zu Woche kleiner, bis zur nächsten Entlastungswoche. Sätze, Wiederholungsbereich und Gewichtsvorschlag stehen bei jeder Übung.';
  }

  @override
  String get wGymLoadDescOneRep => 'Belastungswoche: Beende jeden Arbeitssatz mit etwa 1 Wdh. im Tank – die Reserve wird von Woche zu Woche kleiner, bis zur nächsten Entlastungswoche. Sätze, Wiederholungsbereich und Gewichtsvorschlag stehen bei jeder Übung.';

  @override
  String get wGymLoadDescNoDeloadOneRep => 'Beende jeden Arbeitssatz mit etwa 1 Wdh. im Tank. Sätze, Wiederholungsbereich und Gewichtsvorschlag stehen bei jeder Übung.';

  @override
  String get legacyRecalWhyFatigueRecovery => 'Seit zwei Wochen fühlen sich die Einheiten härter an als geplant: Die nächsten 7 Tage sind eine Erholungswoche (weniger Umfang, keine Intensität). Danach kommen die Qualitätseinheiten mit weniger Wiederholungen zurück.';

  @override
  String get legacyRecalWhyFatigueCheck => 'Auch nach der Erholungswoche noch härter als geplant: Prüfe Schlaf, Krankheit und Stress – und überlege eine langsamere Zielzeit. Die Qualitätseinheiten bleiben, mit weniger Wiederholungen.';

  @override
  String planMoveBeforeLong(String title) {
    return 'Am Tag danach steht „$title“ – eine harte Einheit direkt davor macht sie schwerer. Besser einen lockeren Tag dazwischen lassen.';
  }

  @override
  String planMoveSameDay(String title) {
    return 'An diesem Tag steht schon „$title“.';
  }

  @override
  String get calJumpRace => 'Zum Wettkampf';

  @override
  String recMinNoFit(int n, int days) {
    return 'Dieser Wettkampf braucht mindestens $n Einheiten pro Woche – mehr als $days Tage mit je einer Einheit. Wähle „Bis zu 2× pro Tag“.';
  }

  @override
  String feasLongRunLayout(int km, int x) {
    return 'In deiner Woche, wie sie jetzt ist, erreicht dein langer Lauf nur etwa $km km – dieses Rennen braucht lange Läufe über $x km. Mehr Zeit an einem einzelnen Tag ändert das hier nicht: Prüfe, an welchen Tagen deine Läufe liegen und welcher dein Tag für die lange Einheit ist.';
  }

  @override
  String feasLongRideLayout(int min, int target) {
    return 'In deiner Woche, wie sie jetzt ist, erreicht deine lange Ausfahrt nur $min min – dieses Rennen braucht lange Ausfahrten von mindestens $target min. Mehr Zeit an einem einzelnen Tag ändert das hier nicht: Prüfe, an welchen Tagen deine Radeinheiten liegen und welcher dein Tag für die lange Einheit ist.';
  }
}
