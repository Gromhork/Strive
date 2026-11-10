import '../l10n/gen/app_localizations.dart';

/// Discipline of a race distance.
enum EventSport { run, triathlon, duathlon, ride, swim }

/// One race distance the app can plan for. [key] is what is stored in
/// `AthleteData.eventDistance`; [legs] are the distances of the disciplines in km
/// (triathlon: swim / bike / run, duathlon: run / bike / run).
class EventDistance {
  const EventDistance(this.key, this.sport, this.km, {this.legs = const [], this.primary = false});

  final String key;
  final EventSport sport;

  /// Total distance in km.
  final double km;
  final List<double> legs;

  /// Shown directly as a chip; the others sit behind "More distances…".
  final bool primary;

  String label(AppLocalizations l) => eventDistanceLabel(l, key);
}

/// Every race distance, grouped by sport, most common first. Keep keys stable – they
/// are stored in Firestore.
const eventDistances = <EventDistance>[
  // Running
  EventDistance('5k', EventSport.run, 5, primary: true),
  EventDistance('10k', EventSport.run, 10, primary: true),
  EventDistance('hm', EventSport.run, 21.0975, primary: true),
  EventDistance('m', EventSport.run, 42.195, primary: true),
  EventDistance('ultra50', EventSport.run, 50),
  // Triathlon
  EventDistance('sprint', EventSport.triathlon, 25.75, legs: [0.75, 20, 5], primary: true),
  EventDistance('olympic', EventSport.triathlon, 51.5, legs: [1.5, 40, 10], primary: true),
  EventDistance('70.3', EventSport.triathlon, 113, legs: [1.9, 90, 21.1], primary: true),
  EventDistance('ironman', EventSport.triathlon, 226, legs: [3.8, 180, 42.2]),
  // Duathlon
  EventDistance('du_sprint', EventSport.duathlon, 27.5, legs: [5, 20, 2.5], primary: true),
  EventDistance('du_standard', EventSport.duathlon, 55, legs: [10, 40, 5], primary: true),
  // Cycling
  EventDistance('ride100', EventSport.ride, 100, primary: true),
  EventDistance('ride160', EventSport.ride, 160),
  // Open-water swimming
  EventDistance('swim1500', EventSport.swim, 1.5, primary: true),
  EventDistance('swim3800', EventSport.swim, 3.8),
  EventDistance('swim5000', EventSport.swim, 5),
];

EventDistance? eventDistanceOf(String? key) => eventDistances.where((d) => d.key == key).firstOrNull;

List<EventDistance> eventDistancesFor(EventSport sport) => eventDistances.where((d) => d.sport == sport).toList();

String eventDistanceLabel(AppLocalizations l, String key) => switch (key) {
  '5k' => '5 km',
  '10k' => '10 km',
  'hm' => l.halfMarathon,
  'm' => l.marathon,
  'ultra50' => l.distUltra50,
  'sprint' => l.sprintTri,
  'olympic' => l.olympicTri,
  '70.3' => l.middleDistance,
  'ironman' => l.distIronman,
  'du_sprint' => l.distDuSprint,
  'du_standard' => l.distDuStandard,
  'ride100' => l.distRide100,
  'ride160' => l.distRide160,
  'swim1500' => l.distSwim1500,
  'swim3800' => l.distSwim3800,
  'swim5000' => l.distSwim5000,
  _ => key,
};
