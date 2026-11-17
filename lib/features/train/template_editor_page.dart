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
import '../../widgets/discard_guard.dart';
import '../../widgets/segments.dart';
import '../session/start_helpers.dart';
import '../session/step_editor.dart';
import 'gym_exercise_editor.dart';
import 'program_delete_actions.dart';

/// Create / edit a program: gym exercises (sets, rep ranges, set types, supersets,
/// rest) or a structured endurance workout (phases and repeat blocks).
class TemplateEditorPage extends ConsumerStatefulWidget {
  const TemplateEditorPage({super.key, this.template, this.sport = Sport.gym, this.folder = ''});
  final WorkoutTemplate? template;
  final Sport sport;
  final String folder;

  @override
  ConsumerState<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends ConsumerState<TemplateEditorPage> {
  late final _name = TextEditingController(text: widget.template?.name ?? '');
  late final _folder = TextEditingController(text: widget.template?.folder ?? widget.folder);
  late final _desc = TextEditingController(text: widget.template?.description ?? '');
  late final _km = TextEditingController(text: widget.template?.targetKm == null ? '' : Units.num(widget.template!.targetKm!));
  late Sport _sport = widget.template?.sport ?? widget.sport;
  late int _min = widget.template?.targetMin ?? 45;
  late String _intensity = widget.template?.intensity ?? 'easy';
  late final List<GymExercise> _ex = widget.template?.exercises.map((e) => e.copy()).toList() ?? [];
  late List<WorkoutStep> _steps = [...?widget.template?.steps];
  late bool _structured = _steps.isNotEmpty || widget.template == null;
  bool _dirty = false;

  bool get _isNew => widget.template == null;

  @override
  void dispose() {
    for (final c in [_name, _folder, _desc, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  WorkoutTemplate _build() => WorkoutTemplate(
    id: widget.template?.id ?? ref.read(repoProvider)!.newId(),
    name: _name.text.trim().isEmpty ? _sport.label(context.l10n) : _name.text.trim(),
    sport: _sport,
    folder: _folder.text.trim(),
    exercises: _sport == Sport.gym ? _ex : const [],
    targetKm: _sport == Sport.gym || _structured ? null : parseNum(_km.text),
    targetMin: _sport == Sport.gym || _structured ? null : _min,
    intensity: _sport != Sport.gym && _structured ? deriveIntensity(_steps, _sport) : _intensity,
    description: _desc.text.trim(),
    steps: _sport == Sport.gym || !_structured ? const [] : _steps,
    key: widget.template?.key,
    order: widget.template?.order ?? 999,
    origKey: widget.template?.origKey,
  );

  void _save() {
    ref.read(repoProvider)!.saveTemplate(_build());
    Navigator.pop(context);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirmDiscard(context);
  }

  Future<void> _share() async {
    final l = context.l10n;
    final t = _build();
    ref.read(repoProvider)!.saveTemplate(t);
    try {
      final code = await ref.read(repoProvider)!.shareTemplate(t);
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
    // Keeps the plan loaded (no rebuilds) for the delete below, which keeps the planned workouts'
    // exercises – also when the editor is opened from a page that does not listen to the plan.
    ref.listen(plansProvider, (_, _) {});
    final folders = ref.watch(templateListProvider).map((t) => t.folder).where((f) => f.isNotEmpty).toSet().toList();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l.newProgram : l.editProgram, maxLines: 2, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(onPressed: _save, child: Text(l.save)),
            if (!_isNew)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'share') return _share();
                  // Same path as the Train tab: the plan keeps this program's workouts and the
                  // dialog names them (R7-1 / R2).
                  if (await confirmDeleteProgram(context, ref, widget.template!) && context.mounted) Navigator.pop(context);
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(value: 'share', child: ListTile(leading: const Icon(Icons.share_outlined), title: Text(l.share))),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                          title: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
                        ),
                      ),
                    ],
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (_isNew)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Segments<Sport>(
                  segments: [for (final s in Sport.values) Seg(s, icon: s.icon, color: s.color, tooltip: s.label(l))],
                  value: _sport,
                  onChanged: (v) => _touch(() => _sport = v),
                ),
              ),
            TextField(controller: _name, decoration: InputDecoration(labelText: l.name), onChanged: (_) => _dirty = true),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _folder.text),
              optionsBuilder: (v) => folders.where((f) => f.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _folder.text = v,
              fieldViewBuilder:
                  (context, ctrl, focus, _) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    onChanged: (v) {
                      _folder.text = v;
                      _dirty = true;
                    },
                    decoration: InputDecoration(labelText: l.folder, prefixIcon: const Icon(Icons.folder_outlined)),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: l.description),
              onChanged: (_) => _dirty = true,
            ),
            const SizedBox(height: 20),
            if (_sport == Sport.gym) GymExerciseEditor(exercises: _ex, onChanged: () => _touch(() {})) else ..._cardioEditor(),
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
                      onPressed: () async {
                        final t = _build();
                        ref.read(repoProvider)!.saveTemplate(t);
                        _dirty = false;
                        // Start on top of the editor, then drop the editor from the stack so
                        // "back" from the workout returns to the program list.
                        final route = ModalRoute.of(context);
                        if (t.sport == Sport.gym) {
                          await startGym(context, ref, title: t.name, template: t);
                        } else {
                          await showCardioStart(context, ref, t.sport, title: t.name, steps: t.steps);
                        }
                        if (route != null && route.isActive && !route.isCurrent && context.mounted) Navigator.removeRoute(context, route);
                      },
                    ),
                  ),
                ),
      ),
    );
  }

  // ───────────────────────────── Cardio ─────────────────────────────

  List<Widget> _cardioEditor() {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    return [
      Segments<bool>(
        segments: [
          Seg(true, label: l.structuredWorkout, icon: Icons.stacked_bar_chart_rounded),
          Seg(false, label: l.freeWorkout, icon: Icons.all_inclusive_rounded),
        ],
        value: _structured,
        onChanged: (v) => _touch(() => _structured = v),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text(_structured ? l.structuredWorkoutSub : l.freeWorkoutSub, style: Theme.of(context).textTheme.bodySmall)),
          if (_structured) ZoneInfoButton(sport: _sport, profile: ref.watch(profileOrDefaultProvider)),
        ],
      ),
      const SizedBox(height: 16),
      if (_structured)
        StepEditor(
          key: ValueKey(_sport),
          steps: _steps,
          sport: _sport,
          profile: ref.watch(profileOrDefaultProvider),
          onChanged: (s) => _touch(() => _steps = s),
        )
      else ...[
        LabeledSlider(
          label: l.duration,
          value: _min.toDouble(),
          min: 10,
          max: 300,
          divisions: 58,
          format: (v) => humanDuration(v.round() * 60),
          onChanged: (v) => _touch(() => _min = v.round()),
        ),
        TextField(
          controller: _km,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.targetDistance, suffixText: _sport == Sport.swim ? 'km' : u.distUnit),
          onChanged: (_) => _dirty = true,
        ),
      ],
      const SizedBox(height: 16),
      if (_structured)
        Text(
          '${l.intensity}: ${l.intensityAuto(intensityLabel(l, deriveIntensity(_steps, _sport)))}',
          style: Theme.of(context).textTheme.bodySmall,
        )
      else ...[
        Text(l.intensity, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in intensitiesFor(_sport))
              ChoiceChip(label: Text(intensityLabel(l, i)), selected: _intensity == i, onSelected: (_) => _touch(() => _intensity = i)),
          ],
        ),
      ],
    ];
  }
}
