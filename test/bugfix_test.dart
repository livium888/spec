// Regression tests for bugs found in review (D45).
import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/foundation_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/card_markup.dart';
import 'package:daily_learning/domain/cloze.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/domain/study_card.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

Map<String, dynamic> card(String front) =>
    {'type': 'basic', 'front': front, 'back': 'A short answer', 'source_type': 'model_memory', 'confidence': 'high'};

void main() {
  group('cloze gaps holding formulas', () {
    test('braces inside the answer do not end the gap early', () {
      const text = r'The speed is {{c1::$\sqrt{\frac{a}{b}}$}} here and {{c2::$e^{-x^{2}}$::the bell}}.';
      final m = findClozes(text);
      expect(m.map((x) => x.number), [1, 2]);
      expect(m[0].answer, r'$\sqrt{\frac{a}{b}}$');
      expect(m[1].answer, r'$e^{-x^{2}}$');
      expect(m[1].hint, 'the bell');
      expect(replaceClozes(text, (x) => '[${x.number}]'), 'The speed is [1] here and [2].');
    });

    test('plain gaps, hints, an unclosed gap and nothing at all behave as before', () {
      expect(findClozes('{{c1::Paris}} is the capital').single.answer, 'Paris');
      expect(findClozes('{{c1::Paris::city}}').single.hint, 'city');
      expect(findClozes('{{c1::never closed'), isEmpty);
      expect(findClozes('{{c1::a}} and {{c1::b}}').length, 2);
      expect(clozeNumbersOf('{{c2::x}} {{c1::y}} {{c2::z}}'), {1, 2});
      expect(findClozes('no gaps here {{not a gap}}'), isEmpty);
    });

    test('a card with such a gap imports, and its question and answer read right', () {
      final p = parseImportJson(jsonEncode({
        'domain': 'Physics',
        'cards': [{...card(''), 'type': 'cloze', 'cloze': r'Speed: {{c1::$\sqrt{\frac{a}{b}}$}} m/s.', 'back': ''}],
      }));
      final c = p.cards.single;
      expect(c.errors, isEmpty, reason: c.errors.join('; '));
      expect(c.clozeNumbers, {1});
      final sc = StudyCard(
        snapshot: _snap(), noteId: 1, domainId: 1, noteType: 'cloze', fields: {'cloze': c.cloze}, tags: const [], ord: 0, suspended: false);
      expect(sc.front, 'Speed: [...] m/s.');
      expect(sc.back, r'Speed: $\sqrt{\frac{a}{b}}$ m/s.');
      expect(sc.clozeParts.where((x) => x.isGap).single.text, r'$\sqrt{\frac{a}{b}}$');
    });
  });

  group('LaTeX repair', () {
    String roundTrip(String raw) => (jsonDecode(repairJsonStrings(raw)) as Map)['t'] as String;

    test('single-backslash commands that share a letter with a JSON escape are still repaired', () {
      for (final cmd in [r'\nRightarrow', r'\bigoplus', r'\textcolor', r'\rightleftarrows', r'\rtimes', r'\underbrace', r'\forall', r'\theta', r'\nabla', r'\beta']) {
        expect(roundTrip('{"t":"x \$a $cmd b\$ y"}'), 'x \$a $cmd b\$ y', reason: cmd);
      }
    });

    test('a real JSON line break or tab around a formula stays a line break or tab', () {
      expect(roundTrip(r'{"t":"Line one\nLine two $x$\tand a tab"}'), 'Line one\nLine two \$x\$\tand a tab');
      expect(roundTrip(r'{"t":"It costs $5.\nNext line"}'), 'It costs \$5.\nNext line');
    });
  });

  group('citation markers', () {
    test('real text in 【】 brackets and other private-use-free text is kept; chat-app markers are removed', () {
      expect(stripCitationMarkers('Japanese: 【名詞】 means noun'), 'Japanese: 【名詞】 means noun');
      expect(stripCitationMarkers('Fact【4:0†source】 here'), 'Fact here');
      expect(stripCitationMarkers('Factciteturn0search0 here'), 'Fact here');
    });
  });

  group('speech and prompts', () {
    test('exponents are spoken whole', () {
      expect(plainFromMarkup(r'$x^{23}$'), 'x to the power 23');
      expect(plainFromMarkup(r'$10^{2.5}$'), '10 to the power 2.5');
      expect(plainFromMarkup(r'$x^2$ and $y^{3}$'), 'x squared and y cubed');
    });

    test('quotes and backslashes in a subject name keep the prompt\'s example valid JSON', () {
      for (final p in [
        renderPrompt(domain: r'Say "hi" \ there', syllabusItem: r'A "topic" with \ slash', n: 3, recentTitles: const []),
        renderFoundationsPrompt(domain: r'Say "hi" \ there', syllabusItem: r'A "topic" with \ slash', noteId: 1, front: 'f', back: 'b', recentTitles: const []),
        renderOutlinePrompt(domain: r'Say "hi" \ there', existingTitles: const []),
        renderRemediatePrompt(domain: r'Say "hi" \ there', syllabusItem: r'A "topic" with \ slash', problems: const []),
      ]) {
        expect(p, contains(r'"domain": "Say \"hi\" \\ there"'));
        expect(p, isNot(contains('{domain_json}')));
      }
      expect(renderPrompt(domain: 'D', syllabusItem: r'A "topic" with \ slash', n: 3, recentTitles: const []), contains(r'"syllabus_item": "A \"topic\" with \\ slash"'));
    });
  });

  group('foundations and the queue', () {
    late Env e;
    final t = DateTime.utc(2025, 5, 1, 9);
    setUp(() async {
      e = Env();
      await e.settings.set(SettingsRepo.newPerDay, '50');
      await e.addBasic(1, domain: 'Econ', now: t);
    });
    tearDown(() => e.db.close());

    Future<int> firstNote() async => (await e.db.select(e.db.notes).get()).first.id;

    test('an answer to an ORDINARY prompt is never taken for foundations, even after an unimported foundations prompt', () async {
      final id = await firstNote();
      await FoundationService(e.db, e.settings).promptFor(id, now: t); // issued, never imported
      // The learner then asks for ordinary cards and imports that answer (no foundation_of in it).
      await e.db.into(e.db.promptLogs).insert(PromptLogsCompanion.insert(
          createdAt: t.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
          domainId: const Value(1),
          templateVersion: kPromptTemplateVersion,
          promptText: 'an ordinary card prompt',
          cardsRequested: 6));
      final s = await e.import.commit(await e.import.preview(jsonEncode({'domain': 'Econ', 'cards': [for (var i = 0; i < 6; i++) card('Ordinary $i?')]})));
      expect(s.notes, 6); // not cut at 4
      expect(await FoundationService(e.db, e.settings).countFor(id), 0);
      final notes = await e.db.select(e.db.notes).get();
      expect(notes.any((n) => n.fieldsJson.contains('foundation_of')), isFalse);
    });

    test('a note that is itself a foundation card cannot have foundations', () async {
      final id = await firstNote();
      await e.import.commit(await e.import.preview(jsonEncode({'domain': 'Econ', 'foundation_of': id, 'cards': [card('F one?')]})));
      final f = (await e.db.select(e.db.notes).get()).firstWhere((n) => n.fieldsJson.contains('foundation_of'));
      await e.import.commit(await e.import.preview(jsonEncode({'domain': 'Econ', 'foundation_of': f.id, 'cards': [card('F of F?')]})));
      expect(await FoundationService(e.db, e.settings).countFor(f.id), 0);
    });

    test('at most 8 foundation cards are introduced a day, however many times the queue is rebuilt', () async {
      final id = await firstNote();
      // Make 16 foundation cards for the one original card (bypassing the per-request cap).
      for (var i = 0; i < 16; i++) {
        await e.db.customStatement("INSERT INTO note (guid, domain_id, type, fields_json, tags, source_type, source_ref, llm_confidence, created_at) "
            "VALUES ('g$i', 1, 'basic', '{\"front\":\"Bulk $i?\",\"back\":\"A\",\"foundation_of\":\"$id\"}', 'foundation', 'model_memory', '', 'high', ${t.millisecondsSinceEpoch})");
        final nid = (await e.db.customSelect('SELECT last_insert_rowid() AS i').getSingle()).read<int>('i');
        await e.db.customStatement('INSERT INTO card (note_id, ord, due) VALUES ($nid, 0, ${t.millisecondsSinceEpoch})');
      }
      var answered = 0;
      for (var step = 0; step < 40; step++) {
        final q = await e.queue.build(now: t.add(Duration(minutes: step)));
        final f = q.newCards.where((c) => c.fields['foundation_of'] != null).toList();
        expect(f.length, lessThanOrEqualTo(kMaxFoundationPerDay - answered));
        if (f.isEmpty) break;
        await e.review.review(cardId: f.first.id, rating: 3, durationMs: 1000, now: t.add(Duration(minutes: step)));
        answered++;
      }
      expect(answered, kMaxFoundationPerDay);
    });

    test('a new problem family is offered even when many started families have locked cards in front of it', () async {
      await e.settings.set(SettingsRepo.problemsPerDay, '3');
      Map<String, dynamic> prob(int n) => {
            'statement': 'Problem $n?', 'steps': ['a $n', 'b $n', 'c $n'], 'answer': 'x',
          };
      // 25 families (4 cards each, 3 locked): more locked cards than one page of candidates.
      for (var i = 0; i < 25; i++) {
        await e.import.commit(await e.import.preview(jsonEncode({'domain': 'Econ', 'problems': [prob(i)]})), now: t);
      }
      // Only the first card of each family is unlocked: answer none, so all 25 level-1 cards are available,
      // and 75 locked ones sit between them. Offer, answer and bury the first 25 families' level 1 over days.
      var day = t;
      var seen = <int>{};
      for (var d = 0; d < 30 && seen.length < 25; d++) {
        final q = await e.queue.build(now: day);
        for (final c in q.newCards.where((c) => c.isProblem)) {
          seen.add(c.noteId);
          await e.review.review(cardId: c.id, rating: 1, durationMs: 1000, now: day); // Again: never unlocks the next level
        }
        day = day.add(const Duration(days: 1));
      }
      expect(seen.length, 25, reason: 'every family\'s first card must be reachable although locked cards sit before it');
    });
  });
}

CardSnapshot _snap() => const CardSnapshot(id: 1, due: 0);
