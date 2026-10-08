import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:daily_learning/data/backup/backup_service.dart';
import 'package:daily_learning/data/backup/backup_storage.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  late Directory tmp;
  late File dbFile;
  late AppDatabase db;
  late Directory backupDir;
  final t0 = DateTime.utc(2024, 3, 1, 12);

  AppDatabase open() => AppDatabase(NativeDatabase(dbFile));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('backup_test');
    dbFile = File('${tmp.path}/learning.db');
    backupDir = Directory('${tmp.path}/saf')..createSync();
    db = open();
  });
  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
    tmp.deleteSync(recursive: true);
  });

  Future<void> seed() async {
    final settings = SettingsRepo(db);
    final review = ReviewService(db, settings, ParamsRepo(db, settings));
    final imp = ImportService(db);
    final cards = [
      for (var i = 0; i < 12; i++)
        {
          'type': 'basic', 'front': 'Q$i unique?', 'back': 'A$i', 'source_type': 'quote',
          'supporting_quote': 'q', 'confidence': 'high'
        }
    ];
    await imp.commit(await imp.preview(jsonEncode({'domain': 'Bio', 'cards': cards})), now: t0);
    final rnd = Random(3);
    var now = t0;
    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();
    for (var i = 0; i < 60; i++) {
      now = now.add(Duration(hours: 1 + rnd.nextInt(30)));
      await review.review(
          cardId: ids[rnd.nextInt(ids.length)], rating: 1 + rnd.nextInt(4), durationMs: 900, now: now);
    }
  }

  test('ACCEPTANCE: export, wipe app data, restore -> identical counts, dues, review count', () async {
    await seed();
    final before = await fingerprint(db);
    expect(before.cards, 12);
    expect(before.reviews, 60);

    final storage = DirectoryBackupStorage(backupDir);
    final err = await BackupService(db, SettingsRepo(db)).export(storage, tmp, now: t0);
    expect(err, isNull);
    final files = await storage.list();
    expect(files.single.name, matches(r'^learning-backup-\d{8}\.db$'));

    // "Wipe app data".
    await db.close();
    dbFile.deleteSync();
    db = open();
    expect((await fingerprint(db)).cards, 0);

    final bytes = await storage.read(files.single);
    final report = await BackupService.restore(
      bytes: bytes,
      dbFile: dbFile,
      tmpDir: tmp,
      closeDb: () => db.close(),
      reopen: () async => db = open(),
    );
    expect(report.fingerprint, before);
    expect(await fingerprint(db), before);
    expect(report.clean, isTrue, reason: report.mismatches.join('\n'));
  });

  test('restore reports mismatches when the card cache disagrees with the log', () async {
    await seed();
    await (db.update(db.cards)..where((c) => c.id.equals(1)))
        .write(const CardsCompanion(stability: Value(777.0)));
    final storage = DirectoryBackupStorage(backupDir);
    await BackupService(db, SettingsRepo(db)).export(storage, tmp, now: t0);
    final bytes = await storage.read((await storage.list()).single);
    final report = await BackupService.restore(
      bytes: bytes, dbFile: dbFile, tmpDir: tmp,
      closeDb: () => db.close(), reopen: () async => db = open(),
    );
    expect(report.mismatches.map((m) => m.cardId), [1]);
  });

  test('keeps only the newest 8 backups', () async {
    final storage = DirectoryBackupStorage(backupDir);
    final svc = BackupService(db, SettingsRepo(db));
    for (var d = 1; d <= 11; d++) {
      expect(await svc.export(storage, tmp, now: DateTime(2024, 3, d, 12).toUtc()), isNull);
    }
    final names = (await storage.list()).map((f) => f.name).toList()..sort();
    expect(names.length, 8);
    expect(names.first, 'learning-backup-20240304.db');
    expect(names.last, 'learning-backup-20240311.db');
  });

  test('failed export is logged, not thrown', () async {
    final bad = DirectoryBackupStorage(Directory('${tmp.path}/does-not-exist'));
    final err = await BackupService(db, SettingsRepo(db)).export(bad, tmp, now: t0);
    expect(err, isNotNull);
    final log = await db.select(db.backupLogs).getSingle();
    expect(log.ok, isFalse);
    expect(log.error, isNotNull);
  });

  test('stale detection: > 7 days or never', () async {
    final svc = BackupService(db, SettingsRepo(db));
    expect(await svc.isStale(now: t0), isTrue);
    await svc.export(DirectoryBackupStorage(backupDir), tmp, now: t0);
    expect(await svc.isStale(now: t0.add(const Duration(days: 6))), isFalse);
    expect(await svc.isStale(now: t0.add(const Duration(days: 8))), isTrue);
  });

  test('restore rejects garbage and wrong schema version, and keeps live data', () async {
    await seed();
    final before = await fingerprint(db);

    Future<void> expectRejected(Uint8List bytes) async {
      await expectLater(
        BackupService.restore(
          bytes: bytes, dbFile: dbFile, tmpDir: tmp,
          closeDb: () => db.close(), reopen: () async => db = open(),
        ),
        throwsA(isA<BackupException>()),
      );
    }

    await expectRejected(Uint8List.fromList(utf8.encode('definitely not sqlite')));

    // Valid sqlite, wrong user_version.
    final other = File('${tmp.path}/other.db');
    final d = AppDatabase(NativeDatabase(other));
    await d.customSelect('SELECT 1').get();
    await d.customStatement('PRAGMA user_version = 99');
    await d.close();
    await expectRejected(other.readAsBytesSync());

    // Rejection happens before the live DB is touched.
    expect(await fingerprint(db), before);
  });

  test('restoring an OLDER (v1) backup upgrades it instead of refusing it', () async {
    await seed();
    final storage = DirectoryBackupStorage(backupDir);
    await BackupService(db, SettingsRepo(db)).export(storage, tmp, now: t0);
    final f = (await storage.list()).single;
    final before = await fingerprint(db);

    // Rewrite the backup file so it looks like it came from schema v1.
    final raw = sql.sqlite3.open(f.uri);
    raw.execute('DROP TABLE syllabus_prereq');
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN target_cards');
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN description');
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN rounds');
    raw.execute('ALTER TABLE domain DROP COLUMN learn_weight');
    raw.execute('ALTER TABLE domain DROP COLUMN revisit');
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final report = await BackupService.restore(
      bytes: await storage.read(f), dbFile: dbFile, tmpDir: tmp,
      closeDb: () => db.close(), reopen: () async => db = open(),
    );
    expect(report.fingerprint, before);
    expect(report.clean, isTrue);
    expect(await db.select(db.syllabusPrereqs).get(), isEmpty); // new table exists
  });
}
