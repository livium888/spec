import 'package:drift/drift.dart';

import 'db/database.dart';

/// How long an answer typically takes this learner (D55). The MEDIAN of recent answers, not the mean: a few
/// slow answers (a problem worked out on paper, a card left open) must not set the pace of everything else.
/// Ordinary cards and problem cards are timed apart, because a problem takes minutes and an ordinary card seconds.
///
/// Returns [fallback] until [minSamples] answers exist.
Future<double> typicalSeconds(
  AppDatabase db, {
  required bool problems,
  int sinceMs = 0,
  int latest = 200,
  int minSamples = 20,
  required double fallback,
  required double min,
  required double max,
}) async {
  final rows = await db.customSelect(
    '''SELECT l.duration_ms AS ms FROM review_log l
       JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id
       WHERE l.revoked_at IS NULL AND l.duration_ms >= 500 AND l.reviewed_at >= ?
         AND ${problems ? "n.type = 'problem'" : "n.type != 'problem'"}
       ORDER BY l.id DESC LIMIT ?''',
    variables: [Variable.withInt(sinceMs), Variable.withInt(latest)],
  ).get();
  if (rows.length < minSamples) return fallback;
  final ms = [for (final r in rows) r.read<int>('ms')]..sort();
  final mid = ms.length ~/ 2;
  final median = ms.length.isOdd ? ms[mid].toDouble() : (ms[mid - 1] + ms[mid]) / 2;
  return (median / 1000).clamp(min, max);
}

/// Ordinary cards: 10 s until 20 answers exist (3 to 120 s).
Future<double> ordinarySeconds(AppDatabase db, {int sinceMs = 0, double fallback = 10, double min = 3, double max = 120}) =>
    typicalSeconds(db, problems: false, sinceMs: sinceMs, fallback: fallback, min: min, max: max);

/// Problem cards: 4 minutes until 10 answers exist (30 s to 10 min).
Future<double> problemSeconds(AppDatabase db, {int sinceMs = 0}) =>
    typicalSeconds(db, problems: true, sinceMs: sinceMs, latest: 60, minSamples: 10, fallback: 240, min: 30, max: 600);
