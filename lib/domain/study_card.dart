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
  bool get unverified => tags.contains('unverified');

  /// The card's picture (SHA-256 of the stored image), which side it goes on, and its description.
  String? get imageSha {
    final v = fields['image'];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool get imageOnFront => (fields['image_side'] as String?) != 'back';
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
  });

  final List<StudyCard> learning; // due now
  final List<StudyCard> reviews;
  final List<StudyCard> newCards; // already capped by the remaining limit
  final int dueReviewCount; // before sibling filtering
  final int newLimit; // backlog-adjusted daily limit
  final int newIntroducedToday;

  /// Earliest due time (ms) of a learning card not yet due, for "come back at".
  final int? nextLearningDue;

  /// Order the spec mandates: due learning, due reviews, then new.
  List<StudyCard> get ordered => [...learning, ...reviews, ...newCards];
  StudyCard? get next => ordered.isEmpty ? null : ordered.first;
  bool get isEmpty => ordered.isEmpty;
}

/// `limit = max(0, base - floor(dueReviews / divisor))`
int backlogAdjustedNewLimit(int base, int dueReviews, {int divisor = 25}) =>
    (base - dueReviews ~/ divisor).clamp(0, base < 0 ? 0 : base);
