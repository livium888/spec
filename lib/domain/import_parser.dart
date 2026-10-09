import 'dart:convert';

import 'commons.dart' show cleanImageQuery;

/// Strict, pure validation of LLM-produced JSON. UNTRUSTED input: every field
/// is type-checked and length-capped; nothing is ever evaluated or rendered as
/// markup.
const kMaxCardsPerImport = 200;
const kMaxFieldChars = 2000;
const kMaxExtraChars = 600;
const kMaxTags = 12;

const _types = {'basic', 'cloze'};
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
  });

  final int index; // 0-based position in the payload
  final String type, front, back, cloze, sourceType, sourceRef, supportingQuote, confidence;

  /// Optional answer-side extras: the story / reason, a concrete example, a memory hook.
  final String whyItMatters, example, memoryHook;

  /// Optional hint for "Find a picture": a few words to search Wikimedia Commons for. Never a URL.
  final String imageQuery;
  final List<String> tags;
  final List<String> errors;

  bool get valid => errors.isEmpty;

  /// Low confidence or model-memory-only cards are imported but flagged.
  bool get unverified => confidence == 'low' || sourceType == 'model_memory';

  /// Text used for dedupe: front for basic, cloze text for cloze.
  String get dedupeText => type == 'cloze' ? cloze : front;

  /// Distinct cloze numbers, e.g. {1,2} for "{{c1::a}} {{c2::b}}".
  Set<int> get clozeNumbers =>
      {for (final m in clozeRe.allMatches(cloze)) int.parse(m[1]!)};

  static final clozeRe = RegExp(r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}', dotAll: true);
}

enum PreviewStatus { ok, invalid, duplicateInDb, duplicateInPayload }

class ImportPreview {
  ImportPreview({
    required this.domain,
    required this.syllabusItem,
    required this.cards,
    required this.fatalErrors,
  });

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

ImportPreview parseImportJson(String raw) {
  final fatal = <String>[];
  Object? decoded;
  try {
    decoded = jsonDecode(stripCodeFence(raw));
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
  final cards = <ParsedCard>[];
  if (cardsRaw is! List) {
    fatal.add('"cards" must be an array.');
  } else if (cardsRaw.isEmpty) {
    fatal.add('"cards" is empty.');
  } else if (cardsRaw.length > kMaxCardsPerImport) {
    fatal.add('Too many cards (${cardsRaw.length}); max $kMaxCardsPerImport per import.');
  } else {
    for (var i = 0; i < cardsRaw.length; i++) {
      cards.add(_parseCard(i, cardsRaw[i]));
    }
  }

  return ImportPreview(
    domain: domain is String ? domain.trim() : '',
    syllabusItem: syl is String && syl.trim().isNotEmpty ? syl.trim() : null,
    cards: cards,
    fatalErrors: fatal,
  );
}

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
    if (cloze.isNotEmpty && !ParsedCard.clozeRe.hasMatch(cloze)) {
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
        final clean = t.trim().replaceAll(RegExp(r'\s+'), '_');
        if (clean.isNotEmpty && clean.length <= 40) tags.add(clean);
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
  );
}

bool _looksLikeHttpUrl(String s) {
  final u = Uri.tryParse(s);
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}
