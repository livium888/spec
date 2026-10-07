import 'models.dart';

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
  bool get leech => tags.contains('leech');

  static final _clozeRe = RegExp(r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}', dotAll: true);

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
