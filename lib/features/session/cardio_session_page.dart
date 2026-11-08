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
import '../../services/tracker.dart';
import '../../widgets/common.dart';
import 'session_summary_page.dart';
import 'step_list.dart';
import 'step_text.dart';

/// Live recording screen for runs, rides and swims.
///
/// Layout (top → bottom): status bar · step card (structured workouts) ·
/// big metric · 2×3 metric grid · pace chart vs. target band · controls.
/// Swipe left for the map, again for splits. Lock mode blocks touches.
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
    // Step change banner.
    if (_lastStep != null && _lastStep != s.stepIndex && s.step != null) {
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
                        PopupMenuItem(value: 'lock', child: ListTile(dense: true, leading: const Icon(Icons.lock_outline), title: Text(l.lockScreen))),
                        if (s.step != null)
                          PopupMenuItem(value: 'skip', child: ListTile(dense: true, leading: const Icon(Icons.skip_next_rounded), title: Text(l.skipStep))),
                        PopupMenuItem(
                          value: 'discard',
                          child: ListTile(dense: true, leading: const Icon(Icons.delete_outline, color: AppColors.danger), title: Text(l.discardWorkout)),
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
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final p = ref.watch(profileOrDefaultProvider);
    final dist = s.effectiveDistance;
    final usesPace = s.sport.usesPace;
    final poolMode = s.sport == Sport.swim && s.indoor;
    // Big metric: live pace during a paced step, else distance.
    final showPaceBig = usesPace && s.step?.paceMin != null && !poolMode;
    // Cycling: speed is the primary number (bike-computer style).
    final rideBig = s.sport == Sport.ride && !s.indoor;
    String livePace() => s.currentPace == null ? '–:––' : fmtPaceSec(s.currentPace!, u);
    String speed() => s.currentPace == null ? '0.0' : Units.num(u.distOut(3600000 / s.currentPace!) / 1000, 1);
    final kcal = (p.weightKg * (s.sport == Sport.ride ? 0.28 : (s.sport == Sport.swim ? 0.6 : 1.0)) * dist / 1000).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        if (s.structured) _StepCard(s: s),
        if (!s.structured && s.sport != Sport.swim) _FreeRunHint(s: s),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  showPaceBig ? livePace() : (poolMode ? '${s.laps}' : (rideBig ? speed() : Units.num(u.distOut(dist), 2))),
                  style: TextStyle(
                    fontSize: 88,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: showPaceBig ? _paceColor(s.paceStatus) : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                showPaceBig
                    ? '${l.currentPace} (${u.imperial ? '/mi' : '/km'})'
                    : (poolMode ? l.laps : (rideBig ? '${l.currentSpeed} (${u.imperial ? 'mph' : 'km/h'})' : '${l.distance} (${u.distUnit})')),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: [
            _Cell(value: clock(s.elapsed), label: l.duration),
            if (showPaceBig || rideBig) _Cell(value: Units.num(u.distOut(dist), 2), label: '${l.distance} (${u.distUnit})', color: s.sport.color)
            else if (poolMode) _Cell(value: u.swimDist(dist), label: l.distance, color: s.sport.color)
            else _Cell(value: usesPace ? livePace() : speed(), label: usesPace ? l.currentPace : l.currentSpeed, color: s.sport.color),
            _Cell(value: u.paceOrSpeed(s.sport, dist, s.elapsed), label: usesPace ? l.avgPace : l.avgSpeed),
            _Cell(value: s.splits.isEmpty ? '–' : clock(s.splits.last), label: l.lastSplit),
            _Cell(value: s.indoor ? '–' : '${s.elevationM.round()} m', label: l.elevation),
            _Cell(value: '$kcal', label: 'kcal'),
          ],
        ),
        if (usesPace && s.paceHistory.length >= 3) ...[
          const SizedBox(height: 12),
          SizedBox(height: 90, child: _PaceChart(s: s)),
        ],
        if (poolMode) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 76,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.swim, foregroundColor: Colors.black),
              onPressed: s.paused ? null : ref.read(trackerProvider.notifier).lap,
              icon: const Icon(Icons.add_rounded, size: 30),
              label: Text('${l.lap} (+${s.poolLengthM} m)', style: const TextStyle(fontSize: 18)),
            ),
          ),
          TextButton(onPressed: s.laps == 0 ? null : ref.read(trackerProvider.notifier).undoLap, child: Text(l.undoLap)),
        ],
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
        Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

/// Current step: "INTERVAL 3/6 · 650 m left · 4:05–4:15 /km · Zone 4" + next step.
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
            Expanded(child: Text(l.allStepsDone, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ],
        ),
      );
    }
    final st = s.step!;
    final c = zoneColor(st.zone);
    final (m, sec) = s.stepRemaining;
    final remaining =
        m != null ? (m >= 1000 ? '${Units.num(u.distOut(m), 2)} ${u.distUnit}' : '${m.round()} m') : (sec != null ? clock(sec) : '');
    final target = stepTarget(l, st, u, s.sport);
    final next = s.nextStep;
    final status = s.paceStatus;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [c.withValues(alpha: 0.32), c.withValues(alpha: 0.12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                stepTitle(l, s.steps, s.stepIndex).toUpperCase(),
                style: TextStyle(color: c, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13),
              ),
              const Spacer(),
              if (status != null)
                Container(
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
              Text(remaining, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${l.left} · ${zoneLabel(l, st.zone)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (target.isNotEmpty) ...[const SizedBox(height: 2), Text(target, style: const TextStyle(fontSize: 13))],
          if (st.note.isNotEmpty) Text(st.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: s.stepProgress, minHeight: 6, color: c, backgroundColor: c.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: 8),
          WorkoutProfileBar(steps: s.steps, sport: s.sport, height: 22, current: s.stepIndex),
          if (next != null) ...[
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

/// Free (unstructured) workouts: friendly hint with HR zone 2 guidance.
class _FreeRunHint extends ConsumerWidget {
  const _FreeRunHint({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final max = p.estimatedMaxHr;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.sport.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: s.sport.color),
          const SizedBox(width: 10),
          Expanded(child: Text(l.freeRunHint((max * 0.72).round(), (max * 0.82).round()), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _PaceChart extends ConsumerWidget {
  const _PaceChart({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = s.paceHistory.map((p) => p.clamp(120, 900).toDouble()).toList();
    final st = s.step;
    final lo = [...h, if (st?.paceMin != null) st!.paceMin!.toDouble()].reduce(min) - 15;
    final hi = [...h, if (st?.paceMax != null) st!.paceMax!.toDouble()].reduce(max) + 15;
    // Inverted axis: faster pace (smaller number) is drawn higher.
    double y(double pace) => hi - pace + lo;
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
            if (st?.paceMin != null && st?.paceMax != null)
              HorizontalRangeAnnotation(y1: y(st!.paceMax!.toDouble()), y2: y(st.paceMin!.toDouble()), color: AppColors.success.withValues(alpha: 0.18)),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < h.length; i++) FlSpot(i.toDouble(), y(h[i]))],
            isCurved: true,
            barWidth: 3,
            color: s.sport.color,
            dotData: const FlDotData(show: false),
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
                          decoration: BoxDecoration(color: s.sport.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
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
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]));
}

class _SplitsPage extends ConsumerWidget {
  const _SplitsPage({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    if (s.structured) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.workoutStructure, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          WorkoutProfileBar(steps: s.steps, sport: s.sport, current: s.stepIndex),
          const SizedBox(height: 12),
          StepList(steps: s.steps, sport: s.sport, units: u),
          if (s.splits.isNotEmpty) ...[const Divider(height: 32), ..._splitRows(context, s)],
        ],
      );
    }
    if (s.splits.isEmpty) return Center(child: Text(l.noSplitsYet, style: Theme.of(context).textTheme.bodySmall));
    return ListView(padding: const EdgeInsets.all(16), children: _splitRows(context, s));
  }

  List<Widget> _splitRows(BuildContext context, CardioState s) {
    final best = s.splits.reduce(min);
    final worst = s.splits.reduce(max);
    return [
      for (var i = 0; i < s.splits.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                child: LayoutBuilder(
                  builder:
                      (_, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 20,
                          width: c.maxWidth * (0.35 + 0.65 * (worst == best ? 1 : (worst - s.splits[i]) / (worst - best))),
                          decoration: BoxDecoration(
                            color: s.splits[i] == best ? AppColors.success : s.sport.color.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Text(clock(s.splits[i]), style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (s.paused)
              _HoldToFinish(label: l.holdToFinish, onDone: onStop)
            else
              _RoundButton(icon: Icons.flag_outlined, label: s.sport == Sport.swim ? l.lap : l.roundLap, onTap: n.lap, size: 56),
            SizedBox(
              width: 88,
              height: 88,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
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
              size: 56,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.size = 56});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: size,
        height: size,
        child: IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
      ),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
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
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..addStatusListener((s) {
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
      Text(widget.label, style: Theme.of(context).textTheme.labelSmall),
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
          Text(hasFix ? '±${accuracy?.round() ?? '?'} m' : 'GPS…', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
  Future<void> open(String uri, String web) async {
    if (!await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> search(String q) => open('spotify:search:${Uri.encodeComponent(q)}', 'https://open.spotify.com/search/${Uri.encodeComponent(q)}');

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
                  onTap: () => search('running $bpm bpm'),
                ),
                _MusicTile(icon: Icons.directions_run, title: l.musicEasy, sub: '150–160 BPM', onTap: () => search('easy run 155 bpm')),
                _MusicTile(icon: Icons.speed, title: l.musicTempo, sub: '165–175 BPM', onTap: () => search('tempo run 170 bpm')),
                _MusicTile(icon: Icons.bolt, title: l.musicIntervals, sub: '175–185 BPM', onTap: () => search('running intervals 180 bpm')),
                _MusicTile(icon: Icons.podcasts, title: l.musicPodcasts, sub: l.musicPodcastsSub, onTap: () => search('running podcast')),
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
    leading: CircleAvatar(backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.18), child: Icon(icon, color: const Color(0xFF1DB954))),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: onTap,
  );
}
