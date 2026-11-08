import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/primer_service.dart';
import 'widgets/rich_card_text.dart';

/// The primer for one topic (D68): a short reading BEFORE the cards. Attempt first, then read: a few questions to try
/// (what you get wrong, you read more closely), then the sections, the key points and where it came from.
/// Suggest only: nothing here blocks the cards, and reading is never counted as studying (not due, not in the day's record).
class PrimerReaderScreen extends ConsumerStatefulWidget {
  const PrimerReaderScreen({super.key, required this.topicId, required this.topicTitle});
  final int topicId;
  final String topicTitle;
  @override
  ConsumerState<PrimerReaderScreen> createState() => _PrimerReaderScreenState();
}

class _PrimerReaderScreenState extends ConsumerState<PrimerReaderScreen> {
  StoredPrimer? _stored;
  bool _loaded = false;
  final _shown = <int>{}; // answers revealed
  final _knew = <int, bool>{}; // the learner's own verdict per question
  bool _skipPretest = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(primerServiceProvider).forTopic(widget.topicId);
    if (mounted) setState(() { _stored = s; _loaded = true; });
  }

  Future<void> _markRead() async {
    final s = _stored;
    if (s == null) return;
    await ref.read(primerServiceProvider).markRead(s.id);
    ref.read(refreshProvider.notifier).bump();
    await _load();
    if (mounted) setState(() => _message = 'Marked as read. The cards for this topic are next.');
  }

  Future<void> _addCards() async {
    final s = _stored;
    if (s == null) return;
    final n = await ref.read(primerServiceProvider).addPretestAsCards(s.id);
    ref.read(refreshProvider.notifier).bump();
    if (mounted) {
      setState(() => _message = n == 0
          ? 'Those questions are already among your cards.'
          : 'Added $n card${n == 1 ? '' : 's'} to this topic. They are ordinary cards: review, edit or delete them as usual.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = _stored;
    return Scaffold(
      appBar: AppBar(title: Text(widget.topicTitle, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : s == null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('This topic has no primer.', style: t.bodyLarge)))
                : _body(context, s),
      ),
    );
  }

  Widget _body(BuildContext context, StoredPrimer s) {
    final t = Theme.of(context).textTheme;
    final p = s.primer;
    final known = _knew.values.where((v) => v).length;
    final answered = _knew.length;
    final mostKnown = p.pretest.length >= 3 && answered == p.pretest.length && known >= p.pretest.length - 1;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(p.title.isEmpty ? widget.topicTitle : p.title, style: t.headlineSmall),
      const SizedBox(height: 4),
      Text('About ${p.minutes} min${s.read ? ' · read ${s.readCount} time${s.readCount == 1 ? '' : 's'}' : ''}', style: t.bodySmall),
      const SizedBox(height: 4),
      Text('Written by an AI from your lecture. It is not checked by anyone: if something looks wrong, trust the lecture.', style: t.bodySmall),
      if (p.pretest.isNotEmpty && !_skipPretest) ...[
        const SizedBox(height: 16),
        Text('Try these first', style: t.titleMedium),
        Text('Guess before you read. Being wrong now makes the reading stick.', style: t.bodyMedium),
        const SizedBox(height: 8),
        for (final (i, q) in p.pretest.indexed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichCardText(q.question, style: t.bodyLarge!),
                const SizedBox(height: 8),
                if (!_shown.contains(i))
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => setState(() => _shown.add(i)),
                    child: const Text('Show the answer'),
                  )
                else ...[
                  RichCardText(q.answer, style: t.bodyMedium!),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('I knew it'), selected: _knew[i] == true, onSelected: (_) => setState(() => _knew[i] = true)),
                    ChoiceChip(label: const Text('I did not'), selected: _knew[i] == false, onSelected: (_) => setState(() => _knew[i] = false)),
                  ]),
                ],
              ]),
            ),
          ),
        if (mostKnown)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('You knew $known of ${p.pretest.length}. You may know this already: you can skip the reading and go to the cards.', style: t.bodyMedium),
                const SizedBox(height: 8),
                Row(children: [
                  FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go to the cards')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setState(() => _skipPretest = true), child: const Text('Read it anyway')),
                ]),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 16),
      Text('Reading', style: t.titleMedium),
      for (final sec in p.sections) ...[
        const SizedBox(height: 12),
        if (sec.heading.isNotEmpty) Semantics(header: true, child: Text(sec.heading, style: t.titleSmall)),
        const SizedBox(height: 4),
        RichCardText(sec.text, style: t.bodyLarge!, selectable: true),
      ],
      if (p.keyPoints.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Keep these', style: t.titleMedium),
        const SizedBox(height: 4),
        for (final k in p.keyPoints)
          Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: RichCardText(k, style: t.bodyLarge!)),
          ])),
      ],
      if (p.sources.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('From: ${p.sources.join('; ')}', style: t.bodySmall),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.check),
        label: Text(s.read ? 'Mark as read again' : 'I have read it'),
        onPressed: _markRead,
      ),
      if (p.pretest.isNotEmpty) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.add_card),
          label: Text('Add the ${p.pretest.length} questions as cards'),
          onPressed: _addCards,
        ),
      ],
      if (_message != null)
        Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: t.bodyLarge))),
    ]);
  }
}
