import '../core/event_distances.dart';
import '../core/event_sport_x.dart';
import '../core/format.dart';
import '../core/sport.dart';
import '../data/models.dart';

/// Whether the saved race goal, the training focus and the plan's race (athlete data) fit
/// together. Older data can disagree – e.g. the goal "Hamburg Triathlon" while the focus is
/// still "Hybrid", the plan settings say "no race" and the plan has no cycling at all.
class GoalAlignment {
  const GoalAlignment({
    required this.goal,
    required this.raceKey,
    required this.focus,
    required this.neededFocus,
    required this.planAligned,
    this.missingSports = const [],
  });

  /// The next race goal.
  final Goal goal;

  /// Race distance of the goal (eventDistances key), null when unknown.
  final String? raceKey;

  /// Current training focus and the one the race needs (the same when it fits).
  final TrainingFocus focus;
  final TrainingFocus neededFocus;

  /// The plan settings (athlete data) point at this race (date and distance).
  final bool planAligned;

  /// Disciplines of the race the upcoming plan does not contain (e.g. no cycling).
  final List<Sport> missingSports;

  /// The race belongs to another sport than the focus (triathlon goal, hybrid focus).
  bool get focusWrong => neededFocus != focus;

  /// Anything to fix (shown as the "goal and plan don't match" card).
  bool get mismatch => focusWrong || !planAligned || missingSports.isNotEmpty;

  /// Signature of the mismatch – "later" hides the card until something changes.
  String get signature => '${goal.id}|${focus.name}|$planAligned|${missingSports.map((s) => s.name).join(',')}';

  /// Race distance key of an event goal: the stored preset, else a preset of exactly its km
  /// of the goal's race type.
  static String? keyOf(Goal g) {
    if (eventDistanceOf(g.eventKey) != null) return g.eventKey;
    final km = g.eventKm ?? g.target;
    if (km <= 0) return null;
    final hits = eventDistances.where((d) => (d.km - km).abs() < 0.06).toList();
    if (hits.isEmpty) return null;
    // A single hit or several (5 km run / 5 km open water): the goal's sport decides.
    final bySport = hits.where((d) => d.sport.sport == g.sport).toList();
    return (bySport.length == 1 ? bySport.first : (hits.length == 1 ? hits.first : null))?.key;
  }

  /// The next race goal (race day today or later) and how it fits; null without one.
  static GoalAlignment? of(UserProfile p, List<Goal> goals, List<PlannedWorkout> plans, DateTime today) {
    final list =
        goals.where((g) => g.type == GoalType.event && g.deadline != null && !dayOnly(g.deadline!).isBefore(today)).toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final g = list.firstOrNull;
    if (g == null) return null;
    final key = keyOf(g);
    final race = eventDistanceOf(key);
    final needed = key == null || eventFitsFocus(key, p.focus) ? p.focus : race!.sport.focus;
    final a = p.athlete;
    final aligned = a.eventDate != null && sameDay(a.eventDate!, g.deadline!) && (key == null || a.eventDistance == key);
    // Multisport race: every discipline should show up in the next two weeks of the plan.
    final upcoming = plans.where((w) => w.status != 'skipped' && !w.date.isBefore(today) && w.date.isBefore(addDays(today, 14)));
    final raceSports = switch (race?.sport) {
      EventSport.triathlon => const [Sport.swim, Sport.ride, Sport.run],
      EventSport.duathlon => const [Sport.run, Sport.ride],
      _ => const <Sport>[],
    };
    final missing =
        upcoming.isEmpty
            ? const <Sport>[]
            : [
              for (final s in raceSports)
                if (!upcoming.any((w) => w.sport == s)) s,
            ];
    return GoalAlignment(goal: g, raceKey: key, focus: p.focus, neededFocus: needed, planAligned: aligned, missingSports: missing);
  }

  /// Plain facts for the AI coach – so it neither calls a triathlon a "hybrid goal" nor invents
  /// reasons why the plan lacks a sport.
  String coachText({String lang = 'de'}) {
    if (!mismatch) return '';
    final adjust = lang == 'de' ? '"Anpassen"' : '"Adjust"';
    final parts = [
      'DATA MISMATCH (state it plainly, do not explain it away): the race goal "${goal.title}"'
          '${raceKey == null ? '' : ' ($raceKey)'} on ${dayKey(goal.deadline!)}',
      if (focusWrong) 'does not fit the training focus "${focus.name}" (it needs "${neededFocus.name}")',
      if (!planAligned) 'and the current plan was NOT built for this race',
      if (missingSports.isNotEmpty) 'and the next two weeks of the plan contain no ${missingSports.map((s) => s.name).join(' / ')} at all',
    ];
    return '${parts.join(' ')}. Never invent a reason for this (e.g. "we add cycling later") - the plan is simply not aligned yet. '
        'Recommend the $adjust button of the "goal and plan don\'t match" card (Home or Goals): it '
        '${focusWrong ? 'switches the focus to "${neededFocus.name}" and ' : ''}rebuilds the plan up to race day.';
  }
}
