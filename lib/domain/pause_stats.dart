/// "Pause before apps", second round (D59): what the pause counts, how its wait grows, the daily open limit, and the
/// question it shows. Pure Dart. PauseStore.kt / PauseActivity.kt mirror [pauseWaitSeconds], [pauseOpenLimitReached]
/// and the day boundary (DayClock): keep them in step.
library;

import 'day_clock.dart';

/// What happened at a pause. `shown`: an attempt to open a paused app or site (the pause came up).
enum PauseKind { shown, back, open, cards }

class PauseEvent {
  const PauseEvent(this.atMs, this.kind, this.key);
  final int atMs;
  final PauseKind kind;

  /// The app (package) or site (`site:` + rule) it was about; `test:` for the settings screen's test.
  final String key;

  /// One line of the phone side's log: `ms<TAB>kind<TAB>key`. Null for anything else (the log is read back from
  /// storage; a damaged line is skipped, never trusted).
  static PauseEvent? parse(String line) {
    final p = line.split('\t');
    if (p.length != 3) return null;
    final at = int.tryParse(p[0]);
    final kind = PauseKind.values.where((k) => k.name == p[1]).firstOrNull;
    if (at == null || kind == null || p[2].isEmpty || p[2].length > 300) return null;
    return PauseEvent(at, kind, p[2]);
  }
}

class PauseDay {
  PauseDay(this.dayIndex);
  final int dayIndex;
  int shown = 0, back = 0, open = 0, cards = 0;

  /// Attempts that ended without opening the app: turned back, or went to the cards instead.
  int get turnedAway => back + cards;
}

/// The last [days] app days (oldest first, today last), counted from [events]. Test pauses are left out.
List<PauseDay> pauseDays(Iterable<PauseEvent> events, DayClock clock, DateTime now, {int days = 7}) {
  final today = clock.dayIndex(now.toUtc());
  final out = [for (var i = days - 1; i >= 0; i--) PauseDay(today - i)];
  for (final e in events) {
    if (e.key.startsWith('test:')) continue;
    final d = clock.dayIndex(DateTime.fromMillisecondsSinceEpoch(e.atMs, isUtc: true));
    final i = d - (today - days + 1);
    if (i < 0 || i >= days) continue;
    final day = out[i];
    switch (e.kind) {
      case PauseKind.shown:
        day.shown++;
      case PauseKind.back:
        day.back++;
      case PauseKind.open:
        day.open++;
      case PauseKind.cards:
        day.cards++;
    }
  }
  return out;
}

/// The sentence for Today, or null when the pause did not come up this week.
String? pauseWeekLine(List<PauseDay> week) {
  final shown = week.fold<int>(0, (a, d) => a + d.shown);
  if (shown == 0) return null;
  final away = week.fold<int>(0, (a, d) => a + d.turnedAway);
  final cards = week.fold<int>(0, (a, d) => a + d.cards);
  final times = shown == 1 ? 'time' : 'times';
  return 'This week the pause came up $shown $times; you turned away $away'
      '${cards > 0 ? ', $cards of them for cards' : ''}.';
}

/// Breathing before "open": 10 seconds, plus [kPauseWaitStep] for each earlier pause of the same app or site today,
/// up to [kPauseWaitMax] (D59). [shownToday] counts this pause too.
const kPauseWaitBase = 10;
const kPauseWaitStep = 5;
const kPauseWaitMax = 60;
int pauseWaitSeconds({required int shownToday, required bool rising}) {
  if (!rising || shownToday <= 1) return kPauseWaitBase;
  final s = kPauseWaitBase + kPauseWaitStep * (shownToday - 1);
  return s > kPauseWaitMax ? kPauseWaitMax : s;
}

/// Daily open limit (0 = off): once an app or site was opened this many times today by breathing, only the cards
/// (or not now) remain.
const kPauseOpenLimitChoices = [0, 1, 2, 3, 5, 8, 10];
bool pauseOpenLimitReached({required int opensToday, required int limit}) => limit > 0 && opensToday >= limit;

/// The next card's question, as plain short text for the pause screen: markup marks dropped, one line, at most
/// [kPausePreviewChars] characters. Empty when there is nothing readable (a picture-only card).
const kPausePreviewChars = 140;
String pausePreview(String front) {
  var s = front
      .replaceAllMapped(RegExp(r'\$\$?([^$]*)\$\$?'), (m) => m[1]!) // formulas: keep their source, without the dollar signs
      .replaceAll(RegExp(r'[*_`#>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.length > kPausePreviewChars) s = '${s.substring(0, kPausePreviewChars - 1).trimRight()}…';
  return s;
}
