/// What the app can say about ONE card's memory: plain-language state, and the three numbers
/// the FSRS model keeps for it (the same three quantities as SuperMemo's "three component model of
/// memory": stability, retrievability, difficulty; verify against current docs). Pure, no Flutter.
library;

import 'fsrs_model.dart' show retrievability;
import 'memory_summary.dart' show MemoryBucket, MemoryBucketWords;
import 'models.dart';

const _dayMs = 86400000;

/// A short title and a plain explanation of a card state. [learningSteps] and [relearningSteps]
/// are the learner's own step lengths in minutes.
({String title, String body}) explainState(CardState s,
    {List<int> learningSteps = const [1, 10], List<int> relearningSteps = const [10], MemoryBucket? stage}) {
  String steps(List<int> m) => m.isEmpty ? 'a few minutes' : m.map((x) => x >= 60 && x % 60 == 0 ? '${x ~/ 60} h' : '$x min').join(', then ');
  return switch (s) {
    CardState.newCard => (
        title: 'New',
        body: 'You have not seen this card yet. When you first answer it, it starts a short learning phase.',
      ),
    CardState.learning => (
        title: 'Learning',
        body: 'You are still learning this card, so it comes back after minutes, not days: ${steps(learningSteps)}. '
            'Answer "Good" at each step and it starts growing: the gaps stretch to days, then weeks, then months.',
      ),
    CardState.review => (
        // The stage (Growing, Long-term or Fading) when the caller knows it; the words are the ones Progress uses.
        title: stage != null && stage != MemoryBucket.fresh && stage != MemoryBucket.learning ? stage.label : 'Growing',
        body: 'You know this card. It comes back just before you would probably forget it, and every success makes the next gap longer.'
            '${stage == MemoryBucket.longTerm ? ' It is long-term: stable for three weeks or more, and still likely to be recalled.' : ''}'
            '${stage == MemoryBucket.fading ? ' It is fading: it was stable, but it is overdue, so your chance of recalling it is dropping. Answering it now brings it back.' : ''}',
      ),
    CardState.relearning => (
        title: 'Learning again',
        body: 'You knew this card, then forgot it. It is back on short steps (${steps(relearningSteps)}). Once you remember it, it grows again, with a shorter gap than before.',
      ),
  };
}

/// "Easy", "Average" or "Hard" for FSRS difficulty (1 to 10).
String difficultyWord(double d) => d < 4 ? 'Easy for you' : (d < 7 ? 'Average' : 'Hard for you');

class MemoryStats {
  const MemoryStats({this.stabilityDays, this.difficulty, this.recallNow, required this.reps, required this.lapses, required this.state, required this.dueMs, this.lastReviewMs});
  final double? stabilityDays; // days after which the chance of recall falls to 90%
  final double? difficulty; // 1 easy .. 10 hard
  final double? recallNow; // 0..1, model estimate right now
  final int reps, lapses;
  final CardState state;
  final int dueMs;
  final int? lastReviewMs;

  bool get hasModel => stabilityDays != null && lastReviewMs != null;
}

/// The model's numbers for [c] at [nowMs], with the FSRS weights [w] in use for the card.
MemoryStats memoryStats(CardSnapshot c, List<double> w, int nowMs) {
  final s = c.stability;
  final last = c.lastReview;
  double? r;
  if (s != null && s > 0 && last != null && w.length > 20 && c.state != CardState.newCard) {
    final dt = ((nowMs - last) / _dayMs).clamp(0.0, 100000.0);
    r = retrievability(w, dt, s).clamp(0.0, 1.0);
  }
  return MemoryStats(
    stabilityDays: s,
    difficulty: c.difficulty,
    recallNow: r,
    reps: c.reps,
    lapses: c.lapses,
    state: c.state,
    dueMs: c.due,
    lastReviewMs: last,
  );
}

/// Points of the predicted forgetting curve: (days since the last answer, chance of recall).
/// [horizonDays] is the right edge; at least [points] points, evenly spaced.
List<(double, double)> forgettingCurve(List<double> w, double stability, double horizonDays, {int points = 40}) {
  if (stability <= 0 || horizonDays <= 0 || w.length <= 20) return const [];
  return [
    for (var i = 0; i <= points; i++)
      (horizonDays * i / points, retrievability(w, horizonDays * i / points, stability).clamp(0.0, 1.0)),
  ];
}

/// "in 3 days", "today", "5 days ago": a due date in words, from [nowMs].
String dueWords(int dueMs, int nowMs) {
  final diff = dueMs - nowMs;
  final days = (diff.abs() / _dayMs).round();
  if (diff.abs() < 3600000) return 'now';
  if (diff.abs() < _dayMs) {
    final h = (diff.abs() / 3600000).round();
    return diff > 0 ? 'in $h h' : '$h h ago';
  }
  return diff > 0 ? 'in $days ${days == 1 ? 'day' : 'days'}' : '$days ${days == 1 ? 'day' : 'days'} ago';
}
