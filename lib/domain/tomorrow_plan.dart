/// What tomorrow will ask of the learner, and how much more would fit (D54). Pure Dart.
///
/// Reviews due are a fact (they are scheduled). New cards are a choice made by the daily limit, so they are
/// shown beside the reviews, never mixed into them; each new card is answered more than once while it is
/// learned (once per learning step), which is why minutes count answers, not cards.
class TomorrowPlan {
  const TomorrowPlan({
    required this.dueReviews,
    required this.stillDueToday,
    required this.newCards,
    required this.newWaiting,
    required this.newLimit,
    required this.answersPerNew,
    required this.secondsPerAnswer,
    required this.budgetMinutes,
    this.learningLaterToday = 0,
    this.newStillToday = 0,
    this.problemReviews = 0,
    this.newProblems = 0,
    this.secondsPerProblem = 240,
  });

  /// Of [dueReviews], the problem cards: a problem is worked out on paper, so it is timed on its own pace.
  final int problemReviews;

  /// Problem cards tomorrow may start (up to the daily problem limit, never more than are waiting).
  final int newProblems;
  final double secondsPerProblem;

  /// Reviews scheduled for tomorrow (the app's day, which turns over at 04:00).
  final int dueReviews;

  /// Still to do today (on the Today screen now): reviews due, plus learning steps that come back later today. Anything
  /// left undone is added to tomorrow.
  final int stillDueToday;

  /// Of [stillDueToday], the learning steps that come back after a short wait (not on Today until they are due).
  final int learningLaterToday;

  /// New cards today will introduce (up to what is left of today's limit): they are NOT counted again in [newCards].
  final int newStillToday;

  /// Reviews due today that are on the Today screen now.
  int get reviewsStillToday => stillDueToday - learningLaterToday;

  /// New cards tomorrow would introduce: the daily limit, or fewer if fewer remain once today's are started.
  final int newCards;

  /// New cards left for tomorrow: not started, and not part of today's new cards.
  final int newWaiting;
  final int newLimit;
  final int answersPerNew;
  final double secondsPerAnswer;
  final int budgetMinutes;

  int get cards => dueReviews + newCards + newProblems;

  /// Answers tomorrow, ordinary cards only: each review once, each new card once per learning step.
  int get ordinaryAnswers => (dueReviews - problemReviews) + newCards * answersPerNew;
  int get answers => ordinaryAnswers + problemReviews + newProblems;

  /// Minutes: ordinary answers at the ordinary pace, problems at the problem pace.
  double get minutes => (ordinaryAnswers * secondsPerAnswer + (problemReviews + newProblems) * secondsPerProblem) / 60;

  /// Minutes of the study-time budget left tomorrow (negative: over it).
  double get minutesLeft => budgetMinutes - minutes;
}
