import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// D57: Progress counts what the Today screen will show, by the same rules: one card per note per day (the
/// other gaps of a cloze wait for the next day) and buried cards wait. A learner saw 25 on Today and 37 on Progress.
void main() {
  late AppDatabase db;
  late SettingsRepo settings;
  final t0 = DateTime.utc(2024, 3, 1, 12);
  const day = 86400000;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepo(db);
    await ParamsRepo(db, settings).activeId();
    final imp = ImportService(db);
    await imp.commit(
      await imp.preview(
        jsonEncode({
          'domain': 'Bio',
          'cards': [
            for (var i = 0; i < 6; i++) {'type': 'cloze', 'cloze': 'Fact $i: {{c1::alpha}} and {{c2::beta}} and {{c3::gamma}}.', 'source_type': 'model_memory', 'confidence': 'high'},
            for (var i = 0; i < 6; i++) {'type': 'basic', 'front': 'Question number $i here?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high'},
          ],
        }),
      ),
      now: t0,
    );
  });
  tearDown(() => db.close());

  Future<List<Card>> cards() => (db.select(db.cards)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();

  test('today: Progress says what Today shows (cloze siblings, a buried card, a learning step later today, new cards)', () async {
    final now = t0.add(const Duration(days: 3));
    final nowMs = now.millisecondsSinceEpoch;
    final dayEnd = (await settings.dayClock()).dayEndMs(now);
    final cs = await cards();
    // Every card is a review due an hour ago, except: one basic card is a learning step back in two hours, one is new,
    // and one review is buried until tomorrow (a sibling was answered, or the learner buried it).
    await db.customStatement("UPDATE card SET state = 'review', stability = 5, difficulty = 5, reps = 3, last_review = ?, due = ?", [nowMs - 3 * day, nowMs - 3600000]);
    final basics = [
      for (final c in cs)
        if (cs.where((x) => x.noteId == c.noteId).length == 1) c,
    ];
    expect(basics.length, 6);
    expect(cs.length, 6 * 3 + 6);
    await db.customStatement("UPDATE card SET state = 'learning', due = ? WHERE id = ?", [nowMs + 2 * 3600000, basics[4].id]);
    await db.customStatement("UPDATE card SET state = 'new', due = ?, stability = NULL, difficulty = NULL, reps = 0, last_review = NULL WHERE id = ?", [nowMs, basics[5].id]);
    await db.customStatement('UPDATE card SET buried_until = ? WHERE id = ?', [dayEnd, basics[3].id]);

    final q = await QueueService(db, settings).build(now: now);
    final s = await StatsService(db, settings).compute(now: now);
    expect(q.reviews.length, 6 + 3, reason: 'one card for each cloze note, and the three basic reviews that are not buried');
    final onToday = q.learning.length + q.reviews.length + q.learnAhead.length;
    expect(s.tomorrow.reviewsStillToday, onToday, reason: 'the "due now" line is the Today screen\'s due cards');
    expect(s.tomorrow.learningLaterToday, 1);
    expect(s.forecast[0], onToday + 1);
    expect(s.tomorrow.newStillToday, q.newCards.length);
    expect(s.tomorrow.reviewsStillToday + s.tomorrow.newStillToday, q.ordered.length, reason: 'together: the number on Today');
    expect(s.subjects.fold<int>(0, (a, x) => a + x.dueNow), q.learning.length + q.reviews.length);
    // Tomorrow: the 12 other cloze gaps (one per note, so 6) and the buried card.
    expect(s.forecast[1], 6 + 1);
    expect(s.forecast[2], 6, reason: 'the last gap of each cloze');
    expect(s.forecast.skip(3).every((n) => n == 0), isTrue);
    // Passing the queue Home already built gives the same numbers.
    final s2 = await StatsService(db, settings).compute(now: now, queue: q);
    expect(s2.forecast, s.forecast);
    expect(s2.tomorrow.reviewsStillToday, s.tomorrow.reviewsStillToday);
  });

  test('next morning: what Progress said for tomorrow is what Today shows at 07:00', () async {
    var now = t0.add(const Duration(days: 3));
    final review = ReviewService(db, settings, ParamsRepo(db, settings));
    await db.customStatement("UPDATE card SET state = 'review', stability = 5, difficulty = 5, reps = 3, last_review = ?, due = ?", [
      now.millisecondsSinceEpoch - 3 * day,
      now.millisecondsSinceEpoch - 3600000,
    ]);
    final said = (await StatsService(db, settings).compute(now: now)).forecast;
    expect(said.take(3).toList(), [6 + 6, 6, 6]);
    for (var k = 1; k <= 3; k++) {
      // Finish today exactly as on the phone (answering buries the rest of each note), and keep the answered cards out
      // of the next few days (the forecast assumes today's answers land later than its window).
      final q = await QueueService(db, settings).build(now: now);
      final answered = [for (final c in q.ordered) c.id];
      for (final id in answered) {
        await review.review(cardId: id, rating: 3, durationMs: 4000, now: now);
      }
      await db.customStatement('UPDATE card SET state = \'review\', due = ? WHERE id IN (${answered.join(',')})', [now.millisecondsSinceEpoch + 30 * day]);
      final dayEnd = (await settings.dayClock()).dayEndMs(now);
      now = DateTime.fromMillisecondsSinceEpoch(dayEnd + 3 * 3600000, isUtc: true); // 07:00 the next morning
      final next = await QueueService(db, settings).build(now: now);
      expect(next.learning.length + next.reviews.length, k < 3 ? said[k] : 0, reason: 'day $k: Progress said ${k < 3 ? said[k] : 0}');
    }
  });
}
