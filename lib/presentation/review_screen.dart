import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import '../domain/study_card.dart';
import 'format.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  DailyQueue? _queue;
  StudyCard? _current;
  Map<int, Duration> _preview = {};
  bool _revealed = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _stopwatch = Stopwatch();
  final _touched = <int>{};
  int _answered = 0;
  int _totalMs = 0;
  Timer? _poll;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({StudyCard? force}) async {
    try {
      final q = await ref.read(queueServiceProvider).build();
      final next = force ?? q.next;
      Map<int, Duration> pv = {};
      if (next != null) {
        final params = ref.read(paramsRepoProvider);
        final sched = await params.schedulerFor(await params.activeId());
        pv = sched.preview(next.snapshot, DateTime.now().toUtc());
      }
      if (!mounted) return;
      setState(() {
        _queue = q;
        _current = next;
        _preview = pv;
        _revealed = false;
        _loading = false;
        _error = null;
      });
      _stopwatch
        ..reset()
        ..start();
      _poll?.cancel();
      if (next == null && q.nextLearningDue != null) {
        // Waiting on a learning step: re-check shortly.
        _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
      } else if (next == null && _answered > 0 && !_sessionEnded) {
        _sessionEnded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _askInterest());
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _answer(int rating) async {
    final c = _current;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    _stopwatch.stop();
    final ms = _stopwatch.elapsedMilliseconds;
    try {
      final res = await ref.read(reviewServiceProvider).review(
            cardId: c.id,
            rating: rating,
            durationMs: ms,
          );
      _touched.add(c.domainId);
      _answered++;
      _totalMs += ms;
      if (res.becameLeech && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This card is a leech: suspended and tagged.')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        _stopwatch.start();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save that answer: $e. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final restored = await ref.read(reviewServiceProvider).undoLast();
      if (restored == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to undo.')));
        }
      } else {
        if (_answered > 0) _answered--;
        _sessionEnded = false;
        await _load(force: await ref.read(queueServiceProvider).cardById(restored.id));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _suspend() async {
    final c = _current;
    if (c == null) return;
    await ref.read(reviewServiceProvider).setSuspended(c.id, true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card suspended.')));
    }
    await _load();
  }

  /// One-tap interest per domain touched; skippable. Feeds the future engine.
  Future<void> _askInterest() async {
    if (_touched.isEmpty || !mounted) return;
    final db = ref.read(dbProvider);
    final names = <int, String>{};
    for (final id in _touched) {
      names[id] = (await (db.select(db.domains)..where((d) => d.id.equals(id))).getSingle()).name;
    }
    if (!mounted) return;
    final choices = <int, int>{};
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('How did that feel?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in names.entries) ...[
                Text(e.value, style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                SegmentedButton<int>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: -1, label: Text('Less'), icon: Icon(Icons.thumb_down_outlined)),
                    ButtonSegment(value: 0, label: Text('Same'), icon: Icon(Icons.remove)),
                    ButtonSegment(value: 1, label: Text('More'), icon: Icon(Icons.thumb_up_outlined)),
                  ],
                  selected: choices.containsKey(e.key) ? {choices[e.key]!} : <int>{},
                  onSelectionChanged: (s) => setS(() {
                    if (s.isEmpty) {
                      choices.remove(e.key);
                    } else {
                      choices[e.key] = s.first;
                    }
                  }),
                ),
                const SizedBox(height: 12),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            FilledButton(
              onPressed: () async {
                final svc = ref.read(interestServiceProvider);
                for (final e in choices.entries) {
                  await svc.record(e.key, e.value);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _queue?.ordered.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_current == null ? 'Review' : '$left left'),
        actions: [
          IconButton(tooltip: 'Undo last answer', icon: const Icon(Icons.undo), onPressed: _busy ? null : _undo),
          if (_current != null)
            IconButton(tooltip: 'Suspend this card', icon: const Icon(Icons.pause_circle_outline), onPressed: _suspend),
        ],
      ),
      body: SafeArea(child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Something went wrong: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final c = _current;
    if (c == null) return _done(context);

    final text = Theme.of(context).textTheme;
    return Column(children: [
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _revealed ? null : () => setState(() => _revealed = true),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, children: [
                Chip(label: Text(c.snapshot.state == CardState.newCard ? 'New' : c.snapshot.state.name)),
                if (c.unverified)
                  const Chip(
                      avatar: Icon(Icons.help_outline, size: 18),
                      label: Text('Unverified source')),
              ]),
              const SizedBox(height: 16),
              // Plain Text only: card content comes from an LLM and is never interpreted as markup.
              SelectableText(c.front, style: text.headlineSmall),
              if (_revealed) ...[
                const Divider(height: 32),
                SelectableText(c.back, style: text.titleLarge),
                if ((c.fields['supporting_quote'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Source: “${c.fields['supporting_quote']}”', style: text.bodyMedium),
                ],
              ],
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: _revealed
            ? Row(children: [
                for (final r in Rating.all)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        label: '${ratingName(r)}, next in ${formatInterval(_preview[r] ?? Duration.zero)}',
                        excludeSemantics: true,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 64), padding: const EdgeInsets.symmetric(horizontal: 2)),
                          onPressed: _busy ? null : () => _answer(r),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(ratingName(r)),
                            Text(formatInterval(_preview[r] ?? Duration.zero), style: text.labelSmall),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ])
            : FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => setState(() => _revealed = true),
                child: const Text('Show answer'),
              ),
      ),
    ]);
  }

  Widget _done(BuildContext context) {
    final waiting = _queue?.nextLearningDue;
    final mins = waiting == null
        ? null
        : ((waiting - DateTime.now().millisecondsSinceEpoch) / 60000).ceil().clamp(1, 100000);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(waiting == null ? Icons.check_circle_outline : Icons.hourglass_bottom, size: 56),
          const SizedBox(height: 12),
          Text(
            waiting == null ? 'All done for today' : 'Next card in about $mins min',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (_answered > 0) ...[
            const SizedBox(height: 8),
            Text('$_answered answered in ${(_totalMs / 60000).toStringAsFixed(1)} min'),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to home')),
        ]),
      ),
    );
  }
}
