/// When should the learner re-fit the memory model to their own history? Pure rules, hand-set
/// (docs/DECISIONS.md D25). Output always says WHY and WHEN, as time or as reviews, whichever
/// is the one still missing.
library;

import 'dart:math' as math;

/// Fewest usable reviews (answers that came after a gap of at least a day) before the app
/// offers to fit. A conservative choice of this app, not a number from the FSRS authors.
const kMinUsableReviews = 1000;

/// After a fit: wait at least this long and this much new history before the next one.
const kMinDaysBetweenFits = 30;
const kMinNewReviewsFraction = 0.30;

/// Recent predictions this far off reality (percentage points) bring the next fit forward.
const kDriftPoints = 4.0;
const kDriftMinSample = 300;
const kDriftMinDays = 14;

class OptimizerSnapshot {
  const OptimizerSnapshot({required this.atMs, required this.usableThen, required this.applied, this.gain});
  final int atMs;

  /// Usable reviews at the time of that fit.
  final int usableThen;

  /// True if the personal weights were put in use; false if the old ones were kept.
  final bool applied;
  final double? gain;
}

class OptimizerAdviceInput {
  const OptimizerAdviceInput({
    required this.usableReviews,
    required this.reviewsPerDay,
    required this.nowMs,
    this.last,
    this.predictedRecall,
    this.actualRecall,
    this.sample = 0,
    this.estimated = false,
  });

  /// Usable reviews now (an estimate when [estimated], e.g. on the Today screen).
  final int usableReviews;

  /// Average answers per day over recent weeks.
  final double reviewsPerDay;
  final int nowMs;
  final OptimizerSnapshot? last;

  /// Over recent reviews: what the model expected vs what happened (0..1), and how many.
  final double? predictedRecall, actualRecall;
  final int sample;
  final bool estimated;
}

class OptimizerAdvice {
  const OptimizerAdvice({
    required this.ready,
    required this.title,
    required this.reasons,
    this.inDays,
    this.moreReviews,
  });

  /// A fit is worth doing now.
  final bool ready;
  final String title;
  final List<String> reasons;

  /// What is still missing (null when ready).
  final int? inDays, moreReviews;
}

class OptimizerAdvisor {
  const OptimizerAdvisor();

  OptimizerAdvice advise(OptimizerAdviceInput i) {
    final pace = i.reviewsPerDay;
    String daysFor(int reviews) {
      if (pace <= 0) return 'no estimate yet';
      final d = (reviews / pace).ceil();
      return d <= 1 ? 'about a day' : 'about $d days';
    }

    final gapPts = (i.predictedRecall != null && i.actualRecall != null && i.sample > 0)
        ? (i.predictedRecall! - i.actualRecall!) * 100
        : null;
    String? driftNote;
    if (gapPts != null && i.sample >= kDriftMinSample && gapPts.abs() >= 1.5) {
      driftNote = 'Across ${i.sample} reviews the model expected you to remember '
          '${(i.predictedRecall! * 100).round()}% but you remembered ${(i.actualRecall! * 100).round()}%.';
    }

    final last = i.last;
    if (last == null) {
      if (i.usableReviews < kMinUsableReviews) {
        final need = kMinUsableReviews - i.usableReviews;
        return OptimizerAdvice(
          ready: false,
          title: 'Not yet: ${i.estimated ? 'roughly ' : ''}$need more reviews (${daysFor(need)} at your pace)',
          reasons: [
            'Fitting needs at least $kMinUsableReviews reviews that came after a gap of a day or more; you have '
                '${i.estimated ? 'roughly ' : ''}${i.usableReviews}.',
            'With less, a personal fit would mostly be noise, and the built-in settings (averages from many learners) are the safer choice.',
          ],
          inDays: pace > 0 ? (need / pace).ceil() : null,
          moreReviews: need,
        );
      }
      return OptimizerAdvice(
        ready: true,
        title: 'Ready now',
        reasons: [
          'You have ${i.estimated ? 'roughly ' : ''}${i.usableReviews} usable reviews, enough to fit the model to your own memory.',
          'The built-in settings are averages from many learners; yours may forget faster or slower.',
          ?driftNote,
        ],
      );
    }

    final daysSince = ((i.nowMs - last.atMs) / 86400000).floor();
    final newReviews = math.max(0, i.usableReviews - last.usableThen);
    final needNew = math.max(kMinUsableReviews, (last.usableThen * kMinNewReviewsFraction).round());
    final timeOk = daysSince >= kMinDaysBetweenFits;
    final dataOk = newReviews >= needNew;
    final recap = last.applied
        ? 'Last fitted ${daysSince == 0 ? 'today' : '$daysSince days ago'} on ${last.usableThen} reviews.'
        : 'Last checked ${daysSince == 0 ? 'today' : '$daysSince days ago'}: your settings were already a good fit.';

    if (driftNote != null &&
        gapPts!.abs() >= kDriftPoints &&
        i.sample >= kDriftMinSample &&
        daysSince >= kDriftMinDays) {
      return OptimizerAdvice(
        ready: true,
        title: 'Worth doing now',
        reasons: [
          driftNote,
          'That is a gap of ${gapPts.abs().toStringAsFixed(1)} points, so the schedule is probably '
              '${gapPts > 0 ? 'too ambitious (cards come back later than your memory allows)' : 'too cautious (you review earlier than needed)'}.',
          recap,
        ],
      );
    }
    if (timeOk && dataOk) {
      return OptimizerAdvice(
        ready: true,
        title: 'Ready again',
        reasons: [
          '$newReviews new usable reviews since the last fit (at least $needNew are needed) and more than $kMinDaysBetweenFits days have passed.',
          recap,
          ?driftNote,
        ],
      );
    }

    final needReviews = math.max(0, needNew - newReviews);
    final needDays = math.max(0, kMinDaysBetweenFits - daysSince);
    final daysForReviews = pace > 0 ? (needReviews / pace).ceil() : null;
    final wait = math.max(needDays, daysForReviews ?? needDays);
    final reviewsBinding = daysForReviews != null && daysForReviews > needDays;
    return OptimizerAdvice(
      ready: false,
      title: reviewsBinding
          ? 'In about $needReviews more reviews (${daysFor(needReviews)} at your pace)'
          : 'In ${needDays <= 1 ? 'about a day' : '$needDays days'}',
      reasons: [
        recap,
        if (reviewsBinding || !timeOk)
          'Re-fitting needs at least $needNew new reviews (you have $newReviews) and $kMinDaysBetweenFits days between fits. '
              'Fitting too often just chases noise.',
        ?driftNote,
      ],
      inDays: wait,
      moreReviews: needReviews,
    );
  }
}
