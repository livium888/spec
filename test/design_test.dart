import 'package:daily_learning/presentation/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('colour pairs meet WCAG AA (4.5:1 for text)', () {
    for (final (name, c) in [('light', AppColors.light), ('dark', AppColors.dark)]) {
      test(name, () {
        void pass(String what, Color fg, Color bg, [double min = 4.5]) {
          final r = contrastRatio(fg, bg);
          expect(r, greaterThanOrEqualTo(min), reason: '$name $what = ${r.toStringAsFixed(2)}');
        }

        pass('ink on paper', c.ink, c.paper);
        pass('ink on surface', c.ink, c.surface);
        pass('ink on surfaceDim', c.ink, c.surfaceDim);
        pass('soft ink on paper', c.inkSoft, c.paper);
        pass('soft ink on surface', c.inkSoft, c.surface);
        pass('soft ink on surfaceDim', c.inkSoft, c.surfaceDim);
        pass('on-accent on accent (buttons)', c.onAccent, c.accent);
        pass('accent text on paper (text buttons)', c.accent, c.paper);
        pass('accent text on surface', c.accent, c.surface);
        pass('ink on accent tint', c.ink, c.accentTint);
        pass('accent on accent tint (selected chips/nav)', c.accent, c.accentTint);
        pass('good on its tint', c.good, c.goodTint);
        pass('warn on its tint', c.warn, c.warnTint);
        pass('danger on its tint', c.danger, c.dangerTint);
        pass('info on its tint', c.info, c.infoTint);
        pass('ink on good tint', c.ink, c.goodTint);
        pass('ink on warn tint', c.ink, c.warnTint);
        pass('ink on danger tint', c.ink, c.dangerTint);
        pass('ink on info tint', c.ink, c.infoTint);
        pass('line is visible against paper (non-text 1.2)', c.line, c.paper, 1.1);
      });
    }
  });

  test('contrast function matches known values', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 1e-9));
  });
}
