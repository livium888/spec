import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/app/share_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/presentation/review_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test.dart' show settle;

class _Sharer implements PromptSharer {
  final sent = <String>[];
  @override
  Future<void> send(String text, {String? title}) async => sent.add(text);
}

/// D60: "Talk it through" inside a review: the menu item, and the nudge after a card is forgotten again.
void main() {
  Future<AppDatabase> library({required int lapsesOfFirst}) async {
    final db = AppDatabase(NativeDatabase.memory());
    await ParamsRepo(db, SettingsRepo(db)).activeId();
    final imp = ImportService(db);
    final t0 = DateTime.now().toUtc().subtract(const Duration(days: 20));
    await imp.commit(
        await imp.preview(jsonEncode({
          'domain': 'Biology',
          'cards': [
            {'type': 'basic', 'front': 'First question about membranes?', 'back': 'First answer.', 'source_type': 'model_memory', 'confidence': 'high'},
            {'type': 'basic', 'front': 'Second question about enzymes?', 'back': 'Second answer.', 'source_type': 'model_memory', 'confidence': 'high'},
          ]
        })),
        now: t0);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ids = [for (final c in await db.select(db.cards).get()) c.id]..sort();
    // Both are reviews that are due; the first is earlier, so it comes first.
    await db.customStatement("UPDATE card SET state = 'review', stability = 5, difficulty = 5, reps = 4, last_review = ?, due = ? WHERE id = ?",
        [now - 10 * 86400000, now - 7200000, ids[0]]);
    await db.customStatement("UPDATE card SET state = 'review', stability = 5, difficulty = 5, reps = 4, last_review = ?, due = ? WHERE id = ?",
        [now - 10 * 86400000, now - 3600000, ids[1]]);
    await db.customStatement('UPDATE card SET lapses = ? WHERE id = ?', [lapsesOfFirst, ids[0]]);
    return db;
  }

  Future<_Sharer> boot(WidgetTester t, AppDatabase db) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final sharer = _Sharer();
    await t.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
        promptSharerProvider.overrideWithValue(sharer),
      ],
      child: const MaterialApp(home: ReviewScreen()),
    ));
    await settle(t);
    return sharer;
  }

  testWidgets('the menu item before the answer is shown reveals the card first, and the sheet is about this card', (t) async {
    final db = (await t.runAsync(() => library(lapsesOfFirst: 0)))!;
    addTearDown(() async => t.runAsync(db.close));
    final sharer = await boot(t, db);

    expect(find.text('Show answer'), findsOneWidget);
    await t.tap(find.byTooltip('More actions for this card'));
    await settle(t, rounds: 2);
    await t.tap(find.text('Talk it through with an AI').last, warnIfMissed: false);
    await settle(t, rounds: 3);

    expect(find.text('Talk it through with an AI'), findsOneWidget); // the sheet's title
    await t.tap(find.text('What will be sent'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('First question about membranes?', findRichText: true), findsWidgets);
    expect(find.textContaining('Answer: First answer.', findRichText: true), findsOneWidget, reason: 'the preview shows the answer');
    expect(sharer.sent, isEmpty, reason: 'nothing is sent until the learner taps Share');

    // Close the sheet: the card now counts as revealed, so the rating row is there.
    await t.tapAt(const Offset(10, 10));
    await settle(t, rounds: 3);
    expect(find.text('Show answer'), findsNothing);
    expect(find.text('Again'), findsOneWidget);
  });

  testWidgets('forgetting a card for the second time offers to talk it through, about THAT card and not the next one', (t) async {
    final db = (await t.runAsync(() => library(lapsesOfFirst: 1)))!;
    addTearDown(() async => t.runAsync(db.close));
    await boot(t, db);

    await t.tap(find.textContaining('First question about membranes?'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Again'));
    await settle(t);

    expect(find.byKey(const Key('talk-nudge')), findsOneWidget);
    expect(find.textContaining('Second question about enzymes?'), findsOneWidget, reason: 'the next card is already on screen');
    // No timer on the nudge: it is still there long after the usual 6 seconds.
    await t.pump(const Duration(seconds: 20));
    expect(find.byKey(const Key('talk-nudge')), findsOneWidget);
    await t.tap(find.byKey(const Key('talk-nudge')));
    await settle(t, rounds: 3);

    await t.tap(find.text('What will be sent'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Question: First question about membranes?', findRichText: true), findsOneWidget);
    expect(find.textContaining('Question: Second question', findRichText: true), findsNothing, reason: 'the sheet holds the answered card, not the next one');
  });

  testWidgets('the nudge can be dismissed, and goes with the next answer', (t) async {
    final db = (await t.runAsync(() => library(lapsesOfFirst: 1)))!;
    addTearDown(() async => t.runAsync(db.close));
    await boot(t, db);
    await t.tap(find.textContaining('First question about membranes?'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Again'));
    await settle(t);
    expect(find.byKey(const Key('talk-nudge')), findsOneWidget);
    await t.tap(find.byKey(const Key('talk-nudge-dismiss')));
    await settle(t, rounds: 2);
    expect(find.byKey(const Key('undo-bar')), findsNothing);
    expect(find.byKey(const Key('talk-nudge')), findsNothing);
  });

  testWidgets('no nudge on a first lapse, or after a Good', (t) async {
    final db = (await t.runAsync(() => library(lapsesOfFirst: 0)))!;
    addTearDown(() async => t.runAsync(db.close));
    await boot(t, db);
    await t.tap(find.textContaining('First question about membranes?'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Again')); // lapses become 1
    await settle(t);
    expect(find.byKey(const Key('undo-bar')), findsOneWidget);
    expect(find.byKey(const Key('talk-nudge')), findsNothing);

    await t.tap(find.textContaining('Second question about enzymes?'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Good'));
    await settle(t);
    expect(find.byKey(const Key('talk-nudge')), findsNothing);
  });
}
