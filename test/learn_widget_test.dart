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
