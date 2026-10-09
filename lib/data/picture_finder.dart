import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../app/build_info.dart';
import '../domain/commons.dart';
import '../domain/picture_sources.dart';

/// Why a lookup failed, in words for the learner.
class PictureFinderException implements Exception {
  PictureFinderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What a search found: pictures from every source that answered, plus a reason for each source
/// that did not (so one site being down or rate-limited never hides the others).
class PictureSearch {
  const PictureSearch(this.candidates, [this.failures = const {}]);
  final List<PictureCandidate> candidates;
  final Map<String, String> failures; // source label -> reason
}

/// Finding a picture for a card. The ONLY place in the app that touches the network, and only
/// when the learner taps "Find a picture" (decisions D32, D33). Abstract so tests never go online.
abstract class PictureFinder {
  /// Pictures matching [query] from the chosen [sources] (null = all), interleaved so every source
  /// is represented.
  Future<PictureSearch> search(String query, {Set<String>? sources});

  /// The copy to keep on a card (a larger file than the preview for some sources), or null if it
  /// is unusable. The returned candidate's `thumbUrl` is the address to download.
  Future<PictureCandidate?> forCard(PictureCandidate c);

  /// Bytes of a picture (preview or the one to keep). Throws [PictureFinderException].
  Future<Uint8List> download(String url, {required int maxBytes});
}

/// Every host the app may contact, and nothing else (decisions D32 and D33). Adding a host is a
/// deliberate decision, not a code tweak. Image files only ever come from these hosts: Openverse's
/// own thumbnail proxy is used instead of the many websites its originals live on.
const kPictureHosts = {
  'commons.wikimedia.org',
  'upload.wikimedia.org',
  'api.openverse.org',
  'collectionapi.metmuseum.org',
  'images.metmuseum.org',
  'api.artic.edu',
  'www.artic.edu',
};

/// One restricted HTTPS GET: only listed hosts, no redirects, a size ceiling, short timeouts.
/// Everything the app downloads goes through here, so the limits hold for every caller.
class SafeFetcher {
  SafeFetcher({
    this.allowedHosts = kPictureHosts,
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
    if (!allowedHosts.contains(u.host)) throw PictureFinderException('That address is not on the list of sites this app uses.');
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
      throw PictureFinderException('The website took too long to answer. Try again.');
    } on SocketException {
      throw PictureFinderException('Could not reach the website. Check your connection and try again.');
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
        throw PictureFinderException('The website sent the app somewhere unexpected (${res.statusCode}).');
      }
      target = checked(target.resolve(location).toString());
    }
    if (res.statusCode == 429) {
      await res.drain<void>();
      throw PictureFinderException('The website is asking apps to slow down. Wait a minute and try again.');
    }
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw PictureFinderException('The website (${uri.host}) answered with an error (${res.statusCode}).');
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

/// One place pictures can come from.
abstract class PictureSource {
  PictureSource(this.fetch);
  final SafeFetcher fetch;

  String get id;
  String get label;

  /// At most [limit] usable pictures for [query] (already cleaned).
  Future<List<PictureCandidate>> search(String query, {int limit = 5});

  /// The copy to keep. Most sources know it already; Commons asks again for a larger file.
  Future<PictureCandidate?> forCard(PictureCandidate c) async => c.forKeeping();

  static const jsonLimit = 400000; // an answer is a few KB; this only stops a runaway reply

  Future<Object?> getJson(Uri uri) async {
    final bytes = await fetch.get(uri.toString(), maxBytes: jsonLimit);
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw PictureFinderException('$label sent an answer the app could not read.');
    }
  }
}

/// Wikimedia Commons, through the public MediaWiki Action API. Verify against current docs:
/// https://www.mediawiki.org/wiki/API:Search and https://www.mediawiki.org/wiki/API:Imageinfo
class CommonsSource extends PictureSource {
  CommonsSource(super.fetch);
  @override
  String get id => kSourceCommons;
  @override
  String get label => kSourceLabels[kSourceCommons]!;

  static const _api = 'https://commons.wikimedia.org/w/api.php';

  /// Previews are small; the kept copy is about 960 px wide (one of the thumbnail sizes Wikimedia
  /// serves from cache; other sizes can be refused). Verify against current docs.
  static const previewWidth = 250;
  static const cardWidth = 960;

  Future<Object?> _json(Map<String, String> params) =>
      getJson(Uri.parse(_api).replace(queryParameters: {'format': 'json', 'formatversion': '2', ...params}));

  @override
  Future<List<PictureCandidate>> search(String query, {int limit = 5}) async {
    final json = await _json({
      'action': 'query',
      'generator': 'search',
      'gsrnamespace': '6', // files
      'gsrsearch': query,
      'gsrlimit': '${limit * 2}',
      'prop': 'imageinfo',
      'iiprop': 'url|mime|size|extmetadata',
      'iiextmetadatafilter': 'Artist|LicenseShortName|ImageDescription',
      'iiurlwidth': '$previewWidth',
    });
    return parseCommonsPages(json).take(limit).toList();
  }

  @override
  Future<PictureCandidate?> forCard(PictureCandidate c) async {
    final json = await _json({
      'action': 'query',
      'titles': c.title,
      'prop': 'imageinfo',
      'iiprop': 'url|mime|size|extmetadata',
      'iiextmetadatafilter': 'Artist|LicenseShortName|ImageDescription',
      'iiurlwidth': '$cardWidth',
    });
    final r = parseCommonsPages(json);
    return r.isEmpty ? null : r.first;
  }
}

/// Openverse: Creative Commons images gathered from Flickr, museums, Commons and more.
class OpenverseSource extends PictureSource {
  OpenverseSource(super.fetch);
  @override
  String get id => kSourceOpenverse;
  @override
  String get label => kSourceLabels[kSourceOpenverse]!;

  @override
  Future<List<PictureCandidate>> search(String query, {int limit = 5}) async {
    final json = await getJson(Uri.https('api.openverse.org', '/v1/images/', {
      'q': query,
      'page_size': '${limit * 3}', // some are dropped for licence or size
      'license_type': 'commercial,modification',
      'mature': 'false',
    }));
    return parseOpenverse(json).take(limit).toList();
  }
}

/// The Metropolitan Museum of Art Open Access collection: a search gives object numbers, each
/// object is then fetched (at most [maxObjects], a few at a time by the fetcher).
class MetSource extends PictureSource {
  MetSource(super.fetch);
  @override
  String get id => kSourceMet;
  @override
  String get label => kSourceLabels[kSourceMet]!;

  static const maxObjects = 10;

  @override
  Future<List<PictureCandidate>> search(String query, {int limit = 5}) async {
    final ids = parseMetSearch(await getJson(
        Uri.https('collectionapi.metmuseum.org', '/public/collection/v1/search', {'q': query, 'hasImages': 'true'})));
    final objects = await Future.wait([
      for (final id in ids.take(maxObjects))
        getJson(Uri.https('collectionapi.metmuseum.org', '/public/collection/v1/objects/$id'))
            .then<Object?>((v) => v)
            .catchError((Object _) => null), // one missing object never fails the search
    ]);
    return [
      for (final o in objects) ?parseMetObject(o),
    ].take(limit).toList();
  }
}

/// The Art Institute of Chicago public API (images from its IIIF server).
class ArticSource extends PictureSource {
  ArticSource(super.fetch);
  @override
  String get id => kSourceArtic;
  @override
  String get label => kSourceLabels[kSourceArtic]!;

  @override
  Future<List<PictureCandidate>> search(String query, {int limit = 5}) async {
    final json = await getJson(Uri.https('api.artic.edu', '/api/v1/artworks/search', {
      'q': query,
      'limit': '${limit * 3}',
      'fields': 'id,title,artist_display,date_display,image_id,is_public_domain',
      'query[term][is_public_domain]': 'true',
    }));
    return parseArtic(json).take(limit).toList();
  }
}

/// All sources behind one search box. Sources run side by side; each failure is reported by name
/// and the others still show. Results are interleaved (one from each in turn) so a source with
/// many matches cannot push the rest off the screen.
class PictureLookup implements PictureFinder {
  PictureLookup({SafeFetcher? fetcher, List<PictureSource>? sources})
      : _fetch = fetcher ?? SafeFetcher(),
        _sources = sources ?? const [] {
    if (sources == null) {
      _sources = [CommonsSource(_fetch), OpenverseSource(_fetch), MetSource(_fetch), ArticSource(_fetch)];
    }
  }
  final SafeFetcher _fetch;
  late List<PictureSource> _sources;

  static const perSource = 5;

  List<PictureSource> get sources => _sources;

  @override
  Future<PictureSearch> search(String query, {Set<String>? sources}) async {
    final q = cleanImageQuery(query);
    if (q == null) throw PictureFinderException('Type a few words that describe the picture, not a web address.');
    final chosen = [for (final s in _sources) if (sources == null || sources.contains(s.id)) s];
    if (chosen.isEmpty) throw PictureFinderException('Choose at least one picture source.');
    final failures = <String, String>{};
    final lists = await Future.wait([
      for (final s in chosen)
        s.search(q, limit: perSource).then<List<PictureCandidate>>((r) => r).catchError((Object e) {
          failures[s.label] = e is PictureFinderException ? e.message : 'it did not answer';
          return <PictureCandidate>[];
        }),
    ]);
    // Only pictures on allowed hosts are ever offered, whatever a source's answer says.
    bool allowed(PictureCandidate c) {
      final u = Uri.tryParse(c.thumbUrl);
      return u != null && (c.cardUrl == null || Uri.tryParse(c.cardUrl!) != null) && _fetch.allowedHosts.contains(u.host);
    }

    final out = <PictureCandidate>[];
    for (var i = 0; i < perSource; i++) {
      for (final l in lists) {
        if (i < l.length && allowed(l[i])) out.add(l[i]);
      }
    }
    return PictureSearch(out, failures);
  }

  PictureSource? _sourceFor(PictureCandidate c) {
    for (final s in _sources) {
      if (s.id == c.source) return s;
    }
    return null;
  }

  @override
  Future<PictureCandidate?> forCard(PictureCandidate c) => _sourceFor(c)?.forCard(c) ?? Future.value(c.forKeeping());

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) => _fetch.get(url, maxBytes: maxBytes);
}
