import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart';
import 'prompt_result_screen.dart';

/// Outline prompt: for a brand-new subject, or to add topics to an existing one.
class NewSubjectScreen extends ConsumerStatefulWidget {
  const NewSubjectScreen({super.key});
  @override
  ConsumerState<NewSubjectScreen> createState() => _NewSubjectScreenState();
}

class _NewSubjectScreenState extends ConsumerState<NewSubjectScreen> {
  final _name = TextEditingController();
  final _goal = TextEditingController();
  List<Domain> _existing = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(dbProvider);
    (db.select(db.domains)..where((d) => d.active.equals(true))).get().then((ds) {
      if (mounted) setState(() => _existing = ds);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a subject, for example "Spanish" or "Cell biology".');
      return;
    }
    if (name.length > 100) {
      setState(() => _error = 'Keep the subject name under 100 characters.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final g = await ref.read(learnServiceProvider).outlinePrompt(name, goal: _goal.text);
      if (!mounted) return;
      await Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: (_) => PromptResultScreen(prompt: g)));
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not build the prompt: $e'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New subject or more topics')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('The app will write a prompt that asks your LLM for an ordered outline of topics '
                'with prerequisites. Paste the answer back and the app uses it to decide what to teach you next.'),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Subject', helperText: 'Type an existing subject to add topics to it.'),
            ),
            if (_existing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, children: [
                  for (final d in _existing)
                    ActionChip(label: Text(d.name), onPressed: () => setState(() => _name.text = d.name)),
                ]),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _goal,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your goal or level (optional)',
                helperText: 'e.g. "complete beginner, want to hold a conversation"',
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
              onPressed: _busy ? null : _go,
              child: const Text('Make the outline prompt'),
            ),
          ]),
        ),
      );
}
