import 'dart:convert';

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
    for (final g in gymGoals) ...[
      if (_current(g)[key] case final ex?) gymSignature(ex),
      for (final ex in previousBuiltinVersions(g)[key] ?? const <List<GymExercise>>[]) gymSignature(ex),
    ],
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

/// Old (pre-key) program names, so athletes whose programs were stored before the built-in key
/// existed keep their programs ("Upper" stood for both upper days).
const legacyBuiltinNames = {
  'fb_a': 'Full Body A',
  'fb_b': 'Full Body B',
  'ul_upper_a': 'Upper',
  'ul_upper_b': 'Upper',
  'ul_lower_a': 'Lower',
  'ul_lower_b': 'Lower',
  'ppl_push': 'Push',
  'ppl_pull': 'Pull',
  'ppl_legs': 'Legs',
};

/// The athlete's program that stands for the built-in program [key], or null when they have none:
/// 1. the program carrying the key (the first in list order, as stored);
/// 2. else their own version of it that "restore the originals" or the guest transfer took the
///    key from ([WorkoutTemplate.origKey]);
/// 3. else an own program of that sport without key under one of the built-in's shipped names
///    (either language, ignoring case) – a name shared by two built-ins ("Legs": PPL and bro
///    split) only in that built-in's standard folder;
/// 4. else a pre-key program under its old name ([legacyBuiltinNames]).
/// Several candidates of one step: the one in the folder with the shortest name, then folder name
/// and id – never the document order.
///
/// The plan uses this program for [key], and built-ins are only added automatically
/// ([missingBuiltins]) when there is none – so an athlete's changed version is never joined by a
/// second, automatically re-added original of the same name (owner report r10: "2× Push").
WorkoutTemplate? programForBuiltin(List<WorkoutTemplate> templates, String key) {
  final keyed = templates.where((t) => t.key == key).firstOrNull;
  if (keyed != null) return keyed;
  final sport = _builtinByKey[key]?.sport;
  WorkoutTemplate? best(bool Function(WorkoutTemplate t) test) {
    WorkoutTemplate? out;
    for (final t in templates) {
      if (t.key != null || !test(t)) continue;
      if (out == null || _folderRank(t, out) < 0) out = t;
    }
    return out;
  }

  final own = best((t) => t.origKey == key && (sport == null || t.sport == sport));
  if (own != null) return own;
  final names = _builtinNames[key];
  if (names != null && sport != null) {
    final lower = {for (final n in names) n.toLowerCase()};
    final folders = builtinFolderNames(builtinFolderOf[key]!);
    final named = best((t) {
      if (t.origKey != null || t.sport != sport) return false;
      final n = t.name.trim().toLowerCase();
      if (!lower.contains(n)) return false;
      return builtinKeysNamed(n).length == 1 || folders.contains(t.folder.trim());
    });
    if (named != null) return named;
  }
  final legacy = legacyBuiltinNames[key];
  return legacy == null ? null : best((t) => t.origKey == null && t.sport == Sport.gym && t.name == legacy);
}

/// The built-in key [t] stands for ([programForBuiltin]), or null for an own program.
String? builtinKeyOf(List<WorkoutTemplate> templates, WorkoutTemplate t) {
  final candidates = [
    if (t.key != null) t.key!,
    if (t.origKey != null) t.origKey!,
    ...builtinKeysNamed(t.name),
    for (final e in legacyBuiltinNames.entries)
      if (e.value == t.name) e.key,
  ];
  for (final k in candidates) {
    if (programForBuiltin(templates, k)?.id == t.id) return k;
  }
  return null;
}

int _folderRank(WorkoutTemplate a, WorkoutTemplate b) {
  final length = a.folder.length.compareTo(b.folder.length);
  if (length != 0) return length;
  final folder = a.folder.compareTo(b.folder);
  return folder != 0 ? folder : a.id.compareTo(b.id);
}

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
    for (final e in previousBuiltinVersions(g).entries) {
      for (final ex in e.value) {
        out.putIfAbsent(e.key, () => {}).add(gymSignature(ex));
      }
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

/// Every shipped description and exercise / step note per built-in key (both languages, every
/// goal) – what an untouched copy can carry ([isPristineBuiltin]).
final Map<String, ({Set<String> descriptions, Set<String> notes})> _shippedTexts = () {
  final out = <String, ({Set<String> descriptions, Set<String> notes})>{};
  for (final de in [false, true]) {
    for (final g in gymGoals) {
      for (final t in defaultTemplates(() => '', de: de, goal: g)) {
        final e = out.putIfAbsent(t.key!, () => (descriptions: {''}, notes: {''}));
        e.descriptions.add(t.description.trim());
        for (final x in t.exercises) {
          e.notes.add(x.note.trim());
        }
        for (final x in t.steps) {
          e.notes.add(x.note.trim());
        }
      }
    }
  }
  return out;
}();

/// Whether [t] is a built-in program exactly as an automatic add left it – stricter than
/// [isUntouchedBuiltin], which only looks at what the plan uses (name, work sets, rep ranges, rest):
/// also no warm-up / drop / failure set, no done set, no own weights or prescribed loads, every
/// exercise / step note and the description empty or as shipped (any language, any goal) and, for
/// an endurance program, the shipped intensity and targets. Only such a copy may ever be deleted
/// as an automatically added duplicate ([builtinDuplicateCleanup]) – an athlete's warm-ups, notes or
/// description are never lost.
bool isPristineBuiltin(WorkoutTemplate t) {
  if (!isUntouchedBuiltin(t)) return false;
  final key = t.key!;
  final texts = _shippedTexts[key]!;
  if (!texts.descriptions.contains(t.description.trim())) return false;
  if (t.sport == Sport.gym) {
    for (final e in t.exercises) {
      if (!texts.notes.contains(e.note.trim()) || e.rxKg != null || e.effort != null || e.bodyKg > 0) return false;
      if (e.sets.any((s) => s.type != SetType.normal || s.done || s.weight != 0 || s.rpe != null)) return false;
    }
    return true;
  }
  final original = _builtinByKey[key]!;
  if (t.intensity != original.intensity || t.targetKm != original.targetKm || t.targetMin != original.targetMin) return false;
  return t.steps.every((s) => texts.notes.contains(s.note.trim()));
}

/// [t]'s stored fields without those that differ between automatically added copies of one
/// built-in (id, position, folder) – equal for identical twins.
Map<String, dynamic> _content(WorkoutTemplate t) => {...t.toMap()}..removeWhere((k, _) => k == 'order' || k == 'folder');

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
    // The athlete's versions of it: those with the key – else their version of a former restore /
    // the guest transfer ([WorkoutTemplate.origKey], [programForBuiltin]). An own program that only
    // shares the name (a duplicated folder's copy) stays as it is.
    final keyed = existing.where((t) => t.key == b.key).toList();
    final stands = keyed.isEmpty ? programForBuiltin(existing, b.key!) : null;
    final ownVersion = stands != null && stands.origKey == b.key ? stands : null;
    final same = [...keyed, if (ownVersion != null) ownVersion];
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
      if (programForBuiltin(existing, k) case final t? when kept.contains(t.id)) k: t.id,
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

// ──────────────────────── Automatically re-added duplicates ────────────────────────

/// What [builtinDuplicateCleanup] changes (all empty: nothing to do).
class BuiltinDuplicateCleanup {
  const BuiltinDuplicateCleanup({this.delete = const {}, this.templates = const {}, this.plans = const {}});

  /// Automatically added copies that nothing else refers to.
  final Set<String> delete;

  /// Copies that are kept (a recorded workout, a done / skipped plan entry or the plan settings
  /// refer to them): without the built-in key, named "Name (Standard)" (origKey: the built-in, when
  /// the athlete's version keeps the key) – program id → fields.
  final Map<String, Map<String, dynamic>> templates;

  /// Open planned workouts of a removed or renamed copy, now pointing to the athlete's version –
  /// plan id → fields.
  final Map<String, Map<String, dynamic>> plans;

  bool get isEmpty => delete.isEmpty && templates.isEmpty && plans.isEmpty;
}

/// One-off repair of the built-in programs that older versions added automatically next to the
/// athlete's own version (owner report r10: "2× Push" – the changed one and the standard program,
/// without a restore): the plan added a built-in again whenever no program carried its key, e.g.
/// after "restore the originals" or the guest transfer had moved the key off the athlete's
/// version, or from an empty, not yet loaded program list.
///
/// Per built-in key, only a pristine copy ([isPristineBuiltin]: no warm-ups, notes, own description
/// or weights – an athlete's edits of any kind make it their version) is a duplicate when
/// * another program with that key is not pristine (two programs never carry one key on purpose –
///   a restore and a duplicate take the key off), or
/// * the athlete's own version standing for it without the key ([programForBuiltin]: from a
///   restore / the guest transfer, or under its name in the same folder) has the copy's name
///   (ignoring case) – a restore names the athlete's version "Name (eigene)", so an original
///   restored on purpose stays; or
/// * it is an identical twin of another pristine copy (equal apart from id, position and folder):
///   the one a workout or the plan settings refer to stays, else the first.
/// A duplicate's open planned workouts move to the athlete's version. It is deleted when nothing
/// else refers to it (no recorded workout, no done / skipped plan entry, no `id:` assignment in the
/// plan settings); otherwise it stays as an own program without the key, named
/// "Name ([suffix])" – nothing the athlete did with it is lost.
BuiltinDuplicateCleanup builtinDuplicateCleanup(
  List<WorkoutTemplate> templates, {
  required List<PlannedWorkout> plans,
  required List<Session> sessions,
  required AthleteData athlete,
  required String suffix,
}) {
  final delete = <String>{};
  final renames = <String, Map<String, dynamic>>{};
  final relink = <String, Map<String, dynamic>>{};
  final taken = {for (final t in templates) '${t.folder}\n${t.name.trim().toLowerCase()}'};
  final assigned = {
    for (final r in [...athlete.gymPlanA.values, ...athlete.gymPlanB.values])
      if (r.startsWith('id:')) r.substring(3),
  };
  final used = {
    for (final s in sessions)
      if (s.templateId != null) s.templateId!,
    for (final p in plans)
      if (p.templateId != null && p.status != 'planned') p.templateId!,
    ...assigned,
  };
  String norm(String n) => n.trim().toLowerCase();

  for (final key in _builtinByKey.keys) {
    final keyed = templates.where((t) => t.key == key).toList();
    if (keyed.isEmpty) continue;
    // Only a pristine copy can be an automatic add: one with the athlete's warm-ups, notes,
    // description or weights is their version, whatever the plan-relevant fields say.
    final pristine = keyed.where(isPristineBuiltin).toList();
    if (pristine.isEmpty) continue;
    final changed = keyed.where((t) => !pristine.contains(t)).toList();
    final groups = <(WorkoutTemplate, List<WorkoutTemplate>)>[];
    if (changed.isNotEmpty) {
      groups.add((changed.first, pristine));
    } else {
      final own = programForBuiltin([
        for (final t in templates)
          if (t.key == null) t,
      ], key);
      // Same name – and, for an own program that only shares the name (no origKey: e.g. a duplicated
      // folder's copy), also the same folder: a copy elsewhere next to the original is on purpose.
      bool twin(WorkoutTemplate t) => own != null && norm(t.name) == norm(own.name) && (own.origKey == key || t.folder == own.folder);
      if (own != null && pristine.any(twin)) {
        groups.add((
          own,
          [
            for (final t in pristine)
              if (twin(t)) t,
          ],
        ));
      } else {
        // Identical twins (equal apart from id, position and folder – e.g. added twice from an
        // empty list): one stays – the one a workout or the plan settings refer to, else the first.
        // Copies that differ in anything (language, version) all stay.
        final left = [...pristine];
        while (left.isNotEmpty) {
          final c = jsonEncode(_content(left.first));
          final same = left.where((t) => jsonEncode(_content(t)) == c).toList();
          left.removeWhere(same.contains);
          if (same.length < 2) continue;
          final keep = same.where((t) => used.contains(t.id)).firstOrNull ?? same.first;
          groups.add((
            keep,
            [
              for (final t in same)
                if (t != keep) t,
            ],
          ));
        }
      }
    }
    for (final (keep, dups) in groups) {
      for (final d in dups) {
        for (final p in plans) {
          if (p.templateId == d.id && p.status == 'planned') relink[p.id] = {'templateId': keep.id};
        }
        if (!used.contains(d.id)) {
          delete.add(d.id);
          continue;
        }
        var name = '${d.name.trim()} ($suffix)';
        for (var i = 2; taken.contains('${d.folder}\n${name.toLowerCase()}'); i++) {
          name = '${d.name.trim()} ($suffix $i)';
        }
        taken.add('${d.folder}\n${name.toLowerCase()}');
        // Workouts done with it still count for the gym rotation as that built-in (origKey) – unless
        // the athlete's version has no key: then the copy would stand for the built-in instead of
        // their version ([programForBuiltin] step 2).
        renames[d.id] = {'key': null, 'name': name, if (keep.key == key) 'origKey': key};
      }
    }
  }
  return BuiltinDuplicateCleanup(delete: delete, templates: renames, plans: relink);
}
