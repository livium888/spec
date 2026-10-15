import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/app/share_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/pause_bridge.dart';
import 'package:daily_learning/data/pause_settings.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/socratic_service.dart';
import 'package:daily_learning/data/talk_service.dart';
import 'package:daily_learning/presentation/pause_apps_screen.dart';
import 'package:daily_learning/presentation/socratic_pause_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'learn_widget_test.dart' show boot, done;
import 'pause_apps_test.dart' show FakePauseBridge;
import 'ui_test.dart' show settle;

class _Sharer implements PromptSharer {
  final sent = <String>[];
  @override
  Future<void> send(String text, {String? title}) async => sent.add(text);
}

/// Six basic cards, "Question 0..5"; returns the note ids in that order.
Future<List<int>> library(AppDatabase db, {int n = 6}) async {
  await ParamsRepo(db, SettingsRepo(db)).activeId();
  final imp = ImportService(db);
  await imp.commit(
      await imp.preview(jsonEncode({
        'domain': 'Biology',
        'cards': [
          for (var i = 0; i < n; i++)
            {'type': 'basic', 'front': 'Question $i about the cell?', 'back': 'Answer $i is hidden.', 'source_type': 'model_memory', 'confidence': 'high'},
        ]
      })),
      now: DateTime.utc(2025, 3, 3));
  return [for (final r in await db.select(db.notes).get()) r.id]..sort();
}

/// Make [noteId]'s card a reviewed one with this much struggle.
Future<void> reviewed(AppDatabase db, int noteId, {int lapses = 0, double difficulty = 5, double stability = 5}) =>
    db.customStatement("UPDATE card SET state = 'review', lapses = $lapses, difficulty = $difficulty, stability = $stability WHERE note_id = $noteId");

/// Let async work finish without letting the screen's one-second clock tick (a tick needs a full second of test time).
Future<void> flush(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder textMatching(RegExp r) => find.byWidgetPredicate((w) => w is Text && r.hasMatch(w.data ?? ''));

PauseVisit talkVisit({bool started = false, int? noteId, int left = 180}) => PauseVisit(
    label: 'LinkedIn', atMs: DateTime.now().millisecondsSinceEpoch, freeMinutes: 5, kind: 'talk', noteId: noteId, started: started, secondsLeft: left);

void main() {
  group('SocraticService (D66)', () {
    test('only reviewed cards in play are candidates; the talked-through tag is read', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await library(db, n: 6);
      final svc = SocraticService(db, TalkService(db, SettingsRepo(db)));
      expect(await svc.hasCandidate(), isFalse, reason: 'every card is new');
      await reviewed(db, ids[0], lapses: 3);
      await reviewed(db, ids[1], lapses: 2);
      await reviewed(db, ids[2], lapses: 1);
      await reviewed(db, ids[3], lapses: 9);
      await db.customStatement('UPDATE card SET suspended = 1 WHERE note_id = ${ids[3]}');
      await reviewed(db, ids[4], lapses: 9);
      await db.customStatement('UPDATE card SET retired_at = 1 WHERE note_id = ${ids[4]}');
      await reviewed(db, ids[5], lapses: 9);
      await (db.update(db.notes)..where((n) => n.id.equals(ids[5]))).write(const NotesCompanion(type: Value('problem')));
      await (db.update(db.notes)..where((n) => n.id.equals(ids[1]))).write(const NotesCompanion(tags: Value('bio talked_through')));
      expect(await svc.hasCandidate(), isTrue);
      final c = await svc.candidates();
      expect({for (final x in c) x.noteId}, {ids[0], ids[1], ids[2]}, reason: 'not new, suspended, retired or a problem');
      expect(c.firstWhere((x) => x.noteId == ids[1]).talkedThrough, isTrue);
      expect(c.firstWhere((x) => x.noteId == ids[0]).talkedThrough, isFalse);
    });
  });

  group('the screen', () {
    late AppDatabase db;
    late List<int> ids;
    late FakePauseBridge bridge;
    late _Sharer sharer;

    /// Opens the screen from a button (so it can close). [visit] builds the pending visit once the library exists.
    Future<void> open(WidgetTester t, {PauseVisit? Function(List<int> ids)? visit, bool reviewedCards = true}) async {
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async => t.runAsync(db.close));
      ids = (await t.runAsync(() => library(db)))!;
      if (reviewedCards) {
        await t.runAsync(() async {
          // lapses 5,4,3,2,1,0 for Question 0..5: the hardest five are Questions 0 to 4.
          for (var i = 0; i < 6; i++) {
            await reviewed(db, ids[i], lapses: 5 - i, difficulty: 8.0 - i);
          }
        });
      }
      bridge.pending = visit?.call(ids);
      sharer = _Sharer();
      await t.pumpWidget(ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
          pauseBridgeProvider.overrideWithValue(bridge),
          promptSharerProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SocraticPauseScreen())), child: const Text('go')),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await flush(t);
    }

    String visibleQuestion() {
      final hit = [for (var i = 0; i < 6; i++) if (find.text('Question $i about the cell?').evaluate().isNotEmpty) i];
      expect(hit.length, 1, reason: 'exactly one card is shown');
      return 'Question ${hit.single} about the cell?';
    }

    testWidgets('a fresh conversation shows one hard card, only its question, and starts the clock when shared', (t) async {
      bridge = FakePauseBridge();
      await open(t, visit: (_) => talkVisit());
      expect(find.text('Before you open LinkedIn'), findsOneWidget);
      final q = visibleQuestion();
      expect(q, isNot('Question 5 about the cell?'), reason: 'never the card with no lapses while others lapsed');
      expect(find.textContaining('hidden'), findsNothing, reason: 'the answer is not shown on this screen');
      expect(find.textContaining('Open LinkedIn (in'), findsNothing, reason: 'the clock has not started yet');

      await t.tap(find.text('Share to an AI app'));
      await flush(t);
      final prompt = sharer.sent.single;
      expect(prompt, contains('Socratic tutor'));
      expect(prompt, contains('Question: $q'));
      expect(prompt, contains('Answer: Answer'), reason: 'the AI is told the answer to steer by; the learner is not');
      final noteId = ids[int.parse(q.split(' ')[1])];
      expect(bridge.talkCalls.single.$1, noteId, reason: 'the phone side is told which card');
      final tags = (await t.runAsync(() => (db.select(db.notes)..where((n) => n.id.equals(noteId))).getSingle()))!.tags;
      expect(tags, contains('talked_through'));
      expect(find.text('Open LinkedIn (in 3:00)'), findsOneWidget);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Open LinkedIn (in 3:00)')).onPressed, isNull);

      await t.pump(const Duration(seconds: 61));
      expect(find.text('Open LinkedIn (in 1:59)'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('when the time is up the button opens the app and the screen closes', (t) async {
      bridge = FakePauseBridge();
      // Already started: the phone side kept the card, so this is that card, not a fresh pick.
      await open(t, visit: (ids) => talkVisit(started: true, noteId: ids[3], left: 2));
      expect(find.text('Question 3 about the cell?'), findsOneWidget);
      expect(find.text('Open LinkedIn (in 0:02)'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('I talked it through: open LinkedIn for 5 minutes'), findsOneWidget);
      await t.tap(find.text('I talked it through: open LinkedIn for 5 minutes'));
      await flush(t);
      expect(bridge.grants, 1);
      await t.pumpAndSettle();
      expect(find.byType(SocraticPauseScreen), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('too early by the phone side\'s clock: the screen shows the time it gave', (t) async {
      bridge = FakePauseBridge()..grant = const TalkGrant(ok: false, secondsLeft: 40, reason: 'early');
      await open(t, visit: (ids) => talkVisit(started: true, noteId: ids[0], left: 0));
      await t.tap(find.text('I talked it through: open LinkedIn for 5 minutes'));
      await flush(t);
      expect(find.textContaining('A little longer'), findsOneWidget);
      expect(find.text('Open LinkedIn (in 0:40)'), findsOneWidget);
      expect(find.byType(SocraticPauseScreen), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a visit that ran out while the learner was away says so', (t) async {
      bridge = FakePauseBridge()..grant = const TalkGrant(ok: false, reason: 'none');
      await open(t, visit: (ids) => talkVisit(started: true, noteId: ids[0], left: 0));
      await t.tap(find.text('I talked it through: open LinkedIn for 5 minutes'));
      await flush(t);
      expect(find.text('This pause has run out'), findsOneWidget);
      expect(find.textContaining('Open the app or site again'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no visit, a cards visit, or nothing reviewed: a plain message and Close', (t) async {
      bridge = FakePauseBridge();
      await open(t); // no pending visit
      expect(find.text('This pause has run out'), findsOneWidget);
      await t.pumpWidget(const SizedBox());

      bridge = FakePauseBridge();
      await open(t, visit: (_) => const PauseVisit(label: 'LinkedIn', atMs: 1, freeMinutes: 2));
      expect(find.text('This pause asked for cards'), findsOneWidget);
      await t.pumpWidget(const SizedBox());

      bridge = FakePauseBridge();
      await open(t, visit: (_) => talkVisit(), reviewedCards: false);
      expect(find.text('No card to talk about'), findsOneWidget);
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
      expect(find.byType(SocraticPauseScreen), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Not now drops the visit and closes', (t) async {
      bridge = FakePauseBridge();
      await open(t, visit: (_) => talkVisit());
      await t.tap(find.text('Not now'));
      await flush(t);
      await t.pumpAndSettle();
      expect(bridge.pending, isNull);
      expect(find.byType(SocraticPauseScreen), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the app comes back mid-conversation', () {
    testWidgets('a started conversation reopens its screen on the same card with the time already counted', (t) async {
      late List<int> ids;
      final bridge = FakePauseBridge();
      final db = await boot(t, settings: {'guide_seen': '1'}, prepare: (db) async {
        ids = await library(db);
        for (var i = 0; i < 6; i++) {
          await reviewed(db, ids[i], lapses: 5 - i, difficulty: 8.0 - i);
        }
        // The learner is part-way through a conversation about Question 4, which is not what a fresh pick would choose.
        bridge.pending = talkVisit(started: true, noteId: ids[4], left: 95);
      }, extra: [pauseBridgeProvider.overrideWithValue(bridge)]);
      expect(find.text('Before you open LinkedIn'), findsOneWidget);
      expect(find.text('Question 4 about the cell?'), findsOneWidget);
      expect(textMatching(RegExp(r'^Open LinkedIn \(in 1:3[2-5]\)$')), findsOneWidget, reason: 'about the 95 seconds the phone side said, less the test clock');
      await done(t, db);
    });

    testWidgets('a pause that was never shared does not take the app over when it is opened by hand', (t) async {
      final bridge = FakePauseBridge()..pending = talkVisit();
      final db = await boot(t, settings: {'guide_seen': '1'}, extra: [pauseBridgeProvider.overrideWithValue(bridge)]);
      expect(find.byType(SocraticPauseScreen), findsNothing);
      await done(t, db);
    });
  });

  group('settings (D66)', () {
    test('the minutes are saved and handed to the phone side with whether a conversation is on offer; junk is cleaned', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final bridge = FakePauseBridge();
      final s = PauseSettings(db, SettingsRepo(db), bridge);
      expect((await s.load()).talkMinutes, 5, reason: 'the default');
      await s.save((await s.load()).copyWith(talkMinutes: 10));
      expect(bridge.config!['talkMinutes'], 10);
      expect(bridge.config!['talkOffered'], false, reason: 'nothing reviewed yet');
      final ids = await library(db);
      await reviewed(db, ids[0], lapses: 1);
      await s.push();
      expect(bridge.config!['talkOffered'], true);
      await SettingsRepo(db).set(PauseSettings.talkMinKey, '7');
      expect((await s.load()).talkMinutes, 5, reason: 'not one of the choices: back to the default');
    });

    testWidgets('the Focus screen has its own free-time choice for the conversation', (t) async {
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
      await t.scrollUntilVisible(find.text('Free time after a Socratic conversation'), 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text('Free time after a Socratic conversation'));
      await t.pump();
      expect(find.text('Free time after a Socratic conversation'), findsOneWidget);
      expect(find.textContaining('at least 3 minutes'), findsOneWidget);
    });
  });
}
