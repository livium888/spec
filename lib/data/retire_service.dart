import 'package:drift/drift.dart';

import '../domain/retire.dart';
import 'db/database.dart';

class RetiredCard {
  const RetiredCard({required this.cardId, required this.noteId, required this.title, required this.domainName, required this.stability, required this.retiredAt});
  final int cardId, noteId, retiredAt;
  final String title, domainName;
  final double stability;
}

/// Retiring a mastered card takes it out of your reviews without deleting anything. It is the
/// same as suspending it, plus a label so it can be found and brought back. Scheduling fields and
/// review history are never touched, so replay == live and a restored card is exactly as it was.
class RetireService {
  RetireService(this.db);
  final AppDatabase db;

  static const _where =
      "state = 'review' AND suspended = 0 AND retired_at IS NULL AND stability >= ? AND reps >= ? AND lapses <= ?";
  List<Variable> _vars(RetireCriteria c) =>
      [Variable.withReal(c.minStabilityDays), Variable.withInt(kRetireMinReviews), Variable.withInt(kRetireMaxLapses)];

  Future<RetireSummary> summary(RetireCriteria c, {double secondsPerReview = 10}) async {
    final r = await db.customSelect(
        'SELECT COUNT(*) AS n, COALESCE(SUM(365.0 / stability), 0) AS s FROM card WHERE $_where',
        variables: _vars(c)).getSingle();
    final saved = (r.data['s'] as num).toDouble();
    return RetireSummary(
      cards: r.read<int>('n'),
      reviewsSavedPerYear: saved,
      minutesSavedPerYear: saved * secondsPerReview / 60.0,
    );
  }

  /// Retire every card that meets [c]. Returns how many.
  Future<int> retireMastered(RetireCriteria c, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return db.customUpdate(
      'UPDATE card SET suspended = 1, retired_at = ? WHERE $_where',
      variables: [Variable.withInt(t), ..._vars(c)],
      updates: {db.cards},
    );
  }

  Future<int> retiredCount() async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM card WHERE retired_at IS NOT NULL').getSingle()).read<int>('n');

  Future<List<RetiredCard>> retired({int limit = 50, int offset = 0}) async {
    final rows = await db.customSelect('''
      SELECT c.id AS cid, c.note_id AS nid, c.stability AS s, c.retired_at AS at, n.type AS type,
             n.fields_json AS f, d.name AS dname
      FROM card c JOIN note n ON n.id = c.note_id JOIN domain d ON d.id = n.domain_id
      WHERE c.retired_at IS NOT NULL ORDER BY c.retired_at DESC, c.id DESC LIMIT ? OFFSET ?''',
        variables: [Variable.withInt(limit), Variable.withInt(offset)]).get();
    return [
      for (final r in rows)
        RetiredCard(
          cardId: r.read<int>('cid'),
          noteId: r.read<int>('nid'),
          title: _title(r.read<String>('type'), r.read<String>('f')),
          domainName: r.read<String>('dname'),
          stability: (r.data['s'] as num?)?.toDouble() ?? 0,
          retiredAt: r.read<int>('at'),
        )
    ];
  }

  /// Bring one card back. It keeps its due date, so if that has passed it is simply due now.
  Future<void> restore(int cardId) async => db.customUpdate(
        'UPDATE card SET suspended = 0, retired_at = NULL WHERE id = ? AND retired_at IS NOT NULL',
        variables: [Variable.withInt(cardId)],
        updates: {db.cards},
      );

  Future<int> restoreAll() async => db.customUpdate(
        'UPDATE card SET suspended = 0, retired_at = NULL WHERE retired_at IS NOT NULL',
        updates: {db.cards},
      );

  static String _title(String type, String fieldsJson) {
    final m = RegExp('"${type == 'cloze' ? 'cloze' : 'front'}"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(fieldsJson);
    final raw = m?.group(1) ?? '';
    return raw.replaceAll(r'\n', ' ').replaceAll(r'\"', '"').replaceAllMapped(RegExp(r'\{\{c\d+::(.*?)(?:::.*?)?\}\}'), (x) => x[1]!);
  }
}
