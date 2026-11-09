import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/step_progress.dart';
import '../../services/tracker.dart';
import '../../widgets/common.dart';
import 'session_summary_page.dart';
import 'step_list.dart';
import 'step_text.dart';
import 'zone_info.dart' show showSwimDrills;

/// Live recording screen for runs, rides and swims.
///
/// Layout (top → bottom): status bar · step card (structured workouts) ·
/// big metric · 2×3 metric grid · pace chart vs. target band · controls.
/// Swipe left for the map (outdoor only), again for splits. Lock mode blocks touches.
///
/// * Rides: speed is the big number (bike-computer style), power/HR targets as chips;
///   indoor rides are purely time based (big clock, workout time left).
/// * Pool swims: no GPS – a big LENGTH button in the controls counts lengths, the step
///   card shows the current set ("Interval 2/8 · 8 × 100 m · CSS") and what comes next.
class CardioSessionPage extends ConsumerStatefulWidget {
  const CardioSessionPage({super.key});
  @override
  ConsumerState<CardioSessionPage> createState() => _CardioSessionPageState();
}

class _CardioSessionPageState extends ConsumerState<CardioSessionPage> {
  final _map = MapController();
  final _pages = PageController();
  bool _follow = true;
  bool _locked = false;
  int _page = 0;
  int? _lastStep;

  Future<void> _stop(CardioState s) async {
    final l = context.l10n;
    final n = ref.read(trackerProvider.notifier);
    n.pause();
    final u = ref.read(profileOrDefaultProvider).units;
    double? manual;
    if (s.indoor && s.sport != Sport.swim) {
      final v = await askNumber(context, l.enterDistance, suffix: u.distUnit);
      if (v == null) return;
      manual = u.distIn(v);
    }
    if (!mounted) return;
    final session = n.finish(ref.read(repoProvider)!.newId(), manualDistanceM: manual);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SessionSummaryPage(draft: session)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(trackerProvider);
    if (s == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noActiveWorkout)));
    final n = ref.read(trackerProvider.notifier);
    final last = s.points.isNotEmpty ? s.points.last : null;
    if (_follow && last != null && _page == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _map.move(last, _map.camera.zoom < 13 ? 16 : _map.camera.zoom);
        } catch (_) {}
      });
    }
    // Step change banner (not in the pool: it would cover the LENGTH button).
    if (_lastStep != null && _lastStep != s.stepIndex && s.step != null && !s.poolMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showStepBanner(s));
    }
    _lastStep = s.stepIndex;
    final pausedTint = s.paused ? AppColors.warning.withValues(alpha: 0.08) : null;

    return PopScope(
      canPop: !_locked,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Color.alphaBlend(pausedTint ?? Colors.transparent, Theme.of(context).scaffoldBackgroundColor),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), onPressed: () => Navigator.pop(context)),
              titleSpacing: 0,
              title: Row(
                children: [
                  Flexible(child: Text(s.title, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  if (!s.indoor) _GpsChip(accuracy: s.accuracy, error: s.gpsError, hasFix: last != null),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l.music,
                  icon: const Icon(Icons.music_note_rounded, color: Color(0xFF1DB954)),
                  onPressed: () => showMusicSheet(context, ref, s),
                ),
                IconButton(
                  tooltip: l.voiceCues,
                  icon: Icon(s.voice ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded),
                  onPressed: n.toggleVoice,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'lock') setState(() => _locked = true);
                    if (v == 'skip') n.skipStep();
                    if (v == 'discard' && await confirm(context, l.discardWorkout, ok: l.discard, danger: true)) {
                      n.discard();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder:
                      (_) => [
                        PopupMenuItem(
                          value: 'lock',
                          child: ListTile(dense: true, leading: const Icon(Icons.lock_outline), title: Text(l.lockScreen)),
                        ),
                        if (s.step != null)
                          PopupMenuItem(
                            value: 'skip',
                            child: ListTile(dense: true, leading: const Icon(Icons.skip_next_rounded), title: Text(l.skipStep)),
                          ),
                        PopupMenuItem(
                          value: 'discard',
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                            title: Text(l.discardWorkout),
                          ),
                        ),
                      ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (s.paused)
                  Container(
                    width: double.infinity,
                    color: AppColors.warning,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      s.autoPaused ? l.autoPaused : l.paused,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                    ),
                  ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _MetricsPage(s: s),
                      if (!s.indoor) _MapPage(s: s, controller: _map, follow: _follow, onFollow: (v) => setState(() => _follow = v)),
                      _SplitsPage(s: s),
                    ],
                  ),
                ),
                _PageDots(count: s.indoor ? 2 : 3, index: _page),
                _Controls(s: s, onStop: () => _stop(s)),
              ],
            ),
          ),
          if (_locked) Positioned.fill(child: _LockOverlay(onUnlock: () => setState(() => _locked = false))),
        ],
      ),
    );
  }

  void _showStepBanner(CardioState s) {
    if (!mounted) return;
    final l = context.l10n;
    final u = ref.read(profileOrDefaultProvider).units;
    final st = s.step;
    if (st == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: zoneColor(st.zone),
          content: Text(
            stepSentence(l, s.steps, s.stepIndex, u, s.sport),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );
  }
}

// ───────────────────────────── Metrics page ─────────────────────────────

class _MetricsPage extends ConsumerWidget {
  const _MetricsPage({required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (s.poolMode) return _PoolMetrics(s: s);
    if (s.sport == Sport.ride) return _RideMetrics(s: s);
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final p = ref.watch(profileOrDefaultProvider);
    final dist = s.effectiveDistance;
    final swim = s.sport == Sport.swim;
    // Big metric: live pace during a paced step, else distance.
    final showPaceBig = s.step?.paceMin != null;
    final paceUnit = swim ? '/100 m' : (u.imperial ? '/mi' : '/km');
    String livePace() {
      final p = s.targetPace;
      return p == null ? '–:––' : fmtPaceSec(p, u, swim: swim);
    }

    final kcal = (p.weightKg * (swim ? 0.6 : 1.0) * dist / 1000).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        if (s.structured) _StepCard(s: s),
        if (!s.structured && !swim) _FreeHint(s: s),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  showPaceBig ? livePace() : Units.num(u.distOut(dist), 2),
                  style: TextStyle(
                    // Smaller with a step card so all metric tiles stay visible.
                    fontSize: s.structured ? 64 : 88,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: showPaceBig ? _paceColor(s.paceStatus) : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                showPaceBig ? '${l.currentPace} ($paceUnit)' : '${l.distance} (${u.distUnit})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        SizedBox(height: s.structured ? 10 : 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: s.structured ? 1.6 : 1.35,
          children: [
            _Cell(value: clock(s.elapsed), label: l.duration),
            if (showPaceBig)
              _Cell(value: Units.num(u.distOut(dist), 2), label: '${l.distance} (${u.distUnit})', color: s.sport.color)
            else
              _Cell(value: livePace(), label: l.currentPace, color: s.sport.color),
            _Cell(value: u.paceOrSpeed(s.sport, dist, s.elapsed), label: l.avgPace),
            _Cell(value: s.splits.isEmpty ? '–' : clock(s.splits.last), label: l.lastSplit),
            _Cell(value: s.indoor ? '–' : '${s.elevationM.round()} m', label: l.elevation),
            _Cell(value: '$kcal', label: 'kcal'),
          ],
        ),
        if (s.paceHistory.length >= 3) ...[const SizedBox(height: 12), SizedBox(height: 90, child: _PaceChart(s: s))],
      ],
    );
  }
}

/// Cycling: speed is the big number (bike-computer style). Indoor rides have no
/// speed source, so they show the clock and the remaining workout time instead.
class _RideMetrics extends ConsumerWidget {
  const _RideMetrics({required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final u = p.units;
    final dist = s.effectiveDistance;
    final speedUnit = u.imperial ? 'mph' : 'km/h';
    String speedOf(int? pace) => pace == null || pace <= 0 ? '0.0' : u.distOut(3600000 / pace).toStringAsFixed(1);

    final avg = s.elapsed > 0 && dist > 0 ? (u.distOut(dist) / (s.elapsed / 3600)).toStringAsFixed(1) : '–';
    // Outdoor: ~0.28 kcal per kg and km; indoor: ~7 MET (moderate trainer ride).
    final kcal = (s.indoor ? p.weightKg * 7 * s.elapsed / 3600 : p.weightKg * 0.28 * dist / 1000).round();
    final big = s.indoor ? clock(s.elapsed) : speedOf(s.currentPace);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        if (s.structured) _StepCard(s: s) else _FreeHint(s: s),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  big,
                  style: const TextStyle(
                    fontSize: 88,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(s.indoor ? l.duration : '${l.currentSpeed} ($speedUnit)', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (s.indoor)
          _CellRow(
            cells: [
              if (s.structured) _Cell(value: s.stepsDone ? '0:00' : clock(s.workoutLeftSec), label: l.workoutLeft, color: s.sport.color),
              if (s.structured) _Cell(value: '${min(s.stepIndex + 1, s.steps.length)}/${s.steps.length}', label: l.section),
              _Cell(value: '$kcal', label: 'kcal'),
            ],
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              _Cell(value: clock(s.elapsed), label: l.duration),
              _Cell(value: Units.num(u.distOut(dist), 2), label: '${l.distance} (${u.distUnit})', color: s.sport.color),
              _Cell(value: avg, label: l.avgSpeed),
              _Cell(value: s.bestPace == null ? '–' : speedOf(s.bestPace), label: l.maxSpeed),
              _Cell(value: '${s.elevationM.round()} m', label: l.elevation),
              _Cell(value: '$kcal', label: 'kcal'),
            ],
          ),
        if (!s.indoor && s.paceHistory.length >= 3) ...[const SizedBox(height: 12), SizedBox(height: 80, child: _PaceChart(s: s))],
        if (s.structured && !s.stepsDone) ...[const SizedBox(height: 12), _Upcoming(s: s)],
      ],
    );
  }
}

/// Pool swim: current set, what comes next, length count and per-100 m pace.
/// The LENGTH button itself lives in the controls so it is reachable from every page.
class _PoolMetrics extends ConsumerWidget {
  const _PoolMetrics({required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final u = p.units;
    final dist = s.effectiveDistance;
    String pace(int? v) => v == null ? '–:––' : fmtPaceSec(v, u, swim: true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        if (s.structured) ...[
          _StepCard(s: s),
          if (!s.stepsDone) ...[const SizedBox(height: 10), _Upcoming(s: s)],
        ] else ...[
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                FittedBox(
                  child: Text(
                    u.swimDist(dist),
                    style: const TextStyle(
                      fontSize: 76,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.nLengths(s.laps), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(l.poolTapHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _CellRow(
          cells: [
            _Cell(value: clock(s.elapsed), label: l.duration),
            if (s.structured) _Cell(value: u.swimDist(dist), label: l.distance, color: s.sport.color),
            if (!s.structured) _Cell(value: '${s.laps}', label: l.lengths, color: s.sport.color),
            _Cell(value: pace(s.swimPace100), label: l.pace100, color: _paceColor(s.paceStatus)),
          ],
        ),
        const SizedBox(height: 8),
        _CellRow(
          cells: [
            if (s.structured) _Cell(value: '${s.laps}', label: l.lengths),
            _Cell(value: s.lengthSecs.isEmpty ? '–' : clock(s.lengthSecs.last), label: l.lastLength),
            _Cell(value: pace(s.avgSwimPace100), label: l.avgPace100),
            if (!s.structured) _Cell(value: '${(p.weightKg * 0.6 * dist / 1000).round()}', label: 'kcal'),
          ],
        ),
      ],
    );
  }
}

Color? _paceColor(int? status) => switch (status) {
  0 => AppColors.success,
  -1 => AppColors.swim,
  1 => AppColors.warning,
  _ => null,
};

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.label, this.color});
  final String value, label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        // Long labels ("Rest der Einheit") shrink instead of being cut off.
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1)),
      ],
    ),
  );
}

/// A row of equally wide metric cells with a fixed height (1–3 cells).
class _CellRow extends StatelessWidget {
  const _CellRow({required this.cells});
  final List<Widget> cells;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: cells[i])],
      ],
    ),
  );
}

/// Current step: "INTERVAL 3/6 · 650 m left · 4:05–4:15 /km · Zone 4" + next step.
/// Rides show power/HR targets as chips; swims show the set ("8 × 100 m · CSS") and lengths left.
class _StepCard extends ConsumerWidget {
  const _StepCard({required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    if (s.stepsDone || s.step == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(switch (s.sport) {
                Sport.ride => l.allStepsDoneRide,
                Sport.swim => l.allStepsDoneSwim,
                _ => l.allStepsDone,
              }, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      );
    }
    final st = s.step!;
    final c = zoneColor(st.zone);
    final run = s.sport == Sport.run;
    final ride = s.sport == Sport.ride;
    final (m, sec) = s.stepRemaining;
    final remaining =
        m != null
            ? (m >= 1000 && s.sport != Sport.swim ? '${Units.num(u.distOut(m), 2)} ${u.distUnit}' : '${m.round()} m')
            : (sec != null ? clock(sec) : clock(s.stepElapsed));
    final lengthsLeft = s.lengthsLeft;
    final target = stepTarget(l, st, u, s.sport);
    final next = s.nextStep;
    final status = s.paceStatus;
    final setLabel = stepSetLabel(l, s.steps, s.stepIndex, u, s.sport);
    final rest = st.kind == 'recovery';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.32), c.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  stepTitle(l, s.steps, s.stepIndex, sport: s.sport).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13),
                ),
              ),
              if (!run && !rest) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    setLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ] else
                const Spacer(),
              if (status != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: _paceColor(status), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    status == 0 ? l.onPace : (status < 0 ? l.tooFast : l.tooSlow),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                remaining,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    [
                      if (m != null || sec != null) l.left,
                      if (lengthsLeft != null) l.nLengths(lengthsLeft) else if (!rest || run) zoneLabel(l, st.zone, sport: s.sport),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (ride && (st.powerMin != null || st.hrMin != null)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (st.powerMin != null && st.powerMax != null)
                  _TargetChip(icon: Icons.bolt_rounded, text: '${st.powerMin}–${st.powerMax} W', color: c),
                if (st.hrMin != null && st.hrMax != null)
                  _TargetChip(icon: Icons.favorite_rounded, text: '${st.hrMin}–${st.hrMax} bpm', color: c),
              ],
            ),
          ] else if (target.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(target, style: const TextStyle(fontSize: 13)),
          ],
          if (st.note.isNotEmpty && st.zone == 'DR')
            // Technique drills: tap for the how-to of every drill.
            InkWell(
              onTap: () => showSwimDrills(context),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      st.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            )
          else if (st.note.isNotEmpty)
            Text(
              st.note,
              maxLines: run ? null : 1,
              overflow: run ? null : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: s.stepProgress, minHeight: 6, color: c, backgroundColor: c.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: 8),
          WorkoutProfileBar(steps: s.steps, sport: s.sport, height: 22, current: s.stepIndex),
          // Runs: one "up next" line. Rides/swims show the upcoming list below the card.
          if (run && next != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${l.upNext}: ${stepSentence(l, s.steps, s.stepIndex + 1, u, s.sport)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()])),
      ],
    ),
  );
}

/// Next few steps of a structured ride / swim, plus the estimated rest of the workout.
class _Upcoming extends ConsumerWidget {
  const _Upcoming({required this.s});
  final CardioState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final t = Theme.of(context).textTheme;
    final first = s.stepIndex + 1;
    final last = min(s.steps.length, first + 3);
    final leftM = s.poolMode ? workoutRemainingM(s.steps, s.stepIndex, stepDistance: s.stepDistance) : null;
    final left = [if (leftM != null && leftM > 0) u.swimDist(leftM), '≈ ${clock(s.workoutLeftSec)}'].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.upNext.toUpperCase(), style: t.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              const Spacer(),
              Flexible(child: Text('${l.workoutLeft}: $left', style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (first >= s.steps.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(l.finish, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          for (var i = first; i < last; i++)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: zoneColor(s.steps[i].zone), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stepTitle(l, s.steps, i, sport: s.sport),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: i == first ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.steps[i].kind == 'recovery' && s.sport == Sport.swim
                        ? stepAmount(s.steps[i], u, s.sport)
                        : '${stepAmount(s.steps[i], u, s.sport)} · ${zoneLabel(l, s.steps[i].zone, sport: s.sport)}',
                    style: t.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Free (unstructured) workouts: friendly hint with HR zone 2 guidance.
class _FreeHint extends ConsumerWidget {
  const _FreeHint({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final max = p.estimatedMaxHr;
    // Cycling HR runs ~5–10 bpm lower than running at the same effort.
    final text =
        s.sport == Sport.ride
            ? l.freeRideHint((max * 0.68).round(), (max * 0.78).round())
            : l.freeRunHint((max * 0.72).round(), (max * 0.82).round());
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.sport.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: s.sport.color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Live pace (runs: sec/km, open-water swims: sec/100 m, inverted so faster is higher)
/// vs. the target band, or live speed for rides.
class _PaceChart extends ConsumerWidget {
  const _PaceChart({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = s.sport == Sport.ride;
    final swim = s.sport == Sport.swim;
    final st = s.step;
    final List<double> h;
    double lo, hi;
    double Function(double) y;
    if (ride) {
      h = s.paceHistory.map((p) => (3600 / p).clamp(0, 90).toDouble()).toList();
      lo = max(0, h.reduce(min) - 3);
      hi = h.reduce(max) + 3;
      y = (v) => v;
    } else {
      h = s.paceHistory.map((p) => (swim ? p / 10 : p).clamp(swim ? 40 : 120, swim ? 400 : 900).toDouble()).toList();
      lo = [...h, if (st?.paceMin != null) st!.paceMin!.toDouble()].reduce(min) - (swim ? 5 : 15);
      hi = [...h, if (st?.paceMax != null) st!.paceMax!.toDouble()].reduce(max) + (swim ? 5 : 15);
      // Inverted axis: faster pace (smaller number) is drawn higher.
      final a = lo, b = hi;
      y = (pace) => b - pace + a;
    }
    return LineChart(
      LineChartData(
        minY: lo,
        maxY: hi,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (!ride && st?.paceMin != null && st?.paceMax != null)
              HorizontalRangeAnnotation(
                y1: y(st!.paceMax!.toDouble()),
                y2: y(st.paceMin!.toDouble()),
                color: AppColors.success.withValues(alpha: 0.18),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < h.length; i++) FlSpot(i.toDouble(), y(h[i]))],
            isCurved: true,
            barWidth: 3,
            color: s.sport.color,
            dotData: const FlDotData(show: false),
            belowBarData: ride ? BarAreaData(show: true, color: s.sport.color.withValues(alpha: 0.12)) : BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Map & splits ─────────────────────────────

class _MapPage extends StatelessWidget {
  const _MapPage({required this.s, required this.controller, required this.follow, required this.onFollow});
  final CardioState s;
  final MapController controller;
  final bool follow;
  final ValueChanged<bool> onFollow;

  @override
  Widget build(BuildContext context) {
    final last = s.points.isNotEmpty ? s.points.last : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: last ?? const LatLng(51.1657, 10.4515),
                initialZoom: last == null ? 5 : 16,
                onPositionChanged: (_, gesture) {
                  if (gesture && follow) onFollow(false);
                },
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.gromhork.strive'),
                if (s.points.length > 1) PolylineLayer(polylines: [Polyline(points: s.points, strokeWidth: 5, color: s.sport.color)]),
                if (last != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: last,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: s.sport.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Consumer(
                builder: (context, ref, _) {
                  final u = ref.watch(profileOrDefaultProvider).units;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MapStat(clock(s.elapsed)),
                        _MapStat('${Units.num(u.distOut(s.effectiveDistance), 2)} ${u.distUnit}'),
                        _MapStat(u.paceOrSpeed(s.sport, s.effectiveDistance, s.elapsed)),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (!follow)
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(onPressed: () => onFollow(true), child: const Icon(Icons.my_location)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapStat extends StatelessWidget {
  const _MapStat(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
  );
}

class _SplitsPage extends ConsumerWidget {
  const _SplitsPage({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    // Pool: lengths instead of km splits.
    final rows = s.poolMode ? _lengthRows(context, s) : (s.splits.isEmpty ? <Widget>[] : _splitRows(context, s, u));
    if (s.structured) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.workoutStructure, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          WorkoutProfileBar(steps: s.steps, sport: s.sport, current: s.stepIndex),
          const SizedBox(height: 12),
          StepList(steps: s.steps, sport: s.sport, units: u, current: s.stepIndex),
          if (rows.isNotEmpty) ...[const Divider(height: 32), ...rows],
        ],
      );
    }
    if (rows.isEmpty) {
      return Center(child: Text(s.poolMode ? l.noLengthsYet : l.noSplitsYet, style: Theme.of(context).textTheme.bodySmall));
    }
    return ListView(padding: const EdgeInsets.all(16), children: rows);
  }

  /// One bar per value; [best] is highlighted, faster values get longer bars.
  List<Widget> _bars(BuildContext context, List<int> values, String Function(int) label, {int first = 1}) {
    final best = values.reduce(min);
    final worst = values.reduce(max);
    return [
      for (var i = 0; i < values.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('${i + first}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                child: LayoutBuilder(
                  builder:
                      (_, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 20,
                          width: c.maxWidth * (0.35 + 0.65 * (worst == best ? 1 : (worst - values[i]) / (worst - best))),
                          decoration: BoxDecoration(
                            color: values[i] == best ? AppColors.success : s.sport.color.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: Text(
                  label(values[i]),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// Km splits: time per km (run/swim) or speed (ride).
  List<Widget> _splitRows(BuildContext context, CardioState s, Units u) {
    if (s.sport != Sport.ride) return _bars(context, s.splits, clock);
    return _bars(context, s.splits, (sec) => '${(3600 / sec).toStringAsFixed(1)} km/h');
  }

  /// Pool: time per length, newest first (most recent is what a swimmer checks).
  List<Widget> _lengthRows(BuildContext context, CardioState s) {
    if (s.lengthSecs.isEmpty) return const [];
    final l = context.l10n;
    final recent = s.lengthSecs.length > 60 ? s.lengthSecs.sublist(s.lengthSecs.length - 60) : s.lengthSecs;
    return [
      Text(l.lengths, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      ..._bars(context, recent, clock, first: s.lengthSecs.length - recent.length + 1).reversed,
    ];
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});
  final int count, index;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          width: i == index ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == index ? AppColors.brand : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

// ───────────────────────────── Controls ─────────────────────────────

class _Controls extends ConsumerWidget {
  const _Controls({required this.s, required this.onStop});
  final CardioState s;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.read(trackerProvider.notifier);
    final pool = s.poolMode;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pool) ...[_LengthButton(s: s, onTap: n.lap), const SizedBox(height: 10)],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (s.paused)
                  _HoldToFinish(label: l.holdToFinish, onDone: onStop)
                else if (pool)
                  _RoundButton(icon: Icons.undo_rounded, label: l.undoLength, onTap: s.laps == 0 ? null : n.undoLap)
                else
                  _RoundButton(icon: Icons.flag_outlined, label: l.roundLap, onTap: n.lap),
                SizedBox(
                  width: pool ? 76 : 88,
                  height: pool ? 76 : 88,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: s.paused ? AppColors.success : s.sport.color,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      s.paused ? n.resume() : n.pause();
                    },
                    child: Icon(s.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 44),
                  ),
                ),
                _RoundButton(
                  icon: Icons.skip_next_rounded,
                  label: l.skipStep,
                  onTap: s.step == null ? null : n.skipStep,
                  // Structured rides/swims: make "next section" stand out.
                  highlight: s.structured && s.sport != Sport.run ? s.sport.color : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pool: big "LENGTH +25 m" button with the length count – tap at every wall.
class _LengthButton extends StatelessWidget {
  const _LengthButton({required this.s, required this.onTap});
  final CardioState s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.swim,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.swim.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        onPressed: s.paused ? null : onTap,
        child: Row(
          children: [
            const Icon(Icons.add_circle_rounded, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.lengthBtn.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1.1),
                  ),
                  Text('+${s.poolLengthM} m', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Text(
              '${s.laps}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.highlight});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? highlight;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 92,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child:
              highlight != null
                  ? IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: highlight, foregroundColor: Colors.black),
                    onPressed: onTap,
                    icon: Icon(icon, size: 30),
                  )
                  : IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
        ),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelSmall)),
      ],
    ),
  );
}

/// Finish requires a 1.2 s hold to avoid accidental stops.
class _HoldToFinish extends StatefulWidget {
  const _HoldToFinish({required this.label, required this.onDone});
  final String label;
  final VoidCallback onDone;
  @override
  State<_HoldToFinish> createState() => _HoldToFinishState();
}

class _HoldToFinishState extends State<_HoldToFinish> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..addStatusListener((s) {
    if (s == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      widget.onDone();
    }
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTapDown: (_) => _c.forward(from: 0),
        onTapUp: (_) => _c.reverse(),
        onTapCancel: () => _c.reverse(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: AnimatedBuilder(
            animation: _c,
            builder:
                (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(child: CircularProgressIndicator(value: _c.value, strokeWidth: 4, color: AppColors.danger)),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.stop_rounded, color: Colors.white),
                    ),
                  ],
                ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      SizedBox(
        width: 92,
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.label, maxLines: 1, style: Theme.of(context).textTheme.labelSmall)),
        ),
      ),
    ],
  );
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.onUnlock});
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: Container(
      color: Colors.black.withValues(alpha: 0.25),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 140),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onUnlock();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(context.l10n.holdToUnlock, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({this.accuracy, this.error, required this.hasFix});
  final double? accuracy;
  final String? error;
  final bool hasFix;

  @override
  Widget build(BuildContext context) {
    final good = hasFix && (accuracy ?? 99) < 20;
    final color = error != null ? AppColors.danger : (good ? AppColors.success : AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            hasFix ? '±${accuracy?.round() ?? '?'} m' : 'GPS…',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Music (Spotify) ─────────────────────────────

/// Opens Spotify with running playlists matched to the workout (by tempo / BPM),
/// or the user's own playlist link.
Future<void> showMusicSheet(BuildContext context, WidgetRef ref, CardioState s) {
  final l = context.l10n;
  final prefs = ref.read(prefsProvider);
  final own = prefs.getString('spotifyPlaylist');
  final zone = s.step?.zone ?? (s.structured ? 'E' : 'E');
  final (bpm, label) = switch (zone) {
    'I' || 'R' || 'Z5' => (180, l.musicIntervals),
    'T' || 'M' || 'SS' || 'Z4' => (170, l.musicTempo),
    _ => (s.sport == Sport.ride ? 130 : 160, l.musicEasy),
  };
  // Spotify search terms (not shown in the UI).
  final activity = switch (s.sport) {
    Sport.ride => 'cycling',
    Sport.swim => 'swimming',
    _ => 'running',
  };
  Future<void> open(String uri, String web) async {
    if (!await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> search(String q) =>
      open('spotify:search:${Uri.encodeComponent(q)}', 'https://open.spotify.com/search/${Uri.encodeComponent(q)}');

  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Color(0xFF1DB954), size: 28),
                    const SizedBox(width: 8),
                    Text('Spotify', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l.musicSub, style: Theme.of(c).textTheme.bodySmall),
                const SizedBox(height: 12),
                _MusicTile(
                  icon: Icons.auto_awesome,
                  title: l.musicForNow(label),
                  sub: '$bpm BPM',
                  onTap: () => search('$activity $bpm bpm'),
                ),
                _MusicTile(icon: s.sport.icon, title: l.musicEasy, sub: '150–160 BPM', onTap: () => search('easy $activity 155 bpm')),
                _MusicTile(icon: Icons.speed, title: l.musicTempo, sub: '165–175 BPM', onTap: () => search('tempo $activity 170 bpm')),
                _MusicTile(
                  icon: Icons.bolt,
                  title: l.musicIntervals,
                  sub: '175–185 BPM',
                  onTap: () => search('$activity intervals 180 bpm'),
                ),
                _MusicTile(icon: Icons.podcasts, title: l.musicPodcasts, sub: l.musicPodcastsSub, onTap: () => search('$activity podcast')),
                const Divider(),
                if (own != null && own.isNotEmpty)
                  _MusicTile(
                    icon: Icons.favorite,
                    title: l.musicOwn,
                    sub: own,
                    onTap: () => open(own.replaceFirst('https://open.spotify.com/', 'spotify:').replaceAll('/', ':'), own),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.link),
                  label: Text(own == null ? l.musicSetOwn : l.musicChangeOwn),
                  onPressed: () async {
                    final v = await askText(c, l.musicSetOwn, initial: own ?? 'https://open.spotify.com/playlist/');
                    if (v != null) prefs.setString('spotifyPlaylist', v.split('?').first.trim());
                    if (c.mounted) Navigator.pop(c);
                  },
                ),
              ],
            ),
          ),
        ),
  );
}

class _MusicTile extends StatelessWidget {
  const _MusicTile({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.18),
      child: Icon(icon, color: const Color(0xFF1DB954)),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: onTap,
  );
}
