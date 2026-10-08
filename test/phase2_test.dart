import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/fsrs_scheduler.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/plan_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/retire_service.dart';
import 'package:daily_learning/domain/retire.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

void main() {
  late Env e;
  setUp(() => e = Env());

  /// Gives card [id] a mature, well-answered history (state only; not for replay checks).
  Future<void> mature(int id, {double stability = 900, int reps = 12, int lapses = 0}) =>
      (e.db.update(e.db.cards)..where((c) => c.id.equals(id))).write(CardsCompanion(
        state: const Value('review'),
        stability: Value(stability),
        difficulty: const Value(3.0),
        reps: Value(reps),
        lapses: Value(lapses),
        due: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        lastReview: Value(DateTime.now().toUtc().subtract(const Duration(days: 900)).millisecondsSinceEpoch),
      ));

  group('per-subject target recall', () {
    test('a subject with its own target gets its own params row (same weights), reused, and followed after a fit', () async {
      await e.addBasic(1, domain: 'Bio');
      await e.addBasic(1, domain: 'Chem');
      final doms = await e.db.select(e.db.domains).get();
      final bio = doms.firstWhere((d) => d.name == 'Bio').id, chem = doms.firstWhere((d) => d.name == 'Chem').id;
      final learn = LearnService(e.db, e.settings, QueueService(e.db, e.settings));
      final global = await e.params.activeId();
      expect(await e.params.idForDomain(bio), global); // no own target
      await learn.setSubjectRetention(bio, 0.80);
      final own = await e.params.idForDomain(bio);
      expect(own, isNot(global));
      expect(await e.params.idForDomain(bio), own); // reused, not re-inserted
      expect(await e.params.idForDomain(chem), global);
      expect((await e.params.configFor(own)).desiredRetention, 0.80);
      expect((await e.params.configFor(own)).weights, (await e.params.configFor(global)).weights);
      await learn.setSubjectRetention(bio, 0.80 + 1e-12); // same target (rounded): still the same row
      expect(await e.params.idForDomain(bio), own);
      await learn.setSubjectRetention(bio, null);
      expect(await e.params.idForDomain(bio), global);
      await learn.setSubjectRetention(bio, 0.5); // clamped to the allowed range
      expect((await e.db.select(e.db.domains).get()).firstWhere((d) => d.id == bio).retention, 0.70);
    });

    test('a lower target gives longer gaps for the same answers, and replay == live still holds', () async {
      await e.addBasic(1, domain: 'Bio');
      await e.addBasic(1, domain: 'Chem');
      final learn = LearnService(e.db, e.settings, QueueService(e.db, e.settings));
      final bio = (await e.db.select(e.db.domains).get()).firstWhere((d) => d.name == 'Bio').id;
      await learn.setSubjectRetention(bio, 0.75);
      final cards = await e.db.select(e.db.cards).get();
      var t = DateTime.utc(2025, 1, 1, 9);
      for (var round = 0; round < 7; round++) {
        for (final c in cards) {
          // each card is answered Good whenever it is due (or at the 10-minute learning step)
          final fresh = await (e.db.select(e.db.cards)..where((x) => x.id.equals(c.id))).getSingle();
          final due = DateTime.fromMillisecondsSinceEpoch(fresh.due, isUtc: true);
          await e.review.review(cardId: c.id, rating: 3, durationMs: 800, now: due.isAfter(t) ? due : t);
        }
        t = t.add(const Duration(minutes: 11));
      }
      final after = await e.db.select(e.db.cards).get();
      final bioCard = after.firstWhere((c) => c.id == cards.first.id), chemCard = after.firstWhere((c) => c.id != cards.first.id);
      // find which card belongs to which domain
      final noteDomain = {for (final n in await e.db.select(e.db.notes).get()) n.id: n.domainId};
      final bioC = after.firstWhere((c) => noteDomain[c.noteId] == bio);
      final chemC = after.firstWhere((c) => noteDomain[c.noteId] != bio);
      expect(bioC.state, 'review');
      expect(chemC.state, 'review');
      final gapBio = bioC.due - bioC.lastReview!, gapChem = chemC.due - chemC.lastReview!;
      expect(gapBio, greaterThan(gapChem), reason: 'bio ${gapBio / 86400000} d vs chem ${gapChem / 86400000} d');
      final logs = await e.db.select(e.db.reviewLogs).get();
      expect(logs.map((l) => l.paramsId).toSet().length, 2); // each subject's reviews recorded its own params
      expect(await e.review.rebuildAll(apply: false), isEmpty);
      expect([bioCard, chemCard], isNotEmpty);
    });
  });

  group('retire mastered cards', () {
    test('criteria: long stability, enough reviews, at most one lapse; counts and savings', () async {
      await e.addBasic(6);
      final ids = [for (final c in await e.db.select(e.db.cards).get()) c.id];
      await mature(ids[0]); // yes
      await mature(ids[1], stability: 400); // under 2 years
      await mature(ids[2], reps: 3); // too few reviews
      await mature(ids[3], lapses: 3); // lapsed too often
      await mature(ids[4], stability: 1800); // yes
      final svc = RetireService(e.db);
      final s = await svc.summary(const RetireCriteria(years: 2), secondsPerReview: 12);
      expect(s.cards, 2);
      expect(s.reviewsSavedPerYear, closeTo(365 / 900 + 365 / 1800, 1e-9));
      expect(s.minutesSavedPerYear, closeTo(s.reviewsSavedPerYear * 12 / 60, 1e-9));
      expect((await svc.summary(const RetireCriteria(years: 1))).cards, 3); // 400 days now qualifies
      expect((await svc.summary(const RetireCriteria(years: 3))).cards, 1); // only 1800
    });

    test('retire takes cards out of reviews without touching scheduling; bring-back restores exactly', () async {
      await e.addBasic(3);
      final ids = [for (final c in await e.db.select(e.db.cards).get()) c.id];
      for (final id in ids) {
        await mature(id);
      }
      final before = await e.allCards();
      final svc = RetireService(e.db);
      expect(await svc.retireMastered(const RetireCriteria(years: 2)), 3);
      expect(await svc.retiredCount(), 3);
      expect((await e.queue.build()).reviews, isEmpty); // nothing to review: they are retired
      expect(await e.allCards(), before); // scheduling fields untouched
      expect(await svc.retireMastered(const RetireCriteria(years: 2)), 0); // idempotent

      final list = await svc.retired();
      expect(list, hasLength(3));
      expect(list.first.title, contains('Question number'));
      expect(list.first.domainName, 'Bio');

      await svc.restore(list.first.cardId);
      expect(await svc.retiredCount(), 2);
      expect((await e.queue.build()).reviews.length, 1);
      expect(await svc.restoreAll(), 2);
      expect(await e.allCards(), before);
      expect((await e.queue.build()).reviews.length, 3);
    });

    test('a card suspended for another reason (leech) is not retired or restored by this feature', () async {
      await e.addBasic(2);
      final ids = [for (final c in await e.db.select(e.db.cards).get()) c.id];
      await mature(ids[0]);
      await mature(ids[1]);
      await e.review.setSuspended(ids[1], true); // manual suspend
      final svc = RetireService(e.db);
      expect(await svc.retireMastered(const RetireCriteria(years: 2)), 1);
      expect(await svc.restoreAll(), 1);
      final c = await (e.db.select(e.db.cards)..where((x) => x.id.equals(ids[1]))).getSingle();
      expect(c.suspended, isTrue); // still suspended by the learner
    });

    test('real history: retiring changes nothing the log can see (replay == live)', () async {
      await e.addBasic(2);
      var t = DateTime.utc(2025, 1, 1, 9);
      for (final c in await e.db.select(e.db.cards).get()) {
        for (var i = 0; i < 8; i++) {
          final fresh = await (e.db.select(e.db.cards)..where((x) => x.id.equals(c.id))).getSingle();
          final due = DateTime.fromMillisecondsSinceEpoch(fresh.due, isUtc: true);
          t = due.isAfter(t) ? due : t.add(const Duration(minutes: 11));
          await e.review.review(cardId: c.id, rating: 3, durationMs: 800, now: t);
        }
      }
      final svc = RetireService(e.db);
      expect(await svc.retireMastered(const RetireCriteria(years: 0)), greaterThan(0));
      expect(await e.review.rebuildAll(apply: false), isEmpty);
    });
  });

  group('PlanService', () {
    test('forecast from a real library: reads a sample, uses the learner pace and budget, in the isolate-safe function', () async {
      await e.addBasic(40);
      for (final c in await e.db.select(e.db.cards).get()) {
        await mature(c.id, stability: 60);
      }
      await e.settings.set('daily_minutes', '15');
      final svc = PlanService(e.db, e.settings, e.params, runner: (r) async => computePlan(PlanRequest(
          base: r.base, secondsPerReview: r.secondsPerReview, budgetMinutes: r.budgetMinutes, newPerDay: r.newPerDay, seeds: 1)));
      final r = await svc.plan(newPerDay: 12);
      expect(r.newPerDay, 12);
      expect(r.budgetMinutes, 15);
      expect(r.rows.map((x) => x.label), ['in 6 months', 'in 1 year', 'in 2 years', 'in 5 years', 'in 10 years']);
      expect(r.rows.last.minutesPerDay, greaterThan(r.rows.first.minutesPerDay * 0.5));
      final base = await svc.baseInput(newPerDay: 0, horizonDays: 100);
      expect(base.existing, hasLength(40));
      expect(base.existingWeight, 1);
      expect(base.existing.first.stability, 60);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('pace falls back to the setting until there is history, then follows what really happened', () async {
      final svc = PlanService(e.db, e.settings, e.params);
      expect(await svc.currentPace(), 10);
      await e.settings.set('new_per_day', '7');
      expect(await svc.currentPace(), 7);
      await e.addBasic(30);
      final now = DateTime.utc(2025, 3, 1, 12);
      for (final c in await e.db.select(e.db.cards).get()) {
        await e.review.review(cardId: c.id, rating: 3, durationMs: 900, now: now.subtract(Duration(days: c.id % 20)));
      }
      expect(await svc.currentPace(now: now), closeTo(30 / 28, 1e-9));
    });

    test('a sampled library: weights add up to the real count', () async {
      await e.addBasic(10);
      for (final c in await e.db.select(e.db.cards).get()) {
        await mature(c.id);
      }
      final svc = PlanService(e.db, e.settings, e.params);
      final b = await svc.baseInput(newPerDay: 1, horizonDays: 50);
      expect(b.existing.length * b.existingWeight, closeTo(10, 1e-9));
      expect(fsrs6DefaultWeights.length, 21);
    });
  });
}
