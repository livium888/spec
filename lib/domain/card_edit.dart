import 'cloze.dart';
import 'commons.dart' show cleanImageQuery, kMaxImageQueryChars;
import 'import_parser.dart';

/// Pure validation for editing a note's text. Returns error messages (empty = valid).
///
/// Cloze notes may add deletions but not remove one that already has a card, so
/// review history never loses its card ([existingClozeNumbers]).
List<String> validateNoteEdit({
  required String type,
  required Map<String, String> fields,
  Set<int> existingClozeNumbers = const {},
}) {
  final errors = <String>[];
  String f(String k) => (fields[k] ?? '').trim();
  void limit(String k, String label, int max) {
    if (f(k).length > max) errors.add('$label is too long (max $max characters).');
  }

  if (type == 'cloze') {
    final text = f('cloze');
    if (text.isEmpty) {
      errors.add('The text cannot be empty.');
    } else {
      final nums = clozeNumbersOf(text);
      if (nums.isEmpty) {
        errors.add('The text must contain a gap like {{c1::answer}}.');
      } else if (!nums.containsAll(existingClozeNumbers)) {
        errors.add('Keep every existing gap (${(existingClozeNumbers.toList()..sort()).map((n) => '{{c$n::…}}').join(', ')}); each one has its own review history.');
      }
    }
    limit('cloze', 'The text', kMaxFieldChars);
  } else {
    if (f('front').isEmpty) errors.add('The question cannot be empty.');
    if (f('back').isEmpty) errors.add('The answer cannot be empty.');
    limit('front', 'The question', kMaxFieldChars);
    limit('back', 'The answer', kMaxFieldChars);
  }
  limit('back', 'The answer', kMaxFieldChars);
  if (type == 'problem') {
    final lines = f('steps').split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length > kMaxProblemSteps) errors.add('A problem has at most $kMaxProblemSteps steps.');
    if (lines.any((l) => l.length > 400)) errors.add('Each step is at most 400 characters.');
  }
  limit('why_it_matters', '"Why it matters"', kMaxExtraChars);
  limit('example', '"Example"', kMaxExtraChars);
  limit('memory_hook', '"Memory hook"', kMaxExtraChars);
  limit('image_alt', 'The picture description', 300);
  limit('image_credit', 'The picture credit', 300);
  final keywords = f('image_query');
  if (keywords.isNotEmpty && cleanImageQuery(keywords) == null) {
    errors.add('Image keywords: a few plain words (up to $kMaxImageQueryChars characters), not a web address.');
  }
  return errors;
}
