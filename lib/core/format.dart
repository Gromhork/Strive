import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'sport.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime startOfWeek(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime parseDayKey(String s) => DateFormat('yyyy-MM-dd').parse(s);

/// Unit system. All data is stored metric; this only affects display/input.
class Units {
  final bool imperial;
  const Units(this.imperial);

  static const kgPerLb = 0.45359237;
  static const mPerMi = 1609.344;

  String get weightUnit => imperial ? 'lb' : 'kg';
  String get distUnit => imperial ? 'mi' : 'km';

  double weightOut(double kg) => imperial ? kg / kgPerLb : kg;
  double weightIn(double v) => imperial ? v * kgPerLb : v;
  double distOut(double meters) => imperial ? meters / mPerMi : meters / 1000;
  double distIn(double v) => imperial ? v * mPerMi : v * 1000;

  String weight(double kg, {int digits = 1}) => '${num(weightOut(kg), digits)} $weightUnit';
  String dist(double meters, {int digits = 2}) => '${num(distOut(meters), digits)} $distUnit';

  /// Swim distances are usually shown in meters / yards.
  String swimDist(double meters) => imperial ? '${(meters / 0.9144).round()} yd' : '${meters.round()} m';

  /// Pace in min per km (run) / min per 100m (swim); speed in km/h for ride.
  String paceOrSpeed(Sport sport, double meters, int seconds) {
    if (meters <= 0 || seconds <= 0) return '–';
    if (sport == Sport.swim) {
      final secPer100 = seconds / (meters / 100);
      return '${clock(secPer100.round())} /100m';
    }
    if (sport == Sport.run) {
      final perUnit = seconds / distOut(meters);
      return '${clock(perUnit.round())} /$distUnit';
    }
    final speed = distOut(meters) / (seconds / 3600);
    return '${num(speed, 1)} ${imperial ? 'mph' : 'km/h'}';
  }

  /// Decimal comma for the app language (set by the MaterialApp builder; German → ",").
  static bool decimalComma = false;

  static String num(double v, [int digits = 1]) {
    if (v == v.roundToDouble() && digits > 0 && v.abs() >= 100) return v.round().toString();
    var s = v.toStringAsFixed(digits);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return decimalComma ? s.replaceAll('.', ',') : s;
  }
}

/// 75 -> "1:15", 3725 -> "1:02:05"
String clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// 3725 -> "1h 2min"
String humanDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

String compactNumber(num v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.round().toString();
}

/// Epley estimated one-rep max.
double e1rm(double weight, int reps) => reps <= 0 ? 0 : (reps == 1 ? weight : weight * (1 + reps / 30));

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Parses "ss", "mm:ss" or "h:mm:ss" into seconds.
int? parseClock(String s) {
  final parts = s.trim().split(RegExp(r'[:.]')).where((e) => e.isNotEmpty).map(int.tryParse).toList();
  if (parts.isEmpty || parts.any((e) => e == null)) return null;
  var sec = 0;
  for (final p in parts) {
    sec = sec * 60 + p!;
  }
  return sec;
}

/// Y-axis range for a chart: data min/max plus padding, at least [minSpan] wide
/// (so tiny fluctuations stay visually flat), rounded to whole numbers.
(double, double) paddedRange(Iterable<double> values, {double minSpan = 2}) {
  if (values.isEmpty) return (0, 1);
  var lo = values.reduce((a, b) => a < b ? a : b);
  var hi = values.reduce((a, b) => a > b ? a : b);
  final span = hi - lo;
  final pad = span < minSpan ? (minSpan - span) / 2 : span * 0.1;
  return ((lo - pad).floorToDouble(), (hi + pad).ceilToDouble());
}

/// "barbell curl" → "Barbell curl" (exercise names from the database are lower case).
String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
