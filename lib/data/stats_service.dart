import 'package:drift/drift.dart';

import '../domain/memory_summary.dart';
import '../domain/milestones.dart';
import '../domain/streak.dart';
import '../domain/study_card.dart' show backlogAdjustedNewLimit;
import 'queue_service.dart' show kDefaultProblemsPerDay, kMaxProblemsPerDay;
import '../domain/tomorrow_plan.dart';
import 'activity_cache.dart';
import 'db/database.dart';
import 'pace.dart';
import 'params_repo.dart';
import 'settings_repo.dart';

const _day = 86400000;

/// Answers on cards in normal review and how many were not "Again" (D49). A card is "mature" when its
/// stability before the answer was [kLongTermStability] days or more (Anki says the same about its interval).
class RetentionCell {
  const RetentionCell(this.answers, this.passed);
  final int answers, passed;

  /// Null with fewer than 10 answers: too few to mean anything.
  double? get rate => answers < 10 ? null : passed / answers;
}

class RetentionTable {
  const RetentionTable({
    required this.all30,
    required this.young30,
    required this.mature30,
    required this.all365,
    required this.young365,
    required this.mature365,
  });
  final RetentionCell all30, young30, mature30, all365, young365, mature365;
  static const empty = RetentionTable(
      all30: RetentionCell(0, 0), young30: RetentionCell(0, 0), mature30: RetentionCell(0, 0),
      all365: RetentionCell(0, 0), young365: RetentionCell(0, 0), mature365: RetentionCell(0, 0));
}

class SubjectStat {
  const SubjectStat(this.domainId, this.name, this.cards, this.mature, this.dueNow);
  final int domainId;
  final String name;

  /// Cards in play (not paused by hand); [mature] of them are long-term or retired (D48).
  final int cards, mature, dueNow;
  double get masteredShare => cards == 0 ? 0 : mature / cards;
}

class ProgressStats {
  const ProgressStats({
    required this.streak,
    required this.activity,
    required this.todayAnswered,
    required this.todayMinutes,
    required this.retention30d,
    required this.answers30d,
    required this.newCards,
    required this.learningCards,
    required this.youngCards,
    required this.fadingCards,
    required this.matureCards,
    required this.retiredCards,
    required this.suspendedCards,
    required this.todayCardIds,
    required this.secondsPerCard,
    required this.todayWeekday,
    required this.activitySpanDays,
    required this.retention,
    required this.recallBins,
    required this.tomorrow,
    this.estimatedRecall,
    required this.forecast,
    required this.totalReviews,
    required this.subjects,
    required this.milestones,
    required this.weekActive,
    required this.todayIndex,
  });

  final StreakInfo streak;

  /// Logical day index -> answers that day (last ~17 weeks).
  final Map<int, int> activity;
  final int todayAnswered;
  final double todayMinutes;
  final double? retention30d;
  final int answers30d;

  /// The seven places a card can be (D48); together they are every card, so the memory bar adds up.
  /// [matureCards] = long-term now (stable and still >= 90% likely to be recalled); [fadingCards] = was stable
  /// but is overdue; [retiredCards] = mastered and put away by the learner; [suspendedCards] = paused by hand.
  final int newCards, learningCards, youngCards, fadingCards, matureCards, retiredCards, suspendedCards;

  /// Cards answered today (each once, however many times), so Today can count cards, not answers.
  final Set<int> todayCardIds;

  /// The learner's own recent pace (seconds per answer), for "about N min".
  final double secondsPerCard;

  /// Weekday (1 = Monday) of the app's day, which rolls over at 04:00, not at midnight.
  final int todayWeekday;

  /// Days the activity heatmap really covers (since the first study day, at most the heatmap length).
  final int activitySpanDays;

  /// What tomorrow asks of the learner, and how much more would fit (D54).
  final TomorrowPlan tomorrow;

  /// True retention by card age and period (D49).
  final RetentionTable retention;

  /// How many learned cards sit in each 10-point band of recall right now: [0] is 0-10%, [9] is 90-100%.
  final List<int> recallBins;

  /// Average chance of recalling the cards you have learned, right now (a model estimate); null with too few.
  final double? estimatedRecall;

  /// Cards in long-term memory including the ones the learner retired: what "in long-term memory" shows.
  int get longTermTotal => matureCards + retiredCards;

  /// Reviews scheduled for today (remaining) and the next 6 days.
  final List<int> forecast;
  final int totalReviews;
  final List<SubjectStat> subjects;
  final List<Milestone> milestones;

  /// Active flags for the last 7 days, oldest first (today last).
  final List<bool> weekActive;
  final int todayIndex;

  int get totalCards => newCards + learningCards + youngCards + fadingCards + matureCards + retiredCards + suspendedCards;
}

/// Everything the Home and Progress screens show, computed from the review log and cards.
class StatsService {
  StatsService(this.db, this.settings, {ParamsRepo? params}) : params = params ?? ParamsRepo(db, settings);
  final AppDatabase db;
  final SettingsRepo settings;
  final ParamsRepo params;

  Future<ProgressStats> compute({DateTime? now, int heatmapDays = 119}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final nowMs = t.millisecondsSinceEpoch;
    final clock = await settings.dayClock();
    final today = clock.dayIndex(t);
    final dayStart = clock.dayStartMs(t);
    final dayEnd = clock.dayEndMs(t);

    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    Future<Map<String, Object?>> one(String sql, [List<Variable> v = const []]) async =>
        (await db.customSelect(sql, variables: v).getSingle()).data;

    DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

    // Answers per 15-minute bucket, kept incrementally (ActivityCache): the full review_log
    // is never scanned here, however many years it holds.
    final cache = ActivityCache(db, settings);
    final all = await cache.buckets();
    final activeDays = {for (final b in all) clock.dayIndex(at(b.bucket * kBucketMs))};
    final streak = computeStreak(activeDays, today);

    final since = dayStart - heatmapDays * _day;
    final activity = <int, int>{};
    for (final b in all) {
      if (b.bucket * kBucketMs < since) continue;
      final d = clock.dayIndex(at(b.bucket * kBucketMs));
      activity[d] = (activity[d] ?? 0) + b.n;
    }

    final spent = await one(
        'SELECT COUNT(*) AS n, COALESCE(SUM(duration_ms), 0) AS ms FROM review_log '
        'WHERE revoked_at IS NULL AND reviewed_at >= ?',
        [Variable.withInt(dayStart)]);

    final yearAgo = nowMs - 365 * _day, monthAgo = nowMs - 30 * _day;
    final rt = await one('''
      SELECT
        SUM(CASE WHEN reviewed_at >= ? THEN 1 ELSE 0 END) AS a30,
        SUM(CASE WHEN reviewed_at >= ? AND rating > 1 THEN 1 ELSE 0 END) AS p30,
        SUM(CASE WHEN reviewed_at >= ? AND COALESCE(stability_before, 0) < ? THEN 1 ELSE 0 END) AS ay30,
        SUM(CASE WHEN reviewed_at >= ? AND COALESCE(stability_before, 0) < ? AND rating > 1 THEN 1 ELSE 0 END) AS py30,
        COUNT(*) AS a365,
        SUM(CASE WHEN rating > 1 THEN 1 ELSE 0 END) AS p365,
        SUM(CASE WHEN COALESCE(stability_before, 0) < ? THEN 1 ELSE 0 END) AS ay365,
        SUM(CASE WHEN COALESCE(stability_before, 0) < ? AND rating > 1 THEN 1 ELSE 0 END) AS py365
      FROM review_log WHERE revoked_at IS NULL AND state_before = 'review' AND reviewed_at >= ?''', [
      Variable.withInt(monthAgo), Variable.withInt(monthAgo),
      Variable.withInt(monthAgo), Variable.withReal(kLongTermStability),
      Variable.withInt(monthAgo), Variable.withReal(kLongTermStability),
      Variable.withReal(kLongTermStability), Variable.withReal(kLongTermStability),
      Variable.withInt(yearAgo),
    ]);
    final retention = RetentionTable(
      all30: RetentionCell(i(rt['a30']), i(rt['p30'])),
      young30: RetentionCell(i(rt['ay30']), i(rt['py30'])),
      mature30: RetentionCell(i(rt['a30']) - i(rt['ay30']), i(rt['p30']) - i(rt['py30'])),
      all365: RetentionCell(i(rt['a365']), i(rt['p365'])),
      young365: RetentionCell(i(rt['ay365']), i(rt['py365'])),
      mature365: RetentionCell(i(rt['a365']) - i(rt['ay365']), i(rt['p365']) - i(rt['py365'])),
    );

    // Where every card stands (D48). New, paused and retired cards are counted in SQL; the cards that have a
    // memory trace are read one by one, because "still >= 90% likely to be recalled" depends on the clock.
    final nowMsInt = nowMs;
    final counts = await one('''
      SELECT SUM(CASE WHEN retired_at IS NOT NULL THEN 1 ELSE 0 END) AS retired,
             SUM(CASE WHEN retired_at IS NULL AND suspended = 1 THEN 1 ELSE 0 END) AS paused,
             SUM(CASE WHEN suspended = 0 AND state = 'new' THEN 1 ELSE 0 END) AS fresh
      FROM card''');
    final traced = await db.customSelect('''
      SELECT n.domain_id AS dom, c.state AS state, c.stability AS stab, c.last_review AS last
      FROM card c JOIN note n ON n.id = c.note_id
      WHERE c.suspended = 0 AND c.state != 'new' ''').get();
    final weightsFor = <int, List<double>>{};
    var learningN = 0, growingN = 0, fadingN = 0, longTermN = 0;
    var recallSum = 0.0, recallN = 0;
    final bins = List<int>.filled(10, 0);
    final longByDomain = <int, int>{}, inPlayByDomain = <int, int>{};
    for (final r in traced) {
      final d = r.data;
      final dom = d['dom']! as int;
      var w = weightsFor[dom];
      if (w == null) {
        w = (await params.configFor(await params.idForDomain(dom))).weights;
        weightsFor[dom] = w;
      }
      final fact = MemoryFact(state: d['state']! as String, stability: (d['stab'] as num?)?.toDouble(), lastReviewMs: d['last'] as int?);
      final rec = recallNow(fact, w, nowMsInt);
      switch (bucketOf(fact, w, nowMsInt, recall: rec)) {
        case MemoryBucket.learning:
          learningN++;
        case MemoryBucket.growing:
          growingN++;
        case MemoryBucket.fading:
          fadingN++;
        case MemoryBucket.longTerm:
          longTermN++;
          longByDomain[dom] = (longByDomain[dom] ?? 0) + 1;
        default:
          break;
      }
      inPlayByDomain[dom] = (inPlayByDomain[dom] ?? 0) + 1;
      if (rec > 0) {
        recallSum += rec;
        recallN++;
        bins[(rec * 10).floor().clamp(0, 9)]++;
      }
    }

    // Forecast: reviews still due today, then each of the next 6 days. Cards in their first
    // learning steps (or relearning after a lapse) come back within the day, so they count as today.
    final due = await db.customSelect(
        "SELECT c.due AS due, c.state AS state, n.type AS type FROM card c JOIN note n ON n.id = c.note_id WHERE c.suspended = 0 AND ((c.state = 'review' AND c.due < ?) "
        "OR (c.state IN ('learning', 'relearning') AND c.due < ?))",
        variables: [Variable.withInt(dayEnd + 6 * _day), Variable.withInt(dayEnd)]).get();
    final forecast = List<int>.filled(7, 0);
    var problemTomorrow = 0; // of tomorrow's reviews, the problem cards (they take minutes, not seconds)
    var learningLater = 0; // today's learning steps that come back after a short wait (not yet on Today)
    for (final r in due) {
      final d = r.read<int>('due');
      final idx = d < dayEnd ? 0 : ((d - dayEnd) ~/ _day) + 1;
      if (idx >= 0 && idx < 7) forecast[idx]++;
      if (idx == 1 && r.read<String>('type') == 'problem') problemTomorrow++;
      if (idx == 0 && r.read<String>('state') != 'review' && d > nowMs) learningLater++;
    }

    final subjects = <SubjectStat>[];
    final rows = await db.customSelect('''
      SELECT d.id AS id, d.name AS name,
             SUM(CASE WHEN c.id IS NOT NULL AND (c.suspended = 0 OR c.retired_at IS NOT NULL) THEN 1 ELSE 0 END) AS cards,
             SUM(CASE WHEN c.retired_at IS NOT NULL THEN 1 ELSE 0 END) AS retired,
             SUM(CASE WHEN c.suspended = 0 AND (
                   (c.state IN ('learning','relearning') AND c.due <= ?) OR
                   (c.state = 'review' AND c.due < ?)) THEN 1 ELSE 0 END) AS due_now
      FROM domain d
      LEFT JOIN note n ON n.domain_id = d.id
      LEFT JOIN card c ON c.note_id = n.id
      WHERE d.active = 1
      GROUP BY d.id ORDER BY d.id''',
        variables: [Variable.withInt(nowMs), Variable.withInt(dayEnd)]).get();
    for (final r in rows) {
      final id = r.read<int>('id');
      subjects.add(SubjectStat(id, r.read<String>('name'), i(r.data['cards']), (longByDomain[id] ?? 0) + i(r.data['retired']), i(r.data['due_now'])));
    }

    final answeredIds = await db.customSelect(
        // No DISTINCT: it makes SQLite walk the whole card index (about 60 ms at 120,000 answers); today's few rows are de-duplicated below.
        'SELECT card_id FROM review_log WHERE revoked_at IS NULL AND reviewed_at >= ?',
        variables: [Variable.withInt(dayStart)]).get();
    // The median of recent answers, ordinary and problem cards apart (D55): a mean was set by a few slow answers.
    final ordinaryPace = await ordinarySeconds(db);
    final problemPace = await problemSeconds(db);

    // Tomorrow (D54): reviews are scheduled; new cards come from the daily limit (as the queue applies it).
    final baseNew = await settings.getInt(SettingsRepo.newPerDay, 10);
    final shrink = await settings.get(SettingsRepo.backlogShrink) == '1';
    final divisor = await settings.getInt(SettingsRepo.backlogDivisor, 25);
    final newLimit = shrink ? backlogAdjustedNewLimit(baseNew, forecast[1], divisor: divisor) : (baseNew < 0 ? 0 : baseNew);
    // New cards not started yet, one per note per day (a sibling answered today is buried until tomorrow). The ones
    // available now belong to TODAY first, up to what is left of today's limit; tomorrow gets what remains, plus the
    // buried ones. Counting all of them for tomorrow would count the same cards on both days.
    final waiting = await one(
        "SELECT COUNT(DISTINCT CASE WHEN c.buried_until IS NULL OR c.buried_until <= ? THEN c.note_id END) AS now_n, "
        "COUNT(DISTINCT CASE WHEN c.buried_until > ? THEN c.note_id END) AS buried_n "
        "FROM card c JOIN note n ON n.id = c.note_id "
        "WHERE c.state = 'new' AND c.suspended = 0 AND n.type != 'problem'",
        [Variable.withInt(nowMs), Variable.withInt(nowMs)]);
    final introduced = await one(
        "SELECT COUNT(DISTINCT l.card_id) AS n FROM review_log l CROSS JOIN card c ON c.id = l.card_id CROSS JOIN note n ON n.id = c.note_id "
        "WHERE l.reviewed_at >= ? AND l.revoked_at IS NULL AND l.state_before = 'new' AND n.type != 'problem'",
        [Variable.withInt(dayStart)]);
    final todayLeft = ((baseNew < 0 ? 0 : baseNew) - i(introduced['n'])).clamp(0, 1 << 30);
    final newToday = i(waiting['now_n']) < todayLeft ? i(waiting['now_n']) : todayLeft;
    final newWaiting = (i(waiting['now_n']) - newToday) + i(waiting['buried_n']);
    final steps = await settings.getIntList(SettingsRepo.learningSteps, [1, 10]);
    final problemLimit = (await settings.getInt(SettingsRepo.problemsPerDay, kDefaultProblemsPerDay)).clamp(0, kMaxProblemsPerDay);
    final problemsWaiting = i((await one(
            "SELECT COUNT(DISTINCT c.note_id) AS n FROM card c JOIN note n ON n.id = c.note_id "
            "WHERE c.state = 'new' AND c.suspended = 0 AND n.type = 'problem'"))['n']);
    final newProblems = problemsWaiting < problemLimit ? problemsWaiting : problemLimit;
    final tomorrow = TomorrowPlan(
      dueReviews: forecast[1],
      stillDueToday: forecast[0],
      learningLaterToday: learningLater,
      newStillToday: newToday,
      newCards: newWaiting < newLimit ? newWaiting : newLimit,
      newWaiting: newWaiting,
      newLimit: newLimit,
      answersPerNew: steps.isEmpty ? 1 : steps.length,
      secondsPerAnswer: ordinaryPace,
      secondsPerProblem: problemPace,
      problemReviews: problemTomorrow,
      newProblems: newProblems,
      budgetMinutes: await settings.getInt(SettingsRepo.dailyMinutes, 20),
    );

    final totalReviews = await cache.total();
    final revisited = await one('SELECT COUNT(*) AS n FROM syllabus_item WHERE rounds >= 2');
    final retiredN = i(counts['retired']);

    return ProgressStats(
      streak: streak,
      activity: activity,
      todayAnswered: i(spent['n']),
      todayMinutes: i(spent['ms']) / 60000,
      retention30d: retention.all30.rate,
      answers30d: retention.all30.answers,
      retention: retention,
      recallBins: bins,
      tomorrow: tomorrow,
      newCards: i(counts['fresh']),
      learningCards: learningN,
      youngCards: growingN,
      fadingCards: fadingN,
      matureCards: longTermN,
      retiredCards: retiredN,
      suspendedCards: i(counts['paused']),
      todayCardIds: {for (final r in answeredIds) r.read<int>('card_id')},
      secondsPerCard: ordinaryPace,
      todayWeekday: DateTime.fromMillisecondsSinceEpoch(dayStart).weekday,
      activitySpanDays: activeDays.isEmpty ? 0 : today - [activeDays.reduce((a, b) => a < b ? a : b), today - heatmapDays + 1].reduce((a, b) => a > b ? a : b) + 1,
      estimatedRecall: recallN < kMinCardsForEstimate ? null : recallSum / recallN,
      forecast: forecast,
      totalReviews: totalReviews,
      subjects: subjects,
      milestones: milestonesFor(MilestoneInputs(
        totalReviews: totalReviews,
        bestStreak: streak.best,
        // A milestone is earned for good: it counts every card that ever reached a stable memory.
        matureCards: longTermN + fadingN + retiredN,
        subjectsStarted: subjects.where((s) => s.cards > 0).length,
        topicsRevisited: i(revisited['n']),
      )),
      weekActive: [for (var k = 6; k >= 0; k--) activeDays.contains(today - k)],
      todayIndex: today,
    );
  }
}
