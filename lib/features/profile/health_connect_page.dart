import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/health_service.dart';
import '../../widgets/common.dart';
import '../shell/health_sync.dart';

/// Connect Health Connect (Samsung Health / Galaxy Watch) and show sync status.
class HealthConnectPage extends ConsumerStatefulWidget {
  const HealthConnectPage({super.key});
  @override
  ConsumerState<HealthConnectPage> createState() => _HealthConnectPageState();
}

class _HealthConnectPageState extends ConsumerState<HealthConnectPage> {
  HealthStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final s = await ref.read(healthServiceProvider).status().catchError((_) => HealthStatus.unavailable);
    if (mounted) setState(() => _status = s);
  }

  Future<void> _connect() async {
    final l = context.l10n;
    setState(() => _busy = true);
    final hs = ref.read(healthServiceProvider);
    try {
      final ok = await hs.connect();
      ref.read(healthTickProvider.notifier).bump();
      if (!mounted) return;
      toast(context, ok ? l.hcConnected : l.hcDenied);
      if (ok) {
        final n = await ref.read(healthSyncProvider.future);
        if (mounted) toast(context, l.hcImported(n));
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hs = ref.watch(healthServiceProvider);
    ref.watch(healthTickProvider);
    final vitals = ref.watch(vitalsProvider).value;
    final imported = ref.watch(sessionListProvider).where((s) => s.externalId != null).length;
    final last = hs.lastSync;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF1F3B73), Color(0xFF3A6FD8)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.watch_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 10),
                    Icon(Icons.sync_alt_rounded, color: Colors.white70),
                    SizedBox(width: 10),
                    Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
                    SizedBox(width: 10),
                    Icon(Icons.sync_alt_rounded, color: Colors.white70),
                    SizedBox(width: 10),
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 14),
                Text(l.hcTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(l.hcSub, style: const TextStyle(color: Colors.white, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_status == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_status == HealthStatus.unavailable)
            _Info(icon: Icons.error_outline, color: AppColors.danger, text: l.hcUnavailable)
          else if (_status == HealthStatus.needsInstall)
            Column(
              children: [
                _Info(icon: Icons.download_rounded, color: AppColors.warning, text: l.hcInstall),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await hs.install();
                    _refreshStatus();
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.hcInstallButton),
                ),
              ],
            )
          else if (!hs.connected)
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link_rounded),
                label: Text(l.hcConnect),
              ),
            )
          else ...[
            _Info(icon: Icons.check_circle_rounded, color: AppColors.success, text: l.hcConnectedInfo),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: StatTile(label: l.hcImportedLabel, value: '$imported', icon: Icons.download_done_rounded)),
                      Expanded(
                        child: StatTile(
                          label: l.hcLastSync,
                          value: last == null ? '–' : DateFormat.Hm(context.localeName).format(last),
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (vitals != null && !vitals.isEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(child: StatTile(label: l.steps, value: vitals.steps == null ? '–' : compactNumber(vitals.steps!.toDouble()), icon: Icons.directions_walk)),
                        Expanded(child: StatTile(label: l.restingHr, value: vitals.restingHr == null ? '–' : '${vitals.restingHr}', icon: Icons.favorite_border, color: AppColors.danger)),
                        Expanded(child: StatTile(label: l.sleep, value: vitals.sleepMin == null ? '–' : humanDuration(vitals.sleepMin! * 60), icon: Icons.bedtime_outlined, color: AppColors.brand)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        _busy
                            ? null
                            : () async {
                              setState(() => _busy = true);
                              ref.read(healthTickProvider.notifier).bump();
                              final n = await ref.read(healthSyncProvider.future);
                              if (context.mounted) toast(context, l.hcImported(n));
                              if (mounted) setState(() => _busy = false);
                            },
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(l.hcSyncNow),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await hs.disconnect();
                    ref.read(healthTickProvider.notifier).bump();
                    setState(() {});
                  },
                  child: Text(l.hcDisconnect),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(l.hcSetupTitle, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final (i, step) in [l.hcStep1, l.hcStep2, l.hcStep3, l.hcStep4].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 13, backgroundColor: AppColors.brand.withValues(alpha: 0.2), child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step, style: const TextStyle(height: 1.35))),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse('market://details?id=com.sec.android.app.shealth'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: Text(l.hcOpenSamsung),
          ),
          const SizedBox(height: 12),
          Text(l.hcWhatSynced, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(l.hcWhatSyncedBody, style: t.bodySmall?.copyWith(height: 1.4)),
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
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}
