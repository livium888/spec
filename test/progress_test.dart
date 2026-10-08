import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:daily_learning/domain/milestones.dart';
import 'package:daily_learning/domain/streak.dart';
import 'package:daily_learning/presentation/theme/subject_style.dart';
import 'package:daily_learning/presentation/theme/tokens.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Set<int> days(Iterable<int> xs) => xs.toSet();

void main() {
  group('forgiving streak', () {
    test('plain runs, and today not being over yet', () {
      expect(computeStreak({}, 10).current, 0);
      var s = computeStreak(days([8, 9, 10]), 10);
      expect((s.current, s.best, s.activeToday), (3, 3, true));
      s = computeStreak(days([7, 8, 9]), 10); // yesterday was the last study day: still alive
      expect((s.current, s.activeToday, s.restDayProtected), (3, false, false));
    });

    test('one missed day is forgiven after a run of 3+', () {
      final s = computeStreak(days([1, 2, 3, 5, 6]), 6);
      expect(s.current, 5); // five study days; the forgiven day 4 bridges the gap but is not counted
      expect(s.best, 5);
    });

    test('a run shorter than 3 is not protected', () {
      expect(computeStreak(days([1, 2, 4, 5]), 5).current, 2);
    });

    test('a two-day gap breaks it, and best remembers the old run', () {
      final s = computeStreak(days([1, 2, 3, 4, 7, 8]), 8);
      expect(s.current, 2);
      expect(s.best, 4);
    });

    test('rest days are limited to one per 7 active days', () {
      // 1,2,3 | gap | 5,6,7 | gap again too soon | 9
      final s = computeStreak(days([1, 2, 3, 5, 6, 7, 9]), 9);
      expect(s.current, 1);
      // after 7 active days since the last forgiveness it is available again
      final t = computeStreak(days([1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 13]), 13);
      expect(t.current, 11); // 11 study days; both forgiven gaps bridged
    });

    test('yesterday skipped but earned a rest day: streak waits for today', () {
      final s = computeStreak(days([5, 6, 7]), 9);
      expect((s.current, s.restDayProtected, s.activeToday), (3, true, false));
      final gone = computeStreak(days([5, 6, 7]), 10); // two full days missed
      expect(gone.current, 0);
      expect(gone.best, 3);
    });
  });

  test('milestones show progress, and earn at their goal', () {
    final m = milestonesFor(const MilestoneInputs(
        totalReviews: 120, bestStreak: 5, matureCards: 0, subjectsStarted: 2, topicsRevisited: 0));
    Milestone get(String id) => m.firstWhere((x) => x.id == id);
    expect(get('first').earned, isTrue);
    expect(get('rhythm').earned, isTrue);
    expect(get('week').earned, isFalse);
    expect(get('week').fraction, closeTo(5 / 7, 1e-9));
    expect(get('root').progress, 0);
    expect(get('wide').fraction, 0.4);
    expect(m.length, 9);
  });

  test('every subject colour family is readable (AA) in both themes, and neighbours differ', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (var i = 0; i < SubjectStyle.paletteSize; i++) {
        final (strong, tint) = SubjectStyle.pair(i, b);
        expect(contrastRatio(strong, tint), greaterThanOrEqualTo(4.5), reason: '$b #$i');
        final bg = b == Brightness.dark ? AppColors.dark.surface : AppColors.light.surface;
        expect(contrastRatio(strong, bg), greaterThanOrEqualTo(4.5), reason: '$b #$i on surface');
      }
    }
    expect(SubjectStyle.of(1, 'x', Brightness.light).strong, isNot(SubjectStyle.of(2, 'x', Brightness.light).strong));
    expect(SubjectStyle.iconFor('Music'), Icons.music_note_outlined);
    expect(SubjectStyle.iconFor('Money and Investing'), Icons.savings_outlined);
    expect(SubjectStyle.iconFor('Zzz unknown'), isNotNull);
  });

  group('stats from real data', () {
    late AppDatabase db;
    late SettingsRepo settings;
    late ReviewService review;
    final t0 = DateTime.utc(2024, 3, 1, 12);

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      settings = SettingsRepo(db);
      review = ReviewService(db, settings, ParamsRepo(db, settings));
      final imp = ImportService(db);
      final cards = [
        for (var i = 0; i < 6; i++)
          {'type': 'basic', 'front': 'Question $i here?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high'}
      ];
      await imp.commit(await imp.preview(jsonEncode({'domain': 'Bio', 'cards': cards})), now: t0);
    });
    tearDown(() => db.close());

    test('empty history', () async {
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      final s = await StatsService(fresh, SettingsRepo(fresh)).compute(now: t0);
      expect(s.totalCards, 0);
      expect(s.streak.current, 0);
      expect(s.retention30d, isNull);
      expect(s.forecast, [0, 0, 0, 0, 0, 0, 0]);
      expect(s.weekActive, everyElement(isFalse));
    });

    test('counts, maturity, streak, heatmap, forecast and milestones agree with the log', () async {
      final ids = [for (final c in await db.select(db.cards).get()) c.id];
      // Three days in a row, 2 answers a day; one card answered Easy (long interval).
      for (var d = 0; d < 3; d++) {
        final t = t0.add(Duration(days: d));
        await review.review(cardId: ids[d], rating: 3, durationMs: 6000, now: t);
        await review.review(cardId: ids[d + 1 > 5 ? 5 : d + 1], rating: 4, durationMs: 6000, now: t.add(const Duration(minutes: 1)));
      }
      final now = t0.add(const Duration(days: 2, hours: 1));
      final s = await StatsService(db, settings).compute(now: now);

      expect(s.totalCards, 6);
      expect(s.totalReviews, 6);
      expect(s.streak.current, 3);
      expect(s.streak.activeToday, isTrue);
      expect(s.todayAnswered, 2);
      expect(s.todayMinutes, closeTo(0.2, 1e-9));
      expect(s.weekActive.last, isTrue);
      expect(s.weekActive.where((x) => x).length, 3);
      expect(s.activity.values.fold<int>(0, (a, b) => a + b), 6);
      expect(s.newCards + s.learningCards + s.youngCards + s.matureCards, 6);
      expect(s.youngCards, greaterThan(0)); // Easy graduates to review (about 8 days: young, not yet mature)
      expect(s.matureCards, 0);
      expect(s.subjects.single.cards, 6);
      expect(s.forecast.length, 7);
      expect(s.milestones.firstWhere((m) => m.id == 'first').earned, isTrue);
      expect(s.milestones.firstWhere((m) => m.id == 'root').earned, isFalse);

      // A card with a stability of a month counts as mature, and earns the milestone.
      await (db.update(db.cards)..where((c) => c.id.equals(ids[1]))).write(const CardsCompanion(stability: Value(30.0)));
      final s2 = await StatsService(db, settings).compute(now: now);
      expect(s2.matureCards, 1);
      expect(s2.subjects.single.mature, 1);
      expect(s2.milestones.firstWhere((m) => m.id == 'root').earned, isTrue);
    });

    test('revoked answers do not count', () async {
      final id = (await db.select(db.cards).get()).first.id;
      await review.review(cardId: id, rating: 3, durationMs: 1000, now: t0);
      await review.undoLast(now: t0.add(const Duration(minutes: 1)));
      final s = await StatsService(db, settings).compute(now: t0.add(const Duration(minutes: 2)));
      expect(s.totalReviews, 0);
      expect(s.streak.current, 0);
    });
  });
}
