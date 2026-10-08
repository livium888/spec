import 'dart:isolate';

import 'package:drift/drift.dart';

import '../domain/workload.dart';
import 'db/database.dart';
import 'params_repo.dart';
import 'settings_repo.dart';

const _day = 86400000;

/// How many existing cards the simulation samples (each stands for several real ones).
const kMaxSampledCards = 3000;

class PlanRequest {
  const PlanRequest({
    required this.base,
    required this.secondsPerReview,
    required this.budgetMinutes,
    required this.newPerDay,
    this.withSustainable = true,
    this.seeds = 3,
  });
  final WorkloadInput base;
  final double secondsPerReview, budgetMinutes, newPerDay;
  final bool withSustainable;
  final int seeds;
}

class PlanResult {
  const PlanResult({required this.rows, required this.advice, required this.newPerDay, required this.budgetMinutes, required this.secondsPerReview});
  final List<HorizonRow> rows;
  final PlanAdvice advice;
  final double newPerDay, budgetMinutes, secondsPerReview;
}

/// Pure and isolate-safe: the headline numbers average a few seeded runs to damp Monte Carlo noise.
PlanResult computePlan(PlanRequest r) {
  List<double> mean = [];
  WorkloadResult? first;
  for (var i = 0; i < r.seeds; i++) {
    final b = r.base;
    final res = simulateWorkload(WorkloadInput(
      weights: b.weights, existing: b.existing, existingWeight: b.existingWeight,
      newPerDay: b.newPerDay, newRetention: b.newRetention, horizonDays: b.horizonDays, seed: b.seed + i * 101));
    first ??= res;
    if (mean.isEmpty) {
      mean = List<double>.of(res.daily);
    } else {
      for (var d = 0; d < mean.length; d++) {
        mean[d] += res.daily[d];
      }
    }
  }
  for (var d = 0; d < mean.length; d++) {
    mean[d] /= r.seeds;
  }
  final result = WorkloadResult(mean);
  final sustainable = r.withSustainable && r.base.horizonDays >= 1825
      ? sustainableNewPerDay(base: r.base, atDay: 1825, budgetMinutes: r.budgetMinutes, secondsPerReview: r.secondsPerReview)
      : null;
  return PlanResult(
    rows: horizonTable(result, r.secondsPerReview),
    advice: planAdvice(
        result: result, secondsPerReview: r.secondsPerReview, budgetMinutes: r.budgetMinutes,
        newPerDay: r.newPerDay, sustainableNew: sustainable),
    newPerDay: r.newPerDay,
    budgetMinutes: r.budgetMinutes,
    secondsPerReview: r.secondsPerReview,
  );
}

Future<PlanResult> planInIsolate(PlanRequest r) => Isolate.run(() => computePlan(r));

/// "Looking ahead": reads a sample of the library and the learner's pace, and forecasts review time.
class PlanService {
  PlanService(this.db, this.settings, this.params, {this.runner = planInIsolate});
  final AppDatabase db;
  final SettingsRepo settings;
  final ParamsRepo params;
  final Future<PlanResult> Function(PlanRequest) runner;

  /// New cards a day over the last four weeks (the pace the learner really keeps); falls back to
  /// the daily setting while there is too little history.
  Future<double> currentPace({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final r = await db.customSelect(
        "SELECT COUNT(*) AS n FROM review_log WHERE state_before = 'new' AND revoked_at IS NULL AND reviewed_at >= ?",
        variables: [Variable.withInt(t - 28 * _day)]).getSingle();
    final n = r.read<int>('n');
    if (n >= 10) return n / 28.0;
    return (await settings.getInt(SettingsRepo.newPerDay, 10)).toDouble();
  }

  Future<double> secondsPerReview({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final r = await db.customSelect(
        'SELECT AVG(duration_ms) AS a, COUNT(*) AS n FROM review_log '
        'WHERE revoked_at IS NULL AND duration_ms BETWEEN 500 AND 120000 AND reviewed_at >= ?',
        variables: [Variable.withInt(t - 30 * _day)]).getSingle();
    return r.read<int>('n') >= 20 ? ((r.data['a'] as num).toDouble() / 1000).clamp(4.0, 60.0) : 12.0;
  }

  Future<WorkloadInput> baseInput({required double newPerDay, int horizonDays = 3650, DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final clock = await settings.dayClock();
    final dayStart = clock.dayStartMs(t);
    final total = (await db.customSelect(
            "SELECT COUNT(*) AS n FROM card WHERE state = 'review' AND suspended = 0 AND stability IS NOT NULL").getSingle())
        .read<int>('n');
    final k = total <= kMaxSampledCards ? 1 : (total / kMaxSampledCards).ceil();
    final rows = await db.customSelect('''
      SELECT c.stability AS s, c.difficulty AS d, c.due AS due, c.last_review AS last, dm.retention AS r
      FROM card c JOIN note n ON n.id = c.note_id JOIN domain dm ON dm.id = n.domain_id
      WHERE c.state = 'review' AND c.suspended = 0 AND c.stability IS NOT NULL AND (? = 1 OR c.id % ? = 0)''',
        variables: [Variable.withInt(k), Variable.withInt(k)]).get();
    final globalRetention = await settings.getDouble(SettingsRepo.desiredRetention, 0.90);
    final cards = <SimCard>[];
    var retSum = 0.0;
    for (final r in rows) {
      final ret = (r.data['r'] as num?)?.toDouble() ?? globalRetention;
      retSum += ret;
      final due = r.read<int>('due');
      final last = r.read<int?>('last') ?? due - _day;
      cards.add(SimCard(
        stability: (r.data['s'] as num).toDouble(),
        difficulty: ((r.data['d'] as num?)?.toDouble() ?? 5.0).clamp(1.0, 10.0),
        dueDay: ((due - dayStart) / _day).floor(),
        lastDay: ((last - dayStart) / _day).floor().clamp(-36500, 0),
        retention: ret,
      ));
    }
    return WorkloadInput(
      weights: await params.activeWeights(),
      existing: cards,
      existingWeight: cards.isEmpty ? 1 : total / cards.length,
      newPerDay: newPerDay,
      newRetention: cards.isEmpty ? globalRetention : retSum / cards.length,
      horizonDays: horizonDays,
    );
  }

  /// The forecast for [newPerDay] (null: the learner's current pace).
  Future<PlanResult> plan({double? newPerDay, bool withSustainable = true, DateTime? now}) async {
    final pace = newPerDay ?? await currentPace(now: now);
    final base = await baseInput(newPerDay: pace, now: now);
    return runner(PlanRequest(
      base: base,
      secondsPerReview: await secondsPerReview(now: now),
      budgetMinutes: (await settings.getInt(SettingsRepo.dailyMinutes, 20)).toDouble(),
      newPerDay: pace,
      withSustainable: withSustainable,
    ));
  }
}
