import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/map_prompt.dart';
import 'package:daily_learning/domain/outline_parser.dart';
import 'package:daily_learning/domain/plan_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

String subj(String name, List<String> titles, {String why = 'because'}) => jsonEncode({
      'domain': name,
      'why': why,
      'items': [for (final t in titles) {'title': t, 'level': 1, 'target_cards': 8, 'prerequisites': <String>[]}]
    });

String plan(List<String> subjects) => '{"subjects":[${subjects.join(',')}]}';

void main() {
  group('map prompt (pure)', () {
    List<MapSubject> many(int n, {int titles = 10}) => [
          for (var i = 0; i < n; i++)
            MapSubject(
              name: 'Subject number $i',
              topics: 20 + i,
              cards: 100 + i,
              recentTitles: [for (var k = 0; k < titles; k++) 'A fairly typical topic title $i-$k'],
            )
        ];

    test('stays bounded however large the library grows', () {
      for (final n in [0, 5, 50, 400, 3000]) {
        final text = renderMapPrompt(subjects: many(n));
        expect(text.length, lessThan(kMapBudgetChars + 4500), reason: '$n subjects -> ${text.length} chars');
      }
    });

    test('small library: every subject is described with its newest titles', () {
      final text = renderMapPrompt(subjects: many(3));
      expect(text, contains('3 subjects'));
      expect(text, contains('- Subject number 0 (20 topics, 100 cards)'));
      expect(text, contains('A fairly typical topic title 2-9'));
      expect(text, isNot(contains('names only')));
    });

    test('huge library: newest subjects detailed, the rest by name only, with a count of what was cut', () {
      final text = renderMapPrompt(subjects: many(3000));
      expect(text, contains('3000 subjects'));
      expect(text, contains('A fairly typical topic title 0-0'));
      expect(text, contains('Other subjects (names only):'));
      expect(text, contains('more.'));
    });

    test('paused and liked subjects are marked; paused ones are never to be repeated', () {
      final text = renderMapPrompt(subjects: [
        const MapSubject(name: 'Chess', topics: 5, cards: 40, paused: true),
        const MapSubject(name: 'Jazz', topics: 5, cards: 40, interest: 0.9),
      ]);
      expect(text, contains('Chess (5 topics, 40 cards; paused, do not propose more of this)'));
      expect(text, contains('Jazz (5 topics, 40 cards; the learner likes it)'));
    });

    test('empty library asks for a broad start; profile and ideas are included once, braces in them are safe', () {
      final text = renderMapPrompt(
          subjects: const [], learnerProfile: 'I am a nurse {n} who loves "birds"', ideas: ['Jazz', 'Pottery and Ceramics']);
      expect(text, contains('brand-new library'));
      expect(text, contains("I am a nurse {n} who loves 'birds'"));
      expect(text, contains('Jazz; Pottery and Ceramics'));
      expect(text, contains('Propose 4 NEW subjects'));
    });

    test('asks for JSON only in the schema the parser accepts', () {
      final text = renderMapPrompt(subjects: const []);
      expect(text, contains('"subjects"'));
      expect(text, contains('Output JSON ONLY'));
      expect(text, isNot(contains('"cards"')));
    });
  });

  group('plan parser', () {
    test('detected as a plan, not an outline or cards', () {
      expect(detectPayloadKind(plan([subj('A', ['x'])])), 'plan');
      expect(detectPayloadKind('```json\n${plan([subj('A', ['x'])])}\n```'), 'plan');
      expect(detectPayloadKind(subj('A', ['x'])), 'outline');
    });

    test('rejects junk, empty, too many, and duplicate names; reports per-subject problems', () {
      expect(parsePlanJson('nope').hasFatal, isTrue);
      expect(parsePlanJson('{"subjects": []}').hasFatal, isTrue);
      expect(parsePlanJson(plan([for (var i = 0; i < 9; i++) subj('S$i', ['t'])])).hasFatal, isTrue);
      final p = parsePlanJson(plan([subj('Same', ['a']), subj('same', ['b']), '{"domain":"Bad","items":[]}', '"str"']));
      expect(p.hasFatal, isFalse);
      expect(p.subjects.map((s) => s.valid), [true, false, false, false]);
      expect(p.importable.length, 1);
    });

    test('why is capped; untrusted text is never executed or trusted', () {
      final p = parsePlanJson(plan([subj('A', ['x'], why: 'w' * 5000)]));
      expect(p.subjects.single.why.length, kMaxWhyChars);
    });
  });

  group('plan import', () {
    late AppDatabase db;
    late OutlineService svc;
    late LearnService learn;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      svc = OutlineService(db);
      final s = SettingsRepo(db);
      learn = LearnService(db, s, QueueService(db, s));
    });
    tearDown(() => db.close());

    test('only the ticked subjects are saved, in one go; the map prompt is closed', () async {
      final v = await learn.view(); // empty library -> map prompt
      await learn.chooseGrowth(v.growth!, v);
      final pl = await svc.previewPlan(plan([
        subj('Astronomy', ['Stars', 'Planets']),
        subj('Pottery', ['Clay', 'Glaze', 'Kiln']),
        subj('Chess', ['Openings']),
      ]));
      expect(pl.subjects.every((s) => s.outline.newDomain), isTrue);
      final r = await svc.commitPlan(pl, {0, 1});
      expect((subjects: r.subjects, topics: r.topics), (subjects: 2, topics: 5));
      expect((await db.select(db.domains).get()).map((d) => d.name).toSet(), {'Astronomy', 'Pottery'});
      expect((await db.select(db.promptLogs).get()).single.status, 'imported');
      expect((await learn.view()).plan.options, isNotEmpty);
    });

    test('a proposed subject you already have adds only its new topics', () async {
      await svc.commit(await svc.preview(subj('Astronomy', ['Stars'])));
      final pl = await svc.previewPlan(plan([subj('Astronomy', ['Stars', 'Planets'])]));
      expect(pl.subjects.single.outline.newDomain, isFalse);
      expect(pl.subjects.single.outline.importable.map((i) => i.title), ['Planets']);
      final r = await svc.commitPlan(pl, {0});
      expect(r.topics, 1);
    });

    test('new topics can depend on topics you already have, and both subjects are saved together', () async {
      await svc.commit(await svc.preview(jsonEncode({
        'domain': 'A',
        'items': [
          {'title': 'one'},
          {'title': 'two', 'prerequisites': ['one']}
        ]
      })));
      final pl = await svc.previewPlan(plan([
        subj('Fine', ['x']),
        jsonEncode({
          'domain': 'A',
          'items': [
            {'title': 'three', 'prerequisites': ['two']}
          ]
        }),
      ]));
      final before = (await db.select(db.syllabusItems).get()).length;
      await svc.commitPlan(pl, {0, 1}); // valid, no loop: both saved
      expect((await db.select(db.syllabusItems).get()).length, before + 2);
    });
  });
}
