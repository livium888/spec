import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/pause_stats.dart';
import 'pause_apps_screen.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// The pause before apps, as Progress and Today show it (D59). Null when the learner never set the pause up.
class PauseSummary {
  const PauseSummary({required this.days, required this.on, required this.watching});

  /// The last 7 app days, oldest first.
  final List<PauseDay> days;

  /// Switched on in Android's settings.
  final bool on;

  /// At least one app, browser or site is chosen.
  final bool watching;

  int get shownWeek => days.fold(0, (a, d) => a + d.shown);
}

final pauseSummaryProvider = FutureProvider.autoDispose<PauseSummary?>((ref) async {
  ref.watch(refreshProvider);
  final settings = ref.watch(pauseSettingsProvider);
  final c = await settings.load();
  if (!c.saved) return null;
  final status = await ref.watch(pauseBridgeProvider).status();
  return PauseSummary(
    days: await settings.week(),
    on: status.on,
    watching: c.apps.isNotEmpty || c.wholeBrowsers.isNotEmpty || c.sites.isNotEmpty,
  );
});

/// Progress: attempts to open the paused apps over the last 7 days, and how many were turned away.
class PauseWeekCard extends StatelessWidget {
  const PauseWeekCard(this.s, {super.key});
  final PauseSummary s;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final maxV = s.days.fold<int>(1, (m, d) => d.shown > m ? d.shown : m);
    final today = s.days.last;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    String dayName(int i) {
      if (i == s.days.length - 1) return 'Today';
      // App days are counted from 1970-01-01 (a Thursday) in local time.
      return names[(s.days[i].dayIndex + 3) % 7];
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Pause before apps', style: t.titleMedium),
      const SizedBox(height: 4),
      Text(
        s.shownWeek == 0
            ? (s.on ? 'The pause has not come up in the last 7 days.' : 'The pause is off, so nothing is counted.')
            : 'Today: ${today.shown} ${today.shown == 1 ? 'attempt' : 'attempts'} to open, ${today.turnedAway} turned away.',
        style: t.bodyMedium,
      ),
      const SizedBox(height: Sp.m),
      SizedBox(
        height: 110,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < s.days.length; i++)
            Expanded(
              child: Semantics(
                container: true, // one node per day, read on its own
                label: '${dayName(i)}: ${s.days[i].shown} attempts, ${s.days[i].turnedAway} turned away',
                child: ExcludeSemantics(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${s.days[i].shown}', style: t.labelSmall),
                    const SizedBox(height: 2),
                    // The whole bar is every attempt; its solid lower part is the ones turned away.
                    Container(
                      height: 8 + 60.0 * s.days[i].shown / maxV,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.accent, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: s.days[i].shown == 0 ? 0 : s.days[i].turnedAway / s.days[i].shown,
                        widthFactor: 1,
                        child: Container(decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(6))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dayName(i), style: t.labelSmall),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: Sp.s),
      Text('Each bar is every attempt to open a paused app or site; the filled part is the ones you turned away from '
          '(not now, or the cards). The fewer attempts over time, the better it is working.', style: t.bodySmall),
    ]);
  }
}

/// Today: a warning when the pause stopped (some phones switch it off), else this week's line. Nothing when the
/// pause was never set up, or it did not come up this week.
class PauseTodayNote extends ConsumerWidget {
  const PauseTodayNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(pauseSummaryProvider).value;
    if (s == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    if (!s.on && s.watching) {
      return Padding(
        padding: const EdgeInsets.only(top: Sp.m),
        child: SoftCard(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const PauseAppsScreen()))
              .then((_) => ref.invalidate(pauseSummaryProvider)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(Icons.pause_circle_outline, color: c.warn),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('The pause before apps is off', style: t.titleSmall),
                Text('It works once it is switched on in Android\'s settings. Tap to do it.', style: t.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
    }
    final line = pauseWeekLine(s.days);
    if (line == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Sp.m),
      child: Row(children: [
        Icon(Icons.pause_circle_outline, size: 20, color: c.inkSoft),
        const SizedBox(width: 8),
        Expanded(child: Text(line, style: t.bodyMedium)),
      ]),
    );
  }
}
