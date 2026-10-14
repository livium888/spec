import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/keywords_prompt.dart' show stripClozeMarkup;
import '../domain/read_more_prompt.dart';
import 'db/database.dart';

/// What the preview says about one entry of the AI's answer.
enum ReadMoreStatus { ok, nothingToAdd, unknownCard, alreadyHas, problemCard, invalid, duplicate }

class ReadMoreRow {
  const ReadMoreRow({required this.entry, required this.status, this.question = ''});
  final ReadMoreEntry entry;
  final ReadMoreStatus status;
  final String question; // the card's question, so the learner can see what each line is for
  bool get applicable => status == ReadMoreStatus.ok || status == ReadMoreStatus.nothingToAdd;
}

class ReadMorePlan {
  const ReadMorePlan({required this.rows, required this.fatalErrors});
  final List<ReadMoreRow> rows;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
  Iterable<ReadMoreRow> get applicable => rows.where((r) => r.applicable);
}

class ReadMoreResult {
  const ReadMoreResult({required this.added, required this.none});

  /// Paragraphs saved, and cards marked "nothing to add".
  final int added, none;
}

/// Read more for cards made before every card carried it (D64). Only `fields_json` of a note is touched, so
/// scheduling, review history and replay are unaffected. An existing paragraph is never overwritten. A card
/// the AI found nothing to add for gets a hidden `read_more_none` mark, so it is not offered again.
class ReadMoreService {
  ReadMoreService(this.db);
  final AppDatabase db;

  static const _missing = "n.type != 'problem' "
      "AND COALESCE(json_extract(n.fields_json, '\$.read_more'), '') = '' "
      "AND json_extract(n.fields_json, '\$.read_more_none') IS NULL";

  Future<int> countMissing() async {
    final r = await db.customSelect('SELECT COUNT(*) AS c FROM note n WHERE $_missing').getSingle();
    return r.read<int>('c');
  }

  /// The next [limit] cards (oldest first) that have no paragraph and were not marked "nothing to add".
  Future<List<ReadMoreCardRef>> nextBatch(int limit) async {
    final rows = await db.customSelect(
      'SELECT n.id AS id, n.type AS type, n.fields_json AS f, d.name AS subject '
      'FROM note n JOIN domain d ON d.id = n.domain_id WHERE $_missing ORDER BY n.id LIMIT ?',
      variables: [Variable.withInt(limit.clamp(1, kMaxReadMoreBatch))],
    ).get();
    return [
      for (final r in rows)
        () {
          final f = jsonDecode(r.read<String>('f')) as Map<String, dynamic>;
          final cloze = r.read<String>('type') == 'cloze';
          return ReadMoreCardRef(
            noteId: r.read<int>('id'),
            subject: r.read<String>('subject'),
            question: (cloze ? f['cloze'] : f['front']) as String? ?? '',
            answer: f['back'] as String? ?? '',
            why: f['why_it_matters'] as String? ?? '',
          );
        }(),
    ];
  }

  /// Check an AI answer against the cards. Nothing is saved.
  Future<ReadMorePlan> preview(String raw) async {
    final parsed = parseReadMoreJson(raw);
    if (parsed.hasFatal) return ReadMorePlan(rows: const [], fatalErrors: parsed.fatalErrors);
    final ids = {for (final e in parsed.entries) ?e.noteId};
    final notes = <int, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      final q = await db.customSelect(
        'SELECT id, type, fields_json FROM note WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        variables: [for (final i in ids) Variable.withInt(i)],
      ).get();
      for (final r in q) {
        final f = jsonDecode(r.read<String>('fields_json')) as Map<String, dynamic>;
        f['__type'] = r.read<String>('type');
        notes[r.read<int>('id')] = f;
      }
    }
    final rows = <ReadMoreRow>[];
    for (final e in parsed.entries) {
      final f = e.noteId == null ? null : notes[e.noteId];
      final question = f == null ? '' : ((f['__type'] == 'cloze' ? f['cloze'] : f['front']) as String? ?? '');
      final ReadMoreStatus st;
      if (e.errors.isNotEmpty) {
        st = e.errors.any((x) => x.contains('appears twice')) ? ReadMoreStatus.duplicate : ReadMoreStatus.invalid;
      } else if (f == null) {
        st = ReadMoreStatus.unknownCard;
      } else if (f['__type'] == 'problem') {
        st = ReadMoreStatus.problemCard;
      } else if ((f['read_more'] as String? ?? '').trim().isNotEmpty) {
        st = ReadMoreStatus.alreadyHas;
      } else if (e.nothingToAdd) {
        st = ReadMoreStatus.nothingToAdd;
      } else {
        st = ReadMoreStatus.ok;
      }
      rows.add(ReadMoreRow(entry: e, status: st, question: stripClozeMarkup(question)));
    }
    return ReadMorePlan(rows: rows, fatalErrors: const []);
  }

  /// Apply the chosen entries in one transaction. Re-checks each card at the moment of saving, so a card
  /// edited since the preview is never overwritten.
  Future<ReadMoreResult> commit(ReadMorePlan plan, Set<int> selectedIndexes) {
    return db.transaction(() async {
      var added = 0, none = 0;
      for (final r in plan.applicable) {
        if (!selectedIndexes.contains(r.entry.index)) continue;
        final row = await (db.select(db.notes)..where((x) => x.id.equals(r.entry.noteId!))).getSingleOrNull();
        if (row == null || row.type == 'problem') continue;
        final fields = jsonDecode(row.fieldsJson) as Map<String, dynamic>;
        if ((fields['read_more'] as String? ?? '').trim().isNotEmpty) continue;
        if (r.entry.nothingToAdd) {
          fields['read_more_none'] = '1';
          none++;
        } else {
          fields['read_more'] = r.entry.text;
          fields.remove('read_more_none');
          added++;
        }
        await (db.update(db.notes)..where((x) => x.id.equals(row.id))).write(NotesCompanion(fieldsJson: Value(jsonEncode(fields))));
      }
      return ReadMoreResult(added: added, none: none);
    });
  }
}
