import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../data/exercise_names_de.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/discard_guard.dart';
import '../../widgets/duration_picker.dart';
import '../../services/insights.dart' show xpForSession;
import '../../services/session_checks.dart';
import 'session_check_hint.dart';
import '../../widgets/rpe_picker.dart';
import '../session/gym_session_page.dart' show exerciseFromLibrary;
import '../train/exercise_picker.dart';

/// Corrects a recorded workout (wrong GPS distance, forgotten stop, mistyped weight …).
/// Only the editable fields are written back; route, splits and links stay. Gym: sets can be
/// edited, added and removed, exercises added (library picker), removed (with undo) and
/// reordered; volume and set counts are recomputed on save, records follow from the sessions.
/// Swim: laps × pool length give the distance.
class EditSessionPage extends ConsumerStatefulWidget {
  const EditSessionPage({super.key, required this.session});
  final Session session;

  @override
  ConsumerState<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends ConsumerState<EditSessionPage> {
  Session get s => widget.session;
  late final Units u = ref.read(profileOrDefaultProvider).units;
  late DateTime _start = s.start;
  late final _title = TextEditingController(text: s.title);
  late int _durationSec = s.durationSec;
  late final _distance = TextEditingController(text: s.distanceM <= 0 ? '' : _distText(s.distanceM));
  late final _elevation = TextEditingController(text: s.elevationM <= 0 ? '' : s.elevationM.round().toString());
  late final _laps = TextEditingController(text: s.laps <= 0 ? '' : '${s.laps}');
  late final _pool = TextEditingController(text: '${s.poolLengthM}');
  late final _avgHr = TextEditingController(text: s.avgHr?.toString() ?? '');
  late final _maxHr = TextEditingController(text: s.maxHr?.toString() ?? '');
  late final _calories = TextEditingController(text: s.calories?.toString() ?? '');
  late final _notes = TextEditingController(text: s.notes);
  late int? _rpe = s.rpe;
  late final List<GymExercise> _exercises = s.exercises.map((e) => e.copy()).toList();

  List<TextEditingController> get _controllers => [_title, _distance, _elevation, _laps, _pool, _avgHr, _maxHr, _calories, _notes];

  /// Editable values (for the unsaved-changes prompt on back).
  String _snapshot() => jsonEncode([_start.millisecondsSinceEpoch, for (final c in _controllers) c.text, _rpe, _performance()]);

  /// The performance data of an endurance session (what a session "taken over from the plan" took
  /// from it): changing it makes the session the athlete's own numbers. Gym exercises are judged
  /// one by one ([_fromPlanKeys]).
  String _performance() => jsonEncode([
    _durationSec,
    _distance.text,
    _laps.text,
    _pool.text,
    [for (final e in _exercises) e.toMap()],
  ]);
  late final String _initial;
  late final String _initialPerformance;

  /// Gym: the exercises taken over from the plan ([Session.exerciseFromPlan]) with their sets as
  /// loaded – one whose sets, weights, reps or mode the athlete changes becomes measured; the
  /// others (and a changed duration, title, …) keep the mark, so the plan's prescribed weights
  /// never turn into records.
  late final Map<GymExercise, String> _fromPlanKeys = {
    for (var i = 0; i < _exercises.length; i++)
      if (s.exerciseFromPlan(s.exercises[i])) _exercises[i]: _setsKey(_exercises[i]),
  };

  static String _setsKey(GymExercise e) => jsonEncode([e.bw, e.bodyKg, for (final x in e.sets) x.toMap()]);

  @override
  void initState() {
    super.initState();
    _initial = _snapshot();
    _initialPerformance = _performance();
    _fromPlanKeys; // the sets as loaded, before any edit
  }

  String _distText(double m) => s.sport == Sport.swim ? m.round().toString() : Units.num(u.distOut(m), 2);

  int? _int(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  /// Swim: laps or pool length changed → distance = laps × pool length.
  void _lapsChanged() {
    final laps = _int(_laps), pool = _int(_pool);
    if (laps != null && laps > 0 && pool != null && pool > 0) _distance.text = '${laps * pool}';
    setState(() {});
  }

  void _save() {
    final l = context.l10n;
    final sec = _durationSec;
    final d = parseNum(_distance.text);
    final cardio = s.sport != Sport.gym;
    final swim = s.sport == Sport.swim;
    final elev = parseNum(_elevation.text);
    final update = <String, dynamic>{
      'title': _title.text.trim().isEmpty ? s.sport.label(l) : _title.text.trim(),
      'start': Timestamp.fromDate(_start),
      'durationSec': sec,
      'rpe': _rpe,
      'notes': _notes.text.trim(),
      'avgHr': _int(_avgHr),
      'maxHr': _int(_maxHr),
      'calories': _int(_calories),
      if (cardio) 'distanceM': d == null ? 0.0 : (swim ? d : u.distIn(d)),
      if (cardio && !swim) 'elevationM': elev ?? 0.0,
      if (swim) 'laps': _int(_laps) ?? 0,
      if (swim && (_int(_pool) ?? 0) > 0) 'poolLengthM': _int(_pool),
      // XP as recorded (before the first correction) caps the XP from now on – see [Session.xpCap].
      'xpCap': s.xpCap ?? xpForSession(s),
    };
    if (!cardio) {
      final ex = _exercises.where((e) => e.sets.isNotEmpty).toList();
      // Edited and added exercises are the athlete's own numbers; untouched ones stay "from the plan".
      for (final e in ex) {
        e.fromPlan = _fromPlanKeys[e] == _setsKey(e);
      }
      update['exercises'] = ex.map((e) => e.toMap()).toList();
      // Volume incl. the body load of bodyweight exercises at the session's body weight (kept with
      // the session from now on, so later scale entries don't change its history).
      update['volume'] = ex.fold<double>(0, (a, e) => a + e.volumeAt(s.bodyWeightKg));
      if (s.bodyWeightKg != null) update['bwKg'] = s.bodyWeightKg;
      // The compliance compares the done sets with the planned ones: an added exercise raises the
      // reference (a fully done workout plus one exercise is no "> 150 %"), a removed one keeps it.
      final work = ex.fold<int>(0, (a, e) => a + e.workSets.length);
      if (s.plannedSets != null) update['plannedSets'] = max(s.plannedSets!, work);
      // Still the plan's workout as a whole only while every exercise is untouched and none was
      // removed or added (a changed duration doesn't matter).
      if (s.fromPlan && !(ex.length == s.exercises.length && ex.every((e) => e.fromPlan))) update['fromPlan'] = false;
    } else if (s.fromPlan && _performance() != _initialPerformance) {
      // Corrected performance data are the athlete's own numbers – no longer "from the plan".
      update['fromPlan'] = false;
    }
    ref.read(repoProvider)?.updateMany(sessions: {s.id: update});
    toast(context, l.sessionCorrected);
    Navigator.pop(context);
  }

  Future<void> _addExercises() async {
    final picked = await pickExercises(context);
    if (!mounted || picked.isEmpty) return;
    final history = ref.read(sessionListProvider).where((x) => x.id != s.id).toList();
    final prescriber = ref.read(loadPrescriberProvider);
    final phase = planPhaseOf(ref.read(planListProvider), s.planId);
    setState(() {
      for (final e in picked) {
        final ex = exerciseFromLibrary(e, history: history, prescriber: prescriber, phase: phase);
        // Logged after the fact: the sets were done (untick or delete what wasn't).
        for (final set in ex.sets) {
          set
            ..done = true
            ..amrap = false;
        }
        _exercises.add(ex);
      }
    });
  }

  void _removeExercise(int i) {
    final l = context.l10n;
    final removed = _exercises[i];
    setState(() => _exercises.removeAt(i));
    undoToast(
      ScaffoldMessenger.of(context),
      text: l.exerciseRemoved(exName(context, removed.exId, removed.name)),
      undoLabel: l.undo,
      onUndo: () {
        if (!mounted) return;
        setState(() => _exercises.insert(i.clamp(0, _exercises.length), removed));
      },
    );
  }

  void _move(int i, int by) {
    final j = i + by;
    if (j < 0 || j >= _exercises.length) return;
    setState(() => _exercises.insert(j, _exercises.removeAt(i)));
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Entered distance in metres (0 when empty).
  double _distanceM() {
    final d = parseNum(_distance.text);
    if (d == null || s.sport == Sport.gym) return 0;
    return s.sport == Sport.swim ? d : u.distIn(d);
  }

  SessionCheck get _check => SessionCheck.of(s.sport, _start, _durationSec, _distanceM());

  String _hint(AppLocalizations l) => switch (s.sport) {
    Sport.gym => l.editSessionHintGym,
    Sport.swim => l.editSessionHintSwim,
    _ => s.route.isNotEmpty || s.splits.isNotEmpty ? l.editSessionHint : l.editSessionHintCardio,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final df = DateFormat.yMMMEd(context.localeName).add_Hm();
    final cardio = s.sport != Sport.gym;
    final swim = s.sport == Sport.swim;
    const num = TextInputType.numberWithOptions(decimal: true);
    Widget row(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: children[i])],
        ],
      ),
    );
    return DiscardGuard(
      isDirty: () => _snapshot() != _initial,
      child: Scaffold(
        // A workout ending in the future is a typo in the start or the duration: fix it first.
        appBar: AppBar(
          title: Text(l.editSession),
          actions: [TextButton(key: const ValueKey('editSave'), onPressed: _check.endsInFuture ? null : _save, child: Text(l.save))],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_hint(l), key: const ValueKey('editSessionHint'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(controller: _title, decoration: InputDecoration(labelText: l.title)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(df.format(_start)),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2015), lastDate: DateTime.now());
                if (d == null || !context.mounted) return;
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
                setState(() => _start = DateTime(d.year, d.month, d.day, t?.hour ?? _start.hour, t?.minute ?? _start.minute));
              },
            ),
            row([
              // Scroll wheels instead of typed "h:mm:ss" – no invalid duration to reject on save.
              DurationField(
                key: const ValueKey('editDuration'),
                value: _durationSec,
                onChanged: (v) => setState(() => _durationSec = v ?? _durationSec),
                label: l.duration,
                maxHours: 47,
                clearable: false,
              ),
              if (cardio)
                TextField(
                  key: const ValueKey('editDistance'),
                  controller: _distance,
                  onChanged: (_) => setState(() {}),
                  keyboardType: num,
                  decoration: InputDecoration(labelText: l.distance, suffixText: swim ? 'm' : u.distUnit),
                ),
            ]),
            SessionCheckHint(check: _check, sport: s.sport, start: _start, durationSec: _durationSec, distanceM: _distanceM(), units: u),
            if (swim)
              row([
                TextField(
                  key: const ValueKey('editLaps'),
                  controller: _laps,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.laps),
                  onChanged: (_) => _lapsChanged(),
                ),
                TextField(
                  key: const ValueKey('editPool'),
                  controller: _pool,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.poolLength, suffixText: 'm'),
                  onChanged: (_) => _lapsChanged(),
                ),
              ]),
            if (cardio)
              row([
                if (!swim)
                  TextField(
                    controller: _elevation,
                    keyboardType: num,
                    decoration: InputDecoration(labelText: l.elevation, suffixText: 'm'),
                  ),
                TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.caloriesLabel, suffixText: 'kcal'),
                ),
              ]),
            row([
              TextField(
                controller: _avgHr,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.avgHrShort, suffixText: 'bpm'),
              ),
              TextField(
                controller: _maxHr,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.maxHr, suffixText: 'bpm'),
              ),
              if (!cardio)
                TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.caloriesLabel, suffixText: 'kcal'),
                ),
            ]),
            Text(l.howHardOptional, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            RpePicker(value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
            const SizedBox(height: 8),
            TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(hintText: l.notesHint)),
            if (!cardio) ...[
              const SizedBox(height: 16),
              for (var i = 0; i < _exercises.length; i++)
                Padding(
                  key: ObjectKey(_exercises[i]),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseEditor(
                    exercise: _exercises[i],
                    units: u,
                    onChanged: () => setState(() {}),
                    onBodyweight: (on) => setState(() => ref.read(loadPrescriberProvider).switchBodyweight(_exercises[i], on)),
                    onMoveUp: i > 0 ? () => _move(i, -1) : null,
                    onMoveDown: i < _exercises.length - 1 ? () => _move(i, 1) : null,
                    onRemove: () => _removeExercise(i),
                  ),
                ),
              OutlinedButton.icon(
                key: const ValueKey('editAddExercise'),
                onPressed: _addExercises,
                icon: const Icon(Icons.add),
                label: Text(l.addExercise),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l.save)),
          ],
        ),
      ),
    );
  }
}

/// Weight × reps of every set of one exercise; sets can be removed or added, the exercise
/// moved or removed (menu). In bodyweight mode the weight is the added load (negative =
/// assistance).
class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.exercise,
    required this.units,
    required this.onChanged,
    required this.onBodyweight,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });
  final GymExercise exercise;
  final Units units;
  final VoidCallback onChanged;
  final ValueChanged<bool> onBodyweight;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp, onMoveDown;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = exercise;
    final bw = e.bw == true;
    final timed = e.isTimed;
    return SectionCard(
      title: exName(context, e.exId, e.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A hold's weight is always added load – no bodyweight switch for timed exercises.
          if (e.exId != 'manual' && !timed)
            FilterChip(
              key: const ValueKey('edit-bw'),
              avatar: const Icon(Icons.accessibility_new_rounded, size: 16),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              label: Text(l.bodyweightShort),
              tooltip: l.bodyweightHint,
              selected: bw,
              onSelected: onBodyweight,
            ),
          PopupMenuButton<String>(
            key: ValueKey('editExerciseMenu-${e.exId}'),
            tooltip: l.moreActions,
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected:
                (v) => switch (v) {
                  'up' => onMoveUp?.call(),
                  'down' => onMoveDown?.call(),
                  _ => onRemove(),
                },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'up',
                    enabled: onMoveUp != null,
                    child: ListTile(leading: const Icon(Icons.arrow_upward_rounded), title: Text(l.moveUp)),
                  ),
                  PopupMenuItem(
                    value: 'down',
                    enabled: onMoveDown != null,
                    child: ListTile(leading: const Icon(Icons.arrow_downward_rounded), title: Text(l.moveDown)),
                  ),
                  PopupMenuItem(
                    key: const ValueKey('editRemoveExercise'),
                    value: 'remove',
                    child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l.removeExercise)),
                  ),
                ],
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < e.sets.length; i++)
            Padding(
              // The mode is part of the key: switching it rebuilds the fields with the
              // converted weights.
              key: ValueKey('${identityHashCode(e.sets[i])}-$bw'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('${i + 1}', style: Theme.of(context).textTheme.labelLarge)),
                  Expanded(
                    child: TextFormField(
                      initialValue: e.sets[i].weight == 0 ? '' : Units.num(units.weightOut(e.sets[i].weight)),
                      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: bw),
                      decoration: InputDecoration(
                        isDense: true,
                        // Short label so it fits next to the reps on phones ("BW ± kg").
                        labelText:
                            timed
                                ? '+ ${units.weightUnit}'
                                : bw
                                ? '${l.bodyweightShort} ± ${units.weightUnit}'
                                : l.weight,
                        hintText: bw || timed ? '0' : null,
                        suffixText: bw || timed ? null : units.weightUnit,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      onChanged: (v) {
                        e.sets[i].weight = units.weightIn(parseNum(v) ?? 0);
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        timed
                            // Hold time on scroll wheels (a set stored as reps before hold times
                            // existed shows its reps as the hint until a time is set).
                            ? DurationField(
                              key: ValueKey('edit-hold-$i'),
                              value: e.sets[i].sec > 0 ? e.sets[i].sec : null,
                              label: l.holdTime,
                              emptyText: e.sets[i].legacyReps ? '${e.sets[i].reps} ×' : null,
                              units: DurationUnits.ms,
                              maxMinutes: 15,
                              min: 1,
                              max: 15 * 60,
                              initial: e.sets[i].targetSec ?? e.holdRange.$1,
                              clearable: false,
                              onChanged: (v) {
                                if (v == null) return;
                                e.sets[i].sec = v;
                                onChanged();
                              },
                            )
                            : TextFormField(
                              initialValue: e.sets[i].reps == 0 ? '' : '${e.sets[i].reps}',
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: l.reps,
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              ),
                              onChanged: (v) {
                                e.sets[i].reps = int.tryParse(v.trim()) ?? 0;
                                onChanged();
                              },
                            ),
                  ),
                  Checkbox(
                    value: e.sets[i].done,
                    onChanged: (v) {
                      e.sets[i].done = v ?? false;
                      onChanged();
                    },
                  ),
                  IconButton(
                    tooltip: l.delete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      e.sets.removeAt(i);
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l.addSet),
              onPressed: () {
                final last = e.sets.isEmpty ? null : e.sets.last;
                e.sets.add(
                  GymSet(
                    weight: last?.weight ?? 0,
                    reps: timed ? 0 : last?.reps ?? 0,
                    sec: timed ? (last != null && last.sec > 0 ? last.sec : e.holdRange.$1) : 0,
                    done: true,
                  ),
                );
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}
