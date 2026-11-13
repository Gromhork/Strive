import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../shell/account.dart';
import '../shell/gcal_sync.dart';
import '../shell/health_sync.dart';
import 'google_calendar_page.dart';
import 'health_connect_page.dart';
import '../../services/google_auth.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../../widgets/settings.dart';
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
    // Signed in (auth stream) → the current user object, which also reflects a just-linked guest.
    final user = ref.watch(authProvider).value == null ? null : FirebaseAuth.instance.currentUser;
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(user?.isAnonymous == true ? l.guestAccount : (user?.email ?? ''), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('${p.focus.label(l)} · ${l.experienceIs(_level(l, p.level))}', style: Theme.of(context).textTheme.bodySmall),
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
          // Guests first see how to keep their data – not buried below the settings.
          if (user?.isAnonymous == true) ...[const SizedBox(height: 16), const SecureGuestCard()],
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.levelN(g.level.level),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        SizedBox(
                          width: 110,
                          child: Text('${s.label(l)} ${g.sportLevels[s]!.level}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
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
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                title: l.editProfile,
                subtitle: l.editProfileSub,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.profile))),
              ),
              SettingsTile(
                icon: Icons.tune_rounded,
                title: l.planSettings,
                subtitle: l.editPlanSettingsSub,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(mode: SetupMode.plan))),
              ),
              SettingsTile(
                icon: Icons.flag_outlined,
                title: l.goals,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())),
              ),
              SettingsTile(
                icon: Icons.monitor_weight_outlined,
                title: l.bodyComposition,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyPage())),
              ),
              SettingsTile(
                icon: Icons.menu_book_outlined,
                title: l.glossary,
                subtitle: l.glossaryHint,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlossaryPage())),
              ),
            ],
          ),
          SettingsSection(
            title: l.settings,
            children: [
              SettingsChoiceTile<String?>(
                key: const ValueKey('languageSetting'),
                icon: Icons.language_rounded,
                title: l.language,
                options: {null: l.system, 'de': 'Deutsch', 'en': 'English'},
                selected: settings.locale,
                onChanged: (v) => setN.update(settings.copyWith(locale: v, clearLocale: v == null)),
              ),
              SettingsChoiceTile<ThemeMode>(
                key: const ValueKey('themeSetting'),
                icon: Icons.dark_mode_outlined,
                title: l.theme,
                options: {ThemeMode.system: l.system, ThemeMode.dark: l.dark, ThemeMode.light: l.light},
                selected: settings.themeMode,
                onChanged: (v) => setN.update(settings.copyWith(themeMode: v)),
              ),
              SettingsSwitchTile(
                key: const ValueKey('imperialSetting'),
                icon: Icons.straighten_rounded,
                title: l.imperial,
                value: p.imperial,
                onChanged: (v) => repo?.saveProfile(p.copyWith(imperial: v)),
              ),
              SettingsSwitchTile(
                key: const ValueKey('vibrationSetting'),
                icon: Icons.vibration_rounded,
                title: l.vibration,
                subtitle: l.vibrationSub,
                info: l.vibrationInfo,
                value: settings.vibrate,
                onChanged: (v) => setN.update(settings.copyWith(vibrate: v)),
              ),
              SettingsSwitchTile(
                key: const ValueKey('logRirSetting'),
                icon: Icons.battery_5_bar_rounded,
                title: l.logRirSetting,
                subtitle: l.logRirSettingShort,
                info: l.logRirSettingInfo,
                value: settings.logRir,
                onChanged: (v) => setN.update(settings.copyWith(logRir: v)),
              ),
            ],
          ),
          SettingsSection(
            title: l.reminders,
            children: [
              SettingsSwitchTile(
                key: const ValueKey('trainingReminderSetting'),
                icon: Icons.notifications_active_outlined,
                title: l.trainingReminder,
                subtitle: settings.trainingReminder ? l.trainingReminderShort : l.trainingReminderSub(reminderTimeLabel(context, settings)),
                value: settings.trainingReminder,
                onChanged:
                    (v) =>
                        v
                            ? enableReminder(() async => setN.update(settings.copyWith(trainingReminder: true)))
                            : setN.update(settings.copyWith(trainingReminder: false)),
              ),
              if (settings.trainingReminder)
                SettingsTile(
                  key: const ValueKey('reminderTimeSetting'),
                  icon: Icons.schedule_rounded,
                  title: l.reminderTime,
                  value: reminderTimeLabel(context, settings),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
                    );
                    if (t != null) setN.update(settings.copyWith(reminderHour: t.hour, reminderMinute: t.minute));
                  },
                ),
            ],
          ),
          SettingsSection(
            title: l.integrations,
            children: [
              SettingsTile(
                icon: Icons.watch_rounded,
                iconColor: AppColors.danger,
                title: 'Health Connect',
                subtitle: ref.watch(healthServiceProvider).connected ? l.hcConnectedShort : l.hcTileSub,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthConnectPage())),
              ),
              SettingsTile(
                icon: Icons.calendar_month_outlined,
                iconColor: AppColors.swim,
                title: l.googleCalendar,
                subtitle: gcal.enabled && gcal.account != null ? l.gcalConnectedSub(gcal.account!) : l.googleCalendarSub,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleCalendarPage())),
              ),
            ],
          ),
          SettingsSection(
            title: l.account,
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: l.logout,
                danger: true,
                chevron: false,
                onTap: () async {
                  if (user?.isAnonymous == true && !await confirmGuestLogout(context)) return;
                  if (!context.mounted) return;
                  final out = signOutAndClear(context);
                  Navigator.popUntil(context, (r) => r.isFirst);
                  await out;
                },
              ),
              SettingsTile(
                key: const ValueKey('deleteAccount'),
                icon: Icons.delete_forever_outlined,
                title: l.deleteAccount,
                subtitle: l.deleteAccountSub,
                danger: true,
                chevron: false,
                onTap: () => deleteAccountFlow(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(child: Text('Strive 1.0 · ${l.offlineReady}', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _level(AppLocalizations l, String level) => switch (level) {
    'advanced' => l.advanced,
    'intermediate' => l.intermediate,
    _ => l.beginner,
  };
}

/// The reminder time in the device's format ("08:00", "8:00 AM").
String reminderTimeLabel(BuildContext context, AppSettings s) => MaterialLocalizations.of(context).formatTimeOfDay(
  TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
);

/// Links the guest account with e-mail + password.
Future<void> linkGuestWithEmail(BuildContext context) async {
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
    await FirebaseAuth.instance.currentUser!.linkWithCredential(EmailAuthProvider.credential(email: email.text.trim(), password: pw.text));
    if (context.mounted) toast(context, l.accountLinked);
  } on FirebaseAuthException catch (e) {
    if (context.mounted) toast(context, '${l.authError} (${e.code})');
  }
}

/// Links the guest account with Google.
Future<void> linkGuestWithGoogle(BuildContext context) async {
  final l = context.l10n;
  try {
    if (await GoogleAuth.signIn() && context.mounted) toast(context, l.accountLinked);
  } catch (e) {
    if (context.mounted) toast(context, '${l.authError}: $e');
  }
}

/// Guest logout: "Signing out as a guest deletes all data on this device." with
/// [Secure first] (opens the linking options) and [Sign out anyway]. True = sign out.
Future<bool> confirmGuestLogout(BuildContext context) async {
  final l = context.l10n;
  final r = await showDialog<String>(
    context: context,
    builder:
        (c) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          title: Text(l.guestLogoutTitle),
          content: Text(l.guestLogoutBody),
          actions: [
            // A way out that changes nothing (the barrier alone was not obvious).
            TextButton(key: const ValueKey('guestLogoutCancel'), onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
            // Destructive: deletes the guest's data on this device – styled as such.
            TextButton(
              key: const ValueKey('guestLogoutAnyway'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, 'out'),
              child: Text(l.guestLogoutAnyway),
            ),
            FilledButton(
              key: const ValueKey('guestSecureFirst'),
              onPressed: () => Navigator.pop(c, 'secure'),
              child: Text(l.guestSecureFirst),
            ),
          ],
        ),
  );
  if (r == 'secure' && context.mounted) await showSecureGuestSheet(context);
  return r == 'out';
}

/// The two ways to keep a guest's data (e-mail, Google).
Future<void> showSecureGuestSheet(BuildContext context) {
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l.secureGuestTitle, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email_rounded),
                title: Text(l.upgradeAccount),
                subtitle: Text(l.upgradeAccountSub),
                onTap: () {
                  Navigator.pop(c);
                  linkGuestWithEmail(context);
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/images/google.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(Icons.login),
                ),
                title: Text(l.linkGoogle),
                subtitle: Text(l.linkGoogleSub),
                onTap: () {
                  Navigator.pop(c);
                  linkGuestWithGoogle(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
  );
}

/// "Secure your data – link e-mail or Google" (profile top, and on Home for guests with
/// a few sessions).
class SecureGuestCard extends StatelessWidget {
  const SecureGuestCard({super.key, this.onDismiss});
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      key: const ValueKey('secureGuestCard'),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.shield_outlined, color: AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.secureGuestTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(l.secureGuestBody, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                FilledButton.tonal(
                  key: const ValueKey('secureGuestButton'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => showSecureGuestSheet(context),
                  child: Text(l.secureGuestButton),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
