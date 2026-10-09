/// Pure parsers for the picture sources other than Wikimedia Commons: Openverse, the Metropolitan
/// Museum of Art Open Access API and the Art Institute of Chicago API. No Flutter, no I/O. Every
/// answer is untrusted JSON: types are checked, odd entries are skipped, nothing throws.
///
/// The response shapes follow each service's public documentation (verify against current docs):
/// https://api.openverse.org/v1/ , https://metmuseum.github.io/ , https://api.artic.edu/docs/
library;

import 'commons.dart';

/// Source ids, in the order results are interleaved.
const kSourceCommons = 'commons';
const kSourceOpenverse = 'openverse';
const kSourceMet = 'met';
const kSourceArtic = 'artic';

const kSourceLabels = {
  kSourceCommons: 'Wikimedia Commons',
  kSourceOpenverse: 'Openverse',
  kSourceMet: 'The Met',
  kSourceArtic: 'Art Institute of Chicago',
};

/// Licences kept from Openverse: public domain and the Creative Commons licences that allow reuse
/// with credit. NonCommercial and NoDerivatives are left out to stay on the safe side.
const kOpenverseLicences = {'by', 'by-sa', 'cc0', 'pdm'};

String _s(Object? v) => v is String ? v.trim() : '';
int _i(Object? v) => v is int ? v : (v is double ? v.toInt() : 0);

/// "by-sa" + "4.0" -> "CC BY-SA 4.0"; "cc0" -> "CC0"; "pdm" -> "Public domain".
String openverseLicenceName(String code, String version) {
  final c = code.toLowerCase();
  if (c == 'cc0') return 'CC0';
  if (c == 'pdm') return 'Public domain';
  return 'CC ${c.toUpperCase()}${version.isEmpty ? '' : ' $version'}';
}

/// Openverse image search: `GET /v1/images/?q=...`. Thumbnails come from Openverse's own proxy
/// (`thumbnail`), so no other website is ever contacted.
List<PictureCandidate> parseOpenverse(Object? json) {
  if (json is! Map || json['results'] is! List) return const [];
  final out = <PictureCandidate>[];
  for (final r in json['results'] as List) {
    if (r is! Map) continue;
    final licence = _s(r['license']).toLowerCase();
    if (!kOpenverseLicences.contains(licence)) continue;
    if (r['mature'] == true) continue;
    final thumb = _s(r['thumbnail']);
    final landing = _s(r['foreign_landing_url']);
    final title = _s(r['title']);
    if (thumb.isEmpty || landing.isEmpty) continue;
    final width = _i(r['width']);
    if (width != 0 && width < kMinPictureWidth) continue;
    final provider = _s(r['source']).isNotEmpty ? _s(r['source']) : _s(r['provider']);
    final name = title.isEmpty ? 'Untitled' : _clipName(stripMarkup(title));
    out.add(PictureCandidate(
      title: name,
      displayName: name,
      pageUrl: landing,
      thumbUrl: thumb,
      mime: 'image/jpeg', // the proxy serves JPEG or WebP; the real type is checked from the bytes
      width: width,
      height: _i(r['height']),
      credit: buildCredit(
        title: name,
        artist: stripMarkup(_s(r['creator'])),
        license: openverseLicenceName(licence, _s(r['license_version'])),
        source: provider.isEmpty ? 'Openverse' : 'Openverse ($provider)',
      ),
      description: '',
      source: kSourceOpenverse,
      sourceLabel: kSourceLabels[kSourceOpenverse]!,
    ));
  }
  return out;
}

String _clipName(String s) => s.length <= 120 ? s : '${s.substring(0, 119).trimRight()}…';

/// Met search answer: the object ids (null when nothing matches).
List<int> parseMetSearch(Object? json) {
  if (json is! Map || json['objectIDs'] is! List) return const [];
  return [for (final id in json['objectIDs'] as List) if (id is int) id];
}

/// One Met object. Only public-domain objects with a picture count; the web-sized copy
/// (`primaryImageSmall`) is used for both preview and keeping (the full original can be huge).
PictureCandidate? parseMetObject(Object? json) {
  if (json is! Map) return null;
  if (json['isPublicDomain'] != true) return null;
  final image = _s(json['primaryImageSmall']);
  final page = _s(json['objectURL']);
  final title = _s(json['title']);
  if (image.isEmpty || page.isEmpty) return null;
  final artist = _s(json['artistDisplayName']);
  final date = _s(json['objectDate']);
  final name = title.isEmpty ? 'Untitled' : _clipName(title);
  return PictureCandidate(
    title: name,
    displayName: name,
    pageUrl: page,
    thumbUrl: image,
    mime: 'image/jpeg',
    width: 0,
    height: 0,
    credit: buildCredit(title: name, artist: artist, license: 'Public domain', source: 'The Metropolitan Museum of Art'),
    description: [if (artist.isNotEmpty) artist, if (date.isNotEmpty) date].join(', '),
    source: kSourceMet,
    sourceLabel: kSourceLabels[kSourceMet]!,
  );
}

/// Art Institute of Chicago search: `GET /api/v1/artworks/search?q=...`. Images are served from the
/// IIIF address in `config.iiif_url`; 843 px wide is the size the museum recommends.
List<PictureCandidate> parseArtic(Object? json, {int width = 843}) {
  if (json is! Map || json['data'] is! List) return const [];
  final config = json['config'];
  final iiif = config is Map && _s(config['iiif_url']).isNotEmpty ? _s(config['iiif_url']) : 'https://www.artic.edu/iiif/2';
  final out = <PictureCandidate>[];
  for (final r in json['data'] as List) {
    if (r is! Map) continue;
    if (r['is_public_domain'] != true) continue;
    final imageId = _s(r['image_id']);
    if (imageId.isEmpty || !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(imageId)) continue;
    final id = r['id'];
    final title = _s(r['title']);
    final artist = _s(r['artist_display']).split('\n').first.trim();
    final name = title.isEmpty ? 'Untitled' : _clipName(title);
    final url = '$iiif/$imageId/full/$width,/0/default.jpg';
    out.add(PictureCandidate(
      title: name,
      displayName: name,
      pageUrl: id is int ? 'https://www.artic.edu/artworks/$id' : 'https://www.artic.edu',
      thumbUrl: url,
      mime: 'image/jpeg',
      width: width,
      height: 0,
      credit: buildCredit(title: name, artist: artist, license: 'Public domain (CC0)', source: 'Art Institute of Chicago'),
      description: _s(r['date_display']),
      source: kSourceArtic,
      sourceLabel: kSourceLabels[kSourceArtic]!,
    ));
  }
  return out;
}
