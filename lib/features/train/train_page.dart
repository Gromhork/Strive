import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/builtin_upgrade.dart';
import '../../data/default_programs.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../session/manual_entry_page.dart';
import '../session/start_helpers.dart';
import '../session/step_text.dart';
import 'exercise_picker.dart';
import 'program_order.dart';
import 'program_preview_page.dart';
import 'template_editor_page.dart';

/// Train tab: quick start, exercise library and the program library (folders).
///
/// Folders start collapsed. Long-press a folder header to reorder the folders, long-press a
/// program to move it – inside its folder, into another (open) folder or onto a folder header
/// (a closed folder opens while a program hovers over it). The lists auto-scroll at the edges.
/// Menus offer the same without dragging ("Nach oben / unten", "In Ordner verschieben"). The
/// order is synced via Firestore (profile `folderOrder`, program `order`).
class TrainPage extends ConsumerStatefulWidget {
  const TrainPage({super.key});

  @override
  ConsumerState<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends ConsumerState<TrainPage> {
  final _open = <String>{};

  /// The "New program" button shrinks to an icon once the list scrolls, so it does not
  /// cover the menus of the folders and programs below it.
  /// The tab's primary scroll controller (the shell scrolls it to the top on a second tap).
  ScrollController? _scroll;
  bool _fabExtended = true;

  /// A program is being dragged: pointer moves near the edges scroll the list.
  bool _dragging = false;
  EdgeDraggingAutoScroller? _autoScroller;

  /// Optimistic order until Firestore's snapshot arrives (no snap-back after a drop): the new
  /// folder order and the moved programs, each with the data it was based on – any newer
  /// snapshot replaces them.
  List<String>? _localFolders;
  List<String>? _localFoldersBase;
  Map<String, WorkoutTemplate>? _localPrograms;
  List<WorkoutTemplate>? _localProgramsBase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = PrimaryScrollController.maybeOf(context);
    if (c == _scroll) return;
    _scroll?.removeListener(_onScroll);
    _scroll = c?..addListener(_onScroll);
  }

  void _onScroll() {
    final s = _scroll;
    final ext = s == null || s.positions.length != 1 || s.offset < 24;
    if (ext != _fabExtended) setState(() => _fabExtended = ext);
  }

  @override
  void dispose() {
    _scroll?.removeListener(_onScroll);
    _autoScroller?.stopAutoScroll();
    super.dispose();
  }

  /// Folder names in display order ('' = programs without folder, always last).
  List<String> _folders(List<WorkoutTemplate> all, List<String> folderOrder, bool filtered) {
    final names = all.map((t) => t.folder).where((f) => f.isNotEmpty).toSet();
    final order = [
      for (final f in folderOrder)
        if (f.isNotEmpty && (names.contains(f) || !filtered)) f,
    ];
    final rest = names.where((f) => !order.contains(f)).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...order, ...rest, if (all.any((t) => t.folder.isEmpty)) ''];
  }

  /// The stored folder order, or the one just dropped while its write is on the way.
  List<String> _folderOrder(UserProfile p) {
    if (_localFolders != null && !identical(_localFoldersBase, p.folderOrder) && !listEquals(_localFoldersBase, p.folderOrder)) {
      _localFolders = _localFoldersBase = null;
    }
    return _localFolders ?? p.folderOrder;
  }

  /// The programs (display order) with the optimistic changes of the last drop.
  List<WorkoutTemplate> _programs(List<WorkoutTemplate> stored) {
    final local = _localPrograms;
    if (local == null) return stored;
    if (!identical(_localProgramsBase, stored)) {
      _localPrograms = _localProgramsBase = null;
      return stored;
    }
    return [for (final t in stored) local[t.id] ?? t]..sort((a, b) {
      final o = a.order.compareTo(b.order);
      return o != 0 ? o : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  void _saveFolderOrder(List<String> order) {
    final base = ref.read(profileOrDefaultProvider).folderOrder;
    setState(() {
      _localFolders = order;
      _localFoldersBase = base;
    });
    ref.read(repoProvider)!.saveFolderOrder(order);
  }

  void _savePrograms(List<WorkoutTemplate> changed) {
    if (changed.isEmpty) return;
    setState(() {
      _localPrograms = {...?_localPrograms, for (final t in changed) t.id: t};
      _localProgramsBase = ref.read(templateListProvider);
    });
    ref.read(repoProvider)!.saveTemplates(changed);
  }

  bool _visible(WorkoutTemplate t) {
    final filter = ref.read(sportFilterProvider);
    return filter == null || t.sport == filter;
  }

  /// Moves [t] into [folder] at [index] among the programs shown there.
  void _place(WorkoutTemplate t, String folder, int index) {
    final all = _programs(ref.read(templateListProvider));
    final current = all.firstWhere((x) => x.id == t.id, orElse: () => t);
    _savePrograms(placeProgram(all, current, folder, index, isVisible: _visible));
    if (folder.isNotEmpty && !ref.read(profileOrDefaultProvider).folderOrder.contains(folder)) {
      // A folder only known from its programs joins the stored order (keeps its place).
      final named = _folders(all, _folderOrder(ref.read(profileOrDefaultProvider)), false).where((f) => f.isNotEmpty).toList();
      _saveFolderOrder(named.contains(folder) ? named : [...named, folder]);
    }
  }

  void _startDrag(ScrollableState scrollable) {
    _autoScroller?.stopAutoScroll();
    _autoScroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 50);
    _dragging = true;
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    _autoScroller?.stopAutoScroll();
  }

  void _dragMove(Offset global) {
    if (_dragging) _autoScroller?.startAutoScrollIfNecessary(Rect.fromCenter(center: global, width: 1, height: 120));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final profile = ref.watch(profileOrDefaultProvider);
    final all = _programs(ref.watch(templateListProvider));
    final folderOrder = _folderOrder(profile);
    final templates = all.where((t) => filter == null || t.sport == filter).toList();
    final folders = _folders(templates, folderOrder, filter != null);
    final named = folders.where((f) => f.isNotEmpty).toList();
    List<WorkoutTemplate> inFolder(String f) => templates.where((t) => t.folder == f).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newTemplate',
        isExtended: _fabExtended,
        tooltip: l.newProgram,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditorPage(sport: filter ?? Sport.gym))),
        icon: const Icon(Icons.add),
        label: Text(l.newProgram),
      ),
      // Sees every pointer move of a program drag (even after the dragged row scrolled away).
      body: Listener(
        onPointerMove: (e) => _dragMove(e.position),
        onPointerUp: (_) => _endDrag(),
        onPointerCancel: (_) => _endDrag(),
        child: CustomScrollView(
          primary: true,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList.list(
                children: [
                  Text(l.quickStart, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  // Two tiles per row; when a label would not fit a half-width tile in two lines (large text,
                  // narrow phone), one per row – labels stay whole and in the normal size (no ellipsis, no
                  // scaleDown: "Radfahr…", "Leere Einh…" at text ×1.3).
                  LayoutBuilder(
                    builder: (context, box) {
                      final sports = [
                        for (final s in Sport.values)
                          if (filter == null || s == filter) s,
                      ];
                      final half = (box.maxWidth - _tileGap) / 2;
                      return _TileRows(
                        key: const ValueKey('quickStartTiles'),
                        columns: sports.every((s) => _QuickTile.fits(context, s, half)) ? 2 : 1,
                        minHeight: half / 2.2,
                        children: [for (final s in sports) _QuickTile(sport: s, onTap: () => quickStart(context, ref, s))],
                      );
                    },
                  ),
                  const SizedBox(height: _tileGap),
                  // Same style and rule as the quick-start tiles.
                  LayoutBuilder(
                    builder: (context, box) {
                      final half = (box.maxWidth - _tileGap) / 2;
                      return _TileRows(
                        key: const ValueKey('actionTiles'),
                        columns: [l.logManually, l.exercises].every((t) => _ActionTile.fits(context, t, half)) ? 2 : 1,
                        minHeight: _ActionTile.minHeight,
                        children: [
                          _ActionTile(
                            key: const ValueKey('logManuallyTile'),
                            icon: Icons.edit_note_rounded,
                            label: l.logManually,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryPage())),
                          ),
                          _ActionTile(
                            key: const ValueKey('exercisesTile'),
                            icon: Icons.menu_book_rounded,
                            label: l.exercises,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLibraryPage())),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(l.programs, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: l.newFolder,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        onPressed: () => _newFolder(all, folderOrder),
                      ),
                      PopupMenuButton<String>(
                        key: const ValueKey('programsMenu'),
                        onSelected: (v) => v == 'import' ? _import() : _restoreBuiltins(),
                        itemBuilder:
                            (_) => [
                              PopupMenuItem(
                                value: 'import',
                                child: ListTile(leading: const Icon(Icons.download_rounded), title: Text(l.importCode)),
                              ),
                              PopupMenuItem(
                                value: 'builtins',
                                child: ListTile(leading: const Icon(Icons.settings_backup_restore_rounded), title: Text(l.restoreBuiltins)),
                              ),
                            ],
                      ),
                    ],
                  ),
                  if (templates.length + named.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l.reorderHint, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            if (templates.isEmpty && folders.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.folder_open_rounded,
                  text: l.noPrograms,
                  action: FilledButton.tonalIcon(
                    key: const ValueKey('emptyAddBuiltins'),
                    onPressed: _restoreBuiltins,
                    icon: const Icon(Icons.library_add_outlined),
                    label: Text(l.addBuiltinPrograms),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: folders.length,
                  onReorderStart: (_) => HapticFeedback.mediumImpact(),
                  onReorder: (from, to) {
                    // Folders only: "no folder" stays last.
                    if (from >= named.length) return;
                    final target = (to > from ? to - 1 : to).clamp(0, named.length - 1);
                    if (target == from) return;
                    final full = _folders(all, folderOrder, false).where((f) => f.isNotEmpty).toList();
                    _saveFolderOrder(reorderFolders(full, named, from, target));
                  },
                  proxyDecorator: _proxy,
                  itemBuilder: (c, i) {
                    final f = folders[i];
                    final programs = inFolder(f);
                    return _FolderCard(
                      key: ValueKey('f-$f'),
                      index: i,
                      folder: f,
                      name: f.isEmpty ? l.noFolder : f,
                      programs: programs,
                      open: _open.contains(f),
                      onToggle: () => setState(() => _open.contains(f) ? _open.remove(f) : _open.add(f)),
                      onOpen: () => setState(() => _open.add(f)),
                      onMenu: f.isEmpty ? null : (v) => _folderAction(v, f, all, named, i),
                      canMoveUp: f.isNotEmpty && i > 0,
                      canMoveDown: f.isNotEmpty && i < named.length - 1,
                      onDropProgram: (t, index) => _place(t, f, index ?? programs.where((x) => x.id != t.id).length),
                      onDragStart: _startDrag,
                      onDragEnd: _endDrag,
                      onMoveProgram: (t, delta) {
                        final rest = programs.where((x) => x.id != t.id).toList();
                        final at = programs.indexWhere((x) => x.id == t.id) + delta;
                        if (at >= 0 && at <= rest.length) _place(t, f, at);
                      },
                      onMoveToFolder: (t) => _moveToFolder(t, all, folderOrder),
                      canRestore:
                          () => f.isNotEmpty && !_restorePlan(folderKeys: builtinFolderKeysOf(f, ref.read(templateListProvider))).isEmpty,
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }

  /// The lifted folder card while it is dragged.
  Widget _proxy(Widget child, int index, Animation<double> animation) => AnimatedBuilder(
    animation: animation,
    builder:
        (c, child) => Transform.scale(
          scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
          child: Material(
            color: Colors.transparent,
            elevation: 8 * Curves.easeOut.transform(animation.value),
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(18),
            child: child,
          ),
        ),
    child: child,
  );

  Future<void> _newFolder(List<WorkoutTemplate> all, List<String> folderOrder) async {
    final l = context.l10n;
    final name = (await askText(context, l.newFolder, hint: l.folderNameHint))?.trim();
    if (name == null || name.isEmpty || !mounted) return;
    final named = _folders(all, folderOrder, false).where((f) => f.isNotEmpty).toList();
    if (named.contains(name)) return toast(context, l.folderExists);
    _saveFolderOrder([...named, name]);
    setState(() => _open.add(name));
  }

  /// "In Ordner verschieben": a sheet of the folders (+ new folder); the program goes to the
  /// end of the chosen folder.
  Future<void> _moveToFolder(WorkoutTemplate t, List<WorkoutTemplate> all, List<String> folderOrder) async {
    final l = context.l10n;
    final folders = _folders(all, folderOrder, false).where((f) => f.isNotEmpty).toList();
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (c) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(title: Text(l.moveToFolder, style: const TextStyle(fontWeight: FontWeight.w700))),
                for (final f in [...folders, ''])
                  ListTile(
                    leading: Icon(f == t.folder ? Icons.check_rounded : Icons.folder_outlined),
                    title: Text(f.isEmpty ? l.noFolder : f),
                    onTap: () => Navigator.pop(c, f),
                  ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(l.newFolder),
                  onTap: () async {
                    final n = (await askText(c, l.newFolder, hint: l.folderNameHint))?.trim();
                    if (c.mounted && n != null && n.isNotEmpty) Navigator.pop(c, n);
                  },
                ),
              ],
            ),
          ),
    );
    if (target == null || target == t.folder || !mounted) return;
    final shown = all.where((x) => x.folder == target && x.id != t.id && _visible(x)).length;
    _place(t, target, shown);
    setState(() => _open.add(target));
    toast(context, l.movedToFolder(target.isEmpty ? l.noFolder : target));
  }

  Future<void> _folderAction(String action, String folder, List<WorkoutTemplate> all, List<String> named, int index) async {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final inside = all.where((t) => t.folder == folder).toList();
    final full = _folders(all, _folderOrder(ref.read(profileOrDefaultProvider)), false).where((f) => f.isNotEmpty).toList();
    switch (action) {
      case 'up' || 'down':
        _saveFolderOrder(reorderFolders(full, named, index, action == 'up' ? index - 1 : index + 1));
      case 'restore':
        await _restoreFolder(folder);
      case 'add':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TemplateEditorPage(sport: ref.read(sportFilterProvider) ?? Sport.gym, folder: folder)),
        );
      case 'rename':
        final name = (await askText(context, l.rename, initial: folder))?.trim();
        if (name == null || name.isEmpty || name == folder) return;
        if (full.contains(name)) return mounted ? toast(context, l.folderExists) : null;
        repo.saveTemplates([for (final t in inside) t.copyWith(folder: name)]);
        _saveFolderOrder([for (final f in full) f == folder ? name : f]);
        if (_open.remove(folder)) _open.add(name);
        setState(() {});
      case 'delete':
        if (!mounted) return;
        final choice = await showDialog<String>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(l.deleteFolderTitle(folder)),
                content: Text(inside.isEmpty ? l.deleteFolderEmpty : l.deleteFolderBody(inside.length)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
                  if (inside.isNotEmpty) TextButton(onPressed: () => Navigator.pop(c, 'keep'), child: Text(l.deleteFolderKeep)),
                  TextButton(
                    onPressed: () => Navigator.pop(c, 'all'),
                    child: Text(inside.isEmpty ? l.delete : l.deleteFolderAll, style: const TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
        );
        if (choice == null) return;
        if (choice == 'keep') {
          repo.saveTemplates([for (final t in inside) t.copyWith(folder: '')]);
        } else {
          repo.deleteTemplates(inside.map((t) => t.id));
        }
        _saveFolderOrder(full.where((f) => f != folder).toList());
    }
  }

  Future<void> _import() async {
    final l = context.l10n;
    final code = await askText(context, l.importCode, hint: 'ABC123');
    if (code == null || code.isEmpty) return;
    try {
      final t = await ref.read(repoProvider)!.importTemplate(code);
      if (mounted) toast(context, t == null ? l.codeNotFound : l.imported(t.name));
    } catch (e) {
      if (mounted) toast(context, l.offlineAction);
    }
  }

  /// What restoring the built-in programs of [folderKeys] (null = all) would change.
  BuiltinRestore _restorePlan({Set<String>? folderKeys}) {
    final repo = ref.read(repoProvider)!;
    return planBuiltinRestore(
      ref.read(templateListProvider),
      repo.newId,
      de: context.localeName.startsWith('de'),
      goal: ref.read(profileOrDefaultProvider).athlete.gymGoal,
      ownSuffix: context.l10n.ownVersionSuffix,
      folderKeys: folderKeys,
    );
  }

  void _applyRestore(BuiltinRestore plan) {
    if (plan.isEmpty) return;
    ref.read(repoProvider)!.saveTemplates(plan.writes);
    final opened = plan.add.map((t) => t.folder).where((f) => f.isNotEmpty);
    setState(() => _open.addAll(opened));
    toast(context, context.l10n.programsRestored(plan.add.length));
  }

  /// Folder menu "Standardprogramme wiederherstellen": confirms what is added and kept.
  Future<void> _restoreFolder(String folder) async {
    final l = context.l10n;
    final plan = _restorePlan(folderKeys: builtinFolderKeysOf(folder, ref.read(templateListProvider)));
    if (plan.isEmpty) return toast(context, l.builtinsAllOriginal);
    final ok = await confirm(
      context,
      l.restoreBuiltins,
      body: [
        l.restoreBuiltinsAdd(plan.add.map((t) => t.name).join(', ')),
        if (plan.keep.isNotEmpty) l.restoreBuiltinsKeep(plan.keep.map((t) => '„${t.name}“').join(', ')),
      ].join('\n\n'),
      ok: l.restoreAction,
    );
    if (ok && mounted) _applyRestore(_restorePlan(folderKeys: builtinFolderKeysOf(folder, ref.read(templateListProvider))));
  }

  /// Overflow / empty state: every built-in folder with missing or changed programs.
  Future<void> _restoreBuiltins() async {
    final l = context.l10n;
    final de = context.localeName.startsWith('de');
    final byFolder = <String, BuiltinRestore>{
      for (final fk in builtinFolderKeys)
        if (_restorePlan(folderKeys: {fk}) case final p when !p.isEmpty) fk: p,
    };
    if (byFolder.isEmpty) return toast(context, l.builtinsAllOriginal);
    final chosen = <String>{...byFolder.keys};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setS) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.restoreBuiltins, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(l.restoreBuiltinsSub, style: Theme.of(c).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final e in byFolder.entries)
                                CheckboxListTile(
                                  key: ValueKey('restore-${e.key}'),
                                  contentPadding: EdgeInsets.zero,
                                  value: chosen.contains(e.key),
                                  onChanged: (v) => setS(() => v! ? chosen.add(e.key) : chosen.remove(e.key)),
                                  secondary: SportBadge(e.value.add.first.sport),
                                  title: Text(folderName(e.key, de), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    [
                                      e.value.add.map((t) => t.name).join(', '),
                                      if (e.value.keep.isNotEmpty) l.builtinChangedLine(e.value.changedNames.join(', ')),
                                    ].join('\n'),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const ValueKey('restoreConfirm'),
                          onPressed: chosen.isEmpty ? null : () => Navigator.pop(c, true),
                          child: Text(l.addN(chosen.fold<int>(0, (n, f) => n + byFolder[f]!.add.length))),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (ok != true || !mounted) return;
    _applyRestore(_restorePlan(folderKeys: chosen));
  }
}

class _FolderCard extends StatefulWidget {
  const _FolderCard({
    super.key,
    required this.index,
    required this.folder,
    required this.name,
    required this.programs,
    required this.open,
    required this.onToggle,
    required this.onOpen,
    required this.onMenu,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDropProgram,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onMoveProgram,
    required this.onMoveToFolder,
    required this.canRestore,
  });
  final int index;
  final String folder;
  final String name;
  final List<WorkoutTemplate> programs;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final ValueChanged<String>? onMenu;
  final bool canMoveUp;
  final bool canMoveDown;

  /// A program dropped into this folder: at [index] among its shown programs (null = end).
  final void Function(WorkoutTemplate t, int? index) onDropProgram;
  final ValueChanged<ScrollableState> onDragStart;
  final VoidCallback onDragEnd;
  final void Function(WorkoutTemplate t, int delta) onMoveProgram;
  final ValueChanged<WorkoutTemplate> onMoveToFolder;

  /// Whether the folder stands for built-in programs that are missing or changed (asked when
  /// its menu opens).
  final bool Function() canRestore;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  /// A closed folder opens when a program hovers over its header for a moment.
  Timer? _springOpen;

  @override
  void dispose() {
    _springOpen?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final programs = widget.programs;
    final sports = programs.map((t) => t.sport).toSet().toList()..sort((a, b) => a.index.compareTo(b.index));
    final color = sports.length == 1 ? sports.first.color : AppColors.brand;
    final open = widget.open;

    Widget header(bool hover) => InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: widget.onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: hover ? 0.32 : 0.16), borderRadius: BorderRadius.circular(12)),
              child: Icon(open || hover ? Icons.folder_open_rounded : Icons.folder_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l.programsCount(programs.length),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final s in sports)
                        Padding(padding: const EdgeInsets.only(left: 6), child: Icon(s.icon, size: 14, color: s.color)),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more_rounded),
            ),
            if (widget.onMenu != null)
              PopupMenuButton<String>(
                key: ValueKey('folderMenu-${widget.folder}'),
                onSelected: widget.onMenu,
                itemBuilder:
                    (_) => [
                      PopupMenuItem(value: 'add', child: ListTile(leading: const Icon(Icons.add), title: Text(l.newProgram))),
                      PopupMenuItem(value: 'rename', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.rename))),
                      if (widget.canMoveUp)
                        PopupMenuItem(value: 'up', child: ListTile(leading: const Icon(Icons.arrow_upward_rounded), title: Text(l.moveUp))),
                      if (widget.canMoveDown)
                        PopupMenuItem(
                          value: 'down',
                          child: ListTile(leading: const Icon(Icons.arrow_downward_rounded), title: Text(l.moveDown)),
                        ),
                      if (widget.canRestore())
                        PopupMenuItem(
                          value: 'restore',
                          child: ListTile(leading: const Icon(Icons.settings_backup_restore_rounded), title: Text(l.restoreBuiltins)),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                          title: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
                        ),
                      ),
                    ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );

    // The header takes programs (to the end of this folder) and starts a folder drag on a
    // long press ("no folder" stays last and is not draggable).
    final headerTarget = DragTarget<WorkoutTemplate>(
      onWillAcceptWithDetails: (d) => d.data.folder != widget.folder,
      onMove: (_) {
        if (!widget.open && _springOpen == null) {
          _springOpen = Timer(const Duration(milliseconds: 700), () {
            _springOpen = null;
            if (mounted && !widget.open) widget.onOpen();
          });
        }
      },
      onLeave: (_) {
        _springOpen?.cancel();
        _springOpen = null;
      },
      onAcceptWithDetails: (d) {
        _springOpen?.cancel();
        _springOpen = null;
        HapticFeedback.selectionClick();
        widget.onDropProgram(d.data, null);
        widget.onOpen();
      },
      builder: (c, candidates, _) => header(candidates.isNotEmpty),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ReorderableDelayedDragStartListener(index: widget.index, enabled: widget.folder.isNotEmpty, child: headerTarget),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child:
                  !open
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child:
                            programs.isEmpty
                                ? DragTarget<WorkoutTemplate>(
                                  onAcceptWithDetails: (d) => widget.onDropProgram(d.data, 0),
                                  builder:
                                      (c, cand, _) => Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: cand.isNotEmpty ? AppColors.brand : Colors.transparent, width: 2),
                                        ),
                                        child: Text(l.folderEmpty, style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                )
                                : Column(
                                  children: [
                                    for (var i = 0; i < programs.length; i++)
                                      _ProgramRow(
                                        key: ValueKey(programs[i].id),
                                        t: programs[i],
                                        canMoveUp: i > 0,
                                        canMoveDown: i < programs.length - 1,
                                        onDrop: (dragged, after) {
                                          final rest = programs.where((x) => x.id != dragged.id).toList();
                                          final at = rest.indexWhere((x) => x.id == programs[i].id);
                                          widget.onDropProgram(dragged, at + (after ? 1 : 0));
                                        },
                                        onDragStart: widget.onDragStart,
                                        onDragEnd: widget.onDragEnd,
                                        onMove: (delta) => widget.onMoveProgram(programs[i], delta),
                                        onMoveToFolder: () => widget.onMoveToFolder(programs[i]),
                                      ),
                                  ],
                                ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A program in a folder: long-press lifts it (haptic); dropping another program on it
/// inserts that one above or below (where the line shows).
class _ProgramRow extends StatefulWidget {
  const _ProgramRow({
    super.key,
    required this.t,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDrop,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onMove,
    required this.onMoveToFolder,
  });
  final WorkoutTemplate t;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(WorkoutTemplate dragged, bool after) onDrop;
  final ValueChanged<ScrollableState> onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<int> onMove;
  final VoidCallback onMoveToFolder;

  @override
  State<_ProgramRow> createState() => _ProgramRowState();
}

class _ProgramRowState extends State<_ProgramRow> {
  /// Where a hovering program would land: above (false) or below (true) this one.
  bool? _after;

  bool _below(Offset feedbackTopLeft) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    return box.globalToLocal(feedbackTopLeft).dy > 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final tile = _TemplateTile(
      t: t,
      canMoveUp: widget.canMoveUp,
      canMoveDown: widget.canMoveDown,
      onMove: widget.onMove,
      onMoveToFolder: widget.onMoveToFolder,
    );
    return LayoutBuilder(
      builder:
          (c, box) => DragTarget<WorkoutTemplate>(
            onWillAcceptWithDetails: (d) => d.data.id != t.id,
            onMove: (d) {
              final after = _below(d.offset);
              if (after != _after) setState(() => _after = after);
            },
            onLeave: (_) => setState(() => _after = null),
            onAcceptWithDetails: (d) {
              final after = _below(d.offset);
              setState(() => _after = null);
              HapticFeedback.selectionClick();
              widget.onDrop(d.data, after);
            },
            builder:
                (c, cand, _) => LongPressDraggable<WorkoutTemplate>(
                  data: t,
                  hapticFeedbackOnStart: true,
                  onDragStarted: () => widget.onDragStart(Scrollable.of(context)),
                  onDragEnd: (_) => widget.onDragEnd(),
                  feedback: _DragFeedback(t: t, width: box.maxWidth),
                  childWhenDragging: Opacity(opacity: 0.35, child: tile),
                  child: Container(
                    foregroundDecoration:
                        cand.isEmpty || _after == null
                            ? null
                            : BoxDecoration(
                              border: Border(
                                top: _after! ? BorderSide.none : const BorderSide(color: AppColors.brand, width: 3),
                                bottom: _after! ? const BorderSide(color: AppColors.brand, width: 3) : BorderSide.none,
                              ),
                            ),
                    child: tile,
                  ),
                ),
          ),
    );
  }
}

/// The lifted program under the finger.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.t, required this.width});
  final WorkoutTemplate t;
  final double width;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    shadowColor: Colors.black54,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
        child: Row(
          children: [
            SportBadge(t.sport),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.drag_indicator_rounded, color: Theme.of(context).colorScheme.outline),
          ],
        ),
      ),
    ),
  );
}

const _tileGap = 10.0;

/// Whether [text] fits in [maxLines] lines of [maxWidth] at the current text scale (ambient text
/// style merged with [style]) without breaking a word – a word wider than the line would be split
/// mid-word ("Radfahr-en").
bool _fitsLines(BuildContext context, String text, TextStyle? style, double maxWidth, {int maxLines = 2}) {
  bool fits(String s, int lines) {
    final painter = TextPainter(
      text: TextSpan(text: s, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: lines,
    )..layout(maxWidth: maxWidth);
    final ok = !painter.didExceedMaxLines;
    painter.dispose();
    return ok;
  }

  return maxWidth > 0 && text.split(RegExp(r'\s+')).every((w) => fits(w, 1)) && fits(text, maxLines);
}

/// [children] in rows of [columns] equally wide tiles; the tiles of a row share its height,
/// at least [minHeight], and grow with their text (large font) instead of clipping it.
class _TileRows extends StatelessWidget {
  const _TileRows({super.key, required this.columns, required this.minHeight, required this.children});
  final int columns;
  final double minHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += columns) ...[
          if (i > 0) const SizedBox(height: _tileGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: _tileGap),
                  Expanded(
                    child:
                        i + c < children.length
                            ? ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight), child: children[i + c])
                            : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const minHeight = 48.0;
  static const _hPad = 12.0, _icon = 22.0, _gap = 8.0;
  static const _style = TextStyle(fontWeight: FontWeight.w600);

  /// Whether [label] fits a tile of [width] (at most two lines, no word broken).
  static bool fits(BuildContext context, String label, double width) =>
      _fitsLines(context, label, _style, width - 2 * _hPad - _icon - _gap);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 6),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary, size: _icon),
                const SizedBox(width: _gap),
                // Full size, never scaled down (it was shrunk visibly smaller than its neighbour); the
                // layout gives the tile a whole row when the label doesn't fit half of one.
                Expanded(child: Text(label, style: _style)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.sport, required this.onTap});
  final Sport sport;
  final VoidCallback onTap;

  static const _hPad = 14.0, _icon = 28.0, _gap = 10.0, _play = 24.0;
  static const _titleStyle = TextStyle(fontWeight: FontWeight.w700);

  static String _subtitle(AppLocalizations l, Sport sport) => sport == Sport.gym ? l.emptyWorkout : l.quickRecord;

  /// Whether the tile's title and subtitle each fit a tile of [width] (at most two lines, no
  /// word broken).
  static bool fits(BuildContext context, Sport sport, double width) {
    final l = context.l10n;
    final text = width - 2 * _hPad - _icon - _gap - _play;
    return _fitsLines(context, sport.label(l), _titleStyle, text) &&
        _fitsLines(context, _subtitle(l, sport), Theme.of(context).textTheme.bodySmall, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: sport.color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 8),
          child: Row(
            children: [
              Icon(sport.icon, color: sport.color, size: _icon),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Whole words in the normal size; the layout gives the tile a whole row when a
                    // label doesn't fit half of one.
                    Text(sport.label(l), style: _titleStyle),
                    Text(_subtitle(l, sport), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: sport.color, size: _play),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({
    required this.t,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onMoveToFolder,
  });
  final WorkoutTemplate t;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<int> onMove;
  final VoidCallback onMoveToFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sub =
        t.sport == Sport.gym
            ? '${t.exercises.length} ${l.exercises} · ≈ ${t.estimatedMinutes} min'
            : [
              '≈ ${programMinutes(t, ref.watch(profileOrDefaultProvider))} min',
              if (stepsDistance(t.steps, ref.watch(profileOrDefaultProvider).units, t.sport) case final d?)
                d
              else if (t.steps.where((s) => s.isWork).length > 1)
                l.stepsCount(t.steps.length),
              intensityLabel(l, t.intensity),
            ].join(' · ');
    final repo = ref.read(repoProvider)!;

    Future<void> menu(String v) async {
      switch (v) {
        case 'edit':
          Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditorPage(template: t)));
        case 'dup':
          repo.saveTemplate(
            WorkoutTemplate.fromMap(repo.newId(), {...t.toMap(), 'name': '${t.name} (${l.copy})', 'key': null, 'order': t.order + 1}),
          );
        case 'up':
          onMove(-1);
        case 'down':
          onMove(1);
        case 'move':
          onMoveToFolder();
        case 'delete':
          if (await confirm(context, l.deleteProgram, body: t.name, ok: l.delete, danger: true)) repo.deleteTemplate(t.id);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Tapping opens the read-only preview (big "Start"); editing sits behind its pencil.
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramPreviewPage(template: t))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                SportBadge(t.sport),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l.startWorkout,
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed:
                      () =>
                          t.sport == Sport.gym
                              ? startGym(context, ref, title: t.name, template: t)
                              : showCardioStart(context, ref, t.sport, title: t.name, steps: t.steps),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('programMenu-${t.id}'),
                  onSelected: menu,
                  itemBuilder:
                      (_) => [
                        PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.edit))),
                        PopupMenuItem(value: 'dup', child: ListTile(leading: const Icon(Icons.copy_rounded), title: Text(l.duplicate))),
                        if (canMoveUp)
                          PopupMenuItem(
                            value: 'up',
                            child: ListTile(leading: const Icon(Icons.arrow_upward_rounded), title: Text(l.moveUp)),
                          ),
                        if (canMoveDown)
                          PopupMenuItem(
                            value: 'down',
                            child: ListTile(leading: const Icon(Icons.arrow_downward_rounded), title: Text(l.moveDown)),
                          ),
                        PopupMenuItem(
                          value: 'move',
                          child: ListTile(leading: const Icon(Icons.drive_file_move_outlined), title: Text(l.moveToFolder)),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                            title: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
