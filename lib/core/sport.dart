import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'theme.dart';

enum Sport { gym, run, ride, swim }

extension SportX on Sport {
  Color get color => switch (this) {
    Sport.gym => AppColors.gym,
    Sport.run => AppColors.run,
    Sport.ride => AppColors.ride,
    Sport.swim => AppColors.swim,
  };

  IconData get icon => switch (this) {
    Sport.gym => Icons.fitness_center_rounded,
    Sport.run => Icons.directions_run_rounded,
    Sport.ride => Icons.directions_bike_rounded,
    Sport.swim => Icons.pool_rounded,
  };

  String label(AppLocalizations l) => switch (this) {
    Sport.gym => l.sportGym,
    Sport.run => l.sportRun,
    Sport.ride => l.sportRide,
    Sport.swim => l.sportSwim,
  };

  bool get isCardio => this != Sport.gym;

  /// Whether pace (min/km, min/100m) is more meaningful than speed.
  bool get usesPace => this == Sport.run || this == Sport.swim;

  static Sport parse(String? s) => Sport.values.firstWhere((e) => e.name == s, orElse: () => Sport.gym);
}

/// Primary training focus chosen in onboarding.
enum TrainingFocus { gym, run, ride, swim, hybrid, duathlon, triathlon }

extension TrainingFocusX on TrainingFocus {
  String label(AppLocalizations l) => switch (this) {
    TrainingFocus.gym => l.sportGym,
    TrainingFocus.run => l.sportRun,
    TrainingFocus.ride => l.sportRide,
    TrainingFocus.swim => l.sportSwim,
    TrainingFocus.hybrid => l.focusHybrid,
    TrainingFocus.duathlon => l.focusDuathlon,
    TrainingFocus.triathlon => l.focusTriathlon,
  };

  List<Sport> get sports => switch (this) {
    TrainingFocus.gym => [Sport.gym],
    TrainingFocus.run => [Sport.run],
    TrainingFocus.ride => [Sport.ride],
    TrainingFocus.swim => [Sport.swim],
    TrainingFocus.hybrid => [Sport.gym, Sport.run],
    TrainingFocus.duathlon => [Sport.run, Sport.ride],
    TrainingFocus.triathlon => [Sport.swim, Sport.ride, Sport.run],
  };

  IconData get icon => switch (this) {
    TrainingFocus.gym => Icons.fitness_center_rounded,
    TrainingFocus.run => Icons.directions_run_rounded,
    TrainingFocus.ride => Icons.directions_bike_rounded,
    TrainingFocus.swim => Icons.pool_rounded,
    TrainingFocus.hybrid => Icons.bolt_rounded,
    TrainingFocus.duathlon => Icons.alt_route_rounded,
    TrainingFocus.triathlon => Icons.emoji_events_rounded,
  };

  static TrainingFocus parse(String? s) => TrainingFocus.values.firstWhere((e) => e.name == s, orElse: () => TrainingFocus.gym);
}

String intensityLabel(AppLocalizations l, String i) => switch (i) {
  'easy' => l.intensityEasy,
  'moderate' => l.intensityModerate,
  'tempo' => l.intensityTempo,
  'intervals' => l.intensityIntervals,
  'long' => l.intensityLong,
  'technique' => l.intensityTechnique,
  _ => i,
};

const intensities = ['easy', 'moderate', 'tempo', 'intervals', 'long', 'technique'];
