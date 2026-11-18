import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/widgets/prescription.dart';

void main() {
  test('bodyweight and target labels', () {
    final de = lookupAppLocalizations(const Locale('de'));
    const u = Units(false);
    expect(bodyweightLoad(de.bodyweightShort, 0, u), 'Körpergew.');
    expect(bodyweightLoad(de.bodyweightShort, 5, u), 'Körpergew. +5 kg');
    expect(bodyweightLoad(de.bodyweightShort, -10, u), 'Körpergew. −10 kg');
    const p = Prescription(weight: 62.5, reps: 8, source: LoadSource.history, repMin: 8, repMax: 12, setReps: [9, 9, 8]);
    expect(prescriptionLoad(de, p, u), '≈ 62.5 kg');
    expect(de.targetLoad(prescriptionLoad(de, p, u), 8, 12), 'Ziel: ≈ 62.5 kg · 8–12 Wdh.');
    expect(todayReps(p), '9 · 9 · 8');
    expect(todayReps(const Prescription(weight: 60, reps: 8, source: LoadSource.history, repMin: 8, setReps: [8, 8, 8])), isNull);
    expect(prescriptionLabel(de, const Prescription(weight: -10, reps: 6, source: LoadSource.bodyweight), u), 'Körpergewicht −10 kg × 6');
  });
}
