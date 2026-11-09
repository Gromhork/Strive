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
import 'features/auth/login_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/gcal_sync.dart';
import 'features/shell/relocalize_sync.dart';
import 'features/shell/health_sync.dart';
import 'features/shell/reminder_sync.dart';
import 'firebase_options.dart';
import 'l10n/gen/app_localizations.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) HttpOverrides.global = _DevTlsInspectionOverrides();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Offline mode: everything is cached locally and synced when online.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const StriveApp()));
}

class StriveApp extends ConsumerWidget {
  const StriveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // App-level (always active) so reminder scheduling is never paused by offstage routes.
    ref.watch(reminderSyncProvider);
    ref.watch(healthSyncProvider);
    ref.watch(gcalAutoSyncProvider);
    ref.watch(relocalizeSyncProvider);
    return MaterialApp(
      title: 'Strive',
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
        return child!;
      },
      home: const AuthGate(),
    );
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
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const LoginPage();
        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (p) => (p == null || !p.onboarded) ? const OnboardingPage() : const HomeShell(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: StriveLogo(size: 72)));
}

class StriveLogo extends StatelessWidget {
  const StriveLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        ),
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
