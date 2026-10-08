import 'package:daily_learning/data/fsrs_scheduler.dart';
import 'package:daily_learning/data/optimizer_service.dart';
import 'package:daily_learning/domain/fsrs_trainer.dart';
import 'package:daily_learning/domain/optimizer_advice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

const adv = OptimizerAdvisor();
const day = 86400000;

OptimizerAdviceInput input(int usable,
        {double pace = 50, OptimizerSnapshot? last, int daysSince = 0, double? pred, double? act, int sample = 0}) =>
    OptimizerAdviceInput(
      usableReviews: usable,
      reviewsPerDay: pace,
      nowMs: 1000 * day,
      last: last == null ? null : OptimizerSnapshot(atMs: 1000 * day - daysSince * day, usableThen: last.usableThen, applied: last.applied),
      predictedRecall: pred,
      actualRecall: act,
      sample: sample,
    );

void main() {
  group('when to fit (pure advice)', () {
    test('first time, too early: says how many more reviews and roughly how many days, and why', () {
      final a = adv.advise(input(400, pace: 20));
      expect(a.ready, isFalse);
      expect(a.moreReviews, 600);
      expect(a.inDays, 30);
      expect(a.title, contains('600 more reviews'));
      expect(a.title, contains('30 days'));
      expect(a.reasons.join(' '), contains('noise'));
    });

    test('first time, enough history: ready now, with the reason', () {
      final a = adv.advise(input(1000));
      expect(a.ready, isTrue);
      expect(a.title, 'Ready now');
      expect(a.reasons.first, contains('1000 usable reviews'));
    });

    test('estimates are labelled as estimates', () {
      final a = adv.advise(const OptimizerAdviceInput(usableReviews: 300, reviewsPerDay: 0, nowMs: 0, estimated: true));
      expect(a.title, contains('roughly'));
      expect(a.title, contains('no estimate yet')); // no pace known: no invented day count
      expect(a.inDays, isNull);
    });

    const was = OptimizerSnapshot(atMs: 0, usableThen: 2000, applied: true);

    test('after a fit: time is the missing piece -> "in N days"', () {
      final a = adv.advise(input(2300, last: was, daysSince: 10));
      expect(a.ready, isFalse);
      expect(a.title, 'In 20 days');
      expect(a.reasons.join(' '), contains('chases noise'));
    });

    test('after a fit: reviews are the missing piece -> "in about N more reviews"', () {
      final a = adv.advise(input(2100, last: was, daysSince: 25, pace: 50));
      expect(a.ready, isFalse);
      expect(a.title, startsWith('In about 900 more reviews'));
      expect(a.title, contains('18 days'));
      expect(a.moreReviews, 900);
    });

    test('after a fit: enough of both -> ready again', () {
      final a = adv.advise(input(3100, last: was, daysSince: 40));
      expect(a.ready, isTrue);
      expect(a.title, 'Ready again');
    });

    test('a big gap between what the model expects and what happens brings the next fit forward, with the reason', () {
      final a = adv.advise(input(2100, last: was, daysSince: 20, pred: 0.90, act: 0.84, sample: 500));
      expect(a.ready, isTrue);
      expect(a.reasons.join(' '), contains('expected you to remember 90%'));
      expect(a.reasons.join(' '), contains('too ambitious'));
      final soon = adv.advise(input(2100, last: was, daysSince: 5, pred: 0.90, act: 0.84, sample: 500));
      expect(soon.ready, isFalse); // never twice in a week
      final tiny = adv.advise(input(2100, last: was, daysSince: 20, pred: 0.90, act: 0.84, sample: 100));
      expect(tiny.ready, isFalse); // too few reviews to trust the gap
    });

    test('a check that kept the old weights is described as such', () {
      final a = adv.advise(input(2100, last: const OptimizerSnapshot(atMs: 0, usableThen: 2000, applied: false), daysSince: 3));
      expect(a.reasons.first, contains('already a good fit'));
    });
  });

  group('OptimizerService', () {
    late Env e;
    late OptimizerService svc;
    Future<TrainResult> fast(TrainRequest r) async => trainFsrs(TrainRequest(
        cards: r.cards, start: r.start, defaults: r.defaults, steps: 30, batchReviews: 1500));

    setUp(() {
      e = Env();
      svc = OptimizerService(e.db, e.settings, e.params, runner: fast);
    });

    /// 120 cards x 13 answers over a year: about 1,400 usable reviews.
    Future<void> history() async {
      await e.addBasic(120);
      final cards = await e.db.select(e.db.cards).get();
      final start = DateTime.utc(2024, 1, 2, 9);
      const gaps = [0, 1, 3, 7, 14, 30, 45, 60, 80, 100, 120, 150];
      for (final c in cards) {
        var t = start.add(Duration(minutes: c.id));
        await e.review.review(cardId: c.id, rating: 3, durationMs: 800, now: t);
        for (var i = 0; i < gaps.length; i++) {
          t = start.add(Duration(days: gaps[i] + 1, minutes: c.id));
          await e.review.review(cardId: c.id, rating: (c.id + i) % 7 == 0 ? 1 : 3, durationMs: 800, now: t);
        }
      }
    }

    test('a new learner is told it is too early, with a count', () async {
      final s = await svc.status(now: DateTime.utc(2024, 2, 1));
      expect(s.advice.ready, isFalse);
      expect(s.usableReviews, 0);
      expect(s.personalised, isFalse);
    });

    test('fit -> apply puts new weights in use from now on and replay == live still holds', () async {
      await history();
      final now = DateTime.utc(2025, 3, 1);
      final s = await svc.status(now: now);
      expect(s.usableReviews, greaterThan(1000));
      expect(s.advice.ready, isTrue, reason: s.advice.title);
      expect(s.sample, greaterThan(1000));

      final r = await svc.optimise();
      expect(r.holdoutReviews, greaterThan(kMinHoldoutReviews));

      // Force a visibly different set of weights so the property is exercised either way.
      final changed = TrainResult(
        weights: [...fsrs6DefaultWeights]..[20] = 0.25..[8] = 1.4,
        trainReviews: r.trainReviews,
        holdoutReviews: r.holdoutReviews,
        holdoutLossBefore: r.holdoutLossBefore,
        holdoutLossAfter: r.holdoutLossBefore * 0.98,
        holdoutRmseBefore: r.holdoutRmseBefore,
        holdoutRmseAfter: r.holdoutRmseBefore,
        improved: true,
        reason: 'test',
      );
      final before = await e.params.activeId();
      await svc.apply(changed, now: now);
      final after = await e.params.activeId();
      expect(after, isNot(before));
      expect(await e.params.activeWeights(), changed.weights);
      expect((await svc.status(now: now)).personalised, isTrue);

      // Old reviews still replay under the weights they were made with...
      expect(await e.review.rebuildAll(apply: false), isEmpty);
      // ...and a new review under the new weights replays too.
      final card = (await e.db.select(e.db.cards).get()).first;
      await e.review.review(cardId: card.id, rating: 3, durationMs: 800, now: DateTime.utc(2025, 3, 2));
      expect(await e.review.rebuildAll(apply: false), isEmpty);
      final last = (await e.db.select(e.db.reviewLogs).get()).last;
      expect(last.paramsId, after);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('keeping the current weights is remembered, and the next advice counts from that day', () async {
      await history();
      final now = DateTime.utc(2025, 3, 1);
      final r = await svc.optimise();
      await svc.keep(r, now: now);
      final s = await svc.status(now: now.add(const Duration(days: 3)));
      expect(s.advice.ready, isFalse);
      expect(s.advice.reasons.first, contains('3 days ago'));
      expect(s.advice.reasons.first, contains('already a good fit'));
      expect(await e.params.activeWeights(), fsrs6DefaultWeights); // nothing changed
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('reset goes back to the defaults for new reviews and forgets the fit', () async {
      await e.addBasic(1);
      await svc.params.useWeights([...fsrs6DefaultWeights]..[20] = 0.3);
      expect((await svc.status()).personalised, isTrue);
      await svc.resetToDefaults();
      expect((await svc.status()).personalised, isFalse);
      expect(await svc.lastRun(), isNull);
    });

    test('Today-screen advice never reads the history and says it is an estimate', () async {
      final a = await svc.quickAdvice(now: DateTime.utc(2025, 1, 1));
      expect(a.ready, isFalse);
      expect(a.title, contains('roughly'));
    });

    test('banner can be snoozed', () async {
      final t = DateTime.utc(2025, 1, 1);
      expect(await svc.bannerSnoozed(now: t), isFalse);
      await svc.snoozeBanner(const Duration(days: 14), now: t);
      expect(await svc.bannerSnoozed(now: t.add(const Duration(days: 13))), isTrue);
      expect(await svc.bannerSnoozed(now: t.add(const Duration(days: 15))), isFalse);
    });
  });
}
