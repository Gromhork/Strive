import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../session/manual_entry_page.dart';
import '../session/start_helpers.dart';
import 'exercise_picker.dart';
import 'template_editor_page.dart';

class TrainPage extends ConsumerWidget {
  const TrainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final filter = ref.watch(sportFilterProvider);
    final templates = ref.watch(templateListProvider).where((t) => filter == null || t.sport == filter).toList();
    final folders = <String, List<WorkoutTemplate>>{};
    for (final t in templates) {
      folders.putIfAbsent(t.folder.isEmpty ? l.noFolder : t.folder, () => []).add(t);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newTemplate',
        onPressed:
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditorPage(sport: filter ?? Sport.gym))),
        icon: const Icon(Icons.add),
        label: Text(l.newProgram),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryPage())),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(l.logManually),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseLibraryPage())),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(l.exercises),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(l.programs, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () => _import(context, ref),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(l.importCode),
              ),
            ],
          ),
          if (templates.isEmpty)
            EmptyState(icon: Icons.folder_open_rounded, text: l.noPrograms)
          else
            for (final f in (folders.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${f.value.length}'),
                  children: [for (final t in f.value) _TemplateTile(t: t)],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final code = await askText(context, l.importCode, hint: 'ABC123');
    if (code == null || code.isEmpty) return;
    try {
      final t = await ref.read(repoProvider)!.importTemplate(code);
      if (context.mounted) toast(context, t == null ? l.codeNotFound : l.imported(t.name));
    } catch (e) {
      if (context.mounted) toast(context, l.offlineAction);
    }
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
  const _TemplateTile({required this.t});
  final WorkoutTemplate t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sub =
        t.sport == Sport.gym
            ? '${t.exercises.length} ${l.exercises} · ~${t.estimatedMinutes} min'
            : [if (t.targetMin != null) '${t.targetMin} min', intensityLabel(l, t.intensity)].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: SportBadge(t.sport),
          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditorPage(template: t))),
          trailing: IconButton.filledTonal(
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed:
                () =>
                    t.sport == Sport.gym
                        ? startGym(context, ref, title: t.name, template: t)
                        : showCardioStart(context, ref, t.sport, title: t.name),
          ),
        ),
      ),
    );
  }
}
