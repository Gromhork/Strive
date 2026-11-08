import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../session/start_helpers.dart';
import 'exercise_picker.dart';
import '../../widgets/segments.dart';

/// Create / edit a program (gym exercises with sets, or a cardio session target).
class TemplateEditorPage extends ConsumerStatefulWidget {
  const TemplateEditorPage({super.key, this.template, this.sport = Sport.gym});
  final WorkoutTemplate? template;
  final Sport sport;

  @override
  ConsumerState<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends ConsumerState<TemplateEditorPage> {
  late final _name = TextEditingController(text: widget.template?.name ?? '');
  late final _folder = TextEditingController(text: widget.template?.folder ?? '');
  late final _desc = TextEditingController(text: widget.template?.description ?? '');
  late final _km = TextEditingController(text: widget.template?.targetKm == null ? '' : Units.num(widget.template!.targetKm!));
  late Sport _sport = widget.template?.sport ?? widget.sport;
  late int _min = widget.template?.targetMin ?? 45;
  late String _intensity = widget.template?.intensity ?? 'easy';
  late final List<GymExercise> _ex = widget.template?.exercises.map((e) => e.copy()).toList() ?? [];

  bool get _isNew => widget.template == null;

  WorkoutTemplate _build() => WorkoutTemplate(
    id: widget.template?.id ?? ref.read(repoProvider)!.newId(),
    name: _name.text.trim().isEmpty ? _sport.label(context.l10n) : _name.text.trim(),
    sport: _sport,
    folder: _folder.text.trim(),
    exercises: _sport == Sport.gym ? _ex : const [],
    targetKm: _sport == Sport.gym ? null : parseNum(_km.text),
    targetMin: _sport == Sport.gym ? null : _min,
    intensity: _intensity,
    description: _desc.text.trim(),
  );

  void _save() {
    ref.read(repoProvider)!.saveTemplate(_build());
    Navigator.pop(context);
  }

  Future<void> _share() async {
    final l = context.l10n;
    final t = _build();
    ref.read(repoProvider)!.saveTemplate(t);
    try {
      final code = await ref.read(repoProvider)!.shareTemplate(t, ref.read(profileOrDefaultProvider).name);
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      toast(context, l.codeCopied(code));
      await SharePlus.instance.share(ShareParams(text: l.shareText(t.name, code)));
    } catch (e) {
      if (mounted) toast(context, l.offlineAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final folders = ref.watch(templateListProvider).map((t) => t.folder).where((f) => f.isNotEmpty).toSet().toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.newProgram : l.editProgram),
        actions: [
          if (!_isNew) IconButton(tooltip: l.share, icon: const Icon(Icons.share_outlined), onPressed: _share),
          if (!_isNew)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, l.deleteProgram, ok: l.delete, danger: true)) {
                  ref.read(repoProvider)!.deleteTemplate(widget.template!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (_isNew)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Segments<Sport>(
                segments: [for (final s in Sport.values) Seg(s, label: s.label(l), icon: s.icon)],
                value: _sport,
                onChanged: (v) => setState(() => _sport = v),
              ),
            ),
          TextField(controller: _name, decoration: InputDecoration(labelText: l.name)),
          const SizedBox(height: 12),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _folder.text),
            optionsBuilder: (v) => folders.where((f) => f.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => _folder.text = v,
            fieldViewBuilder:
                (context, ctrl, focus, _) => TextField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (v) => _folder.text = v,
                  decoration: InputDecoration(labelText: l.folder, prefixIcon: const Icon(Icons.folder_outlined)),
                ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: l.description)),
          const SizedBox(height: 20),
          if (_sport == Sport.gym) ..._gymEditor() else ..._cardioEditor(),
        ],
      ),
      bottomNavigationBar:
          _isNew
              ? null
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _sport.color, foregroundColor: Colors.black),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l.startWorkout),
                    onPressed: () {
                      final t = _build();
                      ref.read(repoProvider)!.saveTemplate(t);
                      Navigator.pop(context);
                      t.sport == Sport.gym
                          ? startGym(context, ref, title: t.name, template: t)
                          : showCardioStart(context, ref, t.sport, title: t.name);
                    },
                  ),
                ),
              ),
    );
  }

  List<Widget> _gymEditor() {
    final u = ref.watch(profileOrDefaultProvider).units;
    return [
      Text(context.l10n.exercises, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder:
            (a, b) => setState(() {
              final e = _ex.removeAt(a);
              _ex.insert(b > a ? b - 1 : b, e);
            }),
        children: [
          for (var i = 0; i < _ex.length; i++)
            Padding(
              key: ValueKey('${_ex[i].exId}-$i'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator)),
                          ),
                          Expanded(
                            child: Text(
                              _ex[i].name.isEmpty ? '' : _ex[i].name[0].toUpperCase() + _ex[i].name.substring(1),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gym),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _ex.removeAt(i))),
                        ],
                      ),
                      for (var s = 0; s < _ex[i].sets.length; s++)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 28, child: Text('${s + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              Expanded(
                                child: _NumField(
                                  initial: _ex[i].sets[s].weight == 0 ? '' : Units.num(u.weightOut(_ex[i].sets[s].weight), 2),
                                  suffix: u.weightUnit,
                                  onChanged: (v) => _ex[i].sets[s].weight = u.weightIn(parseNum(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NumField(
                                  initial: _ex[i].sets[s].reps == 0 ? '' : '${_ex[i].sets[s].reps}',
                                  suffix: context.l10n.reps,
                                  onChanged: (v) => _ex[i].sets[s].reps = int.tryParse(v) ?? 0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => setState(() => _ex[i].sets.removeAt(s)),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed:
                                () => setState(() {
                                  final last = _ex[i].sets.isNotEmpty ? _ex[i].sets.last : GymSet(reps: 10);
                                  _ex[i].sets.add(GymSet(weight: last.weight, reps: last.reps));
                                }),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(context.l10n.addSet),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.timer_outlined, size: 16),
                            label: Text('${context.l10n.rest} ${clock(_ex[i].restSec)}'),
                            onPressed: () async {
                              final v = await askNumber(
                                context,
                                context.l10n.restTimeSeconds,
                                initial: _ex[i].restSec.toDouble(),
                                suffix: 's',
                              );
                              if (v != null) setState(() => _ex[i].restSec = v.round());
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addExercise),
        onPressed: () async {
          final picked = await pickExercises(context);
          setState(() {
            for (final e in picked) {
              _ex.add(GymExercise(exId: e.id, name: e.name, sets: [GymSet(reps: 10), GymSet(reps: 10), GymSet(reps: 10)]));
            }
          });
        },
      ),
    ];
  }

  List<Widget> _cardioEditor() {
    final u = ref.watch(profileOrDefaultProvider).units;
    return [
      LabeledSlider(
        label: context.l10n.duration,
        value: _min.toDouble(),
        min: 10,
        max: 300,
        divisions: 58,
        format: (v) => humanDuration(v.round() * 60),
        onChanged: (v) => setState(() => _min = v.round()),
      ),
      TextField(
        controller: _km,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: context.l10n.targetDistance, suffixText: _sport == Sport.swim ? 'km' : u.distUnit),
      ),
      const SizedBox(height: 16),
      Text(context.l10n.intensity, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in intensities)
            ChoiceChip(
              label: Text(intensityLabel(context.l10n, i)),
              selected: _intensity == i,
              onSelected: (_) => setState(() => _intensity = i),
            ),
        ],
      ),
    ];
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.initial, required this.suffix, required this.onChanged});
  final String initial;
  final String suffix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      isDense: true,
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    onChanged: onChanged,
  );
}
