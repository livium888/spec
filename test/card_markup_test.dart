import 'dart:convert';

import 'package:daily_learning/domain/card_markup.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/presentation/theme/app_theme.dart';
import 'package:daily_learning/presentation/widgets/rich_card_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

List<MdInline> inl(String s) => parseCardMarkup(s).expand((b) => b.inlines).toList();

void main() {
  group('card markup', () {
    test('plain text is plain, and so are underscores in words and money', () {
      expect(isPlainMarkup(parseCardMarkup('Why is the sky blue?')), isTrue);
      expect(isPlainMarkup(parseCardMarkup('Use snake_case_names and 2 * 3 here.')), isTrue);
      expect(isPlainMarkup(parseCardMarkup(r'It costs $5 and $10 today.')), isTrue);
      expect(isPlainMarkup(parseCardMarkup('')), isTrue);
    });

    test('bold, italic, code and nesting', () {
      final i = inl('A **key term**, an *idea* and `x = 1`.');
      expect(i.where((p) => p.bold).single.text, 'key term');
      expect(i.where((p) => p.italic).single.text, 'idea');
      expect(i.where((p) => p.code).single.text, 'x = 1');
      final n = inl('**bold and _italic_**');
      expect(n.any((p) => p.bold && p.italic && p.text == 'italic'), isTrue);
    });

    test('inline and display maths; escaped dollars stay text', () {
      final i = inl(r'The energy is $E = mc^2$ at rest.');
      expect(i.where((p) => p.isMath).single.tex, 'E = mc^2');
      expect(i.first.text, 'The energy is ');
      final d = parseCardMarkup('Integral:\n\$\$\\int_0^1 x^2\\,dx\$\$');
      expect(d.map((b) => b.kind), [MdKind.paragraph, MdKind.display]);
      expect(d.last.tex, r'\int_0^1 x^2\,dx');
      expect(inl(r'Pay \$5 now').map((p) => p.text).join(), r'Pay $5 now');
      expect(inl(r'$a<b$ and $c>d$').where((p) => p.isMath).length, 2);
    });

    test('lists and paragraphs', () {
      final b = parseCardMarkup('Intro\n\n- one\n- two\n1. first\n2. second');
      expect(b.map((x) => x.kind), [MdKind.paragraph, MdKind.bullet, MdKind.bullet, MdKind.ordered, MdKind.ordered]);
      expect(b.last.number, 2);
    });

    test('HTML, links and images are never interpreted: they stay text', () {
      final s = r'<script>alert(1)</script> [x](http://evil) ![i](http://evil/p.png) <b>bold</b>';
      final i = inl(s);
      expect(i.every((p) => !p.isMath && !p.bold && !p.code), isTrue);
      expect(i.map((p) => p.text).join(), s);
    });

    test('limits: very long text is cut, too many or too long formulas stay text', () {
      expect(parseCardMarkup('x' * 20000).single.inlines.single.text.length, kMaxMarkupChars);
      final many = List.generate(60, (i) => '\$a$i\$').join(' ');
      expect(inl(many).where((p) => p.isMath).length, kMaxMathPerText);
      final long = '\$${'x' * (kMaxMathChars + 1)}\$';
      expect(inl(long).any((p) => p.isMath), isFalse);
    });

    test('plain text for reading aloud and lists', () {
      expect(plainFromMarkup(r'**Speed** is $\frac{d}{t}$ and $x^2$.'), 'Speed is d over t and x squared.');
      expect(plainFromMarkup('- a\n- b'), '• a\n• b');
    });
  });

  group('repairing LaTeX damaged inside a JSON answer', () {
    Map<String, dynamic> decode(String raw) => jsonDecode(repairJsonStrings(raw)) as Map<String, dynamic>;

    test('a single backslash before a TeX command inside \$...\$ survives (no form feeds, tabs, backspaces)', () {
      final m = decode(r'{"front":"Half: $\frac{1}{2}$, angle $\theta + \beta + \rho + \nu + \text{x}$"}');
      expect(m['front'], r'Half: $\frac{1}{2}$, angle $\theta + \beta + \rho + \nu + \text{x}$');
    });

    test('correctly doubled backslashes are left exactly as they are', () {
      final m = decode(r'{"front":"Half: $\\frac{1}{2}$ and $$\\int_0^1 x\\,dx$$"}');
      expect(m['front'], r'Half: $\frac{1}{2}$ and $$\int_0^1 x\,dx$$');
    });

    test('JSON escapes outside maths keep their meaning; raw line breaks and tabs become escapes', () {
      final m = decode('{"a":"line one\\nline two \$x\$ caf\\u00e9","b":"raw\nbreak\tand tab"}');
      expect(m['a'], 'line one\nline two \$x\$ café');
      expect(m['b'], 'raw\nbreak\tand tab');
    });

    test('invalid escapes and literal dollars no longer break the parse', () {
      final m = decode(r'{"a":"cost \$5 and \(parens\)","b":"cost \\$5 then $x^2$"}');
      expect(m['a'], r'cost \$5 and \\(parens\\)'.replaceAll(r'\\', r'\'));
      expect(m['b'], r'cost \$5 then $x^2$');
    });

    test('a whole import answer with single-backslash LaTeX still imports with the right formula', () {
      final raw = '{"domain":"Physics","cards":[{"type":"basic","front":"Speed of a wave with frequency \$f\$ and wavelength \$\\lambda\$?",'
          '"back":"\$v = f\\lambda\$","source_type":"model_memory","confidence":"high","why_it_matters":"Since \$\\frac{d}{t}\$."}]}';
      final p = parseImportJson(raw);
      expect(p.hasFatal, isFalse, reason: p.fatalErrors.join('; '));
      expect(p.cards.single.front, contains(r'$\lambda$'));
      expect(p.cards.single.back, r'$v = f\lambda$');
      expect(p.cards.single.whyItMatters, contains(r'\frac{d}{t}'));
    });
  });

  group('drawing', () {
    Future<void> pump(WidgetTester t, String text, {int? maxLines}) => t.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: RichCardText(text, style: const TextStyle(fontSize: 18), maxLines: maxLines)))));

    testWidgets('plain text is a plain Text; maths is drawn as a formula; broken maths shows its source', (t) async {
      await pump(t, 'No formatting here');
      expect(find.text('No formatting here'), findsOneWidget);
      expect(find.byType(Math), findsNothing);

      await pump(t, r'Energy $E = mc^2$ and **bold**, then:' '\n\n' r'$$\frac{a}{b}$$');
      expect(find.byType(Math), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp('formula')), findsWidgets);

      await pump(t, r'Broken $\notacommand{x$ here');
      await t.pump();
      expect(find.textContaining(r'\notacommand{x', findRichText: true), findsOneWidget);
    });

    testWidgets('a folded question keeps maths and cuts after the lines', (t) async {
      await pump(t, r'Why does $x^2$ grow? ' * 12, maxLines: 2);
      expect(find.byType(Math), findsWidgets);
    });
  });
}
