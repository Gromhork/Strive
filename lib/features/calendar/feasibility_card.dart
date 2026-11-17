import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/event_distances.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/fitness_state.dart';
import '../../services/plan_generator.dart';

/// Feasibility of the event goal ([PlanGenerator.feasibility]), cached per profile and
/// plan start – the check generates a few plans, so it must not run on every rebuild.
class FeasibilityCache {
  String? _key;
  PlanFeasibility _value = const PlanFeasibility();

  /// [fitness]: the running plan's fitness model – mid-plan the target check uses the forecast's values.
  PlanFeasibility of(UserProfile p, DateTime start, AppLocalizations l, {FitnessState? fitness}) {
    final fk = fitness == null ? '' : '${fitness.current.toStringAsFixed(2)}/${fitness.futureFactor.toStringAsFixed(2)}/${fitness.today}';
    final key = '${p.toMap()}|${dayOnly(start)}|${l.localeName}|$fk';
    if (key != _key) {
      _key = key;
      _value = PlanGenerator.feasibility(p, start: start, l: l, fitness: fitness);
    }
    return _value;
  }
}

/// Name of an event distance key (the shared catalogue, [eventDistanceLabel]).
String eventDistanceName(AppLocalizations l, String d) => eventDistanceLabel(l, d);

/// "3 h 45" / "90 min" for a minute value.
String _hm(int m) => formatMinutes(m);

/// Short warning when the event goal is not realistic in the time left, with what would
/// make it work (later date, shorter distance, run/walk). Nothing when the goal is fine.
class FeasibilityCard extends StatelessWidget {
  const FeasibilityCard(
    this.f, {
    super.key,
    this.planAnyway = false,
    this.onClose,
    this.onAdjustTarget,
    this.showTargetOk = false,
    this.onExtendLongRun,
  });
  final PlanFeasibility f;

  /// Switch "allow long runs up to …" inside the long-run cap note ([LongRunCapNote], where the athlete can
  /// opt in to the extension); without it the note says where to switch it on.
  final ValueChanged<bool>? onExtendLongRun;

  /// One tap "set target to the realistic time" (shown with a target-time issue).
  final ValueChanged<int>? onAdjustTarget;

  /// Also confirm a realistic target time (a small line instead of nothing).
  final bool showTargetOk;

  /// Adds "the plan is created anyway" (where a plan is about to be generated).
  final bool planAnyway;
  final VoidCallback? onClose;

  static String issueText(AppLocalizations l, PlanFeasibility f, String issue, {bool canSwitch = false}) => switch (issue) {
    'beginnerMarathon' => l.feasBeginnerMarathon,
    'beginnerDistance' => l.feasBeginnerDistance,
    'longSwim' => _longSwimText(l, f),
    'runWalkLong' => l.feasRunWalkLong,
    'runWalk' => l.feasRunWalk,
    'longRunTime' => l.feasLongRunTime((f.longRunKm ?? 0).floor(), (f.longRunTargetKm ?? 0).round()),
    'longRideTime' => l.feasLongRideTime(f.longRideMin ?? 0, f.longRideTargetMin ?? 0),
    'targetAmbitious' => l.feasTargetAmbitious(clock(f.target!.targetSec), clock(f.target!.currentSec), clock(f.target!.realisticSec)),
    'targetUnrealistic' => l.feasTargetUnrealistic(clock(f.target!.targetSec), clock(f.target!.currentSec), clock(f.target!.realisticSec)),
    // New issues (review 2026-11: long-day default, long-run share, conservative target) carry their own text.
    _ =>
      f.extraIssueText(l, issue, dayName: (d) => DateFormat.EEEE(l.localeName).format(DateTime(2024, 1, d)), canSwitch: canSwitch) ??
          l.feasTooShort(f.weeks ?? 0),
  };

  /// `longSwim`: open water with its safety rules; a triathlon's target as the plan's goal next to the leg (review
  /// 2026-11 T11); the day whose time cut the swim when that, not the weeks, is the limit (tri-7).
  static String _longSwimText(AppLocalizations l, PlanFeasibility f) {
    final have = (f.longSwimM ?? 0).round(), target = (f.longSwimTargetM ?? 0).round();
    final day =
        f.longSwimDay == null || f.longSwimDayMin == null ? null : DateFormat.EEEE(l.localeName).format(DateTime(2024, 1, f.longSwimDay!));
    final time = f.longSwimDayMin == null ? '' : _hm(f.longSwimDayMin!);
    if (f.openWater) {
      return [l.feasLongSwimOpen(have, target), if (day != null) l.feasLongSwimTime(day, have, target, time)].join(' ');
    }
    final leg = f.longSwimLegM;
    if (leg != null) {
      return day != null ? l.feasLongSwimTime2(day, have, target, '${leg.round()}', time) : l.feasLongSwim2(have, target, '${leg.round()}');
    }
    return day != null ? l.feasLongSwimTime(day, have, target, time) : l.feasLongSwim(have, target);
  }

  /// Issues worth showing: "the long ride only reaches 0 min" / "swimming only 0 m" means the
  /// week has no such session at all (e.g. checked with the wrong focus) – never shown as a
  /// limit of the athlete.
  static List<String> shownIssues(PlanFeasibility f) => [
    for (final i in f.issues)
      if (switch (i) {
        'longRideTime' => (f.longRideMin ?? 0) > 0,
        'longSwim' => (f.longSwimM ?? 0) > 0,
        'longRunTime' => (f.longRunKm ?? 0) >= 1,
        _ => true,
      })
        i,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = f.target;
    final issues = shownIssues(f);
    if (!f.ok && issues.isEmpty) return const SizedBox.shrink();
    if (f.ok) {
      if (!showTargetOk || t == null) return const SizedBox.shrink();
      return Row(
        key: const ValueKey('targetOk'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.feasTargetOkLine(clock(t.targetSec), clock(t.currentSec), clock(t.realisticSec)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      );
    }
    final small = Theme.of(context).textTheme.bodySmall;
    final df = DateFormat.yMMMd(context.localeName);
    final targetIssue = f.issues.any((i) => i.startsWith('target')) && t != null;
    String day(int d) => DateFormat.EEEE(context.localeName).format(DateTime(2024, 1, d)); // 1 Jan 2024 = Monday
    final options = [
      // The time on the long day is the limit: the concrete fix first.
      if (f.raiseDay != null && f.raiseDayMin != null) l.feasRaiseDay(day(f.raiseDay!), _hm(f.raiseDayMin!)),
      if (f.raiseDay2 != null && f.raiseDay2Min != null) l.feasRaiseDay(day(f.raiseDay2!), _hm(f.raiseDay2Min!)),
      if (f.moveDay != null && f.moveDayMin != null) l.feasMoveLongDay(day(f.moveDay!), _hm(f.moveDayMin!)),
      if (f.laterDate != null) l.feasLaterDate(df.format(f.laterDate!)),
      if (f.shorterDistance != null) l.feasShorter(eventDistanceName(l, f.shorterDistance!)),
      if (f.runWalkFinish) l.feasRunWalkFinish,
      if (targetIssue && onAdjustTarget == null) l.feasTargetSuggest(clock(t.suggestedSec)),
      if (targetIssue && t.laterDate != null) l.feasTargetLater(clock(t.targetSec), df.format(t.laterDate!)),
    ];
    // Notes only (the goal itself is fine): a neutral info look, not a warning (user report 2026-11: the
    // long-run cap note read as a warning that contradicted the time the athlete had set).
    final note = f.onlyNotes;
    final cap = f.capNote;
    // (Only where it does something: the plan with the extension has runs beyond the cap – or it is on and
    // can be taken back.)
    final extendMax = issues.contains('longRunTimeCap') && (cap?.showSwitch ?? false) ? cap?.extendMaxMin : null;
    final canSwitch = extendMax != null && onExtendLongRun != null;
    return Container(
      key: const ValueKey('feasibility'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: note ? Theme.of(context).colorScheme.surfaceContainerHighest : AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                note
                    ? const Icon(Icons.info_outline_rounded, key: ValueKey('feasNoteIcon'), color: AppColors.brand, size: 22)
                    : const Icon(Icons.warning_amber_rounded, key: ValueKey('feasWarnIcon'), color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.onlyTarget ? l.feasTitleTarget : (f.onlyNotes ? l.feasTitleNote : l.feasTitle),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                for (final i in issues) Text(issueText(l, f, i, canSwitch: canSwitch), style: const TextStyle(fontSize: 13)),
                if (canSwitch)
                  SwitchListTile(
                    key: const ValueKey('extendLongRun'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    value: cap!.extendOn,
                    onChanged: onExtendLongRun,
                    title: Text(l.longRunExtendSwitch(_hm(extendMax)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.feasOptions, style: small?.copyWith(fontWeight: FontWeight.w600)),
                  for (final o in options) Text('• $o', style: const TextStyle(fontSize: 13)),
                ],
                if (targetIssue && t.guessed) ...[const SizedBox(height: 4), Text(l.feasEstimated, style: small)],
                if (targetIssue && onAdjustTarget != null) ...[
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    key: const ValueKey('adjustTarget'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => onAdjustTarget!(t.suggestedSec),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text(l.adjustTargetTo(clock(t.suggestedSec))),
                  ),
                ],
                if (planAnyway) ...[const SizedBox(height: 6), Text(l.feasPlanAnyway, style: small)],
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
