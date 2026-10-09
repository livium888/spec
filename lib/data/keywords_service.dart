import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/keywords_prompt.dart';
import 'db/database.dart';

/// What the preview says about one entry of the AI's answer.
enum KeywordStatus { ok, unknownCard, alreadyHasKeywords, hasPicture, invalid, duplicate }

class KeywordRow {
  const KeywordRow({required this.entry, required this.status, this.question = ''});
  final KeywordEntry entry;
  final KeywordStatus status;
  final String question; // the card's question, so the learner can see what each line is for
  bool get applicable => status == KeywordStatus.ok;
}

class KeywordPlan {
  const KeywordPlan({required this.rows, required this.fatalErrors});
  final List<KeywordRow> rows;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
  Iterable<KeywordRow> get applicable => rows.where((r) => r.applicable);
}

/// Image keywords for cards made before every card carried them. Only `fields_json` of a note is
/// touched, so scheduling, review history and replay are unaffected. Existing keywords are never
/// overwritten, and a card that already has a picture is left alone.
class KeywordsService {
  KeywordsService(this.db);
  final AppDatabase db;

  static const _missing = "json_extract(n.fields_json, '\$.image_query') IS NULL "
      "AND json_extract(n.fields_json, '\$.image') IS NULL";

  Future<int> countMissing() async {
    final r = await db.customSelect('SELECT COUNT(*) AS c FROM note n WHERE $_missing').getSingle();
    return r.read<int>('c');
  }

  /// The next [limit] cards (oldest first) that have neither keywords nor a picture.
  Future<List<KeywordCardRef>> nextBatch(int limit) async {
    final rows = await db.customSelect(
      'SELECT n.id AS id, n.type AS type, n.fields_json AS f, d.name AS subject '
      'FROM note n JOIN domain d ON d.id = n.domain_id WHERE $_missing ORDER BY n.id LIMIT ?',
      variables: [Variable.withInt(limit.clamp(1, kMaxKeywordCards))],
    ).get();
    return [
      for (final r in rows)
        () {
          final f = jsonDecode(r.read<String>('f')) as Map<String, dynamic>;
          final cloze = r.read<String>('type') == 'cloze';
          return KeywordCardRef(
            noteId: r.read<int>('id'),
            subject: r.read<String>('subject'),
            question: (cloze ? f['cloze'] : f['front']) as String? ?? '',
            answer: f['back'] as String? ?? '',
          );
        }(),
    ];
  }

  /// Check an AI answer against the cards. Nothing is saved.
  Future<KeywordPlan> preview(String raw) async {
    final parsed = parseKeywordsJson(raw);
    if (parsed.hasFatal) return KeywordPlan(rows: const [], fatalErrors: parsed.fatalErrors);
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
    final rows = <KeywordRow>[];
    for (final e in parsed.entries) {
      final f = e.noteId == null ? null : notes[e.noteId];
      final question = f == null ? '' : ((f['__type'] == 'cloze' ? f['cloze'] : f['front']) as String? ?? '');
      final KeywordStatus st;
      if (e.errors.isNotEmpty) {
        st = e.errors.any((x) => x.contains('appears twice')) ? KeywordStatus.duplicate : KeywordStatus.invalid;
      } else if (f == null) {
        st = KeywordStatus.unknownCard;
      } else if ((f['image_query'] as String? ?? '').isNotEmpty) {
        st = KeywordStatus.alreadyHasKeywords;
      } else if ((f['image'] as String? ?? '').isNotEmpty) {
        st = KeywordStatus.hasPicture;
      } else {
        st = KeywordStatus.ok;
      }
      rows.add(KeywordRow(entry: e, status: st, question: stripClozeMarkup(question)));
    }
    return KeywordPlan(rows: rows, fatalErrors: const []);
  }

  /// Apply the chosen entries in one transaction. Re-checks each card at the moment of saving, so a
  /// card edited since the preview is never overwritten. Returns how many cards were updated.
  Future<int> commit(KeywordPlan plan, Set<int> selectedIndexes) {
    return db.transaction(() async {
      var n = 0;
      for (final r in plan.applicable) {
        if (!selectedIndexes.contains(r.entry.index)) continue;
        final row = await (db.select(db.notes)..where((x) => x.id.equals(r.entry.noteId!))).getSingleOrNull();
        if (row == null) continue;
        final fields = jsonDecode(row.fieldsJson) as Map<String, dynamic>;
        if ((fields['image_query'] as String? ?? '').isNotEmpty || (fields['image'] as String? ?? '').isNotEmpty) continue;
        fields['image_query'] = r.entry.query;
        // The side hint only matters for a picture added later; never move an existing choice.
        if (r.entry.side.isNotEmpty && fields['image_side'] == null) fields['image_side'] = r.entry.side;
        await (db.update(db.notes)..where((x) => x.id.equals(row.id))).write(NotesCompanion(fieldsJson: Value(jsonEncode(fields))));
        n++;
      }
      return n;
    });
  }
}
