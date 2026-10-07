import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/study_card.dart';
import 'db/database.dart';
import 'review_service.dart';
import 'settings_repo.dart';

/// BuildDailyQueue use case.
class QueueService {
  QueueService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  Future<DailyQueue> build({DateTime? now, int? domainId}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final nowMs = t.millisecondsSinceEpoch;
    final clock = await settings.dayClock();
    final dayEnd = clock.dayEndMs(t);
    final dayStart = clock.dayStartMs(t);

    final base = await settings.getInt(SettingsRepo.newPerDay, 10);
    final divisor = await settings.getInt(SettingsRepo.backlogDivisor, 25);

    Future<List<StudyCard>> fetch(Expression<bool> where, List<OrderingTerm> order, {int? limit}) async {
      final q = db.select(db.cards).join([
        innerJoin(db.notes, db.notes.id.equalsExp(db.cards.noteId)),
      ])
        ..where(where &
            db.cards.suspended.equals(false) &
            (db.cards.buriedUntil.isNull() | db.cards.buriedUntil.isSmallerOrEqualValue(nowMs)) &
            (domainId == null ? const Constant(true) : db.notes.domainId.equals(domainId)))
        ..orderBy(order);
      if (limit != null) q.limit(limit);
      return [for (final r in await q.get()) _study(r.readTable(db.cards), r.readTable(db.notes))];
    }

    final learning = await fetch(
      db.cards.state.isIn(['learning', 'relearning']) & db.cards.due.isSmallerOrEqualValue(nowMs),
      [OrderingTerm.asc(db.cards.due), OrderingTerm.asc(db.cards.id)],
    );
    final reviews = await fetch(
      db.cards.state.equals('review') & db.cards.due.isSmallerThanValue(dayEnd),
      [OrderingTerm.asc(db.cards.due), OrderingTerm.asc(db.cards.id)],
    );
    final dueReviewCount = reviews.length;

    final introduced = await _introducedToday(dayStart, domainId);
    final limit = backlogAdjustedNewLimit(base, dueReviewCount, divisor: divisor);
    final remaining = (limit - introduced).clamp(0, limit);
    final newCards = remaining == 0
        ? <StudyCard>[]
        : await fetch(
            db.cards.state.equals('new'),
            [OrderingTerm.asc(db.notes.createdAt), OrderingTerm.asc(db.cards.id)],
            limit: remaining * 4, // headroom: sibling filtering may drop some
          );

    // Only one card per note in the queue (sibling burying, also within a session).
    final seen = <int>{};
    List<StudyCard> dedupe(List<StudyCard> xs) =>
        [for (final c in xs) if (seen.add(c.noteId)) c];
    final l = dedupe(learning);
    final r = dedupe(reviews);
    final n = dedupe(newCards).take(remaining).toList();

    // Next not-yet-due learning card, for the "come back at" message.
    final futureQ = db.selectOnly(db.cards)
      ..addColumns([db.cards.due.min()])
      ..where(db.cards.state.isIn(['learning', 'relearning']) &
          db.cards.due.isBiggerThanValue(nowMs) &
          db.cards.suspended.equals(false));
    final nextLearning = await futureQ.map((x) => x.read(db.cards.due.min())).getSingle();

    return DailyQueue(
      learning: l,
      reviews: r,
      newCards: n,
      dueReviewCount: dueReviewCount,
      newLimit: limit,
      newIntroducedToday: introduced,
      nextLearningDue: nextLearning,
    );
  }

  /// Fetch one card with its note (used by undo to re-show the undone card).
  Future<StudyCard?> cardById(int id) async {
    final q = db.select(db.cards).join([
      innerJoin(db.notes, db.notes.id.equalsExp(db.cards.noteId)),
    ])
      ..where(db.cards.id.equals(id));
    final r = await q.getSingleOrNull();
    return r == null ? null : _study(r.readTable(db.cards), r.readTable(db.notes));
  }

  Future<int> _introducedToday(int dayStart, int? domainId) async {
    final rows = await db.customSelect(
      'SELECT COUNT(DISTINCT l.card_id) AS n FROM review_log l '
      'JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id '
      "WHERE l.revoked_at IS NULL AND l.state_before = 'new' AND l.reviewed_at >= ? "
      'AND (? IS NULL OR n.domain_id = ?)',
      variables: [
        Variable.withInt(dayStart),
        Variable<int>(domainId),
        Variable<int>(domainId),
      ],
    ).getSingle();
    return rows.read<int>('n');
  }

  StudyCard _study(Card c, Note n) => StudyCard(
        snapshot: snapshotOf(c),
        noteId: n.id,
        domainId: n.domainId,
        noteType: n.type,
        fields: jsonDecode(n.fieldsJson) as Map<String, dynamic>,
        tags: n.tags.split(' ').where((e) => e.isNotEmpty).toList(),
        ord: c.ord,
        suspended: c.suspended,
      );
}
