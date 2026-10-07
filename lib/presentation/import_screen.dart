import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/import_parser.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportPreview? _preview;
  final _selected = <int>{};
  bool _busy = false;
  String? _message;

  /// Clipboard is read ONLY on this explicit tap (never automatically).
  Future<void> _paste() async {
    setState(() { _busy = true; _message = null; });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        setState(() => _message = 'The clipboard is empty. Copy the LLM\'s JSON answer first.');
        return;
      }
      final p = await ref.read(importServiceProvider).preview(text);
      setState(() {
        _preview = p;
        _selected
          ..clear()
          ..addAll(p.importable.map((c) => c.index));
      });
    } catch (e) {
      setState(() => _message = 'Could not read the clipboard: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
        _message = 'Imported ${s.notes} notes (${s.cards} cards).';
      });
    } catch (e) {
      setState(() => _message = 'Import failed, nothing was saved: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
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
              if (p == null && _message == null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Copy the JSON your LLM returned, then tap the button. '
                      'You will see a preview before anything is saved.'),
                ),
            ]),
          ),
          if (p != null) Expanded(child: _previewList(context, p)),
        ]),
      ),
      bottomNavigationBar: p == null || p.hasFatal
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
          if (importable && c.unverified)
            const Row(children: [
              Icon(Icons.help_outline, size: 16),
              SizedBox(width: 4),
              Text('Unverified (low confidence or from memory)'),
            ]),
        ]),
      ),
    );
  }
}
