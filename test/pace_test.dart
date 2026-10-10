import 'dart:convert';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/pace.dart';
import 'package:daily_learning/data/plan_service.dart';
import 'package:daily_learning/data/params_repo.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/stats_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// D55: the pace behind every "about N minutes" is the MEDIAN of recent answers, ordinary and problem cards apart.
/// (Reported: Today said "about 2 minutes" for one card and tomorrow "about 40 minutes" for 24: the mean of the
/// last 200 answers was 101 seconds because a few problem cards, worked out on paper, took minutes each.)
void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final imp = ImportService(db);
    await imp.commit(await imp.preview(jsonEncode({
      'domain': 'Bio',
      'cards': [
        for (var i = 0; i < 4; i++)
          {'type': 'basic', 'front': 'Question number $i here?', 'back': 'a', 'source_type': 'model_memory', 'confidence': 'high'}
      ]
    })));
    await db.customStatement("UPDATE note SET type = 'problem' WHERE id = (SELECT MAX(id) FROM note)");
    await ParamsRepo(db, SettingsRepo(db)).activeId(); // the answers below name a parameter set
  });
  tearDown(() => db.close());

  Future<void> log(int card, int ms, {int n = 1}) async {
    for (var k = 0; k < n; k++) {
      await db.customStatement(
          "INSERT INTO review_log (card_id, reviewed_at, rating, duration_ms, state_before, due_before, elapsed_days, scheduled_days, fsrs_version, params_id) "
          "VALUES ($card, ${DateTime.now().millisecondsSinceEpoch - (1000 - k)}, 3, $ms, 'review', 0, 1, 1, 'v', 1)");
    }
  }

  test('a few slow problem answers do not set the pace of ordinary cards (median, problems apart)', () async {
    final cards = [for (final c in await db.select(db.cards).get()) c.id];
    final problemCard = (await db.customSelect("SELECT c.id AS id FROM card c JOIN note n ON n.id = c.note_id WHERE n.type = 'problem'").getSingle()).read<int>('id');
    await log(cards.first, 12000, n: 150); // ordinary answers: 12 s
    await log(problemCard, 480000, n: 50); // problem answers: 8 minutes each
    // The old mean over the last 200 answers: (150 x 12 + 50 x 480) / 200 = 126 s. The median of ordinary answers:
    expect(await ordinarySeconds(db), closeTo(12, 1e-9));
    expect(await problemSeconds(db), closeTo(480, 1e-9));
    final s = await StatsService(db, SettingsRepo(db)).compute();
    expect(s.secondsPerCard, closeTo(12, 1e-9), reason: 'Today\'s "about N min" uses this');
    expect(s.tomorrow.secondsPerAnswer, closeTo(12, 1e-9));
    expect(s.tomorrow.secondsPerProblem, closeTo(480, 1e-9));
    // Looking ahead and the advice use the same pace.
    expect(await PlanService(db, SettingsRepo(db), ParamsRepo(db, SettingsRepo(db))).secondsPerReview(), closeTo(12, 1e-9));
  });

  test('too few answers: the defaults (10 s ordinary, 4 minutes for a problem); outliers are clamped', () async {
    expect(await ordinarySeconds(db), 10);
    expect(await problemSeconds(db), 240);
    final c = (await db.select(db.cards).get()).first.id;
    await log(c, 100, n: 30); // under half a second each: not answers a person gave
    expect(await ordinarySeconds(db), 10);
    await log(c, 900000, n: 30); // a quarter of an hour: clamped to the ceiling
    expect(await ordinarySeconds(db), 120);
  });

  test('an even number of answers takes the middle of the two middle ones', () async {
    final c = (await db.select(db.cards).get()).first.id;
    await log(c, 8000, n: 10);
    await log(c, 14000, n: 10);
    expect(await ordinarySeconds(db), closeTo(11, 1e-9));
  });
}
