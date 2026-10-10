import 'package:daily_learning/app/launch_service.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'launch_test.dart' show boot, seeded;
import 'screenshots/screens_test.dart' show settle;

/// D52: the review's top bar keeps Undo; the other card actions live in one menu, "Pause" apart from "Edit".
class _Review implements LaunchInbox {
  bool done = false;
  @override
  Future<LaunchRoute?> take() async {
    if (done) return null;
    done = true;
    return LaunchRoute.review;
  }
}

class _NoNote implements NotificationLaunch {
  const _NoNote();
  @override
  Future<bool> openedFromReminder() async => false;
}

void main() {
  testWidgets('top bar: close, progress, Undo and ONE menu; the menu holds mark, edit, about and (apart) pause', (t) async {
    final db = await seeded(t, cards: 3);
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Review()), notificationLaunchProvider.overrideWithValue(const _NoNote())]);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Undo last answer'), findsOneWidget);
    expect(find.byTooltip('More actions for this card'), findsOneWidget);
    for (final gone in ['Edit or delete this card', 'Suspend this card', 'Mark this card to look at later']) {
      expect(find.byTooltip(gone), findsNothing, reason: '$gone moved into the menu');
    }
    await t.tap(find.byTooltip('More actions for this card'));
    await settle(t, rounds: 2);
    for (final item in ['Mark to look at later', 'Edit or delete', 'About this card', 'Pause this card']) {
      expect(find.text(item), findsOneWidget);
    }
    // The destructive-ish item is below the others, set off by a divider.
    expect(t.getTopLeft(find.text('Pause this card')).dy, greaterThan(t.getTopLeft(find.text('About this card')).dy + 40));
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('pausing a card says where to bring it back, and Undo in the message puts it straight back', (t) async {
    final db = await seeded(t, cards: 3);
    await boot(t, db, [launchInboxProvider.overrideWithValue(_Review()), notificationLaunchProvider.overrideWithValue(const _NoNote())]);
    expect(find.textContaining('3 left'), findsOneWidget);
    await t.tap(find.byTooltip('More actions for this card'));
    await settle(t, rounds: 2);
    await t.tap(find.text('Pause this card'));
    await settle(t, rounds: 6);
    expect(find.textContaining('Paused only'), findsOneWidget);
    expect(find.textContaining('2 left'), findsOneWidget);
    var paused = await t.runAsync(() => (db.select(db.cards)..where((c) => c.suspended.equals(true))).get());
    expect(paused!.length, 1);
    await t.tap(find.text('Undo').last);
    await settle(t, rounds: 6);
    paused = await t.runAsync(() => (db.select(db.cards)..where((c) => c.suspended.equals(true))).get());
    expect(paused, isEmpty);
    expect(find.textContaining('3 left'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Browse can show only paused cards and bring one back', (t) async {
    final db = await seeded(t, cards: 3);
    await t.runAsync(() => db.customStatement('UPDATE card SET suspended = 1 WHERE id = (SELECT MIN(id) FROM card)'));
    final svc = CardEditService(db, SettingsRepo(db));
    final rows = await t.runAsync(() => svc.search(pausedOnly: true));
    expect(rows!.length, 1);
    expect(rows.single.paused, isTrue);
    expect((await t.runAsync(() => svc.search()))!.where((r) => r.paused).length, 1);
    await t.runAsync(() => svc.bringBack(rows.single.noteId));
    expect(await t.runAsync(() => svc.search(pausedOnly: true)), isEmpty);
    // A retired card is not "paused": it stays retired and is not brought back by this.
    await t.runAsync(() => db.customStatement('UPDATE card SET suspended = 1, retired_at = 5 WHERE id = (SELECT MIN(id) FROM card)'));
    expect(await t.runAsync(() => svc.search(pausedOnly: true)), isEmpty);
    await t.runAsync(() => svc.bringBack(rows.single.noteId));
    expect((await t.runAsync(() => (db.select(db.cards)..where((c) => c.retiredAt.isNotNull())).get()))!.length, 1);
  });
}
