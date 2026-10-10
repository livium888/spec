import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshots/screens_test.dart' show boot, settle;

/// D49: the cheap wins taken from the standard flashcard tools.
void main() {
  late AppDatabase db;
  late SettingsRepo settings;
  late ReviewService review;
  late List<int> ids;
  final t0 = DateTime.utc(2024, 3, 1, 12);

  Future<void> seed(AppDatabase d, {int n = 8}) async {
    final imp = ImportService(d);
    await imp.commit(
        await imp.preview(jsonEncode({
          'domain': 'Bio',
          'cards': [
            for (var i = 0; i < n; i++)
              {'type': 'basic', 'front': 'Question number $i here?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high'}
          ]
        })),
        now: t0);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepo(db);
    review = ReviewService(db, settings, ParamsRepo(db, settings));
    await seed(db);
    ids = [for (final c in await db.select(db.cards).get()) c.id];
  });
  tearDown(() => db.close());

  String log(int card, int at, int rating, String before, double? stab) =>
      "INSERT INTO review_log (card_id, reviewed_at, rating, duration_ms, state_before, due_before, stability_before, elapsed_days, scheduled_days, fsrs_version, params_id) "
      "VALUES ($card, $at, $rating, 5000, '$before', $at, ${stab ?? 'NULL'}, 0, 0, 'v', 1)";

  group('true retention by card age and period', () {
    test('young and mature are split by stability before the answer; 30 days is inside one year', () async {
      await review.review(cardId: ids[0], rating: 3, durationMs: 1000, now: t0); // makes params row 1
      final now = t0.add(const Duration(days: 200));
      final nowMs = now.millisecondsSinceEpoch;
      const day = 86400000;
      var k = 0;
      Future<void> add(int daysAgo, int rating, double stab) => db.customStatement(log(ids[1], nowMs - daysAgo * day + (k++), rating, 'review', stab));
      for (var i = 0; i < 10; i++) {
        await add(5, i < 3 ? 1 : 3, 5); // young, last 30 days: 7 of 10
        await add(5, i < 1 ? 1 : 3, 40); // mature, last 30 days: 9 of 10
        await add(100, 3, 40); // mature, older than 30 days: 10 of 10
      }
      await add(100, 1, 5); // young, older than 30 days, but only one answer
      await add(400, 1, 5); // outside a year: ignored
      final r = (await StatsService(db, settings).compute(now: now)).retention;
      expect((r.young30.answers, r.young30.passed), (10, 7));
      expect((r.mature30.answers, r.mature30.passed), (10, 9));
      expect((r.all30.answers, r.all30.passed), (20, 16));
      expect((r.mature365.answers, r.mature365.passed), (20, 19));
      expect(r.young365.answers, 11);
      expect(r.young365.rate, isNotNull);
      expect(r.young30.rate, closeTo(0.7, 1e-9));
      expect(r.all365.answers, 31, reason: 'the answer from 400 days ago is outside the year');
    });

    test('under 10 answers is a dash (null), and relearning answers never count', () async {
      await review.review(cardId: ids[0], rating: 3, durationMs: 1000, now: t0);
      final now = t0.add(const Duration(days: 3));
      final at = now.millisecondsSinceEpoch - 3600000;
      for (var k = 0; k < 9; k++) {
        await db.customStatement(log(ids[1], at + k, 3, 'review', 4));
      }
      for (var k = 0; k < 30; k++) {
        await db.customStatement(log(ids[2], at + 100 + k, 3, 'relearning', 2));
      }
      final r = (await StatsService(db, settings).compute(now: now)).retention;
      expect(r.all30.answers, 9);
      expect(r.all30.rate, isNull);
    });
  });

  test('the recall bands count every learned card once, and add up to the estimate\'s cards', () async {
    final now = t0.add(const Duration(days: 40));
    final nowMs = now.millisecondsSinceEpoch;
    const day = 86400000;
    Future<void> set(int id, double stab, int daysAgo) => db.customStatement(
        "UPDATE card SET state = 'review', stability = ?, last_review = ?, reps = 3 WHERE id = ?", [stab, nowMs - daysAgo * day, id]);
    await set(ids[0], 100, 1); // very likely recalled
    await set(ids[1], 2, 60); // long forgotten
    await set(ids[2], 10, 90); // well under 90%
    final s = await StatsService(db, settings).compute(now: now);
    expect(s.recallBins.length, 10);
    expect(s.recallBins.fold<int>(0, (a, b) => a + b), 3);
    expect(s.recallBins[9], 1, reason: 'the stable recent card is in the top band');
    expect(s.recallBins.take(8).fold<int>(0, (a, b) => a + b), 2, reason: 'the two overdue cards are below 80%');
  });

  test('the advice card measures recall the same way as Progress (review answers only)', () async {
    // The advisor's own queries must not count relearning answers either (D48 fixed Progress; D49 the advice).
    for (final f in ['lib/data/engine_service.dart', 'lib/data/learn_service.dart']) {
      final src = await _read(f);
      expect(src.contains("state_before IN ('review','relearning')"), isFalse, reason: f);
    }
  });

  group('mark for later', () {
    test('marking tags the note, unmarking removes it, and Browse can filter to marked cards', () async {
      final edit = CardEditService(db, settings);
      final note = (await db.select(db.notes).get()).first;
      await review.setMarked(note.id, true);
      expect((await db.select(db.notes).get()).firstWhere((n) => n.id == note.id).tags.split(' '), contains('marked'));
      await review.setMarked(note.id, true); // twice: still one tag
      expect((await (db.select(db.notes)..where((n) => n.id.equals(note.id))).getSingle()).tags.split(' ').where((x) => x == 'marked').length, 1);
      final marked = await edit.search(markedOnly: true);
      expect(marked.map((r) => r.noteId), [note.id]);
      expect(marked.single.marked, isTrue);
      expect((await edit.search()).where((r) => r.marked).length, 1);
      await review.setMarked(note.id, false);
      expect(await edit.search(markedOnly: true), isEmpty);
    });

    test('"marked" is reserved: an AI answer cannot put it on a card', () {
      expect(kReservedTags, contains('marked'));
      expect(cleanTag('Marked'), isNot('marked'));
    });
  });

  testWidgets('Today shows the New / Learning / Due counts, and a card can be marked in the review', (t) async {
    final d = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(d.close));
    await t.runAsync(() async {
      await seed(d, n: 5);
      await SettingsRepo(d).set(SettingsRepo.guideSeen, '1');
    });
    final key = GlobalKey();
    await boot(t, d, key);
    expect(find.text('New 5'), findsOneWidget);
    expect(find.text('Learning 0'), findsOneWidget);
    expect(find.text('Due 0'), findsOneWidget);

    await t.tap(find.text('Start review'));
    await settle(t);
    await t.tap(find.byTooltip('More actions for this card'));
    await settle(t, rounds: 2);
    await t.tap(find.text('Mark to look at later'));
    await settle(t, rounds: 3);
    expect(find.text('Marked'), findsOneWidget, reason: 'the card itself shows that it is marked');
    final tags = await t.runAsync(() async => [for (final n in await d.select(d.notes).get()) n.tags]);
    expect(tags!.where((x) => x.contains('marked')).length, 1);
    await t.tap(find.byTooltip('More actions for this card'));
    await settle(t, rounds: 2);
    await t.tap(find.text('Remove the mark'));
    await settle(t, rounds: 3);
    expect(find.text('Marked'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}

Future<String> _read(String path) => File(path).readAsString();
