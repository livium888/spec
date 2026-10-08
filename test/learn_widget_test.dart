import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/app/share_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/optimizer_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/plan_service.dart';
import 'package:daily_learning/data/reminder_service.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/domain/fsrs_trainer.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/main.dart';
import 'package:daily_learning/presentation/library_screen.dart' show LibraryScreen;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

Future<AppDatabase> boot(WidgetTester t,
    {bool seed = false, Map<String, String> settings = const {}, Future<void> Function(AppDatabase)? prepare, List<Override> extra = const []}) async {
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
    await prepare?.call(db);
  });
  await t.pumpWidget(ProviderScope(
    overrides: [
      bootstrapProvider.overrideWithValue(Bootstrap(File('x'), Directory.systemTemp, db)),
      assetBundleProvider.overrideWithValue(DirAssetBundle('docs/starter-outlines')),
      ...extra,
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
  editDeleteWidgetTests();
  guideWidgetTests();
  memoryModelWidgetTests();
  diagnosticsWidgetTests();
  shareWidgetTests();
  reminderWidgetTests();
  phase2WidgetTests();
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

  testWidgets('when every topic is covered, ONE press still ends at a prompt (more topics), never at a chooser', (t) async {
    final db = await boot(t, seed: true);
    await t.runAsync(() async {
      for (final it in await db.select(db.syllabusItems).get()) {
        await db.update(db.syllabusItems).replace(it.copyWith(status: 'skipped'));
      }
    });
    await t.tap(find.text('Learn something new'));
    await until(t, find.text('Your prompt'));
    await settle(t);

    expect(find.text('Your prompt'), findsOneWidget);
    expect(find.text('More topics for Bio'), findsOneWidget);
    expect(find.textContaining('Pick one'), findsNothing);
    expect(find.text('Copy prompt'), findsOneWidget);
    final logs = await t.runAsync(() => db.select(db.promptLogs).get());
    expect(logs!.single.templateVersion, startsWith('outline-'));
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

void editDeleteWidgetTests() {
  testWidgets('Library -> Browse -> edit text, then delete with confirmation', (t) async {
    final db = await boot(t);
    await t.runAsync(() async {
      final svc = ImportService(db);
      await svc.commit(await svc.preview(jsonEncode({
        'domain': 'Bio',
        'syllabus_item': null,
        'cards': [
          {'type': 'basic', 'front': 'What powers the cell?', 'back': 'Mitochondria',
           'source_type': 'quote', 'source_ref': 'b', 'supporting_quote': 'q', 'confidence': 'high'}
        ]
      })));
    });
    await t.tap(find.text('Library'));
    await settle(t);
    await t.dragUntilVisible(find.text('Browse, edit or delete cards'), find.byType(ListView).first, const Offset(0, -200));
    await t.tap(find.text('Browse, edit or delete cards'));
    await until(t, find.text('What powers the cell?'));
    await settle(t);
    await t.tap(find.text('What powers the cell?'));
    await until(t, find.text('Save changes'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, 'Question'), 'What makes ATP?');
    await t.tap(find.text('Save changes'));
    await until(t, find.text('What makes ATP?'));
    await settle(t);
    expect(find.text('What makes ATP?'), findsOneWidget);

    await t.tap(find.text('What makes ATP?'));
    await until(t, find.text('Save changes'));
    await settle(t);
    await t.tap(find.byTooltip('Delete card'));
    await settle(t);
    expect(find.text('Delete this card?'), findsOneWidget);
    await t.tap(find.text('Delete'));
    await until(t, find.text('No cards yet.'));
    await settle(t);
    expect(find.text('No cards yet.'), findsOneWidget);
    await done(t, db);
  });
}

void guideWidgetTests() {
  testWidgets('first run shows a guide card once; the guide opens from Today and from Settings', (t) async {
    final db = await boot(t);
    expect(find.text('New here?'), findsOneWidget);
    await t.tap(find.text('Show me'));
    await settle(t);
    expect(find.text('How it works'), findsWidgets);
    expect(find.textContaining('Three kinds of prompt'), findsOneWidget);
    await t.pageBack();
    await settle(t);
    expect(find.text('New here?'), findsNothing); // seen: the card does not come back

    await t.tap(find.byTooltip('How it works'));
    await settle(t);
    expect(find.textContaining('The idea'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('"Not now" dismisses the card for good', (t) async {
    final db = await boot(t);
    await t.tap(find.text('Not now'));
    await settle(t);
    expect(find.text('New here?'), findsNothing);
    await done(t, db);
  });

  testWidgets('with a full library the map prompt is reached by ONE press and says what answer to bring back', (t) async {
    final db = await boot(t, seed: true, settings: {'guide_seen': '1'});
    await t.runAsync(() async {
      // Two earlier outline prompts so the next growth step is the third: "new subjects".
      for (final i in [1, 2]) {
        await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
            createdAt: i, domainId: const Value(1), templateVersion: 'outline-v2', promptText: 'x', cardsRequested: 0, status: const Value('imported')));
      }
      for (final it in await db.select(db.syllabusItems).get()) {
        await db.update(db.syllabusItems).replace(it.copyWith(status: 'skipped'));
      }
    });
    await t.tap(find.text('Learn something new'));
    await until(t, find.text('Your prompt'));
    await settle(t);
    expect(find.text('New subjects, chosen for you'), findsOneWidget);
    expect(find.textContaining('several new subjects'), findsOneWidget);
    await done(t, db);
  });
}

void memoryModelWidgetTests() {
  testWidgets('Settings -> Memory model: a new learner sees when to fit and why, and cannot fit yet', (t) async {
    final db = await boot(t, settings: {'guide_seen': '1'});
    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await t.tap(find.text('Memory model: fit to my reviews'));
    await until(t, find.text('Using: the built-in settings'));
    await settle(t);
    expect(find.textContaining('Not yet'), findsOneWidget);
    expect(find.textContaining('more reviews'), findsWidgets);
    expect(find.textContaining('noise'), findsOneWidget); // the reason
    final fit = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Fit anyway'));
    expect(fit.onPressed, isNull);
    expect(find.textContaining('Available from 1000 usable reviews'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('with enough history: Today nudges, the screen fits, shows the check, and applies or keeps', (t) async {
    final db = await boot(t, settings: {'guide_seen': '1'}, prepare: (db) async {
      final s = SettingsRepo(db);
      final params = ParamsRepo(db, s);
      final review = ReviewService(db, s, params);
      final imp = ImportService(db);
      await imp.commit(await imp.preview(jsonEncode({
        'domain': 'Bio',
        'syllabus_item': null,
        'cards': [
          for (var i = 0; i < 120; i++)
            {'type': 'basic', 'front': 'Question $i?', 'back': 'A', 'source_type': 'quote', 'source_ref': 'b', 'supporting_quote': 'q', 'confidence': 'high'}
        ]
      })));
      final start = DateTime.now().toUtc().subtract(const Duration(days: 400));
      const gaps = [0, 1, 3, 7, 14, 30, 45, 60, 80, 100, 120, 150];
      for (final c in await db.select(db.cards).get()) {
        await review.review(cardId: c.id, rating: 3, durationMs: 800, now: start.add(Duration(minutes: c.id)));
        for (var k = 0; k < gaps.length; k++) {
          await review.review(
              cardId: c.id,
              rating: (c.id + k) % 7 == 0 ? 1 : 3,
              durationMs: 800,
              now: start.add(Duration(days: gaps[k] + 1, minutes: c.id)));
        }
      }
    }, extra: [
      optimizerServiceProvider.overrideWith((ref) => OptimizerService(
            ref.watch(dbProvider),
            ref.watch(settingsRepoProvider),
            ref.watch(paramsRepoProvider),
            runner: (r) async => trainFsrs(TrainRequest(
                cards: r.cards, start: r.start, defaults: r.defaults, steps: 20, batchReviews: 1000)),
          )),
    ]);
    // Today shows the nudge with the reason.
    expect(find.text('Your memory model can be personalised'), findsOneWidget);
    await t.tap(find.text('See details'));
    await until(t, find.text('Fit to my memory'));
    await settle(t);
    expect(find.text('When to fit: now'), findsOneWidget);
    expect(find.textContaining('Across'), findsOneWidget); // expected vs actual recall, said once

    await t.tap(find.text('Fit to my memory'));
    await until(t, find.byWidgetPredicate((w) => w is Text && (w.data == 'A better fit was found' || w.data == 'Nothing to change')));
    await settle(t);
    expect(find.textContaining('Checked on'), findsOneWidget);
    final apply = find.text('Use the new weights');
    await t.tap(apply.evaluate().isNotEmpty ? apply : find.text('OK'));
    await settle(t);
    expect(find.textContaining('Kept your current settings').evaluate().length + find.textContaining('Done.').evaluate().length, 1);
    await done(t, db);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

void diagnosticsWidgetTests() {
  testWidgets('Settings > Diagnostics: shows the build, lets you mark checks, and copies a report', (t) async {
    final db = await boot(t, settings: {'guide_seen': '1'});
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await t.dragUntilVisible(find.text('Diagnostics and phone check'), find.byType(ListView).first, const Offset(0, -200));
    await t.tap(find.text('Diagnostics and phone check'));
    await until(t, find.text('Local development build'));
    await settle(t);
    expect(find.text('Local development build'), findsOneWidget);
    expect(find.text('Phone check'), findsOneWidget);

    await t.tap(find.byTooltip('Works').first);
    await settle(t);
    await t.scrollUntilVisible(find.text('Copy report'), 300, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.tap(find.text('Copy report'));
    await settle(t);
    expect(copied, contains('[works] New version installed over the old one'));
    expect(copied, contains('(no errors recorded)'));
    final saved = await t.runAsync(() => SettingsRepo(db).get('phone_check'));
    expect(saved, contains('works'));
    await done(t, db);
  });
}

class FakeSharer implements PromptSharer {
  final sent = <String>[];
  @override
  Future<void> send(String text, {String? title}) async => sent.add(text);
}

class FakeInbox implements ShareInbox {
  final queue = <String?>[];
  @override
  Future<String?> take() async => queue.isEmpty ? null : queue.removeAt(0);
}

const _sharedCards = '{"domain":"Bio","syllabus_item":null,"cards":[{"type":"basic","front":"What powers the cell?",'
    '"back":"Mitochondria","source_type":"model_memory","source_ref":"","supporting_quote":"","confidence":"high"}]}';

void shareWidgetTests() {
  testWidgets('prompt screen: "Send to my AI app" hands the whole prompt to the share sheet', (t) async {
    final sharer = FakeSharer();
    final db = await boot(t, seed: true, settings: {'guide_seen': '1'},
        extra: [promptSharerProvider.overrideWithValue(sharer)]);
    await t.tap(find.text('Learn something new'));
    await until(t, find.text('Your prompt'));
    await settle(t);
    await t.tap(find.text('Send to my AI app'));
    await settle(t);
    expect(sharer.sent, hasLength(1));
    expect(sharer.sent.single, contains('Cell membrane'));
    expect(sharer.sent.single, contains('JSON'));
    await done(t, db);
  });

  testWidgets('an answer shared into the app opens the preview by itself and saves nothing until confirmed', (t) async {
    final inbox = FakeInbox()..queue.add(_sharedCards);
    final db = await boot(t, settings: {'guide_seen': '1'}, extra: [shareInboxProvider.overrideWithValue(inbox)]);
    await until(t, find.text('Import 1 card'));
    await settle(t);
    expect(find.text('Import cards'), findsOneWidget);
    expect(find.text('What powers the cell?'), findsOneWidget);
    expect((await t.runAsync(() => db.select(db.cards).get()))!, isEmpty); // preview only
    await t.tap(find.text('Import 1 card'));
    await until(t, find.textContaining('Imported 1 notes'));
    expect((await t.runAsync(() => db.select(db.cards).get()))!, hasLength(1));
    await done(t, db);
  });

  testWidgets('a share that arrives while the app is open is picked up when it returns to the front', (t) async {
    final inbox = FakeInbox();
    final db = await boot(t, settings: {'guide_seen': '1'}, extra: [shareInboxProvider.overrideWithValue(inbox)]);
    expect(find.text('Import cards'), findsNothing);
    inbox.queue.add(_sharedCards);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await until(t, find.text('Import 1 card'));
    expect(find.text('Import 1 card'), findsOneWidget);
    await done(t, db);
  });

  testWidgets('text that is not JSON is explained, not imported; oversized shares are refused', (t) async {
    final inbox = FakeInbox()..queue.add('Sure! Here are your cards: …');
    final db = await boot(t, settings: {'guide_seen': '1'}, extra: [shareInboxProvider.overrideWithValue(inbox)]);
    await until(t, find.textContaining('This can'));
    await settle(t);
    expect(find.textContaining('Not valid JSON'), findsOneWidget);
    expect((await t.runAsync(() => db.select(db.cards).get()))!, isEmpty);
    await t.pageBack();
    await settle(t);
    inbox.queue.add('x' * (kMaxSharedChars + 1));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await until(t, find.textContaining('too large'));
    expect(find.textContaining('too large'), findsOneWidget);
    expect(find.text('Import cards'), findsNothing);
    await done(t, db);
  });
}

void reminderWidgetTests() {
  testWidgets('Settings: turning the reminder on schedules it; refusing the permission keeps it off with a reason', (t) async {
    final backend = _WidgetBackend();
    final db = await boot(t, settings: {'guide_seen': '1'}, extra: [reminderBackendProvider.overrideWithValue(backend)]);
    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await t.dragUntilVisible(find.text('Remind me every day'), find.byType(ListView).first, const Offset(0, -200));
    backend.allow = false;
    await t.tap(find.text('Remind me every day'));
    await settle(t);
    expect(find.textContaining('blocked'), findsOneWidget);
    expect(backend.scheduled, isEmpty);

    backend.allow = true;
    await t.tap(find.text('Remind me every day'));
    await settle(t);
    expect(backend.scheduled, hasLength(1));
    expect(backend.scheduled.single.hour, 19);
    expect(find.textContaining('Around 19:00'), findsOneWidget);

    await t.tap(find.text('Remind me every day'));
    await settle(t);
    expect(backend.cancels, 1);
    await done(t, db);
  });
}

class _WidgetBackend implements ReminderBackend {
  bool allow = true;
  final scheduled = <DateTime>[];
  int cancels = 0;
  @override
  Future<bool> requestPermission() async => allow;
  @override
  Future<void> scheduleDaily(DateTime firstLocal, String title, String body) async => scheduled.add(firstLocal);
  @override
  Future<void> cancel() async => cancels++;
}

void phase2WidgetTests() {
  testWidgets('Library > Looking ahead: shows the table, the verdict and the levers; the slider re-runs', (t) async {
    final db = await boot(t, settings: {'guide_seen': '1', 'daily_minutes': '10'}, extra: [
      planServiceProvider.overrideWith((ref) => PlanService(ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(paramsRepoProvider),
          runner: (r) async => computePlan(r))),
    ], prepare: (db) async {
      final imp = ImportService(db);
      await imp.commit(await imp.preview(jsonEncode({
        'domain': 'Bio',
        'syllabus_item': null,
        'cards': [
          for (var i = 0; i < 30; i++)
            {'type': 'basic', 'front': 'Question $i?', 'back': 'A', 'source_type': 'quote', 'source_ref': 'b', 'supporting_quote': 'q', 'confidence': 'high'}
        ]
      })));
    });
    await t.tap(find.text('Library'));
    await settle(t);
    await t.scrollUntilVisible(find.text('Looking ahead'), 200, scrollable: find.descendant(of: find.byType(LibraryScreen), matching: find.byType(Scrollable)).first);
    await t.pump();
    await t.tap(find.text('Looking ahead'));
    await until(t, find.text('in 5 years'));
    await settle(t);
    expect(find.text('in 6 months'), findsOneWidget);
    expect(find.text('in 10 years'), findsOneWidget);
    expect(find.textContaining('New cards a day'), findsOneWidget);
    expect(find.text('Retire mastered cards'), findsOneWidget);
    expect(find.text('Ways to bring it down'), findsOneWidget);
    await done(t, db);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('Retire mastered cards: nothing qualifies at first; after mastering, retire with confirmation and bring back', (t) async {
    final db = await boot(t, settings: {'guide_seen': '1'}, prepare: (db) async {
      final imp = ImportService(db);
      await imp.commit(await imp.preview(jsonEncode({
        'domain': 'Bio',
        'syllabus_item': null,
        'cards': [
          for (var i = 0; i < 3; i++)
            {'type': 'basic', 'front': 'Mastered fact $i?', 'back': 'A', 'source_type': 'quote', 'source_ref': 'b', 'supporting_quote': 'q', 'confidence': 'high'}
        ]
      })));
      await db.customStatement("UPDATE card SET state='review', stability=1500, difficulty=3, reps=10, lapses=0");
    });
    await t.tap(find.text('Library'));
    await settle(t);
    await t.scrollUntilVisible(find.text('Retire mastered cards'), 200, scrollable: find.descendant(of: find.byType(LibraryScreen), matching: find.byType(Scrollable)).first);
    await t.pump();
    await t.tap(find.text('Retire mastered cards'));
    await until(t, find.textContaining('3 cards qualify'));
    await settle(t);
    expect(find.textContaining('saves about'), findsOneWidget);
    await t.tap(find.text('Retire 3 cards'));
    await settle(t);
    expect(find.text('Retire 3 cards?'), findsOneWidget);
    await t.tap(find.text('Retire them'));
    await until(t, find.textContaining('Retired (3)'));
    await settle(t);
    expect(find.text('Mastered fact 0?').evaluate().length + find.text('Mastered fact 1?').evaluate().length + find.text('Mastered fact 2?').evaluate().length, 3);
    await t.tap(find.text('Bring back all retired cards'));
    await until(t, find.text('Nothing retired.'));
    expect(find.text('Nothing retired.'), findsOneWidget);
    await done(t, db);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('Subjects: a target recall can be chosen per subject', (t) async {
    final db = await boot(t, seed: true, settings: {'guide_seen': '1'});
    await t.tap(find.byTooltip('Settings and backup'));
    await settle(t);
    await t.dragUntilVisible(find.text('Subjects and topics'), find.byType(ListView).first, const Offset(0, -200));
    await t.tap(find.text('Subjects and topics'));
    await until(t, find.text('Target recall'));
    await settle(t);
    await t.tap(find.byType(DropdownButtonFormField<double?>).first);
    await settle(t);
    await t.tap(find.text('80%').last);
    await settle(t);
    final r = await t.runAsync(() => db.select(db.domains).get());
    expect(r!.single.retention, 0.80);
    await done(t, db);
  });
}
