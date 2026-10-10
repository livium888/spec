/// Turning what Anki stores into card text this app can show (D50). Pure Dart, no Flutter.
///
/// Anki fields are small pieces of HTML. The app draws no HTML (card text only becomes text styles and formulas,
/// D42), so the useful parts are carried over as the Markdown subset the app does draw: bold, italic, code,
/// bullets, line breaks and maths, and everything else is dropped. Pictures are not text: their file names
/// are returned so the caller can fetch the first one. UNTRUSTED input: nothing here is ever evaluated.
library;

/// What was in one Anki field.
class AnkiFieldText {
  const AnkiFieldText(this.text, {this.images = const [], this.sounds = 0});
  final String text;

  /// Picture file names named by `<img src>` tags, in order (never a URL that is fetched).
  final List<String> images;

  /// How many `[sound:...]` references were dropped (the app has no audio on cards).
  final int sounds;
}

/// Longest field text read from a file; longer is cut (a card is read in seconds).
const kMaxAnkiFieldChars = 6000;

final _tag = RegExp(r'<[^>]*>', dotAll: true);
final _img = RegExp('<img\\b[^>]*?\\bsrc\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))[^>]*>', caseSensitive: false, dotAll: true);
final _sound = RegExp(r'\[sound:[^\]]*\]');

/// Converts one Anki field. [html] false means the text is plain (a text export without the html flag).
AnkiFieldText ankiFieldToText(String raw, {bool html = true}) {
  var s = raw.length > kMaxAnkiFieldChars * 3 ? raw.substring(0, kMaxAnkiFieldChars * 3) : raw;
  // Control characters are never text, and \u0001-\u0003 are this function's own placeholders.
  s = s.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final images = <String>[];
  var sounds = 0;
  s = s.replaceAllMapped(_sound, (_) {
    sounds++;
    return '';
  });

  // Maths first: protect it from the escaping below. Anki writes \( \) and \[ \] (and the older [$] [/$]).
  final math = <String>[];
  String hold(String tex, bool display) {
    // Formulas that overlap (a stray delimiter inside another formula): the inner one is flattened to its source.
    tex = tex.replaceAllMapped(RegExp('\u0001(\\d+)\u0002'), (m) => math[int.parse(m[1]!)].replaceAll(r'$', ''));
    tex = tex.replaceAll(r'$', r'\$'); // a dollar sign inside a formula is a literal dollar sign
    math.add(display ? '\$\$${tex.trim()}\$\$' : '\$${tex.trim()}\$');
    return '\u0001${math.length - 1}\u0002';
  }

  s = s.replaceAllMapped(RegExp(r'\\\[(.+?)\\\]', dotAll: true), (m) => hold(_mathBody(m[1]!, html), true));
  s = s.replaceAllMapped(RegExp(r'\\\((.+?)\\\)', dotAll: true), (m) => hold(_mathBody(m[1]!, html), false));
  s = s.replaceAllMapped(RegExp(r'\[\$\$\](.+?)\[/\$\$\]', dotAll: true), (m) => hold(_mathBody(m[1]!, html), true));
  s = s.replaceAllMapped(RegExp(r'\[\$\](.+?)\[/\$\]', dotAll: true), (m) => hold(_mathBody(m[1]!, html), false));

  if (html) {
    s = s.replaceAllMapped(_img, (m) {
      final src = m[1] ?? m[2] ?? m[3] ?? '';
      if (src.isNotEmpty) images.add(_decode(src));
      return '';
    });
    s = s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(div|p|h[1-6]|tr|table|ul|ol|blockquote)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<(div|p|h[1-6]|tr|table|ul|ol|blockquote)(\s[^>]*)?>', caseSensitive: false), '\u0003')
        .replaceAll(RegExp(r'<li(\s[^>]*)?>', caseSensitive: false), '\u0003- ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?(b|strong)(\s[^>]*)?>', caseSensitive: false), '**')
        .replaceAll(RegExp(r'</?(i|em)(\s[^>]*)?>', caseSensitive: false), '*')
        .replaceAll(RegExp(r'</?code(\s[^>]*)?>', caseSensitive: false), '`')
        .replaceAll(_tag, '');
    // An opening block tag starts a line only if one has not just been started by the closing tag before it.
    s = s.replaceAll('\n\u0003', '\n').replaceAll('\u0003', '\n');
    s = _decode(s);
  }

  // What is left is plain text: write the symbols the card markup would read as styling as themselves,
  // except the bold/italic/code marks and bullets this function just made from the HTML.
  if (html) {
    s = _escapeLiteral(s);
  } else {
    s = _escapeAll(s);
  }
  s = s.replaceAllMapped(RegExp('\u0001(\\d+)\u0002'), (m) => math[int.parse(m[1]!)]);

  final lines = [for (final l in s.split('\n')) l.trimRight()];
  s = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  if (s.length > kMaxAnkiFieldChars) s = s.substring(0, kMaxAnkiFieldChars);
  return AnkiFieldText(s, images: images, sounds: sounds);
}

/// Inside a formula the HTML is only entities and line breaks.
String _mathBody(String s, bool html) => html ? _decode(s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ').replaceAll(_tag, '')) : s;

/// Plain text: nothing is markup, so every symbol the card markup reads is escaped.
String _escapeAll(String s) => s.replaceAllMapped(RegExp(r'([$*_`])'), (m) => '\\${m[1]}');

/// HTML text: `$` is always literal (maths was lifted out above); `*` and `` ` `` are literal unless they
/// came from our own conversion, which is why `_escapeLiteral` runs on text where those marks were added from tags.
/// A literal `*` typed in an HTML field is rare and cheap to lose (it shows as a mark), a swallowed paragraph is not.
String _escapeLiteral(String s) => s.replaceAll(r'$', r'\$');

String _decode(String s) {
  const named = {
    'nbsp': ' ', 'lt': '<', 'gt': '>', 'amp': '&', 'quot': '"', 'apos': "'", 'ndash': '–', 'mdash': '—',
    'hellip': '…', 'lsquo': '‘', 'rsquo': '’', 'ldquo': '“', 'rdquo': '”', 'times': '×', 'divide': '÷',
    'deg': '°', 'plusmn': '±', 'micro': 'µ', 'copy': '©', 'rarr': '→', 'larr': '←', 'middot': '·',
  };
  return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final e = m[1]!;
    if (e.startsWith('#x')) return _cp(int.tryParse(e.substring(2), radix: 16)) ?? m[0]!;
    if (e.startsWith('#')) return _cp(int.tryParse(e.substring(1))) ?? m[0]!;
    return named[e] ?? m[0]!;
  });
}

String? _cp(int? c) => (c == null || c < 32 && c != 10 || c > 0x10FFFF || (c >= 0xD800 && c <= 0xDFFF)) ? null : String.fromCharCode(c);

// ---- Anki's plain-text and CSV export -------------------------------------------------------------

/// A file of notes, one per row, as Anki's "Notes in Plain Text" export writes it (or any tab/comma/semicolon file).
class AnkiTextFile {
  const AnkiTextFile({required this.rows, required this.html, this.notetypeCol, this.deckCol, this.tagsCol, this.guidCol});
  final List<List<String>> rows;
  final bool html;

  /// 0-based columns named by the file's `#... column:N` header lines, when present.
  final int? notetypeCol, deckCol, tagsCol, guidCol;
}

/// Reads the header lines (`#separator:tab`, `#html:true`, `#tags column:3` ...) and the rows, with quoted
/// fields that may hold the separator, doubled quotes and line breaks. Returns null for text with no row.
AnkiTextFile? parseAnkiTextFile(String raw, {int maxRows = 50000}) {
  var text = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = text.split('\n');
  final header = <String, String>{};
  var at = 0;
  while (at < lines.length && lines[at].startsWith('#')) {
    final i = lines[at].indexOf(':');
    if (i > 1) header[lines[at].substring(1, i).trim().toLowerCase()] = lines[at].substring(i + 1).trim();
    at++;
  }
  final body = lines.sublist(at).join('\n');
  if (body.trim().isEmpty) return null;

  String? sep;
  switch ((header['separator'] ?? '').toLowerCase()) {
    case 'tab':
      sep = '\t';
    case 'comma':
      sep = ',';
    case 'semicolon':
      sep = ';';
    case 'pipe':
      sep = '|';
    case 'space':
      sep = ' ';
    case '':
      break;
    default:
      sep = header['separator']!.length == 1 ? header['separator'] : null;
  }
  sep ??= _guessSeparator(body);

  final rows = _delimited(body, sep, maxRows);
  int? col(String k) {
    final v = int.tryParse(header[k] ?? '');
    return v == null || v < 1 ? null : v - 1;
  }

  return AnkiTextFile(
    rows: rows,
    html: (header['html'] ?? 'false').toLowerCase() == 'true',
    notetypeCol: col('notetype column'),
    deckCol: col('deck column'),
    tagsCol: col('tags column'),
    guidCol: col('guid column'),
  );
}

String _guessSeparator(String body) {
  final first = body.split('\n').take(5).join('\n');
  int n(String c) => c.allMatches(first).length;
  final tab = n('\t'), semi = n(';'), comma = n(',');
  if (tab > 0 && tab >= semi && tab >= comma) return '\t';
  if (semi > comma) return ';';
  return ',';
}

/// RFC 4180 style: a field may be quoted, a quote inside is doubled, and a quoted field may span lines.
List<List<String>> _delimited(String body, String sep, int maxRows) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cur = StringBuffer();
  var quoted = false, any = false;
  void endField() {
    row.add(cur.toString());
    cur.clear();
  }

  void endRow() {
    endField();
    if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
    any = false;
  }

  for (var i = 0; i < body.length && rows.length < maxRows; i++) {
    final c = body[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < body.length && body[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cur.write(c);
      }
    } else if (c == '"' && cur.isEmpty) {
      quoted = true;
      any = true;
    } else if (c == sep) {
      endField();
      any = true;
    } else if (c == '\n') {
      endRow();
    } else {
      cur.write(c);
      any = true;
    }
  }
  if (any || cur.isNotEmpty) endRow();
  return rows;
}
