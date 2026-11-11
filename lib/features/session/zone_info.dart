import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/zones.dart';
import 'cardio_extra_pages.dart' show contiguousRunRange;
import 'step_text.dart';

/// Intensity zones offered per sport (slow → fast).
///
/// Kept deliberately small and in the vocabulary of common training apps:
/// * Run (Daniels/Runna style): recovery, easy, steady (≈ marathon pace), threshold,
///   interval (≈ 3–5 km race pace), sprint (strides / repetitions).
/// * Ride (Coggan power zones, condensed): recovery, endurance, sweet spot, threshold,
///   VO2max, sprint.
/// * Swim (CSS based): easy, drills, endurance, threshold (CSS), sprint.
List<String> zonesFor(Sport sport) => switch (sport) {
  Sport.run => const ['REC', 'E', 'M', 'T', 'I', 'R'],
  Sport.ride => const ['Z1', 'Z2', 'SS', 'Z4', 'Z5', 'Z6'],
  Sport.swim => const ['REC', 'DR', 'EN', 'CSS', 'SP'],
  Sport.gym => const ['E'],
};

/// Picker value for a stored zone (maps retired codes to their replacement).
String normalizeZone(String zone, Sport sport) => switch ((sport, zone)) {
  (Sport.run, 'L') => 'E',
  (Sport.run, 'walk') => 'REC',
  (Sport.ride, 'Z3') => 'SS',
  (Sport.ride, 'Z7') => 'Z6',
  (Sport.swim, 'TE') => 'EN',
  _ => zone,
};

/// Workout-level intensities that make sense for a sport.
List<String> intensitiesFor(Sport sport) => switch (sport) {
  Sport.swim => const ['easy', 'technique', 'tempo', 'intervals'],
  Sport.gym => const ['easy'],
  _ => const ['easy', 'long', 'tempo', 'intervals'],
};

/// Overall intensity derived from the structure of a workout.
String deriveIntensity(List<WorkoutStep> steps, Sport sport) {
  final work = steps.where((s) => s.kind == 'work' || s.kind == 'steady').toList();
  bool any(Set<String> z) => work.any((s) => z.contains(s.zone));
  if (any(const {'I', 'R', 'Z5', 'Z6', 'Z7', 'SP'})) return 'intervals';
  if (any(const {'M', 'T', 'SS', 'Z3', 'Z4', 'CSS', 'TE'})) return 'tempo';
  if (sport == Sport.swim && work.isNotEmpty && work.where((s) => s.zone == 'DR').length * 2 >= work.length) return 'technique';
  final sec = steps.fold<int>(0, (a, s) => a + (s.durationSec ?? 0));
  final m = steps.fold<double>(0, (a, s) => a + (s.distanceM ?? 0));
  final long = switch (sport) {
    Sport.run => sec >= 75 * 60 || m >= 16000,
    Sport.ride => sec >= 150 * 60 || m >= 70000,
    _ => false,
  };
  return long ? 'long' : 'easy';
}

String zoneDescription(AppLocalizations l, String zone, Sport sport) => switch ((sport, normalizeZone(zone, sport))) {
  (Sport.run, 'REC') => l.zdRunRec,
  (Sport.run, 'E') => l.zdRunEasy,
  (Sport.run, 'M') => l.zdRunSteady,
  (Sport.run, 'T') => l.zdRunThreshold,
  (Sport.run, 'I') => l.zdRunInterval,
  (Sport.run, 'R') => l.zdRunSprint,
  (Sport.ride, 'Z1') => l.zdRideRec,
  (Sport.ride, 'Z2') => l.zdRideEndurance,
  (Sport.ride, 'SS') => l.zdRideSweetSpot,
  (Sport.ride, 'Z4') => l.zdRideThreshold,
  (Sport.ride, 'Z5') => l.zdRideVo2,
  (Sport.ride, 'Z6') => l.zdRideSprint,
  (Sport.swim, 'REC') => l.zdSwimEasy,
  (Sport.swim, 'DR') => l.zdSwimDrills,
  (Sport.swim, 'EN') => l.zdSwimEndurance,
  (Sport.swim, 'CSS') => l.zdSwimCss,
  (Sport.swim, 'SP') => l.zdSwimSprint,
  _ => '',
};

/// Perceived effort (RPE 1–10) and talk test.
String zoneFeel(AppLocalizations l, String zone, Sport sport) => switch (normalizeZone(zone, sport)) {
  'REC' || 'Z1' => l.zfVeryEasy,
  'E' || 'Z2' || 'EN' => l.zfEasy,
  'DR' => l.zfDrills,
  'M' || 'SS' => l.zfModerate,
  'T' || 'Z4' || 'CSS' => l.zfHard,
  'I' || 'Z5' => l.zfVeryHard,
  _ => l.zfMax,
};

/// Personal target for a zone ("≈ 5:40–6:10 /km", "190–215 W · 84–94 % FTP").
/// Returns (text, estimated) – estimated when no test value is known.
(String, bool) zoneTarget(String zone, Sport sport, UserProfile p) {
  final u = p.units;
  final a = p.athlete;
  final z = normalizeZone(zone, sport);
  switch (sport) {
    case Sport.run:
      final vdot = Vdot.of(a);
      // Contiguous zone map (no paces between two zones) – the same ranges as the live zone view.
      final r = contiguousRunRange(PaceZones(vdot ?? Vdot.defaultFor(p.level)), z);
      final unit = u.imperial ? '/mi' : '/km';
      return ('${fmtPaceSec(r.$1, u)}–${fmtPaceSec(r.$2, u)} $unit', vdot == null);
    case Sport.ride:
      final ftp = a.ftp ?? PowerZones.estimate(p.level, p.weightKg);
      final r = PowerZones(ftp).range(z);
      final pct = PowerZones(100).range(z);
      final w = z == 'Z6' ? '> ${r.$1} W' : '${r.$1}–${r.$2} W';
      final pc = z == 'Z6' ? '> ${pct.$1} % FTP' : '${pct.$1}–${pct.$2} % FTP';
      return ('$w · $pc', a.ftp == null);
    case Sport.swim:
      if (z == 'DR') return ('', false);
      final tested = SwimZones.fromTests(a.swim400Sec, a.swim200Sec);
      final r = SwimZones(tested ?? SwimZones.defaultFor(p.level)).range(z);
      return ('${fmtPaceSec(r.$1, u, swim: true)}–${fmtPaceSec(r.$2, u, swim: true)} /100 m', tested == null);
    case Sport.gym:
      return ('', false);
  }
}

/// Heart-rate range of a zone ("128–142 bpm"), or null for swim / drills.
String? zoneHr(String zone, Sport sport, UserProfile p) {
  if (sport == Sport.swim) return null;
  final n = hrZoneOf(normalizeZone(zone, sport));
  if (n == null) return null;
  final r = HrZones(p.estimatedMaxHr, p.athlete.restHr).zone(n);
  return '${r.$1}–${r.$2} bpm';
}

/// Info button that opens [showZoneInfo].
class ZoneInfoButton extends StatelessWidget {
  const ZoneInfoButton({super.key, required this.sport, required this.profile, this.highlight});
  final Sport sport;
  final UserProfile profile;
  final String? highlight;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.zoneInfoTitle,
    visualDensity: VisualDensity.compact,
    icon: Icon(Icons.info_outline_rounded, size: 20, color: Theme.of(context).colorScheme.outline),
    onPressed: () => showZoneInfo(context, sport, profile, highlight: highlight),
  );
}

/// Bottom sheet explaining every zone of [sport] with the athlete's personal targets.
Future<void> showZoneInfo(BuildContext context, Sport sport, UserProfile profile, {String? highlight}) {
  final l = context.l10n;
  final zones = zonesFor(sport);
  final hl = highlight == null ? null : normalizeZone(highlight, sport);
  final estimated = zones.any((z) => zoneTarget(z, sport, profile).$2);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (c) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder:
              (c, scroll) => ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(l.zoneInfoTitle, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(switch (sport) {
                    Sport.run => l.zoneInfoRun,
                    Sport.ride => l.zoneInfoRide,
                    _ => l.zoneInfoSwim,
                  }, style: Theme.of(c).textTheme.bodySmall),
                  if (estimated) ...[
                    const SizedBox(height: 6),
                    Text(l.zoneInfoEstimated, style: Theme.of(c).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 14),
                  for (final z in zones) _ZoneTile(zone: z, sport: sport, profile: profile, selected: z == hl),
                  if (sport == Sport.swim) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pool_rounded),
                      label: Text(l.swimDrillsTitle),
                      onPressed: () => showSwimDrills(c),
                    ),
                  ],
                ],
              ),
        ),
  );
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone, required this.sport, required this.profile, required this.selected});
  final String zone;
  final Sport sport;
  final UserProfile profile;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = zoneColor(zone);
    final (target, est) = zoneTarget(zone, sport, profile);
    final hr = zoneHr(zone, sport, profile);
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.14) : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: c, width: 1.5) : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(zoneLabel(l, zone, sport: sport), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      Text(zoneFeel(l, zone, sport), style: t.labelSmall),
                    ],
                  ),
                  if (target.isNotEmpty || hr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [if (target.isNotEmpty) '${est ? '≈ ' : ''}$target', if (hr != null) hr].join(' · '),
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: c),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(zoneDescription(l, zone, sport), style: t.bodySmall?.copyWith(height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swim technique drills: what "Technik" in a swim workout means.
class SwimDrill {
  const SwimDrill(this.name, this.how, this.why);
  final String name;
  final String how;
  final String why;
}

List<SwimDrill> swimDrills(AppLocalizations l) => [
  SwimDrill(l.drillCatchupName, l.drillCatchupHow, l.drillCatchupWhy),
  SwimDrill(l.drillFingertipName, l.drillFingertipHow, l.drillFingertipWhy),
  SwimDrill(l.drillSideKickName, l.drillSideKickHow, l.drillSideKickWhy),
  SwimDrill(l.drillSingleArmName, l.drillSingleArmHow, l.drillSingleArmWhy),
  SwimDrill(l.drillFistName, l.drillFistHow, l.drillFistWhy),
  SwimDrill(l.drillScullName, l.drillScullHow, l.drillScullWhy),
];

/// Two drills for a technique set, rotating by [week] so sessions vary.
(SwimDrill, SwimDrill) drillsForWeek(AppLocalizations l, int week) {
  final d = swimDrills(l);
  final i = (week * 2) % d.length;
  return (d[i], d[(i + 1) % d.length]);
}

Future<void> showSwimDrills(BuildContext context) {
  final l = context.l10n;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (c) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder:
              (c, scroll) => ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(l.swimDrillsTitle, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(l.swimDrillsIntro, style: Theme.of(c).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  for (final d in swimDrills(l))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(d.how, style: Theme.of(c).textTheme.bodySmall?.copyWith(height: 1.35)),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 14, color: zoneColor('DR')),
                              const SizedBox(width: 6),
                              Expanded(child: Text(d.why, style: Theme.of(c).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        ),
  );
}
