import 'dart:convert';

import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/expr_eval.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/outline_parser.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/domain/study_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'screenshots/screens_test.dart' show boot, settle;

Map<String, dynamic> problem({
  String statement = r'A ball falls from rest through $20\ \mathrm{m}$. How fast is it going? (take $g = 9.8\ \mathrm{m/s^2}$)',
  List<String> steps = const [
    r'Energy: $mgh = \tfrac12 mv^2$, so the mass cancels.',
    r'Solve for speed: $v = \sqrt{2gh}$.',
    r'Substitute: $v = \sqrt{2 \times 9.8 \times 20}$.',
    r'Evaluate: about $19.8\ \mathrm{m/s}$.',
  ],
  String answer = r'$19.8\ \mathrm{m/s}$',
  Object? value = 19.8,
  Object? expr = 'sqrt(2*9.8*20)',
  List<Map<String, dynamic>>? variants,
}) =>
    {
      'statement': statement,
      'steps': steps,
      'answer': answer,
      'answer_value': ?value,
      'answer_expr': ?expr,
      'variants': variants ??
          [
            {'statement': r'Dropped from $5\ \mathrm{m}$?', 'answer': r'$9.9\ \mathrm{m/s}$', 'answer_value': 9.9, 'answer_expr': 'sqrt(2*9.8*5)'},
            {'statement': r'Dropped from $45\ \mathrm{m}$?', 'answer': r'$29.7\ \mathrm{m/s}$', 'answer_value': 29.7, 'answer_expr': 'sqrt(2*9.8*45)'},
          ],
    };

String answer(List<Map<String, dynamic>> problems, {List<Map<String, dynamic>>? cards}) =>
    jsonEncode({'domain': 'Physics', 'syllabus_item': 'Kinematics', 'cards': ?cards, 'problems': problems});

void main() {
  group('the calculator behind the arithmetic check', () {
    test('numbers, precedence, powers and functions', () {
      expect(evalExpression('1 + 2 * 3'), 7);
      expect(evalExpression('(1 + 2) * 3'), 9);
      expect(evalExpression('-2^2'), -4);
      expect(evalExpression('2^3^2'), 512);
      expect(evalExpression('2 * -3'), -6);
      expect(evalExpression('1.5e3 / 3'), 500);
      expect(evalExpression('sqrt(2*9.8*20)'), closeTo(19.799, 0.001));
      expect(evalExpression('log(1000)'), closeTo(3, 1e-12));
      expect(evalExpression('2*pi'), closeTo(6.2832, 0.0001));
      expect(evalExpression('ln(e)'), closeTo(1, 1e-12));
    });

    test('anything else gives null, never an exception or a surprise', () {
      for (final bad in ['', 'x + 1', '1 +', '(1', '1/0', 'sqrt(-1)', 'foo(2)', 'System.exit(0)', '1; 2', 'sqrt 4', '2 3', 'a' * 300, '${'(' * 200}1${')' * 200}']) {
        expect(evalExpression(bad), isNull, reason: bad);
      }
    });

    test('rounded claims agree with the exact value; slips do not', () {
      expect(numbersAgree(19.8, 19.799), isTrue);
      expect(numbersAgree(20, 19.799), isTrue);
      expect(numbersAgree(14.0, 19.799), isFalse);
      expect(numbersAgree(0, 0), isTrue);
    });
  });

  group('levels', () {
    test('steps shown up front fade from all to none', () {
      expect([for (var l = 1; l <= 4; l++) problemStepsGiven(3, l)], [3, 2, 1, 0]);
      expect([for (var l = 1; l <= 4; l++) problemStepsGiven(4, l)], [4, 2, 1, 0]);
      expect([for (var l = 1; l <= 4; l++) problemStepsGiven(5, l)], [5, 3, 1, 0]);
      expect([for (var l = 1; l <= 4; l++) problemStepsGiven(2, l)], [2, 1, 0, 0]);
    });
  });

  group('parsing the problems an AI writes', () {
    test('a good family parses, with the arithmetic checked', () {
      final p = parseImportJson(answer([problem()]));
      expect(p.hasFatal, isFalse, reason: p.fatalErrors.join('; '));
      final c = p.cards.single;
      expect(c.type, 'problem');
      expect(c.errors, isEmpty, reason: c.errors.join('; '));
      expect(c.steps.length, 4);
      expect(c.variants.length, 2);
      expect(c.arithmetic, 'checked');
    });

    test('a slip in the arithmetic is rejected with both numbers', () {
      final c = parseImportJson(answer([problem(value: 14.0)])).cards.single;
      expect(c.valid, isFalse);
      expect(c.errors.single, allOf(contains('arithmetic check failed'), contains('14'), contains('19.799')));
      final v = parseImportJson(answer([problem(variants: [
        {'statement': 'v?', 'answer': 'x', 'answer_value': 1.0, 'answer_expr': 'sqrt(2*9.8*5)'}
      ])])).cards.single;
      expect(v.valid, isFalse); // a wrong variant is caught too
    });

    test('no expression, or one the calculator does not know, is simply not checked', () {
      expect(parseImportJson(answer([problem(value: null, expr: null)])).cards.single.arithmetic, '');
      final unknown = parseImportJson(answer([problem(expr: 'integral(x)')])).cards.single;
      expect(unknown.valid, isTrue);
      expect(unknown.arithmetic, '');
    });

    test('too many problems in one answer are listed as invalid, not silently dropped; reserved tags are not accepted from an AI', () {
      final many = parseImportJson(answer([for (var i = 0; i < 8; i++) problem(statement: 'Problem $i?')]));
      expect(many.cards.length, 8);
      expect(many.cards.where((c) => c.valid).length, kMaxProblemsPerImport);
      expect(many.cards.last.errors.single, contains('Too many problems'));
      final tagged = problem();
      tagged['tags'] = ['free fall', 'leech', 'Problem', 'foundation', 'unverified'];
      expect(parseImportJson(answer([tagged])).cards.single.tags, ['free_fall']);
      final card = parseImportJson(jsonEncode({'domain': 'X', 'cards': [
        {'type': 'basic', 'front': 'q?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high', 'tags': ['Leech', 'physics', 'two words']}
      ]})).cards.single;
      expect(card.tags, ['physics', 'two_words']);
    });

    test('shape rules: steps 2 to 6, text fields, at most 2 variants, problems alone are enough', () {
      expect(parseImportJson(answer([problem(steps: ['only one'])])).cards.single.valid, isFalse);
      expect(parseImportJson(answer([problem(steps: List.filled(7, 'step'))])).cards.single.valid, isFalse);
      expect(parseImportJson(answer([problem(statement: '')])).cards.single.valid, isFalse);
      final many = problem(variants: [for (var i = 0; i < 5; i++) {'statement': 'v$i?', 'answer': 'a$i'}]);
      expect(parseImportJson(answer([many])).cards.single.variants.length, kMaxProblemVariants);
      final alone = parseImportJson(jsonEncode({'domain': 'Physics', 'problems': [problem()]}));
      expect(alone.hasFatal, isFalse);
      expect(parseImportJson(jsonEncode({'domain': 'Physics', 'cards': [], 'problems': []})).hasFatal, isTrue);
      expect(parseImportJson(jsonEncode({'domain': 'Physics', 'cards': [], 'problems': 'x'})).hasFatal, isTrue);
    });

    test('LaTeX with single backslashes in steps survives the repair', () {
      final raw = '{"domain":"Physics","problems":[{"statement":"Find \$\\sqrt{4}\$","steps":["Take \$\\frac{a}{b}\$","Then \$\\theta\$"],"answer":"\$2\$"}]}';
      final c = parseImportJson(raw).cards.single;
      expect(c.valid, isTrue, reason: c.errors.join('; '));
      expect(c.steps.first, r'Take $\frac{a}{b}$');
      expect(c.steps.last, r'Then $\theta$');
    });

    test('the prompt\'s own example is a valid problem', () {
      final start = kProblemsSection.indexOf('{ "statement"');
      final end = kProblemsSection.indexOf('\n- One skill per family');
      final ex = jsonDecode(kProblemsSection.substring(start, end).trim()) as Map<String, dynamic>;
      final c = parseImportJson(answer([ex])).cards.single;
      expect(c.valid, isTrue, reason: c.errors.join('; '));
      expect(c.arithmetic, 'checked');
    });
  });

  group('importing, unlocking and the daily budget', () {
    late Env e;
    final t = DateTime.utc(2025, 5, 1, 9);
    setUp(() async {
      e = Env();
      await e.settings.set(SettingsRepo.newPerDay, '0'); // problems have their own budget
      await e.settings.set(SettingsRepo.problemsPerDay, '5');
    });
    tearDown(() => e.db.close());

    Future<int> importFamily() async {
      final s = await e.import.commit(await e.import.preview(answer([problem()])), now: t);
      expect(s.notes, 3); // the family and its 2 variants
      expect(s.cards, 4 + 2);
      return (await e.db.select(e.db.notes).get()).firstWhere((n) => !n.fieldsJson.contains('variant_of')).id;
    }

    Future<List<StudyCard>> offered(DateTime at) async => (await e.queue.build(now: at)).newCards;

    test('one note with four level cards, and variants with the final level only', () async {
      final id = await importFamily();
      final notes = await e.db.select(e.db.notes).get();
      expect(notes.every((n) => n.type == 'problem' && n.tags.split(' ').contains('problem')), isTrue);
      final cards = await e.db.select(e.db.cards).get();
      expect(cards.where((c) => c.noteId == id).map((c) => c.ord).toList()..sort(), [0, 1, 2, 3]);
      final variants = notes.where((n) => n.fieldsJson.contains('variant_of')).toList();
      for (final v in variants) {
        expect((jsonDecode(v.fieldsJson) as Map)['variant_of'], '$id');
        expect(cards.where((c) => c.noteId == v.id).map((c) => c.ord), [3]);
      }
      expect(await e.import.preview(answer([problem()])).then((p) => p.status.values.single), PreviewStatus.duplicateInDb);
    });

    test('only the worked example is offered at first; each level unlocks after the one before, next day', () async {
      final id = await importFamily();
      var q = await offered(t);
      expect(q.map((c) => (c.noteId, c.ord)), [(id, 0)]); // level 1 only
      final lvl1 = q.single;
      expect(lvl1.isProblem && lvl1.problemLevel == 1 && lvl1.stepsGiven == 4, isTrue);

      await e.review.review(cardId: lvl1.id, rating: 3, durationMs: 1000, now: t);
      await e.review.review(cardId: lvl1.id, rating: 3, durationMs: 1000, now: t.add(const Duration(minutes: 11))); // graduates
      // Answered well, but the level-2 card is a sibling: buried until tomorrow.
      expect((await e.queue.build(now: t.add(const Duration(minutes: 30)))).newCards, isEmpty);
      q = await offered(t.add(const Duration(days: 1)));
      expect(q.map((c) => (c.noteId, c.ord)), [(id, 1)]);
      expect(q.single.stepsGiven, 2);
    });

    test('a level answered Again does not unlock the next; Easy skips one', () async {
      final id = await importFamily();
      final lvl1 = (await offered(t)).single;
      await e.review.review(cardId: lvl1.id, rating: 1, durationMs: 1000, now: t);
      expect(await offered(t.add(const Duration(days: 1))), isEmpty);

      await e.review.review(cardId: lvl1.id, rating: 4, durationMs: 1000, now: t.add(const Duration(days: 1)));
      final q = await offered(t.add(const Duration(days: 2)));
      expect(q.map((c) => c.ord), [2]); // Easy on level 1: level 2 is skipped, level 3 is offered
      expect(q.single.noteId, id);
    });

    test('problems do not use the new-card limit, and have their own daily budget', () async {
      await e.settings.set(SettingsRepo.problemsPerDay, '0');
      await importFamily();
      expect(await offered(t), isEmpty);
      await e.settings.set(SettingsRepo.problemsPerDay, '1');
      expect((await offered(t)).length, 1);
      await e.settings.set(SettingsRepo.newPerDay, '10');
      await e.addBasic(3, domain: 'Bio', now: t);
      final q = await offered(t);
      expect(q.where((c) => c.isProblem).length, 1);
      expect(q.where((c) => !c.isProblem).length, 3);
    });

    test('further problems are not stranded when the family\'s own problem is deleted', () async {
      final id = await importFamily();
      var day = t;
      Future<int> variants() async => (await offered(day)).where((c) => c.fields['variant_of'] != null).length;
      expect(await variants(), 0);
      await e.db.customStatement('DELETE FROM review_log WHERE card_id IN (SELECT id FROM card WHERE note_id = $id)');
      await e.db.customStatement('DELETE FROM card WHERE note_id = $id');
      await e.db.customStatement('DELETE FROM note WHERE id = $id');
      day = day.add(const Duration(days: 1));
      expect(await variants(), 2); // the two further problems are separate notes, both offered (budget 5)
    });

    test('a further problem unlocks after the family\'s third level', () async {
      final id = await importFamily();
      final cards = await e.db.select(e.db.cards).get();
      final level3 = cards.firstWhere((c) => c.noteId == id && c.ord == 2);
      var day = t;
      Future<bool> variantOffered() async => (await offered(day)).any((c) => c.fields['variant_of'] != null);
      expect(await variantOffered(), isFalse);
      await e.review.review(cardId: level3.id, rating: 3, durationMs: 1000, now: day);
      day = day.add(const Duration(days: 1));
      expect(await variantOffered(), isTrue);
    });
  });

  group('what a topic is practised with', () {
    test('the outline carries it; anything unknown means the AI decides; the learner can change it', () async {
      final e = Env();
      addTearDown(e.db.close);
      final out = OutlineService(e.db);
      final raw = jsonEncode({
        'domain': 'Physics',
        'items': [
          {'title': 'Kinematics', 'practice': 'problems'},
          {'title': 'Why things move', 'practice': 'Concepts'},
          {'title': 'Energy', 'practice': 'both'},
          {'title': 'Optics', 'practice': 'everything'},
          {'title': 'Waves'},
        ],
      });
      final prev = parseOutlineJson(raw);
      expect(prev.items.map((i) => i.practice), ['problems', 'concepts', 'both', '', '']);
      await out.commit(await out.preview(raw));
      final rows = await e.db.select(e.db.syllabusItems).get();
      expect({for (final r in rows) r.title: r.practice}, {'Kinematics': 'problems', 'Why things move': 'concepts', 'Energy': 'both', 'Optics': '', 'Waves': ''});
      final learn = LearnService(e.db, e.settings, QueueService(e.db, e.settings));
      await learn.setTopicPractice(rows.first.id, 'concepts');
      expect((await (e.db.select(e.db.syllabusItems)..where((x) => x.id.equals(rows.first.id))).getSingle()).practice, 'concepts');
      await learn.setTopicPractice(rows.first.id, 'nonsense');
      expect((await (e.db.select(e.db.syllabusItems)..where((x) => x.id.equals(rows.first.id))).getSingle()).practice, '');
    });

    test('the card prompt follows the topic: concepts only, both, problems, or the AI decides', () {
      String p(String practice) => renderPrompt(domain: 'Physics', syllabusItem: 'Kinematics', n: 8, recentTitles: const [], practice: practice);
      for (final practice in ['', 'concepts', 'both', 'problems']) {
        for (final leftover in ['{problems_clause}', '{problems_section}', '{n}']) {
          expect(p(practice), isNot(contains(leftover)), reason: '$practice $leftover');
        }
      }
      expect(p('concepts'), allOf(contains('Write concept cards only: no problems.'), isNot(contains('<problems>\nA problem family'))));
      expect(p(''), allOf(contains('If this topic is learned by solving'), contains('<problems>\nA problem family'), contains('answer_expr')));
      expect(p('both'), allOf(contains('1 problem family'), contains('answer_value')));
      expect(p('problems'), contains('write 2 problem families'));
      expect(kPromptTemplateVersion, 'v10');
      expect(kOutlineTemplateVersion, 'outline-v4');
    });
  });

  testWidgets('review: a level-2 problem hides steps; hints and the solution reveal them; the answer then shows the rating hint', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final e = (await t.runAsync(() async {
      final e = Env();
      await e.settings.set(SettingsRepo.newPerDay, '0');
      final now = DateTime.now().toUtc();
      final yesterday = now.subtract(const Duration(days: 1));
      await e.import.commit(await e.import.preview(answer([problem(variants: const [])])), now: yesterday.subtract(const Duration(hours: 1)));
      final lvl1 = (await e.db.select(e.db.cards).get()).firstWhere((c) => c.ord == 0);
      await e.review.review(cardId: lvl1.id, rating: 3, durationMs: 1000, now: yesterday);
      await e.db.customStatement('UPDATE card SET suspended = 1 WHERE ord = 0'); // keep the review queue to level 2
      return e;
    }))!;
    final key = GlobalKey();
    await boot(t, e.db, key);
    await t.tap(find.text('Start review'));
    await settle(t);

    expect(find.textContaining('Problem · level 2 of 4'), findsOneWidget);
    expect(find.text('Show next step'), findsOneWidget);
    expect(find.text('Show solution'), findsOneWidget);
    expect(find.textContaining('Hidden: work it out'), findsNWidgets(2)); // 4 steps, 2 given at level 2
    expect(find.text('Again'), findsNothing); // no rating before the solution

    await t.tap(find.text('Show next step'));
    await t.pump();
    expect(find.textContaining('Hidden: work it out'), findsNWidgets(1));
    await t.tap(find.text('Show next step'));
    await t.pump();
    expect(find.textContaining('Hidden: work it out'), findsNothing);
    expect(find.text('Show next step'), findsNothing); // nothing left to hint

    await t.tap(find.text('Show solution'));
    await settle(t);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.textContaining('You used 2 hints'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(e.db.close);
  });
}
