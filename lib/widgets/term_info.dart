import 'package:flutter/material.dart';

import '../core/format.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/compliance.dart' show ComplianceScale;

String _pct(double share) => Units.pct(share * 100);

/// Terms and abbreviations a beginner may not know. Each has a title (abbreviation +
/// long form), a short explanation and a practical tip.
enum Term {
  rpe,
  rir,
  e1rm,
  vdot,
  ftp,
  css,
  superset,
  amrap,
  volume,
  phases,
  zones,
  keySession,
  loadWeek,
  deloadWeek,
  strides,
  fartlek,
  acwr,
  compliance,
}

extension TermText on Term {
  String title(AppLocalizations l) => switch (this) {
    Term.rpe => l.termRpeTitle,
    Term.rir => l.termRirTitle,
    Term.e1rm => l.termE1rmTitle,
    Term.vdot => l.termVdotTitle,
    Term.ftp => l.termFtpTitle,
    Term.css => l.termCssTitle,
    Term.superset => l.termSupersetTitle,
    Term.amrap => l.termAmrapTitle,
    Term.volume => l.termVolumeTitle,
    Term.phases => l.termPhaseTitle,
    Term.zones => l.termZonesTitle,
    Term.keySession => l.termKeyTitle,
    Term.loadWeek => l.termLoadWeekTitle,
    Term.deloadWeek => l.termDeloadTitle,
    Term.strides => l.termStridesTitle,
    Term.fartlek => l.termFartlekTitle,
    Term.acwr => l.termAcwrTitle,
    Term.compliance => l.termComplianceTitle,
  };

  String body(AppLocalizations l) => switch (this) {
    Term.rpe => l.termRpeBody,
    Term.rir => l.termRirBody,
    Term.e1rm => l.termE1rmBody,
    Term.vdot => l.termVdotBody,
    Term.ftp => l.termFtpBody,
    Term.css => l.termCssBody,
    Term.superset => l.termSupersetBody,
    Term.amrap => l.termAmrapBody,
    Term.volume => l.termVolumeBody,
    Term.phases => l.termPhaseBody,
    Term.zones => l.termZonesBody,
    Term.keySession => l.termKeyBody,
    Term.loadWeek => l.termLoadWeekBody,
    Term.deloadWeek => l.termDeloadBody,
    Term.strides => l.termStridesBody,
    Term.fartlek => l.termFartlekBody,
    Term.acwr => l.termAcwrBody,
    // The bands come from the one scale, so the text can't drift from the markers.
    Term.compliance => l.termComplianceBody(
      _pct(ComplianceScale.greenMin),
      _pct(ComplianceScale.greenMax),
      _pct(ComplianceScale.yellowMin),
      _pct(ComplianceScale.yellowMax),
      _pct(ComplianceScale.countMin),
    ),
  };

  String tip(AppLocalizations l) => switch (this) {
    Term.rpe => l.termRpeTip,
    Term.rir => l.termRirTip,
    Term.e1rm => l.termE1rmTip,
    Term.vdot => l.termVdotTip,
    Term.ftp => l.termFtpTip,
    Term.css => l.termCssTip,
    Term.superset => l.termSupersetTip,
    Term.amrap => l.termAmrapTip,
    Term.volume => l.termVolumeTip,
    Term.phases => l.termPhaseTip,
    Term.zones => l.termZonesTip,
    Term.keySession => l.termKeyTip,
    Term.loadWeek => l.termLoadWeekTip,
    Term.deloadWeek => l.termDeloadTip,
    Term.strides => l.termStridesTip,
    Term.fartlek => l.termFartlekTip,
    Term.acwr => l.termAcwrTip,
    Term.compliance => l.termComplianceTip,
  };

  /// The short label shown in the UI (used for the tooltip "What does … mean?").
  String short(AppLocalizations l) => title(l).split(' – ').first;
}

/// Bottom sheet explaining [term].
Future<void> showTermInfo(BuildContext context, Term term) {
  final l = context.l10n;
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder:
        (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term.title(l), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(term.body(l), style: t.bodyLarge?.copyWith(height: 1.45)),
                const SizedBox(height: 12),
                _TipBox(text: term.tip(l)),
              ],
            ),
          ),
        ),
  );
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

/// Small ⓘ next to an abbreviation; tapping it explains the term. Compact so it fits
/// inline in rows and section headers (24 dp tap target).
class TermInfoButton extends StatelessWidget {
  const TermInfoButton(this.term, {super.key, this.size = 16, this.color});
  final Term term;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      button: true,
      label: l.termWhatIs(term.short(l)),
      child: InkResponse(
        onTap: () => showTermInfo(context, term),
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.info_outline_rounded, size: size, color: color ?? Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

/// All terms on one page (profile → Glossary).
class GlossaryPage extends StatelessWidget {
  const GlossaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.glossary)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l.glossaryHint, style: t.bodySmall),
          const SizedBox(height: 8),
          for (final term in Term.values)
            Card(
              margin: const EdgeInsets.only(top: 8),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: const Border(),
                title: Text(term.title(l), style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(term.body(l), style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 10),
                  _TipBox(text: term.tip(l)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
