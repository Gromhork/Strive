import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Gym · Run · Ride · Swim — all in one place.'**
  String get tagline;

  /// No description provided for @sportGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get sportGym;

  /// No description provided for @sportRun.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get sportRun;

  /// No description provided for @sportRide.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get sportRide;

  /// No description provided for @sportSwim.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get sportSwim;

  /// No description provided for @focusHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get focusHybrid;

  /// No description provided for @focusDuathlon.
  ///
  /// In en, this message translates to:
  /// **'Duathlon'**
  String get focusDuathlon;

  /// No description provided for @focusTriathlon.
  ///
  /// In en, this message translates to:
  /// **'Triathlon'**
  String get focusTriathlon;

  /// No description provided for @intensityEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get intensityEasy;

  /// No description provided for @intensityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get intensityModerate;

  /// No description provided for @intensityTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get intensityTempo;

  /// No description provided for @intensityIntervals.
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get intensityIntervals;

  /// No description provided for @intensityLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get intensityLong;

  /// No description provided for @intensityTechnique.
  ///
  /// In en, this message translates to:
  /// **'Technique'**
  String get intensityTechnique;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Register'**
  String get noAccount;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is wrong.'**
  String get authWrongCredentials;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must have at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get authNetwork;

  /// No description provided for @authNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not enabled in Firebase yet.'**
  String get authNotEnabled;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get authError;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email first.'**
  String get authEnterEmail;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent – check your inbox.'**
  String get authResetSent;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up Strive'**
  String get onboardingTitle;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get letsGo;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Strive'**
  String get welcomeTitle;

  /// No description provided for @welcomeSub.
  ///
  /// In en, this message translates to:
  /// **'A few questions so your coach can build the right plan for you.'**
  String get welcomeSub;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYou;

  /// No description provided for @aboutYouSub.
  ///
  /// In en, this message translates to:
  /// **'Used for training load, heart-rate zones and body stats.'**
  String get aboutYouSub;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @diverse.
  ///
  /// In en, this message translates to:
  /// **'Diverse'**
  String get diverse;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @bodyCompositionOptional.
  ///
  /// In en, this message translates to:
  /// **'Body composition (optional)'**
  String get bodyCompositionOptional;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body fat'**
  String get bodyFat;

  /// No description provided for @muscleMass.
  ///
  /// In en, this message translates to:
  /// **'Muscle mass'**
  String get muscleMass;

  /// No description provided for @muscle.
  ///
  /// In en, this message translates to:
  /// **'Muscle'**
  String get muscle;

  /// No description provided for @fitnessLevel.
  ///
  /// In en, this message translates to:
  /// **'Fitness level'**
  String get fitnessLevel;

  /// No description provided for @fitnessLevelSub.
  ///
  /// In en, this message translates to:
  /// **'Be honest – the plan adapts as you improve.'**
  String get fitnessLevelSub;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @beginnerDesc.
  ///
  /// In en, this message translates to:
  /// **'New or returning after a long break'**
  String get beginnerDesc;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @intermediateDesc.
  ///
  /// In en, this message translates to:
  /// **'Training regularly for 6+ months'**
  String get intermediateDesc;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advancedDesc.
  ///
  /// In en, this message translates to:
  /// **'Years of structured training'**
  String get advancedDesc;

  /// No description provided for @experienceWith.
  ///
  /// In en, this message translates to:
  /// **'Experience with'**
  String get experienceWith;

  /// No description provided for @focusTitle.
  ///
  /// In en, this message translates to:
  /// **'Your focus'**
  String get focusTitle;

  /// No description provided for @focusSub.
  ///
  /// In en, this message translates to:
  /// **'What do you mainly train for?'**
  String get focusSub;

  /// No description provided for @yourGoals.
  ///
  /// In en, this message translates to:
  /// **'Your goals'**
  String get yourGoals;

  /// No description provided for @goalStrength.
  ///
  /// In en, this message translates to:
  /// **'Get stronger'**
  String get goalStrength;

  /// No description provided for @goalMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build muscle'**
  String get goalMuscle;

  /// No description provided for @goalFatLoss.
  ///
  /// In en, this message translates to:
  /// **'Lose fat'**
  String get goalFatLoss;

  /// No description provided for @goalEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get goalEndurance;

  /// No description provided for @goalHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get goalHealth;

  /// No description provided for @goalRace.
  ///
  /// In en, this message translates to:
  /// **'Race / event'**
  String get goalRace;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Training days'**
  String get scheduleTitle;

  /// No description provided for @scheduleSub.
  ///
  /// In en, this message translates to:
  /// **'On which days do you want to train?'**
  String get scheduleSub;

  /// No description provided for @daysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} days per week'**
  String daysPerWeek(int count);

  /// No description provided for @longSessionDay.
  ///
  /// In en, this message translates to:
  /// **'Long session day'**
  String get longSessionDay;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric (kg, km)'**
  String get metric;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial (lb, mi)'**
  String get imperial;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Training for an event?'**
  String get eventTitle;

  /// No description provided for @eventSub.
  ///
  /// In en, this message translates to:
  /// **'Add a race (marathon, triathlon …) and get a countdown. Optional.'**
  String get eventSub;

  /// No description provided for @eventName.
  ///
  /// In en, this message translates to:
  /// **'Event name'**
  String get eventName;

  /// No description provided for @eventDate.
  ///
  /// In en, this message translates to:
  /// **'Event date'**
  String get eventDate;

  /// No description provided for @eventDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get eventDistance;

  /// No description provided for @halfMarathon.
  ///
  /// In en, this message translates to:
  /// **'Half marathon'**
  String get halfMarathon;

  /// No description provided for @marathon.
  ///
  /// In en, this message translates to:
  /// **'Marathon'**
  String get marathon;

  /// No description provided for @searchMarathonDe.
  ///
  /// In en, this message translates to:
  /// **'Find events on marathon.de'**
  String get searchMarathonDe;

  /// No description provided for @generatePlanNow.
  ///
  /// In en, this message translates to:
  /// **'Create my training plan'**
  String get generatePlanNow;

  /// No description provided for @generatePlanNowSub.
  ///
  /// In en, this message translates to:
  /// **'Built from your answers – you can change everything later.'**
  String get generatePlanNowSub;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get navTrain;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get navCoach;

  /// No description provided for @allSports.
  ///
  /// In en, this message translates to:
  /// **'All sports'**
  String get allSports;

  /// No description provided for @weekStreakTooltip.
  ///
  /// In en, this message translates to:
  /// **'Weeks in a row with your training goal reached'**
  String get weekStreakTooltip;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @todaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout'**
  String get todaysWorkout;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDay;

  /// No description provided for @restDaySub.
  ///
  /// In en, this message translates to:
  /// **'Recovery is training too. Feel like moving anyway?'**
  String get restDaySub;

  /// No description provided for @doneToday.
  ///
  /// In en, this message translates to:
  /// **'{count} done today 💪'**
  String doneToday(int count);

  /// No description provided for @train.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get train;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @comingUp.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get comingUp;

  /// No description provided for @toCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get toCalendar;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get rest;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @feelsLike.
  ///
  /// In en, this message translates to:
  /// **'feels'**
  String get feelsLike;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @weatherNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow location for local weather'**
  String get weatherNoLocation;

  /// No description provided for @weatherError.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable'**
  String get weatherError;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @trainedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'trained this week'**
  String get trainedThisWeek;

  /// No description provided for @readyBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building your baseline'**
  String get readyBuilding;

  /// No description provided for @readyBuildingText.
  ///
  /// In en, this message translates to:
  /// **'After about 3 weeks of training, Strive can judge your load and recovery.'**
  String get readyBuildingText;

  /// No description provided for @readyFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get readyFresh;

  /// No description provided for @readyFreshText.
  ///
  /// In en, this message translates to:
  /// **'Your load is low – a great time for a hard session or to increase volume.'**
  String get readyFreshText;

  /// No description provided for @readyOptimal.
  ///
  /// In en, this message translates to:
  /// **'Optimal load'**
  String get readyOptimal;

  /// No description provided for @readyOptimalText.
  ///
  /// In en, this message translates to:
  /// **'Your training load is in the sweet spot. Keep it up!'**
  String get readyOptimalText;

  /// No description provided for @readyHigh.
  ///
  /// In en, this message translates to:
  /// **'High load'**
  String get readyHigh;

  /// No description provided for @readyHighText.
  ///
  /// In en, this message translates to:
  /// **'Load is rising quickly. Prioritise sleep and keep the next session easy.'**
  String get readyHighText;

  /// No description provided for @readyOver.
  ///
  /// In en, this message translates to:
  /// **'Recovery recommended'**
  String get readyOver;

  /// No description provided for @readyOverText.
  ///
  /// In en, this message translates to:
  /// **'Injury risk is elevated. Take a rest day or an easy alternative (walk, mobility).'**
  String get readyOverText;

  /// No description provided for @weightLogHint.
  ///
  /// In en, this message translates to:
  /// **'Log your weight with + / – to see your trend'**
  String get weightLogHint;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @noGoalsYet.
  ///
  /// In en, this message translates to:
  /// **'No goals yet – set one to stay motivated.'**
  String get noGoalsYet;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelN(int level);

  /// No description provided for @xpToNext.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to next level'**
  String xpToNext(int xp);

  /// No description provided for @freeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Free workout'**
  String get freeWorkout;

  /// No description provided for @workoutRunning.
  ///
  /// In en, this message translates to:
  /// **'Workout in progress'**
  String get workoutRunning;

  /// No description provided for @workoutRunningBody.
  ///
  /// In en, this message translates to:
  /// **'Another workout is still running. Discard it and start a new one?'**
  String get workoutRunningBody;

  /// No description provided for @discardAndStart.
  ///
  /// In en, this message translates to:
  /// **'Discard & start'**
  String get discardAndStart;

  /// No description provided for @startTraining.
  ///
  /// In en, this message translates to:
  /// **'Start training'**
  String get startTraining;

  /// No description provided for @logManually.
  ///
  /// In en, this message translates to:
  /// **'Log manually'**
  String get logManually;

  /// No description provided for @openWater.
  ///
  /// In en, this message translates to:
  /// **'Open water'**
  String get openWater;

  /// No description provided for @outdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor (GPS)'**
  String get outdoor;

  /// No description provided for @pool.
  ///
  /// In en, this message translates to:
  /// **'Pool'**
  String get pool;

  /// No description provided for @indoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get indoor;

  /// No description provided for @poolLength.
  ///
  /// In en, this message translates to:
  /// **'Pool length'**
  String get poolLength;

  /// No description provided for @poolHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Lap\" after every length. Distance is calculated automatically.'**
  String get poolHint;

  /// No description provided for @indoorHint.
  ///
  /// In en, this message translates to:
  /// **'Treadmill / trainer: enter the distance when you finish.'**
  String get indoorHint;

  /// No description provided for @gpsHint.
  ///
  /// In en, this message translates to:
  /// **'GPS records your route, distance and pace – also with the screen off.'**
  String get gpsHint;

  /// No description provided for @gpsServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Please turn on location services.'**
  String get gpsServiceOff;

  /// No description provided for @gpsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for GPS tracking.'**
  String get gpsPermissionDenied;

  /// No description provided for @noActiveWorkout.
  ///
  /// In en, this message translates to:
  /// **'No active workout.'**
  String get noActiveWorkout;

  /// No description provided for @noSetsDone.
  ///
  /// In en, this message translates to:
  /// **'No sets completed'**
  String get noSetsDone;

  /// No description provided for @noSetsDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Discard this workout?'**
  String get noSetsDoneBody;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish workout?'**
  String get finishWorkout;

  /// No description provided for @finishWorkoutBody.
  ///
  /// In en, this message translates to:
  /// **'Your workout will be saved after the summary.'**
  String get finishWorkoutBody;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @discardWorkout.
  ///
  /// In en, this message translates to:
  /// **'Discard workout'**
  String get discardWorkout;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercise;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @restTimeSeconds.
  ///
  /// In en, this message translates to:
  /// **'Rest time (seconds)'**
  String get restTimeSeconds;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @setShort.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setShort;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get addSet;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @enterDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance covered'**
  String get enterDistance;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @avgPace.
  ///
  /// In en, this message translates to:
  /// **'Avg. pace'**
  String get avgPace;

  /// No description provided for @avgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg. speed'**
  String get avgSpeed;

  /// No description provided for @laps.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get laps;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get lap;

  /// No description provided for @elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevation;

  /// No description provided for @lastSplit.
  ///
  /// In en, this message translates to:
  /// **'Last km'**
  String get lastSplit;

  /// No description provided for @undoLap.
  ///
  /// In en, this message translates to:
  /// **'Undo last lap'**
  String get undoLap;

  /// No description provided for @pauseToFinish.
  ///
  /// In en, this message translates to:
  /// **'Pause to finish'**
  String get pauseToFinish;

  /// No description provided for @gpsError.
  ///
  /// In en, this message translates to:
  /// **'GPS error'**
  String get gpsError;

  /// No description provided for @gpsSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching GPS …'**
  String get gpsSearching;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job! 🎉'**
  String get greatJob;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @coachBattleWon.
  ///
  /// In en, this message translates to:
  /// **'Coach battle won! You beat the prediction based on your last session.'**
  String get coachBattleWon;

  /// No description provided for @coachBattleLost.
  ///
  /// In en, this message translates to:
  /// **'Coach battle: the prediction was a bit higher this time – next time!'**
  String get coachBattleLost;

  /// No description provided for @newPr.
  ///
  /// In en, this message translates to:
  /// **'New personal record!'**
  String get newPr;

  /// No description provided for @howHard.
  ///
  /// In en, this message translates to:
  /// **'How hard was it?'**
  String get howHard;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes (how did it feel? sleep, nutrition …)'**
  String get notesHint;

  /// No description provided for @saveWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save workout'**
  String get saveWorkout;

  /// No description provided for @discardSummaryBody.
  ///
  /// In en, this message translates to:
  /// **'This workout will not be saved.'**
  String get discardSummaryBody;

  /// No description provided for @rpeVeryEasy.
  ///
  /// In en, this message translates to:
  /// **'very easy'**
  String get rpeVeryEasy;

  /// No description provided for @rpeEasy.
  ///
  /// In en, this message translates to:
  /// **'easy'**
  String get rpeEasy;

  /// No description provided for @rpeModerate.
  ///
  /// In en, this message translates to:
  /// **'moderate'**
  String get rpeModerate;

  /// No description provided for @rpeHard.
  ///
  /// In en, this message translates to:
  /// **'hard'**
  String get rpeHard;

  /// No description provided for @rpeMax.
  ///
  /// In en, this message translates to:
  /// **'maximal'**
  String get rpeMax;

  /// No description provided for @badgeFirst.
  ///
  /// In en, this message translates to:
  /// **'First workout'**
  String get badgeFirst;

  /// No description provided for @badgeTen.
  ///
  /// In en, this message translates to:
  /// **'10 workouts'**
  String get badgeTen;

  /// No description provided for @badgeFifty.
  ///
  /// In en, this message translates to:
  /// **'50 workouts'**
  String get badgeFifty;

  /// No description provided for @badgeHundred.
  ///
  /// In en, this message translates to:
  /// **'100 workouts'**
  String get badgeHundred;

  /// No description provided for @badgeTon.
  ///
  /// In en, this message translates to:
  /// **'10 t in one session'**
  String get badgeTon;

  /// No description provided for @badge5k.
  ///
  /// In en, this message translates to:
  /// **'5 km run'**
  String get badge5k;

  /// No description provided for @badge10k.
  ///
  /// In en, this message translates to:
  /// **'10 km run'**
  String get badge10k;

  /// No description provided for @badgeHalf.
  ///
  /// In en, this message translates to:
  /// **'Half marathon'**
  String get badgeHalf;

  /// No description provided for @badgeMarathon.
  ///
  /// In en, this message translates to:
  /// **'Marathon'**
  String get badgeMarathon;

  /// No description provided for @badgeCentury.
  ///
  /// In en, this message translates to:
  /// **'100 km ride'**
  String get badgeCentury;

  /// No description provided for @badgeSwim1k.
  ///
  /// In en, this message translates to:
  /// **'1 km swim'**
  String get badgeSwim1k;

  /// No description provided for @badgeSwim3k.
  ///
  /// In en, this message translates to:
  /// **'3 km swim'**
  String get badgeSwim3k;

  /// No description provided for @badgeStreak4.
  ///
  /// In en, this message translates to:
  /// **'4-week streak'**
  String get badgeStreak4;

  /// No description provided for @badgeStreak12.
  ///
  /// In en, this message translates to:
  /// **'12-week streak'**
  String get badgeStreak12;

  /// No description provided for @badgeEarly.
  ///
  /// In en, this message translates to:
  /// **'Early bird'**
  String get badgeEarly;

  /// No description provided for @badgeAllround.
  ///
  /// In en, this message translates to:
  /// **'All-rounder'**
  String get badgeAllround;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @totalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total volume'**
  String get totalVolume;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @newProgram.
  ///
  /// In en, this message translates to:
  /// **'New program'**
  String get newProgram;

  /// No description provided for @editProgram.
  ///
  /// In en, this message translates to:
  /// **'Edit program'**
  String get editProgram;

  /// No description provided for @quickStart.
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get quickStart;

  /// No description provided for @programs.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get programs;

  /// No description provided for @importCode.
  ///
  /// In en, this message translates to:
  /// **'Import code'**
  String get importCode;

  /// No description provided for @noPrograms.
  ///
  /// In en, this message translates to:
  /// **'No programs for this sport yet.'**
  String get noPrograms;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get noFolder;

  /// No description provided for @codeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Code not found.'**
  String get codeNotFound;

  /// No description provided for @imported.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" imported'**
  String imported(String name);

  /// No description provided for @offlineAction.
  ///
  /// In en, this message translates to:
  /// **'This needs an internet connection.'**
  String get offlineAction;

  /// No description provided for @emptyWorkout.
  ///
  /// In en, this message translates to:
  /// **'Empty workout'**
  String get emptyWorkout;

  /// No description provided for @recordGps.
  ///
  /// In en, this message translates to:
  /// **'Record activity'**
  String get recordGps;

  /// No description provided for @exerciseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Exercise library'**
  String get exerciseLibrary;

  /// No description provided for @addN.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String addN(int count);

  /// No description provided for @searchExercises.
  ///
  /// In en, this message translates to:
  /// **'Search exercises (e.g. bench press, kniebeuge)'**
  String get searchExercises;

  /// No description provided for @bodyPart.
  ///
  /// In en, this message translates to:
  /// **'Body part'**
  String get bodyPart;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @nResults.
  ///
  /// In en, this message translates to:
  /// **'{count} exercises'**
  String nResults(int count);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @secondaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get secondaryMuscles;

  /// No description provided for @watchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch video tutorial'**
  String get watchVideo;

  /// No description provided for @yourRecords.
  ///
  /// In en, this message translates to:
  /// **'Your records'**
  String get yourRecords;

  /// No description provided for @maxWeight.
  ///
  /// In en, this message translates to:
  /// **'Max weight'**
  String get maxWeight;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @strengthProgress.
  ///
  /// In en, this message translates to:
  /// **'Strength progress (e1RM)'**
  String get strengthProgress;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @instructionsEnglishNote.
  ///
  /// In en, this message translates to:
  /// **'Instructions are currently available in English.'**
  String get instructionsEnglishNote;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code {code} copied'**
  String codeCopied(String code);

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'Try my Strive program \"{name}\"! Import code: {code}'**
  String shareText(String name, String code);

  /// No description provided for @deleteProgram.
  ///
  /// In en, this message translates to:
  /// **'Delete program?'**
  String get deleteProgram;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// No description provided for @targetDistance.
  ///
  /// In en, this message translates to:
  /// **'Target distance'**
  String get targetDistance;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @planWorkout.
  ///
  /// In en, this message translates to:
  /// **'Plan workout'**
  String get planWorkout;

  /// No description provided for @editWorkout.
  ///
  /// In en, this message translates to:
  /// **'Edit workout'**
  String get editWorkout;

  /// No description provided for @program.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get program;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @markSkipped.
  ///
  /// In en, this message translates to:
  /// **'Mark as skipped'**
  String get markSkipped;

  /// No description provided for @generatePlan.
  ///
  /// In en, this message translates to:
  /// **'Generate plan'**
  String get generatePlan;

  /// No description provided for @generatePlanSub.
  ///
  /// In en, this message translates to:
  /// **'Focus: {focus} · {days} days/week (change in profile)'**
  String generatePlanSub(String focus, int days);

  /// No description provided for @weeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get weeks;

  /// No description provided for @planLocal.
  ///
  /// In en, this message translates to:
  /// **'Smart rules'**
  String get planLocal;

  /// No description provided for @planAi.
  ///
  /// In en, this message translates to:
  /// **'AI (Gemini)'**
  String get planAi;

  /// No description provided for @planLocalDesc.
  ///
  /// In en, this message translates to:
  /// **'Periodised plan based on sports science (80/20, progressive overload, deload every 4th week). Works offline.'**
  String get planLocalDesc;

  /// No description provided for @planAiDesc.
  ///
  /// In en, this message translates to:
  /// **'Gemini creates an individual plan from your profile and recent training. Needs internet.'**
  String get planAiDesc;

  /// No description provided for @planWishHint.
  ///
  /// In en, this message translates to:
  /// **'Special wishes? e.g. \"focus on legs\", \"sub-50 10k\"'**
  String get planWishHint;

  /// No description provided for @replaceExisting.
  ///
  /// In en, this message translates to:
  /// **'Replace upcoming planned workouts'**
  String get replaceExisting;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @planCreated.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts planned'**
  String planCreated(int count);

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI coach is not available right now. Check your connection or enable Firebase AI Logic.'**
  String get aiUnavailable;

  /// No description provided for @syncCalendar.
  ///
  /// In en, this message translates to:
  /// **'Sync with Google Calendar'**
  String get syncCalendar;

  /// No description provided for @currentWeek.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextWeek;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get lastWeek;

  /// No description provided for @nothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned.'**
  String get nothingPlanned;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No upcoming workouts to export.'**
  String get nothingToExport;

  /// No description provided for @icsShareText.
  ///
  /// In en, this message translates to:
  /// **'My Strive training plan – open with Google Calendar to import.'**
  String get icsShareText;

  /// No description provided for @planGymDesc.
  ///
  /// In en, this message translates to:
  /// **'Strength session – progressive overload: add weight or reps when all sets feel good.'**
  String get planGymDesc;

  /// No description provided for @planDeloadGym.
  ///
  /// In en, this message translates to:
  /// **'Deload week: same exercises, ~60 % of the usual sets, leave 3–4 reps in reserve.'**
  String get planDeloadGym;

  /// No description provided for @planEasyRun.
  ///
  /// In en, this message translates to:
  /// **'Easy run'**
  String get planEasyRun;

  /// No description provided for @planEasyRide.
  ///
  /// In en, this message translates to:
  /// **'Endurance ride'**
  String get planEasyRide;

  /// No description provided for @planEasyDesc.
  ///
  /// In en, this message translates to:
  /// **'Zone 2 – you should be able to talk in full sentences.'**
  String get planEasyDesc;

  /// No description provided for @planLongRun.
  ///
  /// In en, this message translates to:
  /// **'Long run'**
  String get planLongRun;

  /// No description provided for @planLongRunDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy, steady pace. Take fluids/carbs after 60 min.'**
  String get planLongRunDesc;

  /// No description provided for @planRunIntervals.
  ///
  /// In en, this message translates to:
  /// **'Run intervals'**
  String get planRunIntervals;

  /// No description provided for @planRunIntervalsDesc.
  ///
  /// In en, this message translates to:
  /// **'15 min warm-up · 6×800 m at 5k pace, 2 min jog · 10 min cool-down'**
  String get planRunIntervalsDesc;

  /// No description provided for @planRunTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo run'**
  String get planRunTempo;

  /// No description provided for @planRunTempoDesc.
  ///
  /// In en, this message translates to:
  /// **'15 min easy · 20 min at threshold (comfortably hard) · 10 min easy'**
  String get planRunTempoDesc;

  /// No description provided for @planLongRide.
  ///
  /// In en, this message translates to:
  /// **'Long ride'**
  String get planLongRide;

  /// No description provided for @planLongRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Zone 2, cadence 85–95 rpm. Eat every 45 min.'**
  String get planLongRideDesc;

  /// No description provided for @planRideIntervals.
  ///
  /// In en, this message translates to:
  /// **'VO2max intervals'**
  String get planRideIntervals;

  /// No description provided for @planRideIntervalsDesc.
  ///
  /// In en, this message translates to:
  /// **'15 min warm-up · 5×4 min hard, 4 min easy · 10 min cool-down'**
  String get planRideIntervalsDesc;

  /// No description provided for @planRideTempo.
  ///
  /// In en, this message translates to:
  /// **'Sweet spot'**
  String get planRideTempo;

  /// No description provided for @planRideTempoDesc.
  ///
  /// In en, this message translates to:
  /// **'3×12 min at 88–94 % FTP, 4 min easy between.'**
  String get planRideTempoDesc;

  /// No description provided for @planLongSwim.
  ///
  /// In en, this message translates to:
  /// **'Endurance swim'**
  String get planLongSwim;

  /// No description provided for @planLongSwimDesc.
  ///
  /// In en, this message translates to:
  /// **'Continuous swimming at a relaxed pace, focus on breathing.'**
  String get planLongSwimDesc;

  /// No description provided for @planSwimIntervals.
  ///
  /// In en, this message translates to:
  /// **'Swim intervals'**
  String get planSwimIntervals;

  /// No description provided for @planSwimIntervalsDesc.
  ///
  /// In en, this message translates to:
  /// **'400 warm-up · 10×100 at CSS, 15 s rest · 200 cool-down'**
  String get planSwimIntervalsDesc;

  /// No description provided for @planSwimTechnique.
  ///
  /// In en, this message translates to:
  /// **'Technique swim'**
  String get planSwimTechnique;

  /// No description provided for @planSwimTechniqueDesc.
  ///
  /// In en, this message translates to:
  /// **'300 warm-up · 8×50 drills · 6×100 steady · 200 cool-down'**
  String get planSwimTechniqueDesc;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @range4w.
  ///
  /// In en, this message translates to:
  /// **'4W'**
  String get range4w;

  /// No description provided for @range3m.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get range3m;

  /// No description provided for @range1y.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get range1y;

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rangeAll;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @avgGymDays.
  ///
  /// In en, this message translates to:
  /// **'Ø gym days / month'**
  String get avgGymDays;

  /// No description provided for @avgDuration.
  ///
  /// In en, this message translates to:
  /// **'Ø duration'**
  String get avgDuration;

  /// No description provided for @heatmap.
  ///
  /// In en, this message translates to:
  /// **'Training heatmap'**
  String get heatmap;

  /// No description provided for @weeklyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes per week'**
  String get weeklyMinutes;

  /// No description provided for @weeklyDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance per week'**
  String get weeklyDistance;

  /// No description provided for @notEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get notEnoughData;

  /// No description provided for @strengthRecords.
  ///
  /// In en, this message translates to:
  /// **'Strength records'**
  String get strengthRecords;

  /// No description provided for @noRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'Complete a gym workout to see your records.'**
  String get noRecordsYet;

  /// No description provided for @longestDistance.
  ///
  /// In en, this message translates to:
  /// **'Longest'**
  String get longestDistance;

  /// No description provided for @longestDuration.
  ///
  /// In en, this message translates to:
  /// **'Longest time'**
  String get longestDuration;

  /// No description provided for @bestPace.
  ///
  /// In en, this message translates to:
  /// **'Best pace'**
  String get bestPace;

  /// No description provided for @bestSpeed.
  ///
  /// In en, this message translates to:
  /// **'Best speed'**
  String get bestSpeed;

  /// No description provided for @totalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalDistance;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @noSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts yet. Start your first one!'**
  String get noSessionsYet;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete workout?'**
  String get deleteSession;

  /// No description provided for @splits.
  ///
  /// In en, this message translates to:
  /// **'Splits'**
  String get splits;

  /// No description provided for @compareLast.
  ///
  /// In en, this message translates to:
  /// **'Compared to last time'**
  String get compareLast;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @sharedFromStrive.
  ///
  /// In en, this message translates to:
  /// **'Tracked with Strive 💪'**
  String get sharedFromStrive;

  /// No description provided for @bodyComposition.
  ///
  /// In en, this message translates to:
  /// **'Body composition'**
  String get bodyComposition;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get entries;

  /// No description provided for @logBody.
  ///
  /// In en, this message translates to:
  /// **'Log body data'**
  String get logBody;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @coachTitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI coach'**
  String get coachTitle;

  /// No description provided for @coachSub.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about training, recovery or nutrition. Answers use your profile and training data.'**
  String get coachSub;

  /// No description provided for @coachQ1.
  ///
  /// In en, this message translates to:
  /// **'How is my training going? What should I improve?'**
  String get coachQ1;

  /// No description provided for @coachQ2.
  ///
  /// In en, this message translates to:
  /// **'How much protein do I need per day?'**
  String get coachQ2;

  /// No description provided for @coachQ3.
  ///
  /// In en, this message translates to:
  /// **'How do I get faster over 10 km?'**
  String get coachQ3;

  /// No description provided for @coachQ4.
  ///
  /// In en, this message translates to:
  /// **'I slept badly – should I still train today?'**
  String get coachQ4;

  /// No description provided for @coachQ5.
  ///
  /// In en, this message translates to:
  /// **'What should I eat before a long run?'**
  String get coachQ5;

  /// No description provided for @coachDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI answers can be wrong and do not replace medical advice.'**
  String get coachDisclaimer;

  /// No description provided for @askCoach.
  ///
  /// In en, this message translates to:
  /// **'Ask your coach …'**
  String get askCoach;

  /// No description provided for @newGoal.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get newGoal;

  /// No description provided for @editGoal.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoal;

  /// No description provided for @perWeekProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {target} per week'**
  String perWeekProgress(int done, int target);

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysLeft(int days);

  /// No description provided for @eventPassed.
  ///
  /// In en, this message translates to:
  /// **'Event passed'**
  String get eventPassed;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get onTrack;

  /// No description provided for @behindSchedule.
  ///
  /// In en, this message translates to:
  /// **'Behind'**
  String get behindSchedule;

  /// No description provided for @until.
  ///
  /// In en, this message translates to:
  /// **'until'**
  String get until;

  /// No description provided for @goalTypeWeight.
  ///
  /// In en, this message translates to:
  /// **'Body weight'**
  String get goalTypeWeight;

  /// No description provided for @goalTypeDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get goalTypeDistance;

  /// No description provided for @goalTypeFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get goalTypeFrequency;

  /// No description provided for @goalTypeStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get goalTypeStrength;

  /// No description provided for @goalTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get goalTypeEvent;

  /// No description provided for @perWeek.
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get perWeek;

  /// No description provided for @chooseExercise.
  ///
  /// In en, this message translates to:
  /// **'Choose exercise'**
  String get chooseExercise;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @deadlineOptional.
  ///
  /// In en, this message translates to:
  /// **'Deadline (optional)'**
  String get deadlineOptional;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @athlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get athlete;

  /// No description provided for @guestAccount.
  ///
  /// In en, this message translates to:
  /// **'Guest account'**
  String get guestAccount;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @vibrationSub.
  ///
  /// In en, this message translates to:
  /// **'After rest timers and each km'**
  String get vibrationSub;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @hydrationReminder.
  ///
  /// In en, this message translates to:
  /// **'Drink reminder'**
  String get hydrationReminder;

  /// No description provided for @everyNHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} h (8–20 h)'**
  String everyNHours(int hours);

  /// No description provided for @trainingReminder.
  ///
  /// In en, this message translates to:
  /// **'Training reminder'**
  String get trainingReminder;

  /// No description provided for @trainingReminderSub.
  ///
  /// In en, this message translates to:
  /// **'On training days at {time}'**
  String trainingReminderSub(String time);

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reminderTime;

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Send test notification'**
  String get testNotification;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked in system settings.'**
  String get notificationsDenied;

  /// No description provided for @hydrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to drink 💧'**
  String get hydrationTitle;

  /// No description provided for @hydrationBody.
  ///
  /// In en, this message translates to:
  /// **'A glass of water keeps your performance up.'**
  String get hydrationBody;

  /// No description provided for @trainingReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Today: {sport}'**
  String trainingReminderTitle(String sport);

  /// No description provided for @integrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrations;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get comingSoon;

  /// No description provided for @googleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar'**
  String get googleCalendar;

  /// No description provided for @googleCalendarSub.
  ///
  /// In en, this message translates to:
  /// **'Export your plan as a calendar file'**
  String get googleCalendarSub;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @upgradeAccount.
  ///
  /// In en, this message translates to:
  /// **'Save guest account'**
  String get upgradeAccount;

  /// No description provided for @upgradeAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Link an email so you never lose your data'**
  String get upgradeAccountSub;

  /// No description provided for @accountLinked.
  ///
  /// In en, this message translates to:
  /// **'Account saved!'**
  String get accountLinked;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @guestLogoutWarning.
  ///
  /// In en, this message translates to:
  /// **'As a guest, your data will be lost when you log out.'**
  String get guestLogoutWarning;

  /// No description provided for @offlineReady.
  ///
  /// In en, this message translates to:
  /// **'works offline'**
  String get offlineReady;

  /// No description provided for @viewFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus view'**
  String get viewFocus;

  /// No description provided for @viewTable.
  ///
  /// In en, this message translates to:
  /// **'Table view'**
  String get viewTable;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @setXofY.
  ///
  /// In en, this message translates to:
  /// **'Set {x} of {y}'**
  String setXofY(int x, int y);

  /// No description provided for @exerciseXofY.
  ///
  /// In en, this message translates to:
  /// **'Exercise {x}/{y}'**
  String exerciseXofY(int x, int y);

  /// No description provided for @completeSet.
  ///
  /// In en, this message translates to:
  /// **'Complete set {n}'**
  String completeSet(int n);

  /// No description provided for @nextExercise.
  ///
  /// In en, this message translates to:
  /// **'Next exercise'**
  String get nextExercise;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'All sets done – great work!'**
  String get workoutComplete;

  /// No description provided for @superset.
  ///
  /// In en, this message translates to:
  /// **'Superset'**
  String get superset;

  /// No description provided for @linkSuperset.
  ///
  /// In en, this message translates to:
  /// **'Superset with next'**
  String get linkSuperset;

  /// No description provided for @unlinkSuperset.
  ///
  /// In en, this message translates to:
  /// **'Remove from superset'**
  String get unlinkSuperset;

  /// No description provided for @replaceExercise.
  ///
  /// In en, this message translates to:
  /// **'Replace exercise'**
  String get replaceExercise;

  /// No description provided for @warmupSets.
  ///
  /// In en, this message translates to:
  /// **'Warm-up sets'**
  String get warmupSets;

  /// No description provided for @warmupAdded.
  ///
  /// In en, this message translates to:
  /// **'{n} warm-up sets added'**
  String warmupAdded(int n);

  /// No description provided for @plateCalculator.
  ///
  /// In en, this message translates to:
  /// **'Plates'**
  String get plateCalculator;

  /// No description provided for @plateCalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Plate calculator'**
  String get plateCalcTitle;

  /// No description provided for @perSide.
  ///
  /// In en, this message translates to:
  /// **'per side'**
  String get perSide;

  /// No description provided for @barWeight.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get barWeight;

  /// No description provided for @notLoadable.
  ///
  /// In en, this message translates to:
  /// **'{value} cannot be loaded exactly'**
  String notLoadable(String value);

  /// No description provided for @dropSet.
  ///
  /// In en, this message translates to:
  /// **'Drop set'**
  String get dropSet;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @setTypeNormal.
  ///
  /// In en, this message translates to:
  /// **'Working set'**
  String get setTypeNormal;

  /// No description provided for @setTypeWarmup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get setTypeWarmup;

  /// No description provided for @setTypeDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop set'**
  String get setTypeDrop;

  /// No description provided for @setTypeFailure.
  ///
  /// In en, this message translates to:
  /// **'To failure'**
  String get setTypeFailure;

  /// No description provided for @rpeHint.
  ///
  /// In en, this message translates to:
  /// **'How hard was it? RPE 10 = no rep left, 8 = two reps left'**
  String get rpeHint;

  /// No description provided for @progIncrease.
  ///
  /// In en, this message translates to:
  /// **'You hit the top of your rep range last time → try {value} today'**
  String progIncrease(String value);

  /// No description provided for @progAddReps.
  ///
  /// In en, this message translates to:
  /// **'Same weight – aim for {n} reps per set'**
  String progAddReps(int n);

  /// No description provided for @progDeload.
  ///
  /// In en, this message translates to:
  /// **'Last time was a grind – reset to {value} and build back up'**
  String progDeload(String value);

  /// No description provided for @progHold.
  ///
  /// In en, this message translates to:
  /// **'Keep the weight and own every rep'**
  String get progHold;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @lastTime.
  ///
  /// In en, this message translates to:
  /// **'Last time'**
  String get lastTime;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @restHint.
  ///
  /// In en, this message translates to:
  /// **'Breathe, drink some water, get ready.'**
  String get restHint;

  /// No description provided for @skipRest.
  ///
  /// In en, this message translates to:
  /// **'Skip rest'**
  String get skipRest;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get translating;

  /// No description provided for @translatedByAi.
  ///
  /// In en, this message translates to:
  /// **'Translated by AI'**
  String get translatedByAi;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation unavailable – showing English original'**
  String get translationFailed;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get showOriginal;

  /// No description provided for @showTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get showTranslation;

  /// No description provided for @skyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get skyClear;

  /// No description provided for @skyPartly.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get skyPartly;

  /// No description provided for @skyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get skyCloudy;

  /// No description provided for @skyFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get skyFog;

  /// No description provided for @skyDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get skyDrizzle;

  /// No description provided for @skyRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get skyRain;

  /// No description provided for @skySnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get skySnow;

  /// No description provided for @skyStorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get skyStorm;

  /// No description provided for @clothShorts.
  ///
  /// In en, this message translates to:
  /// **'Shorts & T-shirt'**
  String get clothShorts;

  /// No description provided for @clothLongTee.
  ///
  /// In en, this message translates to:
  /// **'Shorts & long sleeve'**
  String get clothLongTee;

  /// No description provided for @clothTights.
  ///
  /// In en, this message translates to:
  /// **'Tights & long sleeve, light gloves'**
  String get clothTights;

  /// No description provided for @clothJacket.
  ///
  /// In en, this message translates to:
  /// **'Tights, thermal top & light jacket, hat'**
  String get clothJacket;

  /// No description provided for @clothWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter tights, layers, gloves & hat'**
  String get clothWinter;

  /// No description provided for @hintStorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm – train indoors today'**
  String get hintStorm;

  /// No description provided for @hintRainAt.
  ///
  /// In en, this message translates to:
  /// **'Rain from {time} – go before'**
  String hintRainAt(String time);

  /// No description provided for @hintHot.
  ///
  /// In en, this message translates to:
  /// **'Hot – go early, drink more'**
  String get hintHot;

  /// No description provided for @hintCold.
  ///
  /// In en, this message translates to:
  /// **'Cold – warm up indoors first'**
  String get hintCold;

  /// No description provided for @hintBest.
  ///
  /// In en, this message translates to:
  /// **'Best time to train: {time}'**
  String hintBest(String time);

  /// No description provided for @hintIndoor.
  ///
  /// In en, this message translates to:
  /// **'So-so outside – good day for gym'**
  String get hintIndoor;

  /// No description provided for @bestTrainingWindow.
  ///
  /// In en, this message translates to:
  /// **'Best training window'**
  String get bestTrainingWindow;

  /// No description provided for @rainChanceN.
  ///
  /// In en, this message translates to:
  /// **'{pct}% rain'**
  String rainChanceN(int pct);

  /// No description provided for @next24h.
  ///
  /// In en, this message translates to:
  /// **'Next 24 hours'**
  String get next24h;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @trainingScoreLegend.
  ///
  /// In en, this message translates to:
  /// **'Bar = conditions for outdoor training'**
  String get trainingScoreLegend;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @uvIndex.
  ///
  /// In en, this message translates to:
  /// **'UV index'**
  String get uvIndex;

  /// No description provided for @uvHigh.
  ///
  /// In en, this message translates to:
  /// **'High – use sunscreen'**
  String get uvHigh;

  /// No description provided for @uvModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get uvModerate;

  /// No description provided for @uvLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get uvLow;

  /// No description provided for @airQuality.
  ///
  /// In en, this message translates to:
  /// **'Air quality'**
  String get airQuality;

  /// No description provided for @aqiGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get aqiGood;

  /// No description provided for @aqiModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get aqiModerate;

  /// No description provided for @aqiPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor – go easy'**
  String get aqiPoor;

  /// No description provided for @sunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get sunrise;

  /// No description provided for @sunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sunset;

  /// No description provided for @whatToWear.
  ///
  /// In en, this message translates to:
  /// **'What to wear for a run'**
  String get whatToWear;

  /// No description provided for @wearSunscreen.
  ///
  /// In en, this message translates to:
  /// **'Sunscreen & cap'**
  String get wearSunscreen;

  /// No description provided for @wearRainJacket.
  ///
  /// In en, this message translates to:
  /// **'Pack a rain jacket'**
  String get wearRainJacket;

  /// No description provided for @wearWindproof.
  ///
  /// In en, this message translates to:
  /// **'Windproof layer'**
  String get wearWindproof;

  /// No description provided for @drinkMore.
  ///
  /// In en, this message translates to:
  /// **'Drink extra'**
  String get drinkMore;

  /// No description provided for @wearReflective.
  ///
  /// In en, this message translates to:
  /// **'Reflective gear / headlamp'**
  String get wearReflective;

  /// No description provided for @next7Days.
  ///
  /// In en, this message translates to:
  /// **'7-day forecast'**
  String get next7Days;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @weatherSource.
  ///
  /// In en, this message translates to:
  /// **'Weather data: Open-Meteo.com'**
  String get weatherSource;

  /// No description provided for @stepWarmupNote.
  ///
  /// In en, this message translates to:
  /// **'Easy jog, get loose'**
  String get stepWarmupNote;

  /// No description provided for @stepEasyNote.
  ///
  /// In en, this message translates to:
  /// **'Conversational pace – you can talk in full sentences'**
  String get stepEasyNote;

  /// No description provided for @stepMpNote.
  ///
  /// In en, this message translates to:
  /// **'Goal marathon pace – controlled'**
  String get stepMpNote;

  /// No description provided for @stepTempoNote.
  ///
  /// In en, this message translates to:
  /// **'Comfortably hard – a few words only'**
  String get stepTempoNote;

  /// No description provided for @stepFartlekNote.
  ///
  /// In en, this message translates to:
  /// **'Pick it up – strong but relaxed'**
  String get stepFartlekNote;

  /// No description provided for @stepIntervalNote.
  ///
  /// In en, this message translates to:
  /// **'Hard – 3–5k race effort'**
  String get stepIntervalNote;

  /// No description provided for @stepStrideNote.
  ///
  /// In en, this message translates to:
  /// **'Fast and relaxed, not a sprint'**
  String get stepStrideNote;

  /// No description provided for @stepBriskWalk.
  ///
  /// In en, this message translates to:
  /// **'Brisk walk'**
  String get stepBriskWalk;

  /// No description provided for @stepTalkPace.
  ///
  /// In en, this message translates to:
  /// **'Very easy jog – you could chat'**
  String get stepTalkPace;

  /// No description provided for @stepZ2RideNote.
  ///
  /// In en, this message translates to:
  /// **'Zone 2 – steady, you can talk'**
  String get stepZ2RideNote;

  /// No description provided for @stepVo2Note.
  ///
  /// In en, this message translates to:
  /// **'Very hard – 106–120 % FTP'**
  String get stepVo2Note;

  /// No description provided for @stepSsNote.
  ///
  /// In en, this message translates to:
  /// **'Sweet spot – 88–94 % FTP'**
  String get stepSsNote;

  /// No description provided for @stepThresholdNote.
  ///
  /// In en, this message translates to:
  /// **'Threshold – 95–105 % FTP'**
  String get stepThresholdNote;

  /// No description provided for @stepSwimWu.
  ///
  /// In en, this message translates to:
  /// **'Easy, mixed strokes'**
  String get stepSwimWu;

  /// No description provided for @stepDrills.
  ///
  /// In en, this message translates to:
  /// **'Drills: catch-up, fist, 6-kick switch'**
  String get stepDrills;

  /// No description provided for @stepCssNote.
  ///
  /// In en, this message translates to:
  /// **'At CSS pace – even splits'**
  String get stepCssNote;

  /// No description provided for @stepSwimEasyNote.
  ///
  /// In en, this message translates to:
  /// **'Relaxed, focus on long strokes'**
  String get stepSwimEasyNote;

  /// No description provided for @stepSwimEnNote.
  ///
  /// In en, this message translates to:
  /// **'Steady aerobic pace'**
  String get stepSwimEnNote;

  /// No description provided for @wLongRunDesc.
  ///
  /// In en, this message translates to:
  /// **'Builds aerobic endurance and fat metabolism. Keep it easy – time on feet matters, not pace.'**
  String get wLongRunDesc;

  /// No description provided for @wLongRunMp.
  ///
  /// In en, this message translates to:
  /// **'Long run with race pace'**
  String get wLongRunMp;

  /// No description provided for @wLongRunMpDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy long run, finishing the last quarter at goal race pace – the key race-specific session.'**
  String get wLongRunMpDesc;

  /// No description provided for @wTempoDesc.
  ///
  /// In en, this message translates to:
  /// **'Threshold run: raises the pace you can hold for an hour.'**
  String get wTempoDesc;

  /// No description provided for @wFartlek.
  ///
  /// In en, this message translates to:
  /// **'Fartlek'**
  String get wFartlek;

  /// No description provided for @wFartlekDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy run with short, playful surges – builds speed without much fatigue.'**
  String get wFartlekDesc;

  /// No description provided for @wIntervals.
  ///
  /// In en, this message translates to:
  /// **'Intervals {reps} × {meters} m'**
  String wIntervals(int reps, int meters);

  /// No description provided for @wIntervalsDesc.
  ///
  /// In en, this message translates to:
  /// **'VO2max intervals at 3–5k race effort. Recovery jog between reps.'**
  String get wIntervalsDesc;

  /// No description provided for @wMpRun.
  ///
  /// In en, this message translates to:
  /// **'Marathon-pace run'**
  String get wMpRun;

  /// No description provided for @wMpRunDesc.
  ///
  /// In en, this message translates to:
  /// **'Continuous block at goal marathon pace to lock in the rhythm.'**
  String get wMpRunDesc;

  /// No description provided for @wCruise.
  ///
  /// In en, this message translates to:
  /// **'Cruise intervals {reps} × 1.6 km'**
  String wCruise(int reps);

  /// No description provided for @wCruiseDesc.
  ///
  /// In en, this message translates to:
  /// **'Threshold pace with short jogs – more time at threshold with less strain (Daniels).'**
  String get wCruiseDesc;

  /// No description provided for @wEasyStrides.
  ///
  /// In en, this message translates to:
  /// **'Easy run + strides'**
  String get wEasyStrides;

  /// No description provided for @wEasyStridesDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy run, then short relaxed strides for running economy.'**
  String get wEasyStridesDesc;

  /// No description provided for @wRecoveryRun.
  ///
  /// In en, this message translates to:
  /// **'Recovery run'**
  String get wRecoveryRun;

  /// No description provided for @wEasyDesc.
  ///
  /// In en, this message translates to:
  /// **'Most of your running should feel like this – easy volume builds the engine.'**
  String get wEasyDesc;

  /// No description provided for @wRunWalk.
  ///
  /// In en, this message translates to:
  /// **'Run/walk {n} × {min} min'**
  String wRunWalk(int n, int min);

  /// No description provided for @wRunWalkDesc.
  ///
  /// In en, this message translates to:
  /// **'Alternate easy jogging and walking. Repeat the week if it felt hard.'**
  String get wRunWalkDesc;

  /// No description provided for @wLongRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Long Zone 2 ride – the backbone of cycling endurance. Eat and drink every 20–30 min.'**
  String get wLongRideDesc;

  /// No description provided for @wRideVo2.
  ///
  /// In en, this message translates to:
  /// **'VO2max {reps} × {min} min'**
  String wRideVo2(int reps, int min);

  /// No description provided for @wRideVo2Desc.
  ///
  /// In en, this message translates to:
  /// **'Hard intervals with equal recovery – raises your ceiling.'**
  String get wRideVo2Desc;

  /// No description provided for @wSweetSpot.
  ///
  /// In en, this message translates to:
  /// **'Sweet spot {reps} × {each} min'**
  String wSweetSpot(int reps, int each);

  /// No description provided for @wSweetSpotDesc.
  ///
  /// In en, this message translates to:
  /// **'Just below threshold – very time-efficient FTP builder.'**
  String get wSweetSpotDesc;

  /// No description provided for @wThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold {reps} × {each} min'**
  String wThreshold(int reps, int each);

  /// No description provided for @wThresholdDesc.
  ///
  /// In en, this message translates to:
  /// **'At FTP – the power you can hold for about an hour.'**
  String get wThresholdDesc;

  /// No description provided for @wRecoveryRide.
  ///
  /// In en, this message translates to:
  /// **'Recovery ride'**
  String get wRecoveryRide;

  /// No description provided for @wEasyRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy endurance ride, steady cadence 85–95 rpm.'**
  String get wEasyRideDesc;

  /// No description provided for @wSwimCss.
  ///
  /// In en, this message translates to:
  /// **'CSS set {n} × 100 m'**
  String wSwimCss(int n);

  /// No description provided for @wSwimCssDesc.
  ///
  /// In en, this message translates to:
  /// **'Threshold swim at critical swim speed with short rests.'**
  String get wSwimCssDesc;

  /// No description provided for @wSwimTechDesc.
  ///
  /// In en, this message translates to:
  /// **'Technique first: drills, then relaxed repeats with good form.'**
  String get wSwimTechDesc;

  /// No description provided for @wSwimEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance {reps} × {meters} m'**
  String wSwimEndurance(int reps, int meters);

  /// No description provided for @wSwimEnduranceDesc.
  ///
  /// In en, this message translates to:
  /// **'Aerobic swim set – steady pace, short rests.'**
  String get wSwimEnduranceDesc;

  /// No description provided for @wGymDesc.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets × {lo}–{hi} reps, stop with {rir} reps in reserve. Add weight once you reach {hi} reps on all sets.'**
  String wGymDesc(int sets, int lo, int hi, int rir);

  /// No description provided for @wGymDeloadDesc.
  ///
  /// In en, this message translates to:
  /// **'Deload: {sets} sets per exercise, about 10 % lighter, nothing near failure.'**
  String wGymDeloadDesc(int sets);

  /// No description provided for @wGymConcurrentNote.
  ///
  /// In en, this message translates to:
  /// **'Key endurance session tomorrow – upper body focus, keep legs light.'**
  String get wGymConcurrentNote;

  /// No description provided for @setupModeTitle.
  ///
  /// In en, this message translates to:
  /// **'How detailed should we get?'**
  String get setupModeTitle;

  /// No description provided for @setupQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick start · ~2 min'**
  String get setupQuick;

  /// No description provided for @setupQuickSub.
  ///
  /// In en, this message translates to:
  /// **'A few general questions. Your plan adapts as you log workouts.'**
  String get setupQuickSub;

  /// No description provided for @setupDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed · ~6 min'**
  String get setupDetailed;

  /// No description provided for @setupDetailedSub.
  ///
  /// In en, this message translates to:
  /// **'Race times, weekly volume, FTP, swim test, max lifts and a weekday plan – for a precise plan from day one.'**
  String get setupDetailedSub;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @heartRateOptional.
  ///
  /// In en, this message translates to:
  /// **'Heart rate (optional)'**
  String get heartRateOptional;

  /// No description provided for @heartRateHint.
  ///
  /// In en, this message translates to:
  /// **'Resting HR: measured in bed after waking. Leave max HR empty to estimate it (208 − 0.7 × age).'**
  String get heartRateHint;

  /// No description provided for @restingHr.
  ///
  /// In en, this message translates to:
  /// **'Resting HR'**
  String get restingHr;

  /// No description provided for @maxHr.
  ///
  /// In en, this message translates to:
  /// **'Max HR'**
  String get maxHr;

  /// No description provided for @sessionLength.
  ///
  /// In en, this message translates to:
  /// **'Time per session'**
  String get sessionLength;

  /// No description provided for @weekPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Your training week'**
  String get weekPlanTitle;

  /// No description provided for @weekPlanSub.
  ///
  /// In en, this message translates to:
  /// **'Tap which sport you want to do on which day. Your plan follows this structure.'**
  String get weekPlanSub;

  /// No description provided for @oncePerDay.
  ///
  /// In en, this message translates to:
  /// **'1× per day'**
  String get oncePerDay;

  /// No description provided for @twicePerDay.
  ///
  /// In en, this message translates to:
  /// **'Up to 2× per day'**
  String get twicePerDay;

  /// No description provided for @sessionsPerWeekN.
  ///
  /// In en, this message translates to:
  /// **'{n} sessions / week'**
  String sessionsPerWeekN(int n);

  /// No description provided for @longDayHint.
  ///
  /// In en, this message translates to:
  /// **'★ = day for your long session'**
  String get longDayHint;

  /// No description provided for @noRestDayWarning.
  ///
  /// In en, this message translates to:
  /// **'No rest day – at least one easy or rest day per week is recommended.'**
  String get noRestDayWarning;

  /// No description provided for @preferredTime.
  ///
  /// In en, this message translates to:
  /// **'Preferred training time'**
  String get preferredTime;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @midday.
  ///
  /// In en, this message translates to:
  /// **'Midday'**
  String get midday;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @runSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get runSetupTitle;

  /// No description provided for @runSetupSub.
  ///
  /// In en, this message translates to:
  /// **'Your current running fitness – this sets your pace zones and safe progression.'**
  String get runSetupSub;

  /// No description provided for @canRun30.
  ///
  /// In en, this message translates to:
  /// **'I can run 30 min without stopping'**
  String get canRun30;

  /// No description provided for @canRun30Sub.
  ///
  /// In en, this message translates to:
  /// **'If not, we start with a run/walk program.'**
  String get canRun30Sub;

  /// No description provided for @raceTimesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent best times (optional)'**
  String get raceTimesTitle;

  /// No description provided for @raceTimesHint.
  ///
  /// In en, this message translates to:
  /// **'From the last ~6 months. One is enough – we calculate your VDOT (Daniels).'**
  String get raceTimesHint;

  /// No description provided for @currentVolume.
  ///
  /// In en, this message translates to:
  /// **'Current training volume'**
  String get currentVolume;

  /// No description provided for @weeklyKmNow.
  ///
  /// In en, this message translates to:
  /// **'Running km per week'**
  String get weeklyKmNow;

  /// No description provided for @longestRun4w.
  ///
  /// In en, this message translates to:
  /// **'Longest run (last 4 weeks)'**
  String get longestRun4w;

  /// No description provided for @notSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSure;

  /// No description provided for @rideSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get rideSetupTitle;

  /// No description provided for @rideSetupSub.
  ///
  /// In en, this message translates to:
  /// **'Power or heart rate – we set your zones accordingly.'**
  String get rideSetupSub;

  /// No description provided for @hasPowerMeter.
  ///
  /// In en, this message translates to:
  /// **'I have a power meter / smart trainer'**
  String get hasPowerMeter;

  /// No description provided for @hasIndoorTrainer.
  ///
  /// In en, this message translates to:
  /// **'I can ride indoors (trainer / rollers)'**
  String get hasIndoorTrainer;

  /// No description provided for @ftpTitle.
  ///
  /// In en, this message translates to:
  /// **'FTP (optional)'**
  String get ftpTitle;

  /// No description provided for @ftpHint.
  ///
  /// In en, this message translates to:
  /// **'Functional threshold power: 95 % of a 20-min all-out test.'**
  String get ftpHint;

  /// No description provided for @weeklyHoursNow.
  ///
  /// In en, this message translates to:
  /// **'Cycling hours per week'**
  String get weeklyHoursNow;

  /// No description provided for @longestRide4w.
  ///
  /// In en, this message translates to:
  /// **'Longest ride (last 4 weeks)'**
  String get longestRide4w;

  /// No description provided for @swimSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get swimSetupTitle;

  /// No description provided for @swimSetupSub.
  ///
  /// In en, this message translates to:
  /// **'A quick test gives your critical swim speed (CSS) for pace targets.'**
  String get swimSetupSub;

  /// No description provided for @canSwim400.
  ///
  /// In en, this message translates to:
  /// **'I can swim 400 m freestyle without stopping'**
  String get canSwim400;

  /// No description provided for @cssTitle.
  ///
  /// In en, this message translates to:
  /// **'CSS test (optional)'**
  String get cssTitle;

  /// No description provided for @cssHint.
  ///
  /// In en, this message translates to:
  /// **'All-out 400 m, rest, then all-out 200 m.'**
  String get cssHint;

  /// No description provided for @cssResult.
  ///
  /// In en, this message translates to:
  /// **'Your CSS: {pace} /100 m'**
  String cssResult(String pace);

  /// No description provided for @weeklySwimKm.
  ///
  /// In en, this message translates to:
  /// **'Swim km per week'**
  String get weeklySwimKm;

  /// No description provided for @gymSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Strength training'**
  String get gymSetupTitle;

  /// No description provided for @gymSetupSub.
  ///
  /// In en, this message translates to:
  /// **'Equipment and goal decide exercises, rep ranges and progression.'**
  String get gymSetupSub;

  /// No description provided for @equipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do you train?'**
  String get equipmentTitle;

  /// No description provided for @equipGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get equipGym;

  /// No description provided for @equipGymSub.
  ///
  /// In en, this message translates to:
  /// **'Barbells, machines, cables'**
  String get equipGymSub;

  /// No description provided for @equipHome.
  ///
  /// In en, this message translates to:
  /// **'Home gym'**
  String get equipHome;

  /// No description provided for @equipHomeSub.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells, bench, maybe a rack'**
  String get equipHomeSub;

  /// No description provided for @equipBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get equipBodyweight;

  /// No description provided for @equipBodyweightSub.
  ///
  /// In en, this message translates to:
  /// **'No equipment, maybe bands'**
  String get equipBodyweightSub;

  /// No description provided for @gymGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Strength goal'**
  String get gymGoalTitle;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @oneRmTitle.
  ///
  /// In en, this message translates to:
  /// **'Max lifts (optional)'**
  String get oneRmTitle;

  /// No description provided for @oneRmHint.
  ///
  /// In en, this message translates to:
  /// **'1-rep max or a good estimate – used for starting weights.'**
  String get oneRmHint;

  /// No description provided for @liftSquat.
  ///
  /// In en, this message translates to:
  /// **'Squat'**
  String get liftSquat;

  /// No description provided for @liftBench.
  ///
  /// In en, this message translates to:
  /// **'Bench press'**
  String get liftBench;

  /// No description provided for @liftDeadlift.
  ///
  /// In en, this message translates to:
  /// **'Deadlift'**
  String get liftDeadlift;

  /// No description provided for @liftOhp.
  ///
  /// In en, this message translates to:
  /// **'Overhead press'**
  String get liftOhp;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Anything to consider?'**
  String get healthTitle;

  /// No description provided for @healthSub.
  ///
  /// In en, this message translates to:
  /// **'We avoid risky progressions for affected areas.'**
  String get healthSub;

  /// No description provided for @limitKnee.
  ///
  /// In en, this message translates to:
  /// **'Knee'**
  String get limitKnee;

  /// No description provided for @limitBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get limitBack;

  /// No description provided for @limitShoulder.
  ///
  /// In en, this message translates to:
  /// **'Shoulder'**
  String get limitShoulder;

  /// No description provided for @limitHip.
  ///
  /// In en, this message translates to:
  /// **'Hip'**
  String get limitHip;

  /// No description provided for @limitAnkle.
  ///
  /// In en, this message translates to:
  /// **'Ankle / Achilles'**
  String get limitAnkle;

  /// No description provided for @limitHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart / blood pressure'**
  String get limitHeart;

  /// No description provided for @healthDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Strive does not replace medical advice. With pain or health conditions, talk to a doctor first.'**
  String get healthDisclaimer;

  /// No description provided for @olympicTri.
  ///
  /// In en, this message translates to:
  /// **'Olympic triathlon'**
  String get olympicTri;

  /// No description provided for @targetTime.
  ///
  /// In en, this message translates to:
  /// **'Target time'**
  String get targetTime;

  /// No description provided for @targetTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Optional – leave empty to just finish strong.'**
  String get targetTimeHint;

  /// No description provided for @predictedTime.
  ///
  /// In en, this message translates to:
  /// **'Predicted from your current form: {time}'**
  String predictedTime(String time);

  /// No description provided for @planSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get planSetupTitle;

  /// No description provided for @planSetupSub.
  ///
  /// In en, this message translates to:
  /// **'How hard and how long? Based on sports-science guidelines.'**
  String get planSetupSub;

  /// No description provided for @difficultyTitle.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficultyTitle;

  /// No description provided for @difficultyHint.
  ///
  /// In en, this message translates to:
  /// **'Compared to what you do now.'**
  String get difficultyHint;

  /// No description provided for @diffEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get diffEasy;

  /// No description provided for @diffEasySub.
  ///
  /// In en, this message translates to:
  /// **'+5 % volume/week, recovery every 3rd week, mostly easy sessions.'**
  String get diffEasySub;

  /// No description provided for @diffBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get diffBalanced;

  /// No description provided for @diffBalancedSub.
  ///
  /// In en, this message translates to:
  /// **'+8 % volume/week, recovery every 4th week, ~80/20 easy/hard.'**
  String get diffBalancedSub;

  /// No description provided for @diffChallenging.
  ///
  /// In en, this message translates to:
  /// **'Challenging'**
  String get diffChallenging;

  /// No description provided for @diffChallengingSub.
  ///
  /// In en, this message translates to:
  /// **'+10 % volume/week, more quality sessions – for experienced athletes.'**
  String get diffChallengingSub;

  /// No description provided for @planLength.
  ///
  /// In en, this message translates to:
  /// **'Plan length'**
  String get planLength;

  /// No description provided for @plan4w.
  ///
  /// In en, this message translates to:
  /// **'4 weeks · quick boost'**
  String get plan4w;

  /// No description provided for @plan8w.
  ///
  /// In en, this message translates to:
  /// **'8 weeks'**
  String get plan8w;

  /// No description provided for @plan12w.
  ///
  /// In en, this message translates to:
  /// **'12 weeks'**
  String get plan12w;

  /// No description provided for @plan16w.
  ///
  /// In en, this message translates to:
  /// **'16 weeks'**
  String get plan16w;

  /// No description provided for @plan20w.
  ///
  /// In en, this message translates to:
  /// **'20 weeks · max. build-up'**
  String get plan20w;

  /// No description provided for @planLengthHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended for your goal: {lo}–{hi} weeks (👍).'**
  String planLengthHint(int lo, int hi);

  /// No description provided for @planToEvent.
  ///
  /// In en, this message translates to:
  /// **'Your plan runs {weeks} weeks until race day, including taper.'**
  String planToEvent(int weeks);

  /// No description provided for @planToEventShort.
  ///
  /// In en, this message translates to:
  /// **'Only {weeks} weeks to race day – {lo}+ are recommended. We focus on arriving fit rather than a time goal.'**
  String planToEventShort(int weeks, int lo);

  /// No description provided for @planScienceNote.
  ///
  /// In en, this message translates to:
  /// **'Plans follow e.g. Seiler (80/20), Daniels (VDOT paces), Bosquet (taper), Schoenfeld (strength volume). Details in the plan view.'**
  String get planScienceNote;

  /// No description provided for @yourPaceZones.
  ///
  /// In en, this message translates to:
  /// **'Your pace zones'**
  String get yourPaceZones;

  /// No description provided for @zoneEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy / long'**
  String get zoneEasy;

  /// No description provided for @zoneMarathon.
  ///
  /// In en, this message translates to:
  /// **'Marathon'**
  String get zoneMarathon;

  /// No description provided for @zoneThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get zoneThreshold;

  /// No description provided for @zoneInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get zoneInterval;

  /// No description provided for @zoneRepetition.
  ///
  /// In en, this message translates to:
  /// **'Repetition'**
  String get zoneRepetition;

  /// No description provided for @hcTileSub.
  ///
  /// In en, this message translates to:
  /// **'Galaxy Watch, Samsung Health, Garmin & more'**
  String get hcTileSub;

  /// No description provided for @hcConnectedShort.
  ///
  /// In en, this message translates to:
  /// **'Connected – syncing automatically'**
  String get hcConnectedShort;

  /// No description provided for @hcTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your Galaxy Watch'**
  String get hcTitle;

  /// No description provided for @hcSub.
  ///
  /// In en, this message translates to:
  /// **'Your watch syncs to Samsung Health, Samsung Health shares with Health Connect, and Strive reads your workouts, heart rate, sleep and steps – and writes your Strive workouts back.'**
  String get hcSub;

  /// No description provided for @hcUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is not available on this device.'**
  String get hcUnavailable;

  /// No description provided for @hcInstall.
  ///
  /// In en, this message translates to:
  /// **'Health Connect needs to be installed or updated first.'**
  String get hcInstall;

  /// No description provided for @hcInstallButton.
  ///
  /// In en, this message translates to:
  /// **'Install Health Connect'**
  String get hcInstallButton;

  /// No description provided for @hcConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Health Connect'**
  String get hcConnect;

  /// No description provided for @hcConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected!'**
  String get hcConnected;

  /// No description provided for @hcDenied.
  ///
  /// In en, this message translates to:
  /// **'Permissions were not granted.'**
  String get hcDenied;

  /// No description provided for @hcImported.
  ///
  /// In en, this message translates to:
  /// **'{n} new workouts imported'**
  String hcImported(int n);

  /// No description provided for @hcConnectedInfo.
  ///
  /// In en, this message translates to:
  /// **'Connected. New watch workouts appear in your history automatically.'**
  String get hcConnectedInfo;

  /// No description provided for @hcImportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get hcImportedLabel;

  /// No description provided for @hcLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get hcLastSync;

  /// No description provided for @hcSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get hcSyncNow;

  /// No description provided for @hcDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get hcDisconnect;

  /// No description provided for @hcSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your Galaxy Watch 6'**
  String get hcSetupTitle;

  /// No description provided for @hcStep1.
  ///
  /// In en, this message translates to:
  /// **'Pair the watch with the Galaxy Wearable app and sign in to Samsung Health.'**
  String get hcStep1;

  /// No description provided for @hcStep2.
  ///
  /// In en, this message translates to:
  /// **'In Samsung Health: ⋮ → Settings → Health Connect → allow all data types to be shared.'**
  String get hcStep2;

  /// No description provided for @hcStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Connect\" above and allow Strive to read and write.'**
  String get hcStep3;

  /// No description provided for @hcStep4.
  ///
  /// In en, this message translates to:
  /// **'Record workouts on the watch as usual – Strive imports them on the next app start.'**
  String get hcStep4;

  /// No description provided for @hcOpenSamsung.
  ///
  /// In en, this message translates to:
  /// **'Open Samsung Health'**
  String get hcOpenSamsung;

  /// No description provided for @hcWhatSynced.
  ///
  /// In en, this message translates to:
  /// **'What is synced?'**
  String get hcWhatSynced;

  /// No description provided for @hcWhatSyncedBody.
  ///
  /// In en, this message translates to:
  /// **'Read: workouts (run, ride, swim, strength) incl. avg/max heart rate, distance and calories, resting heart rate, HRV, sleep, steps, weight, body fat. Write: Strive workouts and weight entries.'**
  String get hcWhatSyncedBody;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @linkGoogle.
  ///
  /// In en, this message translates to:
  /// **'Link Google account'**
  String get linkGoogle;

  /// No description provided for @guidedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Guided workout'**
  String get guidedWorkout;

  /// No description provided for @guidedWorkoutSub.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step targets with voice cues'**
  String get guidedWorkoutSub;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @voiceCues.
  ///
  /// In en, this message translates to:
  /// **'Voice cues'**
  String get voiceCues;

  /// No description provided for @lockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get lockScreen;

  /// No description provided for @skipStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get skipStep;

  /// No description provided for @autoPaused.
  ///
  /// In en, this message translates to:
  /// **'AUTO-PAUSED'**
  String get autoPaused;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get paused;

  /// No description provided for @currentPace.
  ///
  /// In en, this message translates to:
  /// **'Current pace'**
  String get currentPace;

  /// No description provided for @currentSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get currentSpeed;

  /// No description provided for @allStepsDone.
  ///
  /// In en, this message translates to:
  /// **'All steps done! Cool down and finish when ready.'**
  String get allStepsDone;

  /// No description provided for @onPace.
  ///
  /// In en, this message translates to:
  /// **'On target'**
  String get onPace;

  /// No description provided for @tooFast.
  ///
  /// In en, this message translates to:
  /// **'Too fast'**
  String get tooFast;

  /// No description provided for @tooSlow.
  ///
  /// In en, this message translates to:
  /// **'Too slow'**
  String get tooSlow;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get left;

  /// No description provided for @freeRunHint.
  ///
  /// In en, this message translates to:
  /// **'Easy run? Stay at {lo}–{hi} bpm (Zone 2) – you should be able to talk in full sentences.'**
  String freeRunHint(int lo, int hi);

  /// No description provided for @workoutStructure.
  ///
  /// In en, this message translates to:
  /// **'Workout structure'**
  String get workoutStructure;

  /// No description provided for @noSplitsYet.
  ///
  /// In en, this message translates to:
  /// **'Splits appear after the first kilometer.'**
  String get noSplitsYet;

  /// No description provided for @holdToFinish.
  ///
  /// In en, this message translates to:
  /// **'Hold to finish'**
  String get holdToFinish;

  /// No description provided for @holdToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Hold to unlock'**
  String get holdToUnlock;

  /// No description provided for @musicSub.
  ///
  /// In en, this message translates to:
  /// **'Opens Spotify with music matching your workout tempo.'**
  String get musicSub;

  /// No description provided for @musicForNow.
  ///
  /// In en, this message translates to:
  /// **'Right now: {label}'**
  String musicForNow(String label);

  /// No description provided for @musicEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy run'**
  String get musicEasy;

  /// No description provided for @musicTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo run'**
  String get musicTempo;

  /// No description provided for @musicIntervals.
  ///
  /// In en, this message translates to:
  /// **'Intervals'**
  String get musicIntervals;

  /// No description provided for @musicPodcasts.
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get musicPodcasts;

  /// No description provided for @musicPodcastsSub.
  ///
  /// In en, this message translates to:
  /// **'Great for long easy runs'**
  String get musicPodcastsSub;

  /// No description provided for @musicOwn.
  ///
  /// In en, this message translates to:
  /// **'My playlist'**
  String get musicOwn;

  /// No description provided for @musicSetOwn.
  ///
  /// In en, this message translates to:
  /// **'Set my Spotify playlist link'**
  String get musicSetOwn;

  /// No description provided for @musicChangeOwn.
  ///
  /// In en, this message translates to:
  /// **'Change my playlist'**
  String get musicChangeOwn;

  /// No description provided for @vcGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get vcGo;

  /// No description provided for @vcAutoPaused.
  ///
  /// In en, this message translates to:
  /// **'Auto pause.'**
  String get vcAutoPaused;

  /// No description provided for @vcResumed.
  ///
  /// In en, this message translates to:
  /// **'Resumed.'**
  String get vcResumed;

  /// No description provided for @vcAllDone.
  ///
  /// In en, this message translates to:
  /// **'All steps done. Great work! Cool down easy.'**
  String get vcAllDone;

  /// No description provided for @vcSlowDown.
  ///
  /// In en, this message translates to:
  /// **'A bit slower – stay in your zone.'**
  String get vcSlowDown;

  /// No description provided for @vcSpeedUp.
  ///
  /// In en, this message translates to:
  /// **'Pick it up a little.'**
  String get vcSpeedUp;

  /// No description provided for @vcKm.
  ///
  /// In en, this message translates to:
  /// **'Kilometer {n}. Time {time}. Last kilometer {pace}.'**
  String vcKm(int n, String time, String pace);

  /// No description provided for @zConversational.
  ///
  /// In en, this message translates to:
  /// **'conversational pace'**
  String get zConversational;

  /// No description provided for @zEasyLong.
  ///
  /// In en, this message translates to:
  /// **'easy'**
  String get zEasyLong;

  /// No description provided for @zMarathon.
  ///
  /// In en, this message translates to:
  /// **'marathon pace'**
  String get zMarathon;

  /// No description provided for @zThreshold.
  ///
  /// In en, this message translates to:
  /// **'threshold pace'**
  String get zThreshold;

  /// No description provided for @zInterval.
  ///
  /// In en, this message translates to:
  /// **'interval pace'**
  String get zInterval;

  /// No description provided for @zStride.
  ///
  /// In en, this message translates to:
  /// **'stride'**
  String get zStride;

  /// No description provided for @zJog.
  ///
  /// In en, this message translates to:
  /// **'easy jog'**
  String get zJog;

  /// No description provided for @zWalk.
  ///
  /// In en, this message translates to:
  /// **'walk'**
  String get zWalk;

  /// No description provided for @zRecovery.
  ///
  /// In en, this message translates to:
  /// **'recovery'**
  String get zRecovery;

  /// No description provided for @zSprint.
  ///
  /// In en, this message translates to:
  /// **'sprint'**
  String get zSprint;

  /// No description provided for @zSwimEndurance.
  ///
  /// In en, this message translates to:
  /// **'endurance'**
  String get zSwimEndurance;

  /// No description provided for @zDrills.
  ///
  /// In en, this message translates to:
  /// **'drills'**
  String get zDrills;

  /// No description provided for @stepWarmup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get stepWarmup;

  /// No description provided for @stepCooldown.
  ///
  /// In en, this message translates to:
  /// **'Cool-down'**
  String get stepCooldown;

  /// No description provided for @stepRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get stepRecovery;

  /// No description provided for @stepWorkN.
  ///
  /// In en, this message translates to:
  /// **'Interval {x}/{y}'**
  String stepWorkN(int x, int y);

  /// No description provided for @stepWork.
  ///
  /// In en, this message translates to:
  /// **'Main set'**
  String get stepWork;

  /// No description provided for @stepSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get stepSteady;

  /// No description provided for @phaseBase.
  ///
  /// In en, this message translates to:
  /// **'Base phase'**
  String get phaseBase;

  /// No description provided for @phaseBuild.
  ///
  /// In en, this message translates to:
  /// **'Build phase'**
  String get phaseBuild;

  /// No description provided for @phasePeak.
  ///
  /// In en, this message translates to:
  /// **'Peak phase'**
  String get phasePeak;

  /// No description provided for @phaseTaper.
  ///
  /// In en, this message translates to:
  /// **'Taper'**
  String get phaseTaper;

  /// No description provided for @phaseRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery week'**
  String get phaseRecovery;

  /// No description provided for @keySession.
  ///
  /// In en, this message translates to:
  /// **'Key session'**
  String get keySession;

  /// No description provided for @viewSession.
  ///
  /// In en, this message translates to:
  /// **'View workout'**
  String get viewSession;

  /// No description provided for @fitnessForm.
  ///
  /// In en, this message translates to:
  /// **'Fitness & form'**
  String get fitnessForm;

  /// No description provided for @fitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get fitness;

  /// No description provided for @fatigue.
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get fatigue;

  /// No description provided for @form.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get form;

  /// No description provided for @formFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh – ready for a race or hard session'**
  String get formFresh;

  /// No description provided for @formNeutral.
  ///
  /// In en, this message translates to:
  /// **'Balanced – maintaining'**
  String get formNeutral;

  /// No description provided for @formProductive.
  ///
  /// In en, this message translates to:
  /// **'Productive training – fitness is building'**
  String get formProductive;

  /// No description provided for @formOverload.
  ///
  /// In en, this message translates to:
  /// **'High fatigue – plan recovery'**
  String get formOverload;

  /// No description provided for @fitnessFormHint.
  ///
  /// In en, this message translates to:
  /// **'Fitness = 42-day training load, fatigue = 7-day load, form = difference (Banister model).'**
  String get fitnessFormHint;

  /// No description provided for @bestEfforts.
  ///
  /// In en, this message translates to:
  /// **'Running best efforts'**
  String get bestEfforts;

  /// No description provided for @racePredictions.
  ///
  /// In en, this message translates to:
  /// **'Race predictions'**
  String get racePredictions;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @middleDistance.
  ///
  /// In en, this message translates to:
  /// **'Middle distance (70.3)'**
  String get middleDistance;

  /// No description provided for @maxReps.
  ///
  /// In en, this message translates to:
  /// **'Max reps'**
  String get maxReps;

  /// No description provided for @roundLap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get roundLap;

  /// No description provided for @linkGoogleSub.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google next time – your data stays'**
  String get linkGoogleSub;

  /// No description provided for @wGymTimeCapNote.
  ///
  /// In en, this message translates to:
  /// **'Only {min} min available: do one set less per exercise or skip the last exercise.'**
  String wGymTimeCapNote(int min);

  /// No description provided for @wShakeout.
  ///
  /// In en, this message translates to:
  /// **'Shake-out run'**
  String get wShakeout;

  /// No description provided for @wShakeoutDesc.
  ///
  /// In en, this message translates to:
  /// **'15 min very easy plus a few strides – loosen up, nothing more. Prepare your race kit tonight.'**
  String get wShakeoutDesc;

  /// No description provided for @wRace.
  ///
  /// In en, this message translates to:
  /// **'Race: {name}'**
  String wRace(String name);

  /// No description provided for @wRaceDesc.
  ///
  /// In en, this message translates to:
  /// **'Start controlled, find your rhythm, finish strong. Good luck!'**
  String get wRaceDesc;

  /// No description provided for @wRaceGoalDesc.
  ///
  /// In en, this message translates to:
  /// **'Goal time {time}. Start controlled (first km not faster than goal pace), finish strong. Good luck!'**
  String wRaceGoalDesc(String time);

  /// No description provided for @stepRaceNote.
  ///
  /// In en, this message translates to:
  /// **'Race pace – even splits'**
  String get stepRaceNote;

  /// No description provided for @intensityRace.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get intensityRace;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
