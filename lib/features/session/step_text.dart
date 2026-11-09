import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/step_progress.dart';

/// Human readable texts for structured workout steps (UI and voice).

String zoneLabel(AppLocalizations l, String zone, {Sport? sport}) => switch (zone) {
  'REC' when sport == Sport.swim => l.zSwimEasy,
  'E' || 'L' => l.zConversational,
  'M' => l.zMarathon,
  'T' => l.zThreshold,
  'I' => l.zInterval,
  'R' => l.zStride,
  'REC' => l.zJog,
  'walk' => l.zWalk,
  'Z1' => l.zRecovery,
  'Z2' => l.zEndurance,
  'Z3' || 'TE' => l.zTempo,
  'SS' => 'Sweet Spot',
  'Z4' => l.zThreshold,
  'Z5' => 'VO2max',
  'Z6' || 'Z7' => l.zSprint,
  'CSS' => l.zCss,
  'EN' => l.zSwimEndurance,
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

/// Step title. Runs count all work steps ("Interval 3/6"); rides and swims count
/// the repetitions inside a repeat block ("8 × 100 m" → "Interval 3/8").
/// [spoken] uses "3 of 8" instead of "3/8" (TTS reads slashes as fractions/dates).
String stepTitle(AppLocalizations l, List<WorkoutStep> steps, int i, {Sport? sport, bool spoken = false}) {
  final s = steps[i];
  String n(int x, int y) => spoken ? l.vcStepN(x, y) : l.stepWorkN(x, y);
  if (sport == Sport.ride || sport == Sport.swim) {
    final rep = repInfo(steps, i);
    return switch (s.kind) {
      'warmup' => l.stepWarmup,
      'cooldown' => l.stepCooldown,
      'recovery' => sport == Sport.swim ? l.stepRest : l.stepRecovery,
      'work' when rep != null => n(rep.rep, rep.reps),
      'work' when s.zone == 'DR' => l.stepDrillsTitle,
      'work' => l.stepWork,
      _ => sport == Sport.swim ? l.stepSteadySwim : l.stepSteadyRide,
    };
  }
  final works = [
    for (var k = 0; k < steps.length; k++)
      if (steps[k].isWork) k,
  ];
  return switch (s.kind) {
    'warmup' => l.stepWarmup,
    'cooldown' => l.stepCooldown,
    'recovery' => s.zone == 'walk' ? l.zWalk : l.stepRecovery,
    'work' when works.length > 1 => n(works.indexOf(i) + 1, works.length),
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

/// "8 × 100 m · CSS" for a step inside a repeat block, else "100 m · CSS".
String stepSetLabel(AppLocalizations l, List<WorkoutStep> steps, int i, Units u, Sport sport) {
  final s = steps[i];
  final rep = s.isWork ? repInfo(steps, i) : null;
  final amount = stepAmount(s, u, sport);
  return '${rep != null ? '${rep.reps} × ' : ''}$amount · ${zoneLabel(l, s.zone, sport: sport)}';
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
  if (s.hrMin != null && s.hrMax != null && s.zone != 'REC') {
    parts.add('${z != null ? 'Z$z · ' : ''}${s.hrMin}–${s.hrMax} bpm');
  }
  return parts.join(' · ');
}

/// One-line sentence like "5.0 km at conversational pace (Zone 2)".
String stepSentence(AppLocalizations l, List<WorkoutStep> steps, int i, Units u, Sport sport) {
  final s = steps[i];
  final title = stepTitle(l, steps, i, sport: sport), zone = zoneLabel(l, s.zone, sport: sport);
  return '$title: ${stepAmount(s, u, sport)}${zone == title ? '' : ' · $zone'}';
}

/// Spoken version for the voice coach.
///
/// * Run: "Interval 2 of 6. 800 meters interval pace, 3:50 to 4:00 per kilometer."
/// * Ride: "Interval 2 of 4. 3 minutes VO2max, 250 to 280 watts, heart rate 160 to 172."
/// * Swim: "Interval 2 of 8. 100 meters CSS, 1:45 to 1:50 per 100 meters." / "Rest. 15 seconds."
String stepSpeech(AppLocalizations l, List<WorkoutStep> steps, int i, Units u, Sport sport, String lang) {
  final s = steps[i];
  final de = lang == 'de';
  final amount =
      s.distanceM != null
          ? (s.distanceM! >= 1000 && sport != Sport.swim
              ? '${Units.num(s.distanceM! / 1000, 1).replaceAll('.', de ? ',' : '.')} ${de ? 'Kilometer' : 'kilometers'}'
              : '${s.distanceM!.round()} ${de ? 'Meter' : 'meters'}')
          : (s.durationSec != null ? _spokenTime(s.durationSec!, lang) : '');
  final title = stepTitle(l, steps, i, sport: sport, spoken: true);
  final targets = <String>[];
  switch (sport) {
    case Sport.run:
      if (s.paceMin != null && s.paceMax != null) {
        targets.add(
          de
              ? '${fmtPaceSec(s.paceMin!, u)} bis ${fmtPaceSec(s.paceMax!, u)} pro Kilometer'
              : '${fmtPaceSec(s.paceMin!, u)} to ${fmtPaceSec(s.paceMax!, u)} per kilometer',
        );
      }
    case Sport.ride:
      if (s.powerMin != null && s.powerMax != null) targets.add(l.vcPowerRange(s.powerMin!, s.powerMax!));
      if (s.hrMin != null && s.hrMax != null) targets.add(l.vcHrRange(s.hrMin!, s.hrMax!));
    case Sport.swim:
      // Pace only for the first repetition of a block – short reps would otherwise be very chatty.
      final rep = repInfo(steps, i);
      if (s.isWork && s.paceMin != null && s.paceMax != null && (rep == null || rep.rep == 1)) {
        targets.add(l.vcPaceRange100(fmtPaceSec(s.paceMin!, u, swim: true), fmtPaceSec(s.paceMax!, u, swim: true)));
      }
    case Sport.gym:
      break;
  }
  // Swim rest: "Rest. 15 seconds." – the zone adds nothing.
  if (sport == Sport.swim && s.kind == 'recovery') return '$title. $amount.';
  final tail = targets.isEmpty ? '' : ', ${targets.join(', ')}';
  return '$title. $amount ${zoneLabel(l, s.zone, sport: sport)}$tail.';
}

String _spokenTime(int sec, String lang) {
  final m = sec ~/ 60, s = sec % 60;
  if (lang == 'de') return [if (m > 0) '$m Minute${m == 1 ? '' : 'n'}', if (s > 0) '$s Sekunden'].join(' ');
  return [if (m > 0) '$m minute${m == 1 ? '' : 's'}', if (s > 0) '$s seconds'].join(' ');
}
