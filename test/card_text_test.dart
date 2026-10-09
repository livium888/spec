import 'package:daily_learning/domain/card_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('questions get smaller as they get longer, and never bigger than before (26)', () {
    final sizes = [for (final n in [10, 60, 61, 120, 121, 200, 201, 300, 301, 600]) questionFontSize(n, CardTextSize.medium)];
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], lessThanOrEqualTo(sizes[i - 1]));
    }
    expect(sizes.first, lessThan(26));
    expect(sizes.last, greaterThanOrEqualTo(15));
  });

  test('Small < Medium < Large for the same question, the answer and the extras', () {
    for (final f in [(int n, CardTextSize s) => questionFontSize(n, s), (int n, CardTextSize s) => answerFontSize(s), (int n, CardTextSize s) => extrasScale(s)]) {
      expect(f(80, CardTextSize.small), lessThan(f(80, CardTextSize.medium)));
      expect(f(80, CardTextSize.medium), lessThan(f(80, CardTextSize.large)));
    }
  });

  test('the stored choice is read safely; anything unknown is Medium', () {
    expect(cardTextSizeFrom('small'), CardTextSize.small);
    expect(cardTextSizeFrom('large'), CardTextSize.large);
    expect(cardTextSizeFrom('medium'), CardTextSize.medium);
    expect(cardTextSizeFrom(null), CardTextSize.medium);
    expect(cardTextSizeFrom('huge'), CardTextSize.medium);
  });

  test('only a question over 90 characters is folded after the reveal', () {
    expect(shouldCollapseQuestion('x' * 90), isFalse);
    expect(shouldCollapseQuestion('x' * 91), isTrue);
  });
}
