import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/app/share_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/presentation/talk_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test.dart' show settle;

class _Sharer implements PromptSharer {
  final sent = <String>[];
  @override
  Future<void> send(String text, {String? title}) async => sent.add(text);
}

/// D60: the sheet that hands a card to an AI app; the tag; the schedule untouched.
void main() {
  Future<(AppDatabase, int)> library() async {
    final db = AppDatabase(NativeDatabase.memory());
    await ParamsRepo(db, SettingsRepo(db)).activeId();
    final imp = ImportService(db);
    await imp.commit(
        await imp.preview(jsonEncode({
          'domain': 'Biology',
          'cards': [
            {'type': 'basic', 'front': 'Why does a cell need a membrane?', 'back': 'It controls what goes in and out.', 'source_type': 'model_memory', 'confidence': 'high'},
          ]
        })),
        now: DateTime.utc(2025, 3, 3));
    final note = (await db.select(db.notes).get()).single;
    return (db, note.id);
  }

  Widget host(AppDatabase db, _Sharer sharer, Widget child) => ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
          promptSharerProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('share: the text holds the card and what the learner typed; the note is tagged; the schedule and log are untouched', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final (db, noteId) = (await t.runAsync(library))!;
    addTearDown(() async => t.runAsync(db.close));
    final sharer = _Sharer();
    final cardBefore = (await t.runAsync(() => db.select(db.cards).get()))!.single;

    await t.pumpWidget(host(db, sharer, SingleChildScrollView(child: TalkSheet(noteId: noteId))));
    await settle(t, rounds: 3);

    expect(find.text('Talk it through with an AI'), findsOneWidget);
    expect(find.text("What's confusing you? (optional)"), findsOneWidget);
    expect(find.text('Share to an AI app'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);

    // The preview shows exactly what will be sent, and follows what is typed.
    await t.tap(find.text('What will be sent'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Question: Why does a cell need a membrane?', findRichText: true), findsOneWidget);
    await t.enterText(find.byType(TextField), 'I do not see why it must be thin');
    await t.pump();
    expect(find.textContaining('I do not see why it must be thin', findRichText: true), findsWidgets);

    await t.ensureVisible(find.text('Share to an AI app'));
    await t.tap(find.text('Share to an AI app'));
    await settle(t, rounds: 3);

    expect(sharer.sent, hasLength(1));
    expect(sharer.sent.single, contains('Question: Why does a cell need a membrane?'));
    expect(sharer.sent.single, contains('Answer: It controls what goes in and out.'));
    expect(sharer.sent.single, contains('I do not see why it must be thin'));
    expect(sharer.sent.single, contains('Subject: Biology'));

    final note = (await t.runAsync(() => db.select(db.notes).get()))!.single;
    expect(note.tags.split(' '), contains('talked_through'));
    final cardAfter = (await t.runAsync(() => db.select(db.cards).get()))!.single;
    expect((cardAfter.state, cardAfter.due, cardAfter.reps, cardAfter.lapses), (cardBefore.state, cardBefore.due, cardBefore.reps, cardBefore.lapses));
    expect((await t.runAsync(() => db.select(db.reviewLogs).get()))!, isEmpty, reason: 'the review log is the source of truth: a chat adds nothing to it');
  });

  testWidgets('copy: the text goes to the clipboard and the note is tagged once however often it is used', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final (db, noteId) = (await t.runAsync(library))!;
    addTearDown(() async => t.runAsync(db.close));

    await t.pumpWidget(host(db, _Sharer(), SingleChildScrollView(child: TalkSheet(noteId: noteId))));
    await settle(t, rounds: 3);
    await t.ensureVisible(find.text('Copy'));
    await t.tap(find.text('Copy'));
    await settle(t, rounds: 2);
    await t.tap(find.text('Copy'));
    await settle(t, rounds: 2);

    expect(copied, hasLength(2));
    expect(copied.first, contains('Question: Why does a cell need a membrane?'));
    expect(find.text('Copied. Paste it into your AI app.'), findsOneWidget);
    final tags = (await t.runAsync(() => db.select(db.notes).get()))!.single.tags.split(' ');
    expect(tags.where((x) => x == 'talked_through'), hasLength(1));
  });

  testWidgets('a card that no longer exists says so and offers Close', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final (db, _) = (await t.runAsync(library))!;
    addTearDown(() async => t.runAsync(db.close));
    await t.pumpWidget(host(db, _Sharer(), const TalkSheet(noteId: 9999)));
    await settle(t, rounds: 3);
    expect(find.text('This card no longer exists.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Share to an AI app'), findsNothing);
  });
}
