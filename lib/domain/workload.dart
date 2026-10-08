/// "Looking ahead": how many reviews a day the learner's library will cost in the coming
/// months and years. A seeded Monte Carlo over the same memory model the scheduler uses
/// (fsrs_model.dart), so it is pure, deterministic and testable. Hand-set simplifications are
/// listed in docs/DECISIONS.md D28.
library;

import 'dart:math' as math;

import 'fsrs_model.dart';

/// One existing card, as the simulation needs it. Days are relative to today (today = 0).
class SimCard {
  const SimCard({
    required this.stability,
    required this.difficulty,
    required this.dueDay,
    required this.lastDay,
    required this.retention,
  });
  final double stability, difficulty, retention;
  final int dueDay, lastDay;
}

/// Answers given to a card that was recalled (hard / good / easy).
const kHardShare = 0.06, kGoodShare = 0.84; // the rest are "easy"

/// A new card costs this many reviews on the day it is introduced: the first look and one learning
/// step (the default steps are 1 and 10 minutes). Extra "Again" presses while learning are not modelled.
const kNewCardReviews = 2.0;

/// A lapse costs one extra same-day review (the relearning step).
const kLapseExtraReviews = 1.0;

/// Most simulated new cards (sampling keeps long horizons fast).
const kMaxSimulatedNew = 2500;

class WorkloadInput {
  const WorkloadInput({
    required this.weights,
    required this.existing,
    required this.existingWeight,
    required this.newPerDay,
    required this.newRetention,
    required this.horizonDays,
    this.seed = 1,
  });
  final List<double> weights;

  /// A sample of the cards that exist now, and how many real cards each stands for.
  final List<SimCard> existing;
  final double existingWeight;
  final double newPerDay, newRetention;
  final int horizonDays, seed;
}

class WorkloadResult {
  WorkloadResult(this.daily);

  /// Index 0 is unused; index d = expected reviews on day d from today.
  final List<double> daily;
  int get horizon => daily.length - 1;

  /// Mean reviews per day around [day] (a [half]-day window each side, clipped to the horizon).
  double around(int day, {int half = 15}) {
    final a = math.max(1, day - half), b = math.min(horizon, day + half);
    if (b < a) return 0;
    var s = 0.0;
    for (var d = a; d <= b; d++) {
      s += daily[d];
    }
    return s / (b - a + 1);
  }
}

WorkloadResult simulateWorkload(WorkloadInput inp) {
  final w = clampWeights(inp.weights);
  final h = inp.horizonDays;
  final rnd = math.Random(inp.seed);
  final daily = List<double>.filled(h + 1, 0);

  // Card state in parallel arrays; due buckets hold card indexes.
  final stab = <double>[], diff = <double>[], ret = <double>[], wt = <double>[];
  final last = <int>[];
  final buckets = List.generate(h + 2, (_) => <int>[]);

  void schedule(int idx, int day) {
    if (day <= h) buckets[day].add(idx);
  }

  for (var i = 0; i < inp.existing.length; i++) {
    final c = inp.existing[i];
    stab.add(c.stability);
    diff.add(c.difficulty);
    ret.add(c.retention);
    wt.add(inp.existingWeight);
    last.add(c.lastDay);
    // Overdue cards do not all land on one day: spread them over the next two weeks.
    schedule(i, c.dueDay < 1 ? 1 + (i % 14) : c.dueDay);
  }

  final totalNew = inp.newPerDay * h;
  final m = totalNew <= kMaxSimulatedNew ? 1.0 : (totalNew / kMaxSimulatedNew);
  var carry = 0.0;
  // First look (Good), then the learning step the same day, which lifts stability a little.
  final (s1, d1) = firstState(w, 3);
  final (s0, d0) = nextState(w, s1, d1, 0, 3);
  final firstGap = intervalDays(w, s0, inp.newRetention);

  for (var t = 1; t <= h; t++) {
    carry += inp.newPerDay / m;
    while (carry >= 1.0) {
      carry -= 1.0;
      final idx = stab.length;
      stab.add(s0);
      diff.add(d0);
      ret.add(inp.newRetention);
      wt.add(m);
      last.add(t);
      daily[t] += kNewCardReviews * m;
      schedule(idx, t + firstGap);
    }
    final due = buckets[t];
    for (final idx in due) {
      final dt = t - last[idx];
      final r = retrievability(w, dt.toDouble(), stab[idx]);
      int g;
      if (rnd.nextDouble() < r) {
        final u = rnd.nextDouble();
        g = u < kHardShare ? 2 : (u < kHardShare + kGoodShare ? 3 : 4);
        daily[t] += wt[idx];
      } else {
        g = 1;
        daily[t] += wt[idx] * (1 + kLapseExtraReviews);
      }
      final (ns, nd) = nextState(w, stab[idx], diff[idx], dt, g);
      stab[idx] = ns;
      diff[idx] = nd;
      last[idx] = t;
      schedule(idx, t + intervalDays(w, ns, ret[idx]));
    }
    buckets[t] = const []; // free memory as we go
  }
  return WorkloadResult(daily);
}

/// Daily review time in minutes for [reviewsPerDay] at [secondsPerReview].
double minutesFor(double reviewsPerDay, double secondsPerReview) => reviewsPerDay * secondsPerReview / 60.0;

const kHorizons = [(label: 'in 6 months', days: 182), (label: 'in 1 year', days: 365), (label: 'in 2 years', days: 730), (label: 'in 5 years', days: 1825), (label: 'in 10 years', days: 3650)];

class HorizonRow {
  const HorizonRow(this.label, this.days, this.reviewsPerDay, this.minutesPerDay);
  final String label;
  final int days;
  final double reviewsPerDay, minutesPerDay;
}

/// The table the learner sees, from one simulation (horizon = the longest row).
List<HorizonRow> horizonTable(WorkloadResult r, double secondsPerReview) => [
      for (final h in kHorizons)
        if (h.days <= r.horizon)
          HorizonRow(h.label, h.days, r.around(h.days), minutesFor(r.around(h.days), secondsPerReview)),
    ];

/// Biggest new-cards-per-day (0..[maxNew]) whose reviews at [atDay] still fit in [budgetMinutes].
/// Returns 0 when even zero new cards is over budget.
double sustainableNewPerDay({
  required WorkloadInput base,
  required int atDay,
  required double budgetMinutes,
  required double secondsPerReview,
  double maxNew = 150,
}) {
  WorkloadInput with_(double n) => WorkloadInput(
        weights: base.weights,
        existing: base.existing,
        existingWeight: base.existingWeight,
        newPerDay: n,
        newRetention: base.newRetention,
        horizonDays: atDay + 20,
        seed: base.seed,
      );
  bool fits(double n) => minutesFor(simulateWorkload(with_(n)).around(atDay), secondsPerReview) <= budgetMinutes;
  if (!fits(0)) return 0;
  if (fits(maxNew)) return maxNew;
  var lo = 0.0, hi = maxNew;
  for (var i = 0; i < 9; i++) {
    final mid = (lo + hi) / 2;
    if (fits(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

class PlanAdvice {
  const PlanAdvice({required this.title, required this.reasons, this.sustainableNew, this.overBudgetInDays});
  final String title;
  final List<String> reasons;

  /// New cards a day that keep the 5-year reviews within the budget.
  final double? sustainableNew;
  final int? overBudgetInDays;
}

String _span(int days) {
  if (days < 45) return 'about ${(days / 7).round().clamp(1, 6)} weeks';
  if (days < 700) return 'about ${(days / 30).round()} months';
  return 'about ${(days / 365).toStringAsFixed(days < 1500 ? 1 : 0)} years';
}

/// Plain-words reading of the forecast against the learner's daily time budget. Pure.
PlanAdvice planAdvice({
  required WorkloadResult result,
  required double secondsPerReview,
  required double budgetMinutes,
  required double newPerDay,
  double? sustainableNew,
}) {
  int? over;
  for (var d = 30; d <= result.horizon; d += 15) {
    if (minutesFor(result.around(d), secondsPerReview) > budgetMinutes) {
      over = d;
      break;
    }
  }
  final fiveYear = result.horizon >= 1825 ? minutesFor(result.around(1825), secondsPerReview) : null;
  final reasons = <String>[];
  if (over == null) {
    reasons.add('At about ${newPerDay.toStringAsFixed(newPerDay < 10 ? 1 : 0)} new cards a day, reviews stay within your '
        '${budgetMinutes.round()}-minute budget for the whole forecast.');
    return PlanAdvice(title: 'Sustainable at this pace', reasons: reasons, sustainableNew: sustainableNew);
  }
  reasons.add('At about ${newPerDay.toStringAsFixed(newPerDay < 10 ? 1 : 0)} new cards a day, daily reviews pass your '
      '${budgetMinutes.round()}-minute budget in ${_span(over)}.');
  if (fiveYear != null) reasons.add('In 5 years they would take about ${fiveYear.round()} minutes a day.');
  if (sustainableNew != null) {
    reasons.add(sustainableNew < 0.5
        ? 'Even with no new cards your existing library already needs more than your budget; retire mastered cards or lower the target recall.'
        : 'About ${sustainableNew.toStringAsFixed(sustainableNew < 10 ? 1 : 0)} new cards a day keeps you within budget at 5 years.');
  }
  return PlanAdvice(
    title: 'You will outgrow your time budget in ${_span(over)}',
    reasons: reasons,
    sustainableNew: sustainableNew,
    overBudgetInDays: over,
  );
}
