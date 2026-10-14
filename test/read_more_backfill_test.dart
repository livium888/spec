import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/read_more_service.dart';
import 'package:daily_learning/domain/import_parser.dart' show kMaxReadMoreChars;
import 'package:daily_learning/domain/outline_parser.dart' show detectPayloadKind;
import 'package:daily_learning/domain/read_more_prompt.dart';
import 'package:daily_learning/presentation/import_screen.dart';
import 'package:daily_learning/presentation/read_more_screen.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'ui_test.dart' show settle;

String answer(List<Map<String, Object?>> entries) => jsonEncode({'read_more': entries});

Future<Map<String, dynamic>> fieldsOf(AppDatabase db, int id) async =>
    jsonDecode((await (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle()).fieldsJson) as Map<String, dynamic>;

Future<void> setFields(AppDatabase db, int id, Map<String, dynamic> add) async {
  final f = await fieldsOf(db, id)
    ..addAll(add);
  await (db.update(db.notes)..where((n) => n.id.equals(id))).write(NotesCompanion(fieldsJson: Value(jsonEncode(f))));
}

void main() {
  group('the answer is routed to its own screen', () {
    test('a read_more list is its own kind; a cards payload with read_more inside is still cards', () {
      expect(detectPayloadKind(answer([{'id': 1, 'read_more': 'text'}])), 'readmore');
      expect(detectPayloadKind('```json\n${answer([{'id': 1, 'read_more': 'text'}])}\n```'), 'readmore');
      expect(detectPayloadKind(jsonEncode({'cards': [{'front': 'q', 'read_more': 'x'}]})), 'cards');
      expect(detectPayloadKind(jsonEncode({'image_keywords': [{'id': 1}]})), 'keywords');
      expect(detectPayloadKind(jsonEncode({'read_more': 'not a list'})), 'cards');
    });
  });

  group('the prompt', () {
    test('lists each card by its number, with the rules, the shape and the way out for a long reply', () {
      final p = renderReadMorePrompt([
        const ReadMoreCardRef(noteId: 12, subject: 'Biology', question: 'Why do mitochondria have their own DNA?', answer: 'They were free-living bacteria.', why: 'You inherit them from your mother.'),
        const ReadMoreCardRef(noteId: 13, subject: 'Music', question: 'A scale climbs {{c1::whole}}, whole, {{c2::half::step}}.', answer: '', why: ''),
      ]);
      expect(p, contains('12 | Biology | Q: Why do mitochondria have their own DNA? | A: They were free-living bacteria. | Why: You inherit them from your mother.'));
      expect(p, contains('13 | Music | Q: A scale climbs whole, whole, half.'));
      expect(p, isNot(contains('{{')));
      for (final must in ['"read_more"', '"id"', '120 to 150 words', 'exactly one entry per card', 'never invent a quote', 'complete reply', 'JSON ONLY']) {
        expect(p, contains(must), reason: must);
      }
    });

    test('a batch is capped and every card is one line', () {
      final long = 'word ' * 200;
      final p = renderReadMorePrompt([
        for (var i = 0; i < kMaxReadMoreBatch + 20; i++) ReadMoreCardRef(noteId: i, subject: 's', question: long, answer: long, why: long),
      ]);
      expect(RegExp(r'^\d+ \| s \|', multiLine: true).allMatches(p).length, kMaxReadMoreBatch);
    });
  });

  group('the answer (untrusted)', () {
    test('good entries parse; an empty paragraph means nothing to add; odd entries are marked, never thrown', () {
      final r = parseReadMoreJson(jsonEncode({'read_more': [
        {'id': 1, 'read_more': '  A paragraph.  '},
        {'id': 2, 'read_more': ''},
        {'id': '3', 'read_more': 'text'},
        {'id': 4, 'read_more': 7},
        {'id': 5, 'read_more': 'x' * (kMaxReadMoreChars + 1)},
        {'id': 1, 'read_more': 'again'},
        {'read_more': 'no id'},
        'not an object',
      ]}));
      expect(r.hasFatal, isFalse);
      expect(r.entries[0].valid, isTrue);
      expect(r.entries[0].text, 'A paragraph.');
      expect(r.entries[1].valid, isTrue);
      expect(r.entries[1].nothingToAdd, isTrue);
      expect(r.entries.skip(2).every((e) => !e.valid), isTrue);
      expect(r.entries[4].errors.single, contains('$kMaxReadMoreChars'));
      expect(r.entries[5].errors.single, contains('twice'));
    });

    test('whole-answer problems are reported, not thrown', () {
      expect(parseReadMoreJson('nope').fatalErrors.single, startsWith('Not valid JSON'));
      expect(parseReadMoreJson('{"cards": []}').hasFatal, isTrue);
      expect(parseReadMoreJson('{"read_more": []}').hasFatal, isTrue);
      expect(parseReadMoreJson(answer([for (var i = 0; i < kMaxReadMoreEntries + 1; i++) {'id': i, 'read_more': 'x'}])).hasFatal, isTrue);
    });
  });

  group('ReadMoreService', () {
    late Env e;
    late ReadMoreService svc;
    setUp(() {
      e = Env();
      svc = ReadMoreService(e.db);
    });
    tearDown(() => e.db.close());

    Future<List<int>> ids() async => [for (final n in await (e.db.select(e.db.notes)..orderBy([(n) => OrderingTerm.asc(n.id)])).get()) n.id];

    test('offers the oldest cards first, and skips cards that have it, were answered "nothing to add", or are problems', () async {
      await e.addBasic(5);
      final all = await ids();
      await setFields(e.db, all[0], {'read_more': 'Already there.'});
      await setFields(e.db, all[1], {'read_more_none': '1'});
      await (e.db.update(e.db.notes)..where((n) => n.id.equals(all[2]))).write(const NotesCompanion(type: Value('problem')));
      expect(await svc.countMissing(), 2);
      final batch = await svc.nextBatch(10);
      expect(batch.map((c) => c.noteId), [all[3], all[4]]);
      expect(batch.first.question, startsWith('Question number'));
      expect((await svc.nextBatch(1)).length, 1);
    });

    test('preview says what each line would do; nothing is saved', () async {
      await e.addBasic(4);
      final all = await ids();
      await setFields(e.db, all[1], {'read_more': 'Existing.'});
      await (e.db.update(e.db.notes)..where((n) => n.id.equals(all[2]))).write(const NotesCompanion(type: Value('problem')));
      final plan = await svc.preview(answer([
        {'id': all[0], 'read_more': 'New paragraph.'},
        {'id': all[1], 'read_more': 'Replacement.'},
        {'id': all[2], 'read_more': 'For a problem.'},
        {'id': all[3], 'read_more': ''},
        {'id': 99999, 'read_more': 'Nobody.'},
      ]));
      expect(plan.rows.map((r) => r.status), [
        ReadMoreStatus.ok, ReadMoreStatus.alreadyHas, ReadMoreStatus.problemCard, ReadMoreStatus.nothingToAdd, ReadMoreStatus.unknownCard,
      ]);
      expect(plan.applicable.length, 2);
      expect((await fieldsOf(e.db, all[0])).containsKey('read_more'), isFalse);
    });

    test('commit writes the paragraph, marks "nothing to add" so it is never asked again, and leaves scheduling alone', () async {
      await e.addBasic(3);
      final all = await ids();
      final before = await e.allCards();
      final plan = await svc.preview(answer([
        {'id': all[0], 'read_more': 'New paragraph.'},
        {'id': all[1], 'read_more': ''},
        {'id': all[2], 'read_more': 'Not chosen.'},
      ]));
      final result = await svc.commit(plan, {0, 1});
      expect((result.added, result.none), (1, 1));
      expect((await fieldsOf(e.db, all[0]))['read_more'], 'New paragraph.');
      expect((await fieldsOf(e.db, all[1]))['read_more_none'], '1');
      expect((await fieldsOf(e.db, all[1])).containsKey('read_more'), isFalse);
      expect((await fieldsOf(e.db, all[2])).containsKey('read_more'), isFalse); // not ticked
      expect(await svc.countMissing(), 1); // only the unticked one is still offered
      expect(await e.allCards(), before);
      expect(await e.review.rebuildAll(apply: false), isEmpty);
    });

    test('a card edited between the preview and the save is never overwritten', () async {
      await e.addBasic(2);
      final all = await ids();
      final plan = await svc.preview(answer([
        {'id': all[0], 'read_more': 'From the AI.'},
        {'id': all[1], 'read_more': ''},
      ]));
      await setFields(e.db, all[0], {'read_more': 'Written by the learner meanwhile.'});
      await setFields(e.db, all[1], {'read_more': 'Also written meanwhile.'});
      final result = await svc.commit(plan, {0, 1});
      expect((result.added, result.none), (0, 0));
      expect((await fieldsOf(e.db, all[0]))['read_more'], 'Written by the learner meanwhile.');
      expect((await fieldsOf(e.db, all[1])).containsKey('read_more_none'), isFalse);
    });
  });

  group('the screen', () {
    /// A database with [cards] basic cards, and the id of the first note.
    Future<(AppDatabase, int)> seed(WidgetTester t, {int cards = 3}) async {
      final e = Env();
      addTearDown(() async => t.runAsync(e.db.close));
      await t.runAsync(() => e.addBasic(cards));
      final first = (await t.runAsync(() => e.db.select(e.db.notes).get()))!.first.id;
      return (e.db, first);
    }

    Future<void> show(WidgetTester t, AppDatabase db, Widget home) async {
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db))],
        child: MaterialApp(home: home),
      ));
      await settle(t, rounds: 4);
    }

    testWidgets('previews an answer that arrived, and saves only on the button', (t) async {
      final (db, id) = await seed(t, cards: 1);
      await show(t, db, ReadMoreScreen(initialText: answer([{'id': id, 'read_more': 'A paragraph for the curious.'}])));
      expect(find.text('Untick any you do not want. Nothing is saved until you tap the button.'), findsOneWidget);
      expect(find.textContaining('A paragraph for the curious.'), findsOneWidget);
      expect((await t.runAsync(() => fieldsOf(db, id)))!.containsKey('read_more'), isFalse);
      await t.tap(find.text('Add Read more to 1 card'));
      await settle(t, rounds: 4);
      expect((await t.runAsync(() => fieldsOf(db, id)))!['read_more'], 'A paragraph for the curious.');
      expect(find.textContaining('Added Read more to 1 card'), findsOneWidget);
    });

    testWidgets('with no answer yet it says how many cards have none and offers the batch sizes', (t) async {
      final (db, _) = await seed(t, cards: 3);
      await show(t, db, const ReadMoreScreen());
      expect(find.textContaining('3 cards have no Read more yet'), findsOneWidget);
      for (final n in ['10', '20', '30']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Send to my AI app'), findsOneWidget);
      expect(find.text('Copy prompt'), findsOneWidget);
    });

    testWidgets('an answer pasted on the general import screen opens this one', (t) async {
      final (db, id) = await seed(t, cards: 1);
      await show(t, db, ImportScreen(initialText: answer([{'id': id, 'read_more': 'Routed.'}])));
      expect(find.text('Read more for older cards'), findsOneWidget);
      expect(find.textContaining('Routed.'), findsOneWidget);
    });
  });
}
