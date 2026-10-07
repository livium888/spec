/// Compact interval label for rating buttons: 1m, 10m, 3h, 4d, 2.5mo, 1.2y.
String formatInterval(Duration d) {
  final m = d.inSeconds / 60;
  if (m < 1) return '<1m';
  if (m < 60) return '${m.round()}m';
  final h = m / 60;
  if (h < 24) return '${h.round()}h';
  final days = h / 24;
  if (days < 30) return '${days.round()}d';
  if (days < 365) return '${(days / 30).toStringAsFixed(1)}mo';
  return '${(days / 365).toStringAsFixed(1)}y';
}

String ratingName(int r) => const {1: 'Again', 2: 'Hard', 3: 'Good', 4: 'Easy'}[r]!;
