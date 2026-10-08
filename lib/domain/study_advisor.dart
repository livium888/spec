/// "Should I add more new material, and how much?" Pure, deterministic, explainable.
/// Every verdict carries the reasons behind it in plain words. Thresholds are
/// hand-set heuristics (see docs/DECISIONS.md D16), not fitted to the learner yet.
library;

enum AdviceLevel {
  /// Good time to add new cards.
  go,

  /// Add a small batch only.
  gentle,

  /// Not now: reviews / forgetting come first.
  wait,

  /// Done for today.
  stop,
}

class AdviceInput {
  const AdviceInput({
    required this.dueToday,
    required this.avgSecondsPerReview,
    required this.budgetMinutes,
    required this.spentSecondsToday,
    required this.newIntroducedToday,
    required this.newLimit,
    required this.upcoming7dReviews,
    required this.desiredRetention,
    this.retention30d,
    this.answers30d = 0,
    this.lapseRate30d,
    this.leechCount = 0,
    this.daysSinceLastSession,
    this.baseCount = 10,
    this.limitShrinks = false,
  });

  /// Reviews + learning cards still due today.
  final int dueToday;
  final double avgSecondsPerReview;
  final int budgetMinutes;
  final double spentSecondsToday;
  final int newIntroducedToday;

  /// Today's new-card limit after the backlog shrink (see backlogAdjustedNewLimit).
  final int newLimit;

  /// Review-state cards already scheduled in the 7 days after today.
  final int upcoming7dReviews;
  final double desiredRetention;

  /// Share of review-state answers rated Hard/Good/Easy over 30 days (null: no data).
  final double? retention30d;
  final int answers30d;
  final double? lapseRate30d;
  final int leechCount;
  final double? daysSinceLastSession;
  final int baseCount;

  /// True when the learner switched on "shrink the new-card limit when reviews pile up".
  final bool limitShrinks;
}

class Advice {
  const Advice({
    required this.level,
    required this.headline,
    required this.reasons,
    required this.recommendedNewCards,
    required this.reviewsFirst,
    required this.minutesLeftToday,
    this.limitReached = false,
    this.dailyLimitLeft = 0,
  });
  final AdviceLevel level;
  final String headline;

  /// Facts supporting the verdict, most important first.
  final List<String> reasons;

  /// How many new cards fit right now (0 when level is wait/stop).
  final int recommendedNewCards;

  /// True when reviews are still due and should come before new cards.
  final bool reviewsFirst;
  final double minutesLeftToday;

  /// The learner's own daily new-card limit is used up (the only thing that holds back a prompt).
  final bool limitReached;
  final int dailyLimitLeft;

  /// One short line for tight spaces (Home card subtitle).
  String get summary => reasons.isEmpty ? headline : reasons.first;
}

class StudyAdvisor {
  const StudyAdvisor();

  /// New cards cost this many reviews in their first week (heuristic).
  static const reviewsPerNewCard = 3;

  /// Share of the daily budget that scheduled reviews may use before new cards
  /// are held back; the rest is left for learning new material.
  static const reviewShareOfBudget = 0.8;

  static const retentionGentleGap = 0.03;
  static const retentionWaitGap = 0.07;
  static const minAnswersForRetention = 50;
  static const leechGentle = 8;
  static const longAbsenceDays = 10;
  static const gentleCap = 5;

  static String _mins(double seconds) {
    final m = seconds / 60;
    if (m < 1) return 'under a minute';
    return '${m.round()} min';
  }

  static String _pct(double x) => '${(x * 100).round()}%';

  Advice advise(AdviceInput i) {
    final avg = i.avgSecondsPerReview;
    final budgetSec = i.budgetMinutes * 60.0;
    final dueSec = i.dueToday * avg;
    final leftSec = budgetSec - i.spentSecondsToday - dueSec;
    final leftMin = leftSec <= 0 ? 0.0 : leftSec / 60;

    // How many new cards can fit, three separate ways.
    final roomToday = leftSec <= 0 ? 0 : (leftSec / (reviewsPerNewCard * avg)).floor();
    final weekCapacityReviews = (reviewShareOfBudget * budgetSec / avg * 7).floor();
    final sustain = ((weekCapacityReviews - (i.dueToday + i.upcoming7dReviews)) / reviewsPerNewCard).floor();
    final limitLeft = (i.newLimit - i.newIntroducedToday).clamp(0, 1 << 20);
    var rec = [roomToday, sustain, limitLeft, i.baseCount].reduce((a, b) => a < b ? a : b);
    if (rec < 0) rec = 0;

    final facts = <String>[];
    if (i.dueToday > 0) {
      facts.add('${i.dueToday} review${i.dueToday == 1 ? '' : 's'} due (about ${_mins(dueSec)}).');
    }
    if (i.spentSecondsToday >= 60) {
      facts.add('You have studied ${_mins(i.spentSecondsToday)} today of your ${i.budgetMinutes}-minute budget.');
    }

    final retention = (i.retention30d != null && i.answers30d >= minAnswersForRetention) ? i.retention30d : null;
    final retGap = retention == null ? 0.0 : i.desiredRetention - retention;

    Advice make(AdviceLevel level, String headline, List<String> reasons, int n) => Advice(
          level: level,
          headline: headline,
          reasons: reasons,
          recommendedNewCards: level == AdviceLevel.wait || level == AdviceLevel.stop ? 0 : n,
          reviewsFirst: i.dueToday > 0,
          minutesLeftToday: leftMin,
          limitReached: limitLeft == 0,
          dailyLimitLeft: limitLeft,
        );

    // ---- STOP: the day is done -------------------------------------------------
    if (limitLeft == 0) {
      final added = i.newIntroducedToday;
      return make(AdviceLevel.stop, added > 0 ? 'You are done with new material for today' : 'No new cards today', [
        if (added > 0)
          'You already added $added new card${added == 1 ? '' : 's'} today, which is today\'s limit (${i.newLimit}).'
        else
          'Today\'s new-card limit is ${i.newLimit}${i.limitShrinks ? ' (your setting, reduced because many reviews are due)' : ', your own setting in Settings'}.',
        if (i.limitShrinks) 'You switched on shrinking the limit when many reviews are due, so that new cards do not bury you.',
        ...facts,
        if (added > 0) 'Tomorrow is a good time for the next topic.',
      ], 0);
    }
    if (i.dueToday == 0 && leftSec <= 0) {
      return make(AdviceLevel.stop, 'You have used today\'s study time', [
        'You studied ${_mins(i.spentSecondsToday)} today, which is your ${i.budgetMinutes}-minute budget.',
        'Stopping here keeps the habit sustainable. More new cards today would raise tomorrow\'s reviews.',
      ], 0);
    }

    // ---- WAIT: something should be fixed first ---------------------------------
    if (dueSec > budgetSec * 0.9) {
      return make(AdviceLevel.wait, 'Reviews first. Hold off on new cards', [
        'Your ${i.dueToday} due reviews alone take about ${_mins(dueSec)}, ${dueSec > budgetSec ? 'more than' : 'nearly'} your whole ${i.budgetMinutes}-minute budget.',
        'New cards would add to that pile, and cards you cannot review in time get forgotten.',
        ...facts.skip(1),
      ], 0);
    }
    if (retention != null && retGap > retentionWaitGap) {
      return make(AdviceLevel.wait, 'Consolidate before adding more', [
        'You are remembering ${_pct(retention)} of your reviews, below your ${_pct(i.desiredRetention)} target.',
        'Adding more now tends to make forgetting worse. Reviews on time and rewriting hard cards help most.',
        ...facts,
      ], 0);
    }
    if (sustain <= 0) {
      final perDayMin = (i.dueToday + i.upcoming7dReviews) / 7 * avg / 60;
      return make(AdviceLevel.wait, 'Hold off: the coming week is already full', [
        'About ${i.dueToday + i.upcoming7dReviews} reviews are already scheduled over the next 7 days (about ${perDayMin.round()} min a day).',
        'That is at ${_pct(reviewShareOfBudget)} of your ${i.budgetMinutes}-minute budget, the point where new cards start to crowd out learning.',
        ...facts,
      ], 0);
    }
    if (rec <= 0) {
      return make(AdviceLevel.stop, 'No room for new cards today', [
        'About ${leftMin.round()} min of your budget is left, and each new card costs roughly $reviewsPerNewCard reviews in its first week.',
        ...facts,
      ], 0);
    }

    // ---- GENTLE: go, but small -------------------------------------------------
    final gentle = <String>[];
    if (retention != null && retGap > retentionGentleGap) {
      gentle.add('You are remembering ${_pct(retention)} versus a ${_pct(i.desiredRetention)} target: slightly behind, so go small.');
    }
    if (i.leechCount >= leechGentle) {
      gentle.add('${i.leechCount} cards keep being forgotten. Fixing them pays off more than adding many new ones.');
    }
    if (i.daysSinceLastSession != null && i.daysSinceLastSession! > longAbsenceDays) {
      gentle.add('You have been away ${i.daysSinceLastSession!.floor()} days: reviews will have piled up, so ease back in.');
    }
    if (gentle.isNotEmpty) {
      final n = rec < gentleCap ? rec : gentleCap;
      return make(AdviceLevel.gentle, 'Go gently: up to $n new cards', [...gentle, ...facts], n);
    }

    // ---- GO --------------------------------------------------------------------
    final why = <String>[];
    if (retention != null) {
      why.add('You are remembering ${_pct(retention)} of your reviews, at or above your ${_pct(i.desiredRetention)} target.');
    }
    // Listed so that on a tie the most "ordinary" constraint is the one named.
    final bind = <String, int>{
      'your usual batch size': i.baseCount,
      'today\'s new-card limit': limitLeft,
      'what next week\'s reviews can absorb': sustain,
      'the time left today (about ${leftMin.round()} min)': roomToday,
    };
    final binding = bind.entries.reduce((a, b) => a.value <= b.value ? a : b);
    why.add('Up to $rec new card${rec == 1 ? '' : 's'} fits, limited by ${binding.key}.');
    why.addAll(facts);
    final headline = i.dueToday > 0
        ? 'Do your ${i.dueToday} review${i.dueToday == 1 ? '' : 's'} first, then add up to $rec new cards'
        : 'Good time to learn: add up to $rec new cards';
    return make(AdviceLevel.go, headline, why, rec);
  }
}
