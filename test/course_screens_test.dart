import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/primer_service.dart';
import 'package:daily_learning/data/source_service.dart';
import 'package:daily_learning/domain/outline_parser.dart' show detectPayloadKind;
import 'package:daily_learning/presentation/course_screen.dart';
import 'package:daily_learning/presentation/import_screen.dart';
import 'package:daily_learning/presentation/library_screen.dart';
import 'package:daily_learning/presentation/primer_reader_screen.dart';
import 'package:daily_learning/presentation/topics_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'ui_test.dart' show settle;

final lecture = '${'Risk is the likelihood of a threat exploiting a vulnerability, and the impact is what it costs. ' * 6}'
    'Security governance aligns controls with business goals.';

String primerJson({String topic = 'Risk basics', String title = 'Risk in five minutes'}) => jsonEncode({
      'primer': {
        'domain': 'CISSP',
        'topic': topic,
        'title': title,
        'level': 2,
        'pretest': [
          {'question': 'What is risk?', 'answer': 'Likelihood times impact.'},
          {'question': 'What is a threat?', 'answer': 'Something that can exploit a weakness.'},
          {'question': 'What is impact?', 'answer': 'What a loss costs.'},
        ],
        'sections': [
          {'heading': 'Risk', 'text': 'Risk is **likelihood times impact**.'}
        ],
        'key_points': ['Risk combines likelihood and impact.'],
        'sources': ['Lecture 1'],
      }
    });

void main() {
  test('long prose is a transcript; an AI answer, a short note and JSON are not', () {
    expect(detectPayloadKind(lecture), 'transcript');
    expect(detectPayloadKind('short note'), 'cards');
    expect(detectPayloadKind('Here are your cards:\n${'x ' * 300}\n{"cards": []}'), 'cards', reason: 'prose around broken JSON is not a lecture');
    expect(detectPayloadKind(primerJson()), 'primer');
    expect(detectPayloadKind('```json\n${primerJson()}\n```'), 'primer');
    expect(detectPayloadKind(jsonEncode({'primer': 'no', 'cards': []})), 'cards');
  });

  group('screens', () {
    Future<AppDatabase> seed(WidgetTester t, {bool topic = true}) async {
      final e = Env();
      addTearDown(() async => t.runAsync(e.db.close));
      await t.runAsync(() async {
        final dom = await SourceService(e.db).ensureDomain('CISSP');
        if (topic) {
          await e.db.into(e.db.syllabusItems).insert(SyllabusItemsCompanion.insert(domainId: dom, title: 'Risk basics', position: const Value(1)));
        }
      });
      return e.db;
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

    testWidgets('a pasted lecture opens Add a lecture with its counts, and is kept only on the button', (t) async {
      final db = await seed(t);
      await show(t, db, ImportScreen(initialText: lecture));
      expect(find.text('Add a lecture'), findsWidgets);
      expect(find.textContaining('words ·'), findsOneWidget);
      expect(find.textContaining('one part'), findsOneWidget);
      expect((await t.runAsync(() => db.select(db.sources).get()))!, isEmpty, reason: 'nothing is saved before the button');

      await t.enterText(find.widgetWithText(TextField, 'Lecture title'), 'Security and risk');
      await t.ensureVisible(find.text('Save the lecture'));
      await t.tap(find.text('Save the lecture'));
      await settle(t, rounds: 6);
      final rows = (await t.runAsync(() => db.select(db.sources).get()))!;
      expect(rows.single.title, 'Security and risk');
      expect(rows.single.number, 1);
      expect(find.text('Lecture 1: Security and risk'), findsOneWidget, reason: 'it lands on the course page');
    });

    testWidgets('a lecture without a title is refused, and says why', (t) async {
      final db = await seed(t);
      await show(t, db, ImportScreen(initialText: lecture));
      await t.ensureVisible(find.text('Save the lecture'));
      await t.tap(find.text('Save the lecture'));
      await settle(t, rounds: 4);
      expect(find.textContaining('Give the lecture a title'), findsOneWidget);
      expect((await t.runAsync(() => db.select(db.sources).get()))!, isEmpty);
    });

    testWidgets('the course page offers the outline prompt and, per lecture, the primer and cards prompts', (t) async {
      final db = await seed(t);
      final dom = (await t.runAsync(() => db.select(db.domains).getSingle()))!;
      await t.runAsync(() => SourceService(db).add(domainId: dom.id, title: 'Security and risk', text: lecture));
      await show(t, db, CourseScreen(domainId: dom.id));
      expect(find.text('Outline prompt'), findsOneWidget);
      expect(find.text('Lecture 1: Security and risk'), findsOneWidget);
      await t.tap(find.text('Lecture 1: Security and risk'));
      await settle(t, rounds: 3);
      expect(find.text('Primer prompt'), findsOneWidget);
      expect(find.text('Cards prompt'), findsOneWidget);
      expect(find.byTooltip('Share Primer prompt'), findsOneWidget);
      expect(find.byTooltip('Copy Cards prompt'), findsOneWidget);
    });

    testWidgets('the Library lists Courses from lectures', (t) async {
      final db = await seed(t);
      await show(t, db, const Scaffold(body: LibraryScreen()));
      await t.scrollUntilVisible(find.text('Courses from lectures'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Courses from lectures'), findsOneWidget);
    });

    testWidgets('a primer answer previews, says what it will do, and saves only on the button', (t) async {
      final db = await seed(t);
      await show(t, db, ImportScreen(initialText: primerJson()));
      expect(find.text('Risk in five minutes'), findsOneWidget);
      expect(find.textContaining('For the topic you have'), findsOneWidget);
      expect(find.textContaining('3 questions to try first'), findsOneWidget);
      expect((await t.runAsync(() => db.select(db.primers).get()))!, isEmpty);
      await t.tap(find.text('Save 1 primer'));
      await settle(t, rounds: 4);
      expect((await t.runAsync(() => db.select(db.primers).get()))!.length, 1);
      expect(find.textContaining('Saved 1 primer'), findsOneWidget);
    });

    testWidgets('a primer for a subject you do not have is skipped, with the reason', (t) async {
      final db = await seed(t);
      final raw = (jsonDecode(primerJson()) as Map)['primer'] as Map;
      await show(t, db, ImportScreen(initialText: jsonEncode({'primer': {...raw, 'domain': 'Nothing like it'}})));
      expect(find.textContaining('You have no subject with this name'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Save 0 primers'), findsOneWidget);
    });

    testWidgets('a card whose quote is not in the lecture is flagged and starts unticked', (t) async {
      final db = await seed(t);
      final dom = (await t.runAsync(() => db.select(db.domains).getSingle()))!;
      await t.runAsync(() => SourceService(db).add(domainId: dom.id, title: 'L1', text: lecture));
      final cards = jsonEncode({
        'domain': 'CISSP',
        'syllabus_item': 'Risk basics',
        'cards': [
          {'type': 'basic', 'front': 'What is risk?', 'back': 'Likelihood times impact.', 'source_type': 'quote', 'source_ref': 'L1', 'supporting_quote': 'Risk is the likelihood of a threat exploiting a vulnerability', 'confidence': 'high', 'tags': []},
          {'type': 'basic', 'front': 'What is governance?', 'back': 'Aligning controls.', 'source_type': 'quote', 'source_ref': 'L1', 'supporting_quote': 'Governance means the board sets the sails of the organisation', 'confidence': 'high', 'tags': []},
        ]
      });
      await show(t, db, ImportScreen(initialText: cards));
      expect(find.textContaining('Quote not found in your lecture transcripts'), findsOneWidget);
      expect(find.text('Import 1 card'), findsOneWidget, reason: 'the found one is ticked, the other is not');
    });

    testWidgets('the primer reader: try first, read, mark read, add the questions as cards', (t) async {
      final db = await seed(t);
      await t.runAsync(() async {
        final svc = PrimerService(db);
        await svc.commit(await svc.preview(primerJson()), {0});
      });
      final topicId = (await t.runAsync(() => db.select(db.syllabusItems).getSingle()))!.id;
      await show(t, db, PrimerReaderScreen(topicId: topicId, topicTitle: 'Risk basics'));
      expect(find.text('Try these first'), findsOneWidget);
      expect(find.text('Likelihood times impact.'), findsNothing, reason: 'the answer is hidden until asked for');
      await t.tap(find.text('Show the answer').first);
      await settle(t, rounds: 2);
      expect(find.text('Likelihood times impact.'), findsOneWidget);
      expect(find.textContaining('Written by an AI'), findsOneWidget);

      await t.ensureVisible(find.text('I have read it'));
      await t.tap(find.text('I have read it'));
      await settle(t, rounds: 4);
      expect(find.textContaining('Marked as read'), findsOneWidget);
      expect((await t.runAsync(() => db.select(db.primers).getSingle()))!.readAt, isNotNull);

      await t.ensureVisible(find.text('Add the 3 questions as cards'));
      await t.tap(find.text('Add the 3 questions as cards'));
      await settle(t, rounds: 4);
      expect(find.textContaining('Added 3 cards'), findsOneWidget);
    });

    testWidgets('knowing nearly all the questions offers to skip the reading, and never forces it', (t) async {
      final db = await seed(t);
      await t.runAsync(() async {
        final svc = PrimerService(db);
        await svc.commit(await svc.preview(primerJson()), {0});
      });
      final topicId = (await t.runAsync(() => db.select(db.syllabusItems).getSingle()))!.id;
      await show(t, db, PrimerReaderScreen(topicId: topicId, topicTitle: 'Risk basics'));
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('Show the answer').first);
        await settle(t, rounds: 2);
      }
      for (var i = 0; i < 3; i++) {
        final chip = find.text('I knew it').at(i);
        await t.ensureVisible(chip);
        await t.tap(chip);
        await settle(t, rounds: 1);
      }
      expect(find.textContaining('You knew 3 of 3'), findsOneWidget);
      await t.tap(find.text('Read it anyway'));
      await settle(t, rounds: 2);
      expect(find.text('Try these first'), findsNothing);
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('a topic with a primer shows the book, and its menu offers to read it', (t) async {
      final db = await seed(t);
      await t.runAsync(() async {
        final svc = PrimerService(db);
        await svc.commit(await svc.preview(primerJson()), {0});
      });
      await show(t, db, const TopicsScreen());
      expect(find.byTooltip('Primer, not read yet'), findsOneWidget);
      await t.tap(find.byTooltip('Primer, not read yet'));
      await settle(t, rounds: 4);
      expect(find.text('Try these first'), findsOneWidget);
    });
  });
}
