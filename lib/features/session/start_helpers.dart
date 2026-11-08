import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/active_workout.dart';
import '../../services/tracker.dart';
import '../../widgets/common.dart';
import 'cardio_session_page.dart';
import 'step_list.dart';
import 'gym_session_page.dart';
import 'manual_entry_page.dart';

/// Starts a planned workout from the calendar / home screen.
Future<void> startPlanned(BuildContext context, WidgetRef ref, PlannedWorkout p) async {
  final template = ref.read(templateListProvider).where((t) => t.id == p.templateId).firstOrNull;
  if (p.sport == Sport.gym) {
    await startGym(context, ref, title: p.title, template: template, planId: p.id);
  } else {
    await showCardioStart(context, ref, p.sport, title: p.title, planId: p.id, steps: p.steps);
  }
}

Future<void> startGym(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  WorkoutTemplate? template,
  String? planId,
}) async {
  if (!await _ensureNothingRunning(context, ref)) return;
  ref
      .read(activeGymProvider.notifier)
      .start(title: title, templateId: template?.id, planId: planId, exercises: template?.exercises ?? const []);
  if (context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const GymSessionPage()));
  }
}

Future<bool> _ensureNothingRunning(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  if (ref.read(activeGymProvider) != null || ref.read(trackerProvider) != null) {
    final ok = await confirm(context, l.workoutRunning, body: l.workoutRunningBody, ok: l.discardAndStart, danger: true);
    if (!ok) return false;
    ref.read(activeGymProvider.notifier).discard();
    ref.read(trackerProvider.notifier).discard();
  }
  return true;
}

/// Quick start for one sport (empty gym workout or cardio recording).
Future<void> quickStart(BuildContext context, WidgetRef ref, Sport s) async {
  final l = context.l10n;
  if (s == Sport.gym) {
    await startGym(context, ref, title: l.freeWorkout);
  } else {
    await showCardioStart(context, ref, s);
  }
}

/// Bottom sheet: choose what to start right now.
Future<void> showQuickStart(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  return showModalBottomSheet(
    context: context,
    builder:
        (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.startTraining, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final s in Sport.values)
                  ListTile(
                    leading: SportBadge(s),
                    title: Text(s.label(l)),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () {
                      Navigator.pop(c);
                      quickStart(context, ref, s);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(l.logManually),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryPage()));
                  },
                ),
              ],
            ),
          ),
        ),
  );
}

/// Choose outdoor (GPS) vs indoor, and pool length for swimming.
Future<void> showCardioStart(
  BuildContext context,
  WidgetRef ref,
  Sport sport, {
  String? title,
  String? planId,
  List<WorkoutStep> steps = const [],
}) async {
  if (!await _ensureNothingRunning(context, ref)) return;
  if (!context.mounted) return;
  final l = context.l10n;
  var indoor = sport == Sport.swim;
  var pool = 25;
  var guided = steps.isNotEmpty;
  final u = ref.read(profileOrDefaultProvider).units;
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder:
        (c) => StatefulBuilder(
          builder:
              (c, setS) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SportBadge(sport, size: 44, filled: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title ?? sport.label(l),
                              style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.gps_fixed),
                            label: Text(sport == Sport.swim ? l.openWater : l.outdoor),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(sport == Sport.swim ? Icons.pool : Icons.home_outlined),
                            label: Text(sport == Sport.swim ? l.pool : l.indoor),
                          ),
                        ],
                        selected: {indoor},
                        onSelectionChanged: (s) => setS(() => indoor = s.first),
                      ),
                      const SizedBox(height: 12),
                      if (sport == Sport.swim && indoor) ...[
                        Text(l.poolLength),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 25, label: Text('25 m')),
                            ButtonSegment(value: 33, label: Text('33 m')),
                            ButtonSegment(value: 50, label: Text('50 m')),
                          ],
                          selected: {pool},
                          onSelectionChanged: (s) => setS(() => pool = s.first),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        indoor ? (sport == Sport.swim ? l.poolHint : l.indoorHint) : l.gpsHint,
                        style: Theme.of(c).textTheme.bodySmall,
                      ),
                      if (steps.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: guided,
                          onChanged: (v) => setS(() => guided = v),
                          title: Text(l.guidedWorkout),
                          subtitle: Text(l.guidedWorkoutSub),
                        ),
                        if (guided)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: StepList(steps: steps, sport: sport, units: u, dense: true),
                          ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: sport.color, foregroundColor: Colors.black87),
                        onPressed: () => Navigator.pop(c, true),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l.start),
                      ),
                    ],
                  ),
                ),
              ),
        ),
  );
  if (go != true || !context.mounted) return;
  final err = await ref
      .read(trackerProvider.notifier)
      .start(
        sport: sport,
        title: title ?? sport.label(l),
        planId: planId,
        indoor: indoor,
        poolLengthM: pool,
        steps: guided ? steps : const [],
        l: l,
        lang: Localizations.localeOf(context).languageCode,
      );
  if (!context.mounted) return;
  if (err != null) {
    toast(context, err == 'service' ? l.gpsServiceOff : l.gpsPermissionDenied);
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => const CardioSessionPage()));
}
