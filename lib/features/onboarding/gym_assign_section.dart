import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/default_programs.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/plan_exercises.dart';
import '../../services/plan_generator.dart';
import '../../widgets/segments.dart';

/// "Programme selbst zuweisen" in the plan setup's strength step: the athlete picks the program of
/// each gym day ([AthleteData.gymPlanA]), optionally alternating with a second week
/// ([AthleteData.gymAB], [AthleteData.gymPlanB]). Prefilled with the generator's suggestion
/// ([PlanGenerator.suggestedGymWeeks]); warns about the same program on consecutive days and a
/// leg-heavy program the day before the long session.
class GymAssignSection extends StatefulWidget {
  const GymAssignSection({super.key, required this.profile, required this.templates, required this.onChanged});

  /// The profile as edited so far (its week decides the gym days).
  final UserProfile profile;

  /// The athlete's programs (all sports; only gym programs are offered).
  final List<WorkoutTemplate> templates;

  /// Athlete-data changes ([AthleteData.merge] keys).
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<GymAssignSection> createState() => _GymAssignSectionState();
}

class _GymAssignSectionState extends State<GymAssignSection> {
  /// The week whose programs are shown ('A' / 'B').
  String _week = 'A';

  AthleteData get a => widget.profile.athlete;

  List<int> get _gymDays => [
    for (final e in PlanGenerator.scheduleOf(widget.profile).entries)
      if (e.value.contains(Sport.gym)) e.key,
  ]..sort();

  bool get _de => Localizations.localeOf(context).languageCode == 'de';

  /// Built-in gym programs (the ones the athlete does not have yet are offered too).
  List<WorkoutTemplate> get _builtins => [
    for (final t in defaultTemplates(() => '', de: _de, goal: a.gymGoal))
      if (t.sport == Sport.gym) t,
  ];

  /// Programs the picker offers: the athlete's gym programs, then the built-ins they don't have.
  List<WorkoutTemplate> get _programs {
    final own = [
      for (final t in widget.templates)
        if (t.sport == Sport.gym) t,
    ];
    final keys = {for (final t in own) t.key};
    return [
      ...own,
      for (final t in _builtins)
        if (!keys.contains(t.key)) t,
    ];
  }

  WorkoutTemplate? _program(String? ref) => ref == null ? null : gymProgramOf(ref, widget.templates, builtins: _builtins);

  String _dayName(int d) =>
      DateFormat.E(Localizations.localeOf(context).toLanguageTag()).format(addDays(startOfWeek(DateTime.now()), d - 1));

  /// Turns the assignment on: gym days without a program get the generator's suggestion.
  void _enable(bool on) {
    if (!on) {
      widget.onChanged({'gymAssign': false});
      return;
    }
    final s = PlanGenerator.suggestedGymWeeks(widget.profile, widget.templates);
    final days = _gymDays;
    widget.onChanged({
      'gymAssign': true,
      'gymPlanA': {
        for (final d in days)
          if (a.gymPlanA[d] ?? s.a[d] case final r?) d: r,
      },
      'gymPlanB': {
        for (final d in days)
          if (a.gymPlanB[d] ?? s.b[d] ?? s.a[d] case final r?) d: r,
      },
    });
  }

  void _suggest() {
    final s = PlanGenerator.suggestedGymWeeks(widget.profile, widget.templates);
    widget.onChanged({
      'gymPlanA': s.a,
      'gymPlanB': {...s.a, ...s.b},
    });
  }

  void _set(int day, String ref) {
    final key = _week == 'B' && a.gymAB ? 'gymPlanB' : 'gymPlanA';
    final map = {...(key == 'gymPlanB' ? a.gymPlanB : a.gymPlanA), day: ref};
    widget.onChanged({key: map});
  }

  Future<void> _pick(int day, String? current) async {
    final ref = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProgramPicker(programs: _programs, own: widget.templates, current: current, title: _dayName(day)),
    );
    if (ref != null) _set(day, ref);
  }

  /// Warnings for the current assignment (both weeks with A/B).
  List<String> _warnings(AppLocalizations l) {
    final out = <String>[];
    final days = _gymDays.toSet();
    final weeks = [a.gymPlanA, if (a.gymAB) a.gymPlanB];
    String? at(int w, int d) => days.contains(d) ? (weeks[w][d] ?? (w > 0 ? a.gymPlanA[d] : null)) : null;
    // The same program on consecutive days – also over the week boundary (Sunday → next Monday).
    final seen = <String>{};
    for (var w = 0; w < weeks.length; w++) {
      for (var d = 1; d <= 7; d++) {
        final nextW = d == 7 ? (w + 1) % weeks.length : w;
        final nextD = d == 7 ? 1 : d + 1;
        final x = at(w, d), y = at(nextW, nextD);
        if (x == null || x != y) continue;
        final name = _program(x)?.name;
        final pair = '${_dayName(d)}–${_dayName(nextD)}';
        if (name != null && seen.add('$name$pair')) out.add(l.gymAssignWarnRepeat(name, pair));
      }
    }
    // A leg-heavy program the day before the long session.
    final long = PlanGenerator.longDayOf(widget.profile);
    if (long != null) {
      final before = long == 1 ? 7 : long - 1;
      for (var w = 0; w < weeks.length; w++) {
        final t = _program(at(w, before));
        if (t != null && legHeavyProgram(t)) {
          final msg = l.gymAssignWarnLegs(t.name, _dayName(before));
          if (!out.contains(msg)) out.add(msg);
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final days = _gymDays;
    final showB = a.gymAB && _week == 'B';
    final map = showB ? a.gymPlanB : a.gymPlanA;
    final warnings = a.gymAssign ? _warnings(l) : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('gymAssign'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.gymAssignTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(l.gymAssignSub),
          value: a.gymAssign,
          onChanged: days.isEmpty ? null : _enable,
        ),
        if (a.gymAssign && days.isEmpty) Text(l.gymAssignNoDays, style: t.bodySmall),
        if (a.gymAssign && days.isNotEmpty) ...[
          SwitchListTile(
            key: const ValueKey('gymAB'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.gymAssignAB),
            subtitle: Text(l.gymAssignABSub),
            value: a.gymAB,
            onChanged: (v) {
              setState(() => _week = 'A');
              widget.onChanged({
                'gymAB': v,
                if (v && a.gymPlanB.isEmpty) 'gymPlanB': {...a.gymPlanA},
              });
            },
          ),
          if (a.gymAB) ...[
            const SizedBox(height: 4),
            Segments<String>(
              key: const ValueKey('gymWeek'),
              segments: [Seg('A', label: l.gymWeekA), Seg('B', label: l.gymWeekB)],
              value: _week,
              onChanged: (v) => setState(() => _week = v),
            ),
          ],
          const SizedBox(height: 8),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text(_dayName(d), style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(
                    child: _ProgramButton(
                      key: ValueKey('gymDay$d'),
                      program: _program(map[d] ?? (showB ? a.gymPlanA[d] : null)),
                      placeholder: l.gymAssignPick,
                      onTap: () => _pick(d, map[d]),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('gymSuggest'),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(l.gymAssignSuggest),
              onPressed: _suggest,
            ),
          ),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(child: Text(w, style: const TextStyle(color: AppColors.warning, fontSize: 12.5))),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// The program of one gym day (tap: [_ProgramPicker]).
class _ProgramButton extends StatelessWidget {
  const _ProgramButton({super.key, required this.program, required this.placeholder, required this.onTap});
  final WorkoutTemplate? program;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = program;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.fitness_center_rounded, size: 20, color: p == null ? scheme.outline : AppColors.gym),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.name ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p == null ? scheme.onSurfaceVariant : null),
                    ),
                    if (p != null && p.folder.isNotEmpty)
                      Text(p.folder, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable list of the gym programs, grouped by folder; pops the chosen program's reference
/// ([gymProgramRef]).
class _ProgramPicker extends StatefulWidget {
  const _ProgramPicker({required this.programs, required this.own, required this.current, required this.title});
  final List<WorkoutTemplate> programs;

  /// The athlete's programs (others are marked as built-in templates).
  final List<WorkoutTemplate> own;
  final String? current;
  final String title;

  @override
  State<_ProgramPicker> createState() => _ProgramPickerState();
}

class _ProgramPickerState extends State<_ProgramPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final hits = [
      for (final t in widget.programs)
        if (q.isEmpty || t.name.toLowerCase().contains(q) || t.folder.toLowerCase().contains(q)) t,
    ];
    // Grouped by folder, in the order the folders first appear.
    final folders = <String, List<WorkoutTemplate>>{};
    for (final t in hits) {
      folders.putIfAbsent(t.folder, () => []).add(t);
    }
    for (final list in folders.values) {
      list.sort((x, y) => x.order.compareTo(y.order));
    }
    final ownIds = {for (final t in widget.own) t.id};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${widget.title} · ${l.gymAssignPick}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('gymProgramSearch'),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.gymAssignSearch, isDense: true),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  hits.isEmpty
                      ? Center(child: Text(l.gymAssignNone))
                      : ListView(
                        children: [
                          for (final e in folders.entries) ...[
                            if (e.key.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(e.key, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.gym)),
                              ),
                            for (final t in e.value)
                              ListTile(
                                key: ValueKey('pick_${t.key ?? t.id}'),
                                title: Text(t.name),
                                subtitle: ownIds.contains(t.id) ? null : Text(l.gymAssignBuiltin),
                                trailing: widget.current == gymProgramRef(t) ? const Icon(Icons.check_rounded, color: AppColors.gym) : null,
                                onTap: () => Navigator.pop(context, gymProgramRef(t)),
                              ),
                          ],
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
