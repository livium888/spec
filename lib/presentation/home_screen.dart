import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_util/saf_util.dart';

import '../app/launch_service.dart';
import '../app/providers.dart';
import '../data/backup/backup_service.dart';
import '../data/backup/backup_storage.dart';
import '../data/settings_repo.dart';
import '../data/stats_service.dart';
import '../domain/memory_summary.dart';
import '../domain/study_advisor.dart';
import '../domain/study_card.dart';
import 'advice_card.dart';
import 'learn_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'theme/app_theme.dart';
import 'theme/subject_style.dart';
import 'theme/tokens.dart';
import 'topics_screen.dart';
import 'guide_screen.dart';
import 'memory_model_screen.dart';
import 'widgets/progress_ring.dart';
import 'widgets/soft_card.dart';

class HomeData {
  const HomeData(this.queue, this.lastBackupMs, this.folderSet, this.advice, this.stats,
      {this.guideSeen = true, this.modelNudge});
  final bool guideSeen;

  /// "Tune my scheduling" is worth doing now (null: no nudge).
  final String? modelNudge;
  final DailyQueue queue;
  final int lastBackupMs; // 0 = never
  final bool folderSet;
  final Advice advice;
  final ProgressStats stats;
}

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  ref.watch(refreshProvider);
  final settings = ref.watch(settingsRepoProvider);
  final queue = await ref.watch(queueServiceProvider).build();
  final stats = await ref.watch(statsServiceProvider).compute();
  // Keep tomorrow's reminder right: once today's reviews are done, skip today's.
  // The home-screen widget and the Quick Settings tile show this number (D51).
  final clock = await settings.dayClock();
  ref
      .read(dueBridgeProvider)
      .publish(
          due: queue.ordered.length,
          minutes: (queue.ordered.length * stats.secondsPerCard / 60).ceil(),
          dayEndMs: clock.dayEndMs(DateTime.now().toUtc()))
      .ignore();
  final doneToday = queue.learning.isEmpty && queue.reviews.isEmpty && stats.todayAnswered > 0;
  final reminders = ref.watch(reminderServiceProvider);
  reminders.refresh(doneToday: doneToday).ignore(); // fire and forget; it never throws
  return HomeData(
    queue,
    await settings.getInt(BackupService.lastSuccessKey, 0),
    await settings.get(SettingsRepo.backupTreeUri) != null,
    await ref.watch(learnServiceProvider).advice(),
    stats,
    guideSeen: await settings.get(SettingsRepo.guideSeen) != null,
    modelNudge: await _modelNudge(ref),
  );
});

Future<String?> _modelNudge(Ref ref) async {
  try {
    final svc = ref.watch(optimizerServiceProvider);
    if (await svc.bannerSnoozed()) return null;
    final a = await svc.quickAdvice();
    return a.ready ? a.reasons.first : null;
  } catch (_) {
    return null; // a nudge must never break Today
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _backupOnOpen());
  }

  /// Trigger 3 of 3: on-open backup if the last one is older than 7 days.
  Future<void> _backupOnOpen() async {
    final settings = ref.read(settingsRepoProvider);
    final uri = await settings.get(SettingsRepo.backupTreeUri);
    if (uri == null) return;
    final svc = ref.read(backupServiceProvider);
    if (!await svc.isStale()) return;
    final tmp = ref.read(bootstrapProvider).tmpDir;
    await svc.export(SafBackupStorage(uri), tmp);
    if (mounted) ref.read(refreshProvider.notifier).bump();
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) ref.read(refreshProvider.notifier).bump();
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(homeDataProvider);
    return SafeArea(
      bottom: false,
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Could not load: $e'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.read(refreshProvider.notifier).bump(), child: const Text('Retry')),
            ]),
          ),
        ),
        data: (d) => _body(context, d),
      ),
    );
  }

  Future<void> _openGuide() async {
    await ref.read(settingsRepoProvider).set(SettingsRepo.guideSeen, '1');
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GuideScreen()));
    if (mounted) ref.read(refreshProvider.notifier).bump();
  }

  Future<void> _dismissGuide() async {
    await ref.read(settingsRepoProvider).set(SettingsRepo.guideSeen, '1');
    if (mounted) ref.read(refreshProvider.notifier).bump();
  }

  Widget _body(BuildContext context, HomeData d) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 18 ? 'Good afternoon' : 'Good evening';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting, style: t.headlineMedium),
              Text('${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}', style: t.bodySmall),
            ]),
          ),
          IconButton(
            tooltip: 'How it works',
            icon: const Icon(Icons.help_outline),
            onPressed: _openGuide,
          ),
          IconButton(
            tooltip: 'Settings and backup',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _go(const SettingsScreen()),
          ),
        ]),
        if (!d.guideSeen) ...[
          const SizedBox(height: Sp.m),
          _GuideCard(onOpen: _openGuide, onDismiss: _dismissGuide),
        ],
        const SizedBox(height: Sp.l),
        _TodayCard(d,
            onReview: () => _go(const ReviewScreen()),
            onQuick: () => _go(const ReviewScreen(quick: kQuickSessionCards)),
            onLearn: () => _go(const LearnScreen())),
        const SizedBox(height: Sp.m),
        _LearnTile(d.advice, onTap: () => _go(const LearnScreen())),
        const SizedBox(height: Sp.s),
        AdviceCard(d.advice, compact: true),
        if (d.stats.subjects.isNotEmpty) ...[
          const SectionTitle('Your subjects'),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: d.stats.subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: Sp.m),
              itemBuilder: (context, i) {
                final s = d.stats.subjects[i];
                return SubjectTile(s, onTap: () => _go(TopicsScreen(domainId: s.domainId)));
              },
            ),
          ),
        ],
        // Housekeeping lives below the day's work, so the first screen is one decision (D48).
        if (d.guideSeen && d.modelNudge != null) ...[
          const SizedBox(height: Sp.l),
          _ModelNudge(
            why: d.modelNudge!,
            onOpen: () => _go(const MemoryModelScreen()),
            onLater: () async {
              await ref.read(optimizerServiceProvider).snoozeBanner(const Duration(days: 14));
              if (mounted) ref.read(refreshProvider.notifier).bump();
            },
          ),
        ],
        const SizedBox(height: Sp.xl),
        _BackupBanner(d, onTap: () => _go(const SettingsScreen())),
      ],
    );
  }
}

class _ModelNudge extends StatelessWidget {
  const _ModelNudge({required this.why, required this.onOpen, required this.onLater});
  final String why;
  final VoidCallback onOpen, onLater;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your scheduling can be tuned to you', style: t.titleSmall),
        const SizedBox(height: 4),
        Text(why, style: t.bodyMedium),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.tonal(onPressed: onOpen, child: const Text('See details')),
          const SizedBox(width: 8),
          TextButton(onPressed: onLater, child: const Text('Later')),
        ]),
      ]),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.onOpen, required this.onDismiss});
  final VoidCallback onOpen, onDismiss;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      color: AppColors.of(context).accentTint,
      borderColor: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('New here?', style: t.titleSmall),
        const SizedBox(height: 4),
        Text('A two-minute guide to how the app works and what to do each day.', style: t.bodyMedium),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton(onPressed: onOpen, child: const Text('Show me')),
          const SizedBox(width: 8),
          TextButton(onPressed: onDismiss, child: const Text('Not now')),
        ]),
      ]),
    );
  }
}

/// The hero: how much is left today, the streak, and the one big button.
class _TodayCard extends StatelessWidget {
  const _TodayCard(this.d, {required this.onReview, required this.onQuick, required this.onLearn});
  final HomeData d;
  final VoidCallback onReview, onQuick, onLearn;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final s = d.stats;
    final remaining = d.queue.ordered.length;
    // Cards, not answers: a new card answered three times is one card. A card still waiting in the queue
    // (a learning step due later today) is not "done" yet (D48).
    final waitingIds = {for (final c in d.queue.ordered) c.id};
    final done = s.todayCardIds.where((id) => !waitingIds.contains(id)).length;
    final total = done + remaining;
    final noCards = s.totalCards == 0;
    final caughtUp = remaining == 0 && !noCards;
    final mins = (remaining * s.secondsPerCard / 60).ceil().clamp(1, 999);
    final tomorrow = s.forecast.length > 1 ? s.forecast[1] : 0;

    final String headline;
    final String sub;
    if (noCards) {
      headline = 'Let\'s plant your first cards';
      sub = 'Tap "Learn something new" and the app will pick a topic and write the prompt for you.';
    } else if (remaining > 0) {
      headline = remaining == 1 ? '1 card waiting' : '$remaining cards waiting';
      sub = 'About $mins min${done > 0 ? ' · $done done today' : ''}';
    } else if (done > 0) {
      headline = 'All done for today';
      sub = 'You studied ${done == 1 ? '1 card' : '$done cards'} in ${s.todayMinutes < 1 ? 'under a minute' : '${s.todayMinutes.round()} min'}.'
          '${tomorrow > 0 ? ' $tomorrow reviews are scheduled for tomorrow.' : ''}';
    } else {
      headline = 'You\'re all caught up';
      sub = tomorrow > 0 ? 'Nothing due now. $tomorrow reviews are scheduled for tomorrow.' : 'Nothing due right now.';
    }

    return SoftCard(
      radius: Rd.hero,
      padding: const EdgeInsets.all(20),
      color: c.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProgressRing(
            value: noCards ? 0 : (total == 0 ? 1 : done / total),
            color: caughtUp ? c.good : c.accent,
            track: c.accentTint,
            size: 104,
            stroke: 11,
            semanticLabel: 'Today\'s progress',
            child: caughtUp
                ? Icon(Icons.check_rounded, color: c.good, size: 40)
                : noCards
                    ? Icon(Icons.spa_outlined, color: c.accent, size: 36)
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$remaining', style: AppText.serif(30, weight: 700, color: c.ink, height: 1.0)),
                        Text('left', style: t.labelSmall),
                      ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(headline, style: t.headlineSmall),
              const SizedBox(height: 4),
              Text(sub, style: t.bodyMedium?.copyWith(color: c.inkSoft)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _StreakRow(s),
        if (s.estimatedRecall != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.psychology_outlined, size: 22, color: c.inkSoft),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'You would recall about ${(s.estimatedRecall! * 100).round()}% of what you have learned right now',
                style: t.bodyMedium,
              ),
            ),
          ]),
        ],
        if (remaining > 0) ...[
          const SizedBox(height: 12),
          _QueueSplit(d.queue),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: onReview,
            child: Text(done > 0 ? 'Keep going' : 'Start review'),
          ),
          // A short way in: five cards, then stop (or carry on).
          if (remaining > kQuickSessionCards)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onQuick,
                child: const Text('Just $kQuickSessionCards cards'),
              ),
            ),
        ] else if (noCards) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.auto_awesome),
            onPressed: onLearn,
            label: const Text('Get started'),
          ),
        ],
      ]),
    );
  }
}

/// New, learning and due counts, as in the study overview of the standard flashcard tools (D49).
class _QueueSplit extends StatelessWidget {
  const _QueueSplit(this.q);
  final DailyQueue q;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final parts = [
      (MemoryBucket.fresh.label, q.newCards.length, c.info),
      (MemoryBucket.learning.label, q.learning.length + q.learnAhead.length, c.warn),
      ('Due', q.reviews.length, c.good),
    ];
    return Semantics(
      label: '${parts[0].$2} new, ${parts[1].$2} learning, ${parts[2].$2} due',
      child: ExcludeSemantics(
        child: Wrap(spacing: Sp.l, runSpacing: 4, children: [
          for (final p in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${p.$1} ${p.$2}', style: t.bodyMedium),
            ]),
        ]),
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow(this.s);
  final ProgressStats s;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final st = s.streak;
    final text = st.current == 0
        ? 'Start a streak today'
        : st.restDayProtected
            ? '${st.current}-day streak · rest day used'
            : '${st.current}-day streak';
    final weekday = s.todayWeekday;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(children: [
      Icon(Icons.local_fire_department_outlined, size: 22, color: st.current > 0 ? c.accent : c.inkSoft),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: t.titleSmall)),
      Semantics(
        label: 'Last 7 days: studied on ${s.weekActive.where((x) => x).length}.',
        child: ExcludeSemantics(
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.weekActive[i] ? c.accent : Colors.transparent,
                      border: Border.all(color: s.weekActive[i] ? c.accent : c.line, width: 1.5),
                    ),
                    child: s.weekActive[i] ? Icon(Icons.check, size: 12, color: c.onAccent) : null,
                  ),
                  const SizedBox(height: 2),
                  Text(letters[((weekday - 1) - (6 - i)) % 7],
                      style: t.labelSmall?.copyWith(fontSize: 10)),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _LearnTile extends StatelessWidget {
  const _LearnTile(this.advice, {required this.onTap});
  final Advice advice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return SoftCard(
      color: c.accentTint,
      borderColor: Colors.transparent,
      onTap: onTap,
      semanticLabel: 'Learn something new',
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome, color: c.onAccent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Learn something new', style: t.titleMedium),
            Text('The app picks the topic and writes the prompt.', style: t.bodySmall?.copyWith(color: c.ink)),
          ]),
        ),
        Icon(Icons.chevron_right, color: c.ink),
      ]),
    );
  }
}

/// A subject as a small coloured tile: icon, name, how much is in long-term memory, what is due.
class SubjectTile extends StatelessWidget {
  const SubjectTile(this.s, {super.key, required this.onTap, this.width = 160});
  final SubjectStat s;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final st = SubjectStyle.of(s.domainId, s.name, c.brightness);
    return SizedBox(
      width: width,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        semanticLabel: '${s.name}: ${s.cards} cards, ${s.mature} in long-term memory, ${s.dueNow} due',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: st.tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(st.icon, color: st.strong, size: 22),
            ),
            const Spacer(),
            if (s.dueNow > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: st.tint, borderRadius: BorderRadius.circular(Rd.pill)),
                child: Text('${s.dueNow} due', style: t.labelSmall?.copyWith(color: st.strong)),
              ),
          ]),
          const Spacer(),
          Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(Rd.pill),
            child: LinearProgressIndicator(
              value: s.masteredShare,
              minHeight: 6,
              color: st.strong,
              backgroundColor: st.tint,
            ),
          ),
          const SizedBox(height: 4),
          Text(s.cards == 0 ? 'No cards yet' : '${s.cards} cards', style: t.labelSmall),
        ]),
      ),
    );
  }
}

/// Backup status. State is conveyed by icon AND words, never colour alone.
class _BackupBanner extends StatelessWidget {
  const _BackupBanner(this.d, {required this.onTap});
  final HomeData d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    String text;
    var bad = false;
    if (!d.folderSet) {
      text = 'Backups not set up. Tap to choose a folder.';
      bad = true;
    } else if (d.lastBackupMs == 0) {
      text = 'No successful backup yet.';
      bad = true;
    } else {
      final days = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(d.lastBackupMs)).inDays;
      bad = days > 14;
      final when = days == 0 ? 'today' : '$days day${days == 1 ? '' : 's'} ago';
      text = 'Last backup: $when${bad ? ' - OVERDUE' : ''}';
    }
    return SoftCard(
      onTap: onTap,
      color: bad ? c.dangerTint : c.surface,
      borderColor: bad ? c.danger : c.line,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      semanticLabel: text,
      child: Row(children: [
        Icon(bad ? Icons.warning_amber_rounded : Icons.cloud_done_outlined, color: bad ? c.danger : c.good),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }
}

Future<String?> pickBackupFolder() async =>
    (await SafUtil().pickDirectory(writePermission: true, persistablePermission: true))?.uri;
