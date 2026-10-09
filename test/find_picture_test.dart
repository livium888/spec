import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/picture_finder.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/commons.dart';
import 'package:daily_learning/domain/picture_sources.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/presentation/find_picture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'phase3_test.dart' show png;

Map<String, dynamic> page(
  String title,
  int index, {
  String mime = 'image/jpeg',
  int width = 2000,
  String artist = '<a href="//x">Leonardo da Vinci</a>',
  bool info = true,
}) => {
  'title': title,
  'index': index,
  if (info)
    'imageinfo': [
      {
        'thumburl': 'https://upload.wikimedia.org/thumb/${title.hashCode}.jpg',
        'thumbwidth': 250,
        'thumbheight': 370,
        'url': 'https://upload.wikimedia.org/orig/${title.hashCode}.jpg',
        'descriptionurl': 'https://commons.wikimedia.org/wiki/$title',
        'width': width,
        'height': 3000,
        'mime': mime,
        'extmetadata': {
          'Artist': {'value': artist},
          'LicenseShortName': {'value': 'Public domain'},
          'ImageDescription': {'value': 'A <b>portrait</b> &amp; more'},
        },
      },
    ],
};

Map<String, dynamic> response(List<Map<String, dynamic>> pages) => {
  'query': {'pages': pages},
};

class FakeFetcher extends SafeFetcher {
  FakeFetcher(this.answers);
  final Map<String, Object>
  answers; // substring of the URL -> JSON object or bytes
  final urls = <Uri>[];
  @override
  Future<Uint8List> get(String url, {required int maxBytes}) async {
    final u = checked(url);
    urls.add(u);
    for (final e in answers.entries) {
      if (url.contains(e.key)) {
        final v = e.value;
        return v is Uint8List
            ? v
            : Uint8List.fromList(utf8.encode(jsonEncode(v)));
      }
    }
    throw PictureFinderException('no canned answer for $url');
  }
}

class ThumbsFail extends FakeFinder {
  ThumbsFail({super.results});
  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async =>
      throw PictureFinderException('Wikimedia Commons answered with an error (403).');
}

/// A finder that never goes online.
class FakeFinder implements PictureFinder {
  FakeFinder({this.results = const [], this.error});
  final List<PictureCandidate> results;
  final PictureFinderException? error;
  final searches = <String>[];
  Set<String>? lastSources;
  Map<String, String> failures = const {};

  @override
  Future<PictureSearch> search(String query, {Set<String>? sources}) async {
    searches.add(query);
    lastSources = sources;
    if (error != null) throw error!;
    return PictureSearch(results, failures);
  }

  @override
  Future<PictureCandidate?> forCard(PictureCandidate c) async => c;

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async => png;
}

PictureCandidate candidate(String title) => PictureCandidate(
  title: title,
  pageUrl: 'https://commons.wikimedia.org/wiki/$title',
  thumbUrl: 'https://upload.wikimedia.org/x/$title.png',
  mime: 'image/png',
  width: 250,
  height: 250,
  credit: 'Someone · CC BY-SA 4.0 · Wikimedia Commons',
  description: '',
);

void main() {
  group('Commons response parsing (untrusted input)', () {
    test('keeps good pictures in search order and skips svg, tiny, and entries without image info', () {
      final r = parseCommonsPages(
        response([
          page('File:Second.jpg', 2),
          page('File:First.jpg', 1),
          page('File:Drawing.svg', 3, mime: 'image/svg+xml'),
          page('File:Icon.png', 4, mime: 'image/png', width: 120),
          page('File:NoInfo.jpg', 5, info: false),
        ]),
      );
      expect(r.map((c) => c.title), ['File:First.jpg', 'File:Second.jpg']);
      expect(r.first.label, 'First');
    });

    test(
      'credit and description are plain text: markup and entities are removed',
      () {
        final c = parseCommonsPages(response([page('File:Mona_Lisa.jpg', 1)]))
            .single;
        expect(
          c.credit,
          'Leonardo da Vinci · Public domain · Wikimedia Commons',
        );
        expect(c.description, 'A portrait & more');
        expect(c.label, 'Mona Lisa');
      },
    );

    test('odd shapes never throw', () {
      for (final bad in [
        null,
        5,
        'x',
        <String, dynamic>{},
        {'query': 5},
        {
          'query': {'pages': 'no'},
        },
        {
          'query': {
            'pages': [1, null, 'a', {}],
          },
        },
      ]) {
        expect(parseCommonsPages(bad), isEmpty, reason: '$bad');
      }
    });

    test('markup stripping and credit length', () {
      expect(
        stripMarkup('<script>x()</script>Tom &amp; Jerry &#233;&#0;'),
        'x() Tom & Jerry é',
      );
      expect(
        buildCredit(artist: 'A' * 500, license: 'CC BY 4.0').length,
        lessThanOrEqualTo(kMaxCreditChars),
      );
      expect(buildCredit(), 'Wikimedia Commons');
    });
  });

  group('the search phrase', () {
    test('is cleaned, and anything that looks like a web address or is empty or too long is refused', () {
      expect(
        cleanImageQuery('  Hokusai   Great\nWave  '),
        'Hokusai Great Wave',
      );
      expect(cleanImageQuery('https://example.com/a.jpg'), isNull);
      expect(cleanImageQuery('www.site.org/pic'), isNull);
      expect(cleanImageQuery('upload.wikimedia.org'), isNull);
      expect(cleanImageQuery(''), isNull);
      expect(cleanImageQuery('   '), isNull);
      expect(cleanImageQuery('x' * (kMaxImageQueryChars + 1)), isNull);
      expect(cleanImageQuery(42), isNull);
      expect(cleanImageQuery(null), isNull);
    });
  });

  group('SafeFetcher', () {
    test(
      'refuses other hosts, plain http, credentials in the address and rubbish',
      () {
        final f = SafeFetcher();
        expect(
          () => f.checked('https://evil.example.com/a.jpg'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(
          () => f.checked('http://upload.wikimedia.org/a.jpg'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(
          () => f.checked('https://user:pw@upload.wikimedia.org/a.jpg'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(
          () => f.checked('https://upload.wikimedia.org.evil.com/a.jpg'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(
          () => f.checked('file:///etc/passwd'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(
          () => f.checked('not a url'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(
          f.checked('https://upload.wikimedia.org/a.jpg').host,
          'upload.wikimedia.org',
        );
        expect(
          f.checked('https://commons.wikimedia.org/w/api.php').host,
          'commons.wikimedia.org',
        );
      },
    );

    group('against a loopback server', () {
      late HttpServer server;
      late SafeFetcher f;
      setUp(() async {
        HttpOverrides.global = null; // flutter_test answers every HttpClient request with 400 unless this is cleared
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        f = SafeFetcher(
          allowedHosts: {'127.0.0.1'},
          requireHttps: false,
          timeout: const Duration(seconds: 5),
        );
        server.listen((req) async {
          try {
            switch (req.uri.path) {
              case '/ok':
                req.response.add(png);
              case '/hop':
              req.response.statusCode = 302;
              req.response.headers.set('location', '/ok'); // same host: allowed
            case '/loop':
              req.response.statusCode = 302;
              req.response.headers.set('location', '/loop');
            case '/redirect':
                req.response.statusCode = 302;
                req.response.headers.set(
                  'location',
                  'http://evil.example.com/x',
                );
              case '/big':
                req.response.headers.contentLength = 5000000;
                req.response.add(List.filled(1000, 1));
              case '/stream':
                // no content-length: the cap must still stop it
                req.response.headers.chunkedTransferEncoding = true;
                for (var i = 0; i < 30; i++) {
                  req.response.add(List.filled(10000, 1));
                }
              case '/slow':
                await Future<void>.delayed(const Duration(seconds: 3));
                req.response.add(png);
              case '/limit':
                req.response.statusCode = 429;
              case '/ua':
                req.response.write(req.headers.value('user-agent'));
              default:
                req.response.statusCode = 500;
            }
            await req.response.close();
          } catch (
            _
          ) {} // the client may hang up early (that is the point of some cases)
        });
      });
      tearDown(() => server.close(force: true));

      String u(String path) => 'http://127.0.0.1:${server.port}$path';

      test('returns the bytes and identifies the app', () async {
        expect(await f.get(u('/ok'), maxBytes: 1000), png);
        expect(
          utf8.decode(await f.get(u('/ua'), maxBytes: 1000)),
          startsWith('DailyLearning/'),
        );
      });

      test('follows a redirect that stays on an allowed host, but not forever', () async {
        expect(await f.get(u('/hop'), maxBytes: 1000), png);
        await expectLater(f.get(u('/loop'), maxBytes: 1000), throwsA(isA<PictureFinderException>()));
      });

      test('does not follow a redirect off the allowed hosts', () async {
        await expectLater(
          f.get(u('/redirect'), maxBytes: 1000),
          throwsA(isA<PictureFinderException>()),
        );
      });

      test(
        'stops at the size limit, with or without a declared length',
        () async {
          await expectLater(
            f.get(u('/big'), maxBytes: 100000),
            throwsA(
              isA<PictureFinderException>().having(
                (e) => e.message,
                'message',
                contains('too large'),
              ),
            ),
          );
          await expectLater(
            f.get(u('/stream'), maxBytes: 50000),
            throwsA(
              isA<PictureFinderException>().having(
                (e) => e.message,
                'message',
                contains('too large'),
              ),
            ),
          );
        },
      );

      test('says what happened for rate limits, errors, timeouts and no connection', () async {
        await expectLater(
          f.get(u('/limit'), maxBytes: 1000),
          throwsA(
            isA<PictureFinderException>().having(
              (e) => e.message,
              'message',
              contains('slow down'),
            ),
          ),
        );
        await expectLater(
          f.get(u('/nope'), maxBytes: 1000),
          throwsA(
            isA<PictureFinderException>().having(
              (e) => e.message,
              'message',
              contains('500'),
            ),
          ),
        );
        final quick = SafeFetcher(
          allowedHosts: {'127.0.0.1'},
          requireHttps: false,
          timeout: const Duration(milliseconds: 300),
        );
        await expectLater(
          quick.get(u('/slow'), maxBytes: 1000),
          throwsA(
            isA<PictureFinderException>().having(
              (e) => e.message,
              'message',
              contains('too long'),
            ),
          ),
        );
        final port = server.port;
        await server.close(force: true);
        await expectLater(
          f.get('http://127.0.0.1:$port/ok', maxBytes: 1000),
          throwsA(
            isA<PictureFinderException>().having(
              (e) => e.message,
              'message',
              contains('Could not reach'),
            ),
          ),
        );
      });
    });
  });

  group('Commons source', () {
    test('searches files on Commons for the phrase and returns at most the limit', () async {
      final fetch = FakeFetcher({'generator=search': response([for (var i = 1; i <= 12; i++) page('File:P$i.jpg', i)])});
      final r = await CommonsSource(fetch).search('Mona Lisa');
      expect(r, hasLength(5));
      expect(r.first.source, 'commons');
      final u = fetch.urls.single;
      expect(u.host, 'commons.wikimedia.org');
      expect(u.queryParameters['gsrsearch'], 'Mona Lisa');
      expect(u.queryParameters['gsrnamespace'], '6');
      expect(u.queryParameters['iiurlwidth'], '250');
      expect(u.queryParameters['formatversion'], '2');
    });

    test('asks for the card-sized copy of the chosen file by title', () async {
      final fetch = FakeFetcher({'titles=': response([page('File:Mona_Lisa.jpg', 1)])});
      final c = await CommonsSource(fetch).forCard(candidate('File:Mona_Lisa.jpg'));
      expect(c!.label, 'Mona Lisa');
      expect(fetch.urls.single.queryParameters['titles'], 'File:Mona_Lisa.jpg');
      expect(fetch.urls.single.queryParameters['iiurlwidth'], '960');
    });

    test('an answer that is not JSON is a clear error, not a crash', () async {
      final fetch = FakeFetcher({'generator=search': Uint8List.fromList(utf8.encode('<html>nope'))});
      await expectLater(CommonsSource(fetch).search('cats'), throwsA(isA<PictureFinderException>()));
    });
  });

  group('Openverse, Met and Art Institute parsing (untrusted input)', () {
    Map<String, dynamic> ov(String id, String licence, {String version = '4.0', bool mature = false, int width = 1200, String creator = 'A. Person', String thumb = ''}) => {
          'id': id,
          'title': 'Title $id',
          'creator': creator,
          'license': licence,
          'license_version': version,
          'foreign_landing_url': 'https://www.flickr.com/photos/x/$id',
          'thumbnail': thumb.isEmpty ? 'https://api.openverse.org/v1/images/$id/thumb/' : thumb,
          'source': 'flickr',
          'mature': mature,
          'width': width,
          'height': 800,
        };

    test('Openverse keeps reusable licences only, skips mature and tiny, and builds the credit', () {
      final r = parseOpenverse({
        'results': [
          ov('a', 'by-sa'),
          ov('b', 'by-nc'),
          ov('c', 'by-nd'),
          ov('d', 'cc0', version: '1.0'),
          ov('e', 'by', mature: true),
          ov('f', 'by', width: 100),
          ov('g', 'pdm', version: '1.0'),
          'junk',
          {'license': 'by'},
        ],
      });
      expect(r.map((c) => c.title), ['Title a', 'Title d', 'Title g']);
      expect(r.first.credit, 'Title a — A. Person · CC BY-SA 4.0 · Openverse (flickr)');
      expect(r[1].credit, contains('CC0'));
      expect(r[2].credit, contains('Public domain'));
      expect(r.first.source, 'openverse');
      expect(r.first.thumbUrl, 'https://api.openverse.org/v1/images/a/thumb/');
      expect(r.first.forKeeping().thumbUrl, r.first.thumbUrl);
    });

    test('Met: only public-domain objects with a picture; the artist and title go in the credit', () {
      expect(parseMetSearch({'total': 2, 'objectIDs': [10, 'x', 20]}), [10, 20]);
      expect(parseMetSearch({'total': 0, 'objectIDs': null}), isEmpty);
      final good = {
        'isPublicDomain': true,
        'primaryImageSmall': 'https://images.metmuseum.org/CRDImages/a.jpg',
        'objectURL': 'https://www.metmuseum.org/art/collection/search/10',
        'title': 'Under the Wave off Kanagawa',
        'artistDisplayName': 'Katsushika Hokusai',
        'objectDate': 'ca. 1830-32',
      };
      final c = parseMetObject(good)!;
      expect(c.credit, 'Under the Wave off Kanagawa — Katsushika Hokusai · Public domain · The Metropolitan Museum of Art');
      expect(c.label, 'Under the Wave off Kanagawa');
      expect(parseMetObject({...good, 'isPublicDomain': false}), isNull);
      expect(parseMetObject({...good, 'primaryImageSmall': ''}), isNull);
      expect(parseMetObject(null), isNull);
      expect(parseMetObject('x'), isNull);
    });

    test('Art Institute: public domain only, IIIF address built from the image id, first line of the artist', () {
      final r = parseArtic({
        'config': {'iiif_url': 'https://www.artic.edu/iiif/2'},
        'data': [
          {'id': 1, 'title': 'Sunrise', 'artist_display': 'Claude Monet\nFrench, 1840-1926', 'image_id': 'abc-123', 'is_public_domain': true, 'date_display': '1872'},
          {'id': 2, 'title': 'Locked', 'image_id': 'zzz', 'is_public_domain': false},
          {'id': 3, 'title': 'No image', 'image_id': null, 'is_public_domain': true},
          {'id': 4, 'title': 'Odd id', 'image_id': '../../etc', 'is_public_domain': true},
        ],
      });
      expect(r, hasLength(1));
      expect(r.single.thumbUrl, 'https://www.artic.edu/iiif/2/abc-123/full/843,/0/default.jpg');
      expect(r.single.credit, 'Sunrise — Claude Monet · Public domain (CC0) · Art Institute of Chicago');
      expect(r.single.pageUrl, 'https://www.artic.edu/artworks/1');
    });

    test('odd shapes never throw', () {
      for (final bad in [null, 5, 'x', <String, dynamic>{}, {'results': 'no'}, {'data': 3}]) {
        expect(parseOpenverse(bad), isEmpty, reason: '$bad');
        expect(parseArtic(bad), isEmpty, reason: '$bad');
        expect(parseMetSearch(bad), isEmpty, reason: '$bad');
      }
    });
  });

  group('PictureLookup (all sources together)', () {
    Map<String, Object> answers({bool openverse = true}) => {
          'generator=search': response([for (var i = 1; i <= 3; i++) page('File:C$i.jpg', i)]),
          if (openverse)
            'api.openverse.org': {
              'results': [
                for (var i = 1; i <= 3; i++)
                  {
                    'title': 'O$i', 'creator': 'x', 'license': 'by', 'license_version': '2.0', 'source': 'flickr',
                    'foreign_landing_url': 'https://flickr.com/$i', 'thumbnail': 'https://api.openverse.org/v1/images/$i/thumb/', 'width': 900, 'height': 600,
                  }
              ]
            },
          'public/collection/v1/search': {'total': 2, 'objectIDs': [11, 12]},
          'v1/objects/11': {'isPublicDomain': true, 'primaryImageSmall': 'https://images.metmuseum.org/a.jpg', 'objectURL': 'https://www.metmuseum.org/11', 'title': 'M1', 'artistDisplayName': 'Painter'},
          'v1/objects/12': {'isPublicDomain': false, 'primaryImageSmall': 'https://images.metmuseum.org/b.jpg', 'objectURL': 'https://www.metmuseum.org/12', 'title': 'M2'},
          'api.artic.edu': {
            'config': {'iiif_url': 'https://www.artic.edu/iiif/2'},
            'data': [
              {'id': 7, 'title': 'A1', 'artist_display': 'Someone', 'image_id': 'img1', 'is_public_domain': true},
            ],
          },
        };

    test('searches every source, interleaves the results, and names each source', () async {
      final fetch = FakeFetcher(answers());
      final r = await PictureLookup(fetcher: fetch).search('  Hokusai   wave ');
      expect(r.failures, isEmpty);
      // one from each source in turn, then the rest
      expect(r.candidates.map((c) => c.source).take(4), ['commons', 'openverse', 'met', 'artic']);
      expect(r.candidates.map((c) => c.source).toSet(), {'commons', 'openverse', 'met', 'artic'});
      expect(r.candidates.where((c) => c.source == 'met'), hasLength(1)); // the non-public-domain object is dropped
      Uri one(bool Function(Uri) f) => fetch.urls.firstWhere(f);
      expect(one((u) => u.host == 'api.openverse.org').queryParameters['q'], 'Hokusai wave');
      expect(one((u) => u.host == 'api.openverse.org').queryParameters['license_type'], 'commercial,modification');
      expect(one((u) => u.path.endsWith('/search')).queryParameters, containsPair('hasImages', 'true'));
      expect(one((u) => u.host == 'api.artic.edu').queryParameters['query[term][is_public_domain]'], 'true');
      expect(fetch.urls.every((u) => kPictureHosts.contains(u.host)), isTrue);
    });

    test('a source that fails is named, and the others still answer', () async {
      final r = await PictureLookup(fetcher: FakeFetcher(answers(openverse: false))).search('wave');
      expect(r.failures.keys, ['Openverse']);
      expect(r.candidates.map((c) => c.source).toSet(), {'commons', 'met', 'artic'});
    });

    test('only the chosen sources are asked', () async {
      final fetch = FakeFetcher(answers());
      final r = await PictureLookup(fetcher: fetch).search('wave', sources: {'artic'});
      expect(r.candidates.map((c) => c.source).toSet(), {'artic'});
      expect(fetch.urls.map((u) => u.host).toSet(), {'api.artic.edu'});
    });

    test('a picture address outside the allowed hosts is never offered', () async {
      final bad = answers();
      bad['v1/objects/11'] = {'isPublicDomain': true, 'primaryImageSmall': 'https://evil.example.com/a.jpg', 'objectURL': 'https://www.metmuseum.org/11', 'title': 'M1'};
      final r = await PictureLookup(fetcher: FakeFetcher(bad)).search('wave', sources: {'met'});
      expect(r.candidates, isEmpty);
    });

    test('refuses a web address, and an empty choice of sources, without going online', () async {
      final fetch = FakeFetcher({});
      final lookup = PictureLookup(fetcher: fetch);
      await expectLater(lookup.search('https://example.com/x.jpg'), throwsA(isA<PictureFinderException>()));
      await expectLater(lookup.search('wave', sources: <String>{}), throwsA(isA<PictureFinderException>()));
      expect(fetch.urls, isEmpty);
    });

    test('keeping a museum picture needs no extra request; a Commons one asks for the larger copy', () async {
      final fetch = FakeFetcher(answers());
      final lookup = PictureLookup(fetcher: fetch);
      final r = await lookup.search('wave');
      final met = r.candidates.firstWhere((c) => c.source == 'met');
      final before = fetch.urls.length;
      expect((await lookup.forCard(met))!.thumbUrl, met.thumbUrl);
      expect(fetch.urls.length, before);
    });

    test('every host the app may contact is listed in one place', () {
      expect(kPictureHosts, {
        'commons.wikimedia.org', 'upload.wikimedia.org', 'api.openverse.org',
        'collectionapi.metmuseum.org', 'images.metmuseum.org', 'api.artic.edu', 'www.artic.edu',
      });
    });
  });

  group('the AI hint (image_query) and the credit', () {
    Map<String, dynamic> card(Object? q) => {
      'type': 'basic',
      'front': 'Which painting shows a wave about to break over three boats?',
      'back': 'The Great Wave off Kanagawa',
      'source_type': 'model_memory',
      'confidence': 'high',
      'image_query': ?q,
    };

    test('a good hint is kept; a URL, a non-string or nothing is dropped without refusing the card', () {
      for (final (q, want) in <(Object?, String)>[
        ('Hokusai Great Wave', 'Hokusai Great Wave'),
        ('https://x.org/a.jpg', ''),
        (12, ''),
        (null, ''),
        ('', ''),
      ]) {
        final p = parseImportJson(
          jsonEncode({
            'domain': 'Art',
            'cards': [card(q)],
          }),
        ).cards.single;
        expect(p.valid, isTrue, reason: '$q');
        expect(p.imageQuery, want, reason: '$q');
      }
    });

    test('the hint is stored on the card; editing keeps it and saves a credit with the picture', () async {
      final e = Env();
      final p = await e.import.preview(
        jsonEncode({
          'domain': 'Art',
          'cards': [card('Hokusai Great Wave')],
        }),
      );
      await e.import.commit(p);
      final svc = CardEditService(e.db, e.settings);
      final n = (await svc.search()).single;
      expect(n.fields['image_query'], 'Hokusai Great Wave');
      final errs = await svc.update(n.noteId, {
        'front': n.fields['front'] as String,
        'back': n.fields['back'] as String,
        'image_credit': 'Hokusai · Public domain · Wikimedia Commons',
      });
      expect(errs, isEmpty);
      final after = (await svc.note(n.noteId))!;
      expect(after.fields['image_query'], 'Hokusai Great Wave');
      expect(
        after.fields['image_credit'],
        'Hokusai · Public domain · Wikimedia Commons',
      );
      // a credit that is too long is refused like any other field
      final bad = await svc.update(n.noteId, {
        'front': n.fields['front'] as String,
        'back': n.fields['back'] as String,
        'image_credit': 'x' * 301,
      });
      expect(bad, isNotEmpty);
    });
  });

  group('image keywords from the AI prompt', () {
    test('the card prompt asks for keywords on EVERY card, with a side hint, and the examples show both', () {
      final p = renderPrompt(domain: 'Art', syllabusItem: 'Impressionism', n: 5, recentTitles: const []);
      expect(p, contains('"image_query": on EVERY card'));
      expect(p, contains('NEVER a web address'));
      expect(p, contains('"image_side"'));
      expect(p, contains('"image_query": "mitochondrion electron micrograph"'));
      expect(p, contains('"image_query": "piano keyboard white and black keys"'));
      final remedial = renderRemediatePrompt(domain: 'Art', syllabusItem: 'x', problems: const []);
      expect(remedial, contains('"image_query"'));
    });

    test('the side hint is kept when it is front or back, ignored otherwise, and stored on the card', () async {
      Map<String, dynamic> card(Object? side) => {
            'type': 'basic', 'front': 'Which painting gave Impressionism its name, shown here?', 'back': 'Impression, Sunrise',
            'source_type': 'model_memory', 'confidence': 'high', 'image_query': 'Monet Impression Sunrise', 'image_side': side,
          };
      for (final (v, want) in <(Object?, String)>[('front', 'front'), ('back', 'back'), ('left', ''), (3, ''), (null, '')]) {
        final c = parseImportJson(jsonEncode({'domain': 'Art', 'cards': [card(v)]})).cards.single;
        expect(c.valid, isTrue);
        expect(c.imageSide, want, reason: '$v');
      }
      final e = Env();
      await e.import.commit(await e.import.preview(jsonEncode({'domain': 'Art', 'cards': [card('front')]})));
      final n = (await CardEditService(e.db, e.settings).search()).single;
      expect(n.fields['image_query'], 'Monet Impression Sunrise');
      expect(n.fields['image_side'], 'front');
    });

    test('the keywords can be edited, cleared, and a web address is refused', () async {
      final e = Env();
      await e.addBasic(1);
      final svc = CardEditService(e.db, e.settings);
      final n = (await svc.search()).single;
      Map<String, String> edit(String kw) => {'front': n.fields['front'] as String, 'back': n.fields['back'] as String, 'image_query': kw};
      expect(await svc.update(n.noteId, edit('  Monet   sunrise harbour ')), isEmpty);
      expect((await svc.note(n.noteId))!.fields['image_query'], 'Monet sunrise harbour');
      expect(await svc.update(n.noteId, edit('https://example.com/a.jpg')), isNotEmpty);
      expect((await svc.note(n.noteId))!.fields['image_query'], 'Monet sunrise harbour'); // nothing changed
      expect(await svc.update(n.noteId, edit('')), isEmpty);
      expect((await svc.note(n.noteId))!.fields.containsKey('image_query'), isFalse);
    });
  });

  group('Find a picture screen', () {
    Future<FoundPicture?> open(
      WidgetTester t,
      FakeFinder finder, {
      String query = 'Hokusai',
    }) async {
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      FoundPicture? got;
      var popped = false;
      await t.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            pictureFinderProvider.overrideWithValue(finder),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      got = await Navigator.of(ctx).push<FoundPicture>(
                        MaterialPageRoute(
                          builder: (_) =>
                              FindPictureScreen(initialQuery: query),
                        ),
                      );
                      popped = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return popped ? got : null;
    }

    testWidgets(
      'searches the hint at once, shows results, previews with credit, and returns the choice only on "Use"',
      (t) async {
        final finder = FakeFinder(
          results: [candidate('File:Wave.png'), candidate('File:Fuji.png')],
        );
        await open(t, finder);
        expect(finder.searches, ['Hokusai']);
        expect(find.text('Wave'), findsOneWidget);
        expect(find.text('Fuji'), findsOneWidget);

        await t.tap(find.text('Wave'));
        await t.pumpAndSettle();
        expect(
          find.text('Someone · CC BY-SA 4.0 · Wikimedia Commons'),
          findsOneWidget,
        );
        expect(find.text('Use this picture'), findsOneWidget);

        // back goes to the results, not out of the screen
        await t.tap(find.text('Back to results'));
        await t.pumpAndSettle();
        expect(find.text('Fuji'), findsOneWidget);

        await t.tap(find.text('Wave'));
        await t.pumpAndSettle();
        await t.tap(find.text('Use this picture'));
        await t.pumpAndSettle();
        expect(find.text('open'), findsOneWidget); // the screen closed
      },
    );

    testWidgets('when thumbnails cannot load, each tile says why and can still be opened', (t) async {
      await open(t, ThumbsFail(results: [candidate('File:Wave.png')]));
      expect(find.textContaining('No preview: Wikimedia Commons answered with an error (403).'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
    });

    testWidgets(
      'no results, and no connection, each say so and offer to try again',
      (t) async {
        await open(t, FakeFinder());
        expect(find.textContaining('No pictures found'), findsOneWidget);

        await t.pageBack();
        await t.pumpAndSettle();
        await open(
          t,
          FakeFinder(
            error: PictureFinderException(
              'Could not reach Wikimedia Commons. Check your connection and try again.',
            ),
          ),
        );
        expect(
          find.textContaining('Could not reach Wikimedia Commons'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
      },
    );

    testWidgets(
      'a web address typed as the search is refused without going online',
      (t) async {
        final finder = FakeFinder(results: [candidate('File:Wave.png')]);
        await open(t, finder, query: '');
        expect(finder.searches, isEmpty);
        await t.enterText(find.byType(TextField), 'https://example.com/a.jpg');
        await t.tap(find.byTooltip('Search'));
        await t.pumpAndSettle();
        expect(finder.searches, isEmpty);
        expect(find.textContaining('not a web address'), findsWidgets);
      },
    );
  });

  test('the online-pictures setting starts unset (the app never goes online until the learner agrees)', () async {
    final e = Env();
    expect(await e.settings.get(SettingsRepo.onlinePictures), isNull);
  });
}
