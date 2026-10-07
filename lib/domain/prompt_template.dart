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
