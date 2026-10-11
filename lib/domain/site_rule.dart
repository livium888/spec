/// "Pause before apps" (D58): the sites that bring up the pause in a browser. Pure Dart.
///
/// A rule is typed by the learner: `linkedin.com` (that site, with or without `www.`), `*.linkedin.com` (the site
/// and every subdomain), or either with a path, `reddit.com/r/all` (that page and everything under it). The phone
/// side (PauseRules.kt) matches the address bar against the canonical form written here, with the same rules:
/// keep the two in step. The address bar text is UNTRUSTED (a web page sets it): it is only compared, never stored.
library;

/// Most rules kept; more is refused (the list is read on every page change in a browser).
const kMaxSiteRules = 200;
const _maxHost = 253;
const _maxPath = 200;

class SiteRule {
  const SiteRule({required this.host, this.wildcard = false, this.path = ''});

  /// Lower case, no `www.`, no trailing dot.
  final String host;

  /// `*.host`: subdomains too.
  final bool wildcard;

  /// Lower case, starts with `/`, no trailing `/` (empty: the whole site).
  final String path;

  /// The form stored and handed to the phone side: `*.host/path`.
  String get canonical => '${wildcard ? '*.' : ''}$host$path';

  @override
  String toString() => canonical;

  @override
  bool operator ==(Object other) => other is SiteRule && other.canonical == canonical;
  @override
  int get hashCode => canonical.hashCode;

  /// Does the address [shown] in a browser's address bar fall under this rule?
  bool matches(String shown) {
    final a = parseAddress(shown);
    if (a == null) return false;
    final hostOk = a.host == host || a.host == 'www.$host' || (wildcard && a.host.endsWith('.$host'));
    if (!hostOk) return false;
    return path.isEmpty || a.path == path || a.path.startsWith('$path/');
  }
}

/// Why a typed rule was not accepted, in words for the learner; null when it is fine.
String? siteRuleError(String input) {
  final s = input.trim();
  if (s.isEmpty) return 'Type a site, like linkedin.com';
  if (s.contains(' ')) return 'A site has no spaces';
  if (s.contains('*') && !s.startsWith('*.')) return 'A star only goes at the start: *.example.com';
  if (parseSiteRule(s) == null) return 'That does not look like a site. Try example.com or *.example.com';
  return null;
}

/// Reads a typed rule, or null when it is not one. Accepts a pasted address too (scheme, port, query dropped).
SiteRule? parseSiteRule(String input) {
  var s = input.trim().toLowerCase();
  var wildcard = false;
  if (s.startsWith('*.')) {
    wildcard = true;
    s = s.substring(2);
  }
  if (s.contains('*')) return null;
  final a = parseAddress(s);
  if (a == null) return null;
  var host = a.host;
  if (host.startsWith('www.') && !wildcard) host = host.substring(4);
  if (!_validHost(host)) return null;
  if (a.path.length > _maxPath) return null;
  return SiteRule(host: host, wildcard: wildcard, path: a.path);
}

/// Host and path of an address as a browser shows it: with or without `https://`, maybe a port, a query or a
/// fragment. Null for text that is not an address (a search, the empty bar).
({String host, String path})? parseAddress(String shown) {
  var s = shown.trim().toLowerCase();
  if (s.isEmpty || s.contains(' ') || s.length > 2048) return null;
  final scheme = s.indexOf('://');
  if (scheme >= 0) {
    final name = s.substring(0, scheme);
    if (name != 'http' && name != 'https') return null;
    s = s.substring(scheme + 3);
  }
  final cut = s.indexOf(RegExp('[?#]'));
  if (cut >= 0) s = s.substring(0, cut);
  final slash = s.indexOf('/');
  var host = slash < 0 ? s : s.substring(0, slash);
  var path = slash < 0 ? '' : s.substring(slash);
  final at = host.lastIndexOf('@');
  if (at >= 0) host = host.substring(at + 1);
  final colon = host.indexOf(':');
  if (colon >= 0) host = host.substring(0, colon);
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (!_validHost(host)) return null;
  return (host: host, path: path);
}

final _label = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

bool _validHost(String h) {
  if (h.isEmpty || h.length > _maxHost || !h.contains('.')) return false;
  final parts = h.split('.');
  if (parts.any((p) => !_label.hasMatch(p))) return false;
  return !RegExp(r'^[0-9]+$').hasMatch(parts.last); // an IP address is not a site rule
}

/// The rules of a stored list (one per line), invalid lines dropped (a restored backup is external input), no
/// duplicates, at most [kMaxSiteRules].
List<SiteRule> siteRulesOf(String? stored) {
  final out = <SiteRule>[];
  for (final line in (stored ?? '').split('\n')) {
    final r = parseSiteRule(line);
    if (r != null && !out.contains(r)) out.add(r);
    if (out.length >= kMaxSiteRules) break;
  }
  return out;
}

String storeSiteRules(List<SiteRule> rules) => rules.map((r) => r.canonical).join('\n');

/// Minutes of free use one pause can give; the learner picks within these.
const kPauseFreeMinutesChoices = [1, 2, 3, 5, 10, 15];
const kDefaultPauseFreeMinutes = 2;

/// Did a "Do 5 cards" from the pause earn its free minutes? Answers given since the pause opened (undone ones
/// do not count): the full five, or fewer when the day ran out of cards first. Closing the review earns nothing.
bool pauseEarned({required int answersSincePause, required int quota, required bool nothingLeft}) =>
    answersSincePause >= quota || (nothingLeft && answersSincePause > 0);
