import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import 'step_text.dart';
import 'zone_info.dart' show showSwimDrills;

/// Rough duration of a step in seconds (for proportional drawing).
int _approxSec(WorkoutStep s, Sport sport) {
  if (s.durationSec != null) return s.durationSec!;
  final d = s.distanceM ?? 0;
  if (sport == Sport.swim) return (d / 100 * (s.paceMax ?? 120)).round();
  final pace = ((s.paceMin ?? 360) + (s.paceMax ?? 360)) / 2;
  return (d / 1000 * pace).round();
}

double _intensity(String zone) => switch (zone) {
  'walk' || 'REC' || 'Z1' => 0.25,
  'DR' => 0.4,
  'E' || 'L' || 'Z2' || 'EN' => 0.45,
  'M' || 'Z3' || 'TE' => 0.62,
  'T' || 'SS' || 'Z4' || 'CSS' => 0.78,
  'I' || 'Z5' => 0.92,
  _ => 1.0,
};

/// Zwift/Runna style intensity profile of a structured workout.
class WorkoutProfileBar extends StatelessWidget {
  const WorkoutProfileBar({super.key, required this.steps, required this.sport, this.height = 44, this.current});
  final List<WorkoutStep> steps;
  final Sport sport;
  final double height;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final secs = steps.map((s) => max(20, _approxSec(s, sport))).toList();
    return SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _ProfilePainter(steps, secs, current)));
  }
}

/// Paints the bars proportionally to their duration. Painting (instead of a Row of
/// fixed-width boxes) can never overflow, however many short steps a workout has.
class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.steps, this.secs, this.current);
  final List<WorkoutStep> steps;
  final List<int> secs;
  final int? current;

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;
    final total = secs.fold<int>(0, (a, b) => a + b);
    final gap = steps.length > 40 ? 0.75 : 1.5;
    final usable = size.width - gap * (steps.length - 1);
    var x = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final w = max(0.5, usable * secs[i] / total);
      final h = size.height * _intensity(steps[i].zone);
      final alpha = current == null || current == i ? 1.0 : (i < current! ? 0.35 : 0.7);
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - h, w, h),
        topLeft: Radius.circular(min(3, w / 2)),
        topRight: Radius.circular(min(3, w / 2)),
      );
      canvas.drawRRect(r, Paint()..color = zoneColor(steps[i].zone).withValues(alpha: alpha));
      if (current == i) {
        canvas.drawRRect(
          r,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter old) => old.steps != steps || old.current != current;
}

/// A group of identical repeats (e.g. 6 × [800 m I + 2:00 jog]) or a single step.
class _Group {
  _Group(this.first, this.items, this.reps);
  final int first;
  final List<WorkoutStep> items;
  final int reps;
}

bool _same(WorkoutStep a, WorkoutStep b) =>
    a.kind == b.kind && a.zone == b.zone && a.distanceM == b.distanceM && a.durationSec == b.durationSec;

List<_Group> _groups(List<WorkoutStep> steps) {
  final out = <_Group>[];
  var i = 0;
  while (i < steps.length) {
    // Pattern: work, recovery, work, recovery … (last recovery optional)
    if (steps[i].isWork && i + 1 < steps.length && steps[i + 1].kind == 'recovery') {
      var reps = 1;
      var j = i + 2;
      while (j < steps.length && _same(steps[j], steps[i])) {
        reps++;
        if (j + 1 < steps.length && _same(steps[j + 1], steps[i + 1])) {
          j += 2;
        } else {
          j += 1;
          break;
        }
      }
      if (reps > 1) {
        out.add(_Group(i, [steps[i], steps[i + 1]], reps));
        i = j;
        continue;
      }
    }
    // Pattern: identical consecutive work steps (e.g. strides without recovery)
    out.add(_Group(i, [steps[i]], 1));
    i++;
  }
  return out;
}

/// Readable list of workout steps, repeats collapsed.
class StepList extends StatelessWidget {
  const StepList({super.key, required this.steps, required this.sport, required this.units, this.dense = false, this.current});
  final List<WorkoutStep> steps;
  final Sport sport;
  final Units units;
  final bool dense;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final groups = _groups(steps);
    final t = Theme.of(context).textTheme;
    Widget line(WorkoutStep s, int index) {
      final target = stepTarget(l, s, units, sport);
      final isCurrent = index == current;
      return Container(
        // Live screen: highlight the step being done right now.
        decoration:
            isCurrent ? BoxDecoration(color: zoneColor(s.zone).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)) : null,
        padding: EdgeInsets.symmetric(vertical: dense ? 3 : 6, horizontal: isCurrent ? 4 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: dense ? 30 : 38,
              decoration: BoxDecoration(color: zoneColor(s.zone), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(() {
                    final title = s.isWork ? null : stepTitle(l, steps, index, sport: sport);
                    final zone = zoneLabel(l, s.zone, sport: sport, note: s.note);
                    // "Recovery · 1:30 · Recovery" → "Recovery · 1:30".
                    // A swim rest is standing at the wall – no intensity to show.
                    final showZone = zone != title && !(sport == Sport.swim && s.kind == 'recovery');
                    return [if (title != null) title, stepAmount(s, units, sport), if (showZone) zone].join(' · ');
                  }(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: dense ? 13 : 14)),
                  if (target.isNotEmpty) Text(target, style: t.bodySmall),
                  if (!dense && s.note.isNotEmpty) Text(s.note, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  if (!dense && s.zone == 'DR')
                    InkWell(
                      onTap: () => showSwimDrills(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 15, color: zoneColor('DR')),
                            const SizedBox(width: 4),
                            Text(l.showDrills, style: t.bodySmall?.copyWith(color: zoneColor('DR'), fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: dense ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
      children: [
        for (final g in groups)
          if (g.reps > 1)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${g.reps} ×', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  for (var k = 0; k < g.items.length; k++) line(g.items[k], g.first + k),
                ],
              ),
            )
          else
            line(g.items.first, g.first),
      ],
    );
  }
}
