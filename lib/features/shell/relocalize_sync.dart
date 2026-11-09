import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/relocalize.dart';
import '../../providers.dart';

/// Generated plans and built-in programs are stored with texts in the language that was
/// active when they were created. When the app language changes (or on first start of this
/// version), those texts – and the titles of recorded sessions – are translated in Firestore once, so the plan, calendar, reminders
/// and Google Calendar all show the current language.
final relocalizeSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.uid));
  final repo = ref.watch(repoProvider);
  if (uid == null || repo == null) return;
  final code = ref.watch(settingsProvider.select((s) => s.locale)) ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final lang = code == 'de' ? 'de' : 'en';
  final plans = ref.watch(plansProvider);
  final templates = ref.watch(templatesProvider);
  final sessions = ref.watch(sessionsProvider);
  if (!plans.hasValue || !templates.hasValue || !sessions.hasValue) return;
  final prefs = ref.read(prefsProvider);
  final key = 'dataLang.$uid';
  if (prefs.getString(key) == lang) return;

  final r = Relocalizer.to(lang), rp = Relocalizer.to(lang, programs: true);
  final planUpdates = <String, Map<String, dynamic>>{
    for (final p in plans.value!)
      if (r.plan(p) case final m when m.isNotEmpty) p.id: m,
  };
  final templateUpdates = <String, Map<String, dynamic>>{
    for (final t in templates.value!)
      if (rp.template(t) case final m when m.isNotEmpty) t.id: m,
  };
  final sessionUpdates = <String, Map<String, dynamic>>{
    for (final s in sessions.value!)
      if (r.text(s.title) case final t when t != s.title) s.id: {'title': t},
  };
  debugPrint('relocalize → $lang: ${planUpdates.length} plans, ${templateUpdates.length} programs, ${sessionUpdates.length} sessions');
  repo.updateMany(plans: planUpdates, templates: templateUpdates, sessions: sessionUpdates);
  prefs.setString(key, lang);
});
