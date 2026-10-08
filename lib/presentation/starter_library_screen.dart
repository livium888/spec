import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/starter_library.dart';

/// Bundled subjects that can be added with one tap (no copy/paste needed).
class StarterLibraryScreen extends ConsumerStatefulWidget {
  const StarterLibraryScreen({super.key});
  @override
  ConsumerState<StarterLibraryScreen> createState() => _StarterLibraryScreenState();
}

class _StarterLibraryScreenState extends ConsumerState<StarterLibraryScreen> {
  List<StarterOutline>? _all;
  final _added = <String>{};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await StarterLibrary.load(ref.read(assetBundleProvider));
      final svc = ref.read(outlineServiceProvider);
      final added = <String>{};
      for (final o in all) {
        if (o.askName) continue; // templates are never "already added"
        final p = await svc.preview(o.raw);
        if (!p.hasFatal && !p.newDomain && p.importable.isEmpty) added.add(o.asset);
      }
      if (mounted) setState(() { _all = all; _added..clear()..addAll(added); _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<String?> _askName(String initial) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this subject'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Subject', hintText: 'e.g. Spanish', helperText: 'Replaces "$initial".'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _add(StarterOutline o) async {
    var raw = o.raw;
    if (o.askName) {
      final name = await _askName(o.domain);
      if (name == null || name.isEmpty) return;
      if (name.length > 100) {
        _toast('Keep the name under 100 characters.');
        return;
      }
      raw = o.rawAs(name);
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(outlineServiceProvider);
      final p = await svc.preview(raw);
      if (p.hasFatal) {
        _toast('Could not add: ${p.fatalErrors.first}');
        return;
      }
      if (p.importable.isEmpty) {
        _toast('You already have all of these topics.');
        return;
      }
      final s = await svc.commit(p);
      ref.read(refreshProvider.notifier).bump();
      _toast('Added ${s.items} topics to ${p.domain}.');
      await _load();
    } catch (e) {
      _toast('Could not add: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Starter library')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load: $_error')))
            : _all == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    const Text('Pick subjects to start with. Each adds an ordered list of topics; '
                        '"Learn something new" then decides which to teach you next. These are only the '
                        'starting topics: when you finish them the app asks your LLM for more, and it '
                        'will start new subjects on its own, so the library never runs out.'),
                    const SizedBox(height: 12),
                    for (final o in _all!)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(o.askName ? 'Language course (you name it)' : o.domain, style: t.titleMedium),
                                Text('Starts with ${o.topics} topics', style: t.bodyMedium),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            _added.contains(o.asset)
                                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.check_circle_outline),
                                    SizedBox(width: 4),
                                    Text('Added'),
                                  ])
                                : FilledButton.tonal(
                                    onPressed: _busy ? null : () => _add(o),
                                    child: const Text('Add'),
                                  ),
                          ]),
                        ),
                      ),
                  ]),
      ),
    );
  }
}
