import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/picture_finder.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/commons.dart';
import 'package:daily_learning/domain/import_parser.dart';
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

  @override
  Future<List<PictureCandidate>> search(String query) async {
    searches.add(query);
    if (error != null) throw error!;
    return results;
  }

  @override
  Future<PictureCandidate?> forCard(String title) async =>
      results.firstWhere((r) => r.title == title);

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

  group('CommonsPictureFinder', () {
    test(
      'searches files on Commons for the cleaned phrase and returns at most 8',
      () async {
        final fetch = FakeFetcher({
          'generator=search': response([
            for (var i = 1; i <= 12; i++) page('File:P$i.jpg', i),
          ]),
        });
        final r = await CommonsPictureFinder(fetcher: fetch)
            .search('  Mona   Lisa ');
        expect(r, hasLength(8));
        final u = fetch.urls.single;
        expect(u.host, 'commons.wikimedia.org');
        expect(u.queryParameters['gsrsearch'], 'Mona Lisa');
        expect(u.queryParameters['gsrnamespace'], '6');
        expect(u.queryParameters['iiurlwidth'], '250');
        expect(u.queryParameters['formatversion'], '2');
      },
    );

    test(
      'refuses a web address as a search and does not go online for it',
      () async {
        final fetch = FakeFetcher({});
        await expectLater(
          CommonsPictureFinder(fetcher: fetch)
              .search('https://example.com/x.jpg'),
          throwsA(isA<PictureFinderException>()),
        );
        expect(fetch.urls, isEmpty);
      },
    );

    test('asks for the card-sized copy of the chosen file by title', () async {
      final fetch = FakeFetcher({
        'titles=': response([page('File:Mona_Lisa.jpg', 1)]),
      });
      final c = await CommonsPictureFinder(fetcher: fetch)
          .forCard('File:Mona_Lisa.jpg');
      expect(c!.label, 'Mona Lisa');
      expect(fetch.urls.single.queryParameters['titles'], 'File:Mona_Lisa.jpg');
      expect(fetch.urls.single.queryParameters['iiurlwidth'], '960');
    });

    test('an answer that is not JSON is a clear error, not a crash', () async {
      final fetch = FakeFetcher({
        'generator=search': Uint8List.fromList(utf8.encode('<html>nope')),
      });
      await expectLater(
        CommonsPictureFinder(fetcher: fetch).search('cats'),
        throwsA(isA<PictureFinderException>()),
      );
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
