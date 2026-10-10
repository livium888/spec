/// From Anki notes to this app's cards (D50). Pure Dart: the file reading is in the data layer.
///
/// Only content comes across: the question and answer, the tags and which deck it was in. Anki's scheduling
/// (due dates, intervals) and review history are NOT imported: every card arrives as new. Anki's own code is
/// not used; this follows the documented file formats and note-type behaviour.
library;

import 'anki_text.dart';
import 'import_parser.dart';

/// Most notes read from one file; more is refused with advice to export one deck at a time.
const kMaxAnkiNotes = 50000;

/// One note as read from an Anki package or text export.
class AnkiNote {
  const AnkiNote({
    required this.model,
    required this.fields,
    this.fieldNames = const [],
    this.cloze = false,
    this.tags = const [],
    this.deck = '',
    this.html = true,
  });
  final String model; // note type name, e.g. "Basic"
  final List<String> fields;
  final List<String> fieldNames;
  final bool cloze; // the note type is a cloze type
  final List<String> tags;
  final String deck; // "Biology::Cells"
  final bool html;
}

enum AnkiSkip { empty, noGap, occlusion, tooLong }

/// One converted note: a card for the app's own import, plus the picture file it named (fetched by the caller).
class AnkiDraft {
  const AnkiDraft({required this.card, this.imageFile = '', this.imageSide = 'front', this.extraImages = 0, this.sounds = 0});
  final ParsedCard card;
  final String imageFile;
  final String imageSide;
  final int extraImages, sounds;
}

class AnkiConverted {
  const AnkiConverted({this.draft, this.skip});
  final AnkiDraft? draft;
  final AnkiSkip? skip;
}

/// The subject and tags for an Anki deck name: the top-level deck is the subject, the sub-decks become tags.
({String subject, List<String> tags}) subjectOfDeck(String deck, {String fallback = 'Imported from Anki'}) {
  final parts = [for (final p in deck.split('::')) p.trim()].where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty || parts.first.toLowerCase() == 'default') {
    if (parts.length > 1) {
      final rest = parts.sublist(1);
      return (subject: _cap(rest.first), tags: [for (final p in rest.skip(1)) ...cleanTag(p)]);
    }
    return (subject: fallback, tags: const []);
  }
  return (subject: _cap(parts.first), tags: [for (final p in parts.skip(1)) ...cleanTag(p)]);
}

String _cap(String s) => s.length > 60 ? s.substring(0, 60).trim() : s;

String _byName(AnkiNote n, List<String> names) {
  for (final want in names) {
    final i = n.fieldNames.indexWhere((f) => f.toLowerCase() == want);
    if (i >= 0 && i < n.fields.length) return n.fields[i];
  }
  return '';
}

/// Converts one note, or says why it cannot be.
AnkiConverted convertAnkiNote(AnkiNote n, int index) {
  if (n.model.toLowerCase().contains('occlusion')) return const AnkiConverted(skip: AnkiSkip.occlusion);
  if (n.fields.isEmpty) return const AnkiConverted(skip: AnkiSkip.empty);

  var sounds = 0;
  final images = <(String, String)>[]; // (file, side)
  AnkiFieldText conv(String raw, String side) {
    final r = ankiFieldToText(raw, html: n.html);
    sounds += r.sounds;
    for (final f in r.images) {
      images.add((f, side));
    }
    return r;
  }

  final tags = <String>{'from_anki'};
  for (final t in n.tags) {
    // Anki tags may be hierarchical (a::b): keep the last part, the most specific one.
    final last = t.split('::').last;
    for (final c in cleanTag(last)) {
      if (tags.length < kMaxTags) tags.add(c);
    }
  }
  for (final c in subjectOfDeck(n.deck).tags) {
    if (tags.length < kMaxTags) tags.add(c);
  }

  ParsedCard card;
  if (n.cloze) {
    final textField = _byName(n, ['text']).isNotEmpty ? _byName(n, ['text']) : n.fields.first;
    final extraRaw = _byName(n, ['back extra', 'extra']).isNotEmpty
        ? _byName(n, ['back extra', 'extra'])
        : (n.fields.length > 1 ? n.fields[1] : '');
    final text = conv(textField, 'front').text;
    final extra = conv(extraRaw, 'back').text;
    if (text.isEmpty) return const AnkiConverted(skip: AnkiSkip.empty);
    if (!RegExp(r'\{\{c\d+::').hasMatch(text)) return const AnkiConverted(skip: AnkiSkip.noGap);
    card = ParsedCard(
      index: index,
      type: 'cloze',
      cloze: text,
      back: extra,
      sourceType: 'imported',
      sourceRef: 'Anki: ${n.deck}',
      confidence: 'high',
      tags: tags.toList(),
    );
  } else {
    var front = conv(n.fields.first, 'front').text;
    final rest = <String>[];
    for (var i = 1; i < n.fields.length; i++) {
      final t = conv(n.fields[i], 'back').text;
      if (t.isNotEmpty) rest.add(t);
    }
    var back = rest.join('\n\n');
    final hasFrontImage = images.any((i) => i.$2 == 'front');
    final hasBackImage = images.any((i) => i.$2 == 'back');
    // A card that is only a picture on one side keeps a short text so the card is never empty.
    if (front.isEmpty && hasFrontImage) front = 'What is shown in the picture?';
    if (back.isEmpty && hasBackImage) back = 'See the picture.';
    if (front.isEmpty || back.isEmpty) return const AnkiConverted(skip: AnkiSkip.empty);
    card = ParsedCard(
      index: index,
      type: 'basic',
      front: front,
      back: back,
      sourceType: 'imported',
      sourceRef: 'Anki: ${n.deck}',
      confidence: 'high',
      tags: tags.toList(),
    );
  }
  final first = images.isEmpty ? null : images.first;
  return AnkiConverted(
    draft: AnkiDraft(
      card: card,
      imageFile: first?.$1 ?? '',
      imageSide: first?.$2 ?? 'front',
      extraImages: images.length > 1 ? images.length - 1 : 0,
      sounds: sounds,
    ),
  );
}

/// The notes of a plain-text / CSV export as [AnkiNote]s, using the columns the header names (or the first two).
List<AnkiNote> notesOfTextFile(AnkiTextFile f, {String deckName = 'Imported from Anki'}) {
  final out = <AnkiNote>[];
  // A spreadsheet's header row ("Front,Back") is not a card.
  const frontWords = {'front', 'question', 'term', 'word', 'prompt'};
  const backWords = {'back', 'answer', 'definition', 'meaning', 'translation'};
  final rows = [...f.rows];
  if (rows.isNotEmpty && rows.first.length >= 2 && frontWords.contains(rows.first[0].trim().toLowerCase()) && backWords.contains(rows.first[1].trim().toLowerCase())) {
    rows.removeAt(0);
  }
  final special = {if (f.notetypeCol != null) f.notetypeCol!, if (f.deckCol != null) f.deckCol!, if (f.tagsCol != null) f.tagsCol!, if (f.guidCol != null) f.guidCol!};
  for (final row in rows) {
    String at(int? c) => c != null && c < row.length ? row[c].trim() : '';
    final fields = [for (var i = 0; i < row.length; i++) if (!special.contains(i)) row[i]];
    if (fields.isEmpty) continue;
    final model = at(f.notetypeCol);
    final deck = at(f.deckCol);
    out.add(AnkiNote(
      model: model.isEmpty ? 'Basic' : model,
      fields: fields,
      cloze: model.toLowerCase().contains('cloze') || (model.isEmpty && fields.first.contains(RegExp(r'\{\{c\d+::'))),
      tags: at(f.tagsCol).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(),
      deck: deck.isEmpty ? deckName : deck,
      html: f.html,
    ));
  }
  return out;
}
