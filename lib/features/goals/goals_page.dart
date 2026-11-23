import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/event_distances.dart';
import '../../core/event_sport_x.dart';
import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/event_spec.dart';
import '../../services/goal_model.dart';
import '../../services/insights.dart';
import '../../services/plan_service.dart';
import '../../services/target_suggestion.dart';
import '../calendar/feasibility_card.dart';
import '../calendar/replace_plan_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/discard_guard.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/event_distance_picker.dart';
import '../../widgets/target_suggestion_line.dart';
import '../train/exercise_picker.dart';
import 'goal_forecast_widgets.dart';
import 'goal_mismatch_card.dart';
import '../onboarding/onboarding_page.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goals = ref.watch(goalsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l.goals)),
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
                  // Race goal, focus and plan disagree (older data): say so before the goals.
                  const GoalMismatchCard(),
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
                    (g.deadline == null || s.start.isBefore(addDays(g.deadline!, 1))),
              )
              .fold<double>(0, (a, s) => a + s.distanceM) /
          1000;
      return (km, g.target <= 0 ? 0 : (km / g.target).clamp(0.0, 1.0), '${Units.num(km, 1)} / ${Units.num(g.target)} km');
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
      final total = g.deadline == null ? 1 : daysBetween(g.created, g.deadline!).clamp(1, 10000);
      final today = dayOnly(DateTime.now());
      final left = g.deadline == null ? 0 : daysBetween(today, g.deadline!);
      if (g.deadline == null || left < 0) return (left.toDouble(), 1.0, l.eventPassed);
      // The plan's phase and week instead of a bare percentage of elapsed days.
      final e = EventProgress.of(
        g.deadline!,
        ref.watch(planListProvider),
        today,
        planForRace: planBuiltFor(ref.watch(profileOrDefaultProvider), g),
      );
      final p = e.week != null && e.weeks != null ? e.week! / e.weeks! : (1 - left / total).clamp(0.0, 1.0);
      return (left.toDouble(), p, eventProgressText(l, e));
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
      GoalType.strength => Sport.gym.icon,
      GoalType.event => Icons.emoji_events_outlined,
    };
    // Dynamic adjustment hint: compare progress with elapsed time.
    String? pace;
    if (!compact && g.deadline != null && g.type != GoalType.event && g.type != GoalType.frequency) {
      final total = daysBetween(g.created, g.deadline!).clamp(1, 10000);
      final elapsed = DateTime.now().difference(g.created).inDays.clamp(0, total); // time span
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
                if (g.type != GoalType.event) Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            // "noch 88 Tage · Grundlagenphase (Woche 2/13)" is too long for the title row.
            if (g.type == GoalType.event)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(label, key: const ValueKey('eventGoalProgress'), style: Theme.of(context).textTheme.bodySmall),
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
                  // Event goals say where the plan stands (phase, week) in the label instead.
                  if (g.type != GoalType.event) Text('  ${Units.pct(progress * 100)}', style: const TextStyle(fontWeight: FontWeight.w700)),
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

  // Event goal → training plan alignment. The switch shows reality: on when the plan is
  // built for this race (then it is a status, not an action), off for an existing race the
  // plan doesn't target; a new race defaults to aligning.
  late final bool _planAligned = _isPlanAligned();
  late bool _align = widget.existing == null || _planAligned;
  late int? _targetSec = _initialTarget();

  /// (Checked in the background – the page rebuilds when a check is done.)
  late final _feasibility = FeasibilityCache(
    onUpdate: () {
      if (mounted) setState(() {});
    },
  );

  /// The plan settings point at this (existing) race: same day and distance.
  bool _isPlanAligned() {
    final ex = widget.existing;
    final a = ref.read(profileOrDefaultProvider).athlete;
    if (ex == null || ex.type != GoalType.event || a.eventDate == null || ex.deadline == null) return false;
    return sameDay(a.eventDate!, ex.deadline!) && (a.eventDistance == null || a.eventDistance == _initialKey());
  }

  int? _initialTarget() {
    final a = ref.read(profileOrDefaultProvider).athlete;
    final ex = widget.existing;
    if (ex == null || ex.type != GoalType.event) return null;
    final sameRace = a.eventDate != null && ex.deadline != null && sameDay(a.eventDate!, ex.deadline!);
    return sameRace && _initialKey() == a.eventDistance ? a.targetTimeSec : null;
  }

  /// Race distance picked from the presets (kept while the km field matches it exactly).
  late String? _eventKey = _initialKey();

  /// The stored preset, else the plan's race when it is this goal's race, else a preset of
  /// exactly this length (never a neighbouring one: 51,5 km is not "Ultra 50 km").
  String? _initialKey() {
    final ex = widget.existing;
    if (ex == null || ex.type != GoalType.event) return null;
    if (eventDistanceOf(ex.eventKey) != null) return ex.eventKey;
    final a = ref.read(profileOrDefaultProvider).athlete;
    final km = ex.eventKm ?? ex.target;
    final planRace = eventDistanceOf(a.eventDistance);
    if (planRace != null && a.eventDate != null && ex.deadline != null && sameDay(a.eventDate!, ex.deadline!) && _sameKm(km, planRace.km)) {
      return planRace.key;
    }
    return eventKeyForKm(km);
  }

  /// Race type (Laufen / Triathlon / Duathlon / Radfahren / Freiwasser) of an event goal.
  late EventSport _raceSport = eventDistanceOf(_eventKey)?.sport ?? EventSportX.fromFocus(ref.read(profileOrDefaultProvider).focus);

  /// Event distance key of the current input: the picked preset while the km match it,
  /// else a preset of the race type with exactly these km – null for any other distance.
  String? get _key {
    final km = parseNum(_target.text) ?? 0;
    final picked = eventDistanceOf(_eventKey);
    if (picked != null && picked.sport == _raceSport && _sameKm(km, picked.km)) return picked.key;
    return eventKeyForKm(km, sport: _raceSport, only: true);
  }

  void _pickDistance(String? key) {
    final d = eventDistanceOf(key);
    setState(() {
      // A target time belongs to its distance.
      if (d?.key != _key) _targetSec = null;
      _eventKey = d?.key;
      if (d != null) {
        _target.text = Units.num(d.km, 2);
        _raceSport = d.sport;
        _sport = d.sport.sport;
      }
    });
  }

  void _pickRaceSport(EventSport s) => setState(() {
    if (_raceSport == s) return;
    _raceSport = s;
    _sport = s.sport;
    // The distance of another race type doesn't carry over.
    _eventKey = null;
    _target.clear();
    _targetSec = null;
  });
  @override
  void initState() {
    super.initState();
    _initial = _snapshot();
  }

  /// Entered values (for the unsaved-changes prompt on back).
  String _snapshot() => [
    _type.name,
    _sport?.name,
    _raceSport.name,
    _title.text,
    _target.text,
    _deadline?.millisecondsSinceEpoch,
    _exId,
    _align,
    _targetSec,
  ].join('\u0000');
  late final String _initial;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Recommended plan length (weeks, lower end) to the chosen race – 12 when unknown.
  int _raceWeeks() => EventSpec.of(_key)?.weeksFor(ref.read(profileOrDefaultProvider).level).$1 ?? 12;

  /// The profile with this event as the plan's goal (null when it cannot be aligned).
  UserProfile? _alignedProfile() {
    final key = _key;
    if (_type != GoalType.event || !_align || _deadline == null || key == null) return null;
    final p = ref.read(profileOrDefaultProvider);
    final a = p.athlete;
    // Already aligned and nothing about the race changed: nothing to rebuild.
    if (_planAligned && sameDay(a.eventDate!, _deadline!) && a.eventDistance == key && a.targetTimeSec == _targetSec) return null;
    // Goal and plan stay consistent: a triathlon is planned with the triathlon focus.
    final focus = _focusFor(key, p.focus);
    return p.copyWith(
      focus: focus,
      athlete: a.merge({'eventDate': _deadline, 'eventDistance': key, 'targetTimeSec': _targetSec, 'eventName': _raceName()}),
    );
  }

  /// The race's own name from the title field (null when empty or just the distance's name, [ownRaceName]) – the plan
  /// shows it on Home, the goal page and race day ([raceLabel]), so aligning or renaming here carries it over
  /// (review of final-open: "Berlin" aligned here still showed the previous "Hamburg · Marathon").
  String? _raceName() => ownRaceName(context.l10n, _key, _title.text);

  /// Aligning needs another focus (triathlon goal, hybrid focus): the week of the current
  /// settings has no cycling – the plan settings are opened instead of guessing.
  bool get _needsWizard {
    final key = _key;
    return _type == GoalType.event && _align && key != null && !eventFitsFocus(key, ref.read(profileOrDefaultProvider).focus);
  }

  /// The training focus a race needs (the current one when it fits).
  static TrainingFocus _focusFor(String key, TrainingFocus current) => focusForRace(key, current);

  /// Rebuilds the plan up to race day: completed workouts stay, the old plan's open ones are replaced.
  void _alignPlan(UserProfile profile, DateTime start) {
    final l = context.l10n;
    PlanService.replacePlan(
      repo: ref.read(repoProvider)!,
      l: l,
      profile: profile,
      templates: ref.read(templateListProvider),
      existing: ref.read(planListProvider),
      start: start,
      sessions: ref.read(sessionListProvider),
      weeks: profile.athlete.planWeeks,
    );
    toast(context, l.planAligned(GoalModel.weeksUntil(profile.athlete.eventDate!, start)));
  }

  /// Target time of the race [key]: scroll wheels within its plausible range ([eventTimeBounds]),
  /// starting at the suggestion.
  Widget _targetField(AppLocalizations l, String key) {
    final bounds = eventTimeBounds(key);
    final p = ref.watch(profileOrDefaultProvider);
    final date = _deadline ?? addDays(dayOnly(DateTime.now()), 84);
    final suggested = suggestTargetTime(p, key, date, sessions: ref.watch(sessionListProvider), plans: ref.watch(planListProvider)).sec;
    return DurationField(
      key: const ValueKey('goalTargetTime'),
      value: _targetSec,
      onChanged: (v) => setState(() => _targetSec = v),
      label: l.targetTime,
      title: l.targetTime,
      helperText: l.targetTimeHint,
      emptyText: l.noTargetTime,
      min: bounds?.$1,
      max: bounds?.$2,
      initial: suggested ?? (bounds == null ? null : GoalModel.roundTarget(sqrt(bounds.$1 * bounds.$2).round())),
    );
  }

  /// Why the goal can't be saved yet (shown above the disabled button), null when it can.
  String? _invalidReason(AppLocalizations l) {
    final v = parseNum(_target.text) ?? 0;
    return switch (_type) {
      GoalType.strength when _exId == null => l.goalNeedsExercise,
      GoalType.event when _deadline == null => l.goalNeedsDate,
      GoalType.event when v <= 0 => l.goalNeedsDistance,
      GoalType.frequency when v < 1 => l.goalNeedsTarget,
      GoalType.distance || GoalType.weight || GoalType.strength when v <= 0 => l.goalNeedsTarget,
      _ => null,
    };
  }

  /// Delete after a confirmation, with undo in the snackbar.
  Future<void> _delete() async {
    final l = context.l10n;
    final g = widget.existing!;
    if (!await confirm(context, l.deleteGoalTitle, body: g.title, ok: l.delete, danger: true)) return;
    if (!mounted) return;
    final repo = ref.read(repoProvider)!;
    final messenger = ScaffoldMessenger.of(context);
    repo.deleteGoal(g.id);
    Navigator.pop(context);
    undoToast(messenger, text: l.goalDeleted(g.title), undoLabel: l.undo, onUndo: () => repo.saveGoal(g));
  }

  /// Set while saving: a double tap must not save the goal / align the plan twice.
  bool _saving = false;

  /// "Save" was tapped with something missing.
  bool _submitted = false;

  /// Errors show after a save attempt or once the target was typed (an existing goal: always).
  bool get _showErrors => _submitted || widget.existing != null || _target.text.isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      await _doSave();
    } finally {
      _saving = false;
    }
  }

  Future<void> _doSave() async {
    // Aligning replaces the upcoming plan – asked first, cancelling saves nothing. With a
    // focus change the plan settings take over (week with every discipline, then confirm).
    final wizard = _needsWizard;
    final aligned = wizard ? null : _alignedProfile();
    DateTime? planStart;
    if (aligned != null) {
      planStart = await confirmReplacePlan(
        context,
        ref.read(planListProvider),
        sessions: ref.read(sessionListProvider),
        profile: ref.read(profileOrDefaultProvider),
      );
      if (planStart == null || !mounted) return;
    }
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
              GoalType.distance => '${Units.num(target)} km ${_sport?.label(l) ?? ''}'.trim(),
              GoalType.frequency => l.perWeekProgress(0, target.toInt()).split('/').last.trim(),
              GoalType.strength => _exName ?? l.goalTypeStrength,
              // Named after the race distance ("Halbmarathon") when it is a known one.
              GoalType.event => _key == null ? l.goalTypeEvent : eventDistanceLabel(l, _key!),
            };
    repo.saveGoal(
      Goal(
        id: widget.existing?.id ?? repo.newId(),
        type: _type,
        title: title,
        sport: _type == GoalType.event ? _raceSport.sport : _sport,
        target: target,
        startValue: widget.existing?.startValue ?? start,
        created: widget.existing?.created ?? DateTime.now(),
        deadline: _deadline,
        exId: _exId,
        exName: _exName,
        eventKm: _type == GoalType.event ? target : null,
        eventKey: _type == GoalType.event ? _key : null,
      ),
    );
    if (aligned != null) _alignPlan(aligned, planStart!);
    // The plan's race renamed (nothing else changed – no new plan): the plan settings carry the new name.
    if (aligned == null && !wizard && _type == GoalType.event && _align && _planAligned) {
      final p = ref.read(profileOrDefaultProvider);
      final name = _raceName();
      if ((p.athlete.eventName ?? '').trim() != (name ?? '')) repo.saveProfile(p.copyWith(athlete: p.athlete.merge({'eventName': name})));
    }
    final nav = Navigator.of(context);
    nav.pop();
    // The plan settings read the saved goal (race, date, distance, focus of the race).
    if (wizard) nav.push(MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    // Keep programs and plans loaded: aligning the plan reads them.
    ref.watch(templateListProvider);
    ref.watch(planListProvider);
    final aligned = _alignedProfile();
    final eventKey = _key;
    final types = {
      GoalType.frequency: (l.goalTypeFrequency, Icons.repeat_rounded),
      GoalType.distance: (l.goalTypeDistance, Icons.straighten),
      GoalType.weight: (l.goalTypeWeight, Icons.monitor_weight_outlined),
      GoalType.strength: (l.goalTypeStrength, Sport.gym.icon),
      GoalType.event: (l.goalTypeEvent, Icons.emoji_events_outlined),
    };
    final suffix = switch (_type) {
      GoalType.weight || GoalType.strength => u.weightUnit,
      GoalType.distance || GoalType.event => 'km',
      GoalType.frequency => l.perWeek,
    };
    return DiscardGuard(
      isDirty: () => _snapshot() != _initial,
      child: Padding(
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
                    if (widget.existing != null) IconButton(icon: const Icon(Icons.delete_outline), tooltip: l.delete, onPressed: _delete),
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
                if (_type == GoalType.distance || _type == GoalType.frequency) ...[
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
                    leading: Icon(Sport.gym.icon),
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
                if (_type == GoalType.event) ...[
                  Text(l.raceType, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in EventSport.values)
                        ChoiceChip(
                          key: ValueKey('raceType-${s.name}'),
                          avatar: Icon(s.icon, size: 16),
                          label: Text(s.label(l)),
                          selected: _raceSport == s,
                          onSelected: (_) => _pickRaceSport(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  EventDistanceChips(sports: [_raceSport], selected: eventKey, onChanged: _pickDistance),
                  const SizedBox(height: 12),
                ],
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
                        lastDate: DateTime.now().add(const Duration(days: 1095)), // time span
                        // A race: on the long-session day (else Sunday) of the race's recommended plan length.
                        initialDate:
                            _deadline ??
                            (_type == GoalType.event
                                ? defaultRaceDateFor(
                                  _key,
                                  DateTime.now(),
                                  _raceWeeks(),
                                  longDay: ref.read(profileOrDefaultProvider).longDay,
                                )
                                : DateTime.now().add(const Duration(days: 60))), // time span
                      );
                      if (d != null) setState(() => _deadline = d);
                    },
                  ),
                if (_type == GoalType.event) ...[
                  const SizedBox(height: 8),
                  if (_planAligned)
                    ListTile(
                      key: const ValueKey('alignPlanStatus'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      title: Text(l.alignStatusAligned),
                      subtitle: Text(l.alignStatusAlignedSub),
                    )
                  else
                    SwitchListTile(
                      key: const ValueKey('alignPlan'),
                      contentPadding: EdgeInsets.zero,
                      value: _align,
                      onChanged: (v) => setState(() => _align = v),
                      title: Text(l.alignPlanToEvent),
                      subtitle: Text(widget.existing != null && !_align ? l.alignStatusNotAligned : l.alignPlanToEventSub),
                    ),
                  if (_align && eventKey == null)
                    Text(l.alignNeedsDistance, style: Theme.of(context).textTheme.bodySmall)
                  else if (_align) ...[
                    if (!eventFitsFocus(eventKey, ref.watch(profileOrDefaultProvider).focus))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l.alignFocusWizard(_focusFor(eventKey!, ref.watch(profileOrDefaultProvider).focus).label(l)),
                          key: const ValueKey('alignFocusHint'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.brand),
                        ),
                      ),
                    _targetField(l, eventKey!),
                    if (_deadline != null)
                      TargetSuggestionLine(
                        profile: ref.watch(profileOrDefaultProvider),
                        eventKey: eventKey,
                        eventDate: _deadline!,
                        sessions: ref.watch(sessionListProvider),
                        plans: ref.watch(planListProvider),
                        current: _targetSec,
                        onApply: (sec) => setState(() => _targetSec = sec),
                        onClear: () => setState(() => _targetSec = null),
                      ),
                    // Never a check computed with the wrong focus (its week has no cycling:
                    // "long ride only 0 min") – the plan settings check it with the new week.
                    if (aligned != null && !_needsWizard) ...[
                      const SizedBox(height: 12),
                      FeasibilityCard(
                        _feasibility.of(aligned, DateTime.now(), l),
                        planAnyway: true,
                        showTargetOk: true,
                        onAdjustTarget: (sec) => setState(() => _targetSec = sec),
                        // The race's own settings (date, distance) right here; the week in the plan settings.
                        onAction: (x) {
                          switch (x) {
                            case FeasLaterDate(:final date):
                              setState(() => _deadline = date);
                            case FeasShorter(:final distance):
                              _pickDistance(distance);
                            case FeasClearTarget():
                              setState(() => _targetSec = null);
                            case FeasSetTarget(:final sec):
                              setState(() => _targetSec = sec);
                            default:
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan)));
                          }
                        },
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: 20),
                // Validated on submit / once something was entered – no red error on a fresh sheet.
                if (_showErrors && _invalidReason(l) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _invalidReason(l)!,
                      key: const ValueKey('goalInvalid'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('saveGoal'),
                  onPressed: () {
                    if (_invalidReason(l) != null) {
                      setState(() => _submitted = true);
                      return;
                    }
                    _save();
                  },
                  child: Text(l.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether two race lengths are the same distance (the km field shows presets rounded to
/// two decimals: 21,1 ↔ 21,0975).
bool _sameKm(double a, double b) => (a - b).abs() < 0.06;

/// Event distance key ([eventDistances]) of a race distance of exactly [km] (rounding aside),
/// null for other distances – a neighbouring preset is never picked (51,5 km is the olympic
/// triathlon, not "Ultra 50 km"). Several distances can share a length (5 km run / 5 km open
/// water): [prefer] wins, then a distance of [sport], then the catalogue order. [only]: a
/// distance of [sport] or nothing.
String? eventKeyForKm(double km, {String? prefer, EventSport? sport, bool only = false}) {
  final hits = [
    for (final d in eventDistances)
      if (km > 0 && _sameKm(km, d.km) && (!only || d.sport == sport)) d,
  ];
  return (hits.where((d) => d.key == prefer).firstOrNull ?? hits.where((d) => d.sport == sport).firstOrNull ?? hits.firstOrNull)?.key;
}
