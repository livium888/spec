import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/read_more_service.dart';
import '../domain/read_more_prompt.dart';

/// Library > Read more for older cards (D64). Cards made before every card carried a Read more paragraph get
/// one from an AI: copy or share a prompt for a batch of cards, paste the answer, check the preview, apply.
/// Nothing is saved before the learner has seen it and tapped the button; an existing paragraph is never replaced.
class ReadMoreScreen extends ConsumerStatefulWidget {
  const ReadMoreScreen({super.key, this.initialText});

  /// An answer that arrived through the share sheet: previewed at once (never saved unseen).
  final String? initialText;
  @override
  ConsumerState<ReadMoreScreen> createState() => _ReadMoreScreenState();
}

class _ReadMoreScreenState extends ConsumerState<ReadMoreScreen> {
  int? _missing; // null while loading
  int _batch = 20;
  ReadMorePlan? _plan;
  final _sel = <int>{};
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _count();
    final shared = widget.initialText;
    if (shared != null) WidgetsBinding.instance.addPostFrameCallback((_) => _preview(shared));
  }

  Future<void> _count() async {
    final n = await ref.read(readMoreServiceProvider).countMissing();
    if (mounted) setState(() => _missing = n);
  }

  int get _batchSize => (_missing ?? 0) < _batch ? (_missing ?? 0) : _batch;

  Future<String?> _prompt() async {
    final cards = await ref.read(readMoreServiceProvider).nextBatch(_batch);
    if (cards.isEmpty) return null;
    return renderReadMorePrompt(cards);
  }

  Future<void> _copy() async {
    final text = await _prompt();
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _message = 'Prompt for $_batchSize cards copied. Paste it into your AI app.');
  }

  Future<void> _send() async {
    final text = await _prompt();
    if (text == null) return;
    try {
      await ref.read(promptSharerProvider).send(text, title: 'Read more for $_batchSize cards');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not open the share sheet ($e). Use "Copy prompt" instead.');
    }
  }

  /// The clipboard is read ONLY on this explicit tap.
  Future<void> _paste() async {
    setState(() { _busy = true; _message = null; });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        setState(() => _message = 'The clipboard is empty. Copy the AI\'s JSON answer first.');
        return;
      }
      await _preview(text);
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not read the clipboard: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(String text) async {
    final plan = await ref.read(readMoreServiceProvider).preview(text);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _message = null;
      _sel
        ..clear()
        ..addAll(plan.applicable.map((r) => r.entry.index));
    });
  }

  /// How many of the ticked entries carry a paragraph, and how many say "nothing to add".
  (int, int) get _counts {
    var paragraphs = 0, none = 0;
    for (final r in _plan?.applicable ?? const <ReadMoreRow>[]) {
      if (!_sel.contains(r.entry.index)) continue;
      r.entry.nothingToAdd ? none++ : paragraphs++;
    }
    return (paragraphs, none);
  }

  Future<void> _apply() async {
    final plan = _plan!;
    setState(() => _busy = true);
    try {
      final r = await ref.read(readMoreServiceProvider).commit(plan, Set.of(_sel));
      ref.read(refreshProvider.notifier).bump();
      await _count();
      if (!mounted) return;
      setState(() {
        _plan = null;
        _message = 'Added Read more to ${r.added} card${r.added == 1 ? '' : 's'}.'
            '${r.none > 0 ? ' ${r.none} had nothing to add and will not be asked about again.' : ''}'
            '${(_missing ?? 0) > 0 ? ' $_missing still have none: send the next batch.' : ' Every card has been dealt with.'}';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Nothing was saved: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _why(ReadMoreStatus s) => switch (s) {
        ReadMoreStatus.ok || ReadMoreStatus.nothingToAdd => '',
        ReadMoreStatus.unknownCard => 'No card has this number: skipped.',
        ReadMoreStatus.alreadyHas => 'Already has a Read more: left as it is.',
        ReadMoreStatus.problemCard => 'Problem cards do not have one: skipped.',
        ReadMoreStatus.invalid => 'Not usable: skipped.',
        ReadMoreStatus.duplicate => 'Repeated in this answer: skipped.',
      };

  Widget _batchControls(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final n = _missing;
    if (n == null) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    if (n == 0) {
      return Text('Every card already has a Read more, or your AI found nothing to add. Nothing to do here.', style: t.bodyLarge);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$n card${n == 1 ? '' : 's'} ${n == 1 ? 'has' : 'have'} no Read more yet. It is a paragraph under the answer for when you want a bit more. '
          'Your AI writes them in batches, and it never replaces one you already have.', style: t.bodyLarge),
      const SizedBox(height: 8),
      Text('AI-written text is not checked by anyone. If a paragraph looks wrong, fix it on Edit card.', style: t.bodyMedium),
      const SizedBox(height: 16),
      Text('Cards in this batch', style: t.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 10, label: Text('10')),
          ButtonSegment(value: 20, label: Text('20')),
          ButtonSegment(value: 30, label: Text('30')),
        ],
        selected: {_batch},
        onSelectionChanged: (v) => setState(() => _batch = v.first),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.ios_share),
        label: const Text('Send to my AI app'),
        onPressed: _busy ? null : _send,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.copy),
        label: const Text('Copy prompt'),
        onPressed: _busy ? null : _copy,
      ),
      const SizedBox(height: 16),
      Text('When the AI answers, tap Share on its answer and choose Daily Learning (the preview opens by itself), or copy the answer and tap below.',
          style: t.bodyMedium),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.content_paste),
        label: const Text('Paste the answer'),
        onPressed: _busy ? null : _paste,
      ),
    ]);
  }

  Widget _planList(BuildContext context, ReadMorePlan plan) {
    final t = Theme.of(context).textTheme;
    if (plan.hasFatal) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('This can\'t be used:', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final e in plan.fatalErrors) ListTile(leading: const Icon(Icons.error_outline), title: Text(e)),
      ]);
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Untick any you do not want. Nothing is saved until you tap the button.', style: t.bodyMedium),
      ),
      for (final r in plan.rows)
        Card(
          child: r.applicable
              ? CheckboxListTile(
                  value: _sel.contains(r.entry.index),
                  onChanged: (v) => setState(() => v == true ? _sel.add(r.entry.index) : _sel.remove(r.entry.index)),
                  title: Text(r.question.isEmpty ? 'Card ${r.entry.noteId}' : r.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r.entry.nothingToAdd ? 'Nothing to add: this card will not be asked about again.' : r.entry.text),
                )
              : ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(r.question.isEmpty ? (r.entry.noteId == null ? 'Entry ${r.entry.index + 1}' : 'Card ${r.entry.noteId}') : r.question,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_why(r.status)),
                ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final (paragraphs, none) = _counts;
    return Scaffold(
      appBar: AppBar(title: const Text('Read more for older cards')),
      body: SafeArea(
        child: plan != null
            ? _planList(context, plan)
            : ListView(padding: const EdgeInsets.all(16), children: [
                _batchControls(context),
                if (_message != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!, style: Theme.of(context).textTheme.bodyLarge)),
                  ),
              ]),
      ),
      bottomNavigationBar: plan == null || plan.hasFatal
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  TextButton(onPressed: _busy ? null : () => setState(() => _plan = null), child: const Text('Back')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: _busy || _sel.isEmpty ? null : _apply,
                      child: Text(paragraphs > 0
                          ? 'Add Read more to $paragraphs card${paragraphs == 1 ? '' : 's'}'
                          : 'Mark $none card${none == 1 ? '' : 's'} as nothing to add'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}
