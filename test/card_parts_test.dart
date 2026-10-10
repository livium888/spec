import 'dart:ui' as ui;

import 'package:daily_learning/domain/models.dart';
import 'package:daily_learning/domain/study_card.dart';
import 'package:daily_learning/presentation/widgets/card_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

StudyCard cloze(String text, {int ord = 0, String back = ''}) => StudyCard(
      snapshot: const CardSnapshot(id: 1, due: 0),
      noteId: 1,
      domainId: 1,
      noteType: 'cloze',
      fields: {'cloze': text, 'back': back},
      tags: const [],
      ord: ord,
      suspended: false,
    );

Widget host(Widget child, {bool reduce = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce, size: const Size(400, 800)),
        child: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
      ),
    );

void main() {
  group('cloze parts (pure)', () {
    test('this card\'s deletion becomes the gap; the others stay as plain text', () {
      final parts = cloze('The {{c1::heart::organ}} pumps {{c2::blood}} daily.').clozeParts;
      expect(parts.map((p) => p.isGap), [false, true, false, false, false]);
      expect(parts[1].text, 'heart');
      expect(parts[1].hint, 'organ');
      expect(parts.map((p) => p.text).join(), 'The heart pumps blood daily.');
      final second = cloze('The {{c1::heart}} pumps {{c2::blood}} daily.', ord: 1).clozeParts;
      expect(second.where((p) => p.isGap).single.text, 'blood');
      expect(second.map((p) => p.text).join(), 'The heart pumps blood daily.');
    });

    test('text without gaps, a gap at the very start or end, and the optional note', () {
      expect(cloze('plain').clozeParts.single.isGap, isFalse);
      final edge = cloze('{{c1::A}} and {{c1::B}}').clozeParts;
      expect(edge.where((p) => p.isGap).map((p) => p.text), ['A', 'B']); // one number, two gaps
      expect(cloze('x {{c1::y}}', back: '  note ').clozeExtra, 'note');
    });

    test('a gap inside a formula keeps the formula whole (no bare dollar signs)', () {
      final parts = cloze(r'Solve $x = {{c1::5}} + {{c2::2}}$ now.').clozeParts;
      expect(parts.any((p) => p.isGap), isFalse);
      expect(parts.map((p) => p.text).join(), r'Solve $x = \boxed{5} + 2$ now.');
      expect(parts[1].hiddenText, r'$x = \square + 2$');
      final second = cloze(r'Solve $x = {{c1::5}} + {{c2::2}}$ now.', ord: 1).clozeParts;
      expect(second[1].text, r'$x = 5 + \boxed{2}$');
      // A gap beside a formula, and a gap that is itself a formula, are still ordinary gaps.
      expect(cloze(r'$a$ is {{c1::big}}').clozeParts.where((p) => p.isGap).single.text, 'big');
      expect(cloze(r'is {{c1::$\frac{a}{b}$}} ok').clozeParts.where((p) => p.isGap).single.text, r'$\frac{a}{b}$');
    });

    test('an escaped "::" stays in the answer; the first plain "::" still starts the hint', () {
      final p = cloze(r'Use {{c1::std\::vector::a container}} here.').clozeParts.firstWhere((p) => p.isGap);
      expect((p.text, p.hint), ('std::vector', 'a container'));
      final q = cloze(r'Use {{c1::std\::vector}} here.').clozeParts.firstWhere((p) => p.isGap);
      expect((q.text, q.hint), ('std::vector', null));
      expect(cloze(r'Use {{c1::std\::vector}} here.').front, 'Use [...] here.');
    });
  });

  group('ClozeSentence', () {
    Future<int> tealPixels(WidgetTester t, GlobalKey key) async {
      var teal = 0;
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        for (var i = 0; i < bytes.lengthInBytes; i += 4) {
          if ((bytes.getUint8(i) - 0x0F).abs() < 40 && (bytes.getUint8(i + 1) - 0x76).abs() < 40 && (bytes.getUint8(i + 2) - 0x6E).abs() < 40) teal++;
        }
      });
      return teal;
    }

    testWidgets('a gap inside a formula draws an empty box, then the boxed answer, with no raw dollar signs', (t) async {
      var revealed = false;
      late StateSetter set;
      final parts = cloze(r'Then $x = {{c1::\frac{1}{2}}} + 3$ holds.').clozeParts;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, s) {
        set = s;
        return ClozeSentence(
          parts: parts,
          revealed: revealed,
          style: const TextStyle(fontSize: 26, color: Colors.black),
          strong: const Color(0xFF0F766E),
          tint: const Color(0xFFD9F2EE),
        );
      })));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.textContaining(r'$'), findsNothing);
      set(() => revealed = true);
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('paints without errors in both states, and the revealed answer is actually visible', (t) async {
      final key = GlobalKey();
      var revealed = false;
      late StateSetter set;
      await t.pumpWidget(host(RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
          child: StatefulBuilder(builder: (c, s) {
            set = s;
            return ClozeSentence(
              parts: const [ClozePart.text('means '), ClozePart.gap('to miss someone', hint: 'feel'), ClozePart.text(' ok')],
              revealed: revealed,
              style: const TextStyle(fontSize: 26, color: Colors.black),
              strong: const Color(0xFF0F766E),
              tint: const Color(0xFFD9F2EE),
            );
          }),
        ),
      )));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull); // the old one-sided border with rounded corners asserted here
      expect(find.text('to miss someone'), findsNothing); // hidden before the reveal
      final before = await tealPixels(t, key);
      set(() => revealed = true);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.text('to miss someone'), findsOneWidget);
      expect(await tealPixels(t, key), greaterThan(before)); // the answer is painted, in the subject colour
    });

    testWidgets('the blank never reveals the length of the answer, and the hint is one tidy line', (t) async {
      Future<double> blankWidth(String answer) async {
        await t.pumpWidget(host(ClozeSentence(
          parts: [ClozePart.text('a '), ClozePart.gap(answer), ClozePart.text(' b')],
          revealed: false,
          style: const TextStyle(fontSize: 24),
          strong: Colors.teal,
          tint: Colors.teal.shade50,
        )));
        await t.pump();
        return t.getSize(find.byType(AnimatedContainer).first).width;
      }

      expect(await blankWidth('x'), await blankWidth('a very very long answer indeed'));
      await t.pumpWidget(host(ClozeSentence(
        parts: [const ClozePart.text('a '), const ClozePart.gap('x', hint: 'a long hint that would wrap onto several lines'), const ClozePart.text(' b')],
        revealed: false,
        style: const TextStyle(fontSize: 24),
        strong: Colors.teal,
        tint: Colors.teal.shade50,
      )));
      await t.pump();
      expect(t.getSize(find.byType(AnimatedContainer).first).height, lessThan(60)); // one line, not three
    });
  });

  group('ExtrasStack', () {
    testWidgets('every extra is shown at once, in order, each under its label; no tabs', (t) async {
      await t.pumpWidget(host(const ExtrasStack(
          extras: [('Why it matters', 'Because'), ('Example', 'For instance'), ('Memory hook', 'A ghost')], strong: Colors.teal)));
      for (final x in ['Why it matters', 'Because', 'Example', 'For instance', 'Memory hook', 'A ghost']) {
        expect(find.text(x), findsOneWidget, reason: x);
      }
      expect(find.byType(ChoiceChip), findsNothing);
      // reading order: top to bottom as given
      final ys = [for (final x in ['Why it matters', 'Example', 'Memory hook']) t.getTopLeft(find.text(x)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('one extra shows directly with its label', (t) async {
      await t.pumpWidget(host(const ExtrasStack(extras: [('Example', 'Only one')], strong: Colors.teal)));
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Only one'), findsOneWidget);
    });

    testWidgets('the label is a heading for screen readers and the text follows the size scale', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(host(const ExtrasStack(extras: [('Example', 'Body')], strong: Colors.teal, scale: 2.0)));
      expect(t.getSemantics(find.text('Example')).flagsCollection.isHeader, isTrue);
      final small = t.widget<SelectableText>(find.byType(SelectableText)).style!.fontSize!;
      await t.pumpWidget(host(const ExtrasStack(extras: [('Example', 'Body')], strong: Colors.teal, scale: 1.0)));
      expect(t.widget<SelectableText>(find.byType(SelectableText)).style!.fontSize!, lessThan(small));
      h.dispose();
    });

    testWidgets('nothing at all when the card has no extras', (t) async {
      await t.pumpWidget(host(const ExtrasStack(extras: [], strong: Colors.teal)));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('RevealPanel', () {
    testWidgets('animates open normally, and appears at once with "reduce motion"', (t) async {
      await t.pumpWidget(host(const RevealPanel(accent: Colors.teal, child: Text('The answer'))));
      final start = t.getSize(find.byType(RevealPanel)).height;
      await t.pump(const Duration(milliseconds: 500));
      expect(t.getSize(find.byType(RevealPanel)).height, greaterThan(start));
      expect(find.text('The answer'), findsOneWidget);

      await t.pumpWidget(host(const RevealPanel(accent: Colors.teal, child: Text('The answer')), reduce: true));
      final full = t.getSize(find.byType(RevealPanel)).height;
      await t.pump();
      expect(t.getSize(find.byType(RevealPanel)).height, full); // no animation: already complete
    });
  });

  group('RatingBreakdown', () {
    testWidgets('says every count in words (not only colour) and in one spoken sentence', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(host(const RatingBreakdown(ratings: [1, 3, 3, 3, 4, 2, 3])));
      expect(find.text('Again 1'), findsOneWidget);
      expect(find.text('Hard 1'), findsOneWidget);
      expect(find.text('Good 4'), findsOneWidget);
      expect(find.text('Easy 1'), findsOneWidget);
      expect(find.bySemanticsLabel('How it went: 1 Again, 1 Hard, 4 Good, 1 Easy'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('nothing for an empty session', (t) async {
      await t.pumpWidget(host(const RatingBreakdown(ratings: [])));
      expect(find.byType(Text), findsNothing);
    });
  });
}
