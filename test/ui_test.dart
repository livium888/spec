import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/main.dart';
import 'package:daily_learning/presentation/widgets/activity_heatmap.dart';
import 'package:daily_learning/presentation/widgets/confetti.dart';
import 'package:daily_learning/presentation/widgets/progress_ring.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dir_asset_bundle.dart';

Future<void> settle(WidgetTester t, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pump(const Duration(seconds: 1));
}

/// A small account: one subject, 6 cards, three consecutive days of study ending now.
Future<AppDatabase> seeded() async {
  final db = AppDatabase(NativeDatabase.memory());
  final settings = SettingsRepo(db);
  final review = ReviewService(db, settings, ParamsRepo(db, settings));
  final imp = ImportService(db);
  final now = DateTime.now().toUtc();
  await imp.commit(
      await imp.preview(jsonEncode({
        'domain': 'Music',
        'cards': [
          for (var i = 0; i < 6; i++)
            {'type': 'basic', 'front': 'Music question $i about scales?', 'back': 'Answer $i',
             'source_type': 'model_memory', 'confidence': 'high'}
        ],
      })),
      now: now.subtract(const Duration(days: 5)));
  final ids = [for (final c in await db.select(db.cards).get()) c.id];
  for (var d = 2; d >= 0; d--) {
    await review.review(cardId: ids[d], rating: 4, durationMs: 6000, now: now.subtract(Duration(days: d, minutes: 5)));
  }
  return db;
}

Future<AppDatabase> boot(WidgetTester t, {bool seed = true}) async {
  t.view.physicalSize = const Size(411, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final db = seed ? (await t.runAsync(seeded))! : AppDatabase(NativeDatabase.memory());
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
  testWidgets('Today: hero shows what is left, the streak, the subject tile and the one big button', (t) async {
    final db = await boot(t);
    expect(find.textContaining('Good '), findsWidgets); // greeting
    expect(find.text('3-day streak'), findsOneWidget);
    expect(find.textContaining('cards waiting'), findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget); // answered some today
    expect(find.text('Your subjects'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Learn something new'), findsOneWidget);
    expect(find.byTooltip('Settings and backup'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('bottom navigation reaches Progress and Library, which show real numbers', (t) async {
    final db = await boot(t);
    await t.tap(find.text('Progress'));
    await settle(t);
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('in long-term memory'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    await t.drag(find.byType(ListView).last, const Offset(0, -900));
    await settle(t, rounds: 3);
    expect(find.text('Milestones'), findsOneWidget);
    expect(find.text('First steps'), findsOneWidget);
    expect(find.text('Earned'), findsWidgets);

    await t.tap(find.text('Library'));
    await settle(t);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Starter library'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('review: tap the card to reveal, rating buttons are labelled with their next interval', (t) async {
    final db = await boot(t);
    final handle = t.ensureSemantics();
    await t.tap(find.text('Keep going'));
    await settle(t);
    expect(find.textContaining('Music question'), findsOneWidget);
    expect(find.text('Show answer'), findsOneWidget);
    expect(find.textContaining('Think of your answer'), findsOneWidget);

    await t.tap(find.textContaining('Music question'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Good, next in ')), findsOneWidget);
    expect(find.byTooltip('Undo last answer'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    handle.dispose();
    await done(t, db);
  });

  testWidgets('finishing a session shows a summary with the streak', (t) async {
    final db = await boot(t);
    await t.tap(find.text('Keep going'));
    await settle(t);
    for (var i = 0; i < 30 && find.text('Back to home').evaluate().isEmpty; i++) {
      if (find.text('Show answer').evaluate().isNotEmpty) await t.tap(find.text('Show answer'));
      await t.pump(const Duration(milliseconds: 300));
      if (find.text('Easy').evaluate().isNotEmpty) await t.tap(find.text('Easy'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump(const Duration(milliseconds: 350));
    }
    await settle(t, rounds: 4);
    expect(find.text('Nicely done'), findsOneWidget);
    expect(find.text('remembered'), findsOneWidget);
    expect(find.textContaining('-day streak'), findsOneWidget);
    await done(t, db);
  });

  group('accessibility', () {
    testWidgets('Today: tap targets are large enough and labelled', (t) async {
      final handle = t.ensureSemantics();
      final db = await boot(t);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await done(t, db);
    });

    testWidgets('Review (answer shown): tap targets are large enough and labelled', (t) async {
      final handle = t.ensureSemantics();
      final db = await boot(t);
      await t.tap(find.text('Keep going'));
      await settle(t);
      await t.tap(find.text('Show answer'));
      await t.pump(const Duration(milliseconds: 500));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await done(t, db);
    });

    testWidgets('large system text does not break the Today screen', (t) async {
      final db = await boot(t);
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      await t.pump(const Duration(milliseconds: 300));
      expect(hasNoOverflow(t), isTrue);
      expect(find.text('Learn something new'), findsOneWidget);
      await done(t, db);
    });

    testWidgets('reduced motion: no confetti, ring is drawn instantly', (t) async {
      await t.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [ConfettiBurst(colors: [Colors.red])]),
        ),
      ));
      expect(find.descendant(of: find.byType(ConfettiBurst), matching: find.byType(CustomPaint)), findsNothing);
      await t.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ProgressRing(value: 0.5, color: Colors.red, track: Colors.grey, semanticLabel: 'x'),
        ),
      ));
      expect(find.byType(ProgressRing), findsOneWidget);
    });
  });

  group('small widgets', () {
    test('heatmap intensity levels and week alignment', () {
      expect([0, 1, 4, 5, 14, 15, 29, 30, 99].map(ActivityHeatmap.level), [0, 1, 1, 2, 2, 3, 3, 4, 4]);
      // 1970-01-01 (index 0) was a Thursday; index 4 is Monday, whose week starts at index 4.
      expect(ActivityHeatmap.weekStart(4, 1), 4);
      expect(ActivityHeatmap.weekStart(8, 5), 4); // Friday 8 -> Monday 4
    });
  });
}

/// A frame with a layout overflow reports an exception; none pending means it fit.
bool hasNoOverflow(WidgetTester t) => t.takeException() == null;
