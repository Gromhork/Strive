import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../shell/health_sync.dart';
import '../../widgets/common.dart';
import '../../widgets/segments.dart';

/// Log a past activity (e.g. a treadmill run or a swim without the phone).
class ManualEntryPage extends ConsumerStatefulWidget {
  const ManualEntryPage({super.key, this.sport});
  final Sport? sport;

  @override
  ConsumerState<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends ConsumerState<ManualEntryPage> {
  late Sport _sport = widget.sport ?? ref.read(sportFilterProvider) ?? Sport.run;
  DateTime _start = DateTime.now().subtract(const Duration(hours: 1));
  int _minutes = 45;
  final _title = TextEditingController();
  final _distance = TextEditingController();
  final _volume = TextEditingController();
  final _notes = TextEditingController();
  double _rpe = 6;

  void _save() {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final u = ref.read(profileOrDefaultProvider).units;
    final d = parseNum(_distance.text);
    final vol = parseNum(_volume.text);
    final s = Session(
      id: repo.newId(),
      sport: _sport,
      title: _title.text.trim().isEmpty ? _sport.label(l) : _title.text.trim(),
      start: _start,
      durationSec: _minutes * 60,
      rpe: _rpe.round(),
      notes: _notes.text.trim(),
      distanceM: d == null ? 0 : (_sport == Sport.swim ? d : u.distIn(d)),
      // Manual gym entries store the total volume as one summary "exercise".
      exercises:
          _sport == Sport.gym && vol != null && vol > 0
              ? [
                GymExercise(exId: 'manual', name: l.totalVolume, sets: [GymSet(weight: u.weightIn(vol), reps: 1, done: true)]),
              ]
              : const [],
      indoor: true,
    );
    repo.saveSession(s);
    ref.read(healthServiceProvider).writeSession(s);
    final plan = ref.read(planListProvider).where((p) => sameDay(p.date, _start) && p.sport == _sport && p.status == 'planned').firstOrNull;
    if (plan != null) repo.updatePlan(plan.id, {'status': 'done', 'sessionId': s.id});
    toast(context, l.saved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final df = DateFormat.yMMMEd(context.localeName).add_Hm();
    return Scaffold(
      appBar: AppBar(title: Text(l.logManually)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Segments<Sport>(
            segments: [for (final s in Sport.values) Seg(s, icon: s.icon)],
            value: _sport,
            onChanged: (v) => setState(() => _sport = v),
          ),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: InputDecoration(labelText: l.title, hintText: _sport.label(l))),
          const SizedBox(height: 12),
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
          LabeledSlider(
            label: l.duration,
            value: _minutes.toDouble(),
            min: 5,
            max: 360,
            divisions: 71,
            format: (v) => humanDuration(v.round() * 60),
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
          if (_sport != Sport.gym)
            TextField(
              controller: _distance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.distance, suffixText: _sport == Sport.swim ? 'm' : u.distUnit),
            )
          else
            TextField(
              controller: _volume,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.totalVolume, suffixText: u.weightUnit),
            ),
          const SizedBox(height: 16),
          LabeledSlider(
            label: l.howHard,
            value: _rpe,
            min: 1,
            max: 10,
            divisions: 9,
            format: (v) => 'RPE ${v.round()}',
            onChanged: (v) => setState(() => _rpe = v),
          ),
          TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(hintText: l.notesHint)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
