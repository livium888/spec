import 'dart:convert';

import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/domain/card_edit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

void main() {
  group('validateNoteEdit (pure)', () {
    test('basic needs question and answer, within limits', () {
      expect(validateNoteEdit(type: 'basic', fields: {'front': ' ', 'back': 'a'}), isNotEmpty);
      expect(validateNoteEdit(type: 'basic', fields: {'front': 'q', 'back': ''}), isNotEmpty);
      expect(validateNoteEdit(type: 'basic', fields: {'front': 'q', 'back': 'a'}), isEmpty);
      expect(validateNoteEdit(type: 'basic', fields: {'front': 'q', 'back': 'a', 'example': 'x' * 601}), isNotEmpty);
    });
    test('cloze keeps gaps that already have a card', () {
      expect(validateNoteEdit(type: 'cloze', fields: {'cloze': 'no gap'}), isNotEmpty);
      expect(validateNoteEdit(type: 'cloze', fields: {'cloze': '{{c1::a}} b'}, existingClozeNumbers: {1, 2}), isNotEmpty);
      expect(validateNoteEdit(type: 'cloze', fields: {'cloze': '{{c1::a}} {{c2::b}} {{c3::c}}'}, existingClozeNumbers: {1, 2}), isEmpty);
    });
  });

  group('CardEditService', () {
    late Env e;
    late CardEditService svc;
    setUp(() {
      e = Env();
      svc = CardEditService(e.db, e.settings);
    });

    test('editing text keeps scheduling and replay==live; clearing an optional field removes it', () async {
      await e.addBasic(1);
      final c = (await e.db.select(e.db.cards).get()).single;
      await e.review.review(cardId: c.id, rating: 3, durationMs: 1000, now: DateTime.utc(2024, 3, 1, 13));
      final before = await e.allCards();
      final note = (await svc.search()).single;
      expect(note.reviewCount, 1);

      final errors = await svc.update(note.noteId, {'front': 'New question?', 'back': 'New answer', 'example': 'e.g. this'});
      expect(errors, isEmpty);
      final after = (await svc.note(note.noteId))!;
      expect(after.fields['front'], 'New question?');
      expect(after.fields['example'], 'e.g. this');
      expect(after.fields['source_ref'] ?? '', isNot(isNull)); // untouched keys survive
      expect(await e.allCards(), before);
      expect(await e.review.rebuildAll(apply: false), isEmpty);

      await svc.update(note.noteId, {'front': 'New question?', 'back': 'New answer', 'example': ''});
      expect((await svc.note(note.noteId))!.fields.containsKey('example'), isFalse);
    });

    test('invalid edit changes nothing', () async {
      await e.addBasic(1);
      final id = (await svc.search()).single.noteId;
      final errors = await svc.update(id, {'front': '', 'back': 'a'});
      expect(errors, isNotEmpty);
      expect((await svc.note(id))!.fields['front'], contains('Question number 0'));
    });

    test('adding a cloze gap creates a card due at note creation, so rebuild still agrees', () async {
      final p = await e.import.preview(jsonEncode({
        'domain': 'Bio',
        'syllabus_item': null,
        'cards': [
          {
            'type': 'cloze',
            'cloze': 'The {{c1::heart}} pumps {{c2::blood}}.',
            'source_type': 'quote',
            'source_ref': 'b',
            'supporting_quote': 'q',
            'confidence': 'high',
          }
        ]
      }));
      await e.import.commit(p, now: DateTime.utc(2024, 3, 1));
      final id = (await svc.search()).single.noteId;
      expect(await e.db.select(e.db.cards).get().then((l) => l.length), 2);
      expect(await svc.update(id, {'cloze': 'The {{c1::heart}} pumps {{c2::blood}} via {{c3::vessels}}.'}), isEmpty);
      expect(await e.db.select(e.db.cards).get().then((l) => l.length), 3);
      expect(await svc.update(id, {'cloze': 'The {{c1::heart}} pumps blood.'}), isNotEmpty); // would drop c2
      expect(await e.review.rebuildAll(apply: false), isEmpty);
    });

    test('delete removes note, cards and their history, and leaves the rest consistent', () async {
      await e.addBasic(2);
      final cards = await e.db.select(e.db.cards).get();
      for (final c in cards) {
        await e.review.review(cardId: c.id, rating: 3, durationMs: 1000, now: DateTime.utc(2024, 3, 1, 13));
      }
      final first = (await svc.search(query: 'number 0')).single;
      expect(first.reviewCount, 1);
      await svc.delete(first.noteId);
      expect(await svc.search(), hasLength(1));
      expect(await e.db.select(e.db.cards).get().then((l) => l.length), 1);
      expect(await e.db.select(e.db.reviewLogs).get().then((l) => l.length), 1);
      expect(await e.review.rebuildAll(apply: false), isEmpty);
    });

    test('search is literal: % and _ are not wildcards', () async {
      await e.addBasic(2);
      expect(await svc.search(query: '%'), isEmpty);
      expect(await svc.search(query: 'number _'), isEmpty);
      expect(await svc.search(query: 'NUMBER 1'), hasLength(1)); // case-insensitive
    });
  });
}
