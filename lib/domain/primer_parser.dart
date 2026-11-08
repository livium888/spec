/// A primer (D67/D68): a short reading, tied to one topic of a subject, that the learner does before the cards. It is
/// written outside the app (by the learner's own AI, from a lecture transcript or their notes) and imported as JSON.
/// Strict and pure: the text is UNTRUSTED, every field is type-checked and length-capped, nothing is ever rendered as
/// markup beyond the card formatting the reader already supports.
library;

import 'dart:convert';

import 'import_parser.dart' show repairJsonStrings, stripCitationMarkers, stripCodeFence;

const kMaxPrimersPerImport = 20;
const kMaxPretest = 5;
const kMaxPretestChars = 600;
const kMaxSections = 12;
const kMaxHeadingChars = 80;
const kMaxSectionChars = 2500;
const kMaxKeyPoints = 8;
const kMaxKeyPointChars = 200;
const kMaxSources = 10;
const kMaxSourceChars = 300;
const kMaxPrimerChars = 14000;
const kMaxPrimerTitleChars = 120;
const kMaxTopicTitleChars = 200;
const kMaxDomainChars = 100;

class PretestItem {
  const PretestItem(this.question, this.answer);
  final String question, answer;
}

class PrimerSection {
  const PrimerSection(this.heading, this.text);
  final String heading, text;
}

class ParsedPrimer {
  ParsedPrimer({
    required this.index,
    this.domain = '',
    this.topic = '',
    this.title = '',
    this.level = 1,
    this.pretest = const [],
    this.sections = const [],
    this.keyPoints = const [],
    this.sources = const [],
    this.errors = const [],
  });
  final int index;
  final String domain, topic, title;

  /// 1 foundation, 2 core, 3 advanced; 1 when not given.
  final int level;
  final List<PretestItem> pretest;
  final List<PrimerSection> sections;
  final List<String> keyPoints, sources;
  final List<String> errors;
  bool get valid => errors.isEmpty;

  int get words => [
        for (final s in sections) ...[s.heading, s.text],
        for (final k in keyPoints) k,
      ].fold<int>(0, (a, t) => a + (t.trim().isEmpty ? 0 : t.trim().split(RegExp(r'\s+')).length));

  /// About 200 words a minute, at least one.
  int get minutes => (words / 200).ceil().clamp(1, 99);

  int get chars =>
      pretest.fold<int>(0, (a, p) => a + p.question.length + p.answer.length) +
      sections.fold<int>(0, (a, s) => a + s.heading.length + s.text.length) +
      keyPoints.fold<int>(0, (a, k) => a + k.length);
}

class PrimerPreview {
  const PrimerPreview({required this.primers, required this.fatalErrors});
  final List<ParsedPrimer> primers;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
}

PrimerPreview parsePrimerJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(repairJsonStrings(stripCitationMarkers(stripCodeFence(raw))));
  } on FormatException catch (e) {
    return PrimerPreview(primers: const [], fatalErrors: ['Not valid JSON: ${e.message}']);
  }
  if (decoded is! Map<String, dynamic>) {
    return const PrimerPreview(primers: [], fatalErrors: ['Top level must be a JSON object.']);
  }
  final one = decoded['primer'];
  final many = decoded['primers'];
  final List<Object?> items;
  if (many is List) {
    if (many.isEmpty) return const PrimerPreview(primers: [], fatalErrors: ['"primers" is empty.']);
    if (many.length > kMaxPrimersPerImport) {
      return PrimerPreview(primers: const [], fatalErrors: ['Too many primers (${many.length}); max $kMaxPrimersPerImport per import.']);
    }
    items = many;
  } else if (one is Map) {
    items = [one];
  } else {
    return const PrimerPreview(primers: [], fatalErrors: ['Expected an object with a "primer" object or a "primers" list.']);
  }
  return PrimerPreview(primers: [for (var i = 0; i < items.length; i++) _parsePrimer(i, items[i])], fatalErrors: const []);
}

ParsedPrimer _parsePrimer(int i, Object? raw) {
  if (raw is! Map<String, dynamic>) return ParsedPrimer(index: i, errors: ['A primer must be an object.']);
  final errors = <String>[];

  String str(Map<String, dynamic> m, String key, {bool required = false, required int max, String where = ''}) {
    final v = m[key];
    final name = where.isEmpty ? '"$key"' : '"$key" in $where';
    if (v == null) {
      if (required) errors.add('$name is required.');
      return '';
    }
    if (v is! String) {
      errors.add('$name must be text.');
      return '';
    }
    final t = v.trim();
    if (t.length > max) {
      errors.add('$name is too long (max $max characters).');
      return '';
    }
    if (required && t.isEmpty) errors.add('$name must not be empty.');
    return t;
  }

  final domain = str(raw, 'domain', required: true, max: kMaxDomainChars);
  final topic = str(raw, 'topic', required: true, max: kMaxTopicTitleChars);
  final title = str(raw, 'title', max: kMaxPrimerTitleChars);

  var level = 1;
  final lv = raw['level'];
  if (lv != null) {
    final n = lv is int ? lv : (lv is String ? int.tryParse(lv.trim()) : null);
    if (n == null || n < 1 || n > 3) {
      errors.add('"level" must be 1, 2 or 3.');
    } else {
      level = n;
    }
  }

  final pretest = <PretestItem>[];
  final pt = raw['pretest'];
  if (pt != null) {
    if (pt is! List) {
      errors.add('"pretest" must be a list.');
    } else if (pt.length > kMaxPretest) {
      errors.add('Too many pretest questions (max $kMaxPretest).');
    } else {
      for (final e in pt) {
        if (e is! Map<String, dynamic>) {
          errors.add('A pretest item must be an object with "question" and "answer".');
          continue;
        }
        final q = str(e, 'question', required: true, max: kMaxPretestChars, where: 'a pretest item');
        final a = str(e, 'answer', required: true, max: kMaxPretestChars, where: 'a pretest item');
        if (q.isNotEmpty && a.isNotEmpty) pretest.add(PretestItem(q, a));
      }
    }
  }

  final sections = <PrimerSection>[];
  final sc = raw['sections'];
  if (sc is! List || sc.isEmpty) {
    errors.add('"sections" must be a list with at least one section.');
  } else if (sc.length > kMaxSections) {
    errors.add('Too many sections (max $kMaxSections).');
  } else {
    for (final e in sc) {
      if (e is! Map<String, dynamic>) {
        errors.add('A section must be an object with "heading" and "text".');
        continue;
      }
      final h = str(e, 'heading', max: kMaxHeadingChars, where: 'a section');
      final t = str(e, 'text', required: true, max: kMaxSectionChars, where: 'a section');
      if (t.isNotEmpty) sections.add(PrimerSection(h, t));
    }
  }

  List<String> strings(String key, int maxItems, int maxChars) {
    final v = raw[key];
    if (v == null) return const [];
    if (v is! List || v.any((x) => x is! String)) {
      errors.add('"$key" must be a list of text.');
      return const [];
    }
    if (v.length > maxItems) {
      errors.add('Too many entries in "$key" (max $maxItems).');
      return const [];
    }
    final out = <String>[];
    for (final s in v.cast<String>()) {
      final t = s.trim();
      if (t.length > maxChars) {
        errors.add('An entry in "$key" is too long (max $maxChars characters).');
      } else if (t.isNotEmpty) {
        out.add(t);
      }
    }
    return out;
  }

  final keyPoints = strings('key_points', kMaxKeyPoints, kMaxKeyPointChars);
  final sources = strings('sources', kMaxSources, kMaxSourceChars);

  final p = ParsedPrimer(
    index: i,
    domain: domain,
    topic: topic,
    title: title,
    level: level,
    pretest: pretest,
    sections: sections,
    keyPoints: keyPoints,
    sources: sources,
    errors: errors,
  );
  if (p.chars > kMaxPrimerChars) {
    errors.add('The primer is too long (${p.chars} characters; max $kMaxPrimerChars, about 8 minutes of reading). Split it into two topics.');
  }
  return p;
}

/// What is stored for a primer: only the parts the reader shows. (The subject, topic, title and level are columns.)
String primerContentJson(ParsedPrimer p) => jsonEncode({
      'pretest': [for (final t in p.pretest) {'question': t.question, 'answer': t.answer}],
      'sections': [for (final x in p.sections) {'heading': x.heading, 'text': x.text}],
      'key_points': p.keyPoints,
      'sources': p.sources,
    });

/// A stored primer read back. A restored backup is outside input, so this never throws and never trusts a size: anything
/// that is not text, or is over the limits, is dropped.
ParsedPrimer primerFromStored({required String domain, required String topic, required String title, required int level, required String content}) {
  Object? d;
  try {
    d = jsonDecode(content);
  } catch (_) {
    d = null;
  }
  final m = d is Map ? d : const {};
  List<Map> maps(String key, int max) => m[key] is List ? [for (final e in (m[key] as List).take(max)) if (e is Map) e] : const [];
  String t(Object? v, int max) => v is String ? (v.length > max ? v.substring(0, max) : v) : '';
  List<String> strs(String key, int max, int len) =>
      m[key] is List ? [for (final e in (m[key] as List).take(max)) if (e is String && e.trim().isNotEmpty) t(e.trim(), len)] : const [];
  return ParsedPrimer(
    index: 0,
    domain: domain,
    topic: topic,
    title: title,
    level: level.clamp(1, 3),
    pretest: [
      for (final e in maps('pretest', kMaxPretest))
        if (t(e['question'], kMaxPretestChars).isNotEmpty) PretestItem(t(e['question'], kMaxPretestChars), t(e['answer'], kMaxPretestChars)),
    ],
    sections: [
      for (final e in maps('sections', kMaxSections))
        if (t(e['text'], kMaxSectionChars).isNotEmpty) PrimerSection(t(e['heading'], kMaxHeadingChars), t(e['text'], kMaxSectionChars)),
    ],
    keyPoints: strs('key_points', kMaxKeyPoints, kMaxKeyPointChars),
    sources: strs('sources', kMaxSources, kMaxSourceChars),
  );
}
