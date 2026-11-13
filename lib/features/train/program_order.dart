import '../../data/models.dart';

/// Order of the program library (Train tab): folder order lives in the profile
/// (`folderOrder`, synced via Firestore), the position of a program inside its folder in its
/// `order` field. Both existed before drag & drop, so older data and the built-in programs
/// (order 0…n per folder) keep their order. Only the documents whose folder or order really
/// changes are written.

/// [full] with the [visible] items rearranged to [reordered] – hidden items (another sport
/// filter) keep their positions, the visible ones fill the visible slots in the new order.
List<T> mergeVisibleOrder<T>(List<T> full, List<T> visible, List<T> reordered) {
  final shown = visible.toSet();
  final it = reordered.iterator;
  return [
    for (final x in full)
      if (!shown.contains(x)) x else if (it.moveNext()) it.current,
  ];
}

/// [list] with the item at [from] moved to [to] (index in the list without it).
List<T> moveItem<T>(List<T> list, int from, int to) {
  final out = [...list];
  final x = out.removeAt(from);
  out.insert(to.clamp(0, out.length), x);
  return out;
}

/// New full folder order after moving the visible folder at [from] to [to] (an index into
/// [visible] after removing it). [full]: every named folder in display order.
List<String> reorderFolders(List<String> full, List<String> visible, int from, int to) {
  if (from < 0 || from >= visible.length) return full;
  final all = [
    ...full,
    for (final f in visible)
      if (!full.contains(f)) f,
  ];
  return mergeVisibleOrder(all, visible, moveItem(visible, from, to));
}

/// The programs to save after placing [t] into [folder] at [index] among the programs of
/// that folder that are shown ([isVisible]; [t] itself not counted). [all] is the program
/// list in display order (by order, then name). The folder's programs are renumbered
/// 0…n in their new order; only changed ones are returned.
List<WorkoutTemplate> placeProgram(
  List<WorkoutTemplate> all,
  WorkoutTemplate t,
  String folder,
  int index, {
  bool Function(WorkoutTemplate)? isVisible,
}) {
  final target = [
    for (final x in all)
      if (x.folder == folder && x.id != t.id) x,
  ];
  final visible = isVisible == null ? target : target.where(isVisible).toList();
  final i = index.clamp(0, visible.length);
  // Before the visible program now at [i], or right after the last visible one.
  final at = i < visible.length ? target.indexOf(visible[i]) : (visible.isEmpty ? target.length : target.indexOf(visible.last) + 1);
  final moved = t.copyWith(folder: folder);
  final next = [...target]..insert(at, moved);
  return [
    for (var n = 0; n < next.length; n++)
      if (next[n].order != n || (next[n].id == t.id && t.folder != folder)) next[n].copyWith(order: n),
  ];
}
