import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/learn_service.dart';
import '../domain/learn_planner.dart';
import 'new_subject_screen.dart';
import 'prompt_result_screen.dart';
import 'topics_screen.dart';

/// "Learn something new": the app picks (up to) two things to ask the LLM for.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});
  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  LearnView? _view;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final v = await ref.read(learnServiceProvider).view();
      if (mounted) setState(() => _view = v);
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

  Future<void> _choose(LearnOption o) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final g = await ref.read(learnServiceProvider).choose(o, _view!);
      if (!mounted) return;
      await _open(PromptResultScreen(prompt: g));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not build the prompt: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Learn something new')),
        body: SafeArea(child: _body(context)),
      );

  Widget _body(BuildContext context) {
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
    final v = _view;
    if (v == null) return const Center(child: CircularProgressIndicator());
    final plan = v.plan;
    final t = Theme.of(context).textTheme;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _capacityLine(context, plan),
      if (plan.blockedReason != null)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.warning_amber),
            title: Text(plan.blockedReason!),
          ),
        ),
      if (v.pending != null) _pendingCard(context, v.pending!),
      const SizedBox(height: 8),
      if (plan.options.isEmpty) _empty(context, plan) else ...[
        Text(plan.options.length == 1 ? 'Suggested for today' : 'Pick one', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final o in plan.options) _optionCard(context, o),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('New subject or more topics'),
          onPressed: () => _open(const NewSubjectScreen()),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('Choose a topic myself'),
          onPressed: () => _open(const TopicsScreen(pickMode: true)),
        ),
      ]),
    ]);
  }

  Widget _capacityLine(BuildContext context, LearnPlan plan) {
    final c = plan.capacity;
    final mins = (c.dueSeconds / 60).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        c.dueReviews == 0
            ? 'No reviews due. Room for about ${c.cardsRoom} new cards today.'
            : '${c.dueReviews} reviews due (about $mins min). Room for about ${c.cardsRoom} new cards today.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _pendingCard(BuildContext context, PendingPrompt p) {
    final what = p.isOutline ? 'an outline for ${p.domainName}' : '${p.domainName}${p.itemTitle == null ? '' : ': ${p.itemTitle}'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hourglass_top),
            const SizedBox(width: 8),
            Expanded(child: Text('You have a prompt for $what that was never imported.')),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.tonal(
              onPressed: () => _open(PromptResultScreen(
                  prompt: GeneratedPrompt(p.id, p.text, what))),
              child: const Text('Show it again'),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(learnServiceProvider).abandonPending(p.id);
                _load();
              },
              child: const Text('Discard it'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _optionCard(BuildContext context, LearnOption o) {
    final t = Theme.of(context).textTheme;
    final kind = switch (o.action) {
      LearnAction.newItem => 'New topic',
      LearnAction.deepen => 'Go deeper',
      LearnAction.remediate => 'Fix hard cards',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            Chip(label: Text(kind)),
            Chip(label: Text('${o.count} card${o.count == 1 ? '' : 's'}')),
            if (o.explore) const Chip(avatar: Icon(Icons.shuffle, size: 18), label: Text('A change of pace')),
          ]),
          const SizedBox(height: 8),
          Text(o.headline, style: t.titleMedium),
          const SizedBox(height: 4),
          for (final r in o.reasons) Text(r, style: t.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : () => _choose(o),
            child: const Text('Use this'),
          ),
        ]),
      ),
    );
  }

  Widget _empty(BuildContext context, LearnPlan plan) {
    final (title, body) = switch (plan.emptyReason) {
      EmptyReason.noDomains => (
          'Start with a subject',
          'Tell the app what you want to learn. It will give you a prompt that asks your LLM for an ordered outline. '
              'Paste the answer back and the app will take it from there.'
        ),
      EmptyReason.noSyllabus => (
          'No topics yet',
          'Your subjects have no outline. Create one with the button below.'
        ),
      EmptyReason.allDone => (
          'Everything in your outlines is covered',
          'Add more topics to a subject, or start a new one.'
        ),
      EmptyReason.none => ('', ''),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _open(const NewSubjectScreen()),
            child: const Text('New subject or more topics'),
          ),
        ]),
      ),
    );
  }
}
