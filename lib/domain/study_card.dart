import 'cloze.dart';
import 'models.dart';

/// One piece of a cloze sentence: plain text, or the gap this card asks about.
class ClozePart {
  const ClozePart.text(this.text, {this.hiddenText})
      : isGap = false,
        hint = null;
  const ClozePart.gap(this.text, {this.hint})
      : isGap = true,
        hiddenText = null;

  /// Plain text, or (for the gap) the hidden answer.
  final String text;
  final bool isGap;

  /// The optional hint written as {{c1::answer::hint}}.
  final String? hint;

  /// For a formula with this card's gap inside it (`$x = {{c1::5}}$`): [text] is the formula with the answer
  /// boxed (shown after the reveal), this is the same formula with an empty box (shown before).
  final String? hiddenText;
}

/// Closed `$...$` / `$$...$$` regions of [text], ignoring any `$` that sits inside a cloze gap and any `\$`.
List<(int, int)> _mathRegions(String text, List<ClozeMatch> gaps) {
  bool inGap(int i) => gaps.any((g) => i >= g.start && i < g.end);
  final out = <(int, int)>[];
  int? open;
  String? delim;
  for (var i = 0; i < text.length; i++) {
    if (text[i] != r'$' || inGap(i) || (i > 0 && text[i - 1] == '\\')) continue;
    final d = text.startsWith(r'$$', i) ? r'$$' : r'$';
    if (open == null) {
      open = i;
      delim = d;
      i += d.length - 1;
    } else if (d == delim || (delim == r'$$' && d == r'$')) {
      out.add((open, i + d.length));
      open = null;
      i += d.length - 1;
    }
  }
  return out;
}

/// The four levels of a problem family.
const kProblemLevels = 4;

/// Steps shown up front: all of them at level 1 (a worked example to study), then fewer, none at level 4.
int problemStepsGiven(int total, int level) {
  if (level <= 1) return total;
  if (level >= kProblemLevels) return 0;
  return total - ((total * (level - 1) + 2) ~/ 3); // total - ceil(total * (level-1) / 3)
}

/// A card plus the note content needed to display it.
class StudyCard {
  const StudyCard({
    required this.snapshot,
    required this.noteId,
    required this.domainId,
    required this.noteType,
    required this.fields,
    required this.tags,
    required this.ord,
    required this.suspended,
  });

  final CardSnapshot snapshot;
  final int noteId;
  final int domainId;
  final String noteType; // basic|cloze
  final Map<String, dynamic> fields;
  final List<String> tags;
  final int ord;
  final bool suspended;

  int get id => snapshot.id;

  /// Problem cards (D43): one note, four cards = four levels, from a fully worked example to solving alone.
  bool get isProblem => noteType == 'problem';
  int get problemLevel => (ord + 1).clamp(1, kProblemLevels);
  List<String> get problemSteps => [
        for (final l in (fields['steps'] as String? ?? '').split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ];

  /// How many steps are already shown when this card appears.
  int get stepsGiven => problemStepsGiven(problemSteps.length, problemLevel);
  bool get unverified => tags.contains('unverified');

  /// The card's picture (SHA-256 of the stored image), which side it goes on, and its description.
  String? get imageSha {
    final v = fields['image'];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool get imageOnFront => (fields['image_side'] as String?) != 'back';
  /// Who made the picture and under which licence (shown under it when it came from Wikimedia Commons).
  String get imageCredit => (fields['image_credit'] as String? ?? '').trim();
  String get imageAlt => (fields['image_alt'] as String? ?? '').trim();
  bool get leech => tags.contains('leech');

  /// The learner marked this card to look at later (D49). A tag, so no schema change.
  bool get marked => tags.contains('marked');

  /// Answer-side extras in reading order, as (label, text). Empty ones are left out.
  List<(String, String)> get extras => [
        for (final (label, key) in const [
          ('Why it matters', 'why_it_matters'),
          ('Example', 'example'),
          ('Memory hook', 'memory_hook'),
          ('Read more', 'read_more'), // D64: the paragraph for the curious, last
        ])
          if ((fields[key] as String? ?? '').trim().isNotEmpty) (label, (fields[key] as String).trim()),
      ];

  /// The sentence of a cloze card in order: plain text, with this card's own deletion as a gap.
  /// Other deletions of the same note are shown as ordinary text (their answers), as in [front].
  List<ClozePart> get clozeParts {
    final text = fields['cloze'] as String? ?? '';
    final parts = <ClozePart>[];
    var at = 0;
    final all = findClozes(text);
    final regions = _mathRegions(text, all);
    (int, int)? inRegion(ClozeMatch m) {
      for (final r in regions) {
        if (m.start > r.$1 && m.end < r.$2) return r;
      }
      return null;
    }

    for (var k = 0; k < all.length; k++) {
      final m = all[k];
      final region = inRegion(m);
      if (region != null) {
        // A gap inside a formula: the whole formula is one piece, so its dollar signs are not left bare.
        // Gaps are visited in order; the first one of a region emits it, the rest were folded into it.
        if (at > region.$1) continue;
        if (region.$1 > at) parts.add(ClozePart.text(text.substring(at, region.$1)));
        String build(bool hidden) => replaceClozes(text.substring(region.$1, region.$2), (g) {
              if (g.number != ord + 1) return g.answer;
              return hidden ? r'\square' : '\\boxed{${g.answer}}';
            });
        parts.add(ClozePart.text(build(false), hiddenText: build(true)));
        at = region.$2;
        continue;
      }
      if (m.start > at) parts.add(ClozePart.text(text.substring(at, m.start)));
      if (m.number == ord + 1) {
        parts.add(ClozePart.gap(m.answer, hint: m.hint));
      } else {
        parts.add(ClozePart.text(m.answer));
      }
      at = m.end;
    }
    if (at < text.length) parts.add(ClozePart.text(text.substring(at)));
    return parts;
  }

  /// Extra explanation written beside a cloze sentence (shown after the reveal).
  String get clozeExtra => (fields['back'] as String? ?? '').trim();

  /// Question side. Cloze: the active deletion becomes `[...]` (or its hint).
  String get front {
    if (noteType == 'cloze') {
      final text = fields['cloze'] as String? ?? '';
      return replaceClozes(text, (m) => m.number == ord + 1 ? '[${m.hint ?? '...'}]' : m.answer);
    }
    return fields['front'] as String? ?? '';
  }

  /// Answer side. Cloze: full text with the active deletion visible.
  String get back {
    if (noteType == 'cloze') {
      final text = fields['cloze'] as String? ?? '';
      final full = replaceClozes(text, (m) => m.answer);
      final extra = fields['back'] as String? ?? '';
      return extra.isEmpty ? full : '$full\n\n$extra';
    }
    return fields['back'] as String? ?? '';
  }
}

/// Result of building today's queue.
class DailyQueue {
  const DailyQueue({
    required this.learning,
    required this.reviews,
    required this.newCards,
    required this.dueReviewCount,
    required this.newLimit,
    required this.newIntroducedToday,
    this.nextLearningDue,
    this.learnAhead = const [],
  });

  final List<StudyCard> learning; // due now
  final List<StudyCard> reviews;
  final List<StudyCard> newCards; // already capped by the remaining limit
  final int dueReviewCount; // before sibling filtering
  final int newLimit; // backlog-adjusted daily limit
  final int newIntroducedToday;

  /// Earliest due time (ms) of a learning card not yet due, for "come back at".
  final int? nextLearningDue;

  /// Learning cards whose short wait is not quite over, offered ONLY when nothing else is due, so a
  /// session does not end with cards that are minutes away (D40).
  final List<StudyCard> learnAhead;

  /// Order the spec mandates: due learning, due reviews, then new; early learning cards last.
  List<StudyCard> get ordered => [...learning, ...reviews, ...newCards, ...learnAhead];
  StudyCard? get next => ordered.isEmpty ? null : ordered.first;
  bool get isEmpty => ordered.isEmpty;
}

/// `limit = max(0, base - floor(dueReviews / divisor))`
int backlogAdjustedNewLimit(int base, int dueReviews, {int divisor = 25}) =>
    (base - dueReviews ~/ divisor).clamp(0, base < 0 ? 0 : base);
