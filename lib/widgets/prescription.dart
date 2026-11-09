import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/gym_tools.dart';
import '../services/load_prescription.dart';

/// Compact load text, e.g. "≈ 60 kg × 8", "≈ 12 kg × 10 per hand" or "Bodyweight × 8".
/// Usable anywhere a prescription should be shown (planned workout detail, plan editor, …).
String prescriptionLabel(AppLocalizations l, Prescription p, Units u) {
  if (p.source == LoadSource.bodyweight) {
    return p.weight > 0 ? l.loadBodyweightPlus(u.weight(p.weight), p.reps) : l.loadBodyweight(p.reps);
  }
  final w = u.weight(p.weight);
  return p.perHand ? l.loadApproxPerHand(w, p.reps) : l.loadApprox(w, p.reps);
}

/// Why the suggestion looks like it does, or null when there is nothing worth saying
/// (e.g. a bodyweight exercise without history).
String? prescriptionReason(AppLocalizations l, Prescription p) {
  final base = switch (p.source) {
    LoadSource.oneRm => l.loadSrcOneRm,
    LoadSource.estimate => l.loadSrcEstimate,
    LoadSource.history || LoadSource.bodyweight when p.breakDays != null && p.breakDays! > 21 => l.loadSrcBreak,
    LoadSource.history || LoadSource.bodyweight when p.fromHistory => switch (p.progression) {
      ProgressionKind.increase => l.loadSrcIncrease,
      ProgressionKind.addReps => l.loadSrcAddReps,
      ProgressionKind.deload => l.loadSrcDeload,
      _ => l.loadSrcHistory,
    },
    _ => null,
  };
  final phase = switch (p.phase) {
    'recovery' => l.loadPhaseLighter,
    'taper' => l.loadTaperLighter,
    _ => null,
  };
  if (base == null) return phase;
  return phase == null ? base : '$base · $phase';
}

/// Small hint "Suggestion: ≈ 62.5 kg × 8 · from your last workout" with an optional
/// apply button (shown when the current sets differ from the suggestion).
class PrescriptionHint extends StatelessWidget {
  const PrescriptionHint({super.key, required this.prescription, required this.units, this.onApply, this.dense = false});
  final Prescription prescription;
  final Units units;
  final VoidCallback? onApply;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = prescription;
    final reason = prescriptionReason(l, p);
    final color = switch (p.source) {
      LoadSource.estimate => AppColors.warning,
      _ when p.progression == ProgressionKind.increase && !p.phaseAdjusted => AppColors.success,
      _ => AppColors.brand,
    };
    final icon = switch (p.source) {
      LoadSource.history || LoadSource.bodyweight when p.fromHistory => Icons.history_rounded,
      LoadSource.estimate => Icons.tune_rounded,
      _ => Icons.auto_awesome_outlined,
    };
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: l.loadSuggestion(prescriptionLabel(l, p, units)), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (reason != null) TextSpan(text: ' · $reason'),
        ],
      ),
      style: TextStyle(fontSize: dense ? 12 : 13, height: 1.3),
    );
    if (dense) {
      return Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(child: text),
          if (onApply != null)
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: onApply,
              child: Text(l.apply),
            ),
        ],
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(14, onApply == null ? 10 : 4, onApply == null ? 14 : 4, onApply == null ? 10 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: text),
          if (onApply != null) TextButton(onPressed: onApply, child: Text(l.apply)),
        ],
      ),
    );
  }
}
