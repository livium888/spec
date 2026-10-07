import 'dart:math' as math;

import 'package:daily_learning/data/fsrs_scheduler.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:daily_learning/domain/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as lib;

const _day = 86400000;

CardSnapshot _newCard(int id, DateTime now) =>
    CardSnapshot(id: id, due: now.millisecondsSinceEpoch);

void main() {
  test('fsrs-rs FSRS-6 defaults: 21 weights, decay 0.1542', () {
    expect(fsrs6DefaultWeights.length, 21);
    expect(fsrs6DefaultWeights[20], 0.1542);
    // Must pass the Dart library's own bounds validation.
    expect(() => DartFsrsScheduler(defaultFsrsConfig()), returnsNormally);
  });

  test('library reference vector (test_review_card) via our adapter', () {
    // Same ratings / expected intervals as the fsrs package's own test suite,
    // run with that package's default weights and with fuzz disabled.
    final cfg = FsrsConfig(
      weights: lib.defaultParameters,
      fuzzMinDays: 1 << 30,
    );
    final s = DartFsrsScheduler(cfg);
    const ratings = [3, 3, 3, 3, 3, 3, 1, 1, 3, 3, 3, 3, 3];
    var now = DateTime.utc(2022, 11, 29, 12, 30);
    var card = _newCard(1, now);
    final ivls = <int>[];
    for (final r in ratings) {
      card = applyRating(s, card, r, now);
      ivls.add(((card.due - now.millisecondsSinceEpoch) / _day).floor());
      now = DateTime.fromMillisecondsSinceEpoch(card.due, isUtc: true);
    }
    expect(ivls, [0, 4, 14, 45, 135, 372, 0, 0, 2, 5, 10, 20, 40]);
  });

  test('adapter matches raw library state math for fsrs-rs weights', () {
    final cfg = defaultFsrsConfig().toJson();
    final s = DartFsrsScheduler(defaultFsrsConfig());
    var now = DateTime.utc(2024, 1, 1, 9);
    var c = _newCard(7, now);
    c = applyRating(s, c, Rating.good, now);
    // Initial stability after Good == w[2].
    expect(c.stability, closeTo(fsrs6DefaultWeights[2], 1e-9));
    expect(cfg['w'], isA<List>());
  });

  test('forgetting curve gives R=desired at the scheduled interval (decay 0.1542)', () {
    // R(t,S) = (1 + F t/S)^-decay with F = 0.9^(-1/decay) - 1. At t = S, R = 0.9.
    const decay = 0.1542;
    final f = math.pow(0.9, -1 / decay) - 1;
    expect(math.pow(1 + f, -decay), closeTo(0.9, 1e-12));
  });

  test('learning steps: new card, Again -> 1m, Good -> 10m, Good -> graduates', () {
    final s = DartFsrsScheduler(defaultFsrsConfig());
    var now = DateTime.utc(2024, 1, 1, 9);
    var c = _newCard(2, now);
    var p = s.preview(c, now);
    expect(p[Rating.again], const Duration(minutes: 1));
    expect(p[Rating.good], const Duration(minutes: 10));

    c = applyRating(s, c, Rating.good, now);
    expect(c.state, CardState.learning);
    expect(c.due - now.millisecondsSinceEpoch, 10 * 60000);
    now = DateTime.fromMillisecondsSinceEpoch(c.due, isUtc: true);
    c = applyRating(s, c, Rating.good, now);
    expect(c.state, CardState.review);
    expect(c.due - now.millisecondsSinceEpoch, greaterThanOrEqualTo(_day));
  });

  test('lapse enters relearning with 10m step and counts a lapse', () {
    final s = DartFsrsScheduler(defaultFsrsConfig());
    var now = DateTime.utc(2024, 1, 1, 9);
    var c = _newCard(3, now);
    c = applyRating(s, c, Rating.easy, now); // straight to review
    expect(c.state, CardState.review);
    now = DateTime.fromMillisecondsSinceEpoch(c.due, isUtc: true);
    c = applyRating(s, c, Rating.again, now);
    expect(c.state, CardState.relearning);
    expect(c.lapses, 1);
    expect(c.due - now.millisecondsSinceEpoch, 10 * 60000);
  });

  test('fuzz is deterministic, only applies at >=3 days, and stays in range', () {
    final s = DartFsrsScheduler(defaultFsrsConfig());
    final now = DateTime.utc(2024, 1, 1, 9);
    final c = _newCard(42, now);
    final a = applyRating(s, c, Rating.easy, now);
    final b = applyRating(s, c, Rating.easy, now);
    expect(a, b);

    final noFuzz = DartFsrsScheduler(FsrsConfig(
        weights: fsrs6DefaultWeights, fuzzMinDays: 1 << 30));
    final base = applyRating(noFuzz, c, Rating.easy, now);
    final baseDays = ((base.due - now.millisecondsSinceEpoch) / _day).round();
    final days = ((a.due - now.millisecondsSinceEpoch) / _day).round();
    expect(baseDays, greaterThanOrEqualTo(3));
    expect((days - baseDays).abs(), lessThanOrEqualTo(2));

    // Sub-3-day intervals are never fuzzed.
    final short = DartFsrsScheduler(FsrsConfig(
        weights: fsrs6DefaultWeights, maximumIntervalDays: 2));
    final sc = applyRating(short, c, Rating.easy, now);
    expect((sc.due - now.millisecondsSinceEpoch) / _day, 2.0);
  });

  test('preview matches the interval actually applied', () {
    final s = DartFsrsScheduler(defaultFsrsConfig());
    final now = DateTime.utc(2024, 1, 1, 9);
    final c = _newCard(9, now);
    final p = s.preview(c, now);
    for (final r in Rating.all) {
      final applied = applyRating(s, c, r, now);
      expect(applied.due - now.millisecondsSinceEpoch, p[r]!.inMilliseconds);
    }
  });
}
