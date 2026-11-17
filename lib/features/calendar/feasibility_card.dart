import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/event_distances.dart';
import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/fitness_state.dart';
import '../../services/plan_generator.dart';

/// Feasibility of the event goal ([PlanGenerator.feasibility]), cached per profile and
/// plan start – the check generates a few plans, so it must not run on every rebuild. The last few
/// profiles stay cached (audit eng-4): stepping a minute value up and back again, or the setup's two views
/// of the profile, never rerun a check.
class FeasibilityCache {
  static const _size = 8;
  final _values = <String, PlanFeasibility>{};
  final _notes = <String, LongRunCapNote?>{};

  static String _keyOf(UserProfile p, DateTime start, AppLocalizations l, [String extra = '']) =>
      '${p.toMap()}|${dayOnly(start)}|${l.localeName}|$extra';

  static V _memo<V>(Map<String, V> m, String key, V Function() compute) {
    if (m.containsKey(key)) {
      // Most recently used last.
      final v = m.remove(key) as V;
      return m[key] = v;
    }
    final v = compute();
    m[key] = v;
    if (m.length > _size) m.remove(m.keys.first);
    return v;
  }

  /// [onUpdate]: checks run in a background isolate and this is called when one is done (the page rebuilds) –
  /// an Ironman check with its option verification took ~1.7 s on an emulator (audit eng-4), every tap on the plan
  /// step froze the UI that long. Without it (or under test) the check runs synchronously.
  FeasibilityCache({this.onUpdate});
  final VoidCallback? onUpdate;

  /// The result shown last: shown again while the next check runs.
  PlanFeasibility? _last;
  final _running = <String>{};

  static bool get _underTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// [fitness]: the running plan's fitness model – mid-plan the target check uses the forecast's values.
  PlanFeasibility of(UserProfile p, DateTime start, AppLocalizations l, {FitnessState? fitness}) {
    final fk = fitness == null ? '' : '${fitness.current.toStringAsFixed(2)}/${fitness.futureFactor.toStringAsFixed(2)}/${fitness.today}';
    final key = _keyOf(p, start, l, fk);
    PlanFeasibility now() => PlanGenerator.feasibility(p, start: start, l: l, fitness: fitness);
    if (onUpdate == null || _underTest || _values.containsKey(key)) {
      final v = _memo(_values, key, now);
      _last = v;
      return v;
    }
    if (_running.add(key)) {
      _background(p, start, l.localeName, fitness).then(
        (v) {
          _running.remove(key);
          _memo(_values, key, () => v);
          onUpdate!();
        },
        // (Anything that cannot cross to the isolate: checked here after all.)
        onError: (Object _) {
          _running.remove(key);
          _memo(_values, key, now);
          onUpdate!();
        },
      );
    }
    return _last ?? const PlanFeasibility();
  }

  /// The check in an isolate – a function of its own, so the closure sent there holds only these values (not the
  /// page's state).
  static Future<PlanFeasibility> _background(UserProfile p, DateTime start, String locale, FitnessState? fitness) => Isolate.run(
    () => PlanGenerator.feasibility(p, start: start, l: lookupAppLocalizations(Locale(locale)), fitness: fitness),
    debugName: 'feasibility',
  );

  /// The long-run cap note alone ([PlanGenerator.longRunCapNote]) – cheap enough for every minute tap.
  LongRunCapNote? capNote(UserProfile p, DateTime start, AppLocalizations l) =>
      _memo(_notes, _keyOf(p, start, l), () => PlanGenerator.longRunCapNote(p, start: start, l: l));
}

/// What a tappable option of the [FeasibilityCard] changes – the plan settings apply it (audit UX-9: the options
/// were plain text, the athlete had to find each setting by hand).
sealed class FeasibilityAction {
  const FeasibilityAction();
}

/// Move the race to [date] (the first later date that is long enough).
class FeasLaterDate extends FeasibilityAction {
  const FeasLaterDate(this.date);
  final DateTime date;
}

/// Switch to the shorter race [distance].
class FeasShorter extends FeasibilityAction {
  const FeasShorter(this.distance);
  final String distance;
}

/// Set the time on these days (weekday → minutes).
class FeasDayMinutes extends FeasibilityAction {
  const FeasDayMinutes(this.minutes);
  final Map<int, int> minutes;
}

/// Put the long session on [weekday].
class FeasLongDay extends FeasibilityAction {
  const FeasLongDay(this.weekday);
  final int weekday;
}

/// Add training days of [sport] (the week step).
class FeasAddDay extends FeasibilityAction {
  const FeasAddDay(this.sport);
  final Sport sport;
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
    this.onAction,
    this.compact = false,
    this.onOpenSettings,
  });
  final PlanFeasibility f;

  /// Applies a tapped option ([FeasibilityAction]); without it the options are plain text.
  final ValueChanged<FeasibilityAction>? onAction;

  /// Only the title and the first issue, the rest in a sheet (the calendar: the full card took half the screen).
  final bool compact;

  /// "Change the plan settings" under the options (where the options cannot be applied right there).
  final VoidCallback? onOpenSettings;

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
    'longRunTime' =>
      f.timeUnresolved
          ? l.feasLongRunLayout((f.longRunKm ?? 0).floor(), (f.longRunTargetKm ?? 0).round())
          : l.feasLongRunTime((f.longRunKm ?? 0).floor(), (f.longRunTargetKm ?? 0).round()),
    'longRideTime' =>
      f.timeUnresolved
          ? l.feasLongRideLayout(f.longRideMin ?? 0, f.longRideTargetMin ?? 0)
          : l.feasLongRideTime(f.longRideMin ?? 0, f.longRideTargetMin ?? 0),
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
    final raise1 = f.raiseDay != null && f.raiseDayMin != null;
    final raise2 = raise1 && f.raiseDay2 != null && f.raiseDay2Min != null;
    final options = <(String, FeasibilityAction?)>[
      // Too few sessions of a sport: more such days first (the week step).
      for (final (issue, sport, label) in [
        ('runFrequency', Sport.run, l.feasAddRunDays),
        ('rideFrequency', Sport.ride, l.feasAddRideDays),
        ('swimFrequency', Sport.swim, l.feasAddSwimDays),
      ])
        if (issues.contains(issue)) (label, FeasAddDay(sport)),
      // The time on the long day is the limit: the concrete fix first (both days at once – checked together).
      if (raise2)
        (
          l.feasRaiseTwoDays(day(f.raiseDay!), _hm(f.raiseDayMin!), day(f.raiseDay2!), _hm(f.raiseDay2Min!)),
          FeasDayMinutes({f.raiseDay!: f.raiseDayMin!, f.raiseDay2!: f.raiseDay2Min!}),
        )
      else if (raise1)
        (l.feasRaiseDay(day(f.raiseDay!), _hm(f.raiseDayMin!)), FeasDayMinutes({f.raiseDay!: f.raiseDayMin!})),
      if (f.moveDay != null && f.moveDayMin != null) (l.feasMoveLongDay(day(f.moveDay!), _hm(f.moveDayMin!)), FeasLongDay(f.moveDay!)),
      if (f.laterDate != null) (l.feasLaterDate(df.format(f.laterDate!)), FeasLaterDate(f.laterDate!)),
      if (f.shorterDistance != null) (l.feasShorter(eventDistanceName(l, f.shorterDistance!)), FeasShorter(f.shorterDistance!)),
      if (f.runWalkFinish) (l.feasRunWalkFinish, null),
      if (targetIssue && onAdjustTarget == null) (l.feasTargetSuggest(clock(t.suggestedSec)), null),
      if (targetIssue && t.laterDate != null) (l.feasTargetLater(clock(t.targetSec), df.format(t.laterDate!)), null),
    ];
    // Notes only (the goal itself is fine): a neutral info look, not a warning (user report 2026-11: the
    // long-run cap note read as a warning that contradicted the time the athlete had set).
    final note = f.onlyNotes;
    final cap = f.capNote;
    // (Only where it does something: the plan with the extension has runs beyond the cap – or it is on and
    // can be taken back.)
    final extendMax = issues.contains('longRunTimeCap') && (cap?.showSwitch ?? false) ? cap?.extendMaxMin : null;
    final canSwitch = extendMax != null && onExtendLongRun != null;
    final title = f.onlyTarget ? l.feasTitleTarget : (f.onlyNotes ? l.feasTitleNote : l.feasTitle);
    if (compact) return _compact(context, title, issueText(l, f, issues.first, canSwitch: canSwitch), note);
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                // One block per issue (audit UX-9: several unrelated problems ran together as one wall of text).
                for (final i in issues)
                  Padding(
                    key: ValueKey('feasIssue-$i'),
                    padding: const EdgeInsets.only(top: 6),
                    child:
                        issues.length == 1
                            ? Text(issueText(l, f, i, canSwitch: canSwitch), style: const TextStyle(fontSize: 13))
                            : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, right: 8),
                                  child: Icon(Icons.circle, size: 6, color: AppColors.warning),
                                ),
                                Expanded(child: Text(issueText(l, f, i, canSwitch: canSwitch), style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                  ),
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
                  const SizedBox(height: 8),
                  Text(l.feasOptions, style: small?.copyWith(fontWeight: FontWeight.w600)),
                  for (final (text, action) in options)
                    if (action != null && onAction != null)
                      _OptionButton(text: text, onTap: () => onAction!(action))
                    else
                      Text('• $text', style: const TextStyle(fontSize: 13)),
                ],
                if (onOpenSettings != null && options.any((o) => o.$2 != null))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('feasOpenSettings'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(l.editPlanSettings),
                    ),
                  ),
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

  /// The calendar's one-glance version: title and the first issue in two lines; the whole card in a sheet.
  Widget _compact(BuildContext context, String title, String first, bool note) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('feasibility'),
      color: note ? scheme.surfaceContainerHighest : AppColors.warning.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('feasCompact'),
        borderRadius: BorderRadius.circular(16),
        onTap:
            () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder:
                  (ctx) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: FeasibilityCard(
                        f,
                        onAction: onAction,
                        onAdjustTarget: onAdjustTarget,
                        onOpenSettings:
                            onOpenSettings == null
                                ? null
                                : () {
                                  Navigator.pop(ctx);
                                  onOpenSettings!();
                                },
                      ),
                    ),
                  ),
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(first, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(l.feasShowDetails, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brand)),
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
        ),
      ),
    );
  }
}

/// A tappable option of the [FeasibilityCard] – the change it names is applied at once.
class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.brand),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brand))),
          ],
        ),
      ),
    ),
  );
}
