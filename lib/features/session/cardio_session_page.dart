import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/step_progress.dart';
import '../../services/tracker.dart';
import '../../widgets/common.dart';
import 'music.dart';
import 'session_summary_page.dart';
import 'step_list.dart';
import 'step_text.dart';
import 'zone_info.dart' show showSwimDrills;

/// Pages of the live recording screen.
enum CardioTab { data, map, splits }

/// Which pages a session has: the map only outdoors; splits/structure whenever there
/// is something to show (outdoor splits, pool lengths or a structured workout).
List<CardioTab> cardioTabs(CardioState s) => [
  CardioTab.data,
  if (!s.indoor) CardioTab.map,
  if (s.structured || !s.indoor || s.poolMode) CardioTab.splits,
];

/// Live recording screen for runs, rides and swims.
///
/// Layout (top → bottom): app bar (title, GPS, music, voice, lock) · page tabs ·
/// page · controls. Pages are switched with the tappable tab bar (≥ 48 dp, works with
/// gloves); swiping also works except on the map, where horizontal drags pan the map.
///
/// The data page follows the sports-watch pattern: current step card (structured) ·
/// one big primary metric · ≤ 6 large fields · pace/speed trend + route sketch. It
/// fills the screen (fields grow on tall phones) and scrolls only when a small phone
/// cannot fit the minimum sizes.
class CardioSessionPage extends ConsumerStatefulWidget {
  const CardioSessionPage({super.key, this.initialTab = CardioTab.data});

  /// Starting page (tests / deep links).
  final CardioTab initialTab;
  @override
  ConsumerState<CardioSessionPage> createState() => _CardioSessionPageState();
}

class _CardioSessionPageState extends ConsumerState<CardioSessionPage> {
  final _map = MapController();
  late final PageController _pages;
  bool _follow = true;
  bool _locked = false;
  int _page = 0;
  int? _lastStep;

  @override
  void initState() {
    super.initState();
    final s = ref.read(trackerProvider);
    final i = s == null ? 0 : max(0, cardioTabs(s).indexOf(widget.initialTab));
    _page = i;
    _pages = PageController(initialPage: i);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

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

  void _goTo(List<CardioTab> tabs, CardioTab t) {
    final i = tabs.indexOf(t);
    if (i < 0) return;
    HapticFeedback.selectionClick();
    setState(() => _page = i);
    if (_pages.hasClients) _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Lap button (not in the pool): records the lap and confirms it with its time and distance.
  void _lap(CardioState s) {
    final u = ref.read(profileOrDefaultProvider).units;
    final l = context.l10n;
    final time = clock(s.lapElapsed);
    final dist = s.indoor ? '' : u.dist(s.lapDistance);
    ref.read(trackerProvider.notifier).lap();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          // Above the controls: never cover pause / lap.
          margin: const EdgeInsets.fromLTRB(16, 0, 16, _snackLift),
          content: Text(
            s.indoor ? '${l.roundLap} ${s.laps + 1}: $time' : l.lapDone(s.laps + 1, time, dist),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(trackerProvider);
    if (s == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noActiveWorkout)));
    final n = ref.read(trackerProvider.notifier);
    final tabs = cardioTabs(s);
    if (_page >= tabs.length) _page = tabs.length - 1;
    final onMap = tabs[_page] == CardioTab.map;
    final last = s.points.isNotEmpty ? s.points.last : null;
    if (_follow && last != null && onMap) {
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
              leading: IconButton(
                tooltip: l.minimize,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                  if (!s.indoor) ...[const SizedBox(height: 2), _GpsChip(accuracy: s.accuracy, error: s.gpsError, hasFix: last != null)],
                ],
              ),
              actions: [
                MusicButton(plan: () => musicPlan(l, s.sport, indoor: s.indoor, now: musicIdOfStep(ref.read(trackerProvider)?.step))),
                IconButton(
                  tooltip: l.voiceCues,
                  icon: Icon(s.voice ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded),
                  onPressed: n.toggleVoice,
                ),
                IconButton(
                  tooltip: l.lockScreen,
                  icon: const Icon(Icons.lock_outline_rounded),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _locked = true);
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'repeat') n.speakStatus();
                    if (v == 'skip') n.skipStep();
                    if (v == 'discard' && await confirm(context, l.discardWorkout, ok: l.discard, danger: true)) {
                      n.discard();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder:
                      (_) => [
                        PopupMenuItem(
                          value: 'repeat',
                          child: ListTile(dense: true, leading: const Icon(Icons.replay_rounded), title: Text(l.repeatCue)),
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
                if (s.paused) _PausedBanner(auto: s.autoPaused),
                if (tabs.length > 1)
                  _TabBar(tabs: tabs, index: _page, structured: s.structured, pool: s.poolMode, onTap: (t) => _goTo(tabs, t)),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    // On the map, horizontal drags pan the map: pages switch via the tab bar.
                    physics: onMap ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      for (final t in tabs)
                        switch (t) {
                          CardioTab.data => _DataPage(s: s, onRoute: () => _goTo(tabs, CardioTab.map)),
                          CardioTab.map => _MapPage(s: s, controller: _map, follow: _follow, onFollow: (v) => setState(() => _follow = v)),
                          CardioTab.splits => _SplitsPage(s: s),
                        },
                    ],
                  ),
                ),
                _Controls(s: s, onStop: () => _stop(s), onLap: () => _lap(s)),
              ],
            ),
          ),
          if (_locked)
            Positioned.fill(
              // Outside the Scaffold: needs its own Material for text styles.
              child: Material(type: MaterialType.transparency, child: _LockOverlay(onUnlock: () => setState(() => _locked = false))),
            ),
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
          // Above the controls: never cover pause / lap.
          margin: const EdgeInsets.fromLTRB(16, 0, 16, _snackLift),
          backgroundColor: zoneColor(st.zone),
          content: Text(
            stepSentence(l, s.steps, s.stepIndex, u, s.sport),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );
  }
}

/// Bottom margin of in-workout snack bars (height of the control row).
const double _snackLift = 128;

/// Text colour for a sport/zone colour: the bright accents are kept on dark
/// backgrounds and darkened on light ones (readable in sunlight).
Color _ink(BuildContext context, Color c) {
  if (Theme.of(context).brightness == Brightness.dark) return c;
  final h = HSLColor.fromColor(c);
  return h.lightness > 0.38 ? h.withLightness(0.34).toColor() : c;
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner({required this.auto});
  final bool auto;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: auto ? l.autoPaused : l.paused, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            TextSpan(text: '  ·  ${auto ? l.autoPausedHint : l.pausedHint}', style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.black, fontSize: 13),
      ),
    );
  }
}

/// Segmented page switcher: big tap targets, the current page is highlighted.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.index, required this.onTap, required this.structured, required this.pool});
  final List<CardioTab> tabs;
  final int index;
  final ValueChanged<CardioTab> onTap;
  final bool structured, pool;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => onTap(tabs[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: i == index ? AppColors.brand.withValues(alpha: 0.9) : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              switch (tabs[i]) {
                                CardioTab.data => Icons.speed_rounded,
                                CardioTab.map => Icons.map_rounded,
                                CardioTab.splits => structured ? Icons.format_list_numbered_rounded : Icons.bar_chart_rounded,
                              },
                              size: 20,
                              color: i == index ? Colors.black : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              switch (tabs[i]) {
                                CardioTab.data => l.tabData,
                                CardioTab.map => l.tabMap,
                                CardioTab.splits => structured ? l.tabWorkout : (pool ? l.lengths : l.tabSplits),
                              },
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: i == index ? Colors.black : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Data page ─────────────────────────────

/// One data field (value + label).
class _F {
  const _F(this.value, this.label, {this.color});
  final String value, label;
  final Color? color;
}

/// The data page for every sport: picks the primary metric and ≤ 6 fields.
class _DataPage extends ConsumerWidget {
  const _DataPage({required this.s, required this.onRoute});
  final CardioState s;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final u = p.units;
    final dist = s.effectiveDistance;
    final swim = s.sport == Sport.swim;
    final ride = s.sport == Sport.ride;
    final distLabel = '${l.distance} (${u.distUnit})';
    final distValue = Units.num(u.distOut(dist), 2);
    final duration = _F(clock(s.elapsed), l.duration);
    final header = <Widget>[if (s.structured) _StepCard(s: s) else if (!swim) _FreeHint(s: s)];
    final showTrend = !s.indoor && (s.paceHistory.length >= 3 || s.points.length > 1);
    final footer = showTrend ? _TrendFooter(s: s, onRoute: onRoute) : null;

    // ── Pool ──
    if (s.poolMode) {
      String pace(int? v) => v == null ? '–:––' : fmtPaceSec(v, u, swim: true);
      final kcal = (p.weightKg * 0.6 * dist / 1000).round();
      return _DataLayout(
        header: header,
        primary:
            s.structured
                ? _Primary(pace(s.swimPace100), '${l.pace100} (/100 m)', color: _paceColor(s.paceStatus))
                : _Primary(u.swimDist(dist), l.nLengths(s.laps)),
        hint: !s.structured && s.laps == 0 ? l.poolTapHint : null,
        fields: [
          duration,
          if (s.structured)
            _F(u.swimDist(dist), l.distance, color: s.sport.color)
          else
            _F(pace(s.swimPace100), l.pace100, color: s.sport.color),
          _F('${s.laps}', l.lengths),
          _F(s.lengthSecs.isEmpty ? '–' : clock(s.lengthSecs.last), l.lastLength),
          _F(pace(s.avgSwimPace100), l.avgPace100),
          if (!s.structured) _F('$kcal', 'kcal'),
        ],
      );
    }

    // ── Rides ──
    if (ride) {
      final speedUnit = u.imperial ? 'mph' : 'km/h';
      String speedOf(int? pace) => pace == null || pace <= 0 ? '0.0' : u.distOut(3600000 / pace).toStringAsFixed(1);
      final avg = s.elapsed > 0 && dist > 0 ? (u.distOut(dist) / (s.elapsed / 3600)).toStringAsFixed(1) : '–';
      // Outdoor: ~0.28 kcal per kg and km; indoor: ~7 MET (moderate trainer ride).
      final kcal = _F('${(s.indoor ? p.weightKg * 7 * s.elapsed / 3600 : p.weightKg * 0.28 * dist / 1000).round()}', 'kcal');
      if (s.indoor) {
        return _DataLayout(
          header: header,
          primary: _Primary(clock(s.elapsed), l.duration),
          fields: [
            if (s.structured) ...[
              _F(s.stepsDone ? '0:00' : clock(s.workoutLeftSec), l.workoutLeft, color: s.sport.color),
              _F('${min(s.stepIndex + 1, s.steps.length)}/${s.steps.length}', l.section),
            ],
            _F(_cadenceTarget(s.step), '${l.cadenceTarget} (${l.musicRpm})'),
            kcal,
            if (!s.structured) ...[_F('${s.laps}', l.lapCount), _F(clock(s.lapElapsed), l.currentLap)],
          ],
        );
      }
      return _DataLayout(
        header: header,
        primary: _Primary(speedOf(s.currentPace), '${l.currentSpeed} ($speedUnit)'),
        fields: [
          duration,
          _F(distValue, distLabel, color: s.sport.color),
          _F(avg, l.avgSpeed),
          if (!s.structured) _F(s.bestPace == null ? '–' : speedOf(s.bestPace), l.maxSpeed),
          _F('${s.elevationM.round()} m', l.elevation),
          if (!s.structured) kcal,
        ],
        footer: footer,
      );
    }

    // ── Runs, treadmill runs and open-water swims ──
    final paceUnit = swim ? '/100 m' : (u.imperial ? '/mi' : '/km');
    String livePace() {
      final v = s.targetPace;
      return v == null ? '–:––' : fmtPaceSec(v, u, swim: swim);
    }

    final paced = s.step?.paceMin != null && !s.indoor;
    final kcal = _F('${(s.indoor ? p.weightKg * 9 * s.elapsed / 3600 : p.weightKg * (swim ? 0.6 : 1.0) * dist / 1000).round()}', 'kcal');
    if (s.indoor) {
      // Treadmill: no GPS – time based (distance is entered at the end).
      return _DataLayout(
        header: header,
        primary: _Primary(clock(s.elapsed), l.duration),
        fields: [
          if (s.structured) ...[
            _F(s.stepsDone ? '0:00' : clock(s.workoutLeftSec), l.workoutLeft, color: s.sport.color),
            _F('${min(s.stepIndex + 1, s.steps.length)}/${s.steps.length}', l.section),
          ],
          _F('${s.laps}', l.lapCount),
          _F(clock(s.lapElapsed), l.currentLap),
          kcal,
        ],
      );
    }
    return _DataLayout(
      header: header,
      primary:
          paced ? _Primary(livePace(), '${l.currentPace} ($paceUnit)', color: _paceColor(s.paceStatus)) : _Primary(distValue, distLabel),
      gauge: paced ? _PaceGauge(s: s) : null,
      fields: [
        duration,
        if (paced) _F(distValue, distLabel, color: s.sport.color) else _F(livePace(), l.currentPace, color: s.sport.color),
        _F(u.paceOrSpeed(s.sport, dist, s.elapsed), l.avgPace),
        _F(s.splits.isEmpty ? '–' : clock(s.splits.last), l.lastSplit),
        if (!s.structured) ...[if (!swim) _F('${s.elevationM.round()} m', l.elevation), kcal],
      ],
      footer: footer,
    );
  }
}

/// Trainer cadence guidance by intensity (rpm).
String _cadenceTarget(WorkoutStep? st) => switch (st == null || st.kind != 'work' ? 2 : (hrZoneOf(st.zone) ?? 2)) {
  >= 5 => '95–110',
  4 => '90–100',
  _ => '85–95',
};

/// Step card(s) on top · big primary metric · optional gauge · fields in rows of two ·
/// optional footer. Fills the page height; scrolls only below the minimum sizes.
class _DataLayout extends StatelessWidget {
  const _DataLayout({required this.header, required this.primary, required this.fields, this.gauge, this.footer, this.hint});
  final List<Widget> header;
  final _Primary primary;
  final Widget? gauge;
  final List<_F> fields;
  final Widget? footer;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_F>>[for (var i = 0; i < fields.length; i += 2) fields.sublist(i, min(i + 2, fields.length))];
    return CustomScrollView(
      slivers: [
        if (header.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList.list(children: [...header, const SizedBox(height: 4)]),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                Expanded(flex: 6, child: _MinHeight(height: 76, child: primary)),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(hint!, textAlign: TextAlign.center, maxLines: 2, style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (gauge != null) ...[const SizedBox(height: 4), gauge!],
                for (final r in rows) ...[
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 4,
                    child: _MinHeight(
                      height: 58,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < r.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: _Cell(f: r[i]))],
                        ],
                      ),
                    ),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 8), footer!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reports a fixed intrinsic height so [SliverFillRemaining] sizes the page by the
/// minimum readable size instead of the (scalable) content.
class _MinHeight extends SingleChildRenderObjectWidget {
  const _MinHeight({required this.height, super.child});
  final double height;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMinHeight(height);
  @override
  void updateRenderObject(BuildContext context, _RenderMinHeight renderObject) => renderObject.height = height;
}

class _RenderMinHeight extends RenderProxyBox {
  _RenderMinHeight(this._height);
  double _height;
  set height(double v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;
  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}

/// The big number: scales with the space it gets (up to 120 pt).
class _Primary extends StatelessWidget {
  const _Primary(this.value, this.label, {this.color});
  final String value, label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 120,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color == null ? null : _ink(context, color!),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelLarge)),
    ],
  );
}

Color? _paceColor(int? status) => switch (status) {
  0 => AppColors.success,
  -1 => AppColors.swim,
  1 => AppColors.warning,
  _ => null,
};

class _Cell extends StatelessWidget {
  const _Cell({required this.f});
  final _F f;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
    child: Column(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              f.value,
              style: TextStyle(
                fontSize: 44,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: f.color == null ? null : _ink(context, f.color!),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        // Long labels ("Rest der Einheit") shrink instead of being cut off.
        FittedBox(fit: BoxFit.scaleDown, child: Text(f.label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1)),
      ],
    ),
  );
}

/// Where the live pace sits relative to the target band: slower ← [target] → faster.
class _PaceGauge extends StatelessWidget {
  const _PaceGauge({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = s.step!;
    final swim = s.sport == Sport.swim;
    final lo = st.paceMin!.toDouble(), hi = (st.paceMax ?? st.paceMin!).toDouble();
    final span = max(swim ? 6.0 : 15.0, hi - lo);
    final from = hi + span, to = lo - span; // left: slow, right: fast
    double pos(double v) => ((from - v) / (from - to)).clamp(0.0, 1.0);
    final p = s.targetPace;
    final status = s.paceStatus;
    final small = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: 34,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _GaugePainter(
                bandFrom: pos(hi),
                bandTo: pos(lo),
                marker: p == null ? null : pos(p.toDouble()),
                markerColor: _paceColor(status) ?? Theme.of(context).colorScheme.onSurface,
                track: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Row(
            children: [
              Text('← ${l.tooSlow}', style: small),
              const Spacer(),
              Text(l.targetBand, style: small?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${l.tooFast} →', style: small),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.bandFrom, required this.bandTo, required this.marker, required this.markerColor, required this.track});
  final double bandFrom, bandTo;
  final double? marker;
  final Color markerColor, track;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final r = RRect.fromLTRBR(0, y - 5, size.width, y + 5, const Radius.circular(5));
    canvas.drawRRect(r, Paint()..color = track);
    canvas.drawRRect(
      RRect.fromLTRBR(size.width * bandFrom, y - 5, size.width * bandTo, y + 5, const Radius.circular(5)),
      Paint()..color = AppColors.success,
    );
    if (marker != null) {
      final x = size.width * marker!;
      canvas.drawCircle(Offset(x, y), 8, Paint()..color = markerColor);
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.marker != marker || o.bandFrom != bandFrom || o.bandTo != bandTo || o.markerColor != markerColor;
}

/// Pace/speed trend and a tappable route sketch (opens the map page).
class _TrendFooter extends StatelessWidget {
  const _TrendFooter({required this.s, required this.onRoute});
  final CardioState s;
  final VoidCallback onRoute;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.paceHistory.length >= 3) Expanded(child: _PaceChart(s: s)) else const Spacer(),
          if (s.points.length > 1) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: context.l10n.tabMap,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onRoute,
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(8),
                  child: CustomPaint(painter: RouteSketchPainter(s.points, s.sport.color)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Route outline without map tiles (offline, cheap) with the current position.
class RouteSketchPainter extends CustomPainter {
  RouteSketchPainter(this.points, this.color);
  final List<LatLng> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var minLat = points.first.latitude, maxLat = minLat, minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    final k = cos(((minLat + maxLat) / 2) * pi / 180);
    final w = max((maxLng - minLng) * k, 1e-6), h = max(maxLat - minLat, 1e-6);
    final scale = min(size.width / w, size.height / h);
    final dx = (size.width - w * scale) / 2, dy = (size.height - h * scale) / 2;
    Offset at(LatLng p) => Offset(dx + (p.longitude - minLng) * k * scale, size.height - dy - (p.latitude - minLat) * scale);
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    final step = max(1, points.length ~/ 300);
    for (var i = step; i < points.length; i += step) {
      final o = at(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(at(points.last), 5, Paint()..color = Colors.white);
    canvas.drawCircle(at(points.last), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(RouteSketchPainter o) => o.points.length != points.length;
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
        padding: const EdgeInsets.all(14),
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
    final ci = _ink(context, c);
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                  style: TextStyle(color: ci, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 13),
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (st.powerMin != null && st.powerMax != null)
                  _TargetChip(icon: Icons.bolt_rounded, text: '${st.powerMin}–${st.powerMax} W', color: ci),
                if (st.hrMin != null && st.hrMax != null)
                  _TargetChip(icon: Icons.favorite_rounded, text: '${st.hrMin}–${st.hrMax} bpm', color: ci),
              ],
            ),
          ] else if (target.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(target, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
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
              maxLines: run ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: s.stepProgress, minHeight: 6, color: c, backgroundColor: c.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: 6),
          WorkoutProfileBar(steps: s.steps, sport: s.sport, height: 18, current: s.stepIndex),
          const SizedBox(height: 6),
          // What comes next (all sports) – the full list is on the "Workout" page.
          Row(
            children: [
              Icon(
                next == null ? Icons.flag_rounded : Icons.subdirectory_arrow_right_rounded,
                size: 16,
                color: next == null ? AppColors.success : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 4),
              if (next != null)
                Container(
                  width: 4,
                  height: 14,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: zoneColor(next.zone), borderRadius: BorderRadius.circular(2)),
                ),
              Expanded(
                child: Text(
                  next == null ? '${l.upNext}: ${l.finish}' : '${l.upNext}: ${stepSentence(l, s.steps, s.stepIndex + 1, u, s.sport)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: s.sport.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: _ink(context, s.sport.color), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: LineChart(
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
              belowBarData: BarAreaData(show: true, color: s.sport.color.withValues(alpha: 0.12)),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: last ?? const LatLng(51.1657, 10.4515),
                initialZoom: last == null ? 5 : 16,
                // No map rotation: an accidental twist mid-run is hard to undo.
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
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
              left: 10,
              right: 10,
              top: 10,
              child: Consumer(
                builder: (context, ref, _) {
                  final l = context.l10n;
                  final u = ref.watch(profileOrDefaultProvider).units;
                  final ride = s.sport == Sport.ride;
                  final live =
                      s.currentPace == null
                          ? '–'
                          : ride
                          ? '${u.distOut(3600000 / s.currentPace!).toStringAsFixed(1)} ${u.imperial ? 'mph' : 'km/h'}'
                          : fmtPaceSec(
                            s.sport == Sport.swim ? (s.currentPace! / 10).round() : s.currentPace!,
                            u,
                            swim: s.sport == Sport.swim,
                          );
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        _MapStat(clock(s.elapsed), l.duration),
                        _MapStat(Units.num(u.distOut(s.effectiveDistance), 2), u.distUnit),
                        _MapStat(live, ride ? l.currentSpeed : l.currentPace),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (!follow)
              Positioned(
                right: 12,
                bottom: 28,
                child: FloatingActionButton(heroTag: null, onPressed: () => onFollow(true), child: const Icon(Icons.my_location)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapStat extends StatelessWidget {
  const _MapStat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(color: Colors.white70, fontSize: 11))),
      ],
    ),
  );
}

/// Splits / lengths / workout structure. Outdoors it always starts with the current
/// km (progress + time) so the page is useful before the first split.
class _SplitsPage extends ConsumerWidget {
  const _SplitsPage({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(profileOrDefaultProvider).units;
    final t = Theme.of(context).textTheme;
    final h = t.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final children = <Widget>[];
    if (s.structured) {
      final leftM = s.poolMode ? workoutRemainingM(s.steps, s.stepIndex, stepDistance: s.stepDistance) : null;
      final left = [if (leftM != null && leftM > 0) u.swimDist(leftM), '≈ ${clock(s.workoutLeftSec)}'].join(' · ');
      children.addAll([
        Row(
          children: [
            Expanded(child: Text(l.workoutStructure, style: h)),
            if (!s.stepsDone)
              Flexible(child: Text('${l.workoutLeft}: $left', style: t.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 8),
        WorkoutProfileBar(steps: s.steps, sport: s.sport, current: s.stepIndex),
        const SizedBox(height: 12),
        StepList(steps: s.steps, sport: s.sport, units: u, current: s.stepIndex),
      ]);
    }
    if (s.poolMode) {
      if (s.lengthSecs.isNotEmpty) {
        final recent = s.lengthSecs.length > 60 ? s.lengthSecs.sublist(s.lengthSecs.length - 60) : s.lengthSecs;
        if (children.isNotEmpty) children.add(const Divider(height: 32));
        children.addAll([
          Text(l.lengths, style: h),
          const SizedBox(height: 4),
          ..._bars(context, recent, clock, first: s.lengthSecs.length - recent.length + 1).reversed,
        ]);
      } else if (children.isEmpty) {
        return Center(child: Text(l.noLengthsYet, style: t.bodySmall));
      }
    } else if (!s.indoor) {
      if (children.isNotEmpty) children.add(const Divider(height: 32));
      children.add(_CurrentSplit(s: s));
      if (s.splits.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 16),
          Text(l.splits, style: h),
          const SizedBox(height: 4),
          ..._bars(context, s.splits, s.sport == Sport.ride ? (sec) => '${(3600 / sec).toStringAsFixed(1)} km/h' : clock),
        ]);
      } else {
        children.addAll([const SizedBox(height: 8), Text(l.noSplitsYet, style: t.bodySmall)]);
      }
    }
    if (s.lapSecs.isNotEmpty) {
      children.addAll([
        const Divider(height: 32),
        Text(l.lapCount, style: h),
        for (var i = s.lapSecs.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text(clock(s.lapSecs[i]), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                if (!s.indoor) Text(u.dist(s.lapDists[i]), style: t.bodyMedium),
              ],
            ),
          ),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: children);
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
                width: 84,
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
}

/// Current km: progress bar to the next split, time so far, best and average km.
class _CurrentSplit extends StatelessWidget {
  const _CurrentSplit({required this.s});
  final CardioState s;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ride = s.sport == Sport.ride;
    final inKm = s.distanceM % 1000;
    String fmt(int sec) => ride ? '${(3600 / sec).toStringAsFixed(1)} km/h' : clock(sec);
    final best = s.splits.isEmpty ? null : s.splits.reduce(min);
    final avg = s.splits.isEmpty ? null : (s.splits.reduce((a, b) => a + b) / s.splits.length).round();
    Widget stat(String v, String label) => Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.currentSplit} ${s.splits.length + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${inKm.round()} / 1000 m', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: inKm / 1000,
              minHeight: 10,
              color: s.sport.color,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              stat(clock(max(0, s.splitElapsed)), l.duration),
              stat(best == null ? '–' : fmt(best), l.bestSplit),
              stat(avg == null ? '–' : fmt(avg), l.avgSplit),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Controls ─────────────────────────────

class _Controls extends ConsumerWidget {
  const _Controls({required this.s, required this.onStop, required this.onLap});
  final CardioState s;
  final VoidCallback onStop, onLap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.read(trackerProvider.notifier);
    final pool = s.poolMode;
    final st = s.step;
    // Open steps ("until lap button") end with the lap button – make it stand out.
    final lapEndsStep = st != null && st.distanceM == null && st.durationSec == null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pool) ...[_LengthButton(s: s, onTap: n.lap), const SizedBox(height: 8)],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (s.paused)
                  _HoldToFinish(label: l.holdToFinish, onDone: onStop)
                else if (pool)
                  _RoundButton(icon: Icons.undo_rounded, label: l.undoLength, onTap: s.laps == 0 ? null : n.undoLap)
                else
                  _RoundButton(
                    icon: Icons.flag_outlined,
                    label: s.laps > 0 ? '${l.roundLap} ${s.laps + 1}' : l.roundLap,
                    onTap: onLap,
                    highlight: lapEndsStep ? s.sport.color : null,
                  ),
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
          width: 60,
          height: 60,
          child:
              highlight != null
                  ? IconButton.filled(
                    tooltip: label,
                    style: IconButton.styleFrom(backgroundColor: highlight, foregroundColor: Colors.black),
                    onPressed: onTap,
                    icon: Icon(icon, size: 30),
                  )
                  : IconButton.filledTonal(tooltip: label, onPressed: onTap, icon: Icon(icon, size: 28)),
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
          width: 60,
          height: 60,
          child: AnimatedBuilder(
            animation: _c,
            builder:
                (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(child: CircularProgressIndicator(value: _c.value, strokeWidth: 4, color: AppColors.danger)),
                    Container(
                      width: 50,
                      height: 50,
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  context.l10n.holdToUnlock,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
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
    final color = _ink(context, error != null ? AppColors.danger : (good ? AppColors.success : AppColors.warning));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, size: 11, color: color),
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
