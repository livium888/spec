import 'reading_service.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../domain/import_parser.dart';
import '../domain/learn_planner.dart' show LearnPlanner;
import '../domain/prompt_template.dart' show kFoundationsTemplateVersion, kMaxFoundationCards;
import '../domain/study_card.dart' show kProblemLevels;
import 'db/database.dart';

class ImportSummary {
  const ImportSummary({required this.notes, required this.cards, required this.domainId, this.reading = 0});
  final int reading; // reading suggestions added to the learner's list
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
    return checkPreview(p);
  }

  /// The subject check and the duplicate check, for a preview made by [parseImportJson] or built directly
  /// (the Anki import builds its cards itself and has no AI answer to parse).
  Future<ImportPreview> checkPreview(ImportPreview p, {bool matchPromptSubject = true}) async {
    if (p.hasFatal) return p;

    var dom = await _findDomain(p.domain);
    if (dom == null) {
      // AIs sometimes rename the subject ("Psychology & Influence" for "Psychology and Influence").
      // Importing that as a brand-new subject would leave the requested topic untouched, so the
      // app would offer the same topic again and again. Match it to the prompt that was copied.
      final asked = matchPromptSubject ? await _askedSubject(p) : null;
      if (asked != null) {
        p.renamedFrom = p.domain;
        p.domain = asked.name;
        dom = asked;
      }
    }
    p.newDomain = dom == null;

    final existing = <String>{};
    final found = dom;
    if (found != null) {
      final rows = await (db.select(db.notes)..where((n) => n.domainId.equals(found.id))).get();
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

  /// The subject of a recent, still-unimported CARD prompt that this answer plausibly answers:
  /// same topic title, or a subject name that contains / is contained in the one asked for.
  /// Null if nothing matches, so a genuinely new subject is never forced into an old one.
  Future<Domain?> _askedSubject(ImportPreview p) async {
    final since = DateTime.now().toUtc().millisecondsSinceEpoch - 24 * 3600 * 1000;
    final rows = await (db.select(db.promptLogs)
          ..where((x) =>
              x.status.equals('issued') &
              x.domainId.isNotNull() &
              x.syllabusItemId.isNotNull() &
              x.createdAt.isBiggerOrEqualValue(since))
          ..orderBy([(x) => OrderingTerm.desc(x.createdAt), (x) => OrderingTerm.desc(x.id)])
          ..limit(5))
        .get();
    final wantItem = p.syllabusItem == null ? null : normalizeText(p.syllabusItem!);
    final wantDomain = normalizeText(p.domain);
    for (final r in rows) {
      final dom = await (db.select(db.domains)..where((d) => d.id.equals(r.domainId!))).getSingleOrNull();
      final item = await (db.select(db.syllabusItems)..where((i) => i.id.equals(r.syllabusItemId!))).getSingleOrNull();
      if (dom == null || item == null) continue;
      final name = normalizeText(dom.name);
      final sameTopic = wantItem != null && wantItem.isNotEmpty && wantItem == normalizeText(item.title);
      final similarName = wantDomain.length >= 4 &&
          name.length >= 4 &&
          (wantDomain.contains(name) || name.contains(wantDomain));
      if (sameTopic || similarName) return dom;
    }
    return null;
  }

  /// Insert every `ok` card whose index is in [selected] (null = all).
  Future<ImportSummary> commit(ImportPreview p, {Set<int>? selected, DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final dom = await _findDomain(p.domain);
      final domainId = dom?.id ??
          await db.into(db.domains).insert(DomainsCompanion.insert(name: p.domain, createdAt: t));

      final sylId = await _resolveSyllabusItem(domainId, p.syllabusItem);
      final foundationOf = await _foundationTarget(p, domainId);

      var notes = 0, cards = 0;
      for (final c in p.importable) {
        if (selected != null && !selected.contains(c.index)) continue;
        if (foundationOf != null && notes >= kMaxFoundationCards) break; // one request, at most 4 cards
        final guid = guidFor(p.domain, c.dedupeText);
        // Re-check at commit time: the DB may have changed since preview.
        final dupe = await (db.select(db.notes)..where((n) => n.guid.equals(guid))).getSingleOrNull();
        if (dupe != null) continue;

        final isProblem = c.type == 'problem';
        final tags = {
          ...c.tags,
          if (c.unverified && !isProblem) 'unverified',
          if (isProblem) 'problem',
          if (foundationOf != null) 'foundation',
        };
        final fields = <String, String>{
          if (c.type == 'cloze') 'cloze': c.cloze else 'front': c.front,
          'back': c.back,
          if (isProblem) 'steps': c.steps.join('\n'),
          'supporting_quote': c.supportingQuote,
          if (c.whyItMatters.isNotEmpty) 'why_it_matters': c.whyItMatters,
          if (c.example.isNotEmpty) 'example': c.example,
          if (c.memoryHook.isNotEmpty) 'memory_hook': c.memoryHook,
          if (c.imageQuery.isNotEmpty) 'image_query': c.imageQuery,
          // Where a picture should go once one is added (the card has no picture yet; see EditCardScreen).
          if (c.imageSide.isNotEmpty) 'image_side': c.imageSide,
          // A picture that came with the card (Anki import): already stored, named by its SHA-256.
          if (c.image.isNotEmpty) 'image': c.image,
          // Cards that prepare the learner for a hard card: shown first, outside the daily new-card limit (D41).
          if (foundationOf != null) 'foundation_of': '$foundationOf',
        };
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
        final ords = c.type == 'cloze'
            ? (c.clozeNumbers.toList()..sort())
            : isProblem
                ? [for (var l = 1; l <= kProblemLevels; l++) l] // one card per level
                : [1];
        for (final n in ords) {
          // New card's `due` == note.created_at; RebuildCardsFromLog relies on it.
          await db.into(db.cards).insert(CardsCompanion.insert(noteId: noteId, ord: Value(n - 1), due: t));
          cards++;
        }
        // Further problems of the same kind: one note each with only the final level, which unlocks
        // when the family's third level has been answered well (see QueueService).
        for (final v in c.variants) {
          final vguid = guidFor(p.domain, v.statement);
          if (await (db.select(db.notes)..where((n) => n.guid.equals(vguid))).getSingleOrNull() != null) continue;
          final vId = await db.into(db.notes).insert(NotesCompanion.insert(
                guid: vguid,
                domainId: domainId,
                syllabusItemId: Value(sylId),
                type: 'problem',
                fieldsJson: jsonEncode(<String, String>{
                  'front': v.statement,
                  'back': v.answer,
                  'steps': v.steps.join('\n'),
                  'supporting_quote': '',
                  'variant_of': '$noteId',
                }),
                tags: Value(tags.join(' ')),
                sourceType: Value(c.sourceType),
                sourceRef: Value(c.sourceRef),
                llmConfidence: Value(c.confidence),
                createdAt: t,
              ));
          notes++;
          await db.into(db.cards).insert(CardsCompanion.insert(noteId: vId, ord: const Value(kProblemLevels - 1), due: t));
          cards++;
        }
      }

      if (notes > 0 && p.trackPrompt) {
        await _updatePromptLog(domainId, sylId, notes);
        if (sylId != null) await _refreshItemStatus(sylId);
      }
      final reading = await ReadingService(db).addAll(p.reading, domainId: domainId, syllabusItemId: sylId, now: t);
      return ImportSummary(notes: notes, cards: cards, domainId: domainId, reading: reading);
    });
  }

  /// The note these cards are foundations for: the id the answer carries, else the one in the NEWEST unimported
  /// prompt for this subject, but only if that prompt is a foundations prompt (an answer to an ordinary card
  /// prompt must never be taken for foundations). Null unless that note exists in this subject and is not
  /// itself a foundation card (foundations of foundations would never end).
  Future<int?> _foundationTarget(ImportPreview p, int domainId) async {
    var id = p.foundationOf;
    if (id == null) {
      final row = await (db.select(db.promptLogs)
            ..where((x) => x.domainId.equals(domainId) & x.status.equals('issued'))
            ..orderBy([(x) => OrderingTerm.desc(x.createdAt), (x) => OrderingTerm.desc(x.id)])
            ..limit(1))
          .getSingleOrNull();
      final m = row == null || row.templateVersion != kFoundationsTemplateVersion
          ? null
          : RegExp(r'"foundation_of": (\d+)').firstMatch(row.promptText);
      id = m == null ? null : int.tryParse(m.group(1)!);
    }
    if (id == null) return null;
    final note = await (db.select(db.notes)..where((n) => n.id.equals(id!) & n.domainId.equals(domainId))).getSingleOrNull();
    if (note == null || note.fieldsJson.contains('"foundation_of"')) return null;
    return note.id;
  }

  /// Which syllabus topic do these cards belong to?
  /// 1) exact/normalised title match, 2) the topic the latest unimported prompt
  /// asked for (LLMs rephrase titles), 3) a new topic, only if a title was given.
  Future<int?> _resolveSyllabusItem(int domainId, String? title) async {
    final items = await (db.select(db.syllabusItems)..where((x) => x.domainId.equals(domainId))).get();
    if (title != null) {
      final key = normalizeText(title);
      for (final it in items) {
        if (normalizeText(it.title) == key) return it.id;
      }
    }
    final pending = await (db.select(db.promptLogs)
          ..where((p) =>
              p.domainId.equals(domainId) & p.status.equals('issued') & p.syllabusItemId.isNotNull())
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt), (p) => OrderingTerm.desc(p.id)])
          ..limit(1))
        .getSingleOrNull();
    if (pending?.syllabusItemId != null) return pending!.syllabusItemId;
    if (title == null) return null;
    return db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(
          domainId: domainId,
          title: title,
          position: Value(items.length + 1),
        ));
  }

  Future<Domain?> _findDomain(String name) => (db.select(db.domains)
        ..where((d) => d.name.lower().equals(name.trim().toLowerCase())))
      .getSingleOrNull();

  /// Keep the topic's stored status in step with its card count (todo -> active -> done).
  Future<void> _refreshItemStatus(int itemId) async {
    final it = await (db.select(db.syllabusItems)..where((x) => x.id.equals(itemId))).getSingle();
    final c = await db.customSelect(
        'SELECT COUNT(*) AS n FROM card c JOIN note n ON n.id = c.note_id WHERE n.syllabus_item_id = ?',
        variables: [Variable.withInt(itemId)]).getSingle();
    final next = LearnPlanner.effectiveStatus(it.status, c.read<int>('n'), it.targetCards);
    if (next != it.status) {
      await (db.update(db.syllabusItems)..where((x) => x.id.equals(itemId)))
          .write(SyllabusItemsCompanion(status: Value(next)));
    }
  }

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
