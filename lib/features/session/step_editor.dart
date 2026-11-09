import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/zones.dart';
import '../../widgets/segments.dart';
import 'step_list.dart';
import 'step_text.dart';
import 'zone_info.dart';

export 'zone_info.dart' show zonesFor, intensitiesFor, deriveIntensity, ZoneInfoButton, showZoneInfo;

/// Fills pace / power / heart-rate targets of [s] from the athlete's zones.
WorkoutStep withTargets(WorkoutStep s, Sport sport, UserProfile p) {
  final a = p.athlete;
  final hz = HrZones(p.estimatedMaxHr, a.restHr);
  final hrN = hrZoneOf(s.zone);
  final hr = hrN == null || s.zone == 'walk' ? null : hz.zone(hrN);
  int? p0, p1, w0, w1;
  switch (sport) {
    case Sport.run:
      if (s.zone != 'walk' && (Vdot.of(a) != null || p.level != 'beginner')) {
        final r = PaceZones(Vdot.of(a) ?? Vdot.defaultFor(p.level)).range(s.zone);
        p0 = r.$1;
        p1 = r.$2;
      }
    case Sport.ride:
      final ftp = a.ftp ?? (a.hasPowerMeter ? PowerZones.estimate(p.level, p.weightKg) : null);
      if (ftp != null) {
        final r = PowerZones(ftp).range(s.zone);
        w0 = r.$1;
        w1 = r.$2;
      }
    case Sport.swim:
      final css = SwimZones.fromTests(a.swim400Sec, a.swim200Sec);
      if (css != null && s.zone != 'REC') {
        final r = SwimZones(css).range(s.zone);
        p0 = r.$1;
        p1 = r.$2;
      }
    case Sport.gym:
      break;
  }
  return WorkoutStep(
    kind: s.kind,
    durationSec: s.durationSec,
    distanceM: s.distanceM,
    zone: s.zone,
    paceMin: p0,
    paceMax: p1,
    powerMin: w0,
    powerMax: w1,
    hrMin: sport == Sport.swim ? null : hr?.$1,
    hrMax: sport == Sport.swim ? null : hr?.$2,
    note: s.note,
  );
}

/// A single step or a repeat block (n × [work, recovery]).
class StepBlock {
  StepBlock(this.steps, [this.reps = 1]);
  List<WorkoutStep> steps;
  int reps;

  bool get isRepeat => reps > 1 || steps.length > 1;

  List<WorkoutStep> flatten() => [
    for (var i = 0; i < reps; i++) ...[
      for (var k = 0; k < steps.length; k++)
        // The last recovery of a repeat block is dropped (the next step follows directly).
        if (!(i == reps - 1 && k == steps.length - 1 && steps.length > 1 && steps[k].kind == 'recovery')) steps[k],
    ],
  ];
}

bool _same(WorkoutStep a, WorkoutStep b) =>
    a.kind == b.kind && a.zone == b.zone && a.distanceM == b.distanceM && a.durationSec == b.durationSec;

/// Collapses expanded repeats back into blocks.
List<StepBlock> toBlocks(List<WorkoutStep> steps) {
  final out = <StepBlock>[];
  var i = 0;
  while (i < steps.length) {
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
        out.add(StepBlock([steps[i], steps[i + 1]], reps));
        i = j;
        continue;
      }
    }
    out.add(StepBlock([steps[i]]));
    i++;
  }
  return out;
}

String kindLabel(AppLocalizations l, String kind) => switch (kind) {
  'warmup' => l.stepWarmup,
  'cooldown' => l.stepCooldown,
  'recovery' => l.stepRecovery,
  'work' => l.stepWork,
  _ => l.stepSteady,
};

/// Editor for structured endurance workouts: phases (warm-up, main set, cool-down)
/// and repeat blocks, with an intensity profile preview.
class StepEditor extends StatefulWidget {
  const StepEditor({super.key, required this.steps, required this.sport, required this.profile, required this.onChanged});
  final List<WorkoutStep> steps;
  final Sport sport;
  final UserProfile profile;
  final ValueChanged<List<WorkoutStep>> onChanged;

  @override
  State<StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<StepEditor> {
  late List<StepBlock> _blocks = toBlocks(widget.steps);

  @override
  void didUpdateWidget(StepEditor old) {
    super.didUpdateWidget(old);
    if (old.sport != widget.sport) _blocks = toBlocks(widget.steps);
  }

  void _emit() {
    setState(() {});
    widget.onChanged([for (final b in _blocks) ...b.flatten()]);
  }

  WorkoutStep _default(String kind) {
    final sport = widget.sport;
    final zone = switch ((sport, kind)) {
      (Sport.run, 'work') => 'T',
      (Sport.run, 'recovery') => 'REC',
      (Sport.run, _) => 'E',
      (Sport.ride, 'work') => 'SS',
      (Sport.ride, 'recovery' || 'cooldown') => 'Z1',
      (Sport.ride, _) => 'Z2',
      (Sport.swim, 'work') => 'CSS',
      (Sport.swim, 'recovery' || 'warmup' || 'cooldown') => 'REC',
      (Sport.swim, _) => 'EN',
      _ => 'E',
    };
    final step = switch (kind) {
      'recovery' => WorkoutStep(kind: kind, zone: zone, durationSec: sport == Sport.swim ? 20 : 120),
      _ when sport == Sport.swim => WorkoutStep(kind: kind, zone: zone, distanceM: kind == 'work' ? 100 : 200),
      'work' => WorkoutStep(kind: kind, zone: zone, durationSec: sport == Sport.ride ? 600 : 300),
      _ => WorkoutStep(kind: kind, zone: zone, durationSec: kind == 'steady' ? 1800 : 600),
    };
    return withTargets(step, sport, widget.profile);
  }

  Future<void> _edit(StepBlock b, int k) async {
    final res = await showModalBottomSheet<WorkoutStep?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StepSheet(step: b.steps[k], sport: widget.sport, inRepeat: b.isRepeat, profile: widget.profile),
    );
    if (res == null) return;
    b.steps[k] = withTargets(res, widget.sport, widget.profile);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final flat = [for (final b in _blocks) ...b.flatten()];
    final u = widget.profile.units;
    final sec = estimateStepsSec(flat, widget.sport, widget.profile);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flat.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkoutProfileBar(steps: flat, sport: widget.sport, height: 40),
                const SizedBox(height: 8),
                Text(
                  // Distance says more than a section count (a swim set easily has 30 sections).
                  '≈ ${humanDuration(sec)} · ${stepsDistance(flat, u, widget.sport) ?? l.stepsCount(flat.length)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (a, b) {
            final x = _blocks.removeAt(a);
            _blocks.insert(b > a ? b - 1 : b, x);
            _emit();
          },
          children: [
            for (var i = 0; i < _blocks.length; i++)
              Padding(
                key: ObjectKey(_blocks[i]),
                padding: const EdgeInsets.only(bottom: 8),
                child: _BlockCard(
                  index: i,
                  block: _blocks[i],
                  sport: widget.sport,
                  units: u,
                  onTapStep: (k) => _edit(_blocks[i], k),
                  onReps: (r) {
                    _blocks[i].reps = r;
                    _emit();
                  },
                  onDelete: () {
                    _blocks.removeAt(i);
                    _emit();
                  },
                  onDuplicate: () {
                    _blocks.insert(i + 1, StepBlock([..._blocks[i].steps], _blocks[i].reps));
                    _emit();
                  },
                ),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!_blocks.any((b) => b.steps.first.kind == 'warmup'))
              ActionChip(
                avatar: const Icon(Icons.wb_twilight_rounded, size: 18),
                label: Text(l.stepWarmup),
                onPressed: () {
                  _blocks.insert(0, StepBlock([_default('warmup')]));
                  _emit();
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: Text(l.addSection),
              onPressed: () {
                final cdIdx = _blocks.indexWhere((b) => b.steps.first.kind == 'cooldown');
                _blocks.insert(cdIdx < 0 ? _blocks.length : cdIdx, StepBlock([_default(_blocks.isEmpty ? 'steady' : 'work')]));
                _emit();
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.repeat_rounded, size: 18),
              label: Text(l.addRepeat),
              onPressed: () {
                final cdIdx = _blocks.indexWhere((b) => b.steps.first.kind == 'cooldown');
                _blocks.insert(cdIdx < 0 ? _blocks.length : cdIdx, StepBlock([_default('work'), _default('recovery')], 5));
                _emit();
              },
            ),
            if (!_blocks.any((b) => b.steps.first.kind == 'cooldown'))
              ActionChip(
                avatar: const Icon(Icons.nights_stay_outlined, size: 18),
                label: Text(l.stepCooldown),
                onPressed: () {
                  _blocks.add(StepBlock([_default('cooldown')]));
                  _emit();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.index,
    required this.block,
    required this.sport,
    required this.units,
    required this.onTapStep,
    required this.onReps,
    required this.onDelete,
    required this.onDuplicate,
  });
  final int index;
  final StepBlock block;
  final Sport sport;
  final Units units;
  final ValueChanged<int> onTapStep;
  final ValueChanged<int> onReps;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget stepRow(int k) {
      final s = block.steps[k];
      final target = stepTarget(l, s, units, sport);
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTapStep(k),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(width: 5, height: 36, decoration: BoxDecoration(color: zoneColor(s.zone), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${kindLabel(l, s.kind)} · ${stepAmount(s, units, sport)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      [zoneLabel(l, s.zone, sport: sport), if (target.isNotEmpty) target].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 16, color: scheme.outline),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: block.isRepeat ? Border.all(color: zoneColor(block.steps.first.zone).withValues(alpha: 0.5)) : null,
      ),
      padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(padding: const EdgeInsets.fromLTRB(8, 14, 4, 8), child: Icon(Icons.drag_indicator, color: scheme.outline)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.isRepeat)
                  Row(
                    children: [
                      const Icon(Icons.repeat_rounded, size: 18),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: block.reps > 2 ? () => onReps(block.reps - 1) : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                      Text('${block.reps} ×', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: block.reps < 40 ? () => onReps(block.reps + 1) : null,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                    ],
                  ),
                for (var k = 0; k < block.steps.length; k++) stepRow(k),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: scheme.outline),
            onSelected: (v) => v == 'dup' ? onDuplicate() : onDelete(),
            itemBuilder:
                (_) => [
                  PopupMenuItem(value: 'dup', child: Text(l.duplicate)),
                  PopupMenuItem(value: 'del', child: Text(l.delete, style: const TextStyle(color: AppColors.danger))),
                ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to edit one step: phase type, time/distance, zone, note.
class _StepSheet extends StatefulWidget {
  const _StepSheet({required this.step, required this.sport, required this.inRepeat, required this.profile});
  final WorkoutStep step;
  final Sport sport;
  final bool inRepeat;
  final UserProfile profile;

  @override
  State<_StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends State<_StepSheet> {
  late String _kind = widget.step.kind;
  late bool _byDistance = widget.step.distanceM != null;
  late int _sec = widget.step.durationSec ?? 600;
  late double _m = widget.step.distanceM ?? (widget.sport == Sport.swim ? 100 : 1000);
  late String _zone = _initialZone();

  String _initialZone() {
    final z = normalizeZone(widget.step.zone, widget.sport);
    // Keep 'walk' for run/walk sessions (beginner plans) even though it is not offered.
    if (widget.step.zone == 'walk') return 'walk';
    return zonesFor(widget.sport).contains(z) ? z : zonesFor(widget.sport).first;
  }

  late final _note = TextEditingController(text: widget.step.note);

  List<double> get _distances =>
      widget.sport == Sport.swim
          ? const [25, 50, 75, 100, 150, 200, 300, 400, 500, 800, 1000, 1500]
          : const [100, 200, 400, 600, 800, 1000, 1200, 1600, 2000, 3000, 5000, 8000, 10000, 15000, 21097, 30000];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kinds = widget.inRepeat ? const ['work', 'recovery'] : const ['warmup', 'steady', 'work', 'recovery', 'cooldown'];
    final dIdx = _distances.indexWhere((d) => d >= _m);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.editSection, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in kinds)
                    ChoiceChip(label: Text(kindLabel(l, k)), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
                ],
              ),
              const SizedBox(height: 16),
              Segments<bool>(
                segments: [Seg(false, label: l.byTime, icon: Icons.timer_outlined), Seg(true, label: l.byDistance, icon: Icons.straighten)],
                value: _byDistance,
                onChanged: (v) => setState(() => _byDistance = v),
              ),
              const SizedBox(height: 12),
              if (_byDistance)
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: dIdx > 0 ? () => setState(() => _m = _distances[max(0, dIdx - 1)]) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _m >= 1000 && widget.sport != Sport.swim ? '${Units.num(_m / 1000, 2)} km' : '${_m.round()} m',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed:
                          dIdx >= 0 && dIdx < _distances.length - 1
                              ? () => setState(() => _m = _distances[_m == _distances[dIdx] ? dIdx + 1 : dIdx])
                              : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _sec > 10 ? () => setState(() => _sec = max(10, _sec - _secStep)) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        clock(_sec),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(onPressed: () => setState(() => _sec += _secStep), icon: const Icon(Icons.add_rounded)),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(l.intensity, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ZoneInfoButton(sport: widget.sport, profile: widget.profile, highlight: _zone),
                ],
              ),
              for (final z in zonesFor(widget.sport)) _zoneOption(z),
              const SizedBox(height: 12),
              TextField(controller: _note, decoration: InputDecoration(labelText: l.note)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      context,
                      WorkoutStep(
                        kind: _kind,
                        zone: _zone,
                        durationSec: _byDistance ? null : _sec,
                        distanceM: _byDistance ? _m : null,
                        note: _note.text.trim(),
                      ),
                    ),
                child: Text(l.apply),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneOption(String z) {
    final l = context.l10n;
    final c = zoneColor(z);
    final sel = normalizeZone(_zone, widget.sport) == z;
    final (target, est) = zoneTarget(z, widget.sport, widget.profile);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: sel ? c.withValues(alpha: 0.16) : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _zone = z),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? c : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(zoneLabel(l, z, sport: widget.sport), style: const TextStyle(fontWeight: FontWeight.w600))),
                if (target.isNotEmpty)
                  Flexible(
                    child: Text(
                      '${est ? '≈ ' : ''}${target.split(' · ').first}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  Text(zoneFeel(l, z, widget.sport), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get _secStep => _sec < 60 ? 5 : (_sec < 300 ? 15 : (_sec < 1200 ? 60 : 300));
}
