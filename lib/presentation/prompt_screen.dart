import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart';
import '../domain/prompt_template.dart';

class PromptScreen extends ConsumerStatefulWidget {
  const PromptScreen({super.key});
  @override
  ConsumerState<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends ConsumerState<PromptScreen> {
  List<Domain> _domains = [];
  Domain? _domain;
  final _count = TextEditingController(text: '10');
  final _source = TextEditingController();
  final _newDomain = TextEditingController();
  String? _prompt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDomains();
  }

  @override
  void dispose() {
    _count.dispose();
    _source.dispose();
    _newDomain.dispose();
    super.dispose();
  }

  Future<void> _loadDomains() async {
    final db = ref.read(dbProvider);
    final ds = await (db.select(db.domains)..where((d) => d.active.equals(true))).get();
    if (!mounted) return;
    setState(() {
      _domains = ds;
      _domain ??= ds.isEmpty ? null : ds.first;
    });
  }

  Future<void> _generate() async {
    final n = int.tryParse(_count.text.trim());
    if (n == null || n < 1 || n > 50) {
      setState(() => _error = 'Enter a number of cards between 1 and 50.');
      return;
    }
    try {
      final db = ref.read(dbProvider);
      var dom = _domain;
      final fresh = _newDomain.text.trim();
      if (fresh.isNotEmpty) {
        final existing = _domains.where((d) => d.name.toLowerCase() == fresh.toLowerCase());
        if (existing.isNotEmpty) {
          dom = existing.first;
        } else {
          final id = await db.into(db.domains).insert(
              DomainsCompanion.insert(name: fresh, createdAt: DateTime.now().toUtc().millisecondsSinceEpoch));
          dom = await (db.select(db.domains)..where((d) => d.id.equals(id))).getSingle();
        }
      }
      if (dom == null) {
        setState(() => _error = 'Pick a domain or type a new one.');
        return;
      }
      final r = await ref.read(promptServiceProvider).build(
            domainId: dom.id,
            n: n,
            sourceText: _source.text,
          );
      await _loadDomains();
      setState(() {
        _prompt = r.text;
        _error = null;
        _domain = dom;
      });
    } catch (e) {
      setState(() => _error = 'Could not build the prompt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prompt builder')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_domains.isNotEmpty)
            DropdownButtonFormField<Domain>(
              initialValue: _domain,
              decoration: const InputDecoration(labelText: 'Domain'),
              items: [for (final d in _domains) DropdownMenuItem(value: d, child: Text(d.name))],
              onChanged: (d) => setState(() => _domain = d),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _newDomain,
            decoration: InputDecoration(
              labelText: _domains.isEmpty ? 'Domain name' : 'Or create a new domain',
              helperText: 'Leave empty to use the one selected above.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of cards (1-50)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _source,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Source text (optional)',
              helperText: 'If given, the cards will be made only from this text.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _generate,
            child: const Text('Generate prompt'),
          ),
          if (_prompt != null) ...[
            const SizedBox(height: 16),
            Text('Template $kPromptTemplateVersion', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(_prompt!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy prompt'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _prompt!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Copied. Paste it into your LLM.')));
                }
              },
            ),
          ],
        ]),
      ),
    );
  }
}
