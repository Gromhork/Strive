import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/rpe_picker.dart';

/// Corrects a recorded workout (wrong GPS distance, forgotten stop, mistyped weight …).
/// Only the editable fields are written back; route, splits, laps and links stay.
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
  late final _duration = TextEditingController(text: clock(s.durationSec));
  late final _distance = TextEditingController(text: s.distanceM <= 0 ? '' : _distText(s.distanceM));
  late final _elevation = TextEditingController(text: s.elevationM <= 0 ? '' : s.elevationM.round().toString());
  late final _avgHr = TextEditingController(text: s.avgHr?.toString() ?? '');
  late final _maxHr = TextEditingController(text: s.maxHr?.toString() ?? '');
  late final _calories = TextEditingController(text: s.calories?.toString() ?? '');
  late final _notes = TextEditingController(text: s.notes);
  late int? _rpe = s.rpe;
  late final List<GymExercise> _exercises = s.exercises.map((e) => e.copy()).toList();

  String _distText(double m) => s.sport == Sport.swim ? m.round().toString() : Units.num(u.distOut(m), 2);

  int? _int(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  void _save() {
    final l = context.l10n;
    final sec = parseHms(_duration.text);
    if (sec == null || sec <= 0) {
      toast(context, l.invalidDuration);
      return;
    }
    final d = parseNum(_distance.text);
    final cardio = s.sport != Sport.gym;
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
      if (cardio) 'distanceM': d == null ? 0.0 : (s.sport == Sport.swim ? d : u.distIn(d)),
      if (cardio) 'elevationM': elev ?? 0.0,
    };
    if (!cardio) {
      final ex = _exercises.where((e) => e.sets.isNotEmpty).toList();
      update['exercises'] = ex.map((e) => e.toMap()).toList();
      update['volume'] = ex.fold<double>(0, (a, e) => a + e.volume);
    }
    ref.read(repoProvider)?.updateMany(sessions: {s.id: update});
    toast(context, l.sessionCorrected);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final c in [_title, _duration, _distance, _elevation, _avgHr, _maxHr, _calories, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final df = DateFormat.yMMMEd(context.localeName).add_Hm();
    final cardio = s.sport != Sport.gym;
    const num = TextInputType.numberWithOptions(decimal: true);
    Widget row(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: children[i])],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.editSession), actions: [TextButton(onPressed: _save, child: Text(l.save))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.editSessionHint, style: Theme.of(context).textTheme.bodySmall),
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
            TextField(controller: _duration, keyboardType: TextInputType.datetime, decoration: InputDecoration(labelText: l.durationHms)),
            if (cardio)
              TextField(
                controller: _distance,
                keyboardType: num,
                decoration: InputDecoration(labelText: l.distance, suffixText: s.sport == Sport.swim ? 'm' : u.distUnit),
              ),
          ]),
          if (cardio)
            row([
              TextField(controller: _elevation, keyboardType: num, decoration: InputDecoration(labelText: l.elevation, suffixText: 'm')),
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
            for (final e in _exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseEditor(
                  exercise: e,
                  units: u,
                  onChanged: () => setState(() {}),
                  onBodyweight: (on) => setState(() => ref.read(loadPrescriberProvider).switchBodyweight(e, on)),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}

/// Weight × reps of every set of one exercise; sets can be removed or added. In
/// bodyweight mode the weight is the added load (negative = assistance).
class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({required this.exercise, required this.units, required this.onChanged, required this.onBodyweight});
  final GymExercise exercise;
  final Units units;
  final VoidCallback onChanged;
  final ValueChanged<bool> onBodyweight;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = exercise;
    final bw = e.bw == true;
    return SectionCard(
      title: e.name,
      trailing: FilterChip(
        key: const ValueKey('edit-bw'),
        avatar: const Icon(Icons.accessibility_new_rounded, size: 16),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        label: Text(l.bodyweightShort),
        tooltip: l.bodyweightHint,
        selected: bw,
        onSelected: onBodyweight,
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
                        labelText: bw ? l.addedWeight : l.weight,
                        suffixText: bw ? '${l.bodyweightShort} ± ${units.weightUnit}' : units.weightUnit,
                      ),
                      onChanged: (v) => e.sets[i].weight = units.weightIn(parseNum(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: e.sets[i].reps == 0 ? '' : '${e.sets[i].reps}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(isDense: true, labelText: l.reps),
                      onChanged: (v) => e.sets[i].reps = int.tryParse(v.trim()) ?? 0,
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
                e.sets.add(GymSet(weight: last?.weight ?? 0, reps: last?.reps ?? 0, done: true));
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}
