/// "Day" boundaries for scheduling. All instants are UTC epoch ms; the day
/// rolls over at [rolloverHour] *local* time (default 04:00).
class DayClock {
  DayClock({this.rolloverHour = 4, Duration Function(DateTime utc)? utcOffset})
      : _offset = utcOffset ?? ((utc) => utc.toLocal().timeZoneOffset);

  final int rolloverHour;
  final Duration Function(DateTime utc) _offset;

  static const _dayMs = 86400000;

  int _shiftMs(DateTime utc) =>
      _offset(utc).inMilliseconds - rolloverHour * 3600000;

  /// Integer index of the logical day containing [utc].
  int dayIndex(DateTime utc) =>
      ((utc.millisecondsSinceEpoch + _shiftMs(utc)) / _dayMs).floor();

  /// UTC ms at which the logical day containing [utc] began.
  int dayStartMs(DateTime utc) =>
      dayIndex(utc) * _dayMs - _shiftMs(utc);

  /// UTC ms at which the next logical day begins (exclusive end of today).
  int dayEndMs(DateTime utc) => dayStartMs(utc) + _dayMs;
}
