import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/cloze.dart';
import '../domain/prompt_template.dart';
import 'db/database.dart';
import 'engine_service.dart' show PromptService;
import 'learn_service.dart' show GeneratedPrompt, PromptKind;
import 'settings_repo.dart';

/// "Build the foundations": a prompt for 2 to 4 cards that teach what ONE hard card depends on (D41).
class FoundationService {
  FoundationService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  /// Foundation cards already made for [noteId].
  Future<int> countFor(int noteId) async {
    final r = await db.customSelect(
      "SELECT COUNT(*) AS n FROM note WHERE json_extract(fields_json, '\$.foundation_of') = ?",
      variables: [Variable.withString('$noteId')],
    ).getSingle();
    return r.read<int>('n');
  }

  /// The prompt for [noteId]. A foundations prompt for the same card that was never imported is
  /// shown again instead of making a second one.
  Future<GeneratedPrompt> promptFor(int noteId, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final note = await (db.select(db.notes)..where((n) => n.id.equals(noteId))).getSingle();
    const headline = 'Build the foundations for this card';
    const reasons = [
      'These cards teach the ideas this card rests on, so you can answer it by reasoning, not memory.',
      'They are shown before your other new cards and do not use up your daily limit.',
    ];

    final marker = '"foundation_of": $noteId,';
    final earlier = await (db.select(db.promptLogs)
          ..where((p) => p.status.equals('issued') & p.templateVersion.equals(kFoundationsTemplateVersion) & p.domainId.equals(note.domainId))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt), (p) => OrderingTerm.desc(p.id)])
          ..limit(10))
        .get();
    for (final e in earlier) {
      if (e.promptText.contains(marker)) return GeneratedPrompt(e.id, e.promptText, headline, reasons: reasons, kind: PromptKind.cards);
    }

    final fields = jsonDecode(note.fieldsJson) as Map<String, dynamic>;
    final isCloze = note.type == 'cloze';
    final front = isCloze
        ? replaceClozes(fields['cloze'] as String? ?? '', (m) => m.answer)
        : (fields['front'] as String? ?? '');
    final back = isCloze ? (fields['back'] as String? ?? '') : (fields['back'] as String? ?? '');
    final dom = await (db.select(db.domains)..where((d) => d.id.equals(note.domainId))).getSingle();
    String? syl;
    if (note.syllabusItemId != null) {
      syl = (await (db.select(db.syllabusItems)..where((s) => s.id.equals(note.syllabusItemId!))).getSingleOrNull())?.title;
    }
    final titles = await PromptService(db, settings: settings).recentTitles(note.domainId, note.syllabusItemId);
    final text = renderFoundationsPrompt(
      domain: dom.name,
      syllabusItem: syl,
      noteId: noteId,
      front: front,
      back: back,
      whyItMatters: fields['why_it_matters'] as String? ?? '',
      recentTitles: titles,
      learnerProfile: await settings.get(SettingsRepo.learnerProfile),
    );
    final id = await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
          createdAt: t,
          domainId: Value(note.domainId),
          syllabusItemId: Value(note.syllabusItemId),
          templateVersion: kFoundationsTemplateVersion,
          promptText: text,
          cardsRequested: kMaxFoundationCards,
        ));
    return GeneratedPrompt(id, text, headline, reasons: reasons, kind: PromptKind.cards);
  }
}
