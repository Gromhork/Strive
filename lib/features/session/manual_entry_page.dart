import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/exercise_names_de.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/plan_fill.dart';
import '../../services/plan_match.dart';
import '../../services/session_checks.dart';
import '../stats/session_check_hint.dart';
import '../calendar/auto_adjust.dart';
import '../shell/health_sync.dart';
import '../../widgets/superset_group.dart';
import '../../widgets/common.dart';
import '../../widgets/discard_guard.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/rpe_picker.dart';
import '../../widgets/segments.dart';
import 'gym_session_page.dart' show setLabelOf;

/// Log a past activity (e.g. a treadmill run or a swim without the phone).
class ManualEntryPage extends ConsumerStatefulWidget {
  const ManualEntryPage({super.key, this.sport, this.plan});
  final Sport? sport;

  /// Planned workout done without recording ("Als erledigt eintragen"): the session takes
  /// over the plan's content ([PlanFill]) – gym: exercises, sets and the prescribed weights;
  /// endurance: duration, distance (laps in the pool) – and completes exactly this plan.
  final PlannedWorkout? plan;

  @override
  ConsumerState<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends ConsumerState<ManualEntryPage> {
  late final PlanFill? _fill =
      widget.plan == null
          ? null
          : PlanFill.of(
            widget.plan!,
            profile: ref.read(profileOrDefaultProvider),
            templates: ref.read(templateListProvider),
            prescriber: ref.read(loadPrescriberProvider),
          );
  late Sport _sport = widget.plan?.sport ?? widget.sport ?? ref.read(sportFilterProvider) ?? Sport.run;
  late DateTime _start = _initialStart();

  /// The duration's start: the plan's minutes in the field's 1–600 range (45 without a planned duration).
  late final int _planMinutes = ((_fill?.minutes ?? 0) > 0 ? _fill!.minutes : 45).clamp(1, 600);
  late int _minutes = _planMinutes;
  late final _title = TextEditingController(text: widget.plan?.title ?? '');
  late final String _planDistance = _initialDistance();
  late final _distance = TextEditingController(text: _planDistance);

  DateTime _initialStart() => manualEntryStart(now: DateTime.now(), minutes: _minutes, planDate: widget.plan?.date);

  /// The athlete picked the date / time: the start no longer follows the duration.
  bool _startPicked = false;

  String _initialDistance() {
    final km = _fill?.km;
    if (km == null || km <= 0) return '';
    if (widget.plan!.sport == Sport.swim) return '${(km * 1000).round()}';
    return Units.num(ref.read(profileOrDefaultProvider).units.distOut(km * 1000), 1);
  }

  /// The plan's content is used (same sport as planned).
  bool get _fromPlan => widget.plan != null && _sport == widget.plan!.sport;

  /// Gym exercises taken over from the plan (empty: only the total volume can be entered).
  List<GymExercise> get _planExercises => _fromPlan ? _fill!.exercises : const [];

  final _volume = TextEditingController();
  final _notes = TextEditingController();
  int? _rpe; // optional – null = not rated

  /// Entered values (for the unsaved-changes prompt on back).
  String _snapshot() =>
      [_sport.name, _start.millisecondsSinceEpoch, _minutes, _title.text, _distance.text, _volume.text, _notes.text, _rpe].join('\u0000');
  late final String _initial;

  @override
  void initState() {
    super.initState();
    _initial = _snapshot();
  }

  @override
  void dispose() {
    for (final c in [_title, _distance, _volume, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Entered distance in metres (null = empty / invalid).
  double? _distanceM() {
    final d = parseNum(_distance.text);
    if (d == null) return null;
    return _sport == Sport.swim ? d : ref.read(profileOrDefaultProvider).units.distIn(d);
  }

  void _save() {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final u = ref.read(profileOrDefaultProvider).units;
    final vol = parseNum(_volume.text);
    final title = _title.text.trim().isEmpty ? _sport.label(l) : _title.text.trim();
    final Session s;
    if (_fromPlan && (_sport != Sport.gym || _planExercises.isNotEmpty)) {
      s = sessionFromPlan(
        widget.plan!,
        _fill!,
        id: repo.newId(),
        start: _start,
        title: title,
        // Untouched fields keep the plan's exact values (not the rounded display) – unless the
        // plan has no duration: then the slider's value (never a 0-s session).
        minutes: _minutes == _planMinutes && _fill.minutes > 0 ? null : _minutes,
        distanceM: _distance.text == _planDistance ? null : (_distanceM() ?? 0),
        rpe: _rpe,
        notes: _notes.text.trim(),
        bodyWeightKg: ref.read(profileOrDefaultProvider).weightKg,
      );
    } else {
      s = Session(
        id: repo.newId(),
        sport: _sport,
        title: title,
        start: _start,
        durationSec: _minutes * 60,
        rpe: _rpe,
        notes: _notes.text.trim(),
        distanceM: _sport == Sport.gym ? 0 : (_distanceM() ?? 0),
        // Manual gym entries store the total volume as one summary "exercise".
        exercises:
            _sport == Sport.gym && vol != null && vol > 0
                ? [
                  GymExercise(exId: 'manual', name: l.totalVolume, sets: [GymSet(weight: u.weightIn(vol), reps: 1, done: true)]),
                ]
                : const [],
        indoor: true,
        planId: widget.plan?.id,
      );
    }
    repo.saveSession(s);
    ref.read(healthServiceProvider).writeSession(s);
    final plans = ref.read(planListProvider);
    // "Als erledigt eintragen" on a planned workout completes exactly that workout, whatever day it
    // was done (as the gym version always did) – no "count it as a replacement?" afterwards.
    // A free entry is matched like a recording.
    final plan = widget.plan != null ? plans.where((p) => p.id == widget.plan!.id).firstOrNull ?? widget.plan : matchPlan(s, plans);
    if (plan != null) repo.updatePlan(plan.id, {'status': 'done', 'sessionId': s.id});
    toast(context, l.saved);
    if (plan != null) {
      autoAdjustAfterSessions(
        repo: repo,
        l: l,
        profile: ref.read(profileOrDefaultProvider),
        plans: plans,
        sessions: ref.read(sessionListProvider),
        done: [(s, plan)],
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final gymFromPlan = _sport == Sport.gym && _planExercises.isNotEmpty;
    return DiscardGuard(
      isDirty: () => _snapshot() != _initial,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.plan == null ? l.logManually : l.logAsDone)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // A planned workout fixes the sport.
            if (widget.plan == null) ...[
              Segments<Sport>(
                segments: [for (final s in Sport.values) Seg(s, icon: s.icon)],
                value: _sport,
                onChanged: (v) => setState(() => _sport = v),
              ),
              const SizedBox(height: 16),
            ],
            TextField(controller: _title, decoration: InputDecoration(labelText: l.title, hintText: _sport.label(l))),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              // Start and end ("Di., 17. Nov. · 21:30–22:12"): a lone time read as "now" was an hour off (final QA: 21:12
              // shown at 22:12 – it was the start, an hour before, not a clock error).
              title: Text(manualEntryTimeText(context.localeName, _start, _minutes), key: const ValueKey('manualTime')),
              // A workout planned for a later day, logged today: still completes that workout.
              subtitle:
                  widget.plan != null && !sameDay(widget.plan!.date, _start)
                      ? Text(
                        l.logCompletesPlanOf(DateFormat.MMMEd(context.localeName).format(widget.plan!.date)),
                        key: const ValueKey('manualOtherDay'),
                      )
                      : null,
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2015), lastDate: DateTime.now());
                if (d == null || !context.mounted) return;
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start), helpText: l.startTime);
                setState(() {
                  _startPicked = true;
                  _start = DateTime(d.year, d.month, d.day, t?.hour ?? _start.hour, t?.minute ?? _start.minute);
                });
              },
            ),
            // The same duration input as everywhere else (no slider).
            DurationField(
              key: const ValueKey('manualDuration'),
              label: l.duration,
              value: _minutes * 60,
              units: DurationUnits.hm,
              min: 60,
              max: 10 * 3600,
              clearable: false,
              onChanged:
                  (v) => setState(() {
                    _minutes = ((v ?? _minutes * 60) / 60).round().clamp(1, 600);
                    // A workout just finished keeps ending now: a longer duration starts it earlier.
                    if (!_startPicked) _start = _initialStart();
                  }),
            ),
            const SizedBox(height: 12),
            if (_sport != Sport.gym) ...[
              TextField(
                key: const ValueKey('manualDistance'),
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.distance, suffixText: _sport == Sport.swim ? 'm' : u.distUnit),
                onChanged: (_) => setState(() {}),
              ),
              _CardioDerived(sport: _sport, distanceM: _distanceM() ?? 0, seconds: _minutes * 60, poolM: _fill?.poolLengthM, units: u),
              if (_fromPlan) _FromPlanHint(text: l.fromPlanHintCardio),
            ] else if (gymFromPlan)
              _GymFromPlan(exercises: _planExercises, units: u)
            else
              TextField(
                controller: _volume,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.totalVolume, suffixText: u.weightUnit),
              ),
            SessionCheckHint(
              check: SessionCheck.of(_sport, _start, _minutes * 60, _distanceM() ?? 0),
              sport: _sport,
              start: _start,
              durationSec: _minutes * 60,
              distanceM: _distanceM() ?? 0,
              units: u,
            ),
            const SizedBox(height: 16),
            Text(l.howHardOptional, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            RpePicker(value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
            const SizedBox(height: 8),
            TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(hintText: l.notesHint)),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('manualSave'),
              onPressed: SessionCheck.of(_sport, _start, _minutes * 60, _distanceM() ?? 0).endsInFuture ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ø 5:30 /km" (swim: "Ø 2:05 /100 m · 60 × 25 m") from the entered distance and duration.
class _CardioDerived extends StatelessWidget {
  const _CardioDerived({required this.sport, required this.distanceM, required this.seconds, required this.units, this.poolM});
  final Sport sport;
  final double distanceM;
  final int seconds;
  final int? poolM;
  final Units units;

  @override
  Widget build(BuildContext context) {
    if (distanceM <= 0 || seconds <= 0) return const SizedBox(height: 4);
    final l = context.l10n;
    final pool = poolM ?? 25;
    final laps = sport == Sport.swim && pool > 0 ? (distanceM / pool).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        [
          '${sport.usesPace ? l.avgPace : l.avgSpeed} ${units.paceOrSpeed(sport, distanceM, seconds)}',
          if (laps > 0) '${l.laps} $laps × $pool m',
        ].join(' · '),
        key: const ValueKey('manualDerived'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _FromPlanHint extends StatelessWidget {
  const _FromPlanHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.playlist_add_check_rounded, size: 18, color: AppColors.brand),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}

/// The exercises, sets and weights that will be stored, with the totals.
class _GymFromPlan extends StatelessWidget {
  const _GymFromPlan({required this.exercises, required this.units});
  final List<GymExercise> exercises;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final sets = exercises.fold<int>(0, (a, e) => a + e.doneSets);
    final volume = exercises.fold<double>(0, (a, e) => a + e.volume);
    return SectionCard(
      key: const ValueKey('gymFromPlan'),
      title: l.fromPlanTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.fromPlanGymLine(exercises.length, sets, units.volume(volume)),
            key: const ValueKey('gymFromPlanTotals'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...groupedExerciseWidgets(exercises, hint: false, info: false, bottomInset: 4, (i) {
            final e = exercises[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(exName(context, e.exId, e.name), style: t.bodyMedium)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      e.workSets.map((s) => setLabelOf(l, e, s, units)).join(', '),
                      textAlign: TextAlign.right,
                      style: t.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
          _FromPlanHint(text: l.fromPlanHintGym),
        ],
      ),
    );
  }
}

/// When a manually logged workout started: a past plan day at 18:00; today (and a workout planned for a later day – it
/// cannot have been done in the future) so that it ends now – [minutes] before the current minute. Absolute time
/// arithmetic (a [Duration] back from now), so the end is the current wall-clock time also on the night of a DST change.
DateTime manualEntryStart({required DateTime now, required int minutes, DateTime? planDate}) {
  if (planDate == null || sameDay(planDate, now) || planDate.isAfter(now)) {
    // (The current minute without building a DateTime from wall-clock fields – ambiguous in the repeated hour.)
    final end = now.subtract(Duration(seconds: now.second, milliseconds: now.millisecond, microseconds: now.microsecond));
    return end.subtract(Duration(minutes: minutes));
  }
  return DateTime(planDate.year, planDate.month, planDate.day, 18);
}

/// "Di., 17. Nov. 2026 · 21:30–22:12": the day, start and end of a logged workout ([minutes] after [start]).
String manualEntryTimeText(String locale, DateTime start, int minutes) {
  final end = start.add(Duration(minutes: minutes));
  final hm = DateFormat.Hm(locale);
  final day = DateFormat.yMMMEd(locale).format(start);
  return sameDay(start, end)
      ? '$day · ${hm.format(start)}–${hm.format(end)}'
      : '$day · ${hm.format(start)}–${DateFormat.E(locale).add_Hm().format(end)}';
}
