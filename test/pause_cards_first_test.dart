import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/pause_settings.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/pause_stats.dart';
import 'package:daily_learning/domain/site_rule.dart';
import 'package:daily_learning/presentation/pause_apps_screen.dart';
import 'package:daily_learning/presentation/pause_summary.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;
import 'pause_apps_test.dart' show FakePauseBridge;
import 'ui_test.dart' show settle;

PauseEvent ev(int at, PauseKind k, [String key = 'a']) => PauseEvent(at, k, key);

void main() {
  group('Cards come first (D62)', () {
    test('openings since the last real cards session, over every app, from the start of the day', () {
      const start = 1000;
      expect(pauseOpeningsSinceCards(const [], start), 0);
      expect(pauseOpeningsSinceCards([ev(1001, PauseKind.open), ev(1002, PauseKind.move, 'b')], start), 2, reason: 'breathing and an exercise both count, in any app');
      expect(pauseOpeningsSinceCards([ev(1001, PauseKind.open), ev(1002, PauseKind.earned), ev(1003, PauseKind.move)], start), 1, reason: 'the cards session starts the count again');
      expect(pauseOpeningsSinceCards([ev(1001, PauseKind.shown), ev(1002, PauseKind.back), ev(1003, PauseKind.cards), ev(1004, PauseKind.again)], start), 0,
          reason: 'tapping "Do 5 cards" is a choice, not a cards session; the other lines are not openings');
      expect(pauseOpeningsSinceCards([ev(900, PauseKind.open), ev(999, PauseKind.move), ev(1000, PauseKind.open)], start), 1, reason: 'yesterday does not count');
      expect(pauseOpeningsSinceCards([ev(1001, PauseKind.open, 'test:pause'), ev(1002, PauseKind.open)], start), 1, reason: 'the test pause is not counted');
      expect(pauseOpeningsSinceCards([ev(1001, PauseKind.open), ev(1002, PauseKind.earned, 'test:pause'), ev(1003, PauseKind.open)], start), 2,
          reason: 'and a test cannot clear the count');
    });

    test('whose turn it is: only when cards can be offered', () {
      expect(pauseCardsTurn(openings: 2, every: 2, due: 10), isTrue);
      expect(pauseCardsTurn(openings: 1, every: 2, due: 10), isFalse);
      expect(pauseCardsTurn(openings: 5, every: 0, due: 10), isFalse, reason: 'off');
      expect(pauseCardsTurn(openings: 5, every: 2, due: 0), isFalse, reason: 'nothing due: no lock-out');
      expect(pauseCardsTurn(openings: 5, every: 2, due: null), isFalse, reason: 'the app has not said: no lock-out');
      expect(pauseCardsTurn(openings: 1, every: 1, due: 1), isTrue);
    });

    test('the log lines are read back strictly; a damaged line never counts', () {
      expect(PauseEvent.parse('1001\topen\ta'), isNotNull);
      expect(PauseEvent.parse('+1001\topen\ta'), isNull);
      expect(PauseEvent.parse(' 1001\topen\ta'), isNull);
      expect(PauseEvent.parse('1001\tearned\ta')?.kind, PauseKind.earned);
      expect(PauseEvent.parse('1001\tbogus\ta'), isNull);
      expect(PauseEvent.parse('1001\topen\ta\textra'), isNull);
    });

    test('the choice is saved with the others, handed to the phone side, and junk is cleaned', () async {
      final e = Env();
      final bridge = FakePauseBridge();
      final s = PauseSettings(e.db, e.settings, bridge);
      expect((await s.load()).cardsEvery, 2, reason: 'on by default');
      await s.save((await s.load()).copyWith(cardsEvery: 3));
      expect((await s.load()).cardsEvery, 3);
      expect(bridge.config!['cardsEvery'], 3);
      await e.settings.set(PauseSettings.cardsEveryKey, '7');
      expect((await s.load()).cardsEvery, 2, reason: 'not one of the choices: back to the default');
      await e.settings.set(PauseSettings.cardsEveryKey, '0');
      expect((await s.load()).cardsEvery, 0);
      await e.db.close();
    });
  });

  Future<FakePauseBridge> open(WidgetTester t, {PauseChoices? start}) async {
    t.view.physicalSize = const Size(411, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));
    final bridge = FakePauseBridge();
    if (start != null) await t.runAsync(() => PauseSettings(db, SettingsRepo(db), bridge).save(start));
    await t.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
        pauseBridgeProvider.overrideWithValue(bridge),
      ],
      child: const MaterialApp(home: PauseAppsScreen()),
    ));
    await settle(t, rounds: 4);
    return bridge;
  }

  /// Scroll until the finder's widget is built, then until it is really on the screen.
Future<void> reveal(WidgetTester t, Finder f, {double by = 300}) async {
  await t.scrollUntilVisible(f, by, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pump();
}

String moves(FakePauseBridge b) => b.config!['moves'] as String;

  testWidgets('the screen has three groups, and the test button sits with the status', (t) async {
    final b = await open(t);
    expect(find.text('Focus before apps'), findsOneWidget, reason: 'the app bar');
    for (final h in ['What to pause', 'Ways out', 'Harder to open']) {
      await reveal(t, find.text(h));
      expect(find.text(h), findsOneWidget);
    }
    await reveal(t, find.text('Test the pause'), by: -600);
    await t.tap(find.text('Test the pause'));
    expect(b.tests, 1);
  });

  testWidgets('Cards come first: the choice is on the screen and reaches the phone side', (t) async {
    final b = await open(t);
    await reveal(t, find.text('Cards come first, after this many openings'));
    expect(find.text('2 openings'), findsOneWidget, reason: 'the default');
    await t.tap(find.text('2 openings'));
    await settle(t, rounds: 2);
    await t.tap(find.text('Off').last);
    await settle(t, rounds: 3);
    expect(b.config!['cardsEvery'], 0);
  });

  testWidgets('an exercise can be changed in place: name and time, same position; its own name is not a repeat', (t) async {
    final b = await open(t);
    await reveal(t, find.text('15 squats'));
    await t.tap(find.text('15 squats'));
    await settle(t, rounds: 3);
    expect(find.text('Edit exercise'), findsOneWidget);
    expect(find.widgetWithText(TextField, '15 squats'), findsOneWidget, reason: 'prefilled');
    expect(find.widgetWithText(TextField, '40'), findsOneWidget);
    final dialog = find.byType(AlertDialog);

    await t.enterText(find.widgetWithText(TextField, 'Name'), '15 Squats');
    await t.enterText(find.byType(TextField).last, '30');
    await t.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await settle(t, rounds: 3);
    expect(moves(b).split('\n')[1], '15 Squats|30', reason: 'renamed with a capital and a new time, still second');

    await t.tap(find.text('15 Squats'));
    await settle(t, rounds: 3);
    await t.enterText(find.widgetWithText(TextField, 'Name'), '10 push-ups');
    await t.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await t.pump();
    expect(find.text('That one is in the list already'), findsOneWidget, reason: 'another exercise has that name');
    await t.enterText(find.widgetWithText(TextField, 'Name'), '15 Squats');
    await t.enterText(find.byType(TextField).last, '5');
    await t.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await t.pump();
    expect(find.text('Between 10 and 300 seconds'), findsOneWidget);
    await t.tap(find.descendant(of: dialog, matching: find.text('Cancel')));
    await settle(t, rounds: 3);
    expect(moves(b).split('\n')[1], '15 Squats|30', reason: 'cancel changes nothing');
  });

  testWidgets('the order can be set with the arrows; the ends cannot go further', (t) async {
    final b = await open(t);
    await reveal(t, find.text('15 squats'));
    expect(t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward).first).onPressed, isNull, reason: 'the first cannot go up');
    await t.tap(find.byTooltip('Move 15 squats up'));
    await settle(t, rounds: 3);
    expect(moves(b).split('\n').take(2).toList(), ['15 squats|40', '10 push-ups|40']);
    await t.tap(find.byTooltip('Move 10 push-ups down'));
    await settle(t, rounds: 3);
    expect(moves(b).split('\n').take(3).toList(), ['15 squats|40', '1-minute plank|60', '10 push-ups|40']);
  });

  testWidgets('removing asks nothing but can be undone, to the same place', (t) async {
    final b = await open(t);
    await reveal(t, find.text('15 squats'));
    await t.tap(find.byTooltip('Remove 15 squats'));
    await settle(t, rounds: 3);
    expect(moves(b).contains('15 squats'), isFalse);
    expect(find.text('Removed 15 squats'), findsOneWidget);
    await t.pump(const Duration(seconds: 30));
    expect(find.text('Removed 15 squats'), findsOneWidget, reason: 'no timer: it waits until it is closed');
    await t.tap(find.text('Undo'));
    await settle(t, rounds: 3);
    expect(moves(b).split('\n')[1], '15 squats|40', reason: 'back in second place');
  });

  testWidgets('the Undo bar goes with the screen: leaving it does not leave the bar over the next screen', (t) async {
    t.view.physicalSize = const Size(411, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));
    await t.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
        pauseBridgeProvider.overrideWithValue(FakePauseBridge()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PauseAppsScreen())),
              child: const Text('open it'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open it'));
    await settle(t, rounds: 4);
    await reveal(t, find.text('15 squats'));
    await t.tap(find.byTooltip('Remove 15 squats'));
    await settle(t, rounds: 3);
    expect(find.text('Removed 15 squats'), findsOneWidget);
    await t.pageBack();
    await settle(t, rounds: 4);
    expect(find.text('open it'), findsOneWidget);
    expect(find.text('Removed 15 squats'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('Settings: Focus before apps is a section with its state at a glance, and opens the screen', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));
    final bridge = FakePauseBridge(on: true);
    await t.runAsync(() => PauseSettings(db, SettingsRepo(db), bridge).save(PauseChoices(apps: const ['com.linkedin.android'], sites: [parseSiteRule('*.linkedin.com')!])));
    await t.pumpWidget(ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
        pauseBridgeProvider.overrideWithValue(bridge),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FocusSettingsSection()))),
    ));
    await settle(t, rounds: 4);
    expect(find.text('Focus before apps'), findsOneWidget);
    expect(find.text('On. 1 app, 1 site, 6 exercises'), findsOneWidget);
    await t.tap(find.text('On. 1 app, 1 site, 6 exercises'));
    await settle(t, rounds: 4);
    expect(find.text('What to pause'), findsOneWidget, reason: 'the screen opened');

    bridge.on = false;
    await t.pageBack();
    await settle(t, rounds: 4);
    expect(find.text('Off. 1 app, 1 site, 6 exercises'), findsOneWidget);
    expect(find.text('The pause is off in Android\'s settings. Tap to switch it on.'), findsOneWidget);
  });

  testWidgets('Progress says which way the day\'s openings came, and that the card opens the settings', (t) async {
    final today = PauseDay(100)
      ..shown = 4
      ..back = 1
      ..earned = 1
      ..open = 2
      ..move = 1;
    Widget card({bool tappable = false}) => MaterialApp(
        home: Scaffold(body: ListView(children: [PauseWeekCard(PauseSummary(days: [today], on: true, watching: true), tappable: tappable)])));
    await t.pumpWidget(card());
    expect(find.textContaining('Ways in today: 1 by cards, 1 by exercise, 2 by breathing.'), findsOneWidget);
    expect(find.text('Tap to change these settings.'), findsNothing);
    await t.pumpWidget(card(tappable: true));
    expect(find.text('Tap to change these settings.'), findsOneWidget);
    expect(find.text('Focus before apps'), findsOneWidget);
  });

  test('the summary line: not set up, nothing chosen, singular and plural', () {
    expect(const FocusOverview(saved: false, on: false, apps: 0, browsers: 0, sites: 0, moves: 6).line, 'Not set up yet');
    expect(const FocusOverview(saved: true, on: true, apps: 0, browsers: 0, sites: 0, moves: 0).line, 'On. Nothing chosen yet');
    expect(const FocusOverview(saved: true, on: true, apps: 2, browsers: 1, sites: 3, moves: 1).line, 'On. 2 apps, 1 browser, 3 sites, 1 exercise');
  });
}
