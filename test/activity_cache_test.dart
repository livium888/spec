import 'dart:math';

import 'package:daily_learning/data/activity_cache.dart';
import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

/// Ground truth straight from the log, the slow way the cache replaces.
Future<Map<int, int>> truth(Env e) async {
  final rows = await e.db.customSelect(
      'SELECT reviewed_at / $kBucketMs AS b, COUNT(*) AS n FROM review_log WHERE revoked_at IS NULL GROUP BY b').get();
  return {for (final r in rows) r.read<int>('b'): r.read<int>('n')};
}

Future<Map<int, int>> cached(ActivityCache c) async => {for (final b in await c.buckets()) b.bucket: b.n};

void main() {
  late Env e;
  late ActivityCache cache;
  setUp(() {
    e = Env();
    cache = ActivityCache(e.db, e.settings);
  });

  test('incremental catch-up always equals a full scan, through reviews, undo and more reviews', () async {
    await e.addBasic(6);
    final cards = await e.db.select(e.db.cards).get();
    final rnd = Random(5);
    var now = DateTime.utc(2024, 3, 1, 10);
    for (var round = 0; round < 6; round++) {
      for (var k = 0; k < 15; k++) {
        now = now.add(Duration(minutes: 1 + rnd.nextInt(400)));
        await e.review.review(cardId: cards[rnd.nextInt(cards.length)].id, rating: 1 + rnd.nextInt(4), durationMs: 900, now: now);
      }
      expect(await cached(cache), await truth(e), reason: 'after round $round');
      // Undo after the cache has already counted the row: it must be uncounted.
      await e.review.undoLast(now: now);
      expect(await cached(cache), await truth(e), reason: 'after undo $round');
    }
    expect(await cache.total(), (await truth(e)).values.fold<int>(0, (a, b) => a + b));
  });

  test('deleting a card invalidates the cache, which rebuilds to the truth', () async {
    await e.addBasic(3);
    final cards = await e.db.select(e.db.cards).get();
    for (final c in cards) {
      await e.review.review(cardId: c.id, rating: 3, durationMs: 900, now: DateTime.utc(2024, 3, 1, 11, c.id * 20));
    }
    await cache.catchUp();
    final svc = CardEditService(e.db, e.settings);
    await svc.delete((await svc.search(query: 'number 0')).single.noteId);
    expect(await cached(cache), await truth(e));
    expect(await cache.total(), 2);
  });

  test('an empty or dropped cache rebuilds from the log (migration / safety)', () async {
    await e.addBasic(2);
    for (final c in await e.db.select(e.db.cards).get()) {
      await e.review.review(cardId: c.id, rating: 3, durationMs: 900, now: DateTime.utc(2024, 3, 2, 9, c.id));
    }
    await cache.invalidate();
    expect(await cached(cache), await truth(e));
    await e.db.customStatement('DELETE FROM activity_bucket'); // lost, watermark still set
    await cache.invalidate();
    expect(await cache.total(), 2);
  });

  test('stats numbers are unchanged by the cache (streak, today, total)', () async {
    await e.addBasic(2);
    final cards = await e.db.select(e.db.cards).get();
    final now = DateTime.utc(2024, 3, 5, 12);
    for (var d = 0; d < 4; d++) {
      await e.review.review(cardId: cards.first.id, rating: 3, durationMs: 900, now: now.subtract(Duration(days: d)));
    }
    final s = await StatsService(e.db, e.settings).compute(now: now);
    expect(s.totalReviews, 4);
    expect(s.streak.current, 4);
    expect(s.todayAnswered, 1);
    expect(s.activity.values.fold<int>(0, (a, b) => a + b), 4);
  });
}
