import 'package:daily_learning/domain/day_clock.dart';
import 'package:daily_learning/domain/pause_moves.dart';
import 'package:daily_learning/domain/pause_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// D61: "Move first", the exercises offered on the pause.
void main() {
  group('a stored list', () {
    test('nothing stored means the suggestions; stored but empty means the learner removed them all', () {
      expect(pauseMovesOf(null), kStarterMoves);
      expect(pauseMovesOf(''), isEmpty);
      expect(kStarterMoves.length, lessThanOrEqualTo(kMaxPauseMoves));
      expect(kStarterMoves.every((m) => pauseMoveError(m.name, m.seconds) == null), isTrue, reason: 'every suggestion is itself valid');
      expect(kStarterMoves.any((m) => m.name.contains('desk')), isTrue, reason: 'a quiet one for a desk');
    });

    test('round trip, order kept', () {
      final moves = [const PauseMove('Plank', 60), const PauseMove('10 push-ups', 40)];
      expect(pauseMovesOf(storePauseMoves(moves)), moves);
    });

    test('junk from a restored backup is dropped line by line', () {
      final got = pauseMovesOf([
        '10 push-ups|40',
        'no bar',
        '|30',
        'too quick|9',
        'too slow|301',
        'not a number|abc',
        'two|bars|30',
        'Ctrl\u0007char|30',
        'Line sep|20',
        '${'x' * 41}|20',
        '  Plank   1 min | 60 ',
        'plank 1 min|45', // the same name again, any case
        '10 push-ups|40.5',
      ].join('\n'));
      expect(got.map((m) => m.canonical), ['10 push-ups|40', 'Plank 1 min|60']);
    });

    test('at most twelve', () {
      final many = [for (var i = 1; i <= 20; i++) 'Move $i|20'].join('\n');
      expect(pauseMovesOf(many).length, kMaxPauseMoves);
    });
  });

  group('what the learner types', () {
    test('errors say what to fix', () {
      expect(pauseMoveError('', 30), isNotNull);
      expect(pauseMoveError('   ', 30), isNotNull);
      expect(pauseMoveError('x' * 41, 30), isNotNull);
      expect(pauseMoveError('a|b', 30), isNotNull);
      expect(pauseMoveError('ok', null), isNotNull);
      expect(pauseMoveError('ok', 9), isNotNull);
      expect(pauseMoveError('ok', 301), isNotNull);
      expect(pauseMoveError('20 jumping jacks', 10), isNull);
      expect(pauseMoveError('20 jumping jacks', 300), isNull);
    });
  });

  group('counted on Progress', () {
    final clock = DayClock(utcOffset: (_) => Duration.zero);
    final now = DateTime.utc(2026, 10, 12, 15);
    int at(int hour) => DateTime.utc(2026, 10, 12, hour).millisecondsSinceEpoch;

    test('the move kind is read from the log, and counted apart from the ones turned away', () {
      expect(PauseEvent.parse('1700000000000\tmove\tcom.linkedin.android')?.kind, PauseKind.move);
      final days = pauseDays([
        PauseEvent(at(9), PauseKind.shown, 'li'),
        PauseEvent(at(9), PauseKind.move, 'li'),
        PauseEvent(at(10), PauseKind.shown, 'li'),
        PauseEvent(at(10), PauseKind.back, 'li'),
      ], clock, now);
      final today = days.last;
      expect((today.shown, today.move, today.back, today.turnedAway), (2, 1, 1, 1), reason: 'a move ends in opening the app, so it is not turned away');
      expect(pauseWeekLine(days), 'This week the pause came up 2 times; you turned away 1.');
    });
  });
}
