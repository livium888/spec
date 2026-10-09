import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/device_services.dart' show kSpeechLanguages;
import '../data/db/database.dart' show Domain;
import 'starter_library_screen.dart';
import 'topics_screen.dart';

class _Topic {
  const _Topic(this.id, this.title, this.status, this.cards);
  final int id, cards;
  final String title, status; // todo | active | done | skipped
}

class _Subject {
  const _Subject(this.domain, this.total, this.covered, this.skipped, this.topics);
  final Domain domain;
  final int total, covered, skipped;
  final List<_Topic> topics;
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

  double _globalRetention = 0.90;
  bool _speakAuto = false;

  /// The menu offers four values; show the closest one for anything stored in between.
  static double? _nearest(double? v) {
    if (v == null) return null;
    const options = [0.80, 0.85, 0.90, 0.95];
    return options.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
  }

  Future<void> _load() async {
    try {
      final db = ref.read(dbProvider);
      _globalRetention = await ref.read(settingsRepoProvider).getDouble('desired_retention', 0.90);
      _speakAuto = await ref.read(settingsRepoProvider).get('speak_auto') == '1';
      await ref.read(learnServiceProvider).refreshStatuses();
      final out = <_Subject>[];
      for (final d in await (db.select(db.domains)..where((x) => x.active.equals(true))).get()) {
        final r = await db.customSelect('''
          SELECT COUNT(*) AS total,
                 SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS covered,
                 SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) AS skipped
          FROM syllabus_item WHERE domain_id = ?''',
            variables: [Variable.withInt(d.id)]).getSingle();
        final ts = await db.customSelect('''
          SELECT s.id AS id, s.title AS title, s.status AS status, COUNT(c.id) AS cards
          FROM syllabus_item s
          LEFT JOIN note n ON n.syllabus_item_id = s.id
          LEFT JOIN card c ON c.note_id = n.id
          WHERE s.domain_id = ? GROUP BY s.id ORDER BY s.position, s.id''', variables: [Variable.withInt(d.id)]).get();
        out.add(_Subject(d, r.read<int>('total'), r.read<int?>('covered') ?? 0, r.read<int?>('skipped') ?? 0, [
          for (final x in ts) _Topic(x.read<int>('id'), x.read<String>('title'), x.read<String>('status'), x.read<int>('cards')),
        ]));
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Read aloud automatically'),
                      subtitle: const Text('For subjects with a language set below: speaks the language side when it appears.'),
                      value: _speakAuto,
                      onChanged: (v) async {
                        await ref.read(settingsRepoProvider).set('speak_auto', v ? '1' : '0');
                        _load();
                      },
                    ),
                    const SizedBox(height: 4),
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

  static String _status(_Topic x) =>
      '${switch (x.status) { 'done' => 'Covered', 'active' => 'In progress', 'skipped' => 'Not offered', _ => 'Not started' }}'
      ' · ${x.cards} card${x.cards == 1 ? '' : 's'}';

  /// Every topic of the subject with a tick-box: ticked topics are offered by "Learn something new",
  /// unticked ones are skipped. Open for a subject that has no cards yet (a new one) or few topics.
  Widget _topics(BuildContext context, _Subject s, TextTheme t) {
    if (s.topics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('No topics yet. "Learn something new" will ask your AI for an outline.', style: t.bodySmall),
      );
    }
    final learn = ref.read(learnServiceProvider);
    final offered = s.topics.where((x) => x.status != 'skipped').length;
    final startOpen = s.topics.every((x) => x.cards == 0) || s.topics.length <= 10;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('topics-${s.domain.id}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: startOpen,
        title: Text('Topics: $offered of ${s.topics.length} offered', style: t.titleSmall),
        subtitle: const Text('Tick the topics you want offered for new cards.'),
        children: [
          Row(children: [
            TextButton(
              onPressed: () async {
                for (final x in s.topics.where((x) => x.status == 'skipped')) {
                  await learn.setTopicSkipped(x.id, false);
                }
                _load();
              },
              child: const Text('Offer all'),
            ),
            TextButton(
              onPressed: () async {
                for (final x in s.topics.where((x) => x.status != 'skipped' && x.status != 'done')) {
                  await learn.setTopicSkipped(x.id, true);
                }
                _load();
              },
              child: const Text('Offer none'),
            ),
          ]),
          for (final x in s.topics)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: x.status != 'skipped',
              onChanged: (v) async {
                await learn.setTopicSkipped(x.id, v != true);
                _load();
              },
              title: Text(x.title),
              subtitle: Text(_status(x)),
            ),
        ],
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
          _topics(context, s, t),
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
          const SizedBox(height: 4),
          Text('Target recall', style: t.labelMedium),
          const SizedBox(height: 4),
          DropdownButtonFormField<double?>(
            initialValue: _nearest(d.retention),
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, helperText: 'Lower means fewer reviews, but you forget a little more.', helperMaxLines: 2),
            items: [
              DropdownMenuItem(value: null, child: Text('Same as everything else (${(_globalRetention * 100).round()}%)')),
              for (final v in const [0.80, 0.85, 0.90, 0.95]) DropdownMenuItem(value: v, child: Text('${(v * 100).round()}%')),
            ],
            onChanged: (v) async {
              await learn.setSubjectRetention(d.id, v);
              _load();
            },
          ),
          const SizedBox(height: 8),
          Text('Read cards aloud', style: t.labelMedium),
          const SizedBox(height: 4),
          DropdownButtonFormField<String?>(
            initialValue: kSpeechLanguages.any((l) => l.$2 == d.speechLang) ? d.speechLang : null,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, helperText: 'Uses your phone\'s own voice. Good for languages.', helperMaxLines: 2),
            items: [
              const DropdownMenuItem(value: null, child: Text('Off')),
              for (final l in kSpeechLanguages) DropdownMenuItem(value: l.$2, child: Text(l.$1)),
            ],
            onChanged: (v) async {
              await learn.setSubjectSpeech(d.id, v, side: d.speechSide);
              _load();
            },
          ),
          if (d.speechLang != null) ...[
            const SizedBox(height: 8),
            Text('Which side is written in that language?', style: t.bodySmall),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'front', label: Text('Question')), ButtonSegment(value: 'back', label: Text('Answer'))],
              selected: {d.speechSide},
              onSelectionChanged: (v) async {
                await learn.setSubjectSpeech(d.id, d.speechLang, side: v.first);
                _load();
              },
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('More about each topic'),
              onPressed: () => _open(TopicsScreen(domainId: d.id)),
            ),
          ),
        ]),
      ),
    );
  }
}
