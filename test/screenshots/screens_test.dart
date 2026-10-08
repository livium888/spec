// Renders the real screens to PNG files for visual review. Skipped unless SCREENSHOT_DIR is set:
//   SCREENSHOT_DIR=/some/dir flutter test test/screenshots/screens_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dir_asset_bundle.dart';

final _dir = Platform.environment['SCREENSHOT_DIR'];

Future<void> settle(WidgetTester t, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pump(const Duration(seconds: 1));
}

Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
  await t.pump(const Duration(milliseconds: 800)); // let animations finish
  await t.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image img = await boundary.toImage(pixelRatio: 2);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    File('$_dir/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

Future<AppDatabase> seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final settings = SettingsRepo(db);
  final out = OutlineService(db);
  final imp = ImportService(db);
  final review = ReviewService(db, settings, ParamsRepo(db, settings));
  final now = DateTime.now().toUtc();
  const subjects = {
    'Thinking and Decisions': ['Cognitive biases', 'Inversion and pre-mortems', 'Second-order effects'],
    'Money and Investing': ['Compound interest', 'Index funds and fees', 'Risk and return'],
    'Music': ['Rhythm and metre', 'Major scales and keys'],
    'Arts and Design': ['Colour theory', 'Composition'],
    'Languages: How Language Works': ['Sounds and phonetics'],
    'Crafts and Making': ['Knots and rope'],
  };
  for (final e in subjects.entries) {
    await out.commit(
        await out.preview(jsonEncode({
          'domain': e.key,
          'items': [for (final t in e.value) {'title': t, 'target_cards': 8}],
        })),
        now: now.subtract(const Duration(days: 75)));
  }
  final rnd = Random(5);
  var n = 0;
  for (final e in subjects.entries) {
    for (final topic in e.value) {
      final cards = [
        for (var i = 0; i < 6; i++)
          {
            'type': 'basic',
            'front': i == 0 && n == 0
                ? 'Why do people keep paying for a gym they never use, even though cancelling would save money?'
                : 'Question ${n++} about $topic number $i?',
            'back': i == 0 && n == 1 ? 'Sunk-cost thinking: the past spend feels like a reason to continue.' : 'An answer worth remembering',
            'source_type': 'model_memory',
            'confidence': 'high',
            if (i == 0 && n == 1) ...{
              'why_it_matters': 'The money is gone either way. Only future costs and benefits should decide.',
              'example': 'Finishing a bad film because you already paid for the ticket.',
              'memory_hook': 'The past bill is a ghost: it cannot vote.',
            },
          }
      ];
      await imp.commit(await imp.preview(jsonEncode({'domain': e.key, 'syllabus_item': topic, 'cards': cards})),
          now: now.subtract(Duration(days: 60 - rnd.nextInt(30))));
    }
  }
  // 70 days of history: study on most days, a couple of gaps.
  final ids = [for (final c in await db.select(db.cards).get()) c.id];
  for (var d = 70; d >= 1; d--) {
    if (d % 9 == 0 || d % 13 == 0) continue;
    final k = 2 + rnd.nextInt(10);
    for (var j = 0; j < k; j++) {
      final id = ids[rnd.nextInt(ids.length)];
      await review.review(
          cardId: id,
          rating: rnd.nextInt(10) < 8 ? 3 : (rnd.nextBool() ? 1 : 4),
          durationMs: 5000 + rnd.nextInt(9000),
          now: now.subtract(Duration(days: d, minutes: -j * 2)));
    }
  }
  // A few answered today, so today's ring is part-filled.
  for (var j = 0; j < 4; j++) {
    await review.review(cardId: ids[j], rating: 3, durationMs: 7000, now: now.subtract(Duration(minutes: 20 - j)));
  }
  await settings.set(SettingsRepo.learnerProfile, 'Nurse, cycles to work, loves cooking');
  return db;
}

Future<void> boot(WidgetTester t, AppDatabase db, GlobalKey key, {bool dark = false}) async {
  t.view.physicalSize = const Size(411, 900);
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(RepaintBoundary(
    key: key,
    child: ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
        assetBundleProvider.overrideWithValue(DirAssetBundle('docs/starter-outlines')),
      ],
      child: const DailyLearningApp(),
    ),
  ));
  await settle(t, rounds: 14);
}

void main() {
  final bool? skip = _dir == null ? true : null; // null = run

  testWidgets('light: today, progress, library, review', (t) async {
    Directory(_dir!).createSync(recursive: true);
    final db = await t.runAsync(seed);
    final key = GlobalKey();
    await boot(t, db!, key);
    await shot(t, key, '01_today_light');

    await t.tap(find.text('Progress'));
    await settle(t);
    await shot(t, key, '02_progress_light');
    await t.drag(find.byType(ListView).last, const Offset(0, -700));
    await settle(t, rounds: 4);
    await shot(t, key, '02b_progress_light_scrolled');

    await t.tap(find.text('Library'));
    await settle(t);
    await shot(t, key, '03_library_light');

    await t.tap(find.text('Today'));
    await settle(t);
    await t.tap(find.text('Keep going'));
    await settle(t);
    await shot(t, key, '04_review_front_light');
    await t.tap(find.text('Show answer'));
    await settle(t, rounds: 4);
    await shot(t, key, '05_review_back_light');

    // Answer everything to reach the end-of-session screen.
    for (var i = 0; i < 80 && find.text('Back to home').evaluate().isEmpty; i++) {
      if (find.text('Show answer').evaluate().isNotEmpty) await t.tap(find.text('Show answer'));
      await t.pump(const Duration(milliseconds: 300));
      if (find.text('Good').evaluate().isNotEmpty) await t.tap(find.text('Good').first);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump(const Duration(milliseconds: 350));
    }
    await settle(t, rounds: 6);
    await t.pump(const Duration(milliseconds: 500));
    await shot(t, key, '08_summary_light');

    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  }, skip: skip);

  testWidgets('light: other screens', (t) async {
    Directory(_dir!).createSync(recursive: true);
    final db = await t.runAsync(seed);
    final key = GlobalKey();
    await boot(t, db!, key);

    await shot(t, key, '12_today_first_run');
    await t.tap(find.text('Show me'));
    await settle(t);
    await shot(t, key, '13_guide_top');
    await t.drag(find.byType(ListView).first, const Offset(0, -700));
    await settle(t);
    await shot(t, key, '14_guide_middle');
    await t.pageBack();
    await settle(t);

    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await shot(t, key, '09_settings');
    await t.tap(find.byTooltip('Back'));
    await settle(t);

    await t.tap(find.text('Learn something new'));
    for (var i = 0; i < 40 && find.text('Your prompt').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await settle(t);
    await shot(t, key, '10_prompt_result');
    await t.tap(find.byTooltip('Back'));
    await settle(t);

    await t.tap(find.text('Library'));
    await settle(t);
    await t.tap(find.text('Starter library'));
    for (var i = 0; i < 40 && find.text('Thinking and Decisions').evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await settle(t);
    await shot(t, key, '11_starter_library');
    await t.tap(find.byTooltip('Back'));
    await settle(t);

    await t.tap(find.text('Music').first);
    await settle(t);
    await shot(t, key, '12_topics');

    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  }, skip: skip);

  testWidgets('dark: today and progress', (t) async {
    Directory(_dir!).createSync(recursive: true);
    final db = await t.runAsync(seed);
    final key = GlobalKey();
    await boot(t, db!, key, dark: true);
    await shot(t, key, '06_today_dark');
    await t.tap(find.text('Progress'));
    await settle(t);
    await shot(t, key, '07_progress_dark');
    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  }, skip: skip);
}
