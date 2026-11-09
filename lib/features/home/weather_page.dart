import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/weather_service.dart';

String skyLabel(AppLocalizations l, int code) => switch (skyOf(code)) {
  Sky.clear => l.skyClear,
  Sky.partly => l.skyPartly,
  Sky.cloudy => l.skyCloudy,
  Sky.fog => l.skyFog,
  Sky.drizzle => l.skyDrizzle,
  Sky.rain => l.skyRain,
  Sky.snow => l.skySnow,
  Sky.storm => l.skyStorm,
};

String clothingLabel(AppLocalizations l, Clothing c) => switch (c) {
  Clothing.shortsTee => l.clothShorts,
  Clothing.longTee => l.clothLongTee,
  Clothing.tights => l.clothTights,
  Clothing.jacket => l.clothJacket,
  Clothing.winter => l.clothWinter,
};

/// Short athlete-focused hint for the home card.
String weatherHint(AppLocalizations l, Weather w, String locale) {
  final rain = w.nextRain;
  if (skyOf(w.code) == Sky.storm) return l.hintStorm;
  if (rain != null && rain.time.difference(DateTime.now()).inMinutes > 30) {
    return l.hintRainAt(DateFormat.Hm(locale).format(rain.time));
  }
  if (w.feelsLike > 26) return l.hintHot;
  if (w.feelsLike < -2) return l.hintCold;
  final best = w.bestWindow;
  if (best != null && best.$2 >= 70) {
    final t = DateFormat.Hm(locale).format(best.$1.time);
    return l.hintBest(sameDay(best.$1.time, DateTime.now()) ? t : '${l.tomorrow} $t');
  }
  return l.hintIndoor;
}

// ───────────────────────────── Home card ─────────────────────────────

class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(weatherProvider);
    return async.when(
      loading:
          () => _Shell(
            colors: const [Color(0xFF4A7FC1), Color(0xFF8DB4DE)],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ),
      error:
          (e, _) => _Shell(
            colors: const [Color(0xFF5D6B7E), Color(0xFF8C97A6)],
            onTap: () => ref.invalidate(weatherProvider),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off_outlined, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  e is LocationDenied ? l.weatherNoLocation : l.weatherError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(l.retry, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      data: (w) {
        return _Shell(
          colors: skyGradient(w.code, w.isDay),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherPage())),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.near_me_rounded, size: 12, color: Colors.white70),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      w.place.isEmpty ? l.weather : w.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white70),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${w.temp.round()}°',
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w600, height: 1),
                  ),
                  const Spacer(),
                  Icon(weatherIcon(w.code, night: !w.isDay), color: Colors.white, size: 34),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${skyLabel(l, w.code)} · ${w.max.round()}°/${w.min.round()}°',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  weatherHint(l, w, context.localeName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1.25),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.colors, required this.child, this.onTap});
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 190),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    ),
  );
}

// ───────────────────────────── Detail page ─────────────────────────────

class WeatherPage extends ConsumerWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(weatherProvider);
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text(l.weatherError))),
      data: (w) => _WeatherView(w: w),
    );
  }
}

class _WeatherView extends ConsumerWidget {
  const _WeatherView({required this.w});
  final Weather w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final loc = context.localeName;
    final lang = Localizations.localeOf(context).languageCode;
    final hm = DateFormat.Hm(loc);
    final colors = skyGradient(w.code, w.isDay);
    final best = w.bestWindow;
    final cloth = clothingFor(w.feelsLike);
    // Fixed-height areas grow with the system font size to avoid overflows.
    final ts = MediaQuery.textScalerOf(context);
    final headerExtra = max(0.0, ts.scale(100) - 100);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(weatherProvider),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 280 + headerExtra,
              foregroundColor: Colors.white,
              backgroundColor: colors.first,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.place.isEmpty ? l.weather : w.place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                          // Takes the remaining height; scales down instead of overflowing when tight.
                          Expanded(
                            child: LayoutBuilder(
                              builder:
                                  (_, c) => Align(
                                    alignment: Alignment.bottomLeft,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.bottomLeft,
                                      child: SizedBox(
                                        width: c.maxWidth,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  '${w.temp.round()}°',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 84,
                                                    fontWeight: FontWeight.w300,
                                                    height: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(weatherIcon(w.code, night: !w.isDay), color: Colors.white, size: 72),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${skyLabel(l, w.code)} · ${l.feelsLike} ${w.feelsLike.round()}° · ${w.max.round()}°/${w.min.round()}°',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(
                children: [
                  // ── Training window ──
                  if (best != null)
                    _Panel(
                      icon: Icons.directions_run_rounded,
                      iconColor: AppColors.run,
                      title: l.bestTrainingWindow,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sameDay(best.$1.time, DateTime.now()) ? '' : '${l.tomorrow} '}${hm.format(best.$1.time)} – ${hm.format(best.$1.time.add(const Duration(hours: 2)))}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${best.$1.temp.round()}° · ${skyLabel(l, best.$1.code)} · ${l.rainChanceN(best.$1.rainChance)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          _ScoreRing(score: best.$2),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // ── Hourly ──
                  _Panel(
                    icon: Icons.schedule_rounded,
                    title: l.next24h,
                    child: Column(
                      children: [
                        SizedBox(
                          // 3 text lines (12/14/10 pt) + icon, bar and paddings.
                          height: 62 + ts.scale(52),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: min(24, w.hours.length),
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (_, i) {
                              final h = w.hours[i];
                              final sc = h.trainingScore;
                              return Container(
                                width: max(56.0, 28 + ts.scale(28)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: i == 0 ? AppColors.brand.withValues(alpha: 0.15) : null,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      i == 0 ? l.now : DateFormat.Hm(context.localeName).format(h.time),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Icon(weatherIcon(h.code, night: !h.isDay), size: 22, color: weatherColor(h.code)),
                                    Text(
                                      '${h.temp.round()}°',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      h.rainChance > 0 ? '${h.rainChance}%' : '',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF4FC3F7)),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 24,
                                      height: 3,
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: scoreColor(sc)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(height: 90, child: _TempChart(hours: w.hours.take(24).toList())),
                        const SizedBox(height: 8),
                        const _ScoreLegend(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Details grid ──
                  // Rows of two equal-height tiles sized by their content (a fixed
                  // aspect-ratio grid overflowed on narrow screens / large text).
                  _TileGrid(
                    tiles: [
                      _Tile(icon: Icons.air_rounded, label: l.wind, value: '${w.wind.round()} km/h', sub: windDirLabel(w.windDir, lang)),
                      _Tile(icon: Icons.water_drop_outlined, label: l.humidity, value: '${w.humidity} %'),
                      _Tile(
                        icon: Icons.wb_sunny_outlined,
                        label: l.uvIndex,
                        value: w.uv.toStringAsFixed(0),
                        sub: w.uv >= 6 ? l.uvHigh : (w.uv >= 3 ? l.uvModerate : l.uvLow),
                      ),
                      _Tile(
                        icon: Icons.masks_outlined,
                        label: l.airQuality,
                        value: w.aqi == null ? '–' : '${w.aqi}',
                        sub: w.aqi == null ? null : (w.aqi! <= 40 ? l.aqiGood : (w.aqi! <= 80 ? l.aqiModerate : l.aqiPoor)),
                      ),
                      _Tile(icon: Icons.wb_twilight_rounded, label: l.sunrise, value: hm.format(w.sunrise)),
                      _Tile(icon: Icons.nights_stay_outlined, label: l.sunset, value: hm.format(w.sunset)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── What to wear ──
                  _Panel(
                    icon: Icons.checkroom_rounded,
                    iconColor: AppColors.brand,
                    title: l.whatToWear,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clothingLabel(l, cloth), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (w.uv >= 5) l.wearSunscreen,
                            if ((w.nextRain?.rainChance ?? 0) >= 50) l.wearRainJacket,
                            if (w.wind > 25) l.wearWindproof,
                            if (w.feelsLike > 22) l.drinkMore,
                            if (!w.isDay || w.hours.first.time.isAfter(w.sunset.subtract(const Duration(hours: 1)))) l.wearReflective,
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── 7 days ──
                  _Panel(
                    icon: Icons.calendar_today_rounded,
                    title: l.next7Days,
                    child: Column(
                      children: [
                        for (final d in w.days)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: ts.scale(50),
                                  child: Text(
                                    sameDay(d.date, DateTime.now()) ? l.today : DateFormat.E(loc).format(d.date),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Icon(weatherIcon(d.code), color: weatherColor(d.code), size: 22),
                                SizedBox(
                                  width: ts.scale(40),
                                  child: Text(
                                    d.rainChance >= 20 ? '${d.rainChance}%' : '',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF4FC3F7)),
                                  ),
                                ),
                                SizedBox(
                                  width: ts.scale(30),
                                  child: Text(
                                    '${d.min.round()}°',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _RangeBar(days: w.days, day: d)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: ts.scale(32),
                                  child: Text(
                                    '${d.max.round()}°',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.weatherSource, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.child, this.iconColor});
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(22)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor ?? Theme.of(context).colorScheme.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, this.sub});
  final IconData icon;
  final String label, value;
  final String? sub;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        // Keeps both tiles of a row aligned even if only one has a sub line.
        Text(sub ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    final c = scoreColor(score);
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: c,
              backgroundColor: c.withValues(alpha: 0.15),
            ),
          ),
          Text('$score', style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 16)),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.days, required this.day});
  final List<DayForecast> days;
  final DayForecast day;
  @override
  Widget build(BuildContext context) {
    final lo = days.map((d) => d.min).reduce(min);
    final hi = days.map((d) => d.max).reduce(max);
    final span = max(1.0, hi - lo);
    return LayoutBuilder(
      builder: (_, c) {
        final left = (day.min - lo) / span * c.maxWidth;
        final width = max(6.0, (day.max - day.min) / span * c.maxWidth);
        return Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Positioned(
              left: left,
              child: Container(
                width: width,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFFFFB627)]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TempChart extends StatelessWidget {
  const _TempChart({required this.hours});
  final List<HourForecast> hours;
  @override
  Widget build(BuildContext context) {
    if (hours.length < 2) return const SizedBox.shrink();
    final temps = hours.map((h) => h.temp);
    final lo = temps.reduce(min) - 2, hi = temps.reduce(max) + 2;
    return LineChart(
      LineChartData(
        minY: lo,
        maxY: hi,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < hours.length; i++) FlSpot(i.toDouble(), hours[i].temp)],
            isCurved: true,
            barWidth: 3,
            color: AppColors.ride,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.ride.withValues(alpha: 0.3), AppColors.ride.withValues(alpha: 0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Rain probability (scaled to the temperature axis)
          LineChartBarData(
            spots: [for (var i = 0; i < hours.length; i++) FlSpot(i.toDouble(), lo + (hi - lo) * hours[i].rainChance / 100)],
            isCurved: true,
            barWidth: 0,
            color: Colors.transparent,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF4FC3F7).withValues(alpha: 0.18)),
          ),
        ],
      ),
    );
  }
}

/// Colour of an hourly training score – same thresholds everywhere on the page.
Color scoreColor(int score) => score >= 70 ? AppColors.run : (score >= 45 ? AppColors.ride : AppColors.danger);

/// Lays out tiles in rows of two with equal height per row.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});
  final List<Widget> tiles;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < tiles.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Explains the colours of the hourly condition bars; tap opens the details.
class _ScoreLegend extends StatelessWidget {
  const _ScoreLegend();
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final small = Theme.of(context).textTheme.bodySmall;
    Widget item(Color c, String label, String range) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: small?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(width: 3),
        Text(range, style: small),
      ],
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showScoreInfo(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.scoreLegendTitle, style: small),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        item(AppColors.run, l.scoreGood, '≥ 70'),
                        item(AppColors.ride, l.scoreFair, '45–69'),
                        item(AppColors.danger, l.scorePoor, '< 45'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

void _showScoreInfo(BuildContext context) {
  final l = context.l10n;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) {
      final t = Theme.of(c).textTheme;
      Widget row(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Icon(icon, size: 20, color: color), const SizedBox(width: 12), Expanded(child: Text(text, style: t.bodyMedium))],
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.scoreHowTitle, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(l.scoreHowIntro, style: t.bodyMedium),
              const SizedBox(height: 8),
              row(Icons.thermostat_rounded, AppColors.ride, l.scoreHowTemp),
              row(Icons.water_drop_outlined, const Color(0xFF4FC3F7), l.scoreHowRain),
              row(Icons.air_rounded, Theme.of(c).colorScheme.outline, l.scoreHowWind),
              row(Icons.wb_sunny_outlined, const Color(0xFFFFC53D), l.scoreHowUv),
              row(Icons.nights_stay_outlined, AppColors.brand, l.scoreHowDark),
              row(Icons.thunderstorm_rounded, const Color(0xFF9575CD), l.scoreHowStorm),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    for (final (col, lab, range) in [
                      (AppColors.run, l.scoreGood, '70–100'),
                      (AppColors.ride, l.scoreFair, '45–69'),
                      (AppColors.danger, l.scorePoor, '0–44'),
                    ])
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lab,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(range, maxLines: 1, style: t.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(l.scoreHowLevels, style: t.bodySmall),
            ],
          ),
        ),
      );
    },
  );
}
