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
  /// **'Experience level'**
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
  /// **'Race'**
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
  /// **'Race name'**
  String get eventName;

  /// No description provided for @eventDate.
  ///
  /// In en, this message translates to:
  /// **'Race date'**
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
  /// **'Your load is low – a great time for a key workout or more volume.'**
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
  /// **'Free'**
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
  /// **'Start workout'**
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
  /// **'Tap \"Length\" after every length. Distance is calculated automatically.'**
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
  /// **'Create plan'**
  String get generatePlan;

  /// No description provided for @generatePlanSub.
  ///
  /// In en, this message translates to:
  /// **'Focus: {focus} · {days} days/week (change in profile)'**
  String generatePlanSub(String focus, int days);

  /// No description provided for @planLocalDesc.
  ///
  /// In en, this message translates to:
  /// **'Periodised plan based on sports science (80/20, progressive overload, a recovery week every 3–5 weeks depending on difficulty). Works offline.'**
  String get planLocalDesc;

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
  /// **'Export calendar'**
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
  /// **'Last week'**
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
  /// **'My Strive training plan (.ics) – open it with a calendar app to import it.'**
  String get icsShareText;

  /// No description provided for @planGymDesc.
  ///
  /// In en, this message translates to:
  /// **'Strength session – progressive overload: add weight or reps when all sets feel good.'**
  String get planGymDesc;

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
  /// **'Why does my week look like this?'**
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
  /// **'I\'m sick/tired – what should I change?'**
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
  /// **'Race is over'**
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

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked in system settings.'**
  String get notificationsDenied;

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

  /// No description provided for @googleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar'**
  String get googleCalendar;

  /// No description provided for @googleCalendarSub.
  ///
  /// In en, this message translates to:
  /// **'Sync your plan into a separate \"Strive\" calendar'**
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
  /// **'Link as superset'**
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
  /// **'same weight – one more rep per set'**
  String get progAddReps;

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
  /// **'+10 % volume/week, more key workouts – for experienced athletes.'**
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
  /// **'Easy'**
  String get zConversational;

  /// No description provided for @zEasyLong.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get zEasyLong;

  /// No description provided for @zMarathon.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get zMarathon;

  /// No description provided for @zThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get zThreshold;

  /// No description provided for @zInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get zInterval;

  /// No description provided for @zStride.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get zStride;

  /// No description provided for @zJog.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get zJog;

  /// No description provided for @zWalk.
  ///
  /// In en, this message translates to:
  /// **'walk'**
  String get zWalk;

  /// No description provided for @zRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get zRecovery;

  /// No description provided for @zSprint.
  ///
  /// In en, this message translates to:
  /// **'sprint'**
  String get zSprint;

  /// No description provided for @zSwimEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get zSwimEndurance;

  /// No description provided for @zDrills.
  ///
  /// In en, this message translates to:
  /// **'Technique'**
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
  /// **'Key workout'**
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
  /// **'Fresh – ready for a race or key workout'**
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

  /// No description provided for @gcalConnectedSub.
  ///
  /// In en, this message translates to:
  /// **'Connected · {account}'**
  String gcalConnectedSub(String account);

  /// No description provided for @gcalHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan in Google Calendar'**
  String get gcalHeroTitle;

  /// No description provided for @gcalHeroSub.
  ///
  /// In en, this message translates to:
  /// **'Strive creates its own calendar called \"Strive\" and keeps it up to date automatically. Your other appointments are never read.'**
  String get gcalHeroSub;

  /// No description provided for @gcalConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Calendar'**
  String get gcalConnect;

  /// No description provided for @gcalDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get gcalDisconnect;

  /// No description provided for @gcalSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get gcalSyncNow;

  /// No description provided for @gcalSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get gcalSyncing;

  /// No description provided for @gcalAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get gcalAccount;

  /// No description provided for @gcalLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get gcalLastSync;

  /// No description provided for @gcalEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get gcalEvents;

  /// No description provided for @gcalAutoInfo.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync is on – changes to your plan show up in Google Calendar a few seconds later.'**
  String get gcalAutoInfo;

  /// No description provided for @gcalSynced.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts synced'**
  String gcalSynced(int count);

  /// No description provided for @gcalConnectedToast.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar connected'**
  String get gcalConnectedToast;

  /// No description provided for @gcalDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Google Calendar?'**
  String get gcalDisconnectTitle;

  /// No description provided for @gcalDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'Strive will stop updating the calendar. Do you also want to delete the \"Strive\" calendar and all its events from your Google account?'**
  String get gcalDisconnectBody;

  /// No description provided for @gcalDeleteCalendar.
  ///
  /// In en, this message translates to:
  /// **'Delete calendar'**
  String get gcalDeleteCalendar;

  /// No description provided for @gcalKeepCalendar.
  ///
  /// In en, this message translates to:
  /// **'Keep calendar'**
  String get gcalKeepCalendar;

  /// No description provided for @gcalDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar disconnected'**
  String get gcalDisconnected;

  /// No description provided for @gcalHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get gcalHowTitle;

  /// No description provided for @gcalHow1.
  ///
  /// In en, this message translates to:
  /// **'Strive only gets access to calendars it created itself – it cannot see your other calendars or appointments.'**
  String get gcalHow1;

  /// No description provided for @gcalHow2.
  ///
  /// In en, this message translates to:
  /// **'Workouts from the last 7 days up to 6 months ahead are entered at your preferred training time ({time}).'**
  String gcalHow2(String time);

  /// No description provided for @gcalHow3.
  ///
  /// In en, this message translates to:
  /// **'To hide the workouts, untick the \"Strive\" calendar in Google Calendar – syncing continues in the background.'**
  String get gcalHow3;

  /// No description provided for @gcalHow4.
  ///
  /// In en, this message translates to:
  /// **'Changes made in Google Calendar are overwritten on the next sync – edit your workouts in Strive.'**
  String get gcalHow4;

  /// No description provided for @gcalOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Google Calendar'**
  String get gcalOpen;

  /// No description provided for @gcalReconnect.
  ///
  /// In en, this message translates to:
  /// **'Connect again'**
  String get gcalReconnect;

  /// No description provided for @gcalErrApiDisabled.
  ///
  /// In en, this message translates to:
  /// **'The Google Calendar API is not enabled for this app yet. The developer needs to enable it in the Google Cloud console (project strive-fitness-app).'**
  String get gcalErrApiDisabled;

  /// No description provided for @gcalErrAuth.
  ///
  /// In en, this message translates to:
  /// **'Google access has expired or was revoked. Please connect again.'**
  String get gcalErrAuth;

  /// No description provided for @gcalErrOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection to Google. Strive will try again automatically.'**
  String get gcalErrOffline;

  /// No description provided for @gcalErrRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Google is limiting requests right now. Please try again in a few minutes.'**
  String get gcalErrRateLimit;

  /// No description provided for @gcalErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {detail}'**
  String gcalErrGeneric(String detail);

  /// No description provided for @gcalCalendarDescription.
  ///
  /// In en, this message translates to:
  /// **'Training plan from the Strive app. Managed automatically – changes made here will be overwritten.'**
  String get gcalCalendarDescription;

  /// No description provided for @gcalStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get gcalStructure;

  /// No description provided for @gcalEventFooter.
  ///
  /// In en, this message translates to:
  /// **'Synced from Strive – edit this workout in the app.'**
  String get gcalEventFooter;

  /// No description provided for @planSettings.
  ///
  /// In en, this message translates to:
  /// **'Plan settings'**
  String get planSettings;

  /// No description provided for @editPlanSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit plan settings'**
  String get editPlanSettings;

  /// No description provided for @editPlanSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Sports, week, times, sport data, goal – then a new plan'**
  String get editPlanSettingsSub;

  /// No description provided for @editProfileSub.
  ///
  /// In en, this message translates to:
  /// **'Name, body data, level, health'**
  String get editProfileSub;

  /// No description provided for @timeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time per training day'**
  String get timeTitle;

  /// No description provided for @timeHint.
  ///
  /// In en, this message translates to:
  /// **'The most time you have on a training day – including warm-up and cool-down. Every session is planned to fit.'**
  String get timeHint;

  /// No description provided for @timeLongDayHint.
  ///
  /// In en, this message translates to:
  /// **'On your long-session day (★) Strive plans up to 2 h unless you set that day yourself.'**
  String get timeLongDayHint;

  /// No description provided for @timePerDay.
  ///
  /// In en, this message translates to:
  /// **'Set per day (optional)'**
  String get timePerDay;

  /// No description provided for @timeCustomDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days set individually'**
  String timeCustomDays(int count);

  /// No description provided for @timeDefault.
  ///
  /// In en, this message translates to:
  /// **'Back to default'**
  String get timeDefault;

  /// No description provided for @recTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendation for you'**
  String get recTitle;

  /// No description provided for @recSub.
  ///
  /// In en, this message translates to:
  /// **'Based on your level, goal and focus. Rest days stay free on purpose – that is when you adapt.'**
  String get recSub;

  /// No description provided for @recPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count}× / week'**
  String recPerWeek(int count);

  /// No description provided for @recAuto.
  ///
  /// In en, this message translates to:
  /// **'Plan my week'**
  String get recAuto;

  /// No description provided for @recApplied.
  ///
  /// In en, this message translates to:
  /// **'Week planned – adjust it as you like.'**
  String get recApplied;

  /// No description provided for @recActive.
  ///
  /// In en, this message translates to:
  /// **'Recommendation applied'**
  String get recActive;

  /// No description provided for @recDays.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {count} training days'**
  String recDays(int count);

  /// No description provided for @recAutoDays.
  ///
  /// In en, this message translates to:
  /// **'Use recommendation'**
  String get recAutoDays;

  /// No description provided for @splitTitle.
  ///
  /// In en, this message translates to:
  /// **'Training split'**
  String get splitTitle;

  /// No description provided for @splitHint.
  ///
  /// In en, this message translates to:
  /// **'How your gym sessions are divided. Ideally every muscle is trained about 2× per week.'**
  String get splitHint;

  /// No description provided for @splitAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get splitAuto;

  /// No description provided for @splitAutoSub.
  ///
  /// In en, this message translates to:
  /// **'Now: {name} – adapts to your training days'**
  String splitAutoSub(String name);

  /// No description provided for @splitFullbody.
  ///
  /// In en, this message translates to:
  /// **'Full body'**
  String get splitFullbody;

  /// No description provided for @splitFullbodySub.
  ///
  /// In en, this message translates to:
  /// **'Whole body every session · ideal for 2–3 days'**
  String get splitFullbodySub;

  /// No description provided for @splitUpperLower.
  ///
  /// In en, this message translates to:
  /// **'Upper / Lower'**
  String get splitUpperLower;

  /// No description provided for @splitUpperLowerSub.
  ///
  /// In en, this message translates to:
  /// **'Upper and lower body alternate · ideal for 4 days'**
  String get splitUpperLowerSub;

  /// No description provided for @splitPpl.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs'**
  String get splitPpl;

  /// No description provided for @splitPplSub.
  ///
  /// In en, this message translates to:
  /// **'Pressing, pulling, legs · ideal for 3 or 6 days'**
  String get splitPplSub;

  /// No description provided for @splitUlppl.
  ///
  /// In en, this message translates to:
  /// **'Upper/Lower + PPL'**
  String get splitUlppl;

  /// No description provided for @splitUlpplSub.
  ///
  /// In en, this message translates to:
  /// **'Hybrid of both · ideal for 5 days'**
  String get splitUlpplSub;

  /// No description provided for @splitBro.
  ///
  /// In en, this message translates to:
  /// **'Bro split'**
  String get splitBro;

  /// No description provided for @splitBroSub.
  ///
  /// In en, this message translates to:
  /// **'One muscle group per day · 5 days'**
  String get splitBroSub;

  /// No description provided for @splitFreq.
  ///
  /// In en, this message translates to:
  /// **'Each muscle ~{value}× per week with your days'**
  String splitFreq(String value);

  /// No description provided for @splitBroWarning.
  ///
  /// In en, this message translates to:
  /// **'Each muscle only once a week. With the same weekly volume, training a muscle twice a week usually builds a little more muscle (Schoenfeld 2016) – fine if you enjoy it.'**
  String get splitBroWarning;

  /// No description provided for @splitForDays.
  ///
  /// In en, this message translates to:
  /// **'Best for {count} days'**
  String splitForDays(int count);

  /// No description provided for @splitHomeNote.
  ///
  /// In en, this message translates to:
  /// **'Training at home or with bodyweight uses full-body programs (2 alternating workouts).'**
  String get splitHomeNote;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @folderNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Summer cut'**
  String get folderNameHint;

  /// No description provided for @folderExists.
  ///
  /// In en, this message translates to:
  /// **'A folder with this name already exists.'**
  String get folderExists;

  /// No description provided for @sortPrograms.
  ///
  /// In en, this message translates to:
  /// **'Sort folders & programs'**
  String get sortPrograms;

  /// No description provided for @sortHint.
  ///
  /// In en, this message translates to:
  /// **'Drag folders and programs by the handle to reorder them.'**
  String get sortHint;

  /// No description provided for @addBuiltinPrograms.
  ///
  /// In en, this message translates to:
  /// **'Add built-in programs'**
  String get addBuiltinPrograms;

  /// No description provided for @addBuiltinProgramsSub.
  ///
  /// In en, this message translates to:
  /// **'Evidence-based programs for every split plus structured run, ride and swim workouts.'**
  String get addBuiltinProgramsSub;

  /// No description provided for @builtinsComplete.
  ///
  /// In en, this message translates to:
  /// **'You already have all built-in programs.'**
  String get builtinsComplete;

  /// No description provided for @programsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} programs added'**
  String programsAdded(int count);

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteFolderTitle(String name);

  /// No description provided for @deleteFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'The folder is empty.'**
  String get deleteFolderEmpty;

  /// No description provided for @deleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'The folder contains {count} programs. Keep them (without folder) or delete everything?'**
  String deleteFolderBody(int count);

  /// No description provided for @deleteFolderKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep programs'**
  String get deleteFolderKeep;

  /// No description provided for @deleteFolderAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteFolderAll;

  /// No description provided for @programsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} programs'**
  String programsCount(int count);

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No programs yet – add one via the menu.'**
  String get folderEmpty;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get copy;

  /// No description provided for @moveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolder;

  /// No description provided for @stepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sections'**
  String stepsCount(int count);

  /// No description provided for @addSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get addSection;

  /// No description provided for @addRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get addRepeat;

  /// No description provided for @editSection.
  ///
  /// In en, this message translates to:
  /// **'Edit section'**
  String get editSection;

  /// No description provided for @byTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get byTime;

  /// No description provided for @byDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get byDistance;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChanges;

  /// No description provided for @setsN.
  ///
  /// In en, this message translates to:
  /// **'{count} sets'**
  String setsN(int count);

  /// No description provided for @structuredWorkout.
  ///
  /// In en, this message translates to:
  /// **'Structured'**
  String get structuredWorkout;

  /// No description provided for @structuredWorkoutSub.
  ///
  /// In en, this message translates to:
  /// **'Phases with targets – guided step by step during the workout (voice, pace/power/HR).'**
  String get structuredWorkoutSub;

  /// No description provided for @freeWorkoutSub.
  ///
  /// In en, this message translates to:
  /// **'Just a duration or distance goal, no sections.'**
  String get freeWorkoutSub;

  /// No description provided for @supersetLinked.
  ///
  /// In en, this message translates to:
  /// **'Superset – tap to unlink'**
  String get supersetLinked;

  /// No description provided for @repRange.
  ///
  /// In en, this message translates to:
  /// **'Rep range'**
  String get repRange;

  /// No description provided for @repRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Double progression: add reps until you hit the top of the range on all sets, then increase the weight.'**
  String get repRangeHint;

  /// No description provided for @exerciseLoadError.
  ///
  /// In en, this message translates to:
  /// **'Exercises could not be loaded.'**
  String get exerciseLoadError;

  /// No description provided for @vcStepN.
  ///
  /// In en, this message translates to:
  /// **'Interval {x} of {y}'**
  String vcStepN(int x, int y);

  /// No description provided for @vcSplitRide.
  ///
  /// In en, this message translates to:
  /// **'Kilometer {n}. Time {time}. Last {km} kilometers at {speed}.'**
  String vcSplitRide(int n, String time, int km, String speed);

  /// No description provided for @vcSplitSwim.
  ///
  /// In en, this message translates to:
  /// **'Kilometer {n}. Time {time}. Pace {pace}.'**
  String vcSplitSwim(int n, String time, String pace);

  /// No description provided for @vcKmh.
  ///
  /// In en, this message translates to:
  /// **'{speed} kilometers per hour'**
  String vcKmh(String speed);

  /// No description provided for @vcPer100m.
  ///
  /// In en, this message translates to:
  /// **'{pace} per 100 meters'**
  String vcPer100m(String pace);

  /// No description provided for @vcPaceRange100.
  ///
  /// In en, this message translates to:
  /// **'{a} to {b} per 100 meters'**
  String vcPaceRange100(String a, String b);

  /// No description provided for @vcPowerRange.
  ///
  /// In en, this message translates to:
  /// **'{lo} to {hi} watts'**
  String vcPowerRange(int lo, int hi);

  /// No description provided for @vcHrRange.
  ///
  /// In en, this message translates to:
  /// **'heart rate {lo} to {hi}'**
  String vcHrRange(int lo, int hi);

  /// No description provided for @vcAllDoneRide.
  ///
  /// In en, this message translates to:
  /// **'All sections done. Great work! Spin out easy.'**
  String get vcAllDoneRide;

  /// No description provided for @vcAllDoneSwim.
  ///
  /// In en, this message translates to:
  /// **'All sets done. Great work! Swim a few easy lengths.'**
  String get vcAllDoneSwim;

  /// No description provided for @allStepsDoneRide.
  ///
  /// In en, this message translates to:
  /// **'All sections done! Spin out easy and finish when ready.'**
  String get allStepsDoneRide;

  /// No description provided for @allStepsDoneSwim.
  ///
  /// In en, this message translates to:
  /// **'All sets done! Swim out easy and finish when ready.'**
  String get allStepsDoneSwim;

  /// No description provided for @freeRideHint.
  ///
  /// In en, this message translates to:
  /// **'Easy ride? Stay at {lo}–{hi} bpm (Zone 2) – you should be able to chat comfortably.'**
  String freeRideHint(int lo, int hi);

  /// No description provided for @stepRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get stepRest;

  /// No description provided for @stepSteadyRide.
  ///
  /// In en, this message translates to:
  /// **'Endurance ride'**
  String get stepSteadyRide;

  /// No description provided for @stepSteadySwim.
  ///
  /// In en, this message translates to:
  /// **'Steady swim'**
  String get stepSteadySwim;

  /// No description provided for @stepDrillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Drills'**
  String get stepDrillsTitle;

  /// No description provided for @zThresholdRide.
  ///
  /// In en, this message translates to:
  /// **'threshold'**
  String get zThresholdRide;

  /// No description provided for @lengthBtn.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get lengthBtn;

  /// No description provided for @lengths.
  ///
  /// In en, this message translates to:
  /// **'Lengths'**
  String get lengths;

  /// No description provided for @nLengths.
  ///
  /// In en, this message translates to:
  /// **'{lengths, plural, =1{1 length} other{{lengths} lengths}}'**
  String nLengths(int lengths);

  /// No description provided for @undoLength.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoLength;

  /// No description provided for @lengthUndone.
  ///
  /// In en, this message translates to:
  /// **'Last length removed'**
  String get lengthUndone;

  /// No description provided for @lastLength.
  ///
  /// In en, this message translates to:
  /// **'Last length'**
  String get lastLength;

  /// No description provided for @pace100.
  ///
  /// In en, this message translates to:
  /// **'Pace /100 m'**
  String get pace100;

  /// No description provided for @avgPace100.
  ///
  /// In en, this message translates to:
  /// **'Avg. /100 m'**
  String get avgPace100;

  /// No description provided for @maxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max. speed'**
  String get maxSpeed;

  /// No description provided for @workoutLeft.
  ///
  /// In en, this message translates to:
  /// **'Workout left'**
  String get workoutLeft;

  /// No description provided for @section.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get section;

  /// No description provided for @poolTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap LENGTH each time you touch the wall.'**
  String get poolTapHint;

  /// No description provided for @noLengthsYet.
  ///
  /// In en, this message translates to:
  /// **'Your lengths appear here after the first tap.'**
  String get noLengthsYet;

  /// No description provided for @keySessionSub.
  ///
  /// In en, this message translates to:
  /// **'Important workout of the week – Strive keeps hard days apart.'**
  String get keySessionSub;

  /// No description provided for @workoutPhases.
  ///
  /// In en, this message translates to:
  /// **'Phases'**
  String get workoutPhases;

  /// No description provided for @planDone.
  ///
  /// In en, this message translates to:
  /// **'Plan done'**
  String get planDone;

  /// No description provided for @perSport.
  ///
  /// In en, this message translates to:
  /// **'Per sport'**
  String get perSport;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery & load'**
  String get recoveryTitle;

  /// No description provided for @load7d.
  ///
  /// In en, this message translates to:
  /// **'Load 7 days'**
  String get load7d;

  /// No description provided for @load28d.
  ///
  /// In en, this message translates to:
  /// **'Ø week (28 d)'**
  String get load28d;

  /// No description provided for @daysInARow.
  ///
  /// In en, this message translates to:
  /// **'Days in a row'**
  String get daysInARow;

  /// No description provided for @recoveryHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How this works'**
  String get recoveryHowTitle;

  /// No description provided for @recoveryHowText.
  ///
  /// In en, this message translates to:
  /// **'Every workout gets a load score (duration × intensity, from RPE or heart rate). Strive compares the last 7 days with your average week of the last 28 days (acute:chronic workload ratio, Gabbett 2016). Between 0.8 and 1.3 you build fitness with a low injury risk; above 1.5 the risk rises clearly – plan an easy day. Fitness, fatigue and form follow the Banister model: form = fitness − fatigue.'**
  String get recoveryHowText;

  /// No description provided for @nWorkouts.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts'**
  String nWorkouts(int count);

  /// No description provided for @sessionN.
  ///
  /// In en, this message translates to:
  /// **'Session {n}'**
  String sessionN(int n);

  /// No description provided for @byDay.
  ///
  /// In en, this message translates to:
  /// **'Day by day'**
  String get byDay;

  /// No description provided for @planExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to this workout only – the program stays as it is.'**
  String get planExercisesHint;

  /// No description provided for @planExercisesCustom.
  ///
  /// In en, this message translates to:
  /// **'Adjusted for this workout (program: {name}).'**
  String planExercisesCustom(String name);

  /// No description provided for @saveToProgram.
  ///
  /// In en, this message translates to:
  /// **'Save to program'**
  String get saveToProgram;

  /// No description provided for @savedToProgram.
  ///
  /// In en, this message translates to:
  /// **'Saved to \"{name}\"'**
  String savedToProgram(String name);

  /// No description provided for @resetToProgram.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetToProgram;

  /// No description provided for @adjustExercises.
  ///
  /// In en, this message translates to:
  /// **'Adjust exercises'**
  String get adjustExercises;

  /// No description provided for @zSwimEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get zSwimEasy;

  /// No description provided for @zEndurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get zEndurance;

  /// No description provided for @zCss.
  ///
  /// In en, this message translates to:
  /// **'CSS pace'**
  String get zCss;

  /// No description provided for @zTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get zTempo;

  /// No description provided for @zoneInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Intensity zones'**
  String get zoneInfoTitle;

  /// No description provided for @zoneInfoRun.
  ///
  /// In en, this message translates to:
  /// **'Paces come from your race times (VDOT, Jack Daniels). Most of your running – about 80 % – should be easy; the faster zones are used in short, targeted doses.'**
  String get zoneInfoRun;

  /// No description provided for @zoneInfoRide.
  ///
  /// In en, this message translates to:
  /// **'Power zones are percentages of your FTP (the power you can hold for about one hour). Without a power meter, ride by heart rate and feel.'**
  String get zoneInfoRide;

  /// No description provided for @zoneInfoSwim.
  ///
  /// In en, this message translates to:
  /// **'Paces per 100 m come from your critical swim speed (CSS, from a 400 m and 200 m test).'**
  String get zoneInfoSwim;

  /// No description provided for @zoneInfoEstimated.
  ///
  /// In en, this message translates to:
  /// **'≈ values are estimated from your level – add a test result in the plan settings for exact targets.'**
  String get zoneInfoEstimated;

  /// No description provided for @zfVeryEasy.
  ///
  /// In en, this message translates to:
  /// **'RPE 1–2 · very easy'**
  String get zfVeryEasy;

  /// No description provided for @zfEasy.
  ///
  /// In en, this message translates to:
  /// **'RPE 3–4 · full sentences'**
  String get zfEasy;

  /// No description provided for @zfDrills.
  ///
  /// In en, this message translates to:
  /// **'focus on form'**
  String get zfDrills;

  /// No description provided for @zfModerate.
  ///
  /// In en, this message translates to:
  /// **'RPE 5–6 · short sentences'**
  String get zfModerate;

  /// No description provided for @zfHard.
  ///
  /// In en, this message translates to:
  /// **'RPE 7–8 · single words'**
  String get zfHard;

  /// No description provided for @zfVeryHard.
  ///
  /// In en, this message translates to:
  /// **'RPE 8–9 · no talking'**
  String get zfVeryHard;

  /// No description provided for @zfMax.
  ///
  /// In en, this message translates to:
  /// **'RPE 9–10 · fast & relaxed'**
  String get zfMax;

  /// No description provided for @zdRunRec.
  ///
  /// In en, this message translates to:
  /// **'Walking or very slow jogging between hard efforts and for warming up. Lets your heart rate come down.'**
  String get zdRunRec;

  /// No description provided for @zdRunEasy.
  ///
  /// In en, this message translates to:
  /// **'Your everyday pace: relaxed, you can talk in full sentences. Builds the aerobic base, used for easy and long runs.'**
  String get zdRunEasy;

  /// No description provided for @zdRunSteady.
  ///
  /// In en, this message translates to:
  /// **'Controlled but purposeful, about your marathon pace. Used in long-run finishes and steady runs.'**
  String get zdRunSteady;

  /// No description provided for @zdRunThreshold.
  ///
  /// In en, this message translates to:
  /// **'\"Comfortably hard\" – a pace you could hold for about an hour. Tempo runs and cruise intervals raise your lactate threshold.'**
  String get zdRunThreshold;

  /// No description provided for @zdRunInterval.
  ///
  /// In en, this message translates to:
  /// **'About your 3–5 km race pace. Efforts of 2–5 minutes with recovery jogs improve your VO2max.'**
  String get zdRunInterval;

  /// No description provided for @zdRunSprint.
  ///
  /// In en, this message translates to:
  /// **'Short, fast but relaxed efforts (strides, 10–30 s) with full recovery. Improves running economy and form.'**
  String get zdRunSprint;

  /// No description provided for @zdRideRec.
  ///
  /// In en, this message translates to:
  /// **'Spinning easily, for warm-up, cool-down and recovery rides.'**
  String get zdRideRec;

  /// No description provided for @zdRideEndurance.
  ///
  /// In en, this message translates to:
  /// **'The base of cycling training: long, steady rides at a pace you can hold for hours.'**
  String get zdRideEndurance;

  /// No description provided for @zdRideSweetSpot.
  ///
  /// In en, this message translates to:
  /// **'Just below threshold: hard but sustainable for 10–40 minutes. Very time-efficient for building FTP.'**
  String get zdRideSweetSpot;

  /// No description provided for @zdRideThreshold.
  ///
  /// In en, this message translates to:
  /// **'Around your FTP – the effort of a one-hour time trial. Blocks of 8–20 minutes.'**
  String get zdRideThreshold;

  /// No description provided for @zdRideVo2.
  ///
  /// In en, this message translates to:
  /// **'Very hard efforts of 2–6 minutes that push your maximal oxygen uptake.'**
  String get zdRideVo2;

  /// No description provided for @zdRideSprint.
  ///
  /// In en, this message translates to:
  /// **'Short all-out bursts (up to 30 s) for power and speed, with long recoveries.'**
  String get zdRideSprint;

  /// No description provided for @zdSwimEasy.
  ///
  /// In en, this message translates to:
  /// **'Loose, relaxed swimming for warm-up, cool-down and rests. Focus on long strokes and calm breathing.'**
  String get zdSwimEasy;

  /// No description provided for @zdSwimDrills.
  ///
  /// In en, this message translates to:
  /// **'Technique drills: exercises that isolate one part of the stroke (arm pull, body position, rotation, breathing). Speed does not matter – swim slowly and precisely. Tap \"Technique drills\" below for the exercises.'**
  String get zdSwimDrills;

  /// No description provided for @zdSwimEndurance.
  ///
  /// In en, this message translates to:
  /// **'Steady aerobic swimming, a few seconds slower than CSS per 100 m. The main zone for longer sets.'**
  String get zdSwimEndurance;

  /// No description provided for @zdSwimCss.
  ///
  /// In en, this message translates to:
  /// **'Your critical swim speed – about your 1500 m race pace. Hard but even, with short rests (10–20 s).'**
  String get zdSwimCss;

  /// No description provided for @zdSwimSprint.
  ///
  /// In en, this message translates to:
  /// **'Short, fast lengths (25–50 m) with long rests for speed and power.'**
  String get zdSwimSprint;

  /// No description provided for @swimDrillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Technique drills'**
  String get swimDrillsTitle;

  /// No description provided for @swimDrillsIntro.
  ///
  /// In en, this message translates to:
  /// **'In a technique set you swim these drills instead of normal freestyle, e.g. 50 m drill / 50 m freestyle. Swim slowly and concentrate on one thing per length.'**
  String get swimDrillsIntro;

  /// No description provided for @drillCatchupName.
  ///
  /// In en, this message translates to:
  /// **'Catch-up'**
  String get drillCatchupName;

  /// No description provided for @drillCatchupHow.
  ///
  /// In en, this message translates to:
  /// **'One arm stays stretched in front until the other arm touches it, then it starts its pull.'**
  String get drillCatchupHow;

  /// No description provided for @drillCatchupWhy.
  ///
  /// In en, this message translates to:
  /// **'Longer stroke, better glide and timing.'**
  String get drillCatchupWhy;

  /// No description provided for @drillFingertipName.
  ///
  /// In en, this message translates to:
  /// **'Fingertip drag'**
  String get drillFingertipName;

  /// No description provided for @drillFingertipHow.
  ///
  /// In en, this message translates to:
  /// **'During the recovery, drag your fingertips along the water surface from hip to head.'**
  String get drillFingertipHow;

  /// No description provided for @drillFingertipWhy.
  ///
  /// In en, this message translates to:
  /// **'High elbow and relaxed arm recovery.'**
  String get drillFingertipWhy;

  /// No description provided for @drillSideKickName.
  ///
  /// In en, this message translates to:
  /// **'6-1-6 side kick'**
  String get drillSideKickName;

  /// No description provided for @drillSideKickHow.
  ///
  /// In en, this message translates to:
  /// **'Kick 6 times on your side (lower arm stretched forward), take one stroke, kick 6 times on the other side.'**
  String get drillSideKickHow;

  /// No description provided for @drillSideKickWhy.
  ///
  /// In en, this message translates to:
  /// **'Body position, rotation and calm breathing.'**
  String get drillSideKickWhy;

  /// No description provided for @drillSingleArmName.
  ///
  /// In en, this message translates to:
  /// **'Single arm'**
  String get drillSingleArmName;

  /// No description provided for @drillSingleArmHow.
  ///
  /// In en, this message translates to:
  /// **'One arm stays in front, the other one swims alone; switch arms every length.'**
  String get drillSingleArmHow;

  /// No description provided for @drillSingleArmWhy.
  ///
  /// In en, this message translates to:
  /// **'Clean underwater pull and rotation to the breathing side.'**
  String get drillSingleArmWhy;

  /// No description provided for @drillFistName.
  ///
  /// In en, this message translates to:
  /// **'Fist swimming'**
  String get drillFistName;

  /// No description provided for @drillFistHow.
  ///
  /// In en, this message translates to:
  /// **'Swim freestyle with closed fists; open your hands again for the last 10 m.'**
  String get drillFistHow;

  /// No description provided for @drillFistWhy.
  ///
  /// In en, this message translates to:
  /// **'You learn to pull with the whole forearm (early vertical forearm).'**
  String get drillFistWhy;

  /// No description provided for @drillScullName.
  ///
  /// In en, this message translates to:
  /// **'Sculling'**
  String get drillScullName;

  /// No description provided for @drillScullHow.
  ///
  /// In en, this message translates to:
  /// **'Lying flat, move your hands in small figure-eights in front of your head to move forward.'**
  String get drillScullHow;

  /// No description provided for @drillScullWhy.
  ///
  /// In en, this message translates to:
  /// **'Feel for the water and a strong catch.'**
  String get drillScullWhy;

  /// No description provided for @drillsNote.
  ///
  /// In en, this message translates to:
  /// **'{a} / {b} – alternate 50 m drill, 50 m freestyle'**
  String drillsNote(String a, String b);

  /// No description provided for @intensityAuto.
  ///
  /// In en, this message translates to:
  /// **'{name} (from the structure)'**
  String intensityAuto(String name);

  /// No description provided for @showDrills.
  ///
  /// In en, this message translates to:
  /// **'Show drills'**
  String get showDrills;

  /// No description provided for @streakWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week in a row} other{{count} weeks in a row}}'**
  String streakWeeks(int count);

  /// No description provided for @streakThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get streakThisWeek;

  /// No description provided for @streakWeekDone.
  ///
  /// In en, this message translates to:
  /// **'Goal reached: {done} of {target} training days – this week counts!'**
  String streakWeekDone(int done, int target);

  /// No description provided for @streakWeekLeft.
  ///
  /// In en, this message translates to:
  /// **'{done} of {target} training days – {count} more to keep the streak going.'**
  String streakWeekLeft(int done, int target, int count);

  /// No description provided for @streakLastWeeks.
  ///
  /// In en, this message translates to:
  /// **'Last 8 weeks'**
  String get streakLastWeeks;

  /// No description provided for @streakHow.
  ///
  /// In en, this message translates to:
  /// **'A week counts when you train on as many days as planned. With a training plan, the goal is the number of days with planned workouts that week (two sessions on one day count as one day); without a plan it is your number of training days. The current week never breaks your streak – it is added as soon as you reach the goal.'**
  String get streakHow;

  /// No description provided for @showPastWeeks.
  ///
  /// In en, this message translates to:
  /// **'Past weeks'**
  String get showPastWeeks;

  /// No description provided for @loadSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: {load}'**
  String loadSuggestion(String load);

  /// No description provided for @loadApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {weight} × {reps}'**
  String loadApprox(String weight, int reps);

  /// No description provided for @loadApproxPerHand.
  ///
  /// In en, this message translates to:
  /// **'≈ {weight} × {reps} per hand'**
  String loadApproxPerHand(String weight, int reps);

  /// No description provided for @loadBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight × {reps}'**
  String loadBodyweight(int reps);

  /// No description provided for @loadBodyweightPlus.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight +{weight} × {reps}'**
  String loadBodyweightPlus(String weight, int reps);

  /// No description provided for @loadSrcHistory.
  ///
  /// In en, this message translates to:
  /// **'from your last workout'**
  String get loadSrcHistory;

  /// No description provided for @loadSrcIncrease.
  ///
  /// In en, this message translates to:
  /// **'all reps done last time – more weight'**
  String get loadSrcIncrease;

  /// No description provided for @loadSrcAddReps.
  ///
  /// In en, this message translates to:
  /// **'from your last workout – aim for one more rep'**
  String get loadSrcAddReps;

  /// No description provided for @loadSrcDeload.
  ///
  /// In en, this message translates to:
  /// **'last time was tough – a bit lighter'**
  String get loadSrcDeload;

  /// No description provided for @loadSrcBreak.
  ///
  /// In en, this message translates to:
  /// **'a bit lighter after your break'**
  String get loadSrcBreak;

  /// No description provided for @loadSrcOneRm.
  ///
  /// In en, this message translates to:
  /// **'from your 1RM in the setup'**
  String get loadSrcOneRm;

  /// No description provided for @loadSrcEstimate.
  ///
  /// In en, this message translates to:
  /// **'estimated from body weight – adjust it'**
  String get loadSrcEstimate;

  /// No description provided for @loadPhaseLighter.
  ///
  /// In en, this message translates to:
  /// **'recovery week'**
  String get loadPhaseLighter;

  /// No description provided for @loadTaperLighter.
  ///
  /// In en, this message translates to:
  /// **'taper week'**
  String get loadTaperLighter;

  /// No description provided for @scoreLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'Outdoor training conditions'**
  String get scoreLegendTitle;

  /// No description provided for @scoreGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get scoreGood;

  /// No description provided for @scoreFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get scoreFair;

  /// No description provided for @scorePoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get scorePoor;

  /// No description provided for @scoreHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How the score works'**
  String get scoreHowTitle;

  /// No description provided for @scoreHowIntro.
  ///
  /// In en, this message translates to:
  /// **'Every hour gets a score from 0 to 100 for outdoor endurance training. It starts at 100 and loses points for:'**
  String get scoreHowIntro;

  /// No description provided for @scoreHowTemp.
  ///
  /// In en, this message translates to:
  /// **'Feels-like temperature outside 7–16 °C (ideal for running): −3.5 per °C colder, −4.5 per °C warmer'**
  String get scoreHowTemp;

  /// No description provided for @scoreHowRain.
  ///
  /// In en, this message translates to:
  /// **'Rain: chance of rain and expected amount'**
  String get scoreHowRain;

  /// No description provided for @scoreHowWind.
  ///
  /// In en, this message translates to:
  /// **'Wind above 20 km/h'**
  String get scoreHowWind;

  /// No description provided for @scoreHowUv.
  ///
  /// In en, this message translates to:
  /// **'UV index above 6'**
  String get scoreHowUv;

  /// No description provided for @scoreHowDark.
  ///
  /// In en, this message translates to:
  /// **'Darkness (−18)'**
  String get scoreHowDark;

  /// No description provided for @scoreHowStorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm (−40)'**
  String get scoreHowStorm;

  /// No description provided for @scoreHowLevels.
  ///
  /// In en, this message translates to:
  /// **'Good from 70, fair from 45, below that rather train indoors.'**
  String get scoreHowLevels;

  /// No description provided for @streakSub.
  ///
  /// In en, this message translates to:
  /// **'with your weekly training goal reached'**
  String get streakSub;

  /// No description provided for @wSwimCssSet.
  ///
  /// In en, this message translates to:
  /// **'CSS set {n} × {meters} m'**
  String wSwimCssSet(int n, int meters);

  /// No description provided for @complianceGreen.
  ///
  /// In en, this message translates to:
  /// **'Completed as planned ({pct}% of plan)'**
  String complianceGreen(int pct);

  /// No description provided for @complianceYellow.
  ///
  /// In en, this message translates to:
  /// **'Completed, partly off plan ({pct}% of plan)'**
  String complianceYellow(int pct);

  /// No description provided for @complianceOrange.
  ///
  /// In en, this message translates to:
  /// **'Completed, far off plan ({pct}% of plan)'**
  String complianceOrange(int pct);

  /// No description provided for @complianceDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get complianceDone;

  /// No description provided for @complianceMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get complianceMissed;

  /// No description provided for @compliancePlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get compliancePlanned;

  /// No description provided for @complianceSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get complianceSkipped;

  /// No description provided for @planCompletion.
  ///
  /// In en, this message translates to:
  /// **'Plan completion {pct}%'**
  String planCompletion(int pct);

  /// No description provided for @weightMinus.
  ///
  /// In en, this message translates to:
  /// **'Decrease weight'**
  String get weightMinus;

  /// No description provided for @weightPlus.
  ///
  /// In en, this message translates to:
  /// **'Increase weight'**
  String get weightPlus;

  /// No description provided for @previousWorkout.
  ///
  /// In en, this message translates to:
  /// **'Previous workout'**
  String get previousWorkout;

  /// No description provided for @nextWorkout.
  ///
  /// In en, this message translates to:
  /// **'Next workout'**
  String get nextWorkout;

  /// No description provided for @avgHrShort.
  ///
  /// In en, this message translates to:
  /// **'Avg. HR'**
  String get avgHrShort;

  /// No description provided for @caloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get caloriesLabel;

  /// No description provided for @recordedWith.
  ///
  /// In en, this message translates to:
  /// **'Recorded with {source}'**
  String recordedWith(String source);

  /// No description provided for @sessionGone.
  ///
  /// In en, this message translates to:
  /// **'This workout no longer exists.'**
  String get sessionGone;

  /// No description provided for @adjustWeekBanner.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 planned workout missed – adjust week?} other{{n} planned workouts missed – adjust week?}}'**
  String adjustWeekBanner(int n);

  /// No description provided for @adjustWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust week'**
  String get adjustWeekTitle;

  /// No description provided for @adjustWeekIntro.
  ///
  /// In en, this message translates to:
  /// **'Key workouts move to a free day this week – never right next to another key workout. Easy workouts don\'t need to be made up: piling up volume does more harm than good.'**
  String get adjustWeekIntro;

  /// No description provided for @adjustReplaces.
  ///
  /// In en, this message translates to:
  /// **'replaces {title}'**
  String adjustReplaces(String title);

  /// No description provided for @adjustDropped.
  ///
  /// In en, this message translates to:
  /// **'dropped – no need to make it up'**
  String get adjustDropped;

  /// No description provided for @adjustNoRoom.
  ///
  /// In en, this message translates to:
  /// **'dropped – no free day this week without a key workout next to it'**
  String get adjustNoRoom;

  /// No description provided for @adjustProtected.
  ///
  /// In en, this message translates to:
  /// **'dropped – recovery/taper week stays easy'**
  String get adjustProtected;

  /// No description provided for @adjustDone.
  ///
  /// In en, this message translates to:
  /// **'Week adjusted'**
  String get adjustDone;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @wTriLegs.
  ///
  /// In en, this message translates to:
  /// **'Swim {swim} km · Bike {bike} km · Run {run} km'**
  String wTriLegs(String swim, String bike, String run);

  /// No description provided for @editSession.
  ///
  /// In en, this message translates to:
  /// **'Edit workout'**
  String get editSession;

  /// No description provided for @durationHms.
  ///
  /// In en, this message translates to:
  /// **'Duration (h:mm:ss or mm:ss)'**
  String get durationHms;

  /// No description provided for @invalidDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter the duration as h:mm:ss or minutes.'**
  String get invalidDuration;

  /// No description provided for @rpeNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set'**
  String get rpeNotSet;

  /// No description provided for @sessionCorrected.
  ///
  /// In en, this message translates to:
  /// **'Workout updated'**
  String get sessionCorrected;

  /// No description provided for @editSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Correct wrong measurements or entries. Recorded route and splits stay as they are.'**
  String get editSessionHint;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @supersetHint.
  ///
  /// In en, this message translates to:
  /// **'Alternate the exercises – short switch, full rest after each round'**
  String get supersetHint;

  /// No description provided for @supersetMax.
  ///
  /// In en, this message translates to:
  /// **'A superset has at most 3 exercises.'**
  String get supersetMax;

  /// No description provided for @supersetSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch exercise'**
  String get supersetSwitch;

  /// No description provided for @supersetSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Short break – then straight on to the next exercise of the superset.'**
  String get supersetSwitchHint;

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyweight;

  /// No description provided for @bodyweightShort.
  ///
  /// In en, this message translates to:
  /// **'BW'**
  String get bodyweightShort;

  /// No description provided for @bodyweightHint.
  ///
  /// In en, this message translates to:
  /// **'Weight = added load on top of your body weight (negative = assistance).'**
  String get bodyweightHint;

  /// No description provided for @addedWeight.
  ///
  /// In en, this message translates to:
  /// **'Added weight'**
  String get addedWeight;

  /// No description provided for @targetLoad.
  ///
  /// In en, this message translates to:
  /// **'Target: {load} · {lo}–{hi} reps'**
  String targetLoad(String load, int lo, int hi);

  /// No description provided for @targetToday.
  ///
  /// In en, this message translates to:
  /// **'Today: {list} reps'**
  String targetToday(String list);

  /// No description provided for @loadWeightApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {weight}'**
  String loadWeightApprox(String weight);

  /// No description provided for @loadWeightPerHand.
  ///
  /// In en, this message translates to:
  /// **'≈ {weight} per hand'**
  String loadWeightPerHand(String weight);

  /// No description provided for @loadSrcHold.
  ///
  /// In en, this message translates to:
  /// **'keep the weight and hit all target reps'**
  String get loadSrcHold;

  /// No description provided for @loadSrcStall.
  ///
  /// In en, this message translates to:
  /// **'no progress for 3 workouts – a bit lighter, then build up again'**
  String get loadSrcStall;

  /// No description provided for @loadSrcIncreaseBw.
  ///
  /// In en, this message translates to:
  /// **'all reps done – add a little weight (belt or vest)'**
  String get loadSrcIncreaseBw;

  /// No description provided for @loadSrcMoreReps.
  ///
  /// In en, this message translates to:
  /// **'all reps done – go for more reps'**
  String get loadSrcMoreReps;

  /// No description provided for @loadTotal.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get loadTotal;

  /// No description provided for @quickMinOneDay.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one training day'**
  String get quickMinOneDay;

  /// No description provided for @quickDaysCapped.
  ///
  /// In en, this message translates to:
  /// **'Your plan uses {n} of your {total} days – the others stay rest days so you recover between sessions.'**
  String quickDaysCapped(int n, int total);

  /// No description provided for @wCrossRide.
  ///
  /// In en, this message translates to:
  /// **'Easy ride instead of a run'**
  String get wCrossRide;

  /// No description provided for @wCrossRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Same aerobic training without impact – easier on knees, hips and Achilles tendons. Bike or indoor trainer at a conversational effort.'**
  String get wCrossRideDesc;

  /// No description provided for @healthRunNote.
  ///
  /// In en, this message translates to:
  /// **'Joints: prefer soft surfaces; stop if pain goes above 3/10 or changes your stride.'**
  String get healthRunNote;

  /// No description provided for @healthHeartNote.
  ///
  /// In en, this message translates to:
  /// **'Heart / blood pressure: intensity capped at threshold – no all-out efforts.'**
  String get healthHeartNote;

  /// No description provided for @healthSwimShoulderNote.
  ///
  /// In en, this message translates to:
  /// **'Shoulder: no paddles, breathe to both sides, stop if it hurts.'**
  String get healthSwimShoulderNote;

  /// No description provided for @healthGymBackNote.
  ///
  /// In en, this message translates to:
  /// **'Back: no heavy axial loading – swap back squats and deadlifts for leg press, split squats or hip thrusts; keep a neutral spine.'**
  String get healthGymBackNote;

  /// No description provided for @healthGymShoulderNote.
  ///
  /// In en, this message translates to:
  /// **'Shoulder: no heavy overhead pressing – use landmine or neutral-grip variants and stay pain-free.'**
  String get healthGymShoulderNote;

  /// No description provided for @healthGymJointNote.
  ///
  /// In en, this message translates to:
  /// **'Joints: train in a pain-free range – reduce depth or load if knee or hip hurt.'**
  String get healthGymJointNote;

  /// No description provided for @healthGymHeartNote.
  ///
  /// In en, this message translates to:
  /// **'Heart / blood pressure: keep 2–3 reps in reserve and breathe out on the effort – no straining or breath holding.'**
  String get healthGymHeartNote;

  /// No description provided for @recalNote.
  ///
  /// In en, this message translates to:
  /// **'Adjusted to your recent training (effort and completed sessions).'**
  String get recalNote;

  /// No description provided for @recalButton.
  ///
  /// In en, this message translates to:
  /// **'Review plan'**
  String get recalButton;

  /// No description provided for @recalTitle.
  ///
  /// In en, this message translates to:
  /// **'Adapt plan to your training'**
  String get recalTitle;

  /// No description provided for @recalIntro.
  ///
  /// In en, this message translates to:
  /// **'Your next two weeks, adapted to the last two: effort (RPE), completed and missed sessions, new best efforts. Completed workouts stay as they are.'**
  String get recalIntro;

  /// No description provided for @recalFindings.
  ///
  /// In en, this message translates to:
  /// **'What we see'**
  String get recalFindings;

  /// No description provided for @recalChanges.
  ///
  /// In en, this message translates to:
  /// **'Proposed changes'**
  String get recalChanges;

  /// No description provided for @recalWhyRpeHigh.
  ///
  /// In en, this message translates to:
  /// **'Several sessions felt harder than planned – more recovery first.'**
  String get recalWhyRpeHigh;

  /// No description provided for @recalWhyRpeLow.
  ///
  /// In en, this message translates to:
  /// **'Your key workouts felt easy – a little more volume.'**
  String get recalWhyRpeLow;

  /// No description provided for @recalWhyCompletion.
  ///
  /// In en, this message translates to:
  /// **'{pct} % of the planned training done – no increase for now, a bit less volume.'**
  String recalWhyCompletion(int pct);

  /// No description provided for @recalWhyCutShort.
  ///
  /// In en, this message translates to:
  /// **'{n} sessions ended early – long sessions get shorter.'**
  String recalWhyCutShort(int n);

  /// No description provided for @recalWhyMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed key workouts move to a free day this week.'**
  String get recalWhyMissed;

  /// No description provided for @recalWhyFaster.
  ///
  /// In en, this message translates to:
  /// **'New best effort: running fitness (VDOT) {from} → {to} – paces updated.'**
  String recalWhyFaster(String from, String to);

  /// No description provided for @recalWhySlower.
  ///
  /// In en, this message translates to:
  /// **'Your real running fitness (VDOT {to}) differs from the estimate ({from}) – paces updated.'**
  String recalWhySlower(String to, String from);

  /// No description provided for @recalOnTrack.
  ///
  /// In en, this message translates to:
  /// **'You are on track – the plan fits your training. Nothing to change.'**
  String get recalOnTrack;

  /// No description provided for @recalNoRpe.
  ///
  /// In en, this message translates to:
  /// **'Tip: rate your effort (RPE) after workouts – the plan can then adapt to how they felt.'**
  String get recalNoRpe;

  /// No description provided for @recalEasier.
  ///
  /// In en, this message translates to:
  /// **'Easier'**
  String get recalEasier;

  /// No description provided for @recalHarder.
  ///
  /// In en, this message translates to:
  /// **'A bit more'**
  String get recalHarder;

  /// No description provided for @recalToEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy instead of hard'**
  String get recalToEasy;

  /// No description provided for @recalMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved'**
  String get recalMoved;

  /// No description provided for @recalDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get recalDropped;

  /// No description provided for @recalPaces.
  ///
  /// In en, this message translates to:
  /// **'New paces'**
  String get recalPaces;

  /// No description provided for @recalApply.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Apply 1 change} other{Apply {n} changes}}'**
  String recalApply(int n);

  /// No description provided for @recalApplied.
  ///
  /// In en, this message translates to:
  /// **'Plan adapted'**
  String get recalApplied;

  /// No description provided for @recalNewPlan.
  ///
  /// In en, this message translates to:
  /// **'Start plan over…'**
  String get recalNewPlan;

  /// No description provided for @recalMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get recalMore;

  /// No description provided for @wGymDescRange.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets per exercise in each exercise\'s rep range, leave {rir} reps in the tank. Add reps first; once every set reaches the top of the range, add weight and start again at the bottom.'**
  String wGymDescRange(int sets, int rir);

  /// No description provided for @wGymLoadDesc.
  ///
  /// In en, this message translates to:
  /// **'Loading week: end every work set with about {rir} reps in the tank – the reserve shrinks week by week until the next deload. Sets, rep range and suggested weight are shown for each exercise.'**
  String wGymLoadDesc(int rir);

  /// No description provided for @wGymProgressNote.
  ///
  /// In en, this message translates to:
  /// **'Progression: first build reps up to the top of the range, then add weight and start again at the bottom.'**
  String get wGymProgressNote;

  /// No description provided for @wGymDeloadNote.
  ///
  /// In en, this message translates to:
  /// **'Deload week: weights are entered about 10 % lighter and exercises with 3+ sets lose one. Train cleanly with about 4 reps in the tank – fatigue drops and you come back stronger.'**
  String get wGymDeloadNote;

  /// No description provided for @wGymTaperNote.
  ///
  /// In en, this message translates to:
  /// **'Taper before your race: weights about 10 % lighter, nothing to failure – keep your strength, stay fresh.'**
  String get wGymTaperNote;

  /// No description provided for @wGymTimeCapNote2.
  ///
  /// In en, this message translates to:
  /// **'Only {min} min today: do the main lifts as planned, drop a set of the last exercises or skip them.'**
  String wGymTimeCapNote2(int min);

  /// No description provided for @wRecoveryWeekNote.
  ///
  /// In en, this message translates to:
  /// **'Deload week: volume is reduced on purpose – keep it easy even if you feel fresh. This is when your body absorbs the last weeks.'**
  String get wRecoveryWeekNote;

  /// No description provided for @wTaperWeekNote.
  ///
  /// In en, this message translates to:
  /// **'Taper: less volume, short efforts stay sharp. Don\'t make up for anything – freshness for race day counts now.'**
  String get wTaperWeekNote;

  /// No description provided for @wLongRunHmpDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy long run, the last quarter at your half-marathon goal pace – the most race-specific session.'**
  String get wLongRunHmpDesc;

  /// No description provided for @stepHmpNote.
  ///
  /// In en, this message translates to:
  /// **'Half-marathon goal pace – controlled'**
  String get stepHmpNote;

  /// No description provided for @wLongRunMpDesc2.
  ///
  /// In en, this message translates to:
  /// **'Easy long run, the last quarter at your marathon goal pace – the most race-specific session.'**
  String get wLongRunMpDesc2;

  /// No description provided for @recalWhyRunTrendSlower.
  ///
  /// In en, this message translates to:
  /// **'Your key runs were slower than the target paces at a high effort – paces eased (VDOT {from} → {to}).'**
  String recalWhyRunTrendSlower(String from, String to);

  /// No description provided for @recalWhyRunTrendFaster.
  ///
  /// In en, this message translates to:
  /// **'Your key runs hit the target paces and felt easy – paces a little faster (VDOT {from} → {to}).'**
  String recalWhyRunTrendFaster(String from, String to);

  /// No description provided for @recalWhyFtpUp.
  ///
  /// In en, this message translates to:
  /// **'Bike: power above the targets without extra effort – FTP {from} → {to} W, power targets updated.'**
  String recalWhyFtpUp(String from, String to);

  /// No description provided for @recalWhyFtpDown.
  ///
  /// In en, this message translates to:
  /// **'Bike: the power targets were too hard to hold – FTP {from} → {to} W, power targets updated.'**
  String recalWhyFtpDown(String from, String to);

  /// No description provided for @recalWhyCssFaster.
  ///
  /// In en, this message translates to:
  /// **'Swim: faster than the target paces at a comfortable effort – CSS {from} → {to} per 100 m.'**
  String recalWhyCssFaster(String from, String to);

  /// No description provided for @recalWhyCssSlower.
  ///
  /// In en, this message translates to:
  /// **'Swim: the target paces were too hard to hold – CSS {from} → {to} per 100 m.'**
  String recalWhyCssSlower(String from, String to);

  /// No description provided for @recalWhyAerobicUp.
  ///
  /// In en, this message translates to:
  /// **'Aerobic efficiency (speed per heartbeat at easy effort) +{pct} % over 6 weeks – your base is growing.'**
  String recalWhyAerobicUp(int pct);

  /// No description provided for @recalWhyAerobicDown.
  ///
  /// In en, this message translates to:
  /// **'Aerobic efficiency (speed per heartbeat at easy effort) −{pct} % over 6 weeks – watch recovery, sleep and heat.'**
  String recalWhyAerobicDown(int pct);

  /// No description provided for @autoAdjSnack.
  ///
  /// In en, this message translates to:
  /// **'Plan adapted: {workout} {date} now {after} instead of {before}'**
  String autoAdjSnack(String workout, String date, String after, String before);

  /// No description provided for @autoAdjSnackMany.
  ///
  /// In en, this message translates to:
  /// **'Plan adapted: {n} upcoming workouts'**
  String autoAdjSnackMany(int n);

  /// No description provided for @autoAdjTitle.
  ///
  /// In en, this message translates to:
  /// **'Adapted automatically'**
  String get autoAdjTitle;

  /// No description provided for @autoAdjOriginal.
  ///
  /// In en, this message translates to:
  /// **'Originally planned: {value}'**
  String autoAdjOriginal(String value);

  /// No description provided for @autoAdjUndone.
  ///
  /// In en, this message translates to:
  /// **'Original plan restored'**
  String get autoAdjUndone;

  /// No description provided for @autoAdjLongCutShort.
  ///
  /// In en, this message translates to:
  /// **'Your last long session ended early at a high effort – this one is held at what you managed plus about 10 % instead of growing.'**
  String get autoAdjLongCutShort;

  /// No description provided for @autoAdjLongHard.
  ///
  /// In en, this message translates to:
  /// **'Your last long session felt harder than intended – this one stays at the same length instead of growing.'**
  String get autoAdjLongHard;

  /// No description provided for @autoAdjEasyHard.
  ///
  /// In en, this message translates to:
  /// **'Your last easy session was harder than intended (heart rate / effort) – this one is a little shorter. Keep it truly easy: you should be able to talk in full sentences.'**
  String get autoAdjEasyHard;

  /// No description provided for @autoAdjEasyTooFast.
  ///
  /// In en, this message translates to:
  /// **'Your last easy session was faster than the easy pace – this one is a little shorter. Slow down: easy days build the aerobic base (80/20).'**
  String get autoAdjEasyTooFast;

  /// No description provided for @autoAdjQualityHard.
  ///
  /// In en, this message translates to:
  /// **'Your last key workout was harder than intended – this one is not increased.'**
  String get autoAdjQualityHard;

  /// No description provided for @autoAdjQualityEasy.
  ///
  /// In en, this message translates to:
  /// **'Your last key workout hit the targets and felt easy – this one is 5 % longer.'**
  String get autoAdjQualityEasy;

  /// No description provided for @progTopReached.
  ///
  /// In en, this message translates to:
  /// **'all sets at the top of the range – more weight'**
  String get progTopReached;

  /// No description provided for @progTopWithReserve.
  ///
  /// In en, this message translates to:
  /// **'all sets at the top with reps in reserve – bigger jump'**
  String get progTopWithReserve;

  /// No description provided for @progTopAtLimit.
  ///
  /// In en, this message translates to:
  /// **'top reached, but at your limit – same weight once more'**
  String get progTopAtLimit;

  /// No description provided for @progMicroload.
  ///
  /// In en, this message translates to:
  /// **'the next weight step would be too big – more reps first'**
  String get progMicroload;

  /// No description provided for @progAddRepsFast.
  ///
  /// In en, this message translates to:
  /// **'good reserve – two more reps per set'**
  String get progAddRepsFast;

  /// No description provided for @progRepsNoLoad.
  ///
  /// In en, this message translates to:
  /// **'more reps – that is the progression here'**
  String get progRepsNoLoad;

  /// No description provided for @progHoldLimit.
  ///
  /// In en, this message translates to:
  /// **'last time was at your limit – same reps again'**
  String get progHoldLimit;

  /// No description provided for @progHoldHard.
  ///
  /// In en, this message translates to:
  /// **'hold the weight: last 2 sessions were hard'**
  String get progHoldHard;

  /// No description provided for @progMissedHold.
  ///
  /// In en, this message translates to:
  /// **'just short of the range – hold the weight'**
  String get progMissedHold;

  /// No description provided for @progMissedReduce.
  ///
  /// In en, this message translates to:
  /// **'reps clearly missed – a bit lighter'**
  String get progMissedReduce;

  /// No description provided for @progPerformanceDip.
  ///
  /// In en, this message translates to:
  /// **'hold the weight: last 2 sessions below your level'**
  String get progPerformanceDip;

  /// No description provided for @progPerformanceDrop.
  ///
  /// In en, this message translates to:
  /// **'last 2 sessions clearly weaker – 5–10 % lighter to recover'**
  String get progPerformanceDrop;

  /// No description provided for @effortQuestion.
  ///
  /// In en, this message translates to:
  /// **'How did it feel?'**
  String get effortQuestion;

  /// No description provided for @effortQuestionFor.
  ///
  /// In en, this message translates to:
  /// **'How was {name}?'**
  String effortQuestionFor(String name);

  /// No description provided for @effortOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional – helps pick your next weights'**
  String get effortOptional;

  /// No description provided for @effortEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get effortEasy;

  /// No description provided for @effortRight.
  ///
  /// In en, this message translates to:
  /// **'Just right'**
  String get effortRight;

  /// No description provided for @effortHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get effortHard;

  /// No description provided for @effortLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get effortLimit;

  /// No description provided for @howHardOptional.
  ///
  /// In en, this message translates to:
  /// **'How hard was it? (optional)'**
  String get howHardOptional;

  /// No description provided for @rpeOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Helps adapt your plan – you can skip it.'**
  String get rpeOptionalHint;

  /// No description provided for @rpeClear.
  ///
  /// In en, this message translates to:
  /// **'No rating'**
  String get rpeClear;

  /// No description provided for @rpeRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rpeRate;

  /// No description provided for @progLinear.
  ///
  /// In en, this message translates to:
  /// **'all target reps done – a bit more weight, same reps (beginner linear progression)'**
  String get progLinear;

  /// No description provided for @progNudge.
  ///
  /// In en, this message translates to:
  /// **'held twice and every target met – one more rep on the weakest set'**
  String get progNudge;

  /// No description provided for @progRecalibrated.
  ///
  /// In en, this message translates to:
  /// **'your AMRAP set showed more strength – weight adjusted to it'**
  String get progRecalibrated;

  /// No description provided for @progE1rmFloor.
  ///
  /// In en, this message translates to:
  /// **'no reps missed – the weight stays near your strength level'**
  String get progE1rmFloor;

  /// No description provided for @amrapHint.
  ///
  /// In en, this message translates to:
  /// **'Last set: as many reps as possible – stop 1 rep before failure (helps the app learn your strength)'**
  String get amrapHint;

  /// No description provided for @amrapShort.
  ///
  /// In en, this message translates to:
  /// **'AMRAP'**
  String get amrapShort;

  /// No description provided for @recalWhyBreak.
  ///
  /// In en, this message translates to:
  /// **'No training for {days} days: the first week back restarts at 50–70 % of the planned volume, without intensity, then builds up again.'**
  String recalWhyBreak(int days);

  /// No description provided for @recalWhyLongCap.
  ///
  /// In en, this message translates to:
  /// **'Long sessions stay within +10 % of your longest one of the last 30 days – beyond that the injury risk rises.'**
  String get recalWhyLongCap;

  /// No description provided for @recalWhyRpeLowHold.
  ///
  /// In en, this message translates to:
  /// **'Your key workouts felt easy – the new targets are this week\'s step up, the volume stays (never both at once).'**
  String get recalWhyRpeLowHold;

  /// No description provided for @wBrickRun.
  ///
  /// In en, this message translates to:
  /// **'Brick run {min} min'**
  String wBrickRun(int min);

  /// No description provided for @wBrickRunDesc.
  ///
  /// In en, this message translates to:
  /// **'Straight off the bike: the first minutes feel heavy – that is normal. Change quickly (≤ 2 min) – transition practice included.'**
  String get wBrickRunDesc;

  /// No description provided for @stepBrickStartNote.
  ///
  /// In en, this message translates to:
  /// **'Find your running rhythm – short, quick steps'**
  String get stepBrickStartNote;

  /// No description provided for @stepBrickNote.
  ///
  /// In en, this message translates to:
  /// **'Steady race feel – controlled, not all out'**
  String get stepBrickNote;

  /// No description provided for @wRaceRunWalk.
  ///
  /// In en, this message translates to:
  /// **'Run/walk strategy: run {min} min, walk 1 min – from the start, even if you feel fresh.'**
  String wRaceRunWalk(int min);

  /// No description provided for @wGymLegsHalvedNote.
  ///
  /// In en, this message translates to:
  /// **'Leg exercises with half the sets today – tomorrow\'s key session needs fresh legs.'**
  String get wGymLegsHalvedNote;

  /// No description provided for @feasTitle.
  ///
  /// In en, this message translates to:
  /// **'Very ambitious goal'**
  String get feasTitle;

  /// No description provided for @feasBeginnerMarathon.
  ///
  /// In en, this message translates to:
  /// **'A marathon is not a beginner goal: build up over 5 km, 10 km and a half marathon first.'**
  String get feasBeginnerMarathon;

  /// No description provided for @feasRunWalkLong.
  ///
  /// In en, this message translates to:
  /// **'As long as you can\'t run 30 min continuously, a half or full marathon is too far – start with 5 km.'**
  String get feasRunWalkLong;

  /// No description provided for @feasRunWalk.
  ///
  /// In en, this message translates to:
  /// **'On race day you will still be on run/walk – continuous running takes longer to build.'**
  String get feasRunWalk;

  /// No description provided for @feasTooShort.
  ///
  /// In en, this message translates to:
  /// **'{weeks} weeks are not enough to build the long sessions this distance needs.'**
  String feasTooShort(int weeks);

  /// No description provided for @feasLongRunTime.
  ///
  /// In en, this message translates to:
  /// **'The time on your long-run day allows only about {km} km – this race needs long runs of {x} km. Plan more time on that day.'**
  String feasLongRunTime(int km, int x);

  /// No description provided for @feasLongRideTime.
  ///
  /// In en, this message translates to:
  /// **'The time on your long-ride day allows only {min} min – this race needs long rides of at least {target} min.'**
  String feasLongRideTime(int min, int target);

  /// No description provided for @feasOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get feasOptions;

  /// No description provided for @feasLaterDate.
  ///
  /// In en, this message translates to:
  /// **'A race on {date} or later'**
  String feasLaterDate(String date);

  /// No description provided for @feasShorter.
  ///
  /// In en, this message translates to:
  /// **'A shorter distance: {dist}'**
  String feasShorter(String dist);

  /// No description provided for @feasRunWalkFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish with run/walk – race day in your plan shows the rhythm'**
  String get feasRunWalkFinish;

  /// No description provided for @feasPlanAnyway.
  ///
  /// In en, this message translates to:
  /// **'The plan is created anyway and builds up as far as is safely possible.'**
  String get feasPlanAnyway;

  /// No description provided for @wGymDeloadNote2.
  ///
  /// In en, this message translates to:
  /// **'Deload week: weights are entered about 10 % lighter and each exercise keeps about half its work sets. Train cleanly with about 4 reps in the tank – fatigue drops and you come back stronger.'**
  String get wGymDeloadNote2;

  /// No description provided for @glossary.
  ///
  /// In en, this message translates to:
  /// **'Glossary'**
  String get glossary;

  /// No description provided for @glossaryHint.
  ///
  /// In en, this message translates to:
  /// **'Short explanations of the terms and abbreviations used in the app.'**
  String get glossaryHint;

  /// No description provided for @termWhatIs.
  ///
  /// In en, this message translates to:
  /// **'What does {term} mean?'**
  String termWhatIs(String term);

  /// No description provided for @termRpeTitle.
  ///
  /// In en, this message translates to:
  /// **'RPE – Rating of Perceived Exertion'**
  String get termRpeTitle;

  /// No description provided for @termRpeBody.
  ///
  /// In en, this message translates to:
  /// **'How hard a workout or set felt, on a scale from 1 (very easy) to 10 (maximal). 3–4 = easy, you can chat; 6–7 = hard but controlled; 9–10 = all-out.'**
  String get termRpeBody;

  /// No description provided for @termRpeTip.
  ///
  /// In en, this message translates to:
  /// **'Optional. When you enter it, the plan adapts better – e.g. easy runs that feel too hard lead to a lighter next week.'**
  String get termRpeTip;

  /// No description provided for @termRirTitle.
  ///
  /// In en, this message translates to:
  /// **'RIR – Reps in Reserve'**
  String get termRirTitle;

  /// No description provided for @termRirBody.
  ///
  /// In en, this message translates to:
  /// **'How many more reps you could have done at the end of a set. \"2 in the tank\" means you stop two reps before failure.'**
  String get termRirBody;

  /// No description provided for @termRirTip.
  ///
  /// In en, this message translates to:
  /// **'The effort chips map to it: Easy ≈ 4+, Just right ≈ 2–3, Hard ≈ 1, Limit = 0. Most sets should end with 1–3 in the tank.'**
  String get termRirTip;

  /// No description provided for @termE1rmTitle.
  ///
  /// In en, this message translates to:
  /// **'e1RM – estimated one-rep max'**
  String get termE1rmTitle;

  /// No description provided for @termE1rmBody.
  ///
  /// In en, this message translates to:
  /// **'The weight you could probably lift exactly once, calculated from a set with more reps (e.g. 80 kg × 8 ≈ 101 kg). No need to test a real max.'**
  String get termE1rmBody;

  /// No description provided for @termE1rmTip.
  ///
  /// In en, this message translates to:
  /// **'Good for comparing progress across different weights and rep counts.'**
  String get termE1rmTip;

  /// No description provided for @termVdotTitle.
  ///
  /// In en, this message translates to:
  /// **'VDOT – running fitness score'**
  String get termVdotTitle;

  /// No description provided for @termVdotBody.
  ///
  /// In en, this message translates to:
  /// **'A score by coach Jack Daniels derived from your race times. All running paces in your plan (easy, tempo, interval) are calculated from it.'**
  String get termVdotBody;

  /// No description provided for @termVdotTip.
  ///
  /// In en, this message translates to:
  /// **'+1 VDOT is roughly 1–2 % faster over any distance. It rises with consistent training and is updated when you run faster.'**
  String get termVdotTip;

  /// No description provided for @termFtpTitle.
  ///
  /// In en, this message translates to:
  /// **'FTP – Functional Threshold Power'**
  String get termFtpTitle;

  /// No description provided for @termFtpBody.
  ///
  /// In en, this message translates to:
  /// **'The power (watts) you can hold on the bike for about one hour. Bike zones such as endurance, sweet spot and threshold are percentages of it.'**
  String get termFtpBody;

  /// No description provided for @termFtpTip.
  ///
  /// In en, this message translates to:
  /// **'Without a power meter the plan uses heart rate and feel instead.'**
  String get termFtpTip;

  /// No description provided for @termCssTitle.
  ///
  /// In en, this message translates to:
  /// **'CSS – Critical Swim Speed'**
  String get termCssTitle;

  /// No description provided for @termCssBody.
  ///
  /// In en, this message translates to:
  /// **'Your threshold pace in the pool per 100 m, calculated from a 400 m and a 200 m time trial. Swim intervals are set relative to it.'**
  String get termCssBody;

  /// No description provided for @termCssTip.
  ///
  /// In en, this message translates to:
  /// **'Example: 400 m in 8:00 and 200 m in 3:40 → CSS ≈ 2:10 /100 m.'**
  String get termCssTip;

  /// No description provided for @termSupersetTitle.
  ///
  /// In en, this message translates to:
  /// **'Superset'**
  String get termSupersetTitle;

  /// No description provided for @termSupersetBody.
  ///
  /// In en, this message translates to:
  /// **'Two (or three) exercises done back to back with only a short switch, then the full rest. The app pairs opposing muscles (e.g. press + row), so each recovers while the other works.'**
  String get termSupersetBody;

  /// No description provided for @termSupersetTip.
  ///
  /// In en, this message translates to:
  /// **'Saves time without losing performance.'**
  String get termSupersetTip;

  /// No description provided for @termAmrapTitle.
  ///
  /// In en, this message translates to:
  /// **'AMRAP – as many reps as possible'**
  String get termAmrapTitle;

  /// No description provided for @termAmrapBody.
  ///
  /// In en, this message translates to:
  /// **'On the last set do as many clean reps as you can – but stop one rep before failure. The app uses the result to correct your weights.'**
  String get termAmrapBody;

  /// No description provided for @termAmrapTip.
  ///
  /// In en, this message translates to:
  /// **'Only appears when it helps: for new exercises and when you reach the top of the rep range.'**
  String get termAmrapTip;

  /// No description provided for @termVolumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get termVolumeTitle;

  /// No description provided for @termVolumeBody.
  ///
  /// In en, this message translates to:
  /// **'Weight × reps of all working sets added up (warm-ups don\'t count). For bodyweight exercises the lifted share of your body weight counts.'**
  String get termVolumeBody;

  /// No description provided for @termVolumeTip.
  ///
  /// In en, this message translates to:
  /// **'More volume is not automatically better – what matters is progress over weeks.'**
  String get termVolumeTip;

  /// No description provided for @termPhaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan phases'**
  String get termPhaseTitle;

  /// No description provided for @termPhaseBody.
  ///
  /// In en, this message translates to:
  /// **'Base: build endurance and technique, mostly easy. Build: more intensity. Peak: race-specific sessions. Taper: less volume before the race so you start fresh. Recovery week: a lighter week every 3–5 weeks so your body can adapt.'**
  String get termPhaseBody;

  /// No description provided for @termPhaseTip.
  ///
  /// In en, this message translates to:
  /// **'Recovery and taper weeks feel easy on purpose – don\'t make up for them.'**
  String get termPhaseTip;

  /// No description provided for @termZonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Intensity zones'**
  String get termZonesTitle;

  /// No description provided for @termZonesBody.
  ///
  /// In en, this message translates to:
  /// **'Training ranges from very easy to maximal, based on pace, heart rate or power. About 80 % of endurance training should be easy – that\'s what builds your base.'**
  String get termZonesBody;

  /// No description provided for @termZonesTip.
  ///
  /// In en, this message translates to:
  /// **'Tap a zone in a workout for its exact range.'**
  String get termZonesTip;

  /// No description provided for @raceSearch.
  ///
  /// In en, this message translates to:
  /// **'Find races'**
  String get raceSearch;

  /// No description provided for @raceSport.
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get raceSport;

  /// No description provided for @raceAnyDistance.
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get raceAnyDistance;

  /// No description provided for @raceRegion.
  ///
  /// In en, this message translates to:
  /// **'Region (country or city)'**
  String get raceRegion;

  /// No description provided for @raceRegionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Germany, Munich – empty = worldwide'**
  String get raceRegionHint;

  /// No description provided for @raceWindow.
  ///
  /// In en, this message translates to:
  /// **'Time window'**
  String get raceWindow;

  /// No description provided for @raceNextMonths.
  ///
  /// In en, this message translates to:
  /// **'{n} months'**
  String raceNextMonths(int n);

  /// No description provided for @raceSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search the web'**
  String get raceSearchButton;

  /// No description provided for @raceIntro.
  ///
  /// In en, this message translates to:
  /// **'Searches the web for upcoming races with AI – or open a race calendar directly.'**
  String get raceIntro;

  /// No description provided for @raceSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching the web for races…'**
  String get raceSearching;

  /// No description provided for @raceWebResults.
  ///
  /// In en, this message translates to:
  /// **'Web results (AI search)'**
  String get raceWebResults;

  /// No description provided for @raceDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Found on the web by AI – no guarantee. Check date and details on the organiser\'s page before you sign up.'**
  String get raceDisclaimer;

  /// No description provided for @raceOrganiserPage.
  ///
  /// In en, this message translates to:
  /// **'Organiser page'**
  String get raceOrganiserPage;

  /// No description provided for @raceSetAsGoal.
  ///
  /// In en, this message translates to:
  /// **'Set as goal'**
  String get raceSetAsGoal;

  /// No description provided for @raceGoalSet.
  ///
  /// In en, this message translates to:
  /// **'Race set as your goal'**
  String get raceGoalSet;

  /// No description provided for @raceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No races found for these filters. Try a longer time window or a wider region – or browse a race calendar.'**
  String get raceEmpty;

  /// No description provided for @raceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI web search is not available right now (quota or plan of the AI service). Browse a race calendar instead.'**
  String get raceUnavailable;

  /// No description provided for @raceError.
  ///
  /// In en, this message translates to:
  /// **'The search failed. Check your connection and try again – or browse a race calendar.'**
  String get raceError;

  /// No description provided for @raceBadResponse.
  ///
  /// In en, this message translates to:
  /// **'The search returned no usable result. Try again – or browse a race calendar.'**
  String get raceBadResponse;

  /// No description provided for @raceRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get raceRetry;

  /// No description provided for @racePortals.
  ///
  /// In en, this message translates to:
  /// **'Race calendars'**
  String get racePortals;

  /// No description provided for @racePortalsHint.
  ///
  /// In en, this message translates to:
  /// **'Opens in the browser, filtered where the site supports it.'**
  String get racePortalsHint;

  /// No description provided for @raceSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get raceSources;

  /// No description provided for @raceGoogleSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Google searches'**
  String get raceGoogleSuggestions;

  /// No description provided for @recalGapsTitle.
  ///
  /// In en, this message translates to:
  /// **'Gaps in the plan'**
  String get recalGapsTitle;

  /// No description provided for @recalWhyGaps.
  ///
  /// In en, this message translates to:
  /// **'Sessions the plan expects are missing ({n}) – refills are proposed below.'**
  String recalWhyGaps(int n);

  /// No description provided for @recalWhyGapsOmitted.
  ///
  /// In en, this message translates to:
  /// **'Some missing sessions are not refilled: they would sit next to a race or the week already has its planned volume.'**
  String get recalWhyGapsOmitted;

  /// No description provided for @recalAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get recalAdded;

  /// No description provided for @recalGapMissing.
  ///
  /// In en, this message translates to:
  /// **'The planned session on {day} is missing – added back.'**
  String recalGapMissing(String day);

  /// No description provided for @recalGapEmptyWeek.
  ///
  /// In en, this message translates to:
  /// **'This week has no sessions – the planned one is added back.'**
  String get recalGapEmptyWeek;

  /// No description provided for @recalGapEnded.
  ///
  /// In en, this message translates to:
  /// **'The plan ended earlier – continued here.'**
  String get recalGapEnded;

  /// No description provided for @recalGapDowngraded.
  ///
  /// In en, this message translates to:
  /// **'Easy instead of hard: the day next to it is already hard.'**
  String get recalGapDowngraded;

  /// No description provided for @recalGapEased.
  ///
  /// In en, this message translates to:
  /// **'Easy, because the plan is lighter right now.'**
  String get recalGapEased;

  /// No description provided for @recalGapShortened.
  ///
  /// In en, this message translates to:
  /// **'Shorter, so the week and the long run stay within safe limits.'**
  String get recalGapShortened;

  /// No description provided for @feasTitleTarget.
  ///
  /// In en, this message translates to:
  /// **'Target time check'**
  String get feasTitleTarget;

  /// No description provided for @feasTargetAmbitious.
  ///
  /// In en, this message translates to:
  /// **'Ambitious: {goal} needs more than the usual progress in the time left (today ~{now}, expected by race day ~{pred}). Possible with very consistent training.'**
  String feasTargetAmbitious(String goal, String now, String pred);

  /// No description provided for @feasTargetUnrealistic.
  ///
  /// In en, this message translates to:
  /// **'{goal} is unlikely by race day: today you are at ~{now}, realistic by race day is ~{pred}.'**
  String feasTargetUnrealistic(String goal, String now, String pred);

  /// No description provided for @feasTargetOkLine.
  ///
  /// In en, this message translates to:
  /// **'Target {goal} is realistic: today ~{now}, expected on race day ~{pred}.'**
  String feasTargetOkLine(String goal, String now, String pred);

  /// No description provided for @feasTargetLater.
  ///
  /// In en, this message translates to:
  /// **'{goal} becomes realistic with a race on or after {date}'**
  String feasTargetLater(String goal, String date);

  /// No description provided for @feasTargetSuggest.
  ///
  /// In en, this message translates to:
  /// **'a target of {goal}'**
  String feasTargetSuggest(String goal);

  /// No description provided for @feasEstimated.
  ///
  /// In en, this message translates to:
  /// **'Rough estimate – enter a race time in the plan settings for a precise check.'**
  String get feasEstimated;

  /// No description provided for @adjustTargetTo.
  ///
  /// In en, this message translates to:
  /// **'Set target to {goal}'**
  String adjustTargetTo(String goal);

  /// No description provided for @targetAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Target time set to {goal}'**
  String targetAdjusted(String goal);

  /// No description provided for @planToEventPre.
  ///
  /// In en, this message translates to:
  /// **'{weeks} weeks to race day: {n} weeks of base building first, then the {x}-week race plan.'**
  String planToEventPre(int weeks, int n, int x);

  /// No description provided for @planKeepsDone.
  ///
  /// In en, this message translates to:
  /// **'Completed workouts are kept – only upcoming planned workouts are replaced.'**
  String get planKeepsDone;

  /// No description provided for @planEventTooFar.
  ///
  /// In en, this message translates to:
  /// **'Your event is more than 52 weeks away – the plan uses the length below for now.'**
  String get planEventTooFar;

  /// No description provided for @planUntilRace.
  ///
  /// In en, this message translates to:
  /// **'The plan runs until race day ({weeks} weeks).'**
  String planUntilRace(int weeks);

  /// No description provided for @alignPlanToEvent.
  ///
  /// In en, this message translates to:
  /// **'Align training plan to this race'**
  String get alignPlanToEvent;

  /// No description provided for @alignPlanToEventSub.
  ///
  /// In en, this message translates to:
  /// **'The plan runs until race day; completed workouts are kept.'**
  String get alignPlanToEventSub;

  /// No description provided for @alignNeedsDistance.
  ///
  /// In en, this message translates to:
  /// **'Choose a race distance to align the plan.'**
  String get alignNeedsDistance;

  /// No description provided for @planAligned.
  ///
  /// In en, this message translates to:
  /// **'Plan aligned: {weeks} weeks to race day'**
  String planAligned(int weeks);

  /// No description provided for @goalStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Where I stand'**
  String get goalStatusTitle;

  /// No description provided for @goalCountdown.
  ///
  /// In en, this message translates to:
  /// **'{weeks} wk {days} d'**
  String goalCountdown(int weeks, int days);

  /// No description provided for @goalCountdownDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String goalCountdownDays(int days);

  /// No description provided for @goalToRace.
  ///
  /// In en, this message translates to:
  /// **'to race day'**
  String get goalToRace;

  /// No description provided for @goalForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get goalForecast;

  /// No description provided for @goalTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalTargetLabel;

  /// No description provided for @goalToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get goalToday;

  /// No description provided for @goalFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get goalFinish;

  /// No description provided for @fcAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead of plan'**
  String get fcAhead;

  /// No description provided for @fcOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get fcOnTrack;

  /// No description provided for @fcSlightlyBehind.
  ///
  /// In en, this message translates to:
  /// **'Slightly behind'**
  String get fcSlightlyBehind;

  /// No description provided for @fcAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Goal at risk'**
  String get fcAtRisk;

  /// No description provided for @fcEarly.
  ///
  /// In en, this message translates to:
  /// **'Too early to tell'**
  String get fcEarly;

  /// No description provided for @fcEarlySub.
  ///
  /// In en, this message translates to:
  /// **'After your first workouts the forecast uses your training data.'**
  String get fcEarlySub;

  /// No description provided for @fcRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Your goal is at risk'**
  String get fcRiskTitle;

  /// No description provided for @fcRiskBody.
  ///
  /// In en, this message translates to:
  /// **'Recent training did not go as planned. Forecast for race day: ~{pred} instead of {goal}.'**
  String fcRiskBody(String pred, String goal);

  /// No description provided for @fcRiskBodyFinish.
  ///
  /// In en, this message translates to:
  /// **'Recent training did not go as planned – consistent training now keeps the race comfortable.'**
  String get fcRiskBodyFinish;

  /// No description provided for @fcAheadBody.
  ///
  /// In en, this message translates to:
  /// **'You are faster than planned – {goal} looks realistic.'**
  String fcAheadBody(String goal);

  /// No description provided for @fcReasonMissed.
  ///
  /// In en, this message translates to:
  /// **'{pct} % of the planned training done'**
  String fcReasonMissed(int pct);

  /// No description provided for @fcReasonSlower.
  ///
  /// In en, this message translates to:
  /// **'Key runs slower than planned'**
  String get fcReasonSlower;

  /// No description provided for @fcReasonFaster.
  ///
  /// In en, this message translates to:
  /// **'Key runs faster than planned'**
  String get fcReasonFaster;

  /// No description provided for @fcReasonLongRun.
  ///
  /// In en, this message translates to:
  /// **'Long runs shorter than planned'**
  String get fcReasonLongRun;

  /// No description provided for @fcReasonBreak.
  ///
  /// In en, this message translates to:
  /// **'Training break – fitness drops after ~10 days without running'**
  String get fcReasonBreak;

  /// No description provided for @fcRange.
  ///
  /// In en, this message translates to:
  /// **'Range {fast} – {slow}'**
  String fcRange(String fast, String slow);

  /// No description provided for @fcConfLow.
  ///
  /// In en, this message translates to:
  /// **'rough estimate'**
  String get fcConfLow;

  /// No description provided for @fcConfMedium.
  ///
  /// In en, this message translates to:
  /// **'from your sessions'**
  String get fcConfMedium;

  /// No description provided for @fcConfHigh.
  ///
  /// In en, this message translates to:
  /// **'from a race effort'**
  String get fcConfHigh;

  /// No description provided for @fcInRecal.
  ///
  /// In en, this message translates to:
  /// **'Goal forecast'**
  String get fcInRecal;

  /// No description provided for @goalPhaseBaseShort.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get goalPhaseBaseShort;

  /// No description provided for @goalPhaseBuildShort.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get goalPhaseBuildShort;

  /// No description provided for @goalPhasePeakShort.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get goalPhasePeakShort;

  /// No description provided for @goalPhaseTaperShort.
  ///
  /// In en, this message translates to:
  /// **'Taper'**
  String get goalPhaseTaperShort;

  /// No description provided for @goalCompletion.
  ///
  /// In en, this message translates to:
  /// **'Plan completion'**
  String get goalCompletion;

  /// No description provided for @goalLongestRun.
  ///
  /// In en, this message translates to:
  /// **'Longest run (6 weeks)'**
  String get goalLongestRun;

  /// No description provided for @goalLongRunNeed.
  ///
  /// In en, this message translates to:
  /// **'needed before the taper: {km} km'**
  String goalLongRunNeed(int km);

  /// No description provided for @goalFitnessTrend.
  ///
  /// In en, this message translates to:
  /// **'Fitness trend (VDOT)'**
  String get goalFitnessTrend;

  /// No description provided for @goalTrendPlanned.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get goalTrendPlanned;

  /// No description provided for @goalTrendActual.
  ///
  /// In en, this message translates to:
  /// **'Your sessions'**
  String get goalTrendActual;

  /// No description provided for @goalTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'The trend appears after a few tempo or interval runs.'**
  String get goalTrendEmpty;

  /// No description provided for @goalPhaseOutlook.
  ///
  /// In en, this message translates to:
  /// **'Phases & expected fitness'**
  String get goalPhaseOutlook;

  /// No description provided for @goalPhaseNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get goalPhaseNow;

  /// No description provided for @goalWeeksN.
  ///
  /// In en, this message translates to:
  /// **'{weeks} wk'**
  String goalWeeksN(int weeks);

  /// No description provided for @goalEditPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan settings'**
  String get goalEditPlan;

  /// No description provided for @replacePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Start plan over?'**
  String get replacePlanTitle;

  /// No description provided for @replacePlanBody.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 planned workout from {date} will be replaced.} other{{n} planned workouts from {date} will be replaced.}}'**
  String replacePlanBody(String date, int n);

  /// No description provided for @replacePlanKeeps.
  ///
  /// In en, this message translates to:
  /// **'Completed workouts and stats stay.'**
  String get replacePlanKeeps;

  /// No description provided for @replaceFromToday.
  ///
  /// In en, this message translates to:
  /// **'From today'**
  String get replaceFromToday;

  /// No description provided for @replaceFromMonday.
  ///
  /// In en, this message translates to:
  /// **'From next Monday'**
  String get replaceFromMonday;

  /// No description provided for @replacePlanOk.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replacePlanOk;

  /// No description provided for @startOverTitle.
  ///
  /// In en, this message translates to:
  /// **'Start plan over'**
  String get startOverTitle;

  /// No description provided for @startOverButton.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOverButton;

  /// No description provided for @wRecoveryWeekNote2.
  ///
  /// In en, this message translates to:
  /// **'Recovery week: volume is reduced on purpose – keep it easy even if you feel fresh. This is when your body absorbs the last weeks.'**
  String get wRecoveryWeekNote2;

  /// No description provided for @wGymDeloadNote3.
  ///
  /// In en, this message translates to:
  /// **'Recovery week: weights are entered about 10 % lighter and each exercise keeps about half its work sets. Train cleanly with about 4 reps in the tank – fatigue drops and you come back stronger.'**
  String get wGymDeloadNote3;

  /// No description provided for @eventQuestion.
  ///
  /// In en, this message translates to:
  /// **'Training for a race?'**
  String get eventQuestion;

  /// No description provided for @noPlanYet.
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get noPlanYet;

  /// No description provided for @noPlanYetSub.
  ///
  /// In en, this message translates to:
  /// **'Strive builds one from your goal, training days and time.'**
  String get noPlanYetSub;

  /// No description provided for @todayNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {title} · {day}'**
  String todayNext(String title, String day);

  /// No description provided for @todayHiddenByFilter.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 workout hidden by filter} other{{n} workouts hidden by filter}}'**
  String todayHiddenByFilter(int n);

  /// No description provided for @todayHiddenByFilterSub.
  ///
  /// In en, this message translates to:
  /// **'The sport filter is on – today is not a rest day.'**
  String get todayHiddenByFilterSub;

  /// No description provided for @showAllSports.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAllSports;

  /// No description provided for @hintPlannedDry.
  ///
  /// In en, this message translates to:
  /// **'Planned today: {sport} – dry until {time}'**
  String hintPlannedDry(String sport, String time);

  /// No description provided for @hintPlannedBest.
  ///
  /// In en, this message translates to:
  /// **'Planned today: {sport} – best at {time}'**
  String hintPlannedBest(String sport, String time);

  /// No description provided for @hintPlannedStorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm – move your {sport} indoors or later'**
  String hintPlannedStorm(String sport);

  /// No description provided for @hintPlannedNeutral.
  ///
  /// In en, this message translates to:
  /// **'Planned today: {sport} – dress for the weather'**
  String hintPlannedNeutral(String sport);

  /// No description provided for @summaryEffortTitle.
  ///
  /// In en, this message translates to:
  /// **'How hard was it? Your plan adapts to it.'**
  String get summaryEffortTitle;

  /// No description provided for @summaryEffortHint.
  ///
  /// In en, this message translates to:
  /// **'Optional · 1 = very easy, 10 = all-out'**
  String get summaryEffortHint;

  /// No description provided for @summaryEffortPrefilled.
  ///
  /// In en, this message translates to:
  /// **'Preselected from your exercise ratings – tap to change.'**
  String get summaryEffortPrefilled;

  /// No description provided for @autoAdjBanner.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 workout adapted automatically – review} other{{n} workouts adapted automatically – review}}'**
  String autoAdjBanner(int n);

  /// No description provided for @autoAdjSheetIntro.
  ///
  /// In en, this message translates to:
  /// **'After your last workouts the plan adapted these sessions. Keep them or undo single changes.'**
  String get autoAdjSheetIntro;

  /// No description provided for @planHistory.
  ///
  /// In en, this message translates to:
  /// **'Plan history'**
  String get planHistory;

  /// No description provided for @planHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plan changes yet. Automatic adjustments, “Review plan”, “Adjust week” and “Not feeling 100%?” show up here.'**
  String get planHistoryEmpty;

  /// No description provided for @planLogRecal.
  ///
  /// In en, this message translates to:
  /// **'Plan reviewed'**
  String get planLogRecal;

  /// No description provided for @planLogReadiness.
  ///
  /// In en, this message translates to:
  /// **'Not feeling 100%: {why}'**
  String planLogReadiness(String why);

  /// No description provided for @planLogWeekReason.
  ///
  /// In en, this message translates to:
  /// **'Missed workouts moved within the week or dropped.'**
  String get planLogWeekReason;

  /// No description provided for @planLogUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get planLogUndone;

  /// No description provided for @planLogChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed since – no undo'**
  String get planLogChanged;

  /// No description provided for @planLogNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get planLogNew;

  /// No description provided for @planLogDropped.
  ///
  /// In en, this message translates to:
  /// **'dropped'**
  String get planLogDropped;

  /// No description provided for @planLogUndoDone.
  ///
  /// In en, this message translates to:
  /// **'Change undone'**
  String get planLogUndoDone;

  /// No description provided for @notFitButton.
  ///
  /// In en, this message translates to:
  /// **'Not feeling 100%?'**
  String get notFitButton;

  /// No description provided for @notFitIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell the plan how you feel – it suggests a safe change. Nothing changes until you apply it.'**
  String get notFitIntro;

  /// No description provided for @notFitSick.
  ///
  /// In en, this message translates to:
  /// **'Sick'**
  String get notFitSick;

  /// No description provided for @notFitPain.
  ///
  /// In en, this message translates to:
  /// **'Pain'**
  String get notFitPain;

  /// No description provided for @notFitTired.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get notFitTired;

  /// No description provided for @notFitTime.
  ///
  /// In en, this message translates to:
  /// **'Short on time'**
  String get notFitTime;

  /// No description provided for @notFitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Time available'**
  String get notFitMinutes;

  /// No description provided for @notFitNoChange.
  ///
  /// In en, this message translates to:
  /// **'No change needed – the workout fits as planned.'**
  String get notFitNoChange;

  /// No description provided for @notFitPreview.
  ///
  /// In en, this message translates to:
  /// **'Suggested change'**
  String get notFitPreview;

  /// No description provided for @notFitApplied.
  ///
  /// In en, this message translates to:
  /// **'Plan adjusted'**
  String get notFitApplied;

  /// No description provided for @notFitHintAboveNeck.
  ///
  /// In en, this message translates to:
  /// **'Above-the-neck rule: only a runny nose or a mild sore throat and no fever – rest or at most a short, easy session. Fever, aching muscles, chest or stomach symptoms: no training until you are well.'**
  String get notFitHintAboveNeck;

  /// No description provided for @notFitHintReturn.
  ///
  /// In en, this message translates to:
  /// **'Back after being sick: hard sessions of the next two days become easy. After 10 days or more off, use “Review plan” – it rebuilds at 50–70 % of your previous volume.'**
  String get notFitHintReturn;

  /// No description provided for @notFitHintPainRule.
  ///
  /// In en, this message translates to:
  /// **'Pain up to 3/10 that has settled by the next morning is acceptable. Stop if it gets worse during the session.'**
  String get notFitHintPainRule;

  /// No description provided for @notFitHintDoctor.
  ///
  /// In en, this message translates to:
  /// **'If the pain lasts more than a few days or keeps coming back, have it checked by a doctor or physiotherapist.'**
  String get notFitHintDoctor;

  /// No description provided for @notFitHintSwapped.
  ///
  /// In en, this message translates to:
  /// **'Swapped for low-impact cross-training: it keeps your endurance without the impact of running.'**
  String get notFitHintSwapped;

  /// No description provided for @notFitHintKeyEasy.
  ///
  /// In en, this message translates to:
  /// **'Tired: the key workout becomes an easy session (about 20 % shorter). Quality on tired legs adds fatigue, not fitness.'**
  String get notFitHintKeyEasy;

  /// No description provided for @notFitHintShorter.
  ///
  /// In en, this message translates to:
  /// **'Tired: the easy session is about 25 % shorter – keep it truly easy.'**
  String get notFitHintShorter;

  /// No description provided for @notFitHintGymLighter.
  ///
  /// In en, this message translates to:
  /// **'About a third fewer sets with the same weights; end each set with 2–3 reps in reserve. Leave out exercises that hurt.'**
  String get notFitHintGymLighter;

  /// No description provided for @notFitHintGymShorter.
  ///
  /// In en, this message translates to:
  /// **'Fewer sets to fit your time – main lifts first. A few hard sets keep most of the effect.'**
  String get notFitHintGymShorter;

  /// No description provided for @notFitHintTime.
  ///
  /// In en, this message translates to:
  /// **'Shortened to your time: warm-up and cool-down stay, the main part gets shorter.'**
  String get notFitHintTime;

  /// No description provided for @askCoachAbout.
  ///
  /// In en, this message translates to:
  /// **'Ask the coach'**
  String get askCoachAbout;

  /// No description provided for @coachExplainWorkout.
  ///
  /// In en, this message translates to:
  /// **'Explain the workout “{title}” on {date} to me'**
  String coachExplainWorkout(String title, String date);

  /// No description provided for @reserveLabel.
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get reserveLabel;

  /// No description provided for @reserveN.
  ///
  /// In en, this message translates to:
  /// **'Reserve {value}'**
  String reserveN(String value);

  /// No description provided for @reserveHint.
  ///
  /// In en, this message translates to:
  /// **'reps in the tank'**
  String get reserveHint;

  /// No description provided for @logRirSetting.
  ///
  /// In en, this message translates to:
  /// **'Log reserve per set'**
  String get logRirSetting;

  /// No description provided for @logRirSettingSub.
  ///
  /// In en, this message translates to:
  /// **'Reps left in the tank after each set (RIR). The rating per exercise stays.'**
  String get logRirSettingSub;

  /// No description provided for @wRaceGoalStart.
  ///
  /// In en, this message translates to:
  /// **'Goal {goal} – start at {pace}'**
  String wRaceGoalStart(String goal, String pace);

  /// No description provided for @wProgressionRun.
  ///
  /// In en, this message translates to:
  /// **'Progression run'**
  String get wProgressionRun;

  /// No description provided for @wProgressionRunDesc.
  ///
  /// In en, this message translates to:
  /// **'Start easy, run the last part at a steady marathon-pace effort – aerobic strength without a hard interval day.'**
  String get wProgressionRunDesc;

  /// No description provided for @stepProgressionNote.
  ///
  /// In en, this message translates to:
  /// **'Steady – marathon-pace effort, still controlled'**
  String get stepProgressionNote;

  /// No description provided for @wLongRunProgression.
  ///
  /// In en, this message translates to:
  /// **'Progression long run'**
  String get wLongRunProgression;

  /// No description provided for @wLongRunProgressionDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy long run, the last part at a steady marathon-pace effort – fatigue resistance without a race-pace session.'**
  String get wLongRunProgressionDesc;

  /// No description provided for @wLongRunShortDesc.
  ///
  /// In en, this message translates to:
  /// **'Shorter long run this week: a lighter week between the longest runs – the body absorbs the load before the next step.'**
  String get wLongRunShortDesc;

  /// No description provided for @wGoalPaceSet.
  ///
  /// In en, this message translates to:
  /// **'Goal pace {reps} × {dist} km'**
  String wGoalPaceSet(int reps, String dist);

  /// No description provided for @wGoalPaceSetDesc.
  ///
  /// In en, this message translates to:
  /// **'Repeats at your goal race pace with short jog breaks – the race-specific session: rhythm, pace judgement, confidence.'**
  String get wGoalPaceSetDesc;

  /// No description provided for @stepGoalPaceNote.
  ///
  /// In en, this message translates to:
  /// **'Goal race pace – even and controlled'**
  String get stepGoalPaceNote;

  /// No description provided for @wCruiseKm.
  ///
  /// In en, this message translates to:
  /// **'Cruise intervals {reps} × {dist} km'**
  String wCruiseKm(int reps, String dist);

  /// No description provided for @wRideTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo {reps} × {min} min'**
  String wRideTempo(int reps, int min);

  /// No description provided for @wRideTempoDesc.
  ///
  /// In en, this message translates to:
  /// **'Race-specific tempo at 75–85 % FTP – the effort of a 70.3 bike leg: steady, aero, fuelled.'**
  String get wRideTempoDesc;

  /// No description provided for @stepRideTempoNote.
  ///
  /// In en, this message translates to:
  /// **'Tempo – 75–85 % FTP, steady'**
  String get stepRideTempoNote;

  /// No description provided for @sprintTri.
  ///
  /// In en, this message translates to:
  /// **'Sprint triathlon'**
  String get sprintTri;

  /// No description provided for @distUltra50.
  ///
  /// In en, this message translates to:
  /// **'Ultra 50 km'**
  String get distUltra50;

  /// No description provided for @distIronman.
  ///
  /// In en, this message translates to:
  /// **'Ironman (full distance)'**
  String get distIronman;

  /// No description provided for @distDuSprint.
  ///
  /// In en, this message translates to:
  /// **'Duathlon sprint (5/20/2.5)'**
  String get distDuSprint;

  /// No description provided for @distDuStandard.
  ///
  /// In en, this message translates to:
  /// **'Duathlon standard (10/40/5)'**
  String get distDuStandard;

  /// No description provided for @distRide100.
  ///
  /// In en, this message translates to:
  /// **'Cycling 100 km'**
  String get distRide100;

  /// No description provided for @distRide160.
  ///
  /// In en, this message translates to:
  /// **'Cycling 160 km'**
  String get distRide160;

  /// No description provided for @distSwim1500.
  ///
  /// In en, this message translates to:
  /// **'Open water 1.5 km'**
  String get distSwim1500;

  /// No description provided for @distSwim3800.
  ///
  /// In en, this message translates to:
  /// **'Open water 3.8 km'**
  String get distSwim3800;

  /// No description provided for @distSwim5000.
  ///
  /// In en, this message translates to:
  /// **'Open water 5 km'**
  String get distSwim5000;

  /// No description provided for @moreDistances.
  ///
  /// In en, this message translates to:
  /// **'More distances…'**
  String get moreDistances;

  /// No description provided for @backAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get backAgainToExit;
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
