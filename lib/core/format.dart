import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'sport.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar arithmetic for day values: midnight of the day [n] days after [d]'s day.
/// Never use `Duration(days: n)` on day values – it is n × 24 h, so across a DST change
/// (late October / late March) midnight becomes 23:00 of the day before (or 01:00).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [a]'s day to [b]'s day (negative when [b] is earlier) –
/// DST-safe, unlike `b.difference(a).inDays` (a 23 h day counts as 0).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

DateTime startOfWeek(DateTime d) => addDays(d, -(d.weekday - 1));

/// Where a race date picker opens: [weeks] weeks after [today], moved forward to the next race
/// day – the long-session day ([longDay], 1 = Monday), else Sunday (most races are on a weekend).
DateTime defaultRaceDate(DateTime today, int weeks, {int? longDay}) {
  final d = addDays(dayOnly(today), 7 * weeks);
  final target = longDay ?? DateTime.sunday;
  return addDays(d, (target - d.weekday) % 7);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// 'yyyy-MM-dd' of [d]'s day. Built by hand: it keys maps in hot paths (calendar, compliance),
/// where a new DateFormat (pattern parsing) per call was measurable.
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
String _two(int n) => n < 10 ? '0$n' : '$n';
DateTime parseDayKey(String s) => _dayKeyFormat.parse(s);
final _dayKeyFormat = DateFormat('yyyy-MM-dd');

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

  // (Number and unit with a non-breaking space everywhere – "1,5" / "km" never wrap apart, final QA.)
  String weight(double kg, {int digits = 1}) => '${num(weightOut(kg), digits)}$nbsp$weightUnit';
  String dist(double meters, {int digits = 2}) => '${num(distOut(meters), digits)}$nbsp$distUnit';

  /// Swim distances are usually shown in meters / yards.
  String swimDist(double meters) => imperial ? '${(meters / 0.9144).round()}${nbsp}yd' : '${meters.round()}${nbsp}m';

  /// Pace in min per km (run) / min per 100m (swim); speed in km/h for ride.
  String paceOrSpeed(Sport sport, double meters, int seconds) {
    if (meters <= 0 || seconds <= 0) return '–';
    if (sport == Sport.swim) {
      final secPer100 = seconds / (meters / 100);
      return '${clock(secPer100.round())}$nbsp/100${nbsp}m';
    }
    if (sport == Sport.run) {
      final perUnit = seconds / distOut(meters);
      return '${clock(perUnit.round())} /$distUnit';
    }
    final speed = distOut(meters) / (seconds / 3600);
    return '${num(speed, 1)}$nbsp${imperial ? 'mph' : 'km/h'}';
  }

  /// Decimal comma for the app language (set by the MaterialApp builder; German → ",").
  static bool decimalComma = false;

  static String num(double v, [int digits = 1]) {
    if (v == v.roundToDouble() && digits > 0 && v.abs() >= 100) return v.round().toString();
    var s = v.toStringAsFixed(digits);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return decimalComma ? s.replaceAll('.', ',') : s;
  }

  /// Fixed number of decimals in the app language ("2,0" / "2.0", "43,4", "1,25").
  static String fixed(double v, [int digits = 1]) {
    final s = v.toStringAsFixed(digits);
    return decimalComma ? s.replaceAll('.', ',') : s;
  }

  /// Whole number with thousands separators in the app language ("1.593" / "1,593").
  static String grouped(double v) {
    final n = v.round();
    final digits = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(decimalComma ? '.' : ',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  /// Percentage in the app language: "26 %" (German, with a narrow space) / "26%".
  static String pct(double v) => '${v.round()}$pctSign';

  /// Percent sign with the spacing of the app language (after a number formatted elsewhere).
  static String get pctSign => decimalComma ? ' %' : '%';

  /// Lifted volume: "1.593 kg", from 10 t on "12,4 t" (imperial: "3,512 lb").
  String volume(double kg) {
    if (imperial) return '${grouped(weightOut(kg))}${nbsp}lb';
    return kg >= 10000 ? '${fixed(kg / 1000, 1)}${nbsp}t' : '${grouped(kg)}${nbsp}kg';
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

/// Non-breaking space: a number and its unit ("2 h", "45 min") never wrap apart.
const nbsp = ' ';

/// A planned / allowed time in minutes – the one compact format of the app: "45 min", "1:15 h",
/// "2 h" (never "2 h 00"), with non-breaking spaces so the value never wraps inside. Below 90
/// minutes in minutes ("75 min" reads easier than "1:15 h"); whole hours as "2 h".
String formatMinutes(int minutes) {
  if (minutes < 90 && minutes % 60 != 0) return '$minutes${nbsp}min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h${nbsp}h' : '$h:${m.toString().padLeft(2, '0')}${nbsp}h';
}

/// 3725 -> "1 h 2 min" (non-breaking between number and unit).
/// Rounded to the nearest minute (3:49 → "4 min", like the "≈ 4 min" elsewhere – never cut
/// down to "3 min"); under half a minute the seconds.
String humanDuration(int seconds) {
  final total = (seconds / 60).round();
  if (total == 0 && seconds > 0) return '$seconds${nbsp}s';
  final h = total ~/ 60;
  final m = total % 60;
  if (h == 0) return '$m${nbsp}min';
  return m == 0 ? '$h${nbsp}h' : '$h${nbsp}h $m${nbsp}min';
}

/// Counts (steps, reps): grouped in the app language up to 99.999 ("8.432" / "8,432"),
/// above that "123k" / "1,2 Mio." – never English "1.6k" with a German decimal point.
String compactNumber(num v) {
  if (v >= 1000000) return Units.decimalComma ? '${Units.fixed(v / 1000000, 1)} Mio.' : '${Units.fixed(v / 1000000, 1)}M';
  if (v >= 100000) return '${(v / 1000).round()}k';
  return Units.grouped(v.toDouble());
}

/// Epley estimated one-rep max.
double e1rm(double weight, int reps) => reps <= 0 ? 0 : (reps == 1 ? weight : weight * (1 + reps / 30));

/// Duration typed as "1:02:03", "45:10" (min:sec) or plain minutes "45" → seconds.
int? parseHms(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final parts = t.split(':').map((p) => int.tryParse(p.trim())).toList();
  if (parts.any((p) => p == null || p < 0)) return null;
  final p = parts.cast<int>();
  if (p.length > 1 && p.skip(1).any((x) => x >= 60)) return null;
  return switch (p.length) {
    1 => p[0] * 60,
    2 => p[0] * 60 + p[1],
    3 => p[0] * 3600 + p[1] * 60 + p[2],
    _ => null,
  };
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

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

/// Line-break friendly title: short connectors ("+", "–", "&", "/", "·") stick to the
/// preceding word with a non-breaking space, so a wrapped title never shows a lone "+"
/// on its own line ("Lockerer Lauf +" / "Steigerungen").
/// Numbers stick to their unit too ("Freiwasser 1,5 km" never breaks between "1,5" and "km" – [glueUnits]).
String glueTitle(String s) => glueUnits(s.replaceAllMapped(RegExp(r' ([+–&/·]) '), (m) => ' ${m[1]} '));

/// A number and the unit after it joined by a non-breaking space ("1,5 km", "400 m", "45 min", "3 h") – for labels
/// built from translations ("Freiwasser 1,5 km") and anything else not formatted by [Units] / [formatMinutes].
String glueUnits(String s) => s.contains(' ') ? s.replaceAllMapped(_unitGap, (m) => '${m[1]}$nbsp') : s;
final _unitGap = RegExp(r'(\d) (?=(?:km/h|km|mi|mph|yd|kg|lb|min|h|m|s|t)\b)');
