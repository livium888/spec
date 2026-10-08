import 'dart:math' as math;
import 'dart:typed_data';

import 'package:daily_learning/data/fsrs_scheduler.dart';
import 'package:daily_learning/domain/fsrs_model.dart';
import 'package:daily_learning/domain/fsrs_trainer.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:daily_learning/domain/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as lib;

const _day = 86400000;

/// A learner simulated with the scheduler under weights [truth]: answers are recalled with
/// the model's own probability. Returns the log as sequences, like the app extracts them.
List<CardSeq> simulate(List<double> truth, {int cards = 300, int reviews = 22, int seed = 4}) {
  final rnd = math.Random(seed);
  final sched = DartFsrsScheduler(FsrsConfig(weights: truth, desiredRetention: 0.9));
  final decay = -truth[20];
  final factor = math.pow(0.9, 1 / decay) - 1;
  final out = <CardSeq>[];
  for (var c = 0; c < cards; c++) {
    var card = CardSnapshot(id: c, due: 0);
    var t = DateTime.utc(2024, 1, 1, 9);
    final ratings = <int>[], dts = <int>[];
    int? last;
    for (var i = 0; i < reviews; i++) {
      final dt = last == null ? 0 : (t.millisecondsSinceEpoch - last) ~/ _day;
      int g;
      if (card.stability == null || dt < 1) {
        g = 3;
      } else {
        final r = math.pow(1 + factor * dt / card.stability!, decay).toDouble();
        if (rnd.nextDouble() > r) {
          g = 1;
        } else {
          final u = rnd.nextDouble();
          g = u < 0.12 ? 2 : (u < 0.85 ? 3 : 4);
        }
      }
      ratings.add(g);
      dts.add(dt);
      last = t.millisecondsSinceEpoch;
      card = applyRating(sched, card, g, t);
      // Next review when the scheduler says (at least a day later, with a little lateness).
      final dueMs = card.due;
      final next = DateTime.fromMillisecondsSinceEpoch(dueMs, isUtc: true).add(Duration(hours: rnd.nextInt(30)));
      // Occasionally a same-day relearning repeat after a lapse.
      t = (g == 1 && rnd.nextBool()) ? t.add(const Duration(minutes: 12)) : next;
    }
    out.add(CardSeq(Uint8List.fromList(ratings), Int32List.fromList(dts)));
  }
  return out;
}

void main() {
  test('bounds match the scheduler library', () {
    expect(kWeightLower, lib.lowerBoundsParameters);
    expect(kWeightUpper, lib.upperBoundsParameters);
  });

  test('the training model reproduces the scheduler exactly (stability and difficulty after every answer)', () {
    final rnd = math.Random(11);
    for (var trial = 0; trial < 40; trial++) {
      // Random but valid weights, so every formula is exercised away from the defaults.
      final w = [
        for (var j = 0; j < kWeightCount; j++)
          j < 4 ? 0.2 + rnd.nextDouble() * 12 : kWeightLower[j] + (kWeightUpper[j] - kWeightLower[j]) * (0.15 + 0.7 * rnd.nextDouble())
      ];
      final sched = DartFsrsScheduler(FsrsConfig(weights: w, desiredRetention: 0.9));
      var card = CardSnapshot(id: 1, due: 0);
      var t = DateTime.utc(2024, 1, 1, 8);
      final ratings = <int>[], dts = <int>[];
      final liveS = <double>[], liveD = <double>[];
      int? last;
      for (var i = 0; i < 30; i++) {
        final gaps = [5, 40, 9 * 60, 26 * 60, 3 * 24 * 60, 40 * 24 * 60, 200 * 24 * 60];
        if (i > 0) t = t.add(Duration(minutes: gaps[rnd.nextInt(gaps.length)] + rnd.nextInt(30)));
        final g = 1 + rnd.nextInt(4);
        ratings.add(g);
        dts.add(last == null ? 0 : (t.millisecondsSinceEpoch - last) ~/ _day);
        last = t.millisecondsSinceEpoch;
        card = applyRating(sched, card, g, t);
        liveS.add(card.stability!);
        liveD.add(card.difficulty!);
      }
      final modelS = <double>[], modelD = <double>[];
      forwardCard(CardSeq(Uint8List.fromList(ratings), Int32List.fromList(dts)), w, (_, _) {},
          onState: (i, s, d) {
        modelS.add(s);
        modelD.add(d);
      });
      expect(modelS.length, 30);
      for (var i = 0; i < 30; i++) {
        expect(modelS[i], closeTo(liveS[i], 1e-9 * math.max(1, liveS[i])), reason: 'trial $trial step $i stability');
        expect(modelD[i], closeTo(liveD[i], 1e-9), reason: 'trial $trial step $i difficulty');
      }
    }
  });

  group('trainer', () {
    final truth = List<double>.of(fsrs6DefaultWeights)
      ..[2] = 5.0 // a learner who remembers new cards much better than average
      ..[8] = 1.2
      ..[20] = 0.30; // and a steeper forgetting curve

    test('fits a learner who differs from the defaults, and says it is better on unseen cards', () {
      final cards = simulate(truth);
      final r = trainFsrs(TrainRequest(cards: cards, start: fsrs6DefaultWeights, defaults: fsrs6DefaultWeights, steps: 300));
      expect(r.improved, isTrue, reason: r.reason);
      expect(r.holdoutLossAfter, lessThan(r.holdoutLossBefore));
      expect(r.relativeGain, greaterThanOrEqualTo(kMinRelativeGain));
      expect(r.holdoutReviews, greaterThan(kMinHoldoutReviews));
      // On a brand-new learner history (never seen in training) the fitted weights close at least
      // half the gap between the defaults and the true weights. (Individual weights are not
      // uniquely identifiable, e.g. decay trades off against stability, so predictions are judged, not weights.)
      final fresh = simulate(truth, seed: 77);
      final (lDefault, _) = meanLogLoss(fresh, fsrs6DefaultWeights);
      final (lFit, _) = meanLogLoss(fresh, r.weights);
      final (lTruth, _) = meanLogLoss(fresh, truth);
      expect(lDefault - lTruth, greaterThan(0.01), reason: 'the test learner must differ from the defaults');
      expect(lDefault - lFit, greaterThan(0.5 * (lDefault - lTruth)), reason: 'default $lDefault fit $lFit truth $lTruth');
      // Valid for the scheduler.
      for (var j = 0; j < kWeightCount; j++) {
        expect(r.weights[j], inInclusiveRange(kWeightLower[j], kWeightUpper[j]));
      }
      DartFsrsScheduler(FsrsConfig(weights: r.weights, desiredRetention: 0.9)); // does not throw
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('data that already match the defaults: nothing is offered, weights unchanged', () {
      final cards = simulate(fsrs6DefaultWeights, seed: 9);
      final r = trainFsrs(TrainRequest(cards: cards, start: fsrs6DefaultWeights, defaults: fsrs6DefaultWeights, steps: 80));
      expect(r.improved, isFalse, reason: 'gain ${r.relativeGain}');
      expect(r.weights, fsrs6DefaultWeights);
      expect(r.reason, contains('already a good fit'));
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('too little history is refused, not guessed', () {
      final r = trainFsrs(TrainRequest(cards: simulate(truth, cards: 8, reviews: 6), start: fsrs6DefaultWeights, defaults: fsrs6DefaultWeights));
      expect(r.improved, isFalse);
      expect(r.weights, fsrs6DefaultWeights);
    });

    test('same history and seed give identical weights', () {
      final cards = simulate(truth, cards: 120, reviews: 14, seed: 2);
      TrainResult run() => trainFsrs(TrainRequest(cards: cards, start: fsrs6DefaultWeights, defaults: fsrs6DefaultWeights, steps: 25));
      expect(run().weights, run().weights);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
