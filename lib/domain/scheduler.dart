import 'models.dart';

/// Swappable scheduling algorithm. Implementations MUST be pure and
/// deterministic: the same (card, rating, now) always yields the same result,
/// otherwise `RebuildCardsFromLog` cannot reproduce live state.
abstract class Scheduler {
  const Scheduler();

  /// Written to `review_log.fsrs_version`.
  String get version;

  SchedResult review(CardSnapshot card, int rating, DateTime nowUtc);

  /// Interval each rating would produce, for the button labels.
  Map<int, Duration> preview(CardSnapshot card, DateTime nowUtc) => {
        for (final r in Rating.all)
          r: Duration(
              milliseconds:
                  review(card, r, nowUtc).due - nowUtc.millisecondsSinceEpoch),
      };
}

/// Builds a [Scheduler] for a stored config (so replay can honour the params
/// that were active when each review happened).
typedef SchedulerFactory = Scheduler Function(FsrsConfig config);

/// The one place a rating is applied to a card. Used by BOTH live review and
/// replay, which is what makes "replay == live" true by construction.
CardSnapshot applyRating(
    Scheduler scheduler, CardSnapshot card, int rating, DateTime nowUtc) {
  final r = scheduler.review(card, rating, nowUtc);
  final lapsed = card.state == CardState.review && rating == Rating.again;
  return CardSnapshot(
    id: card.id,
    state: r.state,
    step: r.step,
    due: r.due,
    stability: r.stability,
    difficulty: r.difficulty,
    reps: card.reps + 1,
    lapses: card.lapses + (lapsed ? 1 : 0),
    lastReview: nowUtc.millisecondsSinceEpoch,
  );
}
