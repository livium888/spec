import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../app/build_info.dart';
import '../domain/commons.dart';

/// Why a lookup failed, in words for the learner.
class PictureFinderException implements Exception {
  PictureFinderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Finding a picture for a card. The ONLY place in the app that touches the network, and only
/// when the learner taps "Find a picture" (decision D32). Abstract so tests never go online.
abstract class PictureFinder {
  /// Pictures matching [query], best match first (at most 8).
  Future<List<PictureCandidate>> search(String query);

  /// The same file scaled for keeping on a card (about 960 px wide), or null if it is unusable.
  Future<PictureCandidate?> forCard(String title);

  /// Bytes of a picture (preview or the one to keep). Throws [PictureFinderException].
  Future<Uint8List> download(String url, {required int maxBytes});
}

/// One restricted HTTPS GET: only listed hosts, no redirects, a size ceiling, short timeouts.
/// Everything the app downloads goes through here, so the limits hold for every caller.
class SafeFetcher {
  SafeFetcher({
    this.allowedHosts = const {'commons.wikimedia.org', 'upload.wikimedia.org'},
    this.requireHttps = true,
    this.timeout = const Duration(seconds: 20),
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Set<String> allowedHosts;
  final bool requireHttps; // false only in tests that talk to a loopback server
  final Duration timeout;
  final HttpClient Function() _clientFactory;

  /// Wikimedia asks every client to say who it is. The repository address is the contact.
  static String get userAgent => 'DailyLearning/${BuildInfo.number} (https://github.com/livium888/spec; flashcard app)';

  Uri checked(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasAuthority || u.host.isEmpty) throw PictureFinderException('That address is not valid.');
    if (requireHttps && u.scheme != 'https') throw PictureFinderException('Only secure (https) addresses are used.');
    if (!allowedHosts.contains(u.host)) throw PictureFinderException('That picture is not on Wikimedia Commons.');
    if (u.userInfo.isNotEmpty) throw PictureFinderException('That address is not valid.');
    return u;
  }

  /// At most this many downloads run at once (a results grid asks for eight thumbnails; Wikimedia
  /// asks clients to be gentle).
  static const maxParallel = 3;
  int _running = 0;
  final _waiting = <Completer<void>>[];

  Future<void> _enter() async {
    if (_running < maxParallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future; // the slot is handed over by _leave
  }

  void _leave() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  Future<Uint8List> get(String url, {required int maxBytes}) async {
    final uri = checked(url);
    await _enter();
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = userAgent;
    try {
      return await _read(client, uri, maxBytes).timeout(timeout);
    } on PictureFinderException {
      rethrow;
    } on TimeoutException {
      throw PictureFinderException('Wikimedia Commons took too long to answer. Try again.');
    } on SocketException {
      throw PictureFinderException('Could not reach Wikimedia Commons. Check your connection and try again.');
    } on HandshakeException {
      throw PictureFinderException('Could not make a secure connection. Check the date and time on your phone.');
    } on HttpException catch (e) {
      throw PictureFinderException('The download failed: ${e.message}');
    } finally {
      client.close(force: true);
      _leave();
    }
  }

  /// Redirects are followed by hand, at most [maxRedirects] times, and EVERY hop must pass the
  /// same host check, so a redirect can never lead off the allowed hosts.
  static const maxRedirects = 3;

  Future<Uint8List> _read(HttpClient client, Uri uri, int maxBytes) async {
    var target = uri;
    HttpClientResponse res;
    for (var hop = 0;; hop++) {
      final req = await client.getUrl(target);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, image/jpeg, image/png, image/webp, */*;q=0.1');
      res = await req.close();
      final redirect = const {301, 302, 303, 307, 308}.contains(res.statusCode);
      if (!redirect) break;
      final location = res.headers.value(HttpHeaders.locationHeader);
      await res.drain<void>().catchError((_) {});
      if (location == null || hop >= maxRedirects) {
        throw PictureFinderException('Wikimedia Commons sent the app somewhere unexpected (${res.statusCode}).');
      }
      target = checked(target.resolve(location).toString());
    }
    if (res.statusCode == 429) {
      await res.drain<void>();
      throw PictureFinderException('Wikimedia is asking apps to slow down. Wait a minute and try again.');
    }
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw PictureFinderException('Wikimedia Commons answered with an error (${res.statusCode}).');
    }
    if (res.contentLength > maxBytes) {
      await res.drain<void>().catchError((_) {});
      throw PictureFinderException('That picture is too large (over ${(maxBytes / 1e6).toStringAsFixed(1)} MB).');
    }
    final out = BytesBuilder(copy: false);
    await for (final chunk in res) {
      out.add(chunk);
      if (out.length > maxBytes) {
        throw PictureFinderException('That picture is too large (over ${(maxBytes / 1e6).toStringAsFixed(1)} MB).');
      }
    }
    return out.takeBytes();
  }
}

/// Wikimedia Commons, through the public MediaWiki Action API. Verify against current docs:
/// https://www.mediawiki.org/wiki/API:Search and https://www.mediawiki.org/wiki/API:Imageinfo
class CommonsPictureFinder implements PictureFinder {
  CommonsPictureFinder({SafeFetcher? fetcher}) : _fetch = fetcher ?? SafeFetcher();
  final SafeFetcher _fetch;

  static const _api = 'https://commons.wikimedia.org/w/api.php';
  static const _jsonLimit = 400000; // a search answer is a few KB; this only stops a runaway reply

  /// Previews are small; the kept copy is about 960 px wide (one of the thumbnail sizes Wikimedia
  /// serves from cache; other sizes can be refused). Verify against current docs.
  static const previewWidth = 250;
  static const cardWidth = 960;

  Future<Object?> _json(Map<String, String> params) async {
    final uri = Uri.parse(_api).replace(queryParameters: {'format': 'json', 'formatversion': '2', ...params});
    final bytes = await _fetch.get(uri.toString(), maxBytes: _jsonLimit);
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw PictureFinderException('Wikimedia Commons sent an answer the app could not read.');
    }
  }

  @override
  Future<List<PictureCandidate>> search(String query) async {
    final q = cleanImageQuery(query);
    if (q == null) throw PictureFinderException('Type a few words that describe the picture, not a web address.');
    final json = await _json({
      'action': 'query',
      'generator': 'search',
      'gsrnamespace': '6', // files
      'gsrsearch': q,
      'gsrlimit': '12',
      'prop': 'imageinfo',
      'iiprop': 'url|mime|size|extmetadata',
      'iiextmetadatafilter': 'Artist|LicenseShortName|ImageDescription',
      'iiurlwidth': '$previewWidth',
    });
    return parseCommonsPages(json).take(8).toList();
  }

  @override
  Future<PictureCandidate?> forCard(String title) async {
    final json = await _json({
      'action': 'query',
      'titles': title,
      'prop': 'imageinfo',
      'iiprop': 'url|mime|size|extmetadata',
      'iiextmetadatafilter': 'Artist|LicenseShortName|ImageDescription',
      'iiurlwidth': '$cardWidth',
    });
    final r = parseCommonsPages(json);
    return r.isEmpty ? null : r.first;
  }

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) => _fetch.get(url, maxBytes: maxBytes);
}
