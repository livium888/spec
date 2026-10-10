import 'package:drift/drift.dart';

import '../domain/day_clock.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';
import 'activity_cache.dart';
import 'db/database.dart';
import 'params_repo.dart';
import 'settings_repo.dart';

const kLeechThreshold = 8;

CardSnapshot snapshotOf(Card r) => CardSnapshot(
      id: r.id,
      state: CardState.fromDb(r.state),
      step: r.step,
      due: r.due,
      stability: r.stability,
      difficulty: r.difficulty,
      reps: r.reps,
      lapses: r.lapses,
      lastReview: r.lastReview,
    );

CardsCompanion companionOf(CardSnapshot s) => CardsCompanion(
      state: Value(s.state.dbValue),
      step: Value(s.step),
      due: Value(s.due),
      stability: Value(s.stability),
      difficulty: Value(s.difficulty),
      reps: Value(s.reps),
      lapses: Value(s.lapses),
      lastReview: Value(s.lastReview),
    );

class ReviewResult {
  const ReviewResult(this.logId, this.card, {this.becameLeech = false});
  final int logId;
  final CardSnapshot card;
  final bool becameLeech;
}

class Mismatch {
  const Mismatch(this.cardId, this.stored, this.replayed);
  final int cardId;
  final CardSnapshot stored;
  final CardSnapshot replayed;
  @override
  String toString() => 'card $cardId: stored=$stored replayed=$replayed';
}

/// ReviewCard, UndoReview, suspend, and RebuildCardsFromLog.
/// `review_log` is the source of truth; `card` scheduling fields are a cache.
/// One past answer of a card, for the "about this card" sheet.
class ReviewEntry {
  const ReviewEntry({required this.at, required this.rating, required this.elapsedDays, required this.scheduledDays, required this.durationMs});
  final int at, rating, durationMs;
  final double elapsedDays, scheduledDays;
}

/// A card's answers, newest first (at most [kHistoryShown]), with totals over all of them.
class CardHistory {
  const CardHistory({required this.entries, required this.total, required this.passed, required this.avgMs});
  final List<ReviewEntry> entries;
  final int total, passed, avgMs;
  double? get passRate => total == 0 ? null : passed / total;
}

const kHistoryShown = 8;

class ReviewService {
  ReviewService(this.db, this.settings, this.params);
  final AppDatabase db;
  final SettingsRepo settings;
  final ParamsRepo params;

  /// ReviewCard use case.
  Future<ReviewResult> review({
    required int cardId,
    required int rating,
    required int durationMs,
    DateTime? now,
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    return db.transaction(() async {
      final row = await (db.select(db.cards)..where((c) => c.id.equals(cardId))).getSingle();
      final before = snapshotOf(row);
      final note = await (db.select(db.notes)..where((n) => n.id.equals(row.noteId))).getSingle();
      final paramsId = await params.idForDomain(note.domainId, now: t);
      final scheduler = await params.schedulerFor(paramsId);

      final res = scheduler.review(before, rating, t);
      final after = applyRating(scheduler, before, rating, t);

      final logId = await db.into(db.reviewLogs).insert(ReviewLogsCompanion.insert(
            cardId: cardId,
            reviewedAt: t.millisecondsSinceEpoch,
            rating: rating,
            durationMs: Value(durationMs),
            stateBefore: before.state.dbValue,
            dueBefore: before.due,
            stabilityBefore: Value(before.stability),
            difficultyBefore: Value(before.difficulty),
            elapsedDays: res.elapsedDays,
            scheduledDays: res.scheduledDays,
            fsrsVersion: scheduler.version,
            paramsId: paramsId,
          ));
      await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(companionOf(after));

      // Leech: suspend + tag when lapses first reach the threshold.
      var leech = false;
      if (after.lapses >= kLeechThreshold && before.lapses < kLeechThreshold) {
        leech = true;
        await (db.update(db.cards)..where((c) => c.id.equals(cardId)))
            .write(const CardsCompanion(suspended: Value(true)));
        await _addTag(row.noteId, 'leech');
      }

      // Sibling burying: other cards of this note wait until the next day.
      final clock = await settings.dayClock();
      await (db.update(db.cards)
            ..where((c) => c.noteId.equals(row.noteId) & c.id.equals(cardId).not()))
          .write(CardsCompanion(buriedUntil: Value(clock.dayEndMs(t))));

      return ReviewResult(logId, after, becameLeech: leech);
    });
  }

  /// Answers given to one card (undone ones left out): the last few, plus totals.
  Future<CardHistory> history(int cardId) async {
    final rows = await (db.select(db.reviewLogs)
          ..where((l) => l.cardId.equals(cardId) & l.revokedAt.isNull())
          ..orderBy([(l) => OrderingTerm.desc(l.reviewedAt), (l) => OrderingTerm.desc(l.id)]))
        .get();
    final passed = rows.where((r) => r.rating > 1).length;
    final avg = rows.isEmpty ? 0 : rows.fold<int>(0, (a, r) => a + r.durationMs) ~/ rows.length;
    return CardHistory(
      entries: [
        for (final r in rows.take(kHistoryShown))
          ReviewEntry(at: r.reviewedAt, rating: r.rating, elapsedDays: r.elapsedDays, scheduledDays: r.scheduledDays, durationMs: r.durationMs),
      ],
      total: rows.length,
      passed: passed,
      avgMs: avg,
    );
  }

  /// Undo the most recent non-revoked answer. Returns the restored card, or
  /// null if there is nothing to undo.
  Future<CardSnapshot?> undoLast({DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    return db.transaction(() async {
      final last = await (db.select(db.reviewLogs)
            ..where((l) => l.revokedAt.isNull())
            ..orderBy([
              (l) => OrderingTerm.desc(l.reviewedAt),
              (l) => OrderingTerm.desc(l.id),
            ])
            ..limit(1))
          .getSingleOrNull();
      if (last == null) return null;

      await (db.update(db.reviewLogs)..where((l) => l.id.equals(last.id)))
          .write(ReviewLogsCompanion(revokedAt: Value(t.millisecondsSinceEpoch)));
      await ActivityCache(db, settings).onRevoked(last.id, last.reviewedAt);
      final restored = await rebuildCard(last.cardId);

      final card = await (db.select(db.cards)..where((c) => c.id.equals(last.cardId))).getSingle();
      // Undo a leech suspension caused by this answer.
      if (card.suspended && restored.lapses < kLeechThreshold) {
        final note = await (db.select(db.notes)..where((n) => n.id.equals(card.noteId))).getSingle();
        if (note.tags.split(' ').contains('leech')) {
          await (db.update(db.cards)..where((c) => c.id.equals(card.id)))
              .write(const CardsCompanion(suspended: Value(false)));
          await _removeTag(card.noteId, 'leech');
        }
      }
      // Unbury siblings unless another card of the note was answered today.
      final clock = await settings.dayClock();
      final dayStart = clock.dayStartMs(t);
      final others = await db.customSelect(
        'SELECT COUNT(*) AS n FROM review_log l JOIN card c ON c.id = l.card_id '
        'WHERE c.note_id = ? AND l.revoked_at IS NULL AND l.reviewed_at >= ?',
        variables: [Variable.withInt(card.noteId), Variable.withInt(dayStart)],
      ).getSingle();
      if (others.read<int>('n') == 0) {
        await (db.update(db.cards)..where((c) => c.noteId.equals(card.noteId)))
            .write(const CardsCompanion(buriedUntil: Value(null)));
      }
      return restored;
    });
  }

  Future<void> setSuspended(int cardId, bool suspended) =>
      (db.update(db.cards)..where((c) => c.id.equals(cardId)))
          .write(CardsCompanion(suspended: Value(suspended)));

  /// Mark a card's note to look at later (or take the mark off). Only the note's tags change.
  Future<void> setMarked(int noteId, bool marked) => marked ? _addTag(noteId, 'marked') : _removeTag(noteId, 'marked');

  // ---- RebuildCardsFromLog ------------------------------------------------

  /// Replay non-revoked logs for one card from its pristine state and write the
  /// result. Returns the rebuilt snapshot.
  Future<CardSnapshot> rebuildCard(int cardId) async {
    final replayed = await _replay(cardId);
    await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(companionOf(replayed));
    return replayed;
  }

  /// RebuildCardsFromLog use case: wipe scheduling fields of every card and
  /// replay. With `apply: false` it only reports mismatches (restore check).
  Future<List<Mismatch>> rebuildAll({bool apply = true}) async {
    final ids = await (db.selectOnly(db.cards)
          ..addColumns([db.cards.id])
          ..orderBy([OrderingTerm.asc(db.cards.id)]))
        .map((r) => r.read(db.cards.id)!)
        .get();
    final mismatches = <Mismatch>[];
    final schedulers = <int, Scheduler>{}; // one scheduler per parameter set, not one per answer
    const chunk = 400; // cards per round trip: a handful of queries instead of three per card
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final cardRows = await (db.select(db.cards).join([
        innerJoin(db.notes, db.notes.id.equalsExp(db.cards.noteId)),
      ])
            ..where(db.cards.id.isIn(part)))
          .get();
      final logs = await (db.select(db.reviewLogs)
            ..where((l) => l.cardId.isIn(part) & l.revokedAt.isNull())
            ..orderBy([(l) => OrderingTerm.asc(l.cardId), (l) => OrderingTerm.asc(l.reviewedAt), (l) => OrderingTerm.asc(l.id)]))
          .get();
      final byCard = <int, List<ReviewLog>>{};
      for (final l in logs) {
        byCard.putIfAbsent(l.cardId, () => []).add(l);
      }
      final updates = <(int, CardSnapshot)>[];
      for (final row in cardRows) {
        final stored = snapshotOf(row.readTable(db.cards));
        // A new card's `due` is its note's creation time (see ImportCards).
        var card = CardSnapshot(id: stored.id, due: row.readTable(db.notes).createdAt);
        for (final l in byCard[stored.id] ?? const <ReviewLog>[]) {
          final scheduler = schedulers[l.paramsId] ??= await params.schedulerFor(l.paramsId);
          card = applyRating(scheduler, card, l.rating, DateTime.fromMillisecondsSinceEpoch(l.reviewedAt, isUtc: true));
        }
        if (card != stored) mismatches.add(Mismatch(stored.id, stored, card));
        if (apply) updates.add((stored.id, card));
      }
      if (apply && updates.isNotEmpty) {
        await db.batch((b) {
          for (final (id, card) in updates) {
            b.update(db.cards, companionOf(card), where: (c) => c.id.equals(id));
          }
        });
      }
    }
    return mismatches;
  }

  Future<CardSnapshot> _replay(int cardId) async {
    final q = db.select(db.cards).join([
      innerJoin(db.notes, db.notes.id.equalsExp(db.cards.noteId)),
    ])
      ..where(db.cards.id.equals(cardId));
    final r = await q.getSingle();
    // A new card's `due` is its note's creation time (see ImportCards).
    var card = CardSnapshot(id: cardId, due: r.readTable(db.notes).createdAt);

    final logs = await (db.select(db.reviewLogs)
          ..where((l) => l.cardId.equals(cardId) & l.revokedAt.isNull())
          ..orderBy([(l) => OrderingTerm.asc(l.reviewedAt), (l) => OrderingTerm.asc(l.id)]))
        .get();
    for (final l in logs) {
      final scheduler = await params.schedulerFor(l.paramsId);
      card = applyRating(
          scheduler, card, l.rating, DateTime.fromMillisecondsSinceEpoch(l.reviewedAt, isUtc: true));
    }
    return card;
  }

  // ---- tags ----------------------------------------------------------------

  Future<void> _addTag(int noteId, String tag) async {
    final n = await (db.select(db.notes)..where((t) => t.id.equals(noteId))).getSingle();
    final tags = n.tags.split(' ').where((e) => e.isNotEmpty).toSet()..add(tag);
    await (db.update(db.notes)..where((t) => t.id.equals(noteId)))
        .write(NotesCompanion(tags: Value(tags.join(' '))));
  }

  Future<void> _removeTag(int noteId, String tag) async {
    final n = await (db.select(db.notes)..where((t) => t.id.equals(noteId))).getSingle();
    final tags = n.tags.split(' ').where((e) => e.isNotEmpty && e != tag);
    await (db.update(db.notes)..where((t) => t.id.equals(noteId)))
        .write(NotesCompanion(tags: Value(tags.join(' '))));
  }
}

// Convenience for tests / callers needing a clock.
Future<DayClock> clockOf(SettingsRepo s) => s.dayClock();
