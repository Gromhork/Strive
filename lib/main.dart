import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/format.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/exercise_names_de.dart';
import 'features/auth/login_page.dart';
import 'features/calendar/auto_adjust.dart' show rootMessengerKey;
import 'features/onboarding/onboarding_page.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/account.dart';
import 'features/shell/dst_repair_sync.dart';
import 'features/shell/gym_plan_upgrade_sync.dart';
import 'features/shell/link_cleanup_sync.dart';
import 'features/shell/plan_gen_cleanup_sync.dart';
import 'features/shell/gcal_sync.dart';
import 'features/shell/program_upgrade_sync.dart';
import 'features/shell/relocalize_sync.dart';
import 'features/shell/health_sync.dart';
import 'features/shell/reminder_sync.dart';
import 'firebase_options.dart';
import 'l10n/gen/app_localizations.dart';
import 'providers.dart';
import 'services/app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) HttpOverrides.global = _DevTlsInspectionOverrides();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Before the first Firestore / Gemini request, so every request carries a token.
  await activateAppCheck();
  // Offline mode: everything is cached locally and synced when online.
  FirebaseFirestore.instance.settings = firestoreSettings;
  WriteErrorNotifier.install();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  exerciseNamePrefs = prefs; // cached German exercise names (translation service)
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const StriveApp()));
}

class StriveApp extends ConsumerWidget {
  const StriveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Strive',
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale == null ? null : Locale(settings.locale!),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        Units.decimalComma = Localizations.localeOf(context).languageCode == 'de';
        WriteErrorNotifier.text = context.l10n.writeFailed;
        return _SyncHost(child: child!);
      },
      home: const AuthGate(),
    );
  }
}

/// Keeps the background syncs running: app-level (above the navigator, always active) so reminder
/// scheduling is never paused by offstage routes. Their own widget: a sync's state change
/// rebuilds only this – it used to rebuild the whole MaterialApp.
class _SyncHost extends ConsumerWidget {
  const _SyncHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reminderSyncProvider);
    ref.watch(healthSyncProvider);
    ref.watch(gcalAutoSyncProvider);
    ref.watch(relocalizeSyncProvider);
    ref.watch(programUpgradeSyncProvider);
    ref.watch(dstRepairSyncProvider);
    ref.watch(gymPlanUpgradeSyncProvider);
    ref.watch(linkCleanupSyncProvider);
    ref.watch(planGenCleanupSyncProvider);
    return child;
  }
}

/// Routes between login, onboarding and the main app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => _LoadError(error: e),
      data: (user) {
        if (user == null) return const LoginPage();
        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, _) => _LoadError(error: e),
          data: (p) => (p == null || !p.onboarded) ? const OnboardingPage() : const HomeShell(),
        );
      },
    );
  }
}

/// Sign-in state or profile could not be loaded: a readable message with "Retry" and
/// "Log out" instead of a raw exception (the technical error is only logged).
class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('AuthGate load error: $error');
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 16),
                Text(l.loadFailedTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l.loadFailedBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('loadRetry'),
                  onPressed: () {
                    ref.invalidate(authProvider);
                    ref.invalidate(profileProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.retry),
                ),
                const SizedBox(height: 8),
                TextButton(key: const ValueKey('loadLogout'), onPressed: () => signOutAndClear(context), child: Text(l.logout)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading screen. The logo sits exactly in the screen centre on the app's dark background –
/// the same place, size and colour as the native splash (android res/drawable/splash_logo.xml),
/// so the hand-over from the system splash is invisible; only the name fades in below it.
class _Splash extends StatelessWidget {
  const _Splash();
  static const _size = 72.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgDark,
    // SizedBox.expand: a Stack under loose constraints shrinks to its largest child and
    // would sit in the top-left corner.
    body: SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _LogoMark(size: _size),
          Transform.translate(
            offset: const Offset(0, _size / 2 + _size * 0.2 + _size * 0.25),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'STRIVE',
                style: TextStyle(color: Colors.white, fontSize: _size * 0.36, fontWeight: FontWeight.w700, letterSpacing: _size * 0.08),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.3),
      gradient: const LinearGradient(
        colors: [AppColors.gym, AppColors.brand, AppColors.swim],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Icon(Icons.bolt_rounded, color: Colors.white, size: size * 0.66),
  );
}

class StriveLogo extends StatelessWidget {
  const StriveLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoMark(size: size),
        SizedBox(height: size * 0.2),
        Text('STRIVE', style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, letterSpacing: size * 0.08)),
      ],
    );
  }
}

/// DEBUG ONLY: the development PC runs Norton Antivirus, which re-signs HTTPS traffic with its own
/// root CA. The emulator does not trust that CA, so Dart HTTP calls (Gemini, weather) would fail.
/// Only certificates issued by that local inspection CA are accepted; release builds never include this.
class _DevTlsInspectionOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..badCertificateCallback = (cert, host, port) => cert.issuer.contains('Norton Web/Mail Shield');
}
