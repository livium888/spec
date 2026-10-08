import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../db/database.dart';
import '../params_repo.dart';
import '../review_service.dart';
import '../settings_repo.dart';
import 'backup_storage.dart';

const kKeepBackups = 8;
const _prefix = 'learning-backup-';

String backupFileName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '$_prefix${t.year}${two(t.month)}${two(t.day)}.db.gz';
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Counts that the acceptance test compares before wipe and after restore.
class DbFingerprint {
  const DbFingerprint(this.cards, this.reviews, this.notes, this.dueSum, this.dueMax);
  final int cards, reviews, notes, dueSum, dueMax;
  @override
  bool operator ==(Object other) =>
      other is DbFingerprint &&
      other.cards == cards &&
      other.reviews == reviews &&
      other.notes == notes &&
      other.dueSum == dueSum &&
      other.dueMax == dueMax;
  @override
  int get hashCode => Object.hash(cards, reviews, notes, dueSum, dueMax);
  @override
  String toString() => 'cards=$cards reviews=$reviews notes=$notes dueSum=$dueSum dueMax=$dueMax';
}

Future<DbFingerprint> fingerprint(AppDatabase db) async {
  Future<int> n(String q) async =>
      (await db.customSelect(q).getSingle()).read<int>('n');
  return DbFingerprint(
    await n('SELECT COUNT(*) AS n FROM card'),
    await n('SELECT COUNT(*) AS n FROM review_log'),
    await n('SELECT COUNT(*) AS n FROM note'),
    await n('SELECT COALESCE(SUM(due),0) AS n FROM card'),
    await n('SELECT COALESCE(MAX(due),0) AS n FROM card'),
  );
}

class RestoreReport {
  const RestoreReport(this.fingerprint, this.mismatches);
  final DbFingerprint fingerprint;

  /// Cards whose stored scheduling differs from a replay of their log.
  final List<Mismatch> mismatches;
  bool get clean => mismatches.isEmpty;
}

/// ExportBackup / RestoreBackup use cases.
class BackupService {
  BackupService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  static const lastSuccessKey = 'last_backup_ok_ms';

  /// Consistent snapshot via `VACUUM INTO` (no WAL leftovers, no torn copy), gzip-compressed
  /// to a temp file in streaming chunks. Caller deletes the returned file.
  Future<File> snapshotFile(Directory tmpDir) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final raw = File('${tmpDir.path}/snapshot-$stamp.db');
    final zipped = File('${tmpDir.path}/snapshot-$stamp.db.gz');
    try {
      await db.customStatement("VACUUM INTO '${raw.path.replaceAll("'", "''")}'");
      await raw.openRead().transform(gzip.encoder).pipe(zipped.openWrite());
      return zipped;
    } catch (_) {
      if (zipped.existsSync()) zipped.deleteSync();
      rethrow;
    } finally {
      if (raw.existsSync()) raw.deleteSync();
    }
  }

  /// Export to [storage], keep the newest [kKeepBackups], log the outcome.
  /// Never throws; returns the error message or null on success.
  Future<String?> export(BackupStorage storage, Directory tmpDir, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    try {
      final snapshot = await snapshotFile(tmpDir);
      final BackupFile f;
      try {
        f = await storage.writeFile(backupFileName(t.toLocal()), snapshot);
      } finally {
        snapshot.deleteSync();
      }
      await _prune(storage);
      await db.into(db.backupLogs).insert(BackupLogsCompanion.insert(
          ts: t.millisecondsSinceEpoch, uri: Value(f.uri), bytes: Value(f.length), ok: true));
      await settings.set(lastSuccessKey, '${t.millisecondsSinceEpoch}');
      return null;
    } catch (e) {
      await db.into(db.backupLogs).insert(BackupLogsCompanion.insert(
          ts: t.millisecondsSinceEpoch, ok: false, error: Value('$e')));
      return '$e';
    }
  }

  Future<void> _prune(BackupStorage storage) async {
    final files = (await storage.list()).where((f) => f.name.startsWith(_prefix) && (f.name.endsWith('.db') || f.name.endsWith('.db.gz'))).toList()
      ..sort((a, b) => b.name.compareTo(a.name)); // names embed the date: newest first
    for (final old in files.skip(kKeepBackups)) {
      await storage.delete(old);
    }
  }

  /// Backup is due if none succeeded in the last [days] days.
  Future<bool> isStale({int days = 7, DateTime? now}) async {
    final last = await settings.getInt(lastSuccessKey, 0);
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return last == 0 || t - last > days * 86400000;
  }

  // ---- restore ---------------------------------------------------------------

  static Future<void> _stage(File source, File staged) async {
    final head = await source.openRead(0, 2).expand((c) => c).toList();
    final isGzip = head.length == 2 && head[0] == 0x1f && head[1] == 0x8b;
    if (isGzip) {
      await source.openRead().transform(gzip.decoder).pipe(staged.openWrite());
    } else {
      await source.copy(staged.path);
    }
  }

  /// Validate an UNTRUSTED backup file before touching the live DB.
  /// Throws [BackupException] with a human-readable reason.
  static void validate(File candidate) {
    final sql.Database d;
    try {
      d = sql.sqlite3.open(candidate.path, mode: sql.OpenMode.readOnly);
    } catch (e) {
      throw BackupException('Not a readable SQLite database.');
    }
    try {
      final v = d.select('PRAGMA user_version').first.values.first as int;
      // Older backups are upgraded by the normal migration when the DB is reopened;
      // a backup from a NEWER app cannot be read safely.
      if (v > kSchemaVersion) {
        throw BackupException(
            'This backup was made by a newer version of the app (schema $v, this app understands up to $kSchemaVersion). Update the app first.');
      }
      if (v < 1) throw BackupException('Not a Daily Learning backup (schema version $v).');
      final integrity = d.select('PRAGMA integrity_check').first.values.first;
      if (integrity != 'ok') throw BackupException('Backup failed integrity check: $integrity');
      final tables = d
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'] as String)
          .toSet();
      for (final t in const ['card', 'note', 'review_log', 'fsrs_params', 'domain']) {
        if (!tables.contains(t)) throw BackupException('Backup is missing table "$t".');
      }
    } on sql.SqliteException catch (e) {
      throw BackupException('Not a valid backup: ${e.message}');
    } finally {
      d.close();
    }
  }

  /// Replace the live DB file with the backup in [source] (gzip or plain SQLite; detected
  /// by content, streamed, never loaded whole), then verify by replaying the log.
  /// [closeDb] must close the live database; [reopen] returns a fresh one on
  /// the same file. The previous file is kept as `<db>.pre-restore` until the
  /// new one validates, and put back on any failure.
  static Future<RestoreReport> restore({
    required File source,
    required File dbFile,
    required Directory tmpDir,
    required Future<void> Function() closeDb,
    required Future<AppDatabase> Function() reopen,
  }) async {
    final staged = File('${tmpDir.path}/restore-candidate.db');
    try {
      await _stage(source, staged);
      validate(staged);
    } catch (e) {
      if (staged.existsSync()) staged.deleteSync();
      if (e is BackupException) rethrow;
      throw BackupException('Could not read the backup file: $e');
    }

    await closeDb();
    final safety = File('${dbFile.path}.pre-restore');
    if (safety.existsSync()) safety.deleteSync();
    if (dbFile.existsSync()) dbFile.renameSync(safety.path);
    for (final ext in const ['-wal', '-shm']) {
      final side = File('${dbFile.path}$ext');
      if (side.existsSync()) side.deleteSync();
    }
    staged.copySync(dbFile.path);
    staged.deleteSync();

    try {
      final fresh = await reopen();
      final settings = SettingsRepo(fresh);
      final review = ReviewService(fresh, settings, ParamsRepo(fresh, settings));
      final mism = await review.rebuildAll(apply: false); // report only, do not "fix"
      return RestoreReport(await fingerprint(fresh), mism);
    } catch (e) {
      if (dbFile.existsSync()) dbFile.deleteSync();
      if (safety.existsSync()) safety.renameSync(dbFile.path);
      throw BackupException('Restore failed, previous data kept: $e');
    }
  }
}
