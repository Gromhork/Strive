import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';

/// Human readable texts for structured workout steps (UI and voice).

String zoneLabel(AppLocalizations l, String zone) => switch (zone) {
  'E' => l.zConversational,
  'L' => l.zEasyLong,
  'M' => l.zMarathon,
  'T' => l.zThreshold,
  'I' => l.zInterval,
  'R' => l.zStride,
  'REC' => l.zJog,
  'walk' => l.zWalk,
  'Z1' => l.zRecovery,
  'Z2' => 'Zone 2',
  'Z3' => 'Tempo (Z3)',
  'SS' => 'Sweet Spot',
  'Z4' => l.zThreshold,
  'Z5' => 'VO2max',
  'Z6' || 'Z7' => l.zSprint,
  'CSS' => 'CSS',
  'EN' => l.zSwimEndurance,
  'TE' => 'Tempo',
  'SP' => l.zSprint,
  'DR' => l.zDrills,
  _ => zone,
};

Color zoneColor(String zone) => switch (zone) {
  'E' || 'L' || 'Z2' || 'EN' => AppColors.run,
  'REC' || 'walk' || 'Z1' || 'DR' => const Color(0xFF7D8CA3),
  'M' || 'Z3' || 'TE' => AppColors.swim,
  'T' || 'SS' || 'Z4' || 'CSS' => AppColors.ride,
  'I' || 'Z5' => AppColors.gym,
  _ => AppColors.danger,
};

/// Heart-rate zone number for display.
int? hrZoneOf(String zone) => switch (zone) {
  'E' || 'L' || 'Z2' => 2,
  'REC' || 'walk' || 'Z1' => 1,
  'M' || 'Z3' || 'SS' => 3,
  'T' || 'Z4' => 4,
  'I' || 'R' || 'Z5' || 'Z6' || 'Z7' => 5,
  _ => null,
};

String stepTitle(AppLocalizations l, List<WorkoutStep> steps, int i) {
  final s = steps[i];
  final works = [for (var k = 0; k < steps.length; k++) if (steps[k].isWork) k];
  return switch (s.kind) {
    'warmup' => l.stepWarmup,
    'cooldown' => l.stepCooldown,
    'recovery' => s.zone == 'walk' ? l.zWalk : l.stepRecovery,
    'work' when works.length > 1 => l.stepWorkN(works.indexOf(i) + 1, works.length),
    'work' => l.stepWork,
    _ => l.stepSteady,
  };
}

String stepAmount(WorkoutStep s, Units u, Sport sport) {
  if (s.distanceM != null) {
    if (sport == Sport.swim || s.distanceM! < 1000) return '${s.distanceM!.round()} m';
    return '${Units.num(u.distOut(s.distanceM!), 1)} ${u.distUnit}';
  }
  if (s.durationSec != null) return clock(s.durationSec!);
  return '';
}

String fmtPaceSec(int sec, Units u, {bool swim = false}) {
  final v = swim ? sec : (u.imperial ? (sec * 1.609344).round() : sec);
  return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
}

/// "4:05–4:15 /km · Zone 4" or "180–200 W" etc.
String stepTarget(AppLocalizations l, WorkoutStep s, Units u, Sport sport) {
  final parts = <String>[];
  final swim = sport == Sport.swim;
  final unit = swim ? '/100 m' : (u.imperial ? '/mi' : '/km');
  if (s.paceMin != null && s.paceMax != null) {
    parts.add('${fmtPaceSec(s.paceMin!, u, swim: swim)}–${fmtPaceSec(s.paceMax!, u, swim: swim)} $unit');
  }
  if (s.powerMin != null && s.powerMax != null) parts.add('${s.powerMin}–${s.powerMax} W');
  final z = hrZoneOf(s.zone);
  if (s.hrMin != null && s.hrMax != null) {
    parts.add('${z != null ? 'Z$z · ' : ''}${s.hrMin}–${s.hrMax} bpm');
  }
  return parts.join(' · ');
}

/// One-line sentence like "5.0 km at conversational pace (Zone 2)".
String stepSentence(AppLocalizations l, List<WorkoutStep> steps, int i, Units u, Sport sport) {
  final s = steps[i];
  return '${stepTitle(l, steps, i)}: ${stepAmount(s, u, sport)} · ${zoneLabel(l, s.zone)}';
}

/// Spoken version for the voice coach.
String stepSpeech(AppLocalizations l, List<WorkoutStep> steps, int i, Units u, Sport sport, String lang) {
  final s = steps[i];
  final amount =
      s.distanceM != null
          ? (s.distanceM! >= 1000
              ? '${Units.num(s.distanceM! / 1000, 1).replaceAll('.', lang == 'de' ? ',' : '.')} ${lang == 'de' ? 'Kilometer' : 'kilometers'}'
              : '${s.distanceM!.round()} ${lang == 'de' ? 'Meter' : 'meters'}')
          : (s.durationSec != null ? _spokenTime(s.durationSec!, lang) : '');
  final pace =
      (s.paceMin != null && s.paceMax != null && sport == Sport.run)
          ? (lang == 'de'
              ? ', ${fmtPaceSec(s.paceMin!, u)} bis ${fmtPaceSec(s.paceMax!, u)} pro Kilometer'
              : ', ${fmtPaceSec(s.paceMin!, u)} to ${fmtPaceSec(s.paceMax!, u)} per kilometer')
          : '';
  return '${stepTitle(l, steps, i)}. $amount ${zoneLabel(l, s.zone)}$pace.';
}

String _spokenTime(int sec, String lang) {
  final m = sec ~/ 60, s = sec % 60;
  if (lang == 'de') return [if (m > 0) '$m Minute${m == 1 ? '' : 'n'}', if (s > 0) '$s Sekunden'].join(' ');
  return [if (m > 0) '$m minute${m == 1 ? '' : 's'}', if (s > 0) '$s seconds'].join(' ');
}
