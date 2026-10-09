/// Pure helpers for the "Find a picture" lookup (Wikimedia Commons). No Flutter, no I/O.
///
/// The response shape follows the MediaWiki Action API (`action=query`, `prop=imageinfo`,
/// `formatversion=2`). Verify against current docs: https://www.mediawiki.org/wiki/API:Imageinfo
library;

/// Longest search phrase kept (from an AI's "image_query" or typed by the learner).
const kMaxImageQueryChars = 120;

/// Longest credit line stored on a card.
const kMaxCreditChars = 300;

/// Picture types the app will keep. SVG, GIF, TIFF and PDF are left out on purpose: not every
/// phone decodes them and animated or vector files are not what a card needs.
const kAllowedImageMimes = {'image/jpeg', 'image/png', 'image/webp'};

/// Pictures narrower than this are icons or thumbnails of thumbnails, not worth keeping.
const kMinPictureWidth = 400;

class PictureCandidate {
  const PictureCandidate({
    required this.title,
    required this.pageUrl,
    required this.thumbUrl,
    required this.mime,
    required this.width,
    required this.height,
    required this.credit,
    required this.description,
    this.source = 'commons',
    this.sourceLabel = 'Wikimedia Commons',
    this.cardUrl,
    this.displayName,
  });

  /// Which source it came from ('commons', 'openverse', 'met', 'artic') and its name for the learner.
  final String source, sourceLabel;

  /// Address of the copy to keep on a card, when it is already known (null: ask the source, as
  /// Commons does, because it scales files on request).
  final String? cardUrl;

  /// A readable name when the source's own title is already clean (Commons titles are file names).
  final String? displayName;

  /// The same picture, pointing at the copy to keep on a card.
  PictureCandidate forKeeping() => cardUrl == null
      ? this
      : PictureCandidate(
          title: title,
          pageUrl: pageUrl,
          thumbUrl: cardUrl!,
          mime: mime,
          width: width,
          height: height,
          credit: credit,
          description: description,
          source: source,
          sourceLabel: sourceLabel,
          displayName: displayName,
        );

  /// "File:Mona Lisa.jpg" as Commons names it.
  final String title;
  final String pageUrl; // the file's description page (kept as text in the credit, never opened by the app)
  final String thumbUrl; // a scaled copy served by upload.wikimedia.org
  final String mime;
  final int width, height; // of the scaled copy
  final String credit; // "Author · Licence · Wikimedia Commons", plain text
  final String description; // plain text, may be empty

  /// "Mona Lisa" from "File:Mona Lisa.jpg": a readable name for lists and for a screen reader.
  String get label => displayName ?? cleanTitle(title);
}

/// "File:Hokusai_-_Great_Wave.jpg" -> "Hokusai - Great Wave".
String cleanTitle(String title) {
  var t = title.trim();
  if (t.toLowerCase().startsWith('file:')) t = t.substring(5);
  final dot = t.lastIndexOf('.');
  if (dot > 0 && t.length - dot <= 5) t = t.substring(0, dot);
  return t.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A search phrase safe to send, or null if there is nothing usable. Whitespace is collapsed,
/// control characters removed, and anything that looks like a web address is refused: a pasted URL
/// is never fetched, and an AI that writes one here has not followed the instructions.
String? cleanImageQuery(Object? raw) {
  if (raw is! String) return null;
  final q = raw.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (q.isEmpty || q.length > kMaxImageQueryChars) return null;
  if (RegExp(r'(https?:|ftp:|www\.|://|\.(com|org|net|io)\b)', caseSensitive: false).hasMatch(q)) return null;
  return q;
}

/// Strip markup from a Commons metadata value (artist names and descriptions arrive as HTML).
String stripMarkup(String html) {
  var s = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  const entities = {'&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'", '&nbsp;': ' '};
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#(\d{1,6});'), (m) {
    final code = int.parse(m[1]!);
    return code > 0 && code < 0x110000 && !(code >= 0xD800 && code < 0xE000) ? String.fromCharCode(code) : ' ';
  });
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _meta(Map<String, dynamic>? ext, String key) {
  final v = ext?[key];
  if (v is Map && v['value'] is String) return stripMarkup(v['value'] as String);
  return '';
}

String _clip(String s, int max) => s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';

/// "Leonardo da Vinci · Public domain · Wikimedia Commons". Licences need to be shown with the
/// picture (CC BY and CC BY-SA require credit), so this line is stored on the card and displayed.
String buildCredit({String artist = '', String license = '', String title = '', String source = 'Wikimedia Commons'}) {
  final parts = [
    if (artist.isNotEmpty) _clip(artist, 120),
    if (license.isNotEmpty) _clip(license, 40),
    source,
  ];
  final line = parts.join(' · ');
  return _clip(title.isEmpty ? line : '${_clip(title, 80)} — $line', kMaxCreditChars);
}

/// Pictures from a Commons query response, best search match first. Anything unexpected is skipped
/// rather than thrown: the response is outside input.
List<PictureCandidate> parseCommonsPages(Object? json) {
  if (json is! Map) return const [];
  final query = json['query'];
  if (query is! Map) return const [];
  final pages = query['pages'];
  if (pages is! List) return const [];
  final ranked = <(int, PictureCandidate)>[];
  for (final p in pages) {
    if (p is! Map) continue;
    final title = p['title'];
    final infos = p['imageinfo'];
    if (title is! String || infos is! List || infos.isEmpty || infos.first is! Map) continue;
    final info = (infos.first as Map).cast<String, dynamic>();
    final mime = info['mime'];
    final thumb = info['thumburl'] ?? info['url'];
    final pageUrl = info['descriptionurl'];
    if (mime is! String || !kAllowedImageMimes.contains(mime)) continue;
    if (thumb is! String || pageUrl is! String) continue;
    final width = (info['thumbwidth'] ?? info['width']) is int ? (info['thumbwidth'] ?? info['width']) as int : 0;
    final height = (info['thumbheight'] ?? info['height']) is int ? (info['thumbheight'] ?? info['height']) as int : 0;
    final origWidth = info['width'] is int ? info['width'] as int : width;
    if (origWidth < kMinPictureWidth) continue;
    final ext = info['extmetadata'] is Map ? (info['extmetadata'] as Map).cast<String, dynamic>() : null;
    ranked.add((
      p['index'] is int ? p['index'] as int : 1 << 20,
      PictureCandidate(
        title: title,
        pageUrl: pageUrl,
        thumbUrl: thumb,
        mime: mime,
        width: width,
        height: height,
        credit: buildCredit(
          artist: _meta(ext, 'Artist'),
          license: _meta(ext, 'LicenseShortName'),
        ),
        description: _clip(_meta(ext, 'ImageDescription'), 300),
      ),
    ));
  }
  ranked.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final r in ranked) r.$2];
}
