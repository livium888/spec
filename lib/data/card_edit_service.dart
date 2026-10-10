import '../domain/commons.dart' show cleanImageQuery;
import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/card_edit.dart';
import '../domain/cloze.dart';
import 'activity_cache.dart';
import 'db/database.dart';
import 'media_service.dart';
import 'settings_repo.dart';

class NoteRow {
  const NoteRow({
    required this.noteId,
    required this.cardCount,
    required this.reviewCount,
    required this.type,
    required this.fields,
    required this.domainName,
    required this.domainId,
    this.marked = false,
  });
  final int noteId, cardCount, reviewCount, domainId;

  /// The learner marked it to look at later.
  final bool marked;
  final String type, domainName;
  final Map<String, dynamic> fields;
  String get title => (type == 'cloze' ? fields['cloze'] : fields['front']) as String? ?? '';
}

/// Edit or delete what the user has collected.
///
/// Editing changes text only; scheduling is untouched, so history and replay stay valid.
/// Deleting is permanent: the note, its cards and their review history go together
/// (review_log rows cannot outlive their card). Backups made earlier still hold them.
class CardEditService {
  CardEditService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  Future<NoteRow?> note(int noteId) async {
    final rows = await _query(where: 'n.id = ?', args: [Variable.withInt(noteId)], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Newest first. [query] matches question/answer text; [domainId] narrows to a subject.
  Future<List<NoteRow>> search({String query = '', int? domainId, bool markedOnly = false, int limit = 50, int offset = 0}) {
    final where = <String>[];
    final args = <Variable>[];
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add("n.fields_json LIKE ? ESCAPE '\\'");
      args.add(Variable.withString('%${q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%'));
    }
    if (markedOnly) where.add("(' ' || n.tags || ' ') LIKE '% marked %'");
    if (domainId != null) {
      where.add('n.domain_id = ?');
      args.add(Variable.withInt(domainId));
    }
    return _query(where: where.isEmpty ? '1=1' : where.join(' AND '), args: args, limit: limit, offset: offset);
  }

  Future<List<NoteRow>> _query(
      {required String where, required List<Variable> args, required int limit, int offset = 0}) async {
    final rows = await db.customSelect('''
      SELECT n.id, n.type, n.fields_json, n.domain_id, n.tags, d.name AS dname,
             (SELECT COUNT(*) FROM card c WHERE c.note_id = n.id) AS cards,
             (SELECT COUNT(*) FROM review_log l JOIN card c ON c.id = l.card_id
                WHERE c.note_id = n.id) AS reviews
      FROM note n JOIN domain d ON d.id = n.domain_id
      WHERE $where ORDER BY n.id DESC LIMIT ? OFFSET ?''',
        variables: [...args, Variable.withInt(limit), Variable.withInt(offset)]).get();
    return [
      for (final r in rows)
        NoteRow(
          noteId: r.read<int>('id'),
          cardCount: r.read<int>('cards'),
          reviewCount: r.read<int>('reviews'),
          type: r.read<String>('type'),
          fields: jsonDecode(r.read<String>('fields_json')) as Map<String, dynamic>,
          domainName: r.read<String>('dname'),
          domainId: r.read<int>('domain_id'),
          marked: ' ${r.read<String>('tags')} '.contains(' marked '),
        )
    ];
  }

  /// Returns validation errors; empty means saved. Unknown keys in the note are kept.
  Future<List<String>> update(int noteId, Map<String, String> edited) async {
    final n = await note(noteId);
    if (n == null) return ['This card no longer exists.'];
    final existing = clozeNumbersOf(n.fields['cloze'] as String? ?? '');
    final errors = validateNoteEdit(type: n.type, fields: edited, existingClozeNumbers: existing);
    if (errors.isNotEmpty) return errors;

    final fields = Map<String, dynamic>.from(n.fields);
    const optional = ['why_it_matters', 'example', 'memory_hook', 'image', 'image_side', 'image_alt', 'image_credit', 'image_query'];
    final oldImage = n.fields['image'] as String?;
    for (final e in edited.entries) {
      // Image keywords are stored tidy (spaces collapsed), the same way the prompt's hint is.
      final v = e.key == 'image_query' ? (cleanImageQuery(e.value) ?? '') : e.value.trim();
      if (v.isEmpty && optional.contains(e.key)) {
        fields.remove(e.key);
      } else {
        fields[e.key] = v;
      }
    }
    await db.transaction(() async {
      await (db.update(db.notes)..where((x) => x.id.equals(noteId)))
          .write(NotesCompanion(fieldsJson: Value(jsonEncode(fields))));
      // A new cloze number needs a card; the review screen only shows cards that exist.
      if (n.type == 'cloze') {
        final have = {
          for (final c in await (db.select(db.cards)..where((c) => c.noteId.equals(noteId))).get()) c.ord
        };
        // New card's `due` == note.created_at; RebuildCardsFromLog relies on it.
        final createdAt = (await (db.select(db.notes)..where((x) => x.id.equals(noteId))).getSingle()).createdAt;
        for (final m in findClozes(fields['cloze'] as String)) {
          final ord = m.number - 1;
          if (have.add(ord)) {
            await db.into(db.cards).insert(CardsCompanion.insert(noteId: noteId, ord: Value(ord), due: createdAt));
          }
        }
      }
    });
    final newImage = fields['image'] as String?;
    if (oldImage != null && oldImage != newImage) await MediaService(db).deleteIfOrphan(oldImage);
    return const [];
  }

  /// Permanently removes the note, its cards and their review history.
  Future<void> delete(int noteId) async {
    final image = (await note(noteId))?.fields['image'] as String?;
    await _delete(noteId);
    await MediaService(db).deleteIfOrphan(image); // a picture nothing refers to any more is removed too
  }

  Future<void> _delete(int noteId) => db.transaction(() async {
        await db.customStatement(
            'DELETE FROM review_log WHERE card_id IN (SELECT id FROM card WHERE note_id = ?)', [noteId]);
        await db.customStatement('DELETE FROM card WHERE note_id = ?', [noteId]);
        await db.customStatement('DELETE FROM note WHERE id = ?', [noteId]);
        // History left, so the answers-per-day cache no longer matches the log.
        await ActivityCache(db, settings).invalidate();
      });
}
