import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/learn_planner.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

const _cap = Capacity(dueReviews: 0, avgSecondsPerReview: 12, budgetMinutes: 20);
const planner = LearnPlanner();

ItemStats done(int id, String title,
        {int domain = 1, double? since = 200, int rounds = 1, int cards = 10, int target = 10, String status = 'done'}) =>
    ItemStats(
      id: id, domainId: domain, domainName: 'Arts', title: title, position: id, status: status,
      targetCards: target, cardCount: cards, rounds: rounds, daysSinceCovered: since,
    );

DomainInfo dom({int id = 1, int weight = 2, bool revisit = true}) =>
    DomainInfo(id: id, name: 'Arts', itemCount: 3, weight: weight, revisit: revisit);

LearnPlan plan(List<ItemStats> items, List<DomainInfo> doms, {int seed = 1, LearnPlanner p = planner}) =>
    p.plan(domains: doms, items: items, capacity: _cap, seed: seed);

void main() {
  renamedSubjectTests();
  group('revisit rules (pure)', () {
    test('cool-down doubles each round and is capped at 12 years', () {
      expect([for (var r = 1; r <= 4; r++) planner.cooldownDays(r)], [90, 180, 360, 720]);
      expect(planner.cooldownDays(7), 4380); // 90 * 64 = 5760 -> capped at 12 years
      expect(planner.cooldownDays(30), 4380);
      expect(const LearnPlanner(revisitBaseMonths: 1).cooldownDays(1), 30);
    });

    test('a finished topic is NOT offered before its rest, and IS offered after it', () {
      expect(plan([done(1, 'Colour theory', since: 60)], [dom()]).options, isEmpty);
      final p = plan([done(1, 'Colour theory', since: 100)], [dom()]);
      expect(p.options.single.action, LearnAction.revisit);
      expect(p.options.single.count, 5);
      expect(p.options.single.reasons.single, contains('3 months ago'));
      expect(p.options.single.reasons.single, contains('round 1'));
    });

    test('"used it once" is wrong: the same topic returns years later', () {
      // Round 8 would wait 90*128 days, but the rest is capped at 12 years (4380 days).
      expect(plan([done(1, 'Colour theory', since: 11 * 365.0, rounds: 8)], [dom()]).options, isEmpty);
      final p = plan([done(1, 'Colour theory', since: 12 * 365.0 + 10, rounds: 8)], [dom()]);
      expect(p.options.single.action, LearnAction.revisit);
      expect(p.options.single.reasons.single, contains('years ago'));
      // and a higher round waits longer
      expect(plan([done(1, 'Colour theory', since: 300, rounds: 3)], [dom()]).options, isEmpty); // needs 360
    });

    test('later rounds wait longer than earlier ones', () {
      expect(plan([done(1, 'x', since: 200, rounds: 1)], [dom()]).options, isNotEmpty);
      expect(plan([done(1, 'x', since: 200, rounds: 2)], [dom()]).options, isNotEmpty); // 180
      expect(plan([done(1, 'x', since: 200, rounds: 3)], [dom()]).options, isEmpty); // 360
    });

    test('empty state reports when the next revisit is due', () {
      final p = plan([done(1, 'x', since: 60)], [dom()]);
      expect(p.emptyReason, EmptyReason.allDone);
      expect(p.nextRevisitInDays, closeTo(30, 1e-9));
    });

    test('only the most overdue finished topic per subject is a candidate', () {
      final p = plan([done(1, 'a', since: 100), done(2, 'b', since: 300), done(3, 'c', since: 150)], [dom()]);
      expect(p.candidates.where((c) => c.action == LearnAction.revisit).map((c) => c.item.title), ['b']);
    });

    test('topics with no cards or revisit switched off never come back', () {
      expect(plan([done(1, 'x', since: 500, cards: 0)], [dom()]).options, isEmpty);
      expect(plan([done(1, 'x', since: 500)], [dom(revisit: false)]).options, isEmpty);
    });
  });

  group('learner controls (pure)', () {
    test('weight 0 pauses a subject completely; weights rescale the others', () {
      final items = [
        ItemStats(id: 1, domainId: 1, domainName: 'Arts', title: 'A', position: 1, status: 'todo', targetCards: 10, cardCount: 0),
        ItemStats(id: 2, domainId: 2, domainName: 'Music', title: 'M', position: 1, status: 'todo', targetCards: 10, cardCount: 0),
      ];
      DomainInfo d(int id, int w) => DomainInfo(id: id, name: id == 1 ? 'Arts' : 'Music', itemCount: 1, weight: w);
      var p = plan(items, [d(1, 0), d(2, 2)]);
      expect(p.options.map((o) => o.item.id), [2]);

      p = plan(items, [d(1, 3), d(2, 1)]);
      expect(p.options.first.item.id, 1);
      expect(p.options.first.score, greaterThan(p.options[1].score * 1.5));

      p = plan(items, [d(1, 0), d(2, 0)]);
      expect(p.emptyReason, EmptyReason.allPaused);
    });

    test('a paused subject does not supply revisits or the next-revisit hint', () {
      final p = plan([done(1, 'x', since: 500)], [dom(weight: 0)]);
      expect(p.options, isEmpty);
      expect(p.nextRevisitInDays, isNull);
    });

    test('skipped topics are never offered and do not block what follows', () {
      final items = [
        ItemStats(id: 1, domainId: 1, domainName: 'Arts', title: 'A', position: 1, status: 'skipped', targetCards: 10, cardCount: 0),
        ItemStats(id: 2, domainId: 1, domainName: 'Arts', title: 'B', position: 2, status: 'todo', targetCards: 10, cardCount: 0, prereqIds: const [1]),
      ];
      final p = plan(items, [dom()]);
      expect(p.options.single.item.title, 'B');
      expect(LearnPlanner.effectiveStatus('skipped', 99, 10), 'skipped');
    });
  });

  group('lifelong scenario (service)', () {
    late AppDatabase db;
    late SettingsRepo settings;
    late LearnService learn;
    late OutlineService out;
    late ImportService imp;
    final d0 = DateTime.utc(2024, 1, 10, 12);
    DateTime day(int n) => d0.add(Duration(days: n));

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      settings = SettingsRepo(db);
      learn = LearnService(db, settings, QueueService(db, settings));
      out = OutlineService(db);
      imp = ImportService(db);
      await out.commit(
          await out.preview(jsonEncode({
            'domain': 'Arts',
            'items': [
              {'title': 'Colour theory', 'target_cards': 5},
            ],
          })),
          now: d0);
    });
    tearDown(() => db.close());

    Future<void> cards(int n, String tag, DateTime at) async {
      final c = [
        for (var i = 0; i < n; i++)
          {
            'type': 'basic', 'front': 'Colour $tag question $i?', 'back': 'a',
            'source_type': 'quote', 'supporting_quote': 'q', 'confidence': 'high'
          }
      ];
      await imp.commit(await imp.preview(jsonEncode({'domain': 'Arts', 'syllabus_item': 'Colour theory', 'cards': c})), now: at);
    }

    test('offered today, again in 3 months with new angles, again later, and never repeating cards', () async {
      // Round 1 today.
      var v = await learn.view(now: d0);
      expect(v.plan.options.single.action, LearnAction.newItem);
      final g1 = await learn.choose(v.plan.options.single, v, now: d0);
      expect(g1.text, isNot(contains('studied before')));
      await cards(5, 'first', d0);

      // Resting: nothing to offer, and the app says when it comes back.
      v = await learn.view(now: day(60));
      expect(v.plan.options, isEmpty);
      expect(v.plan.emptyReason, EmptyReason.allDone);
      expect(v.plan.nextRevisitInDays, closeTo(30, 1));
      expect((await learn.returnsInDays(now: day(60))).values.single, closeTo(30, 1));

      // After 3 months: the SAME topic returns for a deeper pass.
      v = await learn.view(now: day(100));
      expect(v.plan.options.single.action, LearnAction.revisit);
      final g2 = await learn.choose(v.plan.options.single, v, now: day(100));
      expect(g2.text, contains('round 2'));
      expect(g2.text, contains('go deeper than the basics'));
      expect(g2.text, contains('Colour first question 0?'), reason: 'existing cards are excluded');
      var item = await db.select(db.syllabusItems).getSingle();
      expect((item.rounds, item.targetCards, item.status), (2, 10, 'active'));
      expect((await db.select(db.promptLogs).get()).last.templateVersion, 'v7+deeper');
      expect(((await db.select(db.engineDecisions).get()).last.chosenJson), contains('revisit'));

      // Until the new cards arrive it is "in progress", and a repeat press shows the pending prompt.
      v = await learn.view(now: day(101));
      expect(v.pending?.id, g2.logId);
      await cards(5, 'second', day(101));
      item = await db.select(db.syllabusItems).getSingle();
      expect(item.status, 'done');

      // Round 2 rests twice as long: not at +100+120, yes at +100+190.
      expect((await learn.view(now: day(101 + 120))).plan.options, isEmpty);
      v = await learn.view(now: day(101 + 190));
      expect(v.plan.options.single.action, LearnAction.revisit);
      final g3 = await learn.choose(v.plan.options.single, v, now: day(101 + 190));
      expect(g3.text, contains('round 3'));
      expect(g3.text, contains('Colour second question 0?'));
    });

    test('twelve years later it still comes back', () async {
      await cards(5, 'old', d0);
      await (db.update(db.syllabusItems)).write(const SyllabusItemsCompanion(rounds: Value(8)));
      expect((await learn.view(now: day(365 * 6))).plan.options, isEmpty); // 4380-day cap not yet reached
      final v = await learn.view(now: day(365 * 12 + 5));
      expect(v.plan.options.single.action, LearnAction.revisit);
      expect(v.plan.options.single.reasons.single, contains('years ago'));
    });

    test('the settings that control it actually take effect', () async {
      await cards(5, 'x', d0);
      final domainId = (await db.select(db.domains).getSingle()).id;

      // Shorter first rest.
      await settings.set(SettingsRepo.revisitMonths, '1');
      expect((await learn.view(now: day(40))).plan.options.single.action, LearnAction.revisit);
      await settings.set(SettingsRepo.revisitMonths, '6');
      expect((await learn.view(now: day(100))).plan.options, isEmpty);
      await settings.set(SettingsRepo.revisitMonths, '3');

      // Revisit off for the subject.
      await learn.setSubjectRevisit(domainId, false);
      expect((await learn.view(now: day(200))).plan.options, isEmpty);
      await learn.setSubjectRevisit(domainId, true);
      expect((await learn.view(now: day(200))).plan.options, isNotEmpty);

      // Paused subject.
      await learn.setSubjectWeight(domainId, 0);
      final v = await learn.view(now: day(200));
      expect(v.plan.options, isEmpty);
      expect(v.plan.emptyReason, EmptyReason.allPaused);
      await learn.setSubjectWeight(domainId, 2);

      // Skipping a topic.
      final itemId = (await db.select(db.syllabusItems).getSingle()).id;
      await learn.setTopicSkipped(itemId, true);
      expect((await db.select(db.syllabusItems).getSingle()).status, 'skipped');
      expect((await learn.view(now: day(200))).plan.options, isEmpty);
      await learn.setTopicSkipped(itemId, false);
      expect((await db.select(db.syllabusItems).getSingle()).status, 'done'); // cards still there
    });
  });

  test('migration v2 -> v3 keeps data and defaults the new settings', () async {
    final dir = Directory.systemTemp.createTempSync('mig3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/m.db');
    var db = AppDatabase(NativeDatabase(f));
    final d = await db.into(db.domains).insert(DomainsCompanion.insert(name: 'Old', createdAt: 1));
    await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(domainId: d, title: 'T'));
    await db.close();

    final raw = sql.sqlite3.open(f.path);
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN rounds');
    raw.execute('ALTER TABLE domain DROP COLUMN learn_weight');
    raw.execute('ALTER TABLE domain DROP COLUMN revisit');
    raw.execute('ALTER TABLE domain DROP COLUMN retention');
    raw.execute('ALTER TABLE domain DROP COLUMN speech_lang');
    raw.execute('ALTER TABLE domain DROP COLUMN speech_side');
    raw.execute('DROP TABLE IF EXISTS media'); // added in v6
    raw.execute('DROP TABLE IF EXISTS reading_item'); // added in v8
    raw.execute('ALTER TABLE card DROP COLUMN retired_at'); // added in v6
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    db = AppDatabase(NativeDatabase(f));
    addTearDown(db.close);
    final dm = await db.select(db.domains).getSingle();
    expect((dm.name, dm.learnWeight, dm.revisit), ('Old', 2, true));
    expect((await db.select(db.syllabusItems).getSingle()).rounds, 1);
  });
}

// ---- the AI renames the subject: the asked-for topic must still be answered ----
void renamedSubjectTests() {
  group('answer with a renamed subject', () {
    late AppDatabase db;
    late LearnService learn;
    late ImportService imp;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final s = SettingsRepo(db);
      learn = LearnService(db, s, QueueService(db, s));
      imp = ImportService(db);
      final out = OutlineService(db);
      await out.commit(await out.preview(
          '{"domain":"Psychology and Influence","items":[{"title":"Memory and attention","target_cards":5},{"title":"Biases","target_cards":5}]}'));
      await out.commit(await out.preview('{"domain":"Music","items":[{"title":"Rhythm","target_cards":5}]}'));
    });
    tearDown(() => db.close());

    String cards(String domain, String? item, int n) => jsonEncode({
          'domain': domain,
          'syllabus_item': item,
          'cards': [
            for (var i = 0; i < n; i++)
              {'type': 'basic', 'front': 'Question $domain $i?', 'back': 'A', 'source_type': 'model_memory', 'source_ref': '', 'supporting_quote': '', 'confidence': 'high'}
          ]
        });

    test('"&" for "and": cards go to the subject that was asked for, so the topic is no longer offered again', () async {
      final v = await learn.view();
      final top = v.plan.options.first;
      await learn.choose(top, v);
      final name = top.item.domainName;
      final renamed = '${name.replaceAll(' and ', ' & ')} (AI edition)';
      final p = await imp.preview(cards(renamed, top.item.title, top.count));
      expect(p.renamedFrom, renamed);
      expect(p.domain, name);
      expect(p.newDomain, isFalse);
      await imp.commit(p);
      expect((await db.select(db.domains).get()).length, 2); // no stray third subject
      final v2 = await learn.view();
      expect(v2.plan.options.first.item.id, isNot(top.item.id));
    });

    test('a different topic title but a similar subject name still maps to the asked subject', () async {
      final v = await learn.view();
      final top = v.plan.options.first;
      await learn.choose(top, v);
      final p = await imp.preview(cards('${top.item.domainName} 101', 'Totally rephrased title', 3));
      expect(p.domain, top.item.domainName);
    });

    test('a genuinely different subject is NOT forced into the asked one', () async {
      final v = await learn.view();
      await learn.choose(v.plan.options.first, v);
      final p = await imp.preview(cards('Chess openings', null, 3));
      expect(p.renamedFrom, isNull);
      expect(p.newDomain, isTrue);
      expect(p.domain, 'Chess openings');
    });

    test('with no prompt outstanding nothing is remapped', () async {
      final p = await imp.preview(cards('Psychology & Influence', null, 2));
      expect(p.renamedFrom, isNull);
      expect(p.newDomain, isTrue);
    });
  });
}
