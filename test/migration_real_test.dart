import 'dart:io';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// The other migration tests wind a current database back by dropping columns. This one starts from the real
/// version-1 schema (test/fixtures/schema_v1.sql, dumped from the commit that shipped it), so a migration step that
/// only works on a "wound back" file is caught.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true; // the second database is only compared in shape
  test('a genuine v1 database upgrades to the latest schema, keeps its data and works', () async {
    final dir = Directory.systemTemp.createTempSync('mig_real');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/old.db');

    final raw = sql.sqlite3.open(f.path);
    raw.execute(File('test/fixtures/schema_v1.sql').readAsStringSync());
    raw.execute("INSERT INTO domain (id, name, created_at) VALUES (1, 'Old subject', 1000)");
    raw.execute("INSERT INTO syllabus_item (id, domain_id, title) VALUES (1, 1, 'Old topic')");
    raw.execute("INSERT INTO note (id, guid, domain_id, syllabus_item_id, type, fields_json, created_at) "
        "VALUES (1, 'g1', 1, 1, 'basic', '{\"front\":\"Q\",\"back\":\"A\"}', 1000)");
    raw.execute("INSERT INTO card (id, note_id, ord, state, due, stability, difficulty, reps, last_review) "
        "VALUES (1, 1, 0, 'review', 1000, 5.0, 5.0, 2, 500)");
    raw.execute("INSERT INTO fsrs_params (id, created_at, version, params_json, desired_retention) VALUES (1, 1, 'v', '[]', 0.9)");
    raw.execute("INSERT INTO review_log (card_id, reviewed_at, rating, state_before, due_before, elapsed_days, scheduled_days, fsrs_version, params_id) "
        "VALUES (1, 500, 3, 'new', 500, 0, 0, 'v', 1)");
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final db = AppDatabase(NativeDatabase(f));
    addTearDown(db.close);

    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, kSchemaVersion);
    final topic = await db.select(db.syllabusItems).getSingle();
    expect((topic.title, topic.targetCards, topic.rounds, topic.practice), ('Old topic', 10, 1, ''));
    final domain = await db.select(db.domains).getSingle();
    expect((domain.name, domain.learnWeight), ('Old subject', 2));
    expect((await db.select(db.cards).getSingle()).retiredAt, isNull);
    expect(await db.select(db.mediaItems).get(), isEmpty);
    expect(await db.select(db.readingItems).get(), isEmpty);
    expect(await db.select(db.syllabusPrereqs).get(), isEmpty);
    expect(await db.select(db.activityBuckets).get(), isEmpty);
    expect((await db.select(db.reviewLogs).get()).length, 1);

    // The old card is still due and the queue builds on the migrated file.
    final q = await QueueService(db, SettingsRepo(db)).build(now: DateTime.utc(2030, 1, 1, 12));
    expect(q.reviews.map((c) => c.id), [1]);

    // A fresh file made today has the same tables and columns as the migrated one.
    Future<Set<String>> shape(AppDatabase d) async {
      final tables = await d.customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'").get();
      final out = <String>{};
      for (final t in tables) {
        final name = t.read<String>('name');
        for (final c in await d.customSelect('PRAGMA table_info("$name")').get()) {
          out.add('$name.${c.read<String>('name')}');
        }
      }
      return out;
    }

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await shape(db), await shape(fresh));
  });
}
