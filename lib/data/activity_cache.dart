import 'package:drift/drift.dart';

import 'db/database.dart';
import 'settings_repo.dart';

/// 15 minutes: fine enough that a day rollover at any real-world UTC offset
/// (including :30 and :45 zones) never falls inside a bucket.
const kBucketMs = 900000;

/// Answers per 15-minute bucket, caught up incrementally from `review_log`.
///
/// A watermark (highest log id already counted) is stored with the buckets in the same
/// database and updated in the same transaction, so a crash or a restore can never leave
/// them disagreeing. Anything that removes or revokes an already-counted log must call
/// [onRevoked] or [invalidate]; [invalidate] simply rebuilds from the log on next use.
class ActivityCache {
  ActivityCache(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  static const watermarkKey = 'activity_through_log_id';

  /// Count log rows added since the last call. Cheap when nothing is new.
  Future<void> catchUp() => db.transaction(() async {
        final wm = await settings.getInt(watermarkKey, 0);
        final top = (await db.customSelect('SELECT COALESCE(MAX(id), 0) AS m FROM review_log').getSingle())
            .read<int>('m');
        if (top == wm) return;
        if (top < wm) {
          // The log shrank (rows deleted): the cache cannot be trusted.
          await db.customStatement('DELETE FROM activity_bucket');
          await settings.set(watermarkKey, '0');
          return catchUp();
        }
        final rows = await db.customSelect(
            'SELECT reviewed_at / $kBucketMs AS b, COUNT(*) AS n FROM review_log '
            'WHERE id > ? AND revoked_at IS NULL GROUP BY b',
            variables: [Variable.withInt(wm)]).get();
        for (final r in rows) {
          await db.customStatement(
              'INSERT INTO activity_bucket (bucket, n) VALUES (?, ?) '
              'ON CONFLICT(bucket) DO UPDATE SET n = n + excluded.n',
              [r.read<int>('b'), r.read<int>('n')]);
        }
        await settings.set(watermarkKey, '$top');
      });

  /// A log row was revoked (undo). Uncount it if it had already been counted.
  Future<void> onRevoked(int logId, int reviewedAt) async {
    if (logId > await settings.getInt(watermarkKey, 0)) return;
    final b = reviewedAt ~/ kBucketMs;
    await db.customStatement('UPDATE activity_bucket SET n = n - 1 WHERE bucket = ?', [b]);
    await db.customStatement('DELETE FROM activity_bucket WHERE n <= 0');
  }

  /// Throw the cache away; the next [catchUp] rebuilds it from the log.
  Future<void> invalidate() => db.transaction(() async {
        await db.customStatement('DELETE FROM activity_bucket');
        await settings.set(watermarkKey, '0');
      });

  /// Buckets with at least one answer, oldest first. Optionally from [sinceMs].
  Future<List<({int bucket, int n})>> buckets({int? sinceMs}) async {
    await catchUp();
    final rows = await db.customSelect(
        'SELECT bucket, n FROM activity_bucket WHERE bucket >= ? ORDER BY bucket',
        variables: [Variable.withInt(sinceMs == null ? 0 : sinceMs ~/ kBucketMs)]).get();
    return [for (final r in rows) (bucket: r.read<int>('bucket'), n: r.read<int>('n'))];
  }

  Future<int> total() async {
    await catchUp();
    final r = await db.customSelect('SELECT COALESCE(SUM(n), 0) AS t FROM activity_bucket').getSingle();
    return r.read<int>('t');
  }
}
