import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'event_distances.dart';
import 'format.dart';
import 'sport.dart';

/// UI and training helpers for [EventSport].
extension EventSportX on EventSport {
  String label(AppLocalizations l) => switch (this) {
    EventSport.run => l.sportRun,
    EventSport.triathlon => l.focusTriathlon,
    EventSport.duathlon => l.focusDuathlon,
    EventSport.ride => l.sportRide,
    EventSport.swim => l.openWater,
  };

  IconData get icon => switch (this) {
    EventSport.run => Sport.run.icon,
    EventSport.triathlon => TrainingFocus.triathlon.icon,
    EventSport.duathlon => TrainingFocus.duathlon.icon,
    EventSport.ride => Sport.ride.icon,
    EventSport.swim => Sport.swim.icon,
  };

  /// Main training sport of a race (stored on an event goal).
  Sport get sport => switch (this) {
    EventSport.ride => Sport.ride,
    EventSport.swim => Sport.swim,
    _ => Sport.run,
  };

  /// Race sport for a training focus (gym / hybrid / no focus: running).
  static EventSport fromFocus(TrainingFocus? f) => switch (f) {
    TrainingFocus.triathlon => EventSport.triathlon,
    TrainingFocus.duathlon => EventSport.duathlon,
    TrainingFocus.ride => EventSport.ride,
    TrainingFocus.swim => EventSport.swim,
    _ => EventSport.run,
  };
}

/// Whether the race distance [key] belongs to the sport of the training [focus] – a
/// triathlon goal on a running plan (or a marathon on a cycling plan) makes no sense.
bool eventFitsFocus(String? key, TrainingFocus? focus) {
  final d = eventDistanceOf(key);
  return d == null || d.sport == EventSportX.fromFocus(focus);
}

/// Legs or total distance of a race distance, e.g. "0,75 / 20 / 5 km" or "21,1 km".
String eventDistanceDetail(EventDistance d) =>
    d.legs.isNotEmpty ? '${d.legs.map((v) => Units.num(v, 2)).join(' / ')} km' : '${Units.num(d.km, 1)} km';
