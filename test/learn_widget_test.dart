import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  libraryTests();
  testWidgets('Home -> Learn something new -> option -> prompt screen', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    await t.runAsync(() async {
      final out = OutlineService(db);
      await out.commit(await out.preview(
          '{"domain":"Bio","items":[{"title":"Cell membrane","target_cards":10},'
          '{"title":"Mitochondria","prerequisites":["Cell membrane"]}]}'));
    });
    await t.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db))],
      child: const DailyLearningApp(),
    ));
    await settle(t);

    await t.tap(find.text('Learn something new'));
    await settle(t);
    expect(find.text('Suggested for today'), findsOneWidget); // only one topic is unlocked
    expect(find.text('Bio: Cell membrane'), findsOneWidget);
    expect(find.text('10 cards'), findsOneWidget);

    await t.tap(find.text('Use this'));
    await settle(t);
    expect(find.text('Your prompt'), findsOneWidget);
    expect(find.text('Copy prompt'), findsOneWidget);
    expect(find.text('Paste the answer'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });

  testWidgets('Learn screen on a fresh install explains the outline-first start', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    await t.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db))],
      child: const DailyLearningApp(),
    ));
    await settle(t);
    await t.tap(find.text('Learn something new'));
    await settle(t);
    expect(find.text('Start with a subject'), findsOneWidget);
    expect(find.text('New subject or more topics'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });
}

void libraryTests() {
  testWidgets('Starter library lists bundled subjects and adds one with a tap', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    await t.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db))],
      child: const DailyLearningApp(),
    ));
    await settle(t);
    await t.tap(find.text('Learn something new'));
    await settle(t);
    await t.tap(find.text('Browse the starter library'));
    await settle(t);
    await settle(t);

    expect(find.text('Starter library'), findsOneWidget);
    expect(find.text('Thinking and Decisions'), findsOneWidget);
    expect(find.text('Add'), findsWidgets);
    await t.dragUntilVisible(
        find.text('Language course (you name it)'), find.byType(ListView), const Offset(0, -300));
    expect(find.text('Language course (you name it)'), findsOneWidget);
    await t.dragUntilVisible(find.text('Thinking and Decisions'), find.byType(ListView), const Offset(0, 300));

    await t.tap(find.widgetWithText(FilledButton, 'Add').first);
    await settle(t);
    await settle(t);
    final items = await t.runAsync(() => db.select(db.syllabusItems).get());
    expect(items!.length, 14);
    expect(find.text('Added'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });

  testWidgets('Settings -> Subjects and topics shows controls and pausing works', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    await t.runAsync(() async {
      final out = OutlineService(db);
      await out.commit(await out.preview('{"domain":"Music","items":[{"title":"Rhythm","target_cards":5}]}'));
    });
    await t.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db))],
      child: const DailyLearningApp(),
    ));
    await settle(t);
    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await t.dragUntilVisible(find.text('Subjects and topics'), find.byType(ListView), const Offset(0, -200));
    await t.tap(find.text('Subjects and topics'));
    await settle(t);

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('How often to offer'), findsOneWidget);
    expect(find.text('Bring finished topics back later'), findsOneWidget);
    await t.tap(find.text('Off'));
    await settle(t);
    expect(find.textContaining('Paused: no new prompts'), findsOneWidget);
    final dm = await t.runAsync(() => db.select(db.domains).getSingle());
    expect(dm!.learnWeight, 0);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });
}
