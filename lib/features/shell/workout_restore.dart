import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/active_workout.dart';
import '../../services/tracker.dart';
import '../../services/workout_store.dart';
import '../../widgets/common.dart';
import '../session/cardio_session_page.dart';
import '../session/gym_session_page.dart';
import '../session/session_summary_page.dart';

/// Whether this app run already looked for a workout left over from a killed process
/// (a plain flag: nothing rebuilds on it).
class _RestoreChecked {
  bool done = false;
}

final _restoreCheckedProvider = Provider<_RestoreChecked>((ref) => _RestoreChecked());

/// Wraps the main shell: once per app run it looks for a workout (or an unsaved summary)
/// that was in progress when Android killed the app and offers to continue it. Until the
/// user decided, autosave stays off so the stored workout is not overwritten.
class WorkoutRestoreGate extends ConsumerStatefulWidget {
  const WorkoutRestoreGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WorkoutRestoreGate> createState() => _WorkoutRestoreGateState();
}

class _WorkoutRestoreGateState extends ConsumerState<WorkoutRestoreGate> {
  @override
  void initState() {
    super.initState();
    final checked = ref.read(_restoreCheckedProvider);
    if (checked.done) {
      ref.read(workoutAutosaveProvider).enable();
      return;
    }
    checked.done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final autosave = ref.read(workoutAutosaveProvider);
    final store = ref.read(workoutStoreProvider);
    try {
      final summary = await store.loadSummary();
      if (summary != null && mounted) await _offerSummary(store, summary);
      // A workout started meanwhile (e.g. from a notification) wins over the stored one.
      final running = ref.read(activeGymProvider) != null || ref.read(trackerProvider) != null;
      final saved = running ? null : await store.loadActive();
      if (saved != null && mounted) await _offerWorkout(store, saved);
    } finally {
      autosave.enable();
    }
  }

  Future<void> _offerSummary(WorkoutStore store, Session draft) async {
    final l = context.l10n;
    final when = DateFormat.Hm(context.localeName).format(draft.start);
    final open = await _ask(
      title: l.restoreSummaryTitle,
      body: l.restoreSummaryBody(draft.title, _day(draft.start), when),
      sport: draft.sport,
      resume: l.restoreSummaryOpen,
    );
    if (!mounted) return;
    if (open == true) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: draft, restored: true)));
    } else if (open == false) {
      await store.clearSummary();
    }
  }

  Future<void> _offerWorkout(WorkoutStore store, SavedWorkout saved) async {
    final l = context.l10n;
    final when = DateFormat.Hm(context.localeName).format(saved.start);
    final resume = await _ask(
      title: l.restoreWorkoutTitle,
      body: l.restoreWorkoutBody(saved.title, _day(saved.start), when),
      sport: saved.sport,
      resume: l.restoreWorkoutResume,
    );
    if (!mounted) return;
    if (resume == true) {
      final gym = saved.gym;
      if (gym != null) {
        ref.read(activeGymProvider.notifier).restore(gym);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GymSessionPage()));
      } else {
        final err = await ref
            .read(trackerProvider.notifier)
            .restore(saved.cardio!, l: l, lang: Localizations.localeOf(context).languageCode, savedAt: saved.savedAt);
        if (!mounted) return;
        if (err != null) toast(context, err == 'service' ? l.gpsServiceOff : l.gpsPermissionDenied);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CardioSessionPage()));
      }
    } else if (resume == false) {
      await store.clearActive();
    }
  }

  /// "today" / "yesterday" / date of the start.
  String _day(DateTime d) {
    final l = context.l10n;
    final now = DateTime.now();
    if (sameDay(d, now)) return l.restoreToday;
    if (sameDay(d, DateTime(now.year, now.month, now.day - 1))) return l.restoreYesterday;
    return DateFormat.MMMd(context.localeName).format(d);
  }

  /// true = continue, false = discard. Back does not dismiss the question – a dismissed
  /// workout would hang in limbo (not running, not offered again until the next start).
  Future<bool?> _ask({required String title, required String body, required Sport sport, required String resume}) {
    final l = context.l10n;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (c) => PopScope(
            canPop: false,
            child: AlertDialog(
              key: const ValueKey('restoreDialog'),
              icon: Icon(sport.icon, color: sport.color),
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  key: const ValueKey('restoreDiscard'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l.discard),
                ),
                FilledButton(key: const ValueKey('restoreResume'), onPressed: () => Navigator.pop(c, true), child: Text(resume)),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
