import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/study_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

void main() {
  group('the learner\'s own daily number is used as it is', () {
    late Env e;
    setUp(() => e = Env());

    Future<void> manyDue(int n) async {
      // (one import takes at most 200 cards)
      await e.addBasic(n ~/ 2, domain: 'Bio');
      await e.addBasic(n - n ~/ 2, domain: 'Phys');
      await e.db.customStatement("UPDATE card SET state='review', stability=3, difficulty=5, reps=3, due=1");
    }

    test('10,000 is accepted by the queue exactly, even with hundreds of reviews due (no hidden shrink by default)', () async {
      await e.settings.set(SettingsRepo.newPerDay, '10000');
      await manyDue(300);
      await e.addBasic(5, domain: 'Chem');
      final q = await e.queue.build();
      expect(q.dueReviewCount, 300);
      expect(q.newLimit, 10000);
    });

    test('the shrink is opt-in: when switched on it works as before', () async {
      await e.settings.set(SettingsRepo.newPerDay, '10');
      await e.settings.set(SettingsRepo.backlogDivisor, '25');
      await manyDue(300);
      expect((await e.queue.build()).newLimit, 10);
      await e.settings.set(SettingsRepo.backlogShrink, '1');
      expect((await e.queue.build()).newLimit, 0); // 10 - 300 ~/ 25, floored at 0
    });

    test('advice only advises: it reports the limit left, and says the limit is the learner\'s own setting', () {
      const a = StudyAdvisor();
      AdviceInput inp({int introduced = 0, int limit = 10000, bool shrink = false}) => AdviceInput(
            dueToday: 0, avgSecondsPerReview: 10, budgetMinutes: 20, spentSecondsToday: 0, newIntroducedToday: introduced,
            newLimit: limit, upcoming7dReviews: 0, desiredRetention: 0.9, retention30d: null, answers30d: 0,
            lapseRate30d: null, leechCount: 0, daysSinceLastSession: null, limitShrinks: shrink);
      final big = a.advise(inp());
      expect(big.dailyLimitLeft, 10000);
      expect(big.limitReached, isFalse);
      final done = a.advise(inp(introduced: 10000));
      expect(done.limitReached, isTrue);
      expect(done.reasons.join(' '), contains('today\'s limit (10000)'));
      final zero = a.advise(inp(limit: 0));
      expect(zero.limitReached, isTrue);
      expect(zero.reasons.join(' '), contains('your own setting'));
      expect(zero.reasons.join(' '), isNot(contains('shrinks automatically')));
      final shrunk = a.advise(inp(introduced: 3, limit: 3, shrink: true));
      expect(shrunk.reasons.join(' '), contains('You switched on shrinking the limit'));
    });
  });

  group('how many cards one prompt asks for', () {
    test('"cards per prompt" is used, and a tight time budget with a big backlog does not shrink it', () async {
      final e = Env();
      final out = OutlineService(e.db);
      await out.commit(await out.preview('{"domain":"Bio","items":[{"title":"Big topic","target_cards":30}]}'));
      await e.settings.set(SettingsRepo.cardsPerPrompt, '25');
      await e.settings.set(SettingsRepo.dailyMinutes, '5');
      await e.addBasic(150, domain: 'Chem');
      await e.addBasic(150, domain: 'Phys');
      await e.db.customStatement("UPDATE card SET state='review', stability=3, difficulty=5, reps=3, due=1");
      final learn = LearnService(e.db, e.settings, QueueService(e.db, e.settings));
      final v = await learn.view();
      final top = v.plan.options.first;
      expect(top.item.title, 'Big topic');
      expect(top.count, 25);
      await e.settings.set(SettingsRepo.cardsPerPrompt, '10');
      expect((await learn.view()).plan.options.first.count, 10);
      await e.db.close();
    });
  });
}
