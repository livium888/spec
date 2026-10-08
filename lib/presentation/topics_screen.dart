import 'package:drift/drift.dart' show OrderingTerm, Variable, innerJoin;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart';
import '../domain/learn_planner.dart';
import 'prompt_result_screen.dart';

class _Row {
  const _Row(this.item, this.domain, this.cards, this.prereqs);
  final SyllabusItem item;
  final String domain;
  final int cards;
  final List<String> prereqs;
}

/// What is covered and what is not. With [pickMode], tapping a topic builds a prompt for it.
class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key, this.pickMode = false});
  final bool pickMode;
  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  Map<String, List<_Row>>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final learn = ref.read(learnServiceProvider);
      await learn.refreshStatuses();
      final db = ref.read(dbProvider);
      final titles = {for (final i in await db.select(db.syllabusItems).get()) i.id: i.title};
      final edges = <int, List<String>>{};
      for (final e in await db.select(db.syllabusPrereqs).get()) {
        edges.putIfAbsent(e.itemId, () => []).add(titles[e.prereqId] ?? '?');
      }
      final out = <String, List<_Row>>{};
      final q = db.select(db.syllabusItems).join([
        innerJoin(db.domains, db.domains.id.equalsExp(db.syllabusItems.domainId)),
      ])
        ..where(db.domains.active.equals(true))
        ..orderBy([OrderingTerm.asc(db.domains.name), OrderingTerm.asc(db.syllabusItems.position)]);
      for (final r in await q.get()) {
        final it = r.readTable(db.syllabusItems);
        final c = await db.customSelect(
            'SELECT COUNT(*) AS n FROM card c JOIN note n ON n.id = c.note_id WHERE n.syllabus_item_id = ?',
            variables: [Variable.withInt(it.id)]).getSingle();
        out.putIfAbsent(r.readTable(db.domains).name, () => []).add(
            _Row(it, r.readTable(db.domains).name, c.read<int>('n'), edges[it.id] ?? const []));
      }
      if (mounted) setState(() { _data = out; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _makePrompt(_Row r) async {
    final learn = ref.read(learnServiceProvider);
    final view = await learn.view();
    final remaining = (r.item.targetCards - r.cards).clamp(1, 10);
    final stats = ItemStats(
      id: r.item.id, domainId: r.item.domainId, domainName: r.domain, title: r.item.title,
      position: r.item.position, status: r.item.status, targetCards: r.item.targetCards,
      cardCount: r.cards,
    );
    final opt = LearnOption(
      action: r.cards == 0 ? LearnAction.newItem : LearnAction.deepen,
      item: stats,
      score: 0,
      reasons: const ['Chosen by you.'],
      count: r.cards == 0 ? r.item.targetCards.clamp(1, 10) : remaining,
    );
    final g = await learn.choose(opt, view, manual: true);
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => PromptResultScreen(prompt: g)));
  }

  Future<void> _menu(_Row r) async {
    if (widget.pickMode) return _makePrompt(r);
    final learn = ref.read(learnServiceProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(r.item.title), subtitle: Text(r.item.description)),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Make cards for this topic'),
            onTap: () { Navigator.pop(ctx); _makePrompt(r); },
          ),
          if (r.item.status != 'done')
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as done'),
              onTap: () async { Navigator.pop(ctx); await learn.setItemStatus(r.item.id, 'done'); _load(); },
            )
          else
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Reopen'),
              onTap: () async { Navigator.pop(ctx); await learn.setItemStatus(r.item.id, 'todo'); _load(); },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Choose a topic' : 'Topics')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load: $_error')))
            : _data == null
                ? const Center(child: CircularProgressIndicator())
                : _data!.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No topics yet. Use "Learn something new" to create an outline.'),
                        ),
                      )
                    : ListView(children: [
                        for (final e in _data!.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(e.key, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          for (final r in e.value)
                            ListTile(
                              minVerticalPadding: 12,
                              leading: Icon(switch (r.item.status) {
                                'done' => Icons.check_circle,
                                'active' => Icons.timelapse,
                                _ => Icons.radio_button_unchecked,
                              }),
                              title: Text(r.item.title),
                              subtitle: Text(
                                '${switch (r.item.status) { 'done' => 'Covered', 'active' => 'In progress', _ => 'Not started' }}'
                                ' · ${r.cards} of ${r.item.targetCards} cards'
                                '${r.prereqs.isEmpty ? '' : '\nAfter: ${r.prereqs.join(', ')}'}',
                              ),
                              isThreeLine: r.prereqs.isNotEmpty,
                              onTap: () => _menu(r),
                            ),
                        ],
                      ]),
      ),
    );
  }
}
