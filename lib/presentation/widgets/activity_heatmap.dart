import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Weeks of activity as small squares (like a contribution graph). Intensity is by count,
/// and the section always has a text summary next to it so it never relies on colour alone.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.activity,
    required this.todayIndex,
    this.weeks = 17,
  });
  final Map<int, int> activity; // logical day index -> answers
  final int todayIndex;
  final int weeks;

  /// Day index of the Monday of the current week, given a weekday for today (1 = Monday).
  static int weekStart(int todayIndex, int todayWeekday) => todayIndex - (todayWeekday - 1);

  static int level(int n) => n <= 0 ? 0 : n < 5 ? 1 : n < 15 ? 2 : n < 30 ? 3 : 4;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Weekday of "today": logical day index 0 is 1970-01-01 (a Thursday, weekday 4).
    final weekday = ((todayIndex + 3) % 7) + 1;
    final start = weekStart(todayIndex, weekday) - (weeks - 1) * 7;
    final steps = [
      c.surfaceDim,
      Color.lerp(c.accentTint, c.accent, 0.35)!,
      Color.lerp(c.accentTint, c.accent, 0.62)!,
      Color.lerp(c.accentTint, c.accent, 0.85)!,
      c.accent,
    ];
    final active = [for (var d = start; d <= todayIndex; d++) if ((activity[d] ?? 0) > 0) d].length;
    return Semantics(
      label: 'Activity over the last $weeks weeks: studied on $active days.',
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, box) {
          const gap = 4.0;
          final cell = ((box.maxWidth - gap * (weeks - 1)) / weeks).clamp(6.0, 22.0);
          return SizedBox(
            height: cell * 7 + gap * 6,
            child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              for (var w = 0; w < weeks; w++) ...[
                Column(children: [
                  for (var d = 0; d < 7; d++) ...[
                    () {
                      final idx = start + w * 7 + d;
                      final future = idx > todayIndex;
                      return Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: future ? Colors.transparent : steps[level(activity[idx] ?? 0)],
                          borderRadius: BorderRadius.circular(cell * 0.28),
                          border: idx == todayIndex ? Border.all(color: c.ink, width: 1.5) : null,
                        ),
                      );
                    }(),
                    if (d < 6) const SizedBox(height: gap),
                  ],
                ]),
                if (w < weeks - 1) const SizedBox(width: gap),
              ],
            ]),
          );
        }),
      ),
    );
  }
}
