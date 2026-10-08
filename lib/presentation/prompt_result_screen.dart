import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/learn_service.dart';
import '../domain/learn_planner.dart';
import '../domain/study_advisor.dart';
import 'advice_card.dart';
import 'import_screen.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';
import 'learn_screen.dart';

/// The prompt to copy into an LLM, with the reasons it was chosen.
class PromptResultScreen extends ConsumerWidget {
  const PromptResultScreen({
    super.key,
    required this.prompt,
    this.view,
    this.alternative,
    this.advice,
    this.wasPending = false,
  });
  final GeneratedPrompt prompt;

  /// The plan this came from (for logging a switch to the alternative).
  final LearnView? view;

  /// Runner-up, offered as "Try something else". Null: nothing else to offer.
  final LearnOption? alternative;
  final Advice? advice;

  /// True when this is an earlier prompt that was never imported.
  final bool wasPending;

  Future<void> _tryAlternative(BuildContext context, WidgetRef ref) async {
    final learn = ref.read(learnServiceProvider);
    final alt = alternative!;
    final cap = advice == null ? alt.count : alt.count.clamp(1, advice!.recommendedNewCards < 1 ? 3 : advice!.recommendedNewCards);
    await learn.abandonPending(prompt.logId); // the first prompt will not be used
    final g = await learn.choose(alt.action == LearnAction.remediate ? alt : alt.withCount(cap), view!);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => PromptResultScreen(prompt: g, view: view, advice: advice)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your prompt')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(prompt.headline, style: t.headlineSmall),
          if (wasPending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('You asked for this earlier and have not imported the answer yet.'),
            ),
          if (prompt.reasons.isNotEmpty) ...[
            const SizedBox(height: Sp.m),
            SoftCard(
              color: AppColors.of(context).accentTint,
              borderColor: Colors.transparent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Why this one', style: t.labelLarge),
                const SizedBox(height: 4),
                for (final r in prompt.reasons) Text(r, style: t.bodyMedium),
              ]),
            ),
          ],
          if (advice != null) ...[
            const SizedBox(height: Sp.s),
            AdviceCard(advice!, compact: true),
          ],
          const SizedBox(height: Sp.l),
          SoftCard(
            child: Column(children: [
              for (final (i, step) in const [
                'Copy the prompt.',
                'Paste it into Claude, Gemini, ChatGPT, DeepSeek or any LLM.',
                'Copy the JSON it answers with.',
                'Come back and tap "Paste the answer".',
              ].indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: i == 3 ? 0 : 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.of(context).accentTint, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: t.labelLarge?.copyWith(color: AppColors.of(context).accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step, style: t.bodyMedium)),
                  ]),
                ),
            ]),
          ),
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
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (wasPending)
              TextButton(
                onPressed: () async {
                  await ref.read(learnServiceProvider).abandonPending(prompt.logId);
                  if (!context.mounted) return;
                  await Navigator.of(context)
                      .pushReplacement(MaterialPageRoute<void>(builder: (_) => const LearnScreen()));
                },
                child: const Text('Discard and pick again'),
              ),
            if (alternative != null && view != null)
              TextButton(
                onPressed: () => _tryAlternative(context, ref),
                child: const Text('Try something else'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LearnScreen(showOptions: true))),
              child: const Text('See all options'),
            ),
          ]),
          const SizedBox(height: 8),
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
