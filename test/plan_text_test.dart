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
    expect(planDescription(de.wGymDeloadDesc(2), de), de.wGymDeloadNote);
    expect(planDescription('${de.wGymDeloadDesc(2)}\n${de.wGymTimeCapNote(30)}', de), '${de.wGymDeloadNote}\n${de.wGymTimeCapNote2(30)}');
  });

  test('other text is kept', () {
    expect(planDescription('Eigene Notiz\n${de.wGymConcurrentNote}', de), 'Eigene Notiz\n${de.wGymConcurrentNote}');
    expect(planDescription('', de), '');
  });
}
