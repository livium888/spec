import 'dart:math' as math;

import 'package:fsrs/fsrs.dart' as lib;

import '../domain/models.dart';
import '../domain/scheduler.dart';

/// Default FSRS-6 weights from fsrs-rs (`FSRS6_DEFAULT_PARAMETERS`, MIT/BSD
/// licensed upstream; numbers are algorithm constants). Decay w[20] = 0.1542.
///
/// NOTE: the Dart `fsrs` 2.0.1 package ships py-fsrs defaults (w[20] = 0.2),
/// not these. We inject the fsrs-rs defaults so the spec's 0.1542 holds.
const fsrs6DefaultWeights = <double>[
  0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, //
  0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
  0.0912, 0.0658, 0.1542,
];

FsrsConfig defaultFsrsConfig({double desiredRetention = 0.90}) => FsrsConfig(
      weights: fsrs6DefaultWeights,
      desiredRetention: desiredRetention,
    );

/// [Scheduler] backed by the `fsrs` Dart package (MIT). Library fuzzing is
/// disabled; we apply our own *seeded* fuzz so results are reproducible.
class DartFsrsScheduler extends Scheduler {
  DartFsrsScheduler(this.config)
      : _s = lib.Scheduler(
          parameters: config.weights,
          desiredRetention: config.desiredRetention,
          learningSteps: [for (final m in config.learningStepsMin) Duration(minutes: m)],
          relearningSteps: [for (final m in config.relearningStepsMin) Duration(minutes: m)],
          maximumInterval: config.maximumIntervalDays,
          enableFuzzing: false,
        );

  final FsrsConfig config;
  final lib.Scheduler _s;

  static const _dayMs = 86400000;

  @override
  String get version => 'fsrs6/dart-fsrs-2.0.1';

  @override
  SchedResult review(CardSnapshot card, int rating, DateTime nowUtc) {
    assert(nowUtc.isUtc);
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final res = _s.reviewCard(
      _toLib(card),
      lib.Rating.fromValue(rating),
      reviewDateTime: nowUtc,
    );
    final c = res.card;
    var dueMs = c.due.millisecondsSinceEpoch;
    final state = _fromLib(c.state);

    if (state == CardState.review) {
      final days = ((dueMs - nowMs) / _dayMs).round();
      if (days >= config.fuzzMinDays) {
        final fuzzed = _fuzz(days, _seed(card.id, card.reps));
        dueMs = nowMs + fuzzed * _dayMs;
      }
    }

    return SchedResult(
      state: state,
      step: c.step ?? 0,
      due: dueMs,
      stability: c.stability!,
      difficulty: c.difficulty!,
      elapsedDays: card.lastReview == null
          ? 0
          : (nowMs - card.lastReview!) / _dayMs,
      scheduledDays: (dueMs - nowMs) / _dayMs,
    );
  }

  lib.Card _toLib(CardSnapshot c) => lib.Card(
        cardId: c.id,
        state: switch (c.state) {
          CardState.newCard || CardState.learning => lib.State.learning,
          CardState.review => lib.State.review,
          CardState.relearning => lib.State.relearning,
        },
        step: c.state == CardState.review ? null : c.step,
        stability: c.stability,
        difficulty: c.difficulty,
        due: DateTime.fromMillisecondsSinceEpoch(c.due, isUtc: true),
        lastReview: c.lastReview == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(c.lastReview!, isUtc: true),
      );

  CardState _fromLib(lib.State s) => switch (s) {
        lib.State.learning => CardState.learning,
        lib.State.review => CardState.review,
        lib.State.relearning => CardState.relearning,
      };

  // Same fuzz ranges as FSRS reference implementations.
  static const _ranges = [
    (2.5, 7.0, 0.15),
    (7.0, 20.0, 0.10),
    (20.0, double.infinity, 0.05),
  ];

  int _fuzz(int days, int seed) {
    var delta = 1.0;
    for (final (start, end, factor) in _ranges) {
      delta += factor * math.max(math.min(days.toDouble(), end) - start, 0);
    }
    final maxI = math.min((days + delta).round(), config.maximumIntervalDays);
    final minI = math.min(math.max(2, (days - delta).round()), maxI);
    return (minI + (_unit(seed) * (maxI - minI + 1)).floor()).clamp(minI, maxI);
  }

  static int _seed(int cardId, int reps) => cardId * 1000003 + reps;

  /// Deterministic value in [0,1) (splitmix64 finaliser).
  static double _unit(int seed) {
    var z = seed + 0x1E3779B97F4A7C15;
    z = (z ^ (z >>> 30)) * 0x3F58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x14D049BB133111EB;
    z = z ^ (z >>> 31);
    return (z & 0xFFFFFFFFFFFF) / 0x1000000000000;
  }
}

Scheduler dartFsrsFactory(FsrsConfig config) => DartFsrsScheduler(config);
