import 'package:drift/drift.dart';

import '../domain/course_prompts.dart';
import '../domain/transcript.dart';
import 'db/database.dart';

/// Lecture transcripts (D67): kept per subject so the app can build prompts from them and check a card's quote against
/// them. Nothing is fetched or sent from here; the text is the learner's own copy.
class SourceService {
  SourceService(this.db);
  final AppDatabase db;

  Future<Domain?> domainByName(String name) =>
      (db.select(db.domains)..where((d) => d.name.lower().equals(name.trim().toLowerCase()))).getSingleOrNull();

  /// The subject called [name], created if it does not exist yet.
  Future<int> ensureDomain(String name, {DateTime? now}) async {
    final found = await domainByName(name);
    if (found != null) return found.id;
    return db.into(db.domains).insert(DomainsCompanion.insert(name: name.trim(), createdAt: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch));
  }

  /// The next free lecture number in the subject (1 for the first).
  Future<int> nextNumber(int domainId) async {
    final r = await db.customSelect('SELECT COALESCE(MAX(number), 0) AS m FROM source WHERE domain_id = ?', variables: [Variable.withInt(domainId)]).getSingle();
    return r.read<int>('m') + 1;
  }

  /// Keep a lecture. The text is cleaned (caption files lose their timings) and capped; an empty one is refused.
  /// Returns the new row's id, or null with nothing saved when the text is empty.
  Future<int?> add({required int domainId, required String title, int? number, String note = '', required String text, DateTime? now}) async {
    final body = cleanTranscript(text);
    if (body.isEmpty || title.trim().isEmpty) return null;
    return db.into(db.sources).insert(SourcesCompanion.insert(
          domainId: domainId,
          number: Value(number ?? await nextNumber(domainId)),
          title: title.trim(),
          note: Value(note.trim()),
          body: body,
          createdAt: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
        ));
  }

  Future<List<Source>> forDomain(int domainId) =>
      (db.select(db.sources)..where((s) => s.domainId.equals(domainId))..orderBy([(s) => OrderingTerm.asc(s.number), (s) => OrderingTerm.asc(s.id)])).get();

  Future<Source?> get(int id) => (db.select(db.sources)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> delete(int id) => (db.delete(db.sources)..where((s) => s.id.equals(id))).go();

  Future<int> count(int domainId) async {
    final r = await db.customSelect('SELECT COUNT(*) AS c FROM source WHERE domain_id = ?', variables: [Variable.withInt(domainId)]).getSingle();
    return r.read<int>('c');
  }

  /// Every lecture of the subject, ready for a course-map prompt.
  Future<List<LectureRef>> lectureRefs(int domainId) async =>
      [for (final s in await forDomain(domainId)) LectureRef(number: s.number, title: s.title, excerpt: excerptOf(s.body))];

  /// A quote checker over all of the subject's transcripts, or null when it has none (then there is nothing to check against).
  Future<QuoteIndex?> indexFor(int domainId) async {
    final all = await forDomain(domainId);
    if (all.isEmpty) return null;
    return QuoteIndex(all.map((s) => s.body).join('\n\n'));
  }
}
