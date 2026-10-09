import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/learn_planner.dart';
import 'package:daily_learning/domain/outline_parser.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

String outline(List<Map<String, dynamic>> items, {String domain = 'Bio'}) =>
    jsonEncode({'domain': domain, 'items': items});

Map<String, dynamic> topic(String title, {List<String> pre = const [], int target = 10}) =>
    {'title': title, 'level': 1, 'target_cards': target, 'prerequisites': pre};

const _cap = Capacity(dueReviews: 0, avgSecondsPerReview: 12, budgetMinutes: 20);

ItemStats item(int id, String title,
        {int domain = 1,
        String status = 'todo',
        int cards = 0,
        int target = 10,
        List<int> pre = const [],
        int leeches = 0,
        int reviews = 0,
        int lapses = 0}) =>
    ItemStats(
      id: id, domainId: domain, domainName: 'Bio', title: title, position: id,
      status: status, targetCards: target, cardCount: cards, prereqIds: pre,
      leechCount: leeches, reviews30d: reviews, lapses30d: lapses,
    );

const _dom = DomainInfo(id: 1, name: 'Bio', itemCount: 3);

void main() {
  group('outline parser', () {
    test('valid outline, defaults, detection', () {
      final raw = outline([topic('A'), topic('B', pre: ['A'])]);
      expect(detectPayloadKind(raw), 'outline');
      expect(detectPayloadKind('{"domain":"x","cards":[]}'), 'cards');
      final p = parseOutlineJson(raw);
      expect(p.hasFatal, isFalse);
      expect(p.items.every((i) => i.valid), isTrue);
    });

    test('fatal: duplicates, self reference, loop, bad shape', () {
      expect(parseOutlineJson('nope').hasFatal, isTrue);
      expect(parseOutlineJson(outline([topic('A'), topic('a')])).fatalErrors.join(), contains('Duplicate'));
      expect(parseOutlineJson(outline([topic('A', pre: ['A'])])).fatalErrors.join(), contains('itself'));
      final loop = parseOutlineJson(outline([topic('A', pre: ['C']), topic('B', pre: ['A']), topic('C', pre: ['B'])]));
      expect(loop.fatalErrors.join(), contains('loop'));
      expect(parseOutlineJson('{"domain":"","items":[]}').fatalErrors.length, 2);
    });

    test('per-item errors, not fatal', () {
      final p = parseOutlineJson(outline([
        topic('Fine'),
        {'title': '', 'level': 9, 'target_cards': 1000, 'prerequisites': 'x'},
      ]));
      expect(p.hasFatal, isFalse);
      expect(p.items[0].valid, isTrue);
      expect(p.items[1].errors.length, 4);
    });
  });

  group('planner (pure)', () {
    const planner = LearnPlanner();

    test('day 1: only the topic whose prerequisites are met is offered', () {
      final plan = planner.plan(
        domains: const [_dom],
        items: [item(1, 'A'), item(2, 'B', pre: [1]), item(3, 'C', pre: [2])],
        capacity: _cap,
        seed: 1,
      );
      expect(plan.options.length, 1);
      expect(plan.options.first.action, LearnAction.newItem);
      expect(plan.options.first.item.title, 'A');
      expect(plan.options.first.count, 10);
      expect(plan.blockedReason, isNull);
    });

    test('day 2: prerequisite at 70% unlocks the next topic, ranked above finishing the first', () {
      final plan = planner.plan(
        domains: const [_dom],
        items: [item(1, 'A', status: 'active', cards: 9), item(2, 'B', pre: [1]), item(3, 'C', pre: [2])],
        capacity: _cap,
        seed: 2,
      );
      expect(plan.options.map((o) => o.key), ['newItem:2', 'deepen:1']);
      expect(plan.options[1].count, 1); // only one card short of target
    });

    test('prerequisite below 70% blocks the next topic', () {
      final plan = planner.plan(
        domains: const [_dom],
        items: [item(1, 'A', status: 'active', cards: 6), item(2, 'B', pre: [1])],
        capacity: _cap,
        seed: 3,
      );
      expect(plan.options.map((o) => o.key), ['deepen:1']);
    });

    test('work-in-progress limit stops opening new topics', () {
      final plan = planner.plan(
        domains: const [_dom],
        items: [
          item(1, 'A', status: 'active', cards: 5),
          item(2, 'B', status: 'active', cards: 5),
          item(3, 'C'),
        ],
        capacity: _cap,
        seed: 4,
      );
      expect(plan.candidates.where((c) => c.action == LearnAction.newItem), isEmpty);
      expect(plan.options.length, 2);
    });

    test('leeches trigger a remediation option that outranks the rest', () {
      final plan = planner.plan(
        domains: const [_dom],
        items: [item(1, 'A', status: 'active', cards: 9, leeches: 3), item(2, 'B', pre: [1])],
        capacity: _cap,
        seed: 5,
      );
      expect(plan.options.first.action, LearnAction.remediate);
      expect(plan.options.first.problemCount, 3);
      expect(plan.options.first.reasons.join(), contains('3 leech'));
    });

    test('high lapse rate on enough reviews also triggers remediation; too few reviews does not', () {
      var plan = planner.plan(
          domains: const [_dom],
          items: [item(1, 'A', status: 'active', cards: 10, reviews: 20, lapses: 8)],
          capacity: _cap, seed: 1);
      expect(plan.candidates.any((c) => c.action == LearnAction.remediate), isTrue);
      plan = planner.plan(
          domains: const [_dom],
          items: [item(1, 'A', status: 'active', cards: 10, reviews: 4, lapses: 3)],
          capacity: _cap, seed: 1);
      expect(plan.candidates.any((c) => c.action == LearnAction.remediate), isFalse);
    });

    test('capacity: free time after reviews decides how many new cards fit', () {
      const c = Capacity(dueReviews: 20, avgSecondsPerReview: 12, budgetMinutes: 20);
      expect(c.cardsRoom, 26); // (1200 - 240) / (3 * 12)
      const busy = Capacity(dueReviews: 100, avgSecondsPerReview: 12, budgetMinutes: 20);
      expect(busy.cardsRoom, 0);
      final plan = planner.plan(
          domains: const [_dom], items: [item(1, 'A')], capacity: busy, seed: 1);
      expect(plan.blockedReason, isNotNull);
      expect(plan.options.first.count, 3); // still offered, but small
      const some = Capacity(dueReviews: 70, avgSecondsPerReview: 12, budgetMinutes: 20);
      expect(some.cardsRoom, 10); // (1200-840)/36
      final p2 = planner.plan(domains: const [_dom], items: [item(1, 'A')], capacity: some, seed: 1);
      expect(p2.options.first.count, 10);
      const tight = Capacity(dueReviews: 60, avgSecondsPerReview: 12, budgetMinutes: 20);
      final p3 = planner.plan(domains: const [_dom], items: [item(1, 'A')], capacity: tight, seed: 1);
      expect(tight.cardsRoom, 13);
      expect(p3.options.first.count, 10); // capped by the base count, not the room
    });

    test('same seed => identical plan; ties vary across days', () {
      List<String> run(int seed) => planner
          .plan(
            domains: const [DomainInfo(id: 1, name: 'Bio', itemCount: 1), DomainInfo(id: 2, name: 'Chem', itemCount: 1)],
            items: [item(1, 'A'), item(2, 'X', domain: 2)],
            capacity: _cap,
            seed: seed,
          )
          .options
          .map((o) => o.key)
          .toList();
      expect(run(7), run(7));
      final tops = {for (var s = 0; s < 30; s++) run(s).first};
      expect(tops.length, 2); // equal scores: the order rotates with the day
    });

    test('exploration slot is seeded, rare, and always a different topic', () {
      var explores = 0;
      for (var s = 0; s < 300; s++) {
        final plan = planner.plan(
          domains: const [_dom],
          items: [
            item(1, 'A', status: 'active', cards: 5),
            item(2, 'B', status: 'active', cards: 4),
            item(3, 'C', status: 'todo', cards: 0, pre: const [99]),
            item(4, 'D', status: 'active', cards: 3, domain: 1),
          ],
          capacity: _cap,
          seed: s,
        );
        expect(plan.options.length, 2);
        expect(plan.options[0].item.id, isNot(plan.options[1].item.id));
        if (plan.options[1].explore) explores++;
      }
      expect(explores, inInclusiveRange(15, 90)); // ~15% of 300
    });

    test('empty states', () {
      expect(planner.plan(domains: const [], items: const [], capacity: _cap, seed: 1).emptyReason,
          EmptyReason.noDomains);
      expect(planner.plan(domains: const [DomainInfo(id: 1, name: 'Bio')], items: const [], capacity: _cap, seed: 1).emptyReason,
          EmptyReason.noSyllabus);
      expect(
          planner.plan(domains: const [_dom], items: [item(1, 'A', status: 'done', cards: 10)], capacity: _cap, seed: 1).emptyReason,
          EmptyReason.allDone);
    });
  });

  group('end to end: why today differs from tomorrow', () {
    late AppDatabase db;
    late SettingsRepo settings;
    late LearnService learn;
    late ImportService imp;
    late OutlineService out;
    final d1 = DateTime.utc(2024, 3, 1, 12);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settings = SettingsRepo(db);
      learn = LearnService(db, settings, QueueService(db, settings));
      imp = ImportService(db);
      out = OutlineService(db);
    });
    tearDown(() => db.close());

    Future<void> importCards(String itemTitle, int n, {DateTime? now, String prefix = 'Q'}) async {
      final cards = [
        for (var i = 0; i < n; i++)
          {
            'type': 'basic', 'front': '$prefix $itemTitle number $i?', 'back': 'a',
            'source_type': 'quote', 'supporting_quote': 'q', 'confidence': 'high'
          }
      ];
      final p = await imp.preview(jsonEncode({'domain': 'Bio', 'syllabus_item': itemTitle, 'cards': cards}));
      await imp.commit(p, now: now);
    }

    test('three days of button presses', () async {
      // Outline first.
      final op = await out.preview(outline([
        topic('Cell membrane'),
        topic('Mitochondria', pre: ['Cell membrane']),
        topic('Photosynthesis', pre: ['Mitochondria']),
      ]));
      final os = await out.commit(op, now: d1);
      expect((os.items, os.edges, os.droppedEdges), (3, 2, 0));

      // DAY 1
      var v = await learn.view(now: d1);
      expect(v.plan.options.single.item.title, 'Cell membrane');
      expect(v.pending, isNull);
      final g1 = await learn.choose(v.plan.options.first, v, now: d1);
      expect(g1.text, contains('Create 10 flashcards for the domain "Bio", focusing on "Cell membrane"'));
      expect(g1.text, contains('"syllabus_item": "Cell membrane"'));

      // Pressing again the same day: same pending prompt, same options.
      final again = await learn.view(now: d1.add(const Duration(hours: 1)));
      expect(again.pending?.id, g1.logId);
      expect(again.plan.options.first.key, v.plan.options.first.key);

      // The LLM rephrased the topic title; the pending prompt still links the cards.
      await importCards('Cell membrane (basics)', 9, now: d1.add(const Duration(hours: 2)));
      final linked = await (db.select(db.notes)..where((n) => n.syllabusItemId.isNotNull())).get();
      expect(linked.length, 9);
      expect((await db.select(db.syllabusItems).get()).length, 3); // no phantom topic
      expect((await db.select(db.promptLogs).getSingle()).status, 'imported');

      // DAY 2: first topic is "active" and 9/10 unlocks the next one.
      final d2 = d1.add(const Duration(days: 1));
      v = await learn.view(now: d2);
      expect(v.pending, isNull);
      expect(v.plan.options.map((o) => o.item.title), ['Mitochondria', 'Cell membrane']);
      expect(v.plan.options.first.reasons.join(), contains('Cell membrane'));
      final g2 = await learn.choose(v.plan.options.first, v, now: d2);
      expect(g2.text, contains('focusing on "Mitochondria"'));
      expect(g2.text, contains('Cell membrane (basics) number 0?'), reason: 'existing cards must be excluded');
      final items = await db.select(db.syllabusItems).get();
      expect(items.firstWhere((i) => i.title == 'Cell membrane').status, 'active');

      // Decision log written with the shown options and the choice.
      final decisions = await db.select(db.engineDecisions).get();
      expect(decisions.length, 2);
      final chosen = jsonDecode(decisions.last.chosenJson) as Map<String, dynamic>;
      expect(chosen['shown'], hasLength(2));
      expect(chosen['key'], startsWith('newItem:'));
      expect(decisions.last.engineVersion, LearnPlanner.version);

      // DAY 3: three hard cards in the first topic => remediation wins.
      await importCards('Mitochondria', 10, now: d2.add(const Duration(hours: 1)));
      final cm = await (db.select(db.syllabusItems)..where((s) => s.title.equals('Cell membrane'))).getSingle();
      final cardIds = await db.customSelect(
          'SELECT c.id FROM card c JOIN note n ON n.id = c.note_id WHERE n.syllabus_item_id = ? LIMIT 3',
          variables: [Variable.withInt(cm.id)]).get();
      for (final r in cardIds) {
        await (db.update(db.cards)..where((c) => c.id.equals(r.read<int>('id'))))
            .write(const CardsCompanion(lapses: Value(9), suspended: Value(true)));
      }
      final d3 = d2.add(const Duration(days: 1));
      v = await learn.view(now: d3);
      expect(v.plan.options.first.action, LearnAction.remediate);
      final g3 = await learn.choose(v.plan.options.first, v, now: d3);
      expect(g3.text, contains('PROBLEM CARDS'));
      expect(g3.text, contains('Cell membrane (basics) number'));
      final logs = await db.select(db.promptLogs).get();
      expect(logs.last.templateVersion, 'remediate-v3');
      // An unimported prompt is surfaced instead of silently piling up.
      expect((await learn.view(now: d3.add(const Duration(hours: 1)))).pending?.id, g3.logId);
      // ...and stops being "pending" after a day.
      expect((await learn.view(now: d3.add(const Duration(hours: 30)))).pending, isNull);
    });

    test('new subject: outline prompt, then import closes it out', () async {
      final g = await learn.outlinePrompt('Spanish', goal: 'travel conversation', now: d1);
      expect(g.text, contains('learning outline for the subject "Spanish"'));
      expect(g.text, contains('travel conversation'));
      expect((await db.select(db.promptLogs).getSingle()).templateVersion, 'outline-v2');
      expect((await learn.view(now: d1)).pending?.isOutline, isTrue);

      final p = await out.preview(outline([topic('Greetings'), topic('Numbers')], domain: 'spanish'));
      expect(p.newDomain, isFalse); // matched case-insensitively
      await out.commit(p, now: d1);
      expect((await db.select(db.promptLogs).getSingle()).status, 'imported');
      expect((await db.select(db.domains).get()).length, 1);

      // Extending an outline mentions what exists and skips duplicates.
      final g2 = await learn.outlinePrompt('Spanish');
      expect(g2.text, contains('- Greetings'));
      final p2 = await out.preview(outline([topic('greetings'), topic('Food', pre: ['Numbers', 'Ghost'])], domain: 'Spanish'));
      expect(p2.alreadyExists, {0});
      expect(p2.warnings[1], isNotNull); // "Ghost" matches nothing
      final s2 = await out.commit(p2);
      expect((s2.items, s2.edges, s2.droppedEdges), (1, 1, 1));
    });

    test('a loop against existing topics is refused and nothing is written', () async {
      await out.commit(await out.preview(outline([topic('A'), topic('B', pre: ['A'])])));
      final bad = await out.preview(outline([topic('C', pre: ['B'])]));
      await out.commit(bad); // fine: C after B
      // Now try to make A depend on C via a new topic: A cannot be re-declared, so craft D<-C and edit edges manually.
      final a = await (db.select(db.syllabusItems)..where((s) => s.title.equals('A'))).getSingle();
      final c = await (db.select(db.syllabusItems)..where((s) => s.title.equals('C'))).getSingle();
      await db.into(db.syllabusPrereqs).insert(SyllabusPrereqsCompanion.insert(itemId: a.id, prereqId: c.id));
      final before = (await db.select(db.syllabusItems).get()).length;
      final p = await out.preview(outline([topic('D', pre: ['C'])]));
      await expectLater(out.commit(p), throwsA(isA<OutlineException>()));
      expect((await db.select(db.syllabusItems).get()).length, before);
    });

    test('items finish and stop being offered', () async {
      await out.commit(await out.preview(outline([topic('Only', target: 5)])));
      await importCards('Only', 5, now: d1);
      final v = await learn.view(now: d1.add(const Duration(days: 1)));
      expect(v.plan.emptyReason, EmptyReason.allDone);
      expect((await db.select(db.syllabusItems).getSingle()).status, 'done');
    });
  });

  test('migration v1 -> latest keeps data and adds the new schema', () async {
    final dir = Directory.systemTemp.createTempSync('mig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/m.db');

    var db = AppDatabase(NativeDatabase(f));
    final dom = await db.into(db.domains).insert(DomainsCompanion.insert(name: 'Old', createdAt: 1));
    await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(domainId: dom, title: 'Legacy topic'));
    await db.close();

    // Turn the file back into a v1 database.
    final raw = sql.sqlite3.open(f.path);
    raw.execute('DROP TABLE syllabus_prereq');
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN target_cards');
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN description');
    raw.execute('ALTER TABLE syllabus_item DROP COLUMN rounds');
    raw.execute('ALTER TABLE card DROP COLUMN retired_at');
    raw.execute('ALTER TABLE domain DROP COLUMN retention');
    raw.execute('ALTER TABLE domain DROP COLUMN speech_lang');
    raw.execute('ALTER TABLE domain DROP COLUMN speech_side');
    raw.execute('DROP TABLE IF EXISTS media');
    raw.execute('ALTER TABLE domain DROP COLUMN learn_weight');
    raw.execute('ALTER TABLE domain DROP COLUMN revisit');
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    db = AppDatabase(NativeDatabase(f));
    addTearDown(db.close);
    final row = await db.select(db.syllabusItems).getSingle();
    expect(row.title, 'Legacy topic');
    expect(row.targetCards, 10);
    expect(row.description, '');
    expect(await db.select(db.syllabusPrereqs).get(), isEmpty);
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, kSchemaVersion);
    expect(row.rounds, 1);
    expect((await db.select(db.domains).getSingle()).learnWeight, 2);
  });
}
