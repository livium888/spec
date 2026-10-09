/// How big card text is. The size follows the length of the question (a long question at a big
/// size fills the whole screen) and the learner's "Card text size" choice. The phone's own font
/// size setting still multiplies all of this on top: it is never capped (WCAG 1.4.4).
library;

enum CardTextSize { small, medium, large }

const kCardTextSizeKey = 'card_text_size';

CardTextSize cardTextSizeFrom(String? stored) => switch (stored) {
      'small' => CardTextSize.small,
      'large' => CardTextSize.large,
      _ => CardTextSize.medium,
    };

double cardTextScale(CardTextSize s) => switch (s) {
      CardTextSize.small => 0.88,
      CardTextSize.medium => 1.0,
      CardTextSize.large => 1.15,
    };

/// Question size in logical pixels for a question of [length] characters. Hand-set steps (they
/// need a real phone and a real pair of eyes): short questions stay comfortable to read at a
/// glance, long ones shrink so the answer is not pushed off the screen.
double questionFontSize(int length, CardTextSize size) {
  final base = length <= 60
      ? 22.0
      : length <= 120
          ? 20.0
          : length <= 200
              ? 18.0
              : length <= 300
                  ? 17.0
                  : 16.0;
  return base * cardTextScale(size);
}

/// The short answer's size.
double answerFontSize(CardTextSize size) => 18.0 * cardTextScale(size);

/// Extras (why it matters, example, hook) are body text, slightly under the answer.
double extrasScale(CardTextSize size) => 0.92 * cardTextScale(size);

/// Once the answer is showing, a long question is folded to a few lines so the answer gets the
/// room; a short one stays whole. Tapping the folded question shows all of it again.
const kCollapseQuestionOver = 90;
bool shouldCollapseQuestion(String question) => question.length > kCollapseQuestionOver;
