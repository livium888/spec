// How the app behaves with a big, long-lived library: 12,000 cards, 400 topics, 120,000 answers.
// Prints timings; the asserts are generous ceilings so a slow regression fails the build.
import 'dart:io';

import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/knowledge_service.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/retire_service.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:daily_learning/domain/retire.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const kCards = 12000, kTopics = 400, kLogs = 120000, kDomains = 12;

Future<int> timed(String label, Future<Object?> Function() f, {int runs = 3}) async {
  final ms = <int>[];
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    await f();
    ms.add(sw.elapsedMilliseconds);
  }
  ms.sort();
  // ignore: avoid_print
  print('PERF ${label.padRight(34)} median ${ms[ms.length ~/ 2].toString().padLeft(5)} ms   (runs: ${ms.join(', ')})');
  return ms[ms.length ~/ 2];
}

void main() {
  late AppDatabase db;
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('perf');
    db = AppDatabase(NativeDatabase(File('${dir.path}/perf.db')));
    final settings = SettingsRepo(db);
    final params = ParamsRepo(db, settings);
    final paramsId = await params.activeId();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var d = 1; d <= kDomains; d++) {
      await db.into(db.domains).insert(DomainsCompanion.insert(name: 'Subject $d', createdAt: now));
    }
    for (var t = 1; t <= kTopics; t++) {
      await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(
          domainId: ((t - 1) % kDomains) + 1, title: 'Topic $t', position: Value(t), targetCards: const Value(30)));
    }
    await db.customStatement('''
      WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i < $kCards)
      INSERT INTO note (guid, domain_id, syllabus_item_id, type, fields_json, tags, source_type, source_ref, llm_confidence, created_at)
      SELECT 'g'||i, ((i % $kTopics) % $kDomains) + 1, (i % $kTopics) + 1, 'basic',
             json_object('front', 'Question number '||i||' about the topic?', 'back', 'Answer '||i, 'why_it_matters', 'Because reason '||i),
             '', 'model_memory', '', 'high', $now + i FROM seq''');
    await db.customStatement('''
      INSERT INTO card (note_id, ord, state, step, due, stability, difficulty, reps, lapses, last_review)
      SELECT id, 0,
             CASE WHEN id % 300 = 0 THEN 'learning' WHEN id % 10 < 8 THEN 'review' ELSE 'new' END, 0,
             CASE WHEN id % 300 = 0 THEN $now - (id % 30) * 60000
                  WHEN id % 10 < 8 THEN $now + ((id * 37) % 400 - 20) * 86400000 ELSE $now END,
             CASE WHEN id % 10 < 8 THEN 5 + (id % 50) * 3.0 END, CASE WHEN id % 10 < 8 THEN 3 + (id % 6) END,
             CASE WHEN id % 10 < 8 THEN 4 ELSE 0 END, id % 3,
             CASE WHEN id % 10 < 8 THEN $now - ((id % 60) + 1) * 86400000 END
      FROM note''');
    await db.customStatement('''
      WITH RECURSIVE seq(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM seq WHERE i < $kLogs)
      INSERT INTO review_log (card_id, reviewed_at, rating, duration_ms, state_before, due_before, stability_before, difficulty_before,
                              elapsed_days, scheduled_days, fsrs_version, params_id)
      SELECT 1 + (i % $kCards), $now - (i % 365) * 86400000 - (i % 12) * 900000 - (i % 900) * 1000, 1 + (i % 4), 6000, 'review', $now, 10.0, 5.0,
             3.0, 8.0, 'perf', $paramsId FROM seq''');
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('timings with 12,000 cards, 400 topics and 120,000 answers', () async {
    final settings = SettingsRepo(db);
    final params = ParamsRepo(db, settings);
    final queue = QueueService(db, settings);
    final results = <String, int>{};
    results['queue.build'] = await timed('QueueService.build', () => queue.build());
    results['stats'] = await timed('StatsService.compute', () => StatsService(db, settings).compute());
    final learn = LearnService(db, settings, queue);
    results['learn.view'] = await timed('LearnService.view', () => learn.view());
    results['learn.advice'] = await timed('LearnService.advice', () => learn.advice());
    results['knowledge'] = await timed('KnowledgeService.forDomain', () => KnowledgeService(db, params).forDomain(1));
    final edit = CardEditService(db, settings);
    results['browse'] = await timed('Browse: first page', () => edit.search());
    results['browse.search'] = await timed('Browse: search text', () => edit.search(query: 'number 777'));
    results['retire'] = await timed('RetireService.summary', () => RetireService(db).summary(const RetireCriteria()));
    final review = ReviewService(db, settings, params);
    final next = (await queue.build()).next!;
    results['answer'] = await timed('ReviewService.review (one answer)', () => review.review(cardId: next.id, rating: 3, durationMs: 4000), runs: 1);
    results['rebuild'] = await timed('rebuildAll (replay 120k answers)', () => review.rebuildAll(apply: false), runs: 1);
    // ignore: avoid_print
    print('PERF summary: ${results.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
    // Ceilings are about 10x what this sandbox measures, so a slow CI machine does not flake but an
    // accidental full scan (the kind D46 removed) fails.
    const ceilings = {'queue.build': 600, 'stats': 1500, 'learn.view': 2500, 'learn.advice': 800, 'knowledge': 300, 'answer': 500, 'rebuild': 20000};
    for (final e in ceilings.entries) {
      final v = results[e.key];
      if (v != null) expect(v, lessThan(e.value), reason: '${e.key} took $v ms');
    }
  },timeout: const Timeout(Duration(minutes: 10)));
}
