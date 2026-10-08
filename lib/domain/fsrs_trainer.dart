/// Fits the FSRS-6 weights to a learner's review history. Pure and deterministic: the same
/// history, defaults and seed always give the same weights, so it can run in an isolate and be
/// tested. Hand-tuned optimiser settings (see docs/DECISIONS.md D25); the safety net is a
/// held-out check: new weights are only offered if they predict unseen cards better.
library;

import 'dart:math' as math;

import 'fsrs_model.dart';

class TrainRequest {
  const TrainRequest({
    required this.cards,
    required this.start,
    required this.defaults,
    this.seed = 1,
    this.steps = 500,
    this.batchReviews = 4000,
    this.holdoutPercent = 20,
    this.learningRate = 0.025,
  });

  /// All usable cards (each with at least one answer).
  final List<CardSeq> cards;

  /// The weights in use now: the baseline to beat and the starting point.
  final List<double> start;

  /// The built-in defaults the fit is gently pulled towards (more strongly with less data).
  final List<double> defaults;
  final int seed, steps, batchReviews, holdoutPercent;
  final double learningRate;
}

class TrainResult {
  const TrainResult({
    required this.weights,
    required this.trainReviews,
    required this.holdoutReviews,
    required this.holdoutLossBefore,
    required this.holdoutLossAfter,
    required this.holdoutRmseBefore,
    required this.holdoutRmseAfter,
    required this.improved,
    required this.reason,
  });
  final List<double> weights;
  final int trainReviews, holdoutReviews;
  final double holdoutLossBefore, holdoutLossAfter, holdoutRmseBefore, holdoutRmseAfter;

  /// True when the new weights clearly beat the old ones on cards they never saw.
  final bool improved;
  final String reason;

  double get relativeGain =>
      holdoutLossBefore <= 0 ? 0 : (holdoutLossBefore - holdoutLossAfter) / holdoutLossBefore;
}

/// Held-out improvement (relative log-loss) needed before new weights are offered.
const kMinRelativeGain = 0.01;

/// Fewest predictions in the held-out set we accept as evidence.
const kMinHoldoutReviews = 150;

TrainResult trainFsrs(TrainRequest req) {
  final holdout = <CardSeq>[], train = <CardSeq>[];
  for (var i = 0; i < req.cards.length; i++) {
    // Deterministic split by card position: the same cards are always held out.
    final h = _mix(i * 2654435761 + req.seed) % 100;
    (h < req.holdoutPercent ? holdout : train).add(req.cards[i]);
  }
  final start = clampWeights(req.start);
  final (lossBefore, nHold) = meanLogLoss(holdout, start);
  final rmseBefore = evaluate(holdout, start).rmseBins;
  var nTrain = 0;
  for (final c in train) {
    forwardCard(c, start, (_, _) => nTrain++);
  }

  TrainResult keep(String why) => TrainResult(
        weights: start,
        trainReviews: nTrain,
        holdoutReviews: nHold,
        holdoutLossBefore: lossBefore,
        holdoutLossAfter: lossBefore,
        holdoutRmseBefore: rmseBefore,
        holdoutRmseAfter: rmseBefore,
        improved: false,
        reason: why,
      );

  if (nHold < kMinHoldoutReviews) {
    return keep('Not enough reviews on cards held back for checking ($nHold of $kMinHoldoutReviews needed).');
  }
  if (nTrain < 300) return keep('Not enough reviews to fit from.');

  final w = List<double>.of(start);
  final m = List<double>.filled(kWeightCount, 0), v = List<double>.filled(kWeightCount, 0);
  final rnd = math.Random(req.seed);
  final defaults = clampWeights(req.defaults);
  final lambda = 20.0 / nTrain; // less data -> stay closer to the defaults
  const b1 = 0.9, b2 = 0.999, eps = 1e-8;

  double batchLoss(List<CardSeq> batch, List<double> p) {
    final (l, n) = meanLogLoss(batch, p);
    var pen = 0.0;
    for (var j = 0; j < kWeightCount; j++) {
      final s = math.max(defaults[j].abs(), 0.1);
      final d = (p[j] - defaults[j]) / s;
      pen += d * d;
    }
    return (n == 0 ? 0.0 : l) + lambda * pen;
  }

  var best = List<double>.of(w);
  var bestTrain = double.infinity;
  for (var step = 1; step <= req.steps; step++) {
    // Mini-batch of whole cards (seeded), about batchReviews answers.
    final batch = <CardSeq>[];
    var count = 0;
    while (count < req.batchReviews) {
      final c = train[rnd.nextInt(train.length)];
      batch.add(c);
      count += c.length;
      if (batch.length >= train.length) break;
    }
    final base = batchLoss(batch, w);
    final lr = req.learningRate * (0.5 * (1 + math.cos(math.pi * step / req.steps)) * 0.9 + 0.1);
    for (var j = 0; j < kWeightCount; j++) {
      final range = kWeightUpper[j] - kWeightLower[j];
      final h = math.max(1e-4, math.min(0.01 * range, 0.002 * w[j].abs() + 1e-4));
      final keepW = w[j];
      w[j] = math.min(keepW + h, kWeightUpper[j]);
      final step_ = w[j] - keepW;
      final g = step_ == 0 ? 0.0 : (batchLoss(batch, w) - base) / step_;
      w[j] = keepW;
      m[j] = b1 * m[j] + (1 - b1) * g;
      v[j] = b2 * v[j] + (1 - b2) * g * g;
      final mh = m[j] / (1 - math.pow(b1, step));
      final vh = v[j] / (1 - math.pow(b2, step));
      // Scale the step by how big the weight is, so tiny and huge weights both move sensibly.
      final scale = math.max(0.2, math.min(2.0, w[j].abs()));
      w[j] = (w[j] - lr * scale * mh / (math.sqrt(vh) + eps)).clamp(kWeightLower[j], kWeightUpper[j]);
    }
    if (step % 10 == 0 || step == req.steps) {
      final (full, _) = meanLogLoss(train.length > 3000 ? train.sublist(0, 3000) : train, w);
      if (full < bestTrain) {
        bestTrain = full;
        best = List<double>.of(w);
      }
    }
  }

  final fitted = clampWeights(best);
  final (lossAfter, _) = meanLogLoss(holdout, fitted);
  final rmseAfter = evaluate(holdout, fitted).rmseBins;
  final gain = lossBefore <= 0 ? 0.0 : (lossBefore - lossAfter) / lossBefore;
  final ok = gain >= kMinRelativeGain && lossAfter.isFinite;
  return TrainResult(
    weights: ok ? fitted : start,
    trainReviews: nTrain,
    holdoutReviews: nHold,
    holdoutLossBefore: lossBefore,
    holdoutLossAfter: ok ? lossAfter : lossBefore,
    holdoutRmseBefore: rmseBefore,
    holdoutRmseAfter: ok ? rmseAfter : rmseBefore,
    improved: ok,
    reason: ok
        ? 'Predicts cards it never saw ${(gain * 100).toStringAsFixed(1)}% better.'
        : 'Your current settings are already a good fit (the best new weights were only ${(gain * 100).toStringAsFixed(1)}% better; ${(kMinRelativeGain * 100).round()}% is needed).',
  );
}

int _mix(int x) {
  var z = x & 0x7fffffffffffffff;
  z = (z ^ (z >> 30)) * 0x1CE4E5B9;
  z = (z ^ (z >> 27)) * 0x133111EB;
  return (z ^ (z >> 31)) & 0x7fffffff;
}
