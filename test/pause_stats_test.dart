import 'package:daily_learning/domain/day_clock.dart';
import 'package:daily_learning/domain/pause_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// D59: the pause's counts, rising wait, open limit and question preview.
void main() {
  final clock = DayClock(utcOffset: (_) => Duration.zero); // UTC, day turns at 04:00
  final now = DateTime.utc(2026, 10, 12, 15);
  int at(int dayBack, int hour) => DateTime.utc(2026, 10, 12 - dayBack, hour).millisecondsSinceEpoch;

  test('a log line is read back only when it is whole and sane', () {
    expect(PauseEvent.parse('1700000000000\tshown\tcom.linkedin.android')?.kind, PauseKind.shown);
    expect(PauseEvent.parse('1700000000000\tshown\tsite:*.linkedin.com')?.key, 'site:*.linkedin.com');
    for (final bad in ['', 'x\tshown\tk', '1\tjump\tk', '1\tshown\t', '1\tshown', '1\tshown\tk\textra']) {
      expect(PauseEvent.parse(bad), isNull, reason: bad);
    }
  });

  test('days are app days (04:00), oldest first; test pauses are not counted', () {
    final days = pauseDays([
      PauseEvent(at(0, 10), PauseKind.shown, 'li'),
      PauseEvent(at(0, 10), PauseKind.back, 'li'),
      PauseEvent(at(0, 11), PauseKind.shown, 'li'),
      PauseEvent(at(0, 11), PauseKind.cards, 'li'),
      PauseEvent(at(0, 2), PauseKind.shown, 'li'), // 02:00 belongs to yesterday
      PauseEvent(at(0, 2), PauseKind.open, 'li'),
      PauseEvent(at(6, 12), PauseKind.shown, 'li'),
      PauseEvent(at(7, 12), PauseKind.shown, 'li'), // eight days ago: outside the week
      PauseEvent(at(0, 12), PauseKind.shown, 'test:pause'),
    ], clock, now);
    expect(days.length, 7);
    expect((days.last.shown, days.last.back, days.last.cards, days.last.turnedAway), (2, 1, 1, 2));
    expect((days[5].shown, days[5].open), (1, 1));
    expect(days.first.shown, 1);
    expect(pauseWeekLine(days), 'This week the pause came up 4 times; you turned away 2, 1 of them for cards.');
    expect(pauseWeekLine(pauseDays(const [], clock, now)), isNull);
  });

  test('the wait grows by 5 s for each earlier pause of the same app today, up to a minute', () {
    expect(pauseWaitSeconds(shownToday: 1, rising: true), 10);
    expect(pauseWaitSeconds(shownToday: 2, rising: true), 15);
    expect(pauseWaitSeconds(shownToday: 4, rising: true), 25);
    expect(pauseWaitSeconds(shownToday: 40, rising: true), 60);
    expect(pauseWaitSeconds(shownToday: 4, rising: false), 10);
  });

  test('the open limit: off at 0; reached at the number', () {
    expect(pauseOpenLimitReached(opensToday: 9, limit: 0), isFalse);
    expect(pauseOpenLimitReached(opensToday: 2, limit: 3), isFalse);
    expect(pauseOpenLimitReached(opensToday: 3, limit: 3), isTrue);
  });

  test('the question preview: plain, one line, short', () {
    expect(pausePreview('What does **ATP** stand for?'), 'What does ATP stand for?');
    expect(pausePreview('Solve \$x^2 = 4\$\n\nfor x'), 'Solve x^2 = 4 for x');
    expect(pausePreview('  '), '');
    final long = pausePreview('word ' * 60);
    expect(long.length, lessThanOrEqualTo(kPausePreviewChars));
    expect(long.endsWith('…'), isTrue);
  });
}
