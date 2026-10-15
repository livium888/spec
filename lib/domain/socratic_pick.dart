/// Which card the Socratic way out of the pause (D66) talks about. Pure Dart; the Kotlin side never needs it (the app
/// chooses the card and hands its id to the phone side).
///
/// The rule, decided with the learner: the card they struggled with, taken from their hardest few so it is not always
/// the same one; if they have hardly lapsed at all, one of their mature cards. No re-roll: a card you can shop for is a
/// card you will shop for.
library;

import 'memory_summary.dart' show kLongTermStability;

/// A card the learner has reviewed, as the rule sees it.
class SocraticCandidate {
  const SocraticCandidate({
    required this.noteId,
    required this.ord,
    required this.lapses,
    this.difficulty,
    this.stability,
    this.talkedThrough = false,
  });
  final int noteId, ord, lapses;

  /// FSRS difficulty (1 to 10) and stability in days; null before a card has either.
  final double? difficulty, stability;

  /// The note carries the `talked_through` tag: it has had a conversation already.
  final bool talkedThrough;
}

/// Their hardest cards considered, and how many lapsed cards it takes to use the struggle rule.
const kSocraticHardest = 5;
const kSocraticMinLapsed = 3;

/// Most lapses first, then the harder FSRS difficulty, then the weaker memory, then the older note.
List<SocraticCandidate> socraticRanked(Iterable<SocraticCandidate> cards) => cards.toList()
  ..sort((a, b) {
    final byLapses = b.lapses.compareTo(a.lapses);
    if (byLapses != 0) return byLapses;
    final byDifficulty = (b.difficulty ?? 0).compareTo(a.difficulty ?? 0);
    if (byDifficulty != 0) return byDifficulty;
    final byStability = (a.stability ?? double.infinity).compareTo(b.stability ?? double.infinity);
    if (byStability != 0) return byStability;
    return a.noteId.compareTo(b.noteId);
  });

/// The card for this pause, or null when the learner has reviewed nothing. [seed] makes the choice stable within one
/// pause and different across pauses (see [socraticSeed]).
SocraticCandidate? pickSocraticCard(List<SocraticCandidate> all, {required int seed}) {
  if (all.isEmpty) return null;
  // A conversation per card, until every candidate has had one.
  final fresh = [for (final c in all) if (!c.talkedThrough) c];
  final pool = fresh.isEmpty ? all : fresh;
  final lapsed = [for (final c in pool) if (c.lapses > 0) c];
  final List<SocraticCandidate> choices;
  if (lapsed.length >= kSocraticMinLapsed) {
    choices = socraticRanked(lapsed).take(kSocraticHardest).toList();
  } else {
    // Hardly any struggle to go on: the cards that feel safest are the ones most worth a probing question.
    final mature = [for (final c in pool) if ((c.stability ?? 0) >= kLongTermStability) c]..sort((a, b) => a.noteId.compareTo(b.noteId));
    choices = mature.isNotEmpty ? mature : socraticRanked(pool);
  }
  return choices[seed % choices.length];
}

/// Same card within one pause (same day, same number of conversations so far); another on the next.
int socraticSeed({required int dayIndex, required int talksToday}) => dayIndex * 7 + talksToday;
