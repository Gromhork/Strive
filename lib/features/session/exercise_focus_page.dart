import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/exercise_db.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/active_workout.dart';
import '../../services/gym_tools.dart';
import '../../services/load_prescription.dart';
import '../../widgets/common.dart';
import '../../widgets/effort_chips.dart';
import '../../widgets/exercise_media.dart';
import '../../widgets/prescription.dart';
import '../train/exercise_detail_page.dart';
import 'gym_session_page.dart';

/// One exercise per screen (swipe between exercises): demo animation, sets,
/// big steppers for weight & reps, RPE, warm-up & plate calculator,
/// progression hint and a full-screen rest timer.
class ExerciseFocusPage extends ConsumerStatefulWidget {
  const ExerciseFocusPage({super.key});

  @override
  ConsumerState<ExerciseFocusPage> createState() => _ExerciseFocusPageState();
}

class _ExerciseFocusPageState extends ConsumerState<ExerciseFocusPage> {
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: ref.read(activeGymProvider)?.focus ?? 0);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = ref.watch(activeGymProvider);
    if (w == null || w.exercises.isEmpty) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noActiveWorkout)));
    }
    // Follow focus changes coming from the notifier (supersets, next exercise).
    ref.listen(activeGymProvider.select((s) => s?.focus), (prev, next) {
      if (next != null && _pc.hasClients && _pc.page?.round() != next) {
        _pc.animateToPage(next, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final n = ref.read(activeGymProvider.notifier);
    final focus = w.focus.clamp(0, w.exercises.length - 1);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.title, style: const TextStyle(fontSize: 16)),
                StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder:
                      (_, __) => Text(
                        '${l.exerciseXofY(focus + 1, w.exercises.length)} · ${clock(DateTime.now().difference(w.start).inSeconds)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                ),
              ],
            ),
            actions: [ExerciseMenu(index: focus, w: w, n: n)],
            bottom: PreferredSize(preferredSize: const Size.fromHeight(6), child: _ExerciseDots(w: w, onTap: (i) => n.setFocus(i))),
          ),
          body: PageView.builder(
            controller: _pc,
            itemCount: w.exercises.length,
            onPageChanged: (i) {
              if (i != ref.read(activeGymProvider)?.focus) n.setFocus(i);
            },
            itemBuilder: (_, i) => _FocusExercise(key: ValueKey('focus-${w.exercises[i].exId}-$i'), index: i),
          ),
        ),
        if (w.restEnd != null) const Positioned.fill(child: _RestOverlay()),
      ],
    );
  }
}

class _ExerciseDots extends StatelessWidget {
  const _ExerciseDots({required this.w, required this.onTap});
  final ActiveGym w;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < w.exercises.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color:
                        w.exercises[i].allDone
                            ? AppColors.success
                            : i == w.focus
                            ? AppColors.gym
                            : scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusExercise extends ConsumerStatefulWidget {
  const _FocusExercise({super.key, required this.index});
  final int index;

  @override
  ConsumerState<_FocusExercise> createState() => _FocusExerciseState();
}

class _FocusExerciseState extends ConsumerState<_FocusExercise> {
  int? _sel; // selected set index (defaults to first open set)

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final w = ref.watch(activeGymProvider)!;
    if (widget.index >= w.exercises.length) return const SizedBox.shrink();
    final n = ref.read(activeGymProvider.notifier);
    final e = w.exercises[widget.index];
    final u = ref.watch(profileOrDefaultProvider).units;
    final db = ref.watch(exerciseDbProvider).value;
    final info = db?.byId(e.exId);
    // Last time's sets in the current mode (bodyweight: added load).
    final lastWork = ref.watch(loadPrescriberProvider).previousSets(e)?.where((s) => !s.warmup).toList();
    final firstOpen = e.sets.indexWhere((s) => !s.done);
    final sel = (_sel != null && _sel! < e.sets.length) ? _sel! : (firstOpen < 0 ? null : firstOpen);
    final rx = ref.watch(loadPrescriberProvider).forExercise(e, phase: planPhaseOf(ref.watch(planListProvider), w.planId));
    final group = w.groupOf(widget.index);
    final t = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // ── Demo animation ──
              Stack(
                children: [
                  Hero(
                    tag: 'ex-media-${widget.index}',
                    child: AspectRatio(aspectRatio: 1.75, child: ExerciseMedia(exId: e.exId, radius: 24)),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Column(
                      children: [
                        _GlassButton(
                          icon: Icons.info_outline_rounded,
                          onTap:
                              info == null
                                  ? null
                                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: info))),
                        ),
                        const SizedBox(height: 8),
                        _GlassButton(
                          icon: Icons.play_circle_outline_rounded,
                          onTap:
                              () => launchUrl(
                                Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent('${e.name} proper form')}'),
                                mode: LaunchMode.externalApplication,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (group.length > 1)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${l.superset} ${e.group} · ${group.indexOf(widget.index) + 1}/${group.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(capitalize(e.name), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
              if (info != null) ...[
                const SizedBox(height: 4),
                Text(
                  [term(info.target, lang), ...info.secondary.take(2).map((s) => term(s, lang))].join(' · '),
                  style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              if (rx != null) ...[
                const SizedBox(height: 12),
                PrescriptionHint(
                  prescription: rx,
                  units: u,
                  onApply:
                      e.doneSets > 0 || _matches(e, rx)
                          ? null
                          : () {
                            var wi = 0;
                            for (var k = 0; k < e.sets.length; k++) {
                              final s = e.sets[k];
                              if (s.warmup || s.type == SetType.drop) continue;
                              final reps = rx.repsForSet(wi++);
                              if (!s.done) n.updateSet(widget.index, k, weight: rx.weight, reps: reps);
                            }
                          },
                ),
              ],
              const SizedBox(height: 16),
              // ── Sets ──
              for (var k = 0; k < e.sets.length; k++)
                _SetLine(
                  set: e.sets[k],
                  index: k,
                  workIndex: e.sets.take(k).where((s) => !s.warmup).length,
                  selected: k == sel,
                  previous:
                      e.sets[k].warmup || lastWork == null
                          ? null
                          : (() {
                            final pos = e.sets.take(k).where((s) => !s.warmup).length;
                            return pos < lastWork.length ? lastWork[pos] : null;
                          })(),
                  units: u,
                  bw: e.bw == true ? l.bodyweightShort : null,
                  onTap: () => setState(() => _sel = k),
                  onType: (tp) => n.updateSet(widget.index, k, type: tp),
                  onToggle: () => n.toggleDone(widget.index, k),
                  onDelete: () => n.removeSet(widget.index, k),
                ),
              if (e.workSets.isNotEmpty && e.workSets.every((s) => s.done)) ...[
                const SizedBox(height: 4),
                EffortChips(value: e.effort, onChanged: (v) => n.setEffort(widget.index, v)),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  TextButton.icon(onPressed: () => n.addSet(widget.index), icon: const Icon(Icons.add, size: 18), label: Text(l.addSet)),
                  TextButton.icon(
                    onPressed: () => n.addDropSet(widget.index),
                    icon: const Icon(Icons.trending_down_rounded, size: 18),
                    label: Text(l.dropSet),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ── Tools ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.whatshot_outlined, size: 18),
                    label: Text(l.warmupSets),
                    onPressed: () {
                      final work = e.workSets.isEmpty ? 0.0 : e.workSets.map((s) => s.weight).reduce(max);
                      final ws = warmupSets(work, bar: info?.equipment == 'barbell' ? 20 : max(0, work * 0.3));
                      n.insertWarmups(widget.index, ws);
                      setState(() => _sel = 0);
                      toast(context, l.warmupAdded(ws.length));
                    },
                  ),
                  if (info == null || const {'barbell', 'smith machine', 'trap bar', 'ez barbell'}.contains(info.equipment))
                    ActionChip(
                      avatar: const Icon(Icons.album_outlined, size: 18),
                      label: Text(l.plateCalculator),
                      onPressed: () => showPlateCalculator(context, sel == null ? 60 : e.sets[sel].weight, u),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(clock(e.restSec)),
                    onPressed: () async {
                      final s = await askNumber(context, l.restTimeSeconds, initial: e.restSec.toDouble(), suffix: 's');
                      if (s != null) n.setRest(widget.index, s.round());
                    },
                  ),
                  ActionChip(
                    avatar: Icon(e.note.isEmpty ? Icons.sticky_note_2_outlined : Icons.sticky_note_2, size: 18),
                    label: Text(e.note.isEmpty ? l.note : e.note, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onPressed: () async {
                      final v = await askText(context, l.note, initial: e.note);
                      if (v != null) n.setNote(widget.index, v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        if (sel != null)
          _SetEditor(index: widget.index, set: sel, units: u, increment: loadIncrement(info, weight: e.sets[sel].weight, bodyweight: e.bw)),
        if (sel == null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  icon: Icon(w.nextOpen() == null ? Icons.flag_rounded : Icons.arrow_forward_rounded),
                  label: Text(w.nextOpen() == null ? l.workoutComplete : l.nextExercise),
                  onPressed: () {
                    final next = w.nextOpen(widget.index + 1);
                    if (next == null) {
                      Navigator.pop(context);
                    } else {
                      n.setFocus(next);
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.45),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, color: Colors.white, size: 22)),
    ),
  );
}

/// True when the open work sets already carry the prescribed load.
bool _matches(GymExercise e, Prescription p) {
  var wi = 0;
  for (final s in e.sets) {
    if (s.warmup || s.type == SetType.drop) continue;
    final reps = p.repsForSet(wi++);
    if (!s.done && ((s.weight - p.weight).abs() > 0.01 || s.reps != reps)) return false;
  }
  return true;
}

class _SetLine extends StatelessWidget {
  const _SetLine({
    required this.set,
    required this.index,
    required this.workIndex,
    required this.selected,
    required this.previous,
    required this.units,
    required this.onTap,
    required this.onType,
    required this.onToggle,
    required this.onDelete,
    this.bw,
  });
  final GymSet set;
  final int index, workIndex;
  final bool selected;
  final GymSet? previous;
  final Units units;
  final String? bw; // short bodyweight label in bodyweight mode
  final VoidCallback onTap, onToggle, onDelete;
  final ValueChanged<SetType> onType;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('setline-$index-${set.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => onDelete(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: set.done ? AppColors.success.withValues(alpha: 0.10) : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.gym : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                SetTypeBadge(set: set, index: set.warmup ? index : workIndex, onChanged: onType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setLabel(set, units, bw: bw) + (set.rpe != null ? '  ·  RPE ${Units.num(set.rpe!)}' : ''),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: set.done ? scheme.onSurface : (selected ? scheme.onSurface : scheme.onSurfaceVariant),
                        ),
                      ),
                      if (previous != null)
                        Text('${l.lastTime}: ${setLabel(previous!, units, bw: bw)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggle,
                  style: IconButton.styleFrom(
                    backgroundColor: set.done ? AppColors.success : scheme.surfaceContainerHighest,
                    foregroundColor: set.done ? Colors.black : scheme.outline,
                  ),
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom panel with large steppers for the selected set.
class _SetEditor extends ConsumerWidget {
  const _SetEditor({required this.index, required this.set, required this.units, required this.increment});
  final int index, set;
  final Units units;
  final double increment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = ref.watch(activeGymProvider)!;
    final n = ref.read(activeGymProvider.notifier);
    final e = w.exercises[index];
    if (set >= e.sets.length) return const SizedBox.shrink();
    final s = e.sets[set];
    final step = units.imperial ? units.weightIn(5) : (increment <= 0 ? 2.5 : (increment > 2.5 ? 2.5 : increment));
    final workPos = e.sets.take(set).where((x) => !x.warmup).length;
    final bw = e.bw == true;
    // Bodyweight mode: the weight is added load, negative = assistance (machine / band).
    final minW = bw ? -max(40.0, e.bodyKg * 0.8) : 0.0;
    String fmt(double kg) => '${bw && kg > 0 ? '+' : ''}${Units.num(units.weightOut(kg), 2)}';

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Tooltip(
                    message: l.bodyweightHint,
                    child: FilterChip(
                      avatar: Icon(Icons.accessibility_new_rounded, size: 18, color: bw ? null : Theme.of(context).colorScheme.outline),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      label: Text(l.bodyweight),
                      selected: bw,
                      onSelected: (on) {
                        HapticFeedback.selectionClick();
                        n.setBodyweight(index, on);
                      },
                    ),
                  ),
                  const Spacer(),
                  if (bw && e.bodyKg > 0)
                    Text('≈ ${units.weight(e.bodyKg + s.weight, digits: 0)} ${l.loadTotal}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Stepper(
                      label: '${bw ? l.addedWeight : l.weight} (${units.weightUnit})',
                      value: fmt(s.weight),
                      onMinus: () => n.updateSet(index, set, weight: max(minW, s.weight - step)),
                      onPlus: () => n.updateSet(index, set, weight: s.weight + step),
                      onEdit: () async {
                        final v = await askNumber(
                          context,
                          bw ? l.addedWeight : l.weight,
                          initial: units.weightOut(s.weight),
                          suffix: units.weightUnit,
                          signed: bw,
                        );
                        if (v != null) n.updateSet(index, set, weight: max(minW, units.weightIn(v)));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stepper(
                      label: l.reps,
                      value: '${s.reps}',
                      onMinus: () => n.updateSet(index, set, reps: max(0, s.reps - 1)),
                      onPlus: () => n.updateSet(index, set, reps: s.reps + 1),
                      onEdit: () async {
                        final v = await askNumber(context, l.reps, initial: s.reps.toDouble());
                        if (v != null) n.updateSet(index, set, reps: v.round());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Tooltip(message: l.rpeHint, child: Text('RPE', style: Theme.of(context).textTheme.labelLarge)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final r in const [6.0, 7.0, 8.0, 9.0, 10.0])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(Units.num(r)),
                                visualDensity: VisualDensity.compact,
                                selected: s.rpe == r,
                                onSelected: (v) => n.updateSet(index, set, rpe: v ? r : null, clearRpe: !v),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: s.done ? Theme.of(context).colorScheme.surfaceContainerHighest : AppColors.gym,
                    foregroundColor: s.done ? null : Colors.white,
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  icon: Icon(s.done ? Icons.undo_rounded : Icons.check_rounded),
                  label: Text(
                    s.done
                        ? l.undo
                        : s.warmup
                        ? '${l.setTypeWarmup} ✓'
                        : l.completeSet(workPos + 1),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    n.toggleDone(index, set);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus, required this.onEdit});
  final String label, value;
  final VoidCallback onMinus, onPlus, onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData i, VoidCallback f) => IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        f();
      },
      style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHighest, minimumSize: const Size(44, 44)),
      icon: Icon(i),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Row(
            children: [
              btn(Icons.remove_rounded, onMinus),
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
              ),
              btn(Icons.add_rounded, onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Rest overlay ─────────────────────────────

class _RestOverlay extends ConsumerWidget {
  const _RestOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = ref.watch(activeGymProvider);
    if (w?.restEnd == null) return const SizedBox.shrink();
    final n = ref.read(activeGymProvider.notifier);
    final u = ref.watch(profileOrDefaultProvider).units;
    final next = w!.exercises[w.focus];
    final nextSetIdx = next.sets.indexWhere((s) => !s.done);
    final nextSet = nextSetIdx < 0 ? null : next.sets[nextSetIdx];
    // Optional effort rating of the exercise that was just finished.
    final rated = w.effortFor == null ? -1 : w.exercises.indexWhere((x) => identical(x, w.effortFor));

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.97),
      child: SafeArea(
        child: StreamBuilder(
          stream: Stream.periodic(const Duration(milliseconds: 200)),
          builder: (context, _) {
            final left = w.restEnd!.difference(DateTime.now()).inMilliseconds / 1000;
            final progress = w.restTotal <= 0 ? 0.0 : (left / w.restTotal).clamp(0.0, 1.0);
            return Column(
              children: [
                const SizedBox(height: 24),
                Text(w.restIsTransition ? l.supersetSwitch : l.rest, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    w.restIsTransition ? l.supersetSwitchHint : l.restHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          color: AppColors.gym,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        clock(left.ceil().clamp(0, 9999)),
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.tonal(onPressed: () => n.adjustRest(-15), child: const Text('− 15 s')),
                    const SizedBox(width: 16),
                    FilledButton.tonal(onPressed: () => n.adjustRest(15), child: const Text('+ 15 s')),
                  ],
                ),
                const Spacer(),
                if (rated >= 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EffortChips(
                      center: true,
                      title: l.effortQuestionFor(capitalize(w.exercises[rated].name)),
                      value: w.exercises[rated].effort,
                      onChanged: (v) => n.setEffort(rated, v),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (nextSet != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        ExerciseMedia(exId: next.exId, animated: false, size: 56, radius: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.upNext, style: const TextStyle(fontSize: 12, color: AppColors.gym, fontWeight: FontWeight.w700)),
                              Text(
                                capitalize(next.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${l.setXofY(nextSetIdx + 1, next.sets.length)} · ${setLabelOf(l, next, nextSet, u)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: n.skipRest,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text(l.skipRest, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────────── Plate calculator ─────────────────────────────

Future<void> showPlateCalculator(BuildContext context, double initialKg, Units u) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlateCalc(initial: initialKg <= 0 ? 60 : initialKg, units: u),
  );
}

class _PlateCalc extends StatefulWidget {
  const _PlateCalc({required this.initial, required this.units});
  final double initial;
  final Units units;
  @override
  State<_PlateCalc> createState() => _PlateCalcState();
}

class _PlateCalcState extends State<_PlateCalc> {
  late double _kg = widget.initial;
  double _bar = 20;

  static final _colors = <double, Color>{
    25.0: Color(0xFFE53935),
    20.0: Color(0xFF1E88E5),
    15.0: Color(0xFFFDD835),
    10.0: Color(0xFF43A047),
    5.0: Color(0xFFECEFF1),
    2.5: Color(0xFF9E9E9E),
    1.25: Color(0xFF616161),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (plates, rest) = platesPerSide(_kg, bar: _bar);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.plateCalcTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(onPressed: () => setState(() => _kg = max(_bar, _kg - 2.5)), icon: const Icon(Icons.remove)),
              Expanded(
                child: Center(child: Text('${Units.num(_kg, 2)} kg', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700))),
              ),
              IconButton.filledTonal(onPressed: () => setState(() => _kg += 2.5), icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${l.barWeight}: '),
              for (final b in const [20.0, 15.0, 10.0])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text('${Units.num(b)} kg'), selected: _bar == b, onSelected: (_) => setState(() => _bar = b)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Visual barbell (one side)
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Container(width: 60, height: 14, color: Colors.grey.shade500),
                Container(width: 10, height: 40, color: Colors.grey.shade400),
                for (final p in plates)
                  Container(
                    width: 14 + p * 0.5,
                    height: 40 + p * 3.2,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(color: _colors[p] ?? Colors.grey, borderRadius: BorderRadius.circular(3)),
                  ),
                Expanded(child: Container(height: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            plates.isEmpty ? '–' : '${plates.map((p) => Units.num(p, 2)).join(' + ')} kg ${l.perSide}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (rest > 0.01) ...[
            const SizedBox(height: 6),
            Text(l.notLoadable('${Units.num(rest, 2)} kg'), style: const TextStyle(color: AppColors.warning)),
          ],
        ],
      ),
    );
  }
}
