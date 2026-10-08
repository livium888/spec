import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_util/saf_util.dart';

import '../app/providers.dart';
import '../data/backup/backup_service.dart';
import '../data/backup/backup_storage.dart';
import '../data/settings_repo.dart';
import '../domain/study_card.dart';
import 'add_card_screen.dart';
import 'import_screen.dart';
import 'learn_screen.dart';
import 'topics_screen.dart';
import 'prompt_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

class DomainRow {
  const DomainRow(this.id, this.name, this.due, this.fresh, this.leeches);
  final int id;
  final String name;
  final int due, fresh, leeches;
}

class HomeData {
  const HomeData(this.domains, this.queue, this.lastBackupMs, this.folderSet);
  final List<DomainRow> domains;
  final DailyQueue queue;
  final int lastBackupMs; // 0 = never
  final bool folderSet;
}

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  ref.watch(refreshProvider);
  final db = ref.watch(dbProvider);
  final queues = ref.watch(queueServiceProvider);
  final settings = ref.watch(settingsRepoProvider);
  final features = await ref.watch(featuresServiceProvider).compute();
  final leeches = {for (final d in features.domains) d.domainId: d.leechCount};
  final rows = <DomainRow>[];
  for (final d in await db.select(db.domains).get()) {
    if (!d.active) continue;
    final q = await queues.build(domainId: d.id);
    rows.add(DomainRow(d.id, d.name, q.learning.length + q.reviews.length, q.newCards.length,
        leeches[d.id] ?? 0));
  }
  return HomeData(
    rows,
    await queues.build(),
    await settings.getInt(BackupService.lastSuccessKey, 0),
    await settings.get(SettingsRepo.backupTreeUri) != null,
  );
});

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

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Learning'),
        actions: [
          IconButton(
            tooltip: 'Settings and backup',
            icon: const Icon(Icons.settings),
            onPressed: () => _go(const SettingsScreen()),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Could not load: $e'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => ref.read(refreshProvider.notifier).bump(),
                  child: const Text('Retry')),
            ]),
          ),
        ),
        data: (d) => _body(context, d),
      ),
    );
  }

  Widget _body(BuildContext context, HomeData d) {
    final total = d.queue.ordered.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BackupBanner(d, onTap: () => _go(const SettingsScreen())),
        const SizedBox(height: 16),
        if (d.domains.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nothing here yet. Tap "Learn something new": the app writes a prompt, you paste it into '
                'your LLM, then paste the JSON answer back to import.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
        else
          for (final r in d.domains)
            Card(
              child: ListTile(
                onTap: () => _go(const TopicsScreen()),
                trailing: const Icon(Icons.chevron_right),
                title: Text(r.name),
                subtitle: Text('${r.due} due · ${r.fresh} new'
                    '${r.leeches > 0 ? ' · ${r.leeches} leech${r.leeches == 1 ? '' : 'es'}' : ''}'),
              ),
            ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.play_arrow),
          label: Text(total > 0 ? 'Review ($total)' : 'Review'),
          onPressed: () => _go(const ReviewScreen()),
        ),
        if (total == 0 && d.domains.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              d.queue.nextLearningDue != null
                  ? 'Nothing due right now. A learning card returns soon.'
                  : 'All done for today.',
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Learn something new'),
          onPressed: () => _go(const LearnScreen()),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('Import'),
              onPressed: () => _go(const ImportScreen())),
          OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Custom prompt'),
              onPressed: () => _go(const PromptScreen())),
          OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add card'),
              onPressed: () => _go(const AddCardScreen())),
        ]),
      ],
    );
  }
}

/// Backup status. State is conveyed by icon + words + colour, never colour alone.
class _BackupBanner extends StatelessWidget {
  const _BackupBanner(this.d, {required this.onTap});
  final HomeData d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
    final color = bad ? cs.error : cs.onSurface;
    return Semantics(
      button: true,
      label: text,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: bad ? cs.error : cs.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(bad ? Icons.warning_amber : Icons.cloud_done_outlined, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ]),
        ),
      ),
    );
  }
}

// Re-exported so SettingsScreen can share the picker without importing saf_util twice.
Future<String?> pickBackupFolder() async =>
    (await SafUtil().pickDirectory(writePermission: true, persistablePermission: true))?.uri;
