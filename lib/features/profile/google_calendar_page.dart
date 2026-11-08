import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/gcal_api.dart';
import '../../services/gcal_mapping.dart';
import '../../widgets/common.dart';
import '../shell/gcal_sync.dart';

String gcalErrorText(AppLocalizations l, GcalErrorKind kind, String? detail) => switch (kind) {
  GcalErrorKind.apiDisabled => l.gcalErrApiDisabled,
  GcalErrorKind.auth => l.gcalErrAuth,
  GcalErrorKind.offline => l.gcalErrOffline,
  GcalErrorKind.rateLimit => l.gcalErrRateLimit,
  _ => l.gcalErrGeneric(detail ?? kind.name),
};

/// Connect Strive to a separate "Strive" calendar in Google Calendar and show the sync status.
class GoogleCalendarPage extends ConsumerStatefulWidget {
  const GoogleCalendarPage({super.key});
  @override
  ConsumerState<GoogleCalendarPage> createState() => _GoogleCalendarPageState();
}

class _GoogleCalendarPageState extends ConsumerState<GoogleCalendarPage> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } on GcalException catch (e) {
      if (mounted) toast(context, gcalErrorText(context.l10n, e.kind, e.message));
    } catch (e) {
      if (mounted) toast(context, '${context.l10n.authError}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _guard(() async {
    final l = context.l10n;
    final ok = await ref.read(gcalProvider.notifier).connect();
    if (!ok || !mounted) return;
    final s = ref.read(gcalProvider);
    toast(context, s.error == null ? '${l.gcalConnectedToast} · ${l.gcalSynced(s.eventCount)}' : gcalErrorText(l, s.error!, s.errorDetail));
  });

  Future<void> _syncNow() => _guard(() async {
    final l = context.l10n;
    final n = await ref.read(gcalProvider.notifier).sync();
    if (!mounted) return;
    final s = ref.read(gcalProvider);
    toast(context, n != null ? l.gcalSynced(n) : gcalErrorText(l, s.error ?? GcalErrorKind.other, s.errorDetail));
  });

  Future<void> _disconnect() async {
    final l = context.l10n;
    final choice = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(l.gcalDisconnectTitle),
            content: Text(l.gcalDisconnectBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.gcalKeepCalendar)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(c, true),
                child: Text(l.gcalDeleteCalendar),
              ),
            ],
          ),
    );
    if (choice == null || !mounted) return;
    await _guard(() async {
      await ref.read(gcalProvider.notifier).disconnect(deleteCalendar: choice);
      if (mounted) toast(context, l.gcalDisconnected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(gcalProvider);
    final t = Theme.of(context).textTheme;
    final pref = ref.watch(profileOrDefaultProvider).athlete.preferredTime;
    final prefLabel = switch (pref) {
      'morning' => l.morning,
      'midday' => l.midday,
      _ => l.evening,
    };
    final time = '$prefLabel, ${gcalStartHour(pref).toString().padLeft(2, '0')}:00';
    final busy = _busy || s.syncing;
    final last = s.lastSync;
    final lastText =
        last == null
            ? '–'
            : (sameDay(last, DateTime.now()) ? DateFormat.Hm(context.localeName) : DateFormat.MMMd(context.localeName).add_Hm()).format(
              last,
            );

    return Scaffold(
      appBar: AppBar(title: Text(l.googleCalendar)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF34A853)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 34),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white70),
                    SizedBox(width: 10),
                    Icon(Icons.calendar_month_rounded, color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 14),
                Text(l.gcalHeroTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(l.gcalHeroSub, style: const TextStyle(color: Colors.white, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s.error != null) ...[
            _Info(icon: Icons.error_outline, color: AppColors.danger, text: gcalErrorText(l, s.error!, s.errorDetail)),
            const SizedBox(height: 12),
          ],
          if (!s.enabled)
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: busy ? null : _connect,
                icon:
                    busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link_rounded),
                label: Text(l.gcalConnect),
              ),
            )
          else ...[
            if (s.error == null) ...[
              _Info(icon: Icons.check_circle_rounded, color: AppColors.success, text: l.gcalAutoInfo),
              const SizedBox(height: 12),
            ],
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.gcalAccount, style: t.bodySmall),
                            Text(s.account ?? '–', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: StatTile(label: l.gcalEvents, value: '${s.eventCount}', icon: Icons.event_available_rounded)),
                      Expanded(
                        child: StatTile(label: l.gcalLastSync, value: s.syncing ? l.gcalSyncing : lastText, icon: Icons.schedule_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (s.error == GcalErrorKind.auth) ...[
              FilledButton.icon(onPressed: busy ? null : _connect, icon: const Icon(Icons.link_rounded), label: Text(l.gcalReconnect)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : _syncNow,
                    icon:
                        busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync_rounded),
                    label: Text(l.gcalSyncNow, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: busy ? null : _disconnect, child: Text(l.gcalDisconnect)),
              ],
            ),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://calendar.google.com/'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: Text(l.gcalOpen),
            ),
          ],
          const SizedBox(height: 24),
          Text(l.gcalHowTitle, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final (icon, text) in [
            (Icons.lock_outline_rounded, l.gcalHow1),
            (Icons.schedule_rounded, l.gcalHow2(time)),
            (Icons.visibility_off_outlined, l.gcalHow3),
            (Icons.edit_off_outlined, l.gcalHow4),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 14, backgroundColor: AppColors.brand.withValues(alpha: 0.2), child: Icon(icon, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(height: 1.35)))],
    ),
  );
}
