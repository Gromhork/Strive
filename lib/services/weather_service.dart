import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class HourForecast {
  final DateTime time;
  final double temp;
  final double feelsLike;
  final int code;
  final int rainChance;
  final double rainMm;
  final double wind;
  final double uv;
  final int humidity;
  final bool isDay;
  const HourForecast({
    required this.time,
    required this.temp,
    required this.feelsLike,
    required this.code,
    required this.rainChance,
    required this.rainMm,
    required this.wind,
    required this.uv,
    required this.humidity,
    required this.isDay,
  });

  /// 0..100 – how pleasant this hour is for outdoor endurance training.
  /// Based on thermal comfort for running (≈ 7–15 °C optimal, Ely et al. 2007),
  /// precipitation, wind, UV and daylight.
  int get trainingScore {
    var s = 100.0;
    final t = feelsLike;
    if (t < 7) s -= (7 - t) * 3.5;
    if (t > 16) s -= (t - 16) * 4.5;
    s -= rainChance * 0.45 + rainMm * 12;
    if (wind > 20) s -= (wind - 20) * 1.2;
    if (uv > 6) s -= (uv - 6) * 5;
    if (!isDay) s -= 18;
    if (code >= 95) s -= 40;
    return s.clamp(0, 100).round();
  }
}

class DayForecast {
  final DateTime date;
  final int code;
  final double max;
  final double min;
  final int rainChance;
  final double uvMax;
  final double windMax;
  final DateTime sunrise;
  final DateTime sunset;
  const DayForecast({
    required this.date,
    required this.code,
    required this.max,
    required this.min,
    required this.rainChance,
    required this.uvMax,
    required this.windMax,
    required this.sunrise,
    required this.sunset,
  });
}

class Weather {
  final String place;
  final double temp;
  final double feelsLike;
  final double wind;
  final int windDir;
  final int humidity;
  final int code;
  final bool isDay;
  final double uv;
  final int? aqi; // European AQI
  final List<HourForecast> hours; // next 48 h
  final List<DayForecast> days; // 7 days
  final DateTime fetched;

  const Weather({
    required this.place,
    required this.temp,
    required this.feelsLike,
    required this.wind,
    required this.windDir,
    required this.humidity,
    required this.code,
    required this.isDay,
    required this.uv,
    required this.aqi,
    required this.hours,
    required this.days,
    required this.fetched,
  });

  DateTime get sunrise => days.first.sunrise;
  DateTime get sunset => days.first.sunset;
  double get max => days.first.max;
  double get min => days.first.min;

  /// Best 2-hour window for outdoor training in the next 16 hours.
  (HourForecast, int)? get bestWindow {
    final cand = hours.take(16).toList();
    if (cand.length < 2) return null;
    var best = 0, bestScore = -1;
    for (var i = 0; i < cand.length - 1; i++) {
      final h = cand[i].time.hour;
      if (h < 6 || h > 21) continue;
      final sc = ((cand[i].trainingScore + cand[i + 1].trainingScore) / 2).round();
      if (sc > bestScore) {
        bestScore = sc;
        best = i;
      }
    }
    return bestScore < 0 ? null : (cand[best], bestScore);
  }

  /// First hour within the next 12 h with a rain chance ≥ 50 %.
  HourForecast? get nextRain => hours.take(12).where((h) => h.rainChance >= 50).firstOrNull;
}

class LocationDenied implements Exception {}

/// Weather via Open-Meteo (free, no API key), air quality via Open-Meteo AQ API
/// and reverse geocoding via BigDataCloud.
class WeatherService {
  static Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw LocationDenied();
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw LocationDenied();
    final last = await Geolocator.getLastKnownPosition().timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (last != null) return last;
    // Network/fused first (fast, battery friendly), then GPS.
    for (final (acc, sec) in const [(LocationAccuracy.low, 8), (LocationAccuracy.high, 20)]) {
      try {
        return await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: acc)).timeout(Duration(seconds: sec));
      } catch (_) {}
    }
    throw LocationDenied(); // no fix available (e.g. indoors / emulator)
  }

  static double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;

  /// [cached] is the last known (lat, lon) used when no fresh fix is available.
  static Future<Weather> fetch(String lang, {(double, double)? cached, void Function(double, double)? onPosition}) async {
    double la, lo;
    try {
      final pos = await _position();
      la = pos.latitude;
      lo = pos.longitude;
      onPosition?.call(la, lo);
    } on LocationDenied {
      if (cached == null) rethrow;
      (la, lo) = cached;
    }
    final lat = la.toStringAsFixed(3), lon = lo.toStringAsFixed(3);
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,relative_humidity_2m,is_day,uv_index'
      '&hourly=temperature_2m,apparent_temperature,weather_code,precipitation_probability,precipitation,wind_speed_10m,uv_index,relative_humidity_2m,is_day'
      '&daily=weather_code,sunrise,sunset,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,wind_speed_10m_max'
      '&timezone=auto&forecast_days=7',
    );
    final aqFuture = http
        .get(
          Uri.parse(
            'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=european_aqi&timezone=auto',
          ),
        )
        .timeout(const Duration(seconds: 8))
        .then<int?>((r) => (jsonDecode(r.body)['current']?['european_aqi'] as num?)?.round())
        .catchError((_) => null);
    final placeFuture = http
        .get(
          Uri.parse(
            'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=$lang',
          ),
        )
        .timeout(const Duration(seconds: 6))
        .then<String>((g) {
          final gj = jsonDecode(g.body);
          return (gj['city'] as String?)?.isNotEmpty == true ? gj['city'] : (gj['locality'] ?? '');
        })
        .catchError((_) => '');

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('weather ${res.statusCode}');
    final j = jsonDecode(res.body);
    final cur = j['current'];
    final d = j['daily'];
    final h = j['hourly'];
    final now = DateTime.now();
    final hours = <HourForecast>[];
    for (var i = 0; i < (h['time'] as List).length; i++) {
      final t = DateTime.parse(h['time'][i]);
      if (t.isAfter(now.subtract(const Duration(hours: 1))) && hours.length < 48) {
        hours.add(
          HourForecast(
            time: t,
            temp: _n(h['temperature_2m'][i]),
            feelsLike: _n(h['apparent_temperature'][i]),
            code: (h['weather_code'][i] as num?)?.toInt() ?? 0,
            rainChance: (h['precipitation_probability'][i] as num?)?.toInt() ?? 0,
            rainMm: _n(h['precipitation'][i]),
            wind: _n(h['wind_speed_10m'][i]),
            uv: _n(h['uv_index'][i]),
            humidity: (h['relative_humidity_2m'][i] as num?)?.toInt() ?? 0,
            isDay: h['is_day'][i] == 1,
          ),
        );
      }
    }
    final days = <DayForecast>[
      for (var i = 0; i < (d['time'] as List).length; i++)
        DayForecast(
          date: DateTime.parse(d['time'][i]),
          code: (d['weather_code'][i] as num?)?.toInt() ?? 0,
          max: _n(d['temperature_2m_max'][i]),
          min: _n(d['temperature_2m_min'][i]),
          rainChance: (d['precipitation_probability_max'][i] as num?)?.toInt() ?? 0,
          uvMax: _n(d['uv_index_max'][i]),
          windMax: _n(d['wind_speed_10m_max'][i]),
          sunrise: DateTime.parse(d['sunrise'][i]),
          sunset: DateTime.parse(d['sunset'][i]),
        ),
    ];
    return Weather(
      place: await placeFuture,
      temp: _n(cur['temperature_2m']),
      feelsLike: _n(cur['apparent_temperature']),
      wind: _n(cur['wind_speed_10m']),
      windDir: (cur['wind_direction_10m'] as num?)?.toInt() ?? 0,
      humidity: (cur['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      code: (cur['weather_code'] as num?)?.toInt() ?? 0,
      isDay: cur['is_day'] == 1,
      uv: _n(cur['uv_index']),
      aqi: await aqFuture,
      hours: hours,
      days: days,
      fetched: now,
    );
  }
}

/// WMO weather code → icon.
IconData weatherIcon(int code, {bool night = false}) {
  if (code == 0) return night ? Icons.nightlight_round : Icons.wb_sunny_rounded;
  if (code <= 2) return night ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
  if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud_rounded;
}

Color weatherColor(int code) {
  if (code <= 1) return const Color(0xFFFFC53D);
  if (code <= 3) return const Color(0xFFB0BEC5);
  if (code >= 95) return const Color(0xFF9575CD);
  if (code >= 51) return const Color(0xFF4FC3F7);
  return const Color(0xFFB0BEC5);
}

/// Condition category used for texts and the card gradient.
enum Sky { clear, partly, cloudy, fog, drizzle, rain, snow, storm }

Sky skyOf(int code) {
  if (code == 0) return Sky.clear;
  if (code <= 2) return Sky.partly;
  if (code == 3) return Sky.cloudy;
  if (code == 45 || code == 48) return Sky.fog;
  if (code >= 51 && code <= 57) return Sky.drizzle;
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return Sky.rain;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return Sky.snow;
  if (code >= 95) return Sky.storm;
  return Sky.cloudy;
}

/// Background gradient for the weather card / page header.
List<Color> skyGradient(int code, bool day) {
  if (!day) return const [Color(0xFF1B2440), Color(0xFF0E1428)];
  return switch (skyOf(code)) {
    Sky.clear => const [Color(0xFF3A8DFF), Color(0xFF7CC4FF)],
    Sky.partly => const [Color(0xFF4A7FC1), Color(0xFF8DB4DE)],
    Sky.cloudy || Sky.fog => const [Color(0xFF5D6B7E), Color(0xFF8C97A6)],
    Sky.drizzle || Sky.rain => const [Color(0xFF34495E), Color(0xFF5B7086)],
    Sky.snow => const [Color(0xFF7F95B0), Color(0xFFB9C7D8)],
    Sky.storm => const [Color(0xFF2B2346), Color(0xFF4B3F72)],
  };
}

/// Clothing layers for running by "feels like" temperature (rule of thumb:
/// dress for ~10 °C warmer than it is).
enum Clothing { shortsTee, longTee, tights, jacket, winter }

Clothing clothingFor(double feels) {
  if (feels >= 16) return Clothing.shortsTee;
  if (feels >= 10) return Clothing.longTee;
  if (feels >= 4) return Clothing.tights;
  if (feels >= -3) return Clothing.jacket;
  return Clothing.winter;
}

String windDirLabel(int deg, String lang) =>
    (lang == 'de' ? const ['N', 'NO', 'O', 'SO', 'S', 'SW', 'W', 'NW'] : const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])[((deg % 360) / 45)
            .round() %
        8];
