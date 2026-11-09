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
  String get fitnessLevel => 'Fitnesslevel';

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
  String get goalRace => 'Wettkampf / Event';

  @override
  String get scheduleTitle => 'Trainingstage';

  @override
  String get scheduleSub => 'An welchen Tagen möchtest du trainieren?';

  @override
  String daysPerWeek(int count) {
    return '$count Tage pro Woche';
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
  String get eventName => 'Name des Events';

  @override
  String get eventDate => 'Datum des Events';

  @override
  String get eventDistance => 'Distanz';

  @override
  String get halfMarathon => 'Halbmarathon';

  @override
  String get marathon => 'Marathon';

  @override
  String get searchMarathonDe => 'Events auf marathon.de suchen';

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
  String get todaysWorkout => 'Heutiges Training';

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
  String get readyFreshText => 'Deine Belastung ist niedrig – ideal für eine harte Einheit oder mehr Umfang.';

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
    return 'Level $level';
  }

  @override
  String xpToNext(int xp) {
    return 'Noch $xp XP bis zum nächsten Level';
  }

  @override
  String get freeWorkout => 'Frei';

  @override
  String get workoutRunning => 'Training läuft';

  @override
  String get workoutRunningBody => 'Es läuft noch ein anderes Training. Verwerfen und neu starten?';

  @override
  String get discardAndStart => 'Verwerfen & starten';

  @override
  String get startTraining => 'Training starten';

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
  String get noActiveWorkout => 'Kein aktives Training.';

  @override
  String get noSetsDone => 'Keine Sätze abgehakt';

  @override
  String get noSetsDoneBody => 'Dieses Training verwerfen?';

  @override
  String get discard => 'Verwerfen';

  @override
  String get finishWorkout => 'Training beenden?';

  @override
  String get finishWorkoutBody => 'Dein Training wird nach der Zusammenfassung gespeichert.';

  @override
  String get finish => 'Beenden';

  @override
  String get minimize => 'Minimieren';

  @override
  String get rename => 'Umbenennen';

  @override
  String get discardWorkout => 'Training verwerfen';

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
  String get howHard => 'Wie anstrengend war es?';

  @override
  String get notesHint => 'Notizen (Wie hat es sich angefühlt? Schlaf, Ernährung …)';

  @override
  String get saveWorkout => 'Training speichern';

  @override
  String get discardSummaryBody => 'Dieses Training wird nicht gespeichert.';

  @override
  String get rpeVeryEasy => 'sehr leicht';

  @override
  String get rpeEasy => 'leicht';

  @override
  String get rpeModerate => 'moderat';

  @override
  String get rpeHard => 'hart';

  @override
  String get rpeMax => 'maximal';

  @override
  String get badgeFirst => 'Erstes Training';

  @override
  String get badgeTen => '10 Trainings';

  @override
  String get badgeFifty => '50 Trainings';

  @override
  String get badgeHundred => '100 Trainings';

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
  String get emptyWorkout => 'Leeres Training';

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
  String get equipment => 'Equipment';

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
  String get startWorkout => 'Training starten';

  @override
  String get targetDistance => 'Zieldistanz';

  @override
  String get intensity => 'Intensität';

  @override
  String get planWorkout => 'Training planen';

  @override
  String get editWorkout => 'Training bearbeiten';

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
    return 'Fokus: $focus · $days Tage/Woche (im Profil änderbar)';
  }

  @override
  String get weeks => 'Wochen';

  @override
  String get planLocal => 'Smarte Regeln';

  @override
  String get planAi => 'KI (Gemini)';

  @override
  String get planLocalDesc => 'Periodisierter Plan nach sportwissenschaftlichen Prinzipien (80/20, progressive Überlastung, Deload jede 4. Woche). Funktioniert offline.';

  @override
  String get planAiDesc => 'Gemini erstellt einen individuellen Plan aus deinem Profil und deinem bisherigen Training. Benötigt Internet.';

  @override
  String get planWishHint => 'Besondere Wünsche? z. B. „Fokus Beine“, „10 km unter 50 min“';

  @override
  String get replaceExisting => 'Kommende geplante Trainings ersetzen';

  @override
  String get generate => 'Erstellen';

  @override
  String planCreated(int count) {
    return '$count Trainings geplant';
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
  String get nothingToExport => 'Keine kommenden Trainings zum Exportieren.';

  @override
  String get icsShareText => 'Mein Strive-Trainingsplan (.ics) – mit einer Kalender-App öffnen, um ihn zu importieren.';

  @override
  String get planGymDesc => 'Krafteinheit – progressive Überlastung: Gewicht oder Wdh. steigern, wenn alle Sätze gut laufen.';

  @override
  String get planDeloadGym => 'Deload-Woche: gleiche Übungen, ~60 % der üblichen Sätze, 3–4 Wdh. im Tank lassen.';

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
  String get performance => 'Performance';

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
  String get noRecordsYet => 'Absolviere ein Gym-Training, um deine Rekorde zu sehen.';

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
  String get noSessionsYet => 'Noch keine Trainings. Starte dein erstes!';

  @override
  String get deleteSession => 'Training löschen?';

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
  String get coachQ2 => 'Wie viel Protein brauche ich pro Tag?';

  @override
  String get coachQ3 => 'Wie werde ich auf 10 km schneller?';

  @override
  String get coachQ4 => 'Ich habe schlecht geschlafen – soll ich heute trotzdem trainieren?';

  @override
  String get coachQ5 => 'Was sollte ich vor einem langen Lauf essen?';

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
    return 'Noch $days Tage';
  }

  @override
  String get eventPassed => 'Event vorbei';

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
  String get goalTypeEvent => 'Event';

  @override
  String get perWeek => 'pro Woche';

  @override
  String get chooseExercise => 'Übung wählen';

  @override
  String get target => 'Zielwert';

  @override
  String get deadlineOptional => 'Deadline (optional)';

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
  String get vibrationSub => 'Nach Pausentimern und jedem km';

  @override
  String get reminders => 'Erinnerungen';

  @override
  String get hydrationReminder => 'Trink-Erinnerung';

  @override
  String everyNHours(int hours) {
    return 'Alle $hours h (8–20 Uhr)';
  }

  @override
  String get trainingReminder => 'Trainings-Erinnerung';

  @override
  String trainingReminderSub(String time) {
    return 'An Trainingstagen um $time';
  }

  @override
  String get reminderTime => 'Uhrzeit';

  @override
  String get testNotification => 'Test-Benachrichtigung senden';

  @override
  String get notificationsDenied => 'Benachrichtigungen sind in den Systemeinstellungen blockiert.';

  @override
  String get hydrationTitle => 'Zeit zu trinken 💧';

  @override
  String get hydrationBody => 'Ein Glas Wasser hält deine Leistung hoch.';

  @override
  String trainingReminderTitle(String sport) {
    return 'Heute: $sport';
  }

  @override
  String get integrations => 'Integrationen';

  @override
  String get comingSoon => 'Bald';

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
  String get superset => 'Superset';

  @override
  String get linkSuperset => 'Als Supersatz verbinden';

  @override
  String get unlinkSuperset => 'Aus Superset lösen';

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
  String progAddReps(int n) {
    return 'Gleiches Gewicht – Ziel $n Wdh. pro Satz';
  }

  @override
  String progDeload(String value) {
    return 'Letztes Mal zu schwer – mit $value neu aufbauen';
  }

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
    return '$n Einheiten / Woche';
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
  String get diffEasySub => '+5 % Umfang/Woche, jede 3. Woche Erholung, fast nur lockere Einheiten.';

  @override
  String get diffBalanced => 'Ausgewogen';

  @override
  String get diffBalancedSub => '+8 % Umfang/Woche, jede 4. Woche Erholung, ~80/20 locker/hart.';

  @override
  String get diffChallenging => 'Herausfordernd';

  @override
  String get diffChallengingSub => '+10 % Umfang/Woche, mehr intensive Einheiten – für Erfahrene.';

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
    return 'Empfohlen für dein Ziel: $lo–$hi Wochen (👍).';
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
  String get hcSub => 'Deine Uhr synchronisiert mit Samsung Health, Samsung Health teilt mit Health Connect und Strive liest Trainings, Puls, Schlaf und Schritte – und schreibt deine Strive-Trainings zurück.';

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
    return '$n neue Trainings importiert';
  }

  @override
  String get hcConnectedInfo => 'Verbunden. Neue Uhr-Trainings erscheinen automatisch in deinem Verlauf.';

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
  String get hcStep4 => 'Trainings wie gewohnt auf der Uhr aufzeichnen – Strive importiert sie beim nächsten App-Start.';

  @override
  String get hcOpenSamsung => 'Samsung Health öffnen';

  @override
  String get hcWhatSynced => 'Was wird synchronisiert?';

  @override
  String get hcWhatSyncedBody => 'Lesen: Trainings (Laufen, Rad, Schwimmen, Kraft) inkl. Ø/Max-Puls, Distanz und Kalorien, Ruhepuls, HRV, Schlaf, Schritte, Gewicht, Körperfett. Schreiben: Strive-Trainings und Gewichtseinträge.';

  @override
  String get steps => 'Schritte';

  @override
  String get sleep => 'Schlaf';

  @override
  String get continueWithGoogle => 'Weiter mit Google';

  @override
  String get linkGoogle => 'Google-Konto verknüpfen';

  @override
  String get guidedWorkout => 'Geführtes Training';

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
  String get zStride => 'Sprint';

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
  String get phaseRecovery => 'Erholungswoche';

  @override
  String get keySession => 'Schlüsseleinheit';

  @override
  String get viewSession => 'Training ansehen';

  @override
  String get fitnessForm => 'Fitness & Form';

  @override
  String get fitness => 'Fitness';

  @override
  String get fatigue => 'Ermüdung';

  @override
  String get form => 'Form';

  @override
  String get formFresh => 'Frisch – bereit für Wettkampf oder harte Einheit';

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
    return '$count Einheiten synchronisiert';
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
  String get editProfileSub => 'Name, Körperdaten, Level, Gesundheit';

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
    return '$count Tage individuell festgelegt';
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
  String get supersetLinked => 'Supersatz – tippen zum Lösen';

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
  String get workoutPhases => 'Phasen';

  @override
  String get planDone => 'Plan erledigt';

  @override
  String get perSport => 'Pro Sportart';

  @override
  String get recoveryTitle => 'Erholung & Belastung';

  @override
  String get load7d => 'Last 7 Tage';

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
    return '$count Einheiten';
  }

  @override
  String sessionN(int n) {
    return 'Einheit $n';
  }

  @override
  String get byDay => 'Tag für Tag';

  @override
  String get planExercisesHint => 'Änderungen gelten nur für dieses Training – das Programm bleibt unverändert.';

  @override
  String planExercisesCustom(String name) {
    return 'Für dieses Training angepasst (Programm: $name).';
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
  String get loadSrcHistory => 'aus deinem letzten Training';

  @override
  String get loadSrcIncrease => 'letztes Mal alle Wiederholungen geschafft – mehr Gewicht';

  @override
  String get loadSrcAddReps => 'aus deinem letzten Training – schaff eine Wiederholung mehr';

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
  String get previousWorkout => 'Vorheriges Training';

  @override
  String get nextWorkout => 'Nächstes Training';

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
  String get adjustWeekIntro => 'Schlüsseleinheiten wandern auf einen freien Tag dieser Woche – nie direkt neben eine andere harte Einheit. Lockere Einheiten musst du nicht nachholen: aufgestaute Umfänge schaden mehr, als sie bringen.';

  @override
  String adjustReplaces(String title) {
    return 'ersetzt $title';
  }

  @override
  String get adjustDropped => 'entfällt – muss nicht nachgeholt werden';

  @override
  String get adjustNoRoom => 'entfällt – diese Woche kein freier Tag ohne harte Einheit daneben';

  @override
  String get adjustProtected => 'entfällt – Erholungs-/Taperwoche bleibt locker';

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
  String get durationHms => 'Dauer (h:mm:ss)';

  @override
  String get invalidDuration => 'Gib die Dauer als h:mm:ss oder in Minuten ein.';

  @override
  String get rpeNotSet => 'nicht angegeben';

  @override
  String get sessionCorrected => 'Einheit aktualisiert';

  @override
  String get editSessionHint => 'Korrigiere fehlerhafte Messungen oder Eingaben. Aufgezeichnete Strecke und Splits bleiben erhalten.';
}
