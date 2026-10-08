/// A forgiving streak. Consecutive study days count; ONE missed day is bridged ("rest day")
/// once the run before it is at least 3 days long, and at most once per 7 active days.
/// Designed to reward returning, not to punish a single missed day.
class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.best,
    required this.activeToday,
    required this.restDayProtected,
  });
  final int current;
  final int best;
  final bool activeToday;

  /// Yesterday was skipped and is being forgiven; studying today keeps the streak.
  final bool restDayProtected;

  static const none = StreakInfo(current: 0, best: 0, activeToday: false, restDayProtected: false);
}

const _graceEveryActiveDays = 7;
const _minRunForGrace = 3;

/// [activeDays] are logical day indices (see DayClock.dayIndex); [today] is today's index.
StreakInfo computeStreak(Set<int> activeDays, int today) {
  if (activeDays.isEmpty) return StreakInfo.none;
  final days = activeDays.toList()..sort();
  var count = 0, best = 0;
  var sinceGrace = _graceEveryActiveDays; // active days since a rest day was last used
  int? prev;
  for (final d in days) {
    if (prev == null || d - prev > 2) {
      count = 1;
      sinceGrace = _graceEveryActiveDays;
    } else if (d == prev + 1) {
      count++;
      sinceGrace++;
    } else if (count >= _minRunForGrace && sinceGrace >= _graceEveryActiveDays) {
      count++; // the single missed day in between is forgiven
      sinceGrace = 1;
    } else {
      count = 1;
      sinceGrace = _graceEveryActiveDays;
    }
    if (count > best) best = count;
    prev = d;
  }
  final last = prev!;
  final activeToday = activeDays.contains(today);
  if (last >= today - 1) {
    return StreakInfo(current: count, best: best, activeToday: activeToday, restDayProtected: false);
  }
  if (last == today - 2 && count >= _minRunForGrace && sinceGrace >= _graceEveryActiveDays) {
    return StreakInfo(current: count, best: best, activeToday: false, restDayProtected: true);
  }
  return StreakInfo(current: 0, best: best, activeToday: false, restDayProtected: false);
}
