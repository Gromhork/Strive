import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/exercise_measure.dart' show formatHold, holdPerSide;
import '../../data/exercise_names_de.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/exercise_class.dart' show offersBodyweightMode;
import '../../services/active_workout.dart';
import '../../services/insights.dart';
import '../../services/load_prescription.dart' show LoadPrescriber;
import '../../data/exercise_db.dart' show Exercise;
import '../../widgets/common.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/effort_chips.dart';
import '../../widgets/exercise_media.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../widgets/prescription.dart';
import '../train/exercise_picker.dart';
import 'exercise_focus_page.dart';
import 'music.dart';
import '../../widgets/superset_group.dart';
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
    // "Finish workout? 11 of 15 sets still open." – only worth a question when sets are open.
    final open = w.totalSets - w.doneSets;
    if (open > 0) {
      final ok = await confirm(context, l.finishWorkout, body: l.finishOpenSets(open, w.totalSets), ok: l.finish, cancel: l.keepTraining);
      if (!ok || !mounted) return;
    }
    final total = w.plannedWorkSets; // work sets, like setsDone – at least the program's
    final session = n.finish(ref.read(repoProvider)!.newId());
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: session, plannedSets: total)));
  }

  Future<void> _addExercises() async {
    final n = ref.read(activeGymProvider.notifier);
    final history = ref.read(sessionListProvider);
    final picked = await pickExercises(context);
    if (!mounted) return;
    final prescriber = ref.read(loadPrescriberProvider);
    final phase = planPhaseOf(ref.read(planListProvider), ref.read(activeGymProvider)?.planId);
    for (final e in picked) {
      n.addExercise(exerciseFromLibrary(e, history: history, prescriber: prescriber, phase: phase));
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
    final next = w.nextOpen(w.focus);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
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
          // Two lines, and small enough that a single long word ("Ganzkörper") is not split.
          child: Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.15)),
        ),
        actions: [
          MusicButton(plan: () => gymMusicPlan(l, ref.read(activeGymProvider))),
          // The view switch lives in the menu so a long workout title keeps its room.
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'view') {
                setState(() => _table = !_table);
                ref.read(prefsProvider).setBool('gymTableView', _table);
              } else if (v == 'discard' && await confirm(context, l.discardWorkout, ok: l.discard, danger: true)) {
                n.discard();
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_table ? Icons.view_agenda_outlined : Icons.table_rows_outlined),
                      title: Text(_table ? l.viewFocus : l.viewTable),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'discard',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                      title: Text(l.discardWorkout, style: const TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
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
            ...groupedExerciseWidgets(
              w.exercises,
              bottomInset: 14,
              badgeTop: 22, // next to the card's title row
              (i) => _ExerciseCard(
                index: i,
                exercise: w.exercises[i],
                previous: ref.watch(loadPrescriberProvider).previousSets(w.exercises[i]),
                units: u,
              ),
            )
          else
            ..._exerciseList(w, u),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.add), label: Text(l.addExercise), onPressed: _addExercises),
        ],
      ),
      bottomSheet:
          _table && w.holdStart != null
              ? HoldBar(w: w)
              : _table && w.restEnd != null
              ? RestBar(w: w)
              : null,
    );
  }

  /// Exercises in order; adjacent superset members sit in one frame ([SupersetGroup]).
  /// (Supersets are adjacent runs only – a letter shared by distant exercises never pulls the
  /// exercises in between out of the list.)
  List<Widget> _exerciseList(ActiveGym w, Units u) => groupedExerciseWidgets(
    w.exercises,
    bottomInset: 10,
    // The builder gets its own index per call: the closure must not capture a loop variable
    // (it would open the last exercise for every tile).
    (k) => _ExerciseTile(w: w, index: k, units: u, onTap: () => _openFocus(k)),
  );
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
              _MiniStat(label: l.volume, value: units.volume(w.volume)),
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
    final group = w.groupOf(index);
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
                      exName(context, e.exId, e.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    if (set != null)
                      Text(
                        '${l.setXofY(setIdx + 1, e.sets.length)} · ${setLabelOf(l, e, set, units)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    // Superset: which one, the position in it and what follows without a rest.
                    if (group.length > 1) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SupersetChip(
                          key: const ValueKey('upNextSuperset'),
                          letter: e.group ?? 'A',
                          position: group.indexOf(index),
                          count: group.length,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SupersetNextLine(exercises: w.exercises, index: index),
                    ],
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
    final summary = exerciseSummary(l, e, units, range: ref.watch(loadPrescriberProvider).range(e));
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
                        exName(context, e.exId, e.name),
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
class ExerciseMenu extends ConsumerWidget {
  const ExerciseMenu({super.key, required this.index, required this.w, required this.n, this.icon});
  final int index;
  final ActiveGym w;
  final ActiveGymNotifier n;
  final Widget? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = w.exercises[index];
    final inSuperset = w.groupOf(index).length > 1;
    return PopupMenuButton<String>(
      icon: icon,
      onSelected: (v) async {
        switch (v) {
          case 'superset':
            if (!n.toggleSuperset(index) && context.mounted) toast(context, l.supersetMax);
          case 'bodyweight':
            final on = e.bw != true;
            n.setBodyweight(index, on);
          case 'timed':
            n.setTimed(index, !e.isTimed);
          case 'replace':
            final picked = await pickExercises(context, single: true);
            if (picked.isNotEmpty) n.replaceExercise(index, picked.first.id, picked.first.name);
          case 'rest':
            if (!context.mounted) return;
            final s = await askNumber(context, l.restTimeSeconds, initial: e.restSec.toDouble(), suffix: 's');
            if (s != null) n.setRest(index, s.round());
          case 'up':
            n.stepExercise(index, -1);
          case 'down':
            n.stepExercise(index, 1);
          case 'remove':
            n.removeExercise(index);
        }
      },
      itemBuilder:
          (_) => [
            if (inSuperset || index + 1 < w.exercises.length)
              PopupMenuItem(
                value: 'superset',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(inSuperset ? Icons.link_off_rounded : Icons.link_rounded),
                  title: Text(inSuperset ? l.unlinkSuperset : l.linkSuperset),
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
            // A hold's weight is always added load – no bodyweight switch for timed exercises.
            if (!e.isTimed && offersBodyweightMode(e.exId, e.name, info: ref.watch(exerciseDbProvider).value?.byId(e.exId), current: e.bw))
              CheckedPopupMenuItem(value: 'bodyweight', checked: e.bw == true, child: Text(l.bodyweight)),
            CheckedPopupMenuItem(value: 'timed', checked: e.isTimed, child: Text(l.timedMode)),
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

/// One line for an exercise's planned work: "3 × 8–12 · 60 kg", "3 × 8–12 · BW +5 kg" or – timed
/// holds – "3 × 45 s", "3 × 45 s · +10 kg" ([range] = rep range of rep exercises).
String exerciseSummary(AppLocalizations l, GymExercise e, Units units, {required (int, int) range}) {
  final work = e.workSets;
  if (work.isEmpty) return '${e.sets.length} ${l.sets}';
  final top = work.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  if (e.isTimed) {
    final secs = work.map((s) => s.sec > 0 ? s.sec : (s.targetSec ?? 0)).toList();
    final hi = secs.reduce((a, b) => a > b ? a : b), lo = secs.reduce((a, b) => a < b ? a : b);
    final time = hi <= 0 ? formatHold(e.holdRange.$1) : (lo == hi ? formatHold(hi) : '$lo–${formatHold(hi)}');
    // Side plank & co.: the time is per side ("3 × 20 s pro Seite"), like "pro Hand" of dumbbells.
    final side = holdPerSide(e.name) ? ' ${l.perSide}' : '';
    return '${work.length} × $time$side${top.abs() < 1e-6 ? '' : ' · ${holdWeight(top, units, bodyweight: e.bw == true)}'}';
  }
  final load = e.bw == true ? bodyweightLoad(l.bodyweightShort, top, units) : (top > 0 ? units.weight(top) : null);
  return '${work.length} × ${range.$1}–${range.$2}${load == null ? '' : ' · $load'}';
}

/// "60 kg × 8", "8 ×" (no weight) or, with [bw] (short bodyweight label), "BW × 8",
/// "BW +5 kg × 8" / "BW −10 kg × 8".
/// A library exercise added to a workout (running or already finished): the same number of
/// work sets as last time (else 3 × 10), weights and reps from the [prescriber].
GymExercise exerciseFromLibrary(Exercise e, {required List<Session> history, required LoadPrescriber prescriber, String? phase}) {
  final prev = lastSetsFor(history, e.id)?.where((s) => !s.warmup && s.type != SetType.drop).toList();
  final n = prev == null || prev.isEmpty ? 3 : prev.length.clamp(1, 6);
  final probe = GymExercise(exId: e.id, name: e.name, sets: const []);
  final raw = GymExercise(
    exId: e.id,
    name: e.name,
    sets: [
      for (var k = 0; k < n; k++)
        probe.isTimed
            ? GymSet(sec: prev == null || prev.isEmpty || prev[k].sec <= 0 ? probe.holdRange.$1 : prev[k].sec)
            : GymSet(reps: prev == null || prev.isEmpty ? 10 : prev[k].reps),
    ],
  );
  return prescriber.apply([raw], phase: phase).single;
}

/// Timed holds ([timed]): "45 s", "+10 kg · 45 s" – sets stored as reps before hold times
/// existed keep their reps label.
String setLabel(GymSet s, Units u, {String? bw, bool timed = false}) {
  if (timed && !s.legacyReps) return holdLoadLabel(s.weight, s.sec > 0 ? s.sec : (s.targetSec ?? 0), u, bodyweight: bw != null);
  if (bw != null) return '${bodyweightLoad(bw, s.weight, u)} × ${s.reps}';
  return s.weight > 0 ? '${u.weight(s.weight)} × ${s.reps}' : '${s.reps} ×';
}

/// [setLabel] for a set of [e] (bodyweight exercises show "BW + added load", timed holds the
/// hold time).
String setLabelOf(AppLocalizations l, GymExercise e, GymSet s, Units u) =>
    setLabel(s, u, bw: e.bw == true ? l.bodyweightShort : null, timed: e.isTimed);

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
    // Watched unconditionally (not only while no set is done): see [PlannedWorkoutPage.build].
    final prescriber = ref.watch(loadPrescriberProvider);
    final plans = ref.watch(planListProvider);
    final rx = exercise.doneSets == 0 ? prescriber.forExercise(exercise, phase: planPhaseOf(plans, w.planId)) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: allDone ? AppColors.success.withValues(alpha: 0.6) : Theme.of(context).colorScheme.outlineVariant),
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
                      exName(context, exercise.exId, exercise.name),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.gym),
                    ),
                  ),
                  ExerciseMenu(index: index, w: w, n: n),
                ],
              ),
              if (rx != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: PrescriptionHint(
                    prescription: rx,
                    units: units,
                    dense: true,
                    sets: exercise.sets.where((s) => !s.warmup && s.type != SetType.drop).length,
                    perSide: exercise.isTimed && holdPerSide(exercise.name),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4, top: 4),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text(l.setShort, style: Theme.of(context).textTheme.labelSmall)),
                    Expanded(flex: 3, child: Text(l.previous, style: Theme.of(context).textTheme.labelSmall)),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          exercise.isTimed && exercise.bw == true
                              ? '+ ${units.weightUnit}'
                              : exercise.bw == true
                              ? '${l.bodyweightShort} ± ${units.weightUnit}'
                              : units.weightUnit,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(child: Text(exercise.isTimed ? l.holdTime : l.reps, style: Theme.of(context).textTheme.labelSmall)),
                    ),
                    SizedBox(width: exercise.isTimed ? 80 : 44),
                  ],
                ),
              ),
              for (var s = 0; s < exercise.sets.length; s++)
                exercise.isTimed
                    ? _HoldSetRow(
                      key: ValueKey('hold-${exercise.exId}-$index-$s-${exercise.sets.length}'),
                      ex: index,
                      set: s,
                      exercise: exercise,
                      previous: _prevFor(exercise, s, work),
                      units: units,
                    )
                    : _SetRow(
                      key: ValueKey('${exercise.exId}-$index-$s-${exercise.sets.length}-${exercise.bw == true}'),
                      ex: index,
                      set: s,
                      data: exercise.sets[s],
                      previous: _prevFor(exercise, s, work),
                      units: units,
                      bodyweight: exercise.bw == true,
                    ),
              if (exercise.workSets.isNotEmpty && exercise.workSets.every((s) => s.done))
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EffortChips(value: exercise.effort, onChanged: (v) => n.setEffort(index, v)),
                  ),
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
  const _SetRow({
    super.key,
    required this.ex,
    required this.set,
    required this.data,
    required this.previous,
    required this.units,
    this.bodyweight = false,
  });
  final int ex, set;
  final GymSet data;
  final GymSet? previous;
  final Units units;
  final bool bodyweight;

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

  /// Keeps the fields in sync with changes made elsewhere (bodyweight toggle, a new
  /// weight carried over from an earlier set, …) without fighting the user's typing.
  @override
  void didUpdateWidget(covariant _SetRow old) {
    super.didUpdateWidget(old);
    final d = widget.data;
    final shown = parseNum(_w.text) ?? 0;
    if ((shown - widget.units.weightOut(d.weight)).abs() > 0.006) {
      _w.text = d.weight == 0 ? '' : Units.num(widget.units.weightOut(d.weight), 2);
    }
    if ((int.tryParse(_r.text) ?? 0) != d.reps) _r.text = d.reps == 0 ? '' : '${d.reps}';
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
                  p == null
                      ? '–'
                      : widget.bodyweight
                      ? setLabel(p, widget.units, bw: context.l10n.bodyweightShort)
                      : '${Units.num(widget.units.weightOut(p.weight))}×${p.reps}',
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true, signed: widget.bodyweight),
                  decoration: deco(p == null ? '0' : Units.num(widget.units.weightOut(p.weight))),
                  onChanged: (v) => n.updateSet(widget.ex, widget.set, weight: widget.units.weightIn(parseNum(v) ?? 0)),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tooltip(
                  message: d.amrap ? context.l10n.amrapHint : '',
                  child: TextField(
                    controller: _r,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // AMRAP set: "8+" – as many reps as possible, stop 1 before failure.
                    decoration: deco(p == null ? '0' : '${p.reps}').copyWith(suffixText: d.amrap ? '+' : null),
                    onChanged: (v) => n.updateSet(widget.ex, widget.set, reps: int.tryParse(v) ?? 0),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: IconButton(
                onPressed: () {
                  if (!d.done && p != null) {
                    // In bodyweight mode an empty field means "no added load" – keep it.
                    if (!widget.bodyweight && d.weight == 0 && _w.text.isEmpty) {
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

/// Table-view row of a timed hold: added weight, hold time (scroll wheels), start / stop of the
/// hold timer and the check button.
class _HoldSetRow extends ConsumerWidget {
  const _HoldSetRow({super.key, required this.ex, required this.set, required this.exercise, required this.previous, required this.units});
  final int ex, set;
  final GymExercise exercise;
  final GymSet? previous;
  final Units units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = ref.watch(activeGymProvider)!;
    final n = ref.read(activeGymProvider.notifier);
    final d = exercise.sets[set];
    final p = previous;
    final scheme = Theme.of(context).colorScheme;
    final holding = w.holding(ex, set);
    final bw = exercise.bw == true;
    return Dismissible(
      key: ValueKey('dismiss-hold-$ex-$set'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger.withValues(alpha: 0.3),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => n.removeSet(ex, set),
      child: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 32, child: SetTypeBadge(set: d, index: set, onChanged: (t) => n.updateSet(ex, set, type: t), compact: true)),
            Expanded(
              flex: 3,
              child: Text(
                p == null ? '–' : setLabel(p, units, bw: bw ? l.bodyweightShort : null, timed: true),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final v = await askNumber(
                      context,
                      bw ? l.addedWeight : l.weight,
                      initial: units.weightOut(d.weight),
                      suffix: units.weightUnit,
                      signed: bw,
                    );
                    if (v != null) n.updateSet(ex, set, weight: units.weightIn(v));
                  },
                  child: _Cell(text: d.weight == 0 ? '–' : Units.num(units.weightOut(d.weight), 2), done: d.done),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  key: ValueKey('holdTime-$ex-$set'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => pickHoldTime(context, l, d, (v) => n.updateSet(ex, set, sec: v)),
                  child:
                      holding
                          ? StreamBuilder(
                            stream: Stream.periodic(const Duration(milliseconds: 250)),
                            builder: (_, __) => _Cell(text: holdClock(w), done: false, highlight: true),
                          )
                          : _Cell(text: d.legacyReps ? '${d.reps} ×' : clock(d.sec > 0 ? d.sec : (d.targetSec ?? 0)), done: d.done),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child:
                  d.done
                      ? null
                      : IconButton(
                        key: ValueKey('holdPlay-$ex-$set'),
                        tooltip: holding ? l.holdStop : l.holdRunning,
                        padding: EdgeInsets.zero,
                        onPressed: () => holding ? n.stopHold() : n.startHold(ex, set),
                        icon: Icon(holding ? Icons.stop_rounded : Icons.play_arrow_rounded, color: AppColors.gym),
                      ),
            ),
            SizedBox(
              width: 44,
              child: IconButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  n.toggleDone(ex, set);
                },
                style: IconButton.styleFrom(
                  backgroundColor: d.done ? AppColors.success : scheme.surfaceContainerHigh,
                  foregroundColor: d.done ? Colors.black : scheme.outline,
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

class _Cell extends StatelessWidget {
  const _Cell({required this.text, required this.done, this.highlight = false});
  final String text;
  final bool done, highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            highlight
                ? AppColors.gym.withValues(alpha: 0.2)
                : done
                ? AppColors.success.withValues(alpha: 0.12)
                : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontWeight: highlight ? FontWeight.w700 : FontWeight.w500, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// Opens the scroll wheels for the hold time of set [s] (minutes + seconds).
Future<void> pickHoldTime(BuildContext context, AppLocalizations l, GymSet s, ValueChanged<int> onPicked) async {
  final pick = await showDurationPicker(
    context,
    title: l.holdTime,
    value: s.sec > 0 ? s.sec : null,
    initial: s.targetSec ?? 30,
    units: DurationUnits.ms,
    maxMinutes: 15,
    min: 1,
    max: 15 * 60,
    clearable: false,
  );
  final v = pick?.seconds;
  if (v != null && v > 0) onPicked(v);
}

/// The running hold as a clock: the lead-in ("3"), the time left of the target ("0:32"), then
/// the overtime ("+0:05").
String holdClock(ActiveGym w) {
  final lead = w.holdLeadInLeft();
  if (lead > 0) return '$lead';
  final left = w.holdTarget - w.holdElapsed();
  return left >= 0 ? clock(left) : '+${clock(-left)}';
}

/// Status of the running hold: "get into position" (lead-in), "hold" or "overtime".
String holdStatus(AppLocalizations l, ActiveGym w) {
  if (w.holdLeadInLeft() > 0) return l.holdGetReady;
  return w.holdElapsed() >= w.holdTarget ? l.holdOvertime : l.holdRunning;
}

/// Compact bar of the running hold timer (table view; the focus view shows it in its editor).
class HoldBar extends ConsumerWidget {
  const HoldBar({super.key, required this.w});
  final ActiveGym w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.read(activeGymProvider.notifier);
    return Material(
      key: const ValueKey('holdBar'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: StreamBuilder(
          stream: Stream.periodic(const Duration(milliseconds: 250)),
          builder: (context, _) {
            final elapsed = w.holdElapsed();
            final over = elapsed >= w.holdTarget;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: w.holdTarget <= 0 ? 1 : (elapsed / w.holdTarget).clamp(0.0, 1.0),
                  minHeight: 4,
                  color: over ? AppColors.success : AppColors.gym,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          holdStatus(l, w),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        holdClock(w),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                        onPressed: n.stopHold,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(l.holdStop),
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
                  // Narrow phones: the label gives way first, the buttons shrink to fit.
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l.rest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        clock(left.ceil().clamp(0, 9999)),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                        ),
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
