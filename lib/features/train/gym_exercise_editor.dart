import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/exercise_measure.dart';
import '../../data/exercise_names_de.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/exercise_class.dart';
import '../../services/supersets.dart';
import '../../widgets/superset_group.dart';
import '../../widgets/common.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/exercise_media.dart';
import '../session/gym_session_page.dart' show SetTypeBadge;
import 'exercise_detail_page.dart';
import 'exercise_picker.dart';

/// Editable list of gym exercises (sets, rep ranges, set types, supersets, rest,
/// notes). Mutates [exercises] in place and calls [onChanged] after every change.
/// Used by the program editor and the planned-workout editor.
class GymExerciseEditor extends ConsumerWidget {
  const GymExerciseEditor({super.key, required this.exercises, required this.onChanged, this.subtitle, this.phase});
  final String? subtitle; // explanation under the header
  final String? phase; // plan phase for the weight suggestions shown as hints
  final List<GymExercise> exercises;
  final VoidCallback onChanged;

  void touch(VoidCallback f) {
    f();
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gymEditor(context, ref));

  /// Links exercise [i] with the next one into a superset (or unlinks). Supersets are
  /// adjacent runs of at most [maxSupersetSize] exercises.
  void _toggleSuperset(BuildContext context, int i) {
    if (supersetOf(exercises, i).contains(i + 1)) {
      touch(() => unlinkSuperset(exercises, i));
    } else if (canLinkSuperset(exercises, i)) {
      touch(() => linkSuperset(exercises, i));
    } else {
      toast(context, context.l10n.supersetMax);
    }
  }

  List<Widget> _gymEditor(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final minutes = estimateGymMinutes(exercises);
    final sets = exercises.fold<int>(0, (a, e) => a + e.workSets.length);
    // Supersets as blocks (adjacent runs – also for programs that were never normalised).
    final blocks = exerciseBlocks(exercises);
    Widget card(int i) => _ExerciseEditCard(
      suggested: ref.watch(loadPrescriberProvider).forExercise(exercises[i], phase: phase)?.weight,
      index: i,
      exercise: exercises[i],
      units: u,
      onChanged: () => touch(() {}),
      onRemove:
          () => touch(() {
            exercises.removeAt(i);
            normalizeSupersets(exercises);
          }),
      onReplace: () async {
        final picked = await pickExercises(context, single: true);
        if (picked.isEmpty) return;
        touch(() {
          final e = exercises[i];
          final wasTimed = e.isTimed;
          e.exId = picked.first.id;
          e.name = picked.first.name;
          e.timed = null;
          // Reps ↔ hold time: the sets switch their measure with the exercise.
          if (e.isTimed != wasTimed) _convertSets(e, ref.read(profileOrDefaultProvider).athlete.gymGoal);
        });
      },
    );
    return [
      Row(
        children: [
          Expanded(child: Text(l.exercises, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (exercises.isNotEmpty) Text('${l.setsN(sets)} · ~$minutes min', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)],
      const SizedBox(height: 8),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (a, b) {
          // A dragged exercise never tears a superset apart: dropped between two members it
          // joins them (or lands behind a full superset).
          if (a < 0 || a >= exercises.length) return;
          final moved = exercises[a];
          late SupersetMove move;
          touch(() => move = moveExercise(exercises, a, b > a ? b - 1 : b));
          if (move == SupersetMove.full) toast(context, l.supersetFullMoved);
          if (move == SupersetMove.joined && moved.group != null) toast(context, l.supersetJoined(moved.group!));
        },
        children: [
          for (final block in blocks)
            for (final i in block.indices)
              Column(
                key: ObjectKey(exercises[i]),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (block.grouped)
                    SupersetSegment(
                      letter: block.letter!,
                      position: i - block.start,
                      count: block.length,
                      badgeTop: 24, // next to the card's title row
                      trailing: TextButton(
                        key: ValueKey('dissolveSuperset-${block.letter}'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => touch(() => dissolveSuperset(exercises, i)),
                        child: Tooltip(
                          message: l.supersetDissolveTip,
                          child: Text(l.supersetDissolve, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      child: Column(
                        children: [
                          card(i),
                          // Inside the frame: the link to the next member (tap to split here).
                          if (i < block.end)
                            _SupersetLink(linked: true, onTap: () => _toggleSuperset(context, i))
                          else
                            const SizedBox(height: 4),
                        ],
                      ),
                    )
                  else
                    card(i),
                  // Between two blocks: "link as superset".
                  if (i == block.end && i < exercises.length - 1) _SupersetLink(linked: false, onTap: () => _toggleSuperset(context, i)),
                ],
              ),
        ],
      ),
      if (exercises.length > 1 && !blocks.any((b) => b.grouped))
        Padding(
          key: const ValueKey('supersetEditHint'),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(l.supersetEditHint, style: Theme.of(context).textTheme.bodySmall),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(l.addExercise),
        onPressed: () async {
          final picked = await pickExercises(context);
          final goal = ref.read(profileOrDefaultProvider).athlete.gymGoal;
          touch(() {
            for (final e in picked) {
              // Timed holds (plank, wall sit, …): 3 sets at the bottom of the hold range.
              if (isTimedExercise(e.id, e.name)) {
                final lo = defaultHoldRange(e.name).$1;
                exercises.add(GymExercise(exId: e.id, name: e.name, restSec: 60, sets: [for (var k = 0; k < 3; k++) GymSet(sec: lo)]));
                continue;
              }
              // Rep range from the exercise class and the gym goal (e.g. 5–8 for a squat,
              // 12–20 for lateral raises).
              final (lo, hi) = repRangeFor(classifyLift(e.id, e.name, info: e), goal);
              exercises.add(
                GymExercise(exId: e.id, name: e.name, repMin: lo, repMax: hi, sets: [for (var k = 0; k < 3; k++) GymSet(reps: lo)]),
              );
            }
          });
        },
      ),
    ];
  }
}

/// Switches the sets of [e] to its (new) measure: hold times at the bottom of the hold range for a
/// timed exercise, reps at the bottom of the rep range otherwise.
void _convertSets(GymExercise e, String goal) {
  e.holdMin = null;
  e.holdMax = null;
  if (e.isTimed) {
    final lo = e.holdRange.$1;
    for (final s in e.sets) {
      s
        ..sec = lo
        ..reps = 0
        ..target = null;
    }
  } else {
    final lo = repRangeOf(e, goal).$1;
    for (final s in e.sets) {
      s
        ..reps = lo
        ..sec = 0
        ..targetSec = null;
    }
  }
}

/// "Link as superset" connector between two exercises.
class _SupersetLink extends StatelessWidget {
  const _SupersetLink({required this.linked, required this.onTap});
  final bool linked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = linked ? AppColors.brand : Theme.of(context).colorScheme.outline;
    return SizedBox(
      height: 34,
      child: Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: c, visualDensity: VisualDensity.compact),
          onPressed: onTap,
          icon: Icon(linked ? Icons.link_rounded : Icons.add_link_rounded, size: 18),
          label: Text(linked ? l.supersetLinked : l.linkSuperset, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _ExerciseEditCard extends ConsumerWidget {
  const _ExerciseEditCard({
    required this.index,
    required this.exercise,
    required this.units,
    required this.onChanged,
    required this.onRemove,
    required this.onReplace,
    this.suggested,
  });
  final int index;
  final GymExercise exercise;
  final Units units;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onReplace;
  final double? suggested; // prescribed weight, shown as hint in empty weight fields

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = exercise;
    final u = units;
    final scheme = Theme.of(context).colorScheme;
    final name = exName(context, e.exId, e.name);

    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.drag_indicator, color: scheme.outline)),
              ),
              GestureDetector(
                onTap: () async {
                  final db = await ref.read(exerciseDbProvider.future);
                  final ex = db.byId(e.exId);
                  if (ex != null && context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: ex)));
                  }
                },
                child: ExerciseMedia(exId: e.exId, animated: false, size: 44, radius: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gym),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (e.isTimed)
                          _MiniChip(
                            key: const ValueKey('holdRangeChip'),
                            icon: Icons.timer_outlined,
                            text: '${e.holdRange.$1}–${e.holdRange.$2} s',
                            onTap: () async {
                              final r = await _askHoldRange(context, e.holdRange.$1, e.holdRange.$2);
                              if (r == null) return;
                              e.holdMin = r.$1;
                              e.holdMax = r.$2;
                              for (final s in e.sets.where((s) => !s.warmup && s.sec < r.$1)) {
                                s.sec = r.$1;
                              }
                              onChanged();
                            },
                          )
                        else
                          _MiniChip(
                            icon: Icons.repeat_rounded,
                            text: () {
                              final (lo, hi) = repRangeOf(e, ref.watch(profileOrDefaultProvider).athlete.gymGoal);
                              return '$lo–$hi ${l.reps}';
                            }(),
                            onTap: () async {
                              final auto = repRangeOf(e, ref.read(profileOrDefaultProvider).athlete.gymGoal);
                              final r = await _askRange(context, e.repMin ?? auto.$1, e.repMax ?? auto.$2);
                              if (r == null) return;
                              e.repMin = r.$1;
                              e.repMax = r.$2;
                              for (final s in e.sets.where((s) => !s.warmup && s.reps < r.$1)) {
                                s.reps = r.$1;
                              }
                              onChanged();
                            },
                          ),
                        _MiniChip(
                          icon: Icons.hourglass_bottom_rounded,
                          text: clock(e.restSec),
                          onTap: () async {
                            final v = await _askRest(context, e.restSec);
                            if (v == null) return;
                            e.restSec = v;
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: scheme.outline),
                onSelected: (v) async {
                  switch (v) {
                    case 'replace':
                      onReplace();
                    case 'bodyweight':
                      e.bw = !_isBw(ref, e);
                      onChanged();
                    case 'timed':
                      e.timed = !e.isTimed;
                      _convertSets(e, ref.read(profileOrDefaultProvider).athlete.gymGoal);
                      onChanged();
                    case 'note':
                      final t = await askText(context, l.note, initial: e.note);
                      if (t != null) {
                        e.note = t;
                        onChanged();
                      }
                    case 'remove':
                      onRemove();
                  }
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'replace',
                        child: ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: Text(l.replaceExercise)),
                      ),
                      PopupMenuItem(value: 'note', child: ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: Text(l.note))),
                      if (!e.isTimed &&
                          offersBodyweightMode(
                            e.exId,
                            e.name,
                            info: ref.watch(exerciseDbProvider).value?.byId(e.exId),
                            current: _isBw(ref, e),
                          ))
                        CheckedPopupMenuItem(value: 'bodyweight', checked: _isBw(ref, e), child: Text(l.bodyweight)),
                      CheckedPopupMenuItem(
                        key: const ValueKey('timedToggle'),
                        value: 'timed',
                        checked: e.isTimed,
                        child: Text(l.timedMode),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                          title: Text(l.remove, style: const TextStyle(color: AppColors.danger)),
                        ),
                      ),
                    ],
              ),
            ],
          ),
          if (e.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 14, color: scheme.outline),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    e.isTimed && _isBw(ref, e)
                        ? '+ ${u.weightUnit}'
                        : _isBw(ref, e)
                        ? '${l.bodyweightShort} ± ${u.weightUnit}'
                        : u.weightUnit,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.isTimed ? l.holdTime : l.reps, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          for (var s = 0; s < e.sets.length; s++)
            Padding(
              key: ObjectKey(e.sets[s]),
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SetTypeBadge(
                        set: e.sets[s],
                        index: e.sets.take(s).where((x) => x.type == SetType.normal).length,
                        onChanged: (t) {
                          e.sets[s].type = t;
                          onChanged();
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NumField(
                      signed: _isBw(ref, e),
                      initial: e.sets[s].weight == 0 ? '' : Units.num(u.weightOut(e.sets[s].weight), 2),
                      hint: suggested != null && suggested! > 0 ? '≈${Units.num(u.weightOut(suggested!), 2)}' : '–',
                      onChanged: (v) => e.sets[s].weight = u.weightIn(parseNum(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        e.isTimed
                            ? _HoldField(
                              key: ValueKey('holdField-$index-$s'),
                              sec: e.sets[s].sec,
                              hint: e.holdRange.$1,
                              onChanged: (v) {
                                e.sets[s].sec = v;
                                onChanged();
                              },
                            )
                            : _NumField(
                              initial: e.sets[s].reps == 0 ? '' : '${e.sets[s].reps}',
                              hint: e.repMin != null ? '${e.repMin}' : '–',
                              onChanged: (v) => e.sets[s].reps = int.tryParse(v) ?? 0,
                            ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: Icon(Icons.remove_circle_outline, size: 20, color: scheme.outline),
                      onPressed:
                          e.sets.length > 1
                              ? () {
                                e.sets.removeAt(s);
                                onChanged();
                              }
                              : null,
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final last = e.sets.isNotEmpty ? e.sets.last : (e.isTimed ? GymSet(sec: e.holdRange.$1) : GymSet(reps: e.repMin ?? 10));
                e.sets.add(GymSet(weight: last.weight, reps: last.reps, sec: last.sec));
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.addSet),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isBw(WidgetRef ref, GymExercise e) => ref.read(loadPrescriberProvider).isBodyweight(e);

  static Future<(int, int)?> _askRange(BuildContext context, int lo, int hi) {
    final l = context.l10n;
    var a = lo, b = hi;
    return showModalBottomSheet<(int, int)>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setS) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.repRange, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(l.repRangeHint, style: Theme.of(c).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Center(child: Text('$a – $b', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
                        RangeSlider(
                          values: RangeValues(a.toDouble(), b.toDouble()),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          onChanged:
                              (v) => setS(() {
                                a = v.start.round();
                                b = v.end.round();
                              }),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final p in const [(3, 5), (5, 8), (6, 10), (8, 12), (10, 15), (12, 20)])
                              ActionChip(label: Text('${p.$1}–${p.$2}'), onPressed: () => setS(() => (a, b) = p)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => Navigator.pop(c, (a, b)), child: Text(l.apply)),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  /// Hold-time range of a timed exercise (5–300 s).
  static Future<(int, int)?> _askHoldRange(BuildContext context, int lo, int hi) {
    final l = context.l10n;
    var a = lo.clamp(5, 300), b = hi.clamp(5, 300);
    return showModalBottomSheet<(int, int)>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setS) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.holdRange, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(l.holdRangeHint, style: Theme.of(c).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            '${formatHold(a)} – ${formatHold(b)}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                        RangeSlider(
                          values: RangeValues(a.toDouble(), b.toDouble()),
                          min: 5,
                          max: 300,
                          divisions: 59,
                          onChanged:
                              (v) => setS(() {
                                a = v.start.round();
                                b = v.end.round();
                              }),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final p in const [(10, 30), (20, 45), (30, 60), (45, 90), (60, 120)])
                              ActionChip(label: Text('${p.$1}–${p.$2} s'), onPressed: () => setS(() => (a, b) = p)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => Navigator.pop(c, (a, b)), child: Text(l.apply)),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  static Future<int?> _askRest(BuildContext context, int sec) {
    final l = context.l10n;
    return showModalBottomSheet<int>(
      context: context,
      builder:
          (c) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.restTimeSeconds, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(l.restHint, style: Theme.of(c).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in const [30, 45, 60, 75, 90, 120, 150, 180, 240])
                        ChoiceChip(label: Text(clock(s)), selected: s == sec, onSelected: (_) => Navigator.pop(c, s)),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// Hold time of one planned set: a tappable "0:45" that opens the scroll wheels.
class _HoldField extends StatelessWidget {
  const _HoldField({super.key, required this.sec, required this.hint, required this.onChanged});
  final int sec, hint;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final pick = await showDurationPicker(
          context,
          title: l.holdTime,
          value: sec > 0 ? sec : null,
          initial: hint,
          units: DurationUnits.ms,
          maxMinutes: 15,
          min: 1,
          max: 15 * 60,
          clearable: false,
        );
        final v = pick?.seconds;
        if (v != null && v > 0) onChanged(v);
      },
      child: InputDecorator(
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
        child: Text(
          sec > 0 ? clock(sec) : clock(hint),
          textAlign: TextAlign.center,
          style: TextStyle(color: sec > 0 ? null : Theme.of(context).hintColor, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({super.key, required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 3),
          // Flexible: a long chip ("8–12 Wdh.") is cut off instead of overflowing on narrow screens.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NumField extends StatelessWidget {
  const _NumField({required this.initial, required this.onChanged, this.hint, this.signed = false});
  final bool signed; // bodyweight mode: negative = assistance
  final String initial;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    textAlign: TextAlign.center,
    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
    decoration: InputDecoration(isDense: true, hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
    onChanged: onChanged,
  );
}
