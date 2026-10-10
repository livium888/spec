/// Finding cloze gaps, {{c1::answer}} or {{c1::answer::hint}}, in a card's text. Pure Dart.
///
/// The answer may hold a formula with braces of its own (`{{c1::$\sqrt{\frac{a}{b}}$}}`), so the end of a
/// gap is the first "}}" at brace depth zero, not the first "}}" (a plain regular expression would stop inside
/// the formula).
///
/// "::" splits the answer from the hint. An answer that really contains "::" (`std::vector`) writes it `\::`;
/// the backslash is dropped from the answer and the hint.
library;

class ClozeMatch {
  const ClozeMatch({required this.number, required this.answer, required this.hint, required this.start, required this.end});
  final int number; // 1 for {{c1::...}}
  final String answer;
  final String? hint;
  final int start, end; // the whole {{...}} in the text, end exclusive
}

final _open = RegExp(r'\{\{c(\d+)::');

List<ClozeMatch> findClozes(String text) {
  final out = <ClozeMatch>[];
  var from = 0;
  while (true) {
    final m = _open.matchAsPrefix(text, from) ?? _open.allMatches(text, from).firstOrNull;
    if (m == null) break;
    final bodyStart = m.end;
    var depth = 0;
    var end = -1;
    var hintAt = -1; // the first "::" at depth zero splits answer and hint
    for (var i = bodyStart; i < text.length; i++) {
      final c = text[i];
      if (depth == 0 && c == '}' && i + 1 < text.length && text[i + 1] == '}') {
        end = i;
        break;
      }
      if (c == '{') {
        depth++;
      } else if (c == '}' && depth > 0) {
        depth--;
      } else if (c == ':' && depth == 0 && hintAt < 0 && i + 1 < text.length && text[i + 1] == ':') {
        if (i > bodyStart && text[i - 1] == '\\') {
          i++; // an escaped "::" belongs to the answer
        } else {
          hintAt = i;
        }
      }
    }
    if (end < 0) {
      from = m.end; // an unclosed gap is plain text; carry on after it
      continue;
    }
    String unescape(String s) => s.replaceAll(r'\::', '::');
    final answer = unescape(hintAt < 0 ? text.substring(bodyStart, end) : text.substring(bodyStart, hintAt));
    final hint = hintAt < 0 ? null : unescape(text.substring(hintAt + 2, end));
    out.add(ClozeMatch(number: int.parse(m[1]!), answer: answer, hint: hint, start: m.start, end: end + 2));
    from = end + 2;
  }
  return out;
}

/// The text with every gap replaced by [f]'s result.
String replaceClozes(String text, String Function(ClozeMatch) f) {
  final buf = StringBuffer();
  var at = 0;
  for (final m in findClozes(text)) {
    buf.write(text.substring(at, m.start));
    buf.write(f(m));
    at = m.end;
  }
  buf.write(text.substring(at));
  return buf.toString();
}

Set<int> clozeNumbersOf(String text) => {for (final m in findClozes(text)) m.number};
