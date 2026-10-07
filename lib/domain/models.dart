/// Core domain value types. No Flutter / Drift imports allowed here.
library;

enum CardState {
  newCard('new'),
  learning('learning'),
  review('review'),
  relearning('relearning');

  const CardState(this.dbValue);
  final String dbValue;

  static CardState fromDb(String v) =>
      CardState.values.firstWhere((s) => s.dbValue == v);
}

/// Ratings are plain ints 1..4 (Again, Hard, Good, Easy) so they can go
/// straight into `review_log.rating`.
abstract final class Rating {
  static const again = 1;
  static const hard = 2;
  static const good = 3;
  static const easy = 4;
  static const all = [again, hard, good, easy];
}

/// The scheduling fields of a card. This is exactly the "cache" that
/// `RebuildCardsFromLog` can recompute from `review_log`.
class CardSnapshot {
  const CardSnapshot({
    required this.id,
    this.state = CardState.newCard,
    this.step = 0,
    required this.due,
    this.stability,
    this.difficulty,
    this.reps = 0,
    this.lapses = 0,
    this.lastReview,
  });

  final int id;
  final CardState state;
  final int step;

  /// UTC epoch ms.
  final int due;
  final double? stability;
  final double? difficulty;
  final int reps;
  final int lapses;

  /// UTC epoch ms.
  final int? lastReview;

  CardSnapshot copyWith({
    CardState? state,
    int? step,
    int? due,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    int? lastReview,
  }) =>
      CardSnapshot(
        id: id,
        state: state ?? this.state,
        step: step ?? this.step,
        due: due ?? this.due,
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        lastReview: lastReview ?? this.lastReview,
      );

  /// A brand-new card in its pristine scheduling state.
  CardSnapshot reset(int dueMs) => CardSnapshot(id: id, due: dueMs);

  @override
  bool operator ==(Object other) =>
      other is CardSnapshot &&
      other.id == id &&
      other.state == state &&
      other.step == step &&
      other.due == due &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.lastReview == lastReview;

  @override
  int get hashCode => Object.hash(
      id, state, step, due, stability, difficulty, reps, lapses, lastReview);

  @override
  String toString() =>
      'CardSnapshot(id:$id $state step:$step due:$due s:$stability d:$difficulty '
      'reps:$reps lapses:$lapses last:$lastReview)';
}

/// Everything the scheduler reports about one review.
class SchedResult {
  const SchedResult({
    required this.state,
    required this.step,
    required this.due,
    required this.stability,
    required this.difficulty,
    required this.elapsedDays,
    required this.scheduledDays,
  });

  final CardState state;
  final int step;
  final int due;
  final double stability;
  final double difficulty;
  final double elapsedDays;
  final double scheduledDays;
}

/// Serialisable scheduler configuration. Stored in `fsrs_params.params_json`
/// so a replay of the log uses exactly the settings that were live at the time.
class FsrsConfig {
  const FsrsConfig({
    required this.weights,
    this.desiredRetention = 0.90,
    this.learningStepsMin = const [1, 10],
    this.relearningStepsMin = const [10],
    this.maximumIntervalDays = 36500,
    this.fuzzMinDays = 3,
  });

  final List<double> weights;
  final double desiredRetention;
  final List<int> learningStepsMin;
  final List<int> relearningStepsMin;
  final int maximumIntervalDays;

  /// Intervals shorter than this are never fuzzed.
  final int fuzzMinDays;

  Map<String, Object?> toJson() => {
        'w': weights,
        'learning_steps_min': learningStepsMin,
        'relearning_steps_min': relearningStepsMin,
        'max_interval_days': maximumIntervalDays,
        'fuzz_min_days': fuzzMinDays,
      };

  static FsrsConfig fromJson(Map<String, Object?> j, double desiredRetention) =>
      FsrsConfig(
        weights: [for (final w in j['w'] as List) (w as num).toDouble()],
        desiredRetention: desiredRetention,
        learningStepsMin: [for (final s in j['learning_steps_min'] as List) s as int],
        relearningStepsMin: [for (final s in j['relearning_steps_min'] as List) s as int],
        maximumIntervalDays: j['max_interval_days'] as int,
        fuzzMinDays: j['fuzz_min_days'] as int,
      );
}
