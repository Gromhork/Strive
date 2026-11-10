import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/active_workout.dart';
import '../../widgets/common.dart';
import 'step_text.dart' show hrZoneOf;

/// Sport-specific music suggestions (opened in Spotify by search query).
///
/// Basis:
/// * Running – music synchronised with the step rate makes running more economical
///   and feel easier (Terry et al. 2012, Bood et al. 2013). Recreational cadence is
///   ~150–160 spm easy and ~170–185 spm fast, so the tempo follows the intensity.
/// * Cycling – one beat per pedal stroke (or two: "double time"); typical cadence is
///   80–100 rpm, sprints 100–110 rpm (Waterhouse et al. 2010: faster music → higher
///   cadence and power). Spinning classes use 128–140 BPM for hard efforts.
/// * Strength – 120–140 BPM, loud and motivating music helps moderate-to-hard work
///   (Karageorghis & Priest 2012); circuits/HIIT higher, warm-up and stretching lower.
/// * Swimming – Bluetooth does not work under water: only waterproof bone-conduction
///   players with on-board storage, so the sheet leads with that hint.

/// Id of a suggestion; the "right now" pick refers to one of these.
enum MusicId { easy, steady, hard, max, podcast, preSwim, swimList, warmup, strength, heavy, circuit, cooldown }

class MusicOption {
  const MusicOption({required this.id, required this.icon, required this.title, required this.sub, required this.query});
  final MusicId id;
  final IconData icon;
  final String title;
  final String sub;

  /// Spotify search query (English – Spotify's catalogue tags are English).
  final String query;
}

class MusicPlan {
  const MusicPlan({required this.intro, required this.options, this.now, this.hint});
  final String intro;
  final List<MusicOption> options;

  /// Suggestion matching the current step / exercise (null: none, e.g. swims).
  final MusicOption? now;

  /// Safety / equipment note shown prominently (outdoor rides, swims).
  final String? hint;
}

/// Intensity of a structured step: warm-up, cool-down and rests are easy; work steps
/// follow their zone (E/Z2 easy · M/Z3/SS steady · T/Z4/CSS hard · I/R/Z5+/SP max).
MusicId musicIdOfStep(WorkoutStep? st) {
  if (st == null || st.kind == 'warmup' || st.kind == 'cooldown' || st.kind == 'recovery') return MusicId.easy;
  switch (st.zone) {
    case 'TE':
      return MusicId.steady;
    case 'CSS':
      return MusicId.hard;
    case 'SP':
      return MusicId.max;
  }
  return switch (hrZoneOf(st.zone)) {
    5 => MusicId.max,
    4 => MusicId.hard,
    3 => MusicId.steady,
    _ => MusicId.easy,
  };
}

/// What fits the gym workout right now: warm-up sets first, low-rep heavy sets,
/// supersets/circuits, or stretching once everything is done.
MusicId gymMusicNow(ActiveGym w) {
  final i = w.nextOpen(w.focus);
  if (i == null) return w.exercises.isEmpty ? MusicId.strength : MusicId.cooldown;
  final e = w.exercises[i];
  final open = e.sets.where((s) => !s.done).toList();
  if (w.doneSets == 0 && open.isNotEmpty && open.first.warmup) return MusicId.warmup;
  if (w.groupOf(i).length > 1) return MusicId.circuit;
  final work = open.where((s) => !s.warmup).toList();
  if (work.isNotEmpty && work.first.reps > 0 && work.first.reps <= 5) return MusicId.heavy;
  return MusicId.strength;
}

/// Builds the suggestions for [sport]. [now] is the suggestion for the current step
/// (cardio: [musicIdOfStep], gym: [gymMusicNow]); swims never get one.
MusicPlan musicPlan(AppLocalizations l, Sport sport, {bool indoor = false, MusicId? now}) {
  String rpm(int lo, int hi, String bpm) => '$lo–$hi ${l.musicRpm} · $bpm BPM';
  final List<MusicOption> options;
  final String intro;
  String? hint;
  switch (sport) {
    case Sport.run:
      intro = l.musicIntroRun;
      options = [
        MusicOption(
          id: MusicId.easy,
          icon: Icons.directions_walk_rounded,
          title: l.musicRunEasy,
          sub: '150–160 BPM',
          query: 'easy running 155 bpm',
        ),
        MusicOption(
          id: MusicId.steady,
          icon: Icons.directions_run_rounded,
          title: l.musicRunSteady,
          sub: '160–170 BPM',
          query: 'running 165 bpm',
        ),
        MusicOption(
          id: MusicId.hard,
          icon: Icons.speed_rounded,
          title: l.musicRunTempo,
          sub: '170–180 BPM',
          query: 'tempo running 175 bpm',
        ),
        MusicOption(
          id: MusicId.max,
          icon: Icons.bolt_rounded,
          title: l.musicRunIntervals,
          sub: '180–190 BPM',
          query: 'running intervals 185 bpm',
        ),
        MusicOption(
          id: MusicId.podcast,
          icon: Icons.podcasts_rounded,
          title: l.musicPodcasts,
          sub: l.musicPodcastsRun,
          query: 'running podcast',
        ),
      ];
    case Sport.ride:
      intro = l.musicIntroRide;
      hint = indoor ? null : l.musicRideSafety;
      options = [
        MusicOption(
          id: MusicId.easy,
          icon: Icons.spa_rounded,
          title: l.musicRideEasy,
          sub: rpm(80, 90, '80–90 / 160–180'),
          query: 'chill cycling 85 bpm',
        ),
        MusicOption(
          id: MusicId.steady,
          icon: Icons.directions_bike_rounded,
          title: l.musicRideSteady,
          sub: rpm(85, 95, '85–95 / 170–190'),
          query: 'cycling endurance 90 bpm',
        ),
        MusicOption(
          id: MusicId.hard,
          icon: Icons.speed_rounded,
          title: l.musicRideThreshold,
          sub: rpm(90, 100, '90–100 / 180–200'),
          query: 'cycling workout 95 bpm',
        ),
        MusicOption(
          id: MusicId.max,
          icon: Icons.bolt_rounded,
          title: l.musicRideIntervals,
          sub: rpm(100, 110, '128–140'),
          query: 'spinning high energy 130 bpm',
        ),
        MusicOption(
          id: MusicId.podcast,
          icon: Icons.podcasts_rounded,
          title: l.musicPodcasts,
          sub: indoor ? l.musicPodcastsTrainer : l.musicPodcastsRide,
          query: indoor ? 'indoor cycling podcast' : 'cycling podcast',
        ),
      ];
    case Sport.swim:
      intro = l.musicIntroSwim;
      hint = indoor ? l.musicSwimPoolHint : l.musicSwimOpenHint;
      options = [
        MusicOption(
          id: MusicId.preSwim,
          icon: Icons.self_improvement_rounded,
          title: l.musicPreSwim,
          sub: '110–125 BPM',
          query: 'pre workout warm up 120 bpm',
        ),
        MusicOption(
          id: MusicId.swimList,
          icon: Icons.download_rounded,
          title: l.musicSwimList,
          sub: l.musicSwimListSub,
          query: 'swimming playlist',
        ),
        MusicOption(id: MusicId.podcast, icon: Icons.podcasts_rounded, title: l.musicPodcasts, sub: l.musicPodcastsSwim, query: 'podcast'),
      ];
    case Sport.gym:
      intro = l.musicIntroGym;
      hint = l.musicGymHint;
      options = [
        MusicOption(
          id: MusicId.warmup,
          icon: Icons.self_improvement_rounded,
          title: l.musicGymWarmup,
          sub: '100–120 BPM',
          query: 'warm up workout 115 bpm',
        ),
        MusicOption(
          id: MusicId.strength,
          icon: Sport.gym.icon,
          title: l.musicGymStrength,
          sub: '120–135 BPM',
          query: 'gym workout 130 bpm',
        ),
        MusicOption(
          id: MusicId.heavy,
          icon: Icons.whatshot_rounded,
          title: l.musicGymHeavy,
          sub: '130–145 BPM',
          query: 'heavy lifting motivation 140 bpm',
        ),
        MusicOption(
          id: MusicId.circuit,
          icon: Icons.bolt_rounded,
          title: l.musicGymCircuit,
          sub: '140–170 BPM',
          query: 'hiit workout 160 bpm',
        ),
        MusicOption(
          id: MusicId.cooldown,
          icon: Icons.spa_rounded,
          title: l.musicGymCooldown,
          sub: '70–100 BPM',
          query: 'stretching cool down',
        ),
      ];
  }
  final pick = now == null || sport == Sport.swim ? null : options.where((o) => o.id == now).firstOrNull;
  return MusicPlan(intro: intro, options: options, now: pick, hint: hint);
}

/// Gym suggestions with the "right now" pick from the workout state.
MusicPlan gymMusicPlan(AppLocalizations l, ActiveGym? w) => musicPlan(l, Sport.gym, now: w == null ? MusicId.strength : gymMusicNow(w));

const spotifyGreen = Color(0xFF1DB954);

/// App-bar button that opens the music sheet.
class MusicButton extends StatelessWidget {
  const MusicButton({super.key, required this.plan});

  /// Built lazily so "right now" reflects the state at the moment of the tap.
  final MusicPlan Function() plan;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.music,
    icon: const Icon(Icons.music_note_rounded, color: spotifyGreen),
    onPressed: () => showMusicSheet(context, plan()),
  );
}

/// Opens Spotify searches for the suggestions, or the user's own playlist link.
Future<void> showMusicSheet(BuildContext context, MusicPlan plan) {
  final l = context.l10n;
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
        (c) => Consumer(
          builder: (c, ref, _) {
            final prefs = ref.read(prefsProvider);
            final own = prefs.getString('spotifyPlaylist');
            final t = Theme.of(c).textTheme;
            final now = plan.now;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: spotifyGreen, size: 28),
                        const SizedBox(width: 8),
                        Text('Spotify', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(plan.intro, style: t.bodySmall),
                    if (plan.hint != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(c).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(plan.hint!, style: t.bodySmall)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (now != null)
                      _MusicTile(
                        icon: Icons.auto_awesome,
                        title: l.musicForNow(now.title),
                        sub: now.sub,
                        highlight: true,
                        onTap: () => search(now.query),
                      ),
                    for (final o in plan.options)
                      if (o.id != now?.id) _MusicTile(icon: o.icon, title: o.title, sub: o.sub, onTap: () => search(o.query)),
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
            );
          },
        ),
  );
}

class _MusicTile extends StatelessWidget {
  const _MusicTile({required this.icon, required this.title, required this.sub, required this.onTap, this.highlight = false});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  final bool highlight;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.symmetric(horizontal: highlight ? 8 : 0),
    shape: highlight ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)) : null,
    tileColor: highlight ? spotifyGreen.withValues(alpha: 0.14) : null,
    leading: CircleAvatar(backgroundColor: spotifyGreen.withValues(alpha: 0.18), child: Icon(icon, color: spotifyGreen)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: onTap,
  );
}
