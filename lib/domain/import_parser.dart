import 'dart:convert';

import 'cloze.dart';
import 'commons.dart' show cleanImageQuery;
import 'expr_eval.dart';
import 'reading.dart' show ReadingSuggestion, parseFurtherReading;

/// Strict, pure validation of LLM-produced JSON. UNTRUSTED input: every field
/// is type-checked and length-capped; nothing is ever evaluated or rendered as
/// markup.
const kMaxCardsPerImport = 200;
const kMaxFieldChars = 2000;
const kMaxExtraChars = 600;
const kMaxTags = 12;

const _types = {'basic', 'cloze'};

/// Problem families (D43): limits.
const kMaxProblemsPerImport = 6;
const kMaxProblemSteps = 6;
const kMinProblemSteps = 2;
const kMaxProblemVariants = 2;
const _sourceTypes = {'quote', 'url', 'model_memory'};
const _confidences = {'high', 'medium', 'low'};

class ParsedCard {
  ParsedCard({
    required this.index,
    this.type = '',
    this.front = '',
    this.back = '',
    this.cloze = '',
    this.sourceType = '',
    this.sourceRef = '',
    this.supportingQuote = '',
    this.confidence = '',
    this.tags = const [],
    this.errors = const [],
    this.whyItMatters = '',
    this.example = '',
    this.memoryHook = '',
    this.imageQuery = '',
    this.imageSide = '',
    this.steps = const [],
    this.variants = const [],
    this.arithmetic = '',
    this.image = '',
  });

  /// A picture already stored for this card (SHA-256 in the media table), set by the Anki import (D50). An
  /// AI answer never sets it: the JSON parser does not read it. The picture goes on [imageSide].
  final String image;

  /// Problem families (type 'problem'): the worked steps (one per line), further problems of the same
  /// kind with other numbers, and what the arithmetic check said: '' (nothing to check), 'checked'.
  final List<String> steps;
  final List<ParsedVariant> variants;
  final String arithmetic;

  final int index; // 0-based position in the payload
  final String type, front, back, cloze, sourceType, sourceRef, supportingQuote, confidence;

  /// Optional answer-side extras: the story / reason, a concrete example, a memory hook.
  final String whyItMatters, example, memoryHook;

  /// Optional hint for "Find a picture": a few words to search Wikimedia Commons for. Never a URL.
  final String imageQuery;

  /// Optional hint for where a picture should go: "front" only if the picture is what the question
  /// asks about; "back" if it would give the answer away. Anything else is ignored.
  final String imageSide;
  final List<String> tags;
  final List<String> errors;

  bool get valid => errors.isEmpty;

  /// Low confidence or model-memory-only cards are imported but flagged.
  bool get unverified => confidence == 'low' || sourceType == 'model_memory';

  /// Text used for dedupe: front for basic, cloze text for cloze.
  String get dedupeText => type == 'cloze' ? cloze : front;

  /// Distinct cloze numbers, e.g. {1,2} for "{{c1::a}} {{c2::b}}".
  Set<int> get clozeNumbers => clozeNumbersOf(cloze);
}

/// A further problem of the same kind with other numbers (final level only).
class ParsedVariant {
  const ParsedVariant({required this.statement, required this.answer, this.steps = const []});
  final String statement, answer;
  final List<String> steps;
}

enum PreviewStatus { ok, invalid, duplicateInDb, duplicateInPayload }

class ImportPreview {
  ImportPreview({
    required this.domain,
    required this.syllabusItem,
    required this.cards,
    required this.fatalErrors,
    this.reading = const [],
    this.foundationOf,
    this.trackPrompt = true,
  });

  /// False for cards that do not answer a prompt the app wrote (the Anki import): the prompt log is left alone.
  final bool trackPrompt;

  /// Set when the answer is to a "build the foundations" prompt: the note the new cards prepare for.
  final int? foundationOf;

  /// Further reading the AI suggested for this topic (optional; never makes an import fail).
  final List<ReadingSuggestion> reading;

  /// The subject the cards go to. Normally what the AI wrote; the data layer may replace it with
  /// the subject of the prompt the learner copied when the AI renamed it (see [renamedFrom]).
  String domain;
  final String? syllabusItem;
  final List<ParsedCard> cards;
  final List<String> fatalErrors;

  /// What the AI wrote as the subject, when it was matched to the subject of the prompt instead.
  String? renamedFrom;

  /// Filled by the data layer (DB dedupe).
  final Map<int, PreviewStatus> status = {};
  bool newDomain = false;

  bool get hasFatal => fatalErrors.isNotEmpty;
  Iterable<ParsedCard> get importable =>
      cards.where((c) => status[c.index] == PreviewStatus.ok);
}

/// Tags the app sets itself; an AI cannot claim them (a "leech" tag from an AI would mark a card as hard).
const kReservedTags = {'leech', 'unverified', 'foundation', 'problem', 'marked'};

/// One tag, tidied (spaces become "_", lower case, at most 40 characters), or nothing if it is empty or reserved.
List<String> cleanTag(String t) {
  final clean = t.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  return clean.isEmpty || clean.length > 40 || kReservedTags.contains(clean) ? const [] : [clean];
}

/// Normalised key for dedupe: strip tags, lowercase, drop punctuation, collapse space.
String normalizeText(String s) => s
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// Removes a ```json fence if the LLM wrapped its output; nothing else is "fixed".
String stripCodeFence(String raw) {
  final t = raw.trim();
  final m = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n?```$').firstMatch(t);
  return m != null ? m.group(1)!.trim() : t;
}

/// Is there an unescaped "$" between [from] and the end of the current JSON string?
bool _closesLater(String raw, int from) {
  var i = from;
  while (i < raw.length) {
    final c = raw[i];
    if (c == '"') return false;
    if (c == r'\') {
      i += 2; // an escape pair, including a doubled backslash and an escaped dollar
      continue;
    }
    if (c == r'$') return true;
    i++;
  }
  return false;
}

/// Does the backslash before [at] start a TeX command (not a JSON escape)? [at] is the first letter.
/// Only \b \f \n \r \t \u are also JSON escapes. Inside a formula such a letter followed by another
/// letter is a command (\nabla, \textcolor, \bigoplus, \underbrace); a JSON line break or tab is followed
/// by something else, and a formula never holds a line break.
bool _isTexCommandAt(String raw, int at, RegExp hex) {
  final first = raw[at];
  if (!'bfnrtu'.contains(first)) return true; // not a JSON escape letter: only TeX can mean it
  if (first == 'u' && at + 5 <= raw.length && hex.hasMatch(raw.substring(at + 1, at + 5))) return false; // \u00e9
  return at + 1 < raw.length && RegExp(r'[a-zA-Z]').hasMatch(raw[at + 1]);
}

/// Repairs what chat apps do to LaTeX inside a JSON answer, touching only the inside of string values:
/// * a single backslash before a TeX command inside $...$ ("$\frac{a}{b}$") is doubled, because JSON
///   would read \f \t \b \r \n as control characters and break the formula;
/// * a backslash that JSON does not allow (e.g. "\$", "\(") is doubled so the text still parses;
/// * a raw line break or tab inside a string becomes \n or \t.
/// Anything else, including correctly doubled backslashes, is left exactly as written.
String repairJsonStrings(String raw) {
  const bs = r'\';
  final out = StringBuffer();
  var inString = false;
  var inMath = false; // inside $...$ or $$...$$ of a string
  final hex = RegExp(r'^[0-9a-fA-F]{4}$');
  final letter = RegExp(r'[a-zA-Z]');
  const validEscape = '"\\/bfnrtu';
  var i = 0;
  while (i < raw.length) {
    final c = raw[i];
    final next = i + 1 < raw.length ? raw[i + 1] : '';
    if (!inString) {
      if (c == '"') inString = true;
      out.write(c);
      i++;
    } else if (c == '"') {
      inString = false;
      inMath = false;
      out.write(c);
      i++;
    } else if (c == bs) {
      if (next == bs) {
        // A correctly doubled backslash. A "$" right after it is a literal dollar, not a maths delimiter.
        out.write('$bs$bs');
        i += 2;
        if (i < raw.length && raw[i] == r'$') {
          out.write(r'$');
          i++;
        }
      } else if (next == r'$') {
        out.write('$bs$bs\$'); // JSON has no "\$": a doubled backslash and the dollar, kept literal
        i += 2;
      } else if (inMath && letter.hasMatch(next) && _isTexCommandAt(raw, i + 1, hex)) {
        out.write('$bs$bs'); // a TeX command written with one backslash; the letter follows next
        i++;
      } else if (next.isNotEmpty && !validEscape.contains(next)) {
        out.write('$bs$bs');
        i++;
      } else {
        out.write(c);
        out.write(next);
        i += 2;
      }
    } else if (c == r'$') {
      out.write(c);
      i++;
      if (next == r'$') {
        out.write(r'$'); // "$$" is one delimiter
        i++;
      }
      // A "$" opens maths only if another one closes it before the string ends: "costs $5." is money.
      inMath = inMath ? false : _closesLater(raw, i);
    } else if (c == '\n') {
      out.write('${bs}n');
      i++;
    } else if (c == '\r') {
      out.write('${bs}n');
      i += next == '\n' ? 2 : 1;
    } else if (c == '\t') {
      out.write('${bs}t');
      i++;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Chat apps that search the web can leave reference markers inside the text they write: private-use
/// "cite" tokens (U+E200 ... U+E201) and 【4:0†source】 brackets (a number, then a dagger). They can never be JSON structure, only
/// part of a string, so removing them is safe. Plain "[1]" is left alone (it can be real card text).
String stripCitationMarkers(String raw) => raw
    .replaceAll(RegExp('\uE200[^\uE201]*\uE201'), '')
    .replaceAll(RegExp('【\\d+(?:[:：]\\d+)?†[^】]*】'), '') // 【4:0†source】, never real text like 【名詞】
    .replaceAll(RegExp('[\uE200-\uE2FF]'), '');

ImportPreview parseImportJson(String raw) {
  final fatal = <String>[];
  Object? decoded;
  try {
    decoded = jsonDecode(repairJsonStrings(stripCitationMarkers(stripCodeFence(raw))));
  } on FormatException catch (e) {
    return ImportPreview(
        domain: '', syllabusItem: null, cards: [], fatalErrors: ['Not valid JSON: ${e.message}']);
  }
  if (decoded is! Map<String, dynamic>) {
    return ImportPreview(
        domain: '', syllabusItem: null, cards: [], fatalErrors: ['Top level must be a JSON object.']);
  }

  final domain = decoded['domain'];
  if (domain is! String || domain.trim().isEmpty) {
    fatal.add('"domain" must be a non-empty string.');
  } else if (domain.length > 100) {
    fatal.add('"domain" is too long (max 100).');
  }
  final syl = decoded['syllabus_item'];
  if (syl != null && syl is! String) fatal.add('"syllabus_item" must be a string or null.');

  final cardsRaw = decoded['cards'];
  final problemsRaw = decoded['problems'];
  final hasProblems = problemsRaw is List && problemsRaw.isNotEmpty;
  final cards = <ParsedCard>[];
  if (cardsRaw == null && hasProblems) {
    // An answer with problems only is fine.
  } else if (cardsRaw is! List) {
    fatal.add('"cards" must be an array.');
  } else if (cardsRaw.isEmpty && !hasProblems) {
    fatal.add('"cards" is empty.');
  } else if (cardsRaw.length > kMaxCardsPerImport) {
    fatal.add('Too many cards (${cardsRaw.length}); max $kMaxCardsPerImport per import.');
  } else {
    for (var i = 0; i < cardsRaw.length; i++) {
      cards.add(_parseCard(i, cardsRaw[i]));
    }
  }
  if (problemsRaw is List) {
    for (var i = 0; i < problemsRaw.length && i < kMaxProblemsPerImport + 20; i++) {
      final p = _parseProblem(cards.length, problemsRaw[i]);
      // More than the limit are listed, not silently dropped: each one shows as invalid with the reason.
      cards.add(i < kMaxProblemsPerImport
          ? p
          : ParsedCard(index: p.index, type: 'problem', front: p.front, errors: ['Too many problems in one answer (the limit is $kMaxProblemsPerImport); ask for the rest separately.']));
    }
  } else if (problemsRaw != null) {
    fatal.add('"problems" must be an array.');
  }

  return ImportPreview(
    domain: domain is String ? domain.trim() : '',
    syllabusItem: syl is String && syl.trim().isNotEmpty ? syl.trim() : null,
    cards: cards,
    fatalErrors: fatal,
    reading: parseFurtherReading(decoded['further_reading']),
    foundationOf: _positiveInt(decoded['foundation_of']),
  );
}

int? _positiveInt(Object? v) {
  final n = v is int ? v : (v is String ? int.tryParse(v.trim()) : null);
  return n != null && n > 0 ? n : null;
}

/// One problem family: a statement, 2-6 worked steps, the final answer, optional variants. The app
/// does the arithmetic itself when "answer_expr" and "answer_value" are both given.
ParsedCard _parseProblem(int i, Object? raw) {
  if (raw is! Map<String, dynamic>) return ParsedCard(index: i, type: 'problem', errors: ['Problem must be an object.']);
  final errors = <String>[];

  String str(Map<String, dynamic> m, String key, {bool required = false, int max = kMaxFieldChars}) {
    final v = m[key];
    if (v == null) {
      if (required) errors.add('"$key" is required.');
      return '';
    }
    if (v is! String) {
      errors.add('"$key" must be a string.');
      return '';
    }
    if (v.length > max) {
      errors.add('"$key" is too long (max $max).');
      return '';
    }
    final t = v.trim();
    if (required && t.isEmpty) errors.add('"$key" must not be empty.');
    return t;
  }

  List<String> stepsOf(Map<String, dynamic> m, {required bool required}) {
    final v = m['steps'];
    if (v == null) {
      if (required) errors.add('"steps" is required.');
      return const [];
    }
    if (v is! List) {
      errors.add('"steps" must be an array of strings.');
      return const [];
    }
    final out = <String>[];
    for (final e in v) {
      if (e is! String || e.trim().isEmpty || e.length > 400) {
        errors.add('Each step must be a non-empty string of at most 400 characters.');
        return const [];
      }
      out.add(e.trim().replaceAll(RegExp(r'\s*\n\s*'), ' '));
    }
    if (required && (out.length < kMinProblemSteps || out.length > kMaxProblemSteps)) {
      errors.add('"steps" needs $kMinProblemSteps to $kMaxProblemSteps steps.');
      return const [];
    }
    if (out.length > kMaxProblemSteps) {
      errors.add('Too many steps.');
      return const [];
    }
    return out;
  }

  // The arithmetic check: the answer's number against the expression that should give it.
  String check(Map<String, dynamic> m, String label) {
    final expr = m['answer_expr'];
    final value = m['answer_value'];
    if (expr == null || value == null) return '';
    if (expr is! String || value is! num) {
      errors.add('$label: "answer_expr" must be text and "answer_value" a number.');
      return '';
    }
    final exact = evalExpression(expr);
    if (exact == null) return ''; // not something the calculator understands: skipped, not an error
    if (!numbersAgree(value.toDouble(), exact)) {
      errors.add('$label: arithmetic check failed. The answer says $value but the working gives ${_short(exact)}.');
      return '';
    }
    return 'checked';
  }

  final statement = str(raw, 'statement', required: true);
  final steps = stepsOf(raw, required: true);
  final answer = str(raw, 'answer', required: true, max: 300);
  final arithmetic = check(raw, 'Problem');
  final why = str(raw, 'why_it_matters', max: kMaxExtraChars);
  final tags = <String>[];
  if (raw['tags'] is List) {
    for (final t in (raw['tags'] as List).take(kMaxTags)) {
      if (t is String) tags.addAll(cleanTag(t));
    }
  }
  final variants = <ParsedVariant>[];
  final vr = raw['variants'];
  if (vr is List) {
    for (final v in vr.take(kMaxProblemVariants)) {
      if (v is! Map<String, dynamic>) {
        errors.add('A variant must be an object.');
        continue;
      }
      final st = str(v, 'statement', required: true);
      final an = str(v, 'answer', required: true, max: 300);
      final vs = stepsOf(v, required: false);
      check(v, 'Variant'); // a wrong variant rejects the whole family (see errors)
      if (st.isNotEmpty && an.isNotEmpty) variants.add(ParsedVariant(statement: st, answer: an, steps: vs));
    }
  } else if (vr != null) {
    errors.add('"variants" must be an array.');
  }
  final confidence = str(raw, 'confidence');

  return ParsedCard(
    index: i,
    type: 'problem',
    front: statement,
    back: answer,
    steps: steps,
    variants: variants,
    arithmetic: arithmetic,
    whyItMatters: why,
    tags: tags,
    sourceType: 'model_memory',
    confidence: const {'high', 'medium', 'low'}.contains(confidence) ? confidence : 'medium',
    imageQuery: cleanImageQuery(raw['image_query']) ?? '',
    imageSide: 'back',
    errors: errors,
  );
}

String _short(double v) => v.abs() >= 1000 || (v != 0 && v.abs() < 0.01) ? v.toStringAsExponential(3) : v.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

ParsedCard _parseCard(int i, Object? raw) {
  if (raw is! Map<String, dynamic>) {
    return ParsedCard(index: i, errors: ['Card must be an object.']);
  }
  final errors = <String>[];

  String str(String key, {bool required = false}) {
    final v = raw[key];
    if (v == null) {
      if (required) errors.add('"$key" is required.');
      return '';
    }
    if (v is! String) {
      errors.add('"$key" must be a string.');
      return '';
    }
    if (v.length > kMaxFieldChars) {
      errors.add('"$key" is too long (max $kMaxFieldChars).');
      return '';
    }
    final t = v.trim();
    if (required && t.isEmpty) errors.add('"$key" must not be empty.');
    return t;
  }

  final type = str('type', required: true);
  if (type.isNotEmpty && !_types.contains(type)) errors.add('"type" must be basic or cloze.');

  var front = '', back = '', cloze = '';
  if (type == 'basic') {
    front = str('front', required: true);
    back = str('back', required: true);
  } else if (type == 'cloze') {
    cloze = str('cloze', required: true);
    back = str('back');
    if (cloze.isNotEmpty && findClozes(cloze).isEmpty) {
      errors.add('"cloze" must contain {{c1::...}}.');
    }
  }

  final sourceType = str('source_type', required: true);
  if (sourceType.isNotEmpty && !_sourceTypes.contains(sourceType)) {
    errors.add('"source_type" must be quote, url or model_memory.');
  }
  final sourceRef = str('source_ref');
  final quote = str('supporting_quote');
  if ((sourceType == 'quote' || sourceType == 'url') && quote.isEmpty && sourceRef.isEmpty) {
    errors.add('Needs a supporting_quote or source_ref (no card without a quote or URL).');
  }
  if (sourceType == 'url' && sourceRef.isNotEmpty && !_looksLikeHttpUrl(sourceRef)) {
    errors.add('source_ref must be an http(s) URL when source_type is url.');
  }

  String extra(String key) {
    final v = raw[key];
    if (v == null) return '';
    if (v is! String) {
      errors.add('"$key" must be a string.');
      return '';
    }
    if (v.length > kMaxExtraChars) {
      errors.add('"$key" is too long (max $kMaxExtraChars). Keep it to a sentence or two.');
      return '';
    }
    return v.trim();
  }

  final why = extra('why_it_matters');
  final example = extra('example');
  final hook = extra('memory_hook');
  // Only a hint: a missing, odd or URL-like value is dropped quietly, never a reason to refuse the card.
  final imageQuery = cleanImageQuery(raw['image_query']) ?? '';
  final sideRaw = raw['image_side'];
  final imageSide = sideRaw == 'front' || sideRaw == 'back' ? sideRaw as String : '';

  final confidence = str('confidence', required: true);
  if (confidence.isNotEmpty && !_confidences.contains(confidence)) {
    errors.add('"confidence" must be high, medium or low.');
  }

  final tags = <String>[];
  final tagsRaw = raw['tags'];
  if (tagsRaw != null) {
    if (tagsRaw is! List || tagsRaw.any((t) => t is! String)) {
      errors.add('"tags" must be an array of strings.');
    } else if (tagsRaw.length > kMaxTags) {
      errors.add('Too many tags (max $kMaxTags).');
    } else {
      for (final t in tagsRaw.cast<String>()) {
        tags.addAll(cleanTag(t));
      }
    }
  }

  return ParsedCard(
    index: i,
    type: type,
    front: front,
    back: back,
    cloze: cloze,
    sourceType: sourceType,
    sourceRef: sourceRef,
    supportingQuote: quote,
    confidence: confidence,
    tags: tags,
    errors: errors,
    whyItMatters: why,
    example: example,
    memoryHook: hook,
    imageQuery: imageQuery,
    imageSide: imageSide,
  );
}

bool _looksLikeHttpUrl(String s) {
  final u = Uri.tryParse(s);
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}
