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
      final nums = {for (final m in ParsedCard.clozeRe.allMatches(text)) int.parse(m[1]!)};
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
  limit('why_it_matters', '"Why it matters"', kMaxExtraChars);
  limit('example', '"Example"', kMaxExtraChars);
  limit('memory_hook', '"Memory hook"', kMaxExtraChars);
  return errors;
}
