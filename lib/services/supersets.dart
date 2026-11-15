import '../data/models.dart';
import 'exercise_class.dart';

/// Supersets are stored as a group letter on each [GymExercise]. Only *adjacent*
/// exercises with the same letter form a superset, and a superset has 2–3 members.
/// Older data can violate this (letters shared by non-adjacent exercises, long linked
/// chains); [normalizeSupersets] repairs such lists.
const maxSupersetSize = 3;

/// Rest between the members of a superset (A1 → A2): just long enough to change
/// stations. The full rest follows after the last member of the round.
const supersetTransitionSec = 20;

/// Indices of the superset that exercise [i] belongs to (adjacent members with the same
/// letter), or just `[i]`.
List<int> supersetOf(List<GymExercise> ex, int i) {
  if (i < 0 || i >= ex.length) return [i];
  final g = ex[i].group;
  if (g == null) return [i];
  var a = i, b = i;
  while (a > 0 && ex[a - 1].group == g) {
    a--;
  }
  while (b + 1 < ex.length && ex[b + 1].group == g) {
    b++;
  }
  if (a == b) return [i];
  return [for (var k = a; k <= b; k++) k];
}

/// Repairs superset data in place and returns true when something changed:
/// * a letter only links adjacent exercises (non-adjacent namesakes are separate),
/// * single "supersets" are dissolved,
/// * chains longer than [maxSupersetSize] are split into sensible pairs
///   ([goodSupersetPair]); exercises without a good partner become straight sets,
/// * letters are re-assigned A, B, C … in order.
bool normalizeSupersets(List<GymExercise> ex) {
  final before = [for (final e in ex) e.group];
  final out = List<String?>.filled(ex.length, null);
  var letter = 0;
  String next() => letter < 26 ? String.fromCharCode(65 + letter++) : 'Z';
  var i = 0;
  while (i < ex.length) {
    final g = ex[i].group;
    if (g == null) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < ex.length && ex[j + 1].group == g) {
      j++;
    }
    final len = j - i + 1;
    if (len >= 2 && len <= maxSupersetSize) {
      final l = next();
      for (var k = i; k <= j; k++) {
        out[k] = l;
      }
    } else if (len > maxSupersetSize) {
      var k = i;
      while (k <= j) {
        if (k + 1 <= j && goodSupersetPair(classifyLift(ex[k].exId, ex[k].name), classifyLift(ex[k + 1].exId, ex[k + 1].name))) {
          final l = next();
          out[k] = l;
          out[k + 1] = l;
          k += 2;
        } else {
          k++;
        }
      }
    }
    i = j + 1;
  }
  var changed = false;
  for (var k = 0; k < ex.length; k++) {
    ex[k].group = out[k];
    if (before[k] != out[k]) changed = true;
  }
  return changed;
}

/// Whether exercises [i] and [i] + 1 can be linked without exceeding [maxSupersetSize].
bool canLinkSuperset(List<GymExercise> ex, int i) {
  if (i < 0 || i + 1 >= ex.length) return false;
  final a = supersetOf(ex, i), b = supersetOf(ex, i + 1);
  if (a.contains(i + 1)) return true; // already linked
  return a.length + b.length <= maxSupersetSize;
}

/// Links exercise [i] with the next one (merging their supersets). Returns false when
/// the result would be longer than [maxSupersetSize] (nothing changes then).
bool linkSuperset(List<GymExercise> ex, int i) {
  if (!canLinkSuperset(ex, i)) return false;
  final a = supersetOf(ex, i), b = supersetOf(ex, i + 1);
  const tmp = '\u0000';
  for (final k in [...a, ...b]) {
    ex[k].group = tmp;
  }
  normalizeSupersets(ex);
  return true;
}

/// Breaks the link between exercise [i] and [i] + 1.
void unlinkSuperset(List<GymExercise> ex, int i) {
  if (i < 0 || i + 1 >= ex.length) return;
  final run = supersetOf(ex, i);
  if (!run.contains(i + 1)) return;
  const tmp = '\u0001';
  for (final k in run.where((k) => k > i)) {
    ex[k].group = tmp;
  }
  normalizeSupersets(ex);
}

/// Removes exercise [i] from its superset (the remaining members stay linked only if
/// they are still adjacent and at least two).
void leaveSuperset(List<GymExercise> ex, int i) {
  final run = supersetOf(ex, i);
  if (run.length < 2) {
    ex[i].group = null;
    return;
  }
  const tmp = '\u0001';
  for (final k in run.where((k) => k > i)) {
    ex[k].group = tmp;
  }
  ex[i].group = null;
  normalizeSupersets(ex);
}

/// Removes the whole superset that exercise [i] belongs to (all members become straight sets).
void dissolveSuperset(List<GymExercise> ex, int i) {
  if (i < 0 || i >= ex.length) return;
  for (final k in supersetOf(ex, i)) {
    ex[k].group = null;
  }
  normalizeSupersets(ex);
}

/// One display block of an exercise list: a single exercise ([letter] == null) or a run of
/// adjacent exercises that share a group letter (a superset; four and more = a circuit).
class ExerciseBlock {
  const ExerciseBlock(this.start, this.end, this.letter);

  /// First and last index (inclusive) in the exercise list.
  final int start, end;

  /// Display letter A, B, C … in order of appearance; null for a single exercise.
  final String? letter;

  int get length => end - start + 1;
  bool get grouped => letter != null;
  Iterable<int> get indices => Iterable.generate(length, (k) => start + k);
}

/// Splits [ex] into the blocks every list of a workout's exercises shows. Works on data that
/// was never normalised (stored sessions, old programs): a letter only links *adjacent*
/// exercises, so a superset whose members are separated by another exercise falls apart into
/// straight sets (or two smaller groups) instead of framing the stranger in between, and the
/// groups are lettered A, B, C … in the order they appear – never two different "A".
List<ExerciseBlock> exerciseBlocks(List<GymExercise> ex) {
  final out = <ExerciseBlock>[];
  var letter = 0;
  var i = 0;
  while (i < ex.length) {
    final run = supersetOf(ex, i);
    if (run.length < 2) {
      out.add(ExerciseBlock(i, i, null));
      i++;
      continue;
    }
    out.add(ExerciseBlock(run.first, run.last, supersetLetter(letter++)));
    i = run.last + 1;
  }
  return out;
}

/// "A" … "Z" for group number [n] (0-based); later groups stay "Z" like [normalizeSupersets].
String supersetLetter(int n) => String.fromCharCode(65 + (n < 0 ? 0 : (n > 25 ? 25 : n)));

/// Result of [moveExercise].
enum SupersetMove {
  /// Moved; group membership as before or straight sets now.
  moved,

  /// Dropped between two members of another superset and joined it.
  joined,

  /// Dropped between two members of a superset that is already full: placed right after it.
  full,
}

/// Moves the exercise at [from] so that it ends up at index [to] of the list *without* it
/// (drag & drop), keeping every superset contiguous:
/// * dropped between two members of a superset it joins that superset – a group never ends up
///   with a stranger in its middle; if the group is full ([maxSupersetSize]) the exercise is
///   placed directly after the group instead,
/// * moved inside its own superset it only changes its position there,
/// * moved anywhere else it leaves its superset (the others stay linked if two remain).
SupersetMove moveExercise(List<GymExercise> ex, int from, int to) {
  if (from < 0 || from >= ex.length) return SupersetMove.moved;
  normalizeSupersets(ex);
  final own = ex[from].group;
  final e = ex.removeAt(from);
  to = to.clamp(0, ex.length);
  final before = to > 0 ? ex[to - 1].group : null, after = to < ex.length ? ex[to].group : null;
  var result = SupersetMove.moved;
  if (before != null && before == after) {
    // Between two members of one superset.
    if (before != own) {
      final size = ex.where((x) => x.group == before).length;
      if (size < maxSupersetSize) {
        result = SupersetMove.joined;
      } else {
        result = SupersetMove.full;
        while (to < ex.length && ex[to].group == before) {
          to++;
        }
      }
    }
    e.group = result == SupersetMove.full ? null : before;
  } else if (own == null || (before != own && after != own)) {
    e.group = null;
  }
  ex.insert(to, e);
  normalizeSupersets(ex);
  return result;
}

/// Moves exercise [i] one step up ([dir] = -1) or down (+1) with the "move up/down" buttons and
/// returns its new index. A superset is never torn apart by an exercise passing through:
/// * inside its superset a member swaps places with its neighbour,
/// * otherwise the exercise jumps over the whole neighbouring block (a single exercise or a
///   complete superset); a member at the edge of its superset leaves it that way.
int stepExercise(List<GymExercise> ex, int i, int dir) {
  if (i < 0 || i >= ex.length || dir == 0) return i;
  normalizeSupersets(ex);
  final j = i + (dir < 0 ? -1 : 1);
  if (j < 0 || j >= ex.length) return i;
  final own = supersetOf(ex, i);
  if (own.contains(j)) {
    final e = ex.removeAt(i);
    ex.insert(j, e);
    return j;
  }
  final block = supersetOf(ex, j);
  final e = ex.removeAt(i)..group = null;
  final to = dir < 0 ? block.first : block.last; // index in the list without [e]
  ex.insert(to, e);
  normalizeSupersets(ex);
  return to;
}
