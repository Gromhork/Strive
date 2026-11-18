import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/exercise_measure.dart' show formatHold;
import '../l10n/gen/app_localizations.dart';
import '../services/gym_tools.dart';
import '../services/load_prescription.dart';
import '../services/smart_progression.dart';

/// Compact load text, e.g. "≈ 60 kg × 8", "≈ 12 kg × 10 per hand" or "Bodyweight × 8".
/// Usable anywhere a prescription should be shown (planned workout detail, plan editor, …).
String prescriptionLabel(AppLocalizations l, Prescription p, Units u) {
  if (p.timed) return holdLoadLabel(p.weight, p.reps, u, bodyweight: p.bodyweight);
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
  if (p.timed) return p.weight.abs() < 1e-6 ? '' : holdWeight(p.weight, u, bodyweight: p.bodyweight);
  if (p.bodyweight || p.source == LoadSource.bodyweight) return bodyweightLoad(l.bodyweight, p.weight, u);
  final w = u.weight(p.weight);
  return p.perHand ? l.loadWeightPerHand(w) : l.loadWeightApprox(w);
}

/// "Bodyweight", "Bodyweight +5 kg", "Bodyweight −10 kg" ([label] = long or short name).
String bodyweightLoad(String label, double added, Units u) {
  if (added.abs() < 1e-6) return label;
  return '$label ${added > 0 ? '+' : '−'}${u.weight(added.abs())}';
}

/// Weight part of a timed hold: "+10 kg" (added to the body), "−10 kg" (assistance) or
/// "24 kg" (a carry's dumbbells).
String holdWeight(double kg, Units u, {required bool bodyweight}) =>
    bodyweight || kg < 0 ? '${kg > 0 ? '+' : '−'}${u.weight(kg.abs())}' : u.weight(kg);

/// One timed set / target: "45 s", "+10 kg · 45 s", "24 kg · 1:30 min".
String holdLoadLabel(double kg, int sec, Units u, {required bool bodyweight}) {
  final t = formatHold(sec);
  return kg.abs() < 1e-6 ? t : '${holdWeight(kg, u, bodyweight: bodyweight)} · $t';
}

String capitalizeFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
    'race' => l.loadRaceLighter,
    'legsEasy' => l.loadLegsEasyLighter,
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
  ProgressReason.fromPlan => l.progFromPlan,
  ProgressReason.repCap => l.progRepCap,
  ProgressReason.holdLonger => l.progHoldLonger,
  ProgressReason.holdAddLoad => l.progHoldAddLoad,
  ProgressReason.holdTop => l.progHoldTop,
  ProgressReason.holdMissed => l.progHoldMissed,
  ProgressReason.holdShorter => l.progHoldShorter,
};

/// Today's target in one line: "Today: 3 × 6 @ 72.5 kg", or with differing rep targets
/// "Today: 9 · 9 · 8 reps @ 72.5 kg" ([sets] = number of work sets; 0 = unknown).
String prescriptionToday(AppLocalizations l, Prescription p, Units u, {int sets = 0, bool perSide = false}) {
  if (p.timed) {
    final secs = [for (var i = 0; i < (sets > 0 ? sets : max(1, p.setReps.length)); i++) p.repsForSet(i)];
    final load = prescriptionLoad(l, p, u);
    final time =
        (secs.toSet().length == 1 ? '${secs.length} × ${formatHold(secs.first)}' : '${secs.join(' · ')} s') +
        (perSide ? ' ${l.perSide}' : '');
    return l.rxTodayText(load.isEmpty ? time : '$time @ $load');
  }
  final load = prescriptionLoad(l, p, u).replaceFirst('≈ ', '');
  final reps = [for (var i = 0; i < (sets > 0 ? sets : p.setReps.length); i++) p.repsForSet(i)];
  if (reps.isEmpty) return l.rxToday(1, p.reps, load);
  if (reps.toSet().length == 1) return l.rxToday(reps.length, reps.first, load);
  return l.rxTodayList(reps.join(' · '), load);
}

/// Coaching box of an exercise: one line "Today: 3 × 6 @ 72.5 kg" plus a short reason,
/// with an optional apply button (shown when the current sets differ from the suggestion).
/// The AMRAP note is not repeated here – it belongs to the last set only.
class PrescriptionHint extends StatelessWidget {
  const PrescriptionHint({
    super.key,
    required this.prescription,
    required this.units,
    this.onApply,
    this.dense = false,
    this.sets = 0,
    this.perSide = false,
  });
  final Prescription prescription;
  final Units units;
  final VoidCallback? onApply;
  final bool dense;

  /// Number of work sets of the exercise (0 = unknown – the prescription's own targets).
  final int sets;

  /// A hold done once per side ([holdPerSide]): "3 × 20 s per side".
  final bool perSide;

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
    final head = prescriptionToday(l, p, units, sets: sets, perSide: perSide);
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: head, style: TextStyle(fontWeight: FontWeight.w700, fontSize: dense ? 12 : 15)),
          if (reason != null) TextSpan(text: dense ? ' · $reason' : '\n${capitalizeFirst(reason)}'),
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
