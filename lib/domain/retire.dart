/// Which cards count as "mastered", and what retiring them saves. Pure. Hand-set rule (D28):
/// a card whose next review is years away, answered well many times, with at most one lapse.
library;

const kRetireYearChoices = [1, 2, 3];
const kRetireMinReviews = 6;
const kRetireMaxLapses = 1;

class RetireCriteria {
  const RetireCriteria({this.years = 2});

  /// Stability (about the interval at 90% recall) at least this many years.
  final int years;
  double get minStabilityDays => 365.0 * years;
}

/// Reviews per year a card of stability [stabilityDays] costs (one review per interval; at the
/// default 90% target the interval is about the stability).
double yearlyReviews(double stabilityDays) => 365.0 / (stabilityDays < 1 ? 1 : stabilityDays);

class RetireSummary {
  const RetireSummary({required this.cards, required this.reviewsSavedPerYear, required this.minutesSavedPerYear});
  final int cards;
  final double reviewsSavedPerYear, minutesSavedPerYear;
  double get minutesSavedPerWeek => minutesSavedPerYear / 52.0;
}
