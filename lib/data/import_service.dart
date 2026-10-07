import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../domain/import_parser.dart';
import 'db/database.dart';

class ImportSummary {
  const ImportSummary({required this.notes, required this.cards, required this.domainId});
  final int notes;
  final int cards;
  final int domainId;
}

/// ImportCards use case: preview (parse + dedupe) then commit.
class ImportService {
  ImportService(this.db);
  final AppDatabase db;

  /// Deterministic GUID: the same normalised text in the same domain always
  /// yields the same GUID, so re-importing is a no-op.
  static String guidFor(String domain, String dedupeText) => sha1
      .convert(utf8.encode('${domain.trim().toLowerCase()}\u0000${normalizeText(dedupeText)}'))
      .toString();

  Future<ImportPreview> preview(String raw) async {
    final p = parseImportJson(raw);
    if (p.hasFatal) return p;

    final dom = await _findDomain(p.domain);
    p.newDomain = dom == null;

    final existing = <String>{};
    if (dom != null) {
      final rows = await (db.select(db.notes)..where((n) => n.domainId.equals(dom.id))).get();
      existing.addAll(rows.map((n) => n.guid));
    }
    final seen = <String>{};
    for (final c in p.cards) {
      if (!c.valid) {
        p.status[c.index] = PreviewStatus.invalid;
        continue;
      }
      final g = guidFor(p.domain, c.dedupeText);
      if (existing.contains(g)) {
        p.status[c.index] = PreviewStatus.duplicateInDb;
      } else if (!seen.add(g)) {
        p.status[c.index] = PreviewStatus.duplicateInPayload;
      } else {
        p.status[c.index] = PreviewStatus.ok;
      }
    }
    return p;
  }

  /// Insert every `ok` card whose index is in [selected] (null = all).
  Future<ImportSummary> commit(ImportPreview p, {Set<int>? selected, DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final dom = await _findDomain(p.domain);
      final domainId = dom?.id ??
          await db.into(db.domains).insert(DomainsCompanion.insert(name: p.domain, createdAt: t));

      int? sylId;
      if (p.syllabusItem != null) {
        final s = await (db.select(db.syllabusItems)
              ..where((x) => x.domainId.equals(domainId) & x.title.equals(p.syllabusItem!)))
            .getSingleOrNull();
        sylId = s?.id ??
            await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(
                  domainId: domainId,
                  title: p.syllabusItem!,
                ));
      }

      var notes = 0, cards = 0;
      for (final c in p.importable) {
        if (selected != null && !selected.contains(c.index)) continue;
        final guid = guidFor(p.domain, c.dedupeText);
        // Re-check at commit time: the DB may have changed since preview.
        final dupe = await (db.select(db.notes)..where((n) => n.guid.equals(guid))).getSingleOrNull();
        if (dupe != null) continue;

        final tags = {...c.tags, if (c.unverified) 'unverified'};
        final fields = c.type == 'cloze'
            ? {'cloze': c.cloze, 'back': c.back, 'supporting_quote': c.supportingQuote}
            : {'front': c.front, 'back': c.back, 'supporting_quote': c.supportingQuote};
        final noteId = await db.into(db.notes).insert(NotesCompanion.insert(
              guid: guid,
              domainId: domainId,
              syllabusItemId: Value(sylId),
              type: c.type,
              fieldsJson: jsonEncode(fields),
              tags: Value(tags.join(' ')),
              sourceType: Value(c.sourceType),
              sourceRef: Value(c.sourceRef),
              llmConfidence: Value(c.confidence),
              createdAt: t,
            ));
        notes++;
        final ords = c.type == 'cloze' ? (c.clozeNumbers.toList()..sort()) : [1];
        for (final n in ords) {
          // New card's `due` == note.created_at; RebuildCardsFromLog relies on it.
          await db.into(db.cards).insert(CardsCompanion.insert(noteId: noteId, ord: Value(n - 1), due: t));
          cards++;
        }
      }

      if (notes > 0) await _updatePromptLog(domainId, sylId, notes);
      return ImportSummary(notes: notes, cards: cards, domainId: domainId);
    });
  }

  Future<Domain?> _findDomain(String name) => (db.select(db.domains)
        ..where((d) => d.name.lower().equals(name.trim().toLowerCase())))
      .getSingleOrNull();

  /// Attach the import to the most recent still-`issued` prompt for the domain.
  Future<void> _updatePromptLog(int domainId, int? sylId, int notes) async {
    final row = await (db.select(db.promptLogs)
          ..where((p) => p.domainId.equals(domainId) & p.status.equals('issued'))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt), (p) => OrderingTerm.desc(p.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;
    await (db.update(db.promptLogs)..where((p) => p.id.equals(row.id))).write(PromptLogsCompanion(
      cardsImported: Value(row.cardsImported + notes),
      status: const Value('imported'),
    ));
  }
}
