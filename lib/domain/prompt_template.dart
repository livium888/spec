/// Versioned LLM prompt template. Bump [kPromptTemplateVersion] on any edit so
/// `prompt_log.template_version` stays meaningful.
const kPromptTemplateVersion = 'v1';

const kPromptTemplateV1 = '''
You are a careful flashcard author. Create {n} flashcards for the domain "{domain}"{syllabus_clause}.

RULES
1. If SOURCE TEXT is provided below, make cards ONLY from it. Do not add outside facts.
2. One fact per card. Keep fronts short and unambiguous.
3. Every card MUST have a supporting_quote (verbatim from the source) or a source_ref URL. No quote and no URL = do not make the card.
4. If you are unsure of a fact, skip it. Do not guess.
5. If a claim is disputed, phrase it as "According to X, ...".
6. Do NOT repeat or rephrase any of these existing cards:
{recent_titles}
7. Output JSON ONLY. No prose, no markdown fences. It must match this schema exactly:

{
  "domain": "{domain}",
  "syllabus_item": {syllabus_json},
  "cards": [
    {
      "type": "basic" | "cloze",
      "front": "string (basic only)",
      "back": "string (basic: the answer; cloze: optional extra)",
      "cloze": "string with {{c1::hidden text}} (cloze only)",
      "source_type": "quote" | "url" | "model_memory",
      "source_ref": "string (URL or citation)",
      "supporting_quote": "string",
      "confidence": "high" | "medium" | "low",
      "tags": ["string"]
    }
  ]
}

SOURCE TEXT:
{source_text}
''';

String renderPrompt({
  required String domain,
  required String? syllabusItem,
  required int n,
  required List<String> recentTitles,
  String? sourceText,
}) {
  final syl = syllabusItem?.trim();
  final recent = recentTitles.isEmpty ? '(none yet)' : recentTitles.map((t) => '- $t').join('\n');
  final source = (sourceText == null || sourceText.trim().isEmpty)
      ? '(none provided; use only facts you are highly confident about and mark source_type "model_memory")'
      : sourceText.trim();
  // Single pass so text inside values (e.g. a source containing "{n}") is never re-expanded.
  final values = {
    'n': '$n',
    'domain': domain,
    'syllabus_clause': syl == null || syl.isEmpty ? '' : ', focusing on "$syl"',
    'syllabus_json': syl == null || syl.isEmpty ? 'null' : '"${syl.replaceAll('"', r'\"')}"',
    'recent_titles': recent,
    'source_text': source,
  };
  return kPromptTemplateV1.replaceAllMapped(
    RegExp(r'\{(n|domain|syllabus_clause|syllabus_json|recent_titles|source_text)\}'),
    (m) => values[m[1]]!,
  );
}

// ---------------------------------------------------------------------------
// Outline prompt (bootstrap a subject / add topics). Version-tagged separately.
// ---------------------------------------------------------------------------
const kOutlineTemplateVersion = 'outline-v1';

const kOutlineTemplateV1 = '''
You are a curriculum designer. Produce an ordered learning outline for the subject "{domain}"{goal_clause}.

RULES
1. Output 8 to 40 topics in the order a learner should meet them. Each topic must be small enough for about 5-15 flashcards.
2. "title" must be unique and short (under 80 characters).
3. "prerequisites" lists the titles (copied exactly) of earlier topics that must be understood first. Use [] when there are none. No loops, no self-references.
4. "level": 1 = foundation, 2 = core, 3 = advanced.
5. "target_cards": how many flashcards (3-30) would cover the topic well.
6. Do NOT repeat or rename any of these existing topics (you may list them as prerequisites):
{existing_titles}
7. Output JSON ONLY. No prose, no markdown fences. Match this schema exactly:

{
  "domain": "{domain}",
  "items": [
    {
      "title": "string",
      "level": 1,
      "description": "one sentence on what this topic covers",
      "target_cards": 10,
      "prerequisites": ["title of an earlier topic"]
    }
  ]
}
''';

String renderOutlinePrompt({
  required String domain,
  String? goal,
  required List<String> existingTitles,
}) {
  final g = goal?.trim();
  final values = {
    'domain': domain,
    'goal_clause': g == null || g.isEmpty ? '' : ' (learner goal: $g)',
    'existing_titles':
        existingTitles.isEmpty ? '(none yet)' : existingTitles.map((t) => '- $t').join('\n'),
  };
  return kOutlineTemplateV1.replaceAllMapped(
    RegExp(r'\{(domain|goal_clause|existing_titles)\}'),
    (m) => values[m[1]]!,
  );
}

// ---------------------------------------------------------------------------
// Remediation prompt (rewrite cards the learner keeps forgetting).
// ---------------------------------------------------------------------------
const kRemediateTemplateVersion = 'remediate-v1';

const kRemediateTemplateV1 = '''
You are a careful flashcard author. A learner keeps forgetting the cards below (domain "{domain}", topic "{syllabus_item}").
Rewrite them so they are easier to remember. For each problem card write 1 to 3 NEW replacement cards.

RULES
1. Split compound cards into one fact per card. Make fronts short and unambiguous.
2. Add a concrete cue, example or mnemonic to the back when it helps.
3. Do not add facts that are not supported by the original card or a quote/URL you can give.
4. Every card MUST have a supporting_quote or a source_ref URL. If you cannot, skip the card.
5. Do NOT reuse the original wording of the front (the app rejects duplicates).
6. Output JSON ONLY. No prose, no markdown fences. Schema:

{
  "domain": "{domain}",
  "syllabus_item": {syllabus_json},
  "cards": [
    {
      "type": "basic" | "cloze",
      "front": "string (basic only)",
      "back": "string",
      "cloze": "string with {{c1::hidden text}} (cloze only)",
      "source_type": "quote" | "url" | "model_memory",
      "source_ref": "string",
      "supporting_quote": "string",
      "confidence": "high" | "medium" | "low",
      "tags": ["string"]
    }
  ]
}

PROBLEM CARDS:
{problem_cards}
''';

String renderRemediatePrompt({
  required String domain,
  required String syllabusItem,
  required List<({String front, String back})> problems,
}) {
  final cards = problems.isEmpty
      ? '(none)'
      : [
          for (var i = 0; i < problems.length; i++)
            '${i + 1}. FRONT: ${problems[i].front.replaceAll('\n', ' ')}\n   BACK: ${problems[i].back.replaceAll('\n', ' ')}'
        ].join('\n');
  final values = {
    'domain': domain,
    'syllabus_item': syllabusItem,
    'syllabus_json': '"${syllabusItem.replaceAll('"', r'\"')}"',
    'problem_cards': cards,
  };
  return kRemediateTemplateV1.replaceAllMapped(
    RegExp(r'\{(domain|syllabus_item|syllabus_json|problem_cards)\}'),
    (m) => values[m[1]]!,
  );
}
