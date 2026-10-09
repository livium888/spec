import 'package:daily_learning/domain/review_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a card left open for hours counts as at most a minute; normal answers are untouched', () {
    expect(cappedCardMs(7000), 7000);
    expect(cappedCardMs(60000), 60000);
    expect(cappedCardMs(3 * 60 * 60 * 1000), kMaxCardMs);
    expect(cappedCardMs(-5), 0);
  });
}
