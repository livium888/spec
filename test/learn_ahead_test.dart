import 'package:daily_learning/data/fsrs_scheduler.dart' show fsrs6DefaultWeights;
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/card_memory.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

void main() {
  late Env e;
  final t = DateTime.utc(2025, 5, 1, 9);
  setUp(() async {
    e = Env();
    await e.settings.set(SettingsRepo.newPerDay, '0'); // new cards never fill the queue in these tests
  });
  tearDown(() => e.db.close());

  Future<int> learnOneCard() async {
    await e.addBasic(1, now: t);
    final id = (await e.allCards()).single.id;
    await e.review.review(cardId: id, rating: 3, durationMs: 1000, now: t);
    final c = (await e.allCards()).single;
    expect(c.state, CardState.learning);
    expect(c.due, greaterThan(t.millisecondsSinceEpoch)); // waiting for its step
    return id;
  }

  group('learn-ahead (D40)', () {
    test('a learning card minutes away is offered when nothing else is due, and is not "later"', () async {
      final id = await learnOneCard();
      final q = await e.queue.build(now: t.add(const Duration(minutes: 2)));
      expect(q.learning, isEmpty);
      expect(q.learnAhead.map((c) => c.id), [id]);
      expect(q.ordered.map((c) => c.id), [id]);
      expect(q.nextLearningDue, isNull); // it is being offered now, so there is no "come back at"
    });

    test('switched off with 0; outside the window the card still waits', () async {
      await learnOneCard();
      final at = t.add(const Duration(minutes: 2));
      await e.settings.set(SettingsRepo.learnAheadMinutes, '0');
      var q = await e.queue.build(now: at);
      expect(q.ordered, isEmpty);
      expect(q.nextLearningDue, isNotNull);
      await e.settings.set(SettingsRepo.learnAheadMinutes, '3'); // card is due in ~8 more minutes
      q = await e.queue.build(now: at);
      expect(q.ordered, isEmpty);
      await e.settings.set(SettingsRepo.learnAheadMinutes, '20');
      q = await e.queue.build(now: at);
      expect(q.ordered, hasLength(1));
    });

    test('a card answered less than a minute ago is not shown again at once', () async {
      await learnOneCard();
      final q = await e.queue.build(now: t.add(const Duration(seconds: 30)));
      expect(q.ordered, isEmpty);
      expect(q.nextLearningDue, isNotNull);
    });

    test('other cards come first: learn-ahead is only used when nothing else is due', () async {
      final id = await learnOneCard();
      await e.settings.set(SettingsRepo.newPerDay, '5');
      await e.addBasic(2, domain: 'Chem', now: t);
      final q = await e.queue.build(now: t.add(const Duration(minutes: 2)));
      expect(q.learnAhead, isEmpty);
      expect(q.newCards, hasLength(2));
      expect(q.ordered.map((c) => c.id), isNot(contains(id)));
    });

    test('reviewing a card early keeps replay == live', () async {
      final id = await learnOneCard();
      final at = t.add(const Duration(minutes: 2));
      final q = await e.queue.build(now: at);
      expect(q.next!.id, id);
      await e.review.review(cardId: id, rating: 3, durationMs: 1000, now: at);
      final mism = await e.review.rebuildAll(apply: false);
      expect(mism, isEmpty);
    });
  });

  group('card memory (pure)', () {
    final w = fsrs6DefaultWeights;

    test('state explanations name the learner\'s own steps', () {
      final l = explainState(CardState.learning, learningSteps: const [1, 10]);
      expect(l.title, 'Learning');
      expect(l.body, contains('1 min, then 10 min'));
      expect(explainState(CardState.relearning).title, 'Learning again');
      expect(explainState(CardState.newCard).body, contains('not seen'));
      expect(explainState(CardState.review).body, contains('just before you would probably forget'));
    });

    test('recall is 90% after one stability, and the curve only falls', () {
      final snap = CardSnapshot(
          id: 1, state: CardState.review, due: 0, stability: 10, difficulty: 5, reps: 3, lapses: 0,
          lastReview: DateTime.utc(2025, 1, 1).millisecondsSinceEpoch);
      final m = memoryStats(snap, w, DateTime.utc(2025, 1, 11).millisecondsSinceEpoch);
      expect(m.recallNow, closeTo(0.9, 0.005));
      final curve = forgettingCurve(w, 10, 30);
      expect(curve.first, (0.0, 1.0));
      for (var i = 1; i < curve.length; i++) {
        expect(curve[i].$2, lessThanOrEqualTo(curve[i - 1].$2));
      }
      expect(forgettingCurve(w, 0, 30), isEmpty);
    });

    test('a new card has no model numbers; difficulty and due words read plainly', () {
      final m = memoryStats(CardSnapshot(id: 1, due: 0), w, 1000);
      expect(m.hasModel, isFalse);
      expect(m.recallNow, isNull);
      expect(difficultyWord(2.0), 'Easy for you');
      expect(difficultyWord(5.0), 'Average');
      expect(difficultyWord(8.5), 'Hard for you');
      const day = 86400000;
      expect(dueWords(3 * day, 0), 'in 3 days');
      expect(dueWords(0, 2 * day), '2 days ago');
      expect(dueWords(100, 0), 'now');
    });
  });
}
