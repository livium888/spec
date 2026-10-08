import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/stats_service.dart';
import '../domain/milestones.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/soft_card.dart';

final statsProvider = FutureProvider.autoDispose<ProgressStats>((ref) async {
  ref.watch(refreshProvider);
  return ref.watch(statsServiceProvider).compute();
});

/// What your effort has built: streak, activity, memory strength, what is coming, milestones.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return SafeArea(
      bottom: false,
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $e'))),
        data: (s) => ProgressBody(s),
      ),
    );
  }
}

class ProgressBody extends StatelessWidget {
  const ProgressBody(this.s, {super.key});
  final ProgressStats s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final st = s.streak;
    final activeDays = s.activity.values.where((v) => v > 0).length;
    final retention = s.retention30d;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
      Text('Progress', style: t.headlineMedium),
      const SizedBox(height: Sp.l),
      SoftCard(
        radius: Rd.hero,
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.accentTint, shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department_rounded, color: c.accent, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${st.current}', style: AppText.serif(44, weight: 700, color: c.ink, height: 1.0)),
              Text(st.current == 1 ? 'day streak' : 'day streak', style: t.labelMedium),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Best', style: t.labelSmall),
            Text('${st.best}', style: t.titleLarge),
          ]),
        ]),
      ),
      if (st.restDayProtected)
        Padding(
          padding: const EdgeInsets.only(top: Sp.s),
          child: Text('Yesterday was a rest day, and it is forgiven. Study today to keep your streak going.', style: t.bodySmall),
        ),
      const SectionTitle('Activity'),
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ActivityHeatmap(activity: s.activity, todayIndex: s.todayIndex),
          const SizedBox(height: Sp.m),
          Text('You studied on $activeDays of the last 17 weeks\' days.', style: t.bodySmall),
        ]),
      ),
      const SectionTitle('Your memory'),
      Row(children: [
        Expanded(child: _Stat('${s.matureCards}', 'in long-term memory', c.good)),
        const SizedBox(width: Sp.m),
        Expanded(
          child: _Stat(
            retention == null ? '—' : '${(retention * 100).round()}%',
            retention == null ? 'recall (needs more answers)' : 'recalled, last 30 days',
            c.accent,
          ),
        ),
      ]),
      const SizedBox(height: Sp.m),
      SoftCard(child: _MemoryBar(s)),
      const SectionTitle('Coming up'),
      SoftCard(child: _Forecast(s.forecast)),
      const SectionTitle('Milestones'),
      GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: Sp.l,
        crossAxisSpacing: Sp.s,
        childAspectRatio: 0.78,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final m in s.milestones) _Badge(m)],
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return SoftCard(
      semanticLabel: '$value $label',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: AppText.serif(34, weight: 700, color: c.ink, height: 1.05)),
        const SizedBox(height: 2),
        Text(label, style: t.bodySmall),
      ]),
    );
  }
}

class _MemoryBar extends StatelessWidget {
  const _MemoryBar(this.s);
  final ProgressStats s;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final parts = [
      ('New', s.newCards, c.line),
      ('Learning', s.learningCards, c.warn),
      ('Growing', s.youngCards, c.info),
      ('Long-term', s.matureCards, c.good),
    ];
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${s.totalCards} cards', style: t.titleSmall),
      const SizedBox(height: Sp.s),
      ClipRRect(
        borderRadius: BorderRadius.circular(Rd.pill),
        child: SizedBox(
          height: 14,
          child: total == 0
              ? ColoredBox(color: c.line)
              : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final p in parts)
                    if (p.$2 > 0) Expanded(flex: p.$2, child: ColoredBox(color: p.$3)),
                ]),
        ),
      ),
      const SizedBox(height: Sp.m),
      Wrap(spacing: Sp.l, runSpacing: Sp.xs, children: [
        for (final p in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${p.$1} ${p.$2}', style: t.bodySmall),
          ]),
      ]),
    ]);
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast(this.counts);
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final maxV = counts.fold<int>(1, (m, v) => v > m ? v : m);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Reviews scheduled over the next week', style: t.bodySmall),
      const SizedBox(height: Sp.m),
      SizedBox(
        height: 104,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < counts.length; i++)
            Expanded(
              child: Semantics(
                label: '${i == 0 ? 'Today' : names[(today - 1 + i) % 7]}: ${counts[i]} reviews',
                child: ExcludeSemantics(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${counts[i]}', style: t.labelSmall),
                    const SizedBox(height: 2),
                    Container(
                      height: 8 + 56.0 * counts[i] / maxV,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: i == 0 ? c.accent : Color.lerp(c.accentTint, c.accent, 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(i == 0 ? 'Today' : names[(today - 1 + i) % 7], style: t.labelSmall),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.m);
  final Milestone m;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final earned = m.earned;
    const icons = {
      'first': Icons.flag_rounded,
      'rhythm': Icons.graphic_eq_rounded,
      'week': Icons.event_available_rounded,
      'root': Icons.psychology_rounded,
      'wide': Icons.explore_rounded,
      'round2': Icons.replay_rounded,
      'month': Icons.local_fire_department_rounded,
      'hundred': Icons.workspace_premium_rounded,
      'thousand': Icons.military_tech_rounded,
    };
    return SizedBox(
      child: Semantics(
        label: '${m.title}. ${m.description} ${earned ? 'Earned.' : '${m.progress} of ${m.goal}.'}',
        child: ExcludeSemantics(
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned ? c.accent : c.surfaceDim,
                border: Border.all(color: earned ? c.accent : c.line, width: 2),
              ),
              child: Icon(earned ? (icons[m.id] ?? Icons.emoji_events_rounded) : Icons.lock_outline_rounded,
                  color: earned ? c.onAccent : c.inkSoft, size: 28),
            ),
            const SizedBox(height: 6),
            Text(m.title, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: c.ink)),
            Text(earned ? 'Earned' : '${m.progress}/${m.goal}', style: t.labelSmall),
          ]),
        ),
      ),
    );
  }
}
