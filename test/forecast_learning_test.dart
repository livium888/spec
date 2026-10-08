import 'package:daily_learning/data/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

void main() {
  test('cards still in their first learning steps are counted as due today in "Coming up"', () async {
    final e = Env();
    await e.addBasic(5);
    final now = DateTime.utc(2025, 3, 3, 10);
    final cards = await e.db.select(e.db.cards).get();
    for (final c in cards.take(3)) {
      await e.review.review(cardId: c.id, rating: 3, durationMs: 800, now: now); // first answer: learning step
    }
    final s = await StatsService(e.db, e.settings).compute(now: now.add(const Duration(minutes: 30)));
    expect(s.learningCards, 3);
    expect(s.forecast[0], 3); // they are due now, so the first bar is not empty
    expect(s.forecast.skip(1).every((n) => n == 0), isTrue);
    await e.db.close();
  });
}
