import 'dart:convert';

import 'import_parser.dart' show normalizeText, stripCodeFence;
import 'outline_parser.dart';

/// Several subjects, each with an outline, in one answer (the "map" prompt's reply).
/// UNTRUSTED LLM output: every subject goes through the same strict outline checks.
const kMaxPlanSubjects = 8;
const kMaxWhyChars = 300;

class ParsedSubject {
  ParsedSubject({required this.index, required this.outline, required this.why});
  final int index;
  final OutlinePreview outline;
  final String why;

  String get name => outline.domain;
  bool get valid => !outline.hasFatal;
}

class PlanPreview {
  PlanPreview({required this.subjects, required this.fatalErrors});
  final List<ParsedSubject> subjects;
  final List<String> fatalErrors;
  bool get hasFatal => fatalErrors.isNotEmpty;
  Iterable<ParsedSubject> get importable => subjects.where((s) => s.valid && s.outline.importable.isNotEmpty);
}

PlanPreview parsePlanJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(stripCodeFence(raw));
  } on FormatException catch (e) {
    return PlanPreview(subjects: [], fatalErrors: ['Not valid JSON: ${e.message}']);
  }
  if (decoded is! Map<String, dynamic> || decoded['subjects'] is! List) {
    return PlanPreview(subjects: [], fatalErrors: ['Expected an object with a "subjects" array.']);
  }
  final list = decoded['subjects'] as List;
  if (list.isEmpty) return PlanPreview(subjects: [], fatalErrors: ['"subjects" is empty.']);
  if (list.length > kMaxPlanSubjects) {
    return PlanPreview(subjects: [], fatalErrors: ['Too many subjects (${list.length}); max $kMaxPlanSubjects per paste.']);
  }
  final out = <ParsedSubject>[];
  final seen = <String>{};
  for (var i = 0; i < list.length; i++) {
    final s = list[i];
    if (s is! Map<String, dynamic>) {
      out.add(ParsedSubject(
          index: i,
          outline: OutlinePreview(domain: '', items: [], fatalErrors: ['Subject ${i + 1} must be an object.']),
          why: ''));
      continue;
    }
    final outline = parseOutlineJson(jsonEncode({'domain': s['domain'], 'items': s['items']}));
    if (outline.domain.isNotEmpty && !seen.add(normalizeText(outline.domain))) {
      outline.fatalErrors.add('"${outline.domain}" appears twice in this paste.');
    }
    var why = s['why'] is String ? (s['why'] as String).trim() : '';
    if (why.length > kMaxWhyChars) why = why.substring(0, kMaxWhyChars);
    out.add(ParsedSubject(index: i, outline: outline, why: why));
  }
  return PlanPreview(subjects: out, fatalErrors: const []);
}
