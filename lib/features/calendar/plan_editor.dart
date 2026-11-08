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
import '../../widgets/segments.dart';
import '../../core/theme.dart';
import '../../data/default_programs.dart';
import '../onboarding/onboarding_page.dart';

/// Add or edit a planned workout.
Future<void> showPlanEditor(BuildContext context, WidgetRef ref, {PlannedWorkout? existing, DateTime? date}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlanEditor(existing: existing, date: date ?? DateTime.now()),
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

  void _save() {
    final repo = ref.read(repoProvider)!;
    final l = context.l10n;
    repo.savePlan(
      PlannedWorkout(
        id: widget.existing?.id ?? repo.newId(),
        date: _date,
        sport: _sport,
        title: _title.text.trim().isEmpty ? _sport.label(l) : _title.text.trim(),
        description: _desc.text.trim(),
        durationMin: _min,
        distanceKm: parseNum(_km.text),
        intensity: _intensity,
        templateId: _templateId,
        status: widget.existing?.status ?? 'planned',
        sessionId: widget.existing?.sessionId,
        // Keep the generated structure unless the sport changed.
        steps: widget.existing?.sport == _sport ? widget.existing!.steps : const [],
        phase: widget.existing?.phase,
        isKey: widget.existing?.isKey ?? false,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final templates = ref.watch(templateListProvider).where((t) => t.sport == _sport).toList();
    final ex = widget.existing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ex == null ? l.planWorkout : l.editWorkout,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (ex != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        ref.read(repoProvider)!.deletePlan(ex.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Segments<Sport>(
                segments: [for (final s in Sport.values) Seg(s, icon: s.icon)],
                value: _sport,
                onChanged:
                    (v) => setState(() {
                      _sport = v;
                      _templateId = null;
                    }),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(DateFormat.yMMMMEEEEd(context.localeName).format(_date)),
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
              if (templates.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: templates.any((t) => t.id == _templateId) ? _templateId : null,
                  decoration: InputDecoration(labelText: l.program),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.none)),
                    for (final t in templates) DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged:
                      (v) => setState(() {
                        _templateId = v;
                        final t = templates.where((t) => t.id == v).firstOrNull;
                        if (t != null) {
                          _title.text = t.name;
                          _min = t.estimatedMinutes;
                          _intensity = t.intensity;
                          if (t.description.isNotEmpty) _desc.text = t.description;
                          if (t.targetKm != null) _km.text = Units.num(t.targetKm!);
                        }
                      }),
                ),
              const SizedBox(height: 12),
              TextField(controller: _title, decoration: InputDecoration(labelText: l.title)),
              const SizedBox(height: 12),
              TextField(controller: _desc, minLines: 1, maxLines: 4, decoration: InputDecoration(labelText: l.description)),
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
              if (_sport != Sport.gym) ...[
                TextField(
                  controller: _km,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l.targetDistance, suffixText: 'km'),
                ),
                const SizedBox(height: 12),
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
              const SizedBox(height: 20),
              Row(
                children: [
                  if (ex != null && !ex.isDone) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l.start),
                        onPressed: () {
                          Navigator.pop(context);
                          startPlanned(context, ref, ex);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: FilledButton(onPressed: _save, child: Text(l.save))),
                ],
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
            ],
          ),
        ),
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
