import 'models.dart';

/// One piece of a cloze sentence: plain text, or the gap this card asks about.
class ClozePart {
  const ClozePart.text(this.text)
      : isGap = false,
        hint = null;
  const ClozePart.gap(this.text, {this.hint}) : isGap = true;

  /// Plain text, or (for the gap) the hidden answer.
  final String text;
  final bool isGap;

  /// The optional hint written as {{c1::answer::hint}}.
  final String? hint;
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

  /// Answer-side extras in reading order, as (label, text). Empty ones are left out.
  List<(String, String)> get extras => [
        for (final (label, key) in const [
          ('Why it matters', 'why_it_matters'),
          ('Example', 'example'),
          ('Memory hook', 'memory_hook'),
        ])
          if ((fields[key] as String? ?? '').trim().isNotEmpty) (label, (fields[key] as String).trim()),
      ];

  static final _clozeRe = RegExp(r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}', dotAll: true);

  /// The sentence of a cloze card in order: plain text, with this card's own deletion as a gap.
  /// Other deletions of the same note are shown as ordinary text (their answers), as in [front].
  List<ClozePart> get clozeParts {
    final text = fields['cloze'] as String? ?? '';
    final parts = <ClozePart>[];
    var at = 0;
    for (final m in _clozeRe.allMatches(text)) {
      if (m.start > at) parts.add(ClozePart.text(text.substring(at, m.start)));
      if (int.parse(m[1]!) == ord + 1) {
        parts.add(ClozePart.gap(m[2]!, hint: m[3]));
      } else {
        parts.add(ClozePart.text(m[2]!));
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
      return text.replaceAllMapped(_clozeRe, (m) {
        if (int.parse(m[1]!) == ord + 1) return '[${m[3] ?? '...'}]';
        return m[2]!;
      });
    }
    return fields['front'] as String? ?? '';
  }

  /// Answer side. Cloze: full text with the active deletion visible.
  String get back {
    if (noteType == 'cloze') {
      final text = fields['cloze'] as String? ?? '';
      final full = text.replaceAllMapped(_clozeRe, (m) => m[2]!);
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
