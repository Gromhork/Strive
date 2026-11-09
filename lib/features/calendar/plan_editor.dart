import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/coach_service.dart';
import '../../services/plan_generator.dart';
import '../../widgets/common.dart';
import '../session/start_helpers.dart';
import '../session/step_editor.dart';
import '../../services/zones.dart';
import '../../widgets/segments.dart';
import '../../core/theme.dart';
import '../../data/default_programs.dart';
import '../onboarding/onboarding_page.dart';
import '../train/gym_exercise_editor.dart';

/// Add or edit a planned workout (full-screen editor with phases for endurance).
Future<void> showPlanEditor(BuildContext context, WidgetRef ref, {PlannedWorkout? existing, DateTime? date}) {
  return Navigator.push(
    context,
    MaterialPageRoute(fullscreenDialog: existing == null, builder: (_) => _PlanEditor(existing: existing, date: date ?? DateTime.now())),
  );
}

class _PlanEditor extends ConsumerStatefulWidget {
  const _PlanEditor({this.existing, required this.date});
  final PlannedWorkout? existing;
  final DateTime date;

  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  late Sport _sport = widget.existing?.sport ?? ref.read(sportFilterProvider) ?? Sport.gym;
  late DateTime _date = widget.existing?.date ?? dayOnly(widget.date);
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _km = TextEditingController(text: widget.existing?.distanceKm == null ? '' : Units.num(widget.existing!.distanceKm!));
  late int _min = widget.existing?.durationMin ?? 45;
  late String _intensity = widget.existing?.intensity ?? 'easy';
  late String? _templateId = widget.existing?.templateId;
  late List<WorkoutStep> _steps = [...?widget.existing?.steps];
  late bool _isKey = widget.existing?.isKey ?? false;
  // Gym: exercises of this workout. `_customEx` = adjusted for this day only.
  late List<GymExercise> _gymEx = _initialGymExercises();
  late bool _customEx = widget.existing?.exercises.isNotEmpty ?? false;

  List<GymExercise> _initialGymExercises() {
    final ex = widget.existing;
    if (ex == null || ex.sport != Sport.gym) return [];
    if (ex.exercises.isNotEmpty) return [for (final e in ex.exercises) e.copy(resetDone: true)];
    final t = ref.read(templateListProvider).where((t) => t.id == ex.templateId).firstOrNull;
    return [for (final e in t?.exercises ?? const <GymExercise>[]) e.copy(resetDone: true)];
  }
  int _editorGen = 0; // forces a fresh StepEditor when steps are replaced from outside

  bool get _structured => _sport != Sport.gym && _steps.isNotEmpty;

  /// Duration / distance estimate of the structured workout.
  (int, double?) _estimate(UserProfile p) {
    var sec = 0;
    var m = 0.0;
    final pz = PaceZones(Vdot.of(p.athlete) ?? Vdot.defaultFor(p.level));
    for (final s in _steps) {
      if (s.durationSec != null) {
        sec += s.durationSec!;
        if (_sport == Sport.run && s.zone != 'walk') m += s.durationSec! / ((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) * 2000;
        if (_sport == Sport.ride) m += s.durationSec! / 3600 * (s.zone == 'Z1' ? 20000 : 27000);
      } else if (s.distanceM != null) {
        m += s.distanceM!;
        sec +=
            _sport == Sport.swim
                ? (s.distanceM! / 100 * (s.paceMax ?? 130)).round()
                : (s.distanceM! / 1000 * ((s.paceMin ?? pz.easySlow) + (s.paceMax ?? pz.easySlow)) / 2).round();
      }
    }
    return (max(5, (sec / 60).round()), m <= 0 ? null : double.parse((m / 1000).toStringAsFixed(1)));
  }

  void _save() {
    _persist();
    Navigator.pop(context);
  }

  PlannedWorkout _persist() {
    final repo = ref.read(repoProvider)!;
    final l = context.l10n;
    final p = ref.read(profileOrDefaultProvider);
    final est = _structured ? _estimate(p) : null;
    final plan = PlannedWorkout(
      id: widget.existing?.id ?? repo.newId(),
      date: _date,
      sport: _sport,
      title: _title.text.trim().isEmpty ? _sport.label(l) : _title.text.trim(),
      description: _desc.text.trim(),
      durationMin: est?.$1 ?? (_sport == Sport.gym && _gymEx.isNotEmpty ? estimateGymMinutes(_gymEx) : _min),
      distanceKm: est != null ? est.$2 : parseNum(_km.text),
      intensity: _intensity,
      templateId: _templateId,
      status: widget.existing?.status ?? 'planned',
      sessionId: widget.existing?.sessionId,
      steps: _sport == Sport.gym ? const [] : _steps,
      phase: widget.existing?.phase,
      isKey: _isKey,
      exercises: _sport == Sport.gym && _customEx ? _gymEx : const [],
    );
    repo.savePlan(plan);
    return plan;
  }

  void _applyTemplate(WorkoutTemplate t) {
    final p = ref.read(profileOrDefaultProvider);
    setState(() {
      _templateId = t.id;
      _title.text = t.name;
      _min = t.estimatedMinutes;
      _intensity = t.intensity;
      if (t.description.isNotEmpty) _desc.text = t.description;
      if (t.targetKm != null) _km.text = Units.num(t.targetKm!);
      if (t.steps.isNotEmpty) {
        _steps = [for (final s in t.steps) withTargets(s, t.sport, p)];
        _editorGen++;
      }
      if (t.sport == Sport.gym) {
        _gymEx = [for (final e in t.exercises) e.copy(resetDone: true)];
        _customEx = false;
      }
    });
  }

  List<Widget> _gymSection() {
    final l = context.l10n;
    final template = ref.watch(templateListProvider).where((t) => t.id == _templateId).firstOrNull;
    return [
      const SizedBox(height: 20),
      Text(l.exercises, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        _customEx && template != null ? l.planExercisesCustom(template.name) : l.planExercisesHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      GymExerciseEditor(exercises: _gymEx, onChanged: () => setState(() => _customEx = true)),
      if (_customEx && template != null)
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.save_as_outlined, size: 18),
              label: Text(l.saveToProgram),
              onPressed: () {
                ref.read(repoProvider)!.saveTemplate(template.copyWith(exercises: [for (final e in _gymEx) e.copy(resetDone: true)]));
                setState(() => _customEx = false);
                toast(context, l.savedToProgram(template.name));
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(l.resetToProgram),
              onPressed: () => _applyTemplate(template),
            ),
          ],
        ),
      if (_gymEx.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${l.duration}: ~${humanDuration(estimateGymMinutes(_gymEx) * 60)}', style: Theme.of(context).textTheme.bodySmall),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final templates = ref.watch(templateListProvider).where((t) => t.sport == _sport).toList();
    final profile = ref.watch(profileOrDefaultProvider);
    final ex = widget.existing;
    final est = _structured ? _estimate(profile) : null;
    return Scaffold(
      appBar: AppBar(title: Text(ex == null ? l.planWorkout : l.editWorkout), actions: [TextButton(onPressed: _save, child: Text(l.save))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Segments<Sport>(
            segments: [for (final s in Sport.values) Seg(s, icon: s.icon, color: s.color, tooltip: s.label(l))],
            value: _sport,
            onChanged:
                (v) => setState(() {
                  if (v == _sport) return;
                  _sport = v;
                  _templateId = null;
                  _steps = [];
                  _gymEx = [];
                  _customEx = false;
                  _editorGen++;
                }),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(DateFormat.yMMMMEEEEd(context.localeName).format(_date)),
            trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          if (templates.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              value: templates.any((t) => t.id == _templateId) ? _templateId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.program, prefixIcon: const Icon(Icons.folder_copy_outlined)),
              items: [
                DropdownMenuItem(value: null, child: Text(l.none)),
                for (final t in templates) DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                final t = templates.where((t) => t.id == v).firstOrNull;
                if (t == null) {
                  setState(() {
                    _templateId = null;
                    if (!_customEx) _gymEx = [];
                  });
                } else {
                  _applyTemplate(t);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          TextField(controller: _title, decoration: InputDecoration(labelText: l.title)),
          const SizedBox(height: 12),
          TextField(controller: _desc, minLines: 1, maxLines: 4, decoration: InputDecoration(labelText: l.description)),
          if (_sport != Sport.gym) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.star_outline_rounded),
              title: Text(l.keySession),
              subtitle: Text(l.keySessionSub),
              value: _isKey,
              onChanged: (v) => setState(() => _isKey = v),
            ),
            const SizedBox(height: 4),
            Text(l.workoutPhases, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.structuredWorkoutSub, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            StepEditor(
              key: ValueKey('$_sport-$_editorGen'),
              steps: _steps,
              sport: _sport,
              profile: profile,
              onChanged: (s) => setState(() => _steps = s),
            ),
            if (est != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${l.duration}: ~${humanDuration(est.$1 * 60)}${est.$2 == null ? '' : ' · ${Units.num(est.$2!)} km'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          if (_sport == Sport.gym) ..._gymSection(),
          if (!_structured && !(_sport == Sport.gym && _gymEx.isNotEmpty)) ...[
            const SizedBox(height: 8),
            LabeledSlider(
              label: l.duration,
              value: _min.toDouble(),
              min: 10,
              max: 300,
              divisions: 58,
              format: (v) => humanDuration(v.round() * 60),
              onChanged: (v) => setState(() => _min = v.round()),
            ),
            if (_sport != Sport.gym)
              TextField(
                controller: _km,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.targetDistance, suffixText: 'km'),
              ),
          ],
          if (_sport != Sport.gym) ...[
            const SizedBox(height: 16),
            Text(l.intensity, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in intensities)
                  ChoiceChip(
                    label: Text(intensityLabel(l, i)),
                    selected: _intensity == i,
                    onSelected: (_) => setState(() => _intensity = i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (ex != null && !ex.isDone)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _sport.color, foregroundColor: Colors.black),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.start),
              onPressed: () async {
                final route = ModalRoute.of(context);
                await startPlanned(context, ref, _persist());
                // The session runs on top now – drop the editor underneath it.
                if (route != null && route.isActive && !route.isCurrent && context.mounted) Navigator.removeRoute(context, route);
              },
            ),
          if (ex != null && ex.status == 'planned') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(repoProvider)!.updatePlan(ex.id, {'status': 'skipped'});
                Navigator.pop(context);
              },
              child: Text(l.markSkipped),
            ),
          ],
          if (ex != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.delete),
              onPressed: () async {
                if (!await confirm(context, l.delete, body: ex.title, ok: l.delete, danger: true)) return;
                ref.read(repoProvider)!.deletePlan(ex.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

/// Generate a multi-week plan (local rules or Gemini).
Future<void> showPlanGenerator(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PlanGenerator());
}

class _PlanGenerator extends ConsumerStatefulWidget {
  const _PlanGenerator();
  @override
  ConsumerState<_PlanGenerator> createState() => _PlanGeneratorState();
}

class _PlanGeneratorState extends ConsumerState<_PlanGenerator> {
  late int _weeks = ref.read(profileOrDefaultProvider).athlete.planWeeks.clamp(1, 24);
  bool _ai = false;
  bool _replace = true;
  bool _busy = false;
  final _wish = TextEditingController();

  Future<void> _run() async {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final profile = ref.read(profileOrDefaultProvider);
    final templates = ref.read(templateListProvider);
    final start = dayOnly(DateTime.now());
    setState(() => _busy = true);
    try {
      List<PlannedWorkout> plan;
      if (_ai) {
        final coach = CoachService(
          profile: profile,
          sessions: ref.read(sessionListProvider),
          plans: ref.read(planListProvider),
          lang: Localizations.localeOf(context).languageCode,
        );
        final items = await coach.generatePlan(weeks: _weeks, start: start, wish: _wish.text.trim());
        plan = [
          for (final m in items)
            PlannedWorkout(
              id: repo.newId(),
              date: start.add(Duration(days: (m['dayOffset'] as num?)?.toInt() ?? 0)),
              sport: SportX.parse(m['sport']),
              title: m['title'] ?? '',
              description: m['description'] ?? '',
              durationMin: (m['durationMin'] as num?)?.toInt() ?? 45,
              distanceKm: ((m['distanceKm'] as num?)?.toDouble() ?? 0) > 0 ? (m['distanceKm'] as num).toDouble() : null,
              intensity: m['intensity'] ?? 'easy',
              templateId: templates.where((t) => t.name == m['title']).firstOrNull?.id,
            ),
        ];
      } else {
        // Make sure the programs of the chosen split exist (built-ins added on demand).
        final de = l.localeName.startsWith('de');
        final added = missingBuiltins(templates, repo.newId, de: de, only: PlanGenerator.gymKeysFor(profile).toSet());
        if (added.isNotEmpty) repo.saveTemplates(added);
        plan = PlanGenerator(l, profile, [...templates, ...added], repo.newId).generate(start: start, weeks: _weeks);
      }
      if (_replace) repo.deletePlansFrom(ref.read(planListProvider), start);
      repo.savePlans(plan);
      if (mounted) {
        Navigator.pop(context);
        toast(context, l.planCreated(plan.length));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, '${l.aiUnavailable} ($e)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.generatePlan, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(l.generatePlanSub(p.focus.label(l), p.weeklyTarget), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.tune_rounded, color: AppColors.brand),
                  title: Text(l.editPlanSettings, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l.editPlanSettingsSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan)));
                  },
                ),
              ),
              const SizedBox(height: 16),
              LabeledSlider(
                label: l.weeks,
                value: _weeks.toDouble(),
                min: 1,
                max: 24,
                divisions: 23,
                onChanged: (v) => setState(() => _weeks = v.round()),
              ),
              Segments<bool>(
                segments: [Seg(false, label: l.planLocal, icon: Icons.rule), Seg(true, label: l.planAi, icon: Icons.auto_awesome)],
                value: _ai,
                onChanged: (v) => setState(() => _ai = v),
              ),
              const SizedBox(height: 8),
              Text(_ai ? l.planAiDesc : l.planLocalDesc, style: Theme.of(context).textTheme.bodySmall),
              if (_ai) ...[
                const SizedBox(height: 12),
                TextField(controller: _wish, maxLines: 2, decoration: InputDecoration(hintText: l.planWishHint)),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _replace,
                onChanged: (v) => setState(() => _replace = v),
                title: Text(l.replaceExisting),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _run,
                icon:
                    _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high_rounded),
                label: Text(l.generate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
