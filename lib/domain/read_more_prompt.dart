/// The "Read more for my older cards" prompt and its answer (pure; no Flutter, no I/O).
///
/// Cards made before prompt v10 have no `read_more` paragraph (D64). The learner sends a batch of them to
/// an AI and pastes back a list: each entry names a card by its number and gives the paragraph. The answer
/// is UNTRUSTED text: ids and strings are type-checked and length-capped, and nothing is applied before the
/// learner has seen it. An empty paragraph means "nothing worth adding" and is remembered so the card is not
/// offered again.
library;

import 'dart:convert';

import 'import_parser.dart' show kMaxReadMoreChars, stripCitationMarkers, stripCodeFence;
import 'keywords_prompt.dart' show stripClozeMarkup;

const kReadMoreTemplateVersion = 'readmore-v1';

/// Most cards one prompt carries (paragraphs make long replies), and most entries one answer may hold.
const kMaxReadMoreBatch = 30;
const kMaxReadMoreEntries = 60;

class ReadMoreCardRef {
  const ReadMoreCardRef({required this.noteId, required this.subject, required this.question, required this.answer, required this.why});
  final int noteId;
  final String subject, question, answer, why;
}

String _oneLine(String s, int max) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max - 1).trimRight()}…';
}

String renderReadMorePrompt(List<ReadMoreCardRef> cards) {
  final list = [
    for (final c in cards.take(kMaxReadMoreBatch))
      [
        '${c.noteId} | ${_oneLine(c.subject, 40)}',
        'Q: ${_oneLine(stripClozeMarkup(c.question), 220)}',
        if (c.answer.trim().isNotEmpty) 'A: ${_oneLine(stripClozeMarkup(c.answer), 120)}',
        if (c.why.trim().isNotEmpty) 'Why: ${_oneLine(c.why, 160)}',
      ].join(' | ')
  ].join('\n');
  return '''
You are a gifted, careful teacher. A learner has just seen the answer to each flashcard below and wants a bit more to read. For EACH card, write a "read_more" paragraph.

RULES
- "read_more": 120 to 150 words, one paragraph (1,100 characters at most): the next layer of the story, a related idea, a common misconception, or where it leads. Build on the answer; do not repeat it. Plain words, written for a bright teenager new to the field.
- Use "" for a card where nothing is worth adding (vocabulary, notation, names, dates).
- Only what you are highly confident of: never invent a quote, a statistic or a citation, and write "According to X, ..." for anything disputed. If you can search the web, check anything that may have changed over time.
- Plain text. **bold** (rarely) and *italic* are allowed; no headings, tables, links or emojis. Write every formula or quantity with a symbol or exponent as LaTeX between dollar signs (\$E = mc^2\$), and because your answer is JSON, write every backslash twice.
- Give exactly one entry per card, using the card's number as "id", copied exactly. Do not add, merge or skip cards. Do not rewrite the cards.
- A complete reply beats long paragraphs: if the whole reply might be too long to finish, shorten every "read_more" first.

OUTPUT
Return JSON ONLY: no text before or after, no markdown fences. Use exactly this shape:

{
  "read_more": [
    { "id": 123, "read_more": "One paragraph of about 120 to 150 words." }
  ]
}

CARDS (number | subject | question | answer | why it matters):
$list
''';
}

class ReadMoreEntry {
  const ReadMoreEntry({required this.index, required this.noteId, required this.text, required this.errors});
  final int index;
  final int? noteId;
  final String text;
  final List<String> errors;
  bool get valid => errors.isEmpty && noteId != null;

  /// A valid entry with an empty paragraph: the AI found nothing worth adding.
  bool get nothingToAdd => valid && text.isEmpty;
}

class ReadMorePreview {
  const ReadMorePreview({required this.entries, required this.fatalErrors});
  final List<ReadMoreEntry> entries;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
}

ReadMorePreview parseReadMoreJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(stripCitationMarkers(stripCodeFence(raw)));
  } on FormatException catch (e) {
    return ReadMorePreview(entries: const [], fatalErrors: ['Not valid JSON: ${e.message}']);
  }
  if (decoded is! Map || decoded['read_more'] is! List) {
    return const ReadMorePreview(entries: [], fatalErrors: ['Expected an object with a "read_more" list.']);
  }
  final list = decoded['read_more'] as List;
  if (list.isEmpty) return const ReadMorePreview(entries: [], fatalErrors: ['"read_more" is empty.']);
  if (list.length > kMaxReadMoreEntries) {
    return ReadMorePreview(entries: const [], fatalErrors: ['Too many entries (${list.length}); max $kMaxReadMoreEntries per paste.']);
  }
  final seen = <int>{};
  final out = <ReadMoreEntry>[];
  for (var i = 0; i < list.length; i++) {
    final e = list[i];
    final errors = <String>[];
    int? id;
    var text = '';
    if (e is! Map) {
      errors.add('Entry ${i + 1} is not an object.');
    } else {
      final rawId = e['id'];
      if (rawId is int) {
        id = rawId;
      } else {
        errors.add('"id" must be the card\'s number.');
      }
      if (id != null && !seen.add(id)) errors.add('Card $id appears twice; the first one is used.');
      final t = e['read_more'];
      if (t is! String) {
        errors.add('"read_more" must be text.');
      } else if (t.length > kMaxReadMoreChars) {
        errors.add('"read_more" is too long (max $kMaxReadMoreChars characters).');
      } else {
        text = t.trim();
      }
    }
    out.add(ReadMoreEntry(index: i, noteId: id, text: text, errors: errors));
  }
  return ReadMorePreview(entries: out, fatalErrors: const []);
}
