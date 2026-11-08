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
import '../../widgets/exercise_media.dart';
import '../../widgets/segments.dart';
import '../session/gym_session_page.dart' show SetTypeBadge;
import '../session/start_helpers.dart';
import '../session/step_editor.dart';
import 'exercise_detail_page.dart';
import 'exercise_picker.dart';

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
    intensity: _intensity,
    description: _desc.text.trim(),
    steps: _sport == Sport.gym || !_structured ? const [] : _steps,
    key: widget.template?.key,
    order: widget.template?.order ?? 999,
  );

  void _save() {
    ref.read(repoProvider)!.saveTemplate(_build());
    Navigator.pop(context);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final l = context.l10n;
    return confirm(context, l.discardChanges, ok: l.discard, danger: true);
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
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l.newProgram : l.editProgram),
          actions: [
            TextButton(onPressed: _save, child: Text(l.save)),
            if (!_isNew)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'share') return _share();
                  if (await confirm(context, l.deleteProgram, ok: l.delete, danger: true)) {
                    ref.read(repoProvider)!.deleteTemplate(widget.template!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
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
                            : showCardioStart(context, ref, t.sport, title: t.name, steps: t.steps);
                      },
                    ),
                  ),
                ),
      ),
    );
  }

  // ───────────────────────────── Gym ─────────────────────────────

  String _nextGroup() {
    final used = _ex.map((e) => e.group).whereType<String>().toSet();
    for (final c in 'ABCDEFGHIJ'.split('')) {
      if (!used.contains(c)) return c;
    }
    return 'Z';
  }

  /// Links exercise [i] with the next one into a superset (or unlinks).
  void _toggleSuperset(int i) => _touch(() {
    final e = _ex[i];
    final n = _ex[i + 1];
    if (e.group != null && e.group == n.group) {
      // Unlink: the lower part keeps a group only if it still has ≥ 2 members.
      n.group = null;
      final rest = _ex.where((x) => x.group == e.group).length;
      if (rest < 2) e.group = null;
    } else {
      final g = e.group ?? n.group ?? _nextGroup();
      e.group = g;
      n.group = g;
    }
  });

  List<Widget> _gymEditor() {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final minutes = estimateGymMinutes(_ex);
    final sets = _ex.fold<int>(0, (a, e) => a + e.workSets.length);
    return [
      Row(
        children: [
          Expanded(child: Text(l.exercises, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (_ex.isNotEmpty) Text('${l.setsN(sets)} · ~$minutes min', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 8),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder:
            (a, b) => _touch(() {
              final e = _ex.removeAt(a);
              _ex.insert(b > a ? b - 1 : b, e);
            }),
        children: [
          for (var i = 0; i < _ex.length; i++)
            Column(
              key: ObjectKey(_ex[i]),
              children: [
                _ExerciseEditCard(
                  index: i,
                  exercise: _ex[i],
                  units: u,
                  inSuperset: _ex[i].group != null,
                  onChanged: () => _touch(() {}),
                  onRemove:
                      () => _touch(() {
                        final g = _ex[i].group;
                        _ex.removeAt(i);
                        if (g != null && _ex.where((x) => x.group == g).length < 2) {
                          for (final x in _ex.where((x) => x.group == g)) {
                            x.group = null;
                          }
                        }
                      }),
                  onReplace: () async {
                    final picked = await pickExercises(context, single: true);
                    if (picked.isEmpty) return;
                    _touch(() {
                      _ex[i].exId = picked.first.id;
                      _ex[i].name = picked.first.name;
                    });
                  },
                ),
                if (i < _ex.length - 1)
                  _SupersetLink(linked: _ex[i].group != null && _ex[i].group == _ex[i + 1].group, onTap: () => _toggleSuperset(i)),
              ],
            ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text(l.addExercise),
        onPressed: () async {
          final picked = await pickExercises(context);
          _touch(() {
            for (final e in picked) {
              _ex.add(
                GymExercise(exId: e.id, name: e.name, repMin: 8, repMax: 12, sets: [GymSet(reps: 8), GymSet(reps: 8), GymSet(reps: 8)]),
              );
            }
          });
        },
      ),
    ];
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
      Text(_structured ? l.structuredWorkoutSub : l.freeWorkoutSub, style: Theme.of(context).textTheme.bodySmall),
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
      Text(l.intensity, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in intensities)
            ChoiceChip(label: Text(intensityLabel(l, i)), selected: _intensity == i, onSelected: (_) => _touch(() => _intensity = i)),
        ],
      ),
    ];
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
    required this.inSuperset,
    required this.onChanged,
    required this.onRemove,
    required this.onReplace,
  });
  final int index;
  final GymExercise exercise;
  final Units units;
  final bool inSuperset;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = exercise;
    final u = units;
    final scheme = Theme.of(context).colorScheme;
    final name = e.name.isEmpty ? '' : e.name[0].toUpperCase() + e.name.substring(1);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: inSuperset ? Border.all(color: AppColors.brand.withValues(alpha: 0.6), width: 1.5) : null,
      ),
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
                        if (e.group != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(6)),
                            child: Text(e.group!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
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
                        _MiniChip(
                          icon: Icons.repeat_rounded,
                          text: e.repMin != null && e.repMax != null ? '${e.repMin}–${e.repMax} ${l.reps}' : l.repRange,
                          onTap: () async {
                            final r = await _askRange(context, e.repMin ?? 8, e.repMax ?? 12);
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
                          icon: Icons.timer_outlined,
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
                Expanded(child: Text(u.weightUnit, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
                const SizedBox(width: 8),
                Expanded(child: Text(l.reps, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
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
                      initial: e.sets[s].weight == 0 ? '' : Units.num(u.weightOut(e.sets[s].weight), 2),
                      hint: '–',
                      onChanged: (v) => e.sets[s].weight = u.weightIn(parseNum(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumField(
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
                final last = e.sets.isNotEmpty ? e.sets.last : GymSet(reps: e.repMin ?? 10);
                e.sets.add(GymSet(weight: last.weight, reps: last.reps));
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text, required this.onTap});
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
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted),
          ),
        ],
      ),
    ),
  );
}

class _NumField extends StatelessWidget {
  const _NumField({required this.initial, required this.onChanged, this.hint});
  final String initial;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(isDense: true, hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
    onChanged: onChanged,
  );
}
