import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/active_workout.dart';
import '../../services/tracker.dart';
import '../calendar/calendar_page.dart';
import '../coach/coach_page.dart';
import '../home/home_page.dart';
import '../profile/profile_page.dart';
import '../session/cardio_session_page.dart';
import '../session/gym_session_page.dart';
import '../stats/stats_page.dart';
import '../train/train_page.dart';
import 'streak_sheet.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  /// Time of the last back press on Home (double-press to exit).
  static DateTime? _lastBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final index = ref.watch(navIndexProvider);
    const pages = [HomePage(), TrainPage(), CalendarPage(), StatsPage(), CoachPage()];
    // Android back: from another tab back to Home; on Home a first press only shows a hint,
    // a second press within 2 s closes the app (instead of leaving it from anywhere).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index != 0) {
          ref.read(navIndexProvider.notifier).set(0);
          return;
        }
        final now = DateTime.now();
        if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.backAgainToExit), duration: const Duration(seconds: 2)));
      },
      child: Scaffold(
        appBar: const StriveTopBar(),
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ActiveBanner(),
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: ref.read(navIndexProvider.notifier).set,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bolt_outlined),
                  selectedIcon: const Icon(Icons.bolt_rounded),
                  label: l.navTrain,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month_rounded),
                  label: l.navCalendar,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights_rounded),
                  label: l.navStats,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const Icon(Icons.auto_awesome),
                  label: l.navCoach,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Top bar: streak · sport switcher · profile (matches the "Pages design" sketch).
class StriveTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const StriveTopBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stats = ref.watch(gameStatsProvider);
    final filter = ref.watch(sportFilterProvider);
    final profile = ref.watch(profileOrDefaultProvider);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Tooltip(
                message: l.weekStreakTooltip,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showStreakSheet(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: stats.weekStreak > 0 ? 0.16 : 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 20,
                          color: stats.weekStreak > 0 ? AppColors.danger : scheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text('${stats.weekStreak}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterButton(
                      selected: filter == null,
                      color: AppColors.brand,
                      icon: Icons.all_inclusive_rounded,
                      tooltip: l.allSports,
                      onTap: () => ref.read(sportFilterProvider.notifier).set(null),
                    ),
                    for (final s in Sport.values)
                      _FilterButton(
                        selected: filter == s,
                        color: s.color,
                        icon: s.icon,
                        tooltip: s.label(l),
                        onTap: () => ref.read(sportFilterProvider.notifier).set(filter == s ? null : s),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.25),
                      child: Text(
                        profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '${stats.level.level}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.selected, required this.color, required this.icon, required this.onTap, required this.tooltip});
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 19, color: selected ? color : Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

/// Shows a running gym workout or cardio recording above the navigation bar.
class _ActiveBanner extends ConsumerWidget {
  const _ActiveBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gym = ref.watch(activeGymProvider);
    final cardio = ref.watch(trackerProvider);
    if (gym == null && cardio == null) return const SizedBox.shrink();
    final sport = gym != null ? Sport.gym : cardio!.sport;
    final title = gym?.title ?? cardio!.title;
    return Material(
      color: sport.color.withValues(alpha: 0.18),
      child: InkWell(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => gym != null ? const GymSessionPage() : const CardioSessionPage()),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(sport.icon, color: sport.color),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              _Elapsed(start: gym?.start, cardio: cardio),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Elapsed extends StatelessWidget {
  const _Elapsed({this.start, this.cardio});
  final DateTime? start;
  final CardioState? cardio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, __) {
        final sec = cardio?.elapsed ?? DateTime.now().difference(start!).inSeconds;
        return Text(clock(sec), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w600));
      },
    );
  }
}
