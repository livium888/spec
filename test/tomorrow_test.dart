import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:daily_learning/domain/tomorrow_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// D54: tomorrow in full: reviews due, new cards, minutes, and how many more new cards would fit.
TomorrowPlan plan({int due = 17, int still = 0, int newCards = 10, int waiting = 40, int limit = 10, int per = 2, double spa = 10, int budget = 20}) =>
    TomorrowPlan(dueReviews: due, stillDueToday: still, newCards: newCards, newWaiting: waiting, newLimit: limit, answersPerNew: per, secondsPerAnswer: spa, budgetMinutes: budget);

void main() {
  group('the plan', () {
    test('cards, answers and minutes: a new card is answered once per learning step', () {
      final p = plan();
      expect(p.cards, 27);
      expect(p.answers, 17 + 10 * 2);
      expect(p.minutes, closeTo(37 * 10 / 60, 1e-9));
    });

    test('room for more new cards within the study-time budget, or how far over it is', () {
      expect(plan().roomForNew, 41, reason: '(1200 s - 170 s) / 20 s = 51 new cards fit, 10 are planned');
      expect(plan(due: 60, newCards: 10).roomForNew, 30 - 10, reason: '(1200 - 600) / 20 = 30 fit, 10 are planned');
      expect(plan(due: 150, newCards: 10).roomForNew, lessThan(0), reason: 'the reviews alone are over 20 minutes');
      expect(plan(due: 0, newCards: 0, budget: 0).roomForNew, 0);
      expect(plan(spa: 0).roomForNew, 0, reason: 'no pace known: no claim');
    });
  });

  group('from the real data', () {
    late AppDatabase db;
    late SettingsRepo settings;
    final t0 = DateTime.utc(2024, 3, 1, 12);

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      settings = SettingsRepo(db);
      final imp = ImportService(db);
      await imp.commit(
          await imp.preview(jsonEncode({
            'domain': 'Bio',
            'cards': [
              for (var i = 0; i < 20; i++)
                {'type': 'basic', 'front': 'Question number $i here?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high'}
            ]
          })),
          now: t0);
    });
    tearDown(() => db.close());

    Future<void> review(int id, int dueMs) =>
        db.customStatement("UPDATE card SET state = 'review', stability = 5, difficulty = 5, reps = 3, last_review = ?, due = ? WHERE id = ?", [dueMs - 86400000, dueMs, id]);

    test('tomorrow counts reviews due tomorrow, today\'s leftovers apart, and new cards by the daily limit', () async {
      final now = t0.add(const Duration(hours: 3));
      final clock = await settings.dayClock();
      final dayEnd = clock.dayEndMs(now);
      const day = 86400000;
      final ids = [for (final c in await db.select(db.cards).get()) c.id];
      await review(ids[0], dayEnd - 3600000); // still due today
      await review(ids[1], dayEnd - 60000); // still due today
      for (var k = 2; k < 7; k++) {
        await review(ids[k], dayEnd + k * 3600000); // five due tomorrow
      }
      await review(ids[7], dayEnd + day + 3600000); // the day after
      await review(ids[8], dayEnd + 3600000); // due tomorrow, but paused: not counted
      await db.customStatement('UPDATE card SET suspended = 1 WHERE id = ?', [ids[8]]);
      await settings.set(SettingsRepo.newPerDay, '4');
      final s = await StatsService(db, settings).compute(now: now);
      final p = s.tomorrow;
      expect(p.dueReviews, 5);
      expect(p.stillDueToday, 2);
      expect(s.forecast[1], 5, reason: 'the chart and the card say the same number');
      expect(p.newWaiting, 11, reason: '20 cards, 8 now in review or paused, one note each');
      expect(p.newLimit, 4);
      expect(p.newCards, 4);
      expect(p.answersPerNew, 2);
      expect(p.budgetMinutes, 20);
    });

    test('fewer waiting than the limit: only those; the backlog shrink lowers the limit as the queue does', () async {
      final now = t0.add(const Duration(hours: 3));
      final dayEnd = (await settings.dayClock()).dayEndMs(now);
      final ids = [for (final c in await db.select(db.cards).get()) c.id];
      for (var k = 0; k < 17; k++) {
        await review(ids[k], dayEnd + 3600000 + k);
      }
      await settings.set(SettingsRepo.newPerDay, '10');
      var p = (await StatsService(db, settings).compute(now: now)).tomorrow;
      expect((p.newWaiting, p.newCards), (3, 3), reason: 'three new cards are all there is');
      await db.customStatement("UPDATE card SET state = 'review', stability = 5, difficulty = 5, reps = 3, due = ? WHERE state = 'new'", [dayEnd + 86400000 * 3]);
      p = (await StatsService(db, settings).compute(now: now)).tomorrow;
      expect((p.newWaiting, p.newCards), (0, 0));
      await settings.set(SettingsRepo.backlogShrink, '1');
      await settings.set(SettingsRepo.backlogDivisor, '5');
      p = (await StatsService(db, settings).compute(now: now)).tomorrow;
      expect(p.newLimit, 10 - 17 ~/ 5, reason: 'same rule as the queue');
    });
  });
}
