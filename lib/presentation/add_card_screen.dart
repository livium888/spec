import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Manual card entry. Goes through the same validation / dedupe as JSON import.
class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});
  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _domain = TextEditingController();
  final _front = TextEditingController();
  final _back = TextEditingController();
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _domain.dispose();
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final svc = ref.read(importServiceProvider);
    final payload = jsonEncode({
      'domain': _domain.text.trim(),
      'syllabus_item': null,
      'cards': [
        {
          'type': 'basic',
          'front': _front.text.trim(),
          'back': _back.text.trim(),
          'source_type': 'quote',
          'source_ref': 'manual entry',
          'supporting_quote': 'written by me',
          'confidence': 'high',
        }
      ],
    });
    final p = await svc.preview(payload);
    if (p.hasFatal) {
      setState(() { _msg = p.fatalErrors.join('\n'); _ok = false; });
      return;
    }
    final c = p.cards.single;
    if (!c.valid) {
      setState(() { _msg = c.errors.join('\n'); _ok = false; });
      return;
    }
    if (p.importable.isEmpty) {
      setState(() { _msg = 'You already have a card with that question in this domain.'; _ok = false; });
      return;
    }
    await svc.commit(p);
    ref.read(refreshProvider.notifier).bump();
    _front.clear();
    _back.clear();
    setState(() { _msg = 'Saved.'; _ok = true; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add card')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: _domain, decoration: const InputDecoration(labelText: 'Domain')),
            const SizedBox(height: 12),
            TextField(controller: _front, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Front (question)')),
            const SizedBox(height: 12),
            TextField(controller: _back, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Back (answer)')),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_msg!, style: TextStyle(color: _ok ? null : Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _save,
              child: const Text('Save card'),
            ),
          ]),
        ),
      );
}
