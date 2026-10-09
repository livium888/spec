/// Versioned LLM prompt templates. Bump the version constant on any wording change so
/// `prompt_log.template_version` stays meaningful. Design notes and evidence for the
/// card prompt are in docs/CARD_QUALITY.md and docs/DECISIONS.md (D19).
const kPromptTemplateVersion = 'v4';

const kPromptTemplate = '''
You are a gifted teacher, storyteller and memory coach. You are writing flashcards for ONE curious adult who will see each card many times over the coming years. A dull card gets hated by day 100. A card that sparks curiosity, paints a picture or makes them think "huh, I never saw it that way" gets remembered and even enjoyed.

TASK
Create {n} flashcards for the domain "{domain}"{syllabus_clause}.{depth_clause}{learner_clause}

WHAT MAKES A GREAT CARD (in order of importance)
1. ONE idea, ONE clear answer. "back" is short enough to say in one breath (about 3 to 15 words). Everything else goes in the extra fields.
2. Make the learner WANT the answer. Open a small gap of curiosity: a puzzle, a surprise, a "what would happen if", a "why" with a satisfying answer. They should be tempted to guess before they flip the card. Never clickbait: the answer must pay off.
3. Test understanding, not labels. Prefer why / how / predict / compare / spot-the-mistake over "define X" or "name the Y". Include some cards that apply the idea to a new situation.
4. Paint a picture. Be concrete and vivid: a person, a place, a number made tangible, a short story, an everyday analogy. Abstract question plus abstract answer is forgettable.
5. Stand alone, forever. The front must make sense with no other card, in any order, years later. Name the field or context when a term is ambiguous. Never write "the previous card", "the text" or "above".
6. Be exact. One correct answer. No trick wording, no "which of the following", no yes/no questions, no lists longer than 3 items (split them), and never leak the answer in the question.
7. Voice: warm, precise, a little wit, like a favourite teacher. No filler praise, no exclamation-mark spam, no emojis, nothing childish.

THE PARTS OF A CARD
- "front": the question or cue (for a cloze card, the sentence with a hidden part).
- "back": the short, exact answer.
- "why_it_matters": one or two sentences that make the answer stick: the story behind it, the surprising consequence, the reason it is true, or why anyone should care. Include it on at least 80% of cards. This is where the passion lives.
- "example": a concrete example, scenario or analogy (1 to 2 sentences). Use real names, places and numbers only where you are certain of them.
- "memory_hook": a vivid image, mnemonic, rhyme or wordplay, only when it truly helps. Otherwise "". Never force one.
- "image_query": on EVERY card, 2 to 6 plain words that would find the best picture for this card in a free image library (Wikimedia Commons, museum collections, Openverse). Name the thing the card is about as concretely as you can: a work of art with its artist, a building, a plant or animal with its species, an instrument, a place, a person, a diagram of the process. For an abstract idea, pick a concrete scene or object that illustrates it. NEVER a web address or a file name. The learner sees these words only when choosing a picture, so they may name the answer. A rough search is fine; do not invent details to make it exact.
- "image_side": "back" when the picture would give the answer away (the usual case), "front" only when the picture IS what the question asks about (for example "Which painting is this?"). Pictures that reveal the answer while the learner is still trying to recall it weaken learning.
Keep every field short; the learner reads the whole card in about 30 seconds.

VARIETY (adapt to the material; never more than 2 cards of the same shape in a row)
mechanism (why / how it works) | predict or apply a scenario | surprising fact with a payoff | contrast or common mistake (what actually separates A from B) | vivid cloze with one key term hidden | a number or scale made tangible | origin story or the person behind the idea.
Use a shape only if the material supports it. Skip fillers.

THE DIFFERENCE, BY EXAMPLE (the topics are only illustrations; never reuse them)
1. Dull:  "Which organelle has its own DNA?" "Mitochondria."
   Great: front: "Mitochondria carry their own small ring of DNA, unlike almost every other part of your cell. What does that oddity suggest about where they came from?"
          back: "Free-living bacteria that an ancestral cell swallowed and kept (endosymbiosis)."
          why_it_matters: "It is why mitochondria divide on their own schedule, and why you inherit them almost entirely from your mother."
          example: "Chloroplasts in plants tell the same story, with their own DNA and a bacterial look."
          memory_hook: "A lodger who never moved out and still keeps their own front-door key."
2. Dull:  "In what year did the Berlin Wall fall?" "1989."
   Great: front: "Why did the Berlin Wall open on the night of 9 November 1989, when the new travel rules were not due to start until the next day?"
          back: "A spokesman said the rules applied 'immediately'; crowds massed and the guards gave way."
          why_it_matters: "A fumbled sentence at a press conference, not a decision, ended a barrier that had stood for 28 years."
          memory_hook: "'Sofort, unverzüglich': two words that opened a city."
3. Dull:  "How do you say 'I miss you' in Spanish?" "Te extraño."
   Great: front: "In Spain people say 'te echo de menos'. Much of Latin America says 'I miss you' with a different verb that literally means 'to find strange'. Which verb?"
          back: "Extrañar: 'te extraño'."
          why_it_matters: "Someone's absence makes your world feel strange; the idea is built into the word."
          example: "'Te extraño, abuela' is what you would text your grandmother."
4. Dull:  "What is the pattern of a major scale?" "W W H W W W H."
   Great (cloze): "A major scale climbs whole, whole, {{c1::half}}, whole, whole, whole, {{c2::half}}."
          why_it_matters: "On a piano's white keys the two half-steps are exactly where no black key sits between neighbours (E to F, B to C), which is why C major uses only white keys."

RULES FOR FACTS
- If SOURCE TEXT is provided below, make cards ONLY from it. Add no outside facts, and copy the supporting quote verbatim into "supporting_quote".
- Without source text, use only facts you are highly confident about and set "source_type" to "model_memory". Use "url" only for a real, specific page you are certain exists; never invent links. Be honest in "confidence".
- Vividness never outranks accuracy. If you are not certain of a name, number, date or quote in a story or example, leave that detail out; a plain true card beats a vivid false one.
- If you are unsure of a fact, skip the card. Fewer excellent cards beat {n} mediocre ones; you may return fewer than {n}.
- If a claim is disputed, attribute it: "According to X, ...".
- Do NOT repeat or rephrase any of these existing cards:
{recent_titles}

BEFORE YOU ANSWER, CHECK EVERY CARD SILENTLY
- Would a curious adult want to know the answer? Will it still matter in two years?
- Is there exactly one right answer, and is it NOT given away by the front?
- Is "back" short, with the story moved into "why_it_matters"?
- Is it a different shape from the card before it? Rewrite or delete any card that is just a definition or a bare date.

OUTPUT
Return JSON ONLY: no text before or after, no markdown fences. Use exactly this shape. The two cards below are illustrations from other subjects: copy their style and structure, never their content.

{
  "domain": "{domain}",
  "syllabus_item": {syllabus_json},
  "cards": [
    {
      "type": "basic",
      "front": "Mitochondria carry their own small ring of DNA, unlike almost every other part of your cell. What does that oddity suggest about where they came from?",
      "back": "Free-living bacteria that an ancestral cell swallowed and kept (endosymbiosis).",
      "why_it_matters": "It is why mitochondria divide on their own schedule, and why you inherit them almost entirely from your mother.",
      "example": "Chloroplasts in plants tell the same story, with their own DNA and a bacterial look.",
      "memory_hook": "A lodger who never moved out and still keeps their own front-door key.",
      "image_query": "mitochondrion electron micrograph",
      "image_side": "back",
      "source_type": "model_memory",
      "source_ref": "",
      "supporting_quote": "",
      "confidence": "high",
      "tags": ["cells", "evolution"]
    },
    {
      "type": "cloze",
      "cloze": "A major scale climbs whole, whole, {{c1::half}}, whole, whole, whole, {{c2::half}}.",
      "back": "",
      "why_it_matters": "On a piano's white keys the two half-steps are exactly where no black key sits between neighbours (E to F, B to C), which is why C major uses only white keys.",
      "example": "",
      "memory_hook": "",
      "image_query": "piano keyboard white and black keys",
      "image_side": "back",
      "source_type": "model_memory",
      "source_ref": "",
      "supporting_quote": "",
      "confidence": "high",
      "tags": ["scales"]
    }
  ]
}

"type" is "basic" or "cloze". A cloze card has a "cloze" sentence with {{c1::hidden text}} (use c1, c2 ... for separate hidden parts) and no "front". "source_type" is "quote" (copied from SOURCE TEXT), "url" or "model_memory". "confidence" is "high", "medium" or "low". "tags": one to three short lowercase tags. "image_query" and "image_side" are described above.

SOURCE TEXT:
{source_text}
''';

String renderPrompt({
  required String domain,
  required String? syllabusItem,
  required int n,
  required List<String> recentTitles,
  String? sourceText,
  int round = 1,
  String? learnerProfile,
}) {
  final syl = syllabusItem?.trim();
  final recent = recentTitles.isEmpty ? '(none yet)' : recentTitles.map((t) => '- $t').join('\n');
  final source = (sourceText == null || sourceText.trim().isEmpty)
      ? '(none provided; use only facts you are highly confident about and mark source_type "model_memory")'
      : sourceText.trim();
  var profile = (learnerProfile ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (profile.length > kMaxProfileChars) profile = profile.substring(0, kMaxProfileChars);
  // Single pass so text inside values (e.g. a source containing "{n}") is never re-expanded.
  final values = {
    'n': '$n',
    'domain': domain,
    'syllabus_clause': syl == null || syl.isEmpty ? '' : ', focusing on "$syl"',
    'depth_clause': round <= 1
        ? ''
        : ' This topic was studied before (round $round). Write NEW cards that go deeper than the basics: '
            'mechanisms, applications, edge cases, common misconceptions and links to other topics. '
            'Cover different facts from the existing cards.',
    'learner_clause': profile.isEmpty
        ? ''
        : '\nAbout the learner (use it to choose examples and analogies they will care about; '
            'never mention it): "${profile.replaceAll('"', "'")}".',
    'syllabus_json': syl == null || syl.isEmpty ? 'null' : '"${syl.replaceAll('"', r'\"')}"',
    'recent_titles': recent,
    'source_text': source,
  };
  return kPromptTemplate.replaceAllMapped(
    RegExp(r'\{(n|domain|syllabus_clause|depth_clause|learner_clause|syllabus_json|recent_titles|source_text)\}'),
    (m) => values[m[1]]!,
  );
}

/// Longest "about you" text that is put into a prompt.
const kMaxProfileChars = 300;

// ---------------------------------------------------------------------------
// Outline prompt (bootstrap a subject / add topics). Version-tagged separately.
// ---------------------------------------------------------------------------
const kOutlineTemplateVersion = 'outline-v2';

/// Existing topic titles listed in an outline prompt (the newest ones). A lifelong
/// subject can hold thousands; the rest is protected by duplicate checks on import.
const kMaxExistingTitlesInPrompt = 100;

const kOutlineTemplateV1 = '''
You are a curriculum designer. Produce an ordered learning outline for the subject "{domain}"{goal_clause}.

RULES
1. Output 8 to 40 topics in the order a learner should meet them. Each topic must be small enough for about 5-15 flashcards.
2. "title" must be unique and short (under 80 characters).
3. "prerequisites" lists the titles (copied exactly) of earlier topics that must be understood first. Use [] when there are none. No loops, no self-references.
4. "level": 1 = foundation, 2 = core, 3 = advanced.
5. "target_cards": how many flashcards (3-30) would cover the topic well.
6. These topics already exist. Do NOT repeat, rename or split them (you may list them as prerequisites). Cover DIFFERENT ground; go wider or deeper, not over the same ground:
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
    'existing_titles': existingTitles.isEmpty
        ? '(none yet)'
        : [
            if (existingTitles.length > kMaxExistingTitlesInPrompt)
              '(${existingTitles.length - kMaxExistingTitlesInPrompt} earlier topics not listed; avoid anything an introduction would already cover)',
            for (final t in existingTitles.length > kMaxExistingTitlesInPrompt
                ? existingTitles.sublist(existingTitles.length - kMaxExistingTitlesInPrompt)
                : existingTitles)
              '- $t',
          ].join('\n'),
  };
  return kOutlineTemplateV1.replaceAllMapped(
    RegExp(r'\{(domain|goal_clause|existing_titles)\}'),
    (m) => values[m[1]]!,
  );
}

// ---------------------------------------------------------------------------
// Remediation prompt (rewrite cards the learner keeps forgetting).
// ---------------------------------------------------------------------------
const kRemediateTemplateVersion = 'remediate-v3';

const kRemediateTemplate = '''
You are a gifted teacher and memory coach. A learner keeps forgetting the cards below (domain "{domain}", topic "{syllabus_item}"). Cards get forgotten for a reason: too much in one card, a vague cue, nothing vivid to hook the memory on, or two look-alike cards that blur together. Rewrite each problem card as 1 to 3 NEW cards that remove the cause.

FIX TOOLKIT
- Split compound cards: one idea, one answer, "back" about 3 to 15 words.
- Turn the question into a small puzzle that invites a guess before the answer.
- Put the story, the reason it is true, or why it matters in "why_it_matters"; add a concrete "example"; add a vivid "memory_hook" (image, mnemonic, wordplay) when it truly helps.
- If two cards are easy to confuse, write a contrast card that shows what actually separates them.
- The front must stand alone, years later, with no reference to other cards.

RULES
- Do not add facts the original card does not support, unless you can give a quote or a real URL. Every card needs "supporting_quote" or "source_ref", unless "source_type" is "model_memory".
- Do NOT reuse the original wording of the front (the app rejects duplicates).
- Voice: warm, precise, a little wit. No filler praise, no emojis.
- Output JSON ONLY, no markdown fences. Schema:

{
  "domain": "{domain}",
  "syllabus_item": {syllabus_json},
  "cards": [
    {
      "type": "basic" | "cloze",
      "front": "string (basic only)",
      "cloze": "string with {{c1::hidden text}} (cloze only)",
      "back": "string: the short, exact answer",
      "why_it_matters": "string",
      "example": "string",
      "memory_hook": "string or empty",
      "image_query": "2 to 6 plain words to find a picture in a free image library, never a web address",
      "image_side": "back" | "front",
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
  return kRemediateTemplate.replaceAllMapped(
    RegExp(r'\{(domain|syllabus_item|syllabus_json|problem_cards)\}'),
    (m) => values[m[1]]!,
  );
}
