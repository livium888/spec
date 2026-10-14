import 'dart:convert';

import 'import_parser.dart' show normalizeText, stripCitationMarkers, stripCodeFence;

/// Outline = ordered list of topics (syllabus items) with prerequisites.
/// UNTRUSTED LLM output: strictly validated, length-capped, never evaluated.
const kMaxOutlineItems = 60;
const kMaxTitleChars = 120;
const kMaxDescChars = 300;

/// What a topic is practised with (D43). Anything else in an AI's answer is ignored.
const kPracticeKinds = {'concepts', 'problems', 'both'};

class ParsedOutlineItem {
  ParsedOutlineItem({
    required this.index,
    this.title = '',
    this.level = 1,
    this.description = '',
    this.targetCards = 10,
    this.prerequisites = const [],
    this.errors = const [],
    this.practice = '',
  });
  final int index;
  final String title, description;

  /// What to practise here: '' (the AI decides when it writes the cards), 'concepts', 'problems' or 'both'.
  final String practice;
  final int level, targetCards;
  final List<String> prerequisites;
  final List<String> errors;
  bool get valid => errors.isEmpty;
}

class OutlinePreview {
  OutlinePreview({required this.domain, required this.items, required this.fatalErrors});
  final String domain;
  final List<ParsedOutlineItem> items;
  final List<String> fatalErrors;

  /// Filled by the data layer: index -> true when an item with this title
  /// already exists in the domain (it is skipped, not duplicated).
  final Set<int> alreadyExists = {};

  /// Non-fatal notes per item index (e.g. a prerequisite title that matches nothing).
  final Map<int, List<String>> warnings = {};
  bool newDomain = false;

  bool get hasFatal => fatalErrors.isNotEmpty;
  Iterable<ParsedOutlineItem> get importable =>
      items.where((i) => i.valid && !alreadyExists.contains(i.index));
}

/// 'keywords' (picture-search words for older cards), 'readmore' (paragraphs for older cards, D64), 'plan' (several subjects), 'outline' (one
/// subject's topics) or 'cards'.
String detectPayloadKind(String raw) {
  try {
    final d = jsonDecode(stripCitationMarkers(stripCodeFence(raw)));
    if (d is Map && d.containsKey('image_keywords') && !d.containsKey('cards')) return 'keywords';
    if (d is Map && d['read_more'] is List && !d.containsKey('cards')) return 'readmore';
    if (d is Map && d.containsKey('subjects') && !d.containsKey('cards')) return 'plan';
    if (d is Map && d.containsKey('items') && !d.containsKey('cards')) return 'outline';
  } catch (_) {}
  return 'cards';
}

OutlinePreview parseOutlineJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(stripCitationMarkers(stripCodeFence(raw)));
  } on FormatException catch (e) {
    return OutlinePreview(domain: '', items: [], fatalErrors: ['Not valid JSON: ${e.message}']);
  }
  if (decoded is! Map<String, dynamic>) {
    return OutlinePreview(domain: '', items: [], fatalErrors: ['Top level must be a JSON object.']);
  }
  final fatal = <String>[];
  final domain = decoded['domain'];
  if (domain is! String || domain.trim().isEmpty) {
    fatal.add('"domain" must be a non-empty string.');
  } else if (domain.length > 100) {
    fatal.add('"domain" is too long (max 100).');
  }

  final itemsRaw = decoded['items'];
  final items = <ParsedOutlineItem>[];
  if (itemsRaw is! List) {
    fatal.add('"items" must be an array.');
  } else if (itemsRaw.isEmpty) {
    fatal.add('"items" is empty.');
  } else if (itemsRaw.length > kMaxOutlineItems) {
    fatal.add('Too many topics (${itemsRaw.length}); max $kMaxOutlineItems per import.');
  } else {
    for (var i = 0; i < itemsRaw.length; i++) {
      items.add(_parseItem(i, itemsRaw[i]));
    }
    _crossChecks(items, fatal);
  }
  return OutlinePreview(
    domain: domain is String ? domain.trim() : '',
    items: items,
    fatalErrors: fatal,
  );
}

ParsedOutlineItem _parseItem(int i, Object? raw) {
  if (raw is! Map<String, dynamic>) {
    return ParsedOutlineItem(index: i, errors: ['Topic must be an object.']);
  }
  final errors = <String>[];

  final t = raw['title'];
  var title = '';
  if (t is! String || t.trim().isEmpty) {
    errors.add('"title" must be a non-empty string.');
  } else if (t.trim().length > kMaxTitleChars) {
    errors.add('"title" is too long (max $kMaxTitleChars).');
  } else {
    title = t.trim();
  }

  var level = 1;
  final l = raw['level'];
  if (l != null) {
    if (l is int && l >= 1 && l <= 3) {
      level = l;
    } else {
      errors.add('"level" must be 1, 2 or 3.');
    }
  }

  var target = 10;
  final tc = raw['target_cards'];
  if (tc != null) {
    if (tc is int && tc >= 3 && tc <= 30) {
      target = tc;
    } else {
      errors.add('"target_cards" must be an integer from 3 to 30.');
    }
  }

  var desc = '';
  final d = raw['description'];
  if (d != null) {
    if (d is! String) {
      errors.add('"description" must be a string.');
    } else if (d.length > kMaxDescChars) {
      errors.add('"description" is too long (max $kMaxDescChars).');
    } else {
      desc = d.trim();
    }
  }

  final prereqs = <String>[];
  final p = raw['prerequisites'];
  if (p != null) {
    if (p is! List || p.any((e) => e is! String)) {
      errors.add('"prerequisites" must be an array of topic titles.');
    } else {
      prereqs.addAll(p.cast<String>().map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
  }

  final pr = raw['practice'];
  final practice = pr is String && kPracticeKinds.contains(pr.trim().toLowerCase()) ? pr.trim().toLowerCase() : '';

  return ParsedOutlineItem(
    index: i,
    practice: practice,
    title: title,
    level: level,
    description: desc,
    targetCards: target,
    prerequisites: prereqs,
    errors: errors,
  );
}

/// Duplicate titles inside the payload, self-references, and cycles among
/// the payload's own topics. References to titles outside the payload are
/// resolved against existing topics by the data layer.
void _crossChecks(List<ParsedOutlineItem> items, List<String> fatal) {
  final seen = <String, int>{};
  for (final it in items) {
    if (it.title.isEmpty) continue;
    final k = normalizeText(it.title);
    if (seen.containsKey(k)) {
      fatal.add('Duplicate topic title "${it.title}" (topics ${seen[k]! + 1} and ${it.index + 1}).');
    } else {
      seen[k] = it.index;
    }
    if (it.prerequisites.map(normalizeText).contains(k)) {
      fatal.add('Topic "${it.title}" lists itself as a prerequisite.');
    }
  }
  final graph = <String, List<String>>{
    for (final it in items)
      if (it.title.isNotEmpty)
        normalizeText(it.title): [
          for (final p in it.prerequisites)
            if (seen.containsKey(normalizeText(p))) normalizeText(p)
        ]
  };
  final cyc = findCycle(graph);
  if (cyc != null) fatal.add('Prerequisites form a loop: ${cyc.join(' -> ')}.');
}

/// Returns one cycle (as a list of nodes) or null. Iterative DFS.
List<String>? findCycle(Map<String, List<String>> graph) {
  final state = <String, int>{}; // 1 = on stack, 2 = done
  for (final start in graph.keys) {
    if (state[start] == 2) continue;
    final stack = <(String, int)>[(start, 0)];
    final path = <String>[];
    while (stack.isNotEmpty) {
      final (node, idx) = stack.removeLast();
      if (idx == 0) {
        if (state[node] == 2) continue;
        state[node] = 1;
        path.add(node);
      }
      final next = graph[node] ?? const [];
      if (idx < next.length) {
        stack.add((node, idx + 1));
        final n = next[idx];
        if (state[n] == 1) {
          return [...path.sublist(path.indexOf(n)), n];
        }
        if (state[n] != 2 && graph.containsKey(n)) stack.add((n, 0));
      } else {
        state[node] = 2;
        path.removeLast();
      }
    }
  }
  return null;
}
