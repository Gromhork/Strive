import 'dart:ui';

import '../l10n/gen/app_localizations.dart';

/// Description of a planned workout for display. Plans generated before the per-exercise
/// rep ranges stored a gym note with one global set count ("3 sets per exercise …"),
/// which contradicts programs whose main lift has 4 sets – those lines are shown in
/// today's wording instead (both languages, the text may predate a language switch).
String planDescription(String description, AppLocalizations l) {
  if (description.isEmpty) return description;
  final out = <String>[];
  for (final line in description.split('\n')) {
    final load = _oldLoad.firstMatch(line);
    if (load != null) {
      final rir = int.tryParse(load.group(1) ?? load.group(2) ?? load.group(3) ?? '') ?? 2;
      out
        ..add(l.wGymLoadDesc(rir))
        ..add(l.wGymProgressNote);
    } else if (_oldDeload.hasMatch(line) || line == l.wGymDeloadNote || line == _otherLang(l).wGymDeloadNote) {
      out.add(l.wGymDeloadNote2);
    } else if (_oldCap.firstMatch(line) case final m?) {
      out.add(l.wGymTimeCapNote2(int.parse(m.group(1) ?? m.group(2)!)));
    } else {
      out.add(line);
    }
  }
  return out.join('\n');
}

final _oldLoad = RegExp(
  r'^\d+ (?:Sätze pro Übung im jeweiligen Wiederholungsbereich, (\d+) Wdh\. im Tank|sets per exercise in each exercise.s rep range, leave (\d+) reps)|'
  r'^\d+ (?:Sätze|sets) × \d+–\d+ (?:Wdh\.|reps), (?:stop with )?(\d+)',
);
final _oldDeload = RegExp(r'^Deload: \d+ (?:Sätze pro Übung|sets per exercise)');
final _oldCap = RegExp(r'^(?:Nur (\d+) min Zeit: pro Übung|Only (\d+) min available: do one set less)');

/// The other app language (stored plan texts may predate a language switch).
AppLocalizations _otherLang(AppLocalizations l) => lookupAppLocalizations(Locale(l.localeName.startsWith('de') ? 'en' : 'de'));
