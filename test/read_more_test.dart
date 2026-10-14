import 'dart:convert';

import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/domain/card_edit.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/domain/talk_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

String payload(Map<String, dynamic> card) => jsonEncode({'domain': 'Bio', 'syllabus_item': null, 'cards': [card]});
Map<String, dynamic> card({Map<String, dynamic> extra = const {}}) => {
      'type': 'basic',
      'front': 'Why do mitochondria have their own DNA?',
      'back': 'They were once free-living bacteria.',
      'source_type': 'model_memory',
      'confidence': 'high',
      ...extra,
    };

/// About a hundred and fifty words, the size the prompt asks for.
final paragraph = List.filled(30, 'Bacteria were swallowed and kept').join(' ').substring(0, 900).trimRight();

void main() {
  group('Read more (D64): the answer', () {
    test('an optional paragraph, trimmed, up to its own limit', () {
      final ok = parseImportJson(payload(card(extra: {'read_more': '  $paragraph  '}))).cards.single;
      expect(ok.errors, isEmpty);
      expect(ok.readMore, paragraph);
      expect(parseImportJson(payload(card())).cards.single.readMore, '');
      final atLimit = parseImportJson(payload(card(extra: {'read_more': 'x' * kMaxReadMoreChars}))).cards.single;
      expect(atLimit.errors, isEmpty);
    });

    test('too long or not text is refused for that card, with the reason in words', () {
      final long = parseImportJson(payload(card(extra: {'read_more': 'x' * (kMaxReadMoreChars + 1)}))).cards.single;
      expect(long.errors.single, allOf(contains('read_more'), contains('$kMaxReadMoreChars')));
      final notText = parseImportJson(payload(card(extra: {'read_more': 7}))).cards.single;
      expect(notText.errors.single, contains('must be a string'));
      // The other extras keep their own, smaller limit.
      final why = parseImportJson(payload(card(extra: {'why_it_matters': 'x' * (kMaxExtraChars + 1)}))).cards.single;
      expect(why.errors.single, contains('$kMaxExtraChars'));
    });
  });

  group('Read more (D64): storage and reading order', () {
    late Env e;
    setUp(() => e = Env());
    tearDown(() => e.db.close());

    test('stored with the note, shown after the other extras, left out when empty', () async {
      final imp = ImportService(e.db);
      await imp.commit(await imp.preview(payload(card(extra: {
        'why_it_matters': 'You inherit them from your mother.',
        'memory_hook': 'A lodger with their own key.',
        'read_more': paragraph,
      }))));
      final c = (await QueueService(e.db, e.settings).build()).newCards.single;
      expect(c.fields['read_more'], paragraph);
      expect(c.extras, [
        ('Why it matters', 'You inherit them from your mother.'),
        ('Memory hook', 'A lodger with their own key.'),
        ('Read more', paragraph),
      ]);
    });

    test('a card without it is unchanged', () async {
      final imp = ImportService(e.db);
      await imp.commit(await imp.preview(payload(card())));
      final c = (await QueueService(e.db, e.settings).build()).newCards.single;
      expect(c.fields.containsKey('read_more'), isFalse);
      expect(c.extras, isEmpty);
    });

    test('the Talk it through prompt does not carry the unchecked paragraph', () {
      final t = talkCardOf(type: 'basic', fields: {'front': 'Q?', 'back': 'A', 'read_more': paragraph}, ord: 0, domain: 'Bio');
      expect(t.extras, isEmpty);
      expect(renderTalkPrompt(t), isNot(contains('Bacteria were swallowed')));
    });
  });

  group('Read more (D64): editing', () {
    test('validated like the other fields, with its own limit and name', () {
      expect(validateNoteEdit(type: 'basic', fields: {'front': 'q', 'back': 'a', 'read_more': 'x' * kMaxReadMoreChars}), isEmpty);
      final errors = validateNoteEdit(type: 'basic', fields: {'front': 'q', 'back': 'a', 'read_more': 'x' * (kMaxReadMoreChars + 1)});
      expect(errors.single, contains('Read more'));
    });

    test('saved, and clearing it removes the key', () async {
      final e = Env();
      addTearDown(e.db.close);
      final svc = CardEditService(e.db, e.settings);
      await e.addBasic(1);
      final noteId = (await svc.search()).single.noteId;
      expect(await svc.update(noteId, {'front': 'Q?', 'back': 'A', 'read_more': paragraph}), isEmpty);
      expect((await svc.note(noteId))!.fields['read_more'], paragraph);
      expect(await svc.update(noteId, {'front': 'Q?', 'back': 'A', 'read_more': ''}), isEmpty);
      expect((await svc.note(noteId))!.fields.containsKey('read_more'), isFalse);
    });
  });

  group('Read more (D64): the card prompt', () {
    String prompt() => renderPrompt(domain: 'Biology', syllabusItem: 'Cell membrane', n: 8, recentTitles: const [], sourceText: null, round: 1, learnerProfile: null);

    test('asks for it, with the size, the accuracy rule and a way out when the reply would be too long', () {
      final p = prompt();
      expect(kPromptTemplateVersion, 'v10');
      for (final must in ['"read_more"', '120 to 150 words', 'complete reply', 'never invent a quote']) {
        expect(p, contains(must), reason: must);
      }
    });
  });
}
