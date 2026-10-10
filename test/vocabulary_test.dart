import 'dart:io';

import 'package:daily_learning/app/launch_service.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/domain/card_memory.dart';
import 'package:daily_learning/domain/memory_summary.dart';
import 'package:daily_learning/domain/models.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import 'launch_test.dart' show boot, seeded;
import 'screenshots/screens_test.dart' show settle;

/// D52: one set of words for where a card stands, and no jargon from other tools in what the learner reads.
class _Review implements LaunchInbox {
  bool done = false;
  @override
  Future<LaunchRoute?> take() async {
    if (done) return null;
    done = true;
    return LaunchRoute.review;
  }
}

class _NoNote implements NotificationLaunch {
  const _NoNote();
  @override
  Future<bool> openedFromReminder() async => false;
}

void main() {
  test('the stage words are one fixed set, each with a meaning in the same words', () {
    expect([for (final b in MemoryBucket.values) b.label], ['New', 'Learning', 'Growing', 'Fading', 'Long-term', 'Retired', 'Paused']);
    expect({for (final b in MemoryBucket.values) b.meaning}.length, MemoryBucket.values.length);
    expect(MemoryBucket.longTerm.meaning, contains('three weeks'));
    expect(MemoryBucket.fading.meaning, contains('overdue'));
  });

  test('the card sheet explains a card in the stage word Progress uses', () {
    expect(explainState(CardState.review, stage: MemoryBucket.longTerm).title, 'Long-term');
    expect(explainState(CardState.review, stage: MemoryBucket.fading).title, 'Fading');
    expect(explainState(CardState.review, stage: MemoryBucket.growing).title, 'Growing');
    expect(explainState(CardState.review).title, 'Growing');
    expect(explainState(CardState.relearning).title, 'Learning again');
    expect(explainState(CardState.learning).title, 'Learning');
    for (final s in CardState.values) {
      expect(explainState(s).body, isNot(contains('Review,')), reason: 'the old state name must not leak back in');
    }
  });

  test('nothing the learner reads uses words from other tools: leech, memory model, mature, young, forgotten (as a state), to review', () {
    final banned = RegExp(r"(Memory model|memory model|leech cards|a leech|\(leeches\)|[Hh]ard cards \(|'Forgotten'|'To review'|\bMature\b|\bYoung\b)");
    final literal = RegExp(r"'(?:[^'\\]|\\.)*'");
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('database.g.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final t = lines[i].trimLeft();
        if (t.startsWith('//')) continue; // comments and doc comments are for developers
        if (literal.allMatches(lines[i]).any((m) => banned.hasMatch(m[0]!))) hits.add('${f.path}:${i + 1}: ${t.length > 90 ? t.substring(0, 90) : t}');
      }
    }
    expect(hits, isEmpty, reason: 'words to replace (D52):\n${hits.join('\n')}');
  });

  testWidgets('the tag on a card in the review says Growing, Long-term or Fading (the Progress words), not "Review"', (t) async {
    Future<String> tagFor({required double stability, required int daysAgo}) async {
      final db = await seeded(t, cards: 1);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await t.runAsync(() => db.customStatement(
          "UPDATE card SET state = 'review', stability = ?, difficulty = 5, last_review = ?, reps = 5, due = ?",
          [stability, now - daysAgo * 86400000, now - 1000]));
      await boot(t, db, [launchInboxProvider.overrideWithValue(_Review()), notificationLaunchProvider.overrideWithValue(const _NoNote())]);
      await settle(t, rounds: 4);
      final words = ['Growing', 'Long-term', 'Fading', 'Review', 'Learning', 'New'];
      final found = [for (final w in words) if (find.text(w).evaluate().isNotEmpty) w];
      await t.pumpWidget(const SizedBox());
      return found.join(',');
    }

    expect(await tagFor(stability: 5, daysAgo: 2), 'Growing');
    expect(await tagFor(stability: 80, daysAgo: 3), 'Long-term');
    expect(await tagFor(stability: 30, daysAgo: 400), 'Fading');
  });
}
