import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../app/bootstrap.dart';
import '../app/providers.dart';
import '../data/backup/backup_service.dart';
import '../data/backup/backup_storage.dart';
import '../data/settings_repo.dart';
import '../domain/prompt_template.dart' show kMaxProfileChars;
import 'guide_screen.dart';
import 'memory_model_screen.dart';
import 'home_screen.dart' show pickBackupFolder;
import 'subjects_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _newPerDay = TextEditingController();
  final _divisor = TextEditingController();
  final _retention = TextEditingController();
  final _steps = TextEditingController();
  final _relearn = TextEditingController();
  final _rollover = TextEditingController();
  final _minutes = TextEditingController();
  final _revisit = TextEditingController();
  final _profile = TextEditingController();
  String? _folder;
  int _lastBackup = 0;
  String? _msg;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_newPerDay, _divisor, _retention, _steps, _relearn, _rollover, _minutes, _revisit, _profile]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = ref.read(settingsRepoProvider);
    _newPerDay.text = '${await s.getInt(SettingsRepo.newPerDay, 10)}';
    _divisor.text = '${await s.getInt(SettingsRepo.backlogDivisor, 25)}';
    _retention.text = '${await s.getDouble(SettingsRepo.desiredRetention, 0.90)}';
    _steps.text = (await s.getIntList(SettingsRepo.learningSteps, [1, 10])).join(',');
    _relearn.text = (await s.getIntList(SettingsRepo.relearningSteps, [10])).join(',');
    _rollover.text = '${await s.getInt(SettingsRepo.rolloverHour, 4)}';
    _minutes.text = '${await s.getInt(SettingsRepo.dailyMinutes, 20)}';
    _revisit.text = '${await s.getInt(SettingsRepo.revisitMonths, 3)}';
    _profile.text = await s.get(SettingsRepo.learnerProfile) ?? '';
    _folder = await s.get(SettingsRepo.backupTreeUri);
    _lastBackup = await s.getInt(BackupService.lastSuccessKey, 0);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveSettings() async {
    final s = ref.read(settingsRepoProvider);
    String? err;
    final n = int.tryParse(_newPerDay.text.trim());
    final d = int.tryParse(_divisor.text.trim());
    final r = double.tryParse(_retention.text.trim());
    final h = int.tryParse(_rollover.text.trim());
    final mins = int.tryParse(_minutes.text.trim());
    final rev = int.tryParse(_revisit.text.trim());
    List<int>? parse(String t) {
      final parts = t.split(',').map((e) => int.tryParse(e.trim())).toList();
      return parts.isEmpty || parts.contains(null) || parts.any((e) => e! < 1 || e > 1440)
          ? null
          : parts.cast<int>();
    }

    final ls = parse(_steps.text);
    final rs = parse(_relearn.text);
    if (n == null || n < 0 || n > 500) err = 'New cards per day must be 0-500.';
    if (d == null || d < 1) err = 'Backlog divisor must be 1 or more.';
    if (r == null || r < 0.7 || r > 0.99) err = 'Desired retention must be between 0.70 and 0.99.';
    if (h == null || h < 0 || h > 23) err = 'Day rollover hour must be 0-23.';
    if (mins == null || mins < 5 || mins > 240) err = 'Daily study time must be 5-240 minutes.';
    if (rev == null || rev < 1 || rev > 24) err = 'First revisit delay must be 1-24 months.';
    if (_profile.text.length > kMaxProfileChars) err = 'Keep "About you" under $kMaxProfileChars characters.';
    if (ls == null) err = 'Learning steps: minutes separated by commas, e.g. 1,10.';
    if (rs == null) err = 'Relearning steps: minutes separated by commas, e.g. 10.';
    if (err != null) {
      setState(() => _msg = err);
      return;
    }
    await s.set(SettingsRepo.newPerDay, '$n');
    await s.set(SettingsRepo.backlogDivisor, '$d');
    await s.set(SettingsRepo.desiredRetention, '$r');
    await s.set(SettingsRepo.learningSteps, ls!.join(','));
    await s.set(SettingsRepo.relearningSteps, rs!.join(','));
    await s.set(SettingsRepo.rolloverHour, '$h');
    await s.set(SettingsRepo.dailyMinutes, '$mins');
    await s.set(SettingsRepo.revisitMonths, '$rev');
    await s.set(SettingsRepo.learnerProfile, _profile.text.trim());
    // New params row (old log rows keep theirs, so replay stays exact).
    await ref.read(paramsRepoProvider).syncFromSettings();
    ref.read(refreshProvider.notifier).bump();
    setState(() => _msg = 'Settings saved.');
  }

  Future<void> _pickFolder() async {
    final uri = await pickBackupFolder();
    if (uri == null) return;
    await ref.read(settingsRepoProvider).set(SettingsRepo.backupTreeUri, uri);
    setState(() { _folder = uri; _msg = 'Backup folder set.'; });
  }

  Future<void> _backupNow() async {
    if (_folder == null) return;
    setState(() { _busy = true; _msg = null; });
    final err = await ref
        .read(backupServiceProvider)
        .export(SafBackupStorage(_folder!), ref.read(bootstrapProvider).tmpDir);
    _lastBackup = await ref.read(settingsRepoProvider).getInt(BackupService.lastSuccessKey, 0);
    ref.read(refreshProvider.notifier).bump();
    if (mounted) setState(() { _busy = false; _msg = err == null ? 'Backup complete.' : 'Backup failed: $err'; });
  }

  Future<void> _restore({required bool latest}) async {
    final storage = _folder == null ? null : SafBackupStorage(_folder!);
    final bs = ref.read(bootstrapProvider);
    final fetched = File('${bs.tmpDir.path}/restore-download-${DateTime.now().microsecondsSinceEpoch}');
    String name;
    try {
      if (latest) {
        if (storage == null) return;
        final files = (await storage.list()).where((f) => f.name.startsWith('learning-backup-')).toList()
          ..sort((a, b) => b.name.compareTo(a.name));
        if (files.isEmpty) {
          setState(() => _msg = 'No backups found in the chosen folder.');
          return;
        }
        name = files.first.name;
        await storage.readToFile(files.first, fetched);
      } else {
        final f = await SafUtil().pickFile();
        if (f == null) return;
        name = f.name;
        await SafStream().copyToLocalFile(f.uri, fetched.path);
      }
    } catch (e) {
      if (fetched.existsSync()) fetched.deleteSync();
      setState(() => _msg = 'Could not read the backup file: $e');
      return;
    }
    if (!mounted) {
      if (fetched.existsSync()) fetched.deleteSync();
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text('This replaces everything in the app with "$name". '
            'Your current data is kept as a safety copy until the restore checks out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (go != true || !mounted) {
      if (fetched.existsSync()) fetched.deleteSync();
      return;
    }

    setState(() { _busy = true; _msg = null; });
    try {
      final report = await BackupService.restore(
        source: fetched,
        dbFile: bs.dbFile,
        tmpDir: bs.tmpDir,
        closeDb: () => ref.read(dbProvider).close(),
        reopen: () async {
          final fresh = Bootstrap.openDb(bs.dbFile);
          ref.read(dbProvider.notifier).replace(fresh);
          return fresh;
        },
      );
      if (!mounted) return;
      await _load();
      setState(() {
        _msg = 'Restored: ${report.fingerprint.cards} cards, ${report.fingerprint.reviews} reviews. '
            '${report.clean ? 'Replay check passed: card states match the review log.' : '${report.mismatches.length} card(s) differ from a replay of the log (listed ids: ${report.mismatches.take(10).map((m) => m.cardId).join(', ')}). Nothing was changed.'}';
      });
    } on BackupException catch (e) {
      if (mounted) setState(() => _msg = 'Restore refused: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _msg = 'Restore failed: $e');
    } finally {
      if (fetched.existsSync()) fetched.deleteSync();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget field(TextEditingController c, String label, {String? help, bool number = true}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 3),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings and backup')),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline),
                  label: const Text('How the app works'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const GuideScreen())),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.psychology_outlined),
                  label: const Text('Memory model: fit to my reviews'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const MemoryModelScreen())),
                ),
                const SizedBox(height: 16),
                Text('Backup', style: t.titleLarge),
                const SizedBox(height: 8),
                Text(_folder == null ? 'No folder chosen.' : 'Folder chosen. Weekly in the background, and on open if older than 7 days.'),
                Text(_lastBackup == 0
                    ? 'No successful backup yet.'
                    : 'Last successful backup: ${DateTime.fromMillisecondsSinceEpoch(_lastBackup)}'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: Text(_folder == null ? 'Choose folder' : 'Change folder'),
                      onPressed: _busy ? null : _pickFolder),
                  FilledButton.icon(
                      icon: const Icon(Icons.backup),
                      label: const Text('Back up now'),
                      onPressed: _busy || _folder == null ? null : _backupNow),
                  OutlinedButton(
                      onPressed: _busy || _folder == null ? null : () => _restore(latest: true),
                      child: const Text('Restore latest')),
                  OutlinedButton(
                      onPressed: _busy ? null : () => _restore(latest: false),
                      child: const Text('Restore from file...')),
                ]),
                if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (_msg != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: SelectableText(_msg!, style: t.bodyLarge)),
                const Divider(height: 40),
                Text('Study', style: t.titleLarge),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.tune),
                  label: const Text('Subjects and topics'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const SubjectsScreen())),
                ),
                const SizedBox(height: 16),
                field(_newPerDay, 'New cards per day'),
                field(_divisor, 'Backlog divisor', help: 'Daily new limit shrinks by 1 for every this-many due reviews.'),
                field(_retention, 'Desired retention', help: '0.90 = aim to remember 90% at review time.'),
                field(_steps, 'Learning steps (minutes)', number: false, help: 'e.g. 1,10'),
                field(_relearn, 'Relearning steps (minutes)', number: false, help: 'e.g. 10'),
                field(_rollover, 'Day rolls over at (hour, local)', help: '4 = 04:00'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _profile,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: kMaxProfileChars,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'About you (optional)',
                      hintText: 'e.g. Nurse, cycles to work, loves football and cooking, learning for fun',
                      helperText: 'Makes examples and analogies fit your life. It is added to the prompts you '
                          'copy, so it goes to whichever LLM you paste them into.',
                      helperMaxLines: 3,
                    ),
                  ),
                ),
                field(_revisit, 'Bring finished topics back after (months)', help: 'First delay; each later round waits twice as long (3, 6, 12, 24 ... up to 12 years).'),
                field(_minutes, 'Daily study time (minutes)', help: 'Used by "Learn something new" to decide how many new cards fit.'),
                FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: _saveSettings,
                    child: const Text('Save settings')),
              ]),
      ),
    );
  }
}
