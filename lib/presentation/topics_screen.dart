import 'package:drift/drift.dart' show BooleanExpressionOperators, Constant, OrderingTerm, Variable, innerJoin;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart';
import '../domain/learn_planner.dart';
import 'knowledge_map_screen.dart';
import 'prompt_result_screen.dart';

class _Row {
  const _Row(this.item, this.domain, this.cards, this.prereqs, this.returnsIn);
  final SyllabusItem item;

  /// Days until a finished topic comes back (<= 0: due now); null if it will not.
  final double? returnsIn;
  final String domain;
  final int cards;
  final List<String> prereqs;
}

/// What is covered and what is not. With [pickMode], tapping a topic builds a prompt for it.
class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key, this.pickMode = false, this.domainId});
  final bool pickMode;
  final int? domainId;
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
      final returns = await learn.returnsInDays();
      final out = <String, List<_Row>>{};
      final q = db.select(db.syllabusItems).join([
        innerJoin(db.domains, db.domains.id.equalsExp(db.syllabusItems.domainId)),
      ])
        ..where(db.domains.active.equals(true) &
            (widget.domainId == null ? const Constant(true) : db.domains.id.equals(widget.domainId!)))
        ..orderBy([OrderingTerm.asc(db.domains.name), OrderingTerm.asc(db.syllabusItems.position)]);
      for (final r in await q.get()) {
        final it = r.readTable(db.syllabusItems);
        final c = await db.customSelect(
            'SELECT COUNT(*) AS n FROM card c JOIN note n ON n.id = c.note_id WHERE n.syllabus_item_id = ?',
            variables: [Variable.withInt(it.id)]).getSingle();
        out.putIfAbsent(r.readTable(db.domains).name, () => []).add(
            _Row(it, r.readTable(db.domains).name, c.read<int>('n'), edges[it.id] ?? const [], returns[it.id]));
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
      rounds: r.item.rounds,
    );
    // A finished topic chosen by hand starts the next, deeper round right away.
    final deeper = r.item.status == 'done' && r.cards > 0;
    final opt = LearnOption(
      action: deeper ? LearnAction.revisit : (r.cards == 0 ? LearnAction.newItem : LearnAction.deepen),
      item: stats,
      score: 0,
      reasons: const ['Chosen by you.'],
      count: deeper
          ? const LearnPlanner().revisitStep(r.item.targetCards)
          : (r.cards == 0 ? r.item.targetCards.clamp(1, 10) : remaining),
    );
    final g = await learn.choose(opt, view, manual: true);
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => PromptResultScreen(prompt: g)));
  }

  static String _returns(double days) {
    if (days <= 0) return 'Due for a deeper pass now';
    if (days < 14) return 'Comes back in about ${days.ceil()} days';
    if (days < 60) return 'Comes back in about ${(days / 7).round()} weeks';
    if (days < 730) return 'Comes back in about ${(days / 30).round()} months';
    return 'Comes back in about ${(days / 365).round()} years';
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
            title: Text(r.item.status == 'done' && r.cards > 0 ? 'Go deeper now (new cards)' : 'Make cards for this topic'),
            onTap: () { Navigator.pop(ctx); _makePrompt(r); },
          ),
          if (r.item.status == 'skipped')
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Include this topic again'),
              onTap: () async { Navigator.pop(ctx); await learn.setTopicSkipped(r.item.id, false); _load(); },
            )
          else
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Skip this topic (never offer it)'),
              onTap: () async { Navigator.pop(ctx); await learn.setTopicSkipped(r.item.id, true); _load(); },
            ),
          if (r.item.status != 'done' && r.item.status != 'skipped')
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as done'),
              onTap: () async { Navigator.pop(ctx); await learn.setItemStatus(r.item.id, 'done'); _load(); },
            )
          else if (r.item.status == 'done')
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
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Choose a topic' : 'Topics'),
        actions: [
          if (!widget.pickMode && widget.domainId != null)
            IconButton(
              tooltip: 'Knowledge map',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => KnowledgeMapScreen(domainId: widget.domainId!)))
                  .then((_) => _load()),
            ),
        ],
      ),
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
                        if (!widget.pickMode)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text('Tap a topic to make cards for it, skip it so it is never offered, or mark it done.',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
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
                                'skipped' => Icons.block,
                                _ => Icons.radio_button_unchecked,
                              }),
                              title: Text(r.item.title),
                              subtitle: Text(
                                '${switch (r.item.status) { 'done' => 'Covered', 'active' => 'In progress', 'skipped' => 'Skipped by you', _ => 'Not started' }}'
                                ' · ${r.cards} card${r.cards == 1 ? '' : 's'} so far'
                                '${r.item.rounds > 1 ? ' · round ${r.item.rounds}' : ''}'
                                '${r.returnsIn == null ? '' : '\n${_returns(r.returnsIn!)}'}'
                                '${r.prereqs.isEmpty ? '' : '\nAfter: ${r.prereqs.join(', ')}'}',
                              ),
                              isThreeLine: r.prereqs.isNotEmpty || r.returnsIn != null,
                              onTap: () => _menu(r),
                            ),
                        ],
                      ]),
      ),
    );
  }
}
