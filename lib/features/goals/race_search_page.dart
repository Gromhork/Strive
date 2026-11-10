import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/event_distances.dart';
import '../../core/event_sport_x.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/race_search.dart';
import '../../widgets/common.dart';
import '../../widgets/event_distance_picker.dart';

/// Race search service of the session (keeps the result cache while the app runs).
final raceSearchServiceProvider = Provider<RaceSearchService>((ref) {
  final s = RaceSearchService();
  ref.onDispose(s.close);
  return s;
});

/// Race taken over as goal ([RaceSearchPage] pops with it).
class RaceSelection {
  const RaceSelection({required this.name, required this.date, required this.sport, this.distance, required this.url});
  final String name;
  final DateTime date;
  final EventSport sport;

  /// App event distance key, null when the race's distance is not one of the app's.
  final String? distance;
  final Uri url;
}

/// Opens the race search, prefilled with [sport] / [distance] (default: the profile's event
/// and focus); returns the race chosen as goal (or null).
Future<RaceSelection?> openRaceSearch(BuildContext context, {bool saveToProfile = true, EventSport? sport, String? distance}) =>
    Navigator.push<RaceSelection>(
      context,
      MaterialPageRoute(builder: (_) => RaceSearchPage(saveToProfile: saveToProfile, sport: sport, distance: distance)),
    );

/// Search for upcoming races in public race calendars, plus calendar links. "Set as goal"
/// stores the event in the profile (unless [saveToProfile] is false, e.g. inside the plan
/// setup that saves the profile itself) and pops with a [RaceSelection].
class RaceSearchPage extends ConsumerStatefulWidget {
  const RaceSearchPage({super.key, this.saveToProfile = true, this.sport, this.distance});
  final bool saveToProfile;
  final EventSport? sport;
  final String? distance;

  @override
  ConsumerState<RaceSearchPage> createState() => _RaceSearchPageState();
}

class _RaceSearchPageState extends ConsumerState<RaceSearchPage> {
  late EventSport _sport;
  String? _distance;
  final _region = TextEditingController();
  int _radius = 50;
  int _months = 6;
  bool _init = false;

  bool _loading = false;
  RaceSearchResult? _result;
  RaceSearchFailure? _failure;
  int _token = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final p = ref.read(profileOrDefaultProvider);
    final ev = eventDistanceOf(widget.distance ?? p.athlete.eventDistance);
    _sport = widget.sport ?? ev?.sport ?? EventSportX.fromFocus(p.focus);
    _distance = ev?.sport == _sport ? ev!.key : null;
    final loc = Localizations.localeOf(context);
    _region.text = defaultRegion(loc.languageCode, loc.countryCode);
  }

  @override
  void dispose() {
    _region.dispose();
    super.dispose();
  }

  RaceQuery get _query => RaceQuery(
    sport: _sport,
    distance: _distance,
    region: _region.text,
    radiusKm: _radius,
    months: _months,
    lang: Localizations.localeOf(context).languageCode,
  );

  /// A city or postcode (not empty, not a country): the radius applies.
  bool get _isPlace => _region.text.trim().isNotEmpty && countryCodeOf(_region.text) == null;

  /// Filters changed: show a cached result for them, otherwise go back to the start state.
  void _filtersChanged() {
    final hit = ref.read(raceSearchServiceProvider).cached(_query);
    setState(() {
      _token++;
      _loading = false;
      _failure = null;
      _result = hit;
    });
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final token = ++_token;
    setState(() {
      _loading = true;
      _failure = null;
      _result = null;
    });
    try {
      final r = await ref.read(raceSearchServiceProvider).search(_query);
      if (!mounted || token != _token) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _failure = RaceSearchFailure.failed;
        _loading = false;
      });
    }
  }

  void _take(RaceResult r) {
    final sel = RaceSelection(name: r.name, date: r.date, sport: _sport, distance: eventDistanceFor(r, _sport, _distance), url: r.url);
    if (widget.saveToProfile) {
      final repo = ref.read(repoProvider);
      final p = ref.read(profileOrDefaultProvider);
      repo?.saveProfile(
        p.copyWith(
          athlete: p.athlete.merge({
            'eventDate': sel.date,
            'eventName': sel.name,
            // Unknown distance: keep the stored one.
            if (sel.distance != null) 'eventDistance': sel.distance,
          }),
        ),
      );
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.raceGoalSet)));
    Navigator.pop(context, sel);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final portals = racePortals(_query, today: dayOnly(DateTime.now()));
    return Scaffold(
      appBar: AppBar(title: Text(l.raceSearch)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _label(context, l.raceSport),
          _chipRow([
            for (final s in EventSport.values)
              ChoiceChip(
                avatar: Icon(s.icon, size: 16),
                label: Text(s.label(l)),
                selected: _sport == s,
                onSelected: (_) {
                  _sport = s;
                  if (eventDistanceOf(_distance)?.sport != s) _distance = null;
                  _filtersChanged();
                },
              ),
          ]),
          _label(context, l.eventDistance),
          EventDistanceChips(
            sports: [_sport],
            selected: _distance,
            anyLabel: l.raceAnyDistance,
            scroll: true,
            onChanged: (k) {
              _distance = k;
              // A distance of another sport from "More distances…" switches the sport.
              final s = eventDistanceOf(k)?.sport;
              if (s != null) _sport = s;
              _filtersChanged();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _region,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _filtersChanged(),
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(labelText: l.raceRegion, hintText: l.raceRegionHint, prefixIcon: const Icon(Icons.place_outlined)),
          ),
          if (_isPlace) ...[
            _label(context, l.raceRadius),
            _chipRow([
              for (final r in const [25, 50, 100])
                ChoiceChip(
                  label: Text('$r km'),
                  selected: _radius == r,
                  onSelected: (_) {
                    _radius = r;
                    _filtersChanged();
                  },
                ),
            ]),
          ],
          _label(context, l.raceWindow),
          _chipRow([
            for (final m in const [3, 6, 12])
              ChoiceChip(
                label: Text(l.raceNextMonths(m)),
                selected: _months == m,
                onSelected: (_) {
                  _months = m;
                  _filtersChanged();
                },
              ),
          ]),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _loading ? null : _search, icon: const Icon(Icons.search_rounded), label: Text(l.raceSearchButton)),
          const SizedBox(height: 16),
          ..._resultArea(context),
          const SizedBox(height: 24),
          Text(l.racePortals, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(l.racePortalsHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final p in portals)
                  ListTile(
                    dense: true,
                    leading: Icon(p.label == 'Google' ? Icons.search_rounded : Icons.event_note_outlined),
                    title: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.url.host, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(p.url),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultArea(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    if (_loading) {
      return [
        const SizedBox(height: 8),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        Text(l.raceSearching, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
      ];
    }
    if (_failure != null) {
      return [
        _Notice(icon: Icons.error_outline_rounded, color: AppColors.warning, text: l.raceError),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _search, icon: const Icon(Icons.refresh_rounded), label: Text(l.raceRetry)),
        ),
      ];
    }
    final r = _result;
    if (r == null) return [Text(l.raceIntro, style: theme.textTheme.bodyMedium)];
    if (r.noSource) return [_Notice(icon: Icons.travel_explore_rounded, color: AppColors.brand, text: l.raceNoSource)];
    final failed = [
      if (r.failed.isNotEmpty) ...[
        _Notice(icon: Icons.cloud_off_rounded, color: AppColors.warning, text: l.raceSourcesFailed(r.failed.join(', '))),
        const SizedBox(height: 8),
      ],
    ];
    if (r.races.isEmpty) return [...failed, _Notice(icon: Icons.search_off_rounded, color: AppColors.brand, text: l.raceEmpty)];
    return [
      Text(l.raceResultsCount(r.races.length), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      _Notice(icon: Icons.info_outline_rounded, color: AppColors.brand, text: l.raceDisclaimer),
      const SizedBox(height: 8),
      ...failed,
      for (final race in r.races)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RaceCard(race: race, onOpen: () => _open(race.url), onTake: () => _take(race)),
        ),
      Text(l.raceDataFrom(r.sources.join(', ')), style: theme.textTheme.bodySmall),
    ];
  }

  Future<void> _open(Uri u) async {
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser available – nothing to do.
    }
  }

  /// One horizontally scrolling row of chips (keeps the filters short on small phones).
  Widget _chipRow(List<Widget> chips) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [for (final (i, c) in chips.indexed) Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 8), child: c)]),
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}

class _RaceCard extends StatelessWidget {
  const _RaceCard({required this.race, required this.onOpen, required this.onTake});
  final RaceResult race;
  final VoidCallback onOpen;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final df = DateFormat.yMMMEd(context.localeName);
    final date = race.endDate == null ? df.format(race.date) : '${df.format(race.date)} – ${df.format(race.endDate!)}';
    final distances = [for (final k in race.distanceKeys) eventDistanceLabel(l, k), ...race.distances];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(race.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          _line(Icons.event_rounded, date, small),
          if (race.place.isNotEmpty) _line(Icons.place_outlined, race.place, small),
          if (distances.isNotEmpty) _line(Icons.straighten_rounded, distances.join(' · '), small),
          _line(Icons.link_rounded, l.raceSourceOf(race.source), small),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(l.raceOrganiserPage),
              ),
              FilledButton.tonalIcon(onPressed: onTake, icon: const Icon(Icons.flag_rounded, size: 18), label: Text(l.raceSetAsGoal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, TextStyle? style) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: style?.color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
