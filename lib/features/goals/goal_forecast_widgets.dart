import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/goal_forecast.dart';
import '../../services/progression_check.dart';
import '../../core/event_distances.dart' show raceLabel;

/// Goal forecast of the signed-in athlete (null without an upcoming event).
final goalForecastProvider = Provider<GoalForecast?>((ref) {
  // Recomputed at midnight / on resume (days left, missed workouts).
  ref.watch(todayProvider);
  return GoalForecast.of(
    ref.watch(profileOrDefaultProvider),
    plans: ref.watch(planListProvider),
    sessions: ref.watch(sessionListProvider),
    now: DateTime.now(),
  );
});

/// Sets a new target time: profile + the race-pace work of the upcoming peak weeks and the race.
void applyTargetTime(BuildContext context, WidgetRef ref, int sec) {
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  final p = ref.read(profileOrDefaultProvider);
  final updates = GoalForecast.retarget(
    p,
    ref.read(planListProvider),
    sec,
    now: DateTime.now(),
    sessions: ref.read(sessionListProvider),
    l: context.l10n,
  );
  if (updates.isNotEmpty) repo.updateMany(plans: updates);
  repo.saveProfile(p.copyWith(athlete: p.athlete.merge({'targetTimeSec': sec})));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.targetAdjusted(clock(sec)))));
}

/// Beginner progression findings (what fell behind, then what to do) – empty when the
/// build-up is on track or the check doesn't apply.
List<String> progressionLines(AppLocalizations l, GoalForecast f) {
  final c = f.progression;
  if (c == null || !c.behind) return const [];
  return [
    for (final i in c.issues)
      switch (i) {
        ProgressionIssue.longSessionsShort => l.progLongShort(((c.longAchievedShare ?? 0) * 100).round()),
        ProgressionIssue.longSessionsMissed => l.progLongMissed,
        ProgressionIssue.runWalkNotAchieved => l.progRunWalkNotAchieved,
        ProgressionIssue.highEffort => l.progHighEffort,
        ProgressionIssue.stageHeld => c.atRisk ? l.progStageHeldRisk(c.heldWeeks) : l.progStageHeld(c.heldWeeks),
      },
    for (final o in c.options)
      '→ ${switch (o) {
        ProgressionOption.repeatWeek => l.progOptRepeatWeek,
        ProgressionOption.laterRace => l.progOptLaterRace,
        ProgressionOption.shorterDistance => l.progOptShorter,
        ProgressionOption.runWalkRace => l.progOptRunWalkRace,
      }}',
  ];
}

/// Why the forecast is still "too early": before the first workout of the plan the general text,
/// after one the number still missing – never "after your first workouts" once some are done.
String forecastEarlyText(AppLocalizations l, GoalForecast f) {
  const needed = 2; // GoalForecast.early: fewer than 2 done endurance sessions since the plan start
  if (f.planStart == null || f.doneSessions <= 0) return l.fcEarlySub;
  return l.fcEarlyMore(max(1, needed - f.doneSessions));
}

/// Colour, icon and label of a forecast status.
(Color, IconData, String) forecastStyle(AppLocalizations l, GoalForecast f) {
  if (f.early) return (AppColors.brand, Icons.hourglass_top_rounded, l.fcEarly);
  return switch (f.status) {
    ForecastStatus.ahead => (AppColors.success, Icons.rocket_launch_rounded, l.fcAhead),
    ForecastStatus.onTrack => (AppColors.success, Icons.check_circle_rounded, l.fcOnTrack),
    ForecastStatus.slightlyBehind => (AppColors.warning, Icons.trending_down_rounded, l.fcSlightlyBehind),
    ForecastStatus.atRisk => (AppColors.danger, Icons.warning_amber_rounded, l.fcAtRisk),
  };
}

String forecastReasonText(AppLocalizations l, GoalForecast f, ForecastReason r) => switch (r) {
  ForecastReason.missedTraining => l.fcReasonMissed(((f.adherence ?? 0) * 100).round()),
  ForecastReason.slowerThanPlanned => l.fcReasonSlower,
  ForecastReason.fasterThanPlanned => l.fcReasonFaster,
  ForecastReason.longRunBehind => l.fcReasonLongRun,
  ForecastReason.trainingBreak => l.fcReasonBreak,
  ForecastReason.fatigue => l.fcReasonFatigue,
  ForecastReason.sessionsSkipped => l.fcReasonSessionsSkipped(f.sessionsDone, f.sessionsDue),
  ForecastReason.keySessionsMissed => l.fcReasonKeyMissed(f.keysDone, f.keysDue),
};

String phaseShort(AppLocalizations l, String phase) => switch (phase) {
  'build' => l.goalPhaseBuildShort,
  'peak' => l.goalPhasePeakShort,
  'taper' => l.goalPhaseTaperShort,
  _ => l.goalPhaseBaseShort,
};

Color phaseColor(String phase) => switch (phase) {
  'build' => AppColors.ride,
  'peak' => AppColors.gym,
  'taper' => AppColors.run,
  _ => AppColors.swim,
};

/// "+1:23" / "−0:45" (forecast minus target).
String deltaText(int sec) => '${sec > 0 ? '+' : (sec < 0 ? '−' : '±')}${clock(sec.abs())}';

String countdownText(AppLocalizations l, int daysLeft) =>
    daysLeft <= 0 ? l.goalCountdownToday : (daysLeft < 14 ? l.goalCountdownDays(daysLeft) : l.goalCountdown(daysLeft ~/ 7, daysLeft % 7));

/// The race as the athlete named it, with its distance ([raceLabel]: "Berlin · Marathon").
String eventLabel(AppLocalizations l, String event, {String? name}) => raceLabel(l, event, name: name);

/// Weeks of the plan by phase, from the stored planned workouts: each week takes the phase of
/// most of its workouts (recovery weeks belong to the phase around them).
List<(String, int)> phaseSegments(List<PlannedWorkout> plans, DateTime planStart, DateTime race) {
  final first = startOfWeek(planStart);
  final n = ((startOfWeek(race).difference(first).inHours / 24).round() ~/ 7) + 1;
  final weeks = List<String?>.filled(max(1, n), null);
  final counts = List.generate(weeks.length, (_) => <String, int>{});
  for (final p in plans) {
    final ph = p.phase;
    if (ph == null || ph == 'recovery' || p.date.isBefore(first) || dayOnly(p.date).isAfter(race)) continue;
    final i = (startOfWeek(p.date).difference(first).inHours / 24).round() ~/ 7;
    if (i < 0 || i >= weeks.length) continue;
    counts[i].update(ph, (v) => v + 1, ifAbsent: () => 1);
  }
  for (var i = 0; i < weeks.length; i++) {
    if (counts[i].isNotEmpty) weeks[i] = (counts[i].entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }
  // Weeks without phased workouts (recovery only, or gaps) take the previous phase.
  for (var i = 0; i < weeks.length; i++) {
    weeks[i] ??= i > 0 ? weeks[i - 1] : (weeks.firstWhere((w) => w != null, orElse: () => 'base'));
  }
  final out = <(String, int)>[];
  for (final w in weeks) {
    if (out.isNotEmpty && out.last.$1 == w) {
      out[out.length - 1] = (w!, out.last.$2 + 1);
    } else {
      out.add((w!, 1));
    }
  }
  return out;
}

/// The next event goal (race day today or later, earliest first), null without one.
Goal? activeEventGoal(List<Goal> goals, DateTime today) {
  final list =
      goals.where((g) => g.type == GoalType.event && g.deadline != null && !dayOnly(g.deadline!).isBefore(today)).toList()
        ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  return list.firstOrNull;
}

/// Where the plan stands on the way to an event: days left, the current phase and the
/// training week of the plan ("Woche 2/13"). Phase and weeks are null without a plan
/// leading to the race.
class EventProgress {
  const EventProgress({required this.daysLeft, this.phase, this.week, this.weeks});
  final int daysLeft;
  final String? phase;
  final int? week;
  final int? weeks;

  /// [planForRace] false: the plan is not built for this race (plan settings without it, another
  /// race) – only the countdown; the phases and weeks of an unrelated plan would read as its.
  static EventProgress of(DateTime race, List<PlannedWorkout> plans, DateTime today, {bool planForRace = true}) {
    final r = dayOnly(race);
    final left = daysBetween(today, r);
    if (!planForRace) return EventProgress(daysLeft: left);
    final earliest = addDays(r, -(7 * 30));
    DateTime? start;
    for (final p in plans) {
      if (p.phase == null || p.date.isAfter(r) || p.date.isBefore(earliest)) continue;
      if (start == null || p.date.isBefore(start)) start = p.date;
    }
    if (start == null || today.isBefore(startOfWeek(start))) return EventProgress(daysLeft: left);
    final segments = phaseSegments(plans, start, r);
    final weeks = segments.fold<int>(0, (a, s) => a + s.$2);
    final week = (daysBetween(startOfWeek(start), startOfWeek(today)) ~/ 7) + 1;
    var i = week - 1;
    String? phase;
    for (final s in segments) {
      if (i < s.$2) {
        phase = s.$1;
        break;
      }
      i -= s.$2;
    }
    return EventProgress(daysLeft: left, phase: phase, week: week.clamp(1, max(1, weeks)), weeks: weeks);
  }
}

/// Whether the plan settings ([AthleteData.eventDate]) point at race goal [g] – only then the plan's
/// phases and weeks belong to it.
bool planBuiltFor(UserProfile p, Goal g) => p.athlete.eventDate != null && g.deadline != null && sameDay(p.athlete.eventDate!, g.deadline!);

/// Long phase name ("Grundlagenphase").
String phaseLong(AppLocalizations l, String phase) => switch (phase) {
  'build' => l.phaseBuild,
  'peak' => l.phasePeak,
  'taper' => l.phaseTaper,
  'recovery' => l.phaseRecovery,
  _ => l.phaseBase,
};

/// "noch 88 Tage · Grundlagenphase (Woche 2/13)" – the countdown plus the plan's phase and
/// week instead of a bare percentage.
String eventProgressText(AppLocalizations l, EventProgress e) {
  final days = e.daysLeft == 0 ? l.raceToday : l.daysLeftInline(e.daysLeft);
  if (e.phase == null || e.week == null || e.weeks == null) return days;
  return '$days · ${l.phaseWeekOf(phaseLong(l, e.phase!), e.week!, e.weeks!)}';
}

/// One line on Home right below today's workout: "Hamburg Triathlon · noch 88 Tage ·
/// Grundlagenphase (Woche 2/13)". Taps open the goal status (or the goals).
class EventGoalLine extends ConsumerWidget {
  const EventGoalLine({super.key, required this.onTap});
  final void Function(Goal goal) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final g = activeEventGoal(ref.watch(goalsProvider).value ?? const [], today);
    if (g == null) return const SizedBox.shrink();
    final e = EventProgress.of(
      g.deadline!,
      ref.watch(planListProvider),
      today,
      planForRace: planBuiltFor(ref.watch(profileOrDefaultProvider), g),
    );
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey('eventGoalLine'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(g),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: g.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' · ${eventProgressText(l, e)}'),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Base → build → peak → taper bar with a marker at [position] (0…1).
class PhaseTimeline extends StatelessWidget {
  const PhaseTimeline({super.key, required this.segments, required this.position, this.height = 10, this.labels = true});
  final List<(String, int)> segments;
  final double position;
  final double height;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final total = segments.fold<int>(0, (x, s) => x + s.$2);
    if (total == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final x = (position.clamp(0.0, 1.0) * c.maxWidth).clamp(5.0, max(5.0, c.maxWidth - 5));
        const labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600);
        // A phase label only where it fits whole (audit UX-12: "Spitz" / "Taper" clipped side by side, also
        // at a larger font scale) – measured, never cut off.
        bool fits(String text, int weeks) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final ok = tp.width <= c.maxWidth * weeks / total - 2;
          tp.dispose();
          return ok;
        }

        final allFit = segments.every((s) => fits(phaseShort(l, s.$1), s.$2));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: height + 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(height),
                      child: Row(
                        children: [
                          for (final (i, s) in segments.indexed)
                            Expanded(
                              flex: s.$2,
                              child: Container(
                                margin: EdgeInsets.only(right: i == segments.length - 1 ? 0 : 2),
                                color: phaseColor(s.$1).withValues(alpha: 0.85),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: x - 5,
                    top: 0,
                    child: Container(
                      key: const ValueKey('timelineMarker'),
                      width: 10,
                      height: height + 8,
                      decoration: BoxDecoration(
                        color: scheme.onSurface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Every phase is named (final QA: "Tapering" was missing under the 70.3 bar – the short last phase had no
            // room): under its segment when all labels fit whole, else as a legend of coloured dots in one wrapping
            // line – never a phase without its name, never a clipped one.
            if (labels && allFit) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final s in segments)
                    Expanded(
                      flex: s.$2,
                      child: Text(
                        phaseShort(l, s.$1),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: labelStyle.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ] else if (labels) ...[
              const SizedBox(height: 6),
              Wrap(
                key: const ValueKey('phaseLegend'),
                spacing: 12,
                runSpacing: 2,
                children: [
                  for (final ph in {for (final s in segments) s.$1})
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: phaseColor(ph).withValues(alpha: 0.85), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(phaseShort(l, ph), style: labelStyle.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Small coloured status pill.
class ForecastChip extends StatelessWidget {
  const ForecastChip(this.f, {super.key});
  final GoalForecast f;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = forecastStyle(context.l10n, f);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Forecast vs. target as two values with the delta (or "finish" without a target).
class ForecastTimes extends StatelessWidget {
  const ForecastTimes(this.f, {super.key, this.large = false});
  final GoalForecast f;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final (color, _, _) = forecastStyle(l, f);
    final valueStyle = (large ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)?.copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(String label, String value, {Color? c, String? sub}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: valueStyle?.copyWith(color: c)),
          ),
          if (sub != null)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: c ?? theme.colorScheme.outline),
            ),
        ],
      ),
    );
    final race = f.raceDaySec;
    final target = f.targetSec;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          l.goalForecast,
          race == null ? '–' : '~${clock(race)}',
          c: f.early ? null : color,
          sub: f.nowSec == null ? null : '${l.goalToday} ~${clock(f.nowSec!)}',
        ),
        const SizedBox(width: 12),
        cell(
          l.goalTargetLabel,
          target == null ? l.goalFinish : clock(target),
          // A target the finish-only plan does not race at: shown, not dropped ("3:27:00 ohne Renntempo").
          sub:
              f.setAsideTargetSec != null
                  ? l.goalTargetSetAsideSub(clock(f.setAsideTargetSec!))
                  : (target == null || race == null || f.early ? null : deltaText(race - target)),
          c: null,
        ),
      ],
    );
  }
}

/// Compact forecast box (recalibration sheet): status, times, reasons, adjust-target action.
class ForecastSummary extends StatelessWidget {
  const ForecastSummary(this.f, {super.key, this.onAdjustTarget});
  final GoalForecast f;
  final ValueChanged<int>? onAdjustTarget;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (color, _, _) = forecastStyle(l, f);
    return Container(
      key: const ValueKey('forecastSummary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.fcInRecal} · ${eventLabel(l, f.event, name: f.eventName)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              ForecastChip(f),
            ],
          ),
          const SizedBox(height: 8),
          ForecastTimes(f),
          for (final r in f.reasons) ...[
            const SizedBox(height: 4),
            Text('• ${forecastReasonText(l, f, r)}', style: const TextStyle(fontSize: 12)),
          ],
          for (final line in progressionLines(l, f)) ...[
            const SizedBox(height: 4),
            Text(line.startsWith('→') ? line : '• $line', style: const TextStyle(fontSize: 12)),
          ],
          if (f.suggestedSec != null && onAdjustTarget != null && !f.early && f.status != ForecastStatus.onTrack) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: const ValueKey('forecastAdjust'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => onAdjustTarget!(f.suggestedSec!),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text(l.adjustTargetTo(clock(f.suggestedSec!))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
