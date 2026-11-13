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

// ───────────────────────────── Restoring the originals ─────────────────────────────

/// Signature of a structured endurance workout as a user would edit it: per step its kind,
/// duration, distance and own targets. Zone codes and notes are left out – the shipped
/// programs' zone codes and drill notes were revised (Nov 2026) and are relocalised, so an
/// old, untouched program still counts as the original.
String stepsSignature(List<WorkoutStep> steps) => steps
    .map(
      (s) =>
          '${s.kind}:${s.durationSec ?? ''}:${s.distanceM ?? ''}:${s.paceMin ?? ''}-${s.paceMax ?? ''}:'
          '${s.powerMin ?? ''}-${s.powerMax ?? ''}:${s.hrMin ?? ''}-${s.hrMax ?? ''}',
    )
    .join(',');

/// Shipped names (English and German) per built-in key.
final Map<String, Set<String>> _builtinNames = () {
  final out = <String, Set<String>>{};
  for (final de in [false, true]) {
    for (final t in defaultTemplates(() => '', de: de)) {
      out.putIfAbsent(t.key!, () => {}).add(t.name);
    }
  }
  return out;
}();

/// Keys of the built-in programs shipped with the name [name] (any language, ignoring case) –
/// several for a shared name ("Beine": the PPL and the bro split's leg day).
Set<String> builtinKeysNamed(String name) {
  final n = name.trim().toLowerCase();
  return {
    for (final e in _builtinNames.entries)
      if (e.value.any((x) => x.toLowerCase() == n)) e.key,
  };
}

/// The built-in programs (English, general goal) by key.
final Map<String, WorkoutTemplate> _builtinByKey = {for (final t in defaultTemplates(() => '')) t.key!: t};

/// Every shipped exercise signature per gym key (v1 and the current version for each goal).
final Map<String, Set<String>> _knownGym = () {
  final out = <String, Set<String>>{};
  for (final e in _v1.entries) {
    out.putIfAbsent(e.key, () => {}).add(e.value);
  }
  for (final g in gymGoals) {
    for (final e in _current(g).entries) {
      out.putIfAbsent(e.key, () => {}).add(gymSignature(e.value));
    }
  }
  return out;
}();

/// Whether [t] is a built-in program exactly as shipped (any shipped version, any language):
/// its name, exercises / steps and no own weights. A renamed, edited or weighted program is
/// the user's own version.
bool isUntouchedBuiltin(WorkoutTemplate t) {
  final key = t.key;
  final original = key == null ? null : _builtinByKey[key];
  if (original == null || t.sport != original.sport || !_builtinNames[key]!.contains(t.name.trim())) return false;
  if (t.sport == Sport.gym) {
    if (t.exercises.any((e) => e.sets.any((s) => s.weight != 0))) return false;
    return _knownGym[key]?.contains(gymSignature(t.exercises)) ?? false;
  }
  return stepsSignature(t.steps) == stepsSignature(original.steps);
}

/// What restoring built-in programs changes.
class BuiltinRestore {
  const BuiltinRestore({this.add = const [], this.keep = const [], this.changed = const {}});

  /// The originals that are added (with their key: the plan generator uses them again).
  final List<WorkoutTemplate> add;

  /// The user's changed versions they replace: kept as the user's own programs – without the
  /// built-in key, renamed ("Pull (eigene)") when the name would clash with the original.
  final List<WorkoutTemplate> keep;

  /// Keys of the originals that replace a changed version (the rest were missing).
  final Set<String> changed;

  /// Names of the originals that replace a changed version.
  List<String> get changedNames => [
    for (final t in add)
      if (changed.contains(t.key)) t.name,
  ];

  bool get isEmpty => add.isEmpty;

  /// Every document to write (one batch).
  List<WorkoutTemplate> get writes => [...keep, ...add];
}

/// Folder a restored original of [folderKey] goes into: the standard folder as the user has
/// it (current-language name first), else the folder holding most of that split's programs
/// (a renamed standard folder), else the shipped name.
String builtinTargetFolder(List<WorkoutTemplate> existing, String folderKey, {required bool de}) {
  final own = folderName(folderKey, de), other = folderName(folderKey, !de);
  final folders = existing.map((t) => t.folder).toSet();
  if (folders.contains(own)) return own;
  if (folders.contains(other)) return other;
  final count = <String, int>{};
  for (final t in existing) {
    if (t.folder.isNotEmpty && t.key != null && builtinFolderOf[t.key] == folderKey) count[t.folder] = (count[t.folder] ?? 0) + 1;
  }
  if (count.isEmpty) return own;
  return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

/// Built-in folder keys a user folder stands for: the folders of the built-in programs in it
/// and a folder carrying a standard folder's name.
Set<String> builtinFolderKeysOf(String folder, List<WorkoutTemplate> existing) => {
  for (final t in existing)
    if (t.folder == folder && t.key != null)
      if (builtinFolderOf[t.key] case final fk?) fk,
  for (final fk in builtinFolderKeys)
    if (builtinFolderNames(fk).contains(folder)) fk,
};

/// Restores the built-in programs of [folderKeys] (null = all) in their original state: every
/// built-in without an untouched copy is added again (missing or changed by the user); the
/// changed versions stay as the user's own programs ([BuiltinRestore.keep]). Untouched
/// originals are never duplicated. [ownSuffix] marks a kept version whose name equals the
/// original's ("eigene" → "Pull (eigene)").
BuiltinRestore planBuiltinRestore(
  List<WorkoutTemplate> existing,
  String Function() id, {
  required bool de,
  required String ownSuffix,
  String goal = 'general',
  Set<String>? folderKeys,
}) {
  final add = <WorkoutTemplate>[];
  final keep = <WorkoutTemplate>[];
  final changed = <String>{};
  final taken = {for (final t in existing) '${t.folder}\n${t.name.trim().toLowerCase()}'};
  String unique(String folder, String name) {
    var n = name;
    for (var i = 2; taken.contains('$folder\n${n.toLowerCase()}'); i++) {
      n = '$name $i';
    }
    taken.add('$folder\n${n.toLowerCase()}');
    return n;
  }

  for (final b in defaultTemplates(id, de: de, goal: goal)) {
    final fk = builtinFolderOf[b.key]!;
    if (folderKeys != null && !folderKeys.contains(fk)) continue;
    final same = existing.where((t) => t.key == b.key).toList();
    if (same.any(isUntouchedBuiltin)) continue;
    final folder = builtinTargetFolder(existing, fk, de: de);
    if (same.isNotEmpty) changed.add(b.key!);
    for (final t in same) {
      final names = {for (final n in _builtinNames[b.key]!) n.toLowerCase()};
      final clash = names.contains(t.name.trim().toLowerCase());
      keep.add(
        WorkoutTemplate.fromMap(t.id, {
          ...t.toMap(),
          'key': null,
          'origKey': b.key,
          if (clash) 'name': unique(t.folder, '${t.name.trim()} ($ownSuffix)'),
        }),
      );
    }
    // The original keeps its shipped name; an unrelated own program of that name in the
    // folder does not block it (the user's changed versions were renamed above).
    taken.add('$folder\n${b.name.toLowerCase()}');
    add.add(WorkoutTemplate.fromMap(b.id, {...b.toMap(), 'folder': folder}));
  }
  return BuiltinRestore(add: add, keep: keep, changed: changed);
}

/// Athlete-data changes ([AthleteData.merge]) that keep the program assignment of the plan
/// settings ([AthleteData.gymPlanA] / [AthleteData.gymPlanB]) on the version the athlete picked:
/// a `key:<k>` reference stands for the athlete's program with that key, and restoring the
/// originals ([plan]) moves the key from their changed version to the restored original – the
/// reference becomes `id:<their version>`. Null when no assignment is affected.
Map<String, dynamic>? restoreAssignmentPatch(AthleteData a, BuiltinRestore plan, List<WorkoutTemplate> existing) {
  final kept = {for (final t in plan.keep) t.id};
  // The program a `key:` reference stood for so far: the first with that key (gymProgramOf).
  final target = <String, String>{
    for (final k in plan.changed)
      if (existing.where((t) => t.key == k).firstOrNull case final t? when kept.contains(t.id)) k: t.id,
  };
  Map<int, String>? rewrite(Map<int, String> week) {
    var changed = false;
    final out = <int, String>{};
    for (final e in week.entries) {
      final id = e.value.startsWith('key:') ? target[e.value.substring(4)] : null;
      changed |= id != null;
      out[e.key] = id != null ? 'id:$id' : e.value;
    }
    return changed ? out : null;
  }

  final ra = rewrite(a.gymPlanA), rb = rewrite(a.gymPlanB);
  if (ra == null && rb == null) return null;
  return {if (ra != null) 'gymPlanA': ra, if (rb != null) 'gymPlanB': rb};
}

/// Weekdays (1..7, assignment on) whose program [restoreAssignmentPatch] keeps on the athlete's
/// version.
List<int> restoreKeptDays(AthleteData a, Map<String, dynamic>? patch) {
  if (patch == null || !a.gymAssign) return const [];
  final days = <int>{};
  for (final (k, old) in [('gymPlanA', a.gymPlanA), if (a.gymAB) ('gymPlanB', a.gymPlanB)]) {
    final now = patch[k] as Map<int, String>?;
    if (now == null) continue;
    for (final e in now.entries) {
      if (old[e.key] != e.value) days.add(e.key);
    }
  }
  return days.toList()..sort();
}
