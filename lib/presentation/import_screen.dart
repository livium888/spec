import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/outline_service.dart' show OutlineException;
import '../domain/import_parser.dart';
import '../domain/study_card.dart' show kProblemLevels;
import '../domain/outline_parser.dart';
import '../domain/plan_parser.dart';
import 'keywords_screen.dart';
import 'topics_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.initialText});

  /// An answer that arrived through the share sheet: previewed straight away (never saved unseen).
  final String? initialText;
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportPreview? _preview;
  OutlinePreview? _outline;
  PlanPreview? _plan;
  final _planSel = <int>{};
  final _selected = <int>{};
  bool _busy = false;
  String? _message;

  /// After an import: the subject whose topics the learner can open next (a button under the message).
  int? _openTopicsOf;
  bool _backToLibrary = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.initialText;
    if (shared != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _previewShared(shared));
    }
  }

  /// Clipboard is read ONLY on this explicit tap (never automatically).
  Future<void> _paste() async {
    setState(() { _busy = true; _message = null; _openTopicsOf = null; _backToLibrary = false; });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        setState(() => _message = 'The clipboard is empty. Copy the LLM\'s JSON answer first.');
        return;
      }
      await _previewText(text);
    } catch (e) {
      setState(() => _message = 'Could not read the clipboard: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewShared(String text) async {
    setState(() { _busy = true; _message = null; });
    try {
      await _previewText(text);
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not read the shared text: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewText(String text) async {
    {
      final kind = detectPayloadKind(text);
      if (kind == 'keywords') {
        // Picture-search words for older cards have their own screen (and preview).
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => KeywordsScreen(initialText: text)));
        return;
      }
      if (kind == 'plan') {
        final pl = await ref.read(outlineServiceProvider).previewPlan(text);
        setState(() {
          _plan = pl;
          _outline = null;
          _preview = null;
          _planSel
            ..clear()
            ..addAll(pl.importable.map((s) => s.index));
        });
        return;
      }
      if (kind == 'outline') {
        final o = await ref.read(outlineServiceProvider).preview(text);
        setState(() {
          _outline = o;
          _preview = null;
          _plan = null;
        });
        return;
      }
      final p = await ref.read(importServiceProvider).preview(text);
      setState(() {
        _preview = p;
        _outline = null;
        _plan = null;
        _selected
          ..clear()
          ..addAll(p.importable.map((c) => c.index));
      });
    }
  }

  Future<void> _commit() async {
    final p = _preview!;
    setState(() => _busy = true);
    try {
      final s = await ref.read(importServiceProvider).commit(p, selected: _selected);
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      setState(() {
        _preview = null;
        _openTopicsOf = s.domainId;
        _message = 'Imported ${s.notes} notes (${s.cards} cards).'
            '${s.reading > 0 ? ' Added ${s.reading} reading suggestion${s.reading == 1 ? '' : 's'} (Library > Go deeper).' : ''}';
      });
    } catch (e) {
      setState(() => _message = 'Import failed, nothing was saved: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitOutline() async {
    final o = _outline!;
    setState(() => _busy = true);
    try {
      final s = await ref.read(outlineServiceProvider).commit(o);
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      setState(() {
        _outline = null;
        _openTopicsOf = s.domainId;
        _message = 'Added ${s.items} topic${s.items == 1 ? '' : 's'} with ${s.edges} prerequisite link${s.edges == 1 ? '' : 's'}'
            '${s.droppedEdges > 0 ? ' (${s.droppedEdges} ignored: unknown topic)' : ''}. '
            'Tap "Learn something new" to start.';
      });
    } on OutlineException catch (e) {
      setState(() => _message = e.message);
    } catch (e) {
      setState(() => _message = 'Import failed, nothing was saved: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitPlan() async {
    final pl = _plan!;
    setState(() => _busy = true);
    try {
      final r = await ref.read(outlineServiceProvider).commitPlan(pl, Set.of(_planSel));
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      setState(() {
        _plan = null;
        _backToLibrary = true;
        _message = 'Added ${r.subjects} subject${r.subjects == 1 ? '' : 's'} with ${r.topics} topic${r.topics == 1 ? '' : 's'}. '
            'Tap "Learn something new" to start.';
      });
    } on OutlineException catch (e) {
      setState(() => _message = e.message);
    } catch (e) {
      setState(() => _message = 'Import failed, nothing was saved: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _planList(BuildContext context, PlanPreview pl) {
    final t = Theme.of(context).textTheme;
    if (pl.hasFatal) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('This can\'t be imported:', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final e in pl.fatalErrors) ListTile(leading: const Icon(Icons.error_outline), title: Text(e)),
      ]);
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Tick the subjects you want. Nothing is saved until you tap the button.', style: t.bodyMedium),
      ),
      for (final s in pl.subjects)
        Card(
          child: s.valid && s.outline.importable.isNotEmpty
              ? CheckboxListTile(
                  value: _planSel.contains(s.index),
                  onChanged: (v) => setState(() => v == true ? _planSel.add(s.index) : _planSel.remove(s.index)),
                  title: Text(s.name),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (s.why.isNotEmpty) Text(s.why),
                    Text(
                        '${s.outline.importable.length} topic${s.outline.importable.length == 1 ? '' : 's'}'
                        '${s.outline.newDomain ? ' · new subject' : ' · added to a subject you have'}'
                        ': ${s.outline.importable.take(3).map((i) => i.title).join(', ')}…',
                        style: t.bodySmall),
                    if (s.outline.items.any((i) => !i.valid))
                      Text('Some topics have problems and will be skipped.', style: t.bodySmall),
                  ]),
                )
              : ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(s.name.isEmpty ? 'Subject ${s.index + 1}' : s.name),
                  subtitle: Text(s.valid ? 'Nothing new to add (all topics exist already).' : s.outline.fatalErrors.join('\n')),
                ),
        ),
    ]);
  }

  Widget _outlineList(BuildContext context, OutlinePreview o) {
    if (o.hasFatal) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('This outline can\'t be imported:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in o.fatalErrors) ListTile(leading: const Icon(Icons.error_outline), title: Text(e)),
      ]);
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: Text('Outline for "${o.domain}"'),
          subtitle: Text(o.newDomain ? 'A new subject will be created.' : 'Topics will be added to your existing subject.'),
        ),
      ),
      for (final it in o.items)
        Card(
          child: ListTile(
            title: Text(it.title.isEmpty ? '(topic ${it.index + 1})' : it.title),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (o.alreadyExists.contains(it.index)) const Text('Already in your topics - skipped'),
              for (final e in it.errors) Text('• $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (it.valid && !o.alreadyExists.contains(it.index))
                Text('Level ${it.level} · about ${it.targetCards} cards'
                    '${it.prerequisites.isEmpty ? '' : ' · after ${it.prerequisites.join(', ')}'}'),
              for (final w in o.warnings[it.index] ?? const <String>[]) Text('• $w'),
            ]),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final o = _outline;
    return Scaffold(
      appBar: AppBar(title: const Text('Import cards')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste from clipboard'),
                onPressed: _busy ? null : _paste,
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_message!, style: Theme.of(context).textTheme.bodyLarge),
                ),
              if (_message != null && _openTopicsOf != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('See the topics and choose what to learn'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TopicsScreen(domainId: _openTopicsOf))),
                  ),
                ),
              if (_message != null && _backToLibrary)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('Back to the Library to see them'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              if (p == null && o == null && _plan == null && _message == null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Copy the JSON your LLM returned (cards, a list of topics, or several new subjects), then tap the button. '
                      'You will see a preview before anything is saved.'),
                ),
            ]),
          ),
          if (p != null) Expanded(child: _previewList(context, p)),
          if (o != null) Expanded(child: _outlineList(context, o)),
          if (_plan != null) Expanded(child: _planList(context, _plan!)),
        ]),
      ),
      bottomNavigationBar: _plan != null && !_plan!.hasFatal
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy || _planSel.isEmpty ? null : _commitPlan,
                  child: Text('Add ${_planSel.length} subject${_planSel.length == 1 ? '' : 's'}'),
                ),
              ),
            )
          : o != null && !o.hasFatal
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy || o.importable.isEmpty ? null : _commitOutline,
                  child: Text('Add ${o.importable.length} topic${o.importable.length == 1 ? '' : 's'}'),
                ),
              ),
            )
          : p == null || p.hasFatal
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy || _selected.isEmpty ? null : _commit,
                  child: Text('Import ${_selected.length} card${_selected.length == 1 ? '' : 's'}'),
                ),
              ),
            ),
    );
  }

  Widget _previewList(BuildContext context, ImportPreview p) {
    if (p.hasFatal) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('This can\'t be imported:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in p.fatalErrors) ListTile(leading: const Icon(Icons.error_outline), title: Text(e)),
      ]);
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      if (p.renamedFrom != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text('These go to "${p.domain}"'),
            subtitle: Text('The AI wrote the subject as "${p.renamedFrom}", but it matches the prompt you copied for "${p.domain}", '
                'so the cards are added there.'),
          ),
        ),
      if (p.reading.isNotEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text('${p.reading.length} reading suggestion${p.reading.length == 1 ? '' : 's'} will be added'),
            subtitle: const Text('For going deeper on this topic. They are AI suggestions and go to Library > Go deeper, where you can check them.'),
          ),
        ),
      if (p.newDomain)
        Card(
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text('Domain "${p.domain}" will be created'),
            subtitle: const Text('Check the spelling if you expected an existing domain.'),
          ),
        ),
      for (final c in p.cards) _cardTile(context, p, c),
    ]);
  }

  Widget _cardTile(BuildContext context, ImportPreview p, ParsedCard c) {
    final st = p.status[c.index];
    final title = c.type == 'cloze' ? c.cloze : c.front;
    final label = switch (st) {
      PreviewStatus.ok => null,
      PreviewStatus.invalid => 'Invalid',
      PreviewStatus.duplicateInDb => 'Duplicate (already in your cards)',
      PreviewStatus.duplicateInPayload => 'Duplicate (repeated in this paste)',
      null => null,
    };
    final importable = st == PreviewStatus.ok;
    return Card(
      child: CheckboxListTile(
        value: importable && _selected.contains(c.index),
        onChanged: importable
            ? (v) => setState(() => v == true ? _selected.add(c.index) : _selected.remove(c.index))
            : null,
        title: Text(title.isEmpty ? '(card ${c.index + 1})' : title, maxLines: 3, overflow: TextOverflow.ellipsis),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null) Text(label, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final e in c.errors) Text('• $e'),
          if (c.type == 'problem')
            Text(
                'Problem with ${c.steps.length} steps in $kProblemLevels levels'
                '${c.variants.isEmpty ? '' : ', plus ${c.variants.length} more to practise'}'
                '${c.arithmetic == 'checked' ? '. Arithmetic checked by the app.' : '. Arithmetic not checked.'}'),
          if (importable && c.unverified && c.type != 'problem')
            const Row(children: [
              Icon(Icons.help_outline, size: 16),
              SizedBox(width: 4),
              Expanded(child: Text('Unverified (low confidence or from memory)')),
            ]),
        ]),
      ),
    );
  }
}
