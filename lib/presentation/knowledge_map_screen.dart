import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/knowledge_map.dart';
import 'prompt_result_screen.dart';
import 'theme/tokens.dart';

const _nodeW = 176.0, _nodeH = 84.0, _gapX = 16.0, _gapY = 54.0, _pad = 18.0;

IconData _stateIcon(TopicState s) => switch (s) {
      TopicState.notStarted => Icons.radio_button_unchecked,
      TopicState.learning => Icons.timelapse,
      TopicState.solid => Icons.check_circle_outline,
      TopicState.fading => Icons.hourglass_bottom,
      TopicState.attention => Icons.warning_amber_rounded,
      TopicState.skipped => Icons.block,
    };

/// (fill, line) colours of a state. Colour is never the only signal: the icon and the words say it too.
(Color, Color) _stateColors(AppColors c, TopicState s) => switch (s) {
      TopicState.notStarted => (c.surface, c.line),
      TopicState.learning => (c.infoTint, c.info),
      TopicState.solid => (c.goodTint, c.good),
      TopicState.fading => (c.warnTint, c.warn),
      TopicState.attention => (c.dangerTint, c.danger),
      TopicState.skipped => (c.surfaceDim, c.line),
    };

/// One subject's topics as a map (prerequisites flow downwards) or the same information as a list (D44).
class KnowledgeMapScreen extends ConsumerStatefulWidget {
  const KnowledgeMapScreen({super.key, required this.domainId});
  final int domainId;
  @override
  ConsumerState<KnowledgeMapScreen> createState() => _KnowledgeMapScreenState();
}

class _KnowledgeMapScreenState extends ConsumerState<KnowledgeMapScreen> {
  KnowledgeMap? _map;
  String _name = '';
  String? _error;
  bool? _list; // null until the first build decides (a screen reader starts on the list)
  final _tc = TransformationController();
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(dbProvider);
      final dom = await (db.select(db.domains)..where((d) => d.id.equals(widget.domainId))).getSingleOrNull();
      final m = await ref.read(knowledgeServiceProvider).forDomain(widget.domainId);
      if (mounted) setState(() { _map = m; _name = dom?.name ?? ''; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  // ---- layout ----------------------------------------------------------------------------------

  ({Map<int, Offset> at, Size size}) _layout(KnowledgeMap m) {
    final widest = m.layers.fold<int>(1, (a, l) => math.max(a, l.length));
    final width = widest * _nodeW + (widest - 1) * _gapX + 2 * _pad;
    final height = m.layers.length * _nodeH + (m.layers.length - 1) * _gapY + 2 * _pad;
    final at = <int, Offset>{};
    for (final (row, ids) in m.layers.indexed) {
      final rowW = ids.length * _nodeW + (ids.length - 1) * _gapX;
      final left = (width - rowW) / 2;
      for (final (i, id) in ids.indexed) {
        at[id] = Offset(left + i * (_nodeW + _gapX), _pad + row * (_nodeH + _gapY));
      }
    }
    return (at: at, size: Size(width, height));
  }

  void _fit(Size canvas, Size view) {
    if (_fitted || view.width <= 0) return;
    _fitted = true;
    final scale = math.min(1.0, view.width / canvas.width).clamp(0.55, 1.0);
    final dx = math.max(0.0, (view.width - canvas.width * scale) / 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tc.value = Matrix4.identity()..translateByDouble(dx, 0, 0, 1)..scaleByDouble(scale, scale, 1, 1);
    });
  }

  // ---- screen ----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _list ??= MediaQuery.accessibleNavigationOf(context);
    final t = Theme.of(context).textTheme;
    final m = _map;
    return Scaffold(
      appBar: AppBar(title: Text(_name.isEmpty ? 'Knowledge map' : '$_name: map')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load the map: $_error')))
            : m == null
                ? const Center(child: CircularProgressIndicator())
                : m.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No topics yet. Add this subject\'s topics from the Library, and the map appears.', style: t.bodyLarge, textAlign: TextAlign.center),
                        ),
                      )
                    : Column(children: [
                        _header(context, m),
                        Expanded(child: _list! ? _listView(context, m) : _mapView(context, m)),
                      ]),
      ),
    );
  }

  Widget _header(BuildContext context, KnowledgeMap m) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final next = [for (final id in m.nextUp) m.nodes[id]!];
    final allSolid = m.nodes.values.every((n) => n.state == TopicState.solid || n.state == TopicState.skipped);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Map'), icon: Icon(Icons.account_tree_outlined)),
                ButtonSegment(value: true, label: Text('List'), icon: Icon(Icons.list_alt_outlined)),
              ],
              selected: {_list!},
              onSelectionChanged: (s) => setState(() => _list = s.first),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(next.isNotEmpty ? 'Next up' : (allSolid ? 'Everything here is solid' : 'Nothing is ready yet'), style: t.titleSmall),
        ),
        const SizedBox(height: 4),
        if (next.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final n in next)
              ActionChip(
                avatar: Icon(_stateIcon(n.state), size: 18, color: c.accent),
                label: Text(n.title, overflow: TextOverflow.ellipsis),
                onPressed: () => _sheet(context, m, n),
              ),
          ])
        else if (!allSolid)
          Text('Strengthen the topics marked Fading or Needs attention first.', style: t.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 2, children: [
          for (final s in const [TopicState.notStarted, TopicState.learning, TopicState.solid, TopicState.fading, TopicState.attention])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_stateIcon(s), size: 15, color: _stateColors(c, s).$2 == c.line ? c.inkSoft : _stateColors(c, s).$2),
              const SizedBox(width: 3),
              Text(stateLabel(s), style: t.labelSmall),
            ]),
        ]),
      ]),
    );
  }

  // ---- map -------------------------------------------------------------------------------------

  Widget _mapView(BuildContext context, KnowledgeMap m) {
    final lay = _layout(m);
    final c = AppColors.of(context);
    return LayoutBuilder(builder: (context, box) {
      _fit(lay.size, Size(box.maxWidth, box.maxHeight));
      return InteractiveViewer(
        transformationController: _tc,
        constrained: false,
        minScale: 0.4,
        maxScale: 2.2,
        boundaryMargin: const EdgeInsets.all(60),
        child: SizedBox(
          width: lay.size.width,
          height: lay.size.height,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgePainter(
                  edges: m.edges,
                  at: lay.at,
                  blockers: {for (final e in m.blockers.entries) (e.value, e.key)},
                  line: c.line,
                  warn: c.warn,
                ),
              ),
            ),
            for (final n in m.nodes.values)
              Positioned(
                left: lay.at[n.id]!.dx,
                top: lay.at[n.id]!.dy,
                width: _nodeW,
                height: _nodeH,
                child: _NodeTile(node: n, blocked: m.blockers.containsKey(n.id), onTap: () => _sheet(context, m, n)),
              ),
          ]),
        ),
      );
    });
  }

  // ---- list ------------------------------------------------------------------------------------

  Widget _listView(BuildContext context, KnowledgeMap m) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      for (final (row, ids) in m.layers.indexed) ...[
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Semantics(header: true, child: Text(row == 0 ? 'Start here' : 'Builds on the topics above', style: t.labelLarge?.copyWith(color: c.inkSoft))),
        ),
        for (final id in ids) _listTile(context, m, m.nodes[id]!),
      ],
    ]);
  }

  Widget _listTile(BuildContext context, KnowledgeMap m, TopicNode n) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final colors = _stateColors(c, n.state);
    final needs = [for (final p in n.prereqs) if (m.nodes[p] != null) m.nodes[p]!.title];
    return Card(
      child: ListTile(
        leading: Icon(_stateIcon(n.state), color: colors.$2 == c.line ? c.inkSoft : colors.$2),
        title: Text(n.title),
        subtitle: Text([
          stateLabel(n.state),
          n.cards == 0 ? 'no cards' : '${(n.knowledge * 100).round()}% known',
          if (needs.isNotEmpty) 'needs ${needs.join(', ')}',
          if (m.blockers.containsKey(n.id)) 'held back by ${m.nodes[m.blockers[n.id]]!.title}',
        ].join(' · ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (n.problems) Icon(Icons.calculate_outlined, size: 18, color: c.inkSoft, semanticLabel: 'has problems'),
          const Icon(Icons.chevron_right),
        ]),
        onTap: () => _sheet(context, m, n),
        titleTextStyle: t.titleSmall,
      ),
    );
  }

  // ---- one topic -------------------------------------------------------------------------------

  Future<void> _sheet(BuildContext context, KnowledgeMap m, TopicNode n) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _TopicSheet(
        map: m,
        node: n,
        onMakeCards: () async {
          final nav = Navigator.of(ctx);
          final messenger = ScaffoldMessenger.of(ctx);
          try {
            final g = await ref.read(learnServiceProvider).promptForTopic(n.id);
            nav.pop();
            if (!context.mounted) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PromptResultScreen(prompt: g)));
            _load();
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Could not build the prompt: $e')));
          }
        },
        onPractice: (v) async {
          await ref.read(learnServiceProvider).setTopicPractice(n.id, v);
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        },
        onSkip: (skip) async {
          await ref.read(learnServiceProvider).setTopicSkipped(n.id, skip);
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node, required this.blocked, required this.onTap});
  final TopicNode node;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final (fill, line) = _stateColors(c, node.state);
    final accent = line == c.line ? c.inkSoft : line;
    final pct = node.cards == 0 ? null : (node.knowledge * 100).round();
    final label = '${node.title}. ${stateLabel(node.state)}.'
        '${pct == null ? ' No cards yet.' : ' $pct percent known, ${node.cards} cards.'}'
        '${node.problems ? ' Has problems.' : ''}${blocked ? ' Held back by an earlier topic.' : ''}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: line, width: node.state == TopicState.attention ? 2 : 1.2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(value: node.cards == 0 ? 0 : node.knowledge.clamp(0.02, 1.0), strokeWidth: 4, color: accent, backgroundColor: c.line.withValues(alpha: 0.5)),
                  Icon(_stateIcon(node.state), size: 18, color: accent),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(node.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15, fontSize: node.title.split(' ').any((w) => w.length > 11) ? 11.5 : 13)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Flexible(
                      child: Text(
                        // The long label leaves no room for a number; the sheet and the list have it.
                        pct == null || node.state == TopicState.attention ? stateLabel(node.state) : '${stateLabel(node.state)} · $pct%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(color: c.inkSoft),
                      ),
                    ),
                    if (node.problems) ...[const SizedBox(width: 4), Icon(Icons.calculate_outlined, size: 14, color: c.inkSoft)],
                    if (node.foundations > 0) ...[const SizedBox(width: 3), Icon(Icons.layers_outlined, size: 14, color: c.inkSoft)],
                    if (blocked) ...[const SizedBox(width: 3), Icon(Icons.lock_clock, size: 14, color: c.warn)],
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.edges, required this.at, required this.blockers, required this.line, required this.warn});
  final List<(int, int)> edges;
  final Map<int, Offset> at;
  final Set<(int, int)> blockers; // (prerequisite, topic) pairs to highlight
  final Color line, warn;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to) in edges) {
      final a = at[from], b = at[to];
      if (a == null || b == null) continue;
      final hot = blockers.contains((from, to));
      final start = Offset(a.dx + _nodeW / 2, a.dy + _nodeH);
      final end = Offset(b.dx + _nodeW / 2, b.dy);
      final mid = (end.dy - start.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, start.dy + mid, end.dx, end.dy - mid, end.dx, end.dy);
      final color = hot ? warn : line;
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = hot ? 2.6 : 1.6);
      final arrow = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 5, end.dy - 9)
        ..lineTo(end.dx + 5, end.dy - 9)
        ..close();
      canvas.drawPath(arrow, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter o) => o.edges != edges || o.at != at || o.line != line || o.warn != warn;
}

class _TopicSheet extends StatelessWidget {
  const _TopicSheet({required this.map, required this.node, required this.onMakeCards, required this.onPractice, required this.onSkip});
  final KnowledgeMap map;
  final TopicNode node;
  final VoidCallback onMakeCards;
  final void Function(String) onPractice;
  final void Function(bool) onSkip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final n = node;
    final blocker = map.blockers[n.id];
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(a, style: t.bodyMedium)), Text(b, style: t.titleSmall)]),
        );
    final prereqs = [for (final p in n.prereqs) if (map.nodes[p] != null) map.nodes[p]!];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(n.title, style: t.headlineSmall)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(_stateIcon(n.state), color: _stateColors(c, n.state).$2 == c.line ? c.inkSoft : _stateColors(c, n.state).$2),
            const SizedBox(width: 8),
            Expanded(child: Text('${stateLabel(n.state)}. ${stateMeaning(n.state)}', style: t.bodyLarge)),
          ]),
          const SizedBox(height: 12),
          row('Known now', n.cards == 0 ? 'no cards' : '${(n.knowledge * 100).round()}%'),
          row('Cards', '${n.cards} of about ${n.targetCards > n.cards ? n.targetCards : n.cards}'),
          if (n.recall != null) row('Recall of what you have learned', '${(n.recall! * 100).round()}%'),
          if (n.leeches > 0) row('Stuck cards', '${n.leeches}'),
          if (n.foundations > 0) row('Foundation cards', '${n.foundations}'),
          if (n.problems) row('Practised with', 'problems'),
          if (blocker != null) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_clock, color: c.warn),
              const SizedBox(width: 8),
              Expanded(child: Text('Held back by "${map.nodes[blocker]!.title}" (${stateLabel(map.nodes[blocker]!.state).toLowerCase()}). Strengthen it first.', style: t.bodyMedium)),
            ]),
          ],
          if (prereqs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(header: true, child: Text('Builds on', style: t.titleSmall)),
            for (final p in prereqs)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(_stateIcon(p.state), size: 18, color: c.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${p.title} · ${stateLabel(p.state)}', style: t.bodyMedium)),
                ]),
              ),
          ],
          const SizedBox(height: 16),
          if (n.state != TopicState.skipped)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.auto_awesome),
              label: Text(n.cards == 0 ? 'Make cards for this topic' : 'Add more cards'),
              onPressed: onMakeCards,
            ),
          const SizedBox(height: 14),
          Text('Practise with', style: t.labelMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final (v, label) in const [('', 'AI decides'), ('concepts', 'Concepts'), ('problems', 'Problems'), ('both', 'Both')])
              ChoiceChip(label: Text(label), selected: n.practice == v, onSelected: (_) => onPractice(v)),
          ]),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: Icon(n.state == TopicState.skipped ? Icons.undo : Icons.block),
            label: Text(n.state == TopicState.skipped ? 'Offer this topic again' : 'Skip this topic (never offer it)'),
            onPressed: () => onSkip(n.state != TopicState.skipped),
          ),
        ]),
      ),
    );
  }
}
