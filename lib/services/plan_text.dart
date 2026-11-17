import 'dart:ui';

import '../l10n/gen/app_localizations.dart';

/// Description of a planned workout for display. Plans generated before the per-exercise
/// rep ranges stored a gym note with one global set count ("3 sets per exercise …"),
/// which contradicts programs whose main lift has 4 sets – those lines are shown in
/// today's wording instead (both languages, the text may predate a language switch).
/// Likewise the English "Deload week: …" notes are shown with today's term "Recovery week", and the
/// older deload notes ("fewer sets") with today's ("same sets, lighter") – deload weeks keep the
/// program's sets now, also in plans generated before.
String planDescription(String description, AppLocalizations l) {
  if (description.isEmpty) return description;
  final out = <String>[];
  for (final line in description.split('\n')) {
    final load = _oldLoad.firstMatch(line);
    if (load != null) {
      final rir = int.tryParse(load.group(1) ?? load.group(2) ?? load.group(3) ?? '') ?? 2;
      out
        ..add(gymLoadNote(l, rir))
        ..add(l.wGymProgressNote);
    } else if (_oldDeload.hasMatch(line) ||
        _isAny(line, l, (x) => [x.wGymDeloadNote, x.wGymDeloadNote2, x.wGymDeloadNote3, x.wGymDeloadNote4])) {
      // Deload weeks no longer drop sets (the plan never changes the program's set counts); bodyweight
      // exercises get fewer reps (review r7 S5).
      out.add(l.wGymDeloadNote5);
    } else if (_oldLoadNote(line, l) case (final rir, final deloadAhead)?) {
      // "… about 1 reps in the tank … until the next deload" (audit T9 / T14): today's wording.
      out.add(gymLoadNote(l, rir, deloadAhead: deloadAhead));
    } else if (_isAny(line, l, (x) => [x.wRecoveryWeekNote])) {
      // Stored as "Deload week: …" in English – shown with today's term "Recovery week".
      out.add(l.wRecoveryWeekNote2);
    } else if (_oldCap.firstMatch(line) case final m?) {
      out.add(l.wGymTimeCapNote2(int.parse(m.group(1) ?? m.group(2)!)));
    } else {
      out.add(line);
    }
  }
  return out.join('\n');
}

/// The loading-week effort note for [rir] reps in reserve: "1 rep" (not "1 reps"), and the lighter week
/// called "recovery week" like everywhere else ([deloadAhead]: one still follows in this block).
String gymLoadNote(AppLocalizations l, int rir, {bool deloadAhead = true}) => switch ((rir, deloadAhead)) {
  (1, true) => l.wGymLoadDescOneRep,
  (_, true) => l.wGymLoadDesc2(rir),
  (1, false) => l.wGymLoadDescNoDeloadOneRep,
  (_, false) => l.wGymLoadDescNoDeload(rir),
};

/// RIR and kind of a stored loading-week note in an older wording ("deload", "1 reps"), in either language.
(int, bool)? _oldLoadNote(String line, AppLocalizations l) {
  for (var rir = 0; rir <= 5; rir++) {
    if (_isAny(line, l, (x) => [x.wGymLoadDesc(rir)]) && gymLoadNote(l, rir) != line) return (rir, true);
    if (rir == 1 && _isAny(line, l, (x) => [x.wGymLoadDescNoDeload(1)]) && gymLoadNote(l, 1, deloadAhead: false) != line) return (1, false);
  }
  return null;
}

final _oldLoad = RegExp(
  r'^\d+ (?:Sätze pro Übung im jeweiligen Wiederholungsbereich, (\d+) Wdh\. im Tank|sets per exercise in each exercise.s rep range, leave (\d+) reps)|'
  r'^\d+ (?:Sätze|sets) × \d+–\d+ (?:Wdh\.|reps), (?:stop with )?(\d+)',
);
final _oldDeload = RegExp(r'^Deload: \d+ (?:Sätze pro Übung|sets per exercise)');
final _oldCap = RegExp(r'^(?:Nur (\d+) min Zeit: pro Übung|Only (\d+) min available: do one set less)');

/// Whether [line] is one of the texts [keys] picks, in the current or the other language.
bool _isAny(String line, AppLocalizations l, List<String> Function(AppLocalizations) keys) =>
    keys(l).contains(line) || keys(_otherLang(l)).contains(line);

/// The other app language (stored plan texts may predate a language switch).
AppLocalizations _otherLang(AppLocalizations l) => lookupAppLocalizations(Locale(l.localeName.startsWith('de') ? 'en' : 'de'));
