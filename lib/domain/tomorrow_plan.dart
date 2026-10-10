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
  });

  /// Reviews scheduled for tomorrow (the app's day, which turns over at 04:00).
  final int dueReviews;

  /// Reviews still due today: if they are left, tomorrow's session starts with them too.
  final int stillDueToday;

  /// New cards tomorrow would introduce: the daily limit, or fewer if fewer are waiting.
  final int newCards;

  /// New cards in the library that have not been started.
  final int newWaiting;
  final int newLimit;
  final int answersPerNew;
  final double secondsPerAnswer;
  final int budgetMinutes;

  int get cards => dueReviews + newCards;

  /// Answers tomorrow: each review once, each new card once per learning step.
  int get answers => dueReviews + newCards * answersPerNew;
  double get minutes => answers * secondsPerAnswer / 60;

  /// How many MORE new cards a day would still fit in the study-time budget; negative when tomorrow is already
  /// over it (by that many new cards).
  int get roomForNew {
    if (secondsPerAnswer <= 0 || answersPerNew <= 0) return 0;
    final fitNew = ((budgetMinutes * 60 - dueReviews * secondsPerAnswer) / (answersPerNew * secondsPerAnswer)).floor();
    return fitNew - newCards;
  }
}
