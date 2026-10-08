import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dir_asset_bundle.dart';

Future<void> settle(WidgetTester t, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump(const Duration(milliseconds: 50));
  }
  // Let route transitions finish so only the top screen counts as visible.
  await t.pump(const Duration(seconds: 1));
}

/// Pump (with real async gaps for the database) until [f] appears, up to ~20 s under load.
Future<void> until(WidgetTester t, Finder f) async {
  for (var i = 0; i < 200 && f.evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<AppDatabase> boot(WidgetTester t, {bool seed = false, Map<String, String> settings = const {}}) async {
  // A phone-sized screen (the default 800x600 test surface is shorter than any phone).
  t.view.physicalSize = const Size(411, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final db = AppDatabase(NativeDatabase.memory());
  await t.runAsync(() async {
    if (seed) {
      final out = OutlineService(db);
      await out.commit(await out.preview(
          '{"domain":"Bio","items":[{"title":"Cell membrane","target_cards":10},'
          '{"title":"Mitochondria","prerequisites":["Cell membrane"]}]}'));
    }
    final s = SettingsRepo(db);
    for (final e in settings.entries) {
      await s.set(e.key, e.value);
    }
  });
  await t.pumpWidget(ProviderScope(
    overrides: [
      bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
      assetBundleProvider.overrideWithValue(DirAssetBundle('docs/starter-outlines')),
    ],
    child: const DailyLearningApp(),
  ));
  await settle(t);
  return db;
}

Future<void> done(WidgetTester t, AppDatabase db) async {
  await t.pumpWidget(const SizedBox());
  await t.runAsync(db.close);
}

void main() {
  testWidgets('ONE press: Home -> prompt screen, no choosing, with the reasons and the advice', (t) async {
    final db = await boot(t, seed: true);
    expect(find.textContaining('Good time to learn'), findsOneWidget); // advice on Home

    await t.tap(find.text('Learn something new'));
    await settle(t);

    expect(find.text('Your prompt'), findsOneWidget);
    expect(find.text('Bio: Cell membrane'), findsOneWidget);
    expect(find.text('Why this one'), findsOneWidget);
    expect(find.textContaining('Next uncovered topic'), findsOneWidget);
    expect(find.textContaining('Good time to learn'), findsOneWidget);
    expect(find.text('Copy prompt'), findsOneWidget);
    expect(find.text('Paste the answer'), findsOneWidget);
    expect(find.text('See all options'), findsOneWidget);
    final logs = await t.runAsync(() => db.select(db.promptLogs).get());
    expect(logs!.single.cardsRequested, 10);
    await done(t, db);
  });

  testWidgets('the very first press on a fresh install sets up subjects and goes straight to a prompt', (t) async {
    final db = await boot(t);
    await t.tap(find.text('Learn something new'));
    await until(t, find.text('Your prompt'));
    await settle(t);

    expect(find.text('Your prompt'), findsOneWidget);
    final domains = await t.runAsync(() => db.select(db.domains).get());
    expect(domains!.length, 15); // every bundled subject except the name-it-yourself template
    await done(t, db);
  });

  testWidgets('when the advice is "stop", the app says why and lets you decide', (t) async {
    final db = await boot(t, seed: true, settings: {SettingsRepo.newPerDay: '0'});
    await t.tap(find.text('Learn something new'));
    await settle(t);

    expect(find.text('Your prompt'), findsNothing);
    expect(find.text('No new cards today'), findsOneWidget);
    expect(find.text('OK, I will stop here'), findsOneWidget);
    expect(find.textContaining('Add just 3 cards anyway'), findsOneWidget);

    await t.tap(find.textContaining('Add just 3 cards anyway'));
    await settle(t);
    expect(find.text('Your prompt'), findsOneWidget);
    final logs = await t.runAsync(() => db.select(db.promptLogs).get());
    expect(logs!.single.cardsRequested, 3);
    await done(t, db);
  });

  testWidgets('"See all options" still lists the alternatives for anyone who wants to choose', (t) async {
    final db = await boot(t, seed: true);
    await t.tap(find.text('Learn something new'));
    await settle(t);
    await t.tap(find.text('See all options'));
    await until(t, find.text('Suggested for today'));
    await settle(t);

    expect(find.text('Suggested for today'), findsOneWidget);
    expect(find.text('Use this'), findsOneWidget);
    expect(find.text('Starter library'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('pressing again before importing shows the same prompt, flagged as not yet imported', (t) async {
    final db = await boot(t, seed: true);
    await t.tap(find.text('Learn something new'));
    await settle(t);
    expect(find.text('Your prompt'), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    await settle(t);

    await t.tap(find.text('Learn something new'));
    await settle(t);
    expect(find.textContaining('have not imported the answer yet'), findsOneWidget);
    expect(find.text('Discard and pick again'), findsOneWidget);
    final logs = await t.runAsync(() => db.select(db.promptLogs).get());
    expect(logs!.length, 1); // no second prompt was created
    await done(t, db);
  });

  testWidgets('Starter library lists bundled subjects and adds one with a tap', (t) async {
    final db = await boot(t);
    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await t.dragUntilVisible(find.text('Subjects and topics'), find.byType(ListView), const Offset(0, -200));
    await t.tap(find.text('Subjects and topics'));
    await settle(t);
    await t.tap(find.textContaining('Add subjects from the starter library'));
    await until(t, find.text('Thinking and Decisions'));
    await settle(t);

    expect(find.text('Starter library'), findsOneWidget);
    expect(find.text('Thinking and Decisions'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Add').first);
    await until(t, find.text('Added'));
    await settle(t);
    final items = await t.runAsync(() => db.select(db.syllabusItems).get());
    expect(items!.length, 14);
    expect(find.text('Added'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('Settings -> Subjects and topics shows controls and pausing works', (t) async {
    final db = await boot(t);
    await t.runAsync(() async {
      final out = OutlineService(db);
      await out.commit(await out.preview('{"domain":"Music","items":[{"title":"Rhythm","target_cards":5}]}'));
    });
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
    await done(t, db);
  });
}
