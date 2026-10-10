import 'package:flutter/material.dart';

import '../../domain/study_card.dart';
import '../../domain/card_markup.dart';
import '../theme/tokens.dart';
import 'rich_card_text.dart';

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

bool _hasMath(String s) => s.contains(r'$') && parseCardMarkup(s).any((b) => b.inlines.any((i) => i.isMath));

bool _hasMarkup(String s) => RegExp(r'[$*_`\\]').hasMatch(s);

/// The text of a non-gap part: a formula with this card's gap inside it shows an empty box until the reveal.
String _revealedOr(ClozePart p, bool revealed) => revealed ? p.text : (p.hiddenText ?? p.text);

/// A cloze sentence: plain text, with this card's own gap shown as a soft blank that fills in place
/// (highlighted in the subject colour) when the answer is revealed. Card text is plain `Text`
/// spans: it comes from an AI, so only the safe Markdown subset and formulas of card_markup.dart are drawn (D42).
class ClozeSentence extends StatelessWidget {
  const ClozeSentence({super.key, required this.parts, required this.revealed, required this.style, required this.strong, required this.tint});
  final List<ClozePart> parts;
  final bool revealed;
  final TextStyle style;
  final Color strong, tint;

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return Text.rich(
      TextSpan(style: style, children: [
        for (final p in parts)
          if (!p.isGap && !_hasMarkup(_revealedOr(p, revealed)))
            TextSpan(text: _revealedOr(p, revealed))
          else if (!p.isGap)
            ...cardSpans(context, parseCardMarkup(_revealedOr(p, revealed)).expand((b) => b.inlines).toList(), style)
          else
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _Gap(part: p, revealed: revealed, style: style, strong: strong, tint: tint, reduce: reduce),
            ),
      ]),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.part, required this.revealed, required this.style, required this.strong, required this.tint, required this.reduce});
  final ClozePart part;
  final bool revealed;
  final TextStyle style;
  final Color strong, tint;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final label = revealed ? 'Answer: ${part.text}' : 'blank${part.hint == null ? '' : ', hint: ${part.hint}'}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AnimatedSize(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: revealed ? tint : tint.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          // A revealed gap that holds a formula is drawn as it is: the formula widget cannot answer the
          // dry-layout question IntrinsicWidth asks, and the underline is gone by then anyway.
          child: revealed && _hasMath(part.text)
              ? RichCardText(part.text, style: style.copyWith(color: strong, fontWeight: FontWeight.w700))
              : _blank(reduce),
        ),
      ),
    );
  }

  Widget _blank(bool reduce) {
    // IntrinsicWidth: the underline takes the width of the text, never the whole line.
    return IntrinsicWidth(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (revealed)
        RichCardText(part.text, style: style.copyWith(color: strong, fontWeight: FontWeight.w700))
      // A fixed-width blank: its size never gives away the length of the answer.
      else
        SizedBox(
          width: part.hint == null ? 72 : (part.hint!.length * 8.5 + 24).clamp(72, 150).toDouble(),
          child: Text(part.hint ?? '…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style.copyWith(fontSize: (style.fontSize ?? 24) * 0.62, color: strong, fontWeight: FontWeight.w600)),
        ),
      // The underline is its own box: a one-sided border cannot be combined with rounded corners.
      AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
        height: revealed ? 0 : 2.5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: strong, borderRadius: BorderRadius.circular(2)),
      ),
    ]));
  }
}

/// The answer side arriving: it opens downwards, fades in and settles a few pixels, and a short
/// accent bar draws itself. With "reduce motion" on it simply appears.
class RevealPanel extends StatefulWidget {
  const RevealPanel({super.key, required this.child, required this.accent});
  final Widget child;
  final Color accent;
  @override
  State<RevealPanel> createState() => _RevealPanelState();
}

class _RevealPanelState extends State<RevealPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.25, 1, curve: Curves.easeOut));
    return SizeTransition(
      sizeFactor: open,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(open),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: open,
              builder: (_, _) => Container(
                width: 44 * open.value,
                height: 4,
                decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            widget.child,
          ]),
        ),
      ),
    );
  }
}

/// Why it matters / Example / Memory hook, all shown one under the other, each with its label.
/// Nothing is hidden behind a tap or a swipe: learners forgot to open tabs, and horizontal swipes
/// clash with the phone's back gesture and need a second way to operate (WCAG 2.5.1).
class ExtrasStack extends StatelessWidget {
  const ExtrasStack({super.key, required this.extras, required this.strong, this.scale = 1.0});
  final List<(String, String)> extras;
  final Color strong;

  /// Multiplies the body text size (the learner's "Card text size").
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final bodyStyle = t.bodyLarge?.copyWith(fontSize: (t.bodyLarge?.fontSize ?? 17) * scale);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, e) in extras.indexed) ...[
          if (i > 0) const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(e.$1, style: t.labelMedium?.copyWith(color: strong, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          RichCardText(e.$2, selectable: true, style: bodyStyle ?? const TextStyle()),
        ],
      ]),
    );
  }
}

/// How the session went, in numbers AND words (never colour alone): a segmented bar and a legend.
class RatingBreakdown extends StatelessWidget {
  const RatingBreakdown({super.key, required this.ratings});
  final List<int> ratings; // 1 Again, 2 Hard, 3 Good, 4 Easy

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final counts = [for (var r = 1; r <= 4; r++) ratings.where((x) => x == r).length];
    if (ratings.isEmpty) return const SizedBox.shrink();
    final parts = [
      ('Again', counts[0], c.danger),
      ('Hard', counts[1], c.warn),
      ('Good', counts[2], c.good),
      ('Easy', counts[3], c.info),
    ];
    final summary = parts.map((p) => '${p.$2} ${p.$1}').join(', ');
    return Semantics(
      label: 'How it went: $summary',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Rd.pill),
          child: SizedBox(
            width: double.infinity,
            height: 12,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final p in parts)
                if (p.$2 > 0) Expanded(flex: p.$2, child: ColoredBox(color: p.$3)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 4, children: [
          for (final p in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${p.$1} ${p.$2}', style: t.bodySmall),
            ]),
        ]),
      ]),
    );
  }
}
