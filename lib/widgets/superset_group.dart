import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/exercise_names_de.dart';
import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/supersets.dart';
import 'term_info.dart';

/// Width of the rail (bracket + "A1" badges) on the left of a superset.
const supersetRailWidth = 34.0;

/// Accent of superset [letter]: one colour per group, the same in every list of the app. The
/// colours avoid the "done" green, the gym coral and the danger red, and are never the only cue –
/// every group also has its frame, its rail and the letter on each member.
Color supersetColor(String? letter) {
  const palette = [
    AppColors.brand, // A violet
    Color(0xFF2AA8E8), // B blue
    Color(0xFFE9A21B), // C amber
    Color(0xFFE66BB3), // D pink
    Color(0xFF22B8A7), // E teal
  ];
  final i = letter == null || letter.isEmpty ? 0 : (letter.codeUnitAt(0) - 65);
  return palette[(i < 0 ? 0 : i) % palette.length];
}

/// Number of different [supersetColor]s (the palette repeats after that).
const supersetColorCount = 5;

/// WCAG contrast ratio of two opaque colours (1–21).
double contrastRatio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

/// Text colour on a badge or chip filled with [c]: black or white, whichever is easier to read
/// (always at least 4.5:1 – the brightness estimate alone put white on the pink of group D at
/// under 3:1).
Color supersetOnColor(Color c) => contrastRatio(c, Colors.white) >= contrastRatio(c, Colors.black) ? Colors.white : Colors.black;

/// Outline of a group's frame: the accent, darkened on light backgrounds where amber and teal
/// would hardly stand out against white.
Color supersetFrameColor(String? letter, {required bool dark}) {
  final c = supersetColor(letter);
  return dark ? c.withValues(alpha: 0.6) : Color.lerp(c, Colors.black, 0.22)!.withValues(alpha: 0.8);
}

/// "Superset" for 2–3 exercises, "Circuit" for longer chains (only in data that was never
/// normalised – the editors keep supersets at [maxSupersetSize]).
String supersetKind(AppLocalizations l, int count) => count > maxSupersetSize ? l.circuit : l.superset;

/// "Superset A · 2 exercises".
String supersetTitle(AppLocalizations l, String letter, int count) => l.supersetGroupTitle(supersetKind(l, count), letter, count);

/// What follows the next set of exercise [i] inside its superset – from the real state of the
/// workout, exactly as the tracker then switches ([nextInSupersetRound]): "Then straight on to:
/// Biceps curl" while a later member still has open sets, else "Last exercise of the round – rest
/// afterwards" (the last member, or the partners are finished already – unequal set counts).
/// Null for an exercise outside a superset, for a finished one, and before a warm-up set that is
/// not its last open set (the tracker stays on the exercise then).
String? supersetNextText(BuildContext context, List<GymExercise> exercises, int i) => _supersetNext(context, exercises, i)?.$1;

/// [supersetNextText] and whether the full rest follows.
(String, bool)? _supersetNext(BuildContext context, List<GymExercise> exercises, int i) {
  if (i < 0 || i >= exercises.length || supersetOf(exercises, i).length < 2) return null;
  final open = exercises[i].sets.where((s) => !s.done).toList();
  if (open.isEmpty || (open.first.warmup && open.length > 1)) return null;
  final l = context.l10n;
  final next = nextInSupersetRound(exercises, i);
  if (next == null) return (l.supersetThenRest, true);
  return (l.supersetThen(exName(context, exercises[next].exId, exercises[next].name)), false);
}

/// The exercises of a workout as every list shows them: straight sets as they are
/// ([itemBuilder]), supersets inside a [SupersetGroup]. [exercises] need not be normalised
/// (see [exerciseBlocks]).
///
/// [bottomInset] = the bottom margin [itemBuilder]'s tiles carry themselves (the "A1" badge is
/// centred on the visible tile); [trailing] adds an action to a group's header.
List<Widget> groupedExerciseWidgets(
  List<GymExercise> exercises,
  Widget Function(int index) itemBuilder, {
  bool hint = true,
  bool info = true,
  double bottomInset = 0,
  double? badgeTop,
  Widget? Function(ExerciseBlock block)? trailing,
}) => [
  for (final b in exerciseBlocks(exercises))
    if (!b.grouped)
      itemBuilder(b.start)
    else
      SupersetGroup(
        key: ValueKey('supersetGroup-${b.letter}'),
        letter: b.letter!,
        hint: hint,
        info: info,
        bottomInset: bottomInset,
        badgeTop: badgeTop,
        trailing: trailing?.call(b),
        children: [for (final i in b.indices) itemBuilder(i)],
      ),
];

/// A superset (or circuit): its exercises in one tinted frame with a header
/// ("Superset A · 2 exercises – alternate, rest after each round") and a coloured rail on the
/// left that connects the members' "A1", "A2" badges – so it is obvious at a glance which
/// exercises belong together and where the superset ends.
class SupersetGroup extends StatelessWidget {
  const SupersetGroup({
    super.key,
    required this.letter,
    required this.children,
    this.hint = true,
    this.info = true,
    this.bottomInset = 0,
    this.badgeTop,
    this.trailing,
  });
  final String letter;
  final List<Widget> children;
  final bool hint, info;
  final double bottomInset;
  final double? badgeTop;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, c) in children.indexed)
        SupersetSegment(
          letter: letter,
          position: i,
          count: children.length,
          hint: hint,
          info: info,
          bottomInset: bottomInset,
          badgeTop: badgeTop,
          trailing: trailing,
          child: c,
        ),
    ],
  );
}

/// One member's slice of a [SupersetGroup]: the first carries the header and the rounded top,
/// the last closes the frame. Stacked directly under each other the slices form one frame –
/// which lets lists that need one widget per exercise (drag & drop in the editor) show the
/// same grouping.
class SupersetSegment extends StatelessWidget {
  const SupersetSegment({
    super.key,
    required this.letter,
    required this.position,
    required this.count,
    required this.child,
    this.hint = true,
    this.info = true,
    this.bottomInset = 0,
    this.badgeTop,
    this.trailing,
  });

  /// Group letter ("A") and this member's 0-based [position] among the [count] members.
  final String letter;
  final int position, count;
  final Widget child;

  /// Header extras (first member only): the one-line explanation, the info button, an action.
  final bool hint, info;
  final Widget? trailing;
  final double bottomInset;

  /// Distance of the "A1" badge from the top of [child] – for tall cards whose title sits at the
  /// top (editor, table view). Null = centred on the member.
  final double? badgeTop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = supersetColor(letter);
    final stroke = supersetFrameColor(letter, dark: dark);
    final first = position == 0, last = position == count - 1;
    return Semantics(
      container: true,
      label: l.supersetMemberOf(supersetKind(l, count), letter, position + 1, count),
      child: Padding(
        // Clear air before and after the group; none between its members.
        padding: EdgeInsets.only(top: first ? 6 : 0, bottom: last ? 16 : 0),
        child: CustomPaint(
          painter: _FramePainter(color: stroke, fill: c.withValues(alpha: dark ? 0.11 : 0.08), first: first, last: last),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (first)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 4, 6),
                  child: Row(
                    children: [
                      SizedBox(width: supersetRailWidth, child: Icon(Icons.link_rounded, size: 18, color: c)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supersetTitle(l, letter, count),
                              key: ValueKey('supersetHeader-$letter'),
                              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (hint) Text(l.supersetGroupHint, style: t.bodySmall),
                          ],
                        ),
                      ),
                      if (info) const TermInfoButton(Term.superset, size: 16),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: supersetRailWidth,
                    child: CustomPaint(
                      painter: _RailPainter(color: c, last: last, bottomInset: bottomInset, badgeTop: badgeTop),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomInset, top: badgeTop ?? 0),
                        child: Align(
                          alignment: badgeTop == null ? Alignment.center : Alignment.topCenter,
                          child: SupersetBadge(letter: letter, number: position + 1),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(left: supersetRailWidth, right: 6), child: child),
                ],
              ),
              // The frame closes a little below the last member.
              if (last) SizedBox(height: bottomInset >= 6 ? 0 : 6 - bottomInset),
            ],
          ),
        ),
      ),
    );
  }
}

/// "A1" – member [number] of superset [letter], in the group's colour. A fixed size (the text is
/// fitted) so the rail keeps its width at large font sizes.
class SupersetBadge extends StatelessWidget {
  const SupersetBadge({super.key, required this.letter, required this.number});
  final String letter;
  final int number;

  static const width = 26.0, height = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = supersetColor(letter);
    final onC = supersetOnColor(c);
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
        child: FittedBox(
          child: Text(
            '$letter$number',
            textScaler: TextScaler.noScaling,
            style: TextStyle(color: onC, fontSize: 12, fontWeight: FontWeight.w800, height: 1.1),
          ),
        ),
      ),
    );
  }
}

/// Pill "Superset A · 1/2" in the group's colour (focus view, up-next card).
class SupersetChip extends StatelessWidget {
  const SupersetChip({super.key, required this.letter, required this.position, required this.count});
  final String letter;
  final int position, count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = supersetColor(letter);
    final onC = supersetOnColor(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_rounded, size: 14, color: onC),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l.supersetPosition(supersetKind(l, count), letter, position + 1, count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: onC, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// "A1 → Then straight on to: Biceps curl" / "Last exercise of the round – rest afterwards":
/// what follows exercise [index] in its superset. Nothing for an exercise outside a superset.
class SupersetNextLine extends StatelessWidget {
  const SupersetNextLine({super.key, required this.exercises, required this.index});
  final List<GymExercise> exercises;
  final int index;

  @override
  Widget build(BuildContext context) {
    final next = _supersetNext(context, exercises, index);
    if (next == null) return const SizedBox.shrink();
    final (text, last) = next;
    final letter = supersetLetterAt(exercises, index);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(last ? Icons.timer_outlined : Icons.subdirectory_arrow_right_rounded, size: 16, color: supersetColor(letter)),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// Tinted frame of one slice: closed at the top of the first and the bottom of the last member,
/// open in between (painted beyond the clip there).
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.color, required this.fill, required this.first, required this.last});
  final Color color, fill;
  final bool first, last;

  @override
  void paint(Canvas canvas, Size size) {
    const r = Radius.circular(18), over = 40.0;
    final rect = RRect.fromLTRBR(0.75, first ? 0.75 : -over, size.width - 0.75, last ? size.height - 0.75 : size.height + over, r);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePainter o) => o.color != color || o.fill != fill || o.first != first || o.last != last;
}

/// The rail: a vertical line from the header (or the member above) through this member's badge;
/// it ends at the badge of the last member.
class _RailPainter extends CustomPainter {
  const _RailPainter({required this.color, required this.last, required this.bottomInset, required this.badgeTop});
  final Color color;
  final bool last;
  final double bottomInset;
  final double? badgeTop;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final badge = badgeTop == null ? (size.height - bottomInset) / 2 : badgeTop! + SupersetBadge.height / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, last ? badge : size.height),
      Paint()
        ..color = color
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RailPainter o) => o.color != color || o.last != last || o.bottomInset != bottomInset || o.badgeTop != badgeTop;
}
