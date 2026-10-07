import 'dart:convert';
import 'dart:math';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/review_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/day_clock.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:daily_learning/domain/study_card.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Env {
  Env() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepo(db);
    params = ParamsRepo(db, settings);
    review = ReviewService(db, settings, params);
    queue = QueueService(db, settings);
    import = ImportService(db);
  }
  late final AppDatabase db;
  late final SettingsRepo settings;
  late final ParamsRepo params;
  late final ReviewService review;
  late final QueueService queue;
  late final ImportService import;

  Future<ImportSummary> addBasic(int n, {String domain = 'Bio', DateTime? now}) async {
    final cards = [
      for (var i = 0; i < n; i++)
        {
          'type': 'basic',
          'front': 'Question number $i about $domain?',
          'back': 'Answer $i',
          'source_type': 'quote',
          'source_ref': 'book p$i',
          'supporting_quote': 'quote $i',
          'confidence': 'high',
        }
    ];
    final p = await import.preview(jsonEncode({'domain': domain, 'syllabus_item': null, 'cards': cards}));
    return import.commit(p, now: now);
  }

  Future<List<CardSnapshot>> allCards() async =>
      [for (final c in await (db.select(db.cards)..orderBy([(c) => OrderingTerm.asc(c.id)])).get()) snapshotOf(c)];
}

DateTime t0 = DateTime.utc(2024, 3, 1, 12);

void main() {
  late Env e;
  setUp(() => e = Env());
  tearDown(() => e.db.close());

  group('replay', () {
    test('RebuildCardsFromLog reproduces live state exactly (random sequence, params change)', () async {
      await e.addBasic(6, now: t0);
      final rnd = Random(7);
      var now = t0;
      for (var step = 0; step < 150; step++) {
        now = now.add(Duration(minutes: 1 + rnd.nextInt(60 * 30)));
        if (step == 60) {
          await e.settings.set(SettingsRepo.desiredRetention, '0.85');
          await e.params.syncFromSettings(now: now);
        }
        final cards = await e.allCards();
        final c = cards[rnd.nextInt(cards.length)];
        await e.review.review(cardId: c.id, rating: 1 + rnd.nextInt(4), durationMs: 1000, now: now);
      }
      final live = await e.allCards();
      expect(live.where((c) => c.reps > 0), isNotEmpty);

      final mism = await e.review.rebuildAll(apply: false);
      expect(mism, isEmpty, reason: mism.join('\n'));

      // And applying a rebuild changes nothing.
      await e.review.rebuildAll();
      expect(await e.allCards(), live);
    });

    test('rebuild repairs a corrupted cache and reports it first', () async {
      await e.addBasic(1, now: t0);
      final id = (await e.allCards()).single.id;
      await e.review.review(cardId: id, rating: 3, durationMs: 1, now: t0);
      final good = (await e.allCards()).single;
      await (e.db.update(e.db.cards)..where((c) => c.id.equals(id)))
          .write(const CardsCompanion(stability: Value(999.0)));
      final mism = await e.review.rebuildAll(apply: false);
      expect(mism.single.cardId, id);
      await e.review.rebuildAll();
      expect((await e.allCards()).single, good);
    });

    test('revoked rows are ignored by replay and undo restores the prior state', () async {
      await e.addBasic(1, now: t0);
      final id = (await e.allCards()).single.id;
      await e.review.review(cardId: id, rating: 3, durationMs: 1, now: t0);
      final afterFirst = (await e.allCards()).single;
      await e.review.review(
          cardId: id, rating: 3, durationMs: 1, now: t0.add(const Duration(minutes: 11)));
      expect((await e.allCards()).single.reps, 2);

      final restored = await e.review.undoLast(now: t0.add(const Duration(minutes: 12)));
      expect(restored, afterFirst);
      expect((await e.allCards()).single, afterFirst);
      final logs = await e.db.select(e.db.reviewLogs).get();
      expect(logs.length, 2); // append-only: row is kept
      expect(logs.where((l) => l.revokedAt != null).length, 1);
      expect(await e.review.rebuildAll(apply: false), isEmpty);

      // Undo again -> back to a pristine new card.
      await e.review.undoLast(now: t0.add(const Duration(minutes: 13)));
      final c = (await e.allCards()).single;
      expect(c.state, CardState.newCard);
      expect(c.reps, 0);
      expect(await e.review.undoLast(), isNull);
    });
  });

  group('import', () {
    test('GUID dedupe: re-import, case/punctuation variants and in-payload duplicates', () async {
      Map<String, dynamic> card(String front) => {
            'type': 'basic', 'front': front, 'back': 'b',
            'source_type': 'quote', 'supporting_quote': 'q', 'confidence': 'high',
          };
      final json = jsonEncode({
        'domain': 'Bio',
        'cards': [card('What is ATP?'), card('what is atp'), card('Other thing?')],
      });
      var p = await e.import.preview(json);
      expect(p.importable.length, 2);
      final s = await e.import.commit(p);
      expect(s.notes, 2);

      p = await e.import.preview(jsonEncode({'domain': 'bio', 'cards': [card('WHAT IS ATP??')]}));
      expect(p.importable, isEmpty);
      expect(p.status[0], PreviewStatus.duplicateInDb);

      // Same text in another domain is a different note.
      p = await e.import.preview(jsonEncode({'domain': 'Chem', 'cards': [card('What is ATP?')]}));
      expect(p.importable.length, 1);
    });

    test('per-card errors, partial import, unverified tagging, cloze cards', () async {
      final p = await e.import.preview(jsonEncode({
        'domain': 'Bio',
        'cards': [
          {'type': 'basic', 'front': 'ok?', 'back': 'yes', 'source_type': 'quote',
           'supporting_quote': 'q', 'confidence': 'high'},
          {'type': 'basic', 'front': '', 'back': 'x', 'source_type': 'nope', 'confidence': 'maybe'},
          {'type': 'basic', 'front': 'mem?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'medium'},
          {'type': 'cloze', 'cloze': 'Cells use {{c1::ATP}} and {{c2::ADP}}.',
           'source_type': 'url', 'source_ref': 'https://example.org/x', 'confidence': 'low'},
          {'type': 'cloze', 'cloze': 'no deletion', 'source_type': 'quote', 'supporting_quote': 'q', 'confidence': 'high'},
          {'type': 'basic', 'front': 'nosrc?', 'back': 'a', 'source_type': 'url', 'confidence': 'high'},
        ],
      }));
      expect(p.cards[1].errors.length, greaterThanOrEqualTo(3));
      expect(p.cards[4].errors, isNotEmpty);
      expect(p.cards[5].errors, isNotEmpty);
      expect(p.importable.map((c) => c.index), [0, 2, 3]);

      final s = await e.import.commit(p);
      expect(s.notes, 3);
      expect(s.cards, 4); // cloze with c1+c2 -> 2 cards
      final notes = await e.db.select(e.db.notes).get();
      expect(notes.where((n) => n.tags.contains('unverified')).length, 2);
      expect(await e.db.select(e.db.domains).get().then((d) => d.single.name), 'Bio');
    });

    test('fatal errors: bad json, wrong shape, code fence tolerated', () async {
      expect((await e.import.preview('not json')).hasFatal, isTrue);
      expect((await e.import.preview('[]')).hasFatal, isTrue);
      expect((await e.import.preview('{"domain":"","cards":[]}')).fatalErrors.length, 2);
      final fenced = '```json\n${jsonEncode({
        'domain': 'D',
        'cards': [
          {'type': 'basic', 'front': 'f?', 'back': 'b', 'source_type': 'quote',
           'supporting_quote': 'q', 'confidence': 'high'}
        ]
      })}\n```';
      expect((await e.import.preview(fenced)).importable.length, 1);
    });

    test('commit updates prompt_log', () async {
      final d = await e.db.into(e.db.domains).insert(DomainsCompanion.insert(name: 'Bio', createdAt: 1));
      await e.db.into(e.db.promptLogs).insert(PromptLogsCompanion.insert(
          createdAt: 5, domainId: d, templateVersion: 'v1', promptText: 'p', cardsRequested: 5));
      await e.addBasic(3);
      final row = await e.db.select(e.db.promptLogs).getSingle();
      expect(row.cardsImported, 3);
      expect(row.status, 'imported');
    });
  });

  group('queue', () {
    test('order: due learning, due reviews, then new; new capped by limit', () async {
      await e.settings.set(SettingsRepo.newPerDay, '3');
      await e.addBasic(8, now: t0);
      var cards = await e.allCards();
      // c0 -> review (Easy), c1 -> learning (Good once => step 10m).
      await e.review.review(cardId: cards[0].id, rating: 4, durationMs: 1, now: t0);
      await e.review.review(cardId: cards[1].id, rating: 3, durationMs: 1, now: t0);
      final later = t0.add(const Duration(days: 30));
      final q = await e.queue.build(now: later);
      expect(q.learning.map((c) => c.id), [cards[1].id]);
      expect(q.reviews.map((c) => c.id), [cards[0].id]);
      expect(q.newCards.length, 3);
      expect(q.ordered.first.id, cards[1].id);
      expect(q.ordered[1].id, cards[0].id);
    });

    test('backlog-adjusted limit formula', () {
      expect(backlogAdjustedNewLimit(10, 0), 10);
      expect(backlogAdjustedNewLimit(10, 24), 10);
      expect(backlogAdjustedNewLimit(10, 25), 9);
      expect(backlogAdjustedNewLimit(10, 99), 7);
      expect(backlogAdjustedNewLimit(10, 250), 0);
      expect(backlogAdjustedNewLimit(10, 1000), 0);
      expect(backlogAdjustedNewLimit(10, 50, divisor: 10), 5);
    });

    test('queue applies the backlog shrink and counts new cards already introduced today', () async {
      await e.settings.set(SettingsRepo.newPerDay, '4');
      await e.settings.set(SettingsRepo.backlogDivisor, '2'); // 2 due reviews -> -1
      await e.addBasic(10, now: t0);
      var cards = await e.allCards();
      for (var i = 0; i < 4; i++) {
        await e.review.review(cardId: cards[i].id, rating: 4, durationMs: 1, now: t0);
      }
      final later = t0.add(const Duration(days: 60));
      final q = await e.queue.build(now: later);
      expect(q.dueReviewCount, 4);
      expect(q.newLimit, 2); // 4 - floor(4/2)
      expect(q.newCards.length, 2);

      // Answer one new card; remaining shrinks.
      await e.review.review(cardId: q.newCards.first.id, rating: 3, durationMs: 1, now: later);
      final q2 = await e.queue.build(now: later.add(const Duration(minutes: 1)));
      expect(q2.newIntroducedToday, 1);
      expect(q2.newCards.length, 1);
    });

    test('sibling burying: cloze siblings are not shown the same day, return next day', () async {
      final p = await e.import.preview(jsonEncode({
        'domain': 'Bio',
        'cards': [
          {'type': 'cloze', 'cloze': '{{c1::A}} and {{c2::B}}', 'source_type': 'quote',
           'supporting_quote': 'q', 'confidence': 'high'}
        ]
      }));
      await e.import.commit(p, now: t0);
      var q = await e.queue.build(now: t0);
      expect(q.ordered.length, 1); // two cards, one note -> one shown
      final first = q.ordered.single;
      await e.review.review(cardId: first.id, rating: 4, durationMs: 1, now: t0);
      q = await e.queue.build(now: t0.add(const Duration(minutes: 5)));
      expect(q.ordered.where((c) => c.id != first.id), isEmpty);

      // Next logical day: sibling is available again.
      final clock = DayClock();
      final tomorrow = DateTime.fromMillisecondsSinceEpoch(clock.dayEndMs(t0) + 3600000, isUtc: true);
      q = await e.queue.build(now: tomorrow);
      expect(q.ordered.any((c) => c.id != first.id), isTrue);
    });

    test('undo unburies siblings', () async {
      await e.import.commit(await e.import.preview(jsonEncode({
        'domain': 'Bio',
        'cards': [
          {'type': 'cloze', 'cloze': '{{c1::A}} {{c2::B}}', 'source_type': 'quote',
           'supporting_quote': 'q', 'confidence': 'high'}
        ]
      })), now: t0);
      final cards = await e.allCards();
      await e.review.review(cardId: cards[0].id, rating: 4, durationMs: 1, now: t0);
      await e.review.undoLast(now: t0.add(const Duration(seconds: 5)));
      final rows = await e.db.select(e.db.cards).get();
      expect(rows.every((c) => c.buriedUntil == null), isTrue);
    });
  });

  group('day clock', () {
    test('rolls over at 04:00 local, honouring the utc offset', () {
      final clock = DayClock(rolloverHour: 4, utcOffset: (_) => const Duration(hours: 2));
      // 02:30 local (00:30 UTC) is still "yesterday"; 04:00 local (02:00 UTC) starts a new day.
      final a = DateTime.utc(2024, 3, 2, 0, 30);
      final b = DateTime.utc(2024, 3, 2, 1, 59);
      final c = DateTime.utc(2024, 3, 2, 2, 0);
      expect(clock.dayIndex(a), clock.dayIndex(b));
      expect(clock.dayIndex(c), clock.dayIndex(a) + 1);
      expect(clock.dayStartMs(c), DateTime.utc(2024, 3, 2, 2).millisecondsSinceEpoch);
      expect(clock.dayEndMs(c), DateTime.utc(2024, 3, 3, 2).millisecondsSinceEpoch);
    });

    test('configurable rollover hour', () {
      final clock = DayClock(rolloverHour: 0, utcOffset: (_) => Duration.zero);
      expect(clock.dayStartMs(DateTime.utc(2024, 3, 2, 23)), DateTime.utc(2024, 3, 2).millisecondsSinceEpoch);
    });
  });

  group('leech', () {
    test('8th lapse suspends and tags the note; undo reverses it', () async {
      await e.addBasic(1, now: t0);
      final id = (await e.allCards()).single.id;
      var now = t0;
      Future<void> answer(int r) async {
        now = now.add(const Duration(days: 40));
        await e.review.review(cardId: id, rating: r, durationMs: 1, now: now);
      }

      await answer(4); // -> review
      for (var i = 0; i < 7; i++) {
        await answer(1); // lapse -> relearning
        await answer(3); // graduate back to review (relearning step then good)
        // after one Good in relearning with a single 10m step the card is review again
      }
      var card = (await e.db.select(e.db.cards).getSingle());
      expect(card.lapses, 7);
      expect(card.suspended, isFalse);
      await answer(1);
      card = await e.db.select(e.db.cards).getSingle();
      expect(card.lapses, 8);
      expect(card.suspended, isTrue);
      expect((await e.db.select(e.db.notes).getSingle()).tags.split(' '), contains('leech'));

      await e.review.undoLast(now: now.add(const Duration(minutes: 1)));
      card = await e.db.select(e.db.cards).getSingle();
      expect(card.lapses, 7);
      expect(card.suspended, isFalse);
      expect((await e.db.select(e.db.notes).getSingle()).tags, isNot(contains('leech')));
    });
  });

  test('every review stores duration, before-state and params id', () async {
    await e.addBasic(1, now: t0);
    final id = (await e.allCards()).single.id;
    await e.review.review(cardId: id, rating: 2, durationMs: 4321, now: t0);
    final l = await e.db.select(e.db.reviewLogs).getSingle();
    expect(l.durationMs, 4321);
    expect(l.stateBefore, 'new');
    expect(l.fsrsVersion, startsWith('fsrs6'));
    expect(l.paramsId, greaterThan(0));
  });
}
