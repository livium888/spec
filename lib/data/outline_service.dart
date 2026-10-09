import 'package:drift/drift.dart';

import '../domain/import_parser.dart' show normalizeText;
import '../domain/outline_parser.dart';
import '../domain/plan_parser.dart';
import 'db/database.dart';

class OutlineException implements Exception {
  OutlineException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OutlineSummary {
  const OutlineSummary(this.items, this.edges, this.droppedEdges, this.domainId);
  final int items, edges, droppedEdges, domainId;
}

/// Imports a syllabus outline (topics + prerequisites) produced by an LLM.
class OutlineService {
  OutlineService(this.db);
  final AppDatabase db;

  Future<OutlinePreview> preview(String raw) async => annotate(parseOutlineJson(raw));

  /// Several subjects from one paste (the "map" prompt's answer). Nothing is saved.
  Future<PlanPreview> previewPlan(String raw) async {
    final plan = parsePlanJson(raw);
    for (final s in plan.subjects) {
      await annotate(s.outline);
    }
    return plan;
  }

  /// Save the chosen subjects (indexes into [PlanPreview.subjects]) in one transaction:
  /// all of them or none. Returns subjects added and topics added.
  Future<({int subjects, int topics})> commitPlan(PlanPreview plan, Set<int> selected, {DateTime? now}) {
    return db.transaction(() async {
      var subjects = 0, topics = 0;
      for (final s in plan.subjects) {
        if (!selected.contains(s.index) || !s.valid) continue;
        final r = await commit(s.outline, now: now);
        if (r.items > 0) subjects++;
        topics += r.items;
      }
      final row = await (db.select(db.promptLogs)
            ..where((x) => x.status.equals('issued') & x.templateVersion.like('map-%'))
            ..orderBy([(x) => OrderingTerm.desc(x.createdAt), (x) => OrderingTerm.desc(x.id)])
            ..limit(1))
          .getSingleOrNull();
      if (row != null) {
        await (db.update(db.promptLogs)..where((x) => x.id.equals(row.id)))
            .write(const PromptLogsCompanion(status: Value('imported')));
      }
      return (subjects: subjects, topics: topics);
    });
  }

  Future<OutlinePreview> annotate(OutlinePreview p) async {
    if (p.hasFatal) return p;
    final dom = await _findDomain(p.domain);
    p.newDomain = dom == null;
    final existing = dom == null
        ? <String, int>{}
        : {
            for (final i in await (db.select(db.syllabusItems)..where((x) => x.domainId.equals(dom.id))).get())
              normalizeText(i.title): i.id
          };
    final inPayload = {for (final i in p.items) normalizeText(i.title)};
    for (final it in p.items) {
      if (existing.containsKey(normalizeText(it.title))) p.alreadyExists.add(it.index);
      for (final pre in it.prerequisites) {
        final k = normalizeText(pre);
        if (!existing.containsKey(k) && !inPayload.contains(k)) {
          p.warnings.putIfAbsent(it.index, () => []).add('Prerequisite "$pre" matches no topic and will be ignored.');
        }
      }
    }
    return p;
  }

  Future<OutlineSummary> commit(OutlinePreview p, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final dom = await _findDomain(p.domain);
      final domainId = dom?.id ??
          await db.into(db.domains).insert(DomainsCompanion.insert(name: p.domain, createdAt: t));

      final existingRows =
          await (db.select(db.syllabusItems)..where((x) => x.domainId.equals(domainId))).get();
      final idByTitle = {for (final r in existingRows) normalizeText(r.title): r.id};
      var pos = existingRows.fold<int>(0, (m, r) => r.position > m ? r.position : m);

      // Re-check at commit time: the preview may be stale.
      final newItems =
          p.importable.where((it) => !idByTitle.containsKey(normalizeText(it.title))).toList();
      for (final it in newItems) {
        final id = await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(
              domainId: domainId,
              title: it.title,
              level: Value(it.level),
              position: Value(++pos),
              targetCards: Value(it.targetCards),
              description: Value(it.description),
              practice: Value(it.practice),
            ));
        idByTitle[normalizeText(it.title)] = id;
      }

      // Resolve prerequisite titles to ids; unknown ones are dropped and counted.
      final edges = <(int, int)>{};
      var dropped = 0;
      for (final it in newItems) {
        final from = idByTitle[normalizeText(it.title)]!;
        for (final pre in it.prerequisites) {
          final to = idByTitle[normalizeText(pre)];
          if (to == null || to == from) {
            dropped++;
          } else {
            edges.add((from, to));
          }
        }
      }

      // Cycle check over old + new edges before anything is written.
      final old = await db.select(db.syllabusPrereqs).get();
      final graph = <String, List<String>>{};
      for (final e in [...old.map((r) => (r.itemId, r.prereqId)), ...edges]) {
        graph.putIfAbsent('${e.$1}', () => []).add('${e.$2}');
        graph.putIfAbsent('${e.$2}', () => []);
      }
      if (findCycle(graph) != null) {
        throw OutlineException('These prerequisites would create a loop with your existing topics. Nothing was imported.');
      }
      for (final e in edges) {
        await db.into(db.syllabusPrereqs).insert(
            SyllabusPrereqsCompanion.insert(itemId: e.$1, prereqId: e.$2),
            mode: InsertMode.insertOrIgnore);
      }

      // Close out the matching unimported outline prompt.
      final row = await (db.select(db.promptLogs)
            ..where((x) =>
                x.domainId.equals(domainId) &
                x.status.equals('issued') &
                x.templateVersion.like('outline-%'))
            ..orderBy([(x) => OrderingTerm.desc(x.createdAt), (x) => OrderingTerm.desc(x.id)])
            ..limit(1))
          .getSingleOrNull();
      if (row != null) {
        await (db.update(db.promptLogs)..where((x) => x.id.equals(row.id)))
            .write(const PromptLogsCompanion(status: Value('imported')));
      }
      return OutlineSummary(newItems.length, edges.length, dropped, domainId);
    });
  }

  Future<Domain?> _findDomain(String name) => (db.select(db.domains)
        ..where((d) => d.name.lower().equals(name.trim().toLowerCase())))
      .getSingleOrNull();
}
