// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tagline => 'Gym · Run · Ride · Swim — all in one place.';

  @override
  String get sportGym => 'Gym';

  @override
  String get sportRun => 'Running';

  @override
  String get sportRide => 'Cycling';

  @override
  String get sportSwim => 'Swimming';

  @override
  String get focusHybrid => 'Hybrid';

  @override
  String get focusDuathlon => 'Duathlon';

  @override
  String get focusTriathlon => 'Triathlon';

  @override
  String get intensityEasy => 'Easy';

  @override
  String get intensityModerate => 'Moderate';

  @override
  String get intensityTempo => 'Tempo';

  @override
  String get intensityIntervals => 'Intervals';

  @override
  String get intensityLong => 'Long';

  @override
  String get intensityTechnique => 'Technique';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Create account';

  @override
  String get haveAccount => 'Already have an account? Log in';

  @override
  String get noAccount => 'No account yet? Register';

  @override
  String get or => 'or';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get authInvalidEmail => 'Invalid email address.';

  @override
  String get authWrongCredentials => 'Email or password is wrong.';

  @override
  String get authEmailInUse => 'This email is already registered.';

  @override
  String get authWeakPassword => 'Password must have at least 6 characters.';

  @override
  String get authNetwork => 'No internet connection.';

  @override
  String get authNotEnabled => 'This sign-in method is not enabled in Firebase yet.';

  @override
  String get authError => 'Sign-in failed';

  @override
  String get authEnterEmail => 'Please enter your email first.';

  @override
  String get authResetSent => 'Reset link sent – check your inbox.';

  @override
  String get onboardingTitle => 'Set up Strive';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get next => 'Next';

  @override
  String get letsGo => 'Let\'s go!';

  @override
  String get welcomeTitle => 'Welcome to Strive';

  @override
  String get welcomeSub => 'A few questions so your coach can build the right plan for you.';

  @override
  String get yourName => 'Your name';

  @override
  String get aboutYou => 'About you';

  @override
  String get aboutYouSub => 'Used for training load, heart-rate zones and body stats.';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get diverse => 'Diverse';

  @override
  String get age => 'Age';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get bodyCompositionOptional => 'Body composition (optional)';

  @override
  String get bodyFat => 'Body fat';

  @override
  String get muscleMass => 'Muscle mass';

  @override
  String get muscle => 'Muscle';

  @override
  String get fitnessLevel => 'Fitness level';

  @override
  String get fitnessLevelSub => 'Be honest – the plan adapts as you improve.';

  @override
  String get beginner => 'Beginner';

  @override
  String get beginnerDesc => 'New or returning after a long break';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get intermediateDesc => 'Training regularly for 6+ months';

  @override
  String get advanced => 'Advanced';

  @override
  String get advancedDesc => 'Years of structured training';

  @override
  String get experienceWith => 'Experience with';

  @override
  String get focusTitle => 'Your focus';

  @override
  String get focusSub => 'What do you mainly train for?';

  @override
  String get yourGoals => 'Your goals';

  @override
  String get goalStrength => 'Get stronger';

  @override
  String get goalMuscle => 'Build muscle';

  @override
  String get goalFatLoss => 'Lose fat';

  @override
  String get goalEndurance => 'Endurance';

  @override
  String get goalHealth => 'Health';

  @override
  String get goalRace => 'Race / event';

  @override
  String get scheduleTitle => 'Training days';

  @override
  String get scheduleSub => 'On which days do you want to train?';

  @override
  String daysPerWeek(int count) {
    return '$count days per week';
  }

  @override
  String get longSessionDay => 'Long session day';

  @override
  String get automatic => 'Automatic';

  @override
  String get units => 'Units';

  @override
  String get metric => 'Metric (kg, km)';

  @override
  String get imperial => 'Imperial (lb, mi)';

  @override
  String get eventTitle => 'Training for an event?';

  @override
  String get eventSub => 'Add a race (marathon, triathlon …) and get a countdown. Optional.';

  @override
  String get eventName => 'Event name';

  @override
  String get eventDate => 'Event date';

  @override
  String get eventDistance => 'Distance';

  @override
  String get halfMarathon => 'Half marathon';

  @override
  String get marathon => 'Marathon';

  @override
  String get searchMarathonDe => 'Find events on marathon.de';

  @override
  String get generatePlanNow => 'Create my training plan';

  @override
  String get generatePlanNowSub => 'Built from your answers – you can change everything later.';

  @override
  String get navHome => 'Home';

  @override
  String get navTrain => 'Train';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navStats => 'Stats';

  @override
  String get navCoach => 'Coach';

  @override
  String get allSports => 'All sports';

  @override
  String get weekStreakTooltip => 'Weeks in a row with your training goal reached';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get todaysWorkout => 'Today\'s workout';

  @override
  String get restDay => 'Rest day';

  @override
  String get restDaySub => 'Recovery is training too. Feel like moving anyway?';

  @override
  String doneToday(int count) {
    return '$count done today 💪';
  }

  @override
  String get train => 'Train';

  @override
  String get start => 'Start';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get comingUp => 'Coming up';

  @override
  String get toCalendar => 'Calendar';

  @override
  String get rest => 'Rest';

  @override
  String get weather => 'Weather';

  @override
  String get feelsLike => 'feels';

  @override
  String get retry => 'Retry';

  @override
  String get weatherNoLocation => 'Allow location for local weather';

  @override
  String get weatherError => 'Weather unavailable';

  @override
  String get thisWeek => 'This week';

  @override
  String get trainedThisWeek => 'trained this week';

  @override
  String get readyBuilding => 'Building your baseline';

  @override
  String get readyBuildingText => 'After about 3 weeks of training, Strive can judge your load and recovery.';

  @override
  String get readyFresh => 'Fresh';

  @override
  String get readyFreshText => 'Your load is low – a great time for a hard session or to increase volume.';

  @override
  String get readyOptimal => 'Optimal load';

  @override
  String get readyOptimalText => 'Your training load is in the sweet spot. Keep it up!';

  @override
  String get readyHigh => 'High load';

  @override
  String get readyHighText => 'Load is rising quickly. Prioritise sleep and keep the next session easy.';

  @override
  String get readyOver => 'Recovery recommended';

  @override
  String get readyOverText => 'Injury risk is elevated. Take a rest day or an easy alternative (walk, mobility).';

  @override
  String get weightLogHint => 'Log your weight with + / – to see your trend';

  @override
  String get goals => 'Goals';

  @override
  String get noGoalsYet => 'No goals yet – set one to stay motivated.';

  @override
  String levelN(int level) {
    return 'Level $level';
  }

  @override
  String xpToNext(int xp) {
    return '$xp XP to next level';
  }

  @override
  String get freeWorkout => 'Free';

  @override
  String get workoutRunning => 'Workout in progress';

  @override
  String get workoutRunningBody => 'Another workout is still running. Discard it and start a new one?';

  @override
  String get discardAndStart => 'Discard & start';

  @override
  String get startTraining => 'Start training';

  @override
  String get logManually => 'Log manually';

  @override
  String get openWater => 'Open water';

  @override
  String get outdoor => 'Outdoor (GPS)';

  @override
  String get pool => 'Pool';

  @override
  String get indoor => 'Indoor';

  @override
  String get poolLength => 'Pool length';

  @override
  String get poolHint => 'Tap \"Length\" after every length. Distance is calculated automatically.';

  @override
  String get indoorHint => 'Treadmill / trainer: enter the distance when you finish.';

  @override
  String get gpsHint => 'GPS records your route, distance and pace – also with the screen off.';

  @override
  String get gpsServiceOff => 'Please turn on location services.';

  @override
  String get gpsPermissionDenied => 'Location permission is required for GPS tracking.';

  @override
  String get noActiveWorkout => 'No active workout.';

  @override
  String get noSetsDone => 'No sets completed';

  @override
  String get noSetsDoneBody => 'Discard this workout?';

  @override
  String get discard => 'Discard';

  @override
  String get finishWorkout => 'Finish workout?';

  @override
  String get finishWorkoutBody => 'Your workout will be saved after the summary.';

  @override
  String get finish => 'Finish';

  @override
  String get minimize => 'Minimize';

  @override
  String get rename => 'Rename';

  @override
  String get discardWorkout => 'Discard workout';

  @override
  String get addExercise => 'Add exercise';

  @override
  String get duration => 'Duration';

  @override
  String get volume => 'Volume';

  @override
  String get sets => 'Sets';

  @override
  String get restTimeSeconds => 'Rest time (seconds)';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get remove => 'Remove';

  @override
  String get setShort => 'Set';

  @override
  String get previous => 'Previous';

  @override
  String get reps => 'Reps';

  @override
  String get addSet => 'Add set';

  @override
  String get skip => 'Skip';

  @override
  String get enterDistance => 'Distance covered';

  @override
  String get distance => 'Distance';

  @override
  String get avgPace => 'Avg. pace';

  @override
  String get avgSpeed => 'Avg. speed';

  @override
  String get laps => 'Laps';

  @override
  String get lap => 'Lap';

  @override
  String get elevation => 'Elevation';

  @override
  String get lastSplit => 'Last km';

  @override
  String get undoLap => 'Undo last lap';

  @override
  String get pauseToFinish => 'Pause to finish';

  @override
  String get gpsError => 'GPS error';

  @override
  String get gpsSearching => 'Searching GPS …';

  @override
  String get summary => 'Summary';

  @override
  String get greatJob => 'Great job! 🎉';

  @override
  String get exercises => 'Exercises';

  @override
  String get coachBattleWon => 'Coach battle won! You beat the prediction based on your last session.';

  @override
  String get coachBattleLost => 'Coach battle: the prediction was a bit higher this time – next time!';

  @override
  String get newPr => 'New personal record!';

  @override
  String get howHard => 'How hard was it?';

  @override
  String get notesHint => 'Notes (how did it feel? sleep, nutrition …)';

  @override
  String get saveWorkout => 'Save workout';

  @override
  String get discardSummaryBody => 'This workout will not be saved.';

  @override
  String get rpeVeryEasy => 'very easy';

  @override
  String get rpeEasy => 'easy';

  @override
  String get rpeModerate => 'moderate';

  @override
  String get rpeHard => 'hard';

  @override
  String get rpeMax => 'maximal';

  @override
  String get badgeFirst => 'First workout';

  @override
  String get badgeTen => '10 workouts';

  @override
  String get badgeFifty => '50 workouts';

  @override
  String get badgeHundred => '100 workouts';

  @override
  String get badgeTon => '10 t in one session';

  @override
  String get badge5k => '5 km run';

  @override
  String get badge10k => '10 km run';

  @override
  String get badgeHalf => 'Half marathon';

  @override
  String get badgeMarathon => 'Marathon';

  @override
  String get badgeCentury => '100 km ride';

  @override
  String get badgeSwim1k => '1 km swim';

  @override
  String get badgeSwim3k => '3 km swim';

  @override
  String get badgeStreak4 => '4-week streak';

  @override
  String get badgeStreak12 => '12-week streak';

  @override
  String get badgeEarly => 'Early bird';

  @override
  String get badgeAllround => 'All-rounder';

  @override
  String get title => 'Title';

  @override
  String get totalVolume => 'Total volume';

  @override
  String get saved => 'Saved';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get newProgram => 'New program';

  @override
  String get editProgram => 'Edit program';

  @override
  String get quickStart => 'Quick start';

  @override
  String get programs => 'Programs';

  @override
  String get importCode => 'Import code';

  @override
  String get noPrograms => 'No programs for this sport yet.';

  @override
  String get noFolder => 'Other';

  @override
  String get codeNotFound => 'Code not found.';

  @override
  String imported(String name) {
    return '\"$name\" imported';
  }

  @override
  String get offlineAction => 'This needs an internet connection.';

  @override
  String get emptyWorkout => 'Empty workout';

  @override
  String get recordGps => 'Record activity';

  @override
  String get exerciseLibrary => 'Exercise library';

  @override
  String addN(int count) {
    return 'Add $count';
  }

  @override
  String get searchExercises => 'Search exercises (e.g. bench press, kniebeuge)';

  @override
  String get bodyPart => 'Body part';

  @override
  String get equipment => 'Equipment';

  @override
  String nResults(int count) {
    return '$count exercises';
  }

  @override
  String get all => 'All';

  @override
  String get secondaryMuscles => 'Secondary';

  @override
  String get watchVideo => 'Watch video tutorial';

  @override
  String get yourRecords => 'Your records';

  @override
  String get maxWeight => 'Max weight';

  @override
  String get sessions => 'Sessions';

  @override
  String get strengthProgress => 'Strength progress (e1RM)';

  @override
  String get instructions => 'Instructions';

  @override
  String get instructionsEnglishNote => 'Instructions are currently available in English.';

  @override
  String codeCopied(String code) {
    return 'Code $code copied';
  }

  @override
  String shareText(String name, String code) {
    return 'Try my Strive program \"$name\"! Import code: $code';
  }

  @override
  String get deleteProgram => 'Delete program?';

  @override
  String get name => 'Name';

  @override
  String get folder => 'Folder';

  @override
  String get description => 'Description';

  @override
  String get startWorkout => 'Start workout';

  @override
  String get targetDistance => 'Target distance';

  @override
  String get intensity => 'Intensity';

  @override
  String get planWorkout => 'Plan workout';

  @override
  String get editWorkout => 'Edit workout';

  @override
  String get program => 'Program';

  @override
  String get none => 'None';

  @override
  String get markSkipped => 'Mark as skipped';

  @override
  String get generatePlan => 'Generate plan';

  @override
  String generatePlanSub(String focus, int days) {
    return 'Focus: $focus · $days days/week (change in profile)';
  }

  @override
  String get weeks => 'Weeks';

  @override
  String get planLocal => 'Smart rules';

  @override
  String get planAi => 'AI (Gemini)';

  @override
  String get planLocalDesc =>
      'Periodised plan based on sports science (80/20, progressive overload, deload every 4th week). Works offline.';

  @override
  String get planAiDesc => 'Gemini creates an individual plan from your profile and recent training. Needs internet.';

  @override
  String get planWishHint => 'Special wishes? e.g. \"focus on legs\", \"sub-50 10k\"';

  @override
  String get replaceExisting => 'Replace upcoming planned workouts';

  @override
  String get generate => 'Generate';

  @override
  String planCreated(int count) {
    return '$count workouts planned';
  }

  @override
  String get aiUnavailable => 'The AI coach is not available right now. Check your connection or enable Firebase AI Logic.';

  @override
  String get syncCalendar => 'Export calendar';

  @override
  String get currentWeek => 'Current';

  @override
  String get nextWeek => 'Next';

  @override
  String get lastWeek => 'Last week';

  @override
  String get nothingPlanned => 'Nothing planned.';

  @override
  String get nothingToExport => 'No upcoming workouts to export.';

  @override
  String get icsShareText => 'My Strive training plan (.ics) – open it with a calendar app to import it.';

  @override
  String get planGymDesc => 'Strength session – progressive overload: add weight or reps when all sets feel good.';

  @override
  String get planDeloadGym => 'Deload week: same exercises, ~60 % of the usual sets, leave 3–4 reps in reserve.';

  @override
  String get planEasyRun => 'Easy run';

  @override
  String get planEasyRide => 'Endurance ride';

  @override
  String get planEasyDesc => 'Zone 2 – you should be able to talk in full sentences.';

  @override
  String get planLongRun => 'Long run';

  @override
  String get planLongRunDesc => 'Easy, steady pace. Take fluids/carbs after 60 min.';

  @override
  String get planRunIntervals => 'Run intervals';

  @override
  String get planRunIntervalsDesc => '15 min warm-up · 6×800 m at 5k pace, 2 min jog · 10 min cool-down';

  @override
  String get planRunTempo => 'Tempo run';

  @override
  String get planRunTempoDesc => '15 min easy · 20 min at threshold (comfortably hard) · 10 min easy';

  @override
  String get planLongRide => 'Long ride';

  @override
  String get planLongRideDesc => 'Zone 2, cadence 85–95 rpm. Eat every 45 min.';

  @override
  String get planRideIntervals => 'VO2max intervals';

  @override
  String get planRideIntervalsDesc => '15 min warm-up · 5×4 min hard, 4 min easy · 10 min cool-down';

  @override
  String get planRideTempo => 'Sweet spot';

  @override
  String get planRideTempoDesc => '3×12 min at 88–94 % FTP, 4 min easy between.';

  @override
  String get planLongSwim => 'Endurance swim';

  @override
  String get planLongSwimDesc => 'Continuous swimming at a relaxed pace, focus on breathing.';

  @override
  String get planSwimIntervals => 'Swim intervals';

  @override
  String get planSwimIntervalsDesc => '400 warm-up · 10×100 at CSS, 15 s rest · 200 cool-down';

  @override
  String get planSwimTechnique => 'Technique swim';

  @override
  String get planSwimTechniqueDesc => '300 warm-up · 8×50 drills · 6×100 steady · 200 cool-down';

  @override
  String get performance => 'Performance';

  @override
  String get records => 'Records';

  @override
  String get history => 'History';

  @override
  String get range4w => '4W';

  @override
  String get range3m => '3M';

  @override
  String get range1y => '1Y';

  @override
  String get rangeAll => 'All';

  @override
  String get time => 'Time';

  @override
  String get avgGymDays => 'Ø gym days / month';

  @override
  String get avgDuration => 'Ø duration';

  @override
  String get heatmap => 'Training heatmap';

  @override
  String get weeklyMinutes => 'Minutes per week';

  @override
  String get weeklyDistance => 'Distance per week';

  @override
  String get notEnoughData => 'Not enough data yet';

  @override
  String get strengthRecords => 'Strength records';

  @override
  String get noRecordsYet => 'Complete a gym workout to see your records.';

  @override
  String get longestDistance => 'Longest';

  @override
  String get longestDuration => 'Longest time';

  @override
  String get bestPace => 'Best pace';

  @override
  String get bestSpeed => 'Best speed';

  @override
  String get totalDistance => 'Total';

  @override
  String get badges => 'Badges';

  @override
  String get noSessionsYet => 'No workouts yet. Start your first one!';

  @override
  String get deleteSession => 'Delete workout?';

  @override
  String get splits => 'Splits';

  @override
  String get compareLast => 'Compared to last time';

  @override
  String get notes => 'Notes';

  @override
  String get sharedFromStrive => 'Tracked with Strive 💪';

  @override
  String get bodyComposition => 'Body composition';

  @override
  String get entries => 'Entries';

  @override
  String get logBody => 'Log body data';

  @override
  String get newChat => 'New chat';

  @override
  String get coachTitle => 'Your AI coach';

  @override
  String get coachSub => 'Ask anything about training, recovery or nutrition. Answers use your profile and training data.';

  @override
  String get coachQ1 => 'How is my training going? What should I improve?';

  @override
  String get coachQ2 => 'How much protein do I need per day?';

  @override
  String get coachQ3 => 'How do I get faster over 10 km?';

  @override
  String get coachQ4 => 'I slept badly – should I still train today?';

  @override
  String get coachQ5 => 'What should I eat before a long run?';

  @override
  String get coachDisclaimer => 'AI answers can be wrong and do not replace medical advice.';

  @override
  String get askCoach => 'Ask your coach …';

  @override
  String get newGoal => 'New goal';

  @override
  String get editGoal => 'Edit goal';

  @override
  String perWeekProgress(int done, int target) {
    return '$done / $target per week';
  }

  @override
  String daysLeft(int days) {
    return '$days days left';
  }

  @override
  String get eventPassed => 'Event passed';

  @override
  String get onTrack => 'On track';

  @override
  String get behindSchedule => 'Behind';

  @override
  String get until => 'until';

  @override
  String get goalTypeWeight => 'Body weight';

  @override
  String get goalTypeDistance => 'Distance';

  @override
  String get goalTypeFrequency => 'Frequency';

  @override
  String get goalTypeStrength => 'Strength';

  @override
  String get goalTypeEvent => 'Event';

  @override
  String get perWeek => 'per week';

  @override
  String get chooseExercise => 'Choose exercise';

  @override
  String get target => 'Target';

  @override
  String get deadlineOptional => 'Deadline (optional)';

  @override
  String get profile => 'Profile';

  @override
  String get athlete => 'Athlete';

  @override
  String get guestAccount => 'Guest account';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get system => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get vibration => 'Vibration';

  @override
  String get vibrationSub => 'After rest timers and each km';

  @override
  String get reminders => 'Reminders';

  @override
  String get hydrationReminder => 'Drink reminder';

  @override
  String everyNHours(int hours) {
    return 'Every $hours h (8–20 h)';
  }

  @override
  String get trainingReminder => 'Training reminder';

  @override
  String trainingReminderSub(String time) {
    return 'On training days at $time';
  }

  @override
  String get reminderTime => 'Time';

  @override
  String get testNotification => 'Send test notification';

  @override
  String get notificationsDenied => 'Notifications are blocked in system settings.';

  @override
  String get hydrationTitle => 'Time to drink 💧';

  @override
  String get hydrationBody => 'A glass of water keeps your performance up.';

  @override
  String trainingReminderTitle(String sport) {
    return 'Today: $sport';
  }

  @override
  String get integrations => 'Integrations';

  @override
  String get comingSoon => 'Soon';

  @override
  String get googleCalendar => 'Google Calendar';

  @override
  String get googleCalendarSub => 'Sync your plan into a separate \"Strive\" calendar';

  @override
  String get account => 'Account';

  @override
  String get upgradeAccount => 'Save guest account';

  @override
  String get upgradeAccountSub => 'Link an email so you never lose your data';

  @override
  String get accountLinked => 'Account saved!';

  @override
  String get logout => 'Log out';

  @override
  String get guestLogoutWarning => 'As a guest, your data will be lost when you log out.';

  @override
  String get offlineReady => 'works offline';

  @override
  String get viewFocus => 'Focus view';

  @override
  String get viewTable => 'Table view';

  @override
  String get upNext => 'Up next';

  @override
  String setXofY(int x, int y) {
    return 'Set $x of $y';
  }

  @override
  String exerciseXofY(int x, int y) {
    return 'Exercise $x/$y';
  }

  @override
  String completeSet(int n) {
    return 'Complete set $n';
  }

  @override
  String get nextExercise => 'Next exercise';

  @override
  String get workoutComplete => 'All sets done – great work!';

  @override
  String get superset => 'Superset';

  @override
  String get linkSuperset => 'Link as superset';

  @override
  String get unlinkSuperset => 'Remove from superset';

  @override
  String get replaceExercise => 'Replace exercise';

  @override
  String get warmupSets => 'Warm-up sets';

  @override
  String warmupAdded(int n) {
    return '$n warm-up sets added';
  }

  @override
  String get plateCalculator => 'Plates';

  @override
  String get plateCalcTitle => 'Plate calculator';

  @override
  String get perSide => 'per side';

  @override
  String get barWeight => 'Bar';

  @override
  String notLoadable(String value) {
    return '$value cannot be loaded exactly';
  }

  @override
  String get dropSet => 'Drop set';

  @override
  String get note => 'Note';

  @override
  String get setTypeNormal => 'Working set';

  @override
  String get setTypeWarmup => 'Warm-up';

  @override
  String get setTypeDrop => 'Drop set';

  @override
  String get setTypeFailure => 'To failure';

  @override
  String get rpeHint => 'How hard was it? RPE 10 = no rep left, 8 = two reps left';

  @override
  String progIncrease(String value) {
    return 'You hit the top of your rep range last time → try $value today';
  }

  @override
  String progAddReps(int n) {
    return 'Same weight – aim for $n reps per set';
  }

  @override
  String progDeload(String value) {
    return 'Last time was a grind – reset to $value and build back up';
  }

  @override
  String get progHold => 'Keep the weight and own every rep';

  @override
  String get apply => 'Apply';

  @override
  String get lastTime => 'Last time';

  @override
  String get undo => 'Undo';

  @override
  String get restHint => 'Breathe, drink some water, get ready.';

  @override
  String get skipRest => 'Skip rest';

  @override
  String get translating => 'Translating…';

  @override
  String get translatedByAi => 'Translated by AI';

  @override
  String get translationFailed => 'Translation unavailable – showing English original';

  @override
  String get showOriginal => 'Original';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get skyClear => 'Clear';

  @override
  String get skyPartly => 'Partly cloudy';

  @override
  String get skyCloudy => 'Cloudy';

  @override
  String get skyFog => 'Fog';

  @override
  String get skyDrizzle => 'Drizzle';

  @override
  String get skyRain => 'Rain';

  @override
  String get skySnow => 'Snow';

  @override
  String get skyStorm => 'Thunderstorm';

  @override
  String get clothShorts => 'Shorts & T-shirt';

  @override
  String get clothLongTee => 'Shorts & long sleeve';

  @override
  String get clothTights => 'Tights & long sleeve, light gloves';

  @override
  String get clothJacket => 'Tights, thermal top & light jacket, hat';

  @override
  String get clothWinter => 'Winter tights, layers, gloves & hat';

  @override
  String get hintStorm => 'Thunderstorm – train indoors today';

  @override
  String hintRainAt(String time) {
    return 'Rain from $time – go before';
  }

  @override
  String get hintHot => 'Hot – go early, drink more';

  @override
  String get hintCold => 'Cold – warm up indoors first';

  @override
  String hintBest(String time) {
    return 'Best time to train: $time';
  }

  @override
  String get hintIndoor => 'So-so outside – good day for gym';

  @override
  String get bestTrainingWindow => 'Best training window';

  @override
  String rainChanceN(int pct) {
    return '$pct% rain';
  }

  @override
  String get next24h => 'Next 24 hours';

  @override
  String get now => 'Now';

  @override
  String get trainingScoreLegend => 'Bar = conditions for outdoor training';

  @override
  String get wind => 'Wind';

  @override
  String get humidity => 'Humidity';

  @override
  String get uvIndex => 'UV index';

  @override
  String get uvHigh => 'High – use sunscreen';

  @override
  String get uvModerate => 'Moderate';

  @override
  String get uvLow => 'Low';

  @override
  String get airQuality => 'Air quality';

  @override
  String get aqiGood => 'Good';

  @override
  String get aqiModerate => 'Moderate';

  @override
  String get aqiPoor => 'Poor – go easy';

  @override
  String get sunrise => 'Sunrise';

  @override
  String get sunset => 'Sunset';

  @override
  String get whatToWear => 'What to wear for a run';

  @override
  String get wearSunscreen => 'Sunscreen & cap';

  @override
  String get wearRainJacket => 'Pack a rain jacket';

  @override
  String get wearWindproof => 'Windproof layer';

  @override
  String get drinkMore => 'Drink extra';

  @override
  String get wearReflective => 'Reflective gear / headlamp';

  @override
  String get next7Days => '7-day forecast';

  @override
  String get today => 'Today';

  @override
  String get weatherSource => 'Weather data: Open-Meteo.com';

  @override
  String get stepWarmupNote => 'Easy jog, get loose';

  @override
  String get stepEasyNote => 'Conversational pace – you can talk in full sentences';

  @override
  String get stepMpNote => 'Goal marathon pace – controlled';

  @override
  String get stepTempoNote => 'Comfortably hard – a few words only';

  @override
  String get stepFartlekNote => 'Pick it up – strong but relaxed';

  @override
  String get stepIntervalNote => 'Hard – 3–5k race effort';

  @override
  String get stepStrideNote => 'Fast and relaxed, not a sprint';

  @override
  String get stepBriskWalk => 'Brisk walk';

  @override
  String get stepTalkPace => 'Very easy jog – you could chat';

  @override
  String get stepZ2RideNote => 'Zone 2 – steady, you can talk';

  @override
  String get stepVo2Note => 'Very hard – 106–120 % FTP';

  @override
  String get stepSsNote => 'Sweet spot – 88–94 % FTP';

  @override
  String get stepThresholdNote => 'Threshold – 95–105 % FTP';

  @override
  String get stepSwimWu => 'Easy, mixed strokes';

  @override
  String get stepDrills => 'Drills: catch-up, fist, 6-kick switch';

  @override
  String get stepCssNote => 'At CSS pace – even splits';

  @override
  String get stepSwimEasyNote => 'Relaxed, focus on long strokes';

  @override
  String get stepSwimEnNote => 'Steady aerobic pace';

  @override
  String get wLongRunDesc => 'Builds aerobic endurance and fat metabolism. Keep it easy – time on feet matters, not pace.';

  @override
  String get wLongRunMp => 'Long run with race pace';

  @override
  String get wLongRunMpDesc => 'Easy long run, finishing the last quarter at goal race pace – the key race-specific session.';

  @override
  String get wTempoDesc => 'Threshold run: raises the pace you can hold for an hour.';

  @override
  String get wFartlek => 'Fartlek';

  @override
  String get wFartlekDesc => 'Easy run with short, playful surges – builds speed without much fatigue.';

  @override
  String wIntervals(int reps, int meters) {
    return 'Intervals $reps × $meters m';
  }

  @override
  String get wIntervalsDesc => 'VO2max intervals at 3–5k race effort. Recovery jog between reps.';

  @override
  String get wMpRun => 'Marathon-pace run';

  @override
  String get wMpRunDesc => 'Continuous block at goal marathon pace to lock in the rhythm.';

  @override
  String wCruise(int reps) {
    return 'Cruise intervals $reps × 1.6 km';
  }

  @override
  String get wCruiseDesc => 'Threshold pace with short jogs – more time at threshold with less strain (Daniels).';

  @override
  String get wEasyStrides => 'Easy run + strides';

  @override
  String get wEasyStridesDesc => 'Easy run, then short relaxed strides for running economy.';

  @override
  String get wRecoveryRun => 'Recovery run';

  @override
  String get wEasyDesc => 'Most of your running should feel like this – easy volume builds the engine.';

  @override
  String wRunWalk(int n, int min) {
    return 'Run/walk $n × $min min';
  }

  @override
  String get wRunWalkDesc => 'Alternate easy jogging and walking. Repeat the week if it felt hard.';

  @override
  String get wLongRideDesc => 'Long Zone 2 ride – the backbone of cycling endurance. Eat and drink every 20–30 min.';

  @override
  String wRideVo2(int reps, int min) {
    return 'VO2max $reps × $min min';
  }

  @override
  String get wRideVo2Desc => 'Hard intervals with equal recovery – raises your ceiling.';

  @override
  String wSweetSpot(int reps, int each) {
    return 'Sweet spot $reps × $each min';
  }

  @override
  String get wSweetSpotDesc => 'Just below threshold – very time-efficient FTP builder.';

  @override
  String wThreshold(int reps, int each) {
    return 'Threshold $reps × $each min';
  }

  @override
  String get wThresholdDesc => 'At FTP – the power you can hold for about an hour.';

  @override
  String get wRecoveryRide => 'Recovery ride';

  @override
  String get wEasyRideDesc => 'Easy endurance ride, steady cadence 85–95 rpm.';

  @override
  String wSwimCss(int n) {
    return 'CSS set $n × 100 m';
  }

  @override
  String get wSwimCssDesc => 'Threshold swim at critical swim speed with short rests.';

  @override
  String get wSwimTechDesc => 'Technique first: drills, then relaxed repeats with good form.';

  @override
  String wSwimEndurance(int reps, int meters) {
    return 'Endurance $reps × $meters m';
  }

  @override
  String get wSwimEnduranceDesc => 'Aerobic swim set – steady pace, short rests.';

  @override
  String wGymDesc(int sets, int lo, int hi, int rir) {
    return '$sets sets × $lo–$hi reps, stop with $rir reps in reserve. Add weight once you reach $hi reps on all sets.';
  }

  @override
  String wGymDeloadDesc(int sets) {
    return 'Deload: $sets sets per exercise, about 10 % lighter, nothing near failure.';
  }

  @override
  String get wGymConcurrentNote => 'Key endurance session tomorrow – upper body focus, keep legs light.';

  @override
  String get setupModeTitle => 'How detailed should we get?';

  @override
  String get setupQuick => 'Quick start · ~2 min';

  @override
  String get setupQuickSub => 'A few general questions. Your plan adapts as you log workouts.';

  @override
  String get setupDetailed => 'Detailed · ~6 min';

  @override
  String get setupDetailedSub =>
      'Race times, weekly volume, FTP, swim test, max lifts and a weekday plan – for a precise plan from day one.';

  @override
  String get recommended => 'Recommended';

  @override
  String get heartRateOptional => 'Heart rate (optional)';

  @override
  String get heartRateHint => 'Resting HR: measured in bed after waking. Leave max HR empty to estimate it (208 − 0.7 × age).';

  @override
  String get restingHr => 'Resting HR';

  @override
  String get maxHr => 'Max HR';

  @override
  String get sessionLength => 'Time per session';

  @override
  String get weekPlanTitle => 'Your training week';

  @override
  String get weekPlanSub => 'Tap which sport you want to do on which day. Your plan follows this structure.';

  @override
  String get oncePerDay => '1× per day';

  @override
  String get twicePerDay => 'Up to 2× per day';

  @override
  String sessionsPerWeekN(int n) {
    return '$n sessions / week';
  }

  @override
  String get longDayHint => '★ = day for your long session';

  @override
  String get noRestDayWarning => 'No rest day – at least one easy or rest day per week is recommended.';

  @override
  String get preferredTime => 'Preferred training time';

  @override
  String get morning => 'Morning';

  @override
  String get midday => 'Midday';

  @override
  String get evening => 'Evening';

  @override
  String get runSetupTitle => 'Running';

  @override
  String get runSetupSub => 'Your current running fitness – this sets your pace zones and safe progression.';

  @override
  String get canRun30 => 'I can run 30 min without stopping';

  @override
  String get canRun30Sub => 'If not, we start with a run/walk program.';

  @override
  String get raceTimesTitle => 'Recent best times (optional)';

  @override
  String get raceTimesHint => 'From the last ~6 months. One is enough – we calculate your VDOT (Daniels).';

  @override
  String get currentVolume => 'Current training volume';

  @override
  String get weeklyKmNow => 'Running km per week';

  @override
  String get longestRun4w => 'Longest run (last 4 weeks)';

  @override
  String get notSure => 'Not sure';

  @override
  String get rideSetupTitle => 'Cycling';

  @override
  String get rideSetupSub => 'Power or heart rate – we set your zones accordingly.';

  @override
  String get hasPowerMeter => 'I have a power meter / smart trainer';

  @override
  String get hasIndoorTrainer => 'I can ride indoors (trainer / rollers)';

  @override
  String get ftpTitle => 'FTP (optional)';

  @override
  String get ftpHint => 'Functional threshold power: 95 % of a 20-min all-out test.';

  @override
  String get weeklyHoursNow => 'Cycling hours per week';

  @override
  String get longestRide4w => 'Longest ride (last 4 weeks)';

  @override
  String get swimSetupTitle => 'Swimming';

  @override
  String get swimSetupSub => 'A quick test gives your critical swim speed (CSS) for pace targets.';

  @override
  String get canSwim400 => 'I can swim 400 m freestyle without stopping';

  @override
  String get cssTitle => 'CSS test (optional)';

  @override
  String get cssHint => 'All-out 400 m, rest, then all-out 200 m.';

  @override
  String cssResult(String pace) {
    return 'Your CSS: $pace /100 m';
  }

  @override
  String get weeklySwimKm => 'Swim km per week';

  @override
  String get gymSetupTitle => 'Strength training';

  @override
  String get gymSetupSub => 'Equipment and goal decide exercises, rep ranges and progression.';

  @override
  String get equipmentTitle => 'Where do you train?';

  @override
  String get equipGym => 'Gym';

  @override
  String get equipGymSub => 'Barbells, machines, cables';

  @override
  String get equipHome => 'Home gym';

  @override
  String get equipHomeSub => 'Dumbbells, bench, maybe a rack';

  @override
  String get equipBodyweight => 'Bodyweight';

  @override
  String get equipBodyweightSub => 'No equipment, maybe bands';

  @override
  String get gymGoalTitle => 'Strength goal';

  @override
  String get general => 'General';

  @override
  String get oneRmTitle => 'Max lifts (optional)';

  @override
  String get oneRmHint => '1-rep max or a good estimate – used for starting weights.';

  @override
  String get liftSquat => 'Squat';

  @override
  String get liftBench => 'Bench press';

  @override
  String get liftDeadlift => 'Deadlift';

  @override
  String get liftOhp => 'Overhead press';

  @override
  String get healthTitle => 'Anything to consider?';

  @override
  String get healthSub => 'We avoid risky progressions for affected areas.';

  @override
  String get limitKnee => 'Knee';

  @override
  String get limitBack => 'Back';

  @override
  String get limitShoulder => 'Shoulder';

  @override
  String get limitHip => 'Hip';

  @override
  String get limitAnkle => 'Ankle / Achilles';

  @override
  String get limitHeart => 'Heart / blood pressure';

  @override
  String get healthDisclaimer => 'Strive does not replace medical advice. With pain or health conditions, talk to a doctor first.';

  @override
  String get olympicTri => 'Olympic triathlon';

  @override
  String get targetTime => 'Target time';

  @override
  String get targetTimeHint => 'Optional – leave empty to just finish strong.';

  @override
  String predictedTime(String time) {
    return 'Predicted from your current form: $time';
  }

  @override
  String get planSetupTitle => 'Your plan';

  @override
  String get planSetupSub => 'How hard and how long? Based on sports-science guidelines.';

  @override
  String get difficultyTitle => 'Difficulty';

  @override
  String get difficultyHint => 'Compared to what you do now.';

  @override
  String get diffEasy => 'Easy';

  @override
  String get diffEasySub => '+5 % volume/week, recovery every 3rd week, mostly easy sessions.';

  @override
  String get diffBalanced => 'Balanced';

  @override
  String get diffBalancedSub => '+8 % volume/week, recovery every 4th week, ~80/20 easy/hard.';

  @override
  String get diffChallenging => 'Challenging';

  @override
  String get diffChallengingSub => '+10 % volume/week, more quality sessions – for experienced athletes.';

  @override
  String get planLength => 'Plan length';

  @override
  String get plan4w => '4 weeks · quick boost';

  @override
  String get plan8w => '8 weeks';

  @override
  String get plan12w => '12 weeks';

  @override
  String get plan16w => '16 weeks';

  @override
  String get plan20w => '20 weeks · max. build-up';

  @override
  String planLengthHint(int lo, int hi) {
    return 'Recommended for your goal: $lo–$hi weeks (👍).';
  }

  @override
  String planToEvent(int weeks) {
    return 'Your plan runs $weeks weeks until race day, including taper.';
  }

  @override
  String planToEventShort(int weeks, int lo) {
    return 'Only $weeks weeks to race day – $lo+ are recommended. We focus on arriving fit rather than a time goal.';
  }

  @override
  String get planScienceNote =>
      'Plans follow e.g. Seiler (80/20), Daniels (VDOT paces), Bosquet (taper), Schoenfeld (strength volume). Details in the plan view.';

  @override
  String get yourPaceZones => 'Your pace zones';

  @override
  String get zoneEasy => 'Easy / long';

  @override
  String get zoneMarathon => 'Marathon';

  @override
  String get zoneThreshold => 'Threshold';

  @override
  String get zoneInterval => 'Interval';

  @override
  String get zoneRepetition => 'Repetition';

  @override
  String get hcTileSub => 'Galaxy Watch, Samsung Health, Garmin & more';

  @override
  String get hcConnectedShort => 'Connected – syncing automatically';

  @override
  String get hcTitle => 'Connect your Galaxy Watch';

  @override
  String get hcSub =>
      'Your watch syncs to Samsung Health, Samsung Health shares with Health Connect, and Strive reads your workouts, heart rate, sleep and steps – and writes your Strive workouts back.';

  @override
  String get hcUnavailable => 'Health Connect is not available on this device.';

  @override
  String get hcInstall => 'Health Connect needs to be installed or updated first.';

  @override
  String get hcInstallButton => 'Install Health Connect';

  @override
  String get hcConnect => 'Connect Health Connect';

  @override
  String get hcConnected => 'Connected!';

  @override
  String get hcDenied => 'Permissions were not granted.';

  @override
  String hcImported(int n) {
    return '$n new workouts imported';
  }

  @override
  String get hcConnectedInfo => 'Connected. New watch workouts appear in your history automatically.';

  @override
  String get hcImportedLabel => 'Imported';

  @override
  String get hcLastSync => 'Last sync';

  @override
  String get hcSyncNow => 'Sync now';

  @override
  String get hcDisconnect => 'Disconnect';

  @override
  String get hcSetupTitle => 'Set up your Galaxy Watch 6';

  @override
  String get hcStep1 => 'Pair the watch with the Galaxy Wearable app and sign in to Samsung Health.';

  @override
  String get hcStep2 => 'In Samsung Health: ⋮ → Settings → Health Connect → allow all data types to be shared.';

  @override
  String get hcStep3 => 'Tap \"Connect\" above and allow Strive to read and write.';

  @override
  String get hcStep4 => 'Record workouts on the watch as usual – Strive imports them on the next app start.';

  @override
  String get hcOpenSamsung => 'Open Samsung Health';

  @override
  String get hcWhatSynced => 'What is synced?';

  @override
  String get hcWhatSyncedBody =>
      'Read: workouts (run, ride, swim, strength) incl. avg/max heart rate, distance and calories, resting heart rate, HRV, sleep, steps, weight, body fat. Write: Strive workouts and weight entries.';

  @override
  String get steps => 'Steps';

  @override
  String get sleep => 'Sleep';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get linkGoogle => 'Link Google account';

  @override
  String get guidedWorkout => 'Guided workout';

  @override
  String get guidedWorkoutSub => 'Step-by-step targets with voice cues';

  @override
  String get music => 'Music';

  @override
  String get voiceCues => 'Voice cues';

  @override
  String get lockScreen => 'Lock screen';

  @override
  String get skipStep => 'Next step';

  @override
  String get autoPaused => 'AUTO-PAUSED';

  @override
  String get paused => 'PAUSED';

  @override
  String get currentPace => 'Current pace';

  @override
  String get currentSpeed => 'Speed';

  @override
  String get allStepsDone => 'All steps done! Cool down and finish when ready.';

  @override
  String get onPace => 'On target';

  @override
  String get tooFast => 'Too fast';

  @override
  String get tooSlow => 'Too slow';

  @override
  String get left => 'left';

  @override
  String freeRunHint(int lo, int hi) {
    return 'Easy run? Stay at $lo–$hi bpm (Zone 2) – you should be able to talk in full sentences.';
  }

  @override
  String get workoutStructure => 'Workout structure';

  @override
  String get noSplitsYet => 'Splits appear after the first kilometer.';

  @override
  String get holdToFinish => 'Hold to finish';

  @override
  String get holdToUnlock => 'Hold to unlock';

  @override
  String get musicSub => 'Opens Spotify with music matching your workout tempo.';

  @override
  String musicForNow(String label) {
    return 'Right now: $label';
  }

  @override
  String get musicEasy => 'Easy run';

  @override
  String get musicTempo => 'Tempo run';

  @override
  String get musicIntervals => 'Intervals';

  @override
  String get musicPodcasts => 'Podcasts';

  @override
  String get musicPodcastsSub => 'Great for long easy runs';

  @override
  String get musicOwn => 'My playlist';

  @override
  String get musicSetOwn => 'Set my Spotify playlist link';

  @override
  String get musicChangeOwn => 'Change my playlist';

  @override
  String get vcGo => 'Let\'s go!';

  @override
  String get vcAutoPaused => 'Auto pause.';

  @override
  String get vcResumed => 'Resumed.';

  @override
  String get vcAllDone => 'All steps done. Great work! Cool down easy.';

  @override
  String get vcSlowDown => 'A bit slower – stay in your zone.';

  @override
  String get vcSpeedUp => 'Pick it up a little.';

  @override
  String vcKm(int n, String time, String pace) {
    return 'Kilometer $n. Time $time. Last kilometer $pace.';
  }

  @override
  String get zConversational => 'Easy';

  @override
  String get zEasyLong => 'Easy';

  @override
  String get zMarathon => 'Steady';

  @override
  String get zThreshold => 'Threshold';

  @override
  String get zInterval => 'Interval';

  @override
  String get zStride => 'Sprint';

  @override
  String get zJog => 'Recovery';

  @override
  String get zWalk => 'walk';

  @override
  String get zRecovery => 'Recovery';

  @override
  String get zSprint => 'sprint';

  @override
  String get zSwimEndurance => 'Endurance';

  @override
  String get zDrills => 'Technique';

  @override
  String get stepWarmup => 'Warm-up';

  @override
  String get stepCooldown => 'Cool-down';

  @override
  String get stepRecovery => 'Recovery';

  @override
  String stepWorkN(int x, int y) {
    return 'Interval $x/$y';
  }

  @override
  String get stepWork => 'Main set';

  @override
  String get stepSteady => 'Steady';

  @override
  String get phaseBase => 'Base phase';

  @override
  String get phaseBuild => 'Build phase';

  @override
  String get phasePeak => 'Peak phase';

  @override
  String get phaseTaper => 'Taper';

  @override
  String get phaseRecovery => 'Recovery week';

  @override
  String get keySession => 'Key session';

  @override
  String get viewSession => 'View workout';

  @override
  String get fitnessForm => 'Fitness & form';

  @override
  String get fitness => 'Fitness';

  @override
  String get fatigue => 'Fatigue';

  @override
  String get form => 'Form';

  @override
  String get formFresh => 'Fresh – ready for a race or hard session';

  @override
  String get formNeutral => 'Balanced – maintaining';

  @override
  String get formProductive => 'Productive training – fitness is building';

  @override
  String get formOverload => 'High fatigue – plan recovery';

  @override
  String get fitnessFormHint => 'Fitness = 42-day training load, fatigue = 7-day load, form = difference (Banister model).';

  @override
  String get bestEfforts => 'Running best efforts';

  @override
  String get racePredictions => 'Race predictions';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get middleDistance => 'Middle distance (70.3)';

  @override
  String get maxReps => 'Max reps';

  @override
  String get roundLap => 'Lap';

  @override
  String get linkGoogleSub => 'Sign in with Google next time – your data stays';

  @override
  String wGymTimeCapNote(int min) {
    return 'Only $min min available: do one set less per exercise or skip the last exercise.';
  }

  @override
  String get wShakeout => 'Shake-out run';

  @override
  String get wShakeoutDesc => '15 min very easy plus a few strides – loosen up, nothing more. Prepare your race kit tonight.';

  @override
  String wRace(String name) {
    return 'Race: $name';
  }

  @override
  String get wRaceDesc => 'Start controlled, find your rhythm, finish strong. Good luck!';

  @override
  String wRaceGoalDesc(String time) {
    return 'Goal time $time. Start controlled (first km not faster than goal pace), finish strong. Good luck!';
  }

  @override
  String get stepRaceNote => 'Race pace – even splits';

  @override
  String get intensityRace => 'Race';

  @override
  String gcalConnectedSub(String account) {
    return 'Connected · $account';
  }

  @override
  String get gcalHeroTitle => 'Your plan in Google Calendar';

  @override
  String get gcalHeroSub =>
      'Strive creates its own calendar called \"Strive\" and keeps it up to date automatically. Your other appointments are never read.';

  @override
  String get gcalConnect => 'Connect Google Calendar';

  @override
  String get gcalDisconnect => 'Disconnect';

  @override
  String get gcalSyncNow => 'Sync now';

  @override
  String get gcalSyncing => 'Syncing…';

  @override
  String get gcalAccount => 'Google account';

  @override
  String get gcalLastSync => 'Last sync';

  @override
  String get gcalEvents => 'Events';

  @override
  String get gcalAutoInfo => 'Automatic sync is on – changes to your plan show up in Google Calendar a few seconds later.';

  @override
  String gcalSynced(int count) {
    return '$count workouts synced';
  }

  @override
  String get gcalConnectedToast => 'Google Calendar connected';

  @override
  String get gcalDisconnectTitle => 'Disconnect Google Calendar?';

  @override
  String get gcalDisconnectBody =>
      'Strive will stop updating the calendar. Do you also want to delete the \"Strive\" calendar and all its events from your Google account?';

  @override
  String get gcalDeleteCalendar => 'Delete calendar';

  @override
  String get gcalKeepCalendar => 'Keep calendar';

  @override
  String get gcalDisconnected => 'Google Calendar disconnected';

  @override
  String get gcalHowTitle => 'How it works';

  @override
  String get gcalHow1 => 'Strive only gets access to calendars it created itself – it cannot see your other calendars or appointments.';

  @override
  String gcalHow2(String time) {
    return 'Workouts from the last 7 days up to 6 months ahead are entered at your preferred training time ($time).';
  }

  @override
  String get gcalHow3 => 'To hide the workouts, untick the \"Strive\" calendar in Google Calendar – syncing continues in the background.';

  @override
  String get gcalHow4 => 'Changes made in Google Calendar are overwritten on the next sync – edit your workouts in Strive.';

  @override
  String get gcalOpen => 'Open Google Calendar';

  @override
  String get gcalReconnect => 'Connect again';

  @override
  String get gcalErrApiDisabled =>
      'The Google Calendar API is not enabled for this app yet. The developer needs to enable it in the Google Cloud console (project strive-fitness-app).';

  @override
  String get gcalErrAuth => 'Google access has expired or was revoked. Please connect again.';

  @override
  String get gcalErrOffline => 'No connection to Google. Strive will try again automatically.';

  @override
  String get gcalErrRateLimit => 'Google is limiting requests right now. Please try again in a few minutes.';

  @override
  String gcalErrGeneric(String detail) {
    return 'Sync failed: $detail';
  }

  @override
  String get gcalCalendarDescription => 'Training plan from the Strive app. Managed automatically – changes made here will be overwritten.';

  @override
  String get gcalStructure => 'Structure';

  @override
  String get gcalEventFooter => 'Synced from Strive – edit this workout in the app.';

  @override
  String get planSettings => 'Plan settings';

  @override
  String get editPlanSettings => 'Edit plan settings';

  @override
  String get editPlanSettingsSub => 'Sports, week, times, sport data, goal – then a new plan';

  @override
  String get editProfileSub => 'Name, body data, level, health';

  @override
  String get timeTitle => 'Time per training day';

  @override
  String get timeHint => 'The most time you have on a training day – including warm-up and cool-down. Every session is planned to fit.';

  @override
  String get timeLongDayHint => 'On your long-session day (★) Strive plans up to 2 h unless you set that day yourself.';

  @override
  String get timePerDay => 'Set per day (optional)';

  @override
  String timeCustomDays(int count) {
    return '$count days set individually';
  }

  @override
  String get timeDefault => 'Back to default';

  @override
  String get recTitle => 'Recommendation for you';

  @override
  String get recSub => 'Based on your level, goal and focus. Rest days stay free on purpose – that is when you adapt.';

  @override
  String recPerWeek(int count) {
    return '$count× / week';
  }

  @override
  String get recAuto => 'Plan my week';

  @override
  String get recApplied => 'Week planned – adjust it as you like.';

  @override
  String get recActive => 'Recommendation applied';

  @override
  String recDays(int count) {
    return 'Recommended: $count training days';
  }

  @override
  String get recAutoDays => 'Use recommendation';

  @override
  String get splitTitle => 'Training split';

  @override
  String get splitHint => 'How your gym sessions are divided. Ideally every muscle is trained about 2× per week.';

  @override
  String get splitAuto => 'Automatic';

  @override
  String splitAutoSub(String name) {
    return 'Now: $name – adapts to your training days';
  }

  @override
  String get splitFullbody => 'Full body';

  @override
  String get splitFullbodySub => 'Whole body every session · ideal for 2–3 days';

  @override
  String get splitUpperLower => 'Upper / Lower';

  @override
  String get splitUpperLowerSub => 'Upper and lower body alternate · ideal for 4 days';

  @override
  String get splitPpl => 'Push / Pull / Legs';

  @override
  String get splitPplSub => 'Pressing, pulling, legs · ideal for 3 or 6 days';

  @override
  String get splitUlppl => 'Upper/Lower + PPL';

  @override
  String get splitUlpplSub => 'Hybrid of both · ideal for 5 days';

  @override
  String get splitBro => 'Bro split';

  @override
  String get splitBroSub => 'One muscle group per day · 5 days';

  @override
  String splitFreq(String value) {
    return 'Each muscle ~$value× per week with your days';
  }

  @override
  String get splitBroWarning =>
      'Each muscle only once a week. With the same weekly volume, training a muscle twice a week usually builds a little more muscle (Schoenfeld 2016) – fine if you enjoy it.';

  @override
  String splitForDays(int count) {
    return 'Best for $count days';
  }

  @override
  String get splitHomeNote => 'Training at home or with bodyweight uses full-body programs (2 alternating workouts).';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderNameHint => 'e.g. Summer cut';

  @override
  String get folderExists => 'A folder with this name already exists.';

  @override
  String get sortPrograms => 'Sort folders & programs';

  @override
  String get sortHint => 'Drag folders and programs by the handle to reorder them.';

  @override
  String get addBuiltinPrograms => 'Add built-in programs';

  @override
  String get addBuiltinProgramsSub => 'Evidence-based programs for every split plus structured run, ride and swim workouts.';

  @override
  String get builtinsComplete => 'You already have all built-in programs.';

  @override
  String programsAdded(int count) {
    return '$count programs added';
  }

  @override
  String deleteFolderTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteFolderEmpty => 'The folder is empty.';

  @override
  String deleteFolderBody(int count) {
    return 'The folder contains $count programs. Keep them (without folder) or delete everything?';
  }

  @override
  String get deleteFolderKeep => 'Keep programs';

  @override
  String get deleteFolderAll => 'Delete all';

  @override
  String programsCount(int count) {
    return '$count programs';
  }

  @override
  String get folderEmpty => 'No programs yet – add one via the menu.';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get copy => 'copy';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String stepsCount(int count) {
    return '$count sections';
  }

  @override
  String get addSection => 'Section';

  @override
  String get addRepeat => 'Repeats';

  @override
  String get editSection => 'Edit section';

  @override
  String get byTime => 'Time';

  @override
  String get byDistance => 'Distance';

  @override
  String get discardChanges => 'Discard changes?';

  @override
  String setsN(int count) {
    return '$count sets';
  }

  @override
  String get structuredWorkout => 'Structured';

  @override
  String get structuredWorkoutSub => 'Phases with targets – guided step by step during the workout (voice, pace/power/HR).';

  @override
  String get freeWorkoutSub => 'Just a duration or distance goal, no sections.';

  @override
  String get supersetLinked => 'Superset – tap to unlink';

  @override
  String get repRange => 'Rep range';

  @override
  String get repRangeHint => 'Double progression: add reps until you hit the top of the range on all sets, then increase the weight.';

  @override
  String get exerciseLoadError => 'Exercises could not be loaded.';

  @override
  String vcStepN(int x, int y) {
    return 'Interval $x of $y';
  }

  @override
  String vcSplitRide(int n, String time, int km, String speed) {
    return 'Kilometer $n. Time $time. Last $km kilometers at $speed.';
  }

  @override
  String vcSplitSwim(int n, String time, String pace) {
    return 'Kilometer $n. Time $time. Pace $pace.';
  }

  @override
  String vcKmh(String speed) {
    return '$speed kilometers per hour';
  }

  @override
  String vcPer100m(String pace) {
    return '$pace per 100 meters';
  }

  @override
  String vcPaceRange100(String a, String b) {
    return '$a to $b per 100 meters';
  }

  @override
  String vcPowerRange(int lo, int hi) {
    return '$lo to $hi watts';
  }

  @override
  String vcHrRange(int lo, int hi) {
    return 'heart rate $lo to $hi';
  }

  @override
  String get vcAllDoneRide => 'All sections done. Great work! Spin out easy.';

  @override
  String get vcAllDoneSwim => 'All sets done. Great work! Swim a few easy lengths.';

  @override
  String get allStepsDoneRide => 'All sections done! Spin out easy and finish when ready.';

  @override
  String get allStepsDoneSwim => 'All sets done! Swim out easy and finish when ready.';

  @override
  String freeRideHint(int lo, int hi) {
    return 'Easy ride? Stay at $lo–$hi bpm (Zone 2) – you should be able to chat comfortably.';
  }

  @override
  String get stepRest => 'Rest';

  @override
  String get stepSteadyRide => 'Endurance ride';

  @override
  String get stepSteadySwim => 'Steady swim';

  @override
  String get stepDrillsTitle => 'Drills';

  @override
  String get zThresholdRide => 'threshold';

  @override
  String get lengthBtn => 'Length';

  @override
  String get lengths => 'Lengths';

  @override
  String nLengths(int lengths) {
    String _temp0 = intl.Intl.pluralLogic(lengths, locale: localeName, other: '$lengths lengths', one: '1 length');
    return '$_temp0';
  }

  @override
  String get undoLength => 'Undo';

  @override
  String get lengthUndone => 'Last length removed';

  @override
  String get lastLength => 'Last length';

  @override
  String get pace100 => 'Pace /100 m';

  @override
  String get avgPace100 => 'Avg. /100 m';

  @override
  String get maxSpeed => 'Max. speed';

  @override
  String get workoutLeft => 'Workout left';

  @override
  String get section => 'Section';

  @override
  String get poolTapHint => 'Tap LENGTH each time you touch the wall.';

  @override
  String get noLengthsYet => 'Your lengths appear here after the first tap.';

  @override
  String get keySessionSub => 'Important session of the week – Strive keeps hard days apart.';

  @override
  String get workoutPhases => 'Phases';

  @override
  String get planDone => 'Plan done';

  @override
  String get perSport => 'Per sport';

  @override
  String get recoveryTitle => 'Recovery & load';

  @override
  String get load7d => 'Load 7 days';

  @override
  String get load28d => 'Ø week (28 d)';

  @override
  String get daysInARow => 'Days in a row';

  @override
  String get recoveryHowTitle => 'How this works';

  @override
  String get recoveryHowText =>
      'Every workout gets a load score (duration × intensity, from RPE or heart rate). Strive compares the last 7 days with your average week of the last 28 days (acute:chronic workload ratio, Gabbett 2016). Between 0.8 and 1.3 you build fitness with a low injury risk; above 1.5 the risk rises clearly – plan an easy day. Fitness, fatigue and form follow the Banister model: form = fitness − fatigue.';

  @override
  String nWorkouts(int count) {
    return '$count workouts';
  }

  @override
  String sessionN(int n) {
    return 'Session $n';
  }

  @override
  String get byDay => 'Day by day';

  @override
  String get planExercisesHint => 'Changes apply to this workout only – the program stays as it is.';

  @override
  String planExercisesCustom(String name) {
    return 'Adjusted for this workout (program: $name).';
  }

  @override
  String get saveToProgram => 'Save to program';

  @override
  String savedToProgram(String name) {
    return 'Saved to \"$name\"';
  }

  @override
  String get resetToProgram => 'Reset';

  @override
  String get adjustExercises => 'Adjust exercises';

  @override
  String get zSwimEasy => 'Easy';

  @override
  String get zEndurance => 'Endurance';

  @override
  String get zCss => 'CSS pace';

  @override
  String get zTempo => 'Tempo';

  @override
  String get zoneInfoTitle => 'Intensity zones';

  @override
  String get zoneInfoRun =>
      'Paces come from your race times (VDOT, Jack Daniels). Most of your running – about 80 % – should be easy; the faster zones are used in short, targeted doses.';

  @override
  String get zoneInfoRide =>
      'Power zones are percentages of your FTP (the power you can hold for about one hour). Without a power meter, ride by heart rate and feel.';

  @override
  String get zoneInfoSwim => 'Paces per 100 m come from your critical swim speed (CSS, from a 400 m and 200 m test).';

  @override
  String get zoneInfoEstimated => '≈ values are estimated from your level – add a test result in the plan settings for exact targets.';

  @override
  String get zfVeryEasy => 'RPE 1–2 · very easy';

  @override
  String get zfEasy => 'RPE 3–4 · full sentences';

  @override
  String get zfDrills => 'focus on form';

  @override
  String get zfModerate => 'RPE 5–6 · short sentences';

  @override
  String get zfHard => 'RPE 7–8 · single words';

  @override
  String get zfVeryHard => 'RPE 8–9 · no talking';

  @override
  String get zfMax => 'RPE 9–10 · fast & relaxed';

  @override
  String get zdRunRec => 'Walking or very slow jogging between hard efforts and for warming up. Lets your heart rate come down.';

  @override
  String get zdRunEasy =>
      'Your everyday pace: relaxed, you can talk in full sentences. Builds the aerobic base, used for easy and long runs.';

  @override
  String get zdRunSteady => 'Controlled but purposeful, about your marathon pace. Used in long-run finishes and steady runs.';

  @override
  String get zdRunThreshold =>
      '\"Comfortably hard\" – a pace you could hold for about an hour. Tempo runs and cruise intervals raise your lactate threshold.';

  @override
  String get zdRunInterval => 'About your 3–5 km race pace. Efforts of 2–5 minutes with recovery jogs improve your VO2max.';

  @override
  String get zdRunSprint => 'Short, fast but relaxed efforts (strides, 10–30 s) with full recovery. Improves running economy and form.';

  @override
  String get zdRideRec => 'Spinning easily, for warm-up, cool-down and recovery rides.';

  @override
  String get zdRideEndurance => 'The base of cycling training: long, steady rides at a pace you can hold for hours.';

  @override
  String get zdRideSweetSpot => 'Just below threshold: hard but sustainable for 10–40 minutes. Very time-efficient for building FTP.';

  @override
  String get zdRideThreshold => 'Around your FTP – the effort of a one-hour time trial. Blocks of 8–20 minutes.';

  @override
  String get zdRideVo2 => 'Very hard efforts of 2–6 minutes that push your maximal oxygen uptake.';

  @override
  String get zdRideSprint => 'Short all-out bursts (up to 30 s) for power and speed, with long recoveries.';

  @override
  String get zdSwimEasy => 'Loose, relaxed swimming for warm-up, cool-down and rests. Focus on long strokes and calm breathing.';

  @override
  String get zdSwimDrills =>
      'Technique drills: exercises that isolate one part of the stroke (arm pull, body position, rotation, breathing). Speed does not matter – swim slowly and precisely. Tap \"Technique drills\" below for the exercises.';

  @override
  String get zdSwimEndurance => 'Steady aerobic swimming, a few seconds slower than CSS per 100 m. The main zone for longer sets.';

  @override
  String get zdSwimCss => 'Your critical swim speed – about your 1500 m race pace. Hard but even, with short rests (10–20 s).';

  @override
  String get zdSwimSprint => 'Short, fast lengths (25–50 m) with long rests for speed and power.';

  @override
  String get swimDrillsTitle => 'Technique drills';

  @override
  String get swimDrillsIntro =>
      'In a technique set you swim these drills instead of normal freestyle, e.g. 50 m drill / 50 m freestyle. Swim slowly and concentrate on one thing per length.';

  @override
  String get drillCatchupName => 'Catch-up';

  @override
  String get drillCatchupHow => 'One arm stays stretched in front until the other arm touches it, then it starts its pull.';

  @override
  String get drillCatchupWhy => 'Longer stroke, better glide and timing.';

  @override
  String get drillFingertipName => 'Fingertip drag';

  @override
  String get drillFingertipHow => 'During the recovery, drag your fingertips along the water surface from hip to head.';

  @override
  String get drillFingertipWhy => 'High elbow and relaxed arm recovery.';

  @override
  String get drillSideKickName => '6-1-6 side kick';

  @override
  String get drillSideKickHow =>
      'Kick 6 times on your side (lower arm stretched forward), take one stroke, kick 6 times on the other side.';

  @override
  String get drillSideKickWhy => 'Body position, rotation and calm breathing.';

  @override
  String get drillSingleArmName => 'Single arm';

  @override
  String get drillSingleArmHow => 'One arm stays in front, the other one swims alone; switch arms every length.';

  @override
  String get drillSingleArmWhy => 'Clean underwater pull and rotation to the breathing side.';

  @override
  String get drillFistName => 'Fist swimming';

  @override
  String get drillFistHow => 'Swim freestyle with closed fists; open your hands again for the last 10 m.';

  @override
  String get drillFistWhy => 'You learn to pull with the whole forearm (early vertical forearm).';

  @override
  String get drillScullName => 'Sculling';

  @override
  String get drillScullHow => 'Lying flat, move your hands in small figure-eights in front of your head to move forward.';

  @override
  String get drillScullWhy => 'Feel for the water and a strong catch.';

  @override
  String drillsNote(String a, String b) {
    return '$a / $b – alternate 50 m drill, 50 m freestyle';
  }

  @override
  String intensityAuto(String name) {
    return '$name (from the structure)';
  }

  @override
  String get showDrills => 'Show drills';

  @override
  String streakWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count weeks in a row', one: '1 week in a row');
    return '$_temp0';
  }

  @override
  String get streakThisWeek => 'This week';

  @override
  String streakWeekDone(int done, int target) {
    return 'Goal reached: $done of $target training days – this week counts!';
  }

  @override
  String streakWeekLeft(int done, int target, int count) {
    return '$done of $target training days – $count more to keep the streak going.';
  }

  @override
  String get streakLastWeeks => 'Last 8 weeks';

  @override
  String get streakHow =>
      'A week counts when you train on as many days as planned. With a training plan, the goal is the number of days with planned workouts that week (two sessions on one day count as one day); without a plan it is your number of training days. The current week never breaks your streak – it is added as soon as you reach the goal.';

  @override
  String get showPastWeeks => 'Past weeks';

  @override
  String loadSuggestion(String load) {
    return 'Suggestion: $load';
  }

  @override
  String loadApprox(String weight, int reps) {
    return '≈ $weight × $reps';
  }

  @override
  String loadApproxPerHand(String weight, int reps) {
    return '≈ $weight × $reps per hand';
  }

  @override
  String loadBodyweight(int reps) {
    return 'Bodyweight × $reps';
  }

  @override
  String loadBodyweightPlus(String weight, int reps) {
    return 'Bodyweight +$weight × $reps';
  }

  @override
  String get loadSrcHistory => 'from your last workout';

  @override
  String get loadSrcIncrease => 'all reps done last time – more weight';

  @override
  String get loadSrcAddReps => 'from your last workout – aim for one more rep';

  @override
  String get loadSrcDeload => 'last time was tough – a bit lighter';

  @override
  String get loadSrcBreak => 'a bit lighter after your break';

  @override
  String get loadSrcOneRm => 'from your 1RM in the setup';

  @override
  String get loadSrcEstimate => 'estimated from body weight – adjust it';

  @override
  String get loadPhaseLighter => 'deload week';

  @override
  String get loadTaperLighter => 'taper week';

  @override
  String get scoreLegendTitle => 'Outdoor training conditions';

  @override
  String get scoreGood => 'Good';

  @override
  String get scoreFair => 'Fair';

  @override
  String get scorePoor => 'Poor';

  @override
  String get scoreHowTitle => 'How the score works';

  @override
  String get scoreHowIntro =>
      'Every hour gets a score from 0 to 100 for outdoor endurance training. It starts at 100 and loses points for:';

  @override
  String get scoreHowTemp => 'Feels-like temperature outside 7–16 °C (ideal for running): −3.5 per °C colder, −4.5 per °C warmer';

  @override
  String get scoreHowRain => 'Rain: chance of rain and expected amount';

  @override
  String get scoreHowWind => 'Wind above 20 km/h';

  @override
  String get scoreHowUv => 'UV index above 6';

  @override
  String get scoreHowDark => 'Darkness (−18)';

  @override
  String get scoreHowStorm => 'Thunderstorm (−40)';

  @override
  String get scoreHowLevels => 'Good from 70, fair from 45, below that rather train indoors.';

  @override
  String get streakSub => 'with your weekly training goal reached';

  @override
  String wSwimCssSet(int n, int meters) {
    return 'CSS set $n × $meters m';
  }

  @override
  String complianceGreen(int pct) {
    return 'Completed as planned ($pct% of plan)';
  }

  @override
  String complianceYellow(int pct) {
    return 'Completed, partly off plan ($pct% of plan)';
  }

  @override
  String complianceOrange(int pct) {
    return 'Completed, far off plan ($pct% of plan)';
  }

  @override
  String get complianceDone => 'Completed';

  @override
  String get complianceMissed => 'Missed';

  @override
  String get compliancePlanned => 'Planned';

  @override
  String get complianceSkipped => 'Skipped';

  @override
  String planCompletion(int pct) {
    return 'Plan completion $pct%';
  }

  @override
  String get weightMinus => 'Decrease weight';

  @override
  String get weightPlus => 'Increase weight';

  @override
  String get previousWorkout => 'Previous workout';

  @override
  String get nextWorkout => 'Next workout';

  @override
  String get avgHrShort => 'Avg. HR';

  @override
  String get caloriesLabel => 'Calories';

  @override
  String recordedWith(String source) {
    return 'Recorded with $source';
  }

  @override
  String get sessionGone => 'This workout no longer exists.';

  @override
  String adjustWeekBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n planned workouts missed – adjust your week?',
      one: '1 planned workout missed – adjust your week?',
    );
    return '$_temp0';
  }

  @override
  String get adjustWeekTitle => 'Adjust my week';

  @override
  String get adjustWeekIntro =>
      'Key workouts move to a free day this week – never right next to another hard session. Easy workouts don\'t need to be made up: piling up volume does more harm than good.';

  @override
  String adjustReplaces(String title) {
    return 'replaces $title';
  }

  @override
  String get adjustDropped => 'dropped – no need to make it up';

  @override
  String get adjustNoRoom => 'dropped – no free day this week without a hard session next to it';

  @override
  String get adjustProtected => 'dropped – recovery/taper week stays easy';

  @override
  String get adjustDone => 'Week adjusted';

  @override
  String get notNow => 'Not now';

  @override
  String wTriLegs(String swim, String bike, String run) {
    return 'Swim $swim km · Bike $bike km · Run $run km';
  }

  @override
  String get quickMinOneDay => 'Choose at least one training day';

  @override
  String quickDaysCapped(int n, int total) {
    return 'Your plan uses $n of your $total days – the others stay rest days so you recover between sessions.';
  }
}
