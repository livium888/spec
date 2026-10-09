/// Further reading suggested by an AI, and checking it against library catalogues. Pure: no Flutter,
/// no I/O. Everything an AI or a catalogue sends back is untrusted: types are checked, odd entries
/// are dropped, nothing throws. A suggestion is only a suggestion; "found" means a catalogue lists
/// a work with that title and author, not that the work is any good.
library;

import 'import_parser.dart' show normalizeText;

enum ReadingKind { book, textbook, article, review, course, other }

extension ReadingKindLabel on ReadingKind {
  String get label => switch (this) {
        ReadingKind.book => 'Book',
        ReadingKind.textbook => 'Textbook',
        ReadingKind.article => 'Article',
        ReadingKind.review => 'Review paper',
        ReadingKind.course => 'Course or lectures',
        ReadingKind.other => 'Other',
      };

  /// Which catalogue can confirm it exists: books and textbooks in Open Library (then Crossref for
  /// books with a DOI), articles and review papers in Crossref. Courses and the rest cannot be checked.
  bool get checkable => this != ReadingKind.course && this != ReadingKind.other;
}

ReadingKind readingKindFrom(Object? raw) {
  final s = (raw is String ? raw : '').toLowerCase().trim().replaceAll(RegExp(r'[_\-]+'), ' ');
  return switch (s) {
    'book' || 'monograph' => ReadingKind.book,
    'textbook' || 'text book' => ReadingKind.textbook,
    'article' || 'paper' || 'journal article' => ReadingKind.article,
    'review' || 'review paper' || 'review article' || 'survey' => ReadingKind.review,
    'course' || 'lecture' || 'lectures' || 'lecture series' || 'lecture course' => ReadingKind.course,
    _ => ReadingKind.other,
  };
}

const kMaxReadingPerAnswer = 4;
const kMaxReadingTitleChars = 200;
const kMaxReadingAuthorChars = 120;
const kMaxReadingWhyChars = 300;

class ReadingSuggestion {
  const ReadingSuggestion({required this.kind, required this.title, required this.author, required this.why});
  final ReadingKind kind;
  final String title, author, why;
  String get key => readingKey(title, author);
}

bool _looksLikeAddress(String s) => RegExp(r'(https?:|ftp:|www\.|://|\bdoi:|\b10\.\d{4,9}/)', caseSensitive: false).hasMatch(s);

String _clean(String s) => s.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// The AI's `further_reading` list. Optional, so it never makes an import fail: a wrong shape gives
/// an empty list, an odd entry is skipped (no title, a web address, too long), at most
/// [kMaxReadingPerAnswer] are kept, and the same work twice is kept once.
List<ReadingSuggestion> parseFurtherReading(Object? raw) {
  if (raw is! List) return const [];
  final out = <ReadingSuggestion>[];
  final seen = <String>{};
  for (final e in raw) {
    if (out.length >= kMaxReadingPerAnswer) break;
    if (e is! Map) continue;
    final title = e['title'] is String ? _clean(e['title'] as String) : '';
    final author = e['author'] is String ? _clean(e['author'] as String) : '';
    final why = e['why'] is String ? _clean(e['why'] as String) : '';
    if (title.isEmpty || title.length > kMaxReadingTitleChars || author.length > kMaxReadingAuthorChars) continue;
    if (_looksLikeAddress(title) || _looksLikeAddress(author) || _looksLikeAddress(why)) continue;
    final s = ReadingSuggestion(
      kind: readingKindFrom(e['kind']),
      title: title,
      author: author,
      why: why.length > kMaxReadingWhyChars ? '${why.substring(0, kMaxReadingWhyChars - 1).trimRight()}…' : why,
    );
    if (seen.add(s.key)) out.add(s);
  }
  return out;
}

/// "Dawkins, R." -> "dawkins"; "Richard Dawkins" -> "dawkins"; the first author only.
String surname(String author) {
  var a = _clean(author);
  if (a.isEmpty) return '';
  a = a.split(RegExp(r'\s*(?:;|&|\band\b| et al\.?)\s*', caseSensitive: false)).first;
  if (a.contains(',')) {
    final before = a.split(',').first.trim();
    // "Dawkins, R." (surname first) vs "Dawkins, Hawking" (a list): keep the first word group.
    return normalizeText(before.split(' ').last);
  }
  return normalizeText(a.split(' ').last);
}

/// Normalised title + first author's surname: the same work twice is recognised.
String readingKey(String title, String author) => '${normalizeText(_mainTitle(title))}|${surname(author)}';

String _mainTitle(String t) => t.split(RegExp(r'\s*[:—]\s*|\s+-\s+')).first;

const _stop = {'the', 'a', 'an', 'of', 'and', 'on', 'in', 'to', 'for'};
List<String> _tokens(String s) => [for (final w in normalizeText(s).split(' ')) if (w.isNotEmpty && !_stop.contains(w)) w];

/// Do two titles name the same work? Subtitles (after a colon, dash or em dash) and small words are
/// ignored; equal word sets match, and so do word sets that overlap by 80% or more. A shorter title
/// contained in a longer one does NOT match ("Cell Biology" is not "Cell Biology by the Numbers").
bool titlesMatch(String aiTitle, String foundTitle) {
  final a = _tokens(_mainTitle(aiTitle));
  final b = _tokens(_mainTitle(foundTitle));
  if (a.isEmpty || b.isEmpty) return false;
  final sa = a.toSet(), sb = b.toSet();
  if (sa.length == sb.length && sa.containsAll(sb)) return true;
  final inter = sa.intersection(sb).length;
  final union = sa.union(sb).length;
  return union > 0 && inter / union >= 0.8;
}

/// The AI named an author: does any catalogue author have that surname? (No author named: no check.)
bool authorMatches(String aiAuthor, List<String> foundAuthors) {
  final s = surname(aiAuthor);
  if (s.isEmpty) return true;
  if (s.length < 3) return false;
  return foundAuthors.any((a) => normalizeText(a).split(' ').contains(s));
}

class ReadingCandidate {
  const ReadingCandidate({required this.title, required this.authors, required this.url, this.year});
  final String title, url;
  final List<String> authors;
  final int? year;
}

/// Open Library `search.json`: `docs: [{key, title, author_name, first_publish_year}]`.
/// Verify against current docs: https://openlibrary.org/dev/docs/api/search
List<ReadingCandidate> parseOpenLibrary(Object? json) {
  if (json is! Map || json['docs'] is! List) return const [];
  final out = <ReadingCandidate>[];
  for (final d in json['docs'] as List) {
    if (d is! Map) continue;
    final key = d['key'];
    final title = d['title'];
    if (key is! String || !RegExp(r'^/works/OL\d+W$').hasMatch(key) || title is! String) continue;
    final authors = d['author_name'] is List ? [for (final a in d['author_name'] as List) if (a is String) a] : <String>[];
    final y = d['first_publish_year'];
    out.add(ReadingCandidate(title: title, authors: authors, url: 'https://openlibrary.org$key', year: y is int ? y : null));
  }
  return out;
}

/// Crossref `works`: `message.items: [{DOI, title: [..], author: [{given, family}], issued}]`.
/// Verify against current docs: https://api.crossref.org/swagger-ui/index.html
List<ReadingCandidate> parseCrossref(Object? json) {
  if (json is! Map || json['message'] is! Map || (json['message'] as Map)['items'] is! List) return const [];
  final out = <ReadingCandidate>[];
  for (final d in (json['message'] as Map)['items'] as List) {
    if (d is! Map) continue;
    final doi = d['DOI'];
    final titles = d['title'];
    if (doi is! String || !RegExp(r'^10\.\d{4,9}/[^\s]+$').hasMatch(doi)) continue;
    if (titles is! List || titles.isEmpty || titles.first is! String) continue;
    final authors = d['author'] is List
        ? [
            for (final a in d['author'] as List)
              if (a is Map && a['family'] is String) '${a['given'] is String ? '${a['given']} ' : ''}${a['family']}'
          ]
        : <String>[];
    int? year;
    final issued = d['issued'];
    if (issued is Map && issued['date-parts'] is List && (issued['date-parts'] as List).isNotEmpty) {
      final first = (issued['date-parts'] as List).first;
      if (first is List && first.isNotEmpty && first.first is int) year = first.first as int;
    }
    out.add(ReadingCandidate(title: titles.first as String, authors: authors, url: 'https://doi.org/$doi', year: year));
  }
  return out;
}

/// The first catalogue entry that matches both title and author, or null.
ReadingCandidate? bestMatch(ReadingSuggestion s, List<ReadingCandidate> candidates) {
  for (final c in candidates) {
    if (titlesMatch(s.title, c.title) && authorMatches(s.author, c.authors)) return c;
  }
  return null;
}
