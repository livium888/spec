import 'package:drift/drift.dart';

import '../domain/milestones.dart';
import '../domain/streak.dart';
import 'activity_cache.dart';
import 'db/database.dart';
import 'settings_repo.dart';

const _day = 86400000;

/// A card counts as "mature" (a stable long-term memory) at this FSRS stability, in days.
const kMatureStabilityDays = 21.0;

class SubjectStat {
  const SubjectStat(this.domainId, this.name, this.cards, this.mature, this.dueNow);
  final int domainId;
  final String name;
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
    required this.matureCards,
    required this.suspendedCards,
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
  final int newCards, learningCards, youngCards, matureCards, suspendedCards;

  /// Reviews scheduled for today (remaining) and the next 6 days.
  final List<int> forecast;
  final int totalReviews;
  final List<SubjectStat> subjects;
  final List<Milestone> milestones;

  /// Active flags for the last 7 days, oldest first (today last).
  final List<bool> weekActive;
  final int todayIndex;

  int get totalCards => newCards + learningCards + youngCards + matureCards + suspendedCards;
}

/// Everything the Home and Progress screens show, computed from the review log and cards.
class StatsService {
  StatsService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

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

    final r30 = await one('''
      SELECT SUM(CASE WHEN state_before IN ('review','relearning') THEN 1 ELSE 0 END) AS answers,
             SUM(CASE WHEN state_before IN ('review','relearning') AND rating > 1 THEN 1 ELSE 0 END) AS passed
      FROM review_log WHERE revoked_at IS NULL AND reviewed_at >= ?''',
        [Variable.withInt(nowMs - 30 * _day)]);

    final mat = await one('''
      SELECT SUM(CASE WHEN suspended = 1 THEN 1 ELSE 0 END) AS susp,
             SUM(CASE WHEN suspended = 0 AND state = 'new' THEN 1 ELSE 0 END) AS fresh,
             SUM(CASE WHEN suspended = 0 AND state IN ('learning','relearning') THEN 1 ELSE 0 END) AS learning,
             SUM(CASE WHEN suspended = 0 AND state = 'review' AND COALESCE(stability, 0) < ? THEN 1 ELSE 0 END) AS young,
             SUM(CASE WHEN suspended = 0 AND state = 'review' AND COALESCE(stability, 0) >= ? THEN 1 ELSE 0 END) AS mature
      FROM card''', [Variable.withReal(kMatureStabilityDays), Variable.withReal(kMatureStabilityDays)]);

    // Forecast: reviews still due today, then each of the next 6 days.
    final due = await db.customSelect(
        "SELECT due FROM card WHERE state = 'review' AND suspended = 0 AND due < ?",
        variables: [Variable.withInt(dayEnd + 6 * _day)]).get();
    final forecast = List<int>.filled(7, 0);
    for (final r in due) {
      final d = r.read<int>('due');
      final idx = d < dayEnd ? 0 : ((d - dayEnd) ~/ _day) + 1;
      if (idx >= 0 && idx < 7) forecast[idx]++;
    }

    final subjects = <SubjectStat>[];
    final rows = await db.customSelect('''
      SELECT d.id AS id, d.name AS name, COUNT(c.id) AS cards,
             SUM(CASE WHEN c.state = 'review' AND COALESCE(c.stability, 0) >= ? THEN 1 ELSE 0 END) AS mature,
             SUM(CASE WHEN c.suspended = 0 AND (
                   (c.state IN ('learning','relearning') AND c.due <= ?) OR
                   (c.state = 'review' AND c.due < ?)) THEN 1 ELSE 0 END) AS due_now
      FROM domain d
      LEFT JOIN note n ON n.domain_id = d.id
      LEFT JOIN card c ON c.note_id = n.id
      WHERE d.active = 1
      GROUP BY d.id ORDER BY d.id''',
        variables: [Variable.withReal(kMatureStabilityDays), Variable.withInt(nowMs), Variable.withInt(dayEnd)]).get();
    for (final r in rows) {
      subjects.add(SubjectStat(r.read<int>('id'), r.read<String>('name'), i(r.data['cards']), i(r.data['mature']), i(r.data['due_now'])));
    }

    final totalReviews = await cache.total();
    final revisited = await one('SELECT COUNT(*) AS n FROM syllabus_item WHERE rounds >= 2');
    final matureTotal = i(mat['mature']);
    final answers = i(r30['answers']);

    return ProgressStats(
      streak: streak,
      activity: activity,
      todayAnswered: i(spent['n']),
      todayMinutes: i(spent['ms']) / 60000,
      retention30d: answers < 10 ? null : i(r30['passed']) / answers,
      answers30d: answers,
      newCards: i(mat['fresh']),
      learningCards: i(mat['learning']),
      youngCards: i(mat['young']),
      matureCards: matureTotal,
      suspendedCards: i(mat['susp']),
      forecast: forecast,
      totalReviews: totalReviews,
      subjects: subjects,
      milestones: milestonesFor(MilestoneInputs(
        totalReviews: totalReviews,
        bestStreak: streak.best,
        matureCards: matureTotal,
        subjectsStarted: subjects.where((s) => s.cards > 0).length,
        topicsRevisited: i(revisited['n']),
      )),
      weekActive: [for (var k = 6; k >= 0; k--) activeDays.contains(today - k)],
      todayIndex: today,
    );
  }
}
