import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/learn_service.dart';
import 'import_screen.dart';

/// Shows a generated prompt with the copy -> LLM -> paste back steps.
class PromptResultScreen extends StatelessWidget {
  const PromptResultScreen({super.key, required this.prompt});
  final GeneratedPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your prompt')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(prompt.headline, style: t.titleLarge),
          const SizedBox(height: 12),
          const Text('1. Copy the prompt.\n'
              '2. Paste it into Claude, Gemini, ChatGPT, DeepSeek or any LLM.\n'
              '3. Copy the JSON it answers with.\n'
              '4. Come back and tap "Paste the answer".'),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.copy),
            label: const Text('Copy prompt'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: prompt.text));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied. Paste it into your LLM.')));
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste the answer'),
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute<void>(builder: (_) => const ImportScreen())),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('See the prompt'),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(prompt.text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
