import 'dart:convert';

import 'package:daily_learning/data/keywords_service.dart';
import 'package:daily_learning/data/media_service.dart';
import 'package:daily_learning/domain/keywords_prompt.dart';
import 'package:daily_learning/domain/outline_parser.dart' show detectPayloadKind;
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'phase3_test.dart' show png;

String answer(List<Map<String, Object?>> entries) => jsonEncode({'image_keywords': entries});

void main() {
  group('the prompt', () {
    test('lists each card by its number with subject, question and answer, and states the rules', () {
      final p = renderKeywordsPrompt([
        const KeywordCardRef(noteId: 12, subject: 'Art', question: 'Which painting gave a movement its name?', answer: 'Impression, Sunrise'),
        const KeywordCardRef(noteId: 13, subject: 'Music', question: 'A scale climbs {{c1::whole}}, whole, {{c2::half::step}}.', answer: ''),
      ]);
      expect(p, contains('12 | Art | Q: Which painting gave a movement its name? | A: Impression, Sunrise'));
      expect(p, contains('13 | Music | Q: A scale climbs whole, whole, half.')); // cloze markup removed, no empty answer
      expect(p, isNot(contains('{{')));
      for (final must in ['"image_keywords"', '"image_query"', '"image_side"', 'NEVER a web address', 'exactly one entry per card', 'JSON ONLY']) {
        expect(p, contains(must), reason: must);
      }
    });

    test('long fields are cut to one line, and a batch is capped', () {
      final long = 'word ' * 200;
      final p = renderKeywordsPrompt([
        for (var i = 0; i < kMaxKeywordCards + 20; i++) KeywordCardRef(noteId: i, subject: 's', question: long, answer: long),
      ]);
      expect('\n'.allMatches(p).length, lessThan(kMaxKeywordCards + 40));
      expect(p, isNot(contains('\n\n\nword'))); // every card is a single line
      expect(p.length, lessThan(60000));
    });
  });

  group('the answer (untrusted)', () {
    test('a good answer parses; odd entries are marked, never thrown', () {
      final r = parseKeywordsJson(answer([
        {'id': 1, 'image_query': '  Monet  Impression Sunrise ', 'image_side': 'front'},
        {'id': 2, 'image_query': 'mitochondrion micrograph', 'image_side': 'sideways'},
        {'id': 3, 'image_query': 'https://example.com/a.jpg'},
        {'id': '4', 'image_query': 'fine words'},
        {'id': 5},
        {'id': 1, 'image_query': 'again'},
        {'image_query': 'no id'},
      ]));
      expect(r.hasFatal, isFalse);
      expect(r.entries[0].valid, isTrue);
      expect(r.entries[0].query, 'Monet Impression Sunrise');
      expect(r.entries[0].side, 'front');
      expect(r.entries[1].valid, isTrue);
      expect(r.entries[1].side, ''); // an unknown side is ignored
      expect(r.entries.skip(2).every((e) => !e.valid), isTrue);
      expect(r.entries[5].errors.single, contains('twice'));
    });

    test('a wrong shape, an empty list or too many entries is refused as a whole', () {
      for (final bad in ['not json', '[]', '{"cards": []}', '{"image_keywords": 5}', answer([])]) {
        expect(parseKeywordsJson(bad).hasFatal, isTrue, reason: bad);
      }
      expect(parseKeywordsJson(answer([for (var i = 0; i < kMaxKeywordEntries + 1; i++) {'id': i, 'image_query': 'x y'}])).hasFatal, isTrue);
    });

    test('a code fence around the JSON is tolerated, and the shape is recognised for share-in', () {
      final raw = '```json\n${answer([{'id': 1, 'image_query': 'old map'}])}\n```';
      expect(parseKeywordsJson(raw).entries.single.valid, isTrue);
      expect(detectPayloadKind(raw), 'keywords');
      expect(detectPayloadKind('{"cards": [], "image_keywords": []}'), 'cards');
    });
  });

  group('KeywordsService', () {
    late Env e;
    late KeywordsService svc;
    setUp(() async {
      e = Env();
      svc = KeywordsService(e.db);
      await e.addBasic(4); // notes 1..4, none has keywords
    });

    Future<Map<String, dynamic>> fields(int id) async {
      final n = await (e.db.select(e.db.notes)..where((x) => x.id.equals(id))).getSingle();
      return jsonDecode(n.fieldsJson) as Map<String, dynamic>;
    }

    test('counts and lists only cards with neither keywords nor a picture, oldest first', () async {
      expect(await svc.countMissing(), 4);
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image_query', 'has words') WHERE id = 1");
      final sha = await MediaService(e.db).save(png);
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image', '$sha') WHERE id = 2");
      expect(await svc.countMissing(), 2);
      final batch = await svc.nextBatch(10);
      expect(batch.map((c) => c.noteId), [3, 4]);
      expect(batch.first.subject, 'Bio');
      expect((await svc.nextBatch(1)).length, 1);
    });

    test('preview explains each entry; nothing is saved by it', () async {
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image_query', 'has words') WHERE id = 1");
      final sha = await MediaService(e.db).save(png);
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image', '$sha') WHERE id = 2");
      final plan = await svc.preview(answer([
        {'id': 3, 'image_query': 'tree rings diagram'},
        {'id': 1, 'image_query': 'new words'},
        {'id': 2, 'image_query': 'words'},
        {'id': 999, 'image_query': 'nobody'},
        {'id': 4, 'image_query': 'https://x.org'},
        {'id': 3, 'image_query': 'again'},
      ]));
      expect(plan.rows.map((r) => r.status), [
        KeywordStatus.ok, KeywordStatus.alreadyHasKeywords, KeywordStatus.hasPicture,
        KeywordStatus.unknownCard, KeywordStatus.invalid, KeywordStatus.duplicate,
      ]);
      expect(plan.rows.first.question, contains('Question number 2'));
      expect(plan.applicable, hasLength(1));
      expect((await fields(3)).containsKey('image_query'), isFalse);
    });

    test('commit adds keywords and the side hint to the chosen cards only, and never overwrites', () async {
      final plan = await svc.preview(answer([
        {'id': 3, 'image_query': 'tree rings diagram', 'image_side': 'back'},
        {'id': 4, 'image_query': 'leaf stomata', 'image_side': 'front'},
      ]));
      // someone adds keywords to card 4 by hand between preview and commit
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image_query', 'hand written') WHERE id = 4");
      final n = await svc.commit(plan, {for (final r in plan.rows) r.entry.index});
      expect(n, 1);
      expect((await fields(3))['image_query'], 'tree rings diagram');
      expect((await fields(3))['image_side'], 'back');
      expect((await fields(4))['image_query'], 'hand written');
      expect(await svc.countMissing(), 2); // cards 1 and 2 remain
      // unticked rows are not touched
      final plan2 = await svc.preview(answer([{'id': 1, 'image_query': 'a b'}]));
      expect(await svc.commit(plan2, <int>{}), 0);
      expect((await fields(1)).containsKey('image_query'), isFalse);
    });

    test('an existing side choice is kept; the original text of the card is untouched', () async {
      await e.db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image_side', 'front') WHERE id = 1");
      final before = await fields(1);
      final plan = await svc.preview(answer([{'id': 1, 'image_query': 'a b', 'image_side': 'back'}]));
      await svc.commit(plan, {0});
      final after = await fields(1);
      expect(after['image_side'], 'front');
      expect(after['image_query'], 'a b');
      expect(after['front'], before['front']);
      expect(after['back'], before['back']);
    });
  });
}
