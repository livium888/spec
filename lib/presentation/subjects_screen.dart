import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart' show Domain;
import 'starter_library_screen.dart';
import 'topics_screen.dart';

class _Subject {
  const _Subject(this.domain, this.total, this.covered, this.skipped);
  final Domain domain;
  final int total, covered, skipped;
}

/// Controls what "Learn something new" may offer, and how often.
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});
  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  List<_Subject>? _subjects;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(dbProvider);
      await ref.read(learnServiceProvider).refreshStatuses();
      final out = <_Subject>[];
      for (final d in await (db.select(db.domains)..where((x) => x.active.equals(true))).get()) {
        final r = await db.customSelect('''
          SELECT COUNT(*) AS total,
                 SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS covered,
                 SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) AS skipped
          FROM syllabus_item WHERE domain_id = ?''',
            variables: [Variable.withInt(d.id)]).getSingle();
        out.add(_Subject(d, r.read<int>('total'), r.read<int?>('covered') ?? 0, r.read<int?>('skipped') ?? 0));
      }
      if (mounted) setState(() { _subjects = out; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) {
      ref.read(refreshProvider.notifier).bump();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Subjects and topics')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load: $_error')))
            : _subjects == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    const Text('Choose how often each subject comes up in "Learn something new". '
                        'Nothing is ever used up: finished topics return after a rest, with new cards that go deeper, '
                        'weeks, months or years later (the rest doubles each time). Cards you already have are never repeated. '
                        'And when a subject runs out of topics, the app asks your LLM for more, or starts a new subject, '
                        'so there is no ceiling.'),
                    const SizedBox(height: 12),
                    if (_subjects!.isEmpty)
                      const Card(child: ListTile(title: Text('No subjects yet. Add some from the starter library.'))),
                    for (final s in _subjects!) _card(context, s, t),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text('Add subjects from the starter library'),
                      onPressed: () => _open(const StarterLibraryScreen()),
                    ),
                  ]),
      ),
    );
  }

  Widget _card(BuildContext context, _Subject s, TextTheme t) {
    final d = s.domain;
    final learn = ref.read(learnServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: t.titleMedium),
          Text('${s.covered} of ${s.total - s.skipped} topics covered'
              '${s.skipped > 0 ? ' · ${s.skipped} skipped' : ''}'),
          const SizedBox(height: 8),
          Text('How often to offer', style: t.labelMedium),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Off')),
              ButtonSegment(value: 1, label: Text('Low')),
              ButtonSegment(value: 2, label: Text('Normal')),
              ButtonSegment(value: 3, label: Text('High')),
            ],
            selected: {d.learnWeight},
            onSelectionChanged: (v) async {
              await learn.setSubjectWeight(d.id, v.first);
              _load();
            },
          ),
          if (d.learnWeight == 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Paused: no new prompts. Your existing cards are still reviewed.'),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bring finished topics back later'),
            subtitle: const Text('For deeper cards after a rest'),
            value: d.revisit,
            onChanged: (v) async {
              await learn.setSubjectRevisit(d.id, v);
              _load();
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Topics'),
              onPressed: () => _open(TopicsScreen(domainId: d.id)),
            ),
          ),
        ]),
      ),
    );
  }
}
