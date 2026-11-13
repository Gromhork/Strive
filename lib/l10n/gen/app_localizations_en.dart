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
  String get fitnessLevel => 'Experience';

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
  String get goalRace => 'Race';

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
  String get eventName => 'Race name';

  @override
  String get eventDate => 'Race date';

  @override
  String get eventDistance => 'Distance';

  @override
  String get halfMarathon => 'Half marathon';

  @override
  String get marathon => 'Marathon';

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
  String get readyFreshText => 'Your load is low – a great time for a key workout or more volume.';

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
    return 'XP level $level';
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
  String get startTraining => 'Start workout';

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
  String get generatePlan => 'Create plan';

  @override
  String generatePlanSub(String focus, int days) {
    return 'Focus: $focus · $days days/week (change in plan settings)';
  }

  @override
  String get planLocalDesc => 'Periodised plan based on sports science (80/20, progressive overload, a recovery week every 3–5 weeks depending on difficulty). Works offline.';

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
  String get coachQ2 => 'Why does my week look like this?';

  @override
  String get coachQ3 => 'How do I get faster over 10 km?';

  @override
  String get coachQ4 => 'I slept badly – should I still train today?';

  @override
  String get coachQ5 => 'I\'m sick/tired – what should I change?';

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
  String get eventPassed => 'Race is over';

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
  String get trainingReminder => 'Training reminder';

  @override
  String trainingReminderSub(String time) {
    return 'On training days at $time';
  }

  @override
  String get reminderTime => 'Time';

  @override
  String get notificationsDenied => 'Notifications are blocked in system settings.';

  @override
  String trainingReminderTitle(String sport) {
    return 'Today: $sport';
  }

  @override
  String get integrations => 'Integrations';

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
  String get progAddReps => 'same weight – one more rep than last time';

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
  String get setupDetailedSub => 'Race times, weekly volume, FTP, swim test, max lifts and a weekday plan – for a precise plan from day one.';

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
  String get diffEasySub => '+5 % volume/week, a deload week every 3rd week, mostly easy sessions.';

  @override
  String get diffBalanced => 'Balanced';

  @override
  String get diffBalancedSub => '+8 % volume/week, a deload week every 4th week, ~80/20 easy/hard.';

  @override
  String get diffChallenging => 'Challenging';

  @override
  String get diffChallengingSub => '+10 % volume/week, more key workouts – for experienced athletes.';

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
    return 'Recommended for your goal: $lo–$hi weeks.';
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
  String get planScienceNote => 'Plans follow e.g. Seiler (80/20), Daniels (VDOT paces), Bosquet (taper), Schoenfeld (strength volume). Details in the plan view.';

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
  String get hcSub => 'Your watch syncs to Samsung Health, Samsung Health shares with Health Connect, and Strive reads your workouts, heart rate, sleep and steps – and writes your Strive workouts back.';

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
  String get hcWhatSyncedBody => 'Read: workouts (run, ride, swim, strength) incl. avg/max heart rate, distance and calories, resting heart rate, HRV, sleep, steps, weight, body fat. Write: Strive workouts and weight entries.';

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
  String get zStride => 'Fast';

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
  String get keySession => 'Key workout';

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
  String get formFresh => 'Fresh – ready for a race or key workout';

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
  String get gcalHeroSub => 'Strive creates its own calendar called \"Strive\" and keeps it up to date automatically. Your other appointments are never read.';

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
  String get gcalDisconnectBody => 'Strive will stop updating the calendar. Do you also want to delete the \"Strive\" calendar and all its events from your Google account?';

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
  String get gcalErrApiDisabled => 'The Google Calendar API is not enabled for this app yet. The developer needs to enable it in the Google Cloud console (project strive-fitness-app).';

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
  String get editProfileSub => 'Name, body data, experience, health';

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
  String get splitBroWarning => 'Each muscle only once a week. With the same weekly volume, training a muscle twice a week usually builds a little more muscle (Schoenfeld 2016) – fine if you enjoy it.';

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
    String _temp0 = intl.Intl.pluralLogic(
      lengths,
      locale: localeName,
      other: '$lengths lengths',
      one: '1 length',
    );
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
  String get keySessionSub => 'Important workout of the week – Strive keeps hard days apart.';

  @override
  String get workoutPhases => 'Sequence';

  @override
  String get planDone => 'Done';

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
  String get recoveryHowText => 'Every workout gets a load score (duration × intensity, from RPE or heart rate). Strive compares the last 7 days with your average week of the last 28 days (acute:chronic workload ratio, Gabbett 2016). Between 0.8 and 1.3 you build fitness with a low injury risk; above 1.5 the risk rises clearly – plan an easy day. Fitness, fatigue and form follow the Banister model: form = fitness − fatigue.';

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
  String get zoneInfoRun => 'Paces come from your race times (VDOT, Jack Daniels). Most of your running – about 80 % – should be easy; the faster zones are used in short, targeted doses.';

  @override
  String get zoneInfoRide => 'Power zones are percentages of your FTP (the power you can hold for about one hour). Without a power meter, ride by heart rate and feel.';

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
  String get zdRunEasy => 'Your everyday pace: relaxed, you can talk in full sentences. Builds the aerobic base, used for easy and long runs.';

  @override
  String get zdRunSteady => 'Controlled but purposeful, about your marathon pace. Used in long-run finishes and steady runs.';

  @override
  String get zdRunThreshold => '\"Comfortably hard\" – a pace you could hold for about an hour. Tempo runs and cruise intervals raise your lactate threshold.';

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
  String get zdSwimDrills => 'Technique drills: exercises that isolate one part of the stroke (arm pull, body position, rotation, breathing). Speed does not matter – swim slowly and precisely. Tap \"Technique drills\" below for the exercises.';

  @override
  String get zdSwimEndurance => 'Steady aerobic swimming, a few seconds slower than CSS per 100 m. The main zone for longer sets.';

  @override
  String get zdSwimCss => 'Your critical swim speed – about your 1500 m race pace. Hard but even, with short rests (10–20 s).';

  @override
  String get zdSwimSprint => 'Short, fast lengths (25–50 m) with long rests for speed and power.';

  @override
  String get swimDrillsTitle => 'Technique drills';

  @override
  String get swimDrillsIntro => 'In a technique set you swim these drills instead of normal freestyle, e.g. 50 m drill / 50 m freestyle. Swim slowly and concentrate on one thing per length.';

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
  String get drillSideKickHow => 'Kick 6 times on your side (lower arm stretched forward), take one stroke, kick 6 times on the other side.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks in a row',
      one: '1 week in a row',
    );
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
  String get streakHow => 'A week counts when you train on as many days as planned. With a training plan, the goal is the number of days with planned workouts that week (two sessions on one day count as one day); without a plan it is your number of training days. The current week never breaks your streak – it is added as soon as you reach the goal.';

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
  String get loadPhaseLighter => 'recovery week';

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
  String get scoreHowIntro => 'Every hour gets a score from 0 to 100 for outdoor endurance training. It starts at 100 and loses points for:';

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
      other: '$n planned workouts missed – adjust week?',
      one: '1 planned workout missed – adjust week?',
    );
    return '$_temp0';
  }

  @override
  String get adjustWeekTitle => 'Adjust week';

  @override
  String get adjustWeekIntro => 'Key workouts move to a free day this week – never right next to another key workout. Easy workouts don\'t need to be made up: piling up volume does more harm than good.';

  @override
  String adjustReplaces(String title) {
    return 'Replaces $title';
  }

  @override
  String get adjustDropped => 'Dropped – no need to make it up';

  @override
  String get adjustNoRoom => 'Dropped – no free day this week without a key session next to it';

  @override
  String get adjustProtected => 'Dropped – deload/taper week stays easy';

  @override
  String get adjustDone => 'Week adjusted';

  @override
  String get notNow => 'Not now';

  @override
  String wTriLegs(String swim, String bike, String run) {
    return 'Swim $swim km · Bike $bike km · Run $run km';
  }

  @override
  String get editSession => 'Edit workout';

  @override
  String get durationHms => 'Duration (h:mm:ss or mm:ss)';

  @override
  String get invalidDuration => 'Enter the duration as h:mm:ss or minutes.';

  @override
  String get rpeNotSet => 'not set';

  @override
  String get sessionCorrected => 'Workout updated';

  @override
  String get editSessionHint => 'Correct wrong measurements or entries. Recorded route and splits stay as they are.';

  @override
  String get deleted => 'Deleted';

  @override
  String get supersetHint => 'Alternate the exercises – short switch, full rest after each round';

  @override
  String get supersetMax => 'A superset has at most 3 exercises.';

  @override
  String get supersetSwitch => 'Switch exercise';

  @override
  String get supersetSwitchHint => 'Short break – then straight on to the next exercise of the superset.';

  @override
  String get bodyweight => 'Bodyweight';

  @override
  String get bodyweightShort => 'BW';

  @override
  String get bodyweightHint => 'Weight = added load on top of your body weight (negative = assistance).';

  @override
  String get addedWeight => 'Added weight';

  @override
  String targetLoad(String load, int lo, int hi) {
    return 'Target: $load · $lo–$hi reps';
  }

  @override
  String targetToday(String list) {
    return 'Today: $list reps';
  }

  @override
  String loadWeightApprox(String weight) {
    return '≈ $weight';
  }

  @override
  String loadWeightPerHand(String weight) {
    return '≈ $weight per hand';
  }

  @override
  String get loadSrcHold => 'keep the weight and hit all target reps';

  @override
  String get loadSrcStall => 'no progress for 3 workouts – a bit lighter, then build up again';

  @override
  String get loadSrcIncreaseBw => 'all reps done – add a little weight (belt or vest)';

  @override
  String get loadSrcMoreReps => 'all reps done – go for more reps';

  @override
  String get loadTotal => 'total';

  @override
  String get quickMinOneDay => 'Choose at least one training day';

  @override
  String quickDaysCapped(int n, int total) {
    return 'Your plan uses $n of your $total days – the others stay rest days so you recover between sessions.';
  }

  @override
  String get wCrossRide => 'Easy ride instead of a run';

  @override
  String get wCrossRideDesc => 'Same aerobic training without impact – easier on knees, hips and Achilles tendons. Bike or indoor trainer at a conversational effort.';

  @override
  String get healthRunNote => 'Joints: prefer soft surfaces; stop if pain goes above 3/10 or changes your stride.';

  @override
  String get healthHeartNote => 'Heart / blood pressure: intensity capped at threshold – no all-out efforts.';

  @override
  String get healthSwimShoulderNote => 'Shoulder: no paddles, breathe to both sides, stop if it hurts.';

  @override
  String get healthGymBackNote => 'Back: no heavy axial loading – swap back squats and deadlifts for leg press, split squats or hip thrusts; keep a neutral spine.';

  @override
  String get healthGymShoulderNote => 'Shoulder: no heavy overhead pressing – use landmine or neutral-grip variants and stay pain-free.';

  @override
  String get healthGymJointNote => 'Joints: train in a pain-free range – reduce depth or load if knee or hip hurt.';

  @override
  String get healthGymHeartNote => 'Heart / blood pressure: keep 2–3 reps in reserve and breathe out on the effort – no straining or breath holding.';

  @override
  String get recalNote => 'Adjusted to your recent training (effort and completed sessions).';

  @override
  String get recalButton => 'Review plan';

  @override
  String get recalTitle => 'Review plan';

  @override
  String get recalIntro => 'Your next two weeks, adapted to the last two: effort (RPE), completed and missed sessions, new best efforts. Completed workouts stay as they are.';

  @override
  String get recalFindings => 'What we see';

  @override
  String get recalChanges => 'Proposed changes';

  @override
  String get recalWhyRpeHigh => 'Several sessions felt harder than planned – more recovery first.';

  @override
  String get recalWhyRpeLow => 'Your key workouts felt easy – a little more volume.';

  @override
  String recalWhyCompletion(int pct) {
    return '$pct % of the planned training done – no increase for now, a bit less volume.';
  }

  @override
  String recalWhyCutShort(int n) {
    return '$n sessions ended early – long sessions get shorter.';
  }

  @override
  String get recalWhyMissed => 'Missed key workouts move to a free day this week.';

  @override
  String recalWhyFaster(String from, String to) {
    return 'New best effort: running fitness (VDOT) $from → $to – paces updated.';
  }

  @override
  String recalWhySlower(String to, String from) {
    return 'Your real running fitness (VDOT $to) differs from the estimate ($from) – paces updated.';
  }

  @override
  String get recalOnTrack => 'You are on track – the plan fits your training. Nothing to change.';

  @override
  String get recalNoRpe => 'Tip: rate your effort (RPE) after workouts – the plan can then adapt to how they felt.';

  @override
  String get recalEasier => 'Easier';

  @override
  String get recalHarder => 'A bit more';

  @override
  String get recalToEasy => 'Easy instead of hard';

  @override
  String get recalMoved => 'Moved';

  @override
  String get recalDropped => 'Dropped';

  @override
  String get recalPaces => 'New paces';

  @override
  String recalApply(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Apply $n changes',
      one: 'Apply 1 change',
    );
    return '$_temp0';
  }

  @override
  String get recalApplied => 'Plan adapted';

  @override
  String get recalNewPlan => 'Start plan over…';

  @override
  String get recalMore => 'More';

  @override
  String wGymDescRange(int sets, int rir) {
    return '$sets sets per exercise in each exercise\'s rep range, leave $rir reps in the tank. Add reps first; once every set reaches the top of the range, add weight and start again at the bottom.';
  }

  @override
  String wGymLoadDesc(int rir) {
    return 'Loading week: end every work set with about $rir reps in the tank – the reserve shrinks week by week until the next deload. Sets, rep range and suggested weight are shown for each exercise.';
  }

  @override
  String get wGymProgressNote => 'Progression: first build reps up to the top of the range, then add weight and start again at the bottom.';

  @override
  String get wGymDeloadNote => 'Deload week: weights are entered about 10 % lighter and exercises with 3+ sets lose one. Train cleanly with about 4 reps in the tank – fatigue drops and you come back stronger.';

  @override
  String get wGymTaperNote => 'Taper before your race: weights about 10 % lighter, nothing to failure – keep your strength, stay fresh.';

  @override
  String wGymTimeCapNote2(int min) {
    return 'Only $min min today: do the main lifts as planned, drop a set of the last exercises or skip them.';
  }

  @override
  String get wRecoveryWeekNote => 'Deload week: volume is reduced on purpose – keep it easy even if you feel fresh. This is when your body absorbs the last weeks.';

  @override
  String get wTaperWeekNote => 'Taper: less volume, short efforts stay sharp. Don\'t make up for anything – freshness for race day counts now.';

  @override
  String get wLongRunHmpDesc => 'Easy long run, the last quarter at your half-marathon goal pace – the most race-specific session.';

  @override
  String get stepHmpNote => 'Half-marathon goal pace – controlled';

  @override
  String get wLongRunMpDesc2 => 'Easy long run, the last quarter at your marathon goal pace – the most race-specific session.';

  @override
  String recalWhyRunTrendSlower(String from, String to) {
    return 'Your key runs were slower than the target paces at a high effort – paces eased (VDOT $from → $to).';
  }

  @override
  String recalWhyRunTrendFaster(String from, String to) {
    return 'Your key runs hit the target paces and felt easy – paces a little faster (VDOT $from → $to).';
  }

  @override
  String recalWhyFtpUp(String from, String to) {
    return 'Bike: power above the targets without extra effort – FTP $from → $to W, power targets updated.';
  }

  @override
  String recalWhyFtpDown(String from, String to) {
    return 'Bike: the power targets were too hard to hold – FTP $from → $to W, power targets updated.';
  }

  @override
  String recalWhyCssFaster(String from, String to) {
    return 'Swim: faster than the target paces at a comfortable effort – CSS $from → $to per 100 m.';
  }

  @override
  String recalWhyCssSlower(String from, String to) {
    return 'Swim: the target paces were too hard to hold – CSS $from → $to per 100 m.';
  }

  @override
  String recalWhyAerobicUp(int pct) {
    return 'Aerobic efficiency (speed per heartbeat at easy effort) +$pct % over 6 weeks – your base is growing.';
  }

  @override
  String recalWhyAerobicDown(int pct) {
    return 'Aerobic efficiency (speed per heartbeat at easy effort) −$pct % over 6 weeks – watch recovery, sleep and heat.';
  }

  @override
  String autoAdjSnack(String workout, String date, String after, String before) {
    return 'Plan adapted: $workout $date now $after instead of $before';
  }

  @override
  String autoAdjSnackMany(int n) {
    return 'Plan adapted: $n upcoming workouts';
  }

  @override
  String get autoAdjTitle => 'Adapted automatically';

  @override
  String autoAdjOriginal(String value) {
    return 'Originally planned: $value';
  }

  @override
  String get autoAdjUndone => 'Original plan restored';

  @override
  String get autoAdjLongCutShort => 'Your last long session ended early at a high effort – this one is held at what you managed plus about 10 % instead of growing.';

  @override
  String get autoAdjLongHard => 'Your last long session felt harder than intended – this one stays at the same length instead of growing.';

  @override
  String get autoAdjEasyHard => 'Your last easy session was harder than intended (heart rate / effort) – this one is a little shorter. Keep it truly easy: you should be able to talk in full sentences.';

  @override
  String get autoAdjEasyTooFast => 'Your last easy session was faster than the easy pace – this one is a little shorter. Slow down: easy days build the aerobic base (80/20).';

  @override
  String get autoAdjQualityHard => 'Your last key workout was harder than intended – this one is not increased.';

  @override
  String get autoAdjQualityEasy => 'Your last key workout hit the targets and felt easy – this one is 5 % longer.';

  @override
  String get progTopReached => 'all sets at the top of the range – more weight';

  @override
  String get progTopWithReserve => 'all sets at the top with reps in reserve – bigger jump';

  @override
  String get progTopAtLimit => 'top reached, but at your limit – same weight once more';

  @override
  String get progMicroload => 'the next weight step would be too big – more reps first';

  @override
  String get progAddRepsFast => 'good reserve – two more reps per set';

  @override
  String get progRepsNoLoad => 'more reps – that is the progression here';

  @override
  String get progHoldLimit => 'last time was at your limit – same reps again';

  @override
  String get progHoldHard => 'hold the weight: last 2 sessions were hard';

  @override
  String get progMissedHold => 'just short of the range – hold the weight';

  @override
  String get progMissedReduce => 'reps clearly missed – a bit lighter';

  @override
  String get progPerformanceDip => 'hold the weight: last 2 sessions below your level';

  @override
  String get progPerformanceDrop => 'last 2 sessions clearly weaker – 5–10 % lighter to recover';

  @override
  String get effortQuestion => 'How did it feel?';

  @override
  String effortQuestionFor(String name) {
    return 'How was $name?';
  }

  @override
  String get effortOptional => 'Optional – helps pick your next weights';

  @override
  String get effortEasy => 'Easy';

  @override
  String get effortRight => 'Just right';

  @override
  String get effortHard => 'Hard';

  @override
  String get effortLimit => 'Limit';

  @override
  String get howHardOptional => 'How hard was it? (optional)';

  @override
  String get rpeOptionalHint => 'Helps adapt your plan – you can skip it.';

  @override
  String get rpeClear => 'No rating';

  @override
  String get rpeRate => 'Rate';

  @override
  String get progLinear => 'all target reps done – a bit more weight, same reps (beginner linear progression)';

  @override
  String get progNudge => 'held twice and every target met – one more rep on the weakest set';

  @override
  String get progRecalibrated => 'your AMRAP set showed more strength – weight adjusted to it';

  @override
  String get progE1rmFloor => 'no reps missed – the weight stays near your strength level';

  @override
  String get amrapHint => 'Last set: as many reps as possible – stop 1 rep before failure (helps the app learn your strength)';

  @override
  String get amrapShort => 'AMRAP';

  @override
  String recalWhyBreak(int days) {
    return 'No training for $days days: the first week back restarts at 50–70 % of the planned volume, without intensity, then builds up again.';
  }

  @override
  String get recalWhyLongCap => 'Long sessions stay within +10 % of your longest one of the last 30 days – beyond that the injury risk rises.';

  @override
  String get recalWhyRpeLowHold => 'Your key workouts felt easy – the new targets are this week\'s step up, the volume stays (never both at once).';

  @override
  String wBrickRun(int min) {
    return 'Brick run $min min';
  }

  @override
  String get wBrickRunDesc => 'Straight off the bike: the first minutes feel heavy – that is normal. Change quickly (≤ 2 min) – transition practice included.';

  @override
  String get stepBrickStartNote => 'Find your running rhythm – short, quick steps';

  @override
  String get stepBrickNote => 'Steady race feel – controlled, not all out';

  @override
  String wRaceRunWalk(int min) {
    return 'Run/walk strategy: run $min min, walk 1 min – from the start, even if you feel fresh.';
  }

  @override
  String get wGymLegsHalvedNote => 'Leg exercises with half the sets today – tomorrow\'s key session needs fresh legs.';

  @override
  String get feasTitle => 'Very ambitious goal';

  @override
  String get feasBeginnerMarathon => 'A marathon is not a beginner goal: build up over 5 km, 10 km and a half marathon first.';

  @override
  String get feasRunWalkLong => 'As long as you can\'t run 30 min continuously, a marathon is too far – build up over 5 km, 10 km and a half marathon first.';

  @override
  String get feasRunWalk => 'On race day you will still be on run/walk – continuous running takes longer to build.';

  @override
  String feasTooShort(int weeks) {
    return '$weeks weeks are not enough to build the long sessions this distance needs.';
  }

  @override
  String feasLongRunTime(int km, int x) {
    return 'The time on your long-run day allows only about $km km – this race needs long runs of $x km. Plan more time on that day.';
  }

  @override
  String feasLongRideTime(int min, int target) {
    return 'The time on your long-ride day allows only $min min – this race needs long rides of at least $target min.';
  }

  @override
  String get feasOptions => 'Options';

  @override
  String feasLaterDate(String date) {
    return 'A race on $date or later';
  }

  @override
  String feasShorter(String dist) {
    return 'A shorter distance: $dist';
  }

  @override
  String get feasRunWalkFinish => 'Finish with run/walk – race day in your plan shows the rhythm';

  @override
  String get feasPlanAnyway => 'The plan is created anyway and builds up as far as is safely possible.';

  @override
  String get wGymDeloadNote2 => 'Deload week: weights are entered about 10 % lighter and each exercise keeps about half its work sets. Train cleanly with about 4 reps in the tank – fatigue drops and you come back stronger.';

  @override
  String get glossary => 'Glossary';

  @override
  String get glossaryHint => 'Short explanations of the terms and abbreviations used in the app.';

  @override
  String termWhatIs(String term) {
    return 'What does $term mean?';
  }

  @override
  String get termRpeTitle => 'RPE – Rating of Perceived Exertion';

  @override
  String get termRpeBody => 'How hard a workout or set felt, on a scale from 1 (very easy) to 10 (maximal). 3–4 = easy, you can chat; 6–7 = hard but controlled; 9–10 = all-out.';

  @override
  String get termRpeTip => 'Optional. When you enter it, the plan adapts better – e.g. easy runs that feel too hard lead to a lighter next week.';

  @override
  String get termRirTitle => 'RIR – Reps in Reserve';

  @override
  String get termRirBody => 'How many more reps you could have done at the end of a set. \"2 in the tank\" means you stop two reps before failure.';

  @override
  String get termRirTip => 'The rating chips map to it: Easy ≈ 4+, Just right ≈ 2–3, Hard ≈ 1, Limit = 0. Most sets should end with 1–3 in the tank.';

  @override
  String get termE1rmTitle => 'e1RM – estimated one-rep max';

  @override
  String get termE1rmBody => 'The weight you could probably lift exactly once, calculated from a set with more reps (e.g. 80 kg × 8 ≈ 101 kg). No need to test a real max.';

  @override
  String get termE1rmTip => 'Good for comparing progress across different weights and rep counts.';

  @override
  String get termVdotTitle => 'VDOT – running fitness score';

  @override
  String get termVdotBody => 'A score by coach Jack Daniels derived from your race times. All running paces in your plan (easy, tempo, interval) are calculated from it.';

  @override
  String get termVdotTip => '+1 VDOT is roughly 1–2 % faster over any distance. It rises with consistent training and is updated when you run faster.';

  @override
  String get termFtpTitle => 'FTP – Functional Threshold Power';

  @override
  String get termFtpBody => 'The power (watts) you can hold on the bike for about one hour. Bike zones such as endurance, sweet spot and threshold are percentages of it.';

  @override
  String get termFtpTip => 'Without a power meter the plan uses heart rate and feel instead.';

  @override
  String get termCssTitle => 'CSS – Critical Swim Speed';

  @override
  String get termCssBody => 'Your threshold pace in the pool per 100 m, calculated from a 400 m and a 200 m time trial. Swim intervals are set relative to it.';

  @override
  String get termCssTip => 'Example: 400 m in 8:00 and 200 m in 3:40 → CSS ≈ 2:10 /100 m.';

  @override
  String get termSupersetTitle => 'Superset';

  @override
  String get termSupersetBody => 'Two (or three) exercises done back to back with only a short switch, then the full rest. The app pairs opposing muscles (e.g. press + row), so each recovers while the other works.';

  @override
  String get termSupersetTip => 'Saves time without losing performance.';

  @override
  String get termAmrapTitle => 'AMRAP – as many reps as possible';

  @override
  String get termAmrapBody => 'On the last set do as many clean reps as you can – but stop one rep before failure. The app uses the result to correct your weights.';

  @override
  String get termAmrapTip => 'Only appears when it helps: for new exercises and when you reach the top of the rep range.';

  @override
  String get termVolumeTitle => 'Volume';

  @override
  String get termVolumeBody => 'Weight × reps of all working sets added up (warm-ups don\'t count). For bodyweight exercises the lifted share of your body weight counts.';

  @override
  String get termVolumeTip => 'More volume is not automatically better – what matters is progress over weeks.';

  @override
  String get termPhaseTitle => 'Plan phases';

  @override
  String get termPhaseBody => 'Base: build endurance and technique, mostly easy. Build: more intensity. Peak: race-specific sessions. Taper: less volume before the race so you start fresh. Recovery week: a lighter week every 3–5 weeks so your body can adapt.';

  @override
  String get termPhaseTip => 'Recovery and taper weeks feel easy on purpose – don\'t make up for them.';

  @override
  String get termZonesTitle => 'Intensity zones';

  @override
  String get termZonesBody => 'Training ranges from very easy to maximal, based on pace, heart rate or power. About 80 % of endurance training should be easy – that\'s what builds your base.';

  @override
  String get termZonesTip => 'Tap a zone in a workout for its exact range.';

  @override
  String get raceSearch => 'Find races';

  @override
  String get raceSport => 'Sport';

  @override
  String get raceAnyDistance => 'Any distance';

  @override
  String get raceRegion => 'Region (country or city)';

  @override
  String get raceRegionHint => 'e.g. Germany, Munich, 80331 – empty = anywhere';

  @override
  String get raceWindow => 'Time window';

  @override
  String raceNextMonths(int n) {
    return '$n months';
  }

  @override
  String get raceSearchButton => 'Search';

  @override
  String get raceIntro => 'Searches public race calendars (German running and triathlon calendars, RunSignup for the USA) – or open a race calendar directly.';

  @override
  String get raceSearching => 'Searching race calendars…';

  @override
  String get raceWebResults => 'Web results (AI search)';

  @override
  String get raceDisclaimer => 'From public race calendars – no guarantee. Check date and details with the organiser before you sign up.';

  @override
  String get raceOrganiserPage => 'Details';

  @override
  String get raceSetAsGoal => 'Set as goal';

  @override
  String get raceGoalSet => 'Race set as your goal';

  @override
  String get raceEmpty => 'No races found for these filters. Try a longer time window or a wider region – or browse a race calendar.';

  @override
  String get raceUnavailable => 'The AI web search is not available right now (quota or plan of the AI service). Browse a race calendar instead.';

  @override
  String get raceError => 'The search failed. Check your connection and try again – or browse a race calendar.';

  @override
  String get raceBadResponse => 'The search returned no usable result. Try again – or browse a race calendar.';

  @override
  String get raceRetry => 'Try again';

  @override
  String get racePortals => 'Race calendars';

  @override
  String get racePortalsHint => 'Opens in the browser, filtered where the site supports it.';

  @override
  String get raceSources => 'Sources';

  @override
  String get raceGoogleSuggestions => 'Google searches';

  @override
  String get recalGapsTitle => 'Gaps in the plan';

  @override
  String recalWhyGaps(int n) {
    return 'Sessions the plan expects are missing ($n) – refills are proposed below.';
  }

  @override
  String get recalWhyGapsOmitted => 'Some missing sessions are not refilled: they would sit next to a race or the week already has its planned volume.';

  @override
  String get recalAdded => 'Added';

  @override
  String recalGapMissing(String day) {
    return 'The planned session on $day is missing – added back.';
  }

  @override
  String get recalGapEmptyWeek => 'This week has no sessions – the planned one is added back.';

  @override
  String get recalGapEnded => 'The plan ended earlier – continued here.';

  @override
  String get recalGapDowngraded => 'Easy instead of hard: the day next to it is already hard.';

  @override
  String get recalGapEased => 'Easy, because the plan is lighter right now.';

  @override
  String get recalGapShortened => 'Shorter, so the week and the long run stay within safe limits.';

  @override
  String get feasTitleTarget => 'Target time check';

  @override
  String feasTargetAmbitious(String goal, String now, String pred) {
    return 'Ambitious: $goal needs more than the usual progress in the time left (today ~$now, expected by race day ~$pred). Possible with very consistent training.';
  }

  @override
  String feasTargetUnrealistic(String goal, String now, String pred) {
    return '$goal is unlikely by race day: today you are at ~$now, realistic by race day is ~$pred.';
  }

  @override
  String feasTargetOkLine(String goal, String now, String pred) {
    return 'Target $goal is realistic: today ~$now, expected on race day ~$pred.';
  }

  @override
  String feasTargetLater(String goal, String date) {
    return '$goal becomes realistic with a race on or after $date';
  }

  @override
  String feasTargetSuggest(String goal) {
    return 'a target of $goal';
  }

  @override
  String get feasEstimated => 'Rough estimate – enter a race time in the plan settings for a precise check.';

  @override
  String adjustTargetTo(String goal) {
    return 'Set target to $goal';
  }

  @override
  String targetAdjusted(String goal) {
    return 'Target time set to $goal';
  }

  @override
  String planToEventPre(int weeks, int n, int x) {
    return '$weeks weeks to race day: $n weeks of base building first, then the $x-week race plan.';
  }

  @override
  String get planKeepsDone => 'Completed workouts are kept – only upcoming planned workouts are replaced.';

  @override
  String get planEventTooFar => 'Your event is more than 52 weeks away – the plan uses the length below for now.';

  @override
  String planUntilRace(int weeks) {
    return 'The plan runs until race day ($weeks weeks).';
  }

  @override
  String get alignPlanToEvent => 'Align training plan to this race';

  @override
  String get alignPlanToEventSub => 'The plan runs until race day; completed workouts are kept.';

  @override
  String get alignNeedsDistance => 'Choose a race distance to align the plan.';

  @override
  String planAligned(int weeks) {
    return 'Plan aligned: $weeks weeks to race day';
  }

  @override
  String get goalStatusTitle => 'Where I stand';

  @override
  String goalCountdown(int weeks, int days) {
    return '$weeks wk $days d';
  }

  @override
  String goalCountdownDays(int days) {
    return '$days days';
  }

  @override
  String get goalToRace => 'to race day';

  @override
  String get goalForecast => 'Forecast';

  @override
  String get goalTargetLabel => 'Target';

  @override
  String get goalToday => 'Today';

  @override
  String get goalFinish => 'Finish';

  @override
  String get fcAhead => 'Ahead of plan';

  @override
  String get fcOnTrack => 'On track';

  @override
  String get fcSlightlyBehind => 'Slightly behind';

  @override
  String get fcAtRisk => 'Goal at risk';

  @override
  String get fcEarly => 'Too early to tell';

  @override
  String get fcEarlySub => 'After your first workouts the forecast uses your training data.';

  @override
  String get fcRiskTitle => 'Your goal is at risk';

  @override
  String fcRiskBody(String pred, String goal) {
    return 'Recent training did not go as planned. Forecast for race day: ~$pred instead of $goal.';
  }

  @override
  String get fcRiskBodyFinish => 'Recent training did not go as planned – at this rate the finish is at risk. Consistent training from now on (or one of the options) can still turn it around.';

  @override
  String fcAheadBody(String goal) {
    return 'You are faster than planned – $goal looks realistic.';
  }

  @override
  String fcReasonMissed(int pct) {
    return '$pct % of the planned training done';
  }

  @override
  String get fcReasonSlower => 'Key runs slower than planned';

  @override
  String get fcReasonFaster => 'Key runs faster than planned';

  @override
  String get fcReasonLongRun => 'Long runs shorter than planned';

  @override
  String get fcReasonBreak => 'Training break – fitness drops after ~10 days without running';

  @override
  String fcRange(String fast, String slow) {
    return 'Range $fast – $slow';
  }

  @override
  String get fcConfLow => 'rough estimate';

  @override
  String get fcConfMedium => 'from your sessions';

  @override
  String get fcConfHigh => 'from a race result';

  @override
  String get fcInRecal => 'Goal forecast';

  @override
  String get goalPhaseBaseShort => 'Base';

  @override
  String get goalPhaseBuildShort => 'Build';

  @override
  String get goalPhasePeakShort => 'Peak';

  @override
  String get goalPhaseTaperShort => 'Taper';

  @override
  String get goalCompletion => 'Plan completion';

  @override
  String get goalLongestRun => 'Longest run (6 weeks)';

  @override
  String goalLongRunNeed(int km) {
    return 'needed before the taper: $km km';
  }

  @override
  String get goalFitnessTrend => 'Fitness trend (VDOT)';

  @override
  String get goalTrendPlanned => 'Plan';

  @override
  String get goalTrendActual => 'Your sessions';

  @override
  String get goalTrendEmpty => 'The trend appears after a few tempo or interval runs.';

  @override
  String get goalPhaseOutlook => 'Phases & expected fitness';

  @override
  String get goalPhaseNow => 'now';

  @override
  String goalWeeksN(int weeks) {
    return '$weeks wk';
  }

  @override
  String get goalEditPlan => 'Plan settings';

  @override
  String get replacePlanTitle => 'Start plan over?';

  @override
  String replacePlanBody(String date, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n planned workouts from $date will be replaced.',
      one: '1 planned workout from $date will be replaced.',
    );
    return '$_temp0';
  }

  @override
  String get replacePlanKeeps => 'Completed workouts and stats stay.';

  @override
  String get replaceFromToday => 'From today';

  @override
  String get replaceFromMonday => 'From next Monday';

  @override
  String get replacePlanOk => 'Replace';

  @override
  String get startOverTitle => 'Start plan over';

  @override
  String get startOverButton => 'Start over';

  @override
  String get wRecoveryWeekNote2 => 'Recovery week: volume is reduced on purpose – keep it easy even if you feel fresh. This is when your body absorbs the last weeks.';

  @override
  String get wGymDeloadNote3 => 'Recovery week: weights are entered about 10 % lighter and each exercise keeps about half its work sets. Train cleanly with about 4 reps in the tank – fatigue drops and you come back stronger.';

  @override
  String get eventQuestion => 'Training for a race?';

  @override
  String get noPlanYet => 'No plan yet';

  @override
  String get noPlanYetSub => 'Strive builds one from your goal, training days and time.';

  @override
  String todayNext(String title, String day) {
    return 'Next: $title · $day';
  }

  @override
  String todayHiddenByFilter(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n workouts hidden by filter',
      one: '1 workout hidden by filter',
    );
    return '$_temp0';
  }

  @override
  String get todayHiddenByFilterSub => 'The sport filter is on – today is not a rest day.';

  @override
  String get showAllSports => 'Show all';

  @override
  String hintPlannedDry(String sport, String time) {
    return 'Planned today: $sport – dry until $time';
  }

  @override
  String hintPlannedBest(String sport, String time) {
    return 'Planned today: $sport – best at $time';
  }

  @override
  String hintPlannedStorm(String sport) {
    return 'Thunderstorm – move your $sport indoors or later';
  }

  @override
  String hintPlannedNeutral(String sport) {
    return 'Planned today: $sport – dress for the weather';
  }

  @override
  String get summaryEffortTitle => 'How hard was it? Your plan adapts to it.';

  @override
  String get summaryEffortHint => 'Optional · 1 = very easy, 10 = all-out';

  @override
  String get summaryEffortPrefilled => 'Preselected from your exercise ratings – tap to change.';

  @override
  String autoAdjBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n workouts adapted automatically – review',
      one: '1 workout adapted automatically – review',
    );
    return '$_temp0';
  }

  @override
  String get autoAdjSheetIntro => 'After your last workouts the plan adapted these sessions. Keep them or undo single changes.';

  @override
  String get planHistory => 'Plan history';

  @override
  String get planHistoryEmpty => 'No plan changes yet. Automatic adjustments, “Review plan”, “Adjust week” and “Not feeling 100%?” show up here.';

  @override
  String get planLogRecal => 'Plan reviewed';

  @override
  String planLogReadiness(String why) {
    return 'Not feeling 100%: $why';
  }

  @override
  String get planLogWeekReason => 'Missed workouts moved within the week or dropped.';

  @override
  String get planLogUndone => 'Undone';

  @override
  String get planLogChanged => 'Changed since – no undo';

  @override
  String get planLogNew => 'new';

  @override
  String get planLogDropped => 'Dropped';

  @override
  String get planLogUndoDone => 'Change undone';

  @override
  String get notFitButton => 'Not feeling 100%?';

  @override
  String get notFitIntro => 'Tell the plan how you feel – it suggests a safe change. Nothing changes until you apply it.';

  @override
  String get notFitSick => 'Sick';

  @override
  String get notFitPain => 'Pain';

  @override
  String get notFitTired => 'Tired';

  @override
  String get notFitTime => 'Short on time';

  @override
  String get notFitMinutes => 'Time available';

  @override
  String get notFitNoChange => 'No change needed – the workout fits as planned.';

  @override
  String get notFitPreview => 'Suggested change';

  @override
  String get notFitApplied => 'Plan adjusted';

  @override
  String get notFitHintAboveNeck => 'Above-the-neck rule: only a runny nose or a mild sore throat and no fever – rest or at most a short, easy session. Fever, aching muscles, chest or stomach symptoms: no training until you are well.';

  @override
  String get notFitHintReturn => 'Back after being sick: hard sessions of the next two days become easy. After 10 days or more off, use “Review plan” – it rebuilds at 50–70 % of your previous volume.';

  @override
  String get notFitHintPainRule => 'Pain up to 3/10 that has settled by the next morning is acceptable. Stop if it gets worse during the session.';

  @override
  String get notFitHintDoctor => 'If the pain lasts more than a few days or keeps coming back, have it checked by a doctor or physiotherapist.';

  @override
  String get notFitHintSwapped => 'Swapped for low-impact cross-training: it keeps your endurance without the impact of running.';

  @override
  String get notFitHintKeyEasy => 'Tired: the key workout becomes an easy session (about 20 % shorter). Quality on tired legs adds fatigue, not fitness.';

  @override
  String get notFitHintShorter => 'Tired: the easy session is about 25 % shorter – keep it truly easy.';

  @override
  String get notFitHintGymLighter => 'About a third fewer sets with the same weights; end each set with 2–3 reps in reserve. Leave out exercises that hurt.';

  @override
  String get notFitHintGymShorter => 'Fewer sets to fit your time – main lifts first. A few hard sets keep most of the effect.';

  @override
  String get notFitHintTime => 'Shortened to your time: warm-up and cool-down stay, the main part gets shorter.';

  @override
  String get askCoachAbout => 'Ask the coach';

  @override
  String coachExplainWorkout(String title, String date) {
    return 'Explain the workout “$title” on $date to me';
  }

  @override
  String get reserveLabel => 'Reserve';

  @override
  String reserveN(String value) {
    return 'Reserve $value';
  }

  @override
  String get reserveHint => 'reps in the tank';

  @override
  String get logRirSetting => 'Reserve per set';

  @override
  String get logRirSettingSub => 'Reps left in the tank after each set (RIR). The rating per exercise stays.';

  @override
  String wRaceGoalStart(String goal, String pace) {
    return 'Goal $goal – start at $pace';
  }

  @override
  String get wProgressionRun => 'Progression run';

  @override
  String get wProgressionRunDesc => 'Start easy, run the last part at a steady marathon-pace effort – aerobic strength without a hard interval day.';

  @override
  String get stepProgressionNote => 'Steady – marathon-pace effort, still controlled';

  @override
  String get wLongRunProgression => 'Progression long run';

  @override
  String get wLongRunProgressionDesc => 'Easy long run, the last part at a steady marathon-pace effort – fatigue resistance without a race-pace session.';

  @override
  String get wLongRunShortDesc => 'Shorter long run this week: a lighter week between the longest runs – the body absorbs the load before the next step.';

  @override
  String wGoalPaceSet(int reps, String dist) {
    return 'Goal pace $reps × $dist km';
  }

  @override
  String get wGoalPaceSetDesc => 'Repeats at your goal race pace with short jog breaks – the race-specific session: rhythm, pace judgement, confidence.';

  @override
  String get stepGoalPaceNote => 'Goal race pace – even and controlled';

  @override
  String wCruiseKm(int reps, String dist) {
    return 'Cruise intervals $reps × $dist km';
  }

  @override
  String wRideTempo(int reps, int min) {
    return 'Tempo $reps × $min min';
  }

  @override
  String get wRideTempoDesc => 'Race-specific tempo at 75–85 % FTP – the effort of a 70.3 bike leg: steady, aero, fuelled.';

  @override
  String get stepRideTempoNote => 'Tempo – 75–85 % FTP, steady';

  @override
  String get sprintTri => 'Sprint triathlon';

  @override
  String get distUltra50 => 'Ultra 50 km';

  @override
  String get distIronman => 'Ironman (full distance)';

  @override
  String get distDuSprint => 'Duathlon sprint (5/20/2.5)';

  @override
  String get distDuStandard => 'Duathlon standard (10/40/5)';

  @override
  String get distRide100 => 'Cycling 100 km';

  @override
  String get distRide160 => 'Cycling 160 km';

  @override
  String get distSwim1500 => 'Open water 1.5 km';

  @override
  String get distSwim3800 => 'Open water 3.8 km';

  @override
  String get distSwim5000 => 'Open water 5 km';

  @override
  String get moreDistances => 'More distances…';

  @override
  String get backAgainToExit => 'Press back again to exit';

  @override
  String get musicRpm => 'rpm';

  @override
  String get musicIntroRun => 'Music matched to your step rate (≈ 150–185 steps/min) makes running feel easier and more economical.';

  @override
  String get musicRunEasy => 'Easy run';

  @override
  String get musicRunSteady => 'Long / steady run';

  @override
  String get musicRunTempo => 'Tempo run';

  @override
  String get musicRunIntervals => 'Intervals & strides';

  @override
  String get musicPodcastsRun => 'Great for long easy runs';

  @override
  String get musicIntroRide => 'Music matched to your cadence (80–100 rpm): one beat per pedal stroke, or double time.';

  @override
  String get musicRideSafety => 'Outdoors: keep the volume low or use one earbud only – you must still hear the traffic.';

  @override
  String get musicRideEasy => 'Easy ride';

  @override
  String get musicRideSteady => 'Endurance & sweet spot';

  @override
  String get musicRideThreshold => 'Threshold';

  @override
  String get musicRideIntervals => 'Intervals & sprints';

  @override
  String get musicPodcastsRide => 'Great for long easy rides';

  @override
  String get musicPodcastsTrainer => 'Great for long trainer sessions';

  @override
  String get musicIntroSwim => 'Under water you only hear music with special headphones – start it before you get in.';

  @override
  String get musicSwimPoolHint => 'Bluetooth does not work under water: you need waterproof bone-conduction headphones with built-in storage (MP3). Download the playlist beforehand.';

  @override
  String get musicSwimOpenHint => 'Open water: only with bone-conduction headphones and quiet enough to hear boats, your group and the safety crew.';

  @override
  String get musicPreSwim => 'Pre-swim warm-up & focus';

  @override
  String get musicSwimList => 'Swim playlist (to download)';

  @override
  String get musicSwimListSub => 'Steady rhythm for your MP3 headphones';

  @override
  String get musicPodcastsSwim => 'For long, calm sets (bone conduction)';

  @override
  String get musicIntroGym => 'Loud, motivating music at 120–140 BPM helps with strength work; circuits higher, warm-up and stretching lower.';

  @override
  String get musicGymHint => 'Tip: continuous mixes keep the energy up between sets – the rest timer still vibrates when the break is over.';

  @override
  String get musicGymWarmup => 'Warm-up & mobility';

  @override
  String get musicGymStrength => 'Strength training';

  @override
  String get musicGymHeavy => 'Heavy sets';

  @override
  String get musicGymCircuit => 'Supersets, circuits & HIIT';

  @override
  String get musicGymCooldown => 'Cool-down & stretching';

  @override
  String get tabData => 'Data';

  @override
  String get tabMap => 'Map';

  @override
  String get tabSplits => 'Splits';

  @override
  String get tabWorkout => 'Workout';

  @override
  String get autoPausedHint => 'Resumes as soon as you move';

  @override
  String get pausedHint => 'Hold ■ to finish';

  @override
  String lapDone(int n, String time, String dist) {
    return 'Lap $n: $time · $dist';
  }

  @override
  String get currentLap => 'Current lap';

  @override
  String get lapCount => 'Laps';

  @override
  String get currentSplit => 'Current km';

  @override
  String get bestSplit => 'Fastest km';

  @override
  String get avgSplit => 'Average km';

  @override
  String get repeatCue => 'Repeat announcement';

  @override
  String get cadenceTarget => 'Cadence target';

  @override
  String vcStatus(String time, String dist) {
    return 'Time $time. Distance $dist.';
  }

  @override
  String get targetBand => 'Target';

  @override
  String get routeTapHint => 'Map';

  @override
  String get stepLeft => 'Step left';

  @override
  String get raceRadius => 'Radius';

  @override
  String raceResultsCount(int n) {
    return 'Races found: $n';
  }

  @override
  String raceSourceOf(String name) {
    return 'Source: $name';
  }

  @override
  String raceDataFrom(String names) {
    return 'Data: $names';
  }

  @override
  String raceSourcesFailed(String names) {
    return 'Not reachable right now: $names';
  }

  @override
  String get raceNoSource => 'There is no direct search for this sport and region yet (connected: German running and triathlon calendars, RunSignup for the USA). Browse a race calendar below.';

  @override
  String get wShakeoutRide => 'Shake-out ride';

  @override
  String get wShakeoutRideDesc => '20–30 min very easy with three short pick-ups – loosen up, check the bike. Prepare food and drinks for tomorrow.';

  @override
  String get wShakeoutSwim => 'Shake-out swim';

  @override
  String get wShakeoutSwimDesc => 'Short and easy with a few faster 50s and sighting – ideally at the race venue in your wetsuit.';

  @override
  String get stepSightingNote => 'Sighting: lift the eyes briefly every 6–9 strokes, keep the rhythm';

  @override
  String wDuLegs(String run, String bike, String run2) {
    return 'Run $run km · Bike $bike km · Run $run2 km';
  }

  @override
  String get wRaceFuelNote => 'Fuel as practised: 60–90 g carbohydrate per hour from early on, drink to thirst – nothing new on race day.';

  @override
  String get wFuelPracticeNote => 'Practise race fuelling: 60–90 g carbohydrate per hour and 400–800 ml fluid per hour – train the gut like the legs.';

  @override
  String get wTrailNote => 'If your race has climbing: run on hilly terrain and practise power hiking on the steep parts.';

  @override
  String get stepClimbNote => 'Seated, low cadence 60–70 rpm – on a climb or high resistance';

  @override
  String wClimb(int reps, int each) {
    return 'Climbing $reps × $each min';
  }

  @override
  String get wClimbDesc => 'Sweet-spot effort as climbing repeats: builds the strength and fatigue resistance long climbs need.';

  @override
  String wDuRunFirst(int min) {
    return 'Run before the bike $min min';
  }

  @override
  String get wDuRunFirstDesc => 'Duathlon order: run at steady race feel, change quickly to the bike – the brick run follows the ride.';

  @override
  String get wBackToBack => 'Back-to-back run';

  @override
  String get wBackToBackDesc => 'Easy medium-long run on tired legs the day after the long run – ultra endurance without one huge run. Walk breaks are fine.';

  @override
  String get stepSwimTestNote => 'Time trial: fastest pace you can hold evenly – note the time';

  @override
  String get wSwimCssTest => 'CSS test (400 m + 200 m)';

  @override
  String get wSwimCssTestDesc => 'You can swim 400 m in one go now: swim 400 m and, after 5–10 min easy, 200 m as time trials. Enter both times in the plan settings (swimming) – Strive then sets your swim paces and plans CSS sets.';

  @override
  String get stepSwimNoviceWu => 'Easy, with breaks as needed';

  @override
  String get stepSwimKickNote => 'Kick with a board, relaxed from the hips – breathe out under water';

  @override
  String get stepSwimNoviceNote => 'Relaxed and without stopping – long strokes, calm breathing';

  @override
  String wSwimBuild(int reps, int meters) {
    return 'Build-up $reps × $meters m';
  }

  @override
  String get wSwimBuildDesc => 'Building continuous swimming: swim every repeat relaxed without stopping, rest at the wall as long as you need (~30–45 s). The repeats get longer week by week – goal: 400 m in one go.';

  @override
  String get wSwimNoviceTechDesc => 'Technique for swim starters: breathing out under water, flat body position, relaxed kick – short distances with breaks. No pace targets.';

  @override
  String wLongSwim(int meters) {
    return 'Long swim $meters m';
  }

  @override
  String get wLongSwimDesc => 'The long continuous swim of the week – even rhythm, bilateral breathing, no stopping. It grows towards your race distance.';

  @override
  String get wOpenWaterNote => 'Open water when possible: wetsuit, sighting, swimming in a group (drafting) and never alone.';

  @override
  String get stepSwimTempoNote => 'Tempo – a little slower than CSS, short rests';

  @override
  String wSwimTempoSet(int n, int meters) {
    return 'Tempo set $n × $meters m';
  }

  @override
  String get wSwimTempoDesc => 'Long repeats just below threshold: sustained race pace for longer distances.';

  @override
  String get feasBeginnerDistance => 'This distance is not a first goal for beginners: build up over a season with shorter races first.';

  @override
  String feasLongSwim(int meters, int target) {
    return 'By race day your continuous swim only reaches about $meters m – this race needs about $target m in one go.';
  }

  @override
  String feasRaiseDay(String day, String time) {
    return 'Increase the time on $day to $time';
  }

  @override
  String feasMoveLongDay(String day, String time) {
    return 'Move the long session to $day ($time available)';
  }

  @override
  String timeLongDayHint2(String time) {
    return 'On your long-session day (★) Strive plans $time for this goal unless you set that day yourself.';
  }

  @override
  String get abilityTitle => 'Your current level';

  @override
  String get canSwim400Sub => 'If not, the plan starts with technique and builds up to 400 m in one go – then a swim test sets your paces.';

  @override
  String get goalKindRace => 'Race';

  @override
  String get goalKindWeeks => 'Plan length only';

  @override
  String get goalKindWeeksHint => 'No race – a plan that builds your fitness over the chosen number of weeks, with recovery weeks and without taper.';

  @override
  String get tabZones => 'Zones';

  @override
  String get tabPlan => 'Plan';

  @override
  String get planProjected => 'Expected finish after';

  @override
  String get planPlanned => 'Planned';

  @override
  String get planDelta => 'vs. plan';

  @override
  String get planOnTarget => 'Intervals on target';

  @override
  String get planNow => 'now';

  @override
  String get planShort => 'Shortened';

  @override
  String get planNoneDone => 'Finished sections appear here with their actual values.';

  @override
  String planStepsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'then $n more sections',
      one: 'then 1 more section',
    );
    return '$_temp0';
  }

  @override
  String get zoneWaiting => 'Waiting for pace…';

  @override
  String get zoneTimeIn => 'Time in zone';

  @override
  String get zoneCurrent => 'Current zone';

  @override
  String get wLongRunWalkDesc => 'Long run/walk: the same rhythm as your other runs, more repeats – time on your feet for the race. Talking pace, walk briskly. Grows about 10 min a week.';

  @override
  String get wWalkBreaksNote => 'Walk 1 min after every 10 min of running (Galloway) – the breaks keep the long run easy on legs and joints. Drop them once it feels easy.';

  @override
  String wSwimContinuous(int meters) {
    return 'Continuous swim $meters m';
  }

  @override
  String get wSwimContinuousDesc => 'Swim the main set in one go at an easy, steady pace – it grows about 100 m a week towards the distance your race needs without stopping.';

  @override
  String get progTitle => 'Your build-up is falling behind';

  @override
  String progLongShort(int pct) {
    return 'Your long sessions of the last 3 weeks reached only $pct % of the plan.';
  }

  @override
  String get progLongMissed => 'Several long sessions – the key sessions of your build-up – were missed.';

  @override
  String get progRunWalkNotAchieved => 'The run/walk steps were shortened or felt hard (RPE ≥ 7) – move on only when a step feels easy.';

  @override
  String get progHighEffort => 'Your long sessions felt very hard (RPE ≥ 8) – they should feel easy.';

  @override
  String get progOptRepeatWeek => 'Repeat this week before the next step';

  @override
  String get progOptLaterRace => 'Choose a later race';

  @override
  String get progOptShorter => 'Switch to a shorter distance';

  @override
  String get progOptRunWalkRace => 'Plan the race with run/walk';

  @override
  String get targetSuggestBasisRace => 'from your race times';

  @override
  String get targetSuggestBasisEfforts => 'from your recent runs';

  @override
  String get targetSuggestBasisLevel => 'Rough estimate from your level – a race time makes it precise';

  @override
  String get targetSuggestFinish => 'Goal: finish – no target time for this race yet';

  @override
  String targetSuggestRange(String time, String fast, String slow) {
    return 'Realistic: $time ($fast–$slow)';
  }

  @override
  String get restoreWorkoutTitle => 'Continue workout?';

  @override
  String restoreWorkoutBody(String title, String day, String time) {
    return '$title – started $day at $time. The app was closed while it was running; continue where you left off or discard it.';
  }

  @override
  String get restoreWorkoutResume => 'Continue';

  @override
  String get restoreSummaryTitle => 'Save your workout?';

  @override
  String restoreSummaryBody(String title, String day, String time) {
    return '$title ($day, $time) was finished but not saved yet.';
  }

  @override
  String get restoreSummaryOpen => 'Open summary';

  @override
  String get restoreToday => 'today';

  @override
  String get restoreYesterday => 'yesterday';

  @override
  String get workoutRunsInBackground => 'Your workout keeps running in the background.';

  @override
  String deletedAutoReverted(int count) {
    return 'Deleted – $count automatic plan adjustments undone';
  }

  @override
  String get writeFailed => 'A change could not be saved. Please check your connection and try again.';

  @override
  String get loadFailedTitle => 'Your data could not be loaded';

  @override
  String get loadFailedBody => 'Please check your internet connection and try again. If it keeps happening, log out and sign in again.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSub => 'Permanently deletes your account and all your data';

  @override
  String get deleteAccountConfirm1 => 'All your workouts, plans, programs, goals and body data will be deleted permanently – on all devices. This cannot be undone.';

  @override
  String get deleteAccountConfirm2Title => 'Really delete?';

  @override
  String get deleteAccountConfirm2 => 'Type DELETE to confirm.';

  @override
  String get deleteAccountWord => 'DELETE';

  @override
  String get deleteAccountRunning => 'Deleting your data…';

  @override
  String get deleteAccountDone => 'Your account and all data have been deleted.';

  @override
  String get deleteAccountFailed => 'Deleting failed – please try again when you are online.';

  @override
  String get reauthTitle => 'Confirm it’s you';

  @override
  String get reauthBody => 'For your security, please sign in again before deleting your account.';

  @override
  String get reauthGoogle => 'Continue with Google';

  @override
  String get reauthConfirm => 'Confirm';

  @override
  String feasLongDayDefault(String day, String time) {
    return 'The long session on $day needs up to $time – far more than your other sessions. The plan schedules it like that; set that day’s time yourself if it does not fit.';
  }

  @override
  String feasLongRunShare(int min) {
    return 'Your other runs are too short for the long run this race needs: it may be at most half of the week and twice your next-longest run. Plan about $min min for your other runs.';
  }

  @override
  String feasTargetConservative(String goal, String now, String pred) {
    return '$goal is a cautious target: today ~$now, realistic on race day ~$pred. Your race-pace sessions use the realistic pace.';
  }

  @override
  String wRunContinuous(int min) {
    return 'Continuous run $min min';
  }

  @override
  String get wShakeoutRunWalkDesc => 'Easy shake-out in your run/walk rhythm – just loosen up, nothing more. Lay out your race kit tonight.';

  @override
  String get wShakeoutEasyDesc => '15 min very easy – just loosen up, nothing more. Lay out your race kit tonight.';

  @override
  String get wMastersStrengthNote => 'Strength tip: add 15–20 min of strength after this session (squats, lunges, calf raises, a plank) – twice a week it keeps muscle, bones and tendons strong as you get older.';

  @override
  String wRaceLeg(String leg, String dist) {
    return '$leg $dist km – your race pace for this leg';
  }

  @override
  String get wRaceFinishDesc => 'Finish goal: no target time yet – start slower than feels right, keep your rhythm and enjoy reaching the finish.';

  @override
  String get wTriOpenWaterNote => 'Race preparation: practise sighting in the pool (look forward every 6–9 strokes); once the water allows, swim some sessions in open water in your wetsuit – in a group, never alone.';

  @override
  String get stepSwimRaceFinishNote => 'Last third at race pace – steady, keep your technique';

  @override
  String get wLongSwimRaceDesc => 'This week the last third of the long swim is at race pace: practise holding the pace when you are already tired.';

  @override
  String wLongRideRacePace(int reps, int each) {
    return 'Long ride with $reps × $each min at race power';
  }

  @override
  String get wLongRideRacePaceDesc => 'Long Z2 ride with blocks at the power you want to hold on race day: steady, aero, and eat and drink as in the race (every 20–30 min).';

  @override
  String get stepRacePowerNote => 'Race power – steady, as on race day';

  @override
  String get wRideTempoDescIm => 'Race-specific tempo at 75–85 % FTP – the effort of an Ironman bike leg: steady, aero, with fuelling.';

  @override
  String get wRideTempoDescFondo => 'Race-specific tempo at 75–85 % FTP – the steady effort of long climbs and a fast group ride: even pacing, with fuelling.';

  @override
  String get wRideTempoBaseDesc => 'Tempo at 76–90 % FTP: aerobic strength for long efforts – controlled, a step below sweet spot.';

  @override
  String get stepThresholdNote2 => 'Threshold – 91–100 % FTP, controlled';

  @override
  String wHillReps(int reps, int sec) {
    return 'Hill repeats $reps × $sec s';
  }

  @override
  String get wHillRepsDesc => 'Uphill repeats on a steady climb (5–8 %): strong, short steps, upright posture; jog or walk down easily. Builds the climbing strength your ultra needs.';

  @override
  String get stepHillNote => 'Uphill – hard but controlled, by feel (no pace)';

  @override
  String get stepHillDownNote => 'Jog or walk down easily';

  @override
  String wGymLoadDescNoDeload(int rir) {
    return 'Finish every work set with about $rir reps in reserve. Sets, rep range and suggested weight are shown with each exercise.';
  }

  @override
  String get wGymRegressionNote => 'First weeks: easier variants of the technically demanding lifts (lat pulldown instead of pull-ups, dumbbell Romanian deadlift instead of the barbell deadlift, reverse crunches instead of hanging leg raises) – the full lifts follow once the technique is solid.';

  @override
  String get recalWhyFatigueRecovery => 'Sessions have felt harder than intended for two weeks: the next 7 days are a recovery week (less volume, no intensity). Quality comes back after it with fewer repeats.';

  @override
  String get recalWhyFatigueCheck => 'Still harder than intended after the recovery week: check sleep, illness and stress – and consider a slower target time. Quality stays, with fewer repeats.';

  @override
  String get recalWhyGoalAtRisk => 'With the training of the last weeks the race goal is hard to reach (long runs or weekly volume far from what the race needs) – consider a later race or a shorter distance.';

  @override
  String get recalWhyRepeatStage => 'The run/walk sessions felt hard (RPE above 5) or were cut short: the coming week repeats your current stage instead of moving up.';

  @override
  String get recalWhyMoveLong => 'Long runs were missed while the other runs were done: the next long run moves to a training day with more time – the easy runs stay as they are.';

  @override
  String get fcReasonFatigue => 'Sessions felt harder than intended recently';

  @override
  String get summaryPlanDone => 'Plan done – great work!';

  @override
  String get summaryPartial => 'Short and sweet – every session counts.';

  @override
  String get summaryFree => 'Nice work – session done.';

  @override
  String get summaryTooShortTitle => 'Too short to save?';

  @override
  String get summaryTooShortBody => 'Less than a minute or no distance recorded.';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String finishOpenSets(int n, int total) {
    return '$n of $total sets still open.';
  }

  @override
  String get keepTraining => 'Keep training';

  @override
  String get planBehind => 'behind plan';

  @override
  String get planAhead => 'ahead of plan';

  @override
  String get planOnPlan => 'on plan';

  @override
  String get todayPlannedTitle => 'Planned today';

  @override
  String todayPlannedBody(String title) {
    return '$title – start it guided?';
  }

  @override
  String get startGuided => 'Start guided';

  @override
  String get startFree => 'Free session';

  @override
  String rxToday(int sets, int reps, String load) {
    return 'Today: $sets × $reps @ $load';
  }

  @override
  String rxTodayList(String list, String load) {
    return 'Today: $list reps @ $load';
  }

  @override
  String get amrapLastSet => 'Last set: as many reps as possible – stop 1 rep before failure.';

  @override
  String programPreviewSets(int sets) {
    return '$sets sets';
  }

  @override
  String get raceToday => 'race day';

  @override
  String phaseWeekOf(String phase, int n, int total) {
    return '$phase (week $n/$total)';
  }

  @override
  String get raceType => 'Race type';

  @override
  String alignChangesFocus(String focus) {
    return 'Your training focus becomes $focus so the plan fits this race.';
  }

  @override
  String get goalNeedsExercise => 'Choose an exercise.';

  @override
  String get goalNeedsDate => 'Choose the race date.';

  @override
  String get goalNeedsDistance => 'Choose a distance or enter the km.';

  @override
  String get goalNeedsTarget => 'Enter a target above 0.';

  @override
  String get deleteGoalTitle => 'Delete goal?';

  @override
  String goalDeleted(String title) {
    return '“$title” deleted';
  }

  @override
  String eventSubFor(String examples) {
    return 'Add a race (e.g. $examples) and get a countdown. Optional.';
  }

  @override
  String get recreatePlan => 'Recreate plan';

  @override
  String get summaryTitle => 'Check & create';

  @override
  String get summarySub => 'Your plan is rebuilt with these settings.';

  @override
  String get summaryChanges => 'What changes:';

  @override
  String get summaryNoChanges => 'Nothing – the plan is recreated with the same settings.';

  @override
  String get summaryWeek => 'Training week';

  @override
  String get summaryRace => 'Race';

  @override
  String get noRace => 'no race';

  @override
  String planWeeksN(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get hiddenShort => 'filtered';

  @override
  String get secureGuestTitle => 'Secure your data';

  @override
  String get secureGuestBody => 'You train as a guest – link an e-mail or Google so your workouts and plan aren’t lost.';

  @override
  String get secureGuestButton => 'Link e-mail or Google';

  @override
  String get guestLogoutTitle => 'Sign out as a guest?';

  @override
  String get guestLogoutBody => 'Signing out as a guest deletes all data on this device.';

  @override
  String get guestLogoutAnyway => 'Sign out anyway';

  @override
  String get guestSecureFirst => 'Secure first';

  @override
  String experienceIs(String value) {
    return 'Experience: $value';
  }

  @override
  String get planGone => 'This workout no longer exists.';

  @override
  String get logAsDone => 'Log as done';

  @override
  String planMoved(String title, String date) {
    return '$title moved to $date';
  }

  @override
  String get planLogMoved => 'Workout moved';

  @override
  String planLogCreated(String date) {
    return 'Plan created – starts $date';
  }

  @override
  String get legendDone => 'done';

  @override
  String get legendPlanned => 'planned';

  @override
  String get legendOnTarget => 'as planned';

  @override
  String get legendPartly => 'partly';

  @override
  String get legendOff => 'far off';

  @override
  String get legendMissed => 'missed / too little';

  @override
  String replacesDayWorkout(String day) {
    return 'replaces $day workout';
  }

  @override
  String get painWhere => 'Where does it hurt?';

  @override
  String get painFoot => 'Foot / ankle';

  @override
  String get painArm => 'Arm / hand';

  @override
  String get painNeck => 'Neck';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String countAsReplacement(String title, String day) {
    return 'Count as a replacement for $title ($day)?';
  }

  @override
  String get countAsReplacementSub => 'You started it from a workout of another day. Yes ticks that workout off; no keeps it open.';

  @override
  String replacementDone(String title) {
    return '$title counts as done';
  }

  @override
  String plannedLine(String title, String amount) {
    return 'Planned: $title · $amount';
  }

  @override
  String fulfilledPct(String share) {
    return '$share done';
  }

  @override
  String coachRpeHigh(String title, int n) {
    return '$title at RPE $n – a bit easier next week?';
  }

  @override
  String get coachAsPlanned => 'Done as planned – well done.';

  @override
  String get coachShorter => 'Shorter than planned – no problem, don’t make it up.';

  @override
  String get coachLonger => 'Longer than planned – keep your next easy session really easy.';

  @override
  String maxRepsN(int reps) {
    String _temp0 = intl.Intl.pluralLogic(
      reps,
      locale: localeName,
      other: '$reps reps',
      one: '1 rep',
    );
    return '$_temp0';
  }

  @override
  String predictionBasis(String dist, String time, String source) {
    return 'Based on $dist in $time ($source)';
  }

  @override
  String get predictionFromProfile => 'profile';

  @override
  String predictionFromRun(String date) {
    return 'run on $date';
  }

  @override
  String get recalSubtitle => 'Suggestions for the next 2 weeks';

  @override
  String get termKeyTitle => 'Key session';

  @override
  String get termKeyBody => 'The one or two sessions of a week that move your fitness forward most – e.g. intervals, a tempo run or the long run. The other sessions are easy and help you recover for them.';

  @override
  String get termKeyTip => 'Missed one? “Adjust week” moves it to a free day – never right next to another key session.';

  @override
  String get termLoadWeekTitle => 'Loading week';

  @override
  String get termLoadWeekBody => 'A normal training week in which volume or intensity rises a little. Two to four loading weeks are followed by a deload week.';

  @override
  String get termLoadWeekTip => 'Feeling tired at the end of a loading week is normal – the deload week turns it into fitness.';

  @override
  String get termDeloadTitle => 'Deload week';

  @override
  String get termDeloadBody => 'Every 3–5 weeks a lighter week (about 60–70 % of the volume, little intensity). Your body adapts to the training in this time.';

  @override
  String get termDeloadTip => 'Don’t make up the missing volume – the week is meant to feel easy.';

  @override
  String get termStridesTitle => 'Strides';

  @override
  String get termStridesBody => 'Short accelerations of 15–30 s up to a fast but relaxed pace, with full recovery in between. They improve running economy and technique without tiring you.';

  @override
  String get termStridesTip => 'Stay relaxed: shoulders loose, quick steps – it is not a sprint.';

  @override
  String get termFartlekTitle => 'Fartlek';

  @override
  String get termFartlekBody => '“Speed play”: faster and easier sections alternate by feel or by time, without fixed distances. A playful way to bring speed into a run.';

  @override
  String get termFartlekTip => 'Use landmarks: faster to the next lamp post, easy to the next corner.';

  @override
  String get termAcwrTitle => 'ACWR – acute:chronic workload ratio';

  @override
  String get termAcwrBody => 'Your load of the last 7 days (acute, ATL) compared with your average week of the last 28 days (chronic, CTL). Between 0.8 and 1.3 you build fitness at a low injury risk; above 1.5 the risk rises clearly.';

  @override
  String get termAcwrTip => 'A high value? Plan an easy day instead of adding more.';

  @override
  String daysLeftInline(int days) {
    return '$days days left';
  }

  @override
  String fcReasonSessionsSkipped(int done, int total) {
    return '$done of $total planned sessions of the last 4 weeks done – regular training builds the fitness, skipped sessions add up';
  }

  @override
  String fcReasonKeyMissed(int done, int total) {
    return '$done of $total key sessions (tempo, intervals, long runs) of the last 4 weeks done';
  }

  @override
  String recalWhySessionsSkipped(int done, int total) {
    return 'Over the last 4 weeks $done of $total sessions were done. If certain days never work, move or drop them in the week planner instead of skipping them.';
  }

  @override
  String recalWhyKeyMissed(int done, int total) {
    return 'Over the last 4 weeks $done of $total key sessions (tempo, intervals, long runs) were done – they carry the race preparation, give them priority over easy runs.';
  }

  @override
  String recalWhyGoalAtRiskTime(String forecast, String goal) {
    return 'The goal forecast puts race day at $forecast – the target $goal is hard to reach with the current fitness. Consider adjusting the target.';
  }

  @override
  String wRaceRealistic(String time, String pace) {
    return 'Realistic on your fitness: $time ($pace) – if you feel good after halfway, pick it up.';
  }

  @override
  String get recalWhyRpeLowSpaced => 'Your key workouts felt easy again – but the volume only just went up, so it stays this week (at most every other week, 3 times per plan). If it keeps feeling easy, the targets follow.';

  @override
  String get recalWhyTaper => 'Taper: less is more – the volume is reduced on purpose and stays that way. Fitness doesn\'t drop in two weeks; freshness for race day comes from the rest.';

  @override
  String recalWhyTaperOverdo(int pct) {
    return 'Taper: last week you trained $pct % of the planned volume. Less is more now – stick to the reduced volume, the form for race day comes from the rest.';
  }

  @override
  String progStageHeld(int weeks) {
    return 'The build-up has been held for $weeks weeks (stage repeated or long session shortened).';
  }

  @override
  String progStageHeldRisk(int weeks) {
    return 'The build-up has been held for $weeks weeks and race day is close – the goal is at risk.';
  }

  @override
  String feasLongRunShare2(int min) {
    return 'Your other runs are too short for the long run this race needs: with three runs a week it may be about two thirds of the week. Plan about $min min for your other runs.';
  }

  @override
  String feasLongRunFinish(String have, String need) {
    return 'Your longest long run only reaches about $have km before the race – this race needs about $need km. The plan therefore treats the race as a finish goal, without a target time.';
  }

  @override
  String get zGoalPace => 'Race pace';

  @override
  String get mismatchTitle => 'Goal and plan don\'t match';

  @override
  String mismatchFocusBody(String goal, String focus, String newFocus) {
    return 'Your goal $goal doesn\'t match your focus $focus – switch the focus to $newFocus and adjust the plan?';
  }

  @override
  String mismatchPlanBody(String goal) {
    return 'Your plan isn\'t aligned to $goal yet – adjust the plan up to race day?';
  }

  @override
  String mismatchMissing(String sports) {
    return 'Missing from the plan so far: $sports.';
  }

  @override
  String get mismatchAdjust => 'Adjust';

  @override
  String get later => 'Later';

  @override
  String get alignStatusAligned => 'Your plan is aligned to this race';

  @override
  String get alignStatusAlignedSub => 'A new date or distance rebuilds the plan up to race day (completed workouts are kept).';

  @override
  String get alignStatusNotAligned => 'Your plan isn\'t aligned to this race yet.';

  @override
  String alignFocusWizard(String focus) {
    return 'The focus switches to $focus. When you save, the plan settings open so you can set your week (with every discipline) – the check of the goal follows there.';
  }

  @override
  String weekMissingSport(String sports, String focus) {
    return '$sports is not in your week yet – a $focus plan needs at least one session of it.';
  }

  @override
  String get summaryNewPlan => 'Your new plan';

  @override
  String summaryWeekStructure(String structure) {
    return 'Week: $structure';
  }

  @override
  String summaryPlanLengthEvent(int weeks) {
    return 'Length: $weeks weeks up to race day';
  }

  @override
  String summaryPlanLength(int weeks) {
    return 'Length: $weeks weeks';
  }

  @override
  String planWeeksCurrent(int weeks) {
    return '$weeks weeks · current';
  }

  @override
  String get planLogReplace => 'Counted as replacement';

  @override
  String get planLogReplaceReason => 'A session from another day ticked this workout off.';

  @override
  String get planLogUnlink => 'Link reopened';

  @override
  String get planLogUnlinkReason => 'Older versions ticked workouts off with sessions more than a day away. They are open again – on the session you can count it as a replacement.';

  @override
  String get planLogTickedOff => 'ticked off';

  @override
  String get planLogReopened => 'open again';

  @override
  String get replacementUndo => 'No longer count as replacement';

  @override
  String replacementUndone(String title) {
    return '$title is open again';
  }

  @override
  String coachMuchShorter(String share) {
    return 'Only $share of the plan – far off, but it counts as done. Feeling good? Add a bit on an easy day; otherwise just carry on.';
  }

  @override
  String partlyDone(String share) {
    return 'partly done ($share)';
  }

  @override
  String doneOnDay(String day) {
    return 'done on $day';
  }

  @override
  String get beforePlanStart => 'before the plan';

  @override
  String get workoutsDone => 'Workouts done';

  @override
  String extraSessionsN(int n) {
    return '+$n extra';
  }

  @override
  String planCompletionMinutes(int pct) {
    return 'Plan $pct % done (of the planned minutes due so far)';
  }

  @override
  String get quickRecord => 'Record';

  @override
  String get noXpTooShort => 'No XP – too short for a workout';

  @override
  String coachQRace(String race) {
    return 'How do I prepare best for $race?';
  }

  @override
  String get coachQTri => 'How do I combine swimming, cycling and running in one week?';

  @override
  String get coachQGym => 'How do I get stronger without stalling?';

  @override
  String get coachQRide => 'How do I get faster on the bike?';

  @override
  String get coachQSwim => 'How do I swim more efficiently?';

  @override
  String get fromPlanTitle => 'Taken over from the plan';

  @override
  String fromPlanGymLine(int count, int sets, String volume) {
    return '$count exercises · $sets sets · $volume';
  }

  @override
  String get fromPlanHintGym => 'Saved with the exercises, sets and weights of the plan. Did something differ? Correct it afterwards on the session under “Edit”.';

  @override
  String get fromPlanHintCardio => 'Duration and distance come from the plan – change them to what you actually did.';

  @override
  String get fromPlanBadge => 'Taken over from the plan';

  @override
  String get fromPlanNoteGym => 'not recorded: counts for volume, sets, statistics and the plan, but sets no records. Use “Edit” to enter what you really lifted.';

  @override
  String get fromPlanNoteCardio => 'not recorded: counts for distance, time and the plan, but sets no records and doesn’t adjust your paces. Use “Edit” to enter your real values.';

  @override
  String get summaryTooShortGym => 'Less than a minute of training.';

  @override
  String get summaryTooShortTime => 'Less than a minute recorded.';

  @override
  String get summaryNoDistanceTitle => 'No distance recorded';

  @override
  String get summaryNoDistanceBody => 'GPS recorded no distance. Save anyway and enter the distance afterwards under “Edit” – or discard the session.';

  @override
  String get summaryNoLapsTitle => 'No laps counted';

  @override
  String get summaryNoLapsBody => 'No laps were counted. Save anyway and enter laps or distance afterwards under “Edit” – or discard the session.';

  @override
  String get summaryTooLittle => 'Less than 10 % of the plan – this doesn’t count as done yet.';

  @override
  String get editSessionHintGym => 'Correct weights, reps and sets, add or remove exercises.';

  @override
  String get editSessionHintCardio => 'Correct wrong measurements or entries.';

  @override
  String get editSessionHintSwim => 'Correct laps, pool length or distance – laps × pool length give the distance.';

  @override
  String get removeExercise => 'Remove exercise';

  @override
  String exerciseRemoved(String name) {
    return '$name removed';
  }

  @override
  String get moreActions => 'More';

  @override
  String complianceNotCounted(int pct) {
    return 'Not counted – only $pct % of the plan';
  }

  @override
  String notCountedShort(String share) {
    return 'not counted ($share)';
  }

  @override
  String setsOfPlanned(int done, int total) {
    return '$done of $total sets';
  }

  @override
  String coachNotCounted(String share) {
    return 'Only $share of the plan – too little to count as done. Did more than that? Correct the session; otherwise the workout is still open.';
  }

  @override
  String coachNotCountedSets(String share) {
    return 'Only $share of the planned sets – too little to count as done. Did more sets? Add them on the session; otherwise the workout is still open.';
  }

  @override
  String coachMuchFewerSets(String share) {
    return 'Only $share of the planned sets – far off, but it counts as done. Don’t make them up; the next strength session starts normally again.';
  }

  @override
  String get coachFewerSets => 'Fewer sets than planned – no problem, don’t make them up.';

  @override
  String get coachMoreSets => 'More sets than planned – give yourself enough recovery before the next strength session.';

  @override
  String get termComplianceTitle => 'Plan compliance – how a workout is rated';

  @override
  String termComplianceBody(String greenMin, String greenMax, String yellowMin, String yellowMax, String countMin) {
    return 'Compared with the plan is the distance (endurance workouts with a distance; structured workouts: distance or duration, whichever is closer to the plan), the done work sets (strength – sets done at a much lighter weight or with far fewer reps count partly) or else the duration. A workout marked as done with the plan\'s numbers counts as planned.\n\n✓ green, as planned: $greenMin–$greenMax\n✓ yellow, partly / above plan: $yellowMin to under $greenMin, or over $greenMax up to $yellowMax\n✓ orange, far off: $countMin to under $yellowMin, or over $yellowMax\n✕ red: missed, or under $countMin – an aborted start doesn’t count as done.';
  }

  @override
  String termComplianceTip(String half, String over) {
    return 'Partly or far off still counts as done – the plan only adapts when it happens repeatedly. For that, a long run or a key session needs at least $half of the plan, and clearly more than planned (over $over) counts like a session that was too hard.';
  }

  @override
  String get feasTitleNote => 'Note on your plan';

  @override
  String feasLongRunTimeCap(String time, String have, String race) {
    return 'Your long runs stop at $time – at your easy pace that is about $have km (many plans go up to $race km). Running longer in one go adds more injury risk and recovery time than fitness. So: finishing is the goal – start easy and plan short walk breaks from the start (e.g. 1 min every 10 min).';
  }

  @override
  String durationRange(String from, String to) {
    return 'Choose a time between $from and $to.';
  }

  @override
  String bestTimeFor(String distance) {
    return 'Best time · $distance';
  }

  @override
  String swimTestFor(String distance) {
    return 'Swim test · $distance';
  }

  @override
  String get noTargetTime => 'No target time – just finish';

  @override
  String get raceWhen => 'When is the race?';

  @override
  String get raceByDate => 'Date';

  @override
  String get raceByWeeks => 'Plan length';

  @override
  String get raceByWeeksHint => 'No date yet? Choose the plan length: the race goes on the day of your long session in the last week, and the plan builds up to it – taper included.';

  @override
  String raceOnDate(String date) {
    return 'Race on $date';
  }

  @override
  String get progFromPlan => 'last session was logged from the plan, not measured – same weight and reps once more';

  @override
  String get progRepCap => 'as many reps as this range allows – add load or a harder variation to progress';

  @override
  String feasRunFrequency(String have, String need) {
    return 'Runs a week in your plan: $have. This distance needs at least $need runs a week (or a clearly higher weekly volume), so your body tolerates the long run – plan more run days.';
  }

  @override
  String feasRideFrequency(String have, String need) {
    return 'Rides a week in your plan: $have. This race needs at least $need rides a week – plan more bike days.';
  }

  @override
  String feasSwimFrequency(String have, String need) {
    return 'Swims a week in your plan: $have. This race needs at least $need swims a week to build technique and continuous swimming – plan more swim sessions.';
  }

  @override
  String feasLongRunRamp(String have, int weeks, String need) {
    return 'From where you are now, your long run grows safely (at most +10 % or +1 km a week) only to about $have km in $weeks weeks – this race needs about $need km.';
  }

  @override
  String feasLongRunShare3(int pct, int min) {
    return 'Your other runs are too short for the long run this race needs: it should be at most about $pct % of your weekly kilometres. Plan about $min min for your other runs.';
  }

  @override
  String feasLongSwimOpen(int meters, int target) {
    return 'By race day your continuous swim only reaches about $meters m – for this open-water race you should swim at least about $target m without stopping. Open water has no wall to hold on to: never swim alone, wear a wetsuit and a swim buoy.';
  }

  @override
  String get wOpenWaterSafety => 'Open-water safety: never swim alone (group or escort boat), wetsuit, swim buoy and a bright cap; with cold, cramp or panic roll onto your back and raise a hand.';

  @override
  String get wGymRaceWeekNote => 'Race coming up: no heavy leg work any more (the last heavy leg session is 7–10 days before the race) – upper body, core and mobility only, easy.';

  @override
  String get stepFartlekSoftNote => 'Pick it up, but controlled – effort 6–7 out of 10, short sentences still possible, no sprint';

  @override
  String get stepBrickEasyNote => 'Keep running easy (effort 4–5 out of 10) – your legs get used to the change, no race pace yet';

  @override
  String get feasLongRunRampHint => 'Do you already run longer? Enter your longest run of the last weeks – the plan then builds on it.';

  @override
  String summaryRemoveRaceGoal(String name, String date) {
    return 'Remove the race goal “$name” ($date)';
  }

  @override
  String get summaryRemoveRaceGoalOn => 'Your new plan has no race – the goal the previous plan was built for is removed with it.';

  @override
  String get summaryRemoveRaceGoalOff => 'The goal stays: its countdown and the hint “Goal and plan don’t match” remain until you align a plan with it again.';

  @override
  String fcEarlyMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more workouts of the plan and the forecast uses your training data.',
      one: 'One more workout of the plan and the forecast uses your training data.',
    );
    return '$_temp0';
  }

  @override
  String plannedNotCountedSub(String date, String duration) {
    return 'Your session on $date ($duration) was too short to count for this workout – it stays open.';
  }

  @override
  String overPlanShort(String share) {
    return 'above plan ($share)';
  }

  @override
  String farOffShort(String share) {
    return 'far off plan ($share)';
  }

  @override
  String logCompletesPlanOf(String day) {
    return 'Completes the workout planned for $day';
  }

  @override
  String get invalidNumber => 'Please enter a number';

  @override
  String get withoutDistance => 'Without distance';

  @override
  String get enterDistanceHint => 'e.g. from the treadmill';

  @override
  String streakThisWeekShort(int done, int target) {
    return 'This week: $done of $target training days';
  }

  @override
  String get freeGymTitle => 'Free workout';

  @override
  String sessionEndsInFuture(String time) {
    return 'With this start and duration the workout would end in the future ($time) – please check both.';
  }

  @override
  String sessionPaceImplausible(String pace) {
    return 'Average $pace – hardly possible. Are the distance and duration right?';
  }

  @override
  String recNow(int count) {
    return 'now $count×';
  }

  @override
  String get yourSwimZones => 'Your swim zones';

  @override
  String get swimCssEstimated => 'Estimated from your 400 m – add the 200 m for an exact CSS.';

  @override
  String get swimTestOnly200 => 'The CSS test needs the 400 m time too – the 200 m alone is not enough.';

  @override
  String get swimTestImplausible => 'These two times don’t fit together (the 400 m should take a little more than twice the 200 m). Please check them – until then the CSS is estimated from the 400 m.';

  @override
  String infoAbout(String title) {
    return 'About $title';
  }

  @override
  String get logRirSettingShort => 'Reps in the tank (RIR) after each set';

  @override
  String get logRirSettingInfo => 'After every set you note how many more reps you could have done (reps in reserve, RIR). When an exercise has no quick rating, Strive uses these values for your next progression. The quick rating per exercise stays either way.';

  @override
  String get trainingReminderShort => 'On planned training days';

  @override
  String get vibrationInfo => 'Vibrates when a rest timer ends, at every new step of a structured workout and at every kilometre split of a recorded activity.';

  @override
  String get reorderHint => 'Long-press folders and programs to move them.';

  @override
  String get restoreBuiltins => 'Restore standard programs';

  @override
  String restoreBuiltinsAdd(String names) {
    return 'Added in their original state: $names.';
  }

  @override
  String restoreBuiltinsKeep(String names) {
    return 'Your changed versions stay as your own programs ($names). New plans use the originals again.';
  }

  @override
  String get restoreAction => 'Restore';

  @override
  String programsRestored(int count) {
    return '$count programs restored';
  }

  @override
  String get ownVersionSuffix => 'custom';

  @override
  String builtinChangedLine(String names) {
    return 'Changed: $names';
  }

  @override
  String get builtinsAllOriginal => 'All standard programs are in their original state.';

  @override
  String get restoreBuiltinsSub => 'Adds missing or changed standard programs in their original state. Your changed versions are kept.';

  @override
  String movedToFolder(String folder) {
    return 'Moved to $folder';
  }
}
