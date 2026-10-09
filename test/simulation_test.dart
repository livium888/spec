// A month-long simulated learner: random imports (cards, problem families, foundation cards), random
// answers, undo, many days. After every step the queue must obey its rules, and at the end the card
// states must equal a replay of the review log.
import 'dart:convert';
import 'dart:math';

import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

Map<String, dynamic> problem(int n) => {
      'statement': 'Problem $n: a body falls ${n + 3} m. Speed?',
      'steps': ['Step A of $n', 'Step B of $n', 'Step C of $n', 'Step D of $n'],
      'answer': '${n + 1} m/s',
      'answer_value': (n + 1).toDouble(),
      'answer_expr': '${n + 1}',
      'variants': [
        {'statement': 'Variant 1 of problem $n', 'answer': 'x'},
        {'statement': 'Variant 2 of problem $n', 'answer': 'y'},
      ],
    };

void main() {
  for (final seed in [11, 12, 13, 14, 15, 16, 17, 18]) {
    test('simulation, seed $seed: queue rules hold every step and the log replays to the same state', () async {
      final r = Random(seed);
      final e = Env();
      addTearDown(e.db.close);
      await e.settings.set(SettingsRepo.newPerDay, '${3 + r.nextInt(5)}');
      final problemLimit = 1 + r.nextInt(4);
      await e.settings.set(SettingsRepo.problemsPerDay, '$problemLimit');
      final start = DateTime.utc(2025, 3, 3, 8);
      final introducedOn = <String, int>{}; // day -> new problem cards first answered
      var problemSeq = 0;
      var cardSeq = 0;

      Future<void> importSome(DateTime at) async {
        final cards = [
          for (var i = 0; i < 3 + r.nextInt(4); i++)
            {'type': 'basic', 'front': 'Seed $seed card ${cardSeq++}?', 'back': 'A', 'source_type': 'model_memory', 'confidence': 'high'}
        ];
        final problems = r.nextInt(3) == 0 ? [problem(seed * 1000 + problemSeq++)] : <Map<String, dynamic>>[];
        await e.import.commit(
            await e.import.preview(jsonEncode({'domain': 'Physics', 'syllabus_item': 'Topic ${r.nextInt(3)}', 'cards': cards, 'problems': problems})),
            now: at);
        if (r.nextInt(3) == 0) {
          final notes = await e.db.select(e.db.notes).get();
          final target = notes[r.nextInt(notes.length)];
          if (!target.fieldsJson.contains('variant_of')) {
            await e.import.commit(
                await e.import.preview(jsonEncode({
                  'domain': 'Physics',
                  'foundation_of': target.id,
                  'cards': [
                    for (var i = 0; i < 2; i++)
                      {'type': 'basic', 'front': 'Foundation $seed ${cardSeq++}?', 'back': 'A', 'source_type': 'model_memory', 'confidence': 'high'}
                  ],
                })),
                now: at);
          }
        }
      }

      for (var day = 0; day < 40; day++) {
        final dayStart = start.add(Duration(days: day));
        if (day % 3 == 0) await importSome(dayStart);
        var now = dayStart;
        final seenToday = <int>{};
        for (var step = 0; step < 25; step++) {
          final q = await e.queue.build(now: now);
          final ids = q.ordered.map((c) => c.id).toList();
          expect(ids.toSet().length, ids.length, reason: 'a card twice in the queue (day $day)');
          expect(q.ordered.map((c) => c.noteId).toSet().length, ids.length, reason: 'two cards of one note in the queue (day $day)');
          final newProblems = q.newCards.where((c) => c.isProblem).length;
          expect(newProblems, lessThanOrEqualTo(problemLimit), reason: 'more new problems than the daily budget');
          expect(q.newCards.where((c) => c.fields['foundation_of'] != null).length, lessThanOrEqualTo(kMaxFoundationPerDay));
          final next = q.next;
          if (next == null) break;
          // Answer it: mostly Good, sometimes Again, Hard or Easy.
          final roll = r.nextInt(10);
          final rating = roll < 1 ? 1 : (roll < 2 ? 2 : (roll < 8 ? 3 : 4));
          now = now.add(Duration(minutes: 1 + r.nextInt(25)));
          final wasNew = next.snapshot.state.dbValue == 'new';
          await e.review.review(cardId: next.id, rating: rating, durationMs: 4000, now: now);
          if (wasNew && next.isProblem) {
            final key = '$day';
            introducedOn[key] = (introducedOn[key] ?? 0) + 1;
            expect(introducedOn[key]!, lessThanOrEqualTo(problemLimit), reason: 'daily problem budget exceeded on day $day');
          }
          seenToday.add(next.id);
          if (r.nextInt(12) == 0) {
            final undone = await e.review.undoLast(now: now); // a slip, taken back
            if (undone != null && wasNew && next.isProblem) introducedOn['$day'] = introducedOn['$day']! - 1;
          }
        }
      }

      // Unlocking: no problem level was first answered before the level that unlocks it was answered well.
      final logs = await e.db.customSelect(
        '''SELECT l.id AS id, l.rating AS rating, l.reviewed_at AS at, c.id AS card, c.ord AS ord, n.id AS note, n.fields_json AS f
           FROM review_log l JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id
           WHERE n.type = 'problem' AND l.revoked_at IS NULL ORDER BY l.reviewed_at, l.id''',
      ).get();
      final firstAnswer = <int, int>{}; // card -> time of its first live answer
      for (final l in logs) {
        firstAnswer.putIfAbsent(l.read<int>('card'), () => l.read<int>('at'));
      }
      bool answeredWell(int note, int ord, int minRating, int before) => logs.any((l) =>
          l.read<int>('note') == note && l.read<int>('ord') == ord && l.read<int>('rating') >= minRating && l.read<int>('at') < before);
      for (final l in logs) {
        final card = l.read<int>('card');
        if (firstAnswer[card] != l.read<int>('at')) continue;
        final ord = l.read<int>('ord'), note = l.read<int>('note'), at = l.read<int>('at');
        final variantOf = int.tryParse('${(jsonDecode(l.read<String>('f')) as Map)['variant_of'] ?? ''}');
        if (variantOf != null) {
          expect(answeredWell(variantOf, 2, 3, at), isTrue, reason: 'variant of $variantOf answered before level 3 was');
        } else if (ord > 0) {
          final ok = answeredWell(note, ord - 1, 3, at) || (ord >= 2 && answeredWell(note, ord - 2, 4, at));
          expect(ok, isTrue, reason: 'level ${ord + 1} of note $note answered before it was unlocked');
        }
      }

      // The cards are a cache of the log: a replay must give the very same state.
      final mismatches = await e.review.rebuildAll(apply: false);
      expect(mismatches, isEmpty, reason: 'replay differs from live: ${mismatches.take(3)}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
