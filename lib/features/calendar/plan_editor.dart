import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/goal_model.dart';
import '../../services/plan_service.dart';
import '../../widgets/common.dart';
import '../../widgets/discard_guard.dart';
import '../../widgets/plan_amount.dart';
import '../session/start_helpers.dart';
import '../session/step_editor.dart';
import '../../services/zones.dart';
import '../../widgets/segments.dart';
import '../../core/theme.dart';
import '../onboarding/onboarding_page.dart';
import '../goals/goal_mismatch_card.dart';
import 'feasibility_card.dart';
import 'replace_plan_dialog.dart';
import '../train/program_duplicate.dart';
import '../train/gym_exercise_editor.dart';
import '../../services/plan_exercises.dart';

/// Result of [showPlanEditor] when the workout was deleted (the page showing it closes too).
const planDeleted = 'deleted';

/// Add or edit a planned workout (full-screen editor with phases for endurance).
Future<Object?> showPlanEditor(BuildContext context, WidgetRef ref, {PlannedWorkout? existing, DateTime? date}) {
  return Navigator.push<Object?>(
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
  // The workout's program – also when found again after it was deleted ([plannedProgramOf]).
  late final String? _initialTemplateId = _programOfExisting()?.id ?? widget.existing?.templateId;
  late String? _templateId = _initialTemplateId;
  late List<WorkoutStep> _steps = [...?widget.existing?.steps];
  late bool _isKey = widget.existing?.isKey ?? false;
  // Gym: exercises of this workout. `_customEx` = adjusted for this day only.
  late List<GymExercise> _gymEx = _initialGymExercises();
  late bool _customEx = widget.existing?.exercises.isNotEmpty ?? false;

  WorkoutTemplate? _programOfExisting() {
    final ex = widget.existing;
    return ex == null ? null : plannedProgramOf(ex, ref.read(templateListProvider));
  }

  List<GymExercise> _initialGymExercises() {
    final ex = widget.existing;
    if (ex == null || ex.sport != Sport.gym) return [];
    if (ex.exercises.isNotEmpty) return [for (final e in ex.exercises) e.copy(resetDone: true)];
    final t = _programOfExisting();
    // The program with the plan's day adaptations ([PlannedWorkout.gymMods]) – what the workout shows.
    final goal = ref.read(profileOrDefaultProvider).athlete.gymGoal;
    return [for (final e in plannedGymExercises(ex, t, gymGoal: goal)) e.copy(resetDone: true)];
  }

  int _editorGen = 0; // forces a fresh StepEditor when steps are replaced from outside

  /// Everything the editor can change – compared with the initial value for the
  /// unsaved-changes prompt on back.
  String _snapshot() => jsonEncode([
    _sport.name,
    dayKey(_date),
    _title.text,
    _desc.text,
    _km.text,
    _min,
    _intensity,
    _templateId,
    [for (final s in _steps) s.toMap()],
    _isKey,
    [for (final e in _gymEx) e.toMap()],
    _customEx,
  ]);
  late String _initial; // last saved state

  @override
  void initState() {
    super.initState();
    _initial = _snapshot();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _km.dispose();
    super.dispose();
  }

  bool get _structured => _sport != Sport.gym && _steps.isNotEmpty;

  /// Duration / distance estimate of the structured workout.
  /// The same estimate every screen shows ([planAmount]).
  (int, double?) _estimate(UserProfile p) {
    final sec = estimateStepsSec(_steps, _sport, p);
    return (max(5, (sec / 60).round()), stepsKm(_steps, _sport, p));
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
      intensity: _structured && _intensity != 'race' ? deriveIntensity(_steps, _sport) : _intensity,
      templateId: _templateId,
      status: widget.existing?.status ?? 'planned',
      sessionId: widget.existing?.sessionId,
      steps: _sport == Sport.gym ? const [] : _steps,
      phase: widget.existing?.phase,
      isKey: _isKey,
      exercises: _sport == Sport.gym && _customEx ? _gymEx : const [],
      // The plan's day adaptations stay while the workout keeps following the same program; the load
      // ones ([gymLoadMods]: lighter legs, race window) also with exercises adjusted here.
      gymMods: [
        if (_sport == Sport.gym && widget.existing != null && _templateId == _initialTemplateId)
          for (final m in widget.existing!.gymMods)
            if (!_customEx || gymLoadMods.contains(m)) m,
      ],
    );
    repo.savePlan(plan);
    _initial = _snapshot();
    return plan;
  }

  void _applyTemplate(WorkoutTemplate t) {
    final p = ref.read(profileOrDefaultProvider);
    setState(() {
      _templateId = t.id;
      _title.text = t.name;
      _min = templateMinutes(t, ref.read(profileOrDefaultProvider));
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
      GymExerciseEditor(
        exercises: _gymEx,
        phase: gymLoadPhase(widget.existing),
        subtitle: template == null ? null : (_customEx ? l.planExercisesCustom(template.name) : l.planExercisesHint),
        onChanged: () => setState(() => _customEx = true),
      ),
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
    final labels = programLabels(templates, l.noFolder);
    final profile = ref.watch(profileOrDefaultProvider);
    final ex = widget.existing;
    return DiscardGuard(
      isDirty: () => _snapshot() != _initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ex == null ? l.planWorkout : l.editWorkout),
          actions: [TextButton(onPressed: _save, child: Text(l.save))],
        ),
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
                  firstDate: DateTime.now().subtract(const Duration(days: 365)), // time span
                  lastDate: DateTime.now().add(const Duration(days: 730)), // time span
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
                  // Same-named programs (a duplicated folder, "Beine" of two splits) show their folder.
                  for (final t in templates) DropdownMenuItem(value: t.id, child: Text(labels[t.id]!, overflow: TextOverflow.ellipsis)),
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
              Row(
                children: [
                  Expanded(
                    child: Text(l.workoutPhases, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  ZoneInfoButton(sport: _sport, profile: profile),
                ],
              ),
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
            if (_sport != Sport.gym && !_structured) ...[
              const SizedBox(height: 16),
              Text(l.intensity, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final i in intensitiesFor(_sport))
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
                  if (context.mounted) Navigator.pop(context, planDeleted);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Start the plan over: a new science-based plan (to race day when an event is set) replaces
/// the upcoming planned workouts after [confirmReplacePlan].
Future<void> showPlanGenerator(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PlanGenerator());
}

class _PlanGenerator extends ConsumerStatefulWidget {
  const _PlanGenerator();
  @override
  ConsumerState<_PlanGenerator> createState() => _PlanGeneratorState();
}

class _PlanGeneratorState extends ConsumerState<_PlanGenerator> {
  /// Plan length without an event (with one, the generator always plans to race day) –
  /// the same choices as the plan settings.
  late int _weeks = _currentLength(ref.read(profileOrDefaultProvider).athlete);

  /// The length of the plan that is running (e.g. 14 weeks after aligning it to a race) –
  /// the preselected chip must match "Woche 2/14", not the stored default of 12.
  static int _currentLength(AthleteData a) => (a.planLength ?? 0) > 0 ? a.planLength! : a.planWeeks;
  bool _busy = false;
  final _feasibility = FeasibilityCache();

  /// "Allow longer long runs" as switched in this sheet (null: as stored). Kept here until "Plan neu
  /// aufsetzen" saves it with the new plan ([_run]): saved at once, a sheet closed without rebuilding left the
  /// profile saying "on" next to a plan without those runs (review 2026-11).
  bool? _extend;

  /// The profile the sheet shows and builds: the stored one with [_extend].
  UserProfile _withExtend(UserProfile p) =>
      _extend == null || _extend == p.athlete.longRunExtend ? p : p.copyWith(athlete: p.athlete.merge({'longRunExtend': _extend}));

  static int? _eventWeeks(UserProfile p) {
    final d = p.athlete.eventDate;
    if (d == null) return null;
    final w = GoalModel.weeksUntil(d, DateTime.now());
    return w >= 1 && w <= GoalModel.maxEventWeeks ? w : null;
  }

  Future<void> _run() async {
    // Busy before the dialog: a double tap must not open two dialogs / generate twice.
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final profile = _withExtend(ref.read(profileOrDefaultProvider));
    final start = await confirmReplacePlan(context, ref.read(planListProvider));
    if (!mounted) return;
    if (start == null) {
      setState(() => _busy = false);
      return;
    }
    final count = await PlanService.replacePlan(
      repo: repo,
      l: l,
      profile: profile.copyWith(athlete: profile.athlete.merge({'planWeeks': _weeks})),
      templates: ref.read(templateListProvider),
      existing: ref.read(planListProvider),
      start: start,
      sessions: ref.read(sessionListProvider),
      weeks: _weeks,
      saveMeta: ref.read(profileProvider).value != null,
    );
    // (The switch is part of the profile the new plan was built from – saved with the plan's meta above.)
    if (mounted) {
      Navigator.pop(context);
      if (count != null) toast(context, l.planCreated(count));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stored = ref.watch(profileOrDefaultProvider);
    final p = _withExtend(stored);
    final eventWeeks = _eventWeeks(p);
    final current = _currentLength(p.athlete);
    final options = [
      // The same plain labels as the plan settings' plan-length chips.
      for (final w in const [4, 8, 12, 16, 20]) (w, l.planWeeksN(w)),
      if (![4, 8, 12, 16, 20].contains(current)) (current, l.planWeeksCurrent(current)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.startOverTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(l.generatePlanSub(p.focus.label(l), p.weeklyTarget), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              // The plan would be rebuilt for the wrong focus / without the race: fix that first.
              GoalMismatchCard(
                onAdjust: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan)));
                },
              ),
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
              if (p.athlete.eventDate != null && p.athlete.eventDistance != null) ...[
                const SizedBox(height: 12),
                FeasibilityCard(
                  _feasibility.of(p, DateTime.now(), l),
                  planAnyway: true,
                  showTargetOk: true,
                  onAdjustTarget: (sec) {
                    ref.read(repoProvider)!.saveProfile(stored.copyWith(athlete: stored.athlete.merge({'targetTimeSec': sec})));
                    toast(context, l.targetAdjusted(clock(sec)));
                  },
                  // Local until "Plan neu aufsetzen" below builds the plan with it ([_extend]).
                  onExtendLongRun: (v) => setState(() => _extend = v),
                ),
                if (_extend != null && _extend != stored.athlete.longRunExtend)
                  Padding(
                    key: const ValueKey('extendRebuildHint'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l.planRebuildExtendHint, style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
              const SizedBox(height: 16),
              if (eventWeeks != null)
                Container(
                  key: const ValueKey('planUntilRace'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, color: AppColors.brand),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          eventWeeks == 1 ? l.planToEventRaceWeek : l.planUntilRace(eventWeeks),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(l.planLength, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  key: const ValueKey('planLengthChoice'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (w, label) in options)
                      ChoiceChip(label: Text(label), selected: _weeks == w, onSelected: (_) => setState(() => _weeks = w)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(l.planLocalDesc, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _run,
                icon:
                    _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restart_alt_rounded),
                label: Text(l.startOverButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
