import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/retire_service.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:daily_learning/domain/memory_summary.dart';
import 'package:daily_learning/domain/retire.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// D48: Progress and Today must count the same way and add up.
void main() {
  late AppDatabase db;
  late SettingsRepo settings;
  late ReviewService review;
  late List<int> ids;
  final t0 = DateTime.utc(2024, 3, 1, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepo(db);
    review = ReviewService(db, settings, ParamsRepo(db, settings));
    final imp = ImportService(db);
    final cards = [
      for (var i = 0; i < 14; i++)
        {'type': 'basic', 'front': 'Question number $i here?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high'}
    ];
    await imp.commit(await imp.preview(jsonEncode({'domain': 'Bio', 'cards': cards})), now: t0);
    ids = [for (final c in await db.select(db.cards).get()) c.id];
  });
  tearDown(() => db.close());

  Future<void> setCard(int id, {required String state, double? stability, int? lastReview, bool suspended = false}) =>
      db.customStatement(
          'UPDATE card SET state = ?, stability = ?, last_review = ?, suspended = ?, reps = 8 WHERE id = ?',
          [state, stability, lastReview, suspended ? 1 : 0, id]);

  test('the memory buckets add up to every card, and a retired card stays counted as long-term', () async {
    final now = t0.add(const Duration(days: 200));
    final nowMs = now.millisecondsSinceEpoch;
    // 0: long-term and recent; 1: stable but 200 days overdue (fading); 2: young; 3: learning; 4: paused by hand.
    await setCard(ids[0], state: 'review', stability: 60, lastReview: nowMs - 5 * 86400000);
    await setCard(ids[1], state: 'review', stability: 30, lastReview: nowMs - 200 * 86400000);
    await setCard(ids[2], state: 'review', stability: 5, lastReview: nowMs - 2 * 86400000);
    await setCard(ids[3], state: 'learning', stability: 1, lastReview: nowMs - 60000);
    await setCard(ids[4], state: 'review', stability: 40, lastReview: nowMs - 86400000, suspended: true);
    // 5: retired (mastered by choice) - suspended with retired_at, as RetireService does it.
    await setCard(ids[5], state: 'review', stability: 90, lastReview: nowMs - 100 * 86400000, suspended: true);
    await db.customStatement('UPDATE card SET retired_at = ? WHERE id = ?', [nowMs, ids[5]]);

    final s = await StatsService(db, settings).compute(now: now);
    expect(s.matureCards, 1, reason: 'only the recent stable card is long-term now');
    expect(s.fadingCards, 1);
    expect(s.youngCards, 1);
    expect(s.learningCards, 1);
    expect(s.suspendedCards, 1);
    expect(s.retiredCards, 1);
    expect(s.newCards, 8);
    expect(s.totalCards, 14, reason: 'the bar must add up to every card');
    expect(s.longTermTotal, 2, reason: 'long-term now plus retired');
    final sub = s.subjects.single;
    expect(sub.cards, 13, reason: 'everything but the card paused by hand');
    expect(sub.mature, 2, reason: 'the subject tile agrees with Progress');
  });

  test('retiring a long-term card does not lower the long-term count', () async {
    final now = t0.add(const Duration(days: 30));
    final nowMs = now.millisecondsSinceEpoch;
    for (var k = 0; k < 3; k++) {
      await setCard(ids[k], state: 'review', stability: 800, lastReview: nowMs - 86400000);
    }
    final before = (await StatsService(db, settings).compute(now: now)).longTermTotal;
    expect(before, 3);
    final retire = RetireService(db);
    expect(await retire.retireMastered(const RetireCriteria(years: 2), now: now), 3);
    final s = await StatsService(db, settings).compute(now: now);
    expect(s.retiredCards, 3);
    expect(s.longTermTotal, before);
    expect(s.totalCards, 14);
  });

  test('an overdue stable card falls out of long-term, as the clock moves', () async {
    final base = t0.add(const Duration(days: 10));
    await setCard(ids[0], state: 'review', stability: 30, lastReview: base.millisecondsSinceEpoch);
    final soon = await StatsService(db, settings).compute(now: base.add(const Duration(days: 2)));
    expect(soon.matureCards, 1);
    final late = await StatsService(db, settings).compute(now: base.add(const Duration(days: 90)));
    expect((late.matureCards, late.fadingCards), (0, 1));
    // The achievement ("a card reached a stable memory") is not taken back.
    expect(late.milestones.firstWhere((m) => m.id == 'root').earned, isTrue);
  });

  test('30-day recall counts only cards in normal review, not the easy steps of relearning', () async {
    String log(int card, int at, int rating, String before) =>
        "INSERT INTO review_log (card_id, reviewed_at, rating, duration_ms, state_before, due_before, elapsed_days, scheduled_days, fsrs_version, params_id) "
        "VALUES ($card, $at, $rating, 5000, '$before', $at, 0, 0, 'v', 1)";
    final now = t0.add(const Duration(days: 5));
    final at = now.millisecondsSinceEpoch - 3600000;
    await review.review(cardId: ids[0], rating: 3, durationMs: 1000, now: t0); // makes params row 1
    for (var k = 0; k < 10; k++) {
      db.customStatement(log(ids[1], at + k, k < 5 ? 1 : 3, 'review')); // 5 forgotten, 5 remembered
    }
    for (var k = 0; k < 20; k++) {
      db.customStatement(log(ids[2], at + 100 + k, 3, 'relearning')); // twenty easy relearning steps
    }
    final s = await StatsService(db, settings).compute(now: now);
    expect(s.answers30d, 10);
    expect(s.retention30d, closeTo(0.5, 1e-9));
  });

  test('the weekday follows the 04:00 day: at 02:00 it is still yesterday', () async {
    // 2024-03-05 is a Tuesday. The clock is local; build the instants in local time.
    final tue2am = DateTime(2024, 3, 5, 2).toUtc();
    final tue9am = DateTime(2024, 3, 5, 9).toUtc();
    expect((await StatsService(db, settings).compute(now: tue2am)).todayWeekday, DateTime.monday);
    expect((await StatsService(db, settings).compute(now: tue9am)).todayWeekday, DateTime.tuesday);
  });

  test('Today counts cards, not answers, and paces by the learner\'s own time', () async {
    final now = t0.add(const Duration(minutes: 30));
    for (var k = 0; k < 3; k++) {
      await review.review(cardId: ids[0], rating: 3, durationMs: 4000, now: t0.add(Duration(minutes: k * 2)));
    }
    await review.review(cardId: ids[1], rating: 3, durationMs: 4000, now: t0.add(const Duration(minutes: 8)));
    final s = await StatsService(db, settings).compute(now: now);
    expect(s.todayAnswered, 4);
    expect(s.todayCardIds, {ids[0], ids[1]});
    expect(s.secondsPerCard, 10.0, reason: 'fewer than 20 answers: the default pace');
    for (var k = 0; k < 25; k++) {
      await review.review(cardId: ids[2 + k % 10], rating: 3, durationMs: 6000, now: t0.add(Duration(minutes: 10 + k)));
    }
    final s2 = await StatsService(db, settings).compute(now: t0.add(const Duration(hours: 2)));
    expect(s2.secondsPerCard, closeTo(6000 / 1000, 0.5));
  });

  test('the average recall needs enough learned cards, and is a probability', () async {
    final now = t0.add(const Duration(days: 3));
    final nowMs = now.millisecondsSinceEpoch;
    for (var k = 0; k < 9; k++) {
      await setCard(ids[k], state: 'review', stability: 20, lastReview: nowMs - 86400000);
    }
    expect((await StatsService(db, settings).compute(now: now)).estimatedRecall, isNull);
    await setCard(ids[9], state: 'review', stability: 20, lastReview: nowMs - 86400000);
    final r = (await StatsService(db, settings).compute(now: now)).estimatedRecall!;
    expect(r, inInclusiveRange(0.9, 1.0));
  });

  test('activity span: the first study day to today, never longer than the grid', () async {
    expect((await StatsService(db, settings).compute(now: t0)).activitySpanDays, 0);
    await review.review(cardId: ids[0], rating: 3, durationMs: 1000, now: t0);
    expect((await StatsService(db, settings).compute(now: t0.add(const Duration(days: 4)))).activitySpanDays, 5);
    expect((await StatsService(db, settings).compute(now: t0.add(const Duration(days: 400)))).activitySpanDays, 119);
  });

  test('bucketOf is pure and agrees with the thresholds', () {
    final w = List<double>.filled(21, 0.5)..[20] = 0.1542; // only the shape matters here
    const day = 86400000;
    expect(bucketOf(const MemoryFact(state: 'new'), w, 0), MemoryBucket.fresh);
    expect(bucketOf(const MemoryFact(state: 'review', stability: 5, lastReviewMs: 0), w, day), MemoryBucket.growing);
    expect(bucketOf(const MemoryFact(state: 'review', stability: 30, lastReviewMs: 0, retired: true, suspended: true), w, day), MemoryBucket.retired);
    expect(bucketOf(const MemoryFact(state: 'review', stability: 30, lastReviewMs: 0, suspended: true), w, day), MemoryBucket.paused);
  });
}
