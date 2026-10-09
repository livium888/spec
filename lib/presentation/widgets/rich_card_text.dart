import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/card_markup.dart';
import '../theme/tokens.dart';

/// Card text with the safe Markdown subset and LaTeX formulas (see `card_markup.dart`).
/// Text with nothing to format is drawn exactly as before (plain, optionally selectable).
/// Formulas are drawn offline by flutter_math_fork; one that cannot be drawn shows its source.
class RichCardText extends StatelessWidget {
  const RichCardText(this.text, {super.key, required this.style, this.maxLines, this.overflow, this.selectable = false});
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final blocks = parseCardMarkup(text);
    if (isPlainMarkup(blocks)) {
      return selectable && maxLines == null
          ? SelectableText(text, style: style)
          : Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    if (maxLines != null) {
      // A folded question: one flowing run of text, cut after [maxLines].
      final spans = <InlineSpan>[];
      for (final (i, b) in blocks.indexed) {
        if (i > 0) spans.add(const TextSpan(text: '\n'));
        spans.addAll(cardSpans(context, b.inlines, style));
      }
      return Text.rich(TextSpan(style: style, children: spans), maxLines: maxLines, overflow: overflow);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (i, b) in blocks.indexed)
        Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8), child: _block(context, b)),
    ]);
  }

  Widget _block(BuildContext context, MdBlock b) {
    switch (b.kind) {
      case MdKind.display:
        return Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _MathView(b.tex!, style: style, display: true, bold: false),
            ),
          ),
        );
      case MdKind.bullet:
      case MdKind.ordered:
        final marker = b.kind == MdKind.bullet ? '•' : '${b.number}.';
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 26, child: Text(marker, style: style)),
          Expanded(child: Text.rich(TextSpan(style: style, children: cardSpans(context, b.inlines, style)))),
        ]);
      case MdKind.paragraph:
        final rich = Text.rich(TextSpan(style: style, children: cardSpans(context, b.inlines, style)));
        return rich;
    }
  }
}

/// Spans for inline pieces: styled text, code, and formulas (as inline widgets).
List<InlineSpan> cardSpans(BuildContext context, List<MdInline> inlines, TextStyle base) {
  final c = AppColors.of(context);
  return [
    for (final p in inlines)
      if (p.isMath)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _MathView(p.tex!, style: base, display: false, bold: p.bold),
        )
      else
        TextSpan(
          text: p.text,
          style: base.copyWith(
            fontWeight: p.bold ? FontWeight.w800 : null,
            fontStyle: p.italic ? FontStyle.italic : null,
            fontFamily: p.code ? 'monospace' : null,
            fontSize: p.code && base.fontSize != null ? base.fontSize! * 0.92 : null,
            backgroundColor: p.code ? c.surfaceDim : null,
          ),
        ),
  ];
}

class _MathView extends StatelessWidget {
  const _MathView(this.tex, {required this.style, required this.display, required this.bold});
  final String tex;
  final TextStyle style;
  final bool display, bold;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(tex, style: style.copyWith(fontFamily: 'monospace', fontSize: (style.fontSize ?? 16) * 0.9));
    return Semantics(
      label: 'formula: $tex',
      excludeSemantics: true,
      child: Math.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        // Formulas keep a regular weight inside heavier card text, unless the author made them bold.
        textStyle: style.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
        settings: const TexParserSettings(strict: Strict.ignore, maxExpand: 200),
        onErrorFallback: (_) => fallback,
      ),
    );
  }
}
