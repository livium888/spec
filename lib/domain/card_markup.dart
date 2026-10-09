/// A small, safe subset of Markdown plus LaTeX maths for card text. Pure Dart, no Flutter.
///
/// Supported: **bold**, *italic* / _italic_, `code`, "- " / "* " bullet lines, "1. " numbered lines,
/// blank line = new paragraph, $inline maths$ and $$display maths$$, and \$ \* \_ \` to write the
/// symbol itself. NOT supported on purpose: HTML, links, images, headings, tables: card text comes
/// from an AI, so nothing in it can load anything or run anything; it is only ever turned into text
/// styles and formulas. Anything that does not parse is shown as the plain text it was.
library;

/// Longest text parsed (longer is cut): a card is read in seconds.
const kMaxMarkupChars = 6000;

/// Longest single formula, and most formulas per text; beyond that the source is shown as text.
const kMaxMathChars = 500;
const kMaxMathPerText = 40;

class MdInline {
  const MdInline(this.text, {this.bold = false, this.italic = false, this.code = false, this.tex});
  final String text; // for a formula: its LaTeX source (also used when it cannot be drawn)
  final bool bold, italic, code;
  final String? tex; // non-null: draw as a formula
  bool get isMath => tex != null;
  bool get isPlain => !bold && !italic && !code && tex == null;
}

enum MdKind { paragraph, bullet, ordered, display }

class MdBlock {
  const MdBlock(this.kind, this.inlines, {this.number = 0, this.tex});
  final MdKind kind;
  final List<MdInline> inlines;
  final int number; // ordered lists
  final String? tex; // display maths
}

/// The text as blocks. Never throws.
List<MdBlock> parseCardMarkup(String source) {
  var src = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (src.length > kMaxMarkupChars) src = src.substring(0, kMaxMarkupChars);
  final budget = _Budget();
  final blocks = <MdBlock>[];

  void lines(String chunk) {
    final para = <String>[];
    void flush() {
      if (para.isEmpty) return;
      blocks.add(MdBlock(MdKind.paragraph, _inline(para.join('\n'), budget)));
      para.clear();
    }

    for (final line in chunk.split('\n')) {
      final bullet = RegExp(r'^\s{0,3}[-*•]\s+(.*)$').firstMatch(line);
      final ordered = RegExp(r'^\s{0,3}(\d{1,3})[.)]\s+(.*)$').firstMatch(line);
      if (line.trim().isEmpty) {
        flush();
      } else if (bullet != null) {
        flush();
        blocks.add(MdBlock(MdKind.bullet, _inline(bullet[1]!, budget)));
      } else if (ordered != null) {
        flush();
        blocks.add(MdBlock(MdKind.ordered, _inline(ordered[2]!, budget), number: int.parse(ordered[1]!)));
      } else {
        para.add(line);
      }
    }
    flush();
  }

  // Display maths first: $$ ... $$ (may span lines).
  final display = RegExp(r'\$\$([\s\S]+?)\$\$');
  var at = 0;
  for (final m in display.allMatches(src)) {
    final tex = m[1]!.trim();
    if (tex.isEmpty || tex.length > kMaxMathChars || !budget.take()) continue; // left in the text
    lines(src.substring(at, m.start));
    blocks.add(MdBlock(MdKind.display, [MdInline(tex, tex: tex)], tex: tex));
    at = m.end;
  }
  lines(src.substring(at));
  return blocks;
}

/// True when the text has nothing to format: one plain paragraph.
bool isPlainMarkup(List<MdBlock> blocks) =>
    blocks.isEmpty || (blocks.length == 1 && blocks.first.kind == MdKind.paragraph && blocks.first.inlines.every((i) => i.isPlain));

class _Budget {
  int left = kMaxMathPerText;
  bool take() => left-- > 0;
}

bool _isSpace(String c) => c == ' ' || c == '\n' || c == '\t';
bool _isWord(String c) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c);
bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

List<MdInline> _inline(String s, _Budget budget, {bool bold = false, bool italic = false}) {
  final out = <MdInline>[];
  final buf = StringBuffer();
  void text() {
    if (buf.isEmpty) return;
    out.add(MdInline(buf.toString(), bold: bold, italic: italic));
    buf.clear();
  }

  var i = 0;
  while (i < s.length) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';
    // Escapes: \$ \* \_ \` write the symbol itself.
    if (c == r'\' && (next == r'$' || next == '*' || next == '_' || next == '`')) {
      buf.write(next);
      i += 2;
      continue;
    }
    // `code`
    if (c == '`') {
      final end = s.indexOf('`', i + 1);
      if (end > i + 1) {
        text();
        out.add(MdInline(s.substring(i + 1, end), bold: bold, italic: italic, code: true));
        i = end + 1;
        continue;
      }
    }
    // $maths$: pandoc rules, so money like "$5 and $10" stays text.
    if (c == r'$' && next.isNotEmpty && !_isSpace(next) && next != r'$') {
      var end = i + 1;
      var found = -1;
      while (end < s.length) {
        final e = s.indexOf(r'$', end);
        if (e < 0) break;
        final escaped = e > 0 && s[e - 1] == r'\';
        final after = e + 1 < s.length ? s[e + 1] : '';
        if (!escaped && !_isSpace(s[e - 1]) && !(after.isNotEmpty && _isDigit(after))) {
          found = e;
          break;
        }
        end = e + 1;
      }
      if (found > i + 1) {
        final tex = s.substring(i + 1, found);
        if (tex.length <= kMaxMathChars && !tex.contains('\n') && budget.take()) {
          text();
          out.add(MdInline(tex, bold: bold, italic: italic, tex: tex));
          i = found + 1;
          continue;
        }
      }
    }
    // **bold**
    if (c == '*' && next == '*') {
      final end = s.indexOf('**', i + 2);
      if (end > i + 2 && !_isSpace(s[i + 2]) && !_isSpace(s[end - 1])) {
        text();
        out.addAll(_inline(s.substring(i + 2, end), budget, bold: true, italic: italic));
        i = end + 2;
        continue;
      }
    }
    // *italic* and _italic_
    if ((c == '*' || c == '_') && next.isNotEmpty && next != c && !_isSpace(next)) {
      final prevWord = i > 0 && _isWord(s[i - 1]);
      if (!(c == '_' && prevWord)) {
        var end = i + 1;
        var found = -1;
        while (end < s.length) {
          final e = s.indexOf(c, end);
          if (e < 0) break;
          final after = e + 1 < s.length ? s[e + 1] : '';
          final okAfter = c == '*' || after.isEmpty || !_isWord(after);
          if (!_isSpace(s[e - 1]) && okAfter && !(c == '*' && after == '*')) {
            found = e;
            break;
          }
          end = e + 1;
        }
        if (found > i + 1) {
          text();
          out.addAll(_inline(s.substring(i + 1, found), budget, bold: bold, italic: true));
          i = found + 1;
          continue;
        }
      }
    }
    buf.write(c);
    i++;
  }
  text();
  return out;
}

/// The text without any formatting, for reading aloud and for lists. Formulas are turned into rough words.
String plainFromMarkup(String source) {
  final blocks = parseCardMarkup(source);
  final parts = <String>[];
  for (final b in blocks) {
    final t = b.inlines.map((i) => i.isMath ? _texToWords(i.tex!) : i.text).join();
    parts.add(switch (b.kind) {
      MdKind.bullet => '• $t',
      MdKind.ordered => '${b.number}. $t',
      _ => t,
    });
  }
  return parts.join('\n').trim();
}

/// A formula as rough words, for reading aloud and for screen readers.
String texToWords(String tex) => _texToWords(tex);

String _texToWords(String tex) {
  var t = tex;
  t = t.replaceAllMapped(RegExp(r'\\[dt]?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}'), (m) => '${m[1]} over ${m[2]}');
  t = t.replaceAllMapped(RegExp(r'\\sqrt\s*\{([^{}]*)\}'), (m) => 'square root of ${m[1]}');
  t = t.replaceAll(RegExp(r'\^\{2\}|\^2(?![0-9])'), ' squared').replaceAll(RegExp(r'\^\{3\}|\^3(?![0-9])'), ' cubed');
  t = t.replaceAllMapped(RegExp(r'\^\{([^{}]*)\}|\^(\w)'), (m) => ' to the power ${m[1] ?? m[2]}');
  t = t.replaceAll(RegExp(r'_\{([^{}]*)\}|_(\w)'), '').replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ').replaceAll(RegExp(r'[{}\\]'), '');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}
