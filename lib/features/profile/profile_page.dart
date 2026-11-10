import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../shell/gcal_sync.dart';
import '../shell/health_sync.dart';
import 'google_calendar_page.dart';
import 'health_connect_page.dart';
import '../../services/google_auth.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../goals/goals_page.dart';
import '../onboarding/onboarding_page.dart';
import '../stats/body_page.dart';
import '../../widgets/term_info.dart';
import '../stats/stats_page.dart' show BadgeView;

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileOrDefaultProvider);
    final g = ref.watch(gameStatsProvider);
    final settings = ref.watch(settingsProvider);
    final setN = ref.read(settingsProvider.notifier);
    final user = FirebaseAuth.instance.currentUser;
    final repo = ref.read(repoProvider);
    final gcal = ref.watch(gcalProvider);

    Future<void> enableReminder(Future<void> Function() apply) async {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok && context.mounted) {
        toast(context, l.notificationsDenied);
        return;
      }
      await apply();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.brand.withValues(alpha: 0.25),
                child: Text(
                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.brand),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name.isEmpty ? l.athlete : p.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(user?.isAnonymous == true ? l.guestAccount : (user?.email ?? ''), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('${p.focus.label(l)} · ${_level(l, p.level)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.editProfile,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.profile))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Text(l.levelN(g.level.level), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const Spacer(),
                    Text('${g.totalXp} XP'),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: g.level.progress, minHeight: 8)),
                const SizedBox(height: 16),
                for (final s in Sport.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(s.icon, color: s.color, size: 20),
                        const SizedBox(width: 8),
                        SizedBox(width: 110, child: Text('${s.label(l)} ${g.sportLevels[s]!.level}')),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: g.sportLevels[s]!.progress,
                            color: s.color,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.badges,
            child: SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                // The progress ring's stroke reaches past its box – keep it off the clip edge.
                padding: const EdgeInsets.only(top: 6),
                children: [
                  for (final b in [...g.badges.where((b) => b.earned), ...g.badges.where((b) => !b.earned)])
                    SizedBox(width: 76, child: BadgeView(badge: b)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(l.editProfile),
                  subtitle: Text(l.editProfileSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.profile))),
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(l.planSettings),
                  subtitle: Text(l.editPlanSettingsSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan))),
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l.goals),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(l.glossary),
                  subtitle: Text(l.glossaryHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlossaryPage())),
                ),
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text(l.bodyComposition),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyPage())),
                ),
              ],
            ),
          ),
          _header(context, l.settings),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l.language),
                  trailing: DropdownButton<String?>(
                    value: settings.locale,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.system)),
                      const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                      const DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setN.update(settings.copyWith(locale: v, clearLocale: v == null)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(l.theme),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(l.system)),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(l.dark)),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(l.light)),
                    ],
                    onChanged: (v) => setN.update(settings.copyWith(themeMode: v)),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.straighten),
                  title: Text(l.imperial),
                  value: p.imperial,
                  onChanged: (v) => repo?.saveProfile(p.copyWith(imperial: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: Text(l.vibration),
                  subtitle: Text(l.vibrationSub),
                  value: settings.vibrate,
                  onChanged: (v) => setN.update(settings.copyWith(vibrate: v)),
                ),
                SwitchListTile(
                  key: const ValueKey('logRirSetting'),
                  secondary: const Icon(Icons.battery_5_bar_rounded),
                  title: Text(l.logRirSetting),
                  subtitle: Text(l.logRirSettingSub),
                  value: settings.logRir,
                  onChanged: (v) => setN.update(settings.copyWith(logRir: v)),
                ),
              ],
            ),
          ),
          _header(context, l.reminders),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.water_drop_outlined, color: AppColors.swim),
                  title: Text(l.hydrationReminder),
                  subtitle: Text(l.everyNHours(settings.hydrationInterval)),
                  value: settings.hydration,
                  onChanged:
                      (v) =>
                          v
                              ? enableReminder(() async => setN.update(settings.copyWith(hydration: true)))
                              : setN.update(settings.copyWith(hydration: false)),
                ),
                if (settings.hydration)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: settings.hydrationInterval.toDouble(),
                      min: 1,
                      max: 4,
                      divisions: 3,
                      label: l.everyNHours(settings.hydrationInterval),
                      onChanged: (v) => setN.update(settings.copyWith(hydrationInterval: v.round())),
                    ),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.brand),
                  title: Text(l.trainingReminder),
                  subtitle: Text(l.trainingReminderSub('${settings.reminderHour}:00')),
                  value: settings.trainingReminder,
                  onChanged:
                      (v) =>
                          v
                              ? enableReminder(() async => setN.update(settings.copyWith(trainingReminder: true)))
                              : setN.update(settings.copyWith(trainingReminder: false)),
                ),
                if (settings.trainingReminder)
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(l.reminderTime),
                    trailing: Text('${settings.reminderHour}:00'),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: settings.reminderHour, minute: 0));
                      if (t != null) setN.update(settings.copyWith(reminderHour: t.hour));
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: Text(l.testNotification),
                  onTap: () => enableReminder(() => NotificationService.instance.showNow('Strive', l.hydrationBody)),
                ),
              ],
            ),
          ),
          _header(context, l.integrations),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.watch_rounded, color: AppColors.danger),
                  title: const Text('Health Connect · Samsung Health'),
                  subtitle: Text(ref.watch(healthServiceProvider).connected ? l.hcConnectedShort : l.hcTileSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthConnectPage())),
                ),
                for (final (name, icon) in [
                  ('Strava', Icons.route_outlined),
                  ('Garmin Connect', Icons.watch_outlined),
                  ('MyFitnessPal / Yazio', Icons.restaurant_outlined),
                ])
                  ListTile(
                    leading: Icon(icon),
                    title: Text(name),
                    trailing: Chip(label: Text(l.comingSoon, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                  ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(l.googleCalendar),
                  subtitle: Text(gcal.enabled && gcal.account != null ? l.gcalConnectedSub(gcal.account!) : l.googleCalendarSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleCalendarPage())),
                ),
              ],
            ),
          ),
          _header(context, l.account),
          Card(
            child: Column(
              children: [
                if (user?.isAnonymous == true)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(l.upgradeAccount),
                    subtitle: Text(l.upgradeAccountSub),
                    onTap: () => _linkAccount(context),
                  ),
                if (user?.isAnonymous == true)
                  ListTile(
                    leading: Image.asset('assets/images/google.png', width: 22, height: 22),
                    title: Text(l.linkGoogle),
                    subtitle: Text(l.linkGoogleSub),
                    onTap: () async {
                      try {
                        if (await GoogleAuth.signIn() && context.mounted) toast(context, l.accountLinked);
                      } catch (e) {
                        if (context.mounted) toast(context, '${l.authError}: $e');
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: Text(l.logout, style: const TextStyle(color: AppColors.danger)),
                  onTap: () async {
                    if (user?.isAnonymous == true &&
                        !await confirm(context, l.logout, body: l.guestLogoutWarning, ok: l.logout, danger: true)) {
                      return;
                    }
                    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                    await GoogleAuth.signOut();
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Strive 1.0 · ${l.offlineReady}', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _header(BuildContext c, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(t, style: Theme.of(c).textTheme.labelLarge?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700)),
  );

  String _level(AppLocalizations l, String level) => switch (level) {
    'advanced' => l.advanced,
    'intermediate' => l.intermediate,
    _ => l.beginner,
  };

  Future<void> _linkAccount(BuildContext context) async {
    final l = context.l10n;
    final email = TextEditingController();
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(l.upgradeAccount),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l.email)),
                const SizedBox(height: 12),
                TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: l.password)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.save)),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await FirebaseAuth.instance.currentUser!.linkWithCredential(
        EmailAuthProvider.credential(email: email.text.trim(), password: pw.text),
      );
      if (context.mounted) toast(context, l.accountLinked);
    } on FirebaseAuthException catch (e) {
      if (context.mounted) toast(context, '${l.authError} (${e.code})');
    }
  }
}
