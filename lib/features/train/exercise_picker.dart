import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/exercise_db.dart';
import '../../data/exercise_names_de.dart';
import '../../providers.dart';
import '../../widgets/exercise_media.dart';
import 'exercise_detail_page.dart';

/// Opens the library in selection mode and returns the chosen exercises.
Future<List<Exercise>> pickExercises(BuildContext context, {bool single = false}) async {
  final r = await Navigator.push<List<Exercise>>(
    context,
    MaterialPageRoute(builder: (_) => ExerciseLibraryPage(selectMode: true, single: single)),
  );
  return r ?? const [];
}

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key, this.selectMode = false, this.single = false});
  final bool selectMode;
  final bool single;

  @override
  ConsumerState<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  String _q = '';
  String? _body;
  String? _equip;
  final _selected = <Exercise>[];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final dbAsync = ref.watch(exerciseDbProvider);
    final records = ref.watch(sessionListProvider).expand((s) => s.exercises.map((e) => e.exId)).toSet();
    return Scaffold(
      appBar: AppBar(title: Text(widget.selectMode ? l.addExercise : l.exerciseLibrary)),
      floatingActionButton:
          widget.selectMode && _selected.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check),
                label: Text(l.addN(_selected.length)),
              )
              : null,
      body: dbAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    Text(l.exerciseLoadError, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('$e', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: () => ref.invalidate(exerciseDbProvider), child: Text(l.retry)),
                  ],
                ),
              ),
            ),
        data: (db) {
          var list = db.search(_q, bodyPart: _body, equipment: _equip, lang: lang);
          // Exercises the user already did come first when not searching.
          if (_q.isEmpty) {
            list = [...list.where((e) => records.contains(e.id)), ...list.where((e) => !records.contains(e.id))];
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  autofocus: widget.selectMode,
                  decoration: InputDecoration(hintText: l.searchExercises, prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterMenu(
                      label: _body == null ? l.bodyPart : term(_body!, lang),
                      active: _body != null,
                      options: db.bodyPartsFor(lang),
                      lang: lang,
                      onSelected: (v) => setState(() => _body = v),
                    ),
                    const SizedBox(width: 8),
                    _FilterMenu(
                      label: _equip == null ? l.equipment : term(_equip!, lang),
                      active: _equip != null,
                      options: db.equipmentFor(lang),
                      lang: lang,
                      onSelected: (v) => setState(() => _equip = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.nResults(list.length), style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final sel = _selected.contains(e);
                    final name = exerciseName(e.id, e.name, lang);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: ExerciseMedia(exId: e.id, animated: false, size: 52, radius: 14, done: sel),
                      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      // Target muscle · equipment (the English name is only a search alias,
                      // shown on the detail page).
                      subtitle: Text(exerciseSubtitle(e, lang), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: records.contains(e.id) ? const Icon(Icons.history, size: 18) : null,
                      onTap: () {
                        if (widget.selectMode && widget.single) {
                          Navigator.pop(context, [e]);
                        } else if (widget.selectMode) {
                          setState(() => sel ? _selected.remove(e) : _selected.add(e));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: e)));
                        }
                      },
                      onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: e))),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.label, required this.active, required this.options, required this.lang, required this.onSelected});
  final String label;
  final bool active;
  final List<String> options;
  final String lang;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: (v) => onSelected(v == '' ? null : v),
      itemBuilder:
          (_) => [
            PopupMenuItem(value: '', child: Text(context.l10n.all)),
            for (final o in options) PopupMenuItem(value: o, child: Text(term(o, lang))),
          ],
      child: Chip(
        label: Text(label),
        avatar: Icon(Icons.filter_list, size: 16, color: active ? AppColors.brand : null),
        side: BorderSide(color: active ? AppColors.brand : Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
