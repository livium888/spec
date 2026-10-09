import 'dart:convert';

import 'package:daily_learning/data/fsrs_scheduler.dart' show fsrs6DefaultWeights;
import 'package:daily_learning/data/knowledge_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/domain/knowledge_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'screenshots/screens_test.dart' show boot, settle;

final w = fsrs6DefaultWeights;
const day = 86400000;
final now = DateTime.utc(2025, 6, 1, 12).millisecondsSinceEpoch;

CardFact known({double stability = 40, int daysAgo = 1, bool leech = false, bool suspended = false}) =>
    CardFact(state: 'review', stability: stability, lastReviewMs: now - daysAgo * day, leech: leech, suspended: suspended);
const fresh = CardFact(state: 'new');

TopicNode node(int id, String title, List<CardFact> facts, {List<int> prereqs = const [], String status = 'todo', int target = 10, int position = 0}) => buildNode(
    id: id, title: title, level: 1, position: position == 0 ? id : position, status: status, targetCards: target, facts: facts,
    weights: w, nowMs: now, prereqs: prereqs, problems: false, foundations: 0);

void main() {
  group('how well a topic is known', () {
    test('recall follows the model: strong and recent is high, old and weak is low, new is zero', () {
      expect(cardRecall(known(stability: 40, daysAgo: 1), w, now), greaterThan(0.95));
      expect(cardRecall(known(stability: 1, daysAgo: 60), w, now), lessThan(0.6));
      expect(cardRecall(fresh, w, now), 0);
    });

    test('knowledge is measured against the topic size, so three good cards of ten is not "solid"', () {
      final few = node(1, 'A', [for (var i = 0; i < 3; i++) known()]);
      expect(few.knowledge, closeTo(0.3, 0.03));
      expect(few.state, TopicState.learning);
      final all = node(2, 'B', [for (var i = 0; i < 10; i++) known()]);
      expect(all.knowledge, greaterThan(0.9));
      expect(all.state, TopicState.solid);
      final more = node(3, 'C', [for (var i = 0; i < 14; i++) known()], target: 10);
      expect(more.knowledge, greaterThan(0.9)); // more cards than the target does not inflate it
    });

    test('states: not started, fading, needs attention (shaky or a leech), skipped', () {
      expect(node(1, 'A', const []).state, TopicState.notStarted);
      expect(node(2, 'B', [fresh, fresh]).state, TopicState.notStarted);
      final fading = node(3, 'C', [for (var i = 0; i < 6; i++) known(stability: 5, daysAgo: 20)]); // ~0.8
      expect(fading.recall, inInclusiveRange(0.7, 0.85));
      expect(fading.state, TopicState.fading);
      final shaky = node(4, 'D', [for (var i = 0; i < 6; i++) known(stability: 2, daysAgo: 40)]);
      expect(shaky.state, TopicState.attention);
      expect(node(5, 'E', [known(), known(), known(), known(leech: true, suspended: true)]).state, TopicState.attention);
      expect(node(6, 'F', [known()], status: 'skipped').state, TopicState.skipped);
      // Too early to judge: two cards, however shaky, are still "learning".
      expect(node(7, 'G', [known(stability: 2, daysAgo: 40), known(stability: 2, daysAgo: 40)]).state, TopicState.learning);
    });

    test('suspended cards are out of the topic, a leech stays in it', () {
      final n = node(1, 'A', [known(), known(suspended: true), known(leech: true, suspended: true)]);
      expect(n.cards, 2);
      expect(n.leeches, 1);
    });
  });

  group('the map', () {
    List<TopicNode> physics() => [
          node(1, 'Kinematics', [for (var i = 0; i < 10; i++) known()]),
          node(2, 'Vectors', [for (var i = 0; i < 10; i++) known(stability: 2, daysAgo: 40)]), // shaky
          node(3, 'Forces', [fresh], prereqs: [1, 2]),
          node(4, 'Energy', const [], prereqs: [3]),
          node(5, 'Waves', const []),
        ];

    test('layers: a topic sits below its deepest prerequisite; no prerequisite means the top', () {
      final m = buildKnowledgeMap(physics());
      expect(m.layers.length, 3);
      expect(m.layers[0].toSet(), {1, 2, 5});
      expect(m.layers[1], [3]);
      expect(m.layers[2], [4]);
      expect(m.edges.toSet(), {(1, 3), (2, 3), (3, 4)});
    });

    test('next up: ready topics only (prerequisites solid); blockers name the weakest prerequisite', () {
      final m = buildKnowledgeMap(physics());
      expect(m.nextUp, [5]); // Waves: nothing needed. Forces waits for Vectors; Energy for Forces.
      expect(m.blockers[3], 2);
      expect(m.blockers[4], 3);
      expect(m.blockers.containsKey(5), isFalse);
    });

    test('once the prerequisites are solid the topic is next up, and not blocked', () {
      final topics = physics();
      topics[1] = node(2, 'Vectors', [for (var i = 0; i < 10; i++) known()]);
      final m = buildKnowledgeMap(topics);
      expect(m.nextUp, containsAll([3, 5]));
      expect(m.blockers.containsKey(3), isFalse);
    });

    test('a finished topic that is not slipping counts as solid; skipped topics are ignored', () {
      final m = buildKnowledgeMap([
        node(1, 'A', [for (var i = 0; i < 4; i++) known()], status: 'done'), // 4 of 10 cards but marked done
        node(2, 'B', const [], prereqs: [1]),
        node(3, 'C', const [], status: 'skipped'),
        node(4, 'D', const [], prereqs: [3]),
      ]);
      expect(m.nextUp, containsAll([2, 4]));
      expect(m.nextUp.contains(3), isFalse);
    });

    test('a cycle in damaged data does not hang or throw', () {
      final m = buildKnowledgeMap([node(1, 'A', const [], prereqs: [2]), node(2, 'B', const [], prereqs: [1])]);
      expect(m.nodes.length, 2);
      expect(m.layers.expand((l) => l).toSet(), {1, 2});
    });

    test('an empty subject gives an empty map', () => expect(buildKnowledgeMap(const []).isEmpty, isTrue));
  });

  group('from the database', () {
    late Env e;
    late int domainId;
    setUp(() async {
      e = Env();
      final out = OutlineService(e.db);
      await out.commit(await out.preview(jsonEncode({
        'domain': 'Physics',
        'items': [
          {'title': 'Kinematics', 'target_cards': 4, 'practice': 'problems'},
          {'title': 'Forces', 'target_cards': 4, 'prerequisites': ['Kinematics']},
        ],
      })));
      domainId = (await e.db.select(e.db.domains).getSingle()).id;
    });
    tearDown(() => e.db.close());

    test('topics, prerequisites, recall, problems, foundations and leeches come through', () async {
      final imp = e.import;
      Map<String, dynamic> c(String q, {String tags = ''}) => {
            'type': 'basic', 'front': q, 'back': 'A short answer', 'source_type': 'model_memory', 'confidence': 'high',
            if (tags.isNotEmpty) 'tags': [tags],
          };
      await imp.commit(await imp.preview(jsonEncode({'domain': 'Physics', 'syllabus_item': 'Kinematics', 'cards': [c('K one?'), c('K two?'), c('K three?'), c('K four?')]})));
      await imp.commit(await imp.preview(jsonEncode({'domain': 'Physics', 'syllabus_item': 'Forces', 'cards': [c('F one?')]})));
      final nowDt = DateTime.now().toUtc();
      await e.db.customStatement("UPDATE card SET state='review', stability=60, last_review=${nowDt.millisecondsSinceEpoch - day}, reps=4 "
          "WHERE note_id IN (SELECT id FROM note WHERE fields_json LIKE '%K %')");
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.foundation_of', '1') WHERE fields_json LIKE '%K two%'");

      final m = await KnowledgeService(e.db, e.params).forDomain(domainId);
      final k = m.nodes.values.firstWhere((n) => n.title == 'Kinematics');
      final f = m.nodes.values.firstWhere((n) => n.title == 'Forces');
      expect(k.cards, 4);
      expect(k.learned, 4);
      expect(k.state, TopicState.solid);
      expect(k.problems, isTrue); // practice = problems
      expect(k.foundations, 1);
      expect(f.prereqs, [k.id]);
      expect(f.state, TopicState.notStarted);
      expect(m.layers.length, 2);
      expect(m.nextUp, [f.id]); // Kinematics is solid, Forces has not started
    });

    test('a subject without topics is an empty map', () async {
      final empty = await KnowledgeService(e.db, e.params).forDomain(9999);
      expect(empty.isEmpty, isTrue);
    });
  });

  testWidgets('the map screen: tiles with words, a List view with the same facts, and a topic sheet with actions', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final e = (await t.runAsync(() async {
      final e = Env();
      final out = OutlineService(e.db);
      await out.commit(await out.preview(jsonEncode({
        'domain': 'Physics',
        'items': [
          {'title': 'Kinematics', 'target_cards': 3},
          {'title': 'Vectors', 'target_cards': 3},
          {'title': 'Forces', 'target_cards': 3, 'prerequisites': ['Kinematics', 'Vectors']},
        ],
      })));
      Map<String, dynamic> c(String q) => {'type': 'basic', 'front': q, 'back': 'A', 'source_type': 'model_memory', 'confidence': 'high'};
      await e.import.commit(await e.import.preview(jsonEncode({'domain': 'Physics', 'syllabus_item': 'Kinematics', 'cards': [c('K1?'), c('K2?'), c('K3?')]})));
      await e.db.customStatement("UPDATE card SET state='review', stability=60, last_review=${DateTime.now().toUtc().millisecondsSinceEpoch - day}, reps=4");
      return e;
    }))!;
    final domainId = (await t.runAsync(() => e.db.select(e.db.domains).getSingle()))!.id;
    final key = GlobalKey();
    await boot(t, e.db, key);
    await t.tap(find.text('Library'));
    await settle(t);
    await t.tap(find.text('Physics').last);
    await settle(t);
    await t.tap(find.byTooltip('Knowledge map'));
    await settle(t);

    expect(find.text('Physics: map'), findsOneWidget);
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Kinematics'), findsWidgets);
    expect(find.textContaining('Solid'), findsWidgets);
    expect(find.textContaining('Not started'), findsWidgets);

    await t.tap(find.text('List'));
    await settle(t);
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('Builds on the topics above'), findsOneWidget);
    expect(find.textContaining('held back by Vectors'), findsOneWidget); // Vectors has no cards: the weakest prerequisite

    await t.tap(find.text('Forces'));
    await settle(t);
    expect(find.textContaining('Held back by "Vectors"'), findsOneWidget);
    expect(find.text('Make cards for this topic'), findsOneWidget);
    expect(find.text('AI decides'), findsOneWidget);
    expect(domainId, isPositive);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(e.db.close);
  });
}
