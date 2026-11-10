import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/gym_tools.dart';
import '../services/load_prescription.dart';
import 'term_info.dart';
import '../services/smart_progression.dart';

/// Compact load text, e.g. "≈ 60 kg × 8", "≈ 12 kg × 10 per hand" or "Bodyweight × 8".
/// Usable anywhere a prescription should be shown (planned workout detail, plan editor, …).
String prescriptionLabel(AppLocalizations l, Prescription p, Units u) {
  if (p.source == LoadSource.bodyweight || p.bodyweight) {
    if (p.weight < 0) return '${bodyweightLoad(l.bodyweight, p.weight, u)} × ${p.reps}';
    return p.weight > 0 ? l.loadBodyweightPlus(u.weight(p.weight), p.reps) : l.loadBodyweight(p.reps);
  }
  final w = u.weight(p.weight);
  return p.perHand ? l.loadApproxPerHand(w, p.reps) : l.loadApprox(w, p.reps);
}

/// Load part of a target without reps, e.g. "≈ 60 kg", "≈ 12 kg per hand",
/// "Bodyweight", "Bodyweight +5 kg" or "Bodyweight −10 kg" (assisted).
String prescriptionLoad(AppLocalizations l, Prescription p, Units u) {
  if (p.bodyweight || p.source == LoadSource.bodyweight) return bodyweightLoad(l.bodyweight, p.weight, u);
  final w = u.weight(p.weight);
  return p.perHand ? l.loadWeightPerHand(w) : l.loadWeightApprox(w);
}

/// "Bodyweight", "Bodyweight +5 kg", "Bodyweight −10 kg" ([label] = long or short name).
String bodyweightLoad(String label, double added, Units u) {
  if (added.abs() < 1e-6) return label;
  return '$label ${added > 0 ? '+' : '−'}${u.weight(added.abs())}';
}

/// Rep targets per work set ("9 · 9 · 8"), or null when they are all the same.
String? todayReps(Prescription p) {
  if (p.setReps.isEmpty || p.setReps.toSet().length == 1 && p.setReps.first == p.repMin) return null;
  return p.setReps.join(' · ');
}

/// Why the suggestion looks like it does, or null when there is nothing worth saying
/// (e.g. a bodyweight exercise without history).
String? prescriptionReason(AppLocalizations l, Prescription p) {
  final base = switch (p.source) {
    LoadSource.oneRm => l.loadSrcOneRm,
    LoadSource.estimate => l.loadSrcEstimate,
    LoadSource.history || LoadSource.bodyweight when p.breakDays != null && p.breakDays! > 21 => l.loadSrcBreak,
    LoadSource.history || LoadSource.bodyweight when p.fromHistory && p.reason != null => progressReasonText(l, p.reason!),
    LoadSource.history || LoadSource.bodyweight when p.fromHistory => switch (p.progression) {
      ProgressionKind.increase when p.bodyweight => l.loadSrcIncreaseBw,
      ProgressionKind.increase => l.loadSrcIncrease,
      ProgressionKind.addReps when p.repMax != null && p.reps > p.repMax! => l.loadSrcMoreReps,
      ProgressionKind.addReps => l.loadSrcAddReps,
      ProgressionKind.deload => l.loadSrcDeload,
      ProgressionKind.reset => l.loadSrcStall,
      ProgressionKind.hold => l.loadSrcHold,
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

/// Localized explanation of a progression step.
String progressReasonText(AppLocalizations l, ProgressReason r) => switch (r) {
  ProgressReason.topReached => l.progTopReached,
  ProgressReason.topWithReserve => l.progTopWithReserve,
  ProgressReason.topAtLimit => l.progTopAtLimit,
  ProgressReason.microload => l.progMicroload,
  ProgressReason.addReps => l.progAddReps,
  ProgressReason.addRepsFast => l.progAddRepsFast,
  ProgressReason.repsNoLoad => l.progRepsNoLoad,
  ProgressReason.holdLimit => l.progHoldLimit,
  ProgressReason.holdHard => l.progHoldHard,
  ProgressReason.missedHold => l.progMissedHold,
  ProgressReason.missedReduce => l.progMissedReduce,
  ProgressReason.performanceDip => l.progPerformanceDip,
  ProgressReason.performanceDrop => l.progPerformanceDrop,
  ProgressReason.stall => l.loadSrcStall,
  ProgressReason.linear => l.progLinear,
  ProgressReason.nudge => l.progNudge,
  ProgressReason.recalibrated => l.progRecalibrated,
  ProgressReason.e1rmFloor => l.progE1rmFloor,
};

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
    final ranged = p.repMin != null && p.repMax != null;
    final today = todayReps(p);
    final head =
        ranged ? l.targetLoad(prescriptionLoad(l, p, units), p.repMin!, p.repMax!) : l.loadSuggestion(prescriptionLabel(l, p, units));
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: head, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (today != null) TextSpan(text: dense ? ' · ${l.targetToday(today)}' : '\n${l.targetToday(today)}'),
          if (reason != null) TextSpan(text: today != null && !dense ? ' – $reason' : (dense || !ranged ? ' · $reason' : '\n$reason')),
          if (p.amrap) TextSpan(text: '\n${l.amrapHint}', style: const TextStyle(fontStyle: FontStyle.italic)),
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
          if (p.amrap) const TermInfoButton(Term.amrap, size: 15),
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
          if (p.amrap) const TermInfoButton(Term.amrap),
          if (onApply != null) TextButton(onPressed: onApply, child: Text(l.apply)),
        ],
      ),
    );
  }
}
