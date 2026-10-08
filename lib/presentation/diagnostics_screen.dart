import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/build_info.dart';
import '../app/providers.dart';
import '../data/backup/backup_service.dart';
import '../domain/diagnostics.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

const _checksKey = 'phone_check';
const _notesKey = 'phone_check_notes';

/// Build number, recent errors, and a tick-list of things to try on the phone, with a
/// report to copy and send. Nothing leaves the phone unless the learner pastes it somewhere.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final _notes = TextEditingController();
  final _checks = <String, CheckState>{};
  Map<String, String> _facts = {};
  String _log = '';
  int _entries = 0;
  bool _loaded = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsRepoProvider);
    final db = ref.read(dbProvider);
    final raw = await settings.get(_checksKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in m.entries) {
          _checks[e.key] = CheckState.values.firstWhere((s) => s.name == e.value, orElse: () => CheckState.untested);
        }
      } catch (_) {}
    }
    _notes.text = await settings.get(_notesKey) ?? '';
    final f = await fingerprint(db);
    final dbFile = ref.read(bootstrapProvider).dbFile;
    final backups = await (db.select(db.backupLogs)
          ..orderBy([(b) => OrderingTerm.desc(b.ts)])
          ..limit(3))
        .get();
    final fit = await settings.getInt('optimizer_last_fit_ms', 0);
    final media = await ref.read(mediaServiceProvider).usage();
    _facts = {
      'Cards': '${f.cards}',
      'Reviews': '${f.reviews}',
      'Database size': dbFile.existsSync() ? '${(dbFile.lengthSync() / 1e6).toStringAsFixed(1)} MB' : 'unknown',
      'Recent backups': backups.isEmpty
          ? 'none'
          : backups
              .map((b) => '${DateTime.fromMillisecondsSinceEpoch(b.ts, isUtc: true).toIso8601String().substring(0, 16)} ${b.ok ? 'ok' : 'FAILED: ${b.error}'}')
              .join('; '),
      if (media.count > 0) 'Pictures': '${media.count} (${(media.bytes / 1e6).toStringAsFixed(1)} MB, inside every backup)',
      if (fit > 0) 'Last memory fit took': '${(fit / 1000).toStringAsFixed(1)} s',
    };
    final log = ref.read(errorLogProvider);
    _log = log.read();
    _entries = log.entryCount;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveChecks() => ref.read(settingsRepoProvider).set(
      _checksKey, jsonEncode({for (final e in _checks.entries) e.key: e.value.name}));

  String _report() => renderReport(
        build: BuildInfo.label + (BuildInfo.builtAt.isEmpty ? '' : ', built ${BuildInfo.builtAt}'),
        os: 'Android/OS: ${Platform.operatingSystemVersion}',
        facts: _facts,
        checks: _checks,
        notes: _notes.text,
        errorLogTail: _log,
      );

  Future<void> _copy() async {
    await ref.read(settingsRepoProvider).set(_notesKey, _notes.text);
    await Clipboard.setData(ClipboardData(text: _report()));
    if (mounted) setState(() => _msg = 'Report copied. Paste it into your message.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics and phone check')),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(BuildInfo.label, style: t.titleMedium),
                    if (BuildInfo.builtAt.isNotEmpty) Text('Built ${BuildInfo.builtAt}', style: t.bodySmall),
                    Text('Android/OS: ${Platform.operatingSystemVersion}', style: t.bodySmall),
                    const SizedBox(height: 6),
                    for (final e in _facts.entries) Text('${e.key}: ${e.value}', style: t.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                        'Matches the title of the release you downloaded it from. If it is older than the newest build, download again.',
                        style: t.bodySmall),
                  ]),
                ),
                const SizedBox(height: Sp.l),
                Text('Phone check', style: t.titleLarge),
                const SizedBox(height: 4),
                Text('Try each thing once and mark what happened. Then copy the report and send it to me.', style: t.bodyMedium),
                const SizedBox(height: Sp.s),
                for (final item in kPhoneCheck) _row(context, item, c),
                const SizedBox(height: Sp.s),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Notes (what broke, which AI, anything odd)'),
                ),
                const SizedBox(height: Sp.m),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy report'),
                  onPressed: _copy,
                ),
                if (_msg != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(liveRegion: true, child: Text(_msg!))),
                const SizedBox(height: Sp.l),
                Text('Errors ($_entries)', style: t.titleLarge),
                const SizedBox(height: 4),
                Text(
                    'Crashes and unexpected errors are written to a file on this phone only. It can contain text from your cards, so it only leaves the phone when you copy the report.',
                    style: t.bodySmall),
                const SizedBox(height: 8),
                SoftCard(
                  child: SelectableText(_log.isEmpty ? 'No errors recorded.' : _log,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                ),
                if (_entries > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        ref.read(errorLogProvider).clear();
                        setState(() { _log = ''; _entries = 0; });
                      },
                      child: const Text('Clear the error log'),
                    ),
                  ),
              ]),
      ),
    );
  }

  Widget _row(BuildContext context, PhoneCheckItem item, AppColors c) {
    final t = Theme.of(context).textTheme;
    final s = _checks[item.id] ?? CheckState.untested;
    Widget choice(CheckState v, IconData icon, String label) => Semantics(
          button: true,
          selected: s == v,
          label: '$label: ${item.title}',
          child: IconButton(
            tooltip: label,
            isSelected: s == v,
            icon: Icon(icon),
            selectedIcon: Icon(icon, color: v == CheckState.works ? c.good : c.danger),
            onPressed: () {
              setState(() => _checks[item.id] = s == v ? CheckState.untested : v);
              _saveChecks();
            },
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: t.titleSmall),
              Text(item.how, style: t.bodySmall),
            ]),
          ),
          choice(CheckState.works, Icons.check_circle_outline, 'Works'),
          choice(CheckState.broken, Icons.error_outline, 'Broken'),
        ]),
      ),
    );
  }
}
