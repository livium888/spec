/// "Move first" (D61): the third way out of the pause before an app, after the cards and the breathing. The learner
/// does an exercise for a set time and then opens the app for the free minutes, that one app only. Pure Dart.
/// PauseStore.kt mirrors [parsePauseMove] (checked equal on the same lines in a test): keep the two in step.
///
/// Nothing can check that the exercise was done. The countdown only stops the tap-through; if the learner fakes it,
/// they have faked themselves, which is the same trust as every card rating.
library;

const kPauseMoveMinSeconds = 10;
const kPauseMoveMaxSeconds = 300;
const kMaxPauseMoves = 12;
const kMaxPauseMoveName = 40;

class PauseMove {
  const PauseMove(this.name, this.seconds);

  /// 1 to 40 characters; no `|`, line breaks or control characters.
  final String name;

  /// How long the countdown runs before the open button appears.
  final int seconds;

  /// The stored form: `name|seconds`.
  String get canonical => '$name|$seconds';

  @override
  String toString() => canonical;
  @override
  bool operator ==(Object other) => other is PauseMove && other.canonical == canonical;
  @override
  int get hashCode => canonical.hashCode;
}

/// Offered until the learner changes the list. Some are quiet enough for a desk.
const kStarterMoves = [
  PauseMove('10 push-ups', 40),
  PauseMove('15 squats', 40),
  PauseMove('1-minute plank', 60),
  PauseMove('30-second desk stretch', 30),
  PauseMove('10 shoulder rolls', 20),
  PauseMove('30-second wall sit', 30),
];

// Control characters (C0, DEL, C1) and the Unicode line and paragraph separators. Plain white space is tidied before
// this check; the Kotlin mirror uses the same explicit white-space class, not each language's own \s.
final _control = RegExp(r'[\u0000-\u001F\u007F-\u009F\u2028\u2029]');
final _space = RegExp(r'[ \t\r\n\f\v]+');

/// Why a typed move is not accepted, in words for the learner; null when it is fine.
String? pauseMoveError(String name, int? seconds) {
  final n = name.replaceAll(_space, ' ').trim();
  if (n.isEmpty) return 'Give it a name, like 10 push-ups';
  if (n.length > kMaxPauseMoveName) return 'Keep the name under $kMaxPauseMoveName characters';
  if (n.contains('|') || _control.hasMatch(n)) return 'The name cannot hold a | or a line break';
  if (seconds == null) return 'How many seconds?';
  if (seconds < kPauseMoveMinSeconds || seconds > kPauseMoveMaxSeconds) {
    return 'Between $kPauseMoveMinSeconds and $kPauseMoveMaxSeconds seconds';
  }
  return null;
}

/// One stored line, or null when it is not a move (a restored backup is external input).
PauseMove? parsePauseMove(String line) {
  final bar = line.lastIndexOf('|');
  if (bar <= 0) return null;
  final name = line.substring(0, bar).replaceAll(_space, ' ').trim();
  final seconds = int.tryParse(line.substring(bar + 1).trim());
  return pauseMoveError(name, seconds) == null ? PauseMove(name, seconds!) : null;
}

/// The learner's moves from the stored text. Nothing stored (null) means the starter list; stored but empty means
/// the learner removed them all. Bad lines and repeats are dropped; at most [kMaxPauseMoves].
List<PauseMove> pauseMovesOf(String? stored) {
  if (stored == null) return kStarterMoves;
  final out = <PauseMove>[];
  for (final line in stored.split('\n')) {
    final m = parsePauseMove(line);
    if (m != null && !out.any((x) => x.name.toLowerCase() == m.name.toLowerCase())) out.add(m);
    if (out.length >= kMaxPauseMoves) break;
  }
  return out;
}

String storePauseMoves(List<PauseMove> moves) => moves.map((m) => m.canonical).join('\n');
