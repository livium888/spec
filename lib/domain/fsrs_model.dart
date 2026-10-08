/// FSRS-6 memory model as pure arithmetic, for fitting the 21 weights to a learner's own
/// review history. It mirrors the scheduler's update rules (the `fsrs` package) exactly;
/// test/optimizer_test.dart replays random histories through both and requires equality.
library;

import 'dart:math' as math;
import 'dart:typed_data';

const int kWeightCount = 21;
const double _stabMin = 0.001;

/// Valid range of each weight (the same bounds the scheduler enforces).
const List<double> kWeightLower = [
  0.001, 0.001, 0.001, 0.001, 1.0, 0.001, 0.001, 0.001, 0.0, 0.0, 0.001, //
  0.001, 0.001, 0.001, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.1,
];
const List<double> kWeightUpper = [
  100.0, 100.0, 100.0, 100.0, 10.0, 4.0, 4.0, 0.75, 4.5, 0.8, 3.5, //
  5.0, 0.25, 0.9, 4.0, 1.0, 6.0, 2.0, 2.0, 0.8, 0.8,
];

List<double> clampWeights(List<double> w) =>
    [for (var i = 0; i < kWeightCount; i++) w[i].isNaN ? kWeightLower[i] : w[i].clamp(kWeightLower[i], kWeightUpper[i])];

/// One card's answers in time order. `dts[i]` = whole days since the previous answer
/// (0 for the first answer and for same-day repeats). `ratings` are 1..4.
class CardSeq {
  const CardSeq(this.ratings, this.dts);
  final Uint8List ratings;
  final Int32List dts;
  int get length => ratings.length;
}

/// Running totals of how well predictions matched what happened.
class FitAccumulator {
  FitAccumulator({this.bins = 20});
  final int bins;
  int n = 0;
  double logLossSum = 0;
  late final List<int> binN = List.filled(bins, 0);
  late final List<double> binPred = List.filled(bins, 0);
  late final List<double> binHit = List.filled(bins, 0);
  double predSum = 0, hitSum = 0;

  void add(double r, bool recalled) {
    final p = r.clamp(1e-6, 1 - 1e-6);
    n++;
    logLossSum += recalled ? -math.log(p) : -math.log(1 - p);
    predSum += r;
    if (recalled) hitSum += 1;
    final b = math.min(bins - 1, (r * bins).floor());
    binN[b]++;
    binPred[b] += r;
    if (recalled) binHit[b] += 1;
  }

  double get logLoss => n == 0 ? 0 : logLossSum / n;
  double get meanPredicted => n == 0 ? 0 : predSum / n;
  double get meanActual => n == 0 ? 0 : hitSum / n;

  /// Calibration error: how far predictions are from reality, averaged over probability
  /// bins and weighted by how many reviews fall in each (RMSE-bins, lower is better).
  double get rmseBins {
    if (n == 0) return 0;
    var s = 0.0;
    for (var b = 0; b < bins; b++) {
      if (binN[b] == 0) continue;
      final d = binPred[b] / binN[b] - binHit[b] / binN[b];
      s += binN[b] * d * d;
    }
    return math.sqrt(s / n);
  }
}

/// Forward pass over one card with weights [w]. Calls [onPrediction] with (predicted
/// recall, recalled?) for every answer that follows at least one full day of delay.
void forwardCard(CardSeq s, List<double> w, void Function(double r, bool recalled) onPrediction,
    {void Function(int i, double stability, double difficulty)? onState}) {
  final decay = -w[20];
  final factor = math.pow(0.9, 1 / decay) - 1;
  final d0Easy = _clampD(w[4] - math.exp(w[5] * 3) + 1);
  double stab = 0, diff = 0;
  for (var i = 0; i < s.length; i++) {
    final g = s.ratings[i];
    if (i == 0) {
      stab = math.max(w[g - 1], _stabMin);
      diff = _clampD(w[4] - math.exp(w[5] * (g - 1)) + 1);
      onState?.call(i, stab, diff);
      continue;
    }
    final dt = s.dts[i];
    if (dt < 1) {
      var inc = math.exp(w[17] * (g - 3 + w[18])) * math.pow(stab, -w[19]);
      if (g >= 3) inc = math.max(inc, 1.0);
      stab = math.max(stab * inc, _stabMin);
    } else {
      final r = math.pow(1 + factor * dt / stab, decay).toDouble();
      onPrediction(r, g > 1);
      double next;
      if (g == 1) {
        final longTerm = w[11] * math.pow(diff, -w[12]) * (math.pow(stab + 1, w[13]) - 1) * math.exp((1 - r) * w[14]);
        final shortTerm = stab / math.exp(w[17] * w[18]);
        next = math.min(longTerm, shortTerm);
      } else {
        final hard = g == 2 ? w[15] : 1.0;
        final easy = g == 4 ? w[16] : 1.0;
        next = stab *
            (1 + math.exp(w[8]) * (11 - diff) * math.pow(stab, -w[9]) * (math.exp((1 - r) * w[10]) - 1) * hard * easy);
      }
      stab = math.max(next, _stabMin);
    }
    final delta = -(w[6] * (g - 3));
    final damped = diff + (10.0 - diff) * delta / 9.0;
    diff = _clampD(w[7] * d0Easy + (1 - w[7]) * damped);
    onState?.call(i, stab, diff);
  }
}

double _clampD(double d) => d < 1.0 ? 1.0 : (d > 10.0 ? 10.0 : d);

/// Fit of weights [w] on [cards].
FitAccumulator evaluate(List<CardSeq> cards, List<double> w) {
  final acc = FitAccumulator();
  for (final c in cards) {
    forwardCard(c, w, acc.add);
  }
  return acc;
}

/// Mean log-loss of [w] on [cards] (and the prediction count).
(double, int) meanLogLoss(List<CardSeq> cards, List<double> w) {
  var sum = 0.0;
  var n = 0;
  for (final c in cards) {
    forwardCard(c, w, (r, y) {
      final p = r.clamp(1e-6, 1 - 1e-6);
      sum += y ? -math.log(p) : -math.log(1 - p);
      n++;
    });
  }
  return (n == 0 ? 0.0 : sum / n, n);
}
