import 'dart:convert';


import '../domain/talk_prompt.dart';
import 'db/database.dart';
import 'settings_repo.dart';

/// Reads a card for "Talk it through with an AI" (D60). Nothing is sent from here: the sheet hands the text to the
/// share sheet or the clipboard, and the schedule is not touched.
class TalkService {
  TalkService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  /// The note's card [ord] as the AI is told about it, or null when the note no longer exists. A missing subject
  /// or topic does not stop it: the card's own words are what matter.
  Future<TalkCard?> load(int noteId, int ord) async {
    final note = await (db.select(db.notes)..where((n) => n.id.equals(noteId))).getSingleOrNull();
    if (note == null) return null;
    Map<String, dynamic> fields;
    try {
      final decoded = jsonDecode(note.fieldsJson);
      fields = decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      fields = const {};
    }
    String domain = '';
    String? syllabus;
    try {
      domain = (await (db.select(db.domains)..where((d) => d.id.equals(note.domainId))).getSingleOrNull())?.name ?? '';
      if (note.syllabusItemId != null) {
        syllabus = (await (db.select(db.syllabusItems)..where((s) => s.id.equals(note.syllabusItemId!))).getSingleOrNull())?.title;
      }
    } catch (_) {
      // the subject and topic are extras
    }
    return talkCardOf(
      type: note.type,
      fields: fields,
      ord: ord,
      domain: domain,
      syllabusItem: syllabus,
      sourceType: note.sourceType,
      sourceRef: note.sourceRef,
    );
  }

  Future<String?> profile() => settings.get(SettingsRepo.learnerProfile);
}
