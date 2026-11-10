import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/step_progress.dart';
import '../../services/tracker.dart';
import '../../services/zones.dart';
import 'step_text.dart';
import 'zone_info.dart' show normalizeZone;

/// Extra pages of the live recording screen:
/// * [ZonesPage] – live pace with its zone colour and the time spent in every zone
///   (runs outdoors and swims; the app has no live HR / power source, so zones are pace based);
/// * [PlanPage] – plan vs. actual of a structured workout: projected finish vs. plan and
///   every finished section with its actual values and a traffic-light status.

/// Text colour for a zone colour: kept on dark backgrounds, darkened on light ones.
Color _ink(BuildContext context, Color c) {
  if (Theme.of(context).brightness == Brightness.dark) return c;
  final h = HSLColor.fromColor(c);
  return h.lightness > 0.38 ? h.withLightness(0.34).toColor() : c;
}

// ───────────────────────────── Zones ─────────────────────────────

/// Contiguous live pace zones (slow → fast) of a session, or null when the session has no
/// live pace (rides – no power meter –, treadmill runs).
class LiveZones {
  LiveZones._(this.sport, this.codes, this.cuts, [this.paces]);

  final Sport sport;

  /// Run: the athlete's Daniels zones – the displayed range of a closed zone.
  final PaceZones? paces;

  /// (fast, slow) range shown for zone [i] – the zone's own pace range (one source with the
  /// zone info), null for open-ended / non-run zones.
  (int?, int?)? shown(int i) {
    final code = codes[i];
    if (paces == null || code == 'REC' || code == 'R') return null;
    final r = paces!.range(code);
    return (r.$1, r.$2);
  }

  /// Zone codes, slowest first (same codes as the workout steps).
  final List<String> codes;

  /// `cuts[i]` separates `codes[i]` from `codes[i + 1]`: a pace below it is faster
  /// (sec/km for runs, sec/100 m for swims). Strictly decreasing.
  final List<int> cuts;

  /// Daniels zones; the gaps between the zone ranges are split in the middle.
  factory LiveZones.run(PaceZones z) {
    final c = [
      z.easySlow,
      ((z.easyFast + z.marathon + 5) / 2).round(),
      ((z.marathon - 5 + z.threshold + 4) / 2).round(),
      ((z.threshold - 4 + z.interval + 4) / 2).round(),
      ((z.interval - 4 + z.repetition + 3) / 2).round(),
    ];
    for (var i = 1; i < c.length; i++) {
      c[i] = min(c[i], c[i - 1] - 1);
    }
    return LiveZones._(Sport.run, const ['REC', 'E', 'M', 'T', 'I', 'R'], c, z);
  }

  /// CSS zones (drills have no pace zone).
  factory LiveZones.swim(int css) => LiveZones._(Sport.swim, const ['REC', 'EN', 'CSS', 'SP'], [css + 13, css + 5, css - 3]);

  static LiveZones? of(CardioState s, UserProfile p) {
    final a = p.athlete;
    if (s.sport == Sport.run && !s.indoor) return LiveZones.run(PaceZones(Vdot.of(a) ?? Vdot.defaultFor(p.level)));
    if (s.sport == Sport.swim) return LiveZones.swim(SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(p.level));
    return null;
  }

  /// Index into [codes] of a pace.
  int indexOf(int pace) {
    var i = 0;
    while (i < cuts.length && pace < cuts[i]) {
      i++;
    }
    return i;
  }

  /// (fast, slow) pace bounds of zone [i]; null = open ended.
  (int?, int?) bounds(int i) => (i < cuts.length ? cuts[i] : null, i > 0 ? cuts[i - 1] : null);

  /// Live pace in zone units: rolling pool pace, else the live GPS pace.
  int? livePace(CardioState s) => s.poolMode ? s.swimPace100 : s.targetPace;

  /// Seconds spent in every zone so far (pool: per length; else moving time per live pace).
  List<int> timeIn(CardioState s) {
    final t = List.filled(codes.length, 0);
    if (s.poolMode) {
      for (final sec in s.lengthSecs) {
        t[indexOf((sec * 100 / s.poolLen).round())] += sec;
      }
      return t;
    }
    for (final e in s.paceTime.entries) {
      if (sport == Sport.run && e.key > 1200) continue; // standing / walking breaks
      t[indexOf(sport == Sport.swim ? (e.key / 10).round() : e.key)] += e.value;
    }
    return t;
  }
}

/// Whether the session gets the zones page.
bool hasZonesPage(CardioState s) => (s.sport == Sport.run && !s.indoor) || s.sport == Sport.swim;

/// Big live pace in its zone colour + one row per zone (fastest on top) with its pace
/// range, the time spent in it and markers for the current and the target zone.
class ZonesPage extends ConsumerWidget {
  const ZonesPage({super.key, required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final u = p.units;
    final z = LiveZones.of(s, p);
    if (z == null) return const SizedBox.shrink();
    final swim = s.sport == Sport.swim;
    final pace = z.livePace(s);
    final cur = pace == null ? null : z.indexOf(pace);
    final target = s.step == null ? null : z.codes.indexOf(normalizeZone(s.step!.zone, s.sport));
    final times = z.timeIn(s);
    final total = times.fold<int>(0, (a, b) => a + b);
    final most = times.fold<int>(0, max);
    final c = cur == null ? Theme.of(context).colorScheme.outline : zoneColor(z.codes[cur]);
    final cs = Theme.of(context).colorScheme;
    String fmt(int v) => fmtPaceSec(v, u, swim: swim);
    final unit = swim ? '/100 m' : (u.imperial ? '/mi' : '/km');

    final primary = Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: cur == null ? cs.surfaceContainer : c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: cur == null ? null : Border.all(color: c.withValues(alpha: 0.7), width: 2),
      ),
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pace == null ? '–:––' : fmt(pace),
                style: TextStyle(
                  fontSize: 110,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: cur == null ? null : _ink(context, c),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              cur == null ? l.zoneWaiting : '${zoneLabel(l, z.codes[cur], sport: s.sport)}  ·  ${l.currentPace} ($unit)',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    final rows = [
      for (var i = z.codes.length - 1; i >= 0; i--)
        _ZoneRow(
          code: z.codes[i],
          sport: s.sport,
          // Closed run zones show the same Daniels range as the zone info and the workout
          // steps ([PaceZones.range]); the cuts in between only classify the live pace.
          range: switch (z.shown(i) ?? z.bounds(i)) {
            // Fastest zone: faster than its slow bound; slowest zone: slower than its fast bound.
            (null, final int slow) => '< ${fmt(slow)}',
            (final int fast, null) => '> ${fmt(fast)}',
            (final int fast, final int slow) => '${fmt(fast)}–${fmt(slow)}',
            _ => '',
          },
          sec: times[i],
          share: total == 0 ? 0 : times[i] / total,
          bar: most == 0 ? 0 : times[i] / most,
          current: i == cur,
          target: i == target,
        ),
    ];
    const headerH = 24.0;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(height: 1.2);
    final header = SizedBox(
      height: headerH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(child: Text(l.zoneTimeIn, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle)),
            Text(clock(total), style: labelStyle?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        const rowMin = 44.0, rowMax = 60.0, gap = 6.0, primaryMin = 96.0;
        // Height left for the big number and the rows (bottom padding, gap, header, row gaps).
        final avail = box.maxHeight - 8 - 8 - headerH - rows.length * gap;
        if (avail - rows.length * rowMin >= primaryMin) {
          // Fill the page: rows grow up to [rowMax], the big number takes the rest.
          final rowH = ((avail - primaryMin) / rows.length).clamp(rowMin, rowMax);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: primary),
                const SizedBox(height: 8),
                header,
                for (final r in rows) ...[const SizedBox(height: gap), SizedBox(height: rowH, child: r)],
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            SizedBox(height: primaryMin, child: primary),
            const SizedBox(height: 8),
            header,
            for (final r in rows) ...[const SizedBox(height: gap), SizedBox(height: rowMin, child: r)],
          ],
        );
      },
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.code,
    required this.sport,
    required this.range,
    required this.sec,
    required this.share,
    required this.bar,
    required this.current,
    required this.target,
  });
  final String code, range;
  final Sport sport;
  final int sec;
  final double share, bar;
  final bool current, target;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final c = zoneColor(code);
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: current,
      child: Container(
        decoration: BoxDecoration(
          color: current ? c.withValues(alpha: 0.22) : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: current ? c : Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(0, 2, 10, 2),
        child: Row(
          children: [
            Container(
              width: 8,
              margin: const EdgeInsets.only(left: 6, right: 10),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
            ),
            Expanded(
              flex: 5,
              // Scales down instead of overflowing on small rows / large text.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: zoneLabel(l, code, sport: sport)),
                          if (target)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.flag_rounded, size: 16, color: _ink(context, c), semanticLabel: l.targetBand),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.2, color: current ? _ink(context, c) : null),
                    ),
                    Text(range, maxLines: 1, style: t.bodySmall?.copyWith(height: 1.2, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: LayoutBuilder(
                builder:
                    (_, b) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 12,
                        width: max(4, b.maxWidth * bar),
                        decoration: BoxDecoration(color: sec == 0 ? cs.surfaceContainerHighest : c, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      clock(sec),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text('${(share * 100).round()} %', style: t.bodySmall?.copyWith(height: 1.2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Plan vs. actual ─────────────────────────────

/// Whether the session gets the plan page (structured workouts only).
bool hasPlanPage(CardioState s) => s.structured;

/// Traffic-light status of a finished step: -1 too fast, 0 as planned / on target,
/// 1 too slow, 2 shortened (ended before its target). [measurable]: the actual pace is
/// known (GPS or pool lengths).
int stepResultStatus(WorkoutStep st, StepResult r, Sport sport, {required bool measurable}) {
  if (!r.complete && st.kind != 'recovery') return 2;
  final pace = measurable ? resultPace(r, sport) : null;
  if (pace != null && st.paceMin != null && st.paceMax != null) {
    final tol = sport == Sport.swim ? 3 : 5;
    if (pace < st.paceMin! - tol) return -1;
    if (pace > st.paceMax! + tol) return 1;
  }
  return 0;
}

/// Average pace of a finished step in target units (sec/km, swims sec/100 m), null when too short to tell.
int? resultPace(StepResult r, Sport sport) {
  if (r.distanceM < (sport == Sport.swim ? 20 : 50) || r.sec <= 0) return null;
  return (r.sec / r.distanceM * (sport == Sport.swim ? 100 : 1000)).round();
}

Color _statusColor(int status) => switch (status) {
  -1 => AppColors.swim,
  0 => AppColors.success,
  _ => AppColors.warning,
};

/// Label and colour of the projected-vs-planned difference [delta] (s): later than
/// planned → "behind plan" (orange), earlier → "ahead of plan" (green; orange when
/// sections were cut short), equal → "on plan".
(String, Color) planDeltaLabel(AppLocalizations l, int delta, {bool shortened = false}) {
  if (delta > 0) return (l.planBehind, AppColors.warning);
  if (delta < 0) return (l.planAhead, shortened ? AppColors.warning : AppColors.success);
  return (l.planOnPlan, AppColors.success);
}

/// Summary (projected finish vs. plan, intervals on target) and the current plus every
/// finished section with planned and actual values – newest first.
class PlanPage extends ConsumerWidget {
  const PlanPage({super.key, required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final measurable = !s.indoor || s.poolMode;
    final planned = s.steps.fold<int>(0, (a, st) => a + approxStepSec(st, s.sport));
    final projected = s.elapsed + s.workoutLeftSec;
    final delta = projected - planned;
    // Ahead of plan because sections were cut short is not "faster" – shown as a warning.
    final shortened = s.stepResults.any((r) => !r.complete && s.steps[r.index].kind != 'recovery');
    final (deltaLabel, deltaColor) = planDeltaLabel(l, delta, shortened: shortened);
    // Intervals on target: work steps with a pace target (else: sections done).
    final paced = [
      for (final r in s.stepResults)
        if (s.steps[r.index].isWork && s.steps[r.index].paceMin != null && measurable) r,
    ];
    final anyPaced = measurable && s.steps.any((st) => st.isWork && st.paceMin != null);
    final onTarget = paced.where((r) => stepResultStatus(s.steps[r.index], r, s.sport, measurable: true) == 0).length;
    final done = s.stepsDone ? s.steps.length : s.stepIndex;
    final summary = <Widget>[
      _Stat(clock(projected), l.planProjected),
      _Stat(clock(planned), l.planPlanned),
      _Stat(delta == 0 ? '±0:00' : '${delta < 0 ? '−' : '+'}${clock(delta.abs())}', deltaLabel, color: deltaColor),
      anyPaced ? _Stat('$onTarget/${paced.length}', l.planOnTarget) : _Stat('$done/${s.steps.length}', l.planDone),
    ];
    final left = max(0, s.steps.length - s.stepIndex - 1);
    final rows = <Widget>[
      if (s.step != null) _StepRow(s: s, index: s.stepIndex, units: u, measurable: measurable, left: left),
      for (final r in s.stepResults.reversed) _StepRow(s: s, index: r.index, result: r, units: u, measurable: measurable),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SizedBox(
          height: 150,
          child: Column(
            children: [
              Expanded(child: Row(children: [Expanded(child: summary[0]), const SizedBox(width: 8), Expanded(child: summary[1])])),
              const SizedBox(height: 8),
              Expanded(child: Row(children: [Expanded(child: summary[2]), const SizedBox(width: 8), Expanded(child: summary[3])])),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final r in rows) Padding(padding: const EdgeInsets.only(top: 8), child: r),
        if (s.stepResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.planNoneDone, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.color});
  final String value, label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
    child: Column(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 36,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: color == null ? null : _ink(context, color!),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}

/// One section: zone bar · title + plan · actual + status. Without [result] it is the
/// running section (live values, highlighted).
class _StepRow extends StatelessWidget {
  const _StepRow({required this.s, required this.index, required this.units, required this.measurable, this.result, this.left = 0});
  final CardioState s;
  final int index;
  final StepResult? result;
  final Units units;
  final bool measurable;
  final int left;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final st = s.steps[index];
    final u = units;
    final swim = s.sport == Sport.swim;
    final ride = s.sport == Sport.ride;
    final live = result == null;
    final r = result ?? StepResult(index, max(0, s.stepElapsed), max(0, s.stepDistance), complete: true);
    final c = zoneColor(st.zone);
    final target = [
      if (stepAmount(st, u, s.sport).isNotEmpty) stepAmount(st, u, s.sport),
      if (st.paceMin != null && st.paceMax != null) '${fmtPaceSec(st.paceMin!, u, swim: swim)}–${fmtPaceSec(st.paceMax!, u, swim: swim)}',
      if (st.paceMin == null && st.powerMin != null && st.powerMax != null) '${st.powerMin}–${st.powerMax} W',
    ].join(' · ');
    // Actual: time, plus distance (time steps) and average pace / speed when measurable.
    final pace = measurable ? resultPace(r, s.sport) : null;
    String distText(double m) => swim ? '${m.round()} m' : u.dist(m);
    final paceText =
        pace == null
            ? null
            : ride
            ? '${u.distOut(3600000 / pace).toStringAsFixed(1)} ${u.imperial ? 'mph' : 'km/h'}'
            : '${fmtPaceSec(pace, u, swim: swim)}${swim ? ' /100 m' : (u.imperial ? ' /mi' : ' /km')}';
    // Big value: pace / speed for distance steps and paced steps, else the time.
    final paceFirst = paceText != null && (st.distanceM != null || st.paceMin != null);
    final main = paceFirst ? paceText : clock(r.sec);
    final secondary = [
      if (paceFirst) clock(r.sec),
      // Distance: progress of a running distance step, covered distance of a time step.
      if (measurable && st.distanceM != null && live) '${distText(r.distanceM)} / ${distText(st.distanceM!)}',
      if (measurable && st.distanceM == null && r.distanceM > 0) distText(r.distanceM),
      if (!paceFirst && paceText != null) paceText,
    ].join(' · ');
    final status = live ? null : stepResultStatus(st, r, s.sport, measurable: measurable);
    final statusText = switch (status) {
      null => l.planNow,
      2 => l.planShort,
      -1 => l.tooFast,
      1 => l.tooSlow,
      _ => st.paceMin != null && measurable ? l.onPace : l.planDone,
    };
    final sc = status == null ? c : _statusColor(status);
    return Container(
      decoration: BoxDecoration(
        color: live ? c.withValues(alpha: 0.16) : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: live ? c.withValues(alpha: 0.8) : Colors.transparent, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              margin: const EdgeInsets.only(left: 6, right: 10),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stepTitle(l, s.steps, index, sport: s.sport),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  if (target.isNotEmpty)
                    Text(
                      '${l.planPlanned}: $target',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  if (live && left > 0) Text(l.planStepsLeft(left), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      main,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                  if (secondary.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(secondary, style: t.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(10)),
                    child: Text(statusText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
