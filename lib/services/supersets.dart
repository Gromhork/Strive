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
