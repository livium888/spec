// Fuzz tests for everything that reads text an AI wrote (or a learner pasted): none of it may throw,
// hang, or change the meaning of valid input. Seeded, so a failure is reproducible.
import 'dart:convert';
import 'dart:math';

import 'package:daily_learning/domain/card_markup.dart';
import 'package:daily_learning/domain/expr_eval.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/keywords_prompt.dart';
import 'package:daily_learning/domain/read_more_prompt.dart';
import 'package:daily_learning/domain/outline_parser.dart';
import 'package:daily_learning/domain/plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String junk(Random r, String alphabet, int maxLen) => String.fromCharCodes([
      for (var i = r.nextInt(maxLen + 1); i > 0; i--) alphabet.codeUnitAt(r.nextInt(alphabet.length)),
    ]);

const _markupAlphabet = r'$$$**__``\\{}()[]<>- 12ab. ' '\n';

Object? randomJson(Random r, int depth) {
  switch (r.nextInt(depth <= 0 ? 6 : 9)) {
    case 0:
      return null;
    case 1:
      return r.nextBool();
    case 2:
      return r.nextInt(100000) - 500;
    case 3:
      return r.nextDouble() * 1000;
    case 4:
    case 5:
      return junk(r, r'abc $\\*_ {{c1::x}}' '\n', 40);
    case 6:
      return [for (var i = r.nextInt(5); i > 0; i--) randomJson(r, depth - 1)];
    default:
      const keys = [
        'domain', 'syllabus_item', 'cards', 'problems', 'items', 'subjects', 'type', 'front', 'back', 'cloze', 'steps', 'answer',
        'answer_value', 'answer_expr', 'variants', 'statement', 'title', 'level', 'target_cards', 'prerequisites', 'practice',
        'source_type', 'confidence', 'tags', 'why_it_matters', 'image_query', 'image_side', 'further_reading', 'foundation_of', 'cards_index', 'x',
      ];
      return {for (var i = r.nextInt(8); i > 0; i--) keys[r.nextInt(keys.length)]: randomJson(r, depth - 1)};
  }
}

void main() {
  test('markup parsing never throws and always stays inside its limits', () {
    final r = Random(1);
    for (var i = 0; i < 4000; i++) {
      final s = junk(r, _markupAlphabet, 300);
      final blocks = parseCardMarkup(s);
      final maths = blocks.expand((b) => b.inlines).where((x) => x.isMath).length;
      expect(maths, lessThanOrEqualTo(kMaxMathPerText + blocks.length), reason: s);
      for (final m in blocks.expand((b) => b.inlines).where((x) => x.isMath)) {
        expect(m.tex!.length, lessThanOrEqualTo(kMaxMathChars), reason: s);
      }
      plainFromMarkup(s);
    }
  });

  test('markup keeps all the text: removing the formatting marks never loses a letter', () {
    final r = Random(2);
    for (var i = 0; i < 2000; i++) {
      final s = junk(r, 'abcxyz 12 \n', 80); // no marks at all
      final out = plainFromMarkup(s);
      expect(out.replaceAll(RegExp(r'\s'), ''), s.replaceAll(RegExp(r'\s'), ''), reason: s);
    }
  });

  test('the calculator never throws, always ends, and gives only finite numbers', () {
    final r = Random(3);
    const tokens = ['1', '2.5', '3e2', '+', '-', '*', '/', '^', '(', ')', 'sqrt', 'sin', 'ln', 'pi', 'e', 'x', ' ', '..', '1e999', '0'];
    final sw = Stopwatch()..start();
    for (var i = 0; i < 20000; i++) {
      final s = [for (var k = r.nextInt(14); k > 0; k--) tokens[r.nextInt(tokens.length)]].join();
      final v = evalExpression(s);
      if (v != null) expect(v.isFinite, isTrue, reason: s);
    }
    expect(sw.elapsedMilliseconds, lessThan(8000));
  });

  test('repairing JSON strings: correctly encoded text keeps its meaning (plain text with any escapes, and \$maths\$ without line breaks)', () {
    final r = Random(4);
    const plain = r'ab \\ \n { } 1 ^ _ frac theta nu text rho beta " x' '\n\t';
    const mathChars = r'ab \\ { } 1 ^ _ frac theta nu text rho beta " x n t';
    String segment() {
      switch (r.nextInt(3)) {
        case 0:
          return junk(r, plain, 20); // no dollar at all
        case 1:
          return '\$x${junk(r, mathChars, 20).trim().replaceAll(r'\$', '')}y\$'; // a formula (never empty: "$$" reads as display maths)
        default:
          return '\$x${junk(r, mathChars, 12).trim()}y\$${junk(r, plain, 6)}'; // formula then text
      }
    }

    for (var i = 0; i < 6000; i++) {
      final value = {'a': [for (var k = r.nextInt(4); k >= 0; k--) segment()].join(' '), 'b': [segment()]}; // (formulas side by side, "$a$$b$", would read as display maths)
      final raw = jsonEncode(value); // a correct encoding of that text
      expect(jsonDecode(repairJsonStrings(raw)), value, reason: 'raw: $raw');
    }
  });

  test('money dollars and newlines: a lone or unclosed dollar never turns a line break into a backslash', () {
    for (final text in ['It costs \$5.\nNext line', '\$5 then more\nNext', 'a \$ b\nnu is not a command here', 'Price \$10 and \$20.\ntheta follows']) {
      final raw = jsonEncode({'t': text});
      expect(jsonDecode(repairJsonStrings(raw)), {'t': text}, reason: raw);
    }
    // And the real thing still works: single backslashes inside a closed formula are TeX.
    expect(jsonDecode(repairJsonStrings(r'{"t":"Angle $\theta$ and $\nu + \neq$\nDone"}')), {'t': 'Angle \$\\theta\$ and \$\\nu + \\neq\$\nDone'});
  });

  test('repairing never throws on broken text either', () {
    final r = Random(5);
    for (var i = 0; i < 4000; i++) {
      final s = junk(r, r'{}[]":, \\ $ n t u 0 a' '\n', 120);
      repairJsonStrings(s);
      stripCitationMarkers(s);
    }
  });

  test('every parser survives random JSON shapes without throwing', () {
    final r = Random(6);
    for (var i = 0; i < 3000; i++) {
      final raw = jsonEncode(randomJson(r, 4));
      parseImportJson(raw);
      parseOutlineJson(raw);
      parsePlanJson(raw);
      parseKeywordsJson(raw);
      parseReadMoreJson(raw);
    }
    for (var i = 0; i < 2000; i++) {
      final raw = junk(r, r'{}[]":, \\ $ n t u 0 a' '\n', 100);
      parseImportJson(raw);
      parseOutlineJson(raw);
      parsePlanJson(raw);
      parseKeywordsJson(raw);
      parseReadMoreJson(raw);
    }
  });
}
