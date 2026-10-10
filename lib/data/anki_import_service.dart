import '../domain/anki_import.dart';
import '../domain/import_parser.dart';
import 'anki_package.dart';
import 'db/database.dart';
import 'import_service.dart';
import 'media_service.dart';

/// The cards of one Anki deck group (the top-level deck), as they would be imported.
class AnkiSubjectPlan {
  AnkiSubjectPlan(this.subject);
  String subject; // editable before importing
  final drafts = <AnkiDraft>[];
  int get count => drafts.length;
  bool selected = true;
}

class AnkiPlan {
  AnkiPlan({required this.subjects, required this.skipped, required this.notes, required this.sounds, required this.pictureNames});
  final List<AnkiSubjectPlan> subjects;
  final Map<AnkiSkip, int> skipped;
  final int notes;
  final int sounds; // [sound:] references dropped
  final int pictureNames; // cards that name a picture

  int get importable => subjects.fold(0, (a, s) => a + s.count);
  int get skippedTotal => skipped.values.fold(0, (a, b) => a + b);

  static String skipWords(AnkiSkip s) => switch (s) {
        AnkiSkip.empty => 'empty question or answer',
        AnkiSkip.noGap => 'cloze without a gap',
        AnkiSkip.occlusion => 'image occlusion (not supported)',
        AnkiSkip.tooLong => 'too long',
      };
}

class AnkiImportResult {
  const AnkiImportResult({
    required this.notes,
    required this.cards,
    required this.duplicates,
    required this.pictures,
    required this.picturesDropped,
    required this.subjects,
  });
  final int notes, cards, duplicates, pictures, picturesDropped;

  /// Subject names that received cards, with the subject ids (the first one can be opened next).
  final Map<String, int> subjects;
}

/// Convert notes into subjects and cards, then hand them to the ordinary import (dedupe + commit).
class AnkiImportService {
  AnkiImportService(this.db);
  final AppDatabase db;

  AnkiPlan plan(AnkiRead read) {
    final bySubject = <String, AnkiSubjectPlan>{};
    final skipped = <AnkiSkip, int>{};
    var sounds = 0, pics = 0;
    var index = 0;
    for (final n in read.notes) {
      final r = convertAnkiNote(n, index++);
      if (r.skip != null) {
        skipped[r.skip!] = (skipped[r.skip!] ?? 0) + 1;
        continue;
      }
      final d = r.draft!;
      sounds += d.sounds;
      if (d.imageFile.isNotEmpty) pics++;
      final subject = subjectOfDeck(n.deck).subject;
      final key = subject.toLowerCase();
      (bySubject[key] ??= AnkiSubjectPlan(subject)).drafts.add(d);
    }
    final subjects = bySubject.values.toList()..sort((a, b) => b.count.compareTo(a.count));
    return AnkiPlan(subjects: subjects, skipped: skipped, notes: read.notes.length, sounds: sounds, pictureNames: pics);
  }

  /// Import every selected subject. Reports progress as (cards handled, cards in total).
  Future<AnkiImportResult> import(AnkiPlan plan, AnkiRead read, {void Function(int done, int total)? onProgress, DateTime? now}) async {
    final imp = ImportService(db);
    final media = MediaService(db);
    final chosen = [for (final s in plan.subjects) if (s.selected && s.subject.trim().isNotEmpty) s];
    final total = chosen.fold<int>(0, (a, s) => a + s.count);
    var done = 0, notes = 0, cards = 0, pics = 0, picsDropped = 0, handled = 0;
    final into = <String, int>{};
    for (final s in chosen) {
      const chunk = 400;
      for (var at = 0; at < s.drafts.length; at += chunk) {
        final slice = s.drafts.sublist(at, at + chunk > s.drafts.length ? s.drafts.length : at + chunk);
        final parsed = <ParsedCard>[
          for (var i = 0; i < slice.length; i++) _copy(slice[i].card, i),
        ];
        final p = ImportPreview(domain: s.subject.trim(), syllabusItem: null, cards: parsed, fatalErrors: const [], trackPrompt: false);
        await imp.checkPreview(p, matchPromptSubject: false);
        // Pictures are stored only for cards that will really be added (not for duplicates).
        for (var i = 0; i < slice.length; i++) {
          final d = slice[i];
          if (d.imageFile.isEmpty || p.status[i] != PreviewStatus.ok) continue;
          String? sha;
          try {
            final bytes = await read.picture(d.imageFile);
            if (bytes != null) sha = await media.save(bytes, now: now);
          } catch (_) {
            sha = null; // too large, or not a picture the app can show: the card is imported without it
          }
          if (sha == null) {
            picsDropped++;
          } else {
            pics++;
            parsed[i] = _copy(parsed[i], i, image: sha, imageSide: d.imageSide);
          }
        }
        final sum = await imp.commit(p, now: now);
        notes += sum.notes;
        cards += sum.cards;
        into[s.subject.trim()] = sum.domainId;
        handled += slice.length;
        done += slice.length;
        onProgress?.call(done, total);
      }
    }
    return AnkiImportResult(
      notes: notes,
      cards: cards,
      duplicates: handled - notes,
      pictures: pics,
      picturesDropped: picsDropped,
      subjects: into,
    );
  }
}

ParsedCard _copy(ParsedCard c, int index, {String image = '', String imageSide = ''}) => ParsedCard(
      index: index,
      type: c.type,
      front: c.front,
      back: c.back,
      cloze: c.cloze,
      sourceType: c.sourceType,
      sourceRef: c.sourceRef,
      confidence: c.confidence,
      tags: c.tags,
      imageSide: imageSide,
      image: image,
    );

