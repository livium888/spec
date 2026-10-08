/// Daily reminder rules. Pure: times are the phone's local clock.
library;

/// When the next reminder should fire: today at [hour]:[minute] if that is still ahead and today's
/// reviews are not finished, otherwise tomorrow. A reminder after the work is done would be noise.
DateTime nextReminder(DateTime nowLocal, int hour, int minute, {required bool doneToday}) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour, minute);
  if (!doneToday && today.isAfter(nowLocal)) return today;
  // Calendar arithmetic (not +24h) so a daylight-saving change cannot move it by an hour.
  return DateTime(nowLocal.year, nowLocal.month, nowLocal.day + 1, hour, minute);
}

const kReminderTitle = 'Daily Learning';
const _bodies = [
  'Your cards are ready. A few minutes keeps it all in your head.',
  'A short session today? Your reviews are lined up.',
  'Ready when you are: a few quick cards, then you are done.',
  'A little today saves a lot of relearning later.',
];

/// Friendly, never guilt-tripping. Rotates by day so it does not feel like a form letter.
String reminderBody(DateTime dayLocal) =>
    _bodies[(dayLocal.year * 372 + dayLocal.month * 31 + dayLocal.day) % _bodies.length];

String formatClock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
