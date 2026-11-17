import '../data/default_programs.dart';
import '../data/models.dart';
import 'gen/l10n_pairs.dart';

/// Translates texts that were stored in the language active when they were created
/// (generated plans, built-in programs and folders) into the current app language.
///
/// Only texts the app itself produced are recognised: whole lines that equal an ARB message
/// or match a message with placeholders (whose arguments are translated recursively). Text
/// the user typed is left unchanged.
class Relocalizer {
  Relocalizer._(this._exact, this._templates, this._toGerman);

  final Map<String, String> _exact; // source → target
  final List<_Template> _templates;
  final bool _toGerman;

  static final _cache = <String, Relocalizer>{};

  /// Relocalizer that converts into [lang] ('de' or 'en'). Where a word has two
  /// translations (e.g. "Langer Lauf" → plan title "Long run" / program name "Long Run"),
  /// [programs] prefers the built-in program spelling.
  factory Relocalizer.to(String lang, {bool programs = false}) =>
      _cache.putIfAbsent('$lang$programs', () => Relocalizer.fromPairs(_allPairs(programs), toGerman: lang == 'de'));

  factory Relocalizer.fromPairs(List<(String, String)> pairs, {required bool toGerman}) {
    final exact = <String, String>{};
    final templates = <_Template>[];
    final targets = <String>{for (final (en, de) in pairs) toGerman ? de : en};
    for (final (en, de) in pairs) {
      final from = toGerman ? en : de, to = toGerman ? de : en;
      // A text that is also a valid target (identical word in both languages, e.g. "Push")
      // must not be "translated" into something else.
      if (targets.contains(from)) continue;
      if (!from.contains('{')) {
        exact.putIfAbsent(from, () => to);
      } else {
        final t = _Template.parse(from, to);
        if (t != null) templates.add(t);
      }
    }
    // Most specific (longest literal text) first; on a tie the later pair – a newer wording of the same source text
    // (e.g. "… until the next recovery week" after "… deload", both "… Entlastungswoche" in German) – wins.
    // (List.sort is not stable: without the tie-break the pick depended on the list's length.)
    final order = {for (var i = 0; i < templates.length; i++) templates[i]: i};
    templates.sort((a, b) {
      final c = b.literalLength.compareTo(a.literalLength);
      return c != 0 ? c : order[b]!.compareTo(order[a]!);
    });
    return Relocalizer._(exact, templates, toGerman);
  }

  static List<(String, String)> _allPairs(bool programsFirst) {
    final en = defaultTemplates(() => '', de: false), de = defaultTemplates(() => '', de: true);
    return [
      if (!programsFirst) ...l10nPairs,
      for (var i = 0; i < en.length && i < de.length; i++) ...[
        (en[i].name, de[i].name),
        (en[i].folder, de[i].folder),
        for (final (a, b) in _lines(en[i].description, de[i].description)) (a, b),
        for (var j = 0; j < en[i].steps.length && j < de[i].steps.length; j++) (en[i].steps[j].note, de[i].steps[j].note),
      ],
      if (programsFirst) ...l10nPairs,
    ].where((p) => p.$1.isNotEmpty && p.$2.isNotEmpty && p.$1 != p.$2).toList();
  }

  static Iterable<(String, String)> _lines(String a, String b) sync* {
    final x = a.split('\n'), y = b.split('\n');
    if (x.length != y.length) {
      yield (a, b);
      return;
    }
    for (var i = 0; i < x.length; i++) {
      yield (x[i].trim(), y[i].trim());
    }
  }

  /// Translates a (possibly multi-line) text; unknown lines stay as they are.
  String text(String s, {int depth = 0}) {
    if (s.isEmpty) return s;
    if (s.contains('\n')) return s.split('\n').map((l) => text(l, depth: depth)).join('\n');
    final hit = _exact[s.trim()];
    if (hit != null) return hit;
    if (depth > 2) return _number(s);
    for (final t in _templates) {
      final m = t.regex.firstMatch(s);
      if (m == null) continue;
      var out = t.target;
      for (final n in t.names) {
        out = out.replaceAll('{$n}', text(m.namedGroup(n)!, depth: depth + 1));
      }
      return out;
    }
    return depth == 0 ? s : _number(s);
  }

  /// Placeholder values that are plain numbers switch the decimal separator.
  String _number(String s) {
    if (RegExp(r'^\d+[.,]\d+$').hasMatch(s)) {
      return _toGerman ? s.replaceAll('.', ',') : s.replaceAll(',', '.');
    }
    return s;
  }

  /// Changed fields of [p] (Firestore update map), empty if nothing to translate.
  Map<String, dynamic> plan(PlannedWorkout p) => _fields(p.title, p.description, p.steps, nameKey: 'title');

  /// Changed fields of [t] (Firestore update map), empty if nothing to translate.
  Map<String, dynamic> template(WorkoutTemplate t) {
    final out = _fields(t.name, t.description, t.steps, nameKey: 'name');
    final folder = text(t.folder);
    if (folder != t.folder) out['folder'] = folder;
    return out;
  }

  Map<String, dynamic> _fields(String name, String desc, List<WorkoutStep> steps, {required String nameKey}) {
    final out = <String, dynamic>{};
    final n = text(name), d = text(desc);
    if (n != name) out[nameKey] = n;
    if (d != desc) out['description'] = d;
    var stepsChanged = false;
    final maps = [
      for (final s in steps)
        () {
          final m = s.toMap();
          final note = text(s.note);
          if (note != s.note) {
            stepsChanged = true;
            m['n'] = note;
          }
          return m;
        }(),
    ];
    if (stepsChanged) out['steps'] = maps;
    return out;
  }
}

class _Template {
  _Template(this.regex, this.names, this.target, this.literalLength);
  final RegExp regex;
  final List<String> names;
  final String target;
  final int literalLength;

  static _Template? parse(String from, String to) {
    final ph = RegExp(r'\{(\w+)\}');
    final names = <String>[];
    final buf = StringBuffer('^');
    var last = 0, literal = 0;
    for (final m in ph.allMatches(from)) {
      final lit = from.substring(last, m.start);
      buf.write(RegExp.escape(lit));
      literal += lit.replaceAll(RegExp(r'[^A-Za-zÄÖÜäöüß]'), '').length;
      final name = m.group(1)!;
      if (names.contains(name)) {
        buf.write('\\k<$name>'); // same value again (e.g. "{hi}" twice)
      } else {
        names.add(name);
        buf.write('(?<$name>.+?)');
      }
      last = m.end;
    }
    final tail = from.substring(last);
    buf
      ..write(RegExp.escape(tail))
      ..write(r'$');
    literal += tail.replaceAll(RegExp(r'[^A-Za-zÄÖÜäöüß]'), '').length;
    // Too little fixed text would match arbitrary user text.
    if (literal < 4) return null;
    for (final n in names) {
      if (!to.contains('{$n}')) return null;
    }
    return _Template(RegExp(buf.toString()), names, to, literal);
  }
}
