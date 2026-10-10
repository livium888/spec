/// Where each card stands in the learner's memory, in one place, so Today, Progress and the subject tiles
/// count the same way (D48). Pure Dart.
library;

import 'fsrs_model.dart' show retrievability;

/// A review card counts as "long-term" once its stability reaches this many days (FSRS: the days after which
/// the chance of recall falls to 90%) AND the model still gives at least [kLongTermRecall] chance of recall now.
const kLongTermStability = 21.0;
const kLongTermRecall = 0.90;

/// Fewer learned cards than this: the average recall is not shown (too few to mean anything).
const kMinCardsForEstimate = 10;

enum MemoryBucket { fresh, learning, growing, fading, longTerm, retired, paused }

/// What the database says about one card.
class MemoryFact {
  const MemoryFact({required this.state, this.stability, this.lastReviewMs, this.suspended = false, this.retired = false});
  final String state; // new | learning | review | relearning
  final double? stability;
  final int? lastReviewMs;
  final bool suspended, retired;
}

/// Chance of recalling the card at [nowMs] (0 when it has no memory trace yet).
double recallNow(MemoryFact c, List<double> weights, int nowMs) {
  final s = c.stability;
  final last = c.lastReviewMs;
  if (c.state == 'new' || s == null || s <= 0 || last == null || weights.length <= 20) return 0;
  final days = ((nowMs - last) / 86400000).clamp(0.0, 100000.0);
  return retrievability(weights, days, s).clamp(0.0, 1.0);
}

/// Retired cards are mastered by the learner's own choice and stay counted; cards put aside by hand are
/// "paused"; pass [recall] when it is already known, to skip computing it twice. A stable card that is now overdue is "fading", not long-term.
MemoryBucket bucketOf(MemoryFact c, List<double> weights, int nowMs, {double? recall}) {
  if (c.retired) return MemoryBucket.retired;
  if (c.suspended) return MemoryBucket.paused;
  switch (c.state) {
    case 'new':
      return MemoryBucket.fresh;
    case 'learning':
    case 'relearning':
      return MemoryBucket.learning;
    default:
      if ((c.stability ?? 0) < kLongTermStability) return MemoryBucket.growing;
      return (recall ?? recallNow(c, weights, nowMs)) >= kLongTermRecall ? MemoryBucket.longTerm : MemoryBucket.fading;
  }
}

/// The words for where a card stands: ONE set, used by every screen (D52).
extension MemoryBucketWords on MemoryBucket {
  String get label => switch (this) {
        MemoryBucket.fresh => 'New',
        MemoryBucket.learning => 'Learning',
        MemoryBucket.growing => 'Growing',
        MemoryBucket.fading => 'Fading',
        MemoryBucket.longTerm => 'Long-term',
        MemoryBucket.retired => 'Retired',
        MemoryBucket.paused => 'Paused',
      };

  /// One sentence, in the same words everywhere.
  String get meaning => switch (this) {
        MemoryBucket.fresh => 'Not answered yet.',
        MemoryBucket.learning => 'In its first short steps, or back on them after you forgot it.',
        MemoryBucket.growing => 'You know it, and the gaps between reviews are getting longer (stable for under three weeks).',
        MemoryBucket.fading => 'It was long-term, but it is overdue and your chance of recalling it is dropping.',
        MemoryBucket.longTerm => 'Stable for three weeks or more, and still at least 90% likely to be recalled now.',
        MemoryBucket.retired => 'Mastered and put away by you. It stays counted as long-term.',
        MemoryBucket.paused => 'Put aside by you. It will not appear until you bring it back.',
      };
}
