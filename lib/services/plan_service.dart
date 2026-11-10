import '../core/format.dart';
import '../data/default_programs.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../l10n/gen/app_localizations.dart';
import 'plan_gaps.dart';
import 'plan_generator.dart';

/// The one way to (re)generate the training plan – used by the setup, "align plan with
/// goal" and "start the plan over". Replaces the upcoming planned workouts from [start]
/// with a new plan in chunked batches, adds missing built-in programs and stores the plan
/// metadata (start / length) on the profile.
///
/// Guarded against double taps: while a replacement runs – and for [cooldown] after it, until
/// the plan stream shows the new plan (a second call would still see the old workouts and add
/// a second plan) – another call returns null.
class PlanService {
  PlanService._();

  static bool _busy = false;
  static DateTime? _last;

  /// Time after a replacement in which another one is refused.
  static const cooldown = Duration(seconds: 3);

  /// For tests.
  static void reset() {
    _busy = false;
    _last = null;
  }

  /// True while a plan is being replaced.
  static bool get busy => _busy || (_last != null && DateTime.now().difference(_last!) < cooldown);

  /// Returns the number of generated workouts, or null when another replacement is still
  /// running. [saveMeta] false: the profile is not written (no profile document yet).
  static Future<int?> replacePlan({
    required Repository repo,
    required AppLocalizations l,
    required UserProfile profile,
    required List<WorkoutTemplate> templates,
    required List<PlannedWorkout> existing,
    required DateTime start,
    required int weeks,
    bool saveMeta = true,
  }) async {
    if (busy) return null;
    _busy = true;
    try {
      final day = dayOnly(start);
      // The programs of the chosen split must exist (built-ins added on demand).
      final added = missingBuiltins(
        templates,
        repo.newId,
        de: l.localeName.startsWith('de'),
        only: PlanGenerator.gymKeysFor(profile).toSet(),
      );
      if (added.isNotEmpty) repo.saveTemplates(added);
      final plan = PlanGenerator(l, profile, [...templates, ...added], repo.newId).generate(start: day, weeks: weeks);
      // Written locally at once (offline persistence); the future is the server commit.
      final write = repo.replacePlans(existing, day, plan);
      // Plan start / length: lets the plan review rebuild the plan to find gaps.
      if (saveMeta) repo.saveProfile(withPlanMeta(profile, day, weeks));
      write.ignore();
      return plan.length;
    } finally {
      _busy = false;
      _last = DateTime.now();
    }
  }
}
