import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../providers.dart';
import '../../services/plan_generator.dart';
import 'feasibility_card.dart';

/// What the calendar shows of the plan's notes ([PlanFeasibility]).
enum PlanHintMode {
  /// Nothing to say.
  none,

  /// The compact card above the calendar.
  card,

  /// Only the "plan notes" entry in the ⋮ menu (marked with a dot) – the notes stay close at hand.
  entry,
}

/// Identity of a set of plan notes: the issues shown, the numbers they name (rounded so day-to-day drift of
/// the fitness model doesn't count) and the plan they belong to (its start). Dismissed notes come back only
/// when this changes – a new or different issue, other key numbers, a new plan.
String planHintSignature(PlanFeasibility f, DateTime planStart) {
  final issues = [...FeasibilityCard.shownIssues(f)]..sort();
  int? r(num? v, int step) => v == null ? null : (v / step).round();
  return [
    dayKey(planStart),
    issues.join(','),
    f.weeks,
    f.longRunKm?.floor(),
    f.longRunTargetKm?.round(),
    r(f.longRideMin, 15),
    r(f.longRideTargetMin, 15),
    r(f.longSwimM, 100),
    r(f.longSwimTargetM, 100),
    f.target?.targetSec,
    f.timeCapMin,
    f.setAsideTargetSec,
    f.shorterDistance,
  ].join('|');
}

/// Which plan notes the athlete closed (×) and which informational ones were already shown – kept per account
/// across restarts (owner round 9: the hint came back on every start).
typedef PlanHintState = ({String? dismissed, String? seen});

class PlanHintMemory extends Notifier<PlanHintState> {
  static const dismissedKey = 'planHintDismissed', seenKey = 'planHintSeen';

  /// Informational notes shown as a card in this app run: they stay a card until the next start (or ×).
  static final shownThisRun = <String>{};

  String _account = '';

  String _key(String base) => _account.isEmpty ? base : '$base/$_account';

  @override
  PlanHintState build() {
    try {
      _account = ref.watch(authProvider).value?.uid ?? '';
    } catch (_) {
      _account = '';
    }
    try {
      final p = ref.watch(prefsProvider);
      return (dismissed: p.getString(_key(dismissedKey)), seen: p.getString(_key(seenKey)));
    } catch (_) {
      return (dismissed: null, seen: null); // no preferences (tests)
    }
  }

  void dismiss(String signature) {
    state = (dismissed: signature, seen: state.seen);
    try {
      ref.read(prefsProvider).setString(_key(dismissedKey), signature);
    } catch (_) {}
  }

  /// An informational note was shown as a card: after the next start only the small entry remains. (The state is
  /// left alone – this run keeps the card, see [shownThisRun].)
  void markSeen(String signature) {
    shownThisRun.add(signature);
    try {
      ref.read(prefsProvider).setString(_key(seenKey), signature);
    } catch (_) {}
  }

  /// The card for new notes; once closed only the entry. Notes that are information only (the goal itself is
  /// fine) are shown as a card in one app run, then as the entry; problems stay a card until closed.
  static PlanHintMode mode(PlanFeasibility f, String signature, PlanHintState s, {Set<String>? shown}) {
    if (f.ok || FeasibilityCard.shownIssues(f).isEmpty) return PlanHintMode.none;
    if (s.dismissed == signature) return PlanHintMode.entry;
    if (f.onlyNotes && s.seen == signature && !(shown ?? shownThisRun).contains(signature)) return PlanHintMode.entry;
    return PlanHintMode.card;
  }
}

final planHintMemoryProvider = NotifierProvider<PlanHintMemory, PlanHintState>(PlanHintMemory.new);
