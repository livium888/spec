import 'package:drift/drift.dart';

import '../domain/knowledge_map.dart';
import 'db/database.dart';
import 'params_repo.dart';

/// Reads one subject's topics, prerequisites and cards and turns them into a [KnowledgeMap] (D44).
class KnowledgeService {
  KnowledgeService(this.db, this.params);
  final AppDatabase db;
  final ParamsRepo params;

  Future<KnowledgeMap> forDomain(int domainId, {DateTime? now}) async {
    final nowMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final items = await (db.select(db.syllabusItems)
          ..where((s) => s.domainId.equals(domainId))
          ..orderBy([(s) => OrderingTerm.asc(s.position), (s) => OrderingTerm.asc(s.id)]))
        .get();
    if (items.isEmpty) return KnowledgeMap(nodes: {}, layers: const [], nextUp: const [], blockers: const {});

    final weights = (await params.configFor(await params.idForDomain(domainId))).weights;

    final prereqs = <int, List<int>>{};
    for (final e in await db.select(db.syllabusPrereqs).get()) {
      prereqs.putIfAbsent(e.itemId, () => []).add(e.prereqId);
    }

    final facts = <int, List<CardFact>>{};
    final problems = <int>{};
    final foundations = <int, int>{};
    final rows = await db.customSelect(
      '''SELECT n.id AS nid, n.syllabus_item_id AS sid, c.state AS state, c.stability AS stability, c.last_review AS last,
                c.lapses AS lapses, c.suspended AS suspended, c.retired_at AS retired, n.type AS type,
                n.tags AS tags, n.fields_json LIKE '%"foundation_of":%' AS foundation
         FROM card c JOIN note n ON n.id = c.note_id
         WHERE n.domain_id = ? AND n.syllabus_item_id IS NOT NULL''',
      variables: [Variable.withInt(domainId)],
    ).get();
    final foundationNotes = <int>{};
    for (final r in rows) {
      final sid = r.read<int>('sid');
      final tags = ' ${r.read<String>('tags')} ';
      facts.putIfAbsent(sid, () => []).add(CardFact(
            state: r.read<String>('state'),
            stability: r.readNullable<double>('stability'),
            lastReviewMs: r.readNullable<int>('last'),
            lapses: r.read<int>('lapses'),
            suspended: r.read<int>('suspended') != 0,
            retired: r.readNullable<int>('retired') != null,
            leech: tags.contains(' leech '),
          ));
      if (r.read<String>('type') == 'problem') problems.add(sid);
      if (r.read<int>('foundation') != 0 && foundationNotes.add(r.read<int>('nid'))) foundations[sid] = (foundations[sid] ?? 0) + 1;
    }

    final nodes = [
      for (final it in items)
        buildNode(
          id: it.id,
          title: it.title,
          level: it.level,
          position: it.position,
          status: it.status,
          targetCards: it.targetCards,
          facts: facts[it.id] ?? const [],
          weights: weights,
          nowMs: nowMs,
          prereqs: prereqs[it.id] ?? const [],
          problems: problems.contains(it.id) || it.practice == 'problems' || it.practice == 'both',
          foundations: foundations[it.id] ?? 0,
          practice: it.practice,
        ),
    ];
    return buildKnowledgeMap(nodes);
  }
}
