import 'dart:convert';

import 'package:daily_learning/app/device_services.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/picture_finder.dart';
import 'package:daily_learning/data/reading_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/domain/reading.dart';
import 'package:daily_learning/presentation/reading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'find_picture_test.dart' show FakeFetcher;

Map<String, dynamic> item(String title, {String kind = 'book', String author = 'Jane Smith', String why = 'Because.'}) =>
    {'kind': kind, 'title': title, 'author': author, 'why': why};

String cardsJson(List<Map<String, dynamic>> reading, {String topic = 'Cell biology'}) => jsonEncode({
      'domain': 'Biology',
      'syllabus_item': topic,
      'cards': [
        {'type': 'basic', 'front': 'What powers the cell?', 'back': 'Mitochondria', 'source_type': 'model_memory', 'confidence': 'high'}
      ],
      'further_reading': reading,
    });

void main() {
  group('the AI suggestions (untrusted)', () {
    test('a good list parses; kinds are understood; the same work twice is kept once; at most four', () {
      final r = parseFurtherReading([
        item('Molecular Biology of the Cell', kind: 'Textbook', author: 'Alberts, B.'),
        item('Molecular Biology of the Cell: Seventh Edition', kind: 'textbook', author: 'Bruce Alberts'),
        item('The Selfish Gene', kind: 'book', author: 'Richard Dawkins'),
        item('A review of mitochondria', kind: 'review paper', author: 'X Y'),
        item('Lectures on cells', kind: 'lecture series', author: 'Someone'),
        item('Fifth one', author: 'Someone Else'),
      ]);
      expect(r, hasLength(4));
      expect(r.map((e) => e.kind), [ReadingKind.textbook, ReadingKind.book, ReadingKind.review, ReadingKind.course]);
      expect(r.first.title, 'Molecular Biology of the Cell'); // the subtitle variant was a repeat
    });

    test('odd entries are skipped without failing: a web address, a DOI, no title, too long, wrong types', () {
      final r = parseFurtherReading([
        item('See https://example.com/book'),
        item('Fine title', why: 'doi:10.1000/xyz123'),
        item('Another', author: 'www.site.org'),
        {'kind': 'book', 'title': ''},
        {'kind': 'book', 'title': 'x' * (kMaxReadingTitleChars + 1)},
        {'kind': 7, 'title': 9},
        'junk',
        null,
        item('Kept', kind: 'weird', author: ''),
      ]);
      expect(r.map((e) => e.title), ['Kept']);
      expect(r.single.kind, ReadingKind.other);
      for (final bad in [null, 5, 'x', <String, dynamic>{}]) {
        expect(parseFurtherReading(bad), isEmpty);
      }
    });

    test('why is shortened, control characters and spaces are tidied', () {
      final r = parseFurtherReading([item('  The\n  Title ', why: 'w' * 500)]);
      expect(r.single.title, 'The Title');
      expect(r.single.why.length, lessThanOrEqualTo(kMaxReadingWhyChars));
    });
  });

  group('matching a suggestion to a catalogue entry', () {
    test('surnames from the usual ways of writing an author', () {
      expect(surname('Richard Dawkins'), 'dawkins');
      expect(surname('Dawkins, R.'), 'dawkins');
      expect(surname('Bruce Alberts, Alexander Johnson'), 'alberts'); // a list: the first author
      expect(surname('Alberts et al.'), 'alberts');
      expect(surname(''), '');
    });

    test('titles match across subtitles and small words, and do not match different works', () {
      expect(titlesMatch('Guns, Germs, and Steel', 'Guns, Germs, and Steel: The Fates of Human Societies'), isTrue);
      expect(titlesMatch('The Selfish Gene', 'Selfish gene'), isTrue);
      expect(titlesMatch('Molecular Biology of the Cell', 'Molecular Biology of the Cell - 7th ed'), isTrue);
      expect(titlesMatch('Cell Biology', 'Cell Biology by the Numbers'), isFalse); // a different book
      expect(titlesMatch('Evolution', 'The Origin of Species'), isFalse);
      expect(titlesMatch('', 'x'), isFalse);
    });

    test('an author must match when one is named; none named means no author check', () {
      expect(authorMatches('Richard Dawkins', ['Richard Dawkins']), isTrue);
      expect(authorMatches('Dawkins, R.', ['Richard Dawkins', 'Other']), isTrue);
      expect(authorMatches('Richard Dawkins', ['Jane Austen']), isFalse);
      expect(authorMatches('', ['Anyone']), isTrue);
    });

    test('Open Library and Crossref answers are read defensively', () {
      final ol = parseOpenLibrary({
        'docs': [
          {'key': '/works/OL1W', 'title': 'The Selfish Gene', 'author_name': ['Richard Dawkins'], 'first_publish_year': 1976},
          {'key': '/evil/path', 'title': 'x'},
          {'key': '/works/OL2W'},
          'junk',
        ],
      });
      expect(ol, hasLength(1));
      expect(ol.single.url, 'https://openlibrary.org/works/OL1W');
      expect(ol.single.year, 1976);
      final cr = parseCrossref({
        'message': {
          'items': [
            {'DOI': '10.1000/abc.1', 'title': ['A Review'], 'author': [{'given': 'Ann', 'family': 'Lee'}], 'issued': {'date-parts': [[2019, 5]]}},
            {'DOI': 'not-a-doi', 'title': ['Bad']},
            {'DOI': '10.1000/x', 'title': []},
          ],
        },
      });
      expect(cr, hasLength(1));
      expect(cr.single.url, 'https://doi.org/10.1000/abc.1');
      expect(cr.single.authors, ['Ann Lee']);
      expect(cr.single.year, 2019);
      for (final bad in [null, 3, 'x', <String, dynamic>{}, {'docs': 'no'}, {'message': 5}]) {
        expect(parseOpenLibrary(bad), isEmpty);
        expect(parseCrossref(bad), isEmpty);
      }
      expect(bestMatch(const ReadingSuggestion(kind: ReadingKind.book, title: 'Selfish Gene', author: 'Dawkins', why: ''), ol), isNotNull);
      expect(bestMatch(const ReadingSuggestion(kind: ReadingKind.book, title: 'Selfish Gene', author: 'Nobody', why: ''), ol), isNull);
    });
  });

  group('the prompt asks for reading once per answer, with strict rules', () {
    test('v5 carries the rules and the example key', () {
      final p = renderPrompt(domain: 'Biology', syllabusItem: 'Cells', n: 5, recentTitles: const []);
      expect(kPromptTemplateVersion, 'v5');
      for (final must in ['FURTHER READING', 'Only works you are CERTAIN exist', 'NEVER a web address, DOI, ISBN', 'Never blogs, listicles', '"further_reading": [']) {
        expect(p, contains(must), reason: must);
      }
      expect(p.length, lessThan(12000));
    });
  });

  group('ReadingService', () {
    late Env e;
    late ReadingService svc;
    setUp(() {
      e = Env();
      svc = ReadingService(e.db);
    });

    test('suggestions arrive with an import, are linked to the topic, and a repeat is kept once', () async {
      final p = await e.import.preview(cardsJson([item('The Selfish Gene', author: 'Richard Dawkins'), item('Cell Biology', kind: 'textbook')]));
      expect(p.reading, hasLength(2));
      final s = await e.import.commit(p);
      expect(s.reading, 2);
      final rows = await svc.list();
      expect(rows.map((r) => r.suggestion.title), unorderedEquals(['The Selfish Gene', 'Cell Biology']));
      expect(rows.first.subject, 'Biology');
      expect(rows.first.topic, 'Cell biology');
      expect(rows.every((r) => r.checkStatus == 'unchecked'), isTrue);
      // a later answer repeating one work adds only the new one
      final again = await e.import.commit(await e.import.preview(
          cardsJson([item('The Selfish Gene', author: 'Richard Dawkins'), item('Genomes 4', kind: 'textbook')]).replaceAll('What powers the cell?', 'What makes ATP?')));
      expect(again.reading, 1);
      expect(await svc.count(), 3);
    });

    test('an import without further_reading, or with a bad one, imports the cards as before', () async {
      final json = jsonDecode(cardsJson([])) as Map<String, dynamic>..remove('further_reading');
      final s = await e.import.commit(await e.import.preview(jsonEncode(json)));
      expect(s.cards, 1);
      expect(s.reading, 0);
      json['further_reading'] = 'nonsense';
      json['cards'] = [
        {'type': 'basic', 'front': 'Second question here?', 'back': 'B', 'source_type': 'model_memory', 'confidence': 'high'}
      ];
      final s2 = await e.import.commit(await e.import.preview(jsonEncode(json)));
      expect(s2.cards, 1);
      expect(await svc.count(), 0);
    });

    test('a check result, read, and removal are saved', () async {
      await e.import.commit(await e.import.preview(cardsJson([item('The Selfish Gene', author: 'Richard Dawkins')])));
      final id = (await svc.list()).single.id;
      await svc.recordCheck(id, const ReadingCheck(status: 'found', url: 'https://openlibrary.org/works/OL1W', foundTitle: 'The Selfish Gene', year: 1976));
      var r = (await svc.list()).single;
      expect((r.checkStatus, r.catalogueUrl, r.foundYear), ('found', 'https://openlibrary.org/works/OL1W', 1976));
      await svc.setDone(id, true);
      expect((await svc.list()).single.done, isTrue);
      await svc.delete(id);
      expect(await svc.list(), isEmpty);
    });

    test('cards and scheduling are untouched by the reading list', () async {
      await e.import.commit(await e.import.preview(cardsJson([item('X Book')])));
      expect(await e.db.select(e.db.cards).get(), hasLength(1));
      expect(await e.db.select(e.db.notes).get(), hasLength(1));
    });
  });

  group('CatalogueVerifier (never goes online here)', () {
    FakeFetcher fetcher(Map<String, Object> answers) => FakeFetcher(answers, hosts: kReadingHosts);

    final olHit = {
      'docs': [
        {'key': '/works/OL1W', 'title': 'The Selfish Gene', 'author_name': ['Richard Dawkins'], 'first_publish_year': 1976}
      ]
    };
    final crHit = {
      'message': {
        'items': [
          {'DOI': '10.1000/abc.1', 'title': ['Mitochondria and ageing'], 'author': [{'given': 'Ann', 'family': 'Lee'}], 'issued': {'date-parts': [[2019]]}}
        ]
      }
    };

    test('a book is asked of Open Library first, with title, author and a small limit', () async {
      final f = fetcher({'openlibrary.org': olHit});
      final c = await CatalogueVerifier(fetcher: f).check(const ReadingSuggestion(kind: ReadingKind.book, title: 'The Selfish Gene', author: 'Richard Dawkins', why: ''));
      expect((c.status, c.url, c.year), ('found', 'https://openlibrary.org/works/OL1W', 1976));
      final u = f.urls.single;
      expect(u.host, 'openlibrary.org');
      expect(u.queryParameters['title'], 'The Selfish Gene');
      expect(u.queryParameters['author'], 'Richard Dawkins');
      expect(u.queryParameters['limit'], '5');
    });

    test('a book not in Open Library is tried in Crossref; an article goes to Crossref only', () async {
      final f1 = fetcher({'openlibrary.org': {'docs': []}, 'api.crossref.org': crHit});
      final c1 = await CatalogueVerifier(fetcher: f1).check(const ReadingSuggestion(kind: ReadingKind.textbook, title: 'Mitochondria and Ageing', author: 'Ann Lee', why: ''));
      expect(c1.status, 'found');
      expect(f1.urls.map((u) => u.host), ['openlibrary.org', 'api.crossref.org']);
      final f2 = fetcher({'api.crossref.org': crHit});
      final c2 = await CatalogueVerifier(fetcher: f2).check(const ReadingSuggestion(kind: ReadingKind.article, title: 'Mitochondria and ageing', author: 'Lee', why: ''));
      expect((c2.status, c2.url), ('found', 'https://doi.org/10.1000/abc.1'));
      expect(f2.urls.single.host, 'api.crossref.org');
    });

    test('a wrong author or title is "notfound"; a course is "cannot" and asks nothing', () async {
      final f = fetcher({'openlibrary.org': olHit, 'api.crossref.org': {'message': {'items': []}}});
      final v = CatalogueVerifier(fetcher: f);
      expect((await v.check(const ReadingSuggestion(kind: ReadingKind.book, title: 'The Selfish Gene', author: 'Jane Austen', why: ''))).status, 'notfound');
      f.urls.clear();
      expect((await v.check(const ReadingSuggestion(kind: ReadingKind.course, title: 'Lectures', author: '', why: ''))).status, 'cannot');
      expect(f.urls, isEmpty);
    });

    test('the reading hosts and the picture hosts are separate lists', () {
      expect(kReadingHosts, {'openlibrary.org', 'api.crossref.org'});
      expect(() => SafeFetcher().checked('https://openlibrary.org/search.json'), throwsA(isA<PictureFinderException>()));
      expect(SafeFetcher(allowedHosts: kReadingHosts).checked('https://api.crossref.org/works').host, 'api.crossref.org');
      expect(() => SafeFetcher(allowedHosts: kReadingHosts).checked('https://upload.wikimedia.org/a.jpg'), throwsA(isA<PictureFinderException>()));
    });
  });

  group('Reading screen', () {
    Future<(Env, FakeOpener, FakeVerifier)> open(WidgetTester t, {List<Map<String, dynamic>>? reading, bool agreed = false, FakeVerifier? verifier}) async {
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final e = Env();
      await t.runAsync(() async {
        if (reading != null) await e.import.commit(await e.import.preview(cardsJson(reading)));
        if (agreed) await e.settings.set(SettingsRepo.onlineReading, SettingsRepo.onlineReadingAgreed);
      });
      final opener = FakeOpener();
      final v = verifier ?? FakeVerifier();
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          dbProvider.overrideWith(() => FixedDb(e.db)),
          readingVerifierProvider.overrideWithValue(v),
          pageOpenerProvider.overrideWithValue(opener),
        ],
        child: const MaterialApp(home: ReadingScreen()),
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      return (e, opener, v);
    }

    testWidgets('empty: says where suggestions come from', (t) async {
      await open(t);
      expect(find.text('No reading suggestions yet.'), findsOneWidget);
      expect(find.textContaining('They arrive with new cards'), findsOneWidget);
    });

    testWidgets('lists suggestions by subject with an honest warning; nothing is online until the learner agrees', (t) async {
      final (e, _, v) = await open(t, reading: [item('The Selfish Gene', author: 'Richard Dawkins', why: 'Gene-eye view.'), item('Lectures on cells', kind: 'course', author: 'MIT')]);
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('The Selfish Gene'), findsOneWidget);
      expect(find.text('by Richard Dawkins'), findsOneWidget);
      expect(find.textContaining('It cannot tell you whether the book is any good'), findsOneWidget);
      expect(find.text('Cannot be checked automatically'), findsOneWidget);
      expect(find.text('Not checked yet'), findsOneWidget);
      expect(v.checked, isEmpty);
      await t.tap(find.text('Check it exists'));
      await t.pumpAndSettle();
      expect(find.text('Check these online?'), findsOneWidget);
      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();
      expect(v.checked, isEmpty);
      expect(await t.runAsync(() => e.settings.get(SettingsRepo.onlineReading)), isNull);
    });

    testWidgets('after agreeing, a check marks it found, and Look it up opens the catalogue page in the app', (t) async {
      final (e, opener, v) = await open(t, reading: [item('The Selfish Gene', author: 'Richard Dawkins')]);
      await t.tap(find.text('Check it exists'));
      await t.pumpAndSettle();
      await t.tap(find.text('Allow'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(v.checked, ['The Selfish Gene']);
      expect(find.text('Listed in Open Library'), findsOneWidget);
      expect(find.textContaining('Catalogue entry: The Selfish Gene (1976)'), findsOneWidget);
      expect(await t.runAsync(() => e.settings.get(SettingsRepo.onlineReading)), SettingsRepo.onlineReadingAgreed);
      await t.tap(find.text('Look it up'));
      await t.pumpAndSettle();
      expect(opener.opened.single.toString(), 'https://openlibrary.org/works/OL1W');
    });

    testWidgets('a failed check says why and the entry stays unchecked; a not-found one can be checked again', (t) async {
      final v = FakeVerifier(error: PictureFinderException('Could not reach the website. Check your connection and try again.'));
      await open(t, reading: [item('Some Book')], agreed: true, verifier: v);
      await t.tap(find.text('Check it exists'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(find.textContaining('Could not check "Some Book": Could not reach the website.'), findsOneWidget);
      expect(find.text('Not checked yet'), findsOneWidget);
      v.error = null;
      v.status = 'notfound';
      await t.tap(find.text('Check it exists'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(find.textContaining('Not found in the catalogue'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('mark as read and remove (with confirmation)', (t) async {
      final (e, _, _) = await open(t, reading: [item('Some Book')], agreed: true);
      await t.tap(find.text('Mark as read'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(find.text('Not read yet'), findsOneWidget);
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      await t.tap(find.text('Keep it'));
      await t.pumpAndSettle();
      expect(await t.runAsync(() => ReadingService(e.db).count()), 1);
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Remove'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(find.text('No reading suggestions yet.'), findsOneWidget);
    });
  });
}

class FixedDb extends DbNotifier {
  FixedDb(this._db);
  final AppDatabase _db;
  @override
  AppDatabase build() => _db;
}

class FakeOpener implements PageOpener {
  final opened = <Uri>[];
  @override
  Future<String?> open(Uri uri) async {
    opened.add(uri);
    return null;
  }
}

class FakeVerifier implements ReadingVerifier {
  FakeVerifier({this.error});
  PictureFinderException? error;
  String status = 'found';
  final checked = <String>[];
  @override
  Future<ReadingCheck> check(ReadingSuggestion s) async {
    if (error != null) throw error!;
    checked.add(s.title);
    return status == 'found'
        ? ReadingCheck(status: 'found', url: 'https://openlibrary.org/works/OL1W', foundTitle: s.title, year: 1976)
        : ReadingCheck(status: status);
  }
}
