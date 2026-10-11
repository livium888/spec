import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/launch_service.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/main.dart' show DailyLearningApp;
import 'package:daily_learning/presentation/review_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'screenshots/screens_test.dart' show settle;

/// D51: the ways into the review from outside the app (shortcuts, widget, tile, reminder) and the "Quick 5" session.
class _Inbox implements LaunchInbox {
  _Inbox(this.route);
  LaunchRoute? route;
  @override
  Future<LaunchRoute?> take() async {
    final r = route;
    route = null;
    return r;
  }
}

class _Bridge implements DueBridge {
  final calls = <({int due, int minutes, int dayEndMs})>[];
  @override
  Future<void> publish({required int due, required int minutes, required int dayEndMs, String? next}) async => calls.add((due: due, minutes: minutes, dayEndMs: dayEndMs));
}

class _NoNotification implements NotificationLaunch {
  const _NoNotification({this.opened = false});
  final bool opened;
  @override
  Future<bool> openedFromReminder() async => opened;
}

Future<AppDatabase> seeded(WidgetTester t, {int cards = 8}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await t.runAsync(() async {
    final imp = ImportService(db);
    await imp.commit(await imp.preview(jsonEncode({
      'domain': 'Bio',
      'cards': [
        for (var i = 0; i < cards; i++)
          {'type': 'basic', 'front': 'Question number $i here?', 'back': 'Answer $i', 'source_type': 'quote', 'source_ref': 'b', 'supporting_quote': 'q', 'confidence': 'high'}
      ]
    })));
    await SettingsRepo(db).set('guide_seen', '1');
  });
  addTearDown(() async => t.runAsync(db.close));
  return db;
}

Future<void> boot(WidgetTester t, AppDatabase db, List<Override> extra) async {
  t.view.physicalSize = const Size(411, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)), ...extra],
    child: const DailyLearningApp(),
  ));
  await settle(t, rounds: 12);
}

Future<void> answerOne(WidgetTester t) async {
  await t.tap(find.text('Show answer'));
  await settle(t, rounds: 3);
  await t.tap(find.text('Good').first);
  await settle(t, rounds: 6);
}

void main() {
  test('only the two known routes are understood; anything else an outside app sends is ignored', () {
    expect(launchRouteOf('review'), LaunchRoute.review);
    expect(launchRouteOf('quick5'), LaunchRoute.quick);
    for (final bad in [null, '', 'REVIEW', 'import', 'review;rm', '../x']) {
      expect(launchRouteOf(bad), isNull, reason: '$bad');
    }
  });

  testWidgets('a shortcut or widget asking for the review opens it straight away, from a cold start', (t) async {
    final db = await seeded(t);
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Inbox(LaunchRoute.review)), notificationLaunchProvider.overrideWithValue(const _NoNotification())]);
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(find.text('Show answer'), findsOneWidget);
    expect(find.textContaining('8 left'), findsOneWidget, reason: 'the whole day, not a short session');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('tapping the reminder opens the review: from a cold start, and while the app is running', (t) async {
    final db = await seeded(t);
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Inbox(null)), notificationLaunchProvider.overrideWithValue(const _NoNotification(opened: true))]);
    expect(find.byType(ReviewScreen), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await settle(t, rounds: 6);
    expect(find.byType(ReviewScreen), findsNothing);
    LaunchRelay.pending.value = LaunchRoute.review; // the tap on a notification while the app runs
    await settle(t, rounds: 8);
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(LaunchRelay.pending.value, isNull, reason: 'consumed');
    // A second request while a review is already open does not stack another one on top.
    LaunchRelay.pending.value = LaunchRoute.quick;
    await settle(t, rounds: 6);
    await t.tap(find.byTooltip('Close'));
    await settle(t, rounds: 6);
    expect(find.byType(ReviewScreen), findsNothing, reason: 'one review was open, so one close ends it');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Quick 5: five cards, then "That was your 5" with the rest waiting; Keep going lifts the limit', (t) async {
    final db = await seeded(t);
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Inbox(LaunchRoute.quick)), notificationLaunchProvider.overrideWithValue(const _NoNotification())]);
    expect(find.textContaining('5 left'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await answerOne(t);
    }
    expect(find.text('That was your 5'), findsOneWidget);
    expect(find.text('Keep going · 3 waiting'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
    await t.tap(find.text('Keep going · 3 waiting'));
    await settle(t, rounds: 8);
    expect(find.text('Show answer'), findsOneWidget);
    expect(find.textContaining('3 left'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Quick 5 with only three cards behaves as an ordinary session, with no "keep going"', (t) async {
    final db = await seeded(t, cards: 3);
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Inbox(LaunchRoute.quick)), notificationLaunchProvider.overrideWithValue(const _NoNotification())]);
    for (var i = 0; i < 3; i++) {
      await answerOne(t);
    }
    // The three new cards are in their first learning steps: the session ends as an ordinary one would.
    expect(find.textContaining('Next card in about'), findsOneWidget);
    expect(find.textContaining('That was your'), findsNothing);
    expect(find.textContaining('Keep going'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Today offers "Just 5 cards" only when more than five wait, and publishes the count for the widget and tile', (t) async {
    final db = await seeded(t);
    final bridge = _Bridge();
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Inbox(null)), notificationLaunchProvider.overrideWithValue(const _NoNotification()), dueBridgeProvider.overrideWithValue(bridge)]);
    expect(find.text('Just 5 cards'), findsOneWidget);
    expect(bridge.calls, isNotEmpty);
    expect(bridge.calls.last.due, 8);
    expect(bridge.calls.last.minutes, 2, reason: '8 cards at the default 10 s each');
    expect(bridge.calls.last.dayEndMs, greaterThan(DateTime.now().millisecondsSinceEpoch), reason: 'the number is for today only');
    await t.tap(find.text('Just 5 cards'));
    await settle(t, rounds: 8);
    expect(find.textContaining('5 left'), findsOneWidget);
    await t.pumpWidget(const SizedBox());

    final few = await seeded(t, cards: 4);
    await boot(t, few, [launchInboxProvider.overrideWithValue(_Inbox(null)), notificationLaunchProvider.overrideWithValue(const _NoNotification())]);
    expect(find.text('Just 5 cards'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
