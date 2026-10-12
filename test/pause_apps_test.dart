import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/pause_bridge.dart';
import 'package:daily_learning/data/pause_settings.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/pause_moves.dart';
import 'package:daily_learning/presentation/pause_apps_screen.dart';
import 'package:daily_learning/presentation/pause_summary.dart';
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

  String logText = '';
  int tests = 0;

  @override
  Future<void> setConfig({
    required List<String> apps,
    required List<String> wholeBrowsers,
    required String rules,
    required int freeMinutes,
    required bool risingWait,
    required int openLimit,
    required bool showNext,
    required String moves,
    required int rolloverHour,
  }) async =>
      config = {'apps': apps, 'whole': wholeBrowsers, 'rules': rules, 'free': freeMinutes, 'rising': risingWait, 'limit': openLimit, 'next': showNext, 'moves': moves, 'rollover': rolloverHour};
  @override
  Future<String> log() async => logText;
  @override
  Future<void> test() async => tests++;
  @override
  Future<List<InstalledApp>> apps() async => const [
        InstalledApp('com.linkedin.android', 'LinkedIn'),
        InstalledApp('com.whatsapp', 'WhatsApp'),
        InstalledApp('com.android.chrome', 'Chrome', browser: true),
      ];
  @override
  Future<PauseStatus> status() async => PauseStatus(on: on);
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
      expect(bridge.config, {
        'apps': ['com.linkedin.android'],
        'whole': <String>[],
        'rules': '*.linkedin.com\nreddit.com/r/all',
        'free': 2,
        'rising': true,
        'limit': 0,
        'next': true,
        'moves': storePauseMoves(kStarterMoves),
        'rollover': 4,
      });
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

    await t.ensureVisible(find.text('Add'));
    await t.pump();
    await t.enterText(find.byType(TextField).first, 'not a site');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.text('A site has no spaces'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'https://www.reddit.com/r/all/');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t, rounds: 3);
    expect(find.text('reddit.com/r/all'), findsOneWidget);
    expect(bridge.config?['rules'], '*.linkedin.com\nreddit.com/r/all');

    await t.scrollUntilVisible(find.text('Chrome'), -200, scrollable: find.byType(Scrollable).first);
    t.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Chrome')).onChanged!(true);
    await settle(t, rounds: 3);
    expect(bridge.config?['whole'], ['com.android.chrome']);
  });

  testWidgets('Move first: the suggestions are there, one can be removed, one added, bad input is refused, the list can be reset', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
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

    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Move first'), 300, scrollable: list);
    expect(find.text('10 push-ups'), findsOneWidget);
    expect(find.text('Use the suggestions'), findsNothing, reason: 'nothing to reset yet');

    await t.tap(find.byTooltip('Remove 10 push-ups'));
    await settle(t, rounds: 3);
    expect(find.text('10 push-ups'), findsNothing);
    expect((bridge.config!['moves'] as String).contains('10 push-ups'), isFalse);
    expect(find.text('Use the suggestions'), findsOneWidget);

    await t.scrollUntilVisible(find.text('Add an exercise'), 200, scrollable: list);
    await t.tap(find.text('Add an exercise'));
    await settle(t, rounds: 3);
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Jumping jacks');
    await t.enterText(find.byType(TextField).last, '5');
    await t.tap(find.text('Add'));
    await t.pump();
    expect(find.text('Between 10 and 300 seconds'), findsOneWidget, reason: 'too short is refused with a reason');
    await t.enterText(find.byType(TextField).last, '25');
    await t.tap(find.text('Add'));
    await settle(t, rounds: 3);
    expect((bridge.config!['moves'] as String).contains('Jumping jacks|25'), isTrue);

    await t.scrollUntilVisible(find.text('Use the suggestions'), 200, scrollable: list);
    await t.tap(find.text('Use the suggestions'));
    await settle(t, rounds: 3);
    expect(bridge.config!['moves'], storePauseMoves(kStarterMoves));
  });

  testWidgets('Today and Progress: the week\'s line, the bars, and a warning when the pause is off (D59)', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));
    final semantics = t.ensureSemantics();
    final bridge = FakePauseBridge(on: true);
    final now = DateTime.now().millisecondsSinceEpoch;
    bridge.logText = [
      '$now\tshown\tcom.linkedin.android',
      '$now\tback\tcom.linkedin.android',
      '$now\tshown\tcom.linkedin.android',
      '$now\tcards\tcom.linkedin.android',
      '$now\tshown\ttest:pause',
      'garbage line',
    ].join('\n');
    final s = PauseSettings(db, SettingsRepo(db), bridge);
    await t.runAsync(() => s.save(const PauseChoices(apps: ['com.linkedin.android'], saved: true)));
    Widget app(Widget child) => ProviderScope(
          overrides: [
            bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
            pauseBridgeProvider.overrideWithValue(bridge),
          ],
          child: MaterialApp(home: Scaffold(body: ListView(children: [child]))),
        );
    await t.pumpWidget(app(const PauseTodayNote()));
    await settle(t, rounds: 4);
    expect(find.text('This week the pause came up 2 times; you turned away 2, 1 of them for cards.'), findsOneWidget,
        reason: 'the test pause and the damaged line are not counted');

    await t.pumpWidget(app(Consumer(builder: (_, ref, _) {
      final v = ref.watch(pauseSummaryProvider).value;
      return v == null ? const SizedBox() : PauseWeekCard(v);
    })));
    await settle(t, rounds: 4);
    expect(find.text('Today: 2 attempts to open, 2 turned away.'), findsOneWidget);
    expect(find.bySemanticsLabel('Today: 2 attempts, 2 turned away'), findsOneWidget);

    bridge.on = false;
    await t.pumpWidget(Container());
    await t.pumpWidget(app(const PauseTodayNote()));
    await settle(t, rounds: 4);
    expect(find.text('The pause before apps is off'), findsOneWidget);
    semantics.dispose();
  });
}
