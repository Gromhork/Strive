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

  /// Training focus that plans for a race of this sport (running: keeps a running /
  /// hybrid / gym focus, see [eventFitsFocus]).
  TrainingFocus get focus => switch (this) {
    EventSport.run => TrainingFocus.run,
    EventSport.triathlon => TrainingFocus.triathlon,
    EventSport.duathlon => TrainingFocus.duathlon,
    EventSport.ride => TrainingFocus.ride,
    EventSport.swim => TrainingFocus.swim,
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
/// triathlon goal on a running plan (or a marathon on a cycling plan) makes no sense. A pure
/// gym plan trains for no race at all: a 10 km after 17 weeks without a single run was planned
/// as "race + shake-out" (audit UX-1) – a running race needs the hybrid (or running) focus.
bool eventFitsFocus(String? key, TrainingFocus? focus) {
  final d = eventDistanceOf(key);
  return d == null || (focus != TrainingFocus.gym && d.sport == EventSportX.fromFocus(focus));
}

/// The training focus a plan for the race [key] needs: [current] when the race fits it, a gym
/// focus keeps its strength work as hybrid for a running race, else the race's own focus.
TrainingFocus focusForRace(String? key, TrainingFocus current) {
  final d = eventDistanceOf(key);
  if (d == null || eventFitsFocus(key, current)) return current;
  if (current == TrainingFocus.gym && d.sport == EventSport.run) return TrainingFocus.hybrid;
  return d.sport.focus;
}

/// Legs or total distance of a race distance, e.g. "0,75 / 20 / 5 km" or "21,1 km".
String eventDistanceDetail(EventDistance d) =>
    d.legs.isNotEmpty ? '${d.legs.map((v) => Units.num(v, 2)).join(' / ')} km' : '${Units.num(d.km, 1)} km';
