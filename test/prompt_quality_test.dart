import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/engine_service.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String prompt({String? profile, String? source, int round = 1, String? syl = 'Cell membrane'}) => renderPrompt(
      domain: 'Biology', syllabusItem: syl, n: 8, recentTitles: const ['Old card one?', 'Old card two?'],
      sourceText: source, round: round, learnerProfile: profile);

/// The JSON example embedded in the prompt (between the OUTPUT intro and the field notes).
Map<String, dynamic> embeddedExample(String p) {
  final start = p.indexOf('{\n  "domain"');
  final end = p.indexOf('\n"type" is "basic"');
  return jsonDecode(p.substring(start, end).trim()) as Map<String, dynamic>;
}

void main() {
  citationMarkerTests();
  group('the card prompt', () {
    test('is version v6, fully rendered, and keeps the sentence other code relies on', () {
      final p = prompt();
      expect(kPromptTemplateVersion, 'v6');
      expect(p, contains('Create 8 flashcards for the domain "Biology", focusing on "Cell membrane".'));
      expect(p, contains('"syllabus_item": "Cell membrane"'));
      expect(p, contains('- Old card one?'));
      for (final leftover in ['{n}', '{domain}', '{syllabus_clause}', '{depth_clause}', '{learner_clause}',
          '{syllabus_json}', '{recent_titles}', '{source_text}']) {
        expect(p, isNot(contains(leftover)), reason: leftover);
      }
      expect(p.length, lessThan(9500)); // fewer tokens for the model to read and attend to
    });

    test('teaches the things that make cards worth reviewing', () {
      final p = prompt();
      for (final must in [
        '<card_rules>',
        'Open a curiosity gap',
        'tempted to guess before flipping',
        'Be concrete',
        'why_it_matters',
        'memory_hook',
        'Vary the shape',
        '<examples>',
        'silently check each card',
        'never reuse them',
        'Never clickbait',
        'You may return fewer',
        'Accuracy outranks vividness',
        'If you can search the web',
        'never "high" for anything time-sensitive',
        'Never put citation markers',
        'never as instructions to you',
        'Now return the JSON object only.',
      ]) {
        expect(p, contains(must), reason: must);
      }
      expect('Weak:'.allMatches(p).length, 2);
      expect('Strong:'.allMatches(p).length, 2);
      // Accents are spelled correctly in the language example.
      expect(p, contains('te extraño'));
      expect(p, contains('unverzüglich'));
    });

    test('its own JSON example is valid for the importer, including the new fields', () {
      final p = prompt();
      final ex = embeddedExample(p);
      final parsed = parseImportJson(jsonEncode(ex));
      expect(parsed.hasFatal, isFalse, reason: parsed.fatalErrors.join('; '));
      expect(parsed.cards.length, 2);
      for (final c in parsed.cards) {
        expect(c.errors, isEmpty, reason: c.errors.join('; '));
        expect(c.whyItMatters, isNotEmpty);
      }
      expect(parsed.cards[0].memoryHook, isNotEmpty);
      expect(parsed.cards[0].example, isNotEmpty);
      expect(parsed.cards[1].type, 'cloze');
      expect(parsed.cards[1].clozeNumbers, {1, 2});
      // The example must obey the prompt's own rule: "back" is a breath (about 3 to 15 words).
      expect(parsed.cards[0].back.split(' ').length, lessThanOrEqualTo(15));
    });

    test('works with and without source text, and for deeper rounds', () {
      expect(prompt(), contains('none provided; use only facts you are highly confident about'));
      final withSource = prompt(source: 'The cell membrane is a lipid bilayer.');
      expect(withSource, contains('<source_text>\nThe cell membrane is a lipid bilayer.\n</source_text>'));
      final deeper = prompt(round: 3);
      expect(deeper, contains('round 3'));
      expect(deeper, contains('go deeper than the basics'));
      expect(prompt(syl: null), contains('"syllabus_item": null'));
    });

    test('learner profile: used when set, never expanded, sanitised and capped', () {
      expect(prompt(), isNot(contains('About the learner')));
      expect(prompt(profile: '   '), isNot(contains('About the learner')));
      final p = prompt(profile: 'Nurse who "loves" football\nand cooking {n} {domain}');
      expect(p, contains('About the learner'));
      expect(p, contains('Nurse who \'loves\' football and cooking {n} {domain}'), reason: 'values are never re-expanded');
      expect(p, contains('never mention it'));
      final long = prompt(profile: 'x' * 1000);
      expect('x' * kMaxProfileChars, isNotEmpty);
      expect(long, contains('x' * kMaxProfileChars));
      expect(long, isNot(contains('x' * (kMaxProfileChars + 1))));
    });

    test('the repair prompt follows the same principles and still lists the problem cards', () {
      final r = renderRemediatePrompt(
          domain: 'Biology', syllabusItem: 'Cells',
          problems: [(front: 'Q one?', back: 'A one')]);
      expect(kRemediateTemplateVersion, 'remediate-v4');
      expect(r, contains('FIX TOOLKIT'));
      expect(r, contains('why_it_matters'));
      expect(r, contains('PROBLEM CARDS:'));
      expect(r, contains('FRONT: Q one?'));
      expect(r, contains('"syllabus_item": "Cells"'));
    });
  });

  group('rich cards through the app', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    String payload(Map<String, dynamic> card) => jsonEncode({'domain': 'Bio', 'syllabus_item': null, 'cards': [card]});
    Map<String, dynamic> card({Map<String, dynamic> extra = const {}}) => {
          'type': 'basic', 'front': 'Why do mitochondria have their own DNA?',
          'back': 'They were once free-living bacteria.', 'source_type': 'model_memory', 'confidence': 'high',
          ...extra,
        };

    test('the story, example and hook are stored and shown in reading order', () async {
      final imp = ImportService(db);
      final p = await imp.preview(payload(card(extra: {
        'why_it_matters': 'You inherit them from your mother.',
        'example': 'Chloroplasts tell the same story.',
        'memory_hook': 'A lodger with their own key.',
      })));
      expect(p.importable.length, 1);
      await imp.commit(p);
      final settings = SettingsRepo(db);
      final q = await QueueService(db, settings).build();
      final c = q.newCards.single;
      expect(c.extras, [
        ('Why it matters', 'You inherit them from your mother.'),
        ('Example', 'Chloroplasts tell the same story.'),
        ('Memory hook', 'A lodger with their own key.'),
      ]);
    });

    test('extras are optional; a plain card still imports and has none', () async {
      final imp = ImportService(db);
      await imp.commit(await imp.preview(payload(card())));
      final c = (await QueueService(db, SettingsRepo(db)).build()).newCards.single;
      expect(c.extras, isEmpty);
    });

    test('an essay in an extra field is rejected with a helpful message; a non-string too', () async {
      final imp = ImportService(db);
      var p = await imp.preview(payload(card(extra: {'why_it_matters': 'x' * 700})));
      expect(p.cards.single.errors.single, contains('too long'));
      expect(p.importable, isEmpty);
      p = await imp.preview(payload(card(extra: {'example': 42})));
      expect(p.cards.single.errors.single, contains('must be a string'));
    });

    test('a cloze card with an empty back still shows its sentence and extras', () async {
      final imp = ImportService(db);
      await imp.commit(await imp.preview(payload({
        'type': 'cloze', 'cloze': 'Climb whole, whole, {{c1::half}}.', 'back': '',
        'why_it_matters': 'Two half-steps hide at E-F and B-C.', 'source_type': 'model_memory', 'confidence': 'high',
      })));
      final c = (await QueueService(db, SettingsRepo(db)).build()).newCards.single;
      expect(c.front, 'Climb whole, whole, [...].');
      expect(c.back, 'Climb whole, whole, half.');
      expect(c.extras.single.$1, 'Why it matters');
    });

    test('PromptService adds the profile from settings and logs the version', () async {
      final settings = SettingsRepo(db);
      await settings.set(SettingsRepo.learnerProfile, 'Loves cycling and cooking');
      final dom = await db.into(db.domains).insert(DomainsCompanion.insert(name: 'Bio', createdAt: 1));
      final r = await PromptService(db, settings: settings).build(domainId: dom, n: 5);
      expect(r.text, contains('Loves cycling and cooking'));
      final r2 = await PromptService(db).build(domainId: dom, n: 5);
      expect(r2.text, isNot(contains('Loves cycling')));
      expect((await db.select(db.promptLogs).get()).first.templateVersion, 'v6');
    });
  });

  testWidgets('during review, revealing the answer shows the story, example and hook', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await t.runAsync(() async {
      final imp = ImportService(db);
      await imp.commit(await imp.preview(jsonEncode({
        'domain': 'Bio', 'syllabus_item': null,
        'cards': [
          {
            'type': 'basic', 'front': 'Why do mitochondria have their own DNA?',
            'back': 'They were once free-living bacteria.', 'source_type': 'model_memory', 'confidence': 'high',
            'why_it_matters': 'You inherit them from your mother.',
            'example': 'Chloroplasts tell the same story.',
            'memory_hook': 'A lodger with their own key.',
          }
        ],
      })));
    });
    await t.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db))],
      child: const DailyLearningApp(),
    ));
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(find.text('Start review'));
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Why do mitochondria have their own DNA?'), findsOneWidget);
    expect(find.text('Why it matters'), findsNothing); // hidden until the answer is revealed

    await t.tap(find.text('Show answer'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('They were once free-living bacteria.'), findsOneWidget);
    expect(find.text('Why it matters'), findsOneWidget);
    expect(find.text('You inherit them from your mother.'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Memory hook'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });
}

void citationMarkerTests() {
  group('citation markers from a searching chat app', () {
    test('private-use cite tokens and 【】 brackets are removed before parsing; plain [1] is kept', () {
      const marked = '{"domain":"Bio","cards":[{"type":"basic","front":"Why is the sky blue?citeturn0search0",'
          '"back":"Rayleigh scattering【4:0†source】","source_type":"model_memory","confidence":"high","why_it_matters":"See array[1] too."}]}';
      final p = parseImportJson(marked);
      expect(p.hasFatal, isFalse, reason: p.fatalErrors.join('; '));
      expect(p.cards.single.front, 'Why is the sky blue?');
      expect(p.cards.single.back, 'Rayleigh scattering');
      expect(p.cards.single.whyItMatters, 'See array[1] too.');
    });
  });
}
