import '../../data/models.dart';

/// Duplicating programs and whole folders of the program library (Train tab).
///
/// A copy is always the athlete's own program: it never carries the built-in key
/// ([WorkoutTemplate.key]) or the key it once stood for ([WorkoutTemplate.origKey]). So the plan
/// generator keeps using the original, "restore the standard programs" neither counts the copy as
/// the original nor as a changed version of it, and the gym days assigned in the plan settings
/// (`key:<key>` / `id:<id>`) keep pointing to the originals. Everything else is copied: exercises
/// with their sets, weights, supersets, timed holds and notes, the steps of an endurance workout,
/// targets and description.

/// Name of a copy of [name] that none of [taken] has (ignoring case): "Name (Kopie)", then
/// "Name (Kopie 2)", "Name (Kopie 3)" … A copy of a copy counts on instead of stacking the
/// suffix ("Name (Kopie)" → "Name (Kopie 2)"). [suffix] is the localised word ("Kopie" / "copy").
String copyName(String name, Iterable<String> taken, String suffix) {
  final used = {for (final n in taken) n.trim().toLowerCase()};
  final trimmed = name.trim();
  final marked = RegExp('^(.*?)\\s*\\(${RegExp.escape(suffix)}(?: \\d+)?\\)\$', caseSensitive: false).firstMatch(trimmed);
  final base = marked?.group(1) ?? trimmed;
  for (var i = 1; ; i++) {
    final n = '$base (${i == 1 ? suffix : '$suffix $i'})'.trim();
    if (!used.contains(n.toLowerCase())) return n;
  }
}

/// [t] as a new program of the athlete's own with the id [id] (see the library comment).
WorkoutTemplate programCopy(WorkoutTemplate t, String id, {String? name, String? folder, int? order}) => WorkoutTemplate.fromMap(id, {
  ...t.toMap(),
  'key': null,
  'origKey': null,
  'name': name ?? t.name,
  'folder': folder ?? t.folder,
  'order': order ?? t.order,
});

/// A duplicated program.
class ProgramDuplicate {
  const ProgramDuplicate(this.copy, this.writes);

  /// The new program (also part of [writes]).
  final WorkoutTemplate copy;

  /// Every document to save: the copy and the programs of its folder whose position changed.
  final List<WorkoutTemplate> writes;
}

/// Duplicates [t]. In its own folder the copy sits directly below [t] and is called
/// "Name (Kopie)" ([copyName]); in another [folder] it goes to the end and keeps its name unless
/// a program there already has it. [all] is the program list in display order (by order, then
/// name); the folder's programs are renumbered 0…n, only changed ones are written.
ProgramDuplicate duplicateProgram(List<WorkoutTemplate> all, WorkoutTemplate t, String id, {required String suffix, String? folder}) {
  final target = folder ?? t.folder;
  final inside = [
    for (final x in all)
      if (x.folder == target) x,
  ];
  final names = [for (final x in inside) x.name];
  final same = target == t.folder;
  final clash = names.any((n) => n.trim().toLowerCase() == t.name.trim().toLowerCase());
  final copy = programCopy(t, id, name: same || clash ? copyName(t.name, names, suffix) : t.name, folder: target);
  final source = same ? inside.indexWhere((x) => x.id == t.id) : -1;
  final next = [...inside]..insert(source < 0 ? inside.length : source + 1, copy);
  final writes = [
    for (var n = 0; n < next.length; n++)
      if (next[n].order != n || identical(next[n], copy)) next[n].copyWith(order: n),
  ];
  return ProgramDuplicate(writes.firstWhere((x) => x.id == id), writes);
}

/// A duplicated folder.
class FolderDuplicate {
  const FolderDuplicate({required this.folder, required this.copies, required this.folderOrder});

  /// Name of the new folder.
  final String folder;

  /// The copies of the folder's programs (all sports), in the same order.
  final List<WorkoutTemplate> copies;

  /// The named folders with the new one directly after its source.
  final List<String> folderOrder;
}

/// Duplicates the folder [folder] with every program in it – whatever the sport filter shows.
/// The new folder is called "Name (Kopie)" ([copyName], unique among all folders) and follows its
/// source in [folders] (every named folder in display order). The copies keep their names (the
/// folder tells them apart) and their order. [all]: the programs in display order.
FolderDuplicate duplicateFolder(
  List<WorkoutTemplate> all,
  List<String> folders,
  String folder,
  String Function() id, {
  required String suffix,
}) {
  final name = copyName(folder, [...folders, for (final t in all) t.folder], suffix);
  final inside = [
    for (final t in all)
      if (t.folder == folder) t,
  ];
  final at = folders.indexOf(folder);
  return FolderDuplicate(
    folder: name,
    copies: [for (final (i, t) in inside.indexed) programCopy(t, id(), folder: name, order: i)],
    folderOrder: [...folders]..insert(at < 0 ? folders.length : at + 1, name),
  );
}
