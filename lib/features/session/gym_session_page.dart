import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/active_workout.dart';
import '../../services/insights.dart';
import '../../services/load_prescription.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_media.dart';
import '../../widgets/prescription.dart';
import '../train/exercise_picker.dart';
import 'exercise_focus_page.dart';
import 'session_summary_page.dart';

/// Workout overview: progress, "up next" hero and the exercise list.
/// Tapping an exercise opens the focus view (one exercise per screen).
class GymSessionPage extends ConsumerStatefulWidget {
  const GymSessionPage({super.key});

  @override
  ConsumerState<GymSessionPage> createState() => _GymSessionPageState();
}

class _GymSessionPageState extends ConsumerState<GymSessionPage> {
  bool _table = false;

  @override
  void initState() {
    super.initState();
    _table = ref.read(prefsProvider).getBool('gymTableView') ?? false;
  }

  void _openFocus(int i) {
    ref.read(activeGymProvider.notifier).setFocus(i);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseFocusPage()));
  }

  Future<void> _finish(ActiveGym w) async {
    final l = context.l10n;
    final n = ref.read(activeGymProvider.notifier);
    if (w.doneSets == 0) {
      final discard = await confirm(context, l.noSetsDone, body: l.noSetsDoneBody, ok: l.discard, danger: true);
      if (discard) {
        n.discard();
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    final ok = await confirm(context, l.finishWorkout, body: l.finishWorkoutBody, ok: l.finish);
    if (!ok || !mounted) return;
    final session = n.finish(ref.read(repoProvider)!.newId());
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: session)));
  }

  Future<void> _addExercises() async {
    final n = ref.read(activeGymProvider.notifier);
    final history = ref.read(sessionListProvider);
    final picked = await pickExercises(context);
    if (!mounted) return;
    final prescriber = ref.read(loadPrescriberProvider);
    final phase = planPhaseOf(ref.read(planListProvider), ref.read(activeGymProvider)?.planId);
    for (final e in picked) {
      // Same number of work sets as last time; weights & reps come from the prescriber.
      final prev = lastSetsFor(history, e.id)?.where((s) => !s.warmup && s.type != SetType.drop).toList();
      final raw = GymExercise(
        exId: e.id,
        name: e.name,
        sets: [
          for (var k = 0; k < (prev == null || prev.isEmpty ? 3 : prev.length.clamp(1, 6)); k++)
            GymSet(reps: prev == null || prev.isEmpty ? 10 : prev[k].reps),
        ],
      );
      n.addExercise(prescriber.apply([raw], phase: phase).single);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = ref.watch(activeGymProvider);
    if (w == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noActiveWorkout)));
    }
    final n = ref.read(activeGymProvider.notifier);
    final u = ref.watch(profileOrDefaultProvider).units;
    final history = ref.watch(sessionListProvider);
    final next = w.nextOpen(w.focus);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: l.minimize,
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () async {
            final t = await askText(context, l.rename, initial: w.title);
            if (t != null && t.isNotEmpty) n.rename(t);
          },
          child: Text(w.title),
        ),
        actions: [
          IconButton(
            tooltip: _table ? l.viewFocus : l.viewTable,
            icon: Icon(_table ? Icons.view_agenda_outlined : Icons.table_rows_outlined),
            onPressed: () {
              setState(() => _table = !_table);
              ref.read(prefsProvider).setBool('gymTableView', _table);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'discard' && await confirm(context, l.discardWorkout, ok: l.discard, danger: true)) {
                n.discard();
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'discard', child: Text(l.discardWorkout))],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                backgroundColor: AppColors.success,
                foregroundColor: Colors.black,
              ),
              onPressed: () => _finish(w),
              child: Text(l.finish),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _ProgressHeader(w: w, units: u),
          const SizedBox(height: 14),
          if (!_table && next != null) ...[
            _UpNextCard(w: w, index: next, units: u, onTap: () => _openFocus(next)),
            const SizedBox(height: 18),
          ],
          if (!_table && next == null && w.exercises.isNotEmpty) ...[_AllDoneCard(onFinish: () => _finish(w)), const SizedBox(height: 18)],
          if (_table)
            for (var i = 0; i < w.exercises.length; i++)
              _ExerciseCard(index: i, exercise: w.exercises[i], previous: lastSetsFor(history, w.exercises[i].exId), units: u)
          else
            ..._exerciseList(w, u),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.add), label: Text(l.addExercise), onPressed: _addExercises),
        ],
      ),
      bottomSheet: _table && w.restEnd != null ? RestBar(w: w) : null,
    );
  }

  List<Widget> _exerciseList(ActiveGym w, Units u) {
    final out = <Widget>[];
    var i = 0;
    while (i < w.exercises.length) {
      final group = w.groupOf(i);
      if (group.length > 1 && group.first == i) {
        out.add(
          _SupersetFrame(
            letter: w.exercises[i].group!,
            children: [for (final k in group) _ExerciseTile(w: w, index: k, units: u, onTap: () => _openFocus(k))],
          ),
        );
        i = group.last + 1;
        // Non-adjacent members are rendered inside the frame; skip them later.
        continue;
      }
      if (group.length > 1 && group.first != i) {
        i++;
        continue;
      }
      // Copy the index: the closure must not capture the loop variable (it would open
      // the last exercise for every tile).
      final idx = i;
      out.add(_ExerciseTile(w: w, index: idx, units: u, onTap: () => _openFocus(idx)));
      i++;
    }
    return out;
  }
}

// ───────────────────────────── Overview widgets ─────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.w, required this.units});
  final ActiveGym w;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final progress = w.totalSets == 0 ? 0.0 : w.doneSets / w.totalSets;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [AppColors.gym.withValues(alpha: 0.22), scheme.surfaceContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder:
                      (_, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.duration, style: Theme.of(context).textTheme.labelMedium),
                          Text(
                            clock(DateTime.now().difference(w.start).inSeconds),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                ),
              ),
              _MiniStat(label: l.volume, value: '${compactNumber(units.weightOut(w.volume))} ${units.weightUnit}'),
              const SizedBox(width: 18),
              _MiniStat(label: l.sets, value: '${w.doneSets}/${w.totalSets}'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.gym,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    ],
  );
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.w, required this.index, required this.units, required this.onTap});
  final ActiveGym w;
  final int index;
  final Units units;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = w.exercises[index];
    final setIdx = e.sets.indexWhere((s) => !s.done);
    final set = setIdx < 0 ? null : e.sets[setIdx];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Hero(tag: 'ex-media-$index', child: ExerciseMedia(exId: e.exId, size: 96, radius: 18)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.upNext.toUpperCase(),
                      style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppColors.gym),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      capitalize(e.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    if (set != null)
                      Text(
                        '${l.setXofY(setIdx + 1, e.sets.length)} · ${setLabel(set, units)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.gym, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.onFinish});
  final VoidCallback onFinish;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(l.workoutComplete, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.black),
            onPressed: onFinish,
            child: Text(l.finish),
          ),
        ],
      ),
    );
  }
}

class _SupersetFrame extends StatelessWidget {
  const _SupersetFrame({required this.letter, required this.children});
  final String letter;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    const c = AppColors.brand;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 0, 0),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: c, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: c),
                const SizedBox(width: 4),
                Text(
                  '${context.l10n.superset} $letter',
                  style: const TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.w, required this.index, required this.units, required this.onTap});
  final ActiveGym w;
  final int index;
  final Units units;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = w.exercises[index];
    final n = ref.read(activeGymProvider.notifier);
    final total = e.sets.length;
    final done = e.sets.where((s) => s.done).length;
    final work = e.workSets;
    final summary =
        work.isEmpty
            ? '$total ${l.sets}'
            : '${work.length} × ${work.first.reps} · ${units.weight(work.map((s) => s.weight).reduce((a, b) => a > b ? a : b))}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 62,
                        height: 62,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          strokeWidth: 3,
                          color: e.allDone ? AppColors.success : AppColors.gym,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      ExerciseMedia(exId: e.exId, animated: false, size: 50, radius: 25, done: e.allDone),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capitalize(e.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: e.allDone ? TextDecoration.lineThrough : null,
                          decorationColor: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('$done/$total · $summary', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                ExerciseMenu(index: index, w: w, n: n),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared overflow menu for an exercise (overview + focus view).
class ExerciseMenu extends StatelessWidget {
  const ExerciseMenu({super.key, required this.index, required this.w, required this.n, this.icon});
  final int index;
  final ActiveGym w;
  final ActiveGymNotifier n;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = w.exercises[index];
    return PopupMenuButton<String>(
      icon: icon,
      onSelected: (v) async {
        switch (v) {
          case 'superset':
            n.toggleSuperset(index);
          case 'replace':
            final picked = await pickExercises(context, single: true);
            if (picked.isNotEmpty) n.replaceExercise(index, picked.first.id, picked.first.name);
          case 'rest':
            if (!context.mounted) return;
            final s = await askNumber(context, l.restTimeSeconds, initial: e.restSec.toDouble(), suffix: 's');
            if (s != null) n.setRest(index, s.round());
          case 'up':
            if (index > 0) n.moveExercise(index, index - 1);
          case 'down':
            n.moveExercise(index, index + 2);
          case 'remove':
            n.removeExercise(index);
        }
      },
      itemBuilder:
          (_) => [
            if (e.group != null || index + 1 < w.exercises.length)
              PopupMenuItem(
                value: 'superset',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(e.group != null ? Icons.link_off_rounded : Icons.link_rounded),
                  title: Text(e.group != null ? l.unlinkSuperset : l.linkSuperset),
                ),
              ),
            PopupMenuItem(
              value: 'replace',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(l.replaceExercise),
              ),
            ),
            PopupMenuItem(
              value: 'rest',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: Text('${l.rest}: ${clock(e.restSec)}'),
              ),
            ),
            PopupMenuItem(value: 'up', child: Text(l.moveUp)),
            PopupMenuItem(value: 'down', child: Text(l.moveDown)),
            PopupMenuItem(value: 'remove', child: Text(l.remove, style: const TextStyle(color: AppColors.danger))),
          ],
    );
  }
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String setLabel(GymSet s, Units u) => s.weight > 0 ? '${u.weight(s.weight)} × ${s.reps}' : '${s.reps} ×';

// ───────────────────────────── Table view (compact, power users) ─────────────────────────────

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.index, required this.exercise, required this.previous, required this.units});
  final int index;
  final GymExercise exercise;
  final List<GymSet>? previous;
  final Units units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.read(activeGymProvider.notifier);
    final w = ref.watch(activeGymProvider)!;
    final allDone = exercise.allDone;
    final work = previous?.where((s) => !s.warmup).toList();
    final rx =
        exercise.doneSets == 0
            ? ref.watch(loadPrescriberProvider).forExercise(exercise, phase: planPhaseOf(ref.watch(planListProvider), w.planId))
            : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color:
                allDone
                    ? AppColors.success.withValues(alpha: 0.6)
                    : exercise.group != null
                    ? AppColors.brand.withValues(alpha: 0.6)
                    : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
          child: Column(
            children: [
              Row(
                children: [
                  ExerciseMedia(exId: exercise.exId, animated: false, size: 36, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${exercise.group != null ? '${exercise.group} · ' : ''}${capitalize(exercise.name)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.gym),
                    ),
                  ),
                  ExerciseMenu(index: index, w: w, n: n),
                ],
              ),
              if (rx != null && (rx.source != LoadSource.bodyweight || rx.fromHistory))
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: PrescriptionHint(prescription: rx, units: units, dense: true),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4, top: 4),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text(l.setShort, style: Theme.of(context).textTheme.labelSmall)),
                    Expanded(flex: 3, child: Text(l.previous, style: Theme.of(context).textTheme.labelSmall)),
                    Expanded(flex: 3, child: Center(child: Text(units.weightUnit, style: Theme.of(context).textTheme.labelSmall))),
                    Expanded(flex: 3, child: Center(child: Text(l.reps, style: Theme.of(context).textTheme.labelSmall))),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              for (var s = 0; s < exercise.sets.length; s++)
                _SetRow(
                  key: ValueKey('${exercise.exId}-$index-$s-${exercise.sets.length}'),
                  ex: index,
                  set: s,
                  data: exercise.sets[s],
                  previous: _prevFor(exercise, s, work),
                  units: units,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: () => n.addSet(index), icon: const Icon(Icons.add, size: 18), label: Text(l.addSet)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Previous value for set [s], matched by work-set position (warm-ups are skipped).
GymSet? _prevFor(GymExercise e, int s, List<GymSet>? work) {
  if (work == null || e.sets[s].warmup) return null;
  final pos = e.sets.take(s).where((x) => !x.warmup).length;
  return pos < work.length ? work[pos] : null;
}

class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({super.key, required this.ex, required this.set, required this.data, required this.previous, required this.units});
  final int ex, set;
  final GymSet data;
  final GymSet? previous;
  final Units units;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  late final TextEditingController _w;
  late final TextEditingController _r;

  @override
  void initState() {
    super.initState();
    _w = TextEditingController(text: widget.data.weight == 0 ? '' : Units.num(widget.units.weightOut(widget.data.weight), 2));
    _r = TextEditingController(text: widget.data.reps == 0 ? '' : '${widget.data.reps}');
  }

  @override
  void dispose() {
    _w.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.read(activeGymProvider.notifier);
    final d = widget.data;
    final p = widget.previous;
    final scheme = Theme.of(context).colorScheme;
    final done = d.done;
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      fillColor: done ? AppColors.success.withValues(alpha: 0.12) : scheme.surfaceContainerHigh,
    );
    return Dismissible(
      key: ValueKey('dismiss-${widget.ex}-${widget.set}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger.withValues(alpha: 0.3),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => n.removeSet(widget.ex, widget.set),
      child: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: SetTypeBadge(set: d, index: widget.set, onChanged: (t) => n.updateSet(widget.ex, widget.set, type: t), compact: true),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap:
                    p == null
                        ? null
                        : () {
                          _w.text = Units.num(widget.units.weightOut(p.weight), 2);
                          _r.text = '${p.reps}';
                          n.updateSet(widget.ex, widget.set, weight: p.weight, reps: p.reps);
                        },
                child: Text(
                  p == null ? '–' : '${Units.num(widget.units.weightOut(p.weight))}×${p.reps}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _w,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: deco(p == null ? '0' : Units.num(widget.units.weightOut(p.weight))),
                  onChanged: (v) => n.updateSet(widget.ex, widget.set, weight: widget.units.weightIn(parseNum(v) ?? 0)),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _r,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: deco(p == null ? '0' : '${p.reps}'),
                  onChanged: (v) => n.updateSet(widget.ex, widget.set, reps: int.tryParse(v) ?? 0),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: IconButton(
                onPressed: () {
                  if (!d.done && p != null) {
                    if (d.weight == 0 && _w.text.isEmpty) {
                      _w.text = Units.num(widget.units.weightOut(p.weight), 2);
                      n.updateSet(widget.ex, widget.set, weight: p.weight);
                    }
                    if (d.reps == 0 && _r.text.isEmpty) {
                      _r.text = '${p.reps}';
                      n.updateSet(widget.ex, widget.set, reps: p.reps);
                    }
                  }
                  FocusScope.of(context).unfocus();
                  n.toggleDone(widget.ex, widget.set);
                },
                style: IconButton.styleFrom(
                  backgroundColor: done ? AppColors.success : scheme.surfaceContainerHigh,
                  foregroundColor: done ? Colors.black : scheme.outline,
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Set number / type badge. Tap to choose normal, warm-up, drop set or failure.
class SetTypeBadge extends StatelessWidget {
  const SetTypeBadge({super.key, required this.set, required this.index, required this.onChanged, this.compact = false});
  final GymSet set;
  final int index;
  final ValueChanged<SetType> onChanged;
  final bool compact;

  static Color colorOf(SetType t) => switch (t) {
    SetType.warmup => AppColors.warning,
    SetType.drop => AppColors.brand,
    SetType.failure => AppColors.danger,
    SetType.normal => AppColors.gym,
  };

  static String labelOf(SetType t, int i) => switch (t) {
    SetType.warmup => 'W',
    SetType.drop => 'D',
    SetType.failure => 'F',
    SetType.normal => '${i + 1}',
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = colorOf(set.type);
    final names = {
      SetType.normal: l.setTypeNormal,
      SetType.warmup: l.setTypeWarmup,
      SetType.drop: l.setTypeDrop,
      SetType.failure: l.setTypeFailure,
    };
    return PopupMenuButton<SetType>(
      tooltip: names[set.type],
      onSelected: onChanged,
      itemBuilder:
          (_) => [
            for (final t in SetType.values)
              PopupMenuItem(
                value: t,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: colorOf(t).withValues(alpha: 0.2),
                      child: Text(labelOf(t, index), style: TextStyle(fontSize: 11, color: colorOf(t))),
                    ),
                    const SizedBox(width: 10),
                    Text(names[t]!),
                  ],
                ),
              ),
          ],
      child:
          compact
              ? Text(labelOf(set.type, index), style: TextStyle(fontWeight: FontWeight.w700, color: set.type == SetType.normal ? null : c))
              : CircleAvatar(
                radius: 15,
                backgroundColor: c.withValues(alpha: set.done ? 0.9 : 0.18),
                child: Text(
                  labelOf(set.type, index),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: set.done ? Colors.black : c),
                ),
              ),
    );
  }
}

/// Compact rest bar (table view). The focus view uses a full-screen rest overlay.
class RestBar extends ConsumerWidget {
  const RestBar({super.key, required this.w});
  final ActiveGym w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.read(activeGymProvider.notifier);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: StreamBuilder(
          stream: Stream.periodic(const Duration(milliseconds: 250)),
          builder: (context, _) {
            final left = w.restEnd!.difference(DateTime.now()).inMilliseconds / 1000;
            final progress = w.restTotal <= 0 ? 0.0 : (left / w.restTotal).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress, minHeight: 4, color: Sport.gym.color),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Text(l.rest, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Text(
                        clock(left.ceil().clamp(0, 9999)),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const Spacer(),
                      TextButton(onPressed: () => n.adjustRest(-15), child: const Text('-15')),
                      TextButton(onPressed: () => n.adjustRest(15), child: const Text('+15')),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                        onPressed: n.skipRest,
                        child: Text(l.skip),
                      ),
                    ],
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
