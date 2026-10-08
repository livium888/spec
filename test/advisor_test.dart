import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/learn_planner.dart';
import 'package:daily_learning/domain/study_advisor.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AdviceInput input({
  int due = 0,
  double avg = 12,
  int budget = 20,
  double spent = 0,
  int introduced = 0,
  int limit = 10,
  int upcoming = 0,
  double desired = 0.9,
  double? retention,
  int answers = 0,
  int leeches = 0,
  double? away,
}) =>
    AdviceInput(
      dueToday: due, avgSecondsPerReview: avg, budgetMinutes: budget, spentSecondsToday: spent,
      newIntroducedToday: introduced, newLimit: limit, upcoming7dReviews: upcoming,
      desiredRetention: desired, retention30d: retention, answers30d: answers,
      leechCount: leeches, daysSinceLastSession: away,
    );

const advisor = StudyAdvisor();

void main() {
  group('verdicts and the reasons behind them', () {
    test('fresh start: go, with the binding constraint named', () {
      final a = advisor.advise(input());
      expect(a.level, AdviceLevel.go);
      expect(a.recommendedNewCards, 10);
      expect(a.headline, 'Good time to learn: add up to 10 new cards');
      expect(a.reasons.join(' '), contains('limited by your usual batch size'));
      expect(a.reviewsFirst, isFalse);
    });

    test('reviews due: do them first, then add cards', () {
      final a = advisor.advise(input(due: 30));
      expect(a.level, AdviceLevel.go);
      expect(a.reviewsFirst, isTrue);
      expect(a.headline, startsWith('Do your 30 reviews first'));
      expect(a.reasons.join(' '), contains('30 reviews due'));
    });

    test('limit reached: stop, and say why', () {
      final a = advisor.advise(input(introduced: 10, limit: 10));
      expect(a.level, AdviceLevel.stop);
      expect(a.recommendedNewCards, 0);
      expect(a.reasons.join(' '), contains('limit (10)'));
      expect(a.reasons.join(' '), contains('Tomorrow'));
    });

    test('a limit of zero is explained as a setting or a backlog, not as "no time"', () {
      final a = advisor.advise(input(limit: 0));
      expect(a.level, AdviceLevel.stop);
      expect(a.reasons.first, contains('limit is 0'));
    });

    test('time budget used up with nothing due: stop', () {
      final a = advisor.advise(input(spent: 1300));
      expect(a.level, AdviceLevel.stop);
      expect(a.reasons.first, contains('20-minute budget'));
    });

    test('reviews alone fill the budget: hold off', () {
      final a = advisor.advise(input(due: 100)); // 100 * 12 s = 20 min
      expect(a.level, AdviceLevel.wait);
      expect(a.recommendedNewCards, 0);
      expect(a.reasons.join(' '), contains('nearly your whole'));
    });

    test('forgetting too much: consolidate first', () {
      final a = advisor.advise(input(retention: 0.80, answers: 100));
      expect(a.level, AdviceLevel.wait);
      expect(a.reasons.first, contains('80%'));
      expect(a.reasons.first, contains('90% target'));
    });

    test('slightly behind target: go gently, capped at 5', () {
      final a = advisor.advise(input(retention: 0.86, answers: 100));
      expect(a.level, AdviceLevel.gentle);
      expect(a.recommendedNewCards, 5);
      expect(a.headline, contains('up to 5'));
    });

    test('retention is ignored until there is enough data', () {
      expect(advisor.advise(input(retention: 0.5, answers: 20)).level, AdviceLevel.go);
    });

    test('many leeches or a long absence: go gently', () {
      expect(advisor.advise(input(leeches: 9)).level, AdviceLevel.gentle);
      final away = advisor.advise(input(away: 14));
      expect(away.level, AdviceLevel.gentle);
      expect(away.reasons.first, contains('14 days'));
    });

    test('next week already full: hold off', () {
      final a = advisor.advise(input(upcoming: 600)); // capacity is 560 reviews/week
      expect(a.level, AdviceLevel.wait);
      expect(a.reasons.first, contains('600 reviews'));
    });

    test('too little time left for even a few cards: stop for today', () {
      final a = advisor.advise(input(spent: 1190));
      expect(a.level, AdviceLevel.stop);
      expect(a.reasons.first, contains('min of your budget is left'));
    });

    test('limit shrink and time left both bind the recommendation', () {
      var a = advisor.advise(input(limit: 7, introduced: 3));
      expect(a.recommendedNewCards, 4);
      expect(a.reasons.join(' '), contains("today's new-card limit"));
      a = advisor.advise(input(spent: 1000, budget: 20)); // 200 s left => 5 cards at 36 s each
      expect(a.recommendedNewCards, 5);
      expect(a.reasons.join(' '), contains('time left today'));
    });
  });

  test('properties: never negative, never above the base batch, more load never helps', () {
    for (final due in [0, 10, 50, 90]) {
      for (final up in [0, 100, 300, 500]) {
        for (final spent in [0.0, 300.0, 900.0]) {
          final a = advisor.advise(input(due: due, upcoming: up, spent: spent));
          expect(a.recommendedNewCards, inInclusiveRange(0, 10));
          final more = advisor.advise(input(due: due, upcoming: up + 50, spent: spent));
          expect(more.recommendedNewCards, lessThanOrEqualTo(a.recommendedNewCards),
              reason: 'due $due upcoming $up spent $spent');
          final busier = advisor.advise(input(due: due, upcoming: up, spent: spent + 100));
          expect(busier.recommendedNewCards, lessThanOrEqualTo(a.recommendedNewCards));
        }
      }
    }
  });

  group('from real data (service)', () {
    late AppDatabase db;
    late SettingsRepo settings;
    late LearnService learn;
    late ReviewService review;
    late ImportService imp;
    final t0 = DateTime.utc(2024, 3, 1, 12);

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      settings = SettingsRepo(db);
      learn = LearnService(db, settings, QueueService(db, settings));
      review = ReviewService(db, settings, ParamsRepo(db, settings));
      imp = ImportService(db);
      final out = OutlineService(db);
      await out.commit(await out.preview(jsonEncode({
        'domain': 'Bio',
        'items': [
          {'title': 'A', 'target_cards': 30},
        ],
      })));
    });
    tearDown(() => db.close());

    Future<List<int>> addCards(int n, {DateTime? at}) async {
      final cards = [
        for (var i = 0; i < n; i++)
          {'type': 'basic', 'front': 'Q$i unique?', 'back': 'a', 'source_type': 'quote',
           'supporting_quote': 'q', 'confidence': 'high'}
      ];
      await imp.commit(await imp.preview(jsonEncode({'domain': 'Bio', 'syllabus_item': 'A', 'cards': cards})), now: at ?? t0);
      return [for (final c in await db.select(db.cards).get()) c.id];
    }

    test('fresh database: go', () async {
      final a = await learn.advice(now: t0);
      expect(a.level, AdviceLevel.go);
      expect(a.recommendedNewCards, 10);
    });

    test('after learning today\'s quota of new cards: stop', () async {
      await settings.set(SettingsRepo.newPerDay, '3');
      final ids = await addCards(6);
      for (final id in ids.take(3)) {
        await review.review(cardId: id, rating: 3, durationMs: 8000, now: t0.add(const Duration(minutes: 1)));
      }
      final a = await learn.advice(now: t0.add(const Duration(minutes: 5)));
      expect(a.level, AdviceLevel.stop);
      expect(a.reasons.join(' '), contains('limit (3)'));
    });

    test('a big review backlog: hold off, and say how big', () async {
      await settings.set(SettingsRepo.dailyMinutes, '10');
      final ids = await addCards(80);
      await (db.update(db.cards)).write(CardsCompanion(
          state: const Value('review'), due: Value(t0.millisecondsSinceEpoch - 86400000),
          stability: const Value(5.0), difficulty: const Value(5.0), reps: const Value(3)));
      expect(ids.length, 80);
      final a = await learn.advice(now: t0);
      expect(a.level, AdviceLevel.wait);
      expect(a.reasons.join(' '), contains('80 due reviews'));
      expect(a.reasons.join(' '), contains('more than your whole 10-minute budget'));
    });

    test('poor recent retention: consolidate first', () async {
      final ids = await addCards(60);
      await db.into(db.fsrsParamsTable).insert(FsrsParamsTableCompanion.insert(
          createdAt: 0, version: 'x', paramsJson: '{}', desiredRetention: 0.9));
      // 60 review-state answers in the last 30 days, 30 of them "Again".
      for (var i = 0; i < 60; i++) {
        await db.into(db.reviewLogs).insert(ReviewLogsCompanion.insert(
            cardId: ids[i], reviewedAt: t0.millisecondsSinceEpoch - 86400000,
            rating: i < 30 ? 1 : 3, durationMs: const Value(8000), stateBefore: 'review',
            dueBefore: 0, elapsedDays: 5, scheduledDays: 5, fsrsVersion: 'x', paramsId: 1));
      }
      final a = await learn.advice(now: t0);
      expect(a.level, AdviceLevel.wait);
      expect(a.reasons.first, contains('50%'));
    });

    test('Learn view carries the advice and caps the plan', () async {
      final v = await learn.view(now: t0);
      expect(v.advice.level, AdviceLevel.go);
      expect(v.plan.options.first.action, LearnAction.newItem);
    });
  });
}
