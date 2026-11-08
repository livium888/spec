import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/import_parser.dart' show normalizeText;
import '../domain/primer_parser.dart';
import 'db/database.dart';
import 'import_service.dart';

/// What the preview says about one primer of an answer.
enum PrimerStatus { ok, replaces, newTopic, noSubject, invalid }

class PrimerRow {
  const PrimerRow({required this.primer, required this.status, this.domainId, this.topicId, this.topicTitle = ''});
  final ParsedPrimer primer;
  final PrimerStatus status;
  final int? domainId;
  final int? topicId;

  /// The topic's own title when it matched (the AI may have written it in other case or spacing).
  final String topicTitle;
  bool get applicable => status == PrimerStatus.ok || status == PrimerStatus.replaces || status == PrimerStatus.newTopic;
}

class PrimerPlan {
  const PrimerPlan({required this.rows, required this.fatalErrors});
  final List<PrimerRow> rows;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
  Iterable<PrimerRow> get applicable => rows.where((r) => r.applicable);
}

class PrimerResult {
  const PrimerResult({required this.added, required this.replaced, required this.topicsCreated});
  final int added, replaced, topicsCreated;
}

/// A primer as the reader and the topic list need it.
class StoredPrimer {
  const StoredPrimer({required this.id, required this.primer, required this.readAt, required this.readCount});
  final int id;
  final ParsedPrimer primer;
  final int? readAt;
  final int readCount;
  bool get read => readAt != null;
}

/// Primers (D68): one reading per topic, imported from JSON the learner's own AI wrote. Matched to a topic by its title;
/// a title that does not exist becomes a new topic at the end of the subject (the preview says so first).
class PrimerService {
  PrimerService(this.db);
  final AppDatabase db;

  Future<Domain?> _domain(String name) =>
      (db.select(db.domains)..where((d) => d.name.lower().equals(name.trim().toLowerCase()))).getSingleOrNull();

  Future<SyllabusItem?> _topic(int domainId, String title) async {
    final key = normalizeText(title);
    for (final it in await (db.select(db.syllabusItems)..where((x) => x.domainId.equals(domainId))).get()) {
      if (normalizeText(it.title) == key) return it;
    }
    return null;
  }

  /// Check an AI answer against the subjects and topics. Nothing is saved.
  Future<PrimerPlan> preview(String raw) async {
    final parsed = parsePrimerJson(raw);
    if (parsed.hasFatal) return PrimerPlan(rows: const [], fatalErrors: parsed.fatalErrors);
    final rows = <PrimerRow>[];
    for (final p in parsed.primers) {
      if (!p.valid) {
        rows.add(PrimerRow(primer: p, status: PrimerStatus.invalid));
        continue;
      }
      final dom = await _domain(p.domain);
      if (dom == null) {
        rows.add(PrimerRow(primer: p, status: PrimerStatus.noSubject));
        continue;
      }
      final topic = await _topic(dom.id, p.topic);
      if (topic == null) {
        rows.add(PrimerRow(primer: p, status: PrimerStatus.newTopic, domainId: dom.id));
        continue;
      }
      final has = await (db.select(db.primers)..where((x) => x.syllabusItemId.equals(topic.id))).getSingleOrNull();
      rows.add(PrimerRow(
        primer: p,
        status: has == null ? PrimerStatus.ok : PrimerStatus.replaces,
        domainId: dom.id,
        topicId: topic.id,
        topicTitle: topic.title,
      ));
    }
    return PrimerPlan(rows: rows, fatalErrors: const []);
  }

  /// Save the chosen primers in one transaction. The topic is looked up again at the moment of saving, so two primers for a
  /// new topic in one file make one topic. A replaced primer is unread again.
  Future<PrimerResult> commit(PrimerPlan plan, Set<int> selectedIndexes, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      var added = 0, replaced = 0, created = 0;
      for (final r in plan.applicable) {
        if (!selectedIndexes.contains(r.primer.index)) continue;
        final dom = await _domain(r.primer.domain);
        if (dom == null) continue;
        var topic = await _topic(dom.id, r.primer.topic);
        if (topic == null) {
          final n = await db.customSelect('SELECT COUNT(*) AS c FROM syllabus_item WHERE domain_id = ?', variables: [Variable.withInt(dom.id)]).getSingle();
          final id = await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(
                domainId: dom.id,
                title: r.primer.topic,
                level: Value(r.primer.level),
                position: Value(n.read<int>('c') + 1),
              ));
          topic = await (db.select(db.syllabusItems)..where((x) => x.id.equals(id))).getSingle();
          created++;
        }
        final content = primerContentJson(r.primer);
        final has = await (db.select(db.primers)..where((x) => x.syllabusItemId.equals(topic!.id))).getSingleOrNull();
        if (has == null) {
          await db.into(db.primers).insert(PrimersCompanion.insert(
                domainId: dom.id,
                syllabusItemId: topic.id,
                title: Value(r.primer.title),
                level: Value(r.primer.level),
                content: content,
                createdAt: t,
                updatedAt: t,
              ));
          added++;
        } else {
          await (db.update(db.primers)..where((x) => x.id.equals(has.id))).write(PrimersCompanion(
            title: Value(r.primer.title),
            level: Value(r.primer.level),
            content: Value(content),
            updatedAt: Value(t),
            readAt: const Value(null),
          ));
          replaced++;
        }
      }
      return PrimerResult(added: added, replaced: replaced, topicsCreated: created);
    });
  }

  Future<StoredPrimer?> _stored(Primer row) async {
    final dom = await (db.select(db.domains)..where((d) => d.id.equals(row.domainId))).getSingleOrNull();
    final topic = await (db.select(db.syllabusItems)..where((x) => x.id.equals(row.syllabusItemId))).getSingleOrNull();
    if (dom == null || topic == null) return null;
    return StoredPrimer(
      id: row.id,
      primer: primerFromStored(domain: dom.name, topic: topic.title, title: row.title, level: row.level, content: row.content),
      readAt: row.readAt,
      readCount: row.readCount,
    );
  }

  Future<StoredPrimer?> forTopic(int topicId) async {
    final row = await (db.select(db.primers)..where((x) => x.syllabusItemId.equals(topicId))).getSingleOrNull();
    return row == null ? null : _stored(row);
  }

  Future<StoredPrimer?> get(int id) async {
    final row = await (db.select(db.primers)..where((x) => x.id.equals(id))).getSingleOrNull();
    return row == null ? null : _stored(row);
  }

  /// topic id -> its primer, for a subject's topic list.
  Future<Map<int, StoredPrimer>> forDomain(int domainId) async {
    final out = <int, StoredPrimer>{};
    for (final row in await (db.select(db.primers)..where((x) => x.domainId.equals(domainId))).get()) {
      final s = await _stored(row);
      if (s != null) out[row.syllabusItemId] = s;
    }
    return out;
  }

  Future<void> markRead(int id, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    await db.customStatement('UPDATE primer SET read_at = ?, read_count = read_count + 1 WHERE id = ?', [t, id]);
  }

  Future<void> delete(int id) => (db.delete(db.primers)..where((x) => x.id.equals(id))).go();

  /// The primer's pretest questions as ordinary cards in its topic (the learner asked for it). They carry no source
  /// quote; they point at the primer. Returns how many were added (a question already in the subject is skipped).
  Future<int> addPretestAsCards(int primerId) async {
    final s = await get(primerId);
    if (s == null || s.primer.pretest.isEmpty) return 0;
    final payload = jsonEncode({
      'domain': s.primer.domain,
      'syllabus_item': s.primer.topic,
      'cards': [
        for (final q in s.primer.pretest)
          {
            'type': 'basic',
            'front': q.question,
            'back': q.answer,
            'source_type': 'quote',
            'source_ref': 'Primer: ${s.primer.title.isEmpty ? s.primer.topic : s.primer.title}',
            'supporting_quote': '',
            'confidence': 'medium',
            'tags': ['primer'],
          },
      ],
    });
    final imp = ImportService(db);
    final preview = await imp.preview(payload);
    if (preview.hasFatal) return 0;
    final sum = await imp.commit(preview);
    return sum.notes;
  }
}
