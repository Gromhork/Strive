import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/default_programs.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/goal_model.dart';
import '../../services/insights.dart';
import '../../services/plan_gaps.dart';
import '../../services/plan_generator.dart';
import '../calendar/feasibility_card.dart';
import '../../services/race_search.dart';
import '../../widgets/common.dart';
import '../train/exercise_picker.dart';
import 'race_search_page.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goals = ref.watch(goalsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.goals),
        actions: [
          IconButton(tooltip: l.raceSearch, icon: const Icon(Icons.travel_explore_rounded), onPressed: () => openRaceSearch(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGoalEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.newGoal),
      ),
      body:
          goals.isEmpty
              ? EmptyState(icon: Icons.flag_outlined, text: l.noGoalsYet)
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final g in goals) Padding(padding: const EdgeInsets.only(bottom: 10), child: SectionCard(child: GoalTile(goal: g))),
                ],
              ),
    );
  }
}

/// Computes current value & progress of a goal from the user's data.
(double current, double progress, String label) goalProgress(Goal g, WidgetRef ref, BuildContext context) {
  final l = context.l10n;
  final sessions = ref.watch(sessionListProvider);
  final body = ref.watch(bodyProvider).value ?? const [];
  final u = ref.watch(profileOrDefaultProvider).units;
  switch (g.type) {
    case GoalType.weight:
      final start = g.startValue ?? (body.isNotEmpty ? body.first.weightKg : g.target);
      final cur = body.isNotEmpty ? body.last.weightKg : start;
      final total = (g.target - start).abs();
      final done = total == 0 ? 1.0 : ((cur - start) / (g.target - start)).clamp(0.0, 1.0);
      return (cur, done, '${u.weight(cur)} → ${u.weight(g.target)}');
    case GoalType.distance:
      final km =
          sessions
              .where(
                (s) =>
                    (g.sport == null || s.sport == g.sport) &&
                    !s.start.isBefore(g.created) &&
                    (g.deadline == null || s.start.isBefore(g.deadline!.add(const Duration(days: 1)))),
              )
              .fold<double>(0, (a, s) => a + s.distanceM) /
          1000;
      return (km, g.target <= 0 ? 0 : (km / g.target).clamp(0.0, 1.0), '${Units.num(km, 1)} / ${Units.num(g.target)} km');
    case GoalType.frequency:
      final weekStart = startOfWeek(DateTime.now());
      final n = sessions.where((s) => !s.start.isBefore(weekStart) && (g.sport == null || s.sport == g.sport)).length.toDouble();
      return (n, g.target <= 0 ? 0 : (n / g.target).clamp(0.0, 1.0), l.perWeekProgress(n.toInt(), g.target.toInt()));
    case GoalType.strength:
      final rec = exerciseRecords(sessions)[g.exId];
      final cur = rec?.bestE1rm ?? 0;
      final start = g.startValue ?? 0;
      final p = g.target <= start ? 1.0 : ((cur - start) / (g.target - start)).clamp(0.0, 1.0);
      return (cur, p, 'e1RM ${u.weight(cur, digits: 0)} / ${u.weight(g.target, digits: 0)}');
    case GoalType.event:
      final total = g.deadline == null ? 1 : g.deadline!.difference(g.created).inDays.clamp(1, 10000);
      final left = g.deadline == null ? 0 : g.deadline!.difference(dayOnly(DateTime.now())).inDays;
      return (left.toDouble(), (1 - left / total).clamp(0.0, 1.0), left >= 0 ? l.daysLeft(left) : l.eventPassed);
  }
}

class GoalTile extends ConsumerWidget {
  const GoalTile({super.key, required this.goal, this.compact = false});
  final Goal goal;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final g = goal;
    final (_, progress, label) = goalProgress(g, ref, context);
    final color = g.sport?.color ?? AppColors.brand;
    final icon = switch (g.type) {
      GoalType.weight => Icons.monitor_weight_outlined,
      GoalType.distance => Icons.straighten,
      GoalType.frequency => Icons.repeat_rounded,
      GoalType.strength => Icons.fitness_center,
      GoalType.event => Icons.emoji_events_outlined,
    };
    // Dynamic adjustment hint: compare progress with elapsed time.
    String? pace;
    if (!compact && g.deadline != null && g.type != GoalType.event && g.type != GoalType.frequency) {
      final total = g.deadline!.difference(g.created).inDays.clamp(1, 10000);
      final elapsed = DateTime.now().difference(g.created).inDays.clamp(0, total);
      final expected = elapsed / total;
      pace = progress >= expected - 0.05 ? l.onTrack : l.behindSchedule;
    }
    return InkWell(
      onTap: compact ? null : () => showGoalEditor(context, ref, existing: g),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: compact ? 18 : 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: compact ? 13 : 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: compact ? 6 : 10, color: color),
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (g.deadline != null)
                    Text(
                      '${l.until} ${DateFormat.yMMMd(context.localeName).format(g.deadline!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const Spacer(),
                  if (pace != null)
                    Text(
                      pace,
                      style: TextStyle(
                        fontSize: 12,
                        color: pace == l.onTrack ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text('  ${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showGoalEditor(BuildContext context, WidgetRef ref, {Goal? existing}) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _GoalEditor(existing: existing));
}

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({this.existing});
  final Goal? existing;
  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late GoalType _type = widget.existing?.type ?? GoalType.frequency;
  late Sport? _sport = widget.existing?.sport;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _target = TextEditingController(text: widget.existing == null ? '' : Units.num(widget.existing!.target));
  late DateTime? _deadline = widget.existing?.deadline;
  late String? _exId = widget.existing?.exId;
  late String? _exName = widget.existing?.exName;

  // Event goal → training plan alignment (new event, or a date that is not the plan's yet).
  late bool _align = _alignDefault();
  late int? _targetSec = _initialTarget();
  final _targetCtl = TextEditingController();
  final _feasibility = FeasibilityCache();

  bool _alignDefault() {
    final ex = widget.existing;
    final a = ref.read(profileOrDefaultProvider).athlete;
    if (ex == null) return true;
    return ex.type == GoalType.event && (a.eventDate == null || ex.deadline == null || !sameDay(a.eventDate!, ex.deadline!));
  }

  int? _initialTarget() {
    final a = ref.read(profileOrDefaultProvider).athlete;
    final km = widget.existing?.eventKm ?? widget.existing?.target;
    return km != null && eventKeyForKm(km) == a.eventDistance ? a.targetTimeSec : null;
  }

  @override
  void initState() {
    super.initState();
    if (_targetSec != null) _targetCtl.text = clock(_targetSec!);
  }

  @override
  void dispose() {
    _targetCtl.dispose();
    super.dispose();
  }

  /// The profile with this event as the plan's goal (null when it cannot be aligned).
  UserProfile? _alignedProfile() {
    final key = eventKeyForKm(parseNum(_target.text) ?? 0);
    if (_type != GoalType.event || !_align || _deadline == null || key == null) return null;
    final p = ref.read(profileOrDefaultProvider);
    return p.copyWith(athlete: p.athlete.merge({'eventDate': _deadline, 'eventDistance': key, 'targetTimeSec': _targetSec}));
  }

  /// Rebuilds the plan up to race day: completed workouts stay, upcoming planned ones are replaced.
  void _alignPlan(UserProfile profile) {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;

    var templates = ref.read(templateListProvider);
    final added = missingBuiltins(
      templates,
      repo.newId,
      de: l.localeName.startsWith('de'),
      only: PlanGenerator.gymKeysFor(profile).toSet(),
    );
    if (added.isNotEmpty) {
      repo.saveTemplates(added);
      templates = [...templates, ...added];
    }
    final now = DateTime.now();
    repo.deletePlansFrom(ref.read(planListProvider), dayOnly(now));
    repo.savePlans(PlanGenerator(l, profile, templates, repo.newId).generate(start: now, weeks: profile.athlete.planWeeks));
    // Plan start / length, so "Re-plan & recalibrate" can rebuild it (gap filling).
    repo.saveProfile(withPlanMeta(profile, now, profile.athlete.planWeeks));
    toast(context, l.planAligned(GoalModel.weeksUntil(profile.athlete.eventDate!, now)));
  }

  void _save() {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final u = ref.read(profileOrDefaultProvider).units;
    var target = parseNum(_target.text) ?? 0;
    if (_type == GoalType.weight || _type == GoalType.strength) target = u.weightIn(target);
    final body = ref.read(bodyProvider).value ?? const [];
    double? start;
    if (_type == GoalType.weight) start = body.isNotEmpty ? body.last.weightKg : ref.read(profileOrDefaultProvider).weightKg;
    if (_type == GoalType.strength) start = exerciseRecords(ref.read(sessionListProvider))[_exId]?.bestE1rm ?? 0;
    final title =
        _title.text.trim().isNotEmpty
            ? _title.text.trim()
            : switch (_type) {
              GoalType.weight => l.goalTypeWeight,
              GoalType.distance => '${Units.num(target)} km ${_sport?.label(l) ?? ''}'.trim(),
              GoalType.frequency => l.perWeekProgress(0, target.toInt()).split('/').last.trim(),
              GoalType.strength => _exName ?? l.goalTypeStrength,
              GoalType.event => l.goalTypeEvent,
            };
    repo.saveGoal(
      Goal(
        id: widget.existing?.id ?? repo.newId(),
        type: _type,
        title: title,
        sport: _sport,
        target: target,
        startValue: widget.existing?.startValue ?? start,
        created: widget.existing?.created ?? DateTime.now(),
        deadline: _deadline,
        exId: _exId,
        exName: _exName,
        eventKm: _type == GoalType.event ? target : null,
      ),
    );
    final aligned = _alignedProfile();
    if (aligned != null) _alignPlan(aligned);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    // Keep programs and plans loaded: aligning the plan reads them.
    ref.watch(templateListProvider);
    ref.watch(planListProvider);
    final aligned = _alignedProfile();
    final eventKey = eventKeyForKm(parseNum(_target.text) ?? 0);
    final types = {
      GoalType.frequency: (l.goalTypeFrequency, Icons.repeat_rounded),
      GoalType.distance: (l.goalTypeDistance, Icons.straighten),
      GoalType.weight: (l.goalTypeWeight, Icons.monitor_weight_outlined),
      GoalType.strength: (l.goalTypeStrength, Icons.fitness_center),
      GoalType.event: (l.goalTypeEvent, Icons.emoji_events_outlined),
    };
    final suffix = switch (_type) {
      GoalType.weight || GoalType.strength => u.weightUnit,
      GoalType.distance || GoalType.event => 'km',
      GoalType.frequency => l.perWeek,
    };
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
                      widget.existing == null ? l.newGoal : l.editGoal,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        ref.read(repoProvider)!.deleteGoal(widget.existing!.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in types.entries)
                    ChoiceChip(
                      avatar: Icon(t.value.$2, size: 16),
                      label: Text(t.value.$1),
                      selected: _type == t.key,
                      onSelected: widget.existing != null ? null : (_) => setState(() => _type = t.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: _title, decoration: InputDecoration(labelText: l.title, hintText: types[_type]!.$1)),
              const SizedBox(height: 12),
              if (_type == GoalType.distance || _type == GoalType.frequency || _type == GoalType.event) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: Text(l.allSports), selected: _sport == null, onSelected: (_) => setState(() => _sport = null)),
                    for (final s in Sport.values.where((s) => _type != GoalType.distance || s != Sport.gym))
                      ChoiceChip(
                        avatar: Icon(s.icon, size: 16, color: s.color),
                        label: Text(s.label(l)),
                        selected: _sport == s,
                        onSelected: (_) => setState(() => _sport = s),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_type == GoalType.strength)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fitness_center),
                  title: Text(_exName ?? l.chooseExercise),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await pickExercises(context);
                    if (picked.isNotEmpty) {
                      setState(() {
                        _exId = picked.first.id;
                        _exName = picked.first.name;
                      });
                    }
                  },
                ),
              TextField(
                controller: _target,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _type == GoalType.event ? l.eventDistance : l.target, suffixText: suffix),
              ),
              const SizedBox(height: 12),
              if (_type != GoalType.frequency)
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(
                    _deadline == null
                        ? (_type == GoalType.event ? l.eventDate : l.deadlineOptional)
                        : DateFormat.yMMMd(context.localeName).format(_deadline!),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1095)),
                      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) setState(() => _deadline = d);
                  },
                ),
              if (_type == GoalType.event)
                TextButton.icon(
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Text(l.raceSearch),
                  onPressed: () async {
                    final r = await openRaceSearch(context);
                    if (r == null || !mounted) return;
                    setState(() {
                      _deadline = r.date;
                      _title.text = r.name;
                      _sport = r.sport.sport;
                      if (eventKm(r.distance) != null) _target.text = Units.num(eventKm(r.distance)!);
                    });
                  },
                ),
              if (_type == GoalType.event) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const ValueKey('alignPlan'),
                  contentPadding: EdgeInsets.zero,
                  value: _align,
                  onChanged: (v) => setState(() => _align = v),
                  title: Text(l.alignPlanToEvent),
                  subtitle: Text(l.alignPlanToEventSub),
                ),
                if (_align && eventKey == null)
                  Text(l.alignNeedsDistance, style: Theme.of(context).textTheme.bodySmall)
                else if (_align) ...[
                  TextField(
                    controller: _targetCtl,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: l.targetTime,
                      helperText: l.targetTimeHint,
                      hintText: 'h:mm:ss',
                      prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                    ),
                    onChanged: (v) => setState(() => _targetSec = parseClock(v)),
                  ),
                  if (aligned != null) ...[
                    const SizedBox(height: 12),
                    FeasibilityCard(
                      _feasibility.of(aligned, DateTime.now(), l),
                      planAnyway: true,
                      showTargetOk: true,
                      onAdjustTarget:
                          (sec) => setState(() {
                            _targetSec = sec;
                            _targetCtl.text = clock(sec);
                          }),
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_type == GoalType.strength && _exId == null) || (_type == GoalType.event && _deadline == null) ? null : _save,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Event distance key of a race distance in km (5 / 10 km, HM, marathon, triathlon distances),
/// null for other distances.
String? eventKeyForKm(double km) {
  const keys = {'5k': 5.0, '10k': 10.0, 'hm': 21.0975, 'm': 42.195, 'sprint': 25.75, 'olympic': 51.5, '70.3': 113.0};
  for (final e in keys.entries) {
    if ((km - e.value).abs() <= e.value * 0.03) return e.key;
  }
  return null;
}
