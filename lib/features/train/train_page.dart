import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/default_programs.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../session/manual_entry_page.dart';
import '../session/start_helpers.dart';
import '../session/step_text.dart';
import '../../services/zones.dart' show templateMinutes;
import 'exercise_picker.dart';
import 'program_preview_page.dart';
import 'template_editor_page.dart';

/// Train tab: quick start, exercise library and the program library (folders).
///
/// Folders start collapsed. Folders and programs can be renamed, deleted, moved and
/// reordered (drag & drop in "sort" mode); the order is synced via Firestore.
class TrainPage extends ConsumerStatefulWidget {
  const TrainPage({super.key});

  @override
  ConsumerState<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends ConsumerState<TrainPage> {
  final _open = <String>{};
  bool _sorting = false;

  /// The "New program" button shrinks to an icon once the list scrolls, so it does not
  /// cover the menus of the folders and programs below it.
  final _scroll = ScrollController();
  bool _fabExtended = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final ext = !_scroll.hasClients || _scroll.offset < 24;
      if (ext != _fabExtended) setState(() => _fabExtended = ext);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Folder names in display order ('' = programs without folder, always last).
  List<String> _folders(List<WorkoutTemplate> all, UserProfile p, bool filtered) {
    final names = all.map((t) => t.folder).where((f) => f.isNotEmpty).toSet();
    final order = [
      for (final f in p.folderOrder)
        if (names.contains(f) || !filtered) f,
    ];
    final rest = names.where((f) => !order.contains(f)).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...order, ...rest, if (all.any((t) => t.folder.isEmpty)) ''];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final profile = ref.watch(profileOrDefaultProvider);
    final all = ref.watch(templateListProvider);
    final templates = all.where((t) => filter == null || t.sport == filter).toList();
    final folders = _folders(templates, profile, filter != null);
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
      body: ListView(
        controller: _scroll,
        // Room below the last folder so its menu can be scrolled clear of the button.
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
        children: [
          Text(l.quickStart, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              for (final s in Sport.values.where((s) => filter == null || s == filter))
                _QuickTile(sport: s, onTap: () => quickStart(context, ref, s)),
            ],
          ),
          const SizedBox(height: 10),
          // Same style as the quick-start tiles; one line each (no wrapping label).
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  key: const ValueKey('logManuallyTile'),
                  icon: Icons.edit_note_rounded,
                  label: l.logManually,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryPage())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.menu_book_rounded,
                  label: l.exercises,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLibraryPage())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text(l.programs, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              if (_sorting)
                FilledButton.tonal(onPressed: () => setState(() => _sorting = false), child: Text(l.finish))
              else ...[
                IconButton(
                  tooltip: l.newFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () => _newFolder(profile, folders),
                ),
                IconButton(
                  tooltip: l.sortPrograms,
                  icon: const Icon(Icons.swap_vert_rounded),
                  onPressed: templates.isEmpty ? null : () => setState(() => _sorting = true),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'import' ? _import() : _addBuiltins(all),
                  itemBuilder:
                      (_) => [
                        PopupMenuItem(
                          value: 'import',
                          child: ListTile(leading: const Icon(Icons.download_rounded), title: Text(l.importCode)),
                        ),
                        PopupMenuItem(
                          value: 'builtins',
                          child: ListTile(leading: const Icon(Icons.library_add_outlined), title: Text(l.addBuiltinPrograms)),
                        ),
                      ],
                ),
              ],
            ],
          ),
          if (_sorting)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.sortHint, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 4),
          if (templates.isEmpty && folders.isEmpty)
            EmptyState(icon: Icons.folder_open_rounded, text: l.noPrograms)
          else if (_sorting)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (a, b) {
                final named = folders.where((f) => f.isNotEmpty).toList();
                if (a >= named.length) return;
                final f = named.removeAt(a);
                named.insert((b > a ? b - 1 : b).clamp(0, named.length), f);
                ref.read(repoProvider)!.saveFolderOrder(named);
              },
              children: [
                for (var i = 0; i < folders.length; i++)
                  _FolderCard(
                    key: ValueKey('f-${folders[i]}'),
                    name: folders[i].isEmpty ? l.noFolder : folders[i],
                    programs: inFolder(folders[i]),
                    open: true,
                    sorting: true,
                    dragIndex: folders[i].isEmpty ? null : i,
                    onToggle: () {},
                    onMenu: null,
                    onReorderPrograms: (list) => _saveOrder(list),
                  ),
              ],
            )
          else
            for (final f in folders)
              _FolderCard(
                key: ValueKey('f-$f'),
                name: f.isEmpty ? l.noFolder : f,
                programs: inFolder(f),
                open: _open.contains(f),
                sorting: false,
                onToggle: () => setState(() => _open.contains(f) ? _open.remove(f) : _open.add(f)),
                onMenu: f.isEmpty ? null : (v) => _folderAction(v, f, all, profile, folders),
                onReorderPrograms: (_) {},
              ),
        ],
      ),
    );
  }

  void _saveOrder(List<WorkoutTemplate> list) {
    ref.read(repoProvider)!.saveTemplates([for (var i = 0; i < list.length; i++) list[i].copyWith(order: i)]);
  }

  Future<void> _newFolder(UserProfile p, List<String> folders) async {
    final l = context.l10n;
    final name = (await askText(context, l.newFolder, hint: l.folderNameHint))?.trim();
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    if (folders.contains(name)) return toast(context, l.folderExists);
    ref.read(repoProvider)!.saveFolderOrder([...folders.where((f) => f.isNotEmpty), name]);
    setState(() => _open.add(name));
  }

  Future<void> _folderAction(String action, String folder, List<WorkoutTemplate> all, UserProfile p, List<String> folders) async {
    final l = context.l10n;
    final repo = ref.read(repoProvider)!;
    final inside = all.where((t) => t.folder == folder).toList();
    final named = folders.where((f) => f.isNotEmpty).toList();
    switch (action) {
      case 'add':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TemplateEditorPage(sport: ref.read(sportFilterProvider) ?? Sport.gym, folder: folder)),
        );
      case 'rename':
        final name = (await askText(context, l.rename, initial: folder))?.trim();
        if (name == null || name.isEmpty || name == folder) return;
        if (named.contains(name)) return mounted ? toast(context, l.folderExists) : null;
        repo.saveTemplates([for (final t in inside) t.copyWith(folder: name)]);
        repo.saveFolderOrder([for (final f in named) f == folder ? name : f]);
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
        repo.saveFolderOrder(named.where((f) => f != folder).toList());
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

  /// Lets the user add (missing) built-in program folders.
  Future<void> _addBuiltins(List<WorkoutTemplate> all) async {
    final l = context.l10n;
    final de = context.localeName.startsWith('de');
    final repo = ref.read(repoProvider)!;
    final missing = missingBuiltins(all, repo.newId, de: de);
    if (missing.isEmpty) return toast(context, l.builtinsComplete);
    final byFolder = <String, List<WorkoutTemplate>>{};
    for (final t in missing) {
      byFolder.putIfAbsent(t.folder, () => []).add(t);
    }
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
                        Text(l.addBuiltinPrograms, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(l.addBuiltinProgramsSub, style: Theme.of(c).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final e in byFolder.entries)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: chosen.contains(e.key),
                                  onChanged: (v) => setS(() => v! ? chosen.add(e.key) : chosen.remove(e.key)),
                                  secondary: SportBadge(e.value.first.sport),
                                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(e.value.map((t) => t.name).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: chosen.isEmpty ? null : () => Navigator.pop(c, true),
                          child: Text(l.addN(chosen.fold<int>(0, (n, f) => n + byFolder[f]!.length))),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (ok != true) return;
    final add = [for (final f in chosen) ...byFolder[f]!];
    repo.saveTemplates(add);
    if (mounted) toast(context, l.programsAdded(add.length));
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    super.key,
    required this.name,
    required this.programs,
    required this.open,
    required this.sorting,
    required this.onToggle,
    required this.onMenu,
    required this.onReorderPrograms,
    this.dragIndex,
  });
  final String name;
  final List<WorkoutTemplate> programs;
  final bool open;
  final bool sorting;
  final int? dragIndex;
  final VoidCallback onToggle;
  final ValueChanged<String>? onMenu;
  final ValueChanged<List<WorkoutTemplate>> onReorderPrograms;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sports = programs.map((t) => t.sport).toSet().toList()..sort((a, b) => a.index.compareTo(b.index));
    final color = sports.length == 1 ? sports.first.color : AppColors.brand;
    final header = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            if (sorting)
              dragIndex == null
                  ? const SizedBox(width: 32)
                  : ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.drag_indicator, color: scheme.outline)),
                  ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
              child: Icon(open ? Icons.folder_open_rounded : Icons.folder_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(l.programsCount(programs.length), style: Theme.of(context).textTheme.bodySmall),
                      for (final s in sports)
                        Padding(padding: const EdgeInsets.only(left: 6), child: Icon(s.icon, size: 14, color: s.color)),
                    ],
                  ),
                ],
              ),
            ),
            if (!sorting)
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded),
              ),
            if (onMenu != null && !sorting)
              PopupMenuButton<String>(
                onSelected: onMenu,
                itemBuilder:
                    (_) => [
                      PopupMenuItem(value: 'add', child: ListTile(leading: const Icon(Icons.add), title: Text(l.newProgram))),
                      PopupMenuItem(value: 'rename', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.rename))),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                          title: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
                        ),
                      ),
                    ],
              )
            else if (!sorting)
              const SizedBox(width: 12),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            header,
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
                                ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(l.folderEmpty, style: Theme.of(context).textTheme.bodySmall),
                                )
                                : sorting
                                ? ReorderableListView(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  onReorder: (a, b) {
                                    final list = [...programs];
                                    final t = list.removeAt(a);
                                    list.insert(b > a ? b - 1 : b, t);
                                    onReorderPrograms(list);
                                  },
                                  children: [
                                    for (var i = 0; i < programs.length; i++)
                                      _TemplateTile(key: ValueKey(programs[i].id), t: programs[i], dragIndex: i),
                                  ],
                                )
                                : Column(children: [for (final t in programs) _TemplateTile(key: ValueKey(t.id), t: t)]),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(sport.icon, color: sport.color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sport.label(l), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(sport == Sport.gym ? l.emptyWorkout : l.recordGps, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: sport.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({super.key, required this.t, this.dragIndex});
  final WorkoutTemplate t;
  final int? dragIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sub =
        t.sport == Sport.gym
            ? '${t.exercises.length} ${l.exercises} · ~${t.estimatedMinutes} min'
            : [
              '~${templateMinutes(t, ref.watch(profileOrDefaultProvider))} min',
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
        case 'move':
          final folders = ref.read(templateListProvider).map((x) => x.folder).where((f) => f.isNotEmpty).toSet().toList()..sort();
          final target = await showModalBottomSheet<String>(
            context: context,
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
          if (target != null && target != t.folder) repo.saveTemplate(t.copyWith(folder: target, order: 999));
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
          onTap:
              dragIndex != null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramPreviewPage(template: t))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.drag_indicator)),
                  ),
                SportBadge(t.sport),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (dragIndex == null) ...[
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
                    onSelected: menu,
                    itemBuilder:
                        (_) => [
                          PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.edit))),
                          PopupMenuItem(value: 'dup', child: ListTile(leading: const Icon(Icons.copy_rounded), title: Text(l.duplicate))),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
