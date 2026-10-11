import 'package:daily_learning/domain/site_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// D58: the sites that bring up the pause. The phone side (PauseRules.kt) mirrors these rules.
void main() {
  group('typing a rule', () {
    test('a plain site, a wildcard, a path; pasted addresses are cleaned', () {
      expect(parseSiteRule('linkedin.com')?.canonical, 'linkedin.com');
      expect(parseSiteRule('  LinkedIn.COM ')?.canonical, 'linkedin.com');
      expect(parseSiteRule('www.linkedin.com')?.canonical, 'linkedin.com', reason: 'www. is the same site');
      expect(parseSiteRule('*.linkedin.com')?.canonical, '*.linkedin.com');
      expect(parseSiteRule('https://www.reddit.com/r/all/?sort=new#top')?.canonical, 'reddit.com/r/all');
      expect(parseSiteRule('http://news.example.com:8080/feed/')?.canonical, 'news.example.com/feed');
      expect(parseSiteRule('example.com.')?.canonical, 'example.com', reason: 'a trailing dot is the same host');
    });

    test('not a site: refused with a reason', () {
      for (final bad in ['', 'linkedin', 'linked in.com', 'li*nked.com', 'ftp://example.com', '192.168.0.1', '-bad-.com', 'a..com', '*.']) {
        expect(parseSiteRule(bad), isNull, reason: bad);
        expect(siteRuleError(bad), isNotNull, reason: bad);
      }
      expect(siteRuleError('example.com'), isNull);
      expect(siteRuleError('*.example.com/path'), isNull);
    });
  });

  group('matching what a browser shows', () {
    final plain = parseSiteRule('linkedin.com')!;
    final wild = parseSiteRule('*.linkedin.com')!;
    final page = parseSiteRule('reddit.com/r/all')!;

    test('plain: the site and www., not other subdomains', () {
      expect(plain.matches('linkedin.com'), isTrue);
      expect(plain.matches('https://www.linkedin.com/feed/'), isTrue);
      expect(plain.matches('LINKEDIN.com/in/someone'), isTrue);
      expect(plain.matches('m.linkedin.com'), isFalse);
      expect(plain.matches('notlinkedin.com'), isFalse, reason: 'a different site that ends the same way');
      expect(plain.matches('linkedin.com.evil.example'), isFalse);
    });

    test('wildcard: the site and every subdomain', () {
      expect(wild.matches('linkedin.com'), isTrue);
      expect(wild.matches('m.linkedin.com/feed'), isTrue);
      expect(wild.matches('a.b.linkedin.com'), isTrue);
      expect(wild.matches('notlinkedin.com'), isFalse);
    });

    test('a path: that page and below, at a path boundary', () {
      expect(page.matches('reddit.com/r/all'), isTrue);
      expect(page.matches('https://www.reddit.com/r/all/top?t=day'), isTrue);
      expect(page.matches('reddit.com/r/allergies'), isFalse);
      expect(page.matches('reddit.com'), isFalse, reason: 'a browser showing only the domain cannot match a page rule');
    });

    test('a search or the empty bar is not an address', () {
      expect(plain.matches(''), isFalse);
      expect(plain.matches('linkedin jobs'), isFalse);
      expect(plain.matches('javascript://linkedin.com'), isFalse);
      expect(plain.matches('user@linkedin.com'), isTrue, reason: 'user info before @ is dropped, the host is what counts');
    });
  });

  test('a stored list: bad lines dropped, duplicates removed, capped', () {
    final rules = siteRulesOf('linkedin.com\n\nnot a site\nwww.linkedin.com\n*.reddit.com');
    expect(rules.map((r) => r.canonical), ['linkedin.com', '*.reddit.com']);
    expect(siteRulesOf(null), isEmpty);
    expect(siteRulesOf([for (var i = 0; i < 300; i++) 's$i.example.com'].join('\n')).length, kMaxSiteRules);
    expect(storeSiteRules(rules), 'linkedin.com\n*.reddit.com');
  });

  test('free minutes are earned by answers, not by opening and closing the review', () {
    expect(pauseEarned(answersSincePause: 5, quota: 5, nothingLeft: false), isTrue);
    expect(pauseEarned(answersSincePause: 4, quota: 5, nothingLeft: false), isFalse);
    expect(pauseEarned(answersSincePause: 2, quota: 5, nothingLeft: true), isTrue, reason: 'the day ran out of cards first');
    expect(pauseEarned(answersSincePause: 0, quota: 5, nothingLeft: true), isFalse);
  });
}
