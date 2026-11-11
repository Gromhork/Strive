import '../core/sport.dart';

/// Plausibility of a session entered or corrected by hand (pure, unit-tested).
///
/// * [endsInFuture]: start + duration lies in the future – a typo in the start or the duration
///   (a workout can't end after "now"); a minute of slack for the clock.
/// * [implausiblePace]: the average pace / speed is outside of what any athlete does for the
///   sport (faster than world-record pace or slower than walking / drifting) – most likely a
///   wrong distance or duration. Only a hint: the athlete may know better (a short sprint test).
class SessionCheck {
  const SessionCheck({required this.endsInFuture, required this.implausiblePace});
  final bool endsInFuture;
  final bool implausiblePace;

  static SessionCheck of(Sport sport, DateTime start, int durationSec, double distanceM, {DateTime? now}) {
    final end = start.add(Duration(seconds: durationSec)); // time span
    final future = end.isAfter((now ?? DateTime.now()).add(const Duration(minutes: 1))); // time span
    return SessionCheck(endsInFuture: future, implausiblePace: !paceIsPlausible(sport, durationSec, distanceM));
  }

  /// Run 2:30–40:00 min/km (run/walk with long walks included), ride 3–70 km/h, swim 0:55–6:00 min/100 m; no distance or no time: true.
  static bool paceIsPlausible(Sport sport, int durationSec, double distanceM) {
    if (distanceM <= 0 || durationSec <= 0 || sport == Sport.gym) return true;
    return switch (sport) {
      Sport.run => _between(durationSec / (distanceM / 1000), 150, 2400),
      Sport.ride => _between(distanceM / 1000 / (durationSec / 3600), 3, 70),
      Sport.swim => _between(durationSec / (distanceM / 100), 55, 360),
      Sport.gym => true,
    };
  }

  static bool _between(double v, double lo, double hi) => v >= lo && v <= hi;
}
