import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/pause_bridge.dart';
import 'package:daily_learning/data/pause_settings.dart';
import 'package:daily_learning/presentation/pause_apps_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'ui_test.dart' show settle;

/// A phone side that records what the app hands it.
class FakePauseBridge implements PauseBridge {
  FakePauseBridge({this.on = false});
  bool on;
  Map<String, Object>? config;
  int granted = 0;
  PauseVisit? pending;

  @override
  Future<void> setConfig({required List<String> apps, required List<String> wholeBrowsers, required String rules, required int freeMinutes}) async =>
      config = {'apps': apps, 'whole': wholeBrowsers, 'rules': rules, 'free': freeMinutes};
  @override
  Future<List<InstalledApp>> apps() async => const [
        InstalledApp('com.linkedin.android', 'LinkedIn'),
        InstalledApp('com.whatsapp', 'WhatsApp'),
        InstalledApp('com.android.chrome', 'Chrome', browser: true),
      ];
  @override
  Future<PauseStatus> status() async => PauseStatus(on: on, back: 3, open: 1, cards: 2);
  @override
  Future<void> openAccessibilitySettings() async {}
  @override
  Future<void> openAppInfo() async {}
  @override
  Future<PauseVisit?> visit() async => pending;
  @override
  Future<bool> grantAll() async {
    granted++;
    return true;
  }

  @override
  Future<void> dropVisit() async => pending = null;
}

void main() {
  group('choices (D58)', () {
    test('saved in settings, handed to the phone side; a restored backup with junk is cleaned', () async {
      final e = Env();
      final bridge = FakePauseBridge();
      final s = PauseSettings(e.db, e.settings, bridge);
      expect((await s.load()).saved, isFalse);
      await s.push();
      expect(bridge.config, isNull, reason: 'nothing is handed over before the learner saved once');

      await e.settings.set(PauseSettings.appsKey, 'com.linkedin.android,not a package,com.linkedin.android,;rm -rf');
      await e.settings.set(PauseSettings.sitesKey, '*.linkedin.com\njavascript:alert(1)\nreddit.com/r/all');
      await e.settings.set(PauseSettings.freeKey, '999');
      final c = await s.load();
      expect(c.apps, ['com.linkedin.android']);
      expect(c.sites.map((r) => r.canonical), ['*.linkedin.com', 'reddit.com/r/all']);
      expect(c.freeMinutes, 2, reason: 'not one of the choices: back to the default');
      await s.push();
      expect(bridge.config, {'apps': ['com.linkedin.android'], 'whole': <String>[], 'rules': '*.linkedin.com\nreddit.com/r/all', 'free': 2});
      await e.db.close();
    });

    test('free time is judged on answers since the pause, and an undone answer does not count', () async {
      final e = Env();
      await e.addBasic(6);
      final s = PauseSettings(e.db, e.settings, FakePauseBridge());
      final t0 = DateTime.utc(2025, 3, 3, 10);
      final cards = await e.db.select(e.db.cards).get();
      await e.review.review(cardId: cards[0].id, rating: 3, durationMs: 1000, now: t0.subtract(const Duration(minutes: 5)));
      final since = t0.millisecondsSinceEpoch;
      for (final c in cards.skip(1).take(3)) {
        await e.review.review(cardId: c.id, rating: 3, durationMs: 1000, now: t0.add(const Duration(minutes: 1)));
      }
      expect(await s.answersSince(since), 3, reason: 'the answer before the pause does not count');
      await e.review.undoLast(now: t0.add(const Duration(minutes: 2)));
      expect(await s.answersSince(since), 2);
      await e.db.close();
    });
  });

  testWidgets('the screen: first visit suggests LinkedIn and saves it; a bad site is refused; a browser can be paused whole', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));
    final bridge = FakePauseBridge();
    await t.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
        pauseBridgeProvider.overrideWithValue(bridge),
      ],
      child: const MaterialApp(home: PauseAppsScreen()),
    ));
    await settle(t, rounds: 4);

    expect(find.text('The pause is off'), findsOneWidget);
    expect(find.text('Open accessibility settings'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(bridge.config?['apps'], ['com.linkedin.android'], reason: 'the suggestion is saved and handed over at once');
    expect(bridge.config?['rules'], '*.linkedin.com');
    await t.scrollUntilVisible(find.text('Add'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('*.linkedin.com'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'not a site');
    await t.tap(find.text('Add'));
    await t.pump();
    expect(find.text('A site has no spaces'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'https://www.reddit.com/r/all/');
    await t.tap(find.text('Add'));
    await settle(t, rounds: 3);
    expect(find.text('reddit.com/r/all'), findsOneWidget);
    expect(bridge.config?['rules'], '*.linkedin.com\nreddit.com/r/all');

    await t.scrollUntilVisible(find.text('Chrome'), -200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byType(Switch).first);
    await settle(t, rounds: 3);
    expect(bridge.config?['whole'], ['com.android.chrome']);
  });
}
