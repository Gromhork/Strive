import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_text.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('old gym notes with a global set count are rewritten', () {
    expect(planDescription(de.wGymDescRange(3, 1), de), '${de.wGymLoadDesc(1)}\n${de.wGymProgressNote}');
    expect(planDescription(en.wGymDescRange(4, 3), de), '${de.wGymLoadDesc(3)}\n${de.wGymProgressNote}');
    expect(planDescription(de.wGymDesc(3, 8, 12, 2), de), '${de.wGymLoadDesc(2)}\n${de.wGymProgressNote}');
    expect(planDescription(en.wGymDesc(3, 8, 12, 2), en), '${en.wGymLoadDesc(2)}\n${en.wGymProgressNote}');
    expect(planDescription(de.wGymDeloadDesc(2), de), de.wGymDeloadNote4);
    expect(planDescription('${de.wGymDeloadDesc(2)}\n${de.wGymTimeCapNote(30)}', de), '${de.wGymDeloadNote4}\n${de.wGymTimeCapNote2(30)}');
  });

  test('the previous deload note (one set less) is replaced', () {
    expect(planDescription(de.wGymDeloadNote, de), de.wGymDeloadNote4);
    expect(planDescription(en.wGymDeloadNote, de), de.wGymDeloadNote4);
  });

  test('deload notes that promised fewer sets show the current note (same sets, lighter)', () {
    for (final l in [de, en]) {
      expect(planDescription(l.wGymDeloadNote3, l), l.wGymDeloadNote4);
      expect(planDescription(de.wGymDeloadNote3, l), l.wGymDeloadNote4);
    }
    expect(planDescription(de.wGymDeloadNote4, de), de.wGymDeloadNote4);
    expect(de.wGymDeloadNote4, contains('gleiche Sätze'));
    expect(en.wGymDeloadNote4, contains('same sets'));
  });

  test('stored "Deload week" notes are shown as "Recovery week"', () {
    expect(planDescription(en.wGymDeloadNote2, en), en.wGymDeloadNote4);
    expect(planDescription(en.wRecoveryWeekNote, en), en.wRecoveryWeekNote2);
    expect(planDescription(en.wRecoveryWeekNote, de), de.wRecoveryWeekNote2);
    expect(en.wRecoveryWeekNote2, startsWith('Recovery week'));
    expect(planDescription(de.wRecoveryWeekNote, en), en.wRecoveryWeekNote2);
  });

  test('other text is kept', () {
    expect(planDescription('Eigene Notiz\n${de.wGymConcurrentNote}', de), 'Eigene Notiz\n${de.wGymConcurrentNote}');
    expect(planDescription('', de), '');
  });
}
