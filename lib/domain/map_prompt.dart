/// The "map" prompt: shown to the learner's LLM when the library should gain NEW SUBJECTS.
/// It carries a bounded summary of everything the learner already has (subjects, counts,
/// the newest topic titles; never cards) so the LLM can propose what is missing.
///
/// Bounded on purpose: a lifelong library holds tens of thousands of topics, and long
/// prompts make LLMs answer worse (see docs/DECISIONS.md D24). Version-tagged in `prompt_log`.
library;

import 'prompt_template.dart' show kMaxProfileChars;

const kMapTemplateVersion = 'map-v1';

/// Characters of library summary put in the prompt (the rest is cut or shortened).
const kMapBudgetChars = 9000;
const kMapDetailedSubjects = 12;
const kMapTitlesDetailed = 10;
const kMapTitlesBrief = 3;
const kMapMaxSubjectsListed = 150;

class MapSubject {
  const MapSubject({
    required this.name,
    required this.topics,
    required this.cards,
    this.interest,
    this.paused = false,
    this.recentTitles = const [],
  });
  final String name;
  final int topics, cards;

  /// -1..1 from the learner's one-tap ratings; null if never rated.
  final double? interest;
  final bool paused;

  /// Newest first.
  final List<String> recentTitles;
}

const kMapTemplate = '''
You are helping a learner grow a lifelong flashcard library. They study a few minutes a day with spaced repetition, for years. Every SUBJECT is an ordered list of small TOPICS; short cards are written for one topic at a time. Right now they need NEW SUBJECTS, chosen well.

WHAT THE LEARNER ALREADY HAS (a summary; the cards themselves are not included)
{library}
{learner_clause}{ideas_clause}
YOUR TASK
Propose {n} NEW subjects for this learner.

RULES
1. Every subject must be clearly different from everything listed above and from each other: not a rename, a subset or a near-duplicate. Never propose anything marked "paused".
2. Mix on purpose: at least one subject that BRIDGES to something they already study (it should make an existing subject richer), and at least one from an area they have not touched at all. Prefer subjects that stay interesting for years, with plenty of depth, over narrow one-off facts.
3. For each subject give "why": one warm sentence on why it suits THIS learner, naming what it connects to in their library when it does.
4. Give each subject 10 to 20 topics in the order a learner should meet them. Each topic must be small enough for about 5-15 flashcards. "title" is unique within the subject and under 80 characters. "level": 1 foundation, 2 core, 3 advanced. "target_cards": 3-30. "prerequisites" are titles (copied exactly) of earlier topics in the same subject; use [] when there are none. No loops.
5. Plain, concrete topic titles a person would actually search for. No hype, no emojis, no filler.
6. Output JSON ONLY. No prose before or after, no markdown fences. Match this schema exactly:

{
  "subjects": [
    {
      "domain": "subject name, under 60 characters",
      "why": "one sentence",
      "items": [
        {
          "title": "string",
          "level": 1,
          "description": "one sentence on what this topic covers",
          "target_cards": 10,
          "prerequisites": []
        }
      ]
    }
  ]
}
''';

String renderMapPrompt({
  required List<MapSubject> subjects,
  List<String> ideas = const [],
  String? learnerProfile,
  int count = 4,
}) {
  var profile = (learnerProfile ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (profile.length > kMaxProfileChars) profile = profile.substring(0, kMaxProfileChars);
  final values = {
    'library': _library(subjects),
    'learner_clause': profile.isEmpty
        ? ''
        : '\nAbout the learner (use it to judge what will matter to them; never mention it): "${profile.replaceAll('"', "'")}".\n',
    'ideas_clause': ideas.isEmpty
        ? ''
        : '\nAreas they have not touched, as optional inspiration (use any, or none): ${ideas.join('; ')}.\n',
    'n': '$count',
  };
  return kMapTemplate.replaceAllMapped(
    RegExp(r'\{(library|learner_clause|ideas_clause|n)\}'),
    (m) => values[m[1]]!,
  );
}

String _library(List<MapSubject> all) {
  if (all.isEmpty) return '(nothing yet: this is a brand-new library. Start with a broad, well-rounded set.)';
  final listed = all.take(kMapMaxSubjectsListed).toList();
  final totalCards = all.fold<int>(0, (a, s) => a + s.cards);
  final totalTopics = all.fold<int>(0, (a, s) => a + s.topics);
  final out = StringBuffer('${all.length} subjects, $totalTopics topics, $totalCards cards in total.\n');

  String line(MapSubject s, int titles) {
    final tags = [
      if (s.paused) 'paused, do not propose more of this',
      if (!s.paused && (s.interest ?? 0) > 0.3) 'the learner likes it',
      if (!s.paused && (s.interest ?? 0) < -0.3) 'the learner finds it less interesting',
    ];
    final newest = s.recentTitles.take(titles).toList();
    return '- ${s.name} (${s.topics} topics, ${s.cards} cards${tags.isEmpty ? '' : '; ${tags.join('; ')}'})'
        '${newest.isEmpty ? '' : ': newest topics: ${newest.join(' | ')}'}\n';
  }

  var i = 0;
  for (; i < listed.length; i++) {
    final detailed = i < kMapDetailedSubjects;
    final l = line(listed[i], detailed ? kMapTitlesDetailed : kMapTitlesBrief);
    if (out.length + l.length > kMapBudgetChars * 0.8 && !detailed) break;
    out.write(l);
  }
  final rest = [for (var j = i; j < all.length; j++) all[j].name];
  if (rest.isNotEmpty) {
    var names = rest.join('; ');
    const cap = 1800;
    var shown = rest.length;
    if (names.length > cap) {
      names = names.substring(0, cap);
      final cut = names.lastIndexOf(';');
      names = cut > 0 ? names.substring(0, cut) : names;
      shown = names.split(';').length;
    }
    out.write('Other subjects (names only): $names'
        '${shown < rest.length ? '; and ${rest.length - shown} more' : ''}.\n');
  }
  return out.toString().trimRight();
}
