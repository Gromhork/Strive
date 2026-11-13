import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/exercise_measure.dart' show formatHold;
import '../../data/exercise_names_de.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/insights.dart';
import '../../widgets/common.dart';
import '../calendar/auto_adjust.dart' show undoAutoAdjust;
import '../session/route_map.dart';
import 'edit_session_page.dart';
import 'plan_link_card.dart';
import '../session/gym_session_page.dart' show setLabelOf;
import '../../widgets/rpe_picker.dart' show rpeLabel;

class SessionDetailPage extends ConsumerWidget {
  const SessionDetailPage({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final all = ref.watch(sessionListProvider);
    final s = all.where((x) => x.id == sessionId).firstOrNull;
    if (s == null) return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.history_rounded, text: l.sessionGone));
    final u = ref.watch(profileOrDefaultProvider).units;
    final prev = previousComparable(s, all);
    final xp = xpForSession(s);

    String delta(double now, double before, {bool lowerIsBetter = false, String Function(double)? fmt}) {
      final d = now - before;
      if (d.abs() < 0.01) return '±0';
      final better = lowerIsBetter ? d < 0 : d > 0;
      return '${better ? '▲' : '▼'} ${fmt?.call(d.abs()) ?? Units.num(d.abs())}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          IconButton(
            tooltip: l.share,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText(context, s, u))),
          ),
          IconButton(
            tooltip: l.editSession,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionPage(session: s))),
          ),
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (await confirm(context, l.deleteSession, ok: l.delete, danger: true)) {
                final repo = ref.read(repoProvider)!;
                final plans = ref.read(planListProvider);
                repo.deleteSession(s);
                // The planned workout it completed is open again (no dangling link).
                final linked = plans.where((p) => p.sessionId == s.id).toList();
                for (final p in linked) {
                  repo.updatePlan(p.id, {'status': 'planned', 'sessionId': FieldValue.delete()});
                }
                // Automatic adjustments this session triggered no longer have a reason.
                final adjusted = plans.where((p) => p.auto?.sessionId == s.id && !p.isDone).toList();
                undoAutoAdjust(repo, adjusted);
                if (context.mounted) Navigator.pop(context);
                // Undo restores the session, its plan link and the adjustments.
                undoToast(
                  messenger,
                  text: adjusted.isEmpty ? l.deleted : l.deletedAutoReverted(adjusted.length),
                  undoLabel: l.undo,
                  onUndo: () {
                    repo.restoreSession(s);
                    for (final p in linked) {
                      repo.updatePlan(p.id, {'status': 'done', 'sessionId': s.id});
                    }
                    if (adjusted.isNotEmpty) repo.savePlans(adjusted);
                  },
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              SportBadge(s.sport, size: 48, filled: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat.yMMMMEEEEd(context.localeName).add_Hm().format(s.start)),
                    Text(
                      '+$xp XP${s.rpe != null ? ' · RPE ${s.rpe} (${rpeLabel(l, s.rpe!)})' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Wrap(
              runSpacing: 14,
              children: [
                _half(context, StatTile(label: l.duration, value: clock(s.durationSec))),
                if (s.sport == Sport.gym) ...[
                  _half(
                    context,
                    StatTile(
                      key: const ValueKey('detailVolume'),
                      label: l.volume,
                      value: u.volume(s.volume),
                      color: AppColors.gym,
                      caption: volumeCaption(l, s, u),
                    ),
                  ),
                  _half(context, StatTile(label: l.sets, value: '${s.setsDone}')),
                  if (s.holdSec > 0)
                    _half(context, StatTile(key: const ValueKey('detailHold'), label: l.holdTime, value: clock(s.holdSec))),
                  if (s.exercises.any((e) => e.exId != 'manual'))
                    _half(context, StatTile(label: l.exercises, value: '${s.exercises.length}')),
                ] else ...[
                  _half(
                    context,
                    StatTile(
                      label: l.distance,
                      value: s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM),
                      color: s.sport.color,
                    ),
                  ),
                  _half(
                    context,
                    StatTile(label: s.sport.usesPace ? l.avgPace : l.avgSpeed, value: u.paceOrSpeed(s.sport, s.distanceM, s.durationSec)),
                  ),
                  if (s.elevationM > 0)
                    _half(
                      context,
                      StatTile(
                        label: l.elevation,
                        value: u.imperial ? '${(s.elevationM / 0.3048).round()} ft' : '${s.elevationM.round()} m',
                      ),
                    ),
                  if (s.sport == Sport.swim && s.laps > 0) _half(context, StatTile(label: l.laps, value: '${s.laps} × ${s.poolLengthM} m')),
                ],
                if (s.avgHr != null) _half(context, StatTile(label: l.avgHrShort, value: '${s.avgHr} bpm', color: AppColors.danger)),
                if (s.maxHr != null) _half(context, StatTile(label: l.maxHr, value: '${s.maxHr} bpm')),
                if (s.calories != null && s.calories! > 0) _half(context, StatTile(label: l.caloriesLabel, value: '${s.calories} kcal')),
              ],
            ),
          ),
          PlanLinkCard(session: s),
          if (s.fromPlan) ...[
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('fromPlanNote'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.playlist_add_check_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${l.fromPlanBadge} – ${s.sport == Sport.gym ? l.fromPlanNoteGym : l.fromPlanNoteCardio}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (s.source != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.watch_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(l.recordedWith(s.source!), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
          if (s.route.length > 1) ...[
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: 240, child: RouteMap(session: s))),
          ],
          if (s.splits.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: l.splits,
              child: Column(
                children: [
                  for (var i = 0; i < s.splits.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(width: 48, child: Text('km ${i + 1}')),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (s.splits.reduce((a, b) => a < b ? a : b) / s.splits[i]).clamp(0.1, 1.0),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                              color: s.sport.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(clock(s.splits[i])),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (prev != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: l.compareLast,
              trailing: Text(DateFormat.MMMd(context.localeName).format(prev.start), style: Theme.of(context).textTheme.labelSmall),
              child: Column(
                children: [
                  _CompareRow(
                    l.duration,
                    clock(s.durationSec),
                    delta(s.durationSec.toDouble(), prev.durationSec.toDouble(), fmt: (d) => clock(d.round())),
                  ),
                  if (s.sport == Sport.gym)
                    _CompareRow(
                      l.volume,
                      u.volume(s.volume),
                      delta(u.weightOut(s.volume), u.weightOut(prev.volume), fmt: (d) => '${Units.grouped(d)} ${u.weightUnit}'),
                    )
                  // The plan's own numbers are no performance to compare.
                  else if (s.distanceM > 0 && prev.distanceM > 0 && s.measured && prev.measured) ...[
                    _CompareRow(
                      l.distance,
                      s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM),
                      s.sport == Sport.swim
                          ? delta(s.distanceM, prev.distanceM, fmt: (d) => '${d.round()} m')
                          : delta(u.distOut(s.distanceM), u.distOut(prev.distanceM), fmt: (d) => Units.num(d, 2)),
                    ),
                    _CompareRow(
                      s.sport.usesPace ? l.avgPace : l.avgSpeed,
                      u.paceOrSpeed(s.sport, s.distanceM, s.durationSec),
                      // No pace without a duration (a 0-s entry would read as the fastest ever).
                      s.durationSec > 0 && prev.durationSec > 0
                          ? delta(s.durationSec / s.distanceM, prev.durationSec / prev.distanceM, lowerIsBetter: true, fmt: (_) => '')
                          : '',
                    ),
                  ],
                  // The plan's weights are no lift to compare – per exercise (an edited one is measured).
                  if (s.sport == Sport.gym)
                    for (final e in s.exercises.where((e) => !s.exerciseFromPlan(e)))
                      Builder(
                        builder: (_) {
                          final pe = prev.exercises.where((x) => x.exId == e.exId && !prev.exerciseFromPlan(x)).firstOrNull;
                          // Timed holds: the longest hold, like with like.
                          if (pe != null && e.isTimed && e.longestHold > 0 && pe.longestHold > 0) {
                            return _CompareRow(
                              exName(context, e.exId, e.name),
                              formatHold(e.longestHold),
                              delta(e.longestHold.toDouble(), pe.longestHold.toDouble(), fmt: (d) => '${d.round()} s'),
                            );
                          }
                          // Only like with like: a set logged before bodyweight mode existed (or
                          // in the other mode) has no comparable e1RM.
                          if (pe == null || e.bestE1rm <= 0 || pe.bestE1rm <= 0 || (e.bw == true) != (pe.bw == true)) {
                            return const SizedBox.shrink();
                          }
                          return _CompareRow(
                            exName(context, e.exId, e.name),
                            'e1RM ${u.weight(e.bestE1rm, digits: 0)}',
                            delta(u.weightOut(e.bestE1rm), u.weightOut(pe.bestE1rm), fmt: (d) => d.toStringAsFixed(1)),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
          if (s.exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in s.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  title: exName(context, e.exId, e.name),
                  // Timed holds: the time held instead of a (meaningless) kg volume.
                  trailing: Text(
                    e.isTimed ? (e.holdSec > 0 ? clock(e.holdSec) : '') : u.volume(e.volumeAt(s.bodyWeightKg)),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final set in e.sets.where((x) => x.done))
                        Chip(visualDensity: VisualDensity.compact, label: Text('${set.warmup ? 'W · ' : ''}${setLabelOf(l, e, set, u)}')),
                    ],
                  ),
                ),
              ),
          ],
          if (s.notes.isNotEmpty) ...[const SizedBox(height: 12), SectionCard(title: l.notes, child: Text(s.notes))],
        ],
      ),
    );
  }

  String _shareText(BuildContext context, Session s, Units u) {
    final l = context.l10n;
    final parts = [
      '${s.sport.label(l)}: ${s.title}',
      clock(s.durationSec),
      if (s.distanceM > 0) s.sport == Sport.swim ? u.swimDist(s.distanceM) : u.dist(s.distanceM),
      if (s.sport == Sport.gym && s.setsDone > 0) l.setsN(s.setsDone),
      if (s.volume > 0) u.volume(s.volume),
      if (s.holdSec > 0) '${l.holdTime} ${clock(s.holdSec)}',
    ];
    return '${parts.join(' · ')}\n${l.sharedFromStrive}';
  }

  Widget _half(BuildContext c, Widget w) => SizedBox(width: (MediaQuery.sizeOf(c).width - 64) / 2, child: w);
}

/// Caption of a gym volume ([Session.volume]) that contains body weight: "incl. body weight (80 kg)";
/// null when no bodyweight exercise counts.
String? volumeCaption(AppLocalizations l, Session s, Units u) {
  if (!s.volumeCountsBody) return null;
  final kg = s.bodyWeightKg;
  return kg == null || kg <= 0 ? l.volumeInclBody : l.volumeInclBodyKg(u.weight(kg, digits: 0));
}

class _CompareRow extends StatelessWidget {
  const _CompareRow(this.label, this.value, this.delta);
  final String label, value, delta;

  @override
  Widget build(BuildContext context) {
    final color = delta.startsWith('▲') ? AppColors.success : (delta.startsWith('▼') ? AppColors.danger : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(delta, textAlign: TextAlign.right, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
