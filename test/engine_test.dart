import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/engine_service.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/engine.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2024, 3, 1, 12);

  test('EngineFeatures per domain', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = SettingsRepo(db);
    final review = ReviewService(db, s, ParamsRepo(db, s));
    final imp = ImportService(db);
    Map<String, dynamic> card(String f) => {
          'type': 'basic', 'front': f, 'back': 'b', 'source_type': 'quote',
          'supporting_quote': 'q', 'confidence': 'high'
        };
    await imp.commit(await imp.preview(jsonEncode({'domain': 'A', 'cards': [card('a1?'), card('a2?')]})), now: t0);
    await imp.commit(await imp.preview(jsonEncode({'domain': 'B', 'cards': [card('b1?')]})), now: t0);
    final cards = await db.select(db.cards).get();
    final a1 = cards[0].id;

    // a1: Easy (-> review), later a pass, later a lapse.
    await review.review(cardId: a1, rating: 4, durationMs: 1, now: t0);
    var due = DateTime.fromMillisecondsSinceEpoch((await db.select(db.cards).get())[0].due, isUtc: true);
    await review.review(cardId: a1, rating: 3, durationMs: 1, now: due);
    due = DateTime.fromMillisecondsSinceEpoch((await db.select(db.cards).get())[0].due, isUtc: true);
    await review.review(cardId: a1, rating: 1, durationMs: 1, now: due);

    final doms = await db.select(db.domains).get();
    final interest = InterestService(db);
    await interest.record(doms[0].id, 1, now: due);
    await interest.record(doms[0].id, -1, now: due);
    await interest.record(doms[0].id, 1, now: due);

    final f = await EngineFeaturesService(db, s).compute(now: due.add(const Duration(days: 2)));
    final a = f.domains.firstWhere((d) => d.domainName == 'A');
    final b = f.domains.firstWhere((d) => d.domainName == 'B');
    // Intervals (~2 weeks, then ~7 weeks) push the first two answers outside the
    // 30-day window; only the final lapse is inside it.
    expect(a.reviews30d, 1);
    expect(a.retention30d, closeTo(0.0, 1e-9));
    expect(a.lapseRate30d, closeTo(1.0, 1e-9));
    expect(a.avgInterest30d, closeTo(1 / 3, 1e-9));
    expect(a.newCardsAdded30d, 0); // created at t0, long before the window
    expect(a.daysSinceLastSession, closeTo(2, 1e-6));
    expect(b.reviews30d, 0);
    expect(b.retention30d, isNull);
    expect(b.daysSinceLastSession, isNull);
    expect(f.toJson()['domains'], isA<List>());
  });

  test('RoundRobinEngine cycles and handles empty', () {
    DomainFeatures d(int id) => DomainFeatures(
        domainId: id, domainName: 'd$id', daysSinceLastSession: null, reviews30d: 0,
        retention30d: null, desiredRetention: 0.9, lapseRate30d: null, leechCount: 0,
        dueBacklog: 0, newCardsAdded30d: 0, avgInterest30d: null, cardsSurviving30d: 0);
    final e = RoundRobinEngine();
    final f = EngineFeatures(0, [d(3), d(1), d(2)]);
    expect([for (var s = 0; s < 4; s++) e.next(f, s).domainId], [1, 2, 3, 1]);
    expect(e.next(const EngineFeatures(0, []), 0).domainId, isNull);
  });

  test('engine_decision can be written', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await EngineFeaturesService(db, SettingsRepo(db)).recordDecision(
        engineVersion: 'x', seed: 1, features: EngineFeatures(1, []), scores: {}, chosen: {'d': 1});
    expect((await db.select(db.engineDecisions).get()).length, 1);
  });

  test('prompt builder: renders all variables once, logs, lists recent titles', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final imp = ImportService(db);
    await imp.commit(await imp.preview(jsonEncode({'domain': 'Bio', 'cards': [
      {'type': 'basic', 'front': 'What is ATP?', 'back': 'b', 'source_type': 'quote', 'supporting_quote': 'q', 'confidence': 'high'}
    ]})));
    final dom = (await db.select(db.domains).getSingle());
    final r = await PromptService(db).build(
        domainId: dom.id, n: 7, sourceText: 'Text with {n} and {domain} inside.');
    expect(r.text, contains('Create 7 flashcards for the domain "Bio"'));
    expect(r.text, contains('- What is ATP?'));
    expect(r.text, contains('Text with {n} and {domain} inside.')); // not re-expanded
    expect(r.text, contains('{{c1::hidden text}}'));
    expect(r.text, isNot(contains('{recent_titles}')));
    final log = await db.select(db.promptLogs).getSingle();
    expect(log.templateVersion, kPromptTemplateVersion);
    expect(log.cardsRequested, 7);
    expect(log.status, 'issued');
  });

  test('rendered prompt with no source/syllabus', () {
    final p = renderPrompt(domain: 'X', syllabusItem: null, n: 3, recentTitles: [], sourceText: null);
    expect(p, contains('"syllabus_item": null'));
    expect(p, contains('model_memory'));
    expect(normalizeText('Hello,  <b>World</b>!'), 'hello world');
  });
}
