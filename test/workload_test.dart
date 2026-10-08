import 'dart:math' as math;

import 'package:daily_learning/data/fsrs_scheduler.dart';
import 'package:daily_learning/domain/fsrs_model.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:daily_learning/domain/scheduler.dart';
import 'package:daily_learning/domain/workload.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 86400000;
final w = fsrs6DefaultWeights;

WorkloadInput input({double newPerDay = 10, int horizon = 730, double retention = 0.9, List<SimCard> existing = const [], double weight = 1, int seed = 1}) =>
    WorkloadInput(
      weights: w,
      existing: existing,
      existingWeight: weight,
      newPerDay: newPerDay,
      newRetention: retention,
      horizonDays: horizon,
      seed: seed,
    );

/// The same learner, but every card goes through the REAL scheduler (learning steps, rounding, the lot).
double realMeanReviews({required double newPerDay, required int days, required int from, int seed = 5, double retention = 0.9}) {
  final rnd = math.Random(seed);
  final sched = DartFsrsScheduler(FsrsConfig(weights: w, desiredRetention: retention, fuzzMinDays: 1 << 30));
  final cards = <CardSnapshot>[];
  var carry = 0.0, id = 0;
  var total = 0.0, counted = 0;
  final start = DateTime.utc(2024, 1, 1, 9);
  // Cards waiting by due day (ms) so each day only touches what is due.
  final byDay = <int, List<int>>{};
  void file(int idx) => (byDay[(cards[idx].due - start.millisecondsSinceEpoch) ~/ _day] ??= []).add(idx);

  for (var d = 0; d < days; d++) {
    final now = start.add(Duration(days: d));
    var reviews = 0;
    carry += newPerDay;
    while (carry >= 1) {
      carry -= 1;
      var c = CardSnapshot(id: id++, due: now.millisecondsSinceEpoch);
      var t = now;
      // First look + learning steps: keep answering Good until it graduates.
      for (var k = 0; k < 4; k++) {
        c = applyRating(sched, c, 3, t);
        reviews++;
        if (c.state == CardState.review) break;
        t = DateTime.fromMillisecondsSinceEpoch(c.due, isUtc: true);
        if (t.difference(now).inHours >= 20) break;
      }
      cards.add(c);
      file(cards.length - 1);
    }
    for (final idx in List<int>.of(byDay[d] ?? const [])) {
      var c = cards[idx];
      var t = now.add(const Duration(hours: 1));
      final dt = (t.millisecondsSinceEpoch - c.lastReview!) ~/ _day;
      final r = retrievability(w, dt.toDouble(), c.stability!);
      int g = 1;
      if (rnd.nextDouble() < r) {
        final u = rnd.nextDouble();
        g = u < kHardShare ? 2 : (u < kHardShare + kGoodShare ? 3 : 4);
      }
      c = applyRating(sched, c, g, t);
      reviews++;
      // Relearning steps after a lapse happen the same day.
      for (var k = 0; k < 3 && c.state != CardState.review; k++) {
        t = DateTime.fromMillisecondsSinceEpoch(c.due, isUtc: true);
        if (t.difference(now).inHours >= 20) break;
        c = applyRating(sched, c, 3, t);
        reviews++;
      }
      cards[idx] = c;
      file(idx);
    }
    byDay.remove(d);
    if (d >= from) {
      total += reviews;
      counted++;
    }
  }
  return total / counted;
}

void main() {
  test('interval at 90% recall is the stability (the definition of stability)', () {
    for (final s in [0.5, 1.0, 3.7, 20.0, 400.0, 2000.0]) {
      expect(intervalDays(w, s, 0.9), math.max(1, s.round()));
    }
    expect(intervalDays(w, 100, 0.8), greaterThan(intervalDays(w, 100, 0.9)));
    expect(intervalDays(w, 1e9, 0.9, maxDays: 36500), 36500);
  });

  test('the forecast matches the real scheduler as ground truth (10 new cards a day, days 600-730)', () {
    final forecast = simulateWorkload(input(newPerDay: 10, horizon: 730));
    final sim = [for (var d = 600; d <= 730; d++) forecast.daily[d]].reduce((a, b) => a + b) / 131;
    final real = realMeanReviews(newPerDay: 10, days: 731, from: 600);
    expect(sim, closeTo(real, real * 0.12), reason: 'forecast $sim vs real scheduler $real reviews/day');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('same story at 80% target recall', () {
    final forecast = simulateWorkload(input(newPerDay: 10, horizon: 500, retention: 0.8));
    final sim = [for (var d = 400; d <= 500; d++) forecast.daily[d]].reduce((a, b) => a + b) / 101;
    final real = realMeanReviews(newPerDay: 10, days: 501, from: 400, retention: 0.8);
    expect(sim, closeTo(real, real * 0.12), reason: 'forecast $sim vs real scheduler $real');
  }, timeout: const Timeout(Duration(minutes: 3)));

  group('behaviour', () {
    test('more new cards a day means more reviews; a lower target recall means fewer', () {
      double at(double n, double r) => simulateWorkload(input(newPerDay: n, horizon: 400, retention: r)).around(380);
      expect(at(20, 0.9), greaterThan(at(10, 0.9) * 1.7));
      expect(at(10, 0.8), lessThan(at(10, 0.9) * 0.85));
      expect(at(0, 0.9), 0);
    });

    test('with no new cards, an old library gets cheaper over time', () {
      final existing = [for (var i = 0; i < 400; i++) SimCard(stability: 30 + (i % 20) * 5.0, difficulty: 5, dueDay: 1 + i % 60, lastDay: -(30 + i % 20), retention: 0.9)];
      final r = simulateWorkload(input(newPerDay: 0, horizon: 1500, existing: existing));
      expect(r.around(1400), lessThan(r.around(60)));
    });

    test('a sampled library counts the same as the whole one (weight), within Monte Carlo noise', () {
      final all = [for (var i = 0; i < 2000; i++) SimCard(stability: 20 + (i % 30) * 4.0, difficulty: 5, dueDay: 1 + i % 40, lastDay: -(20 + i % 30), retention: 0.9)];
      final half = [for (var i = 0; i < all.length; i++) if (i % 2 == 0) all[i]];
      double mean(List<SimCard> c, double wt) {
        var s = 0.0;
        for (final seed in [1, 2, 3, 4, 5, 6]) {
          s += simulateWorkload(input(newPerDay: 0, horizon: 300, existing: c, weight: wt, seed: seed)).around(150, half: 60);
        }
        return s / 6;
      }
      final a = mean(all, 1), b = mean(half, 2);
      expect(b, closeTo(a, a * 0.10));
    });

    test('long horizons with many new cards stay fast and sane (sampling kicks in)', () {
      final sw = Stopwatch()..start();
      final r = simulateWorkload(input(newPerDay: 68, horizon: 3650));
      expect(sw.elapsedMilliseconds, lessThan(8000));
      expect(r.around(3600), greaterThan(r.around(365)));
      expect(r.around(3600).isFinite, isTrue);
    });

    test('deterministic for the same seed', () {
      expect(simulateWorkload(input(horizon: 200)).daily, simulateWorkload(input(horizon: 200)).daily);
    });
  });

  group('plan', () {
    test('sustainable new-cards-per-day: that pace fits the budget and a clearly higher one does not', () {
      final base = input(newPerDay: 10, horizon: 400);
      final n = sustainableNewPerDay(base: base, atDay: 365, budgetMinutes: 20, secondsPerReview: 10);
      expect(n, greaterThan(1));
      double mins(double x) => minutesFor(simulateWorkload(input(newPerDay: x, horizon: 385)).around(365), 10);
      expect(mins(n), lessThanOrEqualTo(20.5));
      expect(mins(n * 1.25), greaterThan(20));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('already over budget with no new cards -> 0, and the advice says what to do', () {
      final existing = [for (var i = 0; i < 3000; i++) SimCard(stability: 3, difficulty: 8, dueDay: 1 + i % 5, lastDay: -3, retention: 0.9)];
      final base = input(newPerDay: 5, horizon: 400, existing: existing, weight: 1);
      expect(sustainableNewPerDay(base: base, atDay: 90, budgetMinutes: 2, secondsPerReview: 10), 0);
    });

    test('advice wording: over budget in about N months, with the 5-year figure and the safe pace', () {
      final r = simulateWorkload(input(newPerDay: 40, horizon: 1900));
      final a = planAdvice(result: r, secondsPerReview: 10, budgetMinutes: 20, newPerDay: 40, sustainableNew: 12.4);
      expect(a.title, startsWith('You will outgrow your time budget in about'));
      expect(a.reasons.join(' '), contains('In 5 years they would take about'));
      expect(a.reasons.join(' '), contains('About 12 new cards a day'));
      final ok = planAdvice(result: simulateWorkload(input(newPerDay: 2, horizon: 400)), secondsPerReview: 10, budgetMinutes: 60, newPerDay: 2);
      expect(ok.title, 'Sustainable at this pace');
    });

    test('table rows only for horizons the simulation covered', () {
      final rows = horizonTable(simulateWorkload(input(horizon: 400)), 10);
      expect(rows.map((r) => r.label), ['in 6 months', 'in 1 year']);
    });
  });
}
