import '../core/sport.dart';
import 'default_programs.dart';
import 'models.dart';

/// Signature of a gym exercise list: exercise, work sets, rep range, superset letter
/// and rest – everything a user would change when editing a program.
String gymSignature(List<GymExercise> ex) =>
    ex.map((e) => '${e.exId}:${e.workSets.length}:${e.repMin}-${e.repMax}:${e.group ?? ''}:${e.restSec}').join(',');

/// Built-in gym programs as shipped before the antagonist-superset revision (v1).
const _v1 = {
  'fb_a': '0043:3:5-8::180,0025:3:6-10::150,0861:3:8-12::120,0085:2:8-12::120,0334:2:12-20::60,0276:2:8-12::45',
  'fb_b': '0032:3:4-6::180,0426:3:8-12::120,2330:3:8-12::120,0336:2:8-12::90,0314:2:8-12::120,0472:2:8-15::60',
  'fb_c': '0739:3:10-15::120,0652:3:6-10::150,0289:3:8-12::120,0586:2:10-15::75,0313:2:10-15:A:60,0241:2:10-15:A:60',
  'ul_upper_a': '0025:4:5-8::150,0027:4:6-10::120,0405:3:8-12::120,2330:3:8-12::120,0031:2:8-12:A:60,0241:2:10-15:A:60',
  'ul_lower_a': '0043:4:5-8::180,0085:3:8-10::120,0585:3:10-15::75,0586:3:10-15::75,0605:3:10-15::60,0276:2:8-12::45',
  'ul_upper_b':
      '0314:3:8-12::120,0652:3:6-10::150,0861:3:10-12::120,0334:3:12-20:A:60,0378:3:12-20:A:60,0227:2:12-15::60,0318:2:10-15:B:60,0194:2:10-15:B:60',
  'ul_lower_b': '0032:3:4-6::180,0739:3:10-15::120,0336:3:8-12::90,0599:3:10-15::75,0594:3:12-20::60,0472:3:8-15::60',
  'ppl_push': '0025:4:6-10::150,0314:3:8-12::120,0405:3:8-12::120,0334:3:12-20::60,0241:3:10-15:A:60,0194:2:10-15:A:60',
  'ppl_pull': '0652:3:6-10::150,0027:3:6-10::120,2330:3:10-12::120,0378:3:12-20::60,0031:3:8-12:A:60,0313:2:10-15:A:60',
  'ppl_legs': '0043:4:5-8::180,0085:3:8-10::120,0739:3:10-15::120,0586:3:10-15::75,0605:4:10-15::60,0472:3:8-15::60',
  'bro_chest': '0025:4:6-10::150,0314:4:8-12::120,0289:3:8-12::120,0227:3:12-15::60',
  'bro_back': '0032:3:4-6::180,0652:4:6-10::150,0027:3:8-10::120,0861:3:10-12::120',
  'bro_shoulders': '0405:4:8-12::120,0334:4:12-20::60,0378:4:12-20::60,0178:3:12-20::60',
  'bro_legs': '0043:4:5-8::180,0739:3:10-15::120,0085:3:8-10::120,0585:3:10-15::75,0586:3:10-15::75,0605:4:10-15::60',
  'bro_arms': '0031:3:8-12:A:60,0241:3:10-15:A:60,0318:3:10-15:B:60,0194:3:10-15:B:60,0313:3:10-15:C:60,0814:3:8-12:C:60',
  'home_a': '1760:3:8-15::90,0289:3:8-12::120,0293:3:8-12::90,1459:3:8-12::90,0334:2:12-20:A:60,0313:2:10-15:A:60,0276:2:8-12::45',
  'home_b': '0381:3:8-12::90,0426:3:8-12::120,0499:3:6-12::90,1757:2:8-12::90,0662:3:8-20::60,0409:2:10-15::45',
  'bw_a': '1460:3:10-20::60,0662:3:8-20::60,0499:3:6-15::75,3561:3:10-20::45,1373:2:15-25::45,0276:3:8-12::45',
  'bw_b': '0514:3:8-15::75,1326:3:3-10::120,0129:3:8-15::60,0410:3:8-12::60,0630:3:20-40::45,0472:2:8-15::60',
};

const gymGoals = ['general', 'strength', 'hypertrophy'];

/// Current built-in gym programs per goal: key → exercises.
Map<String, List<GymExercise>> _current(String goal) => {
  for (final t in defaultTemplates(() => '', goal: goal))
    if (t.sport == Sport.gym && t.key != null) t.key!: t.exercises,
};

/// New exercises for a stored built-in program that the user has not changed (it still
/// equals a shipped version – the old v1 or the current one for any goal) but differs
/// from the current version for [goal]. Null when the program is custom, edited or
/// already up to date – user changes are never overwritten.
List<GymExercise>? upgradedBuiltinExercises(WorkoutTemplate t, String goal) {
  final key = t.key;
  if (t.sport != Sport.gym || key == null) return null;
  final target = _current(goal)[key];
  if (target == null) return null;
  final sig = gymSignature(t.exercises);
  if (sig == gymSignature(target)) return null;
  final known = {
    if (_v1[key] != null) _v1[key]!,
    for (final g in gymGoals)
      if (_current(g)[key] case final ex?) gymSignature(ex),
  };
  // Only unchanged programs whose sets carry no own weights.
  if (!known.contains(sig) || t.exercises.any((e) => e.sets.any((s) => s.weight != 0))) return null;
  return [for (final e in target) e.copy(resetDone: true)];
}
