import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/reading.dart';
import 'db/database.dart';
import 'picture_finder.dart' show PictureFinderException, SafeFetcher;

/// The only websites the reading-list check may contact (decision D37): the two free catalogues.
/// Links the learner OPENS go to the catalogue's own page (Open Library) or the DOI resolver, in an
/// in-app browser tab; nothing is fetched from them by the app.
const kReadingHosts = {'openlibrary.org', 'api.crossref.org'};

class ReadingCheck {
  const ReadingCheck({required this.status, this.url, this.foundTitle, this.year});
  final String status; // found | notfound | cannot
  final String? url, foundTitle;
  final int? year;
}

/// Asks a catalogue whether a suggested work exists. Abstract so tests never go online.
abstract class ReadingVerifier {
  Future<ReadingCheck> check(ReadingSuggestion s);
}

class CatalogueVerifier implements ReadingVerifier {
  CatalogueVerifier({SafeFetcher? fetcher}) : _fetch = fetcher ?? SafeFetcher(allowedHosts: kReadingHosts);
  final SafeFetcher _fetch;

  static const _jsonLimit = 400000;

  Future<Object?> _json(Uri uri) async {
    final bytes = await _fetch.get(uri.toString(), maxBytes: _jsonLimit);
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw PictureFinderException('The catalogue sent an answer the app could not read.');
    }
  }

  Future<List<ReadingCandidate>> _openLibrary(ReadingSuggestion s) async => parseOpenLibrary(await _json(Uri.https('openlibrary.org', '/search.json', {
        'title': s.title,
        if (s.author.isNotEmpty) 'author': s.author,
        'limit': '5',
        'fields': 'key,title,author_name,first_publish_year',
      })));

  Future<List<ReadingCandidate>> _crossref(ReadingSuggestion s) async => parseCrossref(await _json(Uri.https('api.crossref.org', '/works', {
        'query.bibliographic': '${s.title} ${s.author}'.trim(),
        'rows': '5',
        'select': 'DOI,title,author,issued,type',
      })));

  @override
  Future<ReadingCheck> check(ReadingSuggestion s) async {
    if (!s.kind.checkable) return const ReadingCheck(status: 'cannot');
    final books = s.kind == ReadingKind.book || s.kind == ReadingKind.textbook;
    ReadingCandidate? hit;
    if (books) hit = bestMatch(s, await _openLibrary(s));
    hit ??= bestMatch(s, await _crossref(s)); // books with a DOI too; articles and reviews only here
    if (hit == null) return const ReadingCheck(status: 'notfound');
    return ReadingCheck(status: 'found', url: hit.url, foundTitle: hit.title, year: hit.year);
  }
}

class ReadingRow {
  const ReadingRow({
    required this.id,
    required this.domainId,
    required this.subject,
    required this.topic,
    required this.suggestion,
    required this.checkStatus,
    required this.catalogueUrl,
    required this.foundTitle,
    required this.foundYear,
    required this.done,
  });
  final int id, domainId;
  final String subject;
  final String? topic;
  final ReadingSuggestion suggestion;
  final String checkStatus; // unchecked | found | notfound | cannot
  final String? catalogueUrl, foundTitle;
  final int? foundYear;
  final bool done;
}

/// The learner's reading list. Touches only `reading_item`: cards and scheduling are unaffected.
class ReadingService {
  ReadingService(this.db);
  final AppDatabase db;

  /// Add suggestions for a subject (and topic). A work already on the list for that subject is
  /// kept once. Returns how many were new.
  Future<int> addAll(List<ReadingSuggestion> items, {required int domainId, int? syllabusItemId, int? now}) async {
    if (items.isEmpty) return 0;
    final have = {
      for (final r in await (db.select(db.readingItems)..where((x) => x.domainId.equals(domainId))).get()) r.titleKey,
    };
    var added = 0;
    for (final s in items) {
      if (!have.add(s.key)) continue;
      await db.into(db.readingItems).insert(ReadingItemsCompanion.insert(
            domainId: domainId,
            syllabusItemId: Value(syllabusItemId),
            kind: s.kind.name,
            title: s.title,
            author: Value(s.author),
            why: Value(s.why),
            titleKey: s.key,
            createdAt: now ?? DateTime.now().toUtc().millisecondsSinceEpoch,
          ));
      added++;
    }
    return added;
  }

  Future<List<ReadingRow>> list() async {
    final rows = await db.customSelect(
      'SELECT r.*, d.name AS subject, s.title AS topic FROM reading_item r '
      'JOIN domain d ON d.id = r.domain_id LEFT JOIN syllabus_item s ON s.id = r.syllabus_item_id '
      'ORDER BY d.name COLLATE NOCASE, r.done, r.id',
    ).get();
    return [
      for (final r in rows)
        ReadingRow(
          id: r.read<int>('id'),
          domainId: r.read<int>('domain_id'),
          subject: r.read<String>('subject'),
          topic: r.readNullable<String>('topic'),
          suggestion: ReadingSuggestion(
            kind: readingKindFrom(r.read<String>('kind')),
            title: r.read<String>('title'),
            author: r.read<String>('author'),
            why: r.read<String>('why'),
          ),
          checkStatus: r.read<String>('check_status'),
          catalogueUrl: r.readNullable<String>('catalogue_url'),
          foundTitle: r.readNullable<String>('found_title'),
          foundYear: r.readNullable<int>('found_year'),
          done: r.read<int>('done') == 1,
        ),
    ];
  }

  Future<int> count() async => (await db.customSelect('SELECT COUNT(*) AS c FROM reading_item').getSingle()).read<int>('c');

  Future<void> recordCheck(int id, ReadingCheck c, {DateTime? now}) =>
      (db.update(db.readingItems)..where((x) => x.id.equals(id))).write(ReadingItemsCompanion(
        checkStatus: Value(c.status),
        catalogueUrl: Value(c.url),
        foundTitle: Value(c.foundTitle),
        foundYear: Value(c.year),
        checkedAt: Value((now ?? DateTime.now()).toUtc().millisecondsSinceEpoch),
      ));

  Future<void> setDone(int id, bool done) =>
      (db.update(db.readingItems)..where((x) => x.id.equals(id))).write(ReadingItemsCompanion(done: Value(done)));

  Future<void> delete(int id) => (db.delete(db.readingItems)..where((x) => x.id.equals(id))).go();
}
