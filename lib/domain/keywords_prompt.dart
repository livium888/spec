/// The "image keywords for my older cards" prompt and its answer (pure; no Flutter, no I/O).
///
/// Cards made before prompt v4 have no `image_query`. The learner sends a batch of them to an AI
/// and pastes back a short list; each entry names a card by its number and gives the words to search
/// a free picture library with. The answer is UNTRUSTED text: ids and strings are type-checked,
/// keywords go through the same cleaner as everywhere else, and nothing is applied before the
/// learner has seen it.
library;

import 'dart:convert';

import 'commons.dart';
import 'import_parser.dart' show stripCitationMarkers, stripCodeFence;

const kKeywordsTemplateVersion = 'keywords-v1';

/// Most cards one prompt carries, and most entries one answer may hold.
const kMaxKeywordCards = 100;
const kMaxKeywordEntries = 200;

class KeywordCardRef {
  const KeywordCardRef({required this.noteId, required this.subject, required this.question, required this.answer});
  final int noteId;
  final String subject, question, answer;
}

String _oneLine(String s, int max) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max - 1).trimRight()}…';
}

/// `{{c1::mitochondria::hint}}` -> `mitochondria`, so the AI sees the whole sentence.
String stripClozeMarkup(String s) =>
    s.replaceAllMapped(RegExp(r'\{\{c\d+::(.*?)(?:::.*?)?\}\}', dotAll: true), (m) => m[1]!);

String renderKeywordsPrompt(List<KeywordCardRef> cards) {
  final list = [
    for (final c in cards.take(kMaxKeywordCards))
      '${c.noteId} | ${_oneLine(c.subject, 40)} | Q: ${_oneLine(stripClozeMarkup(c.question), 220)}'
          '${c.answer.trim().isEmpty ? '' : ' | A: ${_oneLine(stripClozeMarkup(c.answer), 120)}'}'
  ].join('\n');
  return '''
You are helping a learner add a picture to flashcards. For EACH card below, write the words that would find the best picture for it in a free image library (Wikimedia Commons, museum collections, Openverse).

RULES
- "image_query": 2 to 6 plain words someone would type into the search box. Name the thing the card is about as concretely as you can: a work of art with its artist, a building, a plant or animal with its species, an instrument, a place, a person, a diagram of the process. For an abstract idea, pick a concrete scene or object that illustrates it. NEVER a web address or a file name. The learner sees these words only when choosing a picture, so they may name the answer. A rough search is fine; do not invent details to make it exact.
- "image_side": "back" when the picture would give the answer away (the usual case), "front" only when the picture IS what the question asks about (for example "Which painting is this?").
- Give exactly one entry per card, using the card's number as "id", copied exactly. Do not add, merge or skip cards. Do not rewrite the cards.

OUTPUT
Return JSON ONLY: no text before or after, no markdown fences. Use exactly this shape:

{
  "image_keywords": [
    { "id": 123, "image_query": "mitochondrion electron micrograph", "image_side": "back" }
  ]
}

CARDS (number | subject | question | answer):
$list
''';
}

class KeywordEntry {
  const KeywordEntry({required this.index, required this.noteId, required this.query, required this.side, required this.errors});
  final int index;
  final int? noteId;
  final String query, side; // side: 'front', 'back' or '' (no hint)
  final List<String> errors;
  bool get valid => errors.isEmpty && noteId != null && query.isNotEmpty;
}

class KeywordsPreview {
  const KeywordsPreview({required this.entries, required this.fatalErrors});
  final List<KeywordEntry> entries;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
}

KeywordsPreview parseKeywordsJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(stripCitationMarkers(stripCodeFence(raw)));
  } on FormatException catch (e) {
    return KeywordsPreview(entries: const [], fatalErrors: ['Not valid JSON: ${e.message}']);
  }
  if (decoded is! Map || decoded['image_keywords'] is! List) {
    return const KeywordsPreview(entries: [], fatalErrors: ['Expected an object with an "image_keywords" list.']);
  }
  final list = decoded['image_keywords'] as List;
  if (list.isEmpty) return const KeywordsPreview(entries: [], fatalErrors: ['"image_keywords" is empty.']);
  if (list.length > kMaxKeywordEntries) {
    return KeywordsPreview(entries: const [], fatalErrors: ['Too many entries (${list.length}); max $kMaxKeywordEntries per paste.']);
  }
  final seen = <int>{};
  final out = <KeywordEntry>[];
  for (var i = 0; i < list.length; i++) {
    final e = list[i];
    final errors = <String>[];
    int? id;
    var query = '';
    var side = '';
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
      final q = cleanImageQuery(e['image_query']);
      if (q == null) {
        errors.add('"image_query" must be a few plain words (up to $kMaxImageQueryChars characters), not a web address.');
      } else {
        query = q;
      }
      final s = e['image_side'];
      side = s == 'front' || s == 'back' ? s as String : '';
    }
    out.add(KeywordEntry(index: i, noteId: id, query: query, side: side, errors: errors));
  }
  return KeywordsPreview(entries: out, fatalErrors: const []);
}
